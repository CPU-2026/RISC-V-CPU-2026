module rv32_predictor #(
  parameter int unsigned BHT_ENTRIES = 256,
  parameter int unsigned BTB_ENTRIES = 64,
  parameter int unsigned RAS_ENTRIES = 8,
  parameter int unsigned CONDSEEN_ENTRIES = 512,
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES
) (
  input  logic                         clkInput,
  input  logic                         rstNInput,

  input  logic [31:0]                  queryPcInput,
  output rv32_pkg::prediction_output_t predictionOutput,

  // A checkpoint is allocated only when the frontend accepts this query.
  input  logic                         fetchAcceptInput,

  // Accepted fetch classification and execution-stage training arrive as
  // producer-owned payloads so related fields cannot be miswired separately.
  input  rv32_pkg::predictor_fetch_info_t fetchInfoInput,
  input  rv32_pkg::branch_result_input_t branchInput,
  input  rv32_pkg::jump_result_input_t   jumpInput,
  input  rv32_pkg::squash_input_t         squashInput,
  input  rv32_pkg::rob_predictor_input_t  robInput
);
  import rv32_pkg::*;

  logic dirTakenInner, dirUseGlobalInner, dirCondseenInner;
  logic [7:0] dirGhrInner;
  logic [7:0] branchGhrInner;
  direction_prediction_output_t directionOutputInner;

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

  rv32_bpu_direction #(
    .BHT_ENTRIES(BHT_ENTRIES),
    .CONDSEEN_ENTRIES(CONDSEEN_ENTRIES)
  ) u_direction (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .queryPcInput(queryPcInput),
    .branchInput('{valid: branchTrainInner,
                  programCounter: branchInput.programCounter,
                  nextProgramCounter: branchInput.nextProgramCounter,
                  taken: branchInput.taken,
                  globalHistory: branchGhrInner}),
    .historyInput('{fetchAccepted: fetchAcceptInput,
                   squashValid: squashInput.valid,
                   queryShift: queryShiftInner,
                   queryShiftValue: queryShiftValueInner,
                   recoveryHistory: ckptSquashGhrInner}),
    .predictionOutput(directionOutputInner)
  );
  assign dirTakenInner = directionOutputInner.directionTaken;
  assign dirUseGlobalInner = directionOutputInner.useGlobal;
  assign dirCondseenInner = directionOutputInner.conditionalSeen;
  assign dirGhrInner = directionOutputInner.globalHistory;

  rv32_bpu_btb #(
    .BTB_ENTRIES(BTB_ENTRIES)
  ) u_btb (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .queryPcInput(queryPcInput),
    .lookupOutput(btbLookupOutputInner),
    .trainingInput('{fetchValid: fetchInfoInput.valid,
                    isReturn: fetchInfoInput.isReturn,
                    jalTargetValid: fetchInfoInput.jalTargetValid,
                    fetchProgramCounter: fetchInfoInput.programCounter,
                    jalTarget: fetchInfoInput.jalTarget,
                    branch: '{valid: branchTrainInner,
                              programCounter: branchInput.programCounter,
                              nextProgramCounter: branchInput.nextProgramCounter,
                              taken: branchInput.taken,
                              globalHistory: branchGhrInner},
                    jumpValid: jumpTrainInner,
                    jumpProgramCounter: jumpInput.programCounter,
                    jumpTarget: jumpInput.target,
                    jumpIsReturn: jumpInput.isReturn})
  );
  assign btbHitInner = btbLookupOutputInner.hit;
  assign btbUncondInner = btbLookupOutputInner.unconditional;
  assign btbRetInner = btbLookupOutputInner.isReturn;
  assign btbTgtInner = btbLookupOutputInner.target;

  rv32_bpu_ras #(
    .RAS_ENTRIES(RAS_ENTRIES)
  ) u_ras (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .fetchInfoInput(fetchInfoInput),
    .squashInput(squashInput),
    .robInput(robInput),
    .rasTopOutput(rasTopInner),
    .queryRetTargetOutput(rasRetTargetInner)
  );

  rv32_bpu_checkpoint #(
    .CKPT_ENTRIES(CKPT_ENTRIES)
  ) u_checkpoint (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .checkpointInput('{fetchAccepted: fetchAcceptInput,
                      squash: squashInput,
                      branchCheckpointId: branchInput.checkpointId,
                      globalHistory: dirGhrInner}),
    .checkpointOutput(checkpointOutputInner)
  );
  assign branchGhrInner = checkpointOutputInner.branchHistory;
  assign ckptSquashGhrInner = checkpointOutputInner.recoveryHistory;
  assign predictionOutput.checkpointId = checkpointOutputInner.nextCheckpointId;

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
    if (queryIsRetInner && (rasTopInner == 16'd0)) begin
      queryBtbHitInner = 1'b0;
      queryTakenInner = 1'b0;
    end
    queryTargetInner = btbTgtInner;
    if (queryIsRetInner && (rasTopInner != 16'd0))
      queryTargetInner = rasRetTargetInner;
    queryShiftInner = queryBtbHitInner || dirCondseenInner;
    queryShiftValueInner = queryBtbHitInner ?
                        (btbUncondInner ? 1'b1 : queryTakenInner) :
                        (dirCondseenInner ? queryTakenInner : 1'b0);
    predictionOutput.taken = queryTakenInner;
    predictionOutput.nextProgramCounter = queryTakenInner ? queryTargetInner : (queryPcInput + 32'd4);
  end
endmodule
