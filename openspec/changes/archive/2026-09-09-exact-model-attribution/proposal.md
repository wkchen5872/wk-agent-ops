## Why

The commit workflow currently rejects missing attribution but does not distinguish an exact runtime model identifier from a generic model-family label. This allowed `GPT-5` to be recorded even though the implementation ran on a more specific model.

## What Changes

- Require the provider-facing `openspec-commit` coordinator to resolve and freeze the primary implementation model from provider runtime context when that context exposes an exact value.
- Define provider-specific resolution boundaries: Codex may use its current turn metadata; Claude Code may use only model identity exposed through its supported runtime/session interface or explicit caller input.
- Reject generic family labels and unsupported inference sources as exact attribution.
- Ask the user immediately before commit delegation when no exact primary implementation model is available or when model switching makes the primary model ambiguous.
- Keep provider-specific discovery out of the shared commit writer; it continues to consume validated attribution metadata only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-commit`: Resolve, validate, and freeze exact primary-model attribution before commit delegation.
- `git-commit-writer`: Accept only an already-resolved exact assisting model and reject generic or missing attribution values.

## Impact

- Affects the `openspec-commit` and `git-commit-writer` templates, provider-specific agents, focused tests, and related documentation.
- Does not add a session-log parser, change subagent runtime configuration, or amend existing commits.
