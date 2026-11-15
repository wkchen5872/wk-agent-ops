# GitHub 協作入口

這是 Provider 原生載入入口，不是規範本身，也不是 hook；它不會在執行期攔截任何指令。

當任務要建立、更新、回覆或關閉 GitHub Issue／PR，或發布 Review 報告時，使用已安裝的
`github-issue`、`github-pr` 或 `change-review` Skill；貼文格式、寫入前核對與回讀都在 Skill 內。
無論使用哪個工具，每次寫入前都核對完整的 repository 目標、操作與授權，使用可用的 gh 或
GitHub MCP 與本機 Git，寫入後回讀結果；不輸出 credential，也不自行切換帳號或改 remote。
要了解開發流程在哪些時點接上 GitHub，讀 `docs/github-handoff.md`。

本入口不授予額外的程式碼修改、Git 操作或遠端寫入權限。本檔與上述文件都是安裝產物，
不在此直接編輯；變更依本專案指定的來源與安裝工具處理。
