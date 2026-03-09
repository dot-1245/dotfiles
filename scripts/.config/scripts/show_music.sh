#!/bin/bash

# --- 依存ソフトチェック用メモ ---
# playerctl, kitty, curl, bc, nerd-fonts (JetBrainsMono等)

# --- 設定 ---
BAR_WIDTH=40        # 再生バーの長さ
VOL_BAR_WIDTH=10    # 音量バーの長さ
COVER_SIZE="20x20@2x2"
PREV_ID=""

# 代替画面モードへ切り替え、終了時に画面復元 & 一時ファイル削除
tput smcup
trap "tput rmcup; rm -f /tmp/cover.png; exit" INT TERM
clear

# 時間フォーマット関数 (秒 -> MM:SS)
convert_time() {
    local t=${1:-0}
    printf "%02d:%02d" $((t / 60)) $((t % 60))
}

while true; do
    # 1. アクティブな（Playing状態の）プレイヤーを動的に特定
    PLAYER_NAME=$(playerctl -l 2>/dev/null | while read -r p; do
        if [ "$(playerctl -p "$p" status 2>/dev/null)" = "Playing" ]; then
            echo "$p"
            break
        fi
    done)
    
    # Playing がなければリストの先頭を使用
    [ -z "$PLAYER_NAME" ] && PLAYER_NAME=$(playerctl -l 2>/dev/null | head -n 1)

    # プレイヤーがいなければ待機画面
    if [ -z "$PLAYER_NAME" ]; then
        tput cup 0 0
        echo -e "\n  \e[1;31m󰝛 No active player found.\e[0m\e[K"
        sleep 2
        continue
    fi

    # --- 2. データ取得 ---
    CUR_ID=$(playerctl -p "$PLAYER_NAME" metadata mpris:trackid 2>/dev/null)
    STATUS=$(playerctl -p "$PLAYER_NAME" status 2>/dev/null)
    TITLE=$(playerctl -p "$PLAYER_NAME" metadata xesam:title 2>/dev/null)
    ARTIST=$(playerctl -p "$PLAYER_NAME" metadata xesam:artist 2>/dev/null)
    ALBUM=$(playerctl -p "$PLAYER_NAME" metadata xesam:album 2>/dev/null)
    URL=$(playerctl -p "$PLAYER_NAME" metadata xesam:url 2>/dev/null)
    SHUFFLE=$(playerctl -p "$PLAYER_NAME" shuffle 2>/dev/null)
    LOOP=$(playerctl -p "$PLAYER_NAME" loop 2>/dev/null)
    
    # 【修正】音量取得ロジック（0.000000-1.000000 を 0-100 に確実に変換）
    VOL_RAW=$(playerctl -p "$PLAYER_NAME" volume 2>/dev/null)
    if [[ "$VOL_RAW" == "1.0"* ]]; then
        VOL_PERCENT=100
    elif [[ "$VOL_RAW" == "0.0"* || -z "$VOL_RAW" ]]; then
        VOL_PERCENT=0
    else
        # 小数点第2位までを抽出して整数にする（例: 0.85... -> 85）
        VOL_PERCENT=$(echo "$VOL_RAW" | cut -d. -f2 | cut -c1-2 | sed 's/^0//')
        # sedで0を消して空になった場合は0にする
        [ -z "$VOL_PERCENT" ] && VOL_PERCENT=0
    fi

    # 再生時間と進捗
    POS_SEC=$(playerctl -p "$PLAYER_NAME" position 2>/dev/null | cut -d. -f1)
    LEN_USEC=$(playerctl -p "$PLAYER_NAME" metadata mpris:length 2>/dev/null)
    LEN_SEC=$(( ${LEN_USEC:-0} / 1000000 ))

    # --- 3. 重い処理（画像）は曲が変わった時だけ ---
    if [ "$CUR_ID" != "$PREV_ID" ]; then
        ART_URL=$(playerctl -p "$PLAYER_NAME" metadata mpris:artUrl 2>/dev/null)
        rm -f /tmp/cover.png
        if [[ "$ART_URL" == http* ]]; then
            curl -s "$ART_URL" -o /tmp/cover.png
        elif [[ "$ART_URL" == file://* ]]; then
            cp "${ART_URL#file://}" /tmp/cover.png
        fi
        PREV_ID="$CUR_ID"
        # kitty icat で描画
        kitty +kitten icat --clear --place $COVER_SIZE /tmp/cover.png 2>/dev/null
    fi

    # --- 4. バーの生成（0対策ガード付き） ---
    # プログレスバー
    SAFE_LEN=${LEN_SEC:-1}; [ "$SAFE_LEN" -eq 0 ] && SAFE_LEN=1
    PROGRESS=$(( ${POS_SEC:-0} * BAR_WIDTH / SAFE_LEN ))
    [ "$PROGRESS" -gt "$BAR_WIDTH" ] && PROGRESS=$BAR_WIDTH
    
    FILL=$( [ "$PROGRESS" -gt 0 ] && printf "%${PROGRESS}s" | tr ' ' '=' )
    EMPTY=$( [ "$((BAR_WIDTH - PROGRESS))" -gt 0 ] && printf "%$((BAR_WIDTH - PROGRESS))s" | tr ' ' '-' )

    # 音量バー
    VOL_FILLED=$(( VOL_PERCENT * VOL_BAR_WIDTH / 100 ))
    [ "$VOL_FILLED" -gt "$VOL_BAR_WIDTH" ] && VOL_FILLED=$VOL_BAR_WIDTH
    
    V_FILL=$( [ "$VOL_FILLED" -gt 0 ] && printf "%${VOL_FILLED}s" | tr ' ' '=' )
    V_EMPTY=$( [ "$((VOL_BAR_WIDTH - VOL_FILLED))" -gt 0 ] && printf "%$((VOL_BAR_WIDTH - VOL_FILLED))s" | tr ' ' '-' )

    # --- 5. 描画 ---
    tput cup 0 0
    echo -e "\n  \e[1;33m󰎈 Music System Status\e[0m"
    echo -e "\n\n\n\n\n\n\n\n\n\n\n" # icat表示用のマージン

    echo -e "  \e[1;32m󰎆 Title    :\e[0m ${TITLE:0:50}\e[K"
    echo -e "  \e[1;34m󰗡 Artist   :\e[0m ${ARTIST:0:50}\e[K"
    echo -e "  \e[0;90m󰀥 Album    :\e[0m ${ALBUM:0:50}\e[K"
    echo -e "  \e[1;35m󰓇 App      :\e[0m $PLAYER_NAME ($STATUS)\e[K"
    echo -e "  \e[1;36m󰒝 Shuffle  :\e[0m $SHUFFLE\e[K"
    echo -e "  \e[1;36m󰑐 Loop     :\e[0m $LOOP\e[K"
    echo -e "  \e[1;33m󰕾 Volume   :\e[0m ${V_FILL}${V_EMPTY} ${VOL_PERCENT}%\e[K"
    echo -e "  \e[0;90m URL      :\e[0m ${URL:0:65}\e[K"
    echo -e "\n"
    echo -ne "  \e[1;37m$(convert_time $POS_SEC) ${FILL}\e[0;90m${EMPTY}\e[1;37m $(convert_time $LEN_SEC)\e[0m\e[K"

    sleep 1
done