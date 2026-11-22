## ADDED Requirements

### Requirement: A delegated commit agent records itself in a Committed-By trailer
When a delegated commit agent executes the commit, the message SHALL keep the root-session `Co-Authored-By` and `AI-Assisted-By` trailers unchanged and SHALL add `Committed-By: <agent name> (<model>)` right after them. Delegated commit agents are the provider-native `git-commit-writer-agent` (Claude Code or Codex) and the portable skill in a Pi subagent, named `git-commit-writer`. A `Refs:` line SHALL stay before all attribution trailers.

#### Scenario: Codex commit agent executes the commit
- **WHEN** a Codex root session using `gpt-6.1-terra` delegates the commit to `git-commit-writer-agent`, whose definition uses `gpt-5.6-luna`
- **THEN** the trailers are, in order, `Co-Authored-By: Codex <noreply@openai.com>`, `AI-Assisted-By: gpt-6.1-terra`, and `Committed-By: git-commit-writer-agent (gpt-5.6-luna)`

#### Scenario: Pi subagent executes the commit
- **WHEN** the skill runs in a Pi subagent with `PI_MODEL=gpt-6-luna` and the caller supplied `assisting_model=claude-opus-5-5`
- **THEN** the trailers are `Co-Authored-By: Pi`, `AI-Assisted-By: claude-opus-5-5`, and `Committed-By: git-commit-writer (gpt-6-luna)`

#### Scenario: Root model is unknown but the agent's is known
- **WHEN** the caller supplies no `assisting_model` and the Codex agent runs on `gpt-5.6-luna`
- **THEN** the commit has `Co-Authored-By: Codex <noreply@openai.com>` and `Committed-By: git-commit-writer-agent (gpt-5.6-luna)` with no `AI-Assisted-By`
- **AND** the omitted root model is reported

### Requirement: The Committed-By model is the agent's own
The model in `Committed-By` SHALL be the delegated agent's own: the full ID from its runtime context, else its provider-native definition, and `PI_MODEL` in a Pi subagent. It MUST NOT come from `assisting_model` or a definition alias. When unknown, the trailer SHALL be `Committed-By: <agent name>` and the omission reported without blocking. The ban on inferring identity from a commit-only agent applies only to the root-session model.

#### Scenario: Claude commit agent uses its full model ID
- **WHEN** the Claude `git-commit-writer-agent` runs on `claude-haiku-4-5` and receives `assisting_model=Claude Opus 5.5`
- **THEN** `AI-Assisted-By` is `Claude Opus 5.5` and `Committed-By` is `git-commit-writer-agent (claude-haiku-4-5)`, not the alias `haiku`

#### Scenario: Agent's own model is unknown
- **WHEN** a delegated commit agent cannot determine its own model
- **THEN** the trailer is `Committed-By: git-commit-writer-agent` and the omission is reported
- **AND** the commit is not blocked and `assisting_model` is not copied into the trailer

### Requirement: A root-session commit has no Committed-By
A commit executed by the root session itself, including the portable skill in Claude Code, Codex, Antigravity, or a Pi root session, MUST NOT add `Committed-By`; its trailers stay `Co-Authored-By` and the optional `AI-Assisted-By`.

#### Scenario: Root session commits through the portable skill
- **WHEN** a Claude Code root session runs the `git-commit-writer` skill itself without delegating
- **THEN** the commit has only `Co-Authored-By` and `AI-Assisted-By`, with no `Committed-By`

### Requirement: A caller may supply the commit subject
The skill and the provider-native agents SHALL accept an optional `subject` input and use it verbatim as the subject line, still writing the body and trailers. Without it the subject is derived as before. An empty subject or one over 72 characters SHALL be reported and replaced by a derived subject, without blocking the commit.

#### Scenario: Implementer supplies a fix subject
- **WHEN** the caller supplies `subject=fix(add-export): address codex-add-export-r02`
- **THEN** the commit subject is exactly `fix(add-export): address codex-add-export-r02`
- **AND** the commit still has a body and the attribution trailers

#### Scenario: Supplied subject is too long
- **WHEN** the supplied subject has more than 72 characters
- **THEN** the writer reports it and uses a derived subject instead
