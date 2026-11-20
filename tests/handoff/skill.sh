#!/usr/bin/env bash
# Handoff test section "skill". Run: bash tests/test_agent_handoff.sh skill
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- skill documentation
  printf 'agent-handoff skill\n'
  md="$SKILL/SKILL.md"
  [[ -f "$md" ]] && head -1 "$md" | grep -qx -- '---' && grep -q '^name: agent-handoff$' "$md" && grep -q '^description:' "$md"; check "SKILL.md has name and description frontmatter"
  missing=""
  for field in change round role status head note at verdict report; do
    grep -q "\`$field\`" "$md" 2>/dev/null || missing="$missing $field"
  done
  [[ -z "$missing" ]]; check "SKILL.md documents every record field" || printf '       %s\n' "(missing:$missing)"
  [[ -x "$WRITE" ]]; check "handoff-write is executable"
  AUTH="$SKILL/scripts/handoff-author"
  a1="$(env -i PATH="$PATH" CODEX_SESSION_ID=n-1 CODEX_THREAD_ID=n-1 CHIRP_SESSION_ID=x-1 CLAUDE_CODE_SESSION_ID=wrong "$AUTH" --tool Codex --model gpt-5.6-luna 2>/dev/null)"
  [[ "$a1" == $'Co-Authored-By: Codex\nAI-Assisted-By: gpt-5.6-luna\nSESSION-ID: n-1\nXIRP-SESSION-ID: x-1' ]]; check "handoff-author prints the four Author lines from the Codex environment" || printf '       %s\n' "($a1)"
  a2="$(env -i PATH="$PATH" CLAUDE_CODE_SESSION_ID=c-1 CODEX_SESSION_ID=wrong "$AUTH" --tool 'Claude Code' --model opus 2>/dev/null)"
  [[ "$a2" == $'Co-Authored-By: Claude Code\nAI-Assisted-By: opus\nSESSION-ID: c-1\nXIRP-SESSION-ID: null' ]]; check "handoff-author reads the Claude Code ID and writes null for a missing Xirp ID" || printf '       %s\n' "($a2)"
  a3="$(env -i PATH="$PATH" CHIRP_SESSION_ID=x-1 "$AUTH" --tool Codex --model '' 2>/dev/null)"
  [[ "$a3" == $'Co-Authored-By: Codex\nSESSION-ID: null\nXIRP-SESSION-ID: x-1' ]]; check "handoff-author omits an unknown model and writes null for a missing native ID" || printf '       %s\n' "($a3)"
  a4="$(env -i PATH="$PATH" HERDR_ENV=1 CLAUDE_CODE_SESSION_ID=c-2 CHIRP_SESSION_ID=x-inherited "$AUTH" --tool 'Claude Code' --model opus 2>/dev/null)"
  [[ "$a4" == $'Co-Authored-By: Claude Code\nAI-Assisted-By: opus\nSESSION-ID: c-2\nXIRP-SESSION-ID: null' ]]; check "inside a herdr pane handoff-author ignores an inherited Xirp ID" || printf '       %s\n' "($a4)"
  grep -q 'handoff-author' "$SKILL/SKILL.md"; check "SKILL.md documents handoff-author"

finish_section skill
