module rv32_bpu_checkpoint #(
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES
) (
  input  logic                         clkInput,
  input  logic                         rstNInput,

  input  rv32_pkg::checkpoint_input_t  checkpointInput,
  output rv32_pkg::checkpoint_output_t checkpointOutput,
  output rv32_pkg::bpu_ckpt_id_t nextCheckpointIdOutput
);
  import rv32_pkg::*;

`ifndef SYNTHESIS
  initial begin
    // The configured core owns ROB + I$ requests + FQ4 + IQ4 instructions.
    // A local array-size override cannot change the package identity width.
    assert (CKPT_ENTRIES == BPU_CKPT_ENTRIES && CKPT_ENTRIES == (1 << BPU_CKPT_ID_W) &&
            CKPT_ENTRIES >= ROB_ENTRIES + FETCH_REQUEST_ENTRIES + 8 && CKPT_ENTRIES <= 64)
      else $fatal(1, "BPU checkpoint parameter must match package/CID width and cover configured live budget");
  end
`endif

  localparam int unsigned CKPT_ADDR_W = CKPT_ENTRIES > 1 ? $clog2(CKPT_ENTRIES) : 1;
  logic [7:0] ckptGhrInner [CKPT_ENTRIES];
  bpu_ckpt_id_t nextCkptIdInner;
  bpu_ckpt_id_t nextCkptIdNext;
  integer seqIndexInner;

  assign checkpointOutput.branchHistory = ckptGhrInner[CKPT_ADDR_W'(checkpointInput.branchCheckpointId)];
  assign checkpointOutput.recoveryHistory = ckptGhrInner[CKPT_ADDR_W'(checkpointInput.squash.checkpointId)];
  assign checkpointOutput.nextCheckpointId = nextCkptIdInner;
  // This OLD register is independent of fetchAccepted. A separate wire keeps
  // the ready -> accepted path out of the packed branch/recovery lookup bus.
  assign nextCheckpointIdOutput = nextCkptIdInner;

  always_comb begin
    nextCkptIdNext = nextCkptIdInner;
    if (checkpointInput.fetchAccepted && !checkpointInput.squash.valid)
      nextCkptIdNext = nextCkptIdInner + bpu_ckpt_id_t'(1);
    if (checkpointInput.squash.valid)
      nextCkptIdNext = checkpointInput.squash.checkpointId + bpu_ckpt_id_t'(1);
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      nextCkptIdInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < CKPT_ENTRIES; seqIndexInner = seqIndexInner + 1) begin
        ckptGhrInner[seqIndexInner] <= 8'd0;
      end
    end else begin
      if (checkpointInput.fetchAccepted && !checkpointInput.squash.valid) begin
        ckptGhrInner[CKPT_ADDR_W'(nextCkptIdInner)] <= checkpointInput.globalHistory;
      end
      nextCkptIdInner <= nextCkptIdNext;
    end
  end
endmodule
