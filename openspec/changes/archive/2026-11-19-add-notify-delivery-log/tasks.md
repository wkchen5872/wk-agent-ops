# Tasks

## 1. 送達紀錄

- [x] 1.1 在 `scripts/notify/telegram/test.sh` 先寫失敗測試（`DELIVERY-LOG` 區段）：開啟 `NOTIFY_DELIVERY_LOG=true` 且假 curl 回 `{"ok":true,"result":{"message_id":42}}` 時，`deliveries.log` 多一行，含 `event=stop`、`template=completion`、`ok=true`、`message_id=42`，不含 token、chat ID 與 `Task Complete`；假 curl 回 `{"ok":false}` 或非零結束時為 `ok=false message_id=-`；未開啟與 dry-run 時不建立檔案；預先 500 行時送出後仍 500 行且最後一行為新紀錄。驗證：`bash scripts/notify/telegram/test.sh` 以這些案例失敗（Red），原因是沒有紀錄。
- [x] 1.2 修改 `hook.sh` 的 `deliver()`：取回 Telegram 回覆與 curl 結束碼，開啟時依 design.md 決策 2 寫入並限制 500 行。驗證：1.1 通過（Green），既有測試（含 SEC-ARGV、送達與 dry-run）維持通過。
- [x] 1.3 更新 `docs/notify/telegram.md`：`NOTIFY_DELIVERY_LOG` 的用途、紀錄位置與格式、不含內容、500 行上限，以及用它排查沒收到通知。驗證：依 `docs/okf-conventions.md` 檢查；`grep -n 'NOTIFY_DELIVERY_LOG' docs/notify/telegram.md` 有結果。

## 2. 整合驗收

- [x] 2.1 執行 `bash scripts/notify/telegram/test.sh`、`python3 -m unittest discover -s scripts/notify/tests`、`bash tests/test_agent_handoff.sh`、`openspec validate add-notify-delivery-log --strict`。驗證：全部通過。

## Workflow follow-up

- 依專案流程封存本 change，確認 `openspec/specs/telegram-notify-hook/spec.md` 已加入新需求。
- 合併後執行 `bash scripts/notify/telegram/update.sh fix-hooks`；開啟設定送一則真實通知，確認紀錄出現。
