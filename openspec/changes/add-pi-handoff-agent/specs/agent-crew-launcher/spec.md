# Spec Delta

## MODIFIED Requirements

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

### Requirement: Sessions are opened with explicit model, effort, and name
Every session the core opens SHALL be created through Xirp with the template's harness, model, and effort set explicitly, with the template's provider set explicitly for a Pi role (through Xirp and through the Pi settings written into the role's worktree, as specified by `agent-handoff-pi`), and with a pinned custom name, so that provider defaults saved by `/model` or `/effort` do not apply. The default name pattern SHALL be `<tool> - <label> - <change-id>`, with labels `impl`, `review`, and `finish`.

#### Scenario: Provider default differs from the template
- **WHEN** the user's saved Claude Code default model is Fable and the implement template sets Opus
- **THEN** the implementer session runs Opus

#### Scenario: Name stays as configured
- **WHEN** the implementer session for `add-export` is opened
- **THEN** its name is `claude - impl - add-export` and is not replaced by an automatic title

#### Scenario: Pi session runs on the declared provider
- **WHEN** Pi's saved default is `openai/gpt-6.2-sol` and the implement template declares `provider: openai-codex`, `model: gpt-6.2-sol`
- **THEN** the implementer session runs `openai-codex/gpt-6.2-sol`

### Requirement: Start options override templates for one loop
`handoff-start` SHALL accept per-loop overrides for the implement and review tool, model, and effort, the implementer worktree mode, the finish trigger, and an existing reviewer session to reuse. A Pi override SHALL also give the provider and billing, in the form `pi:<provider>/<model>:<effort>:<billing>`, and SHALL be verified like a Pi template. Overrides SHALL be recorded in `loop.yaml` and MUST NOT modify `roles.yaml`.

#### Scenario: Reuse an existing reviewer
- **WHEN** `handoff-start add-export --reviewer-session <id>` runs and Xirp confirms the session exists
- **THEN** `loop.yaml` records that session as the reviewer and no new reviewer session is opened later

#### Scenario: Pi override without billing
- **WHEN** `handoff-start add-export --review pi:openai-codex/gpt-6.2-sol:high` runs
- **THEN** it exits non-zero, shows the expected override form, and opens nothing

### Requirement: Cleanup archives records, then removes sessions and worktrees
With `--yes`, cleanup SHALL copy each worktree's handoff records and the review reports they reference to `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/`, delete the loop's Xirp sessions, and remove each loop worktree except the main worktree once. When the main worktree is kept and holds a `.pi/settings.json` that the loop wrote for a Pi role, cleanup SHALL remove that file. It MUST NOT delete the feature branch or force-remove a worktree.

#### Scenario: Finished loop is cleaned up
- **WHEN** the loop is finished and clean and `handoff-cleanup <change-id> --yes` runs
- **THEN** the records and review reports are in the main worktree's archive, the sessions are deleted, the loop worktrees are removed, and `feature/<change-id>` still exists

#### Scenario: Implementer used the main worktree
- **WHEN** the loop was started with `--worktree here` in the main worktree
- **THEN** cleanup deletes the sessions and other worktrees but keeps the main worktree

#### Scenario: Pi implementer used the main worktree
- **WHEN** a Pi implementer worked in the main worktree and the loop is cleaned up
- **THEN** the main worktree no longer has the `.pi/settings.json` the loop wrote

## ADDED Requirements

### Requirement: Start verifies every Pi role before opening any session
`handoff-start` SHALL verify the model, credential, and billing of every Pi role in effect for the loop, including the review and finish roles that open later, before opening the implementer session. When any Pi role fails, it SHALL exit non-zero, name the role and the failed check, and open no session and create no worktree.

#### Scenario: Finish role fails while implement role passes
- **WHEN** the implement role passes verification and the Pi finish role declares `billing: subscription` while its provider uses an API key
- **THEN** `handoff-start` exits non-zero naming the finish role, and no session or worktree is created

#### Scenario: Every Pi role passes
- **WHEN** all Pi roles pass verification
- **THEN** `handoff-start` opens only the implementer session, as before
