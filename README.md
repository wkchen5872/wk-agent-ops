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
/opsx:ff  → 建立規格                wt-new <feature>
/opsx:new                             └─ 自動建立 worktree
/opsx:continue ×4                     └─ 自動啟動 Agent
   proposal → specs                /opsx:apply <feature>
   design → tasks                    └─ 依規格實作
                                   /opsx:commit
                                     └─ archive + docs + commit
                                   wt-done <feature>
                                     └─ merge → develop
```

詳細說明：[docs/multi-agent-workflow.md](docs/multi-agent-workflow.md)

---

## Worktree 指令

| 指令 | 說明 |
|---|---|
| `wt-new <feature>` | 建立 `feature/<name>` worktree，自動啟動 Agent |
| `wt-done <feature>` | 合併回 develop，刪除 worktree 與 branch |

支援指定 Agent：

```bash
wt-new etf-nav-fetcher --agent claude    # 預設
wt-new etf-nav-fetcher --agent copilot
wt-new etf-nav-fetcher --agent codex
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
│   ├── skills/
│   │   └── install.sh          ← 安裝擴充套件到目標專案
│   └── worktree/
│       ├── install.sh          ← 安裝 wt-new / wt-done 到全域
│       ├── wt-new.sh
│       └── wt-done.sh
├── docs/
│   ├── multi-agent-workflow.md ← 多 Agent 工作流完整說明
│   ├── commit-feature-workflow.md
│   └── template-profiles.md   ← Template profile 說明與新增方式
└── openspec/                   ← 本專案的 OpenSpec 變更記錄
```

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
