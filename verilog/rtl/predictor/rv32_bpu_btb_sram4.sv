// Four-bank BTB with independent metadata/target SRAMs and register valid bits.
// Each bank has one 1RW port for tag/type and one for target. A query may run
// alongside training to other banks; an older write to the queried bank drains
// first, so the query cannot observe stale state.
module rv32_bpu_btb_sram4 #(
  parameter int unsigned BTB_ENTRIES = 64
) (
  input logic clkInput,
  input logic rstNInput,

  input logic queryValidInput,
  output logic queryReadyOutput,
  input logic [31:0] queryPcInput,
  output logic responseValidOutput,
  input logic responseReadyInput,
  output logic [31:0] responsePcOutput,
  output rv32_pkg::btb_lookup_output_t lookupOutput,

  input logic trainingValidInput,
  output logic trainingReadyOutput,
  input rv32_pkg::btb_training_input_t trainingInput,
  output logic trainingDoneOutput,
  output logic initializedOutput
);
  import rv32_pkg::*;

  localparam int unsigned BANKS = 4;
  localparam int unsigned BANK_W = 2;
  localparam int unsigned INDEX_W = BTB_ENTRIES > 1 ? $clog2(BTB_ENTRIES) : 1;
  localparam int unsigned ROWS_PER_BANK = BTB_ENTRIES / BANKS;
  localparam int unsigned ROW_W = ROWS_PER_BANK > 1 ? $clog2(ROWS_PER_BANK) : 1;
  localparam int unsigned TAG_W = 32 - INDEX_W - 2;
  localparam int unsigned META_W = TAG_W + 2;
  localparam int unsigned TARGET_W = 30;

  localparam logic [1:0] INVALID = 2'b00;
  localparam logic [1:0] CONDITIONAL = 2'b01;
  localparam logic [1:0] UNCONDITIONAL = 2'b10;
  localparam logic [1:0] RETURN = 2'b11;

  typedef struct packed {
    logic valid;
    logic [INDEX_W-1:0] index;
    logic [TAG_W-1:0] tag;
    logic [1:0] state;
    logic targetWrite;
    logic [TARGET_W-1:0] target;
  } intent_t;

  typedef logic [ROW_W-1:0] row_t;
  intent_t batchIntentNext [3];
  intent_t batchIntentInner [3];
  logic [2:0] pendingIntentInner;
  logic trainingActiveInner;

  logic validInner [BTB_ENTRIES];
  logic targetValidInner [BTB_ENTRIES];
  logic [BANKS-1:0] queryGrantInner;
  logic [2:0] trainingGrantInner;
  intent_t grantIntentInner [BANKS];
  logic [BANKS-1:0] bankPendingInner;

  logic [BANKS-1:0] metaEnableInner, metaWriteInner;
  logic [BANKS-1:0] targetEnableInner, targetWriteInner;
  row_t metaAddressInner [BANKS], targetAddressInner [BANKS];
  logic [META_W-1:0] metaWdataInner [BANKS], metaRdataInner [BANKS];
  logic [TARGET_W-1:0] targetWdataInner [BANKS], targetRdataInner [BANKS];

  logic [INDEX_W-1:0] queryIndexInner;
  logic [BANK_W-1:0] queryBankInner;
  row_t queryRowInner;
  logic responseValidInner, responseHoldInner;
  logic [31:0] responsePcInner;
  logic responseEntryValidInner, responseTargetValidInner;
  logic [BANK_W-1:0] responseBankInner;
  logic [META_W-1:0] heldMetaInner;
  logic [TARGET_W-1:0] heldTargetInner;
  logic queryFireInner, trainingFireInner;
  logic [INDEX_W-1:0] fetchIndexInner, jumpIndexInner, branchIndexInner;
  logic fetchWriteInner, jumpWriteInner, branchWriteInner;
  logic fetchJumpSameInner, fetchBranchSameInner, jumpBranchSameInner;
  logic fetchTargetKnownInner;
  logic [TARGET_W-1:0] fetchTargetInner;
  logic [1:0] fetchStateInner;
  integer seqIndexInner;

  assign initializedOutput = rstNInput;
  assign trainingReadyOutput = rstNInput && !trainingActiveInner;
  assign trainingFireInner = trainingValidInput && trainingReadyOutput;
  assign queryIndexInner = queryPcInput[INDEX_W+1:2];
  assign queryBankInner = queryIndexInner[BANK_W-1:0];
  assign queryRowInner = row_t'(queryIndexInner >> BANK_W);

  // Preserve the register BTB's per-slot arbitration and resident-target rule,
  // but normalize the producer batch into at most three distinct-slot intents.
  always_comb begin
    fetchWriteInner = trainingInput.fetchValid;
    jumpWriteInner = trainingInput.jumpValid;
    branchWriteInner = trainingInput.branch.valid && trainingInput.branch.taken;
    fetchIndexInner = trainingInput.fetchProgramCounter[INDEX_W+1:2];
    jumpIndexInner = trainingInput.jumpProgramCounter[INDEX_W+1:2];
    branchIndexInner = trainingInput.branch.programCounter[INDEX_W+1:2];
    fetchJumpSameInner = fetchWriteInner && jumpWriteInner && fetchIndexInner == jumpIndexInner;
    fetchBranchSameInner = fetchWriteInner && branchWriteInner && fetchIndexInner == branchIndexInner;
    jumpBranchSameInner = jumpWriteInner && branchWriteInner && jumpIndexInner == branchIndexInner;

    fetchTargetKnownInner = 1'b1;
    fetchTargetInner = '0;
    if (!trainingInput.isReturn && trainingInput.jalTargetValid)
      fetchTargetInner = trainingInput.jalTarget[31:2];
    else if (fetchJumpSameInner)
      fetchTargetInner = trainingInput.jumpTarget[31:2];
    else if (fetchBranchSameInner)
      fetchTargetInner = trainingInput.branch.nextProgramCounter[31:2];
    else
      fetchTargetKnownInner = 1'b0;
    fetchStateInner = trainingInput.isReturn ? RETURN : UNCONDITIONAL;

    for (int i = 0; i < 3; i++) batchIntentNext[i] = '0;
    if (fetchWriteInner) begin
      batchIntentNext[0] = '{valid:1'b1, index:fetchIndexInner,
        tag:trainingInput.fetchProgramCounter[31:INDEX_W+2], state:fetchStateInner,
        targetWrite:fetchTargetKnownInner, target:fetchTargetInner};
    end
    if (jumpWriteInner && !fetchJumpSameInner) begin
      batchIntentNext[1] = '{valid:1'b1, index:jumpIndexInner,
        tag:trainingInput.jumpProgramCounter[31:INDEX_W+2],
        state:trainingInput.jumpIsReturn ? RETURN : UNCONDITIONAL,
        targetWrite:1'b1, target:trainingInput.jumpTarget[31:2]};
    end
    if (branchWriteInner && !fetchBranchSameInner && !jumpBranchSameInner) begin
      batchIntentNext[2] = '{valid:1'b1, index:branchIndexInner,
        tag:trainingInput.branch.programCounter[31:INDEX_W+2], state:CONDITIONAL,
        targetWrite:1'b1, target:trainingInput.branch.nextProgramCounter[31:2]};
    end
  end

  // Queries only wait for older writes to their own bank. Other banks continue
  // draining one training intent per cycle. A new batch accepted on this edge
  // is younger than a simultaneous query, so that query observes old SRAM data.
  always_comb begin
    bankPendingInner = '0;
    for (int i = 0; i < 3; i++)
      if (trainingActiveInner && pendingIntentInner[i])
        bankPendingInner[batchIntentInner[i].index[BANK_W-1:0]] = 1'b1;

    queryReadyOutput = rstNInput &&
      (!responseValidInner || responseReadyInput) && !bankPendingInner[queryBankInner];
    queryFireInner = queryValidInput && queryReadyOutput;

    for (int b = 0; b < BANKS; b++) begin
      queryGrantInner[b] = queryFireInner && queryBankInner == BANK_W'(b);
      grantIntentInner[b] = '0;
    end
    trainingGrantInner = '0;
    // Oldest source/index intent wins within a bank; independent banks write
    // simultaneously. Query conflicts are excluded by queryReadyOutput.
    for (int b = 0; b < BANKS; b++) begin
      if (trainingActiveInner && !queryGrantInner[b]) begin
        for (int i = 0; i < 3; i++) begin
          if (!grantIntentInner[b].valid && pendingIntentInner[i] &&
              batchIntentInner[i].index[BANK_W-1:0] == BANK_W'(b)) begin
            trainingGrantInner[i] = 1'b1;
            grantIntentInner[b] = batchIntentInner[i];
          end
        end
      end
    end
  end

  assign responseValidOutput = rstNInput && responseValidInner;
  assign responsePcOutput = responseValidOutput ? responsePcInner : 32'b0;
  always_comb begin
    logic [META_W-1:0] metaWord;
    logic [TARGET_W-1:0] targetWord;
    metaWord = heldMetaInner;
    targetWord = heldTargetInner;
    if (!responseHoldInner) begin
      metaWord = metaRdataInner[responseBankInner];
      targetWord = targetRdataInner[responseBankInner];
    end
    lookupOutput = '0;
    if (responseValidOutput) begin
      lookupOutput.hit = responseEntryValidInner && metaWord[1:0] != INVALID &&
        metaWord[2+:TAG_W] == responsePcInner[31:INDEX_W+2];
      // Preserve legacy semantics: valid entry metadata/target are exposed on
      // a tag miss, while reset-invalid and never-written targets are masked.
      lookupOutput.unconditional = responseEntryValidInner &&
        (metaWord[1:0] == UNCONDITIONAL || metaWord[1:0] == RETURN);
      lookupOutput.isReturn = responseEntryValidInner && metaWord[1:0] == RETURN;
      lookupOutput.target = responseEntryValidInner && responseTargetValidInner ?
        {targetWord, 2'b00} : 32'b0;
    end
  end

  always_comb begin
    metaEnableInner = '0;
    metaWriteInner = '0;
    targetEnableInner = '0;
    targetWriteInner = '0;
    for (int b = 0; b < BANKS; b++) begin
      metaAddressInner[b] = '0;
      targetAddressInner[b] = '0;
      metaWdataInner[b] = '0;
      targetWdataInner[b] = '0;
      if (queryGrantInner[b]) begin
        metaEnableInner[b] = 1'b1;
        targetEnableInner[b] = 1'b1;
        metaAddressInner[b] = queryRowInner;
        targetAddressInner[b] = queryRowInner;
      end else if (trainingActiveInner) begin
        for (int i = 0; i < 3; i++) begin
          if (trainingGrantInner[i] && batchIntentInner[i].index[BANK_W-1:0] == BANK_W'(b)) begin
            metaEnableInner[b] = 1'b1;
            metaWriteInner[b] = 1'b1;
            metaAddressInner[b] = row_t'(batchIntentInner[i].index >> BANK_W);
            metaWdataInner[b] = {batchIntentInner[i].tag, batchIntentInner[i].state};
            targetEnableInner[b] = batchIntentInner[i].targetWrite;
            targetWriteInner[b] = batchIntentInner[i].targetWrite;
            targetAddressInner[b] = row_t'(batchIntentInner[i].index >> BANK_W);
            targetWdataInner[b] = batchIntentInner[i].target;
          end
        end
      end
    end
  end

  for (genvar bank = 0; bank < BANKS; bank++) begin : g_bank
    sram_fakeram #(.DEPTH(ROWS_PER_BANK), .WIDTH(META_W),
                   .WRITE_GRANULARITY(META_W)) u_metadata (
      .clk(clkInput), .en(metaEnableInner[bank]), .we(metaWriteInner[bank]), .wmask(1'b1),
      .addr(metaAddressInner[bank]), .wdata(metaWdataInner[bank]), .rdata(metaRdataInner[bank])
    );
    sram_fakeram #(.DEPTH(ROWS_PER_BANK), .WIDTH(TARGET_W),
                   .WRITE_GRANULARITY(TARGET_W)) u_target (
      .clk(clkInput), .en(targetEnableInner[bank]), .we(targetWriteInner[bank]), .wmask(1'b1),
      .addr(targetAddressInner[bank]), .wdata(targetWdataInner[bank]), .rdata(targetRdataInner[bank])
    );
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (seqIndexInner = 0; seqIndexInner < BTB_ENTRIES; seqIndexInner++) begin
        validInner[seqIndexInner] <= 1'b0;
        targetValidInner[seqIndexInner] <= 1'b0;
      end
    end else begin
      for (int b = 0; b < BANKS; b++) begin
        if (metaEnableInner[b] && metaWriteInner[b]) begin
          for (int i = 0; i < 3; i++) begin
            if (trainingGrantInner[i] && batchIntentInner[i].index[BANK_W-1:0] == BANK_W'(b)) begin
              validInner[batchIntentInner[i].index] <= 1'b1;
              if (targetWriteInner[b]) targetValidInner[batchIntentInner[i].index] <= 1'b1;
            end
          end
        end
      end
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      responseValidInner <= 1'b0;
      responseHoldInner <= 1'b0;
      responsePcInner <= '0;
      responseEntryValidInner <= 1'b0;
      responseTargetValidInner <= 1'b0;
      responseBankInner <= '0;
      heldMetaInner <= '0;
      heldTargetInner <= '0;
      trainingActiveInner <= 1'b0;
      pendingIntentInner <= '0;
      trainingDoneOutput <= 1'b0;
      for (int i = 0; i < 3; i++) batchIntentInner[i] <= '0;
    end else begin
      trainingDoneOutput <= 1'b0;
      if (queryFireInner) begin
        responseValidInner <= 1'b1;
        responseHoldInner <= 1'b0;
        responsePcInner <= queryPcInput;
        responseEntryValidInner <= validInner[queryIndexInner];
        responseTargetValidInner <= targetValidInner[queryIndexInner];
        responseBankInner <= queryBankInner;
      end else if (responseValidInner && responseReadyInput) begin
        responseValidInner <= 1'b0;
        responseHoldInner <= 1'b0;
      end else if (responseValidInner && !responseHoldInner) begin
        heldMetaInner <= metaRdataInner[responseBankInner];
        heldTargetInner <= targetRdataInner[responseBankInner];
        responseHoldInner <= 1'b1;
      end

      if (trainingFireInner) begin
        batchIntentInner[0] <= batchIntentNext[0];
        batchIntentInner[1] <= batchIntentNext[1];
        batchIntentInner[2] <= batchIntentNext[2];
        pendingIntentInner <= {batchIntentNext[2].valid, batchIntentNext[1].valid,
                                batchIntentNext[0].valid};
        trainingActiveInner <= |{batchIntentNext[2].valid, batchIntentNext[1].valid,
                                  batchIntentNext[0].valid};
        if (!(|{batchIntentNext[2].valid, batchIntentNext[1].valid,
                batchIntentNext[0].valid})) trainingDoneOutput <= 1'b1;
      end else if (trainingActiveInner) begin
        pendingIntentInner <= pendingIntentInner & ~trainingGrantInner;
        if (!(|(pendingIntentInner & ~trainingGrantInner))) begin
          trainingActiveInner <= 1'b0;
          trainingDoneOutput <= 1'b1;
        end
      end
    end
  end

`ifndef SYNTHESIS
  initial assert (BTB_ENTRIES >= BANKS && (BTB_ENTRIES & (BTB_ENTRIES - 1)) == 0 &&
                  (BTB_ENTRIES % BANKS) == 0 && TAG_W >= 1)
    else $fatal(1, "four-bank BTB entries must be power-of-two >=4 with nonempty tag");
  always @(posedge clkInput) if (rstNInput) begin
    assert (!(queryFireInner && bankPendingInner[queryBankInner]))
      else $fatal(1, "BTB query overtook an older same-bank training write");
    for (int i = 0; i < BTB_ENTRIES; i++)
      assert (!targetValidInner[i] || validInner[i])
        else $fatal(1, "BTB targetValid without a valid row");
  end
`endif
endmodule
