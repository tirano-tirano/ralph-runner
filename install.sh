#!/bin/bash
# install.sh - Ralph Runner インストーラ
set -e

REPO_RAW="https://raw.githubusercontent.com/tirano-tirano/ralph-runner/main"
INSTALL_DIR="${RALPH_INSTALL_DIR:-$HOME/.local/bin}"

echo "===== Ralph Runner インストーラ ====="

command -v curl >/dev/null || { echo "エラー: curl が必要です" >&2; exit 1; }

if ! command -v claude >/dev/null; then
  echo "⚠ 警告: claude コマンドが見つかりません"
fi

mkdir -p "$INSTALL_DIR"

curl -fsSL "$REPO_RAW/bin/ralph" -o "$INSTALL_DIR/ralph"
chmod +x "$INSTALL_DIR/ralph"

echo "✓ ralph を $INSTALL_DIR にインストールしました"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo "⚠ $INSTALL_DIR が PATH に含まれていません"
  echo "  以下を ~/.bashrc に追加してください:"
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "===== インストール完了 ====="
echo "使い方: ralph --help"
