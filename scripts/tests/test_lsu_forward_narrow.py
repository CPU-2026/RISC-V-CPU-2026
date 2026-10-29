"""Real SQ query/clock boundaries, with controls for two unsafe rewrites."""
from pathlib import Path
import ctypes
import ctypes.util
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'verilog/rtl/memory/rv32_lsu.sv'


@unittest.skipUnless(ctypes.util.find_library('z3'), 'requires native libz3')
class OverlapCoverProofTests(unittest.TestCase):
    def test_all_address_bitvectors(self):
        library = ctypes.CDLL(ctypes.util.find_library('z3'))
        library.Z3_mk_config.restype = ctypes.c_void_p
        library.Z3_mk_context.argtypes = [ctypes.c_void_p]
        library.Z3_mk_context.restype = ctypes.c_void_p
        library.Z3_del_config.argtypes = [ctypes.c_void_p]
        library.Z3_del_context.argtypes = [ctypes.c_void_p]
        library.Z3_eval_smtlib2_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        library.Z3_eval_smtlib2_string.restype = ctypes.c_char_p
        config = library.Z3_mk_config()
        context = library.Z3_mk_context(config)
        library.Z3_del_config(config)
        try:
            proof = (ROOT/'scripts/tests/lsu_forward_cover.smt2').read_bytes()
            result = library.Z3_eval_smtlib2_string(context, proof).decode().split()
            self.assertEqual(result, ['unsat', 'unsat', 'sat'])
            print('PASS overlap cover/data lemma (all 32-bit addresses), negative premise control', flush=True)
        finally:
            library.Z3_del_context(context)


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class NarrowForwardTests(unittest.TestCase):
    def run_rtl(self, work, source):
        command = ['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024',
                   '-Wno-fatal', '-j', '2', '--top-module', 'tb_lsu_forward_narrow',
                   '--Mdir', str(work/'obj'), str(ROOT/'verilog/rtl/common/rv32_pkg.sv'),
                   str(source), str(ROOT/'scripts/tests/lsu_forward_narrow_tb.sv')]
        with (work/'build.log').open('w') as log:
            build = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        self.assertEqual(build.returncode, 0, (work/'build.log').read_text()[-14000:])
        return subprocess.run([str(work/'obj/Vtb_lsu_forward_narrow')], cwd=work,
                              capture_output=True, text=True, timeout=120)

    def test_query_and_delivery(self):
        with tempfile.TemporaryDirectory(prefix='lsu-narrow-', dir='/tmp/opencode') as directory:
            run = self.run_rtl(Path(directory), SOURCE)
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS LSU narrow forward', run.stdout)
            print(run.stdout.strip(), flush=True)

    def test_unsafe_rewrites_rejected(self):
        text = SOURCE.read_text()
        anchor = 'end else if (byte_overlap(loadAddressInput, loadSizeInput, address, sqSizeInner[s],'
        self.assertEqual(text.count(anchor), 1)
        mutations = {
            'wrapping_cover_sum': ('logic [2:0] coverEnd;', 'logic [1:0] coverEnd;'),
            'skip_data_late_source': (anchor, anchor.replace('if (byte_overlap', 'if (dataReady && byte_overlap')),
        }
        for name, (old, new) in mutations.items():
            with self.subTest(mutation=name), tempfile.TemporaryDirectory(
                    prefix=f'lsu-narrow-{name}-', dir='/tmp/opencode') as directory:
                work = Path(directory)
                self.assertEqual(text.count(old), 1)
                source = work/'rv32_lsu.sv'
                source.write_text(text.replace(old, new))
                run = self.run_rtl(work, source)
                self.assertNotEqual(run.returncode, 0, 'unsafe rewrite escaped the checker')
                self.assertIn('forward mismatch', run.stdout+run.stderr)
                print(f'PASS negative control {name}', flush=True)
