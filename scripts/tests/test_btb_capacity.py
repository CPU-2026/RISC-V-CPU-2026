"""Capacity, full-tag aliases and three-source training at 32/64 BTB entries."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class BtbCapacityTests(unittest.TestCase):
    def run_rtl(self, work, depth, source):
        cmd = ['verilator','--binary','--timing','--assert','--unroll-count','1024','-Wno-fatal',
               '-j','2','--top-module','tb_btb_capacity',f'-GDEPTH={depth}','--Mdir',str(work/'obj'),
               str(ROOT/'verilog/rtl/common/rv32_pkg.sv'),
               str(ROOT/'verilog/rtl/predictor/rv32_bpu_btb.sv'),str(source)]
        with (work/'build.log').open('w') as log:
            run = subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        self.assertEqual(run.returncode,0,(work/'build.log').read_text()[-14000:])
        return subprocess.run([str(work/'obj/Vtb_btb_capacity')],cwd=work,capture_output=True,text=True,timeout=60)

    def test_capacity_and_training(self):
        for depth in (32,64):
            with self.subTest(depth=depth), tempfile.TemporaryDirectory(prefix=f'btb-{depth}-',dir='/tmp/opencode') as directory:
                run = self.run_rtl(Path(directory),depth,ROOT/'scripts/tests/btb_capacity_tb.sv')
                self.assertEqual(run.returncode,0,run.stdout+run.stderr)
                self.assertIn(f'PASS BTB capacity depth={depth}',run.stdout)
                print(run.stdout.strip(),flush=True)

    def test_wrong_capacity_rejected(self):
        text = (ROOT/'scripts/tests/btb_capacity_tb.sv').read_text()
        anchor = '.BTB_ENTRIES(DEPTH)';self.assertEqual(text.count(anchor),1)
        with tempfile.TemporaryDirectory(prefix='btb-wrong-capacity-',dir='/tmp/opencode') as directory:
            work = Path(directory);source = work/'wrong_capacity.sv'
            source.write_text(text.replace(anchor,'.BTB_ENTRIES(64)'))
            run = self.run_rtl(work,32,source)
            self.assertNotEqual(run.returncode,0)
            self.assertIn('BTB physical capacity mismatch',run.stdout+run.stderr)
            print('PASS negative control wrong physical BTB capacity',flush=True)
