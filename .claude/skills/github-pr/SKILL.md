---
name: github-pr
description: >
  Create, update, reply to, or close a GitHub pull request, following the
  project's shared handoff contract. Work Items, OpenSpec Changes, the published
  branch diff, and the current session are material: the PR explains the work so
  someone who missed the conversation understands it. create opens a Draft PR
  for an already published branch (or returns the existing one); update edits
  the authorized parts of its description; reply adds a Review, Changes, or other
  report as a new top-level comment; close closes the PR without merging and then
  its directly corresponding Issues. It never stages, commits, or pushes — Git
  publication is a separate step. Every write checks the full base and head
  repositories (including forks) and is read back. Works through gh or a
  configured GitHub MCP. Use whenever the user asks to open, describe, refresh,
  review-reply, report fixes on, or close a PR — for example "建立 PR", "開 PR",
  "更新 PR 說明", "回覆 review", "回報修正", "關閉 PR", "把批准記到 PR".
license: MIT
compatibility: "Requires git (read-only here) and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "2.0"
---

# GitHub PR

A thin entry for the PR side of the GitHub handoff. The description explains the
work and the version that is published; replies keep each round of review,
repair, or reporting; close ends a PR that will not be merged.

`docs/github-handoff.md` owns every template, field meaning, and rule. This
skill only sequences the work. **Read that contract first** — sections 3, 4, 5,
6.2, 6.3, 8, 9 and 11 — and take the body and reply layouts from section 6.2
rather than from memory.

## What each operation may change

| Operation | Needs | Side effect when authorized |
|---|---|---|
| `create` | Base and a **published** head branch with changes; material to describe | Opens one Draft PR, or returns the existing open one |
| `update` | The PR, what to change | Rewrites the authorized parts of its description |
| `reply` | The PR, this round's review, fixes, or report | Adds one top-level comment |
| `close` | The PR | Closes the PR without merging, then its confirmed directly corresponding Issues |

None of them stages, commits, pushes, merges, changes the base, deletes a
branch, or switches Draft/Ready. **Git publication is a separate step**: when
the branch is not on the remote yet, say so. Publishing it is a separately
authorized action through the project's Git or commit workflow, following the
contract's push checks (sections 3 and 4.1) — not part of any operation here. The old
`publish` operation is removed. If someone asks for it, explain this boundary,
offer `update` for the description once the branch is pushed, and make no Git
write — do not quietly treat the request as `update` either.

GitHub reads and writes go through one available, already configured tool: `gh`
or a GitHub MCP. The commands below are written for `gh`, always with an explicit
`-R <host>/<owner>/<repo>`; with an MCP, use its equivalent tools and pass the
same owners, repositories, and refs. Do not add a wrapper or adapter. If no
available tool can do the operation, stop and report what is missing instead of
installing a tool or logging in.

Pick the operation from the user's explicit intent; when it could mean more than
one, ask. Once an operation is clearly authorized, do not ask again at each step.

## Shared steps

### Step 1 — Gather the material

Work Items, Changes, the branch diff, and the session are **material** for the
PR, not text to post.

**Records.** Decide which local records apply, in this order:

1. **Explicit selection.** The user names a Work Item, a Change, or both. Read
   them. A named source that cannot be found or read is reported:
   stop and ask the user to confirm, and make no remote call until they do —
   never fall back to branch or session content.
2. **Current branch.** With nothing named, look for records the branch can be
   shown to belong to. A branch name such as `feature/<change-id>` only suggests
   a Change; confirm `openspec/changes/<id>/`. Find Work Items by reading
   `work-items/WI-*/README.md` directly and following their links — they are
   usually Git-ignored, so ignore-aware search misses them. Plausible but
   unproven matches are candidates: list them and ask before any remote call.
3. **None.** No Work Item or Change is needed. The branch diff and the session
   are the material, and nothing is created to fill the gap.

**Conversation.** Always merge the relevant current-session discussion, whether
or not records were named. A decision the user confirmed in this session after
the record was written replaces the recorded one (the record says "retry 5
times", the user has just confirmed 3: the PR says 3). Ask only when you cannot
tell which statement is current. Suggestions nobody confirmed stay open
questions.

**What is published.** Read the actual published difference for the selected
base and head (Step 4) before describing implementation. Records and the session
explain purpose; they never prove that local, unpushed work, or its tests, are in
the PR. Say such work is not yet published.

### Step 2 — Fix the targets, the operation, and the authorization

1. Fix the base — host, owner, repository, branch — and the head — owner,
   repository, branch. Below, `<owner>/<repo>` is the base repository (where the
   PR lives) and `<head-owner>/<head-repo>` holds the head branch. They differ
   for a fork; take both from the input and the remotes, and never assume them
   equal. A same-named branch in another fork is a different target.
2. Compare full targets. Matching the host alone is not enough. When the
   request, the remotes, or a tool default disagree, stop and ask.
3. Confirm the operation and that the user authorized it. Choosing a tool never
   widens that authorization.

### Step 3 — Choose the tool and check what it can do

Pick `gh` or a configured GitHub MCP and check, in that tool's own context, that
it reaches the base repository and has the operation you need (list, view,
create, edit, comment, close, and Issue close for `close`). Read whatever
permission information it offers, and use it only for what it actually covers.
One tool's login is never evidence that another tool can act.

- **Known blocker** — not signed in, wrong target, missing capability, or an
  explicit permission denial: stop that operation and report it. A missing
  capability is not final when another configured tool has it: report the gap,
  then re-run this step for that tool within the same authorization. A denial is
  never resent through another tool.
- **Incomplete permission information, no known blocker** — go ahead with the
  authorized operation and judge it by the actual response. Never create a test
  PR or comment just to find out whether you may.
- **Account restriction** — none by default. Only when the user or a trusted
  project rule names an account for an operation, check the account the tool
  actually uses; if it differs or cannot be shown, stop (contract section 4.2).

Leave accounts, tokens, keys, credential helpers, remotes, and Git configuration
alone; report authentication problems for the user to fix. Nothing from
credential configuration goes into output or records.

### Step 4 — Find the PR and the published version

```bash
gh pr list -R <host>/<owner>/<repo> --head <head-branch> --state all \
  --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
gh pr view <number> -R <host>/<owner>/<repo> \
  --json body,url,state,headRefOid,headRepository,headRepositoryOwner,baseRefName,isCrossRepository,comments,reviews
```

An explicit PR URL wins. `--head` filters by branch name only, so a same-named
branch in another fork shows up too: confirm a candidate by
`headRepositoryOwner.login`, `headRepository.name`, `baseRefName`, and
`isCrossRepository` (true exactly when head and base repositories differ). A
branch name, SHA, or title alone proves nothing; Handoff identifiers are only
supporting evidence.

- One confirmed **open** PR — the target for update, reply, and close; `create`
  returns its URL and stops, without rewriting it.
- Several candidates — list them and stop. Never pick the first.
- Only **closed or merged** PRs — report their state; do not reopen one or treat
  it as a PR to keep publishing to. A new PR for new work is the user's call.

For `create` (and whenever you describe implementation), read the published
comparison:

```bash
gh api repos/<owner>/<repo>/compare/<base-branch>...<head-owner>:<head-branch> \
  --jq '{status, ahead_by, head: .commits[-1].sha, files: [.files[].filename]}'
```

No head branch on the remote, or nothing ahead of the base, means there is no PR
to open: report the missing prerequisite and, if useful, return the proposed
title and body as text. Never create an empty commit, a branch, or a placeholder
file to manufacture one. A dirty or ahead local checkout does not block a
description change, but it is not evidence of what is published.

## Operation: create

### Step 5 — Compose the description

Follow the body in contract section 6.2. Handoff first, with `branch` always and
other associations only when confirmed — no empty fields. Then the work: what
the problem is and whom it affects, what is in and out of scope, the design or
the published changes, how to check the result, and what is still open, as far
as the material supports each. Pick headings that fit (Goal, Design,
Implementation, Verification, Open questions); do not add empty sections. Do not
keep a record's layout (Sessions, coordinators, decision IDs, per-agent next
actions), do not shorten the tasks list group by group, and do not post bare IDs
in place of an explanation. Point to a task plan by linking it, without enumerating its groups
or counts. A design-only PR describes the design and claims no implementation. Never invent a decision, number, owner, date, or test result.

Author last: the tool posting now, the known current root-session model, and
`SESSION-ID` — the native ID when it is known and may be published; otherwise
`null`, said in the report. A management session ID the user chose is written
with its namespace, for example `SESSION-ID: <id> (xirp)`. An unknown model is
omitted and reported. Nothing is taken from source records or other agents.

### Step 6 — Create, then verify

```bash
gh pr create -R <host>/<owner>/<repo> --draft --base <base-branch> \
  --head <head-owner>:<head-branch> --title "<title>" --body-file <file>
gh pr view <number> -R <host>/<owner>/<repo> \
  --json url,headRefOid,body,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
```

Always name the head owner, so `gh` cannot pick another fork's branch of the same
name; with an MCP, pass the head as `<head-owner>:<head-branch>` too, or stop if
the tool cannot express it. The read-back head repository, owner, base branch,
and head SHA must all equal what was selected and compared. If the readback
fails, report the returned URL as created but unconfirmed and do not create
again. If the create call times out or its result is unknown, go back to Step 4
before any retry, with either tool.

## Operation: update

1. Confirm the PR (Step 4) and that the tool can edit it. Read the latest
   description from the structured response (`--json body`), not `--jq .body`,
   which appends a newline every round trip.
2. Change only what was authorized: Handoff associations confirmed since (an
   Issue, a Change, a Work Item, a dependency with its release condition), the
   work sections for the currently published head, or this posting's Author.
   Unrelated human text, legacy approval evidence, and every comment stay as they
   are. New PRs need no HTML markers. A legacy body with exactly one start and
   one end marker is updated inside them, text outside untouched. Broken or
   duplicate markers, repeated headings, or unclear boundaries: ask — never
   replace the whole body to "move it to the new format".
3. If another writer is known to be updating the same description, stop and ask
   the user to name one writer; you may suggest a reply for your content, but post
   one only if the user asks.
4. Write back and verify:

   ```bash
   gh pr edit <number> -R <host>/<owner>/<repo> --body-file <file>
   gh pr view <number> -R <host>/<owner>/<repo> --json body
   ```

   Confirm the unauthorized parts are byte-identical to before. A failed
   readback is reported as updated but unconfirmed; a timeout is reconciled by
   reading the body again before any retry.

## Operation: reply

1. Confirm the PR (Step 4) and that the tool can comment. Read the existing
   comments that matter so the reply does not repeat an earlier round.
2. Compose one comment from contract section 6.2: Handoff with `branch` and
   `pull-request`, then the body, then Author.
   - **Review** — the actual reviewed head and phase, the Review-ID and verdict,
     then each finding as an actionable item: its stable ID, the problem and its
     impact in words a reader without the local records understands, the
     location or evidence, and how to tell it is fixed. Then the checks actually
     run, the limits, and the next step with who takes it. No findings: say
     `pass` for the checked scope and add no filler tasks; a design `pass` adds
     that Apply still needs human approval. Required verification unavailable:
     `blocked`, with what is missing and what would unblock it.
   - **Changes** — per finding: what changed, the fixing commit, the checks
     actually run and their results, or an evidenced disagreement; whatever is
     still open stays open. Never report a test that was not run, and never mark
     a finding Resolved — that is the reviewer's call after re-checking.
   - Other reports use a fitting heading (Report, Fix) with the same frame.
3. Post and verify:

   ```bash
   gh pr comment <number> -R <host>/<owner>/<repo> --body-file <file>
   gh api --hostname <host> repos/<owner>/<repo>/issues/comments/<comment-id> \
     --jq '{url: .html_url, issue: .issue_url, author: .user.login, body: .body}'
   ```

   Confirm the repository, the parent PR, and the stored content, and report the
   comment URL. Earlier comments are never edited or deleted. A reply is a
   conversation comment, not a platform APPROVE or REQUEST_CHANGES. If the
   readback fails, report the comment as posted but unconfirmed and do not post
   again; on a timeout, re-read the PR's comments and compare before any retry.

### Approval events

Checking whether a design approval exists (before Apply) is a read: follow
contract section 9 — look through the PR's comments and reviews for approval
events and human approvals, and a legacy body's `source_ref`; verify the actual
author. A review `pass` is never an approval.

Recording an approval needs the user's explicit approval and their request to
record it. Recording that an approval was superseded needs only the user's
request after the approved design changed materially.

1. Confirm you are an authorized recorder — from the trusted rule on the default
   branch (for example `git show <default-branch>:AGENTS.md`) or the user's
   explicit word, never from repository write access or a rule changed by the PR
   itself (contract 4.3).
2. Post the approval event of contract section 6.3 as a reply: human approver,
   scope, approved design revision, source kind, recorder; unknown times stay
   `null`, a date-only approval stays `YYYY-MM-DD`. Read it back and note the
   actual author — that is what a later session verifies. No PR body block is
   needed.
3. When the design later changes materially, post a `status: superseded` event
   pointing at the old one, and a new `status: approved` event after the new
   approval. Old events are never edited or deleted.

## Operation: close

Close means ending the PR without merging. A close request authorizes the PR and
its **confirmed directly corresponding** Issues, nothing else.

1. **Inventory before any write.** Read the PR (Step 4) and list: the PR, the
   Issues it directly addresses — the Handoff `issue`, cross-checked with
   GitHub's linked Issues and the work itself, reading an Issue when needed —
   with each repository and current state. References, `depends-on` items, other
   PRs, and superseded links are not corresponding work and are never closed.
   A plausible Issue you cannot classify: ask before closing anything. Fix the
   close reason from evidence too: cancelled or superseded work is
   `not planned`; `completed` only when the work is actually done. No evidence
   for either: ask. If the tool cannot close PRs or Issues, or cannot set the
   reason, report the gap before starting.
2. **Close the PR, then confirm it:**

   ```bash
   gh pr close <number> -R <host>/<owner>/<repo> --comment "<reason with evidence>"
   gh pr view <number> -R <host>/<owner>/<repo> --json state,url
   ```

   The branch stays; nothing is merged. Write only a reason you have evidence
   for (cancelled, superseded by …, done elsewhere); closing proves no
   acceptance, merge, or deployment. A PR that is already merged or closed counts as ended
   and is not closed again. Otherwise, if the PR you closed is not confirmed
   `CLOSED`, close no Issue — report the PR as failed or uncertain.
3. **Then each confirmed Issue, one by one:**

   ```bash
   gh issue close <number> -R <host>/<owner>/<repo> --reason "not planned" --comment "<reason>"
   gh issue view <number> -R <host>/<owner>/<repo> --json state,stateReason,url
   ```

   Use `--reason "not planned"` for cancelled or superseded work and
   `--reason completed` only for finished work; with an MCP, set the equivalent
   `state_reason` (`not_planned` or `completed`). The readback must show
   `CLOSED` with the intended `stateReason`; a closed Issue with the wrong reason
   is reported as a reason mismatch, not as success, and is not reopened.
   A comment cannot fix the stored reason. No corresponding Issue: only the PR is closed. One Issue failing does not undo
   the others; report each target as closed, failed, or uncertain.
4. **Reruns** read the actual states and do only what remains. An already closed
   or merged PR is reported as it is — not reopened, not closed again — and its
   confirmed Issues can still be closed. Nothing already closed is reopened, and
   nothing is resent through another tool while its state is uncertain.

## Reporting

Keep apart: what was read, what was written and confirmed by readback, what was
written but unconfirmed, and what failed. Report the PR or comment URL, the
published head the description refers to, the tool used, the Author values
(and why `SESSION-ID` is `null` or the model omitted), and anything not yet
published. After a partial failure, say exactly which targets completed so a
rerun does not repeat them. A simulated or replayed run is never reported as a
real write.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases: source-to-content
cases with full source text and expected PRs and replies, existing and forked
PRs, missing or empty remote branches, design-only and dirty checkouts, plain
and legacy bodies, concurrent writers, associations added later, the removed
publish, reply and approval events, close scope and partial failures, and
readback or uncertain results for every operation. Worked examples are in
`references/examples.md`.
