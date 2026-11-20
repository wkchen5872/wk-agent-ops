## MODIFIED Requirements

### Requirement: Loop configuration identifies the crew
A loop configuration file `loop.yaml` in the change directory SHALL record the change ID, the round limit, the implementer session and worktree, the reviewer session and worktree once known, the finish worktree once known, the finish trigger and delivery settings, the host of each role with its host-specific session details, and the implement, review, and finish templates in effect for this loop. Each record stays in the worktree where its role works.

#### Scenario: Reviewer is filled in later
- **WHEN** a loop has just started and no review has happened yet
- **THEN** `loop.yaml` lists the implementer and leaves the reviewer session and worktree empty

#### Scenario: Templates are fixed per loop
- **WHEN** the repository's role templates are edited while a loop is running
- **THEN** that loop keeps using the templates recorded in its `loop.yaml`

#### Scenario: Implement template is recorded
- **WHEN** `handoff-start` opens a Pi implementer from `roles.yaml` or from an override
- **THEN** `loop.yaml` records the implement template's harness, provider, model, effort, and billing

#### Scenario: Host of each role is recorded
- **WHEN** a loop starts with the implementer on `host: xirp` and the reviewer on `host: herdr`
- **THEN** `loop.yaml` records `xirp` for the implementer and `herdr` with its herdr session for the reviewer

### Requirement: Author blocks are generated, not retyped
The `agent-handoff` skill SHALL provide `handoff-author --tool <tool> --model <model>`, which prints `Co-Authored-By`, `AI-Assisted-By` (omitted for an empty model), `SESSION-ID`, and `XIRP-SESSION-ID`, reading the session IDs only from the runtime variables for that tool (`PI_SESSION_ID` for `Pi`) and from `CHIRP_SESSION_ID`, and printing `null` for an ID that is not set. Inside a herdr pane (`HERDR_ENV=1`), `CHIRP_SESSION_ID` SHALL be treated as not set. Role prompts SHALL tell the agent to append this output verbatim, and the dedicated GitHub agents SHALL append a caller's `author_file` verbatim.

#### Scenario: Codex session writes its Author
- **WHEN** `handoff-author --tool Codex --model gpt-5.6-luna` runs with `CODEX_SESSION_ID` and `CHIRP_SESSION_ID` set
- **THEN** it prints the four lines with those exact IDs

#### Scenario: An ID is not exposed
- **WHEN** `CHIRP_SESSION_ID` is not set
- **THEN** it prints `XIRP-SESSION-ID: null` and still prints the other lines

#### Scenario: Pi session writes its Author
- **WHEN** `handoff-author --tool Pi --model gpt-6.2-sol` runs with `PI_SESSION_ID` and `CHIRP_SESSION_ID` set
- **THEN** it prints `Co-Authored-By: Pi` and the two exact session IDs

#### Scenario: Inherited Xirp variable in a herdr pane
- **WHEN** `handoff-author --tool "Claude Code" --model opus` runs with `HERDR_ENV=1`, `CLAUDE_CODE_SESSION_ID`, and an inherited `CHIRP_SESSION_ID`
- **THEN** it prints the Claude Code session ID and `XIRP-SESSION-ID: null`
