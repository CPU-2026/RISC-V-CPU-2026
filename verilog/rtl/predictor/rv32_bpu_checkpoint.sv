module rv32_bpu_checkpoint #(
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES
) (
  input  logic                         clkInput,
  input  logic                         rstNInput,

  input  rv32_pkg::checkpoint_input_t  checkpointInput,
  output rv32_pkg::checkpoint_output_t checkpointOutput
);
  import rv32_pkg::*;

  logic [7:0] ckptGhrInner [CKPT_ENTRIES];
  bpu_ckpt_id_t nextCkptIdInner;
  bpu_ckpt_id_t nextCkptIdNext;
  integer seqIndexInner;

  assign checkpointOutput.branchHistory = ckptGhrInner[checkpointInput.branchCheckpointId];
  assign checkpointOutput.recoveryHistory = ckptGhrInner[checkpointInput.squash.checkpointId];
  assign checkpointOutput.nextCheckpointId = nextCkptIdInner;

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
        ckptGhrInner[nextCkptIdInner] <= checkpointInput.globalHistory;
      end
      nextCkptIdInner <= nextCkptIdNext;
    end
  end
endmodule
