"""Dual-allocation module boundary checks; no production state injection."""
from pathlib import Path
import fcntl
import os
import resource
import shutil
import subprocess
import tempfile
import unittest
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from fakeram import with_ram_source


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class RenameWidthTests(unittest.TestCase):
    def test_dual_allocation_units(self):
        lock = Path('/tmp/opencode/load-abc-20261021/heavy-job.lock')
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open('a') as guard:
            fcntl.flock(guard, fcntl.LOCK_EX | (0 if os.environ.get('CPU_VALIDATION_WAIT') == '1' else fcntl.LOCK_NB))
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
            with tempfile.TemporaryDirectory(prefix='rename-units-', dir='/tmp/opencode') as directory:
                work = Path(directory)
                rtl = ROOT / 'verilog/rtl'
                sources = with_ram_source([rtl / p for p in [
                    'common/rv32_pkg.sv', 'common/rv32_sram.sv', 'common/rv32_cla.sv',
                    'backend/rv32_rat.sv', 'backend/rv32_prf.sv', 'backend/rv32_rob.sv',
                    'backend/rv32_rs.sv', 'memory/rv32_lsu.sv']])
                command = ['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024',
                           '-Wno-fatal', '-j', '4', '--top-module', 'tb_rename_width', '--Mdir', str(work / 'obj'),
                           *map(str, sources), str(ROOT / 'scripts/tests/rename_width_tb.sv')]
                built = subprocess.run(command, capture_output=True, text=True, timeout=240)
                self.assertEqual(built.returncode, 0, (built.stdout + built.stderr)[-16000:])
                self.assertNotIn('%Warning-UNOPTFLAT', built.stderr)
                self.assertNotIn('%Warning-LATCH', built.stderr)
                tested = subprocess.run([str(work / 'obj/Vtb_rename_width')], capture_output=True, text=True, timeout=60)
                self.assertEqual(tested.returncode, 0, tested.stdout + tested.stderr)
                self.assertIn('PASS dual rename units', tested.stdout)
                print(tested.stdout.strip(), flush=True)


if __name__ == '__main__':
    unittest.main()
