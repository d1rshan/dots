#!/usr/bin/env bash

set -u

SHADER_PATH="$HOME/.config/hypr/shaders/reading_mode.glsl"
STATE_FILE="/tmp/hypr-reading-mode-on"

if [[ ! -f "$SHADER_PATH" ]]; then
  notify-send "Reading Mode" "Shader missing: $SHADER_PATH"
  exit 1
fi

current_shader="$(hyprshade current 2>/dev/null || true)"

if [[ -f "$STATE_FILE" ]] || [[ "$current_shader" == *"reading_mode"* ]]; then
  hyprshade off >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || true
  rm -f "$STATE_FILE"
  notify-send "Reading Mode" "Off"
  exit 0
fi

hyprshade on "$SHADER_PATH" >/dev/null 2>&1 || {
  notify-send "Reading Mode" "Failed to enable shader"
  exit 1
}

touch "$STATE_FILE"
notify-send "Reading Mode" "On"
