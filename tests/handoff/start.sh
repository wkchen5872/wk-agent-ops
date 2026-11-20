#!/usr/bin/env bash
# Handoff test section "start". Run: bash tests/test_agent_handoff.sh start
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

  printf 'launcher\n'
  source "$KV"
  P="$tmp/start-p"; new_project "$P"; use_project "$P"; fresh_state s1
  WT="$P-add-export"

  P0="$tmp/start-noroles"; new_project "$P0"; rm "$P0/.agent-handoff/roles.yaml"; fresh_state s0
  out="$(start_in "$P0" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'roles.yaml' <<<"$out"; check "missing roles.yaml stops before opening anything"
  out="$(start_in "$P" no-such-change 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$P-no-such-change" ]]; check "unknown change stops without a worktree or session"
  mkdir -p "$P/openspec/changes/no-branch"
  out="$(start_in "$P" no-branch 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'feature/no-branch' <<<"$out"; check "missing feature branch stops"

  # Planning committed only on the feature branch (the usual flow): start finds it there.
  PB="$tmp/start-branch-only"; new_repo "$PB"; git -C "$PB" switch -q -c feature/add-export
  mkdir -p "$PB/openspec/changes/add-export"; printf 'p\n' > "$PB/openspec/changes/add-export/proposal.md"
  git -C "$PB" add openspec; git -C "$PB" commit -qm plan; git -C "$PB" switch -q main
  mkdir -p "$PB/.agent-handoff"; cp "$SKILL/roles.example.yaml" "$PB/.agent-handoff/roles.yaml"; use_project "$PB"; fresh_state s1b
  out="$(start_in "$PB" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$PB-add-export/openspec/changes/add-export" && "$(created)" == 1 ]]; check "a change committed only on its feature branch can be started" || { printf '       %s\n' "$out"; }
  # Change present in the main worktree but missing from the branch: refused.
  PM="$tmp/start-main-only"; new_repo "$PM"; git -C "$PM" branch feature/add-export
  mkdir -p "$PM/openspec/changes/add-export"; printf 'p\n' > "$PM/openspec/changes/add-export/proposal.md"
  git -C "$PM" add openspec; git -C "$PM" commit -qm change-on-main
  mkdir -p "$PM/.agent-handoff"; cp "$SKILL/roles.example.yaml" "$PM/.agent-handoff/roles.yaml"; use_project "$PM"; fresh_state s1c
  out="$(start_in "$PM" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PM-add-export" ]] && grep -q 'feature/add-export' <<<"$out"; check "a change missing from its feature branch is refused" || { printf '       %s\n' "$out"; }
  use_project "$P"; fresh_state s1

  out="$(start_in "$P" add-export 2>&1)"; rc=$?
  loop="$WT/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && -d "$WT" && "$(git -C "$WT" branch --show-current)" == "feature/add-export" && "$(git -C "$P" branch --show-current)" == "main" ]]; check "default opens the implementer in a new worktree and keeps the main worktree on main" || { printf '       %s\n' "$out"; }
  [[ "$(created)" == 1 ]] && jq -e --arg w "$WT" '.worktreePath==$w and .customName=="claude - impl - add-export" and .agent.agentName=="claude" and .agent.options.model=="opus" and .agent.options.effort=="high"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; check "only the implementer is opened, with explicit model, effort and pinned name"
  jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null | grep -q 'openspec-apply-change add-export' && jq -r .goal "$FAKE_XIRP_DIR/create-1.json" | grep -q '.agents/skills/agent-handoff/scripts/handoff-write'; check "implementer prompt is rendered from the template"
  g="$(jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null)"
  grep -qF "agent-handoff/scripts/handoff-author --tool 'Claude Code' --model opus" <<<"$g"; check "implementer prompt has it attach the Author block from handoff-author with its tool and template model"
  [[ -f "$loop" && "$(kv_get "$loop" change)" == add-export && "$(kv_get "$loop" max_rounds)" == 3 && "$(kv_get "$loop" implementer.session)" == sess-1 \
    && "$(kv_get "$loop" implementer.worktree)" == "$WT" && -z "$(kv_get "$loop" reviewer.session)" && "$(kv_get "$loop" finish.trigger)" == ask \
    && "$(kv_get "$loop" finish.delivery)" == local && "$(kv_get "$loop" review_template.model)" == gpt-6.1-sol && "$(kv_get "$loop" finish_template.harness)" == codex \
    && "$(kv_get "$loop" review_template.worktree)" == shared ]]; check "loop.yaml records the implementer, limits, finish settings and templates"
  out="$(start_in "$P" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 1 ]] && grep -q "$WT" <<<"$out"; check "branch already in another worktree stops and names it"

  H="$tmp/start-here"; new_project "$H"; use_project "$H"; fresh_state s2; git -C "$H" switch -q feature/add-export
  out="$(start_in "$H" add-export --worktree here 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$H/.agent-handoff/add-export/loop.yaml" implementer.worktree)" == "$H" ]] && ! git -C "$H" worktree list | grep -q -- "-add-export"; check "--worktree here uses the current checkout on the feature branch"
  H2="$tmp/start-here-main"; new_project "$H2"; use_project "$H2"; fresh_state s3
  out="$(start_in "$H2" add-export --worktree here 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]]; check "--worktree here refuses a checkout on another branch"

  M="$tmp/start-nomodel"; new_project "$M"; use_project "$M"; fresh_state s4
  grep -v '^  model: opus$' "$M/.agent-handoff/roles.yaml" > "$M/r.tmp" && mv "$M/r.tmp" "$M/.agent-handoff/roles.yaml"
  out="$(start_in "$M" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'model' <<<"$out"; check "template without model is refused"
  U="$tmp/start-badmode"; new_project "$U"; use_project "$U"; fresh_state s5
  awk 'BEGIN{n=0} /^  worktree: shared$/ && n==0 {print "  worktree: separate"; n=1; next} {print}' "$U/.agent-handoff/roles.yaml" > "$U/r.tmp" && mv "$U/r.tmp" "$U/.agent-handoff/roles.yaml"
  out="$(start_in "$U" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'shared' <<<"$out" && grep -q 'new' <<<"$out"; check "unknown worktree mode is refused and allowed values named"
  CP="$tmp/start-claude-profile"; new_project "$CP"; use_project "$CP"; fresh_state s5p
  awk '/^implement:/{print; print "  profile: handoff-net"; next} {print}' "$CP/.agent-handoff/roles.yaml" > "$CP/r.tmp" && mv "$CP/r.tmp" "$CP/.agent-handoff/roles.yaml"
  out="$(start_in "$CP" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'profile' <<<"$out"; check "a profile on a Claude template is refused" || { printf '       %s\n' "$out"; }
  CF="$tmp/start-finish-profile"; new_project "$CF"; use_project "$CF"; fresh_state s5q
  awk '/^finish:/{print; print "  profile: handoff-net"; next} {print}' "$CF/.agent-handoff/roles.yaml" > "$CF/r.tmp" && mv "$CF/r.tmp" "$CF/.agent-handoff/roles.yaml"
  out="$(start_in "$CF" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$CF-add-export/.agent-handoff/add-export/loop.yaml" finish_template.profile)" == handoff-net ]]; check "a finish profile is copied into loop.yaml" || { printf '       %s\n' "$out"; }

  O="$tmp/start-override"; new_project "$O"; use_project "$O"; fresh_state s6
  before="$(cat "$O/.agent-handoff/roles.yaml")"
  out="$(start_in "$O" add-export --impl codex:gpt-x:low --review claude:sonnet:max --finish auto 2>&1)"; rc=$?
  ol="$O-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 ]] && jq -e '.agent.agentName=="codex" and .agent.options.model=="gpt-x" and .agent.options.reasoning_effort=="low"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$ol" review_template.harness)" == claude && "$(kv_get "$ol" review_template.model)" == sonnet && "$(kv_get "$ol" review_template.effort)" == max \
    && "$(kv_get "$ol" finish.trigger)" == auto && "$(cat "$O/.agent-handoff/roles.yaml")" == "$before" ]]; check "per-loop overrides are recorded in loop.yaml and roles.yaml is unchanged" || { printf '       %s\n' "$out"; }
  # The overrides above change both tools: Codex review → Claude, Claude implement → Codex.
  [[ "$(kv_get "$ol" review_template.prompt)" == '/change-review {change}'* && "$(kv_get "$ol" review_template.name)" == 'claude - review - {change}' ]] \
    && jq -e '.customName=="codex - impl - add-export" and (.goal|startswith("$openspec-apply-change add-export"))' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; check "an override that changes the tool rewrites the skill call and session name" || { printf '       %s | %s\n' "$(kv_get "$ol" review_template.name)" "$(kv_get "$ol" review_template.prompt | cut -c1-40)"; }
  OS="$tmp/start-same-tool"; new_project "$OS"; use_project "$OS"; fresh_state s6s
  start_in "$OS" add-export --review codex:gpt-6.1-terra:high >/dev/null 2>&1
  osl="$OS-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$(kv_get "$osl" review_template.model)" == gpt-6.1-terra && "$(kv_get "$osl" review_template.prompt)" == '$change-review {change}'* \
    && "$(kv_get "$osl" review_template.name)" == 'codex - review - {change}' ]]; check "an override that keeps the tool keeps the prompt and session name"
  R="$tmp/start-reuse"; new_project "$R"; use_project "$R"; fresh_state s7
  out="$(start_in "$R" add-export --reviewer-session rev-9 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$R-add-export/.agent-handoff/add-export/loop.yaml" reviewer.session)" == rev-9 && "$(created)" == 1 ]]; check "an existing reviewer session is recorded and not reopened"
  R2="$tmp/start-reuse-missing"; new_project "$R2"; use_project "$R2"; fresh_state s8
  out="$(start_in "$R2" add-export --reviewer-session missing-1 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]]; check "an unknown reviewer session is refused"

  # Session hosts: recorded per role in loop.yaml; xirp when roles.yaml names none.
  hl="$P-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$(kv_get "$hl" implement_template.host)" == xirp && "$(kv_get "$hl" review_template.host)" == xirp && "$(kv_get "$hl" finish_template.host)" == xirp ]]; check "without a host in roles.yaml every role records host xirp"
  # host_roles <dir> <section> <host> [top-level lines...]: give one role a host in roles.yaml
  host_roles() {
    local d="$1" sec="$2" h="$3" r="$1/.agent-handoff/roles.yaml"; shift 3
    awk -v s="$sec:" -v h="$h" '$0 == s {print; print "  host: " h; next} {print}' "$r" > "$r.tmp" && mv "$r.tmp" "$r"
    local l; for l in "$@"; do printf '%s\n' "$l" >> "$r"; done
  }
  HV="$tmp/start-host-review"; new_project "$HV"; use_project "$HV"; fresh_state s9; host_roles "$HV" review herdr "herdr_session: work"
  out="$(start_in "$HV" add-export 2>&1)"; rc=$?
  hvl="$HV-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$hvl" implement_template.host)" == xirp && "$(kv_get "$hvl" review_template.host)" == herdr \
    && "$(kv_get "$hvl" implementer.session)" == sess-1 ]] && ! herdr_calls | grep -q 'agent start'; check "a role that sets host: herdr records it, and the implementer still opens through Xirp" || { printf '       %s\n' "$out"; }
  [[ "$(kv_get "$hvl" reviewer.herdr_session)" == work ]]; check "outside herdr the herdr role uses herdr_session from roles.yaml" || printf '       %s\n' "($(kv_get "$hvl" reviewer.herdr_session))"
  HP="$tmp/start-host-pane"; new_project "$HP"; use_project "$HP"; fresh_state s10; host_roles "$HP" review herdr "herdr_session: work"
  HERDR_ENV=1 HERDR_SESSION=dev start_in "$HP" add-export >/dev/null 2>&1
  [[ "$(kv_get "$HP-add-export/.agent-handoff/add-export/loop.yaml" reviewer.herdr_session)" == dev ]]; check "inside a herdr pane the herdr role uses the pane's session"
  HN="$tmp/start-host-default"; new_project "$HN"; use_project "$HN"; fresh_state s11; host_roles "$HN" review herdr
  start_in "$HN" add-export >/dev/null 2>&1
  [[ "$(kv_get "$HN-add-export/.agent-handoff/add-export/loop.yaml" reviewer.herdr_session)" == default ]]; check "without herdr_session the herdr role uses the default session"
  HT="$tmp/start-host-tmux"; new_project "$HT"; use_project "$HT"; fresh_state s12; host_roles "$HT" review tmux
  out="$(start_in "$HT" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$HT-add-export" ]] && grep -q review <<<"$out" && grep -q 'xirp, herdr, herdr-app' <<<"$out" && [[ -z "$(herdr_calls | grep -v 'status\|integration\|version')" ]]; check "an unknown host is refused, naming the role and the accepted hosts, and nothing opens" || { printf '       %s\n' "$out"; }

finish_section start
