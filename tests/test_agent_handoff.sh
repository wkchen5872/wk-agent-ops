#!/usr/bin/env bash
# Offline tests for the agent handoff loop: record parser, handoff-write, routing hook, and launcher.
# Usage: bash tests/test_agent_handoff.sh [kv|write|skill|install|route|notify|mixed|start|finish|hookinstall|cleanup|pi|all]
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/template/common/skills/agent-handoff"
KV="$SKILL/scripts/kv.sh"
WRITE="$SKILL/scripts/handoff-write"
section="${1:-all}"
fail=0

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
    json="$5"; n=$(( $(cat "$S/count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$S/count"
    printf '%s\n' "$json" > "$S/create-$n.json"
    jq -c --arg id "sess-$n" '{id:$id, name:.customName}' <<<"$json" >> "$S/sessions"; echo '{}' ;;
  "session list") if [[ -s "$S/sessions" ]]; then jq -s '.' "$S/sessions"; else echo '[]'; fi ;;
  "session get") [[ "$3" == missing-* ]] && exit 1
    if [[ -f "$S/session.json" ]]; then jq --arg id "$3" '. + {id:$id}' "$S/session.json"
    else jq -n --arg id "$3" '{id:$id, currentAgent:"claude", model:"fake-model", agentLaunchOptions:{agentName:"claude", options:{model:"opus", effort:"high"}}}'; fi ;;
  "session message") [[ -e "$S/msg-fail" ]] && exit 1; printf '%s\t%s\n' "$3" "$4" >> "$S/messages" ;;
  "session delete") [[ "$3" == missing-* ]] && exit 1; printf '%s\n' "$3" >> "$S/deleted" ;;
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
fresh_state() { export FAKE_XIRP_DIR="$tmp/state-$1"; rm -rf "$FAKE_XIRP_DIR"; mkdir -p "$FAKE_XIRP_DIR"; }
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
  route_in "$A"
  [[ "$(created)" == 1 ]] && ok "the same record is routed only once" || bad "the same record is routed only once"

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
start_in() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 "$START" "$@" </dev/null); }
finish_in() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" HANDOFF_CREATE_WAIT=2 "$FINISH" "$@" </dev/null); }

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
  R="$tmp/start-reuse"; new_project "$R"; use_project "$R"; fresh_state s7
  out="$(start_in "$R" add-export --reviewer-session rev-9 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$R-add-export/.agent-handoff/add-export/loop.yaml" reviewer.session)" == rev-9 && "$(created)" == 1 ]] \
    && ok "an existing reviewer session is recorded and not reopened" || bad "an existing reviewer session is recorded and not reopened"
  R2="$tmp/start-reuse-missing"; new_project "$R2"; use_project "$R2"; fresh_state s8
  out="$(start_in "$R2" add-export --reviewer-session missing-1 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && ok "an unknown reviewer session is refused" || bad "an unknown reviewer session is refused"
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

# ---------------------------------------------------------------- user-level installer and README
if run_section hookinstall; then
  printf 'hook installer\n'
  HH="$tmp/home"; mkdir -p "$HH/.codex"; printf 'keep = true\n' > "$HH/.codex/config.toml"
  out="$(HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" 2>&1)"; rc=$?
  HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$rc" == 0 && -x "$HH/.local/bin/handoff-start" && -x "$HH/.local/bin/handoff-finish" && -x "$HH/.local/bin/handoff-cleanup" && -x "$HH/.config/wk-workflow/handoff/handoff-route" \
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
  for opt in $( { "$START" --help; "$FINISH" --help; "$ROOT/scripts/handoff/handoff-cleanup" --help; } 2>/dev/null | grep -oE -- '--[a-z][a-z-]+' | sort -u); do
    grep -q -- "$opt" "$readme" 2>/dev/null || missing="$missing $opt"
  done
  [[ -f "$readme" && -z "$missing" ]] && grep -q 'handoff-finish' "$readme" && grep -q 'roles.yaml' "$readme" \
    && ok "README documents every command option" || bad "README documents every command option (missing:$missing)"
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

  out="$(clean_in "$P" add-export --yes 2>&1)"; rc=$?
  arc="$P/.agent-handoff/archive/add-export"
  if [[ "$rc" == 0 && -f "$arc/$(basename "$A")/01-implement.yaml" && -f "$arc/$(basename "$B")/02-review.yaml" && -f "$arc/$(basename "$B")/rv/r01.md" \
    && -n "$(ls "$arc/$(basename "$F")"/*-finish.yaml 2>/dev/null)" ]]; then
    ok "records and review reports are archived in the main worktree"
  else
    bad "records and review reports are archived in the main worktree"; printf '       %s\n' "$out"
  fi
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
  out="$(clean_in "$H" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$H/.git" && "$(deleted | sort | tr '\n' ' ')" == "rev-2 sess-1 " && -f "$H/.agent-handoff/archive/add-export/$(basename "$H")/03-finish.yaml" ]] \
    && ok "an implementer in the main worktree keeps the main worktree" || { bad "an implementer in the main worktree keeps the main worktree"; printf '       %s\n' "$out"; }
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
    printf '%s\n' "$j" > "$h/.pi/agent/trust.json"; export PI_HOME="$h"
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
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --impl codex:gpt-x:low 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && jq -e '.agent.agentName=="codex" and (.agent.options|has("provider")|not)' "$FAKE_XIRP_DIR/create-1.json" >/dev/null && [[ ! -e "$PW/.pi/settings.json" ]] \
    && ok "a Codex override replaces a Pi template without its provider and billing" || { bad "a Codex override replaces a Pi template without its provider and billing"; printf '       %s\n' "$out"; }
  pi_project "$CX_IMPL" "$CX_REV" "$CX_FIN"; out="$(pstart "$PD" add-export --impl pi:openai-codex/gpt-6.2-sol:high:api 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q implement <<<"$out" && ok "a Pi override is verified like a template" || bad "a Pi override is verified like a template ($out)"

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

  # 5.4 cleanup removes the settings the loop wrote in the main worktree
  pi_state cleanup
  pi_project "$PI_IMPL" "$CX_REV" "$CX_FIN"; git -C "$PD" switch -q feature/add-export
  hout="$(pstart "$PD" add-export --worktree here 2>&1)"
  pclean() { (cd "$1" && HOME="$PI_HOME" PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" add-export --abandon --yes >/dev/null 2>&1); }
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
fi

if [[ "$fail" -ne 0 ]]; then
  printf 'test_agent_handoff: FAILED\n'
  exit 1
fi
printf 'test_agent_handoff: ok\n'
