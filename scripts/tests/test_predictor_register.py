"""Register BTB/direction regression; SRAM RAS recovery has its own tests."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class PredictorRegisterTests(unittest.TestCase):
    def test_protocol(self):
        temporary_root = Path('/tmp/opencode')
        with tempfile.TemporaryDirectory(prefix='predictor-register-',
                                        dir=temporary_root if temporary_root.is_dir() else None) as directory:
            work = Path(directory)
            sources = [ROOT/'verilog/rtl/common/rv32_pkg.sv',
                       ROOT/'scripts/ram/sram_fakeram.sv',
                       *[ROOT/'verilog/rtl/predictor'/name for name in (
                            'rv32_bpu_direction.sv', 'rv32_bpu_btb.sv',
                           'rv32_bpu_ras.sv', 'rv32_bpu_checkpoint.sv', 'rv32_predictor.sv')],
                       ROOT/'scripts/tests/predictor_register_tb.sv']
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '--unroll-count', '1024',
                       '--top-module', 'tb_predictor_register', '--Mdir', str(work/'obj'),
                       '-j', '1', *map(str, sources)]
            with (work/'build.log').open('w') as log:
                result = subprocess.run(command, cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            self.assertEqual(result.returncode, 0, (work/'build.log').read_text(errors='replace')[-12000:])
            result = subprocess.run([str(work/'obj/Vtb_predictor_register')], cwd=work,
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS register predictor', result.stdout)
            print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
