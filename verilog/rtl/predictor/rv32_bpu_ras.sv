module rv32_bpu_ras #(
  parameter int unsigned RAS_ENTRIES = rv32_pkg::RAS_ENTRIES
) (
  input logic clkInput,
  input logic rstNInput,
  input logic freezeInput,

  input rv32_pkg::predictor_fetch_info_t fetchInfoInput,
  input rv32_pkg::squash_input_t         squashInput,
  input rv32_pkg::rob_predictor_input_t  robInput,
  input rv32_pkg::recovery_step_t recoveryInput,

  output logic [15:0]            rasTopOutput,
  output logic [31:0]            queryRetTargetOutput
);
  import rv32_pkg::*;
  localparam int unsigned RAS_PTR_W = RAS_ENTRIES > 1 ? $clog2(RAS_ENTRIES) : 1;
  localparam int unsigned RAS_STORAGE_ENTRIES = RAS_ENTRIES > 0 ? RAS_ENTRIES : 1;
  localparam int unsigned RAS_TOP_W = $clog2(RAS_STORAGE_ENTRIES + 1);

  logic [31:0] specRasPcInner [RAS_STORAGE_ENTRIES];
  logic [RAS_TOP_W-1:0] specRasTopInner;  // Depth, including the full state.
  logic [RAS_TOP_W-1:0] archRasTopInner;

  logic [RAS_TOP_W-1:0] specRasTopNext;
  logic [RAS_TOP_W-1:0] archRasTopNext;
  logic [31:0] specRasPcNext [RAS_STORAGE_ENTRIES];
  logic [RAS_TOP_W-1:0] baselineTopInner;
  logic [RAS_STORAGE_ENTRIES-1:0] archValidInner, archWriteMaskInner;
  logic [(RAS_STORAGE_ENTRIES*32)-1:0] archReadDataInner, archWriteDataInner;
  logic archWriteInner;
  logic replayActiveInner, replayActiveNext;
  logic replayCallInner, replayRetInner;
  logic replayRdLinkInner, replayRs1LinkInner;
  integer normalIndexInner, recoveryIndexInner, laneInner, windowIndexInner;
  rob_tag_t replayTagInner;
  integer seqIndexInner;

  always_comb begin
    if (specRasTopInner == '0)
      queryRetTargetOutput = 32'd0;
    else
      queryRetTargetOutput = specRasPcInner[RAS_PTR_W'(specRasTopInner - RAS_TOP_W'(1))];
  end  // query the return address

  // Preserve the public depth carrier; the unused upper bits are constant.
  assign rasTopOutput = 16'(specRasTopInner);

  always_comb begin
    archRasTopNext = archRasTopInner;
    archWriteInner = 1'b0;
    archWriteMaskInner = '0;
    archWriteDataInner = '0;
    if (!freezeInput && !squashInput.valid && !recoveryInput.active && robInput.willCommit) begin
      if (robInput.isHeadReturn && (archRasTopNext != '0))
        archRasTopNext = archRasTopNext - RAS_TOP_W'(1);
      if (robInput.isHeadCall && archRasTopNext < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
        archWriteInner = 1'b1;
        archWriteMaskInner[archRasTopNext[RAS_PTR_W-1:0]] = 1'b1;
        archWriteDataInner[int'(archRasTopNext)*32 +: 32] = robInput.headProgramCounter + 32'd4;
        archRasTopNext = archRasTopNext + RAS_TOP_W'(1);
      end
    end
  end

  // One masked wide word: normal retirement writes one 32-bit lane, recovery
  // reads the entire baseline in one clock. SRAM contents have no reset.
  sram_fakeram #(.DEPTH(1), .WIDTH(RAS_STORAGE_ENTRIES*32), .WRITE_GRANULARITY(32)) u_arch_sram (
    .clk(clkInput), .en(rstNInput && !freezeInput && (squashInput.valid || archWriteInner)),
    .we(archWriteInner), .wmask(archWriteMaskInner), .addr(1'b0),
    .wdata(archWriteDataInner), .rdata(archReadDataInner)
  );

  always_comb begin
    specRasTopNext = specRasTopInner;
    for (normalIndexInner = 0; normalIndexInner < RAS_STORAGE_ENTRIES; normalIndexInner = normalIndexInner + 1)
      specRasPcNext[normalIndexInner] = specRasPcInner[normalIndexInner];

    if (!squashInput.valid && !recoveryInput.active && fetchInfoInput.valid) begin
      if (fetchInfoInput.isReturn && (specRasTopNext != '0))
        specRasTopNext = specRasTopNext - RAS_TOP_W'(1);
      if (fetchInfoInput.isCall && specRasTopNext < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
        specRasPcNext[specRasTopNext[RAS_PTR_W-1:0]] = fetchInfoInput.programCounter + 32'd4;
        specRasTopNext = specRasTopNext + RAS_TOP_W'(1);
      end
    end
    // Each beat applies at most four entries to the previous beat's result.
    // The head cannot retire during the read or walk, so it is replayed once.
    replayActiveNext = recoveryInput.first ? 1'b1 : replayActiveInner;
    replayTagInner = '0;
    replayCallInner = 1'b0;
    replayRetInner = 1'b0;
    replayRdLinkInner = 1'b0;
    replayRs1LinkInner = 1'b0;
    windowIndexInner = 0;
    if (recoveryInput.active) begin
      if (recoveryInput.first) begin
        specRasTopNext = baselineTopInner;
        for (recoveryIndexInner = 0; recoveryIndexInner < RAS_STORAGE_ENTRIES; recoveryIndexInner = recoveryIndexInner + 1)
          specRasPcNext[recoveryIndexInner] = archValidInner[recoveryIndexInner] ?
            archReadDataInner[recoveryIndexInner*32 +: 32] : 32'b0;
      end
      for (laneInner = 0; laneInner < RECOVERY_WIDTH; laneInner = laneInner + 1) begin
        windowIndexInner = int'(recoveryInput.offset) + laneInner;
        replayTagInner = recoveryInput.nextTag + rob_tag_t'(laneInner);
        if (replayActiveNext && windowIndexInner < ROB_ENTRIES &&
            windowIndexInner < int'(recoveryInput.liveCount)) begin
          if (robInput.replayRasWindow[laneInner].robTag == replayTagInner) begin
            replayRdLinkInner = (robInput.replayRasWindow[laneInner].rd == 5'd1) ||
                             (robInput.replayRasWindow[laneInner].rd == 5'd5);
            replayRs1LinkInner = (robInput.replayRasWindow[laneInner].rs1 == 5'd1) ||
                              (robInput.replayRasWindow[laneInner].rs1 == 5'd5);
            replayCallInner = ((robInput.replayRasWindow[laneInner].opcode == OPCODE_JAL) ||
                           ((robInput.replayRasWindow[laneInner].opcode == OPCODE_JALR) &&
                            (robInput.replayRasWindow[laneInner].funct3 == 3'b000))) && replayRdLinkInner;
            replayRetInner = (robInput.replayRasWindow[laneInner].opcode == OPCODE_JALR) &&
                          (robInput.replayRasWindow[laneInner].funct3 == 3'b000) && replayRs1LinkInner;
            if (replayRetInner && (specRasTopNext != '0))
              specRasTopNext = specRasTopNext - RAS_TOP_W'(1);
            if (replayCallInner && specRasTopNext < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
              specRasPcNext[specRasTopNext[RAS_PTR_W-1:0]] =
                robInput.replayRasWindow[laneInner].programCounter + 32'd4;
              specRasTopNext = specRasTopNext + RAS_TOP_W'(1);
            end
            if (replayTagInner == recoveryInput.squashTag)
              replayActiveNext = 1'b0;
          end else
            replayActiveNext = 1'b0;
        end
      end
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      specRasTopInner <= '0;
      archRasTopInner <= '0;
      baselineTopInner <= '0;
      archValidInner <= '0;
      replayActiveInner <= 1'b0;
      for (seqIndexInner = 0; seqIndexInner < RAS_STORAGE_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        specRasPcInner[seqIndexInner] <= '0;
      end
    end else if (!freezeInput) begin
      specRasTopInner <= specRasTopNext;
      archRasTopInner <= archRasTopNext;
      if (squashInput.valid)
        baselineTopInner <= archRasTopInner;
      if (archWriteInner)
        archValidInner <= archValidInner | archWriteMaskInner;
      if (recoveryInput.active)
        replayActiveInner <= replayActiveNext;
      for (seqIndexInner = 0; seqIndexInner < RAS_STORAGE_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        specRasPcInner[seqIndexInner] <= specRasPcNext[seqIndexInner];
      end
    end
  end
`ifndef SYNTHESIS
  initial begin
    assert (RAS_ENTRIES >= 1 && RAS_ENTRIES <= 255)
      else $fatal(1, "BPU RAS parameter must be 1..255 (shared software depth carrier)");
  end
`endif
endmodule
