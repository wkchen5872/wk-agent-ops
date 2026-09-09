---
name: bulk-read-routing
description: Use for broad, read-heavy codebase discovery when relevant locations are unknown. Delegate once to the named read-only agent, then verify relevant evidence in the parent. Do not use for small or already-located work.
---

# Bulk Read Routing

Use this skill only when relevant code locations are unknown and broad repository discovery is expected to dominate the work. Do not use when targeted search has already located the relevant files or symbols.

1. For this discovery phase, spawn exactly one custom subagent named `bulk-reader-agent`. Do not spawn a generic agent or a second discovery agent.
2. Give it the user's question, repository-relative scope, and the evidence needed from discovery.
3. Tell it to perform only bounded, read-only discovery and wait for its findings.
4. If the named agent is unavailable, report the missing user-level provider configuration and perform targeted discovery in the parent. Do not substitute another subagent.
5. Treat its paths, symbols, and quotes as discovery evidence, not final conclusions.
6. In the parent, verify every quote or claim used for an engineering decision with targeted reads.
7. Keep root-cause analysis, debugging, security, concurrency, architecture, final conclusions, and edits in the parent.
8. If confidence is low, continue with targeted parent reads instead of spawning more agents.
9. Do not invoke this skill again during the same discovery phase.
