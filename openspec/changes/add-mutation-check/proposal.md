# Proposal: add-mutation-check

## Why

現行 SDD + TDD 流程無法驗證測試的「有效性」——測試全綠只證明測試被執行，不證明「程式碼壞掉時測試會發現」。AI agent 同時撰寫測試與實作，特別容易產生套套邏輯測試（tautological tests）。需要一個可量化的 mutation audit 稽核測試強度。

## What Changes

- 新增 **兩個 skill**，把「設定」與「執行」拆開以利維護：
  - `template/common/skills/mutation-setup/SKILL.md`：**冪等**的環境設定 skill——套件 install/upgrade、設定值輸入（mutmut source 目錄 / Stryker init）、gitignore。所有互動與副作用集中於此
  - `template/common/skills/mutation-check/SKILL.md`：**零設定**的執行 skill——開頭 setup gate（偵測未安裝/未設定 → 提示先跑 `/mutation-setup`），其後 diff scope → run → findings 報告 → 決策選單 → watermark（比照 entropy-check）
- 在 provider-neutral TDD policy 保留 `/mutation-check` 作為 optional/advisory audit；核心
  TDD 流程、Red 證據與 Provider entrypoints 由獨立 change
  `refine-tdd-enforcement-rules` 維護
- `template/common/docs/agent-protocol.md` §4 verify 階段加一行：Level 2 程式碼變更可用 `/mutation-check` 稽核 diff 範圍的測試強度（advisory，非 DoD 硬條件）
- **不改** `scripts/skills/install.sh`（既有複製路徑已涵蓋 common skills 與 rules）
- **不改** pre-commit hooks（mutation testing 太慢；且維持既有「pre-commit 只跑測試、不設 gate」決策）
- **不由 installer 安裝套件或設定**：mutmut / Stryker 的安裝與設定由 `/mutation-setup` 執行時偵測、詢問後 bootstrap

## Capabilities

### New Capabilities
- `mutation-check`: diff-based mutation testing 整合，含兩個 skill——`mutation-setup`（冪等環境設定：install/upgrade/config）與 `mutation-check`（零設定執行：setup gate、語言偵測、scoped 執行、報告、決策選單、watermark）

### Modified Capabilities
<!-- None. TDD policy requirements are owned by refine-tdd-enforcement-rules. -->

## Impact

- 受影響檔案：`template/common/skills/mutation-setup/`（新增）、`template/common/skills/mutation-check/`（新增）、`template/common/docs/agent-protocol.md`
- TDD capability 的 provider routing 與 drift cleanup 由
  `refine-tdd-enforcement-rules` 處理，本 change 不再攜帶重疊 delta
- 安裝面：執行 `install.sh` 後傳播到各專案的 `.claude/skills/`、`.agents/skills/` 與 `docs/agent-protocol.md`
- 目標專案依賴：不強制。skill 首次執行時才詢問安裝 `mutmut`（dev dep）或 `@stryker-mutator/core`（devDependency）
- 風險：mutmut v3 與 Stryker 的 CLI/設定介面隨版本變動——SKILL.md 內指令定案前必須以 ctx7 查證現行文件
