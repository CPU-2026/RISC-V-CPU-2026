"""Per-register committed RAT SRAM control and unchanged recovery semantics."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class RatLocalWriteTests(unittest.TestCase):
    def test_commits_and_recovery(self):
        for width in (1, 2):
            with self.subTest(width=width), tempfile.TemporaryDirectory(
                    prefix=f'rat-local-{width}-', dir='/tmp/opencode') as directory:
                out = Path(directory)
                sources = [ROOT / name for name in (
                    'verilog/rtl/common/rv32_pkg.sv', 'scripts/ram/sram_fakeram.sv',
                    'verilog/rtl/backend/rv32_rat.sv', 'scripts/tests/rat_local_write_tb.sv')]
                command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                           '-DCHECK_LOCAL_CONTROLS', '--top-module', 'tb_rat_local_write',
                           f'-GCOMMIT_WIDTH={width}', '--Mdir', str(out/'obj'), '-j', '2',
                           *map(str, sources)]
                with (out/'build.log').open('w') as log:
                    build = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                self.assertEqual(build.returncode, 0, (out/'build.log').read_text()[-14000:])
                run = subprocess.run([str(out/'obj/Vtb_rat_local_write')],
                                     capture_output=True, text=True, timeout=60)
                self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
                self.assertIn(f'PASS RAT local write width={width}', run.stdout)
                print(run.stdout.strip(), flush=True)
