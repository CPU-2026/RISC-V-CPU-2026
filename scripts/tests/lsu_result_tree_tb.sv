// Real LSU allocations, tagged replies and CDB grants. No internal state pokes.
module tb_lsu_result_tree;
  import rv32_pkg::*;
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0;
  rob_flush_input_t flush = '0;
  load_allocation_input_t allocation = '0;
  logic allocationReady;
  logic [2:0] allocationIndex;
  lsu_address_input_t address = '0;
  logic [2:0] addressIndex = 0;
  data_memory_request_output_t request;
  data_memory_response_input_t response = '0;
  logic memoryReady = 0, resultReady = 0;
  data_transaction_t requestId, responseId = 0;
  data_transaction_t owners [8];
  load_result_output_t result;
  store_data_input_t storeData [0:0];
  logic [2:0] storeIndex [0:0];
  int sends = 0, broadcasts = 0, checks = 0, rounds = 0;
  int ages [8];

  rv32_lsu #(.TAGGED_DMEM(1'b1)) dut (
    .clkInput(clock), .rstNInput(resetN), .coreStoppedInput(1'b0), .flushInfoInput(flush),
    .loadAllocationInput(allocation), .loadAllocReadyOutput(allocationReady), .loadAllocIndexOutput(allocationIndex),
    .storeAllocationInput('0), .storeAllocReadyOutput(), .storeAllocIndexOutput(),
    .storeDataInput(storeData), .storeDataIndexInput(storeIndex), .addressInput(address), .addressIndexInput(addressIndex),
    .writebackInput('0), .loadResultOutput(result), .loadResultReadyInput(resultReady), .robRetireInput('0),
    .storeCompleteOutput(), .storeCommitInput('0), .storeCommitIndexInput('0), .storeCommitReadyOutput(),
    .storeRetirementOutput(), .dmemRequestOutput(request), .dmemReqReadyInput(memoryReady),
    .dmemResponseInput(response), .dmemReqTransactionOutput(requestId), .dmemRspTransactionInput(responseId),
    .lqCountOutput(), .sqCountOutput()
  );

  function automatic bit older_ref(input rob_tag_t a, input rob_tag_t b);
    int distance;
    distance = (int'(b)-int'(a)) & ((1 << ROB_TAG_W)-1);
    return distance > 0 && distance < (1 << (ROB_TAG_W-1));
  endfunction

  function automatic logic [31:0] value_ref(input logic [31:0] raw, input mem_size_e size, input bit unsign);
    case (size)
      MEM_BYTE: return unsign ? {24'b0,raw[7:0]} : {{24{raw[7]}},raw[7:0]};
      MEM_HALF: return unsign ? {16'b0,raw[15:0]} : {{16{raw[15]}},raw[15:0]};
      default: return raw;
    endcase
  endfunction

  // Independent serial reference reads only pre-edge row state. It catches
  // predicate changes, a reply-to-CDB bypass, wrong index/tag and lost grants.
  always @(posedge clock) if (resetN) begin
    bit found, live;
    int winner;
    found = 0; winner = 0;
    for (int i = 0; i < 8; i++) begin
      if (dut.lqValidInner[i] && dut.lqResultReadyInner[i] && !dut.lqBroadcastedInner[i] &&
          (!found || older_ref(dut.lqTagInner[i], dut.lqTagInner[winner]))) begin
        found = 1; winner = i;
      end
    end
    live = found && (!flush.valid || older_ref(dut.lqTagInner[winner], flush.robTag));
    assert(dut.resultSelectFoundInner == found && dut.resultSelectIndexInner == 3'(winner))
      else $fatal(1, "result selector differs from serial reference round=%0d", rounds);
    assert(result.valid == live) else $fatal(1, "result/flush qualification differs");
    if (live) begin
      assert(result.robTag == dut.lqTagInner[winner] && result.destinationPhy == dut.lqDestInner[winner] &&
             result.value == value_ref(dut.lqResultInner[winner], dut.lqSizeInner[winner], dut.lqUnsignedInner[winner]))
        else $fatal(1, "result tag/PRF/value association lost");
    end
    if (request.valid && memoryReady) begin
      assert(!request.write) else $fatal(1, "unexpected Store");
      owners[request.address[4:2]] = requestId;
      sends++;
    end
    if (result.valid && resultReady) broadcasts++;
    checks++;
  end

  task automatic reserve(input int name, input int tag);
    @(negedge clock);
    allocation = '{valid:1'b1, robTag:rob_tag_t'(tag), destinationPhy:phy_tag_t'(32+name),
      size:mem_size_e'(name % 3), isUnsigned:1'(name & 1)};
    #1; assert(allocationReady && allocationIndex == 3'(name)) else $fatal(1, "allocation failed");
    @(negedge clock);
    allocation.valid = 0;
    addressIndex = 3'(name);
    address = '{valid:1'b1, isStore:1'b0, robTag:rob_tag_t'(tag), address:32'(4096+4*name)};
    @(negedge clock); address.valid = 0;
  endtask

  task automatic reply(input int name);
    @(negedge clock);
    response = '{valid:1'b1, readData:32'habcdff80 + 32'(name)};
    responseId = owners[name];
    @(negedge clock); response.valid = 0;
  endtask

  task automatic drain(input int count);
    int target;
    target = broadcasts + count;
    @(negedge clock); resultReady = 1;
    while (broadcasts < target) @(negedge clock);
    resultReady = 0;
  endtask

  initial begin
    storeData[0] = '0; storeIndex[0] = 0;
    for (int base = 0; base < (1 << ROB_TAG_W); base++) begin
      for (int scenario = 0; scenario < 3; scenario++) begin
        int oldest, expected, stalled;
        @(negedge clock);
        resetN = 0; allocation = '0; address = '0; response = '0; flush = '0;
        memoryReady = 0; resultReady = 0; sends = 0; broadcasts = 0;
        repeat (2) @(negedge clock); resetN = 1;
        oldest = 0;
        for (int i = 0; i < 8; i++) begin
          ages[i] = ((3*i + base) & 7) << 1;
          if (ages[i] == 0) oldest = i;
          reserve(i, base+ages[i]);
        end
        memoryReady = 1;
        while (sends < 8) @(negedge clock);
        memoryReady = 0;
        // Completion order deliberately differs from slot and ROB age order.
        for (int i = 0; i < 8; i++) begin
          int name;
          name = (5*i+3) & 7;
          if (scenario != 1 || name != oldest) reply(name);
        end
        stalled = broadcasts;
        repeat (3) @(negedge clock);
        assert(broadcasts == stalled) else $fatal(1, "CDB backpressure lost");
        if (scenario == 1) begin
          drain(7); // An uncompleted old Load does not block completed ones.
          reply(oldest);
          drain(1);
          expected = 8;
        end else if (scenario == 2) begin
          // Recovery is bounded by a non-Load control instruction: the odd
          // tag is absent from these even-age LQ rows. The boundary survives.
          @(negedge clock); flush = '{valid:1'b1, robTag:rob_tag_t'(base+7)};
          @(negedge clock); flush.valid = 0;
          drain(4); // Ages 8..14 were cancelled before they could broadcast.
          expected = 4;
        end else begin
          drain(8);
          expected = 8;
        end
        repeat (2) @(negedge clock);
        assert(broadcasts == expected && !result.valid && dut.fifoCountInner == 0)
          else $fatal(1, "result did not drain exactly once round=%0d grants=%0d expected=%0d valid=%0d owners=%0d",
            rounds, broadcasts, expected, result.valid, dut.fifoCountInner);
        rounds++;
      end
    end
    $display("PASS LSU result tree rounds=%0d pre-edge-checks=%0d: eight-ready/partial-ready/tag-wrap/backpressure/flush/width", rounds, checks);
    $finish;
  end
  initial begin #1000000; $fatal(1, "result tree timeout"); end
endmodule
