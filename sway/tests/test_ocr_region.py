import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "ocr-region.sh"


class RegionOcrTests(unittest.TestCase):
    def run_ocr(self, failure="", text="Recognized text\n"):
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
    printf '10,20 300x100\\n'
    ;;
  grim) touch "$3" ;;
  tesseract) printf '%s' "$TEXT" > "$2.txt" ;;
  wl-copy) cat > "$COPIED" ;;
esac
""")
            mock.chmod(0o755)
            for name in ("slurp", "grim", "tesseract", "wl-copy", "notify-send"):
                (root / name).symlink_to(mock)
            work = root / "work"
            work.mkdir()
            env = dict(
                os.environ,
                PATH=f"{root}:{os.environ['PATH']}",
                LOG=str(root / "log"),
                COPIED=str(root / "copied"),
                FAIL=failure,
                TEXT=text,
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

    def test_success(self):
        status, calls, copied = self.run_ocr()
        self.assertEqual(status, 0)
        self.assertEqual(copied, "Recognized text\n")
        self.assertIn("wl-copy", calls)

    def test_cancel(self):
        self.assertEqual(self.run_ocr("cancel"), (0, ["slurp"], None))

    def test_failures_preserve_clipboard(self):
        for command in ("slurp", "grim", "tesseract", "wl-copy"):
            with self.subTest(command=command):
                status, calls, copied = self.run_ocr(command)
                self.assertNotEqual(status, 0)
                self.assertIsNone(copied)
                self.assertIn("notify-send", calls)

    def test_empty_text_preserves_clipboard(self):
        status, calls, copied = self.run_ocr(text=" \n\t")
        self.assertEqual(status, 0)
        self.assertNotIn("wl-copy", calls)
        self.assertIsNone(copied)


if __name__ == "__main__":
    unittest.main()
