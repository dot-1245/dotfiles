#!/bin/bash
# matugen-mpvpaper.sh
# mpvpaperが動いてる間、曲が変わるたびにサムネをmatugenに渡す
# 必要: playerctl, yt-dlp, matugen, imagemagick, swww
THUMB_DIR="$HOME/.cache/matugen-mpvpaper"
COLORS_CONF="$HOME/.config/hypr/colors.conf"
mkdir -p "$THUMB_DIR"
get_current_url() {
    playerctl -p mpv metadata xesam:url 2>/dev/null
}
apply_matugen() {
    local url="$1"
    local thumb="$THUMB_DIR/thumb"
    rm -f "$thumb".*
    echo "🎨 サムネ取得中: $url"
    if [[ "$url" == *"youtube.com"* || "$url" == *"youtu.be"* ]]; then
        yt-dlp --write-thumbnail --skip-download \
            --no-warnings \
            --cookies-from-browser firefox \
            --remote-components ejs:github \
            -o "$thumb" \
            "$url" 2>/dev/null
    else
        if [[ "$url" == file://* ]]; then
            local file_path="${url#file://}"
            file_path=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$file_path'))")
            ffmpeg -y -ss 5 -i "$file_path" -vframes 1 "$thumb.jpg" -loglevel quiet 2>/dev/null
        else
            local art_url
            art_url=$(playerctl -p mpv metadata mpris:artUrl 2>/dev/null)
            if [[ "$art_url" == file://* ]]; then
                cp "${art_url#file://}" "$thumb.jpg" 2>/dev/null
            elif [[ -n "$art_url" ]]; then
                curl -s -o "$thumb.jpg" "$art_url" 2>/dev/null
            fi
        fi
    fi
    local thumb_file
    thumb_file=$(ls "$thumb".* 2>/dev/null | head -n 1)
    if [[ -z "$thumb_file" ]]; then
        echo "❌ サムネ取得失敗" >&2
        return 1
    fi
    # 彩度の平均を取得してモノクロ判定
    local saturation
    saturation=$(convert "$thumb_file" -colorspace HSL -channel S \
        -separate -format "%[fx:mean]" info: 2>/dev/null)
    local scheme
    if awk "BEGIN {exit !($saturation < 0.15)}"; then
        echo "🖤 モノクロ検出 → scheme-monochrome"
        scheme="scheme-monochrome"
    else
        scheme="scheme-vibrant"
    fi
    echo "🎨 matugen適用: $thumb_file ($scheme)"
    # matugen image "$thumb_file" --type "$scheme"
    matugen image "$thumb_file" --type "$scheme" --source-color-index 0
    # swww clearをmatugenの背景色で塗る
    if [[ -f "$COLORS_CONF" ]]; then
        local bg_color
        bg_color=$(grep '^\$background' "$COLORS_CONF" | grep -oP '[0-9a-fA-F]{6}')
        bg_color="${bg_color:-000000}"
        swww clear "${bg_color}" 2>/dev/null
    fi
    # waybar再起動
    # killall -SIGUSR2 waybar 2>/dev/null
    hyprctl reload
    swaync-client --reload-config 2>/dev/null
    pkill -USR1 kitty 2>/dev/null
    pkill -SIGUSR1 cava 2>/dev/null
	spicetify apply
}
echo "👀 mpvpaper監視開始..."
PREV_URL=""
while true; do
    if ! pgrep -x mpvpaper > /dev/null; then
        PREV_URL=""
        sleep 3
        continue
    fi
    CURRENT_URL=$(get_current_url)
    if [[ -n "$CURRENT_URL" && "$CURRENT_URL" != "$PREV_URL" ]]; then
        apply_matugen "$CURRENT_URL"
        PREV_URL="$CURRENT_URL"
    fi
    sleep 3
done
