#!/usr/bin/env bash
# Clipboard picker for rofi (mixed text + images in one list)

set -euo pipefail

ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/themes/glass.rasi}"
MAX_PREVIEW_LEN="${MAX_PREVIEW_LEN:-110}"

for cmd in rofi cliphist wl-copy notify-send file wc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    notify-send "Clipboard Picker" "Missing dependency: $cmd"
    exit 1
  fi
done

mapfile -t raw_entries < <(cliphist list)

if ((${#raw_entries[@]} == 0)); then
  notify-send "Clipboard Picker" "Clipboard history is empty"
  exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

truncate_preview() {
  local s="$1"
  if ((${#s} > MAX_PREVIEW_LEN)); then
    printf '%s...' "${s:0:MAX_PREVIEW_LEN}"
  else
    printf '%s' "$s"
  fi
}

human_size() {
  local bytes="$1"
  if ((bytes < 1024)); then
    printf '%d B' "$bytes"
  elif ((bytes < 1024 * 1024)); then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KB", b / 1024 }'
  else
    awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / (1024 * 1024) }'
  fi
}

mime_to_ext() {
  case "$1" in
  image/png) echo "png" ;;
  image/jpeg) echo "jpg" ;;
  image/webp) echo "webp" ;;
  image/gif) echo "gif" ;;
  image/bmp) echo "bmp" ;;
  image/tiff) echo "tiff" ;;
  image/svg+xml) echo "svg" ;;
  *) echo "img" ;;
  esac
}

is_binary_like() {
  local preview="$1"
  [[ "$preview" =~ ^\[\[.*\]\]$ || "$preview" =~ ^\[[[:space:]]*image/ ]]
}

build_rofi_input() {
  local i line preview decoded mime ext img bytes type clean

  for i in "${!raw_entries[@]}"; do
    line="${raw_entries[$i]}"
    preview="${line#*$'\t'}"

    if is_binary_like "$preview"; then
      decoded="$tmpdir/entry-$i.bin"
      if printf '%s' "$line" | cliphist decode >"$decoded" 2>/dev/null; then
        mime=$(file --mime-type -b "$decoded" 2>/dev/null || true)
        if [[ "$mime" == image/* ]]; then
          ext=$(mime_to_ext "$mime")
          img="$tmpdir/entry-$i.$ext"
          mv "$decoded" "$img"
          bytes=$(wc -c <"$img" | tr -d ' ')
          type="${mime#image/}"
          printf '%s\0icon\x1f%s\n' "${type^^}  $(human_size "$bytes")" "$img"
          continue
        fi
      fi
      printf '%s\n' "Binary data"
      continue
    fi

    clean="${preview//$'\n'/ }"
    clean="${clean//$'\r'/ }"
    clean="${clean//$'\t'/ }"
    # Use a themed icon name for text rows to avoid empty icon space.
    printf '%s\0icon\x1f%s\n' "$(truncate_preview "$clean")" "gtk-paste"
  done
}

selection_index=$(
  build_rofi_input | rofi -dmenu -i -show-icons -format i \
    -theme "$ROFI_THEME" \
    -theme-str '
    entry {
      placeholder: "Search clipboard history...";
    }

    listview {
      lines: 9;
    }

    element-icon {
      size: 1.8em;
    }

    element-text {
      vertical-align: 0.5;
    }'
)

[[ -z "$selection_index" ]] && exit 0

if ! [[ "$selection_index" =~ ^[0-9]+$ ]] || ((selection_index >= ${#raw_entries[@]})); then
  exit 1
fi

printf '%s' "${raw_entries[$selection_index]}" | cliphist decode | wl-copy
notify-send "Clipboard" "Copied selection from history"
