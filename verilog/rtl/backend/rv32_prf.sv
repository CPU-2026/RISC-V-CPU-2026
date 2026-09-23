module rv32_prf #(
  parameter int unsigned PRF_DEPTH = rv32_pkg::PRF_ENTRIES,
  parameter int unsigned ROB_DEPTH = rv32_pkg::ROB_ENTRIES
) (
  input  logic                       clkInput,
  input  logic                       rstNInput,

  input  rv32_pkg::prf_allocation_input_t allocationInput,
  output logic                       allocReadyOutput,
  output rv32_pkg::phy_tag_t         allocPhyOutput,

  input  rv32_pkg::prf_free_input_t  freeInput,

  // Recovery is ROB window replay -- the same window rv32_rat consumes. Only
  // the entries strictly younger than restoreTagInput are recycled; the boundaryInput
  // itself and everything older keep their physical registers. restoreCountInput
  // bounds the window to the live entries, so a stale tag left in a slot beyond
  // the ROB tail can never be replayed.
  input  rv32_pkg::prf_restore_input_t restoreInput,
  input  logic [$clog2(ROB_DEPTH+1)-1:0] restoreCountInput,
  input  rv32_pkg::rob_replay_entry_t [ROB_DEPTH-1:0] replayInput,

  input  rv32_pkg::prf_read_input_t [2:0] readInput,
  output rv32_pkg::prf_read_output_t [2:0] readOutput,

  input  rv32_pkg::cdb_result_t [3:0] writebackInput,

  output logic [PRF_DEPTH-1:0]       readyVectorOutput,
  output logic [$clog2(PRF_DEPTH+1)-1:0] freeCountOutput
);
  import rv32_pkg::*;

  localparam rob_tag_t ROB_AGE_MASK = '1;
  localparam rob_tag_t ROB_AGE_LIMIT = rob_tag_t'(1 << (ROB_TAG_W-1));

  logic [31:0] valueInner [PRF_DEPTH];
  logic [PRF_DEPTH-1:0] readyInner;
  logic [PRF_DEPTH-1:0] freeInner;
  logic [PRF_DEPTH-1:0] freeAfterEventsInner;
  logic [PRF_DEPTH-1:0] restoreYoungMaskInner;
  phy_tag_t selectedPhyInner;
  logic selectedValidInner;
  integer combIndexInner;
  integer combJInner;
  integer seqIndexInner;

  always_comb begin
    selectedPhyInner = '0;
    selectedValidInner = 1'b0;
    for (combIndexInner = 1; combIndexInner < PRF_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (!selectedValidInner && freeInner[combIndexInner]) begin
        selectedPhyInner = phy_tag_t'(combIndexInner);
        selectedValidInner = 1'b1;
      end
    end
    // Squash owns recovery: only a non-squash cycle may pop. issue_fire already
    // excludes global_flush upstream, so this is a local invariant guard.
    allocReadyOutput = !restoreInput.valid && selectedValidInner;
    allocPhyOutput = selectedPhyInner;

    readOutput[0].ready = (readInput[0].physicalRegister == '0) ? 1'b1 : readyInner[readInput[0].physicalRegister];
    readOutput[0].value = (readInput[0].physicalRegister == '0) ? 32'b0 : valueInner[readInput[0].physicalRegister];
    readOutput[1].ready = (readInput[1].physicalRegister == '0) ? 1'b1 : readyInner[readInput[1].physicalRegister];
    readOutput[1].value = (readInput[1].physicalRegister == '0) ? 32'b0 : valueInner[readInput[1].physicalRegister];
    readOutput[2].ready = (readInput[2].physicalRegister == '0) ? 1'b1 : readyInner[readInput[2].physicalRegister];
    readOutput[2].value = (readInput[2].physicalRegister == '0) ? 32'b0 : valueInner[readInput[2].physicalRegister];
    readyVectorOutput = readyInner;

    freeCountOutput = '0;
    for (combIndexInner = 1; combIndexInner < PRF_DEPTH; combIndexInner = combIndexInner + 1)
      if (freeInner[combIndexInner])
        freeCountOutput = freeCountOutput + 1'b1;
  end

  // A squashed instruction cannot have released a register yet: commits run in
  // order at the head and the head is strictly older than the boundaryInput. So
  // freeInner already covers every release that happened since the boundaryInput was
  // renamed, and recovery is a plain set-union of the window's new physical
  // tags. That is exactly what the referenceInput tree does by pushing each
  // robNewPhy of (SquashTag, next-free) back onto its free ring.
  //
  // The age test is written out instead of calling rv32_pkg::rob_is_younger:
  // iverilog stalls forever when that function (which contains variable-index
  // writes) is inlined into an always_comb that reads the replay window, while
  // the same predicate as arithmetic is fine. The two agree on all 1024 tag
  // pairs once the limit is exclusive -- rob_is_younger is false at age 16,
  // which no live lane can reach anyway (a window holds at most ROB_DEPTH
  // entries).
  always_comb begin
    restoreYoungMaskInner = '0;
    if (restoreInput.valid) begin
      for (combJInner = 0; combJInner < ROB_DEPTH; combJInner = combJInner + 1) begin
        if ((combJInner < restoreCountInput) &&
            (((replayInput[combJInner].robTag - restoreInput.squashTag) & ROB_AGE_MASK) != '0) &&
            (((replayInput[combJInner].robTag - restoreInput.squashTag) & ROB_AGE_MASK) <
             ROB_AGE_LIMIT) &&
            (replayInput[combJInner].newPhy != '0))
          restoreYoungMaskInner[replayInput[combJInner].newPhy] = 1'b1;
      end
    end
  end

  always_comb begin
    freeAfterEventsInner = freeInner;
    if (freeInput.valid && (freeInput.physicalRegister != '0))
      freeAfterEventsInner[freeInput.physicalRegister] = 1'b1;
    if (restoreInput.valid)
      freeAfterEventsInner = freeAfterEventsInner | restoreYoungMaskInner;
    if (allocationInput.valid && selectedValidInner)
      freeAfterEventsInner[selectedPhyInner] = 1'b0;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      readyInner <= '0;
      freeInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < PRF_DEPTH; seqIndexInner = seqIndexInner + 1)
        valueInner[seqIndexInner] <= 32'b0;
      for (seqIndexInner = 0; seqIndexInner < ARCH_REGS; seqIndexInner = seqIndexInner + 1)
        readyInner[seqIndexInner] <= 1'b1;
      for (seqIndexInner = ARCH_REGS; seqIndexInner < PRF_DEPTH; seqIndexInner = seqIndexInner + 1)
        freeInner[seqIndexInner] <= 1'b1;
    end else begin
      freeInner <= freeAfterEventsInner;

      if (allocationInput.valid && selectedValidInner) begin
        valueInner[selectedPhyInner] <= allocationInput.value;
        readyInner[selectedPhyInner] <= allocationInput.valueValid;
      end

      if (writebackInput[0].valid && (writebackInput[0].phyTag != '0)) begin
        valueInner[writebackInput[0].phyTag] <= writebackInput[0].value;
        readyInner[writebackInput[0].phyTag] <= 1'b1;
      end
      if (writebackInput[1].valid && (writebackInput[1].phyTag != '0)) begin
        valueInner[writebackInput[1].phyTag] <= writebackInput[1].value;
        readyInner[writebackInput[1].phyTag] <= 1'b1;
      end
      if (writebackInput[2].valid && (writebackInput[2].phyTag != '0)) begin
        valueInner[writebackInput[2].phyTag] <= writebackInput[2].value;
        readyInner[writebackInput[2].phyTag] <= 1'b1;
      end
      if (writebackInput[3].valid && (writebackInput[3].phyTag != '0)) begin
        valueInner[writebackInput[3].phyTag] <= writebackInput[3].value;
        readyInner[writebackInput[3].phyTag] <= 1'b1;
      end

      valueInner[0] <= 32'b0;
      readyInner[0] <= 1'b1;
      freeInner[0] <= 1'b0;
    end
  end
endmodule
