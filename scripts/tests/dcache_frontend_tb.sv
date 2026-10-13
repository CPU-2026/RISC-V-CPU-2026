// Same stimulus and physical SRAM model on both sides of the SV frontend.
module tb_dcache_frontend;
  import rv32_pkg::*;
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0;
  dcache_cpu_request_input_t cpuRequest = '0;
  cache_line_response_input_t lineResponse = '0;
  logic readReady, writeReady, writeDone = 0;
  logic readyOriginal, readyConverted, initOriginal, initConverted, idleOriginal, idleConverted;
  dcache_cpu_response_output_t responseOriginal, responseConverted;
  dcache_line_request_output_t requestOriginal, requestConverted;
  logic readBusy = 0, writeBusy = 0;
  logic [31:0] readAddress, writeAddress;
  logic [511:0] writeData;
  logic [7:0] memory [32768];
  int readWait = 0, writeWait = 0, cycle = 0;
  int accepted = 0, responses = 0, reads = 0, writes = 0, beats = 0;
  int fullBlocked = 0, simultaneous = 0, heldReply = 0;
  logic [31:0] randomState = 32'hcace1234;

  rv32_dcache original (
    .clkInput(clock), .rstNInput(resetN), .cpuRequestInput(cpuRequest),
    .cpuReqReadyOutput(readyOriginal), .cpuResponseOutput(responseOriginal),
    .memRequestOutput(requestOriginal), .memReadReadyInput(readReady),
    .memWriteReadyInput(writeReady), .memResponseInput(lineResponse),
    .memWriteDoneInput(writeDone), .initializedOutput(initOriginal), .idleOutput(idleOriginal)
  );
  rv32_dcache_converted converted (
    .clkInput(clock), .rstNInput(resetN), .cpuRequestInput(cpuRequest),
    .cpuReqReadyOutput(readyConverted), .cpuResponseOutput(responseConverted),
    .memRequestOutput(requestConverted), .memReadReadyInput(readReady),
    .memWriteReadyInput(writeReady), .memResponseInput(lineResponse),
    .memWriteDoneInput(writeDone), .initializedOutput(initConverted), .idleOutput(idleConverted)
  );

  // Include inactive/partly-filled rows: catches a wrong byte/bank assignment
  // before final metadata becomes valid, not just at the next Load response.
  for (genvar bank = 0; bank < 16; bank++) begin : g_check_bank
    for (genvar row = 0; row < 128; row++) begin : g_check_row
      always @(negedge clock) if (resetN && initOriginal) begin
        assert (original.g_data_bank[bank].u_data.storage.words[row] ===
                converted.g_data_bank[bank].u_data.storage.words[row])
          else $fatal(1, "SRAM bank mismatch: bank=%0d row=%0d cycle=%0d", bank, row, cycle);
      end
    end
  end
  for (genvar row = 0; row < 128; row++) begin : g_check_metadata
    always @(negedge clock) if (resetN && initOriginal) begin
      assert (original.validInner[row] === converted.validInner[row])
        else $fatal(1, "valid register mismatch: row=%0d cycle=%0d", row, cycle);
      assert (original.u_metadata.storage.words[row] === converted.u_metadata.storage.words[row])
        else $fatal(1, "metadata mismatch: row=%0d cycle=%0d", row, cycle);
    end
  end

  task automatic check_outputs;
    assert ({readyOriginal, initOriginal, idleOriginal} === {readyConverted, initConverted, idleConverted})
      else $fatal(1, "control mismatch: cycle=%0d", cycle);
    assert (responseOriginal.valid === responseConverted.valid)
      else $fatal(1, "response-valid mismatch: cycle=%0d", cycle);
    if (responseOriginal.valid)
      assert (responseOriginal.readData === responseConverted.readData)
        else $fatal(1, "Load result mismatch: cycle=%0d", cycle);
    assert ({requestOriginal.readValid, requestOriginal.writeValid} ===
            {requestConverted.readValid, requestConverted.writeValid})
      else $fatal(1, "memory-valid mismatch: cycle=%0d", cycle);
    if (requestOriginal.readValid)
      assert (requestOriginal.readAddress === requestConverted.readAddress)
        else $fatal(1, "read address mismatch: cycle=%0d", cycle);
    if (requestOriginal.writeValid)
      assert ({requestOriginal.writeAddress, requestOriginal.writeData} ===
              {requestConverted.writeAddress, requestConverted.writeData})
        else $fatal(1, "writeback mismatch: cycle=%0d", cycle);
  endtask
  always @(posedge clock or negedge clock) if (resetN) check_outputs();
  assign readReady = !readBusy && cycle % 7 != 2;
  assign writeReady = !writeBusy && cycle % 11 != 3;

  always @(posedge clock) begin
    cycle++;
    lineResponse.valid <= 0;
    writeDone <= 0;
    if (resetN && initOriginal) begin
      if (cpuRequest.valid && readyOriginal) accepted++;
      if (responseOriginal.valid) responses++;
      if (cpuRequest.valid && !readyOriginal) fullBlocked++;
      if (original.popInner && cpuRequest.valid && readyOriginal) simultaneous++;
      if (original.fillBeatInner) beats++;
      if (original.replyValidInner && !original.fillFireInner) heldReply++;
      if (requestOriginal.readValid && readReady) begin
        readBusy <= 1;
        readAddress <= requestOriginal.readAddress;
        readWait <= 3;
        reads++;
      end else if (readBusy) begin
        readWait <= readWait - 1;
        if (readWait == 1) begin
          for (int b = 0; b < 64; b++) lineResponse.data[b*8+:8] <= memory[readAddress+32'(b)];
          lineResponse.valid <= 1;
          readBusy <= 0;
        end
      end
      if (requestOriginal.writeValid && writeReady) begin
        writeBusy <= 1;
        writeAddress <= requestOriginal.writeAddress;
        writeData <= requestOriginal.writeData;
        writeWait <= 17;
        writes++;
      end else if (writeBusy) begin
        writeWait <= writeWait - 1;
        if (writeWait == 1) begin
          for (int b = 0; b < 64; b++) memory[writeAddress+32'(b)] <= writeData[b*8+:8];
          writeBusy <= 0;
          writeDone <= 1;
        end
      end
    end
  end

  task automatic offer(input bit wr, input int addr, input logic [31:0] value,
                       input logic [1:0] size, input logic [3:0] mask);
    @(negedge clock);
    cpuRequest = '{valid:1'b1, write:wr, address:32'(addr), writeData:value, writeStrobe:mask, size:size};
    do @(posedge clock); while (!readyOriginal);
    @(negedge clock);
    cpuRequest.valid = 0;
  endtask
  initial begin
    for (int a = 0; a < 32768; a++) memory[a] = 8'(a ^ (a >> 8) ^ 'h5a);
    repeat (2) @(negedge clock);
    resetN = 1;
    while (!initOriginal) @(negedge clock);
    // Split Store on a miss, conflicting dirty victim, split Store hit,
    // refetch; then exercise every bank, offset, size and queue wraparound.
    offer(1, 7, 32'h11223380, MEM_WORD, 4'b1111);
    offer(0, 8192, 0, MEM_WORD, 0);
    offer(1, 8199, 32'h55667788, MEM_WORD, 4'b0111);
    offer(0, 7, 0, MEM_WORD, 0);
    while (!idleOriginal) @(negedge clock);
    for (int i = 0; i < 16; i++) offer(i[0], i * 3, 32'(i), MEM_WORD, 4'b1111);
    for (int i = 0; i < 800; i++) begin
      int address, offset, bytes;
      logic [1:0] size;
      logic [3:0] mask;
      randomState = {randomState[30:0], randomState[31] ^ randomState[21] ^ randomState[1] ^ randomState[0]};
      size = 2'(i % 3);
      bytes = 1 << size;
      offset = (i * 7) % (65 - bytes);
      address = (int'(randomState[14:8]) << 6) + (int'(randomState[16:15]) << 13) + offset;
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
    for (int row = 0; row < 128; row++)
      assert (!original.validInner[row] && !converted.validInner[row]);
    offer(0, 64, 0, MEM_WORD, 0);
    while (!idleOriginal) @(negedge clock);
    assert (accepted == 822 && responses > 100 && reads > 100 && writes > 100 &&
            beats == reads * 8 && fullBlocked > 0 && simultaneous > 0 && heldReply > 0)
      else $fatal(1, "coverage incomplete: accepts=%0d responses=%0d reads=%0d writes=%0d beats=%0d full=%0d simultaneous=%0d held=%0d",
                  accepted, responses, reads, writes, beats, fullBlocked, simultaneous, heldReply);
    $display("PASS frontend equivalence: cycles=%0d requests=%0d reads=%0d writes=%0d beats=%0d", cycle, accepted, reads, writes, beats);
    $finish;
  end
  initial begin #1000000; $fatal(1, "frontend equivalence timeout"); end
endmodule
