# Delta Spec: tdd-enforcement-rules

## ADDED Requirements

### Requirement: Red 階段需機械化失敗證據
TDD 規則 SHALL 要求 agent 在 Red 階段實際執行測試，並在對話中呈現原始失敗輸出（失敗測試名稱與錯誤訊息或非零 exit code）。以自述（如「已確認測試失敗」）代替實際輸出 MUST 視為違反規則。

#### Scenario: Red 階段呈現失敗輸出
- **WHEN** agent 完成失敗測試的撰寫並進入 Red 確認
- **THEN** 對話中包含測試執行的原始輸出片段（失敗測試名 + 錯誤訊息或 exit code），才可進入 Green

#### Scenario: 自述失敗視為違規
- **WHEN** agent 僅以文字描述「測試已失敗」而未附執行輸出
- **THEN** 該 Red 階段視為未完成，不得進入實作

### Requirement: 完成前需 revert-check 驗證測試有效性
TDD 規則 SHALL 要求 agent 在標記 task 完成前執行 revert-check：暫時 revert 該 task 的實作（stash 或註解），確認相關測試由綠轉紅，證明測試確實守護該行為，確認後還原實作。若 revert 後測試仍為綠，該測試 MUST 視為無效並需修正。

#### Scenario: revert 後測試轉紅
- **WHEN** agent 完成實作並準備標記 task 完成
- **THEN** 暫時 revert 實作後執行測試，相關測試由綠轉紅，才可還原實作並標記完成

#### Scenario: revert 後測試仍綠視為無效
- **WHEN** revert 實作後相關測試仍全數通過
- **THEN** 該測試被判定未實際守護行為，task 不得標記完成，需修正測試

### Requirement: 存活 mutant 需 triage 後才算完成
當 `/mutation-check` 對某範圍報告存活 mutant 時，TDD 規則 SHALL 要求每個存活 mutant 被 triage（補測試殺死、標記 equivalent、或記錄理由的 skip）後，該範圍的實作才可視為完成。mutation score MUST NOT 作為自動 gate 使用。

#### Scenario: 補測試殺死 mutant
- **WHEN** 使用者對存活 mutant 選擇補測試
- **THEN** 新測試加入後重跑該 mutant 確認被殺死，才標記該項 triage 完成

#### Scenario: triage 不阻擋 commit
- **WHEN** 存在尚未 triage 的存活 mutant
- **THEN** pre-commit hook 不因此失敗；triage 屬於 advisory 追蹤，不是機械 gate

### Requirement: 規則單一來源並自動鏡像至 Antigravity
TDD 規則 SHALL 只維護單一來源 `template/common/.claude/rules/tdd-enforcement.md`。install.sh 執行後 SHALL 自動把該規則 mirror 到目標專案的 `.agents/rules/tdd-enforcement.md`，兩份內容一致，無需手動維護第二份 template 檔。

#### Scenario: install 後 Claude 與 Antigravity 規則一致
- **WHEN** 對目標專案執行 `bash scripts/skills/install.sh`
- **THEN** `.claude/rules/tdd-enforcement.md` 與 `.agents/rules/tdd-enforcement.md` 皆存在且內容相同

## REMOVED Requirements

### Requirement: TDD 規則在 GitHub Copilot CLI 可見
**Reason**: template 中從未存在 `.github/instructions/tdd-enforcement.md`，install.sh 也不複製 `.github/`；此需求自 `focus-tooling-cc-antigravity` 收斂（Claude Code + Antigravity，不 hard-bind 具名次要工具）後即為 drift。
**Migration**: TDD 規則透過單一來源 `.claude/rules/tdd-enforcement.md` 維護，由 install.sh 自動 mirror 到 `.agents/rules/`；不再提供 Copilot 專用 instructions。
