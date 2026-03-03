#!/usr/bin/env bash

used_pct=$(free | awk '/Mem:/ { printf "%d", ($3/$2)*100 }')

if [ "$used_pct" -lt 20 ]; then
  pie="○"
elif [ "$used_pct" -lt 40 ]; then
  pie="◔"
elif [ "$used_pct" -lt 60 ]; then
  pie="◑"
elif [ "$used_pct" -lt 80 ]; then
  pie="◕"
else
  pie="●"
fi

printf '{"text":"%s %s%%","tooltip":"RAM usage: %s%%"}\n' "$pie" "$used_pct" "$used_pct"
