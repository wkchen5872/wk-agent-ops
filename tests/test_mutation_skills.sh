#!/usr/bin/env bash
# Acceptance tests for profile-driven testland/qa mutation skill installation.
# Uses a fake npx; no network access or third-party install occurs.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/scripts/skills/install.sh"
fail=0

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
contains() { grep -Fq -- "$2" "$1" && ok "$3" || bad "$3"; }
forbids() { grep -Fq -- "$2" "$1" && bad "$3" || ok "$3"; }
count_token() {
  local file="$1" token="$2" expected="$3" label="$4" actual
  actual="$(grep -oF -- "$token" "$file" 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$actual" == "$expected" ]] && ok "$label" || bad "$label (expected $expected, got $actual)"
}

DOC="$ROOT/template/common/docs/mutation-testing.md"
PROTO="$ROOT/template/common/docs/agent-protocol.md"
for legacy in mutation-setup mutation-check; do
  [[ ! -f "$ROOT/template/common/skills/$legacy/SKILL.md" ]] \
    && ok "legacy $legacy source removed" \
    || bad "legacy $legacy source removed"
done
for skill in stryker-mutation mutmut-mutation pitest-mutation stryker-net-mutation mutant-survival-triage; do
  contains "$DOC" "$skill" "playbook documents $skill"
done
for term in 'Five-step closed loop' missing-case weak-assertion equivalent-mutant unreachable flaky-killer baseline 'no regression' ratchet inconclusive; do
  contains "$DOC" "$term" "playbook documents $term"
done
contains "$PROTO" 'mutant-survival-triage' "protocol routes through survivor triage"
contains "$PROTO" 'The first valid mutation result establishes a baseline' "protocol defines score baseline"
forbids "$PROTO" '/mutation-check' "protocol drops legacy slash command"
contains "$ROOT/docs/architecture.md" 'testland/qa' "architecture records third-party boundary"
contains "$ROOT/README.md" 'stryker-net-mutation' "README lists language mapping"
contains "$ROOT/AGENTS.md" 'testland/qa mutation runner + survivor triage' "AGENTS documents current skills"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAKE_BIN="$SCRATCH/bin"
mkdir -p "$FAKE_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$PWD" > "${NPX_CWD_LOG:?}"' \
  'printf "%s\n" "$*" > "${NPX_ARGS_LOG:?}"' \
  'exit "${NPX_EXIT_CODE:-0}"' > "$FAKE_BIN/npx"
chmod +x "$FAKE_BIN/npx"

NO_NPX_BIN="$SCRATCH/no-npx-bin"
mkdir -p "$NO_NPX_BIN"
for command_name in git dirname basename mkdir rsync cp mktemp grep mv find chmod rm; do
  ln -s "$(command -v "$command_name")" "$NO_NPX_BIN/$command_name"
done

new_target() {
  local target
  target="$(mktemp -d "$SCRATCH/target.XXXXXX")"
  git -C "$target" init -q
  (cd "$target" && pwd -P)
}

run_with_fake_npx() {
  local target="$1" output="$2"
  shift 2
  NPX_ARGS_LOG="$SCRATCH/npx-args" \
  NPX_CWD_LOG="$SCRATCH/npx-cwd" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
    bash "$INSTALLER" --target "$target" "$@" > "$output" 2>&1
}

assert_profile() {
  local profile="$1" runner="$2" target output
  target="$(new_target)"
  output="$SCRATCH/$profile.out"
  : > "$SCRATCH/npx-args"
  : > "$SCRATCH/npx-cwd"
  if run_with_fake_npx "$target" "$output" "$profile"; then
    ok "$profile profile installs"
  else
    bad "$profile profile installs"
  fi
  contains "$SCRATCH/npx-args" 'skills add testland/qa' "$profile uses testland/qa"
  count_token "$SCRATCH/npx-args" "--skill $runner" 1 "$profile installs one runner"
  count_token "$SCRATCH/npx-args" '--skill mutant-survival-triage' 1 "$profile installs triage once"
  contains "$SCRATCH/npx-args" '--agent claude-code' "$profile selects Claude Code"
  contains "$SCRATCH/npx-args" '--agent codex' "$profile selects Codex"
  contains "$SCRATCH/npx-args" '--agent antigravity' "$profile selects Antigravity"
  contains "$SCRATCH/npx-args" '--yes' "$profile installs non-interactively"
  forbids "$SCRATCH/npx-args" '--global' "$profile stays project-local"
  forbids "$SCRATCH/npx-args" '--copy' "$profile keeps link mode"
  [[ "$(cat "$SCRATCH/npx-cwd" 2>/dev/null)" == "$target" ]] \
    && ok "$profile runs skills CLI in target" \
    || bad "$profile runs skills CLI in target"
}

assert_profile node stryker-mutation
assert_profile python mutmut-mutation
assert_profile jvm pitest-mutation
assert_profile dotnet stryker-net-mutation

# Multiple profiles use one command, one runner per language, and one triage.
target="$(new_target)"
output="$SCRATCH/multi.out"
: > "$SCRATCH/npx-args"
if run_with_fake_npx "$target" "$output" python node jvm dotnet; then
  ok "multiple profiles install"
else
  bad "multiple profiles install"
fi
for runner in stryker-mutation mutmut-mutation pitest-mutation stryker-net-mutation; do
  count_token "$SCRATCH/npx-args" "--skill $runner" 1 "multi-profile installs $runner once"
done
count_token "$SCRATCH/npx-args" '--skill mutant-survival-triage' 1 "multi-profile installs triage once"

# Common-only does not guess a language or call npx.
target="$(new_target)"
output="$SCRATCH/common.out"
rm -f "$SCRATCH/npx-args" "$SCRATCH/npx-cwd"
if run_with_fake_npx "$target" "$output"; then
  ok "common-only install succeeds"
else
  bad "common-only install succeeds"
fi
[[ ! -e "$SCRATCH/npx-args" ]] && ok "common-only skips npx" || bad "common-only skips npx"
cmp -s "$DOC" "$target/docs/mutation-testing.md" \
  && ok "playbook propagates as managed doc" \
  || bad "playbook propagates as managed doc"
cmp -s "$PROTO" "$target/docs/agent-protocol.md" \
  && ok "protocol propagates as managed doc" \
  || bad "protocol propagates as managed doc"

# Unknown profiles fail before any third-party call.
target="$(new_target)"
output="$SCRATCH/unknown.out"
rm -f "$SCRATCH/npx-args" "$SCRATCH/npx-cwd"
if run_with_fake_npx "$target" "$output" ruby; then
  bad "unknown profile fails"
else
  ok "unknown profile fails"
fi
[[ ! -e "$SCRATCH/npx-args" ]] && ok "unknown profile skips npx" || bad "unknown profile skips npx"

# A missing npx and a failed skills CLI both return non-zero with replayable guidance.
target="$(new_target)"
output="$SCRATCH/missing-npx.out"
if PATH="$NO_NPX_BIN" /bin/bash "$INSTALLER" --target "$target" node > "$output" 2>&1; then
  bad "missing npx fails"
else
  ok "missing npx fails"
fi
contains "$output" 'npx skills add testland/qa' "missing npx prints replay command"

target="$(new_target)"
output="$SCRATCH/npx-failure.out"
: > "$SCRATCH/npx-args"
if NPX_EXIT_CODE=42 run_with_fake_npx "$target" "$output" python; then
  bad "skills CLI failure propagates"
else
  ok "skills CLI failure propagates"
fi
contains "$output" 'npx skills add testland/qa' "skills CLI failure prints replay command"

# Migration removes only the two legacy skill directories.
target="$(new_target)"
mkdir -p "$target/.claude/skills/mutation-setup" \
         "$target/.claude/skills/mutation-check" \
         "$target/.claude/skills/user-skill" \
         "$target/.agents/skills/mutation-setup" \
         "$target/.agents/skills/mutation-check" \
         "$target/.agents/skills/user-skill"
output="$SCRATCH/cleanup.out"
run_with_fake_npx "$target" "$output" node || bad "cleanup install succeeds"
for provider in .claude .agents; do
  [[ ! -e "$target/$provider/skills/mutation-setup" ]] && ok "$provider removes mutation-setup" || bad "$provider removes mutation-setup"
  [[ ! -e "$target/$provider/skills/mutation-check" ]] && ok "$provider removes mutation-check" || bad "$provider removes mutation-check"
  [[ -d "$target/$provider/skills/user-skill" ]] && ok "$provider preserves user skill" || bad "$provider preserves user skill"
done

printf '\n'
[[ $fail -eq 0 ]] && { printf 'PASS\n'; exit 0; } || { printf 'FAIL\n'; exit 1; }
