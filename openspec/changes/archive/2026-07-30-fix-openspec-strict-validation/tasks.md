## 1. Capture Validation Baseline

- [x] 1.1 Re-run `openspec validate --all --strict` and record the five
  currently failing canonical specs before editing. 測試要求：確認 failure
  list 只包含 `install-profile-cli`、`pre-commit-quality-gate`,
  `tdd-enforcement-rules`、`telegram-notify-hook` 與
  `template-profile-structure`。

## 2. Normalize Requirement Keywords

- [x] 2.1 Add literal `SHALL` wording to the five rejected requirements in
  `install-profile-cli` without changing conditions or outcomes. 測試要求：執行
  `openspec validate install-profile-cli --type spec --strict` 並確認通過。
- [x] 2.2 Add literal `SHALL` wording to the two rejected requirements in each
  of `pre-commit-quality-gate` and `tdd-enforcement-rules`. 測試要求：分別執行
  兩份 spec 的 strict validation 並確認通過。
- [x] 2.3 Add literal `SHALL` wording to the four rejected requirements in
  `template-profile-structure`, preserving the existing rule-removal update.
  測試要求：執行
  `openspec validate template-profile-structure --type spec --strict`
  並確認通過。

## 3. Complete Telegram Scenarios

- [x] 3.1 Add one level-four scenario to each scenario-less requirement in
  `telegram-notify-hook`: the Telegram hook behavior, Line provider
  placeholder, and notification documentation. 測試要求：執行
  `openspec validate telegram-notify-hook --type spec --strict`
  並確認通過。

## 4. Verify Documentation-Only Scope

- [x] 4.1 Review the final diff to confirm only the five canonical specs and
  task progress changed, with no archive or runtime edits. 測試要求：執行
  `git diff --check`，並確認 diff 未包含 `openspec/changes/archive/`、
  `scripts/` 或 `template/`。
- [x] 4.2 Run repository-wide strict validation after all targeted specs pass.
  測試要求：`openspec validate --all --strict` 必須以 exit code 0 完成。
