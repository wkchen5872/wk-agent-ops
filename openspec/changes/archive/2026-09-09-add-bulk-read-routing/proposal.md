## Why

Read-heavy discovery in unfamiliar codebases can consume the parent agent's context and delay the engineering work that requires its stronger model. A user-level routing skill and bounded read-only subagent can offload that discovery while keeping verification and decisions with the parent.

## What Changes

- Add an independently maintained user-level template for a shared `bulk-read-routing` skill and provider-native `bulk-reader-agent` definitions for Claude Code and Codex.
- Add a dedicated installer that writes only those assets to each provider's user-level skill and agent directories, without changing the project-level common installer.
- Route only broad, location-unknown discovery through exactly one named subagent; keep targeted reads, root-cause analysis, decisions, and edits in the parent.
- Add static installation checks and replayable provider A/B evaluation guidance for routing correctness, read-only behavior, evidence quality, tokens, and elapsed time.

## Capabilities

### New Capabilities

- `bulk-read-routing`: User-level cross-provider routing and installation for bounded read-only codebase discovery.

### Modified Capabilities

- None.

## Impact

- Adds an isolated user-template source and dedicated installer under this repository.
- Installs user-level files for Claude Code and Codex only; existing project-level templates and `scripts/skills/install.sh` remain unchanged.
- Adds focused shell validation and evaluation documentation; no new dependency or network operation is introduced.
