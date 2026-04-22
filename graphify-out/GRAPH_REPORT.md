# Graph Report - .  (2026-04-22)

## Corpus Check
- Corpus is ~46,286 words - fits in a single context window. You may not need a graph.

## Summary
- 233 nodes · 152 edges · 129 communities detected
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `Agents Configuration Guide` - 12 edges
2. `OpenSpec (Spec-Driven Development)` - 12 edges
3. `Multi-Tool Compatibility` - 12 edges
4. `Multi-Agent Collaboration Workflow Guide` - 10 edges
5. `wk-agent-ops Coding Conventions` - 8 edges
6. `Notify Hooks Architecture` - 7 edges
7. `entropy-check Skill (docs)` - 7 edges
8. `wk-agent-ops Project` - 6 edges
9. `wk-agent-ops Architecture Guide` - 6 edges
10. `Gemini CLI Hooks Guide` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Project Architecture Guide (Template)` --semantically_similar_to--> `wk-agent-ops Architecture Guide`  [INFERRED] [semantically similar]
  template/common/docs/architecture.md → docs/architecture.md
- `Coding Conventions Template` --semantically_similar_to--> `wk-agent-ops Coding Conventions`  [INFERRED] [semantically similar]
  template/common/docs/conventions.md → docs/conventions.md
- `Git Commit Writer Skill` --semantically_similar_to--> `git-commit-writer Skill (docs)`  [INFERRED] [semantically similar]
  template/common/skills/git-commit-writer/SKILL.md → docs/skills/git-commit-writer.md
- `Entropy Audit (D2/D3/C1/O1/R1)` --semantically_similar_to--> `entropy-check Skill (docs)`  [INFERRED] [semantically similar]
  template/common/skills/entropy-check/SKILL.md → docs/skills/entropy-check.md
- `wt-work Command` --semantically_similar_to--> `wt-new.sh Script`  [INFERRED] [semantically similar]
  docs/workflow/guide.md → openspec/changes/archive/2026-04-01-wt-lifecycle-scripts/proposal.md

## Hyperedges (group relationships)
- **Multi-Agent Collaboration Workflow (PM+RD+Worktree+OpenSpec)** — concept_pm_rd_separation, concept_worktree_workflow, concept_openspec, docs_workflow_guide [EXTRACTED 0.95]
- **AI CLI Notification Hook Integration (Claude/Gemini/Copilot+Telegram)** — concept_notify_hook_system, docs_hooks_claude, docs_hooks_gemini, docs_hooks_copilot, docs_notify_telegram [EXTRACTED 0.92]
- **OpenSpec Commit Pipeline (Archive+DocUpdate+GitCommit)** — skill_openspec_commit, skill_doc_updater, skill_git_commit_writer [EXTRACTED 0.97]
- **OpenSpec Commit Finalization Flow (archive + docs + commit)** — commit_opsx_archive_step, commit_docs_update_step, commit_git_commit_writer_step [EXTRACTED 0.97]
- **entropy-check Full Audit Suite (D1/D2/D3/C1/R1/O1)** — entropycheck_d1_audit, entropycheck_d3_audit, entropycheck_c1_audit, entropycheck_r1_audit, entropycheck_o1_audit [EXTRACTED 0.93]
- **Telegram Notify Evolution Chain (v1 → Format → Improvements)** — ai_cli_telegram_notify_proposal, telegram_notify_format_proposal, telegram_notify_improvements_design [INFERRED 0.85]
- **Entropy Management System: Check + Counter Hook + Watermark** — entropy_check_skill_change, entropy_counter_hook, entropy_state_watermark [EXTRACTED 0.95]
- **Worktree Lifecycle Command Suite: wt-new, wt-done, wt-resume** — wt_new_script, wt_done_script, wt_resume_script [EXTRACTED 0.93]
- **Copilot CLI Notification Hook Integration Flow** — registry_sh_copilot_functions, github_hooks_json, copilot_event_mapping, hook_sh_copilot_detection [EXTRACTED 0.95]
- **Template Profile Structure and Install CLI** — template_common_profile, template_python_profile, template_node_profile, install_sh_profile_based [EXTRACTED 0.95]
- **Entropy Check C1 False Positive Fix (Bash + Python)** — bash_false_positive_detection, bash_fix_all_files_count, python_false_positive_detection, python_fix_strip_trailing_comma [EXTRACTED 0.95]

## Communities

### Community 0 - "OpenSpec Worktree Workflow"
Cohesion: 0.2
Nodes (16): Git Worktree, Harness System (Agent Extension Kit), OpenSpec (Spec-Driven Development), PM/RD Two-Phase Separation, pm-start Command, Worktree Concurrent Workflow, wt-done Command, wt-work Command (+8 more)

### Community 1 - "Commit & Archive Pipeline"
Cohesion: 0.13
Nodes (16): Docs Update Step in Commit Flow, git-commit-writer Step in Commit Flow, OpenSpec Commit Workflow, opsx:archive Step in Commit Flow, Conventional Commits Format, Doc Updater Mode A (Uncommitted Changes), Doc Updater Mode B (Clean Working Tree), OpenSpec Commit Flow (+8 more)

### Community 2 - "Hook Infrastructure & Conventions"
Cohesion: 0.32
Nodes (12): CLAUDE_PROJECT_DIR Environment Variable, Gate Hook Pattern (Intentional Fail), Multi-Tool Compatibility, Silent Fail Pattern for Background Hooks, wk-agent-ops Coding Conventions, Claude Code Hooks Guide, GitHub Copilot Hooks Guide, Gemini CLI Hooks Guide (+4 more)

### Community 3 - "Project Config & Guidelines"
Cohesion: 0.25
Nodes (11): Agents Configuration Guide, Claude Code Project Config (CLAUDE.md), install.sh Template Propagation Script, Karpathy Guidelines (Level 1), Development Protocol by Task Scale (L1/L2/L3), TDD Enforcement Rules, Template Propagation Pattern, wk-agent-ops Architecture Guide (+3 more)

### Community 4 - "AI CLI Notification System"
Cohesion: 0.22
Nodes (10): AI CLI Telegram Notify Design, ~/.config/ai-notify/config, Hook Lifecycle (AI CLI Events), AI CLI Notification Hook System, NOTIFY_LEVEL Config, Notify Hooks Architecture, Telegram Notify Hook Setup, notify lib/registry.sh (+2 more)

### Community 5 - "Entropy Tracking & Auditing"
Cohesion: 0.29
Nodes (8): Entropy Audit (D2/D3/C1/O1/R1), C1 — Unused Code Audit, entropy-counter PostToolUse Hook, D3 — Dead References Audit, openspec/.entropy-state Watermark File, R1 — Refactor Candidates Audit, entropy-check Skill (docs), Entropy Check Skill

### Community 6 - "Entropy Check Drop-D1 Change"
Cohesion: 0.4
Nodes (5): Change: entropy-check-drop-d1, Entropy Check Context Detection, Entropy Check Watermark Update, Rationale: D1 removed due to third-party skill noise, Entropy Check Spec

### Community 7 - "Entropy Check Skill Refactor"
Cohesion: 0.4
Nodes (5): entropy-check Skill (change), entropy-counter-hook PostToolUse Hook (change), Entropy Management Proposal, Rationale: Archive Count Trigger vs Time Schedule, openspec/.entropy-state Watermark File (change)

### Community 8 - "Worktree Lifecycle Scripts"
Cohesion: 0.4
Nodes (5): wt-done.sh Script, Worktree Lifecycle Scripts Proposal, wt-new.sh Script, Rationale: wt-new Auto-Detect via Worktree Directory Existence, wt-resume.sh Script

### Community 9 - "Copilot CLI Hook Integration"
Cohesion: 0.4
Nodes (5): Copilot CLI Event Mapping (sessionEnd/userPromptSubmitted), hook.sh Copilot CLI Tool Detection, Notify Restructure Copilot Design, Rationale: userPromptSubmitted Over errorOccurred, registry.sh Copilot CLI Functions

### Community 10 - "Telegram Notify Hook Detail"
Cohesion: 0.5
Nodes (4): telegram-notify.sh Hook Script, Session Identification in Notifications, Tool Name Detection (env var fallback), Telegram Notify Hook Spec

### Community 11 - "Git Commit Writer Design"
Cohesion: 0.5
Nodes (4): Git Commit Writer Proposal, Rationale: Haiku Dispatch for Mechanical Commit Formatting, git-commit-writer Skill (change), openspec-commit Skill (change context)

### Community 12 - "Entropy C1 Bug Fixes"
Cohesion: 0.5
Nodes (4): Bash Fix: All-Files Count Instead of Other-Files Filter, Entropy Check C1 Fix Design, Python Fix: Strip Trailing Comma from Import Name, Rationale: Bash Word-Boundary grep Portability Risk

### Community 13 - "Template Profile Installation"
Cohesion: 0.5
Nodes (4): install.sh Profile-Based CLI Interface, Rationale: Skills Only in Common Profile, Template Common Profile Directory, Template Profile Install Design

### Community 14 - "Notification Icon Design"
Cohesion: 0.67
Nodes (3): Action Required Orange Icon (🟠), Rationale: Orange vs Red Icon Semantics, Telegram Notify Orange Icon Proposal

### Community 15 - "wt-work Cross-Machine"
Cohesion: 1.0
Nodes (2): wt-work Branch Resolution (local/remote/new), wt-work Cross-Machine Spec

### Community 16 - "Auto-Branch on OpenSpec"
Cohesion: 1.0
Nodes (2): Auto-Create Feature Branch on OpenSpec New Design, PostToolUse Hook Mechanism

### Community 17 - "TDD Rules Placement"
Cohesion: 1.0
Nodes (2): Rationale: TDD Rules in rules/ Not in Skill, TDD Enforcement Rules Spec

### Community 18 - "Entropy D3 Autofix"
Cohesion: 1.0
Nodes (2): Rationale: D3 Auto-Fix Uses AI Search Not Regex-Only, Entropy Check D3 Autofix Spec

### Community 19 - "wt-work Rename Rationale"
Cohesion: 1.0
Nodes (2): wt-work Command Spec, Rationale: wt-new to wt-work Rename (No Alias)

### Community 20 - "Entropy C1 Fix Proposal"
Cohesion: 1.0
Nodes (2): Bash Function False Positive Detection Bug, Entropy Check C1 Fix Proposal

### Community 21 - "Copilot Hooks Config"
Cohesion: 1.0
Nodes (2): .github/hooks/hooks.json (Copilot Hook Config), Rationale: Copilot Hooks Per-Repo vs Global

### Community 22 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Single Command for Commit Finalization

### Community 23 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Template Profile System

### Community 24 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Common Profile (template/common)

### Community 25 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Python Profile (template/python)

### Community 26 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Node.js Profile (template/node)

### Community 27 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): D1 — AGENTS.md Coverage Audit

### Community 28 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): D2 — Docs Completeness Audit

### Community 29 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): O1 — Stale Active Changes Audit

### Community 30 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Conventional Commits Format (docs)

### Community 31 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Notification hook.sh Interface

### Community 32 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): NOTIFY_LEVEL Config Key

### Community 33 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-work Script (README)

### Community 34 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-done Script (README)

### Community 35 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-resume Script (README)

### Community 36 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): pm-start Script (README)

### Community 37 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): openspec-branch-creator PostToolUse Hook (README)

### Community 38 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: template-profile-structure

### Community 39 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: entropy-check-r1-watermark

### Community 40 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: pm-start

### Community 41 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: notify-test-harness

### Community 42 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: doc-updater

### Community 43 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: tdd-enforcement-rules

### Community 44 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: entropy-check-d3-autofix

### Community 45 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: workflow-scripts

### Community 46 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: entropy-counter-hook

### Community 47 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Spec: pre-commit-quality-gate

### Community 48 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): OpenSpec Branch Creator Hook Spec

### Community 49 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Install Profile CLI Spec

### Community 50 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-resume Spec

### Community 51 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Check C1 Unused Code Spec

### Community 52 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt zsh Completion Spec

### Community 53 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): OpenSpec Commit Spec

### Community 54 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Feature Branch (git)

### Community 55 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Idempotent Hook Registration

### Community 56 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): CLAUDE_PROJECT_DIR Environment Variable

### Community 57 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): ~/.claude/settings.json

### Community 58 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Template Profiles

### Community 59 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Skills Dual-Destination Installation

### Community 60 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): config.sh (Telegram Notify)

### Community 61 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): registry.sh (Hook Registration)

### Community 62 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Copilot CLI Hook Registration (hooks.json)

### Community 63 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): /notify-setup Claude Code Command

### Community 64 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Check Audit Routing Table

### Community 65 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-resume Command

### Community 66 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): _wt zsh Completion Script

### Community 67 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): entropy-check-drop-d1 Design

### Community 68 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Change: 2026-03-27-doc-updater

### Community 69 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): doc-updater Archive Design

### Community 70 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Agent + Skill dual-file mode for doc-updater

### Community 71 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Use Sonnet (not Haiku) for doc-updater

### Community 72 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Change: 2026-04-01-notify-hook-tool-session

### Community 73 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): notify-hook-tool-session Design

### Community 74 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: TOOL_NAME passed as CLI param

### Community 75 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Session ID extracted from stdin JSON

### Community 76 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Notify Test Harness Spec

### Community 77 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): hook.sh Dry-Run Mode

### Community 78 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Notify Hook Spec (notify-hook-tool-session)

### Community 79 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Tool Detection via CLI Param ($2) with Env Fallback

### Community 80 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Session ID in Notification Title

### Community 81 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): TDD Enforcement Gate Design

### Community 82 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): TDD Enforcement Gate Proposal

### Community 83 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Use npm test Not Framework-Specific Binary

### Community 84 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Pre-Commit Quality Gate Spec

### Community 85 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Check Revision Proposal

### Community 86 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Check Revision Design

### Community 87 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Remove H1/O2/O3 Audits (No Stubs)

### Community 88 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Check R1 Watermark Spec

### Community 89 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Check C1 Unused Code Spec

### Community 90 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): WT Workflow Session Resume Design

### Community 91 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): WT Workflow Session Resume Proposal

### Community 92 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: wt-work Resume Path Forces opsx:apply (Idempotent)

### Community 93 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-resume Command Spec

### Community 94 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): AI CLI Telegram Notify Proposal

### Community 95 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): telegram-notify install.sh Wizard

### Community 96 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): notify lib/config.sh

### Community 97 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: registry.sh Idempotent Hook Registration

### Community 98 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Notify Format Proposal

### Community 99 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Notify Format Design

### Community 100 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Message Format (Color Signal Icons)

### Community 101 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Notify Improvements Design

### Community 102 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Auto-Create Feature Branch on OpenSpec New Proposal

### Community 103 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): OpenSpec Branch Creator Hook Spec (change)

### Community 104 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): wt-work Cross-Machine Branch Resolution Spec (change)

### Community 105 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: PostToolUse Hook over Rule or Wrapper Skill

### Community 106 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: wt-work Branch Resolution Order (local/remote/new)

### Community 107 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Management Tasks

### Community 108 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): entropy-counter hook.sh

### Community 109 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): NOTIFY_LEVEL Configuration (all/notify_only)

### Community 110 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Management Design

### Community 111 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Counter Hook Spec (change)

### Community 112 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Entropy Context Detection (harness/openspec/standard)

### Community 113 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: PostToolUse Hook for Archive Detection

### Community 114 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Git Commit Writer Design

### Community 115 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Git Commit Writer Spec (change)

### Community 116 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Scope Only When OpenSpec Change Present

### Community 117 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Worktree Lifecycle Scripts Design

### Community 118 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Notify Title Case Proposal

### Community 119 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): telegram-notify hook.sh Script

### Community 120 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Telegram Notify Orange Icon Design

### Community 121 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Python Import False Positive Detection Bug

### Community 122 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Template Profile Install Proposal

### Community 123 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Template Python Profile Directory

### Community 124 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Template Node Profile Directory

### Community 125 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Rationale: Profile Directory Directly Under template/

### Community 126 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Notify Restructure Copilot Proposal

### Community 127 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): scripts/notify/ Umbrella Directory

### Community 128 - "Isolated Concept"
Cohesion: 1.0
Nodes (1): Tool Detection Environment Variable Chain

## Knowledge Gaps
- **174 isolated node(s):** `Claude Code Project Config (CLAUDE.md)`, `Project Architecture Guide (Template)`, `Coding Conventions Template`, `Harness System (Agent Extension Kit)`, `TDD Enforcement Rules` (+169 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `wt-work Cross-Machine`** (2 nodes): `wt-work Branch Resolution (local/remote/new)`, `wt-work Cross-Machine Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Auto-Branch on OpenSpec`** (2 nodes): `Auto-Create Feature Branch on OpenSpec New Design`, `PostToolUse Hook Mechanism`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `TDD Rules Placement`** (2 nodes): `Rationale: TDD Rules in rules/ Not in Skill`, `TDD Enforcement Rules Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Entropy D3 Autofix`** (2 nodes): `Rationale: D3 Auto-Fix Uses AI Search Not Regex-Only`, `Entropy Check D3 Autofix Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `wt-work Rename Rationale`** (2 nodes): `wt-work Command Spec`, `Rationale: wt-new to wt-work Rename (No Alias)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Entropy C1 Fix Proposal`** (2 nodes): `Bash Function False Positive Detection Bug`, `Entropy Check C1 Fix Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Copilot Hooks Config`** (2 nodes): `.github/hooks/hooks.json (Copilot Hook Config)`, `Rationale: Copilot Hooks Per-Repo vs Global`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Single Command for Commit Finalization`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Template Profile System`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Common Profile (template/common)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Python Profile (template/python)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Node.js Profile (template/node)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `D1 — AGENTS.md Coverage Audit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `D2 — Docs Completeness Audit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `O1 — Stale Active Changes Audit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Conventional Commits Format (docs)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Notification hook.sh Interface`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `NOTIFY_LEVEL Config Key`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-work Script (README)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-done Script (README)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-resume Script (README)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `pm-start Script (README)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `openspec-branch-creator PostToolUse Hook (README)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: template-profile-structure`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: entropy-check-r1-watermark`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: pm-start`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: notify-test-harness`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: doc-updater`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: tdd-enforcement-rules`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: entropy-check-d3-autofix`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: workflow-scripts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: entropy-counter-hook`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Spec: pre-commit-quality-gate`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `OpenSpec Branch Creator Hook Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Install Profile CLI Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-resume Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Check C1 Unused Code Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt zsh Completion Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `OpenSpec Commit Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Feature Branch (git)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Idempotent Hook Registration`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `CLAUDE_PROJECT_DIR Environment Variable`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `~/.claude/settings.json`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Template Profiles`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Skills Dual-Destination Installation`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `config.sh (Telegram Notify)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `registry.sh (Hook Registration)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Copilot CLI Hook Registration (hooks.json)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `/notify-setup Claude Code Command`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Check Audit Routing Table`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-resume Command`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `_wt zsh Completion Script`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `entropy-check-drop-d1 Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Change: 2026-03-27-doc-updater`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `doc-updater Archive Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Agent + Skill dual-file mode for doc-updater`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Use Sonnet (not Haiku) for doc-updater`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Change: 2026-04-01-notify-hook-tool-session`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `notify-hook-tool-session Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: TOOL_NAME passed as CLI param`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Session ID extracted from stdin JSON`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Notify Test Harness Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `hook.sh Dry-Run Mode`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Notify Hook Spec (notify-hook-tool-session)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Tool Detection via CLI Param ($2) with Env Fallback`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Session ID in Notification Title`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `TDD Enforcement Gate Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `TDD Enforcement Gate Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Use npm test Not Framework-Specific Binary`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Pre-Commit Quality Gate Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Check Revision Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Check Revision Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Remove H1/O2/O3 Audits (No Stubs)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Check R1 Watermark Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Check C1 Unused Code Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `WT Workflow Session Resume Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `WT Workflow Session Resume Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: wt-work Resume Path Forces opsx:apply (Idempotent)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-resume Command Spec`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `AI CLI Telegram Notify Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `telegram-notify install.sh Wizard`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `notify lib/config.sh`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: registry.sh Idempotent Hook Registration`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Notify Format Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Notify Format Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Message Format (Color Signal Icons)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Notify Improvements Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Auto-Create Feature Branch on OpenSpec New Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `OpenSpec Branch Creator Hook Spec (change)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `wt-work Cross-Machine Branch Resolution Spec (change)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: PostToolUse Hook over Rule or Wrapper Skill`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: wt-work Branch Resolution Order (local/remote/new)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Management Tasks`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `entropy-counter hook.sh`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `NOTIFY_LEVEL Configuration (all/notify_only)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Management Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Counter Hook Spec (change)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Entropy Context Detection (harness/openspec/standard)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: PostToolUse Hook for Archive Detection`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Git Commit Writer Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Git Commit Writer Spec (change)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Scope Only When OpenSpec Change Present`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Worktree Lifecycle Scripts Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Notify Title Case Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `telegram-notify hook.sh Script`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Telegram Notify Orange Icon Design`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Python Import False Positive Detection Bug`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Template Profile Install Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Template Python Profile Directory`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Template Node Profile Directory`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Rationale: Profile Directory Directly Under template/`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Notify Restructure Copilot Proposal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `scripts/notify/ Umbrella Directory`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Isolated Concept`** (1 nodes): `Tool Detection Environment Variable Chain`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Multi-Tool Compatibility` connect `Hook Infrastructure & Conventions` to `OpenSpec Worktree Workflow`, `Project Config & Guidelines`, `AI CLI Notification System`, `Entropy Tracking & Auditing`, `Copilot CLI Hook Integration`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `OpenSpec (Spec-Driven Development)` connect `OpenSpec Worktree Workflow` to `Commit & Archive Pipeline`, `Project Config & Guidelines`, `Entropy Tracking & Auditing`, `Entropy Check Drop-D1 Change`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `Agents Configuration Guide` connect `Project Config & Guidelines` to `Commit & Archive Pipeline`, `Hook Infrastructure & Conventions`, `Entropy Tracking & Auditing`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `OpenSpec (Spec-Driven Development)` (e.g. with `PM/RD Two-Phase Separation` and `Entropy Check Spec`) actually correct?**
  _`OpenSpec (Spec-Driven Development)` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `Multi-Tool Compatibility` (e.g. with `GEMINI_PROJECT_DIR Environment Variable` and `CLAUDE_PROJECT_DIR Environment Variable`) actually correct?**
  _`Multi-Tool Compatibility` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Claude Code Project Config (CLAUDE.md)`, `Project Architecture Guide (Template)`, `Coding Conventions Template` to the rest of the system?**
  _174 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Commit & Archive Pipeline` be split into smaller, more focused modules?**
  _Cohesion score 0.13 - nodes in this community are weakly interconnected._