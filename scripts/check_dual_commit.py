#!/usr/bin/env python3
"""Directed real-CPU dual retirement, software peers and independent RTL ISA.

Build the lockstep binary with check_course_sync.py first. Images and logs stay
outside the checkout; the course corpus and its expected results are untouched.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess

from build import read_sources
from fakeram import with_ram_source

ROOT = Path(__file__).resolve().parents[2]


def add(rd, rs, imm):
    return ((imm & 4095) << 20) | (rs << 15) | (rd << 7) | 0x13


def lui(rd, value):
    return (value << 12) | (rd << 7) | 0x37


def store(rs, base, offset=0):
    return ((offset >> 5) << 25) | (rs << 20) | (base << 15) | (2 << 12) | ((offset & 31) << 7) | 0x23


def load(rd, base, offset=0):
    return (offset << 20) | (base << 15) | (2 << 12) | (rd << 7) | 3


def div(rd, a, b):
    return (1 << 25) | (b << 20) | (a << 15) | (5 << 12) | (rd << 7) | 0x33


def regadd(rd, a, b):
    return (b << 20) | (a << 15) | (rd << 7) | 0x33


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rtl', type=Path)
    parser.add_argument('--main', type=Path)
    parser.add_argument('--template', type=Path)
    parser.add_argument('--unit-only', action='store_true')
    parser.add_argument('--out', type=Path, default=Path('/tmp/opencode/dual-commit/directed'))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    if args.unit_only:
        sources = with_ram_source(read_sources(ROOT/'RISC-V-CPU-2026/verilog/filelist.f'))
        with (args.out/'build.log').open('w') as log:
            build = subprocess.run(['verilator', '--binary', '--timing', '--assert', '--unroll-count', '1024',
                '-Wno-fatal', '-j', '2', '--top-module', 'dual_commit_tb', '--Mdir', str(args.out/'obj'),
                *map(str, sources), str(ROOT/'RISC-V-CPU-2026/scripts/tests/dual_commit_tb.sv')],
                stdout=log, stderr=subprocess.STDOUT)
        if build.returncode:
            raise RuntimeError((args.out/'build.log').read_text()[-10000:])
        subprocess.run([str(args.out/'obj/Vdual_commit_tb')], check=True)
        return
    if not all((args.rtl, args.main, args.template)):
        parser.error('--rtl, --main and --template are required without --unit-only')
    spec = importlib.util.spec_from_file_location('course', ROOT/'RV32IM_Simulator/data/course.py')
    course = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(course)
    setup = [lui(31, 0x80000), lui(11, 1), lui(12, 0xf0000), add(13, 0, 3), add(14, 0, 42)]
    tests = []

    def case(name, body, expected, data=None, prefix=(), trailing=()):
        words = [*prefix, *setup, *body, store(10, 31), *trailing, 0x6f]
        tests.append((name, words, expected, len(prefix) + len(setup) + len(body) + 1, data or {}))

    case('waw_recycle', [div(20, 12, 13), add(10, 0, 17), add(10, 0, 29), add(10, 0, 41)], 41)
    case('two_stores', [div(20, 12, 13), store(14, 11), store(14, 11, 4), load(10, 11, 4)], 42)
    case('two_loads', [div(20, 12, 13), load(15, 11), load(16, 11, 4), regadd(10, 15, 16)], 141,
         {0x1000: 42, 0x1004: 99})
    case('load_store', [div(20, 12, 13), load(15, 11), store(14, 11, 4), load(10, 11, 4)], 42,
         {0x1000: 99})
    # JAL +4 has the same next PC as a correct sequential prediction, but still
    # pushes x1/x5 return hints into the committed RAS.
    case('two_calls', [div(20, 12, 13), 0x004000ef, 0x004002ef, add(10, 0, 73)], 73)
    for padding in range(16):
        case(f'wrap_exit_{padding:02}', [div(20, 12, 13), add(10, 0, 67)], 67,
             prefix=[add(0, 0, 0)] * padding,
             trailing=[store(14, 31), add(10, 0, 999)])

    rows = []
    for name, words, expected, retired, data in tests:
        directory = args.out/name
        directory.mkdir(exist_ok=True)
        memory = {i << 2: word for i, word in enumerate(words)} | data
        image = directory/'program.data'
        image.write_text('\n'.join(f'@{addr:08x}\n' + ' '.join(f'{(word >> (b << 3)) & 255:02x}' for b in range(4))
                                   for addr, word in sorted(memory.items())) + '\n')
        a = course.simulate(args.main, directory, 120)
        b = course.simulate(args.template, directory, 120)
        assert a == b and (a[0], a[2]) == (expected, retired), (name, a, b, expected, retired)
        rtl = subprocess.run([str(args.rtl.resolve()), str(image), str(expected), str(retired)],
                             capture_output=True, text=True, timeout=120)
        (directory/'rtl.log').write_text(rtl.stdout + rtl.stderr)
        assert rtl.returncode == 0, (name, rtl.stdout, rtl.stderr)
        clocks = re.search(r'cycles=(\d+) core=(\d+).*dual=(\d+)', rtl.stdout)
        assert clocks and (int(clocks[1]), int(clocks[2])) == (a[1][3], a[1][1]), (name, a, rtl.stdout)
        rows.append(dict(case=name, timing=a[1], retired=retired, dual=int(clocks[3])))
        print(name, rtl.stdout.strip(), flush=True)
    assert sum(row['dual'] for row in rows) > 0, 'no real dual retirement exercised'
    (args.out/'report.json').write_text(json.dumps(dict(passed=True, rows=rows), indent=2) + '\n')


if __name__ == '__main__':
    main()
