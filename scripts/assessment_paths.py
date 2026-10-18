#!/usr/bin/env python3
"""Resolve mapped critical-path pins back to retained RTL net names."""
import argparse
from bisect import bisect_right
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re

from synth import quote, run_yosys
from toolchain import DEFAULT_APPIMAGE, enter_appimage, executable, packaged_tool


def generic_register_states(path, targets):
    """Recover named state from pre-ABC checkpoints without loading another
    large design. Final clean -purge can remove every public RTL wire name.
    Cell identity AND source location must survive before we use this bridge.
    """
    if not targets or not path.is_file():
        return {}
    cells, aliases = {}, defaultdict(list)
    active = False
    section = None
    captured = None
    lines = []
    with path.open() as stream:
        for line in stream:
            if not active:
                if line.startswith('    "student_top": {'):
                    active = True
                continue
            if line.startswith('    }'):
                break
            if line.startswith('      "cells": {'):
                section = 'cells'
            elif line.startswith('      "netnames": {'):
                section = 'netnames'
            if line.startswith('        "'):
                captured = None
                if section == 'cells':
                    captured = next((name for name in targets if line.startswith('        ' + json.dumps(name) + ': {')), None)
                elif section == 'netnames' and '$' not in line:
                    captured = 'net'
                lines = [line] if captured is not None else []
            elif captured is not None:
                lines.append(line)
            if captured is not None and line.startswith('        }'):
                item = json.loads('{' + ''.join(lines).rstrip().rstrip(',') + '}')
                name, value = next(iter(item.items()))
                if section == 'cells':
                    cells[name] = value
                else:
                    wanted = {bit for cell in cells.values() for bit in cell['connections'].get('Q', [])}
                    for index, bit in enumerate(value['bits']):
                        if bit in wanted:
                            label = name if len(value['bits']) == 1 else f"{name}[{index + value.get('offset', 0)}]"
                            aliases[bit].append(dict(name=label, src=value.get('attributes', {}).get('src')))
                captured = None
    result = {}
    for name, mapped in targets.items():
        generic = cells.get(name)
        if generic and generic['type'].startswith(('$_DFF', '$_SDFF')) and generic['attributes'].get('src') == mapped['attributes'].get('src'):
            result[name] = dict(generic_cell=name, generic_type=generic['type'],
                                logical_q=[aliases[bit] for bit in generic['connections'].get('Q', [])])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="assessment opt/ report directory")
    paths = parser.add_mutually_exclusive_group()
    paths.add_argument("--all-paths", action="store_true", help="resolve every reported setup path in one netlist load")
    paths.add_argument("--path-index", type=int, default=0, help="reported setup-path index (default: 0)")
    args = parser.parse_args()
    enter_appimage(str(DEFAULT_APPIMAGE))
    args.directory = args.directory.resolve()
    report = json.loads((args.directory / "report.json").read_text())
    original = json.loads((args.directory / "design.json").read_text())
    manifest_file = args.directory.parent / "assessment-opt.json"
    if manifest_file.is_file():
        manifest = json.loads(manifest_file.read_text())
        converted_file = args.directory.parent / "converted.v"
    else:
        # Ordinary course synth.py uses the real AXI student_top and stores
        # its conversion below opt/frontend, not the standalone assess layout.
        manifest = report
        converted_file = args.directory / "frontend/converted.v"
    expected_conversion = report.get("frontend", {}).get("converted_sha256")
    if expected_conversion and hashlib.sha256(converted_file.read_bytes()).hexdigest() != expected_conversion:
        raise ValueError("converted RTL does not match the synthesis report")
    module_files = {}
    for source in manifest["inputs"]:
        source_path = Path(source["path"])
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != source["sha256"]:
            raise ValueError(f"RTL changed since synthesis: {source_path}")
        for module_name in re.findall(r"\bmodule\s+(\w+)", source_path.read_text()):
            module_files[module_name] = source["path"]
    # write_verilog auto-renames hidden cells after design.json is emitted.
    # Re-read the actual STA netlist with its library modules to align names.
    libraries = args.directory / "resolve-libraries.json"
    libraries.write_text(json.dumps({"modules": {
        name: module for name, module in original["modules"].items()
        if module.get("attributes", {}).get("blackbox", "0").endswith("1")}}))
    mapped = args.directory / "mapped-design.json"
    commands = [
        "read_json " + quote(libraries),
        "read_verilog " + quote(args.directory / "mapped.v"),
        "hierarchy -check -top student_top",
        "write_json " + quote(mapped),
    ]
    yosys = packaged_tool("yosys") or executable("yosys")
    run_yosys(yosys, args.directory, "resolve", commands)
    design = json.loads(mapped.read_text())["modules"]["student_top"]
    old_cells = original["modules"]["student_top"]["cells"]
    converted = converted_file.read_text().splitlines()
    module_lines, module_names = [], []
    for number, line in enumerate(converted, 1):
        match = re.match(r"module (\w+)", line)
        if match:
            module_lines.append(number)
            module_names.append(match[1])

    def source_module(cell):
        match = re.search(r"converted\.v:(\d+)", cell.get("attributes", {}).get("src", ""))
        if match:
            index = bisect_right(module_lines, int(match[1])) - 1
            if index >= 0:
                return module_names[index]
        return "unattributed"

    register_area = defaultdict(lambda: {"cells": 0, "area_um2": 0.0})
    for cell in old_cells.values():
        if cell["type"].startswith("DFF"):
            entry = register_area[source_module(cell)]
            entry["cells"] += 1
            entry["area_um2"] += float(original["modules"][cell["type"]]["attributes"]["area"])
    (args.directory / "register-area-by-module.json").write_text(
        json.dumps(dict(sorted(register_area.items(), key=lambda item: -item[1]["area_um2"])), indent=2) + "\n")
    hidden = sorted(name for name in old_cells if name.startswith("$"))
    renamed = sorted((name for name in design["cells"] if re.fullmatch(r"_\d+_", name)),
                     key=lambda name: int(name[1:-1]))
    origins = {}
    if len(hidden) == len(renamed) and all(old_cells[old]["type"] == design["cells"][new]["type"]
                                           for old, new in zip(hidden, renamed)):
        origins = dict(zip(renamed, hidden))
    endpoint_names = {path[key].rsplit('/', 1)[0] for path in report['timing']['critical_paths']
                      for key in ('startpoint', 'endpoint')}
    generic_states = generic_register_states(args.directory/'generic.json',
        {origins[name]: old_cells[origins[name]] for name in endpoint_names if name in origins})
    aliases, sinks = defaultdict(list), defaultdict(list)
    inverters = defaultdict(list)
    for name, net in design["netnames"].items():
        if "$" in name or name.startswith("_"):
            continue
        for index, bit in enumerate(net["bits"]):
            if isinstance(bit, int):
                label = name if len(net["bits"]) == 1 else f"{name}[{index + net.get('offset', 0)}]"
                aliases[bit].append(label)
    for name, cell in design["cells"].items():
        for port, bits in cell["connections"].items():
            if cell["port_directions"].get(port) == "input":
                for bit in bits:
                    sinks[bit].append(f"{name}/{port}")
        if cell["type"].startswith("INV"):
            inverters[cell["connections"]["A"][0]].extend(cell["connections"]["Y"])

    def names(bit):
        result = list(aliases[bit])
        for inverted in inverters[bit]:
            result += ["~" + name for name in aliases[inverted]]
        return sorted(set(result), key=lambda name: (name.count("$"), len(name), name))[:8]

    reported = report["timing"]["critical_paths"]
    indices = list(range(len(reported))) if args.all_paths else [args.path_index]
    if any(index < 0 or index >= len(reported) for index in indices):
        raise ValueError(f"path index must be between 0 and {len(reported)-1}")
    resolved = []
    for index in indices:
        path = reported[index]
        lines = [f"Path {index}: {path['startpoint']} -> {path['endpoint']}",
                 f"Slack: {path['slack_ns']:.6f} ns", ""]
        records = []
        seen = set()
        for point in path["points"]:
            pin = point["pin"]
            if pin in seen or "/" not in pin:
                continue
            seen.add(pin)
            cell_name, port = pin.rsplit("/", 1)
            cell = design["cells"].get(cell_name)
            if cell is None:
                continue
            bits = cell["connections"][port]
            record = dict(pin=pin, cell=cell['type'], arrival_ns=point['arrival_ns'],
                          signals=[dict(bit=bit, fanout=len(sinks[bit]), aliases=names(bit)) for bit in bits])
            lines.append(f"{pin} ({cell['type']}), arrival {point['arrival_ns']:.6f} ns")
            if cell_name in origins:
                record['original_cell'] = origins[cell_name]
                attributes = old_cells[origins[cell_name]].get("attributes", {})
                if attributes.get("hdlname"):
                    record['original_hierarchy'] = attributes['hdlname']
                    lines.append(f"  original hierarchy: {attributes['hdlname']}")
                if attributes.get("src"):
                    module = source_module(old_cells[origins[cell_name]])
                    location = attributes["src"].split("converted.v:", 1)[-1]
                    record.update(source_module=module, converted_location=location, rtl_file=module_files.get(module))
                    lines.append(f"  converted RTL: {converted_file}:{location}")
                    lines.append(f"  source module: {module}")
                    if module in module_files:
                        lines.append(f"  RTL file: {module_files[module]}")
            for bit in bits:
                lines.append(f"  fanout={len(sinks[bit])}; RTL aliases: {', '.join(names(bit)) or '(internal mapping net)'}")
            if cell_name in (path["startpoint"].rsplit("/", 1)[0], path["endpoint"].rsplit("/", 1)[0]):
                state = generic_states.get(origins.get(cell_name))
                if state:
                    record['register_state'] = state
                    for labels in state['logical_q']:
                        lines.append('  checkpoint logical register: ' + ', '.join(item['name'] for item in labels))
                record['register_outputs'] = {port: [names(bit) for bit in cell['connections'][port]]
                                              for port in ('Q', 'QN') if port in cell['connections']}
                record['register_data'] = [names(bit) for bit in cell['connections'].get('D', [])]
                for port, signals in record['register_outputs'].items():
                    for labels in signals:
                        lines.append(f"  register {port} aliases: {', '.join(labels)}")
                for labels in record['register_data']:
                    lines.append(f"  register D aliases: {', '.join(labels)}")
            records.append(record)
        text = "\n".join(lines) + "\n"
        filename = "rtl-critical-path.txt" if index == 0 else f"rtl-critical-path-{index}.txt"
        (args.directory / filename).write_text(text)
        resolved.append(dict(index=index, startpoint=path['startpoint'], endpoint=path['endpoint'],
                             slack_ns=path['slack_ns'], points=records))
        print(text, end="")
    result = dict(source_report_sha256=hashlib.sha256((args.directory/'report.json').read_bytes()).hexdigest(),
                  converted_sha256=hashlib.sha256(converted_file.read_bytes()).hexdigest(),
                  origin_mapping_verified=bool(origins), mapped_origins=len(origins), paths=resolved)
    (args.directory/'rtl-critical-paths.json').write_text(json.dumps(result, indent=2)+'\n')


if __name__ == "__main__":
    main()
