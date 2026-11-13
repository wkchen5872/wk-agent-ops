---
name: github-issue
description: >
  Create or update the GitHub Issue that tracks an OpenSpec change, following the
  project's shared handoff contract: exact-key duplicate detection, a full
  repository-target and authorization check before every write, readback of the
  result, and body updates that keep other authors' text. Works through gh or a
  configured GitHub MCP. Use whenever the user asks to open, register, link, or update a GitHub
  issue for a change, to record parent/child or dependency relations, or to note
  that acceptance is waiting on real data — for example "建立 issue", "開 issue",
  "更新 issue", "把這個 change 登錄到 GitHub", or just "git issue".
license: MIT
compatibility: "Requires git and either GitHub CLI (gh) or a GitHub MCP, already configured for the target host. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "1.1"
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

GitHub reads and writes go through one available, already configured tool: `gh`
or a GitHub MCP. The commands below are written for `gh`, always with an explicit
`-R <host>/<owner>/<repo>` so the CLI cannot pick another repository; with an MCP,
use its equivalent tools and pass the same full owner and repository. Do not add
a wrapper or adapter around either one. If neither can do the operation, stop and
report what is missing instead of installing a tool or logging in.

If the request does not say which operation is meant and the intent cannot tell
them apart, ask before doing anything.

## Shared steps

### Step 1 — Fix the target, the operation, and the authorization

1. Confirm the Change exists (`openspec list --json`, or its directory under
   `openspec/changes/`, including the archive).
2. Fix the full target — host, owner, and repository. Matching the host alone is
   not enough: a remote or a tool default that points at another repository on
   the same host is a different target. When the request and the local context
   disagree, stop and ask.
3. Confirm the operation and that the user authorized it. Choosing a tool never
   widens that authorization.

### Step 2 — Choose the tool and check what it can do

Pick `gh` or a configured GitHub MCP and check, in that tool's own context, that
it reaches the target and has the operation you need. Read whatever permission
information it offers, and use it only for what it actually covers: being able
to read a public repository, or holding a repository role, does not prove this
token or App can create or edit Issues. One tool's login is never evidence that
another tool can act.

- **Known blocker** — not signed in, wrong target, missing capability, or an
  explicit permission denial: stop and report it.
- **Incomplete permission information, no known blocker** — go ahead with the
  authorized operation and judge it by the actual response. Never create a test
  Issue just to find out whether you may.
- **Account restriction** — none by default. Only when the user or a trusted
  project rule names an account for this operation, check the account the tool
  actually uses; if it differs or cannot be shown, stop. Contract section 4.2.

Leave logins, tokens, and configuration alone; report authentication problems
for the user to fix. Record the tool you used and, when the tool reports it, the
acting account — or `unavailable`. Nothing from credential configuration goes
into output or records.

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

Read the Issue back by the number or URL the tool returned. Confirm it is in the
intended repository and the stored body carries both exact keys, then report the
URL. A denial is reported as a denial; nothing was created.

If the create call times out or its result is unknown, go back to Step 3 and
look again before any retry, with either tool — a blind resend, or the same
request through the other tool, is how duplicates appear. Search
can lag just after a write, so on this second look also list the Issues and
match the body directly:

```bash
gh issue list -R <host>/<owner>/<repo> --state all --limit 200 --json number,url,body \
  --jq '[.[] | select(.body | contains("openspec-change: <change-id>")) | {number, url}]'
```

If it is still inconclusive, report that instead of retrying.

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

Confirm the text outside the markers is unchanged. Take the body from the
structured response and parse it; with `gh`, printing it with `--jq .body` appends a newline, and a
read-modify-write through that grows the text after the block by one line each
time.

## Reporting

Say what now exists remotely (Issue URL), what was read but not changed, and
what is still open — for example a PR link not yet available or a parent Issue
not yet updated. When one step succeeded and a later one failed, report both;
a rerun finds the existing Issue by its keys instead of creating a second one.
A simulated or replayed run is never reported as a real write.

## Replay cases

`references/acceptance-cases.md` holds the replayable cases for this skill
(new, duplicate, several candidates, similar title, gh missing with MCP
available, MCP without the capability, denial, restriction mismatch, timeout,
partial success, split work, waiting, markers, secrets).
