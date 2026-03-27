## Context

目前 wk-agent-ops 有兩套文件更新路徑：
1. `openspec-commit` skill：綁定 OpenSpec 工作流程，適合有正式 change 的功能開發
2. 手動維護：開發者自行判斷並更新文件

這個 gap 導致簡單的變更（如新增 agent、修改 script、設定變更）後，`docs/`、`README.md`、`AGENTS.md` 經常沒有同步更新。

## Goals / Non-Goals

**Goals:**
- 提供一個通用的文件同步工具，不依賴 OpenSpec 工作流程
- 支援兩種使用情境：有未 commit 的變更時（pre-commit）或已 commit 後（post-commit）
- 只做最小化更新（改相關 section，不重寫整份文件）
- 智能判斷是否需要文件更新

**Non-Goals:**
- 不取代 `openspec-commit`（openspec 工作流程仍使用原本的路徑）
- 不自動觸發（不作為 git hook，由開發者主動呼叫）
- 不負責建立全新的架構文件（那需要人工判斷）

## Decisions

### 1. Agent + Skill 雙檔模式（對齊 git-commit-writer 模式）

**決定**：同時建立 `.claude/agents/doc-updater.md` 與 `.claude/skills/doc-updater/SKILL.md`

**理由**：
- Agent 讓使用者可以用 `@"doc-updater (agent)"` 直接呼叫
- Skill 讓使用者可以用 `/doc-updater` 在 skill 工作流程中使用
- 兩者遵循 template/common 單一來源模式，由 install.sh 分發

### 2. 雙模式偵測（根據 git status 決定行為）

**決定**：執行時先檢查 `git status`，自動選擇掃描來源：

| 狀態 | 模式 | 掃描來源 | 文件更新方式 |
|------|------|---------|------------|
| 有未 commit 的變更（staged/unstaged）| **Mode A** | `git diff HEAD`（全部未 commit 的變更）| 文件變更加入當前工作區（與即將到來的 commit 合併） |
| 無未 commit 的變更 | **Mode B** | 詢問 N（預設 1，範圍 1-10），掃描最近 N 個 commits | 文件變更留在工作區，由用戶 review 後手動 commit |

**理由**：
- Mode A（pre-commit）：開發者正在整理 commit，文件更新自然是這個 commit 的一部分
- Mode B（post-commit）：commit 已完成，文件更新是補充動作，留在工作區讓開發者 review 後自行決定
- 兩種模式都**不自動 commit**，開發者保有完整控制權
- 兩種情境都有實際需求，強制只支援一種會限制使用彈性

**Mode A 替代方案**：只支援 post-commit → 開發者必須先 commit 才能更新文件，不符合「commit 前掃描並補充文件」的使用情境

### 3. Mode B 的 N commit 詢問

**決定**：Mode B 時用 AskUserQuestion 詢問要掃描幾個 commit（預設 1，範圍 1-10）

**理由**：
- 開發者可能一口氣做了多個 commit 才想到要更新文件
- 開放 1-10 的範圍足夠涵蓋常見情況，不會讓 diff 過大

### 4. Skip 邏輯：僅適用於 Mode B

**決定**：Mode A 不套用 skip 邏輯（因為沒有 commit type）；Mode B 的 skip 條件：
- 所有 N 個 commits 都是 `docs:` 類型（避免無限循環）
- 所有 N 個 commits 都是 `test:` 或 `style:`
- 其他情況：分析 diff 內容決定是否有文件影響

**理由**：Mode A 直接分析 diff 內容判斷是否有文件影響，無需 commit type

### 5. 使用 Sonnet 而非 Haiku

**決定**：agent 指定 `model: sonnet`

**理由**：
- doc-updater 需要讀多個文件、判斷哪些 section 需要更新、用一致的語氣撰寫內容
- 這比 git-commit-writer（只需格式化 commit message）複雜得多

## Risks / Trade-offs

- **語言一致性**：README.md 是繁體中文，agent 必須用繁體中文撰寫新增內容 → 在 skill 指令中明確規定
- **Mode A 文件與 feature 混入同一 commit**：這是刻意設計，但需要告知使用者
- **Mode B N commit 的 diff 可能很大**：限制最多 10 個 commit，超過建議分批執行
- **AGENTS.md 格式漂移**：若新增項目不遵循既有格式 → skill 指令中提供現有項目作為格式參考
