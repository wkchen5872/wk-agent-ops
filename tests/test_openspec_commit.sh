#!/usr/bin/env bash
# Contract test for the project-owned archive -> docs -> commit workflow.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORCHESTRATOR="$ROOT/template/common/skills/openspec-commit/SKILL.md"
CLAUDE_ENTRYPOINT="$ROOT/template/common/.claude/commands/opsx/commit.md"
ANTIGRAVITY_ENTRYPOINT="$ROOT/template/common/.agents/workflows/opsx-commit.md"
DOC_SKILL="$ROOT/template/common/skills/doc-updater/SKILL.md"
DOC_AGENT="$ROOT/template/common/.claude/agents/doc-updater-agent.md"
COMMIT_SKILL="$ROOT/template/common/skills/git-commit-writer/SKILL.md"
COMMIT_AGENT="$ROOT/template/common/.claude/agents/git-commit-writer-agent.md"
CODEX_COMMIT_AGENT="$ROOT/template/common/.codex/agents/git-commit-writer-agent.toml"
fail=0
section="${1:-all}"

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

require_text() {
  local file="$1" text="$2" label="$3"
  grep -Fq "$text" "$file" && ok "$label" || bad "$label"
}

forbid_text() {
  local file="$1" text="$2" label="$3"
  grep -Fq "$text" "$file" && bad "$label" || ok "$label"
}

line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1
}

run_section() {
  [[ "$section" == "all" || "$section" == "$1" ]]
}

if run_section orchestrator; then
printf 'openspec-commit orchestration\n'
archive_line="$(line_of "$ORCHESTRATOR" '## Step 2 — Archive or resume')"
stage_line="$(line_of "$ORCHESTRATOR" '## Step 3 — Prepare the complete diff')"
docs_line="$(line_of "$ORCHESTRATOR" '## Step 4 — Invoke doc-updater')"
commit_line="$(line_of "$ORCHESTRATOR" '## Step 5 — Invoke git-commit-writer')"
attribution_line="$(line_of "$ORCHESTRATOR" 'Resolve the attribution pair now, immediately before commit delegation:')"
if [[ -n "$archive_line" && -n "$stage_line" && -n "$docs_line" && -n "$commit_line" ]] \
  && (( archive_line < stage_line && stage_line < docs_line && docs_line < commit_line )); then
  ok "archive -> stage -> docs -> commit order"
else
  bad "archive -> stage -> docs -> commit order"
fi
if [[ -n "$docs_line" && -n "$commit_line" && -n "$attribution_line" ]] \
  && (( docs_line < commit_line && commit_line < attribution_line )); then
  ok "attribution resolved only at commit boundary"
else
  bad "attribution resolved only at commit boundary"
fi
require_text "$ORCHESTRATOR" 'openspec-archive-change' "portable archive capability named"
require_text "$ORCHESTRATOR" 'git status --short' "resume state comes from Git"
require_text "$ORCHESTRATOR" 'archive_path' "exact archive path retained"
require_text "$ORCHESTRATOR" 'git add -A' "new files prepared before doc-updater"
require_text "$ORCHESTRATOR" 'tool_name=<executing agent tool>' "executing tool handed to commit writer"
require_text "$ORCHESTRATOR" 'assisting_model=<current root-session model>' "primary model handed to commit writer"
require_text "$ORCHESTRATOR" 'commit-only agent' "commit-only agent cannot replace implementation model"
forbid_text "$ORCHESTRATOR" 'Before any delegation, record the exact attribution context' "no early attribution gate"
require_text "$ORCHESTRATOR" '`assisting_model` is Git attribution metadata only' "orchestrator defines attribution metadata"
require_text "$ORCHESTRATOR" 'MUST NOT be used as a subagent spawn model or reasoning-effort override' "orchestrator forbids attribution override"
require_text "$ORCHESTRATOR" 'use the current runtime model name automatically' "same-session runtime attribution is automatic"
require_text "$ORCHESTRATOR" 'MUST NOT ask the user to repeat it' "same-session attribution is not reconfirmed"
require_text "$ORCHESTRATOR" 'later commits in the same session' "same-session attribution survives later commits"
require_text "$ORCHESTRATOR" 'Provider-native documentation and commit subagents MUST NOT replace or make the root-session attribution ambiguous' "subagents do not create attribution ambiguity"
require_text "$ORCHESTRATOR" 'MUST NOT request or require `assisting_model` before archive or documentation handling' "attribution cannot block archive or docs"
forbid_text "$ORCHESTRATOR" 'Codex MAY use exact current-turn runtime metadata' "runtime attribution is not merely optional"
require_text "$ORCHESTRATOR" 'Accept `GPT-5`, `GPT-5.6`, or `GPT-6`' "known family versions are accepted"
require_text "$ORCHESTRATOR" 'Tool names are not model names' "tool identity cannot replace model identity"
require_text "$ORCHESTRATOR" 'do not block the commit' "unknown model cannot block commit"
require_text "$ORCHESTRATOR" 'After a root model switch, use the' "model switch uses current collaboration"
require_text "$ORCHESTRATOR" 'MUST NOT parse session logs' "session-log parsing is forbidden"
require_text "$ORCHESTRATOR" 'MUST NOT use documentation lookup' "documentation cannot prove runtime identity"
require_text "$ORCHESTRATOR" 'Do not pass a spawn `model` or `reasoning_effort`' "native agents keep configured runtime"
[[ "$(grep -Fc 'Do not pass a spawn `model` or `reasoning_effort`' "$ORCHESTRATOR")" -eq 2 ]] \
  && ok "both native subagents keep configured runtime" || bad "both native subagents keep configured runtime"
forbid_text "$ORCHESTRATOR" 'ls -t openspec/changes/archive/' "no newest-archive rediscovery"

printf '\nprovider boundaries\n'
require_text "$ORCHESTRATOR" '.claude/commands/opsx/archive.md' "Claude native alias documented"
require_text "$ORCHESTRATOR" '.codex/skills/openspec-archive-change/' "Codex skill path documented"
require_text "$ORCHESTRATOR" '.agent/workflows/opsx-archive.md' "Antigravity native alias documented"
require_text "$ORCHESTRATOR" '.agents/skills/' "project-owned shared skill root documented"
require_text "$ORCHESTRATOR" 'Do not invoke both' "provider aliases cannot double-run an action"
require_text "$ORCHESTRATOR" 'Claude Code and Codex MUST NOT silently fall back' "known providers cannot silently use skills"
require_text "$ORCHESTRATOR" 'provider-native `doc-updater-agent`' "documentation agent route is explicit"
require_text "$ORCHESTRATOR" 'provider-native `git-commit-writer-agent`' "commit agent route is explicit"
require_text "$ORCHESTRATOR" 'Every other provider' "other providers use default route"
require_text "$ORCHESTRATOR" '.agents/skills/doc-updater/' "portable documentation fallback path named"
require_text "$ORCHESTRATOR" '.agents/skills/git-commit-writer/' "portable commit fallback path named"
forbid_text "$ORCHESTRATOR" '**Codex and Antigravity:**' "Codex is not grouped with skill-only provider"

printf '\nprovider entrypoints\n'
require_text "$CLAUDE_ENTRYPOINT" 'argument-hint: "[change-name]"' "Claude advertises optional change name"
require_text "$CLAUDE_ENTRYPOINT" '$ARGUMENTS' "Claude forwards command arguments"
require_text "$CLAUDE_ENTRYPOINT" 'unchanged' "Claude preserves command arguments"
require_text "$CLAUDE_ENTRYPOINT" 'exactly once' "Claude delegates exactly once"
require_text "$CLAUDE_ENTRYPOINT" 'Do not run archive' "Claude forbids duplicate completion actions"

require_text "$ANTIGRAVITY_ENTRYPOINT" '/opsx-commit' "Antigravity uses its flat command name"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'pass it unchanged' "Antigravity preserves optional change name"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'exactly once' "Antigravity delegates exactly once"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'Do not run archive' "Antigravity forbids duplicate completion actions"
require_text "$ANTIGRAVITY_ENTRYPOINT" '.agents/skills/openspec-commit/SKILL.md' "Antigravity names the project skill fallback"
require_text "$ANTIGRAVITY_ENTRYPOINT" 'current context' "Antigravity fallback stays in context"
forbid_text "$ANTIGRAVITY_ENTRYPOINT" 'Skill tool' "Antigravity avoids Claude Skill tool terminology"
forbid_text "$ANTIGRAVITY_ENTRYPOINT" 'opsx:apply' "Antigravity avoids Claude command syntax"
fi

if run_section doc-updater; then
printf '\ndoc-updater context\n'
for file in "$DOC_SKILL" "$DOC_AGENT"; do
  require_text "$file" 'archive_path' "$(basename "$file") accepts archive_path"
  require_text "$file" '<archive_path>/proposal.md' "$(basename "$file") reads proposal"
  require_text "$file" '<archive_path>/specs/**/*.md' "$(basename "$file") reads delta specs"
  require_text "$file" 'git status --short' "$(basename "$file") reads status"
  require_text "$file" 'git diff HEAD' "$(basename "$file") reads actual diff"
  forbid_text "$file" '建立獨立的 `docs:` commit' "$(basename "$file") Mode B does not claim auto-commit"
done
fi

if run_section commit-writer; then
printf '\ngit-commit-writer boundary\n'
for file in "$COMMIT_SKILL" "$ORCHESTRATOR" "$COMMIT_AGENT" "$CODEX_COMMIT_AGENT"; do
  require_text "$file" 'This records current collaboration, not original code authorship' "$(basename "$file") records collaboration rather than authorship"
  require_text "$file" 'A known `GPT-5` MUST be recorded, not omitted' "$(basename "$file") never omits known GPT-5"
  forbid_text "$file" 'cross-session/model-switched work has unresolved attribution' "$(basename "$file") removes original-author gate"
done
require_text "$COMMIT_SKILL" 'or a commit-only root session MUST NOT' "commit-only root session keeps known model"
require_text "$ORCHESTRATOR" 'or a commit-only root session MUST NOT' "coordinator keeps known model for existing work"
for file in "$COMMIT_SKILL" "$COMMIT_AGENT"; do
  require_text "$file" 'archive_path and change_id are provided' "$(basename "$file") explicit context is primary"
  require_text "$file" 'git add -A' "$(basename "$file") stages changes"
  require_text "$file" 'git diff --cached --quiet' "$(basename "$file") guards empty staged diff"
  require_text "$file" 'git diff --cached --name-only' "$(basename "$file") reads final staged paths"
  require_text "$file" '### Standalone context resolution' "$(basename "$file") names standalone resolution boundary"
  require_text "$file" 'feature/<change-id>' "$(basename "$file") requires exact feature branch evidence"
  require_text "$file" 'openspec/changes/<change-id>/' "$(basename "$file") requires exact active path evidence"
  require_text "$file" 'openspec/changes/archive/<archive-directory>/' "$(basename "$file") requires exact archive path evidence"
  require_text "$file" 'A sole active change without either association is not context.' "$(basename "$file") ignores a sole unrelated active change"
  require_text "$file" 'The number of active changes does not create an association.' "$(basename "$file") separates candidate count from association"
  require_text "$file" 'Zero associated candidates' "$(basename "$file") defines unscoped fallback"
  require_text "$file" 'One associated candidate' "$(basename "$file") defines associated context"
  require_text "$file" 'Multiple associated candidates' "$(basename "$file") guards ambiguity"
  require_text "$file" 'Re-run `git add -A`' "$(basename "$file") restages on retry"
  require_text "$file" 'tool_name=<executing agent tool>' "$(basename "$file") accepts tool identity"
  require_text "$file" 'assisting_model=<current root-session model>' "$(basename "$file") accepts primary model"
  require_text "$file" '`assisting_model` is Git attribution metadata only' "$(basename "$file") keeps attribution separate from runtime"
  require_text "$file" 'MUST NOT select or override this writer' "$(basename "$file") forbids runtime override"
  require_text "$file" 'Accept `GPT-5`, `GPT-5.6`, or `GPT-6`' "$(basename "$file") accepts available model precision"
  require_text "$file" 'omit `AI-Assisted-By` and report the omission' "$(basename "$file") omits unknown model transparently"
  forbid_text "$file" 'Reject a missing value or a generic model-family label' "$(basename "$file") removes exact-model gate"
  require_text "$file" 'documentation' "$(basename "$file") does not resolve identity from documentation"
  require_text "$file" 'session logs' "$(basename "$file") does not parse session logs"
  require_text "$file" 'AI-Assisted-By: <assisting_model>' "$(basename "$file") records primary model"
  add_line="$(line_of "$file" 'git add -A')"
  diff_line="$(line_of "$file" 'git diff --cached --stat')"
  if [[ -n "$add_line" && -n "$diff_line" ]] && (( add_line < diff_line )); then
    ok "$(basename "$file") stages before reading cached diff"
  else
    bad "$(basename "$file") stages before reading cached diff"
  fi
  standalone_line="$(line_of "$file" '### Standalone context resolution')"
  if [[ -n "$add_line" && -n "$standalone_line" ]] && (( add_line < standalone_line )); then
    ok "$(basename "$file") stages before standalone resolution"
  else
    bad "$(basename "$file") stages before standalone resolution"
  fi
done

require_text "$COMMIT_SKILL" 'model name available in the current runtime context automatically' "standalone commit uses available runtime name"
require_text "$COMMIT_SKILL" 'MUST NOT ask the user to repeat it' "standalone commit avoids repeated confirmation"
require_text "$COMMIT_SKILL" 'later standalone commits in that session' "standalone attribution survives later commits"
require_text "$COMMIT_SKILL" 'Provider-native documentation and commit subagents MUST NOT replace or make root-session attribution ambiguous' "portable writer ignores subagent model differences"

require_text "$CODEX_COMMIT_AGENT" '`assisting_model` is Git attribution metadata only' "Codex agent keeps attribution separate from runtime"
require_text "$CODEX_COMMIT_AGENT" 'MUST NOT select or override this writer' "Codex agent forbids runtime override"
require_text "$CODEX_COMMIT_AGENT" 'root-session model supplied as `assisting_model`' "Codex agent preserves root-session attribution"
require_text "$CODEX_COMMIT_AGENT" "MUST NOT resolve it from this commit-only agent's runtime identity" "Codex agent cannot self-attribute"
require_text "$CODEX_COMMIT_AGENT" 'Accept `GPT-5`, `GPT-5.6`, or `GPT-6`' "Codex agent accepts available model precision"
require_text "$CODEX_COMMIT_AGENT" 'omit `AI-Assisted-By` and report the' "Codex agent reports omitted model"
forbid_text "$CODEX_COMMIT_AGENT" 'Reject a' "Codex agent removes exact-model gate"
require_text "$CODEX_COMMIT_AGENT" 'documentation' "Codex agent does not resolve identity from documentation"
require_text "$CODEX_COMMIT_AGENT" 'session logs' "Codex agent does not parse session logs"

require_text "$COMMIT_SKILL" 'ask the user to select one' "portable skill asks on associated ambiguity"
require_text "$COMMIT_SKILL" 'Codex <noreply@openai.com>' "portable skill maps Codex email"
require_text "$COMMIT_SKILL" 'Claude Code <noreply@anthropic.com>' "portable skill maps Claude Code email"
require_text "$COMMIT_SKILL" 'Co-Authored-By: <tool_name>' "portable skill keeps unmapped tool name"
require_text "$COMMIT_SKILL" 'MUST NOT guess' "portable skill forbids guessed attribution"
require_text "$COMMIT_AGENT" 'stop and list them' "Claude agent stops on associated ambiguity"
require_text "$COMMIT_AGENT" 'Claude Code <noreply@anthropic.com>' "Claude agent uses verified tool mapping"
require_text "$COMMIT_AGENT" 'collaborating root-session model' "Claude agent records current collaboration"
require_text "$COMMIT_AGENT" 'root-session model supplied as `assisting_model`' "Claude agent preserves root-session attribution"
require_text "$COMMIT_AGENT" "MUST NOT resolve it from this commit-only agent's runtime identity" "Claude agent cannot self-attribute"

for file in "$COMMIT_SKILL" "$COMMIT_AGENT"; do
  coauthor_line="$(line_of "$file" 'Co-Authored-By:')"
  assisted_line="$(line_of "$file" 'AI-Assisted-By: <assisting_model>')"
  if [[ -n "$coauthor_line" && -n "$assisted_line" ]] && (( coauthor_line < assisted_line )); then
    ok "$(basename "$file") orders tool attribution before model metadata"
  else
    bad "$(basename "$file") orders tool attribution before model metadata"
  fi
done
fi

# ── extend-openspec-commit-delivery ──────────────────────────────────────────
# Maps to openspec/changes/extend-openspec-commit-delivery specs/openspec-commit.
# Static checks pin the documented decisions; the rehearsal below runs the
# documented Git evidence commands against a disposable local bare remote. No
# GitHub call is made; gh/MCP behavior is covered by the replay cases.
REFS="$ROOT/template/common/skills/openspec-commit/references"
CASES="$REFS/acceptance-cases.md"
EXAMPLES="$REFS/examples.md"
LOCAL_DOC="$ROOT/docs/workflow/local-development.md"
instr() { grep -vE '^- (禁止|Forbidden)：|^\| ' "$1" 2>/dev/null; }   # instructions, not prohibitions or tables
case_titles() { grep -E '^### OC-[0-9]+' "$CASES" 2>/dev/null; }
want_case() { case_titles | grep -qF -- "$1" && ok "case for '$1'" || bad "case for '$1'"; }

if run_section delivery; then
printf '\ndelivery intent (1.1)\n'
require_text "$ORCHESTRATOR" '## Delivery intent' "delivery intent is resolved up front"
for path in 'Local completion' 'Successful PR handoff' 'Abandoned PR closure'; do
  require_text "$ORCHESTRATOR" "**$path**" "names the '$path' path"
done
require_text "$ORCHESTRATOR" 'A local commit request does not authorize push' "local commit does not imply remote writes"
require_text "$ORCHESTRATOR" 'A missing PR never blocks local completion' "no PR does not block local work"
require_text "$ORCHESTRATOR" 'Never create a PR or an Issue' "workflow creates no PR or Issue"
require_text "$ORCHESTRATOR" 'An unknown PR or target is not permission' "unknown remote target is reported separately"
if instr "$ORCHESTRATOR" | grep -qE 'gh pr create|gh pr merge|gh pr close|gh issue close|--force|--no-verify|--delete-branch'; then
  bad "instructions never create, merge, close, force or bypass hooks"
else
  ok "instructions never create, merge, close, force or bypass hooks"
fi

printf '\nlocal core preserved (1.2)\n'
require_text "$ORCHESTRATOR" 'belongs to other work' "unrelated work stops whole-worktree staging"
require_text "$ORCHESTRATOR" '## Stage outcomes' "stage outcomes are reported separately"
for stage in 'archive' 'docs' 'commit' 'push' 'PR update' 'final review' 'Closure' 'close'; do
  sed -n '/^## Stage outcomes/,/^## /p' "$ORCHESTRATOR" | grep -qF -- "| $stage |" \
    && ok "stage outcome row for '$stage'" || bad "stage outcome row for '$stage'"
done

printf '\nsuccessful handoff (2.1)\n'
step7="$(line_of "$ORCHESTRATOR" '## Step 7 — Remote delivery')"
step6="$(line_of "$ORCHESTRATOR" '## Step 6 — Verify and summarize')"
[[ -n "$step7" && -n "$step6" ]] && (( step6 < step7 )) \
  && ok "remote delivery follows local completion" || bad "remote delivery follows local completion"
for cmd in 'git remote get-url --push <remote>' 'git push <remote> HEAD:refs/heads/<head-branch>' \
           'git ls-remote <remote> refs/heads/<head-branch>'; do
  require_text "$ORCHESTRATOR" "$cmd" "documents '$cmd'"
done
for cap in 'github-pr update' 'github-pr reply' 'change-review'; do
  require_text "$ORCHESTRATOR" "$cap" "delegates to $cap"
done
require_text "$ORCHESTRATOR" 'An earlier pass never covers a new head' "old pass does not cover a new head"
require_text "$ORCHESTRATOR" 'ready for an authorized merge' "success ends at ready-to-merge Closure"
# codex-sol-commit-r01/F-03: pin the intended completion SHA before update.
require_text "$ORCHESTRATOR" 'intended_sha=<completion commit>' "intended completion SHA is pinned"
require_text "$ORCHESTRATOR" 'gh pr view <number> -R <host>/<owner>/<repo> --json headRefOid' "PR head is read before update"
require_text "$ORCHESTRATOR" 'all three must be the same SHA' "commit, remote and PR head must agree before update"
require_text "$ORCHESTRATOR" 'Never switch to delivering the newer head' "a moved head is not delivered instead"
want_case 'push 後 update 前 head 移動'
# Non-blocking review note: timeout example matches the retry rule.
require_text "$EXAMPLES" 'confirmed not posted' "timeout example covers the confirmed-absent retry"
require_text "$EXAMPLES" 'still unclear' "timeout example keeps the unclear state"
forbid_text "$EXAMPLES" 'no matching comment found on re-read;' "timeout example drops the old not-resent wording"

printf '\nabandoned closure (2.2)\n'
require_text "$ORCHESTRATOR" 'github-pr close' "abandoned PRs delegate to github-pr close"
require_text "$ORCHESTRATOR" 'Successful handoff never uses close' "success never closes"
require_text "$ORCHESTRATOR" 'no preliminary Closure of its own' "no duplicate Closure before delegated close"
require_text "$ORCHESTRATOR" 'does not need a passing review' "cancellation needs no pass"
require_text "$ORCHESTRATOR" 'abandoned local work is not pushed' "abandoned work is not published"

printf '\nrecovery after commit (3.1)\n'
require_text "$ORCHESTRATOR" '## Recovery after commit' "post-commit recovery section"
require_text "$ORCHESTRATOR" 'git log -1 --format=%H -- openspec/changes/archive/<archive-dir>/' "committed archive is found by exact path"
require_text "$ORCHESTRATOR" 'no persistent state file' "no new state registry"
for row in 'Commit confirmed, push missing' 'Push confirmed, PR update missing' 'Closure confirmed, close missing' 'Any result unknown'; do
  sed -n '/^## Recovery after commit/,/^## /p' "$ORCHESTRATOR" | grep -qF -- "$row" \
    && ok "recovery row '$row'" || bad "recovery row '$row'"
done
forbid_text "$ORCHESTRATOR" 'ls -t openspec/changes/archive/' "recovery never picks the newest archive"

printf '\nreferences and cases (1.1 / 3.2)\n'
require_text "$ORCHESTRATOR" 'references/acceptance-cases.md' "skill links its replay cases"
require_text "$ORCHESTRATOR" 'references/examples.md' "skill links its examples"
n="$(case_titles | wc -l | tr -d ' ')"
[[ "${n:-0}" -ge 20 ]] && ok "at least 20 replay cases ($n)" || bad "at least 20 replay cases ($n)"
for label in 'Fixture：' '模擬回覆：' '預期呼叫：' '禁止：' '判定：'; do
  c="$(grep -cF -- "- $label" "$CASES" 2>/dev/null | tr -d ' ')"
  [[ "${c:-0}" -ge "${n:-999}" && "${n:-0}" -gt 0 ]] && ok "every case states '$label'" || bad "every case states '$label' (${c:-0}/${n:-0})"
done
for t in '只要求本地' '沒有 PR' 'PR 查找不明' '有 PR 未授權' '成功交付' '最終 head 變動' '舊 pass' \
         '未授權複審' 'Review 未通過' 'push 被拒' '取消 close' '被取代' '缺少 close 授權' '已 merged' \
         'commit 後 push 失敗' 'push 後 update 失敗' 'Closure 後 close 失敗' 'Closure 結果不明' \
         '多個已提交 archive' '缺少恢復證據' '混有其他工作' '模型未知'; do
  want_case "$t"
done
for term in '## Stage outcomes' 'Closure' 'not performed' 'uncertain'; do
  require_text "$EXAMPLES" "$term" "examples show '$term'"
done
if grep -E '^- 預期呼叫：' "$CASES" 2>/dev/null | grep -qE 'gh pr merge|gh issue close|--force|git commit'; then
  bad "no expected call merges, closes an Issue, forces or commits outside the writer"
else
  ok "no expected call merges, closes an Issue, forces or commits outside the writer"
fi

printf '\nentrypoints stay thin (3.2)\n'
for f in "$CLAUDE_ENTRYPOINT" "$ANTIGRAVITY_ENTRYPOINT"; do
  if grep -qE 'git push|github-pr|gh pr' "$f"; then bad "$(basename "$f") adds no delivery logic"; else ok "$(basename "$f") adds no delivery logic"; fi
done
fi

if run_section rehearsal; then
printf '\nlocal bare-remote rehearsal (2.1 / 3.1)\n'
# codex-sol-commit-r01/F-04: every disposable repository sets its own identity
# and disables its own signing, so a user's global commit.gpgsign cannot break
# the fixture; required fixture commands must succeed or the run fails loudly.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fixture_ok=1
must() { "$@" >/dev/null 2>&1 || { bad "fixture command failed: $*"; fixture_ok=0; }; }
fixture_repo() {                   # $1 repo dir, $2 name
  must git -C "$1" config user.name "$2"
  must git -C "$1" config user.email "$2@example.invalid"
  must git -C "$1" config commit.gpgsign false
  must git -C "$1" config tag.gpgsign false
}
R="$T/remote.git"; W="$T/work"
must git init -q --bare "$R"; must git init -q -b main "$W"
g() { git -C "$W" "$@"; }
fixture_repo "$W" Test
printf 'base\n' > "$W/README.md"; must g add -A; must g commit -q -m "chore: base"
must g remote add origin "$R"; must g push -q origin main:refs/heads/main
must g switch -q -c feature/add-x; must g push -q origin HEAD:refs/heads/feature/add-x
reviewed="$(g rev-parse HEAD)"
ARCH="openspec/changes/archive/2026-11-14-add-x"
mkdir -p "$W/$ARCH"; printf 'p\n' > "$W/$ARCH/proposal.md"; printf 'doc\n' > "$W/README.md"
must g add -A; must g commit -q -m "feat(add-x): archive and document"
done_sha="$(g rev-parse HEAD)"; intended_sha="$done_sha"
[[ -z "$(g status --short)" ]] && ok "committed archive is invisible to git status" || bad "committed archive is invisible to git status"
[[ "$(g log -1 --format=%H -- "$ARCH/")" == "$done_sha" ]] \
  && ok "exact archive path resolves the completion commit" || bad "exact archive path resolves the completion commit"
[[ "$(g remote get-url --push origin)" == "$R" ]] && ok "push destination is the verified remote" || bad "push destination is the verified remote"
[[ "$(g ls-remote origin refs/heads/feature/add-x | cut -f1)" != "$done_sha" ]] \
  && ok "remote lacks the completion commit, so only push is missing" || bad "remote lacks the completion commit, so only push is missing"
count="$(g rev-list --count HEAD)"
g push -q origin HEAD:refs/heads/feature/add-x 2>/dev/null && ok "resumed push succeeds without a new commit" || bad "resumed push succeeds without a new commit"
[[ "$(g ls-remote origin refs/heads/feature/add-x | cut -f1)" == "$intended_sha" && "$(g rev-list --count HEAD)" == "$count" ]] \
  && ok "remote head equals the intended completion SHA; commit count unchanged" || bad "remote head equals the intended completion SHA; commit count unchanged"
[[ "$done_sha" != "$reviewed" ]] && ok "the published head differs from the earlier reviewed head" || bad "the published head differs from the earlier reviewed head"
# codex-sol-commit-r01/F-03: another writer moves the branch after our push and
# before the PR update; the intended-SHA check must see the difference.
O="$T/other"; must git clone -q "$R" "$O"; fixture_repo "$O" Other
must git -C "$O" switch -q feature/add-x
printf 'o\n' > "$O/o.txt"; must git -C "$O" add o.txt; must git -C "$O" commit -q -m "chore: other"
must git -C "$O" push -q origin HEAD:refs/heads/feature/add-x; moved="$(git -C "$O" rev-parse HEAD)"
observed="$(g ls-remote origin refs/heads/feature/add-x | cut -f1)"
[[ "$fixture_ok" == 1 && "$observed" == "$moved" && "$observed" != "$intended_sha" ]] \
  && ok "head moved after push: remote differs from the intended SHA, so update stops" \
  || bad "head moved after push: remote differs from the intended SHA, so update stops"
mkdir -p "$W/openspec/changes/archive/2026-11-15-add-x"; printf 'q\n' > "$W/openspec/changes/archive/2026-11-15-add-x/proposal.md"
must g add -A; must g commit -q -m "chore: second archive"
m="$(g log --format= --name-only -- ':(glob)openspec/changes/archive/*-add-x/**' | grep . | cut -d/ -f4 | sort -u | wc -l | tr -d ' ')"
[[ "$m" == 2 ]] && ok "two committed archives for one id are detected as ambiguous" || bad "two committed archives for one id are detected as ambiguous"
if g push -q origin HEAD:refs/heads/feature/add-x 2>/dev/null; then bad "a non-fast-forward push is rejected"; else ok "a non-fast-forward push is rejected"; fi
[[ "$(g ls-remote origin refs/heads/feature/add-x | cut -f1)" == "$moved" ]] \
  && ok "rejected push leaves the moved remote head untouched" || bad "rejected push leaves the moved remote head untouched"
[[ "$fixture_ok" == 1 ]] && ok "every required fixture command succeeded" || bad "every required fixture command succeeded"
fi

if run_section docs; then
printf '\nlocal development docs (4.1)\n'
[[ -f "$LOCAL_DOC" ]] && ok "local development doc exists" || bad "local development doc exists"
for f in type title description tags; do grep -qE "^$f:" "$LOCAL_DOC" 2>/dev/null && ok "doc frontmatter '$f'" || bad "doc frontmatter '$f'"; done
for s in define implement review finish; do
  for ext in svg png; do
    p="$ROOT/docs/diagrams/local-development-$s.$ext"
    [[ -f "$p" ]] && ok "diagram $s.$ext exists" || bad "diagram $s.$ext exists"
  done
  require_text "$LOCAL_DOC" "../diagrams/local-development-$s.svg" "doc links $s.svg"
  require_text "$LOCAL_DOC" "../diagrams/local-development-$s.png" "doc links $s.png"
  svg="$ROOT/docs/diagrams/local-development-$s.svg"
  if command -v xmllint >/dev/null 2>&1; then xmllint --noout "$svg" 2>/dev/null && ok "$s.svg is well-formed" || bad "$s.svg is well-formed"; fi
  require_text "$svg" '<title' "$s.svg has a title"
  require_text "$svg" '圖例' "$s.svg has a legend"
done
forbid_text "$LOCAL_DOC" 'work-items/WI-' "doc does not depend on Work Item paths"
require_text "$LOCAL_DOC" '人工發布檢核' "doc keeps manual publication checkpoints"
require_text "$LOCAL_DOC" 'github-pr close' "doc shows the cancellation branch"
require_text "$LOCAL_DOC" 'merge' "doc leaves merge to separate authorization"
require_text "$LOCAL_DOC" 'github-handoff.md' "doc links the shared GitHub contract"
require_text "$ROOT/docs/workflow/guide.md" 'local-development.md' "workflow guide links the doc"
require_text "$ROOT/docs/workflow/commit.md" 'local-development.md' "commit playbook links the doc"
forbid_text "$ROOT/template/common/docs/agent-protocol.md" 'local-development' "personal flow stays out of the managed protocol"
[[ ! -e "$ROOT/template/common/docs/workflow/local-development.md" ]] \
  && ok "personal flow is not a managed template" || bad "personal flow is not a managed template"
fi

if run_section install; then
printf '\ninstallation (5.1)\n'
SRC="$ROOT/template/common/skills/openspec-commit"
TI="$(mktemp -d)"; mkdir -p "$TI/repo"; git init -q -b main "$TI/repo"
mkdir -p "$TI/repo/.claude/skills/third-party" "$TI/repo/work-items/WI-20260101-keep"
printf 'third\n' > "$TI/repo/.claude/skills/third-party/SKILL.md"; printf 'keep\n' > "$TI/repo/work-items/WI-20260101-keep/README.md"
bash "$ROOT/scripts/skills/install.sh" --target "$TI/repo" >/dev/null 2>&1
printf 'stale\n' > "$TI/repo/.claude/skills/openspec-commit/references/acceptance-cases.md" 2>/dev/null
bash "$ROOT/scripts/skills/install.sh" --target "$TI/repo" >/dev/null 2>&1
diff -r "$SRC" "$TI/repo/.claude/skills/openspec-commit" >/dev/null 2>&1 && diff -r "$SRC" "$TI/repo/.agents/skills/openspec-commit" >/dev/null 2>&1 \
  && ok "skill and references reach both skill roots after reinstall" || bad "skill and references reach both skill roots after reinstall"
[[ "$(cat "$TI/repo/.claude/skills/third-party/SKILL.md")" == third && -f "$TI/repo/work-items/WI-20260101-keep/README.md" ]] \
  && ok "third-party skill and Work Item survive" || bad "third-party skill and Work Item survive"
[[ ! -e "$TI/repo/docs/workflow/local-development.md" ]] && ok "personal flow doc is not installed" || bad "personal flow doc is not installed"
rm -rf "$TI"
diff -r "$SRC" "$ROOT/.claude/skills/openspec-commit" >/dev/null 2>&1 && diff -r "$SRC" "$ROOT/.agents/skills/openspec-commit" >/dev/null 2>&1 \
  && ok "repository openspec-commit synchronized" || bad "repository openspec-commit synchronized"
fi

printf '\n'
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
