"""Width/capacity profiles, real parallel decoding and packet identity."""
from pathlib import Path
import fcntl
import os
import resource
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'), 'requires Verilator')
class DecodeWidthTests(unittest.TestCase):
    def test_frontend_profiles(self):
        lock = Path('/tmp/opencode/load-abc-20261021/heavy-job.lock')
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open('a') as guard:
            fcntl.flock(guard, fcntl.LOCK_EX | (0 if os.environ.get('CPU_VALIDATION_WAIT') == '1' else fcntl.LOCK_NB))
            os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:2])
            if os.getpriority(os.PRIO_PROCESS, 0) < 10:
                os.nice(10 - os.getpriority(os.PRIO_PROCESS, 0))
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
            with tempfile.TemporaryDirectory(prefix='decode-width-', dir='/tmp/opencode') as directory:
                work = Path(directory)
                rtl = ROOT / 'verilog/rtl'
                sources = [rtl/'common/rv32_pkg.sv', rtl/'common/rv32_epoch_fifo.sv',
                           rtl/'common/rv32_prefix_fifo.sv', rtl/'common/rv32_fetch_packet_fifo.sv',
                           rtl/'frontend/rv32_decoder.sv', rtl/'frontend/rv32_frontend.sv',
                           ROOT/'scripts/tests/decode_width_tb.sv']
                profiles = [(1, 1, 2, 2), (2, 1, 2, 2), (1, 2, 4, 4),
                            (2, 2, 4, 4), (2, 2, 2, 8), (2, 2, 8, 2)]
                for index, (fetch, decode, fq, iq) in enumerate(profiles):
                    with self.subTest(fetch=fetch, decode=decode, fq=fq, iq=iq):
                        obj = work/f'profile-{index}'
                        command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '-j', '1',
                                   '--top-module', 'tb_decode_width', '--Mdir', str(obj),
                                   f'-GFETCH={fetch}', f'-GDECODE={decode}', f'-GFQ={fq}', f'-GIQ={iq}',
                                   *map(str, sources)]
                        built = subprocess.run(command, capture_output=True, text=True, timeout=240)
                        self.assertEqual(built.returncode, 0, (built.stdout+built.stderr)[-12000:])
                        self.assertNotIn('%Warning-UNOPTFLAT', built.stderr)
                        run = subprocess.run([str(obj/'Vtb_decode_width')], cwd=work,
                                             capture_output=True, text=True, timeout=120)
                        self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
                        self.assertIn('PASS decode width', run.stdout)
                        print(run.stdout.strip(), flush=True)
                # Corrupt the actual second-lane CID reconstruction, not the oracle.
                original = sources[-2].read_text()
                token = 'fqInputInner.predictorCheckpointId + bpu_ckpt_id_t\'(1)'
                self.assertEqual(original.count(token), 1)
                negative = work/'frontend_bad_cid.sv'
                negative.write_text(original.replace(token, token.replace("'(1)", "'(0)")))
                obj = work/'negative'
                command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '-j', '1',
                           '--top-module', 'tb_decode_width', '--Mdir', str(obj),
                           *map(str, sources[:-2]), str(negative), str(sources[-1])]
                built = subprocess.run(command, capture_output=True, text=True, timeout=240)
                self.assertEqual(built.returncode, 0, (built.stdout+built.stderr)[-12000:])
                run = subprocess.run([str(obj/'Vtb_decode_width')], cwd=work,
                                     capture_output=True, text=True, timeout=120)
                self.assertNotEqual(run.returncode, 0, run.stdout+run.stderr)
                self.assertIn('IQ context', run.stdout+run.stderr)
                # Invalid widths, non-power-of-two queues and excess live-CID
                # budgets must fail rather than silently truncate identities.
                for name, options, reason in [
                    ('bad-width', ['-GDECODE=3', '-GFQ=4', '-GIQ=4'], 'DECODE_WIDTH must be 1 or 2'),
                    ('bad-depth', ['-GFQ=3', '-GIQ=4'], 'DEPTH must be a power of two'),
                    ('bad-budget', ['-GFQ=8', '-GIQ=8'], 'checkpoint live budget'),
                ]:
                    obj = work/name
                    command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '-j', '1',
                               '--top-module', 'tb_decode_width', '--Mdir', str(obj), *options, *map(str, sources)]
                    built = subprocess.run(command, capture_output=True, text=True, timeout=240)
                    self.assertEqual(built.returncode, 0, (built.stdout+built.stderr)[-12000:])
                    run = subprocess.run([str(obj/'Vtb_decode_width')], cwd=work,
                                         capture_output=True, text=True, timeout=120)
                    self.assertNotEqual(run.returncode, 0, run.stdout+run.stderr)
                    self.assertIn(reason, run.stdout+run.stderr)
                if shutil.which('sv2v'):
                    converted = work/'converted.v'
                    conversion = subprocess.run(['sv2v', *map(str, sources[:-1])],
                                                capture_output=True, text=True, timeout=120)
                    self.assertEqual(conversion.returncode, 0, conversion.stderr[-12000:])
                    converted.write_text(conversion.stdout)
                    obj = work/'converted'
                    # The native testbench imports the original package types;
                    # converted module ports have their identical packed layout.
                    command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '-j', '1',
                               '--top-module', 'tb_decode_width', '--Mdir', str(obj),
                               str(sources[0]), str(converted), str(sources[-1])]
                    built = subprocess.run(command, capture_output=True, text=True, timeout=240)
                    self.assertEqual(built.returncode, 0, (built.stdout+built.stderr)[-12000:])
                    self.assertNotIn('%Warning-UNOPTFLAT', built.stderr)
                    run = subprocess.run([str(obj/'Vtb_decode_width')], cwd=work,
                                         capture_output=True, text=True, timeout=120)
                    self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
                    self.assertIn('PASS decode width', run.stdout)
                    print('sv2v:', run.stdout.strip(), flush=True)


if __name__ == '__main__':
    unittest.main()
