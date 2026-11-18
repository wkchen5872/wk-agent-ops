# Design

## Context

動機與驗收條件見 proposal.md。影響做法的現況：

- `scripts/handoff/handoff-route` 在 Agent 停下時讀最新的交件單並路由；只有需要使用者處理的分支呼叫 `ho_notify_user`（約十處），
  訊息是一段已經組好的文字。
- `ho_notify_user` 以一般的 `notification` 事件呼叫 `telegram-notify.sh`，並帶 `NOTIFY_ACTION_REQUIRED=true` 強制送出；
  所以標題固定是「Action Required」，也無法個別開關。
- hook 已用 `xirp session get` 取得停下 Session 的模型寫入 `routing.log`；同一份回應裡有工具（`currentAgent`）與啟動選項中的 effort。
- hook 的輸入（Stop 事件的 JSON）帶有該 Session 的原生 `session_id`，一般的 Task Complete 通知用它產生標題的 Session 標籤。
- `refine-notify-core` 提供訊息範本、事件對照表與 `{name}` 取代；本 change 以它為前提。

## Goals / Non-Goals

**Goals:**

- 使用者從通知就能看出迴圈走到哪一步、是誰做的、接下來會發生什麼。
- 進度通知可個別關閉；迴圈停下等使用者的通知一定送出。
- 路由行為與失敗時安靜結束的保證不變。

**Non-Goals:**

- 不改路由規則、交件單格式與 `loop.yaml`。
- 不抑制同一個 Session 的一般 Task Complete 通知（使用者先觀察再決定）。
- 不維護模型的顯示名稱對照表。
- 不把交接迴圈延伸到 Antigravity，也不新增輪詢或逾時偵測。

## Decisions

### 1. `handoff-route` 送結構化事件，通知端組訊息

```
handoff-route（路由完成後）
      |
      |  JSON：kind、change、round、verdict、commit、next、detail、agent、session_id、cwd
      v
telegram-notify.sh handoff
      |
      +── 查事件對照表：handoff:<kind> → 範本
      +── 套開關（attention 不看開關）
      +── 套範本、送出
```

- `ho_notify_user` 改為接收種類與欄位，組成 JSON 後呼叫通知腳本的 `handoff` 事件；移除 `NOTIFY_ACTION_REQUIRED=true` 的覆寫。
- 開關在通知端判斷，`handoff-route` 不讀通知設定。這樣交接腳本不依賴通知的設定格式，通知停用或未安裝時行為與現在相同。
- 替代方案：在 `handoff-route` 裡組好文字再送。不採用——標題、開關與範本就得在兩個地方各維護一份。

### 2. 四種事件與開關

| 事件鍵 | 何時 | 開關 | 預設標題 |
| --- | --- | --- | --- |
| `handoff:implement` | `implement`／`done` 已交給審查者 | `NOTIFY_HANDOFF_IMPLEMENT` | ✅ 實作完成 |
| `handoff:review` | `review`／`done` 為 `changes-required`（已轉給實作者），或 `pass` 且收尾為 `auto` | `NOTIFY_HANDOFF_REVIEW` | 🔁 審查退回／🟢 審查通過 |
| `handoff:finish` | `finish`／`done` | `NOTIFY_HANDOFF_FINISH` | 📦 收尾完成 |
| `handoff:attention` | 迴圈需要使用者才能繼續 | 無，一律送出 | 🔴 需要你處理 |

- 審查通過且收尾為 `ask` 時屬於 `attention`：迴圈停在這裡等使用者執行 `handoff-finish`。若把它放在審查開關底下，
  使用者關掉審查通知後迴圈會無聲停住。
- 三個開關缺少時視為開啟。使用者要先看到完整順序，再決定關哪一個。
- `attention` 在 Telegram 啟用時一律送出，不受 `NOTIFY_LEVEL` 與四個一般分類影響。
- 替代方案：審查退回與通過各一個開關。不採用——使用者提出的是「第 N 輪審核通知」一類；需要更細時再加。

### 3. Agent 資訊

- 取自寫下交件單的 Session（即觸發 hook 的 Session，`CHIRP_SESSION_ID`）在 Xirp 的當下資料：工具、模型、effort。
  與 `routing.log` 用同一次查詢，不多打一次。
- 顯示為 `Agent Handoff (<工具> / <模型> / <effort>)`。工具顯示為 Claude 或 Codex；模型與 effort 原樣顯示（例如 `claude-opus-5-5`、`high`）。
  取不到的部分省略；都取不到時只顯示 `Agent Handoff`。
- 替代方案：顯示「Opus 5.5」這類名稱。不採用——需要一張隨新模型更新的對照表；原樣顯示不會過時，也和 `routing.log`、Xirp 一致。
  使用者可在自己的範本調整其他文字，但模型名稱以 Xirp 回報為準。

### 4. 訊息欄位

- 範本參數：`{agent}`、`{change}`、`{round}`、`{verdict}`、`{commit}`（7 碼）、`{next}`、`{detail}`、`{project}`、`{time}`、`{title_suffix}`。
- `{next}` 由 `handoff-route` 依實際採取的動作產生，例如「已請審查者審查第 2 輪」「已把報告交給實作者」
  「請執行：handoff-finish <change-id>」。`{detail}` 放交件單的 `note`（blocked、收尾停下時）。
- 標題的 Session 標籤沿用 hook 輸入的原生 `session_id`，和同一個 Session 的 Task Complete 通知一致。
- 內建範本四個：`handoff-implement`、`handoff-review`、`handoff-finish`、`handoff-attention`；使用者可用同名檔覆寫。

### 5. 路由結果的三種分類（審查 r02/F-01、r04/F-01）

現況：`to_reviewer`、`to_implementer` 呼叫 `ho_xirp_message` 後不看結果就回報 `messaged`，交件單也照樣寫入 `.routed`；
傳訊失敗時迴圈其實已經停住，卻會被記成已交付。另一方面，需要使用者處理的停點如果不寫入 `.routed`，每次 Agent 停下都會重發通知。
所以「要不要標成已處理」不能只分成兩種：

| 結果 | 例子 | 通知 | 寫入 `.routed` | 之後的 hook 執行 |
| --- | --- | --- | --- | --- |
| 已交付 | 已開啟或已通知審查者、已把報告交給實作者、已自動開啟收尾 | 進度通知（依開關） | 是 | 不再處理 |
| 人工停點 | blocked、輪數上限、任何 finish 交件單、通過且 `ask`、worktree 不乾淨或版本不符、無法判讀 | attention 一則 | **是** | 不再處理、不再通知 |
| 可重試的失敗 | Xirp 傳訊失敗、開不了審查或收尾 Session、建立或移動審查 worktree 失敗 | attention 一則（以 `.notified` 記錄） | **否** | 重試；成功後才發進度通知並寫入 |

- 人工停點是這張交件單的最終結果：使用者接下來用指令（例如 `handoff-finish`）或讓 Agent 寫新的交件單來推進，交件單本身不需要再處理。
  這與現行行為一致（現在這些情況都會寫入 `.routed`）。
- 可重試的失敗是 hook 想做的動作沒做成：`routing.log` 記為 `…:send-failed` 或 `…:open-failed`，attention 內容為
  「無法把第 N 輪交給審查者／實作者，迴圈已停住」與重試方式；同一張交件單的失敗通知只發一次，重試再失敗不重發。
- 重試：之後任何一次在該 worktree 觸發的 hook 都會再試；也可以在該 worktree 手動執行 `handoff-route --foreground`。
- 因此每張交件單最多一則進度通知、最多一則 attention。
- hook 仍以成功狀態結束，不影響 Agent。
- 替代方案：失敗也標成已處理，只靠 attention 提醒。不採用——使用者處理完原因後沒有辦法讓 hook 再送一次，只能自己手動傳訊。

### 6. 混版部署與回退（審查 r02/F-02、r04）

交接端與通知端由兩個 installer 分別部署。只更新交接端（或通知端被回退）時，舊的通知 hook 不認得 `handoff` 事件；
在 `attention_required` 層級下未知事件會被濾掉，唯一要使用者處理的提示就會消失。

- 判斷依據綁在**實際會被執行的通知腳本**上：新版 `telegram-notify.sh` 內含一行能力宣告（例如 `# ai-notify-capability: handoff-events`），
  交接端在送出前檢查它要呼叫的那個檔案有沒有這一行。
- 不用事件對照表判斷：舊版 installer 回退 hook 時不會刪除它不認識的 `events.tsv` 與範本，殘留的表檔會誤報支援。
  也不呼叫通知腳本探測：舊版腳本會把不認得的參數當成事件處理。
- 有宣告：走新的 `handoff` 事件。沒有宣告（舊版、已回退、或腳本不存在）：`attention` 類改走原本的一般通知路徑——
  `notification` 事件、純文字訊息、帶 `NOTIFY_ACTION_REQUIRED=true`，與現行行為相同；進度類不送（舊版本來就沒有）。
- 新版通知腳本收到 `attention` 而對照表列或範本缺少時（部署不完整），以內建的後備文字送出，不丟棄。
- 反方向（舊的交接端、新的通知端）由 `refine-notify-core` 保留的「環境變數舊鍵覆寫仍會送出」保證。
- 限制：能力宣告是腳本內的固定文字，使用者手動改寫通知腳本並移除該行時，交接端會退回一般通知路徑（attention 仍送達，只是沒有專屬標題）。

| 交接端 | 通知腳本 | 殘留的新版表檔與範本 | attention | 進度通知 |
| --- | --- | --- | --- | --- |
| 新 | 新 | — | `handoff` 事件，專屬標題 | 依開關 |
| 新 | 舊（尚未更新） | 無 | 一般通知路徑（Action Required） | 不送 |
| 新 | 舊（由舊 installer 回退） | **有** | 一般通知路徑（Action Required） | 不送 |
| 舊 | 新 | — | 一般通知路徑（由 core 的相容規則送出） | 無 |

### 7. TDD 策略與測試邊界

- `tests/test_agent_handoff.sh` 的假通知腳本改為記錄收到的事件與 JSON。先寫失敗測試：每種交件單產生的事件種類與欄位、
  `attention` 的各個來源、同一張交件單不重複通知、Xirp 讀不到 Agent 資訊時仍路由並送出不含 Agent 的通知、不再出現環境變數覆寫。
- `scripts/notify/telegram/test.sh` 以 dry-run 驗證：四個範本的輸出、三個開關與缺少鍵的預設、`attention` 在所有開關關閉時仍送出、
  交件單事件不落到等待回應的範本。
- 傳訊失敗：假的 `xirp` 對 `session message` 回傳非零，分別測審查者與實作者兩條路徑——沒有進度通知、有一則 attention、交件單不在 `.routed`、
  hook 以成功結束；再次執行仍失敗不重發 attention；改為成功後訊息送出一次、進度通知出現、交件單寫入 `.routed`。
- 人工停點：同一張通過且 `ask` 的交件單、同一張 blocked 的交件單各執行 hook 兩次，第二次沒有任何通知或路由，交件單在 `.routed`。
- 混版：以暫時 HOME 做四種通知端——沒有通知腳本、舊版腳本、新版腳本、**完整安裝新版後只把通知腳本換回舊版而保留新版的對照表與範本**——
  驗證審查通過且 `ask`、blocked 兩種情況在前兩者與最後一種都經一般通知路徑送達，在新版走 `handoff` 事件；進度類只在新版送出。
  舊版通知腳本以凍結的測試 fixture 提供（變更前的 `hook.sh` 副本），不依賴 Git 歷史。
- 既有的路由測試（開啟或通知審查者、退回、輪數上限、乾淨檢查）必須維持通過，證明傳訊成功時的路由沒有改變。
- 測試都在暫時的 HOME 與假的 `xirp`、假通知腳本下執行，不送真實 Telegram。
- 真實驗收另列：在演練用的 repo 跑一輪含退回的迴圈，對照收到的通知順序，結果記入 Work Item。

## Risks / Trade-offs

- [實作完成與 Task Complete 會各發一則] → 使用者已接受；兩者帶相同的 Session 標籤，方便之後決定關哪一個。
- [通知變多] → 三個開關可關；`attention` 才是必須處理的。
- [Xirp 回報的 effort 欄位名稱依工具不同（`effort`、`reasoning_effort`）] → 兩個都讀；讀不到就省略。
- [通知端是舊版或已回退，且留下新版的對照表] → 判斷依據是通知腳本自己的能力宣告，不看表檔；偵測不到時改走一般通知路徑，attention 仍送達（決策 6）。
- [傳訊失敗後沒有 Agent 再停下，hook 不會自動重試] → attention 寫明手動重試指令 `handoff-route --foreground`；之後任何一次在該 worktree 的 hook 執行也會重試。
- [未寫入 `.routed` 的交件單在每次 hook 執行時都重試] → 只有可重試的失敗不寫入；人工停點照常寫入，不會重發；attention 每張交件單只發一次。
- [`attention` 不可關閉可能被認為太吵] → 這些情況下迴圈已經停住；文件說明原因。

## Migration Plan

1. `refine-notify-core` 合併後才實作本 change（需要它的範本、事件對照表與設定）。
2. 部署：`scripts/notify/telegram/update.sh` 與 `scripts/handoff/install.sh` 可以任一先執行。只更新其中一個時，
   「需要你處理」仍經一般通知路徑送達（決策 6）；兩者都更新後才有專屬標題、Agent 資訊與進度通知。hook 的登記指令不變，Codex 不需重新信任。
3. 進行中的迴圈不受影響：通知只取決於之後處理的交件單。
4. 回退：兩個腳本可以各自回退，順序不限。通知端回退後交接端自動改走一般通知路徑；交接端回退後回到現行行為。新增的三個設定鍵對舊版無作用。
