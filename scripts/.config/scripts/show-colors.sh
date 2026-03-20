#!/bin/bash

COLORS_FILE="$HOME/matugen-colors.txt"

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "色ファイルが見つかりません: $COLORS_FILE"
    exit 1
fi

# カラム幅
NAME_WIDTH=35
HEX_WIDTH=9

# ヘッダー
printf "\n"
printf "  %-${NAME_WIDTH}s %-${HEX_WIDTH}s %s\n" "NAME" "HEX" "PREVIEW"
printf "  %s\n" "$(printf '─%.0s' $(seq 1 $((NAME_WIDTH + HEX_WIDTH + 14))))"

while IFS=' ' read -r name hex; do
    [[ -z "$name" || -z "$hex" ]] && continue

    r=$((16#${hex:1:2}))
    g=$((16#${hex:3:2}))
    b=$((16#${hex:5:2}))

    # 明るさで文字色を白か黒に自動切替
    brightness=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
    if (( brightness > 128 )); then
        fg="0;0;0"
    else
        fg="255;255;255"
    fi

    printf "  \e[38;2;%s;%s;%sm%-${NAME_WIDTH}s\e[0m " "$r" "$g" "$b" "$name"
    printf "%s " "$hex"
    printf "\e[48;2;%d;%d;%dm\e[38;2;%sm  %s  \e[0m\n" "$r" "$g" "$b" "$fg" "$hex"

done < "$COLORS_FILE"

printf "\n"
