---
name: openspec-commit
description: >
  Finish an OpenSpec change by coordinating archive, documentation update, and
  a conventional git commit, then — only when authorized — deliver it on its
  existing PR: normal push and head readback, github-pr update, a final-version
  review, and a ready-to-merge Closure through github-pr reply; or, for an
  explicitly cancelled or superseded PR, delegate github-pr close. Local
  completion is the default and never needs a PR. Resumes after partial
  failure from verified Git and PR evidence, including after the commit.
  Supports Claude Code, Codex, and Antigravity.
license: MIT
compatibility: Requires openspec CLI and git.
metadata:
  author: wkchen
  version: "3.0"
---

# OpenSpec Commit

Complete a feature inside its isolated worktree after implementation and
verification:

1. `openspec-archive-change`
2. `doc-updater`
3. `git-commit-writer`

Then, only when the request authorizes it, it delivers the result on the
Change's existing PR (Step 7). This skill coordinates those capabilities; it
does not duplicate their logic.

**Input:** An optional active change name. If omitted, resolve it from the
current OpenSpec and Git state. Never guess when multiple candidates exist.

GitHub formats, write-time checks, and readback rules come from the managed
`docs/github-handoff.md` (sections 3, 5, 6, 6.7 and 10); remote steps use the
`github-pr` and `change-review` skills rather than restating them.

---

## Delivery intent

Decide this before Step 1, from the current request and any explicit earlier
authorization for this Change. It picks how far the run goes; it never changes
Steps 1–6.

- **Local completion** — the default: archive, docs, and commit, then stop.
  A local commit request does not authorize push, PR creation, merge, or close,
  even when a PR is found.
- **Successful PR handoff** — the user authorized publishing this completion to
  the Change's PR. Steps 1–6, then Step 7a, which ends at a Closure that says
  the PR is ready for an authorized merge.
- **Abandoned PR closure** — the user explicitly asked to close the Change's PR
  as cancelled or superseded, with a reason. Steps 1–6, then Step 7b, which
  delegates `github-pr close`. Closing a PR without completing the Change is
  plain `github-pr close`, not this workflow, and cancellation is never reported
  as a finished implementation.

A missing PR never blocks local completion, and this workflow does not create
one. Never create a PR or an Issue, merge, close an Issue, or delete a branch
here. For a remote path, fix the target before the remote step: the full base
repository, the head repository, owner and branch, the Change it belongs to,
and the operation. An unknown PR or target is not permission to write anywhere:
the remote step is reported as pending or blocked, and the local steps still
complete. Missing authority is reported the same way. Reuse an authorization
only for the same target and action; never stretch it to another PR or step.

Look the PR up (a read, never a write) whenever a PR may exist, so a local run
can name the remote action still waiting. A lookup that times out may be read
once more; still unclear means `pr=unknown`. Report a remote step as
**pending** when it waits for authorization or a PR, and **blocked** when the
target cannot be confirmed or a read or write failed.

Authorizing delivery to the PR covers push, `github-pr update`, and the Closure.
The final review in Step 7a runs only when the request also asks for review or
acceptance of the final version; otherwise 7a stops before the Closure and says
the final head needs review.

Record:

```text
delivery=<local|handoff|abandon>
pr=<confirmed PR URL | none | unknown>
close_reason=<cancelled|superseded by <PR>, only for abandon>
```

Resolve available attribution at Step 5. Model precision or absence must not
block archive, documentation handling, or commit.

---

## Provider action routing

Invoke capabilities by name. Provider-native OPSX files are aliases for the
same OpenSpec action, not additional workflow steps.

| Provider | OpenSpec capability source | Native alias |
|---|---|---|
| Claude Code | `.claude/skills/openspec-archive-change/` | `.claude/commands/opsx/archive.md` |
| Codex | `.codex/skills/openspec-archive-change/` | skill invocation; no project command file |
| Antigravity | `.agent/skills/openspec-archive-change/` | `.agent/workflows/opsx-archive.md` |

The same OpenSpec naming pattern applies to
`openspec-apply-change`, `openspec-bulk-archive-change`, and
`openspec-continue-change`; their native OPSX action IDs are `apply`,
`bulk-archive`, and `continue`.

Project-owned portable skills from wk-agent-ops are installed separately to
`.claude/skills/` and the plural shared root `.agents/skills/`.

**Do not invoke both** an `openspec-*` capability and its OPSX alias. Invoke
exactly one provider entry point for the capability. If the host cannot nest a
skill call, follow the named capability's instructions in the current context.

---

## Step 1 — Resolve active or resumable context

Inspect both sources:

```bash
openspec list --json
git status --short
```

From Git status, collect top-level directories changed under
`openspec/changes/archive/`. These are resumable archives from an earlier run
whose archive step completed but docs or commit did not.

Resolution rules:

1. **Explicit change name**
   - Matching active change → select it for archive.
   - Otherwise, matching uncommitted archive (after stripping its date prefix)
     → select it and resume.
   - Otherwise, a committed archive for that exact name, confirmed through
     "Recovery after commit" → skip Steps 2–5 and continue at the first missing
     authorized remote step.
   - No match → stop and report the missing change.
2. **No explicit name**
   - Exactly one candidate across active changes and resumable archives → use it.
   - Multiple candidates → ask the user to select; do not guess.
   - No candidates → ask whether to run docs + commit without OpenSpec context.
     If declined, stop.

Before any archive, check the same status output for paths that belong to
other work (see Step 3). If there are any, stop now, so no half-finished archive
is left behind.

Record:

```text
change_id=<selected change, if any>
archive_path=<exact resumable archive path, if already archived>
resume=<true|false>
```

---

## Step 2 — Archive or resume

### Active change

Invoke exactly one provider entry point for the capability
`openspec-archive-change`, passing `change_id`.

Wait for its full flow, including artifact/task warnings and the spec-sync
decision. Both "sync" and an explicitly chosen "skip sync" are valid archive
outcomes.

Capture its result:

```text
change_id
archive_path
spec_sync_status=<synced|skipped|no_delta_specs>
warnings=<list, possibly empty>
```

Validate that the returned `archive_path` exists. If archive failed or the path
is absent, stop without invoking downstream capabilities.

### Resumable archive

Do not invoke archive again. Reuse the exact `archive_path` selected from Git
status, validate it exists, and set:

```text
spec_sync_status=already_archived
warnings=<preserved warning if sync status cannot be reconstructed>
```

### No OpenSpec context

Skip archive and leave `change_id` and `archive_path` empty.

---

## Step 3 — Prepare the complete diff

This workflow is an explicit request to commit all changes in the isolated
feature worktree. First read `git status --short --untracked-files=all` again. If any
path belongs to other work — another Change's directory, another agent's
untracked planning copy, files outside this Change's scope — stop before
staging, list those paths, and ask for them to be isolated. Never stash, reset,
delete, or commit them to make the worktree clean.

Otherwise, stage everything once so new files, spec sync, and the archive move
are visible to `doc-updater` through `git diff HEAD`:

```bash
git add -A
git diff --cached --stat
```

If the staged diff is empty, stop and report that there is nothing to document
or commit.

---

## Step 4 — Invoke doc-updater

Invoke exactly one provider entry point:

- **Claude Code:** invoke the provider-native `doc-updater-agent` subagent.
- **Codex:** spawn the provider-native `doc-updater-agent` custom agent.
- **Every other provider:** invoke the portable `doc-updater` skill from
  `.agents/skills/doc-updater/`. If the host cannot nest a skill call, follow
  that skill's instructions in the current context.

Claude Code and Codex MUST NOT silently fall back to the portable skill. If the
required subagent is unavailable, stop and report the missing provider
configuration.

For Claude Code and Codex, invoke the exact custom agent name only. Do not pass a spawn `model` or `reasoning_effort`; the provider-native agent configuration
owns those runtime settings.

Pass the selected entry point:

```text
change_id=<change_id, when available>
archive_path=<exact archive_path, when available>
```

`doc-updater` must combine archived proposal/spec intent with `git status` and
`git diff HEAD` evidence. Wait for it to complete, then capture:

```text
docs_updated=<list>
docs_skipped_reason=<reason, when no update was needed>
```

If an explicit archive path is invalid or documentation editing reports a
conflict, stop before commit.

---

## Step 5 — Invoke git-commit-writer

Resolve the attribution pair now, immediately before commit delegation:

```text
tool_name=<executing agent tool>
assisting_model=<current root-session model>
```

Use the agent tool that owns the root session (`Codex`, `Claude Code`, or
`Antigravity`), not an outer host surface. Record the most specific model name
actually known for the current root session. Accept `GPT-5`, `GPT-5.6`, or `GPT-6`; do not invent
a variant, version, or context size. Preserve a user-supplied name for this work
verbatim when it describes the current collaboration; otherwise use the current runtime model name automatically.
This records current collaboration, not original code authorship. Pre-existing
changes, another implementation session, or a commit-only root session MUST NOT
cause omission of a known current model. After a root model switch, use the
currently known model rather than a stale name from before the switch.
You MUST NOT ask the user to repeat it or provide a more precise name to commit.
Reuse confirmed attribution for later commits in the same session while the
root model remains unchanged.

Provider-native documentation and commit subagents MUST NOT replace or make the root-session attribution ambiguous.
Tool names are not model names. Only if the current root-session model is unknown, omit
`assisting_model` from the handoff and report the omitted `AI-Assisted-By` trailer;
do not block the commit. A known `GPT-5` MUST be recorded, not omitted.
MUST NOT parse session logs or use private transcript formats.
MUST NOT use documentation lookup, environment variables, or Git history to
infer a model name that is not available in the current context.

`assisting_model` is Git attribution metadata only, at the available precision.
It MUST NOT be used as a subagent spawn model or reasoning-effort override.
This workflow MUST NOT request or require `assisting_model` before archive or documentation handling.

Collect the GitHub Issues and PRs this Change directly addresses, as far as
they are already confirmed: the PR confirmed for this delivery, `issue` and
`pull-request` lines of a Handoff already read, or the user's own instruction —
each with its URL and that evidence. Background links, `references`, and
`depends-on` targets are passed only when
separately confirmed as directly addressed by this Change (for example, the
user says it also fixes that dependency); otherwise they are left out. When nothing is confirmed, omit the field;
no GitHub lookup is made just for commit metadata, so local or offline
completion is never blocked, and a confirmed URL needs no fresh login. Passing a
reference authorizes no publication or state change.

Pass the same exact archive context plus the tool, optional model, and any
confirmed references as task input (omit `assisting_model` when unknown and
`github_references` when none is confirmed):

```text
change_id=<change_id, when available>
archive_path=<archive_path, when available>
tool_name=<executing agent tool>
assisting_model=<current root-session model>
commit_repository=<host/owner/repo of this checkout, when confirmed>
github_references=<url=<Issue or PR URL> evidence=<how it was confirmed>, ...>
```

The writer formats them as one `Refs:` line (its "GitHub references" rules).
On recovery an existing completion commit is reused as it is — never amended
to add a reference discovered later.

- **Claude Code:** invoke the provider-native `git-commit-writer-agent`
  subagent with these values in its task prompt.
- **Codex:** spawn the provider-native `git-commit-writer-agent` custom agent
  with these values.
- **Every other provider:** invoke the portable `git-commit-writer` skill from
  `.agents/skills/git-commit-writer/`. If the host cannot nest a skill call,
  follow that skill's instructions in the current context.

Claude Code and Codex MUST NOT silently fall back to the portable skill. If the
required subagent is unavailable, stop and report the missing provider
configuration. The commit-only agent must preserve `assisting_model`; it MUST
NOT replace the current root-session model with its own model.

For Claude Code and Codex, invoke the exact custom agent name only. Do not pass a spawn `model` or `reasoning_effort`; the provider-native agent configuration
owns those runtime settings.

The writer owns final staging, empty-diff validation, commit execution, and
restaging before a pre-commit retry. Wait for and capture `commit_hash`.

---

## Step 6 — Verify and summarize

Inspect the result:

```bash
git show --stat --oneline HEAD
git status --short
```

Report each stage from "Stage outcomes" separately. For local completion:

```text
✅ Feature committed

📦 Archive: <archive_path or "No OpenSpec context">
   Specs:   <spec_sync_status>
   Warnings: <warnings or "None">

📝 Docs:
   <docs_updated or docs_skipped_reason>

💾 Commit: <commit_hash and subject>

🌐 Remote: <not requested | pending: <what is waited for> | blocked: <reason> | continued in Step 7>
```

If Git status still contains changes, list them and do not claim the worktree is
clean. With `delivery=local`, stop here; when a PR is known, name the remote
action still waiting for its own authorization. For `delivery=abandon`, the
heading reads "Change archived as cancelled", never "Feature committed", and no
stage is described as a finished implementation.

Next step for the documented worktree flow:

```text
wt-done <feature-name>
```

---

## Step 7 — Remote delivery (only when authorized)

Runs after a confirmed commit, and only for `delivery=handoff` or
`delivery=abandon` with a confirmed PR. A failure here never undoes the archive
or the commit; report what completed and stop at the failed stage. Invoke
`github-pr` and `change-review` through exactly one provider entry point each,
as for the other capabilities.

### 7a — Successful PR handoff

1. **Publish the commit normally.** Pin the commit this run delivers:

   ```text
   intended_sha=<completion commit>
   ```

   Confirm the push destination names the PR's head repository and branch,
   push without force, and read the remote head back:

   ```bash
   git remote get-url --push <remote>
   git push <remote> HEAD:refs/heads/<head-branch>
   git ls-remote <remote> refs/heads/<head-branch>
   ```

   Read the remote head first; skip the push when it already equals the
   commit. When resuming, `HEAD` must equal the recovered commit before
   pushing; otherwise stop. A PR that is already merged or closed is reported
   in its actual state and 7a stops — new commits need a separately authorized
   follow-up PR. A rejected
   push (non-fast-forward, denial, hook) stops here with Git's message and the
   remote head — never pull, rebase, or force-push to get past it, and never
   describe the unpushed commit as published.
2. **Check the head, then describe it.** Right before the update, read the
   remote head and the PR head:

   ```bash
   git ls-remote <remote> refs/heads/<head-branch>
   gh pr view <number> -R <host>/<owner>/<repo> --json headRefOid
   ```

   `intended_sha`, the remote head, and the PR's `headRefOid`:
   all three must be the same SHA. If someone pushed after this run (the remote or PR now shows
   another commit), report both SHAs and stop before the update, the review,
   and the Closure. Report that `intended_sha` was pushed and read back, without
   claiming it is still on the branch; the newer commit needs its own decision.
   Never switch to delivering the newer head. When all three agree, invoke `github-pr update` for the
   confirmed PR so Summary, Changes, Verification, and Next actions describe
   `intended_sha`.
3. **Final-version review.** An earlier pass never covers a new head: the
   archive move, spec sync, and documentation commit are new content. Reuse a
   review only when its reviewed head equals the published head. Otherwise,
   when the authorization covers it, invoke `change-review` once for that head;
   if it does not, stop and report that the final head needs review. A
   `changes-required` or `blocked` result, or a head that moved during the
   review, stops the handoff: report it and the next step, with no automatic
   fix, re-review, or polling.
4. **Ready-to-merge Closure.** Read the PR head again. With review evidence
   bound to that current head, invoke `github-pr reply` with a Closure (contract section 6.7):
   Outcome "ready for an authorized merge" at that head, Delivered,
   Verification with the review link, Remaining work, Next actions pointing at
   the merge owner, and the posting Author. Read it back. The Closure states that
   merge, deployment, and Issue acceptance have not happened.
   Successful handoff never uses close, and nothing here merges.

### 7b — Abandoned PR closure

Invoke `github-pr close` once for the confirmed PR with the evidenced reason
(cancelled, or superseded by a named PR). It owns the Closure, its readback,
the re-check, the close, and the state readback, so this workflow posts
no preliminary Closure of its own. A cancelled PR does not need a passing review,
and abandoned local work is not pushed to make the PR look complete. Linked
Issues, dependencies, and the branch stay as they are; Issue closure is a
separate `github-issue close`. A PR that is already merged or closed is reported
in its actual state — never reopened or closed again. Missing reason or close
authorization: keep the local result and report what is needed.

---

## Recovery after commit

Rebuild progress from evidence that already exists — the selected Change, its
exact archive path, local history, the remote head, and the PR's comments and
state. There is no persistent state file. After the commit, the archive no
longer shows in `git status`, so look it up by the exact name:

```bash
git log -1 --format=%H -- openspec/changes/archive/<archive-dir>/
git ls-remote <remote> refs/heads/<head-branch>
```

The commit must contain that archive and only this Change's work. Several
archive directories or completion commits for the same name, or no
explicitly named Change or confirmed PR to tie them to: list what was found and
ask. Never take the newest.

| Confirmed state | Continue with |
|---|---|
| Archive done, no commit | Reuse the exact archive; resume at docs/commit (Step 1 resume) |
| Commit confirmed, push missing | Verify the commit's archive and scope; push only if authorized; no new commit |
| Push confirmed, PR update missing | Keep the push; read the PR head; run only `github-pr update` |
| Update done, final review missing or stale | Run or request one review for the current head |
| Closure confirmed, close missing | Let `github-pr close` read the state and reuse the confirmed Closure; post no second one |
| Any result unknown | Read the current state first; if still unclear, report it as uncertain and resend nothing |
| Closure timed out, re-read finds none | Treat it as not posted; one retry through the same tool, then read back |

Recovery reuses an earlier authorization only for the same target and action.

---

## Stage outcomes

Report every applicable stage on its own line with its evidence. A stage that
did not run is "not performed" with the reason; an unconfirmed write is
"uncertain"; nothing is implied by a later stage's success, and no URL is
reported unless it was returned and read back.

| Stage | Report |
|---|---|
| archive | `archive_path`, `spec_sync_status`, warnings — or reused/resumed |
| docs | files updated, or the reason none were needed |
| commit | hash and subject, or "existing commit reused" |
| push | remote head read back, rejected with Git's message, or not requested |
| PR update | read-back result, failure, or not performed |
| final review | reviewed head, verdict, report URL — or stale, missing, not authorized |
| Closure | comment URL read back, uncertain, or not performed |
| close | `CLOSED` read back, failed, already ended, or not requested |

Merge, deployment, and Issue acceptance are never reported as done by this
workflow.

---

## Error handling

| Situation | Action |
|---|---|
| Multiple active/resume candidates | Ask the user; never select the first |
| Archive fails or path is absent | Stop before docs and commit |
| Explicit archive context is invalid | Stop; do not fall back to newest archive |
| Doc update conflicts | Stop and show the conflicting files |
| Commit hook fails | Let `git-commit-writer` fix, restage, and retry without `--no-verify` |
| Workflow is rerun after archive | Resume from the exact uncommitted archive |
| Worktree holds other work | Stop before staging; list the paths |
| Remote delivery not authorized, or PR/target unknown | Finish locally; report the remote step as pending |
| Push rejected | Stop; report Git's message and remote head; never force |
| Remote or PR head differs from `intended_sha` before update | Stop before update, review, and Closure; report both SHAs |
| PR head differs from the reviewed head | Stop before Closure; the new head needs its own review |
| Final review missing, not authorized, or not passing | Stop before Closure; report the next step |
| Close reason or authorization missing | Keep local results; report what is needed |
| Write result unknown | Reconcile from the remote or PR first; do not resend |

## References

- [references/acceptance-cases.md](references/acceptance-cases.md) — replayable
  cases for local completion, delivery intent, handoff, abandonment, partial
  failures, and recovery.
- [references/examples.md](references/examples.md) — worked stage reports from
  the same sources.
