#!/bin/bash
NUM=$1

# フォーカス中のモニターを取得
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')

if [ "$MONITOR" = "DP-1" ]; then
    hyprctl dispatch workspace $NUM
else
    hyprctl dispatch workspace $((NUM + 10))
fi
