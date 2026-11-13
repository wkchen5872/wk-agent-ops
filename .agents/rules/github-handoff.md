# GitHub 交接入口

這是 Provider 原生載入入口，不是規範本身，也不是 hook；它不會在執行期攔截任何指令。

當任務要建立或更新 GitHub Issue／PR、發布 Review 報告，或為這類交接進行 commit／push
時，先讀取並遵守 `docs/github-handoff.md`。該文件是範本、關聯、身分檢查與交接流程的
唯一來源。每次寫入前，依操作類型（api／commit／push）執行其中指定的共用檢查
`scripts/github/check-identity.sh`；結果不是 pass 就停止該次寫入。

本入口不授予額外的程式碼修改、Git 操作或遠端寫入權限。本檔與上述文件、腳本都是
安裝產物，不在此直接編輯；變更依本專案指定的來源與安裝工具處理。
