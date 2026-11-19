module rv32_predictor #(
  parameter int unsigned BHT_ENTRIES = 256,
  parameter int unsigned BTB_ENTRIES = 32,
  parameter int unsigned RAS_ENTRIES = rv32_pkg::RAS_ENTRIES,
  parameter int unsigned CONDSEEN_ENTRIES = 512,
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES,
  parameter int unsigned COMMIT_WIDTH = 1,
  parameter int unsigned FETCH_WIDTH = 1
) (
  input  logic                         clkInput,
  input  logic                         rstNInput,
  input logic freezeInput,

  input  logic [31:0]                  queryPcInput,
  output rv32_pkg::prediction_output_t predictionOutput,

  // A checkpoint is allocated only when the frontend accepts this query.
  input  logic                         fetchAcceptInput,
  input logic fetchPredictInput,
  input logic fetchSecondInput,

  // Accepted fetch classification and execution-stage training arrive as
  // producer-owned payloads so related fields cannot be miswired separately.
  input  rv32_pkg::predictor_fetch_info_t fetchInfoInput,
  input  rv32_pkg::branch_result_input_t branchInput,
  input  rv32_pkg::jump_result_input_t   jumpInput,
  input  rv32_pkg::squash_input_t         squashInput,
  input  rv32_pkg::rob_predictor_input_t [COMMIT_WIDTH-1:0] robInput,
  input  rv32_pkg::recovery_step_t recoveryInput,
  input logic [2:0] fetchCountInput
);
  import rv32_pkg::*;
  if (FETCH_WIDTH != 1 && FETCH_WIDTH != 2 && FETCH_WIDTH != 4) begin : g_invalid_fetch_width
    initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2 && COMMIT_WIDTH != 4) begin : g_invalid_commit_width
    initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
  end

  logic dirTakenInner, dirUseGlobalInner, dirCondseenInner;
  logic [7:0] dirGhrInner;
  logic [7:0] branchGhrInner;
  direction_prediction_output_t directionOutputInner;
  direction_context_t queryDirectionContextInner, branchDirectionContextInner;

  logic btbHitInner, btbUncondInner, btbRetInner;
  logic [31:0] btbTgtInner;
  btb_lookup_output_t btbLookupOutputInner;

  logic [15:0] rasTopInner;
  logic [31:0] rasRetTargetInner;
  logic [7:0] ckptSquashGhrInner;
  checkpoint_output_t checkpointOutputInner;

  logic branchTrainInner, jumpTrainInner;

  logic queryBtbHitInner;
  logic queryDirTakenInner, queryIsRetInner, queryTakenInner, queryShiftInner, queryShiftValueInner;
  logic [31:0] queryTargetInner;
  btb_training_input_t trainingBatchInner;

  rv32_bpu_direction #(
    .BHT_ENTRIES(BHT_ENTRIES),
    .CONDSEEN_ENTRIES(CONDSEEN_ENTRIES)
  ) u_direction (
    .freezeInput(freezeInput),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .queryPcInput(queryPcInput),
    .branchInput('{valid: branchTrainInner,
                  programCounter: branchInput.programCounter,
                  nextProgramCounter: branchInput.nextProgramCounter,
                  taken: branchInput.taken,
                   globalHistory: branchGhrInner}),
    .branchContextInput(branchDirectionContextInner),
    .historyInput('{fetchAccepted: fetchAcceptInput && (FETCH_WIDTH == 1 || fetchPredictInput),
                   squashValid: squashInput.valid,
                     queryShift: queryShiftInner,
                     queryShiftValue: queryShiftValueInner,
                   recoveryHistory: ckptSquashGhrInner}),
    .predictionOutput(directionOutputInner),
    .queryContextOutput(queryDirectionContextInner)
  );
  assign dirTakenInner = directionOutputInner.directionTaken;
  assign dirUseGlobalInner = directionOutputInner.useGlobal;
  assign dirCondseenInner = directionOutputInner.conditionalSeen;
  assign dirGhrInner = directionOutputInner.globalHistory;

  assign trainingBatchInner = '{fetchValid: fetchInfoInput.valid,
    isReturn: fetchInfoInput.isReturn, jalTargetValid: fetchInfoInput.jalTargetValid,
    fetchProgramCounter: fetchInfoInput.programCounter, jalTarget: fetchInfoInput.jalTarget,
    branch: '{valid: branchTrainInner, programCounter: branchInput.programCounter,
      nextProgramCounter: branchInput.nextProgramCounter, taken: branchInput.taken,
      globalHistory: branchGhrInner},
    jumpValid: jumpTrainInner, jumpProgramCounter: jumpInput.programCounter,
    jumpTarget: jumpInput.target, jumpIsReturn: jumpInput.isReturn};
  // Register BTB: read old state combinationally, train on this edge. SRAM
  // experiments remain standalone modules and do not add stages or credits here.
  rv32_bpu_btb #(
    .BTB_ENTRIES(BTB_ENTRIES)
  ) u_btb (
    .freezeInput(freezeInput),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .queryPcInput(queryPcInput),
    .lookupOutput(btbLookupOutputInner),
    .trainingInput(trainingBatchInner)
  );
  assign btbHitInner = btbLookupOutputInner.hit;
  assign btbUncondInner = btbLookupOutputInner.unconditional;
  assign btbRetInner = btbLookupOutputInner.isReturn;
  assign btbTgtInner = btbLookupOutputInner.target;

  rv32_bpu_ras #(
    .RAS_ENTRIES(RAS_ENTRIES), .COMMIT_WIDTH(COMMIT_WIDTH)
  ) u_ras (
    .freezeInput(freezeInput),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .fetchInfoInput(fetchInfoInput),
    .squashInput(squashInput),
    .robInput(robInput),
    .recoveryInput(recoveryInput),
    .rasTopOutput(rasTopInner),
    .queryRetTargetOutput(rasRetTargetInner)
  );

  rv32_bpu_checkpoint #(
    .CKPT_ENTRIES(CKPT_ENTRIES), .FETCH_WIDTH(FETCH_WIDTH)
  ) u_checkpoint (
    .freezeInput(freezeInput),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .secondAcceptedInput(fetchSecondInput),
    .acceptedCountInput(fetchCountInput),
    .checkpointInput('{fetchAccepted: fetchAcceptInput,
                      squash: squashInput,
                      branchCheckpointId: branchInput.checkpointId,
                      globalHistory: dirGhrInner}),
    .checkpointOutput(checkpointOutputInner),
    .queryContextInput(queryDirectionContextInner),
    .branchContextOutput(branchDirectionContextInner),
    .nextCheckpointIdOutput(predictionOutput.checkpointId)
  );
  assign branchGhrInner = checkpointOutputInner.branchHistory;
  assign ckptSquashGhrInner = checkpointOutputInner.recoveryHistory;

  // Unused direction confidence output is kept for observability only.
  logic unusedDirUseGlobalInner;
  assign unusedDirUseGlobalInner = dirUseGlobalInner;

  always_comb begin
    branchTrainInner = branchInput.valid && branchInput.robEntryLive &&
                   (!squashInput.valid || rob_is_older(branchInput.robTag,
                                                       squashInput.robTag));
    jumpTrainInner = jumpInput.valid && jumpInput.robEntryLive &&
                 (!squashInput.valid || rob_is_older(jumpInput.robTag,
                                                     squashInput.robTag));
  end

  always_comb begin
    queryDirTakenInner = dirTakenInner;
    queryBtbHitInner = btbHitInner;
    queryTakenInner = queryBtbHitInner && queryDirTakenInner;
    if (queryBtbHitInner && btbUncondInner)
      queryTakenInner = 1'b1;
    queryIsRetInner = btbRetInner;
    if (queryIsRetInner && rasTopInner == 0) begin
      queryBtbHitInner = 1'b0;
      queryTakenInner = 1'b0;
    end
    queryTargetInner = btbTgtInner;
    if (queryIsRetInner && rasTopInner != 0)
      queryTargetInner = rasRetTargetInner;
    queryShiftInner = queryBtbHitInner || dirCondseenInner;
    queryShiftValueInner = queryBtbHitInner ?
                        (btbUncondInner ? 1'b1 : queryTakenInner) :
                          (dirCondseenInner ? queryTakenInner : 1'b0);
    predictionOutput.taken = queryTakenInner;
    predictionOutput.nextProgramCounter = queryTakenInner ? queryTargetInner : queryPcInput + 32'd4;
  end
endmodule
