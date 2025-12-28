# shellcheck disable=SC2154,SC2034

RECORDER_PID_FILE="/tmp/peck/wf-recorder.pid"

# Ensure dependencies are installed, otherwise quit.
dependency_check

# Check if PID file exists and process is running wf-recorder
if [[ -f "$RECORDER_PID_FILE" ]]; then
    recorder_pid=$(<"$RECORDER_PID_FILE")

    if ! ps -p "$recorder_pid" -o comm= | grep -qx "wf-recorder"; then
        # PID is either not running anymore, or doesn't belong to wf-recorder
        # so remove the stale file
        rm -f "$RECORDER_PID_FILE"
    else
        # Kill the wf-recorder and exit
        kill -int "$recorder_pid"
        rm -f "$RECORDER_PID_FILE"
        exit 0
    fi
fi

# Remove captures stored in temporary mode
rm -rf /tmp/peck/out

# Determine mode: screenshot or record
mode=$([[ "${args[--record]}" == "1" ]] && echo "record" || echo "screenshot")
# Determine save type: temporary or permanent
mode_save=$([[ "${args[--temp]}" == "1" ]] && echo "temporary" || echo "permanent")
# Determine if final file should be copied to clipboard
copy_to_clipboard=$([[ "${args[--clipboard]}" == "1" ]] && echo "true" || echo "false")
# Determine whether to freeze the screen while capturing screenshot
freeze_mode=$([[ "${args[--freeze]}" == "1" ]] && echo "true" || echo "false")

# Validate temp mode
if [[ "$mode_save" == "temporary" && -n "${args[filepath]}" ]]; then
    notify_user "Invalid usage: --temp flag cannot be used when providing a filepath."
    exit 1
fi

# Determine format
arg_format="${args[--format]}"
if [[ -n "$arg_format" ]]; then
    out_format="$arg_format"
else
    out_format=$([[ "$mode" == "record" ]] && echo "$PECK_RECORDING_FORMAT" || echo "$PECK_SCREENSHOT_FORMAT")
fi

# Generate output filepath
filepath="${args[filepath]}"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
if [[ -n "$filepath" ]]; then
    [[ "$filepath" == */ ]] && { notify_user "Invalid filepath: ends with /"; exit 1; }
    filename="$(basename "$filepath")"
    out_dir="$(dirname "$filepath")"
else
    filename="peck-$timestamp"
    out_dir=$([[ "$mode" == "record" ]] && echo "$PECK_RECORDING_DIR" || echo "$PECK_SCREENSHOT_DIR")
fi

filename="${filename%."$out_format"}"

# Create temp directory
tmp_dir="/tmp/peck/out"
mkdir -p "$tmp_dir"
tmp_file="$tmp_dir/$filename.$out_format"



# Capture
if [[ "$mode" == "screenshot" ]]; then
    if [[ "$freeze_mode" == "true" ]]; then
        # Freeze screen and take screenshot
        # Freeze screen
        wayfreeze & PID=$!
        sleep .1

        # Try to get region selection
        region=$(slurp) || {
            kill $PID
            notify_user "Selection cancelled, not capturing."
            exit 0
        }

        # Take screenshot
        grim -t "$out_format" -g "$region" "$tmp_file"
        kill $PID
    else
        # Normal selection without freeze
        region=$(slurp) || { notify_user "Selection cancelled, not capturing."; exit 0; }
        grim -t "$out_format" -g "$region" "$tmp_file"
    fi
else
    # Select region
    region=$(slurp) || { notify_user "Selection cancelled, not capturing."; exit 0; }
    tmp_mp4="$tmp_dir/$filename.mp4"

    # Enable job control
    set -m

    notify_user "Recording has started..." "$PECK_SILENCE_START_RECORDING"
    echo "Press CTRL+C to stop recording." >&2

    # Trap SIGINT so we can CTRL+C wf-recorder
    trap "" SIGINT

    # Start wf-recorder and store its PID (in case we stop recording by rerunning peck)
    wf-recorder -g "$region" -f "$tmp_mp4" &>/dev/null &
    recorder_pid=$!
    echo "$recorder_pid" > "$RECORDER_PID_FILE"

    # Restore SIGINT handling for child
    trap - SIGINT

    # Bring recorder to foreground (so CTRL+C hits only wf-recorder)
    fg %- >/dev/null

    # Remove the PID file in case we stopped recording by CTRL+C rather than rerunning peck
    rm -f "$RECORDER_PID_FILE"

    # Handle conversion/filtering
    video_filter="${args[--filter]}"
    if [[ "$out_format" != "mp4" || -n "$video_filter" ]]; then
        vf="$video_filter"
        [[ -z "$vf" && "$out_format" == "gif" ]] && vf="fps=20,scale=iw:-1:flags=lanczos"

        if [[ -n "$vf" ]]; then
            ffmpeg -y -i "$tmp_mp4" -vf "$vf" "$tmp_file" &>/dev/null
        else
            ffmpeg -y -i "$tmp_mp4" "$tmp_file" &>/dev/null
        fi

        rm -f "$tmp_mp4"
    else
        tmp_file="$tmp_mp4"
    fi
fi

final_path="$tmp_file"

# Move to permanent location if needed
if [[ "$mode_save" == "permanent" ]]; then
    mkdir -p "$out_dir"
    final_path="$out_dir/$filename.$out_format"
    mv "$tmp_file" "$final_path"
fi

# Notify and copy to clipboard if requested
notification_message="Captured ($final_path)"
if [[ "$copy_to_clipboard" == "true" ]]; then
    if [[ "$mode" == "screenshot" ]]; then
        wl-copy < "$final_path"
    else
        wl-copy --type text/uri-list "file://$final_path"
    fi
    notification_message+=" and copied to clipboard."
fi

notify_user "$notification_message"
