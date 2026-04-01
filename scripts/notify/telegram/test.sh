#!/usr/bin/env bash
# Automated tests for hook.sh using TELEGRAM_DRY_RUN=true.
# No real Telegram connection needed.
# Usage: bash scripts/notify/telegram/test.sh
# Exit 0 if all tests pass; exit 1 if any fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/hook.sh"

PASS_COUNT=0
FAIL_COUNT=0

# ── Test helpers ───────────────────────────────────────────────────────────────

# run_test <name> <expected_pattern> <command...>
# Runs command with TELEGRAM_DRY_RUN=true; passes if output matches pattern.
run_test() {
  local name="$1"
  local expected_pattern="$2"
  shift 2
  local output
  output="$(TELEGRAM_DRY_RUN=true "$@" 2>/dev/null)"
  if echo "${output}" | grep -q "${expected_pattern}"; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name}"
    echo "    expected pattern: ${expected_pattern}"
    echo "    actual output:    ${output:-<empty>}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# run_test_absent <name> <absent_pattern> <command...>
# Passes if output does NOT contain the pattern.
run_test_absent() {
  local name="$1"
  local absent_pattern="$2"
  shift 2
  local output
  output="$(TELEGRAM_DRY_RUN=true "$@" 2>/dev/null)"
  if ! echo "${output}" | grep -q "${absent_pattern}"; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name} (unexpected match)"
    echo "    absent pattern: ${absent_pattern}"
    echo "    actual output:  ${output}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# run_test_empty <name> <command...>
# Passes if output is empty (command produced no output or exited early).
run_test_empty() {
  local name="$1"
  shift 1
  local output
  output="$(TELEGRAM_DRY_RUN=true "$@" 2>/dev/null)"
  if [[ -z "${output}" ]]; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name} (expected empty output)"
    echo "    actual output: ${output}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────

echo ""
echo "── hook.sh Tests ──"
echo ""

# [BUG-01] Copilot sessionEnd should show "Task Complete", not "AI CLI Event"
run_test \
  "BUG-01: sessionEnd outputs Task Complete (not AI CLI Event)" \
  "Task Complete" \
  bash "${HOOK}" sessionEnd "Copilot CLI"

run_test_absent \
  "BUG-01: sessionEnd does not output AI CLI Event" \
  "AI CLI Event" \
  bash "${HOOK}" sessionEnd "Copilot CLI"

# [BUG-02] $2 overrides env var: Copilot is shown even when CLAUDE_PROJECT_DIR is set
run_test \
  "BUG-02: \$2 overrides env var — Copilot CLI shown" \
  "Copilot CLI" \
  env CLAUDE_PROJECT_DIR=/some/path bash "${HOOK}" sessionEnd "Copilot CLI"

run_test_absent \
  "BUG-02: \$2 overrides env var — Claude Code not shown" \
  "Claude Code" \
  env CLAUDE_PROJECT_DIR=/some/path bash "${HOOK}" sessionEnd "Copilot CLI"

# [BUG-04] Claude stop → Task Complete + Claude Code
run_test \
  "BUG-04: stop + Claude Code → Task Complete" \
  "Task Complete" \
  bash -c "echo '{\"hook_event_name\":\"Stop\"}' | bash '${HOOK}' stop 'Claude Code'"

run_test \
  "BUG-04: stop + Claude Code → shows Claude Code" \
  "Claude Code" \
  bash -c "echo '{\"hook_event_name\":\"Stop\"}' | bash '${HOOK}' stop 'Claude Code'"

# [BUG-05] Claude notification → Action Required + message content
run_test \
  "BUG-05: notification → Action Required" \
  "Action Required" \
  bash -c "echo '{\"hook_event_name\":\"Notification\",\"message\":\"Test msg\"}' | bash '${HOOK}' notification 'Claude Code'"

run_test \
  "BUG-05: notification → includes message text" \
  "Test msg" \
  bash -c "echo '{\"hook_event_name\":\"Notification\",\"message\":\"Test msg\"}' | bash '${HOOK}' notification 'Claude Code'"

# [BUG-06] Gemini AfterAgent → Task Complete + Gemini CLI
run_test \
  "BUG-06: AfterAgent + Gemini CLI → Task Complete" \
  "Task Complete" \
  bash "${HOOK}" AfterAgent "Gemini CLI"

run_test \
  "BUG-06: AfterAgent + Gemini CLI → shows Gemini CLI" \
  "Gemini CLI" \
  bash "${HOOK}" AfterAgent "Gemini CLI"

# [SESSION-01] UUID session_id → truncated to #<first8>
run_test \
  "SESSION-01: UUID session_id → #<first8> in title" \
  "(#a1b2c3d4)" \
  bash -c "echo '{\"session_id\":\"a1b2c3d4-e5f6-7890-abcd-ef1234567890\"}' | bash '${HOOK}' stop 'Claude Code'"

# [SESSION-02] No session info → title has no brackets
run_test_absent \
  "SESSION-02: no session info → no ( in title" \
  "Task Complete.*(" \
  env -u GITHUB_COPILOT_SESSION_ID bash "${HOOK}" stop "Claude Code"

# Simpler check: the first line of output has no "("
# (handles grep -q matching across the whole output)
run_test_absent \
  "SESSION-02: no session info → title line has no brackets" \
  "Task Complete (" \
  env -u GITHUB_COPILOT_SESSION_ID bash "${HOOK}" stop "Claude Code"

# [LEVEL-01] notify_only suppresses stop (no output)
run_test_empty \
  "LEVEL-01: notify_only suppresses stop event" \
  env NOTIFY_LEVEL=notify_only bash "${HOOK}" stop "Claude Code"

# [LEVEL-02] notify_only allows notification (Action Required shown)
run_test \
  "LEVEL-02: notify_only allows notification event" \
  "Action Required" \
  env NOTIFY_LEVEL=notify_only bash "${HOOK}" notification "Claude Code"

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "── Results: ${PASS_COUNT}/${TOTAL} passed ──"
echo ""

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
exit 0
