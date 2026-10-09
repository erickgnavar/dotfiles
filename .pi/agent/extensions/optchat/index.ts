/**
 * OptChat for pi: one endless chat per project, where the chat history
 * itself is the memory, stored as a compressed tree of one-line
 * summaries.
 *
 * How it maps onto pi:
 * - Every message (user prompt, reply, tool call, tool result) is logged
 *   verbatim to <cwd>/.pi/optchat/ (OPTCHAT_DIR overrides), append-only,
 *   fsync per line, one writer per log (Unix-socket lock).
 * - A background compactor (the session model, OPTCHAT_MODEL overrides) folds
 *   the log into a binary tree of ≤512-byte one-line summaries; short
 *   messages are their own line.
 * - Each turn starts fresh: the `context` handler replaces everything
 *   before the current turn with the view (~128 KB of summaries; the
 *   older the messages, the coarser the lines), and the model navigates
 *   it with the `zoom` and `date` tools.
 * - Before each turn, the harness waits (up to 2 minutes) until every
 *   line of the view is a real summary, so no call ever sees cut text.
 *
 * Commands: /optchat (status), /optchat view, /optchat note <text>.
 * Set OPTCHAT_DISABLE=1 to turn the memory off for one run.
 */

import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { Type } from "@earendil-works/pi-ai";
import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type {
  ImageContent,
  Model,
  TextContent,
  UserMessage,
} from "@earendil-works/pi-ai";
import {
  defineTool,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { CAP, errorText, OptChat } from "./memory.ts";
import { acquireLock, type Lock, saveImage } from "./store.ts";
import { VIEW_DOC } from "./prompts.ts";

/** Safety cap: never block a turn longer than this waiting for the compactor. */
const SETTLE_TIMEOUT_MS = 120_000;

export default function optchat(pi: ExtensionAPI) {
  let chat: OptChat | null = null;
  let lock: Lock | null = null;
  let active = false;
  let turnActive = false;
  // The view of the current turn, frozen before its first message is
  // logged (§7): requests of the turn send it unchanged, so it caches.
  let viewFrozen: string | null = null;
  let pendingPrompt: string | null = null;
  let sawUserMessageEnd = false;
  let anchorIdx: number | null = null;
  let anchorTs: number | undefined;
  // Provider-reported prompt tokens, including cache reads/writes, this run only.
  let chatTokens = 0;
  let chatCacheRead = 0;
  let compactorTokens = 0;
  let compactorCacheRead = 0;

  // ------------------------------------------------------------ lifecycle

  pi.on("session_start", async (_event, ctx) => {
    cleanup(); // idempotent: reloads and session switches re-run this
    if (process.env.OPTCHAT_DISABLE) {
      ctx.ui.notify("OptChat disabled (OPTCHAT_DISABLE).", "info");
      return;
    }
    const dir = process.env.OPTCHAT_DIR ?? path.join(ctx.cwd, ".pi", "optchat");
    try {
      fs.mkdirSync(path.join(dir, "main"), { recursive: true });
      fs.mkdirSync(path.join(dir, "tree"), { recursive: true });
      lock = await acquireLock(lockPathFor(dir));
    } catch (err) {
      ctx.ui.notify(`OptChat disabled: ${errorText(err)}`, "error");
      return;
    }
    const compactor = resolveCompactor(ctx);
    if (!compactor) {
      ctx.ui.notify(
        "OptChat disabled: no compactor model. Set OPTCHAT_MODEL=provider/model.",
        "error",
      );
      lock.close();
      lock = null;
      return;
    }
    chat = new OptChat(dir, compactor, {
      // Low reasoning: the compactor otherwise thinks for pages before (or
      // instead of) writing its one line; 8192 tokens of headroom for models
      // that ignore the reasoning level.
      complete: async (model, context, signal) => {
        const reply = await ctx.modelRegistry
          .streamSimple(model, context, {
            maxTokens: 8192,
            reasoning: "low",
            sessionId: "optchat-compactor",
            signal,
          })
          .result();
        if (!signal.aborted) {
          compactorCacheRead += reply.usage.cacheRead ?? 0;
          compactorTokens +=
            (reply.usage.input ?? 0) +
            (reply.usage.cacheRead ?? 0) +
            (reply.usage.cacheWrite ?? 0);
        }
        return reply;
      },
      onError: (message) => ctx.ui.notify(message, "error"),
    });
    try {
      chat.load();
      active = true;
      chat.pump();
    } catch (err) {
      cleanup();
      ctx.ui.notify(`OptChat disabled: ${errorText(err)}`, "error");
    }
  });

  pi.on("session_shutdown", () => cleanup());

  function cleanup(): void {
    active = false;
    turnActive = false;
    viewFrozen = null;
    pendingPrompt = null;
    anchorIdx = null;
    anchorTs = undefined;
    chatTokens = chatCacheRead = compactorTokens = compactorCacheRead = 0;
    chat?.close();
    chat = null;
    lock?.close();
    lock = null;
  }

  // ----------------------------------------------------------------- turns

  pi.on("before_agent_start", async (event, ctx) => {
    if (!active || !chat) return;
    // §6: no call ever sees an unbuilt line; wait for the compactor.
    // (Never forever: a stuck or paused compactor must not brick pi.)
    const memory = chat;
    const settleAbort = new AbortController();
    const onAbort = () => settleAbort.abort();
    ctx.signal?.addEventListener("abort", onAbort, { once: true });
    if (ctx.signal?.aborted) settleAbort.abort();
    const settleTimer = setTimeout(onAbort, SETTLE_TIMEOUT_MS);
    let settled: boolean;
    try {
      settled = await memory.settle(settleAbort.signal);
    } finally {
      clearTimeout(settleTimer);
      ctx.signal?.removeEventListener("abort", onAbort);
    }
    if (chat !== memory || !active) return;
    if (!settled && !chat.allBuilt()) {
      ctx.ui.notify(
        chat.isPaused()
          ? "OptChat: compaction paused; keeping pi's transcript. Use /optchat resume."
          : "OptChat: summaries not ready; keeping pi's transcript for this turn.",
        "warning",
      );
    }
    // The view is rendered before the new message is logged (§7).
    viewFrozen = settled ? chat.renderView() : null;
    turnActive = true;
    pendingPrompt = event.prompt;
    sawUserMessageEnd = false;
    anchorIdx = null;
    anchorTs = undefined;
    // The section must stay byte-identical across turns (§7.2, §8).
    event.systemPromptOptions.sections.optchat = VIEW_DOC;
  });

  pi.on("context", (event) => {
    if (!active || !chat || chat.root.length === 0) return;
    const viewText = viewFrozen;
    if (!viewText) return; // never show cut text for unbuilt lines (§5.3)
    // The user prompt never arrived as a message event (fail-safe): log
    // it now, after the view was frozen, so nothing is missing from the log.
    if (turnActive && pendingPrompt !== null && !sawUserMessageEnd) {
      chat.logText("user", pendingPrompt);
      pendingPrompt = null;
    }
    const idx = findAnchor(event.messages);
    if (idx < 0) return;
    const viewMessage: UserMessage = {
      role: "user",
      content: [{ type: "text", text: viewText }],
      timestamp: 0,
    };
    return { messages: [viewMessage, ...event.messages.slice(idx)] };
  });

  /**
   * Index of the user message that starts the current turn: the prompt
   * pi recorded after before_agent_start. Everything before it is
   * replaced by the view; the turn's own messages (replies, tool calls,
   * mid-run user messages) are sent verbatim after it.
   */
  function findAnchor(messages: AgentMessage[]): number {
    const lastUser = () => {
      for (let j = messages.length - 1; j >= 0; j--) {
        if (messages[j].role === "user") return j;
      }
      return -1;
    };
    if (anchorIdx === null) {
      if (!turnActive) return -1; // no turn boundary was captured to reuse
      let idx = messages.length - 1;
      if (messages[idx]?.role !== "user") idx = lastUser();
      if (idx < 0) return -1;
      anchorIdx = idx;
      anchorTs = (messages[idx] as UserMessage).timestamp;
      return idx;
    }
    const m = messages[anchorIdx];
    if (m && m.role === "user" && (m as UserMessage).timestamp === anchorTs)
      return anchorIdx;
    // The transcript moved under us (compaction, an edit): find the anchor again.
    for (let j = messages.length - 1; j >= 0; j--) {
      const mm = messages[j];
      if (mm.role === "user" && (mm as UserMessage).timestamp === anchorTs) {
        anchorIdx = j;
        return j;
      }
    }
    if (!turnActive) return -1; // never move an idle request to a different turn
    const idx = lastUser();
    anchorIdx = idx >= 0 ? idx : null;
    if (idx >= 0) anchorTs = (messages[idx] as UserMessage).timestamp;
    return idx;
  }

  pi.on("agent_end", () => {
    turnActive = false;
    pendingPrompt = null;
    // The frozen view and its anchor stay for idle requests until the next turn.
  });

  // ------------------------------------------------------------------ log

  pi.on("message_end", (event) => {
    if (!active || !chat) return;
    const m = event.message;
    if (m.role === "user") {
      sawUserMessageEnd = true;
      // Only the user's words are theirs; long text is never cut, and
      // attached images are saved as files, never dropped (§1).
      chat.logText("user", flattenContent(m.content));
      logImages(m.content);
    } else if (m.role === "bashExecution") {
      // The command is the user's words; the output is a tool result.
      const status = m.cancelled
        ? " (cancelled)"
        : m.exitCode !== undefined
          ? ` (exit ${m.exitCode})`
          : "";
      chat.logText("user", `$ ${m.command}${status}`);
      chat.log("echo", capText(m.output || "(no output)"));
    } else if (m.role === "custom") {
      // Another extension's message: context from outside this chat.
      chat.logText("note", `[${m.customType}] ${flattenContent(m.content)}`);
      logImages(m.content);
    } else if (m.role === "assistant") {
      chatCacheRead += m.usage.cacheRead ?? 0;
      chatTokens +=
        (m.usage.input ?? 0) +
        (m.usage.cacheRead ?? 0) +
        (m.usage.cacheWrite ?? 0);
      // Thoughts are never logged (§2); the reply is the record.
      const text = m.content
        .filter((c): c is TextContent => c.type === "text")
        .map((c) => c.text)
        .join("\n");
      if (text.trim().length > 0) chat.logText("talk", text);
    }
    // toolResult messages are logged by tool_execution_end, capped.
  });

  pi.on("tool_execution_start", (event) => {
    if (!active || !chat) return;
    // Tool inputs are never cut either (§1): long ones split in a row.
    chat.logText("tool", `${event.toolName} ${safeJson(event.args)}`);
  });

  pi.on("tool_execution_end", (event) => {
    if (!active || !chat) return;
    chat.log("echo", echoText(event.result, event.isError));
    logImages(event.result.content);
  });

  function logImages(content: string | (TextContent | ImageContent)[]): void {
    if (!chat || typeof content === "string") return;
    let seq = 0;
    for (const c of content) {
      if (c.type !== "image") continue;
      const rel = saveImage(
        chat.dir,
        chat.root.length,
        seq++,
        c.data,
        c.mimeType,
      );
      chat.log(
        "note",
        `image attached: ${path.resolve(chat.dir, rel)} (${c.mimeType})`,
      );
    }
  }

  // ----------------------------------------------------------------- tools

  const zoomTool = defineTool({
    name: "zoom",
    label: "Zoom",
    description:
      "Open the line id+n of the view into the two lines of n/2 under it; n = 1 gives the message whole.",
    parameters: Type.Object({
      id: Type.Integer({
        description: "Id of the line: the first message it covers.",
      }),
      n: Type.Integer({
        description:
          "How many messages the line covers: a power of 2 (1, 2, 4, ...).",
      }),
    }),
    async execute(_toolCallId, params) {
      const text = chat
        ? chat.zoom(params.id, params.n)
        : "OptChat is not active.";
      return { content: [{ type: "text", text }], details: undefined };
    },
  });

  const dateTool = defineTool({
    name: "date",
    label: "Date",
    description: "The date and time of message id.",
    parameters: Type.Object({
      id: Type.Integer({ description: "Message id." }),
    }),
    async execute(_toolCallId, params) {
      const text = chat ? chat.date(params.id) : "OptChat is not active.";
      return { content: [{ type: "text", text }], details: undefined };
    },
  });

  pi.registerTool(zoomTool);
  pi.registerTool(dateTool);

  // -------------------------------------------------------------- commands

  pi.registerCommand("optchat", {
    description:
      "OptChat memory: status (default), view, note <text>, resume (after a paused compaction)",
    handler: async (args, ctx) => {
      if (!chat) {
        ctx.ui.notify("OptChat is not active.", "warning");
        return;
      }
      const trimmed = args.trim();
      const space = trimmed.indexOf(" ");
      const cmd = space < 0 ? trimmed : trimmed.slice(0, space);
      const rest = space < 0 ? "" : trimmed.slice(space + 1).trim();
      if (cmd === "view") {
        const file = path.join(chat.dir, "view.txt");
        fs.writeFileSync(file, `${chat.renderView()}\n`);
        ctx.ui.notify(
          `View (${chat.viewByteCount()} bytes) written to ${file}`,
          "info",
        );
      } else if (cmd === "note" && rest) {
        const i = chat.logText("note", rest);
        ctx.ui.notify(`Saved as message ${i}.`, "info");
      } else if (cmd === "resume") {
        if (chat.isPaused()) {
          chat.resume();
          ctx.ui.notify("OptChat compactor resumed.", "info");
        } else {
          ctx.ui.notify("The compactor is not paused.", "info");
        }
      } else {
        const s = chat.stats();
        ctx.ui.notify(
          `OptChat: ${s.messages} messages, ${s.nodes} nodes, view ${s.viewBytes}B ` +
            `in ${s.parts} lines (${s.unbuilt} unbuilt${s.paused ? ", compaction PAUSED" : ""}), ` +
            `compactor ${s.compactor}, log ${chat.dir}. ` +
            `Cache-read tokens this run: chat ${chatCacheRead}/${chatTokens}, ` +
            `compactor ${compactorCacheRead}/${compactorTokens}.`,
          "info",
        );
      }
    },
  });
}

// ----------------------------------------------------------------- helpers

/** Use the session's model unless OPTCHAT_MODEL explicitly selects "provider/model". */
function resolveCompactor(ctx: ExtensionContext): Model<any> | undefined {
  const pref = process.env.OPTCHAT_MODEL;
  if (!pref) return ctx.model;
  const slash = pref.indexOf("/");
  if (slash <= 0) return undefined;
  return ctx.modelRegistry.find(pref.slice(0, slash), pref.slice(slash + 1));
}

/** The lock socket of a log; hashed into /tmp when the path is too long for one. */
function lockPathFor(dir: string): string {
  const p = path.join(dir, "lock");
  if (p.length <= 100) return p;
  const h = createHash("sha256").update(p).digest("hex").slice(0, 16);
  return path.join(os.tmpdir(), `optchat-lock-${h}`);
}

function flattenContent(
  content: string | (TextContent | ImageContent)[],
): string {
  if (typeof content === "string") return content;
  const parts: string[] = [];
  let images = 0;
  for (const c of content) {
    if (c.type === "text") parts.push(c.text);
    else images++;
  }
  if (images > 0)
    parts.push(`(${images} image${images === 1 ? "" : "s"} attached)`);
  return parts.join("\n");
}

function safeJson(v: unknown): string {
  try {
    return JSON.stringify(v ?? {});
  } catch {
    return String(v);
  }
}

/** Tool results are capped at CAP characters, head and tail kept (§7). */
function capText(s: string): string {
  if (s.length <= CAP) return s;
  const head = Math.floor(CAP * 0.7);
  const tail = CAP - head;
  return `${s.slice(0, head)}\n[... ${s.length - CAP} characters cut ...]\n${s.slice(-tail)}`;
}

function echoText(result: unknown, isError: boolean): string {
  const texts: string[] = [];
  const r = result as
    | { content?: unknown; structuredContent?: unknown; isError?: boolean }
    | null
    | undefined;
  if (r && Array.isArray(r.content)) {
    for (const c of r.content) {
      if (
        c &&
        typeof c === "object" &&
        (c as { type?: string }).type === "text"
      ) {
        const t = (c as { text?: unknown }).text;
        if (typeof t === "string") texts.push(t);
      }
    }
  }
  if (
    texts.length === 0 &&
    r &&
    r.structuredContent !== undefined &&
    r.structuredContent !== null
  ) {
    texts.push(safeJson(r.structuredContent));
  }
  let text = texts.join("\n");
  if (!text) text = "(no output)";
  if (isError || r?.isError === true) text = `error: ${text}`;
  return capText(text);
}
