module rv32_agu (
  input  logic [31:0] base_i,
  input  logic [31:0] offset_i,
  output logic [31:0] address_o
);
  logic unused_cout;

  rv32_add #(.WIDTH(32)) u_add (
    .a_i(base_i), .b_i(offset_i), .cin_i(1'b0),
    .sum_o(address_o), .cout_o(unused_cout)
  );
endmodule
