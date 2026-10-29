"""Conditional-only specialization preserves generic BRU and accepted timing."""
from pathlib import Path
import fcntl
import os
import resource
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('verilator'),'requires Verilator')
class ConditionalBruTests(unittest.TestCase):
    def test_modes_and_dispatch_contract(self):
        lock=Path('/tmp/opencode/load-abc-20261021/heavy-job.lock')
        lock.parent.mkdir(parents=True,exist_ok=True)
        with lock.open('a') as guard:
            fcntl.flock(guard,fcntl.LOCK_EX|fcntl.LOCK_NB)
            os.sched_setaffinity(0,sorted(os.sched_getaffinity(0))[:2])
            if os.getpriority(os.PRIO_PROCESS,0)<10:os.nice(10-os.getpriority(os.PRIO_PROCESS,0))
            resource.setrlimit(resource.RLIMIT_CORE,(0,0))
            with tempfile.TemporaryDirectory(prefix='bru-conditional-',dir='/tmp/opencode') as directory:
                work=Path(directory)
                sources=[ROOT/'verilog/rtl/common/rv32_pkg.sv',ROOT/'verilog/rtl/common/rv32_cla.sv',
                         ROOT/'verilog/rtl/execute/rv32_bru.sv',ROOT/'verilog/rtl/execute/rv32_bru_unit.sv',
                         ROOT/'scripts/tests/bru_conditional_tb.sv']
                for negative in [False,True]:
                    obj=work/('negative' if negative else 'positive')
                    command=['verilator','--binary','--timing','--assert','-Wno-fatal','-j','1',
                             '--top-module','tb_bru_conditional',f'-GNEGATIVE={int(negative)}','--Mdir',str(obj),*map(str,sources)]
                    built=subprocess.run(command,capture_output=True,text=True,timeout=180)
                    self.assertEqual(built.returncode,0,(built.stdout+built.stderr)[-12000:])
                    run=subprocess.run([str(obj/'Vtb_bru_conditional')],cwd=work,capture_output=True,text=True,timeout=120)
                    text=run.stdout+run.stderr
                    if negative:
                        self.assertNotEqual(run.returncode,0,text)
                        self.assertIn('conditional-only BRU accepted a non-conditional operation',text)
                    else:
                        self.assertEqual(run.returncode,0,text)
                        self.assertIn('PASS conditional/default BRU:',text)
                        print(text.strip())


if __name__=='__main__':unittest.main()
