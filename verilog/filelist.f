# RTL paths are relative to this file in verilog/.
# This source tree currently provides cpu_top and cpu_cached_top. It does not
# yet provide the framework-required student_top AXI4-Lite wrapper.
rtl/common/rv32_pkg.sv
rtl/common/rv32_cla.sv
rtl/core/rv32_core.sv
rtl/core/rv32_flush_arbiter.sv
rtl/frontend/rv32_decoder.sv
rtl/frontend/rv32_frontend.sv
rtl/backend/rv32_rat.sv
rtl/backend/rv32_prf.sv
rtl/backend/rv32_rob.sv
rtl/backend/rv32_rs.sv
rtl/memory/rv32_lsu.sv
rtl/memory/rv32_sram_1rw.sv
rtl/memory/rv32_icache.sv
rtl/memory/rv32_dcache.sv
rtl/predictor/rv32_bpu_direction.sv
rtl/predictor/rv32_bpu_btb.sv
rtl/predictor/rv32_bpu_ras.sv
rtl/predictor/rv32_bpu_checkpoint.sv
rtl/predictor/rv32_predictor.sv
rtl/execute/rv32_alu.sv
rtl/execute/rv32_alu_unit.sv
rtl/execute/rv32_agu.sv
rtl/execute/rv32_bru.sv
rtl/execute/rv32_bru_unit.sv
rtl/execute/rv32_mul.sv
rtl/execute/rv32_div.sv
rtl/cpu_top.sv
rtl/cpu_cached_top.sv
