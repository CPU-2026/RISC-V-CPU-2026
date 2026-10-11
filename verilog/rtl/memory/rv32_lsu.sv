module rv32_lsu #(
  parameter int unsigned LQ_DEPTH = rv32_pkg::LQ_ENTRIES,
  parameter int unsigned SQ_DEPTH = rv32_pkg::SQ_ENTRIES,
  // Store-queue data ports driven by the storeValue RS.  One lane per RS slot
  // so every store whose data resolves in the same cycle is delivered at once;
  // the RV32IM core instantiates it with STORE_VALUE_RS_ENTRIES.
  parameter int unsigned STORE_DATA_LANES = 1
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,

  input  rv32_pkg::load_allocation_input_t loadAllocationInput,
  output logic                   loadAllocReadyOutput,
  output logic [$clog2(LQ_DEPTH)-1:0] loadAllocIndexOutput,

  input  rv32_pkg::store_allocation_input_t storeAllocationInput,
  output logic                   storeAllocReadyOutput,
  output logic [$clog2(SQ_DEPTH)-1:0] storeAllocIndexOutput,

  input rv32_pkg::store_data_input_t storeDataInput [STORE_DATA_LANES-1:0],
  input logic [$clog2(SQ_DEPTH)-1:0] storeDataIndexInput [STORE_DATA_LANES-1:0],

  input  rv32_pkg::lsu_address_input_t addressInput,
  input  logic [(($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH)) ?
                 $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH))-1:0] addressIndexInput,

  input  rv32_pkg::cdb_result_t [3:0] writebackInput,

  output rv32_pkg::load_result_output_t loadResultOutput,
  input  logic                   loadResultReadyInput,
  input  rv32_pkg::rob_retirement_input_t robRetireInput,

  output rv32_pkg::store_completion_output_t storeCompleteOutput,

  input  rv32_pkg::store_commit_input_t storeCommitInput,
  input  logic [$clog2(SQ_DEPTH)-1:0] storeCommitIndexInput,
  output logic                   storeCommitReadyOutput,
  // ROB-head payload, independent of the older Store selected for memory.
  output rv32_pkg::data_memory_request_output_t storeRetirementOutput,

  output rv32_pkg::data_memory_request_output_t dmemRequestOutput,
  input  logic                   dmemReqReadyInput,
  input  rv32_pkg::data_memory_response_input_t dmemResponseInput,

  output logic [$clog2(LQ_DEPTH+1)-1:0] lqCountOutput,
  output logic [$clog2(SQ_DEPTH+1)-1:0] sqCountOutput
);
  import rv32_pkg::*;

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

  logic pendingInner;
  logic pendingDropInner;
  logic [LQ_INDEX_W-1:0] pendingIndexInner;
  rob_tag_t pendingTagInner;
  mem_size_e pendingSizeInner;
  logic pendingUnsignedInner;

  logic loadAllocFoundInner;
  logic storeAllocFoundInner;
  logic loadSelectFoundInner;
  logic [LQ_INDEX_W-1:0] loadSelectIndexInner;
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
  integer forwardIndexInner;

  logic resultSelectFoundInner;
  logic [LQ_INDEX_W-1:0] resultSelectIndexInner;
  logic storeAllocDataReadyResolvedInner;
  logic [31:0] storeAllocDataValueResolvedInner;
  logic storeCommitMatchInner;
  logic storeRetireFireInner, storeSendSelectedInner;
  logic loadAddressMatchInner, storeAddressMatchInner;
  logic loadRequestSelectedInner;
  logic [31:0] extendedResponseInner;
  integer combIndexInner;
  integer seqIndexInner;
  integer storeLaneInner;

  // Normal address results name an existing reserved row. The standalone LSU
  // interface also permits a matching same-cycle allocation/address pair;
  // preserve that priority without authenticating an old result as a new row.
  assign loadAddressMatchInner =
    (lqValidInner[addressIndexInput] && lqTagInner[addressIndexInput] == addressInput.robTag) ||
    (loadAllocationInput.valid && loadAllocReadyOutput &&
     addressIndexInput == $bits(addressIndexInput)'(loadAllocIndexOutput) &&
     loadAllocationInput.robTag == addressInput.robTag);
  assign storeAddressMatchInner =
    (sqValidInner[addressIndexInput] && !sqCommittedInner[addressIndexInput] &&
     sqTagInner[addressIndexInput] == addressInput.robTag) ||
    (storeAllocationInput.valid && storeAllocReadyOutput &&
     addressIndexInput == $bits(addressIndexInput)'(storeAllocIndexOutput) &&
      storeAllocationInput.robTag == addressInput.robTag);

  assign sqHeadIndexInner = sqHeadSeqInner[SQ_INDEX_W-1:0];
  assign storeCommitMatchInner = storeCommitInput.valid &&
    sqValidInner[storeCommitIndexInput] && !sqCommittedInner[storeCommitIndexInput] &&
    (sqTagInner[storeCommitIndexInput] == storeCommitInput.robTag) &&
    sqAddressReadyInner[storeCommitIndexInput] && sqDataReadyInner[storeCommitIndexInput] &&
    (!flushInfoInput.valid || rob_is_older(storeCommitInput.robTag, flushInfoInput.robTag));
  assign storeCommitReadyOutput = storeCommitMatchInner;
  assign storeRetireFireInner = storeCommitMatchInner && robRetireInput.valid &&
    robRetireInput.robTag == storeCommitInput.robTag;

  function automatic logic [SQ_INDEX_W-1:0] sq_order(input logic [SQ_INDEX_W-1:0] indexInput);
    return indexInput - sqHeadIndexInner;
  endfunction

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

  function automatic logic byte_overlap(
    input logic [31:0] loadAddressInput,
    input mem_size_e loadSizeInput,
    input logic [31:0] storeAddressInput,
    input mem_size_e storeSizeInput
  );
    return loadAddressInput >= storeAddressInput ?
      loadAddressInput - storeAddressInput < {29'b0, mem_bytes(storeSizeInput)} :
      storeAddressInput - loadAddressInput < {29'b0, mem_bytes(loadSizeInput)};
  endfunction

  assign storeAddressEventInner = addressInput.valid && addressInput.isStore &&
    storeAddressMatchInner && sqValidInner[addressIndexInput] &&
    (!flushInfoInput.valid || rob_is_older(addressInput.robTag, flushInfoInput.robTag));
  assign loadAddressEventInner = addressInput.valid && !addressInput.isStore &&
    loadAddressMatchInner && lqValidInner[addressIndexInput] &&
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
    logic [31:0] address, data, delta;
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
            if (!unknownFound || sq_order(SQ_INDEX_W'(s)) > sq_order(youngestUnknownIndex))
              youngestUnknownIndex = SQ_INDEX_W'(s);
            unknownFound = 1'b1;
          end else if (byte_overlap(loadAddressInput, loadSizeInput, address, sqSizeInner[s]) &&
              (!found || sq_order(SQ_INDEX_W'(s)) > sq_order(youngestIndex))) begin
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
        (!found || sq_order(youngestUnknownIndex) >= sq_order(youngestIndex));
      delta = loadAddressInput - youngestAddress;
      if (found && youngestReady && loadAddressInput >= youngestAddress &&
          delta + {29'b0, mem_bytes(loadSizeInput)} <= {29'b0, mem_bytes(youngestSize)}) begin
        result.mask = loadSizeInput == MEM_BYTE ? 4'b0001 :
                     loadSizeInput == MEM_HALF ? 4'b0011 : 4'b1111;
        result.data = youngestData >> (delta << 3);
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
        if (sqValidInner[s] && sq_order(SQ_INDEX_W'(s)) > sq_order(sourceInput) &&
            rob_is_older(sqTagInner[s], loadTagInput) &&
            (!sqAddressReadyInner[s] || sqAddressInner[s][31:2] == sourceAddressInput[31:2]))
          matched = 1'b0;
      end
      return matched;
    end
  endfunction

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
              lqEarlyValueInner[forwardIndexInner] = extend_load(storeDataInput[lane].value,
                lqSizeInner[forwardIndexInner], lqUnsignedInner[forwardIndexInner]);
            end
          end
          if (storeAddressEventInner && sqDataReadyInner[addressIndexInput] &&
              notify_matches(SQ_INDEX_W'(addressIndexInput), addressInput.address,
                lqTagInner[forwardIndexInner], lqAddressInner[forwardIndexInner], lqSizeInner[forwardIndexInner])) begin
            lqEarlyForwardInner[forwardIndexInner] = 1'b1;
            lqEarlyValueInner[forwardIndexInner] = extend_load(sqDataInner[addressIndexInput],
              lqSizeInner[forwardIndexInner], lqUnsignedInner[forwardIndexInner]);
          end
        end
        if (loadAddressEventInner && addressIndexInput == $bits(addressIndexInput)'(forwardIndexInner)) begin
          forwardResult = query_store_forward(lqTagInner[forwardIndexInner], addressInput.address,
                                              lqSizeInner[forwardIndexInner]);
          lqEarlyForwardInner[forwardIndexInner] = !forwardResult.blocked && (forwardResult.mask & needed) == needed;
          lqEarlyValueInner[forwardIndexInner] = extend_load(forwardResult.data,
            lqSizeInner[forwardIndexInner], lqUnsignedInner[forwardIndexInner]);
        end
      end
    end
  end

  always_comb begin
    storeAllocDataReadyResolvedInner = storeAllocationInput.dataReady;
    storeAllocDataValueResolvedInner = storeAllocationInput.dataValue;
    // P0 is not a producer identity. The core uses dataTag=0 while its
    // StoreValue RS owns delivery; an unrelated rd=x0 WB must not fill it.
    if (!storeAllocDataReadyResolvedInner && storeAllocationInput.dataTag != '0) begin
      if (writebackInput[0].valid && (writebackInput[0].phyTag == storeAllocationInput.dataTag)) begin
        storeAllocDataReadyResolvedInner = 1'b1;
        storeAllocDataValueResolvedInner = writebackInput[0].value;
      end else if (writebackInput[1].valid && (writebackInput[1].phyTag == storeAllocationInput.dataTag)) begin
        storeAllocDataReadyResolvedInner = 1'b1;
        storeAllocDataValueResolvedInner = writebackInput[1].value;
      end else if (writebackInput[2].valid && (writebackInput[2].phyTag == storeAllocationInput.dataTag)) begin
        storeAllocDataReadyResolvedInner = 1'b1;
        storeAllocDataValueResolvedInner = writebackInput[2].value;
      end else if (writebackInput[3].valid && (writebackInput[3].phyTag == storeAllocationInput.dataTag)) begin
        storeAllocDataReadyResolvedInner = 1'b1;
        storeAllocDataValueResolvedInner = writebackInput[3].value;
      end
    end
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

    resultSelectFoundInner = 1'b0;
    resultSelectIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (lqValidInner[combIndexInner] && lqResultReadyInner[combIndexInner] &&
          !lqBroadcastedInner[combIndexInner] &&
          (!resultSelectFoundInner ||
           rob_is_older(lqTagInner[combIndexInner], lqTagInner[resultSelectIndexInner]))) begin
        resultSelectFoundInner = 1'b1;
        resultSelectIndexInner = combIndexInner[LQ_INDEX_W-1:0];
      end
    end
    loadResultOutput.valid = resultSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(lqTagInner[resultSelectIndexInner], flushInfoInput.robTag));
    loadResultOutput.robTag = lqTagInner[resultSelectIndexInner];
    loadResultOutput.destinationPhy = lqDestInner[resultSelectIndexInner];
    loadResultOutput.value = lqResultInner[resultSelectIndexInner];

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

    loadSelectFoundInner = 1'b0;
    loadSelectIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (lqValidInner[combIndexInner] && lqAddressReadyInner[combIndexInner] &&
          !lqSentInner[combIndexInner] && !lqResultReadyInner[combIndexInner] &&
          (!loadSelectFoundInner ||
           rob_is_older(lqTagInner[combIndexInner], lqTagInner[loadSelectIndexInner]))) begin
        loadSelectFoundInner = 1'b1;
        loadSelectIndexInner = combIndexInner[LQ_INDEX_W-1:0];
      end
    end

    selectedForwardInner = '0;
    if (loadSelectFoundInner)
      selectedForwardInner = query_store_forward(lqTagInner[loadSelectIndexInner],
        lqAddressInner[loadSelectIndexInner], lqSizeInner[loadSelectIndexInner]);
    loadBlockedInner = selectedForwardInner.cacheBlocked;
    selectedLoadLiveInner = loadSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(lqTagInner[loadSelectIndexInner], flushInfoInput.robTag));
    loadNeedsMemoryInner = selectedLoadLiveInner && !loadBlockedInner &&
                          !lqEarlyForwardInner[loadSelectIndexInner] &&
                          (!pendingInner || dmemResponseInput.valid);

    storeRetirementOutput = '0;
    storeRetirementOutput.valid = storeCommitMatchInner;
    storeRetirementOutput.write = 1'b1;
    storeRetirementOutput.address = sqAddressInner[storeCommitIndexInput];
    storeRetirementOutput.writeData = sqDataInner[storeCommitIndexInput];
    storeRetirementOutput.size = mem_size_e'(sqSizeInner[storeCommitIndexInput]);
    unique case (sqSizeInner[storeCommitIndexInput])
      MEM_BYTE: storeRetirementOutput.writeStrobe = 4'b0001;
      MEM_HALF: storeRetirementOutput.writeStrobe = 4'b0011;
      default:  storeRetirementOutput.writeStrobe = 4'b1111;
    endcase
    storeSendSelectedInner = sqValidInner[sqHeadIndexInner] &&
      (sqCommittedInner[sqHeadIndexInner] ||
       (storeRetireFireInner && storeCommitIndexInput == sqHeadIndexInner));

    dmemRequestOutput.valid = 1'b0;
    dmemRequestOutput.write = 1'b0;
    dmemRequestOutput.address = 32'b0;
    dmemRequestOutput.writeData = 32'b0;
    dmemRequestOutput.writeStrobe = 4'b0000;
    dmemRequestOutput.size = MEM_WORD;
    loadRequestSelectedInner = 1'b0;
    if (storeSendSelectedInner) begin
      dmemRequestOutput.valid = 1'b1;
      dmemRequestOutput.write = 1'b1;
      dmemRequestOutput.address = sqAddressInner[sqHeadIndexInner];
      dmemRequestOutput.writeData = sqDataInner[sqHeadIndexInner];
      dmemRequestOutput.size = mem_size_e'(sqSizeInner[sqHeadIndexInner]);
      unique case (sqSizeInner[sqHeadIndexInner])
        MEM_BYTE: dmemRequestOutput.writeStrobe = 4'b0001;
        MEM_HALF: dmemRequestOutput.writeStrobe = 4'b0011;
        default:  dmemRequestOutput.writeStrobe = 4'b1111;
      endcase
    end else if (loadNeedsMemoryInner) begin
      dmemRequestOutput.valid = 1'b1;
      dmemRequestOutput.write = 1'b0;
      dmemRequestOutput.address = lqAddressInner[loadSelectIndexInner];
      dmemRequestOutput.size = mem_size_e'(lqSizeInner[loadSelectIndexInner]);
      loadRequestSelectedInner = 1'b1;
    end

    extendedResponseInner = extend_load(dmemResponseInput.readData,
      pendingSizeInner, pendingUnsignedInner);

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
      pendingInner <= 1'b0;
      pendingDropInner <= 1'b0;
      pendingIndexInner <= '0;
      pendingTagInner <= '0;
      pendingSizeInner <= MEM_WORD;
      pendingUnsignedInner <= 1'b0;
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
    end else begin
      for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (sqValidInner[seqIndexInner] && !sqDataReadyInner[seqIndexInner] &&
            sqDataTagInner[seqIndexInner] != '0) begin
          if (writebackInput[0].valid && (writebackInput[0].phyTag == sqDataTagInner[seqIndexInner])) begin
            sqDataReadyInner[seqIndexInner] <= 1'b1;
            sqDataInner[seqIndexInner] <= writebackInput[0].value;
          end else if (writebackInput[1].valid && (writebackInput[1].phyTag == sqDataTagInner[seqIndexInner])) begin
            sqDataReadyInner[seqIndexInner] <= 1'b1;
            sqDataInner[seqIndexInner] <= writebackInput[1].value;
          end else if (writebackInput[2].valid && (writebackInput[2].phyTag == sqDataTagInner[seqIndexInner])) begin
            sqDataReadyInner[seqIndexInner] <= 1'b1;
            sqDataInner[seqIndexInner] <= writebackInput[2].value;
          end else if (writebackInput[3].valid && (writebackInput[3].phyTag == sqDataTagInner[seqIndexInner])) begin
            sqDataReadyInner[seqIndexInner] <= 1'b1;
            sqDataInner[seqIndexInner] <= writebackInput[3].value;
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
        if (pendingInner &&
            rob_is_younger(pendingTagInner, flushInfoInput.robTag))
          pendingDropInner <= 1'b1;

        if (loadResultOutput.valid && loadResultReadyInput)
          lqBroadcastedInner[resultSelectIndexInner] <= 1'b1;

      end else begin
        if (loadAllocationInput.valid && loadAllocReadyOutput) begin
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
        if (storeAllocationInput.valid && storeAllocReadyOutput) begin
          sqTailSeqInner <= sqTailSeqInner + 1'b1;
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

        if (loadResultOutput.valid && loadResultReadyInput)
          lqBroadcastedInner[resultSelectIndexInner] <= 1'b1;

      end

      // Retirement posts a Store; only memory acceptance releases the head.
      // Both may happen on one edge, including an older retirement/flush edge.
      if (storeRetireFireInner)
        sqCommittedInner[storeCommitIndexInput] <= 1'b1;
      if (storeSendSelectedInner && dmemReqReadyInput) begin
        sqValidInner[sqHeadIndexInner] <= 1'b0;
        sqHeadSeqInner <= sqHeadSeqInner + 1'b1;
      end

      // Result consumption only records broadcast completion. The actual ROB
      // retirement event releases the reservation, including older retirement
      // concurrent with a recovery broadcast.
      if (robRetireInput.valid) begin
        for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
          if (lqValidInner[seqIndexInner] && lqTagInner[seqIndexInner] == robRetireInput.robTag)
            lqValidInner[seqIndexInner] <= 1'b0;
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

      // A request the memory has already accepted may complete during a flush
      // cycle, when the else branch above is skipped in its entirety. That
      // response must still retire the pending marker: the flush squashes the
      // LQ entry, but dropping the handshake leaves pendingInner set forever and
      // deadlocks every later load. The payload is delivered only when the
      // load itself survived the flush.
      if (dmemResponseInput.valid && pendingInner) begin
        pendingInner <= 1'b0;
        if (!pendingDropInner &&
             !(flushInfoInput.valid &&
               rob_is_younger(pendingTagInner, flushInfoInput.robTag)) &&
            lqValidInner[pendingIndexInner] && lqTagInner[pendingIndexInner] == pendingTagInner &&
            !lqResultReadyInner[pendingIndexInner]) begin
          lqResultInner[pendingIndexInner] <= extendedResponseInner;
          lqResultReadyInner[pendingIndexInner] <= 1'b1;
        end
        pendingDropInner <= 1'b0;
      end

      // Consume the OLD owner above, then capture a NEW accepted read. The
      // returning transaction must not clear a replacement pending marker.
      if (dmemRequestOutput.valid && dmemReqReadyInput && loadRequestSelectedInner) begin
        pendingInner <= 1'b1;
        pendingDropInner <= 1'b0;
        pendingIndexInner <= loadSelectIndexInner;
        pendingTagInner <= lqTagInner[loadSelectIndexInner];
        pendingSizeInner <= lqSizeInner[loadSelectIndexInner];
        pendingUnsignedInner <= lqUnsignedInner[loadSelectIndexInner];
        lqSentInner[loadSelectIndexInner] <= 1'b1;
      end

      // One final forwarding write point per row. Full forwarding wins over
      // a simultaneous accepted read's late response; pending still drains.
      for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (lqEarlyForwardInner[seqIndexInner]) begin
          lqResultInner[seqIndexInner] <= lqEarlyValueInner[seqIndexInner];
          lqResultReadyInner[seqIndexInner] <= 1'b1;
          lqSentInner[seqIndexInner] <= 1'b1;
          lqBroadcastedInner[seqIndexInner] <= 1'b0;
        end
      end
    end
  end
endmodule
