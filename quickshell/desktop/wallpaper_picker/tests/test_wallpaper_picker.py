"""Wallpaper scanner regressions using isolated, standard-library command mocks."""

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scan.py"

MOCK = r"""
import json
import os
import sys
import time
from pathlib import Path

args = sys.argv[1:]
with open(os.environ["TEST_TRACE"], "a") as trace:
    trace.write(json.dumps(args) + "\n")
with open(os.environ["TEST_PIDS"], "a") as pids:
    pids.write(str(os.getpid()) + "\n")
if os.environ["TEST_FFMPEG_MODE"] == "fail":
    sys.exit(1)
if os.environ["TEST_FFMPEG_MODE"] == "hang":
    Path(args[-1]).write_bytes(b"partial")
    time.sleep(600)  # default SIGTERM handling, like a normal FFmpeg exit
Path(args[-1]).write_bytes(b"still")
time.sleep(float(os.environ.get("TEST_FFMPEG_SLEEP", "0.05")))
"""


def alive(pid):
    return Path(f"/proc/{pid}").exists()


class WallpaperPickerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(
            prefix="quickshell-wallpaper-test-"
        )
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ("bin", "cache", "collection"):
            (self.root / directory).mkdir()
        (self.root / "cache" / "wallpaper-picker").mkdir(parents=True)
        for index, suffix in enumerate((".png", ".jpg", ".webp")):
            (self.root / "collection" / f"image{index}{suffix}").touch()
        for index, suffix in enumerate((".mp4", ".mkv", ".webm")):
            (self.root / "collection" / f"video{index}{suffix}").touch()
        self.trace = self.root / "trace.json"
        self.pids = self.root / "pids.txt"
        self.cache = self.root / "cache" / "wallpaper-picker"
        self.env = dict(
            os.environ,
            PATH=str(self.root / "bin") + ":" + os.environ["PATH"],
            HOME=str(self.root / "home"),
            XDG_CACHE_HOME=str(self.root / "cache"),
            TEST_TRACE=str(self.trace),
            TEST_PIDS=str(self.pids),
            TEST_FFMPEG_MODE="ok",
        )
        mock = self.root / "bin" / "ffmpeg"
        mock.write_text(f"#!{sys.executable}\n" + MOCK)
        mock.chmod(0o755)

    def run_scan(self, timeout=30):
        if self.trace.exists():
            self.trace.unlink()
        process = subprocess.Popen(
            [sys.executable, "-B", str(SCRIPT), str(self.root / "collection")],
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            self.fail("scanner did not exit in time")
        lines = [json.loads(line) for line in stdout.splitlines() if line.strip()]
        self.assertEqual(stderr, "")
        return process.returncode, lines

    def launches(self):
        if not self.trace.exists():
            return []
        return [json.loads(line) for line in self.trace.read_text().splitlines()]

    def discovery(self, lines):
        return [line for line in lines if "video" in line]

    def updates(self, lines):
        return [line for line in lines if "video" not in line]

    def assert_pids_gone(self, pids, limit=10):
        deadline = time.monotonic() + limit
        while time.monotonic() < deadline and any(alive(pid) for pid in pids):
            time.sleep(0.05)
        self.assertEqual([pid for pid in pids if alive(pid)], [])

    def test_cold_scan_schedules_and_reports_every_job(self):
        returncode, lines = self.run_scan()
        self.assertEqual(returncode, 0)
        discovered = self.discovery(lines)
        self.assertEqual(len(discovered), 6)
        for entry in discovered:
            self.assertTrue(Path(entry["path"]).exists())
            if entry["video"]:
                self.assertEqual(entry["thumbnail"], "")
                self.assertEqual(entry["preview"], "")
            else:
                self.assertEqual(entry["thumbnail"], entry["path"])
                self.assertEqual(entry["preview"], entry["path"])
            self.assertFalse(entry["small"])
        launches = self.launches()
        # Three uncached images plus two jobs per video, at two workers.
        self.assertEqual(len(launches), 9)
        thumbnails = [launch for launch in launches if "-vf" in launch]
        previews = [
            launch for launch in launches if "-ss" in launch and "-vf" not in launch
        ]
        images = [launch for launch in launches if "-ss" not in launch]
        self.assertEqual(len(thumbnails), 6)
        self.assertEqual(len(previews), 3)
        self.assertEqual(len(images), 3)
        updates = self.updates(lines)
        self.assertEqual(len(updates), 9)
        for update in updates:
            self.assertTrue(
                Path(update.get("thumbnail") or update.get("preview")).is_file()
            )
        self.assertEqual(
            len([update for update in updates if "thumbnail" in update]), 6
        )
        self.assertEqual(len([update for update in updates if "preview" in update]), 3)

    def test_warm_scan_launches_no_media_jobs(self):
        returncode, lines = self.run_scan()
        self.assertEqual(returncode, 0)
        self.assertEqual(len(self.launches()), 9)
        returncode, lines = self.run_scan()
        self.assertEqual(returncode, 0)
        self.assertEqual(self.launches(), [])
        discovered = self.discovery(lines)
        self.assertEqual(len(discovered), 6)
        for entry in discovered:
            self.assertTrue(entry["small"])
            if not entry["video"]:
                self.assertEqual(entry["preview"], entry["path"])
            elif entry["thumbnail"]:
                self.assertTrue(Path(entry["preview"]).is_file())

    def test_failed_jobs_leave_discovery_and_earlier_results_usable(self):
        self.env["TEST_FFMPEG_MODE"] = "fail"
        returncode, lines = self.run_scan()
        self.assertEqual(returncode, 0)
        self.assertEqual(len(self.launches()), 9)
        self.assertEqual(len(self.discovery(lines)), 6)
        self.assertEqual(self.updates(lines), [])
        temp_files = list(self.cache.glob("*.tmp*"))
        self.assertEqual(temp_files, [])

    def test_cancel_reaps_media_children_and_temps(self):
        self.env["TEST_FFMPEG_MODE"] = "hang"
        process = subprocess.Popen(
            [sys.executable, "-B", str(SCRIPT), str(self.root / "collection")],
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and len(self.launches()) < 2:
                time.sleep(0.05)
            self.assertGreaterEqual(len(self.launches()), 2)
            pids = [int(line) for line in self.pids.read_text().splitlines()]
            running = [pid for pid in pids if alive(pid)]
            self.assertLessEqual(len(running), 2)
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=10)
        finally:
            try:
                process.kill()
                process.wait(timeout=5)
            except (OSError, ValueError, subprocess.TimeoutExpired):
                pass
        # The scanner terminates the media children itself and exits cleanly.
        self.assertEqual(process.returncode, 0)
        self.assert_pids_gone(pids)
        temp_files = list(self.cache.glob("*.tmp*"))
        self.assertEqual(temp_files, [])


if __name__ == "__main__":
    unittest.main()
