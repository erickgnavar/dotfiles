import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/session-init.sh"


class SessionInitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        self.trace = root / "trace"
        self.env = dict(
            os.environ,
            HOME=str(root),
            XDG_RUNTIME_DIR=str(root),
            SWAYSOCK="/run/user/1000/sway-ipc.1000.123.sock",
            PATH=f"{bin_dir}:{os.environ['PATH']}",
            TRACE=str(self.trace),
        )
        for name, body in {
            "dbus-update-activation-environment": 'echo "import $*" >> "$TRACE"; exit "${IMPORT_STATUS:-0}"',
            "systemctl": 'echo "picker $*" >> "$TRACE"; exit "${PICKER_STATUS:-0}"',
        }.items():
            path = bin_dir / name
            path.write_text(f"#!/bin/sh\n{body}\n")
            path.chmod(0o755)
        wallpaper = root / ".config/sway/scripts/wallpaper.sh"
        wallpaper.parent.mkdir(parents=True)
        wallpaper.write_text('echo "wallpaper $*" >> "$TRACE"\n')

    def run_init(self):
        return subprocess.run(
            ["bash", str(SCRIPT)], env=self.env, capture_output=True, text=True
        )

    def events(self):
        return self.trace.read_text().splitlines()

    def test_startup_order_and_reload(self):
        self.assertEqual(self.run_init().returncode, 0)
        self.assertEqual(self.run_init().returncode, 0)
        self.assertEqual(
            self.events(),
            [
                "import --systemd WAYLAND_DISPLAY SWAYSOCK XDG_SESSION_TYPE",
                "picker --user restart clipboard-picker.service",
                "wallpaper --restore",
                "import --systemd WAYLAND_DISPLAY SWAYSOCK XDG_SESSION_TYPE",
            ],
        )

    def test_new_session_initializes_again(self):
        self.assertEqual(self.run_init().returncode, 0)
        self.env["SWAYSOCK"] = "/run/user/1000/sway-ipc.1000.456.sock"
        self.assertEqual(self.run_init().returncode, 0)
        self.assertEqual(self.events().count("wallpaper --restore"), 2)

    def test_picker_failure_does_not_skip_wallpaper(self):
        self.env["PICKER_STATUS"] = "1"
        result = self.run_init()
        self.assertEqual(result.returncode, 0)
        self.assertIn("Failed to restart", result.stderr)
        self.assertEqual(self.events()[-1], "wallpaper --restore")

    def test_import_failure_can_be_retried(self):
        self.env["IMPORT_STATUS"] = "1"
        self.assertNotEqual(self.run_init().returncode, 0)
        self.assertEqual(len(self.events()), 1)
        self.env["IMPORT_STATUS"] = "0"
        self.assertEqual(self.run_init().returncode, 0)
        self.assertEqual(self.events()[-1], "wallpaper --restore")


if __name__ == "__main__":
    unittest.main()
