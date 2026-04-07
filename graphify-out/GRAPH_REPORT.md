# Graph Report - .  (2026-04-07)

## Corpus Check
- Corpus is ~43,091 words - fits in a single context window. You may not need a graph.

## Summary
- 19 nodes · 5 edges · 14 communities detected
- Extraction: 80% EXTRACTED · 20% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `Multi-Tool Compatibility Rules` - 2 edges
2. `wk-agent-ops Project Overview` - 1 edges
3. `PM/RD Two-Phase Workflow Separation` - 1 edges
4. `OpenSpec (Spec-Driven Development)` - 1 edges
5. `PM Agent` - 1 edges
6. `Claude Code` - 1 edges
7. `Gemini CLI` - 1 edges
8. `TDD 執行規範` - 1 edges
9. `Harness Engineering Protocol` - 1 edges
10. `D1 — AGENTS.md Coverage Audit` - 0 edges

## Surprising Connections (you probably didn't know these)
- `TDD 執行規範` --references--> `Harness Engineering Protocol`  [INFERRED]
  .claude/rules/tdd-enforcement.md → AGENTS.md
- `PM/RD Two-Phase Workflow Separation` --references--> `PM Agent`  [EXTRACTED]
  docs/architecture.md → docs/workflow/guide.md

## Hyperedges (group relationships)
- **Core Entropy Check Audits** — D1_audit, C1_audit, O1_audit [INFERRED]
- **Project Rules & Standards** — multitool_compat_rule, openspec_commit_rules, tdd_enforcement_rule [INFERRED]

## Communities

### Community 0 - "Multi-Tool Support"
Cohesion: 0.67
Nodes (3): Claude Code, Gemini CLI, Multi-Tool Compatibility Rules

### Community 1 - "Test-Driven Development"
Cohesion: 1.0
Nodes (2): Harness Engineering Protocol, TDD 執行規範

### Community 2 - "Agent Workflow"
Cohesion: 1.0
Nodes (2): OpenSpec (Spec-Driven Development), wk-agent-ops Project Overview

### Community 3 - "Agent Workflow"
Cohesion: 1.0
Nodes (2): PM/RD Two-Phase Workflow Separation, PM Agent

### Community 4 - "Entropy Auditing System"
Cohesion: 1.0
Nodes (1): entropy-check-drop-d1 Change

### Community 5 - "Agent Workflow"
Cohesion: 1.0
Nodes (1): D1 — AGENTS.md Coverage Audit

### Community 6 - "Cluster 6: C1 — Unused Code Audit"
Cohesion: 1.0
Nodes (1): C1 — Unused Code Audit

### Community 7 - "OpenSpec Process"
Cohesion: 1.0
Nodes (1): O1 — Stale OpenSpec Changes Audit

### Community 8 - "Entropy Auditing System"
Cohesion: 1.0
Nodes (1): entropy-counter PostToolUse Hook

### Community 9 - "Template Distribution"
Cohesion: 1.0
Nodes (1): Template Propagation System

### Community 10 - "Git Workflow"
Cohesion: 1.0
Nodes (1): Git Worktree Isolation

### Community 11 - "Agent Workflow"
Cohesion: 1.0
Nodes (1): RD Agent

### Community 12 - "OpenSpec Process"
Cohesion: 1.0
Nodes (1): OpenSpec Commit 規範

### Community 13 - "Agent Workflow"
Cohesion: 1.0
Nodes (1): Agents Configuration Guide

## Knowledge Gaps
- **17 isolated node(s):** `D1 — AGENTS.md Coverage Audit`, `C1 — Unused Code Audit`, `O1 — Stale OpenSpec Changes Audit`, `entropy-counter PostToolUse Hook`, `wk-agent-ops Project Overview` (+12 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Test-Driven Development`** (2 nodes): `Harness Engineering Protocol`, `TDD 執行規範`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Agent Workflow`** (2 nodes): `OpenSpec (Spec-Driven Development)`, `wk-agent-ops Project Overview`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Agent Workflow`** (2 nodes): `PM/RD Two-Phase Workflow Separation`, `PM Agent`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Entropy Auditing System`** (1 nodes): `entropy-check-drop-d1 Change`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Agent Workflow`** (1 nodes): `D1 — AGENTS.md Coverage Audit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 6: C1 — Unused Code Audit`** (1 nodes): `C1 — Unused Code Audit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `OpenSpec Process`** (1 nodes): `O1 — Stale OpenSpec Changes Audit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Entropy Auditing System`** (1 nodes): `entropy-counter PostToolUse Hook`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Template Distribution`** (1 nodes): `Template Propagation System`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Git Workflow`** (1 nodes): `Git Worktree Isolation`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Agent Workflow`** (1 nodes): `RD Agent`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `OpenSpec Process`** (1 nodes): `OpenSpec Commit 規範`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Agent Workflow`** (1 nodes): `Agents Configuration Guide`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `D1 — AGENTS.md Coverage Audit`, `C1 — Unused Code Audit`, `O1 — Stale OpenSpec Changes Audit` to the rest of the system?**
  _17 weakly-connected nodes found - possible documentation gaps or missing edges._