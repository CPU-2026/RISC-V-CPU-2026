// Array-port RAT for the wide backend. Reads intentionally see the OLD map;
// the ordered rename planner owns same-group RAW and oldPhy WAW forwarding.
// The existing scalar/Second implementation is retained for legacy cores.
module rv32_rat_lanes #(
  parameter int unsigned LANES = 4,
  parameter int unsigned COMMIT_WIDTH = 2
) (
  input logic clkInput, rstNInput, freezeInput,
  input rv32_pkg::rat_read_input_t [LANES-1:0] readInput,
  output rv32_pkg::rat_read_output_t [LANES-1:0] readOutput,
  // Destination query is decoded intent, independent of actual rename fire.
  input logic [LANES-1:0][4:0] destinationArchInput,
  input rv32_pkg::rat_rename_input_t [LANES-1:0] renameInput,
  output rv32_pkg::rat_rename_output_t [LANES-1:0] renameOutput,
  input rv32_pkg::rat_restore_input_t restoreInput,
  input rv32_pkg::recovery_step_t recoveryInput,
  input rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayInput,
  input rv32_pkg::rat_commit_input_t [COMMIT_WIDTH-1:0] commitInput
);
  import rv32_pkg::*;
  if (LANES != 1 && LANES != 2 && LANES != 4) begin : g_invalid_lanes
    initial $fatal(1, "RAT LANES must be 1, 2 or 4");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2 && COMMIT_WIDTH != 4) begin : g_invalid_commit
    initial $fatal(1, "RAT COMMIT_WIDTH must be 1, 2 or 4");
  end
  phy_tag_t mapInner [ARCH_REGS], restoreMapInner [ARCH_REGS];
  logic [ARCH_REGS-1:0] archValidInner, archWriteMaskInner;
  logic [ARCH_REGS*PHY_TAG_W-1:0] archReadDataInner, archWriteDataInner;
  logic replayActiveInner, replayActiveNext;

  always_comb begin
    archWriteMaskInner = '0;
    archWriteDataInner = '0;
    for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
      if (!freezeInput && !restoreInput.valid && !recoveryInput.active &&
          commitInput[lane].valid && commitInput[lane].architecturalRegister != 0 &&
          commitInput[lane].physicalRegister != 0) begin
        archWriteMaskInner[commitInput[lane].architecturalRegister] = 1'b1;
        archWriteDataInner[int'(commitInput[lane].architecturalRegister)*PHY_TAG_W +: PHY_TAG_W] =
          commitInput[lane].physicalRegister;
      end
    end
  end
  assign archReadDataInner[0 +: PHY_TAG_W] = '0;
  for (genvar archIndex = 1; archIndex < ARCH_REGS; archIndex++) begin : g_arch_sram
    // fakeram does NOT hold rdata while disabled. Refresh the committed read
    // during a held first replay beat, including freeze, or that pause destroys
    // the restore-edge snapshot. Write intent already excludes freeze/recovery;
    // these extra reads cannot change committed or speculative mappings.
    sram_fakeram #(.DEPTH(1), .WIDTH(PHY_TAG_W), .WRITE_GRANULARITY(PHY_TAG_W)) u_arch_sram (
      .clk(clkInput), .en(rstNInput && (restoreInput.valid ||
        (recoveryInput.active && recoveryInput.first) || archWriteMaskInner[archIndex])),
      .we(archWriteMaskInner[archIndex]), .wmask(1'b1), .addr(1'b0),
      .wdata(archWriteDataInner[archIndex*PHY_TAG_W +: PHY_TAG_W]),
      .rdata(archReadDataInner[archIndex*PHY_TAG_W +: PHY_TAG_W])
    );
  end
  for (genvar lane = 0; lane < LANES; lane++) begin : g_read
    assign readOutput[lane].source1Phy = readInput[lane].source1Arch == 0 ? '0 : mapInner[readInput[lane].source1Arch];
    assign readOutput[lane].source2Phy = readInput[lane].source2Arch == 0 ? '0 : mapInner[readInput[lane].source2Arch];
    assign renameOutput[lane].previousPhysicalRegister = destinationArchInput[lane] == 0 ? '0 :
      mapInner[destinationArchInput[lane]];
  end
  always_comb begin : build_restore_map
    int windowIndex;
    rob_tag_t expectedTag;
    replayActiveNext = recoveryInput.first ? 1'b1 : replayActiveInner;
    windowIndex = 0;
    expectedTag = '0;
    for (int arch = 0; arch < ARCH_REGS; arch++)
      restoreMapInner[arch] = recoveryInput.first ?
        (archValidInner[arch] ? archReadDataInner[arch*PHY_TAG_W +: PHY_TAG_W] : phy_tag_t'(arch)) : mapInner[arch];
    for (int lane = 0; lane < RECOVERY_WIDTH; lane++) begin
      windowIndex = int'(recoveryInput.offset) + lane;
      expectedTag = recoveryInput.nextTag + rob_tag_t'(lane);
      if (recoveryInput.active && replayActiveNext && windowIndex < ROB_ENTRIES &&
          windowIndex < int'(recoveryInput.liveCount)) begin
        if (replayInput[lane].robTag == expectedTag) begin
          if (replayInput[lane].archRd != 0 && replayInput[lane].newPhy != 0)
            restoreMapInner[replayInput[lane].archRd] = replayInput[lane].newPhy;
          if (expectedTag == recoveryInput.squashTag) replayActiveNext = 1'b0;
        end else replayActiveNext = 1'b0;
      end
    end
    restoreMapInner[0] = '0;
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      archValidInner <= '0;
      replayActiveInner <= 1'b0;
      for (int arch = 0; arch < ARCH_REGS; arch++) mapInner[arch] <= phy_tag_t'(arch);
    end else if (!freezeInput) begin
      if (recoveryInput.active) begin
        replayActiveInner <= replayActiveNext;
        for (int arch = 0; arch < ARCH_REGS; arch++) mapInner[arch] <= restoreMapInner[arch];
      end else if (!restoreInput.valid) begin
        for (int arch = 1; arch < ARCH_REGS; arch++) begin
          // A single NBA per map row; the youngest actual writer wins.
          phy_tag_t nextPhy;
          nextPhy = mapInner[arch];
          for (int lane = 0; lane < LANES; lane++)
            if (renameInput[lane].valid && renameInput[lane].architecturalRegister == 5'(arch))
              nextPhy = renameInput[lane].physicalRegister;
          mapInner[arch] <= nextPhy;
        end
      end
      archValidInner <= archValidInner | archWriteMaskInner;
    end
  end
endmodule
