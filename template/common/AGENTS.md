# AGENTS.md

<!-- This file is project-owned. Add your project's mission, module map, and
     business know-how here. It is copied once by install.sh and never overwritten,
     so your additions are safe. The shared agent operating protocol is NOT inlined
     here — it lives in a managed doc (see the pointer below) and updates on install. -->

## Project

<!-- One paragraph: what this project is and any know-how an agent needs that the
     code does not make obvious. Replace this placeholder. -->

## Agent Operating Protocol

This project follows the shared agent operating protocol. **Before any task, read
`docs/agent-protocol.md`** — it defines what to read first, the hard prohibitions,
the task-scale protocol, and the done criteria.

That file is managed by wk-agent-ops and refreshed by re-running the installer; do
not edit it here. Keep project-specific rules in this file or under `docs/`.

## Work Item 協作紀錄

需要保存跨回合／跨 Session 的臨時協作紀錄時，先讀 `work-items/AGENTS.md`；
該文件是這套規範的唯一來源。

## GitHub 協作（選用）

使用 GitHub Issue／PR 時，以已安裝的 `github-issue`、`github-pr`、`change-review` Skill
操作；貼文格式、寫入前核對與可選的帳號限制都以 Skill 為準。開發流程在哪些時點接上
GitHub，見 `docs/github-handoff.md`；是否可以開始實作，見 `docs/openspec-workflow.md`。
