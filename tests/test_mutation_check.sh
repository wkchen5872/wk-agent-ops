#!/usr/bin/env bash
# Verifies the mutation-check skill installs to both tool dirs, the tdd-enforcement rule
# auto-mirrors from .claude/rules/ to .agents/rules/, docs reference /mutation-check, and
# install.sh never touches the target project's own manifests/config.
# Maps to specs/mutation-check + specs/tdd-enforcement-rules scenarios.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/template/common"
PROTO="$COMMON/docs/agent-protocol.md"
fail=0
ok(){ printf '  ok   %s\n' "$1"; }
bad(){ printf '  FAIL %s\n' "$1"; fail=1; }

# (c) both SKILL.md files exist with complete frontmatter
for name in mutation-setup mutation-check; do
  f="$COMMON/skills/$name/SKILL.md"
  if [[ -f "$f" ]]; then
    ok "$name SKILL.md exists"
    head -20 "$f" | grep -qE '^name:'          && ok "$name has name"          || bad "$name has name"
    head -20 "$f" | grep -qE '^description:'    && ok "$name has description"   || bad "$name has description"
    head -20 "$f" | grep -qE '^compatibility:'  && ok "$name has compatibility" || bad "$name has compatibility"
    grep -qE '^\s*version:' "$f"                 && ok "$name has version"       || bad "$name has version"
  else
    bad "$name SKILL.md exists ($f)"
  fi
done

# (d) protocol doc references /mutation-check
grep -q '/mutation-check' "$PROTO" 2>/dev/null && ok "agent-protocol.md references /mutation-check" || bad "agent-protocol.md references /mutation-check"

# (f) mutation-testing playbook ships as a managed doc with tool + design references
DOC="$COMMON/docs/mutation-testing.md"
if [[ -f "$DOC" ]]; then
  ok "mutation-testing.md ships"
  grep -q 'Managed by wk-agent-ops' "$DOC" && ok "playbook has managed banner" || bad "playbook has managed banner"
  for url in 'stryker-mutator.io' 'mutmut.readthedocs.io' 'stryker-js' 'add-mutation-testing.md' 'test-architect.md'; do
    grep -q "$url" "$DOC" && ok "playbook cites $url" || bad "playbook cites $url"
  done
  grep -q 'mutation-testing.md' "$ROOT/scripts/skills/install.sh" && ok "playbook is a MANAGED_DOC" || bad "playbook is a MANAGED_DOC"
else
  bad "mutation-testing.md ships ($DOC)"
fi

# Install into a scratch target, with pre-existing project manifests we expect UNTOUCHED.
T="$(mktemp -d)"; ( cd "$T" && git init -q )
printf '[project]\nname="x"\n' > "$T/pyproject.toml"
printf '{"name":"x"}\n'        > "$T/package.json"
PY_BEFORE="$(md5 -q "$T/pyproject.toml" 2>/dev/null || md5sum "$T/pyproject.toml")"
PKG_BEFORE="$(md5 -q "$T/package.json" 2>/dev/null || md5sum "$T/package.json")"
bash "$ROOT/scripts/skills/install.sh" --target "$T" >/dev/null 2>&1

# (a) both skills land in both tool dirs, identical
for name in mutation-setup mutation-check; do
  cs="$T/.claude/skills/$name/SKILL.md"; as="$T/.agents/skills/$name/SKILL.md"
  [[ -f "$cs" && -f "$as" ]] && ok "$name installed to .claude/ and .agents/" || bad "$name installed to .claude/ and .agents/"
  [[ -f "$cs" && -f "$as" ]] && { diff -q "$cs" "$as" >/dev/null && ok "$name copies identical" || bad "$name copies identical"; }
done

# (f) managed playbook propagates to target docs/, identical to template
td="$T/docs/mutation-testing.md"
[[ -f "$td" ]] && { diff -q "$COMMON/docs/mutation-testing.md" "$td" >/dev/null && ok "playbook propagated to docs/" || bad "playbook propagated to docs/"; } || bad "playbook propagated to docs/"

# (b) tdd-enforcement rule auto-mirrored .claude/rules/ -> .agents/rules/
cr="$T/.claude/rules/tdd-enforcement.md"; ar="$T/.agents/rules/tdd-enforcement.md"
[[ -f "$cr" && -f "$ar" ]] && { diff -q "$cr" "$ar" >/dev/null && ok "tdd rule mirrored to .agents/rules" || bad "tdd rule mirrored to .agents/rules"; } || bad "tdd rule in both .claude and .agents rules"

# (e) installer must not create/modify the target's own manifests or stryker config
PY_AFTER="$(md5 -q "$T/pyproject.toml" 2>/dev/null || md5sum "$T/pyproject.toml")"
PKG_AFTER="$(md5 -q "$T/package.json" 2>/dev/null || md5sum "$T/package.json")"
[[ "$PY_BEFORE" == "$PY_AFTER" ]]   && ok "pyproject.toml untouched" || bad "pyproject.toml untouched"
[[ "$PKG_BEFORE" == "$PKG_AFTER" ]] && ok "package.json untouched"   || bad "package.json untouched"
[[ ! -e "$T/stryker.config.json" ]] && ok "no stryker.config.json created" || bad "no stryker.config.json created"
rm -rf "$T"

echo
[[ $fail -eq 0 ]] && { echo "PASS"; exit 0; } || { echo "FAIL"; exit 1; }
