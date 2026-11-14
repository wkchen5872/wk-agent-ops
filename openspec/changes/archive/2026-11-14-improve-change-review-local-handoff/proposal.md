# Proposal

## Why

使用者已確認本機開發四個流程，前兩階段在發布前保留人工確認，因此 Review 經常先於 PR 發生。現有 `change-review` 能執行本地驗收，但執行前提示、本地報告保存、明確授權的本機修正交接，以及後補 PR 的版本核對仍需更清楚，避免遺失報告或把本地結果誤認為遠端版本已通過。

## What Changes

- 保留 `change-review` 名稱、單輪審查與既有設計／實作驗收能力，不另建 workflow。
- 在檢查開始前交代目標、版本、PR 查詢結果及報告去向；確認沒有 PR 與查詢不明分開呈現，不把提示變成額外批准關卡。
- 銜接既有 Work Item 規範，保存本地報告、受審範圍與必要快照指紋；沒有既有紀錄仍可完成 Review，不另建永久追蹤系統。
- 預設無 PR 不通知；使用者明確要求交回某實作者時，允許以已保存的本地報告及版本證據交接，仍核對原實作者與 Session mapping。
- 補建 PR 後，只有明確要求發布報告才執行；先核對受審內容與當前 PR，差異未驗證時不得轉成該 head 的 pass。
- 精簡 Skill 內重複的格式規則，繼續引用既有共用契約，不變更團隊貼文 schema。

驗收條件：既有 PR Review／三種 verdict／複審均不退化；無 PR 可完成且有可辨識的報告；預設不通知；明確授權的本機交接只送已核對的實作者；舊本地 pass 不自動套到新 PR head。靜態測試、離線重播與真實寫入分別記錄。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `change-review`：補強本地模式提示、證據保存、明確授權的本機交接與延後發布的版本判斷。

## Impact

- 來源：`template/common/skills/change-review/`，包含 SKILL、checklists、acceptance cases 與必要的 review-loop 圖。
- 測試：`tests/test_change_review.sh`；共用契約與 installer 回歸使用 `tests/test_github_handoff.sh`。
- 安裝：依 repo 規範從 template 經 installer 同步，不直接修改安裝副本。
- 不改 github-issue／github-pr 的操作範圍，不建立 PR、不修改產品、不 commit／push，不新增自動修正或輪詢。
- 與 `extend-openspec-commit-delivery` 可獨立實作；本 Change 不擁有四張總流程圖移入 docs 的工作。
- 本階段僅建立本地規劃。待使用者檢查確認，再依 github-issue 規範建立 Issue；這不是已發布或已批准實作的證據。
