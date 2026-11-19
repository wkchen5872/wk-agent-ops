# Provider Extension Guide — scripts/notify/

This directory contains the shared infrastructure for notification destinations.
Telegram is a destination provider; Claude Code, Codex, Antigravity CLI, Pi, and
Copilot CLI are host runtimes registered by `lib/registry.sh`.

---

## Adding a New Provider

To add a new notification provider (e.g., Line Notify, Slack), follow these steps:

### 1. Copy the directory structure

```
scripts/
  notify/
    <provider-name>/
      hook.sh       # The notification hook called by AI CLI
      install.sh    # Interactive install wizard
      update.sh     # Update individual config keys
      uninstall.sh  # Remove hook and config entries
```

Use `scripts/notify/telegram/` as your reference implementation.

### 2. Implement `hook.sh`

The hook script is called by AI CLI with the event type as `$1` and a JSON payload on stdin.

**Required interface:**

```bash
#!/usr/bin/env bash
# $1 = normalized or native provider event type
# stdin = JSON payload from AI CLI

# 1. Source shared config
source ~/.config/ai-notify/config 2>/dev/null || true

# 2. Read ENABLED flag (e.g., LINE_ENABLED)
[[ "${LINE_ENABLED}" != "true" ]] && exit 0

# 3. Read event type from $1 (with jq fallback for stdin)
# 4. Apply the explicit category switch, using NOTIFY_LEVEL as legacy fallback
# 5. Call your provider API silently (curl --silent --max-time 4 ... || true)
```

**Exit rules:**
- Always exit 0 (silent failure — never block AI CLI)
- Return the native host's required neutral stdout contract
- Never return an approval or continuation decision from a notification hook
- No other stdout/stderr unless debugging

### 3. Config key naming convention

All provider keys in `~/.config/ai-notify/config` must follow:

| Key | Description |
|-----|-------------|
| `{PROVIDER}_ENABLED` | `true` / `false` master switch |
| `{PROVIDER}_<CREDENTIAL>` | Provider-specific credential (e.g., `TELEGRAM_BOT_TOKEN`) |
| `NOTIFY_LEVEL` | Shared: `all` (default) or `attention_required`; defaults completion only |

Examples:
- `TELEGRAM_ENABLED=true`
- `TELEGRAM_BOT_TOKEN="..."`
- `LINE_ENABLED=false`
- `LINE_NOTIFY_TOKEN="..."`

`NOTIFY_LEVEL` supplies only the default for completion when `NOTIFY_COMPLETION` is absent (`attention_required`, legacy `notify_only`, turns it off).

Four boolean category keys are supported: `NOTIFY_COMPLETION`, `NOTIFY_AUTHORIZATION`, `NOTIFY_USER_INPUT`, `NOTIFY_FAILURE`; the last three default on. Handoff loop progress has three more, `NOTIFY_HANDOFF_IMPLEMENT`, `NOTIFY_HANDOFF_REVIEW`, `NOTIFY_HANDOFF_FINISH` (default on); its attention notices are always sent. Legacy `NOTIFY_ACTION_REQUIRED`, `NOTIFY_CODEX_HUMAN_APPROVAL`, `NOTIFY_CODEX_USER_INPUT` are still read (environment new → environment legacy → file new → file legacy → default; only exact `true`/`false`), and the category menu replaces them on save. `NOTIFY_AUTHORIZATION_DELAY_SECONDS` (default 30) and `NOTIFY_AUTHORIZATION_REARM_SECONDS` (default 600) tune delayed authorization notices; `NOTIFY_DELIVERY_LOG=true` appends Telegram delivery responses to `state/deliveries.log` (capped at 500 lines); credentials reach curl on stdin (`--config -`) keeping them off `ps`. See [Telegram setup](../../docs/notify/telegram.md).

Messages render from `telegram/events.tsv` and `telegram/templates/` through `lib/template.sh`; users override a template with `~/.config/ai-notify/templates/<name>.md`. Placeholders: `{title_suffix} {tool} {model_suffix} {model_family_suffix} {project} {time} {tag} {message} {reason} {request_tool} {delay}`, plus `{agent} {change} {round} {verdict} {commit} {next} {detail}` for the four `handoff-*` templates.

Use `bash scripts/notify/telegram/update.sh types` for grouped Traditional Chinese settings, and `status` for support/connection diagnostics. Codex inspection is hook-triggered and turn-scoped, with no LaunchAgent. It never launches/resumes Codex or reads full transcripts. Confirmed approval and synchronous-input inspection use the local daemon; without it, authorization falls back to the session record. Async questions notify from a successful `request_user_input_async` PostToolUse result without daemon access; plain-text questions are unsupported.

### 4. Use shared libraries

Source these helpers in your scripts:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/config.sh"   # read_config, write_config, update_config_key
source "${LIB_DIR}/registry.sh" # register_hook, unregister_hook
```

### 5. Deploy path

`install.sh` must copy `hook.sh` to:
```
~/.config/ai-notify/hooks/<provider-name>.sh
```

And call `register_hook` with that deployed path:
```bash
register_hook "${HOME}/.config/ai-notify/hooks/<provider-name>.sh"
```

`register_hook` covers Claude Code plus detected Codex and Antigravity hooks.
For Antigravity it also attempts approval observation automatically, but never
overwrites a different custom `statusLine.command`. Notification-owned legacy
Gemini entries are removed when found; no new Gemini hooks are registered.
Copilot remains repository-local and opt-in. When Pi is detected (`pi` on PATH or
`${PI_CODING_AGENT_DIR:-~/.pi/agent}` exists), it also copies `pi/ai-notify.ts` into Pi's global
extension directory; that file starts with an ownership marker and is the only Pi file registry
functions overwrite or remove (see [Pi Extension Integration](../../docs/hooks/pi-hooks.md)).

Codex registration only writes `~/.codex/hooks.json`. Users must also open
`/hooks`, trust all four owned definitions, and enable their checkboxes before the
commands run. Registry status cannot verify those Codex-managed runtime states.

Each owned Codex handler gets a default `statusMessage` (its `/hooks` name; see
[Telegram setup](../../docs/notify/telegram.md#codex-requires-configuration-trust-and-enablement)).
Ordinary registration only fills missing or blank names and keeps custom ones;
`update.sh fix-hooks` recreates the handlers and resets them to the defaults.
After either, open a new Codex session and trust and enable the changed hooks
in `/hooks`.

Host event mappings belong in the existing deployed hook and registry. Do not
create a second destination directory merely to support another CLI.

---

## Directory Layout Reference

```
~/.config/ai-notify/
  config                      # Shell-sourceable key=value (chmod 600)
  hooks/
    telegram-notify.sh        # Deployed from scripts/notify/telegram/hook.sh
    codex-wait.py             # Optional on-demand daemon inspector
    events.tsv                # Deployed event table
    templates/                # Built-in templates (replaced on update)
  templates/                  # Optional user overrides (never touched)
  lib/config.sh              # Shared category logic
  lib/template.sh            # Template rendering
  lib/authorization.sh       # Delayed authorization logic
  runtime/codex-wait/         # Isolated dependency when inspection is enabled
  state/codex-*              # Owned locks, sanitized requests and diagnostics
  state/{claude,antigravity}-*.pending[.lock]  # Authorization wait markers
    <provider-name>.sh        # Your provider's deployed hook
```

---

## Testing Your Hook

```bash
# Test Stop event
echo '{"hook_event_name":"Stop"}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/<provider-name>.sh stop

# Test Notification event
echo '{"hook_event_name":"Notification","message":"Please approve this action"}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash ~/.config/ai-notify/hooks/<provider-name>.sh notification
```

Run both suites before delivery:

```bash
bash scripts/notify/telegram/test.sh
python3 -m unittest discover -s scripts/notify/tests -v
```

The `PI-EXT-*` tests load `pi/ai-notify.ts` with Node and need TypeScript type stripping (Node 22.18+ or
23.6+). On an older Node they are reported as `Skipped: ... NOT RUN`, never as passing.
