module rv32_bru_unit (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,

  input  logic                   in_valid_i,
  output logic                   in_ready_o,
  input  rv32_pkg::operation_e   op_i,
  input  logic [31:0]            src1_i,
  input  logic [31:0]            src2_i,
  input  logic [31:0]            pc_i,
  input  logic [31:0]            imm_i,
  input  logic [31:0]            predicted_next_pc_i,
  input  rv32_pkg::rob_tag_t     rob_tag_i,
  input  logic                   is_call_i,
  input  logic                   is_return_i,

  output logic                   out_valid_o,
  output rv32_pkg::rob_tag_t     out_rob_tag_o,
  output logic [31:0]            out_pc_o,
  output logic [31:0]            out_target_o,
  output logic [31:0]            out_next_pc_o,
  output logic [31:0]            out_return_address_o,
  output logic                   out_taken_o,
  output logic                   out_conditional_o,
  output logic                   out_mispredict_o,
  output logic                   out_misaligned_o,
  output logic                   out_call_o,
  output logic                   out_return_o
);
  import rv32_pkg::*;

  logic bru_taken, bru_mispredict, bru_misaligned;
  logic [31:0] bru_target, bru_next_pc, bru_link;
  logic valid_q;
  rob_tag_t tag_q;
  logic [31:0] pc_q, target_q, next_pc_q, return_address_q;
  logic taken_q, conditional_q, mispredict_q, misaligned_q;
  logic call_q, return_q;

  rv32_bru u_bru (
    .op_i(op_i), .src1_i(src1_i), .src2_i(src2_i), .pc_i(pc_i),
    .imm_i(imm_i), .predicted_next_pc_i(predicted_next_pc_i),
    .taken_o(bru_taken), .target_o(bru_target), .next_pc_o(bru_next_pc),
    .link_value_o(bru_link), .mispredict_o(bru_mispredict),
    .target_misaligned_o(bru_misaligned)
  );

  always_comb begin
    in_ready_o = !flush_i;
    out_valid_o = valid_q;
    out_rob_tag_o = tag_q;
    out_pc_o = pc_q;
    out_target_o = target_q;
    out_next_pc_o = next_pc_q;
    out_return_address_o = return_address_q;
    out_taken_o = taken_q;
    out_conditional_o = conditional_q;
    out_mispredict_o = mispredict_q;
    out_misaligned_o = misaligned_q;
    out_call_o = call_q;
    out_return_o = return_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= 1'b0;
      tag_q <= '0;
      pc_q <= '0;
      target_q <= '0;
      next_pc_q <= '0;
      return_address_q <= '0;
      taken_q <= 1'b0;
      conditional_q <= 1'b0;
      mispredict_q <= 1'b0;
      misaligned_q <= 1'b0;
      call_q <= 1'b0;
      return_q <= 1'b0;
    end else if (flush_i) begin
      valid_q <= 1'b0;
    end else begin
      valid_q <= in_valid_i;
      if (in_valid_i) begin
        tag_q <= rob_tag_i;
        pc_q <= pc_i;
        target_q <= bru_target;
        next_pc_q <= bru_next_pc;
        return_address_q <= bru_link;
        taken_q <= bru_taken;
        conditional_q <= !((op_i == OP_JAL) || (op_i == OP_JALR));
        mispredict_q <= bru_mispredict;
        misaligned_q <= bru_misaligned;
        call_q <= is_call_i;
        return_q <= is_return_i;
      end
    end
  end
endmodule
