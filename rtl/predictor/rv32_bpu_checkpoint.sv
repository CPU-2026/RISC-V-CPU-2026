module rv32_bpu_checkpoint #(
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         fetch_accept_i,
  input  logic                         squash_valid_i,
  input  rv32_pkg::bpu_ckpt_id_t       squash_ckpt_id_i,
  input  rv32_pkg::bpu_ckpt_id_t       branch_ckpt_id_i,

  input  logic [7:0]                   ghr_i,
  input  logic [7:0]                   align_tail_i,
  input  logic [7:0]                   ras_top_i,

  output logic [7:0]                   branch_ghr_o,
  output logic [7:0]                   squash_ghr_o,
  output logic [7:0]                   squash_align_tail_o,
  output logic [7:0]                   squash_ras_top_o,
  output rv32_pkg::bpu_ckpt_id_t       predicted_ckpt_id_o
);
  import rv32_pkg::*;

  logic [7:0] ckpt_ghr_q [0:CKPT_ENTRIES-1];
  logic [7:0] ckpt_align_tail_q [0:CKPT_ENTRIES-1];
  logic [7:0] ckpt_ras_top_q [0:CKPT_ENTRIES-1];
  bpu_ckpt_id_t next_ckpt_id_q;

  bpu_ckpt_id_t next_ckpt_id_next;
  integer seq_i;

  assign branch_ghr_o = ckpt_ghr_q[branch_ckpt_id_i];
  assign squash_ghr_o = ckpt_ghr_q[squash_ckpt_id_i];
  assign squash_align_tail_o = ckpt_align_tail_q[squash_ckpt_id_i];
  assign squash_ras_top_o = ckpt_ras_top_q[squash_ckpt_id_i];
  assign predicted_ckpt_id_o = next_ckpt_id_q;

  always_comb begin
    next_ckpt_id_next = next_ckpt_id_q;
    if (fetch_accept_i && !squash_valid_i)
      next_ckpt_id_next = next_ckpt_id_q + bpu_ckpt_id_t'(1);
    if (squash_valid_i)
      next_ckpt_id_next = squash_ckpt_id_i + bpu_ckpt_id_t'(1);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      next_ckpt_id_q <= '0;
      for (seq_i = 0; seq_i < CKPT_ENTRIES; seq_i = seq_i + 1) begin
        ckpt_ghr_q[seq_i] <= 8'd0;
        ckpt_align_tail_q[seq_i] <= 8'd0;
        ckpt_ras_top_q[seq_i] <= 8'd0;
      end
    end else begin
      if (fetch_accept_i && !squash_valid_i) begin
        ckpt_ghr_q[next_ckpt_id_q] <= ghr_i;
        ckpt_align_tail_q[next_ckpt_id_q] <= align_tail_i;
        ckpt_ras_top_q[next_ckpt_id_q] <= ras_top_i;
      end
      next_ckpt_id_q <= next_ckpt_id_next;
    end
  end
endmodule
