#!/usr/bin/env bash

set -euo pipefail

EMOJI_COLUMNS="${EMOJI_COLUMNS:-6}"
EMOJI_LINES="${EMOJI_LINES:-7}"

for cmd in rofi wl-copy notify-send; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    notify-send "Emoji Picker" "Missing dependency: $cmd"
    exit 1
  fi
done

if ! rofi -modi emoji -show emoji -help >/dev/null 2>&1; then
  notify-send "Emoji Picker" "rofi-emoji mode is not available"
  exit 1
fi

selection="$(
  rofi -modi emoji -show emoji -emoji-format '{emoji}' \
    -p "Emoji" \
    -theme "$HOME/.config/rofi/themes/glass.rasi" \
    -theme-str "
    listview {
      layout: vertical;
      columns: ${EMOJI_COLUMNS};
      fixed-columns: true;
      lines: ${EMOJI_LINES};
      dynamic: false;
      fixed-height: true;
    }

    element {
      orientation: horizontal;
      children: [ element-text ];
    }

    element-text {
      horizontal-align: 0.5;
    }"
)"

[[ -z "$selection" ]] && exit 0

printf '%s' "$selection" | wl-copy
notify-send "Emoji Picker" "Copied $selection"
