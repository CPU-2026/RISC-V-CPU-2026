"""Address-boundary proof and exact production overlap-function checks."""
from pathlib import Path
import ctypes
import ctypes.util
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'verilog/rtl/memory/rv32_lsu.sv'


@unittest.skipUnless(ctypes.util.find_library('z3'), 'requires native libz3')
class WordNeighborProofTests(unittest.TestCase):
    def test_all_32_bit_addresses(self):
        lib = ctypes.CDLL(ctypes.util.find_library('z3'))
        lib.Z3_mk_config.restype = ctypes.c_void_p
        lib.Z3_mk_context.argtypes = [ctypes.c_void_p]
        lib.Z3_mk_context.restype = ctypes.c_void_p
        lib.Z3_del_config.argtypes = [ctypes.c_void_p]
        lib.Z3_del_context.argtypes = [ctypes.c_void_p]
        lib.Z3_eval_smtlib2_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        lib.Z3_eval_smtlib2_string.restype = ctypes.c_char_p
        config = lib.Z3_mk_config(); context = lib.Z3_mk_context(config); lib.Z3_del_config(config)
        try:
            proof = (ROOT/'scripts/tests/lsu_word_neighbors.smt2').read_bytes()
            result = lib.Z3_eval_smtlib2_string(context, proof).decode().split()
            self.assertEqual(result, ['unsat', 'sat', 'sat'])
            print('PASS 32-bit word-neighbor equivalence; both missing-wrap-guard controls detected', flush=True)
        finally:
            lib.Z3_del_context(context)


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class WordNeighborRtlTests(unittest.TestCase):
    def run_rtl(self, work, text):
        start = text.index('  function automatic logic byte_overlap(\n')
        end = text.index('  endfunction', start) + len('  endfunction')
        probe = work/'probe.sv'
        probe.write_text("module lsu_word_overlap_probe;\n  import rv32_pkg::*;\n"
                         "  localparam logic [29:0] LAST_WORD = '1;\n" + text[start:end] + '\nendmodule\n')
        cmd = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '-j', '2',
               '--top-module', 'tb_lsu_word_neighbors', '--Mdir', str(work/'obj'),
               str(ROOT/'verilog/rtl/common/rv32_pkg.sv'), str(probe),
               str(ROOT/'scripts/tests/lsu_word_neighbors_tb.sv')]
        with (work/'build.log').open('w') as log:
            build = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        self.assertEqual(build.returncode, 0, (work/'build.log').read_text()[-14000:])
        return subprocess.run([str(work/'obj/Vtb_lsu_word_neighbors')], cwd=work,
                              capture_output=True, text=True, timeout=60)

    def test_overlap_function(self):
        with tempfile.TemporaryDirectory(prefix='sq-word-neighbors-', dir='/tmp/opencode') as directory:
            run = self.run_rtl(Path(directory), SOURCE.read_text())
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS LSU word neighbors checks=181920', run.stdout)
            print(run.stdout.strip(), flush=True)

    def test_missing_wrap_guards_rejected(self):
        text = SOURCE.read_text()
        for guard in ('storeAddressInput[31:2] != LAST_WORD', 'loadAddressInput[31:2] != LAST_WORD'):
            with self.subTest(guard=guard), tempfile.TemporaryDirectory(
                    prefix='sq-word-neighbor-wrap-', dir='/tmp/opencode') as directory:
                anchor = ' && ' + guard
                self.assertEqual(text.count(anchor), 1)
                run = self.run_rtl(Path(directory), text.replace(anchor, ''))
                self.assertNotEqual(run.returncode, 0, 'missing wrap guard escaped checker')
                self.assertIn('word overlap mismatch', run.stdout+run.stderr)
                print(f'PASS negative control missing {guard}', flush=True)
