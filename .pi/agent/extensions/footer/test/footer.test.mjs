/** node test/footer.test.mjs /path/to/@earendil-works/pi-coding-agent */
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { test } from "node:test";

const pkg = process.argv[2];
assert.ok(pkg, "pass the installed pi-coding-agent package directory");
const load = (path) => import(pathToFileURL(join(pkg, path)));
const { loadExtensions } = await load("dist/core/extensions/loader.js");
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

async function fixture(mode = "tui") {
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
  const ctx = {
    mode,
    get model() {
      return state.model;
    },
    get thinkingLevel() {
      return state.thinkingLevel;
    },
    getContextUsage: () => state.context,
    sessionManager: manager,
    modelRegistry: {
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
    },
  };
  const loaded = await loadExtensions([entry], process.cwd());
  assert.deepEqual(loaded.errors, []);
  const extension = loaded.extensions[0];
  loaded.runtime.getSettings = () => state.settings;
  async function emit(type) {
    for (const handler of extension.handlers.get(type) ?? [])
      await handler({ type }, ctx);
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
  return { state, ctx, extension, emit, compare };
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

test("noninteractive modes leave the footer alone", async () => {
  for (const mode of ["rpc", "json", "print"]) {
    const f = await fixture(mode);
    assert.equal(f.state.component, undefined);
    await f.extension.commands.get("footer").handler("", f.ctx);
    assert.equal(f.state.component, undefined);
    await f.emit("session_shutdown");
  }
});
