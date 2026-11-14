#!/usr/bin/env bash
# Verifies the GitHub change-handoff capability (revision transport-native-r01):
# the shared contract and its diagram are managed assets that reinstall refreshes;
# the retired identity-check script is no longer shipped, required, or called, and
# an unmodified legacy copy is removed while anything else is left and reported;
# the thin rule and protocol point at the single contract; Work Items stay independent;
# and the two entry skills reference it instead of restating its schema.
# Maps to openspec/changes/add-github-change-handoff specs.
#
# These are contract-presence and installer-behavior checks. They do not replay
# agent decisions or real GitHub calls; those are recorded under
# docs/verification/github-handoff/.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
DOC="$COMMON/docs/github-handoff.md"
SVG="$COMMON/docs/diagrams/github-handoff.svg"
RULE="$COMMON/.claude/rules/github-handoff.md"
PROTO="$COMMON/docs/agent-protocol.md"
WORKFLOW="$COMMON/docs/openspec-workflow.md"
CONVENTION="$COMMON/work-items/AGENTS.md"
ISSUE_SKILL="$COMMON/skills/github-issue"
PR_SKILL="$COMMON/skills/github-pr"
LEGACY="scripts/github/check-identity.sh"
LEGACY_REV="5348897"               # the only revision that shipped the retired script
MANAGED="docs/github-handoff.md docs/diagrams/github-handoff.svg"
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
has() { grep -Fq -- "$2" "$1" 2>/dev/null; }                 # $1 file, $2 fixed string
want() { if has "$1" "$2"; then ok "$3"; else bad "$3"; fi; }
deny() { if has "$1" "$2"; then bad "$3"; else ok "$3"; fi; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT
new_target() {
  local d; d="$(mktemp -d "$TMPROOT/t.XXXXXX")"
  mkdir -p "$d/repo"; git init -q -b main "$d/repo"
  printf '%s\n' "$d/repo"
}
run_install() { bash "$ROOT/scripts/skills/install.sh" --target "$1" > "$1/../install.log" 2>&1; }
log_of() { cat "$1/../install.log" 2>/dev/null; }
sum1() { shasum "$1" 2>/dev/null | awk '{print $1}'; }

# ── 1.1 Shared contract: target, operation, authorization, readback ──────────
echo "1.1 shared contract"
[[ -f "$DOC" ]] && ok "contract source exists" || bad "contract source exists"
want "$DOC" 'Managed by wk-agent-ops' "contract carries the managed banner"
missing=""
for field in type title description tags generated; do
  grep -qE "^${field}:" "$DOC" 2>/dev/null || missing="$missing $field"
done
[[ -z "$missing" ]] && ok "contract frontmatter complete" || bad "contract frontmatter complete (missing:$missing)"
if grep -qiE '\bcodex\b|antigravity' "$DOC" "$RULE" 2>/dev/null; then
  bad "contract and rule name no secondary tool"
else
  ok "contract and rule name no secondary tool"
fi
want "$DOC" '<!-- wk-agent-ops:handoff:start -->' "managed block start marker defined"
want "$DOC" '<!-- wk-agent-ops:handoff:end -->'   "managed block end marker defined"
want "$DOC" 'openspec-change:' "exact Change association key defined"
want "$DOC" 'repository:'      "exact repository association key defined"
want "$DOC" 'host／owner／repo' "full repository target is the unit of comparison"
want "$DOC" 'GitHub MCP'        "contract allows a configured GitHub MCP"
want "$DOC" '讀取權限不等於寫入權限' "read access is not write permission"
want "$DOC" '不額外建立' "no probe writes to test permission"
want "$DOC" '回讀' "results are read back before completion"
want "$DOC" '不換工具重送' "uncertain writes are reconciled before switching tools"
want "$DOC" 'design-approval'                 "design-approval record defined"
want "$DOC" 'human-github'                    "human approval source kind defined"
want "$DOC" 'agent-attested-user-instruction' "attested approval source kind defined"
want "$DOC" 'superseded'                      "superseded approval state defined"
want "$DOC" 'changes-required' "review verdict vocabulary defined"
want "$DOC" 'review-id'        "review identifier defined"
want "$DOC" 'withheld'         "withheld provenance state defined"
want "$DOC" 'Refs #'           "issue reference uses a non-closing keyword"
want "$DOC" 'docs/verification/github-handoff/' "formal evidence location defined"
cases="$(grep -cE '^### C-[0-9]+' "$DOC" 2>/dev/null | tr -d ' ')"
[[ "${cases:-0}" -ge 24 ]] && ok "at least 24 shared cases (${cases:-0})" || bad "at least 24 shared cases (${cases:-0})"
for label in 'Fixture：' '模擬回覆：' '預期呼叫：' '禁止：' '判定：'; do
  n="$(grep -cF -- "- $label" "$DOC" 2>/dev/null | tr -d ' ')"
  [[ "${n:-0}" -ge "${cases:-999}" && "${cases:-0}" -gt 0 ]] \
    && ok "every shared case states '$label'" || bad "every shared case states '$label' (${n:-0}/${cases:-0})"
done

# ── 1.2 Retired identity script: not shipped, not required, not called ───────
echo "1.2 retired identity script"
[[ ! -e "$COMMON/$LEGACY" ]] && ok "template no longer ships $LEGACY" || bad "template no longer ships $LEGACY"
if awk '/^MANAGED_FILES=\(/{f=1} f&&/^\)/{exit} f' "$ROOT/scripts/skills/install.sh" | grep -qF "$LEGACY"; then
  bad "installer no longer lists the script as managed"
else
  ok "installer no longer lists the script as managed"
fi
for f in "$RULE" "$PROTO" "$ISSUE_SKILL/SKILL.md" "$PR_SKILL/SKILL.md" \
         "$ISSUE_SKILL/references/acceptance-cases.md" "$PR_SKILL/references/acceptance-cases.md" \
         "$COMMON/AGENTS.md" "$ROOT/README.md"; do
  if grep -qE 'check-identity|policy[_-]source|script-blob|GitHub handoff identity' "$f" 2>/dev/null; then
    bad "${f#"$ROOT"/} no longer requires the script or identity policy"
  else
    ok "${f#"$ROOT"/} no longer requires the script or identity policy"
  fi
done
deny "$DOC" 'bash scripts/github/check-identity.sh' "contract does not tell anyone to run the script"
deny "$DOC" 'policy_source' "contract has no mandatory policy snapshot"

# ── F-01 / 1.4 Secrets never enter output, records or commands ───────────────
echo "F-01 secrets and credential reconstruction"
want "$DOC" '不解析 credential helper' "contract forbids reconstructing credentials"
want "$DOC" 'helper 的設定內容' "contract forbids copying helper contents into records"
# Prohibition lists may name these actions; instructions and expected calls must not use them.
CRED_CMD='credential fill|ssh -T|get-regexp .*credential|config .*credential\.'
instructions() {                   # $1 file: every line except case prohibitions
  grep -vE '^- (禁止|Forbidden)：' "$1" 2>/dev/null
}
for f in "$DOC" "$ISSUE_SKILL/SKILL.md" "$PR_SKILL/SKILL.md" \
         "$ISSUE_SKILL/references/acceptance-cases.md" "$PR_SKILL/references/acceptance-cases.md"; do
  if instructions "$f" | grep -vE '^\| ' | grep -qE "$CRED_CMD"; then
    bad "${f#"$ROOT"/} instructs no credential-reading or SSH principal command"
  else
    ok "${f#"$ROOT"/} instructs no credential-reading or SSH principal command"
  fi
done

# ── 1.3 Optional, explicit account restrictions; independent recorders ───────
echo "1.3 account restrictions and approval recorders"
want "$DOC" '預設不限制帳號' "no account restriction by default"
want "$DOC" '明示限制' "explicit restrictions are checked when present"
want "$DOC" '不能由 repository 權限推導' "recorder authority is not derived from repo access"
want "$DOC" 'unavailable' "unknown actors are recorded honestly"

# ── 1.3 / 1.4 Review report baseline ─────────────────────────────────────────
echo "1.4 review baseline"
for heading in '## Scope and Baseline' '## Findings' '## Summary and Limitations'; do
  want "$DOC" "$heading" "review template has '$heading'"
done
for field in 'Session-ID：' 'Session-ID source：' 'Session-Alias：' 'Machine-Alias：' \
             'AI-Assisted-By：' 'Git branches：' 'PR base SHA：' 'reviewed head SHA' \
             'Checkout HEAD：' '未提交內容：' '文件快照：' '實際執行的檢查與結果：'; do
  want "$DOC" "$field" "baseline field '$field'"
done

# ── 3.3 Lifecycle manual and diagram ─────────────────────────────────────────
echo "3.3 lifecycle manual and diagram"
want "$DOC" 'diagrams/github-handoff.svg' "contract links its diagram"
[[ -f "$SVG" ]] && ok "diagram source exists" || bad "diagram source exists"
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$SVG" 2>/dev/null && ok "diagram is well-formed XML" || bad "diagram is well-formed XML"
fi
want "$SVG" '<title' "diagram has a title"
want "$SVG" '<desc'  "diagram has a description"
want "$SVG" '圖例'   "diagram has a text legend"
want "$SVG" 'MCP'    "diagram shows the gh or MCP channel"
deny "$SVG" '共用腳本' "diagram no longer shows the retired script"
deny "$SVG" '既有實作待調整' "diagram is not labelled as pending implementation"
broken=""
while read -r ref; do
  [[ -z "$ref" ]] && continue
  [[ -e "$COMMON/docs/$ref" ]] || broken="$broken $ref"
done < <(grep -oE '\]\([^)#]+\.(md|svg)(#[^)]*)?\)' "$DOC" 2>/dev/null \
          | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' | grep -vE '^https?://' | sort -u)
[[ -z "$broken" ]] && ok "every relative link in the contract resolves" || bad "every relative link in the contract resolves (broken:$broken)"

# ── 1.2 Entries: thin rule, protocol, workflow, Work Item boundary ───────────
echo "1.2 entries and Work Item boundary"
[[ -f "$RULE" ]] && ok "rule entry exists in the template" || bad "rule entry exists in the template"
want "$RULE" 'docs/github-handoff.md' "rule points at the single contract"
if [[ -f "$RULE" ]] && [[ "$(wc -l < "$RULE" | tr -d ' ')" -le 30 ]]; then
  ok "rule entry stays short"; else bad "rule entry stays short"; fi
if [[ -f "$RULE" && "$(grep -c '^- ' "$RULE" | tr -d ' ')" == 0 ]]; then
  ok "rule entry carries no rule list"; else bad "rule entry carries no rule list"; fi
want "$RULE" '不是 hook' "rule does not present itself as a hook"
if grep -qE 'openspec-change:|approved_by|Session-ID' "$RULE" 2>/dev/null; then
  bad "rule restates no contract schema"; else ok "rule restates no contract schema"; fi
want "$PROTO" 'docs/github-handoff.md' "protocol references the contract"
grep -qE '^\| Version \| 2\.7\.0' "$PROTO" 2>/dev/null \
  && ok "protocol version bumped" || bad "protocol version bumped"
want "$WORKFLOW" 'github-handoff.md' "OpenSpec workflow links the contract"
want "$WORKFLOW" 'optional' "OpenSpec workflow keeps GitHub handoff optional"
deny "$CONVENTION" '../docs/github-handoff.md' "Work Item convention does not depend on the GitHub contract"
deny "$DOC" '../work-items/AGENTS.md' "GitHub contract owns its schema without importing Work Item policy"
want "$CONVENTION" 'Review 先寫在**當前目錄的 Work Item** 內' "local Review mode remains the default"
want "$CONVENTION" '不上傳、同步或公開整個 Work Item' "Work Item is not uploaded or synchronized"
want "$CONVENTION" '不跨 worktree 自動搬移、複製、搜尋補回或同步' "existing no-sync rule preserved"

# ── 2.x / 3.x Entry skills reference the contract ───────────────────────────
echo "2-3 entry skills"
for skill in "$ISSUE_SKILL" "$PR_SKILL"; do
  name="$(basename "$skill")"
  [[ -f "$skill/SKILL.md" ]] && ok "$name SKILL.md exists" || bad "$name SKILL.md exists"
  grep -qE "^name: $name\$" "$skill/SKILL.md" 2>/dev/null \
    && ok "$name frontmatter name matches directory" || bad "$name frontmatter name matches directory"
  grep -qE '^description:' "$skill/SKILL.md" 2>/dev/null \
    && ok "$name has a description" || bad "$name has a description"
  want "$skill/SKILL.md" 'docs/github-handoff.md' "$name reads the shared contract"
  want "$skill/SKILL.md" 'MCP' "$name allows a configured GitHub MCP"
  want "$skill/SKILL.md" 'references/acceptance-cases.md' "$name links its replay cases"
  if grep -qE 'approved_by|## Scope and Baseline|wk-agent-ops:handoff:start' "$skill/SKILL.md" 2>/dev/null; then
    bad "$name restates no contract schema"
  else
    ok "$name restates no contract schema"
  fi
  [[ -f "$skill/references/acceptance-cases.md" ]] \
    && ok "$name replay cases exist" || bad "$name replay cases exist"
done
gi="$(grep -cE '^### GI-[0-9]+' "$ISSUE_SKILL/references/acceptance-cases.md" 2>/dev/null | tr -d ' ')"
[[ "${gi:-0}" -ge 15 ]] && ok "github-issue has at least 15 cases (${gi:-0})" || bad "github-issue has at least 15 cases (${gi:-0})"
gp="$(grep -cE '^### GP-[0-9]+' "$PR_SKILL/references/acceptance-cases.md" 2>/dev/null | tr -d ' ')"
[[ "${gp:-0}" -ge 20 ]] && ok "github-pr has at least 20 cases (${gp:-0})" || bad "github-pr has at least 20 cases (${gp:-0})"
for op in create update; do
  grep -qE "^## .*\b$op\b" "$ISSUE_SKILL/SKILL.md" 2>/dev/null \
    && ok "github-issue defines $op" || bad "github-issue defines $op"
done
for op in create update reply close; do
  grep -qE "^## .*\b$op\b" "$PR_SKILL/SKILL.md" 2>/dev/null \
    && ok "github-pr defines $op" || bad "github-pr defines $op"
done
# simplify-github-pr: PR operations never publish Git content (old push-destination check retired).
grep -qE '^## .*\bpublish\b' "$PR_SKILL/SKILL.md" 2>/dev/null \
  && bad "github-pr no longer defines a publish operation" || ok "github-pr no longer defines a publish operation"
# Review codex-handoff-impl-s01-r01/W-01: the head repository is evidence, not an assumption.
for field in headRepository headRepositoryOwner baseRefName isCrossRepository; do
  want "$PR_SKILL/SKILL.md" "$field" "github-pr reads $field for candidates and results"
done
want "$PR_SKILL/SKILL.md" '--head <head-owner>:<head-branch>' "github-pr create names the head owner"
grep -E '^### GP-[0-9]+' "$PR_SKILL/references/acceptance-cases.md" 2>/dev/null | grep -qF 'fork' \
  && ok "github-pr has a fork replay case" || bad "github-pr has a fork replay case"

# ── simplify-github-issue 1.1: sources, minimal Issue body, Author ───────────
# Maps to openspec/changes/simplify-github-issue specs/github-issue.
echo "SGI-1 Issue sources and initial body"
ISSUE_CASES="$ISSUE_SKILL/references/acceptance-cases.md"
issue_section() { awk '/^### 6\.1 /{f=1;next} /^### 6\.2 /{f=0} f' "$DOC" 2>/dev/null; }
fence_headings() {                 # $1 = Nth fenced block in §6.1 → its "## " headings, one per line
  issue_section | awk -v n="$1" '/^```/{c++; next} c==2*n-1 && /^## /{print}'
}
initial="$(fence_headings 1 | tr '\n' '|')"
[[ "$initial" == '## Handoff|'*'## Goal|'*'## Author|' ]] \
  && ok "initial Issue body starts with Handoff, has Goal, ends with Author" \
  || bad "initial Issue body starts with Handoff, has Goal, ends with Author ($initial)"
for field in '- openspec-change:' '- work-item:' '- pull-request:' 'Co-Authored-By:' 'AI-Assisted-By:'; do
  issue_section | grep -qF -- "$field" && ok "Issue template has '$field'" || bad "Issue template has '$field'"
done
for field in 'wk-agent-ops:handoff:start' '- repository:' '### Provenance' 'Machine-Alias' 'Session:' '- owner:' '- next-action:'; do
  issue_section | grep -qF -- "$field" && bad "Issue template drops '$field'" || ok "Issue template drops '$field'"
done
want "$ISSUE_SKILL/SKILL.md" 'Work Item' "github-issue accepts a Work Item source"
want "$ISSUE_SKILL/SKILL.md" 'Session-only' "github-issue allows session-only creation"
want "$ISSUE_SKILL/SKILL.md" 'work-items/WI-*/README.md' "github-issue reads Work Items directly, not via ignore-aware search"
want "$ISSUE_SKILL/SKILL.md" 'null' "github-issue fills absent identifiers with null"
sed -n '/^description:/,/^[a-z]*:/p' "$ISSUE_SKILL/SKILL.md" | grep -q 'Work Item' \
  && ok "github-issue description names Work Item sources" || bad "github-issue description names Work Item sources"
for t in 'Work Item 單獨' 'Change 單獨' 'Work Item 與 Change' '分支唯一' '分支歧義' '指定來源不存在' \
         'Session-only' '主題不足' '未知模型' 'local-only' '完整 tasks'; do
  grep -E '^### GI-[0-9]+' "$ISSUE_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-issue has a case for '$t'" || bad "github-issue has a case for '$t'"
done

# ── simplify-github-issue 2.1: comment-only update, legacy Issues, association ─
echo "SGI-2 Issue update appends a comment"
comment="$(fence_headings 2 | tr '\n' '|')"
# standardize-github-collaboration-records: every post carries Next actions before Author.
[[ "$comment" == '## Handoff|## Changes|## Next actions|## Author|' ]] \
  && ok "update comment is Handoff → Changes → Next actions → Author" \
  || bad "update comment is Handoff → Changes → Next actions → Author ($comment)"
update_part() { sed -n '/^## Operation: update/,/^## Reporting/p' "$ISSUE_SKILL/SKILL.md" 2>/dev/null; }
update_part | grep -qF 'gh issue comment' && ok "github-issue update posts a comment" || bad "github-issue update posts a comment"
update_part | grep -qF 'comments' && ok "github-issue update reads existing comments" || bad "github-issue update reads existing comments"
# Body edits may appear only as prohibitions; no instruction or expected call may use them.
for f in "$ISSUE_SKILL/SKILL.md" "$ISSUE_CASES" "$ISSUE_SKILL/references/examples.md"; do
  if instructions "$f" | grep -qE 'gh issue edit|issue comment .*--edit|--edit-last'; then
    bad "${f#"$ROOT"/} never instructs an Issue body or comment edit"
  else
    ok "${f#"$ROOT"/} never instructs an Issue body or comment edit"
  fi
done
if grep -qiE 'adopt|接管|wk-agent-ops:handoff' "$ISSUE_SKILL/SKILL.md" "$ISSUE_SKILL/references/examples.md" 2>/dev/null; then
  bad "github-issue has no managed-block adoption"; else ok "github-issue has no managed-block adoption"; fi
for t in '人工正文' '完整標記' '破損標記' '連續兩輪' '留言關聯' 'null 不是' '多個候選' 'ID 衝突' \
         '只有 comment' '留言逾時' '回讀失敗' '指定 Issue'; do
  grep -E '^### GI-[0-9]+' "$ISSUE_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-issue has a case for '$t'" || bad "github-issue has a case for '$t'"
done

# ── simplify-github-issue 3.1: shared rules separate Issue from PR / Review ──
echo "SGI-3 shared contract scopes managed-body rules to PR"
doc_section() { awk -v s="^## $1\\\\." -v e="^## $2\\\\." '$0~s{f=1} $0~e{f=0} f' "$DOC" 2>/dev/null; }
doc_section 5 6 | grep -qF '已知明確的 Issue／PR URL' \
  && bad "§5 exact-key lookup no longer covers Issues" || ok "§5 exact-key lookup no longer covers Issues"
doc_section 7 8 | grep -qF '第 6.1 節' \
  && ok "§7 provenance names the Issue Author exception" || bad "§7 provenance names the Issue Author exception"
doc_section 11 12 | grep -qF '第 6.1 節' \
  && ok "§11 body-update rules exclude Issues" || bad "§11 body-update rules exclude Issues"
deny "$DOC" 'Issue 的 `Waiting` 區段' "§10 no longer relies on an Issue Waiting block"
deny "$DOC" '`artifacts` 為 `local-only／待發布`' "Issue create case uses References, not artifacts"
for f in "$DOC" "$PR_SKILL/SKILL.md" "$PR_SKILL/references/acceptance-cases.md" \
         "$COMMON/skills/change-review/SKILL.md" "$COMMON/skills/change-review/references/acceptance-cases.md" \
         "$COMMON/skills/change-review/references/checklists.md" "$RULE"; do
  if instructions "$f" | grep -qE 'gh issue edit|Waiting 區段'; then
    bad "${f#"$ROOT"/} asks for no Issue body rewrite"
  else
    ok "${f#"$ROOT"/} asks for no Issue body rewrite"
  fi
done

# ── simplify-github-issue 5.x: sources are material, the Issue is a rewritten task ─
echo "SGI-4 source-to-content quality"
for label in '來源實文：' '產出 Issue：' '內容判定：'; do
  n="$(grep -cF -- "- $label" "$ISSUE_CASES" 2>/dev/null | tr -d ' ')"
  [[ "${n:-0}" -ge 3 ]] && ok "at least 3 source-to-content cases state '$label' (${n:-0})" \
    || bad "at least 3 source-to-content cases state '$label' (${n:-0})"
done
grep -E '^### GI-[0-9]+' "$ISSUE_CASES" 2>/dev/null | grep -qF '對話新決策' \
  && ok "github-issue has a case where the session overrides a recorded decision" \
  || bad "github-issue has a case where the session overrides a recorded decision"
deny "$ISSUE_CASES" '18 項細節任務' "no content case stands on a task count without the tasks"
deny "$ISSUE_SKILL/SKILL.md" 'stop at the first that applies' "explicit records do not exclude the session discussion"
want "$ISSUE_SKILL/SKILL.md" 'Always merge the relevant current-session discussion' "github-issue merges session decisions into named sources"
issue_section | grep -qF '不沿用 Work Item 的紀錄格式' \
  && ok "§6.1 requires rewriting sources into a task, not the record layout" \
  || bad "§6.1 requires rewriting sources into a task, not the record layout"
deny "$ISSUE_SKILL/references/examples.md" 'issues/7 合併' "example dependency names a mergeable PR, not an Issue"
want "$ISSUE_SKILL/references/examples.md" '/pull/' "example dependency links the PR whose merge releases it"

# Review r06 replay: a Change's task plan became Issue Tasks group-for-group.
want "$ISSUE_SKILL/SKILL.md" "not the plan's groups" "github-issue turns a task plan into checkable outcomes"
issue_section | grep -qF '不照搬實作計畫的群組' \
  && ok "§6.1 Tasks are outcomes, not the implementation plan" || bad "§6.1 Tasks are outcomes, not the implementation plan"

# Review r06 replay: a missing named source must halt; §3 must allow the C-20 fallback.
want "$ISSUE_SKILL/SKILL.md" 'stop and ask the user to confirm' "a missing named source halts before any remote call"
doc_section 3 4 | grep -qF '另一個已配置' \
  && ok "§3 lets another configured tool cover a missing capability" || bad "§3 lets another configured tool cover a missing capability"

# ── simplify-github-pr 1.x: sources, minimal PR frame, no Git writes ─────────
# Maps to openspec/changes/simplify-github-pr specs/github-pr.
echo "SGP-1 PR sources, frame and Git boundary"
PR_CASES="$PR_SKILL/references/acceptance-cases.md"
pr_section() { awk '/^### 6\.2 /{f=1;next} /^### 6\.3 /{f=0} f' "$DOC" 2>/dev/null; }
pr_fence() { pr_section | awk -v n="$1" '/^```/{c++; next} c==2*n-1 && /^## /{print}'; }
body="$(pr_fence 1 | tr '\n' '|')"
[[ "$body" == '## Handoff|'*'## Author|' ]] \
  && ok "PR body starts with Handoff and ends with Author" || bad "PR body starts with Handoff and ends with Author ($body)"
for field in '- branch:' 'Co-Authored-By:' 'AI-Assisted-By:' 'SESSION-ID:'; do
  pr_section | grep -qF -- "$field" && ok "PR template has '$field'" || bad "PR template has '$field'"
done
for field in '- brach:' 'wk-agent-ops:handoff:start' '### Provenance' '### design-approval' '### Reviews' '- phase:' '- owner:'; do
  pr_section | grep -qF -- "$field" && bad "PR template drops '$field'" || ok "PR template drops '$field'"
done
# streamline-github-pr-publication: only create may publish Git; update/reply/close never do.
nongit_part() { sed -n '/^## Operation: update/,/^## Reporting/p' "$PR_SKILL/SKILL.md" 2>/dev/null; }
if nongit_part | grep -vE '^- (禁止|Forbidden)：' | grep -qE 'git push|git commit|git add|git-commit-writer'; then
  bad "update, reply and close instruct no staging, commit or push"
else
  ok "update, reply and close instruct no staging, commit or push"
fi
want "$PR_SKILL/SKILL.md" 'publish` operation is removed' "github-pr keeps publish removed"
want "$PR_SKILL/SKILL.md" 'Always merge the relevant current-session discussion' "github-pr merges session decisions into named sources"
want "$PR_SKILL/SKILL.md" 'work-items/WI-*/README.md' "github-pr reads Work Items directly"
want "$PR_SKILL/SKILL.md" 'SESSION-ID' "github-pr fills the Author Session ID"
for label in '來源實文：' '產出 PR：' '內容判定：'; do
  n="$(grep -cF -- "- $label" "$PR_CASES" 2>/dev/null | tr -d ' ')"
  [[ "${n:-0}" -ge 3 ]] && ok "at least 3 PR source-to-content cases state '$label' (${n:-0})" \
    || bad "at least 3 PR source-to-content cases state '$label' (${n:-0})"
done
for t in '對話新決策' '未發布' '設計 PR' '沒有追蹤資料' '唯一既有 PR' '多個 PR' '缺少遠端分支' '空 diff' \
         'dirty checkout' 'plain body' 'legacy markers' '並行' '後補 Issue' '舊 publish' '未知 Session'; do
  grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-pr has a case for '$t'" || bad "github-pr has a case for '$t'"
done

# Replay r01 gaps: plan enumeration, approval discovery, review next step, merged-PR close.
want "$PR_SKILL/SKILL.md" 'without enumerating its groups' "github-pr links a task plan without enumerating it"
want "$PR_SKILL/SKILL.md" 'comments,reviews' "github-pr reads reviews when looking for approval events"
want "$PR_SKILL/SKILL.md" 'Apply still needs' "a design pass reminds that Apply still needs human approval"
pr_section | grep -qF '下一步：' && ok "review reply template has a next step" || bad "review reply template has a next step"
want "$PR_SKILL/SKILL.md" 'already merged or closed counts as ended' "close treats an already ended PR as confirmed"

# ── simplify-github-pr 2.x: replies and independent approval events ─────────
echo "SGP-2 PR replies and approval events"
review="$(pr_fence 2 | tr '\n' '|')"; changes="$(pr_fence 3 | tr '\n' '|')"
[[ "$review" == '## Handoff|## Review|## Verification|## Next actions|## Author|' ]] \
  && ok "reviewer reply is Handoff → Review → Verification → Next actions → Author" \
  || bad "reviewer reply is Handoff → Review → Verification → Next actions → Author ($review)"
[[ "$changes" == '## Handoff|## Changes|## Next actions|## Author|' ]] \
  && ok "implementer reply is Handoff → Changes → Next actions → Author" \
  || bad "implementer reply is Handoff → Changes → Next actions → Author ($changes)"
pr_section | grep -qF -- '- pull-request:' && ok "reply Handoff names the PR" || bad "reply Handoff names the PR"
reply_part() { sed -n '/^## Operation: reply/,/^## Operation: close/p' "$PR_SKILL/SKILL.md" 2>/dev/null; }
reply_part | grep -qF 'gh pr comment' && ok "reply posts a top-level comment" || bad "reply posts a top-level comment"
reply_part | grep -qF 'reviewed head' && ok "reply binds review content to the reviewed head" || bad "reply binds review content to the reviewed head"
for label in '產出回覆：'; do
  n="$(grep -cF -- "- $label" "$PR_CASES" 2>/dev/null | tr -d ' ')"
  [[ "${n:-0}" -ge 2 ]] && ok "at least 2 reply generation cases (${n:-0})" || bad "at least 2 reply generation cases (${n:-0})"
done
for t in 'Reviewer 回覆' '實作者回覆' '沒有 finding' '無法完成' '既有留言'; do
  grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-pr has a case for '$t'" || bad "github-pr has a case for '$t'"
done
awk '/^### 6\.3 /{f=1;next} /^### 6\.4 /{f=0} f' "$DOC" | grep -qF -- '- status:' \
  && ok "approval event carries its own status" || bad "approval event carries its own status"
doc_section 9 10 | grep -qF '沒有正文批准區塊' \
  && ok "§9 finds approval events without a body block" || bad "§9 finds approval events without a body block"
doc_section 9 10 | grep -qF 'source_ref' \
  && ok "§9 still accepts a legacy body source_ref" || bad "§9 still accepts a legacy body source_ref"

# ── simplify-github-pr 3.x: close and uniform result checks ──────────────────
echo "SGP-3 close and result checks"
close_part() { sed -n '/^## Operation: close/,/^## Reporting/p' "$PR_SKILL/SKILL.md" 2>/dev/null; }
close_part | grep -qF 'gh pr close' && ok "close closes the PR" || bad "close closes the PR"
# standardize-github-collaboration-records: PR close no longer closes Issues.
close_part | grep -vE '^- (禁止|Forbidden)：' | grep -qF 'gh issue close' \
  && bad "PR close never closes an Issue" || ok "PR close never closes an Issue"
if instructions "$PR_SKILL/SKILL.md" | grep -qE 'gh pr merge|--delete-branch|gh pr reopen|gh issue reopen'; then
  bad "github-pr never instructs merge, branch deletion or reopen"
else
  ok "github-pr never instructs merge, branch deletion or reopen"
fi
for t in '直接 Issue 與依賴' '沒有 Issue' '關聯歧義' '多個直接 Issue' 'PR close 失敗' 'Closure 已發布' '已 closed' '已 merged'; do
  grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-pr has a close case for '$t'" || bad "github-pr has a close case for '$t'"
done
for op in create update reply close; do
  for t in '回讀失敗' '結果不明'; do
    grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -F -- "$op" | grep -qF -- "$t" \
      && ok "github-pr has a '$op $t' case" || bad "github-pr has a '$op $t' case"
  done
done

# codex-simplify-pr-r02/F-01: a cancelled Issue was stored as closed/completed.
# standardize-github-collaboration-records moves Issue closure into github-issue close.
echo "SGP-4 Issue close reason follows the evidence"
issue_close_part() { sed -n '/^## Operation: close/,/^## Reporting/p' "$ISSUE_SKILL/SKILL.md" 2>/dev/null; }
issue_close_part | grep -qE 'gh issue close .*--reason' && ok "Issue close sets an explicit close reason" \
  || bad "Issue close sets an explicit close reason"
issue_close_part | grep -qF '"not planned"' && ok "cancelled or superseded work closes as not planned" \
  || bad "cancelled or superseded work closes as not planned"
issue_close_part | grep -qF 'stateReason' && ok "Issue close reads back the stored close reason" || bad "Issue close reads back the stored close reason"
issue_close_part | grep -qF 'state_reason' && ok "Issue close names the MCP state_reason field" || bad "Issue close names the MCP state_reason field"
if instructions "$ISSUE_SKILL/SKILL.md" | grep -E 'gh issue close' | grep -vqF -- '--reason'; then
  bad "every github-issue close command carries --reason"
else
  ok "every github-issue close command carries --reason"
fi
if grep -E '^- 預期呼叫：' "$ISSUE_CASES" "$PR_CASES" 2>/dev/null | grep -E 'gh issue close [0-9]+' | grep -vqF -- '--reason'; then
  bad "every expected Issue close call in the cases carries --reason"
else
  ok "every expected Issue close call in the cases carries --reason"
fi
grep -qF 'stateReason: NOT_PLANNED' "$ISSUE_CASES" && ok "an Issue case reads back NOT_PLANNED" || bad "an Issue case reads back NOT_PLANNED"
grep -qF 'stateReason: COMPLETED' "$ISSUE_CASES" && ok "an Issue case keeps COMPLETED for finished work" || bad "an Issue case keeps COMPLETED for finished work"
doc_section 10 11 | grep -qF 'not planned' && ok "contract §10 ties Issue close reason to evidence" \
  || bad "contract §10 ties Issue close reason to evidence"

# ── streamline-github-pr-publication: create publishes; dual session Author ──
# Maps to openspec/changes/streamline-github-pr-publication specs/github-pr.
echo "SPP-1 create performs the necessary Git publication"
create_part() { sed -n '/^## Operation: create/,/^## Operation: update/p' "$PR_SKILL/SKILL.md" 2>/dev/null; }
for cmd in 'git status --porcelain=v1 --untracked-files=all' 'git add -- <pr-paths>' \
           'git commit -m "<message>" -- <pr-paths>' 'git remote get-url --push <remote>' \
           'git push <remote> HEAD:refs/heads/<head-branch>' 'git ls-remote <remote> refs/heads/<head-branch>'; do
  create_part | grep -qF -- "$cmd" && ok "create documents '$cmd'" || bad "create documents '$cmd'"
done
if create_part | awk '/^ *```/{f=!f; next} f' | grep -qE -- '--force|--no-verify|git add -A|git stash|git reset'; then
  bad "create never forces, bypasses hooks, stages everything or discards work"
else
  ok "create never forces, bypasses hooks, stages everything or discards work"
fi
create_part | grep -qF 'whole-worktree' && ok "create limits the whole-worktree commit writer to all-PR worktrees" \
  || bad "create limits the whole-worktree commit writer to all-PR worktrees"
create_part | grep -qF 'without asking again' && ok "create does not re-ask for routine publication" \
  || bad "create does not re-ask for routine publication"
deny "$DOC" 'Issue／PR 操作不 commit、不 push' "contract no longer forbids create from publishing"
deny "$ROOT/README.md" '兩個入口都不 commit、不 push' "README no longer forbids create from publishing"
for t in '未 commit' '已 commit 未 push' '已發布的分支' '前置 base' 'push 被拒' 'hook 失敗' 'non-fast-forward' \
         'push 後 create 失敗' 'push 後 create 結果不明' '混合工作區'; do
  grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-pr has a publication case for '$t'" || bad "github-pr has a publication case for '$t'"
done

echo "SPP-2 dual session Author"
n="$(pr_section | grep -c '^XIRP-SESSION-ID:')"; m="$(pr_section | grep -c '^SESSION-ID:')"
[[ "${n:-0}" -ge 3 && "$n" == "$m" ]] && ok "every §6.2 Author has SESSION-ID and XIRP-SESSION-ID ($m/$n)" \
  || bad "every §6.2 Author has SESSION-ID and XIRP-SESSION-ID ($m/$n)"
want "$PR_SKILL/SKILL.md" 'XIRP-SESSION-ID' "github-pr fills the Xirp session field"
want "$PR_SKILL/SKILL.md" 'look up both IDs before' "github-pr checks the runtime before writing null"
want "$PR_SKILL/SKILL.md" 'never dump the environment' "session discovery reads only the needed keys"
if grep -hvE '^- (禁止|Forbidden)：' "$PR_CASES" "$PR_SKILL/references/examples.md" "$PR_SKILL/SKILL.md" 2>/dev/null \
   | grep -qE '^SESSION-ID: .*\(xirp\)'; then
  bad "new Author examples no longer put a Xirp ID in SESSION-ID"
else
  ok "new Author examples no longer put a Xirp ID in SESSION-ID"
fi
for t in '漏查' '兩者都有' '只有原生' '只有 Xirp' '兩者皆無' 'ID 衝突'; do
  grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-pr has a session case for '$t'" || bad "github-pr has a session case for '$t'"
done

# ── standardize-github-collaboration-records ─────────────────────────────────
# Maps to openspec/changes/standardize-github-collaboration-records specs.
# Static presence only; source-to-output replays are recorded separately.
echo "SCR-1 shared frame: Handoff, Next actions, Author"
frame_part() { awk '/^## 6\. /{f=1;next} /^### 6\.1 /{f=0} f' "$DOC" 2>/dev/null; }
# simplify-github-author-format: the mode and human-account lines are gone (SAF-1).
for term in '## Next actions' '原報告作者:' \
            'SESSION-ID:' 'XIRP-SESSION-ID:' '（local-only）'; do
  frame_part | grep -qF -- "$term" && ok "§6 shared frame defines '$term'" || bad "§6 shared frame defines '$term'"
done
frame_part | grep -qF '舊紀錄的 `null`' && ok "§6 keeps legacy null fields readable" || bad "§6 keeps legacy null fields readable"
[[ "$initial" == '## Handoff|'*'## Goal|'*'## Next actions|## Author|' ]] \
  && ok "initial Issue body ends with Next actions → Author" || bad "initial Issue body ends with Next actions → Author ($initial)"
[[ "$body" == '## Handoff|'*'## Next actions|## Author|' ]] \
  && ok "PR body ends with Next actions → Author" || bad "PR body ends with Next actions → Author ($body)"
n="$(issue_section | grep -c '^XIRP-SESSION-ID:')"; m="$(issue_section | grep -c '^SESSION-ID:')"
[[ "${n:-0}" -ge 2 && "$n" == "$m" ]] && ok "every §6.1 Issue Author has both Session IDs ($m/$n)" \
  || bad "every §6.1 Issue Author has both Session IDs ($m/$n)"
issue_section | grep -qF 'Acceptance criteria' && ok "Issue body names Acceptance criteria" || bad "Issue body names Acceptance criteria"
doc_section 7 8 | grep -qF '（貼文工具與已知模型）' && bad "§7 no longer exempts Issues from Session IDs" \
  || ok "§7 no longer exempts Issues from Session IDs"
pr_section | grep -qF 'close 時一起關閉的 Issue' && bad "PR Handoff issue no longer implies closure" \
  || ok "PR Handoff issue no longer implies closure"

echo "SCR-2 Checkpoint and Closure"
cp_part() { awk '/^### 6\.6 /{f=1;next} /^### 6\.7 /{f=0} f' "$DOC" 2>/dev/null; }
cl_part() { awk '/^### 6\.7 /{f=1;next} /^## 7\. /{f=0} f' "$DOC" 2>/dev/null; }
grep -qE '^### 6\.6 Checkpoint' "$DOC" && ok "contract defines Checkpoint (§6.6)" || bad "contract defines Checkpoint (§6.6)"
grep -qE '^### 6\.7 Closure' "$DOC" && ok "contract defines Closure (§6.7)" || bad "contract defines Closure (§6.7)"
for h in '### Current state' '### Open questions' '## Next actions'; do
  cp_part | grep -qF -- "$h" && ok "Checkpoint has '$h'" || bad "Checkpoint has '$h'"
done
cp_part | grep -qF '之後的事件' && ok "receivers reconcile events after a Checkpoint" || bad "receivers reconcile events after a Checkpoint"
for h in '### Outcome' '### Remaining work' '## Next actions'; do
  cl_part | grep -qF -- "$h" && ok "Closure has '$h'" || bad "Closure has '$h'"
done
cl_part | grep -qF '先發布並回讀 Closure' && ok "Closure is confirmed before the state change" \
  || bad "Closure is confirmed before the state change"
cl_part | grep -qF '不 merge' && ok "Closure never implies a merge" || bad "Closure never implies a merge"
deny "$DOC" '關閉 PR 與直接對應的 Issue' "§10 PR close no longer closes Issues"
deny "$DOC" '使用者要求時才把 pass 發布到 PR' "§8 remote pass is posted, not only on request"
deny "$SVG" 'github-pr close 關 PR 與直接 Issue' "diagram no longer closes Issues from PR close"
want "$SVG" 'github-issue close' "diagram shows the separate Issue close"
for t in '接手缺本地資料' '摘要過時' '平行摘要衝突' 'close 部分失敗' '重試' 'target 變更' \
         '人類直接發布' '代發' '雙 Session' '未知 metadata' 'legacy'; do
  grep -E '^### C-[0-9]+' "$DOC" | grep -qF -- "$t" && ok "shared case for '$t'" || bad "shared case for '$t'"
done

echo "SCR-3 github-issue close, reply and work identity"
grep -qE '^## Operation: close' "$ISSUE_SKILL/SKILL.md" && ok "github-issue defines close" || bad "github-issue defines close"
icp="$(issue_close_part | grep -nE 'gh issue comment|gh issue close' | head -2 | cut -d: -f2- | tr '\n' '|')"
[[ "$icp" == *'gh issue comment'*'|'*'gh issue close'* ]] && ok "Issue close posts Closure before closing" \
  || bad "Issue close posts Closure before closing ($icp)"
issue_close_part | grep -vE '^- (禁止|Forbidden)：' | grep -qF 'gh pr close' \
  && bad "Issue close never closes a PR" || ok "Issue close never closes a PR"
want "$ISSUE_SKILL/SKILL.md" 'XIRP-SESSION-ID' "github-issue Author carries the Xirp session field"
want "$ISSUE_SKILL/SKILL.md" 'source hint' "local Work Item IDs are source hints"
want "$ISSUE_SKILL/SKILL.md" 'reply to an Issue' "an Issue reply is an append-only update"
sed -n '/^description:/,/^[a-z]*:/p' "$ISSUE_SKILL/SKILL.md" | grep -qw 'close' \
  && ok "github-issue description names close" || bad "github-issue description names close"
for t in 'close 完成' 'close 取消' '驗收未完成' '已關閉' '理由不符' 'close 逾時' '摘要成功但 close 失敗' \
         '不同 WI 同一工作' '相同本地 ID' 'Issue 回覆' '人類直接發布' 'Checkpoint'; do
  grep -E '^### GI-[0-9]+' "$ISSUE_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-issue has a case for '$t'" || bad "github-issue has a case for '$t'"
done
EX="$ISSUE_SKILL/references/examples.md"
for term in '## Next actions' '## Checkpoint' '## Closure' 'XIRP-SESSION-ID: null' '虛構' '（local-only）'; do
  want "$EX" "$term" "Issue examples show '$term'"
done

echo "SCR-4 github-pr Closure, Checkpoint and close scope"
cpp="$(close_part | grep -nE 'gh pr comment|gh pr close' | head -2 | cut -d: -f2- | tr '\n' '|')"
[[ "$cpp" == *'gh pr comment'*'|'*'gh pr close'* ]] && ok "PR close posts Closure before closing" \
  || bad "PR close posts Closure before closing ($cpp)"
reply_part | grep -qF 'Checkpoint' && ok "reply covers Checkpoint" || bad "reply covers Checkpoint"
reply_part | grep -qF 'Closure' && ok "reply covers a Closure summary" || bad "reply covers a Closure summary"
want "$PR_SKILL/SKILL.md" 'original author' "relayed reports keep the original author"
sed -n '/^description:/,/^[a-z]*:/p' "$PR_SKILL/SKILL.md" | grep -qF 'corresponding Issues' \
  && bad "github-pr description no longer closes Issues" || ok "github-pr description no longer closes Issues"
if grep -E '^- 預期呼叫：' "$PR_CASES" 2>/dev/null | grep -qF 'gh issue close'; then
  bad "no PR case expects an Issue close"; else ok "no PR case expects an Issue close"; fi
for t in '準備合併' '被取代' 'Closure 已發布' 'Checkpoint' '代發' '人類直接發布'; do
  grep -E '^### GP-[0-9]+' "$PR_CASES" 2>/dev/null | grep -qF -- "$t" \
    && ok "github-pr has a case for '$t'" || bad "github-pr has a case for '$t'"
done
PEX="$PR_SKILL/references/examples.md"
for term in '## Closure' '## Checkpoint' 'reviewer-b-r01/F-01' 'result: pass' '原報告作者:' '虛構'; do
  want "$PEX" "$term" "PR examples show '$term'"
done

# ── simplify-github-design-approval (Issue #17) ──────────────────────────────
# Maps to openspec/changes/simplify-github-design-approval specs. Static checks
# only; Apply decisions are replayed separately.
echo "SDA-1 explicit instruction authorizes Apply; no second identity gate"
sec43() { awk '/^### 4\.3 /{f=1;next} /^## 5\. /{f=0} f' "$DOC" 2>/dev/null; }
sec63() { awk '/^### 6\.3 /{f=1;next} /^### 6\.4 /{f=0} f' "$DOC" 2>/dev/null; }
sec9()  { doc_section 9 10; }
deny "$DOC" '記錄者由已信任的專案批准規範或' "§4.3 drops the recorder allowlist"
sec43 | grep -qF '不要求證明 API 帳號就是使用者本人' && ok "§4.3 does not demand API-account identity proof" \
  || bad "§4.3 does not demand API-account identity proof"
sec43 | grep -qF '不能由 repository 權限推導' && ok "§4.3 still refuses repo access as authorization" \
  || bad "§4.3 still refuses repo access as authorization"
sec9 | grep -qF '而且能從 PR 找到' && bad "§9 no longer requires a PR event before Apply" || ok "§9 no longer requires a PR event before Apply"
sec9 | grep -qF '已授權的記錄者或人類本人' && bad "§9 drops the recorder-or-human author check" || ok "§9 drops the recorder-or-human author check"
for t in '明確的使用者指示' 'PR 事件不是 Apply 的必要條件' '只要求建立 Change' '技術 pass' '撤回' 'API 帳號'; do
  sec9 | grep -qF -- "$t" && ok "§9 covers '$t'" || bad "§9 covers '$t'"
done
sec9 | grep -qF '沒有正文批准區塊' && ok "§9 keeps legacy event discovery" || bad "§9 keeps legacy event discovery"

echo "SDA-2 approval record: optional human identifier, honest metadata"
sec63 | grep -qF '人類批准者的 GitHub 帳號>' && bad "§6.3 no longer requires the approver's GitHub account" \
  || ok "§6.3 no longer requires the approver's GitHub account"
sec63 | grep -qF 'approved_by: <已知且可公開的人類識別；未知時整行省略>' && ok "§6.3 approved_by is optional" \
  || bad "§6.3 approved_by is optional"
for f in 'approved_scope:' 'artifact_revision:' 'source_kind:' 'source_ref:' 'recorded_by:' 'recorded_at:' 'approved_at:' 'supersedes:'; do
  sec63 | grep -qF -- "- $f" && ok "§6.3 keeps '$f'" || bad "§6.3 keeps '$f'"
done
sec63 | grep -qF '實際作者只代表發布帳號' && ok "§6.3 actual author is the publisher, not identity proof" \
  || bad "§6.3 actual author is the publisher, not identity proof"
deny "$DOC" '明文指定 `octo-dev` 為可以代記人類' "shared case fixture has no recorder allowlist"
for t in '未知人類帳號' 'API 帳號與委託者不同' '沒有 PR 事件但已有明確實作指示' '只要求建立 Change' '來源不明的批准宣稱' '授權撤回'; do
  grep -E '^### C-[0-9]+' "$DOC" | grep -qF -- "$t" && ok "shared case for '$t'" || bad "shared case for '$t'"
done
want "$WORKFLOW" 'explicit user instruction' "OpenSpec workflow accepts an explicit user instruction"
deny "$COMMON/AGENTS.md" '批准記錄者授權' "AGENTS seed drops recorder authorization"

echo "SDA-3 entries share the same approval semantics"
CR_SKILL="$COMMON/skills/change-review/SKILL.md"; CR_CASES="$COMMON/skills/change-review/references/acceptance-cases.md"
for f in "$PR_SKILL/SKILL.md" "$CR_SKILL"; do
  if grep -qE 'authorized recorder|contract 4\.3' "$f"; then bad "${f#"$ROOT"/} drops the recorder gate"; else ok "${f#"$ROOT"/} drops the recorder gate"; fi
done
want "$PR_SKILL/SKILL.md" 'omit the human identifier field' "github-pr omits an unknown human identifier"
want "$PR_SKILL/SKILL.md" 'never infer it from the API login' "github-pr never infers identity from the API login"
want "$CR_SKILL" 'explicit user instruction' "change-review recognizes an explicit instruction"
for f in "$PR_CASES" "$CR_CASES"; do
  deny "$f" '為可以代記人類設計批准的記錄者' "${f#"$ROOT"/} fixture has no recorder allowlist"
done
grep -E '^### GP-[0-9]+' "$PR_CASES" | grep -qF '未知帳號的批准紀錄' && ok "github-pr case for an unknown-account approval reply" \
  || bad "github-pr case for an unknown-account approval reply"
grep -E '^### CR-[0-9]+' "$CR_CASES" | grep -qF '明確指示涵蓋實作' && ok "change-review case for an explicit implementation instruction" \
  || bad "change-review case for an explicit implementation instruction"
deny "$SVG" '可由已授權 Agent 具名代記' "diagram drops the named-recorder wording"

# codex-sgda-r01/F-01, F-02: version binding covers the real worktree and
# local-only design revisions.
echo "SDA-4 design version check covers the worktree and local-only revisions"
sec9 | grep -qF 'git diff --quiet <artifact_revision> HEAD' && bad "§9 no longer compares commits only" \
  || ok "§9 no longer compares commits only"
for t in 'git diff --quiet <artifact_revision> -- openspec/changes/<change-id>/' \
         'git ls-files --others --exclude-standard -- openspec/changes/<change-id>/' \
         '結束碼大於 1' '只差在 tasks 的勾選' '不能當成相同'; do
  sec9 | grep -qF -- "$t" && ok "§9 covers '$t'" || bad "§9 covers '$t'"
done
for t in 'unpublished-snapshot' "printf '%s\\0'" '另一台機器' '不編造 commit'; do
  sec63 | grep -qF -- "$t" && ok "§6.3 covers '$t'" || bad "§6.3 covers '$t'"
done
for t in '工作區設計已實質改變' '只有 tasks 勾選' '基線不可得' '本機未提交規劃記到 PR'; do
  grep -E '^### C-[0-9]+' "$DOC" | grep -qF -- "$t" && ok "shared case for '$t'" || bad "shared case for '$t'"
done
want "$PR_SKILL/SKILL.md" 'unpublished snapshot' "github-pr records a local-only design revision honestly"

echo "SDA-5 rehearsal of the documented version check (real Git)"
VT="$(mktemp -d)"; VR="$VT/repo"; CH="openspec/changes/add-export"
vg() { git -C "$VR" "$@"; }
snap() {                           # documented unpublished-snapshot digest of $1 (Change root)
  ( cd "$1" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s\0' "$f"
      if [ "$(basename "$f")" = tasks.md ]; then sed 's/^\([[:space:]]*\)- \[x\] /\1- [ ] /' "$f"; else cat "$f"; fi
      printf '\0'
    done ) | shasum -a 256 | cut -d' ' -f1
}
changed() {                        # documented check: 0 same, 1 changed, 2 not verifiable
  local rev="$1" rc
  vg rev-parse --verify -q "$rev^{commit}" >/dev/null || return 2
  vg diff --quiet "$rev" -- "$CH/" ':(exclude)'"$CH/tasks.md"; rc=$?
  (( rc > 1 )) && return 2; (( rc == 1 )) && return 1
  [[ -n "$(vg ls-files --others --exclude-standard -- "$CH/")" ]] && return 1
  # tasks.md: only checkbox state may differ
  diff -q <(vg show "$rev:$CH/tasks.md" 2>/dev/null | sed 's/- \[x\] /- [ ] /') \
          <(sed 's/- \[x\] /- [ ] /' "$VR/$CH/tasks.md") >/dev/null || return 1
  return 0
}
git init -q -b main "$VR"; vg config user.name T; vg config user.email t@example.invalid; vg config commit.gpgsign false
mkdir -p "$VR/$CH/specs/x"; printf 'decision A\n' > "$VR/$CH/design.md"; printf 'req\n' > "$VR/$CH/specs/x/spec.md"
printf -- '- [ ] 1.1 do it\n' > "$VR/$CH/tasks.md"
vg add -A; vg commit -q -m d1; D1="$(vg rev-parse HEAD)"; S1="$(snap "$VR/$CH")"
changed "$D1"; [[ $? == 0 ]] && ok "unchanged artifacts match the approved revision" || bad "unchanged artifacts match the approved revision"
sed -i.bak 's/- \[ \]/- [x]/' "$VR/$CH/tasks.md"; rm -f "$VR/$CH/tasks.md.bak"
changed "$D1"; [[ $? == 0 ]] && ok "task checkbox progress is bookkeeping, not a design change" || bad "task checkbox progress is bookkeeping, not a design change"
[[ "$(snap "$VR/$CH")" == "$S1" ]] && ok "snapshot digest ignores task checkbox progress" || bad "snapshot digest ignores task checkbox progress"
printf 'decision B\n' > "$VR/$CH/design.md"
vg diff --quiet "$D1" HEAD -- "$CH/" && ok "(gap reproduced) commit-to-HEAD comparison misses the worktree change" \
  || bad "(gap reproduced) commit-to-HEAD comparison misses the worktree change"
changed "$D1"; [[ $? == 1 ]] && ok "unstaged design change is detected" || bad "unstaged design change is detected"
[[ "$(snap "$VR/$CH")" != "$S1" ]] && ok "snapshot digest changes with the design" || bad "snapshot digest changes with the design"
vg add "$CH/design.md"
changed "$D1"; [[ $? == 1 ]] && ok "staged design change is detected" || bad "staged design change is detected"
vg checkout -q "$D1" -- "$CH/design.md"; printf 'new\n' > "$VR/$CH/specs/x/extra.md"
changed "$D1"; [[ $? == 1 ]] && ok "untracked design artifact is detected" || bad "untracked design artifact is detected"
rm -f "$VR/$CH/specs/x/extra.md"
changed "0000000000000000000000000000000000000000"; [[ $? == 2 ]] && ok "missing baseline is not verifiable, never 'same'" \
  || bad "missing baseline is not verifiable, never 'same'"
rm -rf "$VT"

# ── simplify-github-author-format (Issue #18) ────────────────────────────────
# Maps to openspec/changes/simplify-github-author-format specs.
echo "SAF-1 Author drops mode and human-account lines"
sec6_all() { awk '/^## 6\. /{f=1} /^## 7\. /{f=0} f' "$DOC" 2>/dev/null; }
in_fences() { awk '/^ *```/{f=!f; next} f'; }
n="$(sec6_all | in_fences | grep -cE '^[[:space:]]*(方式|人類):')"
[[ "$n" == 0 ]] && ok "no §6 template writes a mode or human-account line" || bad "no §6 template writes a mode or human-account line ($n)"
if sec6_all | in_fences | grep -qE '^[[:space:]]*(mode|Mode|publisher-human|發布方式|委託者|Human):'; then
  bad "no synonymous replacement label"; else ok "no synonymous replacement label"; fi
n="$(sec6_all | in_fences | grep -c '^SESSION-ID:')"; m="$(sec6_all | in_fences | grep -c '^XIRP-SESSION-ID:')"
[[ "${n:-0}" -ge 6 && "$n" == "$m" ]] && ok "Agent templates keep both Session fields ($n/$m)" || bad "Agent templates keep both Session fields ($n/$m)"
frame_part | grep -qF '沒有 Agent 參與、由人類直接發布的內容不加 Author' && ok "pure human-direct posts omit Author" \
  || bad "pure human-direct posts omit Author"
frame_part | grep -qF 'Agent 代為整理或發布' && ok "agent-on-behalf posts keep Agent metadata" || bad "agent-on-behalf posts keep Agent metadata"
frame_part | grep -qF '舊紀錄的 `方式`' && ok "legacy mode/human lines stay readable" || bad "legacy mode/human lines stay readable"
sec63 | grep -qF 'approved_by' && ok "approval event keeps approved_by (Issue #17 untouched)" || bad "approval event keeps approved_by (Issue #17 untouched)"
for t in 'Agent 代人類發布' '新格式代發' '舊格式後追加新內容'; do
  grep -E '^### C-[0-9]+' "$DOC" | grep -qF -- "$t" && ok "shared case for '$t'" || bad "shared case for '$t'"
done

# codex-author-r01/F-01: prose rules and inline expectations, not only template fences.
doc_section 7 8 | grep -qE '方式|人類' && bad "§7 Provenance names no mode/human Author line" || ok "§7 Provenance names no mode/human Author line"
deny "$DOC" 'Handoff、Goal、Next actions、Author 必須出現' "§6.1 does not require Author unconditionally"
issue_section | grep -qF 'Agent 參與時最後是 Author' && ok "§6.1 requires Author only when an Agent posts" || bad "§6.1 requires Author only when an Agent posts"
inline_old() { grep -hE '^- (判定|預期呼叫|產出[^：]*)：' "$@" 2>/dev/null | grep -E '`(方式|人類): '; }
if inline_old "$DOC" "$ISSUE_SKILL"/references/*.md "$PR_SKILL"/references/*.md \
     "$COMMON"/skills/change-review/references/*.md "$COMMON"/skills/openspec-commit/references/*.md >/dev/null; then
  bad "no expected output or judgement asks for a mode/human Author line"
else
  ok "no expected output or judgement asks for a mode/human Author line"
fi
deny "$ISSUE_SKILL/references/examples.md" '省略模型與未確認的' "Issue example no longer mentions an omitted human field"

echo "SAF-2 entries and references write the reduced Author"
CRS="$COMMON/skills/change-review/SKILL.md"
for f in "$ISSUE_SKILL/SKILL.md" "$PR_SKILL/SKILL.md"; do
  if grep -qE '方式: Agent 協助`|方式: 人類直接發布|`人類` only' "$f"; then bad "${f#"$ROOT"/} no longer instructs mode/human lines"
  else ok "${f#"$ROOT"/} no longer instructs mode/human lines"; fi
  want "$f" 'no Author section' "${f#"$ROOT"/} states the human-direct exception"
done
want "$CRS" 'older `方式: Agent 協助代發`' "change-review still reads the legacy relay marker"
want "$CRS" 'identified by `原報告作者`' "change-review identifies relays by the original-author line"
for f in "$ISSUE_SKILL/references/examples.md" "$ISSUE_CASES" "$PR_SKILL/references/examples.md" "$PR_CASES" \
         "$COMMON/skills/change-review/references/acceptance-cases.md" "$COMMON/skills/openspec-commit/references/examples.md"; do
  n="$(grep -cE '^[[:space:]]*(方式|人類): ' "$f")"
  [[ "$n" == 0 ]] && ok "${f#"$ROOT"/} writes no mode/human Author line" || bad "${f#"$ROOT"/} writes no mode/human Author line ($n)"
done
grep -E '^### GI-[0-9]+' "$ISSUE_CASES" | grep -qF '舊格式 Issue 追加留言' && ok "github-issue case: new comment on a legacy Issue" \
  || bad "github-issue case: new comment on a legacy Issue"
grep -E '^### GP-[0-9]+' "$PR_CASES" | grep -qF '新格式代發報告' && ok "github-pr case: relay with the new markers" \
  || bad "github-pr case: relay with the new markers"

# ── 4.1 Managed delivery and legacy script retirement ────────────────────────
echo "4.1 managed delivery"
T="$(new_target)"
mkdir -p "$T/scripts/github" "$T/docs/diagrams" "$T/work-items/WI-20260101-keep"
printf 'own helper\n' > "$T/scripts/github/local-helper.sh"
printf 'own script\n' > "$T/scripts/own.sh"
printf '<svg/>\n'     > "$T/docs/diagrams/own.svg"
printf 'record\n'     > "$T/work-items/WI-20260101-keep/README.md"
git -C "$T" config credential.helper 'store --file=/home/u/FAKE_SECRET_INSTALL_TEST'
KEEP_BEFORE="$(cat "$T/scripts/github/local-helper.sh" "$T/scripts/own.sh" "$T/docs/diagrams/own.svg" \
  "$T/work-items/WI-20260101-keep/README.md" "$T/.git/config" | shasum | awk '{print $1}')"
run_install "$T"
for f in $MANAGED; do
  cmp -s "$COMMON/$f" "$T/$f" && ok "first install delivers $f" || bad "first install delivers $f"
done
[[ ! -e "$T/$LEGACY" ]] && ok "fresh install does not deliver the retired script" || bad "fresh install does not deliver the retired script"
for f in $MANAGED; do
  [[ -f "$T/$f" ]] && printf 'local edit\n' > "$T/$f"
done
run_install "$T"
for f in $MANAGED; do
  cmp -s "$COMMON/$f" "$T/$f" && ok "re-install refreshes edited $f" || bad "re-install refreshes edited $f"
done
S_BEFORE="$(for f in $MANAGED; do sum1 "$T/$f"; done)"
run_install "$T"
[[ "$(for f in $MANAGED; do sum1 "$T/$f"; done)" == "$S_BEFORE" && -n "$S_BEFORE" ]] \
  && ok "a further install is idempotent" || bad "a further install is idempotent"
KEEP_AFTER="$(cat "$T/scripts/github/local-helper.sh" "$T/scripts/own.sh" "$T/docs/diagrams/own.svg" \
  "$T/work-items/WI-20260101-keep/README.md" "$T/.git/config" 2>/dev/null | shasum | awk '{print $1}')"
[[ "$KEEP_AFTER" == "$KEEP_BEFORE" ]] \
  && ok "unrelated scripts, diagrams, Work Items and credential config preserved" \
  || bad "unrelated scripts, diagrams, Work Items and credential config preserved"
if log_of "$T" | grep -q 'FAKE_SECRET_INSTALL_TEST'; then
  bad "installer output carries no credential configuration"
else
  ok "installer output carries no credential configuration"
fi

# An unmodified copy of the retired script is a managed artifact: remove it.
T="$(new_target)"; mkdir -p "$T/scripts/github"
git -C "$ROOT" show "$LEGACY_REV:template/common/$LEGACY" > "$T/$LEGACY"; chmod +x "$T/$LEGACY"
printf 'own helper\n' > "$T/scripts/github/local-helper.sh"
run_install "$T"
[[ ! -e "$T/$LEGACY" ]] && ok "unmodified legacy script is removed" || bad "unmodified legacy script is removed"
[[ -f "$T/scripts/github/local-helper.sh" ]] \
  && ok "neighbouring project script survives the removal" || bad "neighbouring project script survives the removal"
log_of "$T" | grep -q "removed retired $LEGACY" \
  && ok "removal is reported" || bad "removal is reported"
T="$(new_target)"; mkdir -p "$T/scripts/github"
git -C "$ROOT" show "$LEGACY_REV:template/common/$LEGACY" > "$T/$LEGACY"
run_install "$T"
[[ ! -d "$T/scripts/github" ]] && ok "a directory left empty by the removal is removed" || bad "a directory left empty by the removal is removed"

# A modified or unknown copy cannot be removed safely: keep it and report it.
T="$(new_target)"; mkdir -p "$T/scripts/github"
{ git -C "$ROOT" show "$LEGACY_REV:template/common/$LEGACY"; printf '# local change\n'; } > "$T/$LEGACY"
L_BEFORE="$(sum1 "$T/$LEGACY")"
run_install "$T"
[[ "$(sum1 "$T/$LEGACY")" == "$L_BEFORE" ]] \
  && ok "modified legacy script is left byte-identical" || bad "modified legacy script is left byte-identical"
log_of "$T" | grep -q "left $LEGACY in place" \
  && ok "kept legacy script is reported as no longer used" || bad "kept legacy script is reported as no longer used"

for skill in github-issue github-pr; do
  T="$(new_target)"; run_install "$T"
  if diff -r "$COMMON/skills/$skill" "$T/.claude/skills/$skill" >/dev/null 2>&1 \
    && diff -r "$COMMON/skills/$skill" "$T/.agents/skills/$skill" >/dev/null 2>&1; then
    ok "$skill and its cases reach both skill directories"
  else
    bad "$skill and its cases reach both skill directories"
  fi
done
if cmp -s "$RULE" "$T/.claude/rules/github-handoff.md" && cmp -s "$RULE" "$T/.agents/rules/github-handoff.md"; then
  ok "rule reaches .claude/rules and the .agents/rules mirror"
else
  bad "rule reaches .claude/rules and the .agents/rules mirror"
fi
# A tool that reads only AGENTS.md reaches the contract through managed files.
if has "$T/AGENTS.md" 'docs/agent-protocol.md' && has "$T/docs/agent-protocol.md" 'docs/github-handoff.md' \
  && [[ -f "$T/docs/github-handoff.md" ]]; then
  ok "AGENTS.md → protocol → contract chain is reachable"
else
  bad "AGENTS.md → protocol → contract chain is reachable"
fi

# ── 4.2 This repository's installed copies match their sources ───────────────
echo "4.2 repository installation"
for f in $MANAGED; do
  cmp -s "$COMMON/$f" "$ROOT/$f" && ok "repository $f synchronized" || bad "repository $f synchronized"
done
[[ ! -e "$ROOT/$LEGACY" ]] && ok "repository no longer carries the retired script" || bad "repository no longer carries the retired script"
for skill in github-issue github-pr; do
  if diff -r "$COMMON/skills/$skill" "$ROOT/.claude/skills/$skill" >/dev/null 2>&1 \
    && diff -r "$COMMON/skills/$skill" "$ROOT/.agents/skills/$skill" >/dev/null 2>&1; then
    ok "repository $skill synchronized"
  else
    bad "repository $skill synchronized"
  fi
done
if cmp -s "$RULE" "$ROOT/.claude/rules/github-handoff.md" && cmp -s "$RULE" "$ROOT/.agents/rules/github-handoff.md"; then
  ok "repository rule synchronized"
else
  bad "repository rule synchronized"
fi

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
