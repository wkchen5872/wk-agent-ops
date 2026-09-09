## Why

The repository tracks project-scoped Codex custom agents under `.codex/agents/`, but they have no template source or installer path and have drifted from the maintained Claude agent definitions. The project needs an explicit, narrow ownership boundary for these two Codex agents so downstream installations receive current instructions and deliberate model settings.

## What Changes

- Add project-owned Codex custom-agent templates for `git-commit-writer` and `doc-updater`.
- Configure Git Commit Writer with `gpt-5.6-luna` at medium reasoning effort.
- Configure Doc Updater with `gpt-5.6-terra` at medium reasoning effort.
- Extend the common installer to copy only `template/common/.codex/agents/` into `.codex/agents/`, without taking ownership of `.codex/skills/` or `.codex/config.toml`.
- Add focused propagation and configuration checks, and update the affected architecture and installation documentation.

## Capabilities

### New Capabilities
- `codex-subagent-templates`: Defines the project-owned Codex custom agents, model settings, and template-to-target consistency requirements.

### Modified Capabilities
- `tooling-target-scope`: Narrows the existing prohibition on `.codex/` ownership so the installer may manage only project-owned `.codex/agents/` while preserving provider-generated Codex artifacts.
- `template-profile-structure`: Adds `.codex/agents/` as a supported common-profile provider-specific template directory.

## Impact

- Affected paths: `template/common/.codex/agents/`, `.codex/agents/`, `scripts/skills/install.sh`, focused installer tests, `AGENTS.md`, `README.md`, and template/architecture documentation.
- Existing `.codex/skills/` and `.codex/config.toml` remain outside installer ownership.
- No new dependency or external service is introduced.
