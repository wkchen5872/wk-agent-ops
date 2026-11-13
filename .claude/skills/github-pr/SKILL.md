---
name: github-pr
description: >
  Create a pull request for an OpenSpec change, publish a new version to an
  existing PR, or update only its description, following the project's shared
  handoff contract: full-worktree inspection before any commit, separate
  read-only identity checks before commit, push, and API writes, and body
  updates that keep other authors' text. Use whenever the user asks to open a
  PR, push or publish a change's spec or implementation, refresh a PR summary,
  add a review link, or record a design approval on a PR — for example
  "建立 PR", "發 PR", "發布這個版本", "更新 PR 說明", "把批准記到 PR".
license: MIT
compatibility: "Requires git and GitHub CLI (gh) authenticated for the target host. Uses the git-commit-writer skill or agent when a commit is needed. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "1.0"
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

GitHub reads and writes go through `gh`, always with an explicit
`-R <host>/<owner>/<repo>`; commit and push go through `git`. There is no MCP
path in this version: if `gh` is missing or lacks permission, stop the operation
and report it instead of installing, logging in, or switching clients.

Merge, Draft/Ready, deploy, archive, and Issue close are separate actions with
their own authorization. This skill does none of them.

## Shared steps

### Step 1 — Resolve the target and the trusted policy

1. Confirm the Change, the Issue, the phase, and the base and head: repository
   and branch for each. Do not assume a fork and its base are the same
   repository; check the PR input.
2. Take the expected identities from the trusted identity policy (contract
   section 3) or the user's explicit input. Fix `policy_source` now — the full
   commit ID holding the policy block, or `user-input` — and use it for every
   check in this run.
3. If the policy is missing, incomplete, or ambiguous for an identity this
   operation needs, stop and ask. A policy changed by the branch under review is
   not a trusted source.

### Step 2 — Identity checks, one per kind of write

From the project root. Each check covers one kind of write and is not evidence
for another: a matching API login says nothing about who the push authenticates
as.

```bash
bash scripts/github/check-identity.sh --operation api    --policy-source <policy_source> --host <host> --repo <owner/repo> --api-actor <login>
bash scripts/github/check-identity.sh --operation commit --policy-source <policy_source> --author-name "<name>" --author-email <email> --committer-name "<name>" --committer-email <email>
bash scripts/github/check-identity.sh --operation push   --policy-source <policy_source> --host <host> --repo <owner/repo> --remote <remote> --protocol <ssh|https> --push-actor <login> --ref <branch>
```

Run each one immediately before the write it covers, and the api check also
before the first `gh` call. Continue only on exit 0 with `status=pass`. On
anything else, stop that write and report `status`, `reason`, and the printed
evidence. Leave accounts, tokens, keys, remotes, and Git configuration alone —
changing them to get a pass is exactly what the check is there to prevent.

If the script is absent, stop and report it; restoring it means re-running the
project's installer, which is the user's call. Do not rebuild the check from
other commands.
When the branch under review may have changed the script, obtain it as contract
section 4.3 describes.

### Step 3 — Look for an existing PR

```bash
gh pr list -R <host>/<owner>/<repo> --head <head-branch> --state all \
  --json number,url,state,headRefName,headRefOid
gh pr view <number> -R <host>/<owner>/<repo> --json body,url,state,headRefOid
```

Confirm a candidate by its exact keys, repository, and head branch (contract
section 5), not by its title.

- `create` with a confirmed open PR — return it, say that shipping new commits
  needs `publish`, and stop. Nothing is committed or pushed.
- `publish` — requires exactly one confirmed PR. None or several: stop.
- A merged PR — new changes need an explicitly authorized follow-up PR
  (contract section 10). Pushing to the old branch is not a completed review.
- If a create call times out or its result is unknown, run this step again
  before any retry.

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

1. Run the **commit** check.
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

1. Run the **push** check.
2. Push without force, to the verified branch:

   ```bash
   git push <remote> HEAD:refs/heads/<head-branch>
   git ls-remote <remote> refs/heads/<head-branch>
   ```

3. The remote head must equal the local `HEAD` before anything describes it as
   published.

If the push is blocked or rejected, read the remote head with `git ls-remote`
and report the local commit and the remote state separately — "committed as
`<sha>`, not published". Do not force, pull, rebase,
or create another commit to get past it; a later run reuses the same commit.

### Step 7 — Write the PR

1. Run the **api** check again; time has passed since the first one.
2. Compose the PR block from contract section 6.2 and provenance from section 7.
   The head SHA is the one the remote reported in Step 6.
3. `create`:

   ```bash
   gh pr create -R <host>/<owner>/<repo> --draft --base <base-branch> \
     --head <head-branch> --title "<title>" --body-file <file>
   ```

   `publish`: read the latest description and rewrite only the block, as in the
   update operation below, with `gh pr edit`.
4. Verify:

   ```bash
   gh pr view <number> -R <host>/<owner>/<repo> --json url,headRefOid,body
   ```

A new PR starts with `design-approval` pending. `publish` to a PR that already
carries the design version updates that same PR; it does not open a second one
and leaves the recorded approval as it is.

## Operation: update

This path never runs `git add`, `git commit`, `git push`, a merge, a base
change, a close, or a Draft/Ready switch. If the request needs one of those, it
is a different operation.

1. Run the **api** check.
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
5. Change only the requested section and add one provenance line. Earlier
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

1. Run the **api** check — the comment's real author is what a later session
   will verify.
2. Post the approval event as its own comment, using the template in contract
   section 6.3: the human approver, scope, approved design revision, source
   kind, and who recorded it. Unknown times stay `null`.

   ```bash
   gh pr comment <number> -R <host>/<owner>/<repo> --body-file <file>
   ```

3. Update the block's approval section to point at that comment.

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
verified. Report the PR URL, the remote head, which checks ran with what result,
and what is still unverified or waiting. After a partial failure, say exactly
which steps completed so a rerun does not repeat them. A simulated or replayed
run is never reported as a real commit, push, or PR.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases for this skill
(clean and mixed worktrees, wrong identity or remote, missing tool or script,
unsupported push route, hook and push failures, description updates, existing
PRs, and approval recording).
