import importlib.util
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "processes",
    Path(__file__).resolve().parents[1] / "scripts/processes.py",
)
processes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(processes)


class ProcessesTests(unittest.TestCase):
    def test_snapshot_parses_names_cpu_and_rss(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            process = root / "42"
            process.mkdir()
            fields = ["0"] * 22
            fields[0] = "S"
            fields[11], fields[12] = "20", "30"
            fields[19], fields[21] = "123", "256"
            (process / "stat").write_text('42 (a ) tricky "name) ' + " ".join(fields))
            (root / "43").mkdir()  # A process that exited before stat was read.
            result = processes.snapshot(root)
            self.assertEqual(result[42][:3], ("123", 'a ) tricky "name', 50))
            self.assertEqual(result[42][3], 256 * processes.PAGE_MIB)
            self.assertNotIn(43, result)

    def test_interval_cpu_can_exceed_one_core(self):
        previous = {42: ("123", "worker", 10, 1)}
        current = {42: ("123", "worker", 10 + 4 * processes.TICKS, 12.34)}
        rows = processes.top_processes(previous, current, 2)
        self.assertEqual(
            rows, [{"pid": 42, "name": "worker", "cpu": 200.0, "memory": 12.3}]
        )

    def test_skips_new_and_reused_pids(self):
        previous = {1: ("old", "old", 100, 0)}
        current = {1: ("new", "new", 200, 0), 2: ("new", "new", 500, 0)}
        self.assertEqual(processes.top_processes(previous, current, 2), [])

    def test_memory_sort_includes_new_processes(self):
        previous = {1: ("start", "busy", 0, 1)}
        current = {
            1: ("start", "busy", 200, 1),
            2: ("new", "large", 0, 100),
            3: ("new", "medium", 0, 50),
        }
        rows = processes.top_processes(previous, current, 2, "memory")
        self.assertEqual([row["pid"] for row in rows], [2, 3, 1])
        self.assertEqual(rows[0]["memory"], 100)
        self.assertEqual(rows[0]["cpu"], 0)

    def test_sorted_top_ten_and_nonnegative_cpu(self):
        previous = {pid: ("start", "worker", 1, 0) for pid in range(20)}
        current = {pid: ("start", "worker", pid, 0) for pid in range(20)}
        rows = processes.top_processes(previous, current, 2)
        self.assertEqual([row["pid"] for row in rows], list(range(19, 9, -1)))
        self.assertEqual(
            processes.top_processes({0: previous[0]}, {0: current[0]}, 2)[0]["cpu"], 0
        )


if __name__ == "__main__":
    unittest.main()
