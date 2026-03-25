#!/usr/bin/env bash

set -u

SHADER_PATH="$HOME/.config/hypr/shaders/night_light.glsl"
STATE_FILE="/tmp/hypr-night-light-on"

if [[ ! -f "$SHADER_PATH" ]]; then
  notify-send "Night Light" "Shader missing: $SHADER_PATH"
  exit 1
fi

current_shader="$(hyprshade current 2>/dev/null || true)"

if [[ -f "$STATE_FILE" ]] || [[ "$current_shader" == *"night_light"* ]]; then
  hyprshade off >/dev/null 2>&1 || true
  rm -f "$STATE_FILE"
  notify-send "Night Light" "Off"
  exit 0
fi

hyprshade on "$SHADER_PATH" >/dev/null 2>&1 || {
  notify-send "Night Light" "Failed to enable"
  exit 1
}

touch "$STATE_FILE"
notify-send "Night Light" "On"
