"""Stream-copy backend regressions; no desktop or FFmpeg installation required."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "trim.py"
SPEC = importlib.util.spec_from_file_location("capture_trim", SCRIPT)
TRIM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRIM)


class TrimTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.file = self.root / "recording with spaces; $(false).mp4"
        self.file.write_bytes(b"original")
        self.trace = self.root / "trace"
        self.pidfile = self.root / "pid"
        for name in ("ffprobe", "ffmpeg"):
            mock = self.root / name
            mock.write_text(
                f"#!{sys.executable}\n"
                "import json, os, signal, sys, time\n"
                "from pathlib import Path\n"
                "with open(os.environ['TRACE'], 'a') as out:\n"
                "    out.write(json.dumps(sys.argv) + '\\n')\n"
                "if Path(sys.argv[0]).name == 'ffprobe':\n"
                "    print(json.dumps({'format': {'duration': os.getenv('DURATION', '12.5')},\n"
                "                      'streams': [{'codec_type': os.getenv('STREAM', 'video')}]}))\n"
                "else:\n"
                "    Path(sys.argv[-1]).write_bytes(b'trimmed')\n"
                "    if os.getenv('HANG'):\n"
                "        signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                "        Path(os.environ['PIDFILE']).write_text(str(os.getpid()))\n"
                "        time.sleep(30)\n"
                "    if os.getenv('FAIL'): sys.exit(1)\n"
            )
            mock.chmod(0o755)
        self.env = dict(
            os.environ,
            PATH=f"{self.root}:{os.environ['PATH']}",
            TRACE=str(self.trace),
            PIDFILE=str(self.pidfile),
        )

    def invoke(self, mode, *args, **env):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), mode, str(self.file), *args],
            env=dict(self.env, **env),
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result, json.loads(result.stdout)

    def outputs(self):
        return list(self.root.glob("*-trimmed-*.mp4"))

    def test_probe_and_uri(self):
        result, data = self.invoke("probe")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(data, {"duration": 12.5, "url": self.file.as_uri()})

    def test_trim_preserves_original_and_uses_unique_paths(self):
        names = []
        for _ in range(2):
            result, data = self.invoke("trim", "2", "6")
            self.assertEqual(result.returncode, 0, data)
            output = Path(data["file"])
            self.assertEqual(output.read_bytes(), b"trimmed")
            self.assertEqual(output.parent, self.file.parent)
            names.append(output)
        self.assertNotEqual(*names)
        self.assertEqual(self.file.read_bytes(), b"original")
        calls = [json.loads(line) for line in self.trace.read_text().splitlines()]
        command = calls[1]
        self.assertEqual(command[command.index("-i") + 1], str(self.file))
        self.assertEqual(command[command.index("-ss") + 1], "2.0")
        self.assertEqual(command[command.index("-t") + 1], "4.0")
        self.assertEqual(command[command.index("-c") + 1], "copy")
        self.assertIn("0:a?", command)

    def test_invalid_ranges(self):
        for start, end in (
            ("-1", "3"),
            ("3", "3"),
            ("4", "3"),
            ("0", "13"),
            ("nan", "3"),
            ("0", "inf"),
            ("x", "3"),
        ):
            with self.subTest(start=start, end=end):
                result, data = self.invoke("trim", start, end)
                self.assertEqual(result.returncode, 1)
                self.assertIn("error", data)
                self.assertEqual(self.outputs(), [])

    def test_invalid_media(self):
        for env in ({"DURATION": "nan"}, {"DURATION": "0"}, {"STREAM": "audio"}):
            result, data = self.invoke("probe", **env)
            self.assertEqual(result.returncode, 1)
            self.assertIn("error", data)

    def test_failure_removes_partial_output(self):
        result, data = self.invoke("trim", "1", "4", FAIL="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("error", data)
        self.assertEqual(self.outputs(), [])
        self.assertEqual(self.file.read_bytes(), b"original")

    def test_cancel_kills_ignoring_worker_and_removes_output(self):
        process = subprocess.Popen(
            [sys.executable, str(SCRIPT), "trim", str(self.file), "1", "4"],
            env=dict(self.env, HANG="1"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            deadline = time.monotonic() + 3
            while not self.pidfile.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(self.pidfile.exists())
            pid = int(self.pidfile.read_text())
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=3)
            self.assertEqual(process.returncode, 130)
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)
            self.assertEqual(self.outputs(), [])
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_worker_deadline(self):
        pidfile = self.root / "timeout-pid"
        command = [
            sys.executable,
            "-c",
            "import os,time; from pathlib import Path; "
            f"Path({str(pidfile)!r}).write_text(str(os.getpid())); time.sleep(30)",
        ]
        with self.assertRaises(subprocess.TimeoutExpired):
            TRIM.run(command, 0.3)
        with self.assertRaises(ProcessLookupError):
            os.kill(int(pidfile.read_text()), 0)

    def test_trim_timeout_removes_partial_output(self):
        original = TRIM.run
        with (
            mock.patch.dict(os.environ, dict(self.env, HANG="1")),
            mock.patch.object(
                TRIM, "run", side_effect=lambda cmd, timeout: original(cmd, 0.3)
            ),
            self.assertRaises(subprocess.TimeoutExpired),
        ):
            TRIM.trim(self.file, 1, 4, 12.5)
        self.assertEqual(self.outputs(), [])
        with self.assertRaises(ProcessLookupError):
            os.kill(int(self.pidfile.read_text()), 0)

    def test_missing_file(self):
        self.file.unlink()
        result, data = self.invoke("probe")
        self.assertEqual(result.returncode, 1)
        self.assertIn("error", data)

    def test_independent_playhead(self):
        qml = SCRIPT.with_name("Trimmer.qml").read_text()
        seek = qml.split("function seekAt(x) {", 1)[1].split("\n                }", 1)[
            0
        ]
        self.assertIn("player.pause()", seek)
        self.assertIn("player.position = Math.max(0, Math.min(1,", seek)
        self.assertNotIn("setValues", seek)
        self.assertNotIn(".value =", seek)
        self.assertIn("limits.seekAt(mouse.x)", qml)
        self.assertIn("mouse.accepted = false", qml)
        self.assertIn("Math.abs(mouse.x - startX) <= 10", qml)
        self.assertIn("Math.abs(mouse.x - endX) <= 10", qml)
        self.assertIn("if (pressed)", qml)
        self.assertIn("player.position / (shell.duration * 1000)", qml)
        self.assertIn('sequence: "Space"', qml)
        self.assertIn("onActivated: shell.togglePlayback()", qml)
        self.assertIn("onClicked: shell.togglePlayback()", qml)

    def test_dialog_wiring(self):
        qml = SCRIPT.with_name("Trimmer.qml").read_text()
        self.assertIn('target: "trimmer"', qml)
        self.assertIn("VideoOutput", qml)
        self.assertIn("Layout.minimumHeight: 320", qml)
        self.assertIn("implicitHeight: 32", qml)
        self.assertIn("property bool primary: false", qml)
        self.assertIn(
            'text: "Save trimmed copy"\n                    primary: true', qml
        )
        self.assertIn("worker.signal(15)", qml)
        self.assertIn("onClosed: shell.close()", qml)
        self.assertNotIn("TextField", qml)
        self.assertIn("RangeSlider {", qml)
        self.assertNotIn("\n            Slider {", qml)
        self.assertIn("shell.formatTime(player.position / 1000)", qml)
        self.assertIn("shell.formatTime(shell.endTime - shell.startTime)", qml)
        self.assertIn("first.handle: Rectangle", qml)
        self.assertIn("second.handle: Rectangle", qml)
        self.assertIn("limits.second.visualPosition - limits.first.visualPosition", qml)
        self.assertIn("position >= shell.endTime * 1000", qml)
        self.assertIn("player.position = shell.startTime * 1000", qml)
        self.assertIn("readonly property real startTime: limits.first.value", qml)
        self.assertIn("readonly property real endTime: limits.second.value", qml)
        self.assertNotIn("first.onMoved:", qml)
        self.assertNotIn("second.onMoved:", qml)
        self.assertNotIn("player.position = first.value * 1000", qml)
        self.assertNotIn("player.position = second.value * 1000", qml)
        labels = qml.split('text: "Start: "', 1)[0].rsplit("RowLayout {", 1)[1]
        labels += qml.split('text: "Start: "', 1)[1].split('text: "End: "', 1)[0]
        self.assertEqual(labels.count("Layout.preferredWidth: 0"), 3)
        self.assertIn("horizontalAlignment: Text.AlignRight", labels)
        self.assertIn("limits.setValues(0, result.duration)", qml)
        config = SCRIPT.parents[3].joinpath("sway/config").read_text()
        self.assertIn(
            '[title="^Trim recording$"] floating enable, move position center', config
        )
        self.assertIn('player.source = ""', qml)
        self.assertIn(
            "Trimmer { }", SCRIPT.parents[1].joinpath("shell.qml").read_text()
        )


@unittest.skipUnless(
    shutil.which("ffmpeg") and shutil.which("ffprobe"), "FFmpeg unavailable"
)
class RealMediaTests(unittest.TestCase):
    def test_video_with_audio(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "original.mp4"
            subprocess.run(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    "color=s=64x64:r=10",
                    "-f",
                    "lavfi",
                    "-i",
                    "sine=frequency=440",
                    "-t",
                    "2",
                    "-c:v",
                    "mpeg4",
                    "-c:a",
                    "aac",
                    str(file),
                ],
                check=True,
                timeout=15,
            )
            before = file.read_bytes()
            output = TRIM.trim(file, 0, 1, TRIM.probe(file))
            self.assertGreater(TRIM.probe(Path(output)), 0)
            streams = json.loads(
                TRIM.run(
                    [
                        "ffprobe",
                        "-v",
                        "error",
                        "-show_entries",
                        "stream=codec_type",
                        "-of",
                        "json",
                        output,
                    ],
                    5,
                )
            )["streams"]
            self.assertEqual({s["codec_type"] for s in streams}, {"video", "audio"})
            self.assertEqual(file.read_bytes(), before)
