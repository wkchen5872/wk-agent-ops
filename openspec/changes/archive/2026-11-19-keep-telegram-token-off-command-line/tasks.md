# Tasks

## 1. 通知送出不帶憑證上指令列

- [x] 1.1 在 `scripts/notify/telegram/test.sh` 先寫失敗測試：假 curl 記錄 argv 與 stdin；hook 以 token `123:abcDEF`、chat `12345` 送出一則完成通知時，argv 不含兩者、stdin 含 `sendMessage` URL 與 `data = "chat_id=12345"`、argv 仍含 `parse_mode=Markdown`；token 含 `"` 時 curl 未被呼叫且 hook 結束碼為 0。驗證：`bash scripts/notify/telegram/test.sh` 以這些案例失敗（Red），原因是 token 仍在 argv、未驗證字元。
- [x] 1.2 修改 `hook.sh` 的 `deliver()`：驗證 token 與 chat ID 字元，URL 與 `chat_id` 改由 `printf` 經 stdin 交給 `curl --config -`。驗證：1.1 的案例通過（Green），既有 dry-run 與送達測試維持通過。

## 2. 安裝精靈不帶 token 上指令列

- [x] 2.1 先寫失敗測試：安裝精靈以假 curl 完整跑一次，所有 curl 呼叫的 argv 都不含 token。驗證：`bash scripts/notify/telegram/test.sh` 以此案例失敗（Red）。
- [x] 2.2 修改 `install.sh` 的 `getMe`、`getUpdates` 與測試訊息三處，URL（與 chat ID）改由 stdin 交給 `curl --config -`；token 字元不符時沿用「token 無效」提示。驗證：2.1 通過（Green），LIFE-CONFIG-01 等既有安裝測試維持通過。
- [x] 2.3 更新 `docs/notify/telegram.md`：說明 token 與 chat ID 不會出現在程序列表、只接受的字元，以及舊 token 曾外露時的輪換建議。驗證：依 `docs/okf-conventions.md` 檢查；以 `grep -n 'config -\|程序列表' docs/notify/telegram.md` 確認說明存在。

## 3. 整合驗收

- [x] 3.1 執行 `bash scripts/notify/telegram/test.sh`、`python3 -m unittest discover -s scripts/notify/tests`、`bash tests/test_agent_handoff.sh`、`openspec validate keep-telegram-token-off-command-line --strict`。驗證：全部通過。

## Workflow follow-up

- 依專案流程封存本 change，確認 `openspec/specs/telegram-notify-hook/spec.md` 已加入新需求。
- 合併後執行 `bash scripts/notify/telegram/update.sh fix-hooks`，在任一 AI CLI 完成一輪確認仍收到通知。
