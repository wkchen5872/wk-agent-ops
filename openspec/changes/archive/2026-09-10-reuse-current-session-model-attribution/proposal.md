## Why

Commit workflows repeatedly ask for `AI-Assisted-By` even when the current root
session performed the work, exposes an exact model identity, and has not changed
models. This redundant confirmation makes both orchestrated and standalone
commits unnecessarily interruptive.

## What Changes

- Automatically use the exact current root-session model when that session
  performed the work and its model has not changed.
- Reuse that root-session attribution for later commits in the same unchanged
  session without asking again.
- Keep asking when work came from another session, the root model changed, or
  the exact root model is unavailable.
- Clarify that documentation and commit subagents neither replace nor make the
  root-session attribution ambiguous.
- Prevent `openspec-commit` from requesting attribution before its commit step.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-commit`: Prefer exact unchanged root-session attribution and defer
  any necessary prompt until commit delegation.
- `git-commit-writer`: Reuse exact unchanged root-session attribution for
  standalone commits without repeated confirmation.

## Impact

The OpenSpec commit coordinator, portable commit writer, provider-native commit
agents, their canonical specifications, focused contract tests, and generated
installed copies are affected. No new runtime state, cache, session-log parser,
or dependency is introduced.
