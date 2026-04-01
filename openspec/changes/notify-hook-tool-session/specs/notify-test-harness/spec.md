## ADDED Requirements

### Requirement: hook.sh dry-run 模式
hook.sh SHALL 支援 `TELEGRAM_DRY_RUN=true` 環境變數。當啟用時，跳過 curl 呼叫，改將完整訊息內容輸出到 stdout，並以 exit 0 結束。所有其他邏輯（工具偵測、事件映射、session 格式化、NOTIFY_LEVEL gate）仍正常執行。

#### Scenario: Dry-run 輸出訊息到 stdout
- **WHEN** `TELEGRAM_DRY_RUN=true bash hook.sh stop "Claude Code"` 執行，config 有效
- **THEN** 訊息內容輸出到 stdout，不發送 HTTP 請求，exit code 為 0

#### Scenario: Dry-run 保留所有判斷邏輯
- **WHEN** `TELEGRAM_DRY_RUN=true NOTIFY_LEVEL=notify_only bash hook.sh stop "Claude Code"`
- **THEN** stdout 無輸出（被 notify_only gate 攔截），exit 0

---

### Requirement: test.sh — hook 行為測試腳本
`scripts/notify/telegram/test.sh` SHALL 提供自動化測試，利用 `TELEGRAM_DRY_RUN=true` 驗證 hook.sh 在各種情境下的輸出，無需真實 Telegram 連線。測試結果以 PASS / FAIL 顯示，所有 PASS 時 exit 0，有任何 FAIL 時 exit 1。

#### Scenario: 執行所有測試並顯示結果
- **WHEN** `bash scripts/notify/telegram/test.sh` 執行
- **THEN** 每個測試案例顯示 `✓ PASS: <name>` 或 `✗ FAIL: <name>` 及期望 vs 實際內容，最後顯示總結（N passed, M failed）

#### Scenario: 全部通過時 exit 0
- **WHEN** 所有測試案例通過
- **THEN** 腳本 exit 0

#### Scenario: 有失敗時 exit 1
- **WHEN** 至少一個測試案例失敗
- **THEN** 腳本 exit 1（方便 CI 整合）

---

### Requirement: 測試覆蓋已知問題情境
`test.sh` SHALL 涵蓋以下情境，對應歷史上曾發生的 bug 或回報的問題：

#### Scenario: [BUG-01] Copilot sessionEnd 顯示 Task Complete（非 AI CLI Event）
- **WHEN** `bash hook.sh sessionEnd "Copilot CLI"` 執行（模擬舊版 case 問題）
- **THEN** 輸出包含 `Task Complete`，不包含 `AI CLI Event`

#### Scenario: [BUG-02] $2 參數覆蓋 env var，Copilot 正確識別
- **WHEN** `CLAUDE_PROJECT_DIR=/some/path bash hook.sh sessionEnd "Copilot CLI"` 執行
- **THEN** 輸出包含 `Copilot CLI`，不包含 `Claude Code`

#### Scenario: [BUG-03] 無 $2 且 event=sessionend，Copilot fallback 正確
- **WHEN** `bash hook.sh sessionEnd`（無 $2），env var 皆未設定
- **THEN** 輸出包含 `Copilot CLI`

#### Scenario: [BUG-04] Claude stop 正確顯示 Task Complete
- **WHEN** `bash hook.sh stop "Claude Code"` with stdin `{"hook_event_name":"Stop"}`
- **THEN** 輸出包含 `Task Complete` 且包含 `Claude Code`

#### Scenario: [BUG-05] Claude notification 正確顯示 Action Required
- **WHEN** `bash hook.sh notification "Claude Code"` with stdin `{"hook_event_name":"Notification","message":"Test msg"}`
- **THEN** 輸出包含 `Action Required` 且包含 `Test msg`

#### Scenario: [BUG-06] Gemini AfterAgent 正確顯示 Task Complete
- **WHEN** `bash hook.sh AfterAgent "Gemini CLI"`
- **THEN** 輸出包含 `Task Complete` 且包含 `Gemini CLI`

#### Scenario: [SESSION-01] UUID session_id 截短顯示
- **WHEN** stdin `{"session_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890"}`, event=stop, tool=Claude Code
- **THEN** 標題包含 `(#a1b2c3d4)`

#### Scenario: [SESSION-02] 無 session 資訊時標題不帶括號
- **WHEN** stdin 無 session 欄位，env 無 session var
- **THEN** 標題行不包含 `(`

#### Scenario: [LEVEL-01] notify_only 模式抑制 Task Complete
- **WHEN** `NOTIFY_LEVEL=notify_only bash hook.sh stop "Claude Code"`
- **THEN** stdout 無輸出（dry-run 模式下）

#### Scenario: [LEVEL-02] notify_only 模式允許 Action Required
- **WHEN** `NOTIFY_LEVEL=notify_only bash hook.sh notification "Claude Code"`
- **THEN** 輸出包含 `Action Required`
