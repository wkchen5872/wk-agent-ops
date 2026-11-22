---
name: change-review
description: >
  Review, accept, and test an OpenSpec change in one bounded round, starting
  from a Change name, a GitHub Issue (URL or #N), or a PR. It resolves the
  Change and any PR, fixes the exact version under review, runs the mandatory
  openspec-verify-change plus any suitable installed quality review and the
  project's required tests, and reports the result. With a confirmed PR it
  appends the review — pass, changes-required, or blocked — through github-pr
  reply and reads it back, and hands a needed repair to the verified local
  implementer session; without a PR, when the PR lookup is unknown, or when the
  user asks for local-only, it returns and saves a local report with a content
  fingerprint, hands it to an implementer only on explicit request, and can
  later post it to a PR only after comparing versions. Use whenever the user asks to review,
  accept, verify, or re-review a change, an Issue, or a PR — for example
  "review PR #12", "驗收 add-export", "驗收 #7", "幫我審查這個 change",
  "設計審查", "複審新版本", "看一下修正好了沒".
license: MIT
compatibility: "Requires git, the openspec-verify-change skill, and either GitHub CLI (gh) or a GitHub MCP when a PR is involved. Optional: openspec CLI, ponytail-review, code-review, a local session tool such as xirp."
metadata:
  author: wkchen
  version: "3.2"
---

# Change Review

One invocation is one review round of one OpenSpec Change. This skill keeps the
decisions — what to review, which version, which skills to run, what the result
means, where it goes — and hands the work to the tools that own it: checking to
`openspec-verify-change`, quality review skills, and the project's tests;
posting to `github-pr reply`; delivery to the local session tool.

Reports use the review identity rules in Step 4 and the review reply layout of
`github-pr`, which also performs the write checks when a report is posted.
Whether implementation may start is decided by `docs/openspec-workflow.md`, not
by this skill.
Open [the review round](references/review-loop.svg) when you need the whole flow at a glance.

## Inputs

| Input | Required | Meaning |
|---|---|---|
| target | yes | a Change name, a GitHub Issue URL or `#N`, or a PR URL／`owner/repo#number` |
| purpose | no | implementation acceptance by default; design review when the request says so |
| expected-head | no | the commit the caller wants reviewed; must match the PR |
| previous report | no | report URL for a re-review |
| local-only | no | the user asks for no GitHub post and no notification |

A phase argument is no longer required: read the purpose from the request.
Ask only when the purpose would change the result and cannot be told. Each
tool passes these inputs its own way.

## What this skill never does

It does not change the reviewed product, stage, commit, push, merge, archive,
close an Issue or a PR, or switch Draft/Ready. Of the `github-pr` operations it
uses only reply — never the create／update／close paths, and it keeps no review
index in the PR description. It does not create an Issue, PR, or Work Item to
make a review possible, overwrite anyone else's report, upload a transcript or a
Work Item, start a second writer, or poll. GitHub calls go through `gh` or a
configured GitHub MCP, and their authentication stays theirs.

## Inside a handoff loop

A Change has an active handoff loop when `.agent-handoff/<change-id>/loop.yaml` exists in a
worktree of the repository (see the `agent-handoff` skill). Inside a loop these rules replace
the matching parts of the steps below; without a loop, nothing below changes.

- **Implementation-round review.** Bind the round to the `head` of the
  newest implement record. Records are written where each role works: when the
  review runs in its own worktree, read the implement records in the
  implementer worktree named by `implementer.worktree` in `loop.yaml`; the head
  in the reviewer's prompt names the same commit. Before checking, confirm that this worktree's `HEAD` equals that commit and that
  it has no uncommitted non-ignored changes; otherwise the result is `blocked`, with both
  commits or the dirty paths as evidence. A clean worktree at that commit is the fixed
  version: no file snapshot is needed.
- **Final-version review.** When `openspec-commit` calls this skill during PR delivery, it
  passes the delivered head. Review that head, do not apply the implement-record pin, and
  return the verdict and evidence to the caller: a final-version review does not write a handoff record.
- **End of an implementation round.** After the report is saved and, with a confirmed PR,
  after its publication state is known, record the result with the `agent-handoff` skill
  (`handoff-write --role review`, the verdict, the reviewed `head`, and the saved local
  report path). Do not discover, verify, or message the implementer: the handoff hook routes
  the record, so Step 6 is skipped.
- **Publication not confirmed.** If posting the report was denied, timed out, or did not
  read back, write `status: blocked`, keep the technical verdict, and state the publication
  state in the note. Do not resend blindly, try another tool after a denial, or turn the
  failure into a local handoff.
- **Local-only and notification exclusions.** Starting a loop does not override this
  round's instructions. A local-only review, or one where the user excluded notification,
  saves the report locally and writes `status: blocked` with the reason in the note.
  Local-only together with a request to hand the result over is a conflict: report it and
  write `status: blocked` until the user resolves it. Only an explicit instruction to
  skip GitHub but hand the result to the implementer writes `status: done` with the local
  report path.
  The loop prompt's instruction not to message the implementer yourself is the hook's routing,
  and it is not a notification exclusion: it never turns a finished review into `status: blocked`.

- **Delegated PR reply.** With a confirmed PR, the reply may be delegated to the
  `github-pr-agent` within this round. Pass the full repository and PR target, the report
  path, the Review-ID, the reviewed version, and your own tool, model, native session ID,
  and Xirp session ID; the Author's four fields stay yours, and the agent adds its own `Posted-By`
  line last. The readback rules of Step 5 apply
  unchanged.

## Step 1 — Resolve the target

- **Change name** — read `openspec/changes/<id>/` (or its archive and the
  matching specs). Then look for its PR through confirmed links and a PR list
  for the related branch.
- **Issue URL or `#N`** — fix host, owner, and repository first; a bare `#N`
  takes the repository of the confirmed remote, and an unclear repository is
  asked about. Read the Issue body and relevant comments for the Change and the
  PR.
- **PR** — read its base, head, head repository and owner, and its links to the
  Change and Issue.

Confirm links from their content — Handoff fields, explicit links, the PR's
files, the branch — never from a title or a same-named branch alone. Several
plausible Changes or PRs: list them and ask; never pick one. When the PR's
files carry more than one Change, a link reached only through the Issue does not
select one — ask. An Issue with no
resolvable Change: say that the OpenSpec acceptance cannot run, then clarify or
report `blocked`. A Work Item is optional material; a missing one never stops
the review. Record the PR result as one of: a confirmed PR, confirmed **no
PR**, or **unknown** (the lookup failed). Unknown is not no PR.

## Step 2 — Fix the version under review

**With a PR.** Read the diff, the description, and the implementation, repair,
and review comments. The head read now is the reviewed head; an
**expected-head** that differs stops the round with the mismatch reported. Get a
checkout at the reviewed head — the current one only if it matches and is clean;
otherwise an isolated context such as a fresh clone in a temp directory. Never
stash, reset, discard, or commit anyone's work to get there. If no safe matching
checkout is possible, limit or block the conclusion. An expected-head mismatch is
reported back to the caller only — never posted to the PR and never notified. Local work that is not in
the PR head never counts toward its result. When the PR carries other Changes,
review only the selected one and its real dependencies.

**Without a PR, or PR unknown.** Review the **local version** and fix it as a
snapshot before the checks:

- the comparison baseline (`HEAD`, or the base the work starts from);
- the included paths — staged, unstaged, and untracked — from
  `git status --porcelain=v1 --untracked-files=all`, limited to this Change's
  work, and the excluded paths named explicitly (other Changes, other agents'
  files, ignored records);
- a fingerprint of every included file and the algorithm, for example SHA-256
  per file plus one digest over the sorted list of `path NUL sha256 LF` lines.
  Hash the working-tree content — what the checks actually run against — and
  note a path that is both staged and further edited.

Say plainly that this is a local review and proves nothing about any remote
version. Before the report is finished, take the fingerprints again: if any
included content moved during the round, the report names the snapshot actually
checked and what changed, and the moved content is not declared passed. A
check that may have read the content while it changed does not count: re-run it
on a fixed snapshot, or report the affected part as `blocked`.

**Skill source.** If this skill or the `github-pr` skill it posts through is
uncommitted, record the files with a fingerprint and keep that apart from the
reviewed content. A dirty skill checkout never vouches for another head.

**Announce before checking.** In two or three lines, before the required
checks: the Change, the purpose, the version fixed above, the PR state —
confirmed PR, confirmed no PR, or unknown — and where the report will go (a
reply on the confirmed PR, or a saved local report). Unknown is stated as
unknown, never as "no PR". This is a status line, not an approval gate: when
the target and authorization are already clear, carry on without waiting;
ask only about a real ambiguity.

## Step 3 — Run the checks

**openspec-verify-change is mandatory.** Actually invoke it on the resolved
Change through the host's skill mechanism — `/openspec-verify-change` in Claude
Code, `$openspec-verify-change` in Codex, the installed skill in Antigravity —
and keep its original grading. Listing the command is not running it. If it is
not installed or the Change artifacts cannot be read, the acceptance is
`blocked` with that prerequisite named; do not copy its steps and call them a
verification, and do not install it.

**Quality reviews are optional.** Run the installed ones that fit the target,
for example `/code-review:code-review` or `/ponytail:ponytail-review` in Claude
Code and `$ponytail:ponytail-review` in Codex, and record them separately. A
missing one is reported as not executed and blocks nothing; a PR-only review is
not forced onto a no-PR target.

**Project tests.** Run the checks the project requires, in the checkout from
Step 2. A required check that cannot run is reported as not executed with what
is missing.

**Purpose.** Implementation acceptance compares the implementation and tests
with every requirement and scenario. For an explicit design review, keep the
verifier's grading as it is and explain which items — open implementation
tasks, missing code — are outside a design verdict; a design `pass` is neither
human approval nor permission to Apply.
Read [references/checklists.md](references/checklists.md) before deciding the result: it lists only what the
invoked skills do not cover.

Whether implementation is authorized is judged by `docs/openspec-workflow.md`: an
explicit user instruction covering the Change and its design revision — given
directly or through a traceable handoff, with or without a published event —
authorizes Apply. A published approval record is read and compared as
`github-pr`'s `references/approval-records.md` describes. A
date-only `approved_at` is an accepted precision, and an unknown human
identifier is simply omitted. A technical `pass`, repository access, or a
self-declared recorder never authorizes Apply, and no recorder qualification is
checked. None of this stops the review itself.

## Step 4 — Decide the result and write the report

On a first round, form your own view before reading other reviewers'
unconfirmed reports; on a re-review, start from the previous findings and the
implementer's per-finding replies.

- `pass` — sufficient evidence for this scope and version, no blocking finding.
- `changes-required` — a demonstrated defect, security or data risk, or unmet
  requirement.
- `blocked` — a required check or piece of evidence cannot be obtained, or the
  same dispute returns with no new evidence.

Style and out-of-scope ideas are non-blocking suggestions.

<!-- review-identity:start — keep identical in github-pr and change-review -->
**Review identity and finding states**

- The verdict (`result`) is `pass`, `changes-required`, or `blocked`. The phase
  is `design` or `implementation`; a review not marked 「設計審查」 is an
  implementation review. Neither is a GitHub event type.
- `review-id` is assigned before posting, as `<reviewer-session-alias>-rNN`, and
  is unique within the PR. It is not a native Session ID and is never derived
  from a report URL that does not exist yet; the URL is added after posting.
- A finding is `<origin-review-id>/F-NN`. Later rounds keep the original ID and
  never renumber it.
- Finding states: `Open` — not yet confirmed; `Accepted` — the problem is real
  and not yet fixed; `Rejected` — evidence shows it does not hold; `Resolved` —
  the reviewer has verified the fix or handling. An implementer's "fixed" is
  not Resolved.
- The review itself, its posting, and any notification are recorded
  separately. A `blocked` result is posted too when authorized; an unknown
  account, version, or tool, or a failed send, is stated as a limit.
<!-- review-identity:end -->

A fix the implementer claims stays Accepted until you verify the fixing revision
and the affected behavior; only that evidence makes it Resolved. An Accepted
required finding that is not yet handled is linked to the corresponding OpenSpec task
or the project's formal risk record, with the PR evidence link; a detailed PR
report never replaces the formal to-do or marks the work done. Optional
suggestions need no task.

**Final-version review.** When a new head follows an earlier pass only because
of archive, spec synchronization, or documentation updates, compare it with the
reviewed head first (`git diff --stat -M <reviewed-head> <new-head>`). Narrow the
review only when that difference is shown to be limited to archive moves, spec synchronization,
and the matching documentation, and report that evidence. Any semantic change in it — code
or script behavior — gets the necessary tests and a full review of that change,
listing the checks actually rerun. The earlier pass stays bound to its own head
and never covers the new one.

Write the report as the review reply of `github-pr` (its "Reply layouts"),
inside its shared Handoff / Next actions / Author frame: Handoff (the PR and branch, or the Change for a local
review), Review with the reviewed version (PR head, or local `HEAD` plus
included paths), purpose, Review-ID, and verdict, then each finding under its
stable ID as an actionable item a reader without the local records understands
(impact, location or evidence, how to tell it is fixed); Verification with the
checks actually run, their results, and what was not executed; Next actions
saying who acts next and on what condition; Author last. No findings means no
filler items. Author follows `github-pr`'s shared frame for this reviewer session,
including `SESSION-ID` and `XIRP-SESSION-ID`; never write an alias as either
ID, and never copy the implementer's IDs into the reviewer's Author.

Read [references/examples.md](references/examples.md) before writing a full report when you have not written that kind in this session:
it holds one complete report each for no PR, `changes-required` with its
repair notification, `blocked` with a transferable message, and `pass`.

Before any post, read the PR head again. If it moved, keep the report bound to
the reviewed head, mark it **stale**, and say the new head needs its own round.
Stale is a note, not a fourth verdict: the result stays `pass`,
`changes-required`, or `blocked` for the reviewed head, and the report is still
posted under Step 5.

## Step 5 — Where the result goes

- **No PR, PR unknown, or local-only** — the report is returned directly. An
  unknown PR is never treated as permission to post somewhere. Save it under
  the local record rules of `work-items/AGENTS.md` (section 9): in this
  directory's Work Item for the same work when one exists; when none exists,
  record it as those rules allow — a missing Work Item never stops the review,
  and a record created to hold the report is never a precondition for it.
  The file is `<agent>-<session>-rNN.md`; a new round is a new file, and the
  workflow never overwrites another reviewer's report, never restores records
  from another worktree, and keeps no other registry. The saved report carries
  the snapshot from Step 2 so a later reader can check the bytes reviewed.
- **A confirmed PR with any verdict** — `pass`, `changes-required`, or
  `blocked`: invoking this workflow authorizes posting the report through
  `github-pr reply`, unless the user asked for **local-only** or another explicit
  restriction excludes it. A posted pass never notifies anyone to "fix". Then
  **回讀** the stored comment: parent PR, repository,
  reviewed head, Review-ID, and full content, and note its URL. Only a match is
  a confirmed publication. A denial, a timeout, or a failed or mismatched
  readback is recorded as publication 「可能已發布／尚未確認」 or failed —
  separately from the technical verdict — reconciled by listing the PR's
  comments before any retry, never resent blindly, and never through another
  tool after a denial. No notification goes out for an unconfirmed report.

**Later publication of a local report.** Creating a PR never publishes a
saved report. When the user later asks to post one, read the report and the
confirmed PR, then compare: recompute the snapshot's fingerprints at the PR
head for the same paths (`git show <head>:<path>`), and look for anything the
PR adds beyond them. A matching name or branch proves nothing.

- **Same content** — post through `github-pr reply` and read it back, keeping
  the original review-id and findings, with `reviewed-head` set to the PR head
  and the original baseline and snapshot digest stated as what was actually
  reviewed. Author is the posting session (`github-pr`'s shared frame); when a session
  other than the original reviewer posts, it uses the relayed form with
  `原報告作者` pointing at the saved report.
- **Different content** — name the difference. A verdict for the current head
  needs a new round, with the original finding IDs carried forward;
  a local result never inherits to a different head. Only an explicit request to post
  the historical report posts it, labeled with its original scope and
  snapshot — its `reviewed-head` names the local baseline and says it is not
  the PR head — and never as the current head's verdict.
- **Snapshot unavailable or not comparable** — report the limit; the old report
  does not attest the current head.

Use a platform APPROVE or REQUEST_CHANGES only on a separate explicit request
when the account may; an Agent verdict is not a platform approval. Older COMMENT
reviews remain readable history.

## Step 6 — Hand off to the implementer

Inside a handoff loop this step is skipped; see "Inside a handoff loop".

With a PR: only after a confirmed `changes-required` or `blocked` reply,
unless the user excluded notification, and only when the result asks the
implementer to act. A pass never sends a repair notification. A `blocked`
caused by the reviewer's side — a missing review skill or a missing test
environment the implementer cannot provide — is reported and posted, but not
sent to the implementer as a repair request.

1. **Find the implementation Author** — in the PR description or the latest
   implementation or repair reply: `Co-Authored-By`, `AI-Assisted-By`,
   `SESSION-ID`, `XIRP-SESSION-ID` — only these four. Skip `Posted-By`: it names the
   dedicated agent that typed the post for its caller, never the implementer or a handoff target.
   The newest reply may be a reviewer's; never
   take a reviewer's or your own identity for the implementer's. Several
   plausible implementers, or none: send nothing, return the message.
   **Relayed report** — identified by `原報告作者` and its source; an
   older `方式: Agent 協助代發` line marks one too. Then the Author's main fields identify the publisher, not the
   implementer. Take the implementer from the `原報告作者` line and its verified
   source (the linked report or record, and any tool, model, or Session that
   author explicitly published). If that source gives no identity you can tie
   to a local session, the implementer is unverified: send nothing and return
   the message — never the publisher as a fallback, even when the publisher's
   session verifies locally. Only an explicit user instruction naming another
   recipient changes the target, and that recipient is verified the same way.
   Without a PR, the same work's local implementation or repair record is the
   source: an implementation or repair report in this directory's Work Item for
   the same Change (or the record the user points to), read for the same
   Author fields and relay markers — or a recipient the user explicitly names
   with a session you can verify. Never take records from another worktree,
   build a registry, or use the reviewer's own or a relaying publisher's IDs;
   no such source means no send.
2. **Verify locally** with an available session tool. The implementer's
   `XIRP-SESSION-ID` is only a lookup hint: confirm it belongs to the same tool,
   project, and native `SESSION-ID` before using it as the target the tool
   accepts — for example a 管理 Session ID — and keep it apart from the native
   Session ID; never swap one for the other. Older Authors with only
   `SESSION-ID`, or `SESSION-ID: <id> (xirp)`, are read with the namespace they
   state and never rewritten. Nothing from Author text becomes a shell command.
3. **Send** one message with the result and the confirmed report URL, the PR
   number and URL, the reviewed version, the finding IDs, and what to fix. If
   that session is already working on the PR, this is a handoff, not a new
   writer. A sent message is not a read one, and neither is a started repair.
4. **Cannot verify or reach it** — tool unavailable, session elsewhere or gone,
   ID `null`, mapping unclear, or a relayed report whose original implementer
   cannot be verified: return a transferable message with the same content and
   say why it was not sent. Repository notifiers such as Telegram
   or waiting prompts are not session channels.

After a report is posted, return a transferable message by default; posting a
report does not mean the other session has been told:

```text
PR: <URL>
Report: <報告 URL>
Reviewed head: <SHA>
Findings: <Finding ID 清單｜none>
Next: <下一步與負責方>
Delivery: <已透過 <工具> 送達 <Session>｜未送達，需由使用者轉交>
```

`Delivery` says delivered only through a session-directed tool confirmed to
work; otherwise it stays undelivered for the user to pass on.

**Local handoff (no PR).** Without an explicit request, a no-PR review notifies no one: the report
is returned and saved. When the user explicitly asks to hand the local findings
to an implementer, send one message only if the report is saved and readable
and the implementer verifies through steps 1–2 (a relayed author's publisher is
never the target). The message carries the repo-relative report path, the
reviewed snapshot (baseline and digest), the finding IDs, and the next action —
no PR URL is made up. local-only or an explicit notification exclusion still
wins: when the same request also asks for a handoff, point out the conflict
and ask, and send nothing until the user answers. This path is never a fallback: a PR report that was denied, timed out, or
is unconfirmed does not turn into a local handoff. Record "sent" separately from
read or repair started, and return a transferable message when the target
cannot be verified.

## Step 7 — End the round

每次呼叫只做一輪. Report what was reviewed (target, Change, version, skill
source), the verdict, findings by ID, the checks run and not run, the
publication state (confirmed URL, unconfirmed, failed, or not posted), and the
delivery state (sent, returned for transfer, or not applicable). Then stop: no
polling, no automatic re-review, no repair. A re-review is a new invocation
after a new revision or new evidence; a new head never inherits an old pass,
and a repeated dispute with nothing new is `blocked` for human decision. A
replayed or simulated round is never reported as a real review, post, or
notification.

