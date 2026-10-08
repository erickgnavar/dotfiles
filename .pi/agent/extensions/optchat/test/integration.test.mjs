/** Installed pi loader/API regression tests; all model streams are mocked.
 * node test/integration.test.mjs /path/to/@earendil-works/pi-coding-agent
 */
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { setTimeout as delay } from "node:timers/promises";

const pkg = process.argv[2];
assert.ok(pkg, "pass the installed pi-coding-agent package directory");
const { loadExtensions } = await import(
  pathToFileURL(join(pkg, "dist/core/extensions/loader.js"))
);
const { ModelRegistry } = await import(
  pathToFileURL(join(pkg, "dist/core/model-registry.js"))
);
const { AssistantMessageEventStream } = await import(
  pathToFileURL(
    join(pkg, "node_modules/@earendil-works/pi-ai/dist/utils/event-stream.js"),
  )
);
const entry = join(dirname(fileURLToPath(import.meta.url)), "../index.ts");
const model = {
  provider: "openai-codex",
  id: "subscription-model",
  api: "openai-codex-responses",
};
const savedEnv = Object.fromEntries(
  ["OPTCHAT_DIR", "OPTCHAT_DISABLE", "OPTCHAT_MODEL"].map((key) => [
    key,
    process.env[key],
  ]),
);
for (const key of Object.keys(savedEnv)) delete process.env[key];

const reply = (text) => ({
  role: "assistant",
  content: [{ type: "text", text }],
  api: model.api,
  provider: model.provider,
  model: model.id,
  timestamp: Date.now(),
  stopReason: "stop",
  usage: { input: 100, output: 10, cacheRead: 200, cacheWrite: 0 },
});

async function waitFor(predicate) {
  const deadline = Date.now() + 5000;
  while (!predicate() && Date.now() < deadline) await delay(5);
  assert.ok(predicate(), "background compactions finish");
}

async function start(
  cwd,
  respond = () => reply("user: summarized " + "x".repeat(300)),
) {
  const notices = [];
  const calls = [];
  const controller = new AbortController();
  const registry = new ModelRegistry({
    getModel: () => undefined,
    streamSimple(selected, context, options) {
      assert.equal(
        selected,
        model,
        "use the session model, including subscription auth",
      );
      assert.equal(options.reasoning, "low");
      assert.equal(options.maxTokens, 8192);
      calls.push({ context, options });
      const stream = new AssistantMessageEventStream();
      setImmediate(() => stream.end(respond(context, options)));
      return stream;
    },
  });
  const ctx = {
    cwd,
    model,
    modelRegistry: registry,
    signal: controller.signal,
    ui: { notify: (message, type) => notices.push({ message, type }) },
  };
  const loaded = await loadExtensions([entry], cwd);
  assert.deepEqual(loaded.errors, []);
  const extension = loaded.extensions[0];
  async function emit(type, event = {}) {
    let result;
    for (const handler of extension.handlers.get(type) ?? []) {
      result = (await handler({ type, ...event }, ctx)) ?? result;
    }
    return result;
  }
  await emit("session_start", { reason: "startup" });
  return { emit, ctx, calls, notices, extension, controller };
}

async function check(name, run) {
  const cwd = mkdtempSync(join(tmpdir(), "optchat-integration-"));
  const sessions = [];
  try {
    await run(cwd, async (respond) => {
      const session = await start(cwd, respond);
      sessions.push(session);
      return session;
    });
    console.log(`PASS ${name}`);
  } finally {
    for (const session of sessions) await session.emit("session_shutdown");
    rmSync(cwd, { recursive: true, force: true });
  }
}

try {
  await check(
    "non-free leaves/merge, frozen context, images, and cache counters",
    async (cwd, open) => {
      const session = await open((context) =>
        reply(
          context.messages[0].content[1].text.includes("merge lines")
            ? "user: merged both messages"
            : "user: summarized " + "x".repeat(300),
        ),
      );
      for (let i = 0; i < 2; i++) {
        await session.emit("message_end", {
          message: {
            role: "user",
            content: `message ${i} ` + "w".repeat(700),
            timestamp: i,
          },
        });
      }
      const tree = join(cwd, ".pi/optchat/tree");
      await waitFor(() =>
        readdirSync(tree).some((f) =>
          readFileSync(join(tree, f), "utf8").includes('"l":1'),
        ),
      );
      assert.equal(
        session.calls.length,
        3,
        "two non-free leaves and one non-free merge",
      );
      const before = {
        prompt: "new turn",
        systemPromptOptions: { sections: {} },
      };
      await session.emit("before_agent_start", before);
      assert.ok(before.systemPromptOptions.sections.optchat);
      const current = { role: "user", content: "new turn", timestamp: 99 };
      await session.emit("message_end", { message: current });
      const messages = [
        { role: "user", content: "old turn", timestamp: 1 },
        reply("old reply"),
        current,
      ];
      const first = await session.emit("context", { messages });
      assert.equal(first.messages.length, 2);
      assert.equal(first.messages[1], current);
      const frozen = first.messages[0].content[0].text;
      assert.ok(!frozen.includes("new turn"));
      const assistant = reply("new reply");
      await session.emit("message_end", { message: assistant });
      const next = await session.emit("context", {
        messages: [...messages, assistant],
      });
      assert.equal(next.messages[0].content[0].text, frozen);
      assert.equal(next.messages[2], assistant);
      await session.extension.commands.get("optchat").handler("", session.ctx);
      assert.ok(
        session.notices.some((n) =>
          n.message.includes("chat 200/300, compactor 600/900"),
        ),
      );
      const image = {
        type: "image",
        data: Buffer.from([0, 255, 1]).toString("base64"),
        mimeType: "image/png",
      };
      await session.emit("tool_execution_end", {
        result: { content: [image] },
        isError: false,
      });
      const images = join(cwd, ".pi/optchat/images");
      assert.deepEqual(
        readFileSync(join(images, readdirSync(images)[0])),
        Buffer.from([0, 255, 1]),
      );
      assert.ok(!session.notices.some((n) => n.type === "error"));
    },
  );

  await check(
    "idle context keeps the frozen view and original turn boundary",
    async (cwd, open) => {
      const session = await open();
      const prior = { role: "user", content: "old turn", timestamp: 1 };
      const priorReply = reply("old reply");
      for (const message of [prior, priorReply]) {
        await session.emit("message_end", { message });
      }
      const viewFile = join(cwd, ".pi/optchat/view.json");
      await waitFor(
        () => JSON.parse(readFileSync(viewFile, "utf8")).cviewUpTo === 2,
      );
      assert.equal(
        await session.emit("context", { messages: [prior, priorReply] }),
        undefined,
      );
      await session.emit("before_agent_start", {
        prompt: "first question",
        systemPromptOptions: { sections: {} },
      });
      const question = {
        role: "user",
        content: "first question",
        timestamp: 10,
      };
      await session.emit("message_end", { message: question });
      const initial = await session.emit("context", {
        messages: [prior, priorReply, question],
      });
      const frozen = initial.messages[0].content[0].text;
      const firstReply = reply("first reply");
      const steering = {
        role: "user",
        content: "steering message",
        timestamp: 11,
      };
      const finalReply = reply("final reply");
      for (const message of [firstReply, steering, finalReply]) {
        await session.emit("message_end", { message });
      }
      const messages = [
        prior,
        priorReply,
        question,
        firstReply,
        steering,
        finalReply,
      ];
      const active = await session.emit("context", { messages });
      assert.equal(active.messages[0].content[0].text, frozen);
      assert.deepEqual(active.messages.slice(1), messages.slice(2));
      await session.emit("agent_end");
      await waitFor(
        () => JSON.parse(readFileSync(viewFile, "utf8")).cviewUpTo === 6,
      );
      assert.deepEqual(await session.emit("context", { messages }), active);
      await session.extension.commands
        .get("optchat")
        .handler("note idle note", session.ctx);
      await waitFor(
        () => JSON.parse(readFileSync(viewFile, "utf8")).cviewUpTo === 7,
      );
      assert.deepEqual(await session.emit("context", { messages }), active);
      assert.deepEqual(
        await session.emit("context", { messages: messages.slice(1) }),
        active,
        "find the original anchor if transcript indices change",
      );
      assert.equal(
        await session.emit("context", {
          messages: messages.filter((m) => m !== question),
        }),
        undefined,
        "do not substitute a later user message if the anchor disappears",
      );
      assert.deepEqual(await session.emit("context", { messages }), active);
      await session.emit("before_agent_start", {
        prompt: "next question",
        systemPromptOptions: { sections: {} },
      });
      const nextQuestion = {
        role: "user",
        content: "next question",
        timestamp: 20,
      };
      await session.emit("message_end", { message: nextQuestion });
      const next = await session.emit("context", {
        messages: [...messages, nextQuestion],
      });
      const updated = next.messages[0].content[0].text;
      assert.notEqual(updated, frozen);
      assert.ok(
        updated.includes("first question") &&
          updated.includes("steering message"),
      );
      assert.ok(
        updated.includes("idle note") && !updated.includes("next question"),
      );
      assert.deepEqual(next.messages.slice(1), [nextQuestion]);
    },
  );

  await check(
    "quota failure keeps the original transcript, including idle requests after recovery",
    async (cwd, open) => {
      let fail = true;
      const session = await open(() => {
        if (fail) {
          fail = false;
          return {
            ...reply(""),
            stopReason: "error",
            errorMessage: "429: Go usage limit exceeded",
          };
        }
        return reply("user: recovered summary");
      });
      await session.emit("message_end", {
        message: { role: "user", content: "w".repeat(700), timestamp: 1 },
      });
      await waitFor(() =>
        session.notices.some((n) => n.message.includes("paused")),
      );
      await session.emit("before_agent_start", {
        prompt: "keep working",
        systemPromptOptions: { sections: {} },
      });
      assert.equal(
        await session.emit("context", {
          messages: [{ role: "user", content: "keep working", timestamp: 2 }],
        }),
        undefined,
      );
      assert.ok(
        session.notices.some((n) =>
          n.message.includes("keeping pi's transcript"),
        ),
      );
      assert.equal(session.calls.length, 1);
      const fallback = { role: "user", content: "keep working", timestamp: 2 };
      await session.emit("message_end", { message: fallback });
      await session.emit("agent_end");
      await session.extension.commands
        .get("optchat")
        .handler("resume", session.ctx);
      const viewFile = join(cwd, ".pi/optchat/view.json");
      await waitFor(
        () => JSON.parse(readFileSync(viewFile, "utf8")).cviewUpTo === 2,
      );
      assert.equal(
        await session.emit("context", { messages: [fallback] }),
        undefined,
      );
      await session.emit("before_agent_start", {
        prompt: "next turn",
        systemPromptOptions: { sections: {} },
      });
      const nextUser = { role: "user", content: "next turn", timestamp: 3 };
      await session.emit("message_end", { message: nextUser });
      const next = await session.emit("context", {
        messages: [fallback, nextUser],
      });
      assert.ok(next.messages[0].content[0].text.includes("recovered summary"));
      assert.deepEqual(next.messages.slice(1), [nextUser]);
    },
  );

  await check(
    "a second writer is rejected and shutdown releases the lock",
    async (cwd, open) => {
      const first = await open();
      const second = await open();
      assert.ok(
        second.notices.some((n) => n.message.includes("another pi process")),
      );
      await first.emit("session_shutdown");
      const third = await open();
      assert.ok(!third.notices.some((n) => n.type === "error"));
      assert.ok(readFileSync(join(cwd, ".pi/optchat/view.json"), "utf8"));
    },
  );

  console.log("\n4 integration tests passed");
} finally {
  for (const [key, value] of Object.entries(savedEnv)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}
