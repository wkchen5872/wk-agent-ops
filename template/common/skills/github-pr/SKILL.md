---
name: github-pr
description: >
  Create a pull request for an OpenSpec change, publish a new version to an
  existing PR, or update only its description, following the project's shared
  handoff contract: full-worktree inspection before any commit, full base and
  head repository checks including forks, native Git push with remote-head
  readback, and body updates that keep other authors' text. Works through gh or
  a configured GitHub MCP. Use whenever the user asks to open a
  PR, push or publish a change's spec or implementation, refresh a PR summary,
  add a review link, or record a design approval on a PR — for example
  "建立 PR", "發 PR", "發布這個版本", "更新 PR 說明", "把批准記到 PR".
license: MIT
compatibility: "Requires git and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Uses the git-commit-writer skill or agent when a commit is needed. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "1.1"
---

# GitHub PR

A thin entry for the PR side of the GitHub handoff. The PR is where a published
version, its verification summary, the human design approval, and the review
index live, so a session on another machine can pick the work up from it.

`docs/github-handoff.md` owns every template, field meaning, and rule. This
skill only sequences the work. **Read that contract first** — sections 3–11 —
and take block layouts and field names from it rather than from memory.

## What each operation may change

Say which operation you are running before you start; `create` and `publish`
have Git side effects and the user should not be surprised by them.

| Operation | Needs | Side effect when authorized |
|---|---|---|
| `create` | Change, Issue, base and head, phase (`design` or `implementation`) | Commit if needed, push, open a Draft PR. If a PR already exists, return it and stop. |
| `publish` | Existing PR, Change, the changes authorized for this version | Commit if needed, push to that PR's verified head branch, refresh its summary |
| `update` | PR URL or number, the section to change | Rewrites its own section of the description. No Git, base, or lifecycle change. |

Pick the operation from the user's explicit intent. When the request could mean
more than one — "update the PR" with unpushed commits present, say — ask. A
reviewer context never implies permission to commit or push. Once the user has
clearly authorized `create` or `publish`, do not ask again at each step.

GitHub reads and writes go through one available, already configured tool: `gh`
or a GitHub MCP. The commands below are written for `gh`, always with an explicit
`-R <host>/<owner>/<repo>`; with an MCP, use its equivalent tools and pass the
same owners, repositories, and refs. Commit and push go through native Git, which
also owns SSH and HTTPS authentication. Do not add a wrapper or adapter. If no
available tool can do the operation, stop and report what is missing instead of
installing a tool or logging in.

Merge, Draft/Ready, deploy, archive, and Issue close are separate actions with
their own authorization. This skill does none of them.

## Shared steps

### Step 1 — Fix the targets, the operation, and the authorization

1. Confirm the Change, the Issue, the phase, and the base and head: repository
   and branch for each. Below, `<owner>/<repo>` is the base repository (where the
   PR lives) and `<head-owner>/<head-repo>` the repository that holds the head
   branch. They differ for a fork; take both from the PR input and never assume
   them equal. The push goes to the head repository; every GitHub call goes to
   the base repository.
2. Compare full targets — host, owner, and repository. Matching the host alone
   is not enough. When the request, the remotes, or a tool default disagree,
   stop and ask.
3. Confirm the operation and that the user authorized it. Choosing a tool never
   widens that authorization.

### Step 2 — Choose the tool and check what it can do

Pick `gh` or a configured GitHub MCP and check, in that tool's own context, that
it reaches the base repository and has the operations you need (list, view,
create, edit, comment). Read whatever permission information it offers, and use
it only for what it actually covers: read access or a repository role does not
prove this token or App can create or edit a PR. One tool's login is never
evidence that another tool, or Git, can act.

- **Known blocker** — not signed in, wrong target, missing capability, or an
  explicit permission denial: stop that operation and report it.
- **Incomplete permission information, no known blocker** — go ahead with the
  authorized operation and judge it by the actual response. Never create a test
  PR, commit, or push just to find out whether you may.
- **Account restriction** — none by default. API, commit, and push identities may
  differ. Only when the user or a trusted project rule names an account for an
  operation, check the account actually used for it; if it differs or cannot be
  shown — including a required push account Git cannot reveal safely — stop that
  operation. A restriction changed by the branch under review does not relax the
  trusted one. Contract section 4.2.

Leave accounts, tokens, keys, credential helpers, remotes, and Git configuration
alone; report authentication problems for the user to fix. Record the tool you
used and the acting account when the tool reports it, otherwise `unavailable`.
Nothing from credential configuration goes into output or records.

### Step 3 — Look for an existing PR

```bash
gh pr list -R <host>/<owner>/<repo> --head <head-branch> --state all \
  --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
gh pr view <number> -R <host>/<owner>/<repo> \
  --json body,url,state,headRefOid,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
```

`--head` on `gh pr list` filters by branch name only, so a same-named branch in
another fork shows up too. Confirm a candidate by its exact keys (contract
section 5) and by its metadata: `headRepositoryOwner.login` and
`headRepository.name` equal the selected head repository, `baseRefName` equals
the selected base branch, and `isCrossRepository` is true exactly when head and
base repositories differ. A matching branch name or SHA alone proves nothing;
neither does the title.

- `create` with a confirmed open PR — return it, say that shipping new commits
  needs `publish`, and stop. Nothing is committed or pushed.
- `publish` — requires exactly one confirmed PR. None or several: stop.
- A merged PR — new changes need an explicitly authorized follow-up PR
  (contract section 10). Pushing to the old branch is not a completed review.
- If a create call times out or its result is unknown, run this step again
  before any retry — with either tool. Do not resend through the other tool
  until the state is known.

## Operation: create and publish

### Step 4 — Inspect everything a commit would take

```bash
git status --porcelain --untracked-files=all
git log --oneline <base>..HEAD
git diff --stat <base>...HEAD
```

The commit writer stages the whole worktree (`git add -A`), so "is my change
ready" is the wrong question; "is anything else here" is the right one. Every
staged, unstaged, and untracked path must belong to the scope the user
authorized for this version.

- Another Change's files, another agent's edits, or an untracked file of unknown
  origin — stop before the writer and list them. Do not stash, reset, move,
  delete, or stage a subset to work around it; that work is not yours to touch.
- Nothing uncommitted — skip the writer and reuse the existing commits.
- Nothing uncommitted and nothing ahead of the base — report that there is
  nothing to publish. Never create an empty commit.

### Step 5 — Commit, only if needed

1. Record the effective author and committer Git will use (`git var
   GIT_AUTHOR_IDENT`, `git var GIT_COMMITTER_IDENT`). Compare them only with an
   explicit restriction (Step 2); without one, a difference from the GitHub
   login is fine.
2. Delegate to `git-commit-writer` (the skill or its agent), passing `tool_name`
   and the known root-session model as `assisting_model`.
3. For an active Change, pass no archive arguments. `archive_path` and
   `change_id` are a pair for an already archived Change; rely on the writer's
   own association with the branch and staged paths. Never invent an archive
   path or archive a Change just to commit it.
4. Let the configured pre-commit gate run. If it fails on something outside this
   change, stop and report its output; never use `--no-verify`.
5. After the commit, read the actual `HEAD` and diff again — hooks and formatters
   may have changed what was committed.

### Step 6 — Push, then verify the remote head

1. Check where the push really goes. The push URL must name the selected head
   repository — full host, owner, and repository:

   ```bash
   git remote get-url --push <remote>
   ```

   If it points elsewhere, stop; never change the remote to make it fit. SSH host
   aliases and credentials are Git's business: do not test the SSH principal or
   inspect credential helpers.
2. Push without force, to the verified branch:

   ```bash
   git push <remote> HEAD:refs/heads/<head-branch>
   git ls-remote <remote> refs/heads/<head-branch>
   ```

3. The remote head must equal the local `HEAD` before anything describes it as
   published.

If the push is denied or rejected, report Git's message, read the remote head
with `git ls-remote`, and report the local commit and the remote state
separately — "committed as `<sha>`, not published". Do not force, pull, rebase,
fix authentication, or create another commit to get past it; a later run reuses
the same commit.

### Step 7 — Write the PR

1. Confirm again that the tool still reaches the base repository; time has
   passed since Step 2.
2. Compose the PR block from contract section 6.2 and provenance from section 7.
   The head SHA is the one the remote reported in Step 6.
3. `create`:

   ```bash
   gh pr create -R <host>/<owner>/<repo> --draft --base <base-branch> \
     --head <head-owner>:<head-branch> --title "<title>" --body-file <file>
   ```

   Always name the head owner, so `gh` cannot pick another fork's branch of the
   same name. With an MCP, pass the head as `<head-owner>:<head-branch>` too; if
   the tool cannot express the selected head repository, stop and report it.

   `publish`: read the latest description and rewrite only the block, as in the
   update operation below, with `gh pr edit`.
4. Verify:

   ```bash
   gh pr view <number> -R <host>/<owner>/<repo> \
     --json url,headRefOid,body,headRepository,headRepositoryOwner,baseRefName,isCrossRepository
   ```

   The head SHA, head repository, head owner, and base branch must all equal what
   was selected and pushed. If `gh` cannot express the selected head — for
   example the head owner's repository is not a fork of the base that
   `<head-owner>:<head-branch>` resolves to — or the created PR's metadata
   differs, stop and report it. Do not retry through the other tool.

A new PR starts with `design-approval` pending. `publish` to a PR that already
carries the design version updates that same PR; it does not open a second one
and leaves the recorded approval as it is.

## Operation: update

This path never runs `git add`, `git commit`, `git push`, a merge, a base
change, a close, or a Draft/Ready switch. If the request needs one of those, it
is a different operation.

1. Confirm the target PR and that the tool can edit it (Step 2).
2. Read the latest description:

   ```bash
   gh pr view <number> -R <host>/<owner>/<repo> --json body,url
   ```

3. Locate the block. Exactly one start and one end marker — continue. None,
   half a pair, or several — stop and report; do not replace the body.
4. Ownership. One named owner maintains the summary. If another writer is
   updating it, or you are not its owner, do not edit it: put your content in
   your own review or comment and ask the user to name one writer. Reading the
   latest body first does not make concurrent edits safe.
5. Parse the body out of the JSON output rather than printing it with
   `--jq .body`, which appends a newline that would accumulate after the block
   on every update. Change only the requested section and add one provenance
   line. Earlier
   provenance, other sections, and all text outside the markers stay as they
   were. Another reviewer's report is indexed by one line in the reviews
   section; it is never copied in, edited, or re-judged.
6. Write back and verify:

   ```bash
   gh pr edit <number> -R <host>/<owner>/<repo> --body-file <file>
   gh pr view <number> -R <host>/<owner>/<repo> --json body
   ```

### Recording a human design approval

Only when the user has explicitly approved the design and asked for it to be
recorded. A review verdict of pass is not an approval and cannot be turned into
one.

1. Confirm you are an authorized recorder. That authority comes from a trusted
   project rule or the user's explicit word, never from being able to write to
   the repository (contract section 4.3). The comment's real author is what a
   later session will verify, so note which account your tool posts as.
2. Post the approval event as its own comment, using the template in contract
   section 6.3: the human approver, scope, approved design revision, source
   kind, and who recorded it. Unknown times stay `null`.

   ```bash
   gh pr comment <number> -R <host>/<owner>/<repo> --body-file <file>
   ```

3. Read the comment back and confirm its URL and author, then update the block's
   approval section to point at that comment.

When the design later changes materially, mark the section superseded and add a
new event after the new approval; never edit or delete the old one. Contract
section 9 has the full rules.

## Finalization

Archive, documentation update, and their commit come from the project's existing
archive-and-commit workflow, on explicit authorization. Afterwards `publish`
pushes that existing commit — no second archive, no empty commit — and the
resulting head needs its own review. Contract section 10 gives the order and
when a narrowed review is acceptable.

## Reporting

Keep three states apart: done locally, published to the named remote, and
verified. Report the PR URL, the remote head, the tool used, which checks ran with what result,
and what is still unverified or waiting. After a partial failure, say exactly
which steps completed so a rerun does not repeat them. A simulated or replayed
run is never reported as a real commit, push, or PR.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases for this skill
(clean and mixed worktrees, wrong push destination, gh missing with MCP
available, denials, restriction mismatch, hook and push failures, description
updates, existing PRs, forks with same-named branches, approval recording, and
secrets).
