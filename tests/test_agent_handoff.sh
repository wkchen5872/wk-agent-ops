#!/usr/bin/env bash
# Offline tests for the agent handoff loop: record parser, handoff-write, routing hook, and launcher.
# Usage: bash tests/test_agent_handoff.sh [kv|write|skill|install|route|start|finish|hookinstall|cleanup|all]
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
  "session get") [[ "$3" == missing-* ]] && exit 1; jq -n --arg id "$3" '{id:$id, model:"fake-model"}' ;;
  "session message") printf '%s\t%s\n' "$3" "$4" >> "$S/messages" ;;
  "session delete") [[ "$3" == missing-* ]] && exit 1; printf '%s\n' "$3" >> "$S/deleted" ;;
  "project list") jq -n --arg p "$FAKE_PROJECT_PATH" '[{id:"proj-1", path:$p}]' ;;
esac
exit 0
SH
printf '#!/usr/bin/env bash\ntouch "$FAKE_XIRP_DIR/gh-called"\nexit 1\n' > "$FAKES/gh"
printf '#!/usr/bin/env bash\nprintf "action_required=%%s\\n" "${NOTIFY_ACTION_REQUIRED:-unset}" >> "$FAKE_XIRP_DIR/notified"\ncat >> "$FAKE_XIRP_DIR/notified"\nprintf "\\n" >> "$FAKE_XIRP_DIR/notified"\n' > "$FAKES/notify.sh"
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
route_in() { (cd "$1" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null); }
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
  notes | grep -q 'action_required=true' && ! notes | grep -q 'action_required=unset' \
    && ok "handoff notices are sent even when action-required notices are turned off" || bad "handoff notices are sent even when action-required notices are turned off"

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

if [[ "$fail" -ne 0 ]]; then
  printf 'test_agent_handoff: FAILED\n'
  exit 1
fi
printf 'test_agent_handoff: ok\n'
