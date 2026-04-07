## Context

`wk-agent-ops` 是一個 harness 開發專案，產出 skills/rules/workflow 後透過 `install.sh` 安裝到其他開發專案。每個 feature 都有對應的 OpenSpec 文件更新，但缺乏跨功能的週期性審查——template 與安裝層可能脫同步、OpenSpec specs 未同步到 canonical 位置、AGENTS.md 未反映最新安裝的 skills。

`install.sh` 的行為決定了什麼會飄移：
- `.claude/skills/`、`.claude/agents/`、`.claude/rules/`：rsync 完整同步，重跑 install 可修復
- `AGENTS.md`：copy-if-not-exists，安裝後由目標專案擁有，harness 更新後**不會**自動補新條目
- `docs/`：--ignore-existing，安裝後由目標專案擁有

## Goals / Non-Goals

**Goals:**
- Entropy check 在 wk-agent-ops 和目標專案中都能執行，依 context 自動選擇對應的審查
- Archive 計數觸發機制，避免無意義的時間排程（靜默週不觸發、密集開發時自動提示）
- 審查結果提供直接可行的 action，而非只輸出報告

**Non-Goals:**
- 不自動修復需要人工判斷的問題（如 dead specs、stale changes）
- 不追蹤 harness 版本號或比較上下游版本差異
- 不修改 doc-updater（entropy check 的 auto-fix 直接處理，不委派）

## Decisions

### Decision 1：Archive 計數觸發，而非時間排程

時間排程（每週 cron）在靜默週產生雜訊、在密集開發期反應遲緩。Archive 計數是真實的工作量訊號——每個 archived change 代表完成的工作單位，計數達閾值時熵的累積概率才真正升高。

Watermark 存於 `openspec/.entropy-state`（單行整數，不納入版控），避免重複觸發。

**替代方案**：時間排程（週期固定但與工作量脫鉤）、每次 archive 觸發（頻率過高）。

### Decision 2：Context 偵測決定審查範圍

```
有 template/common/  → context = harness   (wk-agent-ops)
有 openspec/changes/ → context = openspec  (使用 OpenSpec 的專案)
否則                 → context = standard  (一般目標專案)
```

三層 context 允許相同 skill 在不同專案中執行對應的審查，避免在不適用的環境跑無意義的檢查。

**替代方案**：多個獨立 skill（`/entropy-check-harness`、`/entropy-check-project`）——會增加安裝複雜度，違反 single skill 的目標。

### Decision 3：AGENTS.md auto-fix 由 entropy-check 直接處理

doc-updater 依靠 git diff 找出最近 N commits 的變更來更新文件，對於「多個 commit 前就存在的缺口」無法覆蓋。Entropy check 找到的缺口可能是任意時間前引入的，必須直接讀取 skill/agent 檔案並補寫條目，不能委派給 doc-updater 的 git-diff 邏輯。

### Decision 4：PostToolUse hook 監聽 Bash tool call

Claude Code 的 PostToolUse hook 可攔截每次 tool call 的輸入。監聽 Bash tool 中包含 `openspec archive` 的指令，與現有 `openspec-branch-creator/hook.sh` 使用相同機制，複用已驗證的 stdin JSON 讀取模式。

## Risks / Trade-offs

- **[Risk] O3 Dead Specs 誤判**：`openspec/specs/<name>` 存在但對應的 skill 用不同目錄名稱存放 → Mitigation：只提示不 auto-fix，由人工確認
- **[Risk] Watermark 與實際 archive 計數不同步**：手動刪除 archive 目錄時 `.entropy-state` 不會更新 → Mitigation：entropy check 執行時重算實際計數，以當前目錄數為準
- **[Trade-off] Hook 只支援 Claude Code 的 PostToolUse**：Gemini CLI / Copilot CLI 沒有等效的 archive 事件 hook → 在這些工具中只能手動觸發 `/entropy-check`，計數閘為 Claude Code 獨有功能
