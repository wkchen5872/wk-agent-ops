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
