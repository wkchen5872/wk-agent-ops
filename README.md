# wk-agent-ops

> **專案定位**：`wk-agent-ops` 是 AI Agent 增強套件（Skills, Rules, Workflows, Hooks）的開發與分發中心。我們在這裡開發高品質的 Agent 配置，並將其「外掛」到任何一個專案中，使 Agent 成為真正理解團隊規範並自動化處理重複任務的得力助手。

主要提供兩大核心價值：

1. **Agent 擴充套件（Harness System）** — 統一開發可安裝到任何專案的 skills、rules、git hooks，確保跨專案的 Agent 行為具備一致的高標準。
2. **Worktree 工作流（Concurrent Workflow）** — 透過 Git Worktree 讓多個 Agent 同時開發多個 Feature，徹底實現並行開發。

以 [OpenSpec](https://github.com/Fission-AI/OpenSpec)（Spec-Driven Development）為核心流程。

---

## 快速開始

### 安裝 Workflow 腳本（全域）

```bash
bash scripts/workflow/install.sh
source ~/.zshrc
```

安裝後可在任何 repo 使用 `wt-work`、`wt-done`、`wt-resume` 與 `pm-start`。
同時安裝 `openspec-branch-creator` PostToolUse hook — PM agent 執行 `openspec new change <name>` 時自動建立 `feature/<name>` 分支。

### 安裝 Agent 擴充套件（到目標專案）

```bash
# 進入目標專案目錄
cd /path/to/your-project

# 只裝通用套件（skills、rules、commands）
bash /path/to/wk-agent-ops/scripts/skills/install.sh

# Python 專案（多裝 Python rules + git hooks）
bash /path/to/wk-agent-ops/scripts/skills/install.sh python

# Node.js 專案
bash /path/to/wk-agent-ops/scripts/skills/install.sh node

# 同時安裝多個 profile
bash /path/to/wk-agent-ops/scripts/skills/install.sh python node
```

---

## 多 Agent 開發流程

```
PM Agent（主環境 main）             RD Agent（獨立 Worktree）
────────────────────────────────    ──────────────────────────
/opsx:ff  → 建立規格                wt-work <feature>
/opsx:new                             └─ 自動建立 worktree
/opsx:continue ×4                     └─ 自動啟動 Agent
   proposal → specs                /opsx:apply <feature>
   design → tasks                    └─ 依規格實作
                                   /opsx:commit
                                     └─ archive + docs + commit
                                   wt-done <feature>
                                     └─ merge → main
                                   wt-resume <feature>  ← 事後回顧
```

詳細說明：[docs/workflow/guide.md](docs/workflow/guide.md)

---

## Workflow 指令

| 指令 | 說明 |
|---|---|
| `wt-work <feature>` | 建立 `feature/<name>` worktree 並啟動 Agent；本地/遠端分支已存在時自動銜接（跨機器支援）；worktree 已存在則自動 resume，均帶入 `/opsx:apply` |
| `wt-done <feature>` | 合併回 base branch，刪除 worktree 與 branch（⚠️ local-only，不含 push / PR）|
| `wt-resume <feature>` | 恢復 Agent session（無 `--session` 時顯示互動選單；worktree 已刪除也可用）|
| `pm-start` | 啟動或恢復 PM Master Claude session（Plan Mode）|

支援指定 Agent（含 Gemini）：

```bash
wt-work feature123 --agent claude    # 預設
wt-work feature123 --agent copilot
wt-work feature123 --agent gemini
wt-work feature123 --agent codex

wt-resume feature123 --agent copilot
wt-resume feature123 --agent gemini
```

支援指定 session（`--session` / `-s`）：

```bash
wt-work feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4
wt-resume feature123 --session "RD: feature123"
```

支援指定 base branch（預設 `main`）：

```bash
wt-work feature123 --base main
wt-done feature123 --base main
```

---

## Agent 擴充套件

安裝後目標專案會得到：

### Common（所有專案）

| 安裝位置 | 用途 |
|---|---|
| `.claude/skills/openspec-commit/` | `/opsx:commit` skill |
| `.claude/commands/opsx/commit.md` | `/opsx:commit` slash command |
| `.agent/workflows/opsx-commit.md` | Agent workflow |
| `.claude/rules/openspec-commits.md` | Commit 規範（永遠載入） |
| `.github/instructions/openspec-commits.md` | GitHub Copilot instructions |
| `.claude/agents/git-commit-writer.md` | `@"git-commit-writer"` — 自動產生 Conventional Commits |
| `.claude/skills/git-commit-writer/` | `/git-commit-writer` skill |
| `.claude/agents/doc-updater.md` | `@"doc-updater"` — 分析 git 變更並同步更新說明文件 |
| `.claude/skills/doc-updater/` | `/doc-updater` skill |

### Python Profile

| 安裝位置 | 用途 |
|---|---|
| `.claude/rules/pytest_testing_style_guide.md` | Pytest 測試風格規範 |
| `.git/hooks/pre-commit` | 執行 `tests/` unit tests，阻止失敗的 commit |
| `.git/hooks/post-merge` | 偵測 `pyproject.toml` 變動，自動 `pip install -e .` |

`pre-commit` hook 特性：
- 自動從 `pyproject.toml` 讀取 source 目錄（支援 setuptools / poetry / pdm / hatch）
- 優先使用專案 `.venv`，fallback 系統 Python
- 測試結果寫入 `logs/unit_test_<timestamp>.log`

---

## 目錄結構

```
wk-agent-ops/
├── template/                   ← 擴充套件來源（單一維護點）
├── scripts/
│   ├── notify/                 ← 通知系統共用庫與 Telegram 實作
│   ├── skills/
│   │   └── install.sh          ← 安裝擴充套件到目標專案
│   └── workflow/               ← wt-* / pm-start 等流程管理腳本
├── docs/
│   ├── workflow/               ← 多 Agent 協作與 Commit 流程說明
│   ├── notify/                 ← 通知系統架構與 Telegram 安裝說明
│   ├── skills/                 ← git-commit-writer, doc-updater 等工具說明
│   └── hooks/                  ← Gemini / Claude / Copilot Hooks 指南與開發參考
└── openspec/                   ← 本專案的 OpenSpec 變更記錄
```

---

## Telegram 通知

當 AI CLI 在背景執行長時間任務時，透過 Telegram 接收任務完成或等待授權的通知。

### 快速安裝

```bash
# 互動式安裝精靈
bash scripts/notify/telegram/install.sh

# 或在 Claude Code 內
/notify-setup
```

### 管理設定

```bash
bash scripts/notify/telegram/update.sh       # 更新 token / chat_id / level
bash scripts/notify/telegram/uninstall.sh    # 移除 hook 與 config
```

詳細說明：[docs/notify/telegram.md](docs/notify/telegram.md) · [docs/notify/architecture.md](docs/notify/architecture.md)

---

## 新增 Profile

```bash
mkdir -p template/<profile>/.claude/rules
mkdir -p template/<profile>/hooks
```

`install.sh` 自動偵測 `template/` 下的子目錄為可用 profile，不需要修改腳本。

詳細說明：[docs/skills/template-profiles.md](docs/skills/template-profiles.md)

---

## 相依

- [OpenSpec CLI](https://github.com/Fission-AI/OpenSpec)：`npm install -g @fission-ai/openspec`
- Claude Code CLI（`wt-work` 預設 Agent；亦支援 Copilot、Gemini、Codex）
- bash 4+、rsync、git 2.5+（worktree 支援）
