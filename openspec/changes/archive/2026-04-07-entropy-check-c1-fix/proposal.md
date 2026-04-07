## Why

The C1 unused code audit has two heuristic bugs that cause false positives on every run:

1. **Bash false positives**: The function search excludes the defining file (`grep -v "^$sh_file$"`), so any function called only within its own script is reported as unused. This is the normal case for helper functions, causing nearly all bash findings to be incorrect.
2. **Python false positives**: When extracting names from multi-name imports (e.g., `from datetime import datetime, timedelta`), `awk '{print $1}'` yields `datetime,` with a trailing comma. `grep -c "datetime,"` then only matches the import line itself, incorrectly flagging used imports as unused.

## What Changes

- **Bash**: Change detection logic to count occurrences across ALL files including the defining file. A function with only 1 total occurrence (the definition line) is unused; ≥ 2 means it has at least one callsite.
- **Python**: Strip trailing commas from extracted import names before checking usage count.

## Capabilities

### New Capabilities

_None_

### Modified Capabilities

- `entropy-check-c1-unused-code`: Fix bash function detection (include self-file) and Python name extraction (strip commas)

## Impact

- `template/common/skills/entropy-check/SKILL.md` — fix C1 bash and Python heuristic code
- `.claude/skills/entropy-check/SKILL.md` — same
- `.agent/skills/entropy-check/SKILL.md` — same
- `openspec/specs/entropy-check-c1-unused-code/spec.md` — update bash detection requirement to reflect all-files approach
