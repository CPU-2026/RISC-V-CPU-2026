"""Verify the single submitted file preserves the two original preprocessor views."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "verilog"))
import export_rtl


@unittest.skipUnless(all(shutil.which(t) for t in ("sv2v", "diff", "iverilog")), "requires export tools")
class ExportTests(unittest.TestCase):
    def test_assertions_parameters_and_synthesis_arm_survive_export(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            frozen = root / "frozen"
            frozen.mkdir()
            original = frozen / "source.sv"
            original.write_text("""\
module student_top(input wire clk, input wire [7:0] d, output reg [7:0] q);
  localparam STEP = `CPU_TEST_STEP;
`ifndef SYNTHESIS
  reg fault;
  initial fault = $test$plusargs("INJECT");
  always @(posedge clk) assert (!fault) else $fatal(1, "injected");
  wire [7:0] next_q = (d + STEP) ^ fault;
`else
  wire [7:0] next_q = d + STEP;
`endif
  always_ff @(posedge clk) q <= next_q;
endmodule
""")
            filelist = frozen / "filelist.f"
            filelist.write_text("source.sv\n")
            generated = root / "submission.sv"
            with patch.object(export_rtl, "VERILOG", root):
                generated.write_bytes(export_rtl.export("sv2v", ["CPU_TEST_STEP=3"], root,
                                                        source_list=filelist))
            for synthesis in (False, True):
                with self.subTest(synthesis=synthesis):
                    selection = ["-DSYNTHESIS"] if synthesis else []
                    standalone = subprocess.check_output([
                        "sv2v", "--exclude=Always", "--top=student_top", "-DCPU_TEST_STEP=3",
                        *(selection or ["--exclude=Assert"]), original], text=True)
                    actual = subprocess.check_output([
                        "iverilog", "-E", "-g2012", *selection, "-o", "-", generated], text=True)
                    def body(text):
                        return [l for l in text[text.index("module student_top"):].splitlines() if l.strip()]
                    self.assertEqual(body(actual), body(standalone))
                    self.assertEqual("assert (" in actual, not synthesis)
