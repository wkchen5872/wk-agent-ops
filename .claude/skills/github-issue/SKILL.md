---
name: github-issue
description: >
  Create, update, or close a GitHub Issue that explains a piece of work,
  in the team's shared Issue format, which this skill holds. The source can be an
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

This skill holds everything these operations need: the write checks, the
shared Handoff / Next actions / Author frame, and the layouts for the Issue body,
update comments, Checkpoints, and Closures. Take layouts from here rather than
from memory; [references/examples.md](references/examples.md) shows them filled
in.

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
a wrapper or adapter around either one. Local `git` reads the remote and branch.
If neither GitHub tool can do the operation, stop and report what is missing
instead of installing a tool or logging in. Each machine and each tool prepares
its own login; one login never vouches for another machine or tool. No identity
policy, check script, or pinned blob is needed; a leftover identity-check
script from an older install is not used, and deleting it is the user's call.

If the request does not say which operation is meant and the intent cannot tell
them apart, ask before doing anything.

## Shared steps

**Write checks.** Every write goes through the same six checks. They establish
that this is the operation the user wants, aimed at the right place, and that
the result really exists — not whose account it is.

1. Fix the full target (Step 2).
2. Fix the operation and the user's authorization (Step 2).
3. Choose one configured tool and confirm it can do this operation (Step 3).
4. Stop on a known blocker (Step 3).
5. Read the result back by the URL or number the tool returned, and confirm it
   before calling the step done (each operation's verify step).
6. On a timeout or an unknown result, look up the actual state first; do not
   resend, and do not resend through another tool, until it is settled.

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
   widens that authorization. Authorization comes from the user's instruction,
   never from an account: being able to write the repository does not mean the
   user asked for this write.

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
- **Account restriction** — none by default: any configured, authorized account
  will do, and API and Git identities may differ. Only when the user in this
  task, or a trusted project rule (for example explicit text in `AGENTS.md` on
  the default branch), names an account for this operation, check the account
  the tool actually uses in that operation's own context. If it differs or
  cannot be shown, stop and report the restriction and the missing evidence.
  Never switch accounts or write a credential parser to pass. A rule that only a
  candidate PR changes does not loosen an existing restriction; following it
  needs the user's separate authorization.

Leave logins, tokens, and configuration alone: do not parse credential helpers,
tokens, or SSH keys, never ask Git's credential helpers for secrets, and report authentication
problems for the user to fix. When you record a tool, account, or failure, keep
to non-secret metadata — the account the tool reports and where it came from, or
`unavailable` — and never borrow another tool's login as evidence. Nothing from
credential configuration goes into output, reports, or Issues.

<!-- shared-frame:start — keep identical in github-issue and github-pr -->
### Every post — Handoff, Next actions, Author

Every new Issue body, Issue comment, PR description, and PR reply contains, in
order:

1. **Handoff** first — which work this post belongs to.
2. **The body for its purpose** — Goal, Changes, Review, Checkpoint, Closure,
   and so on.
3. **Next actions** — what can happen next.
4. **Author** last — the posting tool, model, and sessions when an Agent takes
   part.

Write only what you have read and checked. Never create a Work Item, Change,
branch, Issue, or PR to fill a field, and leave out empty sections. Placeholders
in the layouts below are in angle brackets; drop a section that does not apply
and an optional value that is unknown.

**Handoff**

```markdown
## Handoff

- issue: <已確認的 Issue URL>
- pull-request: <已確認的 PR URL>
- branch: <已核對的 branch；fork 時寫 <head-owner>:<branch>>
- openspec-change: <已確認的 Change ID>
- work-item: <已確認的 Work Item ID>（local-only）
- depends-on: <依賴的 Issue／PR URL>（<解除條件>）
```

- List only confirmed associations that matter to this post; leave unknown
  optional ones out. A PR description always has `branch`, and a fork keeps the
  head owner. With no association at all, one sentence says so (for example
  「目前尚無 Change、branch 或 PR 關聯。」) — never a `null` placeholder.
- Prefer verified remote URLs. A Work Item is always marked `（local-only）`: it
  exists only where it was written, so the post must be understandable without
  it, and the same work can be picked up from another environment's local record.
- Keep the work this post handles directly, reference-only links
  (`references`), and dependencies (`depends-on`, with the condition that
  releases them) apart. Never write `Closes` or `Fixes`; use `Refs #N` when a
  reference is needed. Commit trailers use `Refs: #N` too; the step that makes
  the commit states how they are formatted.
- Older posts with `null` fields (such as `- work-item: null`) or managed blocks
  stay readable as "not confirmed at the time" and are not migrated; new posts
  never write `null` placeholders.

**Next actions**

```markdown
## Next actions

<下一步：誰（已知時）做什麼，完成或解除的條件>
```

- Say what can happen next, with the owner and the done or release condition
  when the material gives them.
- Nothing left: say so (for example 「原範圍內無後續動作」). Waiting on someone:
  say what for.
- No owner or next step in the material: say what needs confirming. Never invent
  an owner, a deadline, or a date.

**Author**

```markdown
## Author

Co-Authored-By: <本次發布的工具>
AI-Assisted-By: <已知的當下 root-session model>
SESSION-ID: <本次原生 Session ID｜null>
XIRP-SESSION-ID: <本次 Xirp 管理 Session ID｜null>
```

- Author has only these four fields: no mode or human line, and no synonym such
  as `mode` or a publisher account — the tool and model show where help came
  from, and GitHub shows the posting account. Never infer the delegating person
  from the API account. Issue and PR posts record no role, machine alias, time,
  or revision, and do not accumulate earlier rounds' provenance.
- Content a human writes and posts directly, with no Agent involved, has
  no Author section and no Agent fields; Handoff, the body, and Next actions
  stay.
  Content an Agent composes or posts — even at a human's request — carries the
  posting Agent's Author. When an Agent only checked the format of text a human
  wrote and posted, it is still a human-direct post.
- The fields describe **this** posting session — never the previous reply, a
  source record, or another Agent:
  - `Co-Authored-By` — the tool posting now, name only, with no provider email
    (commit-trailer email rules do not apply here).
  - `AI-Assisted-By` — the model the current root session knows, at the
    precision it is known. Unknown: omit the line and say so in your report;
    never guess it from source records, environment variables, or another Agent.
  - `SESSION-ID` — the native ID the current tool's runtime exposes for this
    session (for example `CLAUDE_CODE_SESSION_ID` in Claude Code, or
    `CODEX_THREAD_ID`／`CODEX_SESSION_ID` in Codex).
  - `XIRP-SESSION-ID` — this session's Xirp management ID, from the runtime (on
    this kind of setup `CHIRP_SESSION_ID`) or the configured local session tool.
    Do not assume an `XIRP_SESSION_ID` variable exists.
  - Both Session fields always appear when an Agent posts. Always
    look up both IDs before writing either one as `null`, reading only those
    keys — never dump the environment, the transcript, or anything
    credential-like. A value that cannot be tied to
    this posting session, or is absent, unregistered, or explicitly withheld, is
    `null` in its own field with the reason in your report; the other field is
    unaffected and the post goes ahead. Never copy one ID into the other field,
    never write a local alias as an ID, and never ask the user to copy one by
    hand.
- **Relayed report.** Posting a review or implementation report someone else
  wrote adds a first line `原報告作者: @<作者>，來源為 <已核對的報告連結，或標明
  local-only 的紀錄>`, with the original author's explicitly provided, publishable
  tool, model, and Session in parentheses on the same line (for example `（工具
  <工具>，模型 <模型>；未提供 Session ID）`). The four fields below it are still
  this posting session. A relay is recognized by `原報告作者` and its source
  alone. The body must let a reader understand the result without unreadable
  local paths. A summary combining several sources does not claim one author
  did it all; it links each source under References. A later notification to the
  original author (for example asking the implementer to fix) goes to
  `原報告作者` and its verified source, never to the relaying publisher; when the
  original author cannot be verified, return a transferable message instead.
- Never write absolute local paths, hostnames, credentials, or invented provider
  emails. Session IDs are lookup hints: verify the tool, project, and native ID
  mapping before notifying or taking over.
- Older Authors stay readable with the source and namespace they state: `方式`
  (including `Agent 協助代發`) and `人類` lines, only `Co-Authored-By`／
  `AI-Assisted-By`, only `SESSION-ID`, or `SESSION-ID: <id> (xirp)` for a
  management ID. They are never rewritten, and new posts never output the
  removed lines. An old `方式: Agent 協助代發` shows only that a relay happened;
  it does not prove the original author's Session.
<!-- shared-frame:end -->

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
headings. The body uses this layout:

```markdown
## Handoff

- openspec-change: <已確認的 Change ID>
- branch: <已確認的 branch>
- pull-request: <已確認的 PR URL>
- work-item: <已確認的 Work Item ID>（local-only）

## Goal

<問題、理解它所需的背景、影響對象，以及預期結果與範圍>

## Acceptance criteria

- <從使用者或維運者看得到的完成條件>

## References

- <有用的連結，或標明 local-only／尚未發布的 repo-relative 路徑>

## Next actions

<下一步與負責方>

## Author

Co-Authored-By: <本次發布的工具>
AI-Assisted-By: <已知的當下 root-session model>
SESSION-ID: <本次原生 Session ID｜null>
XIRP-SESSION-ID: <本次 Xirp 管理 Session ID｜null>
```

Handoff, Goal, and Next actions are always there; Author comes last when an
Agent posts and is left out of a human-direct post. Acceptance criteria hold
the completion conditions the material supports, under a more fitting heading if
there is one. References, Open questions, and Dependencies stay only when they
carry content. The title says what the work is for; no Change ID prefix is
required. A preliminary problem with no Change or branch says so in one Handoff
sentence. A Checkpoint section is added only when the Issue is opened to hand
over a current state. Do not keep the record's layout (Sessions,
coordinators, decision IDs, per-agent next actions), do not shorten an internal
list and paste it, and do not post bare IDs in place of an explanation. When the
source has a task plan (a Change's `tasks.md`), the Issue's Tasks are outcomes a
reviewer can check from what users or operators will see — not the plan's groups,
numbering, or implementation steps such as endpoints, jobs, storage, or a
test-by-test list. The plan stays in the Change; link it. Never
invent a decision, number, owner, or date the material does not contain.
Implementation, verification, deployment, and acceptance status are written
separately. A dependency states its release condition (which Issue or PR must be
approved, merged, deployed, or accepted), not just another work's name. Work
that waits for real data states the data window needed, the evidence, the owner,
and the next step; a date arriving, a review pass, or a merged PR is not
acceptance and does not close the Issue.
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

Use the update comment layout:

```markdown
## Handoff

- issue: <Issue URL>
- openspec-change: <已確認的 Change ID>
- pull-request: <已確認的 PR URL>

## Changes

<這一輪改變了什麼、為什麼重要>

## Next actions

<下一步與負責方>

## Author

Co-Authored-By: <本次發布的工具>
AI-Assisted-By: <已知的當下 root-session model>
SESSION-ID: <本次原生 Session ID｜null>
XIRP-SESSION-ID: <本次 Xirp 管理 Session ID｜null>
```

 Handoff carries the Issue's confirmed association; add a newly
confirmed association only when it is the same work — this is how an
association that began unknown is recorded, without touching the body. Changes
says what is new in this iteration and why it matters — decisions, progress,
test results, blockers, whichever apply — not the original goal again.

When the work pauses, changes hands, or many rounds need consolidating, write a
**Checkpoint** instead. Everyday progress stays a short Changes comment; a full
summary is never forced.

```markdown
## Handoff

- issue: <Issue URL>
- pull-request: <PR URL>
- openspec-change: <已確認的 Change ID>

## Checkpoint

### Current state
<目前狀態與已發布版本；尚未 push 的實作寫明無法從遠端取得>

### Confirmed decisions
<已確認的決策，或 Confirmed results：已確認的結果與證據連結>

### Open questions
<未決事項與阻礙；沒有就寫明原範圍內無未決事項>

## Next actions

<接手者先做什麼，以及之後由誰做什麼>

## Author

<依共用外框>
```

- Pick subheadings by content: `Confirmed decisions` and `Confirmed results` may
  both appear or either one; blockers may go under `Blockers`. The version is a
  published commit or an explicit "not yet published", and evidence links point
  to published comments, verification documents, or specs.
- Link the formal spec and tasks rather than copying them, do not repost every
  round's findings, and do not dump local logs.
- **Whoever reads a Checkpoint** checks the events after it and the current
  head or state: a newer fix, decision, or review replaces what the summary
  said, and "the latest Checkpoint" does not prove it is still current.
- When several Checkpoints disagree about the same state, show the difference
  and agree on one person to consolidate; do not settle it silently by time,
  and do not claim that reading before writing gives you a lock.

A request to reply to an Issue is this same append-only comment.

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

Compose it with this layout:

```markdown
## Handoff

- issue: <Issue URL>
- pull-request: <PR URL>
- openspec-change: <已確認的 Change ID>

## Closure

### Outcome
<預期的結果：準備以 completed／not planned 關閉、被取代等>

### Result
<交付或取消的範圍>

### Acceptance
<驗收的依據與證據連結>

### Remaining work
<原範圍內未完成的事項與追蹤位置；沒有就寫明>

## Next actions

<結案後由誰接續什麼>

## Author

<依共用外框>
```

The Outcome says what is about to happen ("準備以 completed 關閉"), never that a
close, deployment, or acceptance not yet performed already happened. A
completed Issue needs acceptance evidence for its original scope; a
cancellation states the reason and where any replacement work lives.

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

## References

- Read [references/examples.md](references/examples.md) when writing a kind of body or comment you have not
  written in this session, or for a human author, missing Agent metadata, a
  relayed report, or a legacy Issue: it follows one piece of work from create
  through progress, Checkpoint, and closure.
