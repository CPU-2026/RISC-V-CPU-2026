module tb_recovery4;
  import rv32_pkg::*;
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0, freeze = 0, start = 0;
  rob_tag_t headTag, boundaryTag;
  logic [$clog2(ROB_ENTRIES+1)-1:0] liveCount;
  recovery_step_t step;
  rob_replay_narrow_t [ROB_ENTRIES-1:0] narrowEntries;
  rob_replay_ras_t [ROB_ENTRIES-1:0] rasEntries;
  rob_replay_narrow_t [RECOVERY_WIDTH-1:0] narrowWindow;
  rob_replay_ras_t [RECOVERY_WIDTH-1:0] rasWindow;
  rat_read_input_t ratRead;
  rat_read_output_t ratResult;
  rat_rename_input_t renameInfo;
  rat_rename_output_t renameResult;
  rat_commit_input_t ratCommit;
  prf_allocation_input_t allocation;
  prf_free_input_t freeInfo;
  logic allocReady;
  phy_tag_t allocPhy;
  logic [$clog2(PRF_ENTRIES+1)-1:0] freeCount;
  prf_read_output_t [2:0] unusedRead;
  logic [PRF_ENTRIES-1:0] unusedReady;
  predictor_fetch_info_t fetchInfo;
  rob_predictor_input_t robInfo;
  logic [15:0] rasTop;
  logic [31:0] rasTarget;
  phy_tag_t expectedMap [ARCH_REGS];
  logic [31:0] expectedStack [RAS_ENTRIES];
  phy_tag_t expectedFree [PRF_ENTRIES];
  integer expectedTop, expectedCount;

  rv32_recovery_cursor cursor (
    .clkInput(clock), .rstNInput(resetN), .freezeInput(freeze), .startInput(start),
    .headTagInput(headTag), .squashTagInput(boundaryTag), .countInput(liveCount), .stepOutput(step)
  );
  rv32_rat rat (
    .clkInput(clock), .rstNInput(resetN), .freezeInput(freeze),
    .readInput(ratRead), .readOutput(ratResult), .renameInput(renameInfo), .renameOutput(renameResult),
    .restoreInput('{valid:start, headTag:headTag, squashTag:boundaryTag}),
    .recoveryInput(step), .replayInput(narrowWindow), .commitInput(ratCommit)
  );
  rv32_prf #(.WRITEBACK_PORTS(2)) prf (
    .clkInput(clock), .rstNInput(resetN), .freezeInput(freeze),
    .allocationInput(allocation), .allocReadyOutput(allocReady), .allocPhyOutput(allocPhy),
    .freeInput(freeInfo), .restoreInput('{valid:start, squashTag:boundaryTag}),
    .recoveryInput(step), .restoreCountInput(liveCount), .replayInput(narrowWindow),
    .readInput('0), .readOutput(unusedRead), .writebackInput('0),
    .readyVectorOutput(unusedReady), .freeCountOutput(freeCount)
  );
  rv32_bpu_ras ras (
    .clkInput(clock), .rstNInput(resetN), .freezeInput(freeze), .fetchInfoInput(fetchInfo),
    .squashInput('{valid:start, robTag:boundaryTag, programCounter:32'b0, checkpointId:5'b0}),
    .robInput(robInfo), .recoveryInput(step), .rasTopOutput(rasTop), .queryRetTargetOutput(rasTarget)
  );

  task automatic tick;
    @(posedge clock); #1;
    @(negedge clock); #1;
  endtask

  task automatic apply_reference(input rob_replay_narrow_t narrowInfo,
                                 input rob_replay_ras_t rasInfo);
    logic rdLink, rsLink, callHint, returnHint;
    if (narrowInfo.archRd != 0 && narrowInfo.newPhy != 0)
      expectedMap[narrowInfo.archRd] = narrowInfo.newPhy;
    rdLink = rasInfo.rd == 1 || rasInfo.rd == 5;
    rsLink = rasInfo.rs1 == 1 || rasInfo.rs1 == 5;
    callHint = (rasInfo.opcode == OPCODE_JAL ||
      (rasInfo.opcode == OPCODE_JALR && rasInfo.funct3 == 3'b000)) && rdLink;
    returnHint = rasInfo.opcode == OPCODE_JALR && rasInfo.funct3 == 3'b000 && rsLink;
    if (returnHint && expectedTop != 0) expectedTop--;
    if (callHint && expectedTop < RAS_ENTRIES) begin
      expectedStack[expectedTop] = rasInfo.programCounter + 4;
      expectedTop++;
    end
  endtask

  task automatic check_result;
    for (int a = 0; a < ARCH_REGS; a++) begin
      ratRead = '{source1Arch:5'(a), source2Arch:5'(a)};
      renameInfo.architecturalRegister = 5'(a);
      #1;
      assert (ratResult.source1Phy == expectedMap[a] && ratResult.source2Phy == expectedMap[a] &&
              renameResult.previousPhysicalRegister == expectedMap[a])
        else $fatal(1, "RAT mismatch arch=%0d got=%0d expected=%0d", a, ratResult.source1Phy, expectedMap[a]);
    end
    assert (rasTop == expectedTop) else $fatal(1, "RAS depth got=%0d expected=%0d", rasTop, expectedTop);
    assert (rasTarget == (expectedTop == 0 ? 32'b0 : expectedStack[expectedTop-1]))
      else $fatal(1, "RAS target mismatch");
    for (int a = 0; a < RAS_ENTRIES; a++)
      assert (ras.specRasPcInner[a] == expectedStack[a]) else $fatal(1, "RAS contents mismatch slot=%0d", a);
    assert (freeCount == expectedCount) else $fatal(1, "free count got=%0d expected=%0d", freeCount, expectedCount);
  endtask

  task automatic run_case(input int count, input int boundary, input int head, input int depth,
                          input bit pauseWalk);
    int beforeCount, expectedRecycled;
    resetN = 0; freeze = 0; start = 0;
    headTag = rob_tag_t'(head); boundaryTag = rob_tag_t'(head+boundary); liveCount = 5'(count);
    narrowEntries = '0; rasEntries = '0; narrowWindow = '0; rasWindow = '0;
    robInfo = '0; fetchInfo = '0; ratCommit = '0;
    allocation = '0; freeInfo = '0; renameInfo = '0; ratRead = '0;
    for (int a = 0; a < ARCH_REGS; a++) expectedMap[a] = phy_tag_t'(a);
    for (int a = 0; a < RAS_ENTRIES; a++) expectedStack[a] = 0;
    expectedTop = depth;
    tick(); resetN = 1; tick();
    // Initialize SRAM by real masked retirement writes, with no SRAM reset.
    for (int a = 0; a < depth; a++) begin
      robInfo.willCommit = 1;
      robInfo.isHeadCall = 1;
      robInfo.headProgramCounter = 32'h200 + 4*a;
      expectedStack[a] = robInfo.headProgramCounter + 4;
      tick();
    end
    robInfo = '0;
    ratCommit = '{valid:1'b1, architecturalRegister:5'd7, physicalRegister:6'd23};
    expectedMap[7] = 23;
    tick(); ratCommit = '0;
    // Allocate all live entries, and deliberately leave a different speculative
    // stack/map so restoring only a depth/pointer cannot pass.
    for (int a = 0; a < count; a++) begin
      allocation.valid = 1;
      #1; assert (allocReady && allocPhy == phy_tag_t'(32+a));
      narrowEntries[a] = '{robTag:rob_tag_t'(head+a), archRd:5'(1+a%7),
                           newPhy:phy_tag_t'(32+a)};
      rasEntries[a] = '{robTag:rob_tag_t'(head+a), programCounter:32'(1024+4*a),
                       opcode:OPCODE_OP_IMM, rd:5'd0, funct3:3'b000, rs1:5'd0};
      case (a % 4)
        0: rasEntries[a] = '{robTag:rob_tag_t'(head+a), programCounter:32'(1024+4*a),
                            opcode:OPCODE_JAL,  rd:5'd1, funct3:3'b000, rs1:5'd0};  // JAL x1
        1: rasEntries[a] = '{robTag:rob_tag_t'(head+a), programCounter:32'(1024+4*a),
                            opcode:OPCODE_JALR, rd:5'd0, funct3:3'b000, rs1:5'd1};  // JALR x0,x1
        2: rasEntries[a] = '{robTag:rob_tag_t'(head+a), programCounter:32'(1024+4*a),
                            opcode:OPCODE_JALR, rd:5'd1, funct3:3'b000, rs1:5'd1};  // JALR x1,x1
        3: rasEntries[a] = '{robTag:rob_tag_t'(head+a), programCounter:32'(1024+4*a),
                            opcode:OPCODE_JAL,  rd:5'd5, funct3:3'b000, rs1:5'd0};  // JAL x5
      endcase
      renameInfo = '{valid:1'b1, architecturalRegister:narrowEntries[a].archRd,
                     physicalRegister:narrowEntries[a].newPhy};
      fetchInfo = '{valid:1'b1, isCall:1'b1, isReturn:1'b0, jalTargetValid:1'b0,
                    programCounter:32'(8192+4*a), jalTarget:32'b0};
      tick();
    end
    allocation = '0; renameInfo = '0; fetchInfo = '0;
    robInfo.headTag = headTag;
    expectedCount = 0;
    for (int a = count; a < 16; a++) begin
      expectedFree[expectedCount] = phy_tag_t'(32+a); expectedCount++;
    end
    for (int a = 0; a <= boundary; a++)
      apply_reference(narrowEntries[a], rasEntries[a]);
    for (int a = boundary+1; a < count; a++) begin
      expectedFree[expectedCount] = narrowEntries[a].newPhy; expectedCount++;
    end
    beforeCount = int'(freeCount);
    start = 1; #1; assert (!allocReady);
    tick(); start = 0;
    assert (step.active && step.first && step.nextTag == headTag && step.offset == 0);
    assert (int'(freeCount) == beforeCount) else $fatal(1, "free list recycled during baseline read");
    expectedRecycled = 0;
    for (int beat = 0; beat < 4; beat++) begin
      assert (step.active && step.offset == 4*beat && step.nextTag == rob_tag_t'(head+4*beat));
      assert (step.first == (beat == 0) && step.last == (beat == 3));
      #1; assert (!allocReady);
      if (pauseWalk && beat == 1) begin
        freeze = 1; tick(); tick();
        assert (step.active && step.offset == 4 && step.nextTag == rob_tag_t'(head+4));
        freeze = 0;
      end
      for (int a = 4*beat; a < 4*beat+4; a++)
        if (a < count && a > boundary) expectedRecycled++;
      // The ROB hands out the window at head+offset..+RECOVERY_WIDTH-1, so the
      // consumer-side index is the lane, not offset+lane.
      for (int lane = 0; lane < RECOVERY_WIDTH; lane++) begin
        narrowWindow[lane] = narrowEntries[4*beat+lane];
        rasWindow[lane] = rasEntries[4*beat+lane];
      end
      robInfo.replayRasWindow = rasWindow;
      tick();
      assert (int'(freeCount) == beforeCount+expectedRecycled) else $fatal(1, "wrong per-beat recycling");
    end
    assert (!step.active && step.offset == 16 && step.nextTag == rob_tag_t'(head+16));
    check_result();
    // Drain the FIFO to check ordering, not merely free membership/count.
    for (int a = 0; a < expectedCount; a++) begin
      allocation.valid = 1; #1;
      assert (allocReady && allocPhy == expectedFree[a]) else $fatal(1, "free FIFO order mismatch slot=%0d", a);
      tick();
    end
    allocation = '0; #1; assert (!allocReady && freeCount == 0);
  endtask

  initial begin
    @(negedge clock);
    for (int b = 0; b < 16; b++) run_case(16, b, 26+b%6, b, b == 7);
    run_case(1, 0, 31, 0, 0);
    run_case(4, 3, 30, 16, 0);
    run_case(7, 2, 29, 16, 0);
    run_case(12, 8, 24, 1, 0);
    $display("PASS recovery4: 20 cases, SRAM reset masks/full contents, 1 read + 4 beats, cursor wrap/freeze, RAT priority, free FIFO order");
    $finish;
  end
  initial begin #200000; $fatal(1, "recovery4 timeout"); end
endmodule
