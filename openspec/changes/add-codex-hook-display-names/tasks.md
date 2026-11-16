# Tasks

所有命令從本 repo 根目錄執行。實作與測試依 [design.md](design.md) 及三份 delta specs；本清單尚未執行。

## 1. 通知 hook 命名與既有配置補齊

- [ ] 1.1 在 `scripts/notify/telegram/test.sh` 新增四個 Codex handlers 的命名與遷移測試。測試要求：使用暫存 HOME 及 dry-run，涵蓋 absent、null、空字串、純空白、自訂名稱、同群組第三方 handler、其他欄位保留與重跑 JSON 相等；執行後記錄因名稱尚未寫入而失敗的有效 Red。
- [ ] 1.2 修改 `scripts/notify/lib/registry.sh`，為新 handler 加入規格的預設名稱，並只補既有 handler 的缺名欄位。測試要求：1.1 測試通過，四個事件各只有一個匹配項目，其他 Provider 的配置欄位及原有 uninstall 測試保持通過。
- [ ] 1.3 在通知測試加入 `update.sh fix-hooks` 的實際入口案例，並更新 `docs/notify/telegram.md` 與 `scripts/notify/README.md`。測試要求：暫存環境中修復會恢復四個預設名稱，第三方設定仍保留且不修改 trust；文件說明一般註冊保留名稱、明確修復重設名稱，以及重開 session 後的信任與啟用步驟。

## 2. 共用註冊函式與 OpenSpec 分支 hook

- [ ] 2.1 在 `tests/test_workflow.sh` 的 install 區段新增命名與舊配置補名測試。測試要求：執行 `bash tests/test_workflow.sh install` 取得有效 Red，涵蓋新安裝、Claude 遷移配置、各種缺名值、自訂名稱、同群組第三方欄位、重跑 JSON 相等及 Claude Code 與 Copilot 輸出相容。
- [ ] 2.2 為 `scripts/workflow/lib.sh` 的 `_register_settings_hook()` 加入可省略的第五個名稱參數，並在 `scripts/workflow/openspec-branch-creator/install.sh` 的 Codex 呼叫傳入預設名稱。測試要求：2.1 測試通過，既有四參數呼叫不增加命名欄位，既有 handler 除補名外不變，原有移除測試通過。
- [ ] 2.3 更新 `scripts/workflow/README.md` 的安裝及排查段落。測試要求：文件列出 `OpenSpec 規劃分支檢查`、來源命令的執行目錄及既有 Copilot 檔案副作用，並可按步驟在暫存 HOME 重播註冊、補名及重跑結果。

## 3. Agent 交接 hook

- [ ] 3.1 在 `tests/test_agent_handoff.sh` 的 hookinstall 區段新增交接名稱案例。測試要求：先執行 `bash tests/test_agent_handoff.sh hookinstall` 取得缺少交接名稱的有效 Red，涵蓋新安裝、各種缺名值、自訂名稱、第三方 Stop 及其餘欄位保留、重跑 JSON 相等、Claude 相容與 trust 不寫入。
- [ ] 3.2 在 `scripts/handoff/install.sh` 的 Codex 註冊傳入 `Agent 交接派送`，並更新 `scripts/handoff/README.md`。測試要求：3.1 測試通過，文件指明重開 session 後在 `/hooks` 核對名稱、信任及啟用，現有命令與函式庫部署測試保持通過。

## 4. 整合驗證與共用操作說明

- [ ] 4.1 更新 `docs/hooks/codex-hooks.md`，集中列出六個預設名稱、handler 欄位層級及各模組現有安裝入口。測試要求：與三份規格逐項比對名稱，確認一般重跑、保留自訂名稱、明確修復重設名稱與重新信任的說明一致，並檢查連結及 JSON 範例。
- [ ] 4.2 執行 `bash scripts/notify/telegram/test.sh`、`bash tests/test_workflow.sh`、`bash tests/test_agent_handoff.sh` 及所有變更 shell 檔案的 `bash -n`。測試要求：三套完整受影響測試及語法檢查通過，記錄執行結果；所有自動測試使用暫存環境，不傳送真實通知或啟動真實交接。
- [ ] 4.3 記錄 Codex 真實面板的驗收狀態。測試要求：可操作時於安裝後新 session 核對六個名稱或原有自訂名稱，觀察 trust review 與啟用狀態；無法操作時記錄具體限制並明列 TUI 未驗證，配置檢查不得代替畫面驗收。
- [ ] 4.4 核對實作符合三份 delta specs，並執行 `openspec validate add-codex-hook-display-names --strict` 與差異檢查。測試要求：驗證通過，文件反映最終行為，差異僅包含本 Change 授權範圍，驗證紀錄區分已測配置及未測真實流程。
