# Tasks: add-mutation-check

## 1. 既有基礎（已完成）

- [x] 1.1 完成初版 mutmut／Stryker 文件查證與 design 紀錄
  - 測試要求：確認 design 有記錄當時採用的工具介面；本次 refinement 由後續 tasks 修正已發現的 drift
- [x] 1.2 先建立 `tests/test_mutation_check.sh`，涵蓋雙 skill 安裝、鏡像、frontmatter、protocol reference 與 installer 不修改目標 manifest
  - 測試要求：保留初始 Red 證據，實作後測試轉綠

## 2. 既有 Skill 主體（已完成）

- [x] 2.1 建立 `template/common/skills/mutation-check/SKILL.md` 的 setup gate、diff scope、run、report、triage 與 state 初版
  - 測試要求：`tests/test_mutation_check.sh` 對 mutation-check source 與 mirrors 通過
- [x] 2.2 建立 `template/common/skills/mutation-setup/SKILL.md` 的冪等安裝與設定初版
  - 測試要求：`tests/test_mutation_check.sh` 對 mutation-setup source 與 mirrors 通過

## 3. 既有規則與文件整合（已完成）

- [x] 3.1 將 mutation audit 保持為 TDD policy 的 optional/advisory 入口
  - 測試要求：TDD rule mirrors 一致且未加入固定 mutation score gate
- [x] 3.2 在 managed agent protocol 加入 mutation-check advisory reference
  - 測試要求：installer 後 template 與 managed protocol reference 一致

## 4. 既有安裝驗證（已完成）

- [x] 4.1 執行 skill installer 並通過既有 mutation、portable AGENTS 與 agents-directory shell tests
  - 測試要求：source 與 `.claude/`、`.agents/`、`docs/` 安裝結果一致

## 5. Refinement 測試先行

- [x] 5.1 擴充 `tests/test_mutation_check.sh`，斷言兩個 source skills 使用 Provider-neutral repository root／project-unit 契約、mutmut `source_paths` 與公開 `results` command、baseline gate、tool-specific scope、完整結果分類與分離的 scan/decision state；同時禁止 `paths_to_mutate`、`mutants/summary.json`、Claude-only root 與通用 changed-lines 估算式
  - 測試要求：先對現有 template 執行並保存預期失敗（Red）；不得為了轉綠而只放無行為意義的關鍵字
- [x] 5.2 為 docs drift 增加最小靜態 assertion：`docs/mutation-testing.md` 不得把固定 revert-check 或 mutation score 描述成採用中的完成 gate
  - 測試要求：先確認舊文件使 assertion 失敗，再進入文件修正

## 6. Skill 契約修正

- [x] 6.1 重構 `template/common/skills/mutation-setup/SKILL.md`：依 design D2–D3 解析 repository root 與 affected project unit、沿用既有 package manager／lockfile、使用 mutmut `source_paths`，並加入 Python／fork／WSL preflight；保留修改前需同意與冪等行為
  - 測試要求：執行 5.1 的 setup assertions，並以至少一個 monorepo fixture 驗證歧義時停止而非選錯 unit
- [x] 6.2 重構 `template/common/skills/mutation-check/SKILL.md` 的 setup/baseline gates 與 diff 計算；Stryker 使用 file/line mutate scope，mutmut 說明完整 source universe 並以變更模組聚焦，不再解析未公開的 internal summary 介面
  - 測試要求：執行 5.1 的 root、baseline、scope 與 stale-interface assertions；baseline fixture 失敗時不得移動 scan base
- [x] 6.3 更新 mutation report 與 triage：保留 tool 原生狀態、score 附限制，將 `last_scan_commit`、equivalent 與 deferred records 分開；補測試選項只 hand off 給既有 TDD／implementation workflow
  - 測試要求：以 fixture state 驗證 legacy `commit=` 可讀、deferred 不因 scan base 前進消失、無穩定 fingerprint 時 finding 會重新呈現

## 7. 安裝鏡像與文件

- [x] 7.1 執行 `bash scripts/skills/install.sh`，只由 template 更新 `.claude/skills/`、`.agents/skills/` 與 managed docs mirrors
  - 測試要求：`tests/test_mutation_check.sh` 全綠，且 `diff` 證明每個 installed skill 與 template source 相同
- [x] 7.2 更新 `docs/mutation-testing.md` 與 AGENTS.md 的 mutation skill 說明：補上 Provider-neutral 啟動方式、兩工具 scope 差異、baseline/result/state 契約、advisory 限制與現行官方參考；修正固定 revert-check 的舊敘述
  - 測試要求：5.2 的 docs assertion 轉綠，文件連結可解析且未宣稱固定 score/commit gate

## 8. 真實工具與 Provider Dogfood

- [x] 8.1 在具可執行 production diff 與 baseline tests 的 Python project 執行完整 mutmut 流程：setup、baseline、mutation、結果分類、至少一項 triage 與 state 重跑
  - 測試要求：必須真的執行 mutmut 並產生可檢視 mutant 結果，不得以 mock、grep 或「沒有 mutable files」代替；記錄版本、命令摘要與限制到 `dogfood-notes.md`
- [x] 8.2 在具可執行 production diff 與 baseline tests 的 TS/JS project 執行完整 Stryker 流程，驗證 file/line scope、結果分類、至少一項 triage 與 state 重跑
  - 測試要求：必須真的執行 Stryker 並產生可檢視 mutant 結果，不得只沿用 Python 證據；記錄版本、scope 與限制到 `dogfood-notes.md`
- [x] 8.3 至少以 Codex 依 skill 名稱啟動 8.1 或 8.2 的一次 dogfood，並從 repository 子目錄驗證 root resolution
  - 測試要求：`dogfood-notes.md` 記錄 Provider、起始目錄、解析後 root/project unit 與實際結果；不得依賴 Claude slash command
- [x] 8.4 根據兩個 tool runs 只修正已觀察到的契約或指令問題；若未證明 prompt-only 執行有分歧，不新增 helper script
  - 測試要求：修正後重跑受影響 dogfood 與 `tests/test_mutation_check.sh`，並在 `dogfood-notes.md` 對每項修正留下前後證據

## 9. 最終驗證與交付

- [x] 9.1 執行所有相關 shell tests、template/mirror diff、dead-reference 檢查與 `openspec validate add-mutation-check --strict`
  - 測試要求：所有命令成功，且 Git diff 只包含本 change 規格、mutation source/mirrors、測試與相關文件
- [x] 9.2 Review `dogfood-notes.md`，確認 Python、TS/JS、Codex、baseline failure、survivor triage 與 state persistence 均有證據，再交由 `openspec-commit` 同步主規格與封存
  - 測試要求：不得以 mutation score 門檻判定完成；任何未驗證的 support claim 必須降級或留為未完成 task
