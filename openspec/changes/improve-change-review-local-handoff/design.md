# Design

## Context

動機見 [proposal.md](proposal.md)。現有 `change-review` 的七步流程已具備目標解析、版本固定、必用 verify、選用品質檢查、報告、PR 回讀與實作者交接；本次沿用其架構。

目前 Step 2 的無 PR 分支只明列 HEAD 與未提交路徑，Step 5 直接回傳本地報告，Step 6 只在已確認 PR 回覆後通知。`work-items/AGENTS.md` 已定義本地 Review 紀錄，契約第 6.4 節已有快照欄位，因此不建立新報告 schema 或永久 registry。原規格「Review execution is bounded and preserves scope」的 pass scenario 尚寫僅在使用者要求時發布，與後來的遠端 pass 預設發布規則不一致，本次對齊而不改變既有操作。

## Goals / Non-Goals

**Goals**：讓執行模式及報告去向在開始時可預期，本地結果可保存／複審，且延後發布不混淆版本與來源。

**Non-Goals**：不改名、不增加 workflow、PR create／push、不改團隊格式、預設本機通知、監看循環或四張總流程圖的 docs 遷移。

## Decisions

### 1. 在既有步驟補銜接，不拆分更多 Skills

Step 1–2 完成解析後，在必要檢查前簡短宣告 Change、目的、受審版本、PR 狀態與報告去向。無 PR 正常進行；查詢 unknown 保留限制。除必要歧義外，這是狀態提示，不要求使用者再次批准本已授權的 Review。

### 2. 本地報告依既有 Work Item 規範保存

沿用同工作且當前目錄內的 Work Item；沒有時依現有規範處理紀錄，不先把 Work Item 當成驗收 prerequisite，不跨 worktree 尋回歷史。不強制另建 tracker、持久 cache 或 manifest 服務。

含未提交內容時，記錄實際 included staged／unstaged／untracked 清單、比較基準與內容指紋及算法，排除範圍明示。實作可使用本地隔離快照或逐檔 digest，重點是能核對受審 bytes。Skill source 的指紋與產品快照分開。收尾再檢查版本是否移動；變動時保留原結論範圍，不能聲稱新版本已通過。

### 3. 本地通知是明確授權的例外

預設無 PR 不通知。只有使用者明確指定交回實作者、報告已保存且可讀，才以本機路徑、快照、Finding ID 與下一步交接。需核對工具、專案、原生 ID 與管理 ID，不從代發者資訊猜實作者。定位失敗回傳可轉交訊息。

local-only 的「不發文、不通知」限制保留；若同一次要求互相矛盾，釐清受限制動作，其他 Review 可繼續。PR 模式仍先確認發布及回讀；不得以本地交接繞過 PR 發布被拒、逾時或 readback 未確認。

### 4. 延後發布是既有 reply 的使用情境

不新增 publish 操作或自動補貼。使用者後續要求發布原報告時，讀取原報告及已確認 PR，核對變更範圍、內容與 artifacts。只看相同分支名或 HEAD 相似不足以證明一致。

只有本地受審內容能與已發布 head 對應且沒有未驗證差異時，才能說明該 head 由原證據涵蓋；保留原 review-id、原始基線及來源。若有差異，可在明確的歷史報告發布要求下貼原版本報告並標舊範圍，但不能升格為新 head 的 pass；需要當前 head 結論時啟動新一輪，沿用 Finding ID。無法確認時保留限制，不捏造 mapping。

### 5. 契約格式仍只有一個來源

Skill 描述決策與執行順序，Handoff／Author／Review 等格式引用 managed 契約；保留必要的 workflow guard，避免以「去重」移除版本、回讀、原實作者識別或錯誤恢復規則。回覆原作者與當輪發布者仍分開。

## Risks / Trade-offs

- 快照有額外成本：只涵蓋本輪工作與必要依賴，不能用整個磁碟掃描或公開本機絕對路徑取代。
- 本地交接可能讓 PR 被拒後仍送訊息：以模式及授權分支禁止此 fallback，不從錯誤結果重新分類為無 PR。
- metadata-only commit 使 SHA 改變：比對實際內容與範圍，保留新舊基線，不只依 SHA 相等與否判斷。
- 同一模型重播有盲點：Reviewer 自行核對案例；靜態、模擬、真實寫入證據分開，不拿字串測試宣稱端到端成功。

## TDD and Verification

先在 `tests/test_change_review.sh` 及 acceptance cases 加入行為期待取得有效 Red，再修改 template 與 installer 輸出。重播矩陣包含無 PR／unknown、提示、dirty 快照與中途變動、既有／缺少 Work Item、預設無通知、明確本機交接、代發者混淆、local-only、PR 發布失敗、後補 PR 相同／不同／不可判定內容。正常 PR pass、changes-required、blocked 與複審保持。

跑 change-review／github-handoff suites 及 strict validate；記錄未執行的遠端 gh／MCP／Session 實測。本階段未執行實作或測試。

## Migration Plan

保留名稱與呼叫方式；先改 template、cases、checklists 及必要圖文，透過 installer 傳播並比對。回復時還原本 Change 的 template 並重裝，不改寫既有本地或 GitHub 報告。此 Change 可獨立交付，不依賴 openspec-commit 擴充。
