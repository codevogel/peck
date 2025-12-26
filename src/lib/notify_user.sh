notify_user() {
  local message="$1"
  local silence_this_notification="$2"
  echo "$message" >&2
  command -v notify-send >/dev/null 2>&1 || return 0
  [[ "$PECK_SILENCE_NOTIFICATIONS" == "true" ]] && return 0
  [[ "$silence_this_notification" == "true" ]] && return 0
  notify-send "Peck" "$message"
}
