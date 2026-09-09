## Why

`openspec-commit` currently routes Codex through portable skills even though the
project now installs model-pinned Codex custom agents, and the shared skill and
provider-specific agent use the same names. This makes delegation ambiguous and
prevents the workflow from reliably using the configured model and reasoning
effort while retaining compatibility with providers that only support skills.

## What Changes

- Rename the Claude Code and Codex `doc-updater` and `git-commit-writer`
  subagents with the explicit `-agent` suffix; keep portable skill names
  unchanged.
- Route `openspec-commit` explicitly to the suffixed subagents on Claude Code
  and Codex.
- Stop and report a configuration error when a required Claude Code or Codex
  subagent is unavailable instead of silently falling back to a skill.
- Route every other provider through the existing portable `doc-updater` and
  `git-commit-writer` skills installed under `.agents/skills/`.
- Keep documentation update before commit execution and preserve the existing
  archive and attribution context across either route.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-commit`: Define deterministic provider routing between native
  subagents and portable skill fallback.
- `codex-subagent-templates`: Rename the managed Codex custom agents with the
  `-agent` suffix while preserving their configured models and effort.
- `doc-updater`: Update the managed Claude Code agent location to the suffixed
  name while retaining the portable skill name.

## Impact

- Affects the project-owned templates under `template/common/.claude/agents/`,
  `template/common/.codex/agents/`, and
  `template/common/skills/openspec-commit/`.
- Requires installer verification that obsolete unsuffixed generated agent
  files are removed and suffixed files are installed without touching portable
  skills or unrelated `.codex/` content.
- Updates tests and user-facing documentation that refer to the old subagent
  names or provider routing.
