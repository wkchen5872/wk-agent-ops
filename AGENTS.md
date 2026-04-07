# Agents Configuration Guide

> **專案核心使命**：`wk-agent-ops` 是一個專門為個人或團隊開發、管理與維護 AI Agent 擴充元件（包括 Skills、Rules、Workflows 與 Git Hooks）的中央倉儲。本專案的產出旨在透過安裝腳本，將這些標準化的 Agent 配置無縫部署到其他各個開發專案中，確保跨專案的 Agent 行為一致、高效且具備高度自動化能力。

本文件說明如何在本專案中定義與管理 Claude Code sub-agents、skills、rules 等配置。

---

## 工作流程

調整任何 **skill、agent、rule 或其他配置**時，請遵循以下流程：

```
1. 修改 template/ 中的範本
   ↓
2. 本地確認無誤
   ↓
3. 執行 scripts/skills/install.sh 安裝到 .claude/ 和 .agent/
   ↓
4. 提交 git commit
```

**禁止直接編輯 `.claude/`、`.agent/` 下的檔案** — 這些是由 install.sh 生成的安裝目標，不應該手動維護。

---

## 多工具相容性規範 (Multi-Tool Compatibility)

在進行任何功能規劃、Agent 設計或腳本撰寫時，**必須同時考慮並支援**以下 AI CLI 工具：

- **Claude Code**: 主要研發與執行工具。
- **GitHub Copilot CLI**: 輔助程式碼生成介面。
- **Gemini CLI**: 高性能模型整合。
- **Codex**: 替代執行引擎。

**具體要求：**
1. **設定隔離**：確保 `.claude/`、`.gemini/` 等工具特定設定目錄互不干擾。
2. **環境變數偵測**：腳本必須能根據環境變數（如 `CLAUDE_PROJECT_DIR`、`GEMINI_PROJECT_DIR`）自動偵測當前運作的工具。
3. **輸入輸出規範**：優先支援 Standard Input (stdin) 與 Command-line Arguments，確保所有工具都能透過管道 (pipe) 呼叫。
4. **文件一致性**：`README.md` 與 `docs/` 必須包含各工具的安裝與使用說明。

---

## 目錄結構

```
template/common/
├── .claude/
│   ├── agents/           ← Sub-agent 定義（.md）
│   ├── commands/         ← 自訂斜線命令
│   └── rules/            ← 編碼規範、git 規則等
├── .agent/               ← Antigravity agent 設定
├── .github/
│   └── instructions/     ← GitHub instructions
├── skills/
│   └── <skill-name>/
│       └── SKILL.md      ← Skill 定義
└── hooks/                ← Git hooks （只限於語言特定 profile）
```

---

## 修改流程詳細步驟

### 1. 編輯 Template 文件

所有修改都在 `template/common/` 下進行：

**新增 agent：**
```bash
touch template/common/.claude/agents/<agent-name>.md
# 編輯 frontmatter + system prompt
```

**修改 skill：**
```bash
vim template/common/skills/<skill-name>/SKILL.md
```

**新增 rule：**
```bash
touch template/common/.claude/rules/<rule-topic>.md
```

### 2. 本地驗證

- 讀完新 agent/skill/rule，確認邏輯清晰
- 檢查 frontmatter（如果有 YAML）格式無誤
- 確認跨檔案參考正確（例如 skill 中提到的 agent 路徑是否存在）

### 3. 執行安裝腳本

```bash
bash scripts/skills/install.sh
# 或指定目標
bash scripts/skills/install.sh --target <project-path>
```

此腳本會：
- 複製 `template/common/skills/` → `.claude/skills/` 和 `.agent/skills/`
- 複製 `template/common/.claude/` → `.claude/`（除 skills/）
- 複製 `template/common/.agent/` → `.agent/`
- 複製 `template/common/.github/` → `.github/`

### 4. 本地測試（可選）

在 Claude Code 中測試新 agent：
```
/agents           # 檢查 agent 列表
@"<agent-name>"   # 測試 agent 功能
/reload-plugins   # 重新載入所有 plugin
```

### 5. 提交 Git

同時提交 template 和安裝目標（`.claude/`, `.agent/`）：

```bash
git add template/common/ .claude/ .agent/
git commit -m "chore(agents): add/update <agent-name>"
```

---

## 檔案同步規則

某些檔案需要在三個位置保持同步：

| 檔案類型 | Template | .claude/ | .agent/ | 備註 |
|---------|----------|----------|---------|------|
| Agents | `template/common/.claude/agents/` | ✓ 自動複製 | ✓ 自動複製 | 兩個位置需要相同 |
| Skills | `template/common/skills/` | ✓ 自動複製 | ✓ 自動複製 | 兩個位置需要相同 |
| Rules | `template/common/.claude/rules/` | ✓ 自動複製 | ✗ 不複製 | CC 專用 |
| Commands | `template/common/.claude/commands/` | ✓ 自動複製 | ✗ 不複製 | CC 專用 |

**重要：** 修改後務必確認三個位置內容一致。使用 `diff` 或 `git diff` 檢查：

```bash
diff template/common/.claude/agents/my-agent.md \
     .claude/agents/my-agent.md
```

---

## Common Agents

本專案預定義的 agent：

### git-commit-writer

**位置：** `.claude/agents/git-commit-writer.md`

**用途：** 生成並執行 Conventional Commits 格式的 git commit

**特性：**
- 自動判斷 commit type（feat/fix/chore/docs 等）
- 支援 openspec 上下文（有 change 時加 scope）
- 支援多模型（Claude Haiku 4.5 / Gemini Flash 等），兼顧效能與費用
- 不需要確認，直接執行
- Archive guard：若傳入 `archive_path`，在 commit 前驗證目錄存在；archive 未完成則停止

**觸發方式：**
```
@"git-commit-writer (agent)"

# 或在 openspec-commit workflow 中自動呼叫
```

### doc-updater

**位置：** `.claude/agents/doc-updater.md`

**用途：** 偵測 git 狀態，自動選擇模式，對 `docs/`、`README.md`、`AGENTS.md` 做最小化更新，並將變更留在工作區由使用者 review 後自行 commit

**特性：**
- **Mode A**（有未 commit 的變更）：掃描 `git diff HEAD`，更新文件並留在工作區，與 feature 一起 commit
- **Mode B**（工作區乾淨）：掃描最近 N 個 commit（詢問使用者，預設 1），更新文件留在工作區
- 只改相關 section，不重寫無關段落
- 支援新 agent/skill、workflow 變更、新 profile 等多種情境
- **不自動建立 commit**——文件更新永遠留在工作區
- 支援高品質模型（Claude Sonnet / Gemini Pro），確保文件理解與撰寫品質

**觸發方式：**
```
@"doc-updater (agent)"

# 或透過 skill 呼叫
/doc-updater
```

---

## Skill 開發指南

### Skill 檔案結構

```markdown
---
name: <skill-name>
description: >
  一句話說明此 skill 的用途
license: MIT
compatibility: Required tools/CLI (e.g., git, openspec)
metadata:
  author: <name>
  version: "<version>"
---

# <Skill Title>

<Introduction: 1-2 paragraphs>

---

## Step 1 — <Action>
...

## Step N — <Action>
...
```

### Skill 與 Agent 邏輯一致性

Skill 和 Agent 應該遵循相同的邏輯和步驟，差異只在：

- **Agent** 的 frontmatter 包含 `model: <model-name>`
- **Agent** 的 system prompt 可以更精煉（假設由 agent 執行）
- **Skill** 是通用指令集，需要更詳細的解釋

例：`git-commit-writer`
- Skill 中：「Step 6 — Execute」包含 `Co-Authored-By: <current model name>`（動態）
- Agent 中：「Step 6 — Execute」同樣動態寫入 `Co-Authored-By: <your own model name>`（執行時自填）
- 兩者在 Step 5 均加入 archive guard：archive 目錄不存在則停止

---

## 最佳實踐

1. **優先修改 template**：所有變更先在 `template/common/` 完成，然後透過 install.sh 傳播
2. **測試後再提交**：新 agent/skill 務必在本地測試無誤
3. **保持同步**：定期檢查 template 和安裝位置是否一致
4. **清晰的 commit 訊息**：使用 `chore(agents):`, `feat(agents):` 等 scope 區分
5. **文件詳細**：Skill 文件應該清楚到不懂該領域的人也能跟著步驟做

---

## 常見問題

**Q: 我直接編輯 `.claude/agents/my-agent.md`，為什麼 install.sh 覆蓋了？**

A: `.claude/` 是安裝目標，會被 `template/common/` 覆蓋。請改在 `template/common/` 編輯。

**Q: 新增 agent 後沒看到它出現在 `/agents`？**

A: 執行 `/reload-plugins` 重新載入。

**Q: Skill 和 Agent 應該分開放，還是用同一個檔案？**

A: 分開。Skill 是通用指令集（跨工具），Agent 是 CC 特定設定（含 model）。

**Q: 可以只在 `.claude/` 編輯，不用 template 嗎？**

A: 不建議。`template/` 是「來源」，`.claude/` 和 `.agent/` 是「安裝」。分離設計是為了支援多個專案共用同套配置。

---

## Harness Engineering Protocol

本節定義 AI agent 在 wk-agent-ops 執行任何修改時的強制操作框架。

### Execution Prerequisites

開始任何 task 前，必須同時讀取：
- **`docs/architecture.md`** — 目錄邊界與模組職責
- **`docs/conventions.md`** — Bash 腳本規範與禁止模式
- **`openspec/specs/`** — 需求的唯一真實來源

### The Autonomous Loop (SOP)

1. **Spec-First：** 讀取 openspec/changes/<name>/tasks.md，確認 task 的測試要求
2. **TDD：** 先寫失敗的驗證腳本或測試（例如：`install.sh` 安裝後驗證 hook 存在）
3. **Implement：** 修改 `template/` 下的來源，不直接改 `.claude/`
4. **Verify：** 執行 `/opsx:verify` 或手動安裝測試（見下方 DoD）
5. **Self-Heal：** 若驗證失敗，分析 log、修正來源，重複直到綠燈

### Prohibited Actions

- ❌ **禁止直接編輯 `.claude/`、`.agent/`** — 這是安裝目標，修改會被下次 install.sh 覆蓋
- ❌ **禁止修改第三方 skill** — TDD 規則、workflow 規則放 `template/common/.claude/rules/`，不動 opsx skill
- ❌ **禁止 Hardcode 路徑** — 一律用 `PROJECT_ROOT` 或 `SOURCE_REPO` 變數
- ❌ **禁止 Silent Fail 在 Gate Hook** — pre-commit hook 必須 exit 1 阻擋；只有背景 notification hook 才 exit 0

### Definition of Done (DoD)

- [ ] 修改來源在 `template/` 下，而非安裝目標
- [ ] `bash scripts/skills/install.sh` 在全新 git repo 執行成功
- [ ] 相關功能在安裝後行為符合 spec 的 scenario
- [ ] Aim for 80%+ scenario coverage（bash script 邏輯用臨時 repo 驗證）；若未達到，在 summary 說明原因
- [ ] `git diff template/common/... .claude/...` 確認安裝目標與來源一致

---

## 相關文件

- `scripts/skills/install.sh` — 安裝腳本
- `docs/architecture.md` — 專案架構與模組邊界
- `docs/conventions.md` — Bash 腳本規範
- `docs/workflow/guide.md` — PM/RD 協作完整指南
- `CLAUDE.md` — Claude Code 相關規範
- `.openspec.yaml` — OpenSpec 配置
