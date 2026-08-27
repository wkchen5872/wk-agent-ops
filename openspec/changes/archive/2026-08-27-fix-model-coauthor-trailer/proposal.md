## Why

`git-commit-writer` currently pairs every AI model name with
`noreply@anthropic.com`, producing false provider attribution when another tool
creates the commit and conflating the executing tool with the assisting model.
Commit metadata should preserve both identities without inventing an email.

## What Changes

- Format attribution as `Co-Authored-By: <tool name> <verified email>` followed
  by `AI-Assisted-By: <assisting model>`.
- Add an allowlist for officially verified tool/email mappings, initially Codex
  and Claude Code; omit the email for an unmapped tool instead of guessing.
- Pass the executing tool and primary assisting model explicitly from
  `openspec-commit` so a commit-only sub-agent does not claim implementation
  work.
- Synchronize the canonical templates, installed provider copies, and reader
  documentation.
- Add focused contract coverage for both trailers, mapping, and handoff rules.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `git-commit-writer`: Separate tool co-author attribution from assisting-model
  metadata and use only verified email mappings.
- `openspec-commit`: Pass explicit tool and assisting-model identity to the
  delegated commit writer.

## Impact

The change affects the canonical `openspec-commit` and `git-commit-writer`
skills, the Claude commit agent, their installer-generated copies, related
playbooks and `AGENTS.md`, and the existing shell contract test. It adds no
dependencies and does not change staging, OpenSpec context resolution, or hook
retry behavior.
