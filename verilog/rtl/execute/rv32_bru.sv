module rv32_bru (
  input  rv32_pkg::operation_e op_i,
  input  logic [31:0]          src1_i,
  input  logic [31:0]          src2_i,
  input  logic [31:0]          pc_i,
  input  logic [31:0]          imm_i,
  input  logic [31:0]          predicted_next_pc_i,
  output logic                 taken_o,
  output logic [31:0]          target_o,
  output logic [31:0]          next_pc_o,
  output logic [31:0]          link_value_o,
  output logic                 mispredict_o,
  output logic                 target_misaligned_o
);
  import rv32_pkg::*;

  logic condition;
  logic [31:0] pc_plus_4;
  logic [31:0] pc_plus_imm;
  logic [31:0] src1_plus_imm;
  logic unused_cout_pc4, unused_cout_pcimm, unused_cout_src1imm;

  rv32_add #(.WIDTH(32)) u_pc_plus_4 (
    .a_i(pc_i), .b_i(32'd4), .cin_i(1'b0),
    .sum_o(pc_plus_4), .cout_o(unused_cout_pc4)
  );

  rv32_add #(.WIDTH(32)) u_pc_plus_imm (
    .a_i(pc_i), .b_i(imm_i), .cin_i(1'b0),
    .sum_o(pc_plus_imm), .cout_o(unused_cout_pcimm)
  );

  rv32_add #(.WIDTH(32)) u_src1_plus_imm (
    .a_i(src1_i), .b_i(imm_i), .cin_i(1'b0),
    .sum_o(src1_plus_imm), .cout_o(unused_cout_src1imm)
  );

  always_comb begin
    condition = 1'b0;
    unique case (op_i)
      OP_BEQ:  condition = (src1_i == src2_i);
      OP_BNE:  condition = (src1_i != src2_i);
      OP_BLT:  condition = ($signed(src1_i) < $signed(src2_i));
      OP_BGE:  condition = ($signed(src1_i) >= $signed(src2_i));
      OP_BLTU: condition = (src1_i < src2_i);
      OP_BGEU: condition = (src1_i >= src2_i);
      OP_JAL, OP_JALR: begin
        condition = 1'b1;
      end
      default: condition = 1'b0;
    endcase

    taken_o = condition;
    link_value_o = pc_plus_4;
    if (op_i == OP_JALR) begin
      target_o = src1_plus_imm & 32'hffff_fffe;
      next_pc_o = src1_plus_imm & 32'hffff_fffe;
    end else begin
      target_o = pc_plus_imm;
      if (condition)
        next_pc_o = pc_plus_imm;
      else
        next_pc_o = pc_plus_4;
    end

    target_misaligned_o = condition && (next_pc_o[1:0] != 2'b00);
    mispredict_o = (next_pc_o != predicted_next_pc_i);
  end
endmodule
