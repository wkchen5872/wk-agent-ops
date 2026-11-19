---
name: agent-handoff
description: >
  Write the handoff record ("交件單") that ends an agent's round in an implement–review–finish
  loop, so the next step can be decided by a script instead of by reading the conversation.
  Use at the end of an implementation round, a review round, or a completion run when the
  Change has a loop (`.agent-handoff/<change-id>/loop.yaml`), or whenever the user asks to
  leave a handoff record. Records are written only through the bundled `handoff-write` script.
license: MIT
compatibility: Requires git and bash.
metadata:
  author: wkchen
  version: "1.0"
---

# Agent Handoff

A handoff record tells the next agent — or the hook that routes work — what this round
produced. Write exactly one record at the end of each round, after the work it describes
is committed and, for a review, after the report is saved. Never write the YAML by hand:
run the script, which checks every field and numbers the file.

```bash
.agents/skills/agent-handoff/scripts/handoff-write \
  --change <change-id> --role <implement|review|finish> --status <done|blocked> \
  --head <commit> [--verdict <pass|changes-required|blocked>] [--report <path>] [--note "<one sentence>"]
```

The same script is installed under `.claude/skills/agent-handoff/scripts/`. Run it from
inside the worktree you worked in. It prints the path of the record it wrote; a non-zero
exit means nothing was written — read the message, fix the input, and run it again.

## When each role writes

| Role | When | `status` |
| --- | --- | --- |
| `implement` | After the round's changes pass their tests and are committed locally | `done`; `blocked` when you cannot finish and need the user |
| `review` | After the verdict is decided, the report is saved, and any PR reply's publication state is known | `done` when the result may be routed; `blocked` when publication was denied, timed out or did not read back, when the user asked for local-only or no notification, or when a local-only request conflicts with a handoff request |
| `finish` | After the completion workflow reports its final stage | `done` when the requested delivery completed; `blocked` naming the stage that stopped it |

A final-version review run inside the completion workflow does not write a record; its
result belongs to the `finish` record.

## Fields

| Field | Meaning |
| --- | --- |
| `change` | The OpenSpec change ID (kebab-case). |
| `round` | Set by the script: the number of implementation rounds so far. |
| `role` | `implement`, `review`, or `finish`. |
| `status` | `done` or `blocked`. A `blocked` record stops automatic routing; only the user is notified. |
| `head` | The commit handed over (`implement`), reviewed (`review`), or produced (`finish`). The script stores the full SHA. |
| `verdict` | Review only: `pass`, `changes-required`, or `blocked`. Keep the technical verdict even when `status` is `blocked`. |
| `report` | Review only: path of the saved report, relative to the root of this worktree. |
| `note` | One sentence for a human, such as why the record is blocked. |
| `at` | Set by the script: local time in ISO 8601 with offset. |
| `agent` | Set by the script inside a Pi session only: `harness: pi`, `provider`, `model`, `effort`, `billing` (`subscription`, `api` or `unknown`) and `session`. |

## Rules

- Commit before an `implement` record: the worktree must be clean at `head`, or the hook
  will refuse the handoff and notify the user.
- Do not edit, rename, or delete existing records; each round adds a new file.
- Do not restate the review report in `note`; the next agent reads the report itself.
- The `.agent-handoff/` directory is ignored by Git; never force-add it.

## Pi roles

In a Pi session, `handoff-write` adds an `agent` section taken from the Pi runtime
(`PI_PROVIDER`, `PI_MODEL`, `PI_REASONING_LEVEL`, `PI_SESSION_ID`) and from
`pi auth check` (`oauth` is `subscription`, `api_key` is `api`, anything else `unknown`).
No argument sets it. The hook compares it with the role's template and stops the loop on any
difference, so the role session writes its own record — never a subagent, whose values may
differ — and does not switch model, provider or thinking level before writing it.

## Example

```bash
# Reviewer, after saving its report and confirming the PR reply:
.agents/skills/agent-handoff/scripts/handoff-write --change add-export --role review \
  --status done --verdict changes-required --head HEAD \
  --report work-items/WI-20261120-export/reviews/codex-r02.md --note "Time zone boundary not handled"
```

Resulting record `.agent-handoff/add-export/02-review.yaml`:

```yaml
change: add-export
round: 1
role: review
status: done
verdict: changes-required
head: 3f2a91c0d4…
report: work-items/WI-20261120-export/reviews/codex-r02.md
note: Time zone boundary not handled
at: 2026-11-20T14:05:00+08:00
```

## Author block: `handoff-author`

Posts and reports name the session that wrote them. Never retype a Session ID: let the shell
copy it.

```bash
.agents/skills/agent-handoff/scripts/handoff-author --tool Codex --model gpt-5.6-luna >> body.md
.agents/skills/agent-handoff/scripts/handoff-author --tool 'Claude Code' --model opus > /tmp/author.md
.agents/skills/agent-handoff/scripts/handoff-author --tool Pi --model gpt-6.2-sol >> body.md
```

It prints the four Author lines of the `github-issue`／`github-pr` frame — `Co-Authored-By`,
`AI-Assisted-By` (omitted when `--model` is empty), `SESSION-ID` (from `CODEX_SESSION_ID`,
`CLAUDE_CODE_SESSION_ID` or `PI_SESSION_ID`, by tool), and `XIRP-SESSION-ID` (from `CHIRP_SESSION_ID`) — writing
`null` for an ID the runtime does not expose. Append the output under `## Author`. When a
dedicated agent posts for you, save the output to a file and pass it as `author_file`. The role
prompts give the tool and the template model; the agent does not look up its own model.
