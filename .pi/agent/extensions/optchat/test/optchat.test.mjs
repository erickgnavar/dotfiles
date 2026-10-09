/**
 * Regression tests for the OptChat memory, run with a mocked compactor:
 *   node --experimental-strip-types test/optchat.test.mjs
 * No model calls, no network: hooks.complete fakes every reply.
 */

import assert from "node:assert/strict";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { OptChat, CVIEW_CEIL } from "../memory.ts";
import {
  splitText,
  byteLength,
  localDay,
  saveImage,
  loadJsonl,
  UncertainAppendError,
} from "../store.ts";
import { NODE, RULER } from "../prompts.ts";

const fakeModel = { provider: "fake", id: "fake" };
const fakeReply = (text) => ({
  role: "assistant",
  content: [{ type: "text", text }],
  api: "fake",
  provider: "fake",
  model: "fake",
  usage: {},
  stopReason: "stop",
});

let dir;
let calls;
let plan;
let errors;
let steps;

function freshDir() {
  dir = mkdtempSync(join(tmpdir(), "optchat-test-"));
  mkdirSync(join(dir, "main"), { recursive: true });
  mkdirSync(join(dir, "tree"), { recursive: true });
}

function fakeHooks() {
  calls = 0;
  plan = [];
  errors = [];
  steps = [];
  return {
    complete: async (_model, context) => {
      calls++;
      const step = context.messages[0].content[1].text;
      steps.push(step);
      assert.match(
        step,
        /^Compaction: (compress message \d+|merge lines \d+ and \d+)/,
      );
      assert.ok(step.includes(RULER), "the task shows the ruler");
      assert.ok(step.includes("<input>"), "the task wraps the input");
      return fakeReply(
        plan.length > 0 ? plan.shift() : "line " + "x".repeat(300),
      );
    },
    onError: (m) => errors.push(m),
  };
}

function fresh(budgets) {
  freshDir();
  const chat = new OptChat(dir, fakeModel, fakeHooks(), budgets);
  chat.load();
  return chat;
}

async function buildAll(chat, ms = 1000) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline && !chat.allBuilt()) await delay(5);
  assert.ok(chat.allBuilt(), "the compactor builds everything");
}

async function waitFor(predicate, ms = 5000) {
  const deadline = Date.now() + ms;
  while (!predicate() && Date.now() < deadline) await delay(5);
  assert.ok(predicate(), "background work finishes before the deadline");
}

// Keep fault injection scoped and update the named fs exports used by storage.
async function withFsFaults(faults, run) {
  const originals = Object.fromEntries(
    Object.keys(faults).map((key) => [key, fs[key]]),
  );
  for (const [key, inject] of Object.entries(faults)) {
    fs[key] = (...args) => inject(originals[key], ...args);
  }
  syncBuiltinESMExports();
  try {
    await run();
  } finally {
    Object.assign(fs, originals);
    syncBuiltinESMExports();
  }
}

const tests = [];
const test = (name, fn) => tests.push([name, fn]);

test("merge order measures age from the pair's last message", () => {
  // T=10, view 0+4, 4+4, 8+1, 9+1, both parents built.
  // Last-based: 8+9 (due 1) beats 0-7 (due 0.75). First-based: 0-7 wins.
  const chat = fresh({ view: 160, floor: 160, cview: 1000, cfloor: 900 });
  chat.root.push(
    ...Array.from({ length: 10 }, (_, i) => ({
      i,
      kind: "user",
      text: `m${i}`,
      size: 8,
      date: "",
    })),
  );
  const put = (l, i, t) =>
    chat.nodes.set(`${l}:${i}`, { l, i, text: t, size: t.length });
  put(0, 8, "a".repeat(40));
  put(0, 9, "b".repeat(40));
  put(1, 4, "c".repeat(50));
  put(2, 0, "d".repeat(55));
  put(2, 1, "e".repeat(55));
  put(3, 0, "f".repeat(60)); // must NOT be chosen
  chat.view = [
    { l: 2, i: 0, start: 0, n: 4 },
    { l: 2, i: 1, start: 4, n: 4 },
    { l: 0, i: 8, start: 8, n: 1 },
    { l: 0, i: 9, start: 9, n: 1 },
  ];
  chat.fit();
  const lines = chat.view.map((p) => `${p.l}:${p.i}`).join(" ");
  assert.equal(lines, "2:0 2:1 1:4", "merges the newest pair 8+9, not 0-7");
  chat.close();
});

test("the view is a batched sawtooth: between batches it only grows", async () => {
  const chat = fresh({ view: 2000, floor: 800, cview: 100000, cfloor: 90000 });
  for (let i = 0; i < 20; i++)
    chat.log("user", `message ${i} ` + "y".repeat(120));
  await buildAll(chat);
  await waitFor(() => chat.viewByteCount() <= 800);
  const sizes = [];
  for (let i = 0; i < 6; i++) {
    chat.log("user", `extra ${i} ` + "y".repeat(120));
    await buildAll(chat, 200);
    sizes.push(chat.viewByteCount());
  }
  for (let j = 1; j < sizes.length; j++) {
    assert.ok(sizes[j] >= sizes[j - 1], "between batches the view only grows");
  }
  chat.close();
});

test("the compaction view stays within its own smaller budget", async () => {
  const chat = fresh(); // default budgets: chat 128k/64k, compaction 32k/16k
  for (let i = 0; i < 300; i++)
    chat.log("user", `message ${i} ` + "y".repeat(150));
  await buildAll(chat, 5000);
  let cbytes = chat.cview.reduce(
    (a, p) => a + chat.nodes.get(`${p.l}:${p.i}`).size,
    0,
  );
  const deadline = Date.now() + 5000; // merges keep landing after allBuilt
  while (cbytes > CVIEW_CEIL && Date.now() < deadline) {
    await delay(50);
    cbytes = chat.cview.reduce(
      (a, p) => a + chat.nodes.get(`${p.l}:${p.i}`).size,
      0,
    );
  }
  assert.ok(
    cbytes > 0 && cbytes <= CVIEW_CEIL,
    `compaction view within budget (${cbytes}B)`,
  );
  assert.ok(
    chat.viewByteCount() > cbytes,
    "the compaction view is smaller than the chat view",
  );
  assert.ok(chat.stats().cparts > 0);
  chat.close();
});

test("view.json is saved and restored, never rebuilt", async () => {
  const chat = fresh();
  for (let i = 0; i < 20; i++)
    chat.log("user", `message ${i} ` + "y".repeat(200));
  await buildAll(chat);
  const rendered = chat.renderView();
  const parts = chat.stats().parts;
  const chat2 = new OptChat(dir, fakeModel, fakeHooks());
  chat2.load();
  assert.equal(
    chat2.renderView(),
    rendered,
    "the restored view is byte-identical",
  );
  assert.equal(chat2.stats().parts, parts);
  chat.close();
  chat2.close();
});

test("a corrupt view.json falls back to a fold, not a crash", async () => {
  const chat = fresh();
  for (let i = 0; i < 8; i++) chat.log("user", `m${i}`);
  await buildAll(chat);
  chat.close();
  writeFileSync(join(dir, "view.json"), "{not json");
  const chat2 = new OptChat(dir, fakeModel, fakeHooks());
  chat2.load();
  assert.ok(chat2.allBuilt(), "the fold rebuilds a complete view");
  chat2.close();
});

test("empty then oversized replies retry in the same conversation", async () => {
  const chat = fresh();
  plan = ["", "z".repeat(600), "good short line"];
  chat.log("user", "w".repeat(600));
  await buildAll(chat, 2000);
  const node = [...chat.nodes.values()].find((n) => n.l === 0);
  assert.equal(node.text, "good short line", "keeps the shortest good line");
  assert.equal(calls, 3, "empty and oversized each got one feedback round");
  assert.equal(errors.length, 0, "no node failure for recoverable replies");
  chat.close();
});

test("quota failures pause the compactor; resume restarts it", async () => {
  freshDir();
  let quotaFail = true;
  const bad = new OptChat(dir, fakeModel, {
    complete: async () => {
      if (quotaFail) {
        quotaFail = false;
        throw new Error(
          '429: {"type":"GoUsageLimitError","message":"Go usage limit exceeded"}',
        );
      }
      return fakeReply("line " + "x".repeat(300));
    },
    onError: (m) => errors.push(m),
  });
  errors = [];
  bad.log("user", "w".repeat(600));
  await delay(50);
  assert.ok(bad.isPaused(), "a quota error pauses compaction");
  assert.equal(await bad.settle(), false, "settle does not hang while paused");
  assert.ok(
    errors.some((e) => e.includes("paused")),
    "one pause notice",
  );
  const before = errors.length;
  bad.log("user", "w".repeat(600));
  await delay(50);
  assert.equal(errors.length, before, "no retry spam while paused");
  bad.resume();
  await buildAll(bad, 2000);
  assert.ok(!bad.isPaused(), "resume clears the pause and finishes the work");
  bad.close();
});

test("transient failures retry on their own, without pausing", async () => {
  freshDir();
  let fail = true;
  const flakyChat = new OptChat(
    dir,
    fakeModel,
    {
      complete: async () => {
        if (fail) {
          fail = false;
          throw new Error("socket hang up");
        }
        return fakeReply("line " + "x".repeat(300));
      },
      onError: (m) => errors.push(m),
    },
    { retryMs: 100 },
  );
  errors = [];
  flakyChat.log("user", "w".repeat(600));
  await buildAll(flakyChat, 3000);
  assert.ok(!flakyChat.isPaused(), "a transient error does not pause");
  assert.ok(
    errors.some((e) => e.includes("retrying")),
    "the failure is reported once",
  );
  flakyChat.close();
});

test("long text is never cut: it splits into messages in a row", () => {
  const base = "word ".repeat(4000); // 20 KB
  const parts = splitText(base);
  assert.ok(parts.length > 1, "20 KB splits into several messages");
  let off = 0;
  for (const p of parts) {
    assert.ok(byteLength(p) <= 16000, "each part fits one message");
    assert.equal(p, base.slice(off, off + p.length));
    off += p.length;
  }
  assert.equal(off, base.length, "nothing lost, nothing cut");
  const unicode = "héllo…😀".repeat(4000);
  const unicodeParts = splitText(unicode);
  assert.equal(
    unicodeParts.join(""),
    unicode,
    "Unicode text round-trips exactly",
  );
  for (const p of unicodeParts) assert.ok(byteLength(p) <= 16000);
  assert.throws(() => splitText(unicode, 0), /chunk/);
});

test("the pump runs from queues: at most 8 leaves at once, in order", async () => {
  freshDir();
  let gates = 0;
  let release;
  const gate = new Promise((r) => (release = r));
  const slow = new OptChat(dir, fakeModel, {
    complete: async () => {
      gates++;
      await gate;
      return fakeReply("line " + "x".repeat(300));
    },
    onError: (m) => errors.push(m),
  });
  errors = [];
  for (let i = 0; i < 30; i++) slow.log("user", `m${i} ` + "w".repeat(600));
  await delay(50);
  assert.equal(gates, 8, "eight compactor calls at once, not thirty");
  release();
  await buildAll(slow, 5000);
  const leaves = [...slow.nodes.keys()].filter((k) => k.startsWith("0:"));
  assert.equal(leaves.length, 30, "every long message was compacted, in order");
  slow.close();
});

test("torn lines are repaired, ids stay aligned", () => {
  freshDir();
  const day = new Date().toISOString().slice(0, 10);
  const lines = [
    { i: 0, kind: "user", text: "one", size: 8, date: "" },
    { i: 1, kind: "user", text: "two", size: 8, date: "" },
  ];
  writeFileSync(
    join(dir, "main", `${day}.jsonl`),
    lines.map((l) => JSON.stringify(l)).join("\n") + "\n",
  );
  writeFileSync(
    join(dir, "main", "1970-01-01.jsonl"),
    '{"i":2,"kind":"user","text":"th',
  ); // torn
  const chat = new OptChat(dir, fakeModel, fakeHooks());
  chat.load();
  assert.equal(chat.root.length, 2, "the torn line is skipped");
  assert.ok(
    errors.some((e) => e.includes("torn")),
    "torn lines are reported",
  );
  assert.equal(chat.root[1].i, 1, "ids stay aligned");
  chat.close();
});

test("partial compaction views restore without rewriting the chat layout", async () => {
  const chat = fresh();
  for (let i = 0; i < 3; i++) chat.log("user", `m${i}`);
  await waitFor(() => chat.nodes.has("1:0"));
  chat.view = [
    { l: 1, i: 0, start: 0, n: 2 },
    { l: 0, i: 2, start: 2, n: 1 },
  ];
  chat.cview = [{ l: 1, i: 0, start: 0, n: 2 }];
  chat.cviewUpTo = 2;
  chat.viewDirty = true;
  chat.fit();
  const rendered = chat.renderView();
  chat.close();
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(
    restored.renderView(),
    rendered,
    "restore must not fold a different layout",
  );
  assert.equal(restored.cviewUpTo, 3);
  assert.deepEqual(
    restored.cview.map((p) => [p.l, p.i]),
    [
      [1, 0],
      [0, 2],
    ],
    "keep the saved prefix and append the already-built suffix",
  );
  const saved = JSON.parse(readFileSync(join(dir, "view.json"), "utf8"));
  assert.equal(saved.cviewUpTo, 3);
  assert.deepEqual(saved.cview, [
    [1, 0],
    [0, 2],
  ]);
  assert.equal(calls, 0, "catch-up does not require new compactor calls");
  restored.close();
});

test("an empty saved compaction view catches up with no queued work", async () => {
  const chat = fresh();
  chat.log("user", "already summarized");
  await buildAll(chat);
  const rendered = chat.renderView();
  chat.close();
  const file = join(dir, "view.json");
  const saved = JSON.parse(readFileSync(file, "utf8"));
  saved.cview = [];
  saved.cviewUpTo = 0;
  writeFileSync(file, JSON.stringify(saved));
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(restored.renderView(), rendered);
  assert.equal(restored.cviewUpTo, 1);
  assert.deepEqual(
    restored.cview.map((p) => [p.l, p.i]),
    [[0, 0]],
  );
  assert.equal(restored.contextLines(1), "user: already summarized");
  assert.equal(JSON.parse(readFileSync(file, "utf8")).cviewUpTo, 1);
  restored.pump();
  await delay(10);
  assert.equal(calls, 0);
  restored.close();
});

test("restored compaction view catches up and batches to its budget", async () => {
  const budgets = { cview: 2000, cfloor: 800 };
  const chat = fresh(budgets);
  for (let i = 0; i < 20; i++)
    chat.log("user", `message ${i} ` + "y".repeat(120));
  await waitFor(() => chat.nodes.size === 38);
  const rendered = chat.renderView();
  chat.close();
  const file = join(dir, "view.json");
  const saved = JSON.parse(readFileSync(file, "utf8"));
  saved.cview = [[0, 0]];
  saved.cviewUpTo = 1;
  saved.cbatching = false;
  writeFileSync(file, JSON.stringify(saved));
  const restored = new OptChat(dir, fakeModel, fakeHooks(), budgets);
  restored.load();
  assert.equal(restored.renderView(), rendered);
  assert.equal(restored.cviewUpTo, 20);
  assert.ok(restored.cviewByteCount() <= budgets.cfloor);
  assert.equal(restored.cbatching, false);
  const persisted = JSON.parse(readFileSync(file, "utf8"));
  assert.equal(persisted.cviewUpTo, 20);
  assert.deepEqual(
    persisted.cview,
    restored.cview.map((p) => [p.l, p.i]),
  );
  assert.equal(calls, 0);
  restored.close();
});

test("restored compaction view resumes an unfinished batch below the ceiling", async () => {
  const budgets = { cview: 2000, cfloor: 800 };
  const chat = fresh(budgets);
  for (let i = 0; i < 12; i++)
    chat.log("user", `message ${i} ` + "y".repeat(120));
  await waitFor(() => chat.nodes.size === 22);
  chat.close();
  const file = join(dir, "view.json");
  const saved = JSON.parse(readFileSync(file, "utf8"));
  saved.cview = Array.from({ length: 12 }, (_, i) => [0, i]);
  saved.cviewUpTo = 12;
  saved.cbatching = true;
  writeFileSync(file, JSON.stringify(saved));
  const restored = new OptChat(dir, fakeModel, fakeHooks(), budgets);
  restored.load();
  assert.ok(restored.cviewByteCount() <= budgets.cfloor);
  assert.equal(restored.cbatching, false);
  assert.equal(JSON.parse(readFileSync(file, "utf8")).cbatching, false);
  assert.equal(calls, 0);
  restored.close();
});

test("startup catch-up stops at an unbuilt leaf and later fills the suffix", async () => {
  const chat = fresh();
  for (let i = 0; i < 3; i++) chat.log("user", `m${i}`);
  await waitFor(() => chat.nodes.size === 4);
  chat.close();
  const treeFile = join(dir, "tree", `${localDay()}.jsonl`);
  const nodes = readFileSync(treeFile, "utf8")
    .trim()
    .split("\n")
    .map(JSON.parse);
  writeFileSync(
    treeFile,
    nodes
      .filter((n) => n.l === 0 && n.i !== 1)
      .map((n) => JSON.stringify(n))
      .join("\n") + "\n",
  );
  const file = join(dir, "view.json");
  const saved = JSON.parse(readFileSync(file, "utf8"));
  saved.cview = [];
  saved.cviewUpTo = 0;
  writeFileSync(file, JSON.stringify(saved));
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(restored.cviewUpTo, 1, "do not skip the unbuilt message");
  assert.deepEqual(
    restored.cview.map((p) => [p.l, p.i]),
    [[0, 0]],
  );
  restored.pump();
  await buildAll(restored);
  assert.equal(restored.cviewUpTo, 3);
  assert.deepEqual(
    restored.cview.map((p) => [p.l, p.i]),
    [
      [0, 0],
      [0, 1],
      [0, 2],
    ],
  );
  assert.equal(calls, 0);
  restored.close();
});

test("an empty view and a null saved view are safe to load", () => {
  const chat = fresh();
  chat.close();
  const empty = new OptChat(dir, fakeModel, fakeHooks());
  empty.load();
  assert.equal(empty.renderView(), "<chat>\n\n</chat>");
  empty.close();
  writeFileSync(join(dir, "view.json"), "null");
  const corrupt = new OptChat(dir, fakeModel, fakeHooks());
  corrupt.load();
  assert.equal(corrupt.root.length, 0);
  corrupt.close();
});

test("failed main-log writes do not mutate memory or consume an id", async () => {
  const chat = fresh();
  const file = join(dir, "main", `${localDay()}.jsonl`);
  mkdirSync(file);
  assert.throws(() => chat.log("user", "not durable"));
  assert.equal(chat.root.length, 0);
  assert.equal(chat.view.length, 0);
  rmSync(file, { recursive: true });
  assert.equal(chat.log("user", "durable"), 0);
  await buildAll(chat);
  chat.close();
});

test("failed fsync rolls back a complete line before an id is reused", async () => {
  const chat = fresh();
  chat.log("user", "prior message");
  await buildAll(chat);
  const file = join(dir, "main", `${localDay()}.jsonl`);
  const prior = readFileSync(file, "utf8");
  let syncs = 0;
  await withFsFaults(
    {
      fsyncSync(original, fd) {
        if (syncs++ === 0) throw new Error("injected fsync failure");
        return original(fd);
      },
    },
    () =>
      assert.throws(() => chat.log("user", "failed message"), /injected fsync/),
  );
  assert.equal(syncs, 2, "rollback is fsynced too");
  assert.equal(
    readFileSync(file, "utf8"),
    prior,
    "prior committed lines are preserved",
  );
  assert.equal(chat.root.length, 1);
  assert.equal(chat.log("user", "replacement message"), 1);
  await buildAll(chat);
  chat.close();
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.deepEqual(
    restored.root.map((m) => m.text),
    ["prior message", "replacement message"],
  );
  assert.equal(restored.nodes.get("0:1").text, "user: replacement message");
  restored.close();
});

test("a partial write is truncated before the next append", async () => {
  const chat = fresh();
  let writes = 0;
  await withFsFaults(
    {
      writeSync(original, fd, buffer, offset, length) {
        if (writes++ === 0)
          return original(fd, buffer, offset, Math.min(7, length));
        throw new Error("injected partial-write failure");
      },
    },
    () =>
      assert.throws(() => chat.log("user", "failed message"), /partial-write/),
  );
  const file = join(dir, "main", `${localDay()}.jsonl`);
  assert.equal(readFileSync(file, "utf8"), "");
  assert.equal(chat.root.length, 0);
  chat.log("user", "replacement message");
  await buildAll(chat);
  chat.close();
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(restored.root.length, 1);
  assert.equal(
    restored.nodes.get("0:0").text,
    `user: ${restored.root[0].text}`,
  );
  restored.close();
});

test("failed rollback stops recording until reload, preventing duplicate ids", async () => {
  const chat = fresh();
  await withFsFaults(
    {
      fsyncSync() {
        throw new Error("injected fsync failure");
      },
      ftruncateSync() {
        throw new Error("injected rollback failure");
      },
    },
    () =>
      assert.throws(
        () => chat.log("user", "uncertain message"),
        UncertainAppendError,
      ),
  );
  const file = join(dir, "main", `${localDay()}.jsonl`);
  const before = readFileSync(file, "utf8");
  assert.equal(chat.root.length, 0);
  assert.throws(
    () => chat.log("user", "must not reuse id"),
    /recording stopped/,
  );
  chat.resume();
  chat.pump();
  assert.throws(() => chat.log("user", "still stopped"), /recording stopped/);
  assert.equal(readFileSync(file, "utf8"), before);
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(restored.root[0].text, "uncertain message");
  assert.equal(restored.log("user", "next message"), 1);
  await buildAll(restored);
  assert.equal(restored.nodes.get("0:0").text, "user: uncertain message");
  restored.close();
});

test("failed rollback fsync also stops recording", async () => {
  const chat = fresh();
  let syncs = 0;
  await withFsFaults(
    {
      fsyncSync() {
        syncs++;
        throw new Error("injected fsync failure");
      },
    },
    () =>
      assert.throws(
        () => chat.log("user", "uncertain message"),
        UncertainAppendError,
      ),
  );
  assert.equal(syncs, 2);
  assert.equal(chat.root.length, 0);
  assert.throws(
    () => chat.log("user", "must not reuse id"),
    /recording stopped/,
  );
});

test("close failure after a committed append cannot lead to id reuse", async () => {
  const chat = fresh();
  await withFsFaults(
    {
      closeSync(original, fd) {
        original(fd);
        throw new Error("injected close failure");
      },
    },
    () =>
      assert.throws(
        () => chat.log("user", "committed message"),
        UncertainAppendError,
      ),
  );
  assert.equal(chat.root.length, 0);
  assert.throws(
    () => chat.log("user", "must not reuse id"),
    /recording stopped/,
  );
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(restored.root[0].text, "committed message");
  assert.equal(restored.log("user", "next message"), 1);
  await buildAll(restored);
  restored.close();
});

test("failed tree fsync rolls back before the compactor retries", async () => {
  const chat = fresh({ retryMs: 20 });
  chat.log("user", "durable message");
  let syncs = 0;
  await withFsFaults(
    {
      fsyncSync(original, fd) {
        if (syncs++ === 0) throw new Error("injected tree fsync failure");
        return original(fd);
      },
    },
    async () => {
      await waitFor(() => errors.length > 0);
      assert.equal(chat.nodes.size, 0);
      const file = join(dir, "tree", `${localDay()}.jsonl`);
      assert.equal(readFileSync(file, "utf8"), "");
      await buildAll(chat);
      assert.equal(readFileSync(file, "utf8").trim().split("\n").length, 1);
    },
  );
  chat.close();
});

test("uncertain tree append stops both recording and compaction", async () => {
  const chat = fresh({ retryMs: 20 });
  chat.log("user", "durable message");
  await withFsFaults(
    {
      fsyncSync() {
        throw new Error("injected tree fsync failure");
      },
      ftruncateSync() {
        throw new Error("injected rollback failure");
      },
    },
    async () => {
      await waitFor(() =>
        errors.some((e) => e.includes("append state uncertain")),
      );
    },
  );
  assert.equal(chat.nodes.size, 0);
  assert.throws(() => chat.log("user", "stopped"), /recording stopped/);
  assert.equal(await chat.settle(), false);
  const file = join(dir, "tree", `${localDay()}.jsonl`);
  const before = readFileSync(file, "utf8");
  await delay(100);
  assert.equal(
    readFileSync(file, "utf8"),
    before,
    "no automatic retries after unsafe rollback",
  );
  const restored = new OptChat(dir, fakeModel, fakeHooks());
  restored.load();
  assert.equal(
    restored.nodes.get("0:0").text,
    `user: ${restored.root[0].text}`,
  );
  restored.close();
});

test("failed tree writes leave nodes unbuilt and retry durably", async () => {
  const chat = fresh({ retryMs: 20 });
  const file = join(dir, "tree", `${localDay()}.jsonl`);
  mkdirSync(file);
  chat.log("user", "durable message");
  await waitFor(() => errors.length > 0);
  assert.equal(chat.nodes.size, 0);
  rmSync(file, { recursive: true });
  await buildAll(chat);
  assert.equal(
    JSON.parse(readFileSync(file, "utf8")).text,
    "user: durable message",
  );
  chat.close();
});

test("failed view saves remain dirty and can be retried", () => {
  const chat = fresh();
  const file = join(dir, "view.json");
  rmSync(file);
  mkdirSync(file);
  chat.log("user", "message");
  assert.ok(chat.viewDirty);
  rmSync(file, { recursive: true });
  chat.fit();
  assert.equal(JSON.parse(readFileSync(file, "utf8")).view.length, 1);
  assert.ok(!chat.viewDirty);
  chat.close();
});

test("unreadable logs fail rather than pretending memory is empty", () => {
  freshDir();
  mkdirSync(join(dir, "main", "broken.jsonl"));
  assert.throws(() => loadJsonl(join(dir, "main")));
});

test("image attachments preserve binary bytes", () => {
  freshDir();
  const bytes = Buffer.from([0, 255, 13, 10, 37, 128]);
  const rel = saveImage(dir, 3, 0, bytes.toString("base64"), "image/png");
  assert.equal(rel, "images/3-0.png");
  assert.deepEqual(readFileSync(join(dir, rel)), bytes);
});

test("settle cancellation removes waiters, including an already aborted signal", async () => {
  const chat = fresh();
  chat.root.push({ i: 0, kind: "user", text: "pending", size: 7, date: "" });
  chat.view.push({ l: 0, i: 0, start: 0, n: 1 });
  const controller = new AbortController();
  const pending = chat.settle(controller.signal);
  assert.equal(chat.waiters.length, 1);
  controller.abort();
  assert.equal(await pending, false);
  assert.equal(chat.waiters.length, 0);
  assert.equal(await chat.settle(controller.signal), false);
  chat.close();
});

test("compactor context excludes messages after its task and stays bounded", () => {
  const chat = fresh({ cview: 50 });
  for (let i = 0; i < 4; i++) {
    chat.nodes.set(`0:${i}`, { l: 0, i, text: `message-${i}`, size: 9 });
  }
  chat.nodes.set("1:0", { l: 1, i: 0, text: "message-0 message-1", size: 19 });
  chat.nodes.set("1:1", { l: 1, i: 1, text: "message-2 message-3", size: 19 });
  chat.nodes.set("2:0", {
    l: 2,
    i: 0,
    text: "all four, including future",
    size: 26,
  });
  chat.cview = [{ l: 2, i: 0, start: 0, n: 4 }];
  assert.equal(chat.contextLines(3), "message-0 message-1\nmessage-2");
  chat.cview = Array.from({ length: 4 }, (_, i) => ({
    l: 0,
    i,
    start: i,
    n: 1,
  }));
  chat.nodes.get("0:0").text = "x".repeat(80);
  assert.ok(byteLength(chat.contextLines(4)) <= 50);
  chat.close();
});

test("persistent oversized replies never become oversized nodes", async () => {
  const chat = fresh({ retryMs: 50 });
  plan = Array.from({ length: 5 }, () => "z".repeat(600));
  chat.log("user", "w".repeat(600));
  await waitFor(() => errors.length > 0);
  assert.equal(chat.nodes.size, 0);
  assert.ok(!chat.isPaused(), "length failures are not quota failures");
  await buildAll(chat);
  assert.ok([...chat.nodes.values()].every((n) => n.size <= 512));
  chat.close();
});

test("the ruler is 512 dashes and the limit stays 512 bytes", () => {
  assert.equal(RULER, "-".repeat(512));
  assert.equal(RULER.length, NODE);
});

let failed = 0;
for (const [name, fn] of tests) {
  try {
    await fn();
    console.log(`PASS ${name}`);
  } catch (err) {
    failed++;
    console.log(`FAIL ${name}\n     ${err.message}`);
  } finally {
    if (dir) rmSync(dir, { recursive: true, force: true });
  }
}
console.log(
  failed === 0
    ? `\n${tests.length} tests passed`
    : `\n${failed} of ${tests.length} tests FAILED`,
);
process.exit(failed === 0 ? 0 : 1);
