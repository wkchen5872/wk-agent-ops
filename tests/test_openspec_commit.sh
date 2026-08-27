#!/usr/bin/env bash
# Contract test for the project-owned archive -> docs -> commit workflow.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORCHESTRATOR="$ROOT/template/common/skills/openspec-commit/SKILL.md"
CLAUDE_ENTRYPOINT="$ROOT/template/common/.claude/commands/opsx/commit.md"
ANTIGRAVITY_ENTRYPOINT="$ROOT/template/common/.agents/workflows/opsx-commit.md"
DOC_SKILL="$ROOT/template/common/skills/doc-updater/SKILL.md"
DOC_AGENT="$ROOT/template/common/.claude/agents/doc-updater.md"
COMMIT_SKILL="$ROOT/template/common/skills/git-commit-writer/SKILL.md"
COMMIT_AGENT="$ROOT/template/common/.claude/agents/git-commit-writer.md"
fail=0
section="${1:-all}"

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

require_text() {
  local file="$1" text="$2" label="$3"
  grep -Fq "$text" "$file" && ok "$label" || bad "$label"
}

forbid_text() {
  local file="$1" text="$2" label="$3"
  grep -Fq "$text" "$file" && bad "$label" || ok "$label"
}

line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1
}

run_section() {
  [[ "$section" == "all" || "$section" == "$1" ]]
}

if run_section orchestrator; then
printf 'openspec-commit orchestration\n'
archive_line="$(line_of "$ORCHESTRATOR" '## Step 2 — Archive or resume')"
stage_line="$(line_of "$ORCHESTRATOR" '## Step 3 — Prepare the complete diff')"
docs_line="$(line_of "$ORCHESTRATOR" '## Step 4 — Invoke doc-updater')"
commit_line="$(line_of "$ORCHESTRATOR" '## Step 5 — Invoke git-commit-writer')"
if [[ -n "$archive_line" && -n "$stage_line" && -n "$docs_line" && -n "$commit_line" ]] \
  && (( archive_line < stage_line && stage_line < docs_line && docs_line < commit_line )); then
  ok "archive -> stage -> docs -> commit order"
else
  bad "archive -> stage -> docs -> commit order"
fi
require_text "$ORCHESTRATOR" 'openspec-archive-change' "portable archive capability named"
require_text "$ORCHESTRATOR" 'git status --short' "resume state comes from Git"
require_text "$ORCHESTRATOR" 'archive_path' "exact archive path retained"
require_text "$ORCHESTRATOR" 'git add -A' "new files prepared before doc-updater"
require_text "$ORCHESTRATOR" 'tool_name=<executing agent tool>' "executing tool handed to commit writer"
require_text "$ORCHESTRATOR" 'assisting_model=<primary implementation model>' "primary model handed to commit writer"
require_text "$ORCHESTRATOR" 'commit-only agent' "commit-only agent cannot replace implementation model"
forbid_text "$ORCHESTRATOR" 'ls -t openspec/changes/archive/' "no newest-archive rediscovery"

printf '\nprovider boundaries\n'
require_text "$ORCHESTRATOR" '.claude/commands/opsx/archive.md' "Claude native alias documented"
require_text "$ORCHESTRATOR" '.codex/skills/openspec-archive-change/' "Codex skill path documented"
require_text "$ORCHESTRATOR" '.agent/workflows/opsx-archive.md' "Antigravity native alias documented"
require_text "$ORCHESTRATOR" '.agents/skills/' "project-owned shared skill root documented"
require_text "$ORCHESTRATOR" 'Do not invoke both' "provider aliases cannot double-run an action"

printf '\nprovider entrypoints\n'
require_text "$CLAUDE_ENTRYPOINT" 'argument-hint: "[change-name]"' "Claude advertises optional change name"
require_text "$CLAUDE_ENTRYPOINT" '$ARGUMENTS' "Claude forwards command arguments"
require_text "$CLAUDE_ENTRYPOINT" 'unchanged' "Claude preserves command arguments"
require_text "$CLAUDE_ENTRYPOINT" 'exactly once' "Claude delegates exactly once"
require_text "$CLAUDE_ENTRYPOINT" 'Do not run archive' "Claude forbids duplicate completion actions"

require_text "$ANTIGRAVITY_ENTRYPOINT" '/opsx-commit' "Antigravity uses its flat command name"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'pass it unchanged' "Antigravity preserves optional change name"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'exactly once' "Antigravity delegates exactly once"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'Do not run archive' "Antigravity forbids duplicate completion actions"
require_text "$ANTIGRAVITY_ENTRYPOINT" '.agents/skills/openspec-commit/SKILL.md' "Antigravity names the project skill fallback"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'current context' "Antigravity fallback stays in context"
forbid_text "$ANTIGRAVITY_ENTRYPOINT" 'Skill tool' "Antigravity avoids Claude Skill tool terminology"
forbid_text "$ANTIGRAVITY_ENTRYPOINT" 'opsx:apply' "Antigravity avoids Claude command syntax"
fi

if run_section doc-updater; then
printf '\ndoc-updater context\n'
for file in "$DOC_SKILL" "$DOC_AGENT"; do
  require_text "$file" 'archive_path' "$(basename "$file") accepts archive_path"
  require_text "$file" '<archive_path>/proposal.md' "$(basename "$file") reads proposal"
  require_text "$file" '<archive_path>/specs/**/*.md' "$(basename "$file") reads delta specs"
  require_text "$file" 'git status --short' "$(basename "$file") reads status"
  require_text "$file" 'git diff HEAD' "$(basename "$file") reads actual diff"
  forbid_text "$file" '建立獨立的 `docs:` commit' "$(basename "$file") Mode B does not claim auto-commit"
done
fi

if run_section commit-writer; then
printf '\ngit-commit-writer boundary\n'
for file in "$COMMIT_SKILL" "$COMMIT_AGENT"; do
  require_text "$file" 'archive_path and change_id are provided' "$(basename "$file") explicit context is primary"
  require_text "$file" 'git add -A' "$(basename "$file") stages changes"
  require_text "$file" 'git diff --cached --quiet' "$(basename "$file") guards empty staged diff"
  require_text "$file" 'git diff --cached --name-only' "$(basename "$file") reads final staged paths"
  require_text "$file" '### Standalone context resolution' "$(basename "$file") names standalone resolution boundary"
  require_text "$file" 'feature/<change-id>' "$(basename "$file") requires exact feature branch evidence"
  require_text "$file" 'openspec/changes/<change-id>/' "$(basename "$file") requires exact active path evidence"
  require_text "$file" 'openspec/changes/archive/<archive-directory>/' "$(basename "$file") requires exact archive path evidence"
  require_text "$file" 'A sole active change without either association is not context.' "$(basename "$file") ignores a sole unrelated active change"
  require_text "$file" 'The number of active changes does not create an association.' "$(basename "$file") separates candidate count from association"
  require_text "$file" 'Zero associated candidates' "$(basename "$file") defines unscoped fallback"
  require_text "$file" 'One associated candidate' "$(basename "$file") defines associated context"
  require_text "$file" 'Multiple associated candidates' "$(basename "$file") guards ambiguity"
  require_text "$file" 'Re-run `git add -A`' "$(basename "$file") restages on retry"
  require_text "$file" 'tool_name=<executing agent tool>' "$(basename "$file") accepts tool identity"
  require_text "$file" 'assisting_model=<primary implementation model>' "$(basename "$file") accepts primary model"
  require_text "$file" 'AI-Assisted-By: <assisting_model>' "$(basename "$file") records primary model"
  add_line="$(line_of "$file" 'git add -A')"
  diff_line="$(line_of "$file" 'git diff --cached --stat')"
  if [[ -n "$add_line" && -n "$diff_line" ]] && (( add_line < diff_line )); then
    ok "$(basename "$file") stages before reading cached diff"
  else
    bad "$(basename "$file") stages before reading cached diff"
  fi
  standalone_line="$(line_of "$file" '### Standalone context resolution')"
  if [[ -n "$add_line" && -n "$standalone_line" ]] && (( add_line < standalone_line )); then
    ok "$(basename "$file") stages before standalone resolution"
  else
    bad "$(basename "$file") stages before standalone resolution"
  fi
done

require_text "$COMMIT_SKILL" 'ask the user to select one' "portable skill asks on associated ambiguity"
require_text "$COMMIT_SKILL" 'Codex <noreply@openai.com>' "portable skill maps Codex email"
require_text "$COMMIT_SKILL" 'Claude Code <noreply@anthropic.com>' "portable skill maps Claude Code email"
require_text "$COMMIT_SKILL" 'Co-Authored-By: <tool_name>' "portable skill keeps unmapped tool name"
require_text "$COMMIT_SKILL" 'MUST NOT guess' "portable skill forbids guessed attribution"
require_text "$COMMIT_AGENT" 'stop and list them' "Claude agent stops on associated ambiguity"
require_text "$COMMIT_AGENT" 'Claude Code <noreply@anthropic.com>' "Claude agent uses verified tool mapping"
require_text "$COMMIT_AGENT" 'primary implementation model' "Claude agent preserves primary implementation model"

for file in "$COMMIT_SKILL" "$COMMIT_AGENT"; do
  coauthor_line="$(line_of "$file" 'Co-Authored-By:')"
  assisted_line="$(line_of "$file" 'AI-Assisted-By: <assisting_model>')"
  if [[ -n "$coauthor_line" && -n "$assisted_line" ]] && (( coauthor_line < assisted_line )); then
    ok "$(basename "$file") orders tool attribution before model metadata"
  else
    bad "$(basename "$file") orders tool attribution before model metadata"
  fi
done
fi

printf '\n'
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
