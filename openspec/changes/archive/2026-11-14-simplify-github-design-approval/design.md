# Design

## Context

問題與範圍見 [proposal.md](proposal.md)；來源為 Issue #17。現行契約 §4.3 設置獨立記錄者資格，§6.3 要求批准者 GitHub 帳號，§9 將 PR 事件與實際作者核對設成 Apply 的必要條件。`github-pr` 的批准 reply 與 `change-review` 的 checklist／案例引用同一套要求；`tests/test_github_handoff.sh` 亦固定了部分舊語意。只改 §9 會留下互相衝突的入口。

## Goals / Non-Goals

**Goals:** 讓已有明確授權的工作不中斷，且下一位接手者能理解授權來自何處、涵蓋哪些 artifacts 與操作。

**Non-Goals:** 不取消人類決策、不更動平台 Review／merge 規則、不把 Issue #18／#19 納入、不調整原 Review 優化的本地報告設計。

## Decisions

### 1. 使用者指示與發布證據分開

授權判定輸入為來源、Change／artifacts、內容版本及操作範圍。當前 Session 可直接使用範圍清楚的使用者指示；明確指定 Change 並要求開始實作，足以授權依目前設計實作與驗證，不再要求另一句「批准設計」。只要求開 Change、討論、Review 或技術 pass，均不授權 Apply。

接受來源包括當前使用者指示，以及經既有協作通道明確轉交、可核對指定工作與來源的使用者指示。不要求原始私有逐字稿或本人帳號證明，但 Agent 自己的建議、無來源的批准宣稱、PR 描述自稱獲准均不構成授權。若來源彼此衝突、最新明確指示撤回授權、設計有實質差異或範圍不可辨識，才釐清受影響部分。

替代方案是維持 PR 批准留言但自動發布；未採用，因為本地 Apply 會被不必要的網路寫入綁住，亦擴大實作請求的發布權限。

### 2. 批准紀錄是交接內容，沒有第二套認證

獲授權使用 `github-pr reply` 記錄時，沿用獨立事件及 marker，保留 status、approved_scope、artifact_revision、source_kind、source_ref、recorded_by、recorded_at、approved_at 與 supersedes。`approved_by` 改為選填：只在已知且適合公開時記錄人類識別，未知省略；不能以 API login 補填。API 實際作者代表發布帳號，不證明真人或委託者身分；不再核對專屬記錄者白名單。

來源種類保留 human-github／agent-attested-user-instruction 的相容讀取；未公開對話用不含私人細節的描述，不能杜撰 transcript URL。發布時使用來源指示的實際精度；記錄時間不能取代批准時間。若無可公開且足以接手的來源、範圍、版本，說明證據缺口，不能虛構欄位。

替代方案是完全刪除批准事件；未採用，因為跨機器交接仍需要可追查的決策內容。

### 3. 真實授權與技術能力各自核對

完整 repo、operation、使用者授權、工具能力、已知拒絕與結果回讀仍適用。存取 repo 不等於使用者同意；有明確指示時則不因未知人類 GitHub 帳號阻擋。明示的帳號或提交身分限制保持有效，不改 authentication、不繞過 branch protection 或工具 permission review。

### 4. 規則集中於 repo 擁有的契約

修改 template 契約及其 workflow 引用，再同步 GitHub／Review skills、references、相關圖文。Apply 是目前安裝的上游 OpenSpec skill，template 沒有該來源；不手改已安裝副本，以 managed workflow／契約去除前置關卡。若發現其他 repo 擁有的入口複製舊要求，於相同範圍同步，不能靠候選分支自稱新權限。

## TDD Strategy and Verification Boundaries

先新增能捕捉舊語意的測試並記錄有效 Red，再修改 template；grep 檢查只證明文件一致，另以盲讀案例驗證 Agent 選擇繼續或停止的語意。必要案例為：本人帳號未知、API 帳號與委託者不同、明確實作指示但無 PR 留言、跨 Session 的來源交接、只有 pass、只要求建立 Change、來源不明、授權撤回、設計變更及讀得但寫入被拒。

跑受影響 suites、完整必要檢查、installer 安裝／重裝與三工具入口一致性；Change strict validate 與 verify 分開記錄。離線重播不等於真實 GitHub 寫入或 Session 通知驗收；沒有另行授權不得為測試建立平台批准事件。

## Risks / Trade-offs

- [移除帳號名單後有人將任意留言當批准] → 仍檢查實際內容來源、範圍、版本與較新的撤回，未知來源不能授權；不以 repo 權限背書。
- [各入口殘留舊要求] → 同時檢查契約 §4.3／6.3／9、§11 案例、PR reply、Review references 與 managed workflow，測試涵蓋跨入口重播。
- [與原 Review Change 修改相同能力] → 原分支保留；本 Change 完成後先合併其更新，檢查原 delta 不覆蓋簡化後的批准情境，再繼續 Apply。

## Migration Plan

此輪只建立規格。後續經設計確認後依 tasks 實作 template，透過 installer 安裝；歷史批准事件保持原樣且可讀，不要求補新帳號欄位。需要撤回時回復本次來源修改並重跑 installer，不編輯歷史留言。先完成本修正，再回到 `improve-change-review-local-handoff` 接續工作，不能將規劃完成當作新版規則已生效。
