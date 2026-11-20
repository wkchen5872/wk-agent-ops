# agent-handoff-hosts Specification

## Purpose

Define where the sessions of an agent handoff loop live — the session host — and how the loop opens, messages, checks, and closes those sessions on each supported host, so the same loop runs under Xirp or herdr.

## Requirements

### Requirement: Each role runs on a configured host
`roles.yaml` SHALL accept a top-level `host` of `xirp`, `herdr`, or `herdr-app`, defaulting to `xirp` when absent, and a per-role `host` that overrides it. `herdr` SHALL mean the herdr terminal UI and `herdr-app` the Herdr desktop app. Any other value SHALL be refused before any session opens. The host in effect for each role SHALL be recorded in `loop.yaml` when the loop starts, and every later step SHALL take the host from `loop.yaml`, never from environment variables.

#### Scenario: No host is configured
- **WHEN** `roles.yaml` has no `host` and `handoff-start add-export` runs
- **THEN** every role in `loop.yaml` records `host: xirp` and the loop behaves as before this change

#### Scenario: One role overrides the host
- **WHEN** `roles.yaml` sets `host: xirp` and the review role sets `host: herdr`
- **THEN** the implementer opens through Xirp and the reviewer later opens through herdr

#### Scenario: Unknown host
- **WHEN** a role sets `host: tmux`
- **THEN** `handoff-start` exits non-zero, names the role and the accepted hosts, and opens nothing

#### Scenario: Desktop app host
- **WHEN** `roles.yaml` sets `host: herdr-app`
- **THEN** every role in `loop.yaml` records `host: herdr-app`, and no herdr terminal UI command is used

### Requirement: A configured host that is unavailable stops the loop
When a role's host cannot be used — its command is missing, for herdr the selected session's server is not running, or for herdr-app herdr-core or the Herdr app window is not running — the loop SHALL NOT fall back to another host. `handoff-start`, `handoff-role`, and `handoff-finish` SHALL refuse and name what is missing.

#### Scenario: herdr server is not running
- **WHEN** the implement role uses `host: herdr` and the selected herdr session has no running server
- **THEN** `handoff-start` exits non-zero, says the herdr server is not running, and opens no session on any host

#### Scenario: Herdr app is not open
- **WHEN** the implement role uses `host: herdr-app` and the Herdr app window is not running
- **THEN** `handoff-start` exits non-zero, asks the user to open the Herdr app, and opens no session on any host

### Requirement: The herdr session is chosen predictably
A herdr role SHALL use the current herdr session when the command runs inside a herdr pane, otherwise the session named by `herdr_session` in `roles.yaml`, otherwise herdr's default session. The chosen session SHALL be recorded for the role in `loop.yaml` and used for every later herdr operation of that role.

#### Scenario: Started outside herdr with a named session
- **WHEN** `roles.yaml` sets `herdr_session: work` and `handoff-start` runs in a terminal outside herdr
- **THEN** the implementer opens in the herdr session `work` and `loop.yaml` records `work` for that role

#### Scenario: Started inside a herdr pane
- **WHEN** `handoff-start` runs inside a pane of the herdr session `dev`
- **THEN** the implementer opens in `dev`, whatever `herdr_session` says

### Requirement: herdr loops are grouped under the repository workspace
A herdr loop SHALL place its sessions in a herdr workspace for the loop's worktree, grouped under the workspace of the repository's main worktree. When the main worktree has no open workspace, it SHALL be opened automatically. A role whose worktree is the main worktree SHALL use the repository workspace. Workspaces SHALL be opened without taking focus.

#### Scenario: Repository is not open in herdr yet
- **WHEN** no herdr workspace exists for the main worktree and a herdr loop starts with a new worktree
- **THEN** a workspace for the main worktree is opened and the loop's worktree workspace is grouped under it

#### Scenario: Shared reviewer joins the loop workspace
- **WHEN** a herdr reviewer with `worktree: shared` opens
- **THEN** it appears in the same workspace as the implementer

### Requirement: Each herdr role gets its own tab
Each herdr role SHALL open in its own tab named with the role template's `name`, start the template's harness with its model and effort (and provider for Pi) set explicitly, and then receive the template's prompt as a separate submission.

#### Scenario: Implementer opens in herdr
- **WHEN** a herdr loop for `add-export` starts with a Claude Code implement template using `opus` at `high`
- **THEN** a tab named `claude - impl - add-export` runs Claude Code on `opus` at `high` and has received the implement prompt

### Requirement: herdr sessions are identified by pane and native session
For a herdr role, `loop.yaml` SHALL record the pane ID as the role's session and, once herdr reports it, the agent's native session identifier. Before sending a message, the loop SHALL confirm that the pane still runs the role's harness and, when the native identifier is recorded, the same native session; otherwise the delivery SHALL count as failed.

#### Scenario: Pane was reused by another program
- **WHEN** the reviewer's pane now runs a shell instead of the reviewer agent and a message is due
- **THEN** no text is sent to the pane and the delivery is treated as failed

### Requirement: A herdr role waiting on a dialog is retried, not answered
When a herdr agent is waiting on a trust prompt, an approval, or another dialog at start or when a message is due, the loop SHALL NOT answer the dialog. It SHALL keep the pane, treat the step as a failed delivery, and tell the user which workspace and tab need attention. A later retry SHALL send the pending prompt to the same pane without opening another.

#### Scenario: New worktree asks for trust
- **WHEN** the herdr reviewer stops at Claude Code's folder trust prompt
- **THEN** the user gets one attention notice naming the reviewer's workspace and tab, the record stays unprocessed, and no dialog option is selected

#### Scenario: Retry after the user answers
- **WHEN** the user has accepted the trust prompt and runs `handoff-route --foreground`
- **THEN** the review prompt is sent to the same pane and the record is marked processed

### Requirement: Closing a herdr loop closes what it opened
Cleanup of a herdr loop SHALL close the workspaces the loop created, and the tabs it created in the repository workspace, before removing the loop's worktrees. It MUST NOT close workspaces, tabs, or panes the loop did not create.

#### Scenario: Loop with a new worktree is cleaned up
- **WHEN** a finished herdr loop that used a new worktree is cleaned up with `--yes`
- **THEN** its worktree workspace and agents are gone, the repository workspace remains, and the worktree is removed afterwards

#### Scenario: Loop in the main worktree is cleaned up
- **WHEN** a herdr loop started with `--worktree here` is cleaned up
- **THEN** only the loop's tabs are closed and the repository workspace stays open

### Requirement: Xirp behavior is unchanged
A role on the `xirp` host SHALL open, receive messages, be checked, and be deleted exactly as before this change, through the Xirp project registered for the main worktree.

#### Scenario: Existing Xirp loop
- **WHEN** a loop whose `loop.yaml` has no host fields is routed after this change
- **THEN** it is treated as an `xirp` loop and its messages go through Xirp as before

### Requirement: herdr-app loops open in a space of the Herdr app
A herdr-app role SHALL open through the Herdr app so that it is shown there, never as a terminal the app does not show. The first herdr-app role in a worktree SHALL open a new space for that worktree, named after the change, and later roles in the same worktree SHALL open as tabs in that space. Each tab SHALL be named with the role template's `name`, and nothing SHALL take focus.

#### Scenario: Implementer opens in the app
- **WHEN** a herdr-app loop for `add-export` starts
- **THEN** the Herdr app shows a space `add-export` with a tab `claude - impl - add-export`, and the user's current space stays in front

#### Scenario: Shared reviewer joins the space
- **WHEN** a herdr-app reviewer with `worktree: shared` opens
- **THEN** it appears as a new tab in the `add-export` space

### Requirement: A herdr-app role starts with its template and first prompt
A herdr-app role SHALL start the template's harness with its model and effort (and provider for Pi) set explicitly, in the user's login shell environment, and SHALL hand its first prompt to the app to deliver once the agent is ready. The loop SHALL then confirm that the agent started working; when that is not observed in time, the prompt SHALL be kept as unconfirmed, the user notified once, and the prompt never resent.

#### Scenario: Pi role finds its command
- **WHEN** a herdr-app role uses `harness: pi` and `pi` is installed only through the user's shell profile
- **THEN** the role starts Pi with the template's provider, model, and thinking level

#### Scenario: First prompt delivered
- **WHEN** the implementer opens and the agent starts working on the handed prompt
- **THEN** `loop.yaml` records the role's terminal, space, and tab, and the start is reported as delivered

#### Scenario: First prompt not observed
- **WHEN** the agent shows no started turn within the wait
- **THEN** the prompt is kept in `<role>-unconfirmed.txt`, one attention notice is sent, and the prompt is not sent again

### Requirement: herdr-app messages go only to the role's own idle agent
Before messaging a herdr-app role, the loop SHALL confirm that its terminal is live, still runs the role's harness, and reports idle or done. Delivery SHALL count only when the agent starts a turn. A blocked agent SHALL NOT be answered: the user SHALL get one attention notice naming the space and tab, and the record SHALL stay unprocessed for a later retry.

#### Scenario: Message to the implementer
- **WHEN** a `changes-required` review is processed and the implementer's terminal is idle
- **THEN** the message is delivered to that terminal and the record is marked processed

#### Scenario: Agent waits on a permission prompt
- **WHEN** the reviewer reports blocked with kind permission and a message is due
- **THEN** no text is sent, one attention notice names the reviewer's space and tab, and the record stays unprocessed

#### Scenario: Terminal no longer runs the agent
- **WHEN** the reviewer's terminal has finished or runs another program
- **THEN** no text is sent and the delivery is treated as failed

### Requirement: Closing a herdr-app loop closes what it opened
Cleanup of a herdr-app loop SHALL close the spaces the loop opened, and the tabs it added to other spaces, ending their terminals and removing them from the app, before removing the loop's worktrees. It MUST NOT close spaces, tabs, or terminals the loop did not open. When closing fails, the worktrees SHALL NOT be removed.

#### Scenario: Finished herdr-app loop is cleaned up
- **WHEN** a finished herdr-app loop is cleaned up with `--yes`
- **THEN** its space and terminals are gone from the app, the worktree is removed afterwards, and the branch is kept

#### Scenario: App closed during cleanup
- **WHEN** the Herdr app is not running when cleanup runs
- **THEN** cleanup exits non-zero, asks the user to open the app, and removes no worktree
