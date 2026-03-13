#!/bin/bash
# yttui.sh
# CSVプレイリスト → fzf選曲 → yt-dlp → mpv/mpvpaperストリーミング
# 必要: curl, jq, fzf, mpv, mpvpaper, python3, yt-dlp, chafa

# =====================
# 設定
# =====================
PLAYLIST_DIR="$HOME/.config/playlists"
CACHE_DIR="$HOME/.cache/yttui"
THUMB_CACHE="$CACHE_DIR/thumbs"

mkdir -p "$CACHE_DIR" "$THUMB_CACHE"

# yt-dlp共通オプション
YTDL_OPTS="cookies-from-browser=firefox,remote-components=ejs:github"

# =====================
# プレイリスト一覧 (CSVファイル名から)
# =====================
get_playlists() {
    find "$PLAYLIST_DIR" -maxdepth 1 -name "*.csv" | while read -r f; do
        name=$(basename "$f" .csv)
        count=$(tail -n +2 "$f" | wc -l)
        echo -e "${f}\t${name} (${count}曲)"
    done
}

# =====================
# CSV から曲一覧
# TITLE - ARTIST 形式
# =====================
get_tracks() {
    local csv="$1"
    tail -n +2 "$csv" | while IFS=, read -r uri name album artists rest; do
        name="${name//\"/}"
        artists="${artists//\"/}"
        artist="${artists%%;*}"
        echo -e "${name} - ${artist}"
    done
}

# =====================
# fzfで選曲 (プレビューなし)
# =====================
pick_track() {
    echo "$1" | grep -v '^$' | fzf \
        --prompt="▶ 選ぶ > " \
        --height=60% \
        --reverse \
        --cycle \
        --preview="" \
        --preview-window=hidden
}

# =====================
# fzfでプレイリスト選択
# =====================
pick_playlist() {
    echo "$1" | grep -v '^$' | fzf \
        --delimiter='\t' \
        --with-nth=2 \
        --prompt="📋 プレイリスト > " \
        --height=40% \
        --reverse \
        --cycle \
        --preview="" \
        --preview-window=hidden | cut -f1
}

# =====================
# 再生
# =====================
play_track() {
    local track_info="$1"

    echo "🔍 YouTube候補を検索中... ($track_info)"

    local raw_candidates
    raw_candidates=$(yt-dlp \
        --cookies-from-browser firefox \
        "ytsearch5:${track_info}" \
        --flat-playlist \
        --print "%(id)s###%(title)s###%(duration)s" \
        --no-warnings 2>/dev/null)

    if [[ -z "$raw_candidates" ]]; then
        echo "❌ 候補が見つからなかった" >&2
        return 1
    fi

    local candidates=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local id title duration
        id=$(echo "$line" | awk -F"###" '{print $1}')
        title=$(echo "$line" | awk -F"###" '{print $2}')
        duration=$(echo "$line" | awk -F"###" '{print $3}')

        [[ -z "$duration" || "$duration" == "NA" ]] && duration=0
        duration=${duration%%.*}
        [[ ! "$duration" =~ ^[0-9]+$ ]] && duration=0

        candidates+="https://youtube.com/watch?v=${id}	${title}	[$(( duration/60 ))m$(( duration%60 ))s]\n"
    done <<< "$raw_candidates"

    local selected
    selected=$(printf "%b" "$candidates" | grep -v "^$" | fzf \
        --delimiter="	" \
        --with-nth=2,3 \
        --prompt="▶ YouTube候補を選ぶ > " \
        --height=50% \
        --reverse \
        --cycle \
        --preview='
            id=$(echo {} | cut -f1 | grep -oP "v=\K[^&]+")
            thumb="/tmp/fzf_yt_${id}.jpg"
            [ ! -f "$thumb" ] && curl -s "https://img.youtube.com/vi/${id}/mqdefault.jpg" -o "$thumb" 2>/dev/null
            if [ -f "$thumb" ]; then
                printf "\033[2J\033[H"
                chafa --size="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}" "$thumb" 2>/dev/null
            fi
        ' \
        --preview-window=right:40% | cut -f1)

    [[ -z "$selected" ]] && { clear; return 1; }

    clear

    local play_mode
    play_mode=$(printf \
        "🎵 音声のみ\n🎬 MV(映像あり)\n📝 音声+字幕\n🎬📝 MV+字幕\n🖥️  壁紙 動画\n🖥️📝 壁紙 動画+字幕" \
        | fzf --prompt="再生モード > " --height=40% --reverse --cycle)

    echo "▶ 再生中: $track_info"

    case "$play_mode" in
        "🎵 音声のみ")
            mpv --no-video \
                --ytdl-raw-options="${YTDL_OPTS},format=251" \
                "$selected"
            ;;
        "🎬 MV(映像あり)")
            mpv --ytdl-raw-options="${YTDL_OPTS}" \
                "$selected"
            ;;
        "📝 音声+字幕")
            mpv --no-video \
                --ytdl-raw-options="${YTDL_OPTS},format=251" \
                --sub-auto=all --slang=ja,en \
                "$selected"
            ;;
        "🎬📝 MV+字幕")
            mpv --ytdl-raw-options="${YTDL_OPTS}" \
                --sub-auto=all --slang=ja,en \
                "$selected"
            ;;
        "🖥️  壁紙 動画")
            mpvpaper \* \
                -o "--ytdl-raw-options=${YTDL_OPTS} --loop" \
                "$selected"
            ;;
        "🖥️📝 壁紙 動画+字幕")
            mpvpaper \* \
                -o "--ytdl-raw-options=${YTDL_OPTS} --loop --sub-auto=all --slang=ja,en" \
                "$selected"
            ;;
        *)
            return 1
            ;;
    esac
}

# =====================
# メイン
# =====================
main() {
    for cmd in curl fzf mpv mpvpaper python3 yt-dlp chafa; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "❌ ${cmd}が必要: pacman -S ${cmd}" >&2
            exit 1
        fi
    done

    if [[ ! -d "$PLAYLIST_DIR" ]] || [[ -z "$(ls "$PLAYLIST_DIR"/*.csv 2>/dev/null)" ]]; then
        echo "❌ ${PLAYLIST_DIR} にCSVがない" >&2
        exit 1
    fi

    clear
    local mode
    mode=$(printf "📋 プレイリストから選ぶ\n🔍 手動で検索\n🚪 Exit" | fzf \
        --prompt="モード > " \
        --height=30% \
        --reverse \
        --cycle \
        --preview="" \
        --preview-window=hidden)

    case "$mode" in
        "📋 プレイリストから選ぶ")
            local playlists
            playlists=$(get_playlists)
            [[ -z "$playlists" ]] && echo "❌ CSVが見つからない" && sleep 1 && return 0

            while true; do
                clear
                local csv_path
                csv_path=$(pick_playlist "$playlists")
                [[ -z "$csv_path" ]] && return 0

                echo "📥 曲一覧を読み込み中..."
                local tracks
                tracks=$(get_tracks "$csv_path")

                local selected
                selected=$(pick_track "$tracks")
                if [[ -n "$selected" ]]; then
                    clear
                    play_track "$selected"
                fi
            done
            ;;

        "🔍 手動で検索")
            read -rp "検索 > " query
            [[ -z "$query" ]] && return 0
            clear
            play_track "$query"
            ;;

        "🚪 Exit")
            echo "👋 終了"
            exit 0
            ;;

        *)
            exit 0
            ;;
    esac
}

# =====================
# ループ実行
# =====================
while true; do
    main "$@"
done
