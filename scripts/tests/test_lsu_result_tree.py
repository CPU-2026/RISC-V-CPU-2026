"""Real tagged LSU result selection against an independent pre-edge scan."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class LoadResultTreeTests(unittest.TestCase):
    def test_result_selection(self):
        with tempfile.TemporaryDirectory(prefix='lsu-result-tree-', dir='/tmp/opencode') as directory:
            out = Path(directory)
            command = ['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024',
                       '-Wno-fatal', '-j', '2', '--top-module', 'tb_lsu_result_tree', '--Mdir', str(out/'obj'),
                       str(ROOT/'verilog/rtl/common/rv32_pkg.sv'),
                       str(ROOT/'verilog/rtl/memory/rv32_lsu.sv'),
                       str(ROOT/'scripts/tests/lsu_result_tree_tb.sv')]
            with (out/'build.log').open('w') as log:
                build = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            self.assertEqual(build.returncode, 0, (out/'build.log').read_text()[-14000:])
            run = subprocess.run([str(out/'obj/Vtb_lsu_result_tree')],
                                 capture_output=True, text=True, timeout=60)
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS LSU result tree rounds=96', run.stdout)
            print(run.stdout.strip(), flush=True)
