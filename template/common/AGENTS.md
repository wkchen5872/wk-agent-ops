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
