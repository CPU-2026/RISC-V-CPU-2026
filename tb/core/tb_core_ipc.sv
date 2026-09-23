`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// tb_core_ipc -- IPC benchmark harness for the full-size cached core.
//
// Methodology (frozen contract; scripts/run_ipc.py mirrors the same formulae):
//
//   * DUT geometry: cpu_cached_top at its default full size -- 8 KiB
//     direct-mapped I$ (512 sets x 16 B) and 64 KiB 4-way write-back D$
//     (1024 sets x 4 ways x 16 B).
  //   * IMEM and DMEM are two independent 256 KiB byte-addressed arrays, both
//     loaded from the same sparse benchmark image. Keeping the instruction
//     and data ports on separate memories removes port contention from the
//     measurement, so the numbers characterise the core, not the interconnect.
//   * A line read is answered exactly MEM_LATENCY clock cycles after the
//     request handshake. Line writes are accepted immediately (fire and
//     forget), matching the reference model. The latency actually observed on
//     every read is tracked and the run fails if it is not MEM_LATENCY.
//   * cycles  = clock cycles from reset deassertion through the architectural
//               HALT commit, inclusive. Nothing after the HALT commit is
//               counted -- not even the D$ flush that eventually raises
//               halted_o.
//   * retired = committed instructions with the HALT marker excluded.
  //   * branches    = cycles with an in-ROB conditional BRU or JAL/JALR ALU
  //                   control resolution read back by the predictor.
  //     mispredicts = those cycles that request a predictor recovery.
//   * After the HALT commit the simulation keeps running, uncounted, until
//     halted_o (D$ flush complete) purely for correctness checking: the
//     architectural memory shadow folded from committed stores must match
//     DMEM, and the MMIO result byte must have drained from the D$.
//   * The machine-readable IPC_RESULT line is emitted only when the trap,
//     timeout, memory-range, x10 and flush checks all pass.
//
// Program memory map, fixed by the corpus linker script:
//   0x00000..0x0000f  boot stub (lui sp,0x20000 / jal main / HALT)
//   0x01000..         text, rodata and data of the benchmark
//   0x1ffff           top of RAM; sp starts at 0x20000 and grows down
//   0x30000..0x3001f  MMIO window, result byte at +4
// ---------------------------------------------------------------------------
module tb_core_ipc #(
  parameter bit DIV_USE_SRT4 = 1'b0
);
  // ---------------------------------------------------------------- geometry
  localparam int unsigned LINE_BYTES   = 16;
  localparam int unsigned MEM_BYTES    = 256 * 1024;
  localparam int unsigned MEM_LATENCY  = 20;
  localparam int unsigned ICACHE_BYTES = 8 * 1024;
  localparam int unsigned DCACHE_BYTES = 64 * 1024;
  localparam int unsigned DCACHE_WAYS  = 4;
  localparam int unsigned ICACHE_SETS  = ICACHE_BYTES / LINE_BYTES;
  localparam int unsigned DCACHE_SETS  =
      DCACHE_BYTES / (LINE_BYTES * DCACHE_WAYS);

  // ------------------------------------------------------------------- model
  localparam logic [31:0] HALT_INSN      = 32'h0ff0_0513;
  localparam logic [31:0] HALT_PC        = 32'h0000_0008;
  localparam int unsigned DEFAULT_TIMEOUT = 20_000_000;

  // --------------------------------------------------------------- DUT ports
  logic clk, rst_n;
  logic imem_line_req_valid, imem_line_req_ready;
  logic [31:0] imem_line_req_addr;
  logic imem_line_rsp_valid;
  logic [127:0] imem_line_rsp_data;
  logic dmem_line_req_valid, dmem_line_req_ready, dmem_line_req_write;
  logic [31:0] dmem_line_req_addr;
  logic [127:0] dmem_line_req_wdata;
  logic dmem_line_rsp_valid;
  logic [127:0] dmem_line_rsp_data;
  logic commit_valid;
  logic [31:0] commit_pc, commit_instr;
  logic commit_rd_valid;
  logic [4:0] commit_rd;
  logic [31:0] commit_rd_value;
  logic commit_mem_valid;
  logic [31:0] commit_mem_addr, commit_mem_data;
  logic [3:0] commit_mem_wstrb;
  logic halted, trap;

  // ----------------------------------------------------------- memory model
  logic [7:0] imem_bytes [0:MEM_BYTES-1];
  logic [7:0] dmem_bytes [0:MEM_BYTES-1];
  logic [7:0] shadow_mem [0:MEM_BYTES-1];
  logic       imem_busy_q, imem_rsp_valid_q;
  logic       dmem_busy_q, dmem_rsp_valid_q;
  logic [7:0] imem_wait_q,  dmem_wait_q;
  logic [31:0] imem_addr_q, dmem_addr_q;
  logic [127:0] imem_rsp_data_q, dmem_rsp_data_q;
  logic [63:0] imem_req_tick_q, dmem_req_tick_q;
  int unsigned imem_reads_q, dmem_reads_q, dmem_writes_q;
  int unsigned imem_lat_min_q, imem_lat_max_q;
  int unsigned dmem_lat_min_q, dmem_lat_max_q;
  int unsigned range_errors_q;
  logic [31:0] range_error_addr_q;

  // ------------------------------------------------------------- IPC counters
  logic        ipc_frozen_q;
  logic [63:0] tick_q;
  int unsigned ipc_cycles_q;
  int unsigned retired_q;
  int unsigned branches_q;
  int unsigned mispredicts_q;
  logic [31:0] x10_q, x10_at_halt_q, halt_pc_q;

  // These counters describe the architectural mix and classify every counted
  // IPC cycle exactly once. They deliberately observe the DUT rather than
  // alter its datapath, so profiling has no microarchitectural side effects.
  int unsigned mix_alu_q, mix_load_q, mix_store_q, mix_branch_q;
  int unsigned mix_jal_q, mix_jalr_q, mix_mul_q, mix_divrem_q, mix_other_q;
  int unsigned no_issue_fire_q, no_issue_flush_q, no_issue_rob_q;
  int unsigned no_issue_prf_q, no_issue_int_rs_q, no_issue_mul_rs_q;
  int unsigned no_issue_div_rs_q, no_issue_branch_rs_q, no_issue_mem_rs_q;
  int unsigned no_issue_lq_q, no_issue_sq_q, no_issue_frontend_q;
  int unsigned div_accept_q, div_busy_q, div_head_wait_q, load_store_block_q;
  int unsigned cond_events_q, jal_events_q, jalr_events_q;
  int unsigned cond_mispredicts_q, jal_mispredicts_q, jalr_mispredicts_q;
  int unsigned cond_recoveries_q, jump_recoveries_q;
  int unsigned control_overlap_q;

  logic [31:0] jump_instr;
  logic [6:0] iq_opcode, commit_opcode, jump_opcode;
  logic cf_trace_enable;
  logic [7:0] cf_fetch_ghr_q [0:31];
  logic [7:0] cf_fetch_ras_top_q [0:31];
  logic [7:0] cf_fetch_align_tail_q [0:31];
  logic cf_fetch_btb_q [0:31];

  assign iq_opcode = u_dut.u_core.iq_instr[6:0];
  assign commit_opcode = commit_instr[6:0];
  assign jump_instr = imem_word(u_dut.u_core.jump_rob_pc);
  assign jump_opcode = jump_instr[6:0];

  cpu_cached_top #(
    .ICACHE_SETS(ICACHE_SETS),
    .DCACHE_SETS(DCACHE_SETS),
    .DCACHE_WAYS(DCACHE_WAYS),
    .DIV_USE_SRT4(DIV_USE_SRT4)
  ) u_dut (
    .clk_i(clk), .rst_ni(rst_n),
    .imem_line_req_valid_o(imem_line_req_valid),
    .imem_line_req_ready_i(imem_line_req_ready),
    .imem_line_req_addr_o(imem_line_req_addr),
    .imem_line_rsp_valid_i(imem_line_rsp_valid),
    .imem_line_rsp_data_i(imem_line_rsp_data),
    .dmem_line_req_valid_o(dmem_line_req_valid),
    .dmem_line_req_ready_i(dmem_line_req_ready),
    .dmem_line_req_write_o(dmem_line_req_write),
    .dmem_line_req_addr_o(dmem_line_req_addr),
    .dmem_line_req_wdata_o(dmem_line_req_wdata),
    .dmem_line_rsp_valid_i(dmem_line_rsp_valid),
    .dmem_line_rsp_data_i(dmem_line_rsp_data),
    .commit_valid_o(commit_valid), .commit_pc_o(commit_pc),
    .commit_instr_o(commit_instr),
    .commit_rd_valid_o(commit_rd_valid), .commit_rd_o(commit_rd),
    .commit_rd_value_o(commit_rd_value),
    .commit_mem_valid_o(commit_mem_valid),
    .commit_mem_addr_o(commit_mem_addr),
    .commit_mem_data_o(commit_mem_data),
    .commit_mem_wstrb_o(commit_mem_wstrb),
    .halted_o(halted), .trap_o(trap)
  );

  always #5 clk = ~clk;

  // Every line access must land inside the 256 KiB RAM. There is no MMIO
  // region: the corpus stub does reference 0x00030004, but that store sits
  // after `main`'s return address and is architecturally unreachable because
  // the HALT marker occupies PC 0x8, so a strict RAM-only rule is exact today.
  function automatic logic line_in_ram(input logic [31:0] base);
    begin
      line_in_ram = (base + LINE_BYTES - 1) < MEM_BYTES;
    end
  endfunction

  // IMEM and DMEM are physically distinct, so instruction fetch can never
  // observe a benchmark's data stores. Keep the two line readers separate.
  function automatic logic [127:0] imem_line(input logic [31:0] base);
    logic [31:0] line_base;
    begin
      line_base = {base[31:4], 4'b0};
      imem_line = 128'b0;
      for (int b = 0; b < LINE_BYTES; b = b + 1)
        imem_line[(b << 3) +: 8] = imem_bytes[line_base + b];
    end
  endfunction

  function automatic logic [31:0] imem_word(input logic [31:0] address);
    begin
      if ((address + 3) < MEM_BYTES)
        imem_word = {imem_bytes[address + 3], imem_bytes[address + 2],
                     imem_bytes[address + 1], imem_bytes[address]};
      else
        imem_word = 32'b0;
    end
  endfunction

  function automatic logic [127:0] dmem_line(input logic [31:0] base);
    logic [31:0] line_base;
    begin
      line_base = {base[31:4], 4'b0};
      dmem_line = 128'b0;
      for (int b = 0; b < LINE_BYTES; b = b + 1)
        dmem_line[(b << 3) +: 8] = dmem_bytes[line_base + b];
    end
  endfunction

  // -------------------------------------------------------------- IMEM
  assign imem_line_req_ready = !imem_busy_q;
  assign imem_line_rsp_valid = imem_rsp_valid_q;
  assign imem_line_rsp_data  = imem_rsp_data_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      imem_busy_q      <= 1'b0;
      imem_rsp_valid_q <= 1'b0;
      imem_wait_q      <= '0;
      imem_addr_q      <= '0;
      imem_rsp_data_q  <= '0;
      imem_req_tick_q  <= '0;
      imem_reads_q     <= 0;
      imem_lat_min_q   <= 0;
      imem_lat_max_q   <= 0;
    end else begin
      imem_rsp_valid_q <= 1'b0;
      if (imem_busy_q) begin
        if (imem_wait_q == 8'd0) begin
          imem_busy_q      <= 1'b0;
          imem_rsp_valid_q <= 1'b1;
          imem_rsp_data_q  <= imem_line(imem_addr_q);
          if (imem_reads_q == 1) begin
            imem_lat_min_q <= tick_q + 1 - imem_req_tick_q;
            imem_lat_max_q <= tick_q + 1 - imem_req_tick_q;
          end else begin
            if ((tick_q + 1 - imem_req_tick_q) < imem_lat_min_q)
              imem_lat_min_q <= tick_q + 1 - imem_req_tick_q;
            if ((tick_q + 1 - imem_req_tick_q) > imem_lat_max_q)
              imem_lat_max_q <= tick_q + 1 - imem_req_tick_q;
          end
        end else begin
          imem_wait_q <= imem_wait_q - 8'd1;
        end
      end else if (imem_line_req_valid && imem_line_req_ready) begin
        imem_reads_q    <= imem_reads_q + 1;
        imem_req_tick_q <= tick_q + 1;
        if (!line_in_ram(imem_line_req_addr)) begin
          range_errors_q    <= range_errors_q + 1;
          range_error_addr_q <= imem_line_req_addr;
        end
        imem_addr_q <= imem_line_req_addr;
        imem_wait_q <= MEM_LATENCY[7:0] - 8'd1;
        imem_busy_q <= 1'b1;
      end
    end
  end

  // -------------------------------------------------------------- DMEM
  assign dmem_line_req_ready = !dmem_busy_q;
  assign dmem_line_rsp_valid = dmem_rsp_valid_q;
  assign dmem_line_rsp_data  = dmem_rsp_data_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dmem_busy_q      <= 1'b0;
      dmem_rsp_valid_q <= 1'b0;
      dmem_wait_q      <= '0;
      dmem_addr_q      <= '0;
      dmem_rsp_data_q  <= '0;
      dmem_req_tick_q  <= '0;
      dmem_reads_q     <= 0;
      dmem_writes_q    <= 0;
      dmem_lat_min_q   <= 0;
      dmem_lat_max_q   <= 0;
      range_errors_q   <= 0;
      range_error_addr_q <= '0;
    end else begin
      dmem_rsp_valid_q <= 1'b0;
      if (dmem_busy_q) begin
        if (dmem_wait_q == 8'd0) begin
          dmem_busy_q      <= 1'b0;
          dmem_rsp_valid_q <= 1'b1;
          dmem_rsp_data_q  <= dmem_line(dmem_addr_q);
          if (dmem_reads_q == 1) begin
            dmem_lat_min_q <= tick_q + 1 - dmem_req_tick_q;
            dmem_lat_max_q <= tick_q + 1 - dmem_req_tick_q;
          end else begin
            if ((tick_q + 1 - dmem_req_tick_q) < dmem_lat_min_q)
              dmem_lat_min_q <= tick_q + 1 - dmem_req_tick_q;
            if ((tick_q + 1 - dmem_req_tick_q) > dmem_lat_max_q)
              dmem_lat_max_q <= tick_q + 1 - dmem_req_tick_q;
          end
        end else begin
          dmem_wait_q <= dmem_wait_q - 8'd1;
        end
      end else if (dmem_line_req_valid && dmem_line_req_ready) begin
        if (dmem_line_req_write) begin
          // Full-line writeback. The D$ only writes back lines it allocated,
          // and allocation is gated on an in-range refill, so an out-of-range
          // writeback is reported rather than acted on.
          dmem_writes_q <= dmem_writes_q + 1;
          if (line_in_ram(dmem_line_req_addr)) begin
            for (int b = 0; b < LINE_BYTES; b = b + 1)
              dmem_bytes[({dmem_line_req_addr[31:4], 4'b0}) + b] <=
                dmem_line_req_wdata[(b << 3) +: 8];
          end else begin
            range_errors_q     <= range_errors_q + 1;
            range_error_addr_q <= dmem_line_req_addr;
          end
        end else begin
          dmem_reads_q    <= dmem_reads_q + 1;
          dmem_req_tick_q <= tick_q + 1;
          if (!line_in_ram(dmem_line_req_addr)) begin
            range_errors_q     <= range_errors_q + 1;
            range_error_addr_q <= dmem_line_req_addr;
          end
          dmem_addr_q <= dmem_line_req_addr;
          dmem_wait_q <= MEM_LATENCY[7:0] - 8'd1;
          dmem_busy_q <= 1'b1;
        end
      end
    end
  end

  // ------------------------------------------------------- IPC interval
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tick_q        <= 64'd0;
      ipc_cycles_q  <= 0;
      retired_q     <= 0;
      branches_q    <= 0;
      mispredicts_q <= 0;
      x10_q         <= 32'b0;
      ipc_frozen_q  <= 1'b0;
      x10_at_halt_q <= 32'b0;
      halt_pc_q     <= 32'b0;
      mix_alu_q <= 0; mix_load_q <= 0; mix_store_q <= 0; mix_branch_q <= 0;
      mix_jal_q <= 0; mix_jalr_q <= 0; mix_mul_q <= 0; mix_divrem_q <= 0;
      mix_other_q <= 0;
      no_issue_fire_q <= 0; no_issue_flush_q <= 0; no_issue_rob_q <= 0;
      no_issue_prf_q <= 0; no_issue_int_rs_q <= 0; no_issue_mul_rs_q <= 0;
      no_issue_div_rs_q <= 0; no_issue_branch_rs_q <= 0;
      no_issue_mem_rs_q <= 0; no_issue_lq_q <= 0; no_issue_sq_q <= 0;
      no_issue_frontend_q <= 0;
      div_accept_q <= 0; div_busy_q <= 0; div_head_wait_q <= 0;
      load_store_block_q <= 0;
      cond_events_q <= 0; jal_events_q <= 0; jalr_events_q <= 0;
      cond_mispredicts_q <= 0; jal_mispredicts_q <= 0; jalr_mispredicts_q <= 0;
      cond_recoveries_q <= 0; jump_recoveries_q <= 0; control_overlap_q <= 0;
    end else begin
      tick_q <= tick_q + 64'd1;
      if (!ipc_frozen_q) begin
        ipc_cycles_q <= ipc_cycles_q + 1;

        // This priority chain is intentionally exhaustive: its sum must equal
        // ipc_cycles_q and makes backend pressure visible without double-counting.
        if (u_dut.u_core.issue_fire) begin
          no_issue_fire_q <= no_issue_fire_q + 1;
        end else if (u_dut.u_core.global_flush) begin
          no_issue_flush_q <= no_issue_flush_q + 1;
        end else if (u_dut.u_core.frontend_iq_valid) begin
          if (!u_dut.u_core.rob_alloc_ready) begin
            no_issue_rob_q <= no_issue_rob_q + 1;
          end else if (u_dut.u_core.decoded.writes_rd &&
                       !u_dut.u_core.prf_alloc_ready) begin
            no_issue_prf_q <= no_issue_prf_q + 1;
          end else if (!u_dut.u_core.target_rs_ready) begin
            unique case (iq_opcode)
              7'h03: begin
                if (!u_dut.u_core.lq_alloc_ready) no_issue_lq_q <= no_issue_lq_q + 1;
                else no_issue_mem_rs_q <= no_issue_mem_rs_q + 1;
              end
              7'h23: begin
                if (!u_dut.u_core.sq_alloc_ready) no_issue_sq_q <= no_issue_sq_q + 1;
                else no_issue_mem_rs_q <= no_issue_mem_rs_q + 1;
              end
              7'h33: begin
                if (u_dut.u_core.decoded.instr[31:25] == 7'h01) begin
                  if (u_dut.u_core.decoded.instr[14:12] < 3'd4)
                    no_issue_mul_rs_q <= no_issue_mul_rs_q + 1;
                  else
                    no_issue_div_rs_q <= no_issue_div_rs_q + 1;
                end else begin
                  no_issue_int_rs_q <= no_issue_int_rs_q + 1;
                end
              end
              7'h63: no_issue_branch_rs_q <= no_issue_branch_rs_q + 1;
              default: no_issue_int_rs_q <= no_issue_int_rs_q + 1;
            endcase
          end else begin
            no_issue_frontend_q <= no_issue_frontend_q + 1;
          end
        end else begin
          no_issue_frontend_q <= no_issue_frontend_q + 1;
        end

        if (u_dut.u_core.div_issue_valid && u_dut.u_core.div_issue_ready)
          div_accept_q <= div_accept_q + 1;
        if (u_dut.u_core.div_issue_valid && !u_dut.u_core.div_issue_ready)
          div_busy_q <= div_busy_q + 1;
        if (u_dut.u_core.rob_commit_valid && !u_dut.u_core.rob_commit_ready &&
            (u_dut.u_core.rob_commit_instr[6:0] == 7'h33) &&
            (u_dut.u_core.rob_commit_instr[31:25] == 7'h01) &&
            (u_dut.u_core.rob_commit_instr[14:12] >= 3'd4))
          div_head_wait_q <= div_head_wait_q + 1;
        if (u_dut.u_core.u_lsu.load_select_found && u_dut.u_core.u_lsu.load_blocked)
          load_store_block_q <= load_store_block_q + 1;

        if (u_dut.u_core.branch_result_live) begin
          cond_events_q <= cond_events_q + 1;
          if (u_dut.u_core.branch_flush_candidate) begin
            cond_mispredicts_q <= cond_mispredicts_q + 1;
            cond_recoveries_q <= cond_recoveries_q + 1;
          end
          if (u_dut.u_core.alu_result_live && u_dut.u_core.alu_cdb_is_control)
            control_overlap_q <= control_overlap_q + 1;
        end
        if (u_dut.u_core.alu_result_live && u_dut.u_core.alu_cdb_is_control) begin
          if (jump_opcode == 7'h67) begin
            jalr_events_q <= jalr_events_q + 1;
            if (u_dut.u_core.jump_flush_candidate)
              jalr_mispredicts_q <= jalr_mispredicts_q + 1;
          end else begin
            jal_events_q <= jal_events_q + 1;
            if (u_dut.u_core.jump_flush_candidate)
              jal_mispredicts_q <= jal_mispredicts_q + 1;
          end
          if (u_dut.u_core.jump_flush_candidate) begin
            jump_recoveries_q <= jump_recoveries_q + 1;
          end
        end
        if (u_dut.u_core.branch_result_live ||
            (u_dut.u_core.alu_result_live && u_dut.u_core.alu_cdb_is_control))
          branches_q <= branches_q + int'(u_dut.u_core.branch_result_live) +
                        int'(u_dut.u_core.alu_result_live && u_dut.u_core.alu_cdb_is_control);
        if (u_dut.u_core.branch_flush_candidate || u_dut.u_core.jump_flush_candidate)
          mispredicts_q <= mispredicts_q + int'(u_dut.u_core.branch_flush_candidate) +
                           int'(u_dut.u_core.jump_flush_candidate);

        if (cf_trace_enable && u_dut.u_core.predictor_fetch_accept) begin
          cf_fetch_ghr_q[u_dut.u_core.predicted_ckpt_id] <= u_dut.u_core.u_predictor.dir_ghr;
          cf_fetch_ras_top_q[u_dut.u_core.predicted_ckpt_id] <= u_dut.u_core.u_predictor.ras_top;
          cf_fetch_align_tail_q[u_dut.u_core.predicted_ckpt_id] <= u_dut.u_core.u_predictor.align_tail;
          cf_fetch_btb_q[u_dut.u_core.predicted_ckpt_id] <= u_dut.u_core.u_predictor.btb_hit;
          $display("CF_FETCH t=%0d pc=%08x instr=%08x pred=%08x ptaken=%0b btb=%0b ghr=%02x ras_top=%0d align_tail=%0d ckpt=%0d",
                   tick_q, u_dut.u_core.predictor_pc,
                   imem_word(u_dut.u_core.predictor_pc),
                   u_dut.u_core.predicted_next_pc, u_dut.u_core.predicted_taken,
                   u_dut.u_core.u_predictor.btb_hit, u_dut.u_core.u_predictor.dir_ghr,
                   u_dut.u_core.u_predictor.ras_top, u_dut.u_core.u_predictor.align_tail,
                   u_dut.u_core.predicted_ckpt_id);
        end
        if (cf_trace_enable && u_dut.u_core.branch_result_live) begin
          $display("CF_EXEC t=%0d kind=BR pc=%08x instr=%08x tag=%0d ckpt=%0d pred=%08x actual=%08x taken=%0b miss=%0b recover=%0b fghr=%02x fras_top=%0d falign_tail=%0d fbtb=%0b",
                   tick_q, u_dut.u_core.bru_rob_pc, imem_word(u_dut.u_core.bru_rob_pc),
                   u_dut.u_core.bru_tag, u_dut.u_core.bru_rob_ckpt_id,
                   u_dut.u_core.bru_rob_predicted_pc, u_dut.u_core.bru_next_pc,
                   u_dut.u_core.bru_taken, u_dut.u_core.branch_flush_candidate,
                   u_dut.u_core.branch_flush_candidate,
                   cf_fetch_ghr_q[u_dut.u_core.bru_rob_ckpt_id],
                   cf_fetch_ras_top_q[u_dut.u_core.bru_rob_ckpt_id],
                   cf_fetch_align_tail_q[u_dut.u_core.bru_rob_ckpt_id],
                   cf_fetch_btb_q[u_dut.u_core.bru_rob_ckpt_id]);
        end
        if (cf_trace_enable && u_dut.u_core.alu_result_live &&
            u_dut.u_core.alu_cdb_is_control) begin
          $display("CF_EXEC t=%0d kind=%0s pc=%08x instr=%08x tag=%0d ckpt=%0d pred=%08x actual=%08x taken=1 miss=%0b recover=%0b fghr=%02x fras_top=%0d falign_tail=%0d fbtb=%0b",
                   tick_q, (jump_opcode == 7'h67) ? "JALR" : "JAL",
                   u_dut.u_core.jump_rob_pc, imem_word(u_dut.u_core.jump_rob_pc),
                   u_dut.u_core.wb_alu_tag, u_dut.u_core.jump_rob_ckpt_id,
                   u_dut.u_core.jump_rob_predicted_pc, u_dut.u_core.wb_alu_value,
                   u_dut.u_core.jump_flush_candidate, u_dut.u_core.jump_flush_candidate,
                   cf_fetch_ghr_q[u_dut.u_core.jump_rob_ckpt_id],
                   cf_fetch_ras_top_q[u_dut.u_core.jump_rob_ckpt_id],
                   cf_fetch_align_tail_q[u_dut.u_core.jump_rob_ckpt_id],
                   cf_fetch_btb_q[u_dut.u_core.jump_rob_ckpt_id]);
        end
        if (commit_valid) begin
          if (dbg_enable >= 1)
            $display("DBG t=%0d COMMIT pc=%08x instr=%08x rdv=%0b rd=%0d",
                     tick_q, commit_pc, commit_instr, commit_rd_valid,
                     commit_rd);
          if (commit_instr == HALT_INSN) begin
            // The HALT marker retires here: freeze the interval, keep the last
            // architectural x10 (HALT itself only writes the marker constant),
            // and stop counting retired instructions.
            ipc_frozen_q  <= 1'b1;
            x10_at_halt_q <= x10_q;
            halt_pc_q     <= commit_pc;
            $display("DBG t=%0d HALTFREEZE pc=%08x x10=%08x cycles=%0d retired=%0d",
                     tick_q, commit_pc, x10_q, ipc_cycles_q, retired_q);
          end else begin
            retired_q <= retired_q + 1;
            if (commit_rd_valid && (commit_rd == 5'd10))
              x10_q <= commit_rd_value;
            unique case (commit_opcode)
              7'h03: mix_load_q <= mix_load_q + 1;
              7'h23: mix_store_q <= mix_store_q + 1;
              7'h63: mix_branch_q <= mix_branch_q + 1;
              7'h6f: mix_jal_q <= mix_jal_q + 1;
              7'h67: mix_jalr_q <= mix_jalr_q + 1;
              7'h33: begin
                if (commit_instr[31:25] == 7'h01) begin
                  if (commit_instr[14:12] < 3'd4) mix_mul_q <= mix_mul_q + 1;
                  else mix_divrem_q <= mix_divrem_q + 1;
                end else begin
                  mix_alu_q <= mix_alu_q + 1;
                end
              end
              7'h13, 7'h17, 7'h37: mix_alu_q <= mix_alu_q + 1;
              default: mix_other_q <= mix_other_q + 1;
            endcase
            if (cf_trace_enable && ((commit_opcode == 7'h63) ||
                                    (commit_opcode == 7'h6f) ||
                                    (commit_opcode == 7'h67)))
              $display("CF_COMMIT t=%0d pc=%08x instr=%08x tag=%0d pred=%08x ckpt=%0d",
                       tick_q, commit_pc, commit_instr, u_dut.u_core.rob_commit_tag,
                       u_dut.u_core.u_rob.predicted_pc_q[u_dut.u_core.rob_commit_tag[3:0]],
                       u_dut.u_core.u_rob.predictor_ckpt_id_q[u_dut.u_core.rob_commit_tag[3:0]]);
          end
        end
      end
    end
  end

  // ------------------------------------------------------- architectural shadow
  always_ff @(posedge clk) begin
    if (rst_n && !ipc_frozen_q && commit_valid && commit_mem_valid) begin
      for (int b = 0; b < 4; b = b + 1)
        if (commit_mem_wstrb[b] && (commit_mem_addr + b) < MEM_BYTES)
          shadow_mem[commit_mem_addr + b] <=
            commit_mem_data[(b << 3) +: 8];
    end
  end

  // ------------------------------------------------------- optional tracing
  // +LSU_TRACE=1 logs LSU<->D$ handshakes and D$ state changes; +LSU_TRACE=2
  // logs a full per-cycle state line instead. Off by default; it exists so a
  // future deadlock can be localised without re-deriving the protocol.
  int unsigned dbg_enable;
  logic [2:0]  dbg_dstate_q;

  always_ff @(posedge clk) begin
    if (rst_n && (dbg_enable == 1)) begin
      if (u_dut.core_dmem_req_valid && u_dut.core_dmem_req_ready)
        $display("DBG t=%0d LSUREQ  write=%0b addr=%08x dstate=%0d",
                 tick_q, u_dut.core_dmem_req_write, u_dut.core_dmem_req_addr,
                 u_dut.u_dcache.state_q);
      if (u_dut.core_dmem_rsp_valid)
        $display("DBG t=%0d LUSRSP  data=%08x dstate=%0d", tick_q,
                 u_dut.core_dmem_rsp_data, u_dut.u_dcache.state_q);
      if (dmem_line_req_valid && dmem_line_req_ready)
        $display("DBG t=%0d MEMREQ  write=%0b addr=%08x dstate=%0d",
                 tick_q, dmem_line_req_write, dmem_line_req_addr,
                 u_dut.u_dcache.state_q);
      if (dmem_line_rsp_valid)
        $display("DBG t=%0d MEMRSP  addr=%08x dstate=%0d", tick_q,
                 dmem_addr_q, u_dut.u_dcache.state_q);
      if (u_dut.u_dcache.state_q !== dbg_dstate_q)
        $display("DBG t=%0d DSTATE  %0d -> %0d", tick_q, dbg_dstate_q,
                 u_dut.u_dcache.state_q);
      dbg_dstate_q <= u_dut.u_dcache.state_q;
    end
    if (rst_n && (dbg_enable == 2)) begin
      $display("DBG t=%0d ds=%0d reqv=%0b reqr=%0b reqw=%0b rsp=%0b rspd=%08x fl=%0b pend=%0b pdr=%0b pidx=%0d sel=%0b nm=%0b lq=%0d sq=%0d mrv=%0b mrr=%0b mrw=%0b",
               tick_q, u_dut.u_dcache.state_q, u_dut.core_dmem_req_valid,
               u_dut.core_dmem_req_ready, u_dut.core_dmem_req_write,
               u_dut.core_dmem_rsp_valid, u_dut.core_dmem_rsp_data,
               u_dut.u_core.global_flush, u_dut.u_core.u_lsu.pending_q,
               u_dut.u_core.u_lsu.pending_drop_q,
               u_dut.u_core.u_lsu.pending_index_q,
               u_dut.u_core.u_lsu.load_select_found,
               u_dut.u_core.u_lsu.load_needs_memory,
               u_dut.u_core.lq_count, u_dut.u_core.sq_count,
               dmem_line_req_valid, dmem_line_rsp_valid,
               dmem_line_req_write);
    end
  end

  // ------------------------------------------------------------------ run
  int unsigned watchdog;
  int unsigned timeout;
  int unsigned failures;
  int unsigned check_dmem_latency;
  int unsigned mem_mismatches;
  logic [31:0] mem_mismatch_addr;
  logic [31:0] expected_x10, expected_x10_mask;
  int i;
  string data_file, bench_name;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    // Storage is pre-cleared so that bytes outside the sparse image read as
    // zero, exactly as $readmemh leaves them; all registers take their reset
    // values from the negedge rst_n branch of their own always_ff.
    for (i = 0; i < MEM_BYTES; i = i + 1) begin
      imem_bytes[i] = 8'h00;
      dmem_bytes[i] = 8'h00;
    end
    watchdog         = 0;
    failures         = 0;
    mem_mismatches   = 0;
    mem_mismatch_addr = 32'b0;
    timeout          = DEFAULT_TIMEOUT;
    check_dmem_latency = 1;
    data_file        = "tests/benchmarks/median.data";
    bench_name       = "median";
    expected_x10     = 32'd0;
    expected_x10_mask = 32'h0000_00ff;
    void'($value$plusargs("DATA=%s", data_file));
    void'($value$plusargs("BENCH=%s", bench_name));
    void'($value$plusargs("EXPECT=%h", expected_x10));
    void'($value$plusargs("EXPECT_MASK=%h", expected_x10_mask));
    void'($value$plusargs("TIMEOUT=%d", timeout));
    void'($value$plusargs("CHECK_DMEM_LATENCY=%d", check_dmem_latency));
    dbg_enable = 0;
    void'($value$plusargs("LSU_TRACE=%d", dbg_enable));
    dbg_dstate_q = 3'd0;
    cf_trace_enable = 1'b0;
    void'($value$plusargs("CF_TRACE=%d", cf_trace_enable));

    $readmemh(data_file, imem_bytes);
    $readmemh(data_file, dmem_bytes);
    for (i = 0; i < MEM_BYTES; i = i + 1)
      shadow_mem[i] = dmem_bytes[i];

    repeat (5) @(negedge clk);
    rst_n = 1'b1;

    // Phase 1: reset deassertion through the architectural HALT commit.
    while (!ipc_frozen_q && !trap && (watchdog < timeout)) begin
      @(negedge clk);
      watchdog = watchdog + 1;
    end

    if (trap) begin
      $display("IPC_FAIL bench=%s reason=trap cycles=%0d retired=%0d",
               bench_name, ipc_cycles_q, retired_q);
      $fatal(1, "unexpected architectural trap");
    end
    if (!ipc_frozen_q) begin
      $display("TIMEOUT rob_count=%0d head_pc=%08x head_instr=%08x head_ready=%0b head_store=%0b commit_ready=%0b sq_count=%0d lq_count=%0d",
               u_dut.u_core.rob_count, u_dut.u_core.rob_commit_pc,
               u_dut.u_core.rob_commit_instr,
               u_dut.u_core.rob_commit_valid,
               u_dut.u_core.rob_commit_store,
               u_dut.u_core.rob_commit_ready, u_dut.u_core.sq_count,
               u_dut.u_core.lq_count);
      $display("TIMEOUT mem_occ=%0d mem_issue_valid=%0b mem_issue_ready=%0b dcache_state=%0d creq=%0b cready=%0b cwrite=%0b caddr=%08x",
               u_dut.u_core.mem_occupancy, u_dut.u_core.mem_issue_valid,
               u_dut.u_core.mem_issue_ready, u_dut.u_dcache.state_q,
               u_dut.core_dmem_req_valid, u_dut.core_dmem_req_ready,
               u_dut.core_dmem_req_write, u_dut.core_dmem_req_addr);
      $display("TIMEOUT icache_state=%0d ireq=%0b iready=%0b iaddr=%08x dreq=%0b dread=%0b dwr=%0b daddr=%08x dmem_busy=%0b dmem_wait=%0d",
               u_dut.u_icache.state_q, u_dut.core_imem_req_valid,
               u_dut.core_imem_req_ready, u_dut.core_imem_req_addr,
               dmem_line_req_valid, dmem_line_req_ready, dmem_line_req_write,
               dmem_line_req_addr, dmem_busy_q, dmem_wait_q);
      $display("TIMEOUT fq=%0d iq=%0d prf_free=%0d ilines=%0d dlines=%0d wb=%0d range_err=%0d",
               u_dut.u_core.fq_count, u_dut.u_core.iq_count,
               u_dut.u_core.prf_free_count, imem_reads_q, dmem_reads_q,
               dmem_writes_q, range_errors_q);
      $display("TIMEOUT lsu pending=%0b drop=%0b pidx=%0d sel=%0b blocked=%0b needs_mem=%0b fwd=%0b",
               u_dut.u_core.u_lsu.pending_q,
               u_dut.u_core.u_lsu.pending_drop_q,
               u_dut.u_core.u_lsu.pending_index_q,
               u_dut.u_core.u_lsu.load_select_found,
               u_dut.u_core.u_lsu.load_blocked,
               u_dut.u_core.u_lsu.load_needs_memory,
               u_dut.u_core.u_lsu.load_fully_forwarded);
      for (int k = 0; k < 8; k = k + 1)
        $display("TIMEOUT LQ[%0d] valid=%0b tag=%0d addr=%08x aready=%0b sent=%0b rready=%0b",
                 k, u_dut.u_core.u_lsu.lq_valid_q[k],
                 u_dut.u_core.u_lsu.lq_tag_q[k],
                 u_dut.u_core.u_lsu.lq_address_q[k],
                 u_dut.u_core.u_lsu.lq_address_ready_q[k],
                 u_dut.u_core.u_lsu.lq_sent_q[k],
                 u_dut.u_core.u_lsu.lq_result_ready_q[k]);
      for (int k = 0; k < 8; k = k + 1)
        $display("TIMEOUT SQ[%0d] valid=%0b tag=%0d addr=%08x aready=%0b dready=%0b",
                 k, u_dut.u_core.u_lsu.sq_valid_q[k],
                 u_dut.u_core.u_lsu.sq_tag_q[k],
                 u_dut.u_core.u_lsu.sq_address_q[k],
                 u_dut.u_core.u_lsu.sq_address_ready_q[k],
                 u_dut.u_core.u_lsu.sq_data_ready_q[k]);
      $display("IPC_FAIL bench=%s reason=timeout cycles=%0d retired=%0d rob_count=%0d head_pc=%08x",
               bench_name, ipc_cycles_q, retired_q,
               u_dut.u_core.rob_count, u_dut.u_core.rob_commit_pc);
      $fatal(1, "timeout before the HALT commit");
    end

    // Phase 2: keep running until the D$ flush raises halted_o. Uncounted.
    while (!halted && !trap && (watchdog < timeout)) begin
      @(negedge clk);
      watchdog = watchdog + 1;
    end

    if (trap) begin
      $display("IPC_FAIL bench=%s reason=trap cycles=%0d retired=%0d",
               bench_name, ipc_cycles_q, retired_q);
      $fatal(1, "architectural trap during the drain phase");
    end
    if (!halted) begin
      $display("IPC_FAIL bench=%s reason=timeout cycles=%0d retired=%0d dcache_state=%0d",
               bench_name, ipc_cycles_q, retired_q, u_dut.u_dcache.state_q);
      $fatal(1, "timeout before halted_o");
    end

    if (range_errors_q != 0) begin
      failures = failures + 1;
      $display("CHECK range FAIL first=%08x count=%0d",
               range_error_addr_q, range_errors_q);
    end
    if ((x10_at_halt_q & expected_x10_mask) !==
        (expected_x10 & expected_x10_mask)) begin
      failures = failures + 1;
      $display("CHECK x10 FAIL got=%08x expect=%08x mask=%08x halt_pc=%08x",
               x10_at_halt_q, expected_x10, expected_x10_mask, halt_pc_q);
    end
    if (halt_pc_q !== HALT_PC) begin
      failures = failures + 1;
      $display("CHECK halt_pc FAIL got=%08x expect=%08x", halt_pc_q, HALT_PC);
    end
    if (imem_lat_min_q != MEM_LATENCY || imem_lat_max_q != MEM_LATENCY) begin
      failures = failures + 1;
      $display("CHECK imem_latency FAIL min=%0d max=%0d expect=%0d",
               imem_lat_min_q, imem_lat_max_q, MEM_LATENCY);
    end
    if (check_dmem_latency &&
        (dmem_lat_min_q != MEM_LATENCY || dmem_lat_max_q != MEM_LATENCY)) begin
      failures = failures + 1;
      $display("CHECK dmem_latency FAIL min=%0d max=%0d expect=%0d",
               dmem_lat_min_q, dmem_lat_max_q, MEM_LATENCY);
    end
    for (i = 0; i < MEM_BYTES; i = i + 1) begin
      if (dmem_bytes[i] !== shadow_mem[i]) begin
        if (mem_mismatches == 0) mem_mismatch_addr = i;
        mem_mismatches = mem_mismatches + 1;
      end
    end
    if (mem_mismatches != 0) begin
      failures = failures + 1;
      $display("CHECK dmem_shadow FAIL first=%08x count=%0d",
               mem_mismatch_addr, mem_mismatches);
    end
    if (retired_q == 0) begin
      failures = failures + 1;
      $display("CHECK retired FAIL no retired instructions");
    end
    if ((mix_alu_q + mix_load_q + mix_store_q + mix_branch_q + mix_jal_q +
         mix_jalr_q + mix_mul_q + mix_divrem_q + mix_other_q) != retired_q) begin
      failures = failures + 1;
      $display("CHECK mix FAIL sum=%0d retired=%0d",
               mix_alu_q + mix_load_q + mix_store_q + mix_branch_q + mix_jal_q +
               mix_jalr_q + mix_mul_q + mix_divrem_q + mix_other_q, retired_q);
    end
    if ((no_issue_fire_q + no_issue_flush_q + no_issue_rob_q + no_issue_prf_q +
         no_issue_int_rs_q + no_issue_mul_rs_q + no_issue_div_rs_q +
         no_issue_branch_rs_q + no_issue_mem_rs_q + no_issue_lq_q +
         no_issue_sq_q + no_issue_frontend_q) != ipc_cycles_q) begin
      failures = failures + 1;
      $display("CHECK issue_profile FAIL sum=%0d cycles=%0d",
               no_issue_fire_q + no_issue_flush_q + no_issue_rob_q + no_issue_prf_q +
               no_issue_int_rs_q + no_issue_mul_rs_q + no_issue_div_rs_q +
               no_issue_branch_rs_q + no_issue_mem_rs_q + no_issue_lq_q +
               no_issue_sq_q + no_issue_frontend_q, ipc_cycles_q);
    end
    if ((cond_events_q + jal_events_q + jalr_events_q) != branches_q ||
        (cond_mispredicts_q + jal_mispredicts_q + jalr_mispredicts_q) !=
        mispredicts_q) begin
      failures = failures + 1;
      $display("CHECK control_profile FAIL events=%0d/%0d mispredicts=%0d/%0d",
               cond_events_q + jal_events_q + jalr_events_q, branches_q,
               cond_mispredicts_q + jal_mispredicts_q + jalr_mispredicts_q,
               mispredicts_q);
    end

    if (failures != 0) begin
      $display("IPC_FAIL bench=%s reason=check cycles=%0d retired=%0d halt_pc=%08x x10=%08x failures=%0d",
               bench_name, ipc_cycles_q, retired_q, halt_pc_q, x10_at_halt_q,
               failures);
      $fatal(1, "FAIL tb_core_ipc bench=%s failures=%0d", bench_name, failures);
    end

    // Raw counters only. Derived quantities (IPC, branch accuracy) are the
    // runner's job so that there is a single place where they are computed.
    $display("IPC_RESULT bench=%s cycles=%0d retired=%0d branches=%0d mispredicts=%0d x10=%08x expect=%08x expect_mask=%08x lat_i=%0d lat_d=%0d ilines=%0d dlines=%0d wb=%0d clock=%0d",
              bench_name, ipc_cycles_q, retired_q, branches_q, mispredicts_q,
              x10_at_halt_q, expected_x10, expected_x10_mask,
              imem_lat_min_q, dmem_lat_min_q,
              imem_reads_q, dmem_reads_q, dmem_writes_q, tick_q);
    $display("IPC_PROFILE alu=%0d load=%0d store=%0d branch=%0d jal=%0d jalr=%0d mul=%0d divrem=%0d other=%0d issue=%0d noissue_flush=%0d noissue_rob=%0d noissue_prf=%0d noissue_int_rs=%0d noissue_mul_rs=%0d noissue_div_rs=%0d noissue_branch_rs=%0d noissue_mem_rs=%0d noissue_lq=%0d noissue_sq=%0d noissue_frontend=%0d div_accept=%0d div_busy=%0d div_head_wait=%0d load_store_block=%0d cond_events=%0d jal_events=%0d jalr_events=%0d cond_mispredicts=%0d jal_mispredicts=%0d jalr_mispredicts=%0d cond_recoveries=%0d jump_recoveries=%0d control_overlap=%0d",
             mix_alu_q, mix_load_q, mix_store_q, mix_branch_q, mix_jal_q,
             mix_jalr_q, mix_mul_q, mix_divrem_q, mix_other_q,
             no_issue_fire_q, no_issue_flush_q, no_issue_rob_q, no_issue_prf_q,
             no_issue_int_rs_q, no_issue_mul_rs_q, no_issue_div_rs_q,
             no_issue_branch_rs_q, no_issue_mem_rs_q, no_issue_lq_q,
             no_issue_sq_q, no_issue_frontend_q, div_accept_q, div_busy_q,
             div_head_wait_q, load_store_block_q, cond_events_q, jal_events_q,
             jalr_events_q, cond_mispredicts_q, jal_mispredicts_q,
             jalr_mispredicts_q, cond_recoveries_q, jump_recoveries_q,
             control_overlap_q);
    $finish;
  end
endmodule
