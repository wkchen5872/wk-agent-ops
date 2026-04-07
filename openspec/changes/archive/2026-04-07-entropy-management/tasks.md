## 1. entropy-counter-hook（PostToolUse 計數閘）

- [x] 1.1 建立 `scripts/workflow/entropy-counter/hook.sh`：讀取 stdin JSON（複用 openspec-branch-creator/hook.sh 的模式），偵測 `openspec archive` 指令，計算 archive 目錄數與 `.entropy-state` watermark 的差值，達到 `ENTROPY_THRESHOLD`（預設 5）時印出終端機 banner
- [x] 1.2 在 hook.sh 中加入 Telegram 可選通知：若 `~/.config/ai-notify/hooks/telegram-notify.sh` 存在，透過 stdin JSON 呼叫它發送通知訊息
- [x] 1.3 建立 `scripts/workflow/entropy-counter/install.sh`：冪等地將 hook 加入 `~/.claude/settings.json` 的 `hooks.PostToolUse` 陣列；若 `~/.gemini/settings.json` 存在也一併注冊
- [x] 1.4 建立 `scripts/workflow/entropy-counter/uninstall.sh`：冪等地從 `~/.claude/settings.json` 移除 hook 條目
- [x] 1.5 在 `scripts/workflow/install.sh` 新增 entropy-counter hook 安裝步驟，呼叫 `entropy-counter/install.sh`

## 2. entropy-check skill

- [x] 2.1 建立 `template/common/skills/entropy-check/SKILL.md`，包含 context 偵測邏輯（`template/common/` → harness；`openspec/changes/` → openspec；否則 → standard），以及環境變數偵測（`GEMINI_PROJECT_DIR` → `CLAUDE_PROJECT_DIR` → `PWD`）
- [x] 2.2 實作 U1 審查（AGENTS.md coverage）：比對 `.claude/skills/*/SKILL.md` 與 `.claude/agents/*.md` 清單，找出 AGENTS.md 中缺少 `### <name>` 的條目；auto-fix 路徑：直接讀 SKILL.md/agent.md 補寫條目
- [x] 2.3 實作 U2 審查（Docs completeness）：掃描 `docs/architecture.md` 和 `docs/conventions.md` 是否含 placeholder 文字；僅提示，不 auto-fix
- [x] 2.4 實作 U3 審查（Dead references）：掃描 AGENTS.md 和 `docs/*.md` 中的本地路徑引用，驗證路徑存在；提示但不 auto-fix
- [x] 2.5 實作 H1 審查（Template sync，harness only）：`diff -r template/common/.claude/ .claude/`（exclude `*.local*`），有差異時提示執行 `install.sh`
- [x] 2.6 實作 O1 審查（Stale active changes）：掃描 `openspec/changes/`（非 archive）下超過 14 天未更新的 change；提示 archive 或繼續
- [x] 2.7 實作 O2 審查（OpenSpec spec sync）：掃描 `openspec/changes/archive/<name>/specs/` 有 `.md` 但 `openspec/specs/<name>/` 不存在的情況
- [x] 2.8 實作 O3 審查（Dead specs）：掃描 `openspec/specs/<name>/` 無對應 skill/agent 的情況；僅提示，不 auto-fix
- [x] 2.9 實作輸出格式：摘要表（每項審查 ✓/⚠️）+ findings 詳細 + 決策選單（[1] auto-fix / [2] /opsx:new entropy-cleanup / [3] skip）
- [x] 2.10 實作 watermark 更新：每次執行後將 archive 計數寫入 `openspec/.entropy-state`；確保 `.entropy-state` 在 `.gitignore` 中

## 3. 文件更新

- [x] 3.1 在 `AGENTS.md` 新增 `### entropy-check` skill 條目（位置、用途、觸發方式）
- [x] 3.2 確認 `openspec/.entropy-state` 已加入 `.gitignore`

## 4. 驗證

- [x] 4.1 在 wk-agent-ops 執行 `/entropy-check`，確認 context 偵測為 `harness`，H1/O1/O2/O3 審查正常輸出
- [x] 4.2 手動移除 AGENTS.md 一個條目，執行 `/entropy-check`，選 [1] auto-fix，確認條目補回且格式正確
- [x] 4.3 設 `openspec/.entropy-state` 為低值，執行 `openspec archive`，確認 entropy-counter hook 的 banner 出現
- [x] 4.4 重複執行 install.sh，確認 hook 條目不重複（冪等性）
