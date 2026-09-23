module rv32_alu (
  input  logic [5:0]           op_i,
  input  logic [31:0]          lhs_i,
  input  logic [31:0]          rhs_i,
  input  logic [31:0]          imm_i,
  input  logic [31:0]          pc_i,
  input  logic                 use_imm_i,
  output logic [31:0]          result_o
);
  import rv32_pkg::*;

  logic [31:0] operand_b;
  logic [31:0] sum_add;
  logic [31:0] sum_sub;
  logic [31:0] sum_auipc;
  logic unused_cout_add, unused_cout_auipc, unused_borrow;

  assign operand_b = use_imm_i ? imm_i : rhs_i;

  rv32_add #(.WIDTH(32)) u_add (
    .a_i(lhs_i), .b_i(operand_b), .cin_i(1'b0),
    .sum_o(sum_add), .cout_o(unused_cout_add)
  );

  rv32_sub #(.WIDTH(32)) u_sub (
    .a_i(lhs_i), .b_i(operand_b),
    .diff_o(sum_sub), .borrow_o(unused_borrow)
  );

  rv32_add #(.WIDTH(32)) u_auipc (
    .a_i(pc_i), .b_i(imm_i), .cin_i(1'b0),
    .sum_o(sum_auipc), .cout_o(unused_cout_auipc)
  );

  always_comb begin
    unique case (op_i)
      OP_ADD:   result_o = sum_add;
      OP_SUB:   result_o = sum_sub;
      OP_SLL:   result_o = lhs_i << operand_b[4:0];
      OP_SLT:   result_o = {31'b0, $signed(lhs_i) < $signed(operand_b)};
      OP_SLTU:  result_o = {31'b0, lhs_i < operand_b};
      OP_XOR:   result_o = lhs_i ^ operand_b;
      OP_SRL:   result_o = lhs_i >> operand_b[4:0];
      OP_SRA:   result_o = $unsigned($signed(lhs_i) >>> operand_b[4:0]);
      OP_OR:    result_o = lhs_i | operand_b;
      OP_AND:   result_o = lhs_i & operand_b;
      OP_LUI:   result_o = imm_i;
      OP_AUIPC: result_o = sum_auipc;
      OP_JAL:   result_o = sum_auipc;
      OP_JALR:  result_o = sum_add & 32'hffff_fffe;
      default:  result_o = 32'b0;
    endcase
  end
endmodule
