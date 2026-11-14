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

## GitHub 交接（選用）

使用 GitHub Issue／PR 交接 Change 時，先讀 `docs/github-handoff.md`；寫入前的目標與
操作核對、可選的帳號限制與設計批准的來源都以該文件為準。
