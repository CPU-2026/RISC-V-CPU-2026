module rv32_bpu_ras #(
  parameter int unsigned RAS_ENTRIES = rv32_pkg::RAS_ENTRIES,
  parameter int unsigned COMMIT_WIDTH = 1
) (
  input logic clkInput,
  input logic rstNInput,
  input logic freezeInput,

/* verilator lint_off UNUSEDSIGNAL */   input rv32_pkg::predictor_fetch_info_t fetchInfoInput, /* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_off UNUSEDSIGNAL */   input rv32_pkg::squash_input_t         squashInput, /* verilator lint_on UNUSEDSIGNAL */
  input rv32_pkg::rob_predictor_input_t [COMMIT_WIDTH-1:0] robInput,
/* verilator lint_off UNUSEDSIGNAL */   input rv32_pkg::recovery_step_t recoveryInput, /* verilator lint_on UNUSEDSIGNAL */

  output logic [15:0]            rasTopOutput,
  output logic [31:0]            queryRetTargetOutput
);
  import rv32_pkg::*;
  if (COMMIT_WIDTH != 1 && COMMIT_WIDTH != 2 && COMMIT_WIDTH != 4) begin : g_invalid_commit_width
    initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
  end
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
  localparam bit RAIL_REPLAY = RECOVERY_WIDTH==8 && RAS_STORAGE_ENTRIES==8;
  logic [RAS_TOP_W-1:0] replayTop;
  logic replayStillOpen;
  logic [RAS_STORAGE_ENTRIES-1:0] replayWrite;
  logic [31:0] replayData [RAS_STORAGE_ENTRIES];
  if (RAIL_REPLAY) begin : g_replay_rails
    function automatic logic [15:0] advance_depth(input logic [15:0] d, input logic push, pop);
      // pop+push replaces the top, except at zero (becomes one) and at
      // encodings above eight (pop only). No unreachable-state waiver.
      return ({16{!push && !pop}} & d) |
             ({16{ push && !pop}} & ((d & 16'hff00) | ((d & 16'h00ff)<<1))) |
             ({16{!push &&  pop}} & ((d>>1) | (d & 16'h0001))) |
             ({16{ push &&  pop}} & ((d & 16'h01fe) | ((d & 16'h0001)<<1) | ((d & 16'hfe00)>>1)));
    endfunction
    wire [3:0] initialDepth=recoveryInput.first ? baselineTopInner : specRasTopInner;
    wire initialOpen=recoveryInput.first || replayActiveInner;
    wire [7:0] stop, push, pop;
    wire [7:0][31:0] linkPc;
    for(genvar i=0;i<8;i++) begin : g_decode
      wire rob_replay_ras_t item=robInput[0].replayRasWindow[i];
      wire rob_tag_t expected=recoveryInput.nextTag+rob_tag_t'(i);
      wire inWindow=int'(recoveryInput.offset)+i<ROB_ENTRIES && int'(recoveryInput.offset)+i<int'(recoveryInput.liveCount);
      wire tagEqual=item.robTag==expected;
      wire eligible=initialOpen && !(|(stop & 8'((1<<i)-1))) && inWindow && tagEqual;
      wire jalr=item.opcode==OPCODE_JALR && item.funct3==3'b000;
      assign stop[i]=inWindow && (!tagEqual || expected==recoveryInput.squashTag);
      assign push[i]=eligible && (item.opcode==OPCODE_JAL || jalr) && (item.rd==5'd1 || item.rd==5'd5);
      assign pop[i]=eligible && jalr && (item.rs1==5'd1 || item.rs1==5'd5) && item.rd!=item.rs1;
      assign linkPc[i]=item.programCounter+32'd4;
    end
    assign replayStillOpen=initialOpen && !(|stop);
    wire [15:0] d0=16'h0001<<initialDepth;
    wire [15:0] d1=advance_depth(d0,push[0],pop[0]);
    wire [15:0] d2=advance_depth(d1,push[1],pop[1]);
    wire [15:0] d3=advance_depth(d2,push[2],pop[2]);
    wire [15:0] d4=advance_depth(d3,push[3],pop[3]);
    wire [15:0] d5=advance_depth(d4,push[4],pop[4]);
    wire [15:0] d6=advance_depth(d5,push[5],pop[5]);
    wire [15:0] d7=advance_depth(d6,push[6],pop[6]);
    wire [15:0] d8=advance_depth(d7,push[7],pop[7]);
    assign replayTop={|(d8 & 16'hff00),|(d8 & 16'hf0f0),|(d8 & 16'hcccc),|(d8 & 16'haaaa)};
    for(genvar slot=0;slot<8;slot++) begin : g_slot
      wire [7:0] hits;
      assign hits[0]=push[0] && ((d0[slot] && (slot==0 || !pop[0])) || (d0[slot+1] && pop[0]));
      assign hits[1]=push[1] && ((d1[slot] && (slot==0 || !pop[1])) || (d1[slot+1] && pop[1]));
      assign hits[2]=push[2] && ((d2[slot] && (slot==0 || !pop[2])) || (d2[slot+1] && pop[2]));
      assign hits[3]=push[3] && ((d3[slot] && (slot==0 || !pop[3])) || (d3[slot+1] && pop[3]));
      assign hits[4]=push[4] && ((d4[slot] && (slot==0 || !pop[4])) || (d4[slot+1] && pop[4]));
      assign hits[5]=push[5] && ((d5[slot] && (slot==0 || !pop[5])) || (d5[slot+1] && pop[5]));
      assign hits[6]=push[6] && ((d6[slot] && (slot==0 || !pop[6])) || (d6[slot+1] && pop[6]));
      assign hits[7]=push[7] && ((d7[slot] && (slot==0 || !pop[7])) || (d7[slot+1] && pop[7]));
      wire [7:0][31:0] data;
      for(genvar lane=0;lane<8;lane++) begin : g_select
        localparam logic [7:0] YOUNGER=8'(~((1<<(lane+1))-1));
        wire selected=hits[lane] && !(|(hits & YOUNGER));
        assign data[lane]=linkPc[lane] & {32{selected}};
      end
      assign replayWrite[slot]=|hits;
      assign replayData[slot]=((data[0]|data[1])|(data[2]|data[3])) |
                              ((data[4]|data[5])|(data[6]|data[7]));
    end
  end else begin : g_scalar_restore
    assign replayTop='0;
    assign replayStillOpen=1'b0;
    assign replayWrite='0;
    for(genvar i=0;i<RAS_STORAGE_ENTRIES;i++) assign replayData[i]='0;
  end

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
    for (int lane = 0; lane < COMMIT_WIDTH; lane++) begin
     if (!freezeInput && !squashInput.valid && !recoveryInput.active && robInput[lane].willCommit) begin
      if (robInput[lane].isHeadReturn && (archRasTopNext != '0))
        archRasTopNext = archRasTopNext - RAS_TOP_W'(1);
      if (robInput[lane].isHeadCall && archRasTopNext < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
        archWriteInner = 1'b1;
        archWriteMaskInner[archRasTopNext[RAS_PTR_W-1:0]] = 1'b1;
        archWriteDataInner[int'(archRasTopNext)*32 +: 32] = robInput[lane].headProgramCounter + 32'd4;
        archRasTopNext = archRasTopNext + RAS_TOP_W'(1);
      end
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
      if (RAIL_REPLAY) begin
        replayActiveNext=replayStillOpen;
        specRasTopNext=replayTop;
        for(int slot=0;slot<RAS_STORAGE_ENTRIES;slot++)
          if(replayWrite[slot]) specRasPcNext[slot]=replayData[slot];
      end else for (laneInner = 0; laneInner < RECOVERY_WIDTH; laneInner = laneInner + 1) begin
        windowIndexInner = int'(recoveryInput.offset) + laneInner;
        replayTagInner = recoveryInput.nextTag + rob_tag_t'(laneInner);
        if (replayActiveNext && windowIndexInner < ROB_ENTRIES &&
            windowIndexInner < int'(recoveryInput.liveCount)) begin
          if (robInput[0].replayRasWindow[laneInner].robTag == replayTagInner) begin
            replayRdLinkInner = (robInput[0].replayRasWindow[laneInner].rd == 5'd1) ||
                              (robInput[0].replayRasWindow[laneInner].rd == 5'd5);
            replayRs1LinkInner = (robInput[0].replayRasWindow[laneInner].rs1 == 5'd1) ||
                               (robInput[0].replayRasWindow[laneInner].rs1 == 5'd5);
            replayCallInner = ((robInput[0].replayRasWindow[laneInner].opcode == OPCODE_JAL) ||
                            ((robInput[0].replayRasWindow[laneInner].opcode == OPCODE_JALR) &&
                             (robInput[0].replayRasWindow[laneInner].funct3 == 3'b000))) && replayRdLinkInner;
            replayRetInner = (robInput[0].replayRasWindow[laneInner].opcode == OPCODE_JALR) &&
                           (robInput[0].replayRasWindow[laneInner].funct3 == 3'b000) && replayRs1LinkInner &&
              robInput[0].replayRasWindow[laneInner].rd != robInput[0].replayRasWindow[laneInner].rs1;
            if (replayRetInner && (specRasTopNext != '0))
              specRasTopNext = specRasTopNext - RAS_TOP_W'(1);
            if (replayCallInner && specRasTopNext < RAS_TOP_W'(RAS_STORAGE_ENTRIES)) begin
              specRasPcNext[specRasTopNext[RAS_PTR_W-1:0]] =
                robInput[0].replayRasWindow[laneInner].programCounter + 32'd4;
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
