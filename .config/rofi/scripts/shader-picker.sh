#!/usr/bin/env bash

# ────────────────────────────────────────────────────────────────────
#  「✦ SHADER PICKER ✦ 」
# ────────────────────────────────────────────────────────────────────
# INTERACTIVE SHADER SELECTOR USING ROFI AND HYPRSHADE
# ────────────────────────────────────────────────────────────────────

set -u

ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/themes/shader-menu.rasi}"
ICON="󰛨"

# Check dependencies
for cmd in rofi hyprshade notify-send; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    notify-send "Shader Picker" "Missing dependency: $cmd"
    exit 1
  fi
done

# Function to prettify names
prettify() {
  local name="$1"
  # Standard prettify
  name=$(echo "$name" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
  # Specific override for Blue Light Filter
  name="${name/Blue Light Filter/Blue Light}"
  echo "$name"
}

# Get shaders
mapfile -t raw_shaders < <(hyprshade ls | sed 's/^[ *]*//')

options=("$ICON  Normal")
actual_names=("Normal")

# Build options
for i in "${!raw_shaders[@]}"; do
  s="${raw_shaders[$i]}"
  pretty_name=$(prettify "$s")
  options+=("$ICON  $pretty_name")
  actual_names+=("$s")
done

# Show Rofi menu (removed -a flag for active highlight)
CHOICE_INDEX=$(
  printf '%s\n' "${options[@]}" |
  rofi -dmenu -i -p "Shaders" -theme "$ROFI_THEME" -format i
)

[[ -z "$CHOICE_INDEX" ]] && exit 0

SELECTION="${actual_names[$CHOICE_INDEX]}"

if [[ "$SELECTION" == "Normal" ]]; then
  hyprshade off
  notify-send "Shader Picker" "Shader disabled"
  exit 0
fi

if hyprshade on "$SELECTION" >/dev/null 2>&1; then
  notify-send "Shader Picker" "Enabled: $(prettify "$SELECTION")"
else
  notify-send "Shader Picker" "Failed to enable: $SELECTION"
fi
