# Spec: openspec-commit

## Purpose

Coordinate OpenSpec archival, documentation updates, and a Conventional Commit
while preserving change context, provider routing, and available model attribution.

## Requirements

### Requirement: Coordinate the completion workflow in order
`openspec-commit` SHALL invoke exactly one archive action, followed by
`doc-updater`, followed by `git-commit-writer`. It MUST stop before downstream
steps when archive fails. Optional authorized PR delivery SHALL follow successful local completion and SHALL NOT change this core order or provider routing.

#### Scenario: Successful ordered completion
- **WHEN** a selected OpenSpec change archives successfully
- **THEN** the workflow invokes `doc-updater` after archive
- **AND** invokes `git-commit-writer` only after documentation handling completes

#### Scenario: Archive failure
- **WHEN** `openspec-archive-change` fails or does not return an archive path
- **THEN** the workflow stops without invoking `doc-updater` or `git-commit-writer`

### Requirement: Preserve exact archive context
The workflow SHALL retain `change_id`, `archive_path`, spec sync status, and
archive warnings returned by the archive action. It MUST pass the exact
`archive_path` and `change_id` to downstream capabilities and MUST NOT select an
archive by newest modification time.

#### Scenario: Archive completes
- **WHEN** the archive action returns
  `openspec/changes/archive/YYYY-MM-DD-<change>/`
- **THEN** documentation and commit steps use that exact path
- **AND** no `ls -t` or equivalent newest-directory heuristic is used

### Requirement: Resume an interrupted completion workflow
`openspec-commit` SHALL detect an uncommitted archived change and resume from
documentation update when archive has already completed. It SHALL also recover an explicitly identified completed commit and remote delivery progress from verified Git and PR evidence, including a committed archive. Only missing authorized steps SHALL run; ambiguous or uncertain states MUST NOT be guessed or blindly repeated.

#### Scenario: Retry after documentation failure
- **WHEN** no matching active change exists
- **AND** Git status contains exactly one uncommitted archive candidate
- **THEN** the workflow reuses that archive and skips the archive action

#### Scenario: Multiple resume candidates
- **WHEN** Git status contains multiple uncommitted archive candidates
- **THEN** the workflow asks the user to select one and MUST NOT guess

#### Scenario: Retry after committed archive and failed push
- **WHEN** the selected Change has a verified archive and completion commit but its authorized push failed
- **THEN** the workflow reuses that commit and exact archive context, performing only the missing authorized delivery
- **AND** it does not re-archive, repeat docs unnecessarily or create a duplicate completion commit

#### Scenario: Retry after Closure but failed close
- **WHEN** the PR Closure was confirmed but its close failed
- **THEN** the workflow delegates recovery using the existing summary and actual PR state
- **AND** it does not post a duplicate Closure or reopen ended work

#### Scenario: Uncertain or conflicting recovery evidence
- **WHEN** local history, remote head or PR comments do not identify one consistent completion state
- **THEN** the workflow reports the known partial results and uncertainty or asks for the missing selection
- **AND** it does not select the newest archive, fabricate success or resend writes blindly

### Requirement: Use provider-neutral OpenSpec actions
The workflow SHALL use `openspec-archive-change` as the portable archive
capability and treat provider-native OPSX commands/workflows as aliases to that
same action. It MUST invoke only one entry point.

#### Scenario: Claude Code execution
- **WHEN** the workflow runs in Claude Code
- **THEN** it may resolve the archive capability from `.claude/skills/` or the
  native `.claude/commands/opsx/archive.md` alias
- **AND** performs the archive action once

#### Scenario: Codex execution
- **WHEN** the workflow runs in Codex
- **THEN** it resolves `openspec-archive-change` from the available skill
  integration, including OpenSpec-generated `.codex/skills/`

#### Scenario: Antigravity execution
- **WHEN** the workflow runs in Antigravity
- **THEN** it may resolve the capability from `.agent/skills/` or the native
  `.agent/workflows/opsx-archive.md` alias
- **AND** performs the archive action once

### Requirement: Stage the complete implementation before documentation analysis
After archive succeeds, `openspec-commit` SHALL run `git add -A` before invoking
`doc-updater`, so `git diff HEAD` includes tracked, newly created, synced, and
archived content.

#### Scenario: Feature contains an untracked source file
- **WHEN** archive completes and the feature includes a new untracked file
- **THEN** the coordinator stages the worktree before documentation analysis
- **AND** `doc-updater` can inspect the new file through `git diff HEAD`

### Requirement: Execute git commit step
After archiving the change and updating docs, `openspec-commit` SHALL resolve
the executing `tool_name` and optional root-session `assisting_model` immediately
before delegating final staging and commit execution. It MUST NOT request or
require `assisting_model` before archive or documentation handling.

The coordinator SHALL preserve a user-supplied model name for this work verbatim.
Otherwise, when the current root session exposes a model
name, it MUST use that name automatically and MUST NOT ask for greater precision
or reconfirmation. It SHALL continue using the known current root-session
identity for later commits in the same session while the root model remains
unchanged. Provider-native documentation and commit subagents MUST NOT replace
or make the root-session attribution ambiguous.

Known family versions such as `GPT-5`, `GPT-5.6`, or `GPT-6` SHALL be accepted without
inventing a variant, version, or context size. Attribution records current
collaboration, not original code authorship. Existing changes from another
session MUST NOT cause omission of a known current model. After a root model
switch, use the currently known model rather than stale attribution.
Only if no current root-session model name is known, omit the
model from delegation and report the omitted trailer without blocking commit.
Tool names are not model names. Environment inference, documentation lookup,
session-log parsing, Git history, or commit-only agent identity MUST NOT be used
to guess a model name unavailable in the current context.

In Claude Code and Codex the coordinator SHALL invoke the provider-native
`git-commit-writer-agent` by its exact agent name without supplying a spawn
model or reasoning-effort override; in every other provider it SHALL invoke the
portable `git-commit-writer` skill. It SHALL pass the exact `archive_path`,
`change_id`, `tool_name`, and any known `assisting_model` as task input.
`assisting_model` is Git attribution metadata only and MUST NOT configure a
subagent runtime. If Claude Code or Codex cannot invoke the required subagent,
the workflow MUST stop without falling back to the portable skill.

#### Scenario: Codex or Antigravity environment
- **WHEN** `openspec-commit` reaches the commit step in Codex or Antigravity
- **THEN** Codex automatically records the available current root-session model without asking, including when only committing pre-existing work
- **AND** Codex invokes `git-commit-writer-agent` by exact name without a spawn model or effort override
- **AND** Antigravity invokes the portable `git-commit-writer` skill with the resolved root-session attribution

#### Scenario: Claude Code environment
- **WHEN** the current Claude Code root session performed the work, its supported runtime or session interface exposes the exact model identity, and the model has not changed
- **THEN** `openspec-commit` automatically uses that exact model as `assisting_model`
- **AND** it does not ask the user to provide or confirm the model name

#### Scenario: Same session creates another commit
- **WHEN** the root session performs more work after a commit and its exact model remains unchanged
- **THEN** the next `openspec-commit` invocation uses the same current root-session identity automatically
- **AND** it does not require per-commit reconfirmation

#### Scenario: Documentation or commit subagents use other models
- **WHEN** provider-native documentation or commit subagents run with models different from the root session
- **THEN** the root-session model remains the `assisting_model`
- **AND** the subagent models do not create attribution ambiguity

#### Scenario: Other provider environment
- **WHEN** `openspec-commit` reaches the commit step outside Claude Code and Codex
- **THEN** it invokes the portable `git-commit-writer` skill with the exact archive and resolved root-session attribution context
- **AND** it omits unknown model attribution and reports the omission without requesting user input

#### Scenario: Generic family label is available
- **WHEN** only a known family version such as `GPT-5`, `GPT-5.6`, or `GPT-6` is available
- **THEN** `openspec-commit` passes that name unchanged to the writer
- **AND** it does not invent a variant or request a more precise name

#### Scenario: Work came from another session
- **WHEN** the current session is only finishing work implemented in another session
- **THEN** `openspec-commit` records the available current root-session model as collaboration attribution
- **AND** it does not require identifying the original implementation model

#### Scenario: Model changed after implementation
- **WHEN** the root session switched models and the current model name is available
- **THEN** `openspec-commit` passes the currently known root-session model
- **AND** it does not reuse a stale model name or omit the known current model

#### Scenario: Required commit subagent is missing
- **WHEN** Claude Code or Codex cannot invoke `git-commit-writer-agent`
- **THEN** the workflow stops before commit execution
- **AND** reports the missing provider configuration without invoking `git-commit-writer`

#### Scenario: Commit succeeds
- **WHEN** `git-commit-writer` returns a commit hash
- **THEN** `openspec-commit` reports the exact archive, documentation result, and commit hash

#### Scenario: Documentation runs before attribution is known
- **WHEN** the root-session model is unavailable before documentation handling
- **THEN** `openspec-commit` still completes archive and invokes `doc-updater-agent` or the portable `doc-updater` skill
- **AND** it delegates commit with any known model name, omitting and reporting unknown model attribution

#### Scenario: Primary and commit-writer models differ
- **WHEN** the root-session model is `gpt-5.6-sol` and the configured commit writer uses another model
- **THEN** `assisting_model=gpt-5.6-sol` is passed only as commit task metadata
- **AND** no subagent spawn model or reasoning effort is derived from that value

### Requirement: Route documentation updates by provider capability
`openspec-commit` SHALL invoke `doc-updater-agent` as a provider-native
subagent when running in Claude Code or Codex. For every other provider, it
SHALL invoke the portable `doc-updater` skill. A Claude Code or Codex execution
MUST stop and report a configuration error when its required subagent is
unavailable and MUST NOT silently fall back to the portable skill.

#### Scenario: Claude Code updates documentation
- **WHEN** `openspec-commit` reaches documentation handling in Claude Code
- **THEN** it invokes the `doc-updater-agent` subagent with the exact change and archive context
- **AND** it does not invoke the portable `doc-updater` skill

#### Scenario: Codex updates documentation
- **WHEN** `openspec-commit` reaches documentation handling in Codex
- **THEN** it invokes the `doc-updater-agent` custom agent with the exact change and archive context
- **AND** it does not invoke the portable `doc-updater` skill

#### Scenario: Another provider updates documentation
- **WHEN** `openspec-commit` reaches documentation handling outside Claude Code and Codex
- **THEN** it invokes the portable `doc-updater` skill available through the shared skills integration

#### Scenario: Required documentation subagent is missing
- **WHEN** Claude Code or Codex cannot invoke `doc-updater-agent`
- **THEN** the workflow stops before documentation editing or commit execution
- **AND** reports the missing provider configuration without invoking `doc-updater`

### Requirement: Project-owned provider entrypoints delegate exactly once
The project-owned Claude Code `/opsx:commit` command and Antigravity
`/opsx-commit` workflow SHALL delegate to `openspec-commit` exactly once. Each
entrypoint MUST NOT execute archive, documentation update, or commit as separate
actions outside the delegated skill. Each entrypoint SHALL accept an optional
OpenSpec change name and pass it unchanged to `openspec-commit`.

#### Scenario: Claude Code command receives a change name
- **WHEN** a user invokes `/opsx:commit <change-name>` in Claude Code
- **THEN** the command invokes `openspec-commit` through the Skill tool exactly once
- **AND** passes `<change-name>` unchanged
- **AND** does not execute any completion step separately

#### Scenario: Antigravity workflow receives a change name
- **WHEN** a user invokes `/opsx-commit <change-name>` in Antigravity
- **THEN** the workflow activates `openspec-commit` exactly once
- **AND** passes `<change-name>` unchanged
- **AND** does not use Claude Code-specific `Skill tool` or `/opsx:apply` terminology

#### Scenario: Antigravity cannot activate a nested skill
- **WHEN** the Antigravity host cannot activate `openspec-commit` as a nested skill
- **THEN** the workflow follows the project-owned skill instructions in the current context
- **AND** still performs the completion workflow exactly once

### Requirement: Completion resolves local and remote delivery authority separately
The workflow SHALL distinguish local completion, successful PR handoff and explicitly requested abandoned-PR closure. A local commit request SHALL NOT authorize push, PR creation, merge or close. An absent PR MUST NOT prevent local completion. Unknown PR discovery or missing authority SHALL be reported separately from completed local work. The workflow MUST NOT close linked Issues or delete branches.

#### Scenario: Local completion without a PR
- **WHEN** the request is local-only or no corresponding PR exists
- **THEN** archive, documentation and commit can complete with their actual results reported
- **AND** the workflow does not create a PR, push or mutate GitHub state

#### Scenario: PR exists without remote authorization
- **WHEN** a corresponding PR is known but publishing or closing it was not authorized
- **THEN** the workflow reports the local completion and pending remote action without performing that action

#### Scenario: Remote target is unknown
- **WHEN** remote delivery was requested but the repository, PR or required authority cannot be confirmed
- **THEN** the workflow reports remote delivery as pending or blocked while preserving confirmed local results
- **AND** unknown discovery is not treated as permission for another target

### Requirement: Successful PR handoff uses the verified final published version
Authorized successful PR delivery SHALL confirm the intended head repository and ref, publish through normal Git push when needed, and read back the actual head before describing it. A ready-to-merge Closure SHALL require sufficient review evidence for the final published content. New content MUST NOT inherit an earlier pass. A missing or failed final review SHALL stop the ready-to-merge claim without undoing local completion.

#### Scenario: Final reviewed head is published
- **WHEN** authorized publication is confirmed and valid review evidence covers the actual PR head
- **THEN** the workflow updates the authorized PR description and posts a version-bound Closure through github-pr reply with readback
- **AND** it leaves merge, deployment and independent Issue acceptance unperformed

#### Scenario: Archive or documentation changes the head
- **WHEN** completion creates content not covered by the prior review
- **THEN** the workflow obtains one authorized review round or reports that the final revision needs review before claiming ready to merge
- **AND** it does not auto-repair, poll or copy the old pass to the new head

#### Scenario: Push fails or head moves
- **WHEN** push is rejected or the observed PR head differs from the intended reviewed version
- **THEN** the workflow reports the confirmed commit and the publication or version limit
- **AND** it does not force push, describe unpushed content as published or attest readiness for a different head

### Requirement: Abandoned PR closure delegates the existing close capability
For explicitly authorized cancellation or replacement, the workflow SHALL delegate github-pr close for the confirmed selected PR and evidenced reason. That capability SHALL own Closure publication, readback and state mutation without a duplicate preliminary summary. Successful handoff MUST NOT use close. Closing SHALL NOT require or fabricate a successful implementation review, nor implicitly publish abandoned local work or close Issues.

#### Scenario: Cancelled or superseded PR
- **WHEN** local completion has succeeded and the user explicitly requests closing its cancelled or superseded PR
- **THEN** github-pr close posts and verifies Closure before closing and reading the selected PR state
- **AND** linked Issues, dependencies and branches remain untouched and no unrequested push occurs

#### Scenario: Closure authorization is missing
- **WHEN** closing was not authorized or the reason is unsupported
- **THEN** the workflow retains the local result and reports what prevents closure without closing or merging

#### Scenario: PR is already merged or closed
- **WHEN** the selected PR has already ended
- **THEN** the workflow reports its actual state and only performs explicitly requested missing summary work allowed by github-pr
- **AND** it does not reopen, close again or turn that state into acceptance evidence

### Requirement: Completion reports stage outcomes independently
The workflow SHALL report local archive and sync status, documentation, commit, remote publication, PR description or final review, Closure and close as distinct applicable outcomes with their evidence. A failure at one stage SHALL preserve earlier successful outcomes and leave later dependent actions unperformed. Unknown results SHALL stay uncertain until reconciled; generated URLs or implied atomic rollback are forbidden.

#### Scenario: Commit succeeds but remote update fails
- **WHEN** the completion commit and push are confirmed but the PR description update fails
- **THEN** the report retains the commit and published head and states that the update is incomplete
- **AND** it does not claim completed PR handoff or repeat a confirmed commit on retry

#### Scenario: Summary readback fails
- **WHEN** Closure may have been posted but cannot be confirmed
- **THEN** the workflow preserves the uncertainty and reconciles PR comments before any retry or dependent close

### Requirement: Confirmed local workflows are available outside Work Items
This repository SHALL document the four confirmed local development stages in tracked docs with independently viewable diagrams and mobile previews. The documents SHALL show human publication checkpoints in the first two stages, existing Review, and completion outcome branches. They MUST NOT depend on ignored Work Item contents or impose these personal workflow choices on every managed installation target.

#### Scenario: Fresh checkout has no Work Item
- **WHEN** a reader opens the tracked workflow documentation without the original Work Item or conversation
- **THEN** all four flows, prerequisites, report paths and publication or closure boundaries remain understandable and linked diagrams are available

#### Scenario: Capability status differs from process approval
- **WHEN** the confirmed process documentation describes existing abilities and the new completion integration
- **THEN** it distinguishes confirmed process choices from implementation status and retains manual publication decisions without proposing new first-stage or second-stage workflow skills
