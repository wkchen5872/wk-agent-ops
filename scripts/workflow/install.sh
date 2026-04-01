#!/usr/bin/env bash
# install.sh — Install wt-new / wt-done / wt-resume / pm-start globally
#
# Usage:
#   bash scripts/workflow/install.sh
#
# Description:
#   Copies the workflow helpers to ~/.local/bin, installs the _wt zsh
#   completion to ~/.local/share/zsh/site-functions/, and ensures the
#   directories are in the user's PATH / fpath.

set -euo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
  echo "❌ Error: run this script from inside the repository"
  exit 1
fi

# 1. 配置目標安裝路徑
INSTALL_DIR="$HOME/.local/bin"
ZSH_FUNC_DIR="$HOME/.local/share/zsh/site-functions"
mkdir -p "$INSTALL_DIR" "$ZSH_FUNC_DIR"

# 2. 複製執行檔並賦予執行權限
cp -f "$REPO/scripts/workflow/wt-new.sh"    "$INSTALL_DIR/wt-new"
cp -f "$REPO/scripts/workflow/wt-done.sh"   "$INSTALL_DIR/wt-done"
cp -f "$REPO/scripts/workflow/wt-resume.sh" "$INSTALL_DIR/wt-resume"
cp -f "$REPO/scripts/workflow/pm-start.sh"  "$INSTALL_DIR/pm-start"
chmod +x "$INSTALL_DIR/wt-new" "$INSTALL_DIR/wt-done" \
         "$INSTALL_DIR/wt-resume" "$INSTALL_DIR/pm-start"

# 3. 安裝 zsh completion
cp -f "$REPO/scripts/workflow/_wt" "$ZSH_FUNC_DIR/_wt"

# 4. 偵測使用者的 Shell 設定檔
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "⚠️ 無法自動偵測 Shell。腳本已複製至 $INSTALL_DIR，請手動將該目錄加入您的 PATH 環境變數。"
  exit 0
fi

# 5. 檢查並更新 PATH + fpath (Idempotent)
PATH_MARKER="# wk-agent-ops workflow helpers PATH"
if grep -q "$PATH_MARKER" "$SHELL_RC" 2>/dev/null; then
  echo "⏭️  PATH 已配置於 ${SHELL_RC}。腳本已更新至最新版本。"
else
  cat >> "$SHELL_RC" <<EOF

$PATH_MARKER
export PATH="\$PATH:$INSTALL_DIR"
fpath=($ZSH_FUNC_DIR \$fpath)
autoload -Uz compinit && compinit
EOF
fi

# 6. 重新整理指令快取
hash -r

echo "✅ 安裝完成。執行檔已部署至 $INSTALL_DIR"
echo ""
echo "已安裝指令："
echo "  wt-new      建立或恢復 worktree RD session"
echo "  wt-done     合併 feature 分支並清理 worktree"
echo "  wt-resume   以 session 名稱恢復 Claude agent（worktree 刪除後也可用）"
echo "  pm-start    啟動或恢復 PM Master Claude session"
echo ""
echo "Zsh 補全已安裝至 $ZSH_FUNC_DIR/_wt"
echo ""
echo "請執行以下指令以套用環境變數："
echo "source $SHELL_RC"