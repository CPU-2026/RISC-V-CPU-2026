#!/usr/bin/env python3
"""Supplement dual-rename acceptance with naturally stalled JAL/JALR link RAW.

Use the assertion-enabled rename2 binary from check_rename_width.py. Only input
images and test logs are generated; no DUT state, memory answers or backpressure
are injected. The driver checks every retirement with its independent ISA.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from check_dual_commit import add, div, load, lui, store


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rtl', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    binary = args.rtl.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    before = sha(binary)
    rows = []
    def simulate(name, jump, kind, words, expected, data):
        memory = {4 * i: word for i, word in enumerate(words)} | data
        folder = args.out / name
        folder.mkdir(exist_ok=True)
        image = folder / 'program.data'
        image.write_text('\n'.join(f'@{address:08x}\n' + ' '.join(
            f'{(word >> (8 * byte)) & 255:02x}' for byte in range(4))
            for address, word in sorted(memory.items())) + '\n')
        result = subprocess.run([str(binary), str(image), str(expected), str(len(words) - 1)],
                                capture_output=True, text=True, timeout=30)
        (folder / 'rtl.log').write_text(result.stdout + result.stderr)
        counters = {key: int(value) for key, value in re.findall(r'(\w+)=(\d+)', result.stdout)}
        if result.returncode or not result.stdout.startswith('PASS ') or 'link_raw' not in counters:
            raise ValueError(f'{name}: independent ISA failed or missing rename counters: '
                             f'{result.stdout}{result.stderr}')
        rows.append(dict(case=name, jump=jump, consumer=kind, expected=expected,
                         image_sha256=sha(image), **counters))

    for jump in ('jal', 'jalr'):
        for kind in ('alu', 'store', 'load', 'div'):
            for padding in range(8):
                for pressure in range(1, 7):
                    # Older DIV keeps dependent Integer RS entries occupied;
                    # the jump and consumer accumulate naturally in the IQ.
                    words = [lui(31, 0x80000), lui(11, 1), lui(12, 0x70000), add(13, 0, 3), add(2, 0, 0)]
                    words += [add(0, 0, 0)] * padding + [div(20, 12, 13)]
                    words += [add(21 + i, 20, i) for i in range(pressure)]
                    pc = 4 * len(words)
                    words[4] = add(2, 0, pc + 4)
                    words += [0x004000ef if jump == 'jal' else 0x000100e7]
                    if kind == 'alu':
                        words += [add(10, 1, 0)]
                    elif kind == 'store':
                        words += [store(1, 11), load(10, 11)]
                    elif kind == 'load':
                        words += [load(10, 1, 0x600)]
                    else:
                        words += [div(10, 1, 13)]
                    expected = 123 if kind == 'load' else ((pc + 4) // 3 if kind == 'div' else pc + 4)
                    words += [store(10, 31), 0x6f]
                    name = f'{jump}-{kind}-p{padding}-q{pressure}'
                    simulate(name, jump, kind, words, expected,
                             {pc + 4 + 0x600: 123} if kind == 'load' else {})
    coverage = {jump: {kind: sum(row['link_raw'] for row in rows
                                if row['jump'] == jump and row['consumer'] == kind)
                       for kind in ('alu', 'store', 'load', 'div')}
                for jump in ('jal', 'jalr')}
    # Integer-pressure cases can only free one Integer row per cycle, so the
    # ALU consumer is an architectural control, not required pair coverage.
    # Load/DIV exercise source1 LINK RAW and Store exercises source2 LINK RAW.
    paired = ('store', 'load', 'div')
    passed = all(kinds[kind] > 0 for kinds in coverage.values() for kind in paired) and sha(binary) == before
    report = dict(passed=passed, rows=rows, link_raw=coverage, binary_sha256=before,
                  required_paired_consumers=paired,
                  scope='real CPU retirement ISA and observed link RAW; ALU pair coverage not required; not software timing equality')
    (args.out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    if not passed:
        raise ValueError(f'missing JAL/JALR consumer coverage or binary changed: {coverage}')
    print(f'PASS {len(rows)} natural JAL/JALR link-RAW programs: {coverage}')


if __name__ == '__main__':
    main()
