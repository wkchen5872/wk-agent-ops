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
#
# Examples:
#   bash install.sh                  # common only
#   bash install.sh python           # common + python
#   bash install.sh python node      # common + python + node

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
rsync -a --itemize-changes --exclude 'skills/' "$COMMON/.claude/" "$TARGET/.claude/"
sync_dir "$COMMON/.agents" "$TARGET/.agents"   # agent workflows → .agents/workflows/

# --- AGENTS.md: copy only if not present in target ---
if [[ -f "$COMMON/AGENTS.md" && ! -f "$TARGET/AGENTS.md" ]]; then
  cp "$COMMON/AGENTS.md" "$TARGET/AGENTS.md"
  echo ">f+++++++ AGENTS.md"
fi

# --- docs/: managed vs seed ---
# Managed docs are shared upstream standards: always overwritten so a re-run of
# install.sh propagates updates to already-installed repos. Add new shared
# standards to MANAGED_DOCS. Everything else in docs/ is seed (project-fill):
# copied only if absent, never overwritten.
if [[ -d "$COMMON/docs" ]]; then
  mkdir -p "$TARGET/docs"
  MANAGED_DOCS=(agent-protocol.md okf-conventions.md mutation-testing.md)
  for d in "${MANAGED_DOCS[@]}"; do
    [[ -f "$COMMON/docs/$d" ]] && rsync -a --itemize-changes "$COMMON/docs/$d" "$TARGET/docs/$d"
  done
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

# Remove the retired entropy audit from existing installations.
rm -rf "$TARGET/.claude/skills/entropy-check" \
       "$TARGET/.agents/skills/entropy-check"
rm -f "$TARGET/openspec/.entropy-state"
if [[ -f "$TARGET/.gitignore" ]]; then
  IGNORE_TMP="$(mktemp)"
  grep -vFx 'openspec/.entropy-state' "$TARGET/.gitignore" > "$IGNORE_TMP" || true
  mv "$IGNORE_TMP" "$TARGET/.gitignore"
fi

echo ""
echo "✅ Done. Installed profiles: ${PROFILES_DISPLAY}"
echo "   Target: $TARGET"
