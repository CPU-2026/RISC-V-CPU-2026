#!/usr/bin/env python3
"""Random independent AXI-channel backpressure against the real software modules."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--software',type=Path,default=ROOT.parent/'RV32IM_Simulator')
    parser.add_argument('--out',type=Path,default=Path('/tmp/opencode/axi-sync-register'))
    args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    software=args.software.resolve()
    cmake=software/'CMakeLists.txt'
    cpp=[software/p for p in re.search(r'set\(CPU_SOURCES(.*?)\)',cmake.read_text(),re.S).group(1).split()]
    sv=[ROOT/'verilog/rtl/common/rv32_pkg.sv',*[ROOT/'verilog/rtl/memory'/f'rv32_axi_{name}.sv' for name in ('fetch','data','bus')],ROOT/'scripts/tests/axi_sync_top.sv']
    driver=ROOT/'scripts/tests/axi_sync_driver.cpp'
    paths=cpp+sv+[driver,cmake,Path(__file__).resolve()]+sorted((software/'src/include').glob('*.hpp'))
    def identities():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before=identities()
    command=['verilator','--cc','--exe','--build','--assert','--unroll-count','1024','-j','2',
      '--top-module','axi_sync_top','--Mdir',str(out/'obj'),'-CFLAGS',f'-std=c++20 -O2 -I{software / "src/include"}',
      *map(str,sv),str(driver),*map(str,cpp)]
    with (out/'build.log').open('w') as log:result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError((out/'build.log').read_text(errors='replace')[-12000:])
    result=subprocess.run([str(out/'obj/Vaxi_sync_top')],capture_output=True,text=True,timeout=120)
    assert before==identities(),'production sources changed'
    (out/'report.json').write_text(json.dumps(dict(passed=result.returncode==0,stdout=result.stdout,stderr=result.stderr,
      source_unchanged=True,inputs=before),indent=2)+'\n')
    print(result.stdout+result.stderr,end='')
    if result.returncode:raise SystemExit(result.returncode)


if __name__=='__main__':main()
