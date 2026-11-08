/** node test/footer.test.mjs /path/to/@earendil-works/pi-coding-agent */
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdirSync, mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const pkg = process.argv[2];
assert.ok(pkg, "pass the installed pi-coding-agent package directory");
const load = (path) => import(pathToFileURL(join(pkg, path)));
const { loadExtensions } = await load("dist/core/extensions/loader.js");
const { createEventBus } = await load("dist/core/event-bus.js");
const { FooterComponent } = await load(
  "dist/modes/interactive/components/footer.js",
);
const themes = await load("dist/modes/interactive/theme/theme.js");
const require = createRequire(join(pkg, "package.json"));
const { visibleWidth } = await import(
  pathToFileURL(require.resolve("@earendil-works/pi-tui"))
);
const entry = join(dirname(fileURLToPath(import.meta.url)), "../index.ts");
const usage = (n = 1) => ({
  input: 1000 * n,
  output: 200 * n,
  cacheRead: 3000 * n,
  cacheWrite: 500 * n,
  cost: { total: 0.01 * n },
});
const assistant = (n = 1) => ({
  type: "message",
  message: { role: "assistant", usage: usage(n) },
});

async function fixture(mode = "tui", paths = [entry], cwd = process.cwd()) {
  themes.initTheme("dark");
  const state = {
    model: {
      provider: "test",
      id: "model",
      reasoning: true,
      contextWindow: 200000,
    },
    thinkingLevel: "high",
    entries: [assistant()],
    leaf: "leaf-1",
    name: "footer test",
    branch: "main",
    context: { tokens: 10000, contextWindow: 200000, percent: 5 },
    providers: 2,
    subscription: false,
    settings: {},
    renders: 0,
    watchers: new Set(),
    statuses: new Map(),
    component: undefined,
  };
  const manager = {
    getCwd: () => join(process.env.HOME, "projects", "界面"),
    getSessionId: () => "session",
    getLeafId: () => state.leaf,
    getEntries: () => [...state.entries],
    getSessionName: () => state.name,
  };
  const data = {
    getGitBranch: () => state.branch,
    getAvailableProviderCount: () => state.providers,
    getExtensionStatuses: () => state.statuses,
    onBranchChange(callback) {
      state.watchers.add(callback);
      return () => state.watchers.delete(callback);
    },
  };
  const compactModel = { provider: "other", id: "compact" };
  const ctx = {
    mode,
    cwd,
    hasUI: mode === "tui" || mode === "rpc",
    get model() {
      return state.model;
    },
    get thinkingLevel() {
      return state.thinkingLevel;
    },
    getContextUsage: () => state.context,
    sessionManager: manager,
    modelRegistry: {
      getAvailable: () => [state.model, compactModel],
      find: (provider, id) =>
        [state.model, compactModel].find(
          (model) => model?.provider === provider && model.id === id,
        ),
      isUsingOAuth: () => state.subscription,
      getProvider: () => ({
        auth: { oauth: { isSubscription: state.subscription } },
      }),
    },
    ui: {
      setFooter(factory) {
        state.component?.dispose();
        state.component = factory?.(
          { requestRender: () => state.renders++ },
          themes.theme,
          data,
        );
      },
      notify() {},
      select: async () => state.choice,
    },
  };
  const events = createEventBus();
  const loaded = await loadExtensions(paths, cwd, events);
  assert.deepEqual(loaded.errors, []);
  const extension = loaded.extensions.find((item) =>
    item.commands.has("footer"),
  );
  loaded.runtime.getSettings = () => state.settings;
  async function emit(type, event = {}) {
    for (const item of loaded.extensions)
      for (const handler of item.handlers.get(type) ?? [])
        await handler({ type, ...event }, ctx);
  }
  // The loader's API forwards settings through its runtime, like pi's runner.
  await emit("session_start");
  function original() {
    const model = state.model;
    const session = {
      state,
      model,
      sessionManager: { ...manager, getEntryCount: () => state.entries.length },
      getContextUsage: ctx.getContextUsage,
      modelRuntime: { isUsingSubscription: () => state.subscription },
    };
    const footer = new FooterComponent(session, data);
    footer.setAutoCompactEnabled(state.settings.compaction?.enabled ?? true);
    return footer;
  }
  function compare() {
    const builtin = original();
    for (const width of [0, 1, 2, 3, 10, 20, 40, 80, 120, 240]) {
      const actual = state.component.render(width);
      assert.deepEqual(
        actual,
        builtin.render(width),
        `same output at width ${width}`,
      );
      for (const line of actual) assert.ok(visibleWidth(line) <= width);
    }
  }
  return { state, ctx, extension, emit, compare, events, loaded };
}

test("standalone replica matches default across narrow widths and Unicode", async () => {
  const f = await fixture();
  f.compare();
  f.state.model.id = "模型-🦊-é";
  f.state.statuses = new Map([
    ["z", "last\nstatus"],
    ["a", "\u001b[32mfirst\u001b[0m\tstatus"],
  ]);
  f.compare();
  assert.equal(f.state.watchers.size, 1);
  await f.emit("session_shutdown");
  assert.equal(f.state.watchers.size, 0);
});

test("all usage sources, cache rates, context warnings and settings match", async () => {
  const f = await fixture();
  f.state.entries.push(
    { type: "usage", usage: usage(2) },
    { type: "message", message: { role: "toolResult", usage: usage(3) } },
    { type: "branch_summary", usage: usage(4) },
    { type: "compaction", usage: usage(5) },
    assistant(6),
  );
  f.state.leaf = "leaf-2";
  for (const percent of [null, 0, 70, 70.1, 90, 90.1]) {
    f.state.context = { tokens: null, contextWindow: 200000, percent };
    f.compare();
  }
  f.state.context = undefined;
  f.state.settings = { compaction: { enabled: false } };
  f.compare();
  f.state.entries = [];
  f.state.name = undefined;
  f.state.branch = null;
  f.compare();
  await f.emit("session_shutdown");
});

test("subscription labels, thinking off, model and theme changes match", async () => {
  const f = await fixture();
  f.state.subscription = true;
  f.compare();
  f.state.thinkingLevel = "off";
  await f.emit("thinking_level_select");
  assert.equal(f.state.renders, 1);
  f.compare();
  f.state.model = {
    provider: "kimi-coding",
    id: "kimi",
    contextWindow: 256000,
  };
  f.state.subscription = false;
  await f.emit("model_select");
  assert.equal(f.state.renders, 2);
  f.compare();
  themes.initTheme("light");
  f.state.component.invalidate();
  f.compare();
  f.state.model = undefined;
  f.compare();
  await f.emit("session_shutdown");
});

test("experimental marker matches", async () => {
  const saved = process.env.PI_EXPERIMENTAL;
  process.env.PI_EXPERIMENTAL = "1";
  try {
    const f = await fixture();
    f.compare();
    await f.emit("session_shutdown");
  } finally {
    if (saved === undefined) delete process.env.PI_EXPERIMENTAL;
    else process.env.PI_EXPERIMENTAL = saved;
  }
});

test("toggle restores default, branch callbacks render, and reload cleans up", async () => {
  const f = await fixture();
  for (const callback of f.state.watchers) callback();
  assert.equal(f.state.renders, 1);
  const toggle = () => f.extension.commands.get("footer").handler("", f.ctx);
  await toggle();
  assert.equal(f.state.component, undefined);
  assert.equal(f.state.watchers.size, 0);
  await toggle();
  f.compare();
  assert.equal(f.state.watchers.size, 1);
  await f.emit("session_shutdown");
  assert.equal(f.state.watchers.size, 0);
  await f.emit("session_start");
  f.compare();
  assert.equal(f.state.watchers.size, 1);
  await f.emit("session_shutdown");
});

test("model suffixes follow effort, fit narrow widths, and survive toggling", async () => {
  const f = await fixture();
  const publish = (text) =>
    f.events.emit("footer:model-suffix", { id: "test", text });
  publish("compact");
  assert.equal(f.state.renders, 1);
  assert.match(
    f.state.component.render(240)[1],
    /model • high • compact\u001b/,
  );
  f.state.thinkingLevel = "off";
  assert.match(
    f.state.component.render(240)[1],
    /model • thinking off • compact\u001b/,
  );
  f.state.model.reasoning = false;
  assert.match(f.state.component.render(240)[1], /model • compact\u001b/);
  publish("模型-🦊".repeat(20));
  for (const width of [0, 1, 10, 40, 80, 120])
    for (const line of f.state.component.render(width))
      assert.ok(visibleWidth(line) <= width);
  await f.extension.commands.get("footer").handler("", f.ctx);
  publish("updated while hidden");
  await f.extension.commands.get("footer").handler("", f.ctx);
  assert.match(
    f.state.component.render(240)[1],
    /model • updated while hidden\u001b/,
  );
  for (const invalid of [null, {}, { id: "test", text: 42 }])
    f.events.emit("footer:model-suffix", invalid);
  assert.match(f.state.component.render(240)[1], /updated while hidden/);
  publish(undefined);
  f.compare();
  await f.emit("session_shutdown");
});

test("OptChat publishes and clears its compactor in either startup order", async () => {
  const optchatPath = join(dirname(entry), "../optchat/index.ts");
  const keys = ["OPTCHAT_DIR", "OPTCHAT_DISABLE", "OPTCHAT_MODEL"];
  const saved = keys.map((key) => process.env[key]);
  for (const key of keys) delete process.env[key];
  try {
    for (const paths of [
      [entry, optchatPath],
      [optchatPath, entry],
    ]) {
      const cwd = mkdtempSync(join(tmpdir(), "footer-optchat-test-"));
      let f;
      try {
        f = await fixture("tui", paths, cwd);
        const optchat = f.loaded.extensions.find((item) =>
          item.commands.has("optchat"),
        );
        assert.match(
          f.state.component.render(240)[1],
          /model • high • \(optchat compactor\) model\u001b/,
        );
        f.state.choice = "other/compact";
        await optchat.commands.get("optchat").handler("model", f.ctx);
        assert.match(
          f.state.component.render(240)[1],
          /model • high • \(optchat compactor\) compact\u001b/,
        );
        f.state.model = { ...f.state.model, id: "new-inference" };
        f.state.thinkingLevel = "low";
        await f.emit("model_select");
        assert.match(
          f.state.component.render(240)[1],
          /new-inference • low • \(optchat compactor\) compact\u001b/,
        );

        // A recording failure must remove a suffix that is no longer active.
        await f.emit("message_end", {
          message: { role: "user", content: "first", timestamp: 1 },
        });
        const main = join(cwd, ".pi/optchat/main");
        const log = join(main, readdirSync(main)[0]);
        rmSync(log);
        mkdirSync(log);
        await f.emit("message_end", {
          message: { role: "user", content: "cannot append", timestamp: 2 },
        });
        f.compare();
      } finally {
        await f?.emit("session_shutdown");
        rmSync(cwd, { recursive: true, force: true });
      }
    }
    process.env.OPTCHAT_DISABLE = "1";
    const f = await fixture("tui", [optchatPath, entry]);
    f.compare();
    await f.emit("session_shutdown");
  } finally {
    keys.forEach((key, i) => {
      if (saved[i] === undefined) delete process.env[key];
      else process.env[key] = saved[i];
    });
  }
});

test("noninteractive modes leave the footer alone", async () => {
  for (const mode of ["rpc", "json", "print"]) {
    const f = await fixture(mode);
    assert.equal(f.state.component, undefined);
    await f.extension.commands.get("footer").handler("", f.ctx);
    assert.equal(f.state.component, undefined);
    await f.emit("session_shutdown");
  }
});
