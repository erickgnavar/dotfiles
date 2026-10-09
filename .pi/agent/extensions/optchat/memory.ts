/**
 * The OptChat memory: an append-only log of every
 * message, a binary tree of one-line summaries over it, and two views
 * folded from both — the chat's view (64-128 KB, batched sawtooth) sent
 * to the model each turn, and the smaller compaction view (16-32 KB)
 * sent as context to each compactor call. Ready nodes are kept in
 * queues, never found by scanning the tree.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import {
  appendLine,
  byteLength,
  loadJsonl,
  localDay,
  splitText,
  UncertainAppendError,
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

export const VIEW_CEIL = 128_000; // the chat's view batches past this (≈ 62-64k tokens)
export const VIEW_FLOOR = 64_000; // ... down to this, in one batch
export const CVIEW_CEIL = 32_000; // the compaction view batches past this
export const CVIEW_FLOOR = 16_000; // ... down to this, with the chat's view
export const JOBS = 8; // compactor calls running at once
export const LEAF_WINDOW = 8; // unbuilt lines allowed before a message's node
export const TRIES = 5; // attempts per node to get under NODE
export const RETRY_MS = 10_000; // wait before retrying a transiently failed node
export const CAP = 30_000; // max characters of one tool result (head + tail kept)
const PLACEHOLDER = "(not summarized yet: zoom it)";
/** Quota or authentication failures are not transient: pause instead of retrying. */
const FATAL =
  /429|quota|usage limit|rate.?limit|40[13]|unauthorized|invalid[ _-]?api[ _-]?key|billing|exceeded/i;

/** One tile of a view: tree node (l, i), covering [start, start + n). */
export interface Part {
  l: number;
  i: number;
  start: number;
  n: number;
}

export interface Budgets {
  view?: number;
  floor?: number;
  cview?: number;
  cfloor?: number;
  retryMs?: number;
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
  cparts: number;
  viewBytes: number;
  unbuilt: number;
  paused: boolean;
  compactor: string;
}

const nodeKey = (l: number, i: number) => `${l}:${i}`;
const parseKey = (k: string): [number, number] => {
  const c = k.indexOf(":");
  return [Number(k.slice(0, c)), Number(k.slice(c + 1))];
};

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
  cview: Part[] = [];
  private readonly compactor: Model<any> | undefined;
  private readonly hooks: CompactorHooks;
  private readonly budgets: Required<Budgets>;
  private readonly abort = new AbortController();
  private readonly busy = new Set<string>();
  private readonly retryAt = new Map<string, number>();
  private readonly reported = new Set<string>();
  private readonly retryTimers = new Set<ReturnType<typeof setTimeout>>();
  private readonly leafQueue: number[] = [];
  private readonly mergeQueue: string[] = [];
  private readonly mergeQueued = new Set<string>();
  private waiters: Array<(ok: boolean) => void> = [];
  private leafFront = 0; // first message whose level-0 node is unbuilt
  private cviewUpTo = 0; // first message not yet in the compaction view
  private batching = false;
  private cbatching = false;
  private paused = false;
  private closed = false;
  private pumpQueued = false;
  private loading = false;
  private viewDirty = false;

  constructor(
    dir: string,
    compactor: Model<any> | undefined,
    hooks: CompactorHooks,
    budgets: Budgets = {},
  ) {
    this.dir = dir;
    this.compactor = compactor;
    this.hooks = hooks;
    this.budgets = {
      view: budgets.view ?? VIEW_CEIL,
      floor: budgets.floor ?? VIEW_FLOOR,
      cview: budgets.cview ?? CVIEW_CEIL,
      cfloor: budgets.cfloor ?? CVIEW_FLOOR,
      retryMs: budgets.retryMs ?? RETRY_MS,
    };
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
    // The view is saved in view.json and restored, never rebuilt (§3.2):
    // a rebuilt view differs from the live one, and every cache entry dies.
    if (!this.loadSavedView()) {
      this.loading = true;
      try {
        for (let i = 0; i < this.root.length; i++) {
          this.view.push({ l: 0, i, start: i, n: 1 });
          this.fit();
        }
        this.rebuildCview();
      } finally {
        this.loading = false;
      }
    }
    // A crash can leave durable nodes ahead of the saved compaction view.
    this.pushCviewLeaves();
    this.cfit();
    this.advanceLeafFront();
    for (let i = 0; i < this.root.length; i++) {
      if (!this.nodes.has(nodeKey(0, i))) this.leafQueue.push(i);
    }
    // Queue every ready merge: a built node whose sibling is also built,
    // under a parent that is not (a crash can have lost the enqueue).
    for (const n of this.nodes.values()) {
      if (!this.nodes.has(nodeKey(n.l, n.i ^ 1))) continue;
      const parent = nodeKey(n.l + 1, n.i >> 1);
      if (this.nodes.has(parent) || this.mergeQueued.has(parent)) continue;
      this.mergeQueued.add(parent);
      this.mergeQueue.push(parent);
    }
    this.viewDirty = true;
    this.saveView();
    if (torn > 0)
      this.hooks.onError(
        `OptChat: skipped ${torn} torn lines while loading the log`,
      );
  }

  /** Restore the saved views; false when missing or not a valid tiling. */
  private loadSavedView(): boolean {
    let saved: unknown;
    try {
      saved = JSON.parse(
        fs.readFileSync(path.join(this.dir, "view.json"), "utf8"),
      );
    } catch {
      return false;
    }
    if (!saved || typeof saved !== "object") return false;
    const s = saved as {
      version?: unknown;
      batching?: unknown;
      cbatching?: unknown;
      cviewUpTo?: unknown;
      view?: unknown;
      cview?: unknown;
    };
    if (s.version !== undefined && s.version !== 1) return false;
    const T = this.root.length;
    const restore = (
      raw: unknown,
      requireBuilt: boolean,
      expected: number,
    ): Part[] | null => {
      if (!Array.isArray(raw)) return null;
      const parts: Part[] = [];
      let pos = 0;
      for (const entry of raw) {
        if (!Array.isArray(entry) || entry.length !== 2) return null;
        const [l, i] = entry;
        if (
          !Number.isInteger(l) ||
          !Number.isInteger(i) ||
          l < 0 ||
          l > 52 ||
          i < 0 ||
          !Number.isSafeInteger(i)
        )
          return null;
        const n = Math.pow(2, l);
        if (i * n !== pos || pos + n > expected) return null;
        // Only a level-0 line may be unbuilt (a placeholder); a missing
        // parent in the saved view means the log moved under it.
        if ((requireBuilt || l > 0) && !this.nodes.has(nodeKey(l, i))) {
          return null;
        }
        parts.push({ l, i, start: pos, n });
        pos += n;
      }
      return pos === expected ? parts : null;
    };
    const view = restore(s.view, false, T);
    if (!view) return false;
    const cviewUpTo = s.cviewUpTo;
    if (
      typeof cviewUpTo !== "number" ||
      !Number.isSafeInteger(cviewUpTo) ||
      cviewUpTo < 0 ||
      cviewUpTo > T
    )
      return false;
    const cview = restore(s.cview, true, cviewUpTo);
    if (!cview) return false;
    this.view = view;
    this.cview = cview;
    this.cviewUpTo = cviewUpTo;
    this.batching = s.batching === true;
    this.cbatching = s.cbatching === true;
    return true;
  }

  /** Fallback compaction view: built leaves in order, batched to budget. */
  private rebuildCview(): void {
    this.cview = [];
    this.cviewUpTo = 0;
    this.cbatching = false;
    this.pushCviewLeaves();
    if (this.cviewByteCount() > this.budgets.cview) {
      this.cbatching = true;
      this.cmerge();
      this.cbatching = this.cviewByteCount() > this.budgets.cfloor;
    }
  }

  private saveView(): void {
    if (!this.viewDirty || this.loading) return;
    const file = path.join(this.dir, "view.json");
    const tmp = `${file}.tmp`;
    const data = JSON.stringify({
      version: 1,
      batching: this.batching,
      cbatching: this.cbatching,
      cviewUpTo: this.cviewUpTo,
      view: this.view.map((p) => [p.l, p.i]),
      cview: this.cview.map((p) => [p.l, p.i]),
    });
    try {
      fs.writeFileSync(tmp, data);
      fs.renameSync(tmp, file);
      this.viewDirty = false;
    } catch (err) {
      this.hooks.onError(`OptChat: could not save the view: ${errorText(err)}`);
    }
  }

  // ------------------------------------------------------------------- log

  /** Append one message: to disk first, then to memory, the view, the pump. */
  log(kind: LogMessage["kind"], text: string): number {
    if (this.closed)
      throw new Error(
        "OptChat recording stopped; /reload before recording again.",
      );
    const i = this.root.length;
    const msg: LogMessage = {
      i,
      kind,
      text,
      size: byteLength(`${kind}: ${text}`),
      date: new Date().toISOString(),
    };
    try {
      appendLine(this.dayFile("main"), JSON.stringify(msg));
    } catch (err) {
      if (err instanceof UncertainAppendError) this.close();
      throw err;
    }
    this.root.push(msg);
    this.view.push({ l: 0, i, start: i, n: 1 });
    this.leafQueue.push(i);
    this.viewDirty = true;
    this.fit();
    this.schedulePump();
    return i;
  }

  /** Long text is never cut (§1): it is logged as several messages in a row. */
  logText(kind: LogMessage["kind"], text: string): number {
    const parts = splitText(text);
    const first = this.log(kind, parts[0]);
    for (let p = 1; p < parts.length; p++) this.log(kind, parts[p]);
    return first;
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

  private cviewByteCount(): number {
    let size = 0;
    for (const p of this.cview) {
      size += byteLength(this.nodes.get(nodeKey(p.l, p.i))?.text ?? "");
    }
    return size;
  }

  /** §3: one line per part, oldest first, newlines shown as spaces. */
  renderView(): string {
    const lines = this.view.map((p) => {
      const text = this.nodes.get(nodeKey(p.l, p.i))?.text ?? PLACEHOLDER;
      return `${p.start}+${p.n}|${text.replace(/\n/g, " ")}`;
    });
    return `<chat>\n${lines.join("\n")}\n</chat>`;
  }

  /**
   * Keep the chat's view a batched sawtooth (§3.2): it grows one line per
   * message; past the ceiling, one batch merges the most due pairs down
   * to the floor. Due is measured from the pair's LAST message: measuring
   * from the first churns old lines and their cache entries.
   */
  fit(): void {
    if (!this.batching && this.viewByteCount() <= this.budgets.view) {
      this.saveView();
      this.wake();
      return;
    }
    this.batching = true;
    this.viewDirty = true;
    this.merge();
    if (this.viewByteCount() <= this.budgets.floor) this.batching = false;
    // The compaction view batches with the chat's view, and on its own.
    this.cfit();
    this.saveView();
    this.wake();
  }

  /** One batch of merges: the most due pairs whose parent is built. */
  private merge(): void {
    let dirty = false;
    const T = this.root.length;
    while (this.viewByteCount() > this.budgets.floor) {
      let best = -1;
      let bestDue = -1;
      for (let p = 0; p + 1 < this.view.length; p++) {
        const a = this.view[p];
        const b = this.view[p + 1];
        if (a.l !== b.l || a.i % 2 !== 0 || b.i !== a.i + 1) continue;
        if (!this.nodes.has(nodeKey(a.l + 1, a.i / 2))) continue;
        const due = (T - (b.start + b.n - 1)) / a.n;
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
      dirty = true;
    }
    if (dirty) this.viewDirty = true;
  }

  private cfit(): void {
    if (!this.cbatching && this.cviewByteCount() <= this.budgets.cview) {
      return;
    }
    this.cbatching = true;
    this.viewDirty = true;
    this.cmerge();
    if (this.cviewByteCount() <= this.budgets.cfloor) this.cbatching = false;
  }

  private cmerge(): void {
    let dirty = false;
    const T = this.root.length;
    while (this.cviewByteCount() > this.budgets.cfloor) {
      let best = -1;
      let bestDue = -1;
      for (let p = 0; p + 1 < this.cview.length; p++) {
        const a = this.cview[p];
        const b = this.cview[p + 1];
        if (a.l !== b.l || a.i % 2 !== 0 || b.i !== a.i + 1) continue;
        if (!this.nodes.has(nodeKey(a.l + 1, a.i / 2))) continue;
        const due = (T - (b.start + b.n - 1)) / a.n;
        if (due > bestDue) {
          bestDue = due;
          best = p;
        }
      }
      if (best < 0) break;
      const a = this.cview[best];
      this.cview.splice(best, 2, {
        l: a.l + 1,
        i: a.i / 2,
        start: a.start,
        n: a.n * 2,
      });
      dirty = true;
    }
    if (dirty) this.viewDirty = true;
  }

  /** Append built level-0 nodes to the compaction view, in order. */
  private pushCviewLeaves(): void {
    const T = this.root.length;
    while (this.cviewUpTo < T && this.nodes.has(nodeKey(0, this.cviewUpTo))) {
      this.cview.push({
        l: 0,
        i: this.cviewUpTo,
        start: this.cviewUpTo,
        n: 1,
      });
      this.cviewUpTo++;
      this.viewDirty = true;
    }
  }

  // --------------------------------------------------------------- settle

  /** §6: resolve true when every line of the view is a summary. */
  settle(signal?: AbortSignal): Promise<boolean> {
    if (this.closed || signal?.aborted) return Promise.resolve(false);
    if (this.allBuilt()) return Promise.resolve(true);
    if (this.paused) return Promise.resolve(false);
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
    for (const timer of this.retryTimers) clearTimeout(timer);
    this.retryTimers.clear();
    const waiters = this.waiters.splice(0);
    for (const w of waiters) w(false);
  }

  // -------------------------------------------------------------- compactor

  /** First message whose view line is unbuilt. */
  firstUnbuilt(): number {
    for (const p of this.view) {
      if (!this.nodes.has(nodeKey(p.l, p.i))) return p.start;
    }
    return this.root.length;
  }

  isPaused(): boolean {
    return this.paused;
  }

  /** Resume after a paused (quota/auth) failure: forget the retry times. */
  resume(): void {
    if (!this.paused) return;
    this.paused = false;
    this.retryAt.clear();
    this.pump();
  }

  /**
   * Launch ready nodes, up to JOBS at once (§4), from the ready queues —
   * never by scanning the tree. Leaves run in message order, up to
   * LEAF_WINDOW unbuilt lines ahead; merges run once both halves are
   * built and their whole context is summarized.
   */
  pump(): void {
    if (this.closed || this.paused) return;
    const T = this.root.length;
    if (T === 0) return;
    const now = Date.now();
    const heldLeaves: number[] = [];
    while (this.busy.size < JOBS && this.leafQueue.length > 0) {
      const i = this.leafQueue.shift() as number;
      if (i >= T || this.nodes.has(nodeKey(0, i))) continue;
      const unbuiltBefore = i - this.leafFront;
      if (this.busy.has(nodeKey(0, i)) || unbuiltBefore >= LEAF_WINDOW) {
        heldLeaves.push(i);
        break; // in order: every later leaf is blocked too
      }
      const at = this.retryAt.get(nodeKey(0, i));
      if (at !== undefined && now < at) {
        heldLeaves.push(i);
        continue;
      }
      this.launch(0, i);
    }
    this.leafQueue.unshift(...heldLeaves);
    const first = this.firstUnbuilt();
    const heldMerges: string[] = [];
    while (this.busy.size < JOBS && this.mergeQueue.length > 0) {
      const k = this.mergeQueue.shift() as string;
      if (this.nodes.has(k) || this.busy.has(k)) {
        this.mergeQueued.delete(k);
        continue;
      }
      const [l, i] = parseKey(k);
      if ((i + 1) * Math.pow(2, l) > first) {
        heldMerges.push(k);
        continue;
      }
      const at = this.retryAt.get(k);
      if (at !== undefined && now < at) {
        heldMerges.push(k);
        continue;
      }
      this.mergeQueued.delete(k);
      this.launch(l, i);
    }
    this.mergeQueue.unshift(...heldMerges);
  }

  private launch(l: number, i: number): void {
    const k = nodeKey(l, i);
    this.busy.add(k);
    void this.buildNode(l, i);
  }

  private schedulePump(): void {
    if (this.closed || this.pumpQueued) return;
    this.pumpQueued = true;
    setImmediate(() => {
      this.pumpQueued = false;
      this.pump();
    });
  }

  private advanceLeafFront(): void {
    const T = this.root.length;
    while (this.leafFront < T && this.nodes.has(nodeKey(0, this.leafFront))) {
      this.leafFront++;
    }
  }

  private async buildNode(l: number, i: number): Promise<void> {
    const k = nodeKey(l, i);
    let failed = false;
    try {
      const end = l === 0 ? i + 1 : (i + 1) * Math.pow(2, l);
      let text: string;
      if (l === 0) {
        const m = this.root[i];
        const src = `${m.kind}: ${m.text}`;
        text =
          byteLength(src) <= NODE
            ? src
            : await this.summarize(end, compressStep(i, m.kind, m.text));
      } else {
        const a = this.nodes.get(nodeKey(l - 1, 2 * i));
        const b = this.nodes.get(nodeKey(l - 1, 2 * i + 1));
        if (!a || !b) return; // cannot happen: the queue checks readiness
        const joined = `${a.text}\n${b.text}`;
        text =
          byteLength(joined) <= NODE
            ? joined
            : await this.summarize(
                end,
                mergeStep(
                  2 * i * Math.pow(2, l - 1),
                  (2 * i + 1) * Math.pow(2, l - 1),
                  i * Math.pow(2, l),
                  end,
                  a.text,
                  b.text,
                ),
              );
      }
      if (this.closed || this.abort.signal.aborted) return;
      const node: TreeNode = { l, i, text, size: byteLength(text) };
      appendLine(this.dayFile("tree"), JSON.stringify(node));
      this.nodes.set(k, node);
      this.retryAt.delete(k);
      this.onBuilt(l, i);
      this.fit();
    } catch (err) {
      if (this.closed || this.abort.signal.aborted) return;
      if (err instanceof UncertainAppendError) {
        this.close();
        this.hooks.onError(errorText(err));
        return;
      }
      const message = errorText(err);
      // The queues hold only unbuilt work: put this node back (a
      // paused compactor finds it again on /optchat resume).
      if (l === 0) {
        this.leafQueue.push(i);
        this.leafQueue.sort((a, b) => a - b);
      } else if (!this.mergeQueued.has(k)) {
        this.mergeQueued.add(k);
        this.mergeQueue.unshift(k);
      }
      if (FATAL.test(message)) {
        // Quota and auth failures are not transient: pause, don't churn.
        if (!this.paused) {
          this.paused = true;
          const waiters = this.waiters.splice(0);
          for (const w of waiters) w(false);
          this.hooks.onError(
            `OptChat compaction paused: ${message}. Run /optchat resume once it is fixed.`,
          );
        }
      } else {
        failed = true;
        if (!this.reported.has(k)) {
          this.reported.add(k);
          this.hooks.onError(
            `OptChat compactor: node ${k} failed: ${message} (retrying every ${Math.round(this.budgets.retryMs / 1000)}s)`,
          );
        }
        this.retryAt.set(k, Date.now() + this.budgets.retryMs);
      }
    } finally {
      this.busy.delete(k);
      if (!this.paused) this.schedulePump();
    }
    if (failed && !this.paused) {
      // No exponential backoff: the next turn waits on these (§4).
      const at = this.retryAt.get(k);
      if (at !== undefined) {
        const timer = setTimeout(
          () => {
            this.retryTimers.delete(timer);
            this.pump();
          },
          Math.max(0, at - Date.now()) + 50,
        );
        this.retryTimers.add(timer);
      }
    }
  }

  /** After a node is built: order, the compaction view, ready merges. */
  private onBuilt(l: number, i: number): void {
    if (l === 0) this.advanceLeafFront();
    this.pushCviewLeaves();
    if (this.cbatching || this.cviewByteCount() > this.budgets.cview)
      this.cfit();
    const sib = nodeKey(l, i ^ 1);
    if (this.nodes.has(sib)) {
      const parent = nodeKey(l + 1, i >> 1);
      if (
        !this.nodes.has(parent) &&
        !this.mergeQueued.has(parent) &&
        !this.busy.has(parent)
      ) {
        this.mergeQueued.add(parent);
        this.mergeQueue.push(parent);
      }
    }
  }

  /**
   * One compactor call per node (§4): the compaction view up to the node
   * as context, the ruler, then the task in <input>; oversized or empty
   * replies are fed back, up to TRIES, keeping the shortest.
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
        throw new Error(
          `compactor returned an empty reply ${attempts} times (stopReason: ${reply.stopReason})`,
        );
      }
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
    const shortest = tries.reduce((a, c) =>
      byteLength(c) < byteLength(a) ? c : a,
    );
    if (byteLength(shortest) > NODE) {
      throw new Error(
        `compactor line remains over ${NODE} bytes after ${TRIES} attempts`,
      );
    }
    return shortest;
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
    if (reply.stopReason === "error" || reply.stopReason === "aborted")
      throw new Error(
        reply.errorMessage ?? `compactor call ${reply.stopReason}`,
      );
    return reply;
  }

  /** Compaction-view lines up to the node's last message, bare (§4). */
  private contextLines(end: number): string {
    const out: string[] = [];
    let bytes = 0;
    const add = (p: Part): void => {
      if (p.start >= end) return;
      if (p.start + p.n > end) {
        // A view line may have merged past this task's boundary.
        const n = p.n / 2;
        add({ l: p.l - 1, i: p.i * 2, start: p.start, n });
        add({ l: p.l - 1, i: p.i * 2 + 1, start: p.start + n, n });
        return;
      }
      const node = this.nodes.get(nodeKey(p.l, p.i));
      if (!node) return;
      const text = node.text.replace(/\n/g, " ");
      const size = byteLength(text) + (out.length > 0 ? 1 : 0);
      // A batch can be waiting for parents; never send an oversized prefix.
      if (bytes + size > this.budgets.cview) return;
      out.push(text);
      bytes += size;
    };
    for (const p of this.cview) {
      if (p.start >= end) break;
      add(p);
    }
    return out.join("\n");
  }

  // ------------------------------------------------------------------ tools

  /**
   * §6: open line id+n into the two lines of n/2 under it; n = 1 gives
   * the message whole. (The original spec wrote the whole message as
   * "id+0|"; we render it "id+1|" so a one-message line reads the same
   * as in the view, where level-0 parts render as id+1.)
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

  /** §6: the date and time of message id. */
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
      cparts: this.cview.length,
      viewBytes: this.viewByteCount(),
      unbuilt,
      paused: this.paused,
      compactor: this.compactor
        ? `${this.compactor.provider}/${this.compactor.id}`
        : "none",
    };
  }
}
