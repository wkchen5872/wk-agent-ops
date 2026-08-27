## Context

See `proposal.md` for motivation. The repository has provider-specific
OpenSpec entrypoints but a shared portable commit writer. The Claude completion
path also delegates commit writing to a lightweight sub-agent, so self-reporting
inside the writer can identify the wrong model. Installed copies are generated
from `template/common/` by `scripts/skills/install.sh`.

## Goals / Non-Goals

**Goals:**

- Record the executing tool separately from the primary assisting model.
- Use GitHub-recognizable co-author email mappings only when officially
  verified.
- Preserve attribution across Claude Code, Codex, and Antigravity without
  guessing identities.
- Leave one focused, replayable contract check for handoff, formatting,
  mappings, and template propagation.

**Non-Goals:**

- Mapping every AI product or GitHub bot account in the first version.
- Tracking every model involved in a multi-agent session.
- Changing commit staging, message inference, or archive retry behavior.

## Decisions

### Separate tool attribution from model metadata

End commit messages with:

```text
Co-Authored-By: <tool name> <verified email, when known>
AI-Assisted-By: <primary assisting model>
```

`Co-Authored-By` identifies the stable executing tool, while
`AI-Assisted-By` records the replaceable model. A single model-only co-author
trailer was rejected because it conflates GitHub account attribution with model
metadata. A single `AI-Model` trailer was rejected because it loses the
platform-supported co-author identity when a verified mapping exists.

### Use the executing agent tool, not an outer host surface

Canonical names describe the agent that performed the work: use `Codex` when a
Codex agent runs inside ChatGPT, and `Claude Code` when Claude Code runs from
Claude Desktop. Use `ChatGPT` or `Claude Desktop` only when that surface itself
performs the work without delegating to those agents.

### Keep a strict verified mapping allowlist

The initial mapping is deliberately small:

| Tool | Verified email |
|---|---|
| Codex | `noreply@openai.com` |
| Claude Code | `noreply@anthropic.com` |

For Antigravity, Gemini CLI, GitHub Copilot, ChatGPT, Claude Desktop, or any
other unmapped tool, emit `Co-Authored-By: <tool name>` without an email. Do not
derive addresses from vendor domains, model families, or community examples.
New mappings require an official source plus a contract-test update.

### Pass attribution explicitly through orchestration

Extend the `openspec-commit` to `git-commit-writer` handoff with:

```text
tool_name=<executing agent tool>
assisting_model=<primary implementation model>
```

The coordinator already selects a provider-specific entrypoint, so it owns the
tool identity. It also retains the primary session model and must pass that
model to the Claude commit-only sub-agent. The writer must not replace it with
its own model. A standalone writer may use exact runtime-provided identities;
if either value is unavailable, it stops and requests the missing attribution
instead of guessing.

### Preserve template-first propagation

Edit the canonical `openspec-commit` and `git-commit-writer` skills plus the
Claude commit agent under `template/common/`, then run the existing installer
to refresh `.claude/` and `.agents/`. Update `AGENTS.md` and the two related
playbooks so their examples match the executable instructions.

### Extend the existing shell contract test

Add the smallest assertions to `tests/test_openspec_commit.sh` for the explicit
handoff, the two ordered trailers, both verified mappings, the unmapped-tool
rule, and the prohibition on substituting the commit-only agent model. Run the
focused test before implementation for Expected Red, then rerun after template
and installer changes for Green.

## Risks / Trade-offs

- **An unmapped tool has no GitHub account attribution** → Keep its name-only
  trailer and model metadata; never invent an email.
- **The primary model identity may be unavailable in a standalone invocation**
  → Stop and request explicit values instead of recording false provenance.
- **Multiple implementation models are reduced to one primary model** → Keep
  v1 single-valued; add repeated `AI-Assisted-By` trailers only when a concrete
  multi-model provenance requirement exists.
- **Generated targets can drift from templates** → Run the existing installer
  and verify relevant copies match canonical sources.
