#!/usr/bin/env python3
"""Build a Verilator simulator from the RTL files in a file list."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

from toolchain import DEFAULT_APPIMAGE, enter_appimage, executable, packaged_tool
from fakeram import with_ram_source


def read_sources(filelist):
    filelist = filelist.resolve()
    if not filelist.is_file():
        raise ValueError(f"file list does not exist: {filelist}")
    sources = []
    for line in filelist.read_text().splitlines():
        entry = line.split("#", 1)[0].strip()
        if not entry:
            continue
        source = (filelist.parent / entry).resolve()
        if source.suffix not in (".v", ".sv") or not source.is_file():
            raise ValueError(f"invalid RTL entry in {filelist}: {entry}")
        if source in sources:
            raise ValueError(f"duplicate RTL entry in {filelist}: {entry}")
        sources.append(source)
    if not sources:
        raise ValueError(f"file list is empty: {filelist}")
    return sources


def verilator_command(override=None):
    if override:
        return executable(override)
    packaged = packaged_tool("verilator")
    if packaged:
        print("[build] Using AppImage Verilator", file=sys.stderr)
        return packaged
    installed = shutil.which("verilator")
    if installed:
        print(f"[build] Using system Verilator: {installed}", file=sys.stderr)
        return installed
    raise ValueError("Verilator not found: install verilator on PATH, "
                     "or configure VERILATOR / APPIMAGE in config.mk")


def build_environment(out):
    environment = os.environ.copy()
    # This build has its own job limit, not the parent Make's jobserver.
    for name in ("MAKEFLAGS", "GNUMAKEFLAGS", "MFLAGS"):
        environment.pop(name, None)
    tmp = environment.get("TMPDIR")
    if not tmp or not Path(tmp).is_dir() or not os.access(tmp, os.W_OK | os.X_OK):
        tmp = out / "tmp"
        tmp.mkdir(exist_ok=True)
    tmp = str(Path(tmp).resolve())
    environment.update(TMPDIR=tmp, TMP=tmp, TEMP=tmp)
    return environment


def build_simulator(sources, out, args):
    verilator = verilator_command(args.verilator)
    make = executable(args.make)
    cxx = executable(args.cxx)
    ar = executable(args.ar)
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    binary = out / "sim"
    binary.unlink(missing_ok=True)
    # Verilator's generated dependencies contain absolute paths. Recreate only
    # its object directory so moved checkouts and transient AppImage mounts work.
    objects = out / "obj"
    if objects.is_symlink():
        objects.unlink()
    elif objects.exists():
        shutil.rmtree(objects)
    environment = build_environment(out)
    # Passing -j to newer Verilator versions regroups the split C++ files
    # into larger translation units. Apply the job limit only to GNU Make.
    subprocess.run([
        verilator, "--cc", "--exe", "--trace", "--assert",
        "--unroll-count", "1024", "--unroll-stmts", "100000",
        "--output-split", "10000",
        "-Wall", "-Wno-fatal", "--top-module", "student_top",
        "--Mdir", str(objects), "-o", str(binary),
        "-CFLAGS", "-std=c++17",
        *[str(path) for path in with_ram_source(sources)],
        str(Path(__file__).resolve().with_name("sim.cpp")),
    ], check=True, env=environment)
    make_command = [make, "-C", str(objects), "-f", "Vstudent_top.mk", "-j", str(args.jobs)]
    if args.jobs > 1:
        # GNU Make 4.4 defaults to FIFOs, which some sandboxes and DrvFS lack.
        help_text = subprocess.check_output([make, "--help"], env=environment)
        if b"--jobserver-style" in help_text:
            make_command.append("--jobserver-style=pipe")
    subprocess.run([
        *make_command, f"CXX={cxx}", f"LINK={cxx}", f"AR={ar}", f"PYTHON3={sys.executable}",
    ], check=True, env=environment)
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--filelist", type=Path, default=Path("verilog/filelist.f"))
    parser.add_argument("--out", type=Path, default=Path("build"))
    parser.add_argument("--appimage", default=str(DEFAULT_APPIMAGE))
    parser.add_argument("--verilator", help="custom Verilator executable (takes precedence over AppImage)")
    parser.add_argument("--cxx", default="g++")
    parser.add_argument("--ar", default="ar")
    parser.add_argument("--make", default="make")
    parser.add_argument("--jobs", type=int, default=1, help="parallel C++ compile jobs (default: 1)")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    try:
        if not args.verilator:
            enter_appimage(args.appimage)
        sources = read_sources(args.filelist)
        binary = build_simulator(sources, args.out, args)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
    print(binary)


if __name__ == "__main__":
    main()
