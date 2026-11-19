// managed by wk-agent-ops ai-notify
// Telegram notifications for Pi. Installed by the wk-agent-ops notification installer
// (scripts/notify/lib/registry.sh) as ~/.pi/agent/extensions/ai-notify.ts; edit the source, not the copy.
// - agent_settled: one pi-stop event with stop_reason completed, error, or aborted.
// - ui_prompt_start during a run: one pi-question event.
// Only interactive main sessions notify. The payload carries only the session ID, cwd, the
// stop_reason computed here, and the model ID; prompt and error contents never leave Pi.
// The shared hook runs detached and every failure is swallowed, so Pi is never affected.
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const HOOK = join(homedir(), ".config", "ai-notify", "hooks", "telegram-notify.sh");

function interactiveMain(ctx: ExtensionContext): boolean {
  return ctx.hasUI && !process.env.PI_SUBAGENT_PARENT_SESSION;
}

function notify(event: string, hookEventName: string, ctx: ExtensionContext, stopReason?: string): void {
  try {
    if (!existsSync(HOOK)) return;
    const payload: Record<string, string> = {
      hook_event_name: hookEventName,
      session_id: ctx.sessionManager.getSessionId(),
      cwd: ctx.cwd,
    };
    if (stopReason) payload.stop_reason = stopReason;
    const model = ctx.model?.id;
    if (typeof model === "string" && model) payload.model = model;
    const child = spawn("bash", [HOOK, event, "Pi"], { detached: true, stdio: ["pipe", "ignore", "ignore"] });
    child.on("error", () => {});
    child.stdin?.on("error", () => {});
    child.stdin?.end(JSON.stringify(payload));
    child.unref();
  } catch {
    // notification failures never reach the Pi session
  }
}

export default function (pi: ExtensionAPI) {
  let running = false;
  let lastStop: string | undefined;

  pi.on("agent_start", async () => {
    running = true;
  });

  // Retries start another run; only the last run's final assistant message counts.
  pi.on("agent_end", async (event) => {
    const last = [...event.messages].reverse().find((m) => m.role === "assistant");
    if (last && "stopReason" in last) lastStop = String(last.stopReason);
  });

  pi.on("agent_settled", async (event, ctx) => {
    const stop = lastStop;
    running = false;
    lastStop = undefined;
    if (!interactiveMain(ctx)) return;
    const reason = event.aborted || stop === "aborted" ? "aborted" : stop === "error" ? "error" : "completed";
    notify("pi-stop", "Stop", ctx, reason);
  });

  // Pi merges overlapping prompts into one span; a prompt opened while idle has the user at the screen.
  pi.on("ui_prompt_start", async (_event, ctx) => {
    if (running && interactiveMain(ctx)) notify("pi-question", "UserInputWaiting", ctx);
  });
}
