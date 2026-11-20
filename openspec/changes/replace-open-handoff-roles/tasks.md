# Tasks

## 1. 選項與拒絕條件

- [x] 1.1 `handoff-role` 接受 `--replace` 與 `--worktree <mode>`，順序不限；角色只接受 `review`、`finish`（`implement` 給出「只能更換審查與收尾」的錯誤）；`--worktree` 只接受 `new`；已開啟的角色沒有 `--replace` 時，錯誤訊息提示 `--replace`；`--help` 說明新選項。
  - 測試要求：先寫失敗測試：已開啟且沒有 `--replace` 時，訊息含 `--replace` 且 `loop.yaml` 不變；`implement` 被拒；`--worktree shared` 被拒；三者都以非零結束、什麼都不變。

## 2. 更換已開啟的角色

- [x] 2.1 實作 design D2：在 scratch 副本套用 override 與 `--worktree`，再跑全部檢查；通過後以舊角色的 host 呼叫 `ho_host_close`；成功後寫回 `loop.yaml`，並清空角色的 session 相關欄位（審查者從 shared 改成 new 時，一併清空 `reviewer.worktree`）。
  - 測試要求：先寫失敗測試：新 Pi 模型不存在時，假 `xirp` 沒有收到 delete、`loop.yaml` 不變；成功時假 `xirp` 收到 delete、`loop.yaml` 的審查範本為 Pi 且 `reviewer.session` 為空；close 失敗時 `loop.yaml` 不變並以非零結束；herdr 角色更換時，假 `herdr` 收到關閉 tab 的指令。
  - 審查修正（codex-role-review-r01、r02 的 F-01、F-02、F-04、F-05、F-06、F-07）：舊 session 須經 host 確認刪除，或以可判讀的清單確認已不存在；herdr 只關閉迴圈開的、仍屬舊角色的 tab；每份 `loop.yaml` 整份替換，實作者那份最後寫，失敗時重跑同一指令即可完成；舊 pane 的未確認提示在關閉後移除；Pi 設定（含新 worktree 將 checkout 的 commit 所追蹤的檔案）在刪除前檢查；既有交件單依寫入當時的範本驗證（`<role>_template_until_<NN>`）。各項都有回歸測試。
  - 審查修正（r03 的 F-01、F-06）：Xirp 清單必須整份恰好是一份可解析的 session 清單；Pi 預檢採用 route 或 `handoff-finish` 實際使用的 worktree 與 commit（直接沿用的 worktree 看 index，含 skip-worktree；之後才 checkout 的看該 commit；沒有待審交件單時不拿舊 review 的 commit 檢查）。各項都有回歸測試。
- [x] 2.2 `--worktree new` 寫入 `<role>_template.worktree: new`，並納入 Pi worktree 檢查；可以用在還沒開啟的角色。
  - 測試要求：先寫失敗測試：收尾是 shared Pi 時，審查者加上 `--worktree new` 換成 Pi 會通過，不加則被拒；未開啟的角色只帶 `--worktree new` 時，只改 worktree 模式。
  - 審查修正（r01、r02 的 F-08）：在實作者 worktree 的 blocked 收尾加上 `--worktree new` 時，會帶著 feature branch 移到 `<worktree>-finish`；branch 不在暫停的 commit 時拒絕；中斷的移動由下一次 `handoff-finish` 補完。各項都有回歸測試。
  - 審查修正（r03 的 F-08）：搬移前，原 worktree 必須仍包含 blocked 交件單的 commit；建立新 worktree 後核對實際 HEAD，不符就不開啟；搬移完成後的一般重試只補寫紀錄，沿用原有要求。各項都有回歸測試。
  - 審查修正（pi-role-review-r04 的 F-08）：主檔已指向 `-finish`、但目的地副本未完成時視為搬移未完成，補完前核對目的地包含 blocked 交件單的 commit，不符就停止並指出該 commit。有回歸測試。

## 3. 改送等待中的交件單

- [x] 3.1 審查：最新交件單是已列在 `.routed` 的 `implement`/`done`，而且之後沒有 review 交件單時，把它從 `.routed` 移除，在該 worktree 執行前景 route；新審查者依範本開啟（`new` 時建立 `<root>-review`）並收到這一輪的 prompt，`routing.log` 記錄結果；開啟失敗時走既有 retry。
  - 測試要求：先寫失敗測試：更換後假 `xirp` 依序收到 delete、create（Pi 範本），`reviewer.session` 是新 ID，`routing.log` 有 `reviewer:opened`；開啟失敗時交件單不在 `.routed`，而且只發一次通知；實作者還在工作時（最新是 review 交件單），更換後不開任何 session。
  - 審查修正（r01、r02 的 F-03）：只改送舊審查者確實收到的紀錄，並在紀錄所在 worktree 派送；送達與否只看本次結果；沒送出時保持未處理，host 未確認時不重送；處理標記無法清除時，指令會說明手動步驟。各項都有回歸測試。
  - 審查修正（r03 的 F-03）：是否可能已送達改由迴圈狀態判斷（已記錄的新 session，而且第一個 prompt 不在 pending），不依賴 `routing.log`；可能已送達的紀錄一律保持已處理，不會重送。有回歸測試。
  - 審查修正（pi-role-review-r04 的 F-03）：新審查者已開啟、但 session ID 無法寫入 `loop.yaml` 時，route 以 `reviewer:opened-unrecorded:<id>` 停住而不是重試；`handoff-role` 綜合 session 紀錄、本次 log 與 `.routed` 判斷，任何可能已送達的跡象都保持已處理，並指出要找回的 session。有回歸測試。
  - 審查修正（pi-role-review-r05 的 F-01）：`reviewer:opened-unrecorded:<舊 session>` 也算該舊審查者已收到這一輪；補記 session ID 後明確以 `--replace` 再換一次時，同一輪只改送給新審查者一次，普通前景重試仍不會再開。有回歸測試。
- [x] 3.2 收尾：最新交件單是 `finish`/`blocked`，或者審查 pass 而且舊收尾 session 已開啟時，用 `handoff-finish` 的開啟流程開新的收尾 session。
  - 測試要求：先寫失敗測試：blocked 收尾更換後，開出新收尾並收到收尾 prompt；pass 但收尾還沒開啟時，只換設定、不開啟（仍由 `handoff-finish` 開）。
  - 審查修正（r01）：收尾在更換後無法開啟時，發一次 attention 通知。

## 4. 文件

- [x] 4.1 `scripts/handoff/README.md` 的 handoff-role 段落與 `docs/skills/agent-handoff.md` 說明 `--replace`、`--worktree new`、自動改送、更換前先確認舊角色已停止，以及實作者不能更換；在 Troubleshooting 加上「額度用完時更換審查者」的範例。
  - 測試要求：文件類；hookinstall 測試確認 README 提到 `--replace` 與 `--worktree new`；照 README 的範例指令，在測試 fixture 上執行一次。

## 5. 整合驗收

- [x] 5.1 完整執行 `bash tests/test_agent_handoff.sh` 與 pre-commit 檢查，全部通過。
  - 測試要求：指令輸出全部通過。
  - 結果：`bash tests/test_agent_handoff.sh` 全部通過，其餘 `tests/test_*.sh` 也全部通過。本 repo 沒有啟用 pre-commit hook（`git hook run pre-commit` 回報 `cannot find a hook named pre-commit`；只有 node／python profile 附帶），因此這一關不適用，改以完整測試代替。
