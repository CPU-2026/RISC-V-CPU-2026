// Software SRAM D$ contract: four ordered requests; only the OLD head queries
// synchronous data/tag+dirty SRAMs and resettable valid registers.
// Fill/Store write wins over the next lookup.
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
  input rv32_pkg::cache_line_response_input_t memResponseInput,
  input logic memWriteDoneInput,
  output logic initializedOutput,
  output logic idleOutput
);
  import rv32_pkg::*;
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned OFFSET_W = $clog2(CACHE_LINE_BYTES);
  localparam int unsigned TAG_W = 32 - INDEX_W - OFFSET_W;
  localparam int unsigned META_W = TAG_W + 1;
  localparam int unsigned WORD_BYTES = 4;
  localparam int unsigned WORDS_PER_LINE = CACHE_LINE_BYTES / WORD_BYTES;
  localparam int unsigned FILL_WORDS_PER_BEAT = WORDS_PER_LINE > 1 ? 2 : 1;
  localparam int unsigned WORD_INDEX_W = WORDS_PER_LINE > 1 ? $clog2(WORDS_PER_LINE) : 1;
  localparam int unsigned REQUEST_DEPTH = 4;
  localparam int unsigned REQUEST_W = $clog2(REQUEST_DEPTH);

  typedef struct packed {
    dcache_cpu_request_input_t request;
    logic [TAG_W-1:0] victimTag;
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
  logic writePendingInner, replyValidInner;
  logic [CACHE_LINE_BITS-1:0] replyDataInner, victimLineInner;

  // Only validity needs reset. Tag/dirty and data SRAM retain arbitrary contents
  // until written; sample validity on the same edge as the synchronous lookup.
  logic validInner [SETS];
  logic readLineValidInner;
  logic metaEnableInner, metaWriteInner, lookupFireInner;
  logic [INDEX_W-1:0] metaAddressInner, headSetInner;
  logic [31:0] dataRdataBankInner [WORDS_PER_LINE];
  logic [31:0] dataWdataBankInner [WORDS_PER_LINE];
  logic [3:0] dataMaskBankInner [WORDS_PER_LINE];
  logic dataEnableBankInner [WORDS_PER_LINE];
  logic dataWriteBankInner [WORDS_PER_LINE];
  logic [CACHE_LINE_BITS-1:0] dataRdataInner;
  logic [META_W-1:0] metaRdataInner, metaWdataInner;
  logic acceptInner, popInner, headHitInner, storeWriteInner;
  logic headNeedMemoryInner, headDirtyInner;
  logic readFireInner, writeFireInner, writeCompleteInner;
  logic fillBeatInner, fillLastInner, fillFireInner;
  logic [CACHE_LINE_BITS-1:0] fillDataInner;
  logic [31:0] hitRawInner, fillRawInner;

  function automatic int unsigned bytes_for_size(input logic [1:0] sizeInput);
    case (sizeInput)
      MEM_BYTE: return 1;
      MEM_HALF: return 2;
      default: return 4;
    endcase
  endfunction

  function automatic logic [31:0] extract_raw(
    input logic [CACHE_LINE_BITS-1:0] lineInput,
    input logic [OFFSET_W-1:0] offsetInput,
    input logic [1:0] sizeInput
  );
    logic [CACHE_LINE_BITS-1:0] shifted;
    begin
      shifted = lineInput >> (32'(offsetInput) << 3);
      case (sizeInput)
        MEM_BYTE: return {24'b0, shifted[7:0]};
        MEM_HALF: return {16'b0, shifted[15:0]};
        default: return shifted[31:0];
      endcase
    end
  endfunction

  // Compatibility observation: there is no SRAM initialization phase.
  assign initializedOutput = rstNInput;
  assign cpuReqReadyOutput = rstNInput && countInner < (REQUEST_W+1)'(REQUEST_DEPTH);
  assign acceptInner = cpuRequestInput.valid && cpuReqReadyOutput;
  assign tailInner = headInner + countInner[REQUEST_W-1:0];
  assign headSetInner = requestInner[headInner].request.address[INDEX_W+OFFSET_W-1:OFFSET_W];
  assign headHitInner = countInner != 0 && readValidInner && readIndexInner == headInner &&
    readLineValidInner &&
    metaRdataInner[TAG_W-1:0] == requestInner[headInner].request.address[31:INDEX_W+OFFSET_W];
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
  assign popInner = headHitInner || fillFireInner;
  assign hitRawInner = extract_raw(dataRdataInner, readOffsetInner, readSizeInner);
  assign fillRawInner = extract_raw(fillDataInner,
    requestInner[headInner].request.address[OFFSET_W-1:0], requestInner[headInner].request.size);
  assign cpuResponseOutput = '{
    valid: rstNInput && countInner != 0 && !requestInner[headInner].request.write && popInner,
    readData: fillFireInner ? fillRawInner : hitRawInner
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
    metaEnableInner = 1'b0;
    metaWriteInner = 1'b0;
    metaAddressInner = headSetInner;
    metaWdataInner = '0;
    byteCount = 0;
    globalByte = 0;
    for (int b = 0; b < WORDS_PER_LINE; b = b + 1) begin
      dataEnableBankInner[b] = 1'b0;
      dataWriteBankInner[b] = 1'b0;
      dataWdataBankInner[b] = '0;
      dataMaskBankInner[b] = '0;
    end
    if (rstNInput) begin
      if (fillBeatInner) begin
        byteCount = bytes_for_size(requestInner[headInner].request.size);
        for (int b = 0; b < WORDS_PER_LINE; b = b + 1) begin
          if (b >= int'(fillWordInner) && b < int'(fillWordInner) + FILL_WORDS_PER_BEAT) begin
            dataEnableBankInner[b] = 1'b1;
            dataWriteBankInner[b] = 1'b1;
            dataWdataBankInner[b] = fillDataInner[(b * 32) +: 32];
            dataMaskBankInner[b] = 4'b1111;
            if (requestInner[headInner].request.write) begin
              for (int i = 0; i < WORD_BYTES; i = i + 1) begin
                if (i < byteCount && requestInner[headInner].request.writeStrobe[i]) begin
                  globalByte = int'(requestInner[headInner].request.address[OFFSET_W-1:0]) + i;
                  if ((globalByte >> 2) == b) begin
                    dataWdataBankInner[b][((globalByte & 3) * 8) +: 8] =
                      requestInner[headInner].request.writeData[(i * 8) +: 8];
                  end
                end
              end
            end
          end
        end
        if (fillFireInner) begin
          metaEnableInner = 1'b1;
          metaWriteInner = 1'b1;
          metaWdataInner = {requestInner[headInner].request.write,
            requestInner[headInner].request.address[31:INDEX_W+OFFSET_W]};
        end
      end else if (storeWriteInner) begin
        byteCount = bytes_for_size(requestInner[headInner].request.size);
        for (int i = 0; i < WORD_BYTES; i = i + 1) begin
          if (i < byteCount && requestInner[headInner].request.writeStrobe[i]) begin
            globalByte = int'(requestInner[headInner].request.address[OFFSET_W-1:0]) + i;
            if (globalByte < CACHE_LINE_BYTES) begin
              dataEnableBankInner[globalByte >> 2] = 1'b1;
              dataWriteBankInner[globalByte >> 2] = 1'b1;
              dataMaskBankInner[globalByte >> 2][globalByte & 3] = 1'b1;
              dataWdataBankInner[globalByte >> 2][((globalByte & 3) * 8) +: 8] =
                requestInner[headInner].request.writeData[(i * 8) +: 8];
            end
          end
        end
        metaEnableInner = 1'b1;
        metaWriteInner = 1'b1;
        metaWdataInner = {requestInner[headInner].request.write,
          requestInner[headInner].request.address[31:INDEX_W+OFFSET_W]};
      end else if (countInner != 0 && !readValidInner && !headNeedMemoryInner) begin
        for (int b = 0; b < WORDS_PER_LINE; b = b + 1)
          dataEnableBankInner[b] = 1'b1;
        metaEnableInner = 1'b1;
      end
    end
  end
  assign lookupFireInner = countInner != 0 && !readValidInner && !headNeedMemoryInner &&
    rstNInput && !fillBeatInner && !storeWriteInner;
  for (genvar b = 0; b < WORDS_PER_LINE; b = b + 1) begin : g_data_bank
    assign dataRdataInner[(b * 32) +: 32] = dataRdataBankInner[b];
    sram_fakeram #(.DEPTH(SETS), .WIDTH(32), .WRITE_GRANULARITY(8)) u_data (
      .clk(clkInput), .en(dataEnableBankInner[b]), .we(dataWriteBankInner[b]), .addr(headSetInner),
      .wdata(dataWdataBankInner[b]), .wmask(dataMaskBankInner[b]), .rdata(dataRdataBankInner[b])
    );
  end
  sram_fakeram #(.DEPTH(SETS), .WIDTH(META_W), .WRITE_GRANULARITY(META_W)) u_metadata (
    .clk(clkInput), .en(metaEnableInner), .we(metaWriteInner), .addr(metaAddressInner),
    .wdata(metaWdataInner), .wmask(1'b1), .rdata(metaRdataInner)
  );

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (int s = 0; s < SETS; s = s + 1) validInner[s] <= 1'b0;
      readLineValidInner <= 1'b0;
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
      replyDataInner <= '0;
      victimLineInner <= '0;
      for (int i = 0; i < REQUEST_DEPTH; i = i + 1) requestInner[i] <= '0;
    end else begin
      if (fillFireInner) validInner[headSetInner] <= 1'b1;
      readValidInner <= lookupFireInner;
      if (lookupFireInner) begin
        readLineValidInner <= validInner[headSetInner];
        readIndexInner <= headInner;
        readOffsetInner <= requestInner[headInner].request.address[OFFSET_W-1:0];
        readSizeInner <= requestInner[headInner].request.size;
      end
      if (readValidInner && !headHitInner) begin
        requestInner[headInner].victimTag <= readLineValidInner ? metaRdataInner[TAG_W-1:0] : '0;
        requestInner[headInner].lineValid <= readLineValidInner;
        requestInner[headInner].lineDirty <= readLineValidInner && metaRdataInner[TAG_W];
        requestInner[headInner].needMemory <= 1'b1;
        victimLineInner <= dataRdataInner;
      end
      if (popInner) begin
        requestInner[headInner].needMemory <= 1'b0;
        headInner <= headInner + 1'b1;
        fillWordInner <= '0;
        memReadSentInner <= 1'b0;
        memWriteSentInner <= 1'b0;
        writePendingInner <= 1'b0;
        replyValidInner <= 1'b0;
      end else begin
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
    assert (WAYS == 1 && SETS > 1 && (SETS & (SETS-1)) == 0 &&
            WORDS_PER_LINE > 0 && WORDS_PER_LINE * WORD_BYTES == CACHE_LINE_BYTES &&
            (WORDS_PER_LINE == 1 || (WORDS_PER_LINE & (WORDS_PER_LINE-1)) == 0) &&
            (WORDS_PER_LINE <= 2 || WORDS_PER_LINE % FILL_WORDS_PER_BEAT == 0))
      else $fatal(1, "SRAM DCache requires direct mapping and power-of-two rows");
  end
  always @(posedge clkInput) if (rstNInput) begin
    assert (countInner <= (REQUEST_W+1)'(REQUEST_DEPTH));
    if (readValidInner) assert (countInner != 0 && readIndexInner == headInner);
    if (readValidInner && !readLineValidInner) assert (!headHitInner);
    if (metaWriteInner) assert (fillFireInner || storeWriteInner);
    if (fillBeatInner) begin
      assert (int'(fillWordInner) + FILL_WORDS_PER_BEAT <= WORDS_PER_LINE);
      for (int b = 0; b < WORDS_PER_LINE; b = b + 1)
        assert (dataEnableBankInner[b] ==
          (b >= int'(fillWordInner) && b < int'(fillWordInner) + FILL_WORDS_PER_BEAT));
      assert (metaEnableInner == fillLastInner && metaWriteInner == fillLastInner);
      assert (popInner == fillLastInner);
    end
    if (acceptInner) begin
      assert (cpuRequestInput.size <= MEM_WORD);
      assert (32'(cpuRequestInput.address[OFFSET_W-1:0]) +
        32'(bytes_for_size(cpuRequestInput.size)) <= CACHE_LINE_BYTES);
    end
  end
`endif
endmodule
