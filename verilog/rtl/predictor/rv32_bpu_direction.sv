module rv32_bpu_direction #(
  parameter int unsigned BHT_ENTRIES = 256,
  parameter int unsigned CONDSEEN_ENTRIES = 512
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input logic freezeInput,

  input  logic [31:0]            queryPcInput,
  input  rv32_pkg::branch_training_input_t branchInput,
  input  rv32_pkg::direction_context_t branchContextInput,
  input  rv32_pkg::direction_history_input_t historyInput,
  output rv32_pkg::direction_prediction_output_t predictionOutput,
  output rv32_pkg::direction_context_t queryContextOutput
);
  import rv32_pkg::*;

  localparam int unsigned BHT_INDEX_W = $clog2(BHT_ENTRIES);
  localparam int unsigned COND_INDEX_W = $clog2(CONDSEEN_ENTRIES);

  logic [2:0] localPhtInner [BHT_ENTRIES];
  logic localHistoryInner [BHT_ENTRIES];
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
    queryLocalIdxInner = BHT_INDEX_W'({queryP2Inner, localHistoryInner[queryP2Inner[BHT_INDEX_W-1:0]]});
    queryGlobalIdxInner = queryP2Inner[BHT_INDEX_W-1:0] ^ ghrInner;
    querySelIdxInner = queryP2Inner[BHT_INDEX_W-1:0];
    queryCondIdxInner = queryP2Inner[COND_INDEX_W-1:0];
    predictionOutput.useGlobal = selectorInner[querySelIdxInner] >= 2'b10;
    queryContextOutput = '{localHistory:localHistoryInner[queryP2Inner[BHT_INDEX_W-1:0]],
      localPrediction:localPhtInner[queryLocalIdxInner] >= 3'b100,
      globalPrediction:globalPhtInner[queryGlobalIdxInner] >= 2'b10};
    predictionOutput.directionTaken = predictionOutput.useGlobal ?
                        (globalPhtInner[queryGlobalIdxInner] >= 2'b10) :
                        (localPhtInner[queryLocalIdxInner] >= 3'b100);
    predictionOutput.conditionalSeen = condseenInner[queryCondIdxInner];
  end

  always_comb begin
    branchP2Inner = branchInput.programCounter >> 2;
    branchLocalIdxInner = BHT_INDEX_W'({branchP2Inner, branchContextInput.localHistory});
    branchGlobalIdxInner = branchP2Inner[BHT_INDEX_W-1:0] ^ branchInput.globalHistory;
    branchSelIdxInner = branchP2Inner[BHT_INDEX_W-1:0];
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
      for (seqIndexInner = 0; seqIndexInner < BHT_ENTRIES; seqIndexInner = seqIndexInner + 1)
        localHistoryInner[seqIndexInner] <= 1'b0;
      for (seqIndexInner = 0; seqIndexInner < BHT_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        globalPhtInner[seqIndexInner] <= 2'b01;
        selectorInner[seqIndexInner] <= 2'b01;
      end
      for (seqIndexInner = 0; seqIndexInner < CONDSEEN_ENTRIES; seqIndexInner = seqIndexInner + 1)
        condseenInner[seqIndexInner] <= 1'b0;
    end else if (!freezeInput) begin
      if (branchInput.valid) begin
        localHistoryInner[branchP2Inner[BHT_INDEX_W-1:0]] <= branchInput.taken;
        if (branchInput.taken) begin
          if (globalPhtInner[branchGlobalIdxInner] != 2'b11)
            globalPhtInner[branchGlobalIdxInner] <= globalPhtInner[branchGlobalIdxInner] + 2'b01;
        end else begin
          if (globalPhtInner[branchGlobalIdxInner] != 2'b00)
            globalPhtInner[branchGlobalIdxInner] <= globalPhtInner[branchGlobalIdxInner] - 2'b01;
        end
        if (branchContextInput.globalPrediction == branchInput.taken &&
            branchContextInput.localPrediction != branchInput.taken) begin
          if (selectorInner[branchSelIdxInner] != 2'b11)
            selectorInner[branchSelIdxInner] <= selectorInner[branchSelIdxInner] + 2'b01;
        end else if (branchContextInput.localPrediction == branchInput.taken &&
                     branchContextInput.globalPrediction != branchInput.taken) begin
          if (selectorInner[branchSelIdxInner] != 2'b00)
            selectorInner[branchSelIdxInner] <= selectorInner[branchSelIdxInner] - 2'b01;
        end
        condseenInner[branchCondIdxInner] <= 1'b1;
      end

      ghrInner <= ghrNext;
    end
  end

  // Row-local arithmetic avoids a central old-counter read/update/write mux.
  for (genvar counterRow = 0; counterRow < BHT_ENTRIES; counterRow++) begin : g_local_counter
    always_ff @(posedge clkInput or negedge rstNInput) begin
      if (!rstNInput)
        localPhtInner[counterRow] <= 3'b011;
      else if (!freezeInput && branchInput.valid && branchLocalIdxInner == BHT_INDEX_W'(counterRow)) begin
        if (branchInput.taken && localPhtInner[counterRow] != 3'b111)
          localPhtInner[counterRow] <= localPhtInner[counterRow] + 3'b001;
        else if (!branchInput.taken && localPhtInner[counterRow] != 3'b000)
          localPhtInner[counterRow] <= localPhtInner[counterRow] - 3'b001;
      end
    end
  end
endmodule
