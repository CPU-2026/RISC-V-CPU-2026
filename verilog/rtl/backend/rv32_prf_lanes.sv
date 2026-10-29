// Array-port PRF. Preview is ranked by physical allocation, NOT instruction
// lane, and depends only on old FIFO state. Never feed a fire-dependent preview
// back into the rename planner. Retirement/replay appends are next-cycle credit.
module rv32_prf_lanes #(
  parameter int unsigned LANES = 4,
  parameter int unsigned PRF_DEPTH = rv32_pkg::PRF_ENTRIES,
  parameter int unsigned ROB_DEPTH = rv32_pkg::ROB_ENTRIES,
  parameter int unsigned WRITEBACK_PORTS = 2,
  parameter int unsigned COMMIT_WIDTH = 2,
  parameter int unsigned READ_PORTS = 2*LANES
) (
  input logic clkInput, rstNInput, freezeInput,
  input rv32_pkg::prf_allocation_input_t [LANES-1:0] allocationInput,
  output logic [LANES-1:0] previewReadyOutput,
  output rv32_pkg::phy_tag_t [LANES-1:0] previewPhyOutput,
  output logic [LANES-1:0] allocationFireOutput,
  output rv32_pkg::phy_tag_t [LANES-1:0] allocationPhyOutput,
  input rv32_pkg::prf_free_input_t [COMMIT_WIDTH-1:0] freeInput,
  input rv32_pkg::prf_restore_input_t restoreInput,
  input rv32_pkg::recovery_step_t recoveryInput,
  input logic [$clog2(ROB_DEPTH+1)-1:0] restoreCountInput,
  input rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayInput,
  input rv32_pkg::prf_read_input_t [READ_PORTS-1:0] readInput,
  output rv32_pkg::prf_read_output_t [READ_PORTS-1:0] readOutput,
  input rv32_pkg::cdb_result_t [WRITEBACK_PORTS-1:0] writebackInput,
  output logic [PRF_DEPTH-1:0] readyVectorOutput,
  output logic [$clog2(PRF_DEPTH+1)-1:0] freeCountOutput
);
  import rv32_pkg::*;
  localparam int SLOT_W = $clog2(PRF_DEPTH);
  localparam int SEQ_W = SLOT_W+1;
  localparam int COUNT_W = $clog2(PRF_DEPTH+1);
  localparam int RECYCLE_W = $clog2(RECOVERY_WIDTH+1);
  localparam int VALUE_WRITERS = LANES+WRITEBACK_PORTS;
  typedef logic [SEQ_W-1:0] free_seq_t;
  typedef logic [(RECOVERY_WIDTH > 1 ? $clog2(RECOVERY_WIDTH) : 1)-1:0] recycle_index_t;
  if (LANES != 1 && LANES != 2 && LANES != 4) begin : g_invalid_lanes
    initial $fatal(1, "PRF LANES must be 1, 2 or 4");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2 && COMMIT_WIDTH != 4) begin : g_invalid_commit
    initial $fatal(1, "PRF COMMIT_WIDTH must be 1, 2 or 4");
  end
  if (PRF_DEPTH <= ARCH_REGS || PRF_DEPTH > 2**PHY_TAG_W) begin : g_invalid_depth
    initial $fatal(1, "PRF lane capacity outside physical identity range");
  end
  logic [31:0] valueInner [PRF_DEPTH];
  logic [PRF_DEPTH-1:0] readyInner;
  phy_tag_t freeListInner [PRF_DEPTH];
  free_seq_t freeHeadInner, freeTailInner, allocatedHeadInner, recycleTailInner;
  phy_tag_t recyclePhyInner [RECOVERY_WIDTH];
  logic [SLOT_W-1:0] recycleSlotInner [RECOVERY_WIDTH];
  logic [RECYCLE_W-1:0] recycleCountInner;
  logic [$clog2(LANES+1)-1:0] allocatedCountInner;

  function automatic free_seq_t free_seq_next(input free_seq_t seq);
    if (seq[SLOT_W-1:0] == SLOT_W'(PRF_DEPTH-1))
      return {~seq[SEQ_W-1], {SLOT_W{1'b0}}};
    return seq + free_seq_t'(1);
  endfunction
  always_comb begin : old_credit_preview
    free_seq_t cursor;
    cursor = freeHeadInner;
    freeCountOutput = COUNT_W'(freeTailInner[SLOT_W-1:0]) - COUNT_W'(freeHeadInner[SLOT_W-1:0]);
    if (freeHeadInner[SEQ_W-1] != freeTailInner[SEQ_W-1])
      freeCountOutput = freeCountOutput + COUNT_W'(PRF_DEPTH);
    for (int rank = 0; rank < LANES; rank++) begin
      previewReadyOutput[rank] = !freezeInput && !restoreInput.valid && !recoveryInput.active && int'(freeCountOutput) > rank;
      previewPhyOutput[rank] = previewReadyOutput[rank] ? freeListInner[cursor[SLOT_W-1:0]] : '0;
      cursor = free_seq_next(cursor);
    end
  end
  always_comb begin : consume_by_destination_rank
    int used;
    used = 0;
    allocatedHeadInner = freeHeadInner;
    allocationFireOutput = '0;
    allocationPhyOutput = '0;
    for (int lane = 0; lane < LANES; lane++) begin
      if (!freezeInput && !restoreInput.valid && !recoveryInput.active &&
          allocationInput[lane].valid && used < int'(freeCountOutput)) begin
        allocationFireOutput[lane] = 1'b1;
        allocationPhyOutput[lane] = freeListInner[allocatedHeadInner[SLOT_W-1:0]];
        allocatedHeadInner = free_seq_next(allocatedHeadInner);
        used++;
      end
    end
    allocatedCountInner = $bits(allocatedCountInner)'(used);
  end
  for (genvar portIndex = 0; portIndex < READ_PORTS; portIndex++) begin : g_read
    assign readOutput[portIndex].ready = readInput[portIndex].physicalRegister == 0 ? 1'b1 : readyInner[readInput[portIndex].physicalRegister];
    assign readOutput[portIndex].value = readInput[portIndex].physicalRegister == 0 ? '0 : valueInner[readInput[portIndex].physicalRegister];
  end
  assign readyVectorOutput = readyInner;

  always_comb begin : release_old_physical
    recycleCountInner = '0;
    recycleTailInner = freeTailInner;
    for (int k = 0; k < RECOVERY_WIDTH; k++) begin
      recyclePhyInner[k] = '0;
      recycleSlotInner[k] = '0;
    end
    if (recoveryInput.active) begin
      for (int lane = 0; lane < RECOVERY_WIDTH; lane++) begin
        if (int'(recoveryInput.offset)+lane < ROB_DEPTH &&
            int'(recoveryInput.offset)+lane < int'(recoveryInput.liveCount) &&
            replayInput[lane].robTag == recoveryInput.nextTag+rob_tag_t'(lane) &&
            rob_is_younger(replayInput[lane].robTag, recoveryInput.squashTag) && replayInput[lane].newPhy != 0) begin
          recyclePhyInner[recycle_index_t'(recycleCountInner)] = replayInput[lane].newPhy;
          recycleSlotInner[recycle_index_t'(recycleCountInner)] = recycleTailInner[SLOT_W-1:0];
          recycleTailInner = free_seq_next(recycleTailInner);
          recycleCountInner++;
        end
      end
    end
    for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
      if (!restoreInput.valid && !recoveryInput.active && freeInput[lane].valid && freeInput[lane].physicalRegister != 0) begin
        recyclePhyInner[recycle_index_t'(recycleCountInner)] = freeInput[lane].physicalRegister;
        recycleSlotInner[recycle_index_t'(recycleCountInner)] = recycleTailInner[SLOT_W-1:0];
        recycleTailInner = free_seq_next(recycleTailInner);
        recycleCountInner++;
      end
    end
  end
  // Keep the production masked-OR writer topology: higher WB port > all
  // allocations; amongst allocations the younger lane wins (normally unique).
  for (genvar row = 0; row < PRF_DEPTH; row++) begin : g_value_write
    logic [VALUE_WRITERS-1:0] hit, winner;
    logic [31:0] data;
    logic isReady;
    for (genvar lane = 0; lane < LANES; lane++) begin : g_alloc_hit
      assign hit[lane] = row != 0 && allocationFireOutput[lane] && allocationPhyOutput[lane] == phy_tag_t'(row);
    end
    for (genvar portIndex = 0; portIndex < WRITEBACK_PORTS; portIndex++) begin : g_wb_hit
      assign hit[portIndex+LANES] = row != 0 && writebackInput[portIndex].valid && writebackInput[portIndex].phyTag == phy_tag_t'(row);
    end
    always_comb begin
      winner = '0;
      for (int writer = 0; writer < VALUE_WRITERS; writer++) begin
        logic later;
        later = 1'b0;
        for (int peer = writer+1; peer < VALUE_WRITERS; peer++) later |= hit[peer];
        winner[writer] = hit[writer] && !later;
      end
      data = '0;
      isReady = 1'b0;
      for (int lane = 0; lane < LANES; lane++) begin
        data |= allocationInput[lane].value & {32{winner[lane]}};
        isReady |= allocationInput[lane].valueValid && winner[lane];
      end
      for (int portIndex = 0; portIndex < WRITEBACK_PORTS; portIndex++) begin
        data |= writebackInput[portIndex].value & {32{winner[portIndex+LANES]}};
        isReady |= winner[portIndex+LANES];
      end
    end
    always_ff @(posedge clkInput or negedge rstNInput) begin
      if (!rstNInput) begin
        valueInner[row] <= '0;
        readyInner[row] <= row < ARCH_REGS;
      end else if (!freezeInput) begin
        if (row == 0) begin valueInner[row] <= '0; readyInner[row] <= 1'b1; end
        else if (|hit) begin valueInner[row] <= data; readyInner[row] <= isReady; end
      end
    end
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      freeHeadInner <= '0;
      freeTailInner <= free_seq_t'(PRF_DEPTH-ARCH_REGS);
      for (int k = 0; k < PRF_DEPTH; k++)
        freeListInner[k] <= k < PRF_DEPTH-ARCH_REGS ? phy_tag_t'(ARCH_REGS+k) : '0;
    end else if (!freezeInput) begin
      if (allocatedCountInner != 0) freeHeadInner <= allocatedHeadInner;
      if (recycleCountInner != 0) freeTailInner <= recycleTailInner;
      for (int k = 0; k < RECOVERY_WIDTH; k++)
        if (k < int'(recycleCountInner)) freeListInner[recycleSlotInner[k]] <= recyclePhyInner[k];
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    logic [PRF_DEPTH-1:0] membership;
    free_seq_t cursor;
    membership = '0;
    cursor = freeHeadInner;
    for (int age = 0; age < PRF_DEPTH; age++) if (age < int'(freeCountOutput)) begin
      membership[freeListInner[cursor[SLOT_W-1:0]]] = 1'b1;
      cursor = free_seq_next(cursor);
    end
    assert (!membership[0] && $countones(membership) == int'(freeCountOutput))
      else $fatal(1, "lane PRF free FIFO duplicate/P0");
    assert (int'(freeHeadInner[SLOT_W-1:0]) < PRF_DEPTH && int'(freeTailInner[SLOT_W-1:0]) < PRF_DEPTH)
      else $fatal(1, "lane PRF FIFO padded slot");
    assert (int'(freeCountOutput) >= int'(allocatedCountInner) &&
            int'(freeCountOutput)-int'(allocatedCountInner)+int'(recycleCountInner) <= PRF_DEPTH)
      else $fatal(1, "lane PRF credit overflow");
    if (restoreInput.valid) assert (int'(restoreCountInput) <= ROB_DEPTH)
      else $fatal(1, "lane PRF invalid pre-squash count");
    for (int k = 0; k < RECOVERY_WIDTH; k++) if (k < int'(recycleCountInner)) begin
      assert (recyclePhyInner[k] != 0 && int'(recyclePhyInner[k]) < PRF_DEPTH && !membership[recyclePhyInner[k]])
        else $fatal(1, "lane PRF duplicate/invalid release");
      for (int j = 0; j < k; j++) assert (recyclePhyInner[k] != recyclePhyInner[j])
        else $fatal(1, "lane PRF duplicate batch release");
    end
    for (int lane = 0; lane < LANES; lane++) for (int older = 0; older < lane; older++)
      assert (!allocationFireOutput[lane] || !allocationFireOutput[older] || allocationPhyOutput[lane] != allocationPhyOutput[older])
        else $fatal(1, "lane PRF duplicate allocation");
  end
`endif
endmodule
