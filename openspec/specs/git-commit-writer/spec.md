# Spec: git-commit-writer

## Purpose

A skill that generates and executes Conventional Commits messages, optionally using openspec change context to derive the scope and subject.

## Requirements

### Requirement: Generate commit message from openspec change context
`git-commit-writer` SHALL validate and directly use explicit `archive_path` and
`change_id` inputs when they are supplied. Standalone auto-detection SHALL be
used only when explicit context is absent, and SHALL apply an OpenSpec scope
only when the candidate is positively associated with the current branch or
the final staged diff. The existence of exactly one active change alone MUST
NOT be treated as association evidence.

#### Scenario: Archive path provided explicitly
- **WHEN** `archive_path` and `change_id` are passed by `openspec-commit`
- **THEN** the skill verifies that `<archive_path>` exists
- **AND** reads `<archive_path>/proposal.md`
- **AND** formats `<type>(<change_id>): <subject>`

#### Scenario: Explicit archive path is missing
- **WHEN** a supplied `archive_path` does not exist
- **THEN** the skill stops before staging or committing

#### Scenario: Standalone active change associated by branch
- **WHEN** no explicit context is supplied
- **AND** the current branch is exactly `feature/<change-id>`
- **AND** `<change-id>` identifies an active OpenSpec change
- **THEN** the skill may use that active change as commit context

#### Scenario: Standalone active change associated by staged path
- **WHEN** no explicit context is supplied
- **AND** the final staged diff contains a path under `openspec/changes/<change-id>/`
- **AND** `<change-id>` identifies an active OpenSpec change
- **THEN** the skill may use that active change as commit context

#### Scenario: Standalone archive associated by staged path
- **WHEN** no explicit context is supplied
- **AND** the final staged diff contains a path under one exact archived change directory
- **THEN** the skill may use that archive and its change ID as commit context

#### Scenario: Sole active change is unrelated
- **WHEN** no explicit context is supplied
- **AND** exactly one active change exists
- **AND** neither the current branch nor any staged path associates the commit with that change
- **THEN** the skill MUST ignore the active change and use staged-diff-only context without an OpenSpec scope

#### Scenario: Multiple associated standalone candidates
- **WHEN** no explicit context is supplied and multiple positively associated candidates remain
- **THEN** the skill asks the user to select one when the host supports
  interactive questions
- **AND** otherwise stops and returns the candidates to its caller
- **AND** MUST NOT choose the first

### Requirement: Generate commit message without openspec context
When no explicit or positively associated OpenSpec context is available, the
skill SHALL generate a Conventional Commits message without scope, derived
from `git diff --cached`.

#### Scenario: No active change
- **WHEN** `openspec list --json` returns no active changes
- **THEN** the skill formats `<type>: <subject>` using git diff content as context

#### Scenario: Active changes have no association evidence
- **WHEN** one or more active changes exist but none match the current feature branch or staged OpenSpec paths
- **THEN** the skill formats `<type>: <subject>` from the staged diff
- **AND** MUST NOT read an unrelated proposal to infer the type, subject, or body

### Requirement: Infer commit type
The skill SHALL infer the correct Conventional Commits type from the nature of the staged changes.

#### Scenario: Type inference from proposal
- **WHEN** proposal.md is available
- **THEN** type is derived from the "What Changes" section (feat/fix/refactor/docs/chore/test)

#### Scenario: Type inference from diff only
- **WHEN** no proposal is available
- **THEN** type is inferred from file paths and diff content

### Requirement: Execute commit without confirmation
The skill SHALL execute `git add -A` immediately before reading the cached diff
and committing, without a separate confirmation prompt. It MUST stop when the
staged diff is empty.

#### Scenario: Successful commit
- **WHEN** the worktree contains intended feature, archive, and documentation
  changes
- **THEN** the skill runs `git add -A`
- **AND** derives the message from `git diff --cached`
- **AND** executes `git commit -m "<message>"`
- **AND** prints the short commit hash

#### Scenario: Empty staged diff
- **WHEN** `git add -A` produces no staged changes
- **THEN** the skill reports that there is nothing to commit and stops

#### Scenario: Pre-commit hook failure
- **WHEN** `git commit` fails due to a pre-commit hook
- **THEN** the skill fixes the issue
- **AND** reruns `git add -A` before retrying
- **AND** never uses `--no-verify`

### Requirement: Resolve tool and assisting-model identity without guessing
The `git-commit-writer` skill and provider-specific agent SHALL accept
`tool_name` and an optional root-session `assisting_model` immediately before
commit execution. `assisting_model` SHALL identify the model of the root agent
session governing the work at the available precision and SHALL be used only as
Git trailer metadata; it MUST NOT select or override the writer's runtime model
or reasoning effort.

An orchestrated call SHALL supply the tool and any known model name as task input.
Preserve a user-supplied model name for the work verbatim; otherwise a standalone
invocation in the root session that performed the work MUST use the available
runtime model name automatically and MUST NOT ask the user to repeat it or
provide greater precision. The same rule applies to later commits while the
root model remains unchanged. Provider-native documentation and commit
subagents MUST NOT replace or make root-session attribution ambiguous.

The writer SHALL accept known family versions such as `GPT-5.6` or `GPT-6`
without inventing a variant, version, or context size. Tool names MUST NOT be
used as model names. Unknown models or unresolved cross-session/model-switch
attribution SHALL cause omission of the model trailer and a reported omission,
not a user question or commit blocker. The writer MUST NOT infer identity from
documentation, email domains, environment variables, session logs, Git history,
or a commit-only agent's identity.

#### Scenario: Orchestrated commit supplies attribution
- **WHEN** `openspec-commit` invokes `git-commit-writer` with an exact tool name and root-session model
- **THEN** the commit writer uses those exact values only for attribution

#### Scenario: Standalone commit in unchanged root session
- **WHEN** the root session performed the work, exposes its exact model identity, and has not switched models
- **THEN** standalone `git-commit-writer` automatically uses that exact identity
- **AND** it does not ask the user to provide or confirm the model name

#### Scenario: Repeated standalone commit in the same session
- **WHEN** the same root session performs more work and invokes `git-commit-writer` again without changing models
- **THEN** the writer uses the unchanged current root-session identity
- **AND** it does not require per-commit reconfirmation

#### Scenario: Claude commit-only agent receives the implementation model
- **WHEN** a Claude commit-only agent receives a root-session model different from its configured model
- **THEN** `assisting_model` remains the root-session model
- **AND** the subagent model neither replaces attribution nor creates ambiguity
- **AND** `assisting_model` does not override the commit-only agent's runtime configuration

#### Scenario: Orchestrated commit supplies a family label
- **WHEN** the available model name is `GPT-5.6` or `GPT-6` without a known variant
- **THEN** the commit writer records the supplied name unchanged
- **AND** it neither guesses a variant nor asks for greater precision

#### Scenario: Work came from another session
- **WHEN** standalone `git-commit-writer` is invoked in a session that did not perform the work and no model attribution is supplied
- **THEN** it commits without the model trailer and reports the omission
- **AND** it does not substitute the current or previous commit model

#### Scenario: Root model changed during the work
- **WHEN** the root model changed during implementation and the attribution is ambiguous
- **THEN** the writer commits without the model trailer and reports the omission
- **AND** it does not select the latest model automatically

#### Scenario: Standalone identity is uncertain
- **WHEN** a standalone invocation knows its executing tool but not the implementation model
- **THEN** it commits with tool attribution only and reports the omitted model
- **AND** it does not use a tool name, empty value, or placeholder as the model

#### Scenario: User supplies a precise model name
- **WHEN** the user supplies `gpt-6-astra` for the implementation
- **THEN** the writer preserves `gpt-6-astra` verbatim without reconfirmation

#### Scenario: Codex custom agent has a configured model
- **WHEN** `git-commit-writer-agent` receives `assisting_model=gpt-5.6-sol` as task input
- **THEN** it retains its provider-native configured runtime model and reasoning effort
- **AND** records `gpt-5.6-sol` only in the `AI-Assisted-By` trailer

### Requirement: Emit tool attribution and model metadata
The commit writer SHALL end each generated commit message with a
`Co-Authored-By` trailer naming the executing tool, immediately followed by an
`AI-Assisted-By` trailer when the primary assisting model is known. When unknown,
the entire model trailer SHALL be omitted and the omission reported. It SHALL append an
email only when the tool has an officially verified mapping: Codex maps to
`noreply@openai.com`, and Claude Code maps to `noreply@anthropic.com`. An
unmapped tool MUST retain its tool name without an email and MUST NOT receive a
guessed provider address.

#### Scenario: Codex uses a verified mapping
- **WHEN** `tool_name` is `Codex` and `assisting_model` is `GPT-5.6 Sol`
- **THEN** the trailers are `Co-Authored-By: Codex <noreply@openai.com>` and
  `AI-Assisted-By: GPT-5.6 Sol`

#### Scenario: Claude Code uses a verified mapping
- **WHEN** `tool_name` is `Claude Code` and `assisting_model` is `Fable 5`
- **THEN** the trailers are
  `Co-Authored-By: Claude Code <noreply@anthropic.com>` and
  `AI-Assisted-By: Fable 5`

#### Scenario: Tool has no verified mapping
- **WHEN** `tool_name` is `Antigravity` and its email is not in the verified
  mapping allowlist
- **THEN** the trailers are `Co-Authored-By: Antigravity` and
  `AI-Assisted-By: <assisting model>`
- **AND** no email address is invented
