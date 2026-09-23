module rv32_bpu_ras #(
  parameter int unsigned RAS_ENTRIES = 8
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
  localparam int unsigned RAS_PTR_W = $clog2(RAS_ENTRIES);

  logic [31:0] specRasPcInner [RAS_ENTRIES];
  logic [15:0] specRasTopInner;  // TOS of spec RAS
  logic [31:0] archRasPcInner [RAS_ENTRIES];
  logic [15:0] archRasTopInner;  // TOS of arch RAS

  logic [15:0] specRasTopNext;
  logic [15:0] archRasTopNext;
  logic [31:0] specRasPcNext [RAS_ENTRIES];
  logic [31:0] archRasPcNext [RAS_ENTRIES];
  rob_tag_t replayCountInner;
  rob_tag_t replayTagInner;
  logic replayCallInner, replayRetInner;
  logic replayRdLinkInner, replayRs1LinkInner;
  integer combIndexInner;
  integer seqIndexInner;

  always_comb begin
    if (specRasTopInner == 16'd0)
      queryRetTargetOutput = 32'd0;
    else
      queryRetTargetOutput = specRasPcInner[RAS_PTR_W'(specRasTopInner - 16'd1)];
  end  // query the return address

  assign rasTopOutput = specRasTopInner;

  always_comb begin
    specRasTopNext = specRasTopInner;
    archRasTopNext = archRasTopInner;
    replayCountInner = squashInput.robTag - robInput.headTag + rob_tag_t'(1);
    replayTagInner = '0;
    replayCallInner = 1'b0;
    replayRetInner = 1'b0;
    replayRdLinkInner = 1'b0;
    replayRs1LinkInner = 1'b0;
    for (combIndexInner = 0; combIndexInner < RAS_ENTRIES; combIndexInner = combIndexInner + 1) begin
      specRasPcNext[combIndexInner] = specRasPcInner[combIndexInner];
      archRasPcNext[combIndexInner] = archRasPcInner[combIndexInner];
    end

    if (robInput.willCommit) begin
      if (robInput.isHeadCall) begin
        archRasPcNext[archRasTopNext[RAS_PTR_W-1:0]] = robInput.headProgramCounter + 32'd4;
        archRasTopNext = archRasTopNext + 16'd1;
      end else if (robInput.isHeadReturn && (archRasTopNext != 16'd0)) begin
        archRasTopNext = archRasTopNext - 16'd1;
      end
    end

    if (squashInput.valid) begin
      // Start at the post-commit architectural stack, then replay every
      // surviving ROB instruction (including the mispredicted boundaryInput).
      // Skipping a simultaneous commit avoids applying it twice.
      specRasTopNext = archRasTopNext;
      for (combIndexInner = 0; combIndexInner < RAS_ENTRIES; combIndexInner = combIndexInner + 1)
        specRasPcNext[combIndexInner] = archRasPcNext[combIndexInner];
      for (combIndexInner = 0; combIndexInner < ROB_ENTRIES; combIndexInner = combIndexInner + 1) begin
        replayTagInner = robInput.headTag + rob_tag_t'(combIndexInner);
        if ((combIndexInner < replayCountInner) &&
            (robInput.replayEntries[combIndexInner].robTag == replayTagInner) &&
            !(robInput.willCommit && (combIndexInner == 0))) begin
          replayRdLinkInner = (robInput.replayEntries[combIndexInner].instruction[11:7] == 5'd1) ||
                           (robInput.replayEntries[combIndexInner].instruction[11:7] == 5'd5);
          replayRs1LinkInner = (robInput.replayEntries[combIndexInner].instruction[19:15] == 5'd1) ||
                            (robInput.replayEntries[combIndexInner].instruction[19:15] == 5'd5);
          replayCallInner = ((robInput.replayEntries[combIndexInner].instruction[6:0] == OPCODE_JAL) ||
                         ((robInput.replayEntries[combIndexInner].instruction[6:0] == OPCODE_JALR) &&
                          (robInput.replayEntries[combIndexInner].instruction[14:12] == 3'b000))) &&
                        replayRdLinkInner;
          replayRetInner = (robInput.replayEntries[combIndexInner].instruction[6:0] == OPCODE_JALR) &&
                        (robInput.replayEntries[combIndexInner].instruction[14:12] == 3'b000) &&
                       replayRs1LinkInner && !replayRdLinkInner;
          if (replayCallInner) begin
            specRasPcNext[specRasTopNext[RAS_PTR_W-1:0]] =
              robInput.replayEntries[combIndexInner].programCounter + 32'd4;
            specRasTopNext = specRasTopNext + 16'd1;
          end else if (replayRetInner && (specRasTopNext != 16'd0)) begin
            specRasTopNext = specRasTopNext - 16'd1;
          end
        end
      end
    end else if (fetchInfoInput.valid) begin
      if (fetchInfoInput.isCall) begin
        specRasPcNext[specRasTopNext[RAS_PTR_W-1:0]] = fetchInfoInput.programCounter + 32'd4;
        specRasTopNext = specRasTopNext + 16'd1;
      end else if (fetchInfoInput.isReturn && (specRasTopNext != 16'd0)) begin
        specRasTopNext = specRasTopNext - 16'd1;
      end
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      specRasTopInner <= '0;
      archRasTopInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < RAS_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        specRasPcInner[seqIndexInner] <= '0;
        archRasPcInner[seqIndexInner] <= '0;
      end
    end else begin
      specRasTopInner <= specRasTopNext;
      archRasTopInner <= archRasTopNext;
      for (seqIndexInner = 0; seqIndexInner < RAS_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        specRasPcInner[seqIndexInner] <= specRasPcNext[seqIndexInner];
        archRasPcInner[seqIndexInner] <= archRasPcNext[seqIndexInner];
      end
    end
  end
endmodule
