---
name: github-pr
description: >
  Create, update, reply to, or close a GitHub pull request, following the
  project's shared handoff contract. Work Items, OpenSpec Changes, the published
  branch diff, and the current session are material: the PR explains the work so
  someone who missed the conversation understands it. create does what opening
  the PR needs — checks, a commit scoped to this work, a normal push — then opens
  a Draft PR (or returns the existing one); update edits the authorized parts of
  its description; reply adds a Review, Changes, Checkpoint, Closure, or other
  report as a new top-level comment; close posts and reads back a Closure
  summary, then closes only that PR without merging — linked Issues stay as they
  are. Only create publishes Git. Every write checks the full
  base and head repositories (including forks) and is read back. Works through gh or a
  configured GitHub MCP. Use whenever the user asks to open, describe, refresh,
  review-reply, report fixes on, hand off, summarize, or close a PR — for
  example "建立 PR", "開 PR", "更新 PR 說明", "回覆 review", "回報修正",
  "交接摘要", "結案摘要", "關閉 PR", "把批准記到 PR".
license: MIT
compatibility: "Requires git and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Optional: openspec CLI, git-commit-writer."
metadata:
  author: wkchen
  version: "3.0"
---

# GitHub PR

A thin entry for the PR side of the GitHub handoff. The description explains the
work and the version that is published; replies keep each round of review,
repair, handoff, or closure; close ends a PR that will not be merged.

`docs/github-handoff.md` owns every template, field meaning, and rule. This
skill only sequences the work. **Read that contract first** — sections 3, 4, 5,
6 (the shared Handoff / Next actions / Author frame), 6.2, 6.3, 6.6, 6.7, 8, 9
and 11 — and take the body and reply layouts from there rather than from memory.

## What each operation may change

| Operation | Needs | Side effect when authorized |
|---|---|---|
| `create` | The work to open as a PR (local or already pushed); material to describe | Checks, a scoped commit and a normal push when needed, then one Draft PR — or returns the existing open one |
| `update` | The PR, what to change | Rewrites the authorized parts of its description |
| `reply` | The PR, this round's review, fixes, Checkpoint, Closure, or report | Adds one top-level comment |
| `close` | The PR, and why it ends without a merge | Adds one Closure comment, then closes only that PR without merging |

A request to create a PR is the authorization for everything opening it needs:
the project's checks, a commit of this PR's changes, a normal push, the Draft PR,
and readback. Do those without asking again because the work is uncommitted or
the branch is not on the remote yet. `update`, `reply`, and `close` never stage,
commit, or push. No operation merges, force-pushes, changes the base, deletes a
branch, or switches Draft/Ready. The old `publish` operation is removed. If
someone asks for it, say so: pushing new commits to an existing PR is a separate
Git request, and `update` describes the new head afterwards. Make no Git write
for it, and do not quietly treat it as `update`.

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
create, edit, comment, and comment plus close for `close`). Read whatever
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
gh api --hostname <host> repos/<owner>/<repo>/compare/<base-branch>...<head-owner>:<head-branch> \
  --jq '{status, ahead_by, head: .commits[-1].sha, files: [.files[].filename]}'
```

For `create`, a head branch missing on the remote is not a blocker — Step 5
publishes it. Nothing to publish and nothing ahead of the base means there is no
PR to open: report it. Never create an empty commit, a branch, or a placeholder
file to manufacture a difference. For the other operations, a dirty or ahead
local checkout does not block the write, but it is not evidence of what is
published.

## Operation: create

Run Steps 1–4 first. If one open PR already matches the base and the full head,
return its URL and stop — no commit, no push, no description rewrite.

### Step 5 — Prepare and publish what the PR needs

Do only the stages that are missing, without asking again for routine work.

1. **Resolve the base** when it was not given: an existing PR or session decision
   about this branch, a verified predecessor branch the work builds on, or the
   repository's default branch — in that order. Never use the head's own
   tracking ref as the base. Say which base you used.
2. **Inventory and scope.**

   ```bash
   git status --porcelain=v1 --untracked-files=all
   git log --oneline <base-branch>..HEAD
   ```

   Sort every staged, unstaged, and untracked path into this PR's work or
   unrelated work, from the selected Change or Work Item, the session, and the
   actual diff. Paths you cannot place: list them and ask about those paths
   only. Unrelated work is left exactly as it is — never stash, reset, discard,
   or move it.
3. **Checks.** Run the project's required checks for this work. A failure that
   belongs to this work is fixed only within existing authorization; otherwise
   stop and report it — never skip a check or use `--no-verify` to get past it.
4. **Commit, only if this PR's changes are uncommitted.**

   ```bash
   git add -- <pr-paths>
   git commit -m "<message>" -- <pr-paths>
   ```

   The pathspec commit takes only `<pr-paths>`; other staged entries stay staged,
   and unstaged or untracked unrelated files stay as they were. Use the project's
   Conventional Commits style and root-session attribution. `git-commit-writer`
   stages the whole worktree, so use it only when every changed path belongs to
   this PR — never as a whole-worktree helper on a mixed checkout. Hooks run;
   if one fails, nothing is committed and you report it.
5. **Push, only if the remote does not already have this commit.**

   ```bash
   git remote get-url --push <remote>
   git push <remote> HEAD:refs/heads/<head-branch>
   git ls-remote <remote> refs/heads/<head-branch>
   ```

   The push URL must name the selected head repository — full host, owner, and
   repository; if not, stop rather than change the remote. Push normally, never
   force. The remote head must equal the local commit before the PR describes
   it. When the resolved base is an existing predecessor branch that is not on
   the remote yet, publish that branch as it is
   (`git push <remote> <base-branch>:refs/heads/<base-branch>`) and read it back
   the same way — never create, merge, or rebase predecessor work for it.
   A rejected push (non-fast-forward, denial) stops here: report Git's message
   and the remote head; never pull, rebase, or force to get past it.
6. **Compare what is now published** (Step 4's compare call). Nothing ahead of the
   base: report that there is no PR to open.

Authentication or permission problems are reported as the actual failed
stage — not fixed by asking the user to say yes again, by switching accounts or
credentials, or by resending through another tool.

### Step 6 — Compose the description

Write it from what Step 5 actually published. Follow the body in contract
section 6.2 inside the shared frame of section 6. Handoff first, with `branch`
always and other associations only when confirmed — no empty fields; a Work Item
is marked `（local-only）`, and `issue` names work this PR addresses without
authorizing its closure. Then the work: what the problem is and whom it affects,
what is in and out of scope, the design or the published changes, how the
published version was checked, and what is still open, as far as the material
supports each. Summary, Changes, and Verification are the default headings; pick
others that fit (Design, Open questions) and add no empty sections. Do not keep
a record's layout (Sessions, coordinators, decision IDs, per-agent next
actions), do not shorten the tasks list group by group, and do not post bare IDs
in place of an explanation. Point to a task plan by linking it,
without enumerating its groups or counts. A design-only PR describes the design and
claims no implementation. Never invent a decision, number, owner, date, or test
result.

**Next actions** says what happens next to this published version — usually who
reviews which head — with the owner and condition when known, or what still
needs confirming.

**Author** last (contract section 6). A human posting directly gets only
`方式: 人類直接發布` and `人類`. When you post: `方式: Agent 協助`, `人類` only
when the person is confirmed and may be named (never inferred from the API
account), the tool posting now, the known current root-session model,
`SESSION-ID`, and `XIRP-SESSION-ID`; look up both IDs before writing either one
as `null`:

- `SESSION-ID` — the native ID the current tool's runtime exposes for this
  session (for example `CLAUDE_CODE_SESSION_ID` in Claude Code, or
  `CODEX_THREAD_ID`／`CODEX_SESSION_ID` in Codex).
- `XIRP-SESSION-ID` — the Xirp management ID for this session, from the runtime
  (on this kind of setup `CHIRP_SESSION_ID`) or the configured local session
  tool. Do not assume an `XIRP_SESSION_ID` variable exists.

Read only those keys — never dump the environment, the transcript, or anything
credential-like. A value that cannot be tied to the current posting session, or
that is absent, unregistered, or withheld, is `null` in its own field, with the
reason in your report; the other field is unaffected and the post goes ahead.
Never copy one ID into the other field, take an ID from a source record or
another agent, or ask the user to type one in. The model comes from what the
current root session knows, never from the environment; an unknown model is
omitted and reported. When you post a report someone else wrote, keep its
original author: add `原報告作者` with the verified source link, and any tool,
model, or Session that author explicitly published, above your own fields — your
Session is never presented as the one that reached their conclusions.

### Step 7 — Create, then verify

```bash
gh pr create -R <host>/<owner>/<repo> --draft --base <base-branch> \
  --head <head-owner>:<head-branch> --title "<title>" --body-file <file>
gh pr view <number> -R <host>/<owner>/<repo> \
  --json url,headRefOid,body,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
```

Always name the head owner, so `gh` cannot pick another fork's branch of the same
name; with an MCP, pass the head as `<head-owner>:<head-branch>` too, or stop if
the tool cannot express it. The read-back head repository, owner, base branch,
and head SHA must all equal what was selected and published. If the readback
fails, report the returned URL as created but unconfirmed and do not create
again.

### Partial results and reruns

Report each stage on its own: committed (SHA), pushed (remote head), PR created
(URL), read back. A later failure never undoes an earlier stage: a commit whose
push failed stays committed; a pushed branch whose PR failed stays pushed. Before
any retry — after a failure, a timeout, or an unknown result — read the local
commits, the remote ref, and the existing PRs (Step 4), then do only what is
still missing. Never commit the same work twice, push again "to be safe", or
create a second PR; if the state stays unclear, report that instead.

## Operation: update

1. Confirm the PR (Step 4) and that the tool can edit it. Read the latest
   description from the structured response (`--json body`), not `--jq .body`,
   which appends a newline every round trip.
2. Change only what was authorized: Handoff associations confirmed since (an
   Issue, a Change, a Work Item, a dependency with its release condition), the
   work sections, Verification, and Next actions — all for the same currently
   published head — or this posting's Author.
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
2. Compose one comment in the shared frame (contract sections 6 and 6.2):
   Handoff with `pull-request` and `branch`, then the body, then Next actions,
   then Author (Step 6's rules, including `原報告作者` for a relayed report).
   - **Review** — `reviewed-head`, `review-id`, and `result`, a design review
     marked as such, then each finding under its stable ID: the problem and its
     impact in words a reader without the local records understands, the
     location or evidence, and how to tell it is fixed. A re-review lists the
     earlier IDs with their new status. Verification holds the checks actually
     run and the limits; Next actions says who acts next. No findings: `pass`
     for the checked scope and no filler tasks; a design `pass` adds that
     Apply still needs human approval. Required verification unavailable: `blocked`,
     with what is missing and what would unblock it.
   - **Changes** — per finding ID: what changed, the fixing commit, the checks
     actually run and their results, or an evidenced disagreement; whatever is
     still open stays open. Never report a test that was not run, and never mark
     a finding Resolved — that is the reviewer's call after re-checking.
   - **Checkpoint** (contract section 6.6) — when the work pauses or changes
     hands: current state and published head, confirmed results with links to
     the replies that prove them, open questions, and what the receiver checks
     first. It links the earlier rounds instead of reposting every finding.
   - **Closure** (contract section 6.7) — when the reviewed head is ready to
     merge, or after a merge the user asks to summarize: Outcome, Delivered,
     Verification, Remaining work, and Next actions pointing at the authorized
     merge or follow-up. It says "ready to merge" until a merge has actually
     happened, records real merge evidence afterwards, and never closes or
     merges anything itself.
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

Close ends one PR without merging: post the Closure first, confirm it, then
close. A close request covers that PR only. The Issues it addresses, its
dependencies, other PRs, and its branch stay exactly as they are — closing an
Issue is a separate `github-issue close`. A PR whose work is done and ready to
merge is not closed: post its Closure with `reply` and leave the merge to the
authorized flow.

1. **Read before any write.** Read the PR (Step 4): state, head, body, and the
   latest comments, and fix the reason from evidence — cancelled, superseded by
   a named PR, or done elsewhere. No evidence for the reason: ask. A PR that is
   already merged or closed counts as ended: report its actual state, do
   not close or reopen it, and post a missing Closure only when the user asks
   for one (recording real merge evidence for a merged PR).
2. **Post the Closure and read it back.** Compose it from contract section 6.7:
   Outcome (about to close, and why — never "closed" yet), Result, Verification
   (what the existing reviews covered, and that nothing was merged), Remaining
   work (for example "Issue #42 stays open; continued in PR #61"), Next actions,
   Author.

   ```bash
   gh pr comment <number> -R <host>/<owner>/<repo> --body-file <file>
   gh api --hostname <host> repos/<owner>/<repo>/issues/comments/<comment-id> \
     --jq '{url: .html_url, issue: .issue_url, body: .body}'
   ```

   Do not close on a summary that timed out or failed readback: list the PR's
   comments and compare first, and never post it twice.
3. **Re-check, then close.** Read the PR again. A new head or new comments since
   the summary was prepared are reconciled first — a follow-up Closure covering
   the difference, or a question to the user.

   ```bash
   gh pr close <number> -R <host>/<owner>/<repo>
   gh pr view <number> -R <host>/<owner>/<repo> --json state,url
   ```

   The branch stays; nothing is merged. The readback must show `CLOSED`.
4. **Partial results and reruns.** Report the Closure URL and the PR state
   separately. Summary confirmed but close denied, failed, or unconfirmed: keep
   the URL, report the PR as still open or uncertain, and leave the summary's
   wording as it is. A rerun reads the comments and state first, reuses a
   confirmed Closure that still covers the PR, and does only what is missing.
   Nothing is resent through another tool while its state is uncertain, and no
   Issue is touched either way.

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
publish, reply and approval events, Checkpoint and Closure replies, relayed
reports and human Authors, close scope (ready to merge, superseded, already
merged or closed, summary posted but close failed), and readback or uncertain
results for every operation. Worked examples are in
`references/examples.md`.
