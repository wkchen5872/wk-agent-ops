# Proposal

## Why

新 Agent 目前需要使用者反覆提供 Change、Work Item、版本與操作方式，本機 Review 紀錄也無法直接支援跨機器接手。需要以 GitHub Issue／PR 保存穩定的工作入口、發布版本與交接證據，讓 OpenSpec 繼續管理正式需求，並沿用現有 GitHub 工具與 Git Commit Writer。

## What Changes

- 新增 `github-issue` 與 `github-pr` 兩個薄 Skill，套用專案共用格式，第一版統一以 GitHub CLI `gh` 操作 Issue／PR／Review；commit／push 使用 `git`。GitHub MCP 不在本版範圍，不靜默切換通道，不新增 GitHub client 或修改第三方 Skill。
- Issue 支援建立與更新，包含 Change、父子／依賴關係、下一步、負責人與延後驗收。以明確關聯查重，保留既有人工內容。
- PR 分開提供建立、發布既有 PR 的版本，以及僅更新說明的操作。建立／發布在授權範圍內按需委派 Git Commit Writer、push；更新說明不提交或推送。
- 新增共用唯讀帳號檢查腳本，按 API／commit／push 操作核對 repository、`gh` actor、有效 Git 身分與 push 通道；Skill 解讀結果、共用規範與薄 rule 要求寫入前呼叫。身分不明或衝突時停止受影響寫入，不修改全域配置或登入；第一版不新增 hook。
- 定義共用 Issue、PR、Review 的必要資訊與 provenance 語意。預設保留工具、已知模型與原生 Session ID，機器只使用已配置中性別名；未知或明確要求不公開的值如實標示，不發布本機絕對路徑或原始 hostname。
- 建立可人工啟動的完整流程，規格發布、設計 Review、人類設計批准、實作發布、實作 Review、修正複審、真實資料等待及依授權結案分開記錄。
- 人類批准可由已授權 Agent 具名代記為 PR 事件，保存來源、範圍、版本及實際發布者，供跨機器接手信任；不要求使用者重複到 GitHub 留言，也不把 Agent 技術通過當成人類批准。
- 調整 Work Item 規範，允許 PR 保存正式交接報告；本地 Work Item 仍可丟棄、不進 Git、不跨 worktree 同步。Review 執行另由 `add-change-review-skill` 承接。

驗收須證明新 Session 不讀原對話或 Work Item，仍可由 Issue／PR 找到可取得的正式文件、版本及下一步；查重、帳號衝突、局部內容保留、提交範圍與等待驗收有可重播的通過／拒絕案例。安裝後 Claude Code、Codex、Antigravity 取得同一契約。

## Capabilities

### New Capabilities

- `github-change-handoff`: OpenSpec 與 GitHub 關聯、共用內容／身分契約、Issue／PR 建立更新、版本發布與跨 Session 交接。

### Modified Capabilities

- `work-item-records`: 明確區分本地草稿與 PR 正式交接報告，必要資訊不依賴 Work Item，且不因遠端交接而同步本地紀錄。

## Impact

- 主要來源為 `template/common/skills/github-issue/`、`template/common/skills/github-pr/`、新增的 managed `template/common/docs/github-handoff.md`，以及 `template/common/work-items/AGENTS.md`。
- 共用檢查腳本來源為 `template/common/scripts/github/check-identity.sh`，安裝為 `scripts/github/check-identity.sh`；新增 `template/common/.claude/rules/github-handoff.md` 薄入口並沿用 rule mirror，Codex 由 managed protocol 取得相同規範。
- `template/common/docs/agent-protocol.md`／`openspec-workflow.md` 加入適用範圍與短連結；`scripts/skills/install.sh` 將共用契約與其引用的流程 SVG 一起列為 managed assets。README、專案架構與工作流入口同步必要說明。
- 透過 installer 更新 `.claude/skills/`、`.agents/skills/` 與 managed 文件；不手動修改安裝目標，不變更第三方 OpenSpec 或 Ponytail Skills。
- 補入腳本的離線 PATH stub 行為測試、contract、暫存 repo 安裝／保留測試及有固定格式與正式證據位置的人工 Agent 情境驗收；不新增 Agent harness，不把模擬回覆當真實認證或遠端寫入。真實 `gh` 驗收須使用明確指定的測試 repository，未執行時如實列為未驗證。
- 不新增 Trello 整合、GitHub Projects 自動化、背景派工、跨機器 Session 啟動器、網路 Git hooks、自動合併／部署／archive 或專用 Review Agent。
