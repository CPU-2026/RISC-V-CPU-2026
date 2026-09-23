module rv32_rat (
  input  logic                       clkInput,
  input  logic                       rstNInput,

  input  rv32_pkg::rat_read_input_t  readInput,
  output rv32_pkg::rat_read_output_t readOutput,
  input  rv32_pkg::rat_rename_input_t renameInput,
  output rv32_pkg::rat_rename_output_t renameOutput,
  input  rv32_pkg::rat_restore_input_t restoreInput,
  input  rv32_pkg::rob_replay_entry_t [rv32_pkg::ROB_ENTRIES-1:0] replayInput,
  input  rv32_pkg::rat_commit_input_t commitInput
);
  import rv32_pkg::*;

  phy_tag_t mapInner [ARCH_REGS];
  phy_tag_t archInner [ARCH_REGS];
  phy_tag_t restoreMapInner [ARCH_REGS];
  rob_tag_t replayCursorInner [ROB_ENTRIES+1];
  logic replayActiveInner [ROB_ENTRIES+1];
  logic replayValidInner [ROB_ENTRIES];

  always_comb begin
    readOutput.source1Phy = (readInput.source1Arch == 5'd0) ? '0 : mapInner[readInput.source1Arch];
    readOutput.source2Phy = (readInput.source2Arch == 5'd0) ? '0 : mapInner[readInput.source2Arch];
    renameOutput.previousPhysicalRegister = (renameInput.architecturalRegister == 5'd0) ? '0 :
                       mapInner[renameInput.architecturalRegister];
    readOutput.debugPhy = (readInput.debugArch == 5'd0) ? '0 : mapInner[readInput.debugArch];
  end

  always_comb begin : build_restore_map
    integer replayIndexInner, archIndexInner, windowIndexInner;

    replayCursorInner[0] = restoreInput.headTag;
    replayActiveInner[0] = restoreInput.valid;
    for (replayIndexInner = 0; replayIndexInner < ROB_ENTRIES;
         replayIndexInner = replayIndexInner + 1) begin
      // A stale or malformed window must not replay entries beyond its gap.
      replayValidInner[replayIndexInner] = replayActiveInner[replayIndexInner] &&
                         (replayInput[replayIndexInner].robTag == replayCursorInner[replayIndexInner]);
      replayCursorInner[replayIndexInner+1] = replayCursorInner[replayIndexInner];
      replayActiveInner[replayIndexInner+1] = 1'b0;
      if (replayValidInner[replayIndexInner] &&
           (replayCursorInner[replayIndexInner] != restoreInput.squashTag)) begin
        replayCursorInner[replayIndexInner+1] =
          replayCursorInner[replayIndexInner] + rob_tag_t'(1);
        replayActiveInner[replayIndexInner+1] = 1'b1;
      end
    end

    for (archIndexInner = 0; archIndexInner < ARCH_REGS;
         archIndexInner = archIndexInner + 1) begin
      restoreMapInner[archIndexInner] = archInner[archIndexInner];
      for (windowIndexInner = 0; windowIndexInner < ROB_ENTRIES;
           windowIndexInner = windowIndexInner + 1) begin
        if (replayValidInner[windowIndexInner] &&
            (replayInput[windowIndexInner].archRd == archIndexInner[4:0]) &&
            (replayInput[windowIndexInner].archRd != 5'd0) &&
            (replayInput[windowIndexInner].newPhy != '0))
          restoreMapInner[archIndexInner] = replayInput[windowIndexInner].newPhy;
      end
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin : update_mappings
    integer stateIndexInner;

    if (!rstNInput) begin
      for (stateIndexInner = 0; stateIndexInner < ARCH_REGS;
           stateIndexInner = stateIndexInner + 1) begin
        mapInner[stateIndexInner] <= phy_tag_t'(stateIndexInner);
        archInner[stateIndexInner] <= phy_tag_t'(stateIndexInner);
      end
    end else begin
      if (restoreInput.valid) begin
        for (stateIndexInner = 0; stateIndexInner < ARCH_REGS;
             stateIndexInner = stateIndexInner + 1)
          mapInner[stateIndexInner] <= restoreMapInner[stateIndexInner];
      end else if (renameInput.valid && (renameInput.architecturalRegister != 5'd0)) begin
        mapInner[renameInput.architecturalRegister] <= renameInput.physicalRegister;
      end

      if (commitInput.valid && (commitInput.architecturalRegister != 5'd0) &&
          (commitInput.physicalRegister != '0))
        archInner[commitInput.architecturalRegister] <= commitInput.physicalRegister;
    end
  end
endmodule
