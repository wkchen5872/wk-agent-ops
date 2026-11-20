#!/usr/bin/env bash
# Handoff test section "notify". Run: bash tests/test_agent_handoff.sh notify
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

  printf 'handoff notifications\n'
  source "$KV"

  N="$tmp/n-loop"; new_loop "$N"; use_project "$N"; fresh_state n1; rpt "$N"
  commit_in "$N" one; X="$(git -C "$N" rev-parse HEAD)"; hw "$N" --role implement --status done --head HEAD
  route_in "$N"
  notes | grep -q '^event=handoff action_required=unset ' && ! notes | grep -q 'action_required=true'; check "notifies through the handoff event without an environment override"
  jt --arg c "${X:0:7}" --arg w "$N" '.kind=="implement" and .change=="add-export" and .round=="1" and .commit==$c and .cwd==$w and (.next|test("審查者")) and (.next|test("1"))'; check "implementation handover names change, round, 7-character commit and the reviewer step" || printf '       %s\n' "($(jl | tail -1))"
  jt '.agent=="Claude / fake-model / high"'; check "agent label comes from Xirp's tool, model and effort" || printf '       %s\n' "($(jl | tail -1))"
  hw "$N" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$N"
  jt '.kind=="review" and .verdict=="changes-required" and .round=="1" and (.next|test("實作者"))'; check "changes-required sends a review notice that the implementer was asked" || printf '       %s\n' "($(jl | tail -1))"
  commit_in "$N" two; Y="$(git -C "$N" rev-parse HEAD)"; hw "$N" --role implement --status done --head HEAD; route_in "$N"
  jt --arg c "${Y:0:7}" '.kind=="implement" and .round=="2" and .commit==$c and (.next|test("第 2 輪"))'; check "a later handover names round 2 and its commit" || printf '       %s\n' "($(jl | tail -1))"
  hw "$N" --role review --status done --verdict pass --head HEAD --report r.md; route_in "$N"
  jt '.kind=="attention" and (.next|test("handoff-finish add-export"))'; check "a pass with trigger ask is an attention notice to run handoff-finish" || printf '       %s\n' "($(jl | tail -1))"
  hw "$N" --role finish --status done --head HEAD; route_in "$N"
  jt '.kind=="finish"'; check "a finish record sends a finish notice"
  [[ "$(kinds)" == "implement review implement attention finish" ]]; check "notices follow the loop in order" || printf '       %s\n' "($(kinds))"
  before="$(ncount)"; route_in "$N"
  [[ "$(ncount)" == "$before" ]]; check "an agent stopping again sends nothing new"

  NA="$tmp/n-auto"; new_loop "$NA" shared auto; use_project "$NA"; fresh_state n2; rpt "$NA"
  hw "$NA" --role implement --status done --head HEAD; hw "$NA" --role review --status done --verdict pass --head HEAD --report r.md
  route_in "$NA"
  [[ "$(created)" == 1 && "$(kinds)" == review ]] && jt '.verdict=="pass" and (.next|test("收尾"))'; check "a pass with trigger auto opens finish and sends a review notice" || printf '       %s\n' "($(kinds))"

  # Agent information
  agent_case() {  # <state> <session.json or empty> → agent field of the implementation notice
    one_record "$tmp/n-agent-$1" "$1" --role implement --status done --head HEAD
    [[ -n "$2" ]] && printf '%s\n' "$2" > "$FAKE_XIRP_DIR/session.json"
    route_in "$tmp/n-agent-$1"; jl | tail -1 | jq -r .agent
  }
  [[ "$(agent_case a1 '{"currentAgent":"codex","model":"gpt-6.1-sol","agentLaunchOptions":{"options":{"reasoning_effort":null}}}')" == "Codex / gpt-6.1-sol" ]]; check "an unknown effort is left out of the agent label"
  [[ "$(agent_case a2 '{"currentAgent":"codex","model":"gpt-6.1-sol","agentLaunchOptions":{"options":{"reasoning_effort":"xhigh"}}}')" == "Codex / gpt-6.1-sol / xhigh" ]]; check "Codex effort is read from reasoning_effort"
  [[ "$(agent_case a3 '{"currentAgent":"claude","model":"claude-sonnet-5-5","requestedModel":"opus","agentLaunchOptions":{"options":{"model":"opus","effort":"high"}}}')" == "Claude / claude-sonnet-5-5 / high" ]]; check "the agent label shows the model in use, not the one requested at launch"
  [[ "$(agent_case a4 '{"currentAgent":"codex","model":"gpt_6*x"}')" == "Codex / gpt_6*x" ]]; check "agent values are passed as reported"
  one_record "$tmp/n-agent-a5" a5 --role implement --status done --head HEAD
  T_SID=missing-1 route_in "$tmp/n-agent-a5"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && jt '.kind=="implement" and .agent==""'; check "when Xirp cannot report the session the record is routed and notified without agent parts"
  one_record "$tmp/n-sid" n3 --role implement --status done --head HEAD
  (cd "$tmp/n-sid" && printf '{"session_id":"native-1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID=chirp-1 "$ROUTE")
  jt '.session_id=="native-1"'; check "the notice carries the native session id from the hook input"

  one_record "$tmp/n-manual" n5 --role implement --status done --head HEAD
  (cd "$tmp/n-manual" && printf '{"session_id":"native-1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 "$ROUTE" --foreground)
  [[ "$(created)" == 1 ]] && jt '.kind=="implement" and .agent=="" and .session_id==""'; check "a manual foreground run routes the record and leaves out the agent and session label" || printf '       %s\n' "($(jl | tail -1))"
  one_record "$tmp/n-rc" n4 --role implement --status done --head HEAD
  FAKE_NOTIFY_RC=1 route_in "$tmp/n-rc"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && routed "$tmp/n-rc" 01-implement.yaml; check "a failing notifier changes neither routing nor the exit status"

  # Attention sources that stop for the user: notified once, then marked processed.
  stop_case() {  # <label> <dir> <detail regex> <next regex>
    if jt --arg d "$3" --arg n "$4" '.kind=="attention" and (.detail|test($d)) and (.next|test($n))' && routed "$2" "$(ls "$2/.agent-handoff/add-export" | grep -E '^[0-9]{2}-' | sort | tail -1)"; then
      local before; before="$(ncount)"; route_in "$2"
      [[ "$(ncount)" == "$before" ]]; check "$1" || printf '       %s\n' "(notified again)"
    else
      bad "$1 ($(jl | tail -1))"
    fi
  }
  one_record "$tmp/n-blocked" s1 --role implement --status blocked --head HEAD --note "need a decision"; route_in "$tmp/n-blocked"
  stop_case "a blocked record is one attention notice with its note" "$tmp/n-blocked" 'need a decision' '.'
  NL="$tmp/n-limit"; new_loop "$NL" shared ask 1; use_project "$NL"; fresh_state s2; rpt "$NL"
  hw "$NL" --role implement --status done --head HEAD; hw "$NL" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$NL"
  [[ -z "$(msgs)" ]] && stop_case "the round limit is one attention notice and the implementer gets no message" "$NL" '上限' '.' \
    || bad "the round limit is one attention notice and the implementer gets no message"
  one_record "$tmp/n-dirty" s3 --role implement --status done --head HEAD; printf 'wip\n' > "$tmp/n-dirty/wip.txt"; route_in "$tmp/n-dirty"
  stop_case "an unclean worktree is one attention notice" "$tmp/n-dirty" '未提交' '.'
  one_record "$tmp/n-moved" s4 --role implement --status done --head HEAD; commit_in "$tmp/n-moved" moved; route_in "$tmp/n-moved"
  stop_case "a worktree at another head is one attention notice" "$tmp/n-moved" 'HEAD' '.'
  NU="$tmp/n-unknown"; new_loop "$NU"; use_project "$NU"; fresh_state s5
  printf 'change: add-export\nround: 1\nrole: review\nstatus: done\nverdict: weird\nhead: %s\n' "$(git -C "$NU" rev-parse HEAD)" > "$NU/.agent-handoff/add-export/01-review.yaml"
  route_in "$NU"
  stop_case "an unreadable record is one attention notice" "$NU" '01-review.yaml' '.'
  one_record "$tmp/n-fblocked" s6 --role finish --status blocked --head HEAD --note "push rejected"; route_in "$tmp/n-fblocked"
  stop_case "a stopped finish is one attention notice with the reason and the retry command" "$tmp/n-fblocked" 'push rejected' 'handoff-finish add-export'
  one_record "$tmp/n-ask" s7 --role review --status done --verdict pass --head HEAD --report r.md; route_in "$tmp/n-ask"
  stop_case "a pass waiting for handoff-finish is notified once" "$tmp/n-ask" '.' '^請執行：handoff-finish add-export$'
  # Refused auto finish: the review passed in B while the implementer moved on in A.
  FA="$tmp/n-refuse"; new_loop "$FA" new auto; use_project "$FA"; fresh_state s8; FB="${FA}-review"
  commit_in "$FA" one; hw "$FA" --role implement --status done --head HEAD; route_in "$FA"
  fcommon="$(git -C "$FA" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$fcommon/info"; printf '/r.md\n' >> "$fcommon/info/exclude"
  printf 'r\n' > "$FB/r.md"; hw "$FB" --role review --status done --verdict pass --head HEAD --report r.md
  commit_in "$FA" moved-on; route_in "$FB"
  [[ "$(created)" == 1 ]] && stop_case "a refused automatic finish is one attention notice" "$FB" '收尾' 'handoff-finish add-export' \
    || bad "a refused automatic finish is one attention notice (created $(created))"

  # Retryable failures: one attention notice, left unprocessed, retried by the next run.
  retry_case() {  # <label> <dir> <record> <detail regex>
    if jt --arg d "$4" '.kind=="attention" and (.detail|test($d)) and (.next|test("handoff-route --foreground"))' && ! routed "$2" "$3"; then
      local before; before="$(ncount)"; route_in "$2"
      [[ "$(ncount)" == "$before" ]] && ! routed "$2" "$3"; check "$1" || printf '       %s\n' "(second run)"
    else
      bad "$1 ($(jl | tail -1))"
    fi
  }
  NR="$tmp/n-sendrev"; one_record "$NR" f1 --role implement --status done --head HEAD
  lset "$NR/.agent-handoff/add-export/loop.yaml" reviewer.session sess-r; lset "$NR/.agent-handoff/add-export/loop.yaml" reviewer.worktree "$NR"
  touch "$FAKE_XIRP_DIR/msg-fail"; route_in "$NR"; rc=$?
  [[ "$rc" == 0 && "$(kinds)" == attention ]] && grep -q 'send-failed' "$NR/.agent-handoff/add-export/routing.log" \
    && retry_case "a message the reviewer did not get is one attention notice and stays unprocessed" "$NR" 01-implement.yaml '審查者' \
    || bad "a message the reviewer did not get is one attention notice and stays unprocessed ($(kinds))"
  rm -f "$FAKE_XIRP_DIR/msg-fail"; route_in "$NR"
  [[ "$(msgs | grep -c $'^sess-r\t')" == 1 && "$(kinds)" == "attention implement" ]] && routed "$NR" 01-implement.yaml; check "a retry that reaches the reviewer sends the message and the progress notice once" || printf '       %s\n' "($(kinds))"
  [[ "$(jl | head -1 | jq -r .agent)" == "Claude / fake-model / high" ]] && jt '.agent=="" and .session_id==""'; check "a retried record's notice leaves out the agent and session label of whoever triggered the retry" || printf '       %s\n' "($(jl | tail -1))"
  NI="$tmp/n-sendimpl"; one_record "$NI" f2 --role implement --status done --head HEAD
  hw "$NI" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$FAKE_XIRP_DIR/msg-fail"; route_in "$NI"; rc=$?
  [[ "$rc" == 0 && "$(kinds)" == attention ]] && grep -q 'send-failed' "$NI/.agent-handoff/add-export/routing.log" \
    && retry_case "a message the implementer did not get is one attention notice and stays unprocessed" "$NI" 02-review.yaml '實作者' \
    || bad "a message the implementer did not get is one attention notice and stays unprocessed ($(kinds))"
  rm -f "$FAKE_XIRP_DIR/msg-fail"; route_in "$NI"
  [[ "$(msgs | grep -c $'^impl-1\t')" == 1 && "$(kinds)" == "attention review" ]] && routed "$NI" 02-review.yaml; check "a retry that reaches the implementer sends the message and the review notice once" || printf '       %s\n' "($(kinds))"
  NO="$tmp/n-open"; one_record "$NO" f3 --role implement --status done --head HEAD
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NO"
  [[ "$(created)" == 0 ]] && retry_case "a reviewer that cannot be opened is one attention notice and stays unprocessed" "$NO" 01-implement.yaml '審查' \
    || bad "a reviewer that cannot be opened is one attention notice and stays unprocessed"
  use_project "$NO"; route_in "$NO"
  [[ "$(created)" == 1 && "$(kinds)" == "attention implement" ]] && routed "$NO" 01-implement.yaml; check "a later run opens the reviewer and sends the progress notice" || printf '       %s\n' "($(kinds))"
  NW="$tmp/n-wtfail"; new_loop "$NW" new; use_project "$NW"; fresh_state f4; hw "$NW" --role implement --status done --head HEAD
  touch "${NW}-review"; route_in "$NW"
  [[ "$(created)" == 0 ]] && retry_case "a review worktree that cannot be created is one attention notice and stays unprocessed" "$NW" 01-implement.yaml 'worktree' \
    || bad "a review worktree that cannot be created is one attention notice and stays unprocessed"
  rm -f "${NW}-review"; route_in "$NW"
  [[ "$(created)" == 1 && -d "${NW}-review" ]] && routed "$NW" 01-implement.yaml; check "a later run creates the review worktree and opens the reviewer"
  NV="$tmp/n-movefail"; one_record "$NV" f5 --role implement --status done --head HEAD
  lset "$NV/.agent-handoff/add-export/loop.yaml" reviewer.session sess-r; lset "$NV/.agent-handoff/add-export/loop.yaml" reviewer.worktree "$tmp/n-not-a-worktree"
  mkdir -p "$tmp/n-not-a-worktree"; route_in "$NV"
  [[ -z "$(msgs)" ]] && retry_case "a review worktree that cannot be moved is one attention notice and stays unprocessed" "$NV" 01-implement.yaml 'worktree' \
    || bad "a review worktree that cannot be moved is one attention notice and stays unprocessed"

  # codex-01a1eecf-r01/F-01: a finish worktree made by a failed attempt is reused on retry.
  NF="$tmp/n-finretry"; new_loop "$NF" shared auto; use_project "$NF"; fresh_state f6; rpt "$NF"
  lf="$NF/.agent-handoff/add-export/loop.yaml"
  awk '/^finish_template:/{s=1} s && /^  worktree: shared$/{print "  worktree: new"; s=0; next} {print}' "$lf" > "$lf.tmp" && mv "$lf.tmp" "$lf"
  hw "$NF" --role implement --status done --head HEAD; hw "$NF" --role review --status done --verdict pass --head HEAD --report r.md
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NF"
  [[ -d "${NF}-finish" && "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$NF" 02-review.yaml; check "a finish session that cannot be opened leaves the prepared finish worktree and the record unprocessed" || printf '       %s\n' "($(kinds))"
  use_project "$NF"; route_in "$NF"
  [[ "$(created)" == 1 && "$(kinds)" == "attention review" ]] && jt '.verdict=="pass"' && routed "$NF" 02-review.yaml \
    && jq -e --arg w "${NF}-finish" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; check "a retry reuses that finish worktree, opens one finish session and sends one review notice" || printf '       %s\n' "(created $(created), $(kinds))"

  NF2="$tmp/n-findirty"; new_loop "$NF2" shared auto; use_project "$NF2"; fresh_state f8; rpt "$NF2"
  lf="$NF2/.agent-handoff/add-export/loop.yaml"
  awk '/^finish_template:/{s=1} s && /^  worktree: shared$/{print "  worktree: new"; s=0; next} {print}' "$lf" > "$lf.tmp" && mv "$lf.tmp" "$lf"
  hw "$NF2" --role implement --status done --head HEAD; hw "$NF2" --role review --status done --verdict pass --head HEAD --report r.md
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NF2"
  printf 'mine\n' > "${NF2}-finish/stray.txt"; use_project "$NF2"; route_in "$NF2"
  [[ "$(created)" == 0 && "$(cat "${NF2}-finish/stray.txt")" == mine ]] && ! routed "$NF2" 02-review.yaml; check "an unclean finish worktree is not reused and its content is kept"

  # codex-01a1eecf-r01/F-02: a reused review worktree must be clean.
  NRW="$tmp/n-revretry"; new_loop "$NRW" new; use_project "$NRW"; fresh_state f7; hw "$NRW" --role implement --status done --head HEAD
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NRW"
  rhead="$(git -C "${NRW}-review" rev-parse HEAD 2>/dev/null)"
  printf 'keep me\n' > "${NRW}-review/stray.txt"
  use_project "$NRW"; route_in "$NRW"
  [[ "$(created)" == 0 && "$(kinds)" == "attention attention" && "$(cat "${NRW}-review/stray.txt")" == "keep me" \
    && "$(git -C "${NRW}-review" rev-parse HEAD)" == "$rhead" ]] && jt '.detail|test("未提交")' && routed "$NRW" 01-implement.yaml; check "an unclean reused review worktree stops for the user without opening the reviewer" || printf '       %s\n' "(created $(created), $(kinds))"
  before="$(ncount)"; route_in "$NRW"
  [[ "$(ncount)" == "$before" && "$(created)" == 0 ]]; check "that stop is not notified again"

  # Without a notification hook nothing is sent and routing is unchanged.
  route_none() { (cd "$1" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$tmp/no-such-notify.sh" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 "$ROUTE" --foreground </dev/null); }
  one_record "$tmp/n-none-ask" u1 --role review --status done --verdict pass --head HEAD --report r.md; route_none "$tmp/n-none-ask"; rc1=$?
  one_record "$tmp/n-none-blocked" u2 --role implement --status blocked --head HEAD --note x; route_none "$tmp/n-none-blocked"; rc2=$?
  one_record "$tmp/n-none-impl" u3 --role implement --status done --head HEAD; route_none "$tmp/n-none-impl"; rc3=$?
  [[ "$rc1$rc2$rc3" == 000 && ! -e "$tmp/state-u1/notified" && ! -e "$tmp/state-u2/notified" && ! -e "$tmp/state-u3/notified" ]] \
    && routed "$tmp/n-none-ask" 01-review.yaml && routed "$tmp/n-none-blocked" 01-implement.yaml && routed "$tmp/n-none-impl" 01-implement.yaml \
    && [[ "$(created)" == 1 ]]; check "without a notification hook nothing is sent, records are processed and the reviewer is opened"

finish_section notify
