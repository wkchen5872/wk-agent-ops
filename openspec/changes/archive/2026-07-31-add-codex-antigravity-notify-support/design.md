## Context

See `proposal.md` for motivation. The existing notification system already has
one deployed Telegram hook and a shared jq-based registry. Provider event names
and JSON contracts differ: Codex uses Claude-shaped hook groups but has its own
configuration layer, while Antigravity uses named hook definitions and a single
custom status-line command.

The native control contract is part of correctness. Codex notification hooks
must not return an approval or continuation decision. Antigravity `Stop` requires
a decision and treats only `continue` as a request to re-enter its loop.

## Goals / Non-Goals

**Goals:**

- Reuse the deployed Telegram hook and existing registry instead of adding a
  second notification pipeline.
- Preserve native CLI approval and stopping behavior under success, disabled
  notification, timeout, and malformed-payload paths.
- Make all configuration changes idempotent and ownership-scoped.
- Keep registry and payload behavior replayable with isolated Bash tests.

**Non-Goals:**

- A generic host-provider event bus or plugin framework.
- Automatic approval, denial, or permission-policy changes.
- Terminal scraping, transcript parsing, or forwarding raw commands/errors.
- Composing an arbitrary existing Antigravity status-line command.
- Adding a second message destination.

## Decisions

### D1: Extend the existing hook and registry

Add provider-specific event branches and registry functions to the existing
files. Each native event still flows directly into the deployed Telegram hook.

Alternative: introduce adapters and a canonical event dispatcher. Rejected
because one transport and a handful of event mappings do not justify another
runtime layer.

### D2: Use each CLI's global native configuration

- Codex: `~/.codex/hooks.json`, with `Stop` and `PermissionRequest` command
  groups using a short timeout.
- Antigravity: `~/.gemini/config/hooks.json`, with one owned named definition
  whose `Stop` list contains the notification command.
- Antigravity approval observer:
  `~/.gemini/antigravity-cli/settings.json` `statusLine`, registered only after
  explicit opt-in.

Automatic completion registration is conditional on detecting the corresponding
CLI command or configuration directory. Explicit provider functions remain
available to update and test individual integrations.

Alternative: write project-local hook files. Rejected because notification is a
per-user Telegram integration, project-local Codex hooks require trust per
project, and downstream projects should not receive machine credentials or
absolute deployed-hook paths.

### D3: Return provider-safe stdout

The hook reads stdin before credential guards so every early exit can still
return the native control response:

- Codex `Stop` and `PermissionRequest`: `{}` outside dry-run.
- Antigravity `Stop`: `{"decision":"stop"}` outside dry-run.
- Antigravity status observer: a compact `agent_state` string.

Dry-run continues to print the Telegram message for assertions and never calls
the network. No branch returns allow, deny, block, continue, or raw payload data.

### D4: Observe Antigravity approval state without changing policy

The status observer uses the documented `tool_confirmation_pending` field. A
state file under `~/.config/ai-notify/state/` is keyed by a sanitized
conversation ID:

- false removes the pending marker;
- the first true creates it and notifies;
- repeated true is silent.

If another `statusLine.command` exists, registration stops without modifying it.
This is safer than chaining an unknown command or using `PreToolUse` to predict
which permission policy will ask.

### D5: Minimize and sanitize message content

Codex approval messages identify only `tool_name`; nested command and argument
data are ignored. Antigravity abnormal termination reports the normalized
termination reason but not its raw error. Project and session values use the
documented cwd/workspace and conversation fields with existing fallbacks.

Telegram curl is bounded below the native hook timeout and remains silent-fail.

### D6: Keep lifecycle operations ownership-scoped

Registration merges only owned commands. Unregistration removes entries whose
command begins with the exact deployed-hook invocation, deletes an empty owned
Antigravity definition, and removes the status line only when its command is the
owned command. Invalid existing JSON causes an error rather than replacement.

The existing Copilot registry is corrected to add and remove its already
specified `userPromptSubmitted` command alongside `sessionEnd`.

### D7: Test-first boundaries

Extend the existing dry-run harness before production changes:

1. Red: Codex and Antigravity event fixtures fail because mappings and control
   responses are missing.
2. Green: add the minimum hook branches.
3. Red: isolated registry fixtures fail because native configs are absent and
   Copilot action registration is incomplete.
4. Green: add provider registry and lifecycle integration.
5. Run the focused notify harness after each task, then the repository-required
   shell tests and strict OpenSpec validation.

## Risks / Trade-offs

- [Antigravity exposes only one custom status-line command] → Make approval
  observation opt-in and refuse to overwrite a different command.
- [A status observer changes the default TUI status rendering] → Emit a compact
  current agent-state value and document how to disable the observer.
- [Native hook schemas can change across CLI releases] → Keep JSON fixtures
  isolated, cite official configuration in user docs, and avoid undocumented
  fields.
- [Synchronous hooks can delay the CLI] → Use a short native timeout and a
  shorter curl timeout; always return the neutral response on failure.
- [State markers can remain after an interrupted CLI] → A false transition
  clears them; per-conversation filenames prevent cross-session suppression.

## Migration Plan

1. Re-run install or `update.sh fix-hooks` to deploy the current hook and merge
   detected Codex/Antigravity completion registrations.
2. Opt in separately to Antigravity approval notifications if no custom status
   line is configured.
3. Review, trust, and enable the new Codex command hooks through `/hooks`.
4. Roll back with uninstall; it removes only owned commands and state while
   retaining unrelated provider settings.
