module tb_lsu_tagged;
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
  logic memoryReady = 0;
  data_transaction_t requestId, responseId = 0;
  data_transaction_t owners [8];
  logic [2:0] rows [8];
  int sends = 0;
  store_data_input_t storeData [0:0];
  logic [2:0] storeIndex [0:0];
  load_result_output_t result;
  rv32_lsu #(.TAGGED_DMEM(1'b1)) dut (
    .coreStoppedInput(1'b0),
    .clkInput(clock), .rstNInput(resetN), .flushInfoInput(flush),
    .loadAllocationInput(allocation), .loadAllocReadyOutput(allocationReady), .loadAllocIndexOutput(allocationIndex),
    .storeAllocationInput(store_allocation_input_t'('0)), .storeAllocReadyOutput(), .storeAllocIndexOutput(),
    .storeDataInput(storeData), .storeDataIndexInput(storeIndex),
    .addressInput(address), .addressIndexInput(addressIndex), .writebackInput('0),
    .loadResultOutput(result), .loadResultReadyInput(1'b0), .robRetireInput(rob_retirement_input_t'('0)),
    .storeCompleteOutput(), .storeCommitInput(store_commit_input_t'('0)), .storeCommitIndexInput(3'b0),
    .storeCommitReadyOutput(), .storeRetirementOutput(),
    .dmemRequestOutput(request), .dmemReqReadyInput(memoryReady), .dmemResponseInput(response),
    .dmemReqTransactionOutput(requestId), .dmemRspTransactionInput(responseId), .lqCountOutput(), .sqCountOutput()
  );
  always @(posedge clock) if (resetN && request.valid && memoryReady) begin
    owners[request.address[4:2]] = requestId;
    sends++;
  end
  task automatic reserve(input int name, input int tag, input mem_size_e size, input logic isUnsigned);
    @(negedge clock);
    allocation = '{valid:1'b1, robTag:rob_tag_t'(tag), destinationPhy:phy_tag_t'(tag+31), size:size, isUnsigned:isUnsigned};
    #1;
    assert (allocationReady);
    rows[name] = allocationIndex;
    @(negedge clock);
    allocation.valid = 0;
    addressIndex = rows[name];
    address = '{valid:1'b1, isStore:1'b0, robTag:rob_tag_t'(tag), address:32'(name*4)};
    @(negedge clock);
    address.valid = 0;
  endtask
  task automatic reply(input int name, input logic [31:0] value);
    @(negedge clock);
    response = '{valid:1'b1, readData:value};
    responseId = owners[name];
    @(negedge clock);
    response.valid = 0;
  endtask
  initial begin
    storeData[0] = '0;
    storeIndex[0] = 0;
    repeat (2) @(negedge clock);
    resetN = 1;
    reserve(0,1,MEM_WORD,0);
    reserve(1,3,MEM_BYTE,0);
    reserve(2,4,MEM_HALF,1);
    reserve(3,5,MEM_BYTE,1);
    memoryReady = 1;
    while (sends < 4) @(negedge clock);
    memoryReady = 0;
    // Complete the third request before the first, preserving its frozen width.
    reply(2,32'habcdff80);
    assert (dut.lqResultReadyInner[rows[2]] && dut.lqResultInner[rows[2]] == 32'hff80 &&
            !dut.lqResultReadyInner[rows[0]]) else $fatal(1,"out-of-order width/identity failed");
    @(negedge clock);
    flush = '{valid:1'b1,robTag:rob_tag_t'(2)};
    @(negedge clock);
    flush.valid = 0;
    // A late cancelled response frees ONLY its owner, without resurrecting LQ.
    reply(1,32'h80);
    assert (!dut.lqValidInner[rows[1]] && !dut.lqResultReadyInner[rows[1]]);
    reserve(4,6,MEM_BYTE,0);
    assert (rows[4] == rows[1]);
    memoryReady = 1;
    while (sends < 5) @(negedge clock);
    memoryReady = 0;
    reply(3,32'hdeadbeef);
    assert (!dut.lqResultReadyInner[rows[4]]) else $fatal(1,"cancelled owner corrupted reused LQ");
    reply(4,32'h80);
    assert (dut.lqResultReadyInner[rows[4]] && dut.lqResultInner[rows[4]] == 32'hffffff80);
    reply(0,32'h11223344);
    assert (dut.lqResultReadyInner[rows[0]] && dut.lqResultInner[rows[0]] == 32'h11223344);
    assert (dut.fifoCountInner == 0);
    $display("PASS tagged LSU: out-of-order/sign/flush/late-response/LQ-reuse");
    $finish;
  end
  initial begin #10000; $fatal(1,"tagged LSU timeout"); end
endmodule
