# 🛡️ Harness Engineering Protocol

Version: 1.0.0
Role: This is the mandatory operational framework for AI agents.

## 1. Core Mandates
As an AI developer agent, you must operate within the "Verification Boundary" defined by this project's Harness. All changes MUST be verified before completion.

## 2. Execution Prerequisites
Before performing any task, concurrently analyze:
- **Architecture Guide:** `docs/architecture.md` (Defines module boundaries and data flow).
- **Coding Conventions:** `docs/conventions.md` (Defines style, naming, and prohibited patterns).
- **OpenSpec Specs:** `openspec/specs/` (The source of truth for requirements).

## 3. The Autonomous Loop (SOP)
1.  **Assertive TDD:** Write or update tests based on the Spec *before* implementation.
2.  **Compliant Implementation:** Write code adhering to `architecture.md` and `conventions.md`.
3.  **Automated Scan:** Execute `/opsx:verify` (Claude Code) or `/openspec-verify-change` (all AI CLI tools), plus native project tools (Linter, Type Check, Tests).
4.  **Self-Healing:** If verification fails, analyze logs, fix the implementation, and repeat until green.

## 4. Prohibited Actions
- ❌ **No Warning Suppression:** Never use `// @ts-ignore`, `any`, or skip lint errors.
- ❌ **No Scope Creep:** Do not implement features outside the OpenSpec definition.
- ❌ **No Structural Breach:** Do not violate the dependency rules in `architecture.md`.

## 5. Definition of Done (DoD)
- [ ] `/opsx:verify` (or equivalent) returns success (Exit Code 0).
- [ ] Aim for 80%+ test coverage for the modified logic path. If not met, highlight in summary and explain why.
- [ ] No regression in existing tests.
- [ ] Documentation (README/Docs) is synced with changes.

---

## 6. AI Coding Principles

> Which protocol to use depends on task scale. This three-tier framework prevents small tasks from being over-engineered and large tasks from lacking structure.

### Level 1 — Small Tasks (daily edits, single skill/rule adjustments)

Follow **Karpathy Guidelines**:

**Think Before Acting**
- State assumptions explicitly before implementing. If multiple interpretations exist, present them — don't pick silently.
- If something is unclear, stop and ask. Do not guess and code.

**Simplicity First**
- No features, abstractions, or configurability beyond what was explicitly asked.
- No error handling for impossible scenarios.
- If a solution can be 50 lines, don't write 200.

**Surgical Changes**
- Edit only the code directly required by the request.
- Do not improve, refactor, or reformat adjacent code.
- Do not delete pre-existing dead code unless explicitly asked.
- Every changed line must trace directly to the user's request.

### Level 2 — Medium Features (new skill, new agent, new workflow)

Use the **ECC Feature-Dev** flow:

1. **Discovery** — clarify requirements and acceptance criteria
2. **Codebase Exploration** — understand existing code and integration points
3. **Clarifying Questions** — ask targeted questions, wait for response
4. **Architecture Design** — propose design, wait for approval before implementing
5. **Implementation** — TDD preferred, keep commits small and focused
6. **Quality Review** — address only in-scope issues (follow Surgical Changes principle)

### Level 3 — Architectural Changes (cross-module design, multi-skill systems)

Use the **Superpowers** full pipeline:

1. **Brainstorming** — clarify one question at a time, propose 2-3 approaches, get design approval
2. **Writing-Plans** — produce fine-grained task plan (each step includes test commands and expected output)
3. **Executing-Plans** — follow the plan step by step; stop immediately at any blocker and ask

> **Note:** Level 3 design docs and plan docs only have long-term value for architectural tasks. Forcing this pipeline on Level 1/2 tasks is itself complexity — a violation of Simplicity First.
