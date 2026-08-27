## ADDED Requirements

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
