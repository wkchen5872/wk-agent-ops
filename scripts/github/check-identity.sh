#!/usr/bin/env bash
# check-identity.sh — read-only identity preflight for GitHub handoff writes.
# Managed by wk-agent-ops · do not edit here — re-running install.sh overwrites this file.
#
# Compares the identity that a write would actually use with the expected
# identity for ONE operation, then prints key=value evidence and exits:
#   0 pass · 2 mismatch · 3 unverified · 1 error
# Only pass lets an already authorized write continue. The script never stages,
# commits, pushes, logs in, switches accounts, edits configuration or prints a
# credential. Contract and usage: docs/github-handoff.md.
set -euo pipefail

REL='scripts/github/check-identity.sh'

usage() {
  cat <<'EOF'
Usage: check-identity.sh --operation api|commit|push --policy-source <full-commit|user-input>
                         [--script-blob <blob-id>] <expected values>

  api     --host H --repo OWNER/REPO --api-actor LOGIN
  commit  --author-name N --author-email E --committer-name N --committer-email E
  push    --host H --repo OWNER/REPO --remote NAME --protocol ssh|https
          --push-actor LOGIN [--ref BRANCH]

Project root: $CLAUDE_PROJECT_DIR, otherwise the current directory.
Script source: the blob at <policy-source>:scripts/github/check-identity.sh,
or --script-blob for an explicitly trusted snapshot (required with user-input).
Exit: 0 pass, 2 mismatch, 3 unverified, 1 error.
EOF
}

OPERATION="" POLICY_SOURCE="" SCRIPT_BLOB="" HOST="" REPO="" API_ACTOR=""
AUTHOR_NAME="" AUTHOR_EMAIL="" COMMITTER_NAME="" COMMITTER_EMAIL=""
REMOTE="" PROTOCOL="" PUSH_ACTOR="" REF=""
EVIDENCE=()
FINISHED=0
OWN_TMP=""
ORIG_ARGS=("$@")

add() { EVIDENCE+=("$1=$2"); }

finish() {                         # $1 = status, $2 = reason (non-pass)
  local line
  FINISHED=1
  printf 'operation=%s\n' "${OPERATION:-unknown}"
  printf 'status=%s\n' "$1"
  if [[ -n "${2:-}" ]]; then printf 'reason=%s\n' "$2"; fi
  if [[ -n "$POLICY_SOURCE" ]]; then printf 'policy_source=%s\n' "$POLICY_SOURCE"; fi
  for line in "${EVIDENCE[@]+"${EVIDENCE[@]}"}"; do printf '%s\n' "$line"; done
  case "$1" in
    pass) exit 0 ;;
    mismatch) exit 2 ;;
    unverified) exit 3 ;;
    *) exit 1 ;;
  esac
}

on_exit() {
  local rc=$?
  if [[ -n "$OWN_TMP" ]]; then rm -rf "$OWN_TMP"; fi
  if [[ "$FINISHED" != 1 ]]; then
    printf 'operation=%s\nstatus=error\nreason=unexpected-failure\n' "${OPERATION:-unknown}"
    exit 1
  fi
  exit "$rc"
}
trap on_exit EXIT

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
same()  { [[ "$(lower "$1")" == "$(lower "$2")" ]]; }
is_full_commit() { [[ "$1" =~ ^[0-9a-f]{40}$ || "$1" =~ ^[0-9a-f]{64}$ ]]; }

# ── arguments ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) FINISHED=1; usage; exit 0 ;;
  esac
  if [[ $# -lt 2 || "$2" == *$'\n'* ]]; then finish error missing-argument; fi
  case "$1" in
    --operation)       OPERATION="$2" ;;
    --policy-source)   POLICY_SOURCE="$2" ;;
    --script-blob)     SCRIPT_BLOB="$2" ;;
    --host)            HOST="$2" ;;
    --repo)            REPO="$2" ;;
    --api-actor)       API_ACTOR="$2" ;;
    --author-name)     AUTHOR_NAME="$2" ;;
    --author-email)    AUTHOR_EMAIL="$2" ;;
    --committer-name)  COMMITTER_NAME="$2" ;;
    --committer-email) COMMITTER_EMAIL="$2" ;;
    --remote)          REMOTE="$2" ;;
    --protocol)        PROTOCOL="$2" ;;
    --push-actor)      PUSH_ACTOR="$2" ;;
    --ref)             REF="$2" ;;
    *) finish error unknown-argument ;;
  esac
  shift 2
done

require() {                        # every named variable must be non-empty
  local name
  for name in "$@"; do
    if [[ -z "${!name}" ]]; then finish error missing-argument; fi
  done
}
case "$OPERATION" in
  api)    require POLICY_SOURCE HOST REPO API_ACTOR ;;
  commit) require POLICY_SOURCE AUTHOR_NAME AUTHOR_EMAIL COMMITTER_NAME COMMITTER_EMAIL ;;
  push)   require POLICY_SOURCE HOST REPO REMOTE PROTOCOL PUSH_ACTOR
          case "$PROTOCOL" in ssh|https) ;; *) finish error invalid-protocol ;; esac ;;
  *) OPERATION="${OPERATION:-unknown}"; finish error unknown-operation ;;
esac
if [[ -n "$HOST" && ! "$HOST" =~ ^[A-Za-z0-9.-]+$ ]]; then finish error invalid-host; fi
if [[ -n "$REPO" && ! "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then finish error invalid-repository; fi
if [[ "$POLICY_SOURCE" == user-input ]]; then
  require SCRIPT_BLOB
elif ! is_full_commit "$POLICY_SOURCE"; then
  finish error policy-source-not-full-commit
fi

# ── project root ─────────────────────────────────────────────────────────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
TOP="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null)" || finish error not-a-git-work-tree

# ── script source: run only content the caller already trusts ────────────────
SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$SELF" || ! -f "$SELF" ]]; then finish unverified script-source-unknown; fi
SELF_BLOB="$(git hash-object --no-filters -- "$(cd "$(dirname "$SELF")" && pwd -P)/$(basename "$SELF")" 2>/dev/null)" \
  || finish unverified script-source-unknown

if [[ -n "$SCRIPT_BLOB" ]]; then
  same "$SELF_BLOB" "$SCRIPT_BLOB" || finish unverified script-blob-mismatch
  add script_source pinned-blob
  add script_blob "$SELF_BLOB"
else
  git -C "$TOP" cat-file -e "${POLICY_SOURCE}^{commit}" 2>/dev/null || finish unverified policy-source-unavailable
  TREE_ENTRY="$(git -C "$TOP" ls-tree "$POLICY_SOURCE" -- "$REL" 2>/dev/null)" || finish unverified policy-source-unavailable
  if [[ -z "$TREE_ENTRY" ]]; then finish unverified bootstrap-no-trusted-script; fi
  read -r TREE_MODE TREE_TYPE TREE_BLOB _ <<< "$TREE_ENTRY"
  if [[ "$TREE_TYPE" != blob || ( "$TREE_MODE" != 100755 && "$TREE_MODE" != 100644 ) ]]; then
    finish unverified trusted-script-not-regular-file
  fi
  if [[ "$SELF_BLOB" != "$TREE_BLOB" ]]; then
    # This copy is not the trusted content. Run the trusted blob from a private
    # directory outside the checkout; cwd and CLAUDE_PROJECT_DIR stay on the target.
    OWN_TMP="$(mktemp -d)"
    git -C "$TOP" cat-file blob "$TREE_BLOB" > "$OWN_TMP/check-identity.sh" 2>/dev/null \
      || finish unverified trusted-script-unavailable
    if [[ "$(git hash-object --no-filters -- "$OWN_TMP/check-identity.sh")" != "$TREE_BLOB" ]]; then
      finish unverified trusted-script-fingerprint-mismatch
    fi
    rc=0
    bash "$OWN_TMP/check-identity.sh" "${ORIG_ARGS[@]}" || rc=$?
    FINISHED=1
    exit "$rc"
  fi
  add script_source "$REL@$POLICY_SOURCE"
  add script_blob "$TREE_BLOB"
fi

# ── gh context (shared by api and the HTTPS push route) ──────────────────────
note_gh_context() {
  local name names="" version
  version="$(gh --version 2>/dev/null | awk 'NR==1{print $3}')" || true
  add gh_version "${version:-unknown}"
  # A token in the environment overrides stored gh authentication. Names only.
  for name in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN; do
    if [[ -n "${!name:-}" ]]; then names="${names:+$names,}$name"; fi
  done
  add gh_env_token "${names:-none}"
}

gh_login() { gh api --hostname "$1" user --jq .login 2>/dev/null; }

# ── api ──────────────────────────────────────────────────────────────────────
check_api() {
  local actual full
  add target "$HOST/$REPO"
  add expected_api_actor "$API_ACTOR"
  command -v gh >/dev/null 2>&1 || finish unverified gh-missing
  note_gh_context
  actual="$(gh_login "$HOST")" || finish unverified api-actor-unavailable
  actual="${actual%%$'\n'*}"
  if [[ -z "$actual" ]]; then finish unverified api-actor-unavailable; fi
  add actual_api_actor "$actual"
  same "$actual" "$API_ACTOR" || finish mismatch api-actor-mismatch
  full="$(gh api --hostname "$HOST" "repos/$REPO" --jq .full_name 2>/dev/null)" \
    || finish unverified repository-unavailable
  full="${full%%$'\n'*}"
  add actual_repository "$full"
  same "$full" "$REPO" || finish mismatch repository-mismatch
  finish pass
}

# ── commit ───────────────────────────────────────────────────────────────────
ident_of() {                       # AUTHOR|COMMITTER -> "Name <email>" as Git would record it
  local raw
  raw="$(git -C "$TOP" var "GIT_$1_IDENT" 2>/dev/null)" || return 1
  printf '%s>\n' "${raw%>*}"
}
ident_source() {
  local n="GIT_$1_NAME" e="GIT_$1_EMAIL" scope
  if [[ -n "${!n:-}" || -n "${!e:-}" ]]; then echo env; return 0; fi
  scope="$(git -C "$TOP" config --show-scope --get user.email 2>/dev/null | awk 'NR==1{print $1}')" || true
  echo "config:${scope:-unset}"
}
check_commit() {
  local exp_a="$AUTHOR_NAME <$AUTHOR_EMAIL>" exp_c="$COMMITTER_NAME <$COMMITTER_EMAIL>" act_a act_c
  add expected_author "$exp_a"
  add expected_committer "$exp_c"
  act_a="$(ident_of AUTHOR)" || finish unverified author-unavailable
  act_c="$(ident_of COMMITTER)" || finish unverified committer-unavailable
  add actual_author "$act_a"
  add author_source "$(ident_source AUTHOR)"
  add actual_committer "$act_c"
  add committer_source "$(ident_source COMMITTER)"
  [[ "$act_a" == "$exp_a" ]] || finish mismatch author-mismatch
  [[ "$act_c" == "$exp_c" ]] || finish mismatch committer-mismatch
  finish pass
}

# ── push ─────────────────────────────────────────────────────────────────────
URL_SCHEME="" URL_USERINFO="" URL_HOST="" URL_PORT="" URL_PATH=""
parse_push_url() {                 # sets URL_*; returns 1 for a route this version cannot attribute
  local url="$1" rest authority pre
  case "$url" in
    https://*) URL_SCHEME=https; rest="${url#https://}" ;;
    ssh://*)   URL_SCHEME=ssh;   rest="${url#ssh://}" ;;
    *://*)     return 1 ;;
    *:*)       # scp-like [user@]host:path
      pre="${url%%:*}"; URL_PATH="${url#*:}"
      if [[ "$pre" == */* || -z "$URL_PATH" ]]; then return 1; fi
      URL_SCHEME=ssh
      if [[ "$pre" == *@* ]]; then URL_USERINFO="${pre%@*}"; URL_HOST="${pre##*@}"; else URL_HOST="$pre"; fi
      rest="" ;;
    *) return 1 ;;
  esac
  if [[ -n "$rest" ]]; then
    if [[ "$rest" != */* ]]; then return 1; fi
    authority="${rest%%/*}"; URL_PATH="${rest#*/}"
    if [[ "$authority" == *@* ]]; then URL_USERINFO="${authority%@*}"; authority="${authority##*@}"; fi
    if [[ "$authority" == *:* ]]; then URL_PORT="${authority##*:}"; URL_HOST="${authority%%:*}"; else URL_HOST="$authority"; fi
  fi
  URL_PATH="${URL_PATH#/}"; URL_PATH="${URL_PATH%/}"; URL_PATH="${URL_PATH%.git}"
  [[ -n "$URL_HOST" && -n "$URL_PATH" ]]
}

check_push_ssh() {
  local dest cfg real_host out rc=0 login
  local pargs=()
  if [[ "$URL_USERINFO" == *:* ]]; then finish unverified url-embedded-credential; fi
  # ponytail: any custom SSH command blocks. Reproducing Git's exact key selection
  # from an arbitrary command string is not safe; upgrade path is a whitelist of
  # plain `ssh -i/-F/-o` forms replayed verbatim.
  if [[ -n "${GIT_SSH_COMMAND:-}" || -n "${GIT_SSH:-}" ]] \
    || git -C "$TOP" config --get core.sshCommand >/dev/null 2>&1; then
    finish unverified custom-ssh-command
  fi
  command -v ssh >/dev/null 2>&1 || finish unverified ssh-missing
  dest="${URL_USERINFO:+$URL_USERINFO@}$URL_HOST"
  if [[ -n "$URL_PORT" ]]; then pargs=(-p "$URL_PORT"); fi
  cfg="$(ssh -G "${pargs[@]+"${pargs[@]}"}" "$dest" 2>/dev/null)" || finish unverified ssh-config-unresolved
  real_host="$(awk '$1=="hostname"{print $2; exit}' <<< "$cfg")"
  add push_target "${real_host:-$URL_HOST}/$URL_PATH"
  # GitHub also serves SSH on ssh.<host> (port 443).
  if ! same "$real_host" "$HOST" && ! same "$real_host" "ssh.$HOST"; then finish mismatch push-target-mismatch; fi
  same "$URL_PATH" "$REPO" || finish mismatch push-target-mismatch

  # Authentication test with Git's own route: no remote command, no prompt, no
  # host-key change. GitHub greets the authenticated account and exits 1.
  out="$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no \
    -o ConnectTimeout=15 "${pargs[@]+"${pargs[@]}"}" "$dest" 2>&1 </dev/null)" || rc=$?
  add ssh_exit "$rc"
  login="$(sed -n "s/^Hi \(.*\)! You've successfully authenticated.*/\1/p" <<< "$out")"
  if [[ -z "$login" || "$login" == *$'\n'* ]]; then
    case "$out" in
      *"Host key verification failed"*) finish unverified ssh-host-key-untrusted ;;
      *"Permission denied"*)            finish unverified ssh-permission-denied ;;
      *)                                finish unverified ssh-no-greeting ;;
    esac
  fi
  if [[ "$rc" != 0 && "$rc" != 1 ]]; then finish unverified ssh-unexpected-exit; fi
  # A deploy key greets as owner/repo; that is not a user principal.
  if [[ ! "$login" =~ ^[A-Za-z0-9-]+$ ]]; then finish unverified ssh-non-user-key; fi
  add actual_push_actor "$login"
  same "$login" "$PUSH_ACTOR" || finish mismatch push-actor-mismatch
  finish pass
}

helper_applies() {                 # $1 = config key; 0 applies, 1 other host, 2 cannot decide
  local key="$1" sub url_base
  if [[ "$key" == credential.helper ]]; then return 0; fi
  sub="${key#credential.}"; sub="${sub%.helper}"; sub="$(lower "${sub%/}")"
  url_base="$(lower "https://$URL_HOST")"
  case "$sub" in
    "$url_base"|"$url_base/$(lower "$URL_PATH")"|"$url_base/$(lower "$URL_PATH").git") return 0 ;;
  esac
  if [[ "$sub" == "$url_base/"* && "$(lower "$URL_PATH")/" == "${sub#"$url_base/"}/"* ]]; then return 0; fi
  if [[ "$sub" != *"$(lower "$URL_HOST")"* && "$sub" != *'*'* ]]; then return 1; fi
  return 2
}

helper_gh_path() {                 # prints the gh executable of a recognized gh helper, else returns 1
  local val="${1#!}"
  [[ "$val" =~ ^[\'\"]?(([^\'\"\ ]*/)?gh)[\'\"]?\ auth\ git-credential$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

helper_name() {
  local val="$1" word
  if helper_gh_path "$val" >/dev/null; then echo gh; return 0; fi
  word="${val#!}"; word="${word%% *}"; word="${word//[\'\"]/}"
  basename -- "$word"
}

check_push_https() {
  local rec key val applies names="" helper gh_path actual
  local helpers=()
  if [[ -n "$URL_USERINFO" ]]; then finish unverified url-embedded-credential; fi
  add push_target "$URL_HOST/$URL_PATH"
  same "$URL_HOST" "$HOST" || finish mismatch push-target-mismatch
  same "$URL_PATH" "$REPO" || finish mismatch push-target-mismatch

  # Anything else that could supply or replace the credential blocks the route.
  if git -C "$TOP" config --get-regexp '^http\.(.*\.)?extraheader$' >/dev/null 2>&1; then
    finish unverified http-extraheader
  fi
  if [[ -n "${GIT_ASKPASS:-}" || -n "${SSH_ASKPASS:-}" ]] \
    || git -C "$TOP" config --get core.askPass >/dev/null 2>&1; then
    finish unverified askpass-configured
  fi

  # Effective helper chain in Git's read order; an empty value resets the list.
  while IFS= read -r -d '' rec; do
    key="${rec%%$'\n'*}"; val=""
    if [[ "$rec" == *$'\n'* ]]; then val="${rec#*$'\n'}"; fi
    applies=0; helper_applies "$key" || applies=$?
    case "$applies" in
      1) continue ;;
      2) finish unverified credential-config-ambiguous ;;
    esac
    if [[ -z "$val" ]]; then helpers=(); else helpers+=("$val"); fi
  done < <(git -C "$TOP" config -z --get-regexp '^credential\.(.*\.)?helper$' 2>/dev/null || true)

  for helper in "${helpers[@]+"${helpers[@]}"}"; do
    names="${names:+$names,}$(helper_name "$helper")"
  done
  add credential_helpers "${names:-none}"
  # Only a chain of exactly the gh helper can be tied to an API login without
  # reading a secret. Keychains, stores and managers stay unsupported.
  if [[ ${#helpers[@]} -ne 1 ]]; then finish unverified unsupported-credential-helper; fi
  gh_path="$(helper_gh_path "${helpers[0]}")" || finish unverified unsupported-credential-helper
  command -v gh >/dev/null 2>&1 || finish unverified gh-missing
  if [[ "$gh_path" == */* && ! "$gh_path" -ef "$(command -v gh)" ]]; then
    finish unverified credential-helper-gh-differs
  fi
  note_gh_context
  actual="$(gh_login "$URL_HOST")" || finish unverified push-actor-unavailable
  actual="${actual%%$'\n'*}"
  if [[ -z "$actual" ]]; then finish unverified push-actor-unavailable; fi
  add actual_push_actor "$actual"
  same "$actual" "$PUSH_ACTOR" || finish mismatch push-actor-mismatch
  finish pass
}

check_push() {
  local urls
  add remote "$REMOTE"
  add expected_push_actor "$PUSH_ACTOR"
  if [[ -n "$REF" ]]; then
    git check-ref-format --branch "$REF" >/dev/null 2>&1 || finish error invalid-ref
    add push_ref "$REF"
  fi
  urls="$(git -C "$TOP" remote get-url --push --all "$REMOTE" 2>/dev/null)" || finish unverified remote-unavailable
  if [[ -z "$urls" ]]; then finish unverified remote-unavailable; fi
  if [[ "$urls" == *$'\n'* ]]; then finish unverified multiple-push-urls; fi
  parse_push_url "$urls" || finish unverified unsupported-push-route
  add push_protocol "$URL_SCHEME"
  if [[ "$URL_SCHEME" == https && -n "$URL_USERINFO" ]]; then finish unverified url-embedded-credential; fi
  [[ "$URL_SCHEME" == "$PROTOCOL" ]] || finish mismatch push-protocol-mismatch
  case "$URL_SCHEME" in
    ssh)   check_push_ssh ;;
    https) check_push_https ;;
  esac
}

case "$OPERATION" in
  api)    check_api ;;
  commit) check_commit ;;
  push)   check_push ;;
esac
