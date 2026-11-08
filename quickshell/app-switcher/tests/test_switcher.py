"""Model regression tests; keyboard grabs still require a live Sway session."""

import re
import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SWITCHER = ROOT / "quickshell/app-switcher"


class SwitcherTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("node"), "Node.js required")
    def test_model(self):
        qml = (SWITCHER / "shell.qml").read_text()
        functions = []
        for name in ("orderedWindows", "buildApplications", "cycle"):
            match = re.search(
                rf"^    function {name}\([^\n]*\) \{{\n.*?^    \}}", qml, re.M | re.S
            )
            self.assertIsNotNone(match, name)
            functions.append(match.group())
        source = "\n".join(functions)
        self.assertNotIn('import "model.js"', qml)
        self.assertFalse((SWITCHER / "model.js").exists())
        checks = """
const assert = require('node:assert/strict');
const a = {appId: 'Alacritty'}, b = {appId: 'helium'},
      c = {appId: 'alacritty'}, gone = {appId: 'gone'};
assert.deepEqual(orderedWindows([a,b,c], [gone,c,a], b), [b,c,a]);
assert.deepEqual(orderedWindows([a,b], [], null), [a,b]);
assert.deepEqual(orderedWindows([], [gone], gone), []);
const apps = buildApplications([b,c,a], () => '');
assert.equal(apps.length, 2);
assert.equal(apps[0].window, b);
assert.equal(apps[1].window, c);
assert.equal(apps[1].appId, 'alacritty');
assert.equal(buildApplications([a,b], () => 'same.desktop')[0].window, a);
assert.equal(buildApplications([a,b], () => 'same.desktop').length, 1);
assert.deepEqual(buildApplications([], () => ''), []);
assert.equal(cycle(0, -1, 3), 2);
assert.equal(cycle(2, 1, 3), 0);
assert.equal(cycle(0, 1, 1), 0);
assert.equal(cycle(0, 1, 0), 0);
"""
        subprocess.run(["node", "-e", source + checks], check=True)

    def test_sway_integration_and_placement(self):
        config = (ROOT / "sway/config").read_text()
        for line in (
            "exec qs -c app-switcher",
            "    bindsym $mod+Tab nop app-switcher-next",
            "    bindsym $mod+Shift+Tab nop app-switcher-previous",
            "    bindsym --release Super_L nop app-switcher-accept",
            "    bindsym --release Super_R nop app-switcher-accept",
            "    bindsym --release Shift+Super_L nop app-switcher-accept",
            "    bindsym --release Shift+Super_R nop app-switcher-accept",
        ):
            self.assertEqual(config.splitlines().count(line), 1)
        self.assertIn(
            "quickshell ~/.config/quickshell",
            (ROOT / "placements/linux.txt").read_text(),
        )

    def test_compact_layout(self):
        source = (SWITCHER / "shell.qml").read_text()
        self.assertIn("text: appName", source)
        self.assertNotIn("modelData.windows.length", source)
        self.assertIn(
            "32 + shell.applications.length * 112 + Math.max(0, shell.applications.length - 1) * 8",
            source,
        )
        self.assertIn("screen ? screen.width - 40 : 720", source)
        self.assertIn("implicitHeight: 140", source)

    def test_keyboard_and_lifecycle_contract(self):
        source = (SWITCHER / "shell.qml").read_text()
        for fragment in (
            "visible: shell.opened",
            "shell.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
            "Qt.Key_Escape",
            'command: ["swaymsg", "-m", "-r", "-t", "subscribe", \'["binding"]\']',
            "onRead: data => shell.handleBinding(data)",
            "if (shell.opened) shell.cancel();",
            "ToplevelManager.toplevels.values.includes(window)",
            "const window = applications[selected].window;",
            'command: ["swaymsg", "-r", "-t", "get_tree"]',
            "focusRequest.target = { appId: window.appId, title: window.title };",
            "focusRequest.running = true;",
            'Quickshell.execDetached(["swaymsg", "[con_id=" + id + "]", "focus"]);',
            "DesktopEntries.heuristicLookup",
        ):
            self.assertIn(fragment, source)
        self.assertIn("Keys.onReleased:", source)
        for key in ("Qt.Key_Super_L", "Qt.Key_Super_R", "Qt.Key_Meta"):
            self.assertIn(key, source)
        release = source.split("Keys.onReleased: event => {", 1)[1].split(
            "ListView {", 1
        )[0]
        self.assertIn("shell.accept();", release)
        self.assertNotIn("Timer {", source)
        self.assertNotIn("window.activate()", source)

    @unittest.skipUnless(shutil.which("node"), "Node.js required")
    def test_sway_container_matching(self):
        source = (SWITCHER / "shell.qml").read_text()
        function = re.search(
            r"^    function findContainer\([^\n]*\) \{\n.*?^    \}", source, re.M | re.S
        )
        self.assertIsNotNone(function)
        subprocess.run(
            [
                "node",
                "-e",
                function.group()
                + """
const assert = require('node:assert/strict');
const old = {id: 10, app_id: 'helium', name: 'Same title'};
const recent = {id: 20, app_id: 'helium', name: 'Same title'};
const floating = {id: 30, app_id: 'Alacritty', name: 'Terminal'};
const x11 = {id: 40, window: 99, window_properties: {class: 'Emacs'}, name: 'Editor'};
const tree = {nodes: [
    {id: 1, nodes: [old, recent], floating_nodes: [floating], focus: [30, 20, 10]},
    {id: 2, nodes: [x11]},
], focus: [2, 1]};
assert.equal(findContainer(tree, {appId: 'HELIUM', title: 'Same title'}), 20);
assert.equal(findContainer(tree, {appId: 'helium', title: 'Changed title'}), 20);
old.name = 'Selected title';
assert.equal(findContainer(tree, {appId: 'helium', title: 'Selected title'}), 10);
assert.equal(findContainer(tree, {appId: 'alacritty', title: 'Terminal'}), 30);
assert.equal(findContainer(tree, {appId: 'emacs', title: 'Editor'}), 40);
assert.equal(findContainer(tree, {appId: 'gone', title: 'Same title'}), 0);
assert.equal(findContainer({}, {appId: 'helium', title: ''}), 0);
// Duplicate titles across workspaces follow Sway's focus order, not tree-array order.
tree.nodes[1].nodes.push({id: 50, app_id: 'helium', name: 'Same title'});
assert.equal(findContainer(tree, {appId: 'helium', title: 'Same title'}), 50);
""",
            ],
            check=True,
        )

    @unittest.skipUnless(shutil.which("node"), "Node.js required")
    def test_accept_without_overlay_keypress(self):
        source = (SWITCHER / "shell.qml").read_text()
        functions = []
        for name in ("findContainer", "accept"):
            match = re.search(
                rf"^    function {name}\([^\n]*\)(?:: void)? \{{\n.*?^    \}}",
                source,
                re.M | re.S,
            )
            self.assertIsNotNone(match, name)
            functions.append(match.group().replace("(): void", "()"))
        collector = re.search(
            r"            onStreamFinished: \{\n(.*?)^            \}",
            source,
            re.M | re.S,
        )
        self.assertIsNotNone(collector)
        functions.append("function receiveTree(text) {\n" + collector.group(1) + "\n}")
        subprocess.run(
            [
                "node",
                "-e",
                "\n".join(functions)
                + """
const assert = require('node:assert/strict');
const warnings = [];
const console = {warn: (...args) => warnings.push(args)};
const commands = [];
const Quickshell = {execDetached: command => commands.push(command)};
const shell = {findContainer};
// No activate() method or prior keypress: native focus must still work.
const window = {appId: 'helium', title: 'Browser'};
const ToplevelManager = {toplevels: {values: [window]}};
let opened = true, applications = [{window}], selected = 0;
const focusRequest = {target: null, running: false};
function cancel() { opened = false; applications = []; }
accept();
assert.equal(opened, false);
assert.equal(focusRequest.running, true);
assert.deepEqual(focusRequest.target, {appId: 'helium', title: 'Browser'});
accept(); // A second release cannot issue another selection.
receiveTree(JSON.stringify({nodes: [{id: 42, app_id: 'helium', name: 'Browser'}]}));
assert.deepEqual(commands, [['swaymsg', '[con_id=42]', 'focus']]);
assert.equal(focusRequest.target, null);
focusRequest.target = {appId: 'gone', title: ''};
receiveTree('{}');
focusRequest.target = {appId: 'helium', title: 'Browser'};
receiveTree('invalid');
focusRequest.target = {appId: 'helium', title: 'Browser'};
receiveTree(JSON.stringify({nodes: [{id: '42] kill', app_id: 'helium', name: 'Browser'}]}));
assert.equal(commands.length, 1);
assert.equal(warnings.length, 3);
opened = true;
applications = [{window}];
focusRequest.running = false;
ToplevelManager.toplevels.values = [];
accept(); // A window destroyed before accepting must not launch a query.
assert.equal(opened, false);
assert.equal(focusRequest.running, false);
assert.equal(focusRequest.target, null);
""",
            ],
            check=True,
        )

    @unittest.skipUnless(shutil.which("node"), "Node.js required")
    def test_ordered_shortcuts_before_overlay_focus(self):
        source = (SWITCHER / "shell.qml").read_text()
        handler = re.search(
            r"^    function handleBinding\(line\) \{\n.*?^    \}", source, re.M | re.S
        )
        self.assertIsNotNone(handler)
        subprocess.run(
            [
                "node",
                "-e",
                handler.group()
                + """
const assert = require('node:assert/strict');
const actions = [];
const shell = {step: direction => actions.push(direction), accept: () => actions.push('accept')};
function send(command) { handleBinding(JSON.stringify({binding: {command}})); }
handleBinding('invalid');
handleBinding('{"success":true}');
send('nop unrelated');
assert.deepEqual(actions, []);
// All events can arrive before the layer surface receives keyboard focus.
send('nop app-switcher-next');
send('nop app-switcher-next');
send('nop app-switcher-previous');
send('nop app-switcher-accept');
assert.deepEqual(actions, [1, 1, -1, 'accept']);
""",
            ],
            check=True,
        )


if __name__ == "__main__":
    unittest.main()
