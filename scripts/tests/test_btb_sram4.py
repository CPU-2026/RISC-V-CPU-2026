"""Four-bank split-SRAM BTB oracle and conversion tests, built serially."""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
ROOT = SCRIPTS.parent
sys.path.insert(0,str(SCRIPTS))
from fakeram import RAM_SOURCE
from sv_frontend import convert_sources


@unittest.skipUnless(shutil.which('verilator') and shutil.which('sv2v'),'requires Verilator/sv2v')
class BtbSram4Tests(unittest.TestCase):
    def test_invalid_geometry(self):
        temporary_root=Path('/tmp/opencode')
        with tempfile.TemporaryDirectory(prefix='btb-sram4-invalid-',dir=temporary_root if temporary_root.is_dir() else None) as directory:
            work=Path(directory)
            top=work/'invalid.sv'
            top.write_text('''module tb_btb_sram4_invalid;
  logic clock=0;
  always #5 clock=~clock;
  rv32_bpu_btb_sram4 #(.BTB_ENTRIES(12)) dut (
    .clkInput(clock), .rstNInput(1'b0), .queryValidInput(1'b0),
    .queryReadyOutput(), .queryPcInput(32'b0), .responseValidOutput(),
    .responseReadyInput(1'b0), .responsePcOutput(), .lookupOutput(),
    .trainingValidInput(1'b0), .trainingReadyOutput(), .trainingInput('0),
    .trainingDoneOutput(), .initializedOutput()
  );
  initial begin #30; $fatal(1,"invalid geometry was accepted"); end
endmodule
''')
            sources=[ROOT/'verilog/rtl/common/rv32_pkg.sv',
                     ROOT/'verilog/rtl/predictor/rv32_bpu_btb_sram4.sv',RAM_SOURCE,top]
            with (work/'build.log').open('w') as log:
                result=subprocess.run(['verilator','--binary','--timing','--assert','-Wno-fatal',
                    '--unroll-count','1024','-j','1','--top-module','tb_btb_sram4_invalid',
                    '--Mdir',str(work/'obj'),*map(str,sources)],cwd=work,stdout=log,stderr=subprocess.STDOUT,timeout=120)
            self.assertEqual(result.returncode,0,(work/'build.log').read_text(errors='replace')[-12000:])
            result=subprocess.run([str(work/'obj/Vtb_btb_sram4_invalid')],cwd=work,capture_output=True,text=True,timeout=30)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('four-bank BTB entries must be power-of-two',result.stdout+result.stderr)

    def test_oracle_and_conversion(self):
        temporary_root = Path('/tmp/opencode')
        with tempfile.TemporaryDirectory(prefix='btb-sram4-',dir=temporary_root if temporary_root.is_dir() else None) as directory:
            work=Path(directory)
            package=ROOT/'verilog/rtl/common/rv32_pkg.sv'
            dut=ROOT/'verilog/rtl/predictor/rv32_bpu_btb_sram4.sv'
            converted,_=convert_sources(shutil.which('sv2v'),
                [package,dut,ROOT/'verilog/assessment/btb_sram4_top.sv'],work/'frontend')
            renamed=work/'converted.v'
            text,count=re.subn(r'\brv32_bpu_btb_sram4\b','rv32_bpu_btb_sram4_converted',converted.read_text())
            self.assertGreaterEqual(count,1)
            renamed.write_text(text)
            sources=[package,dut,ROOT/'verilog/rtl/predictor/rv32_bpu_btb.sv',renamed,
                     RAM_SOURCE,SCRIPTS/'tests/btb_sram4_tb.sv']
            for entries in (4,16,64):
                with self.subTest(entries=entries):
                    obj=work/f'obj-{entries}'
                    with (work/'build.log').open('w') as log:
                        result=subprocess.run(['verilator','--binary','--timing','--assert','-Wno-fatal',
                            '--unroll-count','1024','-j','1','--top-module','tb_btb_sram4','--Mdir',str(obj),
                            f'-GENTRIES={entries}',*map(str,sources)],cwd=work,stdout=log,stderr=subprocess.STDOUT,timeout=120)
                    self.assertEqual(result.returncode,0,(work/'build.log').read_text(errors='replace')[-14000:])
                    result=subprocess.run([str(obj/'Vtb_btb_sram4')],cwd=work,capture_output=True,text=True,timeout=30)
                    self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                    self.assertIn(f'PASS four-bank SRAM BTB entries={entries}',result.stdout)
                    print(result.stdout.strip())


if __name__=='__main__':
    unittest.main()
