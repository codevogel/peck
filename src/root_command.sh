# shellcheck disable=SC2154,SC2034

if [[ -e /tmp/peck/recording ]]; then
  pkill -INT -x wf-recorder
  rm /tmp/peck/recording
  exit 0
fi

# Clean old tmp files
rm -rf /tmp/peck/out

# Determine whether we are in record or screenshot mode
if [[ "${args[--record]}" == "1" ]]; then
  mode="record"
else
  mode="screenshot"
fi

# Determine whether we will keep the output file in tmp or move it to a permanent location
if [[ "${args[--temp]}" == "1" ]]; then
  if [[ -n "${args[filepath]}" ]]; then
    notify_user "Invalid usage: --temp flag cannot be used when providing a filepath."
	  exit 1
  fi
  mode_save="temporary"
else
  mode_save="permanent"
fi

# Clipboard
if [[ "${args[--clipboard]}" == "1" ]]; then
  copy_to_clipboard="true"
else
  copy_to_clipboard="false"
fi

# Format

arg_format="${args[--format]}"

if [[ -n "$arg_format" ]]; then
  out_format="$arg_format"
elif [[ "$mode" == "record" ]]; then
  out_format="$PECK_RECORDING_FORMAT"
else
  out_format="$PECK_SCREENSHOT_FORMAT"
fi


# Path

filepath="${args[filepath]}"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"

if [[ -n "$filepath" ]]; then
  # Check if filepath ends with a slash
  if [[ "$filepath" == */ ]]; then
    notify_user "Invalid filepath: '$filepath' ends with a '/'. Please provide a filename, not a directory."
    exit 1
  fi

  # Extract filename
  filename="${filepath##*/}"

  # Determine output directory
  if [[ "$filepath" == */* ]]; then
    out_dir="${filepath%/*}"
    [[ -z "$out_dir" ]] && out_dir="/"
  else
    out_dir="."
  fi
else
  # No filepath supplied → generate filename
  filename="peck-$timestamp"
  if [[ "$mode" == "record" ]]; then
    out_dir="$PECK_RECORDING_DIR"
  else
    out_dir="$PECK_SCREENSHOT_DIR"
  fi
fi

# Normalize filename extension

if [[ "$filename" == *."$out_format" ]]; then
  filename="${filename%."$out_format"}"
fi


# Temp file

tmp_dir="/tmp/peck/out"
mkdir -p "$tmp_dir"

tmp_file="$tmp_dir/$filename.$out_format"
out_file="$tmp_file"

# Screenshot

if [[ "$mode" == "screenshot" ]]; then
  grim -t "$out_format" -g "$(slurp)" "$tmp_file"

  if [[ "$mode_save" == "permanent" ]]; then
    mkdir -p "$out_dir"
    out_file="$out_dir/$filename.$out_format"
    mv "$tmp_file" "$out_file"
  fi
  notification_message="Screenshot captured ($out_file)"

  if [[ "$copy_to_clipboard" == "true" ]]; then
    wl-copy < "$out_file"
    notification_message+=" and copied to the clipboard."
  fi

  notify_user "$notification_message"

  exit 0
fi

# Screen Recording

if [[ "$mode" == "record" ]]; then
  tmp_mp4="$tmp_dir/$filename.mp4"
  out_file="$tmp_mp4"

  # Ask slurp for a region if needed
  region="$(slurp 2>/dev/null)"
  if [[ -z "$region" ]]; then
    notify_user "No region selected. Exiting."
    exit 1
  fi

  # Touch a temp file so the next peck call knows to stop recording
  touch /tmp/peck/recording
  notify_user "Recording has started..." "$PECK_SILENCE_START_RECORDING"
  # Separate echo for when running from the terminal
  echo "Press CTRL+C to stop..." >&2

  wf-recorder -g "$region" -f "$tmp_mp4" &>/dev/null
  rm -f /tmp/peck/recording

  video_filter="${args[--filter]}"
  # Convert to desired output format if different from mp4
  if [[ "$out_format" != "mp4" ]]; then
    final_file="$tmp_dir/$filename.$out_format"

    # Determine which filter to use
    if [[ -n "$video_filter" ]]; then
      vf="$video_filter"
    elif [[ "$out_format" == "gif" ]]; then
      vf="fps=20,scale=iw:-1:flags=lanczos"
    else
      vf=""
    fi

    # Run ffmpeg with or without a video filter
    if [[ -n "$vf" ]]; then
      ffmpeg -y -i "$tmp_mp4" -vf "$vf" "$final_file" &>/dev/null
    else
      ffmpeg -y -i "$tmp_mp4" "$final_file" &>/dev/null
    fi

    rm -f "$tmp_mp4"
    out_file="$final_file"
  fi


  if [[ "$mode_save" == "permanent" ]]; then
    mkdir -p "$out_dir"
    final_out="$out_dir/$filename.$out_format"
    mv "$out_file" "$final_out"
    out_file="$final_out"
  fi

  notification_message="Recording captured ($out_file)"

  if [[ "$copy_to_clipboard" == "true" ]]; then
    wl-copy --type text/uri-list "file://$out_file"
    notification_message+=" and copied to the clipboard."
  fi

  notify_user "$notification_message"
fi
