# Proposal

## Why

`handoff-role` 只能更換還沒開啟的審查或收尾角色。角色一旦開啟，迴圈中途就沒有正式的更換方式。
`add-herdr-handoff-host` 的迴圈中，Codex 週額度用到 98%，預備把審查者換成 Pi 時，唯一可行的做法是：
- 手動清空 `loop.yaml` 的 `reviewer.session`；
- 手動把審查者改成 `worktree: new`，因為收尾也是 Pi，而一個 worktree 只能有一個 Pi 角色；
- 手動把交件單從 `.routed` 移除，再執行 `handoff-route --foreground`。

這些步驟會跳過檢查，也容易遺漏。上一個 Work Item 的 C2 也碰到同一個限制。

## What Changes

- `handoff-role` 新增 `--replace`：審查或收尾角色已經開啟時，以新的設定取代它。
  沒有 `--replace` 時，已開啟的角色照舊拒絕，並提示可以用 `--replace`。
  - 取代前，先對新設定跑和現在相同的檢查（`handoff-doctor` 的角色檢查、一個 worktree 一個 Pi 角色）。
    任何一項失敗，舊 session、`loop.yaml` 和交件單都不變。
  - 通過後，透過舊角色的 host 刪除或關閉舊 session，清空該角色的 session 紀錄，再寫入新設定。
  - 有一張交件單正等著這個角色時，自動改送給新角色：
    - 審查：最新交件單是已送給舊審查者、但還沒有審查結果的 implement 交件單，就依新範本開出審查者並送出這一輪。
    - 收尾：最新交件單是收尾 `blocked`，或者審查已 pass 而且舊收尾 session 已經開啟，就依新範本開出收尾。
  - 沒有交件單在等待時，只換設定；下次輪到這個角色時，hook 依新範本開啟。
- `handoff-role` 新增 `--worktree new`，可以把審查或收尾從共用實作者的 worktree 改成自己的 worktree，用來配合「一個 worktree 一個 Pi 角色」。
  不支援從 `new` 改回 `shared`，因為舊 worktree 裡的交件單與報告要另外處理。
- 實作者仍不能更換，`roles.yaml` 仍不會被修改。
- 文件：`scripts/handoff/README.md` 與 `docs/skills/agent-handoff.md` 說明 `--replace`、`--worktree` 與自動改送。

驗收條件：
- 審查者已開啟、最新交件單是已送出但未審查的 implement 交件單時，執行
  `handoff-role <change> review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace`：
  舊審查 session 被刪除，Pi 審查者開在 `<worktree>-review`，並收到這一輪的審查 prompt；`routing.log` 記錄這次改送。
- 同樣的指令不加 `--replace`：以非零結束，提示 `--replace`，什麼都不變。
- 新設定檢查失敗（例如 Pi 模型不存在）：舊 session 照常存在，`loop.yaml` 不變。
- 收尾是 `blocked` 時更換收尾：舊收尾 session 被刪除，新收尾開啟並收到收尾 prompt。
- `--worktree shared` 或對實作者使用：以非零結束並說明不支援。

## Capabilities

### New Capabilities

### Modified Capabilities
- `agent-crew-launcher`: `handoff-role` 可以用 `--replace` 更換已開啟的審查或收尾角色，並自動把等待中的交件單改送新角色；可以用 `--worktree new` 讓角色改用自己的 worktree。

## Impact

- 程式：`scripts/handoff/handoff-role`；`scripts/handoff/lib/handoff.sh`（重用 `ho_host_close`、`ho_open_role`、finish 開啟函式與 route 的審查派送）；
  可能把 `handoff-route` 裡送給審查者的邏輯抽成函式，讓 `handoff-role` 共用。
- 測試：`tests/test_agent_handoff.sh` 的 handoff-role 案例。
- 文件：`scripts/handoff/README.md`、`docs/skills/agent-handoff.md`。
- 支援的 AI CLI：Claude Code、Codex、Pi；host：xirp、herdr。hook 與觸發器不變。
