module rv32_predictor #(
  parameter int unsigned BHT_ENTRIES = 256,
  parameter int unsigned BTB_ENTRIES = 64,
  parameter int unsigned RAS_ENTRIES = 8,
  parameter int unsigned CONDSEEN_ENTRIES = 512,
  parameter int unsigned CKPT_ENTRIES = rv32_pkg::BPU_CKPT_ENTRIES,
  parameter int unsigned ALIGNQ_ENTRIES = 16
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic [31:0]                  query_pc_i,
  output logic [31:0]                  predicted_next_pc_o,
  output logic                         predicted_taken_o,
  output rv32_pkg::bpu_ckpt_id_t       predicted_ckpt_id_o,

  // A checkpoint is allocated only when the frontend accepts this query.
  input  logic                         fetch_accept_i,

  // The frontend predecodes the prior accepted FQ push for speculative RAS
  // maintenance and early JAL/JALR BTB training.
  input  logic                         fetch_info_valid_i,
  input  logic                         fetch_info_call_i,
  input  logic                         fetch_info_return_i,
  input  logic                         fetch_info_jal_target_valid_i,
  input  logic [31:0]                  fetch_info_pc_i,
  input  logic [31:0]                  fetch_info_jal_target_i,

  // Conditional branch resolution port (BRU).
  input  logic                         branch_valid_i,
  input  rv32_pkg::rob_tag_t           branch_rob_tag_i,
  input  logic                         branch_rob_live_i,
  input  logic [31:0]                  branch_pc_i,
  input  logic [31:0]                  branch_next_pc_i,
  input  logic                         branch_taken_i,
  input  rv32_pkg::bpu_ckpt_id_t       branch_ckpt_id_i,

  // JAL/JALR resolution port (ALU CDB).
  input  logic                         jump_valid_i,
  input  rv32_pkg::rob_tag_t           jump_rob_tag_i,
  input  logic                         jump_rob_live_i,
  input  logic [31:0]                  jump_pc_i,
  input  logic [31:0]                  jump_target_i,
  input  logic                         jump_is_return_i,

  // The registered flush arbiter broadcasts the oldest accepted recovery.
  input  logic                         squash_valid_i,
  input  rv32_pkg::rob_tag_t           squash_tag_i,
  input  rv32_pkg::bpu_ckpt_id_t       squash_ckpt_id_i
);
  import rv32_pkg::*;

  logic dir_taken, dir_use_global, dir_condseen;
  logic [7:0] dir_ghr;
  logic [7:0] branch_ghr;

  logic btb_hit, btb_uncond, btb_ret;
  logic [31:0] btb_tgt;

  logic [7:0] ras_top, align_tail;
  logic [31:0] ras_ret_target;
  logic [7:0] ckpt_squash_ghr, ckpt_squash_align_tail, ckpt_squash_ras_top;

  logic branch_train, jump_train;

  logic query_btb_hit;
  logic query_dir_taken, query_is_ret, query_taken, query_shift, query_shift_value;
  logic [31:0] query_target;

  rv32_bpu_direction #(
    .BHT_ENTRIES(BHT_ENTRIES),
    .CONDSEEN_ENTRIES(CONDSEEN_ENTRIES)
  ) u_direction (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .query_pc_i(query_pc_i),
    .query_dir_taken_o(dir_taken),
    .query_use_global_o(dir_use_global),
    .query_condseen_o(dir_condseen),
    .branch_train_i(branch_train),
    .branch_pc_i(branch_pc_i),
    .branch_taken_i(branch_taken_i),
    .branch_ghr_i(branch_ghr),
    .fetch_accept_i(fetch_accept_i),
    .squash_valid_i(squash_valid_i),
    .query_shift_i(query_shift),
    .query_shift_value_i(query_shift_value),
    .squash_ghr_i(ckpt_squash_ghr),
    .ghr_o(dir_ghr)
  );

  rv32_bpu_btb #(
    .BTB_ENTRIES(BTB_ENTRIES)
  ) u_btb (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .query_pc_i(query_pc_i),
    .query_btb_hit_o(btb_hit),
    .query_btb_uncond_o(btb_uncond),
    .query_btb_ret_o(btb_ret),
    .query_btb_tgt_o(btb_tgt),
    .fetch_info_valid_i(fetch_info_valid_i),
    .fetch_info_return_i(fetch_info_return_i),
    .fetch_info_jal_target_valid_i(fetch_info_jal_target_valid_i),
    .fetch_info_pc_i(fetch_info_pc_i),
    .fetch_info_jal_target_i(fetch_info_jal_target_i),
    .branch_train_i(branch_train),
    .branch_taken_i(branch_taken_i),
    .branch_pc_i(branch_pc_i),
    .branch_next_pc_i(branch_next_pc_i),
    .jump_train_i(jump_train),
    .jump_pc_i(jump_pc_i),
    .jump_target_i(jump_target_i),
    .jump_is_return_i(jump_is_return_i)
  );

  rv32_bpu_ras #(
    .RAS_ENTRIES(RAS_ENTRIES),
    .ALIGNQ_ENTRIES(ALIGNQ_ENTRIES)
  ) u_ras (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .fetch_info_valid_i(fetch_info_valid_i),
    .fetch_info_call_i(fetch_info_call_i),
    .fetch_info_return_i(fetch_info_return_i),
    .fetch_info_pc_i(fetch_info_pc_i),
    .squash_valid_i(squash_valid_i),
    .squash_align_tail_i(ckpt_squash_align_tail),
    .squash_ras_top_i(ckpt_squash_ras_top),
    .ras_top_o(ras_top),
    .align_tail_o(align_tail),
    .query_ret_target_o(ras_ret_target)
  );

  rv32_bpu_checkpoint #(
    .CKPT_ENTRIES(CKPT_ENTRIES)
  ) u_checkpoint (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .fetch_accept_i(fetch_accept_i),
    .squash_valid_i(squash_valid_i),
    .squash_ckpt_id_i(squash_ckpt_id_i),
    .branch_ckpt_id_i(branch_ckpt_id_i),
    .ghr_i(dir_ghr),
    .align_tail_i(align_tail),
    .ras_top_i(ras_top),
    .branch_ghr_o(branch_ghr),
    .squash_ghr_o(ckpt_squash_ghr),
    .squash_align_tail_o(ckpt_squash_align_tail),
    .squash_ras_top_o(ckpt_squash_ras_top),
    .predicted_ckpt_id_o(predicted_ckpt_id_o)
  );

  // Unused direction confidence output is kept for observability only.
  logic unused_dir_use_global;
  assign unused_dir_use_global = dir_use_global;

  always_comb begin
    branch_train = branch_valid_i && branch_rob_live_i &&
                   (!squash_valid_i || rob_is_older(branch_rob_tag_i,
                                                    squash_tag_i));
    jump_train = jump_valid_i && jump_rob_live_i &&
                 (!squash_valid_i || rob_is_older(jump_rob_tag_i,
                                                  squash_tag_i));
  end

  always_comb begin
    query_dir_taken = dir_taken;
    query_btb_hit = btb_hit;
    query_taken = query_btb_hit && query_dir_taken;
    if (query_btb_hit && btb_uncond)
      query_taken = 1'b1;
    query_is_ret = btb_ret;
    if (query_is_ret && (ras_top == 8'd0)) begin
      query_btb_hit = 1'b0;
      query_taken = 1'b0;
    end
    query_target = btb_tgt;
    if (query_is_ret && (ras_top != 8'd0))
      query_target = ras_ret_target;
    query_shift = query_btb_hit || dir_condseen;
    query_shift_value = query_btb_hit ?
                        (btb_uncond ? 1'b1 : query_taken) :
                        (dir_condseen ? query_taken : 1'b0);
    predicted_taken_o = query_taken;
    predicted_next_pc_o = query_taken ? query_target : (query_pc_i + 32'd4);
  end
endmodule
