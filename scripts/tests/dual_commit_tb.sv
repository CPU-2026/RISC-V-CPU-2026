// Directed producer/consumer contracts; real-CPU/ISA tests complement this TB.
module dual_commit_tb;
  import rv32_pkg::*;
  logic clk = 0, rst = 0;
  logic freeze;
  rob_allocation_input_t alloc;
  logic allocReady;
  rob_tag_t allocTag;
  rob_completion_t [5:0] completion;
  store_completion_output_t stores;
  rob_flush_input_t flush;
  rob_lookup_input_t [4:0] lookup;
  rob_lookup_output_t [4:0] lookupResult;
  rob_commit_output_t [1:0] commits;
  logic [1:0] isStore, ready, fire;
  rob_status_output_t status;
  logic [4:0] count;
  rob_replay_narrow_t [RECOVERY_WIDTH-1:0] replay;
  rob_replay_ras_t [RECOVERY_WIDTH-1:0] rasReplay;
  rv32_rob #(.COMMIT_WIDTH(2)) rob (
    .clkInput(clk), .rstNInput(rst), .freezeInput(freeze),
    .allocInput(alloc), .allocReadyOutput(allocReady), .allocTagOutput(allocTag),
    .completionInput(completion), .storeReadyInput(stores), .flushInput(flush),
    .lookupInput(lookup), .lookupOutput(lookupResult), .commitOutput(commits),
    .commitStoreOutput(isStore), .commitReadyInput(ready), .commitFireOutput(fire),
    .statusOutput(status), .countOutput(count), .replayOffsetInput(rob_tag_t'(0)),
    .replayNarrowOutput(replay), .replayRasOutput(rasReplay)
  );

  rat_read_input_t ratRead;
  rat_read_output_t ratResult;
  rat_rename_input_t renamePort;
  rat_rename_output_t renameResult;
  rat_restore_input_t restore;
  recovery_step_t recovery;
  rat_commit_input_t [1:0] ratCommit;
  rv32_rat #(.COMMIT_WIDTH(2)) rat (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0),
    .readInput(ratRead), .readOutput(ratResult), .renameInput(renamePort), .renameOutput(renameResult),
    .restoreInput(restore), .recoveryInput(recovery), .replayInput(replay), .commitInput(ratCommit)
  );

  prf_allocation_input_t phyAlloc;
  logic phyReady;
  phy_tag_t phy;
  prf_free_input_t [1:0] frees;
  prf_read_input_t [2:0] phyRead;
  prf_read_output_t [2:0] phyResult;
  cdb_result_t [1:0] wb;
  logic [PRF_ENTRIES-1:0] phyReadyVector;
  logic [$clog2(PRF_ENTRIES+1)-1:0] freeCount;
  rv32_prf #(.COMMIT_WIDTH(2), .WRITEBACK_PORTS(2)) prf (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0), .allocationInput(phyAlloc),
    .allocReadyOutput(phyReady), .allocPhyOutput(phy), .freeInput(frees),
    .restoreInput('0), .recoveryInput('0), .restoreCountInput(5'b0), .replayInput(replay),
    .readInput(phyRead), .readOutput(phyResult), .writebackInput(wb),
    .readyVectorOutput(phyReadyVector), .freeCountOutput(freeCount)
  );

  predictor_fetch_info_t fetchInfo;
  squash_input_t squash;
  rob_predictor_input_t [1:0] rasInput;
  logic [15:0] rasDepth;
  logic [31:0] rasTarget;
  rv32_bpu_ras #(.COMMIT_WIDTH(2)) ras (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0), .fetchInfoInput(fetchInfo),
    .squashInput(squash), .robInput(rasInput), .recoveryInput(recovery),
    .rasTopOutput(rasDepth), .queryRetTargetOutput(rasTarget)
  );

  load_allocation_input_t lqAlloc;
  store_allocation_input_t sqAlloc;
  logic lqReady, sqReady;
  logic [2:0] lqIndex, sqIndex, addressIndex;
  store_data_input_t storeData [0:0];
  logic [2:0] storeDataIndex [0:0];
  lsu_address_input_t addressPort;
  load_result_output_t loadResult;
  rob_retirement_input_t [1:0] retirePort;
  store_completion_output_t storeCompletion;
  store_commit_input_t [1:0] storePort;
  logic [1:0][2:0] storeIndex;
  logic [1:0] storeReady;
  data_memory_request_output_t [1:0] storePayload;
  data_memory_request_output_t request;
  data_memory_response_input_t response;
  logic memoryReady;
  data_transaction_t transaction;
  logic [3:0] loads, queuedStores;
  rv32_lsu #(.COMMIT_WIDTH(2), .WRITEBACK_PORTS(2)) lsu (
    .clkInput(clk), .rstNInput(rst), .coreStoppedInput(1'b0), .flushInfoInput(flush),
    .loadAllocationInput(lqAlloc), .loadAllocReadyOutput(lqReady), .loadAllocIndexOutput(lqIndex),
    .storeAllocationInput(sqAlloc), .storeAllocReadyOutput(sqReady), .storeAllocIndexOutput(sqIndex),
    .storeDataInput(storeData), .storeDataIndexInput(storeDataIndex),
    .addressInput(addressPort), .addressIndexInput(addressIndex), .writebackInput(wb),
    .loadResultOutput(loadResult), .loadResultReadyInput(1'b1), .robRetireInput(retirePort),
    .storeCompleteOutput(storeCompletion), .storeCommitInput(storePort), .storeCommitIndexInput(storeIndex),
    .storeCommitReadyOutput(storeReady), .storeRetirementOutput(storePayload),
    .dmemRequestOutput(request), .dmemReqReadyInput(memoryReady), .dmemResponseInput(response),
    .dmemReqTransactionOutput(transaction), .dmemRspTransactionInput(data_transaction_t'(0)),
    .lqCountOutput(loads), .sqCountOutput(queuedStores)
  );

  task automatic tick;
    #1; clk = 1; #1; clk = 0; #1;
  endtask
  task automatic reset_all;
    rst = 0; alloc = '0; completion = '0; stores = '0; flush = '0; lookup = '0;
    freeze = 0; ready = 0; ratCommit = '0; renamePort = '0; restore = '0;
    recovery = '0; ratRead = '0; phyAlloc = '0; frees = '0; phyRead = '0; wb = '0;
    fetchInfo = '0; squash = '0; rasInput = '0;
    lqAlloc = '0; sqAlloc = '0; storeData[0] = '0; storeDataIndex[0] = 0;
    addressPort = '0; addressIndex = 0; retirePort = '0; storePort = '0;
    storeIndex = '0; memoryReady = 0; response = '0;
    tick(); rst = 1; tick();
  endtask
  task automatic push(input bit done, input bit halt, input bit exception);
    alloc = '0; alloc.valid = 1; alloc.ready = done;
    alloc.isHalt = halt; alloc.hasException = exception;
    #1; assert(allocReady) else $fatal(1, "allocation blocked");
    tick(); alloc = '0;
  endtask
  task automatic expect_fire(input logic [1:0] expected);
    #1; assert(fire == expected) else $fatal(1, "fire %b expected %b", fire, expected);
  endtask

  initial begin
    reset_all();
    push(0,0,0); push(1,0,0); ready = 3;
    expect_fire(0); // Never bypass the old head.
    completion[0] = '{valid:1'b1, robTag:rob_tag_t'(0), exception:1'b0};
    expect_fire(0); // No WB -> retirement bypass.
    tick(); completion = '0; expect_fire(3); tick();
    assert(count == 0 && status.headTag == 2) else $fatal(1, "dual head/count update");
    ready = 0; push(1,0,0); push(1,0,0);
    ready = 2; expect_fire(0); // Consumer lane 1 cannot skip lane 0.
    ready = 1; expect_fire(1); tick(); ready = 3; expect_fire(1); tick();
    ready = 0; push(1,0,0); push(0,0,0); ready = 3; expect_fire(1); tick(); expect_fire(0);
    reset_all(); push(1,1,0); push(1,0,0); ready = 3; expect_fire(1);
    // Exception-shaped compatibility bits no longer truncate retirement. This
    // is not an exception-behavior test: the active core never drives them high.
    reset_all(); push(1,0,1); push(1,0,0); ready = 3; expect_fire(3);
    assert(!commits[0].hasException && !commits[1].hasException) else $fatal(1, "exception state remains");
    reset_all(); push(1,0,0); push(1,0,1); ready = 3; expect_fire(3);
    freeze = 1; expect_fire(0); freeze = 0;
    reset_all();
    // Two retirements cross slot 15 and the full epoch/tag wrap repeatedly.
    for (int pair = 0; pair < 40; pair++) begin
      ready = 0; push(1,0,0); push(1,0,0); ready = 3; expect_fire(3); tick();
      assert(count == 0 && status.headTag == rob_tag_t'((pair+1)*2)) else $fatal(1, "ROB wrap");
    end

    // Same rd: the younger committed mapping wins the single masked SRAM word.
    ratCommit[0] = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(40)};
    ratCommit[1] = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(41)};
    tick(); ratCommit = '0;
    restore.valid = 1; squash.valid = 1; tick(); restore = '0; squash = '0;
    recovery.active = 1; recovery.first = 1; recovery.liveCount = 0; tick(); recovery = '0;
    ratRead.source1Arch = 5; #1;
    assert(ratResult.source1Phy == 41) else $fatal(1, "same-rd commit SRAM priority");

    reset_all();
    for (int i = 32; i <= 40; i++) begin
      #1; assert(phyReady && phy == phy_tag_t'(i)) else $fatal(1, "FIFO allocation order");
      phyAlloc.valid = 1; tick();
    end
    phyAlloc = '0;
    frees[0] = '{valid:1'b1, physicalRegister:phy_tag_t'(5)};
    frees[1] = '{valid:1'b1, physicalRegister:phy_tag_t'(40)};
    tick(); frees = '0;
    assert(freeCount == 9) else $fatal(1, "dual oldPhy release count");
    for (int i = 0; i < 9; i++) begin
      #1; assert(phy == phy_tag_t'(i < 7 ? 41+i : i == 7 ? 5 : 40)) else $fatal(1, "FIFO release order");
      phyAlloc.valid = 1; tick();
    end
    phyAlloc = '0;

    // Two calls, then pop+push followed by pop+push to the same SRAM stack row.
    rasInput[0].willCommit = 1; rasInput[0].isHeadCall = 1; rasInput[0].headProgramCounter = 32'h100;
    rasInput[1].willCommit = 1; rasInput[1].isHeadCall = 1; rasInput[1].headProgramCounter = 32'h200;
    tick(); rasInput = '0;
    squash.valid = 1; tick(); squash = '0;
    recovery.active = 1; recovery.first = 1; tick(); recovery = '0;
    assert(rasDepth == 2 && rasTarget == 32'h204) else $fatal(1, "dual call baseline");
    rasInput[0].willCommit = 1; rasInput[0].isHeadCall = 1; rasInput[0].isHeadReturn = 1;
    rasInput[0].headProgramCounter = 32'h300;
    rasInput[1] = rasInput[0]; rasInput[1].headProgramCounter = 32'h400;
    tick(); rasInput = '0;
    squash.valid = 1; tick(); squash = '0;
    recovery.active = 1; recovery.first = 1; tick(); recovery = '0;
    assert(rasDepth == 2 && rasTarget == 32'h404) else $fatal(1, "RAS same-row younger winner");
    reset_all();
    for (int lane = 0; lane < 2; lane++) begin
      sqAlloc = '{valid:1'b1, robTag:rob_tag_t'(lane), size:MEM_WORD,
        dataReady:1'b1, dataTag:phy_tag_t'(0), dataValue:32'(42+lane)};
      addressPort = '{valid:1'b1, isStore:1'b1, robTag:rob_tag_t'(lane), address:32'(4096+4*lane)};
      addressIndex = 3'(lane);
      #1; assert(sqReady && sqIndex == 3'(lane)) else $fatal(1, "SQ allocation");
      tick();
    end
    sqAlloc = '0; addressPort = '0;
    storeIndex[0] = 0; storeIndex[1] = 1;
    storePort[0] = '{valid:1'b1, robTag:rob_tag_t'(0)};
    storePort[1] = '{valid:1'b1, robTag:rob_tag_t'(1)};
    #1; assert(storeReady == 3 && queuedStores == 2) else $fatal(1, "dual Store ready");
    retirePort[0] = '{valid:1'b1, robTag:rob_tag_t'(0)};
    retirePort[1] = '{valid:1'b1, robTag:rob_tag_t'(1)};
    tick(); storePort = '0; retirePort = '0;
    flush = '{valid:1'b1, robTag:rob_tag_t'(0)}; tick(); flush = '0;
    assert(queuedStores == 2) else $fatal(1, "committed Stores lost on recovery");
    memoryReady = 1;
    for (int lane = 0; lane < 2; lane++) begin
      #1; assert(request.valid && request.write && request.address == 32'(4096+4*lane) &&
        request.writeData == 32'(42+lane)) else $fatal(1, "SQ drain order");
      tick();
    end
    assert(queuedStores == 0) else $fatal(1, "SQ drain did not release both rows");
    for (int lane = 0; lane < 2; lane++) begin
      lqAlloc = '{valid:1'b1, robTag:rob_tag_t'(2+lane), destinationPhy:phy_tag_t'(32+lane),
        size:MEM_WORD, isUnsigned:1'b1};
      addressPort = '{valid:1'b1, isStore:1'b0, robTag:rob_tag_t'(2+lane), address:32'(4096+4*lane)};
      addressIndex = 3'(lane); tick();
    end
    lqAlloc = '0; addressPort = '0; tick();
    response = '{valid:1'b1, readData:32'd42}; tick();
    response.readData = 43; tick(); response = '0; tick(); tick();
    assert(loads == 2) else $fatal(1, "Load reservation freed before retirement");
    retirePort[0] = '{valid:1'b1, robTag:rob_tag_t'(2)};
    retirePort[1] = '{valid:1'b1, robTag:rob_tag_t'(3)};
    tick(); retirePort = '0;
    assert(loads == 0) else $fatal(1, "dual Load retirement did not release both rows");
    $display("PASS dual commit prefix, WB boundary, termination, ROB wrap, RAT, FIFO, RAS, LSU");
    $finish;
  end
endmodule
