## Context

See `proposal.md` for motivation. The current coordinator collects attribution
before any delegation, while provider-native agents independently define their
runtime model and effort. Both concepts currently use the word "model" without
an explicit boundary.

## Goals / Non-Goals

**Goals:**

- Ask for missing implementation attribution only when the commit step needs it.
- Keep `assisting_model` as the existing Git trailer field for compatibility.
- Prevent orchestration instructions from turning attribution into a spawn
  model or reasoning-effort override.

**Non-Goals:**

- Rename commit trailers or attribution fields.
- Change any configured Claude Code or Codex subagent model.
- Add runtime model discovery or provider-specific detection scripts.

## Decisions

### Move attribution resolution to the Step 5 boundary

Remove the opening workflow gate that requires both attribution values before
delegation. Step 5 will resolve the pair immediately before invoking the commit
writer. This allows archive and documentation work to proceed without asking a
question whose answer they do not consume.

Alternative considered: keep early collection for convenience. Rejected because
it creates an unnecessary blocking prompt and makes the value appear relevant
to earlier subagents.

### Keep the field name and define a strict semantic boundary

Retain `assisting_model` to avoid changing existing agent inputs and trailer
format. Add explicit instructions that it is task metadata for
`AI-Assisted-By`, not runtime configuration.

Alternative considered: rename the field to `implementation_model`. Rejected as
unnecessary churn because a direct definition and prohibition solve the observed
ambiguity.

### Spawn native agents by exact name without runtime overrides

Claude Code and Codex orchestration will specify the custom agent name and task
input only. It will explicitly prohibit supplying spawn `model` or
`reasoning_effort`, leaving those values to provider-native agent configuration.
Portable skill fallback remains unchanged.

### Test text contracts at both boundaries

Extend the existing shell contract test to verify that attribution resolution
appears after documentation handling, that `assisting_model` is metadata only,
and that native agent spawning forbids model and effort overrides. Also verify
the commit-writer skill and agent carry the same semantic boundary.

## Risks / Trade-offs

- [The exact implementation model remains unavailable at commit time] → Ask once
  at the commit boundary and stop before commit if it is still unknown.
- [A provider ignores prose routing instructions] → Keep exact agent names and
  focused contract assertions; runtime UI remains the operational evidence.

## Migration Plan

1. Add focused failing contract assertions.
2. Move attribution instructions to Step 5 and add the no-override boundary.
3. Mirror the metadata-only language into portable and provider-native commit
   writer instructions.
4. Re-run the installer, update workflow documentation, and execute all affected
   shell tests plus strict OpenSpec validation.

Rollback restores the previous instruction text; no stored data or agent config
migration is involved.
