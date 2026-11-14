# GitHub 交接入口

這是 Provider 原生載入入口，不是規範本身，也不是 hook；它不會在執行期攔截任何指令。

當任務要建立、更新、回覆或關閉 GitHub Issue／PR、發布 Review 報告，或為這類交接進行 commit／push
時，先讀取並遵守 `docs/github-handoff.md`。該文件是範本、關聯、寫入前核對、交接與結案流程的
唯一來源：每次寫入前核對完整的 repository 目標、操作與授權，使用可用的 gh 或 GitHub
MCP 與本機 Git，寫入後回讀結果；不輸出 credential，也不自行切換帳號或改 remote。

本入口不授予額外的程式碼修改、Git 操作或遠端寫入權限。本檔與上述文件都是安裝產物，
不在此直接編輯；變更依本專案指定的來源與安裝工具處理。
