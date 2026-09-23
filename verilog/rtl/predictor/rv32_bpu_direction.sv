module rv32_bpu_direction #(
  parameter int unsigned BHT_ENTRIES = 256,
  parameter int unsigned CONDSEEN_ENTRIES = 512
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,

  input  logic [31:0]            queryPcInput,
  input  rv32_pkg::branch_training_input_t branchInput,
  input  rv32_pkg::direction_history_input_t historyInput,
  output rv32_pkg::direction_prediction_output_t predictionOutput
);
  import rv32_pkg::*;

  localparam int unsigned BHT_INDEX_W = $clog2(BHT_ENTRIES);
  localparam int unsigned COND_INDEX_W = $clog2(CONDSEEN_ENTRIES);

  logic [1:0] localPhtInner [BHT_ENTRIES];
  logic [1:0] globalPhtInner [BHT_ENTRIES];
  logic [1:0] selectorInner [BHT_ENTRIES];
  logic [7:0] ghrInner;

  logic condseenInner [CONDSEEN_ENTRIES];

  logic [31:0] queryP2Inner;
  logic [BHT_INDEX_W-1:0] queryLocalIdxInner, queryGlobalIdxInner, querySelIdxInner;
  logic [COND_INDEX_W-1:0] queryCondIdxInner;

  logic [31:0] branchP2Inner;
  logic [BHT_INDEX_W-1:0] branchLocalIdxInner, branchGlobalIdxInner, branchSelIdxInner;
  logic [COND_INDEX_W-1:0] branchCondIdxInner;

  logic [7:0] ghrNext;
  integer combIndexInner;
  integer seqIndexInner;

  always_comb begin
    queryP2Inner = queryPcInput >> 2;
    queryLocalIdxInner = queryP2Inner[BHT_INDEX_W-1:0];
    queryGlobalIdxInner = queryP2Inner[BHT_INDEX_W-1:0] ^ ghrInner;
    querySelIdxInner = queryP2Inner[BHT_INDEX_W-1:0] ^ ghrInner;
    queryCondIdxInner = queryP2Inner[COND_INDEX_W-1:0];
    predictionOutput.useGlobal = selectorInner[querySelIdxInner] >= 2'b10;
    predictionOutput.directionTaken = predictionOutput.useGlobal ?
                        (globalPhtInner[queryGlobalIdxInner] >= 2'b10) :
                        (localPhtInner[queryLocalIdxInner] >= 2'b10);
    predictionOutput.conditionalSeen = condseenInner[queryCondIdxInner];
  end

  always_comb begin
    branchP2Inner = branchInput.programCounter >> 2;
    branchLocalIdxInner = branchP2Inner[BHT_INDEX_W-1:0];
    branchGlobalIdxInner = branchP2Inner[BHT_INDEX_W-1:0] ^ branchInput.globalHistory;
    branchSelIdxInner = branchP2Inner[BHT_INDEX_W-1:0] ^ branchInput.globalHistory;
    branchCondIdxInner = branchP2Inner[COND_INDEX_W-1:0];
  end

  always_comb begin
    ghrNext = ghrInner;
    if (historyInput.fetchAccepted && !historyInput.squashValid) begin
      if (historyInput.queryShift)
        ghrNext = {ghrInner[6:0], historyInput.queryShiftValue};
    end
    if (historyInput.squashValid)
      ghrNext = historyInput.recoveryHistory;
  end

  assign predictionOutput.globalHistory = ghrInner;

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      ghrInner <= 8'd0;
      for (seqIndexInner = 0; seqIndexInner < BHT_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        localPhtInner[seqIndexInner] <= 2'b01;
        globalPhtInner[seqIndexInner] <= 2'b01;
        selectorInner[seqIndexInner] <= 2'b01;
      end
      for (seqIndexInner = 0; seqIndexInner < CONDSEEN_ENTRIES; seqIndexInner = seqIndexInner + 1)
        condseenInner[seqIndexInner] <= 1'b0;
    end else begin
      if (branchInput.valid) begin
        if (branchInput.taken) begin
          if (localPhtInner[branchLocalIdxInner] != 2'b11)
            localPhtInner[branchLocalIdxInner] <= localPhtInner[branchLocalIdxInner] + 2'b01;
          if (globalPhtInner[branchGlobalIdxInner] != 2'b11)
            globalPhtInner[branchGlobalIdxInner] <= globalPhtInner[branchGlobalIdxInner] + 2'b01;
        end else begin
          if (localPhtInner[branchLocalIdxInner] != 2'b00)
            localPhtInner[branchLocalIdxInner] <= localPhtInner[branchLocalIdxInner] - 2'b01;
          if (globalPhtInner[branchGlobalIdxInner] != 2'b00)
            globalPhtInner[branchGlobalIdxInner] <= globalPhtInner[branchGlobalIdxInner] - 2'b01;
        end
        if ((globalPhtInner[branchGlobalIdxInner] >= 2'b10) == branchInput.taken &&
            (localPhtInner[branchLocalIdxInner] >= 2'b10) != branchInput.taken) begin
          if (selectorInner[branchSelIdxInner] != 2'b11)
            selectorInner[branchSelIdxInner] <= selectorInner[branchSelIdxInner] + 2'b01;
        end else if ((localPhtInner[branchLocalIdxInner] >= 2'b10) == branchInput.taken &&
                     (globalPhtInner[branchGlobalIdxInner] >= 2'b10) != branchInput.taken) begin
          if (selectorInner[branchSelIdxInner] != 2'b00)
            selectorInner[branchSelIdxInner] <= selectorInner[branchSelIdxInner] - 2'b01;
        end
        condseenInner[branchCondIdxInner] <= 1'b1;
      end

      ghrInner <= ghrNext;
    end
  end
endmodule
