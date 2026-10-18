"""Source-to-state provenance for flattened STA reports, without hardware tools."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from assessment_paths import generic_register_states


class CheckpointStateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='sta-state-', dir='/tmp/opencode')
        self.path = Path(self.temporary.name)/'generic.json'
        self.source = 'frontend/converted.v:10.2-20.5'
        self.targets = {'$auto$ff': {'attributes': {'src': self.source}}}

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, source=None, cell_type='$_DFFE_PP0P_'):
        design = {'modules': {'unrelated': {'netnames': {'wrong': {'bits': [7]}}},
                              'student_top': {
                                  'cells': {'$auto$ff': {'type': cell_type,
                                      'attributes': {'src': self.source if source is None else source},
                                      'connections': {'Q': [7]}}},
                                  'netnames': {
                                      'u_core.state': {'bits': [5, 6, 7, 8], 'offset': 8,
                                                       'attributes': {'src': 'frontend/converted.v:2'}},
                                      'u_core.flag': {'bits': [7]},
                                      '$mapping_net': {'bits': [7]}}}}}
        self.path.write_text(json.dumps(design, indent=2)+'\n')

    def test_named_vector_bit_and_scalar_alias(self):
        self.write()
        result = generic_register_states(self.path, self.targets)['$auto$ff']
        self.assertEqual(result['generic_type'], '$_DFFE_PP0P_')
        self.assertEqual([a['name'] for a in result['logical_q'][0]], ['u_core.state[10]', 'u_core.flag'])

    def test_source_mismatch_not_attributed(self):
        self.write(source='another-conversion.v:10')
        self.assertEqual(generic_register_states(self.path, self.targets), {})

    def test_only_flip_flops_can_bridge_state(self):
        self.write(cell_type='$_AND_')
        self.assertEqual(generic_register_states(self.path, self.targets), {})

    def test_missing_snapshot_and_empty_targets(self):
        self.assertEqual(generic_register_states(self.path, self.targets), {})
        self.write()
        self.assertEqual(generic_register_states(self.path, {}), {})
        self.assertEqual(generic_register_states(self.path, {'absent': self.targets['$auto$ff']}), {})


if __name__ == '__main__': unittest.main()
