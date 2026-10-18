module rv32_rat (
  input  logic                       clkInput,
  input  logic                       rstNInput,
  input logic freezeInput,

  input  rv32_pkg::rat_read_input_t  readInput,
  output rv32_pkg::rat_read_output_t readOutput,
  input  rv32_pkg::rat_rename_input_t renameInput,
  output rv32_pkg::rat_rename_output_t renameOutput,
  input  rv32_pkg::rat_restore_input_t restoreInput,
  input  rv32_pkg::recovery_step_t recoveryInput,
  input  rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayInput,
  input  rv32_pkg::rat_commit_input_t commitInput
);
  import rv32_pkg::*;

  phy_tag_t mapInner [ARCH_REGS];
  phy_tag_t restoreMapInner [ARCH_REGS];
  logic [ARCH_REGS-1:0] archValidInner;
  logic [ARCH_REGS-1:0] archWriteMaskInner;
  logic [(ARCH_REGS*PHY_TAG_W)-1:0] archReadDataInner, archWriteDataInner;
  logic archWriteInner;
  logic replayActiveInner, replayActiveNext;

  // A wide masked word permits one read of the entire committed baseline.
  // Per-lane valid bits supply reset mappings without resetting SRAM cells.
  always_comb begin
    archWriteInner = !freezeInput && !restoreInput.valid && !recoveryInput.active &&
      commitInput.valid && commitInput.architecturalRegister != 0 && commitInput.physicalRegister != 0;
    archWriteMaskInner = '0;
    archWriteDataInner = '0;
    if (archWriteInner) begin
      archWriteMaskInner[commitInput.architecturalRegister] = 1'b1;
      archWriteDataInner[int'(commitInput.architecturalRegister)*PHY_TAG_W +: PHY_TAG_W] =
        commitInput.physicalRegister;
    end
  end
  sram_fakeram #(.DEPTH(1), .WIDTH(ARCH_REGS*PHY_TAG_W), .WRITE_GRANULARITY(PHY_TAG_W)) u_arch_sram (
    .clk(clkInput), .en(rstNInput && !freezeInput && (restoreInput.valid || archWriteInner)),
    .we(archWriteInner), .wmask(archWriteMaskInner), .addr(1'b0),
    .wdata(archWriteDataInner), .rdata(archReadDataInner)
  );

  always_comb begin
    readOutput.source1Phy = (readInput.source1Arch == 5'd0) ? '0 : mapInner[readInput.source1Arch];
    readOutput.source2Phy = (readInput.source2Arch == 5'd0) ? '0 : mapInner[readInput.source2Arch];
    renameOutput.previousPhysicalRegister = (renameInput.architecturalRegister == 5'd0) ? '0 :
                       mapInner[renameInput.architecturalRegister];
  end

  always_comb begin : build_restore_map
    integer archIndexInner, laneInner, windowIndexInner;
    rob_tag_t expectedTagInner;
    replayActiveNext = recoveryInput.first ? 1'b1 : replayActiveInner;
    windowIndexInner = 0;
    expectedTagInner = '0;
    for (archIndexInner = 0; archIndexInner < ARCH_REGS;
         archIndexInner = archIndexInner + 1) begin
      restoreMapInner[archIndexInner] = recoveryInput.first ?
        (archValidInner[archIndexInner] ?
          archReadDataInner[archIndexInner*PHY_TAG_W +: PHY_TAG_W] : phy_tag_t'(archIndexInner)) :
        mapInner[archIndexInner];
    end
    for (laneInner = 0; laneInner < RECOVERY_WIDTH; laneInner = laneInner + 1) begin
      windowIndexInner = int'(recoveryInput.offset) + laneInner;
      expectedTagInner = recoveryInput.nextTag + rob_tag_t'(laneInner);
      if (recoveryInput.active && replayActiveNext && windowIndexInner < ROB_ENTRIES &&
          windowIndexInner < int'(recoveryInput.liveCount)) begin
        if (replayInput[laneInner].robTag == expectedTagInner) begin
          if (replayInput[laneInner].archRd != 0 && replayInput[laneInner].newPhy != 0)
            restoreMapInner[replayInput[laneInner].archRd] = replayInput[laneInner].newPhy;
          if (expectedTagInner == recoveryInput.squashTag)
            replayActiveNext = 1'b0;
        end else
          replayActiveNext = 1'b0;
      end
    end
    restoreMapInner[0] = '0;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin : update_mappings
    integer stateIndexInner;

    if (!rstNInput) begin
      archValidInner <= '0;
      replayActiveInner <= 1'b0;
      for (stateIndexInner = 0; stateIndexInner < ARCH_REGS;
           stateIndexInner = stateIndexInner + 1) begin
        mapInner[stateIndexInner] <= phy_tag_t'(stateIndexInner);
      end
    end else if (!freezeInput) begin
      if (recoveryInput.active) begin
        replayActiveInner <= replayActiveNext;
        for (stateIndexInner = 0; stateIndexInner < ARCH_REGS;
             stateIndexInner = stateIndexInner + 1)
          mapInner[stateIndexInner] <= restoreMapInner[stateIndexInner];
      end else if (!restoreInput.valid && renameInput.valid && (renameInput.architecturalRegister != 5'd0)) begin
        mapInner[renameInput.architecturalRegister] <= renameInput.physicalRegister;
      end

      if (archWriteInner)
        archValidInner[commitInput.architecturalRegister] <= 1'b1;
    end
  end
endmodule
