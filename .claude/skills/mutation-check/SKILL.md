---
name: mutation-check
description: >
  Provider-neutral mutation testing audit for changed production code. Uses
  mutmut or Stryker, reports tool-native outcomes, and preserves human triage.
license: MIT
compatibility: "Requires git and a project configured by mutation-setup. Python: mutmut v3. TS/JS: StrykerJS."
metadata:
  author: wk-agent-ops
  version: "1.1"
---

# mutation-check

Audit whether existing tests detect deliberate faults in changed production
code. This skill is advisory: it never applies a fixed score gate, blocks a
commit, or edits production code/tests itself.

Invoke it by name on any Provider that supports project skills.
**Provider-specific example:** Claude Code may expose `/mutation-check`; other
Providers need no slash command or hook.

> Commands target current mutmut v3 and StrykerJS. If an interface differs, stop
> and verify the current official documentation rather than improvising.

## Step 1 — Resolve root and affected project units

Resolve the repository root in this order:

1. explicit user target;
2. `git rev-parse --show-toplevel`;
3. normalized Provider-supplied project directory;
4. `PWD` only when Git cannot resolve a root.

Compute the changed production files in Step 4, then map each to its nearest
Python (`pyproject.toml`, `setup.cfg`, `setup.py`) or TS/JS (`package.json`)
manifest. Each unique owner is an **affected project unit**. If ownership is
ambiguous, list candidates and ask; do not run multiple units by guesswork.

## Step 2 — Setup gate

For every selected unit, verify the mutation tool, configuration, and baseline
test command are present:

- mutmut: installed in the project environment and configured with
  `[tool.mutmut] source_paths` (or the current supported equivalent);
- StrykerJS: installed through the project package manager with a readable
  Stryker config.

If anything is missing, stop that unit without installing. Suggest the portable
skill `mutation-setup` (**Provider-specific example:** `/mutation-setup` in
Claude Code).

## Step 3 — Baseline gate

Run the affected project unit's existing **baseline tests** before mutation.
Use the project-defined command; if several commands are plausible, ask the
user. Record command, exit status, and a short sanitized result.

For mutmut projects, ensure the command targets the real tests or excludes the
mutmut-generated `mutants/` directory. A duplicate-module collection error from
that directory is a setup failure, not valid baseline evidence.

- pass → continue;
- fail/error → report `invalid audit: baseline failed`, do not run mutation,
  do not calculate a score, and do not update `last_scan_commit`.

## Step 4 — Compute changed-code focus

Choose the diff base:

1. dirty worktree → tracked changes relative to `HEAD`, plus untracked
   production files from `git ls-files --others --exclude-standard`;
2. clean feature branch → changes since the merge-base with the default branch;
3. clean default branch → changes since `last_scan_commit` in the state file;
4. no usable state → explain the limitation and ask for an explicit base rather
   than silently assuming `HEAD~1`.

Exclude test/spec fixtures and map remaining files to affected project units.
If none remain, report `No mutable changed files in scope` and stop without
claiming an audit passed.

## Step 5 — Explain tool-specific scope and cost

Do not apply one cross-tool cost formula.

**StrykerJS** can restrict mutation generation with `--mutate`. Prefer safe line
ranges derived from a zero-context diff; fall back to exact changed files when
line ranges cannot be represented reliably. Report selected files/ranges and
incremental cache status before running.

**mutmut** uses configured `source_paths` as its mutation **source universe**.
It may generate/cache mutants for that universe before positional mutant or
module selectors focus a rerun. Changed modules therefore control what this
audit reruns, inspects, and reports; they are not a promise of file-level mutant
generation. Report source paths, cached/generated mutant counts when available,
and the changed-module focus.

If the tool reports a large scope or the cost is unknown, let the user proceed,
narrow, or stop. Do not invent a numeric estimate.

## Step 6 — Run mutation testing

Run from the affected project unit using its project environment.

For mutmut, use current supported commands:

```bash
mutmut run
mutmut results
mutmut show <mutant-name>
mutmut browse
```

Use `results` to enumerate outcomes and `show` for a reviewable mutant diff;
`browse` remains the interactive viewer. Tool-supported positional
mutant/module names may rerun selected changed modules. Do not parse
undocumented internal files as a stable API.

For StrykerJS, invoke through the owning package manager and pass one or more
exact mutation scopes, for example:

```bash
npx stryker run --incremental --force --mutate "src/example.ts:10-24"
```

Capture the command, tool version, exit status, scope, and reporter output.

## Step 7 — Report native result semantics

Preserve every category the tool exposes instead of collapsing all non-killed
results into survivors:

- killed;
- survived;
- no coverage / untested;
- timeout;
- invalid / compile error / runtime error;
- skipped or ignored.

Show the tool-provided mutation score only as secondary context. Never compare
scores across tools or treat 100% as proof that the whole test suite is
effective. Always state the baseline result, actual mutation scope, excluded
files, incomplete/error categories, and tool limitations.

Prioritize actionable survivors as conditional, boundary, return-value, then
other mutations:

```text
| # | Status | Risk | File:line | Mutation | Test gap |
|---|---|---|---|---|---|
```

## Step 8 — Triage without implementing

Offer three choices for an actionable finding:

1. hand the test gap to the current **implementation/TDD workflow**;
2. mark it equivalent, requiring a human reason;
3. defer it, requiring a human reason and keeping it unresolved.

Do not write the test in this audit. If the user chooses option 1, return the
finding, expected behavior, and replay command to the workflow that owns the
implementation.

## Step 9 — Preserve scan and decision state

Use `openspec/.mutation-state` when `openspec/` exists, otherwise
`.mutation-state`. Read legacy `commit=<sha>` as a scan base, but write the
separate current records:

```text
last_scan_commit=<sha>
equivalent=<fingerprint>\t<date>\t<reason>
deferred=<fingerprint>\t<date>\t<reason>
```

Build a fingerprint from available tool, project-unit, path, location, mutator,
and mutation-description fields. If those fields cannot identify a finding
reliably, show it for triage again instead of guessing a match.

Only advance `last_scan_commit` after a valid completed run. Preserve all
equivalent and deferred records when the scan base changes. Equivalent findings
may be excluded from the main table but remain counted in the summary; deferred
findings remain visible until explicitly resolved or reclassified.

Finish by reporting the state path and whether the scan base changed.
