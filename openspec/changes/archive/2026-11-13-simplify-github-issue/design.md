# Design

## Context

動機與範圍見 [proposal.md](proposal.md)。目前 skill 是薄入口，範本、關聯與 provenance 的權威來源在 `template/common/docs/github-handoff.md`。`update` 使用 Issue body-edit；共用第 5、6、7、11 節也把 Issue 與 PR 綁在 managed block 與完整 provenance 上。既有 `tests/test_github_handoff.sh` 明示只驗證契約存在與 installer 行為，不能證明 Agent 的實際選擇或遠端成功。

`openspec/specs/` 尚無 github-change-handoff 主規格；目前規則存在於 `add-github-change-handoff` 的待封存 delta。此設計新增專責 Issue 的 `github-issue` capability，不修改該 change 的規劃檔；後續規格同步必須避免把泛用舊條款重新套回 Issue。

## Goals / Non-Goals

**Goals:**

- 以同一份共用契約定義 Issue 初始正文與更新留言，讓 Claude Code、Codex、Antigravity 採用相同行為。
- 把來源辨識、內容整理與遠端寫入分清楚，使用者可讀到工作與每輪差異。
- 保留原有目標、授權、查重與回讀保障，同時移除 Issue 不再需要的正文改寫機制。

**Non-Goals:**

- 不新增資料庫、對照檔、client wrapper、背景同步或獨立腳本。
- 不調整 PR／Review 範本與人類批准流程，不自動改 Issue 狀態、標題、labels 或 assignees。
- 不追溯改寫舊 Issue，不自動建立或發布本機 artifacts，不讀取其他專案的 Session 歷史。

## Decisions

### 1. 輸入為可選來源與可選 Issue，操作只有 create／update

資料保持既有形式：Work Item ID／路徑、Change ID／路徑、Issue URL／編號、已確認的 repository，與目前對話內容；不引入機器可執行的新 schema 或 parser。

來源次序：明確選擇 → 目前分支的可證實關聯 → 目前 Session。明確選擇的來源缺失時回報，不能悄悄 fallback。分支名稱可提供 Change 候選，例如 `feature/<change-id>`，但要核對實際 artifacts；Work Item 依目標 repo 的明確 `work-items/WI-*/README.md` 與連結核對，不能要求新增 branch 欄位，也不能依賴會略過 ignored Work Items 的搜尋。明確指定其中一種來源時，只補充與其確實相關的另一種，不借用無關分支資料。

選定紀錄之後，仍一律整合本輪的相關對話：使用者在對話中後來確認的決策取代紀錄中的舊值（例如紀錄寫重試 5 次、對話確認改 3 次，Issue 寫 3 次）；只有無法判定何者為準時才詢問。

若沒有唯一關聯但有多個合理候選，先詢問；只有確實沒有候選時才進入 Session-only。Session-only 的議題可理解就繼續，主題不足才問。兩個 ID 都沒有即填 `null`，不補造工作紀錄。

替代方案是強制建立 Work Item／Change 後才能登錄；這違反已確認的 Session-only 使用方式，故不採用。

### 2. 格式只固定起點、主體用途與署名

範本唯一放在共用契約的 Issue 小節；skill 指向該節並描述操作順序，references 提供具體範例而不維護另一份規範。建立預設：

```markdown
## Handoff

- openspec-change: <confirmed ID or null>
- work-item: <confirmed ID or null>
- pull-request: <confirmed URL or null>

## Goal

<problem, background needed to understand it, and intended outcome>

## Tasks

- [ ] <meaningful work or completion condition>

## References

- <useful links or repo-relative unpublished references>

## Author

Co-Authored-By: <posting tool>
AI-Assisted-By: <known current root-session model>
```

Work Item、Change 與 Session 是素材：讀取後重組成一份沒有來源的人也能理解、可以交辦的任務，依素材實際內容寫清楚問題與影響、範圍、工作、完成條件與未決事項。這是內容標準，不是固定章節；不沿用 Work Item 的紀錄格式、不把內部清單刪短後貼出、不只貼 ID，也不捏造決策。內容品質以 acceptance cases 中「來源實文 → 產出 Issue → 內容判定」的案例驗收，不以章節存在與否判定。

Handoff、Goal、Author 必須出現；Tasks、References 有用才保留，其他中間標題可依工作調整。標題直接描述工作目的，不強制 Change ID 前綴。摘要讓只讀 Issue 的人理解問題、範圍與預期結果；不搬整份 tasks 或 Session 逐字稿。未決事項明說未決，實作、驗證與部署狀態不混用。沒有發布的 References 標為「尚未發布／local-only」，不偽造可點擊的遠端連結。

Author 只記本次貼文工具與已知 root-session 模型，name-only，不套用 Git commit email trailer 邏輯。模型未知時省略該行並在操作回報說明，不填來源作者的模型。替代方案是保留精簡 Provenance 區，但仍會把本次工具與歷史參與者混在一起，因此不採用。

### 3. update 永遠是新增留言

```markdown
## Handoff

- openspec-change: <confirmed ID or null>
- work-item: <confirmed ID or null>
- pull-request: <confirmed URL or null>

## Changes

<what changed in this iteration and why it matters>

## Author

Co-Authored-By: <posting tool>
AI-Assisted-By: <known current root-session model>
```

先讀 Issue 正文及與本次更新相關的留言，避免重貼初始目標或已發布的更新。Changes 可包含決策、進度、測試結果、阻礙與下一步，但不規定全部出現。未指定 Issue 時，以已選來源查找唯一關聯；無法辨識更新目標就詢問，不改成 create。指定 Issue 時沿用其已確認關聯，僅在確認是同一工作後補上新 ID。

執行使用原生 gh 的 comment 操作或 MCP 等效能力。回讀新 comment 本身並核對父 Issue、repository 與正文，回報 comment URL。舊 managed markers 是否完整均不影響留言；不做 adoption，也不改原正文或先前留言。替代方案「改正文再留言」會保留兩套更新機制並破壞初始快照，故不採用。

### 4. 查重依實際來源，null 不是識別碼

明確 Issue URL 優先。其他情況在確認的 repository 內搜尋非 null 的 Change／Work Item ID，再讀實際正文與相關留言；舊格式的 `repository` 和 Change 欄位可作證據，但新 Issue 不需額外 repository 欄位，目標由 GitHub URL／metadata 核對。

任一非 null ID 可找到候選；若另一個已知 ID 衝突，停止並澄清；缺少值可由相關資料確認後在新留言補充。同一工作後補的關聯存在留言，未來查找必須納入留言，不能只看初始正文。唯一確定的重複 create 只回傳 URL，不自動新增迭代。

Session-only 沒有穩定工作鍵：優先使用本次 Session 已知 URL；否則可讀近期／相關 Issue 排除明顯重複，但標題相似與 null 相等不構成關聯。有合理疑似對象就詢問，沒有就建立，不新增合成 Session key 或對照檔。

逾時後依原目標列出近期 Issue／comments，核對此次預備正文、可得作者與時間範圍；可唯一確認就回報，仍不明就停止重送。沒有穩定鍵的 Session-only 建立與 comment 寫入不宣稱 exactly-once。

### 5. 共用契約分開 Issue 與 PR／Review 的適用範圍

第 5 節的 managed blocks 與雙鍵規則限於 PR 及舊 Issue 的讀取相容；Issue 新規則由精簡 Handoff 與 repository metadata 構成。第 6 節分開 initial body／update comment；第 7 節明列 Issue Author 例外；第 11 節將「更新正文」限於 PR。同時檢查其他會指向這些節點的入口、驗收案例與 SVG，避免 github-pr 或 change-review 間接要求重寫 Issue。

等待資料、依賴解除條件與下一步仍可放在工作說明／Changes 的相關段落；移除的是強制空欄位，並未把 merge 或日期到來視為驗收完成。

## Risks / Trade-offs

- [正文不反映最新狀態] → 初始內容維持工作起點，最新進度讀留言；此為保留迭代的刻意選擇，不額外維護狀態摘要。
- [Session-only 無穩定查重鍵] → 不以 null 或標題假裝確認；不確定時詢問，逾時不盲目重送。
- [關聯後補在留言，僅搜尋正文會漏查] → discovery 案例涵蓋留言關聯，讀取客戶端無法涵蓋時回報限制並要求明確 Issue。
- [純文字測試不能證明 Agent 遵循] → 靜態契約測試、isolated fixture 行為重播與真實遠端結果分開記錄。
- [舊共享 spec 可能重新帶入衝突] → 封存前檢查實際 canonical spec；把本 capability 作為 Issue 行為唯一來源，將舊共用要求限於 PR／Review，或引用此 capability，不能只新增一份相反規則。

## Migration Plan

1. 先補上會在目前來源下失敗的聚焦契約檢查與具體 Agent 重播 fixtures，記錄 Red；不以語法失敗當行為 Red。
2. 修改 template skill、examples、acceptance cases 與 shared contract，調整受影響的薄入口說明與交接 SVG；不改安裝副本。
3. 執行 installer 同步本 repo，確認 Claude Code／Antigravity skills 與受管理 docs 一致，Codex 仍由 protocol 入口到同一契約；不接管 `.codex/skills/` 或 config。
4. 跑聚焦／受影響測試、Agent 重播與 SVG 實際渲染檢查；真實 GitHub 寫入須另外取得授權，沒有執行就明示未驗證。
5. 封存前重新檢查 `add-github-change-handoff` 的發布／封存狀態。若其主規格已出現，先在本 change 補上對其完整 requirement blocks 的 MODIFIED delta，限縮 Issue 共用條款並驗證後再同步；若仍未封存，先完成上游的獨立封存流程，再做此 reconciliation，不改寫上游 change 的歷史 artifacts。本次 ff 不執行上述封存或同步。

回退時回復此 change 的 template 與相關文件，再執行 installer；新留言與既有遠端內容保留，不刪除已發生的工作紀錄。

## Test Strategy

- 擴充既有 `tests/test_github_handoff.sh`：Issue 模板最小欄位、comment-only 更新與 PR／Review 規則隔離；保留其 installer 同步與不覆寫無關檔案的測試。新增檢查需在舊版有有效失敗，不能只檢查新檔存在。
- 在 skill 的 `references/acceptance-cases.md` 記錄可重播 fixture、預期呼叫、禁止副作用與判定；涵蓋 source-only／combined／branch／session-only／ambiguous／missing-explicit、duplicate／null／comment-association、legacy／handwritten、未知模型、權限不足、逾時查核與回讀失敗。
- 使用隔離 fixture 的 Agent 重播驗證內容整理與操作選擇；預期 create 使用 Issue-create，update 只能 comment-create。比對 fixture 前後 body 與既有 comments 不變，兩個連續更新各自留下差異留言。不得把靜態 grep 通過當成這些行為的證明。
- 不另寫通用 GitHub 模擬 client；使用既有可重播案例格式與可用執行環境，若無法自動重播，留下操作步驟、預期結果與未驗證項目。
