# Proposal

## Why

改成多 agent 開發後，commit 與 GitHub 貼文的署名少了一半資訊。現在的規則是只記 root session（開啟該對話的 session）的工具與 model；
root 把 commit、Issue、PR 委派給 subagent 時，subagent 被明文禁止記自己（「MUST NOT substitute its own model」），所以事後查不到是哪個 agent、哪個 model 實際送出這筆紀錄。
另外，交接迴圈的實作者每輪直接 `git commit`，沒有經過 `git-commit-writer`，trailer 變成 Claude Code 內建的
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`（模型名放在工具欄）。最近兩個 change 的實作 commit 都是這樣
（例如 `87b5f9d`、`ed293ac`、`aa58419`）。這類 commit 和經過 skill 的工具名格式混在一起，用 `git log` 追查時要分兩種查法。

## What Changes

- 內容作者的規則不變：`Co-Authored-By: <工具>` 和 `AI-Assisted-By: <root model>` 仍然記錄 root session。
  交接迴圈的每個角色、使用者另開的 session，各自就是 root。
- 新增委派紀錄。只有實際寫入紀錄的 subagent 才多加一行，寫自己的 agent 名稱和 model：
  - `git-commit-writer-agent`（Claude、Codex）在 `AI-Assisted-By` 後加 `Committed-By: <agent 名稱> (<model>)`；
  - `github-issue-agent`、`github-pr-agent`（Claude、Codex）在 Author 區塊最後加 `Posted-By: <agent 名稱> (<model>)`。
  root 自己提交或發文時不加這一行；其他 subagent（例如 `doc-updater-agent`）也不記。
- 交接迴圈範本 `roles.example.yaml` 的實作者 prompt（Claude，以及註解中的 Pi 範例）改成用 `git-commit-writer` skill 提交，不再直接 `git commit`。
  `git-commit-writer` 新增選填輸入 `subject`，讓 commit 標題仍是 `feat(<change>): …`／`fix(<change>): address <review-id>`。
- 讀取 Author 的地方（`change-review` 找實作者 session）會略過 `Posted-By`，不把送出貼文的 agent 當成實作者。

不做：commit-msg hook 檢查、交件單 `agent` 欄位、`handoff-author` 的 model 來源、Claude Code 的 `attribution.commit` 設定、改寫舊 commit。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `git-commit-writer`：委派的 commit agent 加 `Committed-By`；新增選填輸入 `subject`。
- `github-issue`：委派的 Issue agent 在 Author 加 `Posted-By`。
- `github-pr`：委派的 PR agent 在 Author 加 `Posted-By`；讀取 Author 時不把 `Posted-By` 當成作者。
- `agent-crew-launcher`：範例實作者範本改用 `git-commit-writer` 提交。

## Impact

- Agent 定義：`template/common/.claude/agents/{git-commit-writer,github-issue,github-pr}-agent.md`，`template/common/.codex/agents/` 對應的三個 `.toml`。
- Skill：`git-commit-writer`、`github-issue`、`github-pr`、`change-review`、`openspec-commit`（委派段落）、`agent-handoff/roles.example.yaml`。
- 規格：`openspec/specs/` 下的 git-commit-writer、github-issue、github-pr、agent-crew-launcher。
- 測試：`tests/test_agents_dir.sh`、`tests/test_openspec_commit.sh`、`tests/acceptance/{git-commit-writer,github-issue,openspec-commit}.md`。
- 文件：`AGENTS.md`（git-commit-writer-agent 段落、Skill 與 Agent 邏輯一致性）。
- 已安裝的 repo：重跑 `scripts/skills/install.sh` 會更新 agent 和 skill。`.agent-handoff/roles.yaml` 只在不存在時才建立，所以已有的檔案要手動更新實作者 prompt。
- Hook：不涉及 Hook 腳本。
