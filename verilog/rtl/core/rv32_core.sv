module rv32_core #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter bit DIV_USE_SRT4 = 1'b0
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  output logic             imem_req_valid_o,
  input  logic             imem_req_ready_i,
  output logic [31:0]      imem_req_addr_o,
  input  logic             imem_rsp_valid_i,
  input  logic [31:0]      imem_rsp_data_i,

  output logic             dmem_req_valid_o,
  input  logic             dmem_req_ready_i,
  output logic             dmem_req_write_o,
  output logic [31:0]      dmem_req_addr_o,
  output logic [31:0]      dmem_req_wdata_o,
  output logic [3:0]       dmem_req_wstrb_o,
  output logic [1:0]       dmem_req_size_o,
  input  logic             dmem_rsp_valid_i,
  input  logic [31:0]      dmem_rsp_rdata_i,

  output logic             commit_valid_o,
  output logic [31:0]      commit_pc_o,
  output logic [31:0]      commit_instr_o,
  output logic             commit_rd_valid_o,
  output logic [4:0]       commit_rd_o,
  output logic [31:0]      commit_rd_value_o,
  output logic             commit_mem_valid_o,
  output logic [31:0]      commit_mem_addr_o,
  output logic [31:0]      commit_mem_data_o,
  output logic [3:0]       commit_mem_wstrb_o,

  output logic             halted_o,
  output logic             trap_o
);
  import rv32_pkg::*;

  logic [31:0] predictor_pc, predicted_next_pc;
  logic predicted_taken;
  bpu_ckpt_id_t predicted_ckpt_id, iq_predictor_ckpt_id;
  logic predictor_fetch_accept;
  logic fetch_info_valid, fetch_info_call, fetch_info_return;
  logic fetch_info_jal_target_valid;
  logic [31:0] fetch_info_pc, fetch_info_jal_target;
  logic frontend_iq_valid, frontend_iq_ready;
  logic [31:0] iq_pc, iq_instr, iq_predicted_pc;
  logic [2:0] fq_count, iq_count;
  decoded_uop_t decoded;

  phy_tag_t rat_rs1_phy, rat_rs2_phy, rat_old_phy, rat_debug_phy;
  phy_tag_t prf_alloc_phy;
  logic prf_alloc_ready;
  logic prf_src1_ready, prf_src2_ready, prf_commit_ready;
  logic [31:0] prf_src1_value, prf_src2_value, prf_commit_value;
  logic [PRF_ENTRIES-1:0] prf_ready_vector;
  logic [5:0] prf_free_count;

  rob_tag_t rob_alloc_tag, rob_head_tag;
  wire rob_tag_t rob_replay_tag [0:ROB_ENTRIES-1];
  wire [4:0] rob_replay_arch_rd [0:ROB_ENTRIES-1];
  wire phy_tag_t rob_replay_new_phy [0:ROB_ENTRIES-1];
  logic rob_alloc_ready;
  logic rob_commit_valid, rob_commit_ready, rob_commit_fire;
  rob_tag_t rob_commit_tag;
  logic [31:0] rob_commit_pc, rob_commit_instr;
  logic rob_commit_writes;
  logic [4:0] rob_commit_rd;
  phy_tag_t rob_commit_new_phy, rob_commit_old_phy;
  logic rob_commit_store;
  logic [2:0] rob_commit_sq_index;
  logic rob_commit_halt, rob_commit_exception;
  logic rob_empty, rob_full;
  logic [4:0] rob_count;

  logic issue_fire, issue_resources_ready;
  logic target_rs_ready;
  logic issue_is_jump, issue_is_call, issue_is_return;
  logic issue_src1_ready, issue_src2_ready;
  logic [31:0] issue_src1_value, issue_src2_value;
  phy_tag_t issue_dest_phy;

  logic global_flush;
  rob_tag_t global_flush_tag;
  logic [31:0] global_redirect_pc;
  bpu_ckpt_id_t global_flush_ckpt_id;
  logic branch_flush_candidate, jump_flush_candidate;
  logic [31:0] branch_flush_pc, jump_flush_pc;
  logic predictor_update_valid, predictor_mispredict;

  logic wb_alu_valid, wb_load_valid, wb_mul_valid, wb_div_valid;
  logic load_cdb_valid, mul_cdb_valid, div_cdb_valid;
  logic alu_rob_live, load_rob_live, mul_rob_live, div_rob_live;
  logic alu_result_live, branch_result_live;
  rob_tag_t wb_alu_tag, wb_load_tag, wb_mul_tag, wb_div_tag;
  phy_tag_t wb_alu_phy, wb_load_phy, wb_mul_phy, wb_div_phy;
  logic [31:0] wb_alu_value, wb_load_value, wb_mul_value, wb_div_value;
  logic alu_cdb_valid, alu_cdb_is_control, alu_cdb_misaligned;

  logic int_alloc_ready, int_issue_valid, int_issue_ready;
  operation_e int_issue_op;
  rob_tag_t int_issue_tag;
  phy_tag_t int_issue_phy;
  logic [31:0] int_issue_s1, int_issue_s2, int_issue_imm;
  logic [31:0] int_issue_pc, int_issue_pred;
  logic int_issue_use_imm;
  logic [0:0] int_issue_aux;
  logic [2:0] int_occupancy;

  logic mul_alloc_ready, mul_issue_valid, mul_issue_ready;
  operation_e mul_issue_op;
  rob_tag_t mul_issue_tag;
  phy_tag_t mul_issue_phy;
  logic [31:0] mul_issue_s1, mul_issue_s2, mul_issue_imm;
  logic [31:0] mul_issue_pc, mul_issue_pred;
  logic mul_issue_use_imm;
  logic [0:0] mul_issue_aux;
  logic [1:0] mul_occupancy;

  logic div_alloc_ready, div_issue_valid, div_issue_ready;
  operation_e div_issue_op;
  rob_tag_t div_issue_tag;
  phy_tag_t div_issue_phy;
  logic [31:0] div_issue_s1, div_issue_s2, div_issue_imm;
  logic [31:0] div_issue_pc, div_issue_pred;
  logic div_issue_use_imm;
  logic [0:0] div_issue_aux;
  logic [0:0] div_occupancy;

  logic branch_alloc_ready, branch_issue_valid, branch_issue_ready;
  operation_e branch_issue_op;
  rob_tag_t branch_issue_tag;
  phy_tag_t branch_issue_phy;
  logic [31:0] branch_issue_s1, branch_issue_s2, branch_issue_imm;
  logic [31:0] branch_issue_pc, branch_issue_pred;
  logic branch_issue_use_imm;
  logic [2:0] branch_issue_aux;
  logic [2:0] branch_occupancy;

  logic mem_alloc_ready, mem_issue_valid, mem_issue_ready;
  operation_e mem_issue_op;
  rob_tag_t mem_issue_tag;
  phy_tag_t mem_issue_phy;
  logic [31:0] mem_issue_s1, mem_issue_s2, mem_issue_imm;
  logic [31:0] mem_issue_pc, mem_issue_pred;
  logic mem_issue_use_imm;
  logic [3:0] mem_issue_aux;
  logic [2:0] mem_occupancy;
  logic [31:0] mem_address;

  logic bru_valid, bru_taken, bru_conditional, bru_mispredict;
  logic bru_misaligned, bru_call, bru_return;
  rob_tag_t bru_tag;
  logic [31:0] bru_pc, bru_target, bru_next_pc, bru_return_address;

  logic bru_rob_live, jump_rob_live;
  logic [31:0] bru_rob_pc, bru_rob_predicted_pc;
  logic [31:0] jump_rob_pc, jump_rob_predicted_pc;
  bpu_ckpt_id_t bru_rob_ckpt_id, jump_rob_ckpt_id;
  logic bru_rob_is_ret, jump_rob_is_ret;

  logic lq_alloc_ready, sq_alloc_ready;
  logic [2:0] lq_alloc_index, sq_alloc_index;
  logic store_complete_valid;
  rob_tag_t store_complete_tag;
  logic lsu_store_commit_ready;
  mem_size_e lsu_dmem_size;
  logic [3:0] lq_count, sq_count;

  logic halted_q, trap_q;
  logic [31:0] issue_link_value;
  logic unused_cout_link;

  assign alu_rob_live = jump_rob_live;
  assign alu_result_live = alu_cdb_valid && alu_rob_live &&
                           (!global_flush ||
                            rob_is_older(wb_alu_tag, global_flush_tag));
  assign wb_alu_valid = alu_result_live && !alu_cdb_is_control;
  assign wb_load_valid = load_cdb_valid && load_rob_live &&
                         (!global_flush ||
                          rob_is_older(wb_load_tag, global_flush_tag));
  assign wb_mul_valid = mul_cdb_valid && mul_rob_live &&
                        (!global_flush ||
                         rob_is_older(wb_mul_tag, global_flush_tag));
  assign wb_div_valid = div_cdb_valid && div_rob_live &&
                        (!global_flush ||
                         rob_is_older(wb_div_tag, global_flush_tag));
  assign branch_result_live = bru_valid && bru_conditional && bru_rob_live &&
                              (!global_flush ||
                               rob_is_older(bru_tag, global_flush_tag));
  assign branch_flush_candidate = branch_result_live &&
                                  (bru_mispredict || bru_misaligned);
  assign branch_flush_pc = bru_misaligned ? (bru_next_pc & 32'hffff_fffc) :
                           bru_next_pc;
  assign jump_flush_candidate = alu_result_live && alu_cdb_is_control &&
                                 ((wb_alu_value != jump_rob_predicted_pc) ||
                                  alu_cdb_misaligned);
  assign jump_flush_pc = alu_cdb_misaligned ? (wb_alu_value & 32'hffff_fffc) :
                          wb_alu_value;
  assign predictor_update_valid = branch_result_live ||
                                  (alu_result_live && alu_cdb_is_control);
  assign predictor_mispredict = branch_flush_candidate || jump_flush_candidate;

  rv32_flush_arbiter u_flush_arbiter (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .branch_valid_i(branch_flush_candidate), .branch_tag_i(bru_tag),
    .branch_pc_i(branch_flush_pc), .branch_ckpt_id_i(bru_rob_ckpt_id),
    .jump_valid_i(jump_flush_candidate), .jump_tag_i(wb_alu_tag),
    .jump_pc_i(jump_flush_pc), .jump_ckpt_id_i(jump_rob_ckpt_id),
    .squash_valid_o(global_flush), .squash_tag_o(global_flush_tag),
    .squash_pc_o(global_redirect_pc), .squash_ckpt_id_o(global_flush_ckpt_id)
  );

  rv32_frontend #(.RESET_PC(RESET_PC)) u_frontend (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .predictor_pc_o(predictor_pc),
    .predicted_next_pc_i(predicted_next_pc),
    .predicted_ckpt_id_i(predicted_ckpt_id),
    .predictor_accept_o(predictor_fetch_accept),
    .imem_req_valid_o(imem_req_valid_o),
    .imem_req_ready_i(imem_req_ready_i),
    .imem_req_addr_o(imem_req_addr_o),
    .imem_rsp_valid_i(imem_rsp_valid_i),
    .imem_rsp_data_i(imem_rsp_data_i),
    .redirect_valid_i(global_flush), .redirect_pc_i(global_redirect_pc),
    .iq_valid_o(frontend_iq_valid), .iq_ready_i(frontend_iq_ready),
    .iq_pc_o(iq_pc), .iq_instr_o(iq_instr),
    .iq_predicted_pc_o(iq_predicted_pc),
    .iq_ckpt_id_o(iq_predictor_ckpt_id),
    .fetch_info_valid_o(fetch_info_valid),
    .fetch_info_call_o(fetch_info_call),
    .fetch_info_return_o(fetch_info_return),
    .fetch_info_jal_target_valid_o(fetch_info_jal_target_valid),
    .fetch_info_pc_o(fetch_info_pc),
    .fetch_info_jal_target_o(fetch_info_jal_target),
    .fq_count_o(fq_count), .iq_count_o(iq_count)
  );

  rv32_predictor u_predictor (
    .clk_i(clk_i), .rst_ni(rst_ni), .query_pc_i(predictor_pc),
    .predicted_next_pc_o(predicted_next_pc),
    .predicted_taken_o(predicted_taken),
    .predicted_ckpt_id_o(predicted_ckpt_id),
    .fetch_accept_i(predictor_fetch_accept),
    .fetch_info_valid_i(fetch_info_valid),
    .fetch_info_call_i(fetch_info_call), .fetch_info_return_i(fetch_info_return),
    .fetch_info_jal_target_valid_i(fetch_info_jal_target_valid),
    .fetch_info_pc_i(fetch_info_pc), .fetch_info_jal_target_i(fetch_info_jal_target),
    .branch_valid_i(branch_result_live), .branch_rob_tag_i(bru_tag),
    .branch_rob_live_i(bru_rob_live), .branch_pc_i(bru_pc),
    .branch_next_pc_i(bru_next_pc), .branch_taken_i(bru_taken),
    .branch_ckpt_id_i(bru_rob_ckpt_id),
    .jump_valid_i(alu_result_live && alu_cdb_is_control),
    .jump_rob_tag_i(wb_alu_tag), .jump_rob_live_i(jump_rob_live),
    .jump_pc_i(jump_rob_pc), .jump_target_i(wb_alu_value),
    .jump_is_return_i(jump_rob_is_ret),
    .squash_valid_i(global_flush), .squash_tag_i(global_flush_tag),
    .squash_ckpt_id_i(global_flush_ckpt_id)
  );

  rv32_decoder u_decoder (
    .instr_i(iq_instr), .pc_i(iq_pc),
    .predicted_next_pc_i(iq_predicted_pc),
    .predictor_ckpt_id_i(iq_predictor_ckpt_id), .uop_o(decoded)
  );

  rv32_add #(.WIDTH(32)) u_link_add (
    .a_i(decoded.pc), .b_i(32'd4), .cin_i(1'b0),
    .sum_o(issue_link_value), .cout_o(unused_cout_link)
  );

  rv32_rat u_rat (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .rs1_arch_i(decoded.rs1), .rs2_arch_i(decoded.rs2),
    .rs1_phy_o(rat_rs1_phy), .rs2_phy_o(rat_rs2_phy),
    .rename_valid_i(issue_fire && decoded.writes_rd),
    .rename_arch_i(decoded.rd), .rename_phy_i(prf_alloc_phy),
    .rename_old_phy_o(rat_old_phy),
    .restore_valid_i(global_flush),
    .restore_tag_i(global_flush_tag), .restore_head_tag_i(rob_head_tag),
    .replay_tag_i(rob_replay_tag),
    .replay_arch_rd_i(rob_replay_arch_rd),
    .replay_new_phy_i(rob_replay_new_phy),
    .commit_valid_i(rob_commit_fire && rob_commit_writes),
    .commit_arch_i(rob_commit_rd), .commit_phy_i(rob_commit_new_phy),
    .debug_arch_i(5'd0), .debug_phy_o(rat_debug_phy)
  );

  rv32_prf u_prf (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .alloc_valid_i(issue_fire && decoded.writes_rd),
    .alloc_ready_o(prf_alloc_ready), .alloc_phy_o(prf_alloc_phy),
    .alloc_value_valid_i(issue_fire && decoded.writes_rd && issue_is_jump),
    .alloc_value_i(issue_link_value),
    .free_valid_i(rob_commit_fire && rob_commit_writes),
    .free_phy_i(rob_commit_old_phy),
    .restore_valid_i(global_flush),
    .restore_tag_i(global_flush_tag),
    .restore_count_i(rob_count),
    .replay_tag_i(rob_replay_tag),
    .replay_new_phy_i(rob_replay_new_phy),
    .read1_phy_i(rat_rs1_phy), .read1_ready_o(prf_src1_ready),
    .read1_value_o(prf_src1_value),
    .read2_phy_i(rat_rs2_phy), .read2_ready_o(prf_src2_ready),
    .read2_value_o(prf_src2_value),
    .read3_phy_i(rob_commit_new_phy), .read3_ready_o(prf_commit_ready),
    .read3_value_o(prf_commit_value),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy),
    .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy),
    .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy),
    .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy),
    .wb3_value_i(wb_div_value),
    .ready_vector_o(prf_ready_vector), .free_count_o(prf_free_count)
  );

  rv32_rob u_rob (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .alloc_valid_i(issue_fire), .alloc_ready_o(rob_alloc_ready),
    .alloc_tag_o(rob_alloc_tag), .alloc_pc_i(decoded.pc),
    .alloc_instr_i(decoded.instr),
    .alloc_writes_rd_i(decoded.writes_rd),
    .alloc_arch_rd_i(decoded.rd), .alloc_new_phy_i(issue_dest_phy),
    .alloc_old_phy_i(rat_old_phy),
    .alloc_ready_i(decoded.halt || decoded.illegal),
    .alloc_store_i(decoded.uop_class == rv32_pkg::UOP_STORE),
    .alloc_sq_index_i(sq_alloc_index), .alloc_halt_i(decoded.halt),
    .alloc_exception_i(decoded.illegal),
    .alloc_predicted_pc_i(decoded.predicted_next_pc),
    .alloc_predictor_ckpt_id_i(decoded.predictor_ckpt_id),
    .alloc_is_ret_i(issue_is_return),
    .complete0_valid_i(alu_result_live), .complete0_tag_i(wb_alu_tag),
    .complete0_exception_i(alu_cdb_misaligned),
    .complete1_valid_i(wb_load_valid), .complete1_tag_i(wb_load_tag),
    .complete2_valid_i(wb_mul_valid), .complete2_tag_i(wb_mul_tag),
    .complete3_valid_i(wb_div_valid), .complete3_tag_i(wb_div_tag),
    .complete4_valid_i(branch_result_live), .complete4_tag_i(bru_tag),
    .complete4_exception_i(bru_misaligned),
    .complete5_valid_i(store_complete_valid),
    .complete5_tag_i(store_complete_tag),
    .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .lookup0_tag_i(bru_tag), .lookup0_valid_o(bru_rob_live),
    .lookup0_pc_o(bru_rob_pc), .lookup0_predicted_pc_o(bru_rob_predicted_pc),
    .lookup0_predictor_ckpt_id_o(bru_rob_ckpt_id),
    .lookup0_is_ret_o(bru_rob_is_ret),
    .lookup1_tag_i(wb_alu_tag), .lookup1_valid_o(jump_rob_live),
    .lookup1_pc_o(jump_rob_pc), .lookup1_predicted_pc_o(jump_rob_predicted_pc),
    .lookup1_predictor_ckpt_id_o(jump_rob_ckpt_id),
    .lookup1_is_ret_o(jump_rob_is_ret),
    .lookup2_tag_i(wb_load_tag), .lookup2_valid_o(load_rob_live),
    .lookup3_tag_i(wb_mul_tag), .lookup3_valid_o(mul_rob_live),
    .lookup4_tag_i(wb_div_tag), .lookup4_valid_o(div_rob_live),
    .commit_valid_o(rob_commit_valid), .commit_ready_i(rob_commit_ready),
    .commit_fire_o(rob_commit_fire), .commit_tag_o(rob_commit_tag),
    .commit_pc_o(rob_commit_pc), .commit_instr_o(rob_commit_instr),
    .commit_writes_rd_o(rob_commit_writes),
    .commit_arch_rd_o(rob_commit_rd),
    .commit_new_phy_o(rob_commit_new_phy),
    .commit_old_phy_o(rob_commit_old_phy),
    .commit_store_o(rob_commit_store),
    .commit_sq_index_o(rob_commit_sq_index),
    .commit_halt_o(rob_commit_halt),
    .commit_exception_o(rob_commit_exception),
    .empty_o(rob_empty), .full_o(rob_full), .count_o(rob_count),
    .head_tag_o(rob_head_tag),
    .replay_tag_o(rob_replay_tag),
    .replay_arch_rd_o(rob_replay_arch_rd),
    .replay_new_phy_o(rob_replay_new_phy)
  );

  always_comb begin
    issue_is_jump = (decoded.op == OP_JAL) || (decoded.op == OP_JALR);
    issue_is_call = issue_is_jump &&
                     ((decoded.rd == 5'd1) || (decoded.rd == 5'd5));
    issue_is_return = (decoded.op == OP_JALR) &&
                       ((decoded.rs1 == 5'd1) || (decoded.rs1 == 5'd5)) &&
                       (decoded.rd != 5'd1) && (decoded.rd != 5'd5);
    issue_dest_phy = decoded.writes_rd ? prf_alloc_phy : '0;
    issue_src1_ready = !decoded.uses_rs1 || prf_src1_ready;
    issue_src1_value = decoded.uses_rs1 ? prf_src1_value : 32'b0;
    issue_src2_ready = !decoded.uses_rs2 || prf_src2_ready;
    issue_src2_value = decoded.uses_rs2 ? prf_src2_value : 32'b0;

    target_rs_ready = 1'b1;
    unique case (decoded.uop_class)
      rv32_pkg::UOP_ALU:    target_rs_ready = int_alloc_ready;
      rv32_pkg::UOP_MUL:    target_rs_ready = mul_alloc_ready;
      rv32_pkg::UOP_DIV:    target_rs_ready = div_alloc_ready;
      rv32_pkg::UOP_BRANCH: target_rs_ready = branch_alloc_ready;
      rv32_pkg::UOP_LOAD:   target_rs_ready = mem_alloc_ready && lq_alloc_ready;
      rv32_pkg::UOP_STORE:  target_rs_ready = mem_alloc_ready && sq_alloc_ready;
      default:    target_rs_ready = 1'b1;
    endcase
    issue_resources_ready = rob_alloc_ready && target_rs_ready &&
                            (!decoded.writes_rd || prf_alloc_ready);
    issue_fire = frontend_iq_valid && issue_resources_ready &&
                 !global_flush && !halted_q && !trap_q;
    frontend_iq_ready = issue_fire;

    rob_commit_ready = rob_commit_store ? lsu_store_commit_ready : 1'b1;
    commit_valid_o = rob_commit_fire;
    commit_pc_o = rob_commit_pc;
    commit_instr_o = rob_commit_instr;
    commit_rd_valid_o = rob_commit_fire && rob_commit_writes &&
                        (rob_commit_rd != 5'd0) && !rob_commit_exception;
    commit_rd_o = rob_commit_rd;
    commit_rd_value_o = prf_commit_value;
    commit_mem_valid_o = rob_commit_fire && rob_commit_store;
    commit_mem_addr_o = dmem_req_addr_o;
    commit_mem_data_o = dmem_req_wdata_o;
    commit_mem_wstrb_o = dmem_req_wstrb_o;
    halted_o = halted_q;
    trap_o = trap_q;
    dmem_req_size_o = lsu_dmem_size;
  end

  rv32_rs #(.DEPTH(4), .AUX_W(1)) u_int_rs (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush),
    .flush_tag_i(global_flush_tag),
    .alloc_valid_i(issue_fire && (decoded.uop_class == rv32_pkg::UOP_ALU)),
    .alloc_ready_o(int_alloc_ready), .alloc_op_i(decoded.op),
    .alloc_rob_tag_i(rob_alloc_tag), .alloc_dest_phy_i(issue_dest_phy),
    .alloc_src1_ready_i(issue_src1_ready), .alloc_src1_tag_i(rat_rs1_phy),
    .alloc_src1_value_i(issue_src1_value),
    .alloc_src2_ready_i(issue_src2_ready), .alloc_src2_tag_i(rat_rs2_phy),
    .alloc_src2_value_i(issue_src2_value),
    .alloc_imm_i(decoded.imm), .alloc_pc_i(decoded.pc),
    .alloc_predicted_pc_i(decoded.predicted_next_pc),
    .alloc_use_imm_i(decoded.uses_imm), .alloc_aux_i(issue_is_jump),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy), .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy), .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy), .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy), .wb3_value_i(wb_div_value),
    .issue_valid_o(int_issue_valid), .issue_ready_i(int_issue_ready),
    .issue_op_o(int_issue_op), .issue_rob_tag_o(int_issue_tag),
    .issue_dest_phy_o(int_issue_phy), .issue_src1_value_o(int_issue_s1),
    .issue_src2_value_o(int_issue_s2), .issue_imm_o(int_issue_imm),
    .issue_pc_o(int_issue_pc), .issue_predicted_pc_o(int_issue_pred),
    .issue_use_imm_o(int_issue_use_imm), .issue_aux_o(int_issue_aux),
    .occupancy_o(int_occupancy)
  );

  rv32_rs #(.DEPTH(2), .AUX_W(1)) u_mul_rs (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .alloc_valid_i(issue_fire && (decoded.uop_class == rv32_pkg::UOP_MUL)), .alloc_ready_o(mul_alloc_ready),
    .alloc_op_i(decoded.op), .alloc_rob_tag_i(rob_alloc_tag), .alloc_dest_phy_i(issue_dest_phy),
    .alloc_src1_ready_i(issue_src1_ready), .alloc_src1_tag_i(rat_rs1_phy), .alloc_src1_value_i(issue_src1_value),
    .alloc_src2_ready_i(issue_src2_ready), .alloc_src2_tag_i(rat_rs2_phy), .alloc_src2_value_i(issue_src2_value),
    .alloc_imm_i(decoded.imm), .alloc_pc_i(decoded.pc), .alloc_predicted_pc_i(decoded.predicted_next_pc),
    .alloc_use_imm_i(1'b0), .alloc_aux_i(1'b0),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy), .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy), .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy), .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy), .wb3_value_i(wb_div_value),
    .issue_valid_o(mul_issue_valid), .issue_ready_i(mul_issue_ready), .issue_op_o(mul_issue_op),
    .issue_rob_tag_o(mul_issue_tag), .issue_dest_phy_o(mul_issue_phy),
    .issue_src1_value_o(mul_issue_s1), .issue_src2_value_o(mul_issue_s2),
    .issue_imm_o(mul_issue_imm), .issue_pc_o(mul_issue_pc), .issue_predicted_pc_o(mul_issue_pred),
    .issue_use_imm_o(mul_issue_use_imm), .issue_aux_o(mul_issue_aux), .occupancy_o(mul_occupancy)
  );

  rv32_rs #(.DEPTH(1), .AUX_W(1)) u_div_rs (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .alloc_valid_i(issue_fire && (decoded.uop_class == rv32_pkg::UOP_DIV)), .alloc_ready_o(div_alloc_ready),
    .alloc_op_i(decoded.op), .alloc_rob_tag_i(rob_alloc_tag), .alloc_dest_phy_i(issue_dest_phy),
    .alloc_src1_ready_i(issue_src1_ready), .alloc_src1_tag_i(rat_rs1_phy), .alloc_src1_value_i(issue_src1_value),
    .alloc_src2_ready_i(issue_src2_ready), .alloc_src2_tag_i(rat_rs2_phy), .alloc_src2_value_i(issue_src2_value),
    .alloc_imm_i(decoded.imm), .alloc_pc_i(decoded.pc), .alloc_predicted_pc_i(decoded.predicted_next_pc),
    .alloc_use_imm_i(1'b0), .alloc_aux_i(1'b0),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy), .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy), .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy), .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy), .wb3_value_i(wb_div_value),
    .issue_valid_o(div_issue_valid), .issue_ready_i(div_issue_ready), .issue_op_o(div_issue_op),
    .issue_rob_tag_o(div_issue_tag), .issue_dest_phy_o(div_issue_phy),
    .issue_src1_value_o(div_issue_s1), .issue_src2_value_o(div_issue_s2),
    .issue_imm_o(div_issue_imm), .issue_pc_o(div_issue_pc), .issue_predicted_pc_o(div_issue_pred),
    .issue_use_imm_o(div_issue_use_imm), .issue_aux_o(div_issue_aux), .occupancy_o(div_occupancy)
  );

  rv32_rs #(.DEPTH(4), .AUX_W(3)) u_branch_rs (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .alloc_valid_i(issue_fire && (decoded.uop_class == rv32_pkg::UOP_BRANCH)), .alloc_ready_o(branch_alloc_ready),
    .alloc_op_i(decoded.op), .alloc_rob_tag_i(rob_alloc_tag), .alloc_dest_phy_i(issue_dest_phy),
    .alloc_src1_ready_i(issue_src1_ready), .alloc_src1_tag_i(rat_rs1_phy), .alloc_src1_value_i(issue_src1_value),
    .alloc_src2_ready_i(issue_src2_ready), .alloc_src2_tag_i(rat_rs2_phy), .alloc_src2_value_i(issue_src2_value),
    .alloc_imm_i(decoded.imm), .alloc_pc_i(decoded.pc), .alloc_predicted_pc_i(decoded.predicted_next_pc),
    .alloc_use_imm_i(decoded.uses_imm), .alloc_aux_i({1'b0, issue_is_return, issue_is_call}),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy), .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy), .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy), .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy), .wb3_value_i(wb_div_value),
    .issue_valid_o(branch_issue_valid), .issue_ready_i(branch_issue_ready), .issue_op_o(branch_issue_op),
    .issue_rob_tag_o(branch_issue_tag), .issue_dest_phy_o(branch_issue_phy),
    .issue_src1_value_o(branch_issue_s1), .issue_src2_value_o(branch_issue_s2),
    .issue_imm_o(branch_issue_imm), .issue_pc_o(branch_issue_pc), .issue_predicted_pc_o(branch_issue_pred),
    .issue_use_imm_o(branch_issue_use_imm), .issue_aux_o(branch_issue_aux), .occupancy_o(branch_occupancy)
  );

  rv32_rs #(.DEPTH(4), .AUX_W(4)) u_mem_rs (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .alloc_valid_i(issue_fire && ((decoded.uop_class == rv32_pkg::UOP_LOAD) ||
                                  (decoded.uop_class == rv32_pkg::UOP_STORE))),
    .alloc_ready_o(mem_alloc_ready), .alloc_op_i(decoded.op), .alloc_rob_tag_i(rob_alloc_tag),
    .alloc_dest_phy_i(issue_dest_phy), .alloc_src1_ready_i(issue_src1_ready),
    .alloc_src1_tag_i(rat_rs1_phy), .alloc_src1_value_i(issue_src1_value),
    .alloc_src2_ready_i(1'b1), .alloc_src2_tag_i('0), .alloc_src2_value_i('0),
    .alloc_imm_i(decoded.imm), .alloc_pc_i(decoded.pc), .alloc_predicted_pc_i(decoded.predicted_next_pc),
    .alloc_use_imm_i(1'b1),
    .alloc_aux_i({decoded.uop_class == rv32_pkg::UOP_STORE,
                  (decoded.uop_class == rv32_pkg::UOP_STORE) ?
                    sq_alloc_index : lq_alloc_index}),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy), .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy), .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy), .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy), .wb3_value_i(wb_div_value),
    .issue_valid_o(mem_issue_valid), .issue_ready_i(mem_issue_ready), .issue_op_o(mem_issue_op),
    .issue_rob_tag_o(mem_issue_tag), .issue_dest_phy_o(mem_issue_phy),
    .issue_src1_value_o(mem_issue_s1), .issue_src2_value_o(mem_issue_s2),
    .issue_imm_o(mem_issue_imm), .issue_pc_o(mem_issue_pc), .issue_predicted_pc_o(mem_issue_pred),
    .issue_use_imm_o(mem_issue_use_imm), .issue_aux_o(mem_issue_aux), .occupancy_o(mem_occupancy)
  );

  rv32_alu_unit u_alu_unit (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .in_valid_i(int_issue_valid), .in_ready_o(int_issue_ready), .op_i(int_issue_op),
    .lhs_i(int_issue_s1), .rhs_i(int_issue_s2), .imm_i(int_issue_imm), .pc_i(int_issue_pc),
    .use_imm_i(int_issue_use_imm), .rob_tag_i(int_issue_tag), .dest_phy_i(int_issue_phy),
    .is_control_i(int_issue_aux[0]),
    .out_valid_o(alu_cdb_valid), .out_ready_i(1'b1), .result_o(wb_alu_value),
    .rob_tag_o(wb_alu_tag), .dest_phy_o(wb_alu_phy),
    .is_control_o(alu_cdb_is_control),
    .control_misaligned_o(alu_cdb_misaligned)
  );

  rv32_mul u_mul_unit (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .in_valid_i(mul_issue_valid), .in_ready_o(mul_issue_ready), .op_i(mul_issue_op),
    .lhs_i(mul_issue_s1), .rhs_i(mul_issue_s2), .rob_tag_i(mul_issue_tag), .dest_phy_i(mul_issue_phy),
    .out_valid_o(mul_cdb_valid), .out_ready_i(1'b1), .result_o(wb_mul_value),
    .rob_tag_o(wb_mul_tag), .dest_phy_o(wb_mul_phy)
  );

  // Use literal child parameters so sv2v/Yosys can elaborate either whole-core
  // variant without a dynamic defparam on the divider wrapper.
  generate
    if (DIV_USE_SRT4) begin : g_div_srt4
      rv32_div_srt4 u_div_unit (
        .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
        .in_valid_i(div_issue_valid), .in_ready_o(div_issue_ready), .op_i(div_issue_op),
        .dividend_i(div_issue_s1), .divisor_i(div_issue_s2), .rob_tag_i(div_issue_tag),
        .dest_phy_i(div_issue_phy), .out_valid_o(div_cdb_valid), .out_ready_i(1'b1),
        .result_o(wb_div_value), .rob_tag_o(wb_div_tag), .dest_phy_o(wb_div_phy)
      );
    end else begin : g_div_radix2
      rv32_div_radix2 u_div_unit (
        .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
        .in_valid_i(div_issue_valid), .in_ready_o(div_issue_ready), .op_i(div_issue_op),
        .dividend_i(div_issue_s1), .divisor_i(div_issue_s2), .rob_tag_i(div_issue_tag),
        .dest_phy_i(div_issue_phy), .out_valid_o(div_cdb_valid), .out_ready_i(1'b1),
        .result_o(wb_div_value), .rob_tag_o(wb_div_tag), .dest_phy_o(wb_div_phy)
      );
    end
  endgenerate

  rv32_bru_unit u_bru_unit (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush),
    .in_valid_i(branch_issue_valid), .in_ready_o(branch_issue_ready), .op_i(branch_issue_op),
    .src1_i(branch_issue_s1), .src2_i(branch_issue_s2), .pc_i(branch_issue_pc),
    .imm_i(branch_issue_imm), .predicted_next_pc_i(branch_issue_pred),
    .rob_tag_i(branch_issue_tag), .is_call_i(branch_issue_aux[0]),
    .is_return_i(branch_issue_aux[1]), .out_valid_o(bru_valid), .out_rob_tag_o(bru_tag),
    .out_pc_o(bru_pc), .out_target_o(bru_target), .out_next_pc_o(bru_next_pc),
    .out_return_address_o(bru_return_address), .out_taken_o(bru_taken),
    .out_conditional_o(bru_conditional), .out_mispredict_o(bru_mispredict),
    .out_misaligned_o(bru_misaligned), .out_call_o(bru_call), .out_return_o(bru_return)
  );

  rv32_agu u_agu (.base_i(mem_issue_s1), .offset_i(mem_issue_imm), .address_o(mem_address));
  assign mem_issue_ready = !global_flush;

  rv32_lsu u_lsu (
    .clk_i(clk_i), .rst_ni(rst_ni), .flush_i(global_flush), .flush_tag_i(global_flush_tag),
    .load_alloc_valid_i(issue_fire && (decoded.uop_class == rv32_pkg::UOP_LOAD)),
    .load_alloc_ready_o(lq_alloc_ready), .load_alloc_index_o(lq_alloc_index),
    .load_alloc_rob_tag_i(rob_alloc_tag), .load_alloc_dest_phy_i(issue_dest_phy),
    .load_alloc_size_i(decoded.mem_size), .load_alloc_unsigned_i(decoded.mem_unsigned),
    .store_alloc_valid_i(issue_fire && (decoded.uop_class == rv32_pkg::UOP_STORE)),
    .store_alloc_ready_o(sq_alloc_ready), .store_alloc_index_o(sq_alloc_index),
    .store_alloc_rob_tag_i(rob_alloc_tag), .store_alloc_size_i(decoded.mem_size),
    .store_alloc_data_ready_i(issue_src2_ready), .store_alloc_data_tag_i(rat_rs2_phy),
    .store_alloc_data_value_i(issue_src2_value), .address_valid_i(mem_issue_valid && mem_issue_ready),
    .address_is_store_i(mem_issue_aux[3]), .address_index_i(mem_issue_aux[2:0]),
    .address_value_i(mem_address),
    .wb0_valid_i(wb_alu_valid), .wb0_phy_i(wb_alu_phy), .wb0_value_i(wb_alu_value),
    .wb1_valid_i(wb_load_valid), .wb1_phy_i(wb_load_phy), .wb1_value_i(wb_load_value),
    .wb2_valid_i(wb_mul_valid), .wb2_phy_i(wb_mul_phy), .wb2_value_i(wb_mul_value),
    .wb3_valid_i(wb_div_valid), .wb3_phy_i(wb_div_phy), .wb3_value_i(wb_div_value),
    .load_result_valid_o(load_cdb_valid), .load_result_ready_i(1'b1),
    .load_result_rob_tag_o(wb_load_tag), .load_result_dest_phy_o(wb_load_phy),
    .load_result_value_o(wb_load_value), .store_complete_valid_o(store_complete_valid),
    .store_complete_rob_tag_o(store_complete_tag),
    .store_commit_valid_i(rob_commit_valid && rob_commit_store),
    .store_commit_rob_tag_i(rob_commit_tag), .store_commit_index_i(rob_commit_sq_index),
    .store_commit_ready_o(lsu_store_commit_ready), .dmem_req_valid_o(dmem_req_valid_o),
    .dmem_req_ready_i(dmem_req_ready_i), .dmem_req_write_o(dmem_req_write_o),
    .dmem_req_addr_o(dmem_req_addr_o), .dmem_req_wdata_o(dmem_req_wdata_o),
    .dmem_req_wstrb_o(dmem_req_wstrb_o), .dmem_req_size_o(lsu_dmem_size),
    .dmem_rsp_valid_i(dmem_rsp_valid_i), .dmem_rsp_rdata_i(dmem_rsp_rdata_i),
    .lq_count_o(lq_count), .sq_count_o(sq_count)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      halted_q <= 1'b0;
      trap_q <= 1'b0;
    end else if (rob_commit_fire) begin
      if (rob_commit_halt)
        halted_q <= 1'b1;
      if (rob_commit_exception)
        trap_q <= 1'b1;
    end
  end
endmodule
