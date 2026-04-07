## Context

The C1 audit uses shell one-liners to heuristically detect unused code. Two bugs cause systematic false positives that undermine the audit's usefulness.

## Goals / Non-Goals

**Goals:**
- Fix bash detection: count occurrences across all .sh files (including the defining file); flag only when total count = 1 (definition only)
- Fix Python detection: strip trailing commas from multi-name import tokens

**Non-Goals:**
- Improving TypeScript/JavaScript detection (no known bug there)
- Adding semantic analysis or AST parsing
- Reducing the "confirm before removing" heuristic label

## Decisions

**Bash fix — all-files count instead of other-files filter:**

Current (broken):
```bash
count=$(grep -rl "$fn_name" "$PROJECT_ROOT" --include="*.sh" \
  | grep -v "^$sh_file$" | wc -l)
if [ "$count" -eq 0 ]; then ...
```

Fixed:
```bash
total=$(grep -rn "\b${fn_name}\b" "$PROJECT_ROOT" --include="*.sh" | wc -l)
if [ "$total" -le 1 ]; then ...  # only the definition line itself
```

Using `-n` (line count) rather than `-l` (file count) so a function called 5 times in one file still counts as used. Using `\b` word-boundary anchors to avoid partial matches.

**Python fix — strip trailing comma:**

Current (broken):
```bash
name=$(echo "$import_line" | sed 's/^.*import[[:space:]]*//' | awk '{print $1}')
# yields "datetime," for "from datetime import datetime, timedelta"
```

Fixed:
```bash
name=$(echo "$import_line" | sed 's/^.*import[[:space:]]*//' | awk '{print $1}' | tr -d ',')
# yields "datetime"
```

## Risks / Trade-offs

[Bash word-boundary] `\b` in grep may not work on macOS's BSD grep without `-E` or `-P`. Use `grep -rn` with the pattern `"[^a-zA-Z0-9_]${fn_name}[^a-zA-Z0-9_]\|^${fn_name}[^a-zA-Z0-9_]\|[^a-zA-Z0-9_]${fn_name}$"` as a portable alternative, or simply use `grep -c "$fn_name"` which is good enough for the heuristic context.

Simpler portable approach: count lines containing the name in all .sh files, threshold ≤ 1.
