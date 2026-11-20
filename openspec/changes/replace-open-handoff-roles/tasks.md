# Tasks

## 1. 選項與拒絕條件

- [ ] 1.1 `handoff-role` 接受 `--replace` 與 `--worktree <mode>`，順序不限；角色只接受 `review`、`finish`（`implement` 給出「只能更換審查與收尾」的錯誤）；`--worktree` 只接受 `new`；已開啟的角色沒有 `--replace` 時，錯誤訊息提示 `--replace`；`--help` 說明新選項。
  - 測試要求：先寫失敗測試：已開啟且沒有 `--replace` 時，訊息含 `--replace` 且 `loop.yaml` 不變；`implement` 被拒；`--worktree shared` 被拒；三者都以非零結束、什麼都不變。

## 2. 更換已開啟的角色

- [ ] 2.1 實作 design D2：在 scratch 副本套用 override 與 `--worktree`，再跑全部檢查；通過後以舊角色的 host 呼叫 `ho_host_close`；成功後寫回 `loop.yaml`，並清空角色的 session 相關欄位（審查者從 shared 改成 new 時，一併清空 `reviewer.worktree`）。
  - 測試要求：先寫失敗測試：新 Pi 模型不存在時，假 `xirp` 沒有收到 delete、`loop.yaml` 不變；成功時假 `xirp` 收到 delete、`loop.yaml` 的審查範本為 Pi 且 `reviewer.session` 為空；close 失敗時 `loop.yaml` 不變並以非零結束；herdr 角色更換時，假 `herdr` 收到關閉 tab 的指令。
- [ ] 2.2 `--worktree new` 寫入 `<role>_template.worktree: new`，並納入 Pi worktree 檢查；可以用在還沒開啟的角色。
  - 測試要求：先寫失敗測試：收尾是 shared Pi 時，審查者加上 `--worktree new` 換成 Pi 會通過，不加則被拒；未開啟的角色只帶 `--worktree new` 時，只改 worktree 模式。

## 3. 改送等待中的交件單

- [ ] 3.1 審查：最新交件單是已列在 `.routed` 的 `implement`/`done`，而且之後沒有 review 交件單時，把它從 `.routed` 移除，在該 worktree 執行前景 route；新審查者依範本開啟（`new` 時建立 `<root>-review`）並收到這一輪的 prompt，`routing.log` 記錄結果；開啟失敗時走既有 retry。
  - 測試要求：先寫失敗測試：更換後假 `xirp` 依序收到 delete、create（Pi 範本），`reviewer.session` 是新 ID，`routing.log` 有 `reviewer:opened`；開啟失敗時交件單不在 `.routed`，而且只發一次通知；實作者還在工作時（最新是 review 交件單），更換後不開任何 session。
- [ ] 3.2 收尾：最新交件單是 `finish`/`blocked`，或者審查 pass 而且舊收尾 session 已開啟時，用 `handoff-finish` 的開啟流程開新的收尾 session。
  - 測試要求：先寫失敗測試：blocked 收尾更換後，開出新收尾並收到收尾 prompt；pass 但收尾還沒開啟時，只換設定、不開啟（仍由 `handoff-finish` 開）。

## 4. 文件

- [ ] 4.1 `scripts/handoff/README.md` 的 handoff-role 段落與 `docs/skills/agent-handoff.md` 說明 `--replace`、`--worktree new`、自動改送、更換前先確認舊角色已停止，以及實作者不能更換；在 Troubleshooting 加上「額度用完時更換審查者」的範例。
  - 測試要求：文件類；hookinstall 測試確認 README 提到 `--replace` 與 `--worktree new`；照 README 的範例指令，在測試 fixture 上執行一次。

## 5. 整合驗收

- [ ] 5.1 完整執行 `bash tests/test_agent_handoff.sh` 與 pre-commit 檢查，全部通過。
  - 測試要求：指令輸出全部通過。
