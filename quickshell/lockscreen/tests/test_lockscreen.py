"""Standard-library regression tests; no compositor or real locking required."""

import json
import os
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


DIRECTORY = Path(__file__).resolve().parents[1]
REPOSITORY = DIRECTORY.parents[1]


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="quickshell-lock-test-")
        self.root = Path(self.directory.name)
        self.processes = []
        for name in ("bin", "runtime", "home/Wallpapers"):
            (self.root / name).mkdir(parents=True)
        self.pam = self.root / "pam"
        self.pam.touch()
        source = (REPOSITORY / "sway/scripts/lockscreen.sh").read_text()
        self.script = self.root / "lock.sh"
        self.script.write_text(
            source.replace("/etc/pam.d/quickshell-lockscreen", str(self.pam))
        )
        self.trace = self.root / "trace"
        self.release = self.root / "release"
        self.env = dict(
            os.environ,
            PATH=str(self.root / "bin") + ":" + os.environ["PATH"],
            HOME=str(self.root / "home"),
            XDG_RUNTIME_DIR=str(self.root / "runtime"),
            TEST_TRACE=str(self.trace),
            TEST_RELEASE=str(self.release),
            TEST_REAL_RM=shutil.which("rm"),
            TEST_MODE="ready",
            QUICKSHELL_LOCK_TIMEOUT="3",
        )
        self.env.pop("SWAYLOCK_VIDEO", None)
        self.mock(
            "qs",
            """import json, os, pathlib, sys, time
secure = pathlib.Path(os.environ["TEST_TRACE"] + ".secure")
if sys.argv[1:] == ["-c", "lockscreen", "ipc", "call", "lock", "isSecure"]:
    mode = os.environ.get("TEST_IPC_MODE", "normal")
    if mode == "hang":
        time.sleep(30)
    if mode == "error":
        sys.exit(1)
    print("invalid" if mode == "invalid" else "true" if secure.exists() else "false")
    sys.exit(0)
with open(os.environ["TEST_TRACE"], "a") as f:
    f.write(json.dumps(["qs", os.environ.get("SWAYLOCK_VIDEO", "")]) + "\\n")
mode = os.environ["TEST_MODE"]
if mode == "fail":
    sys.exit(1)
if mode == "marker-failure":
    print("Could not signal lock readiness", flush=True)
while mode in ("hang", "marker-failure", "late-failure") and not pathlib.Path(os.environ["TEST_RELEASE"]).exists():
    time.sleep(0.05)
if mode == "late-failure":
    sys.exit(1)
time.sleep(0.2)
secure.touch()
pathlib.Path(os.environ["QUICKSHELL_LOCK_READY"]).touch()
time.sleep(30)
""",
        )

    def tearDown(self):
        for process in self.processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            if process.poll() is None:
                process.wait(timeout=3)
        self.directory.cleanup()

    def mock(self, name, body):
        path = self.root / "bin" / name
        path.write_text("#!/usr/bin/env python3\n" + body)
        path.chmod(0o755)

    def start(self):
        process = subprocess.Popen(
            ["bash", str(self.script)],
            env=self.env,
            start_new_session=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.processes.append(process)
        return process

    def finish(self, process):
        _, stderr = process.communicate(timeout=6)
        return process.returncode, stderr

    def calls(self):
        return (
            [json.loads(line) for line in self.trace.read_text().splitlines()]
            if self.trace.exists()
            else []
        )

    def test_readiness_duplicate_requests_without_wallpaper_scanning(self):
        (self.root / "home/Wallpapers/space # & ' ü.mp4").touch()
        self.mock(
            "find",
            """raise SystemExit("Video scan must not precede locking")
""",
        )
        started = time.monotonic()
        first = self.start()
        second = self.start()
        self.assertEqual(self.finish(first)[0], 0)
        self.assertEqual(self.finish(second)[0], 0)
        self.assertGreaterEqual(time.monotonic() - started, 0.2)
        self.assertEqual(self.calls(), [["qs", ""]])
        self.assertEqual(self.finish(self.start())[0], 0)
        self.assertEqual(len(self.calls()), 1)

    def test_standard_swayidle_sleep_integration(self):
        sway = (REPOSITORY / "sway/config").read_text()
        self.assertIn("exec swayidle -w", sway)
        self.assertRegex(sway, r"before-sleep.*lockscreen\.sh")
        configuration = (REPOSITORY / "nixos/configuration.nix").read_text()
        self.assertNotIn("systemd.user.services.lockscreen", configuration)
        self.assertNotIn("systemd.services.lock-before-sleep", configuration)
        layout = (REPOSITORY / "wlogout/layout").read_text()
        self.assertIn('"action" : "systemctl suspend"', layout)
        self.assertIn('"action" : "systemctl hibernate"', layout)

    def test_no_video(self):
        self.assertEqual(self.finish(self.start())[0], 0)
        self.assertEqual(self.calls(), [["qs", ""]])

    def test_startup_failure_is_not_success(self):
        self.env["TEST_MODE"] = "fail"
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("Quickshell lock failed", error)
        self.assertEqual(self.calls(), [["qs", ""]])

    def test_missing_quickshell_is_not_success(self):
        (self.root / "bin/qs").unlink()
        for command in ("bash", "flock"):
            (self.root / "bin" / command).symlink_to(shutil.which(command))
        self.env["PATH"] = str(self.root / "bin")
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("Quickshell and its PAM service are required", error)
        self.assertEqual(self.calls(), [])

    def test_missing_pam_is_not_success(self):
        self.pam.unlink()
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("Quickshell and its PAM service are required", error)
        self.assertEqual(self.calls(), [])

    def test_timeout_keeps_startup_guard_and_allows_late_readiness(self):
        self.env.update(TEST_MODE="hang", QUICKSHELL_LOCK_TIMEOUT="1")
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("readiness timed out", error)
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("another lock startup", error)
        self.assertEqual(self.calls(), [["qs", ""]])
        self.release.touch()
        self.assertEqual(self.finish(self.start())[0], 0)
        self.assertEqual(self.calls(), [["qs", ""]])

    def test_marker_failure_is_bounded(self):
        self.env.update(TEST_MODE="marker-failure", QUICKSHELL_LOCK_TIMEOUT="1")
        self.assertEqual(self.finish(self.start())[0], 1)
        self.assertEqual(self.calls(), [["qs", ""]])
        log = (self.root / "runtime/quickshell-lockscreen.log").read_text()
        self.assertIn("Could not signal lock readiness", log)

    def test_late_failure_keeps_startup_exclusion_through_cleanup(self):
        self.env.update(TEST_MODE="late-failure", QUICKSHELL_LOCK_TIMEOUT="1")
        self.mock(
            "rm",
            """import os, pathlib, subprocess, sys, time
pathlib.Path(os.environ["TEST_TRACE"] + ".cleanup").touch()
while not pathlib.Path(os.environ["TEST_RELEASE"] + ".cleanup").exists():
    time.sleep(0.02)
subprocess.run([os.environ["TEST_REAL_RM"], *sys.argv[1:]], check=True)
""",
        )
        self.assertEqual(self.finish(self.start())[0], 1)
        self.release.touch()
        cleanup_started = Path(str(self.trace) + ".cleanup")
        deadline = time.monotonic() + 3
        while not cleanup_started.exists():
            self.assertLess(time.monotonic(), deadline, "Cleanup did not start")
            time.sleep(0.02)
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("another lock startup", error)
        self.assertEqual(self.calls(), [["qs", ""]])
        Path(str(self.release) + ".cleanup").touch()
        self.env.update(TEST_MODE="ready", QUICKSHELL_LOCK_TIMEOUT="3")
        self.assertEqual(self.finish(self.start())[0], 0)
        self.assertEqual(self.calls(), [["qs", ""], ["qs", ""]])

    def test_lifecycle_guard_after_unlock_is_not_readiness(self):
        self.assertEqual(self.finish(self.start())[0], 0)
        Path(str(self.trace) + ".secure").unlink()
        code, error = self.finish(self.start())
        self.assertEqual(code, 1)
        self.assertIn("secure state could not be confirmed", error)
        self.assertEqual(self.calls(), [["qs", ""]])

    def test_duplicate_ipc_failures_do_not_report_success(self):
        self.assertEqual(self.finish(self.start())[0], 0)
        self.env["QUICKSHELL_LOCK_TIMEOUT"] = "1"
        for mode in ("error", "invalid", "hang"):
            with self.subTest(mode=mode):
                self.env["TEST_IPC_MODE"] = mode
                code, error = self.finish(self.start())
                self.assertEqual(code, 1)
                self.assertIn("secure state could not be confirmed", error)
        self.assertEqual(self.calls(), [["qs", ""]])

    def test_invalid_timeout(self):
        self.env["QUICKSHELL_LOCK_TIMEOUT"] = "0"
        self.assertEqual(self.finish(self.start())[0], 1)
        self.assertEqual(self.calls(), [])


class AuthenticationTests(unittest.TestCase):
    def test_qml_authentication_handlers(self):
        subprocess.run(["node", str(DIRECTORY / "tests/test-auth.js")], check=True)


if __name__ == "__main__":
    unittest.main()
