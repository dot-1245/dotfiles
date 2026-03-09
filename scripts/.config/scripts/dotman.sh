#!/bin/bash
# dotman.sh - fzfベースのdotfile管理スクリプト
# 依存: fzf, git, stow

# ===== 設定 =====
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
EDITOR="${EDITOR:-nvim}"

# ===== カラー =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ===== ユーティリティ =====
msg()     { echo -e "${GREEN}${BOLD}[✔]${RESET} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $1"; }
err()     { echo -e "${RED}${BOLD}[✘]${RESET} $1"; }
header()  { echo -e "\n${CYAN}${BOLD}=== $1 ===${RESET}\n"; }

# dotfilesディレクトリチェック
check_dotfiles_dir() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        warn "dotfilesディレクトリが見つかりません: $DOTFILES_DIR"
        read -rp "作成しますか？ [y/N]: " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            mkdir -p "$DOTFILES_DIR"
            cd "$DOTFILES_DIR" && git init
            msg "作成 & git init 完了: $DOTFILES_DIR"
        else
            err "キャンセルしました"
            exit 1
        fi
    fi
}

# パッケージ一覧取得（dotfilesDir直下のディレクトリ）
get_packages() {
    find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type d \
        ! -name '.git' \
        ! -name '.stow-local-ignore' \
        -printf '%f\n' | sort
}

# Stow済みかチェック
is_stowed() {
    local pkg="$1"
    local pkg_dir="$DOTFILES_DIR/$pkg"
    # 1つでもシンボリックリンクが存在すればStow済みとみなす
    find "$pkg_dir" -mindepth 1 -maxdepth 3 -type f 2>/dev/null | while read -r f; do
        local rel="${f#$pkg_dir/}"
        local target="$HOME/$rel"
        if [[ -L "$target" ]]; then
            echo "stowed"
            return
        fi
    done
}

# ===== 機能 =====

# 1. Stow/Unstow 管理
manage_stow() {
    header "Stow/Unstow 管理"
    local packages
    packages=$(get_packages)

    if [[ -z "$packages" ]]; then
        warn "パッケージが見つかりません: $DOTFILES_DIR"
        echo ""
        echo -e "  まず ${BOLD}「➕ 新規 dotfile 追加」${RESET} でファイルを追加してみてください"
        echo ""
        read -rp "  今すぐ追加しますか？ [Y/n]: " yn
        [[ ! "$yn" =~ ^[Nn]$ ]] && add_dotfile
        return
    fi

    # fzfで複数選択（Stow状態をプレビュー表示）
    local selected
    selected=$(echo "$packages" | fzf \
        --multi \
        --prompt="パッケージを選択 (TABで複数選択) > " \
        --header="Enter: 操作選択 | TAB: 複数選択 | Ctrl-C: キャンセル" \
        --preview="echo '--- ファイル一覧 ---'; find $DOTFILES_DIR/{} -mindepth 1 -maxdepth 4 ! -path '*/.git/*' | sed 's|$DOTFILES_DIR/{}||' | head -30" \
        --preview-window=right:50%
    )

    [[ -z "$selected" ]] && { warn "キャンセルしました"; return; }

    echo ""
    echo -e "${BOLD}操作を選んでください:${RESET}"
    local action
    action=$(printf "stow（有効化）\nunstow（無効化）\nrestow（再適用）" | fzf \
        --prompt="操作 > " \
        --height=6 \
        --no-preview
    )

    [[ -z "$action" ]] && { warn "キャンセルしました"; return; }

    local flag
    case "$action" in
        stow*)   flag="" ;;
        unstow*) flag="-D" ;;
        restow*) flag="-R" ;;
    esac

    echo ""
    while IFS= read -r pkg; do
        echo -n "  $pkg ... "
        if stow $flag --dir="$DOTFILES_DIR" --target="$HOME" "$pkg" 2>/tmp/stow_err; then
            msg "完了"
        else
            err "失敗"
            cat /tmp/stow_err
        fi
    done <<< "$selected"
}

# 2. Gitバックアップ
git_backup() {
    header "Git バックアップ"
    cd "$DOTFILES_DIR" || return

    if [[ ! -d ".git" ]]; then
        warn "gitリポジトリが初期化されていません"
        read -rp "git init しますか？ [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] && git init || return
    fi

    # ステータス確認
    local status
    status=$(git status --short)

    if [[ -z "$status" ]]; then
        msg "変更なし（クリーンな状態です）"
        echo ""
        echo -e "${BOLD}最新のコミット履歴:${RESET}"
        git log --oneline -10 2>/dev/null || warn "コミット履歴なし"
        return
    fi

    echo -e "${BOLD}変更されたファイル:${RESET}"
    echo "$status"
    echo ""

    local op
    op=$(printf "add & commit\nadd & commit & push\nlog表示\ndiff表示" | fzf \
        --prompt="操作 > " \
        --height=8 \
        --no-preview
    )

    case "$op" in
        "add & commit"*)
            git add -A
            read -rp "コミットメッセージ: " msg_text
            msg_text="${msg_text:-dotfiles: update $(date '+%Y-%m-%d %H:%M')}"
            git commit -m "$msg_text" && msg "コミット完了"
            if [[ "$op" == *"push"* ]]; then
                git push && msg "プッシュ完了" || err "プッシュ失敗（remoteを確認してください）"
            fi
            ;;
        "log表示")
            git log --oneline -20 | fzf \
                --prompt="コミット > " \
                --preview="git show --stat {1}" \
                --preview-window=right:60% \
                --no-multi
            ;;
        "diff表示")
            git diff | less -R
            ;;
        *)
            warn "キャンセルしました"
            ;;
    esac
}

# 3. エディタで設定ファイルを開く
edit_config() {
    header "設定ファイルを編集"

    # dotfiles内の全ファイルをfzfで選択
    local file
    file=$(find "$DOTFILES_DIR" \
        -mindepth 2 \
        -type f \
        ! -path '*/.git/*' \
        | sed "s|$DOTFILES_DIR/||" \
        | sort \
        | fzf \
            --prompt="ファイルを選択 > " \
            --preview="bat --color=always --line-range=:100 '$DOTFILES_DIR/{}' 2>/dev/null || cat '$DOTFILES_DIR/{}'" \
            --preview-window=right:60%
    )

    [[ -z "$file" ]] && { warn "キャンセルしました"; return; }

    msg "開く: $DOTFILES_DIR/$file"
    $EDITOR "$DOTFILES_DIR/$file"
}

# 4. 新規dotfile追加
add_dotfile() {
    header "新規 dotfile 追加"

    # 追加元を選ぶ
    local source_type
    source_type=$(printf "📁  ~/.config のフォルダを丸ごと追加\n📄  ファイルを個別に追加" | fzf \
        --prompt="追加方法 > " \
        --height=6 \
        --no-preview \
        --tac --no-sort
    )

    [[ -z "$source_type" ]] && { warn "キャンセルしました"; return; }

    if [[ "$source_type" == *"フォルダ"* ]]; then
        _add_config_folder
    else
        _add_single_file
    fi
}

# ~/.config のフォルダを丸ごと追加
_add_config_folder() {
    echo ""
    msg "~/.config の中のフォルダを選んでください（TABで複数選択）"
    echo ""

    # すでにdotfilesに取り込まれていないフォルダだけ表示
    local selected
    selected=$(find "$HOME/.config" -maxdepth 1 -mindepth 1 -type d \
        | sed "s|$HOME/.config/||" \
        | sort \
        | fzf \
            --multi \
            --prompt="フォルダを選択 (TABで複数) > " \
            --header="選択したフォルダが ~/dotfiles/<名前>/.config/<名前>/ に配置されます" \
            --preview="echo '--- ファイル一覧 ---'; find $HOME/.config/{} -maxdepth 3 | sed 's|$HOME/.config/||' | head -40" \
            --preview-window=right:50% \
            --tac --no-sort
    )

    [[ -z "$selected" ]] && { warn "キャンセルしました"; return; }

    while IFS= read -r folder; do
        local pkg_name="$folder"
        local src="$HOME/.config/$folder"
        local dest="$DOTFILES_DIR/$pkg_name/.config/$folder"

        echo ""
        echo -e "${BOLD}処理中: $folder${RESET}"

        # すでにdotfilesに存在する場合スキップ
        if [[ -d "$dest" ]]; then
            warn "すでに存在します: $dest （スキップ）"
            continue
        fi

        # コピー先ディレクトリ作成
        mkdir -p "$(dirname "$dest")"

        # フォルダをコピー
        cp -r "$src" "$dest"
        msg "コピー: $src → $dest"

        # 元フォルダを削除してStowでシンボリックリンク
        read -rp "  元の ~/.config/$folder をシンボリックリンクに置き換えますか？ [Y/n]: " yn
        if [[ ! "$yn" =~ ^[Nn]$ ]]; then
            rm -rf "$src"
            if stow --dir="$DOTFILES_DIR" --target="$HOME" "$pkg_name" 2>/tmp/stow_err; then
                msg "Stow完了: $pkg_name → ~/.config/$folder"
            else
                err "Stow失敗（元に戻します）"
                cat /tmp/stow_err
                # ロールバック
                cp -r "$dest" "$src"
                rm -rf "$DOTFILES_DIR/$pkg_name"
                continue
            fi
        fi

        # gitに追加
        if [[ -d "$DOTFILES_DIR/.git" ]]; then
            cd "$DOTFILES_DIR" && git add "$pkg_name/"
            msg "git add 完了: $pkg_name"
        fi

    done <<< "$selected"

    echo ""
    msg "全て完了！"
    echo -e "  dotfiles: ${BOLD}$DOTFILES_DIR${RESET}"
    echo -e "  次は ${BOLD}「💾 Git バックアップ」${RESET} でコミットしよう"
}

# ファイルを個別に追加
_add_single_file() {
    warn "~/ 以下のファイルを選択してください"
    echo ""

    local file
    file=$(find "$HOME" \
        -maxdepth 5 \
        -type f \
        ! -path "$DOTFILES_DIR/*" \
        ! -path "$HOME/.cache/*" \
        ! -path "$HOME/.local/share/*" \
        ! -path "*/.git/*" \
        2>/dev/null \
        | sed "s|$HOME/||" \
        | sort \
        | fzf \
            --prompt="追加するファイル > " \
            --preview="bat --color=always --line-range=:50 '$HOME/{}' 2>/dev/null || cat '$HOME/{}' 2>/dev/null || echo '(プレビュー不可)'" \
            --preview-window=right:55%
    )

    [[ -z "$file" ]] && { warn "キャンセルしました"; return; }

    local suggested_pkg
    suggested_pkg=$(echo "$file" | cut -d'/' -f1 | sed 's/^\.//')
    read -rp "パッケージ名 [${suggested_pkg}]: " pkg_name
    pkg_name="${pkg_name:-$suggested_pkg}"

    local src="$HOME/$file"
    local dest="$DOTFILES_DIR/$pkg_name/$file"

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    msg "コピー: $src → $dest"

    read -rp "元のファイルをシンボリックリンクに置き換えますか？ [Y/n]: " yn
    if [[ ! "$yn" =~ ^[Nn]$ ]]; then
        rm "$src"
        stow --dir="$DOTFILES_DIR" --target="$HOME" "$pkg_name" 2>/tmp/stow_err \
            && msg "Stow完了: $pkg_name" \
            || { err "Stow失敗"; cat /tmp/stow_err; }
    fi

    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        read -rp "git add しますか？ [Y/n]: " yn
        if [[ ! "$yn" =~ ^[Nn]$ ]]; then
            cd "$DOTFILES_DIR" && git add "$pkg_name/"
            msg "git add 完了"
        fi
    fi
}

# ===== メインメニュー =====
main_menu() {
    check_dotfiles_dir

    while true; do
        echo ""
        echo -e "${CYAN}${BOLD}╔══════════════════════════════╗${RESET}"
        echo -e "${CYAN}${BOLD}║        dotman 🗂️              ║${RESET}"
        echo -e "${CYAN}${BOLD}║  dotfiles: ${RESET}${DOTFILES_DIR/$HOME/\~}${CYAN}${BOLD}$(printf '%*s' $((18 - ${#DOTFILES_DIR} + ${#HOME})) '')║${RESET}"
        echo -e "${CYAN}${BOLD}╚══════════════════════════════╝${RESET}"
        echo ""

        local choice
        choice=$(printf \
            "📦  Stow/Unstow 管理\n💾  Git バックアップ\n✏️   設定ファイルを編集\n➕  新規 dotfile 追加\n🚪  終了" \
            | fzf \
                --prompt="操作を選択 > " \
                --height=12 \
                --no-preview \
                --border=rounded \
                --header="dotfiles: $DOTFILES_DIR" \
                --tac \
                --no-sort
        )

        case "$choice" in
            *"Stow/Unstow"*)  manage_stow ;;
            *"Git"*)          git_backup ;;
            *"設定ファイル"*) edit_config ;;
            *"新規"*)         add_dotfile ;;
            *"終了"*|"")      msg "またね！"; exit 0 ;;
        esac
    done
}

# ===== エントリポイント =====
# 引数があればサブコマンドとして実行
case "${1:-}" in
    stow)   check_dotfiles_dir; manage_stow ;;
    git)    check_dotfiles_dir; git_backup ;;
    edit)   check_dotfiles_dir; edit_config ;;
    add)    check_dotfiles_dir; add_dotfile ;;
    *)      main_menu ;;
esac
