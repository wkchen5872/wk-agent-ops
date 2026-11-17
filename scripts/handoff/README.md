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
otherwise you are notified. Each record is routed once and logged in
`.agent-handoff/<change-id>/routing.log` with the stopping session's model. The hook never
writes to GitHub and never pushes. Its notices are sent even when the notifier's
"action required" category is turned off, because the loop waits for you; failures end silently, so watch for the usual
"agent stopped" notification if a loop seems stuck.

## Troubleshooting

- **Nothing happens after an agent stops**: the session was opened before the hook was
  installed, Codex has not trusted the hook, or the agent did not write a record. Check
  `routing.log` and `.agent-handoff/<change-id>/`.
- **"has uncommitted changes" or "HEAD … differs"**: commit or clean the worktree, then
  write a new record.
- **`handoff-finish` refuses**: the message names the failed condition, such as a newer
  commit than the passing review or an unfinished round.
