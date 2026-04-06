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

TARGET="$(cd "${TARGET:-$(pwd)}" && pwd)"

# Validate target is a git repo
if [[ ! -d "$TARGET/.git" ]]; then
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

# skills/ → .claude/skills/ and .agent/skills/
sync_dir "$COMMON/skills" "$TARGET/.claude/skills"
sync_dir "$COMMON/skills" "$TARGET/.agent/skills"

# .claude/ .agent/ .github/ (excluding skills/)
mkdir -p "$TARGET/.claude" "$TARGET/.agent" "$TARGET/.github"
rsync -a --itemize-changes --exclude 'skills/' "$COMMON/.claude/" "$TARGET/.claude/"
sync_dir "$COMMON/.agent"  "$TARGET/.agent"
sync_dir "$COMMON/.github" "$TARGET/.github"

# --- Install requested profiles ---

for profile in "${PROFILES[@]+"${PROFILES[@]}"}"; do
  PROFILE_DIR="$TEMPLATE/$profile"
  sync_dir "$PROFILE_DIR/.claude/rules"        "$TARGET/.claude/rules"
  sync_dir "$PROFILE_DIR/.github/instructions" "$TARGET/.github/instructions"
  if [[ -d "$PROFILE_DIR/hooks" ]]; then
    sync_dir "$PROFILE_DIR/hooks" "$TARGET/.git/hooks"
    find "$TARGET/.git/hooks" -maxdepth 1 -type f -exec chmod +x {} +
  fi
done

echo ""
echo "✅ Done. Installed profiles: ${PROFILES_DISPLAY}"
echo "   Target: $TARGET"
