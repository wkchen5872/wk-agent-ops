#!/usr/bin/env bash
# Handoff test section "install". Run: bash tests/test_agent_handoff.sh install
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- installer (project level)
  printf 'installer\n'
  target="$tmp/install-target"; git init -q -b main "$target"
  printf 'node_modules/\n' > "$target/.gitignore"
  bash "$ROOT/scripts/skills/install.sh" --target "$target" >/dev/null 2>&1
  bash "$ROOT/scripts/skills/install.sh" --target "$target" >/dev/null 2>&1
  [[ "$(grep -cx '/.agent-handoff/' "$target/.gitignore")" == "1" ]]; check "adds /.agent-handoff/ to .gitignore exactly once"
  grep -qx 'node_modules/' "$target/.gitignore"; check "keeps existing ignore rules"
  git -C "$target" check-ignore -q .agent-handoff/roles.yaml \
    && git -C "$target" check-ignore -q .agent-handoff/add-export/01-implement.yaml; check "handoff files are ignored by effect"
  [[ -f "$target/.agent-handoff/roles.yaml" ]] && cmp -s "$SKILL/roles.example.yaml" "$target/.agent-handoff/roles.yaml"; check "seeds roles.yaml from the example when missing"
  printf '# my edits\n' >> "$target/.agent-handoff/roles.yaml"
  edited="$(cat "$target/.agent-handoff/roles.yaml" 2>/dev/null)"
  bash "$ROOT/scripts/skills/install.sh" --target "$target" >/dev/null 2>&1
  [[ -n "$edited" && "$(cat "$target/.agent-handoff/roles.yaml")" == "$edited" ]]; check "never overwrites an existing roles.yaml"
  [[ -x "$target/.agents/skills/agent-handoff/scripts/handoff-write" && -x "$target/.claude/skills/agent-handoff/scripts/handoff-write" ]]; check "installs handoff-write under .agents/ and .claude/ skills"

  conflict="$tmp/install-conflict"; git init -q -b main "$conflict"
  printf '/.agent-handoff/**\n!/.agent-handoff/roles.yaml\n' > "$conflict/.gitignore"
  out="$(bash "$ROOT/scripts/skills/install.sh" --target "$conflict" 2>&1)"
  grep -q 'agent-handoff' <<<"$out" && grep -qi 'not ignored' <<<"$out" \
    && [[ "$(head -2 "$conflict/.gitignore")" == $'/.agent-handoff/**\n!/.agent-handoff/roles.yaml' ]] \
    && [[ "$(grep -c 'agent-handoff' "$conflict/.gitignore")" == "2" ]]; check "reports a negation that un-ignores handoff files and leaves it unchanged"

  # roles.example.yaml carries the confirmed defaults and parses.
  ex="$SKILL/roles.example.yaml"
  [[ -f "$ex" ]] && source "$KV" && [[ "$(kv_get "$ex" review.worktree)" == "shared" && "$(kv_get "$ex" finish.worktree)" == "shared" \
    && "$(kv_get "$ex" finish.trigger)" == "ask" && "$(kv_get "$ex" finish.delivery)" == "local" && "$(kv_get "$ex" max_rounds)" == "3" ]]; check "example templates default to shared worktrees, ask, local and 3 rounds"
  missing=""
  for role in implement review finish; do
    for k in harness model effort name prompt; do kv_get "$ex" "$role.$k" >/dev/null 2>&1 || missing="$missing $role.$k"; done
  done
  [[ -z "$missing" ]]; check "every role template sets harness, model, effort, name and prompt" || printf '       %s\n' "(missing:$missing)"
  n_author="$(grep -c '^  prompt: .*{author}' "$SKILL/roles.example.yaml")"
  [[ "$n_author" == 3 ]]; check "every example role prompt asks for the Author identity" || printf '       %s\n' "($n_author/3)"
  grep -q 'profile: handoff-net' "$SKILL/roles.example.yaml" && grep -q 'delivery: pr' "$SKILL/roles.example.yaml"; check "the example explains the Codex network profile for PR delivery"
  grep -q '^  prompt: .*最終版 Review' "$SKILL/roles.example.yaml" && grep -q '^  prompt: .*Closure' "$SKILL/roles.example.yaml"; check "the example finish prompt says PR delivery covers the final-version review and the Closure"
  grep -q '^  prompt: "\$openspec-commit.*直接同步主規格' "$SKILL/roles.example.yaml"; check "the example finish prompt says to sync main specs without asking"
  rp="$(grep '^  prompt: "\$change-review' "$SKILL/roles.example.yaml")"
  grep -q '由 handoff hook 通知' <<<"$rp" && grep -q '不是排除通知' <<<"$rp"; check "the example review prompt says the hook notifies the implementer and this is not a notification exclusion"

finish_section install
