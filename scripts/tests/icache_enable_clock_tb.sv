// Old/new ICache, identical physical SRAMs, bounded line-response model and
// independent expected instruction/metadata FIFO. Control state is never forced.
module tb_icache_enable_clock;
  parameter bit ALLOW_EXTRA_READS = 1'b1;
  import rv32_pkg::*;
  localparam int REQUESTS = FETCH_REQUEST_ENTRIES;
  logic clk = 0, rstN = 0, freeze = 0, flush = 0;
  icache_cpu_request_input_t cpuRequest;
  icache_cpu_response_output_t response, referenceResponse;
  cache_line_request_output_t lineRequest, referenceLineRequest;
  icache_line_response_input_t lineResponse;
  logic ready, referenceReady, responseReady, lineReady;
  logic lineResponseReady, referenceLineResponseReady, memFlush, referenceMemFlush;
  logic [31:0] lineAddresses [8];
  int remain [8];
  int lineHead = 0, lineTail = 0, lineCount = 0;
  icache_cpu_request_input_t expected [8];
  int expectedHead = 0, expectedTail = 0, expectedCount = 0;
  int serial = 0, cycles = 0, accepted = 0, returned = 0;
  int fills = 0, fullBlocked = 0, fullPopPush = 0, headBypass = 0;
  int fillBlockedHit = 0, flushedFill = 0, frozenFill = 0;
  logic [15:0] forwardedLanes = 0;
  logic lastAccepted;
  int unsigned randomState = 32'h5e4a9c31;

  rv32_icache dut (
    .clkInput(clk), .rstNInput(rstN), .freezeInput(freeze), .flushInput(flush),
    .cpuRequestInput(cpuRequest), .cpuReqReadyOutput(ready), .cpuResponseOutput(response),
    .cpuRspReadyInput(responseReady), .memRequestOutput(lineRequest), .memReqReadyInput(lineReady),
    .memResponseInput(lineResponse), .memRspReadyOutput(lineResponseReady), .memFlushOutput(memFlush)
  );
  rv32_icache_reference referenceCache (
    .clkInput(clk), .rstNInput(rstN), .freezeInput(freeze), .flushInput(flush),
    .cpuRequestInput(cpuRequest), .cpuReqReadyOutput(referenceReady), .cpuResponseOutput(referenceResponse),
    .cpuRspReadyInput(responseReady), .memRequestOutput(referenceLineRequest), .memReqReadyInput(lineReady),
    .memResponseInput(lineResponse), .memRspReadyOutput(referenceLineResponseReady), .memFlushOutput(referenceMemFlush)
  );

  function automatic logic [31:0] word_at(input logic [31:0] address);
    return (address & 32'hfffffffc) ^ 32'h9e3779b9;
  endfunction
  function automatic int unsigned random_word();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction

  // SRAM is persistent across reset; a wrong access is visible in the miter.
  for (genvar row = 0; row < ICACHE_SETS; row++) begin : init_sram
    initial begin
      dut.u_data.storage.words[row] = {16{32'ha5a55a5a}};
      referenceCache.u_data.storage.words[row] = {16{32'ha5a55a5a}};
    end
  end

  task automatic check_state;
    assert({ready, lineResponseReady, memFlush, response, lineRequest} ===
           {referenceReady, referenceLineResponseReady, referenceMemFlush,
            referenceResponse, referenceLineRequest}) else $fatal(1, "ICache interface mismatch cycle=%0d", cycles);
    assert({dut.headInner, dut.countInner, dut.readValidInner, dut.readIndexInner,
            dut.readLaneInner, dut.hitInner, dut.refillHitInner, dut.readBlockedInner,
            dut.refillFoundInner, dut.refillSlotInner, dut.fillFireInner,
             dut.requestFireInner, dut.responseFireInner, dut.sramAddressInner} ===
           {referenceCache.headInner, referenceCache.countInner, referenceCache.readValidInner,
            referenceCache.readIndexInner, referenceCache.readLaneInner, referenceCache.hitInner,
            referenceCache.refillHitInner, referenceCache.readBlockedInner, referenceCache.refillFoundInner,
            referenceCache.refillSlotInner, referenceCache.fillFireInner, referenceCache.requestFireInner,
             referenceCache.responseFireInner, referenceCache.sramAddressInner})
      else $fatal(1, "ICache control mismatch cycle=%0d", cycles);
    // Native-vs-legacy may add harmless reads, never suppress a required
    // physical access. Native-vs-sv2v must preserve even the physical CE.
    if (!ALLOW_EXTRA_READS)
      assert (dut.sramEnableInner === referenceCache.sramEnableInner)
        else $fatal(1, "converted physical CE mismatch cycle=%0d", cycles);
    else if (rstN && referenceCache.sramEnableInner)
      assert (dut.sramEnableInner) else $fatal(1, "required SRAM access suppressed cycle=%0d", cycles);
    for (int row = 0; row < ICACHE_SETS; row++) begin
      assert({dut.validInner[row], dut.tagInner[row]} ===
             {referenceCache.validInner[row], referenceCache.tagInner[row]}) else $fatal(1, "ICache tag mismatch");
      assert(dut.u_data.storage.words[row] === referenceCache.u_data.storage.words[row])
        else $fatal(1, "ICache SRAM mismatch row=%0d", row);
    end
    for (int row = 0; row < REQUESTS; row++)
      assert({dut.requestAddressInner[row], dut.requestPredictedPcInner[row], dut.requestCheckpointInner[row],
              dut.requestReadyInner[row], dut.requestInstructionInner[row]} ===
             {referenceCache.requestAddressInner[row], referenceCache.requestPredictedPcInner[row],
              referenceCache.requestCheckpointInner[row], referenceCache.requestReadyInner[row],
              referenceCache.requestInstructionInner[row]}) else $fatal(1, "ICache request row mismatch");
    assert(int'(dut.countInner) == expectedCount) else $fatal(1, "ICache expected occupancy");
  endtask

  task automatic reset_cache;
    rstN = 0; freeze = 0; flush = 0; cpuRequest = '0; lineResponse = '0;
    responseReady = 0; lineReady = 0;
    lineHead = 0; lineTail = 0; lineCount = 0;
    expectedHead = 0; expectedTail = 0; expectedCount = 0; serial = 0;
    #1; clk = 1; #1; clk = 0; #1;
    rstN = 1; #1; check_state();
  endtask

  task automatic step(input bit offer, input logic [31:0] address, input bit consume,
                      input bit allowMemory, input bit squash = 0, input bit stopped = 0);
    bit takeRequest, takeResponse, takeLine, takeFill;
    int oldLineCount, oldLineHead;
    freeze = stopped; flush = squash; responseReady = consume;
    cpuRequest = '{valid:offer, address:address, predictedProgramCounter:address+32'd4,
      predictorCheckpointId:bpu_ckpt_id_t'(serial)};
    lineReady = allowMemory && lineCount < 8;
    lineResponse = '0;
    if (lineCount != 0 && remain[lineHead] == 0) begin
      lineResponse.valid = 1;
      lineResponse.address = lineAddresses[lineHead];
      for (int word = 0; word < 16; word++)
        lineResponse.data[word*32+:32] = word_at(lineAddresses[lineHead]+32'(word*4));
    end
    #1; check_state();
    takeRequest = offer && ready;
    takeResponse = response.valid && consume && !squash && !stopped;
    takeLine = lineRequest.valid && lineReady;
    takeFill = lineResponse.valid && lineResponseReady;
    lastAccepted = takeRequest;
    if (takeResponse) begin
      assert(expectedCount != 0 && response.address == expected[expectedHead].address &&
        response.predictedProgramCounter == expected[expectedHead].predictedProgramCounter &&
        response.predictorCheckpointId == expected[expectedHead].predictorCheckpointId &&
        response.instruction == word_at(expected[expectedHead].address))
        else $fatal(1, "instruction/metadata reference mismatch cycle=%0d pc=%h got=%h", cycles, response.address, response.instruction);
      returned++;
    end
    if (takeRequest) accepted++;
    if (takeFill) fills++;
    if (offer && !ready && expectedCount == REQUESTS) fullBlocked++;
    if (expectedCount == REQUESTS && takeRequest && takeResponse) fullPopPush++;
    if (takeResponse && dut.headReadReadyInner) headBypass++;
    if (offer && dut.readBlockedInner && dut.hitInner) fillBlockedHit++;
    if (takeRequest && dut.refillHitInner) forwardedLanes[address[5:2]] = 1;
    if (squash && lineResponse.valid) flushedFill++;
    if (stopped && lineResponse.valid) frozenFill++;
    oldLineCount = lineCount; oldLineHead = lineHead;
    clk = 1; #1; clk = 0; #1;
    cycles++;
    if (squash && !stopped) begin
      lineHead = 0; lineTail = 0; lineCount = 0;
      expectedHead = 0; expectedTail = 0; expectedCount = 0;
    end else begin
      for (int age = 0; age < oldLineCount; age++)
        if (remain[(oldLineHead+age)&7] != 0) remain[(oldLineHead+age)&7]--;
      if (takeFill) begin lineHead = (lineHead+1)&7; lineCount--; end
      if (takeLine) begin
        assert(lineCount < 8) else $fatal(1, "line transport capacity");
        lineAddresses[lineTail] = lineRequest.address;
        remain[lineTail] = 12 + (serial % 13);
        lineTail = (lineTail+1)&7; lineCount++;
      end
      if (takeResponse) begin expectedHead = (expectedHead+1)&7; expectedCount--; end
      if (takeRequest) begin
        assert(expectedCount < REQUESTS) else $fatal(1, "request capacity");
        expected[expectedTail] = cpuRequest;
        expectedTail = (expectedTail+1)&7; expectedCount++; serial++;
      end
    end
  endtask

  task automatic send(input logic [31:0] address, input bit consume = 1);
    for (int waitCycle = 0; waitCycle < 1000; waitCycle++) begin
      step(1, address, consume, 1);
      if (lastAccepted) return;
    end
    $fatal(1, "ICache offered request timeout");
  endtask
  task automatic drain;
    for (int waitCycle = 0; waitCycle < 2000; waitCycle++) begin
      if (expectedCount == 0 && lineCount == 0 && !dut.readValidInner) return;
      step(0, 0, 1, 1);
    end
    $fatal(1, "ICache drain timeout");
  endtask
  task automatic wait_offered_fill;
    assert(lineCount != 0) else $fatal(1, "no pending line");
    while (remain[lineHead] != 0) step(0, 0, 0, 0);
  endtask

  initial begin
    bit held;
    logic [31:0] heldAddress;
    reset_cache();
    // Fill the actual request capacity, then offer one more without a pop.
    for (int i = 0; i < REQUESTS; i++) send(32'(i*4), 0);
    step(1, 32, 0, 1);
    assert(!lastAccepted) else $fatal(1, "full queue accepted without pop");
    send(32); drain();
    // Consecutive synchronous hits and all sixteen instruction word lanes.
    for (int turn = 0; turn < 3; turn++)
      for (int lane = 0; lane < 16; lane++) send(32'(lane*4));
    drain();
    // Full pop/push while a same-line fill, not IMEM credit, admits the request.
    reset_cache(); send(0); drain(); send(4, 0);
    for (int i = 0; i < REQUESTS-1; i++) send(32'(1024+i*4), 0);
    wait_offered_fill();
    step(1, 1084, 1, 0);
    assert(lastAccepted) else $fatal(1, "full same-line fill forwarding blocked");
    drain();
    // A fill blocks a new hit in another cache line on the single SRAM port.
    reset_cache(); send(64); drain(); send(1024, 0); wait_offered_fill();
    step(1, 68, 0, 1);
    assert(!lastAccepted) else $fatal(1, "fill/read collision accepted");
    send(68); drain();
    for (int lane = 0; lane < 16; lane++) begin
      reset_cache(); send(4096, 0); wait_offered_fill();
      step(1, 32'(4096+lane*4), 0, 0);
      assert(lastAccepted) else $fatal(1, "refill forwarding lane=%0d", lane);
      drain();
    end
    // Flush an old synchronous hit; flush or freeze an offered refill.
    reset_cache(); send(0); drain(); send(4, 0); step(1, 8, 0, 1, 1); send(8); drain();
    reset_cache(); send(0, 0); wait_offered_fill(); step(1, 60, 0, 0, 1); send(60); drain();
    reset_cache(); send(0, 0); wait_offered_fill();
    repeat (3) step(1, 60, 0, 0, 0, 1);
    step(1, 60, 0, 0); assert(lastAccepted); drain();
    // Stable offers under random CPU/memory backpressure; flush cancels offers.
    reset_cache(); held = 0;
    for (int i = 0; i < 2000; i++) begin
      bit squash;
      squash = random_word() % 64 == 0;
      if (squash) held = 0;
      if (!held && random_word() % 4 != 0) begin
        held = 1; heldAddress = 32'((random_word()%1024)*4);
      end
      step(held, held ? heldAddress : 32'b0, random_word()%4 != 0, random_word()%4 != 0, squash);
      if (lastAccepted || squash) held = 0;
    end
    drain();
    assert(fullBlocked > 0 && fullPopPush > 0 && headBypass > 0 && fillBlockedHit > 0 &&
           forwardedLanes == 16'hffff && flushedFill > 0 && frozenFill > 0)
      else $fatal(1, "ICache coverage missing full=%0d poppush=%0d bypass=%0d collision=%0d lanes=%h flush=%0d freeze=%0d",
        fullBlocked, fullPopPush, headBypass, fillBlockedHit, forwardedLanes, flushedFill, frozenFill);
    $display("PASS ICache enable clock cycles=%0d accepts=%0d responses=%0d fills=%0d full=%0d poppush=%0d bypass=%0d collision=%0d lanes=%h flush=%0d freeze=%0d",
      cycles, accepted, returned, fills, fullBlocked, fullPopPush, headBypass, fillBlockedHit,
      forwardedLanes, flushedFill, frozenFill);
    $finish;
  end
endmodule
