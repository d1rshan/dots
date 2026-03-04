#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────
#  「✦ WALLPAPER PICKER ✦ 」
# ────────────────────────────────────────────────────────────────────
# INTERACTIVE WALLPAPER SELECTOR USING ROFI WITH PYWAL COLOR GENERATION
# ────────────────────────────────────────────────────────────────────

set -u

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/walls}"
HYPRPAPER_CONF="${HYPRPAPER_CONF:-$HOME/.config/hypr/hyprpaper.conf}"
HYPRLOCK_CONF="${HYPRLOCK_CONF:-$HOME/.config/hypr/hyprlock.conf}"

persist_wallpaper_path() {
  local conf_file="$1"
  local new_path="$2"
  local escaped_path

  [[ -f "$conf_file" ]] || return 0

  escaped_path=$(printf '%s' "$new_path" | sed 's/[\/&]/\\&/g')
  sed -i "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = $escaped_path|" "$conf_file"
}

CHOICE=$(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) |
    sort |
    while IFS= read -r f; do
      printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
    done |
    rofi -dmenu -i -show-icons \
      -theme "$HOME/.config/rofi/themes/wallpaper-grid.rasi"
)

[[ -z "$CHOICE" ]] && exit 0

WALLPAPER="$WALLPAPER_DIR/$CHOICE"

[[ ! -f "$WALLPAPER" ]] && exit 1

hyprctl hyprpaper preload "$WALLPAPER" >/dev/null 2>&1 || true
hyprctl hyprpaper wallpaper ",$WALLPAPER" || {
  notify-send "Wallpaper Error" "hyprpaper failed"
  exit 1
}

wal -i "$WALLPAPER" -n -q
persist_wallpaper_path "$HYPRPAPER_CONF" "$WALLPAPER"
persist_wallpaper_path "$HYPRLOCK_CONF" "$WALLPAPER"

notify-send "Wallpaper Updated" "$CHOICE" -i "$WALLPAPER"
