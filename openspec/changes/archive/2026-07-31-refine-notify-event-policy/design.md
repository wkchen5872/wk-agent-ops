## Context

See `proposal.md` for motivation and scope. The current hook filters raw event
names before provider-specific normalization. Consequently, legacy
`notify_only` does not suppress Gemini `AfterAgent`, while it suppresses every
Antigravity `Stop`, including `error` and `max_steps_exceeded`. Antigravity
approval observation is also presented as a second notification preference even
though both intended notification levels include action-required events.

The hook must preserve provider-native stdout contracts, bounded Telegram
delivery, privacy filtering, status-line output, and ownership-scoped JSON
updates. Antigravity still stores its CLI configuration below `~/.gemini/`; that
path alone is not evidence of legacy Gemini CLI support.

## Goals / Non-Goals

**Goals:**

- Make policy depend on normalized event meaning rather than provider event
  spelling.
- Preserve action-required and failure alerts in the reduced-noise mode.
- Remove active Gemini notification support without leaving owned legacy hooks.
- Make Antigravity approval observation a safely managed capability rather than
  an independent notification preference.
- Keep the implementation within the existing Bash hook and registry boundary.

**Non-Goals:**

- Remove Gemini support from workflow, worktree, or other non-notification
  modules.
- Support Gemini CLI Enterprise notification hooks.
- Add per-provider notification levels, a third level, or an arbitrary policy
  engine.
- Chain or overwrite an unknown Antigravity custom status-line command.
- Change native provider approval, stop, or permission decisions.

## Decisions

### D1: Classify first, filter second

The hook will assign one semantic category before applying the level:

| Category | Provider examples |
|---|---|
| `completion` | Claude `Stop`, Codex `Stop`, Copilot `sessionEnd`, Antigravity fully-idle `model_stop` |
| `action_required` | Claude `Notification`, Codex `PermissionRequest`, Copilot `userPromptSubmitted`, Antigravity pending confirmation |
| `failure` | Antigravity fully-idle `error`, `max_steps_exceeded`, or another abnormal terminal reason |

`fullyIdle=false` remains a non-notifying intermediate transition. Unknown events
retain generic handling only under `all`; they are not promoted to an
attention-required category.

The existing event case statement can set one category and reuse one small gate.
No strategy objects, dispatch framework, or new dependency is justified.

Alternative: extend the raw-event suppression list. Rejected because it already
missed `AfterAgent` and cannot distinguish successful and abnormal Antigravity
Stop payloads.

### D2: Use `all` and `attention_required`

The canonical policy matrix is:

| Level | completion | action_required | failure |
|---|---:|---:|---:|
| `all` | send | send | send |
| `attention_required` | suppress | send | send |

The hook accepts `notify_only` as a legacy alias for
`attention_required`. New setup and update input accept only canonical values;
when those flows rewrite config, they persist the canonical value.

Alternative: `action_required`. Rejected because it would imply failure events
are excluded. Alternative: rename `NOTIFY_LEVEL`. Rejected because changing the
key adds migration work without clarifying the values further.

### D3: Remove active Gemini support but retain bounded cleanup

Registration will no longer detect `gemini`, write `AfterAgent` or
`Notification` entries to `~/.gemini/settings.json`, report Gemini status, or
map `AfterAgent` in the hook. It will retain only the existing ownership-prefix
removal needed by setup, repair, and uninstall to clean commands deployed by
older versions.

The cleanup must operate only on commands beginning with the exact deployed-hook
prefix and preserve all unrelated Gemini settings. Other repository modules
that still support Gemini are outside this change.

Alternative: delete every Gemini-related branch immediately. Rejected because
existing installations would continue invoking an orphaned deployed command.

### D4: Automatically attempt Antigravity approval observation

Both levels include `action_required`, so install and update will no longer ask
whether approval notifications are wanted. Detection and repair will attempt to
register the owned status-line command when Antigravity is present.

A different existing `statusLine.command` remains authoritative. Registration
will not overwrite or chain it and status will report approval observation as
unavailable. The standalone `antigravity-approval` update option is removed;
`fix-hooks` provides the retry path after a conflict is cleared.

Notification level changes never install or uninstall provider integrations.
They affect only delivery after an event source is available.

Alternative: keep the approval preference. Rejected because it duplicates the
notification policy. Alternative: overwrite or chain status-line commands.
Rejected because Antigravity supports one custom command and an unknown command
cannot be composed safely.

### D5: Preserve state and native output before delivery exits

Antigravity status-line false transitions must clear pending markers even when
Telegram is disabled or credentials are missing. Every status-line invocation
returns its compact agent state, and every Codex or Antigravity native hook
returns its neutral control response regardless of policy suppression or
delivery failure.

This keeps event-source state and provider control behavior independent from
Telegram availability.

### D6: Use focused TDD around observable policy

Implementation starts with focused failures in
`scripts/notify/telegram/test.sh`:

1. `attention_required` suppresses each successful completion fixture.
2. The same level preserves Antigravity error and max-step failures.
3. `notify_only` matches the canonical policy.
4. Global registration creates no Gemini hooks and removes owned legacy entries.
5. Antigravity detection automatically attempts approval observation while
   preserving a conflicting command.
6. Disabled delivery still clears a false approval transition and returns native
   stdout.

Each Red records the command, failing test name, non-zero exit, expected reason,
and sanitized excerpt. Green changes remain minimal; after each policy or
registry task, run the focused cases and the full notification harness. Final
verification includes Bash syntax, repository shell tests, strict OpenSpec
validation, and the configured pre-commit gate.

## Risks / Trade-offs

- [Enterprise Gemini CLI users lose notification support] → Mark the removal as
  breaking and state the supported host matrix explicitly.
- [Legacy cleanup removes unrelated settings] → Match only the exact deployed
  hook command prefix and test preservation with mixed fixtures.
- [Automatic approval observation changes Antigravity status rendering] → Keep
  the compact agent-state output, preserve conflicts, and document status and
  removal behavior.
- [Old `notify_only` config becomes noisy] → Treat it as a runtime alias before
  any filtering and normalize it when setup or update writes config.
- [A failure is misclassified as completion] → Derive Antigravity category only
  after `fullyIdle` and `terminationReason` are parsed.
- [Rollback to an older hook sees `attention_required` as unknown] → Document
  resetting the value to `notify_only` before deploying an older release.

## Migration Plan

1. Deploy the new hook while accepting both canonical and legacy level values.
2. During install or `fix-hooks`, remove notification-owned legacy Gemini
   entries, register supported completion hooks, and safely attempt the
   Antigravity approval observer.
3. Persist `attention_required` when setup or update rewrites a legacy
   `notify_only` level.
4. Show provider status without Gemini and distinguish an installed
   Antigravity approval observer from a status-line conflict.
5. Update specs and notification documentation with the new support and policy
   matrices.
6. To roll back, set `NOTIFY_LEVEL=notify_only` before deploying the prior hook;
   rerun its registration flow only if legacy Gemini support is intentionally
   restored.
