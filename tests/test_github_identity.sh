#!/usr/bin/env bash
# Behavior tests for the shared read-only identity check
# (template/common/scripts/github/check-identity.sh), run offline against PATH
# stubs for gh and ssh and a logging wrapper around the real git.
# Maps to openspec/changes/add-github-change-handoff, requirement
# "Identity checks share an operation-scoped executable".
#
# Stub replies prove the script's decisions, not that any real account,
# SSH key or credential helper was verified.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/template/common/scripts/github/check-identity.sh"
REL='scripts/github/check-identity.sh'
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

TMPROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMPROOT"' EXIT
REAL_GIT="$(command -v git)"
STUB="$TMPROOT/bin"; NOGH="$TMPROOT/bin-nogh"
LOG="$TMPROOT/calls.log"; ALL_LOG="$TMPROOT/all-calls.log"; : > "$ALL_LOG"
GCFG="$TMPROOT/gitconfig"; : > "$GCFG"
mkdir -p "$STUB" "$NOGH" "$TMPROOT/home" "$TMPROOT/elsewhere"

cat > "$STUB/git" <<EOF
#!/bin/bash
printf 'git %s\n' "\$*" >> "\$STUB_LOG"
exec "$REAL_GIT" "\$@"
EOF
cat > "$STUB/gh" <<'EOF'
#!/bin/bash
printf 'gh %s\n' "$*" >> "$STUB_LOG"
if [[ "${STUB_GH_RC:-0}" != 0 ]]; then echo "gh: authentication required" >&2; exit "$STUB_GH_RC"; fi
case "$*" in
  "--version")   echo "gh version 2.99.0 (stub)" ;;
  *"repos/"*)    printf '%s\n' "${STUB_GH_REPO:-acme/widgets}" ;;
  *" user "*)    printf '%s\n' "${STUB_GH_LOGIN:-octo-dev}" ;;
  *)             echo "unexpected gh call: $*" >&2; exit 9 ;;
esac
EOF
cat > "$STUB/ssh" <<'EOF'
#!/bin/bash
printf 'ssh %s\n' "$*" >> "$STUB_LOG"
if [[ "$1" == "-G" ]]; then
  printf 'user git\nhostname %s\nport %s\n' "${STUB_SSH_HOSTNAME:-github.com}" "${STUB_SSH_PORT:-22}"
  exit 0
fi
printf '%s\n' "${STUB_SSH_OUT:-}" >&2
exit "${STUB_SSH_RC:-1}"
EOF
chmod +x "$STUB"/*
cp "$STUB/git" "$STUB/ssh" "$NOGH/"

g() { GIT_CONFIG_GLOBAL="$GCFG" GIT_CONFIG_NOSYSTEM=1 "$REAL_GIT" "$@"; }
mk_repo() {                        # $1 = name, $2 = origin URL; echoes the repo path
  local d="$TMPROOT/$1"
  g init -q -b main "$d"
  g -C "$d" config user.name 'Dev One'
  g -C "$d" config user.email 'dev1@example.com'
  printf 'x\n' > "$d/file.txt"
  g -C "$d" add file.txt
  g -C "$d" commit -qm base
  g -C "$d" remote add origin "$2"
  printf '%s\n' "$d"
}
commit_script() {                  # $1 = repo, $2 = content file or "symlink"; echoes the commit
  mkdir -p "$1/scripts/github"
  rm -f "$1/$REL"
  if [[ "$2" == symlink ]]; then ln -s ../../file.txt "$1/$REL"; else cp "$2" "$1/$REL"; chmod +x "$1/$REL"; fi
  g -C "$1" add "$REL"
  g -C "$1" commit -qm "script $(date +%s)$RANDOM"
  g -C "$1" rev-parse HEAD
}

RUN_CWD=""; RUN_PATH="$STUB"; ENTRY="$SCRIPT"
run() {                            # [VAR=value ...] -- script args; sets OUT and RC
  local envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : > "$LOG"
  OUT="$(cd "$RUN_CWD" && env -i PATH="$RUN_PATH:/usr/bin:/bin" HOME="$TMPROOT/home" \
    GIT_CONFIG_GLOBAL="$GCFG" GIT_CONFIG_NOSYSTEM=1 STUB_LOG="$LOG" \
    "${envs[@]+"${envs[@]}"}" bash "$ENTRY" "$@" 2>&1)"
  RC=$?
  cat "$LOG" >> "$ALL_LOG"
}
check() {                          # $1 = name, $2 = expected exit code, rest = required output lines
  local name="$1" rc="$2" miss="" s; shift 2
  for s in "$@"; do grep -Fqx -- "$s" <<< "$OUT" || miss="$miss [$s]"; done
  if [[ "$RC" == "$rc" && -z "$miss" ]]; then ok "$name"; else bad "$name (exit $RC, want $rc; missing:$miss)"; fi
}
lacks()   { if grep -Fq -- "$2" <<< "$OUT"; then bad "$1"; else ok "$1"; fi; }
called()  { if grep -Eq -- "$2" "$LOG"; then ok "$1"; else bad "$1"; fi; }
uncalled(){ if grep -Eq -- "$2" "$LOG"; then bad "$1"; else ok "$1"; fi; }

BLOB="$("$REAL_GIT" hash-object --no-filters "$SCRIPT" 2>/dev/null)"
SRC=(--policy-source user-input --script-blob "$BLOB")
API=(--operation api --host github.com --repo acme/widgets --api-actor octo-dev)
COMMIT=(--operation commit --author-name 'Dev One' --author-email dev1@example.com
        --committer-name 'Dev One' --committer-email dev1@example.com)
PUSH_SSH=(--operation push --host github.com --repo acme/widgets --remote origin
          --protocol ssh --push-actor octo-dev)
PUSH_HTTPS=(--operation push --host github.com --repo acme/widgets --remote origin
            --protocol https --push-actor octo-dev)
GREETING="Hi octo-dev! You've successfully authenticated, but GitHub does not provide shell access."

REPO="$(mk_repo ssh-repo 'git@github.com:acme/widgets.git')"
RUN_CWD="$REPO"
CONFIG_BEFORE="$(shasum "$REPO/.git/config" "$GCFG" | shasum)"

# ── api ──────────────────────────────────────────────────────────────────────
echo "api"
run -- "${API[@]}" "${SRC[@]}"
check "matching API actor and repository pass" 0 'operation=api' 'status=pass' \
  'target=github.com/acme/widgets' 'actual_api_actor=octo-dev' 'policy_source=user-input'
called "API login is read from the selected host" '^gh api --hostname github\.com user '
run STUB_GH_LOGIN=someone-else -- "${API[@]}" "${SRC[@]}"
check "different API actor is a mismatch" 2 'status=mismatch' 'reason=api-actor-mismatch' \
  'expected_api_actor=octo-dev' 'actual_api_actor=someone-else'
run STUB_GH_LOGIN=Octo-Dev -- "${API[@]}" "${SRC[@]}"
check "login comparison ignores case" 0 'status=pass'
run STUB_GH_REPO=acme/renamed -- "${API[@]}" "${SRC[@]}"
check "gh resolving another repository is a mismatch" 2 'status=mismatch' 'reason=repository-mismatch'
run STUB_GH_RC=4 -- "${API[@]}" "${SRC[@]}"
check "unauthenticated gh is unverified, not pass" 3 'status=unverified' 'reason=api-actor-unavailable'
RUN_PATH="$NOGH"
run -- "${API[@]}" "${SRC[@]}"
check "missing gh is unverified" 3 'status=unverified' 'reason=gh-missing'
RUN_PATH="$STUB"
run GH_TOKEN=tok_secret_value -- "${API[@]}" "${SRC[@]}"
check "environment token is reported by name" 0 'status=pass' 'gh_env_token=GH_TOKEN'
lacks "token value is never echoed" 'tok_secret_value'

# ── commit ───────────────────────────────────────────────────────────────────
echo "commit"
run -- "${COMMIT[@]}" "${SRC[@]}"
check "configured identity passes" 0 'operation=commit' 'status=pass' \
  'actual_author=Dev One <dev1@example.com>' 'actual_committer=Dev One <dev1@example.com>' \
  'author_source=config:local'
uncalled "commit check does not call gh or ssh" '^(gh|ssh) '
run GIT_AUTHOR_EMAIL=other@example.com -- "${COMMIT[@]}" "${SRC[@]}"
check "environment override decides the effective author" 2 'status=mismatch' \
  'reason=author-mismatch' 'actual_author=Dev One <other@example.com>' 'author_source=env'
run GIT_COMMITTER_NAME=Release-Bot -- "${COMMIT[@]}" "${SRC[@]}"
check "committer is checked separately from author" 2 'status=mismatch' 'reason=committer-mismatch'
run GIT_COMMITTER_NAME=Release-Bot -- --operation commit --author-name 'Dev One' \
  --author-email dev1@example.com --committer-name Release-Bot \
  --committer-email dev1@example.com "${SRC[@]}"
check "intentionally different author and committer pass" 0 'status=pass' 'committer_source=env'

# ── push over SSH ────────────────────────────────────────────────────────────
echo "push (ssh)"
run STUB_SSH_OUT="$GREETING" STUB_SSH_RC=1 -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "trusted greeting passes although ssh exits 1" 0 'operation=push' 'status=pass' \
  'push_protocol=ssh' 'actual_push_actor=octo-dev' 'ssh_exit=1' 'push_target=github.com/acme/widgets'
called "auth test is noninteractive with strict host keys" \
  '^ssh -T .*-o BatchMode=yes .*-o StrictHostKeyChecking=yes .*-o UpdateHostKeys=no .*git@github\.com$'
uncalled "host-key verification is never disabled" 'StrictHostKeyChecking=(no|accept-new)'
uncalled "push check does not use the API login" '^gh api'
run STUB_SSH_OUT="Hi someone-else! You've successfully authenticated, but GitHub does not provide shell access." \
  -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "another SSH account is a mismatch" 2 'status=mismatch' 'reason=push-actor-mismatch' \
  'actual_push_actor=someone-else'
run STUB_SSH_OUT="Hi acme/widgets! You've successfully authenticated, but GitHub does not provide shell access." \
  -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "deploy-key greeting is not a user principal" 3 'status=unverified' 'reason=ssh-non-user-key'
run STUB_SSH_OUT='git@github.com: Permission denied (publickey).' STUB_SSH_RC=255 -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "permission denied is unverified" 3 'status=unverified' 'reason=ssh-permission-denied'
run STUB_SSH_OUT='Host key verification failed.' STUB_SSH_RC=255 -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "untrusted host key is unverified" 3 'status=unverified' 'reason=ssh-host-key-untrusted'
run STUB_SSH_OUT='ssh: connect to host github.com port 22: Operation timed out' STUB_SSH_RC=255 \
  -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "no greeting is unverified" 3 'status=unverified' 'reason=ssh-no-greeting'
run STUB_SSH_OUT="$GREETING" GIT_SSH_COMMAND='ssh -i /tmp/other_key' -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "custom SSH command blocks instead of being executed" 3 'status=unverified' 'reason=custom-ssh-command'
uncalled "no auth test runs with settings that differ from Git's" '^ssh -T'
run STUB_SSH_OUT="$GREETING" -- --operation push --host github.com --repo acme/other --remote origin \
  --protocol ssh --push-actor octo-dev "${SRC[@]}"
check "remote pointing at another repository is a mismatch" 2 'status=mismatch' 'reason=push-target-mismatch'
run STUB_SSH_OUT="$GREETING" -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "protocol differing from the policy is a mismatch" 2 'status=mismatch' 'reason=push-protocol-mismatch'
run -- --operation push --host github.com --repo acme/widgets --remote upstream --protocol ssh \
  --push-actor octo-dev "${SRC[@]}"
check "unknown remote is unverified" 3 'status=unverified' 'reason=remote-unavailable'

# API pass is not reused as push evidence.
run STUB_SSH_OUT="Hi someone-else! You've successfully authenticated, but GitHub does not provide shell access." \
  -- "${API[@]}" "${SRC[@]}"
API_RC=$RC
run STUB_SSH_OUT="Hi someone-else! You've successfully authenticated, but GitHub does not provide shell access." \
  -- "${PUSH_SSH[@]}" "${SRC[@]}"
[[ "$API_RC" == 0 && "$RC" == 2 ]] \
  && ok "api pass does not carry over to a mismatching push" || bad "api pass does not carry over to a mismatching push (api $API_RC, push $RC)"

ALIAS_REPO="$(mk_repo alias-repo 'git@gh-work:acme/widgets.git')"
RUN_CWD="$ALIAS_REPO"
run STUB_SSH_OUT="$GREETING" -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "host alias resolving to the expected host passes" 0 'status=pass'
called "auth test targets the alias Git would use" '^ssh -T .*git@gh-work$'
run STUB_SSH_OUT="$GREETING" STUB_SSH_HOSTNAME=evil.example.com -- "${PUSH_SSH[@]}" "${SRC[@]}"
check "alias resolving to another host is a mismatch" 2 'status=mismatch' 'reason=push-target-mismatch'
RUN_CWD="$REPO"

# ── push over HTTPS ──────────────────────────────────────────────────────────
echo "push (https)"
HTTPS_REPO="$(mk_repo https-repo 'https://github.com/acme/widgets.git')"
RUN_CWD="$HTTPS_REPO"
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "no credential helper is unsupported" 3 'status=unverified' 'reason=unsupported-credential-helper'
g -C "$HTTPS_REPO" config credential.helper osxkeychain
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "osxkeychain is unsupported even when gh reports a matching login" 3 'status=unverified' \
  'reason=unsupported-credential-helper' 'credential_helpers=osxkeychain'
uncalled "an unverifiable helper is never backed by the API login" '^gh api'
g -C "$HTTPS_REPO" config --add credential.https://github.com.helper ''
g -C "$HTTPS_REPO" config --add credential.https://github.com.helper '!gh auth git-credential'
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "helper chain reset to gh alone passes with the gh login" 0 'status=pass' \
  'push_protocol=https' 'actual_push_actor=octo-dev' 'credential_helpers=gh'
run STUB_GH_LOGIN=someone-else -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "gh helper with another login is a mismatch" 2 'status=mismatch' 'reason=push-actor-mismatch'
g -C "$HTTPS_REPO" config --add credential.https://github.com.helper store
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "a second helper beside gh is unsupported" 3 'status=unverified' 'reason=unsupported-credential-helper'
g -C "$HTTPS_REPO" config --unset-all credential.https://github.com.helper
g -C "$HTTPS_REPO" config --unset-all credential.helper
g -C "$HTTPS_REPO" config --add credential.helper '!gh auth git-credential'
g -C "$HTTPS_REPO" config http.https://github.com/.extraheader 'AUTHORIZATION: basic c2VjcmV0'
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "an auth header that takes over is unverified" 3 'status=unverified' 'reason=http-extraheader'
lacks "header value is never echoed" 'c2VjcmV0'
g -C "$HTTPS_REPO" config --unset http.https://github.com/.extraheader
run GIT_ASKPASS=/usr/local/bin/askpass -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "askpass that could take over is unverified" 3 'status=unverified' 'reason=askpass-configured'
g -C "$HTTPS_REPO" remote set-url origin 'https://octo-dev:s3cr3t-pass@github.com/acme/widgets.git'
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "URL with an embedded credential is unverified" 3 'status=unverified' 'reason=url-embedded-credential'
lacks "embedded credential is never echoed" 's3cr3t-pass'
g -C "$HTTPS_REPO" remote set-url origin 'git://github.com/acme/widgets.git'
run -- "${PUSH_HTTPS[@]}" "${SRC[@]}"
check "other transports are unsupported" 3 'status=unverified' 'reason=unsupported-push-route'
RUN_CWD="$REPO"

# ── arguments, project root and exit code 1 ──────────────────────────────────
echo "arguments and project root"
run -- --operation deploy "${SRC[@]}"
check "unknown operation is an error" 1 'status=error'
run -- --operation api --host github.com --repo acme/widgets "${SRC[@]}"
check "missing expected value is an error" 1 'status=error' 'reason=missing-argument'
run -- "${API[@]}"
check "missing policy source is an error" 1 'status=error' 'reason=missing-argument'
RUN_CWD="$TMPROOT/elsewhere"
run -- "${API[@]}" "${SRC[@]}"
check "running outside a Git work tree is an error" 1 'status=error' 'reason=not-a-git-work-tree'
run CLAUDE_PROJECT_DIR="$REPO" -- "${COMMIT[@]}" "${SRC[@]}"
check "CLAUDE_PROJECT_DIR selects the project over the cwd" 0 'status=pass'
RUN_CWD="$REPO"

# ── trusted script source ────────────────────────────────────────────────────
echo "trusted script source"
BASE="$(g -C "$REPO" rev-parse HEAD)"
run -- "${API[@]}" --policy-source user-input --script-blob 0000000000000000000000000000000000000000
check "running content that differs from the pinned blob is unverified" 3 'status=unverified' \
  'reason=script-blob-mismatch'
uncalled "an untrusted script performs no identity check" '^gh '
run -- "${API[@]}" --policy-source user-input
check "user-input policy without a pinned script is an error" 1 'status=error' 'reason=missing-argument'
run -- "${API[@]}" --policy-source "${BASE:0:12}"
check "abbreviated policy commit is an error" 1 'status=error' 'reason=policy-source-not-full-commit'
run -- "${API[@]}" --policy-source "$BASE"
check "trusted revision without the script reports the bootstrap gap" 3 'status=unverified' \
  'reason=bootstrap-no-trusted-script'
uncalled "bootstrap gap performs no identity check" '^gh '

SAME_REPO="$(mk_repo same-repo 'git@github.com:acme/widgets.git')"
SAME="$(commit_script "$SAME_REPO" "$SCRIPT")"
RUN_CWD="$SAME_REPO"
run -- "${API[@]}" --policy-source "$SAME"
check "content equal to the trusted blob runs and records its source" 0 'status=pass' \
  "policy_source=$SAME" "script_source=$REL@$SAME" "script_blob=$BLOB"

# Trusted revision holds a marker script; the working copy holds a different
# candidate; the entry copy matches neither. Only the trusted blob may run.
cat > "$TMPROOT/trusted-marker.sh" <<'EOF'
#!/usr/bin/env bash
echo "marker=trusted-blob"
echo "self=$0"
echo "cwd=$PWD"
echo "args=$*"
exit 0
EOF
printf '#!/usr/bin/env bash\necho "marker=candidate"\necho "status=pass"\nexit 0\n' > "$TMPROOT/candidate.sh"
CAND_REPO="$(mk_repo cand-repo 'git@github.com:acme/widgets.git')"
TRUSTED="$(commit_script "$CAND_REPO" "$TMPROOT/trusted-marker.sh")"
commit_script "$CAND_REPO" "$TMPROOT/candidate.sh" >/dev/null
RUN_CWD="$CAND_REPO"
run -- "${API[@]}" --policy-source "$TRUSTED"
check "only the trusted blob is executed" 0 'marker=trusted-blob' "cwd=$CAND_REPO"
lacks "the candidate script is not executed" 'marker=candidate'
SELF="$(sed -n 's/^self=//p' <<< "$OUT")"
if [[ -n "$SELF" && "$SELF" != "$CAND_REPO"/* && ! -e "$SELF" ]]; then
  ok "trusted copy ran outside the checkout and was cleaned up"
else
  bad "trusted copy ran outside the checkout and was cleaned up (self: ${SELF:-none})"
fi
grep -Fq -- "--policy-source $TRUSTED" <<< "$OUT" \
  && ok "trusted copy receives the original arguments" || bad "trusted copy receives the original arguments"
[[ "$(g -C "$CAND_REPO" status --porcelain)" == "" ]] \
  && ok "the reviewed checkout is left untouched" || bad "the reviewed checkout is left untouched"

LINK_REPO="$(mk_repo link-repo 'git@github.com:acme/widgets.git')"
LINKED="$(commit_script "$LINK_REPO" symlink)"
RUN_CWD="$LINK_REPO"
run -- "${API[@]}" --policy-source "$LINKED"
check "a symlink at the trusted revision is rejected" 3 'status=unverified' \
  'reason=trusted-script-not-regular-file'
uncalled "a rejected source performs no identity check" '^gh '
RUN_CWD="$REPO"

# ── read-only guarantee across every run above ───────────────────────────────
echo "read-only guarantee"
if grep -Eq '^git (-C [^ ]+ )?(add|commit|push|stash|reset|checkout|switch|merge|rebase|fetch|pull|credential|update-ref|tag|branch -[dDmM])( |$)' "$ALL_LOG"; then
  bad "no Git write, staging or credential command was issued"
else
  ok "no Git write, staging or credential command was issued"
fi
if grep -Eq '^git (-C [^ ]+ )?(config .*(--global|--add|--unset|--replace-all|--edit)|remote (add|set-url|remove|rename))' "$ALL_LOG"; then
  bad "no Git configuration or remote was changed"
else
  ok "no Git configuration or remote was changed"
fi
if grep -Eq '^gh (auth|issue|pr|repo|secret|config)( |$)' "$ALL_LOG"; then
  bad "no gh login, switch, token or write command was issued"
else
  ok "no gh login, switch, token or write command was issued"
fi
[[ "$(shasum "$REPO/.git/config" "$GCFG" | shasum)" == "$CONFIG_BEFORE" ]] \
  && ok "repository and global Git config are byte-identical" || bad "repository and global Git config are byte-identical"
[[ "$(g -C "$REPO" status --porcelain)" == "" ]] \
  && ok "work tree and index are unchanged" || bad "work tree and index are unchanged"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
