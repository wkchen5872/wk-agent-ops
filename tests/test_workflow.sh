#!/usr/bin/env bash
# Offline contract tests for the multi-provider workflow helpers.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
section="${1:-all}"
fail=0

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

run_section() {
  [[ "$section" == "all" || "$section" == "$1" ]]
}

new_repo() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name "Workflow Test"
  git -C "$dir" config commit.gpgsign false
  printf 'seed\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -qm seed
}

if run_section branch; then
  printf 'branch-first entry point\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-branch.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  repo="$tmp/repo"
  new_repo "$repo"

  if output="$(cd "$repo" && bash "$ROOT/scripts/workflow/opsx-branch.sh" new-feature 2>&1)" \
    && [[ "$(git -C "$repo" branch --show-current)" == "feature/new-feature" ]]; then
    ok "creates and switches to a new planning branch"
  else
    bad "creates and switches to a new planning branch"
    printf '       %s\n' "$output"
  fi

  git -C "$repo" switch -q main
  git -C "$repo" branch feature/existing-feature
  if output="$(cd "$repo" && bash "$ROOT/scripts/workflow/opsx-branch.sh" existing-feature 2>&1)" \
    && [[ "$(git -C "$repo" branch --show-current)" == "feature/existing-feature" ]]; then
    ok "switches to an existing planning branch"
  else
    bad "switches to an existing planning branch"
    printf '       %s\n' "$output"
  fi

  git -C "$repo" switch -q main
  git -C "$repo" branch feature/occupied-feature
  occupied="$tmp/occupied"
  git -C "$repo" worktree add -q "$occupied" feature/occupied-feature
  occupied="$(cd "$occupied" && pwd -P)"
  if output="$(cd "$repo" && bash "$ROOT/scripts/workflow/opsx-branch.sh" occupied-feature 2>&1)"; then
    bad "rejects a branch held by another worktree"
  elif [[ "$output" == *"$occupied"* ]]; then
    ok "rejects a branch held by another worktree"
  else
    bad "reports the worktree holding the branch"
    printf '       %s\n' "$output"
  fi

  if output="$(cd "$repo" && bash "$ROOT/scripts/workflow/opsx-branch.sh" 'Invalid Name' 2>&1)"; then
    bad "rejects a non-kebab-case change ID"
  elif [[ "$output" == *"kebab-case"* ]]; then
    ok "rejects a non-kebab-case change ID"
  else
    bad "explains invalid change ID format"
  fi

  git -C "$repo" switch -q feature/existing-feature
  hook_input='{"tool_input":{"command":"openspec new change existing-feature"}}'
  if output="$(printf '%s' "$hook_input" | CLAUDE_PROJECT_DIR="$repo" bash "$ROOT/scripts/workflow/openspec-branch-creator/hook.sh" 2>&1)" \
    && [[ "$output" == *"Already on branch"* ]]; then
    ok "compatibility hook is a no-op on the target branch"
  else
    bad "compatibility hook is a no-op on the target branch"
    printf '       %s\n' "$output"
  fi
fi

if run_section resolver; then
  printf 'Git worktree resolver\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-resolver.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  repo="$tmp/repo"
  new_repo "$repo"
  fakebin="$tmp/bin"
  mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nprintf "cwd=%%s argv=%%s\\n" "$PWD" "$*" >> "$WORKFLOW_TEST_LOG"\n' > "$fakebin/claude"
  chmod +x "$fakebin/claude"
  log="$tmp/provider.log"

  make_change_branch() {
    local name="$1"
    git -C "$repo" switch -q main
    git -C "$repo" switch -qc "feature/$name"
    mkdir -p "$repo/openspec/changes/$name"
    printf '# %s\n' "$name" > "$repo/openspec/changes/$name/proposal.md"
    git -C "$repo" add "openspec/changes/$name/proposal.md"
    git -C "$repo" commit -qm "plan $name"
    git -C "$repo" switch -q main
  }

  make_change_branch fixed-change
  fixed="$repo/.worktrees/fixed-change"
  git -C "$repo" worktree add -q "$fixed" feature/fixed-change

  make_change_branch named-change
  named="$tmp/provider-named"
  git -C "$repo" worktree add -q "$named" feature/named-change

  make_change_branch detached-change
  detached="$tmp/provider-detached"
  git -C "$repo" worktree add -qd "$detached" feature/detached-change

  make_change_branch ambiguous-change
  ambiguous_a="$tmp/provider-ambiguous-a"
  ambiguous_b="$tmp/provider-ambiguous-b"
  git -C "$repo" worktree add -qd "$ambiguous_a" feature/ambiguous-change
  git -C "$repo" worktree add -qd "$ambiguous_b" feature/ambiguous-change
  ambiguous_a="$(cd "$ambiguous_a" && pwd -P)"
  ambiguous_b="$(cd "$ambiguous_b" && pwd -P)"

  unregistered="$tmp/unregistered"
  mkdir -p "$unregistered"
  if output="$(cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" fixed-change --agent claude --session s1 --path "$unregistered" 2>&1)"; then
    bad "rejects an explicit unregistered path"
  elif [[ "$output" == *"not a registered worktree"* ]]; then
    ok "rejects an explicit unregistered path"
  else
    bad "explains explicit unregistered path rejection"
    printf '       %s\n' "$output"
  fi

  : > "$log"
  if cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" fixed-change --agent claude --session s1 --path "$fixed" >/dev/null 2>&1 \
    && grep -Fq "cwd=$(cd "$fixed" && pwd -P)" "$log"; then
    ok "accepts an explicit registered path"
  else
    bad "accepts an explicit registered path"
  fi

  : > "$log"
  if cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" fixed-change --agent claude --session s1 >/dev/null 2>&1 \
    && grep -Fq "cwd=$(cd "$fixed" && pwd -P)" "$log"; then
    ok "prefers the registered project-managed path"
  else
    bad "prefers the registered project-managed path"
  fi

  : > "$log"
  if cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" named-change --agent claude --session s1 >/dev/null 2>&1 \
    && grep -Fq "cwd=$(cd "$named" && pwd -P)" "$log"; then
    ok "finds one registered named-branch worktree"
  else
    bad "finds one registered named-branch worktree"
  fi

  : > "$log"
  if cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" detached-change --agent claude --session s1 >/dev/null 2>&1 \
    && grep -Fq "cwd=$(cd "$detached" && pwd -P)" "$log"; then
    ok "finds one eligible detached worktree"
  else
    bad "finds one eligible detached worktree"
  fi

  if output="$(cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" ambiguous-change --agent claude --session s1 2>&1)"; then
    bad "rejects ambiguous detached candidates"
  elif [[ "$output" == *"$ambiguous_a"* && "$output" == *"$ambiguous_b"* && "$output" == *"--path"* ]]; then
    ok "rejects ambiguous detached candidates"
  else
    bad "lists ambiguous candidates and requires --path"
    printf '       %s\n' "$output"
  fi

  printf 'dirty\n' >> "$fixed/README.md"
  printf 'untracked\n' > "$fixed/local.tmp"
  before_status="$(git -C "$fixed" status --short)"
  before_diff="$(git -C "$fixed" diff -- README.md)"
  : > "$log"
  cd "$repo" && PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log" \
    bash "$ROOT/scripts/workflow/wt-resume.sh" fixed-change --agent claude --session s1 >/dev/null 2>&1 || true
  after_status="$(git -C "$fixed" status --short)"
  after_diff="$(git -C "$fixed" diff -- README.md)"
  if [[ "$before_status" == "$after_status" && "$before_diff" == "$after_diff" ]]; then
    ok "preserves dirty status and diff byte-for-byte"
  else
    bad "preserves dirty status and diff byte-for-byte"
  fi
fi

if run_section handoff; then
  printf 'reviewed branch hand-off\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-handoff.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  fakebin="$tmp/bin"
  mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/claude"
  chmod +x "$fakebin/claude"

  add_plan() {
    local repo="$1" name="$2"
    git -C "$repo" switch -qc "feature/$name"
    mkdir -p "$repo/openspec/changes/$name"
    printf '# %s\n' "$name" > "$repo/openspec/changes/$name/proposal.md"
    git -C "$repo" add "openspec/changes/$name/proposal.md"
    git -C "$repo" commit -qm "plan $name"
  }

  local_repo="$tmp/local"
  new_repo "$local_repo"
  add_plan "$local_repo" local-change
  if cd "$local_repo" && PATH="$fakebin:$PATH" \
    bash "$ROOT/scripts/workflow/wt-work.sh" local-change --agent claude >/dev/null 2>&1 \
    && [[ "$(git -C "$local_repo" branch --show-current)" == main \
      && -d "$local_repo/.worktrees/local-change/openspec/changes/local-change" ]]; then
    ok "relocates a clean planning branch from the primary checkout"
  else
    bad "relocates a clean planning branch from the primary checkout"
  fi

  dirty_repo="$tmp/dirty-primary"
  new_repo "$dirty_repo"
  add_plan "$dirty_repo" dirty-change
  printf 'dirty\n' >> "$dirty_repo/README.md"
  before="$(git -C "$dirty_repo" diff -- README.md)"
  if output="$(cd "$dirty_repo" && PATH="$fakebin:$PATH" \
    bash "$ROOT/scripts/workflow/wt-work.sh" dirty-change --agent claude 2>&1)"; then
    bad "refuses to relocate a dirty primary checkout"
  elif [[ "$(git -C "$dirty_repo" branch --show-current)" == feature/dirty-change \
    && "$(git -C "$dirty_repo" diff -- README.md)" == "$before" ]]; then
    ok "refuses to relocate a dirty primary checkout"
  else
    bad "leaves a dirty primary checkout unchanged"
    printf '       %s\n' "$output"
  fi

  remote_repo="$tmp/remote-client"
  bare="$tmp/origin.git"
  git init -q --bare "$bare"
  new_repo "$remote_repo"
  git -C "$remote_repo" remote add origin "$bare"
  git -C "$remote_repo" push -q -u origin main
  add_plan "$remote_repo" remote-change
  git -C "$remote_repo" push -q origin feature/remote-change
  git -C "$remote_repo" switch -q main
  git -C "$remote_repo" branch -D feature/remote-change >/dev/null
  git -C "$remote_repo" update-ref -d refs/remotes/origin/feature/remote-change
  if cd "$remote_repo" && PATH="$fakebin:$PATH" \
    bash "$ROOT/scripts/workflow/wt-work.sh" remote-change --agent claude >/dev/null 2>&1 \
    && [[ -d "$remote_repo/.worktrees/remote-change/openspec/changes/remote-change" ]]; then
    ok "fetches a reviewed remote-only planning branch"
  else
    bad "fetches a reviewed remote-only planning branch"
  fi

  missing_repo="$tmp/missing"
  new_repo "$missing_repo"
  if output="$(cd "$missing_repo" && PATH="$fakebin:$PATH" \
    bash "$ROOT/scripts/workflow/wt-work.sh" missing-change --agent claude 2>&1)"; then
    bad "rejects a confirmed missing planning branch"
  elif ! git -C "$missing_repo" show-ref --verify --quiet refs/heads/feature/missing-change \
    && [[ ! -e "$missing_repo/.worktrees/missing-change" ]]; then
    ok "rejects a confirmed missing planning branch"
  else
    bad "missing-branch failure leaves no branch or worktree"
    printf '       %s\n' "$output"
  fi

  unplanned_repo="$tmp/unplanned"
  new_repo "$unplanned_repo"
  git -C "$unplanned_repo" branch feature/unplanned-change
  if output="$(cd "$unplanned_repo" && PATH="$fakebin:$PATH" \
    bash "$ROOT/scripts/workflow/wt-work.sh" unplanned-change --agent claude 2>&1)"; then
    bad "rejects a feature branch without reviewed planning artifacts"
  elif [[ ! -e "$unplanned_repo/.worktrees/unplanned-change" ]]; then
    ok "rejects a feature branch without reviewed planning artifacts"
  else
    bad "unplanned branch failure leaves no worktree"
    printf '       %s\n' "$output"
  fi

  broken_repo="$tmp/broken-origin"
  new_repo "$broken_repo"
  git -C "$broken_repo" remote add origin "$tmp/does-not-exist.git"
  if output="$(cd "$broken_repo" && PATH="$fakebin:$PATH" \
    bash "$ROOT/scripts/workflow/wt-work.sh" broken-change --agent claude 2>&1)"; then
    bad "does not conflate remote failure with a missing branch"
  elif [[ "$output" == *"could not query origin"* \
    && ! -e "$broken_repo/.worktrees/broken-change" ]]; then
    ok "does not conflate remote failure with a missing branch"
  else
    bad "reports remote infrastructure failure without creating a worktree"
    printf '       %s\n' "$output"
  fi
fi

if run_section providers; then
  printf 'Provider session adapters\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-providers.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  repo="$tmp/repo"
  new_repo "$repo"
  git -C "$repo" switch -qc feature/provider-change
  mkdir -p "$repo/openspec/changes/provider-change"
  printf '# provider-change\n' > "$repo/openspec/changes/provider-change/proposal.md"
  git -C "$repo" add openspec/changes/provider-change/proposal.md
  git -C "$repo" commit -qm plan
  git -C "$repo" switch -q main
  worktree="$repo/.worktrees/provider-change"
  git -C "$repo" worktree add -q "$worktree" feature/provider-change

  fakebin="$tmp/bin"
  mkdir -p "$fakebin"
  for executable in claude codex agy copilot; do
    printf '#!/usr/bin/env bash\nprintf "exe=%%s cwd=%%s argv=%%s\\n" "$(basename "$0")" "$PWD" "$*" >> "$WORKFLOW_TEST_LOG"\n' \
      > "$fakebin/$executable"
    chmod +x "$fakebin/$executable"
  done
  log="$tmp/provider.log"
  export PATH="$fakebin:$PATH" WORKFLOW_TEST_LOG="$log"

  assert_log() {
    local expected="$1" label="$2"
    if grep -Fq -- "$expected" "$log"; then ok "$label"; else bad "$label"; fi
  }

  : > "$log"
  (cd "$repo" && bash "$ROOT/scripts/workflow/pm-start.sh") >/dev/null 2>&1 || true
  assert_log "exe=claude cwd=$(cd "$repo" && pwd -P) argv=--name PM: $(basename "$repo") --permission-mode plan" \
    "pm-start defaults to Claude native plan mode"

  : > "$log"
  (cd "$repo" && bash "$ROOT/scripts/workflow/pm-start.sh" --agent antigravity) >/dev/null 2>&1 || true
  assert_log "exe=agy cwd=$(cd "$repo" && pwd -P) argv=--mode plan" \
    "pm-start uses Antigravity native plan mode"

  : > "$log"
  (cd "$repo" && bash "$ROOT/scripts/workflow/pm-start.sh" --agent agy) >/dev/null 2>&1 || true
  assert_log "exe=agy cwd=$(cd "$repo" && pwd -P) argv=--mode plan" \
    "pm-start accepts the agy alias"

  for provider in codex copilot; do
    : > "$log"
    output="$(cd "$repo" && bash "$ROOT/scripts/workflow/pm-start.sh" --agent "$provider" 2>&1)" || true
    if grep -Fq "exe=$provider cwd=$(cd "$repo" && pwd -P) argv=" "$log" \
      && [[ "$output" == *"select plan mode inside"* ]]; then
      ok "pm-start launches $provider with an in-session plan notice"
    else
      bad "pm-start launches $provider with an in-session plan notice"
    fi
  done

  : > "$log"
  (cd "$repo" && bash "$ROOT/scripts/workflow/wt-work.sh" provider-change \
    --agent agy --path "$worktree") >/dev/null 2>&1 || true
  line="$(tail -1 "$log")"
  count="$(printf '%s' "$line" | grep -o 'openspec-apply-change' | wc -l | tr -d ' ')"
  if [[ "$line" == *"exe=agy"* && "$count" == 1 ]]; then
    ok "wt-work accepts agy as the Antigravity alias"
  else
    bad "wt-work accepts agy as the Antigravity alias"
  fi

  : > "$log"
  (cd "$repo" && bash "$ROOT/scripts/workflow/wt-resume.sh" provider-change \
    --agent agy --session session-1 --path "$worktree") >/dev/null 2>&1 || true
  line="$(tail -1 "$log")"
  if [[ "$line" == *"exe=agy"* && "$line" == *"session-1"* \
    && "$line" != *"openspec-apply-change"* ]]; then
    ok "wt-resume accepts agy as the Antigravity alias"
  else
    bad "wt-resume accepts agy as the Antigravity alias"
  fi

  for provider in claude codex antigravity copilot; do
    : > "$log"
    (cd "$repo" && bash "$ROOT/scripts/workflow/wt-work.sh" provider-change \
      --agent "$provider" --path "$worktree") >/dev/null 2>&1 || true
    line="$(tail -1 "$log")"
    count="$(printf '%s' "$line" | grep -o 'openspec-apply-change' | wc -l | tr -d ' ')"
    if [[ "$count" == 1 ]]; then
      ok "wt-work starts $provider with one apply intent"
    else
      bad "wt-work starts $provider with one apply intent"
    fi

    : > "$log"
    (cd "$repo" && bash "$ROOT/scripts/workflow/wt-work.sh" provider-change \
      --agent "$provider" --session session-1 --path "$worktree") >/dev/null 2>&1 || true
    line="$(tail -1 "$log")"
    count="$(printf '%s' "$line" | grep -o 'openspec-apply-change' | wc -l | tr -d ' ')"
    if [[ "$line" == *"session-1"* && "$count" == 1 ]]; then
      ok "wt-work resumes $provider with one apply intent"
    else
      bad "wt-work resumes $provider with one apply intent"
    fi

    : > "$log"
    (cd "$repo" && bash "$ROOT/scripts/workflow/wt-resume.sh" provider-change \
      --agent "$provider" --session session-1 --path "$worktree") >/dev/null 2>&1 || true
    line="$(tail -1 "$log")"
    if [[ "$line" == *"session-1"* && "$line" != *"openspec-apply-change"* ]]; then
      ok "wt-resume resumes $provider without apply intent"
    else
      bad "wt-resume resumes $provider without apply intent"
    fi

    : > "$log"
    (cd "$repo" && bash "$ROOT/scripts/workflow/wt-resume.sh" provider-change \
      --agent "$provider" --path "$worktree") >/dev/null 2>&1 || true
    line="$(tail -1 "$log")"
    if [[ -n "$line" && "$line" != *"openspec-apply-change"* ]]; then
      ok "wt-resume opens $provider native resume behavior without apply intent"
    else
      bad "wt-resume opens $provider native resume behavior without apply intent"
    fi
  done

  if output="$(cd "$repo" && bash "$ROOT/scripts/workflow/wt-work.sh" provider-change \
    --agent gemini --path "$worktree" 2>&1)"; then
    bad "wt-work rejects removed Gemini Provider"
  elif [[ "$output" == *"claude, codex, antigravity, agy, copilot"* && "$output" != *"one of: claude, copilot, gemini"* ]]; then
    ok "wt-work rejects removed Gemini Provider"
  else
    bad "wt-work lists only current Providers"
  fi

  if (cd "$repo" && bash "$ROOT/scripts/workflow/wt-resume.sh" provider-change \
    --agent gemini --path "$worktree") >/dev/null 2>&1; then
    bad "wt-resume rejects removed Gemini Provider"
  else
    ok "wt-resume rejects removed Gemini Provider"
  fi

  if (cd "$repo" && bash "$ROOT/scripts/workflow/wt-work.sh") >/dev/null 2>&1 \
    || (cd "$repo" && bash "$ROOT/scripts/workflow/wt-resume.sh") >/dev/null 2>&1; then
    bad "wt-work and wt-resume require a change ID"
  else
    ok "wt-work and wt-resume require a change ID"
  fi

  : > "$log"
  outside="$tmp/outside"
  mkdir -p "$outside"
  if (cd "$outside" && bash "$ROOT/scripts/workflow/pm-start.sh") >/dev/null 2>&1 \
    || [[ -s "$log" ]]; then
    bad "pm-start rejects execution outside a Git repository"
  else
    ok "pm-start rejects execution outside a Git repository"
  fi
fi

if run_section settings; then
  printf 'Provider-local worktree setup\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-settings.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  fakebin="$tmp/bin"
  mkdir -p "$fakebin"
  for executable in claude codex agy copilot; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/$executable"
    chmod +x "$fakebin/$executable"
  done
  export PATH="$fakebin:$PATH"

  prepare_settings_repo() {
    local repo="$1" name="$2" tracked_codex="${3:-false}"
    new_repo "$repo"
    git -C "$repo" switch -qc "feature/$name"
    mkdir -p "$repo/openspec/changes/$name"
    printf '# plan\n' > "$repo/openspec/changes/$name/proposal.md"
    if [[ "$tracked_codex" == true ]]; then
      mkdir -p "$repo/.codex"
      printf 'tracked-target\n' > "$repo/.codex/config.toml"
    fi
    git -C "$repo" add .
    git -C "$repo" commit -qm plan
    git -C "$repo" switch -q main
    mkdir -p "$repo/.claude" "$repo/.codex" "$repo/.gemini"
    printf 'env-source-secret\n' > "$repo/.env"
    printf 'claude-source-secret\n' > "$repo/.claude/settings.local.json"
    printf 'codex-source-secret\n' > "$repo/.codex/config.toml"
    printf 'legacy-gemini-secret\n' > "$repo/.gemini/settings.json"
  }

  claude_repo="$tmp/claude"
  prepare_settings_repo "$claude_repo" claude-settings
  (cd "$claude_repo" && bash "$ROOT/scripts/workflow/wt-work.sh" claude-settings --agent claude) >/dev/null 2>&1 || true
  claude_wt="$claude_repo/.worktrees/claude-settings"
  if cmp -s "$claude_repo/.env" "$claude_wt/.env" \
    && cmp -s "$claude_repo/.claude/settings.local.json" "$claude_wt/.claude/settings.local.json" \
    && [[ ! -e "$claude_wt/.codex/config.toml" && ! -e "$claude_wt/.gemini/settings.json" ]]; then
    ok "Claude receives only .env and Claude local settings"
  else
    bad "Claude receives only .env and Claude local settings"
  fi

  codex_repo="$tmp/codex"
  prepare_settings_repo "$codex_repo" codex-settings
  (cd "$codex_repo" && bash "$ROOT/scripts/workflow/wt-work.sh" codex-settings --agent codex) >/dev/null 2>&1 || true
  codex_wt="$codex_repo/.worktrees/codex-settings"
  if cmp -s "$codex_repo/.env" "$codex_wt/.env" \
    && cmp -s "$codex_repo/.codex/config.toml" "$codex_wt/.codex/config.toml" \
    && [[ ! -e "$codex_wt/.claude/settings.local.json" && ! -e "$codex_wt/.gemini/settings.json" ]]; then
    ok "Codex receives only .env and Codex local settings"
  else
    bad "Codex receives only .env and Codex local settings"
  fi

  tracked_repo="$tmp/tracked"
  prepare_settings_repo "$tracked_repo" tracked-settings true
  (cd "$tracked_repo" && bash "$ROOT/scripts/workflow/wt-work.sh" tracked-settings --agent codex) >/dev/null 2>&1 || true
  if [[ "$(git -C "$tracked_repo/.worktrees/tracked-settings" show HEAD:.codex/config.toml)" == tracked-target \
    && "$(tr -d '\n' < "$tracked_repo/.worktrees/tracked-settings/.codex/config.toml")" == tracked-target ]]; then
    ok "tracked target settings are never overwritten"
  else
    bad "tracked target settings are never overwritten"
  fi

  antigravity_repo="$tmp/antigravity"
  prepare_settings_repo "$antigravity_repo" antigravity-settings
  fake_home="$tmp/home"
  mkdir -p "$fake_home/.gemini/antigravity-cli"
  printf 'global-antigravity-secret\n' > "$fake_home/.gemini/antigravity-cli/settings.json"
  (cd "$antigravity_repo" && HOME="$fake_home" \
    bash "$ROOT/scripts/workflow/wt-work.sh" antigravity-settings --agent antigravity) >/dev/null 2>&1 || true
  antigravity_wt="$antigravity_repo/.worktrees/antigravity-settings"
  if cmp -s "$antigravity_repo/.env" "$antigravity_wt/.env" \
    && [[ ! -e "$antigravity_wt/.claude/settings.local.json" \
      && ! -e "$antigravity_wt/.codex/config.toml" \
      && ! -e "$antigravity_wt/.gemini/settings.json" \
      && ! -e "$antigravity_wt/.gemini/antigravity-cli/settings.json" \
      && ! -e "$antigravity_wt/.worktreeinclude" ]]; then
    ok "Antigravity receives .env without legacy or global settings"
  else
    bad "Antigravity receives .env without legacy or global settings"
  fi

  absent_repo="$tmp/absent"
  new_repo "$absent_repo"
  git -C "$absent_repo" switch -qc feature/absent-settings
  mkdir -p "$absent_repo/openspec/changes/absent-settings"
  printf '# plan\n' > "$absent_repo/openspec/changes/absent-settings/proposal.md"
  git -C "$absent_repo" add .
  git -C "$absent_repo" commit -qm plan
  git -C "$absent_repo" switch -q main
  if (cd "$absent_repo" && bash "$ROOT/scripts/workflow/wt-work.sh" absent-settings --agent claude) >/dev/null 2>&1 \
    && [[ ! -e "$absent_repo/.worktrees/absent-settings/.claude/settings.local.json" ]]; then
    ok "absent allowlisted settings do not block creation"
  else
    bad "absent allowlisted settings do not block creation"
  fi
fi

if run_section cleanup; then
  printf 'Project-managed cleanup ownership\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-cleanup.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT

  add_feature_commit() {
    local repo="$1" name="$2"
    git -C "$repo" switch -qc "feature/$name"
    printf '%s\n' "$name" > "$repo/$name.txt"
    git -C "$repo" add "$name.txt"
    git -C "$repo" commit -qm "$name"
    git -C "$repo" switch -q main
  }

  managed_repo="$tmp/managed"
  new_repo "$managed_repo"
  add_feature_commit "$managed_repo" managed-change
  managed_wt="$managed_repo/.worktrees/managed-change"
  git -C "$managed_repo" worktree add -q "$managed_wt" feature/managed-change
  if (cd "$managed_repo" && bash "$ROOT/scripts/workflow/wt-done.sh" managed-change) >/dev/null 2>&1 \
    && [[ ! -e "$managed_wt" ]] \
    && ! git -C "$managed_repo" show-ref --verify --quiet refs/heads/feature/managed-change; then
    ok "wt-done removes its Project-managed worktree and branch"
  else
    bad "wt-done removes its Project-managed worktree and branch"
  fi

  provider_repo="$tmp/provider"
  new_repo "$provider_repo"
  add_feature_commit "$provider_repo" provider-owned
  provider_wt="$tmp/provider-native-path"
  git -C "$provider_repo" worktree add -q "$provider_wt" feature/provider-owned
  if (cd "$provider_repo" && bash "$ROOT/scripts/workflow/wt-done.sh" provider-owned) >/dev/null 2>&1 \
    && [[ -d "$provider_wt" ]] \
    && git -C "$provider_repo" worktree list --porcelain | grep -Fq "worktree $(cd "$provider_wt" && pwd -P)" \
    && git -C "$provider_repo" show-ref --verify --quiet refs/heads/feature/provider-owned; then
    ok "wt-done preserves an attached Provider-native path and branch"
  else
    bad "wt-done preserves an attached Provider-native path and branch"
  fi

  conflict_repo="$tmp/conflict"
  new_repo "$conflict_repo"
  git -C "$conflict_repo" switch -qc feature/conflict-change
  printf 'feature\n' > "$conflict_repo/README.md"
  git -C "$conflict_repo" commit -qam feature
  git -C "$conflict_repo" switch -q main
  printf 'main\n' > "$conflict_repo/README.md"
  git -C "$conflict_repo" commit -qam main
  conflict_wt="$conflict_repo/.worktrees/conflict-change"
  git -C "$conflict_repo" worktree add -q "$conflict_wt" feature/conflict-change
  if (cd "$conflict_repo" && bash "$ROOT/scripts/workflow/wt-done.sh" conflict-change) >/dev/null 2>&1; then
    bad "merge conflict stops cleanup"
  elif [[ -d "$conflict_wt" ]] \
    && git -C "$conflict_repo" show-ref --verify --quiet refs/heads/feature/conflict-change; then
    ok "merge conflict stops cleanup"
  else
    bad "merge conflict preserves the worktree and branch"
  fi
fi

if run_section installer; then
  printf 'installer and zsh completion\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-installer.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  install_repo="$tmp/install-repo"
  new_repo "$install_repo"
  cp -R "$ROOT/scripts" "$install_repo/scripts"
  git -C "$install_repo" add scripts
  git -C "$install_repo" commit -qm scripts
  fake_home="$tmp/home"
  mkdir -p "$fake_home"

  if (cd "$install_repo" && HOME="$fake_home" SHELL=/bin/zsh bash scripts/workflow/install.sh) >/dev/null 2>&1 \
    && [[ -x "$fake_home/.local/bin/opsx-branch" \
      && -x "$fake_home/.local/bin/wk-workflow-runtime" ]]; then
    ok "installer deploys opsx-branch and the shared runtime"
  else
    bad "installer deploys opsx-branch and the shared runtime"
  fi

  first_sum="$(cksum "$fake_home/.local/bin/opsx-branch" "$fake_home/.local/bin/wk-workflow-runtime" 2>/dev/null || true)"
  (cd "$install_repo" && HOME="$fake_home" SHELL=/bin/zsh bash scripts/workflow/install.sh) >/dev/null 2>&1 || true
  second_sum="$(cksum "$fake_home/.local/bin/opsx-branch" "$fake_home/.local/bin/wk-workflow-runtime" 2>/dev/null || true)"
  marker_count="$(grep -c '# wk-agent-ops workflow helpers PATH' "$fake_home/.zshrc" 2>/dev/null || true)"
  if [[ "$first_sum" == "$second_sum" && "$marker_count" == 1 ]]; then
    ok "installer is idempotent across two runs"
  else
    bad "installer is idempotent across two runs"
  fi

  completion="$fake_home/.local/share/zsh/site-functions/_wt"
  if grep -Fq 'worktree list --porcelain' "$completion" \
    && grep -Fq 'for-each-ref' "$completion" \
    && grep -Fq '.worktrees/*' "$completion" \
    && grep -Fq 'worktree_paths' "$completion" \
    && grep -Fq -- '--path' "$completion" \
    && grep -Fq 'claude codex antigravity agy copilot' "$completion" \
    && ! grep -Fqi gemini "$completion" \
    && ! grep -Fq 'ls "$repo/.worktrees' "$completion"; then
    ok "completion uses the Git registry, --path, and current Providers"
  else
    bad "completion uses the Git registry, --path, and current Providers"
  fi

  if grep -Fq 'artifacts 前' "$install_repo/scripts/workflow/install.sh"; then
    ok "installer identifies opsx-branch as the pre-artifact transition"
  else
    bad "installer identifies opsx-branch as the pre-artifact transition"
  fi

  if grep -Fq '#compdef wt-work wt-done wt-resume pm-start opsx-branch' "$completion"; then
    ok "completion registers the final command matrix"
  else
    bad "completion registers the final command matrix"
  fi
fi

if run_section docs; then
  printf 'workflow documentation contracts\n'
  docs=(
    "$ROOT/README.md"
    "$ROOT/scripts/workflow/README.md"
    "$ROOT/docs/workflow/guide.md"
    "$ROOT/docs/workflow/provider-worktrees.md"
    "$ROOT/docs/workflow/wt-work-flow.md"
  )
  if ! grep -Ei '(--agent[[:space:]]+gemini|Gemini.*(supported|支援)|自動.*resume|尚未實作|現行.*尚未)' \
    "${docs[@]}" >/dev/null; then
    ok "docs do not advertise Gemini or old automatic-resume behavior"
  else
    bad "docs do not advertise Gemini or old automatic-resume behavior"
  fi

  links=(
    docs/workflow/guide.md
    docs/workflow/concepts.md
    docs/workflow/wt-work-flow.md
    docs/workflow/provider-worktrees.md
    docs/workflow/commit.md
    scripts/workflow/README.md
  )
  missing=""
  for link in "${links[@]}"; do
    [[ -e "$ROOT/$link" ]] || missing="$missing $link"
  done
  if [[ -z "$missing" ]]; then
    ok "updated workflow cross-references resolve"
  else
    bad "updated workflow cross-references resolve:$missing"
  fi
fi

printf '\n'
[[ $fail -eq 0 ]] && { echo PASS; exit 0; } || { echo FAIL; exit 1; }
