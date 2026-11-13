# Proposal

## Why

現行 change-review 強制從 PR 與 phase 開始，自帶完整檢查流程，無法直接承接「驗收這個 Change／Issue」。需要改成精簡 workflow：找關聯、調用適合的驗收技能，再將未通過的結果回覆 PR 並交給可定位的本機實作者。

## What Changes

- 以已確認的 [流程圖](../../../docs/diagrams/change-review-workflow.svg) 為行為依據。接受 OpenSpec Change 名稱、GitHub Issue URL／`#N`，保留直接指定 PR 的既有入口；先解析 repo、Change、Issue、可取得的 Work Item 與相關 PR。
- **BREAKING**：PR 不再是必要條件。無 PR 時，對選定本機版本執行 Review、驗收與測試，直接回傳報告；不為了 Review 建立 PR、Issue 或 Work Item。
- 有 PR 時讀實作差異、正文及修正／審查留言，確認 reviewed head 與可用的實作 Author 資訊，避免把未發布的本機內容算成 PR 的測試結果。
- **BREAKING**：`openspec-verify-change` 從選用改為必用。依目標選用已安裝且適合的 ponytail-review、code-review 或其他品質技能；不要求固定安裝選用插件，不重寫驗證技能的整套流程。
- 不再強制使用者每次提供 phase；依明確目的判定，通常為實作驗收，保留明確設計審查的相容路徑。無法定位 Change、關聯歧義或必要技能不可用時，說明缺口並釐清或 blocked，不假造通過。
- 有 PR 且 `changes-required`／`blocked` 時，透過 `github-pr reply` 新增精簡 Review，回讀確認；無 PR 或通過時直接回報，通過不強制發表遠端留言，除非另有要求。
- **BREAKING**：呼叫此 workflow 包含依流程發布未通過報告與通知可驗證的本機實作者；依 PR 實作 Author 的工具與 Session 線索，經本機工具核對後通知。先回覆 PR，再傳送 Review 結果、報告連結、PR 號碼／URL、版本與待修事項。不能定位時回傳可轉交訊息。
- 一次呼叫只做一輪。修正後另行觸發複驗，沿用 finding ID 並核對新版本；不自動修程式、commit、push、merge、archive 或關閉工作。

## Capabilities

### New Capabilities

- `change-review`: 以 Change／Issue／PR 為入口，協調必要驗證、選用品質審查、失敗回覆與本機實作者修正交接。

### Modified Capabilities

目前主規格沒有 `change-review`。同名能力位於尚未封存的 `add-change-review-skill`，`simplify-github-pr` 又已調整發布路徑；本 change 規劃其下一版行為，不修改那些歷史規劃。封存前必須依當時主規格調和：若上游已同步，改為對相同 capability 的完整 MODIFIED／必要 REMOVED deltas，不得留下「PR 必填」「verify 選用」等相反有效條款。

## Impact

- `template/common/skills/change-review/SKILL.md`、references 的檢查清單、案例與流程圖；installer 同步的 Claude Code／Codex 共用入口／Antigravity 副本。
- 共用 `template/common/docs/github-handoff.md` 與必要的流程說明；README、AGENTS、architecture 中的使用方式；現行 callers 與 `tests/test_change_review.sh`、受影響的 handoff 測試。
- repo 中已確認的 `docs/diagrams/change-review-workflow.svg` 是本輪設計參考；實作時更新 skill 自帶圖並避免下游依賴這張 repo-only 討論稿。
- 不改 Work Item 規範、不重構被調用的驗收技能、不安裝全域插件、不新增 session adapter／背景輪詢器，也不操作本 repo 既有 PR／Issue 作為預設驗收副作用。
- 驗收涵蓋 Change／Issue 入口、有／無 PR、verify 必用、選用技能缺少、Author 與 Session 定位、發布先於通知、回讀失敗、受測版本及單輪複驗。完整來源到報告與通知的實際產出要另外審閱，不能只靠文字存在測試。
