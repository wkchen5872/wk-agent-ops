## ADDED Requirements

### Requirement: 每個語言使用一個第三方 runner 與共用 triage
系統 SHALL 依已選語言 profile 使用 `testland/qa` 的一個 mutation runner，並同時提供 `mutant-survival-triage`。對應 MUST 為：Node 使用 `stryker-mutation`、Python 使用 `mutmut-mutation`、JVM 使用 `pitest-mutation`、.NET 使用 `stryker-net-mutation`。這些 skills MUST 可由 Claude Code、Codex 與 Antigravity 在 project scope 使用。

#### Scenario: 安裝單一語言 profile
- **WHEN** 使用者安裝一個支援的語言 profile
- **THEN** 目標專案取得該語言唯一對應的 runner 與 `mutant-survival-triage`

#### Scenario: 安裝多個語言 profile
- **WHEN** 使用者一次安裝多個支援的語言 profile
- **THEN** 每個 runner 各安裝一次，且共用 triage 不重複安裝

#### Scenario: common-only 安裝
- **WHEN** 使用者未選擇任何語言 profile
- **THEN** 系統不猜測專案語言，也不安裝 mutation runner 或 triage

### Requirement: 第三方 runner 不取代本地操作政策
第三方 mutation skill SHALL 負責 runner-specific 的設定、執行與報告指引；`wk-agent-ops` managed policy MUST 仍為 package manager、lockfile、權限、Git 安全、TDD handoff、執行頻率與 score 判定的規範來源。執行第三方 skill MUST NOT 因其範例而 blind global install、建立競爭 lockfile、清除未提交變更，或未經必要同意修改專案依賴與設定。

#### Scenario: 第三方範例與專案政策衝突
- **WHEN** runner skill 建議的命令違反目標專案既有 package manager 或 Git 安全規則
- **THEN** agent 遵循本地政策並提出安全的等價步驟，不直接執行衝突命令

#### Scenario: runner 尚未設定
- **WHEN** 使用者第一次啟動語言 runner 且需要新增 dependency 或設定
- **THEN** agent 先顯示現況與副作用，依本地 consent policy 處理，而共用 installer 不代為修改 application manifest 或 lockfile

### Requirement: Mutation audit 在一般測試全綠後依階段執行
Mutation testing SHALL 是 Red、Green、Refactor 與一般測試完成後的階段性品質審查，MUST NOT 在每個 Red/Green 小步驟固定執行。模組完成時 SHALL 限定該模組，Pull Request SHALL 優先使用 changed-files 或 runner 的 incremental 能力，主分支排程 SHALL 執行完整 run，release 前 SHALL 完整執行關鍵業務模組。

#### Scenario: 日常 Red Green iteration
- **WHEN** 工程師仍在單一 focused behavior 的 Red/Green iteration
- **THEN** 只執行 focused test，不啟動 mutation testing

#### Scenario: Pull Request mutation audit
- **WHEN** 一個 change 的一般 required tests 全綠並進入 Pull Request 驗證
- **THEN** agent 使用對應 runner skill，將 mutation scope 限於 changed files 或可用的 incremental scope，並記錄實際 scope

#### Scenario: 主分支排程
- **WHEN** 主分支的排程 mutation job 執行
- **THEN** runner 對設定的完整 mutation universe 執行，而非沿用 Pull Request 的局部 scope

### Requirement: Runner 原生結果與有效性必須完整保留
Mutation report SHALL 保留 runner 可提供的 killed、survived、no coverage 或 untested、timeout、invalid、error 與 skipped 狀態，並列出 baseline test 結果、實際 scope、排除範圍與工具限制。baseline tests 失敗、runner error 或報告不完整時，本次結果 MUST 標為無效，不得換算成可採用的 score verdict。

#### Scenario: 一般測試未通過
- **WHEN** mutation 前的 baseline tests 失敗
- **THEN** mutation audit 停止或標為無效，且不更新 score baseline

#### Scenario: runner 回報多種非 killed 狀態
- **WHEN** 報告同時包含 survived、no coverage、timeout 或 error
- **THEN** 系統分別呈現各原生狀態，不合併成單一 survivor 數字

#### Scenario: runner 回報百分之百
- **WHEN** 有效 scope 的 mutation score 為 100%
- **THEN** 報告仍呈現 scope、排除項目與限制，不宣稱整個 test suite 已完整驗證

### Requirement: Survivor triage 驅動有條件的 TDD 回流
`mutant-survival-triage` SHALL 將可分析 findings 分為 `missing-case`、`weak-assertion`、`equivalent-mutant`、`unreachable` 或 `flaky-killer`，並保留 finding、分類、日期與人工理由等可追溯資訊。只有 `missing-case` 或經確認的 `weak-assertion` SHALL 回到 TDD；其他分類 MUST 依其根因處理，不得為提高 score 強寫無意義測試。

#### Scenario: missing case
- **WHEN** survivor 經確認代表未覆蓋的有效行為案例
- **THEN** finding 回到下一輪 Red，先新增因該缺口而失敗的測試，再進入 Green 與 Refactor

#### Scenario: weak assertion
- **WHEN** 現有測試執行了相關路徑但 assertion 無法辨識 mutant
- **THEN** agent 先取得能證明 assertion 弱點的 Red evidence，再強化既有 assertion；不強制建立新的測試檔

#### Scenario: equivalent mutant
- **WHEN** 人工確認 mutant 不改變可觀察行為
- **THEN** triage 記錄可重識別資訊與理由，不新增測試

#### Scenario: unreachable
- **WHEN** finding 被懷疑位於不可達程式
- **THEN** agent 先證明不可達，再優先提出刪除死程式；不得只因無 coverage 就判定 unreachable

#### Scenario: flaky killer
- **WHEN** mutant 的 killed/survived 結果受不穩定測試影響
- **THEN** 本 finding 的結果標為不可靠，先修復或隔離 flaky test 後再重跑

### Requirement: Mutation score 採 baseline 與可比較 no-regression policy
第一個有效 mutation run SHALL 建立 baseline，而非套用固定通用百分比。後續 CI score gate MUST 僅比較相同 project unit、runner 與主要版本、mutation 設定、測試命令、mutator 集合、scope 及 exclusion policy 相容的結果；可比較結果不得低於適用 baseline 或已明確設定的較高 threshold。無效或不可比較的結果 MUST 標為 `inconclusive`，不得更新 baseline 或形成 score regression verdict。

#### Scenario: 第一次有效 run
- **WHEN** project unit 尚無適用 mutation baseline 且完成有效 run
- **THEN** 系統保存該結果與比較 metadata 作為 baseline，不因低於任意固定百分比而失敗

#### Scenario: 可比較 score 下降
- **WHEN** CI 已啟用 no-regression gate，且本次有效結果與 baseline 可比較但 score 較低
- **THEN** score gate 失敗並列出下降幅度與新增 survivors，交由 triage 判定根因

#### Scenario: scope 或 runner 版本不可比較
- **WHEN** 本次結果的 scope、runner 主要版本或其他必要比較 metadata 與 baseline 不相容
- **THEN** 系統回報 `inconclusive` 並要求建立新 baseline 或執行相容 scope，不宣告 score regression

#### Scenario: 關鍵模組使用較高門檻
- **WHEN** 專案已明確為權限、交易、金額計算或其他關鍵模組設定較高 threshold
- **THEN** 有效且可比較的該模組結果使用其專屬 threshold，而非全專案初始 baseline

### Requirement: Legacy mutation skills 與人工紀錄採保守遷移
installer SHALL 精確移除自身曾安裝的 `mutation-setup` 與 `mutation-check` 目標目錄，但 MUST NOT 刪除其他 skills。既有 `.mutation-state` 中的人工 equivalent 或 deferred 理由 MUST 保留為 legacy record，除非使用者明確確認已轉存並要求清理。

#### Scenario: 重跑新版 installer
- **WHEN** 目標專案仍有 installer 產生的 legacy mutation skill 目錄
- **THEN** 只移除兩個 legacy 目錄，其他自有、第三方或使用者 skill 維持不變

#### Scenario: 目標專案有既有 mutation state
- **WHEN** migration 發現 `.mutation-state` 或 `openspec/.mutation-state`
- **THEN** installer 保留檔案並在文件中說明其 legacy 狀態，不自動刪除人工 decisions

## REMOVED Requirements

### Requirement: 兩個 mutation skill 可由支援的 Provider 使用
**Reason**: 自有 `mutation-setup` 與 `mutation-check` 由語言 runner 與共用 triage 取代。
**Migration**: 依語言改用 `stryker-mutation`、`mutmut-mutation`、`pitest-mutation` 或 `stryker-net-mutation`，並搭配 `mutant-survival-triage`。

### Requirement: 專案根目錄與 affected project unit 可可靠解析
**Reason**: runner 與 project unit 解析改由對應第三方 skill 處理，wk-agent-ops 只以明確 profile 選擇語言。
**Migration**: 安裝時選擇語言 profile；執行時依 runner skill 的專案解析流程處理。

### Requirement: mutation-setup 是經同意且冪等的設定入口
**Reason**: 自有 setup skill 退役。
**Migration**: 啟動對應語言 runner skill，並以 managed local policy 約束 dependency 與設定副作用。

### Requirement: mutation-check 具備 setup 與 baseline gates
**Reason**: 自有 check skill 退役，baseline gate 成為共用流程政策。
**Migration**: 在一般測試全綠後啟動語言 runner；無效 run 不形成 score verdict。

### Requirement: 變更範圍符合各 mutation tool 的實際能力
**Reason**: runner-specific scope 表達交由各第三方 runner skill 維護。
**Migration**: PR 使用 changed-files 或 runner incremental 能力，排程使用完整 scope，並記錄實際範圍。

### Requirement: 報告完整呈現結果語義與限制
**Reason**: 報告責任改由 runner 原生結果與共用 triage 分工，並新增 score comparability policy。
**Migration**: 保留 tool-native 狀態；只對有效且可比較結果形成 score verdict。

### Requirement: 人工 triage 可追溯且不由 watermark 吞掉
**Reason**: 自有 state/watermark 模型退役，survivor 分診改由 `mutant-survival-triage` 處理。
**Migration**: 保留既有 state 作為 legacy record；新的 findings 使用 triage skill 的輸出與本地決策紀錄。

### Requirement: mutation audit 維持 advisory 並交還 TDD 流程
**Reason**: mutation 仍是階段性審查，但 score policy 改為可在建立 baseline 後提供可比較的 CI no-regression gate。
**Migration**: 有效測試缺口仍交回 TDD；CI 僅對有效且可比較的 score 執行已啟用政策。
