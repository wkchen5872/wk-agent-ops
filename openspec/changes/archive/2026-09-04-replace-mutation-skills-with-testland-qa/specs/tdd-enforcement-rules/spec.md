## ADDED Requirements

### Requirement: Mutation testing 接在完整 TDD iteration 之後
Managed TDD policy SHALL 將 implementation loop 表達為 Red → Green → Refactor，並將 Mutate → Triage 放在功能或階段邊界。Mutation testing MUST NOT 取代 OpenSpec acceptance criteria、預期 Red evidence、一般測試或分層驗證，也 MUST NOT 在每個 Red/Green iteration 固定執行。

#### Scenario: 從 OpenSpec scenario 開始
- **WHEN** agent 實作一項 OpenSpec acceptance scenario
- **THEN** agent 先完成該行為的 Red、Green 與 Refactor，並保持一般測試全綠，再於適用階段執行 Mutate 與 Triage

#### Scenario: 尚在 focused TDD iteration
- **WHEN** focused behavior 尚未完成或 affected tests 尚未全綠
- **THEN** agent 不啟動 mutation testing，先完成日常 TDD loop

### Requirement: Survivor 只有在確認測試缺口後回到 TDD
Managed TDD policy SHALL 依 `mutant-survival-triage` 結果決定後續流程。`missing-case` MUST 以新失敗測試重新進入 Red；`weak-assertion` MUST 以可重播的失敗證據強化 assertion；`equivalent-mutant` MUST 記錄理由；`unreachable` MUST 先證明不可達再優先刪除死程式；`flaky-killer` MUST 先修復測試穩定性。Agent MUST NOT 為了提高 score 將每個 survivor 都轉成新測試。

#### Scenario: 有效 missing case
- **WHEN** triage 確認 survivor 代表 acceptance behavior 的缺漏案例
- **THEN** agent 新增因缺口而失敗的 focused test，並重新執行 Red → Green → Refactor

#### Scenario: equivalent mutant
- **WHEN** triage 確認 mutant 不改變任何可觀察行為
- **THEN** agent 保存理由並結束該 finding，不建立無意義測試

#### Scenario: flaky killer
- **WHEN** triage 發現 mutation 結果依賴不穩定測試
- **THEN** agent 先以 TDD/除錯流程修復穩定性，再重跑適用 mutation scope

## MODIFIED Requirements

### Requirement: 額外因果稽核為條件式且 mutation score 採漸進政策
已有可信 test-first Red 時，revert-check MUST NOT 作為每個 task 的固定要求。只有缺少可信 Red、變更風險高或測試與實作的因果關係不清時，agent SHALL 使用安全的 revert-check 或等價 causal check。Mutation testing SHALL 作為階段性測試品質審查：第一個有效結果建立 baseline，不套用通用固定百分比；後續只有在專案明確啟用且結果可比較時，score no-regression 或關鍵模組 threshold MAY 成為 CI gate。未執行 mutation、尚未建立 baseline、未完成非關鍵 triage 或結果不可比較，MUST NOT 單獨阻擋 implementation completion 或 commit。

#### Scenario: 已有可信 Red
- **WHEN** 對話已保留測試因預期行為缺失而失敗的可信證據
- **THEN** agent 無需再為相同因果關係執行 revert-check

#### Scenario: 缺少可信 Red
- **WHEN** 測試晚於實作建立，或現有證據無法證明測試守護變更
- **THEN** agent 在不破壞其他工作區變更的方式下執行 revert-check 或等價 causal check

#### Scenario: Mutation audit 發現 survivor
- **WHEN** 使用者或專案流程執行 mutation audit 並發現 survivor
- **THEN** agent 先使用共用 triage 分類，再只將有效測試缺口交回 TDD

#### Scenario: 專案第一次採用 mutation score
- **WHEN** project unit 尚無有效 baseline
- **THEN** 第一個有效 run 建立 baseline，不因未達任意固定百分比而阻擋 completion 或 commit

#### Scenario: 已啟用的 no-regression gate 下降
- **WHEN** 專案已明確啟用 mutation score CI policy，且有效、可比較結果低於適用 baseline 或 threshold
- **THEN** CI gate 失敗並要求 triage 新增 findings，不以弱化測試或忽略狀態直接提高 score

#### Scenario: 結果不可比較
- **WHEN** runner、設定、測試命令、mutator、scope 或 exclusions 與 baseline 不相容
- **THEN** mutation 結果標為 `inconclusive`，不形成 score regression gate
