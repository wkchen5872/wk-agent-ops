# Spec Delta

## Purpose

Let Pi sessions play implement, review, and finish roles in the handoff loop while guaranteeing that each role runs on the declared provider, model, effort, and billing source, stopping the loop whenever any of them cannot be confirmed.

## ADDED Requirements

### Requirement: A Pi role declares its provider and billing source
A role template with `harness: pi` SHALL set `provider`, `model`, `effort`, and `billing`. `billing` SHALL be `subscription` or `api`. `effort` SHALL be one of Pi's thinking levels: `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, or `max`. A missing or invalid field SHALL be refused before any session opens. A template of another harness that sets `provider` or `billing` SHALL be refused.

#### Scenario: Pi role omits billing
- **WHEN** the implement template sets `harness: pi`, `provider: openai-codex`, `model: gpt-6.2-sol`, and `effort: high` but no `billing`
- **THEN** `handoff-start` exits non-zero, names the missing `billing` field, and opens no session

#### Scenario: Codex role sets billing
- **WHEN** a template with `harness: codex` sets `billing: api`
- **THEN** the command refuses and opens no session

#### Scenario: Unknown billing value
- **WHEN** a Pi template sets `billing: free`
- **THEN** the command exits non-zero, names the allowed values `subscription` and `api`, and opens no session

### Requirement: The model must exist under the declared provider
The model of a Pi role SHALL match exactly one model ID that Pi lists as available under the declared provider. Aliases, fuzzy matches, and a `provider/` prefix in `model` SHALL be refused.

#### Scenario: Same model ID under two providers
- **WHEN** Pi lists `gpt-6.2-sol` under both `openai` and `openai-codex` and the template declares `provider: openai-codex`, `model: gpt-6.2-sol`
- **THEN** the role is accepted and is bound to `openai-codex`

#### Scenario: Alias is not a model ID
- **WHEN** a Pi template sets `model: opus`
- **THEN** the command exits non-zero, states that the model is not listed under the provider, and opens no session

### Requirement: The actual credential must match the declared billing
Before a Pi role session opens, the declared provider's credential SHALL be checked without reading or printing secrets. The role SHALL be accepted only when the credential is ready and its type matches the declared billing: `oauth` for `subscription`, `api_key` for `api`. Any other credential type, a credential that is not ready, or a check that cannot run SHALL be treated as a mismatch.

#### Scenario: Subscription declared and subscription credential found
- **WHEN** the template declares `provider: openai-codex`, `billing: subscription` and the credential check reports `ready` with `oauth`
- **THEN** the role is accepted

#### Scenario: Subscription declared but API key in use
- **WHEN** the template declares `provider: anthropic`, `billing: subscription` and the credential check reports `api_key`
- **THEN** the role is refused with a message naming the declared and the actual billing

#### Scenario: Credential is not ready
- **WHEN** the credential check for the declared provider reports `not_ready` or `invalid`
- **THEN** the role is refused and no session opens

#### Scenario: Pi CLI is unavailable
- **WHEN** the `pi` command cannot be run
- **THEN** every Pi role is refused and no session opens

### Requirement: Anthropic subscription use is flagged, not refused
When a Pi role declares `provider: anthropic` and `billing: subscription` and the credential check confirms `oauth`, the role SHALL be accepted, and `handoff-start` SHALL print a warning that Anthropic subscription use through Pi may consume paid extra usage. The warning MUST NOT apply when the declaration and the credential disagree; that case SHALL be refused.

#### Scenario: Matching Anthropic subscription
- **WHEN** a Pi role declares `anthropic` with `subscription` and the credential is `oauth`
- **THEN** the loop starts and the output contains the extra usage warning

### Requirement: Routing runs when a Pi agent settles
When a Pi main session will not continue on its own, the handoff routing SHALL run once for that stop with the session's working directory, with the same behavior as a Claude Code or Codex stop. It MUST NOT run when the session is a subagent, and MUST NOT run at an intermediate end after which Pi retries, compacts, or continues with queued messages. Failures SHALL NOT affect the Pi session.

#### Scenario: Implementer finishes its turn
- **WHEN** a Pi implementer writes an implement record and its run settles
- **THEN** routing runs once for that worktree

#### Scenario: Subagent finishes
- **WHEN** a subagent started inside a Pi role settles
- **THEN** routing does not run

#### Scenario: Run ends but Pi retries
- **WHEN** a Pi run ends and Pi automatically retries it
- **THEN** routing runs only after the retried run settles
