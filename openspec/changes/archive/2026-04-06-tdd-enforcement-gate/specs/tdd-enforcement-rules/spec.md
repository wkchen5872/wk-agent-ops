## ADDED Requirements

### Requirement: TDD 規則在 Claude Code session 自動載入
`template/common/.claude/rules/tdd-enforcement.md` 必須存在，讓 Claude Code 在每個 session 自動讀取 TDD 強制規則，不依賴任何 skill。

#### Scenario: Claude Code 自動載入 TDD 規則
- **WHEN** Claude Code 啟動新 session
- **THEN** `.claude/rules/tdd-enforcement.md` 的內容自動納入 context

#### Scenario: TDD 規則要求先寫失敗測試
- **WHEN** AI agent 開始實作任何 task
- **THEN** 必須先寫失敗的測試（Red），再實作讓測試通過（Green）

#### Scenario: TDD 規則要求全部測試通過才能進下一個 task
- **WHEN** AI agent 完成一個 task 的實作
- **THEN** 必須執行測試並確認全部通過，才能標記 task 完成或進行下一個 task

### Requirement: TDD 規則在 GitHub Copilot CLI 可見
`template/common/.github/instructions/tdd-enforcement.md` 必須存在，內容與 `.claude/rules/tdd-enforcement.md` 相同，讓 Copilot CLI 也能讀取。

#### Scenario: Copilot CLI 讀取 TDD 規則
- **WHEN** GitHub Copilot CLI 啟動新 session（project dir 包含 `.github/instructions/`）
- **THEN** `tdd-enforcement.md` 的內容納入 context

### Requirement: TDD 規則不依賴 skill 版本
TDD 規則 SHALL 放在 rules/ 目錄，而非任何第三方 skill 內，確保 skill 升級不影響規則。

#### Scenario: opsx skill 升級後 TDD 規則仍存在
- **WHEN** opsx 相關 skill 被重新安裝或升級
- **THEN** `.claude/rules/tdd-enforcement.md` 不受影響，規則仍然存在
