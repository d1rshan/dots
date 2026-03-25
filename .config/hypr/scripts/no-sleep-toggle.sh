#!/usr/bin/env bash

set -u

PID_FILE="/tmp/hypr-no-sleep-toggle.pid"
REASON="Hyprland no-sleep toggle"
HYPRIDLE_STATE_FILE="/tmp/hypr-no-sleep-hypridle-was-running"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    if [[ -f "$HYPRIDLE_STATE_FILE" ]]; then
      hypridle >/dev/null 2>&1 &
      rm -f "$HYPRIDLE_STATE_FILE"
    fi
    notify-send "No Sleep" "Off (idle/lock restored)"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

if pgrep -x hypridle >/dev/null 2>&1; then
  pkill -x hypridle >/dev/null 2>&1 || true
  touch "$HYPRIDLE_STATE_FILE"
fi

systemd-inhibit --what=idle:sleep --mode=block --why="$REASON" \
  bash -c 'while true; do sleep 3600; done' >/dev/null 2>&1 &
pid="$!"
echo "$pid" >"$PID_FILE"
notify-send "No Sleep" "On (idle/lock disabled)"
