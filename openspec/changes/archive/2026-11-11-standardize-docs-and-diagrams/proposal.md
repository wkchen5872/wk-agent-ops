# Proposal

## Why

跨專案文件需要讓數週或數月後回來的讀者快速理解並操作；目前共用規範偏重格式，缺少文件分類、目前有效設計與圖稿交付標準。現有 OKF v0.1 指引也需更新為 v0.2，避免引用與內容時間的寫法繼續漂移。

## What Changes

- 擴充既有共用文件規範，不新增 skill：API、操作、設計與規格各有必要內容與驗收要求。
- 靜態流程、循序、架構及平面設計稿優先交付 SVG；需要 UX 互動時使用 HTML，並檢查圖文與顯示一致性。
- 正式文件只維護目前有效設計，保留必要理由與限制；討論及歷史留在既有協作／封存位置。
- **BREAKING（新寫作約定）**：OKF v0.2 以 `generated` 及 `sources`／具名腳註取代新文件的 `timestamp` 與獨立 Citations 清單；既有文件採漸進遷移，不全面覆寫。
- 共用 protocol 與 doc-updater 的 skill、Claude／Codex agents 引用同一規範，涵蓋巢狀 docs 與獨立圖稿；Antigravity 使用既有共用 skill。

## Capabilities

### New Capabilities

- `documentation-authoring`: 文件分類、OKF v0.2 漸進遷移、有效內容維護與靜態／互動圖稿交付的共用契約。

### Modified Capabilities

- `doc-updater`: 更新相關文件時載入共用契約，檢查分類內容、過時敘述、重複內容、圖文與連結，保留最小修改及不自動 commit 的行為。

## Impact

- 來源：`template/common/docs/okf-conventions.md`、`agent-protocol.md`、`template/common/work-items/AGENTS.md`、既有 doc-updater skill 與 Claude／Codex agent templates；必要的 README／AGENTS 說明。
- 安裝：沿用 installer，更新 managed docs、`.claude/`、`.agents/`、`.codex/agents/`；不接管 `.codex/skills/` 或 `.codex/config.toml`。
- 測試：既有安裝與 agent 同步測試，加上範圍明確的規範驗收案例。無新增 runtime dependency、API 或 hook 行為。
- 排除：不改寫 fio-pv-twin、不全面遷移歷史文件、不新增繪圖引擎／文件產生器／attestation 系統。
- 驗收：規範可由三工具既有入口到達；新舊 OKF 案例有明確處置；三類文件及 SVG／HTML 選擇均可按案例檢查；安裝保持來源同步與專案自有檔案不被覆寫。
