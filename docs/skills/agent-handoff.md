---
type: Playbook
title: Agent Handoff 交接迴圈指南
description: 使用 handoff-start、handoff-finish 與 handoff-cleanup 協調多 Agent 自動化實作、審查與收尾。
tags: [skills, handoff, workflow, xirp, agents, notify]
generated: { by: "claude-code/claude-opus-5-5", at: "2026-11-19T10:06:02+08:00" }
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

每個 Agent 在當前輪次結束時，透過 `agent-handoff` Skill 寫入標準化的「交件單」；當 Agent 停下時，系統內建的 `Stop` 鉤子（`handoff-route`）會讀取該交件單，透過 `xirp` CLI 自動向下一位 Agent 發送訊息，並發送 Telegram 即時進度通知或在需要人工介入時發送停點警報。[^handoff-scripts]

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
                        │ 透過 Xirp 傳遞訊息
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
- `{author}`：自動產生之身分說明區塊（包含工具、模型與 Xirp Session ID）

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
- `--reviewer-session <xirp-id>`：綁定並沿用現有的 Xirp session 作為審查者。

override 換了工具時，prompt 開頭的 skill 呼叫會改成新工具的寫法（例如 `$change-review` 換成 Pi 的 `/skill:change-review`），以舊工具名稱開頭的 session 名稱也會改成新工具名稱。

**迴圈中更換角色：** 審查或收尾的 session 尚未開啟時，可用 `handoff-role <change-id> <review|finish> <override>` 更換（例：`handoff-role add-export review pi:openai/gpt-6.2-sol:high:api`）。它會先跑與 `handoff-start` 相同的檢查（範本欄位、一個 worktree 最多一個 Pi 角色、Pi 的模型、憑證、計費與信任），全部通過才寫入實作者的 `loop.yaml`；角色 session 已開啟時拒絕，永不修改 `roles.yaml` 與實作者。

### 2. `handoff-finish <change-id>`

當審查通過後，啟動收尾階段：

```bash
handoff-finish <change-id>
```

**執行條件與行為：**
- 檢查最新交件單必須為 `review` / `done` / `pass`。
- 檢查實作者 worktree 的 HEAD 與交件單記載之 `head` 一致且乾淨（無未暫存修改）。
- 若設定 `finish.worktree: new`，實作者 worktree 會切換至 detached HEAD，新建立的 `../<repo>-<change-id>-finish` 接手 `feature/<change-id>` 分支進行收尾。
- **失敗重試（Retry）**：若收尾過程因網路中斷或遠端拒絕而停下（交件單為 `finish` / `blocked`），排解問題後再次執行 `handoff-finish`，系統會直接自中斷點接續或重開收尾 Session。
- **實作或審查 blocked 後接續**：迴圈不會自行恢復。排除原因後，請實作者在乾淨且已 commit 的 `HEAD` 寫一筆新的 `implement` / `done` 交件單，hook 會把它當成下一輪交給審查者（計入 `max_rounds`）。審查只因需要人親自做的步驟（例如真實環境驗收）而 blocked 時：由人完成該步驟、把證據記在該 change 的 Work Item（cleanup 會歸檔被移除 worktree 的 Work Item），再請實作者勾選 task、commit 並交件。

### 3. `handoff-cleanup <change-id> [--abandon] [--yes]`

當迴圈完成或決定放棄時，執行安全回收：

```bash
# 預覽將被清理的項目（乾跑，Dry Run，不變更狀態）
handoff-cleanup <change-id>

# 正式執行清理
handoff-cleanup <change-id> --yes

# 放棄未完成的迴圈並清理
handoff-cleanup <change-id> --abandon --yes
```

**三道安全防護門檻：**
1. **紀錄判定**：最新交件單必須為 `finish: done`（除非明示 `--abandon`）。
2. **乾淨檢查**：迴圈內的所有 worktree 必須為 clean（無未提交變更），任何 dirty state 均會立即報錯終止，**絕不冒險丟失代碼**。
3. **主工作區保護**：主 repo 工作區永遠保留，不執行 worktree remove。

**執行清理動作：**
1. **歷史證據歸檔**：將 `.agent-handoff/<change-id>/` 內的交件單與審查報告拷貝至主工作區 `.agent-handoff/archive/<change-id>/` 保存；即將移除的 worktree 中的 `work-items/WI-*` 也整個複製到 `archive/<change-id>/<worktree>/work-items/`，避免審查引用的驗收證據隨 worktree 消失。主工作區的 Work Item 留在原處；預覽（不加 `--yes`）會列出將歸檔的 Work Item。
2. **刪除 Sessions**：呼叫 `xirp session delete` 釋放背景程序。
3. **移除臨時 Worktrees**：安全移除額外建立的實作與收尾 worktree。
4. **保留分支**：`feature/<change-id>` 分支與已提交 commit 永遠保留，由團隊另行授權 merge 與清理。

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

1. **`handoff-start`**：在建立 worktree 與開 Session 前，驗證所有 Pi 角色——一個 worktree 最多一個 Pi 角色、Pi 觸發器已安裝、主 worktree 已在 Pi 信任、模型列在該 provider 下、`pi auth check` 為 `ready` 且 `oauth` 對 `subscription`、`api_key` 對 `api`。
2. **路由交件單**：交件單的 `agent` 區塊與 `loop.yaml` 的範本不同（例如中途 `/model`），或缺少、為 `unknown`，就不接棒，通知你一次。
3. **hook 開 Pi 審查或收尾前**：重做第 1 點的驗證；失敗時通知一次、交件單保留，修正後下次觸發會重試。

Xirp 目前不套用 Pi 1.x 的啟動選項，所以角色從寫入其 worktree 的 `.pi/settings.json` 啟動；這個檔案以 repo 本機的 `info/exclude` 忽略、不進 Git。因此一個 worktree 最多一個 Pi 角色：Pi 角色可以和 Claude Code、Codex 共用 worktree，第二個 Pi 角色要設 `worktree: new`。

Pi 會在有 `.pi/settings.json` 或 `.agents/skills` 的資料夾詢問是否信任。Pi 觸發器（`~/.pi/agent/extensions/wk-handoff.ts`）只在「主 repo 已被你在 Pi 信任、未被追蹤的 `loop.yaml` 列出這個 worktree」時替該 Session 回答信任，不寫入 `trust.json`。第一次使用 Pi 角色前，請在主 worktree 以 Pi 執行一次 `/trust`；安裝後已開啟的 Pi Session 需 `/reload`。

`anthropic` 搭配 `subscription` 且認證為 `oauth` 時照常執行，但 `handoff-start` 會提醒可能使用付費的 extra usage。角色內 subagent 會換 provider 的三種例外，見 [Pi roles](/scripts/handoff/README.md#pi-roles)。

---

## 交接迴圈即時通知 (Notifications)

交接迴圈內建 Telegram 結構化事件通知，由 Stop 鉤子（`scripts/handoff/handoff-route`）在每次路由交件單時自動送出。通知具備專屬的進度回報、不可關閉的停點安全保護、Agent 身分標記與失敗重試保障。[^notify-telegram]

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

交件單通知會自動從 Xirp session 提取當前停下 Agent 的工具名稱、模型與推理強度，標註格式如下：
```text
Agent Handoff (Claude / claude-opus-5-5 / high) (#6ec9b3e2)
Agent Handoff (Codex / gpt-6.1-sol / medium) (#9a8b7c6d)
```
通知內容並附帶 7 碼短 commit SHA 以及清晰的「下一步」指引（如：下一位 Agent 誰接手，或提示你執行 `handoff-finish <change>`）。

### 4. 傳訊失敗重試保障 (Retry)

當 Stop 鉤子向審查者或實作者傳遞訊息（Xirp send）失敗，或開啟新 Session 失敗時：
1. **交件單保留未處理**：交件單不會被標記為 `.routed`。
2. **發送 Attention 警報**：發送一次 `🔴 需要你處理` 通知，指明傳訊或開啟失敗原因。
3. **安全重試**：排解原因（如重啟 Xirp 服務）後，下次 hook 觸發或手動執行 `~/.config/wk-workflow/handoff/handoff-route --foreground` 即可立即重試，傳送成功後隨即補發進度通知。

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

[^handoff-scripts]: [Agent Handoff Loop Scripts](/scripts/handoff/README.md)
[^handoff-skill]: [Agent Handoff Skill](/template/common/skills/agent-handoff/SKILL.md)
[^notify-telegram]: [Telegram Notify Guide](/docs/notify/telegram.md)
