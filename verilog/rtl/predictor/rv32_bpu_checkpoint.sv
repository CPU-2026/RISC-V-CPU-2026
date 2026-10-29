module rv32_bpu_checkpoint #(
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES,
  parameter int unsigned FETCH_WIDTH = 1
) (
  input  logic                         clkInput,
  input  logic                         rstNInput,
  input logic freezeInput,
  input logic secondAcceptedInput,

  input  rv32_pkg::checkpoint_input_t  checkpointInput,
  input  rv32_pkg::direction_context_t queryContextInput,
  output rv32_pkg::checkpoint_output_t checkpointOutput,
  output rv32_pkg::direction_context_t branchContextOutput,
  output rv32_pkg::bpu_ckpt_id_t nextCheckpointIdOutput,
  input logic [2:0] acceptedCountInput
);
  import rv32_pkg::*;
  if (FETCH_WIDTH != 1 && FETCH_WIDTH != 2 && FETCH_WIDTH != 4) begin : g_invalid_fetch_width
    initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
  end

`ifndef SYNTHESIS
  initial begin
    // The configured core owns ROB + I$ requests + FQ + IQ instructions.
    // A local array-size override cannot change the package identity width.
    assert (CKPT_ENTRIES == BPU_CKPT_ENTRIES && CKPT_ENTRIES == (1 << BPU_CKPT_ID_W) &&
            CKPT_ENTRIES >= ROB_ENTRIES + FETCH_REQUEST_ENTRIES + FQ_ENTRIES + IQ_ENTRIES &&
            CKPT_ENTRIES <= 64)
      else $fatal(1, "BPU checkpoint parameter must match package/CID width and cover configured live budget");
  end
`endif

  localparam int unsigned CKPT_ADDR_W = CKPT_ENTRIES > 1 ? $clog2(CKPT_ENTRIES) : 1;
  logic [7:0] ckptGhrInner [CKPT_ENTRIES];
  direction_context_t ckptDirectionInner [CKPT_ENTRIES];
  bpu_ckpt_id_t nextCkptIdInner;
  bpu_ckpt_id_t nextCkptIdNext;
  integer seqIndexInner;

  assign checkpointOutput.branchHistory = ckptGhrInner[CKPT_ADDR_W'(checkpointInput.branchCheckpointId)];
  assign branchContextOutput = ckptDirectionInner[CKPT_ADDR_W'(checkpointInput.branchCheckpointId)];
  assign checkpointOutput.recoveryHistory = ckptGhrInner[CKPT_ADDR_W'(checkpointInput.squash.checkpointId)];
  assign checkpointOutput.nextCheckpointId = nextCkptIdInner;
  // This OLD register is independent of fetchAccepted. A separate wire keeps
  // the ready -> accepted path out of the packed branch/recovery lookup bus.
  assign nextCheckpointIdOutput = nextCkptIdInner;

  always_comb begin
    nextCkptIdNext = nextCkptIdInner;
    if (checkpointInput.fetchAccepted && !checkpointInput.squash.valid)
      nextCkptIdNext = nextCkptIdInner + (FETCH_WIDTH==4 ? bpu_ckpt_id_t'(acceptedCountInput) :
        bpu_ckpt_id_t'(1)+bpu_ckpt_id_t'(FETCH_WIDTH == 2 && secondAcceptedInput));
    if (checkpointInput.squash.valid)
      nextCkptIdNext = checkpointInput.squash.checkpointId + bpu_ckpt_id_t'(1);
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      nextCkptIdInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < CKPT_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        ckptGhrInner[seqIndexInner] <= 8'd0;
        ckptDirectionInner[seqIndexInner] <= '0;
      end
    end else if (!freezeInput) begin
      if (checkpointInput.fetchAccepted && !checkpointInput.squash.valid) begin
        ckptGhrInner[CKPT_ADDR_W'(nextCkptIdInner)] <= checkpointInput.globalHistory;
        ckptDirectionInner[CKPT_ADDR_W'(nextCkptIdInner)] <= queryContextInput;
        // A packet ends at its first CFI. A lane1 CFI owns this context;
        // lane0 is not conditional and its unused direction bits never train.
        if(FETCH_WIDTH == 2 && secondAcceptedInput) begin
          ckptGhrInner[CKPT_ADDR_W'(nextCkptIdInner+bpu_ckpt_id_t'(1))] <= checkpointInput.globalHistory;
          ckptDirectionInner[CKPT_ADDR_W'(nextCkptIdInner+bpu_ckpt_id_t'(1))] <= queryContextInput;
        end
        if (FETCH_WIDTH==4) begin
          for (int lane=1;lane<4;lane++) if (lane<int'(acceptedCountInput)) begin
            ckptGhrInner[CKPT_ADDR_W'(nextCkptIdInner+bpu_ckpt_id_t'(lane))] <= checkpointInput.globalHistory;
            ckptDirectionInner[CKPT_ADDR_W'(nextCkptIdInner+bpu_ckpt_id_t'(lane))] <= queryContextInput;
          end
        end
      end
      nextCkptIdInner <= nextCkptIdNext;
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !freezeInput && checkpointInput.fetchAccepted && FETCH_WIDTH==4)
    assert(acceptedCountInput>=1 && acceptedCountInput<=4) else $fatal(1,"invalid four-fetch checkpoint prefix");
`endif
endmodule
