#!/usr/bin/env bash
# Verifies the GitHub change-handoff capability: the shared contract, its diagram
# and the identity-check script are managed assets that reinstall refreshes; the
# thin rule, protocol and Work Item convention point at the single contract; and
# the two entry skills reference it instead of restating its schema.
# Maps to openspec/changes/add-github-change-handoff specs.
#
# These are contract-presence and installer-behavior checks. They do not replay
# agent decisions or real gh calls; those are recorded under
# docs/verification/github-handoff/.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
DOC="$COMMON/docs/github-handoff.md"
SVG="$COMMON/docs/diagrams/github-handoff.svg"
SCRIPT="$COMMON/scripts/github/check-identity.sh"
RULE="$COMMON/.claude/rules/github-handoff.md"
PROTO="$COMMON/docs/agent-protocol.md"
WORKFLOW="$COMMON/docs/openspec-workflow.md"
CONVENTION="$COMMON/work-items/AGENTS.md"
ISSUE_SKILL="$COMMON/skills/github-issue"
PR_SKILL="$COMMON/skills/github-pr"
MANAGED="docs/github-handoff.md docs/diagrams/github-handoff.svg scripts/github/check-identity.sh"
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
has() { grep -Fq -- "$2" "$1" 2>/dev/null; }                 # $1 file, $2 fixed string
want() { if has "$1" "$2"; then ok "$3"; else bad "$3"; fi; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT
new_target() {
  local d; d="$(mktemp -d "$TMPROOT/t.XXXXXX")"
  mkdir -p "$d/repo"; git init -q -b main "$d/repo"
  printf '%s\n' "$d/repo"
}
run_install() { bash "$ROOT/scripts/skills/install.sh" --target "$1" > "$1/../install.log" 2>&1; }
sum1() { shasum "$1" 2>/dev/null | awk '{print $1}'; }

# ── 1.1 Shared contract: schema, identity policy, evidence table, cases ───────
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
want "$DOC" '## GitHub handoff identity' "trusted identity policy block named"
want "$DOC" 'policy_source' "policy snapshot is an explicit input"
for value in pass mismatch unverified error; do
  want "$DOC" "\`$value\`" "preflight result '$value' documented"
done
want "$DOC" 'BatchMode=yes'            "SSH test is noninteractive"
want "$DOC" 'StrictHostKeyChecking=yes' "SSH test keeps host-key verification"
want "$DOC" 'osxkeychain'               "unsupported credential helper named"
want "$DOC" 'design-approval'                 "design-approval record defined"
want "$DOC" 'human-github'                    "human approval source kind defined"
want "$DOC" 'agent-attested-user-instruction' "attested approval source kind defined"
want "$DOC" 'superseded'                      "superseded approval state defined"
want "$DOC" 'changes-required' "review verdict vocabulary defined"
want "$DOC" 'review-id'        "review identifier defined"
want "$DOC" 'withheld'         "withheld provenance state defined"
want "$DOC" 'Refs #'           "issue reference uses a non-closing keyword"
want "$DOC" 'docs/verification/github-handoff/' "formal evidence location defined"
want "$DOC" 'MCP' "contract states the MCP boundary"
# Shared manual cases: each carries the five replay fields.
cases="$(grep -cE '^### C-[0-9]+' "$DOC" 2>/dev/null | tr -d ' ')"
[[ "${cases:-0}" -ge 18 ]] && ok "at least 18 shared cases (${cases:-0})" || bad "at least 18 shared cases (${cases:-0})"
for label in 'Fixture：' '模擬回覆：' '預期呼叫：' '禁止：' '判定：'; do
  n="$(grep -cF -- "- $label" "$DOC" 2>/dev/null | tr -d ' ')"
  [[ "${n:-0}" -ge "${cases:-999}" && "${cases:-0}" -gt 0 ]] \
    && ok "every shared case states '$label'" || bad "every shared case states '$label' (${n:-0}/${cases:-0})"
done

# ── 1.3 Review report baseline ───────────────────────────────────────────────
echo "1.3 review baseline"
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
if has "$SVG" '尚未實作'; then bad "diagram is not labelled as unimplemented design"; else ok "diagram is not labelled as unimplemented design"; fi
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
want "$RULE" 'scripts/github/check-identity.sh' "rule names the shared preflight"
if [[ -f "$RULE" ]] && [[ "$(wc -l < "$RULE" | tr -d ' ')" -le 30 ]]; then
  ok "rule entry stays short"; else bad "rule entry stays short"; fi
if [[ -f "$RULE" && "$(grep -c '^- ' "$RULE" | tr -d ' ')" == 0 ]]; then
  ok "rule entry carries no rule list"; else bad "rule entry carries no rule list"; fi
want "$RULE" '不是 hook' "rule does not present itself as a hook"
if grep -qE 'openspec-change:|approved_by|Session-ID' "$RULE" 2>/dev/null; then
  bad "rule restates no contract schema"; else ok "rule restates no contract schema"; fi
want "$PROTO" 'docs/github-handoff.md' "protocol references the contract"
want "$PROTO" 'check-identity' "protocol requires the per-operation preflight"
grep -qE '^\| Version \| 2\.7\.0' "$PROTO" 2>/dev/null \
  && ok "protocol version bumped" || bad "protocol version bumped"
want "$WORKFLOW" 'github-handoff.md' "OpenSpec workflow links the contract"
want "$WORKFLOW" 'optional' "OpenSpec workflow keeps GitHub handoff optional"
want "$CONVENTION" '../docs/github-handoff.md' "Work Item convention links the contract"
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
  want "$skill/SKILL.md" 'scripts/github/check-identity.sh' "$name calls the shared preflight"
  want "$skill/SKILL.md" 'references/acceptance-cases.md' "$name links its replay cases"
  want "$skill/SKILL.md" 'MCP' "$name states the MCP boundary"
  if grep -qE 'approved_by|## Scope and Baseline|wk-agent-ops:handoff:start' "$skill/SKILL.md" 2>/dev/null; then
    bad "$name restates no contract schema"
  else
    ok "$name restates no contract schema"
  fi
  [[ -f "$skill/references/acceptance-cases.md" ]] \
    && ok "$name replay cases exist" || bad "$name replay cases exist"
done
gi="$(grep -cE '^### GI-[0-9]+' "$ISSUE_SKILL/references/acceptance-cases.md" 2>/dev/null | tr -d ' ')"
[[ "${gi:-0}" -ge 13 ]] && ok "github-issue has at least 13 cases (${gi:-0})" || bad "github-issue has at least 13 cases (${gi:-0})"
gp="$(grep -cE '^### GP-[0-9]+' "$PR_SKILL/references/acceptance-cases.md" 2>/dev/null | tr -d ' ')"
[[ "${gp:-0}" -ge 16 ]] && ok "github-pr has at least 16 cases (${gp:-0})" || bad "github-pr has at least 16 cases (${gp:-0})"
for op in create update; do
  grep -qE "^## .*\b$op\b" "$ISSUE_SKILL/SKILL.md" 2>/dev/null \
    && ok "github-issue defines $op" || bad "github-issue defines $op"
done
for op in create publish update; do
  grep -qE "^## .*\b$op\b" "$PR_SKILL/SKILL.md" 2>/dev/null \
    && ok "github-pr defines $op" || bad "github-pr defines $op"
done

# ── 4.1 Managed delivery: contract, diagram and script refresh together ──────
echo "4.1 managed delivery"
T="$(new_target)"
mkdir -p "$T/scripts/github" "$T/docs/diagrams" "$T/work-items/WI-20260101-keep"
printf 'own helper\n' > "$T/scripts/github/local-helper.sh"
printf 'own script\n' > "$T/scripts/own.sh"
printf '<svg/>\n'     > "$T/docs/diagrams/own.svg"
printf 'record\n'     > "$T/work-items/WI-20260101-keep/README.md"
KEEP_BEFORE="$(cat "$T/scripts/github/local-helper.sh" "$T/scripts/own.sh" "$T/docs/diagrams/own.svg" \
  "$T/work-items/WI-20260101-keep/README.md" | shasum | awk '{print $1}')"
run_install "$T"
for f in $MANAGED; do
  cmp -s "$COMMON/$f" "$T/$f" && ok "first install delivers $f" || bad "first install delivers $f"
done
[[ -x "$T/scripts/github/check-identity.sh" ]] \
  && ok "installed script is executable" || bad "installed script is executable"

for f in $MANAGED; do
  [[ -f "$T/$f" ]] && printf 'local edit\n' > "$T/$f"
done
chmod -x "$T/scripts/github/check-identity.sh" 2>/dev/null
run_install "$T"
for f in $MANAGED; do
  cmp -s "$COMMON/$f" "$T/$f" && ok "re-install refreshes edited $f" || bad "re-install refreshes edited $f"
done
[[ -x "$T/scripts/github/check-identity.sh" ]] \
  && ok "re-install restores the executable mode" || bad "re-install restores the executable mode"

S_BEFORE="$(for f in $MANAGED; do sum1 "$T/$f"; done)"
run_install "$T"
[[ "$(for f in $MANAGED; do sum1 "$T/$f"; done)" == "$S_BEFORE" && -n "$S_BEFORE" ]] \
  && ok "a further install is idempotent" || bad "a further install is idempotent"
KEEP_AFTER="$(cat "$T/scripts/github/local-helper.sh" "$T/scripts/own.sh" "$T/docs/diagrams/own.svg" \
  "$T/work-items/WI-20260101-keep/README.md" 2>/dev/null | shasum | awk '{print $1}')"
[[ "$KEEP_AFTER" == "$KEEP_BEFORE" ]] \
  && ok "unrelated scripts, diagrams and Work Items preserved" || bad "unrelated scripts, diagrams and Work Items preserved"

for skill in github-issue github-pr; do
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
# A tool that reads only AGENTS.md reaches the preflight through managed files.
if has "$T/AGENTS.md" 'docs/agent-protocol.md' && has "$T/docs/agent-protocol.md" 'docs/github-handoff.md' \
  && has "$T/docs/github-handoff.md" 'scripts/github/check-identity.sh' && [[ -x "$T/scripts/github/check-identity.sh" ]]; then
  ok "AGENTS.md → protocol → contract → script chain is reachable"
else
  bad "AGENTS.md → protocol → contract → script chain is reachable"
fi

# ── 4.2 This repository's installed copies match their sources ───────────────
echo "4.2 repository installation"
for f in $MANAGED; do
  cmp -s "$COMMON/$f" "$ROOT/$f" && ok "repository $f synchronized" || bad "repository $f synchronized"
done
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
