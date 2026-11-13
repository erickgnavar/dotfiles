"""Notification actions dispatch saved captures without shell interpretation."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "notify-capture.sh"


class CaptureNotificationTests(unittest.TestCase):
    def test_actions(self):
        for kind, action, command in (
            ("screenshot", "open", "xdg-open"),
            ("screenshot", "edit", "swappy"),
            ("screenshot", "reveal", "nautilus"),
            ("screenshot", "share", "localsend_app"),
            ("record", "open", "xdg-open"),
            ("record", "trim", "qs"),
            ("screenshot", "trim", None),
            ("record", "reveal", "nautilus"),
            ("record", "share", "localsend_app"),
            ("record", "", None),
            ("screenshot", "unknown", None),
            ("record", "edit", None),
        ):
            with (
                self.subTest(kind=kind, action=action),
                tempfile.TemporaryDirectory() as tmp,
            ):
                root = Path(tmp)
                file = root / "capture with spaces; $(false).png"
                file.touch()
                trace = root / "trace"
                for name in (
                    "notify-send",
                    "xdg-open",
                    "swappy",
                    "nautilus",
                    "localsend_app",
                    "qs",
                ):
                    mock = root / name
                    mock.write_text(
                        f"#!{sys.executable}\n"
                        "import json, os, sys\n"
                        "from pathlib import Path\n"
                        "name = Path(sys.argv[0]).name\n"
                        "with open(os.environ['TRACE'], 'a') as out:\n"
                        "    out.write(json.dumps([name, *sys.argv[1:]]) + '\\n')\n"
                        "if name == 'notify-send': print(os.environ['ACTION'])\n"
                    )
                    mock.chmod(0o755)
                result = subprocess.run(
                    ["bash", str(SCRIPT), kind, str(file)],
                    env=dict(
                        os.environ,
                        PATH=f"{root}:{os.environ['PATH']}",
                        TRACE=str(trace),
                        ACTION=action,
                    ),
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                self.assertEqual(
                    result.returncode,
                    2
                    if (action, kind) in (("edit", "record"), ("trim", "screenshot"))
                    else 0,
                )
                calls = [json.loads(line) for line in trace.read_text().splitlines()]
                self.assertIn("--action=share=Share via LocalSend", calls[0])
                self.assertEqual(
                    "--action=edit=Edit in Swappy" in calls[0], kind == "screenshot"
                )
                self.assertEqual("--action=trim=Trim" in calls[0], kind == "record")
                self.assertEqual(len(calls), 2 if command else 1)
                if command:
                    self.assertEqual(calls[1][0], command)
                    self.assertEqual(calls[1][-1], str(file))
                    if command == "swappy":
                        self.assertEqual(
                            calls[1][1:], ["-f", str(file), "-o", str(file)]
                        )
                    if command == "qs":
                        self.assertEqual(
                            calls[1][1:-1],
                            ["-c", "desktop", "ipc", "call", "trimmer", "open"],
                        )
                    if command == "nautilus":
                        self.assertEqual(calls[1][1], "--select")

    def test_missing_file(self):
        result = subprocess.run(
            ["bash", str(SCRIPT), "record", "/nonexistent/capture.mp4"],
            capture_output=True,
            timeout=5,
        )
        self.assertEqual(result.returncode, 2)
