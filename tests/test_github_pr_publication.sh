#!/usr/bin/env bash
# Verifies, with real Git, the publication procedure that github-pr create
# documents: a scoped commit keeps unrelated staged, unstaged and untracked work
# intact; push goes to the verified destination without force; reruns reuse
# completed stages; a failing hook or a non-fast-forward stops without bypass;
# an existing unpublished predecessor base is published as it is.
# Maps to openspec/changes/streamline-github-pr-publication (tasks 1.2, 1.3).
#
# Everything runs in a temporary repository with a local bare remote. No GitHub
# call is made; PR creation itself is covered by replay cases, not here.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/template/common/skills/github-pr/SKILL.md"
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

# ── The skill documents exactly the procedure exercised below ────────────────
echo "documented procedure"
create_part() { sed -n '/^## Operation: create/,/^## Operation: update/p' "$SKILL" 2>/dev/null; }
for cmd in 'git add -- <pr-paths>' 'git commit -m "<message>" -- <pr-paths>' \
           'git push <remote> HEAD:refs/heads/<head-branch>' 'git ls-remote <remote> refs/heads/<head-branch>' \
           'git push <remote> <base-branch>:refs/heads/<base-branch>'; do
  create_part | grep -qF -- "$cmd" && ok "skill documents '$cmd'" || bad "skill documents '$cmd'"
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
REMOTE="$TMP/remote.git"; WORK="$TMP/work"
git init -q --bare "$REMOTE"
git init -q -b main "$WORK"
g() { git -C "$WORK" "$@"; }
g config user.name "Test"; g config user.email "test@example.invalid"; g config commit.gpgsign false
printf 'a\n' > "$WORK/pr_a.txt"; printf 's\n' > "$WORK/u_staged.txt"; printf 'u\n' > "$WORK/u_unstaged.txt"
g add -A; g commit -q -m "chore: base"
g remote add origin "$REMOTE"; g push -q origin main:refs/heads/main
g switch -q -c feature/x

# Mixed worktree: two PR files plus unrelated staged, unstaged and untracked work.
printf 'a2\n' > "$WORK/pr_a.txt"; printf 'new\n' > "$WORK/pr_new.txt"
printf 's2\n' > "$WORK/u_staged.txt"; g add u_staged.txt
printf 'u2\n' > "$WORK/u_unstaged.txt"
printf 'x\n'  > "$WORK/u_untracked.txt"
STATUS_BEFORE_UNRELATED="$(g status --porcelain=v1 --untracked-files=all | grep ' u_' | sort)"
BASE_COUNT="$(g rev-list --count HEAD)"

echo "scoped commit"
g add -- pr_a.txt pr_new.txt
if g commit -q -m "feat: add x" -- pr_a.txt pr_new.txt; then ok "scoped commit succeeds"; else bad "scoped commit succeeds"; fi
files="$(g show --name-only --format= HEAD | sort | tr '\n' ' ')"
[[ "$files" == "pr_a.txt pr_new.txt " ]] && ok "commit holds only the PR files ($files)" || bad "commit holds only the PR files ($files)"
[[ "$(g status --porcelain=v1 --untracked-files=all | grep ' u_\|^. u_\|^.. u_' | sort)" == "$STATUS_BEFORE_UNRELATED" ]] \
  && ok "unrelated staged, unstaged and untracked state is unchanged" || bad "unrelated staged, unstaged and untracked state is unchanged"
[[ "$(g diff --cached --name-only)" == "u_staged.txt" ]] && ok "unrelated staged entry is still staged" || bad "unrelated staged entry is still staged"
[[ "$(cat "$WORK/u_unstaged.txt")" == "u2" && "$(g show :u_unstaged.txt)" == "u" ]] \
  && ok "unrelated unstaged edit stays unstaged" || bad "unrelated unstaged edit stays unstaged"

echo "push and readback"
[[ "$(g remote get-url --push origin)" == "$REMOTE" ]] && ok "push destination is the verified remote" || bad "push destination is the verified remote"
g push -q origin HEAD:refs/heads/feature/x 2>/dev/null && ok "normal push succeeds" || bad "normal push succeeds"
remote_sha="$(g ls-remote origin refs/heads/feature/x | cut -f1)"
[[ "$remote_sha" == "$(g rev-parse HEAD)" ]] && ok "remote head equals the local commit" || bad "remote head equals the local commit"

echo "rerun reuses completed stages"
if g diff --quiet HEAD -- pr_a.txt pr_new.txt; then ok "no PR change left, so no second commit"; else bad "no PR change left, so no second commit"; fi
g push -q origin HEAD:refs/heads/feature/x 2>/dev/null && ok "repeat push is a no-op" || bad "repeat push is a no-op"
[[ "$(g rev-list --count HEAD)" == "$((BASE_COUNT + 1))" && "$(g ls-remote origin refs/heads/feature/x | cut -f1)" == "$remote_sha" ]] \
  && ok "commit count and remote head unchanged after rerun" || bad "commit count and remote head unchanged after rerun"

echo "failing hook is not bypassed"
printf 'a3\n' > "$WORK/pr_a.txt"
mkdir -p "$WORK/.git/hooks"; printf '#!/bin/sh\necho "test failed" >&2\nexit 1\n' > "$WORK/.git/hooks/pre-commit"; chmod +x "$WORK/.git/hooks/pre-commit"
head_before="$(g rev-parse HEAD)"
g add -- pr_a.txt
if g commit -q -m "feat: more" -- pr_a.txt 2>/dev/null; then bad "a failing hook stops the commit"; else ok "a failing hook stops the commit"; fi
[[ "$(g rev-parse HEAD)" == "$head_before" ]] && ok "HEAD unchanged after the hook failure" || bad "HEAD unchanged after the hook failure"
[[ "$(g diff --cached --name-only | sort | tr '\n' ' ')" == "pr_a.txt u_staged.txt " ]] \
  && ok "staged work survives the failed commit" || bad "staged work survives the failed commit"
rm -f "$WORK/.git/hooks/pre-commit"

echo "already committed, not yet pushed"
g commit -q -m "feat: more" -- pr_a.txt
local_sha="$(g rev-parse HEAD)"; count="$(g rev-list --count HEAD)"
g push -q origin HEAD:refs/heads/feature/x 2>/dev/null
[[ "$(g ls-remote origin refs/heads/feature/x | cut -f1)" == "$local_sha" && "$(g rev-list --count HEAD)" == "$count" ]] \
  && ok "existing commit is published without a new commit" || bad "existing commit is published without a new commit"

echo "non-fast-forward is not forced"
OTHER="$TMP/other"; git clone -q "$REMOTE" "$OTHER" 2>/dev/null
git -C "$OTHER" config user.name "Other"; git -C "$OTHER" config user.email "o@example.invalid"; git -C "$OTHER" config commit.gpgsign false
git -C "$OTHER" switch -q feature/x; printf 'o\n' > "$OTHER/o.txt"; git -C "$OTHER" add o.txt; git -C "$OTHER" commit -q -m "chore: other"
git -C "$OTHER" push -q origin HEAD:refs/heads/feature/x 2>/dev/null
other_sha="$(git -C "$OTHER" rev-parse HEAD)"
printf 'a4\n' > "$WORK/pr_a.txt"; g add -- pr_a.txt; g commit -q -m "feat: diverge" -- pr_a.txt
if g push -q origin HEAD:refs/heads/feature/x 2>/dev/null; then bad "a non-fast-forward push is rejected"; else ok "a non-fast-forward push is rejected"; fi
[[ "$(g ls-remote origin refs/heads/feature/x | cut -f1)" == "$other_sha" ]] && ok "remote head is not overwritten" || bad "remote head is not overwritten"

echo "existing unpublished predecessor base"
g switch -q -c feature/base main; printf 'b\n' > "$WORK/base.txt"; g add base.txt; g commit -q -m "feat: base"
base_sha="$(g rev-parse feature/base)"; base_count="$(g rev-list --count feature/base)"
g push -q origin feature/base:refs/heads/feature/base 2>/dev/null
[[ "$(g ls-remote origin refs/heads/feature/base | cut -f1)" == "$base_sha" && "$(g rev-list --count feature/base)" == "$base_count" ]] \
  && ok "the existing base ref is published as it is" || bad "the existing base ref is published as it is"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
