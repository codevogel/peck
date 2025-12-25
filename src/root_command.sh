# shellcheck disable=SC2154,SC2034

# --- Mode ----------------------------------------------------

if [[ "${args[--record]}" == "1" ]]; then
  mode="record"
else
  mode="screenshot"
fi

# --- Save location -------------------------------------------

if [[ "${args[--temp]}" == "1" ]]; then
  if [[ -n "${args[filepath]}" ]]; then
	  echo "Argument mismatch: --temp flag cannot be used when providing a filepath." >&2
	  exit 1
  fi
  mode_save="temporary"
else
  mode_save="permanent"
fi

# --- Clipboard ------------------------------------------------

if [[ "${args[--clipboard]}" == "1" ]]; then
  copy_to_clipboard="yes"
else
  copy_to_clipboard="no"
fi

# --- Format ---------------------------------------------------

arg_format="${args[--format]}"

if [[ -n "$arg_format" ]]; then
  out_format="$arg_format"
elif [[ "$mode" == "record" ]]; then
  out_format="$PECK_RECORDING_FORMAT"
else
  out_format="$PECK_SCREENSHOT_FORMAT"
fi


# --- Path resolution -----------------------------------------

filepath="${args[filepath]}"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"

if [[ -n "$filepath" ]]; then
  filename="${filepath##*/}"

  if [[ "$filepath" == */* ]]; then
    out_dir="${filepath%/*}"
    [[ -z "$out_dir" ]] && out_dir="/"
  else
    out_dir="."
  fi
else
  filename="peck-$timestamp"
  if [[ "$mode" == "record" ]]; then
    out_dir="$PECK_RECORDING_DIR"
  else
    out_dir="$PECK_SCREENSHOT_DIR"
  fi
fi

# --- Normalize filename extension ----------------------------

if [[ "$filename" == *."$out_format" ]]; then
  filename="${filename%."$out_format"}"
fi


# --- Temp file -----------------------------------------------

tmp_dir="/tmp/peck"
mkdir -p "$tmp_dir"

tmp_file="$tmp_dir/$filename.$out_format"
out_file="$tmp_file"

# --- Screenshot ----------------------------------------------

if [[ "$mode" == "screenshot" ]]; then
  grim -t "$out_format" -g "$(slurp)" "$tmp_file"

  if [[ "$mode_save" == "permanent" ]]; then
    mkdir -p "$out_dir"
    out_file="$out_dir/$filename.$out_format"
    mv "$tmp_file" "$out_file"
  fi
  echo "Screenshot captured and stored at '$out_file'" >&2

  if [[ "$copy_to_clipboard" == "yes" ]]; then
    wl-copy < "$out_file"
    echo "Screenshot was copied to the clipboard." >&2
  fi
fi

# --- Screen Recording ----------------------------------------

if [[ "$mode" == "record" ]]; then
  tmp_mp4="$tmp_dir/$filename.mp4"
  out_file="$tmp_mp4"

  # Ask slurp for a region if needed
  region="$(slurp 2>/dev/null)"
  if [[ -z "$region" ]]; then
    echo "No region selected. Exiting." >&2
    exit 1
  fi

  echo "Recording screen. Press Ctrl+C to stop..." >&2
  wf-recorder -g "$region" -f "$tmp_mp4"

  # Convert to desired output format if different from mp4
  if [[ "$out_format" != "mp4" ]]; then
    final_file="$tmp_dir/$filename.$out_format"

    if [[ "$out_format" == "gif" ]]; then
      ffmpeg -y -i "$tmp_mp4" -vf "fps=15,scale=iw:-1:flags=lanczos" "$final_file"
    else
      ffmpeg -y -i "$tmp_mp4" "$final_file"
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

  echo "Recording saved at '$out_file'" >&2

  if [[ "$copy_to_clipboard" == "yes" ]]; then
    if [[ "$out_format" == "gif" ]]; then
      wl-copy < "$out_file"
    else
      echo "Clipboard copy is only supported for images." >&2
    fi
  fi
fi
