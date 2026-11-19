# Tasks

## 1. 前置與實測

- [x] 1.1 確認 `add-handoff-notifications` 已封存並合併到 `main`，本分支已同步（rebase 或 merge）。測試要求：查證任務；完成條件是 `openspec/specs/agent-handoff-notifications/spec.md` 存在、`openspec validate add-pi-handoff-agent --strict` 通過，且 `bash tests/test_agent_handoff.sh` 在同步後全數通過。
- [x] 1.2 實測 Xirp 開 Pi Session 的參數。結果（記於 Work Item）：Xirp 0.68.0 的選項鍵為 `provider`、`model`、`thinking`，但對 Pi 1.5.2（未測試版本）整組丟掉選項；改以角色 worktree 的 `.pi/settings.json` 指定，並以全域 extension 回答信任提示，實測 Session 跑在 `openai-codex/gpt-5.6-luna low`（全域預設為 `gpt-6-sol medium`）。design.md 決策 2、8 已依此更新。

## 2. Pi 角色驗證（`handoff.sh`）

- [x] 2.1 `ho_template_check` 接受 `harness: pi`，Pi 角色必填 `provider`、`billing`（`subscription`／`api`），effort 限 Pi 的七個等級，`model` 不得含 `/`；非 Pi 角色設 `provider` 或 `billing` 即拒絕；未知 harness 的訊息列出 `claude`、`codex`、`pi`。測試要求：先在 `tests/test_agent_handoff.sh` 寫失敗測試，涵蓋缺 billing、非法 billing、非法 effort、Codex 設 billing、`gemini` harness、模型含 `/`，每案斷言非零結束、訊息內容、假 `xirp` 沒有收到 `session:create`。
- [x] 2.2 新增 `ho_pi_verify <role> <provider> <model> <effort> <billing>`：`pi --list-models <model>` 需有 provider 與 model 完全相同的一列，effort 非 `off` 時該列 thinking 為 `yes`；`pi auth check --provider <p> --json` 需 `ready` 且 `oauth`↔`subscription`、`api_key`↔`api`；anthropic+oauth+subscription 輸出 extra usage 提醒；失敗輸出角色、項目、宣告值與實際值。測試要求：先寫失敗測試，假 `pi` 依環境變數回傳表格與 JSON；涵蓋同 ID 兩個 provider、模型只在另一個 provider、別名、不支援 thinking、四種 billing 組合、`not_ready`、`invalid`、未知 authType、`pi` 不在 PATH、anthropic 提醒有無；斷言輸出不含任何 key 或 token 字樣。
- [x] 2.3 新增 `scripts/handoff/handoff-pi-trust <dir>` 與 `handoff.sh` 的 `ho_pi_repo_trusted <main>`：依 design 決策 8 的三個條件判斷是否信任交接 worktree；`ho_pi_repo_trusted` 以 `~/.pi/agent/trust.json` 中離主 worktree 最近的上層決定為準。測試要求：先寫失敗測試，暫時 HOME 與暫時 repo；涵蓋主 worktree 本身、`loop.yaml` 不存在、`loop.yaml` 被追蹤、`loop.yaml` 未列出此 worktree、主 worktree 未被信任、上層被信任、較近的上層為 `false`，各自斷言結束碼；全部成立時為 0；腳本不修改 `trust.json`。

## 3. 啟動 Pi 角色（`handoff-start`、`ho_xirp_create`）

- [x] 3.1 `ho_xirp_create` 新增 `pi` 分支：`agent.options` 帶 `model`、`provider`、`thinking`；新增 `ho_pi_settings <worktree> <provider> <model> <effort>` 寫入 `.pi/settings.json`（`defaultProvider`、`defaultModel`、`defaultThinkingLevel`），把 `/.pi/settings.json` 加入 `git rev-parse --git-path info/exclude`（必要時建立目錄，只加一次）；相同內容沿用，不同內容或被 Git 追蹤即拒絕且不覆蓋；`ho_open_role` 開 Pi 角色前呼叫；`ho_copy_template` 複製 `provider`、`billing`。測試要求：先寫失敗測試，假 `xirp` 記錄的 `session:create` JSON 中 `agentName` 為 `pi`、三個選項值與範本相同；設定檔內容以 `jq` 讀回；寫入後 `git status --porcelain` 為空、exclude 只有一行；不同內容與被追蹤的檔案各自拒絕且內容不變、沒有 `session:create`；Claude、Codex 的 JSON 與現在相同（既有測試維持通過）。
- [x] 3.2 `handoff-start` 在建 worktree 與開 Session 前，對 implement、review、finish 中所有 Pi 角色檢查：一個 worktree 最多一個 Pi 角色（依 design 決策 2 計算）、`~/.pi/agent/extensions/wk-handoff.ts` 存在、主 worktree 已被信任（`ho_pi_repo_trusted`）、`ho_pi_verify`；任一失敗即非零結束；開實作 Session 前寫入 `.pi/settings.json`；`loop.yaml` 新增 `implement_template`。測試要求：先寫失敗測試——finish 角色 billing 不符時沒有 `session:create`、`git worktree list` 沒有新 worktree、訊息指出 finish；Pi 實作者與 `shared` 的 Pi 審查者被拒並指出兩個角色、Pi 審查改 `new` 後通過、Pi 實作者與 Codex 審查共用通過；extension 不存在、主 worktree 未信任各自被拒且訊息提示安裝或 `/trust`；全部通過時只開實作 Session、實作 worktree 有正確的 `.pi/settings.json` 且乾淨，`loop.yaml` 含 `implement_template` 的五個欄位；anthropic 訂閱一致時 stderr 有提醒。
- [x] 3.3 覆寫參數支援 `pi:<provider>/<model>:<effort>:<billing>`，並與範本相同地驗證；格式錯誤時顯示正確格式。測試要求：先寫失敗測試，涵蓋缺 billing 的 Pi 覆寫、正確的 Pi 覆寫寫入 `loop.yaml` 且不改 `roles.yaml`、既有 claude／codex 覆寫維持可用。
- [x] 3.4 更新 `template/common/skills/agent-handoff/roles.example.yaml`：註解說明 Pi 欄位、billing 對應、`/skill:<name>` 呼叫語法、Anthropic 提醒，並加入一組註解掉的 Pi 角色範例。測試要求：把範例中的 Pi 角色取消註解後交給 `ho_template_check` 與假 `pi` 驗證通過；執行 `bash scripts/skills/install.sh` 後 `diff` 範本與安裝位置一致。

## 4. 交件單的 Agent 身分

- [x] 4.1 `handoff-write` 在 `PI_CODING_AGENT=true` 且 `PI_PROVIDER` 有值時寫入 `agent` 區塊（`harness`、`provider`、`model`、`effort`、`billing`、`session`），billing 由 `pi auth check` 對應；取不到寫 `unknown`，仍寫出交件單；不接受相關參數。測試要求：先寫失敗測試，涵蓋 Pi 環境完整值、`pi auth check` 失敗寫 `unknown`、非 Pi 環境沒有 `agent` 區塊；以 `kv_get` 讀回每個欄位。
- [x] 4.2 `handoff-author --tool Pi` 讀 `PI_SESSION_ID`；`ho_author` 對 `pi` 輸出 `Pi`。測試要求：先寫失敗測試，斷言四行輸出與兩個 Session ID 完全相同、未設定時為 `null`。
- [x] 4.3 更新 `template/common/skills/agent-handoff/SKILL.md`：Pi 角色的交件單由角色 Session 自己寫、`agent` 區塊的來源、`--tool Pi`。測試要求：執行 `bash scripts/skills/install.sh` 後 `.claude/skills/agent-handoff/` 與 `.agents/skills/agent-handoff/` 和範本一致；`bash tests/test_acceptance_bank.sh` 通過。

## 5. 路由比對與開啟前驗證（`handoff-route`）

- [x] 5.1 路由前比對：交件單角色對應的 `loop.yaml` 範本為 Pi 時，比對 provider、model、effort、billing，並要求 `agent` 區塊存在且無 `unknown`；不符時發 attention（列出每一項）並寫入 `.routed`，不傳訊、不開 Session；Claude／Codex 範本跳過。測試要求：先寫失敗測試，四項各自不符、缺 `agent` 區塊、`unknown` 各一案——恰一則 attention、假 `xirp` 沒有 `session message` 或 `session:create`、交件單在 `.routed`、第二次執行沒有任何動作；相符時照常路由；既有的 claude／codex 路由測試維持通過。
- [x] 5.2 開啟 Pi 審查或收尾 Session 前再執行 `ho_pi_verify`、extension 與信任檢查，並在該角色的 worktree 寫入 `.pi/settings.json`（`worktree: new` 時寫入新建的 worktree）；任一失敗失敗時歸為可重試的開啟失敗（attention 一次、不寫入 `.routed`、`routing.log` 記 `open-failed`）。`handoff-finish` 開 Pi 收尾前也驗證，失敗即非零結束。測試要求：先寫失敗測試——首次實作交件時審查角色 billing 不符、或審查 worktree 已有不同內容的 `.pi/settings.json`：沒有 `session:create`、一則 attention、交件單不在 `.routed`；修正假 `pi` 後再執行：審查 Session 開啟、交件單寫入 `.routed`、沒有第二則 attention；`handoff-finish` 驗證失敗時非零結束且沒有新 Session。
- [x] 5.3 交件單通知的 Agent 資訊：Pi 交件單從 `agent` 區塊產生 `Pi / <provider>/<model> / <effort> / 訂閱|API`，手動執行與重試也顯示。測試要求：先寫失敗測試，以假通知腳本記錄的 JSON 斷言 agent 欄位；涵蓋訂閱、API、`unknown`、`--foreground` 重試；以通知腳本 dry-run 確認標題顯示正確。
- [x] 5.4 `handoff-cleanup --yes` 保留主 worktree 時，移除其中由迴圈為 Pi 角色寫入的 `.pi/settings.json`（`loop.yaml` 的 `<角色>.pi_settings` 記錄為迴圈建立、未被追蹤、內容仍等於該 Pi 範本產生的設定）。測試要求：先寫失敗測試——`--worktree here` 於主 worktree 的 Pi 迴圈清理後檔案不存在；內容不同的檔案保留；沒有 Pi 範本的迴圈不動任何 `.pi` 檔案。

## 6. Pi 停止觸發

- [x] 6.1 新增 `scripts/handoff/pi/wk-handoff.ts`：`agent_settled` 時若無 `PI_SUBAGENT_PARENT_SESSION` 即以 `pi.exec` 執行 `handoff-route` 並傳入 cwd 與 Session ID；`project_trust` 時以 `pi.exec` 執行 `handoff-pi-trust <event.cwd>`，結束碼 0 回傳 `{trusted:"yes"}`（不帶 `remember`），其他情況與錯誤回傳 `{trusted:"undecided"}`；所有錯誤吞掉；不註冊 `tool_call` 或其他事件。測試要求：以 `pi -e scripts/handoff/pi/wk-handoff.ts` 啟動不報錯（載入檢查）；在暫時 repo 的交接 worktree 以 `pi -e … -p` 確認不出現信任提示、Session 跑在 `.pi/settings.json` 的模型、`trust.json` 不變；路由行為由 7.2 真實驗收確認。
- [x] 6.2 `scripts/handoff/install.sh` 安裝 extension 到 `~/.pi/agent/extensions/wk-handoff.ts`、`handoff-pi-trust` 到 `~/.config/wk-workflow/handoff/`，並提示已開啟的 Pi Session 需 `/reload` 或重開、使用 Pi 角色的 repo 需先在主 worktree 執行 `/trust`。測試要求：先寫失敗測試，暫時 HOME 下執行兩次 installer，extension 只有一份且內容與來源相同、提示文字出現、Claude 與 Codex 的 Stop hook 登記不變。
- [x] 6.3 更新文件：`scripts/handoff/README.md`（Pi 欄位、三個關口、Anthropic 提醒、角色內 subagent 會換 provider 的三種例外、`.pi/settings.json` 與 `info/exclude`、一個 worktree 一個 Pi 角色、自動信任的條件、安裝、`/trust` 與 `/reload`）、`docs/hooks/index.md` 支援矩陣加入 Pi、`docs/skills/agent-handoff.md`。測試要求：依 `docs/okf-conventions.md` 檢查；文件中的指令與檔案路徑實際存在（以 `rg` 對照），README 的範本範例通過 `ho_template_check`。

## 7. 整合驗收

- [x] 7.1 執行完整檢查：`bash tests/test_agent_handoff.sh`、`bash tests/test_acceptance_bank.sh`、`bash scripts/notify/telegram/test.sh`、`openspec validate add-pi-handoff-agent --strict`。測試要求：全數通過，結果記入 Work Item。
- [x] 7.2 真實演練（演練用 repo，`openai-codex` 訂閱）：Pi 實作 → 審查退回 → 修正 → 通過 → 收尾一輪；過程中確認角色內 subagent 停下不觸發路由；另演練一次把實作 Session 中途 `/model` 到 `openai/gpt-6.2-sol` 後交件，確認不接棒且收到 attention。測試要求：Work Item 記錄每一步的 `routing.log`、交件單 `agent` 區塊與收到的通知；演練結束後以 `handoff-cleanup --yes` 清理。

## Workflow follow-up

- 依專案流程完成審查後封存本 change，並確認 `openspec/specs/agent-handoff-pi/spec.md` 已建立、其他四個能力的主規格已更新。
