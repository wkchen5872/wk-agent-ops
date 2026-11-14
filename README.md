# wk-agent-ops

> **專案定位**：`wk-agent-ops` 是 AI Agent 增強套件（Skills, Rules, Workflows, Hooks）的開發與分發中心。我們在這裡開發高品質的 Agent 配置，並將其「外掛」到任何一個專案中，使 Agent 成為真正理解團隊規範並自動化處理重複任務的得力助手。

主要提供兩大核心價值：

1. **Agent 擴充套件（Harness System）** — 統一開發可安裝到任何專案的 skills、rules、git hooks，確保跨專案的 Agent 行為具備一致的高標準。
2. **Worktree 工作流（Concurrent Workflow）** — 透過 Git Worktree 讓多個 Agent 同時開發多個 Feature，徹底實現並行開發。

以 [OpenSpec](https://github.com/Fission-AI/OpenSpec)（Spec-Driven Development）為核心流程。

[Agent Operating Protocol](docs/agent-protocol.md) 依任務效果與風險分級；
需要正式規劃時，依 [OpenSpec Workflow](docs/openspec-workflow.md) 管理規格、
設計與任務，不以 Claude Code、Codex 或 Antigravity 的原生計畫取代。
兩份文件都會安裝至目標 repo，並在重新安裝時更新。

[文件與圖稿規範](docs/okf-conventions.md) 採 OKF v0.2，提供 API、操作及設計文件要求；
靜態圖稿優先 SVG，UX 互動使用 HTML。Claude Code、Codex、Antigravity 共用此規範，
既有 `doc-updater` 會引用它。舊文件在實質更新時漸進遷移，不批次重寫。

---

## 快速開始

### 安裝 Workflow 腳本（全域）

```bash
bash scripts/workflow/install.sh
source ~/.zshrc
```

安裝後可在任何 repo 使用 `opsx-branch`、`wt-work`、`wt-done`、`wt-resume` 與
`pm-start`。正式規劃先執行 `opsx-branch <change-id>`，再建立 OpenSpec artifacts；
PostToolUse branch hook 僅作相容性 fallback。

### 安裝 Agent 擴充套件（到目標專案）

```bash
# 進入目標專案目錄
cd /path/to/your-project

# 只裝通用套件（skills、rules、commands、Codex agents）
bash /path/to/wk-agent-ops/scripts/skills/install.sh

# Python 專案（多裝 Python rules + git hooks）
bash /path/to/wk-agent-ops/scripts/skills/install.sh python

# Node.js 專案
bash /path/to/wk-agent-ops/scripts/skills/install.sh node

# Java / Kotlin 專案
bash /path/to/wk-agent-ops/scripts/skills/install.sh jvm

# .NET 專案
bash /path/to/wk-agent-ops/scripts/skills/install.sh dotnet

# 同時安裝多個 profile
bash /path/to/wk-agent-ops/scripts/skills/install.sh python node
```

安裝目標必須是 Git repository root，可使用 primary checkout 或 linked
worktree。語言 profile 的 hooks 會安裝到 Git 回報的共用 hooks path；repository
內部的子目錄不會被當成有效 target。

語言 profile 也會透過 `npx skills add testland/qa`，以 project scope 為 Claude
Code、Codex、Antigravity 安裝一個對應 mutation runner 與
`mutant-survival-triage`。若自動安裝失敗，installer 會以非零結束並顯示可重播
命令；不會改用 global 或 copy fallback。詳見
[Mutation Testing Playbook](docs/mutation-testing.md)。

---

## 多 Agent 開發流程

```
PM Agent（planning branch）          RD Agent（可選 Worktree）
────────────────────────────────    ──────────────────────────
opsx-branch <change-id>              wt-work <change-id> --agent <provider>
/opsx:ff  → 建立規格                  └─ 解析或建立 Project-managed Worktree
                                      └─ 啟動新的 Provider apply session
   proposal → specs                /opsx:apply <feature>
   design → tasks                    └─ 依規格實作
                                   /opsx:commit
                                     └─ archive + docs + commit
                                   wt-done <feature>
                                     └─ merge → main
                                   wt-resume <feature>  ← 事後回顧
```

詳細說明：[docs/workflow/guide.md](docs/workflow/guide.md)

- [正式圖稿索引](docs/diagrams/README.md) 列出開發與交付全貌、本機四階段、Review、GitHub 交接及 Worktree 解析；發布前人工檢核與 Review 停止點以該索引連結的現行流程為準。

---

## Workflow 指令

| 指令 | 說明 |
|---|---|
| `opsx-branch <change-id>` | 在建立 artifacts 前建立或切換 planning branch |
| `wt-work <change-id>` | 安全解析 registered Worktree；無候選時從 reviewed branch 建立 Project-managed Worktree，並啟動 apply session |
| `wt-done <change-id>` | Local-only merge；只清理 `.worktrees/<change-id>` |
| `wt-resume <change-id>` | 在 verified Worktree 恢復所選 Provider，不注入 apply intent |
| `pm-start [--agent <provider>]` | 從 repo root 啟動 PM planning session |

支援四個 Provider；Antigravity 同時接受 `antigravity` 與官方 CLI 名稱 `agy`：

```bash
wt-work feature123 --agent claude    # 預設
wt-work feature123 --agent codex
wt-work feature123 --agent antigravity
wt-work feature123 --agent agy
wt-work feature123 --agent copilot
```

支援指定 session（`--session` / `-s`）：

```bash
wt-work feature123 --session a469f20a-a791-4c6f-af7a-5a0e599527f4
wt-resume feature123 --session "RD: feature123"
wt-work feature123 --agent codex --path /registered/worktree/path
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
| `.agents/skills/openspec-commit/` | 跨 Provider 的 `openspec-commit` skill |
| `.claude/commands/opsx/commit.md` | `/opsx:commit` slash command |
| `.agents/workflows/opsx-commit.md` | Agent workflow |
| `.claude/agents/git-commit-writer-agent.md` | `@"git-commit-writer-agent"` — 自動產生 Conventional Commits |
| `.claude/skills/git-commit-writer/` | `/git-commit-writer` skill |
| `.claude/agents/doc-updater-agent.md` | `@"doc-updater-agent"` — 分析 git 變更並同步更新說明文件 |
| `.claude/skills/doc-updater/` | `/doc-updater` skill |
| `.agents/skills/doc-updater/` | 跨 Provider 的 `doc-updater` skill |
| `.agents/skills/git-commit-writer/` | 跨 Provider 的 `git-commit-writer` skill |
| `.codex/agents/git-commit-writer-agent.toml` | Codex custom agent（`gpt-5.6-luna`、medium） |
| `.codex/agents/doc-updater-agent.toml` | Codex custom agent（`gpt-5.6-terra`、medium） |
| `work-items/AGENTS.md` | Work Item 協作紀錄規範（managed，重跑 installer 會更新） |
| `.claude/rules/work-items.md` | Work Item 規範的 Provider 原生載入入口 |
| `.agents/rules/work-items.md` | 同一入口的跨 Provider 鏡像 |
| `.gitignore` 的 `/work-items/WI-*/` | 讓臨時紀錄不被 `git add -A` 暫存 |
| `docs/github-handoff.md`、`docs/diagrams/github-handoff.svg` | GitHub 交接契約與流程圖（managed，重跑 installer 會更新） |
| `.claude/skills/github-issue/`、`.claude/skills/github-pr/` | Issue／PR 交接入口 skill |
| `.claude/skills/change-review/`、`.agents/skills/change-review/` | PR 審查、修正交接與複審 skill（含案例、檢查清單與流程圖） |
| `.agents/skills/github-issue/`、`.agents/skills/github-pr/` | 同兩個入口的跨 Provider 副本 |
| `.claude/rules/github-handoff.md`、`.agents/rules/github-handoff.md` | 交接契約的 Provider 原生載入入口與鏡像 |

`scripts/skills/install.sh` 管理 `.claude/`、複數 `.agents/`，以及兩個
project-owned `.codex/agents/` custom agents。它不接管 `.codex/config.toml`、
`.codex/skills/` 或單數 `.agent/`；OpenSpec provider setup 產生的原生檔案
仍屬於另一個分發邊界。完整路徑與呼叫規則見
[OpenSpec Commit 工作流](docs/workflow/commit.md)。`openspec-commit` 預設只做本地的
archive → docs → commit；交付擴充設計在授權時才接上既有 PR：成功時發 Closure 等待 merge，
取消時委派 `github-pr close`。本版本已完成這段整合並通過本地驗證，
真實遠端發布路徑仍待端到端驗收。本 repo 採用的四階段開發流程見
[本機開發四階段流程](docs/workflow/local-development.md)。

### Work Item 協作紀錄

跨 Session 的臨時協作紀錄放在目標專案根目錄的 `work-items/WI-*/`，不納入
Git；完整規範是 managed 的 `work-items/AGENTS.md`，也是這套規則的唯一來源。
Installer 會把忽略規則合併進專案版控的 `.gitignore`，並以 Git 實際效果雙向
驗證：臨時紀錄確實被忽略，規範檔仍可追蹤。效果只來自 `.git/info/exclude`
或個人 `core.excludesFile` 時不算達成，因為專案本身沒有帶規則。既有已被
追蹤的紀錄只會被回報，installer 不修改 Git index。

只讀 `AGENTS.md` 的工具透過「實際載入的根指示檔 → `docs/agent-protocol.md`
→ `work-items/AGENTS.md`」這條鏈取得規範。Installer 會檢查這條鏈並在斷鏈時
回報該補的段落，但不會覆寫專案自己的 `AGENTS.md`。

### GitHub 交接（選用）

要讓另一個 Session 或另一台機器只靠 GitHub Issue／PR 接手某個 OpenSpec Change 時，
使用 `github-issue`（create／update／close）與 `github-pr`（create／update／reply／close）。
`github-issue` 可從指定的 Work Item、Change、兩者、目前分支的關聯或目前 Session 整理出
精簡的 Issue；之後的進度、回覆與交接 Checkpoint 以新增留言保存，不改寫正文；close 先發布
Closure 摘要再以 completed 或 not planned 關閉該 Issue。`github-pr` 用同樣的素材說明這份工作：
create 會做開 PR 需要的檢查、只含本次工作的 commit 與正常 push，再開 Draft PR；update 改說明、
reply 新增審查、修正、Checkpoint 或 Closure 回覆、close 先發布 Closure 再不 merge 地只關閉該 PR，
它處理的 Issue 由 `github-issue close` 另行結案。每則內容都以 Handoff 開頭，接著依用途撰寫的
正文、Next actions，最後是 Author（人類直接發布，或 Agent 協助時的工具、模型與兩個 Session ID）；
Work Item 只標為 local-only。兩個入口只負責操作順序；範本、關聯鍵、provenance、人類設計批准與完整流程都在
managed 的 [`docs/github-handoff.md`](docs/github-handoff.md)。GitHub 操作使用當下
可用且已配置的 `gh` 或 GitHub MCP。只有 `github-pr create` 會 commit 與 push，且不 force、
不略過 hooks、保留無關的工作區內容；`github-issue` 與 github-pr 的其他操作都不寫 Git，SSH／HTTPS
認證交給 Git 與本機設定。舊的 `github-pr publish` 已移除：對既有 PR 推送新 commit 是另外的
Git 請求，之後以 `github-pr update` 說明新版本。Issue、PR 與回覆的 Agent Author 同時記錄
原生的 `SESSION-ID` 與 Xirp 的 `XIRP-SESSION-ID`。

每次寫入前，入口會核對完整的 host／owner／repo、操作與使用者授權（PR 另核對 base／head
repository 與分支），寫入後回讀結果。預設不限制帳號；只有使用者或可信專案規範明示
限制時才核對，不符就停止，不代為切換帳號或修改設定，也不輸出任何 credential。這是規範
與入口的行為，不是 hook，不會攔截手動執行的指令。Claude Code、Codex 與 Antigravity 取得同一份契約：前者
另有 rule 入口，只讀 `AGENTS.md` 的工具經由 `docs/agent-protocol.md` 到達。

審查與驗收使用 `change-review` Skill：給它 Change 名稱、Issue URL／`#N` 或 PR 即可，PR 不是
必要條件，目的預設為實作驗收（明確要求時做設計審查）。它解析 Change 與 PR、固定受審版本，
實際調用必用的 `openspec-verify-change`、已安裝且適合的選用品質技能與專案測試。沒有 PR、
PR 查找不明或要求 local-only 時直接回報；已確認 PR 時，任何結論（含 pass）都以
`github-pr reply` 發布並回讀；需要修正時再經本機 session 工具核對後通知實作者，無法定位時回傳
可轉交訊息，pass 不發修正通知。每次呼叫只做一輪，不改產品程式、不
commit／push，也不走 PR 的 create／update／close。

| 工具 | 呼叫方式 |
| --- | --- |
| Claude Code | `/change-review`，或以自然語言要求 review PR |
| Codex | `$change-review`，或以自然語言要求 review PR |
| Antigravity | 從 `.agents/skills/change-review/` 載入，或以自然語言要求 |

`openspec-verify-change` 是必要驗證；`ponytail-review` 等品質審查是可選加強，未安裝時使用 Skill 內建基線。

### Python Profile

| 安裝位置 | 用途 |
|---|---|
| `.claude/rules/pytest_testing_style_guide.md` | Pytest 測試風格規範 |
| Git hooks path 的 `pre-commit` | 執行 `tests/` unit tests，阻止失敗的 commit |
| Git hooks path 的 `post-merge` | 偵測 `pyproject.toml` 變動，自動 `pip install -e .` |

`pre-commit` hook 特性：
- 自動從 `pyproject.toml` 讀取 source 目錄（支援 setuptools / poetry / pdm / hatch）
- 優先使用專案 `.venv`，fallback 系統 Python
- 測試結果寫入 `logs/unit_test_<timestamp>.log`

### Mutation Testing Skills

| Profile | testland/qa runner | 共用 triage |
|---|---|---|
| `node` | `stryker-mutation` | `mutant-survival-triage` |
| `python` | `mutmut-mutation` | `mutant-survival-triage` |
| `jvm` | `pitest-mutation` | `mutant-survival-triage` |
| `dotnet` | `stryker-net-mutation` | `mutant-survival-triage` |

`wk-agent-ops` 維護 TDD 閉環、執行頻率、score baseline/no-regression policy
與安全邊界；runner 執行及 survivor 分診由 testland/qa skills 負責。

---

## 使用者層級的 Read-heavy Discovery Skill

`bulk-read-routing` 只在程式碼位置未知、需要廣泛唯讀探索時，委派一次
`bulk-reader-agent`；驗證、工程判斷與編輯仍由 parent agent 保留。它不屬於
project-level common installer，請另行安裝：

```bash
bash scripts/user/install-bulk-read-routing.sh
```

可指定 `claude` 或 `codex` 單一 Provider。完整安裝、靜態驗證與 A/B 評估方式見
[Bulk Read Routing Playbook](docs/skills/bulk-read-routing.md)。

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
├── tests/                      ← installer 與規範的行為測試
├── docs/
│   ├── workflow/               ← 多 Agent 協作與 Commit 流程說明
│   ├── notify/                 ← 通知系統架構與 Telegram 安裝說明
│   ├── skills/                 ← git-commit-writer, doc-updater 等工具說明
│   └── hooks/                  ← Provider hook integration 與 ownership 說明
└── openspec/                   ← 本專案的 OpenSpec 變更記錄
```

---

## Telegram 通知

支援 Claude Code、Codex、Antigravity CLI 與 Copilot CLI，在 AI 任務完成、
等待授權或異常停止時透過 Telegram 通知。

### 快速安裝

```bash
# 互動式安裝精靈
bash scripts/notify/telegram/install.sh

# 或在 Claude Code 內
/notify-setup
```

### 管理設定

```bash
bash scripts/notify/telegram/update.sh       # 分組設定選單
bash scripts/notify/telegram/update.sh types # 共用通知＋Codex 專用通知開關
bash scripts/notify/telegram/update.sh status # 註冊、依賴與 daemon 連線狀態
bash scripts/notify/telegram/uninstall.sh    # 移除 hook 與 config
```

既有 Codex `PermissionRequest` 跟隨共用操作提醒開關；新增「等待你授權／回答」
預設關閉，啟用後由 hook 按需查看既有 daemon，不安裝 LaunchAgent。授權與同步
問題需該 daemon 的 session；非同步題目成功送出即提醒，一般文字問句不偵測。

Codex 顯示 `registered` 只代表設定已寫入；還需要在 `/hooks` 將 `Stop`、
`PermissionRequest`、同步問題的 `PreToolUse` 與非同步問題的 `PostToolUse` owned hooks 設為 `Trusted`
並勾選 `[x]` 啟用。daemon 可連線不代表人工等待端到端流程已實測。

詳細說明：[Provider hooks](docs/hooks/index.md) · [Telegram setup](docs/notify/telegram.md) · [Notification architecture](docs/notify/architecture.md)

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
- Node.js / npm（語言 profile 透過 `npx` 安裝 testland/qa skills）
- Claude Code CLI（`wt-work` 預設 Provider；亦支援 Codex、Antigravity、Copilot）
- bash 4+、rsync、git 2.5+（worktree 支援）
- [GitHub CLI](https://cli.github.com/) `gh` 或已配置的 GitHub MCP（僅 GitHub 交接入口需要，擇一即可）
