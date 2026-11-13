---
name: github-issue
description: >
  Create or update a GitHub Issue that explains a piece of work, following the
  project's shared handoff contract. The source can be an explicitly named Work
  Item, an OpenSpec Change, both, the records tied to the current branch, or —
  when none exist — the current session's discussion. Create writes a short
  Handoff / Goal / Author body after checking for an existing Issue; update adds
  one comment describing what changed and never rewrites the body. Every write
  checks the full repository target and authorization first and is read back.
  Works through gh or a configured GitHub MCP. Use whenever the user asks to
  open, register, link, or update a GitHub issue for a Work Item, a change, or
  the current work — for example "建立 issue", "開 issue", "更新 issue",
  "把這個 change 登錄到 GitHub", "用這個 WI 開 issue", or just "git issue".
license: MIT
compatibility: "Requires git and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "2.0"
---

# GitHub Issue

A thin entry for the Issue side of the GitHub handoff. The Issue explains the
work so someone who reads only GitHub understands the problem, scope, and
intended result; later iterations are kept as comments.

`docs/github-handoff.md` owns every template, field meaning, and rule. This
skill only sequences the work. **Read that contract first** — sections 3, 4, 5
and 6.1 — and take the body and comment layouts from section 6.1 rather than
from memory.

## What this skill may change

| Operation | Needs | Side effect when authorized |
|---|---|---|
| `create` | A source (Work Item, Change, branch records, or the session), explicit repository | Creates one Issue, or returns the existing one |
| `update` | The Issue (URL, number, or a uniquely associated source), what changed | Adds one comment to that Issue |

It never edits an Issue body, title, state, labels, or assignees, never edits or
deletes comments, and never stages, commits, pushes, or creates a Work Item,
Change, branch, or PR. Those need their own request.

GitHub reads and writes go through one available, already configured tool: `gh`
or a GitHub MCP. The commands below are written for `gh`, always with an explicit
`-R <host>/<owner>/<repo>` so the CLI cannot pick another repository; with an MCP,
use its equivalent tools and pass the same full owner and repository. Do not add
a wrapper or adapter around either one. If neither can do the operation, stop and
report what is missing instead of installing a tool or logging in.

If the request does not say which operation is meant and the intent cannot tell
them apart, ask before doing anything.

## Shared steps

### Step 1 — Gather the material

Work Items, Changes, and the session are **material** for the Issue, not text to
post. Gather two kinds and combine them.

**Records.** Decide which local records apply, in this order:

1. **Explicit selection.** The user names a Work Item, a Change, or both. Read
   them. A named source that cannot be found or read is reported:
   stop and ask the user to confirm, and make no remote call until they do —
   never fall back to branch or session content. Add the other kind of record
   only when the selected one links to it; do not borrow unrelated branch data.
2. **Current branch.** With nothing named, look for records the branch can be
   shown to belong to. A branch name such as `feature/<change-id>` only suggests
   a Change; confirm `openspec/changes/<id>/` (or `openspec list --json`). Find
   Work Items by reading `work-items/WI-*/README.md` directly and following their
   links — Work Items are usually Git-ignored, so ignore-aware search tools miss
   them. Do not ask for a branch field to be added. A Change or Work Item whose
   name or links plausibly match the branch is a **candidate** even when the
   match cannot be proven; candidates are resolved by asking, not skipped.
3. **Session-only.** Only when there is no candidate at all, there are no
   records; the conversation is the whole source. If it does not identify a
   concrete subject, ask what to register.

**Conversation.** Always merge the relevant current-session discussion, whether
or not records were named. A decision the user confirmed in this session after
the record was written replaces the recorded one: if the Work Item says "retry
5 times" and the user has just confirmed 3, the Issue says 3. Ask only when you
cannot tell which statement is current, or when sources materially conflict and
nothing settles it. Suggestions nobody confirmed stay open questions.

Several plausible candidates: list them and ask before any remote call. Never
pick the newest or the first. Identifiers that are not confirmed are written
`null`; do not create local records to fill them. An update that names an Issue
follows that Issue's confirmed association rather than the current branch.

### Step 2 — Fix the target, the operation, and the authorization

1. Fix the full target — host, owner, and repository. Matching the host alone is
   not enough: a remote or a tool default that points at another repository on
   the same host is a different target. When the request and the local context
   disagree, stop and ask.
2. Confirm the operation and that the user authorized it. Choosing a tool never
   widens that authorization.

### Step 3 — Choose the tool and check what it can do

Pick `gh` or a configured GitHub MCP and check, in that tool's own context, that
it reaches the target and has the operation you need — Issue create for
`create`, comment create for `update` (body edit is never needed). Read whatever
permission information it offers, and use it only for what it actually covers:
being able to read a public repository, or holding a repository role, does not
prove this token or App can create Issues or comments. One tool's login is never
evidence that another tool can act.

- **Known blocker** — not signed in, wrong target, missing capability, or an
  explicit permission denial: stop and report it. A missing capability is not
  final when another configured tool has it: report the gap, then re-run this
  step for that tool within the same authorization.
- **Incomplete permission information, no known blocker** — go ahead with the
  authorized operation and judge it by the actual response. Never create a test
  Issue or comment just to find out whether you may.
- **Account restriction** — none by default. Only when the user or a trusted
  project rule names an account for this operation, check the account the tool
  actually uses; if it differs or cannot be shown, stop. Contract section 4.2.

Leave logins, tokens, and configuration alone; report authentication problems
for the user to fix. Nothing from credential configuration goes into output or
records.

## Operation: create

### Step 4 — Look for an existing association

Use an explicit Issue URL when one is known. Otherwise search the confirmed
repository with each **non-null** identifier, then **read each candidate's body
and comments** — a later comment may carry an association the body lacks:

```bash
gh issue list -R <host>/<owner>/<repo> --state all \
  --search '"<change-id or WI ID>" in:body,comments' --json number,title,url,state
gh issue view <number> -R <host>/<owner>/<repo> --json body,url,state,comments
```

A search hit or a similar title proves nothing; the identifiers in the stored
text do. Legacy Issues with `openspec-change:` and `repository:` inside managed
markers count as evidence too.

- **One confirmed Issue** — return its URL. Do not create another, do not
  rewrite it, and do not add a comment unless asked.
- **Conflicting identifiers** (one matches, another known one differs) or
  **several candidates** — list them and stop. Never pick the first.
- **None** — continue to Step 5. Mention any near-miss whose identifiers differed.
- **Session-only** — `null` equal to `null` is not a match and a similar title is
  not either. Reuse an Issue URL already known from this session; otherwise read
  recent related Issues, ask about a plausible but uncertain match, and create
  when there is none.

### Step 5 — Compose the body

Handoff and Author are the frame; the work description between them is the
point. Rewrite the material into one task someone could pick up with none of the
sources: what the problem is and whom it affects, what is in and out of scope,
the work to do, how to tell it is done, and what is still undecided — as far as
the material supports each. This is a content standard, not a list of required
headings: follow contract section 6.1 (Handoff first, Goal, other sections only
when they carry content, Author last). Do not keep the record's layout (Sessions,
coordinators, decision IDs, per-agent next actions), do not shorten an internal
list and paste it, and do not post bare IDs in place of an explanation. When the
source has a task plan (a Change's `tasks.md`), the Issue's Tasks are outcomes a
reviewer can check from what users or operators will see — not the plan's groups,
numbering, or implementation steps such as endpoints, jobs, storage, or a
test-by-test list. The plan stays in the Change; link it. Never
invent a decision, number, owner, or date the material does not contain.
Unpublished sources are repo-relative paths marked local-only — never invent a
commit link, and do not commit or push to obtain one. Author names the tool
posting now and the known current root-session model; when the model is
unknown, omit that line and say so in the report — do not take a model from the
source records. No absolute local paths, no hostname.

### Step 6 — Create, then verify

```bash
gh issue create -R <host>/<owner>/<repo> --title "<title>" --body-file <file>
gh issue view <number> -R <host>/<owner>/<repo> --json body,url
```

Read the Issue back by the number or URL the tool returned. Confirm it is in the
intended repository and the stored body is what you composed, then report the
URL. A denial is reported as a denial; nothing was created. If the readback
itself fails, report the returned number as created but unconfirmed and do not
create again.

If the create call times out or its result is unknown, go back to Step 4 and
look again before any retry, with either tool — a blind resend, or the same
request through the other tool, is how duplicates appear. Search can lag just
after a write, so on this second look also list recent Issues and compare the
body directly against what you prepared (and the author and time when the tool
shows them):

```bash
gh issue list -R <host>/<owner>/<repo> --state all --limit 50 --json number,url,body,author,createdAt
```

If it is still inconclusive, report that instead of retrying. A session-only
Issue has no stable key, so this check cannot promise exactly-once.

## Operation: update

### Step 4 — Find the Issue and read what is already there

Use the Issue the user names. Otherwise find it as in create Step 4 with the
selected sources; one confirmed Issue is the target, several or none means ask —
an update never turns into a create.

```bash
gh issue view <number> -R <host>/<owner>/<repo> --json body,url,state,comments
```

Read the body and the comments relevant to this work so the new comment does
not repeat the original goal or an update already posted. The body format does
not matter: handwritten text, legacy managed markers, and broken markers are all
left as they are, and none of them blocks the update.

### Step 5 — Compose one comment

Follow the update comment in contract section 6.1: Handoff, Changes, Author.
Handoff carries the Issue's confirmed association; add a newly confirmed
identifier only when it is the same work — this is how an association that
began as `null` is recorded, without touching the body. Changes says what is new
in this iteration and why it matters — decisions, progress, test results,
blockers, next steps, whichever apply. Author follows the same rule as create.

### Step 6 — Comment, then verify

```bash
gh issue comment <number> -R <host>/<owner>/<repo> --body-file <file>
gh api --hostname <host> repos/<owner>/<repo>/issues/comments/<comment-id> \
  --jq '{url: .html_url, issue: .issue_url, body: .body}'
```

Read back the comment by the URL or id the tool returned and confirm its
repository, parent Issue, and content; report the comment URL — not an Issue
creation. If the readback itself fails, report the returned comment URL as
posted but unconfirmed and do not comment again. If the call times out or the result is unknown, re-read the Issue's
comments and compare against what you prepared (author and time when shown)
before anything else; if that still does not settle it, report the uncertainty
instead of commenting again or switching tools.

## Reporting

Say what now exists remotely (Issue or comment URL), what was read but not
changed, and what is still open — for example a source that is still
local-only, or an omitted `AI-Assisted-By`. When one step succeeded and a later
one failed, report both. A simulated or replayed run is never reported as a real
write.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases for this skill:
source selection (Work Item, Change, both, branch, ambiguous, missing,
session-only), body content, duplicates and conflicts, comment updates on
handwritten and legacy Issues, associations added in comments, missing tools or
capabilities, denial, restriction mismatch, timeouts, failed readback, and
secrets. Worked bodies are in `references/examples.md`.
