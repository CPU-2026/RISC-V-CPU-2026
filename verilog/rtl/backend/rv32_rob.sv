module rv32_rob #(
  parameter int unsigned DEPTH = rv32_pkg::ROB_ENTRIES
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,

  input  rv32_pkg::rob_allocation_input_t allocInput,
  output logic                   allocReadyOutput,
  output rv32_pkg::rob_tag_t     allocTagOutput,
  input  rv32_pkg::rob_completion_t [5:0] completionInput,
  input  rv32_pkg::rob_flush_input_t flushInput,
  input  rv32_pkg::rob_lookup_input_t [4:0] lookupInput,
  output rv32_pkg::rob_lookup_output_t [4:0] lookupOutput,
  output rv32_pkg::rob_commit_output_t commitOutput,
  output logic                   commitStoreOutput,
  input  logic                   commitReadyInput,
  output logic                   commitFireOutput,
  output rv32_pkg::rob_status_output_t statusOutput,
  output logic [$clog2(DEPTH+1)-1:0] countOutput,

  output rv32_pkg::rob_replay_entry_t [DEPTH-1:0] replayOutput
);
  import rv32_pkg::*;

  localparam int unsigned SLOT_W = $clog2(DEPTH);
  localparam int unsigned COUNT_W = $clog2(DEPTH + 1);

  logic validInner [DEPTH];
  rob_tag_t tagInner [DEPTH];
  logic readyInner [DEPTH];
  logic [31:0] pcInner [DEPTH];
  logic [31:0] instrInner [DEPTH];
  logic writesRdInner [DEPTH];
  logic [4:0] archRdInner [DEPTH];
  phy_tag_t newPhyInner [DEPTH];
  phy_tag_t oldPhyInner [DEPTH];
  logic storeInner [DEPTH];
  logic [2:0] sqIndexInner [DEPTH];
  logic haltInner [DEPTH];
  logic exceptionInner [DEPTH];
  logic [31:0] predictedPcInner [DEPTH];
  bpu_ckpt_id_t predictorCkptIdInner [DEPTH];
  logic isRetInner [DEPTH];

  rob_tag_t headInner, tailInner;
  logic [$clog2(DEPTH+1)-1:0] countInner;
  logic [SLOT_W-1:0] headSlotInner;
  logic [SLOT_W-1:0] tailSlotInner;
  logic [ROB_TAG_W-1:0] flushCountInner;
  logic [COUNT_W-1:0] flushCountAfterCommitInner;
  integer iInner;

  logic [ROB_TAG_W-1:0] flushTagNext;
  logic [ROB_TAG_W-1:0] headNext, tailNext;
  logic [COUNT_W-1:0] countUpInner, countDownInner;
  logic unusedCoutFlushTagInner, unusedBorrowFlushInner;
  logic unusedCoutHeadInner, unusedCoutTailInner;
  logic unusedCoutCountUpInner, unusedBorrowCountDownInner;
  logic unusedBorrowFlushCommitInner;

  genvar replayIndexInner;
  generate
    for (replayIndexInner = 0; replayIndexInner < DEPTH;
         replayIndexInner = replayIndexInner + 1) begin : gen_replay_window
      logic [SLOT_W-1:0] replaySlotInner;

      assign replaySlotInner = headInner[SLOT_W-1:0] + SLOT_W'(replayIndexInner);
      assign replayOutput[replayIndexInner].robTag = tagInner[replaySlotInner];
      assign replayOutput[replayIndexInner].programCounter = pcInner[replaySlotInner];
      assign replayOutput[replayIndexInner].instruction = instrInner[replaySlotInner];
      assign replayOutput[replayIndexInner].archRd = archRdInner[replaySlotInner];
      assign replayOutput[replayIndexInner].newPhy = newPhyInner[replaySlotInner];
    end
  endgenerate

  rv32_add #(.WIDTH(ROB_TAG_W)) u_flush_tag_next (
    .aInput(flushInput.robTag), .bInput(ROB_TAG_W'(1)), .cinInput(1'b0),
    .sumOutput(flushTagNext), .coutOutput(unusedCoutFlushTagInner)
  );

  rv32_sub #(.WIDTH(ROB_TAG_W)) u_flush_count (
    .aInput(flushTagNext), .bInput(headInner),
    .diffOutput(flushCountInner), .borrowOutput(unusedBorrowFlushInner)
  );

  rv32_add #(.WIDTH(ROB_TAG_W)) u_head_next (
    .aInput(headInner), .bInput(ROB_TAG_W'(1)), .cinInput(1'b0),
    .sumOutput(headNext), .coutOutput(unusedCoutHeadInner)
  );

  rv32_add #(.WIDTH(ROB_TAG_W)) u_tail_next (
    .aInput(tailInner), .bInput(ROB_TAG_W'(1)), .cinInput(1'b0),
    .sumOutput(tailNext), .coutOutput(unusedCoutTailInner)
  );

  rv32_add #(.WIDTH(COUNT_W)) u_count_up (
    .aInput(countInner), .bInput(COUNT_W'(1)), .cinInput(1'b0),
    .sumOutput(countUpInner), .coutOutput(unusedCoutCountUpInner)
  );

  rv32_sub #(.WIDTH(COUNT_W)) u_count_down (
    .aInput(countInner), .bInput(COUNT_W'(1)),
    .diffOutput(countDownInner), .borrowOutput(unusedBorrowCountDownInner)
  );

  rv32_sub #(.WIDTH(COUNT_W)) u_flush_count_after_commit (
    .aInput(flushCountInner[COUNT_W-1:0]), .bInput(COUNT_W'(1)),
    .diffOutput(flushCountAfterCommitInner),
    .borrowOutput(unusedBorrowFlushCommitInner)
  );

  always_comb begin
    headSlotInner = headInner[SLOT_W-1:0];
    tailSlotInner = tailInner[SLOT_W-1:0];
    statusOutput.empty = (countInner == '0);
    statusOutput.full = (countInner == COUNT_W'(DEPTH));
    countOutput = countInner;
    statusOutput.headTag = headInner;
    allocTagOutput = tailInner;
    allocReadyOutput = !flushInput.valid && !statusOutput.full;

    lookupOutput[0].valid = validInner[lookupInput[0].robTag[SLOT_W-1:0]] &&
                      (tagInner[lookupInput[0].robTag[SLOT_W-1:0]] == lookupInput[0].robTag);
    lookupOutput[0].programCounter = pcInner[lookupInput[0].robTag[SLOT_W-1:0]];
    lookupOutput[0].predictedProgramCounter = predictedPcInner[lookupInput[0].robTag[SLOT_W-1:0]];
    lookupOutput[0].predictorCheckpointId =
      predictorCkptIdInner[lookupInput[0].robTag[SLOT_W-1:0]];
    lookupOutput[0].isReturn = isRetInner[lookupInput[0].robTag[SLOT_W-1:0]];

    lookupOutput[1].valid = validInner[lookupInput[1].robTag[SLOT_W-1:0]] &&
                      (tagInner[lookupInput[1].robTag[SLOT_W-1:0]] == lookupInput[1].robTag);
    lookupOutput[1].programCounter = pcInner[lookupInput[1].robTag[SLOT_W-1:0]];
    lookupOutput[1].predictedProgramCounter = predictedPcInner[lookupInput[1].robTag[SLOT_W-1:0]];
    lookupOutput[1].predictorCheckpointId =
      predictorCkptIdInner[lookupInput[1].robTag[SLOT_W-1:0]];
    lookupOutput[1].isReturn = isRetInner[lookupInput[1].robTag[SLOT_W-1:0]];

    lookupOutput[2].valid = validInner[lookupInput[2].robTag[SLOT_W-1:0]] &&
                      (tagInner[lookupInput[2].robTag[SLOT_W-1:0]] == lookupInput[2].robTag);
    lookupOutput[3].valid = validInner[lookupInput[3].robTag[SLOT_W-1:0]] &&
                      (tagInner[lookupInput[3].robTag[SLOT_W-1:0]] == lookupInput[3].robTag);
    lookupOutput[4].valid = validInner[lookupInput[4].robTag[SLOT_W-1:0]] &&
                      (tagInner[lookupInput[4].robTag[SLOT_W-1:0]] == lookupInput[4].robTag);
  end

  always_comb begin
    commitOutput.valid = (countInner != '0) && validInner[headInner[SLOT_W-1:0]] &&
                     readyInner[headInner[SLOT_W-1:0]] &&
                      (!flushInput.valid || rob_is_older(tagInner[headSlotInner], flushInput.robTag));
    commitOutput.robTag = tagInner[headSlotInner];
    commitOutput.programCounter = pcInner[headSlotInner];
    commitOutput.instruction = instrInner[headSlotInner];
    commitOutput.writesArchitecturalRegister = writesRdInner[headSlotInner];
    commitOutput.architecturalRegister = archRdInner[headSlotInner];
    commitOutput.newPhysicalRegister = newPhyInner[headSlotInner];
    commitOutput.oldPhysicalRegister = oldPhyInner[headSlotInner];
    commitStoreOutput = storeInner[headSlotInner];
    commitOutput.storeQueueIndex = sqIndexInner[headSlotInner];
    commitOutput.isHalt = haltInner[headSlotInner];
    commitOutput.hasException = exceptionInner[headSlotInner];
  end

  assign commitFireOutput = commitOutput.valid && commitReadyInput;

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      tailInner <= '0;
      countInner <= '0;
      for (iInner = 0; iInner < DEPTH; iInner = iInner + 1) begin
        validInner[iInner] <= 1'b0;
        tagInner[iInner] <= '0;
        readyInner[iInner] <= 1'b0;
        pcInner[iInner] <= '0;
        instrInner[iInner] <= '0;
        writesRdInner[iInner] <= 1'b0;
        archRdInner[iInner] <= '0;
        newPhyInner[iInner] <= '0;
        oldPhyInner[iInner] <= '0;
        storeInner[iInner] <= 1'b0;
        sqIndexInner[iInner] <= '0;
        haltInner[iInner] <= 1'b0;
        exceptionInner[iInner] <= 1'b0;
        predictedPcInner[iInner] <= '0;
        predictorCkptIdInner[iInner] <= '0;
        isRetInner[iInner] <= 1'b0;
      end
    end else if (flushInput.valid) begin
      tailInner <= flushTagNext;
      countInner <= commitFireOutput ? flushCountAfterCommitInner :
                                 flushCountInner[COUNT_W-1:0];
      for (iInner = 0; iInner < DEPTH; iInner = iInner + 1) begin
        if (validInner[iInner] && rob_is_younger(tagInner[iInner], flushInput.robTag))
          validInner[iInner] <= 1'b0;
      end

      if (completionInput[0].valid && rob_is_older(completionInput[0].robTag, flushInput.robTag) &&
          validInner[completionInput[0].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[0].robTag[SLOT_W-1:0]] == completionInput[0].robTag)) begin
        readyInner[completionInput[0].robTag[SLOT_W-1:0]] <= 1'b1;
        if (completionInput[0].exception)
          exceptionInner[completionInput[0].robTag[SLOT_W-1:0]] <= 1'b1;
      end
      if (completionInput[1].valid && rob_is_older(completionInput[1].robTag, flushInput.robTag) &&
          validInner[completionInput[1].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[1].robTag[SLOT_W-1:0]] == completionInput[1].robTag))
        readyInner[completionInput[1].robTag[SLOT_W-1:0]] <= 1'b1;
      if (completionInput[2].valid && rob_is_older(completionInput[2].robTag, flushInput.robTag) &&
          validInner[completionInput[2].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[2].robTag[SLOT_W-1:0]] == completionInput[2].robTag))
        readyInner[completionInput[2].robTag[SLOT_W-1:0]] <= 1'b1;
      if (completionInput[3].valid && rob_is_older(completionInput[3].robTag, flushInput.robTag) &&
          validInner[completionInput[3].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[3].robTag[SLOT_W-1:0]] == completionInput[3].robTag))
        readyInner[completionInput[3].robTag[SLOT_W-1:0]] <= 1'b1;
      if (completionInput[4].valid && rob_is_older(completionInput[4].robTag, flushInput.robTag) &&
          validInner[completionInput[4].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[4].robTag[SLOT_W-1:0]] == completionInput[4].robTag)) begin
        readyInner[completionInput[4].robTag[SLOT_W-1:0]] <= 1'b1;
        if (completionInput[4].exception)
          exceptionInner[completionInput[4].robTag[SLOT_W-1:0]] <= 1'b1;
      end
      if (completionInput[5].valid && rob_is_older(completionInput[5].robTag, flushInput.robTag) &&
          validInner[completionInput[5].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[5].robTag[SLOT_W-1:0]] == completionInput[5].robTag))
        readyInner[completionInput[5].robTag[SLOT_W-1:0]] <= 1'b1;

      if (commitFireOutput) begin
        validInner[headSlotInner] <= 1'b0;
        headInner <= headNext;
      end
    end else begin
      if (completionInput[0].valid && validInner[completionInput[0].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[0].robTag[SLOT_W-1:0]] == completionInput[0].robTag)) begin
        readyInner[completionInput[0].robTag[SLOT_W-1:0]] <= 1'b1;
        if (completionInput[0].exception)
          exceptionInner[completionInput[0].robTag[SLOT_W-1:0]] <= 1'b1;
      end
      if (completionInput[1].valid && validInner[completionInput[1].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[1].robTag[SLOT_W-1:0]] == completionInput[1].robTag))
        readyInner[completionInput[1].robTag[SLOT_W-1:0]] <= 1'b1;
      if (completionInput[2].valid && validInner[completionInput[2].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[2].robTag[SLOT_W-1:0]] == completionInput[2].robTag))
        readyInner[completionInput[2].robTag[SLOT_W-1:0]] <= 1'b1;
      if (completionInput[3].valid && validInner[completionInput[3].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[3].robTag[SLOT_W-1:0]] == completionInput[3].robTag))
        readyInner[completionInput[3].robTag[SLOT_W-1:0]] <= 1'b1;
      if (completionInput[4].valid && validInner[completionInput[4].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[4].robTag[SLOT_W-1:0]] == completionInput[4].robTag)) begin
        readyInner[completionInput[4].robTag[SLOT_W-1:0]] <= 1'b1;
        if (completionInput[4].exception)
          exceptionInner[completionInput[4].robTag[SLOT_W-1:0]] <= 1'b1;
      end
      if (completionInput[5].valid && validInner[completionInput[5].robTag[SLOT_W-1:0]] &&
          (tagInner[completionInput[5].robTag[SLOT_W-1:0]] == completionInput[5].robTag))
        readyInner[completionInput[5].robTag[SLOT_W-1:0]] <= 1'b1;

      if (commitFireOutput) begin
        validInner[headSlotInner] <= 1'b0;
        headInner <= headNext;
      end

      if (allocInput.valid && allocReadyOutput) begin
        validInner[tailSlotInner] <= 1'b1;
        tagInner[tailSlotInner] <= tailInner;
        readyInner[tailSlotInner] <= allocInput.ready || allocInput.isHalt ||
                              allocInput.hasException;
        pcInner[tailSlotInner] <= allocInput.programCounter;
        instrInner[tailSlotInner] <= allocInput.instruction;
        writesRdInner[tailSlotInner] <= allocInput.writesArchitecturalRegister;
        archRdInner[tailSlotInner] <= allocInput.architecturalRegister;
        newPhyInner[tailSlotInner] <= allocInput.newPhysicalRegister;
        oldPhyInner[tailSlotInner] <= allocInput.oldPhysicalRegister;
        storeInner[tailSlotInner] <= allocInput.isStore;
        sqIndexInner[tailSlotInner] <= allocInput.storeQueueIndex;
        haltInner[tailSlotInner] <= allocInput.isHalt;
        exceptionInner[tailSlotInner] <= allocInput.hasException;
        predictedPcInner[tailSlotInner] <= allocInput.predictedProgramCounter;
        predictorCkptIdInner[tailSlotInner] <= allocInput.predictorCheckpointId;
        isRetInner[tailSlotInner] <= allocInput.isReturn;
        tailInner <= tailNext;
      end

      unique case ({allocInput.valid && allocReadyOutput, commitFireOutput})
        2'b10: countInner <= countUpInner;
        2'b01: countInner <= countDownInner;
        default: countInner <= countInner;
      endcase
    end
  end
endmodule
