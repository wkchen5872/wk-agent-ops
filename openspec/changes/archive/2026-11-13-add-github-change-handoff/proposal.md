# Proposal

## Why

新 Agent 目前需要使用者反覆提供 Change、Work Item、版本與操作方式，本機 Review 紀錄也無法直接支援跨機器接手。需要以 GitHub Issue／PR 保存穩定的工作入口、發布版本與交接證據，讓 OpenSpec 繼續管理正式需求，並沿用現有 GitHub 工具與 Git Commit Writer。

## What Changes

- 新增 `github-issue` 與 `github-pr` 兩個薄 Skill，套用專案共用格式，Issue／PR／Review 可使用當前可用且已授權的 gh 或 GitHub MCP；commit／push 使用本機 Git。SSH／HTTPS 認證交由原生工具管理，不新增 GitHub client、通用後端框架或修改第三方 Skill。
- Issue 支援建立與更新，包含 Change、父子／依賴關係、下一步、負責人與延後驗收。以明確關聯查重，保留既有人工內容。
- PR 分開提供建立、發布既有 PR 的版本，以及僅更新說明的操作。建立／發布在授權範圍內按需委派 Git Commit Writer、push；更新說明不提交或推送。
- 共用契約改為按操作核對完整 host／owner／repo、必要時的 PR base／head 與分支，確認使用者授權，利用實際執行工具提供的連線及權限資訊，執行後回讀結果。讀取權限不冒充所有寫入權限；無法完整預證權限時，以已授權操作的結果判定，不新增探測寫入。
- 預設不要求指定 GitHub 帳號，不解析 SSH 問候語或 HTTPS credential helper。專案或使用者明確限制帳號時才核對；實際參與者能確認就記錄，未知如實說明。移除既有自訂 identity-check 腳本、可信 blob bootstrap 與強制呼叫入口；不輸出 credential，也不自行切換登入或改 remote。
- 定義共用 Issue、PR、Review 的必要資訊與 provenance 語意。預設保留工具、已知模型與原生 Session ID，機器只使用已配置中性別名；未知或明確要求不公開的值如實標示，不發布本機絕對路徑或原始 hostname。
- 建立可人工啟動的完整流程，規格發布、設計 Review、人類設計批准、實作發布、實作 Review、修正複審、真實資料等待及依授權結案分開記錄。
- 人類批准可由已授權 Agent 具名代記為 PR 事件，保存來源、範圍、版本及實際發布者，供跨機器接手信任；不要求使用者重複到 GitHub 留言，也不把 Agent 技術通過當成人類批准。
- 調整 Work Item 規範，允許 PR 保存正式交接報告；本地 Work Item 仍可丟棄、不進 Git、不跨 worktree 同步。Review 執行另由 `add-change-review-skill` 承接。

驗收須證明新 Session 不讀原對話或 Work Item，仍可由 Issue／PR 找到可取得的正式文件、版本及下一步；查重、明確帳號限制衝突、局部內容保留、提交範圍與等待驗收有可重播的通過／拒絕案例。安裝後 Claude Code、Codex、Antigravity 取得同一契約。

## Capabilities

### New Capabilities

- `github-change-handoff`: OpenSpec 與 GitHub 關聯、共用內容／目標與操作契約、Issue／PR 建立更新、版本發布與跨 Session 交接。

### Modified Capabilities

- `work-item-records`: 明確區分本地草稿與 PR 正式交接報告，必要資訊不依賴 Work Item，且不因遠端交接而同步本地紀錄。

## Impact

- 主要來源為 `template/common/skills/github-issue/`、`template/common/skills/github-pr/`、新增的 managed `template/common/docs/github-handoff.md`，以及 `template/common/work-items/AGENTS.md`。
- 移除舊 `check-identity.sh` 的執行、安裝及依賴；薄 rule 與 Codex managed protocol 指向同一份目標、操作、可選帳號限制與結果驗證規範。既有本機認證配置不由 installer 改寫。
- `template/common/docs/agent-protocol.md`／`openspec-workflow.md` 加入適用範圍與短連結；`scripts/skills/install.sh` 將共用契約與其引用的流程 SVG 一起列為 managed assets。README、專案架構與工作流入口同步必要說明。
- 透過 installer 更新 `.claude/skills/`、`.agents/skills/` 與 managed 文件；不手動修改安裝目標，不變更第三方 OpenSpec 或 Ponytail Skills。
- 補入contract、暫存 repo 安裝／保留測試及有固定格式與正式證據位置的人工 Agent 情境驗收；不新增 Agent harness，不把模擬回覆當真實認證或遠端寫入。真實 GitHub 操作驗收須使用明確指定的測試 repository 與可用工具，未執行時如實列為未驗證。
- 不新增 Trello 整合、GitHub Projects 自動化、背景派工、跨機器 Session 啟動器、網路 Git hooks、自動合併／部署／archive 或專用 Review Agent。
