# Design

## Context

需求動機見 [proposal.md](proposal.md)。這是目標設計，尚未實作或安裝。

目前有兩條註冊路徑。

- [通知 registry](../../../scripts/notify/lib/registry.sh) 的 `register_hook_codex()` 分別註冊四個事件。相同 command 存在時保留原陣列。
- [workflow 共用函式](../../../scripts/workflow/lib.sh) 的 `_register_settings_hook()` 接受 file、event、matcher、command 四個參數。[分支 installer](../../../scripts/workflow/openspec-branch-creator/install.sh) 與 [交接 installer](../../../scripts/handoff/install.sh) 各自呼叫它註冊 Claude Code 和 Codex。

兩條路徑都沒有寫入 `statusMessage`。因此只替新增項目加入名稱，無法更新既有安裝。Codex 在 [官方顯示邏輯](https://github.com/openai/codex/blob/main/codex-rs/tui/src/bottom_pane/hooks_browser_view.rs#L420-L425) 中對非空白 `status_message` 取名稱，否則顯示 `Unnamed hook`。

[Telegram 修復入口](../../../scripts/notify/telegram/update.sh) 的 `fix_hooks()` 會先移除本工具管理的項目再重建。一般註冊與明確修復必須分別描述，避免宣稱修復也會保留原有自訂欄位。

## Goals / Non-Goals

**Goals:**

- 以既有註冊路徑提供一致名稱，並原地補齊舊 handler 的缺名欄位。
- 將寫入範圍限制在相同事件、相同 command 的本工具項目。
- 讓四參數的既有共用函式呼叫保持相容，新增欄位只作用於 Codex。

**Non-Goals:**

- 不變更 hook 的事件、執行順序、執行內容、timeout 或控制決策。
- 不替 Xirp、Herdr、其他 plugin 或使用者自行註冊的 hook 命名。
- 不新增命名設定檔、互動式命名精靈、依賴或另一套 registry。
- 不改寫 Codex trust 或 enable 狀態，也不改變 `fix-hooks` 的重建語意。

## Decisions

### 使用 handler 的 statusMessage

`statusMessage` 是 Codex 支援的 handler 欄位，同時用於 `/hooks` 標題與執行狀態文字。[官方 schema](https://github.com/openai/codex/blob/main/codex-rs/protocol/src/hooks.rs#L151-L161) 將它與 `type`、`command` 放在同一層。

採用以下預設值，規格與文件使用相同文字。

| 功能 | Codex 事件 | 預設 statusMessage |
| --- | --- | --- |
| Telegram 完成 | Stop | `Telegram 完成通知` |
| Telegram 操作確認與檢查 | PermissionRequest | `Telegram 操作確認與等待檢查` |
| Telegram 同步問題檢查 | PreToolUse | `Telegram 同步問題等待檢查` |
| Telegram 非同步問題 | PostToolUse | `Telegram 非同步問題通知` |
| OpenSpec 分支相容 hook | PostToolUse | `OpenSpec 規劃分支檢查` |
| Agent 交接 | Stop | `Agent 交接派送` |

改腳本檔名或加入 `name` 無法滿足已查明的顯示邏輯。名稱放在個別 handler，讓同一事件下的項目可以分辨。

### 在既有註冊轉換中補名

`_register_settings_hook()` 增加可省略的第五個參數 `status_message`。只有 Codex 呼叫端傳入預設文字。四參數呼叫維持原有行為與輸出欄位。

有預設文字時，註冊函式先尋找相同事件中 type 為 command、command 完全相同的 handler。找到後，只補 absent、null、空字串或純空白字串的 `statusMessage`。非空白自訂文字保持原值，其他欄位及 matcher group 原地保留。找不到時，沿用原有建立方式並附上預設文字。既有重複項目的全面去重不在此變更範圍。

通知 registry 在目前的 Codex JSON 轉換中採用相同補名規則，沿用其既有 command 識別與可識別資料形狀。四個通知名稱由事件的註冊位置提供，不從腳本路徑猜測。

兩者都沿用原有暫存檔寫入流程。正常重跑後比較排序過的 JSON，應得到相同結果。這項設計採用 Make Operations Idempotent 原則，讓既有狀態收斂到已命名的配置。

直接刪除再重建所有 hook 雖然容易套入名稱，會丟失使用者自訂欄位，因此一般註冊不採用。另建共用 registry 模組會增加通知與 workflow 的相依，這次保留原有模組邊界。

### 保留明確修復的重建行為

`update.sh fix-hooks` 沿用原本的移除後重建，因此重建的通知 handlers 使用預設名稱。文件必須提醒自訂名稱會重設。一般 install 與重複 registration 的補名行為，仍保留非空白自訂文字。

不為命名功能重新設計修復流程。測試直接執行修復入口，確認預設名稱完整、第三方項目保留，且不修改信任狀態。

### 以配置結果作為自動測試邊界

採用 Test Behavior, Not Implementation 原則。測試執行現有 installer 或 registry 入口，再檢查暫存 HOME 中實際寫出的 JSON。預期名稱取自規格，不從實作的常數產生。

先新增並執行以下行為測試，記錄因名稱尚未寫入而失敗的 Red，再實作最小修正。

| 現有測試入口 | 新增驗收範圍 |
| --- | --- |
| `bash scripts/notify/telegram/test.sh` | 四個名稱、新舊配置、名稱保留、修復重設、第三方欄位、跨 Provider 隔離 |
| `bash tests/test_workflow.sh install` | 新分支註冊、遷移配置補名、四參數呼叫相容、重跑與移除 |
| `bash tests/test_agent_handoff.sh hookinstall` | 新交接註冊、舊項目補名、名稱保留、第三方 Stop、trust 不寫入 |

每條註冊路徑涵蓋 absent、null、空字串、空白字串及非空白自訂名稱。至少一組 fixture 將本工具和第三方 handler 放在同一 matcher group，避免只驗證分開的群組。補名後除了 `statusMessage` 外，完整配置應與補名前相等。第二次安裝使用排序後的 JSON 比較冪等結果。另回歸原有 uninstall 行為。

Telegram 測試維持 dry-run，不傳送真實訊息。workflow 與 handoff 測試使用暫存 repo 和 HOME。實作完成後執行三套完整受影響測試及 Bash 語法檢查。

自動測試證明配置結果，無法證明本機 Codex 的面板已載入或 hooks 已受信任。真實 `/hooks` 的名稱、trust 及勾選狀態另行操作驗收，未執行時明列為未驗證。

## Risks / Trade-offs

- 名稱變更會改變 Codex 信任判定使用的定義雜湊。安裝與操作文件說明重新開啟 session，再於 `/hooks` 信任並啟用；程式不代為批准。依據見 [官方信任說明](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks) 與 [定義雜湊實作](https://github.com/openai/codex/blob/main/codex-rs/hooks/src/engine/discovery.rs#L981-L997)。
- 保留既有非空白自訂名稱，表示部分使用者看到的文字可能不同於預設表。文件說明這是預期結果。
- `fix-hooks` 會恢復預設名稱。文件和修復測試明確驗證此行為，不宣稱自訂名稱跨明確修復保留。
- 共用 helper 影響兩個模組及 Claude Code 呼叫端。測試同時檢查 Codex 補名與其他 Provider 的既有輸出欄位。
- 官方來源比對目前 main，調查時本機 CLI 為 0.169.0；此規劃未實測改名後的 TUI 畫面。

## Migration Plan

1. 在暫存 HOME 完成 test-first 與受影響測試，先確認新舊配置都可補名。
2. 將修正留在上述來源腳本，透過現有分支 hook installer、handoff installer 及 Telegram 安裝或 `update.sh fix-hooks` 套用。實際安裝前保留原 hook 配置供比對。
3. 操作文件標明從本 repo 根目錄執行的命令及既有副作用。分支 installer 也維護目前 repo 的 Copilot hook 檔案，handoff installer 也部署其命令與函式庫。
4. 重新開啟 Codex session，在 `/hooks` 核對預設名稱或既有自訂名稱，完成所需的 trust review，並確認啟用狀態。
5. 若需回復，按更新前的備份還原此次工具所管理 handler 的名稱欄位，保留更新期間其他工具新增或修改的 hooks。重新開啟 session 並檢查信任狀態。

只完成配置檢查時，回報配置驗證通過；只有實際觀察面板後，才回報 TUI 名稱驗收通過。
