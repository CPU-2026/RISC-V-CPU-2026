// Software AXIData: read/write streams share SIXTEEN total line credits.
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
  localparam int DEPTH = 16;
  localparam int WORDS = DCACHE_LINE_BYTES >> 2;
  localparam int WORD_W = $clog2(WORDS)+1;
  typedef struct packed {
    logic [DCACHE_LINE_BITS-1:0] bytes;
    logic [31:0] address;
    logic [1:0] transaction;
    logic [WORD_W-1:0] issued, collected, aw, w;
    logic mmio;
  } entry_t;
  entry_t readsInner [DEPTH], writesInner [DEPTH];
  logic [3:0] readHeadInner, writeHeadInner;
  logic [4:0] readCountInner, writeCountInner;
  int readIssueInner, awIssueInner, wIssueInner, readCollectInner, writeCollectInner;
  logic pushReadInner, pushWriteInner, popReadInner, popWriteInner;
  always_comb begin
    int rslot, wslot;
    readIssueInner = -1;
    awIssueInner = -1;
    wIssueInner = -1;
    readCollectInner = -1;
    writeCollectInner = -1;
    for (int age = 0; age < DEPTH; age++) begin
      rslot = (int'(readHeadInner) + age) & 15;
      wslot = (int'(writeHeadInner) + age) & 15;
      if (age < int'(readCountInner)) begin
        if (readIssueInner < 0 && readsInner[rslot].issued < WORD_W'(WORDS)) readIssueInner = rslot;
        if (readCollectInner < 0 && readsInner[rslot].collected < readsInner[rslot].issued) readCollectInner = rslot;
      end
      if (age < int'(writeCountInner)) begin
        if (awIssueInner < 0 && writesInner[wslot].aw < (writesInner[wslot].mmio ? WORD_W'(1) : WORD_W'(WORDS))) awIssueInner = wslot;
        if (wIssueInner < 0 && writesInner[wslot].w < (writesInner[wslot].mmio ? WORD_W'(1) : WORD_W'(WORDS))) wIssueInner = wslot;
        if (writeCollectInner < 0 && writesInner[wslot].collected < writesInner[wslot].aw &&
            writesInner[wslot].collected < writesInner[wslot].w) writeCollectInner = wslot;
      end
    end
    writeReadyOutput = rstNInput && int'(readCountInner) + int'(writeCountInner) < DEPTH;
    readReadyOutput = rstNInput && int'(readCountInner) + int'(writeCountInner) +
      int'(requestInput.writeValid || exitValidInput) < DEPTH;
    exitReadyOutput = rstNInput && readCountInner == 0 && writeCountInner == 0;
    responseOutput = '{valid:rstNInput && readCountInner != 0 &&
      readsInner[readHeadInner].collected == WORD_W'(WORDS),
      address:readsInner[readHeadInner].address, transaction:readsInner[readHeadInner].transaction,
      data:readsInner[readHeadInner].bytes};
    writeResponseOutput = '{valid:rstNInput && writeCountInner != 0 &&
      writesInner[writeHeadInner].collected == (writesInner[writeHeadInner].mmio ? WORD_W'(1) : WORD_W'(WORDS)),
      address:writesInner[writeHeadInner].address, transaction:writesInner[writeHeadInner].transaction};
    masterOutput = '0;
    masterOutput.arValid = rstNInput && readIssueInner >= 0;
    masterOutput.arAddr = readIssueInner >= 0 ? readsInner[readIssueInner].address +
      (32'(readsInner[readIssueInner].issued) << 2) : 0;
    masterOutput.awValid = rstNInput && awIssueInner >= 0;
    masterOutput.awAddr = awIssueInner >= 0 ? writesInner[awIssueInner].address +
      (32'(writesInner[awIssueInner].aw) << 2) : 0;
    masterOutput.wValid = rstNInput && wIssueInner >= 0;
    if (wIssueInner >= 0) begin
      masterOutput.wStrb = 4'hf;
      masterOutput.wData = 32'(writesInner[wIssueInner].bytes >> (int'(writesInner[wIssueInner].w) << 5));
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
      for (int i = 0; i < DEPTH; i++) begin readsInner[i] <= '0; writesInner[i] <= '0; end
    end else begin
      if (masterOutput.arValid && slaveInput.arReady) readsInner[readIssueInner].issued <= readsInner[readIssueInner].issued + 1'b1;
      if (masterOutput.awValid && slaveInput.awReady) writesInner[awIssueInner].aw <= writesInner[awIssueInner].aw + 1'b1;
      if (masterOutput.wValid && slaveInput.wReady) writesInner[wIssueInner].w <= writesInner[wIssueInner].w + 1'b1;
      if (slaveInput.rValid && readCollectInner >= 0) begin
        readsInner[readCollectInner].bytes[int'(readsInner[readCollectInner].collected)*32+:32] <= slaveInput.rData;
        readsInner[readCollectInner].collected <= readsInner[readCollectInner].collected + 1'b1;
      end
      if (slaveInput.bValid && writeCollectInner >= 0)
        writesInner[writeCollectInner].collected <= writesInner[writeCollectInner].collected + 1'b1;
      if (pushReadInner) readsInner[4'(readHeadInner + 4'(readCountInner))] <=
        '{address:requestInput.readAddress, transaction:requestInput.readTransaction, default:'0};
      if (pushWriteInner) writesInner[4'(writeHeadInner + 4'(writeCountInner))] <=
        '{address:exitValidInput ? AXI_EXIT_ADDR : requestInput.writeAddress,
          transaction:requestInput.writeTransaction, mmio:exitValidInput,
          bytes:exitValidInput ? {{(DCACHE_LINE_BITS-32){1'b0}}, exitValueInput} : requestInput.writeData,
          default:'0};
      if (popReadInner) readHeadInner <= readHeadInner + 1'b1;
      if (popWriteInner) writeHeadInner <= writeHeadInner + 1'b1;
      readCountInner <= readCountInner + 5'(pushReadInner) - 5'(popReadInner);
      writeCountInner <= writeCountInner + 5'(pushWriteInner) - 5'(popWriteInner);
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    assert (int'(readCountInner) + int'(writeCountInner) <= DEPTH);
    assert (!exitValidInput || (exitReadyOutput && !requestInput.writeValid));
    if (slaveInput.rValid) assert (readCollectInner >= 0 && slaveInput.rResp == 0);
    if (slaveInput.bValid) assert (writeCollectInner >= 0 && slaveInput.bResp == 0);
  end
`endif
endmodule
