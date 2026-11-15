"""Incremental wall-clock records, including failed or interrupted stages."""
from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import time


def timestamp():
    return datetime.now(timezone.utc).isoformat()


class WallClockProfile:
    def __init__(self, out):
        self.out = Path(out)
        self.started = time.perf_counter()
        self.started_at = timestamp()
        self.stages = []
        self.stack = []
        self.write()

    def write(self):
        result = {
            "schema_version": 1, "pid": os.getpid(), "started_at_utc": self.started_at,
            "clock": "time.perf_counter", "unit": "seconds",
            "elapsed_wall_seconds": time.perf_counter() - self.started,
            "note": "Nested stages overlap their parents; do not sum all rows. "
                    "Yosys wall times include profiling/stat logging overhead, not just pass CPU time.",
            "stages": self.stages,
        }
        temporary = self.out / "profile.json.tmp"
        temporary.write_text(json.dumps(result, indent=2) + "\n")
        temporary.replace(self.out / "profile.json")
        lines = ["Wall-clock profile (seconds; nested rows overlap their parents)"]
        for row in self.stages:
            duration = row.get("wall_seconds")
            duration = "running" if duration is None else f"{duration:.6f}"
            lines.append(f"{'  ' * row['depth']}{row['name']}: {duration} [{row['status']}]")
        (self.out / "profile.txt").write_text("\n".join(lines) + "\n")

    @contextmanager
    def measure(self, name, **metadata):
        row = {"id": len(self.stages), "name": name, "depth": len(self.stack),
               "parent_id": self.stack[-1] if self.stack else None,
               "started_at_utc": timestamp(), "status": "running", **metadata}
        self.stages.append(row)
        self.stack.append(row["id"])
        self.write()  # Preserve the active stage even if the process is killed.
        print(f"[profile] START {name}", flush=True)
        started = time.perf_counter()
        try:
            yield row
        except BaseException as error:
            row.update(status="failed", error_type=type(error).__name__, error=str(error))
            if hasattr(error, "returncode"):
                row["returncode"] = error.returncode
            raise
        else:
            row["status"] = "completed"
        finally:
            row.update(wall_seconds=time.perf_counter() - started, finished_at_utc=timestamp())
            self.stack.pop()
            self.write()
            print(f"[profile] END {name}: {row['wall_seconds']:.6f}s ({row['status']})", flush=True)
