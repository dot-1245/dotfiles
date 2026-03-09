#!/bin/bash
if [ -z "$video_url" ]; then
  echo "yt-x のShellから実行してください"
  exit 1
fi
pkill mpvpaper 2>/dev/null
mpvpaper -o "ytdl=yes loop=inf" '*' "$video_url"
