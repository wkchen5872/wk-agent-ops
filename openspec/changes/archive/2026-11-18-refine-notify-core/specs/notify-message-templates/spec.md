# Spec Delta

## Purpose

Keep notification wording and event classification as editable data, so messages and categories can change without changing hook logic, and users can adjust wording on their own machine.

## ADDED Requirements

### Requirement: Messages are rendered from named templates
Each notification kind SHALL have a named template whose `{name}` placeholders are replaced with event values. Built-in templates SHALL be deployed with the hook and SHALL reproduce the current wording of completion, stopped, and waiting-for-response messages.

#### Scenario: Completion uses the built-in template
- **WHEN** a completion event is rendered with no user template
- **THEN** the message equals the current Task Complete message for the same tool, project, session, and time

#### Scenario: Placeholder is replaced
- **WHEN** a template contains `{project}` and the event project is `fio-pv-twin`
- **THEN** the rendered message contains `fio-pv-twin` in that position

### Requirement: User templates override built-in ones
A file `~/.config/ai-notify/templates/<name>.md` SHALL replace the built-in template of the same name. A missing, empty, or unreadable user template SHALL fall back to the built-in one. Installation, update, repair, and uninstall MUST NOT create, modify, or delete user templates.

#### Scenario: User template present
- **WHEN** a non-empty user template exists for the completion kind
- **THEN** completion messages are rendered from the user template

#### Scenario: User template is empty
- **WHEN** the user template file exists but is empty
- **THEN** the built-in template is used

#### Scenario: Update keeps user templates
- **WHEN** the update command redeploys the hook
- **THEN** every file under the user template directory is unchanged

### Requirement: Rendering is substitution only
Rendering SHALL escape substituted values so that characters with meaning in the Telegram message format are shown literally. A line that consists only of placeholders and renders empty SHALL be removed. An unknown placeholder SHALL be left unchanged. Templates SHALL NOT support conditions, loops, or command execution.

#### Scenario: Value contains formatting characters
- **WHEN** a substituted value contains `_` or `*`
- **THEN** the delivered message shows those characters literally and is accepted by Telegram

#### Scenario: Optional line has no value
- **WHEN** a template line contains only `{reason}` and the event has no reason
- **THEN** the rendered message has no empty line in its place

#### Scenario: Unknown placeholder
- **WHEN** a template contains `{nope}`, which no event provides
- **THEN** the rendered message still contains `{nope}`

#### Scenario: Template contains shell syntax
- **WHEN** a template contains `$(date)` or backticks
- **THEN** the text is delivered literally and nothing is executed

### Requirement: Events are classified by a data table
The hook SHALL resolve each recognized provider event to a category, a switch, and a template through a data table deployed with the hook. Adding or renaming a notification kind SHALL require a table entry and a template, not a new branch of hook logic. An event absent from the table SHALL keep the current generic-event behavior.

#### Scenario: Known event resolves through the table
- **WHEN** a Codex stop event arrives
- **THEN** it resolves to the completion category, the completion switch, and the completion template

#### Scenario: Unknown event
- **WHEN** an event absent from the table arrives under level `all`
- **THEN** the generic event message is sent as before
