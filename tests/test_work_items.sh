#!/usr/bin/env bash
# Verifies the Work Item records capability: the convention source is a managed,
# tool-neutral file; the installer delivers it, merges a versioned ignore rule,
# verifies ignore protection by effect in both directions, and reports what it
# cannot fix; and the activation entry is reachable from the loaded root
# instruction file. Maps to openspec/changes/add-work-item-records specs.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
CONVENTION="$COMMON/work-items/AGENTS.md"
BANNER='Managed by wk-agent-ops'
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

# ── install harness ──────────────────────────────────────────────────────────
# One parent root created in this shell. new_target runs inside a command
# substitution, so a subshell cannot register anything back here; uniqueness comes
# from mktemp instead of a shared array, and removing the root removes every fixture.
TMPROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT

mk_target() {                      # $1 = target dir; creates a git repo root
  mkdir -p "$1"
  git init -q -b main "$1"
  git -C "$1" config --local user.name probe
  git -C "$1" config --local user.email probe@example.com
}
new_target() {                     # echoes a fresh target dir under TMPROOT
  local d; d="$(mktemp -d "$TMPROOT/t.XXXXXX")"; mk_target "$d/repo"; printf '%s\n' "$d/repo"
}
run_install() {                    # $1 = target; stdout+stderr -> $1/../install.log
  bash "$ROOT/scripts/skills/install.sh" --target "$1" > "$1/../install.log" 2>&1
}
sum1() { shasum "$1" 2>/dev/null | awk '{print $1}'; }

# ── 1.1 Convention source is managed and tool-neutral ────────────────────────
echo "1.1 convention source"
[[ -f "$CONVENTION" ]] && ok "convention source exists" || bad "convention source exists"
grep -q "$BANNER" "$CONVENTION" 2>/dev/null \
  && ok "convention carries the managed banner" || bad "convention carries the managed banner"
missing=""
for field in type title description tags timestamp; do
  grep -qE "^${field}:" "$CONVENTION" 2>/dev/null || missing="$missing $field"
done
[[ -z "$missing" ]] && ok "convention frontmatter complete" || bad "convention frontmatter complete (missing:$missing)"
if grep -qiE '\bcodex\b|antigravity' "$CONVENTION" 2>/dev/null; then
  bad "convention names no secondary tool"
else
  ok "convention names no secondary tool"
fi

# ── 1.2 Convention states the two boundaries ─────────────────────────────────
echo "1.2 convention boundaries"
grep -q 'active writer' "$CONVENTION" 2>/dev/null \
  && ok "convention keeps the single-active-writer rule binding" || bad "convention keeps the single-active-writer rule binding"
grep -q '可追蹤' "$CONVENTION" 2>/dev/null \
  && ok "convention requires the convention file to stay trackable" || bad "convention requires the convention file to stay trackable"
if grep -q 'info/exclude' "$CONVENTION" 2>/dev/null && grep -q 'core.excludesFile' "$CONVENTION" 2>/dev/null; then
  ok "convention rejects non-versioned exclusion as sufficient"
else
  bad "convention rejects non-versioned exclusion as sufficient"
fi
# regression: the pre-existing rules this task must not weaken
grep -q '不得使用強制加入繞過忽略規則' "$CONVENTION" 2>/dev/null \
  && ok "existing no-force-add rule preserved" || bad "existing no-force-add rule preserved"
grep -q '不等於' "$CONVENTION" 2>/dev/null \
  && ok "existing authority boundary preserved" || bad "existing authority boundary preserved"
grep -q '不修改或刪除其他 Agent 的紀錄' "$CONVENTION" 2>/dev/null \
  && ok "existing write-ownership rules preserved" || bad "existing write-ownership rules preserved"

# ── 2.1 Managed delivery of the convention file ──────────────────────────────
echo "2.1 managed delivery"
T="$(new_target)"
printf '# project own AGENTS\n' > "$T/AGENTS.md"
printf 'see @AGENTS.md\n'       > "$T/CLAUDE.md"
mkdir -p "$T/work-items/WI-20260101-keep"
printf 'record\n' > "$T/work-items/WI-20260101-keep/README.md"
A_BEFORE="$(sum1 "$T/AGENTS.md")"; C_BEFORE="$(sum1 "$T/CLAUDE.md")"
R_BEFORE="$(sum1 "$T/work-items/WI-20260101-keep/README.md")"
N_BEFORE="$(find "$T/work-items" -mindepth 2 -type f | wc -l | tr -d ' ')"

run_install "$T"
cmp -s "$CONVENTION" "$T/work-items/AGENTS.md" \
  && ok "first install creates work-items/AGENTS.md byte-identical" || bad "first install creates work-items/AGENTS.md byte-identical"

printf 'local edit\n' > "$T/work-items/AGENTS.md"
run_install "$T"
cmp -s "$CONVENTION" "$T/work-items/AGENTS.md" \
  && ok "re-install overwrites a locally edited managed file" || bad "re-install overwrites a locally edited managed file"

[[ -f "$T/docs/agent-protocol.md" ]] \
  && ok "managed docs still delivered" || bad "managed docs still delivered"
[[ -f "$T/docs/architecture.md" ]] \
  && ok "seed docs still delivered" || bad "seed docs still delivered"
[[ "$(sum1 "$T/AGENTS.md")" == "$A_BEFORE" ]] \
  && ok "existing AGENTS.md untouched" || bad "existing AGENTS.md untouched"
[[ "$(sum1 "$T/CLAUDE.md")" == "$C_BEFORE" ]] \
  && ok "existing CLAUDE.md untouched" || bad "existing CLAUDE.md untouched"
[[ "$(sum1 "$T/work-items/WI-20260101-keep/README.md")" == "$R_BEFORE" ]] \
  && ok "existing record content untouched" || bad "existing record content untouched"
[[ "$(find "$T/work-items" -mindepth 2 -type f | wc -l | tr -d ' ')" == "$N_BEFORE" ]] \
  && ok "no file added or removed inside WI-*/" || bad "no file added or removed inside WI-*/"

# ── 2.2 Ignore rule merge keyed on the versioned project rule ────────────────
echo "2.2 versioned ignore rule merge"
RULE='/work-items/WI-*/'
count_rule() { grep -cxF "$RULE" "$1" 2>/dev/null | tr -d ' '; }

T="$(new_target)"; printf 'build/\nnode_modules/\n' > "$T/.gitignore"
run_install "$T"
[[ "$(count_rule "$T/.gitignore")" == 1 ]] \
  && ok "rule appended once to an existing .gitignore" || bad "rule appended once to an existing .gitignore"
[[ "$(sed -n '1p' "$T/.gitignore")" == 'build/' && "$(sed -n '2p' "$T/.gitignore")" == 'node_modules/' ]] \
  && ok "pre-existing lines preserved in order" || bad "pre-existing lines preserved in order"
run_install "$T"
[[ "$(count_rule "$T/.gitignore")" == 1 ]] \
  && ok "exactly one rule line after two runs" || bad "exactly one rule line after two runs"

T2="$(new_target)"; printf 'work-items/WI-*/\n' > "$T2/.gitignore"
L2_BEFORE="$(wc -l < "$T2/.gitignore" | tr -d ' ')"
run_install "$T2"; run_install "$T2"
if [[ "$(count_rule "$T2/.gitignore")" == 0 \
  && "$(wc -l < "$T2/.gitignore" | tr -d ' ')" == "$L2_BEFORE" ]]; then
  ok "existing versioned equivalent rule is not duplicated"
else
  bad "existing versioned equivalent rule is not duplicated"
fi

T3="$(new_target)"; rm -f "$T3/.gitignore"
run_install "$T3"
[[ -f "$T3/.gitignore" && "$(count_rule "$T3/.gitignore")" == 1 ]] \
  && ok "missing .gitignore is created with the rule" || bad "missing .gitignore is created with the rule"

# ── 2.3 Effect verified in both directions; conflicts reported ───────────────
echo "2.3 effect verification and reporting"
log_of() { cat "$1/../install.log" 2>/dev/null; }

# positive: untracked record ignored, convention trackable, nothing staged
T="$(new_target)"; run_install "$T"
mkdir -p "$T/work-items/WI-20260101-p"; printf 'r\n' > "$T/work-items/WI-20260101-p/README.md"
if git -C "$T" check-ignore -q work-items/WI-20260101-p/README.md; then
  ok "untracked record resolves as ignored"; else bad "untracked record resolves as ignored"; fi
if git -C "$T" check-ignore -q work-items/AGENTS.md; then
  bad "convention file stays trackable"; else ok "convention file stays trackable"; fi
git -C "$T" add -A >/dev/null 2>&1
if git -C "$T" diff --cached --name-only | grep -q 'WI-20260101-p'; then
  bad "git add -A stages no record"; else ok "git add -A stages no record"; fi

# parent-level rule hides the convention
T="$(new_target)"; printf '/work-items/\n' > "$T/.gitignore"; run_install "$T"
if log_of "$T" | grep -q 'convention cannot be tracked'; then
  ok "parent-level rule reported"; else bad "parent-level rule reported"; fi
if log_of "$T" | grep -q 'protection is NOT in effect'; then
  ok "parent-level case does not claim protection"; else bad "parent-level case does not claim protection"; fi

# later negation defeats the literal rule
T="$(new_target)"; printf '/work-items/WI-*/\n!/work-items/WI-*/\n' > "$T/.gitignore"; run_install "$T"
if log_of "$T" | grep -q 'record path is not ignored' \
  && log_of "$T" | grep -q 'protection is NOT in effect' \
  && log_of "$T" | grep -qE 'matched by: \.gitignore:[0-9]+:!'; then
  ok "negation reported with path and responsible rule"
else
  bad "negation reported with path and responsible rule"
fi
[[ "$(count_rule "$T/.gitignore")" == 1 ]] \
  && ok "negation case appends no duplicate rule" || bad "negation case appends no duplicate rule"

# already-tracked record
T="$(new_target)"
mkdir -p "$T/work-items/WI-20260101-tracked"; printf 'r\n' > "$T/work-items/WI-20260101-tracked/README.md"
git -C "$T" add -A >/dev/null 2>&1
git -C "$T" commit -qm init --no-verify >/dev/null 2>&1
IDX_BEFORE="$(git -C "$T" ls-files -s | shasum | awk '{print $1}')"
run_install "$T"
if log_of "$T" | grep -q 'already tracked in Git'; then
  ok "tracked record reported"; else bad "tracked record reported"; fi
[[ "$(git -C "$T" ls-files -s | shasum | awk '{print $1}')" == "$IDX_BEFORE" ]] \
  && ok "installer leaves the Git index unmodified" || bad "installer leaves the Git index unmodified"

# ── 2.4 Exclusion that is not versioned is not a substitute ──────────────────
# These fixtures guard the criterion implemented in 2.2 (skip only on a versioned
# rule). They pass without further production code; the causal check that proves
# they have teeth is recorded in the change's verification notes.
echo "2.4 non-versioned exclusion"

# (a) effect supplied only by the repository-local exclude file
T="$(new_target)"; printf 'build/\n' > "$T/.gitignore"
mkdir -p "$T/.git/info"; printf '/work-items/WI-*/\n' > "$T/.git/info/exclude"
EXC_BEFORE="$(sum1 "$T/.git/info/exclude")"
run_install "$T"
[[ "$(count_rule "$T/.gitignore")" == 1 ]] \
  && ok "info/exclude effect still gets the versioned rule" || bad "info/exclude effect still gets the versioned rule"
[[ "$(sum1 "$T/.git/info/exclude")" == "$EXC_BEFORE" ]] \
  && ok "repository-local exclude file not edited" || bad "repository-local exclude file not edited"

# (b) effect supplied only by a personal global excludes file (isolated config)
T="$(new_target)"; printf 'build/\n' > "$T/.gitignore"
G="$(mktemp -d "$TMPROOT/g.XXXXXX")"
printf '/work-items/WI-*/\n' > "$G/personal-ignore"
printf '[core]\n\texcludesFile = %s/personal-ignore\n' "$G" > "$G/gitconfig"
CFG_BEFORE="$(sum1 "$G/gitconfig")"; PIG_BEFORE="$(sum1 "$G/personal-ignore")"
GIT_CONFIG_GLOBAL="$G/gitconfig" run_install "$T"
[[ "$(count_rule "$T/.gitignore")" == 1 ]] \
  && ok "personal excludesFile effect still gets the versioned rule" || bad "personal excludesFile effect still gets the versioned rule"
if [[ "$(sum1 "$G/gitconfig")" == "$CFG_BEFORE" && "$(sum1 "$G/personal-ignore")" == "$PIG_BEFORE" ]]; then
  ok "personal Git configuration not changed"
else
  bad "personal Git configuration not changed"
fi

# (c) same project files, no local or personal exclusion
T="$(new_target)"; run_install "$T"
SRC="$(git -C "$T" check-ignore -v --no-index -- work-items/WI-20260101-x/README.md 2>/dev/null | awk -F: 'NR==1{print $1}')"
[[ "$SRC" == ".gitignore" ]] \
  && ok "versioned rule alone supplies the effect" || bad "versioned rule alone supplies the effect (source: ${SRC:-none})"
mkdir -p "$T/work-items/WI-20260101-x"; printf 'r\n' > "$T/work-items/WI-20260101-x/README.md"
git -C "$T" add -A >/dev/null 2>&1
if git -C "$T" diff --cached --name-only | grep -q 'WI-20260101-x'; then
  bad "versioned rule alone keeps records out of staging"
else
  ok "versioned rule alone keeps records out of staging"
fi

# ── 3.1 Provider-native activation entry ─────────────────────────────────────
echo "3.1 activation entry"
RULE_SRC="$COMMON/.claude/rules/work-items.md"
[[ -f "$RULE_SRC" ]] && ok "rules entry exists in the template" || bad "rules entry exists in the template"
grep -q 'work-items/AGENTS.md' "$RULE_SRC" 2>/dev/null \
  && ok "rules entry points at the single source" || bad "rules entry points at the single source"
if [[ -f "$RULE_SRC" ]] && [[ "$(wc -l < "$RULE_SRC" | tr -d ' ')" -le 30 ]]; then
  ok "rules entry stays short"; else bad "rules entry stays short"; fi
# Structural guard: a pointer has no rule list, so no bullet lines at all. A
# keyword blacklist alone cannot show that nothing was restated.
if [[ "$(grep -c '^- ' "$RULE_SRC" 2>/dev/null | tr -d ' ')" == 0 ]]; then
  ok "rules entry carries no rule list"; else bad "rules entry carries no rule list"; fi
if grep -qE '查詢資料|cancelled|Coordinator|列出 `?work-items/WI|不自動建立|沒有實質進展' "$RULE_SRC" 2>/dev/null; then
  bad "rules entry restates no convention rules"
else
  ok "rules entry restates no convention rules"
fi
# The entry must not direct anyone to edit a managed install target.
if grep -qE '(只修改|修改|編輯|更新)[^。]*work-items/AGENTS\.md' "$RULE_SRC" 2>/dev/null; then
  bad "rules entry does not instruct editing a managed target"
else
  ok "rules entry does not instruct editing a managed target"
fi
T="$(new_target)"; run_install "$T"
if cmp -s "$RULE_SRC" "$T/.claude/rules/work-items.md" \
  && cmp -s "$RULE_SRC" "$T/.agents/rules/work-items.md"; then
  ok "rules entry reaches .claude/rules and the .agents/rules mirror"
else
  bad "rules entry reaches .claude/rules and the .agents/rules mirror"
fi

# ── 3.2 Managed protocol points at the convention ────────────────────────────
echo "3.2 protocol pointer"
PROTO="$COMMON/docs/agent-protocol.md"
grep -q 'work-items/AGENTS.md' "$PROTO" 2>/dev/null \
  && ok "protocol references the convention" || bad "protocol references the convention"
grep -qE '^\| Version \| 2\.6\.0' "$PROTO" 2>/dev/null \
  && ok "protocol version bumped" || bad "protocol version bumped"
# every repo-relative reference the protocol makes must ship into a target
T="$(new_target)"; run_install "$T"
missing_ref=""
while read -r ref; do
  [[ -z "$ref" ]] && continue
  [[ -e "$T/$ref" ]] || missing_ref="$missing_ref $ref"
done < <(grep -oE '(docs|work-items)/[A-Za-z0-9_.-]+\.md' "$PROTO" 2>/dev/null | sort -u)
[[ -z "$missing_ref" ]] \
  && ok "every protocol reference ships into the target" || bad "every protocol reference ships into the target (missing:$missing_ref)"

# ── 3.3 Seed AGENTS.md keeps a short pointer; no CLAUDE.md is distributed ────
echo "3.3 seed pointer and no CLAUDE.md"
SEED="$COMMON/AGENTS.md"
grep -q 'Work Item' "$SEED" 2>/dev/null \
  && ok "seed AGENTS.md has a Work Item section" || bad "seed AGENTS.md has a Work Item section"
grep -q 'work-items/AGENTS.md' "$SEED" 2>/dev/null \
  && ok "seed pointer names the single source" || bad "seed pointer names the single source"
SEC_LINES="$(awk '/^## Work Item/{f=1;next} f&&/^## /{exit} f{print}' "$SEED" 2>/dev/null | grep -c '[^[:space:]]' | tr -d ' ')"
[[ "${SEC_LINES:-99}" -le 4 ]] \
  && ok "seed pointer stays short (${SEC_LINES} non-blank lines)" || bad "seed pointer stays short (${SEC_LINES} non-blank lines)"
if grep -q '不必等待使用者逐次要求記錄' "$SEED" 2>/dev/null; then
  bad "seed pointer restates no convention rules"
else
  ok "seed pointer restates no convention rules"
fi
[[ ! -e "$COMMON/CLAUDE.md" ]] \
  && ok "template distributes no CLAUDE.md" || bad "template distributes no CLAUDE.md"
T="$(new_target)"; printf 'see @AGENTS.md\n' > "$T/CLAUDE.md"; CB="$(sum1 "$T/CLAUDE.md")"
run_install "$T"
[[ "$(sum1 "$T/CLAUDE.md")" == "$CB" ]] \
  && ok "install leaves a target CLAUDE.md byte-identical" || bad "install leaves a target CLAUDE.md byte-identical"

# ── 3.4 Activation chain checked from the loaded root instruction ────────────
echo "3.4 activation chain check"
CHAIN_OK='Work Item activation chain'

# (a) seeded AGENTS.md points at the protocol -> chain confirmed
T="$(new_target)"; run_install "$T"
log_of "$T" | grep -q "$CHAIN_OK" \
  && ok "complete chain is confirmed" || bad "complete chain is confirmed"

# (b) custom AGENTS.md without the pointer -> reported, not repaired
T="$(new_target)"; printf '# my project\n\nno pointer here\n' > "$T/AGENTS.md"
AB="$(sum1 "$T/AGENTS.md")"
run_install "$T"
if log_of "$T" | grep -q 'activation is NOT active'; then
  ok "broken first link reported"; else bad "broken first link reported"; fi
if log_of "$T" | grep -q 'AGENTS.md'; then
  ok "report names the examined file"; else bad "report names the examined file"; fi
if log_of "$T" | grep -q 'Agent Operating Protocol'; then
  ok "report states the pointer section to add"; else bad "report states the pointer section to add"; fi
[[ "$(sum1 "$T/AGENTS.md")" == "$AB" ]] \
  && ok "project AGENTS.md left byte-identical" || bad "project AGENTS.md left byte-identical"
if log_of "$T" | grep -q "$CHAIN_OK"; then
  bad "broken chain is not reported as confirmed"; else ok "broken chain is not reported as confirmed"; fi
if [[ -f "$T/.claude/rules/work-items.md" && -f "$T/.agents/rules/work-items.md" ]]; then
  ok "provider rules installed yet chain still reported broken"
else
  bad "provider rules installed yet chain still reported broken"
fi

# (c) a non-empty override file wins over a correct AGENTS.md
T="$(new_target)"
printf '# ok\n\nread `docs/agent-protocol.md` first\n' > "$T/AGENTS.md"
printf '# override\n\nno pointer here\n' > "$T/AGENTS.override.md"
OB="$(sum1 "$T/AGENTS.override.md")"; AB="$(sum1 "$T/AGENTS.md")"
run_install "$T"
if log_of "$T" | grep -q 'AGENTS.override.md'; then
  ok "override file is the one examined"; else bad "override file is the one examined"; fi
if log_of "$T" | grep -q 'activation is NOT active'; then
  ok "override case reported broken"; else bad "override case reported broken"; fi
if [[ "$(sum1 "$T/AGENTS.override.md")" == "$OB" && "$(sum1 "$T/AGENTS.md")" == "$AB" ]]; then
  ok "no project-owned instruction file modified"
else
  bad "no project-owned instruction file modified"
fi

# (d) loaded file cannot be determined -> reported unverified
T="$(new_target)"; : > "$T/AGENTS.md"
run_install "$T"
if log_of "$T" | grep -q 'UNVERIFIED'; then
  ok "undeterminable root instruction reported unverified"; else bad "undeterminable root instruction reported unverified"; fi

# ── 2.6 Per-record exceptions and equivalent rule spellings ─────────────────
echo "2.6 real record paths and equivalent rules"

# (a) an exception for one specific existing WI must be detected and named
T="$(new_target)"
printf '/work-items/WI-*/\n!/work-items/WI-20260101-exempt/\n' > "$T/.gitignore"
mkdir -p "$T/work-items/WI-20260101-exempt"; printf 'r\n' > "$T/work-items/WI-20260101-exempt/README.md"
GI_BEFORE="$(sum1 "$T/.gitignore")"
run_install "$T"
if log_of "$T" | grep -q 'WI-20260101-exempt'; then
  ok "per-record exception reported with the concrete path"; else bad "per-record exception reported with the concrete path"; fi
if log_of "$T" | grep -q 'protection is NOT in effect'; then
  ok "per-record exception does not claim protection"; else bad "per-record exception does not claim protection"; fi
if log_of "$T" | grep -qE 'matched by: \.gitignore:[0-9]+'; then
  ok "report names the rule source and line"; else bad "report names the rule source and line"; fi
[[ "$(sum1 "$T/.gitignore")" == "$GI_BEFORE" ]] \
  && ok "user exception is not rewritten" || bad "user exception is not rewritten"
git -C "$T" add -A >/dev/null 2>&1
if git -C "$T" diff --cached --name-only | grep -q 'WI-20260101-exempt'; then
  ok "staging of the exempt record is a reported gap, not a silent pass"
else
  bad "staging of the exempt record is a reported gap, not a silent pass"
fi

# (c) an exception for individual files inside an existing record, including a
#     nested one, must be detected per file rather than via one representative
T="$(new_target)"
printf '%s\n' \
  '/work-items/WI-*/' \
  '!/work-items/WI-20260101-files/' \
  '/work-items/WI-20260101-files/*' \
  '!/work-items/WI-20260101-files/context.md' \
  '!/work-items/WI-20260101-files/agents/' \
  '/work-items/WI-20260101-files/agents/*' \
  '!/work-items/WI-20260101-files/agents/note.md' > "$T/.gitignore"
mkdir -p "$T/work-items/WI-20260101-files/agents"
printf 'r\n' > "$T/work-items/WI-20260101-files/README.md"
printf 'c\n' > "$T/work-items/WI-20260101-files/context.md"
printf 'n\n' > "$T/work-items/WI-20260101-files/agents/note.md"
GI_BEFORE="$(sum1 "$T/.gitignore")"
run_install "$T"
if log_of "$T" | grep -q 'context.md'; then
  ok "per-file exception reported (top-level file)"; else bad "per-file exception reported (top-level file)"; fi
if log_of "$T" | grep -q 'agents/note.md'; then
  ok "per-file exception reported (nested file)"; else bad "per-file exception reported (nested file)"; fi
if log_of "$T" | grep -q 'protection is NOT in effect'; then
  ok "per-file exception does not claim protection"; else bad "per-file exception does not claim protection"; fi
if log_of "$T" | grep -qE 'matched by: \.gitignore:[0-9]+:!/work-items/WI-20260101-files/context\.md'; then
  ok "report names the file-specific rule that wins"; else bad "report names the file-specific rule that wins"; fi
[[ "$(sum1 "$T/.gitignore")" == "$GI_BEFORE" ]] \
  && ok "per-file exception is not rewritten" || bad "per-file exception is not rewritten"

# (b) a subtree-equivalent versioned rule must not trigger a second rule
T="$(new_target)"; printf '/work-items/WI-*/**\n' > "$T/.gitignore"
L_BEFORE="$(wc -l < "$T/.gitignore" | tr -d ' ')"
run_install "$T"; run_install "$T"
if [[ "$(count_rule "$T/.gitignore")" == 0 \
  && "$(wc -l < "$T/.gitignore" | tr -d ' ')" == "$L_BEFORE" ]]; then
  ok "subtree-equivalent versioned rule is not duplicated"
else
  bad "subtree-equivalent versioned rule is not duplicated"
fi
if log_of "$T" | grep -q 'protection is NOT in effect'; then
  bad "subtree-equivalent rule counts as protection in effect"
else
  ok "subtree-equivalent rule counts as protection in effect"
fi

# ── harness hygiene ─────────────────────────────────────────────────────────
echo "harness hygiene"
T="$(new_target)"
[[ -n "${TMPROOT:-}" && "$T" == "$TMPROOT"/* ]] \
  && ok "targets are created under the single cleanup root" || bad "targets are created under the single cleanup root"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
