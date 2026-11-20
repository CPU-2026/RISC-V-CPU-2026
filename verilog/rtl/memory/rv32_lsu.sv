module rv32_lsu #(
  parameter int unsigned LQ_DEPTH = rv32_pkg::LQ_ENTRIES,
  parameter int unsigned SQ_DEPTH = rv32_pkg::SQ_ENTRIES,
  // Store-queue data ports driven by the storeValue RS.  One lane per RS slot
  // so every store whose data resolves in the same cycle is delivered at once;
  // the RV32IM core instantiates it with STORE_VALUE_RS_ENTRIES.
  parameter int unsigned STORE_DATA_LANES = 1,
  // Bare-core legacy word-memory tests may omit IDs. Cached integration MUST
  // enable tagged completion: hit-under-miss no longer preserves send order.
  parameter bit TAGGED_DMEM = 1'b0,
  parameter bit RESPONSE_PREVIEW = 1'b0,
  parameter int unsigned WRITEBACK_PORTS = 4,
  parameter int unsigned COMMIT_WIDTH = 1,
  parameter int unsigned RENAME_WIDTH = 1
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  logic                   coreStoppedInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,

  input  rv32_pkg::load_allocation_input_t loadAllocationInput,
  output logic                   loadAllocReadyOutput,
  output logic [$clog2(LQ_DEPTH)-1:0] loadAllocIndexOutput,
  input rv32_pkg::load_allocation_input_t loadAllocationSecondInput,
  output logic loadAllocSecondReadyOutput,
  output logic [$clog2(LQ_DEPTH)-1:0] loadAllocSecondIndexOutput,

  input  rv32_pkg::store_allocation_input_t storeAllocationInput,
  output logic                   storeAllocReadyOutput,
  output logic [$clog2(SQ_DEPTH)-1:0] storeAllocIndexOutput,
/* verilator lint_off UNUSEDSIGNAL */   input rv32_pkg::store_allocation_input_t storeAllocationSecondInput, /* verilator lint_on UNUSEDSIGNAL */
  output logic storeAllocSecondReadyOutput,
  output logic [$clog2(SQ_DEPTH)-1:0] storeAllocSecondIndexOutput,

  input rv32_pkg::store_data_input_t storeDataInput [STORE_DATA_LANES-1:0],
  input logic [$clog2(SQ_DEPTH)-1:0] storeDataIndexInput [STORE_DATA_LANES-1:0],

  input  rv32_pkg::lsu_address_input_t addressInput,
  input  logic [(($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH)) ?
                 $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH))-1:0] addressIndexInput,

  input  rv32_pkg::cdb_result_t [WRITEBACK_PORTS-1:0] writebackInput,

  output rv32_pkg::load_result_output_t loadResultOutput,
  input  logic                   loadResultReadyInput,
  input  rv32_pkg::rob_retirement_input_t [COMMIT_WIDTH-1:0] robRetireInput,

  output rv32_pkg::store_completion_output_t storeCompleteOutput,

  input  rv32_pkg::store_commit_input_t [COMMIT_WIDTH-1:0] storeCommitInput,
  input  logic [COMMIT_WIDTH-1:0][$clog2(SQ_DEPTH)-1:0] storeCommitIndexInput,
  output logic [COMMIT_WIDTH-1:0] storeCommitReadyOutput,
  // ROB-head payload, independent of the older Store selected for memory.
  output rv32_pkg::data_memory_request_output_t [COMMIT_WIDTH-1:0] storeRetirementOutput,

  output rv32_pkg::data_memory_request_output_t dmemRequestOutput,
  input  logic                   dmemReqReadyInput,
  input  rv32_pkg::data_memory_response_input_t dmemResponseInput,
  output rv32_pkg::data_transaction_t dmemReqTransactionOutput,
  input rv32_pkg::data_transaction_t dmemRspTransactionInput,
  input rv32_pkg::data_transaction_t [1:0] responsePreviewTransactionInput,
  input logic [1:0] responsePreviewSelectInput,

  output logic [$clog2(LQ_DEPTH+1)-1:0] lqCountOutput,
  output logic [$clog2(SQ_DEPTH+1)-1:0] sqCountOutput,
  // Ordered issue4 allocation only. Memory/AGU/result transport stays scalar.
  input rv32_pkg::load_allocation_input_t [3:0] loadAllocationLanesInput,
  input rv32_pkg::store_allocation_input_t [3:0] storeAllocationLanesInput,
  output logic [3:0] loadAllocationLanesFireOutput, storeAllocationLanesFireOutput,
  output logic [3:0][$clog2(LQ_DEPTH)-1:0] loadPreviewIndexOutput,
  output logic [3:0][$clog2(SQ_DEPTH)-1:0] storePreviewIndexOutput,
  output logic [$clog2(LQ_DEPTH+1)-1:0] loadCreditsOutput,
  output logic [$clog2(SQ_DEPTH+1)-1:0] storeCreditsOutput,
  // Permission for NEW reordering only; normal LSU drain/response is unchanged.
  input logic loadYieldEnableInput
);
  import rv32_pkg::*;
  if (RENAME_WIDTH != 1 && RENAME_WIDTH != 2 && RENAME_WIDTH != 4) begin : g_invalid_rename_width
    initial $fatal(1, "RENAME_WIDTH must be 1, 2 or 4");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2 && COMMIT_WIDTH != 4) begin : g_invalid_commit_width
    initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
  end

  localparam int unsigned LQ_INDEX_W = $clog2(LQ_DEPTH);
  localparam int unsigned SQ_INDEX_W = $clog2(SQ_DEPTH);

  // Redundant facts describe the SAME OLD LQ state as the original fields.
  // Their D inputs replay the original NBA writer order, not last-cycle facts.
  logic [LQ_DEPTH-1:0] loadRequestBaseInner, loadInsertableInner, loadPendingAddressInner;
  logic [LQ_DEPTH-1:0] loadRequestBaseNextInner, loadInsertableNextInner, loadPendingAddressNextInner;
  rob_tag_t [LQ_DEPTH-1:0] summaryTagNextInner;
  wire [LQ_DEPTH-1:0][LQ_DEPTH-1:0] loadPairOlderCachedInner;
  wire loadSummaryTagEventInner=addressInput.valid && !addressInput.isStore &&
    lqTagInner[addressIndexInput]==addressInput.robTag &&
    (!flushInfoInput.valid || rob_is_older(addressInput.robTag,flushInfoInput.robTag));
  logic lqValidInner [LQ_DEPTH];
  rob_tag_t lqTagInner [LQ_DEPTH];
  phy_tag_t lqDestInner [LQ_DEPTH];
  mem_size_e lqSizeInner [LQ_DEPTH];
  logic lqUnsignedInner [LQ_DEPTH];
  logic lqAddressReadyInner [LQ_DEPTH];
  logic [31:0] lqAddressInner [LQ_DEPTH];
  logic lqSentInner [LQ_DEPTH];
  logic lqResultReadyInner [LQ_DEPTH];
  logic lqBroadcastedInner [LQ_DEPTH];
  // Raw 32-bit word, whatever the source. Width/sign live on the row and are
  // applied once when the result is read out, never at the writers.
  logic [31:0] lqResultInner [LQ_DEPTH];

  logic sqValidInner [SQ_DEPTH];
  rob_tag_t sqTagInner [SQ_DEPTH];
  mem_size_e sqSizeInner [SQ_DEPTH];
  logic sqAddressReadyInner [SQ_DEPTH];
  logic [31:0] sqAddressInner [SQ_DEPTH];
  logic sqDataReadyInner [SQ_DEPTH];
  phy_tag_t sqDataTagInner [SQ_DEPTH];
  logic [31:0] sqDataInner [SQ_DEPTH];
  logic sqCommittedInner [SQ_DEPTH];
  // SQ order outlives the ROB age window. Allocation/acceptance advance these
  // epoch pointers; recovery rewinds only the uncommitted suffix.
  logic [SQ_INDEX_W:0] sqHeadSeqInner, sqTailSeqInner;
  logic [SQ_INDEX_W-1:0] sqHeadIndexInner;
  logic [SQ_INDEX_W:0] sqRetainedCountInner;

  // Eight immutable transport owners. In tagged mode slots release independently;
  // cancelled owners remain live until their exact response returns, even across
  // LQ/ROB reuse. Width/sign belong to the accepted owner, not the current LQ row.
  data_transaction_t fifoHeadInner, fifoTailInner;
  logic [DATA_TRANSACTION_W:0] fifoCountInner;
  // Size/sign are not copied per entry: the completion guard proves the row was
  // never reused, so the row's own fields describe the accepted transaction.
  logic [LQ_INDEX_W-1:0] fifoIndexInner [DATA_REQUEST_ENTRIES];
  rob_tag_t fifoTagInner [DATA_REQUEST_ENTRIES];
  logic fifoDropInner [DATA_REQUEST_ENTRIES];
  logic fifoValidInner [DATA_REQUEST_ENTRIES];
  data_transaction_t responseOwnerInner, allocationOwnerInner;
  always_comb begin
    logic found;
/* verilator lint_off UNUSEDSIGNAL */     int slot; /* verilator lint_on UNUSEDSIGNAL */
    found = 0;
    allocationOwnerInner = fifoTailInner;
    for (int i = 0; i < DATA_REQUEST_ENTRIES; i++) begin
      slot = (int'(fifoTailInner) + i) & (DATA_REQUEST_ENTRIES-1);
      if (TAGGED_DMEM && !found && !fifoValidInner[slot]) begin
        allocationOwnerInner = data_transaction_t'(slot);
        found = 1;
      end
    end
  end
  assign responseOwnerInner = TAGGED_DMEM ? dmemRspTransactionInput : fifoHeadInner;
  assign dmemReqTransactionOutput = allocationOwnerInner;

  logic loadAllocFoundInner;
  logic storeAllocFoundInner;
  logic loadAllocFireInner, loadAllocSecondFireInner;
  logic storeAllocFireInner, storeAllocSecondFireInner;
  logic [SQ_INDEX_W:0] storeAllocCountInner;
  logic [SQ_INDEX_W:0] storeAllocLanesCountInner;
  logic [3:0][LQ_INDEX_W-1:0] loadLanesIndexInner;
  logic [3:0][SQ_INDEX_W-1:0] storeLanesIndexInner;
  logic [3:0] storeLanesDataReadyInner;
  logic [3:0][31:0] storeLanesDataValueInner;
  logic [SQ_INDEX_W:0] sqUsedInner;
  assign sqUsedInner = sqTailSeqInner - sqHeadSeqInner;
  logic storeAllocSecondDataReadyInner;
  logic [31:0] storeAllocSecondDataValueInner;
  assign loadAllocFireInner = loadAllocationInput.valid && loadAllocReadyOutput;
  assign loadAllocSecondFireInner = RENAME_WIDTH == 2 && loadAllocationSecondInput.valid && loadAllocSecondReadyOutput;
  assign storeAllocFireInner = storeAllocationInput.valid && storeAllocReadyOutput;
  assign storeAllocSecondFireInner = RENAME_WIDTH == 2 && storeAllocationSecondInput.valid && storeAllocSecondReadyOutput;
  assign storeAllocCountInner = RENAME_WIDTH==4 ? storeAllocLanesCountInner :
    (SQ_INDEX_W+1)'(storeAllocFireInner) + (SQ_INDEX_W+1)'(storeAllocSecondFireInner);
  logic loadSelectFoundInner;
  logic [LQ_INDEX_W-1:0] loadSelectIndexInner;
  rob_tag_t loadSelectTagInner;
  logic [31:0] loadSelectAddressInner;
  // Carry the winner's tag through a balanced tournament. Re-reading the tag
  // through the previous winner's index serializes every comparison in a loop.
  localparam int unsigned LOAD_SELECT_LEAVES = 1 << LQ_INDEX_W;
  typedef struct packed {
    logic valid;
    rob_tag_t tag;
    logic [LQ_INDEX_W-1:0] index;
  } load_select_t;
  logic [LQ_DEPTH-1:0] loadSelectCandidatesInner;
  rob_tag_t [LQ_DEPTH-1:0] loadSelectTagsInner;
  load_select_t loadSelectWinnerInner;
  logic loadBlockedInner;
  // SQ qualification is a pure function of OLD rows. Prepare each old
  // Load row before the late winner/address mux; AGU uses the existing query.
  wire loadRequestUsesAddressInner;
  wire [LQ_DEPTH-1:0] oldRequestCacheBlockedInner, oldRequestYieldsInner, oldPostedStoreBlocksInner;
  wire [SQ_DEPTH-1:0] postedStoreUnsafeInner, incomingPostedBlockInner;
  wire incomingRequestYieldsInner, selectedRequestYieldsInner;
  logic loadNeedsMemoryInner;
  logic selectedLoadLiveInner;

  typedef struct packed {
    // Forward-query blocking and Cache admission are distinct predicates.
    logic blocked;
    logic cacheBlocked;
    logic [3:0] mask;
    logic [31:0] data;
  } store_forward_result_t;
  logic storeDataEventInner [STORE_DATA_LANES];
  logic storeAddressEventInner, loadAddressEventInner;
  logic lqEarlyForwardInner [LQ_DEPTH];
  logic [31:0] lqEarlyValueInner [LQ_DEPTH];
/* verilator lint_off UNUSEDSIGNAL */   store_forward_result_t selectedForwardInner; /* verilator lint_on UNUSEDSIGNAL */
  store_forward_result_t addressedForwardInner;
  logic addressedForwardValidInner;
  integer forwardIndexInner;

  logic resultSelectFoundInner;
  logic [LQ_INDEX_W-1:0] resultSelectIndexInner;
  rob_tag_t resultSelectTagInner;
  logic [LQ_DEPTH-1:0] resultSelectCandidatesInner;
  load_select_t resultSelectWinnerInner;
  load_select_t bufferedResultWinnerInner;
  logic chooseResponseResultInner;
  logic responseResultLiveInner;
  logic responseResultIdentityLiveInner;
  logic responseForwardPriorityInner;
  logic [LQ_INDEX_W-1:0] responseResultIndexInner;
  assign responseResultIndexInner = fifoIndexInner[responseOwnerInner];
  // C: authenticated late response competes with buffered results by ROB age.
  // Full Store forwarding retains priority; ordinary result capture remains.
  logic storeAllocDataReadyResolvedInner;
  logic [31:0] storeAllocDataValueResolvedInner;
  logic [COMMIT_WIDTH-1:0] storeCommitMatchInner, storeRetireFireInner;
  logic storeAvailableInner, storeSendSelectedInner;
  logic storeYieldDebtInner, loadBypassStoreInner, postedStoreBlocksLoadInner;
  logic [SQ_DEPTH-1:0] postedStoreMaskInner;
  wire [SQ_DEPTH-1:0] pressureSqValidInner;
  wire pressureLowInner;
  for(genvar row=0;row<SQ_DEPTH;row++)begin : g_pressure_sq
    assign pressureSqValidInner[row]=sqValidInner[row];
  end
  // OLD allocated SQ occupancy includes uncommitted/speculative Stores.
  // Outstanding owners include cancelled Loads until their real response.
  assign pressureLowInner=($countones(pressureSqValidInner)<=4) && (int'(fifoCountInner)<=0);
  logic loadAddressMatchInner, storeAddressMatchInner;
  logic loadRequestSelectedInner;
  integer combIndexInner;
  integer seqIndexInner;
  integer storeLaneInner;

  function automatic load_select_t select_oldest_load(
    input logic [LQ_DEPTH-1:0] validInput,
    input rob_tag_t [LQ_DEPTH-1:0] tagsInput
  );
    load_select_t tree [2*LOAD_SELECT_LEAVES];
    tree[0] = '0;
    for (int leaf = 0; leaf < LOAD_SELECT_LEAVES; leaf++) begin
      tree[LOAD_SELECT_LEAVES+leaf] = '0;
      if (leaf < LQ_DEPTH)
        tree[LOAD_SELECT_LEAVES+leaf] = '{valid:validInput[leaf], tag:tagsInput[leaf], index:LQ_INDEX_W'(leaf)};
    end
    // Constant node dependencies form log2(LEAVES) levels, not a running winner.
    // Strict age comparison preserves the serial scan's lower-slot tie winner.
    for (int node = LOAD_SELECT_LEAVES-1; node > 0; node--) begin
      tree[node] = tree[2*node];
      if (tree[2*node+1].valid &&
          (!tree[2*node].valid || rob_is_older(tree[2*node+1].tag, tree[2*node].tag)))
        tree[node] = tree[2*node+1];
    end
    if (!tree[1].valid) tree[1].index = '0;
    return tree[1];
  endfunction
  // Request insertion trees share OLD leaf-pair age bits. Each internal
  // node keeps its original fixed left/right decision, not a global rank.
  // No transitivity or live ROB-window assumption is used.
  wire [LQ_DEPTH-1:0][LQ_DEPTH-1:0] loadTreePairOlderInner;
  for(genvar right=0;right<LQ_DEPTH;right++)begin : g_load_tree_pair_right
    for(genvar left=0;left<LQ_DEPTH;left++)begin : g_left
      if(right>left)begin : g_pair
        assign loadTreePairOlderInner[right][left]=loadPairOlderCachedInner[right][left];
      end else begin : g_unused_pair
        assign loadTreePairOlderInner[right][left]=1'b0;
        assign loadPairOlderCachedInner[right][left]=1'b0;
      end
    end
  end
  function automatic load_select_t select_load_pair_flags(
    input logic [LQ_DEPTH-1:0] validInput,
    input rob_tag_t [LQ_DEPTH-1:0] tagsInput,
    input logic [LQ_DEPTH-1:0][LQ_DEPTH-1:0] olderInput
  );
    logic [LQ_DEPTH-1:0] pathTree [2*LOAD_SELECT_LEAVES];
    logic validTree [2*LOAD_SELECT_LEAVES];
    logic rightOlder;
    load_select_t answer;
    pathTree[0]='0;validTree[0]=1'b0;
    for(int leaf=0;leaf<LOAD_SELECT_LEAVES;leaf++)begin
      pathTree[LOAD_SELECT_LEAVES+leaf]='0;
      validTree[LOAD_SELECT_LEAVES+leaf]=1'b0;
      if(leaf<LQ_DEPTH)begin
        // Even invalid real leaves carry their original tag identity. If all
        // rows are invalid, the original tree exposes leaf0 tag, not zero.
        pathTree[LOAD_SELECT_LEAVES+leaf]=LQ_DEPTH'(1)<<leaf;
        validTree[LOAD_SELECT_LEAVES+leaf]=validInput[leaf];
      end
    end
    for(int node=LOAD_SELECT_LEAVES-1;node>0;node--)begin
      rightOlder=1'b0;
      for(int right=1;right<LQ_DEPTH;right++)
        for(int left=0;left<right;left++)
          rightOlder|=pathTree[2*node+1][right] && pathTree[2*node][left] && olderInput[right][left];
      pathTree[node]=pathTree[2*node];
      validTree[node]=validTree[2*node];
      if(validTree[2*node+1] && (!validTree[2*node] || rightOlder))begin
        pathTree[node]=pathTree[2*node+1];
        validTree[node]=validTree[2*node+1];
      end
    end
    answer='0;answer.valid=validTree[1];
    for(int row=0;row<LQ_DEPTH;row++)begin
      answer.tag|=tagsInput[row] & {ROB_TAG_W{pathTree[1][row]}};
      answer.index|=LQ_INDEX_W'(row) & {LQ_INDEX_W{pathTree[1][row]}};
    end
    if(!answer.valid)answer.index='0;
    return answer;
  endfunction
  for (genvar row = 0; row < LQ_DEPTH; row++) begin : g_load_select_candidate
    // B: only the already-reserved old LQ identity may use its incoming AGU
    // address before capture, and full SQ forwarding avoids a redundant read.
    assign loadSelectCandidatesInner[row] = lqValidInner[row] &&
      (lqAddressReadyInner[row] ||
       (loadAddressEventInner && addressIndexInput == $bits(addressIndexInput)'(row) &&
        !(!lqBroadcastedInner[row] && addressedForwardValidInner))) &&
      !lqSentInner[row] && !lqResultReadyInner[row];
    assign loadSelectTagsInner[row] = lqTagInner[row];
    // Buffered arbitration depends only on OLD state. A late Cache return
    // competes once with this winner, rather than traversing all tree levels.
    assign resultSelectCandidatesInner[row] = lqValidInner[row] && lqResultReadyInner[row] &&
      !lqBroadcastedInner[row];
  end
  // Only OLD LQ fields enter these complete original-tree alternatives.
  // The AGU event/index and forwarding decision do not enter their age trees.
  wire [LQ_DEPTH-1:0] loadInsertBaseMaskInner, loadInsertEligibleInner;
  wire load_select_t loadInsertBaseWinnerInner;
  wire load_select_t loadInsertWinnerInner [LQ_DEPTH];
  for(genvar row=0;row<LQ_DEPTH;row++)begin : g_load_address_insertion
    wire [LQ_DEPTH-1:0] insertedMask;
    assign loadInsertBaseMaskInner[row]=loadRequestBaseInner[row];
    assign loadInsertEligibleInner[row]=loadInsertableInner[row];
    assign insertedMask=loadInsertBaseMaskInner |
      ((LQ_DEPTH'(1)<<row) & {LQ_DEPTH{loadInsertEligibleInner[row]}});
    assign loadInsertWinnerInner[row]=select_load_pair_flags(insertedMask,loadSelectTagsInner,loadTreePairOlderInner);
  end
  assign loadInsertBaseWinnerInner=select_load_pair_flags(loadInsertBaseMaskInner,loadSelectTagsInner,loadTreePairOlderInner);
  // Preserve the old ready-row candidate even when the new address forwards.
  // No event, flush/identity rejection, or suppressed insertion uses baseTree.
  // I=0 makes the inserted tree byte-identical to base, even for no winner.
  assign loadSelectWinnerInner=loadSummaryTagEventInner && loadInsertableInner[addressIndexInput] &&
    (lqBroadcastedInner[addressIndexInput] || !addressedForwardValidInner) ?
    loadInsertWinnerInner[addressIndexInput] : loadInsertBaseWinnerInner;
`ifndef SYNTHESIS
  always_comb begin
    assert(loadSelectWinnerInner==select_oldest_load(loadSelectCandidatesInner,loadSelectTagsInner))
      else $fatal(1,"LQ insertion exact original tree oracle");
  end
`endif
  assign loadSelectFoundInner = loadSelectWinnerInner.valid;
  assign loadSelectIndexInner = loadSelectWinnerInner.index;
  assign loadSelectTagInner = loadSelectWinnerInner.tag;
  // P includes OLD validity, preserving even row0 inactive payload selection.
  assign loadRequestUsesAddressInner = loadSummaryTagEventInner && loadPendingAddressInner[addressIndexInput] &&
    addressIndexInput == $bits(addressIndexInput)'(loadSelectIndexInner);
  assign loadSelectAddressInner = loadRequestUsesAddressInner ?
    addressInput.address : lqAddressInner[loadSelectIndexInner];
  // A separate combinational tournament: result production must not compete
  // with request selection for hardware or gain an extra register stage.
  always_comb bufferedResultWinnerInner = select_oldest_load(resultSelectCandidatesInner, loadSelectTagsInner);
  assign resultSelectWinnerInner = chooseResponseResultInner ?
    '{valid:1'b1, tag:previewResultTagInner, index:previewResultIndexInner} :
    bufferedResultWinnerInner;
  assign resultSelectFoundInner = resultSelectWinnerInner.valid;
  assign resultSelectIndexInner = resultSelectWinnerInner.index;
  assign resultSelectTagInner = resultSelectWinnerInner.tag;

  // Normal address results name an existing reserved row. The standalone LSU
  // interface also permits a matching same-cycle allocation/address pair;
  // preserve that priority without authenticating an old result as a new row.
  generate if (RENAME_WIDTH != 4) begin : g_legacy_address_match
  assign loadAddressMatchInner =
    (lqValidInner[addressIndexInput] && lqTagInner[addressIndexInput] == addressInput.robTag) ||
    (loadAllocationInput.valid && loadAllocReadyOutput &&
     addressIndexInput == $bits(addressIndexInput)'(loadAllocIndexOutput) &&
      loadAllocationInput.robTag == addressInput.robTag) ||
    (loadAllocSecondFireInner && addressIndexInput == $bits(addressIndexInput)'(loadAllocSecondIndexOutput) &&
      loadAllocationSecondInput.robTag == addressInput.robTag);
  assign storeAddressMatchInner =
    (sqValidInner[addressIndexInput] && !sqCommittedInner[addressIndexInput] &&
     sqTagInner[addressIndexInput] == addressInput.robTag) ||
    (storeAllocationInput.valid && storeAllocReadyOutput &&
     addressIndexInput == $bits(addressIndexInput)'(storeAllocIndexOutput) &&
       storeAllocationInput.robTag == addressInput.robTag) ||
     (storeAllocSecondFireInner && addressIndexInput == $bits(addressIndexInput)'(storeAllocSecondIndexOutput) &&
       storeAllocationSecondInput.robTag == addressInput.robTag);
  end else begin : g_four_address_match
    always_comb begin
      loadAddressMatchInner=lqValidInner[addressIndexInput] && lqTagInner[addressIndexInput]==addressInput.robTag;
      storeAddressMatchInner=sqValidInner[addressIndexInput] && !sqCommittedInner[addressIndexInput] &&
        sqTagInner[addressIndexInput]==addressInput.robTag;
      for (int lane=0;lane<4;lane++) begin
        loadAddressMatchInner|=loadAllocationLanesFireOutput[lane] &&
          addressIndexInput==$bits(addressIndexInput)'(loadLanesIndexInner[lane]) &&
          loadAllocationLanesInput[lane].robTag==addressInput.robTag;
        storeAddressMatchInner|=storeAllocationLanesFireOutput[lane] &&
          addressIndexInput==$bits(addressIndexInput)'(storeLanesIndexInner[lane]) &&
          storeAllocationLanesInput[lane].robTag==addressInput.robTag;
      end
    end
  end endgenerate

  assign sqHeadIndexInner = sqHeadSeqInner[SQ_INDEX_W-1:0];
  for (genvar lane = 0; lane < COMMIT_WIDTH; lane++) begin : g_store_commit
    assign storeCommitMatchInner[lane] = storeCommitInput[lane].valid &&
      sqValidInner[storeCommitIndexInput[lane]] && !sqCommittedInner[storeCommitIndexInput[lane]] &&
      sqTagInner[storeCommitIndexInput[lane]] == storeCommitInput[lane].robTag &&
      sqAddressReadyInner[storeCommitIndexInput[lane]] && sqDataReadyInner[storeCommitIndexInput[lane]] &&
      (!flushInfoInput.valid || rob_is_older(storeCommitInput[lane].robTag, flushInfoInput.robTag));
    assign storeCommitReadyOutput[lane] = storeCommitMatchInner[lane];
    assign storeRetireFireInner[lane] = storeCommitMatchInner[lane] && robRetireInput[lane].valid &&
      robRetireInput[lane].robTag == storeCommitInput[lane].robTag;
    always_comb begin
      storeRetirementOutput[lane] = '0;
      storeRetirementOutput[lane].valid = storeCommitMatchInner[lane];
      storeRetirementOutput[lane].write = 1'b1;
      storeRetirementOutput[lane].address = sqAddressInner[storeCommitIndexInput[lane]];
      storeRetirementOutput[lane].writeData = sqDataInner[storeCommitIndexInput[lane]];
      storeRetirementOutput[lane].size = mem_size_e'(sqSizeInner[storeCommitIndexInput[lane]]);
      unique case (sqSizeInner[storeCommitIndexInput[lane]])
        MEM_BYTE: storeRetirementOutput[lane].writeStrobe = 4'b0001;
        MEM_HALF: storeRetirementOutput[lane].writeStrobe = 4'b0011;
        default: storeRetirementOutput[lane].writeStrobe = 4'b1111;
      endcase
    end
  end

  // Age offset per SQ row, one subtraction each per cycle. Forward queries and
  // the notify fan-out compare these directly instead of re-deriving the offset
  // at every call site.
  logic [SQ_INDEX_W-1:0] sqOrderInner [SQ_DEPTH];
  for (genvar orderRow = 0; orderRow < SQ_DEPTH; orderRow++) begin : g_sq_order
    assign sqOrderInner[orderRow] = SQ_INDEX_W'(orderRow) - sqHeadIndexInner;
  end

  function automatic logic [31:0] extend_load(
    input logic [31:0] valueInput,
    input mem_size_e sizeInput,
    input logic isUnsignedInput
  );
    begin
      unique case (sizeInput)
        MEM_BYTE: extend_load = isUnsignedInput ? {24'b0, valueInput[7:0]} :
                                             {{24{valueInput[7]}}, valueInput[7:0]};
        MEM_HALF: extend_load = isUnsignedInput ? {16'b0, valueInput[15:0]} :
                                             {{16{valueInput[15]}}, valueInput[15:0]};
        default:  extend_load = valueInput;
      endcase
    end
  endfunction

  // Compare adjacent words without first forming a 30-bit SQ +/-1.
  // Exactly one 5-bit chunk is the non-wrapping pivot. Lower chunks must
  // wrap, and upper chunks must be equal. Every predicate reads the original
  // addresses; there is no carry dependency between chunks or new state.
  function automatic logic [1:0] word_neighbors(
    input logic [29:0] loadWordInput,
    input logic [29:0] storeWordInput
  );
    logic [5:0] sameChunk, upChunk, downChunk, upWrap, downWrap;
    logic [5:0] nextTerms, prevTerms;
    for (int chunk = 0; chunk < 6; chunk++) begin
      sameChunk[chunk] = loadWordInput[5*chunk+:5] == storeWordInput[5*chunk+:5];
      upChunk[chunk] = storeWordInput[5*chunk+:5] != 5'd31 &&
        loadWordInput[5*chunk+:5] == storeWordInput[5*chunk+:5] + 5'd1;
      downChunk[chunk] = storeWordInput[5*chunk+:5] != 5'd0 &&
        loadWordInput[5*chunk+:5] == storeWordInput[5*chunk+:5] - 5'd1;
      upWrap[chunk] = storeWordInput[5*chunk+:5] == 5'd31 &&
        loadWordInput[5*chunk+:5] == 5'd0;
      downWrap[chunk] = storeWordInput[5*chunk+:5] == 5'd0 &&
        loadWordInput[5*chunk+:5] == 5'd31;
    end
    for (int chunk = 0; chunk < 6; chunk++) begin
      nextTerms[chunk] = upChunk[chunk] &&
        (&(sameChunk | 6'((2 << chunk)-1))) &&
        (&(upWrap | ~6'((1 << chunk)-1)));
      prevTerms[chunk] = downChunk[chunk] &&
        (&(sameChunk | 6'((2 << chunk)-1))) &&
        (&(downWrap | ~6'((1 << chunk)-1)));
    end
    return {|prevTerms, |nextTerms};
  endfunction

  // Original byte intervals and unsigned no-wrap boundary contract remain.
  function automatic logic byte_overlap(
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput,
    input logic [31:0] storeAddressInput,
    input mem_size_e storeSizeInput
  );
    logic [2:0] loadOffset, storeOffset, loadSpan, storeSpan, loadEnd, storeEnd;
    logic [1:0] neighbors;
    loadOffset = {1'b0, loadAddressInput[1:0]};
    storeOffset = {1'b0, storeAddressInput[1:0]};
    loadSpan = mem_bytes(loadSizeInput);
    storeSpan = mem_bytes(storeSizeInput);
    loadEnd = loadOffset + loadSpan;
    storeEnd = storeOffset + storeSpan;
    neighbors = word_neighbors(loadAddressInput[31:2], storeAddressInput[31:2]);
    return (loadAddressInput[31:2] == storeAddressInput[31:2] &&
            loadOffset < storeEnd && storeOffset < loadEnd) ||
      (neighbors[0] && loadOffset + 3'(4) < storeEnd) ||
      (neighbors[1] && storeOffset + 3'(4) < loadEnd);
  endfunction

  function automatic logic yield_ram_access(
    input logic [31:0] address, input mem_size_e size
  );
    logic [32:0] last;
    last={1'b0,address}+33'(mem_bytes(size))-33'(1);
    return (size==MEM_BYTE || size==MEM_HALF || size==MEM_WORD) &&
      address<32'h10000000 && last<33'h010000000 &&
      address[31:$clog2(DCACHE_LINE_BYTES)]==last[31:$clog2(DCACHE_LINE_BYTES)];
  endfunction

  // Forward notifications are for OLD reserved rows only, never allocation
  // intents. Keep their authentication independent of allocReady/issueFire.
  assign storeAddressEventInner = addressInput.valid && addressInput.isStore &&
    sqValidInner[addressIndexInput] && !sqCommittedInner[addressIndexInput] &&
    sqTagInner[addressIndexInput] == addressInput.robTag &&
    (!flushInfoInput.valid || rob_is_older(addressInput.robTag, flushInfoInput.robTag));
  assign loadAddressEventInner = addressInput.valid && !addressInput.isStore &&
    lqValidInner[addressIndexInput] && lqTagInner[addressIndexInput] == addressInput.robTag &&
    (!flushInfoInput.valid || rob_is_older(addressInput.robTag, flushInfoInput.robTag));
  for (genvar lane = 0; lane < STORE_DATA_LANES; lane = lane + 1) begin : g_store_event
    assign storeDataEventInner[lane] = storeDataInput[lane].valid &&
      sqValidInner[storeDataIndexInput[lane]] && !sqCommittedInner[storeDataIndexInput[lane]] &&
      sqTagInner[storeDataIndexInput[lane]] == storeDataInput[lane].robTag &&
      (!flushInfoInput.valid || rob_is_older(storeDataInput[lane].robTag, flushInfoInput.robTag));
  end

  // Policy (A): choose the youngest overlapping Store, then require that ONE
  // source to cover the whole Load. No byte stitching or partial-memory merge.
  // Query only the old SQ state; same-edge Store events cannot bypass it.
  function automatic store_forward_result_t query_store_forward(
    input rob_tag_t loadTagInput,
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput
  );
    store_forward_result_t result;
    logic found, addressReady, dataReady, unknownFound;
    logic [SQ_INDEX_W-1:0] youngestIndex;
    logic [SQ_INDEX_W-1:0] youngestUnknownIndex;
/* verilator lint_off UNUSEDSIGNAL */     logic [31:0] youngestAddress, youngestData; /* verilator lint_on UNUSEDSIGNAL */
    mem_size_e youngestSize;
    logic youngestReady;
    logic [31:0] address, data;
    logic [1:0] byteOffset;
    logic [2:0] coverEnd;
    begin
      result = '0;
      found = 1'b0; youngestIndex = '0; youngestAddress = '0;
      youngestData = '0; youngestSize = MEM_WORD; youngestReady = 1'b0;
      unknownFound = 1'b0; youngestUnknownIndex = '0;
      for (int s = 0; s < SQ_DEPTH; s = s + 1) begin
        if (sqValidInner[s] &&
            (sqCommittedInner[s] || rob_is_older(sqTagInner[s], loadTagInput))) begin
          addressReady = sqAddressReadyInner[s]; address = sqAddressInner[s];
          dataReady = sqDataReadyInner[s]; data = sqDataInner[s];
          if (!sqCommittedInner[s] &&
               (!sqAddressReadyInner[s] || byte_overlap(loadAddressInput, loadSizeInput,
                  sqAddressInner[s], sqSizeInner[s])))
            result.cacheBlocked = 1'b1;
          if (!addressReady) begin
            if (!unknownFound || sqOrderInner[s] > sqOrderInner[youngestUnknownIndex])
              youngestUnknownIndex = SQ_INDEX_W'(s);
            unknownFound = 1'b1;
          end else if (byte_overlap(loadAddressInput, loadSizeInput, address, sqSizeInner[s]) &&
              (!found || sqOrderInner[s] > sqOrderInner[youngestIndex])) begin
            found = 1'b1; youngestIndex = SQ_INDEX_W'(s);
            youngestAddress = address; youngestData = data;
            youngestSize = sqSizeInner[s]; youngestReady = dataReady;
          end
        end
      end
      // A younger full-cover source dominates older unknown addresses. Any
      // unknown source AFTER it still blocks forwarding. Cache admission above
      // remains conservative; this relaxation applies only to SQ-sourced data.
      result.blocked = unknownFound &&
        (!found || sqOrderInner[youngestUnknownIndex] >= sqOrderInner[youngestIndex]);
      // The winner already byte-overlaps this 1/2/4-byte Load. A forward
      // offset is 0..3; for a source starting AFTER the Load, overlap makes
      // the modulo-4 offset plus Load span exceed 4, so coverage rejects it.
      // Keep the sum at 3 bits (maximum 3+4=7), not a wrapping 2-bit value.
      byteOffset = loadAddressInput[1:0] - youngestAddress[1:0];
      coverEnd = {1'b0, byteOffset} + mem_bytes(loadSizeInput);
      if (found && youngestReady && coverEnd <= mem_bytes(youngestSize)) begin
        result.mask = loadSizeInput == MEM_BYTE ? 4'b0001 :
                     loadSizeInput == MEM_HALF ? 4'b0011 : 4'b1111;
        result.data = youngestData >> {byteOffset, 3'b000};
      end
      return result;
    end
  endfunction

  // Only the cache-admission bit of query_store_forward. Committed Stores
  // do not set it; unknown/overlapping older uncommitted Stores do.
  function automatic logic query_request_cache_block(
    input rob_tag_t loadTagInput,
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput
  );
    logic blocked;
    blocked=1'b0;
    for(int s=0;s<SQ_DEPTH;s++)
      if(sqValidInner[s] && !sqCommittedInner[s] &&
         rob_is_older(sqTagInner[s],loadTagInput) &&
         (!sqAddressReadyInner[s] ||
          byte_overlap(loadAddressInput,loadSizeInput,sqAddressInner[s],sqSizeInner[s])))
        blocked=1'b1;
    return blocked;
  endfunction

  // Match software StoreNotify qualification, including the younger same-word
  // or unknown-address guards. This event contract is distinct from the (A)
  // Load-address query: notifications match the same START and WIDTH only.
  function automatic logic notify_matches(
    input logic [SQ_INDEX_W-1:0] sourceInput,
    input logic [31:0] sourceAddressInput,
    input rob_tag_t loadTagInput,
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput
  );
    logic matched;
    begin
      matched = sourceAddressInput == loadAddressInput &&
        sqSizeInner[sourceInput] == loadSizeInput &&
        rob_is_older(sqTagInner[sourceInput], loadTagInput);
      for (int s = 0; s < SQ_DEPTH; s = s + 1) begin
        if (sqValidInner[s] && sqOrderInner[s] > sqOrderInner[sourceInput] &&
            rob_is_older(sqTagInner[s], loadTagInput) &&
            (!sqAddressReadyInner[s] || sqAddressInner[s][31:2] == sourceAddressInput[31:2]))
          matched = 1'b0;
      end
      return matched;
    end
  endfunction

  // Timing-only reformulation of the query's one-bit forwarding decision.
  // The youngest RELEVANT Store (unknown-address or byte-overlapping) must
  // itself be a known, ready, full-cover source. Pairwise younger predicates
  // depend only on old SQ order; no late-address serial winner/index mux.
  function automatic logic query_store_forward_valid(
    input rob_tag_t loadTagInput,
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput
  );
    logic [SQ_DEPTH-1:0] relevant, covering, winners, younger;
    logic eligible, overlaps;
    logic [1:0] byteOffset;
    logic [2:0] coverEnd;
    begin
      relevant = '0; covering = '0; winners = '0; younger = '0;
      eligible = 1'b0; overlaps = 1'b0; byteOffset = '0; coverEnd = '0;
      for (int s = 0; s < SQ_DEPTH; s++) begin
        eligible = sqValidInner[s] &&
          (sqCommittedInner[s] || rob_is_older(sqTagInner[s], loadTagInput));
        overlaps = byte_overlap(loadAddressInput, loadSizeInput,
          sqAddressInner[s], sqSizeInner[s]);
        relevant[s] = eligible && (!sqAddressReadyInner[s] || overlaps);
        byteOffset = loadAddressInput[1:0] - sqAddressInner[s][1:0];
        coverEnd = {1'b0, byteOffset} + mem_bytes(loadSizeInput);
        covering[s] = eligible && sqAddressReadyInner[s] && overlaps &&
          sqDataReadyInner[s] && coverEnd <= mem_bytes(sqSizeInner[s]);
      end
      for (int s = 0; s < SQ_DEPTH; s++) begin
        younger = '0;
        for (int t = 0; t < SQ_DEPTH; t++)
          younger[t] = relevant[t] && sqOrderInner[t] > sqOrderInner[s];
        winners[s] = covering[s] && !(|younger);
      end
      return |winners;
    end
  endfunction

  // OLD row pairs qualify independently of either late response/SV index.
  // No valid-row assumptions: preserve the original priority bit even when
  // the returning row is inactive. Event authentication remains separate.
  wire [SQ_DEPTH-1:0] oldNotifyMatchInner [LQ_DEPTH];
  for(genvar notifyLoad=0;notifyLoad<LQ_DEPTH;notifyLoad++)begin : g_notify_load
    for(genvar notifyStore=0;notifyStore<SQ_DEPTH;notifyStore++)begin : g_notify_store
      assign oldNotifyMatchInner[notifyLoad][notifyStore]=
        lqAddressReadyInner[notifyLoad] && sqAddressReadyInner[notifyStore] &&
        notify_matches(SQ_INDEX_W'(notifyStore), sqAddressInner[notifyStore],
          lqTagInner[notifyLoad], lqAddressInner[notifyLoad], lqSizeInner[notifyLoad]);
    end
  end
  logic [LQ_INDEX_W-1:0] previewResultIndexInner;
  rob_tag_t previewResultTagInner;
  phy_tag_t previewResultDestinationInner;
  mem_size_e previewResultSizeInner;
  logic previewResultUnsignedInner;
  load_result_output_t previewCdbPacketInner;
  logic directStorePacketInner;
  generate if(RESPONSE_PREVIEW && TAGGED_DMEM)begin : g_response_preview
    // Prepare each transport owner's narrow candidate before the late return
    // mux (including fill and word returns, which use owners[0]). A candidate
    // never authorizes a result: select the real route and require response.valid.
    typedef struct packed {
      logic [LQ_INDEX_W-1:0] index;
      rob_tag_t tag;
      phy_tag_t destination;
      mem_size_e size;
      logic isUnsigned, identity, addressForward, storeValue, winner;
    } owner_candidate_t;
    wire [LQ_DEPTH-1:0] rowLive, rowBeatsBuffered, rowAddressForward, rowStoreValue;
    wire owner_candidate_t ownerCandidate [DATA_REQUEST_ENTRIES];
    owner_candidate_t selectedCandidate [3];
    wire [2:0] identityRows,forwardRows,winnerRows,selectedRows;
    wire [2:0] storeValueRows, addressForwardRows;
    data_transaction_t [2:0] owners;
    wire [LQ_INDEX_W-1:0] indices[3];
    logic bufferedWritebackValid;
    assign bufferedWritebackValid=bufferedResultWinnerInner.valid &&
      (!flushInfoInput.valid || rob_is_older(bufferedResultWinnerInner.tag,flushInfoInput.robTag));
    assign owners[0]=responseOwnerInner;
    assign owners[1]=responsePreviewTransactionInput[0];
    assign owners[2]=responsePreviewTransactionInput[1];
    assign selectedRows={responsePreviewSelectInput,!(|responsePreviewSelectInput)};
    for (genvar row=0;row<LQ_DEPTH;row++) begin : g_row_candidate
      wire [STORE_DATA_LANES-1:0] notifications;
      wire addressOverride=loadAddressEventInner && addressIndexInput==$bits(addressIndexInput)'(row);
      for (genvar lane=0;lane<STORE_DATA_LANES;lane++) begin : g_notify
        assign notifications[lane]=storeDataEventInner[lane] &&
          oldNotifyMatchInner[row][storeDataIndexInput[lane]];
      end
      assign rowAddressForward[row]=addressOverride && addressedForwardValidInner;
      assign rowStoreValue[row]=!addressOverride && (|notifications);
      assign rowLive[row]=lqValidInner[row] && lqSentInner[row] &&
        !lqResultReadyInner[row] && !lqBroadcastedInner[row] &&
        (!flushInfoInput.valid || rob_is_older(lqTagInner[row],flushInfoInput.robTag));
      wire smallerOnTie;
      // The maximum encoded row is never below an unsigned buffered index.
      // Other rows, including non-power-of-two configurations, compare the
      // full index exactly as before.
      if (LQ_INDEX_W'(row)=={LQ_INDEX_W{1'b1}}) begin : g_max_index
        assign smallerOnTie=1'b0;
      end else begin : g_compare_indices
        assign smallerOnTie=LQ_INDEX_W'(row)<bufferedResultWinnerInner.index;
      end
      assign rowBeatsBuffered[row]=!bufferedResultWinnerInner.valid ||
        rob_is_older(lqTagInner[row],bufferedResultWinnerInner.tag) ||
        (lqTagInner[row]==bufferedResultWinnerInner.tag && smallerOnTie);
    end
    for (genvar owner=0;owner<DATA_REQUEST_ENTRIES;owner++) begin : g_owner_candidate
      wire [LQ_INDEX_W-1:0] index=fifoIndexInner[owner];
      // The FIFO and LQ full tags must match before using the LQ's flush check.
      wire identity=fifoValidInner[owner] && !fifoDropInner[owner] &&
        rowLive[index] && lqTagInner[index]==fifoTagInner[owner];
      assign ownerCandidate[owner]='{index:index, tag:lqTagInner[index], destination:lqDestInner[index],
        size:mem_size_e'(lqSizeInner[index]), isUnsigned:lqUnsignedInner[index], identity:identity,
        addressForward:rowAddressForward[index], storeValue:rowStoreValue[index],
        winner:identity && !rowAddressForward[index] && rowBeatsBuffered[index]};
    end
    for (genvar option=0;option<3;option++) begin : g_option
      always_comb begin : select_candidate
        selectedCandidate[option]='0;
        for (int owner=0;owner<DATA_REQUEST_ENTRIES;owner++)
          selectedCandidate[option]|=ownerCandidate[owner] &
            {$bits(owner_candidate_t){owners[option]==data_transaction_t'(owner)}};
      end
      assign indices[option]=selectedCandidate[option].index;
      assign identityRows[option]=selectedCandidate[option].identity;
      assign addressForwardRows[option]=selectedCandidate[option].addressForward;
      assign storeValueRows[option]=selectedCandidate[option].storeValue;
      assign forwardRows[option]=addressForwardRows[option] || storeValueRows[option];
      assign winnerRows[option]=selectedCandidate[option].winner;
    end
    assign responseResultIdentityLiveInner=dmemResponseInput.valid && (|(identityRows & selectedRows));
    assign responseForwardPriorityInner=|(forwardRows & selectedRows);
    assign responseResultLiveInner=responseResultIdentityLiveInner && !(|(addressForwardRows & selectedRows));
    assign chooseResponseResultInner=dmemResponseInput.valid && (|(winnerRows & selectedRows));
    assign directStorePacketInner=chooseResponseResultInner && (|(storeValueRows & selectedRows));
    always_comb begin : preview_metadata
      previewResultIndexInner='0;previewResultTagInner='0;previewResultDestinationInner='0;
      previewResultSizeInner=mem_size_e'(0);previewResultUnsignedInner=1'b0;
      for(int option=0;option<3;option++)begin
        previewResultIndexInner|=indices[option] & {LQ_INDEX_W{selectedRows[option]}};
        previewResultTagInner|=selectedCandidate[option].tag & {ROB_TAG_W{selectedRows[option]}};
        previewResultDestinationInner|=selectedCandidate[option].destination & {PHY_TAG_W{selectedRows[option]}};
        previewResultSizeInner=mem_size_e'(previewResultSizeInner |
          (selectedCandidate[option].size & {$bits(mem_size_e){selectedRows[option]}}));
        previewResultUnsignedInner|=selectedCandidate[option].isUnsigned && selectedRows[option];
      end
    end
    // Each option forms its complete original response-vs-buffered CDB
    // packet BEFORE the late response-route selection. No speculative event.
    always_comb begin : preview_cdb_packet_cofactors
      load_result_output_t packet;
      logic useResponse;
      previewCdbPacketInner='0;packet='0;useResponse=1'b0;
      for(int option=0;option<3;option++)begin
        useResponse=dmemResponseInput.valid && winnerRows[option];
        packet.robTag=useResponse ? selectedCandidate[option].tag : bufferedResultWinnerInner.tag;
        packet.destinationPhy=useResponse ? selectedCandidate[option].destination : lqDestInner[bufferedResultWinnerInner.index];
        packet.value=useResponse ?
          extend_load(storeValueRows[option] ? lqEarlyValueInner[indices[option]] : dmemResponseInput.readData,
            selectedCandidate[option].size,selectedCandidate[option].isUnsigned) :
          extend_load(lqResultInner[bufferedResultWinnerInner.index],lqSizeInner[bufferedResultWinnerInner.index],
            lqUnsignedInner[bufferedResultWinnerInner.index]);
        // A selected response already passed flush with this exact tag.
        // Check the buffered tag before the source mux instead of after it.
        packet.valid=useResponse || bufferedWritebackValid;
        previewCdbPacketInner|=packet & {$bits(load_result_output_t){selectedRows[option]}};
      end
    end
`ifndef SYNTHESIS
    // Independent post-route oracle for the real response, including canceled
    // owners, same-edge forwarding, the age tie and an invalid writeback.
    always @(posedge clkInput) if (rstNInput) begin : selected_owner_oracle
      logic live, advance, addressOverride, addressForward, storeValue;
      logic [LQ_INDEX_W-1:0] index;
      load_result_output_t packet;
      rob_tag_t tag;
      index=fifoIndexInner[responseOwnerInner];
      tag=lqTagInner[index];
      live=dmemResponseInput.valid && fifoValidInner[responseOwnerInner] && !fifoDropInner[responseOwnerInner] &&
        lqValidInner[index] && tag==fifoTagInner[responseOwnerInner] && lqSentInner[index] &&
        !lqResultReadyInner[index] && !lqBroadcastedInner[index] &&
        (!flushInfoInput.valid || rob_is_older(fifoTagInner[responseOwnerInner],flushInfoInput.robTag));
      addressOverride=loadAddressEventInner && addressIndexInput==$bits(addressIndexInput)'(index);
      addressForward=addressOverride && addressedForwardValidInner;
      storeValue=1'b0;
      for (int lane=0;lane<STORE_DATA_LANES;lane++)
        if (!addressOverride && storeDataEventInner[lane] &&
            oldNotifyMatchInner[index][storeDataIndexInput[lane]]) storeValue=1'b1;
      advance=live && !addressForward &&
        (!bufferedResultWinnerInner.valid || rob_is_older(tag,bufferedResultWinnerInner.tag) ||
         (tag==bufferedResultWinnerInner.tag && index<bufferedResultWinnerInner.index));
      packet.robTag=advance ? tag : bufferedResultWinnerInner.tag;
      packet.destinationPhy=advance ? lqDestInner[index] : lqDestInner[bufferedResultWinnerInner.index];
      packet.value=advance ? extend_load(storeValue ? lqEarlyValueInner[index] : dmemResponseInput.readData,
        lqSizeInner[index],lqUnsignedInner[index]) :
        extend_load(lqResultInner[bufferedResultWinnerInner.index],lqSizeInner[bufferedResultWinnerInner.index],
          lqUnsignedInner[bufferedResultWinnerInner.index]);
      packet.valid=(advance || bufferedResultWinnerInner.valid) &&
        (!flushInfoInput.valid || rob_is_older(packet.robTag,flushInfoInput.robTag));
      assert (packet==loadResultOutput && live==responseResultIdentityLiveInner &&
        (live && !addressForward)==responseResultLiveInner && advance==chooseResponseResultInner &&
        (advance && storeValue)==directStorePacketInner)
        else $fatal(1,"LSU actual-owner candidate differs from post-route oracle");
    end
    always_comb begin
      assert(!chooseResponseResultInner || responseResultLiveInner)
        else $fatal(1,"Response preview live qualification consistency");
      assert($onehot0(responsePreviewSelectInput))else $fatal(1,"Response preview grants not onehot0");
      if(dmemResponseInput.valid)begin
        assert((!responsePreviewSelectInput[0] || responsePreviewTransactionInput[0]==responseOwnerInner) &&
               (!responsePreviewSelectInput[1] || responsePreviewTransactionInput[1]==responseOwnerInner))
          else $fatal(1,"Response preview transaction contract");
      end
    end
`endif
  end else begin : g_original_response
  assign directStorePacketInner=1'b0;
  assign responseResultIdentityLiveInner = dmemResponseInput.valid && fifoValidInner[responseOwnerInner] &&
    !fifoDropInner[responseOwnerInner] && lqValidInner[responseResultIndexInner] &&
    lqTagInner[responseResultIndexInner] == fifoTagInner[responseOwnerInner] &&
    lqSentInner[responseResultIndexInner] && !lqResultReadyInner[responseResultIndexInner] &&
    !lqBroadcastedInner[responseResultIndexInner] &&
    (!flushInfoInput.valid || rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput.robTag));
  assign responseResultLiveInner = responseResultIdentityLiveInner && !responseForwardPriorityInner;
  always_comb begin : response_forward_priority
    logic [STORE_DATA_LANES-1:0] notifications;
    notifications='0;
    for(int lane=0;lane<STORE_DATA_LANES;lane++)begin
      notifications[lane]=storeDataEventInner[lane] &&
        oldNotifyMatchInner[responseResultIndexInner][storeDataIndexInput[lane]];
    end
    responseForwardPriorityInner=|notifications;
    if (loadAddressEventInner && addressIndexInput == $bits(addressIndexInput)'(responseResultIndexInner))
      responseForwardPriorityInner = addressedForwardValidInner;
  end  assign chooseResponseResultInner = responseResultLiveInner &&
    (!bufferedResultWinnerInner.valid ||
     rob_is_older(lqTagInner[responseResultIndexInner], bufferedResultWinnerInner.tag) ||
     (lqTagInner[responseResultIndexInner] == bufferedResultWinnerInner.tag &&
      responseResultIndexInner < bufferedResultWinnerInner.index));

    assign previewResultIndexInner=responseResultIndexInner;
    assign previewResultTagInner=lqTagInner[responseResultIndexInner];
    assign previewResultDestinationInner=lqDestInner[responseResultIndexInner];
    assign previewResultSizeInner=lqSizeInner[responseResultIndexInner];
    assign previewResultUnsignedInner=lqUnsignedInner[responseResultIndexInner];
    assign previewCdbPacketInner='0;
  end endgenerate


  // The address-event metadata is OLD AGU state, independent of the returning
  // Cache transaction. Under the equality above these are the same LQ row.
  // B request selection and C return qualification share this early 1-bit cone.
  // Every consumer is gated by loadAddressEventInner, which authenticates
  // the full old LQ tag against this registered AGU tag. Keep invalid query
  // differences internal; no validity, writer, packet or grant changes.
  assign addressedForwardValidInner = query_store_forward_valid(addressInput.robTag,
    addressInput.address, lqSizeInner[addressIndexInput]);

  // One query for the LQ row named by addressIndexInput. The per-row loop below
  // consumes it only on the matching iteration, so eight identical scans (they
  // differ solely in lqTag/lqSize) collapse into this single instance.
  always_comb
    addressedForwardInner = query_store_forward(
      lqTagInner[addressIndexInput], addressInput.address, lqSizeInner[addressIndexInput]);

  // Keep the exact original mask, including actual same-edge retirement.
  // Separate this producer from its consumers to preserve true acyclic deps.
  always_comb begin : prepare_posted_store_mask
    postedStoreMaskInner='0;
    for(int s=0;s<SQ_DEPTH;s++)
      postedStoreMaskInner[s]=sqValidInner[s] && sqCommittedInner[s];
    for(int lane=0;lane<COMMIT_WIDTH;lane++)
      if(storeRetireFireInner[lane]) postedStoreMaskInner[storeCommitIndexInput[lane]]=1'b1;
  end
  for(genvar scanStore=0;scanStore<SQ_DEPTH;scanStore++)begin : g_scan_store
    assign postedStoreUnsafeInner[scanStore]=!sqAddressReadyInner[scanStore] ||
      !sqDataReadyInner[scanStore] || !yield_ram_access(sqAddressInner[scanStore],sqSizeInner[scanStore]);
    assign incomingPostedBlockInner[scanStore]=postedStoreMaskInner[scanStore] &&
      (postedStoreUnsafeInner[scanStore] ||
       byte_overlap(addressInput.address,lqSizeInner[addressIndexInput],
                    sqAddressInner[scanStore],sqSizeInner[scanStore]));
  end
  for(genvar scanLoad=0;scanLoad<LQ_DEPTH;scanLoad++)begin : g_old_request_scan
    wire [SQ_DEPTH-1:0] postedBlocks;
    assign oldRequestCacheBlockedInner[scanLoad]=query_request_cache_block(
      lqTagInner[scanLoad],lqAddressInner[scanLoad],lqSizeInner[scanLoad]);
    assign oldRequestYieldsInner[scanLoad]=yield_ram_access(lqAddressInner[scanLoad],lqSizeInner[scanLoad]);
    for(genvar scanStore=0;scanStore<SQ_DEPTH;scanStore++)begin : g_store
      assign postedBlocks[scanStore]=postedStoreMaskInner[scanStore] &&
        (postedStoreUnsafeInner[scanStore] ||
         byte_overlap(lqAddressInner[scanLoad],lqSizeInner[scanLoad],
                      sqAddressInner[scanStore],sqSizeInner[scanStore]));
    end
    assign oldPostedStoreBlocksInner[scanLoad]=|postedBlocks;
  end
  assign incomingRequestYieldsInner=yield_ram_access(addressInput.address,lqSizeInner[addressIndexInput]);
  assign selectedRequestYieldsInner=loadRequestUsesAddressInner ?
    incomingRequestYieldsInner : oldRequestYieldsInner[loadSelectIndexInner];

`ifndef SYNTHESIS
  // Original post-mux equations remain the independent runtime oracle.
  always @(posedge clkInput)if(rstNInput)begin : moved_SQ_scan_oracle
    logic originalPostedBlock;
    originalPostedBlock=1'b0;
    for(int s=0;s<SQ_DEPTH;s++)
      if(postedStoreMaskInner[s] &&
         (!sqAddressReadyInner[s] || !sqDataReadyInner[s] ||
          !yield_ram_access(sqAddressInner[s],sqSizeInner[s]) ||
          byte_overlap(loadSelectAddressInner,lqSizeInner[loadSelectIndexInner],
                       sqAddressInner[s],sqSizeInner[s])))originalPostedBlock=1'b1;
    assert(loadBlockedInner==selectedForwardInner.cacheBlocked)
      else $fatal(1,"SQ moved cache-block exact original post-mux oracle");
    assert(postedStoreBlocksLoadInner==originalPostedBlock)
      else $fatal(1,"SQ moved posted-Store exact original post-mux oracle");
    assert(selectedRequestYieldsInner==yield_ram_access(loadSelectAddressInner,lqSizeInner[loadSelectIndexInner]))
      else $fatal(1,"SQ moved yield exact original post-mux oracle");
  end
`endif

  // Store-address arrival updates SQ only; it no longer notifies waiting
  // Loads. Load-address SQ queries and Store-data notifications remain. A Load
  // missing both events waits for the older Store to commit/send, then Cache.
  // All matching LQ rows may acquire registered results on this edge. CDB
  // selection above still reads only the old result registers, never intents.
  always_comb begin
    for (forwardIndexInner = 0; forwardIndexInner < LQ_DEPTH; forwardIndexInner = forwardIndexInner + 1) begin
/* verilator lint_off UNUSEDSIGNAL */       store_forward_result_t forwardResult; /* verilator lint_on UNUSEDSIGNAL */
      logic [3:0] needed;
      forwardResult = '0; needed = lqSizeInner[forwardIndexInner] == MEM_BYTE ? 4'b0001 :
        lqSizeInner[forwardIndexInner] == MEM_HALF ? 4'b0011 : 4'b1111;
      lqEarlyForwardInner[forwardIndexInner] = 1'b0;
      lqEarlyValueInner[forwardIndexInner] = '0;
      if (lqValidInner[forwardIndexInner] && !lqResultReadyInner[forwardIndexInner] &&
          !lqBroadcastedInner[forwardIndexInner] &&
          (!flushInfoInput.valid || rob_is_older(lqTagInner[forwardIndexInner], flushInfoInput.robTag))) begin
        if (lqAddressReadyInner[forwardIndexInner]) begin
          for (int lane = 0; lane < STORE_DATA_LANES; lane = lane + 1) begin
            if (storeDataEventInner[lane] && sqAddressReadyInner[storeDataIndexInput[lane]] &&
                notify_matches(storeDataIndexInput[lane], sqAddressInner[storeDataIndexInput[lane]],
                  lqTagInner[forwardIndexInner], lqAddressInner[forwardIndexInner], lqSizeInner[forwardIndexInner])) begin
              lqEarlyForwardInner[forwardIndexInner] = 1'b1;
              lqEarlyValueInner[forwardIndexInner] = storeDataInput[lane].value;
            end
          end
        end
        if (loadAddressEventInner && addressIndexInput == $bits(addressIndexInput)'(forwardIndexInner)) begin
          forwardResult = addressedForwardInner;
          lqEarlyForwardInner[forwardIndexInner] = !forwardResult.blocked && (forwardResult.mask & needed) == needed;
          lqEarlyValueInner[forwardIndexInner] = forwardResult.data;
        end
      end
    end
  end

  // No new storage or direct retirement bypass. These intents can only set
  // the ROB's registered ready bit; commit still consumes the OLD ready bit.
  wire [SQ_DEPTH-1:0] completionAddressReadyInner, completionDataReadyInner;
  for(genvar row=0;row<SQ_DEPTH;row++)begin : g_completion_events
    wire completionLive;
    wire [STORE_DATA_LANES-1:0] dataEvents;
    assign completionLive=!coreStoppedInput &&
      (!flushInfoInput.valid || rob_is_older(sqTagInner[row],flushInfoInput.robTag));
    for(genvar lane=0;lane<STORE_DATA_LANES;lane++)begin : g_lane
      assign dataEvents[lane]=storeDataEventInner[lane] && storeDataIndexInput[lane]==SQ_INDEX_W'(row);
    end
    assign completionAddressReadyInner[row]=sqAddressReadyInner[row] ||
      (completionLive && storeAddressEventInner && addressIndexInput==$bits(addressIndexInput)'(row));
    assign completionDataReadyInner[row]=sqDataReadyInner[row] ||
      (completionLive && ((|dataEvents) || (sqDataTagInner[row]!='0 && sqWbInner[row].valid)));
  end

  // These equations depend on completion events but no memory request does.
  // Keep their combinational cone separate: no WB -> request -> response loop.
  always_comb begin : completion_bitmap
    int completionRow;
    // Only OLD valid uncommitted SQ identities may publish completion. Use
    // actual authenticated events, never allocation intents or future state.
    storeCompleteOutput = '0;
    for (completionRow = 0; completionRow < SQ_DEPTH; completionRow = completionRow + 1) begin
      if (sqValidInner[completionRow] && completionAddressReadyInner[completionRow] &&
          completionDataReadyInner[completionRow] && !sqCommittedInner[completionRow]) begin
        storeCompleteOutput.readyMask |= ROB_ENTRIES'(1) << sqTagInner[completionRow][ROB_TAG_W-2:0];
        if (sqTagInner[completionRow][ROB_TAG_W-1])
          storeCompleteOutput.epochMask |= ROB_ENTRIES'(1) << sqTagInner[completionRow][ROB_TAG_W-2:0];
      end
    end

  end

/* verilator lint_off UNUSEDSIGNAL */   cdb_result_t storeAllocWbInner; /* verilator lint_on UNUSEDSIGNAL */
  cdb_result_t sqWbInner [SQ_DEPTH];
  function automatic cdb_result_t matching_writeback(input phy_tag_t tag);
    matching_writeback = '0;
    for (int portIndex = WRITEBACK_PORTS-1; portIndex >= 0; portIndex--)
      if (writebackInput[portIndex].valid && writebackInput[portIndex].phyTag == tag)
        matching_writeback = writebackInput[portIndex];
  endfunction
  assign storeAllocWbInner = matching_writeback(storeAllocationInput.dataTag);
  for (genvar row = 0; row < SQ_DEPTH; row++) begin : g_sq_wakeup
    assign sqWbInner[row] = matching_writeback(sqDataTagInner[row]);
  end

  always_comb begin
    storeAllocDataReadyResolvedInner = storeAllocationInput.dataReady;
    storeAllocDataValueResolvedInner = storeAllocationInput.dataValue;
    // P0 is not a producer identity. The core uses dataTag=0 while its
    // StoreValue RS owns delivery; an unrelated rd=x0 WB must not fill it.
    if (!storeAllocDataReadyResolvedInner && storeAllocationInput.dataTag != '0) begin
      if (storeAllocWbInner.valid) begin
        storeAllocDataReadyResolvedInner = 1'b1;
        storeAllocDataValueResolvedInner = storeAllocWbInner.value;
      end
    end
  end

  // Preview ranks are OLD free LQ rows / consecutive old SQ tail slots. They
  // never depend on this cycle's allocation valid/fire or retirement/reply.
  generate if (RENAME_WIDTH == 4) begin : g_four_allocation
    always_comb begin : preview_old_rows
      int rank;
      rank=0;
      loadPreviewIndexOutput='0;
      storePreviewIndexOutput='0;
      loadCreditsOutput='0;
      storeCreditsOutput='0;
      for (int row=0;row<LQ_DEPTH;row++) if (!lqValidInner[row]) begin
        if (rank<4) loadPreviewIndexOutput[rank]=LQ_INDEX_W'(row);
        rank++;
      end
      if (!coreStoppedInput && !flushInfoInput.valid) begin
        loadCreditsOutput=$bits(loadCreditsOutput)'(rank);
        storeCreditsOutput=$bits(storeCreditsOutput)'(SQ_DEPTH)-$bits(storeCreditsOutput)'(sqUsedInner);
      end
      for (int r=0;r<4;r++) storePreviewIndexOutput[r]=SQ_INDEX_W'(sqTailSeqInner)+SQ_INDEX_W'(r);
    end
    always_comb begin : consume_sparse_memory_ranks
      int loads,stores;
      loads=0;stores=0;
      loadAllocationLanesFireOutput='0;storeAllocationLanesFireOutput='0;
      loadLanesIndexInner='0;storeLanesIndexInner='0;
      for (int lane=0;lane<4;lane++) begin
        if (loadAllocationLanesInput[lane].valid && loads<int'(loadCreditsOutput)) begin
          loadAllocationLanesFireOutput[lane]=1;
          loadLanesIndexInner[lane]=loadPreviewIndexOutput[loads];
          loads++;
        end
        if (storeAllocationLanesInput[lane].valid && stores<int'(storeCreditsOutput)) begin
          storeAllocationLanesFireOutput[lane]=1;
          storeLanesIndexInner[lane]=storePreviewIndexOutput[stores];
          stores++;
        end
      end
      storeAllocLanesCountInner=(SQ_INDEX_W+1)'(stores);
    end
    for (genvar lane=0;lane<4;lane++) begin : g_data
/* verilator lint_off UNUSEDSIGNAL */       cdb_result_t wb; /* verilator lint_on UNUSEDSIGNAL */
      assign wb=matching_writeback(storeAllocationLanesInput[lane].dataTag);
      assign storeLanesDataReadyInner[lane]=storeAllocationLanesInput[lane].dataReady ||
        (storeAllocationLanesInput[lane].dataTag!=0 && wb.valid);
      assign storeLanesDataValueInner[lane]=!storeAllocationLanesInput[lane].dataReady &&
        storeAllocationLanesInput[lane].dataTag!=0 && wb.valid ? wb.value : storeAllocationLanesInput[lane].dataValue;
    end
  end else begin : g_no_four_allocation
    assign loadAllocationLanesFireOutput='0;assign storeAllocationLanesFireOutput='0;
    assign loadPreviewIndexOutput='0;assign storePreviewIndexOutput='0;
    assign loadCreditsOutput='0;assign storeCreditsOutput='0;
    assign loadLanesIndexInner='0;assign storeLanesIndexInner='0;
    assign storeAllocLanesCountInner='0;
    assign storeLanesDataReadyInner='0;assign storeLanesDataValueInner='0;
  end endgenerate

  generate if (RENAME_WIDTH == 2) begin : g_second_allocation
/* verilator lint_off UNUSEDSIGNAL */     cdb_result_t dataWb; /* verilator lint_on UNUSEDSIGNAL */
    assign dataWb = matching_writeback(storeAllocationSecondInput.dataTag);
    always_comb begin
      logic found;
      found = 1'b0;
      loadAllocSecondIndexOutput = '0;
      for (int row = 0; row < LQ_DEPTH; row++) begin
        if (!found && !lqValidInner[row] &&
            (!loadAllocFireInner || LQ_INDEX_W'(row) != loadAllocIndexOutput)) begin
          found = 1'b1;
          loadAllocSecondIndexOutput = LQ_INDEX_W'(row);
        end
      end
      loadAllocSecondReadyOutput = found && !flushInfoInput.valid;
    end
    assign storeAllocSecondReadyOutput = !flushInfoInput.valid &&
      int'(sqUsedInner) + int'(storeAllocFireInner) < SQ_DEPTH;
    assign storeAllocSecondIndexOutput = SQ_INDEX_W'(sqTailSeqInner) + SQ_INDEX_W'(storeAllocFireInner);
    assign storeAllocSecondDataReadyInner = storeAllocationSecondInput.dataReady ||
      (storeAllocationSecondInput.dataTag != '0 && dataWb.valid);
    assign storeAllocSecondDataValueInner = !storeAllocationSecondInput.dataReady &&
      storeAllocationSecondInput.dataTag != '0 && dataWb.valid ? dataWb.value : storeAllocationSecondInput.dataValue;
  end else begin : g_no_second_allocation
    assign loadAllocSecondReadyOutput = 1'b0;
    assign loadAllocSecondIndexOutput = '0;
    assign storeAllocSecondReadyOutput = 1'b0;
    assign storeAllocSecondIndexOutput = '0;
    assign storeAllocSecondDataReadyInner = 1'b0;
    assign storeAllocSecondDataValueInner = '0;
  end endgenerate

  generate if(RESPONSE_PREVIEW && TAGGED_DMEM)begin : g_preview_cdb_output
    assign loadResultOutput=previewCdbPacketInner;
`ifndef SYNTHESIS
    // Keep full invalid-payload semantics as well as valid CDB events.
    always_comb begin : packet_reference_assertion
      load_result_output_t originalPacket;
      originalPacket.valid=resultSelectFoundInner &&
        (!flushInfoInput.valid || rob_is_older(resultSelectTagInner,flushInfoInput.robTag));
      originalPacket.robTag=resultSelectTagInner;
      originalPacket.destinationPhy=chooseResponseResultInner ? previewResultDestinationInner : lqDestInner[bufferedResultWinnerInner.index];
      originalPacket.value=chooseResponseResultInner ?
        extend_load(lqEarlyForwardInner[responseResultIndexInner] ?
          lqEarlyValueInner[responseResultIndexInner] : dmemResponseInput.readData,
          previewResultSizeInner,previewResultUnsignedInner) :
        extend_load(lqResultInner[bufferedResultWinnerInner.index],lqSizeInner[bufferedResultWinnerInner.index],
          lqUnsignedInner[bufferedResultWinnerInner.index]);
      assert(loadResultOutput==originalPacket)else $fatal(1,"Response payload cofactor oracle");
    end
`endif
  end else begin : g_original_cdb_output
  always_comb begin : result_output
    loadResultOutput.valid = resultSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(resultSelectTagInner, flushInfoInput.robTag));
    loadResultOutput.robTag = resultSelectTagInner;
    loadResultOutput.destinationPhy = chooseResponseResultInner ? previewResultDestinationInner :
      lqDestInner[bufferedResultWinnerInner.index];
    loadResultOutput.value = chooseResponseResultInner ?
      extend_load(dmemResponseInput.readData, previewResultSizeInner, previewResultUnsignedInner) :
      extend_load(lqResultInner[bufferedResultWinnerInner.index], lqSizeInner[bufferedResultWinnerInner.index],
        lqUnsignedInner[bufferedResultWinnerInner.index]);
  end
  end endgenerate

  always_comb begin
    loadAllocFoundInner = 1'b0;
    loadAllocIndexOutput = '0;
    for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (!loadAllocFoundInner && !lqValidInner[combIndexInner]) begin
        loadAllocFoundInner = 1'b1;
        loadAllocIndexOutput = combIndexInner[LQ_INDEX_W-1:0];
      end
    end
    loadAllocReadyOutput = loadAllocFoundInner && !flushInfoInput.valid;

    storeAllocFoundInner = sqTailSeqInner != (sqHeadSeqInner ^ (SQ_INDEX_W+1)'(SQ_DEPTH));
    storeAllocIndexOutput = sqTailSeqInner[SQ_INDEX_W-1:0];
    storeAllocReadyOutput = storeAllocFoundInner && !flushInfoInput.valid;

    selectedForwardInner = '0;
    if (loadSelectFoundInner)
      selectedForwardInner = query_store_forward(loadSelectTagInner,
        loadSelectAddressInner, lqSizeInner[loadSelectIndexInner]);
    loadBlockedInner = loadSelectFoundInner && (loadRequestUsesAddressInner ?
      addressedForwardInner.cacheBlocked : oldRequestCacheBlockedInner[loadSelectIndexInner]);
    selectedLoadLiveInner = loadSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(loadSelectTagInner, flushInfoInput.robTag));
    // No new Load after the exit Store retires; committed SQ still progresses.
    loadNeedsMemoryInner = !coreStoppedInput && selectedLoadLiveInner && !loadBlockedInner &&
                          int'(fifoCountInner) < DATA_REQUEST_ENTRIES;

    storeAvailableInner = sqValidInner[sqHeadIndexInner] &&
      sqCommittedInner[sqHeadIndexInner];
    for (int lane = 0; lane < COMMIT_WIDTH; lane++)
      if (sqValidInner[sqHeadIndexInner] && storeRetireFireInner[lane] && storeCommitIndexInput[lane] == sqHeadIndexInner)
        storeAvailableInner = 1'b1;

    // Include ALL old posted Stores and actual same-edge retiring Stores.
    // Committed identities can outlive the ROB age window: do NOT age-filter them.
    postedStoreBlocksLoadInner=loadRequestUsesAddressInner ?
      (|incomingPostedBlockInner) : oldPostedStoreBlocksInner[loadSelectIndexInner];
    loadBypassStoreInner=loadYieldEnableInput && !coreStoppedInput && !flushInfoInput.valid &&
      storeAvailableInner && !storeYieldDebtInner && loadNeedsMemoryInner &&
      selectedRequestYieldsInner &&
      !postedStoreBlocksLoadInner && pressureLowInner;
    // This is the ACTUAL Store grant, also used by BOTH old SQ dequeue paths.
    storeSendSelectedInner=storeAvailableInner && !loadBypassStoreInner;

    dmemRequestOutput.valid = 1'b0;
    dmemRequestOutput.write = 1'b0;
    // Payload selection is independent of late Load permission. Valid
    // still authenticates Store priority, SQ hazards, flush and owner credits.
    dmemRequestOutput.address = storeSendSelectedInner ?
      sqAddressInner[sqHeadIndexInner] : loadSelectAddressInner;
    dmemRequestOutput.writeData = 32'b0;
    dmemRequestOutput.writeStrobe = 4'b0000;
    dmemRequestOutput.size = storeSendSelectedInner ?
      mem_size_e'(sqSizeInner[sqHeadIndexInner]) : mem_size_e'(lqSizeInner[loadSelectIndexInner]);
    loadRequestSelectedInner = 1'b0;
    if (storeSendSelectedInner) begin
      dmemRequestOutput.valid = 1'b1;
      dmemRequestOutput.write = 1'b1;
      dmemRequestOutput.writeData = sqDataInner[sqHeadIndexInner];
      unique case (sqSizeInner[sqHeadIndexInner])
        MEM_BYTE: dmemRequestOutput.writeStrobe = 4'b0001;
        MEM_HALF: dmemRequestOutput.writeStrobe = 4'b0011;
        default:  dmemRequestOutput.writeStrobe = 4'b1111;
      endcase
    end else if (loadNeedsMemoryInner) begin
      dmemRequestOutput.valid = 1'b1;
      dmemRequestOutput.write = 1'b0;
      loadRequestSelectedInner = 1'b1;
    end

    lqCountOutput = '0;
    for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1)
      if (lqValidInner[combIndexInner]) lqCountOutput = lqCountOutput + 1'b1;
    sqCountOutput = '0;
    sqRetainedCountInner = '0;
    for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (sqValidInner[combIndexInner]) sqCountOutput = sqCountOutput + 1'b1;
      if (sqValidInner[combIndexInner] &&
          (sqCommittedInner[combIndexInner] ||
           !rob_is_younger(sqTagInner[combIndexInner], flushInfoInput.robTag)))
        sqRetainedCountInner = sqRetainedCountInner + 1'b1;
    end
  end

  // Compute the summaries of the original NEXT state. All original LQ,
  // FIFO, SQ, identity, credit and forwarding writers below remain untouched.
  for(genvar summaryRow=0;summaryRow<LQ_DEPTH;summaryRow++)begin : g_scheduler_summary
    always_comb begin : next_tag
      summaryTagNextInner[summaryRow]=lqTagInner[summaryRow];
      if(!coreStoppedInput && !flushInfoInput.valid)begin
        if(RENAME_WIDTH!=4 && loadAllocationInput.valid && loadAllocReadyOutput &&
           loadAllocIndexOutput==LQ_INDEX_W'(summaryRow))
          summaryTagNextInner[summaryRow]=loadAllocationInput.robTag;
        if(loadAllocSecondFireInner && loadAllocSecondIndexOutput==LQ_INDEX_W'(summaryRow))
          summaryTagNextInner[summaryRow]=loadAllocationSecondInput.robTag;
        if(RENAME_WIDTH==4)for(int lane=0;lane<4;lane++)
          if(loadAllocationLanesFireOutput[lane] && loadLanesIndexInner[lane]==LQ_INDEX_W'(summaryRow))
            summaryTagNextInner[summaryRow]=loadAllocationLanesInput[lane].robTag;
      end
    end
    always_comb begin : next_flags
      logic v,a,s,r,allocated,doPop,doPush;
      v=lqValidInner[summaryRow];a=lqAddressReadyInner[summaryRow];
      s=lqSentInner[summaryRow];r=lqResultReadyInner[summaryRow];
      allocated=1'b0;
      doPop=dmemResponseInput.valid && fifoValidInner[responseOwnerInner];
      doPush=dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner &&
        (int'(fifoCountInner)<DATA_REQUEST_ENTRIES || doPop);
      if(!coreStoppedInput)begin
        if(flushInfoInput.valid)begin
          if(lqValidInner[summaryRow] && rob_is_younger(lqTagInner[summaryRow],flushInfoInput.robTag))
            v=1'b0;
        end else begin
          allocated=(RENAME_WIDTH!=4 && loadAllocationInput.valid && loadAllocReadyOutput &&
                     loadAllocIndexOutput==LQ_INDEX_W'(summaryRow)) ||
            (loadAllocSecondFireInner && loadAllocSecondIndexOutput==LQ_INDEX_W'(summaryRow));
          if(RENAME_WIDTH==4)for(int lane=0;lane<4;lane++)
            allocated|=loadAllocationLanesFireOutput[lane] &&
              loadLanesIndexInner[lane]==LQ_INDEX_W'(summaryRow);
          if(allocated)begin v=1'b1;a=1'b0;s=1'b0;r=1'b0;end
        end
        // Match against OLD identity, after allocation/flush in NBA priority.
        for(int lane=0;lane<COMMIT_WIDTH;lane++)
          if(robRetireInput[lane].valid && lqValidInner[summaryRow] &&
             lqTagInner[summaryRow]==robRetireInput[lane].robTag)v=1'b0;
        if(addressInput.valid && !addressInput.isStore && loadAddressMatchInner &&
           (!flushInfoInput.valid || rob_is_older(addressInput.robTag,flushInfoInput.robTag)) &&
           addressIndexInput==$bits(addressIndexInput)'(summaryRow))a=1'b1;
        // Full immutable-owner/drop/flush/generation/sent/result guard, OLD fields.
        if(doPop && !fifoDropInner[responseOwnerInner] &&
           !(flushInfoInput.valid && !rob_is_older(fifoTagInner[responseOwnerInner],flushInfoInput.robTag)) &&
           fifoIndexInner[responseOwnerInner]==LQ_INDEX_W'(summaryRow) &&
           lqValidInner[summaryRow] && lqTagInner[summaryRow]==fifoTagInner[responseOwnerInner] &&
           lqSentInner[summaryRow] && !lqResultReadyInner[summaryRow])r=1'b1;
        if(doPush && loadSelectIndexInner==LQ_INDEX_W'(summaryRow))s=1'b1;
        // The exclusion is the original accepted read, NOT the credit-qualified doPush.
        if(lqEarlyForwardInner[summaryRow] &&
           !(dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner &&
             loadSelectIndexInner==LQ_INDEX_W'(summaryRow)))begin r=1'b1;s=1'b1;end
      end
      loadRequestBaseNextInner[summaryRow]=v && a && !s && !r;
      loadInsertableNextInner[summaryRow]=v && !s && !r;
      loadPendingAddressNextInner[summaryRow]=v && !a;
    end
  end
  always_ff @(posedge clkInput or negedge rstNInput)begin
    if(!rstNInput)begin
      loadRequestBaseInner<='0;loadInsertableInner<='0;loadPendingAddressInner<='0;
    end else if(!coreStoppedInput)begin
      loadRequestBaseInner<=loadRequestBaseNextInner;
      loadInsertableInner<=loadInsertableNextInner;
      loadPendingAddressInner<=loadPendingAddressNextInner;
    end
  end
  for(genvar summaryRight=1;summaryRight<LQ_DEPTH;summaryRight++)begin : g_summary_age_right
    for(genvar summaryLeft=0;summaryLeft<summaryRight;summaryLeft++)begin : g_left
      logic pairOlderInner;
      assign loadPairOlderCachedInner[summaryRight][summaryLeft]=pairOlderInner;
      always_ff @(posedge clkInput or negedge rstNInput)begin
        if(!rstNInput)pairOlderInner<=1'b0;
        else if(!coreStoppedInput)
          pairOlderInner<=
            rob_is_older(summaryTagNextInner[summaryRight],summaryTagNextInner[summaryLeft]);
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput)if(rstNInput)begin : summary_original_state_oracle
    for(int row=0;row<LQ_DEPTH;row++)begin
      assert(loadRequestBaseInner[row]==(lqValidInner[row] && lqAddressReadyInner[row] &&
             !lqSentInner[row] && !lqResultReadyInner[row]))
        else $fatal(1,"LQ summary base does not describe current original state");
      assert(loadInsertableInner[row]==(lqValidInner[row] && !lqSentInner[row] && !lqResultReadyInner[row]))
        else $fatal(1,"LQ summary insertion does not describe current original state");
      assert(loadPendingAddressInner[row]==(lqValidInner[row] && !lqAddressReadyInner[row]))
        else $fatal(1,"LQ summary pending-address does not describe current original state");
      for(int left=0;left<row;left++)
        assert(loadPairOlderCachedInner[row][left]==rob_is_older(lqTagInner[row],lqTagInner[left]))
          else $fatal(1,"LQ summary pair age does not describe current original tags");
    end
  end
`endif
  // Debt survives flush/replay: a committed/actually-retiring Store survives too.
  // Ready or a proposal never consumes the one-Load allowance.
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if(!rstNInput) storeYieldDebtInner<=1'b0;
    else if(storeSendSelectedInner && dmemRequestOutput.valid && dmemReqReadyInput)
      storeYieldDebtInner<=1'b0;
    else if(loadBypassStoreInner && loadRequestSelectedInner && dmemRequestOutput.valid &&
            !dmemRequestOutput.write && dmemReqReadyInput)
      storeYieldDebtInner<=1'b1;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      fifoHeadInner <= '0; fifoTailInner <= '0; fifoCountInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < DATA_REQUEST_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        fifoValidInner[seqIndexInner] <= 1'b0;
        fifoIndexInner[seqIndexInner] <= '0;
        fifoTagInner[seqIndexInner] <= '0;
        fifoDropInner[seqIndexInner] <= 1'b0;
      end
      sqHeadSeqInner <= '0;
      sqTailSeqInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        lqValidInner[seqIndexInner] <= 1'b0;
        lqTagInner[seqIndexInner] <= '0;
        lqDestInner[seqIndexInner] <= '0;
        lqSizeInner[seqIndexInner] <= MEM_WORD;
        lqUnsignedInner[seqIndexInner] <= 1'b0;
        lqAddressReadyInner[seqIndexInner] <= 1'b0;
        lqSentInner[seqIndexInner] <= 1'b0;
        lqResultReadyInner[seqIndexInner] <= 1'b0;
        lqBroadcastedInner[seqIndexInner] <= 1'b0;
      end
      for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        sqValidInner[seqIndexInner] <= 1'b0;
        sqTagInner[seqIndexInner] <= '0;
        sqSizeInner[seqIndexInner] <= MEM_WORD;
        sqAddressReadyInner[seqIndexInner] <= 1'b0;
        sqAddressInner[seqIndexInner] <= '0;
        sqDataReadyInner[seqIndexInner] <= 1'b0;
        sqDataTagInner[seqIndexInner] <= '0;
        sqDataInner[seqIndexInner] <= '0;
        sqCommittedInner[seqIndexInner] <= 1'b0;
      end
    end else if (coreStoppedInput) begin
      // Software freezes LQ/core at retirement, but continues ticking SQ/cache.
      if (storeSendSelectedInner && dmemReqReadyInput) begin
        sqValidInner[sqHeadIndexInner] <= 1'b0;
        sqHeadSeqInner <= sqHeadSeqInner + 1'b1;
      end
    end else begin
      for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (sqValidInner[seqIndexInner] && !sqDataReadyInner[seqIndexInner] &&
            sqDataTagInner[seqIndexInner] != '0) begin
          if (sqWbInner[seqIndexInner].valid) begin
            sqDataReadyInner[seqIndexInner] <= 1'b1;
            sqDataInner[seqIndexInner] <= sqWbInner[seqIndexInner].value;
          end
        end
      end

      // Lane indices are SQ slots handed out by allocation, so distinct lanes
      // always target distinct entries and the per-lane writes cannot collide.
      for (storeLaneInner = 0; storeLaneInner < STORE_DATA_LANES; storeLaneInner = storeLaneInner + 1) begin
        if (storeDataEventInner[storeLaneInner]) begin
          sqDataInner[storeDataIndexInput[storeLaneInner]] <= storeDataInput[storeLaneInner].value;
          sqDataReadyInner[storeDataIndexInput[storeLaneInner]] <= 1'b1;
        end
      end

      if (flushInfoInput.valid) begin
        sqTailSeqInner <= sqHeadSeqInner + sqRetainedCountInner;
        for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
          if (lqValidInner[seqIndexInner] &&
              rob_is_younger(lqTagInner[seqIndexInner], flushInfoInput.robTag))
            lqValidInner[seqIndexInner] <= 1'b0;
        for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1)
          if (sqValidInner[seqIndexInner] &&
              !sqCommittedInner[seqIndexInner] &&
              rob_is_younger(sqTagInner[seqIndexInner], flushInfoInput.robTag))
            sqValidInner[seqIndexInner] <= 1'b0;
        // Persistent cancellation; never recycle an outstanding transport early.
        for (seqIndexInner = 0; seqIndexInner < DATA_REQUEST_ENTRIES; seqIndexInner = seqIndexInner + 1)
          if (fifoValidInner[seqIndexInner] &&
              !rob_is_older(fifoTagInner[seqIndexInner], flushInfoInput.robTag))
            fifoDropInner[seqIndexInner] <= 1'b1;

        if (loadResultOutput.valid && loadResultReadyInput)
          lqBroadcastedInner[resultSelectIndexInner] <= 1'b1;

      end else begin
        if (RENAME_WIDTH != 4 && loadAllocationInput.valid && loadAllocReadyOutput) begin
          lqValidInner[loadAllocIndexOutput] <= 1'b1;
          lqTagInner[loadAllocIndexOutput] <= loadAllocationInput.robTag;
          lqDestInner[loadAllocIndexOutput] <= loadAllocationInput.destinationPhy;
          lqSizeInner[loadAllocIndexOutput] <= loadAllocationInput.size;
          lqUnsignedInner[loadAllocIndexOutput] <= loadAllocationInput.isUnsigned;
          lqAddressReadyInner[loadAllocIndexOutput] <= 1'b0;
          lqSentInner[loadAllocIndexOutput] <= 1'b0;
          lqResultReadyInner[loadAllocIndexOutput] <= 1'b0;
          lqBroadcastedInner[loadAllocIndexOutput] <= 1'b0;
        end
        if (loadAllocSecondFireInner) begin
          lqValidInner[loadAllocSecondIndexOutput] <= 1'b1;
          lqTagInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput.robTag;
          lqDestInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput.destinationPhy;
          lqSizeInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput.size;
          lqUnsignedInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput.isUnsigned;
          lqAddressReadyInner[loadAllocSecondIndexOutput] <= 1'b0;
          lqSentInner[loadAllocSecondIndexOutput] <= 1'b0;
          lqResultReadyInner[loadAllocSecondIndexOutput] <= 1'b0;
          lqBroadcastedInner[loadAllocSecondIndexOutput] <= 1'b0;
        end
        if (storeAllocCountInner != 0)
          sqTailSeqInner <= sqTailSeqInner + storeAllocCountInner;
        if (RENAME_WIDTH != 4 && storeAllocationInput.valid && storeAllocReadyOutput) begin
          sqValidInner[storeAllocIndexOutput] <= 1'b1;
          sqTagInner[storeAllocIndexOutput] <= storeAllocationInput.robTag;
          sqSizeInner[storeAllocIndexOutput] <= storeAllocationInput.size;
          sqAddressReadyInner[storeAllocIndexOutput] <= 1'b0;
          sqDataReadyInner[storeAllocIndexOutput] <=
            storeAllocDataReadyResolvedInner;
          sqDataTagInner[storeAllocIndexOutput] <= storeAllocationInput.dataTag;
          sqDataInner[storeAllocIndexOutput] <= storeAllocDataValueResolvedInner;
          sqCommittedInner[storeAllocIndexOutput] <= 1'b0;
        end
        if (storeAllocSecondFireInner) begin
          sqValidInner[storeAllocSecondIndexOutput] <= 1'b1;
          sqTagInner[storeAllocSecondIndexOutput] <= storeAllocationSecondInput.robTag;
          sqSizeInner[storeAllocSecondIndexOutput] <= storeAllocationSecondInput.size;
          sqAddressReadyInner[storeAllocSecondIndexOutput] <= 1'b0;
          sqDataReadyInner[storeAllocSecondIndexOutput] <= storeAllocSecondDataReadyInner;
          sqDataTagInner[storeAllocSecondIndexOutput] <= storeAllocationSecondInput.dataTag;
          sqDataInner[storeAllocSecondIndexOutput] <= storeAllocSecondDataValueInner;
          sqCommittedInner[storeAllocSecondIndexOutput] <= 1'b0;
        end
        if (RENAME_WIDTH==4) begin
          for (int lane=0;lane<4;lane++) begin
            if (loadAllocationLanesFireOutput[lane]) begin
              lqValidInner[loadLanesIndexInner[lane]]<=1;
              lqTagInner[loadLanesIndexInner[lane]]<=loadAllocationLanesInput[lane].robTag;
              lqDestInner[loadLanesIndexInner[lane]]<=loadAllocationLanesInput[lane].destinationPhy;
              lqSizeInner[loadLanesIndexInner[lane]]<=loadAllocationLanesInput[lane].size;
              lqUnsignedInner[loadLanesIndexInner[lane]]<=loadAllocationLanesInput[lane].isUnsigned;
              lqAddressReadyInner[loadLanesIndexInner[lane]]<=0;
              lqSentInner[loadLanesIndexInner[lane]]<=0;
              lqResultReadyInner[loadLanesIndexInner[lane]]<=0;
              lqBroadcastedInner[loadLanesIndexInner[lane]]<=0;
            end
            if (storeAllocationLanesFireOutput[lane]) begin
              sqValidInner[storeLanesIndexInner[lane]]<=1;
              sqTagInner[storeLanesIndexInner[lane]]<=storeAllocationLanesInput[lane].robTag;
              sqSizeInner[storeLanesIndexInner[lane]]<=storeAllocationLanesInput[lane].size;
              sqAddressReadyInner[storeLanesIndexInner[lane]]<=0;
              sqDataReadyInner[storeLanesIndexInner[lane]]<=storeLanesDataReadyInner[lane];
              sqDataTagInner[storeLanesIndexInner[lane]]<=storeAllocationLanesInput[lane].dataTag;
              sqDataInner[storeLanesIndexInner[lane]]<=storeLanesDataValueInner[lane];
              sqCommittedInner[storeLanesIndexInner[lane]]<=0;
            end
          end
        end

        if (loadResultOutput.valid && loadResultReadyInput)
          lqBroadcastedInner[resultSelectIndexInner] <= 1'b1;

      end

      // Retirement posts a Store; only memory acceptance releases the head.
      // Both may happen on one edge, including an older retirement/flush edge.
      for (int lane = 0; lane < COMMIT_WIDTH; lane++)
        if (storeRetireFireInner[lane]) sqCommittedInner[storeCommitIndexInput[lane]] <= 1'b1;
      if (storeSendSelectedInner && dmemReqReadyInput) begin
        sqValidInner[sqHeadIndexInner] <= 1'b0;
        sqHeadSeqInner <= sqHeadSeqInner + 1'b1;
      end

      // Result consumption only records broadcast completion. The actual ROB
      // retirement event releases the reservation, including older retirement
      // concurrent with a recovery broadcast.
      for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
        if (robRetireInput[lane].valid) begin
          for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
            if (lqValidInner[seqIndexInner] && lqTagInner[seqIndexInner] == robRetireInput[lane].robTag)
              lqValidInner[seqIndexInner] <= 1'b0;
        end
      end

      // Address update follows allocation to retain the normal same-slot
      // priority; recovery admits only existing strictly older producers.
      if (addressInput.valid &&
          (addressInput.isStore ? storeAddressMatchInner : loadAddressMatchInner) &&
          (!flushInfoInput.valid || rob_is_older(addressInput.robTag, flushInfoInput.robTag))) begin
        if (addressInput.isStore) begin
          sqAddressInner[addressIndexInput] <= addressInput.address;
          sqAddressReadyInner[addressIndexInput] <= 1'b1;
        end else begin
          lqAddressReadyInner[addressIndexInput] <= 1'b1;
        end
      end

      // Response ID selects the immutable owner; completion and new acceptance
      // may coexist but allocation only sees OLD free slots.
      begin
        logic doPop, doPush;
        doPop = dmemResponseInput.valid && fifoValidInner[responseOwnerInner];
        doPush = dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner &&
          (int'(fifoCountInner) < DATA_REQUEST_ENTRIES || doPop);
        if (doPop) begin
          if (!fifoDropInner[responseOwnerInner] &&
               !(flushInfoInput.valid &&
                  !rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput.robTag)) &&
               lqValidInner[fifoIndexInner[responseOwnerInner]] &&
               lqTagInner[fifoIndexInner[responseOwnerInner]] == fifoTagInner[responseOwnerInner] &&
               lqSentInner[fifoIndexInner[responseOwnerInner]] &&
               !lqResultReadyInner[fifoIndexInner[responseOwnerInner]]) begin
             lqResultReadyInner[fifoIndexInner[responseOwnerInner]] <= 1'b1;
          end
          fifoValidInner[responseOwnerInner] <= 1'b0;
          if (!TAGGED_DMEM) fifoHeadInner <= fifoHeadInner + data_transaction_t'(1);
        end
        if (doPush) begin
          fifoIndexInner[allocationOwnerInner] <= loadSelectIndexInner;
          fifoTagInner[allocationOwnerInner] <= lqTagInner[loadSelectIndexInner];
          fifoDropInner[allocationOwnerInner] <= 1'b0;
          fifoValidInner[allocationOwnerInner] <= 1'b1;
          fifoTailInner <= allocationOwnerInner + data_transaction_t'(1);
          lqSentInner[loadSelectIndexInner] <= 1'b1;
        end
        if (doPop && !doPush) fifoCountInner <= fifoCountInner - 1'b1;
        else if (doPush && !doPop) fifoCountInner <= fifoCountInner + 1'b1;
      end

      // One final forwarding write point per row. Full forwarding wins over
      // a simultaneous accepted read's late response; pending still drains.
      for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (lqEarlyForwardInner[seqIndexInner] &&
            !(dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner &&
              loadSelectIndexInner == LQ_INDEX_W'(seqIndexInner))) begin
          lqResultReadyInner[seqIndexInner] <= 1'b1;
          lqSentInner[seqIndexInner] <= 1'b1;
          // Saved forwarding data retries after backpressure, but must not
          // re-enter the CDB after an accepted same-cycle bypass.
          lqBroadcastedInner[seqIndexInner] <= directStorePacketInner &&
            loadResultOutput.valid && loadResultReadyInput &&
            resultSelectIndexInner==LQ_INDEX_W'(seqIndexInner);
        end
      end
    end
  end
  // Result-ready/valid authenticate these data flops. Keep both write guards
  // and the original SQ-forward-over-response priority; invalid data is not reset.
  always_ff @(posedge clkInput) begin
    if (rstNInput && !coreStoppedInput) begin
      if (dmemResponseInput.valid && fifoValidInner[responseOwnerInner] &&
          !fifoDropInner[responseOwnerInner] &&
          !(flushInfoInput.valid && !rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput.robTag)) &&
          lqValidInner[fifoIndexInner[responseOwnerInner]] &&
          lqTagInner[fifoIndexInner[responseOwnerInner]] == fifoTagInner[responseOwnerInner] &&
          lqSentInner[fifoIndexInner[responseOwnerInner]] &&
          !lqResultReadyInner[fifoIndexInner[responseOwnerInner]])
        lqResultInner[fifoIndexInner[responseOwnerInner]] <= dmemResponseInput.readData;
      for (int row = 0; row < LQ_DEPTH; row++)
        if (lqEarlyForwardInner[row] &&
            !(dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner &&
              loadSelectIndexInner == LQ_INDEX_W'(row)))
          lqResultInner[row] <= lqEarlyValueInner[row];
    end
  end
  // OLD validity/address-ready qualify this payload. Preserve the existing
  // allocation+address identity and strictly-older recovery authentication.
  always_ff @(posedge clkInput) begin
    if (rstNInput && !coreStoppedInput && addressInput.valid && !addressInput.isStore &&
        loadAddressMatchInner &&
        (!flushInfoInput.valid || rob_is_older(addressInput.robTag, flushInfoInput.robTag)))
      lqAddressInner[addressIndexInput] <= addressInput.address;
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if(rstNInput) begin
    assert(!(storeSendSelectedInner && loadRequestSelectedInner))
      else $fatal(1,"single yield double memory grant");
    if(storeYieldDebtInner) begin
      assert(sqValidInner[sqHeadIndexInner] && sqCommittedInner[sqHeadIndexInner])
        else $fatal(1,"single yield lost posted Store debt owner");
      if(storeAvailableInner) assert(storeSendSelectedInner && !loadBypassStoreInner)
        else $fatal(1,"single yield Store starvation");
    end
    if(loadBypassStoreInner)
      assert(loadYieldEnableInput && !coreStoppedInput && !flushInfoInput.valid &&
        !storeYieldDebtInner && storeAvailableInner && !postedStoreBlocksLoadInner && pressureLowInner)
        else $fatal(1,"single yield unsafe permission");
  end
  always @(posedge clkInput) if (rstNInput) begin
    if (RENAME_WIDTH==4) begin
      assert ($countones(loadAllocationLanesFireOutput)<=int'(loadCreditsOutput) &&
              $countones(storeAllocationLanesFireOutput)<=int'(storeCreditsOutput))
        else $fatal(1,"LSQ four-lane credit exceeded");
      for (int lane=0;lane<4;lane++) for (int older=0;older<lane;older++) begin
        assert (!loadAllocationLanesFireOutput[lane] || !loadAllocationLanesFireOutput[older] ||
          loadLanesIndexInner[lane]!=loadLanesIndexInner[older]) else $fatal(1,"four Load allocations share a row");
        assert (!storeAllocationLanesFireOutput[lane] || !storeAllocationLanesFireOutput[older] ||
          storeLanesIndexInner[lane]!=storeLanesIndexInner[older]) else $fatal(1,"four Store allocations share a row");
      end
    end
    assert (!loadAllocFireInner || !loadAllocSecondFireInner || loadAllocIndexOutput != loadAllocSecondIndexOutput)
      else $fatal(1, "dual Load allocations share a row");
    assert (!storeAllocFireInner || !storeAllocSecondFireInner || storeAllocIndexOutput != storeAllocSecondIndexOutput)
      else $fatal(1, "dual Store allocations share a row");
    assert (int'(sqUsedInner) + int'(storeAllocCountInner) <= SQ_DEPTH)
      else $fatal(1, "Store allocation exceeds old SQ capacity");
    if (loadAddressEventInner && !lqResultReadyInner[addressIndexInput] && !lqBroadcastedInner[addressIndexInput])
      assert (addressedForwardValidInner == lqEarlyForwardInner[addressIndexInput])
        else $fatal(1, "early address-forward eligibility differs from original intent");
    if (responseResultIdentityLiveInner)
      assert (responseForwardPriorityInner == lqEarlyForwardInner[responseResultIndexInner])
        else $fatal(1, "narrow response-forward priority differs from full original intent");
    assert (int'(fifoCountInner) <= DATA_REQUEST_ENTRIES);
    if (dmemResponseInput.valid) assert (fifoValidInner[responseOwnerInner])
      else $fatal(1, "LSU received a response without an outstanding owner");
    if (dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner)
      assert (int'(fifoCountInner) < DATA_REQUEST_ENTRIES);
  end
`endif
endmodule
