// Software AXIFetch: sixteen line slots, sixteen ordered Lite reads per 64B line.
// Recovery discards old responses but preserves any already asserted AR.
module rv32_axi_fetch (
  input logic clkInput, rstNInput,
  input logic squashInput,
  input rv32_pkg::cache_line_request_output_t requestInput,
  output logic requestReadyOutput,
  output rv32_pkg::icache_line_response_input_t responseOutput,
  input logic responseReadyInput,
  output rv32_pkg::axi_master_t masterOutput,
  input rv32_pkg::axi_slave_t slaveInput
);
  import rv32_pkg::*;
  localparam int DEPTH = AXI_FETCH_LINE_ENTRIES;
  localparam int SLOT_W = $clog2(DEPTH);
  localparam int WORDS = CACHE_LINE_BYTES >> 2;
  localparam int WORD_W = $clog2(WORDS)+1;
  typedef struct packed {
    logic valid;
    logic [31:0] address;
    logic [WORD_W-1:0] issued, collected;
    logic [CACHE_LINE_BITS-1:0] words;
  } line_t;
  line_t linesInner [DEPTH];
  logic [SLOT_W-1:0] headInner;
  logic [8:0] inflightInner, discardInner;
  logic pendingInner;
  logic [31:0] pendingAddressInner;
  int occupancyInner, issueInner, collectInner, tailInner;
  logic arInner, rInner, consumeInner, pushInner;
  always_comb begin
    int slot;
    occupancyInner = 0;
    issueInner = -1;
    collectInner = -1;
    for (int age = 0; age < DEPTH; age++) begin
      slot = (int'(headInner) + age) & (DEPTH-1);
      if (linesInner[slot].valid) begin
        occupancyInner++;
        if (issueInner < 0 && linesInner[slot].issued < WORD_W'(WORDS)) issueInner = slot;
        if (collectInner < 0 && linesInner[slot].collected < linesInner[slot].issued) collectInner = slot;
      end
    end
    tailInner = (int'(headInner) + occupancyInner) & (DEPTH-1);
    requestReadyOutput = rstNInput && occupancyInner < DEPTH;
    responseOutput = '{valid:rstNInput && linesInner[headInner].valid &&
      linesInner[headInner].collected == WORD_W'(WORDS), address:linesInner[headInner].address,
      data:linesInner[headInner].words};
    masterOutput = '0;
    masterOutput.arValid = rstNInput && (pendingInner || issueInner >= 0);
    masterOutput.arAddr = pendingInner ? pendingAddressInner : issueInner >= 0 ?
      linesInner[issueInner].address + (32'(linesInner[issueInner].issued) << 2) : 32'b0;
    masterOutput.rReady = rstNInput;
  end
  assign arInner = masterOutput.arValid && slaveInput.arReady;
  assign rInner = slaveInput.rValid && masterOutput.rReady;
  assign consumeInner = responseOutput.valid && responseReadyInput;
  assign pushInner = requestInput.valid && (occupancyInner < DEPTH || consumeInner);
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= 0;
      inflightInner <= 0;
      discardInner <= 0;
      pendingInner <= 0;
      pendingAddressInner <= 0;
      for (int i = 0; i < DEPTH; i++) linesInner[i] <= '0;
    end else begin
      inflightInner <= inflightInner + 9'(arInner) - 9'(rInner);
      if (squashInput) begin
        for (int i = 0; i < DEPTH; i++) linesInner[i].valid <= 0;
        headInner <= 0;
        discardInner <= inflightInner + 9'(arInner) - 9'(rInner);
        if (pendingInner && arInner) pendingInner <= 0;
        else if (!pendingInner && !arInner && masterOutput.arValid) begin
          pendingInner <= 1;
          pendingAddressInner <= masterOutput.arAddr;
        end
      end else begin
        discardInner <= discardInner - 9'(rInner && discardInner != 0) + 9'(arInner && pendingInner);
        if (rInner && discardInner == 0 && collectInner >= 0) begin
          linesInner[collectInner].words[int'(linesInner[collectInner].collected)*32+:32] <= slaveInput.rData;
          linesInner[collectInner].collected <= linesInner[collectInner].collected + 1'b1;
        end
        if (arInner && pendingInner) pendingInner <= 0;
        else if (arInner && issueInner >= 0) linesInner[issueInner].issued <= linesInner[issueInner].issued + 1'b1;
        if (consumeInner && !(pushInner && tailInner == int'(headInner))) linesInner[headInner].valid <= 0;
        if (pushInner) linesInner[tailInner] <= '{valid:1'b1, address:requestInput.address, default:'0};
        if (consumeInner) headInner <= headInner + 1'b1;
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    assert (!requestInput.valid || requestReadyOutput);
    if (rInner) begin
      assert (inflightInner != 0 && slaveInput.rResp == 0);
      assert (squashInput || discardInner != 0 || collectInner >= 0);
    end
  end
`endif
endmodule
