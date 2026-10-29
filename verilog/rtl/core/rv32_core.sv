module rv32_core #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter bit TAGGED_DMEM = 1'b0,
  parameter bit LEGACY_HALT = 1'b0,
  parameter int unsigned FETCH_WIDTH = rv32_pkg::FETCH_WIDTH,
  parameter int unsigned COMMIT_WIDTH = rv32_pkg::COMMIT_WIDTH,
  parameter int unsigned DECODE_WIDTH = rv32_pkg::DECODE_WIDTH,
  parameter int unsigned RENAME_WIDTH = rv32_pkg::RENAME_WIDTH,
  parameter int unsigned FQ_DEPTH = rv32_pkg::default_fq_entries(DECODE_WIDTH),
  parameter int unsigned IQ_DEPTH = rv32_pkg::default_iq_entries(DECODE_WIDTH),
  // RENAME_WIDTH is the legacy default; an explicit ISSUE_WIDTH selects the
  // implementation without changing existing positional parameter arguments.
  parameter int unsigned ISSUE_WIDTH = RENAME_WIDTH
) (
  input  logic             clkInput,
  input  logic             rstNInput,

  output logic             imemReqValidOutput,
  input  logic             imemReqReadyInput,
  output logic [31:0]      imemReqAddrOutput,
  input  logic             imemRspValidInput,
  input  logic [31:0]      imemRspDataInput,
  input logic [31:0] imemRspSecondDataInput,
  input rv32_pkg::icache_fetch_hint_t imemFetchHintInput,
  output logic imemSecondRequestOutput,
  output logic             imemRspReadyOutput,
  output logic             imemFlushOutput,
  output rv32_pkg::icache_cpu_request_input_t imemCacheRequestOutput,

  output logic             dmemReqValidOutput,
  input  logic             dmemReqReadyInput,
  output logic             dmemReqWriteOutput,
  output logic [31:0]      dmemReqAddrOutput,
  output logic [31:0]      dmemReqWdataOutput,
  output logic [3:0]       dmemReqWstrbOutput,
  output logic [1:0]       dmemReqSizeOutput,
  input  logic             dmemRspValidInput,
  input  logic [31:0]      dmemRspRdataInput,
  output rv32_pkg::data_transaction_t dmemReqTransactionOutput,
  input rv32_pkg::data_transaction_t dmemRspTransactionInput,

  output logic             commitValidOutput,
  output logic [31:0]      commitPcOutput,
  output logic [31:0]      commitInstrOutput,
  output logic             commitRdValidOutput,
  output logic [4:0]       commitRdOutput,
  output logic [31:0]      commitRdValueOutput,
  output logic             commitMemValidOutput,
  output logic [31:0]      commitMemAddrOutput,
  output logic [31:0]      commitMemDataOutput,
  output logic [3:0]       commitMemWstrbOutput,
  output rv32_pkg::retirement_trace_t [COMMIT_WIDTH-1:0] retirementOutput,

  output logic             haltedOutput,
  output logic             trapOutput,
  input logic [127:0] imemRspPacketDataInput,
  output logic [2:0] imemFetchCountOutput
);
  import rv32_pkg::*;
  localparam int unsigned ALU_LANES=rv32_pkg::ALU_UNITS;
  localparam int unsigned ROB_LOOKUP_PORTS=ALU_CDB_PORTS==2 ? 6 : 5;
  if (ALU_LANES!=1 && ALU_LANES!=2) begin : g_invalid_alu_count
    initial $fatal(1,"ALU_UNITS must be 1 or 2");
  end
  if ((ALU_CDB_PORTS!=1 && ALU_CDB_PORTS!=2) ||
      (ALU_CDB_PORTS==2 && (ALU_LANES!=2 || ISSUE_WIDTH!=4))) begin : g_invalid_alu_cdb_count
    initial $fatal(1,"two independent ALU CDBs require two ALUs and the array backend");
  end

  rv32_issue_config #(.ISSUE_WIDTH(ISSUE_WIDTH)) u_issue_config ();
  // Ordered issue4 selects the integrated array backend below; package types
  // and capacities are checked once per compilation, with no runtime mode mux.

  logic [31:0] predictorPcInner;
  bpu_ckpt_id_t iqPredictorCkptIdInner;
  logic predictorFetchAcceptInner;
  logic predictorFetchPredictInner,frontendSecondRequestInner;
  logic [2:0] frontendFetchCountInner;
  rv32_pkg::fetch_query_output_t predictorQueryOutputInner;
  rv32_pkg::instruction_memory_request_output_t frontendImemRequestOutputInner;
  rv32_pkg::instruction_memory_response_input_t frontendImemResponseInputInner;
  rv32_pkg::redirect_input_t frontendRedirectInputInner;
  rv32_pkg::fetch_queue_output_t frontendInstructionOutputInner;
  rv32_pkg::predictor_fetch_info_t fetchInfoOutputInner;
  logic frontendIqValidInner, frontendIqReadyInner;
  logic [31:0] iqPcInner, iqInstrInner, iqPredictedPcInner;
  decode_context_t decodeContextInner;
  predictor_fetch_info_t predictorFetchInfoInner;
  branch_result_input_t predictorBranchInputInner;
  jump_result_input_t predictorJumpInputInner;
  rv32_pkg::flush_candidate_input_t branchFlushInputInner;
  rv32_pkg::flush_candidate_input_t jumpFlushInputInner;
  squash_input_t predictorSquashInputInner;
  rob_predictor_input_t [COMMIT_WIDTH-1:0] predictorRobInputInner;
  prediction_output_t predictorOutputInner;
  decoded_uop_t decodedInner;
  decoded_uop_t frontendDecodedInner;
  fetch_queue_output_t frontendSecondInstructionInner;
  decoded_uop_t decodedSecondInner;
  logic issueSecondFireInner, issueSecondResourcesReadyInner, targetSecondRsReadyInner;
  logic issueSecondIsJumpInner, issueSecondIsReturnInner;
  logic issueSecondSrc1ReadyInner, issueSecondSrc2ReadyInner;
  logic [31:0] issueSecondSrc1ValueInner, issueSecondSrc2ValueInner, issueSecondLinkValueInner;
  phy_tag_t issueSecondSrc1PhyInner, issueSecondSrc2PhyInner, issueSecondDestPhyInner;
  rat_read_input_t ratReadSecondInputInner;
  rat_read_output_t ratReadSecondOutputInner;
  rat_rename_input_t ratRenameSecondInputInner;
  rat_rename_output_t ratRenameSecondOutputInner;
  prf_allocation_input_t prfAllocSecondInputInner;
  phy_tag_t prfAllocSecondPhyInner, ratSecondOldPhyInner;
  logic prfAllocSecondReadyInner, robAllocSecondReadyInner;
  rob_tag_t robAllocSecondTagInner;
  rob_allocation_input_t robAllocSecondInputInner;
  rs_allocation_input_t rsAllocSecondBaseInner;
  rs_allocation_input_t intRsAllocSecondInputInner, mulRsAllocSecondInputInner, divRsAllocSecondInputInner;
  rs_allocation_input_t branchRsAllocSecondInputInner, loadRsAllocSecondInputInner;
  rs_allocation_input_t saRsAllocSecondInputInner, svRsAllocSecondInputInner;
  logic intAllocSecondReadyInner, mulAllocSecondReadyInner, divAllocSecondReadyInner, branchAllocSecondReadyInner;
  logic loadRsAllocSecondReadyInner, saRsAllocSecondReadyInner, svRsAllocSecondReadyInner;
  load_allocation_input_t lsuLoadAllocationSecondInputInner;
  store_allocation_input_t lsuStoreAllocationSecondInputInner;
  logic lqAllocSecondReadyInner, sqAllocSecondReadyInner;
  logic [2:0] lqAllocSecondIndexInner, sqAllocSecondIndexInner;

  decoded_uop_t [3:0] wideDecodedInner;
  logic [3:0] wideValidInner,wideFireInner;
  logic [2:0] wideIssueCountInner;
  rs_allocation_input_t [6:0][3:0] wideRsAllocInner;
  logic [6:0][3:0][3:0] wideRsAuxInner;
  logic [6:0][3:0] wideRsFireInner;
  logic [6:0][$clog2(ROB_ENTRIES+1)-1:0] wideRsCreditsInner;
  logic [$clog2(INT_RS_ENTRIES+1)-1:0] wideIntCreditsInner;
  logic [$clog2(MUL_RS_ENTRIES+1)-1:0] wideMulCreditsInner;
  logic [$clog2(DIV_RS_ENTRIES+1)-1:0] wideDivCreditsInner;
  logic [$clog2(BRANCH_RS_ENTRIES+1)-1:0] wideBranchCreditsInner;
  logic [$clog2(LOAD_RS_ENTRIES+1)-1:0] wideLoadRsCreditsInner;
  logic [$clog2(STORE_ADDR_RS_ENTRIES+1)-1:0] wideSaCreditsInner;
  logic [$clog2(STORE_VALUE_RS_ENTRIES+1)-1:0] wideSvCreditsInner;
  logic [3:0] wideIntAuxInner,wideMulAuxInner,wideDivAuxInner;
  logic [3:0][2:0] wideBranchAuxInner,wideSvAuxInner;
  logic [3:0][3:0] wideLoadAuxInner,wideSaAuxInner;
  load_allocation_input_t [3:0] wideLoadAllocInner;
  store_allocation_input_t [3:0] wideStoreAllocInner;
  logic [3:0] wideLoadFireInner,wideStoreFireInner;
  logic [3:0][$clog2(LQ_ENTRIES)-1:0] wideLoadPreviewInner;
  logic [3:0][$clog2(SQ_ENTRIES)-1:0] wideStorePreviewInner;
  logic [$clog2(LQ_ENTRIES+1)-1:0] wideLoadCreditsInner;
  logic [$clog2(SQ_ENTRIES+1)-1:0] wideStoreCreditsInner;
  assign wideRsCreditsInner[0]=$clog2(ROB_ENTRIES+1)'(wideIntCreditsInner);
  assign wideRsCreditsInner[1]=$clog2(ROB_ENTRIES+1)'(wideMulCreditsInner);
  assign wideRsCreditsInner[2]=$clog2(ROB_ENTRIES+1)'(wideDivCreditsInner);
  assign wideRsCreditsInner[3]=$clog2(ROB_ENTRIES+1)'(wideBranchCreditsInner);
  assign wideRsCreditsInner[4]=$clog2(ROB_ENTRIES+1)'(wideLoadRsCreditsInner);
  assign wideRsCreditsInner[5]=$clog2(ROB_ENTRIES+1)'(wideSaCreditsInner);
  assign wideRsCreditsInner[6]=$clog2(ROB_ENTRIES+1)'(wideSvCreditsInner);
  for(genvar lane=0;lane<4;lane++)begin : g_wide_aux_wires
    assign wideIntAuxInner[lane]=wideRsAuxInner[0][lane][0];
    assign wideMulAuxInner[lane]=wideRsAuxInner[1][lane][0];
    assign wideDivAuxInner[lane]=wideRsAuxInner[2][lane][0];
    assign wideBranchAuxInner[lane]=wideRsAuxInner[3][lane][2:0];
    assign wideLoadAuxInner[lane]=wideRsAuxInner[4][lane];
    assign wideSaAuxInner[lane]=wideRsAuxInner[5][lane];
    assign wideSvAuxInner[lane]=wideRsAuxInner[6][lane][2:0];
  end

  phy_tag_t ratRs1PhyInner, ratRs2PhyInner, ratOldPhyInner;
  rv32_pkg::rat_read_input_t ratReadInputInner;
  rv32_pkg::rat_read_output_t ratReadOutputInner;
  rv32_pkg::rat_rename_input_t ratRenameInputInner;
  rv32_pkg::rat_rename_output_t ratRenameOutputInner;
  rv32_pkg::rat_restore_input_t ratRestoreInputInner;
  rv32_pkg::rat_commit_input_t [COMMIT_WIDTH-1:0] ratCommitInputInner;
  rv32_pkg::prf_free_input_t [COMMIT_WIDTH-1:0] retirementFreeInner;
  rv32_pkg::rob_retirement_input_t [COMMIT_WIDTH-1:0] retirementInputInner;
  rv32_pkg::store_commit_input_t [COMMIT_WIDTH-1:0] retirementStoreInputInner;
  rv32_pkg::data_memory_request_output_t [COMMIT_WIDTH-1:0] retirementMemoryInner;
  logic [COMMIT_WIDTH-1:0][2:0] retirementSqIndexInner;
  logic [COMMIT_WIDTH-1:0] retirementReadyInner, retirementFireInner, retirementStoreInner;
  logic [COMMIT_WIDTH-1:0] retirementStoreReadyInner;
  phy_tag_t prfAllocPhyInner;
  logic prfAllocReadyInner;
  logic prfSrc1ReadyInner, prfSrc2ReadyInner, prfCommitReadyInner;
  logic [31:0] prfSrc1ValueInner, prfSrc2ValueInner, prfCommitValueInner;
  logic [PRF_ENTRIES-1:0] prfReadyVectorInner;
  rv32_pkg::cdb_result_t [WRITEBACK_PORTS-1:0] writebackInputInner;
  logic [WRITEBACK_PORTS-1:0] writebackValidInner;
  for (genvar portIndex=0;portIndex<WRITEBACK_PORTS;portIndex++) begin : g_wb_valid
    assign writebackValidInner[portIndex]=writebackInputInner[portIndex].valid;
  end
  rv32_pkg::cdb_result_t [2:0] sharedCdbCandidatesInner;
  rv32_pkg::rob_tag_t [2:0] sharedCdbTagsInner;
  rv32_pkg::rob_tag_t sharedCdbTagInner;
  logic [2:0] sharedCdbGrantInner;
  logic loadResultEligibleInner, mulResultEligibleInner, divResultEligibleInner;
  rv32_pkg::prf_read_input_t [COMMIT_WIDTH+3:0] prfReadInputInner;
  rv32_pkg::prf_read_output_t [COMMIT_WIDTH+3:0] prfReadOutputInner;

  rob_tag_t robAllocTagInner, robHeadTagInner;
  wire rv32_pkg::rob_replay_narrow_t [RECOVERY_WIDTH-1:0] robReplayNarrowInner;
  wire rv32_pkg::rob_replay_ras_t [RECOVERY_WIDTH-1:0] robReplayRasInner;
  rv32_pkg::rob_allocation_input_t robAllocInputInner;
  rv32_pkg::rob_completion_t [5:0] robCompletionInputInner;
  rv32_pkg::rob_lookup_input_t [ROB_LOOKUP_PORTS-1:0] robLookupInputInner;
  rv32_pkg::rob_lookup_output_t [ROB_LOOKUP_PORTS-1:0] robLookupOutputInner;
  rob_lookup_output_t jumpLookupInner;
  rv32_pkg::rob_commit_output_t [COMMIT_WIDTH-1:0] robCommitOutputInner;
  rv32_pkg::rob_status_output_t robStatusOutputInner;
  logic robAllocReadyInner;
  logic robCommitValidInner, robCommitReadyInner, robCommitFireInner;
  logic robCommitFireOutputInner;
  rob_tag_t robCommitTagInner;
  logic [31:0] robCommitPcInner, robCommitInstrInner;
  logic robCommitWritesInner;
  logic [4:0] robCommitRdInner;
  phy_tag_t robCommitNewPhyInner, robCommitOldPhyInner;
  logic robCommitStoreInner;
  logic robCommitIsCallInner, robCommitIsRetInner;
  logic [2:0] robCommitSqIndexInner;
  logic robCommitHaltInner;
  logic robEmptyInner, robFullInner;
  logic [$clog2(ROB_ENTRIES+1)-1:0] robCountInner;

  logic issueFireInner, issueResourcesReadyInner;
  logic targetRsReadyInner;
  logic issueIsJumpInner, issueIsCallInner, issueIsReturnInner;
  logic issueSrc1ReadyInner, issueSrc2ReadyInner;
  logic [31:0] issueSrc1ValueInner, issueSrc2ValueInner;
  phy_tag_t issueDestPhyInner;

  logic globalFlushInner;
  rob_tag_t globalFlushTagInner;
  logic [31:0] globalRedirectPcInner;
  bpu_ckpt_id_t globalFlushCkptIdInner;
  rv32_pkg::squash_input_t flushOutputInner;
  recovery_step_t recoveryStepInner;
  logic recoveryBusyInner, pipelineFrozenInner;
  logic frontendFrozenInner;
  logic branchFlushCandidateInner, jumpFlushCandidateInner;
  logic [31:0] branchFlushPcInner, jumpFlushPcInner;
  logic predictorUpdateValidInner, predictorMispredictInner;

  logic wbAluValidInner, wbLoadValidInner, wbMulValidInner, wbDivValidInner;
  rv32_pkg::alu_execute_output_t aluExecuteOutputInner;
  alu_execute_output_t aluLaneResultInner [ALU_LANES];
  execute_request_input_t aluLaneRequestInner [ALU_LANES];
  rs_issue_output_t intIssueLaneInner [ALU_LANES];
  logic [0:0] intIssueLaneAuxInner [ALU_LANES];
  logic [ALU_LANES-1:0] intIssueLaneValidInner,intIssueLaneReadyInner;
  logic [ALU_LANES-1:0] aluInputReadyInner,aluResultGrantInner,aluPopReadyInner,aluIssueFireInner;
  logic aluSecondWinsInner;
  rv32_pkg::execute_value_output_t mulExecuteOutputInner;
  rv32_pkg::bru_execute_output_t bruExecuteOutputInner;
  rv32_pkg::execute_value_output_t divExecuteOutputInner;
  logic loadCdbValidInner, mulCdbValidInner, divCdbValidInner;
  logic aluRobLiveInner, loadRobLiveInner, mulRobLiveInner, divRobLiveInner;
  logic aluResultLiveInner, branchResultLiveInner;
  rob_tag_t wbAluTagInner, wbLoadTagInner, wbMulTagInner, wbDivTagInner;
  phy_tag_t wbAluPhyInner, wbLoadPhyInner, wbMulPhyInner, wbDivPhyInner;
  logic [31:0] wbAluValueInner, wbLoadValueInner, wbMulValueInner, wbDivValueInner;
  logic aluCdbValidInner, aluCdbIsControlInner;

  logic intAllocReadyInner, intIssueValidInner, intIssueReadyInner;
  operation_e intIssueOpInner;
  rob_tag_t intIssueTagInner;
  phy_tag_t intIssuePhyInner;
  logic [31:0] intIssueS1Inner, intIssueS2Inner, intIssueImmInner;
  logic [31:0] intIssuePcInner, intIssuePredInner;
  logic intIssueUseImmInner;
  logic [0:0] intIssueAuxInner;
  rs_allocation_input_t rsAllocBaseInner;
  rs_allocation_input_t intRsAllocInputInner, mulRsAllocInputInner;
  rs_allocation_input_t divRsAllocInputInner, branchRsAllocInputInner;
  rs_allocation_input_t memRsAllocInputInner;
  rs_issue_output_t intRsIssueOutputInner, mulRsIssueOutputInner;
  rs_issue_output_t divRsIssueOutputInner, branchRsIssueOutputInner;
  rs_issue_output_t memRsIssueOutputInner;

  logic mulAllocReadyInner, mulIssueValidInner, mulIssueReadyInner;
  operation_e mulIssueOpInner;
  rob_tag_t mulIssueTagInner;
  phy_tag_t mulIssuePhyInner;
  logic [31:0] mulIssueS1Inner, mulIssueS2Inner, mulIssueImmInner;
  logic [31:0] mulIssuePcInner, mulIssuePredInner;
  logic mulIssueUseImmInner;
  logic [0:0] mulIssueAuxInner;

  logic divAllocReadyInner, divIssueValidInner, divIssueReadyInner;
  operation_e divIssueOpInner;
  rob_tag_t divIssueTagInner;
  phy_tag_t divIssuePhyInner;
  logic [31:0] divIssueS1Inner, divIssueS2Inner, divIssueImmInner;
  logic [31:0] divIssuePcInner, divIssuePredInner;
  logic divIssueUseImmInner;
  logic [0:0] divIssueAuxInner;

  logic branchAllocReadyInner, branchIssueValidInner, branchIssueReadyInner;
  operation_e branchIssueOpInner;
  rob_tag_t branchIssueTagInner;
  phy_tag_t branchIssuePhyInner;
  logic [31:0] branchIssueS1Inner, branchIssueS2Inner, branchIssueImmInner;
  logic [31:0] branchIssuePcInner, branchIssuePredInner;
  logic branchIssueUseImmInner;
  logic [2:0] branchIssueAuxInner;

  logic memIssueReadyInner;
  logic [3:0] memIssueAuxInner;
  rs_allocation_input_t loadRsAllocInputInner, saRsAllocInputInner, svRsAllocInputInner;
  rs_issue_output_t loadRsIssueOutputInner, saRsIssueOutputInner, svRsIssueOutputInner;
  logic loadRsAllocReadyInner, saRsAllocReadyInner, svRsAllocReadyInner;
  // storeValue presents one lane per RS slot; the store queue takes all of them
  // in the same cycle, so a burst of stores whose data resolves together no
  // longer drains one per cycle.
  logic [STORE_VALUE_RS_ENTRIES-1:0] svRsIssueLaneValidInner;
  rs_issue_output_t svRsIssueLaneInner [STORE_VALUE_RS_ENTRIES];
  logic [2:0] svRsIssueLaneAuxInner [STORE_VALUE_RS_ENTRIES];
  store_data_input_t svRsStoreDataInner [STORE_VALUE_RS_ENTRIES];
  logic [2:0] svRsStoreDataIndexInner [STORE_VALUE_RS_ENTRIES];
  logic chooseLoadInner, loadRsIssueReadyInner, saRsIssueReadyInner;
  logic [3:0] loadAuxInner, saAuxInner;
  logic [2:0] svAuxInner;
  logic [3:0] aguResultAuxInner;

  logic bruValidInner, bruTakenInner, bruConditionalInner, bruMispredictInner;
  rob_tag_t bruTagInner;
  logic [31:0] bruPcInner, bruNextPcInner;

  logic bruRobLiveInner, jumpRobLiveInner;
  logic [31:0] bruRobPcInner, bruRobPredictedPcInner;
  logic [31:0] jumpRobPcInner, jumpRobPredictedPcInner;
  bpu_ckpt_id_t bruRobCkptIdInner, jumpRobCkptIdInner;
  logic bruRobIsRetInner, jumpRobIsRetInner;

  logic lqAllocReadyInner, sqAllocReadyInner;
  logic [2:0] lqAllocIndexInner, sqAllocIndexInner;
  logic lsuStoreCommitReadyInner;
  rv32_pkg::load_allocation_input_t lsuLoadAllocationInputInner;
  rv32_pkg::store_allocation_input_t lsuStoreAllocationInputInner;
  rv32_pkg::lsu_address_input_t lsuAddressInputInner;
  rv32_pkg::lsu_address_input_t aguAddressOutputInner;
  rv32_pkg::store_commit_input_t lsuStoreCommitInputInner;
  rv32_pkg::load_result_output_t lsuLoadResultOutputInner;
  rv32_pkg::store_completion_output_t lsuStoreCompleteOutputInner;
  rv32_pkg::data_memory_request_output_t lsuDmemRequestOutputInner;
  rv32_pkg::data_memory_request_output_t lsuStoreRetirementOutputInner;
  rv32_pkg::data_memory_response_input_t lsuDmemResponseInputInner;
  logic [3:0] sqCountInner;

  logic haltedInner;
  logic bootDoneInner;
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) bootDoneInner <= 1'b0;
    else bootDoneInner <= 1'b1;
  end
  logic [31:0] issueLinkValueInner;
  logic unusedCoutLinkInner;
  integer robInputIndexInner;
  integer storeLaneInner;

  assign aluRobLiveInner = jumpRobLiveInner;
  assign aluResultLiveInner = !pipelineFrozenInner && aluCdbValidInner && aluRobLiveInner &&
                           (!globalFlushInner ||
                            rob_is_older(wbAluTagInner, globalFlushTagInner));
  assign wbAluValidInner = aluResultLiveInner && !aluCdbIsControlInner;
  // Both registered ALU results compete for the original CDB0. Oldest wins;
  // an ungranted result stays in its own producer register. JAL/JALR use the
  // same grant before ROB completion/redirect training (their link is ready
  // from rename), so a waiting control result cannot resolve repeatedly.
  generate if (ALU_CDB_PORTS==2) begin : g_independent_alu_results
    logic [1:0] live;
    // Arithmetic results broadcast independently. The existing single jump
    // predictor/redirect port selects the oldest CONTROL result only; a second
    // simultaneous JAL/JALR holds without blocking an arithmetic result.
    assign aluSecondWinsInner=aluLaneResultInner[1].valid && aluLaneResultInner[1].isControl &&
      (!(aluLaneResultInner[0].valid && aluLaneResultInner[0].isControl) ||
        rob_is_older(aluLaneResultInner[1].robTag,aluLaneResultInner[0].robTag));
    assign aluExecuteOutputInner=aluSecondWinsInner ? aluLaneResultInner[1] : aluLaneResultInner[0];
    assign jumpLookupInner=aluSecondWinsInner ? robLookupOutputInner[5] : robLookupOutputInner[1];
    assign live[0]=!pipelineFrozenInner && aluLaneResultInner[0].valid && robLookupOutputInner[1].valid &&
      (!globalFlushInner || rob_is_older(aluLaneResultInner[0].robTag,globalFlushTagInner));
    assign live[1]=!pipelineFrozenInner && aluLaneResultInner[1].valid && robLookupOutputInner[5].valid &&
      (!globalFlushInner || rob_is_older(aluLaneResultInner[1].robTag,globalFlushTagInner));
    assign aluResultGrantInner[0]=live[0] && (!aluLaneResultInner[0].isControl || !aluSecondWinsInner);
    assign aluResultGrantInner[1]=live[1] && (!aluLaneResultInner[1].isControl || aluSecondWinsInner);
    assign aluPopReadyInner[0]=!pipelineFrozenInner &&
      (aluResultGrantInner[0] || (aluLaneResultInner[0].valid && !robLookupOutputInner[1].valid));
    assign aluPopReadyInner[1]=!pipelineFrozenInner &&
      (aluResultGrantInner[1] || (aluLaneResultInner[1].valid && !robLookupOutputInner[5].valid));
  end else if (ALU_LANES==2) begin : g_dual_alu_result
    assign jumpLookupInner=robLookupOutputInner[1];
    assign aluSecondWinsInner=aluLaneResultInner[1].valid &&
      (!aluLaneResultInner[0].valid || rob_is_older(aluLaneResultInner[1].robTag,aluLaneResultInner[0].robTag));
    assign aluExecuteOutputInner=aluSecondWinsInner ? aluLaneResultInner[1] : aluLaneResultInner[0];
    assign aluResultGrantInner[0]=aluResultLiveInner && !aluSecondWinsInner;
    assign aluResultGrantInner[1]=aluResultLiveInner && aluSecondWinsInner;
    // A stale selected identity may be drained without a CDB/ROB side effect.
    // Other cancelled entries are removed by the ordinary producer flush.
    assign aluPopReadyInner[0]=!pipelineFrozenInner && !aluSecondWinsInner &&
      (aluResultLiveInner || (aluLaneResultInner[0].valid && !aluRobLiveInner));
    assign aluPopReadyInner[1]=!pipelineFrozenInner && aluSecondWinsInner &&
      (aluResultLiveInner || (aluLaneResultInner[1].valid && !aluRobLiveInner));
  end else begin : g_single_alu_result
    assign jumpLookupInner=robLookupOutputInner[1];
    assign aluSecondWinsInner=1'b0;
    assign aluExecuteOutputInner=aluLaneResultInner[0];
    assign aluResultGrantInner[0]=aluResultLiveInner;
    assign aluPopReadyInner[0]=1'b1;
  end endgenerate
  assign loadResultEligibleInner = !recoveryBusyInner && loadCdbValidInner && loadRobLiveInner &&
                         (!globalFlushInner ||
                          rob_is_older(wbLoadTagInner, globalFlushTagInner));
  assign mulResultEligibleInner = !recoveryBusyInner && mulCdbValidInner && mulRobLiveInner &&
                        (!globalFlushInner ||
                         rob_is_older(wbMulTagInner, globalFlushTagInner));
  assign divResultEligibleInner = !recoveryBusyInner && divCdbValidInner && divRobLiveInner &&
                        (!globalFlushInner ||
                         rob_is_older(wbDivTagInner, globalFlushTagInner));
  assign branchResultLiveInner = !recoveryBusyInner && bruValidInner && bruConditionalInner && bruRobLiveInner &&
                              (!globalFlushInner ||
                               rob_is_older(bruTagInner, globalFlushTagInner));
  assign branchFlushCandidateInner = branchResultLiveInner && bruMispredictInner;
  assign branchFlushPcInner = bruNextPcInner;
  assign jumpFlushCandidateInner = aluResultLiveInner && aluCdbIsControlInner &&
                                  (wbAluValueInner != jumpRobPredictedPcInner);
  assign jumpFlushPcInner = wbAluValueInner;
  assign predictorUpdateValidInner = branchResultLiveInner ||
                                  (aluResultLiveInner && aluCdbIsControlInner);
  assign predictorMispredictInner = branchFlushCandidateInner || jumpFlushCandidateInner;
  assign globalFlushInner = flushOutputInner.valid && !recoveryBusyInner && !haltedInner;
  assign recoveryBusyInner = recoveryStepInner.active;
  assign pipelineFrozenInner = haltedInner || recoveryBusyInner;
  // During architectural replay, only fetch known non-control hit packets.
  // This hides frontend refill time without consuming calls/returns while
  // the speculative RAS is still being reconstructed. Backend stays frozen.
  assign frontendFrozenInner = haltedInner || (recoveryBusyInner &&
    !(FETCH_WIDTH == 2 && !LEGACY_HALT && imemFetchHintInput.hit &&
      !imemFetchHintInput.firstControl && !imemFetchHintInput.secondControl));
  assign globalFlushTagInner = flushOutputInner.robTag;
  assign globalRedirectPcInner = flushOutputInner.programCounter;
  assign globalFlushCkptIdInner = flushOutputInner.checkpointId;
  rv32_recovery_cursor u_recovery_cursor (
    .clkInput(clkInput), .rstNInput(rstNInput), .freezeInput(haltedInner),
    .startInput(globalFlushInner), .headTagInput(robHeadTagInner),
    .squashTagInput(globalFlushTagInner), .countInput(robCountInner),
    .stepOutput(recoveryStepInner)
  );
  assign robCommitIsCallInner =
    ((robCommitInstrInner[6:0] == OPCODE_JAL) ||
     ((robCommitInstrInner[6:0] == OPCODE_JALR) &&
      (robCommitInstrInner[14:12] == 3'b000))) &&
    ((robCommitInstrInner[11:7] == 5'd1) ||
     (robCommitInstrInner[11:7] == 5'd5));
  assign robCommitIsRetInner =
    (robCommitInstrInner[6:0] == OPCODE_JALR) &&
    (robCommitInstrInner[14:12] == 3'b000) &&
     ((robCommitInstrInner[19:15] == 5'd1) ||
      (robCommitInstrInner[19:15] == 5'd5));
  always_comb begin
    predictorRobInputInner = '0;
    for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
      predictorRobInputInner[lane].willCommit = retirementFireInner[lane];
      predictorRobInputInner[lane].headTag = robCommitOutputInner[lane].robTag;
      predictorRobInputInner[lane].isHeadCall =
        ((robCommitOutputInner[lane].instruction[6:0] == OPCODE_JAL) ||
         (robCommitOutputInner[lane].instruction[6:0] == OPCODE_JALR &&
          robCommitOutputInner[lane].instruction[14:12] == 0)) &&
        (robCommitOutputInner[lane].instruction[11:7] == 1 || robCommitOutputInner[lane].instruction[11:7] == 5);
      predictorRobInputInner[lane].isHeadReturn = robCommitOutputInner[lane].instruction[6:0] == OPCODE_JALR &&
        robCommitOutputInner[lane].instruction[14:12] == 0 &&
        (robCommitOutputInner[lane].instruction[19:15] == 1 || robCommitOutputInner[lane].instruction[19:15] == 5);
      predictorRobInputInner[lane].headProgramCounter = robCommitOutputInner[lane].programCounter;
    end
    for (robInputIndexInner = 0; robInputIndexInner < RECOVERY_WIDTH;
         robInputIndexInner = robInputIndexInner + 1)
      predictorRobInputInner[0].replayRasWindow[robInputIndexInner] =
        robReplayRasInner[robInputIndexInner];
  end
  assign predictorFetchInfoInner = fetchInfoOutputInner;
  assign predictorBranchInputInner = '{
    valid: branchResultLiveInner,
    robTag: bruTagInner,
    robEntryLive: bruRobLiveInner,
    programCounter: bruPcInner,
    nextProgramCounter: bruNextPcInner,
    taken: bruTakenInner,
    checkpointId: bruRobCkptIdInner
  };
  assign predictorJumpInputInner = '{
    valid: aluResultLiveInner && aluCdbIsControlInner,
    robTag: wbAluTagInner,
    robEntryLive: jumpRobLiveInner,
    programCounter: jumpRobPcInner,
    target: wbAluValueInner,
    isReturn: jumpRobIsRetInner
  };
  assign branchFlushInputInner = '{valid: branchFlushCandidateInner,
                                   robTag: bruTagInner,
                                   programCounter: branchFlushPcInner,
                                   checkpointId: bruRobCkptIdInner};
  assign jumpFlushInputInner = '{valid: jumpFlushCandidateInner,
                                 robTag: wbAluTagInner,
                                 programCounter: jumpFlushPcInner,
                                 checkpointId: jumpRobCkptIdInner};
  assign predictorSquashInputInner = '{
    valid: globalFlushInner,
    robTag: globalFlushTagInner,
    programCounter: globalRedirectPcInner,
    checkpointId: globalFlushCkptIdInner
  };
  generate if (ALU_CDB_PORTS==2) begin : g_alu_writebacks
    for (genvar lane=0;lane<2;lane++) begin : g_port
      assign writebackInputInner[lane]='{valid:aluResultGrantInner[lane] && !aluLaneResultInner[lane].isControl,
        phyTag:aluLaneResultInner[lane].destinationPhy,value:aluLaneResultInner[lane].value};
    end
  end else begin : g_shared_alu_writeback
    assign writebackInputInner[0]='{valid:wbAluValidInner,phyTag:wbAluPhyInner,value:wbAluValueInner};
  end endgenerate
  assign sharedCdbCandidatesInner[0] = '{valid: mulResultEligibleInner,
                                        phyTag: wbMulPhyInner, value: wbMulValueInner};
  assign sharedCdbCandidatesInner[1] = '{valid: divResultEligibleInner,
                                        phyTag: wbDivPhyInner, value: wbDivValueInner};
  assign sharedCdbCandidatesInner[2] = '{valid: loadResultEligibleInner,
                                        phyTag: wbLoadPhyInner, value: wbLoadValueInner};
  assign sharedCdbTagsInner[0] = wbMulTagInner;
  assign sharedCdbTagsInner[1] = wbDivTagInner;
  assign sharedCdbTagsInner[2] = wbLoadTagInner;
  rv32_cdb_arbiter u_shared_cdb (
    .candidateInput(sharedCdbCandidatesInner), .candidateTagInput(sharedCdbTagsInner),
    .resultOutput(writebackInputInner[ALU_CDB_PORTS]), .robTagOutput(sharedCdbTagInner),
    .grantOutput(sharedCdbGrantInner)
  );
  assign wbMulValidInner = sharedCdbGrantInner[0];
  assign wbDivValidInner = sharedCdbGrantInner[1];
  assign wbLoadValidInner = sharedCdbGrantInner[2];
  assign aluCdbValidInner = aluExecuteOutputInner.valid;
  assign wbAluValueInner = aluExecuteOutputInner.value;
  assign wbAluTagInner = aluExecuteOutputInner.robTag;
  assign wbAluPhyInner = aluExecuteOutputInner.destinationPhy;
  assign aluCdbIsControlInner = aluExecuteOutputInner.isControl;
  assign mulCdbValidInner = mulExecuteOutputInner.valid;
  assign wbMulValueInner = mulExecuteOutputInner.value;
  assign wbMulTagInner = mulExecuteOutputInner.robTag;
  assign wbMulPhyInner = mulExecuteOutputInner.destinationPhy;
  assign divCdbValidInner = divExecuteOutputInner.valid;
  assign wbDivValueInner = divExecuteOutputInner.value;
  assign wbDivTagInner = divExecuteOutputInner.robTag;
  assign wbDivPhyInner = divExecuteOutputInner.destinationPhy;
  assign bruValidInner = bruExecuteOutputInner.valid;
  assign bruTagInner = bruExecuteOutputInner.robTag;
  assign bruPcInner = bruExecuteOutputInner.programCounter;
  assign bruNextPcInner = bruExecuteOutputInner.nextProgramCounter;
  assign bruTakenInner = bruExecuteOutputInner.taken;
  assign bruConditionalInner = bruExecuteOutputInner.conditional;
  assign bruMispredictInner = bruExecuteOutputInner.mispredict;
  assign prfReadInputInner[0] = '{physicalRegister: ratRs1PhyInner};
  assign prfReadInputInner[1] = '{physicalRegister: ratRs2PhyInner};
  assign prfSrc1ReadyInner = prfReadOutputInner[0].ready;
  assign prfSrc1ValueInner = prfReadOutputInner[0].value;
  assign prfSrc2ReadyInner = prfReadOutputInner[1].ready;
  assign prfSrc2ValueInner = prfReadOutputInner[1].value;
  assign prfCommitReadyInner = prfReadOutputInner[2].ready;
  assign prfCommitValueInner = prfReadOutputInner[2].value;
   assign ratReadInputInner = '{source1Arch: decodedInner.rs1,
                               source2Arch: decodedInner.rs2};
  assign ratRenameInputInner = '{valid: issueFireInner && decodedInner.writesRd,
                                 architecturalRegister: decodedInner.rd,
                                 physicalRegister: prfAllocPhyInner};
  assign ratRestoreInputInner = '{valid: globalFlushInner,
                                  squashTag: globalFlushTagInner,
                                  headTag: robHeadTagInner};
  assign ratRs1PhyInner = ratReadOutputInner.source1Phy;
  assign ratRs2PhyInner = ratReadOutputInner.source2Phy;
  assign ratOldPhyInner = ratRenameOutputInner.previousPhysicalRegister;
  assign lsuLoadAllocationInputInner = '{
    valid: issueFireInner && (decodedInner.uopClass == rv32_pkg::UOP_LOAD),
    robTag: robAllocTagInner,
    destinationPhy: issueDestPhyInner,
    size: decodedInner.memorySize,
    isUnsigned: decodedInner.memoryUnsigned
  };
  assign lsuStoreAllocationInputInner = '{
    valid: issueFireInner && (decodedInner.uopClass == rv32_pkg::UOP_STORE),
    robTag: robAllocTagInner,
    size: decodedInner.memorySize,
    dataReady: 1'b0,
    dataTag: phy_tag_t'(0),
    dataValue: 32'b0
  };
  assign lsuStoreCommitInputInner = retirementStoreInputInner[0];
  assign lsuStoreCommitReadyInner = retirementStoreReadyInner[0];
  assign lsuStoreRetirementOutputInner = retirementMemoryInner[0];
  assign lsuDmemResponseInputInner = '{valid: dmemRspValidInput, readData: dmemRspRdataInput};
  assign loadCdbValidInner = lsuLoadResultOutputInner.valid;
  assign wbLoadTagInner = lsuLoadResultOutputInner.robTag;
  assign wbLoadPhyInner = lsuLoadResultOutputInner.destinationPhy;
  assign wbLoadValueInner = lsuLoadResultOutputInner.value;
  assign dmemReqValidOutput = lsuDmemRequestOutputInner.valid;
  assign dmemReqWriteOutput = lsuDmemRequestOutputInner.write;
  assign dmemReqAddrOutput = lsuDmemRequestOutputInner.address;
  assign dmemReqWdataOutput = lsuDmemRequestOutputInner.writeData;
  assign dmemReqWstrbOutput = lsuDmemRequestOutputInner.writeStrobe;
  assign dmemReqSizeOutput = lsuDmemRequestOutputInner.size;
  assign robAllocInputInner = '{
    valid: issueFireInner,
    programCounter: decodedInner.programCounter,
    instruction: decodedInner.instruction,
    writesArchitecturalRegister: decodedInner.writesRd,
    architecturalRegister: decodedInner.rd,
    newPhysicalRegister: issueDestPhyInner,
    oldPhysicalRegister: ratOldPhyInner,
    ready: decodedInner.halt,
    isStore: decodedInner.uopClass == rv32_pkg::UOP_STORE,
    storeQueueIndex: sqAllocIndexInner,
    isHalt: decodedInner.halt,
    hasException: 1'b0,
    predictedProgramCounter: decodedInner.predictedNextProgramCounter,
    predictorCheckpointId: decodedInner.predictorCheckpointId,
    isReturn: issueIsReturnInner
  };
  generate if (ALU_CDB_PORTS==2) begin : g_independent_alu_completions
    assign robCompletionInputInner[0]='{valid:aluResultGrantInner[0],robTag:aluLaneResultInner[0].robTag,exception:1'b0};
    assign robCompletionInputInner[2]='{valid:aluResultGrantInner[1],robTag:aluLaneResultInner[1].robTag,exception:1'b0};
    assign robLookupInputInner[1]='{robTag:aluLaneResultInner[0].robTag};
    assign robLookupInputInner[5]='{robTag:aluLaneResultInner[1].robTag};
  end else begin : g_shared_alu_completion
    assign robCompletionInputInner[0]='{valid:aluResultLiveInner,robTag:wbAluTagInner,exception:1'b0};
    assign robCompletionInputInner[2]='0;
    assign robLookupInputInner[1]='{robTag:wbAluTagInner};
  end endgenerate
  assign robCompletionInputInner[1] = '{valid: writebackInputInner[ALU_CDB_PORTS].valid,
                                         robTag: sharedCdbTagInner,
                                         exception: 1'b0};
  assign robCompletionInputInner[3] = '0;
  assign robCompletionInputInner[4] = '{valid: branchResultLiveInner,
                                        robTag: bruTagInner,
                                         exception: 1'b0};
  assign robCompletionInputInner[5] = '0;
  assign robLookupInputInner[0] = '{robTag: bruTagInner};
  assign robLookupInputInner[2] = '{robTag: wbLoadTagInner};
  assign robLookupInputInner[3] = '{robTag: wbMulTagInner};
  assign robLookupInputInner[4] = '{robTag: wbDivTagInner};
  assign robCommitValidInner = robCommitOutputInner[0].valid;
  assign robCommitFireInner = retirementFireInner[0];
  assign robCommitFireOutputInner = retirementFireInner[0];
  assign robCommitTagInner = robCommitOutputInner[0].robTag;
  assign robCommitPcInner = robCommitOutputInner[0].programCounter;
  assign robCommitInstrInner = robCommitOutputInner[0].instruction;
  assign robCommitWritesInner = robCommitOutputInner[0].writesArchitecturalRegister;
  assign robCommitRdInner = robCommitOutputInner[0].architecturalRegister;
  assign robCommitNewPhyInner = robCommitOutputInner[0].newPhysicalRegister;
  assign robCommitOldPhyInner = robCommitOutputInner[0].oldPhysicalRegister;
  assign robCommitSqIndexInner = robCommitOutputInner[0].storeQueueIndex;
  assign robCommitHaltInner = robCommitOutputInner[0].isHalt;
  assign robCommitStoreInner = retirementStoreInner[0];
  for (genvar lane = 0; lane < COMMIT_WIDTH; lane++) begin : g_retirement
    wire prefix;
    if (lane == 0) assign prefix = 1'b1;
    else assign prefix = !(retirementStoreInner[lane-1] &&
      retirementMemoryInner[lane-1].address == AXI_EXIT_ADDR);
    assign retirementReadyInner[lane] = bootDoneInner && !pipelineFrozenInner && !globalFlushInner &&
      prefix && (retirementStoreInner[lane] ? retirementStoreReadyInner[lane] : 1'b1);
    assign prfReadInputInner[lane+2] = '{physicalRegister: robCommitOutputInner[lane].newPhysicalRegister};
    assign ratCommitInputInner[lane] = '{valid: retirementFireInner[lane] && robCommitOutputInner[lane].writesArchitecturalRegister,
      architecturalRegister: robCommitOutputInner[lane].architecturalRegister,
      physicalRegister: robCommitOutputInner[lane].newPhysicalRegister};
    assign retirementFreeInner[lane] = '{valid: retirementFireInner[lane] && robCommitOutputInner[lane].writesArchitecturalRegister,
      physicalRegister: robCommitOutputInner[lane].oldPhysicalRegister};
    assign retirementStoreInputInner[lane] = '{valid: robCommitOutputInner[lane].valid && retirementStoreInner[lane] &&
      !globalFlushInner && !pipelineFrozenInner, robTag: robCommitOutputInner[lane].robTag};
    assign retirementInputInner[lane] = '{valid: retirementFireInner[lane], robTag: robCommitOutputInner[lane].robTag};
    assign retirementSqIndexInner[lane] = robCommitOutputInner[lane].storeQueueIndex;
    assign retirementOutput[lane] = '{valid: retirementFireInner[lane],
      pc: robCommitOutputInner[lane].programCounter, instruction: robCommitOutputInner[lane].instruction,
      rdValid: retirementFireInner[lane] && robCommitOutputInner[lane].writesArchitecturalRegister &&
        robCommitOutputInner[lane].architecturalRegister != 0,
      rd: robCommitOutputInner[lane].architecturalRegister, value: prfReadOutputInner[lane+2].value,
      store: retirementFireInner[lane] && retirementStoreInner[lane], address: retirementMemoryInner[lane].address,
      data: retirementMemoryInner[lane].writeData, strobe: retirementMemoryInner[lane].writeStrobe};
  end
  assign robEmptyInner = robStatusOutputInner.empty;
  assign robFullInner = robStatusOutputInner.full;
  assign robHeadTagInner = robStatusOutputInner.headTag;
  assign bruRobLiveInner = robLookupOutputInner[0].valid;
  assign bruRobPcInner = robLookupOutputInner[0].programCounter;
  assign bruRobPredictedPcInner = robLookupOutputInner[0].predictedProgramCounter;
  assign bruRobCkptIdInner = robLookupOutputInner[0].predictorCheckpointId;
  assign bruRobIsRetInner = robLookupOutputInner[0].isReturn;
  assign jumpRobLiveInner = jumpLookupInner.valid;
  assign jumpRobPcInner = jumpLookupInner.programCounter;
  assign jumpRobPredictedPcInner = jumpLookupInner.predictedProgramCounter;
  assign jumpRobCkptIdInner = jumpLookupInner.predictorCheckpointId;
  assign jumpRobIsRetInner = jumpLookupInner.isReturn;
  assign loadRobLiveInner = robLookupOutputInner[2].valid;
  assign mulRobLiveInner = robLookupOutputInner[3].valid;
  assign divRobLiveInner = robLookupOutputInner[4].valid;
  assign predictorFetchAcceptInner = predictorQueryOutputInner.accepted;
  assign imemSecondRequestOutput = frontendSecondRequestInner;
  assign imemFetchCountOutput = frontendFetchCountInner;
  assign imemReqValidOutput = frontendImemRequestOutputInner.valid && bootDoneInner && !haltedInner;
  assign imemCacheRequestOutput = '{valid:imemReqValidOutput,
    address:predictorPcInner,
    predictedProgramCounter:frontendImemRequestOutputInner.predictedProgramCounter,
    predictorCheckpointId:frontendImemRequestOutputInner.predictorCheckpointId};
  assign imemReqAddrOutput = predictorPcInner;
  assign frontendImemResponseInputInner = '{valid: imemRspValidInput,
                                            instruction: imemRspDataInput};
  assign frontendRedirectInputInner = '{valid: globalFlushInner,
                                        programCounter: globalRedirectPcInner};
  assign frontendIqValidInner = frontendInstructionOutputInner.valid;
  assign iqPcInner = frontendInstructionOutputInner.payload.programCounter;
  assign iqInstrInner = frontendInstructionOutputInner.payload.instruction;
  assign iqPredictedPcInner = frontendInstructionOutputInner.payload.predictedNextProgramCounter;
  assign iqPredictorCkptIdInner = frontendInstructionOutputInner.payload.predictorCheckpointId;
  assign decodeContextInner = '{
    instruction: iqInstrInner,
    programCounter: iqPcInner,
    predictedNextProgramCounter: iqPredictedPcInner,
    predictorCheckpointId: iqPredictorCkptIdInner
  };

  rv32_flush_arbiter #(.SORTED_HEAD_SELECT(1'b1)) u_flush_arbiter (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .branchInput(branchFlushInputInner),
    .jumpInput(jumpFlushInputInner),
    .squashOutput(flushOutputInner)
  );

  rv32_frontend #(.RESET_PC(RESET_PC), .LEGACY_HALT(LEGACY_HALT), .FETCH_WIDTH(FETCH_WIDTH),
    .DECODE_WIDTH(DECODE_WIDTH), .RENAME_WIDTH(ISSUE_WIDTH), .FQ_DEPTH(FQ_DEPTH), .IQ_DEPTH(IQ_DEPTH)) u_frontend (
    .freezeInput(frontendFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .predictorQueryOutput(predictorQueryOutputInner),
    .fetchProgramCounterOutput(predictorPcInner),
    .predictionInput(predictorOutputInner),
    .fetchHintInput(imemFetchHintInput), .imemSecondInstructionInput(imemRspSecondDataInput),
    .secondRequestOutput(frontendSecondRequestInner), .predictEnableOutput(predictorFetchPredictInner),
    .imemPacketInstructionsInput(imemRspPacketDataInput), .fetchCountOutput(frontendFetchCountInner),
    .imemRequestOutput(frontendImemRequestOutputInner),
    .imemReqReadyInput(imemReqReadyInput && bootDoneInner && !haltedInner),
    .imemResponseInput(frontendImemResponseInputInner),
    .imemRspReadyOutput(imemRspReadyOutput), .imemFlushOutput(imemFlushOutput),
    .redirectInput(frontendRedirectInputInner),
    .instructionOutput(frontendInstructionOutputInner),
    .decodedOutput(frontendDecodedInner),
    .iqReadyInput(frontendIqReadyInner),
    .instructionSecondOutput(frontendSecondInstructionInner), .decodedSecondOutput(decodedSecondInner),
    .iqSecondReadyInput(issueSecondFireInner),
    .decodedLanesOutput(wideDecodedInner), .iqLaneValidOutput(wideValidInner),
    .iqReadyCountInput(wideIssueCountInner),
    .fetchInfoOutput(fetchInfoOutputInner),
    .fqCountOutput(), .iqCountOutput()
  );

  rv32_predictor #(.COMMIT_WIDTH(COMMIT_WIDTH), .FETCH_WIDTH(FETCH_WIDTH)) u_predictor (
    .freezeInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput), .queryPcInput(predictorQueryOutputInner.programCounter),
    .fetchAcceptInput(predictorFetchAcceptInner),
    .fetchPredictInput(predictorFetchPredictInner), .fetchSecondInput(frontendSecondRequestInner),
    .fetchCountInput(frontendFetchCountInner),
    .fetchInfoInput(predictorFetchInfoInner),
    .branchInput(predictorBranchInputInner),
    .jumpInput(predictorJumpInputInner),
    .squashInput(predictorSquashInputInner),
    .robInput(predictorRobInputInner),
    .recoveryInput(recoveryStepInner),
    .predictionOutput(predictorOutputInner)
  );

  generate if (DECODE_WIDTH == 1 && ISSUE_WIDTH == 1) begin : g_single_decode
  rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder (
    .decodeContextInput(decodeContextInner), .uopOutput(decodedInner)
  );
  end else begin : g_multi_decode
    assign decodedInner = frontendDecodedInner;
  end endgenerate

  rv32_add #(.WIDTH(32)) u_link_add (
    .aInput(decodedInner.programCounter), .bInput(32'd4), .cinInput(1'b0),
    .sumOutput(issueLinkValueInner), .coutOutput(unusedCoutLinkInner)
  );

  generate if (ISSUE_WIDTH != 4) begin : g_legacy_rename_state
  assign wideFireInner='0;
  assign wideIssueCountInner='0;
  assign wideRsAllocInner='0;
  assign wideRsAuxInner='0;
  assign wideLoadAllocInner='0;
  assign wideStoreAllocInner='0;
  rv32_rat #(.COMMIT_WIDTH(COMMIT_WIDTH), .RENAME_WIDTH(ISSUE_WIDTH)) u_rat (
    .freezeInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .readInput(ratReadInputInner), .readOutput(ratReadOutputInner),
    .renameInput(ratRenameInputInner), .renameOutput(ratRenameOutputInner),
    .readSecondInput(ratReadSecondInputInner), .readSecondOutput(ratReadSecondOutputInner),
    .renameSecondInput(ratRenameSecondInputInner), .renameSecondOutput(ratRenameSecondOutputInner),
    .restoreInput(ratRestoreInputInner),
    .recoveryInput(recoveryStepInner),
    .replayInput(robReplayNarrowInner),
    .commitInput(ratCommitInputInner)
  );

  rv32_prf #(.WRITEBACK_PORTS(WRITEBACK_PORTS), .COMMIT_WIDTH(COMMIT_WIDTH), .RENAME_WIDTH(ISSUE_WIDTH),
             .READ_PORTS(COMMIT_WIDTH+4)) u_prf (
    .freezeInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .allocationInput('{valid: issueFireInner && decodedInner.writesRd,
                      valueValid: issueFireInner && decodedInner.writesRd && issueIsJumpInner,
                      value: issueLinkValueInner}),
    .allocReadyOutput(prfAllocReadyInner), .allocPhyOutput(prfAllocPhyInner),
    .allocationSecondInput(prfAllocSecondInputInner),
    .allocSecondReadyOutput(prfAllocSecondReadyInner), .allocSecondPhyOutput(prfAllocSecondPhyInner),
    .freeInput(retirementFreeInner),
    .restoreInput('{valid: globalFlushInner, squashTag: globalFlushTagInner}),
    .recoveryInput(recoveryStepInner),
    .restoreCountInput(robCountInner),
    .replayInput(robReplayNarrowInner),
    .readInput(prfReadInputInner), .readOutput(prfReadOutputInner),
    .writebackInput(writebackInputInner),
    .readyVectorOutput(prfReadyVectorInner), .freeCountOutput()
  );

  rv32_rob #(.COMMIT_WIDTH(COMMIT_WIDTH), .RENAME_WIDTH(ISSUE_WIDTH)) u_rob (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .allocInput(robAllocInputInner), .allocReadyOutput(robAllocReadyInner),
    .allocTagOutput(robAllocTagInner),
    .allocSecondInput(robAllocSecondInputInner), .allocSecondReadyOutput(robAllocSecondReadyInner),
    .allocSecondTagOutput(robAllocSecondTagInner),
    .completionInput(robCompletionInputInner),
    .storeReadyInput(lsuStoreCompleteOutputInner),
    .flushInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .lookupInput(robLookupInputInner[4:0]), .lookupOutput(robLookupOutputInner[4:0]),
    .commitOutput(robCommitOutputInner), .commitStoreOutput(retirementStoreInner),
    .commitReadyInput(retirementReadyInner), .commitFireOutput(retirementFireInner),
    .statusOutput(robStatusOutputInner), .countOutput(robCountInner),
    .replayOffsetInput(recoveryStepInner.offset),
    .replayNarrowOutput(robReplayNarrowInner),
    .replayRasOutput(robReplayRasInner)
  );
  end else begin : g_four_rename_state
    assign prfAllocReadyInner=1'b1;
    assign robAllocReadyInner=1'b1;
    assign ratReadSecondOutputInner='0;
    assign ratRenameSecondOutputInner='0;
    assign prfAllocSecondPhyInner='0;
    assign prfAllocSecondReadyInner=1'b0;
    assign robAllocSecondTagInner='0;
    assign robAllocSecondReadyInner=1'b0;
    rv32_rename_four #(.COMMIT_WIDTH(COMMIT_WIDTH),.WRITEBACK_PORTS(WRITEBACK_PORTS),.LOOKUP_PORTS(ROB_LOOKUP_PORTS)) u_rename (
      .clkInput,.rstNInput,.freezeInput(haltedInner),
      .enableInput(bootDoneInner && !pipelineFrozenInner && !globalFlushInner),
      .decodedInput(wideDecodedInner),.validInput(wideValidInner),.fireOutput(wideFireInner),.countOutput(wideIssueCountInner),
      .rsCreditsInput(wideRsCreditsInner),.loadCreditsInput(wideLoadCreditsInner),.storeCreditsInput(wideStoreCreditsInner),
      .loadPreviewInput(wideLoadPreviewInner),.storePreviewInput(wideStorePreviewInner),
      .rsOutput(wideRsAllocInner),.rsAuxOutput(wideRsAuxInner),
      .loadOutput(wideLoadAllocInner),.storeOutput(wideStoreAllocInner),
      .mapCommitInput(ratCommitInputInner),.freeInput(retirementFreeInner),
      .scalarReadInput(prfReadInputInner),.scalarReadOutput(prfReadOutputInner),
      .firstMapOutput(ratReadOutputInner),.firstPreviousOutput(ratRenameOutputInner),
      .firstFreePhysicalOutput(prfAllocPhyInner),.readyVectorOutput(prfReadyVectorInner),
      .writebackInput(writebackInputInner),.completionInput(robCompletionInputInner),.storeReadyInput(lsuStoreCompleteOutputInner),
      .flushInput('{valid:globalFlushInner,robTag:globalFlushTagInner}),.recoveryInput(recoveryStepInner),
      .lookupInput(robLookupInputInner),.lookupOutput(robLookupOutputInner),
      .commitOutput(robCommitOutputInner),.commitStoreOutput(retirementStoreInner),
      .commitReadyInput(retirementReadyInner),.commitFireOutput(retirementFireInner),
      .statusOutput(robStatusOutputInner),.robCountOutput(robCountInner),.nextTagOutput(robAllocTagInner),
      .replayNarrowOutput(robReplayNarrowInner),.replayRasOutput(robReplayRasInner)
    );
  end endgenerate

  always_comb begin
    issueIsJumpInner = (decodedInner.operation == OP_JAL) || (decodedInner.operation == OP_JALR);
    issueIsCallInner = issueIsJumpInner &&
                     ((decodedInner.rd == 5'd1) || (decodedInner.rd == 5'd5));
    issueIsReturnInner = (decodedInner.operation == OP_JALR) &&
                        ((decodedInner.rs1 == 5'd1) || (decodedInner.rs1 == 5'd5));
    issueDestPhyInner = decodedInner.writesRd ? prfAllocPhyInner : '0;
    issueSrc1ReadyInner = !decodedInner.usesRs1 || prfSrc1ReadyInner;
    issueSrc1ValueInner = decodedInner.usesRs1 ? prfSrc1ValueInner : 32'b0;
    issueSrc2ReadyInner = !decodedInner.usesRs2 || prfSrc2ReadyInner;
    issueSrc2ValueInner = decodedInner.usesRs2 ? prfSrc2ValueInner : 32'b0;

    targetRsReadyInner = 1'b1;
    unique case (decodedInner.uopClass)
      rv32_pkg::UOP_ALU:    targetRsReadyInner = intAllocReadyInner;
      rv32_pkg::UOP_MUL:    targetRsReadyInner = mulAllocReadyInner;
      rv32_pkg::UOP_DIV:    targetRsReadyInner = divAllocReadyInner;
      rv32_pkg::UOP_BRANCH: targetRsReadyInner = branchAllocReadyInner;
      rv32_pkg::UOP_LOAD:   targetRsReadyInner = loadRsAllocReadyInner && lqAllocReadyInner;
      rv32_pkg::UOP_STORE:  targetRsReadyInner = saRsAllocReadyInner && svRsAllocReadyInner && sqAllocReadyInner;
      default:    targetRsReadyInner = 1'b1;
    endcase
    issueResourcesReadyInner = robAllocReadyInner && targetRsReadyInner &&
                             (!decodedInner.writesRd || prfAllocReadyInner);
    issueFireInner = ISSUE_WIDTH==4 ? wideFireInner[0] :
      (bootDoneInner && frontendIqValidInner && issueResourcesReadyInner && !globalFlushInner && !pipelineFrozenInner);
    frontendIqReadyInner = issueFireInner;

    // The read edge must not compete with an architectural SRAM write. Holding
    // retirement also keeps the head-ordered replay window stable for all beats.
    robCommitReadyInner = retirementReadyInner[0];
    commitValidOutput = robCommitFireInner;
    commitPcOutput = robCommitPcInner;
    commitInstrOutput = robCommitInstrInner;
    commitRdValidOutput = robCommitFireInner && robCommitWritesInner &&
                         (robCommitRdInner != 5'd0);
    commitRdOutput = robCommitRdInner;
    commitRdValueOutput = prfCommitValueInner;
    commitMemValidOutput = robCommitFireInner && robCommitStoreInner;
    commitMemAddrOutput = lsuStoreRetirementOutputInner.address;
    commitMemDataOutput = lsuStoreRetirementOutputInner.writeData;
    commitMemWstrbOutput = lsuStoreRetirementOutputInner.writeStrobe;
    // HALT commits immediately; no SQ/cache/memory drain (software-aligned).
    haltedOutput = haltedInner;
    trapOutput = 1'b0; // Preserve the public port; this core has no exception path.
  end

  always_comb begin
    rsAllocBaseInner = '{
      valid: issueFireInner,
      operation: decodedInner.operation,
      robTag: robAllocTagInner,
      destinationPhy: issueDestPhyInner,
      source1Ready: issueSrc1ReadyInner,
      source1Tag: ratRs1PhyInner,
      source1Value: issueSrc1ValueInner,
      source2Ready: issueSrc2ReadyInner,
      source2Tag: ratRs2PhyInner,
      source2Value: issueSrc2ValueInner,
      immediate: decodedInner.immediate,
      programCounter: decodedInner.programCounter,
      predictedProgramCounter: decodedInner.predictedNextProgramCounter,
      useImmediate: decodedInner.usesImmediate
    };
    intRsAllocInputInner = rsAllocBaseInner;
    intRsAllocInputInner.valid = rsAllocBaseInner.valid &&
                                 (decodedInner.uopClass == rv32_pkg::UOP_ALU);
    mulRsAllocInputInner = rsAllocBaseInner;
    mulRsAllocInputInner.valid = rsAllocBaseInner.valid &&
                                 (decodedInner.uopClass == rv32_pkg::UOP_MUL);
    mulRsAllocInputInner.useImmediate = 1'b0;
    divRsAllocInputInner = rsAllocBaseInner;
    divRsAllocInputInner.valid = rsAllocBaseInner.valid &&
                                 (decodedInner.uopClass == rv32_pkg::UOP_DIV);
    divRsAllocInputInner.useImmediate = 1'b0;
    branchRsAllocInputInner = rsAllocBaseInner;
    branchRsAllocInputInner.valid = rsAllocBaseInner.valid &&
                                    (decodedInner.uopClass == rv32_pkg::UOP_BRANCH);
    memRsAllocInputInner = rsAllocBaseInner;
    memRsAllocInputInner.valid = rsAllocBaseInner.valid &&
      ((decodedInner.uopClass == rv32_pkg::UOP_LOAD) ||
       (decodedInner.uopClass == rv32_pkg::UOP_STORE));
    memRsAllocInputInner.source2Ready = 1'b1;
    memRsAllocInputInner.source2Tag = '0;
    memRsAllocInputInner.source2Value = '0;
    memRsAllocInputInner.useImmediate = 1'b1;
    loadRsAllocInputInner = memRsAllocInputInner;
    loadRsAllocInputInner.valid = issueFireInner && decodedInner.uopClass == rv32_pkg::UOP_LOAD;
    saRsAllocInputInner = memRsAllocInputInner;
    saRsAllocInputInner.valid = issueFireInner && decodedInner.uopClass == rv32_pkg::UOP_STORE;
    svRsAllocInputInner = rsAllocBaseInner;
    svRsAllocInputInner.valid = saRsAllocInputInner.valid;
    svRsAllocInputInner.source1Ready = issueSrc2ReadyInner;
    svRsAllocInputInner.source1Tag = ratRs2PhyInner;
    svRsAllocInputInner.source1Value = issueSrc2ValueInner;
    svRsAllocInputInner.source2Ready = 1'b1;
    svRsAllocInputInner.source2Tag = '0;
    svRsAllocInputInner.source2Value = '0;
    svRsAllocInputInner.useImmediate = 1'b0;

    for (storeLaneInner = 0; storeLaneInner < STORE_VALUE_RS_ENTRIES; storeLaneInner = storeLaneInner + 1) begin
      svRsStoreDataInner[storeLaneInner].valid = !recoveryBusyInner && svRsIssueLaneValidInner[storeLaneInner];
      svRsStoreDataInner[storeLaneInner].robTag = svRsIssueLaneInner[storeLaneInner].robTag;
      svRsStoreDataInner[storeLaneInner].value = svRsIssueLaneInner[storeLaneInner].source1Value;
      svRsStoreDataIndexInner[storeLaneInner] = svRsIssueLaneAuxInner[storeLaneInner];
    end
  end

  rv32_rs #(.DEPTH(INT_RS_ENTRIES), .AUX_W(1), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH),
            .ISSUE_WIDTH(ALU_LANES), .INDEPENDENT_ISSUE_READY(ALU_LANES>1),
            .REUSE_ON_ISSUE(1'b1), .WB_ISSUE_BYPASS(1'b1)) u_int_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(intRsAllocInputInner),
    .allocReadyOutput(intAllocReadyInner), .allocAuxInput(issueIsJumpInner),
    .allocSecondInput(intRsAllocSecondInputInner), .allocSecondReadyOutput(intAllocSecondReadyInner),
    .allocSecondAuxInput(issueSecondIsJumpInner),
    .allocLanesInput(wideRsAllocInner[0]),.allocLanesAuxInput(wideIntAuxInner),
    .allocLanesFireOutput(wideRsFireInner[0]),.allocCreditsOutput(wideIntCreditsInner),
    .writebackInput(writebackInputInner),
    .issueOutput(intRsIssueOutputInner), .issueReadyInput(intIssueReadyInner),
    .issueAuxOutput(intIssueAuxInner),
    .occupancyOutput(), .issueLaneValidOutput(intIssueLaneValidInner),
    .issueLaneOutput(intIssueLaneInner), .issueLaneAuxOutput(intIssueLaneAuxInner),
    .issueLaneReadyInput(intIssueLaneReadyInner)
  );
  assign intIssueValidInner = intRsIssueOutputInner.valid;
  assign intIssueOpInner = intRsIssueOutputInner.operation;
  assign intIssueTagInner = intRsIssueOutputInner.robTag;
  assign intIssuePhyInner = intRsIssueOutputInner.destinationPhy;
  assign intIssueS1Inner = intRsIssueOutputInner.source1Value;
  assign intIssueS2Inner = intRsIssueOutputInner.source2Value;
  assign intIssueImmInner = intRsIssueOutputInner.immediate;
  assign intIssuePcInner = intRsIssueOutputInner.programCounter;
  assign intIssuePredInner = intRsIssueOutputInner.predictedProgramCounter;
  assign intIssueUseImmInner = intRsIssueOutputInner.useImmediate;

  rv32_rs #(.DEPTH(MUL_RS_ENTRIES), .AUX_W(1), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH)) u_mul_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(mulRsAllocInputInner), .allocReadyOutput(mulAllocReadyInner),
    .allocAuxInput(1'b0),
    .allocSecondInput(mulRsAllocSecondInputInner), .allocSecondReadyOutput(mulAllocSecondReadyInner),
    .allocSecondAuxInput(1'b0),
    .allocLanesInput(wideRsAllocInner[1]),.allocLanesAuxInput(wideMulAuxInner),
    .allocLanesFireOutput(wideRsFireInner[1]),.allocCreditsOutput(wideMulCreditsInner),
    .writebackInput(writebackInputInner),
    .issueOutput(mulRsIssueOutputInner), .issueReadyInput(mulIssueReadyInner),
    .issueAuxOutput(mulIssueAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  assign mulIssueValidInner = mulRsIssueOutputInner.valid;
  assign mulIssueOpInner = mulRsIssueOutputInner.operation;
  assign mulIssueTagInner = mulRsIssueOutputInner.robTag;
  assign mulIssuePhyInner = mulRsIssueOutputInner.destinationPhy;
  assign mulIssueS1Inner = mulRsIssueOutputInner.source1Value;
  assign mulIssueS2Inner = mulRsIssueOutputInner.source2Value;
  assign mulIssueImmInner = mulRsIssueOutputInner.immediate;
  assign mulIssuePcInner = mulRsIssueOutputInner.programCounter;
  assign mulIssuePredInner = mulRsIssueOutputInner.predictedProgramCounter;
  assign mulIssueUseImmInner = mulRsIssueOutputInner.useImmediate;

  rv32_rs #(.DEPTH(DIV_RS_ENTRIES), .AUX_W(1), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH)) u_div_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(divRsAllocInputInner), .allocReadyOutput(divAllocReadyInner),
    .allocAuxInput(1'b0),
    .allocSecondInput(divRsAllocSecondInputInner), .allocSecondReadyOutput(divAllocSecondReadyInner),
    .allocSecondAuxInput(1'b0),
    .allocLanesInput(wideRsAllocInner[2]),.allocLanesAuxInput(wideDivAuxInner),
    .allocLanesFireOutput(wideRsFireInner[2]),.allocCreditsOutput(wideDivCreditsInner),
    .writebackInput(writebackInputInner),
    .issueOutput(divRsIssueOutputInner), .issueReadyInput(divIssueReadyInner),
    .issueAuxOutput(divIssueAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  assign divIssueValidInner = divRsIssueOutputInner.valid;
  assign divIssueOpInner = divRsIssueOutputInner.operation;
  assign divIssueTagInner = divRsIssueOutputInner.robTag;
  assign divIssuePhyInner = divRsIssueOutputInner.destinationPhy;
  assign divIssueS1Inner = divRsIssueOutputInner.source1Value;
  assign divIssueS2Inner = divRsIssueOutputInner.source2Value;
  assign divIssueImmInner = divRsIssueOutputInner.immediate;
  assign divIssuePcInner = divRsIssueOutputInner.programCounter;
  assign divIssuePredInner = divRsIssueOutputInner.predictedProgramCounter;
  assign divIssueUseImmInner = divRsIssueOutputInner.useImmediate;

  rv32_rs #(.DEPTH(BRANCH_RS_ENTRIES), .AUX_W(3), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH),
            .REUSE_ON_ISSUE(1'b1), .WB_ISSUE_BYPASS(1'b1)) u_branch_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(branchRsAllocInputInner), .allocReadyOutput(branchAllocReadyInner),
    .allocAuxInput({1'b0, issueIsReturnInner, issueIsCallInner}),
    .allocSecondInput(branchRsAllocSecondInputInner), .allocSecondReadyOutput(branchAllocSecondReadyInner),
    .allocSecondAuxInput(3'b0),
    .allocLanesInput(wideRsAllocInner[3]),.allocLanesAuxInput(wideBranchAuxInner),
    .allocLanesFireOutput(wideRsFireInner[3]),.allocCreditsOutput(wideBranchCreditsInner),
    .writebackInput(writebackInputInner),
    .issueOutput(branchRsIssueOutputInner), .issueReadyInput(branchIssueReadyInner),
    .issueAuxOutput(branchIssueAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  assign branchIssueValidInner = branchRsIssueOutputInner.valid;
  assign branchIssueOpInner = branchRsIssueOutputInner.operation;
  assign branchIssueTagInner = branchRsIssueOutputInner.robTag;
  assign branchIssuePhyInner = branchRsIssueOutputInner.destinationPhy;
  assign branchIssueS1Inner = branchRsIssueOutputInner.source1Value;
  assign branchIssueS2Inner = branchRsIssueOutputInner.source2Value;
  assign branchIssueImmInner = branchRsIssueOutputInner.immediate;
  assign branchIssuePcInner = branchRsIssueOutputInner.programCounter;
  assign branchIssuePredInner = branchRsIssueOutputInner.predictedProgramCounter;
  assign branchIssueUseImmInner = branchRsIssueOutputInner.useImmediate;

  rv32_rs #(.DEPTH(LOAD_RS_ENTRIES), .AUX_W(4), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH),
            .REUSE_ON_ISSUE(1'b1), .WB_ISSUE_BYPASS(1'b1)) u_load_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(loadRsAllocInputInner), .allocReadyOutput(loadRsAllocReadyInner),
    .allocAuxInput({1'b0, lqAllocIndexInner}),
    .allocSecondInput(loadRsAllocSecondInputInner), .allocSecondReadyOutput(loadRsAllocSecondReadyInner),
    .allocSecondAuxInput({1'b0, lqAllocSecondIndexInner}),
    .allocLanesInput(wideRsAllocInner[4]),.allocLanesAuxInput(wideLoadAuxInner),
    .allocLanesFireOutput(wideRsFireInner[4]),.allocCreditsOutput(wideLoadRsCreditsInner),
    .writebackInput(writebackInputInner),
    .issueOutput(loadRsIssueOutputInner), .issueReadyInput(loadRsIssueReadyInner),
    .issueAuxOutput(loadAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  rv32_rs #(.DEPTH(STORE_ADDR_RS_ENTRIES), .AUX_W(4), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH)) u_store_addr_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(saRsAllocInputInner), .allocReadyOutput(saRsAllocReadyInner),
    .allocAuxInput({1'b1, sqAllocIndexInner}), .writebackInput(writebackInputInner),
    .allocSecondInput(saRsAllocSecondInputInner), .allocSecondReadyOutput(saRsAllocSecondReadyInner),
    .allocSecondAuxInput({1'b1, sqAllocSecondIndexInner}),
    .allocLanesInput(wideRsAllocInner[5]),.allocLanesAuxInput(wideSaAuxInner),
    .allocLanesFireOutput(wideRsFireInner[5]),.allocCreditsOutput(wideSaCreditsInner),
    .issueOutput(saRsIssueOutputInner), .issueReadyInput(saRsIssueReadyInner),
    .issueAuxOutput(saAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  rv32_rs #(.DEPTH(STORE_VALUE_RS_ENTRIES), .AUX_W(3),
             .ISSUE_WIDTH(STORE_VALUE_RS_ENTRIES), .WRITEBACK_PORTS(WRITEBACK_PORTS), .RENAME_WIDTH(ISSUE_WIDTH)) u_store_value_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(svRsAllocInputInner), .allocReadyOutput(svRsAllocReadyInner),
    .allocAuxInput(sqAllocIndexInner), .writebackInput(writebackInputInner),
    .allocSecondInput(svRsAllocSecondInputInner), .allocSecondReadyOutput(svRsAllocSecondReadyInner),
    .allocSecondAuxInput(sqAllocSecondIndexInner),
    .allocLanesInput(wideRsAllocInner[6]),.allocLanesAuxInput(wideSvAuxInner),
    .allocLanesFireOutput(wideRsFireInner[6]),.allocCreditsOutput(wideSvCreditsInner),
    .issueOutput(svRsIssueOutputInner), .issueReadyInput(!globalFlushInner ||
        rob_is_older(svRsIssueOutputInner.robTag, globalFlushTagInner)),
    .issueAuxOutput(svAuxInner), .occupancyOutput(),
    .issueLaneValidOutput(svRsIssueLaneValidInner),
    .issueLaneOutput(svRsIssueLaneInner),
    .issueLaneAuxOutput(svRsIssueLaneAuxInner)
  );
  assign chooseLoadInner = loadRsIssueOutputInner.valid &&
      (!saRsIssueOutputInner.valid ||
       rob_is_older(loadRsIssueOutputInner.robTag, saRsIssueOutputInner.robTag));
  assign memRsIssueOutputInner = chooseLoadInner ? loadRsIssueOutputInner : saRsIssueOutputInner;
  assign memIssueAuxInner = chooseLoadInner ? loadAuxInner : saAuxInner;
  assign loadRsIssueReadyInner = memIssueReadyInner && chooseLoadInner;
  assign saRsIssueReadyInner = memIssueReadyInner && !chooseLoadInner;

  // Compact OLD age-ranked RS candidates onto the actually available ALUs.
  // A blocked ALU0 must not stop the oldest candidate from entering ALU1.
  // Producer capacity depends only on registered results and actual CDB grant,
  // never on the new allocation/dispatch payload being routed here.
  always_comb begin : route_integer_dispatch
    int candidate;
    candidate=0;
    intIssueLaneReadyInner='0;
    for (int unitIndex=0;unitIndex<ALU_LANES;unitIndex++) begin
      aluLaneRequestInner[unitIndex]='0;
      if (!pipelineFrozenInner && aluInputReadyInner[unitIndex] && candidate<ALU_LANES) begin
        aluLaneRequestInner[unitIndex]='{valid:intIssueLaneValidInner[candidate],
          operation:intIssueLaneInner[candidate].operation,
          source1:intIssueLaneInner[candidate].source1Value,
          source2:intIssueLaneInner[candidate].source2Value,
          immediate:intIssueLaneInner[candidate].immediate,
          programCounter:intIssueLaneInner[candidate].programCounter,
          predictedNextProgramCounter:intIssueLaneInner[candidate].predictedProgramCounter,
          useImmediate:intIssueLaneInner[candidate].useImmediate,
          robTag:intIssueLaneInner[candidate].robTag,
          destinationPhy:intIssueLaneInner[candidate].destinationPhy,
          isControl:intIssueLaneAuxInner[candidate][0],isCall:1'b0,isReturn:1'b0};
        intIssueLaneReadyInner[candidate]=1'b1;
        candidate++;
      end
    end
  end
  assign intIssueReadyInner=intIssueLaneReadyInner[0];
  for (genvar unitIndex=0;unitIndex<ALU_LANES;unitIndex++) begin : g_alu_units
    assign aluIssueFireInner[unitIndex]=aluLaneRequestInner[unitIndex].valid && aluInputReadyInner[unitIndex];
    rv32_alu_unit #(.DEPTH(rv32_pkg::ALU_RESULT_ENTRIES)) u_alu_unit (
      .freezeInput(pipelineFrozenInner),.clkInput,.rstNInput,
      .flushInfoInput('{valid:globalFlushInner,robTag:globalFlushTagInner}),
      .executeInput(aluLaneRequestInner[unitIndex]),.inReadyOutput(aluInputReadyInner[unitIndex]),
      .outReadyInput(aluPopReadyInner[unitIndex]),.executeOutput(aluLaneResultInner[unitIndex]),.occupancyOutput()
    );
  end

  rv32_mul u_mul_unit (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .executeInput('{valid: mulIssueValidInner,
                   operation: mulIssueOpInner,
                   source1: mulIssueS1Inner,
                   source2: mulIssueS2Inner,
                   immediate: mulIssueImmInner,
                   programCounter: mulIssuePcInner,
                   predictedNextProgramCounter: mulIssuePredInner,
                   useImmediate: mulIssueUseImmInner,
                   robTag: mulIssueTagInner,
                   destinationPhy: mulIssuePhyInner,
                   isControl: 1'b0,
                   isCall: 1'b0,
                   isReturn: 1'b0}),
    .inReadyOutput(mulIssueReadyInner), .outReadyInput(wbMulValidInner),
    .executeOutput(mulExecuteOutputInner)
  );

  rv32_div u_div_unit (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .executeInput('{valid: divIssueValidInner,
                   operation: divIssueOpInner,
                   source1: divIssueS1Inner,
                   source2: divIssueS2Inner,
                   immediate: divIssueImmInner,
                   programCounter: divIssuePcInner,
                   predictedNextProgramCounter: divIssuePredInner,
                   useImmediate: 1'b0,
                   robTag: divIssueTagInner,
                   destinationPhy: divIssuePhyInner,
                   isControl: 1'b0,
                   isCall: 1'b0,
                   isReturn: 1'b0}),
    .inReadyOutput(divIssueReadyInner), .outReadyInput(wbDivValidInner),
    .executeOutput(divExecuteOutputInner)
  );

  // JAL/JALR are UOP_ALU; this pool executes only conditional branches.
  rv32_bru_unit #(.CONDITIONAL_ONLY(1'b1)) u_bru_unit (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(globalFlushInner),
    .flushTagInput(globalFlushTagInner),
    .executeInput('{valid: branchIssueValidInner,
                   operation: branchIssueOpInner,
                   source1: branchIssueS1Inner,
                   source2: branchIssueS2Inner,
                   immediate: branchIssueImmInner,
                   programCounter: branchIssuePcInner,
                   predictedNextProgramCounter: branchIssuePredInner,
                   useImmediate: branchIssueUseImmInner,
                   robTag: branchIssueTagInner,
                   destinationPhy: branchIssuePhyInner,
                   isControl: 1'b0,
                   isCall: branchIssueAuxInner[0],
                   isReturn: branchIssueAuxInner[1]}),
    .inReadyOutput(branchIssueReadyInner), .executeOutput(bruExecuteOutputInner)
  );

  rv32_agu_unit u_agu_unit (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .executeInput(memRsIssueOutputInner), .auxiliaryInput(memIssueAuxInner),
    .inReadyOutput(memIssueReadyInner), .addressOutput(aguAddressOutputInner),
    .auxiliaryOutput(aguResultAuxInner), .robTagOutput()
  );

  always_comb begin
    lsuAddressInputInner = aguAddressOutputInner;
    lsuAddressInputInner.valid = aguAddressOutputInner.valid && !recoveryBusyInner;
  end

  rv32_lsu #(.STORE_DATA_LANES(STORE_VALUE_RS_ENTRIES), .TAGGED_DMEM(TAGGED_DMEM),
             .WRITEBACK_PORTS(WRITEBACK_PORTS), .COMMIT_WIDTH(COMMIT_WIDTH), .RENAME_WIDTH(ISSUE_WIDTH)) u_lsu (
    .coreStoppedInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .loadAllocationInput(lsuLoadAllocationInputInner),
    .loadAllocReadyOutput(lqAllocReadyInner), .loadAllocIndexOutput(lqAllocIndexInner),
    .loadAllocationSecondInput(lsuLoadAllocationSecondInputInner),
    .loadAllocSecondReadyOutput(lqAllocSecondReadyInner), .loadAllocSecondIndexOutput(lqAllocSecondIndexInner),
    .storeAllocationInput(lsuStoreAllocationInputInner),
    .storeAllocReadyOutput(sqAllocReadyInner), .storeAllocIndexOutput(sqAllocIndexInner),
    .storeAllocationSecondInput(lsuStoreAllocationSecondInputInner),
    .storeAllocSecondReadyOutput(sqAllocSecondReadyInner), .storeAllocSecondIndexOutput(sqAllocSecondIndexInner),
    .loadAllocationLanesInput(wideLoadAllocInner),.storeAllocationLanesInput(wideStoreAllocInner),
    .loadAllocationLanesFireOutput(wideLoadFireInner),.storeAllocationLanesFireOutput(wideStoreFireInner),
    .loadPreviewIndexOutput(wideLoadPreviewInner),.storePreviewIndexOutput(wideStorePreviewInner),
    .loadCreditsOutput(wideLoadCreditsInner),.storeCreditsOutput(wideStoreCreditsInner),
    .storeDataInput(svRsStoreDataInner),
    .storeDataIndexInput(svRsStoreDataIndexInner),
    .addressInput(lsuAddressInputInner), .addressIndexInput(aguResultAuxInner[2:0]),
    .writebackInput(writebackInputInner),
    .loadResultOutput(lsuLoadResultOutputInner), .loadResultReadyInput(wbLoadValidInner),
    .robRetireInput(retirementInputInner),
    .storeCompleteOutput(lsuStoreCompleteOutputInner),
    .storeCommitInput(retirementStoreInputInner),
    .storeCommitIndexInput(retirementSqIndexInner),
    .storeCommitReadyOutput(retirementStoreReadyInner),
    .storeRetirementOutput(retirementMemoryInner),
    .dmemRequestOutput(lsuDmemRequestOutputInner), .dmemReqReadyInput(dmemReqReadyInput),
    .dmemResponseInput(lsuDmemResponseInputInner),
    .dmemReqTransactionOutput(dmemReqTransactionOutput), .dmemRspTransactionInput(dmemRspTransactionInput),
    .lqCountOutput(), .sqCountOutput(sqCountInner)
  );

  // Younger allocation is combinationally downstream of lane0 only. All
  // consumers accept the same event; no new pipeline stage or execution lane.
  generate if (ISSUE_WIDTH == 2) begin : g_dual_rename
    logic raw1, raw2;
    logic unusedLinkCarry;
    rv32_add #(.WIDTH(32)) u_second_link_add (
      .aInput(decodedSecondInner.programCounter), .bInput(32'd4), .cinInput(1'b0),
      .sumOutput(issueSecondLinkValueInner), .coutOutput(unusedLinkCarry)
    );
    assign ratReadSecondInputInner = '{source1Arch:decodedSecondInner.rs1, source2Arch:decodedSecondInner.rs2};
    assign prfReadInputInner[COMMIT_WIDTH+2] = '{physicalRegister:ratReadSecondOutputInner.source1Phy};
    assign prfReadInputInner[COMMIT_WIDTH+3] = '{physicalRegister:ratReadSecondOutputInner.source2Phy};
    assign issueSecondIsJumpInner = decodedSecondInner.operation == OP_JAL || decodedSecondInner.operation == OP_JALR;
    assign issueSecondIsReturnInner = decodedSecondInner.operation == OP_JALR &&
      (decodedSecondInner.rs1 == 1 || decodedSecondInner.rs1 == 5);
    assign issueSecondDestPhyInner = decodedSecondInner.writesRd ? prfAllocSecondPhyInner : '0;
    assign raw1 = ratRenameInputInner.valid && decodedSecondInner.usesRs1 && decodedSecondInner.rs1 == decodedInner.rd;
    assign raw2 = ratRenameInputInner.valid && decodedSecondInner.usesRs2 && decodedSecondInner.rs2 == decodedInner.rd;
    assign issueSecondSrc1PhyInner = raw1 ? issueDestPhyInner : ratReadSecondOutputInner.source1Phy;
    assign issueSecondSrc2PhyInner = raw2 ? issueDestPhyInner : ratReadSecondOutputInner.source2Phy;
    // Link values are initialized ready at allocation, not broadcast later.
    // Capturing PC+4 here matches the software's next-cycle PRF read, without
    // making the newly allocated RS entry eligible on this cycle.
    assign issueSecondSrc1ReadyInner = !decodedSecondInner.usesRs1 ||
      (raw1 ? issueIsJumpInner : prfReadOutputInner[COMMIT_WIDTH+2].ready);
    assign issueSecondSrc2ReadyInner = !decodedSecondInner.usesRs2 ||
      (raw2 ? issueIsJumpInner : prfReadOutputInner[COMMIT_WIDTH+3].ready);
    assign issueSecondSrc1ValueInner = !decodedSecondInner.usesRs1 ? 32'b0 :
      (raw1 ? (issueIsJumpInner ? issueLinkValueInner : 32'b0) : prfReadOutputInner[COMMIT_WIDTH+2].value);
    assign issueSecondSrc2ValueInner = !decodedSecondInner.usesRs2 ? 32'b0 :
      (raw2 ? (issueIsJumpInner ? issueLinkValueInner : 32'b0) : prfReadOutputInner[COMMIT_WIDTH+3].value);
    assign ratSecondOldPhyInner = ratRenameInputInner.valid && decodedSecondInner.rd == decodedInner.rd ?
      issueDestPhyInner : ratRenameSecondOutputInner.previousPhysicalRegister;

    always_comb begin
      targetSecondRsReadyInner = 1'b1;
      case (decodedSecondInner.uopClass)
        UOP_ALU: targetSecondRsReadyInner = intAllocSecondReadyInner;
        UOP_MUL: targetSecondRsReadyInner = mulAllocSecondReadyInner;
        UOP_DIV: targetSecondRsReadyInner = divAllocSecondReadyInner;
        UOP_BRANCH: targetSecondRsReadyInner = branchAllocSecondReadyInner;
        UOP_LOAD: targetSecondRsReadyInner = loadRsAllocSecondReadyInner && lqAllocSecondReadyInner;
        UOP_STORE: targetSecondRsReadyInner = saRsAllocSecondReadyInner && svRsAllocSecondReadyInner && sqAllocSecondReadyInner;
        default: targetSecondRsReadyInner = 1'b1;
      endcase
    end
    assign issueSecondResourcesReadyInner = robAllocSecondReadyInner && targetSecondRsReadyInner &&
      (!decodedSecondInner.writesRd || prfAllocSecondReadyInner);
    assign issueSecondFireInner = issueFireInner && !decodedInner.halt && frontendSecondInstructionInner.valid &&
      issueSecondResourcesReadyInner;
    assign ratRenameSecondInputInner = '{valid:issueSecondFireInner && decodedSecondInner.writesRd,
      architecturalRegister:decodedSecondInner.rd, physicalRegister:prfAllocSecondPhyInner};
    assign prfAllocSecondInputInner = '{valid:issueSecondFireInner && decodedSecondInner.writesRd,
      valueValid:issueSecondIsJumpInner, value:issueSecondLinkValueInner};
    assign robAllocSecondInputInner = '{valid:issueSecondFireInner,
      programCounter:decodedSecondInner.programCounter, instruction:decodedSecondInner.instruction,
      writesArchitecturalRegister:decodedSecondInner.writesRd, architecturalRegister:decodedSecondInner.rd,
      newPhysicalRegister:issueSecondDestPhyInner, oldPhysicalRegister:ratSecondOldPhyInner,
      ready:decodedSecondInner.halt, isStore:decodedSecondInner.uopClass == UOP_STORE,
      storeQueueIndex:sqAllocSecondIndexInner, isHalt:decodedSecondInner.halt, hasException:1'b0,
      predictedProgramCounter:decodedSecondInner.predictedNextProgramCounter,
      predictorCheckpointId:decodedSecondInner.predictorCheckpointId, isReturn:issueSecondIsReturnInner};
    assign lsuLoadAllocationSecondInputInner = '{valid:issueSecondFireInner && decodedSecondInner.uopClass == UOP_LOAD,
      robTag:robAllocSecondTagInner, destinationPhy:issueSecondDestPhyInner,
      size:decodedSecondInner.memorySize, isUnsigned:decodedSecondInner.memoryUnsigned};
    assign lsuStoreAllocationSecondInputInner = '{valid:issueSecondFireInner && decodedSecondInner.uopClass == UOP_STORE,
      robTag:robAllocSecondTagInner, size:decodedSecondInner.memorySize, dataReady:1'b0, dataTag:'0, dataValue:'0};
    always_comb begin
      rsAllocSecondBaseInner = '{valid:issueSecondFireInner, operation:decodedSecondInner.operation,
        robTag:robAllocSecondTagInner, destinationPhy:issueSecondDestPhyInner,
        source1Ready:issueSecondSrc1ReadyInner, source1Tag:issueSecondSrc1PhyInner, source1Value:issueSecondSrc1ValueInner,
        source2Ready:issueSecondSrc2ReadyInner, source2Tag:issueSecondSrc2PhyInner, source2Value:issueSecondSrc2ValueInner,
        immediate:decodedSecondInner.immediate, programCounter:decodedSecondInner.programCounter,
        predictedProgramCounter:decodedSecondInner.predictedNextProgramCounter, useImmediate:decodedSecondInner.usesImmediate};
      intRsAllocSecondInputInner = rsAllocSecondBaseInner;
      intRsAllocSecondInputInner.valid = issueSecondFireInner && decodedSecondInner.uopClass == UOP_ALU;
      mulRsAllocSecondInputInner = rsAllocSecondBaseInner;
      mulRsAllocSecondInputInner.valid = issueSecondFireInner && decodedSecondInner.uopClass == UOP_MUL;
      mulRsAllocSecondInputInner.useImmediate = 1'b0;
      divRsAllocSecondInputInner = rsAllocSecondBaseInner;
      divRsAllocSecondInputInner.valid = issueSecondFireInner && decodedSecondInner.uopClass == UOP_DIV;
      divRsAllocSecondInputInner.useImmediate = 1'b0;
      branchRsAllocSecondInputInner = rsAllocSecondBaseInner;
      branchRsAllocSecondInputInner.valid = issueSecondFireInner && decodedSecondInner.uopClass == UOP_BRANCH;
      loadRsAllocSecondInputInner = rsAllocSecondBaseInner;
      loadRsAllocSecondInputInner.valid = lsuLoadAllocationSecondInputInner.valid;
      loadRsAllocSecondInputInner.source2Ready = 1'b1;
      loadRsAllocSecondInputInner.source2Tag = '0;
      loadRsAllocSecondInputInner.source2Value = '0;
      loadRsAllocSecondInputInner.useImmediate = 1'b1;
      saRsAllocSecondInputInner = loadRsAllocSecondInputInner;
      saRsAllocSecondInputInner.valid = lsuStoreAllocationSecondInputInner.valid;
      svRsAllocSecondInputInner = rsAllocSecondBaseInner;
      svRsAllocSecondInputInner.valid = lsuStoreAllocationSecondInputInner.valid;
      svRsAllocSecondInputInner.source1Ready = issueSecondSrc2ReadyInner;
      svRsAllocSecondInputInner.source1Tag = issueSecondSrc2PhyInner;
      svRsAllocSecondInputInner.source1Value = issueSecondSrc2ValueInner;
      svRsAllocSecondInputInner.source2Ready = 1'b1;
      svRsAllocSecondInputInner.source2Tag = '0;
      svRsAllocSecondInputInner.source2Value = '0;
      svRsAllocSecondInputInner.useImmediate = 1'b0;
    end
  end else begin : g_single_rename
    assign issueSecondFireInner = ISSUE_WIDTH==4 ? wideFireInner[1] : 1'b0;
    assign issueSecondResourcesReadyInner = 1'b0;
    assign targetSecondRsReadyInner = 1'b0;
    assign issueSecondIsJumpInner = 1'b0;
    assign issueSecondIsReturnInner = 1'b0;
    assign issueSecondLinkValueInner = '0;
    assign issueSecondSrc1PhyInner = '0;
    assign issueSecondSrc2PhyInner = '0;
    assign issueSecondDestPhyInner = '0;
    assign issueSecondSrc1ReadyInner = 1'b0;
    assign issueSecondSrc2ReadyInner = 1'b0;
    assign issueSecondSrc1ValueInner = '0;
    assign issueSecondSrc2ValueInner = '0;
    assign ratSecondOldPhyInner = '0;
    assign ratReadSecondInputInner = '0;
    assign ratRenameSecondInputInner = '0;
    assign prfAllocSecondInputInner = '0;
    assign robAllocSecondInputInner = '0;
    assign lsuLoadAllocationSecondInputInner = '0;
    assign lsuStoreAllocationSecondInputInner = '0;
    assign rsAllocSecondBaseInner = '0;
    assign intRsAllocSecondInputInner = '0;
    assign mulRsAllocSecondInputInner = '0;
    assign divRsAllocSecondInputInner = '0;
    assign branchRsAllocSecondInputInner = '0;
    assign loadRsAllocSecondInputInner = '0;
    assign saRsAllocSecondInputInner = '0;
    assign svRsAllocSecondInputInner = '0;
    assign prfReadInputInner[COMMIT_WIDTH+2] = '0;
    assign prfReadInputInner[COMMIT_WIDTH+3] = '0;
  end endgenerate

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      haltedInner <= 1'b0;
    end else begin
      for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
        if (retirementFireInner[lane]) begin
          if (robCommitOutputInner[lane].isHalt || (retirementStoreInner[lane] &&
              retirementMemoryInner[lane].address == AXI_EXIT_ADDR)) haltedInner <= 1'b1;
        end
      end
    end
  end
  if (FETCH_WIDTH != 1 && FETCH_WIDTH != 2 && FETCH_WIDTH != 4) begin : g_invalid_fetch_width
    initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2 && COMMIT_WIDTH != 4) begin : g_invalid_commit_width
    initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
  end
  if (COMMIT_WIDTH==4 && ISSUE_WIDTH!=4) begin : g_invalid_four_commit_backend
    initial $fatal(1, "four-commit requires the array four-allocation backend");
  end
  if (ISSUE_WIDTH != 1 && ISSUE_WIDTH != 2 && ISSUE_WIDTH != 4) begin : g_invalid_issue_width
    initial $fatal(1, "ISSUE_WIDTH must be 1, 2 or 4");
  end
`ifndef SYNTHESIS
  for (genvar unitIndex=0;unitIndex<ALU_LANES;unitIndex++) begin : g_alu_hold_check
    logic held;
    alu_execute_output_t previous;
    always_ff @(posedge clkInput or negedge rstNInput) begin
      if (!rstNInput) begin held<=0;previous<='0;end
      else begin
        if (held) assert(aluLaneResultInner[unitIndex]==previous)
          else $fatal(1,"ungranted ALU result was lost or changed");
        held<=aluLaneResultInner[unitIndex].valid && (pipelineFrozenInner || !aluPopReadyInner[unitIndex]) &&
          !(globalFlushInner && !rob_is_older(aluLaneResultInner[unitIndex].robTag,globalFlushTagInner));
        previous<=aluLaneResultInner[unitIndex];
      end
    end
  end
  always @(posedge clkInput) if (rstNInput) begin
    if (ALU_CDB_PORTS==1)
      assert($onehot0(aluResultGrantInner)) else $fatal(1,"two ALUs consumed the single CDB0 together");
    assert($countones(aluIssueFireInner)==$countones(u_int_rs.issueAcceptInner))
      else $fatal(1,"ALU dispatch and real RS departures disagree");
    if (ALU_CDB_PORTS==2) begin
      for (int lane=0;lane<ALU_LANES;lane++)
        assert(writebackInputInner[lane].valid==(aluResultGrantInner[lane] && !aluLaneResultInner[lane].isControl))
          else $fatal(1,"independent ALU grant did not reach its own CDB");
      if (&aluResultGrantInner)
        assert(!(aluLaneResultInner[0].isControl && aluLaneResultInner[1].isControl))
          else $fatal(1,"two jump results consumed one predictor port");
    end
    for (int portIndex=0;portIndex<WRITEBACK_PORTS;portIndex++) for (int peer=0;peer<portIndex;peer++)
      assert(!writebackInputInner[portIndex].valid || !writebackInputInner[peer].valid ||
        writebackInputInner[portIndex].phyTag==0 || writebackInputInner[portIndex].phyTag!=writebackInputInner[peer].phyTag)
        else $fatal(1,"independent CDBs broadcast duplicate live physical identity");
  end
  always @(posedge clkInput) if (rstNInput && !haltedInner) begin
    if (ISSUE_WIDTH==4) begin
      for (int pool=0;pool<7;pool++)for(int lane=0;lane<4;lane++)
        assert(wideRsFireInner[pool][lane]==wideRsAllocInner[pool][lane].valid)
          else $fatal(1,"four rename RS pool did not accept common allocation");
      for(int lane=0;lane<4;lane++)begin
        assert(wideLoadFireInner[lane]==wideLoadAllocInner[lane].valid &&
          wideStoreFireInner[lane]==wideStoreAllocInner[lane].valid)
          else $fatal(1,"four rename LSQ did not accept common allocation");
        if(lane>0)assert(!wideFireInner[lane] || wideFireInner[lane-1])
          else $fatal(1,"four rename did not form a contiguous prefix");
      end
    end
    assert (!issueSecondFireInner || issueFireInner)
      else $fatal(1, "rename lanes did not form an ordered prefix");
    if (ratRenameInputInner.valid && ratRenameSecondInputInner.valid)
      assert (issueDestPhyInner != issueSecondDestPhyInner)
        else $fatal(1, "rename lanes share one destination physical register");
    if (globalFlushInner)
      assert (retirementFireInner == '0)
        else $fatal(1, "architectural SRAM read competed with retirement");
    if (recoveryBusyInner) begin
      if (predictorFetchAcceptInner)
        assert (FETCH_WIDTH == 2 && !LEGACY_HALT && imemFetchHintInput.hit &&
                !imemFetchHintInput.firstControl && !imemFetchHintInput.secondControl)
          else $fatal(1, "recovery prefetch consumed unknown/control packet");
      assert (!predictorFetchInfoInner.valid)
        else $fatal(1, "RAS fetch update overlapped architectural replay");
      assert (!globalFlushInner && !issueFireInner && !robCommitFireInner &&
              !(|writebackValidInner) &&
              !branchResultLiveInner && !lsuAddressInputInner.valid)
        else $fatal(1, "pipeline consumed work during recovery");
      assert (robHeadTagInner == recoveryStepInner.nextTag - recoveryStepInner.offset)
        else $fatal(1, "ROB head moved during recovery");
      assert (robCountInner == recoveryStepInner.squashTag - robHeadTagInner + rob_tag_t'(1))
        else $fatal(1, "ROB recovery window changed during replay");
    end
  end
`endif
endmodule
