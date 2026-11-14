# Proposal

## Why

Issue [#17](https://github.com/wkchen5872/wk-agent-ops/issues/17) 記錄了使用者已授權實作，Agent 卻仍要求確認 GitHub 帳號本人身分與批准記錄者資格的重複關卡；PR #15 又因缺少平台批准留言而停在 Apply 前。需要讓真實且範圍明確的使用者指示可直接支援接續工作，同時保留跨 Session 可追查的來源與版本。

## What Changes

- **BREAKING**：移除一般交接中「批准者必須提供 GitHub 帳號」「記錄者須另列信任名單」「Apply 必須先有 PR 批准留言」的前置條件。
- 已有明確使用者指示且可對應 Change、設計版本與實作範圍時，直接沿用；不追問 API 帳號是否本人、不要求重複授權。只有建立規格的請求不等於授權實作。
- PR 批准紀錄作為獲授權發布的交接證據，保留來源、範圍、版本、發布者及已知時間；未知人類帳號可省略，不冒充真人。
- 跨 Session 接手時區分當前使用者指示、可追查的既有交接與只有技術 pass 的情形；來源缺失、範圍衝突或設計實質改變才釐清。
- 保留完整 repo／operation／授權／能力核對、明確帳號限制與寫後回讀；不從 repo 存取能力推導授權。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `github-change-handoff`: 簡化批准來源與記錄方式，解除本人帳號、專屬記錄者及 PR 事件的重複關卡。
- `github-pr`: reply 可如實記錄既有使用者指示，批准整合不再引入另一套帳號認證。
- `change-review`: 保留技術判定與人類指示的區別，移除批准者帳號及記錄者資格的舊要求。

## Impact

- 來源：`template/common/docs/github-handoff.md` 第 4.3／6.3／9 節及相關案例、`template/common/docs/openspec-workflow.md`、GitHub／Review Skills 與 references，以及必要的交接圖文。
- 經 `scripts/skills/install.sh` 同步 managed 文件與 Claude Code／Codex／Antigravity 共用入口；上游產生的 OpenSpec skills 不直接修改，從本 repo 擁有的共用規範整合。
- 測試：`tests/test_github_handoff.sh`、`tests/test_change_review.sh`、受影響的 workflow 與 installer 檢查、離線語意重播。
- 不處理 Issue #18 的 Author 精簡或 #19 的 commit 引用；不改寫歷史留言、不更動 GitHub branch protection、不自動發布、合併或結案。原 `improve-change-review-local-handoff` 留在其分支，待本修正完成後再接續。
