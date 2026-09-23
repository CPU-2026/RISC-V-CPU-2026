module rv32_flush_arbiter #(
  parameter int unsigned DEPTH = 4
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         branch_valid_i,
  input  rv32_pkg::rob_tag_t           branch_tag_i,
  input  logic [31:0]                  branch_pc_i,
  input  rv32_pkg::bpu_ckpt_id_t       branch_ckpt_id_i,

  input  logic                         jump_valid_i,
  input  rv32_pkg::rob_tag_t           jump_tag_i,
  input  logic [31:0]                  jump_pc_i,
  input  rv32_pkg::bpu_ckpt_id_t       jump_ckpt_id_i,

  output logic                         squash_valid_o,
  output rv32_pkg::rob_tag_t           squash_tag_o,
  output logic [31:0]                  squash_pc_o,
  output rv32_pkg::bpu_ckpt_id_t       squash_ckpt_id_o
);
  import rv32_pkg::*;

  logic valid_q [0:DEPTH-1];
  rob_tag_t tag_q [0:DEPTH-1];
  logic [31:0] pc_q [0:DEPTH-1];
  bpu_ckpt_id_t ckpt_id_q [0:DEPTH-1];

  logic valid_next [0:DEPTH-1];
  rob_tag_t tag_next [0:DEPTH-1];
  logic [31:0] pc_next [0:DEPTH-1];
  bpu_ckpt_id_t ckpt_id_next [0:DEPTH-1];

  integer select_i;
  integer comb_i, comb_j, count, write_index, insert_pos;
  integer seq_i;

  always @* begin
    squash_valid_o = 1'b0;
    squash_tag_o = '0;
    squash_pc_o = '0;
    squash_ckpt_id_o = '0;
    for (select_i = 0; select_i < DEPTH; select_i = select_i + 1) begin
      if (valid_q[select_i] && (!squash_valid_o ||
                         rob_is_older(tag_q[select_i], squash_tag_o))) begin
        squash_valid_o = 1'b1;
        squash_tag_o = tag_q[select_i];
        squash_pc_o = pc_q[select_i];
        squash_ckpt_id_o = ckpt_id_q[select_i];
      end
    end
  end

  always @* begin
    count = 0;
    write_index = 0;
    insert_pos = 0;
    for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1) begin
      valid_next[comb_i] = valid_q[comb_i];
      tag_next[comb_i] = tag_q[comb_i];
      pc_next[comb_i] = pc_q[comb_i];
      ckpt_id_next[comb_i] = ckpt_id_q[comb_i];
    end

    // A broadcast squash has won arbitration. Keep only strictly older queued
    // requests before accepting this cycle's independently detected events.
    if (squash_valid_o) begin
      for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1)
        if (valid_next[comb_i] && !rob_is_older(tag_next[comb_i], squash_tag_o))
          valid_next[comb_i] = 1'b0;
    end

    // Compact first so each insertion can use the same oldest-first layout.
    write_index = 0;
    for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1) begin
      if (valid_next[comb_i]) begin
        if (write_index != comb_i) begin
          valid_next[write_index] = 1'b1;
          tag_next[write_index] = tag_next[comb_i];
          pc_next[write_index] = pc_next[comb_i];
          ckpt_id_next[write_index] = ckpt_id_next[comb_i];
          valid_next[comb_i] = 1'b0;
        end
        write_index = write_index + 1;
      end
    end
    count = write_index;

    if (branch_valid_i &&
        (!squash_valid_o || rob_is_older(branch_tag_i, squash_tag_o)) &&
        (count < DEPTH)) begin
      insert_pos = 0;
      for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1)
        if ((comb_i < count) && rob_is_younger(branch_tag_i, tag_next[comb_i]))
          insert_pos = insert_pos + 1;
      for (comb_j = DEPTH-1; comb_j > 0; comb_j = comb_j - 1) begin
        if ((comb_j > insert_pos) && (comb_j <= count)) begin
          valid_next[comb_j] = valid_next[comb_j-1];
          tag_next[comb_j] = tag_next[comb_j-1];
          pc_next[comb_j] = pc_next[comb_j-1];
          ckpt_id_next[comb_j] = ckpt_id_next[comb_j-1];
        end
      end
      valid_next[insert_pos] = 1'b1;
      tag_next[insert_pos] = branch_tag_i;
      pc_next[insert_pos] = branch_pc_i;
      ckpt_id_next[insert_pos] = branch_ckpt_id_i;
      count = count + 1;
    end

    if (jump_valid_i &&
        (!squash_valid_o || rob_is_older(jump_tag_i, squash_tag_o)) &&
        (count < DEPTH)) begin
      insert_pos = 0;
      for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1)
        if ((comb_i < count) && rob_is_younger(jump_tag_i, tag_next[comb_i]))
          insert_pos = insert_pos + 1;
      for (comb_j = DEPTH-1; comb_j > 0; comb_j = comb_j - 1) begin
        if ((comb_j > insert_pos) && (comb_j <= count)) begin
          valid_next[comb_j] = valid_next[comb_j-1];
          tag_next[comb_j] = tag_next[comb_j-1];
          pc_next[comb_j] = pc_next[comb_j-1];
          ckpt_id_next[comb_j] = ckpt_id_next[comb_j-1];
        end
      end
      valid_next[insert_pos] = 1'b1;
      tag_next[insert_pos] = jump_tag_i;
      pc_next[insert_pos] = jump_pc_i;
      ckpt_id_next[insert_pos] = jump_ckpt_id_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (seq_i = 0; seq_i < DEPTH; seq_i = seq_i + 1) begin
        valid_q[seq_i] <= 1'b0;
        tag_q[seq_i] <= '0;
        pc_q[seq_i] <= '0;
        ckpt_id_q[seq_i] <= '0;
      end
    end else begin
      for (seq_i = 0; seq_i < DEPTH; seq_i = seq_i + 1) begin
        valid_q[seq_i] <= valid_next[seq_i];
        tag_q[seq_i] <= tag_next[seq_i];
        pc_q[seq_i] <= pc_next[seq_i];
        ckpt_id_q[seq_i] <= ckpt_id_next[seq_i];
      end
    end
  end
endmodule
