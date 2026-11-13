---
name: change-review
description: >
  Review a published OpenSpec change from its pull request, for the design or
  implementation phase, bound to an exact reviewed head: fix the version, run the
  phase checklist, publish one attributable report through gh or a configured
  GitHub MCP, read it back, and hand findings to the implementer for a
  version-aware repair and re-review round. Use whenever the user asks to review
  a PR or a change, re-review after fixes, check a design before Apply, or verify
  an implementation against its spec — for example "review PR #12", "幫我審查這個
  change", "設計審查", "實作驗收", "複審新版本", "看一下修正好了沒".
license: MIT
compatibility: "Requires git and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Optional: openspec CLI, openspec-verify-change, ponytail-review."
metadata:
  author: wkchen
  version: "1.0"
---

# Change Review

One invocation performs one review round of one OpenSpec Change on one PR: it
fixes exactly which revision is reviewed, checks it for the requested phase,
publishes a report that another agent can pick up, and says what happens next.
The report schema, provenance rules, write-time checks, and the design-approval
rules all live in `docs/github-handoff.md`. **Read sections 3–10 of that contract
first** and take every template and field from it; this skill only adds the
review procedure.

[Review, repair, and re-review loop](references/review-loop.svg) shows the whole
cycle; this skill covers the Reviewer's boxes.

## Inputs

| Input | Required | Meaning |
|---|---|---|
| PR reference | yes | URL or `owner/repo#number` |
| phase | yes | `design` or `implementation` |
| Change | when the PR links more than one | the OpenSpec Change to review |
| expected-head | no | the commit the caller wants reviewed; must match the PR |
| previous report | no | report URL for a re-review |
| notification target | no | an authorized, verified session tool and its target |

If the phase is missing and cannot be told from the request, ask — do not infer
it from Draft or Ready. If the PR links several Changes and none is named, list
them and ask. These are semantic inputs; each tool passes them its own way.

## What this skill never does

It does not change the reviewed product code, stage, commit, push, merge,
archive, close an Issue, or switch Draft/Ready. It never takes the `github-pr`
create／publish path. It does not overwrite anyone else's report. Updating a PR
summary or an Issue is a separate request handled by `github-pr update` or
`github-issue update`. There is no identity script, credential parser, or extra
adapter: GitHub calls go through `gh` or a configured GitHub MCP, and their
authentication stays theirs.

## Step 1 — Fix the target and the tool

1. Fix the full target: host, owner, repository, and PR number. Then confirm the
   phase and the selected Change, and that the user wants a report published (or
   only returned).
2. Choose `gh` or a configured GitHub MCP and check, in that tool's own context,
   that it can read the PR and, if publishing, create a review or comment. Read
   access does not prove write access; one tool's login proves nothing about
   another. A known blocker stops publication, not the review itself. Missing
   permission details are not a blocker — the actual response decides. Contract
   section 3.
3. Account restrictions apply only when the user or a trusted project rule names
   one (contract section 4.2). Read it from the trusted default-branch version; a
   change in the PR under review does not relax it.

## Step 2 — Fix the version

1. Read the PR's actual head, base, head repository and owner, and its links to
   the Issue and Change. If an **expected-head** was given and differs from the
   actual head, stop and report the mismatch; never switch to the latest head
   silently. Without one, the head read now is the reviewed head.
2. Locate the Change's artifacts in the reviewed head: `openspec/changes/<id>/`,
   or its archive directory and the matching specs if it was archived. Missing
   required artifacts make the round `blocked`.
3. When the PR also carries other Changes, review only the selected one and its
   real dependencies. Their unfinished tasks are out of scope, not findings.
4. Get a checkout whose HEAD is the reviewed head. Use the current one only if it
   matches and has no unpublished changes. Otherwise create an isolated review
   context within existing authorization (for example a fresh clone in a temp
   directory checked out at the reviewed head). Never stash, reset, discard, or
   commit someone's local work to get there. If no safe matching checkout is
   possible, say so and limit or block the conclusion.

## Step 3 — Record what is reviewing what

Two baselines exist and must not be mixed:

- **Skill source** — the revision of this skill and of the shared contract you
  are following. If either is uncommitted, record the files used with a content
  fingerprint and its algorithm.
- **Reviewed content** — the reviewed head and the Checkout HEAD where checks ran.

A dirty skill-development checkout never vouches for tests of a different
published head. Both baselines go in the Scope and Baseline fields the contract
already defines; there is no extra schema.

## Step 4 — Stay independent on a first round

On a first round, form your own conclusions from the user's request, the
artifacts, and the code before reading other reviewers' unconfirmed reports;
record when you read them and keep cross-checked corrections separate. On a
re-review, start from the previous report's findings and the implementer's
per-finding replies, and do not present earlier views as new independent
findings.

## Step 5 — Run the phase checklist

Use [references/checklists.md](references/checklists.md): the design list for
`design`, the self-contained baseline plus available extensions for
`implementation`. In short:

- **design** asks whether the design can be built and accepted. Unchecked tasks
  and missing code are normal; a design `pass` is neither human approval nor
  evidence that tests ran.
- **implementation** compares the reviewed head with every requirement and
  scenario, follows the changed code to its callers, runs the required checks in
  the matching checkout, and looks for security, data, and regression risk.
  `openspec-verify-change` is used when installed and its raw grading kept;
  `ponytail-review` is optional and its absence is only "not executed". Missing
  necessary evidence never becomes `pass`.

Approval records are judged by the contract: `approved_by` is the human's GitHub
account, a date-only `approved_at` (`YYYY-MM-DD`) is an accepted precision, and
`recorded_at` never stands in for it. An attestation whose recorder lacks
independent authorization cannot authorize Apply; it does not stop this review
or the publication of a technical report.

## Step 6 — Write the findings and the verdict

- Name findings `<origin-review-id>/F-NN`, where the review-id is
  `<reviewer-session-alias>-rNN`, assigned before publication and unique in the
  PR; each new round by the same reviewer takes the next `rNN`. A finding keeps
  its original ID in every later round.
- Each finding has impact, requirement or location, evidence, severity, and
  status. Blocking findings are demonstrated defects, security or data risks,
  unmet requirements, or missing required verification. Style and out-of-scope
  ideas are non-blocking.
- A fix claimed by the implementer stays Accepted until you verify the fixing
  revision and the affected behavior; Resolved records that evidence. A
  supported counter-argument can make a finding Rejected, with the reason.
- The verdict is `pass`, `changes-required`, or `blocked`, for this phase and
  this reviewed head only. Accepted, unfixed required items also go to the
  Change's tasks or formal risk tracking, as the contract says.
- Before publishing, read the PR head again. If it moved, keep the report bound
  to the reviewed head, mark it stale, and say the new head needs its own
  review; never carry a `pass` forward.

Write the report in the contract's review template, Scope and Baseline first,
with the session fields filled honestly: a native Session ID only when known and
publishable, a separate alias, and `null` with the reason otherwise.

## Step 7 — Publish, then read back

Publish only when the user asked for it and Step 1 found no blocker.

- Default form: a COMMENT pull request review anchored to the reviewed commit
  (`commit_id` = reviewed head). Use APPROVE or REQUEST_CHANGES only on a
  separate explicit request and only when the account may; an Agent verdict is
  not a platform approval, and agents sharing one account are not separate
  approvers.
- If the tool cannot create a review, use an equally authorized PR comment whose
  first line states phase, Review-ID, and reviewed head. A comment is never a
  way around a denial or an account restriction.
- After the tool reports success, **回讀** the stored report by its URL and
  compare target, Review-ID, phase, reviewed head, and body. Only a match counts
  as published. If readback fails or differs, record publication as
  「可能已發布／尚未確認」, keep the technical verdict as it is, reconcile by listing
  the PR's reviews and comments, and do not announce the handoff as done. If a
  wrong body was stored, report the difference and let the user decide how to
  correct it; do not post a second copy.
- A timeout or unknown result: list existing reviews and comments for the
  Review-ID and head before any retry, with either tool. Never resend blindly.
- If publication is impossible (denied, restricted, no capable tool), return the
  full report or keep an authorized local draft, record publication as
  incomplete, and never invent a URL.

`blocked` reports are published too; not being able to finish checking is not a
reason not to report.

## Step 8 — Hand off and end the round

- **changes-required**: after the report is confirmed, return a transferable
  message (contract section 6.5) with the PR URL, the confirmed report URL, the
  reviewed head, the finding IDs, and the next action. Send it directly only
  when the caller named an available, authorized session tool. Use the target
  that tool accepts — for example a 管理 Session ID — and keep it apart from the
  agent's native Session ID; never swap one for the other. A sent message is not
  a read message, and neither is a started repair. Repository notifiers such as
  Telegram or waiting prompts are not session channels.
- If the original implementer session is gone, the PR already holds what a new
  agent needs; return that handoff action without claiming to have woken anyone.
- **blocked** names the missing condition, its owner, and the next action. The
  same dispute repeated with no new head or evidence is `blocked` for human
  decision — do not keep re-requesting it.
- **pass** applies to this phase and head only; approval, merge, deployment,
  real-data acceptance, and Issue closure remain separate actions.

The round ends here: 每次呼叫只做一輪. A re-review is a new invocation after the implementer has
published a new head and replied per finding. This skill does not poll, wait,
or loop on its own.

## Reporting to the user

Say what was reviewed (Change, phase, reviewed head, Checkout HEAD, skill
source), the verdict, the findings by ID, the checks run and not run, the
publication state (confirmed URL, unconfirmed, or not published), and the
delivery state of any notification. A replayed or simulated round is never
reported as a real review or publication.

## Replay cases

[references/acceptance-cases.md](references/acceptance-cases.md) holds the
replayable cases: phase and Change selection, expected-head and checkout
mismatches, moving heads, skill-source separation, session fields, approval
precision and recorder authorization, gh or MCP channels and denials, design and
implementation outcomes, findings across rounds, publication readback, handoff
and notification, and bounded re-review.
