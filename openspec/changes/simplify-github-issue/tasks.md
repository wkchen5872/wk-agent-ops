# Tasks

## 1. 來源與精簡正文

- [x] 1.1 在既有 handoff 測試與 Issue acceptance cases 加入來源選擇、最小正文和署名案例，先取得舊版的有效 Red。測試要求：指定 WI-only／Change-only／兩者、分支唯一／歧義、來源缺失、Session-only null、未知模型與 local-only references 都有明確 fixture、預期與禁止行為；記錄命令、失敗原因與最小輸出。
- [x] 1.2 修改 template github-issue 的描述與來源步驟，並在共用契約定義 initial body、精簡 Author 與動態中間段落；同步 examples。測試要求：1.1 的聚焦契約檢查轉 Green，重播確認明確指定優先、Work Item 可從 ignored 目錄找到、不搬完整 tasks、不自動建立本機 artifacts、不猜模型。

## 2. 關聯與新增留言

- [x] 2.1 加入 comment-only update、舊格式相容與來源關聯的 Red／重播案例。測試要求：包含人工正文、完整與破損 markers、連續兩輪更新、後補留言關聯、null 不構成查重鍵、多候選與衝突、只有 comment capability 的 client，以及 create／comment 逾時與回讀失敗；每例列出禁止的 body-edit／comment-edit／額外建立行為。
- [x] 2.2 將 template skill 的 update 改為讀取 Issue／相關留言後新增 Changes 留言，刪除正文改寫與 adoption 步驟，更新共用契約的 create 查重及兩類寫入回讀方式。測試要求：2.1 的聚焦檢查轉 Green，重播比對正文及舊留言逐字保留，重複 create 只回 URL，update 回新 comment URL，逾時未查清不重送。

## 3. 共用規則與說明整合

- [x] 3.1 限縮共用契約中的 managed-body、雙鍵與 extended provenance 條款，修正相關共用案例及 github-pr／change-review／rule 的受影響引用；保留 PR 與 Review 原行為。測試要求：先加入會暴露舊 Issue／PR 混用規則的聚焦檢查，再確認 Green；既有 PR、Review、批准與 transport 檢查仍通過，沒有入口要求重寫 Issue。
- [x] 3.2 同步 README、AGENTS、architecture 及 Work Item 規範中受影響的 Issue 說明，並更新 template handoff SVG 的正文／留言語意；來源為 template 的文件只改來源。測試要求：檢查連結與圖文一致，實際渲染 SVG 確認無溢出與重疊；未渲染不得標記視覺驗收通過。

## 4. 安裝與整體驗證

- [x] 4.1 執行 `bash scripts/skills/install.sh` 同步受管理目標，確認沒有接管第三方或 `.codex/skills/`、`.codex/config.toml`。測試要求：template 與 `.claude/skills/github-issue/`、`.agents/skills/github-issue/`、managed docs 逐一比對一致，執行既有 installer fixture 驗證無關內容保留。
- [x] 4.2 完成受影響套件、Agent 行為重播與 OpenSpec verify，留下可稽核驗證紀錄。測試要求：執行 `bash tests/test_github_handoff.sh`、受影響的 change-review／Work Item 測試及專案必要檢查；記錄實際呼叫與結果，區分靜態檢查、模擬行為與遠端驗收。未另獲遠端寫入授權時，不建立測試 Issue，明示真實 GitHub create／comment 未驗證。

## 5. 來源到內容的品質修正（review r06）

- [x] 5.1 加入可驗收內容品質的案例與檢查，先取得有效 Red。測試要求：至少三個「來源實文 → 產出 Issue → 內容判定」案例涵蓋 Work Item、Change、Session，其中一例是紀錄寫 5 次、對話確認改 3 次；靜態檢查在舊版失敗；以舊版 skill／契約快照讓獨立 Agent 實際生成，記錄未達內容標準之處。
- [x] 5.2 修正 skill 的素材整合與撰寫標準、共用契約 §6.1 的內容規則、範例的依賴解除條件，以及 spec／design；不新增固定章節。測試要求：5.1 的靜態檢查轉 Green；獨立 Agent 以新版實際生成三份 Issue，逐項依內容判定審閱並保存。
- [x] 5.3 以 installer 同步，重跑受影響套件，補重播 C-20 與其他受影響案例，留下本輪驗證紀錄。測試要求：`bash tests/test_github_handoff.sh`、`test_change_review.sh`、`test_work_items.sh`、`openspec validate --strict`、`git diff --check` 通過；紀錄區分靜態、離線生成／重播與真實 GitHub（未執行）。

## Workflow follow-up

- 人類 review 並批准本設計後，才開始實作；本次 ff 僅建立規劃 artifacts。
- 請求封存時先確認上游 `add-github-change-handoff` 的主規格已落地；如尚未封存，先走其獨立授權流程。再於本 change 補上共用 capability 的完整 MODIFIED requirement deltas、更新 proposal 能力清單、驗證並同步，確保 Issue 專屬契約與共用規格不衝突。
- Archive、commit、push、建立 Issue／PR 各依後續授權執行，不由本任務清單自動觸發。
