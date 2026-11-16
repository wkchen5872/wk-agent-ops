#!/usr/bin/env bash
# install.sh — Install the opsx-branch workflow command globally
#
# Usage:
#   bash scripts/workflow/install.sh
#
# Description:
#   Copies opsx-branch to ~/.local/bin, installs the _opsx-branch zsh
#   completion to ~/.local/share/zsh/site-functions/, and ensures the
#   directories are in the user's PATH / fpath.
#   Retires recognized, unmodified copies of the old worktree/session helpers;
#   modified, unknown, or symlinked entries are kept and reported.

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

# 2. 退役舊 worktree/session helpers：只移除內容完全符合正式部署版本的 regular file。
#    SHA-256 來自退役前 repo 中 install.sh 部署的來源（wt-new 含所有歷史版本）。
LEGACY_SHA256=(
  "$INSTALL_DIR/wt-work 496ffc0ebb4559d73f2617d82190aede7c9ae1c40b787b90d756fd4f1fb6d822"
  "$INSTALL_DIR/wt-resume 39e3eadc33fc1910f73e9493d5eaecb10ff4e239bf9f4244d2640de9de43e897"
  "$INSTALL_DIR/wt-done bdf18350e331bc6bcf512e9761e946561418a841eb192b57ea907a86557aef4d"
  "$INSTALL_DIR/pm-start c56de48c75c05fd5e3d6088b19453986ddde4097011019ba9144b6655cd04d22"
  "$INSTALL_DIR/wk-workflow-runtime 9c319e337cd668bfb2de71b6aecd4c57861c75f61a38f1a54f12ea64f511e1b7"
  "$ZSH_FUNC_DIR/_wt 57c2da4cd1ad002ca48334e7fe5de244fd260e9e725ae3d8ff279a0921d54aa4"
  "$INSTALL_DIR/wt-new 860824dc5bd8d8897f89e7c2e03c50b819f4ea87d48866ce793c64958c4086d6"
  "$INSTALL_DIR/wt-new ebade42cb001887fc24e3a3ba9444c887d965a9d235bf22f13cbcc11466e6ca6"
  "$INSTALL_DIR/wt-new b04644673531b8781ceec9e846f0f3d95c5d9490025c81d28f59144240e33c20"
  "$INSTALL_DIR/wt-new a8bd653a1a171f927c55bf446f18706e3282c5a173b9ca49ace28158f2e365b7"
)
for legacy in "$INSTALL_DIR"/{wt-work,wt-resume,wt-done,pm-start,wk-workflow-runtime,wt-new} "$ZSH_FUNC_DIR/_wt"; do
  [[ -e "$legacy" || -L "$legacy" ]] || continue
  if [[ -f "$legacy" && ! -L "$legacy" ]] \
    && printf '%s\n' "${LEGACY_SHA256[@]}" \
      | grep -Fxq "$legacy $(shasum -a 256 "$legacy" | cut -d' ' -f1)"; then
    rm "$legacy"
    echo "✓ Removed legacy helper: $legacy"
  else
    echo "⚠️ Kept modified, unknown, or symlinked legacy helper (manual cleanup needed): $legacy"
  fi
done

# 3. 複製執行檔並賦予執行權限
cp -f "$REPO/scripts/workflow/opsx-branch.sh" "$INSTALL_DIR/opsx-branch"
chmod +x "$INSTALL_DIR/opsx-branch"

# 4. 安裝 zsh completion
cp -f "$REPO/scripts/workflow/_opsx-branch" "$ZSH_FUNC_DIR/_opsx-branch"

# 5. 偵測使用者的 Shell 設定檔
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "⚠️ 無法自動偵測 Shell。腳本已複製至 $INSTALL_DIR，請手動將該目錄加入您的 PATH 環境變數。"
  exit 0
fi

# 6. 檢查並更新 PATH + fpath (Idempotent)
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

# 7. 重新整理指令快取
hash -r

# 8. 安裝 openspec-branch-creator hook（PostToolUse 自動建立 feature branch）
bash "$REPO/scripts/workflow/openspec-branch-creator/install.sh"

# 9. 清理已退役的 entropy-counter hook。
# shellcheck source=lib.sh
source "$REPO/scripts/workflow/lib.sh"
LEGACY_ENTROPY_HOOK="$HOME/.config/wk-workflow/hooks/entropy-counter.sh"
LEGACY_ENTROPY_CMD="bash \"$LEGACY_ENTROPY_HOOK\""
if [[ -f "$HOME/.claude/settings.json" ]] && jq empty "$HOME/.claude/settings.json" 2>/dev/null; then
  _remove_settings_hook "$HOME/.claude/settings.json" "PostToolUse" "$LEGACY_ENTROPY_CMD"
fi
if [[ -f "$HOME/.gemini/settings.json" ]] && jq empty "$HOME/.gemini/settings.json" 2>/dev/null; then
  _remove_settings_hook "$HOME/.gemini/settings.json" "AfterTool" "$LEGACY_ENTROPY_CMD"
fi
rm -f "$REPO/.github/hooks/entropy-counter.json" "$LEGACY_ENTROPY_HOOK"

echo "✅ 安裝完成。執行檔已部署至 $INSTALL_DIR"
echo ""
echo "已安裝指令："
echo "  opsx-branch 在 OpenSpec artifacts 前建立或切換 planning branch"
echo ""
echo "Zsh 補全已安裝至 $ZSH_FUNC_DIR/_opsx-branch（請重新開 shell 或執行 rm -f ~/.zcompdump* && compinit 刷新補全）"
echo ""
echo "請執行以下指令以套用環境變數："
echo "source $SHELL_RC"
