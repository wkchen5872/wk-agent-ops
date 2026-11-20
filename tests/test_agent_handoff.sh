#!/usr/bin/env bash
# Offline tests for the agent handoff loop: record parser, handoff-write, routing hook, and launcher.
# Usage: bash tests/test_agent_handoff.sh [kv|write|skill|install|route|notify|mixed|start|finish|doctor|herdr|happ|hookinstall|cleanup|pi|all]
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/template/common/skills/agent-handoff"
KV="$SKILL/scripts/kv.sh"
WRITE="$SKILL/scripts/handoff-write"
section="${1:-all}"
fail=0
# Run inside a Herdr app terminal, the route would name that terminal as the stopping session.
unset HC_TERMINAL_ID

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
run_section() { [[ "$section" == "all" || "$section" == "$1" ]]; }

new_repo() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name "Handoff Test"
  git -C "$dir" config commit.gpgsign false
  printf '/.agent-handoff/\n' > "$dir/.gitignore"
  printf 'seed\n' > "$dir/README.md"
  git -C "$dir" add .gitignore README.md
  git -C "$dir" commit -qm seed
}

tmp="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/wk-handoff.XXXXXX")" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- kv parser
if run_section kv; then
  printf 'kv parser\n'
  f="$tmp/sample.yaml"
  cat > "$f" <<'YAML'
# comment line
change: add-export
note: review says: fix the time zone
empty:
implement:
  harness: claude
  prompt: "/openspec-apply-change {change}: then commit"
review:
  harness: codex
  model: gpt-6.1-sol
YAML
  # shellcheck source=/dev/null
  if [[ -f "$KV" ]] && source "$KV" 2>/dev/null; then
    [[ "$(kv_get "$f" change)" == "add-export" ]] && ok "reads a top-level value" || bad "reads a top-level value"
    [[ "$(kv_get "$f" note)" == "review says: fix the time zone" ]] && ok "keeps colons inside a value" || bad "keeps colons inside a value"
    [[ "$(kv_get "$f" implement.harness)" == "claude" ]] && ok "reads a nested value" || bad "reads a nested value"
    [[ "$(kv_get "$f" review.harness)" == "codex" ]] && ok "keeps sections apart" || bad "keeps sections apart"
    [[ "$(kv_get "$f" implement.prompt)" == "/openspec-apply-change {change}: then commit" ]] && ok "strips surrounding double quotes" || bad "strips surrounding double quotes"
    if kv_get "$f" missing >/dev/null 2>&1; then bad "missing key fails"; else ok "missing key fails"; fi
    if kv_get "$f" implement.model >/dev/null 2>&1; then bad "missing nested key fails"; else ok "missing nested key fails"; fi
    [[ -z "$(kv_get "$f" empty)" ]] && ok "empty value reads as empty" || bad "empty value reads as empty"
  else
    bad "kv.sh exists and can be sourced"
  fi
fi

# ---------------------------------------------------------------- handoff-write
if run_section write; then
  printf 'handoff-write\n'
  repo="$tmp/write-repo"; new_repo "$repo"
  head="$(git -C "$repo" rev-parse HEAD)"
  w() { (cd "$repo" && "$WRITE" "$@") ; }
  dir="$repo/.agent-handoff/add-export"

  if out="$(w --change add-export --role implement --status done --head HEAD --note 'round one' 2>&1)" && [[ -f "$dir/01-implement.yaml" ]]; then
    ok "writes the first record as 01-implement.yaml"
  else
    bad "writes the first record as 01-implement.yaml"; printf '       %s\n' "$out"
  fi
  if [[ -f "$dir/01-implement.yaml" ]] && source "$KV" 2>/dev/null; then
    f="$dir/01-implement.yaml"
    [[ "$(kv_get "$f" change)" == "add-export" && "$(kv_get "$f" role)" == "implement" && "$(kv_get "$f" status)" == "done" \
      && "$(kv_get "$f" head)" == "$head" && "$(kv_get "$f" round)" == "1" && "$(kv_get "$f" note)" == "round one" ]] \
      && ok "records change, role, status, full head, round and note" || bad "records change, role, status, full head, round and note"
    kv_get "$f" verdict >/dev/null 2>&1 && bad "implement record has no verdict" || ok "implement record has no verdict"
    [[ "$(kv_get "$f" at)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$ ]] \
      && ok "at is ISO 8601 with offset" || bad "at is ISO 8601 with offset"
  fi
  [[ -z "$(git -C "$repo" status --porcelain)" ]] && ok "record does not show in git status" || bad "record does not show in git status"

  mkdir -p "$repo/reports"; printf 'report\n' > "$repo/reports/r01.md"
  mkdir -p "$repo/.git/info"; printf '/reports/\n' >> "$repo/.git/info/exclude"
  if w --change add-export --role review --status done --verdict changes-required --head HEAD --report reports/r01.md >/dev/null 2>&1 \
    && [[ -f "$dir/02-review.yaml" ]] && [[ "$(kv_get "$dir/02-review.yaml" verdict)" == "changes-required" ]] \
    && [[ "$(kv_get "$dir/02-review.yaml" report)" == "reports/r01.md" ]] && [[ "$(kv_get "$dir/02-review.yaml" round)" == "1" ]]; then
    ok "review record is 02-review.yaml with verdict, report and round 1"
  else
    bad "review record is 02-review.yaml with verdict, report and round 1"
  fi
  before="$(cat "$dir/01-implement.yaml")"
  w --change add-export --role implement --status done --head HEAD >/dev/null 2>&1
  [[ -f "$dir/03-implement.yaml" && "$(kv_get "$dir/03-implement.yaml" round)" == "2" && "$(cat "$dir/01-implement.yaml")" == "$before" ]] \
    && ok "next implement record is 03 in round 2 and earlier files are unchanged" || bad "next implement record is 03 in round 2 and earlier files are unchanged"

  count="$(ls "$dir" | wc -l | tr -d ' ')"
  expect_reject() {
    local label="$1"; shift
    if w "$@" >/dev/null 2>&1; then bad "$label"; else
      [[ "$(ls "$dir" | wc -l | tr -d ' ')" == "$count" ]] && ok "$label" || bad "$label (left a file)"
    fi
  }
  expect_reject "rejects an unknown verdict" --change add-export --role review --status done --verdict approve --head HEAD --report reports/r01.md
  expect_reject "rejects an unknown role" --change add-export --role planner --status done --head HEAD
  expect_reject "rejects an unknown status" --change add-export --role implement --status ok --head HEAD
  expect_reject "rejects a head that is not a commit" --change add-export --role implement --status done --head deadbeefdeadbeef
  expect_reject "rejects a review without a report" --change add-export --role review --status done --verdict pass --head HEAD
  expect_reject "rejects a report that does not exist" --change add-export --role review --status done --verdict pass --head HEAD --report reports/none.md
  expect_reject "rejects a verdict on an implement record" --change add-export --role implement --status done --verdict pass --head HEAD
  expect_reject "rejects a review without a verdict" --change add-export --role review --status done --head HEAD --report reports/r01.md
  if (cd "$repo" && "$WRITE" --change ../escape --role implement --status done --head HEAD) >/dev/null 2>&1 \
    || [[ -e "$repo/.agent-handoff/escape" || -e "$repo/escape" ]]; then
    bad "rejects a change id that leaves .agent-handoff/"
  else
    ok "rejects a change id that leaves .agent-handoff/"
  fi

  # Sequence spans the worktrees listed in loop.yaml.
  wa="$tmp/seq-a"; new_repo "$wa"
  wb="$tmp/seq-b"; git -C "$wa" worktree add -q --detach "$wb" HEAD
  mkdir -p "$wa/.agent-handoff/add-export" "$wb/.agent-handoff/add-export"
  for d in "$wa" "$wb"; do
    cat > "$d/.agent-handoff/add-export/loop.yaml" <<YAML
change: add-export
max_rounds: 3
implementer:
  worktree: $wa
reviewer:
  worktree: $wb
YAML
  done
  (cd "$wa" && "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  mkdir -p "$wb/reports"; printf 'r\n' > "$wb/reports/r.md"
  (cd "$wb" && "$WRITE" --change add-export --role review --status done --verdict changes-required --head HEAD --report reports/r.md) >/dev/null 2>&1
  (cd "$wa" && "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  [[ -f "$wa/.agent-handoff/add-export/01-implement.yaml" && -f "$wb/.agent-handoff/add-export/02-review.yaml" \
    && -f "$wa/.agent-handoff/add-export/03-implement.yaml" ]] \
    && ok "sequence continues across the implementer and review worktrees" || bad "sequence continues across the implementer and review worktrees"

  # Shared worktree: loop.yaml lists the same worktree for several roles; count it once.
  ws="$tmp/seq-shared"; new_repo "$ws"; mkdir -p "$ws/.agent-handoff/add-export" "$ws/r"; printf 'r\n' > "$ws/r/x.md"
  mkdir -p "$ws/.git/info"; printf '/r/\n' >> "$ws/.git/info/exclude"
  printf 'change: add-export\nimplementer:\n  worktree: %s\nreviewer:\n  worktree: %s\n' "$ws" "$ws" > "$ws/.agent-handoff/add-export/loop.yaml"
  (cd "$ws" && "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  (cd "$ws" && "$WRITE" --change add-export --role review --status done --verdict pass --head HEAD --report r/x.md) >/dev/null 2>&1
  [[ "$(kv_get "$ws/.agent-handoff/add-export/02-review.yaml" round 2>/dev/null)" == "1" ]] \
    && ok "a worktree listed for several roles is counted once" || bad "a worktree listed for several roles is counted once"
fi

# ---------------------------------------------------------------- skill documentation
if run_section skill; then
  printf 'agent-handoff skill\n'
  md="$SKILL/SKILL.md"
  if [[ -f "$md" ]] && head -1 "$md" | grep -qx -- '---' && grep -q '^name: agent-handoff$' "$md" && grep -q '^description:' "$md"; then
    ok "SKILL.md has name and description frontmatter"
  else
    bad "SKILL.md has name and description frontmatter"
  fi
  missing=""
  for field in change round role status head note at verdict report; do
    grep -q "\`$field\`" "$md" 2>/dev/null || missing="$missing $field"
  done
  [[ -z "$missing" ]] && ok "SKILL.md documents every record field" || bad "SKILL.md documents every record field (missing:$missing)"
  [[ -x "$WRITE" ]] && ok "handoff-write is executable" || bad "handoff-write is executable"
  AUTH="$SKILL/scripts/handoff-author"
  a1="$(env -i PATH="$PATH" CODEX_SESSION_ID=n-1 CODEX_THREAD_ID=n-1 CHIRP_SESSION_ID=x-1 CLAUDE_CODE_SESSION_ID=wrong "$AUTH" --tool Codex --model gpt-5.6-luna 2>/dev/null)"
  [[ "$a1" == $'Co-Authored-By: Codex\nAI-Assisted-By: gpt-5.6-luna\nSESSION-ID: n-1\nXIRP-SESSION-ID: x-1' ]] \
    && ok "handoff-author prints the four Author lines from the Codex environment" || bad "handoff-author prints the four Author lines from the Codex environment ($a1)"
  a2="$(env -i PATH="$PATH" CLAUDE_CODE_SESSION_ID=c-1 CODEX_SESSION_ID=wrong "$AUTH" --tool 'Claude Code' --model opus 2>/dev/null)"
  [[ "$a2" == $'Co-Authored-By: Claude Code\nAI-Assisted-By: opus\nSESSION-ID: c-1\nXIRP-SESSION-ID: null' ]] \
    && ok "handoff-author reads the Claude Code ID and writes null for a missing Xirp ID" || bad "handoff-author reads the Claude Code ID and writes null for a missing Xirp ID ($a2)"
  a3="$(env -i PATH="$PATH" CHIRP_SESSION_ID=x-1 "$AUTH" --tool Codex --model '' 2>/dev/null)"
  [[ "$a3" == $'Co-Authored-By: Codex\nSESSION-ID: null\nXIRP-SESSION-ID: x-1' ]] \
    && ok "handoff-author omits an unknown model and writes null for a missing native ID" || bad "handoff-author omits an unknown model and writes null for a missing native ID ($a3)"
  a4="$(env -i PATH="$PATH" HERDR_ENV=1 CLAUDE_CODE_SESSION_ID=c-2 CHIRP_SESSION_ID=x-inherited "$AUTH" --tool 'Claude Code' --model opus 2>/dev/null)"
  [[ "$a4" == $'Co-Authored-By: Claude Code\nAI-Assisted-By: opus\nSESSION-ID: c-2\nXIRP-SESSION-ID: null' ]] \
    && ok "inside a herdr pane handoff-author ignores an inherited Xirp ID" || bad "inside a herdr pane handoff-author ignores an inherited Xirp ID ($a4)"
  grep -q 'handoff-author' "$SKILL/SKILL.md" && ok "SKILL.md documents handoff-author" || bad "SKILL.md documents handoff-author"
fi

# ---------------------------------------------------------------- installer (project level)
if run_section install; then
  printf 'installer\n'
  target="$tmp/install-target"; git init -q -b main "$target"
  printf 'node_modules/\n' > "$target/.gitignore"
  bash "$ROOT/scripts/skills/install.sh" --target "$target" >/dev/null 2>&1
  bash "$ROOT/scripts/skills/install.sh" --target "$target" >/dev/null 2>&1
  [[ "$(grep -cx '/.agent-handoff/' "$target/.gitignore")" == "1" ]] \
    && ok "adds /.agent-handoff/ to .gitignore exactly once" || bad "adds /.agent-handoff/ to .gitignore exactly once"
  grep -qx 'node_modules/' "$target/.gitignore" && ok "keeps existing ignore rules" || bad "keeps existing ignore rules"
  git -C "$target" check-ignore -q .agent-handoff/roles.yaml \
    && git -C "$target" check-ignore -q .agent-handoff/add-export/01-implement.yaml \
    && ok "handoff files are ignored by effect" || bad "handoff files are ignored by effect"
  [[ -f "$target/.agent-handoff/roles.yaml" ]] && cmp -s "$SKILL/roles.example.yaml" "$target/.agent-handoff/roles.yaml" \
    && ok "seeds roles.yaml from the example when missing" || bad "seeds roles.yaml from the example when missing"
  printf '# my edits\n' >> "$target/.agent-handoff/roles.yaml"
  edited="$(cat "$target/.agent-handoff/roles.yaml" 2>/dev/null)"
  bash "$ROOT/scripts/skills/install.sh" --target "$target" >/dev/null 2>&1
  [[ -n "$edited" && "$(cat "$target/.agent-handoff/roles.yaml")" == "$edited" ]] \
    && ok "never overwrites an existing roles.yaml" || bad "never overwrites an existing roles.yaml"
  [[ -x "$target/.agents/skills/agent-handoff/scripts/handoff-write" && -x "$target/.claude/skills/agent-handoff/scripts/handoff-write" ]] \
    && ok "installs handoff-write under .agents/ and .claude/ skills" || bad "installs handoff-write under .agents/ and .claude/ skills"

  conflict="$tmp/install-conflict"; git init -q -b main "$conflict"
  printf '/.agent-handoff/**\n!/.agent-handoff/roles.yaml\n' > "$conflict/.gitignore"
  out="$(bash "$ROOT/scripts/skills/install.sh" --target "$conflict" 2>&1)"
  if grep -q 'agent-handoff' <<<"$out" && grep -qi 'not ignored' <<<"$out" \
    && [[ "$(head -2 "$conflict/.gitignore")" == $'/.agent-handoff/**\n!/.agent-handoff/roles.yaml' ]] \
    && [[ "$(grep -c 'agent-handoff' "$conflict/.gitignore")" == "2" ]]; then
    ok "reports a negation that un-ignores handoff files and leaves it unchanged"
  else
    bad "reports a negation that un-ignores handoff files and leaves it unchanged"
  fi

  # roles.example.yaml carries the confirmed defaults and parses.
  ex="$SKILL/roles.example.yaml"
  if [[ -f "$ex" ]] && source "$KV" && [[ "$(kv_get "$ex" review.worktree)" == "shared" && "$(kv_get "$ex" finish.worktree)" == "shared" \
    && "$(kv_get "$ex" finish.trigger)" == "ask" && "$(kv_get "$ex" finish.delivery)" == "local" && "$(kv_get "$ex" max_rounds)" == "3" ]]; then
    ok "example templates default to shared worktrees, ask, local and 3 rounds"
  else
    bad "example templates default to shared worktrees, ask, local and 3 rounds"
  fi
  missing=""
  for role in implement review finish; do
    for k in harness model effort name prompt; do kv_get "$ex" "$role.$k" >/dev/null 2>&1 || missing="$missing $role.$k"; done
  done
  [[ -z "$missing" ]] && ok "every role template sets harness, model, effort, name and prompt" || bad "every role template sets harness, model, effort, name and prompt (missing:$missing)"
  n_author="$(grep -c '^  prompt: .*{author}' "$SKILL/roles.example.yaml")"
  [[ "$n_author" == 3 ]] && ok "every example role prompt asks for the Author identity" || bad "every example role prompt asks for the Author identity ($n_author/3)"
  grep -q 'profile: handoff-net' "$SKILL/roles.example.yaml" && grep -q 'delivery: pr' "$SKILL/roles.example.yaml" \
    && ok "the example explains the Codex network profile for PR delivery" || bad "the example explains the Codex network profile for PR delivery"
  grep -q '^  prompt: .*最終版 Review' "$SKILL/roles.example.yaml" && grep -q '^  prompt: .*Closure' "$SKILL/roles.example.yaml" \
    && ok "the example finish prompt says PR delivery covers the final-version review and the Closure" || bad "the example finish prompt says PR delivery covers the final-version review and the Closure"
  grep -q '^  prompt: "\$openspec-commit.*直接同步主規格' "$SKILL/roles.example.yaml" \
    && ok "the example finish prompt says to sync main specs without asking" || bad "the example finish prompt says to sync main specs without asking"
  rp="$(grep '^  prompt: "\$change-review' "$SKILL/roles.example.yaml")"
  grep -q '由 handoff hook 通知' <<<"$rp" && grep -q '不是排除通知' <<<"$rp" \
    && ok "the example review prompt says the hook notifies the implementer and this is not a notification exclusion" || bad "the example review prompt says the hook notifies the implementer and this is not a notification exclusion"
fi

# ---------------------------------------------------------------- test doubles for xirp, gh and notify
ROUTE="$ROOT/scripts/handoff/handoff-route"
FAKES="$tmp/fakes"; mkdir -p "$FAKES"
cat > "$FAKES/xirp" <<'SH'
#!/usr/bin/env bash
S="$FAKE_XIRP_DIR"; mkdir -p "$S"; printf '%s\n' "$*" >> "$S/calls"
case "$1 $2" in
  "api send")
    [[ -e "$S/create-fail" ]] && exit 1
    json="$5"; n=$(( $(cat "$S/count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$S/count"
    printf '%s\n' "$json" > "$S/create-$n.json"
    jq -c --arg id "sess-$n" '{id:$id, name:.customName}' <<<"$json" >> "$S/sessions"; echo '{}' ;;
  "session list") [[ -e "$S/list-fail" ]] && exit 1; [[ -e "$S/list-null" ]] && { echo '{"sessions":null}'; exit 0; }; [[ -e "$S/list-truncated" ]] && { printf '[]{"sessions":['; exit 0; }; if [[ -s "$S/sessions" ]]; then jq -s '.' "$S/sessions"; else echo '[]'; fi ;;
  "session get") [[ "$3" == missing-* || -e "$S/get-fail" ]] && exit 1
    if [[ -f "$S/session.json" ]]; then jq --arg id "$3" '. + {id:$id}' "$S/session.json"
    else jq -n --arg id "$3" '{id:$id, currentAgent:"claude", model:"fake-model", agentLaunchOptions:{agentName:"claude", options:{model:"opus", effort:"high"}}}'; fi ;;
  "session message") [[ -e "$S/msg-fail" ]] && exit 1; printf '%s\t%s\n' "$3" "$4" >> "$S/messages" ;;
  "session delete") [[ "$3" == missing-* || -e "$S/delete-fail" ]] && exit 1; printf '%s\n' "$3" >> "$S/deleted" ;;
  "project list") jq -n --arg p "$FAKE_PROJECT_PATH" '[{id:"proj-1", path:$p}]' ;;
esac
exit 0
SH
printf '#!/usr/bin/env bash\ntouch "$FAKE_XIRP_DIR/gh-called"\nexit 1\n' > "$FAKES/gh"
# Fake notification hook: declares handoff events, records each call on one line.
cat > "$FAKES/notify.sh" <<'SH'
#!/usr/bin/env bash
# ai-notify-capability: handoff-events
payload="$(cat)"
printf 'event=%s action_required=%s %s\n' "$1" "${NOTIFY_ACTION_REQUIRED:-unset}" "$payload" >> "$FAKE_XIRP_DIR/notified"
[[ "$1" == handoff ]] && printf '%s\n' "$payload" >> "$FAKE_XIRP_DIR/handoff.jsonl"
exit "${FAKE_NOTIFY_RC:-0}"
SH
chmod +x "$FAKES/xirp" "$FAKES/gh" "$FAKES/notify.sh"
# Fake Claude Code and Codex CLIs: only their version is ever asked for.
printf '#!/usr/bin/env bash\necho "2.9.0 (Claude Code)"\n' > "$FAKES/claude"
printf '#!/usr/bin/env bash\necho "codex-cli 0.130.0"\n' > "$FAKES/codex"
# Fake herdr 0.9.5 (state in $FAKE_XIRP_DIR/herdr). Success JSON on stdout, error JSON on stderr with exit 1,
# as the real CLI. Switches (files in the state dir): server-down, busy (count of agent_pane_busy answers),
# not-ready (agent start stops at a dialog), blocked (agent prompt refused), no-native, shell-<pane>
# (the pane runs a shell), no-integration-<kind> (panes: pane->tab; tablabels: tab->label), prompt-timeout (a prompt is taken, then the answer
# times out), prompt-delay (seconds before a prompt is taken), native-<pane> (the native session ID now in that pane), gone-<id> (a closed workspace/tab),
# stall (agent prompt --wait writes the text but answers agent_prompt_stalled), enter-ignored (agent wait after an extra Enter times out).
# As herdr 0.9.5, agent prompt refuses --timeout without --wait (exit 2).
cat > "$FAKES/herdr" <<'SH'
#!/usr/bin/env bash
S="$FAKE_XIRP_DIR/herdr"; mkdir -p "$S"
sess="default"; [[ "${1:-}" == --session ]] && { sess="$2"; shift 2; }
printf '%s\t%s\n' "$sess" "$*" >> "$S/calls"
ok() { jq -c '{id:"1", result:.}'; }
err() { printf '{"id":"1","error":{"code":"%s","message":"%s"}}\n' "$1" "$1" >&2; exit 1; }
opt() { local k="$1"; shift; while [[ $# -gt 0 ]]; do [[ "$1" == "$k" ]] && { printf '%s' "$2"; return; }; shift; done; }
n() { local c; c=$(( $(cat "$S/n-$1" 2>/dev/null || echo 0) + 1 )); echo "$c" > "$S/n-$1"; echo "$c"; }
[[ "$1" == --version ]] && { echo "herdr 0.9.5"; exit 0; }
if [[ "$1 ${2:-}" == "status server" ]]; then
  if [[ -e "$S/server-down" ]]; then jq -nc --arg s "$sess" '{status:"not_running", running:false, session:$s}'
  else jq -nc --arg s "$sess" '{status:"running", running:true, version:"0.9.5", session:$s}'; fi; exit 0
fi
if [[ "$1 ${2:-}" == "integration status" ]]; then
  for k in pi claude codex; do [[ -e "$S/no-integration-$k" ]] && echo "$k: not installed (x)" || echo "$k: current (v1) (x)"; done; exit 0
fi
[[ -e "$S/server-down" ]] && err server_not_running
ws_json() { jq -nc --arg w "$1" --arg l "$2" --arg p "$3" '{workspace_id:$w, label:$l, worktree:{checkout_path:$p}}'; }
new_ws() {  # <path> <label> -> ws id; also makes tab and pane 1
  local w="w$(n ws)"; ws_json "$w" "$2" "$1" >> "$S/workspaces"; echo "$w:t1" >> "$S/tabs"
  printf '%s\t%s\n' "$w:p1" "$w:t1" >> "$S/panes"; printf '%s\t1\n' "$w:t1" >> "$S/tablabels"; echo "$w"
}
case "$1 ${2:-}" in
  "workspace list") touch "$S/workspaces"; jq -sc '{type:"workspace_list", workspaces:.}' "$S/workspaces" | ok ;;
  "workspace create")
    w="$(new_ws "$(opt --cwd "$@")" "$(opt --label "$@")")"
    jq -nc --arg w "$w" --arg l "$(opt --label "$@")" --arg p "$(opt --cwd "$@")" \
      '{type:"workspace_created", workspace:{workspace_id:$w, label:$l, worktree:{checkout_path:$p}}, tab:{tab_id:($w+":t1")}, root_pane:{pane_id:($w+":p1")}}' | ok ;;
  "worktree open")
    p="$(opt --path "$@")"; w="$(jq -r --arg p "$p" 'select(.worktree.checkout_path == $p) | .workspace_id' "$S/workspaces" 2>/dev/null | head -1)"
    if [[ -n "$w" ]]; then already=true; else already=false; w="$(new_ws "$p" "$(opt --label "$@")")"; fi
    jq -nc --arg w "$w" --arg p "$p" --argjson a "$already" \
      '{type:"worktree_opened", already_open:$a, workspace:{workspace_id:$w, worktree:{checkout_path:$p}}, tab:{tab_id:($w+":t1")}, root_pane:{pane_id:($w+":p1")}}' | ok ;;
  "tab create")
    w="$(opt --workspace "$@")"; t="$w:t$(( $(n "tab-$w") + 1 ))"; p="$w:p$(( $(n "pane-$w") + 1 ))"; echo "$t" >> "$S/tabs"
    printf '%s\t%s\n' "$p" "$t" >> "$S/panes"; printf '%s\t%s\n' "$t" "$(opt --label "$@")" >> "$S/tablabels"
    jq -nc --arg t "$t" --arg p "$p" '{type:"tab_created", tab:{tab_id:$t}, root_pane:{pane_id:$p}}' | ok ;;
  "tab rename") printf '%s\t%s\n' "$3" "$4" >> "$S/renamed"; printf '%s\t%s\n' "$3" "$4" >> "$S/tablabels"; jq -nc '{type:"ok"}' | ok ;;
  "pane get")
    t="$(awk -F'\t' -v p="$3" '$1 == p {t = $2} END {print t}' "$S/panes" 2>/dev/null)"; [[ -n "$t" ]] || err pane_not_found
    jq -nc --arg p "$3" --arg t "$t" --arg w "${t%%:*}" '{type:"pane_info", pane:{pane_id:$p, tab_id:$t, workspace_id:$w}}' | ok ;;
  "tab get")
    l="$(awk -F'\t' -v t="$3" '$1 == t {l = $2} END {print l}' "$S/tablabels" 2>/dev/null)"
    jq -nc --arg t "$3" --arg l "$l" '{type:"tab_info", tab:{tab_id:$t, label:$l}}' | ok ;;
  "workspace get")
    jq -c --arg w "$3" 'select(.workspace_id == $w) | {type:"workspace_info", workspace:.}' "$S/workspaces" | ok ;;
  "agent start")
    name="$3"; shift 3; kind="$(opt --kind "$@")"; pane="$(opt --pane "$@")"
    if [[ -s "$S/busy" ]]; then b="$(cat "$S/busy")"; if (( b > 0 )); then echo $((b - 1)) > "$S/busy"; err agent_pane_busy; fi; fi
    printf '%s\n' "$kind" > "$S/pane-$pane"; rm -f "$S/shell-$pane"
    [[ -e "$S/not-ready" ]] && err agent_not_ready
    jq -nc --arg p "$pane" --arg k "$kind" --arg n "$name" '{type:"agent_started", agent:{pane_id:$p, agent:$k, name:$n, agent_status:"idle"}, argv:[]}' | ok ;;
  "agent get")
    p="$3"; [[ -f "$S/pane-$p" && ! -e "$S/shell-$p" ]] || err agent_not_found
    v="native-$p"; [[ -f "$S/native-$p" ]] && v="$(cat "$S/native-$p")"
    jq -nc --arg p "$p" --arg k "$(cat "$S/pane-$p")" --arg v "$v" --argjson nn "$([[ -e "$S/no-native" ]] && echo true || echo false)" \
      '{type:"agent_info", agent:{pane_id:$p, agent:$k, agent_status:"idle", agent_session:(if $nn then null else {agent:$k, kind:"id", source:"herdr", value:$v} end)}}' | ok ;;
  "agent prompt")
    if [[ " $* " == *" --timeout "* && " $* " != *" --wait "* ]]; then echo "--timeout requires --wait" >&2; exit 2; fi
    p="$3"; [[ -f "$S/pane-$p" && ! -e "$S/shell-$p" ]] || err agent_not_found
    [[ -e "$S/blocked" || -e "$S/not-ready" ]] && err agent_blocked  # an agent at a startup dialog stays blocked
    [[ -s "$S/prompt-delay" ]] && sleep "$(cat "$S/prompt-delay")"  # a slow answer, to overlap two callers
    printf '%s\t%s\n' "$p" "$4" >> "$S/prompts"; [[ -e "$S/prompt-timeout" ]] && err timeout
    [[ -e "$S/stall" && " $* " == *" --wait "* ]] && err agent_prompt_stalled  # text written, the agent never started
    jq -nc --arg p "$p" '{type:"agent_prompted", agent:{pane_id:$p}}' | ok ;;
  "agent send-keys") [[ -f "$S/pane-$3" ]] || err agent_not_found; jq -nc '{type:"keys_sent"}' | ok ;;
  "agent wait")
    [[ -f "$S/pane-$3" ]] || err agent_not_found; [[ -e "$S/enter-ignored" ]] && err timeout
    jq -nc --arg p "$3" '{type:"agent_waited", agent:{pane_id:$p, agent_status:"working"}}' | ok ;;
  "workspace close"|"tab close"|"pane close")
    [[ -e "$S/gone-$3" ]] && err "${1}_not_found"
    path="$(jq -r --arg w "${3%%:*}" 'select(.workspace_id == $w) | .worktree.checkout_path' "$S/workspaces" 2>/dev/null | head -1)"
    printf '%s %s %s exists=%s\n' "$1" "$2" "$3" "$([[ -d "$path" ]] && echo yes || echo no)" >> "$S/closed"; jq -nc '{type:"ok"}' | ok ;;
  *) err "unsupported: $*" ;;
esac
SH
chmod +x "$FAKES/claude" "$FAKES/codex" "$FAKES/herdr"
# Fake Herdr desktop app CLI 0.1.16 (state in $FAKE_XIRP_DIR/happ). Each call is recorded as a JSON array in happ/calls.
# do space.new|tab.new answer {space, tab, pane, terminal} and create the terminal for the fake hc; an errors is
# { "error": "..." } with exit 1. Switch: app-closed (no window: a message on stderr, exit 2, as the real CLI).
cat > "$FAKES/herdr-app" <<'SH'
#!/usr/bin/env bash
A="$FAKE_XIRP_DIR/happ"; H="$FAKE_XIRP_DIR/hc"; mkdir -p "$A" "$H"; touch "$A/spaces" "$A/tabs"
printf '%s\0' "$@" | jq -Rsc 'split("\u0000")[:-1]' >> "$A/calls"
[[ "$1" == --version ]] && { echo "herdr-app 0.1.16"; exit 0; }
[[ -e "$A/app-closed" ]] && { echo "herdr-app: no Herdr window at x/herdr-app.sock: No such file or directory (os error 2)" >&2; exit 2; }
opt() { local k="--$1"; shift; while [[ $# -gt 0 ]]; do [[ "$1" == "$k" ]] && { printf '%s' "$2"; return; }; shift; done; }
n() { local c; c=$(( $(cat "$A/n-$1" 2>/dev/null || echo 0) + 1 )); echo "$c" > "$A/n-$1"; echo "$c"; }
col() { awk -F'\t' -v k="$2" -v c="$3" '$1 == k {print $c}' "$A/$1"; }
case "$1" in
  status) jq -n '{space:"spU", tab:"tbU", errors:[]}' ;;
  ls) jq -n --rawfile s "$A/spaces" --rawfile t "$A/tabs" '($t | split("\n") | map(select(length > 0) | split("\t"))) as $tabs
        | {spaces: [$s | split("\n")[] | select(length > 0) | split("\t") as $sp | {id:$sp[0], name:$sp[1], folder:$sp[2],
           tabs: [$tabs[] | select(.[1] == $sp[0]) | {id:.[0], name:.[2], terminals:[{terminal:.[3]}]}]}]}' ;;
  do)
    cmd="$2"; shift 2
    case "$cmd" in
      space.new|tab.new)
        if [[ "$cmd" == space.new ]]; then sp="sp$(n space)"; printf '%s\t%s\t%s\n' "$sp" "$(opt name "$@")" "$(opt folder "$@")" >> "$A/spaces"; tn="$(opt tab "$@")"
        else sp="$(opt space "$@")"; [[ -n "$(col spaces "$sp" 1)" ]] || { echo "{ \"error\": \"no space $sp\" }"; exit 1; }; tn="$(opt name "$@")"; fi
        tb="tb$(n tab)"; t="t$(n term)"; printf '%s\t%s\t%s\t%s\n' "$tb" "$sp" "$tn" "$t" >> "$A/tabs"
        turn=1; [[ -e "$H/no-start" || -z "$(opt task "$@")" ]] && turn=0
        jq -n --arg t "$t" --argjson argv "$(opt argv "$@")" --arg w "$(col spaces "$sp" 2) / $tn" --arg sp "$sp" --arg tb "$tb" --argjson turn "$turn" \
          '{address:$t, state:"live", argv:$argv, turn:$turn, labels:{"herdr.space":$sp, "herdr.tab":$tb, where:$w}}' > "$H/term-$t"
        jq -n --arg sp "$sp" --arg tb "$tb" --arg t "$t" '{space:$sp, tab:$tb, pane:"p1", terminal:$t}' ;;
      space.close|tab.close)
        id="$(opt id "$@")"; f=spaces; [[ "$cmd" == tab.close ]] && f=tabs
        [[ -n "$(col "$f" "$id" 1)" ]] || { echo "{ \"error\": \"no ${cmd%.close} $id\" }"; exit 1; }
        [[ "$(opt confirmed "$@")" == true ]] || { echo '{ "error": "not confirmed" }'; exit 1; }
        sp="$id"; [[ "$f" == tabs ]] && sp="$(col tabs "$id" 2)"; folder="$(col spaces "$sp" 3)"
        for t in $(awk -F'\t' -v id="$id" '$1 == id || $2 == id {print $4}' "$A/tabs"); do
          jq '.state = "finished"' "$H/term-$t" > "$H/term-$t.tmp" && mv "$H/term-$t.tmp" "$H/term-$t"
        done
        awk -F'\t' -v id="$id" '$1 != id && $2 != id' "$A/tabs" > "$A/tabs.tmp" && mv "$A/tabs.tmp" "$A/tabs"
        [[ "$f" == spaces ]] && { awk -F'\t' -v id="$id" '$1 != id' "$A/spaces" > "$A/spaces.tmp" && mv "$A/spaces.tmp" "$A/spaces"; }
        printf '%s %s exists=%s\n' "$cmd" "$id" "$([[ -d "$folder" ]] && echo yes || echo no)" >> "$A/closed"; echo '"ok"' ;;
      *) echo "{ \"error\": \"unsupported $cmd\" }"; exit 1 ;;
    esac ;;
  *) exit 2 ;;
esac
SH
# Fake herdr-core hc 0.1.21 (terminals in $FAKE_XIRP_DIR/hc/term-<t>, made by the fake herdr-app). Errors are
# {"error":{"kind":...}} with exit 3. Switches: core-down, blocked (status blocked, kind permission; send refuses),
# no-start (the app's --task is never taken: turn stays 0), send-unstarted (send answers started:false),
# finished-<t> (the terminal has finished), shell-<t> (it runs a shell).
cat > "$FAKES/hc" <<'SH'
#!/usr/bin/env bash
H="$FAKE_XIRP_DIR/hc"; mkdir -p "$H"; printf '%s\n' "$*" >> "$H/calls"
[[ "$1" == --version || "$1" == -V ]] && { echo "hc 0.1.21"; exit 0; }
err() { jq -nc --arg k "$1" '{error:{kind:$k, message:$k}}'; exit 3; }
sw() { [[ -e "$H/$1" ]] && echo true || echo false; }
args=(); for a in "$@"; do [[ "$a" == --json || "$a" == -- ]] || args+=("$a"); done; set -- "${args[@]}"
if [[ "$1 ${2:-}" == "server status" ]]; then
  [[ -e "$H/core-down" ]] && { echo "hc: herdr-core is not running" >&2; exit 1; }; jq -nc '{version:"0.1.21", live:1}'; exit 0
fi
[[ -e "$H/core-down" ]] && err unavailable
t="${2:-}"; f="$H/term-$t"
case "$1" in
  get) [[ -f "$f" ]] || err not_found
    jq -c --argjson fin "$(sw "finished-$t")" --argjson sh "$(sw "shell-$t")" --argjson bl "$(sw blocked)" '.argv[0] as $h
      | if $fin or .state == "finished" then .state = "finished" | .foreground = null | .status = null
        elif $sh then .foreground = {name:"zsh", argv:["zsh"], cwd:"/", pid:2} | .status = null
        else .foreground = (if $h == "pi" then {name:"node", argv:["node", "/x/bin/pi"]} else {name:$h, argv:[$h]} end)
          | .status = (if $bl then {app:$h, state:"blocked", kind:"permission"} else {app:$h, state:"idle"} end) end' "$f" ;;
  send) [[ -f "$f" ]] || err not_found
    [[ -e "$H/finished-$t" || "$(jq -r .state "$f")" == finished ]] && err finished; [[ -e "$H/blocked" ]] && err blocked
    printf '%s\t%s\n' "$t" "$3" >> "$H/sends"; turn="$(jq .turn "$f")"; jq '.turn += 1' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    jq -nc --argjson n "$turn" --argjson s "$([[ -e "$H/send-unstarted" ]] && echo false || echo true)" '{started:$s, status:"idle", turn:$n}' ;;
  rm) [[ -f "$f" ]] || err not_found; [[ "$(jq -r .state "$f")" == finished ]] || err live
    printf '%s\n' "$t" >> "$H/removed"; rm -f "$f"; jq -nc --arg t "$t" '{removed:$t}' ;;
  *) err invalid_params ;;
esac
SH
chmod +x "$FAKES/herdr-app" "$FAKES/hc"
# hook_home <dir>: a HOME where handoff-route is registered for Claude Code and Codex.
hook_home() {
  mkdir -p "$1/.claude" "$1/.codex"
  jq -n '{hooks:{Stop:[{matcher:"",hooks:[{type:"command",command:"bash \"~/.config/wk-workflow/handoff/handoff-route\""}]}]}}' | tee "$1/.claude/settings.json" > "$1/.codex/hooks.json"
}
REAL_HOME="$HOME"; TEST_HOME="$tmp/home-test"; hook_home "$TEST_HOME"
# Commands run with the test HOME, unless a test sets its own HOME for the call.
thome() { if [[ "$HOME" == "$REAL_HOME" ]]; then printf '%s' "$TEST_HOME"; else printf '%s' "$HOME"; fi; }
herdr_calls() { cat "$FAKE_XIRP_DIR/herdr/calls" 2>/dev/null; }
herdr_prompts() { cat "$FAKE_XIRP_DIR/herdr/prompts" 2>/dev/null; }

# new_loop <dir> [review-mode] [finish-trigger] [max] : repo with a loop for change add-export
new_loop() {
  local d="$1" mode="${2:-shared}" trig="${3:-ask}" max="${4:-3}"
  new_repo "$d"; git -C "$d" switch -q -c feature/add-export
  mkdir -p "$d/.agent-handoff/add-export"
  cat > "$d/.agent-handoff/add-export/loop.yaml" <<YAML
change: add-export
max_rounds: $max
implementer:
  session: impl-1
  worktree: $d
reviewer:
  session:
  worktree:
finish:
  session:
  worktree:
  trigger: $trig
  delivery: local
review_template:
  worktree: $mode
  harness: codex
  model: gpt-6.1-sol
  effort: high
  name: "codex - review - {change}"
  prompt: "\$change-review {change} commit {head} round {round} {author}"
finish_template:
  worktree: shared
  harness: codex
  model: gpt-5.6-terra
  effort: medium
  name: "codex - finish - {change}"
  prompt: "\$openspec-commit {change} delivery {delivery}"
YAML
}
fresh_state() { export FAKE_XIRP_DIR="$tmp/state-$1"; rm -rf "$FAKE_XIRP_DIR"; mkdir -p "$FAKE_XIRP_DIR/herdr" "$FAKE_XIRP_DIR/happ" "$FAKE_XIRP_DIR/hc"; }
use_project() { export FAKE_PROJECT_PATH="$(dirname "$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)")"; }
# Hook mode run synchronously (HANDOFF_ROUTE_WAIT=1), as when an agent stops.
route_in() { (cd "$1" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID="${T_SID-chirp-1}" "$ROUTE" </dev/null); }
hw() { local d="$1"; shift; (cd "$d" && "$WRITE" --change add-export "$@") >/dev/null 2>&1; }
commit_in() { printf '%s\n' "$2" > "$1/work.txt"; git -C "$1" add work.txt; git -C "$1" commit -qm "$2"; }
msgs() { cat "$FAKE_XIRP_DIR/messages" 2>/dev/null; }
notes() { cat "$FAKE_XIRP_DIR/notified" 2>/dev/null; }
created() { cat "$FAKE_XIRP_DIR/count" 2>/dev/null || echo 0; }

# ---------------------------------------------------------------- routing hook
if run_section route; then
  printf 'routing hook\n'
  source "$KV"

  A="$tmp/route-a"; new_loop "$A"; use_project "$A"; fresh_state r1
  route_in "$A"
  [[ "$(created)" == 0 && -z "$(msgs)" && -z "$(notes)" ]] && ok "no record: nothing is sent" || bad "no record: nothing is sent"

  B0="$tmp/route-noloop"; new_repo "$B0"; hw "$B0" --role implement --status done --head HEAD
  route_in "$B0"
  [[ "$(created)" == 0 && -z "$(msgs)" ]] && ok "record without loop.yaml: nothing is sent" || bad "record without loop.yaml: nothing is sent"

  commit_in "$A" one; X="$(git -C "$A" rev-parse HEAD)"; hw "$A" --role implement --status done --head HEAD
  route_in "$A"
  loop="$A/.agent-handoff/add-export/loop.yaml"
  if [[ "$(created)" == 1 ]] && jq -e --arg w "$A" '.worktreePath==$w and .customName=="codex - review - add-export" and .agent.agentName=="codex" and .agent.options.model=="gpt-6.1-sol" and .agent.options.reasoning_effort=="high"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$loop" reviewer.session)" == "sess-1" && "$(kv_get "$loop" reviewer.worktree)" == "$A" ]]; then
    ok "first implement handoff opens the reviewer in the shared worktree and records it"
  else
    bad "first implement handoff opens the reviewer in the shared worktree and records it"
  fi
  jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null | grep -q "commit $X round 1" && ok "reviewer prompt names the handed-over commit and round" || bad "reviewer prompt names the handed-over commit and round"
  g="$(jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null)"
  grep -qF 'agent-handoff/scripts/handoff-author --tool Codex --model gpt-6.1-sol' <<<"$g" && ! grep -q '{author}' <<<"$g" && ! grep -q '不要寫 null' <<<"$g" \
    && ok "reviewer prompt has it attach the Author block from handoff-author with its tool and template model" || bad "reviewer prompt has it attach the Author block from handoff-author with its tool and template model"
  grep -q 'action=reviewer:opened:sess-1 .*model=' "$A/.agent-handoff/add-export/routing.log" 2>/dev/null && ok "routing log records the action and the session's model" || bad "routing log records the action and the session's model"
  grep -q 'action=reviewer:opened:sess-1 session=chirp-1 ' "$A/.agent-handoff/add-export/routing.log" 2>/dev/null \
    && ok "outside herdr the routing log names the Xirp session" || bad "outside herdr the routing log names the Xirp session"
  route_in "$A"
  [[ "$(created)" == 1 ]] && ok "the same record is routed only once" || bad "the same record is routed only once"
  HE="$tmp/route-herdr-env"; new_loop "$HE"; use_project "$HE"; fresh_state r12; hw "$HE" --role implement --status done --head HEAD
  (export HERDR_ENV=1; T_SID=chirp-inherited route_in "$HE")
  [[ "$(created)" == 1 ]] && grep -q 'action=reviewer:opened' "$HE/.agent-handoff/add-export/routing.log" && ! grep -q 'chirp-inherited' "$HE/.agent-handoff/add-export/routing.log" \
    && ok "inside a herdr pane the routing log does not name an inherited Xirp session" || bad "inside a herdr pane the routing log does not name an inherited Xirp session ($(cat "$HE/.agent-handoff/add-export/routing.log" 2>/dev/null))"

  printf 'SECRET-FINDING detail\n' > "$A/report-r1.md"; mkdir -p "$A/.git/info"; printf '/report-*.md\n' >> "$A/.git/info/exclude"
  hw "$A" --role review --status done --verdict changes-required --head HEAD --report report-r1.md
  route_in "$A"
  if msgs | grep -q $'^impl-1\t' && msgs | grep -q "$A/report-r1.md" && msgs | grep -q "$X" && ! msgs | grep -q SECRET-FINDING; then
    ok "changes-required asks the implementer with the absolute report path and no report content"
  else
    bad "changes-required asks the implementer with the absolute report path and no report content"
  fi

  commit_in "$A" two; Y="$(git -C "$A" rev-parse HEAD)"; hw "$A" --role implement --status done --head HEAD
  route_in "$A"
  [[ "$(created)" == 1 ]] && msgs | grep -q $'^sess-1\t.*'"$Y" && ok "later implement handoffs message the same reviewer" || bad "later implement handoffs message the same reviewer"
  ! grep -q 'host' "$loop" && msgs | grep -q $'^sess-1\t' && ok "a loop.yaml without host fields is routed through Xirp" || bad "a loop.yaml without host fields is routed through Xirp"

  before="$(msgs | wc -l)"
  hw "$A" --role review --status blocked --verdict changes-required --head HEAD --report report-r1.md --note "reply timed out"
  route_in "$A"
  [[ "$(msgs | wc -l)" == "$before" ]] && notes | grep -q 'reply timed out' && ok "a blocked review only notifies the user" || bad "a blocked review only notifies the user"
  notes | grep -q '^event=handoff action_required=unset ' && ! notes | grep -q 'action_required=true' \
    && ok "handoff notices use the handoff event without an environment override" || bad "handoff notices use the handoff event without an environment override"

  A2="$tmp/route-limit"; new_loop "$A2" shared ask 2; use_project "$A2"; fresh_state r2
  printf 'r\n' > "$A2/r.md"; mkdir -p "$A2/.git/info"; printf '/r.md\n' >> "$A2/.git/info/exclude"
  hw "$A2" --role implement --status done --head HEAD; hw "$A2" --role review --status done --verdict changes-required --head HEAD --report r.md
  hw "$A2" --role implement --status done --head HEAD; hw "$A2" --role review --status done --verdict changes-required --head HEAD --report r.md
  route_in "$A2"
  [[ -z "$(msgs)" ]] && notes | grep -q '2 輪上限' && ok "round limit stops automatic repair and notifies the user" || bad "round limit stops automatic repair and notifies the user"

  A3="$tmp/route-pass"; new_loop "$A3" shared ask; use_project "$A3"; fresh_state r3
  printf 'r\n' > "$A3/r.md"; mkdir -p "$A3/.git/info"; printf '/r.md\n' >> "$A3/.git/info/exclude"
  hw "$A3" --role implement --status done --head HEAD; hw "$A3" --role review --status done --verdict pass --head HEAD --report r.md
  route_in "$A3"
  [[ "$(created)" == 0 ]] && notes | grep -q 'handoff-finish add-export' && ok "pass with trigger ask only notifies the user" || bad "pass with trigger ask only notifies the user"

  A4="$tmp/route-auto"; new_loop "$A4" shared auto; use_project "$A4"; fresh_state r4
  printf 'r\n' > "$A4/r.md"; mkdir -p "$A4/.git/info"; printf '/r.md\n' >> "$A4/.git/info/exclude"
  hw "$A4" --role implement --status done --head HEAD; hw "$A4" --role review --status done --verdict pass --head HEAD --report r.md
  route_in "$A4"
  if [[ "$(created)" == 1 ]] && jq -e '.customName=="codex - finish - add-export" and .agent.options.model=="gpt-5.6-terra"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$A4/.agent-handoff/add-export/loop.yaml" finish.session)" == "sess-1" ]]; then
    ok "pass with trigger auto opens the finish session"
  else
    bad "pass with trigger auto opens the finish session"
  fi
  hw "$A4" --role finish --status done --head HEAD
  before="$(created)"; route_in "$A4"
  [[ "$(created)" == "$before" ]] && notes | grep -q '收尾結束' && ok "a finish record only notifies the user" || bad "a finish record only notifies the user"
  BF="$tmp/route-finish-blocked"; new_loop "$BF"; use_project "$BF"; fresh_state r11; hw "$BF" --role finish --status blocked --head HEAD --note "push rejected"; route_in "$BF"
  notes | grep -q 'handoff-finish add-export' && notes | grep -q 'push rejected' \
    && ok "a blocked finish notice gives the reason and the retry command" || bad "a blocked finish notice gives the reason and the retry command"

  A5="$tmp/route-stale-auto"; new_loop "$A5" shared auto; use_project "$A5"; fresh_state r5
  printf 'r\n' > "$A5/r.md"; mkdir -p "$A5/.git/info"; printf '/r.md\n' >> "$A5/.git/info/exclude"
  hw "$A5" --role implement --status done --head HEAD; hw "$A5" --role review --status done --verdict pass --head HEAD --report r.md
  printf 'x\n' > "$A5/dirty.txt"; git -C "$A5" add dirty.txt
  route_in "$A5"
  [[ "$(created)" == 0 ]] && notes | grep -q 'add-export' && ok "auto finish refuses an unclean pass" || bad "auto finish refuses an unclean pass"

  A6="$tmp/route-unclean"; new_loop "$A6"; use_project "$A6"; fresh_state r6
  hw "$A6" --role implement --status done --head HEAD; printf 'wip\n' > "$A6/wip.txt"
  route_in "$A6"
  [[ "$(created)" == 0 ]] && notes | grep -q '未提交' && ok "uncommitted changes stop the handoff" || bad "uncommitted changes stop the handoff"

  A7="$tmp/route-head"; new_loop "$A7"; use_project "$A7"; fresh_state r7
  hw "$A7" --role implement --status done --head HEAD; commit_in "$A7" moved
  route_in "$A7"
  [[ "$(created)" == 0 ]] && notes | grep -q 'HEAD' && ok "a moved HEAD stops the handoff" || bad "a moved HEAD stops the handoff"

  A8="$tmp/route-noxirp"; new_loop "$A8"; fresh_state r8; hw "$A8" --role implement --status done --head HEAD
  (cd "$A8" && PATH="/usr/bin:/bin" HANDOFF_NOTIFY="$FAKES/notify.sh" "$ROUTE" --foreground </dev/null); rc=$?
  [[ "$rc" == 0 && "$(created)" == 0 && -z "$(notes)" && ! -e "$A8/.agent-handoff/add-export/.routed" ]] && ok "without xirp the hook does nothing and exits 0" || bad "without xirp the hook does nothing and exits 0"

  # Separate review worktree: two rounds A -> B -> A -> B.
  WA="$tmp/route-sep"; new_loop "$WA" new ask; use_project "$WA"; fresh_state r9
  WB="${WA}-review"
  commit_in "$WA" first; X="$(git -C "$WA" rev-parse HEAD)"; hw "$WA" --role implement --status done --head HEAD
  route_in "$WA"
  lb="$WB/.agent-handoff/add-export/loop.yaml"
  if [[ -d "$WB" && "$(git -C "$WB" rev-parse HEAD)" == "$X" && -f "$lb" ]] \
    && [[ "$(kv_get "$lb" reviewer.worktree)" == "$WB" && "$(kv_get "$loop" reviewer.worktree 2>/dev/null)" != "x" ]] \
    && [[ "$(kv_get "$WA/.agent-handoff/add-export/loop.yaml" reviewer.worktree)" == "$WB" ]] \
    && jq -e --arg w "$WB" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$lb" reviewer.session)" == "sess-1" && "$(kv_get "$WA/.agent-handoff/add-export/loop.yaml" reviewer.session)" == "sess-1" ]]; then
    ok "new review worktree is created at the head and both loop copies list it"
  else
    bad "new review worktree is created at the head and both loop copies list it"
  fi
  mkdir -p "$WB/reviews"; printf 'finding\n' > "$WB/reviews/r1.md"; mkdir -p "$(git -C "$WB" rev-parse --path-format=absolute --git-common-dir)/info"; printf '/reviews/\n' >> "$(git -C "$WB" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  hw "$WB" --role review --status done --verdict changes-required --head HEAD --report reviews/r1.md
  route_in "$WB"
  [[ -f "$WB/.agent-handoff/add-export/02-review.yaml" ]] && msgs | grep -q $'^impl-1\t.*'"$WB/reviews/r1.md" \
    && ok "review in B is numbered 02 and the implementer gets B's absolute report path" || bad "review in B is numbered 02 and the implementer gets B's absolute report path"
  commit_in "$WA" second; Y="$(git -C "$WA" rev-parse HEAD)"; hw "$WA" --role implement --status done --head HEAD
  route_in "$WA"
  [[ -f "$WA/.agent-handoff/add-export/03-implement.yaml" && "$(git -C "$WB" rev-parse HEAD)" == "$Y" ]] && msgs | grep -q $'^sess-1\t.*'"$Y" \
    && ok "round 2 moves B to the new head before messaging the reviewer" || bad "round 2 moves B to the new head before messaging the reviewer"
  hw "$WB" --role review --status done --verdict pass --head HEAD --report reviews/r1.md
  route_in "$WB"
  [[ -f "$WB/.agent-handoff/add-export/04-review.yaml" ]] && notes | grep -q 'handoff-finish add-export' \
    && ok "pass in B is numbered 04 and notifies the user" || bad "pass in B is numbered 04 and notifies the user"
  commit_in "$WA" third; hw "$WA" --role implement --status done --head HEAD
  printf 'leftover\n' > "$WB/leftover.txt"; before="$(msgs | wc -l)"
  route_in "$WA"
  [[ "$(git -C "$WB" rev-parse HEAD)" == "$Y" && "$(msgs | wc -l)" == "$before" ]] && notes | grep -q '審查 worktree' \
    && ok "an unclean review worktree is not moved and the reviewer is not messaged" || bad "an unclean review worktree is not moved and the reviewer is not messaged"

  AH="$tmp/route-bg"; new_loop "$AH"; use_project "$AH"; fresh_state r10; hw "$AH" --role implement --status done --head HEAD
  start=$SECONDS
  (cd "$AH" && printf '{"hook_event_name":"Stop"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE"); rc=$?
  quick=$(( SECONDS - start ))
  for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$AH/.agent-handoff/add-export/.routed" ]] && break; sleep 0.5; done
  [[ "$rc" == 0 && "$quick" -le 1 && "$(created)" == 1 ]] && ok "hook mode returns at once and routes in the background" || bad "hook mode returns at once and routes in the background"

  [[ ! -e "$tmp/state-r1/gh-called" && ! -e "$tmp/state-r9/gh-called" ]] && ! compgen -G "$tmp/state-*/gh-called" >/dev/null \
    && ok "routing never calls gh" || bad "routing never calls gh"
fi

# ---------------------------------------------------------------- handoff notifications
jl() { cat "$FAKE_XIRP_DIR/handoff.jsonl" 2>/dev/null; }
kinds() { jl | jq -r .kind 2>/dev/null | paste -sd' ' -; }
jt() { jl | tail -1 | jq -e "$@" >/dev/null 2>&1; }
ncount() { if [[ -f "$FAKE_XIRP_DIR/notified" ]]; then wc -l < "$FAKE_XIRP_DIR/notified" | tr -d ' '; else echo 0; fi; }
routed() { grep -qxF "$2" "$1/.agent-handoff/add-export/.routed" 2>/dev/null; }
lset() { (source "$ROOT/scripts/handoff/lib/handoff.sh" && kv_set "$@"); }
rpt() { printf 'r\n' > "$1/r.md"; mkdir -p "$1/.git/info"; printf '/r.md\n' >> "$1/.git/info/exclude"; }
# one_record <dir> <state> <handoff-write args...>: fresh loop and state with one record written
one_record() { local d="$1" s="$2"; shift 2; new_loop "$d"; use_project "$d"; fresh_state "$s"; rpt "$d"; hw "$d" "$@"; }

if run_section notify; then
  printf 'handoff notifications\n'
  source "$KV"

  N="$tmp/n-loop"; new_loop "$N"; use_project "$N"; fresh_state n1; rpt "$N"
  commit_in "$N" one; X="$(git -C "$N" rev-parse HEAD)"; hw "$N" --role implement --status done --head HEAD
  route_in "$N"
  notes | grep -q '^event=handoff action_required=unset ' && ! notes | grep -q 'action_required=true' \
    && ok "notifies through the handoff event without an environment override" || bad "notifies through the handoff event without an environment override"
  jt --arg c "${X:0:7}" --arg w "$N" '.kind=="implement" and .change=="add-export" and .round=="1" and .commit==$c and .cwd==$w and (.next|test("審查者")) and (.next|test("1"))' \
    && ok "implementation handover names change, round, 7-character commit and the reviewer step" || bad "implementation handover names change, round, 7-character commit and the reviewer step ($(jl | tail -1))"
  jt '.agent=="Claude / fake-model / high"' && ok "agent label comes from Xirp's tool, model and effort" || bad "agent label comes from Xirp's tool, model and effort ($(jl | tail -1))"
  hw "$N" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$N"
  jt '.kind=="review" and .verdict=="changes-required" and .round=="1" and (.next|test("實作者"))' \
    && ok "changes-required sends a review notice that the implementer was asked" || bad "changes-required sends a review notice that the implementer was asked ($(jl | tail -1))"
  commit_in "$N" two; Y="$(git -C "$N" rev-parse HEAD)"; hw "$N" --role implement --status done --head HEAD; route_in "$N"
  jt --arg c "${Y:0:7}" '.kind=="implement" and .round=="2" and .commit==$c and (.next|test("第 2 輪"))' \
    && ok "a later handover names round 2 and its commit" || bad "a later handover names round 2 and its commit ($(jl | tail -1))"
  hw "$N" --role review --status done --verdict pass --head HEAD --report r.md; route_in "$N"
  jt '.kind=="attention" and (.next|test("handoff-finish add-export"))' \
    && ok "a pass with trigger ask is an attention notice to run handoff-finish" || bad "a pass with trigger ask is an attention notice to run handoff-finish ($(jl | tail -1))"
  hw "$N" --role finish --status done --head HEAD; route_in "$N"
  jt '.kind=="finish"' && ok "a finish record sends a finish notice" || bad "a finish record sends a finish notice"
  [[ "$(kinds)" == "implement review implement attention finish" ]] && ok "notices follow the loop in order" || bad "notices follow the loop in order ($(kinds))"
  before="$(ncount)"; route_in "$N"
  [[ "$(ncount)" == "$before" ]] && ok "an agent stopping again sends nothing new" || bad "an agent stopping again sends nothing new"

  NA="$tmp/n-auto"; new_loop "$NA" shared auto; use_project "$NA"; fresh_state n2; rpt "$NA"
  hw "$NA" --role implement --status done --head HEAD; hw "$NA" --role review --status done --verdict pass --head HEAD --report r.md
  route_in "$NA"
  [[ "$(created)" == 1 && "$(kinds)" == review ]] && jt '.verdict=="pass" and (.next|test("收尾"))' \
    && ok "a pass with trigger auto opens finish and sends a review notice" || bad "a pass with trigger auto opens finish and sends a review notice ($(kinds))"

  # Agent information
  agent_case() {  # <state> <session.json or empty> → agent field of the implementation notice
    one_record "$tmp/n-agent-$1" "$1" --role implement --status done --head HEAD
    [[ -n "$2" ]] && printf '%s\n' "$2" > "$FAKE_XIRP_DIR/session.json"
    route_in "$tmp/n-agent-$1"; jl | tail -1 | jq -r .agent
  }
  [[ "$(agent_case a1 '{"currentAgent":"codex","model":"gpt-6.1-sol","agentLaunchOptions":{"options":{"reasoning_effort":null}}}')" == "Codex / gpt-6.1-sol" ]] \
    && ok "an unknown effort is left out of the agent label" || bad "an unknown effort is left out of the agent label"
  [[ "$(agent_case a2 '{"currentAgent":"codex","model":"gpt-6.1-sol","agentLaunchOptions":{"options":{"reasoning_effort":"xhigh"}}}')" == "Codex / gpt-6.1-sol / xhigh" ]] \
    && ok "Codex effort is read from reasoning_effort" || bad "Codex effort is read from reasoning_effort"
  [[ "$(agent_case a3 '{"currentAgent":"claude","model":"claude-sonnet-5-5","requestedModel":"opus","agentLaunchOptions":{"options":{"model":"opus","effort":"high"}}}')" == "Claude / claude-sonnet-5-5 / high" ]] \
    && ok "the agent label shows the model in use, not the one requested at launch" || bad "the agent label shows the model in use, not the one requested at launch"
  [[ "$(agent_case a4 '{"currentAgent":"codex","model":"gpt_6*x"}')" == "Codex / gpt_6*x" ]] \
    && ok "agent values are passed as reported" || bad "agent values are passed as reported"
  one_record "$tmp/n-agent-a5" a5 --role implement --status done --head HEAD
  T_SID=missing-1 route_in "$tmp/n-agent-a5"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && jt '.kind=="implement" and .agent==""' \
    && ok "when Xirp cannot report the session the record is routed and notified without agent parts" || bad "when Xirp cannot report the session the record is routed and notified without agent parts"
  one_record "$tmp/n-sid" n3 --role implement --status done --head HEAD
  (cd "$tmp/n-sid" && printf '{"session_id":"native-1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID=chirp-1 "$ROUTE")
  jt '.session_id=="native-1"' && ok "the notice carries the native session id from the hook input" || bad "the notice carries the native session id from the hook input"

  one_record "$tmp/n-manual" n5 --role implement --status done --head HEAD
  (cd "$tmp/n-manual" && printf '{"session_id":"native-1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 "$ROUTE" --foreground)
  [[ "$(created)" == 1 ]] && jt '.kind=="implement" and .agent=="" and .session_id==""' \
    && ok "a manual foreground run routes the record and leaves out the agent and session label" \
    || bad "a manual foreground run routes the record and leaves out the agent and session label ($(jl | tail -1))"
  one_record "$tmp/n-rc" n4 --role implement --status done --head HEAD
  FAKE_NOTIFY_RC=1 route_in "$tmp/n-rc"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && routed "$tmp/n-rc" 01-implement.yaml \
    && ok "a failing notifier changes neither routing nor the exit status" || bad "a failing notifier changes neither routing nor the exit status"

  # Attention sources that stop for the user: notified once, then marked processed.
  stop_case() {  # <label> <dir> <detail regex> <next regex>
    if jt --arg d "$3" --arg n "$4" '.kind=="attention" and (.detail|test($d)) and (.next|test($n))' && routed "$2" "$(ls "$2/.agent-handoff/add-export" | grep -E '^[0-9]{2}-' | sort | tail -1)"; then
      local before; before="$(ncount)"; route_in "$2"
      [[ "$(ncount)" == "$before" ]] && ok "$1" || bad "$1 (notified again)"
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
      [[ "$(ncount)" == "$before" ]] && ! routed "$2" "$3" && ok "$1" || bad "$1 (second run)"
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
  [[ "$(msgs | grep -c $'^sess-r\t')" == 1 && "$(kinds)" == "attention implement" ]] && routed "$NR" 01-implement.yaml \
    && ok "a retry that reaches the reviewer sends the message and the progress notice once" || bad "a retry that reaches the reviewer sends the message and the progress notice once ($(kinds))"
  [[ "$(jl | head -1 | jq -r .agent)" == "Claude / fake-model / high" ]] && jt '.agent=="" and .session_id==""' \
    && ok "a retried record's notice leaves out the agent and session label of whoever triggered the retry" \
    || bad "a retried record's notice leaves out the agent and session label of whoever triggered the retry ($(jl | tail -1))"
  NI="$tmp/n-sendimpl"; one_record "$NI" f2 --role implement --status done --head HEAD
  hw "$NI" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$FAKE_XIRP_DIR/msg-fail"; route_in "$NI"; rc=$?
  [[ "$rc" == 0 && "$(kinds)" == attention ]] && grep -q 'send-failed' "$NI/.agent-handoff/add-export/routing.log" \
    && retry_case "a message the implementer did not get is one attention notice and stays unprocessed" "$NI" 02-review.yaml '實作者' \
    || bad "a message the implementer did not get is one attention notice and stays unprocessed ($(kinds))"
  rm -f "$FAKE_XIRP_DIR/msg-fail"; route_in "$NI"
  [[ "$(msgs | grep -c $'^impl-1\t')" == 1 && "$(kinds)" == "attention review" ]] && routed "$NI" 02-review.yaml \
    && ok "a retry that reaches the implementer sends the message and the review notice once" || bad "a retry that reaches the implementer sends the message and the review notice once ($(kinds))"
  NO="$tmp/n-open"; one_record "$NO" f3 --role implement --status done --head HEAD
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NO"
  [[ "$(created)" == 0 ]] && retry_case "a reviewer that cannot be opened is one attention notice and stays unprocessed" "$NO" 01-implement.yaml '審查' \
    || bad "a reviewer that cannot be opened is one attention notice and stays unprocessed"
  use_project "$NO"; route_in "$NO"
  [[ "$(created)" == 1 && "$(kinds)" == "attention implement" ]] && routed "$NO" 01-implement.yaml \
    && ok "a later run opens the reviewer and sends the progress notice" || bad "a later run opens the reviewer and sends the progress notice ($(kinds))"
  NW="$tmp/n-wtfail"; new_loop "$NW" new; use_project "$NW"; fresh_state f4; hw "$NW" --role implement --status done --head HEAD
  touch "${NW}-review"; route_in "$NW"
  [[ "$(created)" == 0 ]] && retry_case "a review worktree that cannot be created is one attention notice and stays unprocessed" "$NW" 01-implement.yaml 'worktree' \
    || bad "a review worktree that cannot be created is one attention notice and stays unprocessed"
  rm -f "${NW}-review"; route_in "$NW"
  [[ "$(created)" == 1 && -d "${NW}-review" ]] && routed "$NW" 01-implement.yaml \
    && ok "a later run creates the review worktree and opens the reviewer" || bad "a later run creates the review worktree and opens the reviewer"
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
  [[ -d "${NF}-finish" && "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$NF" 02-review.yaml \
    && ok "a finish session that cannot be opened leaves the prepared finish worktree and the record unprocessed" \
    || bad "a finish session that cannot be opened leaves the prepared finish worktree and the record unprocessed ($(kinds))"
  use_project "$NF"; route_in "$NF"
  [[ "$(created)" == 1 && "$(kinds)" == "attention review" ]] && jt '.verdict=="pass"' && routed "$NF" 02-review.yaml \
    && jq -e --arg w "${NF}-finish" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && ok "a retry reuses that finish worktree, opens one finish session and sends one review notice" \
    || bad "a retry reuses that finish worktree, opens one finish session and sends one review notice (created $(created), $(kinds))"

  NF2="$tmp/n-findirty"; new_loop "$NF2" shared auto; use_project "$NF2"; fresh_state f8; rpt "$NF2"
  lf="$NF2/.agent-handoff/add-export/loop.yaml"
  awk '/^finish_template:/{s=1} s && /^  worktree: shared$/{print "  worktree: new"; s=0; next} {print}' "$lf" > "$lf.tmp" && mv "$lf.tmp" "$lf"
  hw "$NF2" --role implement --status done --head HEAD; hw "$NF2" --role review --status done --verdict pass --head HEAD --report r.md
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NF2"
  printf 'mine\n' > "${NF2}-finish/stray.txt"; use_project "$NF2"; route_in "$NF2"
  [[ "$(created)" == 0 && "$(cat "${NF2}-finish/stray.txt")" == mine ]] && ! routed "$NF2" 02-review.yaml \
    && ok "an unclean finish worktree is not reused and its content is kept" || bad "an unclean finish worktree is not reused and its content is kept"

  # codex-01a1eecf-r01/F-02: a reused review worktree must be clean.
  NRW="$tmp/n-revretry"; new_loop "$NRW" new; use_project "$NRW"; fresh_state f7; hw "$NRW" --role implement --status done --head HEAD
  export FAKE_PROJECT_PATH="$tmp/nowhere"; route_in "$NRW"
  rhead="$(git -C "${NRW}-review" rev-parse HEAD 2>/dev/null)"
  printf 'keep me\n' > "${NRW}-review/stray.txt"
  use_project "$NRW"; route_in "$NRW"
  [[ "$(created)" == 0 && "$(kinds)" == "attention attention" && "$(cat "${NRW}-review/stray.txt")" == "keep me" \
    && "$(git -C "${NRW}-review" rev-parse HEAD)" == "$rhead" ]] && jt '.detail|test("未提交")' && routed "$NRW" 01-implement.yaml \
    && ok "an unclean reused review worktree stops for the user without opening the reviewer" \
    || bad "an unclean reused review worktree stops for the user without opening the reviewer (created $(created), $(kinds))"
  before="$(ncount)"; route_in "$NRW"
  [[ "$(ncount)" == "$before" && "$(created)" == 0 ]] && ok "that stop is not notified again" || bad "that stop is not notified again"

  # Without a notification hook nothing is sent and routing is unchanged.
  route_none() { (cd "$1" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$tmp/no-such-notify.sh" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 "$ROUTE" --foreground </dev/null); }
  one_record "$tmp/n-none-ask" u1 --role review --status done --verdict pass --head HEAD --report r.md; route_none "$tmp/n-none-ask"; rc1=$?
  one_record "$tmp/n-none-blocked" u2 --role implement --status blocked --head HEAD --note x; route_none "$tmp/n-none-blocked"; rc2=$?
  one_record "$tmp/n-none-impl" u3 --role implement --status done --head HEAD; route_none "$tmp/n-none-impl"; rc3=$?
  [[ "$rc1$rc2$rc3" == 000 && ! -e "$tmp/state-u1/notified" && ! -e "$tmp/state-u2/notified" && ! -e "$tmp/state-u3/notified" ]] \
    && routed "$tmp/n-none-ask" 01-review.yaml && routed "$tmp/n-none-blocked" 01-implement.yaml && routed "$tmp/n-none-impl" 01-implement.yaml \
    && [[ "$(created)" == 1 ]] \
    && ok "without a notification hook nothing is sent, records are processed and the reviewer is opened" || bad "without a notification hook nothing is sent, records are processed and the reviewer is opened"
fi

# ---------------------------------------------------------------- mixed deployments (real installers, dry-run notifier)
if run_section mixed; then
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
    if three_cases "$2" "$3" && grep -q 'Action Required' <<<"$OUT_ASK" && grep -q 'handoff-finish add-export' <<<"$OUT_ASK" \
      && grep -q 'Action Required' <<<"$OUT_BLOCKED" && grep -q "needs-decision-$3" <<<"$OUT_BLOCKED" && [[ -z "$OUT_IMPL" ]]; then
      ok "$1"
    else
      bad "$1"; printf '       ask: %s\n       blocked: %s\n       impl: %s\n' "$OUT_ASK" "$OUT_BLOCKED" "$OUT_IMPL"
    fi
  }
  handoff_case() {  # <label> <home> <tag>
    if three_cases "$2" "$3" && grep -q '需要你處理' <<<"$OUT_ASK" && grep -q 'handoff-finish add-export' <<<"$OUT_ASK" \
      && grep -q '需要你處理' <<<"$OUT_BLOCKED" && grep -q "needs-decision-$3" <<<"$OUT_BLOCKED" && grep -q '實作完成' <<<"$OUT_IMPL"; then
      ok "$1"
    else
      bad "$1"; printf '       ask: %s\n       blocked: %s\n       impl: %s\n' "$OUT_ASK" "$OUT_BLOCKED" "$OUT_IMPL"
    fi
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
  grep -q 'Action Required' <<<"$out" && grep -q 'handoff-finish add-export' <<<"$out" \
    && ok "only the notifier updated: the previous handoff notice is still delivered" || bad "only the notifier updated: the previous handoff notice is still delivered ($out)"
  H6="$tmp/m-home-none"; install_handoff "$H6"
  three_cases "$H6" none && [[ -z "$OUT_ASK$OUT_BLOCKED$OUT_IMPL" ]] \
    && ok "never installed notifier: nothing is sent and routing is unchanged" || bad "never installed notifier: nothing is sent and routing is unchanged"
  hc="$(jq -r '[.hooks.Stop[]?.hooks[]?.command | select(test("handoff-route"))] | join("|")' "$H2/.claude/settings.json" "$H2/.codex/hooks.json" | paste -sd'|' -)"
  [[ "$hc" == "bash \"$H2/.config/wk-workflow/handoff/handoff-route\"|bash \"$H2/.config/wk-workflow/handoff/handoff-route\"" ]] \
    && ok "the registered hook command is unchanged for Claude Code and Codex" || bad "the registered hook command is unchanged for Claude Code and Codex ($hc)"
fi

# ---------------------------------------------------------------- launcher (handoff-start)
START="$ROOT/scripts/handoff/handoff-start"
FINISH="$ROOT/scripts/handoff/handoff-finish"
# new_project <dir>: main worktree on main, with an active change, its branch and role templates
new_project() {
  local d="$1"; new_repo "$d"
  mkdir -p "$d/openspec/changes/add-export"; printf 'p\n' > "$d/openspec/changes/add-export/proposal.md"
  git -C "$d" add openspec; git -C "$d" commit -qm change; git -C "$d" branch feature/add-export
  mkdir -p "$d/.agent-handoff"; cp "$SKILL/roles.example.yaml" "$d/.agent-handoff/roles.yaml"
}
start_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_CREATE_WAIT=2 "$START" "$@" </dev/null); }
finish_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_CREATE_WAIT=2 "$FINISH" "$@" </dev/null); }
role_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROOT/scripts/handoff/handoff-role" "$@" </dev/null); }
deleted() { cat "$FAKE_XIRP_DIR/deleted" 2>/dev/null; }
# mv that fails when its destination matches $FAKE_MV_FAIL and its source $FAKE_MV_FROM (globs; test-only fault injection),
# after letting $FAKE_MV_AFTER matching calls through (counted in $FAKE_MV_COUNT); with $FAKE_MV_IF, only when the
# source file contains that text.
MVSHIM="$tmp/mvshim"; mkdir -p "$MVSHIM"
cat > "$MVSHIM/mv" <<'SH'
#!/usr/bin/env bash
src="$1"; for a in "$@"; do dst="$a"; done
# shellcheck disable=SC2053
if [[ -n "${FAKE_MV_FAIL:-}" && "$dst" == $FAKE_MV_FAIL && "$src" == ${FAKE_MV_FROM:-*} ]] \
  && { [[ -z "${FAKE_MV_IF:-}" ]] || grep -qF -- "$FAKE_MV_IF" "$src" 2>/dev/null; }; then
  n="$(cat "${FAKE_MV_COUNT:-/dev/null}" 2>/dev/null)"; n="${n:-0}"; echo $((n + 1)) > "${FAKE_MV_COUNT:-/dev/null}"
  (( n >= ${FAKE_MV_AFTER:-0} )) && { echo "mv: injected failure" >&2; exit 1; }
fi
exec /bin/mv "$@"
SH
chmod +x "$MVSHIM/mv"
# git that moves feature/add-export to $FAKE_GIT_MOVE_TO just before "worktree add" (test-only race injection).
REAL_GIT="$(command -v git)"; GITSHIM="$tmp/gitshim"; mkdir -p "$GITSHIM"
cat > "$GITSHIM/git" <<SH
#!/usr/bin/env bash
if [[ -n "\${FAKE_GIT_MOVE_TO:-}" && "\$1" == -C && " \$* " == *" worktree add "* ]]; then "$REAL_GIT" -C "\$2" update-ref refs/heads/feature/add-export "\$FAKE_GIT_MOVE_TO"; fi
exec "$REAL_GIT" "\$@"
SH
chmod +x "$GITSHIM/git"
MV_KV='*/loop.yaml.[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9]'  # kv_set's temporary file
# wrpt <worktree>: an ignored review report r.md in a linked worktree
wrpt() { local i; i="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)/info"; printf 'r\n' > "$1/r.md"; mkdir -p "$i"; printf '/r.md\n' >> "$i/exclude"; }

if run_section start; then
  printf 'launcher\n'
  source "$KV"
  P="$tmp/start-p"; new_project "$P"; use_project "$P"; fresh_state s1
  WT="$P-add-export"

  P0="$tmp/start-noroles"; new_project "$P0"; rm "$P0/.agent-handoff/roles.yaml"; fresh_state s0
  out="$(start_in "$P0" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'roles.yaml' <<<"$out" && ok "missing roles.yaml stops before opening anything" || bad "missing roles.yaml stops before opening anything"
  out="$(start_in "$P" no-such-change 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$P-no-such-change" ]] && ok "unknown change stops without a worktree or session" || bad "unknown change stops without a worktree or session"
  mkdir -p "$P/openspec/changes/no-branch"
  out="$(start_in "$P" no-branch 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'feature/no-branch' <<<"$out" && ok "missing feature branch stops" || bad "missing feature branch stops"

  # Planning committed only on the feature branch (the usual flow): start finds it there.
  PB="$tmp/start-branch-only"; new_repo "$PB"; git -C "$PB" switch -q -c feature/add-export
  mkdir -p "$PB/openspec/changes/add-export"; printf 'p\n' > "$PB/openspec/changes/add-export/proposal.md"
  git -C "$PB" add openspec; git -C "$PB" commit -qm plan; git -C "$PB" switch -q main
  mkdir -p "$PB/.agent-handoff"; cp "$SKILL/roles.example.yaml" "$PB/.agent-handoff/roles.yaml"; use_project "$PB"; fresh_state s1b
  out="$(start_in "$PB" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$PB-add-export/openspec/changes/add-export" && "$(created)" == 1 ]] \
    && ok "a change committed only on its feature branch can be started" || { bad "a change committed only on its feature branch can be started"; printf '       %s\n' "$out"; }
  # Change present in the main worktree but missing from the branch: refused.
  PM="$tmp/start-main-only"; new_repo "$PM"; git -C "$PM" branch feature/add-export
  mkdir -p "$PM/openspec/changes/add-export"; printf 'p\n' > "$PM/openspec/changes/add-export/proposal.md"
  git -C "$PM" add openspec; git -C "$PM" commit -qm change-on-main
  mkdir -p "$PM/.agent-handoff"; cp "$SKILL/roles.example.yaml" "$PM/.agent-handoff/roles.yaml"; use_project "$PM"; fresh_state s1c
  out="$(start_in "$PM" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PM-add-export" ]] && grep -q 'feature/add-export' <<<"$out" \
    && ok "a change missing from its feature branch is refused" || { bad "a change missing from its feature branch is refused"; printf '       %s\n' "$out"; }
  use_project "$P"; fresh_state s1

  out="$(start_in "$P" add-export 2>&1)"; rc=$?
  loop="$WT/.agent-handoff/add-export/loop.yaml"
  if [[ "$rc" == 0 && -d "$WT" && "$(git -C "$WT" branch --show-current)" == "feature/add-export" && "$(git -C "$P" branch --show-current)" == "main" ]]; then
    ok "default opens the implementer in a new worktree and keeps the main worktree on main"
  else
    bad "default opens the implementer in a new worktree and keeps the main worktree on main"; printf '       %s\n' "$out"
  fi
  if [[ "$(created)" == 1 ]] && jq -e --arg w "$WT" '.worktreePath==$w and .customName=="claude - impl - add-export" and .agent.agentName=="claude" and .agent.options.model=="opus" and .agent.options.effort=="high"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; then
    ok "only the implementer is opened, with explicit model, effort and pinned name"
  else
    bad "only the implementer is opened, with explicit model, effort and pinned name"
  fi
  jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null | grep -q 'openspec-apply-change add-export' && jq -r .goal "$FAKE_XIRP_DIR/create-1.json" | grep -q '.agents/skills/agent-handoff/scripts/handoff-write' \
    && ok "implementer prompt is rendered from the template" || bad "implementer prompt is rendered from the template"
  g="$(jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null)"
  grep -qF "agent-handoff/scripts/handoff-author --tool 'Claude Code' --model opus" <<<"$g" \
    && ok "implementer prompt has it attach the Author block from handoff-author with its tool and template model" || bad "implementer prompt has it attach the Author block from handoff-author with its tool and template model"
  if [[ -f "$loop" && "$(kv_get "$loop" change)" == add-export && "$(kv_get "$loop" max_rounds)" == 3 && "$(kv_get "$loop" implementer.session)" == sess-1 \
    && "$(kv_get "$loop" implementer.worktree)" == "$WT" && -z "$(kv_get "$loop" reviewer.session)" && "$(kv_get "$loop" finish.trigger)" == ask \
    && "$(kv_get "$loop" finish.delivery)" == local && "$(kv_get "$loop" review_template.model)" == gpt-6.1-sol && "$(kv_get "$loop" finish_template.harness)" == codex \
    && "$(kv_get "$loop" review_template.worktree)" == shared ]]; then
    ok "loop.yaml records the implementer, limits, finish settings and templates"
  else
    bad "loop.yaml records the implementer, limits, finish settings and templates"
  fi
  out="$(start_in "$P" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 1 ]] && grep -q "$WT" <<<"$out" && ok "branch already in another worktree stops and names it" || bad "branch already in another worktree stops and names it"

  H="$tmp/start-here"; new_project "$H"; use_project "$H"; fresh_state s2; git -C "$H" switch -q feature/add-export
  out="$(start_in "$H" add-export --worktree here 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$H/.agent-handoff/add-export/loop.yaml" implementer.worktree)" == "$H" ]] && ! git -C "$H" worktree list | grep -q -- "-add-export" \
    && ok "--worktree here uses the current checkout on the feature branch" || bad "--worktree here uses the current checkout on the feature branch"
  H2="$tmp/start-here-main"; new_project "$H2"; use_project "$H2"; fresh_state s3
  out="$(start_in "$H2" add-export --worktree here 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && ok "--worktree here refuses a checkout on another branch" || bad "--worktree here refuses a checkout on another branch"

  M="$tmp/start-nomodel"; new_project "$M"; use_project "$M"; fresh_state s4
  grep -v '^  model: opus$' "$M/.agent-handoff/roles.yaml" > "$M/r.tmp" && mv "$M/r.tmp" "$M/.agent-handoff/roles.yaml"
  out="$(start_in "$M" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'model' <<<"$out" && ok "template without model is refused" || bad "template without model is refused"
  U="$tmp/start-badmode"; new_project "$U"; use_project "$U"; fresh_state s5
  awk 'BEGIN{n=0} /^  worktree: shared$/ && n==0 {print "  worktree: separate"; n=1; next} {print}' "$U/.agent-handoff/roles.yaml" > "$U/r.tmp" && mv "$U/r.tmp" "$U/.agent-handoff/roles.yaml"
  out="$(start_in "$U" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'shared' <<<"$out" && grep -q 'new' <<<"$out" && ok "unknown worktree mode is refused and allowed values named" || bad "unknown worktree mode is refused and allowed values named"
  CP="$tmp/start-claude-profile"; new_project "$CP"; use_project "$CP"; fresh_state s5p
  awk '/^implement:/{print; print "  profile: handoff-net"; next} {print}' "$CP/.agent-handoff/roles.yaml" > "$CP/r.tmp" && mv "$CP/r.tmp" "$CP/.agent-handoff/roles.yaml"
  out="$(start_in "$CP" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'profile' <<<"$out" && ok "a profile on a Claude template is refused" || { bad "a profile on a Claude template is refused"; printf '       %s\n' "$out"; }
  CF="$tmp/start-finish-profile"; new_project "$CF"; use_project "$CF"; fresh_state s5q
  awk '/^finish:/{print; print "  profile: handoff-net"; next} {print}' "$CF/.agent-handoff/roles.yaml" > "$CF/r.tmp" && mv "$CF/r.tmp" "$CF/.agent-handoff/roles.yaml"
  out="$(start_in "$CF" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$CF-add-export/.agent-handoff/add-export/loop.yaml" finish_template.profile)" == handoff-net ]] \
    && ok "a finish profile is copied into loop.yaml" || { bad "a finish profile is copied into loop.yaml"; printf '       %s\n' "$out"; }

  O="$tmp/start-override"; new_project "$O"; use_project "$O"; fresh_state s6
  before="$(cat "$O/.agent-handoff/roles.yaml")"
  out="$(start_in "$O" add-export --impl codex:gpt-x:low --review claude:sonnet:max --finish auto 2>&1)"; rc=$?
  ol="$O-add-export/.agent-handoff/add-export/loop.yaml"
  if [[ "$rc" == 0 ]] && jq -e '.agent.agentName=="codex" and .agent.options.model=="gpt-x" and .agent.options.reasoning_effort=="low"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$ol" review_template.harness)" == claude && "$(kv_get "$ol" review_template.model)" == sonnet && "$(kv_get "$ol" review_template.effort)" == max \
    && "$(kv_get "$ol" finish.trigger)" == auto && "$(cat "$O/.agent-handoff/roles.yaml")" == "$before" ]]; then
    ok "per-loop overrides are recorded in loop.yaml and roles.yaml is unchanged"
  else
    bad "per-loop overrides are recorded in loop.yaml and roles.yaml is unchanged"; printf '       %s\n' "$out"
  fi
  # The overrides above change both tools: Codex review → Claude, Claude implement → Codex.
  [[ "$(kv_get "$ol" review_template.prompt)" == '/change-review {change}'* && "$(kv_get "$ol" review_template.name)" == 'claude - review - {change}' ]] \
    && jq -e '.customName=="codex - impl - add-export" and (.goal|startswith("$openspec-apply-change add-export"))' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && ok "an override that changes the tool rewrites the skill call and session name" \
    || { bad "an override that changes the tool rewrites the skill call and session name"; printf '       %s | %s\n' "$(kv_get "$ol" review_template.name)" "$(kv_get "$ol" review_template.prompt | cut -c1-40)"; }
  OS="$tmp/start-same-tool"; new_project "$OS"; use_project "$OS"; fresh_state s6s
  start_in "$OS" add-export --review codex:gpt-6.1-terra:high >/dev/null 2>&1
  osl="$OS-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$(kv_get "$osl" review_template.model)" == gpt-6.1-terra && "$(kv_get "$osl" review_template.prompt)" == '$change-review {change}'* \
    && "$(kv_get "$osl" review_template.name)" == 'codex - review - {change}' ]] \
    && ok "an override that keeps the tool keeps the prompt and session name" || bad "an override that keeps the tool keeps the prompt and session name"
  R="$tmp/start-reuse"; new_project "$R"; use_project "$R"; fresh_state s7
  out="$(start_in "$R" add-export --reviewer-session rev-9 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$R-add-export/.agent-handoff/add-export/loop.yaml" reviewer.session)" == rev-9 && "$(created)" == 1 ]] \
    && ok "an existing reviewer session is recorded and not reopened" || bad "an existing reviewer session is recorded and not reopened"
  R2="$tmp/start-reuse-missing"; new_project "$R2"; use_project "$R2"; fresh_state s8
  out="$(start_in "$R2" add-export --reviewer-session missing-1 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && ok "an unknown reviewer session is refused" || bad "an unknown reviewer session is refused"

  # Session hosts: recorded per role in loop.yaml; xirp when roles.yaml names none.
  hl="$P-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$(kv_get "$hl" implement_template.host)" == xirp && "$(kv_get "$hl" review_template.host)" == xirp && "$(kv_get "$hl" finish_template.host)" == xirp ]] \
    && ok "without a host in roles.yaml every role records host xirp" || bad "without a host in roles.yaml every role records host xirp"
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
    && "$(kv_get "$hvl" implementer.session)" == sess-1 ]] && ! herdr_calls | grep -q 'agent start' \
    && ok "a role that sets host: herdr records it, and the implementer still opens through Xirp" || { bad "a role that sets host: herdr records it, and the implementer still opens through Xirp"; printf '       %s\n' "$out"; }
  [[ "$(kv_get "$hvl" reviewer.herdr_session)" == work ]] \
    && ok "outside herdr the herdr role uses herdr_session from roles.yaml" || bad "outside herdr the herdr role uses herdr_session from roles.yaml ($(kv_get "$hvl" reviewer.herdr_session))"
  HP="$tmp/start-host-pane"; new_project "$HP"; use_project "$HP"; fresh_state s10; host_roles "$HP" review herdr "herdr_session: work"
  HERDR_ENV=1 HERDR_SESSION=dev start_in "$HP" add-export >/dev/null 2>&1
  [[ "$(kv_get "$HP-add-export/.agent-handoff/add-export/loop.yaml" reviewer.herdr_session)" == dev ]] \
    && ok "inside a herdr pane the herdr role uses the pane's session" || bad "inside a herdr pane the herdr role uses the pane's session"
  HN="$tmp/start-host-default"; new_project "$HN"; use_project "$HN"; fresh_state s11; host_roles "$HN" review herdr
  start_in "$HN" add-export >/dev/null 2>&1
  [[ "$(kv_get "$HN-add-export/.agent-handoff/add-export/loop.yaml" reviewer.herdr_session)" == default ]] \
    && ok "without herdr_session the herdr role uses the default session" || bad "without herdr_session the herdr role uses the default session"
  HT="$tmp/start-host-tmux"; new_project "$HT"; use_project "$HT"; fresh_state s12; host_roles "$HT" review tmux
  out="$(start_in "$HT" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$HT-add-export" ]] && grep -q review <<<"$out" && grep -q 'xirp, herdr, herdr-app' <<<"$out" && [[ -z "$(herdr_calls | grep -v 'status\|integration\|version')" ]] \
    && ok "an unknown host is refused, naming the role and the accepted hosts, and nothing opens" || { bad "an unknown host is refused, naming the role and the accepted hosts, and nothing opens"; printf '       %s\n' "$out"; }
fi

# ---------------------------------------------------------------- handoff-finish
if run_section finish; then
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
    && [[ "$(kv_get "$F/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]] \
    && ok "a current passing review opens one finish session" || { bad "a current passing review opens one finish session"; printf '       %s\n' "$out"; }
  jq -e '.agent.options | has("profile") | not' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && ok "a template without profile sends no Codex profile" || bad "a template without profile sends no Codex profile"
  FP="$tmp/fin-profile"; passing_loop "$FP"; use_project "$FP"; fresh_state f1p
  awk '/^finish_template:/{print; print "  profile: \"handoff-net\""; next} {print}' "$FP/.agent-handoff/add-export/loop.yaml" > "$FP/l.tmp" && mv "$FP/l.tmp" "$FP/.agent-handoff/add-export/loop.yaml"
  out="$(finish_in "$FP" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && jq -e '.agent.options.profile == "handoff-net"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && ok "a Codex template profile is passed to the new session" || { bad "a Codex template profile is passed to the new session"; printf '       %s\n' "$out"; }
  # Running handoff-finish again before the finish session writes a record keeps that session.
  FR="$tmp/fin-again"; passing_loop "$FR"; use_project "$FR"; fresh_state f1r
  finish_in "$FR" add-export >/dev/null 2>&1
  out="$(finish_in "$FR" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$FR/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]] \
    && grep -q 'already open.*sess-1' <<<"$out" \
    && ok "a second handoff-finish reuses the open finish session" || { bad "a second handoff-finish reuses the open finish session"; printf '       %s\n' "$out"; }
  FG="$tmp/fin-gone"; passing_loop "$FG"; use_project "$FG"; fresh_state f1g
  awk '/^finish:/{f=1} f&&/^  session:/{print "  session: missing-3"; f=0; next} {print}' "$FG/.agent-handoff/add-export/loop.yaml" > "$FG/l.tmp" && mv "$FG/l.tmp" "$FG/.agent-handoff/add-export/loop.yaml"
  out="$(finish_in "$FG" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$FG/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]] \
    && ok "a recorded finish session that is gone is replaced by a new one" || { bad "a recorded finish session that is gone is replaced by a new one"; printf '       %s\n' "$out"; }

  refuse() {
    local label="$1" d="$2" pat="$3"
    out="$(finish_in "$d" add-export 2>&1)"; rc=$?
    [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q -- "$pat" <<<"$out" && ok "$label" || { bad "$label"; printf '       %s\n' "$out"; }
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
  if [[ "$rc" == 0 && "$(created)" == 0 ]] && msgs | grep -q '^fin-9' && msgs | grep 'fin-9' | grep -q -- '--role finish' && msgs | grep 'fin-9' | grep -q '交付方式：local'; then
    ok "a blocked finish is retried by messaging the existing finish session"
  else
    bad "a blocked finish is retried by messaging the existing finish session"; printf '       %s\n' "$out"
  fi
  R2="$tmp/fin-retry-gone"; retry_loop "$R2" missing-7; use_project "$R2"; fresh_state f12
  out="$(finish_in "$R2" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 && "$(kv_get "$R2/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-1 ]] \
    && ok "a blocked finish whose session is gone opens a new finish session" || { bad "a blocked finish whose session is gone opens a new finish session"; printf '       %s\n' "$out"; }
  R6="$tmp/fin-retry-pr"; retry_loop "$R6" fin-9; use_project "$R6"; fresh_state f16
  sed -i '' 's/^  delivery: local$/  delivery: pr/' "$R6/.agent-handoff/add-export/loop.yaml"
  finish_in "$R6" add-export >/dev/null 2>&1
  msgs | grep 'fin-9' | grep -q '最終版 Review' && msgs | grep 'fin-9' | grep -q 'Closure' \
    && ok "a PR delivery retry states that it covers the final-version review and the Closure" || bad "a PR delivery retry states that it covers the final-version review and the Closure"
  msgs | grep 'fin-9' | grep -q '直接同步主規格' && ok "a retry message says to sync main specs without asking" || bad "a retry message says to sync main specs without asking"
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
    && flog "$RB" | grep -q 'finish.yaml action=finish:opened:sess-1' \
    && ok "a blocked finish whose role is replaced opens a new finish session with the finish prompt" || { bad "a blocked finish whose role is replaced opens a new finish session with the finish prompt"; printf '       %s\n' "$out"; }
  RO="$tmp/fin-replace-open"; passing_loop "$RO"; use_project "$RO"; fresh_state f18; finish_in "$RO" add-export >/dev/null 2>&1
  out="$(role_in "$RO" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == sess-1 && "$(created)" == 2 && "$(kv_get "$RO/.agent-handoff/add-export/loop.yaml" finish.session)" == sess-2 ]] \
    && ok "a finish session opened for a passing review is replaced by a new one" || { bad "a finish session opened for a passing review is replaced by a new one"; printf '       %s\n' "$out"; }
  RP="$tmp/fin-replace-pass"; passing_loop "$RP"; use_project "$RP"; fresh_state f19
  out="$(role_in "$RP" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 0 && "$(kv_get "$RP/.agent-handoff/add-export/loop.yaml" finish_template.harness)" == claude ]] \
    && ok "a passing review whose finish has not opened only changes the finish role" || { bad "a passing review whose finish has not opened only changes the finish role"; printf '       %s\n' "$out"; }

  RW="$tmp/fin-replace-move"; retry_loop "$RW" fin-9; use_project "$RW"; fresh_state f20; XW="$(git -C "$RW" rev-parse HEAD)"
  out="$(role_in "$RW" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$RW-finish" && "$(git -C "$RW-finish" branch --show-current)" == feature/add-export && "$(git -C "$RW-finish" rev-parse HEAD)" == "$XW" \
    && "$(kv_get "$RW/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$RW-finish" && "$(created)" == 1 ]] \
    && jq -e --arg w "$RW-finish" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null 2>&1 \
    && ok "a blocked shared finish moved to its own worktree resumes there on the feature branch (codex-role-review-r01/F-08)" || { bad "a blocked shared finish moved to its own worktree resumes there on the feature branch (codex-role-review-r01/F-08)"; printf '       %s\n' "$out"; }
  RF="$tmp/fin-replace-fail"; retry_loop "$RF" fin-9; use_project "$RF"; fresh_state f21; touch "$FAKE_XIRP_DIR/create-fail"; n0="$(ncount)"
  out="$(role_in "$RF" add-export finish claude:sonnet:high --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/create-fail"
  [[ "$rc" != 0 && "$(( $(ncount) - n0 ))" == 1 ]] && jt '.kind=="attention"' && grep -q 'handoff-finish add-export' <<<"$out" \
    && ok "a finish that cannot open after a replacement sends one attention notice" || { bad "a finish that cannot open after a replacement sends one attention notice"; printf '       %s\n' "$out"; }

  # Round 3 (codex-role-review-r02/F-08)
  R8="$tmp/fin-move-tip"; retry_loop "$R8" fin-9; use_project "$R8"; fresh_state f22
  git -C "$R8" checkout -q --detach; git -C "$R8" branch -f feature/add-export HEAD~1
  out="$(role_in "$R8" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$R8-finish" ]] && grep -q 'feature/add-export' <<<"$out" \
    && ok "a blocked finish is not moved onto a feature branch tip other than its commit (codex-role-review-r02/F-08)" || { bad "a blocked finish is not moved onto a feature branch tip other than its commit (codex-role-review-r02/F-08)"; printf '       %s\n' "$out"; }
  R9="$tmp/fin-move-copy"; retry_loop "$R9" fin-9; use_project "$R9"; fresh_state f23
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*-finish/.agent-handoff/add-export/loop.yaml' role_in "$R9" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  fout="$(finish_in "$R9" add-export 2>&1)"; frc=$?
  [[ "$rc" != 0 && "$frc" == 0 && "$(created)" == 1 && "$(kv_get "$R9-finish/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$R9-finish" ]] \
    && ok "a move whose finish-worktree copy failed is completed by handoff-finish (codex-role-review-r02/F-08)" || { bad "a move whose finish-worktree copy failed is completed by handoff-finish (codex-role-review-r02/F-08)"; printf '       %s\n' "$out" "$fout"; }
  R10="$tmp/fin-move-ptr"; retry_loop "$R10" fin-9; use_project "$R10"; fresh_state f24; lset "$R10/.agent-handoff/add-export/loop.yaml" finish.worktree "$R10"
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL="$R10/.agent-handoff/add-export/loop.yaml" FAKE_MV_FROM="$MV_KV" role_in "$R10" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  fout="$(finish_in "$R10" add-export 2>&1)"; frc=$?
  [[ "$rc" != 0 && "$frc" == 0 && "$(created)" == 1 && "$(kv_get "$R10/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$R10-finish" ]] \
    && jq -e --arg w "$R10-finish" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null 2>&1 \
    && ok "a move whose loop.yaml pointer failed reuses its finish worktree on retry (codex-role-review-r02/F-08)" || { bad "a move whose loop.yaml pointer failed reuses its finish worktree on retry (codex-role-review-r02/F-08)"; printf '       %s\n' "$out" "$fout"; }

  # Round 4 (codex-role-review-r03/F-08)
  R11="$tmp/fin-move-back"; retry_loop "$R11" fin-9; use_project "$R11"; fresh_state f25; git -C "$R11" reset -q --hard HEAD~1
  out="$(role_in "$R11" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$R11-finish" ]] && grep -q 'blocked finish' <<<"$out" \
    && ok "a blocked finish is not moved from a worktree that no longer holds its commit (codex-role-review-r03/F-08)" || { bad "a blocked finish is not moved from a worktree that no longer holds its commit (codex-role-review-r03/F-08)"; printf '       %s\n' "$out"; }
  R12="$tmp/fin-move-race"; retry_loop "$R12" fin-9; use_project "$R12"; fresh_state f26
  out="$(PATH="$GITSHIM:$PATH" FAKE_GIT_MOVE_TO="$(git -C "$R12" rev-parse HEAD~2)" role_in "$R12" add-export finish claude:sonnet:high --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'not opened' <<<"$out" \
    && ok "a finish worktree that checked out another commit is not opened (codex-role-review-r03/F-08)" || { bad "a finish worktree that checked out another commit is not opened (codex-role-review-r03/F-08)"; printf '       %s\n' "$out"; }

  # Round 5 (pi-role-review-r04/F-08): a move cut short is not completed on a commit without the blocked finish's work.
  R13="$tmp/fin-move-rewound"; retry_loop "$R13" fin-9; use_project "$R13"; fresh_state f27; B13="$(git -C "$R13" rev-parse HEAD)"
  PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*-finish/.agent-handoff/add-export/loop.yaml' role_in "$R13" add-export finish claude:sonnet:high --worktree new --replace >/dev/null 2>&1
  git -C "$R13-finish" reset -q --hard HEAD~1
  fout="$(finish_in "$R13" add-export 2>&1)"; frc=$?
  [[ "$frc" != 0 && "$(created)" == 0 ]] && grep -q "${B13:0:7}" <<<"$fout" \
    && ok "completing a move cut short refuses a finish worktree without the blocked finish's commit (pi-role-review-r04/F-08)" || { bad "completing a move cut short refuses a finish worktree without the blocked finish's commit (pi-role-review-r04/F-08)"; printf '       %s\n' "$fout"; }

  # Pass recorded in a separate review worktree B; finish runs from A.
  SA="$tmp/fin-sep"; new_loop "$SA" new ask; use_project "$SA"; fresh_state f8; SB="$SA-review"
  commit_in "$SA" impl; hw "$SA" --role implement --status done --head HEAD
  route_in "$SA"
  mkdir -p "$SB/rv"; printf 'ok\n' > "$SB/rv/r.md"; mkdir -p "$(git -C "$SB" rev-parse --path-format=absolute --git-common-dir)/info"; printf '/rv/\n' >> "$(git -C "$SB" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  hw "$SB" --role review --status done --verdict pass --head HEAD --report rv/r.md
  out="$(finish_in "$SA" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 2 ]] && ok "a pass in the separate review worktree lets A finish" || { bad "a pass in the separate review worktree lets A finish"; printf '       %s\n' "$out"; }

  # Separate finish worktree takes over the branch.
  N="$tmp/fin-new"; passing_loop "$N" new; use_project "$N"; fresh_state f9; XN="$(git -C "$N" rev-parse HEAD)"
  out="$(finish_in "$N" add-export 2>&1)"; rc=$?
  NF="$N-finish"
  if [[ "$rc" == 0 && -d "$NF" && "$(git -C "$NF" branch --show-current)" == feature/add-export && "$(git -C "$NF" rev-parse HEAD)" == "$XN" \
    && -z "$(git -C "$N" branch --show-current)" && "$(git -C "$N" rev-parse HEAD)" == "$XN" && -f "$N/work.txt" ]] \
    && jq -e --arg w "$NF" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$N/.agent-handoff/add-export/loop.yaml" finish.worktree)" == "$NF" ]]; then
    ok "finish worktree new detaches A at the head and opens the finish session on the branch"
  else
    bad "finish worktree new detaches A at the head and opens the finish session on the branch"; printf '       %s\n' "$out"
  fi
  N2="$tmp/fin-new-dirty"; passing_loop "$N2" new; use_project "$N2"; fresh_state f10; printf 'x\n' > "$N2/dirty.txt"
  out="$(finish_in "$N2" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$N2-finish" && "$(git -C "$N2" branch --show-current)" == feature/add-export ]] \
    && ok "finish worktree new does nothing when A is unclean" || bad "finish worktree new does nothing when A is unclean"
fi

# ---------------------------------------------------------------- environment checks (ho_preflight, handoff-doctor)
LIB="$ROOT/scripts/handoff/lib/handoff.sh"
DOCTOR="$ROOT/scripts/handoff/handoff-doctor"
# pf <dir> <file> <sections...>: run ho_preflight in <dir> with the test HOME and the fakes
pf() { local d="$1"; shift; (cd "$d" && export HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_NOTIFY="${PF_NOTIFY-$FAKES/notify.sh}"; source "$LIB"; ho_preflight "$@"); }
doctor_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_NOTIFY="${PF_NOTIFY-$FAKES/notify.sh}" "$DOCTOR" "$@" </dev/null); }
# A PATH with every fake but one tool, and nothing that could hold the real one.
path_without() { local b="$tmp/bin-without-$1"; rm -rf "$b"; cp -R "$FAKES" "$b"; rm -f "$b/$1"; ln -sf "$(command -v jq)" "$b/jq"; printf '%s' "$b:/usr/bin:/bin"; }

if run_section doctor; then
  printf 'environment checks\n'
  source "$KV"
  D="$tmp/doc-p"; new_project "$D"; use_project "$D"; fresh_state d1; DR="$D/.agent-handoff/roles.yaml"
  out="$(pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && ! grep -qv '^\(ok\|warn\) \(base\|host\|harness\|role\|notify\) ' <<<"$out" \
    && ok "a ready machine has only ok and warn lines, each with its area, and passes" || { bad "a ready machine has only ok and warn lines, each with its area, and passes"; printf '       %s\n' "$out"; }
  grep -q '^ok role implement: .*opus.*not verified' <<<"$out" \
    && ok "a Claude model is ok and marked not verified" || { bad "a Claude model is ok and marked not verified"; printf '       %s\n' "$out"; }
  grep -q '^warn harness .*codex.*/hooks' <<<"$out" \
    && ok "Codex hook trust is a warning that points to /hooks" || bad "Codex hook trust is a warning that points to /hooks"
  grep -q '^ok harness .*codex-cli 0.130.0' <<<"$out" && grep -q '^ok host .*xirp' <<<"$out" \
    && ok "harness lines show the tool version and the host line names Xirp" || { bad "harness lines show the tool version and the host line names Xirp"; printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without codex)" pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail harness .*review.*codex' <<<"$out" \
    && ok "a missing codex is a failed harness check naming the review role" || { bad "a missing codex is a failed harness check naming the review role"; printf '       %s\n' "$out"; }
  out="$(FAKE_PROJECT_PATH="$tmp/nowhere" pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*xirp project add' <<<"$out" \
    && ok "an unregistered Xirp project is a failed host check that shows how to register it" || { bad "an unregistered Xirp project is a failed host check that shows how to register it"; printf '       %s\n' "$out"; }
  out="$(PF_NOTIFY="$tmp/no-notifier.sh" pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^warn notify ' <<<"$out" \
    && ok "a missing notifier is only a warning" || { bad "a missing notifier is only a warning"; printf '       %s\n' "$out"; }
  DH="$tmp/doc-nohook"; mkdir -p "$DH"
  out="$(HOME="$DH" pf "$D" "$DR" implement)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail harness .*claude.*settings.json' <<<"$out" \
    && ok "a Claude Code Stop hook that is not registered is a failed harness check" || { bad "a Claude Code Stop hook that is not registered is a failed harness check"; printf '       %s\n' "$out"; }
  out="$(pf "$D" "$tmp/doc-none.yaml" implement)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail base .*doc-none.yaml' <<<"$out" && ! grep -q '^\(ok\|fail\) \(host\|harness\|role\)' <<<"$out" \
    && ok "a missing template file fails the base check and nothing else is checked" || { bad "a missing template file fails the base check and nothing else is checked"; printf '       %s\n' "$out"; }
  awk '/^review:/{print; print "  host: tmux"; next} {print}' "$DR" > "$tmp/doc-tmux.yaml"
  out="$(pf "$D" "$tmp/doc-tmux.yaml" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q "^fail role review.*xirp, herdr, herdr-app" <<<"$out" \
    && ok "an unknown host fails the role check" || { bad "an unknown host fails the role check"; printf '       %s\n' "$out"; }

  # handoff-doctor
  out="$(doctor_in "$D" 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok role implement' <<<"$out" && grep -q '^ok role review' <<<"$out" && grep -q '^ok role finish' <<<"$out" \
    && ok "handoff-doctor checks the three roles of roles.yaml" || { bad "handoff-doctor checks the three roles of roles.yaml"; printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without codex)" doctor_in "$D" 2>&1)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail harness .*review.*codex' <<<"$out" \
    && ok "handoff-doctor exits non-zero on a failed check" || { bad "handoff-doctor exits non-zero on a failed check"; printf '       %s\n' "$out"; }
  start_in "$D" add-export >/dev/null 2>&1; DA="$D-add-export"; commit_in "$DA" impl; hw "$DA" --role implement --status done --head HEAD
  dl="$DA/.agent-handoff/add-export"; awk '/^review_template:/{print; print "  model: \"gpt-6.1-terra\""; next} {print}' "$dl/loop.yaml" > "$tmp/dl.tmp" && cat "$tmp/dl.tmp" > "$dl/loop.yaml"
  snap="$(cd "$dl" && ls -la && cat ./*)"; ncalls="$(wc -l < "$FAKE_XIRP_DIR/calls")"
  out="$(doctor_in "$DA" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok role review_template\|^ok role review: .*gpt-6.1-terra' <<<"$out" \
    && ok "handoff-doctor <change> checks the roles recorded in that loop's loop.yaml" || { bad "handoff-doctor <change> checks the roles recorded in that loop's loop.yaml"; printf '       %s\n' "$out"; }
  [[ "$(cd "$dl" && ls -la && cat ./*)" == "$snap" ]] && ! tail -n +"$((ncalls + 1))" "$FAKE_XIRP_DIR/calls" | grep -q 'api send\|session message\|session delete' \
    && ok "handoff-doctor changes no loop file or record and sends nothing to a session" || bad "handoff-doctor changes no loop file or record and sends nothing to a session"
  # start, role and finish refuse on a failed check and print warnings without stopping
  DS="$tmp/doc-start"; new_project "$DS"; use_project "$DS"; fresh_state d2
  out="$(PF_PATH="$(path_without codex)" start_in "$DS" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -e "$DS-add-export" ]] && grep -q 'handoff-start: fail harness .*review.*codex' <<<"$out" \
    && ok "handoff-start with a missing reviewer tool prints the failed check and opens nothing" || { bad "handoff-start with a missing reviewer tool prints the failed check and opens nothing"; printf '       %s\n' "$out"; }
  out="$(start_in "$DS" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && grep -q 'handoff-start: warn notify' <<<"$out" && ! grep -q 'handoff-start: ok ' <<<"$out" \
    && ok "handoff-start prints warnings and still opens the implementer" || { bad "handoff-start prints warnings and still opens the implementer"; printf '       %s\n' "$out"; }
  dsl="$DS-add-export/.agent-handoff/add-export/loop.yaml"; before="$(cat "$dsl")"
  out="$(cd "$DS" && HOME="$(thome)" PATH="$(path_without claude)" "$ROOT/scripts/handoff/handoff-role" add-export review claude:sonnet:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(cat "$dsl")" == "$before" ]] && grep -q 'handoff-role: fail harness .*review.*claude' <<<"$out" \
    && ok "handoff-role refuses a role whose tool is missing and keeps loop.yaml" || { bad "handoff-role refuses a role whose tool is missing and keeps loop.yaml"; printf '       %s\n' "$out"; }
  DF="$tmp/doc-finish"; new_loop "$DF"; use_project "$DF"; fresh_state d3; rpt "$DF"
  hw "$DF" --role implement --status done --head HEAD; hw "$DF" --role review --status done --verdict pass --head HEAD --report r.md
  out="$(PF_PATH="$(path_without codex)" finish_in "$DF" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'handoff-finish: fail harness .*finish.*codex' <<<"$out" \
    && ok "handoff-finish with a missing finish tool prints the failed check and opens nothing" || { bad "handoff-finish with a missing finish tool prints the failed check and opens nothing"; printf '       %s\n' "$out"; }
  out="$(doctor_in "$D" no-such-change 2>&1)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q 'no-such-change' <<<"$out" && ok "handoff-doctor refuses an unknown change" || bad "handoff-doctor refuses an unknown change"
fi

# ---------------------------------------------------------------- herdr host
HS() { printf '%s' "$FAKE_XIRP_DIR/herdr"; }
# herdr_project <dir> [roles.yaml lines...]: project whose roles all run on herdr (plus the given lines)
herdr_project() {
  local d="$1" l; shift; new_project "$d"; use_project "$d"
  { printf 'host: herdr\n'; for l in "$@"; do printf '%s\n' "$l"; done; cat "$d/.agent-handoff/roles.yaml"; } > "$d/r.tmp" && mv "$d/r.tmp" "$d/.agent-handoff/roles.yaml"
}
if run_section herdr; then
  printf 'herdr host\n'
  source "$KV"
  # 4.2 environment checks for herdr
  Q="$tmp/herdr-doc"; herdr_project "$Q" "herdr_session: work"; fresh_state h1; QR="$Q/.agent-handoff/roles.yaml"
  out="$(pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok host .*herdr 0.9.5' <<<"$out" && grep -q "^ok host .*work" <<<"$out" && ! grep -q 'xirp' <<<"$out" \
    && herdr_calls | grep -q $'^work\tstatus server' \
    && ok "a herdr loop checks herdr and the server of herdr_session, and not Xirp" || { bad "a herdr loop checks herdr and the server of herdr_session, and not Xirp"; printf '       %s\n' "$out"; }
  : > "$(HS)/calls"; out="$(HERDR_ENV=1 HERDR_SESSION=dev pf "$Q" "$QR" implement review finish)"
  herdr_calls | grep -q $'^dev\tstatus server' && ! herdr_calls | grep -q $'^work\t' \
    && ok "inside a herdr pane the check uses the pane's session" || { bad "inside a herdr pane the check uses the pane's session"; herdr_calls | sed 's/^/       /'; }
  touch "$(HS)/server-down"
  out="$(pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*not running' <<<"$out" \
    && ok "a herdr server that is not running fails the host check" || { bad "a herdr server that is not running fails the host check"; printf '       %s\n' "$out"; }
  out="$(start_in "$Q" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -e "$Q-add-export" ]] && grep -q 'handoff-start: fail host .*not running' <<<"$out" \
    && ! herdr_calls | grep -q 'agent start\|workspace create\|worktree open' \
    && ok "handoff-start refuses when the herdr server is not running and opens nothing on any host" || { bad "handoff-start refuses when the herdr server is not running and opens nothing on any host"; printf '       %s\n' "$out"; }
  rm -f "$(HS)/server-down"; touch "$(HS)/no-integration-codex"
  out="$(pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^warn harness review, finish: .*herdr.*codex.*integration' <<<"$out" && ! grep -q '^warn harness implement: .*integration' <<<"$out" \
    && ok "a missing herdr integration for a herdr role's tool is a warning" || { bad "a missing herdr integration for a herdr role's tool is a warning"; printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without herdr)" pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*herdr command was not found' <<<"$out" \
    && ok "a missing herdr command fails the host check" || { bad "a missing herdr command fails the host check"; printf '       %s\n' "$out"; }
  # 4.3 opening a herdr role
  Q2="$tmp/herdr-open"; herdr_project "$Q2"; fresh_state h2; QW="$Q2-add-export"; ql="$QW/.agent-handoff/add-export/loop.yaml"
  out="$(start_in "$Q2" add-export 2>&1)"; rc=$?
  seq="$(herdr_calls | cut -f2 | awk '{print $1, $2}' | grep -v '^status server\|^integration status\|^--version' | paste -sd, -)"
  [[ "$rc" == 0 && "$seq" == "workspace list,workspace create,worktree open,tab rename,agent start,agent prompt,agent get" ]] \
    && herdr_calls | grep -qF "workspace create --cwd $Q2 --label $(basename "$Q2") --no-focus" \
    && herdr_calls | grep -qF "worktree open --workspace w1 --path $QW --label add-export --no-focus" \
    && ok "a missing repository workspace is opened, then the loop's worktree workspace under it" || { bad "a missing repository workspace is opened, then the loop's worktree workspace under it ($seq)"; printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }
  grep -qF $'w2:t1\tclaude - impl - add-export' "$(HS)/renamed" 2>/dev/null \
    && ok "the implementer's tab is named after the template" || bad "the implementer's tab is named after the template"
  herdr_calls | grep 'agent start' | grep -qE 'agent start impl-[a-z0-9]+ --kind claude --pane w2:p1 -- --model opus --effort high --name claude - impl - add-export$' \
    && ok "Claude Code starts with the template's model, effort and name" || { bad "Claude Code starts with the template's model, effort and name"; herdr_calls | grep 'agent start' | sed 's/^/       /'; }
  herdr_prompts | grep -q $'^w2:p1\t.*openspec-apply-change add-export' \
    && herdr_calls | grep 'agent prompt' | grep -q -- '--wait --until working --until blocked --timeout [0-9]' \
    && ok "the implement prompt is sent separately and waits only until the agent starts working" \
    || { bad "the implement prompt is sent separately and waits only until the agent starts working"; herdr_calls | grep 'agent prompt' | sed 's/^/       /'; }
  [[ -z "$(herdr_calls | grep -E 'workspace create|worktree open|tab create' | grep -v -- '--no-focus')" ]] \
    && ok "every workspace and tab opens without focus" || bad "every workspace and tab opens without focus"
  [[ "$(kv_get "$ql" implementer.session)" == w2:p1 && "$(kv_get "$ql" implementer.native_session)" == native-w2:p1 && "$(kv_get "$ql" implementer.herdr_session)" == default \
    && "$(kv_get "$ql" implementer.herdr_tab)" == w2:t1 && "$(kv_get "$ql" herdr.workspaces)" == w2 && "$(kv_get "$ql" implementer.pending_prompt 2>/dev/null)" != true \
    && "$(created)" == 0 ]] \
    && ok "loop.yaml records the pane, herdr session, native session ID, tab and the workspace the loop opened" || { bad "loop.yaml records the pane, herdr session, native session ID, tab and the workspace the loop opened"; cat "$ql"; }
  # The reviewer shares the worktree: it joins the same workspace in a tab of its own.
  commit_in "$QW" impl; hw "$QW" --role implement --status done --head HEAD; route_in "$QW"
  [[ "$(kv_get "$ql" reviewer.session)" == w2:p2 ]] && herdr_calls | grep -qF 'tab create --workspace w2 --cwd '"$QW"' --label codex - review - add-export --no-focus' \
    && herdr_calls | grep 'agent start' | grep -qE 'review-[a-z0-9]+ --kind codex --pane w2:p2 -- -m gpt-6.1-sol -c model_reasoning_effort=high$' \
    && herdr_prompts | grep -q $'^w2:p2\t.*change-review add-export' && [[ "$(kv_get "$ql" herdr.workspaces)" == w2 ]] \
    && [[ "$(herdr_calls | grep -c -- "worktree open --workspace w1 --path $QW --label add-export --no-focus")" == 2 ]] \
    && ok "a shared herdr reviewer opens in a new tab of the loop's workspace with Codex's model and effort" || { bad "a shared herdr reviewer opens in a new tab of the loop's workspace with Codex's model and effort"; herdr_calls | sed 's/^/       /'; }
  # 5.1 messages go to the recorded pane after checking it still runs the role's agent
  qc="$(git -C "$QW" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$qc/info"; printf '/r.md\n' >> "$qc/info/exclude"; printf 'r\n' > "$QW/r.md"
  hw "$QW" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$QW"
  herdr_prompts | grep -q $'^w2:p1\t.*changes-required' && routed "$QW" 02-review.yaml \
    && ok "changes-required is sent to the implementer's pane" || { bad "changes-required is sent to the implementer's pane"; herdr_prompts | sed 's/^/       /'; }
  grep -q '02-review.yaml action=implementer:messaged:w2:p1 .*model=gpt-6.1-sol(template)' "$QW/.agent-handoff/add-export/routing.log" \
    && ok "the routing log shows a herdr role's model from its template, marked as such" || { bad "the routing log shows a herdr role's model from its template, marked as such"; cat "$QW/.agent-handoff/add-export/routing.log"; }
  commit_in "$QW" two; hw "$QW" --role implement --status done --head HEAD; touch "$(HS)/shell-w2:p2"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"
  route_in "$QW"
  [[ "$(herdr_prompts | wc -l)" == "$np" && "$(ncount)" == $((nn + 1)) ]] && ! routed "$QW" 03-implement.yaml && grep -q 'reviewer:send-failed:w2:p2' "$QW/.agent-handoff/add-export/routing.log" \
    && ok "a reviewer pane that now runs a shell gets no text and the record stays unprocessed" || { bad "a reviewer pane that now runs a shell gets no text and the record stays unprocessed"; tail -2 "$QW/.agent-handoff/add-export/routing.log"; }
  rm -f "$(HS)/shell-w2:p2"; touch "$(HS)/blocked"; route_in "$QW"
  [[ "$(herdr_prompts | wc -l)" == "$np" && "$(ncount)" == $((nn + 1)) ]] && ! routed "$QW" 03-implement.yaml \
    && ok "a reviewer waiting on a dialog gets no text and no second notice" || bad "a reviewer waiting on a dialog gets no text and no second notice"
  rm -f "$(HS)/blocked"; lset "$ql" reviewer.native_session other-session; route_in "$QW"
  [[ "$(herdr_prompts | wc -l)" == "$np" ]] && ! routed "$QW" 03-implement.yaml \
    && ok "a pane whose agent has another native session is treated as gone" || bad "a pane whose agent has another native session is treated as gone"
  lset "$ql" reviewer.native_session native-w2:p2; route_in "$QW"
  herdr_prompts | tail -1 | grep -q $'^w2:p2\t.*第 2 輪' && routed "$QW" 03-implement.yaml \
    && [[ "$(herdr_prompts | grep -c $'^w2:p2\t.*第 2 輪')" == 1 ]] && herdr_calls | grep 'agent prompt w2:p2' | tail -1 | grep -q -- '--wait --until working' \
    && ok "a retry sends the review message to the recorded pane once" || bad "a retry sends the review message to the recorded pane once"
  # 5.2 an agent that stops at a dialog when it opens: keep the pane, notify once, retry only the prompt
  Q5="$tmp/herdr-trust"; herdr_project "$Q5"; fresh_state h5; Q5W="$Q5-add-export"; q5l="$Q5W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q5" add-export >/dev/null 2>&1; commit_in "$Q5W" impl; hw "$Q5W" --role implement --status done --head HEAD
  touch "$(HS)/not-ready"; route_in "$Q5W"
  [[ "$(kinds)" == attention && "$(kv_get "$q5l" reviewer.session)" == w2:p2 && "$(kv_get "$q5l" reviewer.pending_prompt)" == true ]] && ! routed "$Q5W" 01-implement.yaml \
    && jt '(.detail|test("w2:t2")) and (.detail|test("codex - review - add-export")) and (.detail|test("w2[^:]")) and (.next|test("handoff-route --foreground"))' \
    && ! herdr_prompts | grep -q '^w2:p2' && ! herdr_calls | grep -q 'send-keys' \
    && ok "a reviewer stopped at a trust dialog keeps its pane, sends one notice naming its workspace and tab, and answers nothing" \
    || { bad "a reviewer stopped at a trust dialog keeps its pane, sends one notice naming its workspace and tab, and answers nothing ($(kinds))"; jl | tail -1 | sed 's/^/       /'; }
  route_in "$Q5W"; [[ "$(ncount)" == 1 ]] && ok "the dialog is notified only once" || { bad "the dialog is notified only once"; notes | cut -c1-300; cat "$Q5W/.agent-handoff/add-export/routing.log"; }
  rm -f "$(HS)/not-ready"; ntab="$(herdr_calls | grep -c 'tab create')"
  (cd "$Q5W" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(herdr_calls | grep -c 'tab create')" == "$ntab" && "$(herdr_calls | grep -c 'agent start')" == 2 && -z "$(kv_get "$q5l" reviewer.pending_prompt)" ]] \
    && herdr_prompts | grep -q $'^w2:p2\t.*change-review add-export' && routed "$Q5W" 01-implement.yaml \
    && ok "a foreground retry sends the review prompt to the same pane and marks the record processed" || { bad "a foreground retry sends the review prompt to the same pane and marks the record processed"; herdr_calls | sed 's/^/       /'; }
  Q6="$tmp/herdr-trust-start"; herdr_project "$Q6"; fresh_state h6; touch "$(HS)/not-ready"
  out="$(start_in "$Q6" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(kv_get "$Q6-add-export/.agent-handoff/add-export/loop.yaml" implementer.pending_prompt)" == true ]] && grep -q 'w2:t1' <<<"$out" && grep -q 'handoff-start add-export' <<<"$out" \
    && ok "an implementer stopped at a dialog keeps its pane and handoff-start says to run it again" || { bad "an implementer stopped at a dialog keeps its pane and handoff-start says to run it again"; printf '       %s\n' "$out"; }
  rm -f "$(HS)/not-ready"; out="$(start_in "$Q6" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(herdr_calls | grep -c 'worktree open')" == 1 && "$(kv_get "$Q6-add-export/.agent-handoff/add-export/loop.yaml" implementer.session)" == w2:p1 ]] \
    && herdr_prompts | grep -q $'^w2:p1\t.*openspec-apply-change' \
    && ok "running handoff-start again sends the implement prompt to the same pane" || { bad "running handoff-start again sends the implement prompt to the same pane"; printf '       %s\n' "$out"; }
  # 5.3 a loop that uses both hosts routes each message through the receiving role's host
  MX="$tmp/herdr-mixed"; new_loop "$MX"; use_project "$MX"; fresh_state h7; rpt "$MX"; mxl="$MX/.agent-handoff/add-export/loop.yaml"
  lset "$mxl" review_template.host herdr; lset "$mxl" reviewer.herdr_session default
  hw "$MX" --role implement --status done --head HEAD; route_in "$MX"
  hw "$MX" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$MX"
  [[ "$(created)" == 0 && "$(kv_get "$mxl" reviewer.session)" == w1:p2 ]] && herdr_prompts | grep -q $'^w1:p2\t.*change-review' && msgs | grep -q $'^impl-1\t.*changes-required' \
    && ok "with the implementer on Xirp and the reviewer on herdr, each message goes through its receiver's host" || { bad "with the implementer on Xirp and the reviewer on herdr, each message goes through its receiver's host"; msgs; herdr_calls | sed 's/^/       /'; }
  NX="$tmp/herdr-noxirp"; herdr_project "$NX"; fresh_state h8; start_in "$NX" add-export >/dev/null 2>&1; NXW="$NX-add-export"
  commit_in "$NXW" impl; hw "$NXW" --role implement --status done --head HEAD
  (cd "$NXW" && PATH="$(path_without xirp)" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 "$ROUTE" </dev/null)
  routed "$NXW" 01-implement.yaml && herdr_prompts | grep -q $'^w2:p2\t.*change-review' \
    && ok "a herdr loop is routed on a machine without xirp" || { bad "a herdr loop is routed on a machine without xirp"; cat "$NXW/.agent-handoff/add-export/routing.log" 2>/dev/null; }
  # 6.1 cleanup closes what the loop opened in herdr, before it removes the worktrees
  CLEAN="$ROOT/scripts/handoff/handoff-cleanup"
  hclean() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" "$CLEAN" "$@" </dev/null); }
  printf 'r\n' > "$NXW/r.md"; nxc="$(git -C "$NXW" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$nxc/info"; printf '/r.md\n' >> "$nxc/info/exclude"
  hw "$NXW" --role review --status done --verdict pass --head HEAD --report r.md; hw "$NXW" --role finish --status done --head HEAD
  out="$(hclean "$NX" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -s "$(HS)/closed" ]] && grep -q 'herdr workspace w2' <<<"$out" && ! grep -q 'herdr workspace w1' <<<"$out" \
    && ok "the cleanup preview lists the herdr workspace the loop opened and closes nothing" || { bad "the cleanup preview lists the herdr workspace the loop opened and closes nothing"; printf '       %s\n' "$out"; }
  out="$(hclean "$NX" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(cat "$(HS)/closed" 2>/dev/null)" == "workspace close w2 exists=yes" && ! -e "$NXW" ]] \
    && ok "cleanup closes the loop's herdr workspace once, before its worktree is removed, and keeps the repository workspace" \
    || { bad "cleanup closes the loop's herdr workspace once, before its worktree is removed, and keeps the repository workspace"; printf '       %s\n' "$out"; cat "$(HS)/closed" 2>/dev/null; }
  Q8="$tmp/herdr-clean-here"; herdr_project "$Q8"; fresh_state h9; git -C "$Q8" switch -q feature/add-export
  start_in "$Q8" add-export --worktree here >/dev/null 2>&1; commit_in "$Q8" impl; hw "$Q8" --role implement --status done --head HEAD; route_in "$Q8"
  out="$(hclean "$Q8" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(sort "$(HS)/closed" 2>/dev/null | paste -sd, -)" == "tab close w1:t2 exists=yes,tab close w1:t3 exists=yes" && -d "$Q8/.git" ]] \
    && ok "cleanup of a loop in the main worktree closes only the loop's tabs" || { bad "cleanup of a loop in the main worktree closes only the loop's tabs"; printf '       %s\n' "$out"; cat "$(HS)/closed" 2>/dev/null; }
  out="$(hclean "$MX" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && grep -qx 'impl-1' "$FAKE_XIRP_DIR/deleted" 2>/dev/null && grep -q 'tab close w1:t2' "$(HS)/closed" 2>/dev/null \
    && ok "cleanup of a loop on both hosts deletes the Xirp session and closes the herdr tab" || { bad "cleanup of a loop on both hosts deletes the Xirp session and closes the herdr tab"; printf '       %s\n' "$out"; }
  # codex-herdr-r01 regressions
  # herdr_loop <dir> <state>: a herdr loop with the reviewer opened for round 1; sets HL (worktree) and HLL (loop.yaml)
  herdr_loop() {
    herdr_project "$1"; fresh_state "$2"; start_in "$1" add-export >/dev/null 2>&1; HL="$1-add-export"; HLL="$HL/.agent-handoff/add-export/loop.yaml"
    local c; c="$(git -C "$HL" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$c/info"; printf '/r.md\n' >> "$c/info/exclude"; printf 'r\n' > "$HL/r.md"
    commit_in "$HL" impl; hw "$HL" --role implement --status done --head HEAD; route_in "$HL"
  }
  # F-01: cleanup removes no worktree until herdr confirms the close, or that the target is gone
  herdr_loop "$tmp/herdr-f1" h11; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md; hw "$HL" --role finish --status done --head HEAD
  touch "$(HS)/server-down"; out="$(hclean "$tmp/herdr-f1" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$HL" && -f "$HLL" ]] && grep -q 'herdr workspace w2' <<<"$out" \
    && ok "cleanup keeps the worktrees and fails when herdr cannot close the loop's workspace (codex-herdr-r01/F-01)" || { bad "cleanup keeps the worktrees and fails when herdr cannot close the loop's workspace (codex-herdr-r01/F-01)"; printf '       %s\n' "$out"; }
  rm -f "$(HS)/server-down"; touch "$(HS)/gone-w2"; out="$(hclean "$tmp/herdr-f1" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -e "$HL" ]] \
    && ok "a rerun of cleanup treats a workspace herdr no longer has as closed" || { bad "a rerun of cleanup treats a workspace herdr no longer has as closed"; printf '       %s\n' "$out"; }
  mkdir -p "$tmp/herdr sp"; herdr_loop "$tmp/herdr sp/p" h12; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md; hw "$HL" --role finish --status done --head HEAD
  out="$(hclean "$tmp/herdr sp/p" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -e "$HL" ]] && grep -q 'workspace close w2 exists=yes' "$(HS)/closed" 2>/dev/null \
    && ok "cleanup closes the herdr workspace of a loop whose path has spaces" || { bad "cleanup closes the herdr workspace of a loop whose path has spaces"; printf '       %s\n' "$out"; }
  # F-02: a reused herdr reviewer keeps the native session ID read when the loop started
  RV="$tmp/herdr-f2"; herdr_project "$RV"; fresh_state h13; printf 'codex\n' > "$(HS)/pane-w9:p1"
  out="$(start_in "$RV" add-export --reviewer-session w9:p1 2>&1)"; rc=$?; RVL="$RV-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$RVL" reviewer.session)" == w9:p1 && "$(kv_get "$RVL" reviewer.native_session)" == native-w9:p1 ]] \
    && ok "a reused herdr reviewer's native session ID is recorded (codex-herdr-r01/F-02)" || { bad "a reused herdr reviewer's native session ID is recorded (codex-herdr-r01/F-02)"; printf '       %s\n' "$out"; }
  printf 'native-replacement\n' > "$(HS)/native-w9:p1"; commit_in "$RV-add-export" impl; hw "$RV-add-export" --role implement --status done --head HEAD; route_in "$RV-add-export"
  ! herdr_prompts | grep -q '^w9:p1' && ! routed "$RV-add-export" 01-implement.yaml \
    && ok "a reused pane now running another session of the same tool gets no prompt" || bad "a reused pane now running another session of the same tool gets no prompt"
  # F-03: a submission whose result is unknown is never sent again
  herdr_loop "$tmp/herdr-f3" h14; commit_in "$HL" two; hw "$HL" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$(HS)/prompt-timeout"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"; route_in "$HL"; route_in "$HL"; rm -f "$(HS)/prompt-timeout"; route_in "$HL"
  (( $(herdr_prompts | wc -l) == np + 1 && $(ncount) == nn + 1 )) && routed "$HL" 02-review.yaml && jt '.kind=="attention" and (.detail|test("w2:p1"))' \
    && grep -q 'changes-required' "$HL/.agent-handoff/add-export/implementer-unconfirmed.txt" 2>/dev/null \
    && ok "an unconfirmed submission is not resent: one notice, the message kept in a file, the record processed (codex-herdr-r01/F-03)" \
    || { bad "an unconfirmed submission is not resent: one notice, the message kept in a file, the record processed (codex-herdr-r01/F-03)"; jl | tail -1; }
  # A prompt left in the composer (Enter swallowed while the agent was still starting) is submitted once more.
  herdr_loop "$tmp/herdr-stall" h14s; commit_in "$HL" two; hw "$HL" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$(HS)/stall"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"; route_in "$HL"; rm -f "$(HS)/stall"
  (( $(herdr_prompts | wc -l) == np + 1 && $(ncount) == nn + 1 )) && herdr_calls | grep -q 'agent send-keys w2:p1 enter' \
    && herdr_calls | grep -q 'agent wait w2:p1 --until working --until blocked --timeout' && routed "$HL" 02-review.yaml \
    && [[ ! -e "$HL/.agent-handoff/add-export/implementer-unconfirmed.txt" ]] && jt '.kind=="review"' \
    && ok "a stalled prompt gets one more Enter and counts as delivered once the agent starts working" \
    || { bad "a stalled prompt gets one more Enter and counts as delivered once the agent starts working"; herdr_calls | grep agent | sed 's/^/       /'; jl | tail -1; }
  herdr_loop "$tmp/herdr-stall2" h14t; commit_in "$HL" two; hw "$HL" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$(HS)/stall" "$(HS)/enter-ignored"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"; route_in "$HL"; route_in "$HL"; rm -f "$(HS)/stall" "$(HS)/enter-ignored"
  (( $(herdr_prompts | wc -l) == np + 1 && $(ncount) == nn + 1 && $(herdr_calls | grep -c 'agent send-keys') == 1 )) && routed "$HL" 02-review.yaml \
    && grep -q 'changes-required' "$HL/.agent-handoff/add-export/implementer-unconfirmed.txt" 2>/dev/null && jt '.kind=="attention" and (.detail|test("w2:p1"))' \
    && ok "a prompt still not taken after the extra Enter is kept unconfirmed: one notice, never resent" \
    || { bad "a prompt still not taken after the extra Enter is kept unconfirmed: one notice, never resent"; herdr_calls | grep agent | sed 's/^/       /'; jl | tail -1; }
  # F-05: a role already open that waits on a dialog is named by workspace and tab
  herdr_loop "$tmp/herdr-f5" h15; commit_in "$HL" two; hw "$HL" --role implement --status done --head HEAD; touch "$(HS)/blocked"; route_in "$HL"
  jt '.kind=="attention" and (.detail|test("workspace w2")) and (.detail|test("w2:t2")) and (.detail|test("codex - review - add-export"))' && ! routed "$HL" 03-implement.yaml \
    && ok "an open reviewer waiting on a dialog gets one notice naming its workspace and tab (codex-herdr-r01/F-05)" || { bad "an open reviewer waiting on a dialog gets one notice naming its workspace and tab (codex-herdr-r01/F-05)"; jl | tail -1; }
  # F-04: the host is needed only to open or message a session
  F4="$tmp/herdr-f4"; new_loop "$F4"; use_project "$F4"; fresh_state h16; rpt "$F4"; lset "$F4/.agent-handoff/add-export/loop.yaml" finish_template.host herdr
  hw "$F4" --role implement --status done --head HEAD; hw "$F4" --role review --status done --verdict pass --head HEAD --report r.md
  (cd "$F4" && PATH="$(path_without herdr)" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID=chirp-1 "$ROUTE" </dev/null)
  [[ "$(ncount)" == 1 ]] && routed "$F4" 02-review.yaml && jt '.kind=="attention" and (.next|test("handoff-finish add-export"))' \
    && ok "a pass waiting for handoff-finish is notified when the finish host is not installed (codex-herdr-r01/F-04)" || { bad "a pass waiting for handoff-finish is notified when the finish host is not installed (codex-herdr-r01/F-04)"; notes; }
  # F-06: a host value is matched exactly
  F6="$tmp/herdr-f6"; new_project "$F6"; use_project "$F6"; fresh_state h17
  awk '/^implement:/{print; print "  host: \"xirp herdr\""; next} {print}' "$F6/.agent-handoff/roles.yaml" > "$F6/r.tmp" && mv "$F6/r.tmp" "$F6/.agent-handoff/roles.yaml"
  dout="$(doctor_in "$F6" 2>&1)"; drc=$?; out="$(start_in "$F6" add-export 2>&1)"; rc=$?
  [[ "$drc" != 0 && "$rc" != 0 && ! -e "$F6-add-export" && "$(created)" == 0 ]] && grep -q '^fail role implement' <<<"$dout" && grep -q 'fail role implement' <<<"$out" \
    && ok "a host that is not exactly xirp or herdr fails doctor and start, and nothing is created (codex-herdr-r01/F-06)" || { bad "a host that is not exactly xirp or herdr fails doctor and start, and nothing is created (codex-herdr-r01/F-06)"; printf '       %s\n' "$dout" "$out"; }
  # codex-herdr-r03 regressions
  # r01/F-03 in finish: an unconfirmed finish prompt is neither resent nor taken as delivered until the user checks it
  herdr_loop "$tmp/herdr-r3a" h21; lset "$HLL" finish.trigger auto; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  touch "$(HS)/prompt-timeout"; route_in "$HL"; rm -f "$(HS)/prompt-timeout"; route_in "$HL"; nf="$(herdr_prompts | grep -c '^w2:p3')"
  uf="$HL/.agent-handoff/add-export/finish-unconfirmed.txt"
  [[ "$nf" == 1 && -f "$uf" ]] && ! routed "$HL" 02-review.yaml && ! grep -q 'finish:opened' "$HL/.agent-handoff/add-export/routing.log" \
    && jt '.kind=="attention" and (.detail|test("finish-unconfirmed.txt"))' \
    && ok "an unconfirmed automatic finish prompt is shown, kept and not taken as opened on the next hook (codex-herdr-r03, r01/F-03)" \
    || { bad "an unconfirmed automatic finish prompt is shown, kept and not taken as opened on the next hook (codex-herdr-r03, r01/F-03)"; cat "$HL/.agent-handoff/add-export/routing.log"; jl | tail -1; }
  rm -f "$uf"; (cd "$HL" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(herdr_prompts | grep -c '^w2:p3')" == 1 ]] && routed "$HL" 02-review.yaml && grep -q 'finish:opened:w2:p3' "$HL/.agent-handoff/add-export/routing.log" \
    && ok "after the user removes the file, the finish counts as opened without sending the prompt again" || { bad "after the user removes the file, the finish counts as opened without sending the prompt again"; cat "$HL/.agent-handoff/add-export/routing.log"; }
  herdr_loop "$tmp/herdr-r3b" h22; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$(HS)/prompt-timeout"; out1="$(finish_in "$HL" add-export 2>&1)"; rc1=$?; rm -f "$(HS)/prompt-timeout"
  n1="$(herdr_prompts | grep -c '^w2:p3')"; out2="$(finish_in "$HL" add-export 2>&1)"; rc2=$?
  [[ "$rc1" != 0 && "$rc2" != 0 && "$(herdr_prompts | grep -c '^w2:p3')" == "$n1" ]] && grep -q 'finish-unconfirmed.txt' <<<"$out1" && grep -q 'finish-unconfirmed.txt' <<<"$out2" \
    && ok "a finish retry whose prompt herdr did not confirm is not sent again by the next handoff-finish (codex-herdr-r03, r01/F-03)" \
    || { bad "a finish retry whose prompt herdr did not confirm is not sent again by the next handoff-finish (codex-herdr-r03, r01/F-03)"; printf '       %s\n' "$out1" "$out2"; }
  # r01/F-05: a reused reviewer waiting on a dialog is named by its real workspace and tab
  RB="$tmp/herdr-r3c"; herdr_project "$RB"; fresh_state h23; printf 'codex\n' > "$(HS)/pane-w9:p1"
  printf 'w9:p1\tw9:t4\n' >> "$(HS)/panes"; printf 'w9:t4\tmy review\n' >> "$(HS)/tablabels"
  start_in "$RB" add-export --reviewer-session w9:p1 >/dev/null 2>&1; commit_in "$RB-add-export" impl; hw "$RB-add-export" --role implement --status done --head HEAD
  touch "$(HS)/blocked"; route_in "$RB-add-export"
  [[ "$(ncount)" == 1 ]] && jt '(.detail|test("workspace w9")) and (.detail|test("tab w9:t4")) and (.detail|test("my review"))' && ! routed "$RB-add-export" 01-implement.yaml \
    && ok "a reused reviewer waiting on a dialog gets one notice naming its actual workspace and tab (codex-herdr-r03, r01/F-05)" || { bad "a reused reviewer waiting on a dialog gets one notice naming its actual workspace and tab (codex-herdr-r03, r01/F-05)"; jl | tail -1; }
  rm -f "$(HS)/blocked"; hclean "$RB" add-export --abandon --yes >/dev/null 2>&1
  ! grep -q 'w9' "$(HS)/closed" 2>/dev/null && ok "cleanup never closes a reused reviewer's tab" || bad "cleanup never closes a reused reviewer's tab"
  # r03/F-01: a herdr stop is logged with its herdr pane and native session, never an inherited Xirp ID
  herdr_loop "$tmp/herdr-r3d" h24; commit_in "$HL" two; hw "$HL" --role implement --status done --head HEAD
  (cd "$HL" && printf '{"session_id":"native-w2:p1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 \
    HERDR_ENV=1 HERDR_PANE_ID=w2:p1 CHIRP_SESSION_ID=chirp-inherited "$ROUTE")
  grep -q '02-implement.yaml action=reviewer:messaged:w2:p2 session=herdr:w2:p1 native=native-w2:p1 model=opus(template)' "$HL/.agent-handoff/add-export/routing.log" \
    && ! grep -q chirp-inherited "$HL/.agent-handoff/add-export/routing.log" \
    && ok "a herdr stop is logged with its herdr pane and native session, not the inherited Xirp ID (codex-herdr-r03/F-01)" || { bad "a herdr stop is logged with its herdr pane and native session, not the inherited Xirp ID (codex-herdr-r03/F-01)"; tail -1 "$HL/.agent-handoff/add-export/routing.log"; }
  # codex-herdr-r04 regressions
  # r01/F-03: once a finish retry was submitted for a blocked record, handoff-finish never sends it again for that record
  herdr_loop "$tmp/herdr-r4a" h31; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$(HS)/prompt-timeout"; finish_in "$HL" add-export >/dev/null 2>&1; rm -f "$(HS)/prompt-timeout"; n1="$(herdr_prompts | grep -c '^w2:p3')"
  rm -f "$HL/.agent-handoff/add-export/finish-unconfirmed.txt"; out="$(finish_in "$HL" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(herdr_prompts | grep -c '^w2:p3')" == "$n1" ]] && grep -q 'already sent.*03-finish.yaml' <<<"$out" \
    && ok "after the user clears an unconfirmed finish retry, handoff-finish does not resend it for the same record (codex-herdr-r04, r01/F-03)" \
    || { bad "after the user clears an unconfirmed finish retry, handoff-finish does not resend it for the same record (codex-herdr-r04, r01/F-03)"; printf '       %s\n' "$out"; }
  herdr_loop "$tmp/herdr-r4b" h32; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  finish_in "$HL" add-export >/dev/null 2>&1; finish_in "$HL" add-export >/dev/null 2>&1
  commit_in "$HL" again; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected again"; finish_in "$HL" add-export >/dev/null 2>&1
  [[ "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 2 ]] \
    && ok "a delivered finish retry is sent once per blocked record" || { bad "a delivered finish retry is sent once per blocked record"; herdr_prompts | grep '^w2:p3' | cut -c1-60; }
  # codex-herdr-r05 (r01/F-03): two overlapping handoff-finish runs submit the retry for one blocked record once
  herdr_loop "$tmp/herdr-r5a" h41; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  echo 2 > "$(HS)/prompt-delay"
  finish_in "$HL" add-export > "$tmp/r5-1.out" 2>&1 & p1=$!; sleep 0.5
  finish_in "$HL" add-export > "$tmp/r5-2.out" 2>&1 & p2=$!; wait "$p1"; r1=$?; wait "$p2"; r2=$?; rm -f "$(HS)/prompt-delay"
  [[ "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 1 && "$r1" == 0 && "$r2" == 0 ]] && grep -q 'already sent' "$tmp/r5-2.out" \
    && ok "two overlapping handoff-finish runs submit the retry for one blocked record once (codex-herdr-r05, r01/F-03)" \
    || { bad "two overlapping handoff-finish runs submit the retry for one blocked record once (codex-herdr-r05, r01/F-03)"; cat "$tmp/r5-1.out" "$tmp/r5-2.out" | grep -v warn; }
  herdr_loop "$tmp/herdr-r5b" h42; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$(HS)/blocked"; finish_in "$HL" add-export >/dev/null 2>&1; rc1=$?; rm -f "$(HS)/blocked"; finish_in "$HL" add-export >/dev/null 2>&1; rc2=$?
  [[ "$rc1" != 0 && "$rc2" == 0 && "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 1 ]] \
    && ok "a finish retry herdr did not send (a dialog) can be retried once the dialog is answered" || bad "a finish retry herdr did not send (a dialog) can be retried once the dialog is answered"
  # codex-herdr-r06/F-01: a claim that cannot be created is an error, not "already sent"
  MKF="$tmp/mkdir-fail-bin"; mkdir -p "$MKF"
  printf '#!/usr/bin/env bash\nfor last; do :; done\nif [[ -e "$FAKE_XIRP_DIR/mkdir-fail" && "$last" == *.finish-retry-* ]]; then echo "mkdir: $last: Permission denied" >&2; exit 1; fi\nexec /bin/mkdir "$@"\n' > "$MKF/mkdir"; chmod +x "$MKF/mkdir"
  herdr_loop "$tmp/herdr-r6a" h51; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$FAKE_XIRP_DIR/mkdir-fail"; out="$(PF_PATH="$MKF:$FAKES:$PATH" finish_in "$HL" add-export 2>&1)"; rc=$?; rm -f "$FAKE_XIRP_DIR/mkdir-fail"
  n1="$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')"
  out2="$(finish_in "$HL" add-export 2>&1)"; rc2=$?
  [[ "$rc" != 0 && "$n1" == 0 && "$rc2" == 0 && "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 1 ]] && grep -q 'Permission denied' <<<"$out" && ! grep -q 'already sent' <<<"$out" \
    && ok "a finish retry claim that cannot be created fails, sends nothing, and can be retried (codex-herdr-r06/F-01)" \
    || { bad "a finish retry claim that cannot be created fails, sends nothing, and can be retried (codex-herdr-r06/F-01)"; printf '       %s\n' "$out" | grep -v warn; }
  # r03/F-01: a manual run does not name whoever ran it as the stopping session
  herdr_loop "$tmp/herdr-r4c" h33; commit_in "$HL" two; hw "$HL" --role implement --status done --head HEAD
  (cd "$HL" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HERDR_ENV=1 HERDR_PANE_ID=w1:p9 CHIRP_SESSION_ID=chirp-inherited "$ROUTE" --foreground </dev/null)
  grep -q '02-implement.yaml action=reviewer:messaged:w2:p2 session=unknown trigger=herdr:w1:p9 model=opus(template)' "$HL/.agent-handoff/add-export/routing.log" \
    && ok "a manual run logs the stopping session as unknown and names who ran it separately (codex-herdr-r04, r03/F-01)" || { bad "a manual run logs the stopping session as unknown and names who ran it separately (codex-herdr-r04, r03/F-01)"; tail -1 "$HL/.agent-handoff/add-export/routing.log"; }
  Q3="$tmp/herdr-busy"; herdr_project "$Q3"; fresh_state h3; echo 1 > "$(HS)/busy"
  printf '%s\n' "{\"workspace_id\":\"w9\",\"label\":\"repo\",\"worktree\":{\"checkout_path\":\"$Q3\"}}" > "$(HS)/workspaces"
  out="$(start_in "$Q3" add-export --impl codex:gpt-x:low 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(herdr_calls | grep -c 'agent start')" == 2 ]] && ! herdr_calls | grep -q 'workspace create' && herdr_calls | grep -qF 'worktree open --workspace w9 ' \
    && herdr_calls | grep 'agent start' | tail -1 | grep -qE -- '--kind codex --pane w1:p1 -- -m gpt-x -c model_reasoning_effort=low$' \
    && ok "an open repository workspace is reused, and a busy new pane is retried" || { bad "an open repository workspace is reused, and a busy new pane is retried"; printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }
  Q4="$tmp/herdr-here"; herdr_project "$Q4"; fresh_state h4; git -C "$Q4" switch -q feature/add-export
  out="$(start_in "$Q4" add-export --worktree here 2>&1)"; rc=$?; q4l="$Q4/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$q4l" implementer.session)" == w1:p2 && "$(kv_get "$q4l" implementer.herdr_tab)" == w1:t2 && -z "$(kv_get "$q4l" herdr.workspaces 2>/dev/null)" ]] \
    && ! herdr_calls | grep -q 'worktree open' && herdr_calls | grep -qF "tab create --workspace w1 --cwd $Q4 --label claude - impl - add-export --no-focus" \
    && ok "an implementer in the main worktree opens a tab in the repository workspace" || { bad "an implementer in the main worktree opens a tab in the repository workspace"; printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }
  # Replacing a herdr reviewer closes only its tab: the workspace also holds the implementer.
  Q9="$tmp/herdr-replace"; herdr_project "$Q9"; fresh_state h9; Q9W="$Q9-add-export"; q9l="$Q9W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q9" add-export >/dev/null 2>&1; commit_in "$Q9W" impl; hw "$Q9W" --role implement --status done --head HEAD; route_in "$Q9W" >/dev/null 2>&1
  wrpt "$Q9W"; hw "$Q9W" --role review --status done --verdict changes-required --head HEAD --report r.md
  out="$(role_in "$Q9W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && -z "$(kv_get "$q9l" reviewer.session)" && -z "$(kv_get "$q9l" reviewer.herdr_tab)" && -z "$(kv_get "$q9l" reviewer.native_session)" ]] \
    && grep -q '^tab close w2:t2 ' "$(HS)/closed" 2>/dev/null && ! grep -q '^workspace close' "$(HS)/closed" \
    && ok "replacing a herdr reviewer closes only its tab and clears its session" || { bad "replacing a herdr reviewer closes only its tab and clears its session"; printf '       %s\n' "$out"; cat "$(HS)/closed" 2>/dev/null | sed 's/^/       /'; }
  Q10="$tmp/herdr-replace-other"; herdr_project "$Q10"; fresh_state h10; Q10W="$Q10-add-export"; q10l="$Q10W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q10" add-export >/dev/null 2>&1; commit_in "$Q10W" impl; hw "$Q10W" --role implement --status done --head HEAD; route_in "$Q10W" >/dev/null 2>&1
  wrpt "$Q10W"; hw "$Q10W" --role review --status done --verdict changes-required --head HEAD --report r.md
  printf 'other-session\n' > "$(HS)/native-w2:p2"; s0="$(cksum < "$q10l")"
  out="$(role_in "$Q10W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(cksum < "$q10l")" == "$s0" && ! -s "$(HS)/closed" ]] && grep -q 'native' <<<"$out" \
    && ok "a herdr reviewer pane that now runs another session is not closed (codex-role-review-r01/F-02)" || { bad "a herdr reviewer pane that now runs another session is not closed (codex-role-review-r01/F-02)"; printf '       %s\n' "$out"; }
  rm -f "$(HS)/native-w2:p2"; lset "$q10l" reviewer.herdr_tab ""; s0="$(cksum < "$q10l")"
  out="$(role_in "$Q10W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(cksum < "$q10l")" == "$s0" && ! -s "$(HS)/closed" ]] && grep -q 'tab' <<<"$out" \
    && ok "a herdr reviewer without a recorded tab is not closed (codex-role-review-r01/F-02)" || { bad "a herdr reviewer without a recorded tab is not closed (codex-role-review-r01/F-02)"; printf '       %s\n' "$out"; }
  # codex-role-review-r02/F-03: a prompt herdr did not confirm is not sent again by a retry.
  Q12="$tmp/herdr-replace-unconfirmed"; herdr_project "$Q12"; fresh_state h12; Q12W="$Q12-add-export"; q12l="$Q12W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q12" add-export >/dev/null 2>&1; commit_in "$Q12W" impl; hw "$Q12W" --role implement --status done --head HEAD; route_in "$Q12W" >/dev/null 2>&1
  touch "$(HS)/prompt-timeout"
  out="$(role_in "$Q12W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  rm -f "$(HS)/prompt-timeout"; np="$(kv_get "$q12l" reviewer.session)"
  routed "$Q12W" 01-implement.yaml; r1=$?; held=0; [[ -f "$Q12W/.agent-handoff/add-export/reviewer-unconfirmed.txt" ]] && held=1
  rm -f "$Q12W/.agent-handoff/add-export/reviewer-unconfirmed.txt"
  (cd "$Q12W" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" CLAUDE_PROJECT_DIR="$Q12W" "$ROUTE" --foreground </dev/null >/dev/null 2>&1)
  [[ "$rc" != 0 && "$r1" == 0 && "$held" == 1 && -n "$np" && "$(herdr_prompts | grep -c "^$np"$'\t')" == 1 ]] && grep -q 'unconfirmed' <<<"$out" \
    && ok "a replacement whose new prompt herdr did not confirm is not sent again (codex-role-review-r02/F-03)" || { bad "a replacement whose new prompt herdr did not confirm is not sent again (codex-role-review-r02/F-03)"; printf '       %s\n' "$out"; }
  Q11="$tmp/herdr-fin-replace"; herdr_project "$Q11"; fresh_state h11; Q11W="$Q11-add-export"; q11l="$Q11W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q11" add-export >/dev/null 2>&1; commit_in "$Q11W" impl; hw "$Q11W" --role implement --status done --head HEAD
  wrpt "$Q11W"; hw "$Q11W" --role review --status done --verdict pass --head HEAD --report r.md
  touch "$(HS)/prompt-timeout"; finish_in "$Q11W" add-export >/dev/null 2>&1; rm -f "$(HS)/prompt-timeout"; fp="$(kv_get "$q11l" finish.session)"
  out="$(role_in "$Q11W" add-export finish codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  np="$(kv_get "$q11l" finish.session)"
  [[ -n "$fp" && "$rc" == 0 && -n "$np" && "$np" != "$fp" && ! -e "$Q11W/.agent-handoff/add-export/finish-unconfirmed.txt" \
    && "$(herdr_prompts | grep -c "^$np"$'\t')" == 1 ]] && grep -q '^tab close' "$(HS)/closed" \
    && ok "replacing a finish role whose prompt herdr did not confirm opens the new one with one prompt (codex-role-review-r01/F-05)" || { bad "replacing a finish role whose prompt herdr did not confirm opens the new one with one prompt (codex-role-review-r01/F-05)"; printf '       %s\n' "$out"; }
fi

# ---------------------------------------------------------------- herdr-app host (Herdr desktop app)
HA() { printf '%s' "$FAKE_XIRP_DIR/happ"; }
HC() { printf '%s' "$FAKE_XIRP_DIR/hc"; }
# happ_do <command>: the recorded herdr-app do calls of that command, one JSON array each
happ_do() { jq -c --arg c "$1" 'select(.[0] == "do" and .[1] == $c)' "$(HA)/calls" 2>/dev/null; }
# happ_opt <call-json> <option>: that option's value in one recorded call
happ_opt() { jq -r --arg k "--$2" '. as $a | [range(length) | select($a[.] == $k) | $a[. + 1]][0] // empty' <<<"$1"; }
hc_sends() { cat "$(HC)/sends" 2>/dev/null; }
# happ_project <dir> [roles.yaml lines...]: project whose roles all run on the Herdr app (plus the given lines)
happ_project() {
  local d="$1" l; shift; new_project "$d"; use_project "$d"
  { printf 'host: herdr-app\n'; for l in "$@"; do printf '%s\n' "$l"; done; cat "$d/.agent-handoff/roles.yaml"; } > "$d/r.tmp" && mv "$d/r.tmp" "$d/.agent-handoff/roles.yaml"
}
# happ_loop <dir> <state>: a herdr-app loop with the reviewer opened for round 1; sets AL (worktree) and ALL (loop.yaml)
happ_loop() {
  happ_project "$1"; fresh_state "$2"; start_in "$1" add-export >/dev/null 2>&1; AL="$1-add-export"; ALL="$AL/.agent-handoff/add-export/loop.yaml"
  wrpt "$AL"; commit_in "$AL" impl; hw "$AL" --role implement --status done --head HEAD; route_in "$AL"
}
hclean() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" "$@" </dev/null); }
if run_section happ; then
  printf 'herdr-app host\n'
  source "$KV"
  # 1.3 environment checks
  AD="$tmp/happ-doc"; happ_project "$AD"; fresh_state a1; ADR="$AD/.agent-handoff/roles.yaml"
  out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok host implement, review, finish: .*Herdr app.*herdr-core 0.1.21' <<<"$out" && ! grep -q 'xirp\|^ok host .*herdr 0.9' <<<"$out" \
    && ok "a herdr-app loop checks the Herdr app and herdr-core, shows the core version, and not Xirp or herdr" || { bad "a herdr-app loop checks the Herdr app and herdr-core, shows the core version, and not Xirp or herdr"; printf '       %s\n' "$out"; }
  touch "$(HA)/app-closed"; out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*Herdr app is not open.*open' <<<"$out" \
    && ok "a closed Herdr app fails the host check and asks to open it" || { bad "a closed Herdr app fails the host check and asks to open it"; printf '       %s\n' "$out"; }
  out="$(start_in "$AD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && ! -e "$AD-add-export" && -z "$(happ_do space.new)$(happ_do tab.new)" && "$(created)" == 0 ]] && grep -q 'handoff-start: fail host .*Herdr app' <<<"$out" \
    && ok "handoff-start refuses while the Herdr app is closed and opens no session on any host" || { bad "handoff-start refuses while the Herdr app is closed and opens no session on any host"; printf '       %s\n' "$out"; }
  rm -f "$(HA)/app-closed"; touch "$(HC)/core-down"; out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*herdr-core is not running' <<<"$out" \
    && ok "herdr-core that is not running fails the host check" || { bad "herdr-core that is not running fails the host check"; printf '       %s\n' "$out"; }
  rm -f "$(HC)/core-down"
  out="$(PF_PATH="$(path_without herdr-app)" pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*herdr-app command was not found' <<<"$out" \
    && ok "a missing herdr-app command fails the host check and names it" || { bad "a missing herdr-app command fails the host check and names it"; printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without hc)" pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*hc command .*not found' <<<"$out" \
    && ok "a missing hc command fails the host check and names it" || { bad "a missing hc command fails the host check and names it"; printf '       %s\n' "$out"; }
  # 1.1 host value
  AV="$tmp/happ-value"; happ_project "$AV"; fresh_state a2; out="$(start_in "$AV" add-export 2>&1)"; rc=$?; avl="$AV-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$avl" implement_template.host)" == herdr-app && "$(kv_get "$avl" review_template.host)" == herdr-app \
    && "$(kv_get "$avl" finish_template.host)" == herdr-app && ! -s "$FAKE_XIRP_DIR/herdr/calls" && "$(created)" == 0 ]] \
    && ok "host: herdr-app is recorded for every role and no herdr TUI or Xirp command is used" || { bad "host: herdr-app is recorded for every role and no herdr TUI or Xirp command is used"; printf '       %s\n' "$out"; }
  # 2.1 opening
  c="$(happ_do space.new)"; AW="$AV-add-export"
  [[ "$(happ_opt "$c" name)" == add-export && "$(happ_opt "$c" folder)" == "$AW" && "$(happ_opt "$c" tab)" == "claude - impl - add-export" \
    && "$(happ_opt "$c" focus)" == false && "$(happ_opt "$c" argv)" == '["claude","--model","opus","--effort","high","--name","claude - impl - add-export"]' ]] \
    && happ_opt "$c" task | grep -q 'openspec-apply-change add-export' \
    && ok "the implementer opens a space named after the change, with Claude's argv, the prompt as its task and no focus" || { bad "the implementer opens a space named after the change, with Claude's argv, the prompt as its task and no focus"; printf '       %s\n' "$c"; }
  [[ "$(kv_get "$avl" implementer.session)" == t1 && "$(kv_get "$avl" implementer.happ_space)" == sp1 && "$(kv_get "$avl" implementer.happ_tab)" == tb1 \
    && "$(kv_get "$avl" herdr_app.spaces)" == sp1 && "$(kv_get "$avl" implementer.pending_prompt 2>/dev/null)" != true && ! -e "$AW/.agent-handoff/add-export/implementer-unconfirmed.txt" ]] \
    && ok "loop.yaml records the terminal, space, tab and the space the loop opened" || { bad "loop.yaml records the terminal, space, tab and the space the loop opened"; cat "$avl"; }
  wrpt "$AW"; commit_in "$AW" impl; hw "$AW" --role implement --status done --head HEAD; route_in "$AW"; c="$(happ_do tab.new)"
  [[ "$(happ_opt "$c" space)" == sp1 && "$(happ_opt "$c" name)" == "codex - review - add-export" && "$(happ_opt "$c" focus)" == false \
    && "$(happ_opt "$c" argv)" == '["codex","-m","gpt-6.1-sol","-c","model_reasoning_effort=high"]' && "$(kv_get "$avl" reviewer.session)" == t2 \
    && "$(kv_get "$avl" herdr_app.spaces)" == sp1 && "$(happ_do space.new | wc -l | tr -d ' ')" == 1 ]] && happ_opt "$c" task | grep -q 'change-review add-export' && routed "$AW" 01-implement.yaml \
    && ok "a shared reviewer opens as a tab in the loop's space with Codex's argv" || { bad "a shared reviewer opens as a tab in the loop's space with Codex's argv"; printf '       %s\n' "$c"; cat "$AW/.agent-handoff/add-export/routing.log"; }
  # 3.1 messages
  hw "$AW" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$AW"
  hc_sends | grep -q $'^t1\t.*changes-required' && routed "$AW" 02-review.yaml \
    && ok "changes-required is sent to the implementer's idle terminal and the record is processed" || { bad "changes-required is sent to the implementer's idle terminal and the record is processed"; hc_sends; tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  # 3.2 the routing log names the stopping terminal
  grep -q '02-review.yaml action=implementer:messaged:t1 session=chirp-1 model=gpt-6.1-sol(template)' "$AW/.agent-handoff/add-export/routing.log" \
    && ok "without HC_TERMINAL_ID the routing log names the session as before, with the herdr-app role's template model" || { bad "without HC_TERMINAL_ID the routing log names the session as before, with the herdr-app role's template model"; tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  commit_in "$AW" two; hw "$AW" --role implement --status done --head HEAD
  (cd "$AW" && printf '{"session_id":"native-1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 \
    HC_TERMINAL_ID=t1 CHIRP_SESSION_ID=chirp-inherited "$ROUTE")
  grep -q '03-implement.yaml action=reviewer:messaged:t2 session=herdr-app:t1 native=native-1 model=opus(template)' "$AW/.agent-handoff/add-export/routing.log" \
    && ! grep -q chirp-inherited "$AW/.agent-handoff/add-export/routing.log" && hc_sends | grep -q $'^t2\t.*第 2 輪' \
    && ok "with HC_TERMINAL_ID the routing log names herdr-app:<terminal>, never an inherited Xirp ID" || { bad "with HC_TERMINAL_ID the routing log names herdr-app:<terminal>, never an inherited Xirp ID"; tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  # blocked: nothing is answered, one notice, the record stays unprocessed
  commit_in "$AW" three; hw "$AW" --role implement --status done --head HEAD; touch "$(HC)/blocked"; ns="$(hc_sends | wc -l)"; nn="$(ncount)"
  route_in "$AW"; route_in "$AW"
  [[ "$(hc_sends | wc -l)" == "$ns" && "$(ncount)" == $((nn + 1)) ]] && ! routed "$AW" 04-implement.yaml && ! grep -q -- '--force' "$(HC)/calls" \
    && jt '.kind=="attention" and (.detail|test("permission")) and (.detail|test("add-export")) and (.detail|test("codex - review - add-export"))' \
    && ok "a reviewer at a permission dialog gets no text, one notice naming its space and tab, and the record stays unprocessed" || { bad "a reviewer at a permission dialog gets no text, one notice naming its space and tab, and the record stays unprocessed"; jl | tail -1; }
  rm -f "$(HC)/blocked"; (cd "$AW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(hc_sends | grep -c $'^t2\t.*第 3 輪')" == 1 ]] && routed "$AW" 04-implement.yaml \
    && ok "after the dialog is answered a foreground retry sends the round once" || bad "after the dialog is answered a foreground retry sends the round once"
  # a terminal that has finished: delivery fails, nothing is sent
  commit_in "$AW" four; hw "$AW" --role implement --status done --head HEAD; touch "$(HC)/finished-t2"; ns="$(hc_sends | wc -l)"
  route_in "$AW"
  [[ "$(hc_sends | wc -l)" == "$ns" ]] && ! routed "$AW" 05-implement.yaml && grep -q '05-implement.yaml action=reviewer:send-failed:t2' "$AW/.agent-handoff/add-export/routing.log" \
    && ok "a reviewer terminal that has finished gets no text and the delivery fails" || { bad "a reviewer terminal that has finished gets no text and the delivery fails"; tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  rm -f "$(HC)/finished-t2"; touch "$(HC)/shell-t2"; route_in "$AW"
  [[ "$(hc_sends | wc -l)" == "$ns" ]] && ! routed "$AW" 05-implement.yaml \
    && ok "a reviewer terminal that now runs a shell gets no text" || bad "a reviewer terminal that now runs a shell gets no text"
  # started:false: kept unconfirmed, never resent
  rm -f "$(HC)/shell-t2"; touch "$(HC)/send-unstarted"; ns="$(hc_sends | wc -l)"
  (cd "$AW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null); route_in "$AW"; rm -f "$(HC)/send-unstarted"
  (( $(hc_sends | wc -l) == ns + 1 )) && routed "$AW" 05-implement.yaml && grep -q '第 4 輪' "$AW/.agent-handoff/add-export/reviewer-unconfirmed.txt" 2>/dev/null \
    && ok "a send that did not start a turn is kept in an unconfirmed file and not sent again" || { bad "a send that did not start a turn is kept in an unconfirmed file and not sent again"; tail -2 "$AW/.agent-handoff/add-export/routing.log"; }
  # first prompt not observed: unconfirmed, one notice, not resent
  happ_project "$tmp/happ-nostart"; fresh_state a3; start_in "$tmp/happ-nostart" add-export >/dev/null 2>&1; NW="$tmp/happ-nostart-add-export"
  commit_in "$NW" impl; hw "$NW" --role implement --status done --head HEAD; touch "$(HC)/no-start"; nn="$(ncount)"
  route_in "$NW"; route_in "$NW"
  [[ "$(happ_do tab.new | wc -l | tr -d ' ')" == 1 && "$(ncount)" == $((nn + 1)) && "$(kv_get "$NW/.agent-handoff/add-export/loop.yaml" reviewer.session)" == t2 ]] \
    && grep -q 'change-review add-export' "$NW/.agent-handoff/add-export/reviewer-unconfirmed.txt" 2>/dev/null && routed "$NW" 01-implement.yaml && jt '.kind=="attention"' \
    && ok "a first prompt with no started turn is kept unconfirmed with one notice and not resent" || { bad "a first prompt with no started turn is kept unconfirmed with one notice and not resent"; cat "$NW/.agent-handoff/add-export/routing.log"; }
  # first prompt waits on a dialog: the tab is kept, one notice names it, a retry opens nothing new
  happ_project "$tmp/happ-dialog"; fresh_state a4; start_in "$tmp/happ-dialog" add-export >/dev/null 2>&1; BW="$tmp/happ-dialog-add-export"; bwl="$BW/.agent-handoff/add-export/loop.yaml"
  commit_in "$BW" impl; hw "$BW" --role implement --status done --head HEAD; touch "$(HC)/blocked"
  route_in "$BW"; route_in "$BW"
  [[ "$(ncount)" == 1 && "$(kv_get "$bwl" reviewer.session)" == t2 && "$(kv_get "$bwl" reviewer.pending_prompt)" == true ]] && ! routed "$BW" 01-implement.yaml \
    && jt '.kind=="attention" and (.detail|test("add-export")) and (.detail|test("codex - review - add-export")) and (.next|test("handoff-route --foreground"))' \
    && ok "a reviewer whose first prompt waits on a dialog keeps its tab and gets one notice naming its space and tab" || { bad "a reviewer whose first prompt waits on a dialog keeps its tab and gets one notice naming its space and tab"; jl | tail -1; }
  rm -f "$(HC)/blocked"; (cd "$BW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(happ_do tab.new | wc -l | tr -d ' ')" == 1 && -z "$(kv_get "$bwl" reviewer.pending_prompt)" && ! -s "$(HC)/sends" ]] && routed "$BW" 01-implement.yaml \
    && ok "after the dialog a retry takes the handed prompt as delivered without opening or sending again" || { bad "after the dialog a retry takes the handed prompt as delivered without opening or sending again"; cat "$BW/.agent-handoff/add-export/routing.log"; }
  # a reviewer with a worktree of its own opens its own space
  happ_project "$tmp/happ-new"; awk '/^review:/{print; print "  worktree: new"; next} /^  worktree: shared/ && r==0 {r=1; next} {print}' "$tmp/happ-new/.agent-handoff/roles.yaml" > "$tmp/r.tmp"
  cp "$tmp/r.tmp" "$tmp/happ-new/.agent-handoff/roles.yaml"; fresh_state a5; start_in "$tmp/happ-new" add-export >/dev/null 2>&1; EW="$tmp/happ-new-add-export"
  commit_in "$EW" impl; hw "$EW" --role implement --status done --head HEAD; route_in "$EW"; c="$(happ_do space.new | tail -1)"
  [[ "$(happ_opt "$c" name)" == "add-export review" && "$(happ_opt "$c" folder)" == "$EW-review" && "$(happ_opt "$c" tab)" == "codex - review - add-export" \
    && -z "$(happ_do tab.new)" && "$(kv_get "$EW/.agent-handoff/add-export/loop.yaml" herdr_app.spaces)" == "sp1 sp2" ]] \
    && ok "a reviewer with worktree new opens a space of its own" || { bad "a reviewer with worktree new opens a space of its own"; printf '       %s\n' "$c"; cat "$EW/.agent-handoff/add-export/loop.yaml"; }
  # mixed hosts: implementer on Xirp, reviewer on the Herdr app
  MA="$tmp/happ-mixed"; new_loop "$MA"; use_project "$MA"; fresh_state a6; rpt "$MA"; mal="$MA/.agent-handoff/add-export/loop.yaml"; lset "$mal" review_template.host herdr-app
  hw "$MA" --role implement --status done --head HEAD; route_in "$MA"
  hw "$MA" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$MA"
  commit_in "$MA" two; hw "$MA" --role implement --status done --head HEAD; route_in "$MA"
  [[ "$(created)" == 0 && "$(kv_get "$mal" reviewer.session)" == t1 ]] && msgs | grep -q $'^impl-1\t.*changes-required' && hc_sends | grep -q $'^t1\t.*第 2 輪' \
    && [[ "$(happ_opt "$(happ_do space.new)" name)" == add-export ]] \
    && ok "with the implementer on Xirp and the reviewer on the Herdr app, each message goes through its receiver's CLI" || { bad "with the implementer on Xirp and the reviewer on the Herdr app, each message goes through its receiver's CLI"; msgs; hc_sends; }
  # 4.1 cleanup
  happ_loop "$tmp/happ-clean" a7; hw "$AL" --role review --status done --verdict pass --head HEAD --report r.md; hw "$AL" --role finish --status done --head HEAD
  out="$(hclean "$tmp/happ-clean" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -s "$(HA)/closed" ]] && grep -q 'herdr-app space sp1' <<<"$out" && [[ "$(grep -c 'herdr-app ' <<<"$out")" == 1 ]] \
    && ok "the cleanup preview lists the Herdr app space the loop opened, once, and closes nothing" || { bad "the cleanup preview lists the Herdr app space the loop opened, once, and closes nothing"; printf '       %s\n' "$out"; }
  touch "$(HA)/app-closed"; out="$(hclean "$tmp/happ-clean" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$AL" && -f "$ALL" && ! -s "$(HA)/closed" ]] && grep -q 'Herdr app' <<<"$out" \
    && ok "cleanup with the Herdr app closed fails, asks to open it and removes no worktree" || { bad "cleanup with the Herdr app closed fails, asks to open it and removes no worktree"; printf '       %s\n' "$out"; }
  rm -f "$(HA)/app-closed"; out="$(hclean "$tmp/happ-clean" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(cat "$(HA)/closed" 2>/dev/null)" == "space.close sp1 exists=yes" && ! -e "$AL" ]] && git -C "$tmp/happ-clean" show-ref -q --verify refs/heads/feature/add-export \
    && [[ "$(sort "$(HC)/removed" 2>/dev/null | paste -sd, -)" == "t1,t2" ]] && happ_do space.close | grep -q '"--confirmed","true"' \
    && ok "cleanup closes the loop's space before removing the worktree, removes its terminals and keeps the branch" || { bad "cleanup closes the loop's space before removing the worktree, removes its terminals and keeps the branch"; printf '       %s\n' "$out"; cat "$(HA)/closed" "$(HC)/removed" 2>/dev/null; }
  # only what the loop opened: a role in a space the loop did not open closes only its tab; a reused terminal is left alone
  happ_loop "$tmp/happ-other" a8
  printf 'spU\tmine\t%s\n' "$tmp" >> "$(HA)/spaces"; awk -F'\t' -v OFS='\t' '$1 == "tb2" {$2 = "spU"} {print}' "$(HA)/tabs" > "$tmp/t.tmp" && cat "$tmp/t.tmp" > "$(HA)/tabs"
  lset "$ALL" reviewer.happ_space spU
  out="$(hclean "$tmp/happ-other" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(sort "$(HA)/closed" | paste -sd, -)" == "space.close sp1 exists=yes,tab.close tb2 exists=yes" ]] && grep -q $'^spU\t' "$(HA)/spaces" \
    && ok "a role in a space the loop did not open has only its tab closed" || { bad "a role in a space the loop did not open has only its tab closed"; printf '       %s\n' "$out"; cat "$(HA)/closed"; }
  happ_project "$tmp/happ-reuse"; fresh_state a9; mkdir -p "$(HC)"; jq -n '{address:"t9", state:"live", argv:["codex"], turn:3, labels:{where:"mine / review"}}' > "$(HC)/term-t9"
  out="$(start_in "$tmp/happ-reuse" add-export --reviewer-session t9 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$tmp/happ-reuse-add-export/.agent-handoff/add-export/loop.yaml" reviewer.session)" == t9 ]] \
    && ok "an existing Herdr app terminal running the review harness can be reused as the reviewer" || { bad "an existing Herdr app terminal running the review harness can be reused as the reviewer"; printf '       %s\n' "$out"; }
  hclean "$tmp/happ-reuse" add-export --abandon --yes >/dev/null 2>&1
  [[ -f "$(HC)/term-t9" ]] && ! grep -q 't9' "$(HA)/closed" 2>/dev/null && ok "cleanup never closes or removes a reused terminal" || bad "cleanup never closes or removes a reused terminal"
  out="$(start_in "$tmp/happ-reuse" add-export --reviewer-session t404 2>&1)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q "t404" <<<"$out" && ok "a reviewer terminal that does not exist is refused" || { bad "a reviewer terminal that does not exist is refused"; printf '       %s\n' "$out"; }
fi

# ---------------------------------------------------------------- user-level installer and README
if run_section hookinstall; then
  printf 'hook installer\n'
  HH="$tmp/home"; mkdir -p "$HH/.codex"; printf 'keep = true\n' > "$HH/.codex/config.toml"
  out="$(HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" 2>&1)"; rc=$?
  HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$rc" == 0 && -x "$HH/.local/bin/handoff-start" && -x "$HH/.local/bin/handoff-finish" && -x "$HH/.local/bin/handoff-cleanup" && -x "$HH/.local/bin/handoff-role" && -x "$HH/.local/bin/handoff-doctor" && -x "$HH/.config/wk-workflow/handoff/handoff-route" \
    && -f "$HH/.config/wk-workflow/handoff/lib/handoff.sh" && -f "$HH/.config/wk-workflow/handoff/lib/kv.sh" ]] \
    && ok "installs the commands, the hook and its libraries" || { bad "installs the commands, the hook and its libraries"; printf '       %s\n' "$out"; }
  n_claude="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$HH/.claude/settings.json" 2>/dev/null)"
  n_codex="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$HH/.codex/hooks.json" 2>/dev/null)"
  [[ "$n_claude" == 1 && "$n_codex" == 1 ]] && ok "registers exactly one Stop hook for Claude Code and Codex after two runs" || bad "registers exactly one Stop hook for Claude Code and Codex after two runs ($n_claude/$n_codex)"
  NP="$HH/.codex/handoff-net.config.toml"
  [[ -f "$NP" ]] && grep -qx 'sandbox_mode = "workspace-write"' "$NP" && grep -qx 'network_access = true' "$NP" \
    && ok "creates the handoff-net Codex profile with network access" || bad "creates the handoff-net Codex profile with network access"
  printf 'model = "mine"\n' > "$NP"; HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$(cat "$NP")" == 'model = "mine"' ]] && ok "never overwrites an existing handoff-net profile" || bad "never overwrites an existing handoff-net profile"
  [[ "$(cat "$HH/.codex/config.toml")" == "keep = true" ]] && grep -qi 'trust' <<<"$out" && ok "tells the user to trust the Codex hook and leaves Codex trust state alone" || bad "tells the user to trust the Codex hook and leaves Codex trust state alone"
  (cd "$tmp" && HOME="$HH" "$HH/.local/bin/handoff-start" --help >/dev/null 2>&1) && ok "installed handoff-start runs with the installed library" || bad "installed handoff-start runs with the installed library"

  hname="Agent 交接派送"
  hname_of() { jq -r --arg cmd "$2" '[.hooks.Stop[]?.hooks[]? | select(.command == $cmd) | .statusMessage] | join("|")' "$1"; }
  hcmd="bash \"$HH/.config/wk-workflow/handoff/handoff-route\""
  [[ "$(hname_of "$HH/.codex/hooks.json" "$hcmd")" == "$hname" && "$(jq '[.. | objects | select(has("statusMessage"))] | length' "$HH/.claude/settings.json")" == 0 ]] \
    && ok "names the new Codex Stop hook and leaves the Claude Code hook format alone" || bad "names the new Codex Stop hook and leaves the Claude Code hook format alone"
  NH="$tmp/name-home"; ncmd="bash \"$NH/.config/wk-workflow/handoff/handoff-route\""; nfail=""
  for blank in absent null '""' '"   "'; do
    rm -rf "$NH"; mkdir -p "$NH/.codex"
    jq -n --arg cmd "$ncmd" --arg blank "$blank" \
      '{hooks:{Stop:[{matcher:"",hooks:[{type:"command",command:$cmd,timeout:10} + (if $blank == "absent" then {} else {statusMessage:($blank|fromjson)} end)]}]}}' > "$NH/.codex/hooks.json"
    HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
    [[ "$(hname_of "$NH/.codex/hooks.json" "$ncmd")" == "$hname" && "$(jq '[.hooks.Stop[]?.hooks[]?] | length' "$NH/.codex/hooks.json")" == 1 ]] || nfail="$nfail $blank"
  done
  [[ -z "$nfail" ]] && ok "fills absent, null, empty and whitespace handoff names in place" || bad "fills absent, null, empty and whitespace handoff names in place (failed:$nfail)"
  rm -rf "$NH"; mkdir -p "$NH/.codex"; printf 'keep = true\n' > "$NH/.codex/config.toml"
  jq -n --arg cmd "$ncmd" '{top:"keep",hooks:{Stop:[{matcher:"",note:"keep",hooks:[{type:"command",command:"other-stop",statusMessage:"第三方"},{type:"command",command:$cmd,timeout:10,statusMessage:"我的交接"}]}]}}' > "$NH/.codex/hooks.json"
  nbefore="$(jq -S . "$NH/.codex/hooks.json")"
  HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1; nfirst="$(jq -S . "$NH/.codex/hooks.json")"
  HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$nbefore" == "$nfirst" && "$nfirst" == "$(jq -S . "$NH/.codex/hooks.json")" && "$(cat "$NH/.codex/config.toml")" == "keep = true" ]] \
    && ok "keeps a custom handoff name and a third-party Stop hook unchanged across two runs without touching trust" \
    || bad "keeps a custom handoff name and a third-party Stop hook unchanged across two runs without touching trust"
  rm -rf "$NH"; mkdir -p "$NH/.codex"
  jq -n --arg cmd "$ncmd" '{hooks:{Stop:[{matcher:"",note:"keep",hooks:[{type:"command",command:"other-stop"},{type:"command",command:$cmd,timeout:10,extra:"keep"}]}]}}' > "$NH/.codex/hooks.json"
  nbefore="$(jq -S . "$NH/.codex/hooks.json")"
  HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$(hname_of "$NH/.codex/hooks.json" "$ncmd")" == "$hname" && "$(hname_of "$NH/.codex/hooks.json" other-stop)" == "" \
    && "$(jq -S 'walk(if type == "object" then del(.statusMessage) else . end)' "$NH/.codex/hooks.json")" == "$nbefore" ]] \
    && ok "naming an existing handoff hook changes only its statusMessage" || bad "naming an existing handoff hook changes only its statusMessage"

  readme="$ROOT/scripts/handoff/README.md"
  missing=""
  for opt in $( { "$START" --help; "$FINISH" --help; "$ROOT/scripts/handoff/handoff-cleanup" --help; "$ROOT/scripts/handoff/handoff-role" --help; } 2>/dev/null | grep -oE -- '--[a-z][a-z-]+' | sort -u); do
    grep -q -- "$opt" "$readme" 2>/dev/null || missing="$missing $opt"
  done
  [[ -f "$readme" && -z "$missing" ]] && grep -q 'handoff-finish' "$readme" && grep -q 'handoff-role' "$readme" && grep -q 'roles.yaml' "$readme" \
    && ok "README documents every command option" || bad "README documents every command option (missing:$missing)"
  grep -q '^## Session hosts' "$readme" && grep -q 'host: herdr' "$readme" && grep -q 'herdr_session' "$readme" && grep -q 'ghostty + tmux' "$readme" \
    && grep -q '^# host: herdr' "$SKILL/roles.example.yaml" && grep -q '^# herdr_session:' "$SKILL/roles.example.yaml" \
    && ok "README and roles.example.yaml document host, herdr_session and the possible ghostty + tmux host" || bad "README and roles.example.yaml document host, herdr_session and the possible ghostty + tmux host"
  grep -q '^### herdr-app' "$readme" && grep -q 'host: herdr-app' "$readme" && grep -q 'herdr-app do space.new' "$readme" && grep -q 'Herdr app' "$ROOT/docs/skills/agent-handoff.md" \
    && grep -q '^# Session host: .*xirp (default), herdr or herdr-app' "$SKILL/roles.example.yaml" \
    && ok "README, the skill guide and roles.example.yaml document the herdr-app host" || bad "README, the skill guide and roles.example.yaml document the herdr-app host"
  grep -qF -- '--replace' "$readme" && grep -qF -- '--worktree new' "$readme" && grep -qF -- '--replace' "$ROOT/docs/skills/agent-handoff.md" && grep -qF -- '--worktree new' "$ROOT/docs/skills/agent-handoff.md" \
    && ok "README and the skill guide document handoff-role --replace and --worktree new" || bad "README and the skill guide document handoff-role --replace and --worktree new"
  grep -q 'HERDR_ENV' "$SKILL/SKILL.md" && ok "SKILL.md explains XIRP-SESSION-ID inside a herdr pane" || bad "SKILL.md explains XIRP-SESSION-ID inside a herdr pane"
fi

# ---------------------------------------------------------------- handoff-cleanup
if run_section cleanup; then
  printf 'handoff-cleanup\n'
  source "$KV"
  CLEAN="$ROOT/scripts/handoff/handoff-cleanup"
  clean_in() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" "$CLEAN" "$@" </dev/null); }
  deleted() { cat "$FAKE_XIRP_DIR/deleted" 2>/dev/null; }
  # A full new-mode loop: implementer A, review worktree B, finish worktree F, all from the main worktree P.
  P="$tmp/clean-p"; new_project "$P"; use_project "$P"; fresh_state c1
  awk '/^  worktree: shared$/{print "  worktree: new"; next} {print}' "$P/.agent-handoff/roles.yaml" > "$P/r.tmp" && mv "$P/r.tmp" "$P/.agent-handoff/roles.yaml"
  start_in "$P" add-export >/dev/null 2>&1
  A="$P-add-export"; B="$A-review"; F="$A-finish"
  pcommon="$(git -C "$P" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$pcommon/info"; printf '/rv/\n' >> "$pcommon/info/exclude"
  commit_in "$A" impl; hw "$A" --role implement --status done --head HEAD; route_in "$A" >/dev/null 2>&1
  mkdir -p "$B/rv"; printf 'review\n' > "$B/rv/r01.md"
  hw "$B" --role review --status done --verdict pass --head HEAD --report rv/r01.md
  finish_in "$A" add-export >/dev/null 2>&1
  if [[ ! -d "$B" || ! -d "$F" ]]; then bad "cleanup fixture has review and finish worktrees"; fi
  # A Work Item in the implementer worktree, ignored like the project's /work-items/WI-*/ rule.
  printf '/work-items/WI-*/\n' >> "$pcommon/info/exclude"
  mkdir -p "$A/work-items/WI-20261119-x/agents"; printf 'drill\n' > "$A/work-items/WI-20261119-x/agents/drill.md"

  out="$(clean_in "$A" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -z "$(deleted)" && -d "$A" && -d "$B" && -d "$F" ]] && grep -q 'review' <<<"$out" \
    && ok "an unfinished loop is refused and the newest record named" || { bad "an unfinished loop is refused and the newest record named"; printf '       %s\n' "$out"; }

  hw "$F" --role finish --status done --head HEAD
  printf 'x\n' > "$B/stray.txt"
  out="$(clean_in "$P" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -z "$(deleted)" && -d "$A" && -d "$B" && -d "$F" ]] && grep -q "$B" <<<"$out" \
    && ok "a worktree with uncommitted changes stops cleanup and is named" || { bad "a worktree with uncommitted changes stops cleanup and is named"; printf '       %s\n' "$out"; }
  rm "$B/stray.txt"

  out="$(clean_in "$P" add-export 2>&1)"; rc=$?
  if [[ "$rc" == 0 && -z "$(deleted)" && -d "$A" && -d "$B" && -d "$F" ]] && grep -q 'sess-1' <<<"$out" && grep -q 'sess-2' <<<"$out" && grep -q 'sess-3' <<<"$out" \
    && grep -q "$A" <<<"$out" && grep -q "$B" <<<"$out" && grep -q "$F" <<<"$out" && grep -q -- '--yes' <<<"$out"; then
    ok "without --yes it lists the sessions and worktrees and changes nothing"
  else
    bad "without --yes it lists the sessions and worktrees and changes nothing"; printf '       %s\n' "$out"
  fi
  grep -q "work-items/WI-20261119-x" <<<"$out" && [[ -f "$A/work-items/WI-20261119-x/agents/drill.md" ]] \
    && ok "the preview names the Work Items it will archive" || { bad "the preview names the Work Items it will archive"; printf '       %s\n' "$out"; }

  out="$(clean_in "$P" add-export --yes 2>&1)"; rc=$?
  arc="$P/.agent-handoff/archive/add-export"
  if [[ "$rc" == 0 && -f "$arc/$(basename "$A")/01-implement.yaml" && -f "$arc/$(basename "$B")/02-review.yaml" && -f "$arc/$(basename "$B")/rv/r01.md" \
    && -n "$(ls "$arc/$(basename "$F")"/*-finish.yaml 2>/dev/null)" ]]; then
    ok "records and review reports are archived in the main worktree"
  else
    bad "records and review reports are archived in the main worktree"; printf '       %s\n' "$out"
  fi
  [[ -f "$arc/$(basename "$A")/work-items/WI-20261119-x/agents/drill.md" && ! -e "$A" ]] \
    && ok "a Work Item in a removed worktree is archived with its files" || { bad "a Work Item in a removed worktree is archived with its files"; printf '       %s\n' "$out"; }
  [[ "$(deleted | sort | tr '\n' ' ')" == "sess-1 sess-2 sess-3 " ]] && ok "each loop session is deleted once" || bad "each loop session is deleted once ($(deleted | tr '\n' ' '))"
  if [[ ! -e "$A" && ! -e "$B" && ! -e "$F" && "$(git -C "$P" worktree list | wc -l | tr -d ' ')" == 1 ]] && git -C "$P" show-ref --verify --quiet refs/heads/feature/add-export \
    && ! grep -q -- '--force' "$FAKE_XIRP_DIR/calls" 2>/dev/null; then
    ok "loop worktrees are removed and the feature branch is kept"
  else
    bad "loop worktrees are removed and the feature branch is kept"; git -C "$P" worktree list | sed 's/^/       /'
  fi
  [[ "$(git -C "$P" status --short | wc -l | tr -d ' ')" == 0 ]] && ok "the archive stays out of Git" || bad "the archive stays out of Git"

  # Implementer in the main worktree: cleanup keeps it.
  H="$tmp/clean-here"; new_project "$H"; use_project "$H"; fresh_state c2; git -C "$H" switch -q feature/add-export
  start_in "$H" add-export --worktree here >/dev/null 2>&1
  printf 'r\n' > "$H/.agent-handoff/r.md"
  hw "$H" --role implement --status done --head HEAD
  hw "$H" --role review --status done --verdict pass --head HEAD --report .agent-handoff/r.md
  hw "$H" --role finish --status done --head HEAD
  awk '/^reviewer:/{r=1} r&&/^  session:/{print "  session: rev-2"; r=0; next} {print}' "$H/.agent-handoff/add-export/loop.yaml" > "$H/l.tmp" && mv "$H/l.tmp" "$H/.agent-handoff/add-export/loop.yaml"
  hcommon="$(git -C "$H" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$hcommon/info"; printf '/work-items/WI-*/\n' >> "$hcommon/info/exclude"
  mkdir -p "$H/work-items/WI-20261119-x"; printf 'wi\n' > "$H/work-items/WI-20261119-x/README.md"
  out="$(clean_in "$H" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$H/.git" && "$(deleted | sort | tr '\n' ' ')" == "rev-2 sess-1 " && -f "$H/.agent-handoff/archive/add-export/$(basename "$H")/03-finish.yaml" ]] \
    && ok "an implementer in the main worktree keeps the main worktree" || { bad "an implementer in the main worktree keeps the main worktree"; printf '       %s\n' "$out"; }
  [[ -f "$H/work-items/WI-20261119-x/README.md" ]] \
    && ok "a Work Item in the kept main worktree stays in place" || bad "a Work Item in the kept main worktree stays in place"
  # Abandoned loop: no finish record; --abandon cleans it with the same safety checks.
  Q="$tmp/clean-abandon"; new_project "$Q"; use_project "$Q"; fresh_state c3
  start_in "$Q" add-export >/dev/null 2>&1; QA="$Q-add-export"
  commit_in "$QA" impl; hw "$QA" --role implement --status done --head HEAD
  out="$(clean_in "$Q" add-export --abandon 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$QA" && -z "$(deleted)" ]] && grep -qi 'abandon' <<<"$out" \
    && ok "--abandon without --yes lists the plan for an unfinished loop and changes nothing" || { bad "--abandon without --yes lists the plan for an unfinished loop and changes nothing"; printf '       %s\n' "$out"; }
  printf 'x\n' > "$QA/stray.txt"
  out="$(clean_in "$Q" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$QA" && -z "$(deleted)" ]] && ok "--abandon still refuses a worktree with uncommitted changes" || { bad "--abandon still refuses a worktree with uncommitted changes"; printf '       %s\n' "$out"; }
  rm "$QA/stray.txt"
  out="$(clean_in "$Q" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -e "$QA" && "$(deleted)" == sess-1 && -f "$Q/.agent-handoff/archive/add-export/$(basename "$QA")/01-implement.yaml" ]] \
    && git -C "$Q" show-ref --verify --quiet refs/heads/feature/add-export \
    && ok "--abandon --yes archives, deletes the sessions and worktrees, and keeps the branch" || { bad "--abandon --yes archives, deletes the sessions and worktrees, and keeps the branch"; printf '       %s\n' "$out"; }
  [[ -x "$ROOT/scripts/handoff/handoff-cleanup" ]] && grep -q 'handoff-cleanup' "$ROOT/scripts/handoff/install.sh" && grep -q 'handoff-cleanup' "$ROOT/scripts/handoff/README.md" \
    && ok "handoff-cleanup is installed and documented" || bad "handoff-cleanup is installed and documented"
fi

# ---------------------------------------------------------------- Pi roles
if run_section pi; then
  printf 'Pi roles\n'
  source "$KV"
  LIB="$ROOT/scripts/handoff/lib/handoff.sh"
  TRUST="$ROOT/scripts/handoff/handoff-pi-trust"
  AUTH="$SKILL/scripts/handoff-author"
  # Fake Pi CLI: models from $FAKE_PI_DIR/models ("provider model thinking"), credentials from auth-<provider>.json.
  cat > "$FAKES/pi" <<'SH'
#!/usr/bin/env bash
D="${FAKE_PI_DIR:?}"; printf '%s\n' "$*" >> "$D/calls"
[[ "$1" == --version ]] && { echo "0.80.0"; exit 0; }
if [[ "$1" == --list-models ]]; then
  printf 'provider  model  context  max-out  thinking  images\n'
  awk -v q="$2" 'index($2, q) {printf "%s  %s  200K  64K  %s  yes\n", $1, $2, $3}' "$D/models"; exit 0
fi
if [[ "$1 $2" == "auth check" ]]; then
  if [[ -f "$D/auth-$4.json" ]]; then cat "$D/auth-$4.json"; cat "$D/auth-tail" 2>/dev/null; exit "$(cat "$D/auth-rc" 2>/dev/null || echo 0)"; fi
  printf '{"status":"not_ready","provider":"%s","reason":"provider_not_found"}\n' "$4"; exit 1
fi
exit 2
SH
  chmod +x "$FAKES/pi"
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
    [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -qF -- "$2" <<<"$out" && ok "$1" || { bad "$1"; printf '       %s\n' "$out"; }
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
  [[ "$rc" == 0 ]] && ok "a model listed under two providers is accepted for the declared one" || bad "a model listed under two providers is accepted for the declared one ($out)"
  out="$(v implement openai-codex gpt-api-only high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'not listed' <<<"$out" && grep -q openai-codex <<<"$out" && ok "a model listed only under another provider is refused" || bad "a model listed only under another provider is refused ($out)"
  out="$(v implement anthropic opus high api)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'not listed' <<<"$out" && ok "an alias is not a model ID" || bad "an alias is not a model ID ($out)"
  out="$(v implement openai-codex plain-1 high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'thinking' <<<"$out" && ok "a model without thinking is refused unless effort is off" || bad "a model without thinking is refused unless effort is off ($out)"
  out="$(v implement openai-codex plain-1 off subscription)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]] && ok "effort off accepts a model without thinking" || bad "effort off accepts a model without thinking ($out)"
  out="$(v review openai-codex gpt-6.2-sol high api)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q review <<<"$out" && grep -q "'api'" <<<"$out" && grep -q subscription <<<"$out" \
    && ok "oauth with billing api is refused naming the role, the declared and the actual billing" || bad "oauth with billing api is refused naming the role, the declared and the actual billing ($out)"
  out="$(v review openai gpt-6.2-sol high api)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]] && ok "api_key with billing api is accepted" || bad "api_key with billing api is accepted ($out)"
  out="$(v review openai gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q "'subscription'" <<<"$out" && ok "api_key with billing subscription is refused" || bad "api_key with billing subscription is refused ($out)"
  for st in not_ready invalid; do
    pi_auth openai-codex "$st" oauth; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
    [[ "$rc" != 0 ]] && grep -q "$st" <<<"$out" && ok "a $st credential is refused" || bad "a $st credential is refused ($out)"
  done
  pi_auth openai-codex ready aws-sso; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'aws-sso' <<<"$out" && ok "an unknown credential type is a mismatch" || bad "an unknown credential type is a mismatch ($out)"
  pi_auth openai-codex ready oauth
  nopi="$tmp/nopi-bin"; mkdir -p "$nopi"; ln -sf "$(command -v jq)" "$nopi/jq"
  out="$( (source "$LIB"; PATH="$nopi:/usr/bin:/bin" ho_pi_verify implement openai-codex gpt-6.2-sol high subscription 2>&1) )"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && grep -q 'pi' <<<"$out" && ok "without the pi command every Pi role is refused" || bad "without the pi command every Pi role is refused ($out)"
  pi_auth anthropic ready oauth
  out="$(v implement anthropic claude-opus-4-7 high subscription warn)"; rc=$?; all+="$out"
  [[ "$rc" == 0 ]] && grep -q 'extra usage' <<<"$out" && ok "a matching Anthropic subscription is accepted with the extra usage warning" || bad "a matching Anthropic subscription is accepted with the extra usage warning ($out)"
  pi_auth anthropic ready api_key
  out="$(v implement anthropic claude-opus-4-7 high api warn)$(v implement openai-codex gpt-6.2-sol high subscription warn)"; all+="$out"
  ! grep -q 'extra usage' <<<"$out" && ok "Anthropic API keys and other subscriptions get no warning" || bad "Anthropic API keys and other subscriptions get no warning ($out)"
  out="$(v implement anthropic claude-opus-4-7 high subscription warn)"; rc=$?; all+="$out"
  [[ "$rc" != 0 ]] && ! grep -q 'extra usage' <<<"$out" && ok "a mismatched Anthropic subscription is refused without the warning" || bad "a mismatched Anthropic subscription is refused without the warning ($out)"
  printf '9\n' > "$FAKE_PI_DIR/auth-rc"; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"; rm -f "$FAKE_PI_DIR/auth-rc"
  [[ "$rc" != 0 ]] && grep -q 'credential check' <<<"$out" && ok "a failing credential check is refused even when it prints ready (codex-pi-handoff-r03/F-04)" || bad "a failing credential check is refused even when it prints ready (codex-pi-handoff-r03/F-04) ($out)"
  printf '{"status":' > "$FAKE_PI_DIR/auth-tail"; out="$(v implement openai-codex gpt-6.2-sol high subscription)"; rc=$?; all+="$out"; rm -f "$FAKE_PI_DIR/auth-tail"
  [[ "$rc" != 0 ]] && grep -q 'unreadable' <<<"$out" && ok "a credential answer that is not one complete JSON object is refused (codex-pi-handoff-r04/F-02)" || bad "a credential answer that is not one complete JSON object is refused (codex-pi-handoff-r04/F-02) ($out)"
  ! grep -q 'SECRET' <<<"$all" && ok "verification output never contains credential values" || bad "verification output never contains credential values"

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
  [[ "$(trc "$th" "$T-ok")$(trc "$th" "$T-ok/sub")" == 00 ]] && ok "a listed handoff worktree of a trusted repository is trusted, from any subdirectory" || bad "a listed handoff worktree of a trusted repository is trusted, from any subdirectory"
  [[ "$(trc "$th" "$T")" != 0 ]] && ok "the main worktree is left to Pi" || bad "the main worktree is left to Pi"
  [[ "$(trc "$th" "$T-none")" != 0 ]] && ok "a worktree without loop.yaml is left to Pi" || bad "a worktree without loop.yaml is left to Pi"
  [[ "$(trc "$th" "$T-tracked")" != 0 ]] && ok "a tracked loop.yaml does not grant trust" || bad "a tracked loop.yaml does not grant trust"
  [[ "$(trc "$th" "$T-other")" != 0 ]] && ok "a loop.yaml that does not list this worktree does not grant trust" || bad "a loop.yaml that does not list this worktree does not grant trust"
  pi_home none; [[ "$(trc "$PI_HOME" "$T-ok")" != 0 ]] && ok "an untrusted repository's worktree is left to Pi" || bad "an untrusted repository's worktree is left to Pi"
  pi_home parent "$(dirname "$T")"; [[ "$(trc "$PI_HOME" "$T-ok")" == 0 ]] && ok "a trusted parent of the main worktree counts" || bad "a trusted parent of the main worktree counts"
  printf '{"%s": true, "%s": false}\n' "$(dirname "$T")" "$T" > "$PI_HOME/.pi/agent/trust.json"
  [[ "$(trc "$PI_HOME" "$T-ok")" != 0 ]] && ok "the nearest saved decision wins" || bad "the nearest saved decision wins"
  [[ "$(cat "$th/.pi/agent/trust.json")" == "$tbefore" ]] && ok "the trust check never edits trust.json" || bad "the trust check never edits trust.json"

  # 3.1 ho_pi_settings
  S="$tmp/pi-set"; new_repo "$S"; SW="$S-wt"; git -C "$S" worktree add -q --detach "$SW"
  pset() { (source "$LIB"; ho_pi_settings "$@" 2>&1); }
  ex="$(git -C "$S" rev-parse --path-format=absolute --git-path info/exclude)"
  out="$(pset "$SW" openai-codex gpt-6.2-sol high)"; rc=$?
  [[ "$rc" == 0 && "$(jq -r '[.defaultProvider, .defaultModel, .defaultThinkingLevel] | join(" ")' "$SW/.pi/settings.json" 2>/dev/null)" == "openai-codex gpt-6.2-sol high" ]] \
    && ok "the settings file names the provider, model and thinking level" || bad "the settings file names the provider, model and thinking level ($out)"
  [[ -z "$(git -C "$SW" status --porcelain)" && -z "$(git -C "$SW" ls-files .pi)" ]] && ok "the settings file keeps the worktree clean and untracked" || bad "the settings file keeps the worktree clean and untracked"
  pset "$SW" openai-codex gpt-6.2-sol high >/dev/null; rc=$?
  [[ "$rc" == 0 && "$(grep -cxF '/.pi/settings.json' "$ex")" == 1 ]] && ok "identical settings are reused and the exclude rule is added once" || bad "identical settings are reused and the exclude rule is added once"
  before="$(cat "$SW/.pi/settings.json")"; out="$(pset "$SW" openai gpt-6.2-sol high)"; rc=$?
  [[ "$rc" != 0 && "$(cat "$SW/.pi/settings.json")" == "$before" ]] && grep -q 'settings.json' <<<"$out" && ok "different settings are refused and left unchanged" || bad "different settings are refused and left unchanged ($out)"
  S2="$tmp/pi-set-tracked"; new_repo "$S2"; mkdir -p "$S2/.pi"; printf '{"defaultModel":"x"}\n' > "$S2/.pi/settings.json"; git -C "$S2" add .pi; git -C "$S2" commit -qm pi
  out="$(pset "$S2" openai-codex gpt-6.2-sol high)"; rc=$?
  [[ "$rc" != 0 && "$(cat "$S2/.pi/settings.json")" == '{"defaultModel":"x"}' ]] && grep -q 'tracked' <<<"$out" && ok "a tracked settings file is refused and left unchanged" || bad "a tracked settings file is refused and left unchanged ($out)"

  # 3.2 handoff-start with Pi roles
  pi_project "$CX_IMPL" "$CX_REV" "$(role_block finish pi gpt-6.2-sol high worktree=new provider=openai-codex billing=api)"
  out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && ! git -C "$PD" worktree list | grep -q add-export && grep -q finish <<<"$out" \
    && ok "a finish role whose billing does not match stops before any worktree or session" || { bad "a finish role whose billing does not match stops before any worktree or session"; printf '       %s\n' "$out"; }
  refuse_case "two Pi roles in the implementer worktree are refused, naming both" "implement and review" "$PI_IMPL" "$PI_REV_SHARED" "$CX_FIN"
  grep -q 'worktree: new' <<<"$out" && ok "the refusal tells the user to give the Pi role worktree: new" || bad "the refusal tells the user to give the Pi role worktree: new ($out)"
  pi_project "$PI_IMPL" "$PI_REV_NEW" "$CX_FIN"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && ok "a second Pi role with worktree: new starts" || { bad "a second Pi role with worktree: new starts"; printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; rm "$PI_HOME/.pi/agent/extensions/wk-handoff.ts"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -q 'install.sh' <<<"$out" && ok "a Pi role without the installed trigger is refused" || { bad "a Pi role without the installed trigger is refused"; printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; printf '{}\n' > "$PI_HOME/.pi/agent/trust.json"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -q '/trust' <<<"$out" && ok "a Pi role in an untrusted repository is refused with the /trust step" || { bad "a Pi role in an untrusted repository is refused with the /trust step"; printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  pl="$PW/.agent-handoff/add-export/loop.yaml"
  if [[ "$rc" == 0 && "$(created)" == 1 ]] && jq -e '.agent.agentName=="pi" and .agent.options=={model:"gpt-6.2-sol", provider:"openai-codex", thinking:"high"}' "$FAKE_XIRP_DIR/create-1.json" >/dev/null; then
    ok "a Pi implementer is opened through Xirp with model, provider and thinking"
  else
    bad "a Pi implementer is opened through Xirp with model, provider and thinking"; printf '       %s\n' "$out"
  fi
  [[ "$(jq -c . "$PW/.pi/settings.json" 2>/dev/null)" == '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}' && -z "$(git -C "$PW" status --porcelain)" ]] \
    && ok "the implementer worktree gets the Pi settings and stays clean" || bad "the implementer worktree gets the Pi settings and stays clean"
  [[ "$(kv_get "$pl" implement_template.harness)" == pi && "$(kv_get "$pl" implement_template.provider)" == openai-codex && "$(kv_get "$pl" implement_template.model)" == gpt-6.2-sol \
    && "$(kv_get "$pl" implement_template.effort)" == high && "$(kv_get "$pl" implement_template.billing)" == subscription ]] \
    && ok "loop.yaml records the implement template's harness, provider, model, effort and billing" || bad "loop.yaml records the implement template's harness, provider, model, effort and billing"
  jq -r .goal "$FAKE_XIRP_DIR/create-1.json" | grep -qF 'handoff-author --tool Pi --model gpt-6.2-sol' \
    && ok "a Pi role's prompt asks for the Author block with --tool Pi" || bad "a Pi role's prompt asks for the Author block with --tool Pi"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export; mkdir -p "$PD/.pi"; printf '{"defaultModel":"x"}\n' > "$PD/.pi/settings.json"
  git -C "$PD" add .pi; git -C "$PD" commit -qm pi; git -C "$PD" switch -q main
  out="$(pstart "$PD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && grep -q 'settings.json' <<<"$out" && ok "a branch that tracks .pi/settings.json is refused before a worktree is created" || { bad "a branch that tracks .pi/settings.json is refused before a worktree is created"; printf '       %s\n' "$out"; }
  pi_auth anthropic ready oauth
  pi_project "$(role_block implement pi claude-opus-4-7 high provider=anthropic billing=subscription)" "$CX_REV" "$CX_FIN"
  err="$(pstart "$PD" add-export 2>&1 >/dev/null)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q 'extra usage' <<<"$err" && ok "a matching Anthropic subscription starts with the warning on stderr" || bad "a matching Anthropic subscription starts with the warning on stderr ($err)"
  pi_auth anthropic ready api_key

  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; printf '9\n' > "$FAKE_PI_DIR/auth-rc"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?; rm -f "$FAKE_PI_DIR/auth-rc"
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && ok "handoff-start opens nothing when the credential check fails (codex-pi-handoff-r03/F-04)" || { bad "handoff-start opens nothing when the credential check fails (codex-pi-handoff-r03/F-04)"; printf '       %s\n' "$out"; }

  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; printf '{"status":' > "$FAKE_PI_DIR/auth-tail"; out="$(pstart "$PD" add-export 2>&1)"; rc=$?; rm -f "$FAKE_PI_DIR/auth-tail"
  [[ "$rc" != 0 && "$(created)" == 0 && ! -d "$PW" ]] && ok "handoff-start opens nothing when the credential answer cannot be parsed (codex-pi-handoff-r04/F-02)" || { bad "handoff-start opens nothing when the credential answer cannot be parsed (codex-pi-handoff-r04/F-02)"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export; pstart "$PD" add-export --worktree here >/dev/null 2>&1
  lb="$(cat "$PD/.agent-handoff/add-export/loop.yaml")"; exr="$(git -C "$PD" rev-parse --path-format=absolute --git-path info/exclude)"; exb="$(cat "$exr" 2>/dev/null)"
  out="$(pstart "$PD" add-export --worktree here --impl pi:openai-codex/gpt-6.2-sol:high:subscription 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 1 && ! -e "$PD/.pi/settings.json" && "$(cat "$PD/.agent-handoff/add-export/loop.yaml")" == "$lb" && "$(cat "$exr" 2>/dev/null)" == "$exb" ]] && grep -q 'loop already exists' <<<"$out" \
    && ok "a refused second start writes no Pi settings or exclude rule (codex-pi-handoff-r04/F-01)" || { bad "a refused second start writes no Pi settings or exclude rule (codex-pi-handoff-r04/F-01)"; printf '       %s\n' "$out"; }

  # 3.3 overrides
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --review pi:openai-codex/gpt-6.2-sol:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -qF 'pi:<provider>/<model>:<effort>:<billing>' <<<"$out" && ok "a Pi override without billing shows the expected form" || bad "a Pi override without billing shows the expected form ($out)"
  before="$(cat "$PD/.agent-handoff/roles.yaml")"; out="$(pstart "$PD" add-export --review pi:openai-codex/gpt-6.2-sol:high:subscription 2>&1)"; rc=$?
  pl="$PW/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$pl" review_template.harness)" == pi && "$(kv_get "$pl" review_template.provider)" == openai-codex && "$(kv_get "$pl" review_template.model)" == gpt-6.2-sol \
    && "$(kv_get "$pl" review_template.effort)" == high && "$(kv_get "$pl" review_template.billing)" == subscription && "$(cat "$PD/.agent-handoff/roles.yaml")" == "$before" ]] \
    && ok "a Pi override is recorded in loop.yaml and roles.yaml is unchanged" || { bad "a Pi override is recorded in loop.yaml and roles.yaml is unchanged"; printf '       %s\n' "$out"; }
  [[ "$(kv_get "$pl" review_template.name)" == 'pi - review - {change}' && "$(kv_get "$pl" review_template.prompt)" == 'do {change} {author}' ]] \
    && ok "a Pi override renames the session and keeps a prompt that starts with no skill call" \
    || bad "a Pi override renames the session and keeps a prompt that starts with no skill call ($(kv_get "$pl" review_template.name))"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --impl codex:gpt-x:low 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && jq -e '.agent.agentName=="codex" and (.agent.options|has("provider")|not)' "$FAKE_XIRP_DIR/create-1.json" >/dev/null && [[ ! -e "$PW/.pi/settings.json" ]] \
    && ok "a Codex override replaces a Pi template without its provider and billing" || { bad "a Codex override replaces a Pi template without its provider and billing"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --impl pi:openai-codex/gpt-6.2-sol:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q implement <<<"$out" && ok "a Pi override is verified like a template" || bad "a Pi override is verified like a template ($out)"

  # Environment checks: a Pi role's model is verified.
  pi_project "$CX_IMPL" "$(role_block review pi nope-1 high worktree=new provider=openai-codex billing=subscription)" "$CX_FIN"
  out="$(HOME="$PI_HOME" pf "$PD" "$PD/.agent-handoff/roles.yaml" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep '^fail role review' <<<"$out" | grep -q 'nope-1' && grep '^fail role review' <<<"$out" | grep -q 'openai-codex' \
    && ok "a Pi model its provider does not list fails the role check, naming role, provider and model" || { bad "a Pi model its provider does not list fails the role check, naming role, provider and model"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$PI_REV_NEW" "$CX_FIN"
  out="$(HOME="$PI_HOME" pf "$PD" "$PD/.agent-handoff/roles.yaml" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok role review: .*openai-codex/gpt-6.2-sol' <<<"$out" && grep -q '^ok harness .*pi 0.80.0' <<<"$out" \
    && ok "a ready Pi role passes with its verified model and Pi version" || { bad "a ready Pi role passes with its verified model and Pi version"; printf '       %s\n' "$out"; }
  # 3.4 roles.example.yaml Pi example
  exf="$tmp/pi-example.yaml"
  sed -n '/^# --- Pi role example ---$/,/^# --- end of Pi role example ---$/p' "$SKILL/roles.example.yaml" | grep -E '^# ?(review:|  )' | sed -E 's/^# ?//' > "$exf"
  if [[ -s "$exf" ]] && (source "$LIB"; ho_template_check "$exf" review) >/dev/null 2>&1 \
    && v review "$(kv_get "$exf" review.provider)" "$(kv_get "$exf" review.model)" "$(kv_get "$exf" review.effort)" "$(kv_get "$exf" review.billing)" >/dev/null 2>&1 \
    && [[ "$(kv_get "$exf" review.worktree)" == new ]] && grep -q '/skill:' "$exf"; then
    ok "the commented Pi example in roles.example.yaml passes the template check and verification"
  else
    bad "the commented Pi example in roles.example.yaml passes the template check and verification ($(cat "$exf" 2>/dev/null | head -3))"
  fi
  grep -q 'extra usage' "$SKILL/roles.example.yaml" && grep -q '/skill:<name>' "$SKILL/roles.example.yaml" && grep -q 'subscription' "$SKILL/roles.example.yaml" \
    && ok "the example explains billing, the Pi skill syntax and the Anthropic warning" || bad "the example explains billing, the Pi skill syntax and the Anthropic warning"

  # 4.1 handoff-write agent section
  PIENV=(PI_CODING_AGENT=true PI_PROVIDER=openai-codex PI_MODEL=gpt-6.2-sol PI_REASONING_LEVEL=high PI_SESSION_ID=pi-sess-1)
  W1="$tmp/pi-write"; new_repo "$W1"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  r="$W1/.agent-handoff/add-export/01-implement.yaml"
  [[ "$(kv_get "$r" agent.harness 2>/dev/null) $(kv_get "$r" agent.provider 2>/dev/null) $(kv_get "$r" agent.model 2>/dev/null) $(kv_get "$r" agent.effort 2>/dev/null) $(kv_get "$r" agent.billing 2>/dev/null) $(kv_get "$r" agent.session 2>/dev/null)" \
    == "pi openai-codex gpt-6.2-sol high subscription pi-sess-1" && "$(kv_get "$r" role)" == implement ]] \
    && ok "a record written in Pi carries the session's agent identity" || bad "a record written in Pi carries the session's agent identity ($(cat "$r" 2>/dev/null | tr '\n' ' '))"
  rm -f "$FAKE_PI_DIR/auth-openai-codex.json"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  [[ "$(kv_get "$W1/.agent-handoff/add-export/02-implement.yaml" agent.billing 2>/dev/null)" == unknown ]] \
    && ok "a failed credential check writes billing unknown and still writes the record" || bad "a failed credential check writes billing unknown and still writes the record"
  pi_auth openai-codex ready oauth
  printf '9\n' > "$FAKE_PI_DIR/auth-rc"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  rm -f "$FAKE_PI_DIR/auth-rc"; w4="$(ls "$W1/.agent-handoff/add-export"/[0-9][0-9]-implement.yaml | tail -1)"
  [[ "$(kv_get "$w4" agent.billing 2>/dev/null)" == unknown ]] && ok "a failing credential check writes billing unknown even when it prints ready (codex-pi-handoff-r03/F-04)" || bad "a failing credential check writes billing unknown even when it prints ready (codex-pi-handoff-r03/F-04)"
  printf '{"status":' > "$FAKE_PI_DIR/auth-tail"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  rm -f "$FAKE_PI_DIR/auth-tail"; w6="$(ls "$W1/.agent-handoff/add-export"/[0-9][0-9]-implement.yaml | tail -1)"
  [[ "$w6" != "$w4" && "$(kv_get "$w6" agent.billing 2>/dev/null)" == unknown ]] && ok "an unparsable credential answer writes billing unknown (codex-pi-handoff-r04/F-02)" || bad "an unparsable credential answer writes billing unknown (codex-pi-handoff-r04/F-02)"
  w4="$w6"
  (cd "$W1" && env -u PI_CODING_AGENT -u PI_PROVIDER -u PI_MODEL -u PI_REASONING_LEVEL -u PI_SESSION_ID PATH="$FAKES:$PATH" "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  w5="$(ls "$W1/.agent-handoff/add-export"/[0-9][0-9]-implement.yaml | tail -1)"
  [[ "$w5" != "$w4" ]] && ! grep -q '^agent:' "$w5" \
    && ok "a record written outside Pi has no agent section" || bad "a record written outside Pi has no agent section"
  (cd "$W1" && env PATH="$FAKES:$PATH" "${PIENV[@]}" "$WRITE" --change add-export --role implement --status done --head HEAD --provider openai) >/dev/null 2>&1 \
    && bad "handoff-write takes no agent arguments" || ok "handoff-write takes no agent arguments"

  # 4.2 handoff-author --tool Pi
  a1="$(env -i PATH="$PATH" PI_SESSION_ID=p-1 CHIRP_SESSION_ID=x-1 CLAUDE_CODE_SESSION_ID=wrong CODEX_SESSION_ID=wrong "$AUTH" --tool Pi --model gpt-6.2-sol 2>/dev/null)"
  [[ "$a1" == $'Co-Authored-By: Pi\nAI-Assisted-By: gpt-6.2-sol\nSESSION-ID: p-1\nXIRP-SESSION-ID: x-1' ]] && ok "handoff-author reads the Pi session ID" || bad "handoff-author reads the Pi session ID ($a1)"
  a2="$(env -i PATH="$PATH" "$AUTH" --tool Pi --model gpt-6.2-sol 2>/dev/null)"
  [[ "$a2" == $'Co-Authored-By: Pi\nAI-Assisted-By: gpt-6.2-sol\nSESSION-ID: null\nXIRP-SESSION-ID: null' ]] && ok "handoff-author writes null for missing Pi and Xirp IDs" || bad "handoff-author writes null for missing Pi and Xirp IDs ($a2)"

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
    if [[ "$(kinds)" == attention && "$(created)" == 0 && -z "$(msgs)" && "$first" == "$(ncount)" ]] && routed "$LD" 01-implement.yaml && jt --arg p "$2" '.detail|contains($p)'; then
      ok "$1"
    else
      bad "$1 ($(kinds); $(jl | tail -1))"
    fi
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
  [[ "$(created)" == 1 && "$(kinds)" == implement ]] && routed "$LD" 01-implement.yaml && ok "a matching Pi record is routed as usual" || bad "a matching Pi record is routed as usual ($(kinds))"
  [[ "$(jl | tail -1 | jq -r .agent)" == "Pi / openai-codex/gpt-6.2-sol / high / 訂閱" ]] && ok "the notice shows Pi's provider, model, effort and subscription from the record" || bad "the notice shows Pi's provider, model, effort and subscription from the record ($(jl | tail -1))"

  # 5.3 agent label for API, unknown and manual runs
  pi_loop; lset "$LD/.agent-handoff/add-export/loop.yaml" implement_template.provider openai; lset "$LD/.agent-handoff/add-export/loop.yaml" implement_template.billing api
  pi_rec "$LD" "${PIENV[@]}" PI_PROVIDER=openai; proute "$LD"
  [[ "$(jl | tail -1 | jq -r .agent)" == "Pi / openai/gpt-6.2-sol / high / API" ]] && ok "an API record is labelled API" || bad "an API record is labelled API ($(jl | tail -1))"
  pi_loop; rm -f "$FAKE_PI_DIR/auth-openai-codex.json"; pi_rec "$LD" "${PIENV[@]}"; proute "$LD"
  [[ "$(jl | tail -1 | jq -r .agent)" == "Pi / openai-codex/gpt-6.2-sol / high / unknown" ]] && ok "the mismatch notice shows unknown billing" || bad "the mismatch notice shows unknown billing ($(jl | tail -1))"
  pi_loop; pi_rec "$LD" "${PIENV[@]}"; touch "$FAKE_XIRP_DIR/msg-fail"
  lset "$LD/.agent-handoff/add-export/loop.yaml" reviewer.session sess-r; lset "$LD/.agent-handoff/add-export/loop.yaml" reviewer.worktree "$LD"
  proute "$LD"; rm -f "$FAKE_XIRP_DIR/msg-fail"
  (cd "$LD" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(kinds)" == "attention implement" && "$(jl | tail -1 | jq -r .agent)" == "Pi / openai-codex/gpt-6.2-sol / high / 訂閱" ]] \
    && ok "a manual foreground retry still shows the Pi agent from the record" || bad "a manual foreground retry still shows the Pi agent from the record ($(kinds); $(jl | tail -1))"
  PH="$tmp/pi-home-notify"; HOME="$PH" bash -c 'source "$1"; deploy_notify_files' _ "$ROOT/scripts/notify/lib/runtime.sh" >/dev/null 2>&1
  HOME="$PH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  pi_loop; pi_rec "$LD" "${PIENV[@]}"
  dry="$(cd "$LD" && env -u HANDOFF_NOTIFY HOME="$PH" TELEGRAM_DRY_RUN=true PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 CHIRP_SESSION_ID=chirp-1 "$PH/.config/wk-workflow/handoff/handoff-route" --foreground </dev/null 2>/dev/null)"
  grep -qF 'Agent Handoff (Pi / openai-codex/gpt-6.2-sol / high / 訂閱)' <<<"$dry" && ok "the notifier's dry run titles a Pi handoff with provider and billing" || bad "the notifier's dry run titles a Pi handoff with provider and billing ($dry)"

  # 5.2 the hook verifies a Pi reviewer before opening it
  pr_loop() { m=$((m + 1)); LD="$tmp/pi-r$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pir$m"; pi_state "r$m"; pi_home "r$m" "$LD"; pi_review_template "$LD"; hw "$LD" "${REC_ARGS[@]}"; }
  pr_loop; pi_auth openai-codex ready api_key; proute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 01-implement.yaml && grep -q 'reviewer:open-failed' "$LD/.agent-handoff/add-export/routing.log" && jt '.detail|test("billing")' \
    && ok "a Pi reviewer whose billing no longer matches is not opened, one notice names it, and the record waits" || bad "a Pi reviewer whose billing no longer matches is not opened, one notice names it, and the record waits ($(kinds); $(jl | tail -1))"
  pi_auth openai-codex ready oauth; proute "$LD"
  if [[ "$(created)" == 1 && "$(kinds)" == "attention implement" ]] && routed "$LD" 01-implement.yaml \
    && jq -e '.agent.agentName=="pi" and .agent.options.provider=="openai-codex"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(jq -r .defaultProvider "$LD/.pi/settings.json" 2>/dev/null)" == openai-codex && -z "$(git -C "$LD" status --porcelain)" ]]; then
    ok "after the fix the hook opens the Pi reviewer with its settings and sends no second attention"
  else
    bad "after the fix the hook opens the Pi reviewer with its settings and sends no second attention ($(kinds))"
  fi
  pr_loop; exf2="$(git -C "$LD" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$exf2")"; printf '/.pi/settings.json\n' >> "$exf2"
  mkdir -p "$LD/.pi"; printf '{"defaultModel":"mine"}\n' > "$LD/.pi/settings.json"; proute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention && "$(cat "$LD/.pi/settings.json")" == '{"defaultModel":"mine"}' ]] && ! routed "$LD" 01-implement.yaml \
    && ok "a review worktree with other Pi settings is not opened and the file is kept" || bad "a review worktree with other Pi settings is not opened and the file is kept ($(kinds))"
  m=$((m + 1)); LD="$tmp/pi-f$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pif$m"; pi_state "f$m"; pi_home "f$m" "$LD"; pi_finish_template "$LD"; rpt "$LD"
  hw "$LD" "${REC_ARGS[@]}"; hw "$LD" --role review --status done --verdict pass --head HEAD --report r.md; pi_auth openai-codex ready api_key
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q billing <<<"$out" && ok "handoff-finish refuses a Pi finish role that fails verification" || bad "handoff-finish refuses a Pi finish role that fails verification ($out)"

  # codex-pi-handoff-r03/F-02: manual finish and its retry use the same Pi record check
  pf_loop() { m=$((m + 1)); LD="$tmp/pi-pf$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pipf$m"; pi_state "pf$m"; pi_home "pf$m" "$LD"; pi_review_template "$LD"; rpt "$LD"; hw "$LD" "${REC_ARGS[@]}"; }
  pi_review_rec() { local d="$1"; shift; (cd "$d" && env PATH="$FAKES:$PATH" "$@" "$WRITE" --change add-export --role review --status done --verdict pass --head HEAD --report r.md) >/dev/null 2>&1; }
  pf_loop; pi_review_rec "$LD" "${PIENV[@]}" PI_MODEL=gpt-6.1-terra
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'gpt-6.1-terra' <<<"$out" && ok "handoff-finish refuses a passing Pi review that differs from its template" || bad "handoff-finish refuses a passing Pi review that differs from its template ($out)"
  pf_loop; pi_review_rec "$LD" "${PIENV[@]}"
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && ok "handoff-finish accepts a matching passing Pi review" || bad "handoff-finish accepts a matching passing Pi review ($out)"
  pf_loop; pi_review_rec "$LD" "${PIENV[@]}" PI_MODEL=gpt-6.1-terra; hw "$LD" --role finish --status blocked --head HEAD --note stopped
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && -z "$(msgs)" ]] && grep -q 'passing review' <<<"$out" && ok "a finish retry ignores a passing Pi review that differs from its template" || bad "a finish retry ignores a passing Pi review that differs from its template ($out)"

  # 7.2 drill: a new finish worktree's own loop.yaml must list it, or the Pi trigger cannot trust it
  pf_loop; pi_finish_template "$LD"; lset "$LD/.agent-handoff/add-export/loop.yaml" finish_template.worktree new; pi_review_rec "$LD" "${PIENV[@]}"
  HOME="$PI_HOME" finish_in "$LD" add-export >/dev/null 2>&1
  [[ "$(created)" == 1 && "$(kv_get "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] \
    && (HOME="$PI_HOME" bash "$TRUST" "${LD}-finish" >/dev/null 2>&1) \
    && ok "a new finish worktree's loop.yaml lists it, so the Pi trigger trusts it" || bad "a new finish worktree's loop.yaml lists it, so the Pi trigger trusts it"
  lset "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree ""; lset "$LD/.agent-handoff/add-export/loop.yaml" finish.session missing-f
  HOME="$PI_HOME" finish_in "$LD" add-export >/dev/null 2>&1
  [[ "$(created)" == 2 && "$(kv_get "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] \
    && ok "reopening finish in the prepared worktree restores its loop.yaml entry" || bad "reopening finish in the prepared worktree restores its loop.yaml entry"

  # codex-pi-handoff-r06/F-01: a failed loop.yaml copy into a new worktree opens nothing and is retried
  CPF="$tmp/cp-fail-bin"; mkdir -p "$CPF"
  printf '#!/usr/bin/env bash\nfor last; do :; done\nif [[ -e "$FAKE_XIRP_DIR/cp-fail" && "$last" == *"$CP_FAIL_MATCH"* ]]; then exit 1; fi\nexec /bin/cp "$@"\n' > "$CPF/cp"; chmod +x "$CPF/cp"
  croute() { (cd "$1" && HOME="$PI_HOME" PATH="$CPF:$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID=chirp-1 "$ROUTE" </dev/null); }
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new; lset "$lf" finish.trigger auto
  pi_review_rec "$LD" "${PIENV[@]}"; export CP_FAIL_MATCH="-finish/"; touch "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 02-review.yaml && grep -q 'finish:open-failed' "$LD/.agent-handoff/add-export/routing.log" \
    && ok "a failed loop.yaml copy into a new finish worktree opens no session and leaves the review unprocessed" || bad "a failed loop.yaml copy into a new finish worktree opens no session and leaves the review unprocessed ($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"; fl="${LD}-finish/.agent-handoff/add-export/loop.yaml"
  [[ "$(created)" == 1 && "$(kv_get "$fl" change 2>/dev/null)" == add-export && "$(kv_get "$fl" implementer.worktree 2>/dev/null)" == "$LD" \
    && "$(kv_get "$fl" finish_template.harness 2>/dev/null)" == pi && "$(kv_get "$fl" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] && routed "$LD" 02-review.yaml \
    && (HOME="$PI_HOME" bash "$TRUST" "${LD}-finish" >/dev/null 2>&1) \
    && ok "the retry completes the finish worktree's loop.yaml, opens one finish session and the trust check passes" || bad "the retry completes the finish worktree's loop.yaml, opens one finish session and the trust check passes ($(created))"
  m=$((m + 1)); LD="$tmp/pi-rc$m"; new_loop "$LD" new; use_project "$LD"; fresh_state "pirc$m"; pi_state "rc$m"; pi_home "rc$m" "$LD"; pi_review_template "$LD"; hw "$LD" "${REC_ARGS[@]}"
  export CP_FAIL_MATCH="-review/"; touch "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 01-implement.yaml \
    && ok "a failed loop.yaml copy into a new review worktree opens no reviewer and leaves the record unprocessed" || bad "a failed loop.yaml copy into a new review worktree opens no reviewer and leaves the record unprocessed ($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/cp-fail"; croute "$LD"
  [[ "$(created)" == 1 && "$(kv_get "${LD}-review/.agent-handoff/add-export/loop.yaml" reviewer.worktree 2>/dev/null)" == "${LD}-review" ]] && routed "$LD" 01-implement.yaml \
    && ok "the retry copies loop.yaml into the review worktree and opens the reviewer once" || bad "the retry copies loop.yaml into the review worktree and opens the reviewer once ($(created))"

  # codex-pi-handoff-r07/F-01: a failed write of the role worktree into the original loop.yaml opens nothing
  printf '#!/usr/bin/env bash\nfor last; do :; done\nif [[ -e "$FAKE_XIRP_DIR/mv-fail" && "$last" == "$MV_FAIL_TARGET" ]]; then exit 1; fi\nexec /bin/mv "$@"\n' > "$CPF/mv"; chmod +x "$CPF/mv"
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new; lset "$lf" finish.trigger auto
  pi_review_rec "$LD" "${PIENV[@]}"; export MV_FAIL_TARGET="$lf"; touch "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 02-review.yaml \
    && ok "a failed write of finish.worktree into loop.yaml opens no finish session and leaves the review unprocessed" || bad "a failed write of finish.worktree into loop.yaml opens no finish session and leaves the review unprocessed ($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 1 && "$(kv_get "$lf" finish.worktree)" == "${LD}-finish" && "$(kv_get "${LD}-finish/.agent-handoff/add-export/loop.yaml" finish.worktree 2>/dev/null)" == "${LD}-finish" ]] \
    && routed "$LD" 02-review.yaml && (HOME="$PI_HOME" bash "$TRUST" "${LD}-finish" >/dev/null 2>&1) \
    && ok "after the write succeeds the prepared finish worktree is reused, trusted and opened once" || bad "after the write succeeds the prepared finish worktree is reused, trusted and opened once ($(created))"
  m=$((m + 1)); LD="$tmp/pi-rw$m"; new_loop "$LD" new; use_project "$LD"; fresh_state "pirw$m"; pi_state "rw$m"; pi_home "rw$m" "$LD"; pi_review_template "$LD"; hw "$LD" "${REC_ARGS[@]}"
  export MV_FAIL_TARGET="$LD/.agent-handoff/add-export/loop.yaml"; touch "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 0 && "$(kinds)" == attention ]] && ! routed "$LD" 01-implement.yaml \
    && ok "a failed write of reviewer.worktree into loop.yaml opens no reviewer and leaves the record unprocessed" || bad "a failed write of reviewer.worktree into loop.yaml opens no reviewer and leaves the record unprocessed ($(created); $(kinds))"
  rm -f "$FAKE_XIRP_DIR/mv-fail"; croute "$LD"
  [[ "$(created)" == 1 && "$(kv_get "${LD}-review/.agent-handoff/add-export/loop.yaml" reviewer.worktree 2>/dev/null)" == "${LD}-review" ]] && routed "$LD" 01-implement.yaml \
    && (HOME="$PI_HOME" bash "$TRUST" "${LD}-review" >/dev/null 2>&1) \
    && ok "after the write succeeds the reviewer opens once in a trusted review worktree" || bad "after the write succeeds the reviewer opens once in a trusted review worktree ($(created))"
  # codex-pi-handoff-r08/F-01: a finish retry never takes over a worktree the loop did not prepare
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new
  pi_review_rec "$LD" "${PIENV[@]}"; git -C "$LD" checkout -q --detach HEAD; git -C "$LD" worktree add -q "${LD}-finish" feature/add-export
  out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -e "${LD}-finish/.pi/settings.json" && ! -e "${LD}-finish/.agent-handoff" && -z "$(kv_get "$lf" finish.worktree)" ]] \
    && ok "a hand-made worktree with the finish worktree's name is left alone and nothing opens" || bad "a hand-made worktree with the finish worktree's name is left alone and nothing opens ($out)"
  pf_loop; pi_finish_template "$LD"; lf="$LD/.agent-handoff/add-export/loop.yaml"; lset "$lf" finish_template.worktree new
  pi_review_rec "$LD" "${PIENV[@]}"; export CP_FAIL_MATCH="-finish/" MV_FAIL_TARGET="$lf"; touch "$FAKE_XIRP_DIR/cp-fail" "$FAKE_XIRP_DIR/mv-fail"
  (cd "$LD" && HOME="$PI_HOME" PATH="$CPF:$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 "$FINISH" add-export </dev/null) >/dev/null 2>&1
  rm -f "$FAKE_XIRP_DIR/cp-fail" "$FAKE_XIRP_DIR/mv-fail"; out="$(HOME="$PI_HOME" finish_in "$LD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'cannot reuse' <<<"$out" \
    && ok "a finish worktree with neither the loop's record nor its loop.yaml is not reused" || bad "a finish worktree with neither the loop's record nor its loop.yaml is not reused ($out)"

  # Opening a Pi role checks the trust rule itself, whatever produced the worktree.
  m=$((m + 1)); LD="$tmp/pi-tg$m"; new_loop "$LD"; use_project "$LD"; fresh_state "pitg$m"; pi_state "tg$m"; pi_home "tg$m" "$LD"; pi_review_template "$LD"
  lset "$LD/.agent-handoff/add-export/loop.yaml" reviewer.worktree "$tmp/pi-elsewhere"; git -C "$LD" worktree add -q --detach "$tmp/pi-elsewhere"
  out="$( (cd "$LD" && source "$LIB" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 ho_open_role "$LD/.agent-handoff/add-export" review_template "$tmp/pi-elsewhere" "$(git -C "$LD" rev-parse HEAD)" 1 "" 2>&1) )"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'trust' <<<"$out" && ok "a Pi role is not opened in a worktree the Pi trigger would not trust" || bad "a Pi role is not opened in a worktree the Pi trigger would not trust ($out)"

  # A Pi reviewer on herdr starts from its worktree settings and runs Pi on the template's provider and model.
  m=$((m + 1)); LD="$tmp/pi-h$m"; new_loop "$LD" new; use_project "$LD"; fresh_state "pih$m"; pi_state "h$m"; pi_home "h$m" "$LD"; pi_review_template "$LD"
  lset "$LD/.agent-handoff/add-export/loop.yaml" review_template.host herdr; hw "$LD" "${REC_ARGS[@]}"; proute "$LD"
  [[ "$(created)" == 0 && "$(jq -r .defaultModel "${LD}-review/.pi/settings.json" 2>/dev/null)" == gpt-6.2-sol ]] && routed "$LD" 01-implement.yaml \
    && herdr_calls | grep 'agent start' | grep -qE -- '--kind pi --pane w2:p1 -- --provider openai-codex --model gpt-6.2-sol --thinking high$' \
    && ok "a Pi reviewer on herdr gets its settings file and runs Pi on the template's provider, model and thinking" \
    || { bad "a Pi reviewer on herdr gets its settings file and runs Pi on the template's provider, model and thinking ($(kinds))"; herdr_calls | sed 's/^/       /'; }
  # 5.4 cleanup removes the settings the loop wrote in the main worktree
  pi_state cleanup
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  hout="$(pstart "$PD" add-export --worktree here 2>&1)"
  pclean() { (cd "$1" && HOME="$PI_HOME" PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" add-export --abandon --yes >/dev/null 2>&1); }
  pvout="$(cd "$PD" && HOME="$PI_HOME" PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" add-export --abandon 2>&1)"
  grep -qF "$PD/.pi/settings.json" <<<"$pvout" && [[ -f "$PD/.pi/settings.json" ]] \
    && ok "the cleanup preview names the Pi settings it will remove" || { bad "the cleanup preview names the Pi settings it will remove"; printf '       %s\n' "$pvout"; }
  [[ -f "$PD/.pi/settings.json" ]] && pclean "$PD" && [[ ! -e "$PD/.pi/settings.json" ]] && ok "cleanup removes the Pi settings the loop wrote in the main worktree" || bad "cleanup removes the Pi settings the loop wrote in the main worktree ($hout)"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  pstart "$PD" add-export --worktree here >/dev/null 2>&1; printf '{"defaultModel":"mine"}\n' > "$PD/.pi/settings.json"
  pclean "$PD"; [[ "$(cat "$PD/.pi/settings.json" 2>/dev/null)" == '{"defaultModel":"mine"}' ]] && ok "cleanup keeps Pi settings it did not write" || bad "cleanup keeps Pi settings it did not write"
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  ex4="$(git -C "$PD" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$ex4")"; printf '/.pi/settings.json\n' >> "$ex4"
  mkdir -p "$PD/.pi"; printf '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}\n' > "$PD/.pi/settings.json"; cp "$PD/.pi/settings.json" "$tmp/pi-own-settings"
  pstart "$PD" add-export --worktree here >/dev/null 2>&1; pclean "$PD"
  cmp -s "$PD/.pi/settings.json" "$tmp/pi-own-settings" && ok "cleanup keeps identical Pi settings that existed before the loop (codex-pi-handoff-r03/F-01)" || bad "cleanup keeps identical Pi settings that existed before the loop (codex-pi-handoff-r03/F-01)"
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  ex3="$(git -C "$PD" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$ex3")"; printf '/.pi/settings.json\n' >> "$ex3"
  mkdir -p "$PD/.pi"; printf '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}\n' > "$PD/.pi/settings.json"
  pstart "$PD" add-export --worktree here >/dev/null 2>&1; pclean "$PD"
  [[ -f "$PD/.pi/settings.json" ]] && ok "cleanup of a loop without Pi roles leaves .pi alone" || bad "cleanup of a loop without Pi roles leaves .pi alone"

  # 6.2 installer
  IH="$tmp/pi-install-home"; mkdir -p "$IH"
  iout="$(HOME="$IH" bash "$ROOT/scripts/handoff/install.sh" 2>&1)"; HOME="$IH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$(ls "$IH/.pi/agent/extensions" 2>/dev/null)" == wk-handoff.ts ]] && cmp -s "$ROOT/scripts/handoff/pi/wk-handoff.ts" "$IH/.pi/agent/extensions/wk-handoff.ts" \
    && [[ -x "$IH/.config/wk-workflow/handoff/handoff-pi-trust" ]] \
    && ok "the installer puts exactly one Pi trigger in Pi's extensions and installs the trust check" || bad "the installer puts exactly one Pi trigger in Pi's extensions and installs the trust check"
  grep -q '/reload' <<<"$iout" && grep -q '/trust' <<<"$iout" && ok "the installer tells the user about /reload and /trust" || bad "the installer tells the user about /reload and /trust"
  n_claude="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$IH/.claude/settings.json" 2>/dev/null)"
  n_codex="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$IH/.codex/hooks.json" 2>/dev/null)"
  [[ "$n_claude" == 1 && "$n_codex" == 1 ]] && ok "Claude Code and Codex keep one Stop hook each" || bad "Claude Code and Codex keep one Stop hook each ($n_claude/$n_codex)"
  ext="$ROOT/scripts/handoff/pi/wk-handoff.ts"
  grep -q '"agent_settled"' "$ext" && grep -q '"project_trust"' "$ext" && grep -q 'PI_SUBAGENT_PARENT_SESSION' "$ext" && ! grep -q '"tool_call"' "$ext" && ! grep -q 'remember' "$ext" \
    && ok "the Pi trigger handles agent_settled and project_trust only, skips subagents and saves no trust" || bad "the Pi trigger handles agent_settled and project_trust only, skips subagents and saves no trust"

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
    && "$(cat "$PD/.agent-handoff/roles.yaml")" == "$rbefore" ]] \
    && ok "handoff-role changes a review role that has not opened, and roles.yaml is unchanged" || { bad "handoff-role changes a review role that has not opened, and roles.yaml is unchanged"; printf '       %s\n' "$out"; }
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  jq -e '.agent.agentName=="pi" and .customName=="pi - review - add-export"' "$FAKE_XIRP_DIR/create-2.json" >/dev/null 2>&1 \
    && ok "the hook opens the reviewer from the changed role" || bad "the hook opens the reviewer from the changed role ($(cat "$FAKE_XIRP_DIR/create-2.json" 2>/dev/null | jq -c '{n: .customName, a: .agent.agentName}'))"
  s0="$(sum "$rl")"; out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q "$(kv_get "$rl" reviewer.session)" <<<"$out" && grep -qF -- '--replace' <<<"$out" \
    && ok "handoff-role refuses a role whose session is open and names it" || { bad "handoff-role refuses a role whose session is open and names it"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/not-a-model:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q 'not-a-model' <<<"$out" \
    && ok "handoff-role refuses a Pi role that fails verification and keeps loop.yaml" || { bad "handoff-role refuses a Pi role that fails verification and keeps loop.yaml"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -qF 'pi:<provider>/<model>:<effort>:<billing>' <<<"$out" \
    && ok "handoff-role refuses a malformed override and shows the form" || { bad "handoff-role refuses a malformed override and shows the form"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export finish claude:sonnet:high 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" finish_template.harness)" == claude && "$(kv_get "$rl" finish_template.name)" == 'claude - finish - {change}' ]] \
    && ok "handoff-role changes a finish role that has not opened" || { bad "handoff-role changes a finish role that has not opened"; printf '       %s\n' "$out"; }
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q 'one Pi role' <<<"$out" \
    && ok "handoff-role refuses a second Pi role in the implementer worktree" || { bad "handoff-role refuses a second Pi role in the implementer worktree"; printf '       %s\n' "$out"; }

  # handoff-role --replace and --worktree new (replace-open-handoff-roles)
  # open_reviewer [finish-block]: a Codex loop whose Codex reviewer (sess-2) received round 1.
  open_reviewer() {
    pi_project "$CX_IMPL" "$CX_REV" "${1:-$CX_FIN}"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
    commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  }
  rlog() { cat "$PW/.agent-handoff/add-export/routing.log" 2>/dev/null; }
  open_reviewer; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export implement claude:opus:high --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -q 'only review and finish' <<<"$out" \
    && ok "handoff-role refuses to change the implementer" || { bad "handoff-role refuses to change the implementer"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --worktree shared --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -qF -- 'only --worktree new' <<<"$out" \
    && ok "handoff-role refuses --worktree shared" || { bad "handoff-role refuses --worktree shared"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review pi:openai/not-a-model:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" && "$(created)" == 2 ]] && grep -q 'not-a-model' <<<"$out" \
    && ok "a replacement that fails its checks deletes nothing and keeps loop.yaml" || { bad "a replacement that fails its checks deletes nothing and keeps loop.yaml"; printf '       %s\n' "$out"; }
  touch "$FAKE_XIRP_DIR/delete-fail"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/delete-fail"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]] && grep -q 'sess-2' <<<"$out" \
    && ok "a replacement whose old session cannot be deleted keeps loop.yaml" || { bad "a replacement whose old session cannot be deleted keeps loop.yaml"; printf '       %s\n' "$out"; }
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
    && rlog | grep -q 'implement.yaml action=reviewer:opened:sess-3' \
    && ok "the README example replaces an open reviewer and hands the waiting round to the new Pi reviewer" \
    || { bad "the README example replaces an open reviewer and hands the waiting round to the new Pi reviewer ($rex)"; printf '       %s\n' "$out"; rlog | sed 's/^/       /'; }
  open_reviewer; n0="$(ncount)"; touch "$FAKE_XIRP_DIR/create-fail"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/create-fail"
  [[ "$rc" != 0 && "$(deleted)" == sess-2 && -z "$(kv_get "$rl" reviewer.session)" && "$(( $(ncount) - n0 ))" == 1 ]] \
    && ! routed "$PW" 01-implement.yaml && jt '.kind=="attention"' && grep -q 'handoff-route --foreground' <<<"$out" \
    && ok "a hand-off that fails after a replacement leaves the record unprocessed with one attention notice" \
    || { bad "a hand-off that fails after a replacement leaves the record unprocessed with one attention notice"; printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict changes-required --head HEAD --report r.md
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == sess-2 && "$(created)" == 2 && -z "$(kv_get "$rl" reviewer.session)" \
    && "$(kv_get "$rl" review_template.harness)" == pi && "$(kv_get "$rl" review_template.model)" == gpt-6.2-sol ]] \
    && ok "a reviewer replaced while the implementer works is deleted and nothing opens" || { bad "a reviewer replaced while the implementer works is deleted and nothing opens"; printf '       %s\n' "$out"; }
  # --worktree new lets a Pi reviewer sit next to a shared Pi finish role; alone it changes only the worktree.
  PI_FIN_SHARED="$(role_block finish pi gpt-6.2-sol high worktree=shared provider=openai-codex billing=subscription)"
  pi_project "$CX_IMPL" "$CX_REV" "$PI_FIN_SHARED"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" ]] && grep -q 'one Pi role' <<<"$out" \
    && ok "a Pi reviewer next to a shared Pi finish role is refused without --worktree new" || { bad "a Pi reviewer next to a shared Pi finish role is refused without --worktree new"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review --worktree new pi:openai/gpt-6.2-sol:medium:api 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" review_template.harness)" == pi && "$(kv_get "$rl" review_template.worktree)" == new ]] \
    && ok "with --worktree new the Pi reviewer passes the one-Pi-role check" || { bad "with --worktree new the Pi reviewer passes the one-Pi-role check"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export finish --worktree new 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" finish_template.worktree)" == new && "$(kv_get "$rl" finish_template.harness)" == pi \
    && "$(kv_get "$rl" finish_template.model)" == gpt-6.2-sol && "$(kv_get "$rl" finish_template.provider)" == openai-codex ]] \
    && ok "--worktree new alone changes only the role's worktree" || { bad "--worktree new alone changes only the role's worktree"; printf '       %s\n' "$out"; }

  # Round 2 (codex-role-review-r01)
  ROUTE_FG() { (cd "$1" && HOME="$PI_HOME" PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 CLAUDE_PROJECT_DIR="$1" "$ROUTE" --foreground </dev/null >/dev/null 2>&1); }
  open_reviewer; s0="$(sum "$rl")"; touch "$FAKE_XIRP_DIR/get-fail" "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-fail"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/get-fail" "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-fail"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]] && grep -q 'sess-2' <<<"$out" \
    && ok "a replacement whose old session Xirp neither deletes nor confirms gone keeps loop.yaml (codex-role-review-r01/F-01)" \
    || { bad "a replacement whose old session Xirp neither deletes nor confirms gone keeps loop.yaml (codex-role-review-r01/F-01)"; printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict changes-required --head HEAD --report r.md; touch "$FAKE_XIRP_DIR/get-fail"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?; rm -f "$FAKE_XIRP_DIR/get-fail"
  [[ "$rc" == 0 && "$(deleted)" == sess-2 && -z "$(kv_get "$rl" reviewer.session)" ]] \
    && ok "a failed Xirp lookup does not skip deleting the old session (codex-role-review-r01/F-01)" || { bad "a failed Xirp lookup does not skip deleting the old session (codex-role-review-r01/F-01)"; printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict changes-required --head HEAD --report r.md; lset "$rl" reviewer.session missing-9
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && -z "$(kv_get "$rl" reviewer.session)" && -z "$(deleted)" ]] \
    && ok "a replacement goes ahead when Xirp no longer lists the old session (codex-role-review-r01/F-01)" || { bad "a replacement goes ahead when Xirp no longer lists the old session (codex-role-review-r01/F-01)"; printf '       %s\n' "$out"; }
  open_reviewer; OTHER="$tmp/pi-elsewhere"; rm -rf "$OTHER"; new_repo "$OTHER"
  out="$(export CLAUDE_PROJECT_DIR="$OTHER"; prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] \
    && ok "the hand-off routes the record's own worktree when CLAUDE_PROJECT_DIR names another (codex-role-review-r01/F-03)" || { bad "the hand-off routes the record's own worktree when CLAUDE_PROJECT_DIR names another (codex-role-review-r01/F-03)"; printf '       %s\n' "$out"; }
  open_reviewer; commit_in "$PW" impl2; printf 'x\n' > "$PW/dirty.txt"; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1; rm -f "$PW/dirty.txt"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 2 && -z "$(kv_get "$rl" reviewer.session)" ]] && routed "$PW" 02-implement.yaml \
    && ok "a record that never reached the old reviewer is not handed to the new one (codex-role-review-r01/F-03)" || { bad "a record that never reached the old reviewer is not handed to the new one (codex-role-review-r01/F-03)"; printf '       %s\n' "$out"; }
  open_reviewer; git -C "$PW" worktree add -q --detach "$PW-review" HEAD; printf 'x\n' > "$PW-review/stray.txt"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  rm -f "$PW-review/stray.txt"; r1="$rc"; ROUTE_FG "$PW"
  [[ "$r1" != 0 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] && grep -q 'handoff-route --foreground' <<<"$out" \
    && ok "a hand-off stopped by an unclean review worktree is retried after the worktree is cleaned (codex-role-review-r01/F-03)" || { bad "a hand-off stopped by an unclean review worktree is retried after the worktree is cleaned (codex-role-review-r01/F-03)"; printf '       %s\n' "$out"; }
  open_reviewer; chmod 555 "$PW/.agent-handoff/add-export"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  chmod 755 "$PW/.agent-handoff/add-export"
  [[ "$rc" != 0 && "$(deleted)" == sess-2 && "$(created)" == 2 ]] && grep -qF -- '--replace' <<<"$out" \
    && ok "a loop.yaml write that fails after the deletion exits non-zero and names the rerun (codex-role-review-r01/F-04)" || { bad "a loop.yaml write that fails after the deletion exits non-zero and names the rerun (codex-role-review-r01/F-04)"; printf '       %s\n' "$out"; }
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] \
    && ok "rerunning the replacement after a failed write hands the round to the new reviewer (codex-role-review-r01/F-04)" || { bad "rerunning the replacement after a failed write hands the round to the new reviewer (codex-role-review-r01/F-04)"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=new)" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  chmod 555 "$PW-review/.agent-handoff/add-export"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  chmod 755 "$PW-review/.agent-handoff/add-export"
  [[ "$rc" != 0 && "$(created)" == 2 && "$(kv_get "$rl" reviewer.session)" == sess-2 ]] && grep -qF -- '--replace' <<<"$out" \
    && ok "a failed write to another loop.yaml copy keeps the old session recorded for a rerun (codex-role-review-r01/F-04)" || { bad "a failed write to another loop.yaml copy keeps the old session recorded for a rerun (codex-role-review-r01/F-04)"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$PI_REV_SHARED" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  out="$(prole "$PW" add-export review pi:openai-codex/gpt-6.2-sol:medium:subscription --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] && jq -e '.defaultThinkingLevel=="medium"' "$PW/.pi/settings.json" >/dev/null 2>&1 \
    && ok "a Pi reviewer replaced in the same worktree rewrites the settings the loop wrote (codex-role-review-r01/F-06)" || { bad "a Pi reviewer replaced in the same worktree rewrites the settings the loop wrote (codex-role-review-r01/F-06)"; printf '       %s\n' "$out"; }
  open_reviewer; px="$(git -C "$PW" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$px")"; printf '/.pi/settings.json\n' >> "$px"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -q 'settings.json' <<<"$out" \
    && ok "Pi settings the loop did not write refuse the replacement before the old session is deleted (codex-role-review-r01/F-06)" || { bad "Pi settings the loop did not write refuse the replacement before the old session is deleted (codex-role-review-r01/F-06)"; printf '       %s\n' "$out"; }
  open_reviewer; wrpt "$PW"; hw "$PW" --role review --status done --verdict pass --head HEAD --report r.md; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:high:api --replace 2>&1)"; rc=$?
  fout="$(HOME="$PI_HOME" finish_in "$PW" add-export 2>&1)"; frc=$?
  [[ "$rc" == 0 && "$frc" == 0 && "$(created)" == 3 && "$(kv_get "$rl" finish.session)" == sess-3 ]] \
    && ok "a Codex pass recorded before the reviewer became Pi still lets the loop finish (codex-role-review-r01/F-07)" || { bad "a Codex pass recorded before the reviewer became Pi still lets the loop finish (codex-role-review-r01/F-07)"; printf '       %s\n' "$out" "$fout"; }
  hw "$PW" --role finish --status blocked --head HEAD --note quota
  out="$(prole "$PW" add-export review pi:openai/gpt-api-only:high:api 2>&1)"; rc=$?
  fout="$(HOME="$PI_HOME" finish_in "$PW" add-export 2>&1)"; frc=$?
  [[ "$rc" == 0 && "$frc" == 0 ]] && msgs | grep -q '^sess-3' \
    && ok "a blocked finish is retried after a further reviewer change (codex-role-review-r01/F-07)" || { bad "a blocked finish is retried after a further reviewer change (codex-role-review-r01/F-07)"; printf '       %s\n' "$out" "$fout"; }

  # Round 3 (codex-role-review-r02)
  open_reviewer; s0="$(sum "$rl")"; touch "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-null"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-null"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]] \
    && ok "an unreadable Xirp session list does not prove the old session gone (codex-role-review-r02/F-01)" || { bad "an unreadable Xirp session list does not prove the old session gone (codex-role-review-r02/F-01)"; printf '       %s\n' "$out"; }
  open_reviewer
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*/.routed' prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  grep -vxF 01-implement.yaml "$PW/.agent-handoff/add-export/.routed" > "$tmp/routed.tmp"; cat "$tmp/routed.tmp" > "$PW/.agent-handoff/add-export/.routed"; ROUTE_FG "$PW"
  [[ "$rc" != 0 && "$(kv_get "$rl" reviewer.session)" == sess-3 ]] && grep -qF '.routed' <<<"$out" && grep -q 'handoff-route --foreground' <<<"$out" \
    && ok "a hand-off marker that cannot be cleared is reported, and the documented steps complete it (codex-role-review-r02/F-03)" || { bad "a hand-off marker that cannot be cleared is reported, and the documented steps complete it (codex-role-review-r02/F-03)"; printf '       %s\n' "$out"; }
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
  [[ "$rc" != 0 && "$c1" == "$c0" && "$rc2" == 0 && "$copies_ok" == 1 ]] \
    && ok "a loop.yaml copy whose write fails stays whole, and a rerun completes every copy (codex-role-review-r02/F-04)" || { bad "a loop.yaml copy whose write fails stays whole, and a rerun completes every copy (codex-role-review-r02/F-04)"; printf '       %s\n' "$out" "$out2"; }
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
  { (( rc == 0 )) || [[ "$c1" == "$c0" ]]; } && [[ "$copies_ok" == 1 ]] \
    && ok "a copy write interrupted after its first change never leaves a partial earlier template (codex-role-review-r02/F-04)" || { bad "a copy write interrupted after its first change never leaves a partial earlier template (codex-role-review-r02/F-04)"; printf '       %s\n' "$out" "$out2"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" && ! -d "$PW-review" ]] && grep -q 'tracked' <<<"$out" \
    && ok "Pi settings tracked in the commit a new worktree will check out refuse the replacement first (codex-role-review-r02/F-06)" || { bad "Pi settings tracked in the commit a new worktree will check out refuse the replacement first (codex-role-review-r02/F-06)"; printf '       %s\n' "$out"; }

  # Round 4 (codex-role-review-r03)
  open_reviewer; s0="$(sum "$rl")"; touch "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-truncated"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  rm -f "$FAKE_XIRP_DIR/delete-fail" "$FAKE_XIRP_DIR/list-truncated"
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && "$(created)" == 2 ]] \
    && ok "a Xirp list followed by unparsable output does not prove the old session gone (codex-role-review-r03/F-01)" || { bad "a Xirp list followed by unparsable output does not prove the old session gone (codex-role-review-r03/F-01)"; printf '       %s\n' "$out"; }
  open_reviewer; chmod 444 "$PW/.agent-handoff/add-export/routing.log"
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  chmod 644 "$PW/.agent-handoff/add-export/routing.log"; ROUTE_FG "$PW"
  [[ "$rc" != 0 && "$(created)" == 3 && "$(kv_get "$rl" reviewer.session)" == sess-3 && -z "$(msgs | grep '^sess-3')" ]] && routed "$PW" 01-implement.yaml && grep -q 'sess-3' <<<"$out" \
    && ok "a hand-off whose result could not be logged is never sent again (codex-role-review-r03/F-03)" || { bad "a hand-off whose result could not be logged is never sent again (codex-role-review-r03/F-03)"; printf '       %s\n' "$out"; msgs | sed 's/^/       /'; }
  # F-06: the Pi pre-check reads the worktree and commit the route or finish will really use.
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  git -C "$PW" update-index --skip-worktree .pi/settings.json; rm -rf "$PW/.pi"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1; s0="$(sum "$rl")"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(sum "$rl")" == "$s0" && -z "$(deleted)" ]] && grep -q 'tracked' <<<"$out" \
    && ok "Pi settings the shared worktree's index tracks, even when not checked out, refuse the replacement first (codex-role-review-r03/F-06)" || { bad "Pi settings the shared worktree's index tracks, even when not checked out, refuse the replacement first (codex-role-review-r03/F-06)"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$(role_block finish codex gpt-5.6-terra medium worktree=new)"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  wrpt "$PW"; hw "$PW" --role review --status done --verdict pass --head HEAD --report r.md; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  HOME="$PI_HOME" finish_in "$PW" add-export >/dev/null 2>&1; PF="$PW-finish"; f0="$(kv_get "$rl" finish.session)"
  git -C "$PF" rm -q .pi/settings.json; git -C "$PF" commit -qm "drop pi settings"; hw "$PF" --role finish --status blocked --head HEAD --note quota
  out="$(prole "$PW" add-export finish pi:openai/gpt-6.2-sol:high:api --replace 2>&1)"; rc=$?
  [[ -n "$f0" && "$rc" == 0 && "$(deleted)" == "$f0" && -n "$(kv_get "$rl" finish.session)" && "$(kv_get "$rl" finish.session)" != "$f0" ]] \
    && ok "a blocked finish in its own worktree is checked at that worktree's commit, not the implementer's (codex-role-review-r03/F-06)" || { bad "a blocked finish in its own worktree is checked at that worktree's commit, not the implementer's (codex-role-review-r03/F-06)"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$(role_block review codex gpt-6.1-sol high worktree=new)" "$CX_FIN"; pstart "$PD" add-export >/dev/null 2>&1; rl="$PW/.agent-handoff/add-export/loop.yaml"
  mkdir -p "$PW/.pi"; printf '{"defaultModel":"mine"}\n' > "$PW/.pi/settings.json"; git -C "$PW" add -f .pi/settings.json; git -C "$PW" commit -qm "own pi settings"
  commit_in "$PW" impl; hw "$PW" --role implement --status done --head HEAD; HOME="$PI_HOME" route_in "$PW" >/dev/null 2>&1
  wrpt "$PW-review"; hw "$PW-review" --role review --status done --verdict changes-required --head HEAD --report r.md
  git -C "$PW" rm -q .pi/settings.json; git -C "$PW" commit -qm "drop pi settings"
  out="$(prole "$PW" add-export review pi:openai/gpt-6.2-sol:medium:api --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(deleted)" == sess-2 && "$(created)" == 2 && "$(kv_get "$rl" review_template.harness)" == pi ]] \
    && ok "with no round waiting, an earlier review's commit is not checked as the next checkout (codex-role-review-r03/F-06)" || { bad "with no round waiting, an earlier review's commit is not checked as the next checkout (codex-role-review-r03/F-06)"; printf '       %s\n' "$out"; }

  # Round 5 (pi-role-review-r04/F-03): the new reviewer opened, but its session ID could not be recorded.
  open_reviewer
  out="$(PATH="$MVSHIM:$PATH" FAKE_MV_FAIL='*/loop.yaml' FAKE_MV_IF='session: sess-3' prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  ROUTE_FG "$PW"
  [[ "$rc" != 0 && "$(created)" == 3 ]] && routed "$PW" 01-implement.yaml && grep -q 'sess-3' <<<"$out" \
    && ok "a reviewer opened whose session ID could not be recorded is named, and no second reviewer opens (pi-role-review-r04/F-03)" || { bad "a reviewer opened whose session ID could not be recorded is named, and no second reviewer opens (pi-role-review-r04/F-03)"; printf '       %s\n' "$out"; }
  # pi-role-review-r05/F-01: once its ID is recorded by hand, replacing that reviewer hands the round on, once.
  lset "$rl" reviewer.session sess-3
  out="$(prole "$PW" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  ROUTE_FG "$PW"
  [[ "$rc" == 0 && "$(deleted | tail -1)" == sess-3 && "$(created)" == 4 && "$(kv_get "$rl" reviewer.session)" == sess-4 ]] \
    && ok "replacing a reviewer that was opened unrecorded hands the waiting round to the new one once (pi-role-review-r05/F-01)" || { bad "replacing a reviewer that was opened unrecorded hands the waiting round to the new one once (pi-role-review-r05/F-01)"; printf '       %s\n' "$out"; }
  # herdr-app: a Pi role starts in the Herdr app with provider, model and thinking, and its worktree gets the Pi settings
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; { printf 'host: herdr-app\n'; cat "$PD/.agent-handoff/roles.yaml"; } > "$PD/r.tmp" && mv "$PD/r.tmp" "$PD/.agent-handoff/roles.yaml"
  out="$(pstart "$PD" add-export 2>&1)"; rc=$?; c="$(happ_do space.new)"
  [[ "$rc" == 0 && "$(created)" == 0 && "$(happ_opt "$c" argv)" == '["pi","--provider","openai-codex","--model","gpt-6.2-sol","--thinking","high"]' \
    && "$(jq -c . "$PW/.pi/settings.json" 2>/dev/null)" == '{"defaultModel":"gpt-6.2-sol","defaultProvider":"openai-codex","defaultThinkingLevel":"high"}' ]] \
    && ok "a Pi implementer on the Herdr app starts with provider, model and thinking, and its worktree gets the Pi settings" \
    || { bad "a Pi implementer on the Herdr app starts with provider, model and thinking, and its worktree gets the Pi settings"; printf '       %s\n' "$out" "$c"; }
fi

if [[ "$fail" -ne 0 ]]; then
  printf 'test_agent_handoff: FAILED\n'
  exit 1
fi
printf 'test_agent_handoff: ok\n'
