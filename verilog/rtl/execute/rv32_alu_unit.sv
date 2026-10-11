// ALU result buffer: a single result register with SAME-CYCLE release
// (drain-and-refill).  It mirrors the software reference after the 2026-10-07
// unification (`ALU_CAP = 1`; the reference applies this cycle's release before
// pushing, so a slot freed this cycle is reusable immediately):
//
//   * allocation scans the POST-release bitmap: a slot is free this cycle when
//     it is empty, when the CDB consumes its entry (outReadyInput) or when a
//     flush cancels it.  The running entry is read combinationally onto the
//     result bus while the register samples the new entry at the clock edge, so
//     one register keeps one op per cycle;
//   * the oldest valid entry drives the bus, so release matches the reference
//     remove-by-CDB-tag;
//   * flush kills every entry that is not strictly older than the flush tag, and
//     a pushed entry is stillborn when the incoming op is not older;
//   * inReadyOutput reports a free slot in the post-release bitmap.
//
// The allocation predicate and the sequential release use the SAME
// removedInner/flushedInner signals, so acceptance can never admit an op whose
// slot is not actually released (the "same source" rule of SPEC §29.5).
module rv32_alu_unit #(
  parameter int unsigned DEPTH = rv32_pkg::ALU_RESULT_ENTRIES
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,

  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  input  logic                   outReadyInput,
  output rv32_pkg::alu_execute_output_t executeOutput,
  output logic [$clog2(DEPTH+1)-1:0] occupancyOutput
);
  import rv32_pkg::*;

  localparam int unsigned INDEX_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

  logic [31:0] aluResultInner;
  alu_operation_output_t aluOutputInner;

  logic [31:0] valueInner [DEPTH];
  rob_tag_t    tagInner [DEPTH];
  phy_tag_t    phyInner [DEPTH];
  logic        controlInner [DEPTH];
  logic        controlMisalignedInner [DEPTH];
  logic        validInner [DEPTH];

  logic               headFoundInner;
  logic [INDEX_W-1:0] headIndexInner;
  logic               allocFoundInner;
  logic [INDEX_W-1:0] allocIndexInner;
  logic               pushHereInner;
  logic               pushFlushedInner;
  logic               removedInner [DEPTH];
  logic               flushedInner [DEPTH];

  integer combIndexInner;
  integer seqIndexInner;

  rv32_alu u_alu (
    .aluInput('{operation: executeInput.operation,
               leftOperand: executeInput.source1,
               rightOperand: executeInput.source2,
               immediate: executeInput.immediate,
               programCounter: executeInput.programCounter,
               useImmediate: executeInput.useImmediate}),
    .aluOutput(aluOutputInner)
  );
  assign aluResultInner = aluOutputInner.value;

  always_comb begin
    // Oldest valid entry wins the result bus (reference headValue/headRobTag).
    headFoundInner = 1'b0;
    headIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      if (validInner[combIndexInner] &&
          (!headFoundInner ||
           rob_is_older(tagInner[combIndexInner], tagInner[headIndexInner]))) begin
        headFoundInner = 1'b1;
        headIndexInner = combIndexInner[INDEX_W-1:0];
      end
    end

    // This cycle's releases, computed once from the committed bitmap.  The
    // sequential block below reuses the very same signals, so a slot admitted by
    // allocation is guaranteed to be released this cycle.
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      removedInner[combIndexInner] = outReadyInput && headFoundInner &&
          validInner[combIndexInner] &&
          (tagInner[combIndexInner] == tagInner[headIndexInner]);
      flushedInner[combIndexInner] = flushInfoInput.valid &&
          validInner[combIndexInner] &&
          !rob_is_older(tagInner[combIndexInner], flushInfoInput.robTag);
    end

    // Allocation reads the POST-release bitmap: a slot freed by this cycle's
    // grant/flush is reusable in the SAME cycle (drain-and-refill).
    allocFoundInner = 1'b0;
    allocIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      if (!allocFoundInner &&
          (!validInner[combIndexInner] || removedInner[combIndexInner] ||
           flushedInner[combIndexInner])) begin
        allocFoundInner = 1'b1;
        allocIndexInner = combIndexInner[INDEX_W-1:0];
      end
    end

    pushHereInner = executeInput.valid && allocFoundInner;
    pushFlushedInner = flushInfoInput.valid &&
        !rob_is_older(executeInput.robTag, flushInfoInput.robTag);
    // The reference gates dispatch on capacity alone and drops a squashed push,
    // so acceptance does not depend on the incoming op's age.
    inReadyOutput = allocFoundInner;

    // Raw result visibility is retained; the core authenticates output age.
    executeOutput.valid = headFoundInner;
    executeOutput.value = valueInner[headIndexInner];
    executeOutput.robTag = tagInner[headIndexInner];
    executeOutput.destinationPhy = phyInner[headIndexInner];
    executeOutput.isControl = controlInner[headIndexInner];
    executeOutput.controlMisaligned = controlMisalignedInner[headIndexInner];

    occupancyOutput = '0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
      if (validInner[combIndexInner])
        occupancyOutput = occupancyOutput + 1'b1;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        validInner[seqIndexInner] <= 1'b0;
        valueInner[seqIndexInner] <= '0;
        tagInner[seqIndexInner] <= '0;
        phyInner[seqIndexInner] <= '0;
        controlInner[seqIndexInner] <= 1'b0;
        controlMisalignedInner[seqIndexInner] <= 1'b0;
      end
    end else begin
      // Single assignment per slot, priority push > flush > grant > keep.  A
      // push may land in a slot that is released this same cycle; the payload
      // written is the new one (drain-and-refill of a single result register).
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (pushHereInner && (seqIndexInner[INDEX_W-1:0] == allocIndexInner)) begin
          valueInner[seqIndexInner] <= aluResultInner;
          tagInner[seqIndexInner] <= executeInput.robTag;
          phyInner[seqIndexInner] <= executeInput.destinationPhy;
          controlInner[seqIndexInner] <= executeInput.isControl;
          controlMisalignedInner[seqIndexInner] <=
              executeInput.isControl && (aluResultInner[1:0] != 2'b00);
          validInner[seqIndexInner] <= !pushFlushedInner;
        end else if (flushedInner[seqIndexInner]) begin
          validInner[seqIndexInner] <= 1'b0;
        end else if (removedInner[seqIndexInner]) begin
          validInner[seqIndexInner] <= 1'b0;
        end
      end
    end
  end
endmodule
