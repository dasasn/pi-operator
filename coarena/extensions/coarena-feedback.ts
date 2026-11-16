/**
 * Coarena Model API feedback integration.
 *
 * Captures the `x-coarena-request-id` of every Coarena reply, then lets you rate it:
 *   Ctrl+Alt+U  rate the last Coarena reply up   (POST rating:"up")
 *   Ctrl+Alt+D  rate the last Coarena reply down (POST rating:"down")
 *   /coarena-rate <up|down|none> [note...]       same, from a slash command
 *   /coarena-last                                show the pending request id
 *   /coarena-models                              list models from GET /api/v1/models
 *
 * Endpoint: https://coarena.ai/api/v1/feedback
 * Auth:     Authorization: Bearer $COARENA_API_KEY (or `!cmd`/literal via env override below)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER = "coarena";
const API_BASE = process.env.COARENA_BASE_URL ?? "https://coarena.ai/api/v1";

type Pending = {
  requestId: string;
  responseId?: string;
  model: string;
  at: number;
  rating?: "up" | "down" | null;
};

function apiKey(): string {
  const key = process.env.COARENA_API_KEY;
  if (!key) throw new Error("COARENA_API_KEY is not set");
  return key;
}

async function postFeedback(requestId: string, rating: "up" | "down" | null, note?: string, tags?: string[]) {
  const body: Record<string, unknown> = { request_id: requestId, rating };
  if (note) body.note = note;
  if (tags?.length) body.tags = tags;
  const res = await fetch(`${API_BASE}/feedback`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey()}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 300)}`);
  return text;
}

export default function (pi: ExtensionAPI) {
  // Last request seen on the wire, keyed by nothing: the newest one is the one to rate.
  let last: Pending | undefined;

  pi.on("after_provider_response", (event, ctx) => {
    if (ctx.model?.provider !== PROVIDER) return;
    const headers = event.headers ?? {};
    const requestId =
      headers["x-coarena-request-id"] ?? headers["x-request-id"] ?? headers["request-id"];
    if (!requestId) return;
    last = {
      requestId,
      model: String(ctx.model?.id ?? "?"),
      at: Date.now(),
    };
  });

  pi.on("message_end", (event, ctx) => {
    if (ctx.model?.provider !== PROVIDER) return;
    const msg = event.message as any;
    if (msg?.role !== "assistant") return;
    if (last) {
      last.responseId = msg.id ? String(msg.id) : undefined;
      // Some streams only expose the id in the body: chatcmpl-<request-id>
      if (!last.responseId && typeof msg.responseId === "string") last.responseId = msg.responseId;
      if (last.responseId?.startsWith("chatcmpl-")) {
        const derived = last.responseId.slice("chatcmpl-".length);
        if (derived.startsWith("req_")) last.requestId = derived;
      }
    }
  });

  async function rate(rating: "up" | "down" | null, note: string | undefined, ctx: any) {
    if (!last) {
      ctx.ui.notify("Coarena: no reply to rate yet in this session", "warn");
      return;
    }
    try {
      const raw = await postFeedback(last.requestId, rating, note);
      last.rating = rating;
      const label = rating === "up" ? "👍 up" : rating === "down" ? "👎 down" : "cleared";
      ctx.ui.notify(`Coarena feedback (${label}) ${last.requestId} ${raw}`, "info");
    } catch (err) {
      ctx.ui.notify(`Coarena feedback failed: ${(err as Error).message}`, "error");
    }
  }

  pi.registerShortcut("ctrl+alt+u", {
    description: "Coarena: rate last reply up",
    handler: async (ctx) => rate("up", undefined, ctx),
  });

  pi.registerShortcut("ctrl+alt+d", {
    description: "Coarena: rate last reply down",
    handler: async (ctx) => rate("down", undefined, ctx),
  });

  pi.registerCommand("coarena-rate", {
    description: "Rate the last Coarena reply: /coarena-rate <up|down|none> [note...]",
    handler: async (args, ctx) => {
      const [head, ...rest] = (args ?? "").trim().split(/\s+/);
      const word = (head ?? "").toLowerCase();
      const note = rest.join(" ").trim() || undefined;
      if (!word) {
        ctx.ui.notify('usage: /coarena-rate <up|down|none> [note...]', "warn");
        return;
      }
      if (word === "up" || word === "good" || word === "1" || word === "true") return rate("up", note, ctx);
      if (word === "down" || word === "bad" || word === "-1" || word === "false") return rate("down", note, ctx);
      if (word === "none" || word === "clear" || word === "null") return rate(null, note, ctx);
      // Treat a bare word as a note on an up-rating.
      return rate("up", (args ?? "").trim(), ctx);
    },
  });

  pi.registerCommand("coarena-last", {
    description: "Show the Coarena request id pending for feedback",
    handler: async (_args, ctx) => {
      if (!last) {
        ctx.ui.notify("Coarena: nothing pending", "info");
        return;
      }
      ctx.ui.notify(
        `Coarena pending → request_id=${last.requestId} model=${last.model} rating=${last.rating ?? "not rated"}`,
        "info",
      );
    },
  });

  pi.registerCommand("coarena-models", {
    description: "List models offered by the Coarena Model API",
    handler: async (_args, ctx) => {
      try {
        const res = await fetch(`${API_BASE}/models`, {
          headers: { Authorization: `Bearer ${apiKey()}`, Accept: "application/json" },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json: any = await res.json();
        const lines = (json.data ?? []).map(
          (m: any) => `${m.id}  [${m.owned_by}]  ctx=${m.context_length}  tools=${m.capabilities?.tools ?? false}`,
        );
        ctx.ui.notify(`Coarena models (${lines.length}):\n${lines.join("\n")}`, "info");
      } catch (err) {
        ctx.ui.notify(`Coarena models failed: ${(err as Error).message}`, "error");
      }
    },
  });

  pi.on("session_shutdown", () => {
    last = undefined;
  });
}
