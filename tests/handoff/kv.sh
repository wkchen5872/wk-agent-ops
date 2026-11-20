#!/usr/bin/env bash
# Handoff test section "kv". Run: bash tests/test_agent_handoff.sh kv
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- kv parser
  printf 'kv parser\n'
  f="$tmp/sample.yaml"
  cat > "$f" <<'YAML'
# comment line
change: add-export
note: review says: fix the time zone
empty:
implement:
  harness: claude
  prompt: "/openspec-apply-change {change}: then commit"
review:
  harness: codex
  model: gpt-6.1-sol
YAML
  # shellcheck source=/dev/null
  if [[ -f "$KV" ]] && source "$KV" 2>/dev/null; then
    [[ "$(kv_get "$f" change)" == "add-export" ]]; check "reads a top-level value"
    [[ "$(kv_get "$f" note)" == "review says: fix the time zone" ]]; check "keeps colons inside a value"
    [[ "$(kv_get "$f" implement.harness)" == "claude" ]]; check "reads a nested value"
    [[ "$(kv_get "$f" review.harness)" == "codex" ]]; check "keeps sections apart"
    [[ "$(kv_get "$f" implement.prompt)" == "/openspec-apply-change {change}: then commit" ]]; check "strips surrounding double quotes"
    ! kv_get "$f" missing >/dev/null 2>&1; check "missing key fails"
    ! kv_get "$f" implement.model >/dev/null 2>&1; check "missing nested key fails"
    [[ -z "$(kv_get "$f" empty)" ]]; check "empty value reads as empty"
  else
    bad "kv.sh exists and can be sourced"
  fi

finish_section kv
