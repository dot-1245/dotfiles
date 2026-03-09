#!/bin/bash
# Spotifyの監視とアルバムアート付き通知
playerctl metadata --format '{{mpris:artUrl}}' --follow | while read -r url; do
    if [ -n "$url" ]; then
        wget -q -O /tmp/spotify_cover.png "$url"
        notify-send -i /tmp/spotify_cover.png "Now Playing" "$(playerctl --player=spotify metadata --format '{{title}}\n{{artist}}')" -a "Spotify"

        # 【ここにMatugenのコマンドを足すと、曲ごとに色を変えられます！】
        # matugen image /tmp/spotify_cover.png
    fi
done
