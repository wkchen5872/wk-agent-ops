#!/usr/bin/env bash
# Handoff test section "pi". Run: bash tests/test_agent_handoff.sh pi
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- Pi roles
  printf 'Pi roles\n'
  source "$KV"
  LIB="$ROOT/scripts/handoff/lib/handoff.sh"
  TRUST="$ROOT/scripts/handoff/handoff-pi-trust"
  AUTH="$SKILL/scripts/handoff-author"
  pi_auth() { printf '{"status":"%s","provider":"%s","authType":"%s","token":"tok-SECRET-1"}\n' "$2" "$1" "$3" > "$FAKE_PI_DIR/auth-$1.json"; }
  pi_state() {
    export FAKE_PI_DIR="$tmp/fakepi-$1"; rm -rf "$FAKE_PI_DIR"; mkdir -p "$FAKE_PI_DIR"
    printf '%s\n' 'openai gpt-6.2-sol yes' 'openai-codex gpt-6.2-sol yes' 'openai-codex gpt-6.1-terra yes' 'openai gpt-api-only yes' \
      'anthropic claude-opus-4-7 yes' 'openai-codex plain-1 no' > "$FAKE_PI_DIR/models"
    pi_auth openai-codex ready oauth; pi_auth openai ready api_key; pi_auth anthropic ready api_key
  }
  # pi_home <name> [trusted-dir...]: HOME with the Pi trigger installed and those directories trusted in Pi
  pi_home() {
    local h="$tmp/home-pi-$1" j='{}' d; shift; rm -rf "$h"; mkdir -p "$h/.pi/agent/extensions"; : > "$h/.pi/agent/extensions/wk-handoff.ts"
    for d in "$@"; do j="$(jq --arg d "$d" '. + {($d): true}' <<<"$j")"; done
    printf '%s\n' "$j" > "$h/.pi/agent/trust.json"; hook_home "$h"; export PI_HOME="$h"
  }
  role_block() {  # <section> <harness> <model> <effort> [key=value...]
    local sec="$1" h="$2" m="$3" e="$4" kv; shift 4
    printf '%s:\n  harness: %s\n  model: %s\n  effort: %s\n  name: "%s - %s - {change}"\n  prompt: "do {change} {author}"\n' "$sec" "$h" "$m" "$e" "$h" "$sec"
    for kv in "$@"; do printf '  %s: %s\n' "${kv%%=*}" "${kv#*=}"; done
  }
  pi_roles() { { printf 'max_rounds: 3\n\n'; printf '%s\n\n' "$2" "$3" "$4"; } > "$1/.agent-handoff/roles.yaml"; }
  PI_IMPL="$(role_block implement pi gpt-6.2-sol high provider=openai-codex billing=subscription)"
  CX_IMPL="$(role_block implement codex gpt-6.1-sol high)"
  CX_REV="$(role_block review codex gpt-6.1-sol high worktree=shared)"
  CX_FIN="$(role_block finish codex gpt-5.6-terra medium worktree=shared)"
  PI_REV_SHARED="$(role_block review pi gpt-6.2-sol high worktree=shared provider=openai-codex billing=subscription)"
  PI_REV_NEW="$(role_block review pi gpt-6.2-sol high worktree=new provider=openai-codex billing=subscription)"
  pi_state base
  n=0
  # pi_project <roles: implement review finish> → sets PD (project), PW (implementer worktree); trusted HOME
  pi_project() { n=$((n + 1)); PD="$tmp/pi-p$n"; PW="$PD-add-export"; new_project "$PD"; use_project "$PD"; fresh_state "pip$n"; pi_roles "$PD" "$1" "$2" "$3"; pi_home "p$n" "$PD"; }
  pstart() { local d="$1"; shift; HOME="$PI_HOME" start_in "$d" "$@"; }

  # 2.1 template checks
  refuse_case() {  # <label> <pattern> <implement> <review> <finish>
    pi_project "$3" "$4" "$5"
    out="$(pstart "$PD" add-export 2>&1)"; rc=$?
    [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -qF -- "$2" <<<"$out"; check "$1" || { printf '       %s\n' "$out"; }
  }
  refuse_case "a Pi template without billing is refused and names billing" "billing" \
    "$(role_block implement pi gpt-6.2-sol high provider=openai-codex)" "$CX_REV" "$CX_FIN"
  refuse_case "an unknown billing value is refused and names subscription and api" "subscription or api" \
    "$(role_block implement pi gpt-6.2-sol high provider=openai-codex billing=free)" "$CX_REV" "$CX_FIN"
  refuse_case "an effort that is not a Pi thinking level is refused" "off, minimal, low, medium, high, xhigh, max" \
    "$(role_block implement pi gpt-6.2-sol ultra provider=openai-codex billing=subscription)" "$CX_REV" "$CX_FIN"
  refuse_case "a Codex template that sets billing is refused" "billing" \
    "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=shared billing=api)" "$CX_FIN"
  refuse_case "a gemini harness is refused and names claude, codex and pi" "claude, codex or pi" \
    "$(role_block implement gemini gemini-3 high)" "$CX_REV" "$CX_FIN"
  refuse_case "a Pi model with a provider/ prefix is refused" "provider/" \
    "$(role_block implement pi openai-codex/gpt-6.2-sol high provider=openai-codex billing=subscription)" "$CX_REV" "$CX_FIN"

  # 2.2 ho_pi_verify
  v() { (source "$LIB"; PATH="$FAKES:$PATH" ho_pi_verify "$@" 2>&1); }
  all=""
  out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]]; check "a model listed under two providers is accepted for the declared one" || printf '       %s\n' "($out)"
  out="$(v implement openai-codex gpt-api-only high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'not listed' <<<"$out" && grep -q openai-codex <<<"$out"; check "a model listed only under another provider is refused" || printf '       %s\n' "($out)"
  out="$(v implement anthropic opus high api)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'not listed' <<<"$out"; check "an alias is not a model ID" || printf '       %s\n' "($out)"
  out="$(v implement openai-codex plain-1 high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'thinking' <<<"$out"; check "a model without thinking is refused unless effort is off" || printf '       %s\n' "($out)"
  out="$(v implement openai-codex plain-1 off subscription)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]]; check "effort off accepts a model without thinking" || printf '       %s\n' "($out)"
  out="$(v review openai-codex gpt-6.2-sol high api)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q review <<<"$out" && grep -q "'api'" <<<"$out" && grep -q subscription <<<"$out"; check "oauth with billing api is refused naming the role, the declared and the actual billing" || printf '       %s\n' "($out)"
  out="$(v review openai gpt-6.2-sol high api)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]]; check "api_key with billing api is accepted" || printf '       %s\n' "($out)"
  out="$(v review openai gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q "'subscription'" <<<"$out"; check "api_key with billing subscription is refused" || printf '       %s\n' "($out)"
  for st in not_ready invalid; do
    pi_auth openai-codex "$st" oauth; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
    [[ "$rc" != 0 ]] && grep -q "$st" <<<"$out"; check "a $st credential is refused" || printf '       %s\n' "($out)"
  done
  pi_auth openai-codex ready aws-sso; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'aws-sso' <<<"$out"; check "an unknown credential type is a mismatch" || printf '       %s\n' "($out)"
  pi_auth openai-codex ready oauth
  nopi="$tmp/nopi-bin"; mkdir -p "$nopi"; ln -sf "$(command -v jq)" "$nopi/jq"
  out="$( (source "$LIB"; PATH="$nopi:/usr/bin:/bin" ho_pi_verify implement openai-codex gpt-6.2-sol high subscription 2>&1) )"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'pi' <<<"$out"; check "without the pi command every Pi role is refused" || printf '       %s\n' "($out)"
  pi_auth anthropic ready oauth
  out="$(v implement anthropic claude-opus-4-7 high subscription warn)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]] && grep -q 'extra usage' <<<"$out"; check "a matching Anthropic subscription is accepted with the extra usage warning" || printf '       %s\n' "($out)"
  pi_auth anthropic ready api_key
  out="$(v implement anthropic claude-opus-4-7 high api warn)$(v implement openai-codex gpt-6.2-sol high subscription warn)"; all+="$out"
  ! grep -q 'extra usage' <<<"$out"; check "Anthropic API keys and other subscriptions get no warning" || printf '       %s\n' "($out)"
  out="$(v implement anthropic claude-opus-4-7 high subscription warn)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && ! grep -q 'extra usage' <<<"$out"; check "a mismatched Anthropic subscription is refused without the warning" || printf '       %s\n' "($out)"
  printf '9\n' > "$FAKE_PI_DIR/auth-rc"; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"; rm -f "$FAKE_PI_DIR/auth-rc"
  [[ "$rc" != 0 ]] && grep -q 'credential check' <<<"$out"; check "a failing credential check is refused even when it prints ready (codex-pi-handoff-r03/F-04)" || printf '       %s\n' "($out)"
  printf '{"status":' > "$FAKE_PI_DIR/auth-tail"; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"; rm -f "$FAKE_PI_DIR/auth-tail"
  [[ "$rc" != 0 ]] && grep -q 'unreadable' <<<"$out"; check "a credential answer that is not one complete JSON object is refused (codex-pi-handoff-r04/F-02)" || printf '       %s\n' "($out)"
  ! grep -q 'SECRET' <<<"$all"; check "verification output never contains credential values"

  # 2.3 handoff-pi-trust
  T="$tmp/pi-trust"; new_repo "$T"
  tw() { git -C "$T" worktree add -q --detach "$1"; mkdir -p "$1/.agent-handoff/add-export"; printf 'change: add-export\nimplementer:\n  worktree: %s\n' "${2:-$1}" > "$1/.agent-handoff/add-export/loop.yaml"; }
  trc() { (HOME="$1" bash "$TRUST" "$2" >/dev/null 2>&1); echo $?; }
  tw "$T-ok"; mkdir -p "$T-ok/sub"
  mkdir -p "$T/.agent-handoff/add-export"; printf 'change: add-export\nimplementer:\n  worktree: %s\n' "$T" > "$T/.agent-handoff/add-export/loop.yaml"
  git -C "$T" worktree add -q --detach "$T-none"
  tw "$T-tracked"; git -C "$T-tracked" add -f .agent-handoff; git -C "$T-tracked" commit -qm tracked
  tw "$T-other" "$T-ok"
  pi_home trusted "$T"; th="$PI_HOME"; tbefore="$(cat "$th/.pi/agent/trust.json")"
  [[ "$(trc "$th" "$T-ok")$(trc "$th" "$T-ok/sub")" == 00 ]]; check "a listed handoff worktree of a trusted repository is trusted, from any subdirectory"
  [[ "$(trc "$th" "$T")" != 0 ]]; check "the main worktree is left to Pi"
  [[ "$(trc "$th" "$T-none")" != 0 ]]; check "a worktree without loop.yaml is left to Pi"
  [[ "$(trc "$th" "$T-tracked")" != 0 ]]; check "a tracked loop.yaml does not grant trust"
  [[ "$(trc "$th" "$T-other")" != 0 ]]; check "a loop.yaml that does not list this worktree does not grant trust"
  pi_home none; [[ "$(trc "$PI_HOME" "$T-ok")" != 0 ]]; check "an untrusted repository's worktree is left to Pi"
  pi_home parent "$(dirname "$T")"; [[ "$(trc "$PI_HOME" "$T-ok")" == 0 ]]; check "a trusted parent of the main worktree counts"
  printf '{"%s": true, "%s": false}\n' "$(dirname "$T")" "$T" > "$PI_HOME/.pi/agent/trust.json"
  [[ "$(trc "$PI_HOME" "$T-ok")" != 0 ]]; check "the nearest saved decision wins"
  [[ "$(cat "$th/.pi/agent/trust.json")" == "$tbefore" ]]; check "the trust check never edits trust.json"

  # 3.1 ho_pi_settings
  S="$tmp/pi-set"; new_repo "$S"; SW="$S-wt"; git -C "$S" worktree add -q --detach "$SW"
  pset() { (source "$LIB"; ho_pi_settings "$@" 2>&1); }
  ex="$(git -C "$S" rev-parse --path-format=absolute --git-path info/exclude)"
  out="$(pset "$SW" openai-codex gpt-6.2-sol high)"; rc=$?
  [[ "$rc" == 0 && "$(jq -r '[.defaultProvider, .defaultModel, .defaultThinkingLevel] | join(" ")' "$SW/.pi/settings.json" 2>/dev/null)" == "openai-codex gpt-6.2-sol high" ]]; check "the settings file names the provider, model and thinking level" || printf '       %s\n' "($out)"
  [[ -z "$(git -C "$SW" status --porcelain)" && -z "$(git -C "$SW" ls-files .pi)" ]]; check "the settings file keeps the worktree clean and untracked"
  pset "$SW" openai-codex gpt-6.2-sol high >/dev/null; rc=$?
  [[ "$rc" == 0 && "$(grep -cxF '/.pi/settings.json' "$ex")" == 1 ]]; check "identical settings are reused and the exclude rule is added once"
  before="$(cat "$SW/.pi/settings.json")"; out="$(pset "$SW" openai gpt-6.2-sol high)"; rc=$?
  [[ "$rc" != 0 && "$(cat "$SW/.pi/settings.json")" == "$before" ]] && grep -q 'settings.json' <<<"$out"; check "different settings are refused and left unchanged" || printf '       %s\n' "($out)"
  S2="$tmp/pi-set-tracked"; new_repo "$S2"; mkdir -p "$S2/.pi"; printf '{"defaultModel":"x"}\n' > "$S2/.pi/settings.json"; git -C "$S2" add .pi; git -C "$S2" commit -qm pi
  out="$(pset "$S2" openai-codex gpt-6.2-sol high)"; rc=$?
  [[ "$rc" != 0 && "$(cat "$S2/.pi/settings.json")" == '{"defaultModel":"x"}' ]] && grep -q 'tracked' <<<"$out"; check "a tracked settings file is refused and left unchanged" || printf '       %s\n' "($out)"

  # 3.2 handoff-start with Pi roles
  pi_project "$CX_IMPL" "$CX_REV" "$(role_block finish pi gpt-6.2-sol high worktree=new provider=openai-codex billing=api)"
  out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && ! git -C "$PD" worktree list | grep -q add-export && grep -q finish <<<"$out"; check "a finish role whose billing does not match stops before any worktree or session" || { printf '       %s\n' "$out"; }
  refuse_case "two Pi roles in the implementer worktree are refused, naming both" "implement and review" "$PI_IMPL" "$PI_REV_SHARED" "$CX_FIN"
  grep -q 'worktree: new' <<<"$out"; check "the refusal tells the user to give the Pi role worktree: new" || printf '       %s\n' "($out)"
  pi_project "$PI_IMPL" "$PI_REV_NEW" "$CX_FIN"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]]; check "a second Pi role with worktree: new starts" || { printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; rm "$PI_HOME/.pi/agent/extensions/wk-handoff.ts"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -q 'install.sh' <<<"$out"; check "a Pi role without the installed trigger is refused" || { printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; printf '{}\n' > "$PI_HOME/.pi/agent/trust.json"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -q '/trust' <<<"$out"; check "a Pi role in an untrusted repository is refused with the /trust step" || { printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  pl="$PW/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(created)" == 1 ]] && jq -e '.agent.agentName=="pi" and .agent.options=={model:"gpt-6.2-sol", provider:"openai-codex", thinking:"high"}' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; check "a Pi implementer is opened through Xirp with model, provider and thinking" || { printf '       %s\n' "$out"; }
  [[ "$(jq -c . "$PW/.pi/settings.json" 2>/dev/null)" == '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}' && -z "$(git -C "$PW" status --porcelain)" ]]; check "the implementer worktree gets the Pi settings and stays clean"
  [[ "$(kv_get "$pl" implement_template.harness)" == pi && "$(kv_get "$pl" implement_template.provider)" == openai-codex && "$(kv_get "$pl" implement_template.model)" == gpt-6.2-sol \
    && "$(kv_get "$pl" implement_template.effort)" == high && "$(kv_get "$pl" implement_template.billing)" == subscription ]]; check "loop.yaml records the implement template's harness, provider, model, effort and billing"
  jq -r .goal "$FAKE_XIRP_DIR/create-1.json" | grep -qF 'handoff-author --tool Pi --model gpt-6.2-sol'; check "a Pi role's prompt asks for the Author block with --tool Pi"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export; mkdir -p "$PD/.pi"; printf '{"defaultModel":"x"}\n' > "$PD/.pi/settings.json"
  git -C "$PD" add .pi; git -C "$PD" commit -qm pi; git -C "$PD" switch -q main
  out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -q 'settings.json' <<<"$out"; check "a branch that tracks .pi/settings.json is refused before a worktree is created" || { printf '       %s\n' "$out"; }
  pi_auth anthropic ready oauth
  pi_project "$(role_block implement pi claude-opus-4-7 high provider=anthropic billing=subscription)" "$CX_REV" "$CX_FIN"
  err="$(pstart "$PD" add-export 2>&1 >/dev/null)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q 'extra usage' <<<"$err"; check "a matching Anthropic subscription starts with the warning on stderr" || printf '       %s\n' "($err)"
  pi_auth anthropic ready api_key

  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; printf '9\n' > "$FAKE_PI_DIR/auth-rc"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?; rm -f "$FAKE_PI_DIR/auth-rc"
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]]; check "handoff-start opens nothing when the credential check fails (codex-pi-handoff-r03/F-04)" || { printf '       %s\n' "$out"; }

  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; printf '{"status":' > "$FAKE_PI_DIR/auth-tail"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?; rm -f "$FAKE_PI_DIR/auth-tail"
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]]; check "handoff-start opens nothing when the credential answer cannot be parsed (codex-pi-handoff-r04/F-02)" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export; pstart "$PD" add-export --worktree here >/dev/null 2>&1
  lb="$(cat "$PD/.agent-handoff/add-export/loop.yaml")"; exr="$(git -C "$PD" rev-parse --path-format=absolute --git-path info/exclude)"; exb="$(cat "$exr" 2>/dev/null)"
  out="$(pstart "$PD" add-export --worktree here --impl pi:openai-codex/gpt-6.2-sol:high:subscription 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 1 && ! -e "$PD/.pi/settings.json" && "$(cat "$PD/.agent-handoff/add-export/loop.yaml")" == "$lb" && "$(cat "$exr" 2>/dev/null)" == "$exb" ]] && grep -q 'loop already exists' <<<"$out"; check "a refused second start writes no Pi settings or exclude rule (codex-pi-handoff-r04/F-01)" || { printf '       %s\n' "$out"; }

  # 3.3 overrides
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --review pi:openai-codex/gpt-6.2-sol:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -qF 'pi:<provider>/<model>:<effort>:<billing>' <<<"$out"; check "a Pi override without billing shows the expected form" || printf '       %s\n' "($out)"
  before="$(cat "$PD/.agent-handoff/roles.yaml")"; out="$(pstart "$PD" add-export --review pi:openai-codex/gpt-6.2-sol:high:subscription 2>&1)"; rc=$?
  pl="$PW/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$pl" review_template.harness)" == pi && "$(kv_get "$pl" review_template.provider)" == openai-codex && "$(kv_get "$pl" review_template.model)" == gpt-6.2-sol \
    && "$(kv_get "$pl" review_template.effort)" == high && "$(kv_get "$pl" review_template.billing)" == subscription && "$(cat "$PD/.agent-handoff/roles.yaml")" == "$before" ]]; check "a Pi override is recorded in loop.yaml and roles.yaml is unchanged" || { printf '       %s\n' "$out"; }
  [[ "$(kv_get "$pl" review_template.name)" == 'pi - review - {change}' && "$(kv_get "$pl" review_template.prompt)" == 'do {change} {author}' ]]; check "a Pi override renames the session and keeps a prompt that starts with no skill call" || printf '       %s\n' "($(kv_get "$pl" review_template.name))"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --impl codex:gpt-x:low 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && jq -e '.agent.agentName=="codex" and (.agent.options|has("provider")|not)' "$FAKE_XIRP_DIR/create-1.json" >/dev/null && [[ ! -e "$PW/.pi/settings.json" ]]; check "a Codex override replaces a Pi template without its provider and billing" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --impl pi:openai-codex/gpt-6.2-sol:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q implement <<<"$out"; check "a Pi override is verified like a template" || printf '       %s\n' "($out)"

  # Environment checks: a Pi role's model is verified.
  pi_project "$CX_IMPL" "$(role_block review pi nope-1 high worktree=new provider=openai-codex billing=subscription)" "$CX_FIN"
  out="$(HOME="$PI_HOME" pf "$PD" "$PD/.agent-handoff/roles.yaml" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep '^fail role review' <<<"$out" | grep -q 'nope-1' && grep '^fail role review' <<<"$out" | grep -q 'openai-codex'; check "a Pi model its provider does not list fails the role check, naming role, provider and model" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$PI_REV_NEW" "$CX_FIN"
  out="$(HOME="$PI_HOME" pf "$PD" "$PD/.agent-handoff/roles.yaml" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok role review: .*openai-codex/gpt-6.2-sol' <<<"$out" && grep -q '^ok harness .*pi 0.80.0' <<<"$out"; check "a ready Pi role passes with its verified model and Pi version" || { printf '       %s\n' "$out"; }
  # 3.4 roles.example.yaml Pi example
  exf="$tmp/pi-example.yaml"
  sed -n '/^# --- Pi role example ---$/,/^# --- end of Pi role example ---$/p' "$SKILL/roles.example.yaml" | grep -E '^# ?(review:|  )' | sed -E 's/^# ?//' > "$exf"
  [[ -s "$exf" ]] && (source "$LIB"; ho_template_check "$exf" review) >/dev/null 2>&1 \
    && v review "$(kv_get "$exf" review.provider)" "$(kv_get "$exf" review.model)" "$(kv_get "$exf" review.effort)" "$(kv_get "$exf" review.billing)" >/dev/null 2>&1 \
    && [[ "$(kv_get "$exf" review.worktree)" == new ]] && grep -q '/skill:' "$exf"; check "the commented Pi example in roles.example.yaml passes the template check and verification" || printf '       %s\n' "($(cat "$exf" 2>/dev/null | head -3))"
  grep -q 'extra usage' "$SKILL/roles.example.yaml" && grep -q '/skill:<name>' "$SKILL/roles.example.yaml" && grep -q 'subscription' "$SKILL/roles.example.yaml"; check "the example explains billing, the Pi skill syntax and the Anthropic warning"

  # 4.1 handoff-write agent section
  PIENV=(PI_CODING_AGENT=true PI_PROVIDER=openai-codex PI_MODEL=gpt-6.2-sol PI_REASONING_LEVEL=high PI_SESSION_ID=pi-sess-1)
  W1="$tmp/pi-write"; new_repo "$W1"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  r="$W1/.agent-handoff/add-export/01-implement.yaml"
  [[ "$(kv_get "$r" agent.harness 2>/dev/null) $(kv_get "$r" agent.provider 2>/dev/null) $(kv_get "$r" agent.model 2>/dev/null) $(kv_get "$r" agent.effort 2>/dev/null) $(kv_get "$r" agent.billing 2>/dev/null) $(kv_get "$r" agent.session 2>/dev/null)" \
    == "pi openai-codex gpt-6.2-sol high subscription pi-sess-1" && "$(kv_get "$r" role)" == implement ]]; check "a record written in Pi carries the session's agent identity" || printf '       %s\n' "($(cat "$r" 2>/dev/null | tr '\n' ' '))"
  rm -f "$FAKE_PI_DIR/auth-openai-codex.json"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  [[ "$(kv_get "$W1/.agent-handoff/add-export/02-implement.yaml" agent.billing 2>/dev/null)" == unknown ]]; check "a failed credential check writes billing unknown and still writes the record"
  pi_auth openai-codex ready oauth
  printf '9\n' > "$FAKE_PI_DIR/auth-rc"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  rm -f "$FAKE_PI_DIR/auth-rc"; w4="$(ls "$W1/.agent-handoff/add-export"/[0-9][0-9]-implement.yaml | tail -1)"
  [[ "$(kv_get "$w4" agent.billing 2>/dev/null)" == unknown ]]; check "a failing credential check writes billing unknown even when it prints ready (codex-pi-handoff-r03/F-04)"
  printf '{"status":' > "$FAKE_PI_DIR/auth-tail"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  rm -f "$FAKE_PI_DIR/auth-tail"; w6="$(ls "$W1/.agent-handoff/add-export"/[0-9][0-9]-implement.yaml | tail -1)"
  [[ "$w6" != "$w4" && "$(kv_get "$w6" agent.billing 2>/dev/null)" == unknown ]]; check "an unparsable credential answer writes billing unknown (codex-pi-handoff-r04/F-02)"
  w4="$w6"
  (cd "$W1" && env -u PI_CODING_AGENT -u PI_PROVIDER -u PI_MODEL -u PI_REASONING_LEVEL -u PI_SESSION_ID PATH="$FAKES:$PATH" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  w5="$(ls "$W1/.agent-handoff/add-export"/[0-9][0-9]-implement.yaml | tail -1)"
  [[ "$w5" != "$w4" ]] && ! grep -q '^agent:' "$w5"; check "a record written outside Pi has no agent section"
  ! (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD --provider openai) >/dev/null 2>&1; check "handoff-write takes no agent arguments"

  # 4.2 handoff-author --tool Pi
  a1="$(env -i PATH="$PATH" PI_SESSION_ID=p-1 CHIRP_SESSION_ID=x-1 CLAUDE_CODE_SESSION_ID=wrong CODEX_SESSION_ID=wrong "$AUTH" --tool Pi --model gpt-6.2-sol 2>/dev/null)"
  [[ "$a1" == $'Co-Authored-By: Pi\nAI-Assisted-By: gpt-6.2-sol\nSESSION-ID: p-1\nXIRP-SESSION-ID: x-1' ]]; check "handoff-author reads the Pi session ID" || printf '       %s\n' "($a1)"
  a2="$(env -i PATH="$PATH" "$AUTH" --tool Pi --model gpt-6.2-sol 2>/dev/null)"
  [[ "$a2" == $'Co-Authored-By: Pi\nAI-Assisted-By: gpt-6.2-sol\nSESSION-ID: null\nXIRP-SESSION-ID: null' ]]; check "handoff-author writes null for missing Pi and Xirp IDs" || printf '       %s\n' "($a2)"

  # 5.1 routing compares Pi records with the template
  pi_impl_template() { local l="$1/.agent-handoff/add-export/loop.yaml" kv; for kv in harness=pi provider=openai-codex model=gpt-6.2-sol effort=high billing=subscription name=pi-impl prompt=x; do lset "$l" "implement_template.${kv%%=*}" "${kv#*=}"; done; }
  pi_review_template() { local l="$1/.agent-handoff/add-export/loop.yaml" kv; for kv in harness=pi provider=openai-codex model=gpt-6.2-sol effort=high billing=subscription; do lset "$l" "review_template.${kv%%=*}" "${kv#*=}"; done; }
  pi_finish_template() { local l="$1/.agent-handoff/add-export/loop.yaml" kv; for kv in harness=pi provider=openai-codex model=gpt-6.2-sol effort=high billing=subscription; do lset "$l" "finish_template.${kv%%=*}" "${kv#*=}"; done; }
  pi_rec() { local d="$1"; shift; (cd "$d" && env PATH="$FAKES:$PATH" "$@" "$WRITE" --change add-export "${REC_ARGS[@]}") >/dev/null 2>&1; }
  REC_ARGS=(--role implement --status done --head HEAD)
  proute() { HOME="$PI_HOME" route_in "$1"; }
  m=0
  # pi_loop: loop with a Pi implement template (codex reviewer), trusted HOME; sets LD
  pi_loop() { m=$((m + 1)); LD="$tmp/pi-l$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pil$m"; pi_state "l$m"; pi_home "l$m" "$LD"; pi_impl_template "$LD"; }
  mismatch_case() {  # <label> <detail text>; record already written in $LD
    proute "$LD"; local first; first="$(ncount)"; proute "$LD"
    [[ "$(kinds)" == attention && "$(created)" == 0 && -z "$(msgs)" && "$first" == "$(ncount)" ]] && routed "$LD" 01-implement.yaml && jt --arg p "$2" '.detail|contains($p)'; check "$1" || printf '       %s\n' "($(kinds); $(jl | tail -1))"
  }
  pi_loop; pi_rec "$LD" "${PIENV[@]}" PI_PROVIDER=openai
  mismatch_case "a record on another provider stops with one notice and is processed" "provider"
  pi_loop; pi_rec "$LD" "${PIENV[@]}" PI_MODEL=gpt-6.1-terra
  mismatch_case "a record on another model stops with one notice naming the model" "gpt-6.1-terra"
  pi_loop; pi_rec "$LD" "${PIENV[@]}" PI_REASONING_LEVEL=medium
  mismatch_case "a record at another effort stops with one notice naming the effort" "effort"
  pi_loop; pi_auth openai-codex ready api_key; pi_rec "$LD" "${PIENV[@]}"
  mismatch_case "a record with another billing stops with one notice naming the billing" "billing"
  pi_loop; hw "$LD" "${REC_ARGS[@]}"
  mismatch_case "a Pi role's record without an agent section stops with one notice" "agent"
  pi_loop; rm -f "$FAKE_PI_DIR/auth-openai-codex.json"; pi_rec "$LD" "${PIENV[@]}"
  mismatch_case "a record with an unknown value stops with one notice showing unknown" "unknown"
  pi_loop; (cd "$LD" && env -u PI_SESSION_ID PATH="$FAKES:$PATH" PI_CODING_AGENT=true PI_PROVIDER=openai-codex PI_MODEL=gpt-6.2-sol PI_REASONING_LEVEL=high \
    "$WRITE" --change add-export "${REC_ARGS[@]}") >/dev/null 2>&1
  mismatch_case "a record without a Pi session ID stops with one notice (codex-pi-handoff-r03/F-03)" "session"
  pi_loop; pi_rec "$LD" "${PIENV[@]}"; proute "$LD"
  [[ "$(created)" == 1 && "$(kinds)" == implement ]] && routed "$LD" 01-implement.yaml; check "a matching Pi record is routed as usual" || printf '       %s\n' "($(kinds))"
  [[ "$(jl | tail -1 | jq -r .agent)" == "Pi / openai-codex/gpt-6.2-sol / high / 訂閱" ]]; check "the notice shows Pi's provider, model, effort and subscription from the record" || printf '       %s\n' "($(jl | tail -1))"

  # 5.3 agent label for API, unknown and manual runs
  pi_loop; lset "$LD/.agent-handoff/add-export/loop.yaml" implement_template.provider openai; lset "$LD/.agent-handoff/add-export/loop.yaml" implement_template.billing api
  pi_rec "$LD" "${PIENV[@]}" PI_PROVIDER=openai; proute "$LD"
  [[ "$(jl | tail -1 | jq -r .agent)" == "Pi / openai/gpt-6.2-sol / high / API" ]]; check "an API record is labelled API" || printf '       %s\n' "($(jl | tail -1))"
  pi_loop; rm -f "$FAKE_PI_DIR/auth-openai-codex.json"; pi_rec "$LD" "${PIENV[@]}"; proute "$LD"
  [[ "$(jl | tail -1 | jq -r .agent)" == "Pi / openai-codex/gpt-6.2-sol / high / unknown" ]]; check "the mismatch notice shows unknown billing" || printf '       %s\n' "($(jl | tail -1))"
  pi_loop; pi_rec "$LD" "${PIENV[@]}"; touch "$FAKE_XIRP_DIR/msg-fail"
  lset "$LD/.agent-handoff/add-export/loop.yaml" reviewer.session sess-r; lset "$LD/.agent-handoff/add-export/loop.yaml" reviewer.worktree "$LD"
  proute "$LD"; rm -f "$FAKE_XIRP_DIR/msg-fail"
  (cd "$LD" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(kinds)" == "attention implement" && "$(jl | tail -1 | jq -r .agent)" == "Pi / openai-codex/gpt-6.2-sol / high / 訂閱" ]]; check "a manual foreground retry still shows the Pi agent from the record" || printf '       %s\n' "($(kinds); $(jl | tail -1))"
  PH="$tmp/pi-home-notify"; HOME="$PH" bash -c 'source "$1"; deploy_notify_files' _ "$ROOT/scripts/notify/lib/runtime.sh" >/dev/null 2>&1
  HOME="$PH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  pi_loop; pi_rec "$LD" "${PIENV[@]}"
  dry="$(cd "$LD" && env -u HANDOFF_NOTIFY HOME="$PH" TELEGRAM_DRY_RUN=true PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 "$PH/.config/wk-workflow/handoff/handoff-route" --foreground </dev/null 2>/dev/null)"
  grep -qF 'Agent Handoff (Pi / openai-codex/gpt-6.2-sol / high / 訂閱)' <<<"$dry"; check "the notifier's dry run titles a Pi handoff with provider and billing" || printf '       %s\n' "($dry)"

  # 5.2 the hook verifies a Pi reviewer before opening it
  pr_loop() { m=$((m + 1)); LD="$tmp/pi-r$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pir$m"; pi_state "r$m"; pi_home "r$m" "$LD"; pi_review_template "$LD"; hw "$LD" "${REC_ARGS[@]}"; }
  pr_loop; pi_auth openai-codex ready api_key; proute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 01-implement.yaml && grep -q 'reviewer:open-failed' "$LD/.agent-handoff/add-export/routing.log" && jt '.detail|test("billing")'; check "a Pi reviewer whose billing no longer matches is not opened, one notice names it, and the record waits" || printf '       %s\n' "($(kinds); $(jl | tail -1))"
  pi_auth openai-codex ready oauth; proute "$LD"
  [[ "$(created)" == 1 && "$(kinds)" == "attention implement" ]] && routed "$LD" 01-implement.yaml \
    && jq -e '.agent.agentName=="pi" and .agent.options.provider=="openai-codex"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(jq -r .defaultProvider "$LD/.pi/settings.json" 2>/dev/null)" == openai-codex && -z "$(git -C "$LD" status --porcelain)" ]]; check "after the fix the hook opens the Pi reviewer with its settings and sends no second attention" || printf '       %s\n' "($(kinds))"
  pr_loop; exf2="$(git -C "$LD" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$exf2")"; printf '/.pi/settings.json\n' >> "$exf2"
  mkdir -p "$LD/.pi"; printf '{"defaultModel":"mine"}\n' > "$LD/.pi/settings.json"; proute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention && "$(cat "$LD/.pi/settings.json")" == '{"defaultModel":"mine"}' ]] && ! routed "$LD" 01-implement.yaml; check "a review worktree with other Pi settings is not opened and the file is kept" || printf '       %s\n' "($(kinds))"
  m=$((m + 1)); LD="$tmp/pi-f$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pif$m"; pi_state "f$m"; pi_home "f$m" "$LD"; pi_finish_template "$LD"; rpt "$LD"
  hw "$LD" "${REC_ARGS[@]}"; hw "$LD" --role review --status done --verdict pass --head HEAD --report r.md; pi_auth openai-codex ready api_key
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q billing <<<"$out"; check "handoff-finish refuses a Pi finish role that fails verification" || printf '       %s\n' "($out)"

  # codex-pi-handoff-r03/F-02: manual finish and its retry use the same Pi record check
  pf_loop() { m=$((m + 1)); LD="$tmp/pi-pf$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pipf$m"; pi_state "pf$m"; pi_home "pf$m" "$LD"; pi_review_template "$LD"; rpt "$LD"; hw "$LD" "${REC_ARGS[@]}"; }
  pi_review_rec() { local d="$1"; shift; (cd "$d" && env PATH="$FAKES:$PATH" "$@" "$WRITE" --change add-export --role review --status done --verdict pass --head HEAD --report r.md) >/dev/null 2>&1; }
  pf_loop; pi_review_rec "$LD" "${PIENV[@]}" PI_MODEL=gpt-6.1-terra
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'gpt-6.1-terra' <<<"$out"; check "handoff-finish refuses a passing Pi review that differs from its template" || printf '       %s\n' "($out)"
  pf_loop; pi_review_rec "$LD" "${PIENV[@]}"
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]]; check "handoff-finish accepts a matching passing Pi review" || printf '       %s\n' "($out)"
  pf_loop; pi_review_rec "$LD" "${PIENV[@]}" PI_MODEL=gpt-6.1-terra; hw "$LD" --role finish --status blocked --head HEAD --note stopped
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && -z "$(msgs)" ]] && grep -q 'passing review' <<<"$out"; check "a finish retry ignores a passing Pi review that differs from its template" || printf '       %s\n' "($out)"

  # 7.2 drill: a new finish worktree's own loop.yaml must list it, or the Pi trigger cannot trust it
  pf_loop; pi_finish_template "$LD"; lset "$LD/.agent-handoff/add-export/loop.yaml" finish_template.worktree new; pi_review_rec "$LD" "${PIENV[@]}"
  HOME="$PI_HOME" finish_in "$LD" add-export >/dev/null 2>&1
  [[ "$(created)" == 1 && "$(kv_get "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] \
    && (HOME="$PI_HOME" bash "$TRUST" "${LD}-finish" >/dev/null 2>&1); check "a new finish worktree's loop.yaml lists it, so the Pi trigger trusts it"
  lset "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree ""; lset "$LD/.agent-handoff/add-export/loop.yaml" finish.session missing-f
  HOME="$PI_HOME" finish_in "$LD" add-export >/dev/null 2>&1
  [[ "$(created)" == 2 && "$(kv_get "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree 2>/dev/null)" == "${LD}-finish" ]]; check "reopening finish in the prepared worktree restores its loop.yaml entry"

  # codex-pi-handoff-r06/F-01: a failed loop.yaml copy into a new worktree opens nothing and is retried
  CPF="$tmp/cp-fail-bin"; mkdir -p "$CPF"
  printf '#!/usr/bin/env bash\nfor last; do :; done\nif [[ -e "$FAKE_XIRP_DIR/cp-fail" && "$last" == *"$CP_FAIL_MATCH"* ]]; then exit 1; fi\nexec /bin/cp "$@"\n' > "$CPF/cp"; chmod +x "$CPF/cp"
  croute() { (cd "$1" && HOME="$PI_HOME" PATH="$CPF:$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID=chirp-1 "$ROUTE" </dev/null); }
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new; lset "$lf" finish.trigger auto
  pi_review_rec "$LD" "${PIENV[@]}"; export CP_FAIL_MATCH="-finish/"; touch "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 02-review.yaml && grep -q 'finish:open-failed' "$LD/.agent-handoff/add-export/routing.log"; check "a failed loop.yaml copy into a new finish worktree opens no session and leaves the review unprocessed" || printf '       %s\n' "($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"; fl="${LD}-finish/.agent-handoff/add-export/loop.yaml"
  [[ "$(created)" == 1 && "$(kv_get "$fl" change 2>/dev/null)" == add-export && "$(kv_get "$fl" implementer.worktree 2>/dev/null)" == "$LD" \
    && "$(kv_get "$fl" finish_template.harness 2>/dev/null)" == pi && "$(kv_get "$fl" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] && routed "$LD" 02-review.yaml \
    && (HOME="$PI_HOME" bash "$TRUST" "${LD}-finish" >/dev/null 2>&1); check "the retry completes the finish worktree's loop.yaml, opens one finish session and the trust check passes" || printf '       %s\n' "($(created))"
  m=$((m + 1)); LD="$tmp/pi-rc$m"; new_loop "$LD" new; use_project "$LD"; fresh_state "pirc$m"; pi_state "rc$m"; pi_home "rc$m" "$LD"; pi_review_template "$LD"; hw "$LD" "${REC_ARGS[@]}"
  export CP_FAIL_MATCH="-review/"; touch "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 01-implement.yaml; check "a failed loop.yaml copy into a new review worktree opens no reviewer and leaves the record unprocessed" || printf '       %s\n' "($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"
  [[ "$(created)" == 1 && "$(kv_get "${LD}-review/.agent-handoff/add-export/loop.yaml" reviewer.worktree 2>/dev/null)" == "${LD}-review" ]] && routed "$LD" 01-implement.yaml; check "the retry copies loop.yaml into the review worktree and opens the reviewer once" || printf '       %s\n' "($(created))"

  # codex-pi-handoff-r07/F-01: a failed write of the role worktree into the original loop.yaml opens nothing
  printf '#!/usr/bin/env bash\nfor last; do :; done\nif [[ -e "$FAKE_XIRP_DIR/mv-fail" && "$last" == "$MV_FAIL_TARGET" ]]; then exit 1; fi\nexec /bin/mv "$@"\n' > "$CPF/mv"; chmod +x "$CPF/mv"
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new; lset "$lf" finish.trigger auto
  pi_review_rec "$LD" "${PIENV[@]}"; export MV_FAIL_TARGET="$lf"; touch "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 02-review.yaml; check "a failed write of finish.worktree into loop.yaml opens no finish session and leaves the review unprocessed" || printf '       %s\n' "($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 1 && "$(kv_get "$lf" finish.worktree)" == "${LD}-finish" && "$(kv_get "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] \
    && routed "$LD" 02-review.yaml && (HOME="$PI_HOME" bash "$TRUST" "${LD}-finish" >/dev/null 2>&1); check "after the write succeeds the prepared finish worktree is reused, trusted and opened once" || printf '       %s\n' "($(created))"
  m=$((m + 1)); LD="$tmp/pi-rw$m"; new_loop "$LD" new; use_project "$LD"; fresh_state "pirw$m"; pi_state "rw$m"; pi_home "rw$m" "$LD"; pi_review_template "$LD"; hw "$LD" "${REC_ARGS[@]}"
  export MV_FAIL_TARGET="$LD/.agent-handoff/add-export/loop.yaml"; touch "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 01-implement.yaml; check "a failed write of reviewer.worktree into loop.yaml opens no reviewer and leaves the record unprocessed" || printf '       %s\n' "($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 1 && "$(kv_get "${LD}-review/.agent-handoff/add-export/loop.yaml" reviewer.worktree 2>/dev/null)" == "${LD}-review" ]] && routed "$LD" 01-implement.yaml \
    && (HOME="$PI_HOME" bash "$TRUST" "${LD}-review" >/dev/null 2>&1); check "after the write succeeds the reviewer opens once in a trusted review worktree" || printf '       %s\n' "($(created))"
  # codex-pi-handoff-r08/F-01: a finish retry never takes over a worktree the loop did not prepare
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new
  pi_review_rec "$LD" "${PIENV[@]}"; git -C "$LD" checkout -q --detach HEAD; git -C "$LD" worktree add -q "${LD}-finish" feature/add-export
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -e "${LD}-finish/.pi/settings.json" && ! -e "${LD}-finish/.agent-handoff" && -z "$(kv_get "$lf" finish.worktree)" ]]; check "a hand-made worktree with the finish worktree's name is left alone and nothing opens" || printf '       %s\n' "($out)"
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new
  pi_review_rec "$LD" "${PIENV[@]}"; export CP_FAIL_MATCH="-finish/" MV_FAIL_TARGET="$lf"; touch "$FAKE_XIRP_DIR/cp-fail" "$FAKE_XIRP_DIR/mv-fail"
  (cd "$LD" && HOME="$PI_HOME" PATH="$CPF:$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 "$FINISH" add-export </dev/null) >/dev/null 2>&1
  rm -f "$FAKE_XIRP_DIR/cp-fail" "$FAKE_XIRP_DIR/mv-fail"; out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'cannot reuse' <<<"$out"; check "a finish worktree with neither the loop's record nor its loop.yaml is not reused" || printf '       %s\n' "($out)"

  # Opening a Pi role checks the trust rule itself, whatever produced the worktree.
  m=$((m + 1)); LD="$tmp/pi-tg$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pitg$m"; pi_state "tg$m"; pi_home "tg$m" "$LD"; pi_review_template "$LD"
  lset "$LD/.agent-handoff/add-export/loop.yaml" reviewer.worktree "$tmp/pi-elsewhere"; git -C "$LD" worktree add -q --detach "$tmp/pi-elsewhere"
  out="$( (cd "$LD" && source "$LIB" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 ho_open_role "$LD/.agent-handoff/add-export" review_template "$tmp/pi-elsewhere" "$(git -C "$LD" rev-parse HEAD)" 1 "" 2>&1) )"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'trust' <<<"$out"; check "a Pi role is not opened in a worktree the Pi trigger would not trust" || printf '       %s\n' "($out)"

  # A Pi reviewer on herdr starts from its worktree settings and runs Pi on the template's provider and model.
  m=$((m + 1)); LD="$tmp/pi-h$m"; new_loop "$LD" new; use_project "$LD"; fresh_state "pih$m"; pi_state "h$m"; pi_home "h$m" "$LD"; pi_review_template "$LD"
  lset "$LD/.agent-handoff/add-export/loop.yaml" review_template.host herdr; hw "$LD" "${REC_ARGS[@]}"; proute "$LD"
  [[ "$(created)" == 0 && "$(jq -r .defaultModel "${LD}-review/.pi/settings.json" 2>/dev/null)" == gpt-6.2-sol ]] && routed "$LD" 01-implement.yaml \
    && herdr_calls | grep 'agent start' | grep -qE -- '--kind pi --pane w2:p1 -- --provider openai-codex --model gpt-6.2-sol --thinking high$'; check "a Pi reviewer on herdr gets its settings file and runs Pi on the template's provider, model and thinking" || { printf '       %s\n' "($(kinds))"; herdr_calls | sed 's/^/       /'; }
  # 5.4 cleanup removes the settings the loop wrote in the main worktree
  pi_state cleanup
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  hout="$(pstart "$PD" add-export --worktree here 2>&1)"
  pclean() { (cd "$1" && HOME="$PI_HOME" PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" add-export --abandon --yes >/dev/null 2>&1); }
  pvout="$(cd "$PD" && HOME="$PI_HOME" PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" add-export --abandon 2>&1)"
  grep -qF "$PD/.pi/settings.json" <<<"$pvout" && [[ -f "$PD/.pi/settings.json" ]]; check "the cleanup preview names the Pi settings it will remove" || { printf '       %s\n' "$pvout"; }
  [[ -f "$PD/.pi/settings.json" ]] && pclean "$PD" && [[ ! -e "$PD/.pi/settings.json" ]]; check "cleanup removes the Pi settings the loop wrote in the main worktree" || printf '       %s\n' "($hout)"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  pstart "$PD" add-export --worktree here >/dev/null 2>&1; printf '{"defaultModel":"mine"}\n' > "$PD/.pi/settings.json"
  pclean "$PD"; [[ "$(cat "$PD/.pi/settings.json" 2>/dev/null)" == '{"defaultModel":"mine"}' ]]; check "cleanup keeps Pi settings it did not write"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  ex4="$(git -C "$PD" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$ex4")"; printf '/.pi/settings.json\n' >> "$ex4"
  mkdir -p "$PD/.pi"; printf '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}\n' > "$PD/.pi/settings.json"; cp "$PD/.pi/settings.json" "$tmp/pi-own-settings"
  pstart "$PD" add-export --worktree here >/dev/null 2>&1; pclean "$PD"
  cmp -s "$PD/.pi/settings.json" "$tmp/pi-own-settings"; check "cleanup keeps identical Pi settings that existed before the loop (codex-pi-handoff-r03/F-01)"
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  ex3="$(git -C "$PD" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$ex3")"; printf '/.pi/settings.json\n' >> "$ex3"
  mkdir -p "$PD/.pi"; printf '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}\n' > "$PD/.pi/settings.json"
  pstart "$PD" add-export --worktree here >/dev/null 2>&1; pclean "$PD"
  [[ -f "$PD/.pi/settings.json" ]]; check "cleanup of a loop without Pi roles leaves .pi alone"

  # 6.2 installer
  IH="$tmp/pi-install-home"; mkdir -p "$IH"
  iout="$(HOME="$IH" bash "$ROOT/scripts/handoff/install.sh" 2>&1)"; HOME="$IH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$(ls "$IH/.pi/agent/extensions" 2>/dev/null)" == wk-handoff.ts ]] && cmp -s "$ROOT/scripts/handoff/pi/wk-handoff.ts" "$IH/.pi/agent/extensions/wk-handoff.ts" \
    && [[ -x "$IH/.config/wk-workflow/handoff/handoff-pi-trust" ]]; check "the installer puts exactly one Pi trigger in Pi's extensions and installs the trust check"
  grep -q '/reload' <<<"$iout" && grep -q '/trust' <<<"$iout"; check "the installer tells the user about /reload and /trust"
  n_claude="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$IH/.claude/settings.json" 2>/dev/null)"
  n_codex="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$IH/.codex/hooks.json" 2>/dev/null)"
  [[ "$n_claude" == 1 && "$n_codex" == 1 ]]; check "Claude Code and Codex keep one Stop hook each" || printf '       %s\n' "($n_claude/$n_codex)"
  ext="$ROOT/scripts/handoff/pi/wk-handoff.ts"
  grep -q '"agent_settled"' "$ext" && grep -q '"project_trust"' "$ext" && grep -q 'PI_SUBAGENT_PARENT_SESSION' "$ext" && ! grep -q '"tool_call"' "$ext" && ! grep -q 'remember' "$ext"; check "the Pi trigger handles agent_settled and project_trust only, skips subagents and saves no trust"

  # handoff-role: change a role that has not opened, with the checks handoff-start runs.
  ROLE="$ROOT/scripts/handoff/handoff-role"
  prole() { local d="$1"; shift; (cd "$d" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROLE" "$@" </dev/null); }
  sum() { cksum < "$1"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  rbefore="$(cat "$PD/.agent-handoff/roles.yaml")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high:api 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" review_template.harness)" == pi && "$(kv_get "$rl" review_template.provider)" == openai \
    && "$(kv_get "$rl" review_template.model)" == gpt-6.2-sol && "$(kv_get "$rl" review_template.effort)" == high \
    && "$(kv_get "$rl" review_template.billing)" == api && "$(kv_get "$rl" review_template.name)" == 'pi - review - {change}' \
    && "$(cat "$PD/.agent-handoff/roles.yaml")" == "$rbefore" ]]; check "handoff-role changes a review role that has not opened, and roles.yaml is unchanged" || { printf '       %s\n' "$out"; }
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  jq -e '.agent.agentName=="pi" and .customName=="pi - review - add-export"' "$FAKE_XIRP_DIR/create-2.json" >/dev/null 2>&1; check "the hook opens the reviewer from the changed role" || printf '       %s\n' "($(cat "$FAKE_XIRP_DIR/create-2.json" 2>/dev/null | jq -c '{n: .customName, a: .agent.agentName}'))"
  s0="$(sum "$rl")"; out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q "$(kv_get "$rl" reviewer.session)" <<<"$out" && grep -qF -- '--replace' <<<"$out"; check "handoff-role refuses a role whose session is open and names it" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/not-a-model:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q 'not-a-model' <<<"$out"; check "handoff-role refuses a Pi role that fails verification and keeps loop.yaml" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -qF 'pi:<provider>/<model>:<effort>:<billing>' <<<"$out"; check "handoff-role refuses a malformed override and shows the form" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export finish claude:sonnet:high 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" finish_template.harness)" == claude && "$(kv_get "$rl" finish_template.name)" == 'claude - finish - {change}' ]]; check "handoff-role changes a finish role that has not opened" || { printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q 'one Pi role' <<<"$out"; check "handoff-role refuses a second Pi role in the implementer worktree" || { printf '       %s\n' "$out"; }

  # handoff-role --replace and --worktree new (replace-open-handoff-roles)
  # open_reviewer [finish-block]: a Codex loop whose Codex reviewer (sess-2) received round 1.
  open_reviewer() {
    pi_project "$CX_IMPL" "$CX_REV" "${1:-$CX_FIN}"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
    commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  }
  rlog() { cat "$PW/.agent-handoff/add-export/routing.log" 2>/dev/null; }
  open_reviewer; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export implement claude:opus:high --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -q 'only review and finish' <<<"$out"; check "handoff-role refuses to change the implementer" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --worktree shared --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -qF -- 'only --worktree new' <<<"$out"; check "handoff-role refuses --worktree shared" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review pi:openai/not-a-model:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" && "$(created)" == 2 ]] && grep -q 'not-a-model' <<<"$out"; check "a replacement that fails its checks deletes nothing and keeps loop.yaml" || { printf '       %s\n' "$out"; }
  touch "$FAKE_XIRP_DIR/delete-fail"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/delete-fail"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]] && grep -q 'sess-2' <<<"$out"; check "a replacement whose old session cannot be deleted keeps loop.yaml" || { printf '       %s\n' "$out"; }
  # The README's example: the implement record already went to the old reviewer, so the new one gets it.
  rex="$(grep -m1 -E '^ *handoff-role add-export review .*--replace' "$ROOT/scripts/handoff/README.md" | sed 's/^ *//')"
  rbefore="$(cat "$PD/.agent-handoff/roles.yaml")"
  # shellcheck disable=SC2086
  out="$(prole "$PW" ${rex#handoff-role } 2>&1)"; rc=$?
  [[ -n "$rex" && "$rc" == 0 && "$(deleted)" == sess-2 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 \
    && "$(kv_get "$rl" review_template.harness)" == pi && "$(kv_get "$rl" review_template.worktree)" == new \
    && "$(kv_get "$rl" reviewer.worktree)" == "$PW-review" && -d "$PW-review" && "$(cat "$PD/.agent-handoff/roles.yaml")" == "$rbefore" ]] \
    && grep -n 'session delete sess-2\|api send' "$FAKE_XIRP_DIR/calls" | tail -2 | head -1 | grep -q 'session delete sess-2' \
    && jq -e --arg w "$PW-review" '.agent.agentName=="pi" and .worktreePath==$w and (.goal|test("add-export"))' "$FAKE_XIRP_DIR/create-3.json" >/dev/null 2>&1 \
    && rlog | grep -q 'implement.yaml action=reviewer:opened:sess-3'; check "the README example replaces an open reviewer and hands the waiting round to the new Pi reviewer" || { printf '       %s\n' "($rex)"; printf '       %s\n' "$out"; rlog | sed 's/^/       /'; }
  open_reviewer; n0="$(ncount)"; touch "$FAKE_XIRP_DIR/create-fail"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/create-fail"
  [[ "$rc" != 0 && "$(deleted)" == sess-2 && -z "$(kv_get "$rl" reviewer.session)" && "$(( $(ncount) - n0 ))" == 1 ]] \
    && ! routed "$PW" 01-implement.yaml && jt '.kind=="attention"' && grep -q 'handoff-route --foreground' <<<"$out"; check "a hand-off that fails after a replacement leaves the record unprocessed with one attention notice" || { printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict changes-required --head HEAD --report r.md
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == sess-2 && "$(created)" == 2 && -z "$(kv_get "$rl" reviewer.session)" \
    && "$(kv_get "$rl" review_template.harness)" == pi && "$(kv_get "$rl" review_template.model)" == gpt-6.2-sol ]]; check "a reviewer replaced while the implementer works is deleted and nothing opens" || { printf '       %s\n' "$out"; }
  # --worktree new lets a Pi reviewer sit next to a shared Pi finish role; alone it changes only the worktree.
  PI_FIN_SHARED="$(role_block finish pi gpt-6.2-sol high worktree=shared provider=openai-codex billing=subscription)"
  pi_project "$CX_IMPL" "$CX_REV" "$PI_FIN_SHARED"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q 'one Pi role' <<<"$out"; check "a Pi reviewer next to a shared Pi finish role is refused without --worktree new" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review --worktree new pi:openai/gpt-6.2-sol:medium:api 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" review_template.harness)" == pi && "$(kv_get "$rl" review_template.worktree)" == new ]]; check "with --worktree new the Pi reviewer passes the one-Pi-role check" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export finish --worktree new 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" finish_template.worktree)" == new && "$(kv_get "$rl" finish_template.harness)" == pi \
    && "$(kv_get "$rl" finish_template.model)" == gpt-6.2-sol && "$(kv_get "$rl" finish_template.provider)" == openai-codex ]]; check "--worktree new alone changes only the role's worktree" || { printf '       %s\n' "$out"; }

  # Round 2 (codex-role-review-r01)
  ROUTE_FG() { (cd "$1" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 CLAUDE_PROJECT_DIR="$1" "$ROUTE" --foreground </dev/null >/dev/null 2>&1); }
  open_reviewer; s0="$(sum "$rl")"; touch "$FAKE_XIRP_DIR/get-fail" "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-fail"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/get-fail" "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-fail"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]] && grep -q 'sess-2' <<<"$out"; check "a replacement whose old session Xirp neither deletes nor confirms gone keeps loop.yaml (codex-role-review-r01/F-01)" || { printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict changes-required --head HEAD --report r.md; touch "$FAKE_XIRP_DIR/get-fail"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?; rm -f "$FAKE_XIRP_DIR/get-fail"
  [[ "$rc" == 0 && "$(deleted)" == sess-2 && -z "$(kv_get "$rl" reviewer.session)" ]]; check "a failed Xirp lookup does not skip deleting the old session (codex-role-review-r01/F-01)" || { printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict changes-required --head HEAD --report r.md; lset "$rl" reviewer.session missing-9
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && -z "$(kv_get "$rl" reviewer.session)" && -z "$(deleted)" ]]; check "a replacement goes ahead when Xirp no longer lists the old session (codex-role-review-r01/F-01)" || { printf '       %s\n' "$out"; }
  open_reviewer; OTHER="$tmp/pi-elsewhere"; rm -rf "$OTHER"; new_repo "$OTHER"
  out="$(export CLAUDE_PROJECT_DIR="$OTHER"; prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]]; check "the hand-off routes the record's own worktree when CLAUDE_PROJECT_DIR names another (codex-role-review-r01/F-03)" || { printf '       %s\n' "$out"; }
  open_reviewer; commit_in "$PW" impl2; printf 'x\n' > "$PW/dirty.txt"; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1; rm -f "$PW/dirty.txt"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 2 && -z "$(kv_get "$rl" reviewer.session)" ]] && routed "$PW" 02-implement.yaml; check "a record that never reached the old reviewer is not handed to the new one (codex-role-review-r01/F-03)" || { printf '       %s\n' "$out"; }
  open_reviewer; git -C "$PW" worktree add -q --detach "$PW-review" HEAD; printf 'x\n' > "$PW-review/stray.txt"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$PW-review/stray.txt"; r1="$rc"; ROUTE_FG "$PW"
  [[ "$r1" != 0 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] && grep -q 'handoff-route --foreground' <<<"$out"; check "a hand-off stopped by an unclean review worktree is retried after the worktree is cleaned (codex-role-review-r01/F-03)" || { printf '       %s\n' "$out"; }
  open_reviewer; chmod 555 "$PW/.agent-handoff/add-export"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  chmod 755 "$PW/.agent-handoff/add-export"
  [[ "$rc" != 0 && "$(deleted)" == sess-2 && "$(created)" == 2 ]] && grep -qF -- '--replace' <<<"$out"; check "a loop.yaml write that fails after the deletion exits non-zero and names the rerun (codex-role-review-r01/F-04)" || { printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]]; check "rerunning the replacement after a failed write hands the round to the new reviewer (codex-role-review-r01/F-04)" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=new)" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  chmod 555 "$PW-review/.agent-handoff/add-export"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  chmod 755 "$PW-review/.agent-handoff/add-export"
  [[ "$rc" != 0 && "$(created)" == 2 && "$(kv_get "$rl" reviewer.session)" == sess-2 ]] && grep -qF -- '--replace' <<<"$out"; check "a failed write to another loop.yaml copy keeps the old session recorded for a rerun (codex-role-review-r01/F-04)" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$PI_REV_SHARED" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  out="$(prole "$PW" add-export review pi:openai-codex/gpt-6.2-sol:medium:subscription --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] && jq -e '.defaultThinkingLevel=="medium"' "$PW/.pi/settings.json" >/dev/null 2>&1; check "a Pi reviewer replaced in the same worktree rewrites the settings the loop wrote (codex-role-review-r01/F-06)" || { printf '       %s\n' "$out"; }
  open_reviewer; px="$(git -C "$PW" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$px")"; printf '/.pi/settings.json\n' >> "$px"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -q 'settings.json' <<<"$out"; check "Pi settings the loop did not write refuse the replacement before the old session is deleted (codex-role-review-r01/F-06)" || { printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict pass --head HEAD --report r.md; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high:api --replace 2>&1)"; rc=$?
  fout="$(HOME="$PI_HOME" finish_in "$PW" add-export 2>&1)"; frc=$?
  [[ "$rc" == 0 && "$frc" == 0 && "$(created)" == 3 && "$(kv_get "$rl" finish.session)" == sess-3 ]]; check "a Codex pass recorded before the reviewer became Pi still lets the loop finish (codex-role-review-r01/F-07)" || { printf '       %s\n' "$out" "$fout"; }
  hw "$PW" --role finish --status blocked --head HEAD --note quota
  out="$(prole "$PW" add-export review pi:openai/gpt-api-only:high:api 2>&1)"; rc=$?
  fout="$(HOME="$PI_HOME" finish_in "$PW" add-export 2>&1)"; frc=$?
  [[ "$rc" == 0 && "$frc" == 0 ]] && msgs | grep -q '^sess-3'; check "a blocked finish is retried after a further reviewer change (codex-role-review-r01/F-07)" || { printf '       %s\n' "$out" "$fout"; }

  # Round 3 (codex-role-review-r02)
  open_reviewer; s0="$(sum "$rl")"; touch "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-null"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-null"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]]; check "an unreadable Xirp session list does not prove the old session gone (codex-role-review-r02/F-01)" || { printf '       %s\n' "$out"; }
  open_reviewer
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*/.routed' prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  grep -vxF 01-implement.yaml "$PW/.agent-handoff/add-export/.routed" > "$tmp/routed.tmp"; cat "$tmp/routed.tmp" > "$PW/.agent-handoff/add-export/.routed"; ROUTE_FG "$PW"
  [[ "$rc" != 0 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] && grep -qF '.routed' <<<"$out" && grep -q 'handoff-route --foreground' <<<"$out"; check "a hand-off marker that cannot be cleared is reported, and the documented steps complete it (codex-role-review-r02/F-03)" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=new)" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  rvl="$PW-review/.agent-handoff/add-export/loop.yaml"; wrpt "$PW-review"; hw "$PW-review" --role review --status done --verdict changes-required --head HEAD --report r.md; c0="$(sum "$rvl")"
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL="$rvl" prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?; c1="$(sum "$rvl")"
  out2="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc2=$?
  copies_ok=1
  for f in "$rl" "$rvl"; do
    [[ "$(kv_get "$f" review_template_until_03.harness)" == codex && "$(kv_get "$f" review_template_until_03.model)" == gpt-6.1-sol \
      && "$(kv_get "$f" review_template_until_03.effort)" == high && "$(kv_get "$f" review_template.harness)" == pi ]] || copies_ok=0
  done
  [[ "$rc" != 0 && "$c1" == "$c0" && "$rc2" == 0 && "$copies_ok" == 1 ]]; check "a loop.yaml copy whose write fails stays whole, and a rerun completes every copy (codex-role-review-r02/F-04)" || { printf '       %s\n' "$out" "$out2"; }
  # The same, with the copy's first write let through and the second (provider) failing, as the review injected it.
  pi_project "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=new)" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  rvl="$PW-review/.agent-handoff/add-export/loop.yaml"; wrpt "$PW-review"; hw "$PW-review" --role review --status done --verdict changes-required --head HEAD --report r.md; c0="$(sum "$rvl")"
  rm -f "$tmp/mvcount"
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL="$rvl" FAKE_MV_AFTER=1 FAKE_MV_COUNT="$tmp/mvcount" prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?; c1="$(sum "$rvl")"
  out2=""; (( rc == 0 )) || out2="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"
  copies_ok=1
  for f in "$rl" "$rvl"; do
    for k in harness:codex model:gpt-6.1-sol effort:high; do [[ "$(kv_get "$f" "review_template_until_03.${k%%:*}")" == "${k#*:}" ]] || copies_ok=0; done
    kv_get "$f" review_template_until_03.provider >/dev/null 2>&1 && kv_get "$f" review_template_until_03.billing >/dev/null 2>&1 || copies_ok=0
  done
  { (( rc == 0 )) || [[ "$c1" == "$c0" ]]; } && [[ "$copies_ok" == 1 ]]; check "a copy write interrupted after its first change never leaves a partial earlier template (codex-role-review-r02/F-04)" || { printf '       %s\n' "$out" "$out2"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" && ! -d "$PW-review" ]] && grep -q 'tracked' <<<"$out"; check "Pi settings tracked in the commit a new worktree will check out refuse the replacement first (codex-role-review-r02/F-06)" || { printf '       %s\n' "$out"; }

  # Round 4 (codex-role-review-r03)
  open_reviewer; s0="$(sum "$rl")"; touch "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-truncated"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-truncated"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]]; check "a Xirp list followed by unparsable output does not prove the old session gone (codex-role-review-r03/F-01)" || { printf '       %s\n' "$out"; }
  open_reviewer; chmod 444 "$PW/.agent-handoff/add-export/routing.log"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  chmod 644 "$PW/.agent-handoff/add-export/routing.log"; ROUTE_FG "$PW"
  [[ "$rc" != 0 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 && -z "$(msgs | grep '^sess-3')" ]] && routed "$PW" 01-implement.yaml && grep -q 'sess-3' <<<"$out"; check "a hand-off whose result could not be logged is never sent again (codex-role-review-r03/F-03)" || { printf '       %s\n' "$out"; msgs | sed 's/^/       /'; }
  # F-06: the Pi pre-check reads the worktree and commit the route or finish will really use.
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  git -C "$PW" update-index --skip-worktree .pi/settings.json; rm -rf "$PW/.pi"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -q 'tracked' <<<"$out"; check "Pi settings the shared worktree's index tracks, even when not checked out, refuse the replacement first (codex-role-review-r03/F-06)" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$(role_block finish codex gpt-5.6-terra medium worktree=new)"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  wrpt "$PW"; hw "$PW" --role review --status done --verdict pass --head HEAD --report r.md; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  HOME="$PI_HOME" finish_in "$PW" add-export >/dev/null 2>&1; PF="$PW-finish"; f0="$(kv_get "$rl" finish.session)"
  git -C "$PF" rm -q .pi/settings.json; git -C "$PF" commit -qm "drop pi settings"; hw "$PF" --role finish --status blocked --head HEAD --note quota
  out="$(prole "$PW" add-export finish pi:openai/gpt-6.2-sol:high:api --replace 2>&1)"; rc=$?
  [[ -n "$f0" && "$rc" == 0 && "$(deleted)" == "$f0" && -n "$(kv_get "$rl" finish.session)" && "$(kv_get "$rl" finish.session)" != "$f0" ]]; check "a blocked finish in its own worktree is checked at that worktree's commit, not the implementer's (codex-role-review-r03/F-06)" || { printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=new)" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  wrpt "$PW-review"; hw "$PW-review" --role review --status done --verdict changes-required --head HEAD --report r.md
  git -C "$PW" rm -q .pi/settings.json; git -C "$PW" commit -qm "drop pi settings"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == sess-2 && "$(created)" == 2 && "$(kv_get "$rl" review_template.harness)" == pi ]]; check "with no round waiting, an earlier review's commit is not checked as the next checkout (codex-role-review-r03/F-06)" || { printf '       %s\n' "$out"; }

  # Round 5 (pi-role-review-r04/F-03): the new reviewer opened, but its session ID could not be recorded.
  open_reviewer
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*/loop.yaml' FAKE_MV_IF='session: sess-3' prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  ROUTE_FG "$PW"
  [[ "$rc" != 0 && "$(created)" == 3 ]] && routed "$PW" 01-implement.yaml && grep -q 'sess-3' <<<"$out"; check "a reviewer opened whose session ID could not be recorded is named, and no second reviewer opens (pi-role-review-r04/F-03)" || { printf '       %s\n' "$out"; }
  # pi-role-review-r05/F-01: once its ID is recorded by hand, replacing that reviewer hands the round on, once.
  lset "$rl" reviewer.session sess-3
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  ROUTE_FG "$PW"
  [[ "$rc" == 0 && "$(deleted | tail -1)" == sess-3 && "$(created)" == 4 && "$(kv_get "$rl" reviewer.session)" == sess-4 ]]; check "replacing a reviewer that was opened unrecorded hands the waiting round to the new one once (pi-role-review-r05/F-01)" || { printf '       %s\n' "$out"; }
  # herdr-app: a Pi role starts in the Herdr app with provider, model and thinking, and its worktree gets the Pi settings
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; { printf 'host: herdr-app\n'; cat "$PD/.agent-handoff/roles.yaml"; } > "$PD/r.tmp" && mv "$PD/r.tmp" "$PD/.agent-handoff/roles.yaml"
  out="$(pstart "$PD" add-export 2>&1)"; rc=$?; c="$(happ_do space.new)"
  [[ "$rc" == 0 && "$(created)" == 0 && "$(happ_opt "$c" argv)" == '["pi","--provider","openai-codex","--model","gpt-6.2-sol","--thinking","high"]' \
    && "$(jq -c . "$PW/.pi/settings.json" 2>/dev/null)" == '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}' ]]; check "a Pi implementer on the Herdr app starts with provider, model and thinking, and its worktree gets the Pi settings" || { printf '       %s\n' "$out" "$c"; }

finish_section pi
