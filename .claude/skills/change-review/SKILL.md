---
name: change-review
description: >
  Review, accept, and test an OpenSpec change in one bounded round, starting
  from a Change name, a GitHub Issue (URL or #N), or a PR. It resolves the
  Change and any PR, fixes the exact version under review, runs the mandatory
  openspec-verify-change plus any suitable installed quality review and the
  project's required tests, and reports the result. With a PR that does not
  pass, it appends a review through github-pr reply, reads it back, and hands
  the repair to the verified local implementer session; without a PR, or on a
  pass, it returns the report directly. Use whenever the user asks to review,
  accept, verify, or re-review a change, an Issue, or a PR — for example
  "review PR #12", "驗收 add-export", "驗收 #7", "幫我審查這個 change",
  "設計審查", "複審新版本", "看一下修正好了沒".
license: MIT
compatibility: "Requires git, the openspec-verify-change skill, and either GitHub CLI (gh) or a GitHub MCP when a PR is involved. Optional: openspec CLI, ponytail-review, code-review, a local session tool such as xirp."
metadata:
  author: wkchen
  version: "2.0"
---

# Change Review

One invocation is one review round of one OpenSpec Change. This skill keeps the
decisions — what to review, which version, which skills to run, what the result
means, where it goes — and hands the work to the tools that own it: checking to
`openspec-verify-change`, quality review skills, and the project's tests;
posting to `github-pr reply`; delivery to the local session tool.

The reviewer reply template (section 6.2), finding identity (section 8),
write-time checks, and the design-approval rules live in
`docs/github-handoff.md`. **Read sections 3–10 of that contract first** and take
templates and fields from it. [The review round](references/review-loop.svg)
shows the whole flow.

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

**Without a PR, or PR unknown.** Review the **local version**: record `HEAD`,
the uncommitted paths included, and run the checks there. Say plainly that this
is a local review and proves nothing about any remote version.

**Skill source.** If this skill or the contract you are following is
uncommitted, record the files with a fingerprint and keep that apart from the
reviewed content. A dirty skill checkout never vouches for another head.

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
human approval nor permission to Apply. The checklist in
[references/checklists.md](references/checklists.md) lists only what the
invoked skills do not cover.

Approval records are judged by the contract (section 9): the human approver's
account, a date-only `approved_at` is an accepted precision, and the event's
actual author must be an authorized recorder. A recorder without authority
cannot authorize Apply; that does not stop this review.

## Step 4 — Decide the result and write the report

On a first round, form your own view before reading other reviewers'
unconfirmed reports; on a re-review, start from the previous findings and the
implementer's per-finding replies.

- `pass` — sufficient evidence for this scope and version, no blocking finding.
- `changes-required` — a demonstrated defect, security or data risk, or unmet
  requirement.
- `blocked` — a required check or piece of evidence cannot be obtained, or the
  same dispute returns with no new evidence.

Style and out-of-scope ideas are non-blocking suggestions. Findings are named
`<origin-review-id>/F-NN` with a review-id `<reviewer-session-alias>-rNN`
assigned before publication; a finding keeps its ID in later rounds. A fix the
implementer claims stays Accepted until you verify the fixing revision and the
affected behavior; only that evidence makes it Resolved.

Write the report as the reviewer reply of contract section 6.2: the reviewed
version (PR head, or local `HEAD` plus included paths) and purpose, the
Review-ID and verdict, each finding as an actionable item a reader without the
local records understands (impact, location or evidence, how to tell it is
fixed), the checks actually run and their results, what was not executed, and
the next step. No findings means no filler items. Author carries both
`SESSION-ID` (this reviewer session's native ID) and `XIRP-SESSION-ID` (its
Xirp management ID). Look both up from the runtime before writing either as
`null`, read only those keys, and explain any `null` in your report; an alias is
never written as either ID, and one ID never fills the other's field.

Before any post, read the PR head again. If it moved, keep the report bound to
the reviewed head, mark it **stale**, and say the new head needs its own round.

## Step 5 — Where the result goes

- **No PR, PR unknown, or `pass`** — the report is returned directly. A pass is
  posted only when the user asks; such a post never notifies anyone to "fix".
- **A PR with `changes-required` or `blocked`** — invoking this workflow
  authorizes posting the report through `github-pr reply`, unless the user asked
  for **local-only**. Then **回讀** the stored comment: parent PR, repository,
  reviewed head, Review-ID, and full content, and note its URL. Only a match is
  a confirmed publication. A denial, a timeout, or a failed or mismatched
  readback is recorded as publication 「可能已發布／尚未確認」 or failed —
  separately from the technical verdict — reconciled by listing the PR's
  comments before any retry, never resent blindly, and never through another
  tool after a denial. No notification goes out for an unconfirmed report.

Use a platform APPROVE or REQUEST_CHANGES only on a separate explicit request
when the account may; an Agent verdict is not a platform approval. Older COMMENT
reviews remain readable history.

## Step 6 — Hand off to the implementer

Only after a confirmed failed-review reply, unless the user excluded
notification, and only when the result asks the implementer to act. A `blocked`
caused by the reviewer's side — a missing review skill or a missing test
environment the implementer cannot provide — is reported and posted, but not
sent to the implementer as a repair request.

1. **Find the implementation Author** — in the PR description or the latest
   implementation or repair reply: `Co-Authored-By`, `AI-Assisted-By`,
   `SESSION-ID`, `XIRP-SESSION-ID`. The newest reply may be a reviewer's; never
   take a reviewer's or your own identity for the implementer's. Several
   plausible implementers, or none: send nothing, return the message.
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
   ID `null`, mapping unclear: return a transferable message with the same
   content and say why it was not sent. Repository notifiers such as Telegram
   or waiting prompts are not session channels.

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

## Replay cases

[references/acceptance-cases.md](references/acceptance-cases.md) holds the
replayable cases: entry by Change, Issue, `#N`, or PR; no PR and unknown PR;
ambiguity; versions and moving heads; mandatory verify and optional skills;
design review; required tests; full reports for no PR, a failed PR that can be
notified, a blocked PR that cannot, and a pass; publication readback and
failures; implementer identity and local sessions; local-only; and re-review.
