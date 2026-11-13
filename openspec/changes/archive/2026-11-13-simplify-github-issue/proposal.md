# Proposal

## Why

目前 github-issue 只接受 OpenSpec Change，Issue 正文被關聯欄位與累積 provenance 佔據，更新又覆寫正文，難以理解工作與迭代歷程。改為整理 Work Item、Change 或目前 Session 的內容，建立清楚的工作說明，後續以新增留言保留變化。

## What Changes

- 支援明確指定 Work Item、Change 或兩者；未指定時確認目前分支的關聯，找不到時允許純 Session 來源，不自動建立任何本機工作紀錄。
- Issue 開頭固定三個 Handoff 欄位，結尾固定 Author；Goal 說明問題與結果，Tasks、References 及其他中間段落依內容出現，避免空白樣板與全文搬運。
- **BREAKING**：`github-issue update` 改為新增 `Handoff → Changes → Author` 留言，保留原正文與既有留言，不再採用 managed block 改寫流程。
- Issue 與留言只要求本次貼文工具、當下已知 root-session 模型；不再要求 Session、機器、角色與多輪 provenance。PR／Review 維持原有欄位與更新行為。
- 保留完整 repository 目標、操作授權、可用 gh／MCP、查重、結果回讀及逾時後先查核的規則；舊格式 Issue 可直接新增留言，無須格式遷移。

## Capabilities

### New Capabilities

- `github-issue`: 本機／Session 來源選擇、精簡 Issue 整理、明確關聯與只新增留言的更新契約。

### Modified Capabilities

無已發布的主規格需要直接修改。`github-change-handoff` 尚存在於未封存的 `add-github-change-handoff` change；本 change 明確取代其中 Issue 專屬的來源、managed 更新與 provenance 要求。整合時須同步限縮共用條款適用範圍，不能留下互相衝突的有效規則，亦不在本次規劃中改寫另一個 change 的 artifacts。

## Impact

- 來源：`template/common/skills/github-issue/SKILL.md`、其 `references/`、`template/common/docs/github-handoff.md` 及交接 SVG。
- 呼叫與說明：檢查 github-pr、change-review、handoff rule、README、AGENTS、architecture 及 Work Item 規範中的 Issue 假設，只修正受影響敘述；PR／Review 語意不變。
- 驗證：更新 `tests/test_github_handoff.sh` 與可重播案例，區分靜態契約測試、Agent 行為重播與真實 GitHub 寫入證據。
- 安裝：實作後由 `scripts/skills/install.sh` 同步受管理目標，支援 Claude Code、Codex、Antigravity；不手改安裝副本，不新增依賴或 API wrapper。
- 驗收：指定來源優先、分支辨識與歧義處理、Session-only null 欄位、精簡格式、差異留言、舊 Issue 保留、查重與逾時查核均有可重播案例；本次規劃不建立／修改遠端 Issue。
