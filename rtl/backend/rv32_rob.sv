module rv32_rob #(
  parameter int unsigned DEPTH = rv32_pkg::ROB_ENTRIES
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic                   alloc_valid_i,
  output logic                   alloc_ready_o,
  output rv32_pkg::rob_tag_t     alloc_tag_o,
  input  logic [31:0]            alloc_pc_i,
  input  logic [31:0]            alloc_instr_i,
  input  logic                   alloc_writes_rd_i,
  input  logic [4:0]             alloc_arch_rd_i,
  input  rv32_pkg::phy_tag_t     alloc_new_phy_i,
  input  rv32_pkg::phy_tag_t     alloc_old_phy_i,
  input  logic                   alloc_ready_i,
  input  logic                   alloc_store_i,
  input  logic [2:0]             alloc_sq_index_i,
  input  logic                   alloc_halt_i,
  input  logic                   alloc_exception_i,
  input  logic [31:0]            alloc_predicted_pc_i,
  input  rv32_pkg::bpu_ckpt_id_t alloc_predictor_ckpt_id_i,
  input  logic                   alloc_is_ret_i,

  input  logic                   complete0_valid_i,
  input  rv32_pkg::rob_tag_t     complete0_tag_i,
  input  logic                   complete0_exception_i,
  input  logic                   complete1_valid_i,
  input  rv32_pkg::rob_tag_t     complete1_tag_i,
  input  logic                   complete2_valid_i,
  input  rv32_pkg::rob_tag_t     complete2_tag_i,
  input  logic                   complete3_valid_i,
  input  rv32_pkg::rob_tag_t     complete3_tag_i,
  input  logic                   complete4_valid_i,
  input  rv32_pkg::rob_tag_t     complete4_tag_i,
  input  logic                   complete4_exception_i,
  input  logic                   complete5_valid_i,
  input  rv32_pkg::rob_tag_t     complete5_tag_i,

  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  rv32_pkg::rob_tag_t     lookup0_tag_i,
  output logic                   lookup0_valid_o,
  output logic [31:0]            lookup0_pc_o,
  output logic [31:0]            lookup0_predicted_pc_o,
  output rv32_pkg::bpu_ckpt_id_t lookup0_predictor_ckpt_id_o,
  output logic                   lookup0_is_ret_o,
  input  rv32_pkg::rob_tag_t     lookup1_tag_i,
  output logic                   lookup1_valid_o,
  output logic [31:0]            lookup1_pc_o,
  output logic [31:0]            lookup1_predicted_pc_o,
  output rv32_pkg::bpu_ckpt_id_t lookup1_predictor_ckpt_id_o,
  output logic                   lookup1_is_ret_o,
  input  rv32_pkg::rob_tag_t     lookup2_tag_i,
  output logic                   lookup2_valid_o,
  input  rv32_pkg::rob_tag_t     lookup3_tag_i,
  output logic                   lookup3_valid_o,
  input  rv32_pkg::rob_tag_t     lookup4_tag_i,
  output logic                   lookup4_valid_o,

  output logic                   commit_valid_o,
  input  logic                   commit_ready_i,
  output logic                   commit_fire_o,
  output rv32_pkg::rob_tag_t     commit_tag_o,
  output logic [31:0]            commit_pc_o,
  output logic [31:0]            commit_instr_o,
  output logic                   commit_writes_rd_o,
  output logic [4:0]             commit_arch_rd_o,
  output rv32_pkg::phy_tag_t     commit_new_phy_o,
  output rv32_pkg::phy_tag_t     commit_old_phy_o,
  output logic                   commit_store_o,
  output logic [2:0]             commit_sq_index_o,
  output logic                   commit_halt_o,
  output logic                   commit_exception_o,

  output logic                   empty_o,
  output logic                   full_o,
  output logic [$clog2(DEPTH+1)-1:0] count_o,
  output rv32_pkg::rob_tag_t     head_tag_o,

  output rv32_pkg::rob_tag_t     replay_tag_o [0:DEPTH-1],
  output logic [4:0]             replay_arch_rd_o [0:DEPTH-1],
  output rv32_pkg::phy_tag_t     replay_new_phy_o [0:DEPTH-1]
);
  import rv32_pkg::*;

  localparam int unsigned SLOT_W = $clog2(DEPTH);
  localparam int unsigned COUNT_W = $clog2(DEPTH + 1);

  logic valid_q [0:DEPTH-1];
  rob_tag_t tag_q [0:DEPTH-1];
  logic ready_q [0:DEPTH-1];
  logic [31:0] pc_q [0:DEPTH-1];
  logic [31:0] instr_q [0:DEPTH-1];
  logic writes_rd_q [0:DEPTH-1];
  logic [4:0] arch_rd_q [0:DEPTH-1];
  phy_tag_t new_phy_q [0:DEPTH-1];
  phy_tag_t old_phy_q [0:DEPTH-1];
  logic store_q [0:DEPTH-1];
  logic [2:0] sq_index_q [0:DEPTH-1];
  logic halt_q [0:DEPTH-1];
  logic exception_q [0:DEPTH-1];
  logic [31:0] predicted_pc_q [0:DEPTH-1];
  bpu_ckpt_id_t predictor_ckpt_id_q [0:DEPTH-1];
  logic is_ret_q [0:DEPTH-1];

  rob_tag_t head_q, tail_q;
  logic [$clog2(DEPTH+1)-1:0] count_q;
  logic [SLOT_W-1:0] head_slot;
  logic [SLOT_W-1:0] tail_slot;
  logic [ROB_TAG_W-1:0] flush_count;
  logic [COUNT_W-1:0] flush_count_after_commit;
  integer i;

  logic [ROB_TAG_W-1:0] flush_tag_next;
  logic [ROB_TAG_W-1:0] head_next, tail_next;
  logic [COUNT_W-1:0] count_up, count_down;
  logic unused_cout_flush_tag, unused_borrow_flush;
  logic unused_cout_head, unused_cout_tail;
  logic unused_cout_count_up, unused_borrow_count_down;
  logic unused_borrow_flush_commit;

  genvar replay_index;
  generate
    for (replay_index = 0; replay_index < DEPTH;
         replay_index = replay_index + 1) begin : gen_replay_window
      logic [SLOT_W-1:0] replay_slot;

      assign replay_slot = head_q[SLOT_W-1:0] + SLOT_W'(replay_index);
      assign replay_tag_o[replay_index] = tag_q[replay_slot];
      assign replay_arch_rd_o[replay_index] = arch_rd_q[replay_slot];
      assign replay_new_phy_o[replay_index] = new_phy_q[replay_slot];
    end
  endgenerate

  rv32_add #(.WIDTH(ROB_TAG_W)) u_flush_tag_next (
    .a_i(flush_tag_i), .b_i(ROB_TAG_W'(1)), .cin_i(1'b0),
    .sum_o(flush_tag_next), .cout_o(unused_cout_flush_tag)
  );

  rv32_sub #(.WIDTH(ROB_TAG_W)) u_flush_count (
    .a_i(flush_tag_next), .b_i(head_q),
    .diff_o(flush_count), .borrow_o(unused_borrow_flush)
  );

  rv32_add #(.WIDTH(ROB_TAG_W)) u_head_next (
    .a_i(head_q), .b_i(ROB_TAG_W'(1)), .cin_i(1'b0),
    .sum_o(head_next), .cout_o(unused_cout_head)
  );

  rv32_add #(.WIDTH(ROB_TAG_W)) u_tail_next (
    .a_i(tail_q), .b_i(ROB_TAG_W'(1)), .cin_i(1'b0),
    .sum_o(tail_next), .cout_o(unused_cout_tail)
  );

  rv32_add #(.WIDTH(COUNT_W)) u_count_up (
    .a_i(count_q), .b_i(COUNT_W'(1)), .cin_i(1'b0),
    .sum_o(count_up), .cout_o(unused_cout_count_up)
  );

  rv32_sub #(.WIDTH(COUNT_W)) u_count_down (
    .a_i(count_q), .b_i(COUNT_W'(1)),
    .diff_o(count_down), .borrow_o(unused_borrow_count_down)
  );

  rv32_sub #(.WIDTH(COUNT_W)) u_flush_count_after_commit (
    .a_i(flush_count[COUNT_W-1:0]), .b_i(COUNT_W'(1)),
    .diff_o(flush_count_after_commit),
    .borrow_o(unused_borrow_flush_commit)
  );

  always_comb begin
    head_slot = head_q[SLOT_W-1:0];
    tail_slot = tail_q[SLOT_W-1:0];
    empty_o = (count_q == '0);
    full_o = (count_q == COUNT_W'(DEPTH));
    count_o = count_q;
    head_tag_o = head_q;
    alloc_tag_o = tail_q;
    alloc_ready_o = !flush_i && !full_o;

    lookup0_valid_o = valid_q[lookup0_tag_i[SLOT_W-1:0]] &&
                      (tag_q[lookup0_tag_i[SLOT_W-1:0]] == lookup0_tag_i);
    lookup0_pc_o = pc_q[lookup0_tag_i[SLOT_W-1:0]];
    lookup0_predicted_pc_o = predicted_pc_q[lookup0_tag_i[SLOT_W-1:0]];
    lookup0_predictor_ckpt_id_o =
      predictor_ckpt_id_q[lookup0_tag_i[SLOT_W-1:0]];
    lookup0_is_ret_o = is_ret_q[lookup0_tag_i[SLOT_W-1:0]];

    lookup1_valid_o = valid_q[lookup1_tag_i[SLOT_W-1:0]] &&
                      (tag_q[lookup1_tag_i[SLOT_W-1:0]] == lookup1_tag_i);
    lookup1_pc_o = pc_q[lookup1_tag_i[SLOT_W-1:0]];
    lookup1_predicted_pc_o = predicted_pc_q[lookup1_tag_i[SLOT_W-1:0]];
    lookup1_predictor_ckpt_id_o =
      predictor_ckpt_id_q[lookup1_tag_i[SLOT_W-1:0]];
    lookup1_is_ret_o = is_ret_q[lookup1_tag_i[SLOT_W-1:0]];

    lookup2_valid_o = valid_q[lookup2_tag_i[SLOT_W-1:0]] &&
                      (tag_q[lookup2_tag_i[SLOT_W-1:0]] == lookup2_tag_i);
    lookup3_valid_o = valid_q[lookup3_tag_i[SLOT_W-1:0]] &&
                      (tag_q[lookup3_tag_i[SLOT_W-1:0]] == lookup3_tag_i);
    lookup4_valid_o = valid_q[lookup4_tag_i[SLOT_W-1:0]] &&
                      (tag_q[lookup4_tag_i[SLOT_W-1:0]] == lookup4_tag_i);
  end

  always_comb begin
    commit_valid_o = (count_q != '0) && valid_q[head_q[SLOT_W-1:0]] &&
                     ready_q[head_q[SLOT_W-1:0]] &&
                     (!flush_i || rob_is_older(tag_q[head_slot], flush_tag_i));
    commit_tag_o = tag_q[head_slot];
    commit_pc_o = pc_q[head_slot];
    commit_instr_o = instr_q[head_slot];
    commit_writes_rd_o = writes_rd_q[head_slot];
    commit_arch_rd_o = arch_rd_q[head_slot];
    commit_new_phy_o = new_phy_q[head_slot];
    commit_old_phy_o = old_phy_q[head_slot];
    commit_store_o = store_q[head_slot];
    commit_sq_index_o = sq_index_q[head_slot];
    commit_halt_o = halt_q[head_slot];
    commit_exception_o = exception_q[head_slot];
  end

  assign commit_fire_o = commit_valid_o && commit_ready_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      head_q <= '0;
      tail_q <= '0;
      count_q <= '0;
      for (i = 0; i < DEPTH; i = i + 1) begin
        valid_q[i] <= 1'b0;
        tag_q[i] <= '0;
        ready_q[i] <= 1'b0;
        pc_q[i] <= '0;
        instr_q[i] <= '0;
        writes_rd_q[i] <= 1'b0;
        arch_rd_q[i] <= '0;
        new_phy_q[i] <= '0;
        old_phy_q[i] <= '0;
        store_q[i] <= 1'b0;
        sq_index_q[i] <= '0;
        halt_q[i] <= 1'b0;
        exception_q[i] <= 1'b0;
        predicted_pc_q[i] <= '0;
        predictor_ckpt_id_q[i] <= '0;
        is_ret_q[i] <= 1'b0;
      end
    end else if (flush_i) begin
      tail_q <= flush_tag_next;
      count_q <= commit_fire_o ? flush_count_after_commit :
                                 flush_count[COUNT_W-1:0];
      for (i = 0; i < DEPTH; i = i + 1) begin
        if (valid_q[i] && rob_is_younger(tag_q[i], flush_tag_i))
          valid_q[i] <= 1'b0;
      end

      if (complete0_valid_i && rob_is_older(complete0_tag_i, flush_tag_i) &&
          valid_q[complete0_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete0_tag_i[SLOT_W-1:0]] == complete0_tag_i)) begin
        ready_q[complete0_tag_i[SLOT_W-1:0]] <= 1'b1;
        if (complete0_exception_i)
          exception_q[complete0_tag_i[SLOT_W-1:0]] <= 1'b1;
      end
      if (complete1_valid_i && rob_is_older(complete1_tag_i, flush_tag_i) &&
          valid_q[complete1_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete1_tag_i[SLOT_W-1:0]] == complete1_tag_i))
        ready_q[complete1_tag_i[SLOT_W-1:0]] <= 1'b1;
      if (complete2_valid_i && rob_is_older(complete2_tag_i, flush_tag_i) &&
          valid_q[complete2_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete2_tag_i[SLOT_W-1:0]] == complete2_tag_i))
        ready_q[complete2_tag_i[SLOT_W-1:0]] <= 1'b1;
      if (complete3_valid_i && rob_is_older(complete3_tag_i, flush_tag_i) &&
          valid_q[complete3_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete3_tag_i[SLOT_W-1:0]] == complete3_tag_i))
        ready_q[complete3_tag_i[SLOT_W-1:0]] <= 1'b1;
      if (complete4_valid_i && rob_is_older(complete4_tag_i, flush_tag_i) &&
          valid_q[complete4_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete4_tag_i[SLOT_W-1:0]] == complete4_tag_i)) begin
        ready_q[complete4_tag_i[SLOT_W-1:0]] <= 1'b1;
        if (complete4_exception_i)
          exception_q[complete4_tag_i[SLOT_W-1:0]] <= 1'b1;
      end
      if (complete5_valid_i && rob_is_older(complete5_tag_i, flush_tag_i) &&
          valid_q[complete5_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete5_tag_i[SLOT_W-1:0]] == complete5_tag_i))
        ready_q[complete5_tag_i[SLOT_W-1:0]] <= 1'b1;

      if (commit_fire_o) begin
        valid_q[head_slot] <= 1'b0;
        head_q <= head_next;
      end
    end else begin
      if (complete0_valid_i && valid_q[complete0_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete0_tag_i[SLOT_W-1:0]] == complete0_tag_i)) begin
        ready_q[complete0_tag_i[SLOT_W-1:0]] <= 1'b1;
        if (complete0_exception_i)
          exception_q[complete0_tag_i[SLOT_W-1:0]] <= 1'b1;
      end
      if (complete1_valid_i && valid_q[complete1_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete1_tag_i[SLOT_W-1:0]] == complete1_tag_i))
        ready_q[complete1_tag_i[SLOT_W-1:0]] <= 1'b1;
      if (complete2_valid_i && valid_q[complete2_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete2_tag_i[SLOT_W-1:0]] == complete2_tag_i))
        ready_q[complete2_tag_i[SLOT_W-1:0]] <= 1'b1;
      if (complete3_valid_i && valid_q[complete3_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete3_tag_i[SLOT_W-1:0]] == complete3_tag_i))
        ready_q[complete3_tag_i[SLOT_W-1:0]] <= 1'b1;
      if (complete4_valid_i && valid_q[complete4_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete4_tag_i[SLOT_W-1:0]] == complete4_tag_i)) begin
        ready_q[complete4_tag_i[SLOT_W-1:0]] <= 1'b1;
        if (complete4_exception_i)
          exception_q[complete4_tag_i[SLOT_W-1:0]] <= 1'b1;
      end
      if (complete5_valid_i && valid_q[complete5_tag_i[SLOT_W-1:0]] &&
          (tag_q[complete5_tag_i[SLOT_W-1:0]] == complete5_tag_i))
        ready_q[complete5_tag_i[SLOT_W-1:0]] <= 1'b1;

      if (commit_fire_o) begin
        valid_q[head_slot] <= 1'b0;
        head_q <= head_next;
      end

      if (alloc_valid_i && alloc_ready_o) begin
        valid_q[tail_slot] <= 1'b1;
        tag_q[tail_slot] <= tail_q;
        ready_q[tail_slot] <= alloc_ready_i || alloc_halt_i ||
                              alloc_exception_i;
        pc_q[tail_slot] <= alloc_pc_i;
        instr_q[tail_slot] <= alloc_instr_i;
        writes_rd_q[tail_slot] <= alloc_writes_rd_i;
        arch_rd_q[tail_slot] <= alloc_arch_rd_i;
        new_phy_q[tail_slot] <= alloc_new_phy_i;
        old_phy_q[tail_slot] <= alloc_old_phy_i;
        store_q[tail_slot] <= alloc_store_i;
        sq_index_q[tail_slot] <= alloc_sq_index_i;
        halt_q[tail_slot] <= alloc_halt_i;
        exception_q[tail_slot] <= alloc_exception_i;
        predicted_pc_q[tail_slot] <= alloc_predicted_pc_i;
        predictor_ckpt_id_q[tail_slot] <= alloc_predictor_ckpt_id_i;
        is_ret_q[tail_slot] <= alloc_is_ret_i;
        tail_q <= tail_next;
      end

      unique case ({alloc_valid_i && alloc_ready_o, commit_fire_o})
        2'b10: count_q <= count_up;
        2'b01: count_q <= count_down;
        default: count_q <= count_q;
      endcase
    end
  end
endmodule
