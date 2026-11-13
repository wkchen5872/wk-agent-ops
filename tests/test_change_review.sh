#!/usr/bin/env bash
# Verifies the change-review capability: the cross-tool Skill exists with its
# phase and version entry, references the shared handoff contract instead of
# restating its schema, never takes the PR create/update/close or commit/push paths,
# ships its replay cases, checklists and diagram, and reaches Claude Code and the
# .agents mirror through the existing installer.
# Maps to openspec/changes/add-change-review-skill specs.
#
# Contract presence and installer behavior only. Agent decisions are replayed
# from references/acceptance-cases.md and recorded under
# docs/verification/change-review/.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
SKILL_DIR="$COMMON/skills/change-review"
SKILL="$SKILL_DIR/SKILL.md"
CASES="$SKILL_DIR/references/acceptance-cases.md"
CHECKS="$SKILL_DIR/references/checklists.md"
SVG="$SKILL_DIR/references/review-loop.svg"
CONTRACT="$COMMON/docs/github-handoff.md"
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
has() { grep -Fq -- "$2" "$1" 2>/dev/null; }
want() { if has "$1" "$2"; then ok "$3"; else bad "$3"; fi; }
deny() { if has "$1" "$2"; then bad "$3"; else ok "$3"; fi; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT
new_target() {
  local d; d="$(mktemp -d "$TMPROOT/t.XXXXXX")"
  mkdir -p "$d/repo"; git init -q -b main "$d/repo"; printf '%s\n' "$d/repo"
}
run_install() { bash "$ROOT/scripts/skills/install.sh" --target "$1" > "$1/../install.log" 2>&1; }

# ── 1.1 Entry: PR, phase, optional expected head, selected Change ────────────
echo "1.1 entry and version fixing"
[[ -f "$SKILL" ]] && ok "Skill source exists" || bad "Skill source exists"
grep -qE '^name: change-review$' "$SKILL" 2>/dev/null && ok "frontmatter name matches" || bad "frontmatter name matches"
grep -qE '^description:' "$SKILL" 2>/dev/null && ok "Skill has a description" || bad "Skill has a description"
for term in 'phase' 'design' 'implementation' 'expected-head' 'reviewed head' 'stale'; do
  want "$SKILL" "$term" "Skill covers '$term'"
done
want "$SKILL" 'Change' "Skill requires a selected Change when several are linked"
want "$SKILL" 'Skill source' "Skill records its own source separately from the reviewed head"

# ── 1.2 / 1.3 Shared contract is referenced, not restated ────────────────────
echo "1.2-1.3 shared contract"
want "$SKILL" 'docs/github-handoff.md' "Skill reads the shared contract"
for section in '## Scope and Baseline' '## Findings' '## Summary and Limitations' 'approved_by:'; do
  deny "$SKILL" "$section" "Skill does not restate contract template text '$section'"
done
want "$CONTRACT" 'change-review' "contract points reviewers at the Skill"

# ── 1.4 / 3.1 Native tools and publication boundaries ────────────────────────
echo "1.4 / 3.1 tools and publication"
want "$SKILL" 'MCP' "Skill allows a configured GitHub MCP"
# simplify-github-pr: reports go out as a github-pr reply bound to the reviewed head.
want "$SKILL" 'github-pr reply' "default report form is a github-pr reply"
deny "$SKILL" 'Scope and Baseline first' "remote report no longer requires the full baseline table"
want "$CASES" 'github-pr reply' "cases publish through github-pr reply"
for v in pass changes-required blocked; do want "$SKILL" "$v" "Skill keeps the '$v' verdict"; done
if grep -vE '^- (禁止|Forbidden)：' "$SKILL" "$CHECKS" 2>/dev/null | grep -qE 'github-pr (create|update|close|publish)|Reviews 索引'; then
  bad "Reviewer path invokes no PR create, update, close or review index"
else
  ok "Reviewer path invokes no PR create, update, close or review index"
fi
want "$SKILL" '回讀' "publication is read back"
want "$SKILL" '尚未確認' "unconfirmed publication is a separate state"
if grep -qE 'check-identity|policy[_-]source|script-blob' "$SKILL" "$CASES" "$CHECKS" 2>/dev/null; then
  bad "no identity script, policy or blob prerequisite"
else
  ok "no identity script, policy or blob prerequisite"
fi
# Prohibition lines may name these; instructions must not use them.
if grep -vE '^- (禁止|Forbidden)：' "$SKILL" 2>/dev/null | grep -qE 'gh pr create|gh pr merge|git push|git commit|git add|github-pr (create|publish|update|close)'; then
  bad "Skill instructs no PR create/update/close, merge, commit or push"
else
  ok "Skill instructs no PR create/update/close, merge, commit or push"
fi
want "$SKILL" 'create／update／close' "Skill states the create/update/close boundary explicitly"

# ── 2.x Phase checklists and findings ────────────────────────────────────────
echo "2.x checklists and findings"
[[ -f "$CHECKS" ]] && ok "phase checklists exist" || bad "phase checklists exist"
want "$CHECKS" '## design' "design checklist present"
want "$CHECKS" '## implementation' "implementation checklist present"
want "$CHECKS" 'ponytail-review' "optional quality extension named as optional"
want "$CHECKS" 'openspec-verify-change' "verification Skill used when available"
want "$SKILL" 'references/checklists.md' "Skill links the checklists"
want "$SKILL" '<origin-review-id>/F-NN' "Skill keeps origin-bound finding IDs"

# ── 3.2 / 3.3 Handoff and bounded rounds ─────────────────────────────────────
echo "3.2 / 3.3 handoff and rounds"
want "$SKILL" 'Session' "Skill addresses session handoff"
want "$SKILL" '管理 Session ID' "management session ID is distinguished from the native ID"
want "$SKILL" '一輪' "one invocation performs one round"
want "$SKILL" 'references/review-loop.svg' "Skill links its diagram"

# ── Replay cases ─────────────────────────────────────────────────────────────
echo "replay cases"
[[ -f "$CASES" ]] && ok "replay cases exist" || bad "replay cases exist"
want "$SKILL" 'references/acceptance-cases.md' "Skill links its replay cases"
n="$(grep -cE '^### CR-[0-9]+' "$CASES" 2>/dev/null | tr -d ' ')"
[[ "${n:-0}" -ge 40 ]] && ok "at least 40 cases (${n:-0})" || bad "at least 40 cases (${n:-0})"
for label in 'Fixture：' '模擬回覆：' '預期呼叫：' '禁止：' '判定：'; do
  c="$(grep -cF -- "- $label" "$CASES" 2>/dev/null | tr -d ' ')"
  [[ "${c:-0}" -ge "${n:-999}" && "${n:-0}" -gt 0 ]] \
    && ok "every case states '$label'" || bad "every case states '$label' (${c:-0}/${n:-0})"
done
for topic in 'expected-head' 'MCP' 'approved_at' 'recorded_at' '尚未確認' 'ponytail-review' '管理 Session ID'; do
  want "$CASES" "$topic" "cases cover '$topic'"
done

# ── 4.2 Diagram ──────────────────────────────────────────────────────────────
echo "4.2 diagram"
[[ -f "$SVG" ]] && ok "diagram exists beside the Skill" || bad "diagram exists beside the Skill"
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$SVG" 2>/dev/null && ok "diagram is well-formed XML" || bad "diagram is well-formed XML"
fi
want "$SVG" '<title' "diagram has a title"
want "$SVG" '圖例' "diagram has a text legend"
deny "$SVG" '尚未實作' "diagram is not labelled as unimplemented"
[[ ! -e "$COMMON/docs/diagrams/review-loop.svg" ]] && ok "no seed-only copy in docs" || bad "no seed-only copy in docs"

# ── 4.1 Installation ─────────────────────────────────────────────────────────
echo "4.1 installation"
T="$(new_target)"
mkdir -p "$T/.claude/skills/third-party"; printf 'third\n' > "$T/.claude/skills/third-party/SKILL.md"
run_install "$T"
if diff -r "$SKILL_DIR" "$T/.claude/skills/change-review" >/dev/null 2>&1 \
  && diff -r "$SKILL_DIR" "$T/.agents/skills/change-review" >/dev/null 2>&1; then
  ok "Skill, cases, checklists and diagram reach both skill directories"
else
  bad "Skill, cases, checklists and diagram reach both skill directories"
fi
printf 'stale\n' > "$T/.claude/skills/change-review/references/acceptance-cases.md"
printf '<svg/>\n' > "$T/.agents/skills/change-review/references/review-loop.svg"
run_install "$T"
if cmp -s "$CASES" "$T/.claude/skills/change-review/references/acceptance-cases.md" \
  && cmp -s "$SVG" "$T/.agents/skills/change-review/references/review-loop.svg"; then
  ok "second install refreshes cases and diagram"
else
  bad "second install refreshes cases and diagram"
fi
[[ "$(cat "$T/.claude/skills/third-party/SKILL.md" 2>/dev/null)" == third ]] \
  && ok "unrelated skills are untouched" || bad "unrelated skills are untouched"
if has "$T/docs/github-handoff.md" 'change-review'; then
  ok "installed contract points at the Skill"; else bad "installed contract points at the Skill"; fi

echo "repository installation"
if diff -r "$SKILL_DIR" "$ROOT/.claude/skills/change-review" >/dev/null 2>&1 \
  && diff -r "$SKILL_DIR" "$ROOT/.agents/skills/change-review" >/dev/null 2>&1; then
  ok "repository change-review synchronized"
else
  bad "repository change-review synchronized"
fi

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
