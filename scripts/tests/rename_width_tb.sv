module tb_rename_width;
  import rv32_pkg::*;
  logic clk = 0, rst = 0;
  always #5 clk = !clk;
  task automatic step;
    @(posedge clk); #1;
    @(negedge clk); #1;
  endtask
  rat_read_input_t ratRead, ratReadSecond;
  rat_read_output_t ratOut, ratOutSecond;
  rat_rename_input_t rename0, rename1;
  rat_rename_output_t old0, old1;
  rat_commit_input_t [1:0] commits;
  rob_replay_narrow_t [RECOVERY_WIDTH-1:0] replay;
  rv32_rat #(.COMMIT_WIDTH(2), .RENAME_WIDTH(2)) rat (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0),
    .readInput(ratRead), .readOutput(ratOut), .readSecondInput(ratReadSecond), .readSecondOutput(ratOutSecond),
    .renameInput(rename0), .renameOutput(old0), .renameSecondInput(rename1), .renameSecondOutput(old1),
    .restoreInput('0), .recoveryInput('0), .replayInput(replay), .commitInput(commits)
  );

  prf_allocation_input_t pa0, pa1;
  logic pr0, pr1;
  phy_tag_t pp0, pp1;
  prf_free_input_t [1:0] frees;
  prf_read_input_t [3:0] reads;
  prf_read_output_t [3:0] values;
  cdb_result_t [1:0] wb;
  logic [PRF_ENTRIES-1:0] ready;
  logic [$clog2(PRF_ENTRIES+1)-1:0] freeCount;
  rv32_prf #(.COMMIT_WIDTH(2), .RENAME_WIDTH(2), .WRITEBACK_PORTS(2), .READ_PORTS(4)) prf (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0), .allocationInput(pa0), .allocationSecondInput(pa1),
    .allocReadyOutput(pr0), .allocPhyOutput(pp0), .allocSecondReadyOutput(pr1), .allocSecondPhyOutput(pp1),
    .freeInput(frees), .restoreInput('0), .recoveryInput('0), .restoreCountInput('0), .replayInput(replay),
    .readInput(reads), .readOutput(values), .writebackInput(wb), .readyVectorOutput(ready), .freeCountOutput(freeCount)
  );

  rob_allocation_input_t ra0, ra1;
  logic rr0, rr1;
  rob_tag_t rt0, rt1;
  rob_completion_t [5:0] complete;
  rob_lookup_input_t [4:0] lookups;
  rob_lookup_output_t [4:0] lookupValues;
  rob_commit_output_t [1:0] robCommits;
  logic [1:0] retireReady, retireFire;
  logic [2:0] robCount;
  rv32_rob #(.DEPTH(4), .COMMIT_WIDTH(2), .RENAME_WIDTH(2)) rob (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0), .allocInput(ra0), .allocReadyOutput(rr0),
    .allocTagOutput(rt0), .allocSecondInput(ra1), .allocSecondReadyOutput(rr1), .allocSecondTagOutput(rt1),
    .completionInput(complete), .storeReadyInput('0), .flushInput('0), .lookupInput(lookups), .lookupOutput(lookupValues),
    .commitOutput(robCommits), .commitStoreOutput(), .commitReadyInput(retireReady), .commitFireOutput(retireFire),
    .statusOutput(), .countOutput(robCount), .replayOffsetInput('0), .replayNarrowOutput(), .replayRasOutput()
  );

  rs_allocation_input_t sa0, sa1;
  logic sr0, sr1, issueReady;
  rob_flush_input_t rsFlush;
  rs_issue_output_t issued;
  logic [2:0] occupancy;
  rv32_rs #(.DEPTH(4), .AUX_W(1), .RENAME_WIDTH(2), .WRITEBACK_PORTS(2),
            .REUSE_ON_ISSUE(1'b1), .WB_ISSUE_BYPASS(1'b1)) rs (
    .clkInput(clk), .rstNInput(rst), .freezeInput(1'b0), .flushInfoInput(rsFlush),
    .allocInput(sa0), .allocAuxInput(1'b0), .allocReadyOutput(sr0),
    .allocSecondInput(sa1), .allocSecondAuxInput(1'b0), .allocSecondReadyOutput(sr1),
    .writebackInput(wb), .issueOutput(issued), .issueReadyInput(issueReady), .issueAuxOutput(),
    .issueLaneValidOutput(), .issueLaneOutput(), .issueLaneAuxOutput(), .occupancyOutput(occupancy)
  );

  load_allocation_input_t la0, la1;
  store_allocation_input_t st0, st1;
  logic lr0, lr1, str0, str1;
  logic li0, li1, si0, si1;
  logic [1:0] lqCount, sqCount;
  rob_flush_input_t memFlush;
  lsu_address_input_t address;
  logic addressIndex;
  store_data_input_t storeData [0:0];
  logic storeDataIndex [0:0];
  store_commit_input_t [1:0] storeCommit;
  logic [1:0][0:0] storeCommitIndex;
  rob_retirement_input_t [1:0] retirement;
  data_memory_request_output_t request;
  logic memoryReady;
  rv32_lsu #(.LQ_DEPTH(2), .SQ_DEPTH(2), .COMMIT_WIDTH(2), .RENAME_WIDTH(2), .WRITEBACK_PORTS(2)) lsu (
    .clkInput(clk), .rstNInput(rst), .coreStoppedInput(1'b0), .flushInfoInput(memFlush),
    .loadAllocationInput(la0), .loadAllocReadyOutput(lr0), .loadAllocIndexOutput(li0),
    .loadAllocationSecondInput(la1), .loadAllocSecondReadyOutput(lr1), .loadAllocSecondIndexOutput(li1),
    .storeAllocationInput(st0), .storeAllocReadyOutput(str0), .storeAllocIndexOutput(si0),
    .storeAllocationSecondInput(st1), .storeAllocSecondReadyOutput(str1), .storeAllocSecondIndexOutput(si1),
    .storeDataInput(storeData), .storeDataIndexInput(storeDataIndex),
    .addressInput(address), .addressIndexInput(addressIndex), .writebackInput(wb),
    .loadResultOutput(), .loadResultReadyInput(1'b0), .robRetireInput(retirement), .storeCompleteOutput(),
    .storeCommitInput(storeCommit), .storeCommitIndexInput(storeCommitIndex), .storeCommitReadyOutput(),
    .storeRetirementOutput(), .dmemRequestOutput(request), .dmemReqReadyInput(memoryReady), .dmemResponseInput('0),
    .dmemReqTransactionOutput(), .dmemRspTransactionInput('0), .lqCountOutput(lqCount), .sqCountOutput(sqCount)
  );

  initial begin
    ratRead = '0; ratReadSecond = '0; rename0 = '0; rename1 = '0; commits = '0; replay = '0;
    pa0 = '0; pa1 = '0; frees = '0; reads = '0; wb = '0;
    ra0 = '0; ra1 = '0; complete = '0; lookups = '0; retireReady = '0;
    sa0 = '0; sa1 = '0; issueReady = 0; rsFlush = '0;
    la0 = '0; la1 = '0; st0 = '0; st1 = '0; memFlush = '0;
    address = '0; addressIndex = 0; storeData[0] = '0; storeDataIndex[0] = 0;
    storeCommit = '0; storeCommitIndex = '0; retirement = '0; memoryReady = 0;
    step(); rst = 1; #1;

    // WAW folds to the younger mapping; read ports still see OLD state.
    ratRead.source1Arch = 5; ratReadSecond.source1Arch = 5;
    rename0 = '{valid:1, architecturalRegister:5, physicalRegister:32};
    rename1 = '{valid:1, architecturalRegister:5, physicalRegister:33};
    #1; assert (ratOut.source1Phy == 5 && ratOutSecond.source1Phy == 5);
    step(); rename0.valid = 0; rename1.valid = 0; #1;
    assert (ratOut.source1Phy == 33 && ratOutSecond.source1Phy == 33);

    // Two distinct physical registers; LINK starts ready, arithmetic does not.
    pa0 = '{valid:1, valueValid:1, value:111}; pa1 = '{valid:1, valueValid:0, value:0};
    #1; assert (pr0 && pr1 && pp0 == 32 && pp1 == 33);
    step(); pa0.valid = 0; pa1.valid = 0;
    reads[0].physicalRegister = 32; reads[1].physicalRegister = 33; #1;
    assert (freeCount == 14 && values[0].ready && values[0].value == 111 && !values[1].ready);
    wb[0] = '{valid:1, phyTag:32, value:333}; wb[1] = '{valid:1, phyTag:33, value:222};
    step(); wb = '0; #1;
    assert (values[0].value == 333 && values[1].ready && values[1].value == 222);
    for (int pair = 0; pair < 7; pair++) begin
      pa0.valid = 1; pa1.valid = 1;
      #1; assert (pr0 && pr1 && pp0 == phy_tag_t'(34+2*pair) && pp1 == phy_tag_t'(35+2*pair));
      step();
    end
    pa0.valid = 0; pa1.valid = 0; #1; assert (freeCount == 0 && !pr0 && !pr1);
    for (int round = 0; round < 4; round++) begin
      for (int pair = 0; pair < 8; pair++) begin
        frees[0] = '{valid:1, physicalRegister:phy_tag_t'(32+2*pair)};
        frees[1] = '{valid:1, physicalRegister:phy_tag_t'(33+2*pair)};
        step();
      end
      frees = '0;
      for (int pair = 0; pair < 8; pair++) begin
        pa0.valid = 1; pa1.valid = 1; #1;
        assert (pr0 && pr1 && pp0 == phy_tag_t'(32+2*pair) && pp1 == phy_tag_t'(33+2*pair));
        step();
      end
      pa0.valid = 0; pa1.valid = 0; #1; assert (freeCount == 0 && !pr0 && !pr1);
    end

    // ROB admits two old-free slots, never borrows same-cycle retirement.
    ra0.valid = 1; ra0.ready = 1; ra1.valid = 1; ra1.ready = 1;
    #1; assert (rr0 && rr1 && rt0 == 0 && rt1 == 1); step();
    #1; assert (robCount == 2 && rt0 == 2 && rt1 == 3); step();
    ra0.valid = 0; ra1.valid = 0; #1; assert (robCount == 4 && !rr0 && !rr1);
    retireReady = 2'b11; #1; assert (!rr0 && !rr1 && retireFire == 2'b11);
    step(); assert (robCount == 2); step(); assert (robCount == 0); retireReady = 0;

    // RS selects two distinct old free slots, then free+real departing slot.
    sa0 = '{default:'0, valid:1, operation:OP_ADD, source1Ready:1, source2Ready:1, robTag:0};
    sa1 = sa0; sa1.robTag = 1;
    #1; assert (sr0 && sr1 && !issued.valid); step();
    assert (occupancy == 2); issueReady = 1; sa0.robTag = 2; sa1.robTag = 3; step();
    assert (occupancy == 3); sa0.robTag = 4; sa1.robTag = 5;
    #1; assert (sr0 && sr1); step();
    sa0.valid = 0; sa1.valid = 0; issueReady = 0; #1;
    assert (occupancy == 4 && !sr0 && !sr1 && rs.robTagInner[0] == 4 && rs.robTagInner[1] == 5);
    rsFlush = '{valid:1, robTag:3}; step(); rsFlush = '0; #1; assert (occupancy == 2);

    // LQ full boundary and lane1-only Load allocation after cancellation.
    la0 = '{valid:1, robTag:0, destinationPhy:32, size:MEM_WORD, isUnsigned:0};
    la1 = '{valid:1, robTag:1, destinationPhy:33, size:MEM_WORD, isUnsigned:0};
    #1; assert (lr0 && lr1 && li0 != li1); step();
    la0.valid = 0; la1.valid = 0; #1; assert (lqCount == 2 && !lr0 && !lr1);
    memFlush = '{valid:1, robTag:0}; step(); memFlush = '0; #1; assert (lqCount == 1);
    la1.valid = 1; la1.robTag = 2; #1; assert (lr1 && li1 == 1); step(); la1.valid = 0;

    // Two Stores are independently initialized, committed, survive younger-tag
    // recovery, and still send only one request on each acceptance edge.
    st0 = '{valid:1, robTag:3, size:MEM_WORD, dataReady:1, dataTag:0, dataValue:111};
    st1 = '{valid:1, robTag:4, size:MEM_WORD, dataReady:1, dataTag:0, dataValue:222};
    #1; assert (str0 && str1 && si0 != si1); step(); st0.valid = 0; st1.valid = 0;
    #1; assert (sqCount == 2 && !str0 && !str1);
    address = '{valid:1, isStore:1, robTag:3, address:32'h600}; addressIndex = 0; step();
    address.robTag = 4; address.address = 32'h604; addressIndex = 1; step(); address.valid = 0;
    storeCommit[0] = '{valid:1, robTag:3}; storeCommit[1] = '{valid:1, robTag:4};
    retirement[0] = '{valid:1, robTag:3}; retirement[1] = '{valid:1, robTag:4};
    storeCommitIndex[0] = 0; storeCommitIndex[1] = 1; step(); storeCommit = '0; retirement = '0;
    memFlush = '{valid:1, robTag:0}; step(); memFlush = '0; #1;
    assert (sqCount == 2 && lsu.sqCommittedInner[0] && lsu.sqCommittedInner[1]);
    memoryReady = 1; #1; assert (!str0 && !str1 && request.valid && request.write && request.writeData == 111);
    step(); #1; assert (sqCount == 1 && request.valid && request.write && request.writeData == 222);
    step(); #1; assert (sqCount == 0);
    $display("PASS dual rename units: RAT WAW, PRF FIFO holes, ROB old capacity, RS reuse, dual LSQ and committed Store recovery");
    $finish;
  end
endmodule
