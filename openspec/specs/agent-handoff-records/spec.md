# agent-handoff-records Specification

## Purpose

Define the handoff record each agent leaves when it finishes a round, and the loop configuration that records who plays each role, so a script can decide the next step without reading conversations.

## Requirements

### Requirement: Handoff records live in an ignored per-change directory
Handoff records SHALL be written under `.agent-handoff/<change-id>/` at the root of the worktree where the agent works. The directory MUST be excluded from version control and MUST NOT be written outside that worktree.

#### Scenario: Record is written inside the worktree
- **WHEN** an agent working in a worktree records a handoff for change `add-export`
- **THEN** the record is created under `<worktree-root>/.agent-handoff/add-export/`
- **AND** `git status` in that worktree does not list it

#### Scenario: Write outside the worktree is refused
- **WHEN** the requested change ID would resolve to a path outside `.agent-handoff/` of the current worktree
- **THEN** no file is written and the writer exits non-zero with the reason

### Requirement: Each round produces one numbered record
Each handoff SHALL be a new file named `<NN>-<role>.yaml`, where `NN` is the next two-digit sequence number across all worktrees listed in the loop configuration (or the current change directory when there is none) and `role` is `implement`, `review`, or `finish`. Existing records MUST NOT be overwritten.

#### Scenario: Records accumulate in order
- **WHEN** the directory already contains `01-implement.yaml` and `02-review.yaml` and the implementer records a new handoff
- **THEN** the new record is `03-implement.yaml` and the earlier files are unchanged

#### Scenario: Sequence spans a separate review worktree
- **WHEN** worktree A holds `01-implement.yaml`, the review worktree B holds `02-review.yaml`, and the implementer in A records a new handoff
- **THEN** the new record in A is `03-implement.yaml`

### Requirement: Records carry a fixed set of fields
A record SHALL contain `change`, `round`, `role`, `status` (`done` or `blocked`), `head` (the commit handed over or reviewed), `note`, and `at` (ISO 8601 with offset). A `review` record SHALL also contain `verdict` (`pass`, `changes-required`, or `blocked`) and `report` (a path to the review report relative to the root of the worktree that holds the record).

#### Scenario: Review record is complete
- **WHEN** a reviewer records a `changes-required` result
- **THEN** the record includes `verdict: changes-required`, the reviewed `head`, and the `report` path

#### Scenario: Blocked review keeps its technical verdict
- **WHEN** a review's technical verdict is `changes-required` but its PR publication is unconfirmed
- **THEN** the record has `status: blocked`, `verdict: changes-required`, and a `note` stating why it is blocked

#### Scenario: Implement record has no verdict
- **WHEN** an implementer records a finished round
- **THEN** the record has `role: implement`, `status: done`, and `head`, and no `verdict`

### Requirement: The writer validates before writing
The `handoff-write` script SHALL reject a record with a missing required field, an unknown role, status, or verdict, a `head` that is not a commit in the current repository, or a `report` path that does not exist. A rejected record MUST NOT leave a partial file.

#### Scenario: Unknown verdict is rejected
- **WHEN** `handoff-write` is called with `--role review --verdict approve`
- **THEN** it exits non-zero, names the allowed values, and writes nothing

#### Scenario: Head must exist
- **WHEN** `--head` names a commit that does not exist in the repository
- **THEN** it exits non-zero and writes nothing

### Requirement: The writer is available in every installed repository
The `agent-handoff` skill SHALL ship `handoff-write` so that it is installed at a fixed path under both `.claude/skills/agent-handoff/` and `.agents/skills/agent-handoff/` of every target repository, and SHALL document when each role writes a record and what each field means.

#### Scenario: Installed path is stable
- **WHEN** the installer has run on a target repository
- **THEN** `.agents/skills/agent-handoff/scripts/handoff-write` exists and is executable
- **AND** the same script exists under `.claude/skills/agent-handoff/`

### Requirement: Loop configuration identifies the crew
A loop configuration file `loop.yaml` in the change directory SHALL record the change ID, the round limit, the implementer session and worktree, the reviewer session and worktree once known, the finish worktree once known, the finish trigger and delivery settings, and the review and finish templates in effect for this loop. Each record stays in the worktree where its role works.

#### Scenario: Reviewer is filled in later
- **WHEN** a loop has just started and no review has happened yet
- **THEN** `loop.yaml` lists the implementer and leaves the reviewer session and worktree empty

#### Scenario: Templates are fixed per loop
- **WHEN** the repository's role templates are edited while a loop is running
- **THEN** that loop keeps using the templates recorded in its `loop.yaml`

### Requirement: Author blocks are generated, not retyped
The `agent-handoff` skill SHALL provide `handoff-author --tool <tool> --model <model>`, which prints `Co-Authored-By`, `AI-Assisted-By` (omitted for an empty model), `SESSION-ID`, and `XIRP-SESSION-ID`, reading the session IDs only from the runtime variables for that tool and from `CHIRP_SESSION_ID`, and printing `null` for an ID that is not set. Role prompts SHALL tell the agent to append this output verbatim, and the dedicated GitHub agents SHALL append a caller's `author_file` verbatim.

#### Scenario: Codex session writes its Author
- **WHEN** `handoff-author --tool Codex --model gpt-5.6-luna` runs with `CODEX_SESSION_ID` and `CHIRP_SESSION_ID` set
- **THEN** it prints the four lines with those exact IDs

#### Scenario: An ID is not exposed
- **WHEN** `CHIRP_SESSION_ID` is not set
- **THEN** it prints `XIRP-SESSION-ID: null` and still prints the other lines
