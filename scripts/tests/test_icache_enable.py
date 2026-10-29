"""Early physical SRAM read enable; full logical/SRAM state remains unchanged."""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'verilog/rtl/memory/rv32_icache.sv'


def assignment(text, name):
    matches = re.findall(r'  assign ' + name + r' =[^;]+;', text)
    if len(matches) != 1:
        raise ValueError(f'expected one {name} assignment')
    return matches[0]


def legacy_enable(text):
    return text.replace(assignment(text, 'sramEnableInner'),
                        '  assign sramEnableInner = !flushInput && (fillFireInner || requestFireInner);')


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class IcacheEnableTests(unittest.TestCase):
    def build_run(self, work, top, sources, extra_flags=()):
        work.mkdir(parents=True, exist_ok=True)
        cmd = ['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024',
               '-Wno-fatal', '-j', '1', '--top-module', top, '--Mdir', str(work/'obj'),
               *extra_flags, *map(str, sources)]
        with (work/'build.log').open('w') as log:
            build = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        self.assertEqual(build.returncode, 0, (work/'build.log').read_text()[-14000:])
        return subprocess.run([str(work/'obj'/f'V{top}')], cwd=work,
                              capture_output=True, text=True, timeout=120)

    def run_boolean(self, work, text):
        body = '\n'.join(assignment(text, name) for name in (
            'refillHitInner', 'readBlockedInner', 'cpuReqReadyOutput', 'requestFireInner', 'sramEnableInner'))
        probe = work/'probe.sv'
        probe.write_text('''module icache_enable_probe (
  input logic [8:0] flagsInput,
  input logic [3:0] countInner,
  output logic enableOutput, legacyOutput
);
  import rv32_pkg::*;
  localparam int REQUEST_DEPTH=8, COUNT_W=4, OFFSET_W=6;
  logic rstNInput, flushInput, freezeInput, fillFireInner, hitInner, sameLine;
  logic valid, memReqReadyInput, responseFireInner;
  logic refillHitInner, readBlockedInner, cpuReqReadyOutput, requestFireInner, sramEnableInner;
  icache_cpu_request_input_t cpuRequestInput;
  icache_line_response_input_t memResponseInput;
  assign {rstNInput, flushInput, freezeInput, fillFireInner, hitInner, sameLine,
          valid, memReqReadyInput, responseFireInner} = flagsInput;
  assign cpuRequestInput = '{valid:valid, address:sameLine ? 32'h400 : 32'h440, default:'0};
  assign memResponseInput = '{address:32'h400, default:'0};
''' + body + '''
  assign enableOutput = sramEnableInner;
  // Independent specification of the intentionally broader physical CE.
  // Logical requestFire/readValid and real SRAM contents are checked below.
  assign legacyOutput = flagsInput[8] && !flagsInput[7] && !flagsInput[6];
endmodule
''')
        return self.build_run(work, 'tb_icache_enable_bool',
                              [ROOT/'verilog/rtl/common/rv32_pkg.sv', probe,
                               ROOT/'scripts/tests/icache_enable_bool_tb.sv'])

    def test_boolean_assignments(self):
        with tempfile.TemporaryDirectory(prefix='icache-enable-bool-', dir='/tmp/opencode') as directory:
            run = self.run_boolean(Path(directory), SOURCE.read_text())
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS ICache enable Boolean combinations=8192', run.stdout)
            print(run.stdout.strip(), flush=True)

    def test_unsafe_enables_rejected(self):
        text = SOURCE.read_text()
        old = assignment(text, 'sramEnableInner')
        mutations = {
            'drop_required_reads': '  assign sramEnableInner = fillFireInner;',
            'drop_fill_ownership': '  assign sramEnableInner = rstNInput && !freezeInput && !flushInput && !fillFireInner;',
        }
        for name, new in mutations.items():
            with self.subTest(mutation=name), tempfile.TemporaryDirectory(
                    prefix=f'icache-enable-{name}-', dir='/tmp/opencode') as directory:
                self.assertEqual(text.count(old), 1)
                work = Path(directory)
                run = self.run_boolean(work, text.replace(old, new))
                self.assertNotEqual(run.returncode, 0, 'unsafe enable escaped checker')
                self.assertIn('enable mismatch', run.stdout+run.stderr)
                reference = work/'reference.sv'
                reference.write_text(legacy_enable(text).replace('module rv32_icache #(', 'module rv32_icache_reference #('))
                mutated = work/'mutated.sv'
                mutated.write_text(text.replace(old, new))
                run = self.build_run(work/'clock', 'tb_icache_enable_clock',
                                     [ROOT/'verilog/rtl/common/rv32_pkg.sv', ROOT/'scripts/ram/sram_fakeram.sv',
                                      mutated, reference, ROOT/'scripts/tests/icache_enable_clock_tb.sv'])
                self.assertNotEqual(run.returncode, 0, 'unsafe physical access escaped clock/SRAM checker')
                self.assertIn('required SRAM access suppressed', run.stdout+run.stderr)
                print(f'PASS negative control {name}', flush=True)

    def test_clock_and_sram(self):
        with tempfile.TemporaryDirectory(prefix='icache-enable-clock-', dir='/tmp/opencode') as directory:
            work = Path(directory)
            text = legacy_enable(SOURCE.read_text())
            self.assertEqual(text.count('module rv32_icache #('), 1)
            reference = work/'legacy.sv'
            reference.write_text(text.replace('module rv32_icache #(', 'module rv32_icache_reference #('))
            sources = [ROOT/'verilog/rtl/common/rv32_pkg.sv', ROOT/'scripts/ram/sram_fakeram.sv',
                       SOURCE, reference, ROOT/'scripts/tests/icache_enable_clock_tb.sv']
            run = self.build_run(work, 'tb_icache_enable_clock', sources)
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS ICache enable clock', run.stdout)
            print(run.stdout.strip(), flush=True)

    @unittest.skipUnless(shutil.which('sv2v'), 'requires sv2v')
    def test_converted_clock_and_sram(self):
        sys.path.insert(0, str(ROOT/'scripts'))
        from sv_frontend import convert_sources
        with tempfile.TemporaryDirectory(prefix='icache-enable-converted-', dir='/tmp/opencode') as directory:
            work = Path(directory)
            converted, _ = convert_sources(shutil.which('sv2v'),
                                            [ROOT/'verilog/rtl/common/rv32_pkg.sv', SOURCE], work/'frontend',
                                            top='rv32_icache')
            text, count = re.subn(r'\bmodule rv32_icache\b', 'module rv32_icache_reference', converted.read_text())
            self.assertEqual(count, 1)
            reference = work/'converted.v'
            reference.write_text(text)
            sources = [ROOT/'verilog/rtl/common/rv32_pkg.sv', ROOT/'scripts/ram/sram_fakeram.sv',
                       SOURCE, reference, ROOT/'scripts/tests/icache_enable_clock_tb.sv']
            run = self.build_run(work, 'tb_icache_enable_clock', sources, ['-GALLOW_EXTRA_READS=0'])
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            self.assertIn('PASS ICache enable clock', run.stdout)
            print('PASS actual sv2v conversion', run.stdout.strip(), flush=True)
