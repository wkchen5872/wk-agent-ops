# Design

## Context

動機見 proposal.md 的 Why。程式位置以 main `89b1af0` 為準（實作時以 rebase 後的實際行號為準）：

| 現在散落的 harness 知識 | 位置 |
|---|---|
| 合法值 `claude\|codex\|pi` | `ho_template_check`（lib:817）、doctor 的迴圈（lib:1180） |
| override 格式正規式與錯誤訊息 | `handoff-start:50-51`、`handoff-role:40-41`（相同） |
| 顯示名稱（`'Claude Code'`、`Codex`、`Pi`） | `ho_author`（lib:791） |
| skill 呼叫語法（`/x`、`$x`、`/skill:x`） | `ho_retool`（lib:873） |
| xirp 的 effort 欄位（`effort`／`reasoning_effort`／`thinking`） | `ho_xirp_create`（lib:187-192） |
| 啟動參數 | `ho_herdr_open`（lib:434-440，bash 陣列，不含程式名）、`ho_happ_argv`（lib:560-569，JSON 陣列，含程式名） |
| 觸發器檢查 | doctor（lib:1185-1194） |

| 「送出結果不明」機制 | 使用者 |
|---|---|
| `ho_herdr_unconfirmed`、`ho_herdr_held`、`ho_herdr_hold_error`、`HO_HERDR_CODE` | herdr（open、message）、herdr-app（open、message）、收尾流程（lib:1323、1426） |

| Pi 專屬判斷（指令內） | 位置 |
|---|---|
| 一個 worktree 一個 Pi 角色（重複兩份） | `handoff-start:86-94`、`handoff-role:73-81` |
| 實作者寫入 Pi 設定、確認 worktree 可用 | `handoff-start:95、130、153` |
| 換角色時處理 Pi 設定檔 | `handoff-role:88-113` |
| 交件單 `agent` 區塊的檢查與標籤 | `handoff-route:62、135` |
| cleanup 預覽與移除 Pi 設定檔 | `handoff-cleanup:102、161` |
| `ho_pi_role_key`（通用的 section 轉角色鍵） | lib 5 處、route 1 處、start 1 處 |

限制：`#!/usr/bin/env bash` 在這台機器上解析成 `/bin/bash` 3.2，現有程式也沒有用到 bash 4 的功能，所以新程式必須相容 bash 3.2（不用 `mapfile`、關聯陣列、`${v,,}`）。

## Goals / Non-Goals

**Goals:**
- harness 知識只有一個來源；加入新 harness 時，只需要在 harness 層加一組對應，再補測試。
- 指令只呼叫 harness 掛勾，不再自己判斷是不是 Pi。
- 外部行為完全不變：錯誤訊息、`loop.yaml` 欄位、指令選項、通知內容都和現在相同。

**Non-Goals:**
- 不加入新的 harness 或 host。
- 不拆分 lib 檔、不補齊 host 介面、不做 host 合約測試（屬於第 3 階段）。
- 不修正既有的訊息措辭。例如「送出結果不明」的訊息在 herdr-app 上也寫 `herdr did not confirm the prompt to pane`，這次只記錄，留給後續 change。

## Decisions

### D1：harness 層放在 lib 的一個獨立區塊
新增 `# --- harness` 區塊，所有 `ho_harness_*` 都放在這裡。第 3 階段拆檔時，這個區塊直接搬成 `lib/harness.sh`。
- `HANDOFF_HARNESSES="claude codex pi"`，與既有的 `HANDOFF_HOSTS` 對稱。
- 不採用「每個 harness 一個設定檔」：目前只有三個 harness，一組 `case` 最直接，而且 bash 3.2 沒有關聯陣列。

### D2：harness 層的函式
| 函式 | 回傳 | 取代 |
|---|---|---|
| `ho_harness_valid <h>` | 是否為合法 harness | lib:817 的比對 |
| `ho_override_valid <ov>` | override 格式是否正確 | start 與 role 的正規式（錯誤訊息由呼叫端照舊輸出） |
| `ho_harness_tool <h>` | 顯示名稱 `Claude Code`／`Codex`／`Pi` | `ho_author` 的 `case`（呼叫端照舊加引號） |
| `ho_harness_skill <h> <skill>` | `/skill`／`$skill`／`/skill:skill` | `ho_retool` 裡改寫 prompt 的 `case` |
| `ho_harness_argv <tf> <sec> <name>` | JSON 陣列，含程式名（現在 `ho_happ_argv` 的格式） | herdr 與 herdr-app 的兩份參數對應 |
| `ho_harness_xirp_effort_key <h>` | `effort`／`reasoning_effort`／`thinking` | `ho_xirp_create` 的 `case` |
| `ho_harness_check_trigger <h> <roles>` | doctor 的 `ok`／`fail`／`warn` 行 | doctor 迴圈裡的 `case` |
- herdr 用 bash 3.2 相容的寫法取出參數：`while IFS= read -r a; do args+=("$a"); done < <(jq -r '.[1:][]' <<<"$argv")`。
  參數不會含換行，所以逐行讀取等價。
- `ho_happ_argv` 改為直接呼叫 `ho_harness_argv`，或刪除後由呼叫端直接使用。

### D3：「送出結果不明」改成與 host 無關的名稱
| 舊 | 新 |
|---|---|
| `ho_herdr_unconfirmed` | `ho_unconfirmed_keep` |
| `ho_herdr_held` | `ho_unconfirmed_file` |
| `ho_herdr_hold_error` | `ho_unconfirmed_guard` |
| `HO_HERDR_CODE` | `HO_HOST_CODE` |
- 只改名稱與註解，不改邏輯，也不改輸出訊息（Non-Goals）。
- 機械替換後，以 `grep` 確認舊名稱完全消失。

### D4：Pi 專屬判斷收進 harness 掛勾
指令改呼叫下列掛勾；Pi 的實作仍是現有的 `ho_pi_*`，只是改由 harness 層呼叫：
| 掛勾 | Pi 的行為 | 其他 harness |
|---|---|---|
| `ho_harness_shared_worktree_error <file> <section-suffix>` | 「一個 worktree 一個 Pi 角色」：違反時印出現有的錯誤訊息並回傳 1 | — |
| `ho_harness_prepare_worktree <file> <sec> <wt>` | 寫入 `.pi/settings.json`（`ho_pi_settings`） | 不做事 |
| `ho_harness_worktree_ready <file> <sec> <wt> <main>` | `ho_pi_worktree_ready` | 回傳成功 |
| `ho_harness_role_change_files ...` | `handoff-role` 換角色時處理 Pi 設定檔的整段邏輯，原樣搬移 | 不做事 |
| `ho_harness_record_check <loop> <rec>`、`ho_harness_record_label <rec>` | 交件單 `agent` 區塊的檢查與標籤 | 不做事（label 回傳失敗，維持現狀） |
| `ho_harness_owned_files <loop> <wt>`、`ho_harness_cleanup_files <loop> <wt>` | cleanup 預覽與移除 Pi 設定檔 | 不做事 |
- 「一個 worktree 一個 Pi 角色」：start 讀 `roles.yaml` 風格的 section（`implement`），role 讀 `loop.yaml` 風格的 section（`implement_template`），所以函式接受一個 section 後綴參數。
- 移完後，`handoff-start`、`handoff-role`、`handoff-route`、`handoff-cleanup` 都不再出現 `== pi` 的判斷或 `ho_pi_` 呼叫。

### D5：`ho_pi_role_key` 改名為 `ho_role_key`
直接改名並更新所有呼叫處，不保留舊名稱的別名（只在本 repo 內部使用）。

### D6：驗證方式
- 沿用第 1 階段的方法：開始前保存完整測試的斷言名稱清單；每一步完成後比對，原有名稱必須全部存在且結果相同，只允許多出 harness 層新測試的名稱。
- harness 層新增直接測試（新區段 `harness`），以表格逐一檢查 `ho_harness_argv`、`ho_harness_skill`、`ho_harness_tool`、`ho_override_valid` 對三個 harness 的輸出。
  這些測試在函式抽出前先寫，第一次執行應因函式不存在而失敗（Red），抽出後通過（Green）。
- `grep` 檢查 proposal 的 grep 類驗收條件。

## Risks / Trade-offs

- [herdr 從 JSON 轉回 bash 陣列時，參數含空白（例如 `--name "claude - impl - x"`）被拆開] → 逐行讀取保留整行；既有測試已經檢查 `--name claude - impl - add-export` 的完整參數。
- [`handoff-role` 的 Pi 設定檔邏輯搬移時改變判斷順序] → 原樣搬移整段，不重寫；依賴既有 handoff-role 的 Pi 測試與名稱比對。
- [和第 1 階段的測試結構衝突] → 實作在 `split-handoff-tests` 合併後才開始，第一個 task 就是 rebase 到 main。

## Migration Plan

- 只改內部結構，安裝的腳本行為不變；合併後照常重新安裝即可。
- 回復：退回本 change 的 commit。

## TDD 策略與測試邊界

- 測試位置使用第 1 階段的新結構：`tests/handoff/<section>.sh`，以及 `tests/test_agent_handoff.sh` 執行器。
- 新增的 `harness` 區段：先寫表格測試（Red：函式不存在），再抽出函式（Green）。
- 其餘改動是不改變行為的重構，以 D6 的名稱比對和既有測試證明行為不變。
