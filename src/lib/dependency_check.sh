dependency_check() {
  for cmd in grim slurp wf-recorder ffmpeg wl-copy; do
    command -v "$cmd" >/dev/null 2>&1 || { 
        echo "Error: $cmd not found. Please install: grim, slurp, wf-recorder, ffmpeg, and wl-copy." >&2
        exit 1
    }
  done
}
