#!/bin/bash
WALLPAPER_DIR="$HOME/.config/wallpaper"
VIDEO_DIR="$WALLPAPER_DIR/Video"
HYPRLOCK_CONF="$HOME/.config/hypr/hyprlock.conf"
COLORS_CONF="$HOME/.config/hypr/colors.conf"
THUMB_DIR="/tmp/wallpaper_thumbs"
mkdir -p "$THUMB_DIR"

generate_entries() {
  {
    find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \
      -iregex ".*\.\(jpg\|jpeg\|png\|gif\|bmp\|webp\)" \
      -printf "%T@ IMAGE %p\n"
    find "$VIDEO_DIR" -maxdepth 1 -type f \
      -iregex ".*\.\(mp4\|mkv\|webm\|mov\|avi\)" \
      -printf "%T@ VIDEO %p\n"
  } | sort -rn | while read -r _ type f; do
    name=$(basename "$f")
    if [[ "$type" == "VIDEO" ]]; then
      thumb="$THUMB_DIR/${name}.jpg"
      if [[ ! -f "$thumb" ]]; then
        ffmpeg -y -i "$f" -ss 00:00:03 -vframes 1 -vf scale=320:-1 "$thumb" 2>/dev/null
      fi
      [[ -f "$thumb" ]] && icon="$thumb" || icon="$f"
      printf "Video/%s\0icon\x1f%s\n" "$name" "$icon"
    else
      printf "%s\0icon\x1f%s\n" "$name" "$f"
    fi
  done
}

SELECTED=$(generate_entries | rofi -dmenu -show-icons -theme ~/.config/rofi/wallpaper.rasi)
[[ -z "$SELECTED" ]] && exit 0

FULL_PATH="$WALLPAPER_DIR/$SELECTED"

# matugenの背景色を取得（なければ黒）
if [[ -f "$COLORS_CONF" ]]; then
    BG_COLOR=$(grep '^\$background' "$COLORS_CONF" | grep -oP '[0-9a-fA-F]{6}' | head -c 6)
    BG_COLOR="${BG_COLOR:-000000}"
else
    BG_COLOR="000000"
fi

if [[ "$SELECTED" == Video/* ]]; then
  pkill mpvpaper 2>/dev/null
  swww clear "${BG_COLOR}" 2>/dev/null
  mpvpaper -o "loop" '*' "$FULL_PATH" &
else
  pkill mpvpaper 2>/dev/null
  swww img "$FULL_PATH" --transition-type fade
  matugen image "$FULL_PATH"
  BG_COLOR=$(grep '^\$background' "$COLORS_CONF" | grep -oP '[0-9a-fA-F]{6}' | head -c 6)
  kill -USR1 $(pidof kitty) 2>/dev/null
  kill -SIGUSR1 $(pidof cava) 2>/dev/null
  killall -SIGUSR2 waybar 2>/dev/null
fi

if [[ -f "$HYPRLOCK_CONF" ]]; then
  sed -i "s|path = .*|path = $FULL_PATH|" "$HYPRLOCK_CONF"
fi

hyprctl reload
swaync-client --reload-config 2>/dev/null
