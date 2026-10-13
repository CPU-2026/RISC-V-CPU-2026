"""Lower SystemVerilog for Yosys without changing the production RTL."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess

from toolchain import executable


def select_frontend(name, sources, override=None):
    """Prefer sv2v for .sv input; keep plain Verilog on the native path."""
    if name == "yosys":
        if override:
            raise ValueError("--sv2v cannot be combined with --frontend yosys")
        return "yosys", None
    if name == "auto" and not override and not any(path.suffix == ".sv" for path in sources):
        return "yosys", None
    if override:
        return "sv2v", executable(override)
    appdir = os.environ.get("CPU2026_APPDIR")
    packaged = Path(appdir) / "bin" / "sv2v" if appdir else None
    found = (executable(packaged) if packaged and packaged.is_file() and os.access(packaged, os.X_OK)
             else shutil.which("sv2v"))
    if found:
        return "sv2v", found
    if name == "sv2v":
        raise ValueError("sv2v is required for this frontend: install sv2v on PATH or supply --sv2v /path/to/sv2v")
    return "yosys", None


def explicit_port_patterns(sources, directory):
    """Give sv2v the declared type of implicit input-port assignment patterns.

    Only generated copies are changed. The explicit cast has the same type as
    the original port, so field order, widths and assignment semantics remain
    unchanged. Keep the native core's existing sv2v workarounds in one place.
    """
    texts = {path: path.read_text() for path in sources}
    if len({path.name for path in sources}) != len(texts):
        raise ValueError("sv2v staging requires unique source file names")
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
            # Avoid sv2v's nonconstant replication width in this typed '0.
            rewritten = rewritten.replace("& ROB_AGE_MASK) != '0)",
                                          "& ROB_AGE_MASK) != rob_tag_t'(0))")
        target = directory / path.name
        target.write_text(rewritten)
        staged.append(target)
    return staged, changes


def convert_sources(sv2v, sources, directory, *, top="student_top", defines=("SYNTHESIS",)):
    """Return converted RTL and its provenance; never hand-flatten structs.

    Retain always_ff/always_comb during sv2v conversion: lowering helper calls
    can otherwise produce illegal whole-array sensitivity lists. Afterwards
    use @* for Yosys's function-temporary handling. The synthesis flow still
    rejects every surviving latch, undriven signal and unmapped cell.
    """
    staged, changes = explicit_port_patterns(sources, directory / "sources")
    command = [sv2v, *[arg for define in defines for arg in ("-D", define)],
               "--exclude=Always", f"--top={top}", *map(str, staged)]
    converted = directory / "converted.v"
    log = directory / "sv2v.log"
    with converted.open("w") as stream, log.open("w") as errors:
        result = subprocess.run(command, stdout=stream, stderr=errors)
    if result.returncode:
        converted.unlink(missing_ok=True)
        raise ValueError(f"SystemVerilog conversion failed (exit {result.returncode}); see {log}")
    converted.write_text(re.sub(r"\balways_comb\b", "always @*", converted.read_text()))
    manifest = {
        "name": "sv2v",
        "sv2v": subprocess.check_output([sv2v, "--version"], text=True).strip(),
        "conversion_command": command,
        "explicit_port_patterns": changes,
        "combinational_lowering": "always_comb -> always @*; surviving latches rejected",
        "converted_sha256": hashlib.sha256(converted.read_bytes()).hexdigest(),
    }
    if any(path.name == "rv32_prf.sv" for path in sources):
        manifest["typed_zero_lowering"] = "PRF masked ROB-age comparison uses rob_tag_t'(0) instead of '0"
    return converted, manifest
