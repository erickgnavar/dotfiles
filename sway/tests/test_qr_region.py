import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "qr-region.sh"


class RegionQrTests(unittest.TestCase):
    def run_qr(self, failure="", text="https://example.com/\n"):
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
    [[ "$FAIL" != empty ]] || exit 0
    printf '10,20 300x100\\n'
    ;;
  grim) touch "$3" ;;
  zbarimg)
    [[ "$*" == *"--raw --set *.disable --set qrcode.enable"* ]] || exit 3
    [[ "$FAIL" != missing ]] || exit 4
    printf '%s' "$TEXT"
    ;;
  wl-copy) cat > "$COPIED" ;;
esac
""")
            mock.chmod(0o755)
            for name in ("slurp", "grim", "zbarimg", "wl-copy", "notify-send"):
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
        status, calls, copied = self.run_qr()
        self.assertEqual(status, 0)
        self.assertEqual(copied, "https://example.com/\n")
        self.assertIn("wl-copy", calls)

    def test_multiple_codes(self):
        text = "first\nsecond\n"
        self.assertEqual(self.run_qr(text=text)[2], text)

    def test_cancel_and_empty_selection(self):
        for failure in ("cancel", "empty"):
            self.assertEqual(self.run_qr(failure), (0, ["slurp"], None))

    def test_no_code_preserves_clipboard(self):
        for failure, text in (("missing", "unused"), ("", "")):
            status, calls, copied = self.run_qr(failure, text)
            self.assertEqual(status, 0)
            self.assertNotIn("wl-copy", calls)
            self.assertIsNone(copied)

    def test_failures_preserve_clipboard(self):
        for command in ("slurp", "grim", "zbarimg", "wl-copy"):
            with self.subTest(command=command):
                status, calls, copied = self.run_qr(command)
                self.assertNotEqual(status, 0)
                self.assertIsNone(copied)
                self.assertIn("notify-send", calls)

    def test_notification_failure_is_harmless(self):
        self.assertEqual(self.run_qr("notify-send")[0], 0)


if __name__ == "__main__":
    unittest.main()
