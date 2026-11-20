#!/usr/bin/env bash
# Tests for scripts/user/te-prune-stale-checkouts.py against a throwaway TokenEconomizer state.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/../scripts/user/te-prune-stale-checkouts.py"
pass=0 fail=0
ok() { if eval "$2"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
live="$tmp/live" gone="$tmp/gone" te="$tmp/te"
mkdir -p "$live/.codex" "$te/repos/r1/codex" "$te/repos/r2/claude"
cat > "$te/index.json" <<EOF
{"checkouts": {"$live": {"key": "r1"}, "$gone": {"key": "r1"}, "$tmp/gone2": {"key": "r2"}}}
EOF
cat > "$te/repos/r1/codex/untool_applied.json" <<EOF
{"by_path": {"$live/.codex/config.toml": ["goals"], "$gone/.codex/config.toml": ["goals"]}}
EOF
echo "{\"auto_pending\": {\"items\": [\"goals\"], \"root\": \"$gone\"}}" > "$te/repos/r1/codex/untool.json"
echo "{\"auto_pending\": {\"items\": [\"x\"], \"root\": \"$tmp/gone2\"}}" > "$te/repos/r2/claude/untool.json"

TOKENECONOMIZER_HOME="$te" python3 -I "$script" --dry-run > "$tmp/dry.out" 2>&1
ok "dry run reports two checkouts" 'grep -q "removed 2 checkouts" "$tmp/dry.out"'
ok "dry run changes nothing" 'jq -e --arg g "$gone" ".checkouts | has(\$g)" "$te/index.json" >/dev/null'

TOKENECONOMIZER_HOME="$te" python3 -I "$script" > "$tmp/run.out" 2>&1; rc=$?
ok "run exits 0" '[[ $rc -eq 0 ]]'
ok "missing checkouts removed, live kept" 'jq -e --arg l "$live" ".checkouts | keys == [\$l]" "$te/index.json" >/dev/null'
ok "applied path of a gone checkout removed" 'jq -e --arg l "$live/.codex/config.toml" ".by_path | keys == [\$l]" "$te/repos/r1/codex/untool_applied.json" >/dev/null'
ok "pending root moved to a live checkout of the same repo" 'jq -e --arg l "$live" ".auto_pending.root == \$l" "$te/repos/r1/codex/untool.json" >/dev/null'
ok "pending dropped when the repo has no checkout left" 'jq -e "has(\"auto_pending\") | not" "$te/repos/r2/claude/untool.json" >/dev/null'
TOKENECONOMIZER_HOME="$te" python3 -I "$script" > "$tmp/again.out" 2>&1
ok "second run finds nothing" 'grep -q "removed 0 checkouts" "$tmp/again.out" && [[ $(wc -l < "$tmp/again.out") -eq 1 ]]'

echo "te-prune: $pass passed, $fail failed"
(( fail == 0 ))
