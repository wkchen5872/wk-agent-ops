# Spec: mutation-check

## Purpose

提供跨 AI Provider、依 mutation tool 實際能力運作的測試有效性稽核，使團隊能在不建立固定分數 gate 的前提下，發現、追蹤並人工判定變更程式碼中的測試缺口。

## Requirements

### Requirement: 兩個 mutation skill 可由支援的 Provider 使用
系統 SHALL 提供 `mutation-setup` 與 `mutation-check` 兩個 skill，並由既有 installer 將相同內容安裝到支援的 Provider 目錄。skill 的必要行為 MUST NOT 依賴 Claude Code 專屬 slash command 或 hook；slash command 只能作為 Provider-specific 使用範例。

#### Scenario: 安裝兩個 skill
- **WHEN** 使用者對目標專案執行共用 skill installer
- **THEN** `mutation-setup` 與 `mutation-check` 會出現在 `.claude/skills/` 與 `.agents/skills/`，且各自與 template source 一致

#### Scenario: 非 Claude Provider 啟動稽核
- **WHEN** 使用者在 Codex 或其他支援 skills 的 Provider 中依名稱要求執行 `mutation-check`
- **THEN** Agent 能執行相同稽核流程，而不要求 `/mutation-check` slash command 存在

### Requirement: 專案根目錄與 affected project unit 可可靠解析
兩個 skill SHALL 先解析 Git repository root，再從變更檔案與 manifest 判定 affected Python 或 TS/JS project unit。若 monorepo 中存在多個合理 project unit 且無法唯一判定，skill MUST 在安裝、修改設定或執行 mutation 前請使用者選擇。

#### Scenario: 從子目錄啟動
- **WHEN** Agent 在 repository 子目錄中執行任一 mutation skill
- **THEN** skill 以該 Git repository root 為操作邊界，而非把目前子目錄誤判為專案根目錄

#### Scenario: monorepo 目標不明
- **WHEN** 變更檔案分布在多個具有相同語言 manifest 的 project unit，且無法唯一選定目標
- **THEN** skill 列出候選 project unit 並等待使用者選擇，未選擇前不修改設定也不執行 mutation

#### Scenario: 沒有支援的 project unit
- **WHEN** affected area 中找不到 Python 或 TS/JS manifest
- **THEN** skill 中止並說明目前只支援 mutmut 與 Stryker 對應的專案

### Requirement: mutation-setup 是經同意且冪等的設定入口
`mutation-setup` SHALL 集中處理 mutation tool 的安裝、升級與設定副作用，並沿用目標 project unit 既有的 package manager、dependency declaration 與 lockfile。所有修改 MUST 先顯示現況與預定動作並取得使用者同意；重跑時 MUST NOT 盲目覆蓋有效設定，也 MUST NOT 以 global install 作為未確認的 fallback。共用 installer MUST NOT 修改目標專案的 manifest 或 mutation tool 設定。

#### Scenario: 已有設定時重跑 setup
- **WHEN** project unit 已安裝並設定 mutation tool，使用者再次執行 `mutation-setup`
- **THEN** skill 顯示目前版本與設定並提供保留或更新選擇，未經同意不寫入檔案

#### Scenario: 沿用既有 package manager
- **WHEN** project unit 的 manifest 或 lockfile 表明既有 package manager
- **THEN** setup 使用該 manager 增加或升級開發依賴，且不另外建立競爭的 lockfile

#### Scenario: 執行環境不符合工具前提
- **WHEN** Python 版本、作業系統或執行能力不符合目前 mutmut 的支援條件
- **THEN** setup 在安裝或執行前停止，列出不符合項目與可行環境選項，不嘗試不受支援的 fallback

#### Scenario: 共用 installer 不碰專案依賴
- **WHEN** 使用者只執行共用 skill installer
- **THEN** 目標專案的 manifest、lockfile 與 mutation 設定檔不會被建立或修改

### Requirement: mutation-check 具備 setup 與 baseline gates
`mutation-check` SHALL 在 mutation run 前確認 tool 與設定就緒，並執行 affected project unit 的既有 baseline tests。setup 未完成時 MUST 導向 `mutation-setup`；baseline tests 失敗時 MUST 將本次稽核標為無效並停止，不得產生可被誤解為有效的 mutation score。

#### Scenario: setup 尚未完成
- **WHEN** mutation tool 或必要設定缺失
- **THEN** check 不自行安裝，改為依目前 Provider 可用方式建議執行 `mutation-setup`

#### Scenario: baseline tests 失敗
- **WHEN** mutation 前的既有測試命令失敗
- **THEN** check 停止 mutation run、回報 baseline failure，且不更新掃描基準

#### Scenario: baseline tests 通過
- **WHEN** mutation tool、設定與 baseline tests 均就緒
- **THEN** check 進入變更範圍計算與 mutation run

### Requirement: 變更範圍符合各 mutation tool 的實際能力
`mutation-check` SHALL 從未提交 diff、feature branch merge-base 或 default branch 上次掃描基準取得變更檔案，排除測試檔，再依工具能力執行。Stryker SHALL 使用其支援的 file 或 line mutate scope；mutmut SHALL 以 project unit 設定的 source universe 產生與快取 mutants，再用變更模組聚焦重跑、檢視與報告。系統 MUST NOT 宣稱 mutmut 只產生變更檔案的 mutants。

#### Scenario: Stryker 有精準變更範圍
- **WHEN** affected project unit 使用 Stryker 且只有部分 production files 或行被修改
- **THEN** run 的 mutate scope 限定在可表達的變更 files 或 line ranges

#### Scenario: mutmut 聚焦變更模組
- **WHEN** affected project unit 使用 mutmut
- **THEN** check 說明設定的完整 mutation universe，並將變更模組用於重跑、檢視與 findings 篩選，而不把它描述成 file-level mutant generation

#### Scenario: 成本預估
- **WHEN** 預期 run 成本可能偏高
- **THEN** check 使用工具可得的 mutant 數量、快取狀態或 scope 資訊提出警告，不套用跨工具共用的固定「變更行數乘係數」公式

### Requirement: 報告完整呈現結果語義與限制
`mutation-check` SHALL 依 tool 實際輸出呈現 killed、survived、no coverage 或 untested、timeout、invalid、error 或 skipped 等可得分類，並清楚區分有效結果與執行失敗。tool 提供的 mutation score MAY 顯示為摘要，但 MUST NOT 被解讀為固定品質門檻或完整測試有效性的證明。

#### Scenario: run 含多種非 killed 狀態
- **WHEN** tool 回報 survived、no coverage、timeout 或 error 類結果
- **THEN** 報告分別列出可取得的類別與數量，不把它們合併成單一 survivor 數字

#### Scenario: tool 回報百分之百 score
- **WHEN** tool 回報 mutation score 為 100%
- **THEN** 報告仍列出 baseline、實際 scope、未納入範圍與工具限制，且不自動宣稱整體 test suite 有效

#### Scenario: mutation 執行失敗
- **WHEN** tool 因設定、測試 runner 或 runtime error 無法完成
- **THEN** check 將本次結果標為無效、保留診斷資訊，且不把失敗換算成 score

### Requirement: 人工 triage 可追溯且不由 watermark 吞掉
`mutation-check` SHALL 將掃描基準與 finding decisions 分開保存。equivalent 與 deferred decisions MUST 記錄可重識別 finding 的資訊、日期與人工理由；deferred 或尚未判定的 finding MUST NOT 因掃描基準前進而靜默消失。若 finding 無法穩定重識別，check MUST 再次呈現而非推測匹配。

#### Scenario: 標記 equivalent
- **WHEN** 使用者確認某 finding 為 equivalent 並提供理由
- **THEN** check 保存理由與識別資訊，後續匹配時在摘要中列為已排除而非一般 survivor

#### Scenario: 延後處理 finding
- **WHEN** 使用者選擇 defer 或 skip 並提供理由
- **THEN** check 保存為未解決 finding，後續適用範圍的稽核仍會顯示，直到使用者明確解決或重新分類

#### Scenario: finding 無穩定識別資訊
- **WHEN** tool 輸出不足以可靠對應既有 equivalent 或 deferred record
- **THEN** check 將 finding 當作需要重新 triage 的項目呈現

### Requirement: mutation audit 維持 advisory 並交還 TDD 流程
`mutation-check` MUST NOT 建立固定 score gate、阻擋 commit、直接宣告 OpenSpec task 失敗，或自行修改 production code 與 tests。對可行動的 finding，check SHALL 說明測試缺口並讓使用者選擇交由既有 TDD／implementation workflow 處理、標記 equivalent 或 defer。

#### Scenario: 發現 surviving mutant
- **WHEN** 有可行動的 surviving mutant
- **THEN** check 提供 finding、測試方向與三種人工選擇，但不自行寫測試或阻擋提交

#### Scenario: 使用者選擇補測試
- **WHEN** 使用者選擇處理某項測試缺口
- **THEN** check 將該 finding 交還適用的 TDD／implementation workflow，而不把 mutation audit 本身當成實作流程
