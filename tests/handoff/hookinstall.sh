#!/usr/bin/env bash
# Handoff test section "hookinstall". Run: bash tests/test_agent_handoff.sh hookinstall
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- user-level installer and README
  printf 'hook installer\n'
  HH="$tmp/home"; mkdir -p "$HH/.codex"; printf 'keep = true\n' > "$HH/.codex/config.toml"
  out="$(HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" 2>&1)"; rc=$?
  HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$rc" == 0 && -x "$HH/.local/bin/handoff-start" && -x "$HH/.local/bin/handoff-finish" && -x "$HH/.local/bin/handoff-cleanup" && -x "$HH/.local/bin/handoff-role" && -x "$HH/.local/bin/handoff-doctor" && -x "$HH/.config/wk-workflow/handoff/handoff-route" \
    && -f "$HH/.config/wk-workflow/handoff/lib/handoff.sh" && -f "$HH/.config/wk-workflow/handoff/lib/kv.sh" ]]; check "installs the commands, the hook and its libraries" || { printf '       %s\n' "$out"; }
  n_claude="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$HH/.claude/settings.json" 2>/dev/null)"
  n_codex="$(jq '[.hooks.Stop[]?.hooks[]? | select(.command | test("handoff-route"))] | length' "$HH/.codex/hooks.json" 2>/dev/null)"
  [[ "$n_claude" == 1 && "$n_codex" == 1 ]]; check "registers exactly one Stop hook for Claude Code and Codex after two runs" || printf '       %s\n' "($n_claude/$n_codex)"
  NP="$HH/.codex/handoff-net.config.toml"
  [[ -f "$NP" ]] && grep -qx 'sandbox_mode = "workspace-write"' "$NP" && grep -qx 'network_access = true' "$NP"; check "creates the handoff-net Codex profile with network access"
  printf 'model = "mine"\n' > "$NP"; HOME="$HH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$(cat "$NP")" == 'model = "mine"' ]]; check "never overwrites an existing handoff-net profile"
  [[ "$(cat "$HH/.codex/config.toml")" == "keep = true" ]] && grep -qi 'trust' <<<"$out"; check "tells the user to trust the Codex hook and leaves Codex trust state alone"
  (cd "$tmp" && HOME="$HH" "$HH/.local/bin/handoff-start" --help >/dev/null 2>&1); check "installed handoff-start runs with the installed library"

  hname="Agent 交接派送"
  hname_of() { jq -r --arg cmd "$2" '[.hooks.Stop[]?.hooks[]? | select(.command == $cmd) | .statusMessage] | join("|")' "$1"; }
  hcmd="bash \"$HH/.config/wk-workflow/handoff/handoff-route\""
  [[ "$(hname_of "$HH/.codex/hooks.json" "$hcmd")" == "$hname" && "$(jq '[.. | objects | select(has("statusMessage"))] | length' "$HH/.claude/settings.json")" == 0 ]]; check "names the new Codex Stop hook and leaves the Claude Code hook format alone"
  NH="$tmp/name-home"; ncmd="bash \"$NH/.config/wk-workflow/handoff/handoff-route\""; nfail=""
  for blank in absent null '""' '"   "'; do
    rm -rf "$NH"; mkdir -p "$NH/.codex"
    jq -n --arg cmd "$ncmd" --arg blank "$blank" \
      '{hooks:{Stop:[{matcher:"",hooks:[{type:"command",command:$cmd,timeout:10} + (if $blank == "absent" then {} else {statusMessage:($blank|fromjson)} end)]}]}}' > "$NH/.codex/hooks.json"
    HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
    [[ "$(hname_of "$NH/.codex/hooks.json" "$ncmd")" == "$hname" && "$(jq '[.hooks.Stop[]?.hooks[]?] | length' "$NH/.codex/hooks.json")" == 1 ]] || nfail="$nfail $blank"
  done
  [[ -z "$nfail" ]]; check "fills absent, null, empty and whitespace handoff names in place" || printf '       %s\n' "(failed:$nfail)"
  rm -rf "$NH"; mkdir -p "$NH/.codex"; printf 'keep = true\n' > "$NH/.codex/config.toml"
  jq -n --arg cmd "$ncmd" '{top:"keep",hooks:{Stop:[{matcher:"",note:"keep",hooks:[{type:"command",command:"other-stop",statusMessage:"第三方"},{type:"command",command:$cmd,timeout:10,statusMessage:"我的交接"}]}]}}' > "$NH/.codex/hooks.json"
  nbefore="$(jq -S . "$NH/.codex/hooks.json")"
  HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1; nfirst="$(jq -S . "$NH/.codex/hooks.json")"
  HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$nbefore" == "$nfirst" && "$nfirst" == "$(jq -S . "$NH/.codex/hooks.json")" && "$(cat "$NH/.codex/config.toml")" == "keep = true" ]]; check "keeps a custom handoff name and a third-party Stop hook unchanged across two runs without touching trust"
  rm -rf "$NH"; mkdir -p "$NH/.codex"
  jq -n --arg cmd "$ncmd" '{hooks:{Stop:[{matcher:"",note:"keep",hooks:[{type:"command",command:"other-stop"},{type:"command",command:$cmd,timeout:10,extra:"keep"}]}]}}' > "$NH/.codex/hooks.json"
  nbefore="$(jq -S . "$NH/.codex/hooks.json")"
  HOME="$NH" bash "$ROOT/scripts/handoff/install.sh" >/dev/null 2>&1
  [[ "$(hname_of "$NH/.codex/hooks.json" "$ncmd")" == "$hname" && "$(hname_of "$NH/.codex/hooks.json" other-stop)" == "" \
    && "$(jq -S 'walk(if type == "object" then del(.statusMessage) else . end)' "$NH/.codex/hooks.json")" == "$nbefore" ]]; check "naming an existing handoff hook changes only its statusMessage"

  readme="$ROOT/scripts/handoff/README.md"
  missing=""
  for opt in $( { "$START" --help; "$FINISH" --help; "$ROOT/scripts/handoff/handoff-cleanup" --help; "$ROOT/scripts/handoff/handoff-role" --help; } 2>/dev/null | grep -oE -- '--[a-z][a-z-]+' | sort -u); do
    grep -q -- "$opt" "$readme" 2>/dev/null || missing="$missing $opt"
  done
  [[ -f "$readme" && -z "$missing" ]] && grep -q 'handoff-finish' "$readme" && grep -q 'handoff-role' "$readme" && grep -q 'roles.yaml' "$readme"; check "README documents every command option" || printf '       %s\n' "(missing:$missing)"
  grep -q '^## Session hosts' "$readme" && grep -q 'host: herdr' "$readme" && grep -q 'herdr_session' "$readme" && grep -q 'ghostty + tmux' "$readme" \
    && grep -q '^# host: herdr' "$SKILL/roles.example.yaml" && grep -q '^# herdr_session:' "$SKILL/roles.example.yaml"; check "README and roles.example.yaml document host, herdr_session and the possible ghostty + tmux host"
  grep -q '^### herdr-app' "$readme" && grep -q 'host: herdr-app' "$readme" && grep -q 'herdr-app do space.new' "$readme" && grep -q 'Herdr app' "$ROOT/docs/skills/agent-handoff.md" \
    && grep -q '^# Session host: .*xirp (default), herdr or herdr-app' "$SKILL/roles.example.yaml"; check "README, the skill guide and roles.example.yaml document the herdr-app host"
  grep -qF -- '--replace' "$readme" && grep -qF -- '--worktree new' "$readme" && grep -qF -- '--replace' "$ROOT/docs/skills/agent-handoff.md" && grep -qF -- '--worktree new' "$ROOT/docs/skills/agent-handoff.md"; check "README and the skill guide document handoff-role --replace and --worktree new"
  grep -q 'HERDR_ENV' "$SKILL/SKILL.md"; check "SKILL.md explains XIRP-SESSION-ID inside a herdr pane"

finish_section hookinstall
