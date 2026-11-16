#!/usr/bin/env bash
# Offline contract tests for the opsx-branch workflow command, hook, and installer.
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

  compat_repo="$tmp/compat-repo"
  new_repo "$compat_repo"
  compat_repo="$(cd "$compat_repo" && pwd -P)"
  hook_stub="$tmp/opsx-branch-stub"
  hook_log="$tmp/hook.log"
  printf '#!/usr/bin/env bash\nprintf "%%s|%%s\\n" "$PWD" "$*" >> "$HOOK_LOG"\nexit "${HOOK_EXIT:-0}"\n' > "$hook_stub"
  chmod +x "$hook_stub"

  codex_input="{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$compat_repo\",\"tool_input\":{\"command\":\"openspec new change codex-feature\"},\"tool_response\":{\"exit_code\":0}}"
  if output="$(printf '%s' "$codex_input" | (cd "$compat_repo" && HOOK_LOG="$hook_log" OPSX_BRANCH_BIN="$hook_stub" \
    bash "$ROOT/scripts/workflow/openspec-branch-creator/hook.sh") 2>&1)" \
    && grep -Fxq "$compat_repo|codex-feature" "$hook_log"; then
    ok "hook delegates Claude/Codex payloads to opsx-branch"
  else
    bad "hook delegates Claude/Codex payloads to opsx-branch"
    printf '       %s\n' "$output"
  fi

  : > "$hook_log"
  copilot_input="{\"cwd\":\"$compat_repo\",\"toolName\":\"bash\",\"toolArgs\":\"{\\\"command\\\":\\\"openspec new change copilot-feature\\\"}\",\"toolResult\":{\"resultType\":\"success\"}}"
  if output="$(printf '%s' "$copilot_input" | (cd "$compat_repo" && HOOK_LOG="$hook_log" OPSX_BRANCH_BIN="$hook_stub" \
    bash "$ROOT/scripts/workflow/openspec-branch-creator/hook.sh") 2>&1)" \
    && grep -Fxq "$compat_repo|copilot-feature" "$hook_log"; then
    ok "hook normalizes Copilot camelCase payloads"
  else
    bad "hook normalizes Copilot camelCase payloads"
    printf '       %s\n' "$output"
  fi

  : > "$hook_log"
  failed_input="{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$compat_repo\",\"tool_input\":{\"command\":\"openspec new change failed-feature\"},\"tool_response\":{\"exit_code\":1}}"
  if output="$(printf '%s' "$failed_input" | (cd "$compat_repo" && CLAUDE_PROJECT_DIR="$compat_repo" HOOK_LOG="$hook_log" OPSX_BRANCH_BIN="$hook_stub" \
    bash "$ROOT/scripts/workflow/openspec-branch-creator/hook.sh") 2>&1)" \
    && [[ ! -s "$hook_log" ]] \
    && ! git -C "$compat_repo" show-ref --verify --quiet refs/heads/feature/failed-feature; then
    ok "hook ignores explicit Codex command failure"
  else
    bad "hook ignores explicit Codex command failure"
    printf '       %s\n' "$output"
  fi

  : > "$hook_log"
  delegated_failure="{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$compat_repo\",\"tool_input\":{\"command\":\"openspec new change occupied-feature\"},\"tool_response\":{\"exit_code\":0}}"
  if output="$(printf '%s' "$delegated_failure" | (cd "$compat_repo" && HOOK_LOG="$hook_log" HOOK_EXIT=1 OPSX_BRANCH_BIN="$hook_stub" \
    bash "$ROOT/scripts/workflow/openspec-branch-creator/hook.sh") 2>&1)" \
    && grep -Fxq "$compat_repo|occupied-feature" "$hook_log" \
    && [[ "$output" == *"warning"* ]]; then
    ok "delegated branch failure remains fail-soft"
  else
    bad "delegated branch failure remains fail-soft"
    printf '       %s\n' "$output"
  fi
fi

if run_section installer; then
  printf 'installer and branch hooks\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-installer.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  install_repo="$tmp/install-repo"
  new_repo "$install_repo"
  cp -R "$ROOT/scripts" "$install_repo/scripts"
  git -C "$install_repo" add scripts
  git -C "$install_repo" commit -qm scripts
  fake_home="$tmp/home"
  legacy_entropy_hook="$fake_home/.config/wk-workflow/hooks/entropy-counter.sh"
  legacy_entropy_cmd="bash \"$legacy_entropy_hook\""
  unrelated_hook='bash "/tmp/keep-hook.sh"'
  mkdir -p "$fake_home/.claude" "$fake_home/.gemini" \
    "$(dirname "$legacy_entropy_hook")" "$install_repo/.github/hooks"
  touch "$legacy_entropy_hook" "$install_repo/.github/hooks/entropy-counter.json"
  jq -n --arg legacy "$legacy_entropy_cmd" --arg keep "$unrelated_hook" \
    '{hooks:{PostToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$legacy,timeout:10}]},{matcher:"Bash",hooks:[{type:"command",command:$keep,timeout:10}]}]}}' \
    > "$fake_home/.claude/settings.json"
  jq -n --arg legacy "$legacy_entropy_cmd" --arg keep "$unrelated_hook" \
    '{hooks:{AfterTool:[{matcher:"bash",hooks:[{type:"command",command:$legacy,timeout:10}]},{matcher:"bash",hooks:[{type:"command",command:$keep,timeout:10}]}]}}' \
    > "$fake_home/.gemini/settings.json"

  if (cd "$install_repo" && HOME="$fake_home" SHELL=/bin/zsh bash scripts/workflow/install.sh) >/dev/null 2>&1 \
    && [[ -x "$fake_home/.local/bin/opsx-branch" \
      && -f "$fake_home/.local/share/zsh/site-functions/_opsx-branch" ]]; then
    ok "installer deploys opsx-branch and its completion"
  else
    bad "installer deploys opsx-branch and its completion"
  fi

  first_sum="$(cksum "$fake_home/.local/bin/opsx-branch" "$fake_home/.local/share/zsh/site-functions/_opsx-branch" 2>/dev/null || true)"
  (cd "$install_repo" && HOME="$fake_home" SHELL=/bin/zsh bash scripts/workflow/install.sh) >/dev/null 2>&1 || true
  second_sum="$(cksum "$fake_home/.local/bin/opsx-branch" "$fake_home/.local/share/zsh/site-functions/_opsx-branch" 2>/dev/null || true)"
  marker_count="$(grep -c '# wk-agent-ops workflow helpers PATH' "$fake_home/.zshrc" 2>/dev/null || true)"
  if [[ "$first_sum" == "$second_sum" && "$marker_count" == 1 ]]; then
    ok "installer is idempotent across two runs"
  else
    bad "installer is idempotent across two runs"
  fi

  if grep -Fq 'artifacts 前' "$install_repo/scripts/workflow/install.sh"; then
    ok "installer identifies opsx-branch as the pre-artifact transition"
  else
    bad "installer identifies opsx-branch as the pre-artifact transition"
  fi

  hook_cmd="bash \"$fake_home/.config/wk-workflow/hooks/openspec-branch-creator.sh\""
  claude_count="$(jq --arg cmd "$hook_cmd" '[.hooks.PostToolUse[]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.claude/settings.json" 2>/dev/null || printf 0)"
  codex_count="$(jq --arg cmd "$hook_cmd" '[.hooks.PostToolUse[]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.codex/hooks.json" 2>/dev/null || printf 0)"
  gemini_count="$(jq --arg cmd "$hook_cmd" '[.hooks.AfterTool[]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.gemini/settings.json" 2>/dev/null || printf 0)"
  if [[ "$claude_count" == 1 && "$codex_count" == 1 \
    && -f "$install_repo/.github/hooks/openspec-branch-creator.json" \
    && "$gemini_count" == 0 && ! -e "$fake_home/.agent/hooks" ]]; then
    ok "installer registers Claude, Codex, and Copilot without an Antigravity hook"
  else
    bad "installer registers Claude, Codex, and Copilot without an Antigravity hook"
  fi

  legacy_claude_count="$(jq --arg cmd "$legacy_entropy_cmd" '[.hooks.PostToolUse[]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.claude/settings.json")"
  legacy_gemini_count="$(jq --arg cmd "$legacy_entropy_cmd" '[.hooks.AfterTool[]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.gemini/settings.json")"
  unrelated_count="$(jq --arg cmd "$unrelated_hook" '[.hooks[][]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.claude/settings.json" "$fake_home/.gemini/settings.json" | awk '{ total += $1 } END { print total + 0 }')"
  if [[ "$legacy_claude_count" == 0 && "$legacy_gemini_count" == 0 \
    && "$unrelated_count" == 2 \
    && ! -e "$legacy_entropy_hook" \
    && ! -e "$install_repo/.github/hooks/entropy-counter.json" ]]; then
    ok "installer removes legacy entropy hooks without changing unrelated hooks"
  else
    bad "installer removes legacy entropy hooks without changing unrelated hooks"
  fi

  migrated_home="$tmp/migrated-home"
  migrated_hook="$migrated_home/.config/wk-workflow/hooks/openspec-branch-creator.sh"
  migrated_cmd="bash \"$migrated_hook\""
  mkdir -p "$migrated_home/.codex"
  jq -n --arg cmd "$migrated_cmd" '{hooks:{PostToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$cmd,timeout:10}]}]}}' \
    > "$migrated_home/.codex/hooks.json"
  (cd "$install_repo" && HOME="$migrated_home" bash scripts/workflow/openspec-branch-creator/install.sh) >/dev/null 2>&1 || true
  migrated_count="$(jq --arg cmd "$migrated_cmd" '[.hooks.PostToolUse[]?.hooks[]? | select(.command == $cmd)] | length' "$migrated_home/.codex/hooks.json")"
  if [[ "$migrated_count" == 1 ]]; then
    ok "installer preserves one migrated Codex registration"
  else
    bad "installer preserves one migrated Codex registration"
  fi

  mkdir -p "$fake_home/.codex"
  if [[ ! -f "$fake_home/.codex/hooks.json" ]]; then
    jq -n --arg cmd "$hook_cmd" '{hooks:{PostToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$cmd,timeout:10}]}]}}' \
      > "$fake_home/.codex/hooks.json"
  fi
  (cd "$install_repo" && HOME="$fake_home" bash scripts/workflow/openspec-branch-creator/uninstall.sh) >/dev/null 2>&1 || true
  remaining_codex="$(jq --arg cmd "$hook_cmd" '[.hooks.PostToolUse[]?.hooks[]? | select(.command == $cmd)] | length' "$fake_home/.codex/hooks.json" 2>/dev/null || printf 0)"
  if [[ "$remaining_codex" == 0 && ! -e "$install_repo/.github/hooks/openspec-branch-creator.json" ]]; then
    ok "uninstaller removes Codex and Copilot registrations"
  else
    bad "uninstaller removes Codex and Copilot registrations"
  fi
fi

if run_section retire; then
  printf 'legacy helper retirement\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-retire.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  fixtures="$ROOT/tests/fixtures/workflow-legacy"
  retire_repo="$tmp/repo"
  new_repo "$retire_repo"
  cp -R "$ROOT/scripts" "$retire_repo/scripts"
  git -C "$retire_repo" add scripts
  git -C "$retire_repo" commit -qm scripts
  retired_cmds=(wt-work wt-resume wt-done pm-start wk-workflow-runtime wt-new)

  run_install() {
    (cd "$retire_repo" && HOME="$1" SHELL=/bin/zsh bash scripts/workflow/install.sh 2>&1)
  }
  seed_work_data() {
    mkdir -p "$1/.local/bin" "$1/.config/wk-workflow" "$1/work/.worktrees/keep"
    printf 'custom\n' > "$1/.local/bin/my-tool"
    printf 'token=keep\n' > "$1/.config/wk-workflow/settings"
    printf 'export PATH="$PATH:/opt/keep"\n' > "$1/.zshrc"
  }
  work_data_intact() {
    [[ "$(cat "$1/.local/bin/my-tool")" == custom \
      && "$(cat "$1/.config/wk-workflow/settings")" == token=keep \
      && -d "$1/work/.worktrees/keep" ]] \
      && grep -Fq '/opt/keep' "$1/.zshrc"
  }

  fresh_home="$tmp/fresh"
  mkdir -p "$fresh_home"
  if output="$(run_install "$fresh_home")" \
    && [[ -x "$fresh_home/.local/bin/opsx-branch" \
      && -f "$fresh_home/.local/share/zsh/site-functions/_opsx-branch" \
      && ! -e "$fresh_home/.local/share/zsh/site-functions/_wt" ]] \
    && ! ls "$fresh_home/.local/bin" | grep -Exq 'wt-work|wt-resume|wt-done|pm-start|wk-workflow-runtime|wt-new'; then
    ok "fresh install deploys only opsx-branch and its completion"
  else
    bad "fresh install deploys only opsx-branch and its completion"
    printf '       %s\n' "$output"
  fi

  upgrade_home="$tmp/upgrade"
  seed_work_data "$upgrade_home"
  mkdir -p "$upgrade_home/.local/share/zsh/site-functions"
  for cmd in "${retired_cmds[@]}"; do
    cp "$fixtures/$cmd" "$upgrade_home/.local/bin/$cmd"
  done
  cp "$fixtures/_wt" "$upgrade_home/.local/share/zsh/site-functions/_wt"
  output="$(run_install "$upgrade_home")" || true
  left=""
  for cmd in "${retired_cmds[@]}"; do
    [[ -e "$upgrade_home/.local/bin/$cmd" ]] && left="$left $cmd"
  done
  [[ -e "$upgrade_home/.local/share/zsh/site-functions/_wt" ]] && left="$left _wt"
  if [[ -z "$left" ]] && grep -Fq 'Removed legacy' <<<"$output" \
    && grep -Fq 'wt-work' <<<"$output"; then
    ok "upgrade removes and reports recognized legacy copies"
  else
    bad "upgrade removes and reports recognized legacy copies:$left"
  fi
  if work_data_intact "$upgrade_home"; then
    ok "upgrade leaves work data and unrelated files untouched"
  else
    bad "upgrade leaves work data and unrelated files untouched"
  fi

  if output="$(run_install "$upgrade_home")" \
    && [[ -x "$upgrade_home/.local/bin/opsx-branch" ]] \
    && [[ "$(grep -c '# wk-agent-ops workflow helpers PATH' "$upgrade_home/.zshrc")" == 1 ]] \
    && work_data_intact "$upgrade_home"; then
    ok "repeat install after upgrade is idempotent"
  else
    bad "repeat install after upgrade is idempotent"
    printf '       %s\n' "$output"
  fi

  custom_home="$tmp/custom"
  seed_work_data "$custom_home"
  bin="$custom_home/.local/bin"
  site="$custom_home/.local/share/zsh/site-functions"
  mkdir -p "$site" "$custom_home/elsewhere"
  { cat "$fixtures/wt-work"; printf '# local edit\n'; } > "$bin/wt-work"
  printf '#!/bin/sh\necho mine\n' > "$bin/wt-new"
  printf '#!/bin/sh\necho mine\n' > "$bin/wt-resume"
  cp "$fixtures/wt-done" "$custom_home/elsewhere/wt-done"
  ln -s "$custom_home/elsewhere/wt-done" "$bin/wt-done"
  ln -s "$custom_home/missing-target" "$bin/pm-start"
  { cat "$fixtures/_wt"; printf '# local edit\n'; } > "$site/_wt"
  before="$(cksum "$bin/wt-work" "$bin/wt-new" "$bin/wt-resume" "$site/_wt" "$custom_home/elsewhere/wt-done")"
  output="$(run_install "$custom_home")" || true
  after="$(cksum "$bin/wt-work" "$bin/wt-new" "$bin/wt-resume" "$site/_wt" "$custom_home/elsewhere/wt-done" 2>/dev/null)"
  if [[ "$before" == "$after" && -L "$bin/wt-done" && -L "$bin/pm-start" \
    && "$(readlink "$bin/pm-start")" == "$custom_home/missing-target" ]]; then
    ok "modified, unknown, and symlinked legacy entries are preserved"
  else
    bad "modified, unknown, and symlinked legacy entries are preserved"
  fi
  missing_report=""
  for entry in "$bin/wt-work" "$bin/wt-new" "$bin/wt-resume" "$bin/wt-done" "$bin/pm-start" "$site/_wt"; do
    grep -Fq "$entry" <<<"$output" || missing_report="$missing_report ${entry##*/}"
  done
  if [[ -z "$missing_report" ]] && grep -Fq 'manual cleanup' <<<"$output" \
    && work_data_intact "$custom_home"; then
    ok "preserved legacy entries are reported for manual cleanup"
  else
    bad "preserved legacy entries are reported for manual cleanup:$missing_report"
    printf '       %s\n' "$output"
  fi
fi

if run_section completion; then
  printf 'opsx-branch zsh completion\n'
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wk-workflow-completion.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  site="$tmp/site"
  mkdir -p "$site"
  cp "$ROOT/scripts/workflow/_opsx-branch" "$site/" 2>/dev/null || true

  comps="$(zsh -fc 'fpath=("$1" ${^fpath}/compinit(N:h)); autoload -Uz compinit; compinit -u -d "$2/zcompdump"
    for c in opsx-branch wt-work wt-resume wt-done pm-start; do print -r -- "$c=${_comps[$c]-}"; done' _ "$site" "$tmp" 2>&1)"
  if [[ "$comps" == *"opsx-branch=_opsx-branch"* ]] \
    && ! grep -Eq '^(wt-work|wt-resume|wt-done|pm-start)=.+' <<<"$comps"; then
    ok "completion registers only opsx-branch"
  else
    bad "completion registers only opsx-branch"
    printf '       %s\n' "$comps"
  fi

  complete_in() {
    (cd "$1" && zsh -fc 'fpath=("$1" $fpath); _arguments() { print -r -- "$@"; }
      autoload -Uz _opsx-branch; _opsx-branch' _ "$site")
  }
  repo="$tmp/repo"
  new_repo "$repo"
  git -C "$repo" branch feature/alpha
  git -C "$repo" branch feature/beta
  git -C "$repo" branch other/skip
  git -C "$repo" worktree add -q -b feature/gamma "$tmp/gamma"
  candidates="$(complete_in "$repo" 2>&1)"
  if [[ "$candidates" == *'1:change ID:(alpha beta gamma)'* ]]; then
    ok "completion suggests each local feature ID once"
  else
    bad "completion suggests each local feature ID once"
    printf '       %s\n' "$candidates"
  fi
  if ! grep -Eq -- '--(agent|session|path|base)|claude|codex|wt-' "$site/_opsx-branch" 2>/dev/null \
    && [[ -f "$site/_opsx-branch" ]]; then
    ok "completion offers no retired commands or options"
  else
    bad "completion offers no retired commands or options"
  fi

  mkdir -p "$tmp/norepo"
  if candidates="$(GIT_CEILING_DIRECTORIES="$tmp" complete_in "$tmp/norepo" 2>&1)" \
    && [[ "$candidates" == '1:change ID:()' ]]; then
    ok "completion is silent outside a repository"
  else
    bad "completion is silent outside a repository"
    printf '       %s\n' "$candidates"
  fi
fi

if run_section docs; then
  printf 'workflow documentation contracts\n'
  docs=(
    "$ROOT/README.md"
    "$ROOT/scripts/workflow/README.md"
    "$ROOT/docs/README.md"
    "$ROOT/docs/architecture.md"
    "$ROOT/docs/diagrams/README.md"
    "$ROOT/docs/diagrams/development-lifecycle.svg"
    "$ROOT/docs/workflow/guide.md"
    "$ROOT/docs/workflow/concepts.md"
    "$ROOT/docs/workflow/commit.md"
    "$ROOT/docs/workflow/provider-worktrees.md"
    "$ROOT/template/common/skills/openspec-commit/SKILL.md"
  )
  if ! grep -Ei '(--agent[[:space:]]+gemini|Gemini.*(supported|支援)|自動.*resume|尚未實作|現行.*尚未)' \
    "${docs[@]:0:2}" "$ROOT/docs/workflow/guide.md" "$ROOT/docs/workflow/provider-worktrees.md" >/dev/null; then
    ok "docs do not advertise Gemini or old automatic-resume behavior"
  else
    bad "docs do not advertise Gemini or old automatic-resume behavior"
  fi

  if ! grep -En '(wt-work|wt-resume|wt-done|pm-start)( <| \[|[[:space:]]+[a-z0-9-]+[[:space:]]+--| →)|wt-work-flow\.md|wt-work-resolution\.svg|scripts/workflow/(runtime|wt-work|wt-done|wt-resume|pm-start)\.sh' \
    "${docs[@]}"; then
    ok "current docs give no retired-command steps or links"
  else
    bad "current docs give no retired-command steps or links"
  fi

  links=(
    docs/workflow/guide.md
    docs/workflow/concepts.md
    docs/workflow/provider-worktrees.md
    docs/workflow/commit.md
    docs/workflow/local-development.md
    scripts/workflow/README.md
  )
  missing=""
  for link in "${links[@]}"; do
    [[ -e "$ROOT/$link" ]] || missing="$missing $link"
  done
  for gone in docs/workflow/wt-work-flow.md docs/diagrams/wt-work-resolution.svg scripts/workflow/_wt; do
    [[ -e "$ROOT/$gone" ]] && missing="$missing still-present:$gone"
  done
  if [[ -z "$missing" ]]; then
    ok "updated workflow cross-references resolve"
  else
    bad "updated workflow cross-references resolve:$missing"
  fi
fi

printf '\n'
[[ $fail -eq 0 ]] && { echo PASS; exit 0; } || { echo FAIL; exit 1; }
