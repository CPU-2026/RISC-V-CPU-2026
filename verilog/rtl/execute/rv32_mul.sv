module rv32_mul (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   in_valid_i,
  output logic                   in_ready_o,
  input  rv32_pkg::operation_e   op_i,
  input  logic [31:0]            lhs_i,
  input  logic [31:0]            rhs_i,
  input  rv32_pkg::rob_tag_t     rob_tag_i,
  input  rv32_pkg::phy_tag_t     dest_phy_i,

  output logic                   out_valid_o,
  input  logic                   out_ready_i,
  output logic [31:0]            result_o,
  output rv32_pkg::rob_tag_t     rob_tag_o,
  output rv32_pkg::phy_tag_t     dest_phy_o
);
  import rv32_pkg::*;

  localparam int unsigned PRODUCT_W = 64;

  logic [2:0] valid_q;
  logic [PRODUCT_W-1:0] booth_rows_q [0:5];
  logic [PRODUCT_W-1:0] csa_sum_q, csa_carry_q;
  logic [31:0] result_q;
  logic high_q [0:1];
  rob_tag_t tag_q [0:2];
  phy_tag_t phy_q [0:2];
  logic ready_2, ready_1, ready_0;

  logic lhs_signed, rhs_signed;
  logic [PRODUCT_W-1:0] booth_multiplicand;
  logic [34:0] booth_multiplier;
  logic [PRODUCT_W-1:0] booth_rows [0:17];
  logic [PRODUCT_W-1:0] booth_correction;
  logic [PRODUCT_W-1:0] compress_l1 [0:11];
  logic [PRODUCT_W-1:0] compress_l2 [0:7];
  logic [PRODUCT_W-1:0] compress_l3 [0:5];

  logic [PRODUCT_W-1:0] csa_l1 [0:3];
  logic [PRODUCT_W-1:0] csa_l2 [0:2];
  logic [PRODUCT_W-1:0] csa_sum_d, csa_carry_d;
  logic [PRODUCT_W-1:0] final_product;
  logic final_carry_unused;

  integer booth_i;
  integer compress_i;
  integer csa_i;
  integer seq_i;

  // Stage 1: radix-4 Booth recoding followed by three CSA levels. Negative
  // digits use one's-complement rows plus a shared correction row, avoiding a
  // carry-propagate negation for every partial product.
  always_comb begin
    lhs_signed = (op_i == OP_MULH) || (op_i == OP_MULHSU);
    rhs_signed = (op_i == OP_MULH);
    booth_multiplicand = lhs_signed ? {{32{lhs_i[31]}}, lhs_i} :
                                        {32'b0, lhs_i};
    booth_multiplier = rhs_signed ? {{2{rhs_i[31]}}, rhs_i, 1'b0} :
                                      {2'b0, rhs_i, 1'b0};

    booth_correction = '0;
    for (booth_i = 0; booth_i < 17; booth_i = booth_i + 1) begin
      unique case (booth_multiplier[2*booth_i +: 3])
        3'b001, 3'b010: begin
          booth_rows[booth_i] = booth_multiplicand << (2*booth_i);
        end
        3'b011: begin
          booth_rows[booth_i] = booth_multiplicand << (2*booth_i + 1);
        end
        3'b100: begin
          booth_rows[booth_i] = (~booth_multiplicand) << (2*booth_i + 1);
          booth_correction[2*booth_i + 1] = 1'b1;
        end
        3'b101, 3'b110: begin
          booth_rows[booth_i] = (~booth_multiplicand) << (2*booth_i);
          booth_correction[2*booth_i] = 1'b1;
        end
        default: begin
          booth_rows[booth_i] = '0;
        end
      endcase
    end
    booth_rows[17] = booth_correction;

    for (compress_i = 0; compress_i < 6; compress_i = compress_i + 1) begin
      compress_l1[2*compress_i] = booth_rows[3*compress_i] ^
                                  booth_rows[3*compress_i+1] ^
                                  booth_rows[3*compress_i+2];
      compress_l1[2*compress_i+1] =
          ((booth_rows[3*compress_i] & booth_rows[3*compress_i+1]) |
           (booth_rows[3*compress_i] & booth_rows[3*compress_i+2]) |
           (booth_rows[3*compress_i+1] & booth_rows[3*compress_i+2])) << 1;
    end
    for (compress_i = 0; compress_i < 4; compress_i = compress_i + 1) begin
      compress_l2[2*compress_i] = compress_l1[3*compress_i] ^
                                  compress_l1[3*compress_i+1] ^
                                  compress_l1[3*compress_i+2];
      compress_l2[2*compress_i+1] =
          ((compress_l1[3*compress_i] & compress_l1[3*compress_i+1]) |
           (compress_l1[3*compress_i] & compress_l1[3*compress_i+2]) |
           (compress_l1[3*compress_i+1] & compress_l1[3*compress_i+2])) << 1;
    end
    for (compress_i = 0; compress_i < 2; compress_i = compress_i + 1) begin
      compress_l3[2*compress_i] = compress_l2[3*compress_i] ^
                                  compress_l2[3*compress_i+1] ^
                                  compress_l2[3*compress_i+2];
      compress_l3[2*compress_i+1] =
          ((compress_l2[3*compress_i] & compress_l2[3*compress_i+1]) |
           (compress_l2[3*compress_i] & compress_l2[3*compress_i+2]) |
           (compress_l2[3*compress_i+1] & compress_l2[3*compress_i+2])) << 1;
    end
    compress_l3[4] = compress_l2[6];
    compress_l3[5] = compress_l2[7];
  end

  // Stage 2: finish the carry-save tree, leaving only two 64-bit rows.
  always_comb begin
    for (csa_i = 0; csa_i < 2; csa_i = csa_i + 1) begin
      csa_l1[2*csa_i] = booth_rows_q[3*csa_i] ^
                         booth_rows_q[3*csa_i+1] ^
                         booth_rows_q[3*csa_i+2];
      csa_l1[2*csa_i+1] =
          ((booth_rows_q[3*csa_i] & booth_rows_q[3*csa_i+1]) |
           (booth_rows_q[3*csa_i] & booth_rows_q[3*csa_i+2]) |
           (booth_rows_q[3*csa_i+1] & booth_rows_q[3*csa_i+2])) << 1;
    end
    csa_l2[0] = csa_l1[0] ^ csa_l1[1] ^ csa_l1[2];
    csa_l2[1] = ((csa_l1[0] & csa_l1[1]) |
                 (csa_l1[0] & csa_l1[2]) |
                 (csa_l1[1] & csa_l1[2])) << 1;
    csa_l2[2] = csa_l1[3];
    csa_sum_d = csa_l2[0] ^ csa_l2[1] ^ csa_l2[2];
    csa_carry_d = ((csa_l2[0] & csa_l2[1]) |
                   (csa_l2[0] & csa_l2[2]) |
                   (csa_l2[1] & csa_l2[2])) << 1;
  end

  // Stage 3: the only carry-propagate addition in the multiplier.
  rv32_add #(.WIDTH(PRODUCT_W)) u_final_add (
    .a_i(csa_sum_q),
    .b_i(csa_carry_q),
    .cin_i(1'b0),
    .sum_o(final_product),
    .cout_o(final_carry_unused)
  );

  always_comb begin
    ready_2 = !valid_q[2] || out_ready_i;
    ready_1 = !valid_q[1] || ready_2;
    ready_0 = !valid_q[0] || ready_1;
    in_ready_o = ready_0;
    out_valid_o = valid_q[2];
    result_o = result_q;
    rob_tag_o = tag_q[2];
    dest_phy_o = phy_q[2];
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= '0;
      for (seq_i = 0; seq_i < 6; seq_i = seq_i + 1)
        booth_rows_q[seq_i] <= '0;
      csa_sum_q <= '0;
      csa_carry_q <= '0;
      result_q <= '0;
      high_q[0] <= 1'b0;
      high_q[1] <= 1'b0;
      for (seq_i = 0; seq_i < 3; seq_i = seq_i + 1) begin
        tag_q[seq_i] <= '0;
        phy_q[seq_i] <= '0;
      end
    end else if (flush_i) begin
      // The old output is consumed in the flush cycle. Older work advances
      // while equal or younger operations are discarded.
      valid_q[2] <= valid_q[1] && rob_is_older(tag_q[1], flush_tag_i);
      if (valid_q[1] && rob_is_older(tag_q[1], flush_tag_i)) begin
        result_q <= high_q[1] ? final_product[63:32] : final_product[31:0];
        tag_q[2] <= tag_q[1];
        phy_q[2] <= phy_q[1];
      end
      valid_q[1] <= valid_q[0] && rob_is_older(tag_q[0], flush_tag_i);
      if (valid_q[0] && rob_is_older(tag_q[0], flush_tag_i)) begin
        csa_sum_q <= csa_sum_d;
        csa_carry_q <= csa_carry_d;
        high_q[1] <= high_q[0];
        tag_q[1] <= tag_q[0];
        phy_q[1] <= phy_q[0];
      end
      valid_q[0] <= 1'b0;
    end else begin
      if (ready_2) begin
        valid_q[2] <= valid_q[1];
        if (valid_q[1]) begin
          result_q <= high_q[1] ? final_product[63:32] : final_product[31:0];
          tag_q[2] <= tag_q[1];
          phy_q[2] <= phy_q[1];
        end
      end
      if (ready_1) begin
        valid_q[1] <= valid_q[0];
        if (valid_q[0]) begin
          csa_sum_q <= csa_sum_d;
          csa_carry_q <= csa_carry_d;
          high_q[1] <= high_q[0];
          tag_q[1] <= tag_q[0];
          phy_q[1] <= phy_q[0];
        end
      end
      if (ready_0) begin
        valid_q[0] <= in_valid_i;
        if (in_valid_i) begin
          for (seq_i = 0; seq_i < 6; seq_i = seq_i + 1)
            booth_rows_q[seq_i] <= compress_l3[seq_i];
          high_q[0] <= (op_i != OP_MUL);
          tag_q[0] <= rob_tag_i;
          phy_q[0] <= dest_phy_i;
        end
      end
    end
  end
endmodule
