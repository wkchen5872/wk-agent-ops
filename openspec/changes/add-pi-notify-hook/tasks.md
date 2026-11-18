# Tasks

## 1. 前置實測

- [ ] 1.1 查證 Xirp 背景開啟的 Pi session 也以 TUI 執行：前景 session 已確認（程序鏈 `tmux new-session -d -s xirp-<id>` → Xirp node → `pi`，沒有 `-p` 或 `--mode`）。以 `xirp api send session:create` 帶 `background: true` 與 `agent.agentName: "pi"` 開一個演練 session，用 `ps` 追它的程序鏈與參數，確認同樣是不帶模式參數的 `pi`；演練後刪除該 session。測試要求：查證任務；完成條件是 Work Item 記下前景與背景兩種 session 的程序鏈。若背景 session 帶 `--mode rpc` 或 `-p`，先回報使用者決定是否調整 design.md 決策 2，再繼續。

## 2. 通知腳本的 Pi 事件

- [ ] 2.1 `events.tsv` 新增 `pi-stop:completed`、`pi-stop:error`、`pi-stop:aborted`、`pi-stop:*`、`pi-question`；`hook.sh` 在事件為 `pi-stop` 時以 payload 的 `stop_reason`（只留小寫字母）組事件鍵。測試要求：先在 `scripts/notify/telegram/test.sh` 寫失敗的 dry-run 測試——completed 產生工作結束、error 產生異常停止且理由為 `error`、aborted 與未知值不產生訊息、`pi-question` 產生等待回應；標題含 `Pi` 與 UUID 前八碼的 Session 標籤；payload 夾帶 `message`、錯誤原文時訊息中不出現。
- [ ] 2.2 確認分類開關與等級對 Pi 事件生效。測試要求：先寫失敗測試——`NOTIFY_COMPLETION=false` 時 completed 不送、`NOTIFY_FAILURE=false` 時 error 不送、`NOTIFY_USER_INPUT=false` 時 question 不送、`NOTIFY_LEVEL=attention_required` 時 completed 不送但 error 與 question 送出；`TELEGRAM_ENABLED=false` 時都不送。

## 3. Pi extension

- [ ] 3.1 新增 `scripts/notify/pi/ai-notify.ts`：首行為擁有標記；只在 `ctx.hasUI` 為真且沒有 `PI_SUBAGENT_PARENT_SESSION` 時運作；依 design.md 決策 1 追蹤 `agent_start`、`agent_end`、`agent_settled`、`ui_prompt_start`；以 detached 的 `bash <hook> <event> Pi` 傳送 `{hook_event_name, session_id, cwd, stop_reason}`，不等待結果、吞掉所有錯誤；通知腳本不存在時直接返回；不轉送提示標題、訊息或錯誤內容。測試要求：以不呼叫模型的方式做載入檢查（例如 `pi -e scripts/notify/pi/ai-notify.ts --list-models` 結束碼為 0 且沒有 extension 錯誤）；以 `rg` 確認檔案中沒有讀取提示 `title` 或 `errorMessage` 後送出的程式碼；行為由 5.2 真實演練確認。

## 4. 安裝、移除與狀態

- [ ] 4.1 `registry.sh` 新增 `register_pi_extension`、`unregister_pi_extension`，並由 `register_hook`、`unregister_hook` 在偵測到 Pi（`command -v pi` 或 `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}` 存在）時呼叫；`register_pi_extension` 從 `NOTIFY_SOURCE_ROOT/pi/ai-notify.ts` 複製（與 `deploy_notify_files` 取用來源的方式相同）；`fix-hooks` 走同一路徑；安裝完成時提示已開啟的 Pi session 需 `/reload`。測試要求：先在暫時 HOME 寫失敗測試——有 Pi 時安裝一份且與來源相同、執行兩次仍一份、同名無標記檔案不被覆寫且 stderr 有警告、移除只刪帶標記檔案、沒有 Pi 時不建立任何檔案、`PI_CODING_AGENT_DIR` 指定的目錄被使用；既有 Claude、Codex、Antigravity、Copilot 的 registry 測試維持通過。
- [ ] 4.2 `update.sh status` 列出 Pi 的狀態：已安裝、未偵測到 Pi、被同名檔案擋住。測試要求：先寫失敗測試，三種狀態各一案，輸出不含 token 或 chat ID。
- [ ] 4.3 更新文件：`docs/hooks/index.md` 支援矩陣加入 Pi（completion、failure、等待回應；無授權）、新增 `docs/hooks/pi-hooks.md`（事件對應、通知範圍、`pi -p` 不通知、安裝與 `/reload`、移除與衝突）、`docs/notify/telegram.md` 與 `scripts/notify/README.md` 的支援工具清單。測試要求：依 `docs/okf-conventions.md` 檢查；文件中的檔案路徑與指令實際存在（以 `rg` 對照）。

## 5. 整合驗收

- [ ] 5.1 執行 `bash scripts/notify/telegram/test.sh`、`python3 -m unittest discover -s scripts/notify/tests -v`、`openspec validate add-pi-notify-hook --strict`。測試要求：全數通過，結果記入 Work Item。
- [ ] 5.2 真實演練（使用訂閱登入的 provider）：在 Pi TUI 完成一輪對話、讓 pstack `ask_user_question` 開選單、按 Esc 中止一次、執行一次 `pi -p`、讓一個 subagent 結束；比對收到的通知恰為一則工作結束與一則等待回應，其餘沒有通知。錯誤路徑以中斷網路或無效模型觸發一次，確認收到異常停止且沒有錯誤原文。測試要求：Work Item 記錄每一步的預期與實際通知。

## Workflow follow-up

- 依專案流程完成審查後封存本 change，確認 `openspec/specs/pi-notify-hook/spec.md` 已建立、`telegram-notify-hook` 主規格已更新。
