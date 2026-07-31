#!/usr/bin/env bash
# Shared Git worktree resolution for wt-work and wt-resume.

# The first porcelain record is Git's primary checkout, even when invoked from
# a linked worktree. Project-managed paths are always rooted there.
REPO="$(git -C "$REPO" worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }')"

workflow_worktrees() {
  git -C "$REPO" worktree list --porcelain | awk '
    function emit() {
      if (path != "") print path "\034" head "\034" branch "\034" detached
      path=head=branch=""; detached=0
    }
    /^worktree / { emit(); path=substr($0, 10); next }
    /^HEAD / { head=substr($0, 6); next }
    /^branch / { branch=substr($0, 8); next }
    /^detached$/ { detached=1; next }
    /^$/ { emit() }
    END { emit() }
  '
}

workflow_check_candidate() {
  local path="$1" branch="feature/$NAME"
  if [[ ! -d "$path/openspec/changes/$NAME" ]]; then
    echo "Error: active OpenSpec change not found in worktree: $path" >&2
    return 1
  fi
  if ! git -C "$REPO" show-ref --verify --quiet "refs/heads/$branch"; then
    echo "Error: planning branch not found: $branch" >&2
    return 1
  fi
  if ! git -C "$path" merge-base --is-ancestor "refs/heads/$branch" HEAD; then
    echo "Error: planning branch tip is not reachable from worktree HEAD: $path" >&2
    return 1
  fi
}

workflow_choose() {
  local label="$1"
  shift
  if (( $# == 1 )); then
    workflow_check_candidate "$1" || return 1
    printf '%s\n' "$1"
    return 0
  fi
  if (( $# > 1 )); then
    echo "Error: multiple $label worktrees match feature/$NAME; use --path:" >&2
    printf '  %s\n' "$@" >&2
    return 1
  fi
  return 2
}

# Prints the canonical registered path. Returns 2 when no candidate exists.
workflow_resolve_worktree() {
  local explicit_path="${1:-}" path head branch detached primary="" canonical=""
  local -a paths=() heads=() branches=() detached_flags=()

  while IFS=$'\034' read -r path head branch detached; do
    [[ -n "$path" ]] || continue
    [[ -n "$primary" ]] || primary="$path"
    paths+=("$path")
    heads+=("$head")
    branches+=("$branch")
    detached_flags+=("$detached")
  done < <(workflow_worktrees)

  if [[ -n "$explicit_path" ]]; then
    if [[ ! -d "$explicit_path" ]]; then
      echo "Error: --path does not exist: $explicit_path" >&2
      return 1
    fi
    canonical="$(cd "$explicit_path" && pwd -P)"
    for path in "${paths[@]}"; do
      if [[ "$path" == "$canonical" ]]; then
        workflow_check_candidate "$path" || return 1
        printf '%s\n' "$path"
        return 0
      fi
    done
    echo "Error: --path is not a registered worktree for this repository: $canonical" >&2
    return 1
  fi

  canonical="$REPO/.worktrees/$NAME"
  if [[ -d "$canonical" ]]; then
    canonical="$(cd "$canonical" && pwd -P)"
    for path in "${paths[@]}"; do
      if [[ "$path" == "$canonical" ]]; then
        workflow_check_candidate "$path" || return 1
        printf '%s\n' "$path"
        return 0
      fi
    done
  fi

  local -a candidates=()
  local i
  for i in "${!paths[@]}"; do
    [[ "${paths[$i]}" != "$primary" && "${branches[$i]}" == "refs/heads/feature/$NAME" ]] \
      && candidates+=("${paths[$i]}")
  done
  if (( ${#candidates[@]} )); then
    workflow_choose "named-branch" "${candidates[@]}"
    return $?
  fi

  candidates=()
  for i in "${!paths[@]}"; do
    if [[ "${paths[$i]}" != "$primary" && "${detached_flags[$i]}" == "1" \
      && -d "${paths[$i]}/openspec/changes/$NAME" ]] \
      && git -C "${paths[$i]}" merge-base --is-ancestor "refs/heads/feature/$NAME" HEAD 2>/dev/null; then
      candidates+=("${paths[$i]}")
    fi
  done
  if (( ${#candidates[@]} )); then
    workflow_choose "detached" "${candidates[@]}"
    return $?
  fi
  return 2
}

workflow_validate_provider() {
  [[ "$AGENT" == "agy" ]] && AGENT="antigravity"
  case "$AGENT" in
    claude|codex|antigravity|copilot) ;;
    *)
      echo "Error: --agent must be one of: claude, codex, antigravity, agy, copilot (got: $AGENT)" >&2
      return 1
      ;;
  esac
}

workflow_provider_executable() {
  case "$AGENT" in
    antigravity) printf 'agy\n' ;;
    *) printf '%s\n' "$AGENT" ;;
  esac
}

workflow_require_provider() {
  local executable
  executable="$(workflow_provider_executable)"
  if ! command -v "$executable" >/dev/null 2>&1; then
    echo "Error: Provider executable not found: $executable" >&2
    return 1
  fi
}

workflow_print_context() {
  local path="$1" branch head status
  branch="$(git -C "$path" branch --show-current)"
  head="$(git -C "$path" rev-parse --short HEAD)"
  status="$(git -C "$path" status --short)"
  echo "Worktree: $path"
  echo "State   : ${branch:-detached}"
  echo "HEAD    : $head"
  echo "Status  :"
  if [[ -n "$status" ]]; then printf '%s\n' "$status"; else echo "  clean"; fi
}

workflow_launch_apply() {
  local session="$1" intent="/openspec-apply-change $NAME"
  workflow_require_provider || return 1
  case "$AGENT" in
    claude)
      if [[ -n "$session" ]]; then
        claude --resume "$session" "$intent"
      else
        claude --name "RD: $NAME" "$intent"
      fi
      ;;
    codex)
      if [[ -n "$session" ]]; then codex resume "$session" "$intent"; else codex "$intent"; fi
      ;;
    antigravity)
      if [[ -n "$session" ]]; then
        agy --conversation "$session" --prompt-interactive "$intent"
      else
        agy --prompt-interactive "$intent"
      fi
      ;;
    copilot)
      if [[ -n "$session" ]]; then
        copilot --resume="$session" --allow-all -i "$intent"
      else
        copilot --allow-all -i "$intent"
      fi
      ;;
  esac
}

workflow_resume_session() {
  local session="$1"
  workflow_require_provider || return 1
  case "$AGENT" in
    claude)
      if [[ -n "$session" ]]; then claude --resume "$session"; else claude --resume; fi
      ;;
    codex)
      if [[ -n "$session" ]]; then codex resume "$session"; else codex resume; fi
      ;;
    antigravity)
      if [[ -n "$session" ]]; then agy --conversation "$session"; else agy --continue; fi
      ;;
    copilot)
      if [[ -n "$session" ]]; then copilot --resume="$session" --allow-all; else copilot --resume --allow-all; fi
      ;;
  esac
}
