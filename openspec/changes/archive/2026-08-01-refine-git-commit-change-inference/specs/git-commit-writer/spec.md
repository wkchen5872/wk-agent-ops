## MODIFIED Requirements

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
- **THEN** the skill asks the user to select one when the host supports interactive questions
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
