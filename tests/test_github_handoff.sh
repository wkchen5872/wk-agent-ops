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
[[ "$comment" == '## Handoff|## Changes|## Author|' ]] \
  && ok "update comment is Handoff → Changes → Author" || bad "update comment is Handoff → Changes → Author ($comment)"
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
if instructions "$PR_SKILL/SKILL.md" | grep -qE 'git push|git commit|git add|git-commit-writer|commit writer'; then
  bad "github-pr instructs no staging, commit, push or commit-writer delegation"
else
  ok "github-pr instructs no staging, commit, push or commit-writer delegation"
fi
want "$PR_SKILL/SKILL.md" 'Git publication is a separate step' "github-pr explains the removed publish boundary"
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
[[ "$review" == '## Handoff|## Review|## Author|' ]] && ok "reviewer reply is Handoff → Review → Author" \
  || bad "reviewer reply is Handoff → Review → Author ($review)"
[[ "$changes" == '## Handoff|## Changes|## Author|' ]] && ok "implementer reply is Handoff → Changes → Author" \
  || bad "implementer reply is Handoff → Changes → Author ($changes)"
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
close_part | grep -qF 'gh issue close' && ok "close closes confirmed corresponding Issues" || bad "close closes confirmed corresponding Issues"
if instructions "$PR_SKILL/SKILL.md" | grep -qE 'gh pr merge|--delete-branch|gh pr reopen|gh issue reopen'; then
  bad "github-pr never instructs merge, branch deletion or reopen"
else
  ok "github-pr never instructs merge, branch deletion or reopen"
fi
for t in '直接 Issue 與依賴' '沒有 Issue' '關聯歧義' '多個直接 Issue' 'PR close 失敗' 'Issue 部分失敗' '已 closed' '已 merged'; do
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
echo "SGP-4 Issue close reason follows the evidence"
close_part | grep -qE 'gh issue close .*--reason' && ok "close sets an explicit Issue close reason" \
  || bad "close sets an explicit Issue close reason"
close_part | grep -qF '"not planned"' && ok "cancelled or superseded work closes as not planned" \
  || bad "cancelled or superseded work closes as not planned"
close_part | grep -qF 'stateReason' && ok "close reads back the stored close reason" || bad "close reads back the stored close reason"
close_part | grep -qF 'state_reason' && ok "close names the MCP state_reason field" || bad "close names the MCP state_reason field"
if instructions "$PR_SKILL/SKILL.md" | grep -E 'gh issue close' | grep -vqF -- '--reason'; then
  bad "every github-pr Issue close command carries --reason"
else
  ok "every github-pr Issue close command carries --reason"
fi
if grep -E '^- 預期呼叫：' "$PR_CASES" 2>/dev/null | grep -E 'gh issue close [0-9]+' | grep -vqF -- '--reason'; then
  bad "every expected Issue close call in the cases carries --reason"
else
  ok "every expected Issue close call in the cases carries --reason"
fi
grep -qF 'stateReason: NOT_PLANNED' "$PR_CASES" && ok "a case reads back NOT_PLANNED" || bad "a case reads back NOT_PLANNED"
grep -qF 'stateReason: COMPLETED' "$PR_CASES" && ok "a case keeps COMPLETED for finished work" || bad "a case keeps COMPLETED for finished work"
doc_section 10 11 | grep -qF 'not planned' && ok "contract §10 ties Issue close reason to evidence" \
  || bad "contract §10 ties Issue close reason to evidence"

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
