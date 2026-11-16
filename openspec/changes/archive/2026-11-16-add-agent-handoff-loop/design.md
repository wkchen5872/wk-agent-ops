# Design

## Context

動機見 proposal.md。設計依據是 Work Item `WI-20261116-agent-commander` 的決策 D-001～D-012，
以及該 Work Item 第 7–9 節的本機實測：

- Xirp API `session:create` 可帶 `agent.options` 的模型與 effort，並以 `customName` 固定名稱；
  `xirp session new` 沒有 effort 選項。只帶 `name` 時名稱可能被自動標題覆蓋。
- Session 結束後成功與失敗都顯示 `idle`，無法用狀態判斷結果。
- Claude Code 與 Codex 的 Stop hook 都能取得 `CHIRP_SESSION_ID` 並執行 `xirp`；Codex 的 stdin 另含原生
  `session_id`、`turn_id` 與 `last_assistant_message`。Codex 只在 Session 啟動時載入 hook，新 hook 需使用者信任。
- Codex 無法寫入 repo 外的檔案；同一分支不能同時被兩個 worktree 使用；同機 worktree 共用 Git 資料庫。
- `retire-worktree-session-helpers` 退役了 repo 自有的 Session／worktree launcher；現行文件把 worktree 交給
  使用者選用的工具（Xirp、Herdr 或 `git worktree add`）。
- 現有腳本依賴 `jq`；系統 Python 沒有 PyYAML，也沒有 `yq`。
- `openspec-apply-change` 由 OpenSpec 產生並以其工具更新，不在本 repo 修改。

## Goals / Non-Goals

**Goals:**

- 交接決策完全由不用模型的腳本完成；Agent 只負責寫交件單。
- Claude Code 與 Codex 兩邊行為一致；沒有 Xirp 時一切安靜退回手動流程。
- 每個元件可以單獨使用：只有交件單時，人看交件單就知道輪到誰。

**Non-Goals:**

- 不合併、不刪分支；Session 與 worktree 只在收尾完成後由使用者執行 `handoff-cleanup` 清理，hook 不自動清理。
- 不支援 Herdr、Antigravity、GitHub Copilot CLI 的 hook。
- 不修改 `openspec-apply-change`；實作者的交件要求寫在 prompt 裡。

## Decisions

### 1. 元件與資料流

```text
roles.yaml（主 worktree，不進 Git）
   │ handoff-start 讀取並複製到 loop.yaml
   ▼
handoff-start ──核心──► worktree A（feature branch）＋ 實作者 Session
                              │ 實作、commit、handoff-write
                              ▼
                     .agent-handoff/<change>/NN-implement.yaml
                              │ Agent 停下 → Stop hook
                              ▼
                     handoff-route（hook）──核心──► 審查者 Session（第一輪才開）
                              │ xirp session message
                              ▼
                     change-review → handoff-write → NN-review.yaml → Stop hook
                              │
            changes-required ─┘ pass ─► ask：通知使用者 → handoff-finish ──核心──► 收尾 Session
                                        auto：直接開收尾 Session
```

- **核心**（`scripts/handoff/lib/handoff.sh`）只做一件事：依某個範本準備 worktree、以 Xirp API 開 Session、送出 prompt，
  回傳 Xirp Session ID。`handoff-start`、`handoff-finish` 與 hook 都呼叫它。
- **hook**（`handoff-route`）只讀交件單與 `loop.yaml`、做檢查、送訊息或呼叫核心，從不寫 GitHub、不 push。
- `scripts/handoff/` 為新目錄；`scripts/workflow/` 維持「不提供 launcher」的邊界不變。

替代方案：做成 Agent（指揮官）判斷下一步——每次交接都花 token，且結果不穩定，留待後續另案。

### 2. 交件單與 `loop.yaml` 的格式：受限 YAML，自帶解析器

- 交件單是單層 `key: value`；`roles.yaml` 與 `loop.yaml` 最多兩層（角色 → 欄位），值都是純量字串。
- 由 `agent-handoff` Skill 內的 `scripts/kv.sh` 小型解析器讀取（awk），`handoff-write` 與 `scripts/handoff/` 共用這一份；
  有測試覆蓋；寫入一律經由腳本，格式由腳本控制。
- 使用者可讀可改，且不新增依賴。

替代方案：PyYAML（系統 Python 沒有）、`yq`（未安裝，新增依賴）、改用 JSON（使用者編輯 `roles.yaml` 不友善）。

### 3. 交件單由 Skill 附帶的腳本寫入

`template/common/skills/agent-handoff/scripts/handoff-write` 經 installer 裝到 `.claude/skills/` 與 `.agents/skills/`，
Agent 在任何 repo 都以固定相對路徑呼叫。腳本以 `git rev-parse --show-toplevel` 取得 worktree 根目錄、計算下一個編號、
驗證欄位後以暫存檔加 rename 寫入，避免殘缺檔案。

替代方案：寫成規範讓 Agent 手寫 YAML——每個 Session 都載入規範，格式無法保證（D-002）。

### 4. worktree 佈局

- 實作者預設 `git worktree add ../<repo>-<change> feature/<change>`，再以 Xirp API 的 `worktreePath` 開 Session（D-011）。
  不依賴 Xirp 建 worktree，因為 Xirp 對「既有分支」的 worktree 行為未驗證；`git worktree add` 是現行文件列出的選項之一。
- 審查與收尾都支援 `shared` 與 `new`，預設 `shared`（D-012）；使用者要並行比較兩種習慣。受審版本以「該 worktree 的
  HEAD 等於交件單的 head 且工作區乾淨」固定，每輪 commit（D-009）讓這個條件在交接當下自然成立。
- **交件單位置**：每筆交件單留在寫它的角色所在的 worktree（實作在 A，審查在 A 或 B，收尾在 A 或收尾 worktree）。
  `loop.yaml` 列出所有 worktree；`handoff-write`、hook 與 `handoff-finish` 依它讀取各 worktree 的 `.agent-handoff/<change>/`，
  只讀不寫別人的目錄。序號跨所有 worktree 計算，A、B 合起來仍是 01、02、03…。
- **報告位置**：報告存在審查者自己的 worktree；交件單的 `report` 相對於該 worktree，hook 傳訊時換成絕對路徑，
  實作者以唯讀方式讀取。不搬移整個 Work Item。
- **審查 `new`**（審查 r01 F-01）：第一輪由 hook 以 `git worktree add --detach` 在交件單 head 建立 B，更新 A 的 `loop.yaml`
  並寫一份完整副本到 B（D-010）。之後每輪由 hook 移動 B：確認 B 乾淨後 `git checkout --detach <新 head>`，再通知審查者；
  B 不乾淨就通知使用者、不移動。hook 此時正在處理實作者的交件，審查者已停下，不會同時寫入。
- **收尾 `new`**：同一分支不能同時被兩個 worktree 使用，所以收尾入口先確認 A 乾淨在受審 head，把 A detach 在同一個 commit，
  再開新 worktree checkout feature branch。只 detach、不刪除，A 的檔案與實作者 Session 都保留。
- hook 建立 B 與寫入 B 需要寫到所在 worktree 以外的路徑；Codex hook 是否受沙箱限制未驗證，列為任務 1.2 先查證。

### 5. hook 的判斷順序

1. 找 worktree 根目錄下 `.agent-handoff/*/`，各取最新且未記在 `.routed` 的交件單；沒有就結束。
2. 讀 `loop.yaml`；沒有就結束（未啟用迴圈的手動流程不受影響）。
3. 檢查 HEAD 等於交件單 `head`、工作區乾淨；不符合就通知使用者。
4. 依路由表動作（見 `agent-handoff-routing` spec），把結果與 `xirp session get` 取得的模型附加到 `routing.log`，
   再把檔名寫入 `.routed`。先記錄再送訊息會在送出失敗時漏送；先送再記錄會在記錄失敗時重送。選擇後者，
   因為重送一次的代價（Agent 收到重複通知）低於漏送（迴圈停住）。
5. 任何錯誤以 exit 0 結束。
6. hook 本身只把上述工作交給背景程序後立即結束：開 Session 並等待 Xirp 回報 ID 可能超過 hook 的逾時（共用登記函式設為 10 秒），
   背景執行也保證不阻擋 Agent。測試與手動排查用 `handoff-route --foreground` 同步執行。

通知使用者沿用既有的 `~/.config/ai-notify/hooks/telegram-notify.sh`；不存在時只寫 `routing.log`。

### 6. 實作輪 Review 與最終版 Review 分開

- **實作輪 Review**：由 hook 依交件單觸發，綁定最新 implement record 的 head，結束時寫 `review` 交件單。
- **最終版 Review**：只在 `finish.delivery: pr` 時，由收尾 Session 的 `openspec-commit` 第 7a 步呼叫，
  綁定交付後的 head Y（呼叫端傳入），不套用 implement head 的鎖定，也**不寫交件單**；結果交回 `openspec-commit`。
  不寫交件單是為了讓 hook 不會把它當成新的 pass 再開一次收尾。
- 最終版不是 pass 時不發 Closure，`finish` 交件單為 `status: blocked` 並註明停在最終版 Review；X 的 pass 不能代替 Y。
- hook 收到任何 `finish` 交件單都只通知使用者，不開任何 Session。

### 7. 發布狀態與通知邊界

- 迴圈中 PR 回覆被拒、逾時或回讀不符時，`review` 交件單寫 `status: blocked`、保留技術 verdict，`note` 註明發布狀態；
  hook 對任何 `blocked` 只通知使用者（審查 r01 F-04）。不新增欄位。
- 啟動迴圈只代表一般情況下可以把審查結果交給實作者，不覆蓋單輪的明確指示（審查 r02 F-04）。
- 使用者要求 local-only：維持既有意義（不發 GitHub、不通知），寫 `status: blocked`，`note` 註明 local-only，只通知使用者。
- 使用者同時要求 local-only 與交接、但未說明是否允許本地交接：先說明衝突，未釐清前寫 `status: blocked`，實作者收不到訊息。
- 使用者明確說「不發 GitHub，但交給實作者」：寫 `status: done`，以本地報告路徑照常路由。
- 使用者明確要求這次不通知：`status: blocked` 並在 `note` 註明。

### 8. `handoff-finish` 的檢查

開收尾 Session 前，`handoff-finish` 確認：最新一筆交件單是 `review`、`status: done`、`verdict: pass`；其 head 等於
實作者 worktree 的 HEAD；工作區乾淨；尚無 `finish` 交件單。任一不符就拒絕並說明（審查 r01 F-03）。
hook 的 `auto` 路徑走同一個檢查函式。

### 8.1 `handoff-cleanup`：收尾後清理

一個 change 會留下一到三個 worktree 與三個 Session，手動逐一刪除不實際（演練後使用者回饋）。`handoff-cleanup <change-id>`：

1. 從任一 worktree 找到迴圈，彙整所有 `loop.yaml` 副本記錄的 Session 與 worktree。
2. 只在最新交件單為 `finish`／`done`、且每個要刪的 worktree 沒有未提交的非忽略變更時繼續；否則列出原因、不動任何東西。
3. 沒有 `--yes` 時只列出計畫並結束（exit 0）。
4. 先把各 worktree 的 `.agent-handoff/<change-id>/` 與審查交件單指向的報告，複製到主 worktree 的
   `.agent-handoff/archive/<change-id>/<worktree 名稱>/`（仍被忽略，不進 Git）。
5. 以 `xirp session delete <id> --yes` 刪 Session（不帶 `--delete-worktree`，避免共用的 worktree 被重複處理）；Session 已不存在時回報並繼續。
   沒有 Xirp 時跳過並說明。
6. 以 `git worktree remove`（不加 `--force`）移除主 worktree 以外的 worktree，共用的只移除一次。
7. 分支保留：commit 還沒合併回 main；合併與刪分支另依授權。

實測：`xirp session delete --delete-worktree` 能正確移除非 Xirp 建立的 worktree，但同一 worktree 被多個 Session 共用時
順序難以控制，所以由本指令統一移除。

### 8.2 Codex 收尾的網路

PR 交付演練中，Codex 收尾 Session 的沙箱沒有網路（`CODEX_SANDBOX_NETWORK_DISABLED=1`）：push 靠申請越過沙箱並經自動審核放行而成功，
委派的 PR 回覆沒申請就失敗，結果取決於模型是否記得申請。實測 `codex sandbox` 加上 `sandbox_workspace_write.network_access=true`
後 `gh` 與 HTTPS 的 git 可用，SSH 仍因沙箱讀不到金鑰而被拒。做法：範本可選 `profile`（只限 Codex），由 Xirp 的
`agent.options.profile` 傳入；使用者層級 installer 在缺少時建立 `~/.codex/handoff-net.config.toml`（workspace-write 加網路），
只在角色指定時生效。這會放寬該角色的 Codex 沙箱，需使用者自行執行 installer 同意；SSH push 仍經 Codex 的提權審核。

### 8.3 Author 由腳本產生；blocked 收尾可重試

PR #4 的兩則留言把 `XIRP-SESSION-ID` 抄錯一個字元：只告訴 Agent 去哪裡讀，無法保證逐字複製。`agent-handoff` 新增
`handoff-author`，由 shell 從環境變數印出 Author 四行（讀不到的 ID 依 GitHub 框架寫 `null`），`{author}` 改為要求原樣附加；
委派專用 Agent 時傳 `author_file`，Agent 原樣附加。先前 `{author}` 寫「讀不到就省略、不寫 null」與共用框架相衝，一併改正。

收尾 `blocked` 後，`handoff-finish` 原本把任何 finish 交件單都視為已收尾而拒絕。改為：最新交件單是 finish／blocked、收尾
worktree 乾淨、且 HEAD 包含最新 pass 的 head 時重試——收尾 Session 還在就傳訊請它依中斷恢復接續，不在就重開；`done` 仍拒絕。
hook 對 blocked 收尾的通知附上原因與 `handoff-finish <change-id>`。

### 9. prompt 範本與 Skill 呼叫語法

範本 `prompt` 支援 `{change}`、`{head}`、`{round}`、`{report}`、`{handoff_write}` 佔位符。Claude Code 用 `/skill`，
Codex 用 `$skill`，由範本作者寫明；核心不改寫 prompt。實作者的 prompt 要求：用 `openspec-apply-change` 實作、
通過測試後本機 commit（訊息格式見 D-009）、最後執行 `handoff-write`。

### 10. 專用文案 Agent

`github-pr-agent`、`github-issue-agent` 比照 `git-commit-writer-agent`：呼叫端傳入 `assisting_model`、工具名稱、
原生 Session ID 與 Xirp Session ID；Agent 只照 Skill 規則格式化、寫入與回讀，不改用自己的身分。
Claude 版 `model: sonnet`；Codex 版 `gpt-5.6-terra`、`medium`。`change-review` 第 5 步與 `openspec-commit` 第 7a 步
改為「有專用 Agent 時委派，否則自行執行」。

### 11. 安裝

- 專案層（`scripts/skills/install.sh`）：安裝 `agent-handoff` Skill 與兩個 Agent、合併 `/.agent-handoff/` 忽略規則並雙向驗證、
  只在缺少時放入 `roles.yaml` 範例。
- 使用者層（`scripts/handoff/install.sh`）：把 `handoff-start`、`handoff-finish` 裝到 `~/.local/bin`、hook 裝到
  `~/.config/wk-workflow/hooks/`，並重用 `scripts/workflow/lib.sh` 的設定檔 hook 登記函式，登記到
  `~/.claude/settings.json` 與 `~/.codex/hooks.json`；冪等，並提示 Codex 需信任。

### 12. TDD 策略與測試邊界

- 新增 `tests/test_agent_handoff.sh`，每個測試在 `mktemp` 建立暫時 Git repo 與 worktree。
- 以假的 `xirp` 放在 `PATH` 前面：記錄收到的參數，`session:create` 回傳固定 ID，`session get` 回傳固定模型；
  以假的 `gh` 在被呼叫時讓測試失敗，證明 hook 不寫 GitHub；以假的通知腳本記錄通知。
- 先寫失敗測試再實作：`kv.sh` 解析、`handoff-write` 驗證與編號、hook 路由表每一列（含 blocked 保留 verdict、finish 只通知）、
  去重、輪數上限、乾淨檢查、第一輪開審查者、`ask`／`auto`、沒有 xirp、`handoff-start` 的範本缺漏、未知 worktree 值與分支佔用、
  審查 `new` 的兩輪跨 worktree 案例（A→B→A→B）、收尾 `new` 的 detach 與接手、
  `handoff-finish` 的過期 pass 拒絕、installer 冪等與忽略規則。
- Skill 行為（最終版 Review、發布失敗、local-only、禁通知）以 `tests/acceptance/` 的可重播案例驗證。
- Skill 文字變更（`change-review`、`openspec-commit`、`github-pr`、`github-issue`）以既有 `tests/test_*.sh` 的內容檢查
  與 `tests/acceptance/` 的可重播案例驗證；兩個 Agent 的模型設定擴充 `tests/test_agents_dir.sh`。
- 不在自動測試內：真的 Xirp Session、真的模型、真的 GitHub。這三者由 tasks 中的連動測試與真實演練涵蓋，結果記在 Work Item。

## Risks / Trade-offs

- [hook 只在新開的 Session 生效] → 安裝程式與 README 提示重開 Session；`handoff-start` 開的 Session 一定是新的。
- [hook 失敗會無聲中斷迴圈] → 每個動作寫入 `routing.log`；既有 Telegram「Agent 停下」通知是使用者端的保險。
- [Codex 修改 hook 定義後需重新信任；只改腳本內容是否也要，未驗證] → hook 定義只指向固定路徑的腳本，
  更新時只換腳本內容；演練時驗證是否需重新信任。
- [共用 worktree 時審查者的測試留下檔案] → 乾淨檢查會攔下並通知使用者；需要隔離時用審查 `worktree: new`。
- [審查 `new` 每個 worktree 都要重新安裝依賴才能跑測試] → 由使用者在範本選擇；演練（任務 8.2）兩種模式都跑，比較成本。
- [hook 寫入所在 worktree 以外的路徑可能被 Codex 沙箱擋下] → 任務 1.2 先查證；若被擋，審查 `new` 只在實作者為 Claude Code 時可用，並在 `handoff-start` 檢查時拒絕不支援的組合。
- [Agent 沒有寫交件單] → hook 不動作；使用者仍會收到既有的「Agent 停下」通知，從 `routing.log` 看不到新紀錄即可判斷。
- [Xirp API 未來變更] → 只用到 `session:create`、`session message`、`session get` 三個介面，集中在核心，並在演練時驗證。
- [Xirp 以 `worktreePath` 開 linked worktree 的 Session 未實測] → tasks 的第一步先驗證；不行時改用 `--here` 於該目錄開啟。

## Migration Plan

- 全部是新增；既有手動流程在沒有 `loop.yaml` 時完全不變，`change-review` 的既有通知要求在未啟用迴圈時照舊。
- 回復：移除 `scripts/handoff/install.sh` 登記的 hook 與指令，`agent-handoff` Skill 留著無害。

## Open Questions

- `roles.yaml` 範例中 prompt 的確切措辭，可在真實演練後再調整，不影響規格與任務。
