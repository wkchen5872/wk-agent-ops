# Proposal

## Why

交接迴圈的通知現在只在需要使用者處理時發出，而且借用一般的「Action Required」訊息：

- 使用者只看得到「第 N 輪審查通過」與「收尾結束」，看不到實作者交件與審查退回，整個迴圈的進度是斷的。
- 每一則的標題都是「Action Required」，看不出是進度還是真的要處理；也看不出是哪個工具、哪個模型做的。
- 不能選擇要收哪些事件；commit 以 40 碼顯示。

使用者已確認（Work Item `WI-20261118-notify-optimization` 的 D-003）另開本 change 處理交件單通知；希望看到完整的事件順序、
Agent 的工具／模型／effort，並能分別開關實作完成、每輪審查、收尾三類通知。與一般的 Task Complete 重複可以接受，之後再決定關哪一個。

## What Changes

- **專屬的交件單通知事件**，各有標題與範本：實作完成、審查結果（退回或通過）、收尾完成、需要你處理。
- **補齊進度通知**：實作者交件與審查退回也通知使用者（目前只在 Agent 之間傳遞）。
- **三個開關**：`NOTIFY_HANDOFF_IMPLEMENT`、`NOTIFY_HANDOFF_REVIEW`、`NOTIFY_HANDOFF_FINISH`，預設開啟，可在通知設定選單調整。
- **「需要你處理」不可關閉**：blocked、達輪數上限、worktree 不乾淨或版本不符、無法開啟或移動審查 worktree、無法判讀交件單、
  收尾停下，以及審查通過後等使用者執行 `handoff-finish`。迴圈停下等使用者時，這是唯一的訊號。
- **顯示 Agent 資訊**：`Agent Handoff (Claude / claude-opus-5-5 / high)`，取自寫下該交件單的 Session 當下在 Xirp 的工具、模型與 effort；取不到的部分省略。
- **訊息內容**：commit 顯示 7 碼；每則附一句接下來會發生什麼；標題帶與該 Session 一般通知相同的 Session 標籤，方便對照。
- 交件單通知不再以環境變數覆寫一般通知的開關，改走自己的事件與開關。
- **傳訊失敗不再被當成已交件**：對審查者或實作者的 Xirp 訊息送不出去時，不發進度通知、不把交件單標成已處理，改發一則「需要你處理」，
  之後的 hook 執行或手動執行會重試。
- **混版部署仍看得到「需要你處理」**：通知端還不支援交件單事件時（尚未更新或已回退），交接端改走原本的一般通知路徑送出需要你處理的通知，
  兩個 installer 的部署與回退順序不受限制。是否支援以實際執行的通知腳本的能力宣告判斷，回退後殘留的資料檔不會造成誤判。
  從未安裝通知腳本的機器維持現行行為：不送通知，路由照常。
- **每張交件單最多一則進度通知與一則「需要你處理」**：需要你處理的停點通知後即視為已處理，不會在 Agent 每次停下時重發；只有傳訊或開啟失敗會保留重試。例外：重試時又因不同原因停下等你（例如審查 worktree 不乾淨），會再發一則說明新原因。
- 一般的 Task Complete 通知維持不變，不因交件單通知而略過。

支援的 AI CLI：Claude Code、Codex（兩者的 Stop hook 都已登記交接路由）。Antigravity 目前不在交接迴圈內。

驗收條件：

- 一輪「實作 → 審查退回 → 修正 → 審查通過 → 收尾」依序產生對應的通知，每則都有 Agent 資訊與下一步。
- 關閉某一類開關後該類不再通知，其他類與「需要你處理」不受影響。
- 審查通過且收尾設定為 `ask` 時，即使審查開關關閉，使用者仍收到執行 `handoff-finish` 的通知。
- 沒有 Xirp 或 Telegram 未啟用時，路由行為與現在相同，hook 仍然安靜結束。
- 對審查者或實作者傳訊失敗時，使用者收到一則說明迴圈已停住的通知，沒有「已交給對方」的進度通知；重試成功後才出現進度通知。
- 只更新交接端、通知端仍是舊版時，審查通過（等你執行 `handoff-finish`）與 blocked 的通知仍然送達。
- 沒有安裝通知腳本時不送任何通知，路由結果與有通知時相同，hook 正常結束。

依賴：本 change 使用 `refine-notify-core` 的訊息範本與事件對照表，須在該 change 合併後實作。

## Capabilities

### New Capabilities

- `agent-handoff-notifications`: 交接迴圈通知使用者的事件種類、開關、不可關閉的項目、Agent 資訊與訊息內容。

### Modified Capabilities

- `telegram-notify-hook`: 通知 hook 接受交件單事件並套用其開關；設定選單列出三個交件單開關。
- `agent-handoff-routing`: 傳訊或開啟失敗的交件單不標成已處理、不記為已交付，之後可重試；需要使用者處理的停點通知一次後標成已處理。

## Impact

- 程式：`scripts/handoff/handoff-route`、`scripts/handoff/lib/handoff.sh`（組通知資料、查 Agent 資訊，移除環境變數覆寫）、
  `scripts/notify/telegram/hook.sh` 與事件對照表（新增交件單事件）、`scripts/notify/lib/{config,settings}.sh`（三個開關）、
  新增四個內建範本；`tests/test_agent_handoff.sh`、`scripts/notify/telegram/test.sh`。
- 設定：`~/.config/ai-notify/config` 新增三個鍵；缺少時視為開啟。
- 部署：需重新執行 `scripts/handoff/install.sh` 與 `scripts/notify/telegram/update.sh`；hook 的登記指令不變，Codex 不需重新信任。
- 文件：`scripts/handoff/README.md`、`docs/notify/telegram.md`、`docs/workflow/local-development.md`。
- 規格 `agent-handoff-routing` 的路由對象與條件不變；新增「傳訊失敗時不標成已處理、可重試」。
