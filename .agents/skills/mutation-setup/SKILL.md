---
name: mutation-setup
description: >
  Idempotent setup for mutation testing. Selects the affected project unit,
  preserves its package manager, and configures mutmut or Stryker with consent.
license: MIT
compatibility: "Requires git. Python: mutmut v3, Python 3.10+, fork-capable OS. TS/JS: StrykerJS."
metadata:
  author: wk-agent-ops
  version: "1.1"
---

# mutation-setup

Prepare one affected project unit for the portable `mutation-check` audit. This
skill owns every install and configuration side effect; it is safe to re-run and
never overwrites project files without showing the proposed change and obtaining
user consent.

Invoke this skill by name on any Provider that supports project skills.
**Provider-specific example:** Claude Code may expose `/mutation-setup`; the slash
command is not a portable requirement.

> Commands target current mutmut v3 and StrykerJS. If an interface differs, stop
> and verify the current official documentation before changing project files.

## Step 1 — Resolve the repository root

Use the first available source:

1. an explicit target supplied by the user;
2. `git rev-parse --show-toplevel` from the current directory;
3. a normalized Provider-supplied project directory;
4. `PWD` only when no Git repository can be resolved.

Canonicalize the path and announce it. Do not search or write outside that root.

## Step 2 — Select the affected project unit

Find candidate manifests beneath the repository root:

| Manifest | Tool |
|---|---|
| `pyproject.toml`, `setup.cfg`, or legacy `setup.py` | mutmut |
| `package.json` | StrykerJS |

Prefer the nearest manifest that owns the user-specified target or current
changed production files. A repository may contain more than one **affected
project unit**:

- one unambiguous candidate → select it and announce its directory;
- multiple plausible candidates → list them and ask the user to choose;
- Python and TS/JS units both affected → offer to configure each separately;
- no supported candidate → stop without writing.

Never choose the repository-root manifest merely because it was found first.

## Step 3 — Inspect existing dependency management

Before proposing an install, report:

- the selected project unit and tool;
- installed tool version or `not installed`;
- current mutation configuration or `missing`;
- the package manager declared by the manifest, `packageManager` field, or
  lockfile.

Use the project's existing package manager and lockfile. If these disagree or no
manager is evident, ask which established project workflow to use. Do not create
a competing lockfile and do not use a global install as a fallback.

## Step 4 — Python preflight and mutmut setup

For a Python unit, verify before installation:

- the selected interpreter is Python 3.10 or newer;
- the environment is **fork-capable**;
- native Windows users are directed to **WSL** rather than an unsupported run;
- baseline tests already have a known project command, or the user supplies one.

If mutmut is absent, show the exact dev-dependency command for the detected
manager and ask before running it. For example, an existing uv project uses:

```bash
uv add --dev mutmut
```

For other managers, use that project's documented dev-dependency workflow; do
not silently switch managers. If mutmut is present, show its version and offer
keep or upgrade.

The current pyproject form is:

```toml
[tool.mutmut]
source_paths = ["src/"]
pytest_add_cli_args_test_selection = ["tests/"]
```

Treat the values as examples. Infer candidate source/test directories, show the
proposed values, and ask before editing. Preserve other `[tool.mutmut]` keys.
When a legacy project has no supported config file, ask whether to use its
existing `setup.cfg` or add `pyproject.toml`; do not guess.

## Step 5 — StrykerJS setup

Invoke Stryker through the selected JavaScript package manager. For an npm
project, the current initializer is:

```bash
npx stryker init
```

Equivalent package-manager-native launchers may be used only when that manager
already owns the project. The initializer is interactive and may add dev
dependencies plus a Stryker config. Show the expected files and obtain consent
before running it.

If Stryker is already configured, display its installed version, test runner,
mutate setting, and incremental setting. Offer keep or update; never replace the
whole config merely to change one value. Per-run changed-file scope belongs to
`mutation-check`, not setup.

## Step 6 — Ignore local state

Show and confirm any missing ignore entries before appending them to the
repository `.gitignore`:

```text
mutants/
.stryker-tmp/
reports/stryker-incremental.json
.mutation-state
openspec/.mutation-state
```

Do not remove or reorder unrelated ignore rules.

If the project's normal pytest discovery scans the repository root, configure
that command to target the real tests directory or exclude `mutants/`; otherwise
mutmut's generated test copy can cause duplicate-module collection errors on the
next baseline.

## Step 7 — Report readiness

Summarize the selected project unit, package manager, tool version, config path,
baseline test command, and changed files. If no change was needed, explicitly
report that the existing setup was kept.

Then suggest the portable skill name `mutation-check`.
**Provider-specific example:** Claude Code may invoke `/mutation-check`.
