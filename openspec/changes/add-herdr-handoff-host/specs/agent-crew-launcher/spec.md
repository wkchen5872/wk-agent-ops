## MODIFIED Requirements

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
