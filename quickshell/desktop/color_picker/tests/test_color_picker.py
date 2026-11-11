"""Static checks; live magnifier behavior needs a real compositor session."""

import re
import unittest
from pathlib import Path


SOURCE = (Path(__file__).resolve().parents[1] / "ColorPicker.qml").read_text()
SHELL = Path(__file__).resolve().parents[2] / "shell.qml"


class ColorPickerTests(unittest.TestCase):
    def test_shell_mounts_picker(self):
        shell = SHELL.read_text()
        self.assertIn('import "./color_picker"', shell)
        self.assertIn("    ColorPicker { }", shell)

    def test_overlay_layers_and_inputs(self):
        self.assertIn("WlrLayer.Overlay", SOURCE)
        self.assertIn("ExclusionMode.Ignore", SOURCE)
        self.assertIn("exclusiveZone: 0", SOURCE)
        self.assertIn("model: Quickshell.screens", SOURCE)
        self.assertIn("WlrKeyboardFocus.Exclusive", SOURCE)
        self.assertIn("hoverEnabled: true", SOURCE)
        # The tracking surface must fill the screen; the panel is a child.
        self.assertIn(
            "anchors { top: true; bottom: true; left: true; right: true }", SOURCE
        )

    def test_ipc_and_compositor_coordinates(self):
        self.assertIn('target: "colorpicker"', SOURCE)
        self.assertRegex(
            SOURCE,
            r"function pick\(file: string\): void",
            "typed IPC function registers",
        )
        self.assertRegex(
            SOURCE,
            r"function cancel\(\): void",
            "timeout dismissal registers",
        )
        # Clicks must pick exactly where the user clicked — the tracked
        # point can lag one grab cycle behind the cursor — reported in
        # compositor coordinates for grim.
        self.assertIn("overlay.screen.x + Math.round(mouse.x)", SOURCE)
        self.assertIn("overlay.screen.y + Math.round(mouse.y)", SOURCE)

    def test_results_reach_the_caller(self):
        # Picks write "<x> <y>"; cancellation touches the file empty.
        self.assertIn("\"printf '%s\\\\n' '\"", SOURCE)
        self.assertIn('writer.command = ["touch", pointFile]', SOURCE)

    def test_click_requires_tracking(self):
        # A click with no position reports would write a bogus constant
        # point (0,0), the symptom of repeated stale colors.
        self.assertIn("if (!area.containsMouse)", SOURCE)
        self.assertIn("picker.cancel()", SOURCE)

    def test_capture_happens_without_a_cursor(self):
        # The compositor cursor is composited into grim's capture, and the
        # picked pixel is the cursor hotspot, so picks kept returning the
        # cursor's white outline (fafafa). The cursor is hidden while
        # picking, and the overlay stays up (keeping it blank) until
        # copy-color.sh captures and cancels the picker.
        self.assertIn("cursorShape: Qt.BlankCursor", SOURCE)
        self.assertNotIn("picker.picking = false", SOURCE)
        self.assertIn("refresh.watch = false", SOURCE)

    def test_magnifier_capture_and_refresh(self):
        self.assertIn('"grim", "-g"', SOURCE)
        # "grim -g" geometry must be "<x>,<y> <width>x<height>"; a
        # space-separated "x y w h" fails to parse and exits with status 1.
        self.assertIn('patchX + "," + patchY + " "', SOURCE)
        self.assertIn('picker.patchSize + "x" + picker.patchSize', SOURCE)
        self.assertIn("interval: 25", SOURCE)
        self.assertIn("repeat: true", SOURCE)
        # Query strings cannot be loaded from file URLs; use revisioned names.
        self.assertIsNone(re.search(r'\+\s*"\?r="\s*\+', SOURCE))
        self.assertIn('-" + (revision + 1) + ".png"', SOURCE)
        # The point must track the cursor even while a grab is in flight,
        # or picks land one grab cycle (~100ms of motion) behind the click.
        self.assertLess(
            SOURCE.index("pointX = x;"),
            SOURCE.index("if (grabber.running)"),
            "cursor tracking must not be gated on the grab",
        )
        # A grab finishing after the cursor stops must not strand a stale
        # patch: re-grab when the cursor leaves the shown patch, not only
        # when the tracked point changed.
        self.assertIn("screen.x + x >= shownX", SOURCE)
        self.assertIn("screen.x + x < shownX + picker.patchSize", SOURCE)
        self.assertIn("screen.y + y >= shownY", SOURCE)
        self.assertIn("screen.y + y < shownY + picker.patchSize", SOURCE)
        # The cross is tracked against the displayed image, never the grab
        # in flight, so it cannot lie about the pixel under the cursor.
        self.assertIn("screen.x + pointX - shownX", SOURCE)
        self.assertIn("overlay.shownX = overlay.patchX", SOURCE)
        # Grabs completing after hide must not leak into the next pick.
        self.assertIn("if (!overlay.visible)", SOURCE)
        # Clamps must be global: screen-local bounds pin the patch to a
        # fixed column on any screen whose x/y offset is nonzero.
        self.assertRegex(
            SOURCE,
            r"Math\.min\(Math\.max\(gx - half, screen\.x\)",
            "patch clamped to the screen's global bounds",
        )
        self.assertRegex(
            SOURCE,
            r"Math\.min\(Math\.max\(gy - half, screen\.y\)",
            "patch clamped to the screen's global bounds",
        )
        self.assertIn("screen.x + screen.width - picker.patchSize", SOURCE)
        self.assertIn("screen.y + screen.height - picker.patchSize", SOURCE)
        self.assertIn("grabber.running", SOURCE)
        self.assertIn("overlay.patchTarget = targetFile", SOURCE)

    def test_panel_parks_in_the_top_right_corner(self):
        # The panel does not chase the cursor: it parks at the right edge —
        # top corner by default — and flips to the bottom-right corner only
        # when the cursor's grab patch would reach it, because the magnifier
        # must never capture itself.
        self.assertIn("x: parent.width - width - gutter", SOURCE)
        self.assertIn("Math.round(area.mouseY) - reach <= gutter + height", SOURCE)
        self.assertIn("? parent.height - height - gutter", SOURCE)
        self.assertIn(": gutter", SOURCE)
        self.assertIn("picker.patchSize / 2 + 24", SOURCE)
        self.assertIn("Math.round(area.mouseX) + reach >= x", SOURCE)

    def test_pointer_ring_marks_the_pick_point(self):
        # With the cursor hidden, the pointer position still needs a visible
        # marker: a ring drawn by the overlay around the cursor, with an
        # open center so grim never captures the marker over the pixel.
        self.assertIn("// Ring marking the pointer position", SOURCE)
        ring = SOURCE[SOURCE.index("// Ring marking the pointer position") :]
        self.assertIn("Math.round(area.mouseX) - width / 2", ring)
        self.assertIn("Math.round(area.mouseY) - height / 2", ring)
        self.assertIn("radius: 8", ring)
        self.assertIn('color: "transparent"', ring)
        self.assertIn('border.color: "#eb4d4b"', ring)

    def test_guides_do_not_tint_the_picked_pixel(self):
        # Cross-hair guides tinted the preview and misled the pick, so they
        # were removed: only the 8x patch and a red border around the exact
        # pixel remain, and the border sits outside the pixel itself.
        self.assertNotIn("guide", SOURCE)
        self.assertNotIn("#7fffffff", SOURCE)
        self.assertIn('border.color: "#eb4d4b"', SOURCE)
        self.assertIn("picker.magnification + 4", SOURCE)

    def test_escape_cancels(self):
        self.assertIn('sequence: "Escape"', SOURCE)
        self.assertIn("picker.cancel()", SOURCE)


if __name__ == "__main__":
    unittest.main()
