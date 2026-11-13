#!/usr/bin/env bash
# install.sh — Copy custom skills/rules/workflows into a target project
#
# Usage (from inside the target project):
#   bash /path/to/wk-agent-ops/scripts/skills/install.sh [profile...]
#
# Or with explicit target:
#   bash /path/to/wk-agent-ops/scripts/skills/install.sh --target /path/to/target-project [profile...]
#
# Profiles:
#   (none)   — common only (language-agnostic skills, rules, workflows)
#   python   — common + Python coding style rules + pre-commit hook
#   node     — common + Node.js coding style rules + pre-commit hook
#   jvm      — common + Java/Kotlin mutation testing skills
#   dotnet   — common + .NET mutation testing skills
#
# Examples:
#   bash install.sh                  # common only
#   bash install.sh python           # common + python
#   bash install.sh python node      # common + python + node
#   bash install.sh jvm dotnet       # common + JVM + .NET

set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$SOURCE_REPO/template"
COMMON="$TEMPLATE/common"

# Parse --target option and remaining positional args as profiles
TARGET=""
PROFILES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"; shift 2 ;;
    --target=*)
      TARGET="${1#--target=}"; shift ;;
    -*)
      echo "❌ Unknown option: $1"; exit 1 ;;
    *)
      PROFILES+=("$1"); shift ;;
  esac
done

TARGET="$(cd "${TARGET:-$(pwd)}" && pwd -P)"

# Validate target is a git repository root. Linked worktrees have a .git file,
# so ask Git for the canonical top-level instead of assuming .git is a directory.
if ! GIT_TOPLEVEL="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "❌ Error: $TARGET is not a git repository root"
  exit 1
fi
GIT_TOPLEVEL="$(cd "$GIT_TOPLEVEL" && pwd -P)"
if [[ "$GIT_TOPLEVEL" != "$TARGET" ]]; then
  echo "❌ Error: $TARGET is not a git repository root"
  exit 1
fi

# Discover available profiles (subdirs of template/ excluding common/)
AVAILABLE_PROFILES=()
for d in "$TEMPLATE"/*/; do
  name="$(basename "$d")"
  [[ "$name" != "common" ]] && AVAILABLE_PROFILES+=("$name")
done

# Validate requested profiles
for profile in "${PROFILES[@]+"${PROFILES[@]}"}"; do
  valid=false
  for avail in "${AVAILABLE_PROFILES[@]+"${AVAILABLE_PROFILES[@]}"}"; do
    [[ "$profile" == "$avail" ]] && valid=true && break
  done
  if [[ "$valid" == false ]]; then
    echo "❌ Unknown profile: '$profile'"
    echo "   Available profiles: ${AVAILABLE_PROFILES[*]:-"(none yet)"}"
    exit 1
  fi
done

# Select one testland/qa runner per language profile. Keep this mapping here,
# beside profile validation, so the installer has one source of truth.
MUTATION_SKILLS=()
add_mutation_skill() {
  local candidate="$1" existing
  for existing in "${MUTATION_SKILLS[@]+"${MUTATION_SKILLS[@]}"}"; do
    [[ "$candidate" == "$existing" ]] && return 0
  done
  MUTATION_SKILLS+=("$candidate")
}

for profile in "${PROFILES[@]+"${PROFILES[@]}"}"; do
  case "$profile" in
    node) add_mutation_skill "stryker-mutation" ;;
    python) add_mutation_skill "mutmut-mutation" ;;
    jvm) add_mutation_skill "pitest-mutation" ;;
    dotnet) add_mutation_skill "stryker-net-mutation" ;;
  esac
done
if [[ ${#MUTATION_SKILLS[@]} -gt 0 ]]; then
  add_mutation_skill "mutant-survival-triage"
fi

PROFILES_DISPLAY="common${PROFILES[*]:+ ${PROFILES[*]}}"
echo "🔧 Installing custom agent extensions"
echo "   source  : $TEMPLATE"
echo "   target  : $TARGET"
echo "   profiles: ${PROFILES_DISPLAY}"
echo ""

sync_dir() {
  local src="$1" dst="$2"
  [[ -d "$src" ]] || return 0
  mkdir -p "$dst"
  rsync -a --itemize-changes "$src/" "$dst/"
}

# --- Install common ---
# Targets: Claude Code (.claude/) and Antigravity (.agents/ — flat rules/workflows).

# skills/ → .claude/skills/ and .agents/skills/
sync_dir "$COMMON/skills" "$TARGET/.claude/skills"
sync_dir "$COMMON/skills" "$TARGET/.agents/skills"

# .claude/ and .agents/ (excluding skills/)
mkdir -p "$TARGET/.claude" "$TARGET/.agents"
# Remove only the project-owned agent names retired by the `-agent` migration.
rm -f "$TARGET/.claude/agents/git-commit-writer.md" \
      "$TARGET/.claude/agents/doc-updater.md" \
      "$TARGET/.codex/agents/git-commit-writer.toml" \
      "$TARGET/.codex/agents/doc-updater.toml"
rsync -a --itemize-changes --exclude 'skills/' "$COMMON/.claude/" "$TARGET/.claude/"
sync_dir "$COMMON/.agents" "$TARGET/.agents"   # agent workflows → .agents/workflows/
sync_dir "$COMMON/.codex/agents" "$TARGET/.codex/agents"

# --- AGENTS.md: copy only if not present in target ---
if [[ -f "$COMMON/AGENTS.md" && ! -f "$TARGET/AGENTS.md" ]]; then
  cp "$COMMON/AGENTS.md" "$TARGET/AGENTS.md"
  echo ">f+++++++ AGENTS.md"
fi

# --- Managed vs seed files ---
# Managed files are shared upstream standards: always overwritten so a re-run of
# install.sh propagates updates to already-installed repos. Paths are target-root
# relative, so a managed file may live outside docs/. Add new shared standards to
# MANAGED_FILES. Everything else in docs/ is seed (project-fill): copied only if
# absent, never overwritten.
MANAGED_FILES=(
  docs/agent-protocol.md
  docs/okf-conventions.md
  docs/mutation-testing.md
  docs/openspec-workflow.md
  docs/github-handoff.md
  docs/diagrams/github-handoff.svg
  work-items/AGENTS.md
)
for f in "${MANAGED_FILES[@]}"; do
  [[ -f "$COMMON/$f" ]] || continue
  mkdir -p "$TARGET/$(dirname "$f")"
  rsync -a --itemize-changes "$COMMON/$f" "$TARGET/$f"
done
if [[ -d "$COMMON/docs" ]]; then
  mkdir -p "$TARGET/docs"
  rsync -a --ignore-existing --itemize-changes "$COMMON/docs/" "$TARGET/docs/"
fi

# --- Install requested profiles ---

for profile in "${PROFILES[@]+"${PROFILES[@]}"}"; do
  PROFILE_DIR="$TEMPLATE/$profile"
  sync_dir "$PROFILE_DIR/.claude/rules" "$TARGET/.claude/rules"
  if [[ -d "$PROFILE_DIR/hooks" ]]; then
    GIT_HOOKS_DIR="$(git -C "$TARGET" rev-parse --git-path hooks)"
    if [[ "$GIT_HOOKS_DIR" != /* ]]; then
      GIT_HOOKS_DIR="$TARGET/$GIT_HOOKS_DIR"
    fi
    sync_dir "$PROFILE_DIR/hooks" "$GIT_HOOKS_DIR"
    find "$GIT_HOOKS_DIR" -maxdepth 1 -type f -exec chmod +x {} +
  fi
done

# --- Mirror all installed rules to Antigravity's flat .agents/rules/ ---
# Claude Code reads .claude/rules/; Antigravity reads flat .agents/rules/*.md.
# .claude/rules/ is flat in this template, so a direct copy preserves the flat layout.
sync_dir "$TARGET/.claude/rules" "$TARGET/.agents/rules"

# Remove the retired OpenSpec commit rule from existing installations.
rm -f "$TARGET/.claude/rules/openspec-commits.md" \
      "$TARGET/.agents/rules/openspec-commits.md"

# Retire the GitHub handoff identity-check script. Only a byte-identical copy of
# a version this installer shipped is removed; a modified or unknown file may hold
# local work, so it is left in place and reported. Nothing reads its contents.
LEGACY_ID_SCRIPT="scripts/github/check-identity.sh"
LEGACY_ID_BLOBS=" e43ee68edf95d5a408df8687764d573a9414efae "
if [[ -f "$TARGET/$LEGACY_ID_SCRIPT" && ! -L "$TARGET/$LEGACY_ID_SCRIPT" ]]; then
  legacy_blob="$(git hash-object --no-filters -- "$TARGET/$LEGACY_ID_SCRIPT" 2>/dev/null || true)"
  if [[ -n "$legacy_blob" && "$LEGACY_ID_BLOBS" == *" $legacy_blob "* ]]; then
    rm -f "$TARGET/$LEGACY_ID_SCRIPT"
    rmdir "$TARGET/scripts/github" "$TARGET/scripts" 2>/dev/null || true
    echo "ℹ️  removed retired $LEGACY_ID_SCRIPT (unmodified managed copy)"
  else
    echo "⚠️  left $LEGACY_ID_SCRIPT in place: it differs from every shipped version."
    echo "    The GitHub handoff no longer uses it; delete it yourself if it is not needed."
  fi
elif [[ -L "$TARGET/$LEGACY_ID_SCRIPT" ]]; then
  echo "⚠️  left $LEGACY_ID_SCRIPT in place: it is a symlink. The GitHub handoff no longer uses it."
fi

# Remove the retired entropy audit from existing installations.
rm -rf "$TARGET/.claude/skills/entropy-check" \
       "$TARGET/.agents/skills/entropy-check"
rm -f "$TARGET/openspec/.entropy-state"
if [[ -f "$TARGET/.gitignore" ]]; then
  IGNORE_TMP="$(mktemp)"
  grep -vFx 'openspec/.entropy-state' "$TARGET/.gitignore" > "$IGNORE_TMP" || true
  mv "$IGNORE_TMP" "$TARGET/.gitignore"
fi

# --- Work Item records: versioned ignore rule and effect verification ---
WI_RULE='/work-items/WI-*/'

# The paths whose ignore status decides whether records are protected: a generic
# probe, which covers a target holding no records yet or an empty record directory,
# plus every file that actually exists inside each record directory. One
# representative path per directory is not enough, because an exception can be
# written for a single file such as context.md or a file under agents/.
wi_record_paths() {
  printf '%s\n' 'work-items/WI-00000000-probe/README.md'
  local d f had
  for d in "$TARGET"/work-items/WI-*/; do
    [[ -d "$d" ]] || continue
    had=0
    while IFS= read -r f; do
      if [[ -n "$f" ]]; then
        printf '%s\n' "${f#"$TARGET"/}"
        had=1
      fi
    done < <(find "$d" -type f 2>/dev/null)
    if [[ "$had" -eq 0 ]]; then
      printf 'work-items/%s/README.md\n' "$(basename "$d")"
    fi
  done
}

# One Git call for every record path. `-n` also reports non-matching paths, so a
# path that is not ignored shows up in one of two forms: an empty `::` field when
# no pattern covers it at all, or the negation pattern itself when a `!` rule
# re-includes it. Both must count as unprotected.
wi_scan() {
  wi_record_paths | git -C "$TARGET" check-ignore --no-index -v -n --stdin 2>/dev/null || true
}

# $1 is the "<source>:<line>:<pattern>" field produced above.
wi_rule_leaves_path_unignored() {
  local pat="${1#*:*:}"
  [[ -z "$pat" || "$pat" == '!'* ]]
}

wi_pattern_ignored() { git -C "$TARGET" check-ignore -q --no-index -- "$1" 2>/dev/null; }
wi_match()           { git -C "$TARGET" check-ignore -v --no-index -- "$1" 2>/dev/null | awk -F'\t' 'NR==1{print $1}'; }
wi_match_source()    { wi_match "$1" | awk -F: 'NR==1{print $1}'; }

# A directory-level negation may leave child paths unmatched; locate its rule for diagnostics.
wi_negation_line() {
  [[ -f "$TARGET/.gitignore" ]] || return 0
  local n=0 line pat hit=""
  while IFS= read -r line; do
    n=$((n + 1))
    case "$line" in
      '!'*) ;;
      *) continue ;;
    esac
    pat="${line#!}"
    pat="${pat#/}"
    pat="${pat%/}"
    [[ -n "$pat" ]] || continue
    case "$1" in
      # Git lets the last matching pattern win, so keep looking instead of
      # reporting the first negation that happens to cover the path.
      $pat | $pat/*) hit=".gitignore:$n:$line" ;;
    esac
  done < "$TARGET/.gitignore"
  if [[ -n "$hit" ]]; then printf '%s\n' "$hit"; fi
  return 0
}

# A literal rule line is already there: never append a second one, even when a
# later negation makes it ineffective. That case is reported, not rewritten.
wi_rule_line_present() {
  [[ -f "$TARGET/.gitignore" ]] && grep -qE '^/?work-items/WI-\*/(\*\*)?$' "$TARGET/.gitignore"
}

# Equivalent protection is already supplied by the versioned .gitignore when every
# record path is ignored, every match comes from that file, and the convention stays
# trackable. This accepts any equivalent spelling while still rejecting exclusion
# from .git/info/exclude or a personal core.excludesFile, which report a different
# source: the project would carry no rule and a fresh clone would be unprotected.
wi_versioned_effect() {
  local line rule
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    rule="${line%%$'\t'*}"
    if wi_rule_leaves_path_unignored "$rule"; then return 1; fi
    if [[ "${rule%%:*}" != ".gitignore" ]]; then return 1; fi
  done < <(wi_scan)
  if wi_pattern_ignored 'work-items/AGENTS.md'; then return 1; fi
  return 0
}

if ! wi_rule_line_present && ! wi_versioned_effect; then
  if [[ -f "$TARGET/.gitignore" ]]; then
    # Keep the file newline-terminated so the appended block cannot join a line.
    if [[ -n "$(tail -c 1 "$TARGET/.gitignore")" ]]; then
      printf '\n' >> "$TARGET/.gitignore"
    fi
    printf '\n# Local, disposable Work Item records\n%s\n' "$WI_RULE" >> "$TARGET/.gitignore"
  else
    printf '# Local, disposable Work Item records\n%s\n' "$WI_RULE" > "$TARGET/.gitignore"
  fi
  echo ">f+++++++ .gitignore (Work Item rule)"
fi

# Verify the outcome with Git rather than the presence of a rule line: over every
# record path, and in both directions. check-ignore never reports a tracked path as
# ignored, so the index is consulted separately below.
WI_PROTECTED=true
while IFS= read -r wi_line; do
  [[ -n "$wi_line" ]] || continue
  wi_rule="${wi_line%%$'\t'*}"
  wi_p="${wi_line#*$'\t'}"
  if wi_rule_leaves_path_unignored "$wi_rule"; then
    echo "⚠️  Work Item record path is not ignored: $wi_p"
    # Git names the negation when one matched the path itself; when nothing
    # matched it reports an empty field, and the responsible directory-level
    # negation is then located by scanning the versioned .gitignore.
    WI_M="$wi_rule"
    if [[ -z "${WI_M#*:*:}" ]]; then
      WI_M="$(wi_negation_line "$wi_p" || true)"
    fi
    if [[ -n "$WI_M" ]]; then
      echo "      matched by: $WI_M"
    else
      echo "      no rule matches this path"
    fi
    WI_PROTECTED=false
  fi
done < <(wi_scan)

if wi_pattern_ignored 'work-items/AGENTS.md'; then
  WI_CONV_M="$(wi_match 'work-items/AGENTS.md' || true)"
  echo "⚠️  work-items/AGENTS.md is ignored by ${WI_CONV_M:-an existing rule};"
  echo "    the convention cannot be tracked, so the two-way condition fails."
  WI_PROTECTED=false
fi

if [[ "$WI_PROTECTED" != true ]]; then
  echo "    Existing rules were left unchanged. Work Item ignore protection is NOT in effect."
fi

WI_TRACKED="$(git -C "$TARGET" ls-files -- 'work-items/WI-*' 2>/dev/null || true)"
if [[ -n "$WI_TRACKED" ]]; then
  echo "⚠️  Work Item records are already tracked in Git; protection is not in force for them:"
  while IFS= read -r wi_line; do
    if [[ -n "$wi_line" ]]; then echo "      $wi_line"; fi
  done <<< "$WI_TRACKED"
  echo "    The Git index was not modified. Untrack them yourself if that is intended."
fi

# --- Activation entry reachability ---
# A tool that reads only AGENTS.md discovers project instructions from the project
# root down to its launch directory, loading at most one file per directory, with an
# override file taking precedence. So check the file that would actually load rather
# than AGENTS.md by name. Provider rules directories do not reach such a tool, and a
# project-owned instruction file is never modified here.
WI_ROOT_INSTRUCTION=""
for wi_candidate in AGENTS.override.md AGENTS.md; do
  if [[ -s "$TARGET/$wi_candidate" ]]; then
    WI_ROOT_INSTRUCTION="$wi_candidate"
    break
  fi
done

if [[ -z "$WI_ROOT_INSTRUCTION" ]]; then
  echo "⚠️  No non-empty root instruction file (AGENTS.override.md or AGENTS.md) was found."
  echo "    Work Item activation is UNVERIFIED for tools that read only AGENTS.md."
elif ! grep -q 'docs/agent-protocol.md' "$TARGET/$WI_ROOT_INSTRUCTION"; then
  echo "⚠️  $WI_ROOT_INSTRUCTION is the root instruction that loads, and it does not point"
  echo "    at docs/agent-protocol.md. Managed files were installed, but Work Item"
  echo "    activation is NOT active for tools that read only AGENTS.md."
  echo "    Installed provider rules do not reach such a tool. Add this section to"
  echo "    $WI_ROOT_INSTRUCTION yourself — the installer does not modify it:"
  echo ""
  echo "      ## Agent Operating Protocol"
  echo "      Before any task, read \`docs/agent-protocol.md\`."
  echo ""
else
  WI_CHAIN_MISSING=""
  for wi_link in docs/agent-protocol.md work-items/AGENTS.md; do
    if [[ ! -f "$TARGET/$wi_link" ]]; then
      WI_CHAIN_MISSING="$WI_CHAIN_MISSING $wi_link"
    fi
  done
  if ! grep -q 'work-items/AGENTS.md' "$TARGET/docs/agent-protocol.md" 2>/dev/null; then
    WI_CHAIN_MISSING="$WI_CHAIN_MISSING protocol-pointer"
  fi
  if [[ -n "$WI_CHAIN_MISSING" ]]; then
    echo "⚠️  Activation chain incomplete; missing:$WI_CHAIN_MISSING"
    echo "    Work Item activation is NOT active for tools that read only AGENTS.md."
  else
    echo "✓ Work Item activation chain: $WI_ROOT_INSTRUCTION → docs/agent-protocol.md → work-items/AGENTS.md"
  fi
fi

# Remove the retired wk-agent-ops mutation skills. Third-party replacements are
# installed below; legacy human triage state is intentionally preserved.
rm -rf "$TARGET/.claude/skills/mutation-setup" \
       "$TARGET/.claude/skills/mutation-check" \
       "$TARGET/.agents/skills/mutation-setup" \
       "$TARGET/.agents/skills/mutation-check"

print_mutation_install_command() {
  printf '   Replay in target:'
  printf ' cd %q &&' "$TARGET"
  printf ' %q' "${MUTATION_INSTALL_CMD[@]}"
  printf '\n'
}

if [[ ${#MUTATION_SKILLS[@]} -gt 0 ]]; then
  MUTATION_INSTALL_CMD=(npx skills add testland/qa)
  for skill in "${MUTATION_SKILLS[@]}"; do
    MUTATION_INSTALL_CMD+=(--skill "$skill")
  done
  MUTATION_INSTALL_CMD+=(
    --agent claude-code
    --agent codex
    --agent antigravity
    --yes
  )

  if ! command -v npx >/dev/null 2>&1; then
    echo "❌ npx is required to install testland/qa mutation skills" >&2
    echo "   Skills not installed: ${MUTATION_SKILLS[*]}" >&2
    print_mutation_install_command >&2
    exit 1
  fi

  echo "🔧 Installing testland/qa mutation skills"
  if ! (cd "$TARGET" && "${MUTATION_INSTALL_CMD[@]}"); then
    echo "❌ Failed to install testland/qa mutation skills" >&2
    echo "   Skills not installed: ${MUTATION_SKILLS[*]}" >&2
    print_mutation_install_command >&2
    exit 1
  fi
fi

echo ""
echo "✅ Done. Installed profiles: ${PROFILES_DISPLAY}"
echo "   Target: $TARGET"
