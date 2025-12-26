# shellcheck disable=SC2154,SC2034

# Ensure dependencies are installed, otherwise quit.
dependency_check

# If a recording is already in progress (indicated by the state file), stop it and exit
if [[ -e /tmp/peck/recording ]]; then
  pkill -INT -x wf-recorder
  rm /tmp/peck/recording
  exit 0
fi

# Cleanup old temp files
rm -rf /tmp/peck/out

# Determine mode: screenshot or record
mode=$([[ "${args[--record]}" == "1" ]] && echo "record" || echo "screenshot")
# Determine save type: temporary (discard after use) or permanent (keep in output directory)
mode_save=$([[ "${args[--temp]}" == "1" ]] && echo "temporary" || echo "permanent")
# Determine if the final file should also be copied to the clipboard
copy_to_clipboard=$([[ "${args[--clipboard]}" == "1" ]] && echo "true" || echo "false")

# Validate temp mode: cannot provide a filepath when saving temporarily
if [[ "$mode_save" == "temporary" && -n "${args[filepath]}" ]]; then
  notify_user "Invalid usage: --temp flag cannot be used when providing a filepath."
  exit 1
fi

# Determine Format
arg_format="${args[--format]}"
if [[ -n "$arg_format" ]]; then
  # If format was provided, use that
  out_format="$arg_format"
else
  # Else get the default from the env variables
  out_format=$([[ "$mode" == "record" ]] && echo "$PECK_RECORDING_FORMAT" || echo "$PECK_SCREENSHOT_FORMAT")
fi

# Generate the output filepath 
filepath="${args[filepath]}"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
if [[ -n "$filepath" ]]; then
    # Ensure filepath doesn't end with a slash
    [[ "$filepath" == */ ]] && { notify_user "Invalid filepath: ends with /"; exit 1; }

    filename="$(basename "$filepath")"
    out_dir="$(dirname "$filepath")"

    # If dirname returns ".", it's already the current directory
else
    # Auto-generate filename and output directory
    filename="peck-$timestamp"
    out_dir=$([[ "$mode" == "record" ]] && echo "$PECK_RECORDING_DIR" || echo "$PECK_SCREENSHOT_DIR")
fi

# Normalize the filename (prevent .png.png)
filename="${filename%."$out_format"}"

# Create the temp directory
tmp_dir="/tmp/peck/out"
mkdir -p "$tmp_dir"
tmp_file="$tmp_dir/$filename.$out_format"

# Select the recording region, exit if cancaelled
region=$(slurp) || { notify_user "Selection cancelled, not capturing."; exit 0; }

# Capture
if [[ "$mode" == "screenshot" ]]; then
  grim -t "$out_format" -g "$region" "$tmp_file"
else
  # Create a filepath for the mp4
  tmp_mp4="$tmp_dir/$filename.mp4"
  # Mark as currently recording so we can stop by calling peck again
  touch /tmp/peck/recording
  notify_user "Recording has started..." "$PECK_SILENCE_START_RECORDING"
  echo "Press CTRL+C to stop recording." >&2
  wf-recorder -g "$region" -f "$tmp_mp4" &>/dev/null
  echo "" >&2
  # Remove the recording state file in case we quit from the terminal rather than calling peck again
  rm -f /tmp/peck/recording

  # Handle Conversion/Filtering
  video_filter="${args[--filter]}"

  if [[ "$out_format" != "mp4" || -n "$video_filter" ]]; then
      vf="$video_filter"

      if [[ -z "$vf" && "$out_format" == "gif" ]]; then
          vf="fps=20,scale=iw:-1:flags=lanczos"
      fi

      if [[ -n "$vf" ]]; then
          ffmpeg -y -i "$tmp_mp4" -vf "$vf" "$tmp_file" &>/dev/null
      else
          ffmpeg -y -i "$tmp_mp4" "$tmp_file" &>/dev/null
      fi

      # Remove the temporary file after conversion
      rm -f "$tmp_mp4"
  else
    tmp_file="$tmp_mp4"
  fi
fi

final_path="$tmp_file"

# If we want to store the file permanently, move it out of the tmp dir
if [[ "$mode_save" == "permanent" ]]; then
  mkdir -p "$out_dir"
  final_path="$out_dir/$filename.$out_format"
  mv "$tmp_file" "$final_path"
fi

# Notify the user and copy to clipboard if requested
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
