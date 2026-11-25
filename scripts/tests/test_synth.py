from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import synth


class SynthesisTests(unittest.TestCase):
    def test_yosys_receives_the_written_script_and_propagates_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)
            commands = ['hierarchy -check -top student_top', 'check -assert']
            error = subprocess.CalledProcessError(7, ['yosys'])
            with patch.object(synth.subprocess, 'run', side_effect=error) as run:
                with self.assertRaises(subprocess.CalledProcessError) as raised:
                    synth.run_yosys('yosys', out, 'elaborate', commands)
            script = out / 'elaborate.ys'
            self.assertEqual(script.read_text(), '\n'.join(commands) + '\n')
            self.assertEqual(raised.exception.returncode, 7)
            run.assert_called_once_with([
                'yosys', '-Q', '-T', '-q', '-l', str(out / 'elaborate.log'), '-s', str(script),
            ], check=True)


if __name__ == '__main__':
    unittest.main()
