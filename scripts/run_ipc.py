#!/usr/bin/env python3
"""Run the vendored RV32IM IPC corpus through the Verilator IPC testbench.

Methodology (frozen contract; mirrored by tb/core/tb_core_ipc.sv):

  * One Verilator executable, six benchmark images, one process per image.
  * DUT: cpu_cached_top at full size -- 8 KiB direct-mapped I$ and a 64 KiB
    4-way write-back D$ (1024 sets x 4 ways x 16 B).
   * IMEM and DMEM are two independent 256 KiB byte-addressed arrays loaded
    from the same sparse image, so instruction and data ports never contend.
  * Every line read is answered exactly 20 cycles after the request handshake;
    line writes are accepted immediately.
  * ``cycles``  = clock cycles from reset deassertion through the
    architectural HALT commit, inclusive. The D$ flush that follows the HALT
    commit, and everything else after it, is excluded.
  * ``retired`` = committed instructions with the HALT marker excluded.
  * IPC              = retired / cycles, per benchmark.
  * Aggregate IPC    = geometric mean of the per-case IPCs over the corpus --
    exp(mean(log(retired / cycles))), not sum(retired) / sum(cycles).
   * branches         = every in-ROB conditional BRU, JAL, and JALR resolution;
      two same-cycle control completions count as two events. ``mispredicts``
      is the corresponding sum of recovery requests.
  * Aggregate branch accuracy = 1 - sum(mispredicts) / sum(branches), i.e.
    computed from summed event counts, not from averaging per-case rates.

The testbench emits a single ``IPC_RESULT`` line per benchmark and only after
its trap, timeout, memory-range, x10 and flush/drain checks all pass. Anything
else is reported as ``IPC_FAIL`` and makes this runner exit non-zero.
"""

from __future__ import annotations

import argparse
import datetime
import json
import math
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = REPO / "tests" / "benchmarks" / "manifest.json"
DEFAULT_BINARY = REPO / "build" / "obj_tb_core_ipc" / "tb_core_ipc"
DEFAULT_REPORT = REPO / "build" / "reports" / "ipc.md"

KV_RE = re.compile(r"(\w+)=(\S+)")

PROFILE_KEYS = (
    "alu", "load", "store", "branch", "jal", "jalr", "mul", "divrem", "other",
    "issue", "noissue_flush", "noissue_rob", "noissue_prf", "noissue_int_rs",
    "noissue_mul_rs", "noissue_div_rs", "noissue_branch_rs", "noissue_mem_rs",
    "noissue_lq", "noissue_sq", "noissue_frontend", "div_accept", "div_busy",
    "div_head_wait", "load_store_block", "cond_events", "jal_events", "jalr_events",
    "cond_mispredicts", "jal_mispredicts", "jalr_mispredicts", "cond_recoveries",
    "jump_recoveries", "control_overlap",
)


def parse_result_line(line: str) -> dict[str, str]:
    return {key: value for key, value in KV_RE.findall(line)}


def geomean_ipc(results: list[dict]) -> float:
    """Geometric mean of per-case IPC (retired / cycles) over passing cases."""
    ipcs = [r["retired"] / r["cycles"] for r in results if r.get("ok")]
    if not ipcs or any(v <= 0.0 for v in ipcs):
        return 0.0
    return math.exp(sum(math.log(v) for v in ipcs) / len(ipcs))


def run_benchmark(binary: pathlib.Path, entry: dict, x10_mask: int,
                  timeout_cycles: int, verbose: bool) -> dict:
    image = REPO / "tests" / "benchmarks" / entry["image"]
    required = int(entry["x10"])
    argv = [
        str(binary),
        f"+DATA={image.relative_to(REPO)}",
        f"+BENCH={entry['name']}",
        "+EXPECT={:08x}".format(required),
        "+EXPECT_MASK={:08x}".format(x10_mask),
        f"+TIMEOUT={timeout_cycles}",
    ]
    proc = subprocess.run(argv, cwd=REPO, capture_output=True, text=True)
    output = proc.stdout + proc.stderr

    result = {"name": entry["name"], "image": entry["image"],
              "x10_expected": required, "x10_mask": x10_mask,
              "ok": False, "reason": "", "diagnostics": [], "profile": {}}

    for line in output.splitlines():
        if line.startswith("IPC_RESULT "):
            result.update(parse_result_line(line))
            result["ok"] = True
        elif line.startswith("IPC_PROFILE "):
            result["profile"] = parse_result_line(line)
        elif line.startswith("IPC_FAIL "):
            fields = parse_result_line(line)
            result["reason"] = fields.get("reason", "unknown")
            result["fail_fields"] = fields
        elif line.startswith(("CHECK ", "TIMEOUT ")):
            result["diagnostics"].append(line.strip())

    if proc.returncode != 0 and result["ok"]:
        result["ok"] = False
        result["reason"] = f"exited with status {proc.returncode}"

    if result["ok"]:
        result["cycles"] = int(result["cycles"])
        result["retired"] = int(result["retired"])
        result["branches"] = int(result["branches"])
        result["mispredicts"] = int(result["mispredicts"])
        result["ipc"] = result["retired"] / result["cycles"]
        result["accuracy"] = (1.0 - result["mispredicts"] / result["branches"]
                              if result["branches"] else 1.0)
        result["x10_measured"] = int(result["x10"], 16)
        result["diverges_from_corpus"] = (
            (result["x10_measured"] & x10_mask) != (required & x10_mask))
        missing_profile = [key for key in PROFILE_KEYS if key not in result["profile"]]
        if missing_profile:
            result["ok"] = False
            result["reason"] = "missing IPC profile"
        else:
            result["profile"] = {key: int(result["profile"][key]) for key in PROFILE_KEYS}

    if verbose or not result["ok"]:
        for line in result["diagnostics"]:
            print(f"  {line}", file=sys.stderr)

    return result


def format_table(results: list[dict]) -> list[str]:
    rows = [
        "| benchmark | cycles | retired | IPC | branches | mispredicts | branch accuracy | x10 |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for r in results:
        if not r["ok"]:
            rows.append(f"| {r['name']} | - | - | - | - | - | - | FAILED ({r['reason']}) |")
            continue
        rows.append(
            "| {name} | {cycles} | {retired} | {ipc:.6f} | {branches} | "
            "{mispredicts} | {accuracy:.6f} | {x10:08x} |".format(
                name=r["name"], cycles=r["cycles"], retired=r["retired"],
                ipc=r["ipc"], branches=r["branches"],
                mispredicts=r["mispredicts"], accuracy=r["accuracy"],
                x10=r["x10_measured"]))
    return rows


def print_table(results: list[dict]) -> None:
    header = (f"{'benchmark':<10} {'cycles':>10} {'retired':>9} {'IPC':>9} "
               f"{'branches':>9} {'mispred':>8} {'accuracy':>10} {'x10':>8}")
    print(header)
    print("-" * len(header))
    for r in results:
        if not r["ok"]:
            print(f"{r['name']:<10} {'-':>10} {'-':>9} {'-':>9} {'-':>9} "
                  f"{'-':>8} {'-':>10}   FAILED ({r['reason']})")
            continue
        print(f"{r['name']:<10} {r['cycles']:>10} {r['retired']:>9} "
              f"{r['ipc']:>9.6f} {r['branches']:>9} {r['mispredicts']:>8} "
                f"{r['accuracy']:>10.6f} {r['x10_measured']:>8x}")


def profile_totals(results: list[dict]) -> dict[str, int]:
    return {key: sum(r["profile"][key] for r in results if r["ok"])
            for key in PROFILE_KEYS}


def format_profile_section(profile: dict[str, int], total_cycles: int) -> list[str]:
    rows = ["## Profiling Baseline", "",
            "### Dynamic Instruction Mix", "",
            "| class | retired |",
            "| --- | ---: |"]
    rows.extend(f"| {key} | {profile[key]} |" for key in
                ("alu", "load", "store", "branch", "jal", "jalr", "mul", "divrem", "other"))
    rows.extend(["", "### No-Issue Cycle Classification", "",
                 "| class | cycles | share of IPC interval |",
                 "| --- | ---: | ---: |"])
    for key in ("issue", "noissue_flush", "noissue_rob", "noissue_prf", "noissue_int_rs",
                "noissue_mul_rs", "noissue_div_rs", "noissue_branch_rs", "noissue_mem_rs",
                "noissue_lq", "noissue_sq", "noissue_frontend"):
        rows.append(f"| {key} | {profile[key]} | "
                    f"{profile[key] / total_cycles:.6f} |")
    rows.extend(["", "### Focused Events", "",
                 "| event | count |",
                 "| --- | ---: |"])
    rows.extend(f"| {key} | {profile[key]} |" for key in
                ("div_accept", "div_busy", "div_head_wait", "load_store_block",
                 "cond_events", "jal_events", "jalr_events", "cond_mispredicts",
                 "jal_mispredicts", "jalr_mispredicts", "cond_recoveries",
                 "jump_recoveries", "control_overlap"))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--binary", default=str(DEFAULT_BINARY),
                        help="Verilator IPC executable")
    parser.add_argument("--report", default=str(DEFAULT_REPORT),
                        help="markdown report to write ('' to skip)")
    parser.add_argument("--timeout", type=int, default=20_000_000,
                        help="per-benchmark cycle budget")
    parser.add_argument("--bench", action="append", default=None,
                        help="restrict to a benchmark (repeatable)")
    parser.add_argument("--verbose", action="store_true",
                        help="always echo testbench diagnostics")
    args = parser.parse_args()

    binary = pathlib.Path(args.binary)
    if not binary.is_file():
        print(f"IPC testbench not built: {binary}\n"
              f"run `make ipc` (or `make build/obj_tb_core_ipc/tb_core_ipc`) first.",
              file=sys.stderr)
        return 1

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    x10_mask = int(manifest["x10_compare_mask"], 0)
    entries = manifest["benchmarks"]
    if args.bench:
        wanted = set(args.bench)
        entries = [e for e in entries if e["name"] in wanted]
        if not entries:
            print(f"no manifest entry matches {sorted(wanted)}", file=sys.stderr)
            return 1

    results = [run_benchmark(binary, entry, x10_mask, args.timeout, args.verbose)
               for entry in entries]

    print()
    print_table(results)
    print()

    passed = [r for r in results if r["ok"]]
    failed = [r for r in results if not r["ok"]]
    for r in failed:
        print(f"FAILED: {r['name']} reason={r['reason']}", file=sys.stderr)

    total_cycles = sum(r["cycles"] for r in passed)
    total_retired = sum(r["retired"] for r in passed)
    total_branches = sum(r["branches"] for r in passed)
    total_mispredicts = sum(r["mispredicts"] for r in passed)
    aggregate_ipc = geomean_ipc(passed)
    aggregate_accuracy = (1.0 - total_mispredicts / total_branches
                           if total_branches else 1.0)
    profile = profile_totals(results)

    print(f"aggregate IPC = geomean(retired/cycles) over {len(passed)} cases "
          f"= {aggregate_ipc:.6f}")
    print(f"aggregate branch accuracy = 1 - {total_mispredicts}/{total_branches} "
          f"= {aggregate_accuracy:.6f}")

    diverged = [r for r in passed if r["diverges_from_corpus"]]
    if diverged:
        print()
        for r in diverged:
            note = next((e.get("note") for e in entries
                         if e["name"] == r["name"]), None)
            print(f"NOTE {r['name']}: x10={r['x10_measured']:08x} differs from "
                  f"the expected value {r['x10_expected']:08x} under mask "
                  f"{r['x10_mask']:08x}.")
            if note:
                print(f"     {note}")

    if args.report:
        report = pathlib.Path(args.report)
        report.parent.mkdir(parents=True, exist_ok=True)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
        lines = [
            "# RV32IM IPC Benchmarks",
            "",
            f"> Generated by `scripts/run_ipc.py` on {stamp}. Corpus: "
            "`tests/benchmarks/`; ISA: RV32IM.",
            "",
            "> `cycles` counts from reset deassertion through the architectural HALT "
            "commit, inclusive; the D$ flush that follows is excluded. `retired` "
            "excludes the HALT marker. IMEM and DMEM are separate 256 KiB "
            "byte-addressed memories loaded from the same image, and every line read "
            "is answered a fixed 20 cycles after the request handshake.",
            "",
            "> Aggregate IPC is the geometric mean of the per-case IPC "
            "(`retired / cycles`), not `sum(retired) / sum(cycles)`. `branches` counts each in-ROB conditional branch, "
            "JAL, and JALR resolution separately; aggregate branch accuracy is computed "
            "from those summed events and mispredictions.",
            "",
        ]
        lines.extend(format_table(results))
        lines.append("")
        lines.append(f"> Aggregate IPC = geomean(`retired / cycles`) = "
                     f"**{aggregate_ipc:.6f}** over {len(passed)} cases "
                     f"(totals {total_retired}/{total_cycles}).")
        lines.append(f"> Aggregate branch accuracy = "
                      f"**{aggregate_accuracy:.6f}** "
                      f"(1 - {total_mispredicts}/{total_branches}).")
        if passed:
            lines.append("")
            lines.extend(format_profile_section(profile, total_cycles))
        if failed:
            lines.append("")
            lines.append("> FAILED: " + ", ".join(
                f"`{r['name']}` ({r['reason']})" for r in failed))
        if diverged:
            lines.append("")
            lines.append("## Recorded divergences")
            lines.append("")
            for r in diverged:
                note = next((e.get("note") for e in entries
                             if e["name"] == r["name"]), None)
                lines.append(
                    f"- `{r['name']}`: the DUT reports `x10 = "
                    f"{r['x10_measured']:08x}`, while the expected value "
                    f"is `{r['x10_expected']:08x}` under mask "
                    f"`{r['x10_mask']:08x}`.")
                if note:
                    lines.append(f"  {note}")
        report.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"\nreport written to {report.relative_to(REPO)}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
