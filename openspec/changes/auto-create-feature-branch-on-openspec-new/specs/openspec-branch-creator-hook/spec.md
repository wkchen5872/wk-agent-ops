## ADDED Requirements

### Requirement: Hook detects openspec new change commands
The hook script SHALL read JSON from stdin and detect when a Bash tool call contains the pattern `openspec new change "<name>"` or `openspec new change '<name>'` or `openspec new change <name>` (unquoted).

#### Scenario: Matching command triggers branch creation
- **WHEN** stdin JSON contains `tool_input.command` matching `openspec new change "my-feature"`
- **THEN** the hook extracts change name `my-feature` and proceeds to branch creation

#### Scenario: Non-matching command is silently ignored
- **WHEN** stdin JSON contains `tool_input.command` that does not contain `openspec new change`
- **THEN** the hook exits 0 immediately without any git operations

#### Scenario: Empty or malformed stdin
- **WHEN** stdin is empty or contains invalid JSON
- **THEN** the hook exits 0 without error

### Requirement: Hook creates feature branch in project directory
The hook SHALL create a `feature/<name>` git branch in the project directory. The project directory is resolved from `CLAUDE_PROJECT_DIR` environment variable, falling back to the `project_dir` field in the stdin JSON, falling back to `PWD`.

#### Scenario: Branch does not exist — create it
- **WHEN** `feature/<name>` does not exist locally
- **THEN** the hook runs `git -C "$PROJECT_DIR" checkout -b "feature/<name>"`

#### Scenario: Branch already exists — switch to it
- **WHEN** `feature/<name>` already exists locally
- **THEN** the hook runs `git -C "$PROJECT_DIR" checkout "feature/<name>"` (no error, idempotent)

#### Scenario: CLAUDE_PROJECT_DIR is set
- **WHEN** `CLAUDE_PROJECT_DIR=/path/to/repo` is set in the environment
- **THEN** the hook uses that path as the project directory for git operations

#### Scenario: CLAUDE_PROJECT_DIR is not set, project_dir in JSON
- **WHEN** `CLAUDE_PROJECT_DIR` is unset and stdin JSON contains `"project_dir": "/path/to/repo"`
- **THEN** the hook uses the JSON `project_dir` value

#### Scenario: CLAUDE_PROJECT_DIR is not set, no project_dir in JSON
- **WHEN** both `CLAUDE_PROJECT_DIR` and JSON `project_dir` are unavailable
- **THEN** the hook falls back to `PWD`

### Requirement: Hook never blocks Claude Code
The hook script SHALL always exit with code 0, regardless of any error (git failure, missing jq, network issue, non-git directory).

#### Scenario: git checkout fails
- **WHEN** `git checkout -b feature/<name>` fails (e.g., dirty working tree)
- **THEN** the hook logs the error to stderr and exits 0

#### Scenario: jq is not installed
- **WHEN** `jq` is not available on the system
- **THEN** the hook falls back to grep-based JSON parsing or skips branch creation, and exits 0

### Requirement: Hook is registered via PostToolUse in settings.json
The install script SHALL add a `PostToolUse` entry to `~/.claude/settings.json` with `matcher: "Bash"` pointing to the deployed hook script. Registration SHALL be idempotent.

#### Scenario: First-time install registers the hook
- **WHEN** `install.sh` is run and no existing entry for the hook exists in settings.json
- **THEN** the hook command is added under `hooks.PostToolUse` with matcher `"Bash"`

#### Scenario: Re-running install does not duplicate the hook
- **WHEN** `install.sh` is run a second time
- **THEN** only one hook entry exists in settings.json (idempotent)

#### Scenario: Uninstall removes the hook entry
- **WHEN** `uninstall.sh` is run
- **THEN** the hook entry is removed from `hooks.PostToolUse` in settings.json and the deployed script is deleted
