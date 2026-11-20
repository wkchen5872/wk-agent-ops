# agent-handoff-doctor Specification

## Purpose

Check, in one place and before any session opens, that this machine can run an agent handoff loop with the configured hosts, tools, and role templates, and report each result so the user knows what to fix.

## Requirements

### Requirement: handoff-doctor reports the environment of a loop
`handoff-doctor` SHALL check the roles in `roles.yaml`, or with a change ID the roles in effect in that loop's `loop.yaml`, and print one line per check as `ok`, `warn`, or `fail` with its area (`base`, `host`, `harness`, `role`, `notify`) and a message. It SHALL exit non-zero when any check fails and MUST NOT open, message, or close any session or change any file.

#### Scenario: Everything is ready
- **WHEN** `handoff-doctor` runs on a machine with every configured host and tool ready
- **THEN** every line is `ok` or `warn` and it exits with status 0

#### Scenario: A tool is missing
- **WHEN** the review role uses `harness: codex` and `codex` is not installed
- **THEN** a `fail harness` line names the review role and `codex`, and it exits non-zero

#### Scenario: Doctor does not change anything
- **WHEN** `handoff-doctor add-export` runs on a running loop
- **THEN** `loop.yaml`, the records, and every session are unchanged

### Requirement: Doctor covers base, host, harness, role, and notify checks
`base` SHALL check git, jq, the main worktree, and that `roles.yaml` exists and can be read. `host` SHALL check each host in use: for `xirp` its command and the Xirp project; for `herdr` its command and the chosen session's server. `harness` SHALL check each role's command, show its version, and check its trigger is installed. `role` SHALL check template fields and every Pi role's model, credential, billing, and trust. `notify` SHALL check the notifier.

#### Scenario: Xirp project is not registered
- **WHEN** a role uses `host: xirp` and the main worktree is not a registered Xirp project
- **THEN** a `fail host` line says so and shows how to register it

#### Scenario: Pi role model is not available
- **WHEN** a Pi role names a model its provider does not list
- **THEN** a `fail role` line names the role, provider, and model

### Requirement: Doctor marks what it cannot verify
Checks that cannot be confirmed from outside a tool SHALL NOT fail. Doctor SHALL print `warn` when Codex hook trust cannot be confirmed, when herdr's integration for a herdr role's harness is not installed, and when no notifier is configured. Claude Code and Codex models, which have no reliable list to check, SHALL be reported as `ok` and marked unverified.

#### Scenario: Notifier is not configured
- **WHEN** no Telegram notifier is configured
- **THEN** a `warn notify` line says notices will not be delivered, and the exit status is unaffected

#### Scenario: Claude model cannot be listed
- **WHEN** the implement role uses `harness: claude` with `model: opus`
- **THEN** the role line is `ok` and says the model is not verified

### Requirement: Loop commands refuse on a failed check
`handoff-start`, `handoff-role`, and `handoff-finish` SHALL run the same checks as `handoff-doctor` for the roles they act on before opening a session or writing `loop.yaml`. When any check fails they SHALL print the failing lines, exit non-zero, and change nothing. Warnings SHALL be printed without stopping.

#### Scenario: Start with a failed check
- **WHEN** `handoff-start add-export` runs and the reviewer's harness is not installed
- **THEN** it prints the `fail` line, opens no session, and writes no `loop.yaml`

#### Scenario: Start with only warnings
- **WHEN** the only non-ok result is a `warn notify` line
- **THEN** `handoff-start` prints it and opens the implementer

### Requirement: Doctor checks the Herdr app host
For each host `herdr-app` in use, the `host` checks SHALL confirm that the `herdr-app` and `hc` commands exist, that herdr-core is running, and that the Herdr app window is open, in that order. Each missing piece SHALL be a `fail host` line that says what is missing and how to fix it; when all pass, the line SHALL be `ok` and show the herdr-core version.

#### Scenario: Herdr app is closed
- **WHEN** a role uses `host: herdr-app`, herdr-core is running, and the Herdr app window is not open
- **THEN** a `fail host` line says the Herdr app is not open and asks the user to open it

#### Scenario: herdr-core is not running
- **WHEN** a role uses `host: herdr-app` and `hc server status` fails
- **THEN** a `fail host` line says herdr-core is not running

#### Scenario: A command is missing
- **WHEN** a role uses `host: herdr-app` and `herdr-app` is not installed
- **THEN** a `fail host` line names the missing `herdr-app` command

#### Scenario: Herdr app is ready
- **WHEN** a role uses `host: herdr-app` with both commands present, herdr-core running, and the app open
- **THEN** the host lines are `ok` and show the herdr-core version
