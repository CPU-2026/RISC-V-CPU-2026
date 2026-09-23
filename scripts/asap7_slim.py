#!/usr/bin/env python3
"""Project the pinned ASAP7 Liberty files down to what mapping actually needs.

Why this exists
---------------
The ABC build available here (Debian ``yosys`` 0.33 / ABC 1.01) cannot classify
ASAP7 cells: reading the pristine Liberty files makes ABC report

    Warnings: genlib library reader cannot detect the buffer gate.
    Warnings: genlib library reader cannot detect the invertor gate.
    Warnings: genlib library reader cannot detect the AND2, NAND2, OR2, and
              NOR2 gate.

so ABC's mapper has no buffer cell to fall back on and aborts with

    Error: Cannot find buffer gate in the library.
    Error: Abc_CommandAbc9Nf(): Mapping into LUTs has failed.

and never writes a mapped netlist.  ABC's gate classifier is tripped up by the
ASAP7 Liberty housekeeping - power/ground pins, leakage tables and the NLDM
delay tables - not by the cells themselves.  A cell with the same name, area
and ``function`` but no surrounding noise is classified correctly.

What this script does
---------------------
It emits a *projection* of each Liberty file that keeps everything relevant to
area and structure -- ``library``/``cell``/``pin``/``ff``/``latch`` blocks,
``area``, ``function``, pin ``direction`` and sequential state -- and drops the
blocks that ABC cannot digest: ``pg_pin``, ``leakage_power``, ``internal_power``
and every NLDM timing table.  Cell names, cell areas and boolean functions are
preserved byte for byte from the source, so ``stat -liberty`` on the projection
reports exactly the ASAP7 areas.

The projection is verified against the source: the set of cells and the total
area summarised from both files must be identical.  The four combinational
groups are also folded into one library for ABC; the SEQ group remains separate
for Yosys ``dfflibmap`` and area reporting.

Usage: scripts/asap7_slim.py [--check] [--out DIR] LIBS...
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

# Blocks dropped wholesale, at any nesting depth.
DROP_BLOCKS = {
    "timing", "internal_power", "leakage_power", "pg_pin", "power",
    "rise_power", "fall_power", "cell_rise", "cell_fall",
    "rise_transition", "fall_transition", "rise_constraint", "fall_constraint",
    "lut", "test_cell", "memory", "bundle", "bus", "statetable",
    "output_current_rise", "output_current_fall", "receiver_capacitance",
    "ocv_sigma_cell_rise", "ocv_sigma_cell_fall",
    "ocv_sigma_rise_transition", "ocv_sigma_fall_transition",
    "ocv_sigma_rise_constraint", "ocv_sigma_fall_constraint",
}

# Leaf attributes dropped by name prefix (power/related pin bookkeeping).
DROP_ATTR_PREFIX = ("related_", "power_down_", "driver_", "ocv_")

# Leaf attributes worth keeping verbatim; anything unrecognised inside a cell
# is dropped so that no unparsed construct leaks through.
KEEP_ATTR = {
    "area", "function", "direction", "capacitance", "max_capacitance",
    "min_capacitance", "max_transition", "clocked_on", "next_state", "preset",
    "clear", "three_state", "enable", "data_in", "dont_touch", "dont_use",
    "time_unit", "capacitive_load_unit", "voltage_unit", "current_unit",
    "pulling_resistance_unit", "leakage_power_unit", "nom_voltage",
    "nom_temperature", "nom_process", "default_operating_conditions",
    "default_cell_leakage_power", "default_fanout_load",
    "default_inout_pin_cap", "default_input_pin_cap", "default_output_pin_cap",
    "default_max_transition", "default_wire_load", "slew_lower_threshold_pct_rise",
    "slew_upper_threshold_pct_rise", "slew_lower_threshold_pct_fall",
    "slew_upper_threshold_pct_fall", "input_threshold_pct_rise",
    "input_threshold_pct_fall", "output_threshold_pct_rise",
    "output_threshold_pct_fall", "operating_conditions", "process",
    "temperature", "voltage", "tree_type", "scaling_factors",
    "in_place_swap_mode", "delay_model",
}

BLOCK_RE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*(\(([^)]*)\))?\s*\{")
# Liberty makes the trailing semicolon optional: ASAP7's INVBUF group writes
# "area : 0.20412" while the other groups write "area : 0.08748;".  Both forms
# must survive the projection, or the BUF/INV cells would come out with zero
# area in the mapped report.
ATTR_RE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*;?\s*$")
CELL_RE = re.compile(r"^\s*cell\s*\(([^)]+)\)")
AREA_RE = re.compile(r"^\s*area\s*:\s*([0-9.eE+-]+)\s*;?")
FUNCTION_RE = re.compile(r'^\s*function\s*:\s*(".*")\s*;?\s*$')
FF_RE = re.compile(r"^\s*ff\s*\(")


def project(text: str) -> str:
    out: list[str] = []
    # One "drop this subtree" flag per open brace.
    stack: list[bool] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("}"):
            if stack:
                was_dropping = stack.pop()
                if not was_dropping:
                    out.append("  " * len(stack) + "}")
            continue
        if stripped.endswith("{"):
            match = BLOCK_RE.match(line)
            if match is None:
                continue
            keyword = match.group(2)
            child_dropping = (stack[-1] if stack else False) or \
                             (keyword in DROP_BLOCKS)
            if not child_dropping:
                out.append("  " * len(stack) + stripped)
            stack.append(child_dropping)
            continue
        if stack and stack[-1]:
            continue
        match = ATTR_RE.match(line)
        if match is None:
            continue
        name = match.group(2)
        if name in KEEP_ATTR and not name.startswith(DROP_ATTR_PREFIX):
            out.append("  " * len(stack) + stripped)
    return "\n".join(out) + "\n"


def inventory(text: str) -> dict[str, float]:
    """Map cell name -> area, from any Liberty text."""
    cells: dict[str, float] = {}
    current: str | None = None
    for line in text.splitlines():
        match = CELL_RE.match(line)
        if match:
            current = match.group(1).strip()
            cells.setdefault(current, 0.0)
            continue
        area = AREA_RE.match(line)
        if area and current is not None:
            cells[current] = float(area.group(1))
            current = None
    return cells


def functions(text: str) -> list[str]:
    """Every boolean function string in the file, as a sorted multiset."""
    return sorted(m.group(1) for m in
                  (FUNCTION_RE.match(line) for line in text.splitlines())
                  if m is not None)


def flip_flop_count(text: str) -> int:
    return sum(1 for line in text.splitlines() if FF_RE.match(line))


COMB_LIB_NAME = "asap7sc7p5t_COMB_RVT_TT.lib"


def cell_blocks(text: str) -> dict[str, str]:
    """Cell name -> raw block text, for the normalised projection format."""
    blocks: dict[str, str] = {}
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        match = CELL_RE.match(lines[index])
        if match is None:
            index += 1
            continue
        name = match.group(1).strip()
        body = [lines[index]]
        index += 1
        depth = 1
        while index < len(lines) and depth:
            body.append(lines[index])
            if lines[index].strip().endswith("{"):
                depth += 1
            elif lines[index].strip().startswith("}"):
                depth -= 1
            index += 1
        blocks[name] = "\n".join(body)
    return blocks


def combine(sources: list[tuple[pathlib.Path, str]], name: str) -> str:
    """Fold several projected library groups into a single library.

    ABC refuses to use a library that exposes fewer than three gate classes,
    and ASAP7 keeps buffers and inverters alone in the INVBUF group -- two
    classes, so ABC discards it and its mapper is left without a buffer cell.
    It also mis-classifies ASAP7 cells once a second `read_lib` is issued, so
    the mapper must be given exactly one library.  Folding the groups keeps
    every cell name, function and area identical while giving ABC a single
    library it can actually use.
    """
    header: list[str] = []
    blocks: dict[str, str] = {}
    for path, text in sources:
        lines = text.splitlines()
        if not header:
            for line in lines:
                if CELL_RE.match(line):
                    break
                if line.strip().startswith("library ("):
                    header.append(f"library ({name}) {{")
                else:
                    header.append(line)
        for cell, body in cell_blocks(text).items():
            blocks.setdefault(cell, body)
    body = "\n\n".join(blocks[cell] for cell in sorted(blocks))
    return "\n".join(header) + "\n" + body + "\n}\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("libs", nargs="+", type=pathlib.Path)
    parser.add_argument("--out", type=pathlib.Path, default=None,
                        help="output directory (default: <lib dir>/slim)")
    parser.add_argument("--check", action="store_true",
                        help="only verify that existing projections match the sources")
    args = parser.parse_args()

    status = 0
    projected: list[pathlib.Path] = []
    for src in args.libs:
        if not src.is_file():
            print(f"asap7_slim: missing {src}", file=sys.stderr)
            return 2
        out_dir = args.out if args.out is not None else src.parent / "slim"
        dst = out_dir / src.name
        original = src.read_text(encoding="utf-8", errors="replace")

        if args.check:
            if not dst.is_file():
                print(f"asap7_slim: {dst} is missing", file=sys.stderr)
                status = 1
                continue
            slim = dst.read_text(encoding="utf-8", errors="replace")
        else:
            out_dir.mkdir(parents=True, exist_ok=True)
            slim = project(original)
            dst.write_text(slim, encoding="utf-8")

        before = inventory(original)
        after = inventory(slim)
        same_cells = set(before) == set(after)
        same_area = abs(sum(before.values()) - sum(after.values())) < 1e-9
        kept = sum(1 for name in after if abs(before.get(name, -1) - after[name]) < 1e-12)
        same_funcs = functions(original) == functions(slim)
        same_ffs = flip_flop_count(original) == flip_flop_count(slim)
        if not (same_cells and same_area and kept == len(before) and same_funcs
                and same_ffs):
            print(f"asap7_slim: PROJECTION MISMATCH for {src.name}: "
                  f"cells {len(before)}->{len(after)}, "
                  f"area {sum(before.values()):.6f}->{sum(after.values()):.6f}, "
                  f"identical areas {kept}/{len(before)}, "
                  f"functions {'ok' if same_funcs else 'DIFFER'}, "
                  f"ff {'ok' if same_ffs else 'DIFFER'}", file=sys.stderr)
            status = 1
            continue
        ratio = len(slim) / max(len(original), 1)
        print(f"asap7_slim: {dst} cells={len(after)} "
              f"sum_area={sum(after.values()):.6f} um^2 "
              f"functions={len(functions(slim))} "
              f"bytes={len(slim)} ({ratio:.1%} of source)")
        projected.append(dst)

    if status or args.check:
        return status

    # ABC sees only combinational cones. Keep the sequential cells out of its
    # library; Yosys preserves them as boundaries after dfflibmap.
    out_dir = projected[0].parent
    comb_path = out_dir / COMB_LIB_NAME
    sources = [(path, path.read_text(encoding="utf-8"))
               for path in projected if "SEQ" not in path.name]
    comb_text = combine(sources, COMB_LIB_NAME[:-4])
    comb_path.write_text(comb_text, encoding="utf-8")

    got_cells = inventory(comb_text)
    expect_cells: dict[str, float] = {}
    for _, text in sources:
        for cell, area in inventory(text).items():
            expect_cells.setdefault(cell, area)
    if set(expect_cells) != set(got_cells):
        print(f"asap7_slim: COMBINATIONAL LIBRARY MISMATCH: cells "
              f"{len(expect_cells)}->{len(got_cells)}", file=sys.stderr)
        return 1
    for path, text in sources:
        for cell, area in inventory(text).items():
            if abs(got_cells[cell] - area) > 1e-9:
                print(f"asap7_slim: COMBINATIONAL LIBRARY area drift for {cell}: "
                      f"{area} -> {got_cells[cell]}", file=sys.stderr)
                return 1
    if flip_flop_count(comb_text) != 0:
        print("asap7_slim: COMBINATIONAL LIBRARY contains state elements",
              file=sys.stderr)
        return 1
    print(f"asap7_slim: {comb_path} cells={len(got_cells)} "
          f"(from {len(sources)} groups: "
          f"{', '.join(path.name for path, _ in sources)})")
    return status


if __name__ == "__main__":
    sys.exit(main())
