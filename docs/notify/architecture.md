---
type: Architecture
title: AI CLI Notification Hooks Architecture
description: Native host hook registration and Telegram notification data flow.
tags: [notifications, hooks, codex, antigravity, telegram]
generated: { by: claude-code/claude-sonnet-5-5, at: 2026-11-18T14:17:55+08:00 }
---

# Notify Hooks — Architecture

This document describes the architecture of the AI CLI notification hook system.

---

## Overview

The notification system allows Claude Code, Codex, Antigravity CLI, and Copilot
CLI to send Telegram notifications when an agent turn finishes, requires user
attention, or stops abnormally.

**Design principle:** The repository contains only scripts. All machine state (config files, deployed hooks, settings.json entries) is created exclusively by running the install/update entrypoints — never at repository checkout time.

---

## Directory Structure

```
scripts/
  notify/
    lib/
      config.sh        # Shared: read/write ~/.config/ai-notify/config
      registry.sh      # Shared: register/unregister hooks in AI CLI settings
      settings.sh      # Grouped, draft-only category editor
      runtime.sh       # Explicit helper/venv deployment and support status
      template.sh      # Placeholder rendering, event table lookup, user overrides
      authorization.sh # Delayed authorization wait markers, checks, state pruning
    codex/
      wait.py          # Hook-triggered daemon metadata checker
      requirements.txt # Optional isolated dependency
    telegram/
      hook.sh          # Notification hook (called by AI CLI at runtime)
      events.tsv       # Event table: key, category, template, reason label
      templates/       # Built-in message templates (*.md)
      install.sh       # Interactive install wizard
      update.sh        # Update individual config keys
      uninstall.sh     # Remove hooks and config
    line/
      .placeholder     # Reserved for future Line Notify implementation
    README.md          # Provider extension guide

.claude/
  commands/
    notify-setup.md    # /notify-setup Claude Code command
```

**Runtime layout (created by install.sh):**

```
~/.config/ai-notify/
  config               # Shell-sourceable key=value (chmod 600)
  hooks/
    telegram-notify.sh # Deployed copy of scripts/notify/telegram/hook.sh
    codex-wait.py      # On-demand checker
    events.tsv         # Deployed event table
    templates/         # Built-in templates, replaced on every update
  templates/           # Optional user overrides <name>.md (never touched by scripts)
  lib/config.sh        # Shared category logic for deployed hooks
  lib/template.sh      # Template rendering
  lib/authorization.sh # Delayed authorization logic
  runtime/codex-wait/ # Optional Python venv, only for enabled new categories
  state/codex-*       # Scoped lock, sanitized trigger mailbox and diagnostics
  state/claude-<session>.pending[.lock/]       # Delayed authorization wait marker + owner PID
  state/antigravity-<session>.pending[.lock/]

# Copilot CLI hooks (opt-in, created by install.sh if user accepts):
.github/
  hooks/
    hooks.json         # Copilot CLI hook config (version:1)

# Native user-level host configuration:
~/.codex/hooks.json                         # Codex Stop + PermissionRequest + question Pre/PostToolUse
~/.gemini/config/hooks.json                 # Antigravity named Stop hook
~/.gemini/antigravity-cli/settings.json     # Approval observer when statusLine is free
```

`~/.gemini/settings.json` is cleanup-only: setup, repair, and uninstall remove
notification-owned legacy Gemini commands but never register new ones.

---

## Config Format

`~/.config/ai-notify/config` is a shell-sourceable key=value file:

```bash
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN="7123456789:ABCdef..."
TELEGRAM_CHAT_ID="987654321"
NOTIFY_LEVEL=all           # default for completion only: all | attention_required
NOTIFY_COMPLETION=true
NOTIFY_AUTHORIZATION=true
NOTIFY_USER_INPUT=true
NOTIFY_FAILURE=true
NOTIFY_AUTHORIZATION_DELAY_SECONDS=30   # optional; 0 = immediate
NOTIFY_AUTHORIZATION_REARM_SECONDS=600  # optional
# LINE_ENABLED=false       # Future extension
```

**Security:** The file is created with `chmod 600` and never committed to the repository.

**Category resolution.** Four categories, one switch each: completion, authorization, user input, failure. Order: environment new key → environment legacy keys → config-file new key → config-file legacy keys → default. Only exact `true`/`false` count. Legacy keys `NOTIFY_ACTION_REQUIRED`, `NOTIFY_CODEX_HUMAN_APPROVAL`, `NOTIFY_CODEX_USER_INPUT` are still read: authorization from ACTION_REQUIRED + CODEX_HUMAN_APPROVAL, user input from ACTION_REQUIRED + CODEX_USER_INPUT; within one source any `true` wins, otherwise any `false`, otherwise undefined. Defaults: completion follows `NOTIFY_LEVEL`; the other three are on.

**NOTIFY_LEVEL values:**
| Value | Behaviour |
|-------|-----------|
| `all` (default) | Completion on by default |
| `attention_required` | Completion off by default |

The legacy `notify_only` value is read as `attention_required`. Saving the category menu writes the four new keys and removes the three legacy keys in one atomic write; changing the level writes only `NOTIFY_LEVEL` and `NOTIFY_COMPLETION`.

---

## Installation Flow

```
User runs: bash scripts/notify/telegram/install.sh
          (or: /notify-setup → setup in Claude Code)

Step 1  Guide user to create Telegram Bot via @BotFather
Step 2  Read and validate Bot Token (Telegram API call)
Step 3  Auto-detect Chat ID (getUpdates API call)
Step 4  Edit grouped category switches and confirm summary
Step 5  Write ~/.config/ai-notify/config (chmod 600)
Step 6  Deploy hook + common config library + checker; provision isolated dependency only if selected
Step 7  Register Claude plus detected Codex and Antigravity hooks; attempt approval observation safely
Step 8  Optionally register Copilot CLI hooks in .github/hooks/hooks.json [y/N]
Step 9  Send test notification to confirm end-to-end
```

**Idempotent:** Running `install.sh` multiple times is safe. Existing config values are preserved unless overwritten, and `registry.sh` prevents duplicate hook entries.

---

## Hook Lifecycle

```
AI CLI event fires (e.g., task complete)
        │
        ▼
Native AI CLI hook or Antigravity status state
        │
        ▼
bash ~/.config/ai-notify/hooks/telegram-notify.sh <event-type> [tool-name]
  (stdin: JSON payload from AI CLI)
        │
        ├─ source ~/.config/ai-notify/config
        ├─ TOOL_NAME = $2 arg (set by registry.sh) or "AI CLI"
        ├─ PROJECT_DIR from payload cwd/workspace, CLAUDE_PROJECT_DIR, or PWD
        ├─ SESSION_LABEL from session/conversation payload or Copilot env
        ├─ update Antigravity approval state and parse terminal reason
        ├─ for Codex permission/sync-question hooks: independently start opt-in inspection
        ├─ for Codex async-question results: validate accepted=true without daemon inspection
        ├─ classify via events.tsv: completion / authorization / user_input / failure
        ├─ apply the category switch (NOTIFY_LEVEL only defaults completion)
        ├─ authorization: record a wait and let a detached check decide after the delay
        ├─ check TELEGRAM_ENABLED and credentials (skipped in dry-run)
        ├─ return the provider-neutral control response
        ├─ render template (user override → built-in); escape values for Markdown
        └─ curl --silent --max-time 4 Telegram API || true
           (always exits 0; curl is bounded to four seconds)
```

---

## Data Formats

AI CLI 工具透過 `stdin` 將 JSON payload 傳遞給 Hook 腳本。

### Standard JSON Payload (Incoming)

```json
{
  "hook_event_name": "Stop",     // 事件類型：Stop | Notification | sessionEnd | ...
  "message": "...",              // (選填) 通知詳細訊息，如等待授權的內容
  "cwd": "/path/to/proj"         // (選填) 專案路徑
}
```

*   **Claude Code**: 傳送 `Stop` 與 `Notification` 事件；`permission_prompt` → 授權（延遲），`idle_prompt`、`agent_needs_input`、`elicitation_dialog`、`elicitation_url_dialog` 與無類型 → 等待回應（立即），其他類型不送。
*   **Codex**: 傳送 `Stop` 與 `PermissionRequest`；notification hook 回傳
    neutral `{}`，不代替使用者決定。
*   **Antigravity CLI**: `Stop` 提供 `fullyIdle` 與
    `terminationReason`（見下方 Antigravity 一節）；managed status line 提供
    `tool_confirmation_pending`。
*   **Copilot CLI**: 傳送 `sessionEnd` 與 `userPromptSubmitted` 事件。

---

## Shared Libraries

### `scripts/notify/lib/config.sh`

| Function | Description |
|----------|-------------|
| `normalize_notify_level VALUE` | Return `all` or `attention_required`, including the legacy alias |
| `read_config` | Source the config file into current shell |
| `write_config KEY=VAL ...` | Create/overwrite config with given pairs (chmod 600) |
| `update_config_key KEY VAL` | Atomically update one key; preserve other lines |
| `update_config_keys KEY VAL ...` | Atomically apply a whole draft, preserving other keys |
| `notify_category_value KEY` | Resolve a category through the new/legacy key order and default |
| `remove_config_keys_by_prefix PREFIX` | Remove all keys matching a prefix |

### `scripts/notify/lib/registry.sh`

| Function | Description |
|----------|-------------|
| `register_hook <hook_path>` | Register Claude plus detected Codex and Antigravity hooks; clean owned legacy Gemini entries |
| `unregister_hook <hook_path>` | Remove owned global hook entries without affecting other hooks |
| `register_hook_copilot <hook_path>` | Write `sessionEnd` + `userPromptSubmitted` entries to `.github/hooks/hooks.json` (idempotent) |
| `unregister_hook_copilot <hook_path>` | Remove Copilot hook entries from `.github/hooks/hooks.json` |
| `register_hook_codex <hook_path>` | Add neutral `Stop`, `PermissionRequest`, question `PreToolUse` / `PostToolUse` hooks |
| `register_hook_antigravity <hook_path>` | Add the named global Antigravity `Stop` hook |
| `register_hook_antigravity_statusline <hook_path>` | Add approval-state observation without overwriting another command |
| `show_hook_status <hook_path>` | Report provider registration without reading credentials |

All functions require `jq`.

---

## Codex Integration

Codex hooks live in `~/.codex/hooks.json`. The installer adds `Stop` for
completion and `PermissionRequest` for approval notifications. Both invoke the
deployed hook with a five-second native timeout. The hook returns `{}` and never
returns `allow`, `deny`, `block`, or `continue`, so Codex retains its normal
approval and stopping behavior.

Non-managed Codex command hooks have three independent runtime states:

1. configured in `~/.codex/hooks.json`;
2. trusted in `/hooks`;
3. enabled with an `[x]` checkbox in `/hooks`.

All four owned definitions must be trusted and enabled. `Trust:
Trusted` does not override an unchecked `[ ] Hook 1`; that hook remains
disabled. `show_hook_status` reports only whether the owned commands exist in
configuration because Codex does not expose trust and enablement through the
registry file.

The authorization notice contains only a generic tool label. Raw commands,
arguments, prompts, descriptions, and transcript paths are not forwarded.

---

## Codex On-demand Inspection

PermissionRequest never sends at the moment it is raised, even with delay 0; it only starts the checker (when authorization or user input is on). See Delayed Authorization below. PreToolUse retains the `^(request_user_input|request_user_input_async)$` matcher for existing installations; the async tool returns neutrally without starting inspection, while synchronous questions start the checker.

Async questions are emitted as messages and do not raise waitingOnUserInput. A separate PostToolUse handler matches `^request_user_input_async$`, validates the native event/tool name and accepted=true result (JSON object or JSON string), then reuses the user-input category and sanitized renderer. Missing, malformed, rejected and disabled results remain silent. This means a question was posted, not that generation is blocked. No question text or raw tool output is persisted or forwarded, and no daemon is needed for this path.

The hook sends only session_id, turn_id and cwd to `codex-wait.py start`, then returns neutral JSON. An inherited advisory lock coalesces workers by CODEX_HOME/session. A sanitized trigger mailbox hands new-turn hooks to an existing worker without losing them during shutdown. Atomic state holds only turn/PID, wait flags and generic diagnostics. No raw tool input or transcript is retained.

The checker uses websocket-client over a socketpair connected to `codex app-server proxy`; the CLI resolves its own control socket. It never starts a daemon and never calls thread/resume. RPCs are limited to initialize, thread/read with includeTurns=false, and thread/turns/list with itemsView=notLoaded. Waiting flags are sampled at one-second intervals and validated against the triggering turn before notification. No flag means no human-wait message, even during automatic review.

Continuous waiting episodes are independently deduplicated for waitingOnApproval and waitingOnUserInput. Explicit absence re-arms notification; reconnect retains the last notified flags. A worker exits at turn completion/change without a new trigger, thread unload, disabled settings, or bounded transport recovery failure. There is no LaunchAgent. Notification delivery is attempted once per episode; a network timeout does not cause repeated attempts for that wait.

The runtime counts as unable to be queried when the daemon is unreachable or when it reports the triggering session as `notLoaded` on the first query. The latter is normal for a Codex session started from the terminal, which is never loaded in the daemon (live capture, 2026-11-18); `notLoaded` after the session was seen `active` still means the turn finished. In that case the checker keeps the request until the delay passes, then reads the Codex session record (payload `transcript_path`, else `$CODEX_HOME/sessions/*/*/*/rollout-*-<session_id>.jsonl`): a `*_call_output` for the open call or a `task_complete` / `turn_aborted` event means silence; otherwise, or when unreadable, it sends the unconfirmed notice. Each Codex inspection start prunes notification-owned state older than 7 days whose lock is free (`codex-<24 hex>.{lock,json,request.json}` together, and `claude-*.pending` / `antigravity-*.pending` whose lock directory has no live PID).

Status probes report metadata connectivity separately from live hook/delivery coverage. Confirmed approval and synchronous-input inspection require the existing local daemon; async question-posted notifications use native hooks. General prose questions are not inferred. See [setup and limitations](/docs/notify/telegram.md).

---

## Delayed Authorization

Authorization notices are sent only if the wait is still unresolved after `NOTIFY_AUTHORIZATION_DELAY_SECONDS` (default 30; 0 immediate; non-numeric or negative → 30), at most once per continuous wait.

| Host | Start signal | Wait identity / clearing |
|---|---|---|
| Claude Code | `Notification` with `permission_prompt` | Last `tool_use` in `transcript_path` without a `tool_result`; a matching `tool_result` before the delay means silence; unreadable record sends the unconfirmed notice; `Stop` clears |
| Antigravity | Status line `tool_confirmation_pending` true | None; false or `Stop` clears |
| Codex | `PermissionRequest` starts `codex-wait.py` | `waitingOnApproval` held beyond the delay (daemon), or session-record check (no daemon) |

Waits without an identifier are merged: repeated start signals never restart the delay or send a second notice, and an un-notified wait never ages out. A notified wait re-arms on a start signal at least `NOTIFY_AUTHORIZATION_REARM_SECONDS` after the notice (default 600; invalid → 600; whole-second clock, never early, at most one second late); resolution evidence re-arms at once. Known limitation: without a resolution signal, a second wait right after the first is merged into it. An approved Codex command still running past the delay also gets the unconfirmed notice (accepted).

Markers `claude-<session>.pending` and `antigravity-<session>.pending` each have a lock directory `<marker>.lock` holding the owner PID. A detached background check per wait acts only if the marker still carries its own wait identity. Notices contain only tool, project, session label, time and a generic tool label.

---

## Message Templates

`telegram/events.tsv` maps an event key to category, template and reason label (`<prefix>:*` is the fallback; category `none` is never sent; absent events keep the generic "AI CLI Event" message). Built-in templates in `telegram/templates/` deploy to `~/.config/ai-notify/hooks/templates/` and are replaced on every update; `~/.config/ai-notify/templates/<name>.md` overrides one by name, and a missing, empty or unreadable file falls back to the built-in. Install, update, fix-hooks and uninstall never touch the override directory; uninstall removes only the built-in templates and the table.

Placeholders: `{title_suffix} {tool} {project} {time} {tag} {message} {reason} {request_tool} {delay}`. Values are escaped for Telegram legacy Markdown; a line made only of empty placeholders is removed; unknown placeholders stay as is. There is no eval, condition or loop.

---

## Antigravity CLI Integration

Antigravity completion hooks live in `~/.gemini/config/hooks.json` under the
owned `telegram-notify` definition. `Stop` emits a result only when
`fullyIdle=true`. `terminationReason` is compared case-insensitively: `NO_TOOL_CALL` and legacy `model_stop` are Task Complete, `USER_CANCELED` is silent, everything else is Task Stopped with a reason label from `events.tsv` (e.g. `ERROR` → "error", `MAX_TOKEN_BUDGET_EXCEEDED` → "token budget exceeded", unknown → "execution stopped"). Raw error text is never included. The hook returns `{"decision":"stop"}`, which permits the documented
stop instead of re-entering the execution loop.

Antigravity approval observation uses
`~/.gemini/antigravity-cli/settings.json`. Setup and `fix-hooks` attempt it
automatically whenever Antigravity is detected:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" antigravity-statusline \"Antigravity CLI\""
  }
}
```

The observer starts a delayed authorization wait on `tool_confirmation_pending=true`. With no request identifier, a status line whose `tool_confirmation_pending` is no longer true (Antigravity 1.5.10 omits the field once the confirmation is answered; it never sends false), or the conversation's `Stop`, clears the wait, even when Telegram delivery is disabled. It prints a compact agent-state value so it
remains a valid status-line command. A different existing command is preserved
and reported as `Antigravity approval: unavailable (statusLine conflict)`.

---

## Copilot CLI Integration

Copilot CLI uses a repository-local hook file rather than global host settings.

### Hook file: `.github/hooks/hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      { "type": "command", "bash": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" sessionEnd \"Copilot CLI\"" }
    ],
    "userPromptSubmitted": [
      { "type": "command", "bash": "bash \"/Users/<user>/.config/ai-notify/hooks/telegram-notify.sh\" userPromptSubmitted \"Copilot CLI\"" }
    ]
  }
}
```

### Event mapping

| Copilot CLI event | Mapped to | Message type |
|-------------------|-----------|-------------|
| `sessionEnd` | `stop` (task complete) | 🟢 Task Complete |
| `userPromptSubmitted` | `notification` (action required) | 🟡 Action Required |

### Tool name in hook.sh

`hook.sh` receives the tool name as `$2` CLI argument, hardcoded by `registry.sh` at registration time:

| Caller | `$1` (event) | `$2` (tool name) |
|--------|-------------|-----------------|
| Claude Code | `stop` / `notification` | `"Claude Code"` |
| Codex | `codex-stop` / `codex-permission` | `"Codex"` |
| Antigravity CLI | `antigravity-stop` / `antigravity-statusline` | `"Antigravity CLI"` |
| Copilot CLI | `sessionEnd` / `userPromptSubmitted` | `"Copilot CLI"` |

When `$2` is absent (old-format registered hooks), `TOOL_NAME` defaults to `"AI CLI"`. Run `fix-hooks` to upgrade:

```bash
bash scripts/notify/telegram/update.sh fix-hooks
```

### Setup

Copilot hook registration is **opt-in** during `install.sh` (step 8). The resulting `.github/hooks/hooks.json` can be committed to the repository so all machines with the notify hook installed benefit automatically.

To register after install:
```bash
bash scripts/notify/telegram/update.sh copilot-hooks
```

---

## How to Add a New Provider

See the [provider extension guide](/scripts/notify/README.md) for the step-by-step provider extension workflow.

Summary:
1. Copy `scripts/notify/telegram/` to `scripts/notify/<provider-name>/`
2. Implement `hook.sh` with the standard interface
3. Use `{PROVIDER}_ENABLED` config key prefix
4. Deploy hook to `~/.config/ai-notify/hooks/<provider-name>.sh` from `install.sh`
5. Call `register_hook` / `unregister_hook` from shared library

---

## Rollback

```bash
# Full removal
bash scripts/notify/telegram/uninstall.sh

# Or in Claude Code
/notify-setup → uninstall
```

Uninstall removes owned Claude, Codex, and Antigravity hook entries, any
notification-owned legacy Gemini commands, Antigravity notification state,
`TELEGRAM_*` keys, the deployed hook, built-in templates and the event table (user templates stay). It cooperatively stops owned Codex checkers and removes their isolated runtime/state. It removes repository-local Copilot
entries only after separate confirmation. Unrelated hooks and settings remain
unchanged.

To migrate, rerun `update.sh` (or `fix-hooks`); hook registrations are unchanged, so Codex needs no re-trust and existing configs need no edits. Rollback redeploys the previous hook; legacy keys already removed by a menu save must be set again.

Before rolling back to a hook release that predates `attention_required`, set
the config value back to its legacy spelling, `notify_only`.

# Citations

[1] [OpenAI Codex Hooks](https://developers.openai.com/codex/hooks)
[2] [Google Antigravity Hooks](https://antigravity.google/docs/hooks)
[3] [Google Antigravity Status Line](https://antigravity.google/docs/cli/statusline)

[4] [OpenAI Codex App Server](https://learn.chatgpt.com/docs/app-server)
[5] [websocket-client custom sockets](https://websocket-client.readthedocs.io/en/latest/examples.html#connecting-with-custom-sockets)
