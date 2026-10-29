#!/usr/bin/env python3
"""Real RTL dual rename: independent retirement ISA, optional SW cycles and frozen scalar trace.

The external Slave is unchanged. RENAME_WIDTH changes allocation only, not ALUs,
CDBs, AGU, Cache/AXI ports or retirement width. All builds/reports stay in --out.
"""
import argparse
import concurrent.futures
import fcntl
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess

from build import read_sources
from fakeram import with_ram_source

ROOT = Path(__file__).resolve().parents[1]
SOFTWARE = ROOT.parent / 'RV32IM_Simulator'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    cmake = SOFTWARE / 'CMakeLists.txt'
    cpp = [SOFTWARE / p for p in re.search(r'set\(CPU_SOURCES(.*?)\)', cmake.read_text(), re.S)[1].split()]
    rtl = with_ram_source(read_sources(ROOT / 'verilog/filelist.f'))
    test = ROOT / 'scripts/tests'
    cases = sorted(p for p in (ROOT / 'testcases').iterdir()
                   if (p / 'program.data').is_file() and fnmatch.fnmatchcase(p.name, args.pattern))
    if not cases:
        raise ValueError('no matching course cases')
    directed = []
    if args.directed_report:
        old = json.loads(args.directed_report.read_text())
        for row in old['directed']:
            path = args.directed_report.parent / row['case'] / 'program.data'
            directed.append((row['case'], path, row['expected'], row['builds']['baseline'][2]))
    tracked = [*rtl, *cpp, cmake, Path(__file__).resolve(), test / 'course_sync_top.sv',
               test / 'course_sync_driver.cpp', test / 'decode_course_top.sv', test / 'decode_course_driver.cpp']
    tracked += sorted((SOFTWARE / 'src/include').glob('*.hpp'))
    for case in cases:
        tracked += [case / p for p in ('program.data', 'expected.txt', 'metrics.json')]
    tracked += [d[1] for d in directed]
    def identities():
        return {str(p): sha(p) for p in tracked}
    before = identities()
    report = dict(passed=False, status='building', profiles=[], inputs=before,
                  configuration=dict(fetch=args.fetch_width, decode=args.decode_width, commit=args.commit_width),
                  scope='real RTL independent retirement ISA; configured SW cycle and scalar frozen-trace checks only')
    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    reference = json.loads(args.software_report.read_text()) if args.software_report else None
    if reference:
        assert reference['passed'] and reference['fixed'] == dict(fetch_width=args.fetch_width,
            decode_width=args.decode_width, commit_width=args.commit_width), 'software reference configuration differs'
        swrows = {r['case']: r['builds'] for r in reference['course']}
    if args.baseline_binary and (args.fetch_width, args.decode_width, args.commit_width) != (2, 2, 2):
        raise ValueError('frozen baseline option requires fetch/decode/commit=2/2/2')
    interpreter = (test / 'course_sync_driver.cpp').read_text().split(
        '// Independent architectural interpreter.', 1)[1].split('struct CourseSyncProbe {', 1)[0]
    widths = args.rename_width or [1, 2]
    binaries = {}
    for rename in widths:
        folder = out / f'rename-{rename}'
        folder.mkdir(exist_ok=True)
        (folder / 'decode_isa.inc').write_text('// Independent architectural interpreter.' + interpreter)
        configuration = dict(fetch=args.fetch_width, decode=args.decode_width,
                             commit=args.commit_width, rename=rename)
        binary = folder / 'obj/Vdecode_course_top'
        if not args.skip_build:
            defines = [f'-DCPU_{key}={value}' for key, value in
                       [('FETCH_WIDTH', args.fetch_width), ('DECODE_WIDTH', args.decode_width),
                        ('COMMIT_WIDTH', args.commit_width), ('RENAME_WIDTH', rename)]]
            command = ['verilator', '--cc', '--exe', '--build', '--assert', '--unroll-count', '1024',
                       '-Wno-fatal', '-j', str(args.jobs), '--top-module', 'decode_course_top',
                       '--Mdir', str(folder / 'obj'), *defines, '-CFLAGS',
                       f'-std=c++20 -O2 -DCPU_COMMIT_WIDTH={args.commit_width} -I{SOFTWARE/"src/include"} -I{folder}',
                       *map(str, rtl), str(test / 'course_sync_top.sv'), str(test / 'decode_course_top.sv'),
                       str(test / 'decode_course_driver.cpp'), *map(str, cpp)]
            with (folder / 'build.log').open('w') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
            log = (folder / 'build.log').read_text()
            if '%Warning-UNOPTFLAT' in log or '%Warning-LATCH' in log:
                raise ValueError('combinational cycle or latch in RTL build')
            (folder / 'inputs.json').write_text(json.dumps(before, indent=2) + '\n')
            (folder / 'configuration.json').write_text(json.dumps(configuration) + '\n')
        elif (json.loads((folder / 'inputs.json').read_text()) != before or
              json.loads((folder / 'configuration.json').read_text()) != configuration):
            raise ValueError('stale binary or configuration')
        binaries[rename] = binary
        report['profiles'].append(dict(configuration=configuration, binary_sha256=sha(binary),
                                       passed=False, rows=[], directed=[]))
        save()
        print('BUILT', configuration, flush=True)
    report['status'] = 'testing'
    save()
    def simulate(binary, name, path, expected, retired, logpath):
        result = subprocess.run([str(binary), str(path), str(expected), str(retired)],
                                capture_output=True, text=True, timeout=900)
        text = result.stdout + result.stderr
        logpath.write_text(text)
        counters = {key: int(value) for key, value in re.findall(r'(\w+)=(\d+)', result.stdout)}
        if result.returncode or not text.startswith('PASS ') or 'cycles' not in counters:
            raise ValueError(f'{name}: RTL/independent ISA failed: {text[-6000:]}')
        return counters
    for entry in report['profiles']:
        rename = entry['configuration']['rename']
        binary = binaries[rename]
        folder = out / f'rename-{rename}'
        for name, path, expected, retired in directed:
            counters = simulate(binary, name, path, expected, retired, folder / f'directed-{name}.log')
            entry['directed'].append(dict(case=name, **counters))
            save()
        def check(case):
            expected = int((case / 'expected.txt').read_text())
            retired = int(json.loads((case / 'metrics.json').read_text())['dynamic_instructions'])
            actual = simulate(binary, case.name, case / 'program.data', expected, retired, folder / f'{case.name}.log')
            if reference:
                key = f'f{args.fetch_width}d{args.decode_width}r{rename}-assert'
                sw = swrows[case.name][key]
                if (actual['cycles'], actual['core'], actual['retired']) != (sw['cycles'], sw['core'], sw['retired']):
                    raise ValueError(f'{case.name}: RTL/SW timing differs: {actual} != {sw}')
            if rename == 1 and args.baseline_binary:
                baseline = simulate(args.baseline_binary, case.name, case / 'program.data', expected, retired,
                                    folder / f'baseline-{case.name}.log')
                for key in ('cycles', 'core', 'retired', 'dual', 'dual_decode', 'trace'):
                    if actual[key] != baseline[key]:
                        raise ValueError(f'{case.name}: frozen scalar {key} differs: {actual} != {baseline}')
            return dict(case=case.name, **actual)
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.case_jobs) as pool:
            futures = [pool.submit(check, case) for case in cases]
            for future in concurrent.futures.as_completed(futures):
                row = future.result()
                entry['rows'].append(row)
                entry['rows'].sort(key=lambda r: r['case'])
                save()
                print('PASS', rename, row['case'], row['cycles'], 'dual_issue', row['dual_issue'], flush=True)
        allrows = entry['rows'] + entry['directed']
        if rename == 2 and not sum(row['dual_issue'] for row in allrows):
            raise ValueError('no actual dual rename observed')
        if rename == 2 and directed and not all(sum(row[key] for row in allrows) for key in ('dual_load', 'dual_store', 'raw1', 'waw')):
            raise ValueError('missing double-memory/RAW/WAW coverage')
        if rename == 1 and any(row['dual_issue'] for row in allrows):
            raise ValueError('single rename issued two instructions')
        entry['passed'] = True
        save()
    if before != identities():
        raise ValueError('production/test inputs changed during validation')
    report.update(passed=True, status='complete', inputs_unchanged=True)
    save()
    print('PASS all profiles; report:', out / 'report.json', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--rename-width', type=int, choices=(1, 2), action='append')
    parser.add_argument('--fetch-width', type=int, choices=(1, 2), default=2)
    parser.add_argument('--decode-width', type=int, choices=(1, 2), default=2)
    parser.add_argument('--commit-width', type=int, choices=(1, 2), default=2)
    parser.add_argument('--pattern', default='*')
    parser.add_argument('--software-report', type=Path)
    parser.add_argument('--baseline-binary', type=Path)
    parser.add_argument('--directed-report', type=Path)
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--case-jobs', type=int, default=2)
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    if args.jobs < 1 or args.case_jobs < 1:
        parser.error('job counts must be positive')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    lock = Path('/tmp/opencode/load-abc-20261021/heavy-job.lock')
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run(args)


if __name__ == '__main__':
    main()
