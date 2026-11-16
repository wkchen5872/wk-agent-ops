---
name: github-pr
description: >
  Create, update, reply to, or close a GitHub pull request in the team's shared
  PR format, which this skill holds. Work Items, OpenSpec Changes, the published
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

This skill holds everything these operations need: the write checks, the
shared Handoff / Next actions / Author frame, and the layouts for the
description, review and fix replies, Checkpoints, and Closures. Take layouts
from here rather than from memory; the references below show them filled in.

## Dedicated agent

A session may delegate one operation to the `github-pr-agent` (Claude Code
`.claude/agents/`, Codex `.codex/agents/`). The agent follows this skill
unchanged and posts with the caller's identity: the caller passes the
operation, the full repository and PR target, the content or report path, and
its own tool, model, native session ID, and Xirp session ID. The Author is the
caller's, never the agent's own model or session; without that identity the
agent posts nothing. The caller keeps the authorization and gets back
`confirmed`, `unconfirmed`, or `failed` with the URL or reason.

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
same owners, repositories, and refs. Do not add a wrapper or adapter. Local
`git` reads the remotes and branches and makes the commit and push that `create`
needs. If no available tool can do the operation, stop and report what is
missing instead of installing a tool or logging in; a missing Git push path
stops only the push. Each machine and each tool prepares its own login; one
login never vouches for another machine or tool. No identity policy, check
script, or pinned blob is needed; a leftover identity-check script from an
older install is not used, and deleting it is the user's call.

Pick the operation from the user's explicit intent; when it could mean more than
one, ask. Once an operation is clearly authorized, do not ask again at each step.

## Shared steps

**Write checks.** Every write goes through the same six checks. They establish
that this is the operation the user wants, aimed at the right place, and that
the result really exists — not whose account it is.

1. Fix the full targets: base and head (Step 2).
2. Fix the operation and the user's authorization (Step 2).
3. Choose one configured tool and confirm it can do this operation (Step 3).
4. Stop on a known blocker (Step 3).
5. Read the result back by the URL, number, or ref the tool returned, and
   confirm it before calling the step done (each operation's verify step).
6. On a timeout or an unknown result, look up the actual state first; do not
   resend, and do not resend through another tool, until it is settled.

Every Git push also checks the actual push URL's repository and ref
(`git remote get-url --push <remote>`), never forces, and reads the remote head
back afterwards; SSH host aliases are left to Git and SSH to resolve.

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
   widens that authorization. Authorization comes from the user's instruction,
   never from an account: being able to write the repository does not mean the
   user asked for this write.

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
- **Account restriction** — none by default: any configured, authorized account
  will do, and the API, commit, and push identities may differ. Only when the
  user in this task, or a trusted project rule (for example explicit text in
  `AGENTS.md` on the default branch), names an account for an operation, check
  the account actually used in that operation's own context. If it differs or
  cannot be shown, stop and report the restriction and the missing evidence.
  Never switch accounts or write a credential parser to pass; a strict push
  account that Git cannot safely show is left to the user. A rule that only the
  PR head under review changes does not loosen an existing restriction;
  following it needs the user's separate authorization.

Leave accounts, tokens, keys, credential helpers, remotes, and Git configuration
alone: do not parse credential helpers, tokens, SSH keys, or SSH greetings,
never ask Git's credential helpers for secrets, and never treat the `gh` login as
the push identity. Git's author and committer are commit metadata and need not
match a GitHub login. Report authentication problems for the user to fix. When
you record a tool, account, or failure, keep to non-secret metadata — the
account the tool reports and where it came from, or `unavailable` — and never
borrow another tool's login as evidence. Nothing from credential configuration
goes into output, reports, or PRs.

### Step 4 — Find the PR and the published version

```bash
gh pr list -R <host>/<owner>/<repo> --head <head-branch> --state all \
  --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
gh pr view <number> -R <host>/<owner>/<repo> \
  --json body,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,baseRefName,isCrossRepository,comments,reviews
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
   Conventional Commits style. `git-commit-writer`
   stages the whole worktree, so use it only when every changed path belongs to
   this PR — never as a whole-worktree helper on a mixed checkout. Hooks run;
   if one fails, nothing is committed and you report it.

   The message ends with its trailers, in this order:

   ```text
   Refs: <references>
   Co-Authored-By: <tool trailer>
   AI-Assisted-By: <known current root-session model>
   ```

   - `Refs:` is the first trailer, right before the attribution trailers, and
     is left out when no reference is confirmed — never an empty value.
   - The co-author trailer uses this verified mapping:
     `Co-Authored-By: Claude Code <noreply@anthropic.com>` for Claude Code and
     `Co-Authored-By: Codex <noreply@openai.com>` for Codex; any other tool is
     `Co-Authored-By: <tool name>` without an email, and no address is guessed.
   - `AI-Assisted-By` is the model the current root session knows. When it is
     unknown, omit the whole `AI-Assisted-By` line and say so in your report.

   The `Refs:` line lists the Issues and PRs this work
   directly addresses, each confirmed by this session's user instruction, a
   Handoff `issue` or `pull-request` line that was read, or a read Issue or PR
   that names this work — for example the Handoff `issue`, or an existing PR
   being reused. Never scan GitHub for more, and never infer one from a branch
   name or from a number a proposal merely mentions.

   - Only directly addressed work counts. Links that are background (such as
     completed Issues a proposal cites for context), `references`, and
     `depends-on` targets are left out unless separately confirmed as directly
     addressed.
   - Unknown, ambiguous, or conflicting targets are omitted and reported; they
     never block the commit and are never a reason to ask again.
   - The commit repository is the confirmed push target from the remote. A
     target in that repository on the same host is `#N`; anything else is its
     full HTTPS URL (`https://<host>/<owner>/<repo>/issues/<N>` or `/pull/<N>`).
     If the commit repository is unknown, keep only targets given as full URLs.
   - Deduplicate by host, owner, repository, and number — a `#N` and a URL for
     the same target count once. List local `#N` in ascending order, then
     external URLs in lexical order: `Refs: #7, https://github.com/acme/platform/issues/3`.
   - Use `Refs:` only — never `Closes` or `Fixes`, or any keyword that changes
     Issue or PR state.
   - Only targets that exist at commit time count: the new PR has no number yet,
     so it is never guessed into the message. Work that is already committed is
     published as it is; never amend it, or add a commit, just to backfill a
     reference.

   `git-commit-writer` applies the same rules when it is used as the helper
   above; this step does not depend on it.
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

Write it from what Step 5 actually published, with this layout:

```markdown
## Handoff

- branch: <已核對的 head branch；fork 時寫 <head-owner>:<branch>>
- openspec-change: <已確認的 Change ID>
- issue: <這張 PR 直接處理的 Issue URL>
- work-item: <已確認的 Work Item ID>（local-only）
- depends-on: <依賴的 Issue／PR URL>（<解除條件>）

## Summary

<問題、影響與預期結果>

## Changes

<這個已發布版本實際改了什麼>

## Verification

<發布版本與實際執行的檢查、結果與尚未驗證的部分>

## Next actions

<下一步與負責方>

## Author

Co-Authored-By: <本次發布的工具>
AI-Assisted-By: <已知的當下 root-session model>
SESSION-ID: <本次原生 Session ID｜null>
XIRP-SESSION-ID: <本次 Xirp 管理 Session ID｜null>
```

Handoff first, with `branch` always (spelled `branch`) and other associations
only when confirmed — no empty fields; later confirmations are added with
`update`. A Work Item is marked `（local-only）`, and `issue` names work this PR
addresses without authorizing its closure — the Issue's state is a separate
`github-issue close`. The title says what the work is for, with no required
Change ID prefix; a design-stage PR may say it is the design. Then the work: what the problem is and whom it affects,
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
needs confirming. **Author** follows "Every post" above. A reader who sees
`XIRP-SESSION-ID` uses it only as a lookup hint for the local session tool.

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
   Changes, Verification, and Next actions must all describe the same published
   version. Unrelated human text, legacy approval evidence, and every comment
   stay as they are. New PRs need no HTML markers. A legacy body with exactly one
   `<!-- wk-agent-ops:handoff:start -->` and one
   `<!-- wk-agent-ops:handoff:end -->` marker is updated inside them, text
   outside untouched; its `openspec-change:` and `repository:` keys stay
   readable evidence and need no migration. Broken or
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

   Take the exact body from the structured response before editing: a
   text-output read such as `--jq .body` adds a trailing newline every round
   trip, and shell `$(…)` strips one. Confirm the unauthorized parts are
   byte-identical to before. A failed readback is reported as updated but
   unconfirmed; a timeout is reconciled by reading the body again before any
   retry. Reading before writing does not remove a race, and this skill offers
   no lock or atomic merge.

This is for PR descriptions only: an Issue body is never rewritten, and
Issue updates are new comments through `github-issue update`.
`update` never stages, commits, pushes, merges, changes the base, closes,
switches Draft/Ready, or replaces labels or assignees wholesale; each of those
needs its own authorization.

## Operation: reply

1. Confirm the PR (Step 4) and that the tool can comment. Read the existing
   comments that matter so the reply does not repeat an earlier round.
2. Compose one comment in the shared frame ("Every post" above): Handoff with
   `pull-request` and `branch`, then the body, then Next actions, then Author
   (including `原報告作者` for a relayed report). The body heading is Review or
   Changes by default, or Checkpoint, Closure, Report, or Fix when that fits
   better; the frame stays the same. The layouts are below.
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
   - **Checkpoint** (layout below) — when the work pauses or changes
     hands: current state and published head, confirmed results with links to
     the replies that prove them, open questions, and what the receiver checks
     first. It links the earlier rounds instead of reposting every finding.
   - **Closure** (layout below) — when the reviewed head is ready to
     merge, or after a merge the user asks to summarize: Outcome, Delivered,
     Verification, Remaining work, and Next actions pointing at the authorized
     merge or follow-up. It says "ready to merge" until a merge has actually
     happened, records real merge evidence afterwards, and never closes or
     merges anything itself.
   - Other reports use a fitting heading (Report, Fix) with the same frame.
   - Longer supporting evidence goes in a published document that the reply
     links; never publish local private paths. A checkout that differs from the
     reviewed head is pointed out. Older one-line replies
     (`版本：…。Review-ID：…。結論：…`) stay readable and are not rewritten.
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

### Reply layouts

Review reply:

```markdown
## Handoff

- pull-request: <已確認的 PR URL>
- branch: <head branch>

## Review

- reviewed-head: <reviewed head SHA>
- review-id: <review-id>
- result: <pass｜changes-required｜blocked>

### <review-id>/F-01

<問題與影響，讓沒讀過本機紀錄的人看得懂>
位置／證據：<檔案、行為或實際結果>。完成條件：<怎樣算修好>。

## Verification

<實際執行的檢查與結果；未驗證的部分與具體限制>

## Next actions

下一步：<誰做什麼，以及完成或解除的條件>

## Author

Co-Authored-By: <本次發布的工具>
AI-Assisted-By: <已知的當下 root-session model>
SESSION-ID: <本次原生 Session ID｜null>
XIRP-SESSION-ID: <本次 Xirp 管理 Session ID｜null>
```

Fix reply:

```markdown
## Handoff

- pull-request: <已確認的 PR URL>
- branch: <head branch>

## Changes

### <review-id>/F-01

<改了什麼>。修正 commit：<SHA>。驗證：<實際執行的檢查與結果>。目前為已修正、待 Reviewer 複審。

### <review-id>/F-02

<尚未處理，或有證據的不同意與理由>

## Next actions

<下一步與負責方，通常是 Reviewer 對新 head 複審>

## Author

Co-Authored-By: <本次發布的工具>
AI-Assisted-By: <已知的當下 root-session model>
SESSION-ID: <本次原生 Session ID｜null>
XIRP-SESSION-ID: <本次 Xirp 管理 Session ID｜null>
```

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

Checkpoint:

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

`Confirmed decisions` and `Confirmed results` may both appear or either one, and
blockers may go under `Blockers`. Link the formal spec, tasks, and earlier
rounds instead of copying them. Whoever reads a Checkpoint checks the events
after it and the current head: a newer fix, decision, or review replaces the
summary, and "the latest Checkpoint" does not prove it is current. Checkpoints
that disagree are shown side by side and one person consolidates them.

Closure (ready to merge with `reply`, or ending the PR with `close`):

```markdown
## Handoff

- issue: <Issue URL>
- pull-request: <PR URL>
- branch: <PR 的 head branch；只結 Issue 時省略>
- openspec-change: <已確認的 Change ID>

## Closure

### Outcome
<預期或已發生的結果：準備以 completed／not planned 關閉、準備合併、被取代等>

### Result
<交付或取消的範圍；PR 可用 Delivered>

### Verification
<驗收或驗證的依據與證據連結；Issue 可用 Acceptance>

### Remaining work
<原範圍內未完成的事項與追蹤位置；沒有就寫明>

## Next actions

<結案後由誰接續什麼>

## Author

<依共用外框>
```

The Outcome states an expected result — about to merge, about to close — and
never claims a close, merge, deployment, or acceptance that has not happened.
After a merge the user asks to summarize, record the actual merge evidence and
do not close. A superseded or abandoned PR links the replacing PR or states why
it was cancelled; the Issues it addresses are not treated as done.

### Approval events

Whether implementation may start is decided by `docs/openspec-workflow.md`, not
by this skill: an explicit user instruction to implement, in this session or
through a traceable handoff, needs no PR event. Read
[references/approval-records.md](references/approval-records.md) when you need to record an approval on the PR or look one up there;
it holds the event layout, how to find events, how to compare the approved
revision with the current design, and how to supersede one. Looking up a
published approval is a read — the PR's comments and reviews for approval
events and the user's own comments or reviews, plus a legacy body's
`source_ref`. A review `pass`, a body claim, or repository access is never an
approval; an API author shows only who posted.

Recording an approval needs an explicit user instruction and the user's request
to record it on the PR. Recording that an approval was superseded needs the
user's request after the design changed materially or the instruction was
withdrawn. Permission to implement does not include permission to post.

1. Read the PR's earlier approval events first, so `supersedes` points at the
   one being replaced (or `none`). Post the approval event from
   `references/approval-records.md` as a reply, inside the shared Handoff / Next
   actions / Author frame: source kind and source description, scope, approved
   design revision (the design commit, or, for a design that exists only
   locally, an unpublished snapshot fingerprint with its base — never a made-up
   commit, and no commit or push to get one), recorder, and times — a date-only
   approval stays `YYYY-MM-DD`, an unknown time stays `null`. Write a human
   identifier only when it is known and may be published; otherwise
   omit the human identifier field — never infer it from the API login, and do
   not ask whether the posting account is the user. No recorder qualification is
   needed, and no PR body block.
2. Read it back; the actual author is recorded as the publisher, not as proof of
   who approved.
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
2. **Post the Closure and read it back.** Use the Closure layout under "Reply
   layouts": Outcome (about to close, and why — never "closed" yet), Result, Verification
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

## References

- Read [references/examples.md](references/examples.md) when writing a kind of description or reply you have
  not written in this session, or for a relayed report, a human author, missing
  Agent metadata, or a legacy body: it follows one piece of work from create
  through review, repair, handoff, and closure.
- Read [references/approval-records.md](references/approval-records.md) when recording an approval on the PR or looking one up:
  it holds the event layout, discovery, version comparison, and supersession.
