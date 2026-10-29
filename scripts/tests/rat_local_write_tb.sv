// Independent committed/speculative mapping scoreboard; no SRAM contents forced.
module tb_rat_local_write #(
  parameter int unsigned COMMIT_WIDTH = 2
);
  import rv32_pkg::*;
  logic clk = 0, rstN = 0, freeze = 0;
  rat_read_input_t readPort;
  rat_read_output_t readResult;
  rat_rename_input_t renamePort;
  rat_rename_output_t renameResult;
  rat_restore_input_t restore;
  recovery_step_t recovery;
  rob_replay_narrow_t [RECOVERY_WIDTH-1:0] replay;
  rat_commit_input_t [COMMIT_WIDTH-1:0] commits;
  phy_tag_t committed [ARCH_REGS], speculative [ARCH_REGS], captured [ARCH_REGS];
  logic [ARCH_REGS-1:0] validModel, writeModel;
  bit replayOpen;
  int cycles = 0;
  int unsigned randomState = 32'h9f731a25;

  rv32_rat #(.COMMIT_WIDTH(COMMIT_WIDTH)) dut (
    .clkInput(clk), .rstNInput(rstN), .freezeInput(freeze),
    .readInput(readPort), .readOutput(readResult),
    .renameInput(renamePort), .renameOutput(renameResult),
    .restoreInput(restore), .recoveryInput(recovery),
    .replayInput(replay), .commitInput(commits)
  );

`ifdef CHECK_LOCAL_CONTROLS
  for (genvar row = 1; row < ARCH_REGS; row++) begin : check_local_controls
    always @(posedge clk) begin
      assert(dut.gen_arch_sram[row].u_arch_sram.we == writeModel[row])
        else $fatal(1, "nonlocal write enable row=%0d cycle=%0d", row, cycles);
      assert(dut.gen_arch_sram[row].u_arch_sram.en ==
        (rstN && !freeze && (restore.valid || writeModel[row])))
        else $fatal(1, "local read/write enable row=%0d cycle=%0d", row, cycles);
    end
  end
`endif

  function automatic int unsigned random_word();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction

  task automatic clear_inputs;
    freeze = 0;
    readPort = '0;
    renamePort = '0;
    restore = '0;
    recovery = '0;
    replay = '0;
    commits = '0;
  endtask

  task automatic tick;
    int expectedTag;
    #1;
    writeModel = '0;
    if (!freeze && !restore.valid && !recovery.active) begin
      for (int lane = 0; lane < COMMIT_WIDTH; lane++)
        if (commits[lane].valid && commits[lane].architecturalRegister != 0 &&
            commits[lane].physicalRegister != 0)
          writeModel[commits[lane].architecturalRegister] = 1'b1;
    end
    assert(dut.archWriteMaskInner == writeModel) else $fatal(1, "write intent cycle=%0d", cycles);
    if (!rstN) begin
      validModel = '0;
      replayOpen = 0;
      for (int row = 0; row < ARCH_REGS; row++) begin
        committed[row] = phy_tag_t'(row);
        speculative[row] = phy_tag_t'(row);
        captured[row] = phy_tag_t'(row);
      end
    end else if (!freeze) begin
      // SRAM read is synchronous: snapshot before the following recovery edge.
      if (restore.valid)
        for (int row = 0; row < ARCH_REGS; row++) captured[row] = committed[row];
      if (recovery.active) begin
        if (recovery.first) begin
          replayOpen = 1;
          for (int row = 0; row < ARCH_REGS; row++) speculative[row] = captured[row];
        end
        for (int lane = 0; lane < RECOVERY_WIDTH; lane++) begin
          expectedTag = (int'(recovery.nextTag) + lane) % (1 << ROB_TAG_W);
          if (replayOpen && int'(recovery.offset) + lane < ROB_ENTRIES &&
              int'(recovery.offset) + lane < int'(recovery.liveCount)) begin
            if (int'(replay[lane].robTag) != expectedTag) replayOpen = 0;
            else begin
              if (replay[lane].archRd != 0 && replay[lane].newPhy != 0)
                speculative[replay[lane].archRd] = replay[lane].newPhy;
              if (expectedTag == int'(recovery.squashTag)) replayOpen = 0;
            end
          end
        end
        speculative[0] = '0;
      end else if (!restore.valid && renamePort.valid && renamePort.architecturalRegister != 0)
        speculative[renamePort.architecturalRegister] = renamePort.physicalRegister;
      if (!restore.valid && !recovery.active) begin
        for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
          if (commits[lane].valid && commits[lane].architecturalRegister != 0 &&
              commits[lane].physicalRegister != 0) begin
            committed[commits[lane].architecturalRegister] = commits[lane].physicalRegister;
            validModel[commits[lane].architecturalRegister] = 1'b1;
          end
        end
      end
    end
    clk = 1; #1; clk = 0; #1;
    cycles++;
    assert(dut.archValidInner == validModel) else $fatal(1, "committed valid cycle=%0d", cycles);
    // Exercise both public read ports for every architectural register each edge.
    for (int row = 0; row < ARCH_REGS; row++) begin
      readPort.source1Arch = 5'(row);
      readPort.source2Arch = 5'(ARCH_REGS-1-row);
      #1;
      assert(readResult.source1Phy == speculative[row] &&
             readResult.source2Phy == speculative[ARCH_REGS-1-row])
        else $fatal(1, "mapping cycle=%0d row=%0d got=%0d expected=%0d",
          cycles, row, readResult.source1Phy, speculative[row]);
    end
    assert(renameResult.previousPhysicalRegister == speculative[renamePort.architecturalRegister])
      else $fatal(1, "rename previous mapping cycle=%0d", cycles);
  endtask

  task automatic reset_rat;
    clear_inputs(); rstN = 0; tick(); rstN = 1; tick();
  endtask

  task automatic empty_restore;
    clear_inputs(); restore.valid = 1; tick();
    restore = '0; recovery.active = 1; recovery.first = 1; tick();
    recovery = '0;
  endtask

  initial begin
    reset_rat();
    empty_restore(); // Unwritten SRAM cells use identity mappings.
    // Every register, adjacent writes to different rows, then immediate restore.
    for (int row = 1; row < ARCH_REGS; row++) begin
      clear_inputs();
      commits[0] = '{valid:1'b1, architecturalRegister:5'(row), physicalRegister:phy_tag_t'(32+row%16)};
      if (COMMIT_WIDTH == 2)
        commits[COMMIT_WIDTH-1] = '{valid:1'b1, architecturalRegister:5'(row%31+1),
          physicalRegister:phy_tag_t'(32+(row+1)%16)};
      tick(); empty_restore();
    end
    // Same-rd younger winner, invalid younger lane, x0 and physical zero guards.
    clear_inputs();
    for (int lane = 0; lane < COMMIT_WIDTH; lane++)
      commits[lane] = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(40+lane)};
    tick(); empty_restore();
    clear_inputs();
    commits[0] = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(43)};
    if (COMMIT_WIDTH == 2)
      commits[COMMIT_WIDTH-1] = '{valid:1'b0, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(44)};
    tick(); empty_restore();
    clear_inputs();
    commits[0] = '{valid:1'b1, architecturalRegister:5'd0, physicalRegister:phy_tag_t'(45)};
    tick();
    commits[0] = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(0)};
    tick(); empty_restore();
    // Freeze blocks writes and renames; a frozen restore is reissued on resume.
    clear_inputs(); freeze = 1;
    commits[0] = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(46)};
    renamePort = '{valid:1'b1, architecturalRegister:5'd5, physicalRegister:phy_tag_t'(47)};
    tick(); restore.valid = 1; tick();
    freeze = 0; tick(); // Restore wins over commit/rename on this edge.
    restore = '0; recovery.active = 1; recovery.first = 1; tick();
    clear_inputs();

    for (int round = 0; round < 128; round++) begin
      for (int step = 0; step < 16; step++) begin
        clear_inputs();
        freeze = (random_word() % 8 == 0);
        renamePort = '{valid:1'(random_word()), architecturalRegister:5'(random_word()),
          physicalRegister:phy_tag_t'(random_word())};
        for (int lane = 0; lane < COMMIT_WIDTH; lane++)
          commits[lane] = '{valid:1'(random_word()), architecturalRegister:5'(random_word()),
            physicalRegister:phy_tag_t'(random_word())};
        if (COMMIT_WIDTH == 2 && random_word() % 4 == 0)
          commits[COMMIT_WIDTH-1].architecturalRegister = commits[0].architecturalRegister;
        tick();
      end
      // Preserve active commits while reading/replaying to check suppression.
      freeze = 0; restore.valid = 1; tick(); restore = '0;
      recovery = '0;
      recovery.active = 1;
      recovery.nextTag = rob_tag_t'(random_word());
      recovery.liveCount = 5'(random_word() % (ROB_ENTRIES+1));
      recovery.squashTag = recovery.nextTag + rob_tag_t'(random_word() % ROB_ENTRIES);
      for (int beat = 0; beat < RECOVERY_BEATS; beat++) begin
        recovery.first = (beat == 0);
        recovery.offset = rob_tag_t'(beat*RECOVERY_WIDTH);
        for (int lane = 0; lane < RECOVERY_WIDTH; lane++) begin
          replay[lane] = '{robTag:recovery.nextTag + rob_tag_t'(lane),
            archRd:5'(random_word()), newPhy:phy_tag_t'(random_word())};
          if (random_word() % 16 == 0) replay[lane].robTag ^= rob_tag_t'(1);
        end
        if (beat != 0 && random_word() % 4 == 0) begin
          freeze = 1; tick(); freeze = 0;
        end
        tick(); recovery.nextTag += rob_tag_t'(RECOVERY_WIDTH);
      end
      clear_inputs();
      if (round % 16 == 15) begin
        reset_rat(); // Stale SRAM contents must not leak across reset.
        empty_restore();
      end
    end
    empty_restore();
    $display("PASS RAT local write width=%0d cycles=%0d", COMMIT_WIDTH, cycles);
    $finish;
  end
endmodule
