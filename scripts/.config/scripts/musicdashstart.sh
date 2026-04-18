#!/bin/bash

# プロジェクトのディレクトリに移動（必要に応じてパスを書き換えてください）
cd ~/git/python/musicdash

# 仮想環境を有効化
source venv/bin/activate

# Flaskをバックグラウンドで起動
echo "Starting Flask Server..."
python app.py &
FLASK_PID=$!

# 少し待ってからFunnelを起動
sleep 2
echo "Starting Tailscale Funnel..."
tailscale funnel 5000

# FunnelをCtrl+Cで止めた時にFlaskも一緒に殺す処理
trap "kill $FLASK_PID" EXIT
