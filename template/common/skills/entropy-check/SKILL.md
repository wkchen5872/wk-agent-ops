---
name: entropy-check
description: >
  Periodic health audit for AI agent projects. Detects documentation drift,
  dead references, stale OpenSpec changes, and template/install sync issues.
  Auto-fixes AGENTS.md coverage gaps; reports other findings for human review.
license: MIT
compatibility: Requires bash, git. Optional: jq, openspec CLI.
metadata:
  author: wk-agent-ops
  version: "1.0"
---

# entropy-check

Runs a structured health audit of the current project. Detects drift and dead
weight that accumulates between feature cycles.

---

## Step 1 — Resolve project root

Determine the project root using environment variables:

```
if $GEMINI_PROJECT_DIR is set  → PROJECT_ROOT=$GEMINI_PROJECT_DIR
elif $CLAUDE_PROJECT_DIR is set → PROJECT_ROOT=$CLAUDE_PROJECT_DIR
else                            → PROJECT_ROOT=$PWD
```

---

## Step 2 — Detect context

Examine the project root to classify the project type:

```
if  $PROJECT_ROOT/template/common/ exists  → context = harness
elif $PROJECT_ROOT/openspec/changes/ exists → context = openspec
else                                        → context = standard
```

Announce: **"Context detected: `<context>`"**

Determine which audits to run:

| Audit | standard | openspec | harness |
|-------|----------|----------|---------|
| U1 — AGENTS.md coverage | ✓ | ✓ | ✓ |
| U2 — Docs completeness  | ✓ | ✓ | ✓ |
| U3 — Dead references    | ✓ | ✓ | ✓ |
| H1 — Template sync      | — | — | ✓ |
| O1 — Stale active changes | — | ✓ | ✓ |
| O2 — OpenSpec spec sync | — | ✓ | ✓ |
| O3 — Dead specs         | — | ✓ | ✓ |

---

## Step 3 — Run audits

Execute each applicable audit and collect findings.

### U1 — AGENTS.md coverage

Find all installed skills and agents, check each has a `### <name>` section in AGENTS.md.

```bash
# Skills
for skill_dir in $PROJECT_ROOT/.claude/skills/*/; do
  name=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    if ! grep -q "^### $name" "$PROJECT_ROOT/AGENTS.md" 2>/dev/null; then
      # FINDING: U1 — missing skill entry for <name>
    fi
  fi
done

# Agents
for agent_file in $PROJECT_ROOT/.claude/agents/*.md; do
  name=$(basename "$agent_file" .md)
  if ! grep -q "^### $name" "$PROJECT_ROOT/AGENTS.md" 2>/dev/null; then
    # FINDING: U1 — missing agent entry for <name>
  fi
done
```

**Auto-fix available:** Read the SKILL.md or agent.md source and write a
`### <name>` entry to AGENTS.md. Include: location, purpose, trigger method.
Do not modify other sections.

### U2 — Docs completeness

Scan `docs/architecture.md` and `docs/conventions.md` for placeholder text:

```bash
for doc in "$PROJECT_ROOT/docs/architecture.md" "$PROJECT_ROOT/docs/conventions.md"; do
  if [ -f "$doc" ]; then
    if grep -qiE 'TODO|\[填入\]' "$doc" 2>/dev/null; then
      # FINDING: U2 — placeholder text in <doc>
    fi
    # Empty section: "## Heading\n\n## Next" or "## Heading\n<!-- ... -->\n## Next"
    if grep -qE '^## ' "$doc" 2>/dev/null; then
      # Check for sections with no real content (only comments or whitespace between headers)
      # FINDING: U2 — empty section in <doc> if detected
    fi
  fi
done
```

**No auto-fix** — requires human knowledge to fill.

### U3 — Dead references

Scan AGENTS.md and `docs/*.md` for local path references that do not exist:

```bash
for file in "$PROJECT_ROOT/AGENTS.md" "$PROJECT_ROOT/docs/"*.md; do
  [ -f "$file" ] || continue
  grep -oE '`(scripts/|\.claude/|template/)[^`]+`' "$file" \
    | sed "s/\`//g" \
    | while read -r ref_path; do
        if [ ! -e "$PROJECT_ROOT/$ref_path" ]; then
          # FINDING: U3 — broken reference '$ref_path' in <file>
        fi
      done
done
```

**No auto-fix** — report path and containing file for human review.

### H1 — Template sync (harness only)

Diff template layer against installed layer, excluding `*.local*` files:

```bash
diff -rq \
  --exclude="*.local*" \
  --exclude="*.local" \
  "$PROJECT_ROOT/template/common/.claude/" \
  "$PROJECT_ROOT/.claude/" \
  2>/dev/null
```

For each differing file, report as H1 finding.

**Auto-fix:** Run `bash scripts/skills/install.sh` to resync.

### O1 — Stale active changes (openspec / harness)

Find changes under `openspec/changes/` (excluding `archive/`) not modified in 14+ days:

```bash
for change_dir in "$PROJECT_ROOT/openspec/changes"/*/; do
  name=$(basename "$change_dir")
  [ "$name" = "archive" ] && continue
  # Find most recently modified file in the change directory
  last_modified=$(find "$change_dir" -type f -printf '%T@\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d. -f1)
  now=$(date +%s)
  age_days=$(( (now - last_modified) / 86400 ))
  if (( age_days > 14 )); then
    # FINDING: O1 — change '<name>' last modified <age_days> days ago
  fi
done
```

**No auto-fix** — prompt: archive or continue?

### O2 — OpenSpec spec sync (openspec / harness)

Find archived changes with specs not yet synced to canonical location:

```bash
ARCHIVE_DIR="$PROJECT_ROOT/openspec/changes/archive"
if [ -d "$ARCHIVE_DIR" ]; then
  for archived_change in "$ARCHIVE_DIR"/*/; do
    name=$(basename "$archived_change")
    specs_dir="$archived_change/specs"
    if [ -d "$specs_dir" ] && find "$specs_dir" -name "*.md" -maxdepth 2 | grep -q .; then
      if [ ! -d "$PROJECT_ROOT/openspec/specs/$name" ]; then
        # FINDING: O2 — archived change '<name>' has specs not synced to openspec/specs/
      fi
    fi
  done
fi
```

**No auto-fix** — report for human review (use `/opsx:sync-specs` if available).

### O3 — Dead specs (openspec / harness)

Find spec directories with no corresponding skill or agent:

```bash
if [ -d "$PROJECT_ROOT/openspec/specs" ]; then
  for spec_dir in "$PROJECT_ROOT/openspec/specs"/*/; do
    name=$(basename "$spec_dir")
    skill_exists=false
    agent_exists=false
    [ -d "$PROJECT_ROOT/.claude/skills/$name" ] && skill_exists=true
    [ -d "$PROJECT_ROOT/template/common/skills/$name" ] && skill_exists=true
    [ -f "$PROJECT_ROOT/.claude/agents/$name.md" ] && agent_exists=true
    if ! $skill_exists && ! $agent_exists; then
      # FINDING: O3 — spec '$name' has no corresponding skill or agent
    fi
  done
fi
```

**No auto-fix** — requires human confirmation before deletion.

---

## Step 4 — Display results

Show a summary table:

```
## Entropy Check Results — <context> context

| Audit | Status | Findings |
|-------|--------|----------|
| U1 — AGENTS.md coverage | ✓ / ⚠️ N | <description> |
| U2 — Docs completeness  | ✓ / ⚠️ N | <description> |
| U3 — Dead references    | ✓ / ⚠️ N | <description> |
| H1 — Template sync      | ✓ / ⚠️ N | <description> |  ← harness only
| O1 — Stale active changes | ✓ / ⚠️ N | <description> | ← openspec/harness
| O2 — OpenSpec spec sync | ✓ / ⚠️ N | <description> |  ← openspec/harness
| O3 — Dead specs         | ✓ / ⚠️ N | <description> |  ← openspec/harness
```

Then list all findings grouped by audit code.

---

## Step 5 — Decision menu

**If findings exist:**

Present the user with:

```
What would you like to do?
  [1] Auto-fix fixable findings (U1, H1 if applicable)
  [2] Create OpenSpec change to address structural findings
  [3] Skip — update watermark and continue
```

Wait for user response, then execute the chosen action:

- **[1] Auto-fix:**
  - U1: For each missing entry, read the source SKILL.md or agent.md and append
    a well-formatted `### <name>` section to AGENTS.md. Format:
    ```markdown
    ### <name>

    **位置：** `.claude/skills/<name>/SKILL.md`  (or agents path)

    **用途：** <first sentence of description from SKILL.md>

    **觸發方式：**
    ```
    /<name>
    ```
    ```
  - H1: Run `bash scripts/skills/install.sh` in project root.
  - After fixes, confirm what was changed.

- **[2] Create OpenSpec change:**
  - Summarize structural findings and suggest: `openspec new change entropy-cleanup`
  - Do not execute automatically.

- **[3] Skip:**
  - Proceed to watermark update.

**If no findings exist:**
```
✅ All audits passed — project is clean!
```
Proceed to watermark update automatically.

---

## Step 6 — Update watermark

If context is `openspec` or `harness`:

1. Count the current number of directories in `openspec/changes/archive/`.
2. Write that count to `openspec/.entropy-state` (single integer, no trailing newline).
3. Ensure `openspec/.entropy-state` is in `.gitignore`:
   - Check if `openspec/.entropy-state` appears in `.gitignore`.
   - If not, append the line `openspec/.entropy-state` to `.gitignore`.

```bash
ARCHIVE_COUNT=$(find "$PROJECT_ROOT/openspec/changes/archive" \
  -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')
printf '%s' "$ARCHIVE_COUNT" > "$PROJECT_ROOT/openspec/.entropy-state"
echo "  ✓ Watermark updated: $ARCHIVE_COUNT"
```

Confirm: **"Watermark updated to `<count>`"**
