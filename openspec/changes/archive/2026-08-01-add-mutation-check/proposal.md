# Proposal: add-mutation-check

## Why

AI coding 能力提升並不會自動保證 AI 產生的測試具有守護力；mutation testing 仍適合用來檢查「實作被刻意破壞時，測試能否察覺」。但此 active change 的既有草案混用了過時的 mutmut v3 介面、把 Python scope 誤寫成與 Stryker 相同的精準檔案範圍，且未充分處理跨 Provider 執行、baseline 失敗、非存活結果與 deferred finding。若直接依原 tasks 完成 dogfood，可能驗證錯誤的契約。

## What Changes

- 保留 `mutation-setup` 與 `mutation-check` 兩個 skill：前者集中互動與專案設定副作用，後者提供可重複執行的 advisory audit。
- 將啟動方式與專案根目錄解析改為 Provider-neutral；`/mutation-check` 僅作 Claude Code 範例，不作跨 Provider 前提。
- 依工具能力分開定義 scope：Stryker 使用 file/line mutate scope；mutmut 以設定的 `source_paths` 產生 mutants，再以變更模組聚焦重跑與檢視，不宣稱只產生變更檔案的 mutants。
- 修正 mutmut 現行設定與查詢介面，並要求 setup 尊重既有 package manager、lockfile、monorepo project unit、Python 版本與平台限制。
- mutation run 前要求 baseline tests 通過；報告區分 killed、survived、no coverage、timeout、invalid/error/skipped 等工具實際提供的狀態，mutation score 僅作次要資訊。
- 將掃描基準與人工判定分開保存：equivalent 與 deferred findings 必須附理由，不能因 watermark 前進而靜默消失。
- 保持 advisory：不加入固定 score、commit 或 CI gate；audit 只回報測試缺口並交還既有 TDD／實作流程處理。
- 完成前必須分別以真實 Python/mutmut 與 TS/JS/Stryker diff dogfood，且至少一次由非 Claude Provider（Codex）執行。

## Capabilities

### New Capabilities

- `mutation-check`: Provider-neutral、tool-aware 的 diff-focused mutation audit，包含冪等環境設定、baseline gate、結構化結果、可追溯 triage state，以及 Python 與 TS/JS 的實際驗收。

### Modified Capabilities

<!-- None. This active change has not yet been archived into the main specs. -->

## Impact

- 主要影響 `template/common/skills/mutation-setup/`、`template/common/skills/mutation-check/`、對應安裝鏡像、`tests/test_mutation_check.sh` 與 `docs/mutation-testing.md`。
- `scripts/skills/install.sh` 沿用既有 generic skill 複製機制，不新增專用 installer 邏輯。
- 目標專案只在使用者執行 setup 並同意後才修改開發依賴或 mutation 設定。
- 既有 TDD policy 僅保留 optional/advisory 入口；mutation score 不成為完成條件。
