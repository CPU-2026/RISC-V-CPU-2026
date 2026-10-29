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
  input rv32_pkg::store_allocation_input_t storeAllocationSecondInput,
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

  output logic [$clog2(LQ_DEPTH+1)-1:0] lqCountOutput,
  output logic [$clog2(SQ_DEPTH+1)-1:0] sqCountOutput,
  // Ordered issue4 allocation only. Memory/AGU/result transport stays scalar.
  input rv32_pkg::load_allocation_input_t [3:0] loadAllocationLanesInput,
  input rv32_pkg::store_allocation_input_t [3:0] storeAllocationLanesInput,
  output logic [3:0] loadAllocationLanesFireOutput, storeAllocationLanesFireOutput,
  output logic [3:0][$clog2(LQ_DEPTH)-1:0] loadPreviewIndexOutput,
  output logic [3:0][$clog2(SQ_DEPTH)-1:0] storePreviewIndexOutput,
  output logic [$clog2(LQ_DEPTH+1)-1:0] loadCreditsOutput,
  output logic [$clog2(SQ_DEPTH+1)-1:0] storeCreditsOutput
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
    int slot;
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
  store_forward_result_t selectedForwardInner;
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
  assign responseResultIdentityLiveInner = dmemResponseInput.valid && fifoValidInner[responseOwnerInner] &&
    !fifoDropInner[responseOwnerInner] && lqValidInner[responseResultIndexInner] &&
    lqTagInner[responseResultIndexInner] == fifoTagInner[responseOwnerInner] &&
    lqSentInner[responseResultIndexInner] && !lqResultReadyInner[responseResultIndexInner] &&
    !lqBroadcastedInner[responseResultIndexInner] &&
    (!flushInfoInput.valid || rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput.robTag));
  assign responseResultLiveInner = responseResultIdentityLiveInner && !responseForwardPriorityInner;
  logic storeAllocDataReadyResolvedInner;
  logic [31:0] storeAllocDataValueResolvedInner;
  logic [COMMIT_WIDTH-1:0] storeCommitMatchInner, storeRetireFireInner;
  logic storeSendSelectedInner;
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
  always_comb loadSelectWinnerInner = select_oldest_load(loadSelectCandidatesInner, loadSelectTagsInner);
  assign loadSelectFoundInner = loadSelectWinnerInner.valid;
  assign loadSelectIndexInner = loadSelectWinnerInner.index;
  assign loadSelectTagInner = loadSelectWinnerInner.tag;
  assign loadSelectAddressInner = !lqAddressReadyInner[loadSelectIndexInner] &&
    loadAddressEventInner && addressIndexInput == $bits(addressIndexInput)'(loadSelectIndexInner) ?
    addressInput.address : lqAddressInner[loadSelectIndexInner];
  // A separate combinational tournament: result production must not compete
  // with request selection for hardware or gain an extra register stage.
  always_comb bufferedResultWinnerInner = select_oldest_load(resultSelectCandidatesInner, loadSelectTagsInner);
  assign chooseResponseResultInner = responseResultLiveInner &&
    (!bufferedResultWinnerInner.valid ||
     rob_is_older(lqTagInner[responseResultIndexInner], bufferedResultWinnerInner.tag) ||
     (lqTagInner[responseResultIndexInner] == bufferedResultWinnerInner.tag &&
      responseResultIndexInner < bufferedResultWinnerInner.index));
  assign resultSelectWinnerInner = chooseResponseResultInner ?
    '{valid:1'b1, tag:lqTagInner[responseResultIndexInner], index:responseResultIndexInner} :
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

  // Independent of Load selection: prepare adjacent word addresses from each
  // OLD SQ row. The late selected Load address then needs equality only, not a
  // variable 30-bit subtraction. These are wires, not extra address state.
  logic [29:0] sqNextWordInner [SQ_DEPTH], sqPrevWordInner [SQ_DEPTH];
  for (genvar addressRow = 0; addressRow < SQ_DEPTH; addressRow++) begin : g_sq_word_neighbors
    assign sqNextWordInner[addressRow] = sqAddressInner[addressRow][31:2] + 30'd1;
    assign sqPrevWordInner[addressRow] = sqAddressInner[addressRow][31:2] - 30'd1;
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

  // Byte-interval overlap of two accesses. Each one spans at most one word
  // boundary (size <= 4, offset <= 3), so only same-word and adjacent-word
  // positions can intersect and 3-bit byte arithmetic suffices. Adjacent Store
  // words are precomputed before the selected Load address arrives. The two
  // wrap guards preserve the original unsigned mod-2^32 comparison semantics.
  localparam logic [29:0] LAST_WORD = '1;
  function automatic logic byte_overlap(
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput,
    input logic [31:0] storeAddressInput,
    input mem_size_e storeSizeInput,
    input logic [29:0] storeNextWordInput,
    input logic [29:0] storePrevWordInput
  );
    logic [2:0] loadOffset, storeOffset, loadSpan, storeSpan, loadEnd, storeEnd;
    loadOffset = {1'b0, loadAddressInput[1:0]};
    storeOffset = {1'b0, storeAddressInput[1:0]};
    loadSpan = {1'b0, mem_bytes(loadSizeInput)};
    storeSpan = {1'b0, mem_bytes(storeSizeInput)};
    loadEnd = loadOffset + loadSpan;
    storeEnd = storeOffset + storeSpan;
    if (loadAddressInput[31:2] == storeAddressInput[31:2])
      return loadOffset < storeEnd && storeOffset < loadEnd;
    if (loadAddressInput[31:2] == storeNextWordInput && storeAddressInput[31:2] != LAST_WORD)
      return loadOffset + 3'(4) < storeEnd;
    if (loadAddressInput[31:2] == storePrevWordInput && loadAddressInput[31:2] != LAST_WORD)
      return storeOffset + 3'(4) < loadEnd;
    return 1'b0;
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
    logic [31:0] youngestAddress, youngestData;
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
                  sqAddressInner[s], sqSizeInner[s], sqNextWordInner[s], sqPrevWordInner[s])))
            result.cacheBlocked = 1'b1;
          if (!addressReady) begin
            if (!unknownFound || sqOrderInner[s] > sqOrderInner[youngestUnknownIndex])
              youngestUnknownIndex = SQ_INDEX_W'(s);
            unknownFound = 1'b1;
          end else if (byte_overlap(loadAddressInput, loadSizeInput, address, sqSizeInner[s],
              sqNextWordInner[s], sqPrevWordInner[s]) &&
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
          sqAddressInner[s], sqSizeInner[s], sqNextWordInner[s], sqPrevWordInner[s]);
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

  // Only the returning row's priority bit is needed by CDB qualification.
  // Preserve the original final Load-address event override exactly. The
  // eight full payload-producing lqEarlyForward lanes remain unchanged.
  always_comb begin : response_forward_priority
    logic [STORE_DATA_LANES:0] notifications;
    notifications = '0;
    if (lqAddressReadyInner[responseResultIndexInner]) begin
      for (int lane = 0; lane < STORE_DATA_LANES; lane++) begin
        notifications[lane] = storeDataEventInner[lane] &&
          sqAddressReadyInner[storeDataIndexInput[lane]] &&
          notify_matches(storeDataIndexInput[lane], sqAddressInner[storeDataIndexInput[lane]],
            lqTagInner[responseResultIndexInner], lqAddressInner[responseResultIndexInner],
            lqSizeInner[responseResultIndexInner]);
      end
      notifications[STORE_DATA_LANES] = storeAddressEventInner && sqDataReadyInner[addressIndexInput] &&
        notify_matches(SQ_INDEX_W'(addressIndexInput), addressInput.address,
          lqTagInner[responseResultIndexInner], lqAddressInner[responseResultIndexInner],
          lqSizeInner[responseResultIndexInner]);
    end
    responseForwardPriorityInner = |notifications;
    if (loadAddressEventInner && addressIndexInput == $bits(addressIndexInput)'(responseResultIndexInner))
      responseForwardPriorityInner = addressedForwardValidInner;
  end

  // The address-event metadata is OLD AGU state, independent of the returning
  // Cache transaction. Under the equality above these are the same LQ row.
  // B request selection and C return qualification share this early 1-bit cone.
  assign addressedForwardValidInner = query_store_forward_valid(lqTagInner[addressIndexInput],
    addressInput.address, lqSizeInner[addressIndexInput]);

  // One query for the LQ row named by addressIndexInput. The per-row loop below
  // consumes it only on the matching iteration, so eight identical scans (they
  // differ solely in lqTag/lqSize) collapse into this single instance.
  always_comb
    addressedForwardInner = query_store_forward(
      lqTagInner[addressIndexInput], addressInput.address, lqSizeInner[addressIndexInput]);

  // All matching LQ rows may acquire registered results on this edge. CDB
  // selection above still reads only the old result registers, never intents.
  always_comb begin
    for (forwardIndexInner = 0; forwardIndexInner < LQ_DEPTH; forwardIndexInner = forwardIndexInner + 1) begin
      store_forward_result_t forwardResult;
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
          if (storeAddressEventInner && sqDataReadyInner[addressIndexInput] &&
              notify_matches(SQ_INDEX_W'(addressIndexInput), addressInput.address,
                lqTagInner[forwardIndexInner], lqAddressInner[forwardIndexInner], lqSizeInner[forwardIndexInner])) begin
            lqEarlyForwardInner[forwardIndexInner] = 1'b1;
            lqEarlyValueInner[forwardIndexInner] = sqDataInner[addressIndexInput];
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

  cdb_result_t storeAllocWbInner;
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
      cdb_result_t wb;
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
    cdb_result_t dataWb;
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

  always_comb begin : result_output
    loadResultOutput.valid = resultSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(resultSelectTagInner, flushInfoInput.robTag));
    loadResultOutput.robTag = resultSelectTagInner;
    loadResultOutput.destinationPhy = chooseResponseResultInner ? lqDestInner[responseResultIndexInner] :
      lqDestInner[bufferedResultWinnerInner.index];
    loadResultOutput.value = chooseResponseResultInner ?
      extend_load(dmemResponseInput.readData, lqSizeInner[responseResultIndexInner], lqUnsignedInner[responseResultIndexInner]) :
      extend_load(lqResultInner[bufferedResultWinnerInner.index], lqSizeInner[bufferedResultWinnerInner.index],
        lqUnsignedInner[bufferedResultWinnerInner.index]);
  end

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

    // Combinational qualification of every OLD SQ row. No address/data event
    // bypass and no reporting register: the ROB consumes all bits on this edge.
    storeCompleteOutput = '0;
    for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (sqValidInner[combIndexInner] && sqAddressReadyInner[combIndexInner] &&
          sqDataReadyInner[combIndexInner] && !sqCommittedInner[combIndexInner]) begin
        storeCompleteOutput.readyMask |= ROB_ENTRIES'(1) << sqTagInner[combIndexInner][ROB_TAG_W-2:0];
        if (sqTagInner[combIndexInner][ROB_TAG_W-1])
          storeCompleteOutput.epochMask |= ROB_ENTRIES'(1) << sqTagInner[combIndexInner][ROB_TAG_W-2:0];
      end
    end

    selectedForwardInner = '0;
    if (loadSelectFoundInner)
      selectedForwardInner = query_store_forward(loadSelectTagInner,
        loadSelectAddressInner, lqSizeInner[loadSelectIndexInner]);
    loadBlockedInner = selectedForwardInner.cacheBlocked;
    selectedLoadLiveInner = loadSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(loadSelectTagInner, flushInfoInput.robTag));
    // No new Load after the exit Store retires; committed SQ still progresses.
    loadNeedsMemoryInner = !coreStoppedInput && selectedLoadLiveInner && !loadBlockedInner &&
                          int'(fifoCountInner) < DATA_REQUEST_ENTRIES;

    storeSendSelectedInner = sqValidInner[sqHeadIndexInner] &&
      sqCommittedInner[sqHeadIndexInner];
    for (int lane = 0; lane < COMMIT_WIDTH; lane++)
      if (sqValidInner[sqHeadIndexInner] && storeRetireFireInner[lane] && storeCommitIndexInput[lane] == sqHeadIndexInner)
        storeSendSelectedInner = 1'b1;

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
        lqAddressInner[seqIndexInner] <= '0;
        lqSentInner[seqIndexInner] <= 1'b0;
        lqResultReadyInner[seqIndexInner] <= 1'b0;
        lqBroadcastedInner[seqIndexInner] <= 1'b0;
        lqResultInner[seqIndexInner] <= '0;
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
          lqAddressInner[addressIndexInput] <= addressInput.address;
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
             lqResultInner[fifoIndexInner[responseOwnerInner]] <= dmemResponseInput.readData;
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
          lqResultInner[seqIndexInner] <= lqEarlyValueInner[seqIndexInner];
          lqResultReadyInner[seqIndexInner] <= 1'b1;
          lqSentInner[seqIndexInner] <= 1'b1;
          lqBroadcastedInner[seqIndexInner] <= 1'b0;
        end
      end
    end
  end
`ifndef SYNTHESIS
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
