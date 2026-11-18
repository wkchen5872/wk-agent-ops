#!/usr/bin/env bash
# Automated tests for hook.sh using TELEGRAM_DRY_RUN=true.
# No real Telegram connection needed.
# Usage: bash scripts/notify/telegram/test.sh
# Exit 0 if all tests pass; exit 1 if any fail.

set -uo pipefail

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
  "等待你授權" \
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

if [[ "$(printf '%s\n' "${AGY_STATUS_SEQUENCE}" | grep -c "等待你授權\*\*")" -eq 2 ]]; then
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
  "$(printf '%s\n' "${AGY_ATTENTION_SEQUENCE}" | grep -c "等待你授權\*\*")"

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
run_test "CLAUDE-TYPE-04: permission_prompt is an authorization notice" \
  "等待你授權" \
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

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "── Results: ${PASS_COUNT}/${TOTAL} passed ──"
echo ""

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
exit 0
