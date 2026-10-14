// Software SRAM D$ contract: four ordered requests; only the OLD head queries
// synchronous data/tag+dirty SRAMs and resettable valid registers.
// Fill/Store write wins over the next lookup.
// A Load miss responds once on the first eligible fill beat; its queue head
// remains occupied until the final beat publishes the complete SRAM line.
// No HALT scan. Load transport completions stay ordered, including cancelled
// reads; the LSU's immutable outstanding FIFO owns identity and cancellation.
module rv32_dcache #(
  parameter int unsigned SETS = rv32_pkg::DCACHE_SETS,
  parameter int unsigned WAYS = rv32_pkg::DCACHE_WAYS
) (
  input logic clkInput,
  input logic rstNInput,
  input rv32_pkg::dcache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::dcache_cpu_response_output_t cpuResponseOutput,
  output rv32_pkg::dcache_line_request_output_t memRequestOutput,
  input logic memReadReadyInput,
  input logic memWriteReadyInput,
  input rv32_pkg::dcache_line_response_input_t memResponseInput,
  input logic memWriteDoneInput,
  output logic initializedOutput,
  output logic idleOutput
);
  import rv32_pkg::*;
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned OFFSET_W = $clog2(DCACHE_LINE_BYTES);
  localparam int unsigned TAG_W = 32 - INDEX_W - OFFSET_W;
  localparam int unsigned META_W = TAG_W + 1;
  localparam int unsigned WORD_BYTES = 4;
  localparam int unsigned WORDS_PER_LINE = DCACHE_LINE_BYTES / WORD_BYTES;
  localparam int unsigned FILL_WORDS_PER_BEAT = WORDS_PER_LINE > 1 ? 2 : 1;
  localparam int unsigned WORD_INDEX_W = WORDS_PER_LINE > 1 ? $clog2(WORDS_PER_LINE) : 1;
  localparam int unsigned REQUEST_DEPTH = 4;
  localparam int unsigned REQUEST_W = $clog2(REQUEST_DEPTH);
  // Way identity and tree-PLRU state widths. PLRU is unused for direct
  // mapping; its vector keeps a legal width of at least one bit.
  localparam int unsigned WAY_W = WAYS > 1 ? $clog2(WAYS) : 1;
  localparam int unsigned PLRU_W = WAYS > 2 ? 3 : 1;

  typedef struct packed {
    dcache_cpu_request_input_t request;
    logic [TAG_W-1:0] victimTag;
    logic [WAY_W-1:0] victimWay;
    logic lineValid;
    logic lineDirty;
    logic needMemory;
  } request_entry_t;
  request_entry_t requestInner [REQUEST_DEPTH];
  logic [REQUEST_W-1:0] headInner, tailInner, readIndexInner;
  logic [REQUEST_W:0] countInner;
  logic [OFFSET_W-1:0] readOffsetInner;
  logic [1:0] readSizeInner;
  logic [WORD_INDEX_W-1:0] fillWordInner;
  logic readValidInner, memReadSentInner, memWriteSentInner;
  logic writePendingInner, replyValidInner, loadRespondedInner;
  logic [DCACHE_LINE_BITS-1:0] replyDataInner, victimLineInner;

  // Only validity needs reset. Tag/dirty and data SRAM retain arbitrary contents
  // until written; sample validity on the same edge as the synchronous lookup.
  logic validInner [SETS][WAYS];
  logic [PLRU_W-1:0] plruInner [SETS];
  logic [WAYS-1:0] readWayMaskInner;
  logic metaEnableInner [WAYS], metaWriteInner [WAYS], lookupFireInner;
  logic [INDEX_W-1:0] metaAddressInner, headSetInner;
  logic [31:0] dataRdataBankInner [WAYS][WORDS_PER_LINE];
  logic [31:0] dataWdataBankInner [WAYS][WORDS_PER_LINE];
  logic [3:0] dataMaskBankInner [WAYS][WORDS_PER_LINE];
  logic dataEnableBankInner [WAYS][WORDS_PER_LINE];
  logic dataWriteBankInner [WAYS][WORDS_PER_LINE];
  logic [DCACHE_LINE_BITS-1:0] dataRdataInner;
  logic [META_W-1:0] metaRdataInner [WAYS], metaWdataInner;
  logic [WAY_W-1:0] hitWayInner, missVictimInner, headWayInner;
  logic hitAnyInner;
  logic acceptInner, popInner, headHitInner, storeWriteInner;
  logic headNeedMemoryInner, headDirtyInner;
  logic readFireInner, writeFireInner, writeCompleteInner;
  logic fillBeatInner, fillLastInner, fillFireInner, fillLoadReadyInner;
  logic [DCACHE_LINE_BITS-1:0] fillDataInner;
  logic [31:0] hitRawInner, fillRawInner;

  function automatic int unsigned bytes_for_size(input logic [1:0] sizeInput);
    case (sizeInput)
      MEM_BYTE: return 1;
      MEM_HALF: return 2;
      default: return 4;
    endcase
  endfunction

  function automatic logic [31:0] extract_raw(
    input logic [DCACHE_LINE_BITS-1:0] lineInput,
    input logic [OFFSET_W-1:0] offsetInput,
    input logic [1:0] sizeInput
  );
    logic [DCACHE_LINE_BITS-1:0] shifted;
    begin
      shifted = lineInput >> (32'(offsetInput) << 3);
      case (sizeInput)
        MEM_BYTE: return {24'b0, shifted[7:0]};
        MEM_HALF: return {16'b0, shifted[15:0]};
        default: return shifted[31:0];
      endcase
    end
  endfunction

  // Tree-PLRU victim: 2-way keeps the MRU way in bit0; 4-way keeps the MRU
  // direction in bit2 (root), bit1 (left), bit0 (right), where a set bit
  // means the right child is more recent. Multi-way arms are dead for
  // direct mapping but kept in one shared implementation.
  /* verilator lint_off SELRANGE */
  /* verilator lint_off WIDTHTRUNC */
  function automatic logic [WAY_W-1:0] plru_victim(
    input logic [PLRU_W-1:0] plruBits
  );
    logic sub;
    begin
      if (WAYS == 2) return plruBits[0] ? WAY_W'(0) : WAY_W'(1);
      if (WAYS == 4) begin
        sub = plruBits[2] ? plruBits[1] : plruBits[0];
        return {~plruBits[2], ~sub};
      end
      return '0;
    end
  endfunction

  function automatic logic [PLRU_W-1:0] plru_touch(
    input logic [PLRU_W-1:0] plruBits,
    input logic [WAY_W-1:0] wayInput
  );
    begin
      if (WAYS == 2) return PLRU_W'(wayInput[0]);
      if (WAYS == 4) begin
        if (wayInput[1]) return {wayInput[1], plruBits[1], wayInput[0]};
        else return {wayInput[1], wayInput[0], plruBits[0]};
      end
      return '0;
    end
  endfunction

  // Miss victim: lowest-index invalid way first, else the tree-PLRU victim.
  /* verilator lint_on SELRANGE */
  /* verilator lint_on WIDTHTRUNC */
  function automatic logic [WAY_W-1:0] select_victim(
    input logic [INDEX_W-1:0] setInput
  );
    begin
      for (int w = 0; w < WAYS; w = w + 1)
        if (!validInner[setInput][w]) return WAY_W'(w);
      return plru_victim(plruInner[setInput]);
    end
  endfunction

  // Compatibility observation: there is no SRAM initialization phase.
  assign initializedOutput = rstNInput;
  assign cpuReqReadyOutput = rstNInput && countInner < (REQUEST_W+1)'(REQUEST_DEPTH);
  assign acceptInner = cpuRequestInput.valid && cpuReqReadyOutput;
  assign tailInner = headInner + countInner[REQUEST_W-1:0];
  assign headSetInner = requestInner[headInner].request.address[INDEX_W+OFFSET_W-1:OFFSET_W];
  assign missVictimInner = select_victim(headSetInner);
  always_comb begin
    hitWayInner = '0;
    hitAnyInner = 1'b0;
    for (int w = 0; w < WAYS; w = w + 1)
      if (readValidInner && readWayMaskInner[w] &&
          metaRdataInner[w][TAG_W-1:0] == requestInner[readIndexInner].request.address[31:INDEX_W+OFFSET_W]) begin
        hitWayInner = WAY_W'(w);
        hitAnyInner = 1'b1;
      end
  end
  assign headHitInner = countInner != 0 && readValidInner && readIndexInner == headInner &&
    hitAnyInner;
  // Store hits use the combinational hit way in the same cycle the lookup
  // result arrives; the recorded victim way only serves later refills.
  assign headWayInner = headHitInner ? hitWayInner : requestInner[headInner].victimWay;
  assign storeWriteInner = headHitInner && requestInner[headInner].request.write;
  assign headNeedMemoryInner = countInner != 0 && requestInner[headInner].needMemory;
  assign headDirtyInner = headNeedMemoryInner && requestInner[headInner].lineValid &&
    requestInner[headInner].lineDirty;
  assign readFireInner = memRequestOutput.readValid && memReadReadyInput;
  assign writeFireInner = memRequestOutput.writeValid && memWriteReadyInput;
  assign writeCompleteInner = memWriteDoneInput && (writePendingInner || writeFireInner);
  // A registered response from the environment is already the software's old
  // DMEM reply. Bypass it into the fill; cache it only if writeback still waits.
  assign fillBeatInner = headNeedMemoryInner && memReadSentInner &&
    (replyValidInner || memResponseInput.valid) &&
    (!headDirtyInner || (memWriteSentInner && (!writePendingInner || writeCompleteInner)));
  assign fillDataInner = replyValidInner ? replyDataInner : memResponseInput.data;
  assign fillLastInner = fillWordInner == WORD_INDEX_W'(WORDS_PER_LINE - FILL_WORDS_PER_BEAT);
  assign fillFireInner = fillBeatInner && fillLastInner;
  assign fillLoadReadyInner = fillBeatInner && !loadRespondedInner &&
    !requestInner[headInner].request.write;
  assign popInner = headHitInner || fillFireInner;
  assign hitRawInner = extract_raw(dataRdataInner, readOffsetInner, readSizeInner);
  assign fillRawInner = extract_raw(fillDataInner,
    requestInner[headInner].request.address[OFFSET_W-1:0], requestInner[headInner].request.size);
  assign cpuResponseOutput = '{
    valid: rstNInput && countInner != 0 && !requestInner[headInner].request.write &&
      (headHitInner || fillLoadReadyInner),
    // Select the data source independently of the high-fanout fill enable.
    // Valid hits cannot needMemory; valid miss responses always needMemory.
    // Payload is unspecified when valid=0, so eligibility only gates valid.
    readData: headNeedMemoryInner ? fillRawInner : hitRawInner
  };
  assign memRequestOutput = '{
    readValid: rstNInput && headNeedMemoryInner && !memReadSentInner,
    readAddress: {requestInner[headInner].request.address[31:OFFSET_W], {OFFSET_W{1'b0}}},
    writeValid: rstNInput && headDirtyInner && !memWriteSentInner,
    writeAddress: {requestInner[headInner].victimTag, headSetInner, {OFFSET_W{1'b0}}},
    writeData: victimLineInner
  };
  assign idleOutput = rstNInput && countInner == 0 && !readValidInner &&
    !memReadSentInner && !writePendingInner && !replyValidInner;

  always_comb begin
    int unsigned byteCount;
    int unsigned globalByte;
    for (int w = 0; w < WAYS; w = w + 1) begin
      metaEnableInner[w] = 1'b0;
      metaWriteInner[w] = 1'b0;
    end
    metaAddressInner = headSetInner;
    metaWdataInner = '0;
    byteCount = 0;
    globalByte = 0;
    for (int w = 0; w < WAYS; w = w + 1) begin
      for (int b = 0; b < WORDS_PER_LINE; b = b + 1) begin
        dataEnableBankInner[w][b] = 1'b0;
        dataWriteBankInner[w][b] = 1'b0;
        dataWdataBankInner[w][b] = '0;
        dataMaskBankInner[w][b] = '0;
      end
    end
    if (rstNInput) begin
      if (fillBeatInner) begin
        byteCount = bytes_for_size(requestInner[headInner].request.size);
        for (int b = 0; b < WORDS_PER_LINE; b = b + 1) begin
          if (b >= int'(fillWordInner) && b < int'(fillWordInner) + FILL_WORDS_PER_BEAT) begin
            dataEnableBankInner[headWayInner][b] = 1'b1;
            dataWriteBankInner[headWayInner][b] = 1'b1;
            dataWdataBankInner[headWayInner][b] = fillDataInner[(b * 32) +: 32];
            dataMaskBankInner[headWayInner][b] = 4'b1111;
            if (requestInner[headInner].request.write) begin
              for (int i = 0; i < WORD_BYTES; i = i + 1) begin
                if (i < byteCount && requestInner[headInner].request.writeStrobe[i]) begin
                  globalByte = int'(requestInner[headInner].request.address[OFFSET_W-1:0]) + i;
                  if ((globalByte >> 2) == b) begin
                    dataWdataBankInner[headWayInner][b][((globalByte & 3) * 8) +: 8] =
                      requestInner[headInner].request.writeData[(i * 8) +: 8];
                  end
                end
              end
            end
          end
        end
        if (fillFireInner) begin
          metaEnableInner[headWayInner] = 1'b1;
          metaWriteInner[headWayInner] = 1'b1;
          metaWdataInner = {requestInner[headInner].request.write,
            requestInner[headInner].request.address[31:INDEX_W+OFFSET_W]};
        end
      end else if (storeWriteInner) begin
        byteCount = bytes_for_size(requestInner[headInner].request.size);
        for (int i = 0; i < WORD_BYTES; i = i + 1) begin
          if (i < byteCount && requestInner[headInner].request.writeStrobe[i]) begin
            globalByte = int'(requestInner[headInner].request.address[OFFSET_W-1:0]) + i;
            if (globalByte < DCACHE_LINE_BYTES) begin
              dataEnableBankInner[headWayInner][globalByte >> 2] = 1'b1;
              dataWriteBankInner[headWayInner][globalByte >> 2] = 1'b1;
              dataMaskBankInner[headWayInner][globalByte >> 2][globalByte & 3] = 1'b1;
              dataWdataBankInner[headWayInner][globalByte >> 2][((globalByte & 3) * 8) +: 8] =
                requestInner[headInner].request.writeData[(i * 8) +: 8];
            end
          end
        end
        metaEnableInner[headWayInner] = 1'b1;
        metaWriteInner[headWayInner] = 1'b1;
        metaWdataInner = {requestInner[headInner].request.write,
          requestInner[headInner].request.address[31:INDEX_W+OFFSET_W]};
      end else if (countInner != 0 && !readValidInner && !headNeedMemoryInner) begin
        for (int w = 0; w < WAYS; w = w + 1) begin
          for (int b = 0; b < WORDS_PER_LINE; b = b + 1)
            dataEnableBankInner[w][b] = 1'b1;
          metaEnableInner[w] = 1'b1;
        end
      end
    end
  end
  assign lookupFireInner = countInner != 0 && !readValidInner && !headNeedMemoryInner &&
    rstNInput && !fillBeatInner && !storeWriteInner;
  // dataRdataInner follows the hit way for Load responses and the selected
  // victim way while a miss result is saved; exactly one of the two selects.
  always_comb begin
    for (int b = 0; b < WORDS_PER_LINE; b = b + 1)
      dataRdataInner[(b * 32) +: 32] =
        dataRdataBankInner[headHitInner ? hitWayInner : missVictimInner][b];
  end
  for (genvar w = 0; w < WAYS; w = w + 1) begin : g_way
    for (genvar b = 0; b < WORDS_PER_LINE; b = b + 1) begin : g_data_bank
      sram_fakeram #(.DEPTH(SETS), .WIDTH(32), .WRITE_GRANULARITY(8)) u_data (
        .clk(clkInput), .en(dataEnableBankInner[w][b]), .we(dataWriteBankInner[w][b]), .addr(headSetInner),
        .wdata(dataWdataBankInner[w][b]), .wmask(dataMaskBankInner[w][b]), .rdata(dataRdataBankInner[w][b])
      );
    end
    sram_fakeram #(.DEPTH(SETS), .WIDTH(META_W), .WRITE_GRANULARITY(META_W)) u_metadata (
      .clk(clkInput), .en(metaEnableInner[w]), .we(metaWriteInner[w]), .addr(metaAddressInner),
      .wdata(metaWdataInner), .wmask(1'b1), .rdata(metaRdataInner[w])
    );
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (int s = 0; s < SETS; s = s + 1) begin
        for (int w = 0; w < WAYS; w = w + 1) validInner[s][w] <= 1'b0;
        plruInner[s] <= '0;
      end
      readWayMaskInner <= '0;
      headInner <= '0;
      countInner <= '0;
      readValidInner <= 1'b0;
      readIndexInner <= '0;
      readOffsetInner <= '0;
      readSizeInner <= MEM_WORD;
      fillWordInner <= '0;
      memReadSentInner <= 1'b0;
      memWriteSentInner <= 1'b0;
      writePendingInner <= 1'b0;
      replyValidInner <= 1'b0;
      loadRespondedInner <= 1'b0;
      replyDataInner <= '0;
      victimLineInner <= '0;
      for (int i = 0; i < REQUEST_DEPTH; i = i + 1) requestInner[i] <= '0;
    end else begin
      // A partially overwritten victim is not a valid old line either.
      // Publish validity only after every bank has been refilled.
      if (fillBeatInner) validInner[headSetInner][requestInner[headInner].victimWay] <= fillLastInner;
      readValidInner <= lookupFireInner;
      if (lookupFireInner) begin
        for (int w = 0; w < WAYS; w = w + 1)
          readWayMaskInner[w] <= validInner[headSetInner][w];
        readIndexInner <= headInner;
        readOffsetInner <= requestInner[headInner].request.address[OFFSET_W-1:0];
        readSizeInner <= requestInner[headInner].request.size;
      end
      // A hit access refreshes replacement state even when its slot retires
      // on the same cycle; the set-level recency outlives the queue entry.
      // The hit way is recorded for a following Store hit update.
      if (readValidInner && headHitInner) begin
        plruInner[headSetInner] <= plru_touch(plruInner[headSetInner], hitWayInner);
        requestInner[headInner].victimWay <= hitWayInner;
      end
      if (readValidInner && !headHitInner) begin
        requestInner[headInner].victimTag <= readWayMaskInner[missVictimInner] ?
          metaRdataInner[missVictimInner][TAG_W-1:0] : '0;
        requestInner[headInner].victimWay <= missVictimInner;
        requestInner[headInner].lineValid <= readWayMaskInner[missVictimInner];
        requestInner[headInner].lineDirty <= readWayMaskInner[missVictimInner] &&
          metaRdataInner[missVictimInner][TAG_W];
        requestInner[headInner].needMemory <= 1'b1;
        victimLineInner <= dataRdataInner;
      end
      if (popInner) begin
        // A completed refill installs its victim way as most-recently-used.
        if (fillFireInner)
          plruInner[headSetInner] <= plru_touch(plruInner[headSetInner],
            requestInner[headInner].victimWay);
        requestInner[headInner].needMemory <= 1'b0;
        headInner <= headInner + 1'b1;
        fillWordInner <= '0;
        memReadSentInner <= 1'b0;
        memWriteSentInner <= 1'b0;
        writePendingInner <= 1'b0;
        replyValidInner <= 1'b0;
        loadRespondedInner <= 1'b0;
      end else begin
        if (fillLoadReadyInner) loadRespondedInner <= 1'b1;
        if (readFireInner) memReadSentInner <= 1'b1;
        if (writeFireInner) begin
          memWriteSentInner <= 1'b1;
          writePendingInner <= !writeCompleteInner;
        end
        if (writeCompleteInner) writePendingInner <= 1'b0;
        if (fillBeatInner && !fillLastInner)
          fillWordInner <= fillWordInner + WORD_INDEX_W'(FILL_WORDS_PER_BEAT);
        if (memResponseInput.valid && memReadSentInner && !replyValidInner) begin
          replyValidInner <= 1'b1;
          replyDataInner <= memResponseInput.data;
        end
      end
      if (acceptInner) requestInner[tailInner] <= '{request:cpuRequestInput, default:'0};
      case ({acceptInner, popInner})
        2'b10: countInner <= countInner + 1'b1;
        2'b01: countInner <= countInner - 1'b1;
        default: ;
      endcase
    end
  end

`ifndef SYNTHESIS
  initial begin
    assert ((WAYS == 1 || WAYS == 2 || WAYS == 4) && SETS > 1 && (SETS & (SETS-1)) == 0 &&
            WORDS_PER_LINE > 0 && WORDS_PER_LINE * WORD_BYTES == DCACHE_LINE_BYTES &&
            (WORDS_PER_LINE == 1 || (WORDS_PER_LINE & (WORDS_PER_LINE-1)) == 0) &&
            (WORDS_PER_LINE <= 2 || WORDS_PER_LINE % FILL_WORDS_PER_BEAT == 0))
      else $fatal(1, "SRAM DCache requires 1/2/4 ways and power-of-two rows");
  end
  always @(posedge clkInput) if (rstNInput) begin
    assert (countInner <= (REQUEST_W+1)'(REQUEST_DEPTH));
    if (readValidInner) assert (countInner != 0 && readIndexInner == headInner);
    if (readValidInner && !(|readWayMaskInner)) assert (!headHitInner);
    if (readValidInner && headHitInner) begin
      int matchCount;
      matchCount = 0;
      for (int w = 0; w < WAYS; w = w + 1)
        if (readWayMaskInner[w] &&
            metaRdataInner[w][TAG_W-1:0] == requestInner[readIndexInner].request.address[31:INDEX_W+OFFSET_W])
          matchCount = matchCount + 1;
      assert (matchCount == 1);
    end
    for (int w = 0; w < WAYS; w = w + 1)
      if (metaWriteInner[w]) assert (fillFireInner || storeWriteInner);
    if (fillBeatInner) begin
      assert (int'(fillWordInner) + FILL_WORDS_PER_BEAT <= WORDS_PER_LINE);
      for (int w = 0; w < WAYS; w = w + 1) begin
        for (int b = 0; b < WORDS_PER_LINE; b = b + 1)
          assert (dataEnableBankInner[w][b] ==
            (w == int'(requestInner[headInner].victimWay) &&
             b >= int'(fillWordInner) && b < int'(fillWordInner) + FILL_WORDS_PER_BEAT));
        assert (metaEnableInner[w] == (fillLastInner && w == int'(requestInner[headInner].victimWay)) &&
          metaWriteInner[w] == (fillLastInner && w == int'(requestInner[headInner].victimWay)));
      end
      assert (popInner == fillLastInner);
      if (fillLoadReadyInner) assert (fillWordInner == '0);
      if (loadRespondedInner) assert (!cpuResponseOutput.valid);
    end
    if (acceptInner) begin
      assert (cpuRequestInput.size <= MEM_WORD);
      assert (32'(cpuRequestInput.address[OFFSET_W-1:0]) +
        32'(bytes_for_size(cpuRequestInput.size)) <= DCACHE_LINE_BYTES);
    end
  end
`endif
endmodule
