# Design

## Context

動機見 proposal.md 的 Why。現況：
- `scripts/handoff/handoff-role` 只在 `<role>.session` 為空時更換角色。它先在 scratch 副本上套用 override（`ho_apply_override`），
  再跑 `ho_preflight_or_refuse` 與「一個 worktree 一個 Pi 角色」的檢查，全部通過才寫回 `loop.yaml`。
- `handoff-route` 的 `to_reviewer` 在 `reviewer.session` 為空時，依 `review_template` 開新的審查者（`worktree: new` 時建立 `<root>-review`）；
  不為空時，透過 host 傳訊。處理過的交件單記在 `.routed`；只有 `retry` 的結果不會記進去。
- `handoff-finish` 在收尾 `blocked` 時呼叫 `ho_finish_retry`：原 session 還在就傳訊，否則開新的。審查 pass 時呼叫 `ho_finish_open`，會沿用已開啟的收尾 session。
- 各 host 都有 `ho_host_close`：xirp 刪除 session，herdr 關閉角色的 tab 或 workspace。

## Goals / Non-Goals

**Goals:**
- 已開啟的審查或收尾角色可以用一個指令更換，而且和現在一樣，在動任何東西之前先通過全部檢查。
- 等待中的交件單自動送給新角色，不需要手動編輯 `.routed`。

**Non-Goals:**
- 不支援更換實作者。實作者 worktree 可能有未 commit 的工作，交接方式另外設計。
- 不支援把角色從自己的 worktree 改回共用 worktree，因為舊 worktree 裡的交件單與報告要另外處理。
- 不做「額度用完時自動更換」。何時更換由人決定。

## Decisions

### D1：`--replace` 是明確的開關
已開啟的角色沒有 `--replace` 時照舊拒絕，訊息提示可以加 `--replace`。更換會刪除舊 session，屬於破壞性動作，必須明確要求。
- 不採用「已開啟就自動取代」：誤打指令時，會把正在工作的審查者刪掉。

### D2：順序是先檢查、再刪舊、再寫新、最後改送
1. 在 scratch 副本套用 override 與 `--worktree`，跑 `ho_preflight_or_refuse` 與 Pi worktree 檢查。失敗就結束，什麼都不動。
2. 透過舊角色的 host 呼叫 `ho_host_close`。刪除失敗就結束，`loop.yaml` 不變，讓使用者知道舊 session 還在。
3. 把 scratch 寫回 `loop.yaml`，清空 `<role>.session`、`native_session`、`herdr_tab`、`pending_prompt`。
   審查者從 `shared` 改成 `new` 時，同時清空 `reviewer.worktree`，讓 route 建立 `<root>-review`。
4. 依 D3 改送等待中的交件單。
- 先刪舊 session 再寫新設定，是為了避免舊審查者在換完之後才寫出交件單，產生兩個審查結果。

### D3：改送等待中的交件單，重用現有的派送路徑
- 審查：最新交件單是 `implement`/`done`，已列在 `.routed`，而且之後沒有 review 交件單。
  這時把它從 `.routed` 移除，在該交件單所在的 worktree 呼叫 route 的前景模式（`handoff-route --foreground`）。
  `reviewer.session` 已清空，所以 `to_reviewer` 會依新範本開啟審查者並送出這一輪；結果照常寫進 `routing.log`。
- 收尾：最新交件單是 `finish`/`blocked`，或者審查 pass 而且舊收尾 session 已經開啟（沒有收尾交件單）。
  這時呼叫和 `handoff-finish` 相同的開啟流程。`finish.session` 已清空，所以 `ho_finish_retry`／`ho_finish_open` 會開新的。
- 開啟失敗時沿用既有的 retry：交件單維持未處理，發一次 attention 通知，之後用 `handoff-route --foreground` 或 `handoff-finish` 重試。
- 不採用「在 `handoff-role` 裡另寫一套開啟與傳訊」：會和 route、finish 的行為分岔。

### D4：`--worktree` 只接受 `new`
`--worktree new` 寫入 `<role>_template.worktree: new`，並納入 Pi worktree 檢查的計算。其他值一律拒絕。
可以和 override 一起用，也可以單獨用在還沒開啟的角色上。

## Risks / Trade-offs

- [刪掉舊 session 後，新角色開啟失敗，這一輪暫時沒有審查者] → 交件單維持未處理，並發出 attention 通知；修好之後重試即可，不需要再換一次。
- [舊審查者正在寫交件單時被刪除] → 文件提醒：更換前先確認舊角色已停止。若刪除後才出現舊審查者的交件單，依既有規則，它是最新交件單時照常處理。
- [審查者從 shared 改成 new 之後，新審查者看不到舊審查報告的上下文] → 報告路徑仍在交件單裡，新審查者由 prompt 取得受審 commit 與報告路徑。

## Migration Plan

- 只新增選項，不改變現有行為；沒有 `--replace` 時，所有現有測試的結果不變。
- 回復：退回本 change 的 commit。

## TDD 策略與測試邊界

- 測試檔：`tests/test_agent_handoff.sh`。沿用假的 `xirp`／`herdr`，以及現有 handoff-role 案例的 fixture。
- 每個需求先寫失敗的測試：沒有 `--replace` 時拒絕並提示；`--replace` 時新設定檢查失敗則什麼都不變；成功時刪除舊 session，並把等待中的 implement 交件單改送給新審查者（假 `xirp` 收到 create 與傳訊）；收尾 blocked 時改送；沒有等待中的交件單時不開啟任何 session；更換實作者被拒；`--worktree shared` 被拒；Pi 審查者加上 `--worktree new` 通過 Pi 檢查。
- 不在自動測試範圍：真實額度用完時的實際操作，在下一次真實迴圈中觀察，記在 Work Item。
