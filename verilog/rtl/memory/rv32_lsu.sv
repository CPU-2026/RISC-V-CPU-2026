module rv32_lsu #(
  parameter int unsigned LQ_DEPTH = rv32_pkg::LQ_ENTRIES,
  parameter int unsigned SQ_DEPTH = rv32_pkg::SQ_ENTRIES
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

  input  rv32_pkg::lsu_address_input_t addressInput,
  input  logic [(($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH)) ?
                 $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH))-1:0] addressIndexInput,

  input  rv32_pkg::cdb_result_t [3:0] writebackInput,

  output rv32_pkg::load_result_output_t loadResultOutput,
  input  logic                   loadResultReadyInput,

  output rv32_pkg::store_completion_output_t storeCompleteOutput,

  input  rv32_pkg::store_commit_input_t storeCommitInput,
  input  logic [$clog2(SQ_DEPTH)-1:0] storeCommitIndexInput,
  output logic                   storeCommitReadyOutput,

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
  logic [31:0] lqResultInner [LQ_DEPTH];

  logic sqValidInner [SQ_DEPTH];
  rob_tag_t sqTagInner [SQ_DEPTH];
  mem_size_e sqSizeInner [SQ_DEPTH];
  logic sqAddressReadyInner [SQ_DEPTH];
  logic [31:0] sqAddressInner [SQ_DEPTH];
  logic sqDataReadyInner [SQ_DEPTH];
  phy_tag_t sqDataTagInner [SQ_DEPTH];
  logic [31:0] sqDataInner [SQ_DEPTH];
  logic sqReportedInner [SQ_DEPTH];

  logic pendingInner;
  logic pendingDropInner;
  logic [LQ_INDEX_W-1:0] pendingIndexInner;
  logic [3:0] pendingForwardMaskInner;
  logic [31:0] pendingForwardDataInner;

  logic loadAllocFoundInner;
  logic storeAllocFoundInner;
  logic loadSelectFoundInner;
  logic [LQ_INDEX_W-1:0] loadSelectIndexInner;
  logic loadBlockedInner;
  logic [3:0] loadForwardMaskInner;
  logic [31:0] loadForwardDataInner;
  logic [2:0] selectedLoadBytesInner;
  logic [3:0] selectedLoadByteMaskInner;
  logic loadFullyForwardedInner;
  logic loadNeedsMemoryInner;
  logic selectedLoadLiveInner;

  logic forwardByteValidInner [4];
  rob_tag_t forwardByteTagInner [4];
  logic [7:0] forwardByteDataInner [4];

  logic resultSelectFoundInner;
  logic [LQ_INDEX_W-1:0] resultSelectIndexInner;
  logic storeCompleteFoundInner;
  logic [SQ_INDEX_W-1:0] storeCompleteIndexInner;
  logic storeAllocDataReadyResolvedInner;
  logic [31:0] storeAllocDataValueResolvedInner;
  logic storeCommitMatchInner;
  logic loadRequestSelectedInner;
  logic [31:0] mergedResponseInner;
  logic [31:0] extendedResponseInner;
  integer combIndexInner, combJInner;
  integer seqIndexInner;

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

  function automatic logic [7:0] select_store_byte(
    input logic [31:0] dataInput,
    input logic [31:0] byteOffsetInput
  );
    begin
      unique case (byteOffsetInput[1:0])
        2'd0: select_store_byte = dataInput[7:0];
        2'd1: select_store_byte = dataInput[15:8];
        2'd2: select_store_byte = dataInput[23:16];
        default: select_store_byte = dataInput[31:24];
      endcase
    end
  endfunction

  always_comb begin
    storeAllocDataReadyResolvedInner = storeAllocationInput.dataReady;
    storeAllocDataValueResolvedInner = storeAllocationInput.dataValue;
    if (!storeAllocDataReadyResolvedInner) begin
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

    storeAllocFoundInner = 1'b0;
    storeAllocIndexOutput = '0;
    for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (!storeAllocFoundInner && !sqValidInner[combIndexInner]) begin
        storeAllocFoundInner = 1'b1;
        storeAllocIndexOutput = combIndexInner[SQ_INDEX_W-1:0];
      end
    end
    storeAllocReadyOutput = storeAllocFoundInner && !flushInfoInput.valid;

    resultSelectFoundInner = 1'b0;
    resultSelectIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (lqValidInner[combIndexInner] && lqResultReadyInner[combIndexInner] &&
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

    storeCompleteFoundInner = 1'b0;
    storeCompleteIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1) begin
      if (sqValidInner[combIndexInner] && sqAddressReadyInner[combIndexInner] &&
          sqDataReadyInner[combIndexInner] && !sqReportedInner[combIndexInner] &&
          (!storeCompleteFoundInner ||
           rob_is_older(sqTagInner[combIndexInner],
                        sqTagInner[storeCompleteIndexInner]))) begin
        storeCompleteFoundInner = 1'b1;
        storeCompleteIndexInner = combIndexInner[SQ_INDEX_W-1:0];
      end
    end
    storeCompleteOutput.valid = storeCompleteFoundInner &&
      (!flushInfoInput.valid || rob_is_older(sqTagInner[storeCompleteIndexInner], flushInfoInput.robTag));
    storeCompleteOutput.robTag = sqTagInner[storeCompleteIndexInner];

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

    selectedLoadBytesInner = mem_bytes(lqSizeInner[loadSelectIndexInner]);
    unique case (lqSizeInner[loadSelectIndexInner])
      MEM_BYTE: selectedLoadByteMaskInner = 4'b0001;
      MEM_HALF: selectedLoadByteMaskInner = 4'b0011;
      default:  selectedLoadByteMaskInner = 4'b1111;
    endcase
    loadBlockedInner = 1'b0;
    loadForwardMaskInner = 4'b0000;
    loadForwardDataInner = 32'b0;
    for (combJInner = 0; combJInner < 4; combJInner = combJInner + 1) begin
      forwardByteValidInner[combJInner] = 1'b0;
      forwardByteTagInner[combJInner] = '0;
      forwardByteDataInner[combJInner] = 8'b0;
    end

    if (loadSelectFoundInner) begin
      for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1) begin
        if (sqValidInner[combIndexInner] &&
            rob_is_older(sqTagInner[combIndexInner],
                         lqTagInner[loadSelectIndexInner])) begin
          if (!sqAddressReadyInner[combIndexInner]) begin
            loadBlockedInner = 1'b1;
          end else begin
            for (combJInner = 0; combJInner < 4; combJInner = combJInner + 1) begin
              if ((combJInner < selectedLoadBytesInner) &&
                  ((lqAddressInner[loadSelectIndexInner] + combJInner) >=
                   sqAddressInner[combIndexInner]) &&
                  ((lqAddressInner[loadSelectIndexInner] + combJInner) <
                   (sqAddressInner[combIndexInner] +
                    {29'b0, mem_bytes(sqSizeInner[combIndexInner])}))) begin
                if (!sqDataReadyInner[combIndexInner]) begin
                  loadBlockedInner = 1'b1;
                end else if (!forwardByteValidInner[combJInner] ||
                             rob_is_younger(sqTagInner[combIndexInner],
                                            forwardByteTagInner[combJInner])) begin
                  forwardByteValidInner[combJInner] = 1'b1;
                  forwardByteTagInner[combJInner] = sqTagInner[combIndexInner];
                  forwardByteDataInner[combJInner] = select_store_byte(
                    sqDataInner[combIndexInner],
                    lqAddressInner[loadSelectIndexInner] + combJInner -
                    sqAddressInner[combIndexInner]);
                end
              end
            end
          end
        end
      end
    end

    for (combJInner = 0; combJInner < 4; combJInner = combJInner + 1) begin
      if (forwardByteValidInner[combJInner]) begin
        loadForwardMaskInner[combJInner] = 1'b1;
        loadForwardDataInner = loadForwardDataInner |
          ({24'b0, forwardByteDataInner[combJInner]} << (combJInner << 3));
      end
    end
    selectedLoadLiveInner = loadSelectFoundInner &&
      (!flushInfoInput.valid || rob_is_older(lqTagInner[loadSelectIndexInner], flushInfoInput.robTag));
    loadFullyForwardedInner = selectedLoadLiveInner && !loadBlockedInner &&
                            ((loadForwardMaskInner & selectedLoadByteMaskInner) ==
                             selectedLoadByteMaskInner);
    loadNeedsMemoryInner = selectedLoadLiveInner && !loadBlockedInner &&
                         !loadFullyForwardedInner && !pendingInner;

    storeCommitMatchInner = storeCommitInput.valid &&
      sqValidInner[storeCommitIndexInput] &&
      (sqTagInner[storeCommitIndexInput] == storeCommitInput.robTag) &&
      sqAddressReadyInner[storeCommitIndexInput] &&
      sqDataReadyInner[storeCommitIndexInput] &&
      (!flushInfoInput.valid || rob_is_older(storeCommitInput.robTag, flushInfoInput.robTag));

    dmemRequestOutput.valid = 1'b0;
    dmemRequestOutput.write = 1'b0;
    dmemRequestOutput.address = 32'b0;
    dmemRequestOutput.writeData = 32'b0;
    dmemRequestOutput.writeStrobe = 4'b0000;
    dmemRequestOutput.size = MEM_WORD;
    loadRequestSelectedInner = 1'b0;
    if (storeCommitMatchInner) begin
      dmemRequestOutput.valid = 1'b1;
      dmemRequestOutput.write = 1'b1;
      dmemRequestOutput.address = sqAddressInner[storeCommitIndexInput];
      dmemRequestOutput.writeData = sqDataInner[storeCommitIndexInput];
      dmemRequestOutput.size = mem_size_e'(sqSizeInner[storeCommitIndexInput]);
      unique case (sqSizeInner[storeCommitIndexInput])
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
    storeCommitReadyOutput = storeCommitMatchInner && dmemReqReadyInput;

    mergedResponseInner = dmemResponseInput.readData;
    for (combJInner = 0; combJInner < 4; combJInner = combJInner + 1) begin
      if (pendingForwardMaskInner[combJInner]) begin
        mergedResponseInner = (mergedResponseInner &
                           ~(32'h0000_00ff << (combJInner << 3))) |
                          (pendingForwardDataInner &
                           (32'h0000_00ff << (combJInner << 3)));
      end
    end
    extendedResponseInner = extend_load(mergedResponseInner,
      lqSizeInner[pendingIndexInner], lqUnsignedInner[pendingIndexInner]);

    lqCountOutput = '0;
    for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1)
      if (lqValidInner[combIndexInner]) lqCountOutput = lqCountOutput + 1'b1;
    sqCountOutput = '0;
    for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1)
      if (sqValidInner[combIndexInner]) sqCountOutput = sqCountOutput + 1'b1;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      pendingInner <= 1'b0;
      pendingDropInner <= 1'b0;
      pendingIndexInner <= '0;
      pendingForwardMaskInner <= '0;
      pendingForwardDataInner <= '0;
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
        sqReportedInner[seqIndexInner] <= 1'b0;
      end
    end else begin
      for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (sqValidInner[seqIndexInner] && !sqDataReadyInner[seqIndexInner]) begin
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

      if (flushInfoInput.valid) begin
        for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
          if (lqValidInner[seqIndexInner] &&
              rob_is_younger(lqTagInner[seqIndexInner], flushInfoInput.robTag))
            lqValidInner[seqIndexInner] <= 1'b0;
        for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1)
          if (sqValidInner[seqIndexInner] &&
              rob_is_younger(sqTagInner[seqIndexInner], flushInfoInput.robTag))
            sqValidInner[seqIndexInner] <= 1'b0;
        if (pendingInner &&
            rob_is_younger(lqTagInner[pendingIndexInner], flushInfoInput.robTag))
          pendingDropInner <= 1'b1;

        if (storeCompleteOutput.valid)
          sqReportedInner[storeCompleteIndexInner] <= 1'b1;

        if (loadFullyForwardedInner) begin
          lqResultInner[loadSelectIndexInner] <= extend_load(
            loadForwardDataInner, lqSizeInner[loadSelectIndexInner],
            lqUnsignedInner[loadSelectIndexInner]);
          lqResultReadyInner[loadSelectIndexInner] <= 1'b1;
          lqSentInner[loadSelectIndexInner] <= 1'b1;
        end else if (dmemRequestOutput.valid && dmemReqReadyInput &&
                     loadRequestSelectedInner) begin
          pendingInner <= 1'b1;
          pendingDropInner <= 1'b0;
          pendingIndexInner <= loadSelectIndexInner;
          pendingForwardMaskInner <= loadForwardMaskInner;
          pendingForwardDataInner <= loadForwardDataInner;
          lqSentInner[loadSelectIndexInner] <= 1'b1;
        end

        if (loadResultOutput.valid && loadResultReadyInput)
          lqValidInner[resultSelectIndexInner] <= 1'b0;

        if (storeCommitReadyOutput)
          sqValidInner[storeCommitIndexInput] <= 1'b0;
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
        end
        if (storeAllocationInput.valid && storeAllocReadyOutput) begin
          sqValidInner[storeAllocIndexOutput] <= 1'b1;
          sqTagInner[storeAllocIndexOutput] <= storeAllocationInput.robTag;
          sqSizeInner[storeAllocIndexOutput] <= storeAllocationInput.size;
          sqAddressReadyInner[storeAllocIndexOutput] <= 1'b0;
          sqDataReadyInner[storeAllocIndexOutput] <=
            storeAllocDataReadyResolvedInner;
          sqDataTagInner[storeAllocIndexOutput] <= storeAllocationInput.dataTag;
          sqDataInner[storeAllocIndexOutput] <= storeAllocDataValueResolvedInner;
          sqReportedInner[storeAllocIndexOutput] <= 1'b0;
        end

        if (addressInput.valid) begin
          if (addressInput.isStore) begin
            sqAddressInner[addressIndexInput] <= addressInput.address;
            sqAddressReadyInner[addressIndexInput] <= 1'b1;
          end else begin
            lqAddressInner[addressIndexInput] <= addressInput.address;
            lqAddressReadyInner[addressIndexInput] <= 1'b1;
          end
        end

        if (storeCompleteOutput.valid)
          sqReportedInner[storeCompleteIndexInner] <= 1'b1;

        if (loadFullyForwardedInner) begin
          lqResultInner[loadSelectIndexInner] <= extend_load(
            loadForwardDataInner, lqSizeInner[loadSelectIndexInner],
            lqUnsignedInner[loadSelectIndexInner]);
          lqResultReadyInner[loadSelectIndexInner] <= 1'b1;
          lqSentInner[loadSelectIndexInner] <= 1'b1;
        end else if (dmemRequestOutput.valid && dmemReqReadyInput &&
                     loadRequestSelectedInner) begin
          pendingInner <= 1'b1;
          pendingDropInner <= 1'b0;
          pendingIndexInner <= loadSelectIndexInner;
          pendingForwardMaskInner <= loadForwardMaskInner;
          pendingForwardDataInner <= loadForwardDataInner;
          lqSentInner[loadSelectIndexInner] <= 1'b1;
        end

        if (loadResultOutput.valid && loadResultReadyInput)
          lqValidInner[resultSelectIndexInner] <= 1'b0;

        if (storeCommitReadyOutput)
          sqValidInner[storeCommitIndexInput] <= 1'b0;
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
              rob_is_younger(lqTagInner[pendingIndexInner], flushInfoInput.robTag)) &&
            lqValidInner[pendingIndexInner]) begin
          lqResultInner[pendingIndexInner] <= extendedResponseInner;
          lqResultReadyInner[pendingIndexInner] <= 1'b1;
        end
        pendingDropInner <= 1'b0;
      end
    end
  end
endmodule
