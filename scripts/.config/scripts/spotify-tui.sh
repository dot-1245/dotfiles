#!/bin/bash
# spotify-tui.sh
# Spotify OAuth → fzf選曲 → yt-dlp → mpv/mpvpaperストリーミング
# 必要: curl, jq, fzf, mpv, mpvpaper, python3, yt-dlp, chafa

# =====================
# 設定 (ここだけ変える)
# =====================
CLIENT_ID=""
CLIENT_SECRET=""
REDIRECT_URI="http://127.0.0.1:8888/callback"
CACHE_DIR="$HOME/.cache/spotify-tui"
TOKEN_CACHE="$CACHE_DIR/token"
THUMB_CACHE="$CACHE_DIR/thumbs"
SCOPE="playlist-read-private playlist-read-collaborative user-library-read"

mkdir -p "$CACHE_DIR" "$THUMB_CACHE"

# =====================
# OAuth認証
# =====================
do_oauth() {
    echo "🔐 Spotify認証を開始..."

    # 前回の残骸を掃除
    fuser -k 8888/tcp 2>/dev/null

    local encoded_scope
    encoded_scope=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SCOPE}'))")
    local auth_url="https://accounts.spotify.com/authorize?client_id=${CLIENT_ID}&response_type=code&redirect_uri=${REDIRECT_URI}&scope=${encoded_scope}"

    echo "🌐 ブラウザで認証ページを開く..."
    xdg-open "$auth_url" 2>/dev/null || echo "このURLをブラウザで開いて: $auth_url"

    echo "⏳ 認証待機中..."
    local code
    code=$(python3 - <<'EOF'
import http.server
import urllib.parse
import sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if 'code' in params:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"<h1>OK! back to the tui</h1>")
            print(params['code'][0])
            sys.stdout.flush()
        else:
            self.send_response(400)
            self.end_headers()
        self.server.shutdown_flag = True

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(('127.0.0.1', 8888), Handler)
server.shutdown_flag = False
while not server.shutdown_flag:
    server.handle_request()
EOF
)

    if [[ -z "$code" ]]; then
        echo "❌ 認証コードの取得に失敗" >&2
        exit 1
    fi

    local response
    response=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=authorization_code&code=${code}&redirect_uri=${REDIRECT_URI}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}")

    _save_token "$response"
}

# =====================
# トークン保存
# =====================
_save_token() {
    local response="$1"
    local access_token refresh_token expires_in expires_at

    access_token=$(echo "$response" | jq -r '.access_token')
    refresh_token=$(echo "$response" | jq -r '.refresh_token // empty')
    expires_in=$(echo "$response" | jq -r '.expires_in')
    expires_at=$(( $(date +%s) + expires_in - 60 ))

    if [[ "$access_token" == "null" || -z "$access_token" ]]; then
        echo "❌ トークン取得失敗: $response" >&2
        exit 1
    fi

    jq -n \
        --arg at "$access_token" \
        --arg rt "${refresh_token:-}" \
        --argjson ea "$expires_at" \
        '{access_token: $at, refresh_token: $rt, expires_at: $ea}' > "$TOKEN_CACHE"

    echo "✅ 認証完了"
}

# =====================
# トークンリフレッシュ
# =====================
_refresh_token() {
    local refresh_token="$1"
    local response
    response=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token&refresh_token=${refresh_token}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}")

    local new_access
    new_access=$(echo "$response" | jq -r '.access_token')

    if [[ "$new_access" == "null" || -z "$new_access" ]]; then
        echo "❌ リフレッシュ失敗、再認証が必要" >&2
        rm -f "$TOKEN_CACHE"
        do_oauth
        return
    fi

    local expires_in expires_at
    expires_in=$(echo "$response" | jq -r '.expires_in')
    expires_at=$(( $(date +%s) + expires_in - 60 ))

    local rt
    rt=$(jq -r '.refresh_token' "$TOKEN_CACHE")
    jq -n \
        --arg at "$new_access" \
        --arg rt "$rt" \
        --argjson ea "$expires_at" \
        '{access_token: $at, refresh_token: $rt, expires_at: $ea}' > "$TOKEN_CACHE"
}

# =====================
# 有効なトークンを返す
# =====================
get_token() {
    if [[ ! -f "$TOKEN_CACHE" ]]; then
        do_oauth
    fi

    local expires_at
    expires_at=$(jq -r '.expires_at' "$TOKEN_CACHE")
    if [[ $(date +%s) -ge "$expires_at" ]]; then
        local rt
        rt=$(jq -r '.refresh_token' "$TOKEN_CACHE")
        if [[ -n "$rt" && "$rt" != "null" ]]; then
            _refresh_token "$rt"
        else
            do_oauth
        fi
    fi

    jq -r '.access_token' "$TOKEN_CACHE"
}

# =====================
# 自分のプレイリスト一覧
# =====================
get_my_playlists() {
    local token="$1"
    local response
    response=$(curl -s "https://api.spotify.com/v1/me/playlists?limit=50" \
        -H "Authorization: Bearer ${token}")

    echo "$response" | jq -r '.items[] |
        "\(.id)\t\(.name) (\(.tracks.total)曲)"'
}

# =====================
# プレイリスト内の曲 (50曲以上も対応)
# URI\tTITLE - ARTIST\tTHUMB_URL の3カラム形式
# =====================
get_tracks() {
    local token="$1"
    local playlist_id="$2"
    local offset=0
    local all_tracks=""

    while true; do
        local response
        response=$(curl -s "https://api.spotify.com/v1/playlists/${playlist_id}/tracks?limit=50&offset=${offset}&fields=items(track(name,artists,uri,album(images))),next" \
            -H "Authorization: Bearer ${token}")

        local tracks
        tracks=$(echo "$response" | jq -r '.items[] |
            select(.track != null) |
            "\(.track.uri)\t\(.track.name) - \(.track.artists[0].name)\t\(.track.album.images[1].url // .track.album.images[0].url // "")"')

        all_tracks+="${tracks}"$'\n'

        local has_next
        has_next=$(echo "$response" | jq -r '.next')
        [[ "$has_next" == "null" ]] && break
        offset=$(( offset + 50 ))
    done

    echo "$all_tracks"
}

# =====================
# 検索
# URI\tTITLE - ARTIST\tTHUMB_URL の3カラム形式
# =====================
search_tracks() {
    local token="$1"
    local query="$2"
    local response
    response=$(curl -s -G "https://api.spotify.com/v1/search" \
        --data-urlencode "q=${query}" \
        -d "type=track&limit=30" \
        -H "Authorization: Bearer ${token}")

    echo "$response" | jq -r '.tracks.items[] |
        "\(.uri)\t\(.name) - \(.artists[0].name)\t\(.album.images[1].url // .album.images[0].url // "")"'
}

# =====================
# fzfで選曲 (chafaプレビュー付き)
# =====================
pick_track() {
    local thumb_cache="$THUMB_CACHE"
    echo "$1" | grep -v '^$' | fzf \
        --delimiter='\t' \
        --with-nth=2 \
        --prompt="▶ 選ぶ > " \
        --height=60% \
        --reverse \
        --cycle \
        --preview="
            thumb_url=\$(echo {} | cut -f3)
            uri=\$(echo {} | cut -f1)
            cache_key=\$(echo \"\$uri\" | md5sum | cut -c1-8)
            thumb=\"${thumb_cache}/\${cache_key}.jpg\"
            if [ -n \"\$thumb_url\" ] && [ ! -f \"\$thumb\" ]; then
                curl -s \"\$thumb_url\" -o \"\$thumb\" 2>/dev/null
            fi
            if [ -f \"\$thumb\" ]; then
                printf '\033[2J\033[H'
                chafa --size=\"\${FZF_PREVIEW_COLUMNS}x\${FZF_PREVIEW_LINES}\" \"\$thumb\" 2>/dev/null
            fi
        " \
        --preview-window=right:40% | cut -f1
}

# =====================
# fzfでプレイリスト選択 (プレビューなし)
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
    local spotify_uri="$1"
    local track_id="${spotify_uri##*:}"
    local token
    token=$(get_token)

    echo "🔍 曲情報を取得中..."
    local track_json track_name artist_name duration_ms duration_sec
    track_json=$(curl -s "https://api.spotify.com/v1/tracks/${track_id}" -H "Authorization: Bearer ${token}")
    track_name=$(echo "$track_json" | jq -r ".name")
    artist_name=$(echo "$track_json" | jq -r ".artists[0].name")
    duration_ms=$(echo "$track_json" | jq -r ".duration_ms")
    duration_sec=$(( duration_ms / 1000 ))
    local track_info="${track_name} ${artist_name}"

    echo "🔍 YouTube候補を検索中... ($track_info)"

    local raw_candidates
    raw_candidates=$(yt-dlp --cookies-from-browser firefox "ytsearch5:${track_info}" --flat-playlist --print "%(id)s###%(title)s###%(duration)s" --no-warnings 2>/dev/null)

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

        local diff=$(( duration - duration_sec ))
        [[ $diff -lt 0 ]] && diff=$(( -diff ))

        candidates+="https://youtube.com/watch?v=${id}	${title}	[$(( duration/60 ))m$(( duration%60 ))s | Spotify:$(( duration_sec/60 ))m$(( duration_sec%60 ))s | diff:${diff}s]\n"
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

    [[ -z "$selected" ]] && { echo "❌ キャンセル"; clear; return 1; }

    clear

    local yt_url="$selected"
    local play_mode
    play_mode=$(printf \
        "🎵 音声のみ\n🎬 MV(映像あり)\n📝 音声+字幕\n🎬📝 MV+字幕\n🖥️  壁紙 動画\n🖥️📝 壁紙 動画+字幕" \
        | fzf --prompt="再生モード > " --height=40% --reverse --cycle)

    echo "▶ 再生中: $track_name - $artist_name"

    case "$play_mode" in
        "🎵 音声のみ")
            mpv --no-video \
                --ytdl-raw-options="cookies-from-browser=firefox,format=251" \
                "$yt_url"
            ;;
        "🎬 MV(映像あり)")
            mpv --ytdl-raw-options="cookies-from-browser=firefox" \
                "$yt_url"
            ;;
        "📝 音声+字幕")
            mpv --no-video \
                --ytdl-raw-options="cookies-from-browser=firefox,format=251" \
                --sub-auto=all --slang=ja,en \
                "$yt_url"
            ;;
        "🎬📝 MV+字幕")
            mpv --ytdl-raw-options="cookies-from-browser=firefox" \
                --sub-auto=all --slang=ja,en \
                "$yt_url"
            ;;
        "🖥️  壁紙 動画")
            mpvpaper \* "$yt_url" -- \
                --ytdl-raw-options="cookies-from-browser=firefox" \
                --loop=inf
            ;;
        "🖥️📝 壁紙 動画+字幕")
            mpvpaper \* "$yt_url" -- \
                --ytdl-raw-options="cookies-from-browser=firefox" \
                --sub-auto=all --slang=ja,en \
                --loop=inf
            ;;
        *)
            echo "❌ キャンセル"
            return 1
            ;;
    esac
}

# =====================
# メイン
# =====================
main() {
    for cmd in curl jq fzf mpv mpvpaper python3 yt-dlp chafa; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "❌ ${cmd}が必要: pacman -S ${cmd}" >&2
            exit 1
        fi
    done

    local token
    token=$(get_token)

    clear
    local mode
    mode=$(printf "🔍 検索\n📋 自分のプレイリスト\n🔄 再認証\n🚪 Exit" | fzf \
        --prompt="モード > " \
        --height=30% \
        --reverse \
        --cycle \
        --preview="" \
        --preview-window=hidden)

    case "$mode" in
        "🔍 検索")
            read -rp "検索 > " query
            [[ -z "$query" ]] && return 0
            local tracks
            tracks=$(search_tracks "$token" "$query")
            [[ -z "$tracks" ]] && echo "❌ 結果なし" && sleep 1 && return 0
            local selected
            selected=$(pick_track "$tracks")
            if [[ -n "$selected" ]]; then
                clear
                play_track "$selected"
            fi
            ;;

        "📋 自分のプレイリスト")
            local playlists
            playlists=$(get_my_playlists "$token")
            [[ -z "$playlists" ]] && echo "❌ プレイリストが取得できなかった" && sleep 1 && return 0

            while true; do
                clear
                local playlist_id
                playlist_id=$(pick_playlist "$playlists")
                [[ -z "$playlist_id" ]] && return 0

                echo "📥 曲一覧を取得中..."
                local tracks
                tracks=$(get_tracks "$token" "$playlist_id")

                local selected
                selected=$(pick_track "$tracks")
                if [[ -n "$selected" ]]; then
                    clear
                    play_track "$selected"
                fi
            done
            ;;

        "🔄 再認証")
            rm -f "$TOKEN_CACHE"
            do_oauth
            echo "✅ 再認証完了"
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
