# Proposal

## Why

交接迴圈啟動後，沒有正式方式更換尚未開啟的審查或收尾角色；Pi 交接實測只能手動編輯 `loop.yaml`，並手動以 bash 載入函式庫補跑
啟動檢查。另外，`handoff-start --review`／`--impl` 的 override 換了工具卻保留原工具的 skill 呼叫寫法與 session 名稱，
例如把 Codex 審查改成 Pi 時，Pi 收到的 prompt 仍以 `$change-review` 開頭。

## What Changes

- 新增 `handoff-role <change-id> <review|finish> <override>`：在角色的 session 尚未開啟時，更新該迴圈 `loop.yaml` 的角色範本。
  override 格式與 `handoff-start` 相同（`claude|codex:<model>:<effort>` 或 `pi:<provider>/<model>:<effort>:<billing>`）。
  寫入前執行與 `handoff-start` 相同的檢查：範本欄位、一個 worktree 最多一個 Pi 角色、Pi 角色的模型、憑證、計費與信任。
  任何檢查失敗或角色 session 已開啟時拒絕，`loop.yaml` 不變；永不修改 `roles.yaml`。
- override 換了工具時（`handoff-start` 與 `handoff-role` 都是），prompt 開頭的 skill 呼叫改成新工具的寫法（Claude Code `/x`、
  Codex `$x`、Pi `/skill:x`），以舊工具名稱開頭的 session 名稱改用新工具名稱。
- `scripts/handoff/install.sh` 安裝 `handoff-role` 到 `~/.local/bin`。
- 不支援更換實作者角色（實作者在 `handoff-start` 時就已開啟）。

驗收條件：

- 第一次交件前執行 `handoff-role <change> review pi:openai/gpt-6.2-sol:high:api`，`loop.yaml` 的 `review_template` 變成 Pi、
  prompt 以 `/skill:change-review` 開頭、名稱以 `pi - ` 開頭；之後 hook 依此開啟審查者。
- 審查者已開啟時執行，回報已開啟的 session 並不改 `loop.yaml`。
- Pi 檢查失敗（例如模型不在該 provider 下）時，回報原因並不改 `loop.yaml`。
- `handoff-start --review pi:...` 啟動的迴圈，`loop.yaml` 的審查 prompt 與名稱同樣改成 Pi 的寫法。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `agent-crew-launcher`: 新增迴圈中更換未開啟角色的指令；override 換工具時一併改寫 skill 呼叫與 session 名稱。

## Impact

- 程式：新增 `scripts/handoff/handoff-role`；`scripts/handoff/lib/handoff.sh` 新增共用的 override 套用函式；
  `scripts/handoff/handoff-start` 改用該函式；`scripts/handoff/install.sh` 安裝新指令。
- 測試：`tests/test_agent_handoff.sh`。
- 文件：`scripts/handoff/README.md`（Commands）、`docs/skills/agent-handoff.md`。
- 使用者環境：合併後重跑 `bash scripts/handoff/install.sh`。
- 支援的 AI CLI：Claude Code、Codex、Pi 角色（與交接迴圈現況相同）。
