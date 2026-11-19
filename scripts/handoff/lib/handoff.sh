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

# Open a role session from the template stored in loop.yaml. Prints the session id.
ho_open_role() {
  local dir="$1" tsec="$2" wt="$3" head="$4" round="$5" report="$6"
  local loop="$dir/loop.yaml" change main project name prompt delivery
  change="$(kv_get "$loop" change)"
  delivery="$(kv_get "$loop" finish.delivery 2>/dev/null || echo local)"
  main="$(ho_main_worktree "$wt")"
  project="$(ho_xirp_project_id "$main")"
  [[ -n "$project" ]] || { ho_err "no Xirp project registered for $main"; return 1; }
  if [[ "$(kv_get "$loop" "$tsec.harness")" == pi ]]; then
    ho_pi_ready "$loop" "$tsec" "${tsec%_template}" "$main" || return 1
    local existed=0; [[ -e "$wt/.pi/settings.json" ]] && existed=1
    ho_pi_settings "$wt" "$(kv_get "$loop" "$tsec.provider")" "$(kv_get "$loop" "$tsec.model")" "$(kv_get "$loop" "$tsec.effort")" || return 1
    (( existed )) || ho_loop_set "$dir" "$(ho_pi_role_key "$tsec").pi_settings" "$wt/.pi/settings.json"
  fi
  name="$(ho_render "$(kv_get "$loop" "$tsec.name")" "$change" "$head" "$round" "$report" "$delivery")"
  prompt="$(ho_render "$(kv_get "$loop" "$tsec.prompt")" "$change" "$head" "$round" "$report" "$delivery" \
    "$(kv_get "$loop" "$tsec.harness")" "$(kv_get "$loop" "$tsec.model")")"
  ho_xirp_create "$project" "$wt" "$(kv_get "$loop" "$tsec.harness")" "$(kv_get "$loop" "$tsec.model")" \
    "$(kv_get "$loop" "$tsec.effort")" "$name" "$prompt" "$(kv_get "$loop" "$tsec.profile" 2>/dev/null || true)" \
    "$(kv_get "$loop" "$tsec.provider" 2>/dev/null || true)"
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

# ho_pi_settings_cleanup <loop.yaml> <worktree>: remove the settings file this loop recorded as written,
# when it still holds what the loop wrote; a file that existed before the loop is never recorded.
ho_pi_settings_cleanup() {
  local loop="$1" f="$2/.pi/settings.json" have role sec
  [[ -f "$f" && -z "$(git -C "$2" ls-files -- .pi/settings.json 2>/dev/null)" ]] || return 0
  have="$(jq -cS . "$f" 2>/dev/null)" || return 0
  for sec in implement_template review_template finish_template; do
    role="$(ho_pi_role_key "$sec")"
    [[ "$(kv_get "$loop" "$sec.harness" 2>/dev/null)" == pi && "$(kv_get "$loop" "$role.pi_settings" 2>/dev/null)" == "$f" ]] || continue
    if [[ "$have" == "$(ho_pi_settings_json "$(kv_get "$loop" "$sec.provider")" "$(kv_get "$loop" "$sec.model")" "$(kv_get "$loop" "$sec.effort")")" ]]; then
      rm -f "$f"; rmdir "$2/.pi" 2>/dev/null; printf 'Removed %s\n' "$f"; return 0
    fi
  done
}

# ho_pi_record_check <loop.yaml> <record>: a record of a Pi role must match its template.
# Prints each mismatch and fails; other harnesses always pass.
ho_pi_record_check() {
  local loop="$1" rec="$2" sec k want got out=""
  sec="$(kv_get "$rec" role 2>/dev/null)_template"
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
ho_finish_retry() {
  local dir="$1" loop="$1/loop.yaml" rec d f pass="" pn=-1 n wt change id msg note
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
  # No finish record yet, so a recorded session that still exists is the finish in progress.
  # ponytail: an idle one that died without a record is reused too; delete it in Xirp for a new one.
  id="$(kv_get "$loop" finish.session 2>/dev/null)"
  if [[ -n "$id" ]] && ho_xirp_exists "$id"; then printf '%s\n' "$id"; return 0; fi
  impl="$(kv_get "$loop" implementer.worktree)"; change="$(kv_get "$loop" change)"
  mode="$(kv_get "$loop" finish_template.worktree 2>/dev/null || echo shared)"
  wt="$impl"
  if [[ "$mode" == new && -d "${impl}-finish" ]]; then
    # A retry after a failed open: reuse only the clean finish worktree this loop prepared
    # on the feature branch at the passing commit; anything else is left untouched.
    wt="${impl}-finish"
    [[ "$(kv_get "$loop" finish.worktree 2>/dev/null)" == "$wt" && "$(git -C "$wt" branch --show-current 2>/dev/null)" == "feature/$change" \
      && "$(ho_head "$wt")" == "$head" ]] && ho_clean "$wt" \
      || { ho_err "cannot reuse the finish worktree $wt"; return 1; }
  elif [[ "$mode" == new ]]; then
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
