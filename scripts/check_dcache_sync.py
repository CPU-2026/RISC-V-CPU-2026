#!/usr/bin/env python3
"""Read-only main-tree DCache/DMEM lockstep; deliberately excludes software BPU."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from fakeram import RAM_SOURCE

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--software', type=Path, default=ROOT.parent/'RV32IM_Simulator')
    parser.add_argument('--out', type=Path, default=ROOT/'build/dcache-mshr-sync-20261016')
    args = parser.parse_args()
    software, out = args.software.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sv = [ROOT/'verilog/rtl/common/rv32_pkg.sv', ROOT/'verilog/rtl/memory/rv32_dcache.sv',
          ROOT/'verilog/rtl/memory/rv32_dmem.sv', RAM_SOURCE, ROOT/'scripts/tests/dcache_sync_top.sv']
    cpp = sorted(p for p in (software/'src').rglob('*.cpp') if p.name != 'main.cpp')
    driver = ROOT/'scripts/tests/dcache_sync_driver.cpp'
    paths = sorted(set(sv + cpp + [driver, Path(__file__).resolve()] + list((software/'src/include').glob('*.hpp'))))
    def identities():
        return [{'path':str(p), 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
    before = identities()
    command = ['verilator', '--cc', '--exe', '--build', '--assert', '-Wno-fatal', '--unroll-count', '1024',
               '-j', '1', '--top-module', 'dcache_sync_top', '--Mdir', str(out/'obj'),
               '-CFLAGS', f'-std=c++20 -O2 -I{software / "src/include"}',
               *map(str, sv), str(driver), *map(str,cpp)]
    with (out/'build.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError((out/'build.log').read_text()[-14000:])
    result = subprocess.run([str(out/'obj/Vdcache_sync_top')], capture_output=True, text=True, timeout=300)
    (out/'simulation.log').write_text(result.stdout+result.stderr)
    assert before == identities(), 'source changed during data-side verification'
    report = {'passed':result.returncode == 0, 'scope':'real software main-tree DCache/DMEM only; no BPU changes',
              'inputs':before, 'source_unchanged':True, 'stdout':result.stdout, 'stderr':result.stderr}
    (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(result.stdout+result.stderr, end='')
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
