---
type: Playbook
title: Agent Handoff 交接迴圈指南
description: 使用 handoff-start、handoff-role、handoff-finish、handoff-cleanup 與 handoff-doctor 協調多 Agent 自動化實作、審查與收尾。
tags: [skills, handoff, workflow, xirp, herdr, agents, notify]
generated: { by: "claude-code/claude-opus-5-5", at: "2026-11-20T14:05:00+08:00" }
sources:
  - id: handoff-scripts
    resource: /scripts/handoff/README.md
    title: Agent Handoff Loop Scripts
  - id: handoff-skill
    resource: /template/common/skills/agent-handoff/SKILL.md
    title: Agent Handoff Skill
  - id: notify-telegram
    resource: /docs/notify/telegram.md
    title: Telegram Notify Guide
---

# Agent Handoff 交接迴圈指南

`agent-handoff` 是一套自動化的多 Agent 協作迴圈系統。它讓負責實作（implementer）、審查（reviewer）與收尾（finish）的各個 Agent 能在無需人工反覆傳話的情況下，自動接力完成功能開發、審查驗收與最終提交。

每個 Agent 在當前輪次結束時，透過 `agent-handoff` Skill 寫入標準化的「交件單」；當 Agent 停下時，系統內建的 `Stop` 鉤子（`handoff-route`）會讀取該交件單，透過下一位 Agent 所在的 session 宿主（host：`xirp` 或 `herdr`）自動發送訊息，並發送 Telegram 即時進度通知或在需要人工介入時發送停點警報。[^handoff-scripts]

相關流程圖稿：
- [啟動流程圖（SVG）](/docs/diagrams/agent-handoff-start.svg)
- [交接迴圈圖（SVG）](/docs/diagrams/agent-handoff-loop.svg)
- [收尾清理圖（SVG）](/docs/diagrams/agent-handoff-cleanup.svg)

---

## 迴圈運作流程

```text
                  【使用者啟動】
             handoff-start <change-id>
                        │
                        ▼
┌───────────────────────────────────────────────────┐
│ 1. 實作者 (Implementer)                           │
│    - 依 OpenSpec 規格進行 TDD 實作                │
│    - 本地完成 commit                              │
│    - 執行 handoff-write --role implement 寫交件單 │
└───────────────────────┬───────────────────────────┘
                        │ Agent 停下，觸發 Stop hook
                        ▼
┌───────────────────────────────────────────────────┐
│ 2. 背景調度 (handoff-route Stop Hook)            │
│    - 驗證 worktree HEAD 與 clean 狀態             │
│    - 第一輪：開啟 Reviewer Session                │
│    - 後續輪：切換 Reviewer worktree 至新 commit   │
└───────────────────────┬───────────────────────────┘
                        │ 透過 Session Host (Xirp / Herdr TUI) 傳遞訊息
                        ▼
┌───────────────────────────────────────────────────┐
│ 3. 審查者 (Reviewer)                              │
│    - 執行 change-review 嚴格檢驗功能              │
│    - 執行 handoff-write --role review 寫審查結果  │
└───────────────────────┬───────────────────────────┘
                        │
       ┌────────────────┴────────────────┐
       ▼ (changes-required)              ▼ (pass)
┌──────────────────────────────┐  ┌──────────────────────────────┐
│ 退回修正                     │  │ 審查通過                     │
│ Stop hook 將報告路徑轉給實作 │  │ 預設 (ask)：通知你執行       │
│ 者，自動啟動下一輪修正       │  │   handoff-finish <change-id> │
│ （達 max_rounds 上限時通知你）│  │ 自動 (auto)：自動開收尾      │
└──────────────────────────────┘  └──────────────┬───────────────┘
                                                 │
                                                 ▼
                                  ┌──────────────────────────────┐
                                  │ 4. 收尾者 (Finish)           │
                                  │    - 執行 openspec-commit    │
                                  │    - 封存規格、同步文件、提交│
                                  │    - 寫 finish 交件單並通知  │
                                  └──────────────┬───────────────┘
                                                 │
                                                 ▼
                                  ┌──────────────────────────────┐
                                  │ 5. 清理與歸檔                │
                                  │    handoff-cleanup --yes     │
                                  │    - 歸檔交件單與審查報告    │
                                  │    - 刪除 Sessions 與工作區  │
                                  │    - 保留 feature 分支       │
                                  └──────────────────────────────┘
```

---

## 角色範本配置 (`.agent-handoff/roles.yaml`)

迴圈運作依賴主工作區（Main Worktree）下的 `.agent-handoff/roles.yaml`（該檔案由 `.gitignore` 排除，不納入版本控制）。

每個角色均需定義 `harness`（`claude`、`codex` 或 `pi`）、`model`、`effort`、`name` 與 `prompt`：

| 欄位 | 說明與預設值 |
|---|---|
| `host` | `xirp`（預設）或 `herdr`：Session 跑在哪裡。可寫在頂層套用至所有角色，或由個別角色覆寫 |
| `herdr_session` | 在 herdr 外部啟動時指定 herdr session 名稱（預設使用 herdr default session） |
| `max_rounds` | 最大退回修復輪數，預設為 `3`。達上限時 Stop hook 停止自動調度並通知你 |
| `review.worktree` | `shared`（預設）：審查者與實作者共用同一個 worktree；`new`：另開獨立 detached worktree 停在該 commit |
| `finish.worktree` | `shared`（預設）：收尾者沿用實作者 worktree；`new`：實作者 worktree 脫鉤，另開新 worktree 接手分支 |
| `finish.trigger` | `ask`（預設）：審查通過後發送 Telegram 通知，等待人工下達 `handoff-finish`；`auto`：通過後自動開啟收尾 Session |
| `finish.delivery` | `local`（預設）：僅執行本地封存、文件更新與 commit；`pr`：包含 push、`github-pr update` 與發布 Closure |
| `<role>.profile` | Codex 專用：指定設定檔名稱。如需執行遠端 PR 交付，請設為 `profile: handoff-net` 啟用網路存取 |
| `<role>.provider` | Pi 專用、必填：擁有該模型的 Pi provider，例如 `openai-codex` |
| `<role>.billing` | Pi 專用、必填：`subscription`（OAuth 登入）或 `api`（API key） |

### Prompt 支援的動態佔位符

範本的 `prompt` 支援以下變數自動替換：
- `{change}`：OpenSpec Change ID
- `{head}`：受審或目標 commit SHA
- `{round}`：當前輪次編號（1, 2, 3...）
- `{report}`：審查報告的相對/絕對路徑（供退回修正時傳遞）
- `{delivery}`：交付模式（`local` 或 `pr`）
- `{handoff_write}`：寫入交件單的相對腳本路徑
- `{author}`：自動產生之身分說明區塊（包含工具、模型、Session ID；Herdr pane 內因變數隔離不帶 Xirp Session ID，而是記錄原生 Session ID）

---

## Session 宿主（host）

host 決定角色的 Session 執行與顯示位置：`xirp`（預設）或 `herdr`。此設定為本機屬性，定義於主工作區不進 Git 的 `roles.yaml`（頂層套用全域，角色可個別覆寫）：

```yaml
host: herdr            # 全域預設宿主：xirp 或 herdr
herdr_session: work    # 於 herdr 外部執行時使用的 herdr session 名稱（預設為 default）
```

### Herdr TUI 工作區與 Tab 拓撲

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Herdr TUI Server                                                       │
│  └─ 主 Repo Workspace (wk-agent-ops)                                  │
│      ├─ Linked Worktree Workspace (../wk-agent-ops-<change-id>)        │
│      │   ├─ Tab 1: claude - impl - <change-id>   (實作者 Pane)        │
│      │   ├─ Tab 2: codex - review - <change-id>  (審查者 Pane)        │
│      │   └─ Tab 3: codex - finish - <change-id>  (收尾者 Pane)        │
│      └─ (若為 --worktree here，則直接在主 Repo Workspace 建立 Tabs)    │
└────────────────────────────────────────────────────────────────────────┘
```

### Herdr 提問防卡死與重試機制 (Prompt Lifecycle & Recovery)

```text
herdr agent start (開啟 Pane，注入模型/effort 參數)
       │
       ▼
herdr agent prompt (--wait --until working/blocked)
       ├─► [正常] Agent 開始工作 (working) ──────────► 進入回合執行
       │
       ├─► [對話框] 遇到信任/權限視窗 (agent_blocked) ─► 留 Pane + 標記 pending_prompt
       │                                              │  發 Attention 通知 (workspace/tab/pane)
       │                                              └─► 人工確認後 ─► handoff-route --foreground
       │
       └─► [吞 Enter] 停在輸入框 (agent_prompt_stalled)
             │
             └─► 迴圈自動補按一次 Enter (agent send-keys enter)
                   ├─► [成功] Agent 啟動 working ───► 正常交接
                   └─► [仍無動靜] 產生 <role>-unconfirmed.txt 鎖定防護，發送通知
```

### 宿主特性對照

| 特性 | Xirp | Herdr TUI |
|---|---|---|
| **介面型態** | 桌面應用 / 背景程序 | Terminal UI（Workspace / Tab / Pane） |
| **Worktree 配置** | 各 Session 獨立指向 worktree 路徑 | Linked Workspace 掛在主 Repo 下，每個角色一個 Tab |
| **啟動等待** | 建立即返回 | 等待至 Agent 開始工作（`--until working`）或停留對話框 |
| **模型回報** | 動態透過 API 提取執行模型與強度 | 記錄範本設定值（標註 `(template)`） |
| **環境變數隔離** | 帶有 `CHIRP_SESSION_ID` | 隔離環境（`HERDR_ENV=1`），Xirp ID 記為 `null`，依賴 integration 回報原生 ID |
| **清理動作** | `xirp session delete` | 關閉迴圈開立的 Workspace 或 Tab（不碰無關 Pane） |

- **嚴格驗證**：若設定的 host 未安裝或 server 未啟動，指令直接終止，不猜測或自動切換 host。
- **混合使用**：同一個迴圈支援混用宿主（例如實作者跑 Xirp、審查者跑 Herdr），訊息自動路由至接收端宿主。
- **未來規劃**：後續評估支援 `ghostty + tmux`。

---

## 指令手冊

### 1. `handoff-start <change-id>`

開啟一輪實作 → Review → 收尾的交接迴圈。

```bash
handoff-start <change-id> [選項]
```

**常用選項：**
- `--worktree new`（預設）：在 `../<repo>-<change-id>` 開立新的獨立 worktree，實作者在該目錄工作。
- `--worktree here`：在當前目錄直接啟動（當前目錄必須已經 checkout 在 `feature/<change-id>`）。
- `--impl <override>`：臨時覆寫實作者配置（例：`--impl claude:opus:high`）。
- `--review <override>`：臨時覆寫審查者配置（例：`--review codex:gpt-6.1-sol:high`；Pi 為 `--review pi:openai-codex/gpt-6.2-sol:high:subscription`，與範本一樣驗證）。
- `--finish ask|auto`：覆寫審查通過時的行為（是否自動啟動 finish）。
- `--reviewer-session <id>`：沿用審查角色 host 上現有的 session 作為審查者（Xirp session ID，或 herdr 的 pane ID）。

override 換了工具時，prompt 開頭的 skill 呼叫會改成新工具的寫法（例如 `$change-review` 換成 Pi 的 `/skill:change-review`），以舊工具名稱開頭的 session 名稱也會改成新工具名稱。

### 2. `handoff-role <change-id> <review|finish> [<override>] [--worktree new] [--replace]`

在交接迴圈運行中更換審查（review）或收尾（finish）的角色範本：

```bash
# 例如：將還沒開啟的審查者換為 Pi
handoff-role <change-id> review pi:openai/gpt-6.2-sol:high:api

# 例如：將收尾者換為 Codex
handoff-role <change-id> finish codex:gpt-6.1-sol:high

# 例如：審查者已開啟、額度用完，換成在自己 worktree 的 Pi 審查者
handoff-role <change-id> review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace
```

**角色更換決策與處理流程：**

```text
       handoff-role <change-id> <review|finish> [override] [--worktree new] [--replace]
                                      │
                                      ▼
                       ┌──────────────────────────────┐
                       │ 1. 預檢門檻 (Doctor Check)   │
                       │    範本、工具、host、Pi 憑證 │
                       └──────────────┬───────────────┘
                                      │ Pass (Fail 則立即終止，不改任何狀態)
                                      ▼
                       ┌──────────────────────────────┐
                       │ 2. 目標角色 Session 狀態？   │
                       └──────┬────────────────┬──────┘
                              │                │
                     [未開啟] │                │ [已開啟]
                              │                ▼
                              │   ┌──────────────────────────────┐
                              │   │ 檢查有無 --replace 旗標？    │
                              │   └──────┬────────────────┬──────┘
                              │          │ 無             │ 有
                              │          ▼                ▼
                              │   ┌─────────────┐  ┌───────────────────────────────────┐
                              │   │ 拒絕執行    │  │ ① 安全結束舊 Session (Xirp/Herdr) │
                              │   │ 提示加旗標  │  │ ② 清空 loop.yaml 舊 Session 紀錄  │
                              │   └─────────────┘  │ ③ 寫入新角色範本配置              │
                              │                    └─────────────────┬─────────────────┘
                              ▼                                      │
           ┌──────────────────────────────────────┐                  │
           │ 3. 更新 loop.yaml 範本配置           │                  │
           └──────────────────┬───────────────────┘                  │
                              │                                      │
                              └──────────────────┬───────────────────┘
                                                 │
                                                 ▼
                       ┌──────────────────────────────────────────────┐
                       │ 4. 自動改送等待中的交件單                    │
                       │    - 審查角色：重新派送等待中的 implement 單 │
                       │    - 收尾角色：若為 blocked/pass 則重啟收尾  │
                       └──────────────────────────────────────────────┘
```

**行為與安全規則要點：**
- **自動適配語法**：自動重寫 Prompt 開頭的 Skill 呼叫（如 Claude `$change-review` 轉 Pi `/skill:change-review`）與 Session 名稱。
- **嚴格預檢**：呼叫 `handoff-doctor` 執行範本、工具、host 與 Pi 憑證驗證，若不通過則完全不改動現有配置。
- **`--worktree new`**：將角色移至獨立目錄（`<worktree>-review` 或 `<worktree>-finish`），避免多個 Pi 角色共用工作區的限制。
- **`--replace` 汰換舊 Session**：
  1. 透過 host 安全終止舊 Session（Xirp 刪除 Session；Herdr 關閉該角色 Tab/Pane）。
  2. 清空 `loop.yaml` 舊 Session 記錄並寫入新範本（既有歷史交件單結論依然有效）。
- **自動改送交件單**：
  - 審查角色：若舊審查者有未處理的 `implement:done` 交件單，自動在新 Session 重新派送。
  - 收尾角色：若收尾處於 `blocked` 或審查通過已開 Session，自動重啟新收尾流程。
- **不可更換邊界**：實作者不可更換，主庫原始 `roles.yaml` 永不修改。詳細啟動拓撲請見 [啟動流程圖（SVG）](/docs/diagrams/agent-handoff-start.svg)。

### 3. `handoff-finish <change-id>`

當審查通過後，啟動收尾階段：

```bash
handoff-finish <change-id>
```

**執行條件與行為：**
- 檢查最新交件單必須為 `review` / `done` / `pass`。
- 檢查實作者 worktree 的 HEAD 與交件單記載之 `head` 一致且乾淨（無未暫存修改）。
- 若設定 `finish.worktree: new`，實作者 worktree 會切換至 detached HEAD，新建立的 `../<repo>-<change-id>-finish` 接手 `feature/<change-id>` 分支進行收尾。
- **失敗重試（Retry）**：若收尾過程因網路中斷或遠端拒絕而停下（交件單為 `finish` / `blocked`），排解問題後再次執行 `handoff-finish`，系統會直接自中斷點接續或重開收尾 Session。每筆 blocked 交件單只送一次重試（記在 `loop.yaml` 的 `finish.retried_for`）；收尾 Session 寫出新交件單之前再執行（即使與前一次同時執行），只會回報已送過，不會重送；只有 host 明確回報沒送出（例如被對話框擋住）時才能再試。
- **實作或審查 blocked 後接續**：迴圈不會自行恢復。排除原因後，請實作者在乾淨且已 commit 的 `HEAD` 寫一筆新的 `implement` / `done` 交件單，hook 會把它當成下一輪交給審查者（計入 `max_rounds`）。審查只因需要人親自做的步驟（例如真實環境驗收）而 blocked 時：由人完成該步驟、把證據記在該 change 的 Work Item（cleanup 會歸檔被移除 worktree 的 Work Item），再請實作者勾選 task、commit 並交件。

### 4. `handoff-cleanup <change-id> [--abandon] [--yes]`

當迴圈完成或決定放棄時，執行安全回收：

```bash
# 預覽將被清理的項目（乾跑，Dry Run，不變更狀態；列出要刪除的 Sessions、Worktrees、將歸檔的 Work Items 與主工作區的 Pi 設定）
handoff-cleanup <change-id>

# 正式執行清理
handoff-cleanup <change-id> --yes

# 放棄未完成的迴圈並清理
handoff-cleanup <change-id> --abandon --yes
```

**清理回收安全門檻與執行流程：**

```text
           handoff-cleanup <change-id> [--abandon] [--yes]
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                     【三道安全防護門檻】                        │
│ 1. 紀錄判定：最新交件單須為 finish:done（除非明示 --abandon）   │
│ 2. 乾淨檢查：所有 Worktree 須為 Clean（無未提交變更，否則終止） │
│ 3. 主庫保護：主 Repo 工作區永遠保留，絕不執行 worktree remove   │
└────────────────────────────────┬────────────────────────────────┘
                                 │ 通過門檻且帶有 --yes
                                 │ （未帶 --yes 僅執行 Dry Run 預覽，不改狀態）
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                     【執行三階段清理回收】                      │
│ 步驟 1. 歷史證據歸檔：                                          │
│         - 交件單與審查報告拷貝至主庫 archive/<change-id>/       │
│         - 臨時 Worktree 中的 WI-* 證據同步歸檔                  │
│ 步驟 2. 釋放 Session：                                          │
│         - Xirp：呼叫 xirp session delete                        │
│         - Herdr：關閉迴圈開立的專屬 Workspace 或 Tab            │
│ 步驟 3. 移除臨時工作區：                                        │
│         - 安全刪除額外建立的實作與收尾 Worktree                 │
│         - feature/<change-id> 分支與已提交 Commit 永遠保留      │
└─────────────────────────────────────────────────────────────────┘
```

**清理行為與安全要點：**
- **歷史證據永存**：臨時 Worktree 內的 `work-items/WI-*` 與交件單均複製歸檔至主工作區 `.agent-handoff/archive/`，驗收與審查軌跡不隨目錄刪除而遺失。
- **精準釋放 Session**：只關閉迴圈自行建立的 Session/Workspace/Tab，絕不影響其他外部 Pane 或現存工作。
- **代碼絕對安全**：任何 Worktree 存在未暫存或未提交代碼時立即報錯終止；`feature/<change-id>` 分支保留交由團隊後續合併。完整清理拓撲請見 [收尾清理圖（SVG）](/docs/diagrams/agent-handoff-cleanup.svg)。

### 5. `handoff-doctor [change-id]`

在開任何 session 之前，集中檢查這台機器能不能跑交接迴圈。不開、不傳訊、不關任何 session，也不改任何檔案。

```bash
# 檢查 roles.yaml 的三個角色
handoff-doctor

# 檢查某個迴圈 loop.yaml 裡實際生效的角色（含 override 與 handoff-role 的變更）
handoff-doctor <change-id>
```

每項檢查印一行 `<ok|warn|fail> <區> <訊息>`，任何一行是 `fail` 就以非零狀態結束：

| 區 | 檢查項目 | 有問題時 |
|---|---|---|
| `base` | `git`、`jq`、main worktree、範本檔（`roles.yaml` 或 `loop.yaml`）；這裡失敗就不做其他檢查 | `fail` |
| `host` | 每個用到的 host。`xirp`：指令、main worktree 已登錄為 Xirp project；`herdr`：指令、版本、所選 herdr session 的 server 在跑 | `fail` |
| `harness` | 每個用到的工具：指令與版本，以及觸發器（Claude Code／Codex 的 `handoff-route` Stop hook、Pi 擴充） | `fail` |
| `harness` | Codex hook 是否已在 `/hooks` 信任，無法從外部確認 | `warn` |
| `harness` | herdr 角色：herdr 對該工具的整合（`herdr integration status`），沒有就拿不到原生 Session ID | `warn` |
| `role` | 範本欄位、harness 與 host；Pi 另檢查 repo 信任、模型、憑證與計費 | `fail` |
| `role` | Claude Code、Codex 的模型沒有可靠的清單可查，標示 `model not verified` | `ok` |
| `notify` | 通知器已安裝 | `warn` |

**何時自動執行**：`handoff-start`（三個角色）、`handoff-role`（被更換的角色）與 `handoff-finish`（收尾角色）在開 session 或寫 `loop.yaml` 之前都會跑同一套檢查：印出 `warn` 與 `fail` 那幾行（前面加上指令名稱），有 `fail` 就拒絕，什麼都不開。

---

## Agent 交件單技能 (`agent-handoff`)

迴圈中的 Agent 均透過本專案的 `agent-handoff` Skill 回報進度。[^handoff-skill]

### 1. 寫入交件單 (`handoff-write`)

```bash
.agents/skills/agent-handoff/scripts/handoff-write \
  --change <change-id> \
  --role implement|review|finish \
  --status done|blocked \
  [--verdict pass|changes-required|blocked] \
  [--report <report-path>] \
  [--note "<note>"]
```

產生的紀錄會存放在 `.agent-handoff/<change-id>/<NN>-<role>.yaml`，例如：
```yaml
role: review
status: done
head: a1b2c3d4e5f6
round: 1
verdict: changes-required
report: work-items/WI-123/review-r1.md
author:
  tool: Codex
  model: gpt-6.1-sol
  session_id: 9a8b7c6d...
```

### 2. 身分輸出 (`handoff-author`)

為避免 LLM 在受限沙盒中自行捏造或丟失 Session ID，腳本提供自動輸出工具：

```bash
.agents/skills/agent-handoff/scripts/handoff-author --tool Codex --model gpt-6.1-sol >> body.md
```

自動讀取當前環境變數（`CLAUDE_CODE_SESSION_ID`、`CODEX_SESSION_ID`、`PI_SESSION_ID`、`CHIRP_SESSION_ID`）生成符合規範的 Author 標頭；Pi 使用 `--tool Pi`。

### 3. Pi 角色的 `agent` 區塊

在 Pi Session 中，`handoff-write` 會從 Pi 執行環境（`PI_PROVIDER`、`PI_MODEL`、`PI_REASONING_LEVEL`、`PI_SESSION_ID`）與 `pi auth check` 自動加上 `agent` 區塊，記錄實際的 provider、模型、effort、計費方式與 Session ID；不能用參數指定。交件單必須由角色 Session 自己寫，不要交給 subagent。

---

## Pi 角色

`harness: pi` 的角色在 Pi 中執行，另需 `provider` 與 `billing`；`model` 是該 provider 底下的精確模型 ID（不加 `provider/`、不用別名），`effort` 為 Pi 的 thinking 等級（`off`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max`）。迴圈在三個關口確認角色跑在宣告的 provider、模型與計費方式上，對不上就停下：[^handoff-scripts]

```text
                 Pi 角色三道檢驗關卡 (3-Gate Validation)
                                 │
   1. 啟動預檢 (handoff-start)   │ 驗證 roles.yaml/loop.yaml
 ┌───────────────────────────────┴───────────────────────────────┐
 │ • 一個 worktree 最多一個 Pi 角色（第二個須設 worktree: new）  │
 │ • Pi 觸發器已安裝、主 worktree 已在 Pi 信任 (/trust)          │
 │ • 模型存在於 provider 下、pi auth check 狀態為 ready          │
 └───────────────────────────────┬───────────────────────────────┘
                                 │ 通過後建立 Worktree / Session
   2. 路由檢驗 (Stop Hook)       │ 檢查交件單 YAML 的 agent 區塊
 ┌───────────────────────────────┴───────────────────────────────┐
 │ • 實際執行的 provider/model/effort 與 loop.yaml 範本完全相符  │
 │ • 若中途被手動切換模型或為 unknown，立即停下並發送 Attention  │
 └───────────────────────────────┬───────────────────────────────┘
                                 │ 相符才接棒
   3. 開啟前複檢 (handoff-route) │ 開啟 Pi Reviewer / Finish Session 前
 ┌───────────────────────────────┴───────────────────────────────┐
 │ • 重新確認環境、憑證與計費方式（OAuth 對 subscription）       │
 │ • 驗證失敗則保留交件單並發通知，排除後自動重試                │
 └───────────────────────────────────────────────────────────────┘
```

**配置與運行要點：**
- **單一 Worktree 限制**：Xirp 從本機 `.pi/settings.json`（由 repo `info/exclude` 忽略、不進 Git）啟動角色，因此一個 worktree 僅限一個 Pi 角色；多個 Pi 角色需使用 `worktree: new` 分離目錄。
- **資料夾信任授權**：首次使用前需在主庫以 Pi 執行 `/trust`；全域擴充（`wk-handoff.ts`）會在主庫已信任且 `loop.yaml` 列出該 worktree 時自動授權，不需反覆手動信任。
- **費用與 Context 考量**：
  - 審查 Session 貫穿全迴圈，長輪數建議優先選用 `subscription`（OAuth 登入）與大 Context Window provider，避免 API 費用與 Context 膨脹。
  - 當 Context 滿時 Pi 會自動 compaction；角色內 subagent 不會鎖定特定 provider，交件單一律由外層 Session 撰寫。詳細細節見 [Pi roles](/scripts/handoff/README.md#pi-roles)。

---

## 交接迴圈即時通知 (Notifications)

交接迴圈內建 Telegram 結構化事件通知，由 Stop 鉤子（`scripts/handoff/handoff-route`）在每次路由交件單時自動送出。通知具備專屬的進度回報、不可關閉的停點安全保護、Agent 身分標記與失敗重試保障。完整通知系統整體架構請見 [通知架構與延遲授權流程（SVG）](/docs/diagrams/notify-architecture.svg)。[^notify-telegram]

```text
                     交接迴圈事件通知流與安全保護
                                   │
                    ┌──────────────┴──────────────┐
                    │  Stop Hook 捕獲交件單狀態   │
                    └──────────────┬──────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ handoff:implement│      │ handoff:review  │       │ handoff:finish  │
│ ✅ 實作完成     │       │ 🟢 通過 / 🔁 退回│       │ 📦 收尾完成     │
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         └─────────────────────────┼─────────────────────────┘
                                   │
              [正常運轉：可由 ~/.config/ai-notify/config 開關]
                                   │
                                   ▼
        ═══════════════════════════════════════════════════
        🚨 停點安全保護 (Safety Anchor Guarantee - 不可關閉)
        ═══════════════════════════════════════════════════
        若遭遇以下停點事件，強制發送 handoff:attention (🔴 需要你處理)：
          • 交件單為 blocked 或遭遇執行錯誤
          • 退回輪數達 max_rounds 上限
          • 工作區 dirty 或 HEAD 與交件單不一致
          • 審查通過但設為 ask (等待手動下達 handoff-finish)
          • 宿主傳訊失敗或需使用者互動確認
```

### 1. 四大通知事件與對應範本

| 事件代碼 | 訊息標題 | 對應範本 | 觸發時機與內容 |
|---|---|---|---|
| `handoff:implement` | `✅ 實作完成` | `handoff-implement` | 實作者完成實作與本地 commit 並提交交件單，轉交給審查者 |
| `handoff:review` | `🔁 審查退回` 或 `🟢 審查通過` | `handoff-review` | 審查者提交結果；退回修正時通知實作者接手，審查通過且設為 `auto` 時通知啟動收尾 |
| `handoff:finish` | `📦 收尾完成` | `handoff-finish` | 收尾角色完成規格封存、文件同步與 commit |
| `handoff:attention` | `🔴 需要你處理` | `handoff-attention` | 迴圈停下等待人工介入（如 blocked、達輪數上限、工作區 dirty、等候手動執行 `handoff-finish`，或傳訊失敗等） |

### 2. 進度開關與停點安全保護

交接迴圈在 `~/.config/ai-notify/config` 提供三個獨立的進度通知開關，可隨時透過 `bash scripts/notify/telegram/update.sh types` 調整：

| 設定鍵 | 選單名稱 | 預設值 | 說明 |
|---|---|---|---|
| `NOTIFY_HANDOFF_IMPLEMENT` | 交件單實作完成 | `true` | 實作者交付交件單時的進度通知 |
| `NOTIFY_HANDOFF_REVIEW` | 交件單每輪審查 | `true` | 審查退回修正或通過並自動收尾時的進度通知 |
| `NOTIFY_HANDOFF_FINISH` | 交件單收尾 | `true` | 收尾角色完成交付時的進度通知 |

> **🚨 停點安全保護 (Safety Anchor Guarantee，不可關閉)**：
> 當迴圈因任何原因停下需要人類處理時（如 `blocked`、達 `max_rounds` 上限、工作區未提交或 HEAD 不符、或審查通過等候手動執行 `handoff-finish`），系統會強制發送 `handoff-attention` 通知。**此類停點訊號不可被關閉**，確保迴圈絕不靜默掛起。

### 3. Agent 身分標記格式

交件單通知會自動從當前 Session 宿主提取停下 Agent 的工具名稱、模型與推理強度：
- **Xirp 角色**：從 Xirp session API 提取動態模型與 effort，標註格式如：
  ```text
  Agent Handoff (Claude / claude-opus-5-5 / high) (#6ec9b3e2)
  Agent Handoff (Codex / gpt-6.1-sol / medium) (#9a8b7c6d)
  ```
- **Herdr 角色**：因 Herdr 不主動回報模型，模型標記為範本設定值（如 `model=gpt-6.1-sol(template)`），Session 標註 Herdr pane ID 與原生 Session ID：
  ```text
  Agent Handoff (Claude / claude-opus-5-5(template) / high) (herdr:w2:p1)
  ```
通知內容並附帶 7 碼短 commit SHA 以及清晰的「下一步」指引（如：下一位 Agent 誰接手，或提示你執行 `handoff-finish <change>`）。

### 4. 傳訊失敗重試保障 (Retry)

當 Stop 鉤子向審查者或實作者傳遞訊息（Xirp send 或 herdr agent prompt）失敗，或開啟新 Session 失敗時：
1. **交件單保留未處理**：交件單不會被標記為 `.routed`。
2. **發送 Attention 警報**：發送一次 `🔴 需要你處理` 通知，指明傳訊或開啟失敗原因。
3. **安全重試**：排解原因（如重啟 Session 宿主服務）後，下次 hook 觸發或手動執行 `~/.config/wk-workflow/handoff/handoff-route --foreground` 即可立即重試，傳送成功後隨即補發進度通知。

---

## 常見問題與排錯 Q&A

### Q1: Agent 停止後，為什麼完全沒有觸發下一位 Agent？
1. **未信任鉤子**：在 Codex 中，必須在 `/hooks` 面板中將 `Stop` 鉤子信任一次（Trusted），並確認勾選 `[x]`。
2. **Session 啟動順序**：鉤子是在 Session 啟動時載入，若該 Session 是在執行 `install.sh` 之前就已開啟，該 Session 結束時不會觸發路由。
3. **未寫交件單**：檢查 `.agent-handoff/<change-id>/` 是否有新產生的交件單 YAML。
4. **查閱紀錄**：檢視 `.agent-handoff/<change-id>/routing.log`，確認 Stop hook 實際執行的動作與錯誤輸出。

### Q2: 提示「worktree 的 HEAD 與交件單的 head 不同，未交接」？
交件單記載的 `head` 必須等於該 worktree 當前最新的 commit SHA。請確認 Agent 在寫入交件單前已完成 `git commit`，且沒有在寫單後又產生新的提交。

### Q3: 提示「有未提交的變更，未交接」？
為確保代碼安全與交接可重現，在交接前工作區必須乾淨（clean）。請檢查 `git status`，將暫存或未暫存的修改提交或清理後，重新執行 `handoff-write` 寫單。

### Q4: 收尾角色執行 PR 交付時被阻擋（網路權限不足）？
Codex 預設的 `workspace-write` 沙盒禁止對外網路存取。若收尾角色需執行 `git push` 或呼叫 GitHub API，請確保：
1. 執行過 `bash scripts/handoff/install.sh` 生成 `~/.codex/handoff-net.config.toml`。
2. `.agent-handoff/roles.yaml` 中的 `finish` 角色加上 `profile: handoff-net`。

### Q5: 迴圈因 `blocked` 停下後，該如何恢復與接續？
`blocked` 的交件單會暫停迴圈，系統不會自行重啟：
- **實作或審查 blocked**：排除阻礙原因後，由實作者在乾淨且已 commit 的 `HEAD` 產生一筆新的 `implement` / `done` 交件單。Stop hook 會將其作為新一輪轉交給審查者（計入 `max_rounds`）。若審查僅因「需要人工親自驗收（例如真實環境驗證）」而 blocked，請人工完成驗收並將證據記錄在該 Change 的 Work Item 中，再請實作者勾選 Task、commit 並交件。
- **收尾 blocked**：若因網路或權限問題導致 `finish` 失敗，排解問題後再次執行 `handoff-finish <change-id>` 即可重試或重開收尾 Session。

### Q6: 審查者額度用完，迴圈中途要換人？
先確認舊審查者已停止（或已閒置），再以 `--replace` 更換。若收尾是共用實作者 worktree 的 Pi，Pi 審查者需要自己的 worktree：

```bash
handoff-role <change-id> review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace
```

舊 session 會被刪除；已送給舊審查者、還沒有審查結果的這一輪，會改送給在 `<worktree>-review` 開啟的新審查者。可在 `routing.log` 看到 `reviewer:opened`。

### Q7: Xirp 顯示 Pi 角色為 `finished`，但工作似乎還沒完成？
Pi 角色在背景工作或等待時，Xirp 介面可能暫時標記其為 `finished`，但實際執行程序仍在進行，Stop hook 發送的訊息依然能正常送達。請以交件單記錄及 `.agent-handoff/<change-id>/routing.log` 的實際進度為準。

### Q8: Herdr 角色啟動後停在對話框（如資料夾信任、權限詢問），迴圈停下？
在新的 Linked Worktree 中，Claude Code 或 Codex 可能會跳出資料夾信任或權限對話框：
1. 迴圈不會替你自動點選，而是保留該 Pane、標記 `pending_prompt`，並發送一則 `🔴 需要你處理` 的 Attention 通知，註明 Herdr 的 workspace、tab 與 pane ID。
2. 前往該 Tab / Pane 依指示確認並信任資料夾。
3. 執行通知提示的 `handoff-route --foreground`（若在實作者啟動時遇到，則重新執行 `handoff-start <change-id>`），迴圈會直接向原 Pane 補送提示，無需重新建立環境。

### Q9: 迴圈移除 worktree 後，出現幾乎空白的殘留目錄（只剩 `.codex/config.toml` 或 `.claude/settings.local.json`）？
這是因為 TokenEconomizer 快取了該 checkout 路徑，並於背景將設定寫回已移除的目錄：
1. 在本專案根目錄執行清理預覽：`python3 -I scripts/user/te-prune-stale-checkouts.py --dry-run`。
2. 確認無誤後正式清除快取：`python3 -I scripts/user/te-prune-stale-checkouts.py`。
3. 刪除該殘留目錄即可。

### Q10: Herdr 提示文字停在輸入框（Composer）沒有自動執行？
剛啟動的 Agent 在初始化過程中偶爾會遺漏 Enter 觸發訊號：
1. 迴圈內建自動防卡死機制：當 Herdr 回報 `agent_prompt_stalled` 時，會自動補按一次 Enter（不重送文字）並再次等待。
2. 若仍然沒有動靜，迴圈不會盲目重送，而是將該提示保存為 `.agent-handoff/<change-id>/<role>-unconfirmed.txt` 並發送通知。此時 hook 與啟動命令會進入防護鎖定，避免重複發送。
3. 前往該 Herdr Pane 查看：若文字停在輸入框，手動按 Enter 送出；若完全沒收到，貼上該檔案內容。確認 Agent 開始工作後，手動刪除該 `<role>-unconfirmed.txt` 檔案即可解除保護繼續迴圈。

[^handoff-scripts]: [Agent Handoff Loop Scripts](/scripts/handoff/README.md)
[^handoff-skill]: [Agent Handoff Skill](/template/common/skills/agent-handoff/SKILL.md)
[^notify-telegram]: [Telegram Notify Guide](/docs/notify/telegram.md)
