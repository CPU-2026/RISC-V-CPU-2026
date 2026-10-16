// Same stimulus and physical SRAM model on both sides of the SV frontend.
module tb_dcache_frontend;
  import rv32_pkg::*;
  localparam int unsigned WORDS_PER_LINE = DCACHE_LINE_BYTES / 4;
  localparam int unsigned FILL_BEATS = WORDS_PER_LINE / 2;
  localparam int unsigned SAME_SET_STRIDE = DCACHE_SETS * DCACHE_LINE_BYTES;
  localparam int unsigned TAG_W = 32 - $clog2(DCACHE_SETS) - $clog2(DCACHE_LINE_BYTES);
  localparam logic [TAG_W:0] POISON_META = {1'b1, {TAG_W{1'b0}}};
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0;
  dcache_cpu_request_input_t cpuRequest = '0;
  dcache_line_response_input_t lineResponse;
  logic readReady, writeReady;
  dcache_write_response_input_t writeResponse;
  logic replyReadyOriginal, replyReadyConverted, writeReplyReadyOriginal, writeReplyReadyConverted;
  logic backingRead, backingWrite;
  logic [31:0] backingReadAddress, backingWriteAddress;
  logic [DCACHE_LINE_BITS-1:0] backingReadData, backingWriteData;
  logic [4:0] memoryCount;
  logic readyOriginal, readyConverted, initOriginal, initConverted, idleOriginal, idleConverted;
  dcache_cpu_response_output_t responseOriginal, responseConverted;
  dcache_line_request_output_t requestOriginal, requestConverted;
  logic [31:0] lastWriteAddress = 0;
  logic [7:0] memory [32768];
  logic [7:0] expectedMemory [32768];
  logic [31:0] expectedLoads [4];
  logic [3:0] loadOwners = 0;
  int cycle = 0;
  int accepted = 0, responses = 0, reads = 0, writes = 0, beats = 0;
  int fullBlocked = 0, simultaneous = 0, heldReply = 0;
  int wayOneStoreHits = 0;
  logic [31:0] randomState = 32'hcace1234;

  rv32_dcache original (
    .clkInput(clock), .rstNInput(resetN), .cpuRequestInput(cpuRequest),
    .cpuReqReadyOutput(readyOriginal), .cpuResponseOutput(responseOriginal),
    .memRequestOutput(requestOriginal), .memReadReadyInput(readReady),
    .memWriteReadyInput(writeReady), .memResponseInput(lineResponse),
    .memWriteResponseInput(writeResponse), .memRspReadyOutput(replyReadyOriginal),
    .memWriteRspReadyOutput(writeReplyReadyOriginal), .initializedOutput(initOriginal), .idleOutput(idleOriginal)
  );
  rv32_dcache_converted converted (
    .clkInput(clock), .rstNInput(resetN), .cpuRequestInput(cpuRequest),
    .cpuReqReadyOutput(readyConverted), .cpuResponseOutput(responseConverted),
    .memRequestOutput(requestConverted), .memReadReadyInput(readReady),
    .memWriteReadyInput(writeReady), .memResponseInput(lineResponse),
    .memWriteResponseInput(writeResponse), .memRspReadyOutput(replyReadyConverted),
    .memWriteRspReadyOutput(writeReplyReadyConverted), .initializedOutput(initConverted), .idleOutput(idleConverted)
  );

  rv32_dmem memoryController (
    .clkInput(clock), .rstNInput(resetN), .requestInput(requestOriginal),
    .readReadyOutput(readReady), .writeReadyOutput(writeReady),
    .responseOutput(lineResponse), .writeResponseOutput(writeResponse),
    .responseReadyInput(replyReadyOriginal), .writeResponseReadyInput(writeReplyReadyOriginal),
    .backingReadValidOutput(backingRead), .backingReadAddressOutput(backingReadAddress),
    .backingReadDataInput(backingReadData), .backingWriteValidOutput(backingWrite),
    .backingWriteAddressOutput(backingWriteAddress), .backingWriteDataOutput(backingWriteData),
    .countOutput(memoryCount)
  );
  always_comb
    for (int b = 0; b < DCACHE_LINE_BYTES; b++) backingReadData[b*8+:8] = memory[backingReadAddress+32'(b)];

  // Include inactive/partly-filled rows: catches a wrong byte/bank assignment
  // before final metadata becomes valid, not just at the next Load response.
  for (genvar way = 0; way < DCACHE_WAYS; way++) begin : g_check_way
   for (genvar bank = 0; bank < WORDS_PER_LINE; bank++) begin : g_check_bank
    for (genvar row = 0; row < DCACHE_SETS; row++) begin : g_check_row
      initial begin
        original.g_way[way].g_data_bank[bank].u_data.storage.words[row] = 32'ha5a5a5a5;
        converted.g_way[way].g_data_bank[bank].u_data.storage.words[row] = 32'ha5a5a5a5;
      end
      always @(negedge clock) if (resetN && initOriginal) begin
        assert (original.g_way[way].g_data_bank[bank].u_data.storage.words[row] ===
                converted.g_way[way].g_data_bank[bank].u_data.storage.words[row])
          else $fatal(1, "SRAM bank mismatch: way=%0d bank=%0d row=%0d cycle=%0d", way, bank, row, cycle);
      end
    end
   end
   for (genvar row = 0; row < DCACHE_SETS; row++) begin : g_check_metadata
    initial begin
      original.g_way[way].u_metadata.storage.words[row] = POISON_META;
      converted.g_way[way].u_metadata.storage.words[row] = POISON_META;
    end
    always @(negedge clock) if (resetN && initOriginal) begin
      assert (original.validInner[row][way] === converted.validInner[row][way])
        else $fatal(1, "valid register mismatch: way=%0d row=%0d cycle=%0d", way, row, cycle);
      assert (original.g_way[way].u_metadata.storage.words[row] === converted.g_way[way].u_metadata.storage.words[row])
        else $fatal(1, "metadata mismatch: way=%0d row=%0d cycle=%0d", way, row, cycle);
    end
   end
  end
  for (genvar row = 0; row < DCACHE_SETS; row++) begin : g_check_plru
    always @(negedge clock) if (resetN && initOriginal) begin
      assert (original.plruInner[row] === converted.plruInner[row])
        else $fatal(1, "PLRU mismatch: row=%0d cycle=%0d", row, cycle);
    end
  end

  task automatic check_outputs;
    assert ({readyOriginal, initOriginal, idleOriginal, replyReadyOriginal, writeReplyReadyOriginal} ===
            {readyConverted, initConverted, idleConverted, replyReadyConverted, writeReplyReadyConverted})
      else $fatal(1, "control mismatch: cycle=%0d", cycle);
    assert (responseOriginal.valid === responseConverted.valid)
      else $fatal(1, "response-valid mismatch: cycle=%0d", cycle);
    if (responseOriginal.valid)
      assert (responseOriginal === responseConverted)
        else $fatal(1, "Load result mismatch: cycle=%0d", cycle);
    assert ({requestOriginal.readValid, requestOriginal.writeValid} ===
            {requestConverted.readValid, requestConverted.writeValid})
      else $fatal(1, "memory-valid mismatch: cycle=%0d", cycle);
    if (requestOriginal.readValid)
      assert ({requestOriginal.readAddress, requestOriginal.readTransaction} ===
              {requestConverted.readAddress, requestConverted.readTransaction})
        else $fatal(1, "read address mismatch: cycle=%0d", cycle);
    if (requestOriginal.writeValid)
      assert ({requestOriginal.writeAddress, requestOriginal.writeData, requestOriginal.writeTransaction} ===
              {requestConverted.writeAddress, requestConverted.writeData, requestConverted.writeTransaction})
        else $fatal(1, "writeback mismatch: cycle=%0d", cycle);
  endtask
  always @(posedge clock or negedge clock) if (resetN) check_outputs();

  always @(posedge clock) begin
    cycle++;
    if (resetN && initOriginal) begin
      if (responseOriginal.valid) begin
        logic [31:0] expected;
        assert (loadOwners[responseOriginal.transaction]) else $fatal(1, "unsolicited Load response");
        expected = expectedLoads[responseOriginal.transaction];
        loadOwners[responseOriginal.transaction] = 0;
        assert (responseOriginal.readData === expected)
          else $fatal(1, "architectural Load mismatch cycle=%0d actual=%h expected=%h", cycle, responseOriginal.readData, expected);
        responses++;
      end
      if (cpuRequest.valid && readyOriginal) begin
        int bytes;
        logic [31:0] expected;
        accepted++;
        bytes = 1 << cpuRequest.size;
        expected = 0;
        if (cpuRequest.write) begin
          for (int b = 0; b < bytes; b++)
            if (cpuRequest.writeStrobe[b]) expectedMemory[cpuRequest.address+32'(b)] = cpuRequest.writeData[b*8+:8];
        end else begin
          for (int b = 0; b < bytes; b++) expected[b*8+:8] = expectedMemory[cpuRequest.address+32'(b)];
          assert (!loadOwners[cpuRequest.transaction]);
          loadOwners[cpuRequest.transaction] = 1;
          expectedLoads[cpuRequest.transaction] = expected;
        end
      end
      if (original.storeInner >= 0 && original.hitWayInner == 1) wayOneStoreHits++;
      if (cpuRequest.valid && !readyOriginal) fullBlocked++;
      if (|original.releasedInner && cpuRequest.valid && readyOriginal) simultaneous++;
      if (original.fillBeatInner) beats++;
      if (lineResponse.valid && !original.fillFireInner) heldReply++;
      if (requestOriginal.readValid && readReady) begin
        reads++;
      end
      if (requestOriginal.writeValid && writeReady) begin
        lastWriteAddress = requestOriginal.writeAddress;
        writes++;
      end
      if (backingWrite)
        for (int b = 0; b < DCACHE_LINE_BYTES; b++) memory[backingWriteAddress+32'(b)] <= backingWriteData[b*8+:8];
    end
  end

  task automatic offer(input bit wr, input int addr, input logic [31:0] value,
                       input logic [1:0] size, input logic [3:0] mask);
    int owner;
    @(negedge clock);
    owner = 0;
    if (!wr) begin
      while (&loadOwners) @(negedge clock);
      for (int i = 3; i >= 0; i--) if (!loadOwners[i]) owner = i;
    end
    cpuRequest = '{valid:1'b1, write:wr, address:32'(addr), writeData:value, writeStrobe:mask, size:size, transaction:2'(owner)};
    do @(posedge clock); while (!readyOriginal);
    @(negedge clock);
    cpuRequest.valid = 0;
  endtask
  initial begin
    int readsBefore, writesBefore;
    assert (DCACHE_SETS * DCACHE_WAYS * DCACHE_LINE_BYTES == 4096);
    for (int a = 0; a < 32768; a++) begin
      memory[a] = 8'(a ^ (a >> 8) ^ 'h5a);
      expectedMemory[a] = memory[a];
    end
    repeat (2) @(negedge clock);
    resetN = 1;
    while (!initOriginal) @(negedge clock);
    // Split Store on a miss, conflicting dirty victim, split Store hit,
    // refetch; then exercise every bank, offset, size and queue wraparound.
    offer(1, 7, 32'h11223380, MEM_WORD, 4'b1111);
    offer(0, SAME_SET_STRIDE, 0, MEM_WORD, 0);
    offer(1, SAME_SET_STRIDE+7, 32'h55667788, MEM_WORD, 4'b0111);
    offer(0, 7, 0, MEM_WORD, 0);
    while (!idleOriginal) @(negedge clock);
    if (DCACHE_WAYS == 2) begin
      readsBefore = reads;
      offer(0, 7, 0, MEM_WORD, 0);
      offer(0, SAME_SET_STRIDE+7, 0, MEM_WORD, 0);
      offer(0, 7, 0, MEM_WORD, 0); // A MRU: B must be the next dirty victim.
      while (!idleOriginal) @(negedge clock);
      assert (reads == readsBefore && wayOneStoreHits > 0)
        else $fatal(1, "two resident ways or way1 Store hit was not exercised");
      writesBefore = writes;
      offer(0, SAME_SET_STRIDE*2, 0, MEM_WORD, 0);
      while (!idleOriginal) @(negedge clock);
      assert (writes == writesBefore+1 && lastWriteAddress == SAME_SET_STRIDE)
        else $fatal(1, "two-way replacement did not evict dirty LRU way1/B");
      writesBefore = writes;
      offer(0, SAME_SET_STRIDE+7, 0, MEM_WORD, 0);
      while (!idleOriginal) @(negedge clock);
      assert (writes == writesBefore+1 && lastWriteAddress == 0)
        else $fatal(1, "two-way replacement did not evict dirty LRU way0/A");
      offer(0, 7, 0, MEM_WORD, 0);
      while (!idleOriginal) @(negedge clock);
    end
    for (int i = 0; i < 16; i++) offer(i[0], (i * 3) % (DCACHE_LINE_BYTES - 3), 32'(i), MEM_WORD, 4'b1111);
    for (int i = 0; i < 800; i++) begin
      int address, offset, bytes;
      logic [1:0] size;
      logic [3:0] mask;
      randomState = {randomState[30:0], randomState[31] ^ randomState[21] ^ randomState[1] ^ randomState[0]};
      size = 2'(i % 3);
      bytes = 1 << size;
      offset = (i * 7) % (DCACHE_LINE_BYTES + 1 - bytes);
      address = (int'(randomState[14:8]) & (DCACHE_SETS - 1)) * DCACHE_LINE_BYTES +
        int'(randomState[16:15]) * SAME_SET_STRIDE + offset;
      mask = 4'((1 << bytes) - 1) & randomState[7:4];
      offer(randomState[0], address, randomState, size, mask);
    end
    while (!idleOriginal) @(negedge clock);
    // Warm reset must preserve SRAM yet invalidate the converted register array.
    offer(1, 64, 32'hdeadbeef, MEM_WORD, 4'b1111);
    while (!idleOriginal) @(negedge clock);
    resetN = 0;
    repeat (2) @(negedge clock);
    resetN = 1;
    #1;
    assert (initOriginal && initConverted && readyOriginal && readyConverted);
    assert (loadOwners == 0);
    for (int a = 0; a < 32768; a++) expectedMemory[a] = memory[a];
    for (int row = 0; row < DCACHE_SETS; row++)
      for (int way = 0; way < DCACHE_WAYS; way++)
        assert (!original.validInner[row][way] && !converted.validInner[row][way]);
    offer(0, 64, 0, MEM_WORD, 0);
    while (!idleOriginal) @(negedge clock);
    assert (accepted == (DCACHE_WAYS == 2 ? 828 : 822) && responses > 100 && reads > 100 && writes > 100 &&
            loadOwners == 0 && beats == reads * FILL_BEATS &&
            fullBlocked > 0 && simultaneous > 0 && heldReply > 0)
      else $fatal(1, "coverage incomplete: accepts=%0d responses=%0d reads=%0d writes=%0d beats=%0d full=%0d simultaneous=%0d held=%0d",
                  accepted, responses, reads, writes, beats, fullBlocked, simultaneous, heldReply);
    $display("PASS frontend equivalence: sets=%0d ways=%0d line=%0d cycles=%0d requests=%0d reads=%0d writes=%0d beats=%0d way1_stores=%0d",
             DCACHE_SETS, DCACHE_WAYS, DCACHE_LINE_BYTES, cycle, accepted, reads, writes, beats, wayOneStoreHits);
    $finish;
  end
  initial begin #1000000; $fatal(1, "frontend equivalence timeout"); end
endmodule
