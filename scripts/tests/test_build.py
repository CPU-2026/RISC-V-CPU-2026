import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from argparse import Namespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build


class BuildTests(unittest.TestCase):
    def setUp(self):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        self.out = Path(work.name) / "build"
        self.source = Path(work.name) / "design.v"
        self.args = Namespace(verilator="verilator", make="make", cxx="g++", ar="ar", jobs=1)
        for name in ("verilator_command", "executable"):
            mock = patch.object(build, name, side_effect=lambda name: f"/tools/{name}")
            mock.start()
            self.addCleanup(mock.stop)

    def test_serial_build_splits_cpp_and_ignores_stale_jobserver(self):
        inherited = {
            "TMPDIR": str(self.out / "missing"),
            "MAKEFLAGS": "-j8 --jobserver-auth=fifo:/missing/GMfifo",
            "GNUMAKEFLAGS": "-j8",
            "MFLAGS": "-j8",
        }
        with patch.dict(os.environ, inherited), patch.object(build.subprocess, "run") as run:
            self.assertEqual(build.build_simulator([self.source], self.out, self.args), self.out / "sim")
            self.assertEqual(os.environ["TMPDIR"], inherited["TMPDIR"])

        generate, compile_cpp = run.call_args_list
        verilator_command = generate.args[0]
        self.assertIn("--output-split", verilator_command)
        self.assertIn("--assert", verilator_command)
        self.assertIn("--trace", verilator_command)
        self.assertNotIn("--build", verilator_command)
        self.assertNotIn("-j", verilator_command)
        self.assertEqual(compile_cpp.args[0][:7], [
            "/tools/make", "-C", str(self.out / "obj"), "-f", "Vstudent_top.mk", "-j", "1",
        ])
        for step in (generate, compile_cpp):
            self.assertTrue(step.kwargs["check"])
            env = step.kwargs["env"]
            for name in ("MAKEFLAGS", "GNUMAKEFLAGS", "MFLAGS"):
                self.assertNotIn(name, env)
            for name in ("TMPDIR", "TMP", "TEMP"):
                self.assertEqual(env[name], str(self.out / "tmp"))
        self.assertTrue((self.out / "tmp").is_dir())

    def test_parallel_make_uses_pipes_when_available(self):
        self.args.jobs = 2
        self.out.mkdir()
        for help_text, supports_pipes in ((b"--jobserver-style=STYLE", True), (b"", False)):
            with self.subTest(supports_pipes=supports_pipes):
                with (patch.dict(os.environ, {"TMPDIR": str(self.out)}),
                      patch.object(build.subprocess, "check_output", return_value=help_text),
                      patch.object(build.subprocess, "run") as run):
                    build.build_simulator([self.source], self.out, self.args)
                command = run.call_args.args[0]
                self.assertEqual(command[command.index("-j") + 1], "2")
                self.assertEqual("--jobserver-style=pipe" in command, supports_pipes)
                self.assertEqual(run.call_args.kwargs["env"]["TMPDIR"], str(self.out))

    def test_failed_generation_does_not_start_make(self):
        with patch.object(build.subprocess, "run",
                          side_effect=subprocess.CalledProcessError(1, ["verilator"])) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                build.build_simulator([self.source], self.out, self.args)
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
