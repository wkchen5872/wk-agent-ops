## Why

`template/common/docs/conventions.md` ships JS-specific defaults (`camelCase`, `kebab-case` 檔名、`JSDoc`、禁止 `console.log`)，但它透過 `install.sh` 一次性裝進**所有** profile，包括 python。python profile 同時又裝上 `pytest_testing_style_guide.md`（要求 `snake_case`、bare assert）。結果 Python 專案安裝完，AI agent 第一天就讀到兩份互相矛盾的風格來源。

## What Changes

- 改寫 `template/common/docs/conventions.md`，從「JS 寫死」變為「依語言慣例（language-agnostic）」：
  - **Naming Conventions**：改為小型對照表（Python `snake_case` / JS-TS `camelCase`；classes 皆 `PascalCase`；constants 皆 `UPPER_SNAKE_CASE`；files Python `snake_case` / JS-TS `kebab-case`），並加一句「遵循該語言慣例，勿硬套他語言風格」。
  - **Prohibited Patterns**：`console.log` 改為語言中立「禁止 production code 留除錯輸出（Python `print` / JS `console.log`），改用 logger」。其餘兩條（no hardcoded secrets、no logic-heavy constructors）本就通用，保留。
  - **Error Handling**：`null/undefined` → `null/None/undefined`，其餘保留。
  - **Documentation**：`JSDoc/Docstrings` → 「Docstrings（Python）/ JSDoc（JS-TS）」，「Why not What」保留。
- 保留檔頂「客製起點範本」定位語句。
- 範圍嚴格限定此單一檔案。

## Capabilities

### New Capabilities
- `template-conventions-doc`: 規範 `template/common/docs/` 內隨所有 profile 出貨的 conventions 範本必須語言中立，不得與任何 profile 的語言專屬 rule 矛盾。

### Modified Capabilities
<!-- 無既有 spec 變更（openspec/specs/ 目前為空） -->

## Impact

- 變更檔案：`template/common/docs/conventions.md`（唯一）。
- 行為影響：僅影響**全新**安裝（`install.sh` docs 走 `rsync --ignore-existing`），不覆蓋既有專案已客製的 `docs/conventions.md`。
- 不影響：git-commit-writer（模型版號標記為刻意設計，排除）、supabase-migrations、.github 鏡像。
- 參照（不改）：`template/python/.claude/rules/pytest_testing_style_guide.md`、`scripts/skills/install.sh`。
