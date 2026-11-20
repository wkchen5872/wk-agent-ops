#!/usr/bin/env bash
# Handoff test section "mixed". Run: bash tests/test_agent_handoff.sh mixed
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- mixed deployments (real installers, dry-run notifier)
  printf 'mixed deployments\n'
  source "$KV"
  OLD_HOOK="$ROOT/tests/fixtures/notify/telegram-notify-pre-handoff.sh"
  install_handoff() { HOME="$1" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1; }
  install_notify() { HOME="$1" bash -c 'source "$1"; deploy_notify_files' _ "$ROOT/scripts/notify/lib/runtime.sh" >/dev/null 2>&1; }
  # notify_variant <home> <old|rollback>: old = the hook and data before this change; rollback = only the hook reverted
  notify_variant() {
    local hooks="$1/.config/ai-notify/hooks"
    cp "$OLD_HOOK" "$hooks/telegram-notify.sh"
    if [[ "$2" == old ]]; then
      grep -v '^handoff' "$hooks/events.tsv" > "$hooks/events.tsv.tmp" && mv "$hooks/events.tsv.tmp" "$hooks/events.tsv"
      rm -f "$hooks"/templates/handoff-*.md
    fi
  }
  route_real() { (cd "$1" && env -u HANDOFF_NOTIFY HOME="$2" TELEGRAM_DRY_RUN=true PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 \
    "$2/.config/wk-workflow/handoff/handoff-route" --foreground </dev/null 2>/dev/null); }
  # three_cases <home> <tag>: sets OUT_ASK, OUT_BLOCKED, OUT_IMPL and checks routing of each
  three_cases() {
    one_record "$tmp/m-$2-ask" "m-$2-ask" --role review --status done --verdict pass --head HEAD --report r.md; OUT_ASK="$(route_real "$tmp/m-$2-ask" "$1")"
    one_record "$tmp/m-$2-blk" "m-$2-blk" --role implement --status blocked --head HEAD --note "needs-decision-$2"; OUT_BLOCKED="$(route_real "$tmp/m-$2-blk" "$1")"
    one_record "$tmp/m-$2-impl" "m-$2-impl" --role implement --status done --head HEAD; OUT_IMPL="$(route_real "$tmp/m-$2-impl" "$1")"
    routed "$tmp/m-$2-ask" 01-review.yaml && routed "$tmp/m-$2-blk" 01-implement.yaml && routed "$tmp/m-$2-impl" 01-implement.yaml && [[ "$(created)" == 1 ]]
  }
  generic_case() {  # <label> <home> <tag>
    three_cases "$2" "$3" && grep -q 'Action Required' <<<"$OUT_ASK" && grep -q 'handoff-finish add-export' <<<"$OUT_ASK" \
      && grep -q 'Action Required' <<<"$OUT_BLOCKED" && grep -q "needs-decision-$3" <<<"$OUT_BLOCKED" && [[ -z "$OUT_IMPL" ]]; check "$1" || { printf '       ask: %s\n       blocked: %s\n       impl: %s\n' "$OUT_ASK" "$OUT_BLOCKED" "$OUT_IMPL"; }
  }
  handoff_case() {  # <label> <home> <tag>
    three_cases "$2" "$3" && grep -q '需要你處理' <<<"$OUT_ASK" && grep -q 'handoff-finish add-export' <<<"$OUT_ASK" \
      && grep -q '需要你處理' <<<"$OUT_BLOCKED" && grep -q "needs-decision-$3" <<<"$OUT_BLOCKED" && grep -q '實作完成' <<<"$OUT_IMPL"; check "$1" || { printf '       ask: %s\n       blocked: %s\n       impl: %s\n' "$OUT_ASK" "$OUT_BLOCKED" "$OUT_IMPL"; }
  }

  H1="$tmp/m-home-old"; install_notify "$H1"; notify_variant "$H1" old; install_handoff "$H1"
  generic_case "only the handoff side updated: attention reaches the user through the generic path, progress is skipped" "$H1" old
  H2="$tmp/m-home-nh"; install_notify "$H2"; install_handoff "$H2"
  handoff_case "both updated, notifier first: handoff events with their own titles" "$H2" nh
  H3="$tmp/m-home-hn"; install_handoff "$H3"; install_notify "$H3"
  handoff_case "both updated, handoff side first: handoff events with their own titles" "$H3" hn
  H4="$tmp/m-home-rb"; install_notify "$H4"; install_handoff "$H4"; notify_variant "$H4" rollback
  generic_case "notifier rolled back with newer data files left behind: attention still uses the generic path" "$H4" rb
  H5="$tmp/m-home-rbc"; install_notify "$H5"; install_handoff "$H5"; notify_variant "$H5" old
  generic_case "notifier rolled back with its data files cleared: attention still uses the generic path" "$H5" rbc
  # Only the notifier updated: the previous handoff side sent this generic notice with an env override.
  out="$(jq -n --arg m "[add-export] 第 1 輪審查通過。確認後執行：handoff-finish add-export" '{hook_event_name:"Notification", message:$m, cwd:"/tmp/p"}' \
    | env -i PATH="$PATH" HOME="$H2" TELEGRAM_DRY_RUN=true NOTIFY_ACTION_REQUIRED=true bash "$H2/.config/ai-notify/hooks/telegram-notify.sh" notification "Agent Handoff" 2>/dev/null)"
  grep -q 'Action Required' <<<"$out" && grep -q 'handoff-finish add-export' <<<"$out"; check "only the notifier updated: the previous handoff notice is still delivered" || printf '       %s\n' "($out)"
  H6="$tmp/m-home-none"; install_handoff "$H6"
  three_cases "$H6" none && [[ -z "$OUT_ASK$OUT_BLOCKED$OUT_IMPL" ]]; check "never installed notifier: nothing is sent and routing is unchanged"
  hc="$(jq -r '[.hooks.Stop[]?.hooks[]?.command | select(test("handoff-route"))] | join("|")' "$H2/.claude/settings.json" "$H2/.codex/hooks.json" | paste -sd'|' -)"
  [[ "$hc" == "bash \"$H2/.config/wk-workflow/handoff/handoff-route\"|bash \"$H2/.config/wk-workflow/handoff/handoff-route\"" ]]; check "the registered hook command is unchanged for Claude Code and Codex" || printf '       %s\n' "($hc)"

finish_section mixed
