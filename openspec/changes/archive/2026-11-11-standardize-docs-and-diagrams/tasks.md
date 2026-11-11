# Tasks

## 1. 共用文件與圖稿契約

- [x] 1.1 建立最小契約檢查及 design 所列人工驗收案例；測試要求：在修改 template 前記錄缺少新契約的 Red，人工案例記錄預期結果。
- [x] 1.2 更新 OKF v0.2、分類寫作、SVG／HTML 與漸進遷移規範；測試要求：契約檢查通過，逐項審閱新舊 metadata、來源、三類文件及圖稿案例。
- [x] 1.3 擴展 protocol 的文件／圖稿入口及必要 README／AGENTS 說明；測試要求：從共用入口可到達規範，涵蓋巢狀 docs 與 Work Item 圖稿，schema-owned 文件不被強制改格式。

## 2. Doc updater 整合

- [x] 2.1 更新共用 skill 與 Claude／Codex agent templates；測試要求：入口檢查先 Red 再 Green，三入口均引用規範並涵蓋相關文件、範例、圖稿與連結，保留 mode 與 no-commit 行為。
- [x] 2.2 檢查最小修改、過時／重複內容及驗證限制的語意案例；測試要求：記錄人工規範審查結果與未執行的 runtime 驗證，不聲稱文字檢查證明 agent 執行成功。

## 3. 安裝與整合驗證

- [x] 3.1 在暫存目標驗證 installer 並安裝本 repo；測試要求：既有同步／portable entry 測試通過，自有文件及不受管理的 Codex 設定保留，template 與 installed copies 一致。
- [x] 3.2 執行受影響檢查、OpenSpec verify 與 strict validation；測試要求：記錄命令、結果、檔案同步與未驗證範圍，更新本清單且無未處理的規格缺口。

## Workflow follow-up

- 依後續授權範圍處理 archive 與 commit；正式提交前執行專案完整必要檢查。
