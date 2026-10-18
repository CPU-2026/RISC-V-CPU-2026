module rv32_prf #(
  parameter int unsigned PRF_DEPTH = rv32_pkg::PRF_ENTRIES,
  parameter int unsigned ROB_DEPTH = rv32_pkg::ROB_ENTRIES,
  parameter int unsigned WRITEBACK_PORTS = 4
) (
  input  logic                       clkInput,
  input  logic                       rstNInput,
  input logic freezeInput,

  input  rv32_pkg::prf_allocation_input_t allocationInput,
  output logic                       allocReadyOutput,
  output rv32_pkg::phy_tag_t         allocPhyOutput,

  input  rv32_pkg::prf_free_input_t  freeInput,

  // Recovery shares the four-beat cursor with RAT/RAS. Only younger newPhy
  // registers are returned, in age order. The cursor retains PRE-squash count:
  // the ROB tail is already rewound, but its payload stays frozen until done.
  input  rv32_pkg::prf_restore_input_t restoreInput,
  input  rv32_pkg::recovery_step_t recoveryInput,
  input  logic [$clog2(ROB_DEPTH+1)-1:0] restoreCountInput,
  input  rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayInput,

  input  rv32_pkg::prf_read_input_t [2:0] readInput,
  output rv32_pkg::prf_read_output_t [2:0] readOutput,

  input  rv32_pkg::cdb_result_t [WRITEBACK_PORTS-1:0] writebackInput,

  output logic [PRF_DEPTH-1:0]       readyVectorOutput,
  output logic [$clog2(PRF_DEPTH+1)-1:0] freeCountOutput
);
  import rv32_pkg::*;

  localparam int unsigned SLOT_W = $clog2(PRF_DEPTH);
  localparam int unsigned SEQ_W = SLOT_W + 1;
  localparam int unsigned COUNT_W = $clog2(PRF_DEPTH+1);
  localparam int unsigned RECYCLE_W = $clog2(RECOVERY_WIDTH+1);
  typedef logic [SEQ_W-1:0] free_seq_t;
  typedef logic [(RECOVERY_WIDTH > 1 ? $clog2(RECOVERY_WIDTH) : 1)-1:0] recycle_index_t;

  logic [31:0] valueInner [PRF_DEPTH];
  logic [PRF_DEPTH-1:0] readyInner;
  phy_tag_t freeListInner [PRF_DEPTH];
  free_seq_t freeHeadInner, freeTailInner, recycleTailInner;
  logic [SLOT_W-1:0] freeHeadSlotInner, freeTailSlotInner;
  phy_tag_t recyclePhyInner [RECOVERY_WIDTH];
  logic [SLOT_W-1:0] recycleSlotInner [RECOVERY_WIDTH];
  logic [RECYCLE_W-1:0] recycleCountInner;
  phy_tag_t selectedPhyInner;
  logic selectedValidInner;
  logic allocationFireInner;
  integer seqIndexInner;

  function automatic free_seq_t free_seq_next(input free_seq_t seq);
    if (seq[SLOT_W-1:0] == SLOT_W'(PRF_DEPTH-1))
      free_seq_next = {~seq[SEQ_W-1], {SLOT_W{1'b0}}};
    else
      free_seq_next = seq + free_seq_t'(1);
  endfunction

  assign freeHeadSlotInner = freeHeadInner[SLOT_W-1:0];
  assign freeTailSlotInner = freeTailInner[SLOT_W-1:0];
  assign allocationFireInner = allocationInput.valid && allocReadyOutput;

  always_comb begin
    // Non-power-of-two ring: slots 48..63 are skipped at depth48. The epoch
    // contributes PRF_DEPTH, not 2**SLOT_W, to the occupied distance.
    freeCountOutput = COUNT_W'(freeTailSlotInner) - COUNT_W'(freeHeadSlotInner);
    if (freeHeadInner[SEQ_W-1] != freeTailInner[SEQ_W-1])
      freeCountOutput = freeCountOutput + COUNT_W'(PRF_DEPTH);
    selectedValidInner = freeHeadInner != freeTailInner;
    selectedPhyInner = selectedValidInner ? freeListInner[freeHeadSlotInner] : '0;
    // Squash owns recovery: only a non-squash cycle may pop. issue_fire already
    // excludes global_flush upstream, so this is a local invariant guard.
    allocReadyOutput = !restoreInput.valid && !recoveryInput.active && selectedValidInner;
    allocPhyOutput = selectedPhyInner;

    readOutput[0].ready = (readInput[0].physicalRegister == '0) ? 1'b1 : readyInner[readInput[0].physicalRegister];
    readOutput[0].value = (readInput[0].physicalRegister == '0) ? 32'b0 : valueInner[readInput[0].physicalRegister];
    readOutput[1].ready = (readInput[1].physicalRegister == '0) ? 1'b1 : readyInner[readInput[1].physicalRegister];
    readOutput[1].value = (readInput[1].physicalRegister == '0) ? 32'b0 : valueInner[readInput[1].physicalRegister];
    readOutput[2].ready = (readInput[2].physicalRegister == '0) ? 1'b1 : readyInner[readInput[2].physicalRegister];
    readOutput[2].value = (readInput[2].physicalRegister == '0) ? 32'b0 : valueInner[readInput[2].physicalRegister];
    readyVectorOutput = readyInner;

  end

  // Replay is ordered oldest->youngest, at most RECOVERY_WIDTH appends per
  // beat. Retirement is stalled throughout recovery, so normal oldPhy recycling
  // is a separate path. Selection always uses the old FIFO.
  always_comb begin
    recycleCountInner = '0;
    recycleTailInner = freeTailInner;
    for (int k = 0; k < RECOVERY_WIDTH; k++) begin
      recyclePhyInner[k] = '0;
      recycleSlotInner[k] = '0;
    end
    if (recoveryInput.active) begin
      for (int lane = 0; lane < RECOVERY_WIDTH; lane++) begin
        if ((int'(recoveryInput.offset) + lane < ROB_DEPTH) &&
            (int'(recoveryInput.offset) + lane < int'(recoveryInput.liveCount))) begin
          if ((replayInput[lane].robTag ==
               recoveryInput.nextTag + rob_tag_t'(lane)) &&
              rob_is_younger(replayInput[lane].robTag,
                             recoveryInput.squashTag) &&
              (replayInput[lane].newPhy != '0)) begin
            recyclePhyInner[recycle_index_t'(recycleCountInner)] = replayInput[lane].newPhy;
            recycleSlotInner[recycle_index_t'(recycleCountInner)] = recycleTailInner[SLOT_W-1:0];
            recycleTailInner = free_seq_next(recycleTailInner);
            recycleCountInner = recycleCountInner + RECYCLE_W'(1);
          end
        end
      end
    end
    if (!restoreInput.valid && !recoveryInput.active && freeInput.valid && freeInput.physicalRegister != '0) begin
      recyclePhyInner[recycle_index_t'(recycleCountInner)] = freeInput.physicalRegister;
      recycleSlotInner[recycle_index_t'(recycleCountInner)] = recycleTailInner[SLOT_W-1:0];
      recycleTailInner = free_seq_next(recycleTailInner);
      recycleCountInner = recycleCountInner + RECYCLE_W'(1);
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      readyInner <= '0;
      freeHeadInner <= '0;
      freeTailInner <= free_seq_t'(PRF_DEPTH-ARCH_REGS);
      for (seqIndexInner = 0; seqIndexInner < PRF_DEPTH; seqIndexInner = seqIndexInner + 1)
        valueInner[seqIndexInner] <= 32'b0;
      for (seqIndexInner = 0; seqIndexInner < ARCH_REGS; seqIndexInner = seqIndexInner + 1)
        readyInner[seqIndexInner] <= 1'b1;
      for (seqIndexInner = 0; seqIndexInner < PRF_DEPTH; seqIndexInner = seqIndexInner + 1)
        freeListInner[seqIndexInner] <= seqIndexInner < PRF_DEPTH-ARCH_REGS ?
            phy_tag_t'(ARCH_REGS+seqIndexInner) : phy_tag_t'(0);
    end else if (!freezeInput) begin
      if (allocationFireInner)
        freeHeadInner <= free_seq_next(freeHeadInner);
      if (recycleCountInner != 0)
        freeTailInner <= recycleTailInner;
      for (int k = 0; k < RECOVERY_WIDTH; k++)
        if (k < int'(recycleCountInner))
          freeListInner[recycleSlotInner[k]] <= recyclePhyInner[k];

      if (allocationFireInner) begin
        valueInner[selectedPhyInner] <= allocationInput.value;
        readyInner[selectedPhyInner] <= allocationInput.valueValid;
      end

      for (int portIndex = 0; portIndex < WRITEBACK_PORTS; portIndex++) begin
        if (writebackInput[portIndex].valid && (writebackInput[portIndex].phyTag != '0)) begin
          valueInner[writebackInput[portIndex].phyTag] <= writebackInput[portIndex].value;
          readyInner[writebackInput[portIndex].phyTag] <= 1'b1;
        end
      end

      valueInner[0] <= 32'b0;
      readyInner[0] <= 1'b1;
    end
  end

`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    // Local assertion scratch only; no observation bitmap in the datapath.
    logic [PRF_DEPTH-1:0] freeMembership;
    free_seq_t scanSeq;
    freeMembership = '0;
    scanSeq = freeHeadInner;
    if (restoreInput.valid)
      assert (int'(restoreCountInput) <= ROB_DEPTH) else $fatal(1, "invalid pre-squash ROB count");
    for (int age = 0; age < PRF_DEPTH; age++) begin
      if (age < int'(freeCountOutput)) begin
        freeMembership[freeListInner[scanSeq[SLOT_W-1:0]]] = 1'b1;
        scanSeq = free_seq_next(scanSeq);
      end
    end
    assert (int'(freeHeadSlotInner) < PRF_DEPTH && int'(freeTailSlotInner) < PRF_DEPTH)
      else $fatal(1, "PRF FIFO entered a padded slot");
    assert (!freeMembership[0] && $countones(freeMembership) == int'(freeCountOutput))
      else $fatal(1, "PRF FIFO contains P0 or duplicate registers");
    assert (int'(freeCountOutput) - int'(allocationFireInner) +
            int'(recycleCountInner) <= PRF_DEPTH)
      else $fatal(1, "PRF FIFO overflow");
    for (int k = 0; k < RECOVERY_WIDTH; k++) if (k < int'(recycleCountInner)) begin
      assert (recyclePhyInner[k] != 0 && int'(recyclePhyInner[k]) < PRF_DEPTH &&
              !freeMembership[recyclePhyInner[k]]) else $fatal(1, "PRF duplicate/invalid release");
      for (int j = 0; j < k; j++)
        assert (recyclePhyInner[k] != recyclePhyInner[j])
          else $fatal(1, "PRF duplicate batch release");
    end
  end
`endif
endmodule
