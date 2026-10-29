#!/usr/bin/env python3
"""Current software/real AXI course DUT lockstep, without production probes."""
import argparse
import fnmatch
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess

from build import read_sources
from fakeram import with_ram_source

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--software', type=Path, default=ROOT.parent/'RV32IM_Simulator')
    parser.add_argument('--out', type=Path, default=Path('/tmp/opencode/course-sync-register'))
    parser.add_argument('--pattern', default='*')
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--commit-width', type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = args.software.resolve()/'src'
    paths = sorted(p for p in source.rglob('*') if p.is_file())
    rtl = with_ram_source(read_sources(ROOT/'verilog/filelist.f'))
    cmake = args.software.resolve()/'CMakeLists.txt'
    inputs = paths + rtl + [cmake, ROOT/'scripts/tests/course_sync_top.sv', ROOT/'scripts/tests/course_sync_driver.cpp', Path(__file__).resolve()]
    def identities():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = identities()
    binary = out/'obj/Vcourse_sync_top'
    if not args.skip_build:
        staged = out/'software'
        shutil.copytree(source, staged, dirs_exist_ok=True)
        header = staged/'include/CPU.hpp'
        original = header.read_text()
        assert original.count('class CPU {') == 1
        header.write_text(original.replace('class CPU {', 'class CPU {\n  friend struct CourseSyncProbe;'))
        active = re.search(r'set\(CPU_SOURCES(.*?)\)',cmake.read_text(),re.S).group(1)
        cpp = [staged/Path(p).relative_to('src') for p in active.split()]
        command = ['verilator', '--cc', '--exe', '--build', '--assert', '--unroll-count', '1024', '-Wno-fatal',
                   f'-DCPU_COMMIT_WIDTH={args.commit_width}',
                   '-j', '2', '--top-module', 'course_sync_top', '--Mdir', str(out/'obj'),
                   '-CFLAGS', f'-std=c++20 -O2 -DCPU_COMMIT_WIDTH={args.commit_width} -I{staged / "include"}',
                   *map(str,rtl), str(ROOT/'scripts/tests/course_sync_top.sv'),
                   str(ROOT/'scripts/tests/course_sync_driver.cpp'), *map(str,cpp)]
        with (out/'build.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError((out/'build.log').read_text(errors='replace')[-14000:])
        (out/'inputs.json').write_text(json.dumps(before, indent=2)+'\n')
        (out/'configuration.json').write_text(json.dumps(dict(commit_width=args.commit_width))+'\n')
    elif (json.loads((out/'inputs.json').read_text()) != before or
          not (out/'configuration.json').is_file() or
          json.loads((out/'configuration.json').read_text()) != dict(commit_width=args.commit_width)):
        raise ValueError('stale binary: source identities changed; rebuild required')
    rows = []
    (out/'report.json').write_text(json.dumps(dict(passed=False,status='running',rows=rows),indent=2)+'\n')
    for case in sorted((ROOT/'testcases').iterdir()):
        if not (case/'program.data').is_file() or not fnmatch.fnmatchcase(case.name,args.pattern):
            continue
        expected = int((case/'expected.txt').read_text())
        retired = json.loads((case/'metrics.json').read_text())['dynamic_instructions']
        run = subprocess.run([str(binary), str(case/'program.data'), str(expected), str(retired)],
                             capture_output=True, text=True, timeout=900)
        (out/f'{case.name}.log').write_text(run.stdout+run.stderr)
        rows.append(dict(case=case.name, passed=run.returncode == 0, stdout=run.stdout, stderr=run.stderr))
        (out/'report.json').write_text(json.dumps(dict(passed=False,status='running',rows=rows),indent=2)+'\n')
        print(case.name, run.stdout+run.stderr, flush=True)
        if run.returncode:
            break
    assert before == identities(), 'production sources changed during verification'
    report = dict(passed=bool(rows) and all(r['passed'] for r in rows), status='complete', rows=rows,
                   commit_width=args.commit_width,
                  scope='current main-tree CPU, shared slave events, real AXI DUT; pre-edge events and retirement',
                  source_unchanged=True, inputs=before)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    if not report['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
