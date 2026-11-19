// Pi trigger for the wk-agent-ops agent handoff loop.
// Installed by scripts/handoff/install.sh as ~/.pi/agent/extensions/wk-handoff.ts.
// - agent_settled: when a main session will not continue on its own, run handoff-route
//   (the same hook Claude Code and Codex call on Stop). Subagents are skipped.
// - project_trust: trust a handoff worktree for this process only when handoff-pi-trust says so;
//   otherwise leave the decision to Pi. Nothing is saved.
// All rules live in the shell scripts; every failure is swallowed so Pi is never affected.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";

const HANDOFF_DIR = join(homedir(), ".config", "wk-workflow", "handoff");

export default function (pi: ExtensionAPI) {
  pi.on("project_trust", async (event) => {
    try {
      const result = await pi.exec("bash", [join(HANDOFF_DIR, "handoff-pi-trust"), event.cwd], { timeout: 10000 });
      if (result.code === 0) return { trusted: "yes" };
    } catch {
      // fall through to Pi's own trust flow
    }
    return { trusted: "undecided" };
  });

  pi.on("agent_settled", async (_event, ctx) => {
    if (process.env.PI_SUBAGENT_PARENT_SESSION) return;
    try {
      const payload = JSON.stringify({
        hook_event_name: "Stop",
        cwd: ctx.cwd,
        session_id: ctx.sessionManager.getSessionId(),
      });
      // handoff-route reads the payload on stdin, routes in the background, and always exits 0.
      await pi.exec("bash", ["-c", 'printf "%s" "$1" | bash "$2"', "wk-handoff", payload, join(HANDOFF_DIR, "handoff-route")], {
        timeout: 10000,
      });
    } catch {
      // routing failures never reach the Pi session
    }
  });
}
