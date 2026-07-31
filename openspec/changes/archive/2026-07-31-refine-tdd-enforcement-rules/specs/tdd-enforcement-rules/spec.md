## ADDED Requirements

### Requirement: Provider-neutral TDD policy 為單一規範來源
共用的 TDD policy SHALL 維護於 installer 會覆寫更新的 managed operating protocol。各 Provider 的原生入口 MUST 載入或指向該 policy，而不是各自維護完整副本。

#### Scenario: Codex 透過共用入口取得規範
- **WHEN** agent 讀取專案根目錄的 `AGENTS.md`
- **THEN** 該入口要求 agent 在實作前讀取 managed operating protocol 的 TDD policy

#### Scenario: Claude 與 Antigravity 使用相同薄入口
- **WHEN** installer 把 template 安裝到目標 repository
- **THEN** Claude 與 Antigravity 的 TDD rule 皆存在、內容相同，並指向同一份 managed operating protocol

### Requirement: 正式 TDD 依工作類型而非 task 數量套用
所有行為變更與 bug fix SHALL 使用 test-first 流程，不因 diff 小或 task 被標為 Level 1 而豁免。純文件、生成檔、無行為變化的設定同步與探索性工作 MAY 不使用正式 TDD，但 MUST 執行與變更相稱的替代驗證。

#### Scenario: 行為變更使用 test-first
- **WHEN** task 新增或修改可觀察行為，或修正 bug
- **THEN** agent 在實作前先建立能描述預期行為的失敗測試

#### Scenario: 非行為變更使用替代驗證
- **WHEN** task 只修改文件、生成檔或無行為變化的設定同步
- **THEN** agent 可不建立失敗測試，但需執行 relevant validation 並記錄結果

#### Scenario: 無法合理自動化的行為
- **WHEN** UI、外部整合或非確定性行為無法合理建立自動化測試
- **THEN** task 在實作前記錄原因與可重播的 acceptance evidence，再依該 evidence 驗證

### Requirement: Red 證據需證明預期行為尚未成立
Red 階段 MUST 實際執行 focused test，並記錄 command、失敗測試名稱、非零 exit code、預期失敗原因與經清理的最小輸出。setup error、syntax error、無關失敗或未清理的完整輸出 MUST NOT 視為有效 Red。

#### Scenario: Red 因預期原因失敗
- **WHEN** focused test 因目標行為尚未實作而失敗
- **THEN** agent 可在呈現最小且不含敏感資訊的失敗證據後進入 Green

#### Scenario: Red 因測試環境錯誤失敗
- **WHEN** test command 因 syntax、fixture、dependency 或 setup error 結束
- **THEN** agent 修正測試環境並重跑，直到測試因預期行為原因失敗

#### Scenario: 新測試直接通過
- **WHEN** 新測試第一次執行即通過
- **THEN** agent 不得把它當成 Red，必須確認行為已存在或修正測試使其能證明缺少的行為

### Requirement: Green 不得破壞測試完整性
Agent MUST 以最小實作讓有效 Red 轉綠，且 MUST NOT 透過弱化 assertion、跳過、刪除或改寫需求測試來取得 Green。

#### Scenario: 實作使原測試通過
- **WHEN** agent 進入 Green
- **THEN** 原本因預期原因失敗的測試保持原意並因 production behavior 完成而通過

#### Scenario: 測試本身確實錯誤
- **WHEN** 實作過程發現測試與已核准 spec 或 acceptance criteria 衝突
- **THEN** agent 先更新 change artifact 或取得使用者確認，再修正測試

### Requirement: 驗證依 feedback loop 分層執行
Agent SHALL 在 Red/Green iteration 執行 focused test，在 task 邊界執行 affected suite，並在 seal 或 commit 前執行專案定義的完整 required checks。規範 MUST 使用專案原生驗證命令，不得限制於特定語言或 test runner。

#### Scenario: Red Green iteration
- **WHEN** agent 正在進行單一行為的 Red/Green iteration
- **THEN** 先執行能提供快速回饋的 focused test

#### Scenario: Task 邊界
- **WHEN** agent 準備標記行為變更 task 完成
- **THEN** focused test 與受變更影響的 test suite 皆通過

#### Scenario: Seal 或 commit
- **WHEN** change 準備 seal、archive 或 commit
- **THEN** agent 執行 AGENTS、CI 或專案 manifest 定義的完整 required checks

### Requirement: 額外因果稽核為條件式且不成為通用 gate
已有可信 test-first Red 時，revert-check MUST NOT 作為每個 task 的固定要求。只有缺少可信 Red、變更風險高或測試與實作的因果關係不清時，agent SHALL 使用安全的 revert-check 或等價 causal check。Mutation testing MAY 作為 advisory audit，但其 score 或未完成 triage MUST NOT 阻擋 implementation completion 或 commit。

#### Scenario: 已有可信 Red
- **WHEN** 對話已保留測試因預期行為缺失而失敗的可信證據
- **THEN** agent 無需再為相同因果關係執行 revert-check

#### Scenario: 缺少可信 Red
- **WHEN** 測試晚於實作建立，或現有證據無法證明測試守護變更
- **THEN** agent 在不破壞其他工作區變更的方式下執行 revert-check 或等價 causal check

#### Scenario: Mutation audit 發現 survivor
- **WHEN** 使用者選擇執行 mutation audit 並發現 survivor
- **THEN** agent 報告 survivor 與 triage 選項，但不以固定 score 或未完成 triage 阻擋 commit

## MODIFIED Requirements

### Requirement: TDD 規則在 Claude Code session 自動載入
`template/common/.claude/rules/tdd-enforcement.md` SHALL 作為 Claude Code 的薄入口，在 session 中要求實作工作讀取 managed operating protocol 的 TDD policy，而不複製完整政策內容。

#### Scenario: Claude Code 自動載入 TDD 入口
- **WHEN** Claude Code 啟動新 session
- **THEN** `.claude/rules/tdd-enforcement.md` 自動納入 context，並要求讀取 managed TDD policy

#### Scenario: Claude 開始行為變更
- **WHEN** Claude Code agent 開始實作行為變更或 bug fix
- **THEN** agent 依 managed TDD policy 執行 test-first 與分層驗證

### Requirement: TDD 規則不依賴 skill 版本
TDD policy SHALL 存在於 project-owned 或 managed operating instructions，不得放入會被第三方升級替換的 skill。Provider-specific rule 只能作為載入該 policy 的薄入口。

#### Scenario: 第三方 skill 升級後規範仍存在
- **WHEN** opsx 或其他第三方 skill 被重新安裝或升級
- **THEN** managed TDD policy 與 Provider 入口不受該 skill 內容變動影響

## REMOVED Requirements

### Requirement: TDD 規則在 GitHub Copilot CLI 可見
**Reason**: 此 repository 沒有對應 template 或 installer 路徑，且跨工具政策已改由 `AGENTS.md` 與 managed operating protocol 提供。
**Migration**: AGENTS.md-aware 工具讀取 managed policy；Claude 與 Antigravity 另外透過各自的原生 rule 入口載入相同政策。
