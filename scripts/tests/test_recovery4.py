"""SRAM committed baselines and four-beat RAT/RAS/free-list recovery."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class RecoveryFourTests(unittest.TestCase):
    def test_core_pending_load(self):
        filelist = ROOT / 'verilog/filelist.f'
        sources = [ROOT / 'scripts/ram/sram_fakeram.sv']
        sources += [filelist.parent / line.strip() for line in filelist.read_text().splitlines()
                    if line.strip() and not line.lstrip().startswith('#')]
        sources.append(ROOT / 'scripts/tests/recovery4_core_tb.sv')
        with tempfile.TemporaryDirectory(prefix='recovery4-core-', dir='/tmp/opencode') as directory:
            work = Path(directory)
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                       '--unroll-count', '1024', '--top-module', 'tb_recovery4_core',
                       '--Mdir', str(work / 'obj'), '-j', '2', *map(str, sources)]
            with (work / 'build.log').open('w') as log:
                result = subprocess.run(command, cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            self.assertEqual(result.returncode, 0, (work / 'build.log').read_text(errors='replace')[-16000:])
            result = subprocess.run([str(work / 'obj/Vtb_recovery4_core')], cwd=work,
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS recovery4 core', result.stdout)
            print(result.stdout.strip())

    def test_recovery(self):
        with tempfile.TemporaryDirectory(prefix='recovery4-', dir='/tmp/opencode') as directory:
            work = Path(directory)
            sources = [ROOT / name for name in (
                'verilog/rtl/common/rv32_pkg.sv', 'scripts/ram/sram_fakeram.sv',
                'verilog/rtl/core/rv32_recovery_cursor.sv',
                'verilog/rtl/backend/rv32_rat.sv', 'verilog/rtl/backend/rv32_prf.sv',
                'verilog/rtl/predictor/rv32_bpu_ras.sv', 'scripts/tests/recovery4_tb.sv')]
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                       '--top-module', 'tb_recovery4', '--Mdir', str(work / 'obj'),
                       '-j', '2', *map(str, sources)]
            with (work / 'build.log').open('w') as log:
                result = subprocess.run(command, cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            self.assertEqual(result.returncode, 0, (work / 'build.log').read_text(errors='replace')[-16000:])
            result = subprocess.run([str(work / 'obj/Vtb_recovery4')], cwd=work,
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS recovery4', result.stdout)
            print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
