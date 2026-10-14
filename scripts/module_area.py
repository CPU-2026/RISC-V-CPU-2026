#!/usr/bin/env python3
"""Export non-overlapping RTL-module area from a hierarchy-preserved synthesis."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

KEYS = ('combinational_area_um2', 'sequential_area_um2', 'sram_area_um2', 'area_um2')


def summarize(report):
    if report['mode'] != 'diagnose':
        raise ValueError('module accounting requires diagnose; flattened opt has no unique RTL ownership')
    groups, hierarchy, seen = {}, [], set()

    def visit(node, owner=None):
        path = node['instance']
        if path in seen:
            raise ValueError(f'duplicate instance: {path}')
        seen.add(path)
        source = node.get('source_module', node['module'])
        wrapper = node['module'].startswith('sram_fakeram_')
        if not wrapper:
            owner = source
            groups.setdefault(owner, dict(source_module=owner, instances=0,
                                          **{k: 0.0 for k in KEYS}))['instances'] += 1
        if owner is None:
            raise ValueError(f'SRAM wrapper has no RTL owner: {path}')
        # Wrapper mask/enable gates AND SRAM leaf macros belong to the enclosing
        # RTL module. Descendant RTL modules otherwise keep their own area.
        for key in KEYS:
            value = float(node['direct'][key])
            if not math.isfinite(value) or value < 0:
                raise ValueError(f'invalid {key} at {path}')
            groups[owner][key] += value
        hierarchy.append(dict(instance=path, source_module=source,
                              direct_area_um2=node['direct']['area_um2'],
                              inclusive_area_um2=node['area_um2']))
        for child in node['children']:
            visit(child, owner)

    visit(report['area']['module_tree'])
    for key in KEYS:
        total = sum(row[key] for row in groups.values())
        if not math.isclose(total, report['area'][key], rel_tol=1e-9, abs_tol=1e-5):
            raise ValueError(f'leaf accounting mismatch for {key}: {total} != {report["area"][key]}')
    total = report['area']['area_um2']
    for row in groups.values():
        if not math.isclose(row['area_um2'], sum(row[k] for k in KEYS[:-1]), abs_tol=1e-5):
            raise ValueError(f'component accounting mismatch for {row["source_module"]}')
        row['percent_of_total'] = 100 * row['area_um2'] / total if total else 0.0
    return sorted(groups.values(), key=lambda row: (-row['area_um2'], row['source_module'])), hierarchy


def identities(items):
    return sorted((Path(item['path']).name, item['sha256']) for item in items)


def functional_blocks(report):
    """Cut CPU containers into disjoint blocks; retain internal adders/FIFOs."""
    rows = []
    containers = {'student_top', 'rv32_core', 'rv32_predictor', 'rv32_dmem_backend'}

    def visit(node):
        source = node.get('source_module', node['module'])
        container = source in containers
        area = node['direct'] if container else node
        if area['area_um2']:
            rows.append(dict(instance=node['instance'], source_module=source,
                             includes_children=not container, **{k: area[k] for k in KEYS}))
        if container:
            for child in node['children']:
                visit(child)

    visit(report['area']['module_tree'])
    for key in KEYS:
        if not math.isclose(sum(row[key] for row in rows), report['area'][key], abs_tol=1e-5):
            raise ValueError(f'functional-block accounting mismatch for {key}')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path, help='diagnose/report.json')
    parser.add_argument('--flat-report', type=Path, help='optional matching opt/report.json for total comparison')
    parser.add_argument('--out', type=Path, help='output directory; defaults to report directory')
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    rows, hierarchy = summarize(report)
    flat = None
    if args.flat_report:
        flat = json.loads(args.flat_report.read_text())
        if flat['mode'] != 'opt' or flat['tools'] != report['tools'] or any(
                identities(flat[k]) != identities(report[k]) for k in ('inputs', 'libraries')):
            raise ValueError('opt and diagnose do not have matching source/library/tool identities')
        if flat['timing']['clock_period_ns'] != report['timing']['clock_period_ns']:
            raise ValueError('opt and diagnose clock constraints differ')
    out = args.out or args.report.parent
    out.mkdir(parents=True, exist_ok=True)
    blocks = functional_blocks(report)
    for filename, data in [('module-area-direct.csv', rows), ('module-area-hierarchy.csv', hierarchy),
                           ('functional-blocks.csv', blocks)]:
        with (out / filename).open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=list(data[0]))
            writer.writeheader()
            writer.writerows(data)
    note = ('Each mapped cell counted once. Rows sum across parameter variants/instances; '
            'RTL descendants are separate rows, SRAM wrapper gates/macros belong to their RTL owner. '
            'This is the diagnose netlist, not an allocation of the flattened opt total.')
    result = dict(mode='diagnose', accounting=note, source_report=str(args.report.resolve()),
                  source_report_sha256=hashlib.sha256(args.report.read_bytes()).hexdigest(),
                  totals={k: report['area'][k] for k in KEYS}, modules=rows,
                  sram_leaf_instances=len(report['area']['sram_instances']))
    if flat:
        result['flattened_comparison'] = dict(report=str(args.flat_report.resolve()),
                                              totals={k: flat['area'][k] for k in KEYS})
    (out / 'module-area.json').write_text(json.dumps(result, indent=2) + '\n')
    lines = ['# 综合模块面积', '', '**单位：μm²。保留层次映射综合，各行不包含其他RTL子模块；**',
             '重复实例按RTL模块类型合计；SRAM宏及其接口门归入所属Cache。各行可相加，不重复计数。',
             '显示值保留三位小数；求和校验使用未舍入值。功能块含内部加法器/FIFO的分组见functional-blocks.csv。', '',
             '| RTL模块 | 实例数 | 组合 | 时序 | SRAM | 合计 | 占比 |',
             '|---|---:|---:|---:|---:|---:|---:|']
    for row in rows:
        lines.append(f"| {row['source_module']} | {row['instances']} | " +
                     ' | '.join(f'{row[k]:,.3f}' for k in KEYS) +
                     f" | {row['percent_of_total']:.2f}% |")
    lines += ['| **总计** | — | ' + ' | '.join(f'{report["area"][k]:,.3f}' for k in KEYS) + ' | 100% |', '']
    if flat:
        lines += [f'相同源码/库/工具/目标下展平opt总面积：**{flat["area"]["area_um2"]:,.3f} μm²**。',
                  '展平会进行跨模块优化，不能把上述分组比例缩放后冒称为opt的实际模块面积。', '']
    lines += [f'源报告：`{args.report.resolve()}`', '', note]
    text = '\n'.join(lines) + '\n'
    (out / 'module-area.md').write_text(text)
    print(text)


if __name__ == '__main__':
    main()
