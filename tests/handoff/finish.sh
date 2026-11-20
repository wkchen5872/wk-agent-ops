#!/usr/bin/env bash
# Handoff test section "finish". Run: bash tests/test_agent_handoff.sh finish
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- handoff-finish
  printf 'handoff-finish\n'
  source "$KV"
  # passing_loop <dir> [finish-mode]: implementer worktree with one round passed at HEAD
  passing_loop() {
    local d="$1" fmode="${2:-shared}"
    new_loop "$d" shared ask
    awk -v m="$fmode" '/^finish_template:/{f=1} f && /^  worktree:/{print "  worktree: " m; f=0; next} {print}' "$d/.agent-handoff/add-export/loop.yaml" > "$d/l.tmp" \
      && mv "$d/l.tmp" "$d/.agent-handoff/add-export/loop.yaml"
    printf 'r\n' > "$d/r.md"; mkdir -p "$d/.git/info"; printf '/r.md\n/l.tmp\n' >> "$d/.git/info/exclude"
    commit_in "$d" impl; hw "$d" --role implement --status done --head HEAD
    hw "$d" --role review --status done --verdict pass --head HEAD --report r.md
  }
  F="$tmp/fin-ok"; passing_loop "$F"; use_project "$F"; fresh_state f1
  out="$(finish_in "$F" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && jq -e --arg w "$F" '.worktreePath==$w and .customName=="codex - finish - add-export"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$F/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]]; check "a current passing review opens one finish session" || { printf '       %s\n' "$out"; }
  jq -e '.agent.options | has("profile") | not' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; check "a template without profile sends no Codex profile"
  FP="$tmp/fin-profile"; passing_loop "$FP"; use_project "$FP"; fresh_state f1p
  awk '/^finish_template:/{print; print "  profile: \"handoff-net\""; next} {print}' "$FP/.agent-handoff/add-export/loop.yaml" > "$FP/l.tmp" && mv "$FP/l.tmp" "$FP/.agent-handoff/add-export/loop.yaml"
  out="$(finish_in "$FP" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && jq -e '.agent.options.profile == "handoff-net"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; check "a Codex template profile is passed to the new session" || { printf '       %s\n' "$out"; }
  # Running handoff-finish again before the finish session writes a record keeps that session.
  FR="$tmp/fin-again"; passing_loop "$FR"; use_project "$FR"; fresh_state f1r
  finish_in "$FR" add-export >/dev/null 2>&1
  out="$(finish_in "$FR" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$FR/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]] \
    && grep -q 'already open.*sess-1' <<<"$out"; check "a second handoff-finish reuses the open finish session" || { printf '       %s\n' "$out"; }
  FG="$tmp/fin-gone"; passing_loop "$FG"; use_project "$FG"; fresh_state f1g
  awk '/^finish:/{f=1} f&&/^  session:/{print "  session: missing-3"; f=0; next} {print}' "$FG/.agent-handoff/add-export/loop.yaml" > "$FG/l.tmp" && mv "$FG/l.tmp" "$FG/.agent-handoff/add-export/loop.yaml"
  out="$(finish_in "$FG" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$FG/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]]; check "a recorded finish session that is gone is replaced by a new one" || { printf '       %s\n' "$out"; }

  refuse() {
    local label="$1" d="$2" pat="$3"
    out="$(finish_in "$d" add-export 2>&1)"; rc=$?
    [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q -- "$pat" <<<"$out"; check "$label" || { printf '       %s\n' "$out"; }
  }
  F2="$tmp/fin-cr"; new_loop "$F2"; use_project "$F2"; fresh_state f2; printf 'r\n' > "$F2/r.md"; mkdir -p "$F2/.git/info"; printf '/r.md\n' >> "$F2/.git/info/exclude"
  hw "$F2" --role implement --status done --head HEAD; hw "$F2" --role review --status done --verdict changes-required --head HEAD --report r.md
  refuse "refuses a changes-required review" "$F2" "changes-required"
  F3="$tmp/fin-blocked"; new_loop "$F3"; use_project "$F3"; fresh_state f3; printf 'r\n' > "$F3/r.md"; mkdir -p "$F3/.git/info"; printf '/r.md\n' >> "$F3/.git/info/exclude"
  hw "$F3" --role implement --status done --head HEAD; hw "$F3" --role review --status blocked --verdict pass --head HEAD --report r.md
  refuse "refuses a blocked pass" "$F3" "blocked"
  F4="$tmp/fin-moved"; passing_loop "$F4"; use_project "$F4"; fresh_state f4; X4="$(git -C "$F4" rev-parse HEAD)"; commit_in "$F4" later
  refuse "refuses a pass after a new commit and names both commits" "$F4" "$X4"
  F5="$tmp/fin-superseded"; passing_loop "$F5"; use_project "$F5"; fresh_state f5; hw "$F5" --role implement --status done --head HEAD
  refuse "refuses a pass superseded by a new implement record" "$F5" "implement"
  F6="$tmp/fin-dirty"; passing_loop "$F6"; use_project "$F6"; fresh_state f6; printf 'x\n' > "$F6/dirty.txt"
  refuse "refuses when the worktree has uncommitted changes" "$F6" "uncommitted"
  F7="$tmp/fin-done"; passing_loop "$F7"; use_project "$F7"; fresh_state f7; hw "$F7" --role finish --status done --head HEAD
  refuse "refuses when the loop already finished" "$F7" "finish"

  # Retry after a blocked finish: the finish session committed the archive, then stopped.
  retry_loop() {  # retry_loop <dir> <finish-session>
    passing_loop "$1"; commit_in "$1" archive
    awk -v s="$2" '/^finish:/{f=1} f&&/^  session:/{print "  session: " s; f=0; next} {print}' "$1/.agent-handoff/add-export/loop.yaml" > "$1/l.tmp" && mv "$1/l.tmp" "$1/.agent-handoff/add-export/loop.yaml"
    hw "$1" --role finish --status blocked --head HEAD --note "push rejected"
  }
  R1="$tmp/fin-retry"; retry_loop "$R1" fin-9; use_project "$R1"; fresh_state f11
  out="$(finish_in "$R1" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 0 ]] && msgs | grep -q '^fin-9' && msgs | grep 'fin-9' | grep -q -- '--role finish' && msgs | grep 'fin-9' | grep -q '交付方式：local'; check "a blocked finish is retried by messaging the existing finish session" || { printf '       %s\n' "$out"; }
  R2="$tmp/fin-retry-gone"; retry_loop "$R2" missing-7; use_project "$R2"; fresh_state f12
  out="$(finish_in "$R2" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$R2/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]]; check "a blocked finish whose session is gone opens a new finish session" || { printf '       %s\n' "$out"; }
  R6="$tmp/fin-retry-pr"; retry_loop "$R6" fin-9; use_project "$R6"; fresh_state f16
  sed -i '' 's/^  delivery: local$/  delivery: pr/' "$R6/.agent-handoff/add-export/loop.yaml"
  finish_in "$R6" add-export >/dev/null 2>&1
  msgs | grep 'fin-9' | grep -q '最終版 Review' && msgs | grep 'fin-9' | grep -q 'Closure'; check "a PR delivery retry states that it covers the final-version review and the Closure"
  msgs | grep 'fin-9' | grep -q '直接同步主規格'; check "a retry message says to sync main specs without asking"
  R3="$tmp/fin-retry-dirty"; retry_loop "$R3" fin-9; use_project "$R3"; fresh_state f13; printf 'x\n' > "$R3/dirty.txt"
  refuse "a blocked finish is not retried with uncommitted changes" "$R3" "uncommitted"
  R4="$tmp/fin-retry-done"; retry_loop "$R4" fin-9; use_project "$R4"; fresh_state f14; hw "$R4" --role finish --status done --head HEAD
  refuse "a finished loop is not retried" "$R4" "finish"
  R5="$tmp/fin-retry-off"; retry_loop "$R5" fin-9; use_project "$R5"; fresh_state f15
  git -C "$R5" checkout -q --orphan other && git -C "$R5" commit -qm unrelated --allow-empty
  hw "$R5" --role finish --status blocked --head HEAD --note again
  refuse "a blocked finish is not retried when HEAD does not build on the passing review" "$R5" "pass"

  # handoff-role --replace on the finish role (replace-open-handoff-roles)
  flog() { cat "$1/.agent-handoff/add-export/routing.log" 2>/dev/null; }
  RB="$tmp/fin-replace-blocked"; retry_loop "$RB" fin-9; use_project "$RB"; fresh_state f17
  finish_in "$RB" add-export >/dev/null 2>&1   # the retry went to fin-9 before its quota ran out
  out="$(role_in "$RB" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == fin-9 && "$(created)" == 1 && "$(kv_get "$RB/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]] \
    && jq -e '.agent.agentName=="claude" and .customName=="claude - finish - add-export" and (.goal|test("openspec-commit add-export"))' "$FAKE_XIRP_DIR/create-1.json" >/dev/null 2>&1 \
    && flog "$RB" | grep -q 'finish.yaml action=finish:opened:sess-1'; check "a blocked finish whose role is replaced opens a new finish session with the finish prompt" || { printf '       %s\n' "$out"; }
  RO="$tmp/fin-replace-open"; passing_loop "$RO"; use_project "$RO"; fresh_state f18; finish_in "$RO" add-export >/dev/null 2>&1
  out="$(role_in "$RO" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == sess-1 && "$(created)" == 2 && "$(kv_get "$RO/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-2 ]]; check "a finish session opened for a passing review is replaced by a new one" || { printf '       %s\n' "$out"; }
  RP="$tmp/fin-replace-pass"; passing_loop "$RP"; use_project "$RP"; fresh_state f19
  out="$(role_in "$RP" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 0 && "$(kv_get "$RP/.agent-handoff/add-export/loop.yaml" finish_template.harness)" == claude ]]; check "a passing review whose finish has not opened only changes the finish role" || { printf '       %s\n' "$out"; }

  RW="$tmp/fin-replace-move"; retry_loop "$RW" fin-9; use_project "$RW"; fresh_state f20; XW="$(git -C "$RW" rev-parse HEAD)"
  out="$(role_in "$RW" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$RW-finish" && "$(git -C "$RW-finish" branch --show-current)" == feature/add-export && "$(git -C "$RW-finish" rev-parse HEAD)" == "$XW" \
    && "$(kv_get "$RW/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$RW-finish" && "$(created)" == 1 ]] \
    && jq -e --arg w "$RW-finish" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null 2>&1; check "a blocked shared finish moved to its own worktree resumes there on the feature branch (codex-role-review-r01/F-08)" || { printf '       %s\n' "$out"; }
  RF="$tmp/fin-replace-fail"; retry_loop "$RF" fin-9; use_project "$RF"; fresh_state f21; touch "$FAKE_XIRP_DIR/create-fail"; n0="$(ncount)"
  out="$(role_in "$RF" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/create-fail"
  [[ "$rc" != 0 && "$(( $(ncount) - n0 ))" == 1 ]] && jt '.kind=="attention"' && grep -q 'handoff-finish add-export' <<<"$out"; check "a finish that cannot open after a replacement sends one attention notice" || { printf '       %s\n' "$out"; }

  # Round 3 (codex-role-review-r02/F-08)
  R8="$tmp/fin-move-tip"; retry_loop "$R8" fin-9; use_project "$R8"; fresh_state f22
  git -C "$R8" checkout -q --detach; git -C "$R8" branch -f feature/add-export HEAD~1
  out="$(role_in "$R8" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$R8-finish" ]] && grep -q 'feature/add-export' <<<"$out"; check "a blocked finish is not moved onto a feature branch tip other than its commit (codex-role-review-r02/F-08)" || { printf '       %s\n' "$out"; }
  R9="$tmp/fin-move-copy"; retry_loop "$R9" fin-9; use_project "$R9"; fresh_state f23
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*-finish/.agent-handoff/add-export/loop.yaml' role_in "$R9" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  fout="$(finish_in "$R9" add-export 2>&1)"; frc=$?
  [[ "$rc" != 0 && "$frc" == 0 && "$(created)" == 1 && "$(kv_get "$R9-finish/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$R9-finish" ]]; check "a move whose finish-worktree copy failed is completed by handoff-finish (codex-role-review-r02/F-08)" || { printf '       %s\n' "$out" "$fout"; }
  R10="$tmp/fin-move-ptr"; retry_loop "$R10" fin-9; use_project "$R10"; fresh_state f24; lset "$R10/.agent-handoff/add-export/loop.yaml" finish.worktree "$R10"
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL="$R10/.agent-handoff/add-export/loop.yaml" FAKE_MV_FROM="$MV_KV" role_in "$R10" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  fout="$(finish_in "$R10" add-export 2>&1)"; frc=$?
  [[ "$rc" != 0 && "$frc" == 0 && "$(created)" == 1 && "$(kv_get "$R10/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$R10-finish" ]] \
    && jq -e --arg w "$R10-finish" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null 2>&1; check "a move whose loop.yaml pointer failed reuses its finish worktree on retry (codex-role-review-r02/F-08)" || { printf '       %s\n' "$out" "$fout"; }

  # Round 4 (codex-role-review-r03/F-08)
  R11="$tmp/fin-move-back"; retry_loop "$R11" fin-9; use_project "$R11"; fresh_state f25; git -C "$R11" reset -q --hard HEAD~1
  out="$(role_in "$R11" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$R11-finish" ]] && grep -q 'blocked finish' <<<"$out"; check "a blocked finish is not moved from a worktree that no longer holds its commit (codex-role-review-r03/F-08)" || { printf '       %s\n' "$out"; }
  R12="$tmp/fin-move-race"; retry_loop "$R12" fin-9; use_project "$R12"; fresh_state f26
  out="$(PATH="$GITSHIM:$PATH" FAKE_GIT_MOVE_TO="$(git -C "$R12" rev-parse HEAD~2)" role_in "$R12" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'not opened' <<<"$out"; check "a finish worktree that checked out another commit is not opened (codex-role-review-r03/F-08)" || { printf '       %s\n' "$out"; }

  # Round 5 (pi-role-review-r04/F-08): a move cut short is not completed on a commit without the blocked finish's work.
  R13="$tmp/fin-move-rewound"; retry_loop "$R13" fin-9; use_project "$R13"; fresh_state f27; B13="$(git -C "$R13" rev-parse HEAD)"
  PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*-finish/.agent-handoff/add-export/loop.yaml' role_in "$R13" add-export finish claude:sonnet:high --worktree new --replace >/dev/null 2>&1
  git -C "$R13-finish" reset -q --hard HEAD~1
  fout="$(finish_in "$R13" add-export 2>&1)"; frc=$?
  [[ "$frc" != 0 && "$(created)" == 0 ]] && grep -q "${B13:0:7}" <<<"$fout"; check "completing a move cut short refuses a finish worktree without the blocked finish's commit (pi-role-review-r04/F-08)" || { printf '       %s\n' "$fout"; }

  # Pass recorded in a separate review worktree B; finish runs from A.
  SA="$tmp/fin-sep"; new_loop "$SA" new ask; use_project "$SA"; fresh_state f8; SB="$SA-review"
  commit_in "$SA" impl; hw "$SA" --role implement --status done --head HEAD
  route_in "$SA"
  mkdir -p "$SB/rv"; printf 'ok\n' > "$SB/rv/r.md"; mkdir -p "$(git -C "$SB" rev-parse --path-format=absolute --git-common-dir)/info"; printf '/rv/\n' >> "$(git -C "$SB" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  hw "$SB" --role review --status done --verdict pass --head HEAD --report rv/r.md
  out="$(finish_in "$SA" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 2 ]]; check "a pass in the separate review worktree lets A finish" || { printf '       %s\n' "$out"; }

  # Separate finish worktree takes over the branch.
  N="$tmp/fin-new"; passing_loop "$N" new; use_project "$N"; fresh_state f9; XN="$(git -C "$N" rev-parse HEAD)"
  out="$(finish_in "$N" add-export 2>&1)"; rc=$?
  NF="$N-finish"
  [[ "$rc" == 0 && -d "$NF" && "$(git -C "$NF" branch --show-current)" == feature/add-export && "$(git -C "$NF" rev-parse HEAD)" == "$XN" \
    && -z "$(git -C "$N" branch --show-current)" && "$(git -C "$N" rev-parse HEAD)" == "$XN" && -f "$N/work.txt" ]] \
    && jq -e --arg w "$NF" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$N/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$NF" ]]; check "finish worktree new detaches A at the head and opens the finish session on the branch" || { printf '       %s\n' "$out"; }
  N2="$tmp/fin-new-dirty"; passing_loop "$N2" new; use_project "$N2"; fresh_state f10; printf 'x\n' > "$N2/dirty.txt"
  out="$(finish_in "$N2" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$N2-finish" && "$(git -C "$N2" branch --show-current)" == feature/add-export ]]; check "finish worktree new does nothing when A is unclean"

finish_section finish
