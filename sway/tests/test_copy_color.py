import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "copy-color.sh"


class CopyColorTests(unittest.TestCase):
    def run_pick(self, failure="", empty=False, choice="", qs="", pick_timeout=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mock = root / "mock"
            mock.write_text("""#!/usr/bin/env bash
name=${0##*/}
printf '%s\\n' "$name" >> "$LOG"
[[ "$FAIL" != "$name" ]] || exit 2
case "$name" in
  qs)
    for arg in "$@"; do
      [[ "$arg" == cancel ]] && { printf 'qs-cancel\\n' >> "$LOG"; exit 0; }
    done
    point_file="${@: -1}"
    case "$QS" in
      cancel) touch "$point_file"; exit 0 ;;
      fail) exit 2 ;;
      hang) exit 0 ;;
    esac
    printf '%s\\n' "${QS_POINT:-100 200}" > "$point_file"
    ;;
  slurp)
    [[ "$FAIL" != cancel ]] || exit 1
    printf '100,200 1x1\\n'
    ;;
  grim) printf '%s\n' "$2" > "$GEO"; touch "$3" ;;
  magick)
    [[ "$FAIL" != empty ]] || exit 0
    printf '4a90d9\\n'
    ;;
  rofi)
    menu=$(cat)
    printf '%s\\n' "$menu" > "$MENU"
    printf '%s\\n' "$*" > "$RARGS"
    pick=$(printf '%s\\n' "$menu" | awk -v want="$CHOICE" 'index($0, want "\\t") { print; exit }')
    printf '%s\\n' "${pick:-$(printf '%s\\n' "$menu" | head -n 1)}"
    ;;
  wl-copy) cat > "$COPIED" ;;
esac
""")
            mock.chmod(0o755)
            for name in (
                "qs",
                "slurp",
                "grim",
                "magick",
                "rofi",
                "wl-copy",
                "notify-send",
            ):
                (root / name).symlink_to(mock)
            work = root / "work"
            work.mkdir()
            env = dict(
                os.environ,
                PATH=f"{root}:{os.environ['PATH']}",
                LOG=str(root / "log"),
                COPIED=str(root / "copied"),
                GEO=str(root / "geo"),
                FAIL=("empty" if empty else failure),
                QS=qs,
                CHOICE=choice,
                MENU=str(root / "menu"),
                RARGS=str(root / "rofi_args"),
                TMPDIR=str(work),
            )
            if pick_timeout is not None:
                env["PICK_TIMEOUT"] = str(pick_timeout)
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                env=env,
                capture_output=True,
                text=True,
                timeout=5,
            )
            calls = (root / "log").read_text().splitlines()
            copied = root / "copied"
            value = copied.read_text() if copied.exists() else None
            # grim's geometry must be "<x>,<y> <width>x<height>"; a bare
            # "x,y" fails with "invalid geometry" and copies nothing.
            geo = root / "geo"
            self.last_geo = geo.read_text().strip() if geo.exists() else None
            menu_path = root / "menu"
            self.last_menu = menu_path.read_text() if menu_path.exists() else ""
            rargs = root / "rofi_args"
            self.last_rofi_args = rargs.read_text() if rargs.exists() else ""
            self.assertEqual(list(work.iterdir()), [])
            return result.returncode, calls, value

    def test_success_defaults_to_hex(self):
        status, calls, copied = self.run_pick()
        self.assertEqual(status, 0)
        self.assertEqual(copied, "#4a90d9\n")
        for command in ("qs", "grim", "magick", "rofi", "wl-copy"):
            self.assertIn(command, calls)
        self.assertNotIn("slurp", calls)
        self.assertEqual(self.last_geo, "100,200 1x1")
        # The overlay stays up (blank cursor) while grim captures and is
        # dismissed only afterwards, before the menu.
        self.assertLess(calls.index("grim"), calls.index("qs-cancel"))

    def test_rofi_menu_renders_color_swatch(self):
        status, _, copied = self.run_pick()
        self.assertEqual(status, 0)
        self.assertEqual(copied, "#4a90d9\n")
        # -markup-rows lets rofi render the Pango swatch span per entry.
        self.assertIn("-markup-rows", self.last_rofi_args)
        for line in self.last_menu.splitlines():
            with self.subTest(line=line):
                self.assertIn('<span background="#4a90d9">', line)
                # The markup stays before the tab; the value stays plain.
                label, _, value = line.partition("\t")
                self.assertIn("<span", label)
                self.assertNotIn("<span", value)

    def test_format_selection_copies_chosen_value(self):
        with self.subTest(format="HSL"):
            status, _, copied = self.run_pick(choice="HSL")
            self.assertEqual(status, 0)
            self.assertIsNotNone(copied)
            self.assertRegex(copied or "", r"^hsl\(\d+, \d+%, \d+%\)\n$")
        with self.subTest(format="RGBA"):
            status, _, copied = self.run_pick(choice="RGBA")
            self.assertEqual(status, 0)
            self.assertEqual(copied, "rgba(74, 144, 217, 1.0)\n")

    def test_cancel(self):
        self.assertEqual(self.run_pick(qs="cancel"), (0, ["qs"], None))

    def test_quickshell_unavailable_falls_back_to_slurp(self):
        status, calls, copied = self.run_pick(failure="qs")
        self.assertEqual(status, 0)
        self.assertEqual(copied, "#4a90d9\n")
        self.assertEqual(calls[0], "qs")
        self.assertIn("slurp", calls)
        self.assertEqual(self.last_geo, "100,200 1x1")

    def test_slurp_cancellation_preserves_clipboard(self):
        status, calls, copied = self.run_pick(failure="cancel", qs="fail")
        self.assertEqual(status, 0)
        self.assertEqual(calls, ["qs", "slurp"])
        self.assertIsNone(copied)

    def test_slurp_failure_after_fallback_notifies(self):
        status, calls, copied = self.run_pick(failure="slurp", qs="fail")
        self.assertNotEqual(status, 0)
        self.assertIsNone(copied)
        self.assertIn("notify-send", calls)

    def test_point_timeout_cancels(self):
        status, calls, copied = self.run_pick(qs="hang", pick_timeout=1)
        self.assertEqual(status, 0)
        # The mock logs the command name first, so a cancel invocation
        # shows up as "qs" followed by "qs-cancel".
        self.assertEqual(calls, ["qs", "qs", "qs-cancel", "notify-send"])
        self.assertIsNone(copied)

    def test_rofi_dismissal_preserves_clipboard(self):
        status, calls, copied = self.run_pick("rofi")
        self.assertEqual(status, 0)
        self.assertIsNone(copied)
        self.assertIn("rofi", calls)
        self.assertNotIn("wl-copy", calls)

    def test_failures_preserve_clipboard(self):
        for command in ("grim", "magick", "wl-copy"):
            with self.subTest(command=command):
                status, calls, copied = self.run_pick(command)
                self.assertNotEqual(status, 0)
                self.assertIsNone(copied)
                self.assertIn("notify-send", calls)
                # Unexpected exits dismiss the overlay via the trap, so it
                # never keeps the keyboard and the blank cursor.
                self.assertIn("qs-cancel", calls)

    def test_empty_color_preserves_clipboard(self):
        status, calls, copied = self.run_pick(empty=True)
        self.assertEqual(status, 0)
        self.assertNotIn("rofi", calls)
        self.assertNotIn("wl-copy", calls)
        self.assertIsNone(copied)


if __name__ == "__main__":
    unittest.main()
