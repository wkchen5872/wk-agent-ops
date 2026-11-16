# agent-crew-launcher Specification

## Purpose

Start an implement–review–finish crew for one OpenSpec Change from repository role templates, by preparing worktrees and opening Xirp sessions with the configured tool, model, effort, name, and prompt.

## Requirements

### Requirement: Role templates are per repository and untracked
Role templates SHALL be read from `.agent-handoff/roles.yaml` in the repository's main worktree, including when the command runs from a linked worktree. The file MUST NOT be tracked by Git. When it is missing, the command SHALL stop and explain how to create it.

#### Scenario: Command runs from a linked worktree
- **WHEN** `handoff-start` runs inside a linked worktree of the repository
- **THEN** it reads `roles.yaml` from the main worktree

#### Scenario: Templates are missing
- **WHEN** `.agent-handoff/roles.yaml` does not exist in the main worktree
- **THEN** the command exits non-zero without opening any session and names the expected path

### Requirement: Templates define how each role is opened
Each of the `implement`, `review`, and `finish` templates SHALL define the harness, model, effort, session name pattern, and prompt. The `review` and `finish` templates SHALL also define `worktree` as `shared` (the implementer's worktree) or `new` (a separate worktree), defaulting to `shared`; any other value SHALL be refused. The `finish` template SHALL define `trigger` (`ask` or `auto`, default `ask`) and `delivery` (`local` or `pr`, default `local`).

#### Scenario: Template omits model or effort
- **WHEN** a template does not set both model and effort
- **THEN** the command refuses to open that role and names the missing field

#### Scenario: Unknown worktree mode
- **WHEN** the review template sets `worktree: separate`
- **THEN** `handoff-start` exits non-zero, names the allowed values `shared` and `new`, and opens nothing

### Requirement: A Codex template may name a Codex profile
A Codex template MAY set `profile` to a Codex configuration profile, which SHALL be passed to the new session; a Claude template that sets `profile` SHALL be refused before any session opens.

#### Scenario: Codex finish needs network for PR delivery
- **WHEN** the finish template sets `harness: codex` and `profile: handoff-net`
- **THEN** the finish session is opened with that Codex profile

#### Scenario: Claude template sets a profile
- **WHEN** a Claude template sets `profile`
- **THEN** the command refuses and opens no session

### Requirement: Sessions are opened with explicit model, effort, and name
Every session the core opens SHALL be created through Xirp with the template's harness, model, and effort set explicitly and with a pinned custom name, so that provider defaults saved by `/model` or `/effort` do not apply. The default name pattern SHALL be `<tool> - <label> - <change-id>`, with labels `impl`, `review`, and `finish`.

#### Scenario: Provider default differs from the template
- **WHEN** the user's saved Claude Code default model is Fable and the implement template sets Opus
- **THEN** the implementer session runs Opus

#### Scenario: Name stays as configured
- **WHEN** the implementer session for `add-export` is opened
- **THEN** its name is `claude - impl - add-export` and is not replaced by an automatic title

### Requirement: Start verifies the change and its branch
`handoff-start <change-id>` SHALL verify that the OpenSpec change exists and that `feature/<change-id>` exists before opening anything. It MUST NOT create OpenSpec artifacts or branches.

#### Scenario: Change does not exist
- **WHEN** `handoff-start add-export` runs and no active change `add-export` exists
- **THEN** it exits non-zero without creating a worktree or session

### Requirement: The implementer gets its own worktree by default
By default `handoff-start` SHALL prepare a new worktree checked out on `feature/<change-id>`; `--worktree here` SHALL use the current checkout only if it is already on that branch. If the branch is checked out in another worktree, the command SHALL stop and name that path.

#### Scenario: Default keeps the main worktree on its branch
- **WHEN** `handoff-start add-export` runs from the main worktree on `main`
- **THEN** the implementer works in a new worktree on `feature/add-export` and the main worktree stays on `main`

#### Scenario: Branch is already in use
- **WHEN** `feature/add-export` is checked out in another worktree
- **THEN** the command exits non-zero and prints that worktree's path

### Requirement: Start opens only the implementer and records the loop
`handoff-start` SHALL open the implementer session with the implement template's prompt, then write `loop.yaml` with the implementer's Xirp session ID and worktree, the round limit, the finish settings, and the review and finish templates. It MUST NOT open the reviewer or finish session.

#### Scenario: Loop is recorded after start
- **WHEN** `handoff-start add-export` succeeds
- **THEN** exactly one session exists for the loop and `loop.yaml` names it as the implementer

### Requirement: Start options override templates for one loop
`handoff-start` SHALL accept per-loop overrides for the implement and review tool, model, and effort, the implementer worktree mode, the finish trigger, and an existing reviewer session to reuse. Overrides SHALL be recorded in `loop.yaml` and MUST NOT modify `roles.yaml`.

#### Scenario: Reuse an existing reviewer
- **WHEN** `handoff-start add-export --reviewer-session <id>` runs and Xirp confirms the session exists
- **THEN** `loop.yaml` records that session as the reviewer and no new reviewer session is opened later

### Requirement: Finish requires a current passing review
`handoff-finish <change-id>` SHALL open the finish session only when the newest record across the loop's worktrees is a `review` record with `status: done` and `verdict: pass`, its `head` equals the implementer worktree's current `HEAD`, the implementer worktree has no uncommitted non-ignored changes, and no `finish` record exists. Otherwise it SHALL exit non-zero, state the failed condition, and open nothing.

#### Scenario: Finish after a current passing review
- **WHEN** the newest record is a `pass` review of commit X and the clean worktree is at X
- **THEN** one finish session is opened with the finish prompt

#### Scenario: Finish without a passing review
- **WHEN** the newest review record is `changes-required` or has `status: blocked`
- **THEN** `handoff-finish` exits non-zero and opens nothing

#### Scenario: Pass is stale after a new commit
- **WHEN** X passed review and the worktree has since moved to commit Y
- **THEN** `handoff-finish` refuses and names both commits

#### Scenario: Pass is superseded by a new implement record
- **WHEN** an implement record was written after the `pass` review
- **THEN** `handoff-finish` refuses because the newest record is not the passing review

#### Scenario: Worktree has uncommitted changes
- **WHEN** the passing review's head equals `HEAD` but tracked or untracked non-ignored files are modified
- **THEN** `handoff-finish` refuses and opens nothing

#### Scenario: Loop already finished
- **WHEN** a `finish` record with `status: done` exists for the loop
- **THEN** `handoff-finish` refuses and reports the existing finish record

#### Scenario: Pass recorded in a separate review worktree
- **WHEN** the review worktree B holds the newest record, a `pass` of commit X, and the clean implementer worktree A is at X
- **THEN** `handoff-finish` run from A opens the finish session

### Requirement: Separate finish worktree takes over the branch
When the finish template sets `worktree: new`, the finish entry SHALL first confirm the implementer worktree is clean at the passing head, then detach that worktree at the same commit, create a new worktree on `feature/<change-id>`, record it in `loop.yaml`, and open the finish session there. It MUST NOT delete the implementer worktree or discard any change.

#### Scenario: Finish in its own worktree
- **WHEN** a passing review of X exists and the finish template sets `worktree: new`
- **THEN** the implementer worktree is detached at X, a finish worktree is created on `feature/<change-id>` at X, and the finish session opens there

#### Scenario: Implementer worktree is not clean
- **WHEN** the implementer worktree has uncommitted changes
- **THEN** nothing is detached or created and the command exits non-zero

### Requirement: Cleanup acts only on a finished, clean loop
`handoff-cleanup <change-id>` SHALL act only when the newest record of the loop is `finish` with `status: done`, or `--abandon` is given, and every loop worktree to remove has no uncommitted non-ignored changes; otherwise it SHALL report why and change nothing. Without `--yes` it SHALL only list what it would remove.

#### Scenario: Plan only without --yes
- **WHEN** `handoff-cleanup <change-id>` runs without `--yes`
- **THEN** it lists the sessions and worktrees it would remove and changes nothing

#### Scenario: Loop is not finished
- **WHEN** the newest record is not `finish`/`done`
- **THEN** cleanup refuses, names the newest record, and changes nothing

#### Scenario: A worktree has uncommitted changes
- **WHEN** any loop worktree has uncommitted non-ignored changes
- **THEN** cleanup refuses, names the worktree, and deletes no session or worktree

#### Scenario: Abandoned loop
- **WHEN** the loop will not finish and `handoff-cleanup <change-id> --abandon --yes` runs on clean worktrees
- **THEN** cleanup archives the records, deletes the sessions and loop worktrees, and keeps the branch

### Requirement: Cleanup archives records, then removes sessions and worktrees
With `--yes`, cleanup SHALL copy each worktree's handoff records and the review reports they reference to `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/`, delete the loop's Xirp sessions, and remove each loop worktree except the main worktree once. It MUST NOT delete the feature branch or force-remove a worktree.

#### Scenario: Finished loop is cleaned up
- **WHEN** the loop is finished and clean and `handoff-cleanup <change-id> --yes` runs
- **THEN** the records and review reports are in the main worktree's archive, the sessions are deleted, the loop worktrees are removed, and `feature/<change-id>` still exists

#### Scenario: Implementer used the main worktree
- **WHEN** the loop was started with `--worktree here` in the main worktree
- **THEN** cleanup deletes the sessions and other worktrees but keeps the main worktree

### Requirement: A blocked finish can be retried
When the newest record is `finish` with `status: blocked`, `handoff-finish <change-id>` SHALL retry instead of refusing, provided the finish worktree is clean and its `HEAD` contains the head of the newest passing review. It SHALL message the existing finish session to resume from the stopped stage and write a new finish record, or open a new finish session when that session no longer exists. Otherwise it SHALL refuse and change nothing.

#### Scenario: Retry with the finish session still open
- **WHEN** the newest record is a blocked finish and the finish session exists
- **THEN** that session is messaged to resume and write a new finish record, and no session is opened

#### Scenario: Retry after the finish session is gone
- **WHEN** the newest record is a blocked finish and the finish session no longer exists
- **THEN** a new finish session opens in the finish worktree and `loop.yaml` records it

#### Scenario: Retry is not safe
- **WHEN** the finish worktree has uncommitted changes or its `HEAD` does not contain the passing review's head
- **THEN** `handoff-finish` refuses and names the reason
