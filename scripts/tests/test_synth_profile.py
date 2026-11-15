import copy
import io
import itertools
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synth
from fakeram import prepare_memories
from synth_profile import WallClockProfile


class SynthesisProfileTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.out = Path(self.temporary.name)
        self.stdout = patch('sys.stdout', new_callable=io.StringIO)
        self.stdout.start()
        self.addCleanup(self.stdout.stop)

    def profile(self):
        return json.loads((self.out / 'profile.json').read_text())

    def test_running_nested_and_completed_records(self):
        with patch('synth_profile.time.perf_counter', side_effect=itertools.count(0, .25)):
            profile = WallClockProfile(self.out)
            with profile.measure('parent'):
                self.assertEqual(self.profile()['stages'][0]['status'], 'running')
                with profile.measure('child'):
                    self.assertEqual(self.profile()['stages'][1]['parent_id'], 0)
        rows = self.profile()['stages']
        self.assertEqual([r['status'] for r in rows], ['completed', 'completed'])
        self.assertGreater(rows[0]['wall_seconds'], rows[1]['wall_seconds'])
        self.assertEqual(rows[1]['depth'], 1)
        self.assertIn('child', (self.out / 'profile.txt').read_text())

    def test_yosys_flags_script_and_call_wall_time(self):
        profile = WallClockProfile(self.out)
        commands = ['read_verilog "unchanged.v"', synth.stat_width(self.out, 'boundary')]
        with patch('synth.subprocess.run', return_value=subprocess.CompletedProcess([], 0)) as run:
            synth.run_yosys('/tools/yosys', self.out, 'elaborate', commands, profile=profile)
        args = run.call_args.args[0]
        self.assertNotIn('-T', args)
        for flag in ('-t', '-d', '-l', '-q', '-Q'):
            self.assertIn(flag, args)
        self.assertEqual(args[-2:], ['-s', 'elaborate.ys'])
        self.assertTrue(run.call_args.kwargs['check'])
        self.assertEqual(commands[1], 'tee -o stats/boundary.rpt stat -width')
        self.assertEqual((self.out / 'elaborate.ys').read_text(), '\n'.join(commands) + '\n')
        row = self.profile()['stages'][0]
        self.assertEqual((row['name'], row['returncode'], row['status']), ('yosys.elaborate', 0, 'completed'))
        self.assertGreaterEqual(row['wall_seconds'], 0)

    def test_failed_yosys_is_recorded_and_not_swallowed(self):
        profile = WallClockProfile(self.out)
        with patch('synth.subprocess.run', side_effect=subprocess.CalledProcessError(7, ['yosys'])):
            with self.assertRaises(subprocess.CalledProcessError):
                synth.run_yosys('yosys', self.out, 'synth', ['check -assert'], profile=profile)
        row = self.profile()['stages'][0]
        self.assertEqual((row['status'], row['returncode']), ('failed', 7))

    def test_legacy_yosys_call_without_profile_remains_supported(self):
        with patch('synth.subprocess.run', return_value=subprocess.CompletedProcess([], 0)):
            synth.run_yosys('yosys', self.out, 'legacy', ['check -assert'])
        self.assertEqual((self.out / 'legacy.ys').read_text(), 'check -assert\n')
        self.assertFalse((self.out / 'profile.json').exists())

    def test_interrupt_is_recorded_and_propagated(self):
        profile = WallClockProfile(self.out)
        with self.assertRaises(KeyboardInterrupt):
            with profile.measure('interrupted'):
                raise KeyboardInterrupt()
        self.assertEqual(self.profile()['stages'][0]['status'], 'failed')
        self.assertEqual(profile.stack, [])

    def test_ram_validation_failure_is_not_bypassed(self):
        profile = WallClockProfile(self.out)
        invalid = {'modules': {'student_top': {'cells': {
            'mem': {'type': 'unsupported_external', 'connections': {}}
        }}}}
        with self.assertRaisesRegex(ValueError, 'unsupported external module'):
            prepare_memories(invalid, self.out / 'ram', profile=profile)
        self.assertEqual(self.profile()['stages'][0]['status'], 'failed')
        self.assertFalse((self.out / 'ram/prepared.json').exists())

    def test_json_processing_success_and_failure(self):
        profile = WallClockProfile(self.out)
        path = self.out / 'design.json'
        path.write_text('{"modules": {}}')
        self.assertEqual(synth.read_netlist(path, profile, 'read.good'), {'modules': {}})
        path.write_text('bad JSON')
        with self.assertRaises(ValueError):
            synth.read_netlist(path, profile, 'read.bad')
        with self.assertRaises(FileNotFoundError):
            synth.read_netlist(self.out / 'missing.json', profile, 'read.missing')
        self.assertEqual([r['status'] for r in self.profile()['stages']], ['completed', 'failed', 'failed'])

    def test_statistics_timestamp_cleanup_preserves_raw_and_plain_json(self):
        profile = WallClockProfile(self.out)
        text = '{\n  "modules": {}, "note": "[00001.000000] unchanged"\n}\n'
        raw, clean = self.out / 'stat.raw.json', self.out / 'stat.json'
        for timestamped in (False, True):
            source = ''.join('[00001.123456] ' + line for line in text.splitlines(keepends=True)) if timestamped else text
            raw.write_text(source)
            result = synth.read_yosys_statistics(raw, clean, profile)
            self.assertEqual(result, json.loads(text))
            self.assertEqual(clean.read_text(), text)
            self.assertEqual(raw.read_text(), source)

    def test_statistics_rejects_diagnostics_mixed_prefixes_and_corruption(self):
        profile = WallClockProfile(self.out)
        raw, clean = self.out / 'stat.raw.json', self.out / 'stat.json'
        for text in ('[1.000] {\n}\n', '[1.000] {}\n[1.000] Warning: unexpected\n',
                     '[1.000] {bad}\n', '[bad] {}\n', '', '[]', '{} trailing'):
            with self.subTest(text=text):
                raw.write_text(text)
                with self.assertRaises(ValueError):
                    synth.read_yosys_statistics(raw, clean, profile)
                self.assertFalse(clean.exists())
        with self.assertRaisesRegex(ValueError, 'distinct path'):
            synth.read_yosys_statistics(raw, raw, profile)

    def test_ram_outputs_identical_with_and_without_measurement(self):
        design = {'modules': {
            'ram': {'attributes': {'hdlname': 'sram_fakeram'},
                    'parameter_default_values': {k: f'{v:032b}' for k, v in
                                                [('DEPTH', 4), ('WIDTH', 8), ('WRITE_GRANULARITY', 4)]}},
            'student_top': {'cells': {'mem': {'type': 'ram', 'parameters': {},
                'connections': {p: [0] for p in ('clk', 'en', 'we', 'wmask', 'addr', 'wdata')}}}},
        }}
        plain, measured = self.out / 'plain', self.out / 'measured'
        left, right = copy.deepcopy(design), copy.deepcopy(design)
        prepare_memories(left, plain)
        profile = WallClockProfile(self.out)
        with profile.measure('python.prepare_memories'):
            prepare_memories(right, measured, profile=profile)
        self.assertEqual(left, right)
        self.assertEqual({p.name: p.read_bytes() for p in plain.iterdir()},
                         {p.name: p.read_bytes() for p in measured.iterdir()})
        rows = self.profile()['stages']
        self.assertEqual([r['name'] for r in rows[1:]],
                         ['python.ram_rewrite', 'python.write_prepared_json', 'python.write_ram_wrappers_and_libraries'])
        self.assertTrue(all(r['parent_id'] == 0 for r in rows[1:]))

    def run_main(self, resume=False, frontend='yosys'):
        source = self.out / 'tiny.v'
        source.write_text('module student_top(input clock); endmodule\n')
        libs = self.out / 'lib'
        libs.mkdir()
        for name in ('a.lib', 'b.lib', 'c_SEQ_test.lib', 'd.lib', 'e.lib'):
            (libs / name).write_text('library(test) {}\n')
        elaborated = {'modules': {'student_top': {'ports': {'clock': {'direction': 'input', 'bits': [1]}}, 'cells': {}}}}
        argv = ['synth.py', '--out', str(self.out / 'build'), '--yosys', '/fake/yosys',
                '--sta', '/fake/sta', '--asap7-lib', str(libs), '--filelist', str(self.out / 'filelist.f')]
        if resume:
            snapshot = self.out / 'input.json'
            snapshot.write_text(json.dumps(elaborated))
            (self.out / 'pre-abc.json').write_text('{"modules": {}}')
            argv += ['--elaborated-json', str(snapshot), '--pre-abc-json', str(self.out / 'pre-abc.json')]
        captured = {}

        def fake_convert(sv2v, sources, directory):
            directory.mkdir(parents=True)
            converted = directory / 'converted.v'
            converted.write_text(source.read_text())
            return converted, {'name': 'sv2v'}

        def fake_yosys(yosys, out, name, commands, profile=None):
            self.assertIsNotNone(profile)
            captured[name] = commands
            if name == 'elaborate':
                (out / 'elaborated.json').write_text(json.dumps(elaborated))
            else:
                (out / 'design.json').write_text('{"modules": {}}')
                (out / 'stat.raw.json').write_text('[00001.000000] {}\n')

        with patch.object(sys, 'argv', argv), \
             patch('synth.read_sources', return_value=[source]), \
             patch('synth.executable', side_effect=str), \
             patch('synth.select_frontend', return_value=(frontend, '/fake/sv2v' if frontend == 'sv2v' else None)), \
             patch('synth.convert_sources', side_effect=fake_convert), \
             patch('synth.run_yosys', side_effect=fake_yosys), \
             patch('synth.area_report', return_value={}), \
             patch('synth.analyze', return_value={}), \
             patch('synth.format_report', return_value='report\n'), \
             patch('synth.subprocess.check_output', return_value='version\n'):
            synth.main()
        result = json.loads((self.out / 'build/opt/profile.json').read_text())
        self.assertIn('python.read_elaborated_json', [r['name'] for r in result['stages']])
        self.assertIn('python.read_mapped_design_json', [r['name'] for r in result['stages']])
        self.assertIn('python.area_report', [r['name'] for r in result['stages']])
        self.assertIn('opensta.analyze', [r['name'] for r in result['stages']])
        return captured

    def test_stats_at_existing_boundaries_without_changing_synthesis_commands(self):
        captured = self.run_main()
        elaborate, mapped = captured['elaborate'], captured['synth']
        self.assertEqual(sum('stat -width' in c for c in elaborate), 3)
        reads = [c for c in elaborate if c.startswith('read_verilog ')]
        self.assertEqual(reads[0], 'read_verilog -sv -defer -noblackbox -D SYNTHESIS ' + synth.quote(synth.RAM_SOURCE))
        self.assertTrue(all('-defer' in c.split() for c in reads))
        self.assertIn('tiny.v', reads[1])
        self.assertEqual(sum('stat -width' in c for c in mapped), 6)
        self.assertIn('synth -top student_top -noabc -flatten', mapped)
        self.assertEqual(sum(c.startswith('synth ') for c in mapped), 1)
        self.assertEqual(sum(c.startswith('abc ') for c in mapped), 1)
        self.assertTrue(any('-D 2000' in c and c.startswith('abc ') for c in mapped))
        self.assertFalse(any('-fast' in c or '-noshare' in c for c in mapped))
        self.assertTrue(any(c.startswith('tee -o ') and 'stat -json' in c for c in mapped))

    def test_sv2v_uses_ram_first_and_deferred_cpu_read(self):
        captured = self.run_main(frontend='sv2v')
        reads = [c for c in captured['elaborate'] if c.startswith('read_verilog ')]
        self.assertEqual(len(reads), 2)
        self.assertIn('sram_fakeram.sv', reads[0])
        self.assertIn('converted.v', reads[1])
        self.assertTrue(all('-defer' in c.split() for c in reads))
        self.assertIn('hierarchy -top student_top', captured['elaborate'])

    def test_pre_abc_resume_keeps_original_boundary_and_skips_completed_passes(self):
        captured = self.run_main(resume=True)
        self.assertNotIn('elaborate', captured)
        commands = captured['synth']
        self.assertIn('pre-abc.json', commands[0])
        self.assertFalse(any(c.startswith(('synth ', 'dfflibmap ')) for c in commands))
        self.assertEqual(sum('synth-before-abc.rpt' in c for c in commands), 1)
        self.assertEqual(sum(c.startswith('abc ') for c in commands), 1)


if __name__ == '__main__':
    unittest.main()
