#!/usr/bin/env python3
"""Assess the core, cached system, or DCache without an external memory slave."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from build import read_sources
from fakeram import RAM_SOURCE
from sv_frontend import convert_sources
from toolchain import DEFAULT_APPIMAGE, executable


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope", choices=("core", "cached", "dcache"), default="cached")
    parser.add_argument("--mode", choices=("opt", "diagnose"), default="opt")
    parser.add_argument("--clock-period", type=float, default=2.0)
    parser.add_argument("--out", type=Path, default=root / "build" / "assessment")
    parser.add_argument("--work-dir", type=Path,
                        help="optional working root; default is the durable output directory")
    parser.add_argument("--sv2v", default="sv2v")
    parser.add_argument("--appimage", default=str(DEFAULT_APPIMAGE))
    parser.add_argument("--background", action="store_true", help="launch a persistent assessment job")
    parser.add_argument("--prepare-only", action="store_true", help="convert RTL without running synthesis")
    parser.add_argument("--reuse-elaboration", type=Path,
                        help="reuse elaborated.json after checking its assessment source manifest")
    parser.add_argument("--reuse-pre-abc", type=Path,
                        help="resume pre-abc.json; also supply its matching --reuse-elaboration")
    parser.add_argument("--no-checkpoints", action="store_true",
                        help="skip large generic/pre-ABC JSON snapshots during synthesis")
    args = parser.parse_args()
    if args.background:
        destination = args.out.resolve() / args.scope
        destination.mkdir(parents=True, exist_ok=True)
        command = [sys.executable, str(Path(__file__).resolve()),
                   *[arg for arg in sys.argv[1:] if arg != "--background"]]
        log = destination / f"job-{args.mode}.log"
        with log.open("w") as stream:
            job = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        (destination / f"job-{args.mode}.pid").write_text(str(job.pid) + "\n")
        print(f"Started PID {job.pid}; progress: {log}")
        return
    try:
        sv2v = executable(args.sv2v)
        # Use the framework's canonical SRAM declaration once. The unfinished
        # AXI course wrapper is replaced only in this assessment source list.
        if args.scope == "dcache":
            sources = [root / "verilog" / "rtl" / "common" / "rv32_pkg.sv",
                       root / "verilog" / "rtl" / "memory" / "rv32_dcache.sv",
                       RAM_SOURCE, root / "verilog" / "assessment" / "dcache_top.sv"]
        else:
            sources = [path for path in read_sources(root / "verilog" / "filelist.f")
                       if path.name not in ("student_top.sv", "rv32_sram.sv")]
            sources += [RAM_SOURCE, root / "verilog" / "assessment" / "student_top.sv"]
        destination = args.out.resolve() / args.scope
        out = args.work_dir.resolve() / args.scope if args.work_dir else destination
        out.mkdir(parents=True, exist_ok=True)
        defines = ("SYNTHESIS", "ASSESS_CORE_ONLY") if args.scope == "core" else ("SYNTHESIS",)
        converted, frontend = convert_sources(sv2v, sources, out, defines=defines)
        filelist = out / "filelist.f"
        filelist.write_text("converted.v\n")
        manifest = {
            "scope": args.scope, "mode": args.mode,
            "hierarchical_optimization": False,
            "clock_period_ns": args.clock_period,
            "external_memory": "ports only; no slave or bus adapter",
            "commit_trace_outputs": "not applicable" if args.scope == "dcache" else "retained as top-level outputs",
            "frontend": frontend["name"],
            **{key: value for key, value in frontend.items() if key != "name"},
            "inputs": [{"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                       for path in sources],
        }
        if args.reuse_elaboration:
            snapshot = args.reuse_elaboration.resolve()
            previous_manifest = snapshot.parent.parent / f"assessment-{snapshot.parent.name}.json"
            previous = json.loads(previous_manifest.read_text())
            if previous["inputs"] != manifest["inputs"] or previous["converted_sha256"] != manifest["converted_sha256"]:
                raise ValueError("elaboration snapshot does not match the current RTL and conversion")
            manifest["elaboration_snapshot"] = {
                "path": str(snapshot), "sha256": hashlib.sha256(snapshot.read_bytes()).hexdigest()}
        if args.reuse_pre_abc:
            if not args.reuse_elaboration:
                raise ValueError("--reuse-pre-abc requires --reuse-elaboration")
            checkpoint = args.reuse_pre_abc.resolve()
            previous = json.loads((checkpoint.parent.parent / f"assessment-{checkpoint.parent.name}.json").read_text())
            if previous["mode"] != args.mode or previous["inputs"] != manifest["inputs"] or previous["converted_sha256"] != manifest["converted_sha256"]:
                raise ValueError("pre-ABC checkpoint does not match this mode and RTL conversion")
            manifest["pre_abc_snapshot"] = {
                "path": str(checkpoint), "sha256": hashlib.sha256(checkpoint.read_bytes()).hexdigest()}
        (out / f"assessment-{args.mode}.json").write_text(json.dumps(manifest, indent=2) + "\n")
        if args.prepare_only:
            print(f"Prepared {converted}")
            return
        synth_command = [
            sys.executable, str(root / "scripts" / "synth.py"),
            "--filelist", str(filelist), "--out", str(out), "--mode", args.mode,
            "--clock-period", str(args.clock_period), "--appimage", args.appimage,
        ]
        if not args.no_checkpoints:
            synth_command.append("--checkpoints")
        if args.reuse_elaboration:
            synth_command += ["--elaborated-json", str(args.reuse_elaboration.resolve())]
        if args.mode == "diagnose":
            synth_command += ["--no-hieropt"]
        if args.reuse_pre_abc:
            synth_command += ["--pre-abc-json", str(args.reuse_pre_abc.resolve())]
        log = out / f"assessment-{args.mode}.log"
        print(f"[{args.scope}/{args.mode}] synthesis log: {log}", flush=True)
        with log.open("w") as stream:
            started_wall = time.time()
            result = subprocess.Popen(synth_command, stdout=stream, stderr=subprocess.STDOUT)
            started = time.monotonic()
            while result.poll() is None:
                time.sleep(30)
                if result.poll() is not None:
                    break
                stage = "starting tools"
                for name in ("elaborate.log", "synth.log", "timing.log"):
                    progress = out / args.mode / name
                    if progress.exists() and progress.stat().st_mtime >= started_wall:
                        text = progress.read_text(errors="replace")
                        matches = re.findall(r"(?m)^\d+(?:\.\d+)*\. (Executing .*|Printing statistics\.)", text)
                        stage = matches[-1] if matches else name
                print(f"[{args.scope}/{args.mode}] {int(time.monotonic()-started)}s: {stage}", flush=True)
        if destination != out:
            shutil.copytree(out, destination, dirs_exist_ok=True)
        if result.returncode:
            raise ValueError(f"synthesis failed (exit {result.returncode}); see {destination / log.name}")
        print(f"Published reports: {destination / args.mode}")
        print((out / args.mode / "report.txt").read_text(), end="")
    except (ValueError, OSError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
