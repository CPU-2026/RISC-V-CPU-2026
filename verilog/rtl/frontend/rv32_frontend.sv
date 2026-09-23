module rv32_frontend #(
  parameter int unsigned FQ_DEPTH = 4,
  parameter int unsigned IQ_DEPTH = 4,
  parameter logic [31:0] RESET_PC = 32'b0
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,

  output logic [31:0]            predictor_pc_o,
  input  logic [31:0]            predicted_next_pc_i,
  input  rv32_pkg::bpu_ckpt_id_t predicted_ckpt_id_i,
  output logic                   predictor_accept_o,

  output logic                   imem_req_valid_o,
  input  logic                   imem_req_ready_i,
  output logic [31:0]            imem_req_addr_o,
  input  logic                   imem_rsp_valid_i,
  input  logic [31:0]            imem_rsp_data_i,

  input  logic                   redirect_valid_i,
  input  logic [31:0]            redirect_pc_i,

  output logic                   iq_valid_o,
  input  logic                   iq_ready_i,
  output logic [31:0]            iq_pc_o,
  output logic [31:0]            iq_instr_o,
  output logic [31:0]            iq_predicted_pc_o,
  output rv32_pkg::bpu_ckpt_id_t iq_ckpt_id_o,

  output logic                   fetch_info_valid_o,
  output logic                   fetch_info_call_o,
  output logic                   fetch_info_return_o,
  output logic                   fetch_info_jal_target_valid_o,
  output logic [31:0]            fetch_info_pc_o,
  output logic [31:0]            fetch_info_jal_target_o,

  output logic [$clog2(FQ_DEPTH+1)-1:0] fq_count_o,
  output logic [$clog2(IQ_DEPTH+1)-1:0] iq_count_o
);
  import rv32_pkg::*;

  localparam int unsigned FQ_PTR_W = $clog2(FQ_DEPTH);
  localparam int unsigned IQ_PTR_W = $clog2(IQ_DEPTH);
  localparam int unsigned FQ_COUNT_W = $clog2(FQ_DEPTH+1);
  localparam int unsigned IQ_COUNT_W = $clog2(IQ_DEPTH+1);

  logic [31:0] pc_q;
  logic request_pending_q;
  logic request_drop_q;
  logic [31:0] request_pc_q;
  logic [31:0] request_predicted_pc_q;
  bpu_ckpt_id_t request_ckpt_id_q;
  logic stop_fetch_q;

  logic [31:0] fq_pc_q [0:FQ_DEPTH-1];
  logic [31:0] fq_instr_q [0:FQ_DEPTH-1];
  logic [31:0] fq_predicted_pc_q [0:FQ_DEPTH-1];
  bpu_ckpt_id_t fq_ckpt_id_q [0:FQ_DEPTH-1];
  logic [FQ_PTR_W-1:0] fq_head_q, fq_tail_q;
  logic [$clog2(FQ_DEPTH+1)-1:0] fq_count_q;

  logic [31:0] iq_pc_q [0:IQ_DEPTH-1];
  logic [31:0] iq_instr_q [0:IQ_DEPTH-1];
  logic [31:0] iq_predicted_pc_q [0:IQ_DEPTH-1];
  bpu_ckpt_id_t iq_ckpt_id_q [0:IQ_DEPTH-1];
  logic [IQ_PTR_W-1:0] iq_head_q, iq_tail_q;
  logic [$clog2(IQ_DEPTH+1)-1:0] iq_count_q;

  logic request_fire;
  logic response_accept;
  logic halt_response;
  logic fire_space_ok;
  logic fq_push;
  logic fq_pop;
  logic iq_push;
  logic iq_pop;
  integer i;

  logic [FQ_PTR_W-1:0] fq_tail_next, fq_head_next;
  logic [IQ_PTR_W-1:0] iq_tail_next, iq_head_next;
  logic [FQ_COUNT_W-1:0] fq_count_up, fq_count_down;
  logic [IQ_COUNT_W-1:0] iq_count_up, iq_count_down;
  logic unused_cout_fq_tail, unused_cout_fq_head;
  logic unused_cout_iq_tail, unused_cout_iq_head;
  logic unused_cout_fq_up, unused_borrow_fq_down;
  logic unused_cout_iq_up, unused_borrow_iq_down;

  logic last_fq_push_q;
  logic [31:0] last_fq_instr_q, last_fq_pc_q;
  logic [6:0] fetch_opcode;
  logic [2:0] fetch_funct3;
  logic [4:0] fetch_rd, fetch_rs1;
  logic fetch_rd_link, fetch_rs1_link;

  rv32_add #(.WIDTH(FQ_PTR_W)) u_fq_tail_next (
    .a_i(fq_tail_q), .b_i(FQ_PTR_W'(1)), .cin_i(1'b0),
    .sum_o(fq_tail_next), .cout_o(unused_cout_fq_tail)
  );

  rv32_add #(.WIDTH(FQ_PTR_W)) u_fq_head_next (
    .a_i(fq_head_q), .b_i(FQ_PTR_W'(1)), .cin_i(1'b0),
    .sum_o(fq_head_next), .cout_o(unused_cout_fq_head)
  );

  rv32_add #(.WIDTH(IQ_PTR_W)) u_iq_tail_next (
    .a_i(iq_tail_q), .b_i(IQ_PTR_W'(1)), .cin_i(1'b0),
    .sum_o(iq_tail_next), .cout_o(unused_cout_iq_tail)
  );

  rv32_add #(.WIDTH(IQ_PTR_W)) u_iq_head_next (
    .a_i(iq_head_q), .b_i(IQ_PTR_W'(1)), .cin_i(1'b0),
    .sum_o(iq_head_next), .cout_o(unused_cout_iq_head)
  );

  rv32_add #(.WIDTH(FQ_COUNT_W)) u_fq_count_up (
    .a_i(fq_count_q), .b_i(FQ_COUNT_W'(1)), .cin_i(1'b0),
    .sum_o(fq_count_up), .cout_o(unused_cout_fq_up)
  );

  rv32_sub #(.WIDTH(FQ_COUNT_W)) u_fq_count_down (
    .a_i(fq_count_q), .b_i(FQ_COUNT_W'(1)),
    .diff_o(fq_count_down), .borrow_o(unused_borrow_fq_down)
  );

  rv32_add #(.WIDTH(IQ_COUNT_W)) u_iq_count_up (
    .a_i(iq_count_q), .b_i(IQ_COUNT_W'(1)), .cin_i(1'b0),
    .sum_o(iq_count_up), .cout_o(unused_cout_iq_up)
  );

  rv32_sub #(.WIDTH(IQ_COUNT_W)) u_iq_count_down (
    .a_i(iq_count_q), .b_i(IQ_COUNT_W'(1)),
    .diff_o(iq_count_down), .borrow_o(unused_borrow_iq_down)
  );

  always_comb begin
    predictor_pc_o = pc_q;
    response_accept = imem_rsp_valid_i && request_pending_q;
    halt_response = response_accept && (imem_rsp_data_i == HALT_INSN);
    fire_space_ok = response_accept
                    ? (fq_count_q <= $clog2(FQ_DEPTH+1)'(FQ_DEPTH - 2))
                    : (fq_count_q != $clog2(FQ_DEPTH+1)'(FQ_DEPTH));
    imem_req_valid_o = (response_accept || !request_pending_q) &&
                       !halt_response && fire_space_ok &&
                       !stop_fetch_q && !redirect_valid_i;
    imem_req_addr_o = pc_q;
    request_fire = imem_req_valid_o && imem_req_ready_i;
    predictor_accept_o = request_fire;
    fq_push = response_accept && !request_drop_q && !redirect_valid_i;
    fq_pop = (fq_count_q != '0) &&
             (iq_count_q != $clog2(IQ_DEPTH+1)'(IQ_DEPTH)) &&
             !redirect_valid_i;
    iq_push = fq_pop;
    fq_count_o = fq_count_q;
    iq_count_o = iq_count_q;
  end

  assign iq_valid_o = (iq_count_q != '0) && !redirect_valid_i;
  assign iq_pop = iq_valid_o && iq_ready_i;
  assign iq_pc_o = iq_pc_q[iq_head_q];
  assign iq_instr_o = iq_instr_q[iq_head_q];
  assign iq_predicted_pc_o = iq_predicted_pc_q[iq_head_q];
  assign iq_ckpt_id_o = iq_ckpt_id_q[iq_head_q];

  always_comb begin
    fetch_opcode = last_fq_instr_q[6:0];
    fetch_funct3 = last_fq_instr_q[14:12];
    fetch_rd = last_fq_instr_q[11:7];
    fetch_rs1 = last_fq_instr_q[19:15];
    fetch_rd_link = (fetch_rd == 5'd1) || (fetch_rd == 5'd5);
    fetch_rs1_link = (fetch_rs1 == 5'd1) || (fetch_rs1 == 5'd5);

    fetch_info_valid_o = last_fq_push_q &&
                         ((fetch_opcode == OPCODE_JAL) ||
                          ((fetch_opcode == OPCODE_JALR) &&
                           (fetch_funct3 == 3'b000)));
    fetch_info_call_o = fetch_info_valid_o && fetch_rd_link;
    fetch_info_return_o = fetch_info_valid_o &&
                           (fetch_opcode == OPCODE_JALR) &&
                           fetch_rs1_link && !fetch_rd_link;
    fetch_info_jal_target_valid_o = fetch_info_valid_o &&
                                    (fetch_opcode == OPCODE_JAL);
    fetch_info_pc_o = last_fq_pc_q;
    fetch_info_jal_target_o = last_fq_pc_q +
                              {{11{last_fq_instr_q[31]}}, last_fq_instr_q[31],
                               last_fq_instr_q[19:12], last_fq_instr_q[20],
                               last_fq_instr_q[30:21], 1'b0};
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= RESET_PC;
      request_pending_q <= 1'b0;
      request_drop_q <= 1'b0;
      request_pc_q <= '0;
      request_predicted_pc_q <= '0;
      request_ckpt_id_q <= '0;
      stop_fetch_q <= 1'b0;
      last_fq_push_q <= 1'b0;
      last_fq_instr_q <= '0;
      last_fq_pc_q <= '0;
      fq_head_q <= '0;
      fq_tail_q <= '0;
      fq_count_q <= '0;
      iq_head_q <= '0;
      iq_tail_q <= '0;
      iq_count_q <= '0;
      for (i = 0; i < FQ_DEPTH; i = i + 1) begin
        fq_pc_q[i] <= '0;
        fq_instr_q[i] <= '0;
        fq_predicted_pc_q[i] <= '0;
        fq_ckpt_id_q[i] <= '0;
      end
      for (i = 0; i < IQ_DEPTH; i = i + 1) begin
        iq_pc_q[i] <= '0;
        iq_instr_q[i] <= '0;
        iq_predicted_pc_q[i] <= '0;
        iq_ckpt_id_q[i] <= '0;
      end
    end else if (redirect_valid_i) begin
      pc_q <= redirect_pc_i;
      fq_head_q <= '0;
      fq_tail_q <= '0;
      fq_count_q <= '0;
      iq_head_q <= '0;
      iq_tail_q <= '0;
      iq_count_q <= '0;
      stop_fetch_q <= 1'b0;
      last_fq_push_q <= 1'b0;
      if (response_accept) begin
        request_pending_q <= 1'b0;
        request_drop_q <= 1'b0;
      end else if (request_pending_q) begin
        request_drop_q <= 1'b1;
      end
    end else begin
      if (request_fire) begin
        request_pending_q <= 1'b1;
        request_drop_q <= 1'b0;
        request_pc_q <= pc_q;
        request_predicted_pc_q <= predicted_next_pc_i;
        request_ckpt_id_q <= predicted_ckpt_id_i;
        pc_q <= predicted_next_pc_i;
      end

      if (response_accept) begin
        if (!request_fire)
          request_pending_q <= 1'b0;
        request_drop_q <= 1'b0;
        if (!request_drop_q) begin
          fq_pc_q[fq_tail_q] <= request_pc_q;
          fq_instr_q[fq_tail_q] <= imem_rsp_data_i;
          fq_predicted_pc_q[fq_tail_q] <= request_predicted_pc_q;
          fq_ckpt_id_q[fq_tail_q] <= request_ckpt_id_q;
          fq_tail_q <= fq_tail_next;
          if (imem_rsp_data_i == HALT_INSN)
            stop_fetch_q <= 1'b1;
        end
      end

      if (fq_pop) begin
        iq_pc_q[iq_tail_q] <= fq_pc_q[fq_head_q];
        iq_instr_q[iq_tail_q] <= fq_instr_q[fq_head_q];
        iq_predicted_pc_q[iq_tail_q] <= fq_predicted_pc_q[fq_head_q];
        iq_ckpt_id_q[iq_tail_q] <= fq_ckpt_id_q[fq_head_q];
        fq_head_q <= fq_head_next;
        iq_tail_q <= iq_tail_next;
      end
      if (iq_pop)
        iq_head_q <= iq_head_next;

      last_fq_push_q <= fq_push;
      if (fq_push) begin
        last_fq_instr_q <= imem_rsp_data_i;
        last_fq_pc_q <= request_pc_q;
      end

      unique case ({fq_push, fq_pop})
        2'b10: fq_count_q <= fq_count_up;
        2'b01: fq_count_q <= fq_count_down;
        default: fq_count_q <= fq_count_q;
      endcase
      unique case ({iq_push, iq_pop})
        2'b10: iq_count_q <= iq_count_up;
        2'b01: iq_count_q <= iq_count_down;
        default: iq_count_q <= iq_count_q;
      endcase
    end
  end
endmodule
