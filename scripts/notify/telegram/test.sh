#!/usr/bin/env bash
# Automated tests for hook.sh using TELEGRAM_DRY_RUN=true.
# No real Telegram connection needed.
# Usage: bash scripts/notify/telegram/test.sh
# Exit 0 if all tests pass; exit 1 if any fail.

set -uo pipefail
# Registry tests install the Pi extension under a temporary HOME; never the caller's Pi directory.
unset PI_CODING_AGENT_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/hook.sh"
TEST_TMP_ROOT="$(mktemp -d)"

cleanup() {
  [[ -n "${TEST_TMP_ROOT:-}" && -d "${TEST_TMP_ROOT}" ]] && rm -rf -- "${TEST_TMP_ROOT}"
}
trap cleanup EXIT

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
  output="$(env HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" 2>/dev/null)"
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
  output="$(env HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" 2>/dev/null)"
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
  output="$(env HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" 2>/dev/null)"
  if [[ -z "${output}" ]]; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name} (expected empty output)"
    echo "    actual output: ${output}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# run_test_exact <name> <expected> <command...>
# Runs without dry-run injection; used for native hook control responses.
run_test_exact() {
  local name="$1"
  local expected="$2"
  shift 2
  local output
  output="$(env HOME="${TEST_TMP_ROOT}/default-home" "$@" 2>/dev/null)"
  if [[ "${output}" == "${expected}" ]]; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name}"
    echo "    expected: ${expected}"
    echo "    actual:   ${output:-<empty>}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_equal() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual:-<empty>}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_file_contains() {
  local name="$1"
  local expected="$2"
  local file="$3"
  if grep -Fq "${expected}" "${file}"; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name}"
    echo "    missing text: ${expected}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_file_not_contains() {
  local name="$1"
  local unexpected="$2"
  local file="$3"
  if ! grep -Fq "${unexpected}" "${file}"; then
    echo "  ✓ PASS: ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAIL: ${name}"
    echo "    unexpected text: ${unexpected}"
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

# [BUG-03] Legacy Gemini environment must not affect generic host or project fallback.
run_test_absent \
  "BUG-03: GEMINI_PROJECT_DIR is ignored" \
  "legacy-gemini-project" \
  env GEMINI_PROJECT_DIR=/tmp/legacy-gemini-project bash "${HOOK}" stop

run_test \
  "BUG-03: missing payload and Claude path falls back to PWD" \
  "$(basename "${PWD}")" \
  env GEMINI_PROJECT_DIR=/tmp/legacy-gemini-project bash "${HOOK}" stop

run_test \
  "BUG-03: missing explicit tool name stays generic" \
  "AI CLI" \
  env GEMINI_PROJECT_DIR=/tmp/legacy-gemini-project bash "${HOOK}" stop

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

# [CODEX-01] Stop → completion with Codex payload fields
CODEX_STOP_PAYLOAD='{"hook_event_name":"Stop","session_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890","cwd":"/tmp/codex-project"}'
run_test \
  "CODEX-01: Stop → Task Complete" \
  "Task Complete" \
  bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${HOOK}' codex-stop 'Codex'"

run_test \
  "CODEX-01: Stop → payload cwd project" \
  "codex-project" \
  bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${HOOK}' codex-stop 'Codex'"

run_test \
  "CODEX-01: Stop → payload session label" \
  "(#a1b2c3d4)" \
  bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${HOOK}' codex-stop 'Codex'"

# [CODEX-02] PermissionRequest → action required without raw tool input
CODEX_PERMISSION_PAYLOAD='{"hook_event_name":"PermissionRequest","session_id":"codex-session","cwd":"/tmp/codex-project","tool_name":"Bash","tool_input":{"command":"rm -rf /private/secret","description":"delete private secret"},"transcript_path":"/private/transcript.jsonl"}'
run_test_empty \
  "CODEX-02: PermissionRequest sends nothing when it is raised" \
  bash -c "printf '%s' '${CODEX_PERMISSION_PAYLOAD}' | bash '${HOOK}' codex-permission 'Codex'"

run_test_empty \
  "CODEX-02: PermissionRequest sends nothing even with delay 0 (the checker owns Codex waits)" \
  env NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 bash -c "printf '%s' '${CODEX_PERMISSION_PAYLOAD}' | bash '${HOOK}' codex-permission 'Codex'"

run_test_absent \
  "CODEX-02: PermissionRequest hides raw command" \
  "rm -rf" \
  bash -c "printf '%s' '${CODEX_PERMISSION_PAYLOAD}' | bash '${HOOK}' codex-permission 'Codex'"

run_test_absent \
  "CODEX-02: PermissionRequest hides transcript path" \
  "transcript.jsonl" \
  bash -c "printf '%s' '${CODEX_PERMISSION_PAYLOAD}' | bash '${HOOK}' codex-permission 'Codex'"

# [CODEX-03] Native hooks return neutral JSON when Telegram is unavailable.
NATIVE_HOME="${TEST_TMP_ROOT}/native-home"
mkdir -p "${NATIVE_HOME}"
run_test_exact \
  "CODEX-03: Stop native response is neutral JSON" \
  "{}" \
  env HOME="${NATIVE_HOME}" bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${HOOK}' codex-stop 'Codex'"

run_test_exact \
  "CODEX-03: PermissionRequest native response is neutral JSON" \
  "{}" \
  env HOME="${NATIVE_HOME}" bash -c "printf '%s' '${CODEX_PERMISSION_PAYLOAD}' | bash '${HOOK}' codex-permission 'Codex'"

# [AGY-STOP-01] Fully idle model stop → successful completion.
AGY_STOP_PAYLOAD='{"executionNum":1,"terminationReason":"model_stop","error":"","fullyIdle":true,"conversationId":"b1c2d3e4-f5a6-7890-abcd-ef1234567890","workspacePaths":["/tmp/agy-project"]}'
run_test \
  "AGY-STOP-01: fully idle model stop → Task Complete" \
  "Task Complete" \
  bash -c "printf '%s' '${AGY_STOP_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test \
  "AGY-STOP-01: workspace path → project name" \
  "agy-project" \
  bash -c "printf '%s' '${AGY_STOP_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test \
  "AGY-STOP-01: conversation ID → session label" \
  "(#b1c2d3e4)" \
  bash -c "printf '%s' '${AGY_STOP_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

# [AGY-STOP-02] Background work still active → no completion notification.
AGY_NOT_IDLE_PAYLOAD='{"terminationReason":"model_stop","fullyIdle":false,"conversationId":"agy-not-idle","workspacePaths":["/tmp/agy-project"]}'
run_test_empty \
  "AGY-STOP-02: fullyIdle=false suppresses notification" \
  bash -c "printf '%s' '${AGY_NOT_IDLE_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

# [AGY-STOP-03] Abnormal termination is visible but raw errors stay private.
AGY_ERROR_PAYLOAD='{"terminationReason":"error","error":"token leaked at /private/secret","fullyIdle":true,"conversationId":"agy-error","workspacePaths":["/tmp/agy-project"]}'
run_test \
  "AGY-STOP-03: error → Task Stopped" \
  "Task Stopped" \
  bash -c "printf '%s' '${AGY_ERROR_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test_absent \
  "AGY-STOP-03: error is not Task Complete" \
  "Task Complete" \
  bash -c "printf '%s' '${AGY_ERROR_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test_absent \
  "AGY-STOP-03: raw error remains private" \
  "token leaked" \
  bash -c "printf '%s' '${AGY_ERROR_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

AGY_MAX_STEPS_PAYLOAD='{"terminationReason":"max_steps_exceeded","fullyIdle":true,"conversationId":"agy-max","workspacePaths":["/tmp/agy-project"]}'
run_test \
  "AGY-STOP-03: max steps → normalized reason" \
  "max steps exceeded" \
  bash -c "printf '%s' '${AGY_MAX_STEPS_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

# [LEVEL-03] Canonical reduced-noise mode suppresses only successful completion.
run_test_empty \
  "LEVEL-03: attention_required suppresses Claude completion" \
  env NOTIFY_LEVEL=attention_required bash "${HOOK}" stop "Claude Code"

run_test_empty \
  "LEVEL-03: attention_required suppresses Codex completion" \
  env NOTIFY_LEVEL=attention_required bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${HOOK}' codex-stop 'Codex'"

run_test_empty \
  "LEVEL-03: attention_required suppresses Copilot completion" \
  env NOTIFY_LEVEL=attention_required bash "${HOOK}" sessionEnd "Copilot CLI"

run_test_empty \
  "LEVEL-03: attention_required suppresses Antigravity completion" \
  env NOTIFY_LEVEL=attention_required bash -c "printf '%s' '${AGY_STOP_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test \
  "LEVEL-04: attention_required allows Claude action required" \
  "Action Required" \
  env NOTIFY_LEVEL=attention_required bash "${HOOK}" notification "Claude Code"

run_test \
  "LEVEL-04: attention_required allows a confirmed Codex authorization wait" \
  "Waiting for Your Approval" \
  env NOTIFY_LEVEL=attention_required bash -c "printf '%s' '{\"hook_event_name\":\"HumanApprovalWaiting\",\"cwd\":\"/tmp/p\"}' | bash '${HOOK}' codex-human-approval 'Codex'"

run_test \
  "LEVEL-04: attention_required allows Copilot action required" \
  "Action Required" \
  env NOTIFY_LEVEL=attention_required bash "${HOOK}" userPromptSubmitted "Copilot CLI"

run_test \
  "LEVEL-05: attention_required allows Antigravity error" \
  "Task Stopped" \
  env NOTIFY_LEVEL=attention_required bash -c "printf '%s' '${AGY_ERROR_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test \
  "LEVEL-05: attention_required allows Antigravity max steps" \
  "Task Stopped" \
  env NOTIFY_LEVEL=attention_required bash -c "printf '%s' '${AGY_MAX_STEPS_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test \
  "LEVEL-06: legacy notify_only allows Antigravity failure" \
  "Task Stopped" \
  env NOTIFY_LEVEL=notify_only bash -c "printf '%s' '${AGY_ERROR_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

run_test_empty \
  "LEVEL-07: attention_required suppresses unknown event" \
  env NOTIFY_LEVEL=attention_required bash "${HOOK}" unknown-event "AI CLI"

# [AGY-STOP-04] Native hook must allow the stop even if Telegram is disabled.
run_test_exact \
  "AGY-STOP-04: native response allows stop" \
  '{"decision":"stop"}' \
  env HOME="${NATIVE_HOME}" bash -c "printf '%s' '${AGY_STOP_PAYLOAD}' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"

# [AGY-STATUS-01] Pending transition is deduplicated and reset by false.
# Delay 0 keeps the sequence immediate; delayed timing lives in tests/test_authorization_wait.py.
AGY_STATUS_HOME="${TEST_TMP_ROOT}/agy-status-home"
mkdir -p "${AGY_STATUS_HOME}"
AGY_STATUS_TRUE='{"cwd":"/tmp/agy-project","conversation_id":"status-conversation","agent_state":"tool_use","tool_confirmation_pending":true,"email":"private@example.com"}'
AGY_STATUS_FALSE='{"cwd":"/tmp/agy-project","conversation_id":"status-conversation","agent_state":"idle","tool_confirmation_pending":false,"email":"private@example.com"}'

AGY_STATUS_FIRST="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 HOME="${AGY_STATUS_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_STATUS_REPEAT="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 HOME="${AGY_STATUS_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_STATUS_RESET="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 HOME="${AGY_STATUS_HOME}" bash -c "printf '%s' '${AGY_STATUS_FALSE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_STATUS_AFTER_RESET="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 HOME="${AGY_STATUS_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_STATUS_SEQUENCE="${AGY_STATUS_FIRST}
${AGY_STATUS_REPEAT}
${AGY_STATUS_RESET}
${AGY_STATUS_AFTER_RESET}"

if [[ "$(printf '%s\n' "${AGY_STATUS_SEQUENCE}" | grep -c "Waiting for Your Approval\*\*")" -eq 2 ]]; then
  echo "  ✓ PASS: AGY-STATUS-01: true/repeat/false/true notifies exactly twice"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: AGY-STATUS-01: expected exactly two authorization notifications"
  echo "    actual output: ${AGY_STATUS_SEQUENCE:-<empty>}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if [[ "${AGY_STATUS_REPEAT}" == "tool_use" && "${AGY_STATUS_RESET}" == "idle" ]]; then
  echo "  ✓ PASS: AGY-STATUS-01: every silent transition returns compact status"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: AGY-STATUS-01: compact status output missing"
  echo "    repeat: ${AGY_STATUS_REPEAT:-<empty>}; reset: ${AGY_STATUS_RESET:-<empty>}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if ! printf '%s\n' "${AGY_STATUS_SEQUENCE}" | grep -q "private@example.com"; then
  echo "  ✓ PASS: AGY-STATUS-01: status payload private fields stay private"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: AGY-STATUS-01: private status field leaked"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

run_test_exact \
  "AGY-STATUS-02: disabled Telegram still returns compact status" \
  "tool_use" \
  env HOME="${NATIVE_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'"

AGY_ATTENTION_HOME="${TEST_TMP_ROOT}/agy-attention-home"
mkdir -p "${AGY_ATTENTION_HOME}"
AGY_ATTENTION_FIRST="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 NOTIFY_LEVEL=attention_required HOME="${AGY_ATTENTION_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_ATTENTION_REPEAT="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 NOTIFY_LEVEL=attention_required HOME="${AGY_ATTENTION_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_ATTENTION_RESET="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 NOTIFY_LEVEL=attention_required HOME="${AGY_ATTENTION_HOME}" bash -c "printf '%s' '${AGY_STATUS_FALSE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_ATTENTION_AFTER_RESET="$(TELEGRAM_DRY_RUN=true NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 NOTIFY_LEVEL=attention_required HOME="${AGY_ATTENTION_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" 2>/dev/null)"
AGY_ATTENTION_SEQUENCE="${AGY_ATTENTION_FIRST}
${AGY_ATTENTION_REPEAT}
${AGY_ATTENTION_RESET}
${AGY_ATTENTION_AFTER_RESET}"
assert_equal \
  "AGY-STATUS-03: attention_required notifies twice across approval resets" \
  "2" \
  "$(printf '%s\n' "${AGY_ATTENTION_SEQUENCE}" | grep -c "Waiting for Your Approval\*\*")"

AGY_DISABLED_HOME="${TEST_TMP_ROOT}/agy-disabled-home"
mkdir -p "${AGY_DISABLED_HOME}"
TELEGRAM_DRY_RUN=true HOME="${AGY_DISABLED_HOME}" bash -c "printf '%s' '${AGY_STATUS_TRUE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" >/dev/null 2>&1
AGY_DISABLED_STATE="${AGY_DISABLED_HOME}/.config/ai-notify/state/antigravity-status-conversation.pending"
HOME="${AGY_DISABLED_HOME}" TELEGRAM_ENABLED=false bash -c "printf '%s' '${AGY_STATUS_FALSE}' | bash '${HOOK}' antigravity-statusline 'Antigravity CLI'" >/dev/null 2>&1
assert_equal \
  "AGY-STATUS-04: disabled delivery still clears false transition" \
  "false" \
  "$([[ -f "${AGY_DISABLED_STATE}" ]] && echo true || echo false)"

# ── Golden messages (built-in templates must reproduce these exactly) ─────────

echo ""
echo "── golden message Tests ──"
echo ""

# run_golden <name> <expected> <event> <tool> <payload> [VAR=value...]
# The clock line is normalized; everything else must match byte for byte.
run_golden() {
  local name="$1" expected="$2" event="$3" tool="$4" payload="$5" output
  shift 5
  output="$(printf '%s' "${payload}" | env HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" \
    bash "${HOOK}" "${event}" "${tool}" 2>/dev/null | sed 's/^⏰ .*/⏰ <time>/')"
  assert_equal "${name}" "${expected}" "${output}"
}

golden_body() {  # <title> <tool> <last line>
  printf '%s\n\n🤖 %s\n📂 golden-project\n⏰ <time>\n\n%s' "$1" "$2" "$3"
}

GOLDEN_SESSION='"session_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890","cwd":"/tmp/golden-project"'
run_golden "GOLDEN-01: Claude stop" \
  "$(golden_body '🟢 **Task Complete** (#a1b2c3d4)' 'Claude Code' 'Process finished successfully #Stop')" \
  stop 'Claude Code' "{\"hook_event_name\":\"Stop\",${GOLDEN_SESSION}}"
run_golden "GOLDEN-02: Codex stop" \
  "$(golden_body '🟢 **Task Complete** (#a1b2c3d4)' 'Codex' 'Process finished successfully #Stop')" \
  codex-stop Codex "{\"hook_event_name\":\"Stop\",${GOLDEN_SESSION}}"
run_golden "GOLDEN-03: Copilot sessionEnd" \
  "$(golden_body '🟢 **Task Complete**' 'Copilot CLI' 'Process finished successfully #sessionend')" \
  sessionEnd 'Copilot CLI' '{"cwd":"/tmp/golden-project"}'
run_golden "GOLDEN-04: Codex question wait" \
  "$(golden_body '🟡 **Waiting for Your Response** (#a1b2c3d4)' 'Codex' 'Codex has a question awaiting your response. #UserInputWaiting')" \
  codex-user-input Codex "{\"hook_event_name\":\"UserInputWaiting\",${GOLDEN_SESSION}}" NOTIFY_CODEX_USER_INPUT=true
run_golden "GOLDEN-05: Codex async question" \
  "$(golden_body '🟡 **Waiting for Your Response** (#a1b2c3d4)' 'Codex' 'Codex has a question awaiting your response. #AsyncUserInputRequested')" \
  codex-async-question Codex "{\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"request_user_input_async\",\"tool_response\":{\"accepted\":true},${GOLDEN_SESSION}}" NOTIFY_CODEX_USER_INPUT=true
run_golden "GOLDEN-06: Claude notification with message" \
  "$(golden_body '🟡 **Action Required** (#a1b2c3d4)' 'Claude Code' 'Claude is waiting for your input #Notification')" \
  notification 'Claude Code' "{\"hook_event_name\":\"Notification\",\"message\":\"Claude is waiting for your input\",${GOLDEN_SESSION}}"
run_golden "GOLDEN-07: Claude notification without message" \
  "$(golden_body '🟡 **Action Required** (#a1b2c3d4)' 'Claude Code' 'Waiting for user interaction... #Notification')" \
  notification 'Claude Code' "{\"hook_event_name\":\"Notification\",${GOLDEN_SESSION}}"
run_golden "GOLDEN-08: Copilot prompt submitted" \
  "$(golden_body '🟡 **Action Required**' 'Copilot CLI' 'Waiting for user interaction... #userpromptsubmitted')" \
  userPromptSubmitted 'Copilot CLI' '{"cwd":"/tmp/golden-project"}'
run_golden "GOLDEN-09: Antigravity completion" \
  "$(golden_body '🟢 **Task Complete** (#b1c2d3e4)' 'Antigravity CLI' 'Process finished successfully #antigravity-stop')" \
  antigravity-stop 'Antigravity CLI' '{"terminationReason":"model_stop","fullyIdle":true,"conversationId":"b1c2d3e4-f5a6-7890-abcd-ef1234567890","workspacePaths":["/tmp/golden-project"]}'
run_golden "GOLDEN-10: Antigravity stopped" \
  "$(golden_body '🔴 **Task Stopped** (agy-golden)' 'Antigravity CLI' 'Execution ended: error #antigravity-stop')" \
  antigravity-stop 'Antigravity CLI' '{"terminationReason":"error","error":"secret","fullyIdle":true,"conversationId":"agy-golden","workspacePaths":["/tmp/golden-project"]}'
run_golden "GOLDEN-11: unknown event" \
  "$(golden_body '🤖 **AI CLI Event**' 'AI CLI' '#unknown-event')" \
  unknown-event 'AI CLI' '{"cwd":"/tmp/golden-project"}'

# ── Template rendering ─────────────────────────────────────────────────────────

echo ""
echo "── template Tests ──"
echo ""

TEMPLATE_LIB="${SCRIPT_DIR}/../lib/template.sh"
# render_text <template text> [name=value...] — renders with the given values only.
render_text() {
  bash -c 'source "$1" || exit 9; text="$2"; shift 2
    for pair in "$@"; do printf -v "tpl_${pair%%=*}" "%s" "${pair#*=}"; done
    notify_render_text "${text}"' _ "${TEMPLATE_LIB}" "$@" 2>&1
}

assert_equal "TPL-01: placeholder is replaced" \
  "📂 fio-pv-twin done" "$(render_text '📂 {project} done' project=fio-pv-twin)"
assert_equal "TPL-02: values are escaped for Telegram Markdown" \
  '**Title** a\_b \*c\* \`d\` \[e' "$(render_text '**Title** {message}' 'message=a_b *c* `d` [e')"
assert_equal "TPL-03: a line holding only empty placeholders is removed" \
  "$(printf 'top\nbottom')" "$(render_text "$(printf 'top\n{message}\nbottom')")"
assert_equal "TPL-03: a line with text around an empty value is kept" \
  "$(printf 'top\nx  y\nbottom')" "$(render_text "$(printf 'top\nx {message} y\nbottom')")"
assert_equal "TPL-04: unknown placeholder is left unchanged" \
  "keep {nope} here" "$(render_text 'keep {nope} here')"
assert_equal "TPL-04: a value is not substituted again" \
  'a {tool} b' "$(render_text 'a {message} b' 'message={tool}' tool=Codex)"
TPL_MARKER="${TEST_TMP_ROOT}/template-executed"
assert_equal "TPL-05: shell syntax is delivered literally" \
  "\$(touch ${TPL_MARKER}) \`touch ${TPL_MARKER}\` \${HOME}" \
  "$(render_text "\$(touch ${TPL_MARKER}) \`touch ${TPL_MARKER}\` \${HOME}")"
assert_equal "TPL-05: template content is never executed" \
  "false" "$([[ -e "${TPL_MARKER}" ]] && echo true || echo false)"
for TPL_NAME in completion stopped question action-required generic; do
  assert_equal "TPL-06: built-in template ${TPL_NAME} exists" \
    "true" "$([[ -s "${SCRIPT_DIR}/templates/${TPL_NAME}.md" ]] && echo true || echo false)"
done

# ── Event table ────────────────────────────────────────────────────────────────

echo ""
echo "── event table Tests ──"
echo ""

# A copy of the deployed layout whose table can be edited without touching the repo.
TABLE_ROOT="${TEST_TMP_ROOT}/table-layout"
mkdir -p "${TABLE_ROOT}/hooks" "${TABLE_ROOT}/lib"
cp "${HOOK}" "${TABLE_ROOT}/hooks/telegram-notify.sh"
cp "${SCRIPT_DIR}/../lib/"*.sh "${TABLE_ROOT}/lib/"
cp -R "${SCRIPT_DIR}/templates" "${TABLE_ROOT}/hooks/templates" 2>/dev/null || mkdir -p "${TABLE_ROOT}/hooks/templates"
cp "${SCRIPT_DIR}/events.tsv" "${TABLE_ROOT}/hooks/events.tsv" 2>/dev/null || : > "${TABLE_ROOT}/hooks/events.tsv"
TABLE_HOOK="${TABLE_ROOT}/hooks/telegram-notify.sh"

assert_equal "TABLE-01: repository ships the event table" \
  "true" "$([[ -s "${SCRIPT_DIR}/events.tsv" ]] && echo true || echo false)"
sed -i.bak 's/^codex-stop	completion	completion/codex-stop	completion	generic/' "${TABLE_ROOT}/hooks/events.tsv"
run_test "TABLE-02: a known event resolves its template through the table" \
  "AI CLI Event" \
  bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${TABLE_HOOK}' codex-stop Codex"
run_test_empty "TABLE-02: the table category drives the switch" \
  env NOTIFY_COMPLETION=false bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${TABLE_HOOK}' codex-stop Codex"
printf 'custom-event\tfailure\tcustom\n' >> "${TABLE_ROOT}/hooks/events.tsv"
printf '🧪 custom {project}{title_suffix}\n' > "${TABLE_ROOT}/hooks/templates/custom.md"
run_test "TABLE-03: a new kind needs only a table row and a template" \
  "🧪 custom codex-project (#a1b2c3d4)" \
  bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${TABLE_HOOK}' custom-event Codex"
run_test_empty "TABLE-03: the new kind follows its category switch" \
  env NOTIFY_FAILURE=false bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${TABLE_HOOK}' custom-event Codex"
run_test "TABLE-04: an event absent from the table keeps the generic message" \
  "AI CLI Event" \
  bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${TABLE_HOOK}' not-in-table Codex"
assert_equal "TABLE-05: hook no longer builds messages in a case statement" \
  "0" "$(grep -c 'MESSAGE="' "${HOOK}")"

# ── Category resolution (design decision 2) ────────────────────────────────────

echo ""
echo "── category resolution Tests ──"
echo ""

CONFIG_LIB="${SCRIPT_DIR}/../lib/config.sh"
CAT_HOME="${TEST_TMP_ROOT}/category-home"
mkdir -p "${CAT_HOME}/.config/ai-notify"
# category <KEY> <config lines separated by spaces> [VAR=value...] → resolved value
category() {
  local key="$1" lines="$2"; shift 2
  printf '%s\n' ${lines} > "${CAT_HOME}/.config/ai-notify/config"
  env -i PATH="${PATH}" HOME="${CAT_HOME}" "$@" bash -c \
    'source "$1"; read_config; notify_category_value "$2"' _ "${CONFIG_LIB}" "${key}" 2>&1
}
both() {  # <config lines> [VAR=value...] → "<authorization> <user_input>"
  printf '%s %s' "$(category NOTIFY_AUTHORIZATION "$@")" "$(category NOTIFY_USER_INPUT "$@")"
}

assert_equal "CAT-01: legacy ACTION_REQUIRED=true only" "true true" "$(both 'NOTIFY_ACTION_REQUIRED=true')"
assert_equal "CAT-02: current machine — one legacy key on, Codex approval off" "true true" \
  "$(both 'NOTIFY_ACTION_REQUIRED=true NOTIFY_CODEX_HUMAN_APPROVAL=false NOTIFY_CODEX_USER_INPUT=true')"
assert_equal "CAT-03: ACTION_REQUIRED=false and Codex approval on" "true false" \
  "$(both 'NOTIFY_ACTION_REQUIRED=false NOTIFY_CODEX_HUMAN_APPROVAL=true')"
assert_equal "CAT-03: ACTION_REQUIRED=false follows CODEX_USER_INPUT" "true true" \
  "$(both 'NOTIFY_ACTION_REQUIRED=false NOTIFY_CODEX_HUMAN_APPROVAL=true NOTIFY_CODEX_USER_INPUT=true')"
assert_equal "CAT-04: every legacy key false" "false false" \
  "$(both 'NOTIFY_ACTION_REQUIRED=false NOTIFY_CODEX_HUMAN_APPROVAL=false NOTIFY_CODEX_USER_INPUT=false')"
assert_equal "CAT-04: ACTION_REQUIRED=false and Codex keys absent" "false false" \
  "$(both 'NOTIFY_ACTION_REQUIRED=false')"
assert_equal "CAT-05: nothing defined" "true true" "$(both 'TELEGRAM_ENABLED=true')"
assert_equal "CAT-06: new key wins over legacy keys in the file" "false" \
  "$(category NOTIFY_AUTHORIZATION 'NOTIFY_AUTHORIZATION=false NOTIFY_ACTION_REQUIRED=true')"
assert_equal "CAT-06: quoted file value is read" "false" \
  "$(category NOTIFY_AUTHORIZATION 'NOTIFY_AUTHORIZATION="false" NOTIFY_ACTION_REQUIRED=true')"
assert_equal "CAT-07: environment new key beats environment legacy key" "false" \
  "$(category NOTIFY_USER_INPUT 'TELEGRAM_ENABLED=true' NOTIFY_USER_INPUT=false NOTIFY_ACTION_REQUIRED=true)"
assert_equal "CAT-08: environment legacy key beats the file's new key" "true" \
  "$(category NOTIFY_USER_INPUT 'NOTIFY_USER_INPUT=false' NOTIFY_ACTION_REQUIRED=true)"
assert_equal "CAT-09: one true and one false in the environment merge to true" "true" \
  "$(category NOTIFY_AUTHORIZATION 'NOTIFY_AUTHORIZATION=false' NOTIFY_ACTION_REQUIRED=false NOTIFY_CODEX_HUMAN_APPROVAL=true)"
assert_equal "CAT-10: invalid value is undefined" "false" \
  "$(category NOTIFY_AUTHORIZATION 'NOTIFY_AUTHORIZATION=yes NOTIFY_ACTION_REQUIRED=false')"
assert_equal "CAT-10: empty value is undefined" "true" \
  "$(category NOTIFY_AUTHORIZATION 'NOTIFY_AUTHORIZATION= NOTIFY_ACTION_REQUIRED=true')"
assert_equal "CAT-10: empty environment value is undefined" "false" \
  "$(category NOTIFY_AUTHORIZATION 'NOTIFY_AUTHORIZATION=false' NOTIFY_AUTHORIZATION=)"
assert_equal "CAT-11: failure defaults on" "true" "$(category NOTIFY_FAILURE 'TELEGRAM_ENABLED=true')"
assert_equal "CAT-11: completion follows attention_required" "false" \
  "$(category NOTIFY_COMPLETION 'NOTIFY_LEVEL=attention_required')"
assert_equal "CAT-11: environment completion overrides the file" "true" \
  "$(category NOTIFY_COMPLETION 'NOTIFY_COMPLETION=false' NOTIFY_COMPLETION=true)"

# ── Claude Code notification types ─────────────────────────────────────────────

echo ""
echo "── Claude notification type Tests ──"
echo ""

claude_notification() {  # <type or empty> → payload
  if [[ -n "$1" ]]; then
    printf '{"hook_event_name":"Notification","notification_type":"%s","message":"Claude says %s","cwd":"/tmp/p"}' "$1" "$1"
  else
    printf '{"hook_event_name":"Notification","message":"Claude says untyped","cwd":"/tmp/p"}'
  fi
}
for CLAUDE_TYPE in idle_prompt agent_needs_input elicitation_dialog elicitation_url_dialog; do
  run_test "CLAUDE-TYPE-01: ${CLAUDE_TYPE} is sent at once as waiting for response" \
    "Claude says ${CLAUDE_TYPE//_/\\\\_}" \
    bash -c "printf '%s' '$(claude_notification "${CLAUDE_TYPE}")' | bash '${HOOK}' notification 'Claude Code'"
  run_test_empty "CLAUDE-TYPE-01: ${CLAUDE_TYPE} follows the user-input switch" \
    env NOTIFY_USER_INPUT=false bash -c "printf '%s' '$(claude_notification "${CLAUDE_TYPE}")' | bash '${HOOK}' notification 'Claude Code'"
done
run_test "CLAUDE-TYPE-02: a notification without a type is waiting for response" \
  "Claude says untyped" \
  bash -c "printf '%s' '$(claude_notification '')' | bash '${HOOK}' notification 'Claude Code'"
CLAUDE_TYPE_HOME="${TEST_TMP_ROOT}/claude-type-home"
mkdir -p "${CLAUDE_TYPE_HOME}/.config/ai-notify"
printf '%s\n' 'NOTIFY_USER_INPUT=false' > "${CLAUDE_TYPE_HOME}/.config/ai-notify/config"
assert_equal "CLAUDE-TYPE-02: untyped notification with NOTIFY_ACTION_REQUIRED=true in the environment is still sent" \
  "true" \
  "$(printf '%s' "$(claude_notification '')" | env HOME="${CLAUDE_TYPE_HOME}" TELEGRAM_DRY_RUN=true NOTIFY_ACTION_REQUIRED=true bash "${HOOK}" notification 'Claude Code' | grep -q 'Claude says untyped' && echo true || echo false)"
for CLAUDE_TYPE in auth_success agent_completed quota_auto_resume_scheduled plugin_notification; do
  run_test_empty "CLAUDE-TYPE-03: informational ${CLAUDE_TYPE} is not sent" \
    bash -c "printf '%s' '$(claude_notification "${CLAUDE_TYPE}")' | bash '${HOOK}' notification 'Claude Code'"
done
run_test_empty "CLAUDE-TYPE-04: permission_prompt follows the authorization switch" \
  env NOTIFY_AUTHORIZATION=false NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 bash -c "printf '%s' '$(claude_notification permission_prompt)' | bash '${HOOK}' notification 'Claude Code'"
# This payload has no transcript_path, so the wait cannot be confirmed (review codex-01a1ee38-r02/F-02).
run_test "CLAUDE-TYPE-04: permission_prompt is an authorization notice" \
  "Approval Status Unknown" \
  env NOTIFY_AUTHORIZATION_DELAY_SECONDS=0 bash -c "printf '%s' '$(claude_notification permission_prompt)' | bash '${HOOK}' notification 'Claude Code'"

# ── Antigravity termination reasons ────────────────────────────────────────────

echo ""
echo "── Antigravity termination reason Tests ──"
echo ""

agy_stop() {  # <reason> [fullyIdle] → payload with a private error text
  printf '{"terminationReason":"%s","error":"PRIVATE-ERROR-TEXT","fullyIdle":%s,"conversationId":"agy-reason","workspacePaths":["/tmp/agy-project"]}' "$1" "${2:-true}"
}
for AGY_REASON in NO_TOOL_CALL no_tool_call model_stop MODEL_STOP; do
  run_test "AGY-REASON-01: ${AGY_REASON} with fullyIdle is Task Complete" \
    "Task Complete" \
    bash -c "printf '%s' '$(agy_stop "${AGY_REASON}")' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"
done
run_test_empty "AGY-REASON-02: NO_TOOL_CALL while background work runs sends nothing" \
  bash -c "printf '%s' '$(agy_stop NO_TOOL_CALL false)' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"
for AGY_REASON in USER_CANCELED user_canceled; do
  run_test_empty "AGY-REASON-03: ${AGY_REASON} sends nothing" \
    bash -c "printf '%s' '$(agy_stop "${AGY_REASON}")' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"
done
run_test_exact "AGY-REASON-03: a cancelled stop still lets Antigravity stop" \
  '{"decision":"stop"}' \
  env HOME="${NATIVE_HOME}" bash -c "printf '%s' '$(agy_stop USER_CANCELED)' | bash '${HOOK}' antigravity-stop 'Antigravity CLI'"
for AGY_CASE in "ERROR|Execution ended: error" "MAX_INVOCATIONS|Execution ended: max invocations reached" \
                "MAX_TOKEN_BUDGET_EXCEEDED|Execution ended: token budget exceeded" \
                "MAX_FORCED_INVOCATIONS|Execution ended: max forced invocations reached" \
                "TERMINAL_STEP_TYPE|Execution ended: terminal step" \
                "SOMETHING_NEW|Execution ended: execution stopped"; do
  AGY_REASON="${AGY_CASE%%|*}"
  AGY_OUTPUT="$(printf '%s' "$(agy_stop "${AGY_REASON}")" | env HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true bash "${HOOK}" antigravity-stop 'Antigravity CLI' 2>/dev/null)"
  assert_equal "AGY-REASON-04: ${AGY_REASON} is Task Stopped with its fixed label" \
    "true true false false" \
    "$(grep -q 'Task Stopped' <<<"${AGY_OUTPUT}" && echo true || echo false) $(grep -qF "${AGY_CASE#*|} #" <<<"${AGY_OUTPUT}" && echo true || echo false) $(grep -q 'Task Complete' <<<"${AGY_OUTPUT}" && echo true || echo false) $(grep -q 'PRIVATE-ERROR-TEXT' <<<"${AGY_OUTPUT}" && echo true || echo false)"
done

# ── Re-arm boundary (review codex-01a1ee38-r02/F-06) ──────────────────────────

echo ""
echo "── re-arm boundary Tests ──"
echo ""

REARM_MARKER="${TEST_TMP_ROOT}/rearm.pending"
printf '%s\n' 'id=w-test' 'ided=0' 'started=50' 'notified=100' 'tool=a tool' > "${REARM_MARKER}"
rearm_decide() {  # <now> → new|same for a notice at 100 and an interval of 600
  HOME="${TEST_TMP_ROOT}/default-home" bash -c 'source "$1"; auth_decide "$2" "" 600 "$3"' _ \
    "${SCRIPT_DIR}/../lib/authorization.sh" "${REARM_MARKER}" "$1"
}
assert_equal "REARM-01: a signal exactly at the interval begins a new wait" "new" "$(rearm_decide 700)"
assert_equal "REARM-01: a signal one second short is merged" "same" "$(rearm_decide 699)"
printf '%s\n' 'id=w-test' 'ided=0' 'started=50' 'notified=0' 'tool=a tool' > "${REARM_MARKER}"
assert_equal "REARM-02: a wait not yet notified never re-arms" "same" "$(rearm_decide 99999)"

# ── Registry tests (isolated HOME/repository) ──────────────────────────────────

echo ""
echo "── registry.sh Tests ──"
echo ""

REGISTRY="${SCRIPT_DIR}/../lib/registry.sh"
REGISTRY_HOME="${TEST_TMP_ROOT}/registry-home"
FAKE_HOOK="${REGISTRY_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
mkdir -p "$(dirname "${FAKE_HOOK}")" "${REGISTRY_HOME}/.codex" "${REGISTRY_HOME}/.gemini/config" "${REGISTRY_HOME}/.gemini/antigravity-cli"
touch "${FAKE_HOOK}"

# [REG-GLOBAL-01] Supported hosts register idempotently; Gemini is cleanup-only.
LEGACY_GEMINI_AFTER="bash \"${FAKE_HOOK}\" AfterAgent \"Gemini CLI\""
LEGACY_GEMINI_NOTIFY="bash \"${FAKE_HOOK}\" notification \"Gemini CLI\""
jq -n \
  --arg after "${LEGACY_GEMINI_AFTER}" \
  --arg notify "${LEGACY_GEMINI_NOTIFY}" \
  '{
    theme: "dark",
    hooks: {
      AfterAgent: [{hooks: [
        {type: "command", command: $after},
        {type: "command", command: "other-after"}
      ]}],
      Notification: [{hooks: [
        {type: "command", command: $notify},
        {type: "command", command: "other-notification"}
      ]}]
    }
  }' > "${REGISTRY_HOME}/.gemini/settings.json"

HOME="${REGISTRY_HOME}" bash -c 'source "$1"; register_hook "$2"; register_hook "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true

assert_equal \
  "REG-GLOBAL-01: notification-owned legacy Gemini hooks are removed" \
  "0" \
  "$(jq --arg prefix "bash \"${FAKE_HOOK}\"" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.gemini/settings.json")"
assert_equal \
  "REG-GLOBAL-01: unrelated Gemini AfterAgent hook is preserved" \
  "1" \
  "$(jq '[.. | objects | .command? // empty | select(. == "other-after")] | length' "${REGISTRY_HOME}/.gemini/settings.json")"
assert_equal \
  "REG-GLOBAL-01: unrelated Gemini Notification hook is preserved" \
  "1" \
  "$(jq '[.. | objects | .command? // empty | select(. == "other-notification")] | length' "${REGISTRY_HOME}/.gemini/settings.json")"
assert_equal \
  "REG-GLOBAL-01: Claude Stop is registered once" \
  "1" \
  "$(jq --arg prefix "bash \"${FAKE_HOOK}\" stop" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.claude/settings.json")"
assert_equal \
  "REG-GLOBAL-01: Antigravity approval observer is automatic" \
  "bash \"${FAKE_HOOK}\" antigravity-statusline \"Antigravity CLI\"" \
  "$(jq -r '.statusLine.command // empty' "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json")"

assert_equal \
  "REG-GLOBAL-01: Codex naming does not reach Claude or Antigravity handlers" \
  "0 0" \
  "$(jq '[.. | objects | select(has("statusMessage"))] | length' "${REGISTRY_HOME}/.claude/settings.json") $(jq '[.. | objects | select(has("statusMessage"))] | length' "${REGISTRY_HOME}/.gemini/config/hooks.json")"

GLOBAL_STATUS_OUTPUT="$(HOME="${REGISTRY_HOME}" bash -c 'source "$1"; show_hook_status "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" 2>&1 || true)"
if ! printf '%s\n' "${GLOBAL_STATUS_OUTPUT}" | grep -q "Gemini CLI"; then
  echo "  ✓ PASS: REG-GLOBAL-01: active status excludes Gemini CLI"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: REG-GLOBAL-01: active status still lists Gemini CLI"
  echo "    actual output: ${GLOBAL_STATUS_OUTPUT}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

HOME="${REGISTRY_HOME}" bash -c 'source "$1"; unregister_hook "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal \
  "REG-GLOBAL-01: global unregister removes Claude hooks" \
  "0" \
  "$(jq --arg prefix "bash \"${FAKE_HOOK}\"" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.claude/settings.json")"
assert_equal \
  "REG-GLOBAL-01: global unregister removes Codex hooks" \
  "0" \
  "$(jq --arg prefix "bash \"${FAKE_HOOK}\"" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.codex/hooks.json")"
assert_equal \
  "REG-GLOBAL-01: global unregister removes Antigravity hooks" \
  "0" \
  "$(jq --arg prefix "bash \"${FAKE_HOOK}\"" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.gemini/config/hooks.json")"
assert_equal \
  "REG-GLOBAL-01: global unregister removes owned approval observer" \
  "false" \
  "$(jq 'has("statusLine")' "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json")"
assert_equal \
  "REG-GLOBAL-01: global unregister preserves unrelated Gemini settings" \
  "dark" \
  "$(jq -r '.theme' "${REGISTRY_HOME}/.gemini/settings.json")"

# [REG-GLOBAL-02] A non-owned status line is preserved and reported unavailable.
CONFLICT_HOME="${TEST_TMP_ROOT}/registry-conflict-home"
CONFLICT_HOOK="${CONFLICT_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
mkdir -p "$(dirname "${CONFLICT_HOOK}")" "${CONFLICT_HOME}/.gemini/antigravity-cli"
touch "${CONFLICT_HOOK}"
printf '%s\n' '{"statusLine":{"type":"command","command":"/existing/status.sh"}}' > "${CONFLICT_HOME}/.gemini/antigravity-cli/settings.json"
HOME="${CONFLICT_HOME}" bash -c 'source "$1"; register_hook "$2"' _ "${REGISTRY}" "${CONFLICT_HOOK}" >/dev/null 2>&1
assert_equal \
  "REG-GLOBAL-02: existing Antigravity status line survives automatic setup" \
  "/existing/status.sh" \
  "$(jq -r '.statusLine.command' "${CONFLICT_HOME}/.gemini/antigravity-cli/settings.json")"
CONFLICT_STATUS_OUTPUT="$(HOME="${CONFLICT_HOME}" bash -c 'source "$1"; show_hook_status "$2"' _ "${REGISTRY}" "${CONFLICT_HOOK}" 2>&1 || true)"
if printf '%s\n' "${CONFLICT_STATUS_OUTPUT}" | grep -q "Antigravity approval: unavailable"; then
  echo "  ✓ PASS: REG-GLOBAL-02: approval conflict is distinguishable in status"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: REG-GLOBAL-02: status does not distinguish approval conflict"
  echo "    actual output: ${CONFLICT_STATUS_OUTPUT}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# [REG-CODEX-01] Register twice and preserve unrelated JSON.
printf '%s\n' '{"unrelated":{"keep":true},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"other-stop"}]}]}}' > "${REGISTRY_HOME}/.codex/hooks.json"
HOME="${REGISTRY_HOME}" bash -c 'source "$1"; register_hook_codex "$2"; register_hook_codex "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true

CODEX_STOP_PREFIX="bash \"${FAKE_HOOK}\" codex-stop"
CODEX_PERMISSION_PREFIX="bash \"${FAKE_HOOK}\" codex-permission"
CODEX_STOP_COUNT="$(jq --arg prefix "${CODEX_STOP_PREFIX}" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.codex/hooks.json")"
CODEX_PERMISSION_COUNT="$(jq --arg prefix "${CODEX_PERMISSION_PREFIX}" '[.. | objects | .command? // empty | select(startswith($prefix))] | length' "${REGISTRY_HOME}/.codex/hooks.json")"
assert_equal "REG-CODEX-01: Stop registered once" "1" "${CODEX_STOP_COUNT}"
assert_equal "REG-CODEX-01: PermissionRequest registered once" "1" "${CODEX_PERMISSION_COUNT}"
assert_equal "REG-CODEX-01: unrelated JSON preserved" "true" "$(jq -r '.unrelated.keep' "${REGISTRY_HOME}/.codex/hooks.json")"

HOME="${REGISTRY_HOME}" bash -c 'source "$1"; unregister_hook_codex "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal "REG-CODEX-01: owned hooks removed" "0" "$(jq '[.. | objects | .command? // empty | select(contains("'"${FAKE_HOOK}"'"))] | length' "${REGISTRY_HOME}/.codex/hooks.json")"
assert_equal "REG-CODEX-01: unrelated hook survives unregister" "other-stop" "$(jq -r '.hooks.Stop[0].hooks[0].command' "${REGISTRY_HOME}/.codex/hooks.json")"

# [REG-CODEX-NAME] Owned Codex handlers carry display names; existing ones are filled in place.
NAME_HOME="${TEST_TMP_ROOT}/codex-name-home"
NAME_HOOK="${NAME_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
NAME_FILE="${NAME_HOME}/.codex/hooks.json"
mkdir -p "$(dirname "${NAME_HOOK}")" "${NAME_HOME}/.codex"
touch "${NAME_HOOK}"
NAME_STOP="bash \"${NAME_HOOK}\" codex-stop \"Codex\""
NAME_PERMISSION="bash \"${NAME_HOOK}\" codex-permission \"Codex\""
NAME_QUESTION="bash \"${NAME_HOOK}\" codex-question \"Codex\""
NAME_ASYNC="bash \"${NAME_HOOK}\" codex-async-question \"Codex\""
name_of() { jq -r --arg cmd "$2" "[.hooks.$1[]?.hooks[]? | select(.command == \$cmd) | .statusMessage] | join(\"|\")" "${NAME_FILE}"; }
count_of() { jq --arg cmd "$2" "[.hooks.$1[]?.hooks[]? | select(.command == \$cmd)] | length" "${NAME_FILE}"; }
without_names() { jq -S 'walk(if type == "object" then del(.statusMessage) else . end)' "$1"; }
register_codex_names() { HOME="${NAME_HOME}" bash -c 'source "$1"; register_hook_codex "$2"' _ "${REGISTRY}" "${NAME_HOOK}" >/dev/null 2>&1 || true; }

printf '%s\n' '{}' > "${NAME_FILE}"
register_codex_names
assert_equal "REG-CODEX-NAME: new Stop is named" "Telegram 完成通知" "$(name_of Stop "${NAME_STOP}")"
assert_equal "REG-CODEX-NAME: new PermissionRequest is named" "Telegram 操作確認與等待檢查" "$(name_of PermissionRequest "${NAME_PERMISSION}")"
assert_equal "REG-CODEX-NAME: new question PreToolUse is named" "Telegram 同步問題等待檢查" "$(name_of PreToolUse "${NAME_QUESTION}")"
assert_equal "REG-CODEX-NAME: new async PostToolUse is named" "Telegram 非同步問題通知" "$(name_of PostToolUse "${NAME_ASYNC}")"

# absent (Stop, shared group with a third-party handler), null, empty and whitespace-only names.
jq -n --arg stop "${NAME_STOP}" --arg perm "${NAME_PERMISSION}" --arg q "${NAME_QUESTION}" --arg aq "${NAME_ASYNC}" '{
  unrelated: {keep: true},
  hooks: {
    Stop: [{hooks: [
      {type: "command", command: "other-stop", statusMessage: "第三方"},
      {type: "command", command: $stop, timeout: 5, extra: "keep"}
    ], extra_group: "keep"}],
    PermissionRequest: [{hooks: [{type: "command", command: $perm, timeout: 5, statusMessage: null}]}],
    PreToolUse: [{matcher: "^(request_user_input|request_user_input_async)$", hooks: [{type: "command", command: $q, timeout: 5, statusMessage: ""}]}],
    PostToolUse: [{matcher: "^request_user_input_async$", hooks: [{type: "command", command: $aq, timeout: 5, statusMessage: "   "}]}]
  }
}' > "${NAME_FILE}"
cp "${NAME_FILE}" "${NAME_HOME}/before.json"
register_codex_names
assert_equal "REG-CODEX-NAME: absent Stop name is filled" "Telegram 完成通知" "$(name_of Stop "${NAME_STOP}")"
assert_equal "REG-CODEX-NAME: null PermissionRequest name is filled" "Telegram 操作確認與等待檢查" "$(name_of PermissionRequest "${NAME_PERMISSION}")"
assert_equal "REG-CODEX-NAME: empty PreToolUse name is filled" "Telegram 同步問題等待檢查" "$(name_of PreToolUse "${NAME_QUESTION}")"
assert_equal "REG-CODEX-NAME: whitespace PostToolUse name is filled" "Telegram 非同步問題通知" "$(name_of PostToolUse "${NAME_ASYNC}")"
assert_equal "REG-CODEX-NAME: each owned handler stays single" "1 1 1 1" \
  "$(count_of Stop "${NAME_STOP}") $(count_of PermissionRequest "${NAME_PERMISSION}") $(count_of PreToolUse "${NAME_QUESTION}") $(count_of PostToolUse "${NAME_ASYNC}")"
assert_equal "REG-CODEX-NAME: third-party name in the same group is kept" "第三方" "$(name_of Stop other-stop)"
assert_equal "REG-CODEX-NAME: only statusMessage changed" "$(without_names "${NAME_HOME}/before.json")" "$(without_names "${NAME_FILE}")"
jq -S . "${NAME_FILE}" > "${NAME_HOME}/first.json"
register_codex_names
assert_equal "REG-CODEX-NAME: rerun leaves JSON unchanged" "$(cat "${NAME_HOME}/first.json")" "$(jq -S . "${NAME_FILE}")"

jq -n --arg stop "${NAME_STOP}" '{hooks: {Stop: [{hooks: [{type: "command", command: $stop, timeout: 5, statusMessage: "我的完成提醒"}]}]}}' > "${NAME_FILE}"
register_codex_names
register_codex_names
assert_equal "REG-CODEX-NAME: custom name survives repeated registration" "我的完成提醒" "$(name_of Stop "${NAME_STOP}")"
assert_equal "REG-CODEX-NAME: custom-named handler is not duplicated" "1" "$(count_of Stop "${NAME_STOP}")"

# [REG-AGY-01] Named Stop hook is idempotent and ownership-scoped.
printf '%s\n' '{"other-hook":{"Stop":[{"type":"command","command":"other-stop"}]}}' > "${REGISTRY_HOME}/.gemini/config/hooks.json"
HOME="${REGISTRY_HOME}" bash -c 'source "$1"; register_hook_antigravity "$2"; register_hook_antigravity "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal "REG-AGY-01: named Stop registered once" "1" "$(jq '.["telegram-notify"].Stop | length' "${REGISTRY_HOME}/.gemini/config/hooks.json")"
assert_equal "REG-AGY-01: unrelated named hook preserved" "other-stop" "$(jq -r '.["other-hook"].Stop[0].command' "${REGISTRY_HOME}/.gemini/config/hooks.json")"

HOME="${REGISTRY_HOME}" bash -c 'source "$1"; unregister_hook_antigravity "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal "REG-AGY-01: owned named hook removed" "false" "$(jq 'has("telegram-notify")' "${REGISTRY_HOME}/.gemini/config/hooks.json")"
assert_equal "REG-AGY-01: unrelated named hook survives unregister" "true" "$(jq 'has("other-hook")' "${REGISTRY_HOME}/.gemini/config/hooks.json")"

# [REG-AGY-02] Status line registration refuses an existing different command.
printf '%s\n' '{"theme":"dark","statusLine":{"type":"command","command":"/existing/status.sh"}}' > "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json"
AGY_CONFLICT_OUTPUT="$(HOME="${REGISTRY_HOME}" bash -c 'source "$1"; register_hook_antigravity_statusline "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" 2>&1 || true)"
assert_equal "REG-AGY-02: existing status line remains unchanged" "/existing/status.sh" "$(jq -r '.statusLine.command' "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json")"
if printf '%s' "${AGY_CONFLICT_OUTPUT}" | grep -q "existing statusLine.command"; then
  echo "  ✓ PASS: REG-AGY-02: conflict is reported"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: REG-AGY-02: expected explicit conflict report"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

printf '%s\n' '{"theme":"dark"}' > "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json"
HOME="${REGISTRY_HOME}" bash -c 'source "$1"; register_hook_antigravity_statusline "$2"; register_hook_antigravity_statusline "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal "REG-AGY-02: owned status line registered" "bash \"${FAKE_HOOK}\" antigravity-statusline \"Antigravity CLI\"" "$(jq -r '.statusLine.command' "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json")"
HOME="${REGISTRY_HOME}" bash -c 'source "$1"; unregister_hook_antigravity_statusline "$2"' _ "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal "REG-AGY-02: owned status line removed" "false" "$(jq 'has("statusLine")' "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json")"
assert_equal "REG-AGY-02: unrelated settings preserved" "dark" "$(jq -r '.theme' "${REGISTRY_HOME}/.gemini/antigravity-cli/settings.json")"

# [REG-COPILOT-01] Both canonical events are registered and removed once.
COPILOT_REPO="${TEST_TMP_ROOT}/copilot-repo"
mkdir -p "${COPILOT_REPO}/.github/hooks"
git -C "${COPILOT_REPO}" init -q
printf '%s\n' '{"version":1,"hooks":{"otherEvent":[{"type":"command","bash":"other-command"}]}}' > "${COPILOT_REPO}/.github/hooks/hooks.json"
bash -c 'cd "$1"; source "$2"; register_hook_copilot "$3"; register_hook_copilot "$3"' _ "${COPILOT_REPO}" "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true

COPILOT_SESSION_COUNT="$(jq --arg prefix "bash \"${FAKE_HOOK}\" sessionEnd" '[.hooks.sessionEnd[]? | select(.type == "command" and (.bash | startswith($prefix)))] | length' "${COPILOT_REPO}/.github/hooks/hooks.json")"
COPILOT_PROMPT_COUNT="$(jq --arg prefix "bash \"${FAKE_HOOK}\" userPromptSubmitted" '[.hooks.userPromptSubmitted[]? | select(.type == "command" and (.bash | startswith($prefix)))] | length' "${COPILOT_REPO}/.github/hooks/hooks.json")"
assert_equal "REG-COPILOT-01: sessionEnd registered once" "1" "${COPILOT_SESSION_COUNT}"
assert_equal "REG-COPILOT-01: userPromptSubmitted registered once" "1" "${COPILOT_PROMPT_COUNT}"
assert_equal "REG-COPILOT-01: Copilot handlers get no Codex name field" "0" "$(jq '[.. | objects | select(has("statusMessage"))] | length' "${COPILOT_REPO}/.github/hooks/hooks.json")"

bash -c 'cd "$1"; source "$2"; unregister_hook_copilot "$3"' _ "${COPILOT_REPO}" "${REGISTRY}" "${FAKE_HOOK}" >/dev/null 2>&1 || true
assert_equal "REG-COPILOT-01: owned sessionEnd removed" "0" "$(jq '.hooks.sessionEnd // [] | length' "${COPILOT_REPO}/.github/hooks/hooks.json")"
assert_equal "REG-COPILOT-01: owned userPromptSubmitted removed" "0" "$(jq '.hooks.userPromptSubmitted // [] | length' "${COPILOT_REPO}/.github/hooks/hooks.json")"
assert_equal "REG-COPILOT-01: unrelated event preserved" "other-command" "$(jq -r '.hooks.otherEvent[0].bash' "${COPILOT_REPO}/.github/hooks/hooks.json")"

# ── Setup lifecycle tests ──────────────────────────────────────────────────────

echo ""
echo "── setup lifecycle Tests ──"
echo ""

STATUS_HOME="${TEST_TMP_ROOT}/status-home"
STATUS_HOOK="${STATUS_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
mkdir -p "$(dirname "${STATUS_HOOK}")" "${STATUS_HOME}/.codex" "${STATUS_HOME}/.gemini/antigravity-cli"
touch "${STATUS_HOOK}"
printf '%s\n' 'TELEGRAM_ENABLED=true' 'TELEGRAM_BOT_TOKEN="never-print-this-token"' 'TELEGRAM_CHAT_ID="12345"' > "${STATUS_HOME}/.config/ai-notify/config"

STATUS_OUTPUT="$(HOME="${STATUS_HOME}" bash -c 'source "$1"; register_hook_codex "$2" >/dev/null; register_hook_antigravity "$2" >/dev/null; register_hook_antigravity_statusline "$2" >/dev/null; show_hook_status "$2"' _ "${REGISTRY}" "${STATUS_HOOK}" 2>&1 || true)"
if printf '%s\n' "${STATUS_OUTPUT}" | grep -q "Codex: registered" &&
   printf '%s\n' "${STATUS_OUTPUT}" | grep -q "Antigravity completion: registered" &&
   printf '%s\n' "${STATUS_OUTPUT}" | grep -q "Antigravity approval: registered"; then
  echo "  ✓ PASS: LIFE-STATUS-01: provider coverage is reported"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: LIFE-STATUS-01: provider coverage report missing"
  echo "    actual output: ${STATUS_OUTPUT:-<empty>}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if ! printf '%s\n' "${STATUS_OUTPUT}" | grep -q "never-print-this-token"; then
  echo "  ✓ PASS: LIFE-STATUS-01: status does not expose credentials"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: LIFE-STATUS-01: status exposed credentials"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

mkdir -p "${STATUS_HOME}/.config/ai-notify/state"
touch "${STATUS_HOME}/.config/ai-notify/state/antigravity-owned.pending"
touch "${STATUS_HOME}/.config/ai-notify/state/unrelated.pending"
HOME="${STATUS_HOME}" bash -c 'source "$1"; clear_antigravity_notify_state' _ "${REGISTRY}" >/dev/null 2>&1 || true
assert_equal "LIFE-UNINSTALL-01: owned Antigravity state removed" "false" "$([[ -f "${STATUS_HOME}/.config/ai-notify/state/antigravity-owned.pending" ]] && echo true || echo false)"
assert_equal "LIFE-UNINSTALL-01: unrelated state preserved" "true" "$([[ -f "${STATUS_HOME}/.config/ai-notify/state/unrelated.pending" ]] && echo true || echo false)"

INSTALL_SCRIPT="${SCRIPT_DIR}/install.sh"
UPDATE_SCRIPT="${SCRIPT_DIR}/update.sh"
UNINSTALL_SCRIPT="${SCRIPT_DIR}/uninstall.sh"
assert_file_contains "LIFE-INSTALL-01: installer supports canonical level" "attention_required" "${INSTALL_SCRIPT}"
assert_file_not_contains "LIFE-INSTALL-01: installer has no approval preference" "Enable Antigravity approval notifications" "${INSTALL_SCRIPT}"
assert_file_contains "LIFE-INSTALL-01: installer explains Codex hook trust" "Review and trust Codex hooks with /hooks" "${INSTALL_SCRIPT}"
assert_file_contains "LIFE-UPDATE-01: update supports canonical level" "attention_required" "${UPDATE_SCRIPT}"
assert_file_not_contains "LIFE-UPDATE-01: standalone approval command is removed" "antigravity-approval" "${UPDATE_SCRIPT}"
assert_file_contains "LIFE-UPDATE-01: update supports status" "status)" "${UPDATE_SCRIPT}"
assert_file_contains "LIFE-UNINSTALL-01: uninstall clears owned state" "clear_antigravity_notify_state" "${UNINSTALL_SCRIPT}"

FIX_HOME="${TEST_TMP_ROOT}/fix-hooks-home"
FIX_REPO="${TEST_TMP_ROOT}/fix-hooks-repo"
FIX_HOOK="${FIX_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
mkdir -p "$(dirname "${FIX_HOOK}")" "${FIX_HOME}/.gemini/antigravity-cli" "${FIX_REPO}"
touch "${FIX_HOOK}"
git -C "${FIX_REPO}" init -q
printf '%s\n' '{"statusLine":{"type":"command","command":"/existing/status.sh"}}' > "${FIX_HOME}/.gemini/antigravity-cli/settings.json"
bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${FIX_HOME}" "${UPDATE_SCRIPT}" >/dev/null 2>&1 || true
assert_equal \
  "LIFE-UPDATE-02: fix-hooks preserves a conflicting status line" \
  "/existing/status.sh" \
  "$(jq -r '.statusLine.command' "${FIX_HOME}/.gemini/antigravity-cli/settings.json")"
printf '%s\n' '{}' > "${FIX_HOME}/.gemini/antigravity-cli/settings.json"
bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${FIX_HOME}" "${UPDATE_SCRIPT}" >/dev/null 2>&1 || true
assert_equal \
  "LIFE-UPDATE-02: fix-hooks retries automatic approval observation" \
  "bash \"${FIX_HOOK}\" antigravity-statusline \"Antigravity CLI\"" \
  "$(jq -r '.statusLine.command // empty' "${FIX_HOME}/.gemini/antigravity-cli/settings.json")"

# [LIFE-UPDATE-03] fix-hooks rebuilds owned Codex handlers with default names.
FIXN_HOME="${TEST_TMP_ROOT}/fix-names-home"
FIXN_HOOK="${FIXN_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
FIXN_FILE="${FIXN_HOME}/.codex/hooks.json"
mkdir -p "$(dirname "${FIXN_HOOK}")" "${FIXN_HOME}/.codex"
touch "${FIXN_HOOK}"
printf '%s\n' '[hooks.state]' 'trusted = "keep"' > "${FIXN_HOME}/.codex/config.toml"
jq -n --arg stop "bash \"${FIXN_HOOK}\" codex-stop \"Codex\"" '{keep: 1, hooks: {Stop: [{hooks: [
  {type: "command", command: "other-stop", statusMessage: "第三方"},
  {type: "command", command: $stop, timeout: 5, statusMessage: "我的完成提醒"}
]}]}}' > "${FIXN_FILE}"
bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${FIXN_HOME}" "${UPDATE_SCRIPT}" >/dev/null 2>&1 || true
assert_equal \
  "LIFE-UPDATE-03: fix-hooks restores the four default Codex names" \
  "Telegram 完成通知|Telegram 操作確認與等待檢查|Telegram 同步問題等待檢查|Telegram 非同步問題通知" \
  "$(jq -r --arg p "bash \"${FIXN_HOOK}\" codex-" '[.hooks.Stop, .hooks.PermissionRequest, .hooks.PreToolUse, .hooks.PostToolUse | [.[]?.hooks[]? | select(.command | startswith($p)) | .statusMessage] | join(",")] | join("|")' "${FIXN_FILE}")"
assert_equal "LIFE-UPDATE-03: fix-hooks keeps third-party Codex hooks" "第三方 1" "$(jq -r '"\([.. | objects | select(.command? == "other-stop") | .statusMessage] | join(",")) \(.keep)"' "${FIXN_FILE}")"
assert_equal "LIFE-UPDATE-03: fix-hooks leaves Codex trust state alone" "$(printf '%s\n' '[hooks.state]' 'trusted = "keep"')" "$(cat "${FIXN_HOME}/.codex/config.toml")"

# [LIFE-CONFIG-01] Install and update persist only canonical level values.
FAKE_BIN="${TEST_TMP_ROOT}/fake-bin"
mkdir -p "${FAKE_BIN}"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'echo "{\"ok\":true,\"result\":[{\"message\":{\"chat\":{\"id\":12345}}}]}"' \
  > "${FAKE_BIN}/curl"
chmod +x "${FAKE_BIN}/curl"

INSTALL_HOME="${TEST_TMP_ROOT}/install-home"
mkdir -p "${INSTALL_HOME}/.gemini/antigravity-cli"
INSTALL_OUTPUT="$(printf '%s\n' 'test-token' '' 'attention_required' 'all' 'n' 'n' | HOME="${INSTALL_HOME}" PATH="${FAKE_BIN}:${PATH}" bash "${INSTALL_SCRIPT}" 2>&1 || true)"
if [[ ! -f "${INSTALL_HOME}/.config/ai-notify/config" ]]; then
  echo "  ✗ INSTALL FIXTURE: installer did not create config"
  echo "    actual output: ${INSTALL_OUTPUT:-<empty>}"
fi
assert_equal \
  "LIFE-CONFIG-01: fresh install persists attention_required" \
  "attention_required" \
  "$(HOME="${INSTALL_HOME}" bash -c 'source "$1"; printf "%s" "${NOTIFY_LEVEL:-}"' _ "${INSTALL_HOME}/.config/ai-notify/config")"

UPDATE_HOME="${TEST_TMP_ROOT}/update-home"
mkdir -p "${UPDATE_HOME}/.config/ai-notify"
printf '%s\n' \
  'TELEGRAM_ENABLED=true' \
  'TELEGRAM_BOT_TOKEN="test-token"' \
  'TELEGRAM_CHAT_ID="12345"' \
  'NOTIFY_LEVEL=notify_only' \
  > "${UPDATE_HOME}/.config/ai-notify/config"
UPDATE_OUTPUT="$(printf '%s\n' '' 'attention_required' 'all' | HOME="${UPDATE_HOME}" bash "${UPDATE_SCRIPT}" notify_level 2>&1 || true)"
assert_equal \
  "LIFE-CONFIG-01: legacy level update persists canonical value" \
  "attention_required" \
  "$(HOME="${UPDATE_HOME}" bash -c 'source "$1"; printf "%s" "${NOTIFY_LEVEL:-}"' _ "${UPDATE_HOME}/.config/ai-notify/config")"
assert_equal \
  "LIFE-CONFIG-01: level update preserves unrelated config" \
  "test-token" \
  "$(HOME="${UPDATE_HOME}" bash -c 'source "$1"; printf "%s" "${TELEGRAM_BOT_TOKEN:-}"' _ "${UPDATE_HOME}/.config/ai-notify/config")"

INVALID_HOME="${TEST_TMP_ROOT}/invalid-level-home"
mkdir -p "${INVALID_HOME}/.config/ai-notify"
printf '%s\n' \
  'TELEGRAM_ENABLED=true' \
  'TELEGRAM_BOT_TOKEN="test-token"' \
  'TELEGRAM_CHAT_ID="12345"' \
  'NOTIFY_LEVEL=all' \
  > "${INVALID_HOME}/.config/ai-notify/config"
INVALID_OUTPUT="$(printf '%s\n' 'invalid' 'all' | HOME="${INVALID_HOME}" bash "${UPDATE_SCRIPT}" notify_level 2>&1 || true)"
if printf '%s\n' "${INVALID_OUTPUT}" | grep -q "Invalid"; then
  echo "  ✓ PASS: LIFE-CONFIG-01: invalid canonical input is rejected"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ✗ FAIL: LIFE-CONFIG-01: invalid canonical input was not rejected"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
assert_equal \
  "LIFE-CONFIG-01: rejected input does not change current level" \
  "all" \
  "$(HOME="${INVALID_HOME}" bash -c 'source "$1"; printf "%s" "${NOTIFY_LEVEL:-}"' _ "${INVALID_HOME}/.config/ai-notify/config")"

# [LIFE-TPL-01] Built-in templates deploy with the hook; user templates are never touched.
TPLD_HOME="${TEST_TMP_ROOT}/template-deploy-home"
TPLD_ROOT="${TPLD_HOME}/.config/ai-notify"
TPLD_USER="${TPLD_ROOT}/templates"
mkdir -p "${TPLD_ROOT}/hooks" "${TPLD_USER}"
touch "${TPLD_ROOT}/hooks/telegram-notify.sh"
printf '%s\n' 'TELEGRAM_ENABLED=true' 'TELEGRAM_BOT_TOKEN="t"' 'TELEGRAM_CHAT_ID="1"' > "${TPLD_ROOT}/config"
printf '🧪 mine {project}{title_suffix}\n' > "${TPLD_USER}/completion.md"
: > "${TPLD_USER}/stopped.md"
printf 'unreadable {project}\n' > "${TPLD_USER}/question.md"
printf 'extra file\n' > "${TPLD_USER}/notes.txt"
tpl_digest() { (cd "${TPLD_USER}" && ls -lT && cat completion.md stopped.md notes.txt) | shasum; }
TPLD_BEFORE="$(tpl_digest)"
bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${TPLD_HOME}" "${UPDATE_SCRIPT}" >/dev/null 2>&1 || true
bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${TPLD_HOME}" "${UPDATE_SCRIPT}" >/dev/null 2>&1 || true
assert_equal "LIFE-TPL-01: update deploys built-in templates, table, and renderer" \
  "true true true" \
  "$([[ -s "${TPLD_ROOT}/hooks/templates/completion.md" ]] && echo true || echo false) $([[ -s "${TPLD_ROOT}/hooks/events.tsv" ]] && echo true || echo false) $([[ -s "${TPLD_ROOT}/lib/template.sh" ]] && echo true || echo false)"
assert_equal "LIFE-TPL-01: update leaves user templates byte-identical" "${TPLD_BEFORE}" "$(tpl_digest)"
assert_equal "LIFE-TPL-01: update deploys the delayed-authorization library" \
  "true" "$([[ -s "${TPLD_ROOT}/lib/authorization.sh" ]] && echo true || echo false)"
assert_equal "LIFE-TPL-01: rerunning the update leaves exactly the built-in template set" \
  "$(cd "${SCRIPT_DIR}/templates" && ls)" "$(cd "${TPLD_ROOT}/hooks/templates" && ls)"
printf '%s\n' 'NOTIFY_AUTHORIZATION_DELAY_SECONDS=45' >> "${TPLD_ROOT}/config"
TPLD_STATUS="$(bash -c 'cd "$1"; HOME="$2" bash "$3" status' _ "${FIX_REPO}" "${TPLD_HOME}" "${UPDATE_SCRIPT}" 2>&1 || true)"
assert_equal "LIFE-STATUS-02: status shows the authorization delay" \
  "true" "$(grep -q '授權延遲：45 秒' <<<"${TPLD_STATUS}" && echo true || echo false)"
assert_equal "LIFE-STATUS-02: status lists only the user templates in use" \
  "使用者範本：completion, question" "$(grep '使用者範本：' <<<"${TPLD_STATUS}")"
assert_equal "LIFE-STATUS-02: status does not print credentials" \
  "false" "$(grep -q 'TELEGRAM_BOT_TOKEN\|="t"' <<<"${TPLD_STATUS}" && echo true || echo false)"
TPLD_HOOK="${TPLD_ROOT}/hooks/telegram-notify.sh"
run_test "LIFE-TPL-02: a user template overrides the built-in one" \
  "🧪 mine codex-project (#a1b2c3d4)" \
  env HOME="${TPLD_HOME}" bash -c "printf '%s' '${CODEX_STOP_PAYLOAD}' | bash '${TPLD_HOOK}' codex-stop Codex"
run_test "LIFE-TPL-03: an empty user template falls back to the built-in one" \
  "Task Stopped" \
  env HOME="${TPLD_HOME}" bash -c "printf '%s' '${AGY_ERROR_PAYLOAD}' | bash '${TPLD_HOOK}' antigravity-stop 'Antigravity CLI'"
TPLD_QMODE="$(stat -f %Lp "${TPLD_USER}/question.md")"
chmod 000 "${TPLD_USER}/question.md"
run_test "LIFE-TPL-03: an unreadable user template falls back to the built-in one" \
  "Waiting for Your Response" \
  env HOME="${TPLD_HOME}" NOTIFY_CODEX_USER_INPUT=true bash -c "printf '%s' '{\"cwd\":\"/tmp/p\"}' | bash '${TPLD_HOOK}' codex-user-input Codex"
chmod "${TPLD_QMODE}" "${TPLD_USER}/question.md"
printf 'y\nn\n' | HOME="${TPLD_HOME}" bash "${UNINSTALL_SCRIPT}" >/dev/null 2>&1 || true
assert_equal "LIFE-TPL-04: uninstall leaves user templates byte-identical" "${TPLD_BEFORE}" "$(tpl_digest)"
assert_equal "LIFE-TPL-04: uninstall removes the built-in templates and table" \
  "false false" \
  "$([[ -e "${TPLD_ROOT}/hooks/templates" ]] && echo true || echo false) $([[ -e "${TPLD_ROOT}/hooks/events.tsv" ]] && echo true || echo false)"

# [LIFE-DETECT-01] Antigravity's ~/.gemini directory is not Gemini CLI evidence.
DETECT_HOME="${TEST_TMP_ROOT}/detect-home"
DETECT_HOOK="${DETECT_HOME}/.config/ai-notify/hooks/telegram-notify.sh"
mkdir -p "$(dirname "${DETECT_HOOK}")" "${DETECT_HOME}/.gemini/antigravity-cli"
touch "${DETECT_HOOK}"
HOME="${DETECT_HOME}" bash -c '
  command() {
    if [[ "$1" == "-v" && "$2" == "gemini" ]]; then
      return 1
    fi
    builtin command "$@"
  }
  source "$1"
  register_hook "$2"
' _ "${REGISTRY}" "${DETECT_HOOK}" >/dev/null 2>&1 || true
assert_equal "LIFE-DETECT-01: Antigravity completion is registered" "true" "$([[ -f "${DETECT_HOME}/.gemini/config/hooks.json" ]] && echo true || echo false)"
assert_equal "LIFE-DETECT-01: Antigravity-only HOME does not create Gemini settings" "false" "$([[ -f "${DETECT_HOME}/.gemini/settings.json" ]] && echo true || echo false)"

# ── Handoff events (add-handoff-notifications) ─────────────────────────────────

echo ""
echo "── Handoff event Tests ──"
echo ""

# handoff_payload <kind> [verdict] [agent] [detail] → one handoff event as the handoff hook sends it
handoff_payload() {
  jq -nc --arg k "$1" --arg v "${2:-}" --arg a "${3-Claude / claude-opus-5-5 / high}" --arg d "${4:-}" \
    '{kind:$k, change:"add-export", round:"2", verdict:$v, commit:"3f2a91c", next:"已請審查者審查第 2 輪",
      detail:$d, agent:$a, session_id:"6ec9b3e2-cf84-4574-923c-b58a23964d1b", cwd:"/tmp/handoff-project"}'
}
handoff_out() {  # <payload> [VAR=value...] → dry-run output of the source hook
  local payload="$1"; shift
  printf '%s' "${payload}" | env -i PATH="${PATH}" HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" bash "${HOOK}" handoff 2>/dev/null
}
has() { grep -qF -- "$2" <<<"$1" && echo true || echo false; }

assert_equal "HO-CAP-01: the hook declares the handoff-events capability" \
  "true" "$(grep -qx '# ai-notify-capability: handoff-events' "${HOOK}" && echo true || echo false)"

HO_OUT="$(handoff_out "$(handoff_payload implement)")"
assert_equal "HO-TPL-01: implementation title carries the agent and the session label" \
  "true" "$(has "${HO_OUT}" '實作完成** · Agent Handoff (Claude / claude-opus-5-5 / high) (#6ec9b3e2)')"
assert_equal "HO-TPL-01: implementation shows change, round, short commit and the next step" \
  "true true true true" \
  "$(has "${HO_OUT}" 'add-export') $(has "${HO_OUT}" '第 2 輪') $(has "${HO_OUT}" '3f2a91c') $(has "${HO_OUT}" '已請審查者審查第 2 輪')"
assert_equal "HO-TPL-02: changes-required review is titled as a review asking for changes" \
  "true" "$(has "$(handoff_out "$(handoff_payload review changes-required)")" '審查退回')"
assert_equal "HO-TPL-02: passing review is titled as a pass" \
  "true" "$(has "$(handoff_out "$(handoff_payload review pass)")" '審查通過')"
assert_equal "HO-TPL-03: finish event is titled as finish completed" \
  "true" "$(has "$(handoff_out "$(handoff_payload finish)")" '收尾完成')"
HO_OUT="$(handoff_out "$(handoff_payload attention '' 'Claude / claude-opus-5-5 / high' 'reply timed out')")"
assert_equal "HO-TPL-04: attention event is titled as needing the user and shows the detail" \
  "true true" "$(has "${HO_OUT}" '需要你處理') $(has "${HO_OUT}" 'reply timed out')"
assert_equal "HO-TPL-05: an unknown effort is left out of the agent label" \
  "true" "$(has "$(handoff_out "$(handoff_payload implement '' 'Codex / gpt-6.1-sol')")" 'Agent Handoff (Codex / gpt-6.1-sol) (#6ec9b3e2)')"
HO_OUT="$(handoff_out "$(handoff_payload implement '' '')")"
assert_equal "HO-TPL-05: with no agent part known the label is Agent Handoff" \
  "true false" "$(has "${HO_OUT}" '· Agent Handoff (#6ec9b3e2)') $(has "${HO_OUT}" 'Agent Handoff ()')"
assert_equal "HO-TPL-06: formatting characters in agent values are escaped" \
  "true" "$(has "$(handoff_out "$(handoff_payload implement '' 'Codex / gpt_6*x / x_high')")" 'Codex / gpt\_6\*x / x\_high')"
for HO_KIND in implement review finish attention; do
  HO_OUT="$(handoff_out "$(handoff_payload "${HO_KIND}" pass)")"
  assert_equal "HO-TPL-07: ${HO_KIND} does not use the waiting-for-response or generic template" \
    "false false" "$(has "${HO_OUT}" 'Waiting for Your Response') $(has "${HO_OUT}" 'AI CLI Event')"
done

# Switches: a missing key is on; each switch covers only its own kind.
assert_equal "HO-SW-01: with no handoff keys every progress kind is sent" \
  "true true true" \
  "$(has "$(handoff_out "$(handoff_payload implement)")" '實作完成') $(has "$(handoff_out "$(handoff_payload review pass)")" '審查通過') $(has "$(handoff_out "$(handoff_payload finish)")" '收尾完成')"
assert_equal "HO-SW-02: NOTIFY_HANDOFF_FINISH=false silences finish only" \
  "| true true" \
  "|$(handoff_out "$(handoff_payload finish)" NOTIFY_HANDOFF_FINISH=false) $(has "$(handoff_out "$(handoff_payload implement)" NOTIFY_HANDOFF_FINISH=false)" '實作完成') $(has "$(handoff_out "$(handoff_payload review pass)" NOTIFY_HANDOFF_FINISH=false)" '審查通過')"
assert_equal "HO-SW-03: NOTIFY_HANDOFF_IMPLEMENT=false silences implementation only" \
  "| true true" \
  "|$(handoff_out "$(handoff_payload implement)" NOTIFY_HANDOFF_IMPLEMENT=false) $(has "$(handoff_out "$(handoff_payload review changes-required)" NOTIFY_HANDOFF_IMPLEMENT=false)" '審查退回') $(has "$(handoff_out "$(handoff_payload finish)" NOTIFY_HANDOFF_IMPLEMENT=false)" '收尾完成')"
assert_equal "HO-SW-04: NOTIFY_HANDOFF_REVIEW=false silences reviews only" \
  "| true" \
  "|$(handoff_out "$(handoff_payload review pass)" NOTIFY_HANDOFF_REVIEW=false) $(has "$(handoff_out "$(handoff_payload implement)" NOTIFY_HANDOFF_REVIEW=false)" '實作完成')"
HO_SW_HOME="${TEST_TMP_ROOT}/handoff-switch-home"
mkdir -p "${HO_SW_HOME}/.config/ai-notify"
printf '%s\n' 'NOTIFY_HANDOFF_REVIEW=false' > "${HO_SW_HOME}/.config/ai-notify/config"
assert_equal "HO-SW-05: a switch in the config file is honored" \
  "" "$(printf '%s' "$(handoff_payload review pass)" | env -i PATH="${PATH}" HOME="${HO_SW_HOME}" TELEGRAM_DRY_RUN=true bash "${HOOK}" handoff 2>/dev/null)"
assert_equal "HO-SW-06: attention is sent with every switch and category off" \
  "true" \
  "$(has "$(handoff_out "$(handoff_payload attention)" NOTIFY_HANDOFF_IMPLEMENT=false NOTIFY_HANDOFF_REVIEW=false NOTIFY_HANDOFF_FINISH=false \
      NOTIFY_COMPLETION=false NOTIFY_AUTHORIZATION=false NOTIFY_USER_INPUT=false NOTIFY_FAILURE=false NOTIFY_LEVEL=attention_required)" '需要你處理')"

# Telegram delivery: observed through a fake curl, never the network.
HO_TG_HOME="${TEST_TMP_ROOT}/handoff-telegram-home"
HO_TG_BIN="${TEST_TMP_ROOT}/handoff-telegram-bin"
mkdir -p "${HO_TG_HOME}/.config/ai-notify" "${HO_TG_BIN}"
printf '#!/usr/bin/env bash\ntouch "%s/curl-called"\n' "${HO_TG_HOME}" > "${HO_TG_BIN}/curl"
chmod +x "${HO_TG_BIN}/curl"
ho_telegram() {  # <enabled> → whether curl was called for an attention event
  rm -f "${HO_TG_HOME}/curl-called"
  printf '%s\n' "TELEGRAM_ENABLED=$1" 'TELEGRAM_BOT_TOKEN="t"' 'TELEGRAM_CHAT_ID="1"' > "${HO_TG_HOME}/.config/ai-notify/config"
  printf '%s' "$(handoff_payload attention)" | env -i PATH="${HO_TG_BIN}:${PATH}" HOME="${HO_TG_HOME}" bash "${HOOK}" handoff >/dev/null 2>&1
  [[ -e "${HO_TG_HOME}/curl-called" ]] && echo sent || echo none
}
assert_equal "HO-SW-07: attention is delivered when Telegram is enabled" "sent" "$(ho_telegram true)"
assert_equal "HO-SW-07: attention is not delivered when Telegram is disabled" "none" "$(ho_telegram false)"

# A partial deployment without the attention row or template still sends attention.
HO_PART="${TEST_TMP_ROOT}/handoff-partial"
mkdir -p "${HO_PART}/telegram" "${HO_PART}/lib"
cp "${SCRIPT_DIR}/../lib/"*.sh "${HO_PART}/lib/"
cp "${HOOK}" "${HO_PART}/telegram/hook.sh"
grep -v '^handoff:attention' "${SCRIPT_DIR}/events.tsv" > "${HO_PART}/telegram/events.tsv"
cp -R "${SCRIPT_DIR}/templates" "${HO_PART}/telegram/templates"
rm -f "${HO_PART}/telegram/templates/handoff-attention.md"
HO_OUT="$(printf '%s' "$(handoff_payload attention '' '' 'push rejected')" | env -i PATH="${PATH}" HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true bash "${HO_PART}/telegram/hook.sh" handoff 2>/dev/null)"
assert_equal "HO-FB-01: attention without its row or template uses the built-in text with change, detail and next step" \
  "true true true" "$(has "${HO_OUT}" 'add-export') $(has "${HO_OUT}" 'push rejected') $(has "${HO_OUT}" '已請審查者審查第 2 輪')"

# ── Pi events (add-pi-notify-hook) ─────────────────────────────────────────────

echo ""
echo "── Pi event Tests ──"
echo ""

# pi_payload <hook_event_name> [stop_reason] [model] → an event as the Pi extension sends it,
# plus private fields the extension never sends, to prove they cannot leak.
pi_payload() {
  jq -nc --arg e "$1" --arg r "${2:-}" --arg m "${3:-}" \
    '{hook_event_name:$e, session_id:"c0ffee12-3456-7890-abcd-ef1234567890", cwd:"/tmp/pi-project",
      message:"PRIVATE-PI-MESSAGE", errorMessage:"PRIVATE-PI-ERROR at /secret/path: 500 upstream"}
     + (if $r == "" then {} else {stop_reason:$r} end) + (if $m == "" then {} else {model:$m} end)'
}
pi_out() {  # <event> <payload> [VAR=value...] → dry-run output for tool Pi
  local event="$1" payload="$2"; shift 2
  printf '%s' "${payload}" | env -i PATH="${PATH}" HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" bash "${HOOK}" "${event}" Pi 2>/dev/null
}
PI_DONE="$(pi_payload Stop completed)"
PI_ERROR="$(pi_payload Stop error)"
PI_QUESTION="$(pi_payload UserInputWaiting)"

PI_OUT="$(pi_out pi-stop "${PI_DONE}")"
assert_equal "PI-EVT-01: completed is Task Complete for Pi with the session label" \
  "true true true" \
  "$(has "${PI_OUT}" 'Task Complete') $(has "${PI_OUT}" '(#c0ffee12)') $(has "${PI_OUT}" '🤖 Pi')"
PI_OUT="$(pi_out pi-stop "${PI_ERROR}")"
assert_equal "PI-EVT-02: error is Task Stopped with reason error and no private text" \
  "true true false false false" \
  "$(has "${PI_OUT}" 'Task Stopped') $(has "${PI_OUT}" 'Execution ended: error #Stop') $(has "${PI_OUT}" 'Task Complete') $(has "${PI_OUT}" 'PRIVATE-PI') $(has "${PI_OUT}" '/secret/path')"
assert_equal "PI-EVT-03: aborted sends nothing" "" "$(pi_out pi-stop "$(pi_payload Stop aborted)")"
assert_equal "PI-EVT-03: an unknown stop reason sends nothing" "" "$(pi_out pi-stop "$(pi_payload Stop length)")"
assert_equal "PI-EVT-03: a missing stop reason sends nothing" "" "$(pi_out pi-stop "$(pi_payload Stop)")"
PI_OUT="$(pi_out pi-question "${PI_QUESTION}")"
assert_equal "PI-EVT-04: question is Waiting for Your Response for Pi with the session label" \
  "true true false" \
  "$(has "${PI_OUT}" 'Waiting for Your Response') $(has "${PI_OUT}" '(#c0ffee12)') $(has "${PI_OUT}" 'PRIVATE-PI')"
assert_equal "PI-EVT-05: completion carries no private text" "false" "$(has "$(pi_out pi-stop "${PI_DONE}")" 'PRIVATE-PI')"

# Switches and level act on Pi events like on every other tool.
assert_equal "PI-SW-01: NOTIFY_COMPLETION=false silences completed" "" "$(pi_out pi-stop "${PI_DONE}" NOTIFY_COMPLETION=false)"
assert_equal "PI-SW-02: NOTIFY_FAILURE=false silences error" "" "$(pi_out pi-stop "${PI_ERROR}" NOTIFY_FAILURE=false)"
assert_equal "PI-SW-03: NOTIFY_USER_INPUT=false silences question" "" "$(pi_out pi-question "${PI_QUESTION}" NOTIFY_USER_INPUT=false)"
assert_equal "PI-SW-04: attention_required silences completed" "" "$(pi_out pi-stop "${PI_DONE}" NOTIFY_LEVEL=attention_required)"
assert_equal "PI-SW-04: attention_required keeps error and question" "true true" \
  "$(has "$(pi_out pi-stop "${PI_ERROR}" NOTIFY_LEVEL=attention_required)" 'Task Stopped') $(has "$(pi_out pi-question "${PI_QUESTION}" NOTIFY_LEVEL=attention_required)" 'Waiting for Your Response')"
pi_telegram() {  # <enabled> <event> <payload> → whether curl was called
  rm -f "${HO_TG_HOME}/curl-called"
  printf '%s\n' "TELEGRAM_ENABLED=$1" 'TELEGRAM_BOT_TOKEN="t"' 'TELEGRAM_CHAT_ID="1"' > "${HO_TG_HOME}/.config/ai-notify/config"
  printf '%s' "$3" | env -i PATH="${HO_TG_BIN}:${PATH}" HOME="${HO_TG_HOME}" bash "${HOOK}" "$2" Pi >/dev/null 2>&1
  [[ -e "${HO_TG_HOME}/curl-called" ]] && echo sent || echo none
}
assert_equal "PI-SW-05: TELEGRAM_ENABLED=false sends nothing for any Pi event" "none none none" \
  "$(pi_telegram false pi-stop "${PI_DONE}") $(pi_telegram false pi-stop "${PI_ERROR}") $(pi_telegram false pi-question "${PI_QUESTION}")"
assert_equal "PI-SW-05: an enabled Telegram delivers a Pi completion" "sent" "$(pi_telegram true pi-stop "${PI_DONE}")"

# ── Model on the tool line (design decision 6) ─────────────────────────────────

echo ""
echo "── model label Tests ──"
echo ""

# tool_line <event> <tool> <payload> [VAR=value...] → the message's tool line (line 3)
tool_line() {
  local event="$1" tool="$2" payload="$3"; shift 3
  printf '%s' "${payload}" | env -i PATH="${PATH}" HOME="${TEST_TMP_ROOT}/default-home" TELEGRAM_DRY_RUN=true "$@" \
    bash "${HOOK}" "${event}" "${tool}" 2>/dev/null | sed -n 3p
}
codex_model() { jq -nc --arg m "$1" '{hook_event_name:"Stop", session_id:"s", cwd:"/tmp/p", model:$m}'; }
MODEL_DIR="${TEST_TMP_ROOT}/model-records"
mkdir -p "${MODEL_DIR}"
# claude_record <file> <model...> → a session record whose assistant entries use these models in order
claude_record() {
  local file="${MODEL_DIR}/$1" m; shift
  : > "${file}"
  for m in "$@"; do
    jq -nc --arg m "${m}" '{type:"assistant", message:{role:"assistant", model:$m, content:[{type:"text", text:"hi"}]}}' >> "${file}"
    jq -nc '{type:"user", message:{role:"user", content:"next"}}' >> "${file}"
  done
  printf '%s' "${file}"
}
claude_stop() { jq -nc --arg t "$1" '{hook_event_name:"Stop", session_id:"s", cwd:"/tmp/p", transcript_path:$t}'; }

assert_equal "MODEL-01: Codex payload model is shown as is" \
  "🤖 Codex (gpt-6.1-terra)" "$(tool_line codex-stop Codex "$(codex_model gpt-6.1-terra)")"
assert_equal "MODEL-02: Pi on a GPT model" \
  "🤖 Pi (gpt-6.1-sol)" "$(tool_line pi-stop Pi "$(pi_payload Stop completed gpt-6.1-sol)")"
assert_equal "MODEL-02: Pi on a Claude model" \
  "🤖 Pi (Opus 5.5)" "$(tool_line pi-stop Pi "$(pi_payload Stop completed claude-opus-5-5)")"
assert_equal "MODEL-02: Pi question carries the model too" \
  "🤖 Pi (gpt-6.1-sol)" "$(tool_line pi-question Pi "$(pi_payload UserInputWaiting '' gpt-6.1-sol)")"
assert_equal "MODEL-03: Claude Code model comes from the session record" \
  "🤖 Claude Code (Opus 5.5)" "$(tool_line stop 'Claude Code' "$(claude_stop "$(claude_record plain.jsonl claude-sonnet-4-5 claude-opus-5-5)")")"
assert_equal "MODEL-04: a synthetic newest entry is skipped" \
  "🤖 Claude Code (Fable 5.2)" "$(tool_line stop 'Claude Code' "$(claude_stop "$(claude_record synthetic.jsonl claude-fable-5-2 '<synthetic>')")")"
assert_equal "MODEL-05: payload model wins over the session record" \
  "🤖 Claude Code (Sonnet 4.5)" \
  "$(tool_line stop 'Claude Code' "$(jq -nc --arg t "${MODEL_DIR}/plain.jsonl" '{hook_event_name:"Stop", cwd:"/tmp/p", transcript_path:$t, model:"claude-sonnet-4-5"}')")"
assert_equal "MODEL-06: only Claude Code reads the session record" \
  "🤖 Codex" "$(tool_line codex-stop Codex "$(claude_stop "${MODEL_DIR}/plain.jsonl")")"
assert_equal "MODEL-07: no model shows the tool name alone" \
  "🤖 Claude Code" "$(tool_line stop 'Claude Code' '{"hook_event_name":"Stop","cwd":"/tmp/p"}')"
assert_equal "MODEL-07: an unreadable session record shows the tool name alone" \
  "🤖 Claude Code" "$(tool_line stop 'Claude Code' "$(claude_stop "${MODEL_DIR}/missing.jsonl")")"
assert_equal "MODEL-07: a non-string model is ignored" \
  "🤖 Codex" "$(tool_line codex-stop Codex '{"hook_event_name":"Stop","cwd":"/tmp/p","model":{"id":"x"}}')"
assert_equal "MODEL-08: context-size suffix is removed" \
  "🤖 Claude Code (Opus 5.5)" "$(tool_line stop 'Claude Code' "$(codex_model 'claude-opus-5-5[1m]')")"
assert_equal "MODEL-08: backticks and spaces are dropped" \
  "🤖 Codex (gpt-6x)" "$(tool_line codex-stop Codex "$(codex_model 'gpt-6 `x`')")"
assert_equal "MODEL-08: a model made only of unsafe characters counts as none" \
  "🤖 Codex" "$(tool_line codex-stop Codex "$(codex_model '` `')")"
for MODEL_CASE in "claude-sonnet-4-5-20250929|Sonnet 4.5" "claude-opus-4-20250514|Opus 4" \
                  "claude-3-5-sonnet-20241022|Sonnet 3.5" "opus|Opus" "claude-haiku-4-5|Haiku 4.5" \
                  "gemini-3.1-pro|gemini-3.1-pro" "us.anthropic.claude-opus-5-5|us.anthropic.claude-opus-5-5"; do
  assert_equal "MODEL-09: ${MODEL_CASE%%|*} is shown as ${MODEL_CASE#*|}" \
    "🤖 Codex (${MODEL_CASE#*|})" "$(tool_line codex-stop Codex "$(codex_model "${MODEL_CASE%%|*}")")"
done
assert_equal "MODEL-10: a long model is cut to 64 characters" \
  "🤖 Codex ($(printf 'a%.0s' $(seq 1 64)))" "$(tool_line codex-stop Codex "$(codex_model "$(printf 'a%.0s' $(seq 1 80))")")"

# Every built-in template with a tool line shows the model after the tool name.
for TPL_NAME in completion question stopped action-required authorization authorization-unconfirmed generic; do
  TPL_TEXT="$(cat "${SCRIPT_DIR}/templates/${TPL_NAME}.md")"
  assert_equal "MODEL-TPL-01: ${TPL_NAME} shows the model on the tool line" \
    "🤖 Codex (Opus 5.5)" "$(render_text "${TPL_TEXT}" tool=Codex 'model_suffix= (Opus 5.5)' | sed -n 3p)"
  assert_equal "MODEL-TPL-01: ${TPL_NAME} without a model keeps the plain tool line" \
    "🤖 Codex" "$(render_text "${TPL_TEXT}" tool=Codex | sed -n 3p)"
done
assert_equal "MODEL-TPL-02: handoff templates do not show the tool model" \
  "0" "$(cat "${SCRIPT_DIR}"/templates/handoff-*.md | grep -c 'model_')"
MODEL_USER_HOME="${TEST_TMP_ROOT}/model-user-home"
mkdir -p "${MODEL_USER_HOME}/.config/ai-notify/templates"
printf '%s\n' '🟢 done{title_suffix}' '' '🤖 {tool}{model_family_suffix}' > "${MODEL_USER_HOME}/.config/ai-notify/templates/completion.md"
assert_equal "MODEL-TPL-03: a user template can drop the version" \
  "🤖 Claude Code (Opus)" \
  "$(printf '%s' "$(codex_model claude-opus-5-5)" | env -i PATH="${PATH}" HOME="${MODEL_USER_HOME}" TELEGRAM_DRY_RUN=true bash "${HOOK}" stop 'Claude Code' 2>/dev/null | sed -n 3p)"
assert_equal "MODEL-TPL-03: the family label of a GPT model is the model itself" \
  "🤖 Codex (gpt-6.1-terra)" \
  "$(printf '%s' "$(codex_model gpt-6.1-terra)" | env -i PATH="${PATH}" HOME="${MODEL_USER_HOME}" TELEGRAM_DRY_RUN=true bash "${HOOK}" codex-stop Codex 2>/dev/null | sed -n 3p)"

# ── Pi extension install (registry.sh) ─────────────────────────────────────────

echo ""
echo "── Pi extension registry Tests ──"
echo ""

PI_SOURCE="${SCRIPT_DIR}/../pi/ai-notify.ts"
PI_MARKER="// managed by wk-agent-ops ai-notify"
# pi_registry <home> <commands> [no-pi] — run registry functions; "no-pi" hides the pi command.
pi_registry() {
  local home="$1" commands="$2" hide="${3:-}"
  HOME="${home}" PI_HIDE="${hide}" bash -c '
    command() {
      if [[ -n "${PI_HIDE}" && "$1" == "-v" && "$2" == "pi" ]]; then return 1; fi
      builtin command "$@"
    }
    source "$1"; hook="$2"; eval "$3"' _ "${REGISTRY}" "${home}/.config/ai-notify/hooks/telegram-notify.sh" "${commands}"
}
pi_home() {  # <name> [with-agent-dir] → a fresh HOME with a deployed hook
  local home="${TEST_TMP_ROOT}/pi-reg-$1"
  mkdir -p "${home}/.config/ai-notify/hooks"
  touch "${home}/.config/ai-notify/hooks/telegram-notify.sh"
  [[ -n "${2:-}" ]] && mkdir -p "${home}/.pi/agent"
  printf '%s' "${home}"
}
same_file() { cmp -s "$1" "$2" && echo true || echo false; }

assert_equal "PI-REG-00: the extension source starts with the ownership marker" \
  "${PI_MARKER}" "$(head -n 1 "${PI_SOURCE}" 2>/dev/null)"

PI_HOME_A="$(pi_home installed agent)"
pi_registry "${PI_HOME_A}" 'register_hook "$hook"; register_hook "$hook"' no-pi >/dev/null 2>&1
PI_EXT_A="${PI_HOME_A}/.pi/agent/extensions/ai-notify.ts"
assert_equal "PI-REG-01: Pi agent directory alone triggers one installed copy identical to the source" \
  "true 1" "$(same_file "${PI_SOURCE}" "${PI_EXT_A}") $(ls "${PI_HOME_A}/.pi/agent/extensions" 2>/dev/null | grep -c 'ai-notify')"
PI_STATUS="$(pi_registry "${PI_HOME_A}" 'show_hook_status "$hook"' 2>&1)"
assert_equal "PI-STATUS-01: an installed extension is reported registered" "Pi: registered" "$(grep '^Pi:' <<<"${PI_STATUS}")"

PI_HOME_CMD="$(pi_home command-only)"
if command -v pi >/dev/null 2>&1; then
  pi_registry "${PI_HOME_CMD}" 'register_hook "$hook"' >/dev/null 2>&1
  assert_equal "PI-REG-02: the pi command alone installs into the default directory" \
    "true" "$(same_file "${PI_SOURCE}" "${PI_HOME_CMD}/.pi/agent/extensions/ai-notify.ts")"
fi

PI_HOME_NONE="$(pi_home none)"
pi_registry "${PI_HOME_NONE}" 'register_hook "$hook"' no-pi >/dev/null 2>&1
assert_equal "PI-REG-03: without Pi no Pi directory or file is created" \
  "false" "$([[ -e "${PI_HOME_NONE}/.pi" ]] && echo true || echo false)"
PI_STATUS="$(pi_registry "${PI_HOME_NONE}" 'show_hook_status "$hook"' no-pi 2>&1)"
assert_equal "PI-STATUS-02: status says Pi is not detected" "Pi: not detected" "$(grep '^Pi:' <<<"${PI_STATUS}")"

PI_HOME_CONFLICT="$(pi_home conflict agent)"
mkdir -p "${PI_HOME_CONFLICT}/.pi/agent/extensions"
printf '%s\n' '// my own notifier' > "${PI_HOME_CONFLICT}/.pi/agent/extensions/ai-notify.ts"
PI_CONFLICT_ERR="$(pi_registry "${PI_HOME_CONFLICT}" 'register_hook "$hook"' no-pi 2>&1 >/dev/null)"
assert_equal "PI-REG-04: a same-named file without the marker is left unchanged" \
  "// my own notifier" "$(cat "${PI_HOME_CONFLICT}/.pi/agent/extensions/ai-notify.ts")"
assert_equal "PI-REG-04: the conflict is reported on stderr" \
  "true" "$(grep -q 'Pi' <<<"${PI_CONFLICT_ERR}" && grep -q 'ai-notify.ts' <<<"${PI_CONFLICT_ERR}" && echo true || echo false)"
pi_registry "${PI_HOME_CONFLICT}" 'unregister_hook "$hook"' no-pi >/dev/null 2>&1
assert_equal "PI-REG-04: unregister keeps a file without the marker" \
  "// my own notifier" "$(cat "${PI_HOME_CONFLICT}/.pi/agent/extensions/ai-notify.ts")"

printf '%s\n' 'TELEGRAM_ENABLED=true' 'TELEGRAM_BOT_TOKEN="never-print-pi-token"' 'TELEGRAM_CHAT_ID="98765"' > "${PI_HOME_CONFLICT}/.config/ai-notify/config"
PI_STATUS="$(bash -c 'cd "$1"; HOME="$2" bash "$3" status' _ "${FIX_REPO}" "${PI_HOME_CONFLICT}" "${UPDATE_SCRIPT}" 2>&1 || true)"
assert_equal "PI-STATUS-03: update.sh status reports the conflict without credentials" \
  "true false false" \
  "$(grep -q '^Pi: unavailable' <<<"${PI_STATUS}" && echo true || echo false) $(grep -q 'never-print-pi-token' <<<"${PI_STATUS}" && echo true || echo false) $(grep -q '98765' <<<"${PI_STATUS}" && echo true || echo false)"

printf '%s\n' 'export default function () {}' > "${PI_HOME_A}/.pi/agent/extensions/other.ts"
pi_registry "${PI_HOME_A}" 'unregister_hook "$hook"' no-pi >/dev/null 2>&1
assert_equal "PI-REG-05: unregister removes the owned file and keeps other extensions" \
  "false true" "$([[ -e "${PI_EXT_A}" ]] && echo true || echo false) $([[ -e "${PI_HOME_A}/.pi/agent/extensions/other.ts" ]] && echo true || echo false)"

PI_HOME_CUSTOM="$(pi_home custom)"
mkdir -p "${PI_HOME_CUSTOM}/custom-agent"
PI_CODING_AGENT_DIR="${PI_HOME_CUSTOM}/custom-agent" pi_registry "${PI_HOME_CUSTOM}" 'register_hook "$hook"' no-pi >/dev/null 2>&1
assert_equal "PI-REG-06: PI_CODING_AGENT_DIR chooses the extension directory" \
  "true false" \
  "$(same_file "${PI_SOURCE}" "${PI_HOME_CUSTOM}/custom-agent/extensions/ai-notify.ts") $([[ -e "${PI_HOME_CUSTOM}/.pi" ]] && echo true || echo false)"

PI_FIX_HOME="$(pi_home fix agent)"
bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${PI_FIX_HOME}" "${UPDATE_SCRIPT}" >/dev/null 2>&1 || true
assert_equal "PI-REG-07: fix-hooks installs the extension" \
  "true" "$(same_file "${PI_SOURCE}" "${PI_FIX_HOME}/.pi/agent/extensions/ai-notify.ts")"
PI_FIX_OUT="$(bash -c 'cd "$1"; HOME="$2" bash "$3" fix-hooks' _ "${FIX_REPO}" "${PI_FIX_HOME}" "${UPDATE_SCRIPT}" 2>&1 || true)"
assert_equal "PI-REG-07: setup tells open Pi sessions to /reload" "true" "$(grep -q '/reload' <<<"${PI_FIX_OUT}" && echo true || echo false)"
assert_equal "PI-REG-07: fix-hooks twice leaves one copy" \
  "1" "$(ls "${PI_FIX_HOME}/.pi/agent/extensions" | grep -c 'ai-notify')"

# [PI-REG-08] An owned regular file with stale content is refreshed (review pi-notify-review01-r01/F-02).
PI_HOME_STALE="$(pi_home stale agent)"
mkdir -p "${PI_HOME_STALE}/.pi/agent/extensions"
printf '%s\n' "${PI_MARKER}" '// old version' > "${PI_HOME_STALE}/.pi/agent/extensions/ai-notify.ts"
pi_registry "${PI_HOME_STALE}" 'register_hook "$hook"' no-pi >/dev/null 2>&1
assert_equal "PI-REG-08: an owned file is updated to the source" \
  "true" "$(same_file "${PI_SOURCE}" "${PI_HOME_STALE}/.pi/agent/extensions/ai-notify.ts")"

# [PI-REG-09] A symbolic link, broken or not, is never managed (review pi-notify-review01-r01/F-02).
PI_HOME_LINK="$(pi_home broken-link agent)"
mkdir -p "${PI_HOME_LINK}/.pi/agent/extensions"
ln -s "${PI_HOME_LINK}/outside/target.ts" "${PI_HOME_LINK}/.pi/agent/extensions/ai-notify.ts"
PI_LINK_ERR="$(pi_registry "${PI_HOME_LINK}" 'register_hook "$hook"' no-pi 2>&1 >/dev/null)"
assert_equal "PI-REG-09: a broken link is reported and nothing is written through it" \
  "true ${PI_HOME_LINK}/outside/target.ts false" \
  "$(grep -q 'ai-notify.ts' <<<"${PI_LINK_ERR}" && echo true || echo false) $(readlink "${PI_HOME_LINK}/.pi/agent/extensions/ai-notify.ts") $([[ -e "${PI_HOME_LINK}/outside/target.ts" ]] && echo true || echo false)"
assert_equal "PI-STATUS-04: status reports a broken link as unavailable" \
  "true" "$(grep -q '^Pi: unavailable' <<<"$(pi_registry "${PI_HOME_LINK}" 'show_hook_status "$hook"' no-pi 2>&1)" && echo true || echo false)"

PI_HOME_MLINK="$(pi_home marker-link agent)"
mkdir -p "${PI_HOME_MLINK}/.pi/agent/extensions" "${PI_HOME_MLINK}/mine"
printf '%s\n' "${PI_MARKER}" '// a file the user keeps elsewhere' > "${PI_HOME_MLINK}/mine/notify.ts"
ln -s "${PI_HOME_MLINK}/mine/notify.ts" "${PI_HOME_MLINK}/.pi/agent/extensions/ai-notify.ts"
PI_MLINK_ERR="$(pi_registry "${PI_HOME_MLINK}" 'register_hook "$hook"' no-pi 2>&1 >/dev/null)"
assert_equal "PI-REG-09: a link to a marker file is reported and its target is not overwritten" \
  "true // a file the user keeps elsewhere" \
  "$(grep -q 'ai-notify.ts' <<<"${PI_MLINK_ERR}" && echo true || echo false) $(sed -n 2p "${PI_HOME_MLINK}/mine/notify.ts")"
assert_equal "PI-STATUS-04: status reports a link to a marker file as unavailable" \
  "true" "$(grep -q '^Pi: unavailable' <<<"$(pi_registry "${PI_HOME_MLINK}" 'show_hook_status "$hook"' no-pi 2>&1)" && echo true || echo false)"
pi_registry "${PI_HOME_MLINK}" 'unregister_hook "$hook"' no-pi >/dev/null 2>&1
assert_equal "PI-REG-09: unregister keeps the link and its target" \
  "true true" \
  "$([[ -L "${PI_HOME_MLINK}/.pi/agent/extensions/ai-notify.ts" ]] && echo true || echo false) $([[ -f "${PI_HOME_MLINK}/mine/notify.ts" ]] && echo true || echo false)"

# ── Pi extension behavior (driven under Node with a fake Pi API) ──────────────

echo ""
echo "── Pi extension behavior Tests ──"
echo ""

# The real extension file runs under Node's type stripping with a recorded fake hook in a temporary HOME.
# A Node without type stripping cannot run them: they are reported as not run, never as passing.
PI_EXT_SKIPPED=""
pi_node_imports_ts() {
  command -v node >/dev/null 2>&1 || return 1
  printf 'const value: number = 1;\nexport default value;\n' > "${TEST_TMP_ROOT}/ts-probe.ts"
  printf 'const m = await import(process.argv[2]);\nif (m.default !== 1) process.exit(1);\n' > "${TEST_TMP_ROOT}/ts-probe.mjs"
  node "${TEST_TMP_ROOT}/ts-probe.mjs" "${TEST_TMP_ROOT}/ts-probe.ts" >/dev/null 2>&1
}
if pi_node_imports_ts; then
  PI_DRIVER="${TEST_TMP_ROOT}/pi-driver.mjs"
  cat > "${PI_DRIVER}" <<'JS'
const [ext, mode, scenario] = process.argv.slice(2);
const { default: register } = await import(ext);
const on = {};
register({ on: (name, fn) => { on[name] = fn; } });
const ctx = {
  mode, hasUI: mode === "tui" || mode === "rpc", cwd: "/tmp/pi-project",
  model: { id: "gpt-6.1-sol", provider: "openai-codex" },
  sessionManager: { getSessionId: () => "c0ffee12-3456-7890-abcd-ef1234567890" },
};
const prompt = { reason: "ui_prompt", kind: "select", title: "PRIVATE-PROMPT-TITLE" };
const reply = (stopReason) => ({ messages: [{ role: "user" }, { role: "assistant", stopReason, errorMessage: "PRIVATE-ERROR" }] });
if (scenario === "idle-prompt") { await on.ui_prompt_start(prompt, ctx); process.exit(0); }
await on.agent_start({}, ctx);
if (scenario === "turn") await on.ui_prompt_start(prompt, ctx);
if (scenario === "retry-ok") { await on.agent_end(reply("error"), ctx); await on.agent_start({}, ctx); }
await on.agent_end(reply(scenario === "error" ? "error" : "stop"), ctx);
await on.agent_settled({ aborted: scenario === "abort" }, ctx);
JS
  # pi_drive <mode> <scenario> [subagent] → recorded hook calls, one per line: "<event> <tool> <stdin>".
  # A driver that fails prints DRIVER-FAILED, so no assertion (not even an expected silence) can pass.
  pi_drive() {
    local home="${TEST_TMP_ROOT}/pi-drive-$1-$2-${3:-main}" log rc
    log="${home}/calls"
    mkdir -p "${home}/.config/ai-notify/hooks"
    printf '#!/usr/bin/env bash\nprintf "%%s %%s %%s\\n" "$1" "$2" "$(cat)" >> "%s"\n' "${log}" > "${home}/.config/ai-notify/hooks/telegram-notify.sh"
    env -u PI_SUBAGENT_PARENT_SESSION HOME="${home}" ${3:+PI_SUBAGENT_PARENT_SESSION=parent} \
      node "${PI_DRIVER}" "$(cd "${SCRIPT_DIR}/../pi" && pwd)/ai-notify.ts" "$1" "$2" >/dev/null 2>"${home}/driver.err"
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
      printf 'DRIVER-FAILED exit=%s: %s\n' "${rc}" "$(head -n 1 "${home}/driver.err")"
      return 0
    fi
    sleep 1  # the hook runs detached; give it time to record
    cat "${log}" 2>/dev/null
  }
  PI_CALLS="$(pi_drive tui turn)"
  assert_equal "PI-EXT-01: a TUI turn sends one question and one completion with the model" \
    "2 true true true" \
    "$(grep -c . <<<"${PI_CALLS}") $(grep -q '^pi-question Pi .*"hook_event_name":"UserInputWaiting"' <<<"${PI_CALLS}" && echo true || echo false) $(grep -q '^pi-stop Pi .*"stop_reason":"completed"' <<<"${PI_CALLS}" && echo true || echo false) $(grep -q '"model":"gpt-6.1-sol"' <<<"${PI_CALLS}" && echo true || echo false)"
  assert_equal "PI-EXT-01: the prompt title and error text never reach the hook" \
    "false false" "$(grep -q 'DRIVER-FAILED' <<<"${PI_CALLS}" && echo true || echo false) $(grep -q 'PRIVATE-' <<<"${PI_CALLS}" && echo true || echo false)"
  for PI_MODE in rpc print json; do
    assert_equal "PI-EXT-02: ${PI_MODE} mode sends nothing" "" "$(pi_drive "${PI_MODE}" turn)"
  done
  assert_equal "PI-EXT-02: a subagent TUI sends nothing" "" "$(pi_drive tui turn subagent)"
  assert_equal "PI-EXT-03: an error settles as stop_reason error" \
    "true" "$(grep -q '^pi-stop Pi .*"stop_reason":"error"' <<<"$(pi_drive tui error)" && echo true || echo false)"
  assert_equal "PI-EXT-03: a retry that succeeds settles as completed only" \
    "1 true" "$(PI_CALLS="$(pi_drive tui retry-ok)"; printf '%s %s' "$(grep -c . <<<"${PI_CALLS}")" "$(grep -q '"stop_reason":"completed"' <<<"${PI_CALLS}" && echo true || echo false)")"
  assert_equal "PI-EXT-03: an abort settles as stop_reason aborted" \
    "true" "$(grep -q '"stop_reason":"aborted"' <<<"$(pi_drive tui abort)" && echo true || echo false)"
  assert_equal "PI-EXT-04: a prompt opened while idle sends nothing" "" "$(pi_drive tui idle-prompt)"
else
  PI_EXT_SKIPPED="Pi extension behavior tests (PI-EXT-*) NOT RUN: $(node --version 2>/dev/null || echo 'node not found') cannot import TypeScript; use Node 22.18+ or 23.6+ (type stripping)"
  echo "  - SKIP: ${PI_EXT_SKIPPED}"
fi

# [SEC-ARGV] Telegram credentials never reach curl's command line (other users can read it with ps).
# The fake curl logs its arguments and, only when told to read its config from stdin, that config.
SEC_HOME="${TEST_TMP_ROOT}/sec-argv-home"
SEC_BIN="${TEST_TMP_ROOT}/sec-argv-bin"
mkdir -p "${SEC_HOME}/.config/ai-notify" "${SEC_BIN}"
cat > "${SEC_BIN}/curl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "${SEC_HOME}/curl-args"
for a in "\$@"; do [[ "\$a" == - ]] && cat >> "${SEC_HOME}/curl-stdin"; done
echo '{"ok":true,"result":[{"message":{"chat":{"id":12345}}}]}'
EOF
chmod +x "${SEC_BIN}/curl"
sec_reset() { rm -f "${SEC_HOME}/curl-args" "${SEC_HOME}/curl-stdin"; }
sec_args() {  # → not-called | leaked | clean, for token 123:abcDEF and chat 12345
  [[ -s "${SEC_HOME}/curl-args" ]] || { echo not-called; return; }
  grep -q -e '123:abcDEF' -e '12345' "${SEC_HOME}/curl-args" && echo leaked || echo clean
}
sec_deliver() {  # <token> → the hook's exit code for one Claude Code completion
  sec_reset
  printf '%s\n' 'TELEGRAM_ENABLED=true' "TELEGRAM_BOT_TOKEN='$1'" 'TELEGRAM_CHAT_ID="12345"' 'NOTIFY_LEVEL=all' \
    > "${SEC_HOME}/.config/ai-notify/config"
  printf '%s' '{"hook_event_name":"Stop","session_id":"abc","cwd":"/tmp/sec"}' \
    | env -i PATH="${SEC_BIN}:${PATH}" HOME="${SEC_HOME}" bash "${HOOK}" stop "Claude Code" >/dev/null 2>&1
  echo $?
}
sec_deliver '123:abcDEF' >/dev/null
assert_equal "SEC-ARGV-01: delivery keeps the token and chat ID off curl's arguments" "clean" "$(sec_args)"
assert_equal "SEC-ARGV-01: curl reads the sendMessage URL and chat ID from stdin" \
  'url = "https://api.telegram.org/bot123:abcDEF/sendMessage"|data = "chat_id=12345"' \
  "$(grep -E '^(url|data) = ' "${SEC_HOME}/curl-stdin" 2>/dev/null | paste -sd'|' -)"
assert_equal "SEC-ARGV-01: the rest of the request is unchanged" "yes" \
  "$(grep -qx 'parse_mode=Markdown' "${SEC_HOME}/curl-args" 2>/dev/null && grep -q '^text=.*Task Complete' "${SEC_HOME}/curl-args" && echo yes || echo no)"
assert_equal "SEC-ARGV-02: a token holding a quote is not sent and the hook still succeeds" "0 not-called" \
  "$(sec_deliver '123:ab"c') $(sec_args)"

# [SEC-ARGV-03] The setup wizard's getMe, getUpdates and test message keep the token off the command line.
SEC_INSTALL_HOME="${TEST_TMP_ROOT}/sec-install-home"
mkdir -p "${SEC_INSTALL_HOME}/.gemini/antigravity-cli"
sec_reset
printf '%s\n' '123:abcDEF' '' 'attention_required' 'all' 'n' 'n' \
  | HOME="${SEC_INSTALL_HOME}" PATH="${SEC_BIN}:${PATH}" bash "${INSTALL_SCRIPT}" >/dev/null 2>&1 || true
assert_equal "SEC-ARGV-03: the setup wizard keeps the token and chat ID off curl's arguments" "clean" "$(sec_args)"
assert_equal "SEC-ARGV-03: the setup wizard still saves the token" "123:abcDEF" \
  "$(bash -c 'source "$1" 2>/dev/null; printf "%s" "${TELEGRAM_BOT_TOKEN:-}"' _ "${SEC_INSTALL_HOME}/.config/ai-notify/config")"

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "── Results: ${PASS_COUNT}/${TOTAL} passed ──"
[[ -n "${PI_EXT_SKIPPED}" ]] && echo "── Skipped: ${PI_EXT_SKIPPED} ──"
echo ""

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
exit 0
