module rv32_bpu_ras #(
  parameter int unsigned RAS_ENTRIES = rv32_pkg::RAS_ENTRIES
) (
  input logic clkInput,
  input logic rstNInput,

  input rv32_pkg::predictor_fetch_info_t fetchInfoInput,
  input rv32_pkg::squash_input_t         squashInput,
  input rv32_pkg::rob_predictor_input_t  robInput,

  output logic [15:0]            rasTopOutput,
  output logic [31:0]            queryRetTargetOutput
);
  import rv32_pkg::*;
  localparam int unsigned RAS_PTR_W = RAS_ENTRIES > 1 ? $clog2(RAS_ENTRIES) : 1;
  localparam int unsigned RAS_STORAGE_ENTRIES = RAS_ENTRIES > 0 ? RAS_ENTRIES : 1;
  localparam int unsigned RAS_TOP_W = $clog2(RAS_STORAGE_ENTRIES + 1);

  logic [31:0] specRasPcInner [RAS_STORAGE_ENTRIES];
  logic [RAS_TOP_W-1:0] specRasTopInner;  // Depth, including the full state.
  logic [31:0] archRasPcInner [RAS_STORAGE_ENTRIES];
  logic [RAS_TOP_W-1:0] archRasTopInner;

  logic [RAS_TOP_W-1:0] specRasTopNext;
  logic [RAS_TOP_W-1:0] archRasTopNext;
  logic [31:0] specRasPcNext [RAS_STORAGE_ENTRIES];
  logic [31:0] archRasPcNext [RAS_STORAGE_ENTRIES];
  logic [RAS_TOP_W-1:0] normalRasTopInner, recoveryRasTopInner;
  logic [31:0] normalRasPcInner [RAS_STORAGE_ENTRIES];
  logic [31:0] recoveryRasPcInner [RAS_STORAGE_ENTRIES];
  rob_tag_t replayCountInner;
  rob_tag_t replayTagInner;
  logic replayCallInner, replayRetInner;
  logic replayRdLinkInner, replayRs1LinkInner;
  integer archIndexInner, normalIndexInner, recoveryIndexInner, selectIndexInner;
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
    for (archIndexInner = 0; archIndexInner < RAS_STORAGE_ENTRIES; archIndexInner = archIndexInner + 1)
      archRasPcNext[archIndexInner] = archRasPcInner[archIndexInner];

    if (robInput.willCommit) begin
      if (robInput.isHeadReturn && (archRasTopNext != '0))
        archRasTopNext = archRasTopNext - RAS_TOP_W'(1);
      if (robInput.isHeadCall && archRasTopNext < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
        archRasPcNext[archRasTopNext[RAS_PTR_W-1:0]] = robInput.headProgramCounter + 32'd4;
        archRasTopNext = archRasTopNext + RAS_TOP_W'(1);
      end
    end
  end

  always_comb begin
    normalRasTopInner = specRasTopInner;
    for (normalIndexInner = 0; normalIndexInner < RAS_STORAGE_ENTRIES; normalIndexInner = normalIndexInner + 1)
      normalRasPcInner[normalIndexInner] = specRasPcInner[normalIndexInner];

    if (fetchInfoInput.valid) begin
      if (fetchInfoInput.isReturn && (normalRasTopInner != '0))
        normalRasTopInner = normalRasTopInner - RAS_TOP_W'(1);
      if (fetchInfoInput.isCall && normalRasTopInner < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
        normalRasPcInner[normalRasTopInner[RAS_PTR_W-1:0]] = fetchInfoInput.programCounter + 32'd4;
        normalRasTopInner = normalRasTopInner + RAS_TOP_W'(1);
      end
    end
  end

  always_comb begin
    // Compute recovery independently of both squash.valid and willCommit.
    // The OLD architectural stack does not contain this cycle's retiring head,
    // so replay the whole surviving prefix, including the head and boundary,
    // exactly once. Architectural retirement proceeds separately above.
    recoveryRasTopInner = archRasTopInner;
    for (recoveryIndexInner = 0; recoveryIndexInner < RAS_STORAGE_ENTRIES; recoveryIndexInner = recoveryIndexInner + 1)
      recoveryRasPcInner[recoveryIndexInner] = archRasPcInner[recoveryIndexInner];
    replayCountInner = squashInput.robTag - robInput.headTag + rob_tag_t'(1);
    replayTagInner = '0;
    replayCallInner = 1'b0;
    replayRetInner = 1'b0;
    replayRdLinkInner = 1'b0;
    replayRs1LinkInner = 1'b0;
    for (recoveryIndexInner = 0; recoveryIndexInner < ROB_ENTRIES; recoveryIndexInner = recoveryIndexInner + 1) begin
      replayTagInner = robInput.headTag + rob_tag_t'(recoveryIndexInner);
      if ((recoveryIndexInner < replayCountInner) &&
          (robInput.replayEntries[recoveryIndexInner].robTag == replayTagInner)) begin
        replayRdLinkInner = (robInput.replayEntries[recoveryIndexInner].instruction[11:7] == 5'd1) ||
                         (robInput.replayEntries[recoveryIndexInner].instruction[11:7] == 5'd5);
        replayRs1LinkInner = (robInput.replayEntries[recoveryIndexInner].instruction[19:15] == 5'd1) ||
                          (robInput.replayEntries[recoveryIndexInner].instruction[19:15] == 5'd5);
        replayCallInner = ((robInput.replayEntries[recoveryIndexInner].instruction[6:0] == OPCODE_JAL) ||
                       ((robInput.replayEntries[recoveryIndexInner].instruction[6:0] == OPCODE_JALR) &&
                        (robInput.replayEntries[recoveryIndexInner].instruction[14:12] == 3'b000))) &&
                      replayRdLinkInner;
        replayRetInner = (robInput.replayEntries[recoveryIndexInner].instruction[6:0] == OPCODE_JALR) &&
                      (robInput.replayEntries[recoveryIndexInner].instruction[14:12] == 3'b000) &&
                      replayRs1LinkInner;
        if (replayRetInner && (recoveryRasTopInner != '0))
          recoveryRasTopInner = recoveryRasTopInner - RAS_TOP_W'(1);
        if (replayCallInner && recoveryRasTopInner < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
          recoveryRasPcInner[recoveryRasTopInner[RAS_PTR_W-1:0]] =
            robInput.replayEntries[recoveryIndexInner].programCounter + 32'd4;
          recoveryRasTopInner = recoveryRasTopInner + RAS_TOP_W'(1);
        end
      end
    end
  end

  always_comb begin
    specRasTopNext = squashInput.valid ? recoveryRasTopInner : normalRasTopInner;
    for (selectIndexInner = 0; selectIndexInner < RAS_STORAGE_ENTRIES; selectIndexInner = selectIndexInner + 1)
      specRasPcNext[selectIndexInner] = squashInput.valid ?
        recoveryRasPcInner[selectIndexInner] : normalRasPcInner[selectIndexInner];
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      specRasTopInner <= '0;
      archRasTopInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < RAS_STORAGE_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        specRasPcInner[seqIndexInner] <= '0;
        archRasPcInner[seqIndexInner] <= '0;
      end
    end else begin
      specRasTopInner <= specRasTopNext;
      archRasTopInner <= archRasTopNext;
      for (seqIndexInner = 0; seqIndexInner < RAS_STORAGE_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        specRasPcInner[seqIndexInner] <= specRasPcNext[seqIndexInner];
        archRasPcInner[seqIndexInner] <= archRasPcNext[seqIndexInner];
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
