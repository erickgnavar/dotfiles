"""QML wiring and actual JavaScript handler checks; no compositor required."""

import re
import subprocess
import unittest
from pathlib import Path


SOURCE = (Path(__file__).resolve().parents[1] / "shell.qml").read_text()


def block(marker, source=SOURCE):
    start = source.index("{", source.index(marker)) + 1
    depth = 1
    for end in range(start, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if not depth:
            return source[start:end]
    raise AssertionError(f"Unclosed block: {marker}")


class DockTests(unittest.TestCase):
    def javascript(self, code):
        subprocess.run(
            ["node", "-e", "const assert = require('node:assert/strict');\n" + code],
            check=True,
        )

    def test_chooser_workspace_and_urgency_metadata(self):
        self.javascript(
            f"function collectWindows(node, workspace) {{{block('function collectWindows(')}}}"
            "const tree = {nodes: [{type: 'workspace', name: '2: web', nodes: ["
            "{type: 'con', app_id: 'helium', name: 'Browser', urgent: true}],"
            "floating_nodes: [{type: 'con', window_properties: {class: 'Emacs'}, name: 'Editor'}]}]};"
            "const chooser = {windowDetails: collectWindows(tree, '')};"
            f"function detailsFor(window) {{{block('function detailsFor(').replace('windowDetails', 'chooser.windowDetails')}}}"
            "assert.equal(chooser.windowDetails.length, 2);"
            "assert.equal(detailsFor({appId: 'HELIUM', title: 'Browser'}).workspace, '2: web');"
            "assert.equal(detailsFor({appId: 'helium', title: 'Browser'}).urgent, true);"
            "assert.equal(detailsFor({appId: 'emacs', title: 'Editor'}).urgent, false);"
            "assert.equal(detailsFor({appId: 'helium', title: 'Missing'}), null);"
            "chooser.windowDetails.push({...chooser.windowDetails[0]});"
            "assert.equal(detailsFor({appId: 'helium', title: 'Browser'}), null);"
            "assert.deepEqual(collectWindows({}, ''), []);"
        )
        self.assertIn("running: chooser.visible", SOURCE)
        self.assertIn('["window","workspace"]', SOURCE)
        self.assertIn(
            'details ? "Workspace " + details.workspace : "Workspace unknown"', SOURCE
        )
        self.assertIn(" · Focused", SOURCE)
        self.assertIn(" · Urgent", SOURCE)
        self.assertIn("sourceSize.width: 28", SOURCE)

    def test_startup_edge_and_ipc(self):
        self.assertIn("visible: true", SOURCE)
        for edge in ("left", "top", "bottom"):
            self.assertIn(f"anchors.{edge}: true", SOURCE)
        self.assertIn("implicitWidth: expanded ? 76 : 3", SOURCE)
        self.assertIn("shell.forcedOpen || hoverExpanded", SOURCE)
        reveal = re.search(r"onTriggered: (dock\.hoverExpanded = true)", SOURCE).group(
            1
        )
        self.javascript(
            "const shell = { forcedOpen: false };"
            "const dock = { hoverExpanded: false };"
            f"const toggle = () => {{{block('function toggle()')}}};"
            f"const reveal = () => {{ {reveal}; }};"
            "reveal(); assert.equal(dock.hoverExpanded, true);"
            "toggle(); assert.equal(shell.forcedOpen, true);"
            "toggle(); assert.equal(shell.forcedOpen, false);"
        )

    def test_one_tooltip_per_screen(self):
        self.assertEqual(SOURCE.count("id: tooltip\n"), 1)
        self.assertEqual(SOURCE.count("PopupWindow {"), 2)
        self.assertLess(SOURCE.index("PopupWindow {"), SOURCE.index("delegate: Button"))
        self.assertIn("mask: Region {}", block("PopupWindow {"))
        self.assertIn("interval: 100", block("            Timer {"))
        self.assertIn(
            "dock.expanded && !dock.chooserAppId ? dock.hoveredEntry : null", SOURCE
        )

    def test_hover_switch_removal_and_delay(self):
        clear = block("function clearHoveredEntry")
        change = block("onEntryChanged:")
        hover = block("readonly property var tooltipIcon")
        self.assertIn(
            "dock.clearHoveredEntry(entry);", block("Component.onDestruction:")
        )
        self.javascript(
            "const tooltip = { visible: true }; let restarts = 0, stops = 0;"
            "const restart = () => restarts++; const stop = () => stops++;"
            f"const change = entry => {{{change}}};"
            "const dock = { hoveredEntry: null };"
            f"dock.clearHoveredEntry = entry => {{ let hoveredEntry = dock.hoveredEntry; {clear};"
            "dock.hoveredEntry = hoveredEntry; };"
            f"const hover = (entry, hovered) => {{{hover}}};"
            "const a = {}, b = {}; hover(a, true); change(a);"
            "assert.equal(tooltip.visible, false); assert.equal(restarts, 1);"
            "hover(b, true); hover(a, false); assert.equal(dock.hoveredEntry, b);"
            "change(b); assert.equal(restarts, 2);"
            "dock.clearHoveredEntry(a); assert.equal(dock.hoveredEntry, b);"
            "dock.clearHoveredEntry(b); change(null);"
            "assert.equal(dock.hoveredEntry, null); assert.equal(stops, 1);"
        )

    def test_position_and_scroll(self):
        anchor = block("onAnchoring:")
        self.assertIn(
            "function onContentYChanged(): void { tooltip.anchor.updateAnchor(); }",
            SOURCE,
        )
        self.assertIn("adjustment: PopupAdjustment.SlideY", SOURCE)
        self.javascript(
            "for (const y of [60, 250, 700]) for (const height of [24, 40]) {"
            "const icon = { height: 30 };"
            "const tooltipDelay = { entry: { tooltipIcon: icon } };"
            "const tooltip = { height, anchor: { rect: {} } };"
            "const dock = { width: 76, contentItem: { mapFromItem: () => ({ y }) } };"
            f"const anchor = () => {{{anchor}}}; anchor();"
            "assert.equal(tooltip.anchor.rect.x + 1 - 68, 4);"
            "assert.equal(tooltip.anchor.rect.y + height / 2, y);"
            "tooltipDelay.entry = null; anchor(); }"
        )

    def test_pinned_order_matching_and_remaining_windows(self):
        pins = re.search(r"pinnedApps: (\[.*\])", SOURCE).group(1)
        self.javascript(
            f"const pinnedApps = {pins};"
            "assert.deepEqual(pinnedApps, ['helium', 'Alacritty', 'emacs', 'spotify', 'org.gnome.Nautilus']);"
            "const shell = { desktopEntriesRevision: 0 };"
            "const DesktopEntries = { heuristicLookup: id => "
            "id === 'nautilus' || id === 'org.gnome.Nautilus' ? { id: 'org.gnome.Nautilus' } : null };"
            f"const matchesApp = (window, appId) => {{{block('function matchesApp')}}};"
            "assert.equal(matchesApp({ appId: 'alacritty' }, 'Alacritty'), true);"
            "assert.equal(matchesApp({ appId: 'nautilus' }, 'org.gnome.Nautilus'), true);"
            "assert.equal(matchesApp({ appId: 'unknown' }, 'emacs'), false);"
            "const ToplevelManager = { toplevels: { values: [] } };"
            f"const items = () => {{{block('readonly property var dockItems:')}}};"
            "assert.equal(items().length, 5);"
            "const a = { appId: 'Alacritty' }, b = { appId: 'Alacritty' };"
            "const other = { appId: 'firefox' };"
            "ToplevelManager.toplevels.values = [a, b, other, { appId: 'nautilus' }];"
            "assert.equal(items().length, 6); assert.equal(items()[5].toplevel, other);"
            "ToplevelManager.toplevels.values = []; assert.equal(items().length, 5);"
        )

    def test_launch_focus_and_running_state(self):
        self.javascript(
            "const shell = { desktopEntriesRevision: 0, matchesApp: (w, id) => w.appId === id };"
            "let focused = 0, launched = 0;"
            "const a = { appId: 'helium', activated: false, activate: () => focused = 1 };"
            "const b = { appId: 'helium', activated: true, activate: () => focused = 2 };"
            "const ToplevelManager = { toplevels: { values: [a, b] } };"
            "let modelData = { appId: 'helium', pinned: true };"
            f"const matching = () => {{{block('readonly property var appWindows: {', SOURCE[SOURCE.index('id: entry') :])}}};"
            "let appWindows = matching(); const desktopEntry = { execute: () => launched++ };"
            "const dock = { chooserAppId: '' };"
            f"const click = () => {{{block('onClicked: {\n                                if (appWindows')}}};"
            "assert.equal(appWindows.length, 2); click(); assert.equal(dock.chooserAppId, 'helium');"
            "assert.equal(focused, 0); click(); assert.equal(dock.chooserAppId, '');"
            "ToplevelManager.toplevels.values = [a]; appWindows = matching(); click();"
            "assert.equal(focused, 1);"
            "ToplevelManager.toplevels.values = []; appWindows = matching(); click();"
            "assert.equal(launched, 1);"
            "modelData = { pinned: false, toplevel: a }; appWindows = matching(); click();"
            "assert.equal(focused, 1); assert.equal(launched, 1);"
        )
        self.assertIn("visible: entry.appWindows.length > 0", SOURCE)
        self.assertIn("appWindows.some(window => window.activated)", SOURCE)

    def test_window_chooser_selection_and_lifecycle(self):
        chooser = SOURCE[
            SOURCE.index("id: chooser\n") : SOURCE.index("// The full-height")
        ]
        self.assertIn("model: chooser.appWindows", chooser)
        self.assertIn("elide: Text.ElideRight", chooser)
        self.assertIn("clip: true", chooser)
        self.assertIn("chooser.anchor.updateAnchor()", chooser)
        self.assertIn("if (hover.hovered || chooserHover.hovered) return;", SOURCE)
        self.javascript(
            "const dock = { chooserAppId: 'helium' }; let focused = 0;"
            "const modelData = { activate: () => focused++ };"
            f"const choose = () => {{{block('                            onClicked:')}}};"
            "choose(); assert.equal(focused, 1); assert.equal(dock.chooserAppId, '');"
            "let appWindows = [{}, {}]; dock.chooserAppId = 'helium';"
            f"const changed = () => {{{block('onAppWindowsChanged:')}}};"
            "changed(); assert.equal(dock.chooserAppId, 'helium');"
            "appWindows = [{}]; changed(); assert.equal(dock.chooserAppId, '');"
            "appWindows = []; changed();"
            "dock.chooserAppId = 'helium'; let expanded = false;"
            f"const collapse = () => {{{block('onExpandedChanged:')}}};"
            "collapse(); assert.equal(dock.chooserAppId, '');"
        )

    def test_chooser_survives_model_and_delegate_replacement(self):
        chooser = SOURCE[
            SOURCE.index("id: chooser\n") : SOURCE.index("// The full-height")
        ]
        self.assertNotIn("chooserEntry", SOURCE)
        self.assertIn(
            "function onYChanged(): void { chooser.anchor.updateAnchor(); }", chooser
        )
        app_index = re.search(r"appIndex: (.*)", chooser).group(1)
        anchor = chooser[chooser.index("if (chooser.appIndex < 0)") :]
        anchor = anchor[: anchor.index("\n                    }")]
        self.javascript(
            "const dock = { chooserAppId: 'helium', clearHoveredEntry: () => {} };"
            "const shell = { desktopEntriesRevision: 0, dockItems: [{ appId: 'helium' }],"
            "matchesApp: (w, id) => w.appId === id };"
            "const a = { appId: 'helium' }, b = { appId: 'helium' };"
            "const ToplevelManager = { toplevels: { values: [a, b] } };"
            f"const matching = () => {{{block('readonly property var appWindows: {')}}};"
            f"const index = () => {app_index};"
            f"const destroy = entry => {{{block('Component.onDestruction:')}}};"
            "assert.deepEqual(matching(), [a, b]); destroy({});"
            "shell.dockItems = [{ appId: 'helium' }, { appId: 'other' }];"
            "ToplevelManager.toplevels.values = [a, b, { appId: 'other' }];"
            "assert.equal(dock.chooserAppId, 'helium'); assert.equal(index(), 0);"
            "assert.deepEqual(matching(), [a, b]);"
            "const c = { appId: 'helium' }; ToplevelManager.toplevels.values = [a, b, c];"
            "shell.desktopEntriesRevision++; destroy({});"
            "assert.deepEqual(matching(), [a, b, c]);"
            "const windows = { rowHeight: 48, spacing: 4, contentY: 12 };"
            "const chooser = { appIndex: index(), height: 100, anchor: { rect: {} } };"
            "dock.width = 76; dock.contentItem = { mapFromItem: (item, x, y) => ({ y: y + 200 }) };"
            f"const anchor = () => {{{anchor}}};"
            "anchor(); assert.equal(chooser.anchor.rect.y, 158);"
            "assert.equal(chooser.anchor.rect.x, 71);"
        )

    def test_async_desktop_entry_refresh(self):
        self.assertIn(
            "shell.desktopEntriesRevision;",
            block("readonly property var desktopEntry:"),
        )
        self.assertIn("DesktopEntries.heuristicLookup(modelData.appId)", SOURCE)
        self.javascript(
            "const shell = { desktopEntriesRevision: 0 };"
            f"const refresh = () => {{{block('function onApplicationsChanged()')}}};"
            "refresh(); refresh(); assert.equal(shell.desktopEntriesRevision, 2);"
        )


if __name__ == "__main__":
    unittest.main()
