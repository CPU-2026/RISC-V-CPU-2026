#!/usr/bin/env python3
"""Report optimized or hierarchical ASIC area and frequency with Yosys/OpenSTA."""
import argparse
from contextlib import nullcontext
import hashlib
import json
import math
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

from build import read_sources
from fakeram import MODEL, RAM_SOURCE, prepare_memories
from toolchain import DEFAULT_APPIMAGE, enter_appimage, executable, packaged_tool
from synth_report import area_report, format_report
from synth_profile import WallClockProfile
from sv_frontend import convert_sources, select_frontend
from timing import analyze


def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


def run_yosys(yosys, out, name, commands, profile=None):
    script = out / f"{name}.ys"
    # Keep Unicode workspace prefixes out of RTLIL identifiers/source attrs.
    # Relative paths let checkpoints stay in the durable project build folder.
    def relative_path(match):
        value = json.loads(match[0])
        return quote(os.path.relpath(value, out)) if os.path.isabs(value) and not value.isascii() else match[0]
    commands = [re.sub(r'"(?:[^"\\]|\\.)*"', relative_path, command) for command in commands]
    script.write_text("\n".join(commands) + "\n")
    command = [str(yosys), "-Q", "-q", "-t", "-d", "-l", str(out / f"{name}.log"),
               "-s", script.name]
    measurement = (profile.measure(f"yosys.{name}", command=command,
                                  script=str(script), log=str(out / f"{name}.log"))
                   if profile is not None else nullcontext({}))
    with measurement as record:
        result = subprocess.run(command, cwd=out, check=True)
        record["returncode"] = result.returncode


def stat_width(out, name):
    """Read-only statistics at an existing boundary; never split synth passes."""
    directory = out / "stats"
    directory.mkdir(exist_ok=True)
    # tee does not unquote filenames in some Yosys versions. The runner's cwd
    # is out, so fixed ASCII relative names also avoid spaces/Unicode prefixes.
    return f"tee -o stats/{name}.rpt stat -width"


def read_netlist(path, profile, name):
    with profile.measure(name, path=str(path)) as record:
        record["bytes"] = path.stat().st_size
        return json.loads(path.read_text())


def read_yosys_statistics(raw_path, clean_path, profile):
    """Normalize only stat -json's complete per-line -t prefixes; keep raw.

    This is not a netlist reader and never skips diagnostics/trailing garbage.
    Plain JSON and all-lines-timestamped Yosys statistics are both accepted.
    """
    if raw_path.resolve() == clean_path.resolve():
        raise ValueError("raw Yosys statistics must be preserved at a distinct path")
    with profile.measure("python.read_area_stat_json", path=str(raw_path)) as record:
        text = raw_path.read_text()
        record["bytes"] = raw_path.stat().st_size
        count = 0
        try:
            statistics = json.loads(text)
        except json.JSONDecodeError:
            lines = text.splitlines(keepends=True)
            prefix = re.compile(r"^\[\d+\.\d+\] ")
            if not lines or any(line.strip() and not prefix.match(line) for line in lines):
                raise
            count = sum(bool(prefix.match(line)) for line in lines)
            text = "".join(prefix.sub("", line, count=1) for line in lines)
            statistics = json.loads(text)
        if not isinstance(statistics, dict):
            raise ValueError("Yosys statistics must be a JSON object")
        record["timestamped_lines_removed"] = count
    with profile.measure("python.write_clean_area_stat_json", path=str(clean_path)):
        temporary = clean_path.with_name(clean_path.name + ".tmp")
        temporary.write_text(text)
        temporary.replace(clean_path)
    return statistics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--filelist", type=Path, default=Path("verilog/filelist.f"))
    parser.add_argument("--out", type=Path, default=Path("build/synth"),
                        help="output root; results go in its opt/ or diagnose/ subdirectory")
    parser.add_argument("--mode", choices=("opt", "diagnose"), default="opt")
    parser.add_argument("--no-hieropt", action="store_true",
                        help="preserve hierarchy without opt_hier (workaround for port-removal bugs)")
    parser.add_argument("--elaborated-json", type=Path,
                        help="reuse an existing RTL elaboration snapshot")
    parser.add_argument("--pre-abc-json", type=Path,
                        help="resume mapping from an existing pre-ABC snapshot")
    parser.add_argument("--checkpoints", action="store_true",
                        help="save the generic synthesis JSON snapshot")
    parser.add_argument("--clock-period", type=float, default=2.0, help="target clock period in ns (default: 2)")
    parser.add_argument("--clock-port", default="clock", help="top-level clock input (default: clock)")
    parser.add_argument("--abc-driving-cell", default="INVx1_ASAP7_75t_R",
                        help="ABC input driving cell (default: INVx1_ASAP7_75t_R)")
    parser.add_argument("--abc-load-ff", type=float, default=5.0,
                        help="ABC output load in fF (default: 5); OpenSTA loads stay fixed")
    parser.add_argument("--blackboxes", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--appimage", default=str(DEFAULT_APPIMAGE))
    parser.add_argument("--yosys", help="custom Yosys executable")
    parser.add_argument("--frontend", choices=("auto", "yosys", "sv2v"), default="auto",
                        help="SV frontend: auto prefers sv2v for .sv input; yosys uses its limited native parser")
    parser.add_argument("--sv2v", help="custom sv2v executable (also selects sv2v in auto mode)")
    parser.add_argument("--abc", help="custom ABC executable")
    parser.add_argument("--sta", help="custom OpenSTA executable")
    parser.add_argument("--asap7-lib", type=Path, help="directory containing the five ASAP7 libraries")
    args = parser.parse_args()
    out = args.out.resolve() / args.mode
    out.mkdir(parents=True, exist_ok=True)
    for name in ("area.json", "report.json", "report.txt", "timing.json", "timing_values.json",
                 "critical_paths.json", "timing.rpt", "timing_checks.rpt", "clock_checks.rpt", "constraints.sdc"):
        (out / name).unlink(missing_ok=True)
    if not math.isfinite(args.clock_period) or args.clock_period <= 0:
        parser.error("--clock-period must be a finite positive number in ns")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", args.abc_driving_cell):
        parser.error("--abc-driving-cell must be a cell name containing letters, digits or underscores")
    if not math.isfinite(args.abc_load_ff) or args.abc_load_ff < 0:
        parser.error("--abc-load-ff must be a finite nonnegative number in fF")
    (out / "blackboxes.v").unlink(missing_ok=True)
    if args.blackboxes:
        parser.error("--blackboxes has been removed; instantiate sram_fakeram for library-backed SRAM")
    legacy = args.filelist.resolve().parent / "blackboxes.txt"
    if legacy.is_file() and any(line.split("#", 1)[0].strip() for line in legacy.read_text().splitlines()):
        parser.error(f"{legacy}: zero-area blackbox exclusions are no longer supported; "
                     "migrate SRAMs to sram_fakeram and remove this list")
    try:
        sources = read_sources(args.filelist)
        if not (args.yosys and args.asap7_lib and args.sta):
            enter_appimage(args.appimage)
        yosys = executable(args.yosys) if args.yosys else (packaged_tool("yosys") or executable("yosys"))
        abc = executable(args.abc) if args.abc else packaged_tool("yosys-abc")
        if not abc and os.environ.get("CPU2026_ABC"):
            abc = executable(os.environ["CPU2026_ABC"])
        try:
            sta = executable(args.sta) if args.sta else (packaged_tool("sta") or executable("sta"))
        except ValueError as error:
            raise ValueError("OpenSTA is required for synthesis: configure STA=/path/to/sta "
                             "or use a course AppImage containing OpenSTA") from error
    except (ValueError, OSError) as error:
        parser.error(str(error))
    library_dir = args.asap7_lib or Path(os.environ.get("CPU2026_ASAP7_LIB", "/opt/asap7/lib"))
    libs = sorted(library_dir.expanduser().resolve().glob("*.lib"))
    if len(libs) != 5:
        parser.error("five ASAP7 RVT TT libraries required; configure APPIMAGE or ASAP7_LIB")
    # Start after AppImage re-entry so the outer launcher cannot overwrite the
    # actual tool process's records. PPA report schemas remain unchanged.
    profile = WallClockProfile(out)
    # Read the empty SRAM interface first and defer RTLIL generation until
    # hierarchy knows the actual instance parameters. Preserve -noblackbox so
    # RAM specializations still reach prepare_memories as normal empty modules.
    # No RAM array is lowered to flops in this stage.
    frontend = {"name": "elaboration_snapshot"}
    if args.elaborated_json:
        previous = args.elaborated_json.resolve()
        if previous != out / "elaborated.json":
            with profile.measure("python.copy_elaboration_snapshot", path=str(previous)):
                shutil.copyfile(previous, out / "elaborated.json")
    else:
        try:
            selected, sv2v = select_frontend(args.frontend, sources, args.sv2v)
            frontend = {"name": selected}
            if selected == "sv2v":
                with profile.measure("frontend.sv2v"):
                    converted, frontend = convert_sources(sv2v, [path for path in sources if path != RAM_SOURCE],
                                                           out / "frontend")
                reads = ["read_verilog -sv -defer -D SYNTHESIS " + quote(converted)]
            else:
                reads = ["read_verilog -sv -defer -D SYNTHESIS " + quote(path) for path in sources if path != RAM_SOURCE]
        except (ValueError, OSError) as error:
            parser.error(str(error))
        print(f"[synth] Frontend: {selected}", flush=True)
        try:
            run_yosys(yosys, out, "elaborate", [
                "read_verilog -sv -defer -noblackbox -D SYNTHESIS " + quote(RAM_SOURCE),
                *reads,
                "hierarchy -top student_top",
                stat_width(out, "elaborate-after-hierarchy"),
                "proc",
                stat_width(out, "elaborate-after-proc"),
                "memory_collect",
                stat_width(out, "elaborate-after-memory-collect"),
                "write_json " + quote(out / "elaborated.json"),
            ], profile=profile)
        except subprocess.CalledProcessError:
            if selected == "yosys" and any(path.suffix == ".sv" for path in sources):
                print("[synth] Native Yosys has limited SystemVerilog support. For packages/struct arrays, "
                      "install sv2v and use --frontend sv2v [--sv2v /path/to/sv2v].", file=sys.stderr)
            raise
    try:
        elaborated = read_netlist(out / "elaborated.json", profile, "python.read_elaborated_json")
        clock = elaborated["modules"]["student_top"].get("ports", {}).get(args.clock_port, {})
        if clock.get("direction") != "input" or len(clock.get("bits", [])) != 1:
            raise ValueError(f"student_top must have a one-bit clock input named {args.clock_port}")
        with profile.measure("python.prepare_memories"):
            prepared, wrappers, ram_libs, macros = prepare_memories(elaborated, out / "ram", profile=profile)
    except ValueError as error:
        parser.error(str(error))
    library_args = " ".join("-liberty " + quote(lib) for lib in libs)
    all_library_args = " ".join("-liberty " + quote(lib) for lib in [*libs, *ram_libs])
    library_reads = ["read_liberty -lib -ignore_miss_func " + quote(lib) for lib in [*libs, *ram_libs]]
    seq = next(lib for lib in libs if "_SEQ_" in lib.name)
    # Supplying constraints enables ABC's buffering and cell sizing passes.
    abc_constraints = out / "abc.constr"
    abc_constraints.write_text(f"set_driving_cell {args.abc_driving_cell}\nset_load {args.abc_load_ff:.12g}\n")
    script = [
        "read_json " + quote(prepared),
        "read_verilog " + quote(wrappers),
        *library_reads,
        "hierarchy -check -top student_top",
        stat_width(out, "synth-before-noabc"),
        "synth -top student_top -noabc " +
        ("-flatten" if args.mode == "opt" else ("" if args.no_hieropt else "-hieropt")),
        stat_width(out, "synth-after-noabc"),
        "check -assert",
        "select -assert-none a:init t:$dlatch* t:$_DLATCH*",
        *(["write_json " + quote(out / "generic.json")] if args.checkpoints else []),
        "dfflibmap -liberty " + quote(seq),
        stat_width(out, "synth-before-abc"),
        "abc " + ("-exe " + quote(abc) + " " if abc else "") + library_args
        + " -constr " + quote(abc_constraints) + f" -D {args.clock_period * 1000:.9g}",
        stat_width(out, "synth-after-abc"),
        "clean",
        "delete t:$scopeinfo",
        "clean -purge",
        "hilomap -hicell TIEHIx1_ASAP7_75t_R H -locell TIELOx1_ASAP7_75t_R L",
        "check -assert -mapped",
        stat_width(out, "synth-mapped-clean"),
        f"tee -o stat.raw.json stat -json {all_library_args}",
        "write_json " + quote(out / "design.json"),
        "write_verilog -noattr -noexpr " + quote(out / "mapped.v"),
        "design -reset",
        *library_reads,
        "read_verilog " + quote(out / "mapped.v"),
        "hierarchy -check -top student_top",
        "check -assert -mapped",
        stat_width(out, "synth-mapped-reload"),
    ]
    if args.pre_abc_json:
        abc_start = next(index for index, command in enumerate(script) if command.startswith("abc "))
        script = ["read_json " + quote(args.pre_abc_json.resolve()), *library_reads,
                   "hierarchy -check -top student_top", "check -assert",
                   "select -assert-none a:init t:$dlatch* t:$_DLATCH*",
                   stat_width(out, "synth-before-abc")] + script[abc_start:]
    run_yosys(yosys, out, "synth", script, profile=profile)
    try:
        design = read_netlist(out / "design.json", profile, "python.read_mapped_design_json")
        statistics = read_yosys_statistics(out / "stat.raw.json", out / "stat.json", profile)
        with profile.measure("python.area_report"):
            area = area_report(design, statistics, macros)
        del design, statistics
        with profile.measure("opensta.analyze"):
            timing = analyze(sta, out, [*libs, *ram_libs], args.clock_period, args.clock_port)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    def identities(paths):
        return [{"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in paths]
    with profile.measure("python.hash_inputs_and_libraries"):
        input_identities = identities([*sources, RAM_SOURCE])
        library_identities = identities([*libs, *ram_libs])
    with profile.measure("tool_version.yosys"):
        yosys_version = subprocess.check_output([yosys, "-V"], text=True).strip()
    with profile.measure("tool_version.opensta"):
        sta_version = subprocess.check_output([sta, "-version"], text=True).strip()
    report = {"schema_version": 1, "mode": args.mode, "output_directory": str(out),
              "abc_constraints": {"driving_cell": args.abc_driving_cell, "output_load_ff": args.abc_load_ff},
              "area": area, "timing": timing,
              "inputs": input_identities, "libraries": library_identities,
              "sram_model": MODEL,
              "frontend": frontend,
              "tools": {"yosys": yosys_version, "opensta": sta_version}}
    if args.elaborated_json:
        report["elaboration_snapshot"] = identities([args.elaborated_json.resolve()])[0]
    if args.pre_abc_json:
        report["pre_abc_snapshot"] = identities([args.pre_abc_json.resolve()])[0]
    with profile.measure("python.write_reports"):
        for name, data in (("report.json", report), ("timing.json", timing),
                           ("area.json", {"mode": args.mode, **area, "sram_model": MODEL, "timing_analyzed": True})):
            (out / name).write_text(json.dumps(data, indent=2, allow_nan=False) + "\n")
        (out / "report.txt").write_text(format_report(report, full=True))
    print(format_report(report), end="")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
