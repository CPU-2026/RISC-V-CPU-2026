#!/usr/bin/env python3
"""Assess the native core, optionally with caches, without a memory slave."""
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
from toolchain import DEFAULT_APPIMAGE, executable


def explicit_port_patterns(sources, directory):
    """Supply the declared port type for sv2v's implicit-pattern limitation.

    Only generated copies are changed: type'('{field: value}) has the same
    SystemVerilog semantics as the original pattern in a typed input port.
    """
    texts = {path: path.read_text() for path in sources}
    ports = {}
    for text in texts.values():
        module = re.search(r"\bmodule\s+(\w+)", text)
        if module:
            ports[module[1]] = dict((name, kind) for kind, name in re.findall(
                r"\binput\s+(rv32_pkg::\w+)\s+(\w+)", text))
    changes = []
    staged = []
    directory.mkdir(parents=True, exist_ok=True)
    for path, text in texts.items():
        def instance(match):
            block = match[0]
            replacements = []
            for port in re.finditer(r"\.(\w+)\(\s*('\{)", block):
                kind = ports.get(match[1], {}).get(port[1])
                if not kind:
                    raise ValueError(f"unknown pattern port type: {path}: {match[1]}.{port[1]}")
                start = port.start(2)
                depth = 1
                end = start + 2
                while end < len(block) and depth:
                    depth += (block[end] == "{") - (block[end] == "}")
                    end += 1
                if depth:
                    raise ValueError(f"unbalanced assignment pattern in {path}")
                replacements.append((start, end, kind + "'(" + block[start:end] + ")"))
                changes.append({"source": str(path), "module": match[1], "port": port[1], "type": kind})
            for start, end, replacement in reversed(replacements):
                block = block[:start] + replacement + block[end:]
            return block
        rewritten = re.sub(r"^  (rv32_\w+)\s+.*?\);", instance, text, flags=re.MULTILINE | re.DOTALL)
        if path.name == "rv32_prf.sv":
            # sv2v otherwise emits a nonconstant replication width for '0 in
            # the variable-index packed-struct ROB-age expression.
            rewritten = rewritten.replace("& ROB_AGE_MASK) != '0)",
                                          "& ROB_AGE_MASK) != rob_tag_t'(0))")
        target = directory / path.name
        target.write_text(rewritten)
        staged.append(target)
    return staged, changes


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope", choices=("core", "cached"), default="cached")
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
        sources = [path for path in read_sources(root / "verilog" / "filelist.f")
                   if path.name not in ("student_top.sv", "rv32_sram.sv")]
        sources += [RAM_SOURCE, root / "verilog" / "assessment" / "student_top.sv"]
        destination = args.out.resolve() / args.scope
        out = args.work_dir.resolve() / args.scope if args.work_dir else destination
        out.mkdir(parents=True, exist_ok=True)
        staged, pattern_changes = explicit_port_patterns(sources, out / "sources")
        converted = out / "converted.v"
        # Yosys accepts always_comb/always_ff. Retaining them avoids sv2v's
        # invalid whole-unpacked-array sensitivity lists in LSU helper calls.
        command = [sv2v, "-D", "SYNTHESIS", "--exclude=Always", "--top=student_top"]
        if args.scope == "core":
            command += ["-D", "ASSESS_CORE_ONLY"]
        command += [str(path) for path in staged]
        with converted.open("w") as stream:
            subprocess.run(command, stdout=stream, check=True)
        # Older Yosys treats automatic function temporaries in conditionally
        # called helpers as always_comb latch errors. Normal @* lowering lets
        # optimization remove those unused temporaries; synth.py still rejects
        # every surviving latch in the actual mapped circuit.
        converted.write_text(re.sub(r"\balways_comb\b", "always @*", converted.read_text()))
        filelist = out / "filelist.f"
        filelist.write_text("converted.v\n")
        manifest = {
            "scope": args.scope, "mode": args.mode,
            "hierarchical_optimization": False,
            "clock_period_ns": args.clock_period,
            "external_memory": "ports only; no slave or bus adapter",
            "commit_trace_outputs": "retained as top-level outputs",
            "sv2v": subprocess.check_output([sv2v, "--version"], text=True).strip(),
            "conversion_command": command,
            "explicit_port_patterns": pattern_changes,
            "combinational_lowering": "always_comb -> always @*; surviving latches rejected",
            "typed_zero_lowering": "PRF masked ROB-age comparison uses rob_tag_t'(0) instead of '0",
            "inputs": [{"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                       for path in sources],
            "converted_sha256": hashlib.sha256(converted.read_bytes()).hexdigest(),
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
