## Context

See `proposal.md` for motivation. Current instructions permit exact runtime
metadata but surround that permission with stricter uncertainty guards. Live
agents therefore ask repeatedly even when the unchanged root session already
provides the exact model identity. Static tests only assert text presence and
ordering, so they did not catch the weak `MAY use` behavior.

## Goals / Non-Goals

**Goals:**

- Make unchanged same-session attribution the mandatory first resolution path.
- Preserve fail-closed behavior for cross-session and genuinely ambiguous work.
- Keep provider-native subagent runtime models separate from Git attribution.
- Prevent pre-archive attribution prompts in `openspec-commit`.

**Non-Goals:**

- Persist attribution outside the conversation or provider session.
- Parse private logs, infer from Git history, or add a model cache.
- Change subagent model or reasoning-effort configuration.

## Decisions

### Define attribution as the root-session model

Use the exact model of the root agent session governing the work. Documentation
and commit-only subagents remain implementation details and never replace that
identity. This matches the trailer's purpose and avoids treating normal
provider delegation as multi-model ambiguity.

Alternative: attribute the model that physically edited each file. Rejected
because it makes a single commit ambiguous whenever routine subagents run.

### Replace permissive runtime wording with an ordered mandatory rule

Both workflows will say that an exact unchanged root-session identity MUST be
used automatically and MUST NOT trigger a prompt. Asking is the fallback only
for another session, a changed root model, or unavailable exact metadata.

Alternative: retain `MAY use` and add examples. Rejected because the live
behavior demonstrates that permissive wording loses to fail-closed clauses.

### Reuse session context without persistent state

Later commits resolve from the same current runtime identity. No attribution
cache or session-log parser is needed; a model switch naturally invalidates the
automatic path.

### Test the decision contract before editing production prompts

Extend the focused shell contract test first so it fails unless both workflows
contain mandatory automatic-use and no-repeat-prompt language, subagents are
explicitly non-ambiguous, and `openspec-commit` prohibits early attribution
requests. Then make the smallest prompt edits and propagate through the
installer.

## Risks / Trade-offs

- [Provider exposes only a family label] → Keep the existing exact-value prompt.
- [Work is handed to a new session] → Require user-supplied attribution rather
  than silently using the finisher's model.
- [Prompt contracts cannot fully simulate provider behavior] → Retain focused
  static tests and report that live provider acceptance remains separate.
