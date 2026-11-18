# Spec Delta

## MODIFIED Requirements

### Requirement: Resolve tool and assisting-model identity without guessing
The `git-commit-writer` skill and provider-specific agent SHALL accept
`tool_name` and an optional root-session `assisting_model` immediately before
commit execution. `assisting_model` SHALL identify the model of the root agent
session collaborating on the current task at the available precision and SHALL be used only as
Git trailer metadata; it MUST NOT select or override the writer's runtime model
or reasoning effort.

An orchestrated call SHALL supply the tool and any known model name as task input.
Preserve a user-supplied model name for the work verbatim; otherwise a standalone
invocation in the current root session MUST use the available
runtime model name automatically and MUST NOT ask the user to repeat it or
provide greater precision. The same rule applies to later commits while the
root model remains unchanged. Provider-native documentation and commit
subagents MUST NOT replace or make root-session attribution ambiguous.

The writer SHALL accept known family versions such as `GPT-5`, `GPT-5.6`, or `GPT-6`
without inventing a variant, version, or context size. Tool names MUST NOT be
used as model names. This records current collaboration, not original code
authorship. Pre-existing work or a commit-only root session MUST NOT cause
omission of a known current model. After a root model switch, use the currently
known model rather than stale attribution. Only an unknown current model
SHALL cause omission of the model trailer and a reported omission,
not a user question or commit blocker. The writer MUST NOT infer identity from
documentation, email domains, environment variables, session logs, Git history,
or a commit-only agent's identity. The only exception is the Pi runtime model
state of a Pi root session, as defined by "Pi root sessions read the current
model from Pi's runtime state".

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
- **WHEN** the available model name is `GPT-5`, `GPT-5.6`, or `GPT-6` without a known variant
- **THEN** the commit writer records the supplied name unchanged
- **AND** it neither guesses a variant nor asks for greater precision

#### Scenario: Work came from another session
- **WHEN** standalone `git-commit-writer` handles pre-existing changes and the current root model is known only as `GPT-5`
- **THEN** it records `AI-Assisted-By: GPT-5` without asking who originally implemented the changes
- **AND** it does not omit the known model or infer a more precise variant

#### Scenario: Root model changed during the work
- **WHEN** the root model changes and the current collaboration model is known
- **THEN** the writer records the currently known root model
- **AND** it does not carry forward a stale model name from before the switch

#### Scenario: Standalone identity is uncertain
- **WHEN** a standalone invocation knows its executing tool but no current root-session model name
- **THEN** it commits with tool attribution only and reports the omitted model
- **AND** it does not use a tool name, empty value, or placeholder as the model

#### Scenario: User supplies a precise model name
- **WHEN** the user supplies `gpt-6-astra` for the current collaboration
- **THEN** the writer preserves `gpt-6-astra` verbatim without reconfirmation

#### Scenario: Codex custom agent has a configured model
- **WHEN** `git-commit-writer-agent` receives `assisting_model=gpt-5.6-sol` as task input
- **THEN** it retains its provider-native configured runtime model and reasoning effort
- **AND** records `gpt-5.6-sol` only in the `AI-Assisted-By` trailer

#### Scenario: Claude Code environment happens to contain a Pi model variable
- **WHEN** the writer runs in Claude Code and the environment contains `PI_MODEL`
- **THEN** it does not use that value as the model

## ADDED Requirements

### Requirement: Pi root sessions read the current model from Pi's runtime state
When the writer runs in a Pi root session, identified by `PI_CODING_AGENT=true` with no `PI_SUBAGENT_PARENT_SESSION`, and no user-supplied or caller-supplied model is given, it SHALL use the value of `PI_MODEL` read at commit time as the current root-session model, recorded verbatim as the model ID without the provider. An empty `PI_MODEL` SHALL count as an unknown model.

#### Scenario: Standalone commit in a Pi root session
- **WHEN** a Pi root session with `PI_MODEL=claude-opus-5-5` invokes `git-commit-writer` without `assisting_model`
- **THEN** the trailers are `Co-Authored-By: Pi` and `AI-Assisted-By: claude-opus-5-5`
- **AND** the writer does not ask the user for the model

#### Scenario: Model switched in Pi before commit
- **WHEN** the Pi root session switched from `claude-opus-5-5` to `gpt-6.2-sol` with `/model` before the commit
- **THEN** the trailer is `AI-Assisted-By: gpt-6.2-sol`

#### Scenario: User-supplied name wins
- **WHEN** the user supplied `Claude Opus 5.5` for the current collaboration and `PI_MODEL` is `claude-opus-5-5`
- **THEN** the trailer is `AI-Assisted-By: Claude Opus 5.5`

#### Scenario: Pi model variable is empty
- **WHEN** a Pi root session has an empty `PI_MODEL` and no supplied model
- **THEN** the writer omits `AI-Assisted-By` and reports the omission

### Requirement: Pi subagents do not attribute their own model
When the writer runs in a Pi subagent, identified by `PI_SUBAGENT_PARENT_SESSION`, it MUST NOT use its own `PI_MODEL` as the root-session model. It SHALL use the caller-supplied `assisting_model`, and otherwise SHALL omit `AI-Assisted-By` and report the omission.

#### Scenario: Subagent without a supplied model
- **WHEN** a Pi subagent with `PI_MODEL=gpt-6-luna` runs the writer and the caller supplied no `assisting_model`
- **THEN** the commit has `Co-Authored-By: Pi` and no `AI-Assisted-By`
- **AND** the omission is reported

#### Scenario: Subagent with a supplied model
- **WHEN** a Pi subagent runs the writer with `assisting_model=claude-opus-5-5`
- **THEN** the trailer is `AI-Assisted-By: claude-opus-5-5`, not the subagent's own model

### Requirement: Pi is named without an email
In Pi the writer SHALL use `Pi` as `tool_name` and SHALL write `Co-Authored-By: Pi` without an email address.

#### Scenario: Pi trailer has no email
- **WHEN** a commit is made from a Pi session
- **THEN** the co-author trailer is exactly `Co-Authored-By: Pi`
