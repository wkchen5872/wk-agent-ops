# Design

## Context

動機見 [proposal](proposal.md)。現有 managed `okf-conventions.md` 已由 installer 出貨，protocol 目前僅以 docs 路徑觸發讀取；doc-updater 有共用 skill 與兩種 provider agent。沿用這條交付鏈即可，不需要新工具。

## Goals / Non-Goals

- 共用規範是唯一寫作契約，入口僅負責載入與執行檢查。
- 適用根目錄及模組 docs、README 與圖稿；OpenSpec、技能、協作紀錄維持自身 schema，不強制套用 OKF frontmatter。
- 不更改 installer ownership、不批次遷移下游 repo、不建立文件產生器或自動評分系統。

## Decisions

### 1. 擴充既有 managed 規範

`template/common/docs/okf-conventions.md` 保存 OKF 格式、分類內容及圖稿檢查；`agent-protocol.md` 將入口擴展至文件與圖稿工作。doc-updater 的 skill、Claude agent、Codex agent 引用該檔，並在目標探索中納入巢狀文件、範例與圖稿。

資料流為 template 經 installer 到 managed policy 及 provider entrypoints，再由 agent 讀取並產出文件。獨立 skill 需要額外觸發，複製規則到各工具會增加漂移，因此不採用。既有 installer 已包含這些檔案，除測試發現缺口外不改腳本。

Work Item 專屬紀錄、圖稿存放及交接要求集中於 `template/common/work-items/AGENTS.md`；共用文件規範只保留引用。Work Item 規範反向引用共用圖稿格式與視覺驗收，避免重複維護。

### 2. OKF v0.2 採漸進遷移

依官方 SPEC §4–9、§11–13（2026-11-11 查閱）：基礎 conformance 與本專案較嚴格的可讀性要求分開；保留本專案 title、description、tags 要求。新寫作使用 generated.by/at，來源使用 sources 與同 id 腳註；不推測舊作者，不把修改時間當來源查驗時間。新 metadata 只寫已知事件；未知 generated 身分時可省略該 optional family 並說明。

只遷移本次實質修改的 managed 文件／範例，其他 v0.1 文件保持可讀並在下次實質更新時遷移。無法可靠對應的既有引用保留並報告，不任意配置。既有擴充欄位不丟棄；若自訂 status 表示部署進度，更新時移至清楚命名的自訂欄位或正文，status 專供文件生命週期。不得由 stable 推定 deployed 或 verified。

`index.md`／`log.md` 保留其特殊結構；不為升級新增無用途的 index。跨文件連結沿用 bundle-relative 或相對路徑，圖稿使用鄰近 diagrams 的相對連結。全面重寫與強制新增所有 optional metadata 都不採用。

### 3. 交付格式與歷史分工

靜態圖稿採 SVG、互動 UX 採 HTML，現有可編輯來源可保留但不作為唯一交付。預設更新既有圖，避免雙份權威文件。圖稿必須可直接開啟、文字與流程一致，視覺檢查另列結果。

正式文件只寫目前有效設計及必要技術理由，歷史由既有 archive／Work Item 承接；不刪除歷史證據，也不把草案或已核定但未部署的設計寫成現況。OpenSpec design 保留 schema 要求的方案取捨，避免將「不放對話紀錄」誤解為禁止技術理由。

### 4. 驗證與 TDD 邊界

安裝與同步沿用 `tests/test_portable_agents_md.sh`、`tests/test_agents_dir.sh`、`tests/test_openspec_commit.sh`。先新增最小入口／規範契約檢查，確認舊版本因缺少新契約而失敗，再更新 template。避免用字串存在宣稱文件品質或 agent runtime 已驗證。

語意品質無法由 shell 可靠判定，採可重播人工驗收：給定缺少錯誤回應的 API、缺執行目錄的操作稿、含對話與過時段落的設計稿、v0.1 引用／未知作者案例、靜態流程與互動表單需求，逐一對照規範確認明確處理方式。預期為 API 契約補全、步驟可辨識成功、現況與歷史分離、來源不臆造、SVG／HTML 選擇一致。此為規範審查，不等同新 session 執行結果；若未做跨工具 runtime 測試須明示。

## Risks / Trade-offs

- 規範較長 → protocol 只放短入口，詳細規範按工作需要讀取。
- 舊 timestamp 與引用混用 → 漸進遷移，保留未知資訊，不宣稱整個 bundle 已完成遷移。
- 圖稿語法通過但難讀 → 將渲染檢視與結構檢查分開記錄；未檢視時明示。
- 規範出貨不保證每個 agent 遵循 → 分別回報同步、入口檢查及 runtime 證據。

## Migration Plan

1. 確認上述驗收案例並建立失敗檢查。
2. 修改 template 規範、入口與 updater，更新本 repo 必要說明。
3. 在暫存 repo 驗證安裝及既有自有檔案保留，再安裝到本 repo。
4. 執行相關檢查與 OpenSpec validation，記錄未驗證範圍。
5. 回退時回復 template 及相關文件後重跑 installer；不回滾或刪除下游自有文件。

## Sources

- [GoogleCloudPlatform OKF SPEC v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)：格式、遷移與 optional metadata 的依據；本設計的文件分類與 SVG 優先是專案政策。
