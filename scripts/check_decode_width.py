#!/usr/bin/env python3
"""Real course RTL/independent ISA for width-dependent frontend capacities.

Profile syntax: fetch:decode:commit[:FQ:IQ]. The software only supplies the
existing external Slave and independent test ISA; it is NOT a cycle reference.
"""
import argparse
import fcntl
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import subprocess

from build import read_sources
from fakeram import with_ram_source

ROOT = Path(__file__).resolve().parents[1]


def profile(value):
    fields = list(map(int, value.split(':')))
    if len(fields) == 3:
        fields += [fields[1] << 1, fields[1] << 1]
    if len(fields) != 5 or any(width not in (1, 2) for width in fields[:3]):
        raise argparse.ArgumentTypeError('expected fetch:decode:commit[:FQ:IQ], widths 1 or 2')
    return tuple(fields)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--profile', type=profile, action='append')
    parser.add_argument('--pattern', default='*')
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    lock = Path('/tmp/opencode/load-abc-20261021/heavy-job.lock')
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
        os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:2])
        if os.getpriority(os.PRIO_PROCESS, 0) < 10:
            os.nice(10 - os.getpriority(os.PRIO_PROCESS, 0))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        run_profiles(args, out)


def run_profiles(args, out):
    software = ROOT.parent/'RV32IM_Simulator'
    cmake = software/'CMakeLists.txt'
    cpp = [software/path for path in re.search(r'set\(CPU_SOURCES(.*?)\)', cmake.read_text(), re.S)[1].split()]
    rtl = with_ram_source(read_sources(ROOT/'verilog/filelist.f'))
    test = ROOT/'scripts/tests'
    interpreter = (test/'course_sync_driver.cpp').read_text().split(
        '// Independent architectural interpreter.', 1)[1].split('struct CourseSyncProbe {', 1)[0]
    # Retain the opening comment discarded by split above.
    interpreter = '// Independent architectural interpreter.' + interpreter
    tracked = [*rtl, *cpp, *sorted((software/'src/include').glob('*.hpp')), cmake,
               test/'course_sync_top.sv', test/'course_sync_driver.cpp',
               test/'decode_course_top.sv', test/'decode_course_driver.cpp', Path(__file__).resolve()]
    cases = sorted(p for p in (ROOT/'testcases').iterdir()
                   if (p/'program.data').is_file() and fnmatch.fnmatchcase(p.name, args.pattern))
    if not cases:
        raise ValueError('no matching course cases')
    for case in cases:
        tracked += [case/'program.data', case/'expected.txt', case/'metrics.json']
    def identities():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in tracked}
    before = identities()
    report = dict(passed=False, status='running', profiles=[], inputs=before,
                  scope='real RTL/independent retirement ISA; no software-cycle equivalence or PPA claim')
    def save():
        (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    save()
    for widths in args.profile or [(2, 1, 2, 2, 2), (2, 2, 2, 4, 4)]:
        fetch, decode, commit, fq, iq = widths
        folder = out/('-'.join(map(str, widths)))
        folder.mkdir(exist_ok=True)
        binary = folder/'obj/Vdecode_course_top'
        config = dict(fetch=fetch, decode=decode, commit=commit, fq=fq, iq=iq)
        if not args.skip_build:
            (folder/'decode_isa.inc').write_text(interpreter)
            defines = [f'-DCPU_{name}={value}' for name, value in
                       [('FETCH_WIDTH', fetch), ('DECODE_WIDTH', decode), ('COMMIT_WIDTH', commit),
                        ('FQ_ENTRIES', fq), ('IQ_ENTRIES', iq)]]
            command = ['verilator', '--cc', '--exe', '--build', '--assert', '--unroll-count', '1024',
                       '-Wno-fatal', '-j', '1', '--top-module', 'decode_course_top', '--Mdir', str(folder/'obj'),
                       *defines, '-CFLAGS', f'-std=c++20 -O2 -DCPU_COMMIT_WIDTH={commit} -I{software/"src/include"} -I{folder}',
                       *map(str, rtl), str(test/'course_sync_top.sv'), str(test/'decode_course_top.sv'),
                       str(test/'decode_course_driver.cpp'), *map(str, cpp)]
            with (folder/'build.log').open('w') as log:
                build = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
            if build.returncode:
                raise RuntimeError((folder/'build.log').read_text(errors='replace')[-16000:])
            if '%Warning-UNOPTFLAT' in (folder/'build.log').read_text():
                raise RuntimeError('combinational cycle in configured RTL')
            (folder/'inputs.json').write_text(json.dumps(before, indent=2)+'\n')
            (folder/'configuration.json').write_text(json.dumps(config)+'\n')
        elif (json.loads((folder/'inputs.json').read_text()) != before or
              json.loads((folder/'configuration.json').read_text()) != config):
            raise ValueError('stale binary: configuration/source identities differ')
        rows = []
        item = dict(configuration=config, passed=False, rows=rows)
        report['profiles'].append(item)
        save()
        for case in cases:
            expected = (case/'expected.txt').read_text().strip()
            retired = json.loads((case/'metrics.json').read_text())['dynamic_instructions']
            run = subprocess.run([str(binary), str(case/'program.data'), expected, str(retired)],
                                 capture_output=True, text=True, timeout=900)
            text = run.stdout+run.stderr
            (folder/f'{case.name}.log').write_text(text)
            counters = {key: int(value) for key, value in re.findall(r'(\w+)=(\d+)', run.stdout)}
            rows.append(dict(case=case.name, passed=run.returncode == 0, **counters))
            save()
            print(widths, case.name, text.strip(), flush=True)
            if run.returncode:
                raise RuntimeError('independent course ISA failed')
        if fetch == 2 and decode == 2 and sum(row.get('dual_decode', 0) for row in rows) == 0:
            raise RuntimeError('no actual dual decode observed')
        item['passed'] = True
        save()
    if before != identities():
        raise ValueError('sources changed during validation')
    report.update(passed=True, status='complete', source_unchanged=True)
    save()


if __name__ == '__main__':
    main()
