#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  「✦ POMODORO TIMER ✦ 」
# ─────────────────────────────────────────────────────────────────────
# WAYBAR MODULE FOR POMODORO-STYLE BREAK TIMER
# ─────────────────────────────────────────────────────────────────────

STATE_FILE=/tmp/break_state
PRESET_FILE=/tmp/break_preset
PAUSED_FILE=/tmp/break_paused
SESSION_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro/sessions.log"

MIN_PRESET=5
MAX_PRESET=120
STEP_PRESET=5
DEFAULT_PRESET=20

get_preset_minutes() {
  if [ -f "$PRESET_FILE" ]; then
    preset=$(cat "$PRESET_FILE" 2>/dev/null)
    case "$preset" in
      ''|*[!0-9]*)
        ;;
      *)
        if [ "$preset" -ge "$MIN_PRESET" ] && [ "$preset" -le "$MAX_PRESET" ]; then
          printf '%s\n' "$preset"
          return
        fi
        ;;
    esac
  fi
  printf '%s\n' "$DEFAULT_PRESET"
}

set_preset_minutes() {
  printf '%s\n' "$1" >"$PRESET_FILE"
}

ensure_log_dir() {
  mkdir -p "$(dirname "$SESSION_LOG")"
}

log_completed_session() {
  ensure_log_dir
  printf '%s %s\n' "$(date +%F)" "$1" >>"$SESSION_LOG"
}

adjust_preset() {
  current=$(get_preset_minutes)
  direction=$1

  if [ -f "$STATE_FILE" ]; then
    exit 0
  fi

  if [ "$direction" = "next" ]; then
    new_preset=$((current + STEP_PRESET))
    if [ "$new_preset" -gt "$MAX_PRESET" ]; then
      new_preset=$MAX_PRESET
    fi
  else
    new_preset=$((current - STEP_PRESET))
    if [ "$new_preset" -lt "$MIN_PRESET" ]; then
      new_preset=$MIN_PRESET
    fi
  fi

  set_preset_minutes "$new_preset"
}

start_timer() {
  duration_minutes=$(get_preset_minutes)
  duration_seconds=$((duration_minutes * 60))
  end_time=$(($(date +%s) + duration_seconds))
  echo "$end_time" >"$STATE_FILE"
  rm -f "$PAUSED_FILE"
}

pause_timer() {
  if [ ! -f "$STATE_FILE" ] || [ -f "$PAUSED_FILE" ]; then
    return
  fi

  now=$(date +%s)
  end_time=$(cat "$STATE_FILE" 2>/dev/null)
  remaining=$((end_time - now))

  if [ "$remaining" -le 0 ]; then
    rm -f "$STATE_FILE" "$PAUSED_FILE"
    return
  fi

  echo "$remaining" >"$STATE_FILE"
  touch "$PAUSED_FILE"
}

resume_timer() {
  if [ ! -f "$STATE_FILE" ] || [ ! -f "$PAUSED_FILE" ]; then
    return
  fi

  remaining=$(cat "$STATE_FILE" 2>/dev/null)
  case "$remaining" in
    ''|*[!0-9]*)
      rm -f "$STATE_FILE" "$PAUSED_FILE"
      return
      ;;
  esac

  end_time=$(($(date +%s) + remaining))
  echo "$end_time" >"$STATE_FILE"
  rm -f "$PAUSED_FILE"
}

stop_timer() {
  rm -f "$STATE_FILE" "$PAUSED_FILE"
  notify-send "Break Time" "Timer stopped"
}

print_json() {
  text=$1
  tooltip=$2
  printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$tooltip"
}

case "$1" in
start)
  start_timer
  exit 0
  ;;

stop)
  stop_timer
  exit 0
  ;;

toggle)
  if [ -f "$STATE_FILE" ]; then
    if [ -f "$PAUSED_FILE" ]; then
      resume_timer
    else
      pause_timer
    fi
  else
    start_timer
  fi
  exit 0
  ;;

preset-next)
  adjust_preset next
  exit 0
  ;;

preset-prev)
  adjust_preset prev
  exit 0
  ;;
esac

duration_minutes=$(get_preset_minutes)
duration_seconds=$((duration_minutes * 60))

if [ ! -f "$STATE_FILE" ]; then
  print_json "${duration_minutes}m" "Scroll to adjust, click to start (${duration_minutes} min)"
  exit 0
fi

if [ -f "$PAUSED_FILE" ]; then
  remaining=$(cat "$STATE_FILE" 2>/dev/null)
  case "$remaining" in
    ''|*[!0-9]*)
      rm -f "$STATE_FILE" "$PAUSED_FILE"
      print_json "${duration_minutes}m" "Scroll to adjust, click to start (${duration_minutes} min)"
      exit 0
      ;;
  esac
else
  now=$(date +%s)
  end_time=$(cat "$STATE_FILE" 2>/dev/null)
  remaining=$((end_time - now))
fi

if [ $remaining -le 0 ]; then
  rm -f "$STATE_FILE" "$PAUSED_FILE"
  log_completed_session "$duration_minutes"
  notify-send "Break Time" "Timer finished (${duration_minutes} minutes)"
  print_json "${duration_minutes}m" "Scroll to adjust, click to start (${duration_minutes} min)"
  exit 0
fi

min=$((remaining / 60))
sec=$((remaining % 60))
if [ -f "$PAUSED_FILE" ]; then
  print_json "⏸ $(printf '%02d:%02d' "$min" "$sec")" "Paused: click to resume, right click to stop"
else
  print_json "$(printf '%02d:%02d' "$min" "$sec")" "Running: ${duration_minutes} min preset"
fi
