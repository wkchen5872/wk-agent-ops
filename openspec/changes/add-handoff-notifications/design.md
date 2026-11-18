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

### 5. TDD 策略與測試邊界

- `tests/test_agent_handoff.sh` 的假通知腳本改為記錄收到的事件與 JSON。先寫失敗測試：每種交件單產生的事件種類與欄位、
  `attention` 的各個來源、同一張交件單不重複通知、Xirp 讀不到 Agent 資訊時仍路由並送出不含 Agent 的通知、不再出現環境變數覆寫。
- `scripts/notify/telegram/test.sh` 以 dry-run 驗證：四個範本的輸出、三個開關與缺少鍵的預設、`attention` 在所有開關關閉時仍送出、
  交件單事件不落到等待回應的範本。
- 既有的路由測試（開啟或通知審查者、退回、輪數上限、乾淨檢查）必須維持通過，證明路由沒有改變。
- 測試都在暫時的 HOME 與假的 `xirp`、假通知腳本下執行，不送真實 Telegram。
- 真實驗收另列：在演練用的 repo 跑一輪含退回的迴圈，對照收到的通知順序，結果記入 Work Item。

## Risks / Trade-offs

- [實作完成與 Task Complete 會各發一則] → 使用者已接受；兩者帶相同的 Session 標籤，方便之後決定關哪一個。
- [通知變多] → 三個開關可關；`attention` 才是必須處理的。
- [Xirp 回報的 effort 欄位名稱依工具不同（`effort`、`reasoning_effort`）] → 兩個都讀；讀不到就省略。
- [通知腳本是舊版（尚未部署 `refine-notify-core`）時收到 `handoff` 事件] → 舊版會當成未知事件處理；安裝說明要求兩個 installer 都重新部署，
  `handoff-route` 不因此失敗。
- [`attention` 不可關閉可能被認為太吵] → 這些情況下迴圈已經停住；文件說明原因。

## Migration Plan

1. `refine-notify-core` 合併並部署後才實作本 change。
2. 合併後執行 `scripts/notify/telegram/update.sh` 與 `scripts/handoff/install.sh` 重新部署；hook 的登記指令不變，Codex 不需重新信任。
3. 進行中的迴圈不受影響：通知只取決於之後處理的交件單。
4. 回復：重新部署前一版的兩個腳本；新增的三個設定鍵對舊版無作用。
