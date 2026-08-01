# Design: add-mutation-check

## Context

本 change 已完成兩個 skill、安裝鏡像與靜態測試，但尚未完成真實 mutation dogfood。重新檢驗時發現既有設計把 mutmut 與 Stryker 的 scope 能力視為相同，並引用已不適用的 mutmut 設定與結果介面；root resolution、baseline validity 與 deferred state 也仍偏向單一 Provider。動機見 `proposal.md`，行為契約見 `specs/mutation-check/spec.md`。

目前介面依據：

- [mutmut 官方 repository](https://github.com/boxed/mutmut)：現行設定使用 `source_paths`，主要操作為 `mutmut run`、`mutmut browse` 與 `mutmut apply`；執行環境需具備 fork 能力，Windows 應使用 WSL。
- [StrykerJS 官方 configuration reference](https://stryker-mutator.io/docs/stryker-js/configuration/)：`mutate` 支援 file/line scope，incremental 與 force 可控制快取重用及重跑。

## Goals / Non-Goals

**Goals:**

- 讓兩個既有 skill 在 Claude Code、Codex 與其他支援 skills 的 Provider 中遵循同一份行為契約。
- 對 mutmut 與 Stryker 使用各自真實可提供的 scope、結果與成本資訊。
- 讓每次報告的 baseline、scope、結果分類與人工 decision 可追溯。
- 以最小靜態測試加兩個真實 tool runs 驗證文件式 skill。

**Non-Goals:**

- 不新增 mutation runtime wrapper、通用結果 parser 或新的 dependency。
- 不支援 Bash mutation、全 repository 排程、固定 score gate 或 CI 強制門檻。
- 不讓 `mutation-check` 自己進入實作或修改測試；它只產生 audit finding。
- 不保證不同 mutation tools 的 score 可以直接比較。

## Decisions

### D1: 保留 setup/check 分工，不先新增 helper script

`mutation-setup` 保有安裝、升級與設定等低頻互動副作用；`mutation-check` 只做 setup gate、baseline、scope、run、report 與 state。兩者仍以 SKILL.md 表達，沿用現有 installer。

只有在 Python 與 TS/JS dogfood 證明不同 Provider 對同一段 deterministic 操作產生不可接受的分歧時，才抽出最小 helper。現階段先修正單一 template source，避免在沒有失敗證據前同時維護 prompt 與 runtime。

### D2: 先解析 repository root，再選 affected project unit

root resolution 順序為：使用者明示 target、`git rev-parse --show-toplevel`、Provider 提供的 project directory，最後才是 `PWD`。這避免從子目錄啟動或切換 Provider 時改到不同位置。

語言與工具不只看 repository root：依 changed production files 向上尋找最近 manifest/config，形成 affected project units。只有一個候選時自動選定；多個候選或同一檔案可歸屬多個 unit 時詢問使用者。

### D3: setup 沿用專案既有 dependency 管理與工具限制

Python setup 使用 project 已採用的 manager 與 lockfile；JavaScript setup同樣沿用既有 npm-compatible manager。找不到明確 manager 時先提供選項，不使用 global `pip install` 或產生第二份 lockfile。

mutmut 設定以現行 `source_paths` 為核心，必要時再設定 test selection arguments；若 project 只有 legacy `setup.py`，setup 先詢問要使用既有 `setup.cfg` 或建立 `pyproject.toml`，不自行猜測。安裝前檢查目前 mutmut 所需的 Python 版本與 fork-capable environment，Windows 原生環境則提示 WSL。Dogfood 顯示 mutmut 會留下 `mutants/` 測試副本，因此 setup 亦需 gitignore 該目錄，baseline command 則必須限定真實 tests path 或排除該目錄。

### D4: diff 決定 audit focus，不假裝兩個工具具有相同 generation scope

共同 diff base 維持三種來源：dirty worktree 相對 HEAD、feature branch 相對 default branch merge-base、default branch 相對 `last_scan_commit`。再將變更檔映射至 D2 的 project units，排除 tests。

- Stryker：以 `--mutate` 傳入 changed files 或可安全計算的 line ranges；需要重跑時使用現行 incremental/force 能力。
- mutmut：`source_paths` 是 mutant generation universe。先沿用工具生成與快取，再以 changed modules 對工具支援的 mutant/module selector 聚焦重跑和檢視；dogfood 已確認 mutmut 3.7.0 的公開 `run`、`results`、`show`、`browse` commands，但不得解析未公開保證的 `mutants/summary.json`。

成本提示優先使用 tool 已產生的 mutant 數、快取狀態與實際 scope；沒有可靠數據時只說明未知，不使用 `changed_lines × 1.5` 之類跨工具固定公式。

### D5: baseline 與結果有效性先於 score

每個 affected project unit 先執行既有 unit-test command。無法辨認命令時詢問使用者；baseline failure 直接終止該 unit 的 mutation run，也不移動 scan base。

run 完成後保留 tool 原生語義：killed、survived、no coverage/untested、timeout、invalid/error/skipped 等有什麼就報什麼。tool 提供的 score 可原樣附上，但不自行跨工具重算統一 score。即使顯示 100%，摘要仍列出實際 scope、排除項與未驗證限制。

### D6: scan base 與人工 decisions 使用同一個簡單狀態檔、不同 record

狀態位置仍為 `openspec/.mutation-state`，無 `openspec/` 時使用 repository root 的 `.mutation-state`。沿用 line-oriented 格式，避免新增 parser dependency：

```text
last_scan_commit=<sha>
equivalent=<fingerprint>\t<date>\t<reason>
deferred=<fingerprint>\t<date>\t<reason>
```

fingerprint 由 tool、project unit、檔案、位置、mutator 與 mutation description 的可得欄位組成；缺少穩定欄位時不抑制 finding。讀取時相容既有 `commit=<sha>`，下次成功 run 再寫成 `last_scan_commit`。scan base 前進只影響 diff 選擇，不刪除 equivalent/deferred records。

### D7: triage 只做分類與 handoff

報告先呈現 conditional、boundary、return-value 等高風險 survivors，再呈現其他結果。使用者可：

1. 將測試缺口交還目前 implementation/TDD workflow；
2. 以人工理由標記 equivalent；
3. 以理由 defer，保留為未解決 finding。

這裡不直接補測試，避免把 advisory audit 變成繞過 OpenSpec/TDD ownership 的第二套實作入口。

### D8: 驗收必須跨 tool，並至少跨一個 Provider

靜態 shell test 負責 template/install mirror、frontmatter、禁用過時字串、Provider-neutral root 與 state 契約。行為驗收另執行兩次可重播 dogfood：

- Python project：通過 baseline，對真實 production diff 執行 mutmut，取得至少一項可 triage 結果並驗證 state。
- TS/JS project：通過 baseline，對真實 production diff 執行 Stryker file/line scope，取得至少一項可 triage 結果並驗證 state。

至少一次從 Codex 依 skill 名稱啟動，用來驗證非 slash-command entrypoint 與 root resolution。輸出、環境、版本、限制與 decision 記錄在 `dogfood-notes.md`；不要求固定 score。

## TDD Strategy and Test Boundary

先擴充 `tests/test_mutation_check.sh`，讓舊 template 因過時的 `paths_to_mutate`、undocumented `summary.json`、Claude-only root 與通用成本公式而失敗，並要求 dogfood 驗證過的公開 `results` command；再最小修改兩個 source skills、安裝鏡像與 playbook 使其通過。靜態測試只能驗證契約文字與鏡像，不能取代 D8 的兩個真實 tool runs。

## Risks / Trade-offs

- [mutmut selector 或輸出再變動] → skill 描述意圖並使用現行官方介面；改版時重新查官方文件與 dogfood。
- [monorepo 自動判定錯誤] → 唯一候選才自動執行，有歧義即詢問。
- [fingerprint 因程式碼位移失配] → 無法可靠匹配時重新呈現，不靜默排除。
- [mutation run 成本過高] → 先顯示可得 scope/cost，允許縮小或中止；不新增猜測性排程系統。
- [兩個真實工具增加驗收時間] → 這是宣稱同時支援 Python 與 TS/JS 的最低證據，保留為人工 dogfood 而非每次 pre-commit gate。

## Migration Plan

1. 先更新 template 與靜態契約測試，再執行 installer 更新本 repository 的 mirrors。
2. 舊 `.mutation-state` 的 `commit=` 在讀取時視為 legacy scan base；首次成功 run 後改寫為新格式並保留 decisions。
3. 完成兩個 tool dogfood 與 Codex entrypoint 驗收後，更新 playbook 並重新 strict validate。
4. 若新流程無法運作，可還原 template/mirrors；目標專案的 mutation dependency 與 config 僅由使用者在 setup 中同意後產生，不由 rollback 自動刪除。
