module rv32_div #(
  parameter bit USE_SRT4 = 1'b0
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   in_valid_i,
  output logic                   in_ready_o,
  input  rv32_pkg::operation_e   op_i,
  input  logic [31:0]            dividend_i,
  input  logic [31:0]            divisor_i,
  input  rv32_pkg::rob_tag_t     rob_tag_i,
  input  rv32_pkg::phy_tag_t     dest_phy_i,

  output logic                   out_valid_o,
  input  logic                   out_ready_i,
  output logic [31:0]            result_o,
  output rv32_pkg::rob_tag_t     rob_tag_o,
  output rv32_pkg::phy_tag_t     dest_phy_o
);
  generate
    if (USE_SRT4) begin : g_srt4
      rv32_div_srt4 u_impl (.*);
    end else begin : g_radix2
      rv32_div_radix2 u_impl (.*);
    end
  endgenerate
endmodule

/* verilator lint_off DECLFILENAME */
// Original 32-iteration restoring implementation, retained as the A/B
// baseline for the SRT radix-4 implementation below.
module rv32_div_radix2 (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   in_valid_i,
  output logic                   in_ready_o,
  input  rv32_pkg::operation_e   op_i,
  input  logic [31:0]            dividend_i,
  input  logic [31:0]            divisor_i,
  input  rv32_pkg::rob_tag_t     rob_tag_i,
  input  rv32_pkg::phy_tag_t     dest_phy_i,

  output logic                   out_valid_o,
  input  logic                   out_ready_i,
  output logic [31:0]            result_o,
  output rv32_pkg::rob_tag_t     rob_tag_o,
  output rv32_pkg::phy_tag_t     dest_phy_o
);
  import rv32_pkg::*;

  logic busy_q;
  logic [5:0] count_q;
  logic [31:0] dividend_q;
  logic [31:0] divisor_q;
  logic [32:0] remainder_q;
  logic [31:0] quotient_q;
  logic quotient_negative_q;
  logic remainder_negative_q;
  logic want_remainder_q;
  rob_tag_t active_tag_q;
  phy_tag_t active_phy_q;

  logic result_valid_q;
  logic [31:0] result_q;
  rob_tag_t result_tag_q;
  phy_tag_t result_phy_q;

  logic signed_op;
  logic want_remainder;
  logic [31:0] dividend_abs;
  logic [31:0] divisor_abs;
  logic [32:0] shifted_remainder;
  logic [32:0] divisor_ext;
  logic [32:0] remainder_diff;
  logic [32:0] next_remainder;
  logic [31:0] next_quotient;
  logic [31:0] unsigned_final;
  logic [31:0] signed_final;
  logic remainder_ge;
  logic [31:0] dividend_neg, divisor_neg, final_neg;
  logic [5:0] count_next;
  logic unused_borrow_remainder, unused_borrow_dividend, unused_borrow_divisor;
  logic unused_borrow_final, unused_cout_count;

  assign signed_op = (op_i == OP_DIV) || (op_i == OP_REM);
  assign want_remainder = (op_i == OP_REM) || (op_i == OP_REMU);

  rv32_sub #(.WIDTH(32)) u_dividend_neg (
    .a_i(32'b0), .b_i(dividend_i),
    .diff_o(dividend_neg), .borrow_o(unused_borrow_dividend)
  );

  rv32_sub #(.WIDTH(32)) u_divisor_neg (
    .a_i(32'b0), .b_i(divisor_i),
    .diff_o(divisor_neg), .borrow_o(unused_borrow_divisor)
  );

  assign dividend_abs = (signed_op && dividend_i[31]) ?
                        dividend_neg : dividend_i;
  assign divisor_abs = (signed_op && divisor_i[31]) ?
                       divisor_neg : divisor_i;

  assign shifted_remainder = {remainder_q[31:0], dividend_q[31]};
  assign divisor_ext = {1'b0, divisor_q};
  assign remainder_ge = (shifted_remainder >= divisor_ext);

  rv32_sub #(.WIDTH(33)) u_remainder_diff (
    .a_i(shifted_remainder), .b_i(divisor_ext),
    .diff_o(remainder_diff), .borrow_o(unused_borrow_remainder)
  );

  assign next_remainder = remainder_ge ? remainder_diff : shifted_remainder;
  assign next_quotient = remainder_ge ?
                         {quotient_q[30:0], 1'b1} :
                         {quotient_q[30:0], 1'b0};
  assign unsigned_final = want_remainder_q ? next_remainder[31:0] :
                                             next_quotient;

  rv32_sub #(.WIDTH(32)) u_final_neg (
    .a_i(32'b0), .b_i(unsigned_final),
    .diff_o(final_neg), .borrow_o(unused_borrow_final)
  );

  assign signed_final =
    ((want_remainder_q && remainder_negative_q) ||
     (!want_remainder_q && quotient_negative_q)) ? final_neg : unsigned_final;

  rv32_add #(.WIDTH(6)) u_count_next (
    .a_i(count_q), .b_i(6'd1), .cin_i(1'b0),
    .sum_o(count_next), .cout_o(unused_cout_count)
  );

  always_comb begin
    in_ready_o = !busy_q && (!result_valid_q || out_ready_i);
    out_valid_o = result_valid_q;
    result_o = result_q;
    rob_tag_o = result_tag_q;
    dest_phy_o = result_phy_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q <= 1'b0;
      count_q <= '0;
      dividend_q <= '0;
      divisor_q <= '0;
      remainder_q <= '0;
      quotient_q <= '0;
      quotient_negative_q <= 1'b0;
      remainder_negative_q <= 1'b0;
      want_remainder_q <= 1'b0;
      active_tag_q <= '0;
      active_phy_q <= '0;
      result_valid_q <= 1'b0;
      result_q <= '0;
      result_tag_q <= '0;
      result_phy_q <= '0;
    end else begin
      if (flush_i && busy_q &&
          !rob_is_older(active_tag_q, flush_tag_i)) begin
        busy_q <= 1'b0;
      end else if (flush_i && result_valid_q) begin
        result_valid_q <= 1'b0;
      end else begin
        if (result_valid_q && out_ready_i)
          result_valid_q <= 1'b0;

        if (in_valid_i && in_ready_o) begin
          active_tag_q <= rob_tag_i;
          active_phy_q <= dest_phy_i;
          want_remainder_q <= want_remainder;
          quotient_negative_q <= signed_op &&
                                 (dividend_i[31] ^ divisor_i[31]);
          remainder_negative_q <= signed_op && dividend_i[31];

          if (divisor_i == 32'b0) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? dividend_i : 32'hffff_ffff;
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else if (signed_op && (dividend_i == 32'h8000_0000) &&
                       (divisor_i == 32'hffff_ffff)) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? 32'b0 : 32'h8000_0000;
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else if (dividend_abs < divisor_abs) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? dividend_i : 32'b0;
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else if (dividend_abs == divisor_abs) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? 32'b0 :
                        ((signed_op && (dividend_i[31] ^ divisor_i[31])) ?
                         32'hffff_ffff : 32'd1);
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else begin
            busy_q <= 1'b1;
            count_q <= 6'd0;
            dividend_q <= dividend_abs;
            divisor_q <= divisor_abs;
            remainder_q <= 33'b0;
            quotient_q <= 32'b0;
          end
        end else if (busy_q) begin
          dividend_q <= {dividend_q[30:0], 1'b0};
          remainder_q <= next_remainder;
          quotient_q <= next_quotient;
          if (count_q == 6'd31) begin
            busy_q <= 1'b0;
            result_valid_q <= 1'b1;
            result_q <= signed_final;
            result_tag_q <= active_tag_q;
            result_phy_q <= active_phy_q;
          end else begin
            count_q <= count_next;
          end
        end
      end
    end
  end
endmodule

// Radix-4 SRT divider translated from the C++ reference DIV module. It uses
// carry-save partial remainders and redundant A/B quotient conversion, so each
// loop consumes two quotient bits without using a combinational divide.
module rv32_div_srt4 (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   in_valid_i,
  output logic                   in_ready_o,
  input  rv32_pkg::operation_e   op_i,
  input  logic [31:0]            dividend_i,
  input  logic [31:0]            divisor_i,
  input  rv32_pkg::rob_tag_t     rob_tag_i,
  input  rv32_pkg::phy_tag_t     dest_phy_i,

  output logic                   out_valid_o,
  input  logic                   out_ready_i,
  output logic [31:0]            result_o,
  output rv32_pkg::rob_tag_t     rob_tag_o,
  output rv32_pkg::phy_tag_t     dest_phy_o
);
  import rv32_pkg::*;

  typedef enum logic [1:0] {PH_PREP, PH_LOOP, PH_FINISH} phase_e;

  logic busy_q;
  phase_e phase_q;
  logic [5:0] loop_count_q;
  logic [31:0] dividend_mag_q, divisor_mag_q;
  logic [35:0] divisor_dp_q;
  logic [5:0] clz_d_q;
  logic shift_d_q;
  logic [6:0] d_slice_q, d_slice3_q;
  logic [35:0] reg_s_q, reg_c_q, mask_q;
  logic [31:0] reg_a_q, reg_b_q;
  logic quotient_negative_q, remainder_negative_q, want_remainder_q;
  rob_tag_t active_tag_q;
  phy_tag_t active_phy_q;

  logic result_valid_q;
  logic [31:0] result_q;
  rob_tag_t result_tag_q;
  phy_tag_t result_phy_q;

  logic signed_op, want_remainder;
  logic [31:0] dividend_neg, divisor_neg;
  logic [31:0] dividend_abs, divisor_abs;
  logic unused_borrow_dividend, unused_borrow_divisor;

  logic [5:0] prep_clz_x, prep_clz_d, prep_align, prep_loop_count;
  logic prep_shift_d;
  logic [35:0] prep_mask, prep_dividend_norm, prep_divisor_norm, prep_divisor_dp;
  logic [6:0] prep_d_slice, prep_d_slice3, prep_slice;
  logic [35:0] prep_subtrahend, prep_s, prep_c;
  logic [31:0] prep_a, prep_b;

  logic [8:0] loop_sum9;
  logic signed [9:0] loop_slice, loop_d_slice, loop_d_slice3;
  logic [35:0] loop_s4, loop_c4, loop_subtrahend, loop_t, loop_s, loop_c;
  logic [31:0] loop_a, loop_b;

  logic [35:0] finish_pk, finish_corrected_pk;
  logic finish_negative;
  logic [31:0] finish_quotient, finish_remainder, finish_unsigned;
  logic [31:0] finish_negated, finish_signed;

  function automatic logic [5:0] clz32(input logic [31:0] value);
    integer index;
    logic seen_one;
    begin
      clz32 = 6'd32;
      seen_one = 1'b0;
      for (index = 31; index >= 0; index = index - 1) begin
        if (!seen_one && value[index]) begin
          clz32 = 31 - index;
          seen_one = 1'b1;
        end
      end
    end
  endfunction

  assign signed_op = (op_i == OP_DIV) || (op_i == OP_REM);
  assign want_remainder = (op_i == OP_REM) || (op_i == OP_REMU);

  rv32_sub #(.WIDTH(32)) u_dividend_neg (
    .a_i(32'b0), .b_i(dividend_i),
    .diff_o(dividend_neg), .borrow_o(unused_borrow_dividend)
  );
  rv32_sub #(.WIDTH(32)) u_divisor_neg (
    .a_i(32'b0), .b_i(divisor_i),
    .diff_o(divisor_neg), .borrow_o(unused_borrow_divisor)
  );
  assign dividend_abs = (signed_op && dividend_i[31]) ? dividend_neg : dividend_i;
  assign divisor_abs = (signed_op && divisor_i[31]) ? divisor_neg : divisor_i;

  always_comb begin
    prep_clz_x = clz32(dividend_mag_q);
    prep_clz_d = clz32(divisor_mag_q);
    prep_align = prep_clz_d - prep_clz_x;
    prep_loop_count = (prep_align + 6'd1) >> 1;
    prep_shift_d = prep_align[0];
    prep_mask = prep_shift_d ? 36'hf_ffffffff : 36'h7_ffffffff;
    prep_dividend_norm = ({4'b0, dividend_mag_q} << prep_clz_x) & prep_mask;
    prep_divisor_norm = ({4'b0, divisor_mag_q} << prep_clz_d) & prep_mask;
    prep_divisor_dp = (prep_divisor_norm << prep_shift_d) & prep_mask;
    prep_d_slice = prep_shift_d ? {2'b0, prep_divisor_dp[32:28]} :
                                 {2'b0, prep_divisor_dp[31:27]};
    prep_d_slice3 = prep_d_slice + (prep_d_slice << 1);
    prep_slice = prep_shift_d ? (prep_dividend_norm >> 27) :
                                (prep_dividend_norm >> 26);

    prep_subtrahend = '0;
    prep_s = '0;
    prep_c = '0;
    prep_a = '0;
    prep_b = '0;
    if (prep_slice >= prep_d_slice3) begin
      prep_subtrahend = (prep_divisor_dp << 1) & prep_mask;
      prep_s = ((prep_dividend_norm ^ ~prep_subtrahend ^ 36'd1) << 2) & prep_mask;
      prep_c = (((prep_dividend_norm & ~prep_subtrahend) |
                 (prep_dividend_norm & 36'd1) |
                 (~prep_subtrahend & 36'd1)) << 3) & prep_mask;
      prep_a = 32'd2;
      prep_b = 32'd1;
    end else if (prep_slice >= prep_d_slice) begin
      prep_subtrahend = prep_divisor_dp;
      prep_s = ((prep_dividend_norm ^ ~prep_subtrahend ^ 36'd1) << 2) & prep_mask;
      prep_c = (((prep_dividend_norm & ~prep_subtrahend) |
                 (prep_dividend_norm & 36'd1) |
                 (~prep_subtrahend & 36'd1)) << 3) & prep_mask;
      prep_a = 32'd1;
      prep_b = 32'd0;
    end else begin
      prep_s = (prep_dividend_norm << 2) & prep_mask;
      prep_c = '0;
      prep_a = 32'd0;
      prep_b = 32'd3;
    end
  end

  always_comb begin
    if (shift_d_q)
      loop_sum9 = reg_s_q[35:27] + reg_c_q[35:27];
    else
      loop_sum9 = reg_s_q[34:26] + reg_c_q[34:26];
    loop_slice = {loop_sum9[8], loop_sum9};
    loop_slice[0] = 1'b0;
    loop_d_slice = $signed({3'b000, d_slice_q});
    loop_d_slice3 = $signed({3'b000, d_slice3_q});
    loop_s4 = (reg_s_q << 2) & mask_q;
    loop_c4 = (reg_c_q << 2) & mask_q;

    loop_subtrahend = '0;
    loop_t = '0;
    loop_s = '0;
    loop_c = '0;
    loop_a = '0;
    loop_b = '0;
    if (loop_slice >= loop_d_slice3) begin
      loop_subtrahend = (divisor_dp_q << 3) & mask_q;
      loop_t = mask_q ^ loop_subtrahend;
      loop_s = (loop_s4 ^ loop_c4 ^ loop_t) & mask_q;
      loop_c = ((((loop_s4 & loop_c4) | (loop_s4 & loop_t) |
                  (loop_c4 & loop_t)) << 1) | 36'd1) & mask_q;
      loop_a = (reg_a_q << 2) | 32'd2;
      loop_b = (reg_a_q << 2) | 32'd1;
    end else if (loop_slice >= loop_d_slice) begin
      loop_subtrahend = (divisor_dp_q << 2) & mask_q;
      loop_t = mask_q ^ loop_subtrahend;
      loop_s = (loop_s4 ^ loop_c4 ^ loop_t) & mask_q;
      loop_c = ((((loop_s4 & loop_c4) | (loop_s4 & loop_t) |
                  (loop_c4 & loop_t)) << 1) | 36'd1) & mask_q;
      loop_a = (reg_a_q << 2) | 32'd1;
      loop_b = reg_a_q << 2;
    end else if (loop_slice >= -loop_d_slice) begin
      loop_s = (loop_s4 ^ loop_c4) & mask_q;
      loop_c = ((loop_s4 & loop_c4) << 1) & mask_q;
      loop_a = reg_a_q << 2;
      loop_b = (reg_b_q << 2) | 32'd3;
    end else if (loop_slice >= -loop_d_slice3) begin
      loop_subtrahend = (divisor_dp_q << 2) & mask_q;
      loop_s = (loop_s4 ^ loop_c4 ^ loop_subtrahend) & mask_q;
      loop_c = (((loop_s4 & loop_c4) | (loop_s4 & loop_subtrahend) |
                 (loop_c4 & loop_subtrahend)) << 1) & mask_q;
      loop_a = (reg_b_q << 2) | 32'd3;
      loop_b = (reg_b_q << 2) | 32'd2;
    end else begin
      loop_subtrahend = (divisor_dp_q << 3) & mask_q;
      loop_s = (loop_s4 ^ loop_c4 ^ loop_subtrahend) & mask_q;
      loop_c = (((loop_s4 & loop_c4) | (loop_s4 & loop_subtrahend) |
                 (loop_c4 & loop_subtrahend)) << 1) & mask_q;
      loop_a = (reg_b_q << 2) | 32'd2;
      loop_b = (reg_b_q << 2) | 32'd1;
    end
  end

  always_comb begin
    finish_pk = (reg_s_q + reg_c_q) & mask_q;
    finish_negative = shift_d_q ? finish_pk[35] : finish_pk[34];
    finish_corrected_pk = finish_negative ?
                          ((finish_pk + (divisor_dp_q << 2)) & mask_q) : finish_pk;
    finish_quotient = finish_negative ? reg_b_q : reg_a_q;
    finish_remainder = (((finish_corrected_pk >> 2) >> shift_d_q) >> clz_d_q);
    finish_unsigned = want_remainder_q ? finish_remainder : finish_quotient;
    finish_negated = ~finish_unsigned + 32'd1;
    finish_signed =
      ((want_remainder_q && remainder_negative_q) ||
       (!want_remainder_q && quotient_negative_q)) ? finish_negated : finish_unsigned;
  end

  always_comb begin
    in_ready_o = !busy_q && (!result_valid_q || out_ready_i);
    out_valid_o = result_valid_q;
    result_o = result_q;
    rob_tag_o = result_tag_q;
    dest_phy_o = result_phy_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q <= 1'b0;
      phase_q <= PH_PREP;
      loop_count_q <= '0;
      dividend_mag_q <= '0;
      divisor_mag_q <= '0;
      divisor_dp_q <= '0;
      clz_d_q <= '0;
      shift_d_q <= 1'b0;
      d_slice_q <= '0;
      d_slice3_q <= '0;
      reg_s_q <= '0;
      reg_c_q <= '0;
      mask_q <= '0;
      reg_a_q <= '0;
      reg_b_q <= '0;
      quotient_negative_q <= 1'b0;
      remainder_negative_q <= 1'b0;
      want_remainder_q <= 1'b0;
      active_tag_q <= '0;
      active_phy_q <= '0;
      result_valid_q <= 1'b0;
      result_q <= '0;
      result_tag_q <= '0;
      result_phy_q <= '0;
    end else begin
      if (flush_i && busy_q && !rob_is_older(active_tag_q, flush_tag_i)) begin
        busy_q <= 1'b0;
      end else if (flush_i && result_valid_q) begin
        result_valid_q <= 1'b0;
      end else begin
        if (result_valid_q && out_ready_i)
          result_valid_q <= 1'b0;

        if (in_valid_i && in_ready_o) begin
          active_tag_q <= rob_tag_i;
          active_phy_q <= dest_phy_i;
          want_remainder_q <= want_remainder;
          quotient_negative_q <= signed_op && (dividend_i[31] ^ divisor_i[31]);
          remainder_negative_q <= signed_op && dividend_i[31];

          if (divisor_i == 32'b0) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? dividend_i : 32'hffff_ffff;
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else if (signed_op && (dividend_i == 32'h8000_0000) &&
                       (divisor_i == 32'hffff_ffff)) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? 32'b0 : 32'h8000_0000;
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else if (dividend_abs < divisor_abs) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? dividend_i : 32'b0;
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else if (dividend_abs == divisor_abs) begin
            result_valid_q <= 1'b1;
            result_q <= want_remainder ? 32'b0 :
                        ((signed_op && (dividend_i[31] ^ divisor_i[31])) ?
                         32'hffff_ffff : 32'd1);
            result_tag_q <= rob_tag_i;
            result_phy_q <= dest_phy_i;
            busy_q <= 1'b0;
          end else begin
            busy_q <= 1'b1;
            phase_q <= PH_PREP;
            dividend_mag_q <= dividend_abs;
            divisor_mag_q <= divisor_abs;
          end
        end else if (busy_q) begin
          unique case (phase_q)
            PH_PREP: begin
              loop_count_q <= prep_loop_count;
              divisor_dp_q <= prep_divisor_dp;
              clz_d_q <= prep_clz_d;
              shift_d_q <= prep_shift_d;
              d_slice_q <= prep_d_slice;
              d_slice3_q <= prep_d_slice3;
              reg_s_q <= prep_s;
              reg_c_q <= prep_c;
              mask_q <= prep_mask;
              reg_a_q <= prep_a;
              reg_b_q <= prep_b;
              phase_q <= (prep_loop_count == 6'd0) ? PH_FINISH : PH_LOOP;
            end
            PH_LOOP: begin
              reg_s_q <= loop_s;
              reg_c_q <= loop_c;
              reg_a_q <= loop_a;
              reg_b_q <= loop_b;
              if (loop_count_q == 6'd1) begin
                phase_q <= PH_FINISH;
              end else begin
                loop_count_q <= loop_count_q - 6'd1;
              end
            end
            default: begin
              busy_q <= 1'b0;
              result_valid_q <= 1'b1;
              result_q <= finish_signed;
              result_tag_q <= active_tag_q;
              result_phy_q <= active_phy_q;
            end
          endcase
        end
      end
    end
  end
endmodule
/* verilator lint_on DECLFILENAME */
