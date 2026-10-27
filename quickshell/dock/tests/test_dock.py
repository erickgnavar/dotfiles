"""QML wiring and actual JavaScript handler checks; no compositor required."""

import re
import subprocess
import unittest
from pathlib import Path


SOURCE = (Path(__file__).resolve().parents[1] / "shell.qml").read_text()


def block(marker):
    start = SOURCE.index("{", SOURCE.index(marker)) + 1
    depth = 1
    for end in range(start, len(SOURCE)):
        depth += (SOURCE[end] == "{") - (SOURCE[end] == "}")
        if not depth:
            return SOURCE[start:end]
    raise AssertionError(f"Unclosed block: {marker}")


class DockTests(unittest.TestCase):
    def javascript(self, code):
        subprocess.run(
            ["node", "-e", "const assert = require('node:assert/strict');\n" + code],
            check=True,
        )

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
        self.assertEqual(SOURCE.count("PopupWindow {"), 1)
        self.assertLess(SOURCE.index("PopupWindow {"), SOURCE.index("delegate: Button"))
        self.assertIn("mask: Region {}", block("PopupWindow {"))
        self.assertIn("interval: 100", block("            Timer {"))
        self.assertIn("dock.expanded ? dock.hoveredEntry : null", SOURCE)

    def test_hover_switch_removal_and_delay(self):
        clear = block("function clearHoveredEntry")
        change = block("onEntryChanged:")
        hover = block("readonly property var tooltipIcon")
        self.assertIn("Component.onDestruction: dock.clearHoveredEntry(entry)", SOURCE)
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
