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
ho_loop_set() {
  local dir="$1" key="$2" value="$3" d
  while IFS= read -r d; do kv_set "$d/loop.yaml" "$key" "$value"; done < <(ho_loop_dirs "$dir")
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

ho_xirp_ids_named() {
  xirp session list --search "$1" --json 2>/dev/null \
    | jq -r --arg n "$1" '(if type == "array" then . else (.sessions // []) end)[] | select((.name // "") == $n) | .id' 2>/dev/null
}

# ho_xirp_create <project-id> <worktree> <harness> <model> <effort> <name> <prompt> [codex-profile] -> session id
ho_xirp_create() {
  local project="$1" wt="$2" harness="$3" model="$4" effort="$5" name="$6" prompt="$7" profile="${8:-}"
  local effort_key before json id waited=0
  case "$harness" in
    claude) effort_key="effort" ;;
    codex) effort_key="reasoning_effort" ;;
    *) ho_err "unsupported harness: $harness"; return 1 ;;
  esac
  before="$(ho_xirp_ids_named "$name")"
  json="$(jq -n --arg p "$project" --arg w "$wt" --arg n "$name" --arg g "$prompt" --arg h "$harness" \
    --arg m "$model" --arg ek "$effort_key" --arg e "$effort" --arg pr "$profile" \
    '{projectId:$p, worktreePath:$w, customName:$n, goal:$g, background:true,
      agent:{agentName:$h, options:({model:$m} + {($ek):$e} + (if $pr == "" then {} else {profile:$pr} end))}}')"
  xirp api send session:create --json "$json" >/dev/null 2>&1 || { ho_err "xirp session:create failed"; return 1; }
  while :; do
    id="$(ho_xirp_ids_named "$name" | while IFS= read -r x; do grep -qxF "$x" <<<"$before" || { printf '%s\n' "$x"; break; }; done)"
    [[ -n "$id" ]] && { printf '%s\n' "$id"; return 0; }
    (( waited >= HANDOFF_CREATE_WAIT )) && { ho_err "session '$name' did not appear"; return 1; }
    sleep 1; waited=$((waited + 1))
  done
}

# --- templates -------------------------------------------------------------------
# ho_author <harness> <model>: tells a role to append handoff-author's output as its Author.
# The model comes from the template (agents cannot query Xirp from a sandbox); the script copies
# both session IDs from the agent's environment, so no model retypes them.
ho_author() {
  local tool
  case "$1" in claude) tool="'Claude Code'" ;; codex) tool="Codex" ;; *) tool="$1" ;; esac
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
  local file="$1" sec="$2" k v missing=""
  for k in harness model effort name prompt; do
    v="$(kv_get "$file" "$sec.$k" 2>/dev/null)"
    [[ -n "$v" ]] || missing="$missing $k"
  done
  [[ -z "$missing" ]] || { ho_err "$sec template is missing:$missing"; return 1; }
  v="$(kv_get "$file" "$sec.harness")"
  [[ "$v" == claude || "$v" == codex ]] || { ho_err "$sec template harness must be claude or codex, got '$v'"; return 1; }
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
  for k in worktree harness model effort name prompt profile; do
    v="$(kv_get "$src" "$sec.$k" 2>/dev/null)" || continue
    [[ "$k" == worktree && -z "$v" ]] && v=shared
    kv_set "$loop" "$dest.$k" "\"$v\""
  done
  if [[ "$sec" == review || "$sec" == finish ]] && ! kv_get "$loop" "$dest.worktree" >/dev/null 2>&1; then
    kv_set "$loop" "$dest.worktree" shared
  fi
}

# Open a role session from the template stored in loop.yaml. Prints the session id.
ho_open_role() {
  local dir="$1" tsec="$2" wt="$3" head="$4" round="$5" report="$6"
  local loop="$dir/loop.yaml" change main project name prompt delivery
  change="$(kv_get "$loop" change)"
  delivery="$(kv_get "$loop" finish.delivery 2>/dev/null || echo local)"
  main="$(ho_main_worktree "$wt")"
  project="$(ho_xirp_project_id "$main")"
  [[ -n "$project" ]] || { ho_err "no Xirp project registered for $main"; return 1; }
  name="$(ho_render "$(kv_get "$loop" "$tsec.name")" "$change" "$head" "$round" "$report" "$delivery")"
  prompt="$(ho_render "$(kv_get "$loop" "$tsec.prompt")" "$change" "$head" "$round" "$report" "$delivery" \
    "$(kv_get "$loop" "$tsec.harness")" "$(kv_get "$loop" "$tsec.model")")"
  ho_xirp_create "$project" "$wt" "$(kv_get "$loop" "$tsec.harness")" "$(kv_get "$loop" "$tsec.model")" \
    "$(kv_get "$loop" "$tsec.effort")" "$name" "$prompt" "$(kv_get "$loop" "$tsec.profile" 2>/dev/null || true)"
}

# --- finish ------------------------------------------------------------------------
# ho_finish_check <dir>: prints the passing head, or the reason it cannot finish (exit 1).
ho_finish_check() {
  local dir="$1" loop="$1/loop.yaml" rec impl head
  impl="$(kv_get "$loop" implementer.worktree)"
  if ho_has_finish_record "$dir"; then echo "the loop already has a finish record (a blocked one is retried with handoff-finish)"; return 1; fi
  rec="$(ho_newest_in_loop "$dir")" || { echo "the loop has no records"; return 1; }
  if [[ "$(kv_get "$rec" role)" != review ]]; then echo "the newest record is $(basename "$rec"), not a passing review"; return 1; fi
  if [[ "$(kv_get "$rec" status)" != done || "$(kv_get "$rec" verdict)" != pass ]]; then
    echo "the newest review is status $(kv_get "$rec" status), verdict $(kv_get "$rec" verdict)"; return 1
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
ho_finish_retry() {
  local dir="$1" loop="$1/loop.yaml" rec d f pass="" pn=-1 n wt change id msg note
  rec="$(ho_newest_in_loop "$dir")" || { echo "the loop has no records"; return 1; }
  if [[ "$(kv_get "$rec" role)" != finish || "$(kv_get "$rec" status)" != blocked ]]; then
    echo "the newest record is $(basename "$rec"), not a blocked finish"; return 1
  fi
  while IFS= read -r d; do
    for f in "$d"/[0-9][0-9]-review.yaml; do
      [[ -e "$f" && "$(kv_get "$f" status)" == done && "$(kv_get "$f" verdict)" == pass ]] || continue
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
  id="$(kv_get "$loop" finish.session 2>/dev/null)"
  if [[ -n "$id" ]] && ho_xirp_exists "$id"; then
    msg="[$change] 重試收尾。上次停在：${note}。使用者已處理並要求重試：依 openspec-commit 的中斷恢復規則，從停下的階段接續，不重複已完成的步驟。"
    msg+="封存時若有待同步的 delta spec，直接同步主規格後封存，不需詢問。$(ho_delivery_text "$(kv_get "$loop" finish.delivery 2>/dev/null || echo local)")；"
    msg+="結束時以 $HANDOFF_WRITE_REL --change $change --role finish 寫新的交件單，不要改舊的交件單。"
    ho_xirp_message "$id" "$msg" || { echo "could not message finish session $id"; return 1; }
  else
    id="$(ho_open_role "$dir" finish_template "$wt" "$(ho_head "$wt")" "$(kv_get "$rec" round)" "")" || { echo "could not open a finish session"; return 1; }
    ho_loop_set "$dir" finish.session "$id"
  fi
  printf '%s\n' "$id"
}

ho_finish_open() {
  local dir="$1" loop="$1/loop.yaml" head impl mode wt change id round
  head="$(ho_finish_check "$dir")" || { ho_err "cannot finish: $head"; return 1; }
  impl="$(kv_get "$loop" implementer.worktree)"; change="$(kv_get "$loop" change)"
  mode="$(kv_get "$loop" finish_template.worktree 2>/dev/null || echo shared)"
  wt="$impl"
  if [[ "$mode" == new ]]; then
    wt="${impl}-finish"
    git -C "$impl" checkout -q --detach "$head" || { ho_err "cannot detach the implementer worktree"; return 1; }
    git -C "$impl" worktree add -q "$wt" "feature/$change" 2>/dev/null \
      || { git -C "$impl" checkout -q "feature/$change"; ho_err "cannot create the finish worktree $wt"; return 1; }
    mkdir -p "$wt/.agent-handoff/$change" && cp "$loop" "$wt/.agent-handoff/$change/loop.yaml"
    ho_loop_set "$dir" finish.worktree "$wt"
  fi
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
