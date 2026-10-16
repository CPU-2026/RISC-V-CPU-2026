"""Standalone naive SRAM BTB tests; run Verilator builds serially (-j 1)."""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
ROOT = SCRIPTS.parent
sys.path.insert(0, str(SCRIPTS))
from fakeram import RAM_SOURCE
from sv_frontend import convert_sources


@unittest.skipUnless(shutil.which("verilator") and shutil.which("sv2v"),
                     "requires Verilator and sv2v")
class BtbSramTests(unittest.TestCase):
    def setUp(self):
        temporary_root = Path("/tmp/opencode")
        self.temporary = tempfile.TemporaryDirectory(prefix="btb-sram-",
                                                     dir=temporary_root if temporary_root.is_dir() else None)
        self.work = Path(self.temporary.name)
        self.package = ROOT / "verilog/rtl/common/rv32_pkg.sv"
        self.dut = ROOT / "verilog/rtl/predictor/rv32_bpu_btb_sram.sv"

    def tearDown(self):
        self.temporary.cleanup()

    def run_logged(self, command, name, *, success=True):
        log = self.work / name
        with log.open("w") as stream:
            result = subprocess.run(command, cwd=self.work, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=120)
        text = log.read_text()
        if success:
            self.assertEqual(result.returncode, 0, f"{command[0]} failed:\n{text[-12000:]}")
        else:
            self.assertNotEqual(result.returncode, 0, "invalid BTB geometry unexpectedly ran")
        return text

    def build(self, sources, top, directory, *extra):
        self.run_logged(["verilator", "--binary", "--timing", "--assert", "-Wno-fatal",
                         "-j", "1", "--top-module", top, "--Mdir", str(directory),
                         *extra, *map(str, sources)], directory.name + ".log")

    def test_register_oracle_and_sv2v_equivalence(self):
        converted, _ = convert_sources(shutil.which("sv2v"),
                                       [self.package, self.dut, ROOT / "verilog/assessment/btb_sram_top.sv"],
                                       self.work / "frontend")
        renamed = self.work / "btb_converted.v"
        text, count = re.subn(r"\brv32_bpu_btb_sram\b", "rv32_bpu_btb_sram_converted", converted.read_text())
        self.assertGreaterEqual(count, 1)
        renamed.write_text(text)
        sources = [self.package, self.dut, ROOT / "verilog/rtl/predictor/rv32_bpu_btb.sv",
                   renamed, RAM_SOURCE, SCRIPTS / "tests/btb_sram_tb.sv"]
        for entries in (2, 16, 64):
            with self.subTest(entries=entries):
                directory = self.work / f"obj-{entries}"
                self.build(sources, "tb_btb_sram", directory, f"-GENTRIES={entries}")
                output = self.run_logged([str(directory / "Vtb_btb_sram")], f"simulation-{entries}.log")
                self.assertIn(f"PASS naive SRAM BTB entries={entries}", output)
                print(output.strip())

    def test_non_power_of_two_rejected_at_runtime(self):
        top = self.work / "invalid.sv"
        top.write_text("""module tb_btb_sram_invalid;
  logic clock = 0;
  always #5 clock = ~clock;
  rv32_bpu_btb_sram #(.BTB_ENTRIES(3)) dut (
    .clkInput(clock), .rstNInput(1'b0), .queryValidInput(1'b0),
    .queryReadyOutput(), .queryPcInput(32'b0), .responseValidOutput(),
    .responseReadyInput(1'b0), .responsePcOutput(), .lookupOutput(),
    .trainingValidInput(1'b0), .trainingReadyOutput(), .trainingInput('0),
    .trainingDoneOutput(), .initializedOutput()
  );
  initial begin #30; $fatal(1, "invalid parameter was accepted"); end
endmodule
""")
        directory = self.work / "obj-invalid"
        self.build([self.package, self.dut, RAM_SOURCE, top], "tb_btb_sram_invalid", directory)
        output = self.run_logged([str(directory / "Vtb_btb_sram_invalid")], "invalid.log", success=False)
        self.assertIn("BPU SRAM BTB parameter must be power-of-two", output)


if __name__ == "__main__":
    unittest.main()
