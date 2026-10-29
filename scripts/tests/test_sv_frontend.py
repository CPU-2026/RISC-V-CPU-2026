"""Run with: python3 -B -m unittest discover -s scripts/tests -v."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
ROOT = SCRIPTS.parent
sys.path.insert(0, str(SCRIPTS))
from fakeram import RAM_SOURCE
from sv_frontend import convert_sources, explicit_port_patterns, factor_registered_axi_outputs, select_frontend


class FrontendTests(unittest.TestCase):
    def setUp(self):
        temporary_root = Path("/tmp/opencode")
        self.temporary = tempfile.TemporaryDirectory(prefix="sv-frontend-",
                                                     dir=temporary_root if temporary_root.is_dir() else None)
        self.work = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def test_plain_verilog_uses_native_parser(self):
        with patch("sv_frontend.shutil.which", return_value=None):
            self.assertEqual(select_frontend("auto", [Path("design.v")]), ("yosys", None))

    def test_sv_prefers_converter(self):
        with patch.dict(os.environ, {}, clear=True), patch("sv_frontend.shutil.which", return_value="/bin/sv2v"):
            self.assertEqual(select_frontend("auto", [Path("design.sv")]), ("sv2v", "/bin/sv2v"))

    def test_missing_converter_and_override_errors(self):
        with patch.dict(os.environ, {}, clear=True), patch("sv_frontend.shutil.which", return_value=None):
            self.assertEqual(select_frontend("auto", [Path("design.sv")]), ("yosys", None))
            with self.assertRaisesRegex(ValueError, "sv2v is required"):
                select_frontend("sv2v", [Path("design.sv")])
            with self.assertRaisesRegex(ValueError, "executable not found"):
                select_frontend("auto", [Path("design.v")], "/nonexistent/sv2v")
        with self.assertRaisesRegex(ValueError, "cannot be combined"):
            select_frontend("yosys", [], "sv2v")

    def test_typed_patterns_only_change_staged_copy(self):
        child = self.work / "child.sv"
        child.write_text("module rv32_child(input rv32_pkg::request_t requestInput); endmodule\n")
        top = self.work / "top.sv"
        text = "module student_top;\n  rv32_child dut (.requestInput('{valid:1'b1, data:{8'b0, 24'b0}}));\nendmodule\n"
        top.write_text(text)
        staged, changes = explicit_port_patterns([child, top], self.work / "sources")
        self.assertEqual(top.read_text(), text)
        self.assertIn("rv32_pkg::request_t'('{", staged[1].read_text())
        self.assertEqual(changes[0]["type"], "rv32_pkg::request_t")

    def test_failed_conversion_removes_partial_output(self):
        source = self.work / "top.sv"
        source.write_text("module student_top; endmodule\n")
        with patch("sv_frontend.subprocess.run", return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaisesRegex(ValueError, "conversion failed"):
                convert_sources("sv2v", [source], self.work / "frontend")
        self.assertFalse((self.work / "frontend" / "converted.v").exists())
        self.assertTrue((self.work / "frontend" / "sv2v.log").exists())

    def test_typed_patterns_inside_generate_indentation(self):
        child=self.work/"child.sv"
        child.write_text("module rv32_child(input rv32_pkg::request_t requestInput); endmodule\n")
        top=self.work/"top.sv"
        text=("module student_top;\n  if (1) begin : g_four\n"
              "    rv32_child #(.WIDTH(4)) four (.requestInput('{valid:1'b1, data:32'b0}));\n"
              "\trv32_child tabbed (.requestInput('{valid:1'b0, data:32'b0}));\n"
              "  end\nendmodule\n")
        top.write_text(text)
        staged,changes=explicit_port_patterns([child,top],self.work/"sources")
        self.assertEqual(top.read_text(),text)
        self.assertEqual(len(changes),2)
        self.assertEqual(staged[1].read_text().count("rv32_pkg::request_t'('{"),2)

    def test_registered_axi_outputs_factor_only_staged_copy(self):
        original=ROOT/"verilog/rtl/memory/rv32_axi_data.sv"
        text=original.read_text()
        staged,_=explicit_port_patterns([original],self.work/"sources")
        changes=factor_registered_axi_outputs(staged)
        self.assertEqual(original.read_text(),text)
        self.assertEqual(len(changes),1)
        result=staged[0].read_text()
        self.assertIn("always_comb begin : registered_axi_responses",result)
        for name in ("readReadyOutput","writeReadyOutput","exitReadyOutput"):
            self.assertEqual(result.count("assign "+name+" ="),1)
        begin=text.index("    responseOutput = '")
        end=text.index("    masterOutput = '0;",begin)
        self.assertIn(text[begin:end],result)

    def test_axi_response_factor_rejects_unknown_equations(self):
        source=self.work/"rv32_axi_data.sv"
        text=(ROOT/"verilog/rtl/memory/rv32_axi_data.sv").read_text()
        text=text.replace("responseOutput = '{valid:rstNInput", "responseOutput = '{valid:requestInput.readValid && rstNInput")
        source.write_text(text)
        with self.assertRaisesRegex(ValueError,"unknown AXI registered response"):
            factor_registered_axi_outputs([source])
        self.assertEqual(source.read_text(),text)

    @unittest.skipUnless(shutil.which("sv2v") and shutil.which("verilator"),
                         "requires sv2v and Verilator")
    def test_real_dcache_conversion_and_cycle_equivalence(self):
        sources = [ROOT / "verilog/rtl/common/rv32_pkg.sv", ROOT / "verilog/rtl/memory/rv32_dcache.sv",
                   ROOT / "verilog/rtl/memory/rv32_dmem.sv",
                   ROOT / "verilog/assessment/dcache_top.sv"]
        hashes = [hashlib.sha256(source.read_bytes()).hexdigest() for source in sources]
        converted, manifest = convert_sources(shutil.which("sv2v"), sources, self.work / "frontend")
        self.assertEqual(hashes, [hashlib.sha256(source.read_bytes()).hexdigest() for source in sources])
        self.assertEqual(manifest["converted_sha256"], hashlib.sha256(converted.read_bytes()).hexdigest())
        rtl = sources[1].read_text()
        self.assertIn("for (genvar b = 0; b < WORDS_PER_LINE; b = b + 1) begin : g_data_bank", rtl)
        self.assertIn(".WIDTH(32), .WRITE_GRANULARITY(8)", rtl)
        self.assertIn(".WIDTH(META_W), .WRITE_GRANULARITY(META_W)", rtl)
        self.assertIn("META_W = TAG_W + 1", rtl)
        self.assertIn("logic validInner [SETS]", rtl)
        renamed = self.work / "dcache_converted.v"
        text, replacements = re.subn(r"\bmodule rv32_dcache\b", "module rv32_dcache_converted", converted.read_text())
        self.assertEqual(replacements, 1)
        renamed.write_text(text)
        self.run_logged(["verilator", "--binary", "--timing", "--assert", "-Wno-fatal", "--unroll-count", "1024", "--unroll-stmts", "100000",
                         "-j", "1", "--top-module", "tb_dcache_frontend", "--Mdir", str(self.work / "obj"),
                         *map(str, sources), str(renamed), str(RAM_SOURCE), str(SCRIPTS / "tests/dcache_frontend_tb.sv")],
                        "verilator.log")
        self.run_logged([str(self.work / "obj/Vtb_dcache_frontend")], "simulation.log")
        text = (self.work / "simulation.log").read_text()
        self.assertIn("PASS frontend equivalence", text)
        print(text.strip())

    def run_logged(self, command, name):
        log = self.work / name
        with log.open("w") as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
        self.assertEqual(result.returncode, 0, f"{command[0]} failed:\n{log.read_text()[-8000:]}")


if __name__ == "__main__":
    unittest.main()
