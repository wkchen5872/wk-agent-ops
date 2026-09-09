# Template Profiles

`template/` uses a **profile-based** directory layout. When installing into a target project, you choose which profiles to include. `common` is always installed; language-specific profiles are opt-in.

## Directory Structure

```
template/
├── common/                       ← always installed
│   ├── skills/                   → .claude/skills/ and .agents/skills/
│   ├── .claude/
│   │   ├── commands/opsx/        → /opsx:* slash commands
│   │   └── rules/                → always-on Claude Code rules
│   ├── .agents/workflows/         → agent workflow definitions
│   ├── .codex/agents/             → Codex custom-agent TOML
│   └── .github/instructions/     → GitHub Copilot instructions
├── python/                       ← opt-in: Python projects
│   ├── .claude/rules/            → Python-specific Claude rules
│   └── hooks/
│       └── pre-commit            → .git/hooks/pre-commit (chmod +x)
├── node/                         ← opt-in: Node.js projects
│   ├── .claude/rules/            → Node.js-specific Claude rules
│   └── hooks/
│       └── pre-commit            → .git/hooks/pre-commit (chmod +x)
├── jvm/                          ← opt-in: Java / Kotlin projects
└── dotnet/                       ← opt-in: .NET projects
```

## Install Usage

Run `install.sh` from **inside the target project**, or pass `--target`:

```bash
# common only (language-agnostic)
bash /path/to/wk-agent-ops/scripts/skills/install.sh

# common + python profile
bash /path/to/wk-agent-ops/scripts/skills/install.sh python

# common + node profile
bash /path/to/wk-agent-ops/scripts/skills/install.sh node

# common + Java / Kotlin profile
bash /path/to/wk-agent-ops/scripts/skills/install.sh jvm

# common + .NET profile
bash /path/to/wk-agent-ops/scripts/skills/install.sh dotnet

# common + python + node
bash /path/to/wk-agent-ops/scripts/skills/install.sh python node

# explicit target directory
bash /path/to/wk-agent-ops/scripts/skills/install.sh --target /path/to/project python
```

`common` is always installed and does not need to be specified.

The target must be the Git repository top-level. Both a primary checkout and a
linked worktree root are valid; a subdirectory inside either one is rejected.
For linked worktrees, `.git` is a file, so the installer resolves repository and
hook paths through Git instead of assuming `<target>/.git` is a directory.

Selecting a language profile also runs `npx skills add testland/qa` in the
target repository. It installs one profile-specific mutation runner plus
`mutant-survival-triage` for Claude Code, Codex, and Antigravity using project
scope and the skills CLI default link mode. Common-only installation does not
call `npx`.

| Profile | Mutation runner |
|---|---|
| `node` | `stryker-mutation` |
| `python` | `mutmut-mutation` |
| `jvm` | `pitest-mutation` |
| `dotnet` | `stryker-net-mutation` |

If the third-party install fails or `npx` is unavailable, the installer exits
non-zero and prints the exact command to replay. It does not fall back to a
global or copied installation.

## What Gets Installed

| Source | Destination | Notes |
|--------|-------------|-------|
| `common/skills/` | `.claude/skills/` | agent skills |
| `common/skills/` | `.agents/skills/` | agent skills (duplicate) |
| `common/.claude/` | `.claude/` | rules, commands |
| `common/.agents/` | `.agents/` | workflows |
| `common/.codex/agents/` | `.codex/agents/` | project-owned Codex custom agents only |
| `common/.github/` | `.github/` | Copilot instructions |
| `<profile>/.claude/rules/` | `.claude/rules/` | per-profile rules |
| `<profile>/hooks/` | Git-resolved hooks path | shared git hooks, auto chmod +x |
| `testland/qa` selected skills | project-local Agent skill paths | one language runner plus deduplicated triage |

## Adding a New Profile

1. Create `template/<profile>/` with subdirs as needed:
   ```
   template/<profile>/
   ├── .claude/rules/    ← optional: profile-specific Claude rules
   └── hooks/            ← optional: git hook scripts
       └── pre-commit
   ```
2. Add only required content. Add a hook only when the profile has a reliable
   test command; do not create placeholder hooks.
3. `install.sh` auto-discovers profiles from subdirectories of `template/` (excluding `common/`).
4. Document the new profile in this file.

## Notes

- Installing does not remove arbitrary project files. It may remove explicitly
  retired wk-agent-ops artifacts, including the legacy `mutation-setup` and
  `mutation-check` skills; other user and third-party skills are preserved.
- Codex ownership is limited to `.codex/agents/`; `.codex/config.toml` and
  `.codex/skills/` are preserved.
- Hook scripts are installed at `git rev-parse --git-path hooks` and made
  executable (`chmod +x`). Linked worktrees therefore use the repository's
  shared hooks directory.
- `common` is always required; there is no way to skip it.
