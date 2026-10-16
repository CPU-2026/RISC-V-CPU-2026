"""Tagged transport owners must survive cancellation and LQ reuse."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TaggedLsuTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
    def test_out_of_order_and_cancelled_owner(self):
        with tempfile.TemporaryDirectory(prefix='lsu-tagged-',dir='/tmp/opencode') as directory:
            out = Path(directory)
            command = ['verilator','--binary','--timing','--assert','--unroll-count','1024',
                       '-Wno-fatal','-j','1','--top-module','tb_lsu_tagged','--Mdir',str(out/'obj'),
                       str(ROOT/'verilog/rtl/common/rv32_pkg.sv'),str(ROOT/'verilog/rtl/memory/rv32_lsu.sv'),
                       str(ROOT/'scripts/tests/lsu_tagged_tb.sv')]
            result = subprocess.run(command,capture_output=True,text=True,timeout=120)
            self.assertEqual(result.returncode,0,result.stdout[-8000:]+result.stderr[-8000:])
            result = subprocess.run([str(out/'obj/Vtb_lsu_tagged')],capture_output=True,text=True,timeout=30)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('PASS tagged LSU',result.stdout)
            print(result.stdout.strip())
