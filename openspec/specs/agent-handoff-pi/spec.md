# agent-handoff-pi Specification

## Purpose

Let Pi sessions play implement, review, and finish roles in the handoff loop while guaranteeing that each role runs on the declared provider, model, effort, and billing source, stopping the loop whenever any of them cannot be confirmed.

## Requirements

### Requirement: A Pi role declares its provider and billing source
A role template with `harness: pi` SHALL set `provider`, `model`, `effort`, and `billing`. `billing` SHALL be `subscription` or `api`. `effort` SHALL be one of Pi's thinking levels: `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, or `max`. A missing or invalid field SHALL be refused before any session opens. A template of another harness that sets `provider` or `billing` SHALL be refused.

#### Scenario: Pi role omits billing
- **WHEN** the implement template sets `harness: pi`, `provider: openai-codex`, `model: gpt-6.2-sol`, and `effort: high` but no `billing`
- **THEN** `handoff-start` exits non-zero, names the missing `billing` field, and opens no session

#### Scenario: Codex role sets billing
- **WHEN** a template with `harness: codex` sets `billing: api`
- **THEN** the command refuses and opens no session

#### Scenario: Unknown billing value
- **WHEN** a Pi template sets `billing: free`
- **THEN** the command exits non-zero, names the allowed values `subscription` and `api`, and opens no session

### Requirement: The model must exist under the declared provider
The model of a Pi role SHALL match exactly one model ID that Pi lists as available under the declared provider. Aliases, fuzzy matches, and a `provider/` prefix in `model` SHALL be refused.

#### Scenario: Same model ID under two providers
- **WHEN** Pi lists `gpt-6.2-sol` under both `openai` and `openai-codex` and the template declares `provider: openai-codex`, `model: gpt-6.2-sol`
- **THEN** the role is accepted and is bound to `openai-codex`

#### Scenario: Alias is not a model ID
- **WHEN** a Pi template sets `model: opus`
- **THEN** the command exits non-zero, states that the model is not listed under the provider, and opens no session

### Requirement: The actual credential must match the declared billing
Before a Pi role session opens, the declared provider's credential SHALL be checked without reading or printing secrets. The role SHALL be accepted only when the credential is ready and its type matches the declared billing: `oauth` for `subscription`, `api_key` for `api`. Any other credential type, a credential that is not ready, or a check that cannot run SHALL be treated as a mismatch.

#### Scenario: Subscription declared and subscription credential found
- **WHEN** the template declares `provider: openai-codex`, `billing: subscription` and the credential check reports `ready` with `oauth`
- **THEN** the role is accepted

#### Scenario: Subscription declared but API key in use
- **WHEN** the template declares `provider: anthropic`, `billing: subscription` and the credential check reports `api_key`
- **THEN** the role is refused with a message naming the declared and the actual billing

#### Scenario: Credential is not ready
- **WHEN** the credential check for the declared provider reports `not_ready` or `invalid`
- **THEN** the role is refused and no session opens

#### Scenario: Pi CLI is unavailable
- **WHEN** the `pi` command cannot be run
- **THEN** every Pi role is refused and no session opens

### Requirement: Anthropic subscription use is flagged, not refused
When a Pi role declares `provider: anthropic` and `billing: subscription` and the credential check confirms `oauth`, the role SHALL be accepted, and `handoff-start` SHALL print a warning that Anthropic subscription use through Pi may consume paid extra usage. The warning MUST NOT apply when the declaration and the credential disagree; that case SHALL be refused.

#### Scenario: Matching Anthropic subscription
- **WHEN** a Pi role declares `anthropic` with `subscription` and the credential is `oauth`
- **THEN** the loop starts and the output contains the extra usage warning

### Requirement: Routing runs when a Pi agent settles
When a Pi main session will not continue on its own, the handoff routing SHALL run once for that stop with the session's working directory, with the same behavior as a Claude Code or Codex stop. It MUST NOT run when the session is a subagent, and MUST NOT run at an intermediate end after which Pi retries, compacts, or continues with queued messages. Failures SHALL NOT affect the Pi session.

#### Scenario: Implementer finishes its turn
- **WHEN** a Pi implementer writes an implement record and its run settles
- **THEN** routing runs once for that worktree

#### Scenario: Subagent finishes
- **WHEN** a subagent started inside a Pi role settles
- **THEN** routing does not run

#### Scenario: Run ends but Pi retries
- **WHEN** a Pi run ends and Pi automatically retries it
- **THEN** routing runs only after the retried run settles

### Requirement: A Pi role starts from settings written into its worktree
Before a Pi role session opens, its worktree SHALL receive `.pi/settings.json` setting Pi's default provider, model, and thinking level to the template's `provider`, `model`, and `effort`, which SHALL also be passed to the role's host. The file SHALL be ignored through the repository's local exclude file and MUST NOT make the worktree unclean. An existing file with identical content SHALL be reused; a different or tracked one SHALL be refused, not overwritten.

#### Scenario: Xirp ignores Pi launch options
- **WHEN** Pi's saved default is `openai-codex/gpt-6-sol` at `medium`, Xirp drops the Pi launch options, and the implement template declares `openai-codex`, `gpt-5.6-luna`, `low`
- **THEN** the implementer session runs `openai-codex/gpt-5.6-luna` at `low`

#### Scenario: Settings file keeps the worktree clean
- **WHEN** the settings file has been written into the implementer worktree
- **THEN** `git status --porcelain` in that worktree is empty and the file is not tracked

#### Scenario: Repository has its own Pi settings
- **WHEN** the role worktree already contains a different `.pi/settings.json`
- **THEN** the role is refused with a message naming the file, the file is unchanged, and no session opens

#### Scenario: Pi role on herdr
- **WHEN** the review role uses `host: herdr`, `harness: pi`, and declares `anthropic`, `claude-haiku-5-5`, `low`
- **THEN** the reviewer's worktree has the settings file and the herdr tab runs Pi on `anthropic/claude-haiku-5-5` at `low`

### Requirement: A worktree hosts at most one Pi role
`handoff-start` SHALL refuse a loop in which two or more Pi roles would work in the same worktree, counting the implement role in the implementer worktree, a `shared` review or finish role in the implementer worktree, and a `new` review or finish role in its own worktree. The message SHALL name the roles and tell the user to set `worktree: new` for the Pi review or finish role. A Pi role MAY share a worktree with Claude Code and Codex roles.

#### Scenario: Pi implementer and shared Pi reviewer
- **WHEN** the implement and review templates are both Pi and the review template has `worktree: shared`
- **THEN** `handoff-start` exits non-zero naming implement and review, and opens no session and creates no worktree

#### Scenario: Pi implementer with Codex reviewer in the same worktree
- **WHEN** the implement template is Pi and the review template is Codex with `worktree: shared`
- **THEN** the loop starts as usual

#### Scenario: Second Pi role in a new worktree
- **WHEN** the implement and review templates are both Pi and the review template has `worktree: new`
- **THEN** the loop starts as usual

### Requirement: Handoff worktrees of a trusted repository are trusted automatically
The Pi trigger SHALL trust a working directory for the current process only when it is in a linked worktree that an untracked `loop.yaml` there names as a role worktree, and the nearest saved Pi trust decision for the repository's main worktree or one of its parents is trust. Otherwise, and on any error, it SHALL leave the decision to Pi. It MUST NOT save a trust decision.

#### Scenario: Reviewer opens in a new review worktree
- **WHEN** a Pi reviewer opens in `<repo>-add-export-review`, which the untracked `loop.yaml` lists as the reviewer worktree, and the main worktree is trusted
- **THEN** Pi starts without a trust prompt and loads the worktree's `.pi/settings.json`, and Pi's saved trust decisions are unchanged

#### Scenario: Repository was never trusted
- **WHEN** the main worktree has no saved trust decision and a Pi session starts in its handoff worktree
- **THEN** the trigger leaves the decision to Pi

#### Scenario: Loop file is tracked by Git
- **WHEN** a repository commits a `loop.yaml` that names a worktree
- **THEN** the trigger does not trust that worktree

### Requirement: Pi roles need the trigger and a trusted repository
Before opening a Pi role session, `handoff-start` and the hook SHALL check that the Pi trigger is installed in Pi's global extension directory and that the user has trusted the repository's main worktree in Pi. When either check fails, the role SHALL be refused with a message telling the user to run the handoff installer or to run `/trust` in Pi in the main worktree, so that no background session waits at a trust prompt.

#### Scenario: Main worktree not trusted
- **WHEN** a loop has a Pi role and the main worktree has no saved trust decision
- **THEN** `handoff-start` exits non-zero, tells the user to run `/trust` in Pi in the main worktree, and opens no session

#### Scenario: Trigger not installed
- **WHEN** a loop has a Pi role and `~/.pi/agent/extensions/wk-handoff.ts` does not exist
- **THEN** `handoff-start` exits non-zero, tells the user to run the handoff installer, and opens no session
