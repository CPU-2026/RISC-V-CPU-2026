#!/usr/bin/env python3
"""Resolve mapped critical-path pins back to retained RTL net names."""
import argparse
from bisect import bisect_right
from collections import defaultdict
import json
from pathlib import Path
import re

from synth import quote, run_yosys
from toolchain import DEFAULT_APPIMAGE, enter_appimage, executable, packaged_tool


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="assessment opt/ report directory")
    args = parser.parse_args()
    enter_appimage(str(DEFAULT_APPIMAGE))
    args.directory = args.directory.resolve()
    report = json.loads((args.directory / "report.json").read_text())
    original = json.loads((args.directory / "design.json").read_text())
    manifest = json.loads((args.directory.parent / "assessment-opt.json").read_text())
    converted_file = args.directory.parent / "converted.v"
    module_files = {}
    for source in manifest["inputs"]:
        for module_name in re.findall(r"\bmodule\s+(\w+)", Path(source["path"]).read_text()):
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

    path = report["timing"]["critical_paths"][0]
    lines = [f"Worst path: {path['startpoint']} -> {path['endpoint']}",
             f"Slack: {path['slack_ns']:.6f} ns", ""]
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
        lines.append(f"{pin} ({cell['type']}), arrival {point['arrival_ns']:.6f} ns")
        if cell_name in origins:
            attributes = old_cells[origins[cell_name]].get("attributes", {})
            if attributes.get("hdlname"):
                lines.append(f"  original hierarchy: {attributes['hdlname']}")
            if attributes.get("src"):
                module = source_module(old_cells[origins[cell_name]])
                location = attributes["src"].split("converted.v:", 1)[-1]
                lines.append(f"  converted RTL: {converted_file}:{location}")
                lines.append(f"  source module: {module}")
                if module in module_files:
                    lines.append(f"  RTL file: {module_files[module]}")
        for bit in bits:
            lines.append(f"  fanout={len(sinks[bit])}; RTL aliases: {', '.join(names(bit)) or '(internal mapping net)'}")
        if cell_name in (path["startpoint"].rsplit("/", 1)[0], path["endpoint"].rsplit("/", 1)[0]):
            for bit in cell["connections"].get("QN", []):
                lines.append(f"  register QN aliases: {', '.join(names(bit))}")
            for bit in cell["connections"].get("D", []):
                lines.append(f"  register D aliases: {', '.join(names(bit))}")
    text = "\n".join(lines) + "\n"
    (args.directory / "rtl-critical-path.txt").write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
