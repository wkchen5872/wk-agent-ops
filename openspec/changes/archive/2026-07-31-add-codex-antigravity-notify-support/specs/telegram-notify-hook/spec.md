## ADDED Requirements

### Requirement: Codex native lifecycle notifications
The notification installer SHALL register idempotent Codex `Stop` and
`PermissionRequest` command hooks in the user Codex hook configuration when
Codex is detected. The hooks SHALL preserve unrelated configuration and SHALL
not allow, deny, continue, or stop Codex on the user's behalf.

#### Scenario: Codex hooks are registered once
- **WHEN** Codex hook registration runs twice for the same deployed notification hook
- **THEN** `Stop` and `PermissionRequest` each contain one matching command while unrelated hooks remain unchanged

#### Scenario: Codex completion keeps the native stop decision
- **WHEN** the notification hook receives a Codex `Stop` payload
- **THEN** it emits a completion notification and returns neutral JSON that does not continue or stop Codex

#### Scenario: Codex approval keeps the native prompt
- **WHEN** the notification hook receives a Codex `PermissionRequest` payload
- **THEN** it emits an action-required notification and returns no allow or deny decision so the normal Codex approval prompt continues

### Requirement: Antigravity completion notifications
The notification installer SHALL register an idempotent named Antigravity
`Stop` command hook in the global Antigravity hook configuration when
Antigravity CLI is detected. The hook SHALL return a non-continue decision and
SHALL notify only after `fullyIdle` is true.

#### Scenario: Fully idle model stop is complete
- **WHEN** Antigravity sends `fullyIdle=true` and `terminationReason=model_stop`
- **THEN** the hook emits a task-complete notification and returns a decision that allows Antigravity to stop

#### Scenario: Background work remains active
- **WHEN** Antigravity sends `fullyIdle=false`
- **THEN** the hook emits no Telegram notification and still returns a decision that allows the current stop transition

#### Scenario: Error termination is not reported as success
- **WHEN** Antigravity sends `fullyIdle=true` with `terminationReason=error` or `max_steps_exceeded`
- **THEN** the hook reports a stopped execution without including the raw error or claiming successful completion

### Requirement: Opt-in Antigravity approval observer
The installer SHALL offer an opt-in Antigravity status-line observer that emits
an action-required notification when `tool_confirmation_pending` transitions
from false to true for a conversation. Repeated true states SHALL be
deduplicated until a false state resets that conversation.

#### Scenario: First pending confirmation notifies
- **WHEN** an opted-in observer receives `tool_confirmation_pending=true` for a conversation that is not already pending
- **THEN** it emits one action-required notification and records the pending state

#### Scenario: Repeated pending state is deduplicated
- **WHEN** the observer receives another true state for the same still-pending conversation
- **THEN** it emits no additional action-required notification

#### Scenario: Existing custom status line is preserved
- **WHEN** Antigravity settings already contain a different `statusLine.command`
- **THEN** registration reports a conflict and leaves the existing status line unchanged

#### Scenario: Observer remains a valid status line
- **WHEN** the observer is invoked by Antigravity
- **THEN** it writes a compact agent-state value to stdout while keeping Telegram delivery details off stdout

### Requirement: Cross-provider lifecycle preservation
Setup, update, status, and uninstall flows SHALL manage only notification-owned
Codex and Antigravity entries, preserve unrelated JSON fields and hook entries,
and remain idempotent.

#### Scenario: Provider-aware setup
- **WHEN** setup runs on a machine where Codex or Antigravity CLI is detected
- **THEN** completion hooks are registered for each detected CLI and the optional Antigravity approval observer is offered separately

#### Scenario: Status reports provider coverage
- **WHEN** notification status is requested
- **THEN** it reports whether Claude, Gemini, Codex, Antigravity completion, Antigravity approval, and Copilot registrations are present without exposing credentials

#### Scenario: Uninstall preserves unrelated settings
- **WHEN** notification uninstall runs
- **THEN** only commands owned by this notification installation are removed from Codex and Antigravity configuration

### Requirement: Notification privacy and bounded failure
Codex and Antigravity notifications SHALL include only the CLI name, project,
session label, event type, and a generic tool or termination label. They SHALL
exclude raw commands, prompts, transcripts, tool arguments, and raw error text.
Telegram delivery failure SHALL not block the invoking CLI beyond the configured
short timeout.

#### Scenario: Codex approval payload contains a command
- **WHEN** a Codex approval payload includes a raw command or other tool arguments
- **THEN** the Telegram message identifies the requesting tool but does not contain those arguments

#### Scenario: Telegram is unavailable
- **WHEN** Telegram delivery times out or fails
- **THEN** the hook returns the provider's neutral control response and the AI CLI continues its native flow

