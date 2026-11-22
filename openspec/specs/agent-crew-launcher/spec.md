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
Each of the `implement`, `review`, and `finish` templates SHALL define the harness (`claude`, `codex`, or `pi`), model, effort, session name pattern, and prompt; a `pi` template SHALL also define `provider` and `billing` as specified by `agent-handoff-pi`. The `review` and `finish` templates SHALL also define `worktree` as `shared` (the implementer's worktree) or `new` (a separate worktree), defaulting to `shared`; any other value SHALL be refused. The `finish` template SHALL define `trigger` (`ask` or `auto`, default `ask`) and `delivery` (`local` or `pr`, default `local`).

#### Scenario: Template omits model or effort
- **WHEN** a template does not set both model and effort
- **THEN** the command refuses to open that role and names the missing field

#### Scenario: Unknown worktree mode
- **WHEN** the review template sets `worktree: separate`
- **THEN** `handoff-start` exits non-zero, names the allowed values `shared` and `new`, and opens nothing

#### Scenario: Unknown harness
- **WHEN** a template sets `harness: gemini`
- **THEN** `handoff-start` exits non-zero, names the allowed values `claude`, `codex`, and `pi`, and opens nothing

### Requirement: A Codex template may name a Codex profile
A Codex template MAY set `profile` to a Codex configuration profile, which SHALL be passed to the new session; a Claude template that sets `profile` SHALL be refused before any session opens.

#### Scenario: Codex finish needs network for PR delivery
- **WHEN** the finish template sets `harness: codex` and `profile: handoff-net`
- **THEN** the finish session is opened with that Codex profile

#### Scenario: Claude template sets a profile
- **WHEN** a Claude template sets `profile`
- **THEN** the command refuses and opens no session

### Requirement: Sessions are opened with explicit model, effort, and name
Every session the core opens SHALL be created through the role's host, as specified by `agent-handoff-hosts`, with the template's harness, model, and effort set explicitly, with the template's provider set explicitly for a Pi role (through the host and through the Pi settings written into the role's worktree, as specified by `agent-handoff-pi`), and with a pinned custom name, so that provider defaults saved by `/model` or `/effort` do not apply. The default name pattern SHALL be `<tool> - <label> - <change-id>`, with labels `impl`, `review`, and `finish`.

#### Scenario: Provider default differs from the template
- **WHEN** the user's saved Claude Code default model is Fable and the implement template sets Opus
- **THEN** the implementer session runs Opus

#### Scenario: Name stays as configured
- **WHEN** the implementer session for `add-export` is opened
- **THEN** its name is `claude - impl - add-export` and is not replaced by an automatic title

#### Scenario: Pi session runs on the declared provider
- **WHEN** Pi's saved default is `openai/gpt-6.2-sol` and the implement template declares `provider: openai-codex`, `model: gpt-6.2-sol`
- **THEN** the implementer session runs `openai-codex/gpt-6.2-sol`

#### Scenario: herdr session uses the template, not the saved default
- **WHEN** the implement role uses `host: herdr`, the user's saved Claude Code default is Fable, and the template sets Opus at `high`
- **THEN** the implementer's herdr tab runs Claude Code on Opus at `high`

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
`handoff-start` SHALL open the implementer session with the implement template's prompt, then write `loop.yaml` with the implementer's host, its session identifier on that host, and its worktree, the round limit, the finish settings, and the review and finish templates. It MUST NOT open the reviewer or finish session.

#### Scenario: Loop is recorded after start
- **WHEN** `handoff-start add-export` succeeds
- **THEN** exactly one session exists for the loop and `loop.yaml` names it as the implementer

#### Scenario: herdr implementer is recorded
- **WHEN** `handoff-start add-export` succeeds with the implement role on `host: herdr`
- **THEN** `loop.yaml` records `host: herdr`, the herdr session, and the implementer's pane ID

### Requirement: Start options override templates for one loop
`handoff-start` SHALL accept per-loop overrides for the implement and review tool, model, and effort, the implementer worktree mode, the finish trigger, and an existing reviewer session on the review role's host to reuse. A Pi override SHALL also give the provider and billing, in the form `pi:<provider>/<model>:<effort>:<billing>`, and SHALL be verified like a Pi template. Overrides SHALL be recorded in `loop.yaml` and MUST NOT modify `roles.yaml`.

#### Scenario: Reuse an existing reviewer
- **WHEN** `handoff-start add-export --reviewer-session <id>` runs and the review role's host confirms the session exists
- **THEN** `loop.yaml` records that session as the reviewer and no new reviewer session is opened later

#### Scenario: Pi override without billing
- **WHEN** `handoff-start add-export --review pi:openai-codex/gpt-6.2-sol:high` runs
- **THEN** it exits non-zero, shows the expected override form, and opens nothing

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
With `--yes`, cleanup SHALL copy each worktree's handoff records and the review reports they reference to `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/`, delete or close the loop's sessions on each role's host, and remove each loop worktree except the main worktree once. When the main worktree is kept and holds a `.pi/settings.json` that the loop wrote for a Pi role, cleanup SHALL remove that file. It MUST NOT delete the feature branch or force-remove a worktree.

#### Scenario: Finished loop is cleaned up
- **WHEN** the loop is finished and clean and `handoff-cleanup <change-id> --yes` runs
- **THEN** the records and review reports are in the main worktree's archive, the sessions are deleted, the loop worktrees are removed, and `feature/<change-id>` still exists

#### Scenario: Implementer used the main worktree
- **WHEN** the loop was started with `--worktree here` in the main worktree
- **THEN** cleanup deletes the sessions and other worktrees but keeps the main worktree

#### Scenario: Pi implementer used the main worktree
- **WHEN** a Pi implementer worked in the main worktree and the loop is cleaned up
- **THEN** the main worktree no longer has the `.pi/settings.json` the loop wrote

#### Scenario: Loop used both hosts
- **WHEN** a loop whose implementer ran on Xirp and whose reviewer ran on herdr is cleaned up
- **THEN** the Xirp session is deleted and the herdr workspace or tab the loop opened is closed

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

### Requirement: Start verifies every Pi role before opening any session
`handoff-start` SHALL verify the model, credential, and billing of every Pi role in effect for the loop, including the review and finish roles that open later, before opening the implementer session. When any Pi role fails, it SHALL exit non-zero, name the role and the failed check, and open no session and create no worktree.

#### Scenario: Finish role fails while implement role passes
- **WHEN** the implement role passes verification and the Pi finish role declares `billing: subscription` while its provider uses an API key
- **THEN** `handoff-start` exits non-zero naming the finish role, and no session or worktree is created

#### Scenario: Every Pi role passes
- **WHEN** all Pi roles pass verification
- **THEN** `handoff-start` opens only the implementer session, as before

### Requirement: Cleanup keeps the Work Items of removed worktrees
Before it removes a loop worktree other than the main worktree, cleanup with `--yes` SHALL copy every `work-items/WI-*` directory in that worktree, with all its files, to `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/work-items/`. If a copy fails, cleanup SHALL remove nothing. Without `--yes`, cleanup SHALL list those directories. Work Items in a kept main worktree SHALL stay where they are.

#### Scenario: Work Item in a removed worktree is archived
- **WHEN** the implementer worktree holds `work-items/WI-20261119-x/agents/drill.md` and `handoff-cleanup <change-id> --yes` runs on the finished loop
- **THEN** `<main worktree>/.agent-handoff/archive/<change-id>/<implementer worktree name>/work-items/WI-20261119-x/agents/drill.md` exists and the implementer worktree is removed

#### Scenario: Preview names the Work Items
- **WHEN** `handoff-cleanup <change-id>` runs without `--yes` and a loop worktree holds `work-items/WI-20261119-x/`
- **THEN** the output names that Work Item directory and nothing is changed

#### Scenario: Work Item in the main worktree stays
- **WHEN** the loop was started with `--worktree here` in the main worktree, which holds `work-items/WI-20261119-x/`, and cleanup runs with `--yes`
- **THEN** `work-items/WI-20261119-x/` is still in the main worktree

### Requirement: A role that has not opened can be changed during the loop
`handoff-role <change-id> <review|finish> <override>` SHALL replace that role's tool, model, effort, provider and billing in the loop's `loop.yaml` while the role's session has not opened, using the override form `handoff-start` accepts. It SHALL first run the checks `handoff-start` applies to roles. When a check fails, or the role's session is already recorded and `--replace` is not given, it SHALL exit non-zero and leave `loop.yaml` unchanged. It MUST NOT modify `roles.yaml`.

#### Scenario: Reviewer changed before the first handoff
- **WHEN** no reviewer has opened and `handoff-role add-export review pi:openai/gpt-6.2-sol:high:api` runs with that model listed and an API-key credential ready
- **THEN** `loop.yaml` holds a Pi review template with those values, and the hook later opens the reviewer from it

#### Scenario: Reviewer already open
- **WHEN** `loop.yaml` records a reviewer session and `handoff-role add-export review codex:gpt-6.2-sol:high` runs without `--replace`
- **THEN** it exits non-zero naming that session and suggesting `--replace`, and `loop.yaml` is unchanged

#### Scenario: Pi role fails verification
- **WHEN** `handoff-role add-export review pi:openai/not-a-model:high:api` runs and the model is not listed under `openai`
- **THEN** it exits non-zero naming the check, and `loop.yaml` is unchanged

#### Scenario: Second Pi role in one worktree
- **WHEN** the implementer is a Pi role, the review role uses the implementer's worktree, and `handoff-role add-export review pi:openai/gpt-6.2-sol:high:api` runs
- **THEN** it exits non-zero explaining that a worktree holds one Pi role, and `loop.yaml` is unchanged

### Requirement: An open review or finish role can be replaced
With `--replace`, `handoff-role` SHALL replace a review or finish role whose session is open. It SHALL run the same checks on the new settings first; when any fails, the old session, `loop.yaml`, and the records SHALL stay unchanged. Otherwise it SHALL delete or close the old session through the old role's host, clear the role's session in `loop.yaml`, and write the new settings. The implementer SHALL NOT be replaceable.

#### Scenario: Reviewer replaced
- **WHEN** a Codex reviewer is open and `handoff-role add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace` passes its checks
- **THEN** the Codex session is deleted, `loop.yaml` holds the Pi review template with no reviewer session, and `roles.yaml` is unchanged

#### Scenario: Replacement fails its checks
- **WHEN** `--replace` is given and the new Pi model is not listed under its provider
- **THEN** it exits non-zero, the old reviewer session still exists, and `loop.yaml` is unchanged

#### Scenario: Implementer cannot be replaced
- **WHEN** `handoff-role add-export implement claude:opus:high --replace` runs
- **THEN** it exits non-zero saying only review and finish roles can be changed

### Requirement: A record waiting for a replaced role goes to the new role
After a replacement, `handoff-role` SHALL hand the waiting record to the new role at once. For review, a newest `implement`/`done` record that was sent to the old reviewer and has no later review SHALL open the new reviewer and send that round. For finish, a newest `finish`/`blocked` record, or a passing review whose finish session had opened, SHALL open the new finish session. The hand-off SHALL be written to the routing log. With no waiting record, the new role SHALL open when its turn comes.

#### Scenario: Pending review goes to the new reviewer
- **WHEN** the newest record is an `implement`/`done` record already sent to the old reviewer and the reviewer is replaced
- **THEN** the new reviewer opens, receives the review prompt for that round, and the routing log records the hand-off

#### Scenario: Blocked finish goes to the new finish role
- **WHEN** the newest record is `finish`/`blocked` and the finish role is replaced
- **THEN** a new finish session opens and receives the finish prompt

#### Scenario: Nothing is waiting
- **WHEN** the reviewer is replaced while the implementer is still working on its round
- **THEN** no session opens now, and the hook opens the new reviewer when the next `implement`/`done` record is processed

#### Scenario: Hand-off fails after replacement
- **WHEN** the replacement succeeds but the new reviewer cannot be opened
- **THEN** the record stays unprocessed, the user gets one attention notice, and `handoff-route --foreground` retries it

### Requirement: A review or finish role can move to its own worktree
`handoff-role` SHALL accept `--worktree new` to make a review or finish role that uses the implementer's worktree work in a worktree of its own, applied with the other new settings and checked by the one-Pi-role-per-worktree rule. Moving a role back to the implementer's worktree SHALL be refused.

#### Scenario: Pi reviewer next to a Pi finish role
- **WHEN** the finish role is a shared Pi role and `handoff-role add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new` runs
- **THEN** the check passes, `loop.yaml` sets the review worktree to `new`, and the reviewer later opens in its own worktree

#### Scenario: Moving back to the shared worktree
- **WHEN** `handoff-role add-export review codex:gpt-6.2-sol:high --worktree shared` runs
- **THEN** it exits non-zero saying only `--worktree new` is supported, and `loop.yaml` is unchanged

### Requirement: An override that changes the tool also changes its skill call and session name
When an override from `handoff-start` or `handoff-role` sets a tool different from the template's, the role's prompt SHALL start with the new tool's skill call syntax — `/<skill>` for Claude Code, `$<skill>` for Codex, `/skill:<skill>` for Pi — when it started with a skill call, and a session name that starts with the old tool's name SHALL start with the new tool's name.

#### Scenario: Codex review overridden with Pi at start
- **WHEN** the review template is `codex` with prompt `$change-review {change}…` and name `codex - review - {change}`, and `handoff-start add-export --review pi:openai-codex/gpt-6.2-sol:high:subscription` runs
- **THEN** `loop.yaml` holds prompt `/skill:change-review {change}…` and name `pi - review - {change}`

#### Scenario: Same tool keeps its prompt
- **WHEN** an override keeps the template's tool and changes only the model
- **THEN** the prompt and session name are unchanged

### Requirement: The example implement template commits through git-commit-writer
Every implement prompt in the bundled example role templates, including commented alternatives for other harnesses, SHALL commit each round through the `git-commit-writer` skill instead of running `git commit` directly, passing the round's subject as the skill's `subject` input: `feat(<change>): <summary>` for the first round and `fix(<change>): address <review-id>` for a repair round.

#### Scenario: Claude implementer finishes a repair round
- **WHEN** an implementer opened from the example `claude` template finishes round 2 after review `codex-add-export-r01`
- **THEN** its commit is made through `git-commit-writer` with subject `fix(add-export): address codex-add-export-r01`
- **AND** the commit has `Co-Authored-By: Claude Code <noreply@anthropic.com>` and an `AI-Assisted-By` trailer, not a model name in `Co-Authored-By`

### Requirement: Existing role templates are not overwritten
The installer SHALL keep creating `.agent-handoff/roles.yaml` from the example only when that file does not exist, and the handoff documentation SHALL tell users with an existing file how to update its implement prompt.

#### Scenario: Existing roles.yaml is kept
- **WHEN** the project installer runs and `.agent-handoff/roles.yaml` already exists
- **THEN** the file is left unchanged
- **AND** the handoff documentation explains how to replace its implement prompt with the example's
