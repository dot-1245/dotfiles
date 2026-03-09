#!/bin/bash

# --- 環境変数の注入 ---
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
[ -z "$WAYLAND_DISPLAY" ] && export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR/wayland-* 2>/dev/null | head -n 1 | xargs basename)

pkill -x fuzzel 2>/dev/null

while true; do
    # 1. アクティブプレイヤーの特定
    PLAYER_NAME=$(playerctl -l 2>/dev/null | while read -r p; do
        if [ "$(playerctl -p "$p" status 2>/dev/null)" = "Playing" ]; then
            echo "$p"; break
        fi
    done)
    [ -z "$PLAYER_NAME" ] && PLAYER_NAME=$(playerctl -l 2>/dev/null | head -n 1)

    # --- ステータス取得 ---
    STATUS=$(playerctl -p "$PLAYER_NAME" status 2>/dev/null || echo "Stopped")
    SHUFFLE=$(playerctl -p "$PLAYER_NAME" shuffle 2>/dev/null || echo "Off")
    LOOP=$(playerctl -p "$PLAYER_NAME" loop 2>/dev/null || echo "None")

    # --- 音量取得 ---
    VOL_RAW=$(playerctl -p "$PLAYER_NAME" volume 2>/dev/null)

    if [[ "$VOL_RAW" == "1.0"* ]]; then
        VOL_PERCENT=100
    elif [[ "$VOL_RAW" == "0.0"* || "$VOL_RAW" == "0" ]]; then
        VOL_PERCENT=0
    else
        VOL_PERCENT=$(echo "${VOL_RAW//./}" | sed 's/^0//' | cut -c1-2)
        [ -z "$VOL_PERCENT" ] && VOL_PERCENT=0
    fi

    # --- アイコンとラベルの動的設定 ---
    [[ "$STATUS" == "Playing" ]] && P_ICON="󰏦" || P_ICON="󰐊"
    [[ "$SHUFFLE" == "On" ]]     && S_ICON="󰒞" || S_ICON="󰒝"

    case "$LOOP" in
        "Playlist") L_ICON="󰑘"; NEXT_L="Track" ;;
        "Track")    L_ICON="󰑗"; NEXT_L="None" ;;
        *)          L_ICON="󰑖"; NEXT_L="Playlist" ;;
    esac

    # --- メタデータ ---
    TITLE=$(playerctl -p "$PLAYER_NAME" metadata xesam:title 2>/dev/null \
        | awk '{print substr($0,1,40)}' | tr -d '"\\')
    ARTIST=$(playerctl -p "$PLAYER_NAME" metadata xesam:artist 2>/dev/null \
        | awk '{print substr($0,1,30)}' | tr -d '"\\')
    ALBUM=$(playerctl -p "$PLAYER_NAME" metadata xesam:album 2>/dev/null \
        | awk '{print substr($0,1,30)}' | tr -d '"\\')
    POS=$(playerctl -p "$PLAYER_NAME" metadata --format "{{ duration(position) }} / {{ duration(mpris:length) }}" 2>/dev/null)


# --- アイコンとラベルの動的設定 (次のアクションを明示) ---
    if [[ "$STATUS" == "Playing" ]]; then
        P_ICON="󰏦"; P_LABEL="Pause"
    else
        P_ICON="󰐊"; P_LABEL="Play"
    fi

    if [[ "$SHUFFLE" == "On" ]]; then
        S_ICON="󰒞"; S_LABEL="Turn Shuffle OFF"
    else
        S_ICON="󰒝"; S_LABEL="Turn Shuffle ON"
    fi

    case "$LOOP" in
        "Playlist") L_ICON="󰑘"; NEXT_L="Track";    L_LABEL="Set Loop to Track" ;;
        "Track")    L_ICON="󰑗"; NEXT_L="None";     L_LABEL="Disable Loop" ;;
        *)          L_ICON="󰑖"; NEXT_L="Playlist"; L_LABEL="Set Loop to Playlist" ;;
    esac

    # --- メニュー構築 ---
    # 左側に「何をするか」、右側の括弧に「今の状態」を配置して視認性を上げる
    MENU="${P_ICON}  ${P_LABEL} \n"
    MENU+="󰒭  Next Track\n"
    MENU+="󰒮  Previous Track\n"
    MENU+="${S_ICON}  ${S_LABEL} \n"
    MENU+="${L_ICON}  ${L_LABEL} \n"
    MENU+="󰝝  Volume UP +10% \t(Now: ${VOL_PERCENT}%)\n"
    MENU+="󰝞  Volume DOWN -10% \t(Now: ${VOL_PERCENT}%)"

    # --- Fuzzel実行 ---
    CHOSEN=$(echo -e "$MENU" | fuzzel \
        --dmenu \
        --anchor=bottom-right \
        --width=40 \
        --lines=7 \
        --index \
        --placeholder="󰎈 $TITLE by $ARTIST ($ALBUM)")

    [[ -z "$CHOSEN" ]] && break

    case "$CHOSEN" in
        0) playerctl -p "$PLAYER_NAME" play-pause ;;
        1) playerctl -p "$PLAYER_NAME" next ;;
        2) playerctl -p "$PLAYER_NAME" previous ;;
        3) playerctl -p "$PLAYER_NAME" shuffle Toggle ;;
        4) playerctl -p "$PLAYER_NAME" loop "$NEXT_L" ;;
        5) playerctl -p "$PLAYER_NAME" volume 0.1+ ;;
        6) playerctl -p "$PLAYER_NAME" volume 0.1- ;;
        *) break ;;
    esac

    sleep 0.1
done
