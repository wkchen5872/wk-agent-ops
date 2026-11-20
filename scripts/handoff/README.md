# Agent handoff loop

Implementation, review, and finish agents hand work to each other without you relaying
messages. Each agent ends its round by writing a handoff record with the `agent-handoff`
skill; when the agent stops, a Stop hook reads that record and messages the next agent
through its session host — Xirp or herdr — or notifies you through the existing Telegram notifier.

Scope: one person's machine. Handoff records and the hook exist only locally, so the loop never
spans people: it commits locally and does not push, open a PR, or post reviews by default. Work
that another person implements or reviews goes through the GitHub PR instead (`github-pr`,
`change-review`), which is where the team boundary is. See
[本機開發四階段流程](../../docs/workflow/local-development.md) for how the two fit together.

Requirements: `git`, `jq`, and the CLI of each [session host](#session-hosts) in use for opening
and messaging sessions — `xirp` (the default) or `herdr`; the `pi` CLI only for Pi roles. When a
record's host is not installed, the hook does nothing for it and the manual workflow is unchanged.
Run [`handoff-doctor`](#handoff-doctor-change-id) to check a machine.
Supported agents: Claude Code, Codex, and Pi (see [Pi roles](#pi-roles)).

## Install

```bash
bash scripts/handoff/install.sh                              # once per machine
bash scripts/skills/install.sh --target /path/to/repo        # once per repository
```

The first command installs `handoff-start`, `handoff-finish`, `handoff-cleanup` and `handoff-role` in `~/.local/bin`, installs
`handoff-route` in `~/.config/wk-workflow/handoff/`, and registers it as a Stop hook for
Claude Code (`~/.claude/settings.json`) and Codex (`~/.codex/hooks.json`). Then open a new
Codex session and, in `/hooks`, find the Stop hook named `Agent 交接派送`, trust it and make
sure it is enabled. Hooks load when a session starts, so sessions opened earlier do not route.

It also installs the Pi trigger `~/.pi/agent/extensions/wk-handoff.ts` and its trust check
`~/.config/wk-workflow/handoff/handoff-pi-trust`; rerunning replaces the same file, so there is
one copy. Pi loads global extensions at start: run `/reload` (or restart) in Pi sessions opened
earlier. Before a loop uses a Pi role, run `/trust` once in Pi in the repository's main worktree.

The Codex name is the handler's `statusMessage`. Rerunning the installer fills it on an
existing handoff hook whose name is missing or blank and keeps a custom name; other hooks and
fields are untouched. Adding the name changes the hook definition, so Codex asks you to review
and trust it again in a new session. The installer never changes Codex trust or enable state.

The first command also creates `~/.codex/handoff-net.config.toml` when it is missing: a Codex
profile with the workspace-write sandbox plus network access, used only by roles that name it.
Running the installer is your consent to that wider sandbox. SSH pushes still need Codex's
approval to leave the sandbox; HTTPS remotes work inside it.

The second command installs the `agent-handoff` skill, adds `/.agent-handoff/` to the
repository's `.gitignore`, and creates `.agent-handoff/roles.yaml` in the main worktree
when it is missing.

## Role templates: `.agent-handoff/roles.yaml`

One file per repository, in the main worktree, not tracked by Git. Lines are `key: value`,
at most two levels. Every role sets `harness` (`claude`, `codex` or `pi`), `model`, `effort`,
`name`, and `prompt`; set both model and effort, because a missing value would otherwise
fall back to whatever `/model` last saved as the tool's default.

| Key | Meaning |
| --- | --- |
| `max_rounds` | Repair rounds before the hook stops and asks you (default 3) |
| `review.worktree`, `finish.worktree` | `shared` (default): the implementer's worktree; `new`: a separate worktree |
| `finish.trigger` | `ask` (default): notify you after a passing review; `auto`: open the finish session |
| `finish.delivery` | `local` (default): archive, docs, commit only; `pr`: authorized PR delivery |
| `<role>.profile` | Codex only: a Codex configuration profile for that session. Use `handoff-net` for a Codex finish role with `delivery: pr`; Codex's default sandbox has no network |
| `<role>.provider` | Pi only, required: the Pi provider that owns the model, for example `openai-codex` |
| `<role>.billing` | Pi only, required: `subscription` (OAuth login) or `api` (API key) |
| `host`, `<role>.host` | Where the sessions run: `xirp` (default) or `herdr`; a role's `host` overrides the top-level one. See [Session hosts](#session-hosts) |
| `herdr_session` | The herdr session for herdr roles started outside herdr (default: herdr's default session) |

Prompt placeholders: `{change}`, `{head}`, `{round}`, `{report}`, `{delivery}`, `{handoff_write}`, `{author}`.
`{author}` tells the agent its Author identity: the tool, the template model, and the environment
variables holding its session IDs (`CLAUDE_CODE_SESSION_ID`, `CODEX_SESSION_ID` or `PI_SESSION_ID`, and `CHIRP_SESSION_ID`).
Agents cannot ask Xirp from inside a sandbox, so the model comes from the template. The agent
appends the output of `agent-handoff/scripts/handoff-author` so the shell, not the model, copies the IDs.
Claude Code calls skills as `/skill`, Codex as `$skill`, Pi as `/skill:<name>`. Session names default to
`<tool> - <impl|review|finish> - <change-id>`.

## Session hosts

A session host is where a role's session runs and where you watch it: `xirp` (the default) or
`herdr`. It is a property of your machine, so it lives in your untracked `roles.yaml`:

```yaml
host: herdr            # every role; omit for xirp
herdr_session: work    # herdr session used when you start a loop outside herdr

review:
  host: xirp           # this role only
  harness: codex
  # ...
```

`handoff-start` records each role's host (and a herdr role's herdr session) in `loop.yaml`; every
later step takes it from there, never from environment variables. A `loop.yaml` without host fields
is an `xirp` loop. One loop may mix hosts, for example the implementer in Xirp and the reviewer in
herdr: each message goes through its receiver's host. A configured host that is missing — its
command, or for herdr the selected session's server — stops `handoff-start`, `handoff-role` and
`handoff-finish` before anything opens; the loop never falls back to another host.

**herdr session.** Inside a herdr pane the loop uses that pane's session (`HERDR_SESSION`);
otherwise `herdr_session` from `roles.yaml`, otherwise herdr's default session. Every herdr call
names that session.

**herdr layout.** The loop groups its sessions under the repository's workspace (the workspace of
the main worktree), opening it without focus when herdr has none:

- A loop worktree (`--worktree new`, or a role with `worktree: new`) gets a linked workspace under
  the repository workspace, labelled with the change ID. The first role uses its root pane; a
  `shared` reviewer or finish role joins it in a new tab.
- A loop in the main worktree (`--worktree here` there) opens its tabs in the repository workspace.
- Each role has its own tab, named after the template's `name` (for example
  `claude - impl - add-export`). Nothing takes focus.

Each role starts as `herdr agent start` with the template's model and effort (Codex `-m`,
`-c model_reasoning_effort=`, `-p <profile>`; Pi `--provider`, `--model`, `--thinking`, plus the
worktree's `.pi/settings.json` as with Xirp). The first prompt is then submitted separately with
`herdr agent prompt`, without `--wait` (the command returns once the text is written; herdr accepts
`--timeout` only together with `--wait`). `loop.yaml` records the role's pane ID as its
session, its tab, the herdr session, the native session ID once herdr's integration reports it, and
the workspaces the loop opened. Before each message the hook checks that the pane still runs the
role's tool and, once known, the same native session; otherwise nothing is sent and the record is
retried like a failed Xirp message. A reused reviewer (`--reviewer-session <pane>`) keeps the native
session it ran when `handoff-start` checked it.

**Unconfirmed submissions.** When herdr says a prompt was not sent (`agent_blocked`,
`agent_not_found`, `pane_not_found`, `server_not_running`), the record is retried as above. Any other
error, such as a timeout, leaves it unknown whether the agent got the text, and sending it again could
start the same work twice. The hook then sends nothing more: it keeps the text in
`.agent-handoff/<change-id>/<role>-unconfirmed.txt` and sends one attention notice naming the pane and
the file. While that file exists, the role gets no prompt from the hook, `handoff-start` or
`handoff-finish`, and an open finish session is not taken as started. Check the pane, paste the text
if it did not arrive, then delete the file; the next hook or retry continues as usual.

**Dialogs and retry.** A new worktree makes Claude Code and Codex ask whether to trust the folder,
and other prompts (approvals, a Codex usage notice) can appear too. The loop never answers them:
trusting a folder is your decision. When a role stops at a dialog as it opens or when a message is
due, its pane is kept (`<role>.pending_prompt: true` when it was just opened), you get one attention
notice naming the herdr workspace, tab and pane as herdr reports them (also for a reused
`--reviewer-session` pane), and the record stays unprocessed. Answer the dialog there, then run
the retry command from the notice (`handoff-route --foreground` in that worktree); only the missing
prompt is sent, to the same pane. When the implementer stops at a dialog, `handoff-start` keeps its
pane and tells you so: answer it and run `handoff-start <change-id>` again. Trusting the parent
directory of your worktrees in Claude Code and Codex beforehand avoids most of these stops.

herdr needs its integration for each tool (`herdr integration install claude|codex|pi`) to report
native session IDs; `handoff-doctor` warns when one is missing. `XIRP-SESSION-ID` is `null` in a
herdr pane, even when herdr was started from an Xirp shell (see the `agent-handoff` skill).

Possible later host: `ghostty + tmux` (tmux `send-keys` can type into a pane) is not supported yet.

## Commands

### `handoff-start <change-id>`

Checks that `feature/<change-id>` exists and holds the OpenSpec change (planning is usually
committed on that branch), prepares the implementer's
worktree, opens only the implementer session, and writes
`.agent-handoff/<change-id>/loop.yaml` there. The reviewer is opened by the hook when the
implementer first hands over.

| Option | Effect |
| --- | --- |
| `--worktree new` | Default. Open the implementer in `../<repo>-<change-id>` on the feature branch |
| `--worktree here` | Use the current checkout; it must already be on `feature/<change-id>` |
| `--impl <override>` | Override the implement template for this loop |
| `--review <override>` | Override the review template for this loop |
| `--finish ask\|auto` | Override `finish.trigger` for this loop |
| `--reviewer-session <id>` | Reuse an existing session on the review role's host as the reviewer: an Xirp session ID, or a herdr pane ID |

An override is `claude|codex:<model>:<effort>`, or `pi:<provider>/<model>:<effort>:<billing>` for
Pi (verified like a Pi template). Overrides are written to `loop.yaml`; `roles.yaml` is never
changed. The [`handoff-doctor`](#handoff-doctor-change-id) checks run first for all three roles in
effect, including every Pi role's model, credential, billing and trust; a failed check creates no
worktree, session or `loop.yaml`.
When an override changes the tool, the prompt's leading skill call follows it (`$change-review`
becomes `/skill:change-review` for Pi or `/change-review` for Claude Code), and a session name
that starts with the old tool's name starts with the new one; anything else stays as written.

### `handoff-role <change-id> <review|finish> [<override>] [--worktree new] [--replace]`

Changes the review or finish role of a running loop, for example to run the reviewer in Pi after
`handoff-start`:

```bash
handoff-role add-export review pi:openai/gpt-6.2-sol:high:api
```

The override takes the same form as `handoff-start`'s and rewrites the skill call and session
name the same way. `--worktree new` moves the role from the implementer's worktree to one of its
own (`<worktree>-review` or `<worktree>-finish`), for example so that a Pi reviewer can work next to a
shared Pi finish role; it can be given with or without an override. Moving a role back to the
implementer's worktree is not supported. It runs the `handoff-doctor` checks for that role and the
one-Pi-role-per-worktree check first, and changes nothing unless all of them pass. It never changes
`roles.yaml` or the implementer: only `review` and `finish` can be changed.

A role whose session is open is refused unless `--replace` is given. Make sure the old session has
stopped first. `--replace` then:

1. Ends the old session through its host, and changes nothing unless the host confirms it. Xirp
   must delete the session, or answer that it no longer lists it. herdr closes only the role's tab,
   and only while that tab is the one the loop opened and its pane still runs the role's agent (the
   same tool and native session) or no agent; a pane herdr reports gone needs nothing. A prompt to
   the old pane that herdr did not confirm no longer holds back the new role.
2. Clears the role's session in every copy of `loop.yaml` and writes the new settings. Records
   written so far are still checked against the settings they were written under, so an earlier
   pass stays valid when the reviewer becomes a Pi role. If a write fails after the old session was
   deleted, the command says so and exits non-zero; fix the cause and run the same command again.
3. Hands the new role the record that waited for the old one:
   - review: when the newest record is an `implement`/`done` record that the old reviewer received
     (`routing.log`) and no review followed, it is routed again in its own worktree, so the new
     reviewer opens from the new settings and receives that round. If it does not open, the record
     stays unprocessed (an attention notice tells you why) and `handoff-route --foreground` retries
     it once the cause is fixed. Once a new reviewer session holds the round, or may hold it (the
     host did not confirm the prompt, or its session ID or the result could not be recorded), it is
     never sent again: find or check that session as the message says. If the record's mark cannot be cleared, the
     command names the line to remove from `.routed` before you run the retry.
   - finish: when the newest record is a blocked finish, or a passing review whose finish session
     had opened, a new finish session opens as `handoff-finish` would open it; if it cannot, you get
     an attention notice and `handoff-finish` retries it. A blocked finish that ran in the
     implementer's worktree and is given `--worktree new` moves to `<worktree>-finish` with the
     feature branch, as `handoff-finish` does for a new finish worktree. That worktree must still hold
     the blocked finish's commit, the branch must be at its `HEAD`, and the new worktree is opened only
     at that commit. A move cut short is completed by the next `handoff-finish`.

With no record waiting, only the settings change, and the new role opens when its turn comes. The
replacement and the hand-off are written to `routing.log`. A Pi role's `.pi/settings.json` that the
loop wrote for the old role is replaced; one the loop did not write, or one changed since, refuses
the replacement before anything is deleted unless it already matches the new role. So does a
`.pi/settings.json` tracked in the commit a worktree of the role's own would check out.

### `handoff-finish <change-id>`

Opens the finish session when the newest record of the loop is a passing review of the
implementer worktree's current, clean `HEAD`, and the loop has not finished yet. With
`finish.worktree: new`, the implementer worktree is detached at the same commit and a new
worktree `../<repo>-<change-id>-finish` takes over the branch; nothing is deleted.

Running it again before the finish session writes its record opens nothing: it reports the
finish session already open. If that session died without a record, delete it in Xirp and
run `handoff-finish` again to open a new one.

After a blocked finish (for example a rejected push), fix the cause and run `handoff-finish`
again. It retries when the finish worktree is clean and builds on the passing review: the
finish session resumes from the stopped stage, or a new one opens if it is gone. The retry is sent
once per blocked record (recorded as `finish.retried_for` in `loop.yaml`), whether or not herdr
confirmed it: running `handoff-finish` again before the finish session writes a new record — even
while the first run is still sending — reports that the retry was already sent and sends nothing.
Only a retry the host reports as not sent (for example a dialog in the way), or one whose
claim in the loop directory could not be created (the command fails and names the error), can be
run again.

### `handoff-cleanup <change-id> [--abandon] [--yes]`

Removes a finished loop. It acts only when the newest record is `finish`/`done` and every loop
worktree is clean; otherwise it names the reason and changes nothing. Without `--yes` it lists
the sessions and worktrees it would remove, the Work Items it would archive, and the Pi settings
file it would remove from a kept main worktree. With `--yes` it:

1. copies the handoff records and the review reports they reference to
   `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/` (still ignored by Git),
   together with every `work-items/WI-*` directory of a worktree it will remove, under `work-items/`
   there; Work Items in a kept main worktree stay where they are. If any copy fails, nothing is removed;
2. deletes the loop's Xirp sessions, and for herdr roles closes what the loop opened: the
   workspace it opened for a loop worktree, or only the role's tab in the repository workspace
   (a loop in the main worktree). It never closes a workspace, tab or pane the loop did not open.
   This happens before the worktrees go, because herdr resumes the agents of open panes when its
   server restarts. A target herdr reports as already gone counts as closed. If herdr is missing, its
   server is not running, or a close fails, cleanup stops with a non-zero status and removes no
   worktree; start herdr and run it again;
3. removes every loop worktree except the main worktree, without `--force`. In a kept main worktree
   it removes the `.pi/settings.json` the loop created for a Pi role (recorded in `loop.yaml` and
   unchanged); a file that existed before the loop is kept.

The branch `feature/<change-id>` is kept: the work is not merged yet. Merge and delete the
branch separately.

For a loop that will not finish (for example a blocked finish whose PR was closed), add
`--abandon`: the finish record is not required, and every other check and step stays the same.

### `handoff-doctor [change-id]`

Checks that this machine can run a loop, without opening, messaging or closing any session and
without changing any file. Without a change ID it checks the three roles of `roles.yaml`; with one,
the roles recorded in that loop's `loop.yaml` (overrides and `handoff-role` changes included). It
prints one line per check, `<ok|warn|fail> <area> <message>`, and exits non-zero when any line is
`fail`:

```text
$ handoff-doctor
ok base git found
ok base jq found
ok base main worktree /Users/me/src/app
ok base templates /Users/me/src/app/.agent-handoff/roles.yaml
ok host implement, review, finish: xirp project 3f1c… for /Users/me/src/app
ok harness implement: claude 2.9.0 (Claude Code)
ok harness implement: Claude Code Stop hook registered
ok harness review, finish: codex codex-cli 0.130.0
ok harness review, finish: Codex Stop hook registered
warn harness review, finish: codex hook trust cannot be checked from outside Codex; confirm "Agent 交接派送" is trusted and enabled in /hooks
ok role implement: claude model opus at high (model not verified)
ok role review: codex model gpt-6.1-sol at high (model not verified)
ok role finish: codex model gpt-5.6-terra at medium (model not verified)
warn notify no notifier at /Users/me/.config/ai-notify/hooks/telegram-notify.sh; loop notices will not be delivered (see /notify-setup)
```

| Area | Checks | A problem is |
| --- | --- | --- |
| `base` | `git`, `jq`, the main worktree, the template file (`roles.yaml` or `loop.yaml`). A failure here skips every other check | `fail` |
| `host` | For each host in use. `xirp`: the command, and the main worktree registered as an Xirp project. `herdr`: the command, its version, and the server of each selected herdr session | `fail` |
| `harness` | For each tool in use: the command and its version, and its trigger — the `handoff-route` Stop hook in `~/.claude/settings.json` or `~/.codex/hooks.json`, or the Pi trigger extension | `fail` |
| `harness` | Codex hook trust, which cannot be read from outside Codex | `warn` |
| `harness` | For a role on herdr: herdr's integration for its tool (`herdr integration status`); without it herdr cannot report the native session ID | `warn` |
| `role` | Template fields, harness and host; for Pi, the repository trust, the model listed under the provider, the credential and its billing | `fail` |
| `role` | Claude Code and Codex models, which have no reliable list to check: shown as `model not verified` | `ok` |
| `notify` | The notifier is installed | `warn` |

`handoff-start` (all three roles), `handoff-role` (the role it changes) and `handoff-finish` (the
finish role) run the same checks before they open a session or write `loop.yaml`. They print the
`warn` and `fail` lines, prefixed with the command name, and refuse when any line is `fail`.

## What the hook does

| Newest record | Action |
| --- | --- |
| `implement`, `done` | First round: open the reviewer (in a new detached worktree when `review.worktree: new`). Later rounds: move a separate review worktree to the new commit, then message the reviewer |
| `review`, `done`, `changes-required` | Message the implementer with the round, the reviewed commit, and the report's absolute path; at the round limit, notify you instead |
| `review`, `done`, `pass` | `ask`: notify you to run `handoff-finish`; `auto`: open the finish session |
| any `blocked` | Notify you only |
| `finish` | Notify you only |

Before routing, the worktree holding the record must be clean at the record's `head`;
otherwise you are notified. Each record is logged in `.agent-handoff/<change-id>/routing.log`
with the stopping session's model: the model Xirp reports for Claude Code and Codex (for example
`model=claude-opus-5-5`), and `provider/model` from the record's `agent` section for Pi (for
example `model=openai/gpt-6.2-sol`). herdr reports no model, so a Claude Code or Codex role on
herdr shows its template's model, marked `model=gpt-6.1-sol(template)`. The stopping session is
`session=<Xirp session ID>`, or inside a herdr pane `session=herdr:<pane ID> native=<native session ID>`
(an Xirp ID inherited by herdr panes is never used). A manual `--foreground` run or a retry may be
started by someone else, so it logs `session=unknown` and names who ran it as
`trigger=xirp:<id>` or `trigger=herdr:<pane ID>`. The hook never writes to GitHub and never pushes, and it
always exits successfully.

**Continuing after `blocked`.** A blocked record stops the loop until you act; nothing resumes it
on its own.

- Blocked `implement` or `review`: fix the cause, then have the implementer write a new
  `implement`/`done` record at a clean, committed `HEAD`. The hook hands it to the reviewer as
  the next round, so it counts toward `max_rounds`. Use this when a review is blocked only on a
  step a person must do, such as a real-environment acceptance check: do that step, record the
  evidence in the change's Work Item (cleanup archives the Work Items of removed worktrees), and
  ask the implementer to tick the task, commit, and hand over.
- Blocked `finish`: run `handoff-finish <change-id>` again (see [handoff-finish](#handoff-finish-change-id)).

Each record ends in one of three outcomes:

| Outcome | Examples | Notice | Marked processed (`.routed`) |
| --- | --- | --- | --- |
| Delivered | reviewer opened or messaged, report handed to the implementer, finish opened | progress notice (if its switch is on) | yes |
| Stops for you | `blocked`, round limit, any `finish` record, pass with `ask`, worktree not clean or not at `head`, review worktree not clean, unreadable record, a Pi record that differs from its template, a reviewer opened whose session ID could not be written to `loop.yaml` (`opened-unrecorded`; write it as `reviewer.session` yourself) | one attention notice | yes |
| Retry | Xirp message not delivered, reviewer or finish session not opened (including a Pi role that fails verification), review worktree not created or moved | one attention notice (recorded in `.notified`) | no |

A retry record is tried again by the next hook run in that worktree, or right away with
`handoff-route --foreground` run from that worktree
(`~/.config/wk-workflow/handoff/handoff-route`); the routing log shows `send-failed` or
`open-failed`. Its attention notice is sent once, however many retries fail; the progress notice
follows once delivery succeeds.
A retry reuses a review or finish worktree that the failed attempt already made only when it is
clean; a finish worktree must also be the loop's own (recorded in the implementer's `loop.yaml`,
or holding the loop's untracked `loop.yaml` that names it when that record could not be written),
on `feature/<change-id>` at the passing commit. A worktree made by hand with the same name is never
taken over. An unclean review worktree stops for you instead; nothing in either is removed.

## Notifications

The hook tells you what happened through the Telegram notifier
([docs/notify/telegram.md](../../docs/notify/telegram.md)). Each record gives at most one progress
notice and at most one attention notice. One exception: when a retry outcome was already
notified and the retry then stops for you for a different reason (for example an unclean review
worktree), that stop sends one more attention notice so you learn the new cause.

| Notice | When | Switch (`~/.config/ai-notify/config`) |
| --- | --- | --- |
| ✅ 實作完成 | an `implement` record was handed to the reviewer | `NOTIFY_HANDOFF_IMPLEMENT` |
| 🔁 審查退回／🟢 審查通過 | a `changes-required` review reached the implementer, or a pass with `finish.trigger: auto` opened finish | `NOTIFY_HANDOFF_REVIEW` |
| 📦 收尾完成 | a `finish`/`done` record | `NOTIFY_HANDOFF_FINISH` |
| 🔴 需要你處理 | the loop stops for you, or a retry outcome | none: always sent while Telegram is enabled |

- A missing switch counts as on; change them in `bash scripts/notify/telegram/update.sh types`.
  Turning a switch off never changes routing.
- A pass with `finish.trigger: ask` is an attention notice, so you are told to run
  `handoff-finish <change-id>` even with review notices off.
- Every notice names the change, the round, the commit (7 characters) and one line on what
  happens next. Its title shows `Agent Handoff (<tool> / <model> / <effort>)` for the session that
  wrote the record, as Xirp reports it when the record is processed (for example
  `Claude / claude-opus-5-5 / high`); parts Xirp does not report are left out. The title also
  carries the same session label as that session's other notifications. A manual
  `--foreground` run or a retry names no agent and no session label, because whoever triggers it
  may not have written the record. A Pi record names its own agent instead, from its `agent`
  section, also for manual runs and retries: `Agent Handoff (Pi / openai-codex/gpt-6.2-sol / high / 訂閱)`
  (`API` for an API key, `unknown` when the record could not tell).
- The ordinary completion notice of the same session is still sent.
- Mixed versions: the hook sends handoff events only when the notifier script declares
  `# ai-notify-capability: handoff-events`. An older or rolled-back notifier gets attention as
  the previous generic notice (Action Required) and no progress notices. Without a notifier
  nothing is sent and routing is unchanged.

## Pi roles

A role with `harness: pi` runs in Pi. It must also set `provider` and `billing`; `model` is the
exact model ID under that provider (no `provider/` prefix, no alias such as `opus`), and `effort`
is a Pi thinking level: `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`.

```yaml
review:
  worktree: new
  harness: pi
  provider: openai-codex
  model: gpt-6.2-sol
  effort: high
  billing: subscription
  name: "pi - review - {change}"
  prompt: "/skill:change-review {change} commit {head} round {round} {author}"
```

The loop stops instead of running a Pi role on the wrong provider, model or billing. It checks
at three points:

1. **`handoff-start`**, for every Pi role in effect (also the review and finish roles that open
   later), before any worktree or session: at most one Pi role per worktree, the Pi trigger is
   installed, Pi already trusts the main worktree, the model is listed under the provider by
   `pi --list-models <model>` (with thinking support unless effort is `off`), and
   `pi auth check --provider <provider> --json` reports `ready` with `oauth` for `subscription`
   or `api_key` for `api`. Any other credential type is a mismatch.
2. **Routing a record**: a Pi session's `handoff-write` records the session's actual provider,
   model, effort, billing and session ID in an `agent` section. If any of them differs from the
   role's template in `loop.yaml`, or is missing or `unknown` (for example after `/model`), the
   record is not routed and you get one attention notice naming each difference.
3. **The hook opening a Pi reviewer or finish role** repeats the checks of point 1. A failure is a
   retry: one attention notice, the record stays unprocessed, and the next hook run (or
   `handoff-route --foreground`) opens the role once the cause is fixed. `handoff-finish` exits
   non-zero instead.

**Worktree settings.** Xirp currently drops launch options for Pi 1.x, so the role starts from
`.pi/settings.json` (`defaultProvider`, `defaultModel`, `defaultThinkingLevel`) written into its
worktree just before it opens. The file is ignored through the repository's `info/exclude`
(the main worktree ignores that path too) and is never committed. The same values are also passed
to Xirp. A worktree that already has a different or tracked `.pi/settings.json` cannot host a Pi
role. Because one file serves one role, a worktree holds at most one Pi role: a Pi role may share
a worktree with Claude Code or Codex roles, but a second Pi role needs `worktree: new`.

**Trust.** Pi asks whether to trust a folder that has `.pi/settings.json` or `.agents/skills`, and
a background session would wait at that prompt. The Pi trigger answers it for the session only
when the folder is a linked worktree that an untracked `loop.yaml` there lists as a role
worktree, and you already trust the main worktree in Pi (`~/.pi/agent/trust.json`, nearest saved
decision). Otherwise Pi decides as usual. Nothing is saved to `trust.json`.

**Anthropic subscription.** `provider: anthropic` with `billing: subscription` is allowed when the
credential is `oauth`, but `handoff-start` warns that it may consume paid extra usage. A mismatch
is refused, never warned.

**Routing trigger.** The Pi trigger runs `handoff-route` on `agent_settled`, when Pi will not retry
or continue on its own; it skips subagents (`PI_SUBAGENT_PARENT_SESSION`). The role session writes
its own record, so `PI_*` describe that session.

**Cost and context.** A reviewer keeps one session for the whole loop, so its context grows every
round; when it fills, Pi compacts it automatically and the role keeps working. Context size
depends on the provider: check `pi --list-models <model>` (the same model can list a smaller
window under `openai` than under `openai-codex`). With `billing: api` every round is paid usage,
and Pi also loads your global Pi packages and skills into each role session, which adds tokens.
Prefer `subscription` for long loops, and choose the provider with the larger window.

**Subagents inside a role are not locked.** pstack's subagents follow the role's provider when they
resolve aliases such as `opus` or raise effort. They switch provider, and maybe billing, only when:
a prompt names another provider's `provider/id` explicitly; `pstack-models.md` sets `pi models:`;
or the role's provider is not `anthropic`, `openai` or `openai-codex`, so aliases fall back to
Anthropic. Avoid these in handoff roles. Records still describe the role session, so routing is
unaffected; only usage moves.

## Troubleshooting

- **Nothing happens after an agent stops**: the session was opened before the hook was
  installed, Codex has not trusted the hook, the agent did not write a record, or the host of the
  next role is not installed on this machine. Check `routing.log`, `.agent-handoff/<change-id>/`
  and `handoff-doctor <change-id>`.
- **A herdr role does not move on**: it may wait on a dialog (folder trust, an approval). Find the
  tab named in the attention notice, answer it there, then run the retry command.
- **Xirp shows no reviewer, or the implementer shows `idle` mid-round**: Xirp lists only the
  sessions it opened (the loop's implementer, reviewer, and finish sessions). Subagents an
  agent starts inside its session (for example Claude Code's Agent tool) and background
  commands (for example a full test run) never appear there; an `idle` session may be waiting
  for them and is resumed automatically when they finish. The reviewer opens only after the
  implementer writes its implement record and its turn ends, so no reviewer before that is
  expected. A Pi role may show `finished` in Xirp while it is still working, and messages from
  the hook still reach it. Check the records and `routing.log` for progress.
- **"has uncommitted changes" or "HEAD … differs"**: commit or clean the worktree, then
  write a new record.
- **A removed loop worktree comes back as a nearly empty directory** (only `.codex/config.toml`
  or `.claude/settings.local.json`): TokenEconomizer remembers the checkout and writes its settings
  back. Run `python3 -I scripts/user/te-prune-stale-checkouts.py --dry-run` from wk-agent-ops, then
  without `--dry-run`, and delete the directory.
- **`handoff-finish` refuses**: the message names the failed condition, such as a newer
  commit than the passing review or an unfinished round.
- **The reviewer ran out of quota mid-loop**: stop it (or wait until it is idle), then replace it.
  With a Pi finish role in the implementer's worktree, a Pi reviewer needs a worktree of its own:

  ```bash
  handoff-role add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace
  ```

  The old session is deleted, and a round that had already gone to it goes to the new reviewer in
  `<worktree>-review`; check `routing.log` for `reviewer:opened`.
- **A Pi role is refused**: the message names the role and the check. Run
  `pi --list-models <model>` and `pi auth check --provider <provider> --json` to compare, run
  `scripts/handoff/install.sh` for a missing trigger, or `/trust` in Pi in the main worktree.
