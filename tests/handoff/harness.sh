#!/usr/bin/env bash
# Handoff test section "harness": the harness layer of lib/handoff.sh, called directly. Run: bash tests/test_agent_handoff.sh harness
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- harness layer
  printf 'harness layer\n'
  # shellcheck source=/dev/null
  source "$LIB"
  # each <description> <expected> <command...>: the command's stdout must equal the expected text.
  each() { local name="$1" want="$2" got; shift 2; got="$("$@" 2>/dev/null)"; [[ "$got" == "$want" ]]; check "$name" || printf '    got: %s\n' "$got"; }

  for h in claude codex pi; do ho_harness_valid "$h"; check "$h is a valid harness"; done
  for h in gemini "" Claude; do ! ho_harness_valid "$h"; check "'$h' is not a valid harness"; done

  for ov in claude:opus:high codex:gpt-6.1-sol:xhigh pi:openai-codex/gpt-6.2-sol:high:subscription; do
    ho_override_valid "$ov"; check "override $ov is accepted"
  done
  for ov in claude:opus codex:a:b:c pi:gpt-6.2-sol:high:api pi:a/b/c:high:api gemini:m:e claude::high; do
    ! ho_override_valid "$ov"; check "override $ov is refused"
  done

  each "claude shows as Claude Code" "Claude Code" ho_harness_tool claude
  each "codex shows as Codex" "Codex" ho_harness_tool codex
  each "pi shows as Pi" "Pi" ho_harness_tool pi

  each "a Claude Code skill call is /skill" "/change-review" ho_harness_skill claude change-review
  each "a Codex skill call is \$skill" "\$change-review" ho_harness_skill codex change-review
  each "a Pi skill call is /skill:skill" "/skill:change-review" ho_harness_skill pi change-review

  each "xirp gets claude's effort as effort" effort ho_harness_xirp_effort_key claude
  each "xirp gets codex's effort as reasoning_effort" reasoning_effort ho_harness_xirp_effort_key codex
  each "xirp gets pi's effort as thinking" thinking ho_harness_xirp_effort_key pi
  ! ho_harness_xirp_effort_key gemini >/dev/null 2>&1; check "xirp has no effort field for an unknown harness"

  tf="$tmp/roles.yaml"
  cat > "$tf" <<'YAML'
implement:
  harness: claude
  model: opus
  effort: high
review:
  harness: codex
  model: gpt-6.1-sol
  effort: xhigh
finish:
  harness: codex
  model: gpt-5.6-terra
  effort: medium
  profile: work
other:
  harness: pi
  provider: openai-codex
  model: gpt-6.2-sol
  effort: high
bad:
  harness: gemini
  model: m
  effort: e
YAML
  each "claude argv carries model, effort and the whole name" '["claude","--model","opus","--effort","high","--name","claude - impl - add-export"]' \
    ho_harness_argv "$tf" implement "claude - impl - add-export"
  each "codex argv carries model and reasoning effort" '["codex","-m","gpt-6.1-sol","-c","model_reasoning_effort=xhigh"]' \
    ho_harness_argv "$tf" review "codex - review - add-export"
  each "codex argv adds the profile when set" '["codex","-m","gpt-5.6-terra","-c","model_reasoning_effort=medium","-p","work"]' \
    ho_harness_argv "$tf" finish "codex - finish - add-export"
  each "pi argv carries provider, model and thinking" '["pi","--provider","openai-codex","--model","gpt-6.2-sol","--thinking","high"]' \
    ho_harness_argv "$tf" other "pi - other - add-export"
  ! ho_harness_argv "$tf" bad x >/dev/null 2>&1; check "argv for an unknown harness fails"

finish_section harness
