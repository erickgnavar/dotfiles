// Run the real QML handlers with a PAM mock that keeps responseRequired true
// after respond(), matching Quickshell's implementation.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const qml = fs.readFileSync(path.join(__dirname, "..", "shell.qml"), "utf8");
function body(marker) {
  const start = qml.indexOf("{", qml.indexOf(marker));
  assert(qml.includes(marker), `Missing handler: ${marker}`);
  let depth = 1;
  let end = start + 1;
  for (; depth && end < qml.length; end++) {
    if (qml[end] === "{") depth++;
    if (qml[end] === "}") depth--;
  }
  assert.equal(depth, 0);
  return qml.slice(start + 1, end - 1);
}

function createState() {
  const context = {
    pendingPassword: "",
    firstResponse: false,
    waitingForPam: false,
    failed: false,
    unlocked: false,
    status: "Enter your password",
    responses: [],
    clears: 0,
    rejections: 0,
    finishes: 0,
    clearInputs() {
      context.clears++;
    },
    rejected() {
      context.rejections++;
    },
    typed() {},
    PamResult: { Success: 0, Error: 1, Failure: 2 },
  };
  context.shell = context;
  context.finish = {
    start() {
      context.finishes++;
    },
  };
  context.pam = {
    active: false,
    responseRequired: false,
    responseVisible: false,
    start() {
      this.active = true;
      return true;
    },
    respond(value) {
      context.responses.push(value);
    },
  };
  context.respond = (value) => context.pam.respond(value);
  Object.defineProperty(context, "busy", {
    get() {
      return vm.runInContext(
        qml.match(/readonly property bool busy: (.*)/)[1],
        context,
      );
    },
  });
  vm.createContext(context);
  context.submit = (password) => {
    context.password = password;
    vm.runInContext(
      `(() => { ${body("function submit(password)")} })()`,
      context,
    );
  };
  context.sendMessage = (
    responseRequired,
    responseVisible = false,
    message = "Password:",
  ) => {
    Object.assign(context.pam, { responseRequired, responseVisible });
    Object.assign(context, { responseRequired, responseVisible, message });
    vm.runInContext(`(() => { ${body("onPamMessage:")} })()`, context);
  };
  context.complete = (result) => {
    context.pam.active = false;
    context.pam.responseRequired = false;
    context.result = result;
    vm.runInContext(
      `(() => { ${body("onCompleted: function (result)")} })()`,
      context,
    );
  };
  return context;
}

const securityContext = vm.createContext({
  lock: { secure: false },
  shell: { unlocked: false },
});
function querySecureState() {
  return vm.runInContext(
    `(() => { ${body("function isSecure(): bool")} })()`,
    securityContext,
  );
}
assert.equal(querySecureState(), false);
securityContext.lock.secure = true;
assert.equal(querySecureState(), true);
securityContext.shell.unlocked = true;
assert.equal(querySecureState(), false);
securityContext.lock.secure = false;
assert.equal(querySecureState(), false);

const startupContext = vm.createContext({
  secure: false,
  ready: { running: false },
  Quickshell: {
    env() {
      return "ready-marker";
    },
  },
});
function handleSecureChange() {
  vm.runInContext(`(() => { ${body("onSecureChanged:")} })()`, startupContext);
}
handleSecureChange();
assert.equal(startupContext.ready.running, false);
startupContext.secure = true;
handleSecureChange();
assert.equal(startupContext.ready.running, true);
assert(/command: \["bash", "-c", [^\n]*\n\s*running: true/.test(qml));
assert(qml.includes("if (source && lock.secure)"));
const mediaActiveExpression = qml.match(
  /active: (lock.secure && shell.videoPath !== "")/,
)[1];
for (const [secure, videoPath, expected] of [
  [false, "", false],
  [false, "/tmp/video.mp4", false],
  [true, "", false],
  [true, "/tmp/video.mp4", true],
]) {
  assert.equal(
    vm.runInNewContext(mediaActiveExpression, {
      lock: { secure },
      shell: { videoPath },
    }),
    expected,
  );
}
assert(qml.includes("precision: SystemClock.Minutes"));
assert.equal(
  (qml.match(/Qt.formatDateTime\(systemClock.date,/g) || []).length,
  2,
);

// Keep the input focused and hidden except for explicitly visible PAM responses.
const showResponseExpression = qml.match(
  /readonly property bool showResponse: (.*)/,
)[1];
const inputOpacity = qml.match(/opacity: (showResponse \? 1 : 0)/)[1];
for (const [active, responseRequired, responseVisible, expected] of [
  [false, false, false, 0],
  [true, true, false, 0],
  [true, true, true, 1],
  [true, false, true, 0],
]) {
  const showResponse = vm.runInNewContext(showResponseExpression, {
    pam: { active, responseRequired, responseVisible },
  });
  assert.equal(vm.runInNewContext(inputOpacity, { showResponse }), expected);
}
assert(qml.includes("anchors.topMargin: showResponse ? 16 : 0"));
assert(qml.includes("height: showResponse ? 48 : 0"));
assert(
  qml.includes(
    "echoMode: showResponse ? TextInput.Normal : TextInput.Password",
  ),
);
assert(qml.includes("focus: true"));

// Preserve special filenames and reject incomplete, non-null-terminated output.
const selectedVideo = "/tmp/space # & ' ü\n.MP4";
for (const [text, expected] of [
  ["", ""],
  [selectedVideo, ""],
  [selectedVideo + "\u0000", selectedVideo],
]) {
  const selectionContext = vm.createContext({ text, shell: { videoPath: "" } });
  vm.runInContext(qml.match(/onStreamFinished: (.*)/)[1], selectionContext);
  assert.equal(selectionContext.shell.videoPath, expected);
}

// Fade in only after a frame with valid dimensions reaches the video sink.
const videoContext = vm.createContext({
  video: { hasFrame: false, videoSink: { videoSize: { width: 0, height: 0 } } },
});
function receiveVideoFrame() {
  vm.runInContext(
    `(() => { ${body("function onVideoFrameChanged()")} })()`,
    videoContext,
  );
}
receiveVideoFrame();
assert.equal(videoContext.video.hasFrame, false);
videoContext.video.videoSink.videoSize.height = 1080;
receiveVideoFrame();
assert.equal(videoContext.video.hasFrame, false);
videoContext.video.videoSink.videoSize.width = 1920;
receiveVideoFrame();
assert.equal(videoContext.video.hasFrame, true);
assert(qml.includes("enabled: !video.hasFrame"));
assert(qml.includes("opacity: hasFrame ? 1 : 0"));
assert(qml.includes('GradientStop { position: 0; color: "#253b4c" }'));
assert(
  qml.includes(
    "text: shell.status\n                        textFormat: Text.PlainText",
  ),
);

const videoWarnings = [];
const videoErrorContext = vm.createContext({
  error: 1,
  errorString: "Unsupported video",
  console: {
    warn(...details) {
      videoWarnings.push(details);
    },
  },
});
vm.runInContext(
  `(() => { ${body("onErrorOccurred: function (error, errorString)")} })()`,
  videoErrorContext,
);
assert.deepEqual(videoWarnings, [
  ["Lockscreen video playback failed:", 1, "Unsupported video"],
]);

let state = createState();
state.submit("secret");
assert(state.busy);
state.submit("duplicate");
assert.equal(state.pendingPassword, "secret");
state.sendMessage(true);
assert.deepEqual(state.responses, ["secret"]);
assert.equal(state.pendingPassword, "");
assert(state.pam.responseRequired); // Quickshell does not clear this on respond().
assert(state.busy);
state.submit("duplicate");
assert.deepEqual(state.responses, ["secret"]);
state.sendMessage(false, false, "Checking credentials");
assert(state.busy);
state.complete(state.PamResult.Failure);
assert(!state.busy && state.failed);
vm.runInContext(`(() => { ${body("onTextEdited:")} })()`, state);
assert(!state.failed);
assert.equal(state.status, "Enter your password");
state.submit("retry");
state.sendMessage(true);
state.complete(state.PamResult.Success);
assert(state.busy && state.unlocked);
assert.equal(state.finishes, 1);
state.submit("after success");
assert.deepEqual(state.responses, ["secret", "retry"]);

state = createState();
state.submit("password");
state.sendMessage(true);
state.sendMessage(true, false, "OTP:");
assert(!state.busy);
state.submit("123456");
assert(state.busy);
state.submit("duplicate OTP");
assert.deepEqual(state.responses, ["password", "123456"]);
state.sendMessage(true, false, "Optional response:");
state.submit("");
assert.deepEqual(state.responses, ["password", "123456", ""]);

state = createState();
state.submit("secret");
state.sendMessage(true, true, "Username:");
assert.equal(state.pendingPassword, "");
assert(!state.busy);
assert.deepEqual(state.responses, []); // Never echo the cached password.
state.submit("user");
assert.deepEqual(state.responses, ["user"]);

state = createState();
state.pam.start = () => false;
state.submit("secret");
assert(!state.busy && state.failed);
assert.equal(state.pendingPassword, "");
assert.equal(state.rejections, 1);
state = createState();
state.submit("");
assert(!state.busy && !state.pam.active);
state.submit("secret");
state.complete(state.PamResult.Error);
assert(!state.busy && state.failed);
assert.equal(state.status, "Authentication unavailable");

// Escape clears the input and typing pulse without discarding an active PAM prompt.
state = createState();
state.failed = true;
state.status = "Incorrect password — try again";
state.clear = () => state.clears++;
state.pulse = { stop() {} };
state.ripple = { opacity: 0.7 };
vm.runInContext(`(() => { ${body("Keys.onEscapePressed:")} })()`, state);
assert.equal(state.clears, 1);
assert.equal(state.ripple.opacity, 0);
assert(!state.failed);
assert.equal(state.status, "Enter your password");
state.status = "Username:";
vm.runInContext(`(() => { ${body("Keys.onEscapePressed:")} })()`, state);
assert.equal(state.status, "Username:");

// Check the actual sizing expressions at narrow/short sizes and with long feedback.
const geometry = vm.createContext({});
for (const [width, height, clockHeight, cardHeight] of [
  [1920, 1080, 132, 180],
  [320, 240, 70, 180],
  [200, 150, 80, 500],
]) {
  geometry.content = { height };
  geometry.parent = { width, height };
  geometry.clock = { height: clockHeight };
  geometry.card = { height: cardHeight };
  geometry.clock.gap = vm.runInContext(
    qml.match(/readonly property real gap: (.*)/)[1],
    geometry,
  );
  Object.assign(geometry, { height, width });
  const contentHeight = vm.runInContext(
    qml.match(/contentHeight: (.*)/)[1],
    geometry,
  );
  geometry.parent.height = contentHeight;
  geometry.height = clockHeight;
  geometry.gap = geometry.clock.gap;
  const clockY = vm.runInContext(
    qml.match(/y: Math.max\(12, (.*)/)[0].slice(3),
    geometry,
  );
  assert(clockY >= 12);
  assert(
    clockY + clockHeight + geometry.clock.gap + cardHeight <= contentHeight,
  );
}
assert(qml.includes("anchors.top: clock.bottom"));
assert(qml.includes("anchors.topMargin: clock.gap"));
assert(qml.includes("interactive: contentHeight > height"));

console.log(
  "PASS: rapid submissions, retries, PAM prompts, errors, success, and layout sizing",
);
