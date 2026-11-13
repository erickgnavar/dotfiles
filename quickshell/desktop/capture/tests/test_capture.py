"""Capture backend regressions using isolated, standard-library command mocks."""

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "capture.sh"
MOCK = r"""
import json
import os
import signal
import sys
import time
from pathlib import Path

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_TRACE"], "a") as trace:
    trace.write(json.dumps([name, *args]) + "\n")
if name == "slurp":
    assert sys.stdin.read() == ""
    print(os.environ["TEST_GEOMETRY"])
    print(os.environ["TEST_SELECTION_ERROR"], file=sys.stderr, end="")
    sys.exit(int(os.environ["TEST_SELECTION_STATUS"]))
elif name == "swaymsg":
    print('[{"name":"HDMI-A-2","focused":true}]')
elif name == "jq":
    outputs = json.load(sys.stdin)
    print(next((output["name"] for output in outputs if output["focused"]), ""))
elif name == "grim":
    Path(args[-1]).write_bytes(b"original")
elif name == "wl-copy":
    Path(os.environ["TEST_CLIPBOARD"]).write_bytes(sys.stdin.buffer.read())
elif name == "notify-send":
    sys.exit(int(os.environ["TEST_NOTIFY_STATUS"]))
elif name == "swappy":
    assert sys.stdin.read() == ""
    assert args == ["-f", args[1], "-o", args[1]]
    Path(args[3]).write_bytes(b"annotated")
elif name == "wf-recorder":
    if os.environ["TEST_RECORDER_FAIL"] == "1":
        sys.exit(1)
    def stop(signum, frame):
        Path(os.environ["TEST_STOPPED"]).touch()
        sys.exit(0)
    Path(os.environ["TEST_RECORDER_PID"]).write_text(str(os.getpid()))
    mode = os.environ["TEST_RECORDER_MODE"]
    signal.signal(signal.SIGINT, signal.SIG_IGN if mode != "normal" else stop)
    signal.signal(signal.SIGTERM, signal.SIG_IGN if mode == "ignore-both" else stop)
    Path(args[args.index("-f") + 1]).touch()
    while True:
        time.sleep(0.05)
"""


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="quickshell-capture-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ("bin", "home", "runtime", "tmp"):
            (self.root / directory).mkdir()
        self.env = dict(
            os.environ,
            PATH=str(self.root / "bin") + ":" + os.environ["PATH"],
            HOME=str(self.root / "home"),
            XDG_RUNTIME_DIR=str(self.root / "runtime"),
            TMPDIR=str(self.root / "tmp"),
            TEST_TRACE=str(self.root / "trace"),
            TEST_CLIPBOARD=str(self.root / "clipboard"),
            TEST_STOPPED=str(self.root / "stopped"),
            TEST_GEOMETRY="-100,50 640x480",
            TEST_SELECTION_ERROR="",
            TEST_SELECTION_STATUS="0",
            TEST_NOTIFY_STATUS="0",
            TEST_RECORDER_FAIL="0",
            TEST_RECORDER_MODE="normal",
            TEST_RECORDER_PID=str(self.root / "recorder.pid"),
        )
        for command in (
            "slurp",
            "swaymsg",
            "jq",
            "grim",
            "wl-copy",
            "notify-send",
            "swappy",
            "wf-recorder",
            "pkill",
        ):
            mock = self.root / "bin" / command
            mock.write_text(f"#!{sys.executable}\n" + MOCK)
            mock.chmod(0o755)

    def run_capture(
        self,
        kind="screenshot",
        area="region",
        audio="silent",
        source="default",
        request="",
    ):
        process = subprocess.Popen(
            ["bash", str(SCRIPT), kind, area, audio, source],
            env=self.env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        try:
            stdout, stderr = process.communicate(request, timeout=12)
        finally:
            # Also reap a mocked recorder if a regression leaves it running.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        self.assertEqual(list((self.root / "tmp").iterdir()), [])
        return process.returncode, stdout, stderr

    def calls(self, command):
        trace = self.root / "trace"
        entries = (
            [json.loads(line) for line in trace.read_text().splitlines()]
            if trace.exists()
            else []
        )
        return [entry[1:] for entry in entries if entry[0] == command]

    def test_invalid_arguments(self):
        self.assertEqual(self.run_capture(kind="invalid")[0], 2)
        self.assertFalse((self.root / "trace").exists())

    def test_ui_can_enable_recording_audio(self):
        source = SCRIPT.with_name("Capture.qml").read_text()
        self.assertIn("import Quickshell.Services.Pipewire", source)
        self.assertIn('text: "Include audio"', source)
        self.assertIn('visible: shell.kind === "record"', source)
        self.assertNotIn("annotate", source)
        self.assertNotIn("Annotate in Swappy", source)
        self.assertIn('label: "Default microphone", name: "default"', source)
        self.assertIn('!node.name.endsWith(".monitor")', source)
        self.assertIn('audioSourcePicker.currentValue || "default"', source)
        self.assertIn('color: audioSourcePicker.down ? "#64727d"', source)
        self.assertIn("visible: shell.recording && outline.region !== null", source)
        self.assertIn("color: sourceOption.highlighted", source)
        self.assertIn("text: sourceOption.modelData.label", source)
        self.assertNotIn("region.x - 2 < screen.x", source)

    def test_cancel_is_silent(self):
        self.env.update(
            TEST_SELECTION_STATUS="1", TEST_SELECTION_ERROR="selection cancelled\n"
        )
        self.assertEqual(self.run_capture()[0], 0)
        self.assertEqual(self.calls("notify-send"), [])
        self.assertEqual(self.calls("grim"), [])

    def test_selection_failure_preserves_status_and_diagnostic(self):
        self.env.update(
            TEST_SELECTION_STATUS="2", TEST_SELECTION_ERROR="display unavailable\n"
        )
        status, _, stderr = self.run_capture()
        self.assertEqual(status, 2)
        self.assertIn("display unavailable", stderr)
        self.assertIn("display unavailable", self.calls("notify-send")[0])
        self.assertEqual(self.calls("grim"), [])

    def test_selection_failure_without_diagnostic(self):
        self.env["TEST_SELECTION_STATUS"] = "3"
        self.assertEqual(self.run_capture()[0], 3)
        self.assertIn("slurp exited with status 3.", self.calls("notify-send")[0])

    def test_empty_selection_fails(self):
        self.env["TEST_GEOMETRY"] = ""
        self.assertEqual(self.run_capture()[0], 1)
        self.assertEqual(self.calls("grim"), [])

    def test_plain_screenshot(self):
        self.assertEqual(self.run_capture()[0], 0)
        files = list((self.root / "home/Pictures/Screenshots").glob("*.png"))
        self.assertEqual(len(files), 1)
        self.assertEqual(files[0].read_bytes(), b"original")
        self.assertEqual((self.root / "clipboard").read_bytes(), b"original")
        self.assertEqual(self.calls("grim")[0][:2], ["-g", "-100,50 640x480"])
        self.assertEqual(self.calls("swappy"), [])

    def test_screenshot_survives_notification_failure(self):
        self.env["TEST_NOTIFY_STATUS"] = "1"
        self.assertEqual(self.run_capture(request="stop\n")[0], 0)
        files = list((self.root / "home/Pictures/Screenshots").glob("*.png"))
        self.assertEqual(len(files), 1)
        self.assertEqual(files[0].read_bytes(), b"original")
        self.assertEqual((self.root / "clipboard").read_bytes(), b"original")
        self.assertEqual(self.calls("swappy"), [])

    def test_focused_screen_screenshot(self):
        self.assertEqual(self.run_capture(area="screen")[0], 0)
        self.assertEqual(self.calls("grim")[0][:2], ["-o", "HDMI-A-2"])
        self.assertEqual(self.calls("slurp"), [])

    def test_recording_stop_and_eof(self):
        for request in ("stop\n", "", "ignored\nstop\n"):
            with self.subTest(request=request):
                self.env["TEST_NOTIFY_STATUS"] = "1"
                status, stdout, stderr = self.run_capture(
                    kind="record", request=request
                )
                self.assertEqual(status, 0, stderr)
                self.assertEqual(
                    stdout.splitlines(), ["REGION -100,50 640x480", "RECORDING"]
                )
                self.assert_recorder_gone()
                self.assertTrue((self.root / "stopped").exists())
                (self.root / "stopped").unlink()
                self.assertFalse(
                    (self.root / "runtime/quickshell-recording.pid").exists()
                )
        self.assertTrue(self.calls("pkill"))

    def test_screen_recording_has_no_region_message(self):
        status, stdout, stderr = self.run_capture(
            kind="record", area="screen", request="stop\n"
        )
        self.assertEqual(status, 0, stderr)
        self.assertEqual(stdout.splitlines(), ["RECORDING"])
        self.assertEqual(self.calls("wf-recorder")[0][:2], ["-o", "HDMI-A-2"])
        self.assertNotIn("--audio", self.calls("wf-recorder")[0])
        self.assertFalse((self.root / "runtime/quickshell-recording.pid").exists())

    def test_recording_can_include_audio(self):
        status, _, stderr = self.run_capture(
            kind="record", area="screen", audio="audio", request="stop\n"
        )
        self.assertEqual(status, 0, stderr)
        self.assertIn("--audio", self.calls("wf-recorder")[0])

    def test_recording_can_select_audio_source(self):
        source = "alsa_input.usb-example_microphone.mono-fallback"
        status, _, stderr = self.run_capture(
            kind="record",
            area="screen",
            audio="audio",
            source=source,
            request="stop\n",
        )
        self.assertEqual(status, 0, stderr)
        self.assertIn(f"--audio={source}", self.calls("wf-recorder")[0])
        self.assertNotIn("--audio", self.calls("wf-recorder")[0])

    def assert_recorder_gone(self):
        pid = int((self.root / "recorder.pid").read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)
        self.assertFalse((self.root / "runtime/quickshell-recording.pid").exists())

    def test_stop_escalates_to_term_and_kill(self):
        for mode, diagnostic in (
            ("ignore-int", "sending SIGTERM"),
            ("ignore-both", "sending SIGKILL"),
        ):
            with self.subTest(mode=mode):
                self.env["TEST_RECORDER_MODE"] = mode
                started = time.monotonic()
                status, _, stderr = self.run_capture(kind="record", request="stop\n")
                self.assertNotEqual(status, 0)
                self.assertLess(time.monotonic() - started, 11)
                self.assertIn(diagnostic, stderr)
                self.assert_recorder_gone()
                self.assertFalse(
                    any("Recording saved" in call for call in self.calls("notify-send"))
                )

    def test_eof_escalates_for_unresponsive_recorder(self):
        self.env["TEST_RECORDER_MODE"] = "ignore-int"
        status, _, stderr = self.run_capture(kind="record")
        self.assertNotEqual(status, 0)
        self.assertIn("sending SIGTERM", stderr)
        self.assert_recorder_gone()

    def test_backend_termination_reaps_recorder(self):
        for ready, mode in ((False, "normal"), (True, "normal"), (True, "ignore-both")):
            with self.subTest(after_recording_message=ready, mode=mode):
                self.env["TEST_RECORDER_MODE"] = mode
                process = subprocess.Popen(
                    ["bash", str(SCRIPT), "record", "region"],
                    env=self.env,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    start_new_session=True,
                )
                try:
                    deadline = time.monotonic() + 4
                    # Wait for handlers to be installed, but not necessarily RECORDING.
                    while True:
                        if ready:
                            started = bool(self.calls("pkill"))
                        else:
                            started = any(
                                (self.root / "home/Videos/Recordings").glob("*.mp4")
                            )
                        if started:
                            break
                        self.assertLess(time.monotonic(), deadline)
                        time.sleep(0.01)
                    process.terminate()
                    _, stderr = process.communicate(timeout=12)
                    self.assertEqual(process.returncode, 130, stderr)
                    self.assert_recorder_gone()
                finally:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait()
                # Do not let the previous run satisfy the next readiness check.
                (self.root / "trace").unlink()
                for file in (self.root / "home/Videos/Recordings").glob("*.mp4"):
                    file.unlink()

    def test_recorder_startup_failure(self):
        self.env["TEST_RECORDER_FAIL"] = "1"
        status, stdout, _ = self.run_capture(kind="record")
        self.assertNotEqual(status, 0)
        self.assertEqual(stdout, "")
        self.assertFalse((self.root / "runtime/quickshell-recording.pid").exists())
        self.assertIn("Capture failed", self.calls("notify-send")[0])


if __name__ == "__main__":
    unittest.main()
