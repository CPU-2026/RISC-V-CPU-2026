"""Current allocator contract; rejected Q2 fixtures live in experiment artifacts."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'verilog/rtl/memory/rv32_dcache.sv'


def allocator_body(text):
    start = text.index('  always_comb begin : allocate_request\n')
    end = text.index('\n  end\n', start) + len('\n  end\n')
    return text[start:end]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class DcacheAllocationTests(unittest.TestCase):
    def build_run(self, work, top, sources):
        command = ['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024',
                   '-Wno-fatal', '-j', '2', '--top-module', top, '--Mdir', str(work/'obj'),
                   *map(str, sources)]
        with (work/'build.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        self.assertEqual(result.returncode, 0, (work/'build.log').read_text()[-14000:])
        return subprocess.run([str(work/'obj'/f'V{top}')], cwd=work,
                              capture_output=True, text=True, timeout=120)

    def run_allocator(self, work, body):
        probe = work/'probe.sv'
        probe.write_text('''module dcache_alloc_probe (
  input logic [2:0] cursorInner,
  input logic [7:0] activeInput, releasedInner,
  input logic acceptInner,
  output integer allocationInner,
  output logic [7:0] allocationMaskInner
);
  localparam int REQUEST_DEPTH = 8;
  typedef struct packed { logic active; } request_entry_t;
  request_entry_t requestInner [REQUEST_DEPTH];
  for (genvar row = 0; row < REQUEST_DEPTH; row++)
    assign requestInner[row].active = activeInput[row];
''' + body + "  always_comb allocationMaskInner = allocationInner < 0 ? 8'b0 : 8'(1 << allocationInner);\nendmodule\n")
        return self.build_run(work, 'tb_dcache_alloc',
                              [probe, ROOT/'scripts/tests/dcache_alloc_tb.sv'])

    def test_all_old_state_combinations(self):
        with tempfile.TemporaryDirectory(prefix='dcache-alloc-', dir='/tmp/opencode') as directory:
            run = self.run_allocator(Path(directory), allocator_body(SOURCE.read_text()))
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS DCache allocation combinations=1048576', run.stdout)
            print(run.stdout.strip(), flush=True)

    def test_unsafe_grants_rejected(self):
        body = allocator_body(SOURCE.read_text())
        mutations = {
            'ungated_grant': ('acceptInner && allocationInner < 0', 'allocationInner < 0'),
            'borrow_released_row': ('!requestInner[slot].active',
                                    '(!requestInner[slot].active || releasedInner[slot])'),
        }
        for name, (old, new) in mutations.items():
            with self.subTest(mutation=name), tempfile.TemporaryDirectory(
                    prefix=f'dcache-alloc-{name}-', dir='/tmp/opencode') as directory:
                self.assertEqual(body.count(old), 1)
                run = self.run_allocator(Path(directory), body.replace(old, new))
                self.assertNotEqual(run.returncode, 0, 'unsafe grant escaped checker')
                self.assertIn('allocation mismatch', run.stdout+run.stderr)
                print(f'PASS negative control {name}', flush=True)
