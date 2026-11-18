# Spec Delta

## Purpose

Deliver the shared Telegram notifications for Pi sessions through a Pi extension, mapping Pi's lifecycle and prompt events onto the existing completion, failure, and user-input categories without affecting the Pi session.

## ADDED Requirements

### Requirement: A settled Pi run is reported by how it ended
When a Pi main session settles and will not continue on its own, the extension SHALL send one event to the notification hook with the tool name `Pi`, the session ID, and the working directory. A run whose last assistant message ended normally SHALL be a completion; one whose last assistant message ended with an error SHALL be a failure; a run aborted by the user SHALL send nothing. An intermediate end after which Pi retries or continues SHALL NOT be reported.

#### Scenario: Normal completion
- **WHEN** a Pi main session finishes a run and settles without error
- **THEN** one completion notification for `Pi` is sent with the Pi session label in its title

#### Scenario: Error after retries
- **WHEN** a Pi run ends with an error, Pi retries, and the final attempt also ends with an error
- **THEN** exactly one failure notification is sent after the run settles
- **AND** the message contains no raw error text

#### Scenario: Retry succeeds
- **WHEN** a Pi run ends with an error and the automatic retry completes normally
- **THEN** one completion notification is sent and no failure notification is sent

#### Scenario: User aborts
- **WHEN** the user aborts a Pi run, for example with Escape
- **THEN** no notification is sent

### Requirement: A Pi prompt waiting for the user is reported at once
When a Pi main session starts waiting on an extension UI prompt while a run is in progress, such as the selection shown by pstack `ask_user_question`, the extension SHALL send one user-input event immediately. A prompt opened while the session is idle, such as by a command the user typed, SHALL send nothing. Overlapping or nested prompts that Pi reports as one waiting span SHALL produce one notification. The notification MUST NOT contain the prompt title, options, or answer.

#### Scenario: Question menu opens
- **WHEN** pstack `ask_user_question` opens a selection in a Pi main session
- **THEN** one waiting-for-response notification for `Pi` is sent immediately

#### Scenario: User opens a prompt while idle
- **WHEN** the user runs an extension command that opens a selection while no run is in progress
- **THEN** no notification is sent

#### Scenario: Prompt title contains a question
- **WHEN** the prompt title is `Deploy to production?`
- **THEN** the notification does not contain that text

### Requirement: Only interactive Pi main sessions notify
The extension SHALL send events only from a Pi session that has an interactive UI and is not a subagent. Print mode (`pi -p`), JSON mode, RPC mode without a UI, and pstack subagents (identified by `PI_SUBAGENT_PARENT_SESSION`) SHALL send nothing.

#### Scenario: Print mode
- **WHEN** `pi -p "summarize"` runs to completion
- **THEN** no notification is sent

#### Scenario: Subagent settles
- **WHEN** a pstack subagent started inside an interactive Pi session settles
- **THEN** the subagent sends no notification

### Requirement: Notification work never affects the Pi session
The extension SHALL run the notification hook in the background, MUST NOT wait for Telegram delivery before Pi continues, and SHALL ignore every error from starting or running the hook. A missing notification hook SHALL send nothing and SHALL not report an error in the Pi session.

#### Scenario: Telegram is unavailable
- **WHEN** Telegram delivery fails or times out after a Pi run settles
- **THEN** the Pi session stays usable and shows no error from the notification

#### Scenario: Notification hook is not installed
- **WHEN** the extension is present but the deployed notification hook is missing
- **THEN** nothing is sent and Pi continues normally

### Requirement: The Pi extension file is owned and managed by the notification installer
When Pi is detected, notification setup and repair SHALL install the extension as one file in Pi's global extension directory, carrying an ownership marker, and repeated installation SHALL leave exactly one up-to-date copy. Uninstall SHALL remove that file only when it carries the marker. An existing file of the same name without the marker SHALL be neither overwritten nor removed, and setup SHALL report the conflict.

#### Scenario: Installed twice
- **WHEN** notification setup runs twice on a machine with Pi
- **THEN** Pi's extension directory contains one notification extension identical to the source

#### Scenario: User file with the same name
- **WHEN** `~/.pi/agent/extensions/ai-notify.ts` exists without the ownership marker
- **THEN** setup leaves it unchanged and reports that Pi notifications were not installed

#### Scenario: Uninstall
- **WHEN** notification uninstall runs after a successful installation
- **THEN** the owned extension file is removed and other files in the extension directory are unchanged

#### Scenario: Pi is not installed
- **WHEN** setup runs on a machine without the `pi` command or Pi agent directory
- **THEN** no Pi extension file is created
