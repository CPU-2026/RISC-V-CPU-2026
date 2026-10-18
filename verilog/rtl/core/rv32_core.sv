module rv32_core #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter bit TAGGED_DMEM = 1'b0,
  parameter bit LEGACY_HALT = 1'b0
) (
  input  logic             clkInput,
  input  logic             rstNInput,

  output logic             imemReqValidOutput,
  input  logic             imemReqReadyInput,
  output logic [31:0]      imemReqAddrOutput,
  input  logic             imemRspValidInput,
  input  logic [31:0]      imemRspDataInput,
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

  output logic             haltedOutput,
  output logic             trapOutput
);
  import rv32_pkg::*;

  logic [31:0] predictorPcInner;
  bpu_ckpt_id_t iqPredictorCkptIdInner;
  logic predictorFetchAcceptInner;
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
  rob_predictor_input_t predictorRobInputInner;
  prediction_output_t predictorOutputInner;
  decoded_uop_t decodedInner;

  phy_tag_t ratRs1PhyInner, ratRs2PhyInner, ratOldPhyInner;
  rv32_pkg::rat_read_input_t ratReadInputInner;
  rv32_pkg::rat_read_output_t ratReadOutputInner;
  rv32_pkg::rat_rename_input_t ratRenameInputInner;
  rv32_pkg::rat_rename_output_t ratRenameOutputInner;
  rv32_pkg::rat_restore_input_t ratRestoreInputInner;
  rv32_pkg::rat_commit_input_t ratCommitInputInner;
  phy_tag_t prfAllocPhyInner;
  logic prfAllocReadyInner;
  logic prfSrc1ReadyInner, prfSrc2ReadyInner, prfCommitReadyInner;
  logic [31:0] prfSrc1ValueInner, prfSrc2ValueInner, prfCommitValueInner;
  logic [PRF_ENTRIES-1:0] prfReadyVectorInner;
  rv32_pkg::cdb_result_t [1:0] writebackInputInner;
  rv32_pkg::cdb_result_t [2:0] sharedCdbCandidatesInner;
  rv32_pkg::rob_tag_t [2:0] sharedCdbTagsInner;
  rv32_pkg::rob_tag_t sharedCdbTagInner;
  logic [2:0] sharedCdbGrantInner;
  logic loadResultEligibleInner, mulResultEligibleInner, divResultEligibleInner;
  rv32_pkg::prf_read_input_t [2:0] prfReadInputInner;
  rv32_pkg::prf_read_output_t [2:0] prfReadOutputInner;

  rob_tag_t robAllocTagInner, robHeadTagInner;
  wire rv32_pkg::rob_replay_narrow_t [RECOVERY_WIDTH-1:0] robReplayNarrowInner;
  wire rv32_pkg::rob_replay_ras_t [RECOVERY_WIDTH-1:0] robReplayRasInner;
  rv32_pkg::rob_allocation_input_t robAllocInputInner;
  rv32_pkg::rob_completion_t [5:0] robCompletionInputInner;
  rv32_pkg::rob_lookup_input_t [4:0] robLookupInputInner;
  rv32_pkg::rob_lookup_output_t [4:0] robLookupOutputInner;
  rv32_pkg::rob_commit_output_t robCommitOutputInner;
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
  logic robCommitHaltInner, robCommitExceptionInner;
  logic robEmptyInner, robFullInner;
  logic [4:0] robCountInner;

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
  logic branchFlushCandidateInner, jumpFlushCandidateInner;
  logic [31:0] branchFlushPcInner, jumpFlushPcInner;
  logic predictorUpdateValidInner, predictorMispredictInner;

  logic wbAluValidInner, wbLoadValidInner, wbMulValidInner, wbDivValidInner;
  rv32_pkg::alu_execute_output_t aluExecuteOutputInner;
  rv32_pkg::execute_value_output_t mulExecuteOutputInner;
  rv32_pkg::bru_execute_output_t bruExecuteOutputInner;
  rv32_pkg::execute_value_output_t divExecuteOutputInner;
  logic loadCdbValidInner, mulCdbValidInner, divCdbValidInner;
  logic aluRobLiveInner, loadRobLiveInner, mulRobLiveInner, divRobLiveInner;
  logic aluResultLiveInner, branchResultLiveInner;
  rob_tag_t wbAluTagInner, wbLoadTagInner, wbMulTagInner, wbDivTagInner;
  phy_tag_t wbAluPhyInner, wbLoadPhyInner, wbMulPhyInner, wbDivPhyInner;
  logic [31:0] wbAluValueInner, wbLoadValueInner, wbMulValueInner, wbDivValueInner;
  logic aluCdbValidInner, aluCdbIsControlInner, aluCdbMisalignedInner;

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
  logic bruMisalignedInner;
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

  logic haltedInner, trapInner;
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
  assign aluResultLiveInner = !recoveryBusyInner && aluCdbValidInner && aluRobLiveInner &&
                           (!globalFlushInner ||
                            rob_is_older(wbAluTagInner, globalFlushTagInner));
  assign wbAluValidInner = aluResultLiveInner && !aluCdbIsControlInner;
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
  assign branchFlushCandidateInner = branchResultLiveInner &&
                                  (bruMispredictInner || bruMisalignedInner);
  assign branchFlushPcInner = bruMisalignedInner ? (bruNextPcInner & 32'hffff_fffc) :
                           bruNextPcInner;
  assign jumpFlushCandidateInner = aluResultLiveInner && aluCdbIsControlInner &&
                                 ((wbAluValueInner != jumpRobPredictedPcInner) ||
                                  aluCdbMisalignedInner);
  assign jumpFlushPcInner = aluCdbMisalignedInner ? (wbAluValueInner & 32'hffff_fffc) :
                          wbAluValueInner;
  assign predictorUpdateValidInner = branchResultLiveInner ||
                                  (aluResultLiveInner && aluCdbIsControlInner);
  assign predictorMispredictInner = branchFlushCandidateInner || jumpFlushCandidateInner;
  assign globalFlushInner = flushOutputInner.valid && !recoveryBusyInner && !haltedInner;
  assign recoveryBusyInner = recoveryStepInner.active;
  assign pipelineFrozenInner = haltedInner || recoveryBusyInner;
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
    predictorRobInputInner.willCommit = robCommitFireInner;
    predictorRobInputInner.headTag = robHeadTagInner;
    predictorRobInputInner.isHeadCall = robCommitIsCallInner;
    predictorRobInputInner.isHeadReturn = robCommitIsRetInner;
    predictorRobInputInner.headProgramCounter = robCommitPcInner;
    for (robInputIndexInner = 0; robInputIndexInner < RECOVERY_WIDTH;
         robInputIndexInner = robInputIndexInner + 1)
      predictorRobInputInner.replayRasWindow[robInputIndexInner] =
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
  assign writebackInputInner[0] = '{valid: wbAluValidInner,
                                     phyTag: wbAluPhyInner,
                                     value: wbAluValueInner};
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
    .resultOutput(writebackInputInner[1]), .robTagOutput(sharedCdbTagInner),
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
  assign aluCdbMisalignedInner = aluExecuteOutputInner.controlMisaligned;
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
  assign bruMisalignedInner = bruExecuteOutputInner.misaligned;
  assign prfReadInputInner[0] = '{physicalRegister: ratRs1PhyInner};
  assign prfReadInputInner[1] = '{physicalRegister: ratRs2PhyInner};
  assign prfReadInputInner[2] = '{physicalRegister: robCommitNewPhyInner};
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
  assign ratCommitInputInner = '{valid: robCommitFireInner && robCommitWritesInner,
                                architecturalRegister: robCommitRdInner,
                                physicalRegister: robCommitNewPhyInner};
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
  assign lsuStoreCommitInputInner = '{
    valid: robCommitValidInner && robCommitStoreInner && !globalFlushInner && !pipelineFrozenInner,
    robTag: robCommitTagInner
  };
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
    ready: decodedInner.halt || decodedInner.illegal,
    isStore: decodedInner.uopClass == rv32_pkg::UOP_STORE,
    storeQueueIndex: sqAllocIndexInner,
    isHalt: decodedInner.halt,
    hasException: decodedInner.illegal,
    predictedProgramCounter: decodedInner.predictedNextProgramCounter,
    predictorCheckpointId: decodedInner.predictorCheckpointId,
    isReturn: issueIsReturnInner
  };
  assign robCompletionInputInner[0] = '{valid: aluResultLiveInner,
                                        robTag: wbAluTagInner,
                                        exception: aluCdbMisalignedInner};
  assign robCompletionInputInner[1] = '{valid: writebackInputInner[1].valid,
                                         robTag: sharedCdbTagInner,
                                         exception: 1'b0};
  assign robCompletionInputInner[2] = '0;
  assign robCompletionInputInner[3] = '0;
  assign robCompletionInputInner[4] = '{valid: branchResultLiveInner,
                                        robTag: bruTagInner,
                                        exception: bruMisalignedInner};
  assign robCompletionInputInner[5] = '0;
  assign robLookupInputInner[0] = '{robTag: bruTagInner};
  assign robLookupInputInner[1] = '{robTag: wbAluTagInner};
  assign robLookupInputInner[2] = '{robTag: wbLoadTagInner};
  assign robLookupInputInner[3] = '{robTag: wbMulTagInner};
  assign robLookupInputInner[4] = '{robTag: wbDivTagInner};
  assign robCommitValidInner = robCommitOutputInner.valid;
  assign robCommitFireInner = robCommitFireOutputInner;
  assign robCommitTagInner = robCommitOutputInner.robTag;
  assign robCommitPcInner = robCommitOutputInner.programCounter;
  assign robCommitInstrInner = robCommitOutputInner.instruction;
  assign robCommitWritesInner = robCommitOutputInner.writesArchitecturalRegister;
  assign robCommitRdInner = robCommitOutputInner.architecturalRegister;
  assign robCommitNewPhyInner = robCommitOutputInner.newPhysicalRegister;
  assign robCommitOldPhyInner = robCommitOutputInner.oldPhysicalRegister;
  assign robCommitSqIndexInner = robCommitOutputInner.storeQueueIndex;
  assign robCommitHaltInner = robCommitOutputInner.isHalt;
  assign robCommitExceptionInner = robCommitOutputInner.hasException;
  assign robEmptyInner = robStatusOutputInner.empty;
  assign robFullInner = robStatusOutputInner.full;
  assign robHeadTagInner = robStatusOutputInner.headTag;
  assign bruRobLiveInner = robLookupOutputInner[0].valid;
  assign bruRobPcInner = robLookupOutputInner[0].programCounter;
  assign bruRobPredictedPcInner = robLookupOutputInner[0].predictedProgramCounter;
  assign bruRobCkptIdInner = robLookupOutputInner[0].predictorCheckpointId;
  assign bruRobIsRetInner = robLookupOutputInner[0].isReturn;
  assign jumpRobLiveInner = robLookupOutputInner[1].valid;
  assign jumpRobPcInner = robLookupOutputInner[1].programCounter;
  assign jumpRobPredictedPcInner = robLookupOutputInner[1].predictedProgramCounter;
  assign jumpRobCkptIdInner = robLookupOutputInner[1].predictorCheckpointId;
  assign jumpRobIsRetInner = robLookupOutputInner[1].isReturn;
  assign loadRobLiveInner = robLookupOutputInner[2].valid;
  assign mulRobLiveInner = robLookupOutputInner[3].valid;
  assign divRobLiveInner = robLookupOutputInner[4].valid;
  assign predictorFetchAcceptInner = predictorQueryOutputInner.accepted;
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

  rv32_flush_arbiter u_flush_arbiter (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .branchInput(branchFlushInputInner),
    .jumpInput(jumpFlushInputInner),
    .squashOutput(flushOutputInner)
  );

  rv32_frontend #(.RESET_PC(RESET_PC), .LEGACY_HALT(LEGACY_HALT)) u_frontend (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .predictorQueryOutput(predictorQueryOutputInner),
    .fetchProgramCounterOutput(predictorPcInner),
    .predictionInput(predictorOutputInner),
    .imemRequestOutput(frontendImemRequestOutputInner),
    .imemReqReadyInput(imemReqReadyInput && bootDoneInner && !haltedInner),
    .imemResponseInput(frontendImemResponseInputInner),
    .imemRspReadyOutput(imemRspReadyOutput), .imemFlushOutput(imemFlushOutput),
    .redirectInput(frontendRedirectInputInner),
    .instructionOutput(frontendInstructionOutputInner),
    .iqReadyInput(frontendIqReadyInner),
    .fetchInfoOutput(fetchInfoOutputInner),
    .fqCountOutput(), .iqCountOutput()
  );

  rv32_predictor u_predictor (
    .freezeInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput), .queryPcInput(predictorPcInner),
    .fetchAcceptInput(predictorFetchAcceptInner),
    .fetchInfoInput(predictorFetchInfoInner),
    .branchInput(predictorBranchInputInner),
    .jumpInput(predictorJumpInputInner),
    .squashInput(predictorSquashInputInner),
    .robInput(predictorRobInputInner),
    .recoveryInput(recoveryStepInner),
    .predictionOutput(predictorOutputInner)
  );

  rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder (
    .decodeContextInput(decodeContextInner), .uopOutput(decodedInner)
  );

  rv32_add #(.WIDTH(32)) u_link_add (
    .aInput(decodedInner.programCounter), .bInput(32'd4), .cinInput(1'b0),
    .sumOutput(issueLinkValueInner), .coutOutput(unusedCoutLinkInner)
  );

  rv32_rat u_rat (
    .freezeInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .readInput(ratReadInputInner), .readOutput(ratReadOutputInner),
    .renameInput(ratRenameInputInner), .renameOutput(ratRenameOutputInner),
    .restoreInput(ratRestoreInputInner),
    .recoveryInput(recoveryStepInner),
    .replayInput(robReplayNarrowInner),
    .commitInput(ratCommitInputInner)
  );

  rv32_prf #(.WRITEBACK_PORTS(2)) u_prf (
    .freezeInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .allocationInput('{valid: issueFireInner && decodedInner.writesRd,
                      valueValid: issueFireInner && decodedInner.writesRd && issueIsJumpInner,
                      value: issueLinkValueInner}),
    .allocReadyOutput(prfAllocReadyInner), .allocPhyOutput(prfAllocPhyInner),
    .freeInput('{valid: robCommitFireInner && robCommitWritesInner,
                physicalRegister: robCommitOldPhyInner}),
    .restoreInput('{valid: globalFlushInner, squashTag: globalFlushTagInner}),
    .recoveryInput(recoveryStepInner),
    .restoreCountInput(robCountInner),
    .replayInput(robReplayNarrowInner),
    .readInput(prfReadInputInner), .readOutput(prfReadOutputInner),
    .writebackInput(writebackInputInner),
    .readyVectorOutput(prfReadyVectorInner), .freeCountOutput()
  );

  rv32_rob u_rob (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .allocInput(robAllocInputInner), .allocReadyOutput(robAllocReadyInner),
    .allocTagOutput(robAllocTagInner),
    .completionInput(robCompletionInputInner),
    .storeReadyInput(lsuStoreCompleteOutputInner),
    .flushInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .lookupInput(robLookupInputInner), .lookupOutput(robLookupOutputInner),
    .commitOutput(robCommitOutputInner), .commitStoreOutput(robCommitStoreInner),
    .commitReadyInput(robCommitReadyInner), .commitFireOutput(robCommitFireOutputInner),
    .statusOutput(robStatusOutputInner), .countOutput(robCountInner),
    .replayOffsetInput(recoveryStepInner.offset),
    .replayNarrowOutput(robReplayNarrowInner),
    .replayRasOutput(robReplayRasInner)
  );

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
    issueFireInner = bootDoneInner && frontendIqValidInner && issueResourcesReadyInner &&
                  !globalFlushInner && !pipelineFrozenInner && !trapInner;
    frontendIqReadyInner = issueFireInner;

    // The read edge must not compete with an architectural SRAM write. Holding
    // retirement also keeps the head-ordered replay window stable for all beats.
    robCommitReadyInner = !pipelineFrozenInner && !globalFlushInner &&
      (robCommitStoreInner ? lsuStoreCommitReadyInner : 1'b1);
    commitValidOutput = robCommitFireInner;
    commitPcOutput = robCommitPcInner;
    commitInstrOutput = robCommitInstrInner;
    commitRdValidOutput = robCommitFireInner && robCommitWritesInner &&
                        (robCommitRdInner != 5'd0) && !robCommitExceptionInner;
    commitRdOutput = robCommitRdInner;
    commitRdValueOutput = prfCommitValueInner;
    commitMemValidOutput = robCommitFireInner && robCommitStoreInner;
    commitMemAddrOutput = lsuStoreRetirementOutputInner.address;
    commitMemDataOutput = lsuStoreRetirementOutputInner.writeData;
    commitMemWstrbOutput = lsuStoreRetirementOutputInner.writeStrobe;
    // HALT commits immediately; no SQ/cache/memory drain (software-aligned).
    haltedOutput = haltedInner;
    trapOutput = trapInner;
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

  rv32_rs #(.DEPTH(INT_RS_ENTRIES), .AUX_W(1), .WRITEBACK_PORTS(2)) u_int_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(intRsAllocInputInner),
    .allocReadyOutput(intAllocReadyInner), .allocAuxInput(issueIsJumpInner),
    .writebackInput(writebackInputInner),
    .issueOutput(intRsIssueOutputInner), .issueReadyInput(intIssueReadyInner),
    .issueAuxOutput(intIssueAuxInner),
    .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
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

  rv32_rs #(.DEPTH(MUL_RS_ENTRIES), .AUX_W(1), .WRITEBACK_PORTS(2)) u_mul_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(mulRsAllocInputInner), .allocReadyOutput(mulAllocReadyInner),
    .allocAuxInput(1'b0),
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

  rv32_rs #(.DEPTH(DIV_RS_ENTRIES), .AUX_W(1), .WRITEBACK_PORTS(2)) u_div_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(divRsAllocInputInner), .allocReadyOutput(divAllocReadyInner),
    .allocAuxInput(1'b0),
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

  rv32_rs #(.DEPTH(BRANCH_RS_ENTRIES), .AUX_W(3), .WRITEBACK_PORTS(2)) u_branch_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(branchRsAllocInputInner), .allocReadyOutput(branchAllocReadyInner),
    .allocAuxInput({1'b0, issueIsReturnInner, issueIsCallInner}),
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

  rv32_rs #(.DEPTH(LOAD_RS_ENTRIES), .AUX_W(4), .WRITEBACK_PORTS(2)) u_load_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(loadRsAllocInputInner), .allocReadyOutput(loadRsAllocReadyInner),
    .allocAuxInput({1'b0, lqAllocIndexInner}),
    .writebackInput(writebackInputInner),
    .issueOutput(loadRsIssueOutputInner), .issueReadyInput(loadRsIssueReadyInner),
    .issueAuxOutput(loadAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  rv32_rs #(.DEPTH(STORE_ADDR_RS_ENTRIES), .AUX_W(4), .WRITEBACK_PORTS(2)) u_store_addr_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(saRsAllocInputInner), .allocReadyOutput(saRsAllocReadyInner),
    .allocAuxInput({1'b1, sqAllocIndexInner}), .writebackInput(writebackInputInner),
    .issueOutput(saRsIssueOutputInner), .issueReadyInput(saRsIssueReadyInner),
    .issueAuxOutput(saAuxInner), .occupancyOutput(), .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput()
  );
  rv32_rs #(.DEPTH(STORE_VALUE_RS_ENTRIES), .AUX_W(3),
             .ISSUE_WIDTH(STORE_VALUE_RS_ENTRIES), .WRITEBACK_PORTS(2)) u_store_value_rs (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .allocInput(svRsAllocInputInner), .allocReadyOutput(svRsAllocReadyInner),
    .allocAuxInput(sqAllocIndexInner), .writebackInput(writebackInputInner),
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

  rv32_alu_unit #(.DEPTH(rv32_pkg::ALU_RESULT_ENTRIES)) u_alu_unit (
    .freezeInput(pipelineFrozenInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .executeInput('{valid: intIssueValidInner,
                   operation: intIssueOpInner,
                   source1: intIssueS1Inner,
                   source2: intIssueS2Inner,
                   immediate: intIssueImmInner,
                   programCounter: intIssuePcInner,
                   predictedNextProgramCounter: intIssuePredInner,
                   useImmediate: intIssueUseImmInner,
                   robTag: intIssueTagInner,
                   destinationPhy: intIssuePhyInner,
                   isControl: intIssueAuxInner[0],
                   isCall: 1'b0,
                   isReturn: 1'b0}),
    .inReadyOutput(intIssueReadyInner), .outReadyInput(1'b1),
    .executeOutput(aluExecuteOutputInner), .occupancyOutput()
  );

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

  rv32_bru_unit u_bru_unit (
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
             .WRITEBACK_PORTS(2)) u_lsu (
    .coreStoppedInput(haltedInner),
    .clkInput(clkInput), .rstNInput(rstNInput),
    .flushInfoInput('{valid: globalFlushInner, robTag: globalFlushTagInner}),
    .loadAllocationInput(lsuLoadAllocationInputInner),
    .loadAllocReadyOutput(lqAllocReadyInner), .loadAllocIndexOutput(lqAllocIndexInner),
    .storeAllocationInput(lsuStoreAllocationInputInner),
    .storeAllocReadyOutput(sqAllocReadyInner), .storeAllocIndexOutput(sqAllocIndexInner),
    .storeDataInput(svRsStoreDataInner),
    .storeDataIndexInput(svRsStoreDataIndexInner),
    .addressInput(lsuAddressInputInner), .addressIndexInput(aguResultAuxInner[2:0]),
    .writebackInput(writebackInputInner),
    .loadResultOutput(lsuLoadResultOutputInner), .loadResultReadyInput(wbLoadValidInner),
    .robRetireInput('{valid: robCommitFireOutputInner, robTag: robCommitOutputInner.robTag}),
    .storeCompleteOutput(lsuStoreCompleteOutputInner),
    .storeCommitInput(lsuStoreCommitInputInner),
    .storeCommitIndexInput(robCommitSqIndexInner),
    .storeCommitReadyOutput(lsuStoreCommitReadyInner),
    .storeRetirementOutput(lsuStoreRetirementOutputInner),
    .dmemRequestOutput(lsuDmemRequestOutputInner), .dmemReqReadyInput(dmemReqReadyInput),
    .dmemResponseInput(lsuDmemResponseInputInner),
    .dmemReqTransactionOutput(dmemReqTransactionOutput), .dmemRspTransactionInput(dmemRspTransactionInput),
    .lqCountOutput(), .sqCountOutput(sqCountInner)
  );

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      haltedInner <= 1'b0;
      trapInner <= 1'b0;
    end else if (robCommitFireInner) begin
      if (robCommitHaltInner || (robCommitStoreInner &&
          lsuStoreRetirementOutputInner.address == AXI_EXIT_ADDR))
        haltedInner <= 1'b1;
      if (robCommitExceptionInner)
        trapInner <= 1'b1;
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !haltedInner) begin
    if (globalFlushInner)
      assert (!robCommitFireInner && !ratCommitInputInner.valid)
        else $fatal(1, "architectural SRAM read competed with retirement");
    if (recoveryBusyInner) begin
      assert (!globalFlushInner && !issueFireInner && !robCommitFireInner &&
              !writebackInputInner[0].valid && !writebackInputInner[1].valid &&
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
