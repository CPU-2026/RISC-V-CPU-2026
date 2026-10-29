// Software AXIFetch: eight line slots, sixteen ordered Lite reads per 64B line.
// Eight slots match FETCH_REQUEST_ENTRIES: every outstanding line owns one
// unready ICache queue slot, so occupancy can never exceed eight.
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
  } line_t;
  line_t linesInner [DEPTH];
  logic [31:0] payloadInner [DEPTH][WORDS];
  logic [SLOT_W-1:0] headInner;
  logic [SLOT_W:0] countInner, tailSeqInner, issueSeqInner, collectSeqInner;
  logic [8:0] inflightInner, discardInner;
  logic pendingInner;
  logic [31:0] pendingAddressInner;
  int occupancyInner, issueInner, collectInner, tailInner;
  logic arInner, rInner, consumeInner, pushInner;
  always_comb begin
    occupancyInner = int'(countInner);
    issueInner = issueSeqInner != tailSeqInner ? int'(issueSeqInner[SLOT_W-1:0]) : -1;
    collectInner = collectSeqInner != tailSeqInner &&
      linesInner[collectSeqInner[SLOT_W-1:0]].collected < linesInner[collectSeqInner[SLOT_W-1:0]].issued ?
      int'(collectSeqInner[SLOT_W-1:0]) : -1;
    tailInner = (int'(headInner) + occupancyInner) & (DEPTH-1);
    requestReadyOutput = rstNInput && occupancyInner < DEPTH;
    responseOutput = '{valid:rstNInput && linesInner[headInner].valid &&
      linesInner[headInner].collected == WORD_W'(WORDS), address:linesInner[headInner].address,
      data:'0};
    for (int wordIndex = 0; wordIndex < WORDS; wordIndex++)
      if (responseOutput.valid) responseOutput.data[wordIndex*32+:32] = payloadInner[headInner][wordIndex];
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
      countInner <= 0; tailSeqInner <= 0; issueSeqInner <= 0; collectSeqInner <= 0;
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
        countInner <= 0; tailSeqInner <= 0; issueSeqInner <= 0; collectSeqInner <= 0;
        discardInner <= inflightInner + 9'(arInner) - 9'(rInner);
        if (pendingInner && arInner) pendingInner <= 0;
        else if (!pendingInner && !arInner && masterOutput.arValid) begin
          pendingInner <= 1;
          pendingAddressInner <= masterOutput.arAddr;
        end
      end else begin
        discardInner <= discardInner - 9'(rInner && discardInner != 0) + 9'(arInner && pendingInner);
        if (rInner && discardInner == 0 && collectInner >= 0) begin
          linesInner[collectInner].collected <= linesInner[collectInner].collected + 1'b1;
          if (linesInner[collectInner].collected + 1'b1 == WORD_W'(WORDS)) collectSeqInner <= collectSeqInner + 1'b1;
        end
        if (arInner && pendingInner) pendingInner <= 0;
        else if (arInner && issueInner >= 0) begin
          linesInner[issueInner].issued <= linesInner[issueInner].issued + 1'b1;
          if (linesInner[issueInner].issued + 1'b1 == WORD_W'(WORDS)) issueSeqInner <= issueSeqInner + 1'b1;
        end
        if (consumeInner && !(pushInner && tailInner == int'(headInner))) linesInner[headInner].valid <= 0;
        if (pushInner) linesInner[tailInner] <= '{valid:1'b1, address:requestInput.address, default:'0};
        if (pushInner) tailSeqInner <= tailSeqInner + 1'b1;
        if (consumeInner) headInner <= headInner + 1'b1;
        // Prepare both one-step alternatives before late push qualification.
        countInner <= pushInner ?
          (consumeInner ? countInner : countInner + (SLOT_W+1)'(1)) :
          (consumeInner ? countInner - (SLOT_W+1)'(1) : countInner);
      end
    end
  end
  // Payload is never reset or cleared on allocation. A line becomes visible
  // only after all WORDS have arrived; discarded generations never write it.
  always_ff @(posedge clkInput) begin
    if (rstNInput && !squashInput && rInner && discardInner == 0 && collectInner >= 0)
      payloadInner[collectInner][linesInner[collectInner].collected[$clog2(WORDS)-1:0]] <= slaveInput.rData;
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    int active;
    active = 0;
    for (int row = 0; row < DEPTH; row++) active += int'(linesInner[row].valid);
    assert (int'(countInner) == active && int'(countInner) <= DEPTH);
    assert (tailSeqInner[SLOT_W-1:0] == SLOT_W'(headInner + SLOT_W'(countInner)));
    assert ((SLOT_W+1)'(tailSeqInner - issueSeqInner) <= countInner);
    assert ((SLOT_W+1)'(tailSeqInner - collectSeqInner) <= countInner);
    assert (!requestInput.valid || requestReadyOutput);
    if (rInner) begin
      assert (inflightInner != 0 && slaveInput.rResp == 0);
      assert (squashInput || discardInner != 0 || collectInner >= 0);
    end
  end
`endif
endmodule
