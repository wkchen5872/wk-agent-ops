#!/usr/bin/env bash
# Shared helpers for handoff-route, handoff-start and handoff-finish.
# Source this file; do not execute it. Requires git and jq; xirp only at runtime.

HANDOFF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HANDOFF_LIB_DIR/kv.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HANDOFF_LIB_DIR/kv.sh"
else
  # Development checkout: the single source of the parser lives in the agent-handoff skill.
  # shellcheck source=/dev/null
  source "$HANDOFF_LIB_DIR/../../../template/common/skills/agent-handoff/scripts/kv.sh"
fi

HANDOFF_WRITE_REL=".agents/skills/agent-handoff/scripts/handoff-write"
HANDOFF_NOTIFY="${HANDOFF_NOTIFY:-$HOME/.config/ai-notify/hooks/telegram-notify.sh}"
HANDOFF_CREATE_WAIT="${HANDOFF_CREATE_WAIT:-60}"

ho_err() { printf '%s\n' "$*" >&2; }

# --- key/value writing (two levels at most) ---------------------------------
# kv_set <file> <key|section.key> <value>: replace the value, or add the key.
kv_set() {
  local file="$1" path="$2" value="$3" section="" key="$2" tmp
  if [[ "$path" == *.* ]]; then section="${path%%.*}"; key="${path#*.}"; fi
  [[ -f "$file" ]] || : > "$file"
  tmp="$(mktemp "${file}.XXXXXX")" || return 1
  awk -v sec="$section" -v key="$key" -v val="$value" '
    function emit() { if (sec == "") print key ": " val; else print "  " key ": " val }
    {
      line = $0; indented = (line ~ /^[[:space:]]/)
      stripped = line; sub(/^[[:space:]]+/, "", stripped)
      n = index(stripped, ":"); k = (n ? substr(stripped, 1, n - 1) : "")
      if (!indented && n) {
        if (insec && !done) { emit(); done = 1 }
        insec = (sec != "" && k == sec && substr(stripped, n + 1) ~ /^[[:space:]]*$/)
        if (sec == "" && k == key && !done) { emit(); done = 1; next }
      } else if (indented && insec && k == key && !done) { emit(); done = 1; next }
      print line
    }
    END {
      if (!done) {
        if (sec != "" && insec) emit()
        else if (sec != "") { print sec ":"; emit() }
        else emit()
      }
    }' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- repository and loop layout -----------------------------------------------
ho_toplevel() { git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null; }

ho_main_worktree() {
  local common
  common="$(git -C "${1:-$PWD}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  if [[ "$(basename "$common")" == ".git" ]]; then dirname "$common"; else ho_toplevel "${1:-$PWD}"; fi
}

# Every change directory of a loop, starting with the given one.
ho_loop_dirs() {
  local dir="$1" change loop wt seen="$1"
  change="$(basename "$dir")"; loop="$dir/loop.yaml"
  printf '%s\n' "$dir"
  for k in implementer.worktree reviewer.worktree finish.worktree; do
    wt="$(kv_get "$loop" "$k" 2>/dev/null)" || continue
    [[ -n "$wt" && -d "$wt/.agent-handoff/$change" ]] || continue
    case " $seen " in *" $wt/.agent-handoff/$change "*) continue ;; esac
    seen="$seen $wt/.agent-handoff/$change"
    printf '%s\n' "$wt/.agent-handoff/$change"
  done
}

# Newest record file in one directory, or across the whole loop with "all".
ho_newest_in() {
  local best="" bn=-1 f b n
  for f in "$1"/[0-9][0-9]-*.yaml; do
    [[ -e "$f" ]] || continue
    b="$(basename "$f")"
    [[ "$b" =~ ^([0-9]{2})-(implement|review|finish)\.yaml$ ]] || continue
    n=$((10#${BASH_REMATCH[1]}))
    (( n > bn )) && { bn=$n; best="$f"; }
  done
  [[ -n "$best" ]] && printf '%s\n' "$best"
}

ho_newest_in_loop() {
  local dir="$1" best="" bn=-1 d f n
  while IFS= read -r d; do
    f="$(ho_newest_in "$d")" || continue
    n=$((10#$(basename "$f" | cut -c1-2)))
    (( n > bn )) && { bn=$n; best="$f"; }
  done < <(ho_loop_dirs "$dir")
  [[ -n "$best" ]] && printf '%s\n' "$best"
}

ho_has_finish_record() {
  local d
  while IFS= read -r d; do
    compgen -G "$d/[0-9][0-9]-finish.yaml" >/dev/null && return 0
  done < <(ho_loop_dirs "$1")
  return 1
}

ho_clean() { [[ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ]]; }
ho_head() { git -C "$1" rev-parse HEAD 2>/dev/null; }

# Write a key to every copy of loop.yaml that exists for this loop.
# The list is read in full first: writing while ho_loop_dirs still reads loop.yaml would race.
# Fails when any copy could not be written; the others are still updated.
ho_loop_set() {
  local dir="$1" key="$2" value="$3" d dirs rc=0
  dirs="$(ho_loop_dirs "$dir")"
  while IFS= read -r d; do kv_set "$d/loop.yaml" "$key" "$value" || rc=1; done <<<"$dirs"
  return $rc
}

# --- user notification and logging -------------------------------------------
HANDOFF_NOTIFY_CAPABILITY="# ai-notify-capability: handoff-events"

# ho_notify <context-json> <kind> <verdict> <next> <detail>
# kind: implement, review, finish (progress) or attention (the loop waits for the user).
# A notifier that declares handoff events gets the structured event and applies its own
# switches; an older one gets attention as the previous generic notice and no progress.
# No notifier installed: nothing is sent. Failures never reach the caller.
ho_notify() {
  local ctx="$1" kind="$2" verdict="$3" next="$4" detail="$5"
  [[ -f "$HANDOFF_NOTIFY" ]] || return 0
  if grep -qxF "$HANDOFF_NOTIFY_CAPABILITY" "$HANDOFF_NOTIFY" 2>/dev/null; then
    jq -c --arg k "$kind" --arg v "$verdict" --arg n "$next" --arg d "$detail" \
      '. + {kind:$k, verdict:$v, next:$n, detail:$d}' <<<"$ctx" \
      | bash "$HANDOFF_NOTIFY" handoff 2>/dev/null || true
  elif [[ "$kind" == attention ]]; then
    jq -c --arg n "$next" --arg d "$detail" \
      '{hook_event_name:"Notification", message:("[\(.change)] \($d) \($n)"), cwd:.cwd}' <<<"$ctx" \
      | NOTIFY_ACTION_REQUIRED=true bash "$HANDOFF_NOTIFY" notification "Agent Handoff" 2>/dev/null || true
  fi
  return 0
}

ho_log() {
  local dir="$1"; shift
  printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" >> "$dir/routing.log" 2>/dev/null || true
}

# --- Xirp ----------------------------------------------------------------------
ho_xirp_session() { [[ -n "$1" ]] && xirp session get "$1" --json 2>/dev/null; }

# ho_agent_label <session-json>: "<tool> / <model> / <effort>", leaving out what Xirp does not report.
ho_agent_label() {
  jq -r '[(.currentAgent // "" | if . == "claude" then "Claude" elif . == "codex" then "Codex" else . end),
          (.model // ""),
          (.agentLaunchOptions.options.effort // .agentLaunchOptions.options.reasoning_effort // "")]
         | map(select(type == "string" and . != "")) | join(" / ")' <<<"$1" 2>/dev/null
}

ho_xirp_exists() { xirp session get "$1" --json >/dev/null 2>&1; }

ho_xirp_message() { xirp session message "$1" "$2" >/dev/null 2>&1; }

ho_xirp_project_id() {
  local path="$1"
  xirp project list --json 2>/dev/null | jq -r --arg p "$path" '[.[] | select(.path == $p)][0].id // empty' 2>/dev/null
}

# ho_xirp_listed <id>: 0 when Xirp lists the session, 1 when it answers with a readable list without it, 2 when
# it cannot answer or the answer is not exactly one list of sessions with string IDs (then absence is not proven).
ho_xirp_listed() {
  local out r
  out="$(xirp session list --json 2>/dev/null)" || return 2
  # Slurped, so trailing or truncated output fails the whole parse instead of yielding an answer first.
  r="$(jq -rs --arg id "$1" 'if length != 1 then "unknown" else .[0]
    | (if type == "array" then . elif type == "object" and (.sessions | type) == "array" then .sessions else null end)
    | if type == "array" and all(.[]; type == "object" and (.id | type) == "string")
      then (if any(.[]; .id == $id) then "listed" else "absent" end) else "unknown" end end' <<<"$out" 2>/dev/null)" || return 2
  case "$r" in listed) return 0 ;; absent) return 1 ;; *) return 2 ;; esac
}

ho_xirp_ids_named() {
  xirp session list --search "$1" --json 2>/dev/null \
    | jq -r --arg n "$1" '(if type == "array" then . else (.sessions // []) end)[] | select((.name // "") == $n) | .id' 2>/dev/null
}

# ho_xirp_create <project-id> <worktree> <harness> <model> <effort> <name> <prompt> [codex-profile] [pi-provider] -> session id
ho_xirp_create() {
  local project="$1" wt="$2" harness="$3" model="$4" effort="$5" name="$6" prompt="$7" profile="${8:-}" provider="${9:-}"
  local effort_key before json id waited=0
  case "$harness" in
    claude) effort_key="effort" ;;
    codex) effort_key="reasoning_effort" ;;
    pi) effort_key="thinking" ;;
    *) ho_err "unsupported harness: $harness"; return 1 ;;
  esac
  before="$(ho_xirp_ids_named "$name")"
  json="$(jq -n --arg p "$project" --arg w "$wt" --arg n "$name" --arg g "$prompt" --arg h "$harness" \
    --arg m "$model" --arg ek "$effort_key" --arg e "$effort" --arg pr "$profile" --arg pv "$provider" \
    '{projectId:$p, worktreePath:$w, customName:$n, goal:$g, background:true,
      agent:{agentName:$h, options:({model:$m} + {($ek):$e} + (if $pr == "" then {} else {profile:$pr} end)
                                     + (if $pv == "" then {} else {provider:$pv} end))}}')"
  xirp api send session:create --json "$json" >/dev/null 2>&1 || { ho_err "xirp session:create failed"; return 1; }
  while :; do
    id="$(ho_xirp_ids_named "$name" | while IFS= read -r x; do grep -qxF "$x" <<<"$before" || { printf '%s\n' "$x"; break; }; done)"
    [[ -n "$id" ]] && { printf '%s\n' "$id"; return 0; }
    (( waited >= HANDOFF_CREATE_WAIT )) && { ho_err "session '$name' did not appear"; return 1; }
    sleep 1; waited=$((waited + 1))
  done
}

# --- session hosts -----------------------------------------------------------------
# A role runs on a host (design D1, D2). loop.yaml records it as <template>.host; a loop.yaml
# without one is an xirp loop. Each host implements four actions; callers never call a host directly.
ho_role_tsec() { case "$1" in implementer) echo implement_template ;; reviewer) echo review_template ;; finish) echo finish_template ;; esac; }
ho_role_host() { ho_sec_host "$1" "$(ho_role_tsec "$2")"; }
HANDOFF_HOSTS="xirp herdr"

# ho_sec_host <file> <section>: the section's host, else the file's top-level host, else xirp.
ho_sec_host() {
  local h
  h="$(kv_get "$1" "$2.host" 2>/dev/null)"; [[ -n "$h" ]] || h="$(kv_get "$1" host 2>/dev/null)"
  printf '%s\n' "${h:-xirp}"
}

# ho_herdr_session_choice <roles-file>: inside a herdr pane its session, else herdr_session, else default.
ho_herdr_session_choice() {
  local s=""
  [[ "${HERDR_ENV:-}" == 1 ]] && s="${HERDR_SESSION:-}"
  [[ -n "$s" ]] || s="$(kv_get "$1" herdr_session 2>/dev/null)"
  printf '%s\n' "${s:-default}"
}

# ho_host_open <host> <loop-dir> <role> <worktree> <name> <prompt> <template-file> <section>: prints the session id.
ho_host_open() {
  local host="$1" wt="$4" name="$5" prompt="$6" tf="$7" sec="$8" main project
  case "$host" in
    xirp)
      main="$(ho_main_worktree "$wt")"; project="$(ho_xirp_project_id "$main")"
      [[ -n "$project" ]] || { ho_err "no Xirp project registered for $main"; return 1; }
      ho_xirp_create "$project" "$wt" "$(kv_get "$tf" "$sec.harness")" "$(kv_get "$tf" "$sec.model")" "$(kv_get "$tf" "$sec.effort")" \
        "$name" "$prompt" "$(kv_get "$tf" "$sec.profile" 2>/dev/null || true)" "$(kv_get "$tf" "$sec.provider" 2>/dev/null || true)" ;;
    herdr) ho_herdr_open "$2" "$3" "$wt" "$name" "$prompt" "$tf" "$sec" ;;
    *) ho_err "unknown host: $host"; return 1 ;;
  esac
}

# ho_host_message <host> <loop-dir> <role> <session> <text>
ho_host_message() {
  case "$1" in
    xirp) ho_xirp_message "$4" "$5" ;;
    herdr) ho_herdr_message "$2" "$3" "$4" "$5" ;;
    *) return 1 ;;
  esac
}

# ho_host_exists <host> <loop-dir> <role> <session>
ho_host_exists() {
  case "$1" in
    xirp) ho_xirp_exists "$4" ;;
    herdr) ho_herdr_exists "$2" "$3" "$4" ;;
    *) return 1 ;;
  esac
}

# ho_host_close <host> <loop-dir> <role> <session>: delete or close what the loop opened for the role.
ho_host_close() {
  case "$1" in
    xirp) xirp session delete "$4" --yes >/dev/null 2>&1 ;;
    herdr) ho_herdr_close "$2" "$3" ;;
    *) return 1 ;;
  esac
}

# ho_role_close <host> <loop-dir> <role> <session> <harness>: end one role's session for handoff-role. Succeeds
# only when the host deleted or closed it, or confirms it is gone; anything it cannot confirm fails (stderr says why).
ho_role_close() {
  local rc
  case "$1" in
    xirp)
      xirp session delete "$4" --yes >/dev/null 2>&1 && return 0
      ho_xirp_listed "$4"; rc=$?
      (( rc == 1 )) && return 0
      if (( rc == 0 )); then ho_err "Xirp did not delete session $4 and still lists it"
      else ho_err "Xirp did not delete session $4 and could not say whether it still exists"; fi
      return 1 ;;
    herdr) ho_herdr_close_role "$2" "$3" "$4" "$5" ;;
    *) ho_err "unknown host: $1"; return 1 ;;
  esac
}

# --- herdr host (design D3–D6) ---------------------------------------------------------
# A herdr role is identified by its pane ID (<role>.session) and, once herdr reports it, the agent's
# native session ID (<role>.native_session). Every call names the role's herdr session explicitly.
HANDOFF_NATIVE_WAIT="${HANDOFF_NATIVE_WAIT:-5}"

# ho_herdr <session> <args...>: herdr's JSON answer (stdout on success, stderr on error) and its status.
ho_herdr() { local s="$1"; shift; herdr --session "$s" "$@" </dev/null 2>&1; }
ho_herdr_code() { jq -r '.error.code // empty' <<<"$1" 2>/dev/null; }
# ho_herdr_prompt <session> <pane> <text>: submit and wait only until the agent starts working (or stops
# at a dialog), not for the whole turn. An agent that was still starting can swallow the Enter and leave
# the text in its composer (herdr answers agent_prompt_stalled): Enter is sent once more, never the text.
# Returns 0 when the agent took it, 1 when herdr says nothing was sent, 2 when the result is unknown
# (a timeout, or still no activity after the extra Enter): such a prompt may have arrived and is never
# sent again. Sets HO_HERDR_CODE.
HANDOFF_SUBMIT_TIMEOUT_MS="${HANDOFF_SUBMIT_TIMEOUT_MS:-15000}"
ho_herdr_prompt() {
  local out rc until=(--until working --until blocked --timeout "$HANDOFF_SUBMIT_TIMEOUT_MS")
  out="$(ho_herdr "$1" agent prompt "$2" "$3" --wait "${until[@]}")"; rc=$?; HO_HERDR_CODE=""
  (( rc == 0 )) && return 0
  HO_HERDR_CODE="$(ho_herdr_code "$out")"
  case "$HO_HERDR_CODE" in agent_blocked|agent_not_found|pane_not_found|server_not_running) return 1 ;; esac
  (( rc == 2 )) && { HO_HERDR_CODE="usage error"; return 1; }  # a command-line error sends nothing
  if [[ "$HO_HERDR_CODE" == agent_prompt_stalled ]]; then
    ho_herdr "$1" agent send-keys "$2" enter >/dev/null \
      && ho_herdr "$1" agent wait "$2" "${until[@]}" >/dev/null && { HO_HERDR_CODE=""; return 0; }
    HO_HERDR_CODE="agent_prompt_stalled, still idle after one more Enter"
  fi
  return 2
}

# ho_herdr_unconfirmed <loop-dir> <role> <pane> <text>: keep a prompt herdr did not confirm in a file the
# user can check against the pane, and say where it is. While the file exists the role gets no prompt
# and is never taken as started (ho_herdr_held): the user checks the pane, pastes the text if it is
# missing, and deletes the file.
ho_herdr_unconfirmed() {
  local f="$1/$2-unconfirmed.txt"
  printf '%s\n' "$4" > "$f"
  ho_err "herdr did not confirm the prompt to pane $3 (${HO_HERDR_CODE:-no answer}); it may have arrived, so it is not sent again. Check that pane, paste the text from $f if it is missing, then delete $f"
}

# ho_herdr_held <loop-dir> <role>: a prompt to the role still waits for the user's check; prints the file.
ho_herdr_held() {
  local d dirs
  dirs="$(ho_loop_dirs "$1")"
  while IFS= read -r d; do [[ -f "$d/$2-unconfirmed.txt" ]] && { printf '%s\n' "$d/$2-unconfirmed.txt"; return 0; }; done <<<"$dirs"
  return 1
}

# ho_herdr_hold_error <loop-dir> <role> <pane>: refuse while ho_herdr_held; fails (status 1) only then.
ho_herdr_hold_error() {
  local f; f="$(ho_herdr_held "$1" "$2")" || return 0
  ho_err "herdr did not confirm an earlier prompt to the $2 (pane $3); nothing is sent until you check that pane, paste the text from $f if it is missing, and delete $f"
  return 1
}

ho_herdr_session_of() { local s; s="$(kv_get "$1/loop.yaml" "$2.herdr_session" 2>/dev/null)"; printf '%s\n' "${s:-default}"; }

# ho_herdr_main_ws <session> <main-worktree>: the repository's workspace, opened when herdr has none.
ho_herdr_main_ws() {
  local hs="$1" main="$2" phys out id
  phys="$(cd "$main" && pwd -P)"
  out="$(ho_herdr "$hs" workspace list)" || { ho_err "herdr workspace list failed: $(ho_herdr_code "$out")"; return 1; }
  id="$(jq -r --arg a "$main" --arg b "$phys" \
    '[.result.workspaces[] | select(.worktree.checkout_path == $a or .worktree.checkout_path == $b)][0].workspace_id // empty' <<<"$out")"
  if [[ -z "$id" ]]; then
    out="$(ho_herdr "$hs" workspace create --cwd "$main" --label "$(basename "$main")" --no-focus)" \
      || { ho_err "herdr could not open a workspace for $main: $(ho_herdr_code "$out")"; return 1; }
    id="$(jq -r '.result.workspace.workspace_id' <<<"$out")"
  fi
  printf '%s\n' "$id"
}

# ho_herdr_place <loop-dir> <role> <session> <worktree> <name>: a pane for the role, in its own tab named
# <name>, under the repository workspace (design D3). Records the pane, the tab and any workspace it opened.
ho_herdr_place() {
  local dir="$1" role="$2" hs="$3" wt="$4" name="$5" main mws out ws tab pane label cur
  main="$(ho_main_worktree "$wt")"; mws="$(ho_herdr_main_ws "$hs" "$main")" || return 1
  if [[ "$(cd "$wt" && pwd -P)" == "$(cd "$main" && pwd -P)" ]]; then
    out="$(ho_herdr "$hs" tab create --workspace "$mws" --cwd "$wt" --label "$name" --no-focus)" \
      || { ho_err "herdr could not open a tab in $mws: $(ho_herdr_code "$out")"; return 1; }
  else
    # --label also renames an open workspace, so a role sharing the implementer's worktree keeps its label.
    label="$(kv_get "$dir/loop.yaml" change)"
    [[ "$wt" == "$(kv_get "$dir/loop.yaml" implementer.worktree 2>/dev/null)" ]] || label="$label $role"
    out="$(ho_herdr "$hs" worktree open --workspace "$mws" --path "$wt" --label "$label" --no-focus)" \
      || { ho_err "herdr could not open a workspace for $wt: $(ho_herdr_code "$out")"; return 1; }
    ws="$(jq -r '.result.workspace.workspace_id' <<<"$out")"
    if [[ "$(jq -r '.result.already_open' <<<"$out")" == false ]]; then
      # A workspace this loop opened: its root pane holds the first role, and cleanup closes it.
      cur="$(kv_get "$dir/loop.yaml" herdr.workspaces 2>/dev/null)"
      ho_loop_set "$dir" herdr.workspaces "${cur:+$cur }$ws" || return 1
      ho_herdr "$hs" tab rename "$(jq -r '.result.tab.tab_id' <<<"$out")" "$name" >/dev/null
    else
      out="$(ho_herdr "$hs" tab create --workspace "$ws" --cwd "$wt" --label "$name" --no-focus)" \
        || { ho_err "herdr could not open a tab in $ws: $(ho_herdr_code "$out")"; return 1; }
    fi
  fi
  tab="$(jq -r '.result.tab.tab_id' <<<"$out")"; pane="$(jq -r '.result.root_pane.pane_id' <<<"$out")"
  ho_loop_set "$dir" "$role.herdr_tab" "$tab" && ho_loop_set "$dir" "$role.session" "$pane" || return 1
  printf '%s\n' "$pane"
}

# ho_herdr_agent_get <session> <pane> <harness>: the agent JSON when the pane runs that harness.
ho_herdr_agent_get() {
  local out
  out="$(ho_herdr "$1" agent get "$2")" || return 1
  [[ "$(jq -r '.result.agent.agent // empty' <<<"$out")" == "$3" ]] || return 1
  printf '%s\n' "$out"
}

# ho_herdr_dialog <loop-dir> <role> <pane>: where the user finds a role that waits on a dialog.
# Asks herdr where the pane is now, so a reused pane the loop did not open is named correctly too.
ho_herdr_dialog() {
  local hs tab ws tl wl
  hs="$(ho_herdr_session_of "$1" "$2")"
  tab="$(ho_herdr "$hs" pane get "$3" | jq -r '.result.pane.tab_id // empty' 2>/dev/null)"
  [[ -n "$tab" ]] || tab="$(kv_get "$1/loop.yaml" "$2.herdr_tab" 2>/dev/null)"
  ws="${tab%%:*}"
  tl="$(ho_herdr "$hs" tab get "$tab" | jq -r '.result.tab.label // empty' 2>/dev/null)"
  wl="$(ho_herdr "$hs" workspace get "$ws" | jq -r '.result.workspace.label // empty' 2>/dev/null)"
  printf '%s waits on a dialog in herdr workspace %s%s, tab %s%s, pane %s; answer it there' \
    "$2" "${ws:-unknown}" "${wl:+ (\"$wl\")}" "${tab:-unknown}" "${tl:+ (\"$tl\")}" "$3"
}

# ho_role_pending <loop-dir> <role>: an earlier open left the role's pane waiting for its first prompt.
ho_role_pending() { [[ "$(kv_get "$1/loop.yaml" "$2.pending_prompt" 2>/dev/null)" == true ]]; }

# ho_herdr_open <loop-dir> <role> <worktree> <name> <prompt> <template-file> <section>: start the
# template's agent in the role's pane, then send the prompt (design D4). A pane left by an attempt that
# stopped at a dialog (<role>.pending_prompt) is reused: only what is missing is done again (D5).
ho_herdr_open() {
  local dir="$1" role="$2" wt="$3" name="$4" prompt="$5" tf="$6" sec="$7" loop="$1/loop.yaml"
  local hs h m e pane out code aname waited=0 native fresh=0 args=()
  hs="$(ho_herdr_session_of "$dir" "$role")"
  h="$(kv_get "$tf" "$sec.harness")"; m="$(kv_get "$tf" "$sec.model")"; e="$(kv_get "$tf" "$sec.effort")"
  pane="$(kv_get "$loop" "$role.session" 2>/dev/null)"
  ho_herdr_hold_error "$dir" "$role" "$pane" || return 1
  if [[ -z "$pane" || "$(kv_get "$loop" "$role.pending_prompt" 2>/dev/null)" != true ]]; then
    pane="$(ho_herdr_place "$dir" "$role" "$hs" "$wt" "$name")" || return 1
    ho_loop_set "$dir" "$role.pending_prompt" true; fresh=1
  fi
  if (( fresh )) || ! ho_herdr_agent_get "$hs" "$pane" "$h" >/dev/null; then
    case "$h" in
      claude) args=(--model "$m" --effort "$e" --name "$name") ;;
      codex) args=(-m "$m" -c "model_reasoning_effort=$e")
        [[ -z "$(kv_get "$tf" "$sec.profile" 2>/dev/null)" ]] || args+=(-p "$(kv_get "$tf" "$sec.profile")") ;;
      pi) args=(--provider "$(kv_get "$tf" "$sec.provider")" --model "$m" --thinking "$e") ;;
      *) ho_err "unsupported harness: $h"; return 1 ;;
    esac
    # herdr agent names must match [a-z][a-z0-9_-]{0,31}; they are labels only, the pane identifies the role.
    case "$role" in implementer) aname=impl ;; reviewer) aname=review ;; *) aname="$role" ;; esac
    aname="$aname-$(printf '%s' "$pane$$$RANDOM" | shasum | cut -c1-6)"
    until out="$(ho_herdr "$hs" agent start "$aname" --kind "$h" --pane "$pane" -- "${args[@]}")"; do
      code="$(ho_herdr_code "$out")"
      if [[ "$code" == agent_pane_busy ]] && (( waited < HANDOFF_CREATE_WAIT )); then sleep 1; waited=$((waited + 1)); continue; fi
      if [[ "$code" == agent_not_ready ]]; then ho_err "$(ho_herdr_dialog "$dir" "$role" "$pane")"
      else ho_err "herdr agent start failed in pane $pane: ${code:-no answer}"; fi
      return 1
    done
  fi
  ho_herdr_prompt "$hs" "$pane" "$prompt"; code=$?
  if (( code == 1 )); then
    if [[ "$HO_HERDR_CODE" == agent_blocked ]]; then ho_err "$(ho_herdr_dialog "$dir" "$role" "$pane")"
    else ho_err "herdr agent prompt failed in pane $pane: $HO_HERDR_CODE"; fi
    return 1
  fi
  ho_loop_set "$dir" "$role.pending_prompt" ""
  (( code == 2 )) && { ho_herdr_unconfirmed "$dir" "$role" "$pane" "$prompt"; return 2; }
  # The native session ID arrives through herdr's integration hook, a little later (design D4 step 5).
  for ((waited = 0; waited <= HANDOFF_NATIVE_WAIT; waited++)); do
    native="$(ho_herdr "$hs" agent get "$pane" | jq -r '.result.agent.agent_session.value // empty' 2>/dev/null)"
    [[ -n "$native" ]] && { ho_loop_set "$dir" "$role.native_session" "$native"; break; }
    (( waited < HANDOFF_NATIVE_WAIT )) && sleep 1
  done
  printf '%s\n' "$pane"
}

# ho_herdr_exists <loop-dir> <role> <pane>: the pane still runs the role's agent (design D6): the same
# harness and, when recorded, the same native session. A native ID first seen here is recorded.
ho_herdr_exists() {
  local dir="$1" role="$2" pane="$3" hs json have want
  hs="$(ho_herdr_session_of "$dir" "$role")"
  json="$(ho_herdr_agent_get "$hs" "$pane" "$(kv_get "$dir/loop.yaml" "$(ho_role_tsec "$role").harness" 2>/dev/null)")" || return 1
  have="$(jq -r '.result.agent.agent_session.value // empty' <<<"$json")"
  want="$(kv_get "$dir/loop.yaml" "$role.native_session" 2>/dev/null)"
  if [[ -n "$want" ]]; then [[ "$have" == "$want" ]] || return 1
  elif [[ -n "$have" ]]; then ho_loop_set "$dir" "$role.native_session" "$have"; fi
  return 0
}

# ho_herdr_message <loop-dir> <role> <pane> <text>: submit only to the role's own agent. Returns 1 when
# nothing was sent (retried later) and 2 when herdr did not confirm the submission (never resent).
ho_herdr_message() {
  local rc
  ho_herdr_hold_error "$1" "$2" "$3" || return 1
  if ! ho_herdr_exists "$1" "$2" "$3"; then
    ho_err "herdr pane $3 no longer runs the $2's agent (tab $(kv_get "$1/loop.yaml" "$2.herdr_tab" 2>/dev/null)); nothing was sent"; return 1
  fi
  ho_herdr_prompt "$(ho_herdr_session_of "$1" "$2")" "$3" "$4"; rc=$?
  case "$rc" in
    0) return 0 ;;
    1) if [[ "$HO_HERDR_CODE" == agent_blocked ]]; then ho_err "$(ho_herdr_dialog "$1" "$2" "$3")"
       else ho_err "herdr agent prompt failed in pane $3: $HO_HERDR_CODE"; fi
       return 1 ;;
    *) ho_herdr_unconfirmed "$1" "$2" "$3" "$4"; return 2 ;;
  esac
}

# ho_herdr_close_target <loop-dir> <role>: what cleanup closes for a herdr role (design D3): the workspace
# when this loop opened it, otherwise only the role's tab. Prints "workspace <id>" or "tab <id>".
ho_herdr_close_target() {
  local tab ws
  tab="$(kv_get "$1/loop.yaml" "$2.herdr_tab" 2>/dev/null)"; [[ -n "$tab" ]] || return 1
  ws="${tab%%:*}"
  if [[ " $(kv_get "$1/loop.yaml" herdr.workspaces 2>/dev/null) " == *" $ws "* ]]; then printf 'workspace %s\n' "$ws"
  else printf 'tab %s\n' "$tab"; fi
}

# ho_herdr_close <loop-dir> <role>: close that target; closing it ends the agents in it. Succeeds only
# when herdr confirms the close or reports the target gone (closed earlier), so cleanup can stop otherwise.
ho_herdr_close() {
  local t out code
  t="$(ho_herdr_close_target "$1" "$2")" || return 0
  out="$(ho_herdr "$(ho_herdr_session_of "$1" "$2")" "${t% *}" close "${t#* }")" && return 0
  code="$(ho_herdr_code "$out")"
  [[ "$code" == "${t% *}_not_found" ]] && return 0
  ho_err "herdr could not close $t: ${code:-no answer}"; return 1
}

# ho_herdr_close_role <loop-dir> <role> <pane> <harness>: close only the role's own tab, the one the loop opened,
# and only while its pane still runs the role's agent (same harness and, when recorded, native session) or no
# agent. Another workspace's roles are left alone. A pane herdr reports gone needs nothing.
ho_herdr_close_role() {
  local dir="$1" role="$2" pane="$3" h="$4" hs tab out code have want
  hs="$(ho_herdr_session_of "$dir" "$role")"
  if ! out="$(ho_herdr "$hs" pane get "$pane")"; then
    code="$(ho_herdr_code "$out")"; [[ "$code" == pane_not_found ]] && return 0
    ho_err "herdr could not say where pane $pane is (${code:-no answer}); nothing was closed"; return 1
  fi
  tab="$(kv_get "$dir/loop.yaml" "$role.herdr_tab" 2>/dev/null)"
  if [[ -z "$tab" || "$(jq -r '.result.pane.tab_id // empty' <<<"$out")" != "$tab" ]]; then
    ho_err "pane $pane is not in a tab the loop opened for the $role (recorded tab: ${tab:-none}); nothing was closed. Stop or close it yourself, then run this again"
    return 1
  fi
  if out="$(ho_herdr "$hs" agent get "$pane")"; then
    have="$(jq -r '.result.agent.agent // empty' <<<"$out")"
    [[ "$have" == "$h" ]] || { ho_err "pane $pane now runs ${have:-an unknown agent}, not the $role's $h; nothing was closed"; return 1; }
    want="$(kv_get "$dir/loop.yaml" "$role.native_session" 2>/dev/null)"; have="$(jq -r '.result.agent.agent_session.value // empty' <<<"$out")"
    [[ -z "$want" || "$have" == "$want" ]] \
      || { ho_err "pane $pane runs native session ${have:-unknown}, not the $role's $want; nothing was closed"; return 1; }
  elif [[ "$(ho_herdr_code "$out")" != agent_not_found ]]; then
    ho_err "herdr could not say what pane $pane runs ($(ho_herdr_code "$out")); nothing was closed"; return 1
  fi
  out="$(ho_herdr "$hs" tab close "$tab")" && return 0
  code="$(ho_herdr_code "$out")"; [[ "$code" == tab_not_found ]] && return 0
  ho_err "herdr could not close tab $tab: ${code:-no answer}"; return 1
}

# --- templates -------------------------------------------------------------------
# ho_author <harness> <model>: tells a role to append handoff-author's output as its Author.
# The model comes from the template (agents cannot query Xirp from a sandbox); the script copies
# both session IDs from the agent's environment, so no model retypes them.
ho_author() {
  local tool
  case "$1" in claude) tool="'Claude Code'" ;; codex) tool="Codex" ;; pi) tool="Pi" ;; *) tool="$1" ;; esac
  printf 'Author 區塊（GitHub 回覆、報告，或交給專用 Agent 的 author_file）一律用 %s/handoff-author --tool %s --model %s 產生，' \
    "$(dirname "$HANDOFF_WRITE_REL")" "$tool" "$2"
  printf '把輸出原樣附加在 ## Author 標題下（例如 >> body.md），不要手抄或改寫 Session ID。'
}

# ho_render <text> <change> <head> <round> <report> <delivery> [harness model]
ho_render() {
  local text="$1" change="$2" head="$3" round="$4" report="$5" delivery="$6"
  [[ $# -ge 8 ]] && text="${text//\{author\}/$(ho_author "$7" "$8")}"
  text="${text//\{change\}/$change}"; text="${text//\{head\}/$head}"; text="${text//\{round\}/$round}"
  text="${text//\{report\}/$report}"; text="${text//\{delivery\}/$delivery}"
  text="${text//\{handoff_write\}/$HANDOFF_WRITE_REL}"
  printf '%s' "$text"
}

# ho_template_check <file> <section>: every role needs these fields and a supported harness.
ho_template_check() {
  local file="$1" sec="$2" k v h missing=""
  h="$(kv_get "$file" "$sec.harness" 2>/dev/null)"
  for k in harness model effort name prompt $([[ "$h" == pi ]] && echo provider billing); do
    v="$(kv_get "$file" "$sec.$k" 2>/dev/null)"
    [[ -n "$v" ]] || missing="$missing $k"
  done
  [[ -z "$missing" ]] || { ho_err "$sec template is missing:$missing"; return 1; }
  [[ "$h" == claude || "$h" == codex || "$h" == pi ]] || { ho_err "$sec template harness must be claude, codex or pi, got '$h'"; return 1; }
  v="$(ho_sec_host "$file" "$sec")"
  case "$v" in xirp|herdr) ;; *) ho_err "$sec host must be xirp or herdr, got '$v'"; return 1 ;; esac
  if [[ "$h" == pi ]]; then
    v="$(kv_get "$file" "$sec.billing")"
    [[ "$v" == subscription || "$v" == api ]] || { ho_err "$sec template billing must be subscription or api, got '$v'"; return 1; }
    v="$(kv_get "$file" "$sec.effort")"
    [[ " $HANDOFF_PI_EFFORTS " == *" $v "* ]] || { ho_err "$sec template effort must be one of ${HANDOFF_PI_EFFORTS// /, } for Pi, got '$v'"; return 1; }
    v="$(kv_get "$file" "$sec.model")"
    [[ "$v" != */* ]] || { ho_err "$sec template model must be the model ID without a provider/ prefix, got '$v'"; return 1; }
  else
    for k in provider billing; do
      [[ -z "$(kv_get "$file" "$sec.$k" 2>/dev/null || true)" ]] || { ho_err "$sec template sets $k, which only Pi supports"; return 1; }
    done
  fi
  # profile selects a Codex configuration profile (~/.codex/<profile>.config.toml).
  if [[ -n "$(kv_get "$file" "$sec.profile" 2>/dev/null || true)" && "$(kv_get "$file" "$sec.harness")" != codex ]]; then
    ho_err "$sec template sets profile, which only Codex supports"; return 1
  fi
  if [[ "$sec" == review* || "$sec" == finish* ]]; then
    v="$(kv_get "$file" "$sec.worktree" 2>/dev/null || true)"
    [[ -z "$v" || "$v" == shared || "$v" == new ]] || { ho_err "$sec worktree must be shared or new, got '$v'"; return 1; }
  fi
  return 0
}

# Copy one role template from a roles file into loop.yaml under <dest-section>.
ho_copy_template() {
  local src="$1" sec="$2" loop="$3" dest="$4" k v
  for k in worktree harness model effort name prompt profile provider billing; do
    v="$(kv_get "$src" "$sec.$k" 2>/dev/null)" || continue
    [[ "$k" == worktree && -z "$v" ]] && v=shared
    [[ ( "$k" == provider || "$k" == billing ) && -z "$v" ]] && continue
    kv_set "$loop" "$dest.$k" "\"$v\""
  done
  if [[ "$sec" == review || "$sec" == finish ]] && ! kv_get "$loop" "$dest.worktree" >/dev/null 2>&1; then
    kv_set "$loop" "$dest.worktree" shared
  fi
}

# ho_retool <old-tool> <new-tool> <name|prompt> <text>: a session name that starts with "<old-tool> - "
# and a prompt that starts with a skill call (/x Claude Code, $x Codex, /skill:x Pi) follow the new tool.
ho_retool() {
  local old="$1" new="$2" kind="$3" text="$4" skill=""
  if [[ "$kind" == name ]]; then
    [[ "$text" == "$old - "* ]] && text="$new - ${text#"$old - "}"
    printf '%s' "$text"; return 0
  fi
  case "$text" in
    /skill:*) skill="${text#/skill:}" ;;
    \$*) skill="${text#\$}" ;;
    /*) skill="${text#/}" ;;
  esac
  if [[ "$skill" =~ ^[a-z0-9] ]]; then
    case "$new" in claude) text="/$skill" ;; codex) text="\$$skill" ;; pi) text="/skill:$skill" ;; esac
  fi
  printf '%s' "$text"
}

# ho_apply_override <file> <section> <override>: set a role's tool, model, effort, provider and billing from
# claude|codex:<model>:<effort> or pi:<provider>/<model>:<effort>:<billing> (the caller checks the form).
# Fails when the file could not be written.
ho_apply_override() {
  local file="$1" sec="$2" ov="$3" h m e b="" p="" old k v
  IFS=: read -r h m e b <<<"$ov"
  if [[ "$h" == pi ]]; then p="${m%%/*}"; m="${m#*/}"; else b=""; fi
  old="$(kv_get "$file" "$sec.harness" 2>/dev/null || true)"
  kv_set "$file" "$sec.harness" "\"$h\"" && kv_set "$file" "$sec.model" "\"$m\"" && kv_set "$file" "$sec.effort" "\"$e\"" \
    && kv_set "$file" "$sec.provider" "${p:+\"$p\"}" && kv_set "$file" "$sec.billing" "${b:+\"$b\"}" || return 1
  [[ -n "$old" && "$old" != "$h" ]] || return 0
  for k in name prompt; do
    v="$(kv_get "$file" "$sec.$k" 2>/dev/null)" || continue
    kv_set "$file" "$sec.$k" "\"$(ho_retool "$old" "$h" "$k" "$v")\"" || return 1
  done
}

# Open a role session from the template stored in loop.yaml. Prints the session id.
ho_open_role() {
  local dir="$1" tsec="$2" wt="$3" head="$4" round="$5" report="$6"
  local loop="$dir/loop.yaml" change main name prompt delivery role
  change="$(kv_get "$loop" change)"
  delivery="$(kv_get "$loop" finish.delivery 2>/dev/null || echo local)"
  main="$(ho_main_worktree "$wt")"
  role="$(ho_pi_role_key "$tsec")"
  if [[ "$(kv_get "$loop" "$tsec.harness")" == pi ]]; then
    ho_pi_ready "$loop" "$tsec" "${tsec%_template}" "$main" || return 1
    ho_pi_worktree_ready "$wt" "$main" \
      || { ho_err "${tsec%_template}: the Pi trigger would not trust $wt (its loop.yaml does not list it); not opened"; return 1; }
    local existed=0; [[ -e "$wt/.pi/settings.json" ]] && existed=1
    ho_pi_settings "$wt" "$(kv_get "$loop" "$tsec.provider")" "$(kv_get "$loop" "$tsec.model")" "$(kv_get "$loop" "$tsec.effort")" || return 1
    (( existed )) || ho_loop_set "$dir" "$(ho_pi_role_key "$tsec").pi_settings" "$wt/.pi/settings.json"
  fi
  name="$(ho_render "$(kv_get "$loop" "$tsec.name")" "$change" "$head" "$round" "$report" "$delivery")"
  prompt="$(ho_render "$(kv_get "$loop" "$tsec.prompt")" "$change" "$head" "$round" "$report" "$delivery" \
    "$(kv_get "$loop" "$tsec.harness")" "$(kv_get "$loop" "$tsec.model")")"
  ho_host_open "$(ho_role_host "$loop" "$role")" "$dir" "$role" "$wt" "$name" "$prompt" "$loop" "$tsec"
}

# --- Pi roles ------------------------------------------------------------------------
# A Pi role declares provider and billing; every check below fails closed (design decisions 1, 2, 8).
HANDOFF_PI_EFFORTS="off minimal low medium high xhigh max"
ho_pi_extension() { printf '%s\n' "$HOME/.pi/agent/extensions/wk-handoff.ts"; }

# ho_pi_auth_fields <json>: "<status> <authType>" from exactly one JSON object, or fail.
ho_pi_auth_fields() {
  jq -rs 'if length == 1 and (.[0] | type) == "object" then "\(.[0].status // "") \(.[0].authType // "")"
          else error("not one JSON object") end' <<<"$1" 2>/dev/null
}

# ho_pi_billing <authType>: the billing a credential type stands for, or nothing.
ho_pi_billing() { case "$1" in oauth) echo subscription ;; api_key) echo api ;; esac; }

# ho_pi_verify <role> <provider> <model> <effort> <billing> [warn]
# The model must be listed under exactly this provider, support thinking unless effort is off, and the
# provider's credential must be ready with the declared billing. Never prints credential values.
ho_pi_verify() {
  local role="$1" provider="$2" model="$3" effort="$4" billing="$5" warn="${6:-}" list thinking json fields status auth actual
  command -v pi >/dev/null 2>&1 || { ho_err "$role: the pi command was not found, so $provider/$model cannot be verified"; return 1; }
  list="$(pi --list-models "$model" </dev/null 2>/dev/null)" || { ho_err "$role: pi --list-models $model failed"; return 1; }
  thinking="$(awk -v p="$provider" -v m="$model" 'NR > 1 && $1 == p && $2 == m { print $5; found = 1; exit } END { exit !found }' <<<"$list")" \
    || { ho_err "$role: model '$model' is not listed under provider '$provider' (pi --list-models $model)"; return 1; }
  if [[ "$effort" != off && "$thinking" != yes ]]; then
    ho_err "$role: $provider/$model does not support thinking, but effort is '$effort'"; return 1
  fi
  json="$(pi auth check --provider "$provider" --json </dev/null 2>/dev/null)" \
    || { ho_err "$role: the credential check for $provider failed (pi auth check --provider $provider --json)"; return 1; }
  fields="$(ho_pi_auth_fields "$json")" || { ho_err "$role: the credential check for $provider returned an unreadable answer"; return 1; }
  status="${fields%% *}"; auth="${fields#* }"
  [[ "$status" == ready ]] || { ho_err "$role: the credential for $provider is not ready (status: ${status:-unknown})"; return 1; }
  actual="$(ho_pi_billing "$auth")"
  if [[ "$actual" != "$billing" ]]; then
    ho_err "$role: billing is declared '$billing', but $provider uses a ${auth:-unknown} credential (billing: ${actual:-unknown})"; return 1
  fi
  if [[ "$warn" == warn && "$provider" == anthropic && "$billing" == subscription ]]; then
    ho_err "⚠️  $role: Anthropic subscription use through Pi may consume paid extra usage"
  fi
  return 0
}

# ho_pi_repo_trusted <dir>: the nearest saved Pi trust decision for <dir> or a parent is trust.
ho_pi_repo_trusted() {
  local dir file="$HOME/.pi/agent/trust.json" v
  dir="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  [[ -f "$file" ]] || return 1
  while :; do
    v="$(jq -r --arg d "$dir" 'if has($d) then (.[$d] | tostring) else empty end' "$file" 2>/dev/null)"
    [[ -n "$v" ]] && { [[ "$v" == true ]]; return; }
    [[ "$dir" == / ]] && return 1
    dir="$(dirname "$dir")"
  done
}

# ho_pi_trusts_worktree <dir>: the rule the Pi trigger applies (design decision 8). True only for a
# linked worktree that an untracked .agent-handoff/<change>/loop.yaml there lists as a role worktree,
# in a repository whose main worktree the user trusts in Pi.
ho_pi_trusts_worktree() {
  local top main loop k wt listed=0
  top="$(ho_toplevel "$1")" && top="$(cd "$top" && pwd -P)" || return 1
  main="$(ho_main_worktree "$top")" && main="$(cd "$main" && pwd -P)" || return 1
  [[ "$top" != "$main" ]] || return 1
  for loop in "$top"/.agent-handoff/*/loop.yaml; do
    [[ -f "$loop" && -z "$(git -C "$top" ls-files -- "${loop#"$top"/}" 2>/dev/null)" ]] || continue
    for k in implementer.worktree reviewer.worktree finish.worktree; do
      wt="$(kv_get "$loop" "$k" 2>/dev/null)" || continue
      [[ -n "$wt" && -d "$wt" && "$(cd "$wt" && pwd -P)" == "$top" ]] && listed=1
    done
  done
  (( listed )) && ho_pi_repo_trusted "$main"
}

# ho_pi_worktree_ready <worktree> <main-worktree>: the main worktree is trusted by the user (checked by
# ho_pi_ready); any other worktree must pass the trigger's rule, or the session would wait at Pi's prompt.
ho_pi_worktree_ready() {
  local wt main
  wt="$(cd "$1" 2>/dev/null && pwd -P)" && main="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
  [[ "$wt" == "$main" ]] || ho_pi_trusts_worktree "$wt"
}

# ho_pi_ready <file> <section> <role> <main-worktree> [warn]: everything a Pi role needs before it opens.
ho_pi_ready() {
  local file="$1" sec="$2" role="$3" main="$4"
  [[ -f "$(ho_pi_extension)" ]] || { ho_err "$role: the Pi handoff trigger $(ho_pi_extension) is not installed; run scripts/handoff/install.sh"; return 1; }
  ho_pi_repo_trusted "$main" || { ho_err "$role: Pi does not trust $main yet; open Pi in that directory and run /trust"; return 1; }
  ho_pi_verify "$role" "$(kv_get "$file" "$sec.provider")" "$(kv_get "$file" "$sec.model")" \
    "$(kv_get "$file" "$sec.effort")" "$(kv_get "$file" "$sec.billing")" "${5:-}"
}

# ho_pi_settings_json <provider> <model> <effort>: the Pi project settings a role starts from.
ho_pi_settings_json() {
  jq -cnS --arg p "$1" --arg m "$2" --arg t "$3" '{defaultProvider:$p, defaultModel:$m, defaultThinkingLevel:$t}'
}

# ho_pi_settings <worktree> <provider> <model> <effort>: write .pi/settings.json, ignored through info/exclude.
# Identical content is reused (a retry); a different or tracked file is refused and left alone.
ho_pi_settings() {
  local wt="$1" f="$1/.pi/settings.json" want ex
  want="$(ho_pi_settings_json "$2" "$3" "$4")" || return 1
  if [[ -n "$(git -C "$wt" ls-files -- .pi/settings.json 2>/dev/null)" ]]; then
    ho_err "$f is tracked by Git; a Pi role cannot use this worktree"; return 1
  fi
  if [[ -e "$f" && "$(jq -cS . "$f" 2>/dev/null)" != "$want" ]]; then
    ho_err "$f already exists with other settings; remove it or give the Pi role another worktree"; return 1
  fi
  ex="$(git -C "$wt" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null)" || { ho_err "$wt is not a Git worktree"; return 1; }
  mkdir -p "$(dirname "$ex")" || return 1
  if ! grep -qxF '/.pi/settings.json' "$ex" 2>/dev/null; then
    [[ -s "$ex" && -n "$(tail -c1 "$ex")" ]] && printf '\n' >> "$ex"
    printf '/.pi/settings.json\n' >> "$ex" || return 1
  fi
  [[ -e "$f" ]] || { mkdir -p "$wt/.pi" && printf '%s\n' "$want" > "$f"; }
}

# A role that creates the settings file records it as <implementer|reviewer|finish>.pi_settings in loop.yaml.
ho_pi_role_key() { case "$1" in implement*) echo implementer ;; review*) echo reviewer ;; finish*) echo finish ;; esac; }

# ho_pi_settings_owned <loop.yaml> <worktree>: print the worktree's settings file when this loop recorded
# it as written and it still holds what the loop wrote; a file that existed before the loop is never recorded.
ho_pi_settings_owned() {
  local loop="$1" f="$2/.pi/settings.json" have role sec
  [[ -f "$f" && -z "$(git -C "$2" ls-files -- .pi/settings.json 2>/dev/null)" ]] || return 1
  have="$(jq -cS . "$f" 2>/dev/null)" || return 1
  for sec in implement_template review_template finish_template; do
    role="$(ho_pi_role_key "$sec")"
    [[ "$(kv_get "$loop" "$sec.harness" 2>/dev/null)" == pi && "$(kv_get "$loop" "$role.pi_settings" 2>/dev/null)" == "$f" ]] || continue
    if [[ "$have" == "$(ho_pi_settings_json "$(kv_get "$loop" "$sec.provider")" "$(kv_get "$loop" "$sec.model")" "$(kv_get "$loop" "$sec.effort")")" ]]; then
      printf '%s\n' "$f"; return 0
    fi
  done
  return 1
}

# ho_pi_settings_cleanup <loop.yaml> <worktree>: remove the settings file ho_pi_settings_owned names.
ho_pi_settings_cleanup() {
  local f
  f="$(ho_pi_settings_owned "$1" "$2")" || return 0
  rm -f "$f"; rmdir "$2/.pi" 2>/dev/null; printf 'Removed %s\n' "$f"
}

# ho_record_tsec <loop.yaml> <record>: the template a record answers to. handoff-role keeps the template it
# replaces as <role>_template_until_<NN> for the records numbered below NN; later records use the current one.
ho_record_tsec() {
  local sec n k
  sec="$(kv_get "$2" role 2>/dev/null)_template"; n=$((10#$(basename "$2" | cut -c1-2)))
  for k in $(sed -n "s/^${sec}_until_\([0-9][0-9]\):[[:space:]]*\$/\1/p" "$1" | sort); do
    (( 10#$k > n )) && { printf '%s_until_%s\n' "$sec" "$k"; return 0; }
  done
  printf '%s\n' "$sec"
}

# ho_pi_record_check <loop.yaml> <record>: a record of a Pi role must match the template it answers to.
# Prints each mismatch and fails; other harnesses always pass.
ho_pi_record_check() {
  local loop="$1" rec="$2" sec k want got out=""
  sec="$(ho_record_tsec "$loop" "$rec")"
  [[ "$(kv_get "$loop" "$sec.harness" 2>/dev/null)" == pi ]] || return 0
  if [[ "$(kv_get "$rec" agent.harness 2>/dev/null)" != pi ]]; then echo "交件單沒有 Pi 的 agent 區塊"; return 1; fi
  for k in provider model effort billing; do
    want="$(kv_get "$loop" "$sec.$k" 2>/dev/null)"; got="$(kv_get "$rec" "agent.$k" 2>/dev/null)"; got="${got:-unknown}"
    [[ "$got" == "$want" ]] && continue
    [[ -n "$out" ]] && out+="；"
    out+="$k 範本為 ${want}、實際為 $got"
  done
  got="$(kv_get "$rec" agent.session 2>/dev/null)"
  if [[ -z "$got" || "$got" == unknown ]]; then [[ -n "$out" ]] && out+="；"; out+="session 為 unknown"; fi
  [[ -z "$out" ]] && return 0
  printf '%s\n' "$out"; return 1
}

# ho_pi_record_label <record>: "Pi / <provider>/<model> / <effort> / 訂閱|API|unknown" for a Pi record.
ho_pi_record_label() {
  local rec="$1" b
  [[ "$(kv_get "$rec" agent.harness 2>/dev/null)" == pi ]] || return 1
  b="$(kv_get "$rec" agent.billing 2>/dev/null)"
  case "$b" in subscription) b="訂閱" ;; api) b="API" ;; *) b="${b:-unknown}" ;; esac
  printf 'Pi / %s/%s / %s / %s\n' "$(kv_get "$rec" agent.provider 2>/dev/null || echo unknown)" \
    "$(kv_get "$rec" agent.model 2>/dev/null || echo unknown)" "$(kv_get "$rec" agent.effort 2>/dev/null || echo unknown)" "$b"
}

# --- environment checks (handoff-doctor, design D9) -------------------------------------
# Each check prints lines "<ok|warn|fail> <area> <message>"; areas: base, host, harness, role, notify.
# <file> is roles.yaml (sections implement, review, finish) or loop.yaml (sections *_template).
ho_line() { printf '%s %s %s\n' "$1" "$2" "$3"; }
ho_sec_role() { printf '%s\n' "${1%_template}"; }

ho_check_base() {
  local file="$1" t main
  for t in git jq; do
    if command -v "$t" >/dev/null 2>&1; then ho_line ok base "$t found"; else ho_line fail base "$t command not found"; fi
  done
  if main="$(ho_main_worktree)"; then ho_line ok base "main worktree $main"; else ho_line fail base "not inside a Git repository"; fi
  if [[ -f "$file" && -r "$file" ]]; then ho_line ok base "templates $file"
  else ho_line fail base "role templates not found: $file (run the wk-agent-ops installer, or copy roles.example.yaml there)"; fi
}

# ho_secs_with <file> <lookup-fn> <value> <sections...>: the roles (comma-separated) whose lookup is <value>.
ho_secs_with() {
  local file="$1" fn="$2" want="$3" sec out=""; shift 3
  for sec in "$@"; do [[ "$("$fn" "$file" "$sec")" == "$want" ]] && out+="${out:+, }$(ho_sec_role "$sec")"; done
  printf '%s' "$out"
}
ho_sec_harness() { kv_get "$1" "$2.harness" 2>/dev/null; }

ho_check_host() {
  local file="$1" h roles main project; shift
  main="$(ho_main_worktree)"
  for h in $HANDOFF_HOSTS; do
    roles="$(ho_secs_with "$file" ho_sec_host "$h" "$@")"; [[ -n "$roles" ]] || continue
    if ! command -v "$h" >/dev/null 2>&1; then ho_line fail host "$roles: the $h command was not found"; continue; fi
    case "$h" in
      xirp)
        project="$(ho_xirp_project_id "$main")"
        if [[ -n "$project" ]]; then ho_line ok host "$roles: xirp project $project for $main"
        else ho_line fail host "$roles: no Xirp project is registered for $main (xirp project add $main)"; fi ;;
      herdr) ho_check_herdr "$file" "$@" ;;
    esac
  done
}

# ho_sec_herdr_session <file> <section>: the herdr session recorded for the role in loop.yaml, or the
# one a loop started now would choose (design D4).
ho_sec_herdr_session() {
  local s; s="$(kv_get "$1" "$(ho_pi_role_key "$2").herdr_session" 2>/dev/null)"
  [[ -n "$s" ]] && printf '%s\n' "$s" || ho_herdr_session_choice "$1"
}

# ho_check_herdr <file> <sections...>: herdr's version and the server of every herdr session in use.
ho_check_herdr() {
  local file="$1" sec hs seen=" " roles ver; shift
  ver="$(herdr --version </dev/null 2>/dev/null | head -1)"
  ho_line ok host "herdr: ${ver:-version unknown}"
  for sec in "$@"; do
    [[ "$(ho_sec_host "$file" "$sec")" == herdr ]] || continue
    hs="$(ho_sec_herdr_session "$file" "$sec")"; [[ "$seen" == *" $hs "* ]] && continue; seen+="$hs "
    roles="$(ho_secs_with "$file" ho_sec_herdr_session "$hs" "$@")"
    if herdr --session "$hs" status server --json </dev/null 2>/dev/null | jq -e '.running == true' >/dev/null 2>&1; then
      ho_line ok host "$roles: herdr session '$hs' server is running"
    else
      ho_line fail host "$roles: the herdr server for session '$hs' is not running (start it with: herdr --session $hs)"
    fi
  done
}

# ho_hook_registered <settings-json>: handoff-route is a Stop hook there.
ho_hook_registered() {
  jq -e '[.hooks.Stop[]?.hooks[]? | select((.command // "") | test("handoff-route"))] | length > 0' "$1" >/dev/null 2>&1
}

ho_check_harness() {
  local file="$1" h roles ver; shift
  for h in claude codex pi; do
    roles="$(ho_secs_with "$file" ho_sec_harness "$h" "$@")"; [[ -n "$roles" ]] || continue
    if ! command -v "$h" >/dev/null 2>&1; then ho_line fail harness "$roles: the $h command was not found"; continue; fi
    ver="$("$h" --version </dev/null 2>/dev/null | head -1)"
    ho_line ok harness "$roles: $h ${ver:-(version unknown)}"
    case "$h" in
      claude) ho_hook_registered "$HOME/.claude/settings.json" && ho_line ok harness "$roles: Claude Code Stop hook registered" \
        || ho_line fail harness "$roles: handoff-route is not a Stop hook in ~/.claude/settings.json (run scripts/handoff/install.sh)" ;;
      codex)
        ho_hook_registered "$HOME/.codex/hooks.json" && ho_line ok harness "$roles: Codex Stop hook registered" \
          || ho_line fail harness "$roles: handoff-route is not a Stop hook in ~/.codex/hooks.json (run scripts/handoff/install.sh)"
        ho_line warn harness "$roles: codex hook trust cannot be checked from outside Codex; confirm \"Agent 交接派送\" is trusted and enabled in /hooks" ;;
      pi) [[ -f "$(ho_pi_extension)" ]] && ho_line ok harness "$roles: Pi trigger $(ho_pi_extension) installed" \
        || ho_line fail harness "$roles: the Pi handoff trigger $(ho_pi_extension) is not installed; run scripts/handoff/install.sh" ;;
    esac
    ho_check_herdr_integration "$file" "$h" "$@"
  done
}

# ho_check_herdr_integration <file> <harness> <sections...>: herdr reports a herdr role's native session
# ID only through its integration for that tool.
ho_check_herdr_integration() {
  local file="$1" h="$2" sec roles=""; shift 2
  for sec in "$@"; do
    [[ "$(ho_sec_harness "$file" "$sec")" == "$h" && "$(ho_sec_host "$file" "$sec")" == herdr ]] && roles+="${roles:+, }$(ho_sec_role "$sec")"
  done
  [[ -n "$roles" ]] && command -v herdr >/dev/null 2>&1 || return 0
  if herdr integration status </dev/null 2>/dev/null | grep -E "^$h: " | grep -qv 'not installed'; then
    ho_line ok harness "$roles: herdr $h integration installed"
  else
    ho_line warn harness "$roles: herdr's $h integration is not installed (herdr integration install $h); herdr cannot report the native session ID"
  fi
}

# ho_check_role <file> <section>: the template passed ho_template_check; check the model where possible.
ho_check_role() {
  local file="$1" sec="$2" role h m e p msg main
  role="$(ho_sec_role "$sec")"; h="$(kv_get "$file" "$sec.harness")"; m="$(kv_get "$file" "$sec.model")"; e="$(kv_get "$file" "$sec.effort")"
  if [[ "$h" != pi ]]; then ho_line ok role "$role: $h model $m at $e (model not verified)"; return 0; fi
  p="$(kv_get "$file" "$sec.provider")"; main="$(ho_main_worktree)"
  if ! ho_pi_repo_trusted "$main"; then ho_line fail role "$role: Pi does not trust $main yet; open Pi in that directory and run /trust"; return 0; fi
  if msg="$(ho_pi_verify "$role" "$p" "$m" "$e" "$(kv_get "$file" "$sec.billing")" warn 2>&1)"; then
    ho_line ok role "$role: pi $p/$m at $e verified"
    [[ -z "$msg" ]] || ho_line warn role "${msg#⚠️  }"
  else
    ho_line fail role "$msg"
  fi
}

ho_check_notify() {
  if [[ -f "$HANDOFF_NOTIFY" ]]; then ho_line ok notify "notifier $HANDOFF_NOTIFY"
  else ho_line warn notify "no notifier at $HANDOFF_NOTIFY; loop notices will not be delivered (see /notify-setup)"; fi
}

# ho_preflight <file> <sections...>: every check for these roles; fails when any line is fail.
# A failed base check stops the rest; a role whose template fails is not checked further.
ho_preflight() {
  local file="$1" base out sec msg valid=() tfail=""; shift
  base="$(ho_check_base "$file")"; printf '%s\n' "$base"
  grep -q '^fail ' <<<"$base" && return 1
  for sec in "$@"; do
    if msg="$(ho_template_check "$file" "$sec" 2>&1)"; then valid+=("$sec"); else tfail+="fail role $(ho_sec_role "$sec"): $msg"$'\n'; fi
  done
  out="$(
    if (( ${#valid[@]} )); then ho_check_host "$file" "${valid[@]}"; ho_check_harness "$file" "${valid[@]}"; fi
    printf '%s' "$tfail"
    for sec in "${valid[@]+"${valid[@]}"}"; do ho_check_role "$file" "$sec"; done
    ho_check_notify
  )"
  printf '%s\n' "$out"
  ! grep -q '^fail ' <<<"$out"
}

# ho_preflight_or_refuse <command> <file> <sections...>: print warn and fail lines on stderr; fail on any fail.
ho_preflight_or_refuse() {
  local cmd="$1" out rc; shift
  out="$(ho_preflight "$@")"; rc=$?
  grep -E '^(warn|fail) ' <<<"$out" | sed "s/^/$cmd: /" >&2
  return $rc
}

# --- finish ------------------------------------------------------------------------
# ho_finish_check <dir>: prints the passing head, or the reason it cannot finish (exit 1).
ho_finish_check() {
  local dir="$1" loop="$1/loop.yaml" rec impl head why
  impl="$(kv_get "$loop" implementer.worktree)"
  if ho_has_finish_record "$dir"; then echo "the loop already has a finish record (a blocked one is retried with handoff-finish)"; return 1; fi
  rec="$(ho_newest_in_loop "$dir")" || { echo "the loop has no records"; return 1; }
  if [[ "$(kv_get "$rec" role)" != review ]]; then echo "the newest record is $(basename "$rec"), not a passing review"; return 1; fi
  if [[ "$(kv_get "$rec" status)" != done || "$(kv_get "$rec" verdict)" != pass ]]; then
    echo "the newest review is status $(kv_get "$rec" status), verdict $(kv_get "$rec" verdict)"; return 1
  fi
  if ! why="$(ho_pi_record_check "$loop" "$rec")"; then
    echo "the passing review $(basename "$rec") does not match the Pi review template: $why"; return 1
  fi
  head="$(kv_get "$rec" head)"
  if [[ "$(ho_head "$impl")" != "$head" ]]; then
    echo "the passing review is for $head but the implementer worktree is at $(ho_head "$impl")"; return 1
  fi
  if ! ho_clean "$impl"; then echo "the implementer worktree has uncommitted changes"; return 1; fi
  printf '%s\n' "$head"
}

# ho_finish_open <dir>: checks, prepares the finish worktree and opens the finish session.
# ho_delivery_text <local|pr>: what the loop's delivery setting asks the finish session to do.
ho_delivery_text() {
  if [[ "$1" == pr ]]; then
    printf '交付方式：pr（已授權：push 並回讀、github-pr update、以交付後的 head 做最終版 Review，通過才發 ready-to-merge Closure 並回讀）'
  else
    printf '交付方式：local（只做本地封存、文件與 commit，不寫 GitHub）'
  fi
}

# ho_finish_retry <loop-dir>: retry a finish whose newest record is finish/blocked.
# The finish worktree must be clean and build on the newest passing review; then the existing
# finish session resumes, or a new one opens when it is gone. Prints the session id.
# The retry for one blocked record is submitted once, confirmed or not: running handoff-finish again for
# the same record, even at the same time, reports it (status 3) and sends nothing (codex-herdr-r04, r05).
# The gate is a claim directory, created atomically before anything is sent; it is removed only when the
# host reports that nothing was sent, so that case can be retried. finish.retried_for records the result.
ho_finish_retry() {
  local dir="$1" loop="$1/loop.yaml" rec d f pass="" pn=-1 n wt change id msg note base rc claim existing err retried=0
  rec="$(ho_newest_in_loop "$dir")" || { echo "the loop has no records"; return 1; }
  if [[ "$(kv_get "$rec" role)" != finish || "$(kv_get "$rec" status)" != blocked ]]; then
    echo "the newest record is $(basename "$rec"), not a blocked finish"; return 1
  fi
  while IFS= read -r d; do
    for f in "$d"/[0-9][0-9]-review.yaml; do
      [[ -e "$f" && "$(kv_get "$f" status)" == done && "$(kv_get "$f" verdict)" == pass ]] || continue
      ho_pi_record_check "$loop" "$f" >/dev/null || continue
      n=$((10#$(basename "$f" | cut -c1-2))); (( n > pn )) && { pn=$n; pass="$(kv_get "$f" head)"; }
    done
  done < <(ho_loop_dirs "$dir")
  [[ -n "$pass" ]] || { echo "the loop has no passing review"; return 1; }
  wt="$(kv_get "$loop" finish.worktree 2>/dev/null)"; [[ -n "$wt" ]] || wt="$(kv_get "$loop" implementer.worktree)"
  if ! git -C "$wt" merge-base --is-ancestor "$pass" HEAD 2>/dev/null; then
    echo "$wt is at $(ho_head "$wt"), which does not build on the passing review $pass"; return 1
  fi
  ho_clean "$wt" || { echo "$wt has uncommitted changes"; return 1; }
  change="$(kv_get "$loop" change)"; note="$(kv_get "$rec" note 2>/dev/null)"
  id="$(kv_get "$loop" finish.session 2>/dev/null)"; base="$(basename "$rec")"; claim="$dir/.finish-retry-$base"
  existing=0
  if [[ -n "$id" ]] && ! ho_role_pending "$dir" finish && ho_host_exists "$(ho_role_host "$loop" finish)" "$dir" finish "$id"; then
    existing=1; ho_herdr_hold_error "$dir" finish "$id" || return 1
  fi
  if [[ "$(kv_get "$loop" finish.retried_for 2>/dev/null)" != "$base" ]] && ! err="$(mkdir "$claim" 2>&1)"; then
    # Only an existing claim means another run took it; any other failure sent nothing and stays retryable.
    [[ -d "$claim" ]] || { echo "cannot claim the finish retry for $base ($err); nothing was sent"; return 1; }
    retried=1
  fi
  if [[ "$(kv_get "$loop" finish.retried_for 2>/dev/null)" == "$base" ]] || (( retried )); then
    echo "Finish retry already sent (or being sent) for $base${id:+ to session $id}; nothing was sent again. Wait for its new record"; return 3
  fi
  if (( existing )); then
    msg="[$change] 重試收尾。上次停在：${note}。使用者已處理並要求重試：依 openspec-commit 的中斷恢復規則，從停下的階段接續，不重複已完成的步驟。"
    msg+="封存時若有待同步的 delta spec，直接同步主規格後封存，不需詢問。$(ho_delivery_text "$(kv_get "$loop" finish.delivery 2>/dev/null || echo local)")；"
    msg+="結束時以 $HANDOFF_WRITE_REL --change $change --role finish 寫新的交件單，不要改舊的交件單。"
    ho_host_message "$(ho_role_host "$loop" finish)" "$dir" finish "$id" "$msg"; rc=$?
    if (( rc == 0 || rc == 2 )); then ho_loop_set "$dir" finish.retried_for "$base"; else rmdir "$claim"; fi
    (( rc == 0 )) || { echo "could not message finish session $id"; return 1; }
  else
    # A finish that ran in the implementer's worktree and now has worktree new moves there with the branch, from a
    # commit that keeps the blocked finish's work (ho_finish_worktree also completes a move cut short). After a move,
    # the finish worktree keeps the usual requirements, and its records are written again in case one was cut short.
    local impl bh; impl="$(kv_get "$loop" implementer.worktree)"; bh="$(kv_get "$rec" head)"
    if [[ "$(kv_get "$loop" finish_template.worktree 2>/dev/null)" == new && "$wt" == "$impl" ]]; then
      if ! git -C "$wt" merge-base --is-ancestor "$bh" HEAD 2>/dev/null; then
        rmdir "$claim"; echo "$wt is at $(ho_head "$wt"), which does not hold the blocked finish's commit $bh; not moved"; return 1
      fi
      if ! wt="$(ho_finish_worktree "$dir" "$impl" "$change" "$(ho_head "$wt")" 2>&1)"; then
        rmdir "$claim"; echo "${wt##*$'\n'}"; return 1
      fi
      wt="${wt##*$'\n'}"
    elif [[ "$(kv_get "$loop" finish_template.worktree 2>/dev/null)" == new && "$wt" == "$impl-finish" ]]; then
      # Its own copy not naming it means a move into it was cut short: complete it only on the blocked finish's work.
      if [[ "$(kv_get "$wt/.agent-handoff/$change/loop.yaml" finish.worktree 2>/dev/null)" != "$wt" ]] \
        && ! git -C "$wt" merge-base --is-ancestor "$bh" HEAD 2>/dev/null; then
        rmdir "$claim"; echo "the move to $wt was not completed and $wt is at $(ho_head "$wt"), which does not hold the blocked finish's commit $bh; bring $wt back to $bh, then run handoff-finish again"; return 1
      fi
      if ! err="$(ho_finish_record "$dir" "$wt" "$change" 2>&1)"; then rmdir "$claim"; echo "${err##*$'\n'}"; return 1; fi
    fi
    id="$(ho_open_role "$dir" finish_template "$wt" "$(ho_head "$wt")" "$(kv_get "$rec" round)" "")"; rc=$?
    if (( rc == 0 || rc == 2 )); then ho_loop_set "$dir" finish.retried_for "$base"; else rmdir "$claim"; fi
    (( rc == 0 )) || { echo "could not open a finish session"; return 1; }
    ho_loop_set "$dir" finish.session "$id"
  fi
  printf '%s\n' "$id"
}

# ho_finish_record <loop-dir> <finish-worktree> <change>: give the finish worktree its own loop.yaml
# naming itself, then record it in every loop.yaml. Both are attempted; either failing fails.
# The copy alone proves the loop prepared the worktree when the implementer's record cannot be written.
ho_finish_record() {
  local dir="$1" wt="$2" change="$3" copy="$2/.agent-handoff/$3/loop.yaml" rc=0
  { mkdir -p "$wt/.agent-handoff/$change" && cp "$dir/loop.yaml" "$copy" && kv_set "$copy" finish.worktree "$wt"; } \
    || { ho_err "cannot copy loop.yaml into the finish worktree $wt"; rc=1; }
  ho_loop_set "$dir" finish.worktree "$wt" || { ho_err "cannot record the finish worktree $wt in loop.yaml"; rc=1; }
  return $rc
}

# ho_finish_prepared <loop.yaml> <finish-worktree> <change> <implementer-worktree>: this loop prepared it —
# the implementer's loop.yaml records it, or (when that record could not be written, so it still names no finish
# worktree or the implementer's) the worktree holds this loop's untracked loop.yaml naming it. A worktree made by
# hand has neither and is never taken over.
ho_finish_prepared() {
  local loop="$1" wt="$2" change="$3" impl="$4" copy="$2/.agent-handoff/$3/loop.yaml" recorded
  recorded="$(kv_get "$loop" finish.worktree 2>/dev/null || true)"
  [[ "$recorded" == "$wt" ]] && return 0
  [[ ( -z "$recorded" || "$recorded" == "$impl" ) && -f "$copy" && -z "$(git -C "$wt" ls-files -- ".agent-handoff/$change/loop.yaml" 2>/dev/null)" ]] || return 1
  [[ "$(kv_get "$copy" change 2>/dev/null)" == "$change" && "$(kv_get "$copy" implementer.worktree 2>/dev/null)" == "$impl" \
    && "$(kv_get "$copy" finish.worktree 2>/dev/null)" == "$wt" ]]
}

# ho_finish_worktree <loop-dir> <implementer-worktree> <change> <head>: the finish worktree of a finish role with
# worktree new; prints its path. A new one takes over feature/<change> while the implementer worktree is detached
# at <head>. A retry after a failed open reuses only the clean finish worktree this loop prepared on the feature
# branch at <head>; anything else is left untouched. The record and the copy are written (again) either way.
ho_finish_worktree() {
  local dir="$1" impl="$2" change="$3" head="$4" wt="$2-finish"
  if [[ -d "$wt" ]]; then
    ho_finish_prepared "$dir/loop.yaml" "$wt" "$change" "$impl" && [[ "$(git -C "$wt" branch --show-current 2>/dev/null)" == "feature/$change" \
      && "$(ho_head "$wt")" == "$head" ]] && ho_clean "$wt" \
      || { ho_err "cannot reuse the finish worktree $wt"; return 1; }
  else
    # The new worktree checks out the branch: it must be at the commit the finish continues from.
    [[ "$(git -C "$impl" rev-parse -q --verify "refs/heads/feature/$change" 2>/dev/null)" == "$head" ]] \
      || { ho_err "feature/$change is at $(git -C "$impl" rev-parse -q --verify "refs/heads/feature/$change" 2>/dev/null || echo nothing), not $head; the finish worktree was not created"; return 1; }
    git -C "$impl" checkout -q --detach "$head" || { ho_err "cannot detach the implementer worktree"; return 1; }
    git -C "$impl" worktree add -q "$wt" "feature/$change" 2>/dev/null \
      || { git -C "$impl" checkout -q "feature/$change"; ho_err "cannot create the finish worktree $wt"; return 1; }
    # The branch may have moved between the check and the checkout: open only at the expected commit.
    [[ "$(ho_head "$wt")" == "$head" ]] \
      || { ho_err "the finish worktree $wt checked out $(ho_head "$wt"), not $head; not opened. Remove that worktree, then run handoff-finish again"; return 1; }
  fi
  ho_finish_record "$dir" "$wt" "$change" || return 1
  printf '%s\n' "$wt"
}

ho_finish_open() {
  local dir="$1" loop="$1/loop.yaml" head impl mode wt change id round
  head="$(ho_finish_check "$dir")" || { ho_err "cannot finish: $head"; return 1; }
  # No finish record yet, so a recorded session that still exists is the finish in progress.
  # ponytail: an idle one that died without a record is reused too; delete it in Xirp for a new one.
  id="$(kv_get "$loop" finish.session 2>/dev/null)"
  if [[ -n "$id" ]] && ! ho_role_pending "$dir" finish && ho_host_exists "$(ho_role_host "$loop" finish)" "$dir" finish "$id"; then
    # An open finish whose first prompt herdr did not confirm is not taken as started until the user checks it.
    ho_herdr_hold_error "$dir" finish "$id" || return 1
    printf '%s\n' "$id"; return 0
  fi
  impl="$(kv_get "$loop" implementer.worktree)"; change="$(kv_get "$loop" change)"
  mode="$(kv_get "$loop" finish_template.worktree 2>/dev/null || echo shared)"
  wt="$impl"
  if [[ "$mode" == new ]]; then wt="$(ho_finish_worktree "$dir" "$impl" "$change" "$head")" || return 1; fi
  round="$(kv_get "$(ho_newest_in_loop "$dir")" round)"
  id="$(ho_open_role "$dir" finish_template "$wt" "$head" "$round" "")" || return 1
  ho_loop_set "$dir" finish.session "$id"
  [[ "$mode" == new ]] || ho_loop_set "$dir" finish.worktree "$wt"
  printf '%s\n' "$id"
}

# Locate the implementer's change directory for <change> from any worktree of the repo.
ho_find_loop_dir() {
  local change="$1" wt impl
  while IFS= read -r wt; do
    [[ -f "$wt/.agent-handoff/$change/loop.yaml" ]] || continue
    impl="$(kv_get "$wt/.agent-handoff/$change/loop.yaml" implementer.worktree 2>/dev/null)"
    [[ -n "$impl" && -f "$impl/.agent-handoff/$change/loop.yaml" ]] && { printf '%s\n' "$impl/.agent-handoff/$change"; return 0; }
  done < <(git -C "${2:-$PWD}" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0, 10)}')
  return 1
}
