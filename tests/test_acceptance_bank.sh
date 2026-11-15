#!/usr/bin/env bash
# Verifies the skill acceptance-case bank: replayable cases for the instruction
# skills live under tests/acceptance/, every case is complete and uniquely
# identified, case references resolve, removals are recorded, and the shipped
# skills carry run-time material only.
# Maps to openspec/changes/separate-github-contract-from-workflow
# specs/skill-acceptance-cases and specs/install-profile-cli.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
BANK="$ROOT/tests/acceptance"
SKILLS="openspec-commit github-pr github-issue git-commit-writer change-review"
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }

ID_RE='(C|GI|GP|CR|OC|WC)-[0-9]+'
bank_files() { local f; for f in "$BANK/shared.md" $(for s in $SKILLS; do printf '%s ' "$BANK/$s.md"; done); do [[ -f "$f" ]] && printf '%s\n' "$f"; done; }
# Case identifiers that head a case anywhere in the bank.
case_ids() { bank_files | xargs grep -hoE "^### $ID_RE " 2>/dev/null | awk '{print $2}'; }

# ── 1 Layout ──────────────────────────────────────────────────────────────────
echo "1 bank layout"
for f in README.md shared.md; do
  [[ -f "$BANK/$f" ]] && ok "tests/acceptance/$f exists" || bad "tests/acceptance/$f exists"
done
for s in $SKILLS; do
  [[ -f "$BANK/$s.md" ]] && ok "tests/acceptance/$s.md exists" || bad "tests/acceptance/$s.md exists"
done

# ── 2 Every case is complete ──────────────────────────────────────────────────
echo "2 case fields"
total="$(case_ids | wc -l | tr -d ' ')"
[[ "${total:-0}" -gt 0 ]] && ok "bank holds cases ($total)" || bad "bank holds cases"
missing="$(bank_files | while read -r f; do
  awk -v file="${f#"$ROOT"/}" '
    function flush() {
      if (id == "") return
      for (i = 1; i <= 5; i++) if (!(lab[i] in seen)) printf "%s %s lacks %s\n", file, id, lab[i]
    }
    BEGIN { lab[1]="Fixture："; lab[2]="模擬回覆："; lab[3]="預期呼叫："; lab[4]="禁止："; lab[5]="判定：" }
    /^### (C|GI|GP|CR|OC|WC)-[0-9]+ / { flush(); id = $2; delete seen; next }
    /^## / { flush(); id = ""; next }
    id != "" { for (i = 1; i <= 5; i++) if (index($0, "- " lab[i]) == 1) seen[lab[i]] = 1 }
    END { flush() }' "$f"
done)"
if [[ -z "$missing" ]]; then ok "every case states Fixture, 模擬回覆, 預期呼叫, 禁止, 判定"
else bad "every case states Fixture, 模擬回覆, 預期呼叫, 禁止, 判定"; printf '%s\n' "$missing" | sed 's/^/       /'; fi

# ── 3 Identifiers are unique across the bank ──────────────────────────────────
echo "3 unique identifiers"
dups="$(case_ids | sort | uniq -d)"
[[ -z "$dups" ]] && ok "case identifiers are unique across the bank" || bad "case identifiers are unique across the bank: $(echo $dups)"

# ── 4 Case references resolve ─────────────────────────────────────────────────
echo "4 case references"
known="$(case_ids | sort -u)"
# A range such as "GP-01–GP-20" names retired identifiers, not a reference.
refs="$(bank_files | xargs cat 2>/dev/null | sed -E "s/$ID_RE[–-]$ID_RE//g" \
  | grep -oE "(^|[^A-Za-z0-9])$ID_RE" | grep -oE "$ID_RE" | sort -u)"
dangling="$(comm -23 <(printf '%s\n' "$refs") <(printf '%s\n' "$known"))"
[[ -z "$dangling" ]] && ok "every case reference resolves" || bad "every case reference resolves: $(echo $dangling)"
c17="$(awk '/^### C-17 /{f=1;next} f&&/^##/{exit} f' "$BANK/shared.md" 2>/dev/null)"
if [[ -n "$c17" ]] && grep -q '同 C-16' <<<"$c17"; then
  grep -q '^### C-16 ' "$BANK/shared.md" && ok "C-17 can reuse C-16 (C-16 is kept)" || bad "C-17 can reuse C-16 (C-16 is kept)"
else
  [[ -n "$c17" ]] && ok "C-17 states its own fixture and calls" || bad "C-17 is present in shared.md"
fi

# ── 5 Removals are recorded ───────────────────────────────────────────────────
echo "5 removal record"
table="$(awk '/^## 去重對照/{f=1;next} f&&/^## /{exit} f' "$BANK/README.md" 2>/dev/null | grep -E '^\| *(C|GI|GP|CR|OC|WC)-[0-9]+')"
[[ -n "$table" ]] && ok "README records the duplicate review" || bad "README records the duplicate review"
while IFS='|' read -r _ cand covered result _; do
  cand="$(echo $cand)"; covered="$(echo $covered)"; result="$(echo $result)"
  [[ -z "$cand" ]] && continue
  grep -qx -- "$covered" <<<"$known" && ok "$cand: covering case $covered exists" || bad "$cand: covering case $covered exists"
  case "$result" in
    刪除*) grep -qx -- "$cand" <<<"$known" && bad "$cand removed as recorded" || ok "$cand removed as recorded" ;;
    保留*) grep -qx -- "$cand" <<<"$known" && ok "$cand kept as recorded" || bad "$cand kept as recorded" ;;
    *) bad "$cand has a recorded result (刪除 or 保留)" ;;
  esac
done <<<"$table"
for pair in GP-58:GI-46 GP-65:GI-33 GP-46:GI-41 GP-21:GI-02 WC-14:GP-90; do
  a="${pair%%:*}"; b="${pair##*:}"
  grep -qx -- "$a" <<<"$known" && grep -qx -- "$b" <<<"$known" \
    && ok "parallel entry cases $a and $b are both kept" || bad "parallel entry cases $a and $b are both kept"
done

# ── 6 Shipped skills carry run-time material only ─────────────────────────────
echo "6 shipped skills"
found="$(find "$COMMON/skills" -name 'acceptance-cases.md' 2>/dev/null)"
[[ -z "$found" ]] && ok "no shipped skill contains acceptance-cases.md" || bad "no shipped skill contains acceptance-cases.md: ${found//$ROOT\//}"
mentions="$(grep -rl 'acceptance-cases' "$COMMON/skills" 2>/dev/null)"
[[ -z "$mentions" ]] && ok "no shipped skill file mentions acceptance-cases" || bad "no shipped skill file mentions acceptance-cases: $(echo ${mentions//$ROOT\//})"
for s in $SKILLS; do
  dir="$COMMON/skills/$s"
  [[ -d "$dir/references" ]] || continue
  for ref in "$dir"/references/*; do
    [[ -f "$ref" ]] || continue
    name="references/$(basename "$ref")"
    # The SKILL.md line naming the reference must also state when to read it.
    if grep -F -- "$name" "$dir/SKILL.md" 2>/dev/null | grep -qiE '\b(read|open)\b.*\b(when|before|if|for)\b|\b(when|before|if)\b.*\b(read|open)\b'; then
      ok "$s names $name with a reading condition"
    else
      bad "$s names $name with a reading condition"
    fi
  done
done

# ── 7 Installer retires shipped bank copies, and only those ──────────────────
echo "7 installer retirement"
TMPROOT="$(mktemp -d)"; trap 'rm -rf "$TMPROOT"' EXIT
new_target() { local d; d="$(mktemp -d "$TMPROOT/t.XXXXXX")"; mkdir -p "$d/repo"; git init -q -b main "$d/repo"; printf '%s\n' "$d/repo"; }
run_install() { bash "$ROOT/scripts/skills/install.sh" --target "$1" > "$1/../install.log" 2>&1; }
log_of() { cat "$1/../install.log" 2>/dev/null; }
OLD_PATH() { printf 'template/common/skills/%s/references/acceptance-cases.md' "$1"; }
# The newest and the oldest shipped version of a skill's bank, from Git history.
# Only commits in which the old path still exists count: once the move is
# committed, the newest commit touching the path is the one that removed it
# (codex-implementation-r01/F-02).
shipped() {                        # $1 skill, $2 newest|oldest → file content on stdout
  local path rev order=()
  path="$(OLD_PATH "$1")"
  [[ "$2" == oldest ]] && order=(--reverse)
  for rev in $(git -C "$ROOT" log ${order[@]+"${order[@]}"} --format=%H -- "$path" 2>/dev/null); do
    if git -C "$ROOT" cat-file -e "$rev:$path" 2>/dev/null; then
      git -C "$ROOT" show "$rev:$path"
      return
    fi
  done
  return 1
}
RETIRED_LIST="$(awk '/^RETIRED_CASE_BLOBS=\(/{f=1;next} f&&/^\)/{exit} f{print $1}' "$ROOT/scripts/skills/install.sh")"
for s in $SKILLS; do
  for v in newest oldest; do
    if shipped "$s" "$v" > "$TMPROOT/$s.$v" && [[ -s "$TMPROOT/$s.$v" ]]; then
      blob="$(git hash-object --no-filters -- "$TMPROOT/$s.$v")"
      grep -qx -- "$blob" <<<"$RETIRED_LIST" && ok "$s $v shipped version extracted and listed for retirement" \
        || bad "$s $v shipped version is on the installer's retirement list ($blob)"
    else
      bad "$s $v shipped version extracted from Git history"
    fi
  done
done

T="$(new_target)"; run_install "$T"
left=0; for r in .claude/skills .agents/skills; do for s in $SKILLS; do
  [[ -e "$T/$r/$s/references/acceptance-cases.md" ]] && left=$((left+1)); done; done
[[ "$left" == 0 ]] && ok "fresh install ships no bank copy in either skills directory" || bad "fresh install ships no bank copy ($left found)"

T="$(new_target)"; run_install "$T"
for r in .claude/skills .agents/skills; do for s in $SKILLS; do
  mkdir -p "$T/$r/$s/references"; cp "$TMPROOT/$s.newest" "$T/$r/$s/references/acceptance-cases.md"; done; done
cp "$TMPROOT/github-pr.oldest" "$T/.claude/skills/github-pr/references/acceptance-cases.md"
cp "$TMPROOT/change-review.oldest" "$T/.agents/skills/change-review/references/acceptance-cases.md"
printf 'local\n' > "$T/.claude/skills/github-issue/references/notes.md"
mkdir -p "$T/.claude/skills/third-party/references"; printf 'third\n' > "$T/.claude/skills/third-party/references/acceptance-cases.md"
run_install "$T"
left=0; for r in .claude/skills .agents/skills; do for s in $SKILLS; do
  [[ -e "$T/$r/$s/references/acceptance-cases.md" ]] && left=$((left+1)); done; done
[[ "$left" == 0 ]] && ok "reinstall removes every unmodified shipped copy, newest and oldest" || bad "reinstall removes every unmodified shipped copy ($left left)"
log_of "$T" | grep -qF 'removed retired .claude/skills/github-pr/references/acceptance-cases.md' \
  && ok "the removal is reported" || bad "the removal is reported"
[[ "$(cat "$T/.claude/skills/github-issue/references/notes.md" 2>/dev/null)" == local ]] \
  && ok "other files beside a retired copy are untouched" || bad "other files beside a retired copy are untouched"
[[ -d "$T/.claude/skills/github-issue/references" ]] && ok "a references directory with other files stays" || bad "a references directory with other files stays"
[[ ! -e "$T/.claude/skills/git-commit-writer/references" ]] \
  && ok "a references directory left empty is removed" || bad "a references directory left empty is removed"
[[ "$(cat "$T/.claude/skills/third-party/references/acceptance-cases.md" 2>/dev/null)" == third ]] \
  && ok "a same-named file in an unlisted skill is untouched" || bad "a same-named file in an unlisted skill is untouched"
run_install "$T"
log_of "$T" | grep -qF 'removed retired' && bad "a second run removes nothing more" || ok "a second run removes nothing more"

T="$(new_target)"; run_install "$T"
mkdir -p "$T/.claude/skills/openspec-commit/references"
{ cat "$TMPROOT/openspec-commit.newest"; printf '\n### OC-99 本地補充\n'; } > "$T/.claude/skills/openspec-commit/references/acceptance-cases.md"
printf 'outside\n' > "$TMPROOT/outside.md"
mkdir -p "$T/.agents/skills/github-pr/references"; ln -s "$TMPROOT/outside.md" "$T/.agents/skills/github-pr/references/acceptance-cases.md"
run_install "$T"
grep -qF 'OC-99' "$T/.claude/skills/openspec-commit/references/acceptance-cases.md" 2>/dev/null \
  && ok "a modified copy is kept" || bad "a modified copy is kept"
log_of "$T" | grep -qF 'left .claude/skills/openspec-commit/references/acceptance-cases.md in place' \
  && ok "a kept modified copy is reported" || bad "a kept modified copy is reported"
[[ -L "$T/.agents/skills/github-pr/references/acceptance-cases.md" ]] && ok "a symlink is kept" || bad "a symlink is kept"
log_of "$T" | grep -qF 'left .agents/skills/github-pr/references/acceptance-cases.md in place' \
  && ok "a kept symlink is reported" || bad "a kept symlink is reported"
[[ "$(cat "$TMPROOT/outside.md")" == outside ]] && ok "a symlink target is untouched" || bad "a symlink target is untouched"

# codex-implementation-r01/F-01: a symlinked ancestor must not let the step reach
# files outside the project. Both the references directory and the skills root.
T="$(new_target)"; run_install "$T"
OUT1="$TMPROOT/outside-refs"; mkdir -p "$OUT1"; cp "$TMPROOT/git-commit-writer.newest" "$OUT1/acceptance-cases.md"
rm -rf "$T/.claude/skills/git-commit-writer/references"; ln -s "$OUT1" "$T/.claude/skills/git-commit-writer/references"
OUT2="$TMPROOT/outside-skills"; mkdir -p "$OUT2/git-commit-writer/references"
cp "$TMPROOT/git-commit-writer.newest" "$OUT2/git-commit-writer/references/acceptance-cases.md"
rm -rf "$T/.agents/skills"; ln -s "$OUT2" "$T/.agents/skills"
sum_before1="$(shasum "$OUT1/acceptance-cases.md" | awk '{print $1}')"; sum_before2="$(shasum "$OUT2/git-commit-writer/references/acceptance-cases.md" | awk '{print $1}')"
run_install "$T"; install_rc=$?
[[ "$install_rc" == 0 ]] && ok "installer completes with symlinked ancestors" || bad "installer completes with symlinked ancestors ($install_rc)"
[[ -f "$OUT1/acceptance-cases.md" && "$(shasum "$OUT1/acceptance-cases.md" | awk '{print $1}')" == "$sum_before1" ]] \
  && ok "a file behind a symlinked references directory is untouched" || bad "a file behind a symlinked references directory is untouched"
[[ -L "$T/.claude/skills/git-commit-writer/references" ]] && ok "the symlinked references directory is kept" || bad "the symlinked references directory is kept"
log_of "$T" | grep -qF 'left .claude/skills/git-commit-writer/references/acceptance-cases.md in place' \
  && ok "a symlinked references directory is reported" || bad "a symlinked references directory is reported"
[[ -f "$OUT2/git-commit-writer/references/acceptance-cases.md" && "$(shasum "$OUT2/git-commit-writer/references/acceptance-cases.md" | awk '{print $1}')" == "$sum_before2" ]] \
  && ok "a file behind a symlinked skills root is untouched" || bad "a file behind a symlinked skills root is untouched"
[[ -L "$T/.agents/skills" ]] && ok "the symlinked skills root is kept" || bad "the symlinked skills root is kept"
log_of "$T" | grep -qF 'left .agents/skills/git-commit-writer/references/acceptance-cases.md in place' \
  && ok "a symlinked skills root is reported" || bad "a symlinked skills root is reported"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
