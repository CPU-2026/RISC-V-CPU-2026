module rv32_rob #(
  parameter int unsigned DEPTH = rv32_pkg::ROB_ENTRIES,
  parameter int unsigned COMMIT_WIDTH = 1,
  parameter int unsigned RENAME_WIDTH = 1
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input logic freezeInput,

  input  rv32_pkg::rob_allocation_input_t allocInput,
  output logic                   allocReadyOutput,
  output rv32_pkg::rob_tag_t     allocTagOutput,
  input  rv32_pkg::rob_allocation_input_t allocSecondInput,
  output logic allocSecondReadyOutput,
  output rv32_pkg::rob_tag_t allocSecondTagOutput,
  input  rv32_pkg::rob_completion_t [5:0] completionInput,
  input  rv32_pkg::store_completion_output_t storeReadyInput,
  input  rv32_pkg::rob_flush_input_t flushInput,
  input  rv32_pkg::rob_lookup_input_t [4:0] lookupInput,
  output rv32_pkg::rob_lookup_output_t [4:0] lookupOutput,
  output rv32_pkg::rob_commit_output_t [COMMIT_WIDTH-1:0] commitOutput,
  output logic [COMMIT_WIDTH-1:0] commitStoreOutput,
  input  logic [COMMIT_WIDTH-1:0] commitReadyInput,
  output logic [COMMIT_WIDTH-1:0] commitFireOutput,
  output rv32_pkg::rob_status_output_t statusOutput,
  output logic [$clog2(DEPTH+1)-1:0] countOutput,

  input  rv32_pkg::rob_tag_t     replayOffsetInput,
  output rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayNarrowOutput,
  output rv32_pkg::rob_replay_ras_t    [rv32_pkg::RECOVERY_WIDTH-1:0] replayRasOutput
);
  import rv32_pkg::*;
  if (RENAME_WIDTH != 1 && RENAME_WIDTH != 2) begin : g_invalid_rename_width
    initial $fatal(1, "RENAME_WIDTH must be 1 or 2");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2) begin : g_invalid_commit_width
    initial $fatal(1, "COMMIT_WIDTH must be 1 or 2");
  end

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
  logic [DEPTH-1:0] readySetInner;
  logic [DEPTH-1:0] storeBitmapReadyInner;
  logic [COUNT_W-1:0] commitCountInner;
  logic allocFireInner, allocSecondFireInner;
  logic [COUNT_W-1:0] allocCountInner;
  logic [SLOT_W-1:0] secondSlotInner;
  assign allocFireInner = allocInput.valid && allocReadyOutput;
  assign allocSecondReadyOutput = RENAME_WIDTH == 2 && !flushInput.valid && int'(countInner) <= DEPTH-2;
  assign allocSecondTagOutput = tailInner + rob_tag_t'(1);
  assign secondSlotInner = tailSlotInner + SLOT_W'(1);
  assign allocSecondFireInner = RENAME_WIDTH == 2 && allocFireInner && allocSecondInput.valid && allocSecondReadyOutput;
  assign allocCountInner = COUNT_W'(allocFireInner) + COUNT_W'(allocSecondFireInner);
  // Compile-time selection: single retirement has no second-lane prefix or
  // commit-count adder. The dual path retains the validated age-order fold.
  generate if (COMMIT_WIDTH == 1) begin : g_single_commit
    assign commitCountInner = COUNT_W'(commitFireOutput[0]);
    assign commitFireOutput[0] = commitOutput[0].valid && commitReadyInput[0];
  end else begin : g_dual_commit
    always_comb begin
      commitCountInner = '0;
      for (int lane = 0; lane < COMMIT_WIDTH; lane++)
        commitCountInner = commitCountInner + COUNT_W'(commitFireOutput[lane]);
    end
    always_comb begin : commit_prefix
      logic open;
      open = 1'b1;
      for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
        commitFireOutput[lane] = open && commitOutput[lane].valid && commitReadyInput[lane];
        open = commitFireOutput[lane];
      end
    end
  end endgenerate

  // Merge completion intents per physical row. The bitmap uses the FULL
  // package slot index, not SLOT_W: reduced DEPTH must retain all tag bits.
  always_comb begin
    readySetInner = '0;
    for (int row = 0; row < DEPTH; row = row + 1) begin
      if (validInner[row] &&
          (!flushInput.valid || rob_is_older(tagInner[row], flushInput.robTag))) begin
        if (storeInner[row] && storeBitmapReadyInner[row])
          readySetInner[row] = 1'b1;
        for (int portIndex = 0; portIndex < 6; portIndex = portIndex + 1) begin
          if (completionInput[portIndex].valid && completionInput[portIndex].robTag == tagInner[row]) begin
            readySetInner[row] = 1'b1;
          end
        end
      end
    end
  end

  // Exactly one ready write per row; allocation initialization wins. Retirement
  // still observes the old ready bit and is bounded by COMMIT_WIDTH.
  generate
    for (genvar row = 0; row < DEPTH; row = row + 1) begin : gen_ready_write
      if (DEPTH == ROB_ENTRIES) begin : gen_constant_bitmap_slot
        // Normal core: literal per-slot wires, no mask-selection crossbar.
        assign storeBitmapReadyInner[row] = storeReadyInput.readyMask[row] &&
          storeReadyInput.epochMask[row] == tagInner[row][ROB_TAG_W-1];
      end else begin : gen_full_tag_bitmap_slot
        // Reduced DEPTH retains the full package tag's slot identity.
        assign storeBitmapReadyInner[row] = storeReadyInput.readyMask[tagInner[row][ROB_TAG_W-2:0]] &&
          storeReadyInput.epochMask[tagInner[row][ROB_TAG_W-2:0]] == tagInner[row][ROB_TAG_W-1];
      end
      always_ff @(posedge clkInput or negedge rstNInput) begin
        if (!rstNInput) readyInner[row] <= 1'b0;
        else if (!freezeInput && allocInput.valid && allocReadyOutput && tailSlotInner == SLOT_W'(row))
          readyInner[row] <= allocInput.ready || allocInput.isHalt;
        else if (!freezeInput && allocSecondFireInner && secondSlotInner == SLOT_W'(row))
          readyInner[row] <= allocSecondInput.ready || allocSecondInput.isHalt;
        else if (!freezeInput && readySetInner[row]) readyInner[row] <= 1'b1;
      end
    end
  endgenerate

  // Replay window = the RECOVERY_WIDTH entries at absolute slot head+offset+lane.
  // Rotating all DEPTH entries here and re-indexing them in every consumer cost
  // two mux layers; consumers always read the same expression (head+offset+lane).
  genvar replayIndexInner;
  generate
    for (replayIndexInner = 0; replayIndexInner < RECOVERY_WIDTH;
         replayIndexInner = replayIndexInner + 1) begin : gen_replay_window
      logic [SLOT_W-1:0] replaySlotInner;

      assign replaySlotInner = headInner[SLOT_W-1:0] + SLOT_W'(replayOffsetInput) +
                               SLOT_W'(replayIndexInner);
      assign replayNarrowOutput[replayIndexInner] = '{
        robTag: tagInner[replaySlotInner],
        archRd: archRdInner[replaySlotInner],
        newPhy: newPhyInner[replaySlotInner]
      };
      assign replayRasOutput[replayIndexInner] = '{
        robTag: tagInner[replaySlotInner],
        programCounter: pcInner[replaySlotInner],
        opcode: instrInner[replaySlotInner][6:0],
        rd: instrInner[replaySlotInner][11:7],
        funct3: instrInner[replaySlotInner][14:12],
        rs1: instrInner[replaySlotInner][19:15]
      };
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
    .aInput(headInner), .bInput(ROB_TAG_W'(commitCountInner)), .cinInput(1'b0),
    .sumOutput(headNext), .coutOutput(unusedCoutHeadInner)
  );

  rv32_add #(.WIDTH(ROB_TAG_W)) u_tail_next (
    .aInput(tailInner), .bInput(ROB_TAG_W'(allocCountInner)), .cinInput(1'b0),
    .sumOutput(tailNext), .coutOutput(unusedCoutTailInner)
  );

  rv32_add #(.WIDTH(COUNT_W)) u_count_up (
    .aInput(countInner), .bInput(COUNT_W'(1)), .cinInput(1'b0),
    .sumOutput(countUpInner), .coutOutput(unusedCoutCountUpInner)
  );

  rv32_sub #(.WIDTH(COUNT_W)) u_count_down (
    .aInput(countInner), .bInput(commitCountInner),
    .diffOutput(countDownInner), .borrowOutput(unusedBorrowCountDownInner)
  );

  rv32_sub #(.WIDTH(COUNT_W)) u_flush_count_after_commit (
    .aInput(flushCountInner[COUNT_W-1:0]), .bInput(commitCountInner),
    .diffOutput(flushCountAfterCommitInner),
    .borrowOutput(unusedBorrowFlushCommitInner)
  );

  always_comb begin
    lookupOutput = '0;
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

  // Fold candidates locally rather than feeding a packed output array back
  // through per-lane blocks. Eligibility is old-state only, independent of
  // downstream ready; the separate fire fold enforces consumer acceptance.
  always_comb begin : commit_candidates
    logic prefix;
    logic [SLOT_W-1:0] slot;
    logic eligible;
    prefix = !freezeInput;
    slot = '0;
    eligible = 1'b0;
    for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
      slot = headInner[SLOT_W-1:0] + SLOT_W'(lane);
      eligible = prefix && int'(countInner) > lane && validInner[slot] &&
        tagInner[slot] == headInner + rob_tag_t'(lane) && readyInner[slot] &&
        (!flushInput.valid || rob_is_older(tagInner[slot], flushInput.robTag));
      commitOutput[lane].valid = eligible;
      commitOutput[lane].robTag = tagInner[slot];
      commitOutput[lane].programCounter = pcInner[slot];
      commitOutput[lane].instruction = instrInner[slot];
      commitOutput[lane].writesArchitecturalRegister = writesRdInner[slot];
      commitOutput[lane].architecturalRegister = archRdInner[slot];
      commitOutput[lane].newPhysicalRegister = newPhyInner[slot];
      commitOutput[lane].oldPhysicalRegister = oldPhyInner[slot];
      commitStoreOutput[lane] = storeInner[slot];
      commitOutput[lane].storeQueueIndex = sqIndexInner[slot];
      commitOutput[lane].isHalt = haltInner[slot];
      commitOutput[lane].hasException = 1'b0; // Compatibility field, no exception state.
      prefix = eligible && !haltInner[slot];
    end
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      tailInner <= '0;
      countInner <= '0;
      for (iInner = 0; iInner < DEPTH; iInner = iInner + 1) begin
        validInner[iInner] <= 1'b0;
        tagInner[iInner] <= '0;
        pcInner[iInner] <= '0;
        instrInner[iInner] <= '0;
        writesRdInner[iInner] <= 1'b0;
        archRdInner[iInner] <= '0;
        newPhyInner[iInner] <= '0;
        oldPhyInner[iInner] <= '0;
        storeInner[iInner] <= 1'b0;
        sqIndexInner[iInner] <= '0;
        haltInner[iInner] <= 1'b0;
        predictedPcInner[iInner] <= '0;
        predictorCkptIdInner[iInner] <= '0;
        isRetInner[iInner] <= 1'b0;
      end
    end else if (!freezeInput && flushInput.valid) begin
      tailInner <= flushTagNext;
      countInner <= commitFireOutput ? flushCountAfterCommitInner :
                                 flushCountInner[COUNT_W-1:0];
      for (iInner = 0; iInner < DEPTH; iInner = iInner + 1) begin
        if (validInner[iInner] && rob_is_younger(tagInner[iInner], flushInput.robTag))
          validInner[iInner] <= 1'b0;
      end

      if (commitCountInner != 0) begin
        for (int lane = 0; lane < COMMIT_WIDTH; lane++)
          if (commitFireOutput[lane]) validInner[SLOT_W'(headInner + rob_tag_t'(lane))] <= 1'b0;
        headInner <= headNext;
      end
    end else if (!freezeInput) begin
      if (commitCountInner != 0) begin
        for (int lane = 0; lane < COMMIT_WIDTH; lane++)
          if (commitFireOutput[lane]) validInner[SLOT_W'(headInner + rob_tag_t'(lane))] <= 1'b0;
        headInner <= headNext;
      end

      if (allocInput.valid && allocReadyOutput) begin
        validInner[tailSlotInner] <= 1'b1;
        tagInner[tailSlotInner] <= tailInner;
        pcInner[tailSlotInner] <= allocInput.programCounter;
        instrInner[tailSlotInner] <= allocInput.instruction;
        writesRdInner[tailSlotInner] <= allocInput.writesArchitecturalRegister;
        archRdInner[tailSlotInner] <= allocInput.architecturalRegister;
        newPhyInner[tailSlotInner] <= allocInput.newPhysicalRegister;
        oldPhyInner[tailSlotInner] <= allocInput.oldPhysicalRegister;
        storeInner[tailSlotInner] <= allocInput.isStore;
        sqIndexInner[tailSlotInner] <= allocInput.storeQueueIndex;
        haltInner[tailSlotInner] <= allocInput.isHalt;
        predictedPcInner[tailSlotInner] <= allocInput.predictedProgramCounter;
        predictorCkptIdInner[tailSlotInner] <= allocInput.predictorCheckpointId;
        isRetInner[tailSlotInner] <= allocInput.isReturn;
        tailInner <= tailNext;
      end
      if (allocSecondFireInner) begin
        validInner[secondSlotInner] <= 1'b1;
        tagInner[secondSlotInner] <= allocSecondTagOutput;
        pcInner[secondSlotInner] <= allocSecondInput.programCounter;
        instrInner[secondSlotInner] <= allocSecondInput.instruction;
        writesRdInner[secondSlotInner] <= allocSecondInput.writesArchitecturalRegister;
        archRdInner[secondSlotInner] <= allocSecondInput.architecturalRegister;
        newPhyInner[secondSlotInner] <= allocSecondInput.newPhysicalRegister;
        oldPhyInner[secondSlotInner] <= allocSecondInput.oldPhysicalRegister;
        storeInner[secondSlotInner] <= allocSecondInput.isStore;
        sqIndexInner[secondSlotInner] <= allocSecondInput.storeQueueIndex;
        haltInner[secondSlotInner] <= allocSecondInput.isHalt;
        predictedPcInner[secondSlotInner] <= allocSecondInput.predictedProgramCounter;
        predictorCkptIdInner[secondSlotInner] <= allocSecondInput.predictorCheckpointId;
        isRetInner[secondSlotInner] <= allocSecondInput.isReturn;
      end

      countInner <= countDownInner + allocCountInner;
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !freezeInput) begin
    assert (!allocSecondInput.valid || RENAME_WIDTH == 1 || allocFireInner)
      else $fatal(1, "ROB second allocation must follow the first");
    assert (int'(countInner) + int'(allocCountInner) <= DEPTH)
      else $fatal(1, "ROB allocation exceeds old free capacity");
  end
`endif
endmodule
