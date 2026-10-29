module rv32_rat #(
  parameter int unsigned COMMIT_WIDTH = 1,
  parameter int unsigned RENAME_WIDTH = 1
) (
  input  logic                       clkInput,
  input  logic                       rstNInput,
  input logic freezeInput,

  input  rv32_pkg::rat_read_input_t  readInput,
  output rv32_pkg::rat_read_output_t readOutput,
  input  rv32_pkg::rat_rename_input_t renameInput,
  output rv32_pkg::rat_rename_output_t renameOutput,
  input  rv32_pkg::rat_read_input_t readSecondInput,
  output rv32_pkg::rat_read_output_t readSecondOutput,
  input  rv32_pkg::rat_rename_input_t renameSecondInput,
  output rv32_pkg::rat_rename_output_t renameSecondOutput,
  input  rv32_pkg::rat_restore_input_t restoreInput,
  input  rv32_pkg::recovery_step_t recoveryInput,
  input  rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayInput,
  input  rv32_pkg::rat_commit_input_t [COMMIT_WIDTH-1:0] commitInput
);
  import rv32_pkg::*;
  if (RENAME_WIDTH != 1 && RENAME_WIDTH != 2) begin : g_invalid_rename_width
    initial $fatal(1, "RENAME_WIDTH must be 1 or 2");
  end
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2) begin : g_invalid_commit_width
    initial $fatal(1, "COMMIT_WIDTH must be 1 or 2");
  end

  phy_tag_t mapInner [ARCH_REGS];
  phy_tag_t restoreMapInner [ARCH_REGS];
  logic [ARCH_REGS-1:0] archValidInner;
  logic [ARCH_REGS-1:0] archWriteMaskInner;
  logic [(ARCH_REGS*PHY_TAG_W)-1:0] archReadDataInner, archWriteDataInner;
  logic replayActiveInner, replayActiveNext;

  // Fold commits in age order; a younger write to the same architectural
  // register wins. Each mask bit is the corresponding SRAM's local write intent.
  always_comb begin
    archWriteMaskInner = '0;
    archWriteDataInner = '0;
    for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
      if (!freezeInput && !restoreInput.valid && !recoveryInput.active &&
          commitInput[lane].valid && commitInput[lane].architecturalRegister != 0 && commitInput[lane].physicalRegister != 0) begin
        archWriteMaskInner[commitInput[lane].architecturalRegister] = 1'b1;
        archWriteDataInner[int'(commitInput[lane].architecturalRegister)*PHY_TAG_W +: PHY_TAG_W] =
          commitInput[lane].physicalRegister;
      end
    end
  end
  // Read all committed mappings on the restore edge, but drive write enable
  // locally instead of broadcasting a late global write signal to every macro.
  // Per-register valid bits supply reset mappings without resetting SRAM cells.
  assign archReadDataInner[0 +: PHY_TAG_W] = '0;
  generate
    for (genvar archIndex = 1; archIndex < ARCH_REGS; archIndex++) begin : gen_arch_sram
      sram_fakeram #(.DEPTH(1), .WIDTH(PHY_TAG_W), .WRITE_GRANULARITY(PHY_TAG_W)) u_arch_sram (
        .clk(clkInput),
        .en(rstNInput && !freezeInput && (restoreInput.valid || archWriteMaskInner[archIndex])),
        .we(archWriteMaskInner[archIndex]), .wmask(1'b1), .addr(1'b0),
        .wdata(archWriteDataInner[archIndex*PHY_TAG_W +: PHY_TAG_W]),
        .rdata(archReadDataInner[archIndex*PHY_TAG_W +: PHY_TAG_W])
      );
    end
  endgenerate

  always_comb begin
    readOutput.source1Phy = (readInput.source1Arch == 5'd0) ? '0 : mapInner[readInput.source1Arch];
    readOutput.source2Phy = (readInput.source2Arch == 5'd0) ? '0 : mapInner[readInput.source2Arch];
    renameOutput.previousPhysicalRegister = (renameInput.architecturalRegister == 5'd0) ? '0 :
                       mapInner[renameInput.architecturalRegister];
  end

  generate if (RENAME_WIDTH == 2) begin : g_second_read
    assign readSecondOutput.source1Phy = readSecondInput.source1Arch == 0 ? '0 : mapInner[readSecondInput.source1Arch];
    assign readSecondOutput.source2Phy = readSecondInput.source2Arch == 0 ? '0 : mapInner[readSecondInput.source2Arch];
    assign renameSecondOutput.previousPhysicalRegister = renameSecondInput.architecturalRegister == 0 ? '0 :
      mapInner[renameSecondInput.architecturalRegister];
  end else begin : g_no_second_read
    assign readSecondOutput = '0;
    assign renameSecondOutput = '0;
  end endgenerate

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
      end else if (!restoreInput.valid) begin
        // Fold in program order: younger WAW wins, one assignment per mapping.
        for (stateIndexInner = 1; stateIndexInner < ARCH_REGS; stateIndexInner++) begin
          if (RENAME_WIDTH == 2 && renameSecondInput.valid &&
              renameSecondInput.architecturalRegister == 5'(stateIndexInner))
            mapInner[stateIndexInner] <= renameSecondInput.physicalRegister;
          else if (renameInput.valid && renameInput.architecturalRegister == 5'(stateIndexInner))
            mapInner[stateIndexInner] <= renameInput.physicalRegister;
        end
      end

      archValidInner <= archValidInner | archWriteMaskInner;
    end
  end
endmodule
