module rv32_alu_unit (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   in_valid_i,
  output logic                   in_ready_o,
  input  rv32_pkg::operation_e   op_i,
  input  logic [31:0]            lhs_i,
  input  logic [31:0]            rhs_i,
  input  logic [31:0]            imm_i,
  input  logic [31:0]            pc_i,
  input  logic                   use_imm_i,
  input  rv32_pkg::rob_tag_t     rob_tag_i,
  input  rv32_pkg::phy_tag_t     dest_phy_i,
  input  logic                   is_control_i,

  output logic                   out_valid_o,
  input  logic                   out_ready_i,
  output logic [31:0]            result_o,
  output rv32_pkg::rob_tag_t     rob_tag_o,
  output rv32_pkg::phy_tag_t     dest_phy_o,
  output logic                   is_control_o,
  output logic                   control_misaligned_o
);
  import rv32_pkg::*;

  logic [31:0] alu_result;
  logic valid_q;
  logic [31:0] result_q;
  rob_tag_t tag_q;
  phy_tag_t phy_q;
  logic control_q, control_misaligned_q;

  rv32_alu u_alu (
    .op_i(op_i), .lhs_i(lhs_i), .rhs_i(rhs_i), .imm_i(imm_i),
    .pc_i(pc_i), .use_imm_i(use_imm_i), .result_o(alu_result)
  );

  always_comb begin
    in_ready_o = !valid_q || out_ready_i;
    out_valid_o = valid_q;
    result_o = result_q;
    rob_tag_o = tag_q;
    dest_phy_o = phy_q;
    is_control_o = control_q;
    control_misaligned_o = control_misaligned_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= 1'b0;
      result_q <= '0;
      tag_q <= '0;
      phy_q <= '0;
      control_q <= 1'b0;
      control_misaligned_q <= 1'b0;
    end else if (flush_i) begin
      // Strictly older results broadcast in this cycle; equal/younger results
      // are killed. Either way this single output slot is consumed once.
      valid_q <= 1'b0;
    end else if (in_ready_o) begin
      valid_q <= in_valid_i;
      if (in_valid_i) begin
        result_q <= alu_result;
        tag_q <= rob_tag_i;
        phy_q <= dest_phy_i;
        control_q <= is_control_i;
        control_misaligned_q <= is_control_i && (alu_result[1:0] != 2'b00);
      end
    end
  end
endmodule
