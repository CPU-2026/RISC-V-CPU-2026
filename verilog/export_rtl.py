"""Export the editable SV as one RTL file for course synthesis and simulation."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

VERILOG = Path(__file__).resolve().parent
sys.path.insert(0, str(VERILOG.parent / "scripts"))
from build import read_sources
from sv_frontend import explicit_port_patterns, factor_registered_axi_outputs


def export(sv2v, defines, work, *, source_list=None):
    if source_list is None:
        source_list = VERILOG / "rtl_sources.f"
    sources = read_sources(source_list)
    staged, _ = explicit_port_patterns(sources, work / "sources")
    factor_registered_axi_outputs(staged)

    # sv2v preprocesses away `ifndef SYNTHESIS. Lower both views of the
    # same inputs and retain their differences under that same macro.
    files = []
    for view in ("simulation", "synthesis"):
        flags = ["--exclude=Assert"] if view == "simulation" else ["-DSYNTHESIS"]
        result = subprocess.check_output([
            sv2v, "--exclude=Always", "--top=student_top", *flags,
            *["-D" + d for d in defines], *staged])
        path = work / (view + ".sv")
        path.write_bytes(re.sub(rb"\balways_comb\b", b"always @*", result))
        files.append(path)
    # GNU diff's group formats leave common logic in the file just once.
    merged = subprocess.run([
        "diff", "--minimal", "--unchanged-group-format=%=",
        "--old-group-format=`ifndef SYNTHESIS\n%<`endif\n",
        "--new-group-format=`ifdef SYNTHESIS\n%>`endif\n",
        "--changed-group-format=`ifndef SYNTHESIS\n%<`else\n%>`endif\n",
        *files], stdout=subprocess.PIPE)
    if merged.returncode not in (0, 1):
        merged.check_returncode()

    # An ASCII logical filename also keeps checkout paths out of RTLIL names.
    header = b"// Generated from the supplied source list by verilog/export_rtl.py; edit the sources instead.\n"
    return header + b'`line 3 "generated/student_top.sv" 0\n' + merged.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sv2v", default="sv2v")
    parser.add_argument("-D", dest="defines", action="append", default=[], metavar="CPU_NAME=VALUE")
    parser.add_argument("--sources", type=Path, default=VERILOG / "rtl_sources.f",
                        help="source list to read, e.g. verilog/filelist.f in a frozen checkout")
    parser.add_argument("--output", type=Path, default=VERILOG / "generated/student_top.sv")
    parser.add_argument("--check", action="store_true", help="fail if the submitted RTL is stale")
    args = parser.parse_args()
    if any(not re.fullmatch(r"CPU_[A-Z0-9_]+(?:=\d+)?", d) for d in args.defines):
        parser.error("-D accepts CPU configuration macros only")
    try:
        with tempfile.TemporaryDirectory(prefix="cpu-export-") as temp:
            data = export(args.sv2v, args.defines, Path(temp), source_list=args.sources)
    except (OSError, ValueError) as error:
        parser.exit(1, f"RTL export failed: {error}\n")
    except subprocess.CalledProcessError as error:
        parser.exit(1, f"RTL export failed: {error.cmd[0]} exited with status {error.returncode}\n")
    if args.output.is_file() and args.output.read_bytes() == data:
        return
    if args.check:
        parser.exit(1, f"stale or missing generated RTL: {args.output}\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.output.parent, prefix=".export-") as temp:
        pending = Path(temp) / args.output.name
        pending.write_bytes(data)
        pending.replace(args.output)


if __name__ == "__main__":
    main()
