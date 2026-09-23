# RTL Source Tree

`filelist.f` is the authoritative list of synthesizable RTL sources. Paths in
that file are relative to this directory.

## Layout

- `rtl/common/`: shared types, instruction definitions, and arithmetic cells
- `rtl/frontend/`: fetch and decode
- `rtl/backend/`: rename, physical registers, reorder buffer, and reservation stations
- `rtl/execute/`: integer, branch, multiply, divide, and address-generation units
- `rtl/memory/`: load/store unit, caches, and local SRAM wrapper
- `rtl/predictor/`: branch-prediction structures
- `rtl/core/`: core integration and flush arbitration

## Current Integration Status

The preserved implementation has two native top modules:

- `cpu_top`: uncached split instruction/data ready-valid interface
- `cpu_cached_top`: cached 128-bit-line memory interface

Neither module is the course framework's `student_top` AXI4-Lite top level.
Consequently, the official `make build`, `make test`, `make perf`, and `make
synth` flows cannot run until an adapter provides the required interface,
active-high reset behavior, MMIO exit store, and FakeRAM-compatible SRAMs.

The legacy testbenches and legacy test runner scripts were intentionally
removed. The official `testcases/` submodule remains the only regression input
tree.
