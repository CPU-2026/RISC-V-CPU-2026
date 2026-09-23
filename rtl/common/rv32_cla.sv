/* verilator lint_off DECLFILENAME */

module rv32_cla2 (
  input  logic [1:0] a_i,
  input  logic [1:0] b_i,
  input  logic       cin_i,
  output logic [1:0] sum_o,
  output logic       cout_o
);
  logic [1:0] p, g, c;

  assign p = a_i ^ b_i;
  assign g = a_i & b_i;
  assign c = {g[0] | (p[0] & cin_i), cin_i};
  assign sum_o = p ^ c;
  assign cout_o = g[1] | (p[1] & c[1]);
endmodule

module rv32_cla4 (
  input  logic [3:0] a_i,
  input  logic [3:0] b_i,
  input  logic       cin_i,
  output logic [3:0] sum_o,
  output logic       cout_o,
  output logic       pg_o,
  output logic       gg_o
);
  logic [3:0] p, g, c;

  assign p = a_i ^ b_i;
  assign g = a_i & b_i;
  assign c = {
    g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) |
      (p[2] & p[1] & p[0] & cin_i),
    g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin_i),
    g[0] | (p[0] & cin_i),
    cin_i
  };
  assign pg_o = p[3] & p[2] & p[1] & p[0];
  assign gg_o = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) |
                (p[3] & p[2] & p[1] & g[0]);
  assign sum_o = p ^ c;
  assign cout_o = gg_o | (pg_o & cin_i);
endmodule

module rv32_cla8 (
  input  logic [7:0] a_i,
  input  logic [7:0] b_i,
  input  logic       cin_i,
  output logic [7:0] sum_o,
  output logic       cout_o,
  output logic       pg_o,
  output logic       gg_o
);
  logic pg_lo, pg_hi, gg_lo, gg_hi;
  logic [3:0] sum_lo, sum_hi;
  logic cout_lo, cout_hi;
  logic carry4;

  assign carry4 = gg_lo | (pg_lo & cin_i);

  rv32_cla4 u_low (
    .a_i(a_i[3:0]), .b_i(b_i[3:0]), .cin_i(cin_i),
    .sum_o(sum_lo), .cout_o(cout_lo), .pg_o(pg_lo), .gg_o(gg_lo)
  );
  rv32_cla4 u_high (
    .a_i(a_i[7:4]), .b_i(b_i[7:4]), .cin_i(carry4),
    .sum_o(sum_hi), .cout_o(cout_hi), .pg_o(pg_hi), .gg_o(gg_hi)
  );

  assign sum_o = {sum_hi, sum_lo};
  assign pg_o = pg_hi & pg_lo;
  assign gg_o = gg_hi | (pg_hi & gg_lo);
  assign cout_o = gg_o | (pg_o & cin_i);
endmodule

module rv32_cla16 (
  input  logic [15:0] a_i,
  input  logic [15:0] b_i,
  input  logic        cin_i,
  output logic [15:0] sum_o,
  output logic        cout_o,
  output logic        pg_o,
  output logic        gg_o
);
  logic [3:0] pg_block, gg_block;
  logic [3:0] cout_block;
  logic [4:0] carry;

  assign carry = {
    gg_block[3] | (pg_block[3] & gg_block[2]) |
      (pg_block[3] & pg_block[2] & gg_block[1]) |
      (pg_block[3] & pg_block[2] & pg_block[1] & gg_block[0]) |
      (pg_block[3] & pg_block[2] & pg_block[1] & pg_block[0] & cin_i),
    gg_block[2] | (pg_block[2] & gg_block[1]) |
      (pg_block[2] & pg_block[1] & gg_block[0]) |
      (pg_block[2] & pg_block[1] & pg_block[0] & cin_i),
    gg_block[1] | (pg_block[1] & gg_block[0]) |
      (pg_block[1] & pg_block[0] & cin_i),
    gg_block[0] | (pg_block[0] & cin_i),
    cin_i
  };
  assign pg_o = pg_block[3] & pg_block[2] & pg_block[1] & pg_block[0];
  assign gg_o = gg_block[3] | (pg_block[3] & gg_block[2]) |
                (pg_block[3] & pg_block[2] & gg_block[1]) |
                (pg_block[3] & pg_block[2] & pg_block[1] & gg_block[0]);
  assign cout_o = carry[4];

  genvar block;
  generate
    for (block = 0; block < 4; block = block + 1) begin : g_blocks
      rv32_cla4 u_block (
        .a_i(a_i[4*block +: 4]), .b_i(b_i[4*block +: 4]),
        .cin_i(carry[block]), .sum_o(sum_o[4*block +: 4]),
        .cout_o(cout_block[block]),
        .pg_o(pg_block[block]), .gg_o(gg_block[block])
      );
    end
  endgenerate
endmodule

module rv32_cla32 (
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  logic        cin_i,
  output logic [31:0] sum_o,
  output logic        cout_o,
  output logic        pg_o,
  output logic        gg_o
);
  logic pg_lo, pg_hi, gg_lo, gg_hi;
  logic [15:0] sum_lo, sum_hi;
  logic cout_lo, cout_hi;
  logic carry16;

  assign carry16 = gg_lo | (pg_lo & cin_i);

  rv32_cla16 u_low (
    .a_i(a_i[15:0]), .b_i(b_i[15:0]), .cin_i(cin_i),
    .sum_o(sum_lo), .cout_o(cout_lo), .pg_o(pg_lo), .gg_o(gg_lo)
  );
  rv32_cla16 u_high (
    .a_i(a_i[31:16]), .b_i(b_i[31:16]), .cin_i(carry16),
    .sum_o(sum_hi), .cout_o(cout_hi), .pg_o(pg_hi), .gg_o(gg_hi)
  );

  assign sum_o = {sum_hi, sum_lo};
  assign pg_o = pg_hi & pg_lo;
  assign gg_o = gg_hi | (pg_hi & gg_lo);
  assign cout_o = gg_o | (pg_o & cin_i);
endmodule

module rv32_cla64 (
  input  logic [63:0] a_i,
  input  logic [63:0] b_i,
  input  logic        cin_i,
  output logic [63:0] sum_o,
  output logic        cout_o
);
  logic pg_lo, pg_hi, gg_lo, gg_hi;
  logic [31:0] sum_lo, sum_hi;
  logic cout_lo, cout_hi;
  logic carry32;

  assign carry32 = gg_lo | (pg_lo & cin_i);

  rv32_cla32 u_low (
    .a_i(a_i[31:0]), .b_i(b_i[31:0]), .cin_i(cin_i),
    .sum_o(sum_lo), .cout_o(cout_lo), .pg_o(pg_lo), .gg_o(gg_lo)
  );
  rv32_cla32 u_high (
    .a_i(a_i[63:32]), .b_i(b_i[63:32]), .cin_i(carry32),
    .sum_o(sum_hi), .cout_o(cout_hi), .pg_o(pg_hi), .gg_o(gg_hi)
  );

  assign sum_o = {sum_hi, sum_lo};
  assign cout_o = gg_hi | (pg_hi & carry32);
endmodule

module rv32_add #(
  parameter int unsigned WIDTH = 32
) (
  input  logic [WIDTH-1:0] a_i,
  input  logic [WIDTH-1:0] b_i,
  input  logic             cin_i,
  output logic [WIDTH-1:0] sum_o,
  output logic             cout_o
);
  localparam int unsigned CLA_WIDTH = (WIDTH <= 2) ? 2 :
                                      (WIDTH <= 4) ? 4 :
                                      (WIDTH <= 8) ? 8 :
                                      (WIDTH <= 16) ? 16 :
                                      (WIDTH <= 32) ? 32 : 64;

  logic [CLA_WIDTH-1:0] a_ext, b_ext, sum_ext;
  logic cout_ext;
  logic unused_pg, unused_gg;

  assign sum_o = sum_ext[WIDTH-1:0];

  generate
    if (CLA_WIDTH == WIDTH) begin : g_ext_native
      assign a_ext = a_i;
      assign b_ext = b_i;
    end else begin : g_ext_padded
      assign a_ext = {{(CLA_WIDTH-WIDTH){1'b0}}, a_i};
      assign b_ext = {{(CLA_WIDTH-WIDTH){1'b0}}, b_i};
    end
  endgenerate

  generate
    if (CLA_WIDTH == 2) begin : g_cla2
      rv32_cla2 u_cla (
        .a_i(a_ext), .b_i(b_ext), .cin_i(cin_i),
        .sum_o(sum_ext), .cout_o(cout_ext)
      );
    end else if (CLA_WIDTH == 4) begin : g_cla4
      rv32_cla4 u_cla (
        .a_i(a_ext), .b_i(b_ext), .cin_i(cin_i),
        .sum_o(sum_ext), .cout_o(cout_ext),
        .pg_o(unused_pg), .gg_o(unused_gg)
      );
    end else if (CLA_WIDTH == 8) begin : g_cla8
      rv32_cla8 u_cla (
        .a_i(a_ext), .b_i(b_ext), .cin_i(cin_i),
        .sum_o(sum_ext), .cout_o(cout_ext),
        .pg_o(unused_pg), .gg_o(unused_gg)
      );
    end else if (CLA_WIDTH == 16) begin : g_cla16
      rv32_cla16 u_cla (
        .a_i(a_ext), .b_i(b_ext), .cin_i(cin_i),
        .sum_o(sum_ext), .cout_o(cout_ext),
        .pg_o(unused_pg), .gg_o(unused_gg)
      );
    end else if (CLA_WIDTH == 32) begin : g_cla32
      rv32_cla32 u_cla (
        .a_i(a_ext), .b_i(b_ext), .cin_i(cin_i),
        .sum_o(sum_ext), .cout_o(cout_ext),
        .pg_o(unused_pg), .gg_o(unused_gg)
      );
    end else begin : g_cla64
      rv32_cla64 u_cla (
        .a_i(a_ext), .b_i(b_ext), .cin_i(cin_i),
        .sum_o(sum_ext), .cout_o(cout_ext)
      );
    end
  endgenerate

  generate
    if (CLA_WIDTH == WIDTH) begin : g_carry_native
      assign cout_o = cout_ext;
    end else begin : g_carry_extended
      assign cout_o = sum_ext[WIDTH];
    end
  endgenerate
endmodule

module rv32_sub #(
  parameter int unsigned WIDTH = 32
) (
  input  logic [WIDTH-1:0] a_i,
  input  logic [WIDTH-1:0] b_i,
  output logic [WIDTH-1:0] diff_o,
  output logic             borrow_o
);
  logic carry;

  rv32_add #(.WIDTH(WIDTH)) u_add (
    .a_i(a_i), .b_i(~b_i), .cin_i(1'b1),
    .sum_o(diff_o), .cout_o(carry)
  );

  assign borrow_o = ~carry;
endmodule

/* verilator lint_on DECLFILENAME */
