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
`tool_name` and `assisting_model` as an attribution pair. An orchestrated call
MUST supply both values. A standalone invocation MAY use exact runtime-provided
identities, but MUST stop and request the missing values when either identity is
uncertain rather than inferring it from an email domain or unrelated environment
variable.

#### Scenario: Orchestrated commit supplies attribution
- **WHEN** `openspec-commit` invokes `git-commit-writer`
- **THEN** it supplies the executing tool name and primary assisting model
- **AND** the commit writer uses those exact values

#### Scenario: Claude commit-only agent receives the implementation model
- **WHEN** a Claude commit-only agent writes a commit for work completed by a
  different primary model
- **THEN** `assisting_model` identifies the primary implementation model
- **AND** MUST NOT be replaced with the commit-only agent's model

#### Scenario: Standalone identity is uncertain
- **WHEN** a standalone invocation cannot identify its tool or assisting model
  exactly
- **THEN** it stops before committing and requests the missing attribution
- **AND** MUST NOT guess either value

### Requirement: Emit tool attribution and model metadata
The commit writer SHALL end each generated commit message with a
`Co-Authored-By` trailer naming the executing tool, immediately followed by an
`AI-Assisted-By` trailer naming the primary assisting model. It SHALL append an
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
