## Context

`openspec-commit` is a project-owned workflow installed from
`template/common/skills/` into `.claude/skills/` and `.agents/skills/`. It
currently delegates archive and commit work, but duplicates documentation
logic between them. It also drops the exact archive path returned by the
archive action and relies on implicit staging that no current step performs.

OpenSpec 1.4.1 generates separate native integrations:

| Provider | OpenSpec skill | Native workflow alias |
|---|---|---|
| Claude Code | `.claude/skills/openspec-*/SKILL.md` | `.claude/commands/opsx/<action>.md` |
| Codex | `.codex/skills/openspec-*/SKILL.md` | none in the project |
| Antigravity | `.agent/skills/openspec-*/SKILL.md` | `.agent/workflows/opsx-<action>.md` |

These OpenSpec-generated files are upstream-owned. The wk-agent-ops installer
has a different boundary: it installs project-owned portable skills to
`.claude/skills/` and the plural shared root `.agents/skills/`. The refactor
must support all three providers without copying or editing their native
OpenSpec artifacts.

## Goals / Non-Goals

**Goals:**

- Make `openspec-commit` a thin, ordered coordinator over three existing
  capabilities.
- Preserve exact `change_id`, `archive_path`, sync status, and warnings across
  steps.
- Combine OpenSpec intent with the complete implementation diff when updating
  documentation.
- Make the workflow safe to retry after archive.
- Restore staging and retry behavior required by `git-commit-writer`.
- Keep provider-specific syntax at the invocation edge while using portable
  capability names inside the workflow.
- Add one focused, runnable contract test plus existing installer/spec checks.

**Non-Goals:**

- Modify OpenSpec-generated `.claude/`, `.codex/`, or `.agent/` provider files.
- Add a workflow engine, checkpoint file, provider adapter layer, or new
  dependency.
- Change `openspec-archive-change` behavior.
- Archive or commit this change as part of apply.

## Decisions

### 1. Coordinate capabilities, not filesystem paths

`openspec-commit` will invoke the semantic capabilities
`openspec-archive-change`, `doc-updater`, and `git-commit-writer`. It will not
execute both an `openspec-*` skill and its `opsx-*` alias, because those are two
entry points to the same action.

Provider-native paths are documented for discovery and troubleshooting only.
If a host cannot perform a nested skill call, it follows the named capability's
instructions in the current context. This keeps the workflow portable without
inventing a provider abstraction.

Alternative considered: hard-code `/opsx:archive` for Claude and
`/opsx-archive` for Antigravity. Rejected because Codex is skill-based and
command syntax is an entry-point concern, not workflow logic.

### 2. Use explicit hand-off fields

The archive step must yield and the coordinator must retain:

```text
change_id
archive_path
spec_sync_status
warnings
```

The exact `archive_path` is passed to both downstream capabilities.
`ls -t ... | head -1` and downstream archive rediscovery are removed from the
coordinated path.

Alternative considered: continue rediscovering from `git status`. Rejected
because it duplicates known state and becomes ambiguous when multiple archives
are dirty.

### 3. Use Git as the resume state

On entry, the coordinator first checks for uncommitted archived changes. If one
matches the requested change, or exactly one exists when no change was
specified, it resumes at documentation update. Multiple candidates require
selection. No separate checkpoint file is added.

Alternative considered: write a workflow state file. Rejected because the
archive move and Git status already encode the durable state.

### 4. Stage once for visibility, stage again for the final commit

After archive, the coordinator runs `git add -A` before `doc-updater`. This
makes new implementation files and the archive move visible through
`git diff HEAD`, which otherwise omits untracked files.

`git-commit-writer` remains responsible for the final `git add -A` immediately
before reading the cached diff and committing. It repeats staging after fixing
a pre-commit failure.

This assumes the documented isolated feature-worktree workflow and an explicit
user request to commit. It does not add a second interactive staging UI.

### 5. Give doc-updater both intent and evidence

`doc-updater` gains optional inputs `change_id` and `archive_path`. In Mode A it
reads:

- archived `proposal.md` and delta specs for intended scope;
- `git status --short` and `git diff HEAD` for actual changed files/content.

The OpenSpec context informs document selection but never overrides the actual
diff. Mode B remains available for standalone use and is clarified to leave
changes uncommitted.

### 6. Pass explicit context to git-commit-writer

When called by `openspec-commit`, `git-commit-writer` uses the supplied
`archive_path` and `change_id`, validates that the archive exists, stages all
changes, and derives the message from the archived proposal plus staged diff.
Standalone auto-detection remains a fallback only.

### 7. Verify the instruction contract mechanically

Because these skills are Markdown instructions rather than a runtime program,
the smallest useful automated check is a shell contract test. It will assert:

- the three capability calls appear in the required order;
- exact archive context is reused and `ls -t` rediscovery is absent;
- staging occurs before documentation analysis and in the commit writer;
- provider paths distinguish `.agents/` from OpenSpec-generated `.agent/` and
  `.codex/`;
- template and installed copies match after installation.

Existing OpenSpec validation and shell suites remain the broader regression
checks.

## Risks / Trade-offs

- **[Risk] Provider invocation mechanisms differ.** → Use capability names as
  the invariant and treat native commands/workflows as aliases, never a second
  action.
- **[Risk] `git add -A` can stage unrelated files.** → Keep the workflow scoped
  to its documented isolated feature worktree and explicit commit invocation.
- **[Risk] OpenSpec changes generated provider paths in a future release.** →
  Keep paths descriptive, do not edit generated files, and validate against the
  installed OpenSpec version when updating this workflow.
- **[Risk] Markdown contract tests cannot prove model behavior end to end.** →
  Test the enforceable orchestration invariants and retain pre-commit/OpenSpec
  verification for execution-time failures.

## Migration Plan

1. Add the failing orchestration contract test.
2. Update the three project-owned skills and the two Claude wrappers.
3. Run `scripts/skills/install.sh` to refresh `.claude/` and `.agents/`.
4. Update workflow documentation.
5. Run the focused test, existing shell tests, and OpenSpec validation.

Rollback is a normal Git revert of project-owned template/spec/doc changes.
OpenSpec-generated provider artifacts are unaffected.

## Open Questions

None. The user explicitly selected Claude Code, Codex, and Antigravity as the
three primary consumers and requested immediate implementation after planning.
