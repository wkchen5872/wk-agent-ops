# wk-agent-ops

個人 AI Agent 開發工具集，提供兩件事：

1. **Worktree 工作流** — 讓多個 Agent 同時開發不同功能，互不干擾
2. **Agent 擴充套件** — 可安裝到任何專案的 skills、rules、git hooks

以 [OpenSpec](https://github.com/Fission-AI/OpenSpec)（Spec-Driven Development）為核心流程。

---

## 快速開始

### 安裝 Worktree 腳本（全域）

```bash
bash scripts/worktree/install.sh
source ~/.zshrc
```

安裝後可在任何 repo 使用 `wt-new` 和 `wt-done`。

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
PM Agent（主環境 develop）          RD Agent（獨立 Worktree）
────────────────────────────────    ──────────────────────────
pm-start  → 啟動 PM Master Session
/opsx:ff  → 建立規格                wt-new <feature>
/opsx:new                             └─ 自動建立 worktree（或 resume）
/opsx:continue ×4                     └─ 自動啟動 Agent
   proposal → specs                /opsx:apply <feature>
   design → tasks                    └─ 依規格實作
                                   /opsx:commit
                                     └─ archive + docs + commit
                                   wt-done <feature>
                                     └─ merge → develop
                                   wt-resume <feature>  ← 事後回顧
```

詳細說明：[docs/multi-agent-workflow.md](docs/multi-agent-workflow.md)

---

## Worktree 指令

| 指令 | 說明 |
|---|---|
| `wt-new <feature>` | 建立 `feature/<name>` worktree 並啟動 Agent；worktree 已存在則自動 resume |
| `wt-done <feature>` | 合併回 base branch，刪除 worktree 與 branch |
| `wt-resume <feature>` | 以 session 名稱恢復 Agent session（worktree 已刪除也可用）|
| `pm-start` | 啟動或恢復 PM Master Claude session（Plan Mode）|

支援指定 Agent：

```bash
wt-new feature123 --agent claude    # 預設
wt-new feature123 --agent copilot
wt-new feature123 --agent codex

wt-resume feature123 --agent copilot
```

支援指定 base branch（預設 `main`）：

```bash
wt-new feature123 --base develop
wt-done feature123 --base develop
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

### Node.js Profile

| 安裝位置 | 用途 |
|---|---|
| `.claude/rules/` | Node.js 規範（待補充） |
| `.git/hooks/pre-commit` | Lint hook（待補充） |

---

## 目錄結構

```
wk-agent-ops/
├── template/                   ← 擴充套件來源（單一維護點）
│   ├── common/                 ← 所有專案
│   ├── python/                 ← Python 專案
│   └── node/                   ← Node.js 專案
├── scripts/
│   ├── notify/
│   │   └── lib/                ← 共用庫（config.sh、registry.sh）
│   ├── telegram-notify/        ← Telegram 通知 hook 與安裝腳本
│   │   ├── install.sh          ← 互動式安裝精靈
│   │   ├── hook.sh             ← AI CLI hook 腳本
│   │   ├── update.sh           ← 更新設定
│   │   └── uninstall.sh        ← 移除
│   ├── line-notify/            ← Line Notify（架構佔位，未實作）
│   ├── skills/
│   │   └── install.sh          ← 安裝擴充套件到目標專案
│   └── worktree/
│       ├── install.sh          ← 安裝 wt-* / pm-start 到全域 + zsh 補全
│       ├── wt-new.sh
│       ├── wt-done.sh
│       ├── wt-resume.sh
│       ├── pm-start.sh
│       └── _wt                 ← zsh completion
├── docs/
│   ├── multi-agent-workflow.md    ← 多 Agent 工作流完整說明
│   ├── commit-feature-workflow.md ← /opsx:commit 工作流說明
│   ├── git-commit-writer.md       ← git-commit-writer 使用說明
│   ├── doc-updater.md             ← doc-updater 使用說明
│   ├── template-profiles.md       ← Template profile 說明與新增方式
│   ├── telegram-notify-hook.md    ← Telegram 通知快速安裝說明
│   └── notify-hooks-architecture.md ← 通知 hook 架構與擴充指南
└── openspec/                   ← 本專案的 OpenSpec 變更記錄
```

---

## Telegram 通知

當 AI CLI 在背景執行長時間任務時，透過 Telegram 接收任務完成或等待授權的通知。

### 快速安裝

```bash
# 互動式安裝精靈
bash scripts/telegram-notify/install.sh

# 或在 Claude Code 內
/notify-setup
```

### 管理設定

```bash
bash scripts/telegram-notify/update.sh       # 更新 token / chat_id / level
bash scripts/telegram-notify/uninstall.sh    # 移除 hook 與 config
```

| 通知等級 | Stop（任務完成）| Notification（等待授權）|
|---------|--------------|----------------------|
| `all`（預設）| ✅ | ✅ |
| `notify_only` | ❌ | ✅ |

詳細說明：[docs/telegram-notify-hook.md](docs/telegram-notify-hook.md) · [docs/notify-hooks-architecture.md](docs/notify-hooks-architecture.md)

---

## 新增 Profile

```bash
mkdir -p template/<profile>/.claude/rules
mkdir -p template/<profile>/hooks
```

`install.sh` 自動偵測 `template/` 下的子目錄為可用 profile，不需要修改腳本。

詳細說明：[docs/template-profiles.md](docs/template-profiles.md)

---

## 相依

- [OpenSpec CLI](https://github.com/Fission-AI/OpenSpec)：`npm install -g @fission-ai/openspec`
- Claude Code CLI（`wt-new` 預設 Agent）
- bash 4+、rsync、git 2.5+（worktree 支援）
