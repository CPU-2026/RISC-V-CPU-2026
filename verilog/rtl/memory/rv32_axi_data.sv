// Software AXIData: read/write streams share EIGHT total line credits.
// D$ has MSHR_DEPTH=4, so at most four reads and four writes are ever live;
// sixteen credits only widened payload storage nobody could fill.
// Each D$ line is eight independent 32b Lite transfers. AW and W advance
// independently, and line completion waits for every R/B, preserving MSHR ID.
module rv32_axi_data (
  input logic clkInput, rstNInput,
  input rv32_pkg::dcache_line_request_output_t requestInput,
  output logic readReadyOutput, writeReadyOutput,
  output rv32_pkg::dcache_line_response_input_t responseOutput,
  input logic responseReadyInput,
  output rv32_pkg::dcache_write_response_input_t writeResponseOutput,
  input logic writeResponseReadyInput,
  input logic exitValidInput,
  input logic [31:0] exitValueInput,
  output logic exitReadyOutput,
  output rv32_pkg::axi_master_t masterOutput,
  input rv32_pkg::axi_slave_t slaveInput
);
  import rv32_pkg::*;
  localparam int DEPTH = 8;
  // The order ring keeps sixteen rows so the 4-bit sequence indices stay in
  // range; at most DEPTH rows are live, so the extra rows are never reused
  // before the head passes them.
  localparam int ORDER_ROWS = 16;
  localparam int WORDS = DCACHE_LINE_BYTES >> 2;
  localparam int WORD_W = $clog2(WORDS)+1;
  localparam int WORD_INDEX_W = $clog2(WORDS);
  typedef struct packed {
    logic [31:0] address;
    logic [1:0] transaction;
    logic [WORD_W-1:0] issued, collected, w;
    logic mmio;
  } entry_t;
  entry_t entriesInner [DEPTH];
  logic [DEPTH-1:0] lineCompleteInner, writeCompleteInner;
  // Classify completion BEFORE the order-ring/descriptor selection. The
  // selected queue head now chooses one bit instead of a multi-bit counter
  // and MMIO flag followed by a late equality comparator. This adds no state
  // and deliberately preserves the old-counter (not current B/R) contract.
  for (genvar slot = 0; slot < DEPTH; slot++) begin : g_completion
    assign lineCompleteInner[slot] = entriesInner[slot].collected == WORD_W'(WORDS);
    assign writeCompleteInner[slot] = entriesInner[slot].mmio ?
      entriesInner[slot].collected == WORD_W'(1) : lineCompleteInner[slot];
  end
  logic [3:0] readOrderInner [ORDER_ROWS], writeOrderInner [ORDER_ROWS];
  wire [3:0] readIssueSlotInner = readOrderInner[readIssueSeqInner[3:0]];
  wire [3:0] readCollectSlotInner = readOrderInner[readCollectSeqInner[3:0]];
  wire [3:0] awIssueSlotInner = writeOrderInner[awIssueSeqInner[3:0]];
  wire [3:0] wIssueSlotInner = writeOrderInner[wIssueSeqInner[3:0]];
  wire [3:0] writeCollectSlotInner = writeOrderInner[writeCollectSeqInner[3:0]];
  localparam int SLOT_W = $clog2(DEPTH);
  logic [SLOT_W-1:0] readHeadOwnerInner, writeHeadOwnerInner;
  // Mirror the ring head at its update edge, avoiding order->descriptor
  // indirection in every completion/payload consumer, including empty state.
  wire [3:0] readHeadSlotInner = 4'(readHeadOwnerInner);
  wire [3:0] writeHeadSlotInner = 4'(writeHeadOwnerInner);
  // DEPTH shared lines, organized by 32-bit word. Payload is deliberately not
  // reset: descriptors gate visibility and every read word is received before
  // a line is exposed. This is register storage, not an SRAM interface change.
  logic [31:0] payloadInner [DEPTH][WORDS];
  logic [DEPTH-1:0] dataBusyInner, allocatedInner, releasedInner;
  logic [3:0] firstFreeInner, secondFreeInner, readSlotInner, writeSlotInner;
  logic firstFreeFoundInner, secondFreeFoundInner;
  logic [3:0] readHeadInner, writeHeadInner;
  logic [4:0] readCountInner, writeCountInner;
  logic [4:0] readTailSeqInner, writeTailSeqInner;
  logic [4:0] readIssueSeqInner, readCollectSeqInner;
  logic [4:0] awIssueSeqInner, wIssueSeqInner, writeCollectSeqInner;
  int readIssueInner, awIssueInner, wIssueInner, readCollectInner, writeCollectInner;
  logic pushReadInner, pushWriteInner, popReadInner, popWriteInner;
  always_comb begin
    firstFreeInner = '0;
    secondFreeInner = '0;
    firstFreeFoundInner = 1'b0;
    secondFreeFoundInner = 1'b0;
    // Only the DEPTH-bit free bitmap is priority encoded; descriptors/payloads are
    // not scanned. Do not recycle a just-consumed slot before old-full gating.
    for (int slot = 0; slot < DEPTH; slot++) begin
      if (!dataBusyInner[slot]) begin
        if (!firstFreeFoundInner) begin
          firstFreeFoundInner = 1'b1;
          firstFreeInner = 4'(slot);
        end else if (!secondFreeFoundInner) begin
          secondFreeFoundInner = 1'b1;
          secondFreeInner = 4'(slot);
        end
      end
    end
    writeSlotInner = firstFreeInner;
    readSlotInner = pushWriteInner ? secondFreeInner : firstFreeInner;
    allocatedInner = '0;
    releasedInner = '0;
    if (pushWriteInner) allocatedInner[writeSlotInner] = 1'b1;
    if (pushReadInner) allocatedInner[readSlotInner] = 1'b1;
    if (popReadInner) releasedInner[readHeadSlotInner] = 1'b1;
    if (popWriteInner) releasedInner[writeHeadSlotInner] = 1'b1;
  end
  always_comb begin
    // Each ordered AXI stream advances only on a completed line. The epoch
    // bit distinguishes full wrap from empty even while replies are held.
    readIssueInner = readIssueSeqInner != readTailSeqInner ? int'(readIssueSeqInner[3:0]) : -1;
    awIssueInner = awIssueSeqInner != writeTailSeqInner ? int'(awIssueSeqInner[3:0]) : -1;
    wIssueInner = wIssueSeqInner != writeTailSeqInner ? int'(wIssueSeqInner[3:0]) : -1;
    readCollectInner = readCollectSeqInner != readTailSeqInner &&
      entriesInner[readCollectSlotInner].collected < entriesInner[readCollectSlotInner].issued ?
      int'(readCollectSeqInner[3:0]) : -1;
    writeCollectInner = writeCollectSeqInner != writeTailSeqInner &&
      entriesInner[writeCollectSlotInner].collected < entriesInner[writeCollectSlotInner].issued &&
      entriesInner[writeCollectSlotInner].collected < entriesInner[writeCollectSlotInner].w ?
      int'(writeCollectSeqInner[3:0]) : -1;
    writeReadyOutput = rstNInput && int'(readCountInner) + int'(writeCountInner) < DEPTH;
    readReadyOutput = rstNInput && int'(readCountInner) + int'(writeCountInner) +
      int'(requestInput.writeValid || exitValidInput) < DEPTH;
    exitReadyOutput = rstNInput && readCountInner == 0 && writeCountInner == 0;
    responseOutput = '{valid:rstNInput && readCountInner != 0 &&
      lineCompleteInner[readHeadSlotInner],
      address:entriesInner[readHeadSlotInner].address, transaction:entriesInner[readHeadSlotInner].transaction,
      data:'0};
    for (int wordIndex = 0; wordIndex < WORDS; wordIndex++)
      if (responseOutput.valid)
        responseOutput.data[wordIndex*32+:32] = payloadInner[readHeadSlotInner][wordIndex];
    writeResponseOutput = '{valid:rstNInput && writeCountInner != 0 &&
      writeCompleteInner[writeHeadSlotInner],
      address:entriesInner[writeHeadSlotInner].address, transaction:entriesInner[writeHeadSlotInner].transaction};
    masterOutput = '0;
    masterOutput.arValid = rstNInput && readIssueInner >= 0;
    masterOutput.arAddr = readIssueInner >= 0 ? entriesInner[readIssueSlotInner].address +
      (32'(entriesInner[readIssueSlotInner].issued) << 2) : 0;
    masterOutput.awValid = rstNInput && awIssueInner >= 0;
    masterOutput.awAddr = awIssueInner >= 0 ? entriesInner[awIssueSlotInner].address +
      (32'(entriesInner[awIssueSlotInner].issued) << 2) : 0;
    masterOutput.wValid = rstNInput && wIssueInner >= 0;
    if (wIssueInner >= 0) begin
      masterOutput.wStrb = 4'hf;
      masterOutput.wData = payloadInner[wIssueSlotInner][entriesInner[wIssueSlotInner].w[WORD_INDEX_W-1:0]];
    end
    masterOutput.rReady = rstNInput;
    masterOutput.bReady = rstNInput;
  end
  assign pushWriteInner = (requestInput.writeValid || exitValidInput) && writeReadyOutput;
  assign pushReadInner = requestInput.readValid && readReadyOutput;
  assign popReadInner = responseOutput.valid && responseReadyInput;
  // The external slave terminates on the exit B handshake. Do not present an
  // MMIO completion to D$ as if it were a dirty-victim MSHR acknowledgement.
  assign popWriteInner = writeResponseOutput.valid && writeResponseReadyInput;
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      readHeadInner <= 0;
      writeHeadInner <= 0;
      readCountInner <= 0;
      writeCountInner <= 0;
      readTailSeqInner <= 0;
      writeTailSeqInner <= 0;
      readIssueSeqInner <= 0;
      readCollectSeqInner <= 0;
      awIssueSeqInner <= 0;
      wIssueSeqInner <= 0;
      writeCollectSeqInner <= 0;
      dataBusyInner <= '0;
      for (int i = 0; i < DEPTH; i++) begin entriesInner[i] <= '0; readOrderInner[i] <= '0; writeOrderInner[i] <= '0; end
    end else begin
      if (masterOutput.arValid && slaveInput.arReady) begin
        entriesInner[readIssueSlotInner].issued <= entriesInner[readIssueSlotInner].issued + 1'b1;
        if (entriesInner[readIssueSlotInner].issued + 1'b1 == WORD_W'(WORDS)) readIssueSeqInner <= readIssueSeqInner + 1'b1;
      end
      if (masterOutput.awValid && slaveInput.awReady) begin
        entriesInner[awIssueSlotInner].issued <= entriesInner[awIssueSlotInner].issued + 1'b1;
        if (entriesInner[awIssueSlotInner].issued + 1'b1 == (entriesInner[awIssueSlotInner].mmio ? WORD_W'(1) : WORD_W'(WORDS)))
          awIssueSeqInner <= awIssueSeqInner + 1'b1;
      end
      if (masterOutput.wValid && slaveInput.wReady) begin
        entriesInner[wIssueSlotInner].w <= entriesInner[wIssueSlotInner].w + 1'b1;
        if (entriesInner[wIssueSlotInner].w + 1'b1 == (entriesInner[wIssueSlotInner].mmio ? WORD_W'(1) : WORD_W'(WORDS)))
          wIssueSeqInner <= wIssueSeqInner + 1'b1;
      end
      if (slaveInput.rValid && readCollectInner >= 0) begin
        entriesInner[readCollectSlotInner].collected <= entriesInner[readCollectSlotInner].collected + 1'b1;
        if (entriesInner[readCollectSlotInner].collected + 1'b1 == WORD_W'(WORDS)) readCollectSeqInner <= readCollectSeqInner + 1'b1;
      end
      if (slaveInput.bValid && writeCollectInner >= 0) begin
        entriesInner[writeCollectSlotInner].collected <= entriesInner[writeCollectSlotInner].collected + 1'b1;
        if (entriesInner[writeCollectSlotInner].collected + 1'b1 ==
            (entriesInner[writeCollectSlotInner].mmio ? WORD_W'(1) : WORD_W'(WORDS)))
          writeCollectSeqInner <= writeCollectSeqInner + 1'b1;
      end
      if (pushReadInner) begin
        readOrderInner[readTailSeqInner[3:0]] <= readSlotInner;
        entriesInner[readSlotInner] <=
          '{address:requestInput.readAddress, transaction:requestInput.readTransaction,
            default:'0};
        readTailSeqInner <= readTailSeqInner + 1'b1;
      end
      if (pushWriteInner) begin
        writeOrderInner[writeTailSeqInner[3:0]] <= writeSlotInner;
        entriesInner[writeSlotInner] <= '{address:exitValidInput ? AXI_EXIT_ADDR : requestInput.writeAddress,
           transaction:requestInput.writeTransaction, mmio:exitValidInput,
           default:'0};
        writeTailSeqInner <= writeTailSeqInner + 1'b1;
      end
      if (popReadInner) readHeadInner <= readHeadInner + 1'b1;
      if (popWriteInner) writeHeadInner <= writeHeadInner + 1'b1;
      readCountInner <= readCountInner + 5'(pushReadInner) - 5'(popReadInner);
      writeCountInner <= writeCountInner + 5'(pushWriteInner) - 5'(popWriteInner);
      dataBusyInner <= (dataBusyInner & ~releasedInner) | allocatedInner;
    end
  end
  // Mirror ownership at the edge which first exposes a head, not a cycle
  // later. A final pop plus enqueue must bypass the old order-ring contents.
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      readHeadOwnerInner <= '0;
      writeHeadOwnerInner <= '0;
    end else begin
      if (pushReadInner && (readCountInner == 0 || (popReadInner && readCountInner == 1)))
        readHeadOwnerInner <= SLOT_W'(readSlotInner);
      else if (popReadInner)
        readHeadOwnerInner <= SLOT_W'(readOrderInner[4'(readHeadInner + 4'd1)]);
      if (pushWriteInner && (writeCountInner == 0 || (popWriteInner && writeCountInner == 1)))
        writeHeadOwnerInner <= SLOT_W'(writeSlotInner);
      else if (popWriteInner)
        writeHeadOwnerInner <= SLOT_W'(writeOrderInner[4'(writeHeadInner + 4'd1)]);
    end
  end
  always_ff @(posedge clkInput) begin
    if (rstNInput) begin
      for (int slot = 0; slot < DEPTH; slot++) begin
        for (int wordIndex = 0; wordIndex < WORDS; wordIndex++) begin
          if (pushWriteInner && writeSlotInner == 4'(slot) && (!exitValidInput || wordIndex == 0))
            payloadInner[slot][wordIndex] <= exitValidInput ? exitValueInput : requestInput.writeData[wordIndex*32+:32];
          else if (slaveInput.rValid && readCollectInner >= 0 &&
              readCollectSlotInner == 4'(slot) &&
              entriesInner[readCollectSlotInner].collected == WORD_W'(wordIndex))
            payloadInner[slot][wordIndex] <= slaveInput.rData;
        end
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    logic [DEPTH-1:0] owners;
    owners = '0;
    assert (4'(readHeadOwnerInner) == readOrderInner[readHeadInner])
      else $fatal(1, "AXI read head owner cache diverged");
    assert (4'(writeHeadOwnerInner) == writeOrderInner[writeHeadInner])
      else $fatal(1, "AXI write head owner cache diverged");
    assert (int'(readCountInner) + int'(writeCountInner) <= DEPTH);
    assert ($countones(dataBusyInner) == int'(readCountInner) + int'(writeCountInner));
    assert (readTailSeqInner[3:0] == 4'(readHeadInner + 4'(readCountInner)));
    assert (writeTailSeqInner[3:0] == 4'(writeHeadInner + 4'(writeCountInner)));
    assert (5'(readTailSeqInner - readIssueSeqInner) <= readCountInner);
    assert (5'(readTailSeqInner - readCollectSeqInner) <= readCountInner);
    assert (5'(writeTailSeqInner - awIssueSeqInner) <= writeCountInner);
    assert (5'(writeTailSeqInner - wIssueSeqInner) <= writeCountInner);
    assert (5'(writeTailSeqInner - writeCollectSeqInner) <= writeCountInner);
    assert (!pushWriteInner || firstFreeFoundInner);
    assert (!pushReadInner || (pushWriteInner ? secondFreeFoundInner : firstFreeFoundInner));
    for (int age = 0; age < DEPTH; age++) begin
      if (age < int'(readCountInner)) begin
        assert (!owners[readOrderInner[4'(readHeadInner + 4'(age))]]);
        owners[readOrderInner[4'(readHeadInner + 4'(age))]] = 1'b1;
      end
      if (age < int'(writeCountInner)) begin
        assert (!owners[writeOrderInner[4'(writeHeadInner + 4'(age))]]);
        owners[writeOrderInner[4'(writeHeadInner + 4'(age))]] = 1'b1;
      end
    end
    assert (owners == dataBusyInner);
    assert (!exitValidInput || (exitReadyOutput && !requestInput.writeValid));
    if (slaveInput.rValid) assert (readCollectInner >= 0 && slaveInput.rResp == 0);
    if (slaveInput.bValid) assert (writeCollectInner >= 0 && slaveInput.bResp == 0);
  end
`endif
endmodule
