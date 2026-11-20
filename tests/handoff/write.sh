#!/usr/bin/env bash
# Handoff test section "write". Run: bash tests/test_agent_handoff.sh write
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- handoff-write
  printf 'handoff-write\n'
  repo="$tmp/write-repo"; new_repo "$repo"
  head="$(git -C "$repo" rev-parse HEAD)"
  w() { (cd "$repo" && "$WRITE" "$@") ; }
  dir="$repo/.agent-handoff/add-export"

  out="$(w --change add-export --role implement --status done --head HEAD --note 'round one' 2>&1)" && [[ -f "$dir/01-implement.yaml" ]]; check "writes the first record as 01-implement.yaml" || { printf '       %s\n' "$out"; }
  if [[ -f "$dir/01-implement.yaml" ]] && source "$KV" 2>/dev/null; then
    f="$dir/01-implement.yaml"
    [[ "$(kv_get "$f" change)" == "add-export" && "$(kv_get "$f" role)" == "implement" && "$(kv_get "$f" status)" == "done" \
      && "$(kv_get "$f" head)" == "$head" && "$(kv_get "$f" round)" == "1" && "$(kv_get "$f" note)" == "round one" ]]; check "records change, role, status, full head, round and note"
    ! kv_get "$f" verdict >/dev/null 2>&1; check "implement record has no verdict"
    [[ "$(kv_get "$f" at)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$ ]]; check "at is ISO 8601 with offset"
  fi
  [[ -z "$(git -C "$repo" status --porcelain)" ]]; check "record does not show in git status"

  mkdir -p "$repo/reports"; printf 'report\n' > "$repo/reports/r01.md"
  mkdir -p "$repo/.git/info"; printf '/reports/\n' >> "$repo/.git/info/exclude"
  w --change add-export --role review --status done --verdict changes-required --head HEAD --report reports/r01.md >/dev/null 2>&1 \
    && [[ -f "$dir/02-review.yaml" ]] && [[ "$(kv_get "$dir/02-review.yaml" verdict)" == "changes-required" ]] \
    && [[ "$(kv_get "$dir/02-review.yaml" report)" == "reports/r01.md" ]] && [[ "$(kv_get "$dir/02-review.yaml" round)" == "1" ]]; check "review record is 02-review.yaml with verdict, report and round 1"
  before="$(cat "$dir/01-implement.yaml")"
  w --change add-export --role implement --status done --head HEAD >/dev/null 2>&1
  [[ -f "$dir/03-implement.yaml" && "$(kv_get "$dir/03-implement.yaml" round)" == "2" && "$(cat "$dir/01-implement.yaml")" == "$before" ]]; check "next implement record is 03 in round 2 and earlier files are unchanged"

  count="$(ls "$dir" | wc -l | tr -d ' ')"
  expect_reject() {
    local label="$1"; shift
    if w "$@" >/dev/null 2>&1; then bad "$label"; else
      [[ "$(ls "$dir" | wc -l | tr -d ' ')" == "$count" ]]; check "$label" || printf '       %s\n' "(left a file)"
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
  ! { (cd "$repo" && "$WRITE" --change ../escape --role implement --status done --head HEAD) >/dev/null 2>&1 \
    || [[ -e "$repo/.agent-handoff/escape" || -e "$repo/escape" ]]; }; check "rejects a change id that leaves .agent-handoff/"

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
    && -f "$wa/.agent-handoff/add-export/03-implement.yaml" ]]; check "sequence continues across the implementer and review worktrees"

  # Shared worktree: loop.yaml lists the same worktree for several roles; count it once.
  ws="$tmp/seq-shared"; new_repo "$ws"; mkdir -p "$ws/.agent-handoff/add-export" "$ws/r"; printf 'r\n' > "$ws/r/x.md"
  mkdir -p "$ws/.git/info"; printf '/r/\n' >> "$ws/.git/info/exclude"
  printf 'change: add-export\nimplementer:\n  worktree: %s\nreviewer:\n  worktree: %s\n' "$ws" "$ws" > "$ws/.agent-handoff/add-export/loop.yaml"
  (cd "$ws" && "$WRITE" --change add-export --role implement --status done --head HEAD) >/dev/null 2>&1
  (cd "$ws" && "$WRITE" --change add-export --role review --status done --verdict pass --head HEAD --report r/x.md) >/dev/null 2>&1
  [[ "$(kv_get "$ws/.agent-handoff/add-export/02-review.yaml" round 2>/dev/null)" == "1" ]]; check "a worktree listed for several roles is counted once"

finish_section write
