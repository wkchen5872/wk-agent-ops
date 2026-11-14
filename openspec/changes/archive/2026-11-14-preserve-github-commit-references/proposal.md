# Proposal

## Why

Issue #19 指出提交入口沒有要求保留已確認的 GitHub Issue／PR 關聯，導致只讀 Git 歷史時不容易追查協作來源。現有三個 open Issues 中，#13 與 #17 的功能已在 main 並封存；本 Change 只補齊剩餘的 commit 引用缺口，不重做既有功能。

## What Changes

- 對本次提交直接處理且已確認的 Issue／PR，輸出不觸發自動關閉的 `Refs: ...`；無關聯仍正常提交。
- 定義直接工作與 references／depends-on 的區別、同 repo 與跨 repo 格式、去重與未知／衝突處理。
- 統一 git-commit-writer Skill、Claude／Codex commit agent，以及 openspec-commit／github-pr create 的關聯交接。
- 提供可重播案例與最小必要自動化驗證，保留 Conventional Commits、既有 attribution、archive guard 與 scoped commit 邊界。
- 不新增操作授權，不自動 merge／close，不重寫歷史 commit，不為純 GitHub 操作建立額外 commit。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `git-commit-writer`: 提交保留經確認的直接 GitHub 工作關聯，跨 provider 行為一致。
- `openspec-commit`: 在原有 archive／docs／commit 流程交接已確認的關聯，不因選用 metadata 增加遠端操作。
- `github-pr`: create 的必要提交使用當時已知的關聯；PR 建立後不追補歷史提交。

## Impact

- 來源：`template/common/skills/git-commit-writer/`、`template/common/.claude/agents/git-commit-writer-agent.md`、`template/common/.codex/agents/git-commit-writer-agent.toml`、`template/common/skills/openspec-commit/`、`template/common/skills/github-pr/`；必要時更新共用契約的 Git commit 引用說明。
- 透過 installer 更新受管理副本，更新相關範例、文件及 `tests/test_openspec_commit.sh`／`tests/test_github_pr_publication.sh`。
- 直接實作來源：[Issue #19](https://github.com/wkchen5872/wk-agent-ops/issues/19)。#13 的本地 Review 與 #17 的批准簡化為既有回歸邊界，不是本次直接處理的 Issue。
- 不新增 GitHub API wrapper、hook、套件依賴或帳號認證流程。
