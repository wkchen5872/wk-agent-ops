#!/usr/bin/env bash
# install.sh — Install wt-new / wt-done globally
#
# Usage:
#   bash scripts/worktree/install.sh
#
# Description:
#   Copies the worktree helpers to ~/.local/bin and ensures
#   the directory is in the user's PATH.

set -euo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
  echo "❌ Error: run this script from inside the repository"
  exit 1
fi

# 1. 配置目標安裝路徑
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# 2. 複製執行檔並賦予執行權限
cp -f "$REPO/scripts/worktree/wt-new.sh" "$INSTALL_DIR/wt-new"
cp -f "$REPO/scripts/worktree/wt-done.sh" "$INSTALL_DIR/wt-done"
chmod +x "$INSTALL_DIR/wt-new" "$INSTALL_DIR/wt-done"

# 3. 偵測使用者的 Shell 設定檔
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "⚠️ 無法自動偵測 Shell。腳本已複製至 $INSTALL_DIR，請手動將該目錄加入您的 PATH 環境變數。"
  exit 0
fi

# 4. 檢查並更新 PATH (Idempotent)
PATH_MARKER="# invest-data-fetcher worktree helpers PATH"
if grep -q "$PATH_MARKER" "$SHELL_RC" 2>/dev/null; then
  echo "⏭️  PATH 已配置於 ${SHELL_RC}。腳本已更新至最新版本。"
  exit 0
fi

cat >> "$SHELL_RC" <<EOF

$PATH_MARKER
export PATH="\$PATH:$INSTALL_DIR"
EOF

echo "✅ 安裝完成。執行檔已部署至 $INSTALL_DIR"
echo ""
echo "請執行以下指令以套用環境變數："
echo "source $SHELL_RC"