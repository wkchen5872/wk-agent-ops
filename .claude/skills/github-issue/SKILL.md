---
name: github-issue
description: >
  Create or update the GitHub Issue that tracks an OpenSpec change, following the
  project's shared handoff contract: exact-key duplicate detection, a read-only
  identity check before every write, and body updates that keep other authors'
  text. Use whenever the user asks to open, register, link, or update a GitHub
  issue for a change, to record parent/child or dependency relations, or to note
  that acceptance is waiting on real data — for example "建立 issue", "開 issue",
  "更新 issue", "把這個 change 登錄到 GitHub", or just "git issue".
license: MIT
compatibility: "Requires git and GitHub CLI (gh) authenticated for the target host. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "1.0"
---

# GitHub Issue

A thin entry for the Issue side of the GitHub handoff. The Issue is the stable
place a new session opens to find the Change, its published version, who owns
the next step, and what it is waiting on.

`docs/github-handoff.md` owns every template, field meaning, and rule. This
skill only sequences the work. **Read that contract first** — sections 3–7 and
11 — and take block layouts and field names from it rather than from memory, so
the Issue, PR, and review records stay on one schema.

## What this skill may change

| Operation | Needs | Side effect when authorized |
|---|---|---|
| `create` | Change, explicit repository | Creates one Issue, or returns the existing one |
| `update` | Issue URL or number, the fields to change | Rewrites its own managed block in that Issue |

It never stages, commits, pushes, closes or reopens an Issue, or replaces labels
and assignees wholesale. Those need their own request.

GitHub reads and writes go through `gh`, always with an explicit
`-R <host>/<owner>/<repo>` so the CLI cannot pick another repository. There is no
MCP path in this version: if `gh` is missing or lacks permission, stop and
report it instead of installing, logging in, or switching to another client.

If the request does not say which operation is meant and the intent cannot tell
them apart, ask before doing anything.

## Shared steps

### Step 1 — Resolve the target and the trusted policy

1. Confirm the Change exists (`openspec list --json`, or its directory under
   `openspec/changes/`, including the archive).
2. Take host, repository, and `api_actor` from the trusted identity policy
   (contract section 3) or from the user's explicit input for this task. Fix
   `policy_source` now: the full commit ID that holds the policy block, or
   `user-input`.
3. If the policy is missing, incomplete, or ambiguous, stop and ask. Do not
   infer the account from `git config`, the remote URL, or an Issue's content.

### Step 2 — Run the api identity check

From the project root, before the first `gh` call:

```bash
bash scripts/github/check-identity.sh --operation api \
  --policy-source <policy_source> \
  --host <host> --repo <owner/repo> --api-actor <expected login>
```

Continue only when it exits 0 with `status=pass`. On any other result, stop and
report `status`, `reason`, and the expected and actual values it printed. The
check exists because several accounts can be signed in on one machine, and a
wrong one writes to the wrong place under the wrong name; "fixing" the result by
switching accounts would defeat it, so leave login, tokens, and configuration
alone and let the user decide.

If the script is absent, stop and report that too; restoring it means re-running
the project's installer, which is the user's call. Do not substitute your own
commands for it. When the working copy of the script may have been changed by
the work under review, obtain it as contract section 4.3 describes.

Rerun the check if the environment, account, or repository changes before the
write.

## Operation: create

### Step 3 — Look for an existing association

Use an explicit Issue URL when one is known. Otherwise search for candidates,
then **read each candidate's body** and compare both exact keys:

```bash
gh issue list -R <host>/<owner>/<repo> --state all \
  --search '"openspec-change: <change-id>" in:body' --json number,title,url,state
gh issue view <number> -R <host>/<owner>/<repo> --json body,url,state
```

A search hit or a similar title proves nothing; only matching
`openspec-change` and `repository` keys do.

- **One confirmed Issue** — return it. Do not create another and do not rewrite
  its body.
- **None** — continue to Step 4. Mention any near-miss whose keys differed.
- **Several** — list them and stop. Never pick the first.

### Step 4 — Compose the body

Fill the Issue block from contract section 6.1 and the provenance fields from
section 7. Keep it a tracking record: summarize the goal and link the
artifacts; do not copy `tasks.md`.

- `artifacts` is a repo-relative path plus a link to the published revision. If
  the artifacts are not on the remote yet, write `local-only／待發布` — never
  invent a commit link, and do not commit or push to obtain one.
- Unknown provenance values are omitted or marked as the contract says, not
  guessed. No absolute local paths, no hostname.

### Step 5 — Create, then verify

```bash
gh issue create -R <host>/<owner>/<repo> --title "<title>" --body-file <file>
gh issue view <number> -R <host>/<owner>/<repo> --json body,url
```

Confirm the stored body carries both exact keys, then report the URL.

If the create call times out or its result is unknown, go back to Step 3 and
look again before any retry — a blind resend is how duplicates appear. If the
second look is still inconclusive, report that instead of retrying.

## Operation: update

### Step 3 — Read the latest body and locate the block

```bash
gh issue view <number> -R <host>/<owner>/<repo> --json body,url,state
```

- **Exactly one start and one end marker** — continue.
- **No markers** — stop and report. Add a block only when the user explicitly
  asks to adopt this Issue. Before adopting, run the create operation's Step 3
  so that no other Issue already carries the same keys; then append the block
  after the original text and leave that text untouched. See
  `references/examples.md`.
- **Half a pair or several pairs** — stop and report; do not guess which is real.

If another writer is known to be updating the same block, stop and ask the user
to name one writer. Reading before writing does not make this safe.

### Step 4 — Change only what was asked

Edit the requested fields inside the block and add one provenance line for this
update. Leave earlier provenance, every other field, and all text outside the
markers exactly as it was. Relations and waiting-for-data records follow
contract section 6.1; worked examples are in `references/examples.md`.

A date arriving, a review passing, or a PR merging does not complete acceptance
and does not close the Issue.

### Step 5 — Write back, then verify

```bash
gh issue edit <number> -R <host>/<owner>/<repo> --body-file <file>
gh issue view <number> -R <host>/<owner>/<repo> --json body
```

Confirm the text outside the markers is unchanged.

## Reporting

Say what now exists remotely (Issue URL), what was read but not changed, and
what is still open — for example a PR link not yet available or a parent Issue
not yet updated. When one step succeeded and a later one failed, report both;
a rerun finds the existing Issue by its keys instead of creating a second one.
A simulated or replayed run is never reported as a real write.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases for this skill
(new, duplicate, several candidates, similar title, missing tool or script,
non-pass check, timeout, partial success, split work, waiting, markers).
