# Tasks

## 1. 前置查證

- [x] 1.1 以一次性 Session 驗證 Xirp API `session:create` 帶 linked worktree 的 `worktreePath` 能在該目錄開啟 Session，結果記入 Work Item。測試要求：非行為變更的查證；記錄指令、Session 的 `worktreePath` 與 cwd，測完刪除該 Session。
- [x] 1.2 驗證 Codex 的 Stop hook 能在所在 worktree 以外建立 worktree 與寫入檔案（審查與收尾 `new` 的前提），由使用者在 Codex 信任測試 hook；結果記入 Work Item。測試要求：非行為變更的查證；記錄 hook 執行結果與寫入位置，測完移除測試 hook 與測試 worktree。若被擋，依 design 的風險處理更新 spec 與任務後再實作。

## 2. 解析器與交件單（agent-handoff-records）

- [x] 2.1 實作 `template/common/skills/agent-handoff/scripts/kv.sh`（`handoff-write` 與 `scripts/handoff/` 共用的唯一來源）：讀單層與兩層 `key: value`。測試要求：先在 `tests/test_agent_handoff.sh` 寫失敗測試（單層、兩層、含冒號的值、註解、缺鍵），取得 Red 後實作至 Green。
- [x] 2.2 新增 `template/common/skills/agent-handoff/`（`SKILL.md` 與 `scripts/handoff-write`）：依 `loop.yaml` 跨所有 worktree 計算編號、驗證欄位、暫存檔後 rename 寫入、拒絕 worktree 外的路徑。測試要求：先寫失敗測試涵蓋編號遞增、A 與 B 交錯時序號連續、不覆寫、未知 role／status／verdict、不存在的 head、缺少 report、路徑越界不留檔。
- [x] 2.3 `SKILL.md` 說明三種角色何時寫、各欄位意義與範例。測試要求：文件檢查——`tests/test_agent_handoff.sh` 確認 Skill frontmatter 合法且列出所有欄位。

## 3. 安裝：專案層（install-profile-cli、codex-subagent-templates）

- [x] 3.1 `scripts/skills/install.sh` 合併 `/.agent-handoff/` 忽略規則並雙向驗證、只在缺少時放入 `roles.yaml` 範例；範例含 D-007、D-011、D-012 的預設值。測試要求：先寫失敗測試（規則只出現一次、`git check-ignore` 生效、既有 `roles.yaml` 不被改動、重跑冪等）。
- [x] 3.2 新增 `template/common/.claude/agents/github-pr-agent.md`、`github-issue-agent.md`（`model: sonnet`）與 `template/common/.codex/agents/github-pr-agent.toml`、`github-issue-agent.toml`（`gpt-5.6-terra`、`medium`），要求呼叫端傳入身分並沿用之。測試要求：先擴充 `tests/test_agents_dir.sh` 檢查四個檔案的模型設定與安裝後內容一致，取得 Red 後新增檔案。
- [x] 3.3 執行 `bash scripts/skills/install.sh` 同步安裝副本。測試要求：`diff` 確認 template 與 `.claude/`、`.agents/`、`.codex/agents/` 一致；跑 3.1、3.2 的測試。

## 4. Stop hook（agent-handoff-routing）

- [x] 4.1 建立測試替身：假的 `xirp`（記錄參數、`session:create` 回傳固定 ID、`session get` 回傳固定模型）、會讓測試失敗的假 `gh`、記錄通知的假通知腳本。測試要求：替身本身以一個 smoke test 驗證可被 hook 呼叫。
- [x] 4.2 實作 `handoff-route` 的偵測與去重：無交件單或無 `loop.yaml` 不動作、同一交件單只處理一次、沒有 `xirp` 時安靜結束。測試要求：先寫失敗測試涵蓋這四種情況。
- [x] 4.3 實作乾淨交接檢查（HEAD 等於 head、工作區乾淨）與不符合時通知使用者。測試要求：先寫失敗測試涵蓋未 commit、HEAD 不符、審查者留下變更三種情況。
- [x] 4.4 實作路由表（報告以絕對路徑傳給實作者）：implement→審查者、changes-required→實作者、任何 blocked（含保留技術 verdict 的 `status: blocked`）→只通知使用者、finish→只通知使用者、輪數上限、訊息只含引用不含報告內容。測試要求：先寫失敗測試逐列驗證假 `xirp` 收到的對象與訊息內容；`status: blocked`+`verdict: changes-required` 時實作者收不到訊息；finish 交件單不開任何 Session；假 `gh` 從未被呼叫。
- [x] 4.5 實作第一輪開審查者（`shared` 在實作者 worktree；`new` 先建立 detached 審查 worktree 並寫 `loop.yaml` 副本）、`finish.trigger` 的 `ask`／`auto`（`auto` 走與 `handoff-finish` 相同的檢查），以及 `routing.log`（含 `xirp session get` 的模型）。測試要求：先寫失敗測試涵蓋兩種模式下審查者只開一次且 cwd 正確、`new` 時兩份 `loop.yaml` 都列出審查 worktree、沿用既有審查者、`ask` 只通知、`auto` 開收尾 Session、`auto` 遇過期 pass 不開、log 記錄模型。
- [x] 4.6 實作審查 `new` 的每輪移動：確認審查 worktree 乾淨後 detach 到新 head 再通知審查者；不乾淨則通知使用者、不移動。測試要求：先寫失敗的 A→B→A→B 兩輪測試——B 的報告存在 B、實作者收到絕對路徑且讀得到、第二輪 B 位於 Y、序號 01–04 跨 A／B 連續、B 的最終 pass 讓 A 的 `handoff-finish` 可開；另測 B 有未提交變更時不移動、不通知審查者。

## 5. 核心與啟動指令（agent-crew-launcher）

- [x] 5.1 實作 `scripts/handoff/lib/handoff.sh`（核心與共用函式）：依範本以 Xirp API 開 Session（`customName`、模型、effort、prompt 佔位符）、範本缺模型或 effort 時拒絕。測試要求：先寫失敗測試驗證送給假 `xirp` 的 JSON 與名稱格式 `<tool> - <label> - <change>`。
- [x] 5.2 實作 `handoff-start`：從主 worktree 讀 `roles.yaml`、驗證 Change 與分支、預設另開 worktree、`--worktree here`、分支被佔用時停止、範本 `worktree` 不是 `shared` 或 `new` 時拒絕、只開實作者、寫 `loop.yaml`、單次覆寫參數。測試要求：先寫失敗測試涵蓋 spec 的每個 scenario（含未知 worktree 值拒絕且不開任何 Session），在暫時 repo 中驗證 worktree 與 `loop.yaml`；未知 worktree 值拒絕。
- [x] 5.3 實作 `handoff-finish` 與共用的收尾檢查（跨 `loop.yaml` 列出的所有 worktree 找最新一筆）：最新一筆交件單須為 `review`／`done`／`pass`、其 head 等於目前 HEAD、工作區乾淨、尚無 finish 交件單。測試要求：先寫失敗測試涵蓋七種情況——乾淨 X 的 pass 會開；changes-required、`status: blocked` 的 pass、X pass 後 commit Y、X pass 後出現新 implement 交件單、X pass 後有未提交變更、已有 finish 交件單，皆拒絕且不開 Session；另測 pass 位於審查 worktree B 時可由 A 開收尾。
- [x] 5.4 實作收尾 `new`：確認實作者 worktree 乾淨在受審 head，detach 在同一 commit，新 worktree checkout feature branch，記入 `loop.yaml` 後開收尾 Session。測試要求：先寫失敗測試涵蓋成功接手（A detach 於 X、收尾 worktree 在分支上的 X）與 A 不乾淨時不 detach、不建立。
- [x] 5.5 實作 `scripts/handoff/install.sh`：安裝指令與 hook、重用 `scripts/workflow/lib.sh` 登記到 Claude Code 與 Codex、冪等、提示 Codex 信任。測試要求：先寫失敗測試，以暫時 HOME 驗證兩個設定檔各只有一筆登記、重跑不重複、不修改 Codex 信任狀態。
- [x] 5.7 實作 `handoff-cleanup`：收尾完成且乾淨時，先把交件單與審查報告搬到主 worktree 的 `.agent-handoff/archive/<change-id>/`，再刪 Session 與主 worktree 以外的 worktree，保留分支；沒有 `--yes` 只列計畫；`install.sh` 一併安裝，README 補說明。測試要求：先寫失敗測試涵蓋 spec 的五個 scenario（以假 `xirp` 驗證刪除呼叫），並在 8.5 以演練 repo 實測。
- [x] 5.8 範本支援 Codex `profile`（Claude 範本設定時拒絕），開 Session 時傳給 Xirp；`scripts/handoff/install.sh` 在缺少時建立 `~/.codex/handoff-net.config.toml`，不覆寫既有檔；範例範本說明 PR 交付時給 Codex 收尾設 `profile: handoff-net`。測試要求：先寫失敗測試涵蓋傳入與不傳 profile、Claude 範本拒絕、複製到 `loop.yaml`、installer 建立與不覆寫。
- [x] 5.9 `agent-handoff` 新增 `handoff-author`，`{author}` 改為要求原樣附加其輸出；`github-pr-agent`、`github-issue-agent` 接受 `author_file` 並原樣附加。測試要求：先寫失敗測試涵蓋 Codex／Claude 的 ID 來源、缺 ID 寫 `null`、空模型省略 `AI-Assisted-By`、prompt 指令與四個 Agent 的 `author_file`。
- [x] 5.10 `handoff-finish` 重試 blocked 收尾：乾淨且 HEAD 包含最新 pass head 時，傳訊給原收尾 Session 或重開；`done` 仍拒絕；hook 的 blocked 收尾通知附重試指令。測試要求：先寫失敗測試涵蓋傳訊重試、Session 不在時重開、未提交變更與 HEAD 不包含 pass 時拒絕、已 done 拒絕、通知內容。
- [x] 5.11 迴圈的 `finish.delivery: pr` 本身即授權最終版 Review 與 ready-to-merge Closure：`openspec-commit` 迴圈規則、範例收尾 prompt 與重試訊息都寫明。測試要求：先寫失敗測試涵蓋三處文字，並新增驗收案例 OC-38。
- [x] 5.12 `handoff-cleanup --abandon`：不要求 finish done，其餘檢查與步驟不變。測試要求：先寫失敗測試涵蓋只列計畫、未提交變更仍拒絕、封存並刪除且保留分支。
- [x] 5.6 撰寫 `scripts/handoff/README.md`（安裝、`roles.yaml` 欄位、指令、疑難排解）。測試要求：文件檢查——README 列出的指令與選項和 `--help` 輸出一致。

## 6. Skill 修改（change-review、openspec-commit、github-pr、github-issue）

- [x] 6.1 `change-review`：區分實作輪 Review（以交件單 head 固定版本、乾淨檢查、結束寫交件單）與最終版 Review（綁定呼叫端傳入的交付 head、不寫交件單）；迴圈啟用時不自行通知實作者；發布被拒、逾時或回讀不符時寫 `status: blocked` 並保留 verdict、不盲目重發、不轉 local handoff；local-only 維持不通知、與交接衝突時先釐清、只有明確允許本地交接才路由，以及禁通知的處理；PR 回覆可委派 `github-pr-agent`。測試要求：先在 `tests/test_change_review.sh` 加入失敗的內容檢查，並在 `tests/acceptance/` 新增可重播案例：迴圈中 changes-required 已確認發布、三種發布失敗各一（皆寫 blocked、實作者不被通知）、已有迴圈後追加 local-only（實作者零則訊息）、local-only 加交接但未釐清（零則訊息）、明確「不發 GitHub 但交給實作者」（照常路由）、禁通知、最終版 Review 審 Y 不被 X 擋下且不寫交件單、未啟用迴圈時維持舊行為。
- [x] 6.2 `openspec-commit`：迴圈中依 `finish.delivery` 決定交付；PR 交付時最終版 Review 以交付後的 head 呼叫 `change-review`，不是 pass 就不發 Closure；結束時寫 finish 交件單；PR update 與 Closure 可委派。測試要求：先在 `tests/test_openspec_commit.sh` 加入失敗的內容檢查，並新增 `finish.delivery: pr` 的可重播案例：X pass → 封存與文件 commit Y → 審 Y pass → Closure → finish done；審 Y 為 changes-required 或 blocked → 不發 Closure、finish blocked、不以 X 的 pass 代替。
- [x] 6.3 `github-pr`、`github-issue`：說明專用 Agent 的委派方式與呼叫端身分規則。測試要求：先在 `tests/test_github_handoff.sh` 加入失敗的內容檢查（兩個 Skill 的共同外框仍逐位元相同）。
- [x] 6.4 執行 installer 同步四個 Skill 的安裝副本。測試要求：跑 6.1–6.3 的測試與 `diff` 一致性檢查。

## 7. 文件

- [x] 7.1 更新 README、`docs/workflow/local-development.md`、`docs/workflow/guide.md` 與 `docs/github-handoff.md` 的相關段落，說明交接迴圈、角色範本與專用 Agent；把 Work Item 中已確認的兩張流程圖整理後放入 `docs/diagrams/`。測試要求：`tests/test_documentation_authoring.sh` 通過；以 `rsvg-convert` 渲染圖稿目視確認，PNG 不入庫。

## 8. 整合驗證

- [x] 8.1 專用 Agent 連動測試：經使用者當次授權後，在本 repo 以 `gh` 建立測試 Issue 與 Draft PR，分別透過 `github-issue-agent`、`github-pr-agent` 完成建立、回覆、關閉並回讀，確認 Author 為呼叫端身分；測完關閉。結果記入 Work Item。（2026-11-16 依使用者選擇改在 private 測試 repo `wkchen5872/handoff-drill` 進行；Issue #1、PR #2 皆已關閉，見 Work Item 10.13；只測 Claude 版 Agent，Codex 版未實測。）
- [x] 8.2 真實演練：安裝 hook 並在 Codex 信任後，以便宜模型（Claude Haiku、Codex Luna）對一個小 Change 分別以審查 `shared` 與 `new` 各跑一次 `handoff-start`，每次至少經過一次退回與一次通過，並比較兩種模式的成本（含依賴安裝）；pass 後先另做一次 commit，再試 `handoff-finish` 確認被拒，回到乾淨的受審 commit 後以 `handoff-finish` 完成本地收尾；確認 `routing.log`、交件單與通知符合預期，並驗證只改 hook 腳本內容時 Codex 是否需要重新信任。結果記入 Work Item。（2026-11-16 完成，結果見 Work Item 10.7–10.11；`shared` 只真實走過通過路徑，退回路徑由 `new` 演練與自動測試驗證，使用者已接受。）
- [x] 8.3 PR 交付演練：經使用者當次授權，對 8.2 的測試 Change 以 `finish.delivery: pr` 跑一次收尾，確認最終版 Review 審的是交付後的 head、通過後才發 Closure 並回讀；測完關閉測試 PR。結果記入 Work Item。（2026-11-16 完成於 private 測試 repo：PR #3 走到最終版 Review 為 changes-required、不發 Closure；重跑 PR #4 最終版 Review pass 後才發 Closure 並回讀。見 Work Item 10.14–10.16。PR #4 保持 OPEN 待使用者決定。）
- [x] 8.5 清理實測：在演練 repo 對已收尾的 `add-titlecase` 與 `add-slugify` 執行 `handoff-cleanup`，先看計畫再加 `--yes`；確認 Session 已刪、worktree 已移除、分支仍在、紀錄已搬到主 worktree。結果記入 Work Item。
- [x] 8.4 執行專案完整檢查：`tests/test_*.sh` 全部通過、`openspec validate add-agent-handoff-loop --strict` 通過、pre-commit gate 通過。

## Workflow follow-up

- 依使用者授權以 `openspec-commit` 封存並提交。
- 合併回 main 時依 D-009 壓成一個 commit；合併、刪除分支與 worktree 另行授權。
