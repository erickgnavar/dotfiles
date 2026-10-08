/**
 * The OptChat memory (§3-§6 of optchat.md): an append-only log of every
 * message, a binary tree of one-line summaries over it, and the
 * fixed-budget view folded from both. The compactor ("pump") builds tree
 * nodes with a cheap model, one node per call, in a strict order.
 */

import * as path from "node:path";
import {
  appendLine,
  byteLength,
  loadJsonl,
  localDay,
  type LogMessage,
  type TreeNode,
} from "./store.ts";
import {
  COMPACT,
  compressStep,
  mergeStep,
  NODE,
  overLimitFeedback,
} from "./prompts.ts";
import type {
  AssistantMessage,
  Context,
  Message,
  Model,
  TextContent,
} from "@earendil-works/pi-ai";

export const VIEW = 128_000; // view budget in bytes (≈ 62-64k tokens)
export const JOBS = 8; // compactor calls running at once
export const TRIES = 5; // attempts per node to get under NODE
export const RETRY_MS = 10_000; // wait before retrying a failed node
export const CAP = 30_000; // max characters of one tool result (head + tail kept)
const PLACEHOLDER = "(not summarized yet: zoom it)";

/** One tile of the view: tree node (l, i), covering [start, start + n). */
export interface Part {
  l: number;
  i: number;
  start: number;
  n: number;
}

export interface CompactorHooks {
  complete(
    model: Model<any>,
    context: Context,
    signal: AbortSignal,
  ): Promise<AssistantMessage>;
  onError(message: string): void;
}

export interface MemoryStats {
  messages: number;
  nodes: number;
  parts: number;
  viewBytes: number;
  unbuilt: number;
  compactor: string;
}

const nodeKey = (l: number, i: number) => `${l}:${i}`;

function assistantText(m: AssistantMessage): string {
  return m.content
    .filter((c): c is TextContent => c.type === "text")
    .map((c) => c.text)
    .join("\n");
}

export function errorText(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export class OptChat {
  readonly dir: string;
  root: LogMessage[] = [];
  nodes = new Map<string, TreeNode>();
  view: Part[] = [];
  private readonly compactor: Model<any> | undefined;
  private readonly hooks: CompactorHooks;
  private readonly abort = new AbortController();
  private readonly busy = new Set<string>();
  private readonly retryAt = new Map<string, number>();
  private readonly reported = new Set<string>();
  private waiters: Array<(ok: boolean) => void> = [];
  private closed = false;
  private pumpQueued = false;

  constructor(
    dir: string,
    compactor: Model<any> | undefined,
    hooks: CompactorHooks,
  ) {
    this.dir = dir;
    this.compactor = compactor;
    this.hooks = hooks;
  }

  // ------------------------------------------------------------------ load

  load(): void {
    const main = loadJsonl(path.join(this.dir, "main"));
    const tree = loadJsonl(path.join(this.dir, "tree"));
    let torn = main.torn + tree.torn;
    const loaded: LogMessage[] = [];
    for (const raw of main.lines) {
      const m = raw as Partial<LogMessage>;
      if (
        typeof m?.i !== "number" ||
        typeof m?.kind !== "string" ||
        typeof m?.text !== "string"
      ) {
        torn++;
        continue;
      }
      loaded.push({
        i: m.i,
        kind: m.kind as LogMessage["kind"],
        text: m.text,
        size: m.size ?? byteLength(`${m.kind}: ${m.text}`),
        date: m.date ?? "",
      });
    }
    // A crash can tear a message away: keep the ids aligned with hole
    // markers, so the tree's ranges stay true.
    for (const m of loaded) {
      while (this.root.length < m.i) {
        this.root.push({
          i: this.root.length,
          kind: "note",
          text: "(this message was lost to a crash)",
          size: 0,
          date: "",
        });
        torn++;
      }
      if (m.i < this.root.length) {
        torn++; // duplicate id: keep the first
        continue;
      }
      this.root.push(m);
    }
    for (const raw of tree.lines) {
      const n = raw as Partial<TreeNode>;
      if (
        typeof n?.l !== "number" ||
        typeof n?.i !== "number" ||
        typeof n?.text !== "string"
      )
        continue;
      this.nodes.set(nodeKey(n.l, n.i), {
        l: n.l,
        i: n.i,
        text: n.text,
        size: n.size ?? byteLength(n.text),
      });
    }
    // The view is not saved: fold it again from message 0, the same
    // append + fit as live (§5.2).
    for (let i = 0; i < this.root.length; i++) {
      this.view.push({ l: 0, i, start: i, n: 1 });
      this.fit();
    }
    if (torn > 0)
      this.hooks.onError(
        `OptChat: skipped ${torn} torn lines while loading the log`,
      );
  }

  // ------------------------------------------------------------------- log

  /** Append one message to the log, tile it into the view, and pump. */
  log(kind: LogMessage["kind"], text: string): number {
    const i = this.root.length;
    const msg: LogMessage = {
      i,
      kind,
      text,
      size: byteLength(`${kind}: ${text}`),
      date: new Date().toISOString(),
    };
    this.root.push(msg);
    appendLine(this.dayFile("main"), JSON.stringify(msg));
    this.view.push({ l: 0, i, start: i, n: 1 });
    this.fit();
    this.schedulePump();
    return i;
  }

  private dayFile(sub: "main" | "tree"): string {
    return path.join(this.dir, sub, `${localDay()}.jsonl`);
  }

  // ------------------------------------------------------------------ view

  allBuilt(): boolean {
    for (const p of this.view) {
      if (!this.nodes.has(nodeKey(p.l, p.i))) return false;
    }
    return true;
  }

  viewByteCount(): number {
    let size = 0;
    for (const p of this.view) {
      size += byteLength(
        this.nodes.get(nodeKey(p.l, p.i))?.text ?? PLACEHOLDER,
      );
    }
    return size;
  }

  /** §5.1: one line per part, oldest first, newlines shown as spaces. */
  renderView(): string {
    const lines = this.view.map((p) => {
      const text = this.nodes.get(nodeKey(p.l, p.i))?.text ?? PLACEHOLDER;
      return `${p.start}+${p.n}|${text.replace(/\n/g, " ")}`;
    });
    return `<chat>\n${lines.join("\n")}\n</chat>`;
  }

  /**
   * Keep the view under budget: merge the most due adjacent sibling pair
   * whose parent is built (§5.2). Never split: parts only coarsen.
   */
  fit(): void {
    const T = this.root.length;
    let size = this.viewByteCount();
    while (size > VIEW) {
      let best = -1;
      let bestDue = -1;
      for (let p = 0; p + 1 < this.view.length; p++) {
        const a = this.view[p];
        const b = this.view[p + 1];
        if (a.l !== b.l || a.i % 2 !== 0 || b.i !== a.i + 1) continue;
        if (!this.nodes.has(nodeKey(a.l + 1, a.i / 2))) continue;
        const due = (T - a.start) / Math.pow(2, a.l + 2);
        if (due > bestDue) {
          bestDue = due;
          best = p;
        }
      }
      if (best < 0) break; // stay over budget until a parent is built
      const a = this.view[best];
      this.view.splice(best, 2, {
        l: a.l + 1,
        i: a.i / 2,
        start: a.start,
        n: a.n * 2,
      });
      size = this.viewByteCount();
    }
    this.wake();
  }

  // ------------------------------------------------------------- settle

  /** §6: resolve true when every line of the view is a summary. */
  settle(signal?: AbortSignal): Promise<boolean> {
    if (this.closed) return Promise.resolve(false);
    if (this.allBuilt()) return Promise.resolve(true);
    return new Promise<boolean>((resolve) => {
      let done = false;
      const finish = (ok: boolean) => {
        if (done) return;
        done = true;
        signal?.removeEventListener("abort", onAbort);
        const ix = this.waiters.indexOf(waiter);
        if (ix >= 0) this.waiters.splice(ix, 1);
        resolve(ok);
      };
      const waiter = (ok: boolean) => finish(ok);
      const onAbort = () => finish(false);
      signal?.addEventListener("abort", onAbort, { once: true });
      this.waiters.push(waiter);
    });
  }

  private wake(): void {
    if (this.waiters.length === 0 || !this.allBuilt()) return;
    const waiters = this.waiters.splice(0);
    for (const w of waiters) w(true);
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    this.abort.abort();
    const waiters = this.waiters.splice(0);
    for (const w of waiters) w(false);
  }

  // ------------------------------------------------------------- compactor

  /** First message whose view line is unbuilt (§4.1, `first`). */
  firstUnbuilt(): number {
    for (const p of this.view) {
      if (!this.nodes.has(nodeKey(p.l, p.i))) return p.start;
    }
    return this.root.length;
  }

  /**
   * Launch every node whose turn it is, up to JOBS at once (§4.1,
   * `pump`): not built, not running, sources ready, and its whole
   * context summarized (end ≤ firstUnbuilt).
   */
  pump(): void {
    if (this.closed) return;
    const T = this.root.length;
    if (T === 0) return;
    const first = this.firstUnbuilt();
    const now = Date.now();
    let slots = JOBS - this.busy.size;
    if (slots <= 0) return;
    for (let l = 0; Math.pow(2, l) <= T && slots > 0; l++) {
      const width = Math.pow(2, l);
      for (let i = 0; (i + 1) * width <= T && slots > 0; i++) {
        const k = nodeKey(l, i);
        if (this.nodes.has(k) || this.busy.has(k)) continue;
        const end = l === 0 ? i : (i + 1) * width;
        if (end > first) continue;
        const at = this.retryAt.get(k);
        if (at !== undefined && now < at) continue;
        if (
          l > 0 &&
          !(
            this.nodes.has(nodeKey(l - 1, 2 * i)) &&
            this.nodes.has(nodeKey(l - 1, 2 * i + 1))
          )
        ) {
          continue;
        }
        this.busy.add(k);
        slots--;
        void this.buildNode(l, i);
      }
    }
  }

  private schedulePump(): void {
    if (this.closed || this.pumpQueued) return;
    this.pumpQueued = true;
    setImmediate(() => {
      this.pumpQueued = false;
      this.pump();
    });
  }

  private async buildNode(l: number, i: number): Promise<void> {
    const k = nodeKey(l, i);
    let failed = false;
    try {
      const end = l === 0 ? i : (i + 1) * Math.pow(2, l);
      let text: string;
      if (l === 0) {
        const m = this.root[i];
        const src = `${m.kind}: ${m.text}`;
        text =
          byteLength(src) <= NODE
            ? src
            : await this.summarize(end, compressStep(m.kind, m.text));
      } else {
        const a = this.nodes.get(nodeKey(l - 1, 2 * i));
        const b = this.nodes.get(nodeKey(l - 1, 2 * i + 1));
        if (!a || !b) return; // cannot happen: pump checks readiness
        const joined = `${a.text}\n${b.text}`;
        text =
          byteLength(joined) <= NODE
            ? joined
            : await this.summarize(end, mergeStep(a.text, b.text));
      }
      if (this.closed || this.abort.signal.aborted) return;
      const node: TreeNode = { l, i, text, size: byteLength(text) };
      appendLine(this.dayFile("tree"), JSON.stringify(node));
      this.nodes.set(k, node);
      this.retryAt.delete(k);
      this.fit();
    } catch (err) {
      if (this.closed || this.abort.signal.aborted) return;
      failed = true;
      if (!this.reported.has(k)) {
        this.reported.add(k);
        this.hooks.onError(
          `OptChat compactor: node ${k} failed: ${errorText(err)} (retrying every 10s)`,
        );
      }
      this.retryAt.set(k, Date.now() + RETRY_MS);
    } finally {
      this.busy.delete(k);
      this.schedulePump();
    }
    if (failed) {
      // No exponential backoff: the next turn waits on these (§4.1).
      const at = this.retryAt.get(k);
      if (at !== undefined)
        setTimeout(() => this.pump(), Math.max(0, at - Date.now()) + 50);
    }
  }

  /**
   * One compactor call per node (§4.2-§4.3): the view up to the node as
   * context, a 512-byte SCALE line, then the step; oversized replies are
   * fed back cut at the limit, up to TRIES, keeping the shortest.
   */
  private async summarize(end: number, step: string): Promise<string> {
    const model = this.compactor;
    if (!model) throw new Error("no compactor model configured");
    let conversation: Message[] = [
      {
        role: "user",
        content: [
          { type: "text", text: `<chat>\n${this.contextLines(end)}\n</chat>` },
          { type: "text", text: step },
        ],
        timestamp: Date.now(),
      },
    ];
    const tries: string[] = [];
    let reply = await this.ask(model, conversation);
    for (let attempts = 1; ; attempts++) {
      const line = assistantText(reply).trim();
      if (line) tries.push(line);
      if (line && (byteLength(line) <= NODE || attempts >= TRIES)) break;
      if (!line && attempts >= TRIES) {
        // Reasoning models occasionally reply with thinking only; after
        // TRIES empties, fail the node and let the 10s retry take over.
        throw new Error(
          `compactor returned an empty reply ${attempts} times (stopReason: ${reply.stopReason})`,
        );
      }
      // Both failures get one more chance in the same conversation (§4.3).
      const feedback = line
        ? overLimitFeedback(line, byteLength(line))
        : "That reply was empty. Output only the line.";
      conversation = [
        ...conversation,
        reply,
        {
          role: "user",
          content: [{ type: "text", text: feedback }],
          timestamp: Date.now(),
        },
      ];
      reply = await this.ask(model, conversation);
    }
    return tries.reduce((a, c) => (byteLength(c) < byteLength(a) ? c : a));
  }

  private async ask(
    model: Model<any>,
    messages: Message[],
  ): Promise<AssistantMessage> {
    const reply = await this.hooks.complete(
      model,
      { systemPrompt: COMPACT, messages },
      this.abort.signal,
    );
    if (reply.stopReason === "error")
      throw new Error(reply.errorMessage ?? "compactor call failed");
    return reply;
  }

  /** View lines up to the node's last message, bare, one per line (§4.2). */
  private contextLines(end: number): string {
    const out: string[] = [];
    for (const p of this.view) {
      if (p.start >= end) break;
      const t = this.nodes.get(nodeKey(p.l, p.i));
      if (t) out.push(t.text.replace(/\n/g, " "));
    }
    return out.join("\n");
  }

  // ------------------------------------------------------------------ tools

  /**
   * §7.1: open line id+n into the two lines of n/2 under it; n = 1 gives
   * the message whole. (The spec writes the whole message as "id+0|";
   * we render it "id+1|" so a one-message line reads the same as in the
   * view, where level-0 parts render as id+1.)
   */
  zoom(id: number, n: number): string {
    if (
      !Number.isInteger(id) ||
      !Number.isInteger(n) ||
      n < 1 ||
      (n & (n - 1)) !== 0
    ) {
      return "n must be a power of 2 (1, 2, 4, ...).";
    }
    const T = this.root.length;
    if (id < 0 || id % n !== 0 || id + n > T) {
      return `No line ${id}+${n}. The chat has ${T} messages; ids run 0-${T - 1}.`;
    }
    if (n === 1) {
      const m = this.root[id];
      return `${id}+1|${m.kind}: ${m.text}`;
    }
    const l = Math.log2(n) - 1;
    const a = this.nodes.get(nodeKey(l, (2 * id) / n));
    const b = this.nodes.get(nodeKey(l, (2 * id) / n + 1));
    if (!a || !b) return `No line ${id}+${n} (that node is not built yet).`;
    const h = n / 2;
    return `${id}+${h}|${a.text.replace(/\n/g, " ")}\n${id + h}+${h}|${b.text.replace(/\n/g, " ")}`;
  }

  /** §7.1: the date and time of message id. */
  date(id: number): string {
    const m = this.root[id];
    if (!m) return `No message ${id}.`;
    return `${m.date} (message ${id})`;
  }

  stats(): MemoryStats {
    let unbuilt = 0;
    for (const p of this.view) {
      if (!this.nodes.has(nodeKey(p.l, p.i))) unbuilt++;
    }
    return {
      messages: this.root.length,
      nodes: this.nodes.size,
      parts: this.view.length,
      viewBytes: this.viewByteCount(),
      unbuilt,
      compactor: this.compactor
        ? `${this.compactor.provider}/${this.compactor.id}`
        : "none",
    };
  }
}
