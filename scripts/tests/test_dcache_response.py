"""R2 narrow-response identities and full legacy/new cache state contract."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'verilog/rtl/memory/rv32_dcache.sv'


def fill_branches(text):
    start = text.index('  for (genvar miss = 0; miss < MSHR_DEPTH; miss++) begin : gen_fill_response\n')
    end = text.index('\n  end\n', start) + len('\n  end\n')
    return text[start:end]


def legacy_response(text):
    """Undo R2 only, retaining the accepted allocator and unrelated RTL."""
    start = text.index('  // These narrow identities/qualifiers depend only on OLD MSHR/request state.\n')
    end = text.index('  always_comb begin : plan\n', start)
    text = text[:start] + text[end:]
    changes = (
        ('  integer normalResponseInner;\n', ''),
        ('  logic [MSHR_DEPTH-1:0] fillCanRespondInner;\n'
         '  data_transaction_t fillTransactionInner [MSHR_DEPTH];\n'
         '  data_transaction_t normalTransactionInner;\n', ''),
        ('earlyInner = fillBeatInner && fillCanRespondInner[memResponseInput.transaction];',
         'earlyInner = fillBeatInner && !requestInner[owner].request.write && !missesInner[fillMissInner].responded;'),
        ("    normalResponseInner = oldest_request(candidates);\n"
         "    normalTransactionInner = '0;\n"
         '    if (normalResponseInner >= 0)\n'
         '      normalTransactionInner = requestInner[normalResponseInner].request.transaction;\n'
         '    responseInner = earlyInner ? owner : normalResponseInner;',
         '    responseInner = earlyInner ? owner : oldest_request(candidates);'),
        ('cpuResponseOutput.transaction = earlyInner ? fillTransactionInner[memResponseInput.transaction] :\n'
         '        normalTransactionInner;',
         'cpuResponseOutput.transaction = requestInner[responseInner].request.transaction;'),
    )
    for old, new in changes:
        if text.count(old) != 1:
            raise ValueError(f'R2 fixture anchor changed: {old}')
        text = text.replace(old, new)
    return text


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class DcacheResponseTests(unittest.TestCase):
    def build_run(self, work, top, sources):
        cmd = ['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024', '--unroll-stmts', '100000',
               '-Wno-fatal', '-j', '2', '--top-module', top, '--Mdir', str(work/'obj'),
               *map(str, sources)]
        with (work/'build.log').open('w') as log:
            result = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        self.assertEqual(result.returncode, 0, (work/'build.log').read_text()[-14000:])
        return subprocess.run([str(work/'obj'/f'V{top}')], cwd=work,
                              capture_output=True, text=True, timeout=120)

    def run_identities(self, work, text):
        early = re.search(r'    earlyInner = [^;]+;', text).group()
        start = text.index("    normalTransactionInner = '0;\n")
        end = text.index('\n    cpuResponseOutput =', start)
        selection = text[start:end]
        transaction = re.search(r'      cpuResponseOutput.transaction = [^;]+;', text).group()
        probe = work/'probe.sv'
        probe.write_text('''module dcache_response_probe (
  input logic rstNInput, fillBeatInner,
  input logic [1:0] transactionInput,
  input logic [11:0] ownersInput,
  input logic [3:0] respondedInput,
  input logic [7:0] writesInput,
  input logic [23:0] idsInput,
  input integer normalResponseInner,
  output integer responseInner,
  output logic earlyInner, validOutput,
  output rv32_pkg::data_transaction_t transactionOutput
);
  import rv32_pkg::*;
  localparam int MSHR_DEPTH = 4;
  typedef struct packed { logic write; data_transaction_t transaction; } payload_t;
  typedef struct packed { payload_t request; } request_t;
  typedef struct packed { logic [2:0] owner; logic responded; } miss_t;
  request_t requestInner [8];
  miss_t missesInner [4];
  dcache_line_response_input_t memResponseInput;
  dcache_cpu_response_output_t cpuResponseOutput;
  logic [MSHR_DEPTH-1:0] fillCanRespondInner;
  data_transaction_t fillTransactionInner [MSHR_DEPTH];
  data_transaction_t normalTransactionInner;
  integer owner;
  assign memResponseInput = '{transaction:transactionInput, default:'0};
  // Drive each packed row as a whole. Split field assignments can leave the
  // test-only array projection in Verilator's initialization-only evaluation.
  for (genvar row = 0; row < 8; row++) begin
    assign requestInner[row] = {writesInput[row], idsInput[row*3+:3]};
  end
  for (genvar row = 0; row < 4; row++) begin
    assign missesInner[row] = {ownersInput[row*3+:3], respondedInput[row]};
  end
''' + fill_branches(text) + '''  always_comb begin
    owner = fillBeatInner ? int'(missesInner[transactionInput].owner) : 0;
''' + early + '\n' + selection + '''
    cpuResponseOutput = '0;
    if (responseInner >= 0) begin
      cpuResponseOutput.valid = rstNInput;
''' + transaction + '''
    end
  end
  assign validOutput = cpuResponseOutput.valid;
  assign transactionOutput = cpuResponseOutput.transaction;
endmodule
''')
        return self.build_run(work, 'tb_dcache_response',
                              [ROOT/'verilog/rtl/common/rv32_pkg.sv', probe,
                               ROOT/'scripts/tests/dcache_response_tb.sv'])

    def test_response_identities(self):
        with tempfile.TemporaryDirectory(prefix='dcache-response-', dir='/tmp/opencode') as directory:
            run = self.run_identities(Path(directory), SOURCE.read_text())
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS DCache response identities combinations=4718592', run.stdout)
            print(run.stdout.strip(), flush=True)

    def test_unsafe_identities_rejected(self):
        text = SOURCE.read_text()
        mutations = {
            'repeated_early_response': (' &&\n      !missesInner[miss].responded', ''),
            'request_slot_as_transport_id': (
                'fillTransactionInner[miss] = requestInner[missesInner[miss].owner].request.transaction;',
                "fillTransactionInner[miss] = data_transaction_t'(missesInner[miss].owner);"),
        }
        for name, (old, new) in mutations.items():
            with self.subTest(mutation=name), tempfile.TemporaryDirectory(
                    prefix=f'dcache-response-{name}-', dir='/tmp/opencode') as directory:
                self.assertEqual(text.count(old), 1)
                run = self.run_identities(Path(directory), text.replace(old, new))
                self.assertNotEqual(run.returncode, 0, 'unsafe identity escaped checker')
                self.assertIn('response identity mismatch', run.stdout+run.stderr)
                print(f'PASS negative control {name}', flush=True)

    def test_cache_clock_contract(self):
        with tempfile.TemporaryDirectory(prefix='dcache-response-clock-', dir='/tmp/opencode') as directory:
            work = Path(directory)
            text = legacy_response(SOURCE.read_text())
            self.assertEqual(text.count('module rv32_dcache #('), 1)
            reference = work/'legacy.sv'
            reference.write_text(text.replace('module rv32_dcache #(', 'module rv32_dcache_converted #('))
            fixture = (ROOT/'scripts/tests/dcache_frontend_tb.sv').read_text()
            anchor = '  task automatic check_outputs;\n'
            self.assertEqual(fixture.count(anchor), 1)
            fixture = fixture.replace(anchor, anchor + '''    assert ({original.countInner, original.cursorInner, original.readIndexInner,
              original.readValidInner, original.readWayMaskInner, original.responseInner,
              original.earlyInner, original.fillMissInner, original.fillBeatInner,
              original.fillFireInner, original.releasedInner} ===
             {converted.countInner, converted.cursorInner, converted.readIndexInner,
              converted.readValidInner, converted.readWayMaskInner, converted.responseInner,
              converted.earlyInner, converted.fillMissInner, converted.fillBeatInner,
              converted.fillFireInner, converted.releasedInner})
      else $fatal(1, "response clock control mismatch");
    for (int row = 0; row < 8; row++)
      assert(original.requestInner[row] === converted.requestInner[row] &&
             original.olderInner[row] === converted.olderInner[row] &&
             original.rawInner[row] === converted.rawInner[row])
        else $fatal(1, "response request state mismatch row=%0d", row);
    for (int miss = 0; miss < 4; miss++)
      assert(original.missesInner[miss] === converted.missesInner[miss])
        else $fatal(1, "response MSHR state mismatch miss=%0d", miss);
''')
            testbench = work/'clock_tb.sv'
            testbench.write_text(fixture)
            sources = [ROOT/'verilog/rtl/common/rv32_pkg.sv', ROOT/'scripts/ram/sram_fakeram.sv',
                       SOURCE, reference, ROOT/'verilog/rtl/memory/rv32_dmem.sv', testbench]
            run = self.build_run(work, 'tb_dcache_frontend', sources)
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS frontend equivalence', run.stdout)
            print('PASS response full-cache legacy/new clock and state contract', run.stdout.strip(), flush=True)
