---
name: github-issue
description: >
  Create, update, or close a GitHub Issue that explains a piece of work,
  following the project's shared handoff contract. The source can be an
  explicitly named Work Item, an OpenSpec Change, both, the records tied to the
  current branch, or — when none exist — the current session's discussion.
  Create writes a Handoff / Goal / Acceptance criteria / Next actions / Author
  body after checking for an existing Issue; update (also "reply to the issue")
  adds one progress or Checkpoint comment and never rewrites the body; close
  first posts and reads back a Closure summary, then closes only that Issue as
  completed or not planned. Every write checks the full repository target and
  authorization first and is read back. Works through gh or a configured GitHub
  MCP. Use whenever the user asks to open, register, link, update, reply to,
  hand off, or close a GitHub issue for a Work Item, a change, or the current
  work — for example "建立 issue", "開 issue", "更新 issue", "回覆 issue",
  "關閉 issue", "把這個 change 登錄到 GitHub", "用這個 WI 開 issue", or just
  "git issue".
license: MIT
compatibility: "Requires git and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "3.0"
---

# GitHub Issue

A thin entry for the Issue side of the GitHub handoff. The Issue explains the
work so someone who reads only GitHub understands the problem, scope, and
intended result; later iterations are kept as comments, and closing leaves a
Closure summary behind.

`docs/github-handoff.md` owns every template, field meaning, and rule. This
skill only sequences the work. **Read that contract first** — sections 3, 4, 5,
6 (the shared Handoff / Next actions / Author frame), 6.1, 6.6 and 6.7 — and take
the body and comment layouts from there rather than from memory.

## What this skill may change

| Operation | Needs | Side effect when authorized |
|---|---|---|
| `create` | A source (Work Item, Change, branch records, or the session), explicit repository | Creates one Issue, or returns the existing one |
| `update` | The Issue (URL, number, or a uniquely associated source), what changed | Adds one progress or Checkpoint comment to that Issue |
| `close` | The Issue, and the reason: completed with acceptance evidence, or cancelled | Adds one Closure comment, then closes only that Issue as completed or not planned |

A request to reply to an Issue is an `update`: one new comment, nothing else.
Only `close` changes state, and only the selected Issue's. The skill never edits
an Issue body, title, labels, or assignees, never edits or deletes comments,
never reopens anything, never touches a PR or another Issue, and never stages,
commits, pushes, or creates a Work Item, Change, branch, or PR. Those need their
own request.

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
pick the newest or the first. Identifiers that are not confirmed are left out of
Handoff; do not create local records to fill them. A Work Item is local-only:
mark it so, and never let the Issue depend on it to be understood. An update or
close that names an Issue follows that Issue's confirmed association rather than
the current branch.

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
`create`, comment create for `update`, comment create plus close with a state
reason for `close` (body edit is never needed). Read whatever
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

### Every post — Handoff, Next actions, Author

Every body and comment uses the shared frame of contract section 6: Handoff
first, the content for its purpose, Next actions, Author last.

- **Handoff** lists only confirmed associations — Issue, PR, branch, Change, and
  a Work Item marked `（local-only）`. Unknown ones are left out; with none at
  all, one sentence says so. Legacy `null` fields in older Issues stay readable.
- **Next actions** says what can happen next, with the owner and the done or
  release condition when the material gives them. Nothing left: say so. Owner
  or step unknown: say what needs confirming — never invent an assignee or date.
- **Author** describes the posting Agent. Content a human writes and posts
  directly, with no Agent involved, has no Author section at all. When you post —
  even content the user dictated — write the tool posting now, the known current
  root-session model, `SESSION-ID`, and `XIRP-SESSION-ID`, and nothing else: no
  mode line, no human-account line, no synonym for either, and never an identity
  inferred from the API account. Look up both IDs before writing either one as
  `null`:
  - `SESSION-ID` — the native ID the current tool's runtime exposes for this
    session (for example `CLAUDE_CODE_SESSION_ID` in Claude Code, or
    `CODEX_THREAD_ID`／`CODEX_SESSION_ID` in Codex).
  - `XIRP-SESSION-ID` — the Xirp management ID for this session, from the
    runtime (on this kind of setup `CHIRP_SESSION_ID`) or the configured local
    session tool. Do not assume an `XIRP_SESSION_ID` variable exists.

  Read only those keys — never dump the environment, the transcript, or anything
  credential-like. A value that cannot be tied to this posting session, or that
  is absent or withheld, is `null` in its own field with the reason in your
  report; the other field is unaffected and the post goes ahead. Never copy one
  ID into the other field, or take an ID or a model from a source record or
  another agent. An unknown model is omitted and reported. Posting someone
  else's report adds `原報告作者` with the verified source link above your own
  fields (contract section 6). No absolute local paths, no hostname.

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
markers count as evidence too. A Work Item ID is only a **source hint**: when the
Change and the scope match, a different Work Item ID is not a conflict — the same
work can be picked up from another environment's local record; and the same
Work Item ID on unrelated work proves nothing and authorizes no write.

- **One confirmed Issue** — return its URL. Do not create another, do not
  rewrite it, and do not add a comment unless asked.
- **Conflicting identifiers** (the confirmed Change, branch, or scope differs)
  or **several candidates** — list them and stop. Never pick the first.
- **None** — continue to Step 5. Mention any near-miss whose identifiers differed.
- **Session-only** — `null` equal to `null` is not a match and a similar title is
  not either. Reuse an Issue URL already known from this session; otherwise read
  recent related Issues, ask about a plausible but uncertain match, and create
  when there is none.

### Step 5 — Compose the body

Handoff, Next actions, and Author are the frame; the work description
between them is the point. Rewrite the material into one task someone could pick up with none of the
sources: what the problem is and whom it affects, what is in and out of scope,
the work to do, how to tell it is done, and what is still undecided — as far as
the material supports each. This is a content standard, not a list of required
headings: follow contract section 6.1 (Handoff first, Goal, Acceptance
criteria for the supported completion conditions, other sections only when they
carry content, Next actions, Author last). A Checkpoint section is added only
when the Issue is opened to hand over a current state. Do not keep the record's layout (Sessions,
coordinators, decision IDs, per-agent next actions), do not shorten an internal
list and paste it, and do not post bare IDs in place of an explanation. When the
source has a task plan (a Change's `tasks.md`), the Issue's Tasks are outcomes a
reviewer can check from what users or operators will see — not the plan's groups,
numbering, or implementation steps such as endpoints, jobs, storage, or a
test-by-test list. The plan stays in the Change; link it. Never
invent a decision, number, owner, or date the material does not contain.
Unpublished sources are repo-relative paths marked local-only — never invent a
commit link, and do not commit or push to obtain one. Author follows "Every
post" above.

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

Follow the update comment in contract section 6.1: Handoff, Changes, Next
actions, Author. Handoff carries the Issue's confirmed association; add a newly
confirmed association only when it is the same work — this is how an
association that began unknown is recorded, without touching the body. Changes
says what is new in this iteration and why it matters — decisions, progress,
test results, blockers, whichever apply — not the original goal again.

When the work pauses, changes hands, or many rounds need consolidating, write a
**Checkpoint** (contract section 6.6) instead: current state and published
version (or that the work is not yet pushed), confirmed decisions or results
with evidence links, open questions, and what the receiver does first. Link the
Change's tasks rather than copying them, and do not dump local logs. A request to
reply to an Issue is this same append-only comment.

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

## Operation: close

Close ends one selected Issue: post the Closure first, confirm it, then change
the state. It never closes, merges, or comments on a linked PR, a dependency, a
parent, or another Issue — those stay as they are.

### Step 4 — Read the Issue and fix the reason

```bash
gh issue view <number> -R <host>/<owner>/<repo> --json body,url,state,stateReason,comments
```

Read the latest body, comments, linked PRs, and state, and fix the reason from
evidence:

- **completed** — the original scope's required acceptance has evidence (test
  or review results, real-data checks, the user's confirmed acceptance). A
  merged PR, a review `pass`, or a date arriving is not acceptance by itself.
  Required acceptance still pending: do not close; report what is missing, and
  offer an `update` that says what is being waited for.
- **not planned** — the user cancelled the work or it was replaced. The Closure
  says why and where any remaining or replacement work lives.
- No evidence for either, or the request is unclear: ask.
- Already **CLOSED** — report the actual state and reason; do not reopen or
  close again. Post a missing Closure only when this request authorizes it.

### Step 5 — Post the Closure and read it back

Compose it from contract section 6.7: Handoff, Closure (Outcome, Result,
Acceptance or Verification, Remaining work), Next actions, Author. The Outcome
says what is about to happen ("準備以 completed 關閉"), never that it already did.

```bash
gh issue comment <number> -R <host>/<owner>/<repo> --body-file <file>
gh api --hostname <host> repos/<owner>/<repo>/issues/comments/<comment-id> \
  --jq '{url: .html_url, issue: .issue_url, body: .body}'
```

Confirm the repository, parent Issue, and content. If the comment timed out or
cannot be read back, list the Issue's comments and compare before anything
else; do not close on an unconfirmed summary, and do not post it twice.

### Step 6 — Close, then verify state and reason

Re-read the Issue first. If new comments or work arrived after the summary was
prepared, reconcile them — post a follow-up Closure that covers the difference,
or stop and ask — before closing.

```bash
gh issue close <number> -R <host>/<owner>/<repo> --reason completed
gh issue close <number> -R <host>/<owner>/<repo> --reason "not planned"
gh issue view <number> -R <host>/<owner>/<repo> --json state,stateReason,url
```

Use one of the two close commands; with an MCP, set the equivalent
`state_reason` (`completed` or `not_planned`). The readback must show `CLOSED`
with the intended `stateReason`. A closed Issue with the wrong reason is a
reason mismatch, reported as such — not success — and is not reopened; a comment
cannot fix the stored reason.

### Partial results and reruns

Report the Closure URL and the state change separately. Summary confirmed but
close denied or failed: keep the URL, report the Issue as still OPEN, and leave
the summary's "about to close" wording as it is. Close timed out: read the state
before any retry, and never resend through another tool while it is uncertain.
A rerun reads the comments and state first, reuses a confirmed Closure that
still covers the work, and does only what is missing.

## Reporting

Say what now exists remotely (Issue, comment, or Closure URL, and the read-back
state and reason after close), what was read but not changed, and what is still
open — for example a source that is still local-only, an omitted
`AI-Assisted-By`, or a Session ID written as `null` and why. When one step
succeeded and a later one failed, report both. A simulated or replayed run is
never reported as a real write.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases for this skill:
source selection (Work Item, Change, both, branch, ambiguous, missing,
session-only), body content, duplicates and conflicts, work identity across
local records, comment updates and replies on handwritten and legacy Issues,
Checkpoints, associations added in comments, close (completed, cancelled,
pending acceptance, already closed, reason mismatch, timeout, summary posted but
close failed), human and Agent Authors with missing metadata, missing tools or
capabilities, denial, restriction mismatch, timeouts, failed readback, and
secrets. Worked bodies are in `references/examples.md`.
