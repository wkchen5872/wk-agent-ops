# Template Profiles

`template/` uses a **profile-based** directory layout. When installing into a target project, you choose which profiles to include. `common` is always installed; language-specific profiles are opt-in.

## Directory Structure

```
template/
├── common/                       ← always installed
│   ├── skills/                   → .claude/skills/ and .agent/skills/
│   ├── .claude/
│   │   ├── commands/opsx/        → /opsx:* slash commands
│   │   └── rules/                → always-on Claude Code rules
│   ├── .agent/workflows/         → agent workflow definitions
│   └── .github/instructions/     → GitHub Copilot instructions
├── python/                       ← opt-in: Python projects
│   ├── .claude/rules/            → Python-specific Claude rules
│   └── hooks/
│       └── pre-commit            → .git/hooks/pre-commit (chmod +x)
└── node/                         ← opt-in: Node.js projects
    ├── .claude/rules/            → Node.js-specific Claude rules
    └── hooks/
        └── pre-commit            → .git/hooks/pre-commit (chmod +x)
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

# common + python + node
bash /path/to/wk-agent-ops/scripts/skills/install.sh python node

# explicit target directory
bash /path/to/wk-agent-ops/scripts/skills/install.sh --target /path/to/project python
```

`common` is always installed and does not need to be specified.

## What Gets Installed

| Source | Destination | Notes |
|--------|-------------|-------|
| `common/skills/` | `.claude/skills/` | agent skills |
| `common/skills/` | `.agent/skills/` | agent skills (duplicate) |
| `common/.claude/` | `.claude/` | rules, commands |
| `common/.agent/` | `.agent/` | workflows |
| `common/.github/` | `.github/` | Copilot instructions |
| `<profile>/.claude/rules/` | `.claude/rules/` | per-profile rules |
| `<profile>/hooks/` | `.git/hooks/` | git hooks, auto chmod +x |

## Adding a New Profile

1. Create `template/<profile>/` with subdirs as needed:
   ```
   template/<profile>/
   ├── .claude/rules/    ← optional: profile-specific Claude rules
   └── hooks/            ← optional: git hook scripts
       └── pre-commit
   ```
2. Add content. For placeholder hooks, use the existing `python/hooks/pre-commit` as a template.
3. `install.sh` auto-discovers profiles from subdirectories of `template/` (excluding `common/`).
4. Document the new profile in this file.

## Notes

- Installing does **not** remove previously installed files. If you switch profiles, manually clean up obsolete files.
- Hook scripts are automatically made executable (`chmod +x`) during install.
- `common` is always required; there is no way to skip it.
