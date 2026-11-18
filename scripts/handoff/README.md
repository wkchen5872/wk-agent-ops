# Agent handoff loop

Implementation, review, and finish agents hand work to each other without you relaying
messages. Each agent ends its round by writing a handoff record with the `agent-handoff`
skill; when the agent stops, a Stop hook reads that record and messages the next agent
through Xirp, or notifies you through the existing Telegram notifier.

Scope: one person's machine. Handoff records and the hook exist only locally, so the loop never
spans people: it commits locally and does not push, open a PR, or post reviews by default. Work
that another person implements or reviews goes through the GitHub PR instead (`github-pr`,
`change-review`), which is where the team boundary is. See
[本機開發四階段流程](../../docs/workflow/local-development.md) for how the two fit together.

Requirements: `git`, `jq`, and the `xirp` CLI for opening and messaging sessions.
Without Xirp the hook does nothing and the manual workflow is unchanged.

## Install

```bash
bash scripts/handoff/install.sh                              # once per machine
bash scripts/skills/install.sh --target /path/to/repo        # once per repository
```

The first command installs `handoff-start`, `handoff-finish` and `handoff-cleanup` in `~/.local/bin`, installs
`handoff-route` in `~/.config/wk-workflow/handoff/`, and registers it as a Stop hook for
Claude Code (`~/.claude/settings.json`) and Codex (`~/.codex/hooks.json`). Then open a new
Codex session and, in `/hooks`, find the Stop hook named `Agent 交接派送`, trust it and make
sure it is enabled. Hooks load when a session starts, so sessions opened earlier do not route.

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
at most two levels. Every role sets `harness` (`claude` or `codex`), `model`, `effort`,
`name`, and `prompt`; set both model and effort, because a missing value would otherwise
fall back to whatever `/model` last saved as the tool's default.

| Key | Meaning |
| --- | --- |
| `max_rounds` | Repair rounds before the hook stops and asks you (default 3) |
| `review.worktree`, `finish.worktree` | `shared` (default): the implementer's worktree; `new`: a separate worktree |
| `finish.trigger` | `ask` (default): notify you after a passing review; `auto`: open the finish session |
| `finish.delivery` | `local` (default): archive, docs, commit only; `pr`: authorized PR delivery |
| `<role>.profile` | Codex only: a Codex configuration profile for that session. Use `handoff-net` for a Codex finish role with `delivery: pr`; Codex's default sandbox has no network |

Prompt placeholders: `{change}`, `{head}`, `{round}`, `{report}`, `{delivery}`, `{handoff_write}`, `{author}`.
`{author}` tells the agent its Author identity: the tool, the template model, and the environment
variables holding its session IDs (`CLAUDE_CODE_SESSION_ID` or `CODEX_SESSION_ID`, and `CHIRP_SESSION_ID`).
Agents cannot ask Xirp from inside a sandbox, so the model comes from the template. The agent
appends the output of `agent-handoff/scripts/handoff-author` so the shell, not the model, copies the IDs.
Claude Code calls skills as `/skill`, Codex as `$skill`. Session names default to
`<tool> - <impl|review|finish> - <change-id>`.

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
| `--impl tool:model:effort` | Override the implement template for this loop |
| `--review tool:model:effort` | Override the review template for this loop |
| `--finish ask\|auto` | Override `finish.trigger` for this loop |
| `--reviewer-session <xirp-id>` | Reuse an existing Xirp session as the reviewer |

Overrides are written to `loop.yaml`; `roles.yaml` is never changed.

### `handoff-finish <change-id>`

Opens the finish session when the newest record of the loop is a passing review of the
implementer worktree's current, clean `HEAD`, and the loop has not finished yet. With
`finish.worktree: new`, the implementer worktree is detached at the same commit and a new
worktree `../<repo>-<change-id>-finish` takes over the branch; nothing is deleted.

After a blocked finish (for example a rejected push), fix the cause and run `handoff-finish`
again. It retries when the finish worktree is clean and builds on the passing review: the
finish session resumes from the stopped stage, or a new one opens if it is gone.

### `handoff-cleanup <change-id> [--abandon] [--yes]`

Removes a finished loop. It acts only when the newest record is `finish`/`done` and every loop
worktree is clean; otherwise it names the reason and changes nothing. Without `--yes` it lists
the sessions and worktrees it would remove. With `--yes` it:

1. copies the handoff records and the review reports they reference to
   `<main worktree>/.agent-handoff/archive/<change-id>/<worktree name>/` (still ignored by Git);
2. deletes the loop's Xirp sessions;
3. removes every loop worktree except the main worktree, without `--force`.

The branch `feature/<change-id>` is kept: the work is not merged yet. Merge and delete the
branch separately.

For a loop that will not finish (for example a blocked finish whose PR was closed), add
`--abandon`: the finish record is not required, and every other check and step stays the same.

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
with the stopping session's model. The hook never writes to GitHub and never pushes, and it
always exits successfully.

Each record ends in one of three outcomes:

| Outcome | Examples | Notice | Marked processed (`.routed`) |
| --- | --- | --- | --- |
| Delivered | reviewer opened or messaged, report handed to the implementer, finish opened | progress notice (if its switch is on) | yes |
| Stops for you | `blocked`, round limit, any `finish` record, pass with `ask`, worktree not clean or not at `head`, review worktree not clean, unreadable record | one attention notice | yes |
| Retry | Xirp message not delivered, reviewer or finish session not opened, review worktree not created or moved | one attention notice (recorded in `.notified`) | no |

A retry record is tried again by the next hook run in that worktree, or right away with
`handoff-route --foreground` run from that worktree
(`~/.config/wk-workflow/handoff/handoff-route`); the routing log shows `send-failed` or
`open-failed`. Its attention notice is sent once, however many retries fail; the progress notice
follows once delivery succeeds.
A retry reuses a review or finish worktree that the failed attempt already made only when it is
clean; a finish worktree must also be the loop's recorded one, on `feature/<change-id>` at the
passing commit. An unclean review worktree stops for you instead; nothing in either is removed.

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
  carries the same session label as that session's other notifications.
- The ordinary completion notice of the same session is still sent.
- Mixed versions: the hook sends handoff events only when the notifier script declares
  `# ai-notify-capability: handoff-events`. An older or rolled-back notifier gets attention as
  the previous generic notice (Action Required) and no progress notices. Without a notifier
  nothing is sent and routing is unchanged.

## Troubleshooting

- **Nothing happens after an agent stops**: the session was opened before the hook was
  installed, Codex has not trusted the hook, or the agent did not write a record. Check
  `routing.log` and `.agent-handoff/<change-id>/`.
- **Xirp shows no reviewer, or the implementer shows `idle` mid-round**: Xirp lists only the
  sessions it opened (the loop's implementer, reviewer, and finish sessions). Subagents an
  agent starts inside its session (for example Claude Code's Agent tool) and background
  commands (for example a full test run) never appear there; an `idle` session may be waiting
  for them and is resumed automatically when they finish. The reviewer opens only after the
  implementer writes its implement record and its turn ends, so no reviewer before that is
  expected. Check the records and `routing.log` for progress.
- **"has uncommitted changes" or "HEAD … differs"**: commit or clean the worktree, then
  write a new record.
- **`handoff-finish` refuses**: the message names the failed condition, such as a newer
  commit than the passing review or an unfinished round.
