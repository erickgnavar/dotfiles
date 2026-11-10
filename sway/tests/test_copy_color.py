import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "copy-color.sh"


class CopyColorTests(unittest.TestCase):
    def run_pick(self, failure="", empty=False, choice=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mock = root / "mock"
            mock.write_text("""#!/usr/bin/env bash
name=${0##*/}
printf '%s\\n' "$name" >> "$LOG"
[[ "$FAIL" != "$name" ]] || exit 2
case "$name" in
  slurp)
    [[ "$FAIL" != cancel ]] || exit 1
    printf '100,200 1x1\\n'
    ;;
  grim) touch "$3" ;;
  magick)
    [[ "$FAIL" != empty ]] || exit 0
    printf '4a90d9\\n'
    ;;
  rofi)
    menu=$(cat)
    pick=$(printf '%s\\n' "$menu" | awk -v want="$CHOICE" '$1 == want { print; exit }')
    printf '%s\\n' "${pick:-$(printf '%s\\n' "$menu" | head -n 1)}"
    ;;
  wl-copy) cat > "$COPIED" ;;
esac
""")
            mock.chmod(0o755)
            for name in ("slurp", "grim", "magick", "rofi", "wl-copy", "notify-send"):
                (root / name).symlink_to(mock)
            work = root / "work"
            work.mkdir()
            env = dict(
                os.environ,
                PATH=f"{root}:{os.environ['PATH']}",
                LOG=str(root / "log"),
                COPIED=str(root / "copied"),
                FAIL=("empty" if empty else failure),
                CHOICE=choice,
                TMPDIR=str(work),
            )
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
            self.assertEqual(list(work.iterdir()), [])
            return result.returncode, calls, value

    def test_success_defaults_to_hex(self):
        status, calls, copied = self.run_pick()
        self.assertEqual(status, 0)
        self.assertEqual(copied, "#4a90d9\n")
        for command in ("slurp", "grim", "magick", "rofi", "wl-copy"):
            self.assertIn(command, calls)

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
        self.assertEqual(self.run_pick("cancel"), (0, ["slurp"], None))

    def test_rofi_dismissal_preserves_clipboard(self):
        status, calls, copied = self.run_pick("rofi")
        self.assertEqual(status, 0)
        self.assertIsNone(copied)
        self.assertIn("rofi", calls)
        self.assertNotIn("wl-copy", calls)

    def test_failures_preserve_clipboard(self):
        for command in ("slurp", "grim", "magick", "wl-copy"):
            with self.subTest(command=command):
                status, calls, copied = self.run_pick(command)
                self.assertNotEqual(status, 0)
                self.assertIsNone(copied)
                self.assertIn("notify-send", calls)

    def test_empty_color_preserves_clipboard(self):
        status, calls, copied = self.run_pick(empty=True)
        self.assertEqual(status, 0)
        self.assertNotIn("rofi", calls)
        self.assertNotIn("wl-copy", calls)
        self.assertIsNone(copied)


if __name__ == "__main__":
    unittest.main()
