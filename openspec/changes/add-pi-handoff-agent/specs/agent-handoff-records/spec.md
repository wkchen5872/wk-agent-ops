# Spec Delta

## MODIFIED Requirements

### Requirement: Loop configuration identifies the crew
A loop configuration file `loop.yaml` in the change directory SHALL record the change ID, the round limit, the implementer session and worktree, the reviewer session and worktree once known, the finish worktree once known, the finish trigger and delivery settings, and the implement, review, and finish templates in effect for this loop. Each record stays in the worktree where its role works.

#### Scenario: Reviewer is filled in later
- **WHEN** a loop has just started and no review has happened yet
- **THEN** `loop.yaml` lists the implementer and leaves the reviewer session and worktree empty

#### Scenario: Templates are fixed per loop
- **WHEN** the repository's role templates are edited while a loop is running
- **THEN** that loop keeps using the templates recorded in its `loop.yaml`

#### Scenario: Implement template is recorded
- **WHEN** `handoff-start` opens a Pi implementer from `roles.yaml` or from an override
- **THEN** `loop.yaml` records the implement template's harness, provider, model, effort, and billing

### Requirement: Author blocks are generated, not retyped
The `agent-handoff` skill SHALL provide `handoff-author --tool <tool> --model <model>`, which prints `Co-Authored-By`, `AI-Assisted-By` (omitted for an empty model), `SESSION-ID`, and `XIRP-SESSION-ID`, reading the session IDs only from the runtime variables for that tool (`PI_SESSION_ID` for `Pi`) and from `CHIRP_SESSION_ID`, and printing `null` for an ID that is not set. Role prompts SHALL tell the agent to append this output verbatim, and the dedicated GitHub agents SHALL append a caller's `author_file` verbatim.

#### Scenario: Codex session writes its Author
- **WHEN** `handoff-author --tool Codex --model gpt-5.6-luna` runs with `CODEX_SESSION_ID` and `CHIRP_SESSION_ID` set
- **THEN** it prints the four lines with those exact IDs

#### Scenario: An ID is not exposed
- **WHEN** `CHIRP_SESSION_ID` is not set
- **THEN** it prints `XIRP-SESSION-ID: null` and still prints the other lines

#### Scenario: Pi session writes its Author
- **WHEN** `handoff-author --tool Pi --model gpt-6.2-sol` runs with `PI_SESSION_ID` and `CHIRP_SESSION_ID` set
- **THEN** it prints `Co-Authored-By: Pi` and the two exact session IDs

## ADDED Requirements

### Requirement: Records written in a Pi session carry the session's agent identity
When `handoff-write` runs inside a Pi session, the record SHALL contain an `agent` section with `harness: pi` and the session's current `provider`, `model`, `effort`, `billing`, and `session`, taken from the Pi runtime and from the credential check, never from arguments the agent types. A value that cannot be determined SHALL be written as `unknown` and SHALL NOT prevent the record from being written. Records written outside Pi SHALL be unchanged.

#### Scenario: Record from a Pi implementer
- **WHEN** a Pi session on `openai-codex/gpt-6.2-sol` at `high` with an `oauth` credential writes an implement record
- **THEN** the record's `agent` section is `harness: pi`, `provider: openai-codex`, `model: gpt-6.2-sol`, `effort: high`, `billing: subscription`, and the Pi session ID

#### Scenario: Credential check fails while writing
- **WHEN** the credential check cannot run while a Pi session writes a record
- **THEN** the record is written with `billing: unknown`

#### Scenario: Record from Codex
- **WHEN** a Codex session writes a record
- **THEN** the record has no `agent` section
