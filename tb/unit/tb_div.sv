`timescale 1ns/1ps

// Interface-level divider regression. The expected-value function is testbench
// only; synthesizable divider RTL never uses / or %.
module tb_div #(
  parameter bit USE_SRT4 = 1'b0
);
  import rv32_pkg::*;

  logic clk, rst_n;
  logic flush;
  rob_tag_t flush_tag;
  logic in_valid, in_ready;
  operation_e op;
  logic [31:0] dividend, divisor;
  rob_tag_t in_rob_tag, out_rob_tag;
  phy_tag_t in_phy_tag, out_phy_tag;
  logic out_valid, out_ready;
  logic [31:0] result;
  int unsigned case_id;

  rv32_div #(.USE_SRT4(USE_SRT4)) u_dut (
    .clk_i(clk), .rst_ni(rst_n), .flush_i(flush), .flush_tag_i(flush_tag),
    .in_valid_i(in_valid), .in_ready_o(in_ready), .op_i(op),
    .dividend_i(dividend), .divisor_i(divisor), .rob_tag_i(in_rob_tag),
    .dest_phy_i(in_phy_tag), .out_valid_o(out_valid), .out_ready_i(out_ready),
    .result_o(result), .rob_tag_o(out_rob_tag), .dest_phy_o(out_phy_tag)
  );

  always #5 clk = ~clk;

  function automatic logic [31:0] reference_result(
    input operation_e operation,
    input logic [31:0] numerator,
    input logic [31:0] denominator
  );
    logic signed [31:0] signed_numerator;
    logic signed [31:0] signed_denominator;
    begin
      signed_numerator = numerator;
      signed_denominator = denominator;
      if (denominator == 32'b0) begin
        reference_result = ((operation == OP_REM) || (operation == OP_REMU)) ?
                           numerator : 32'hffff_ffff;
      end else if ((operation == OP_DIV || operation == OP_REM) &&
                   (numerator == 32'h8000_0000) &&
                   (denominator == 32'hffff_ffff)) begin
        reference_result = (operation == OP_DIV) ? 32'h8000_0000 : 32'b0;
      end else begin
        unique case (operation)
          OP_DIV:  reference_result = signed_numerator / signed_denominator;
          OP_DIVU: reference_result = numerator / denominator;
          OP_REM:  reference_result = signed_numerator % signed_denominator;
          OP_REMU: reference_result = numerator % denominator;
          default: reference_result = 'x;
        endcase
      end
    end
  endfunction

  function automatic logic [31:0] lfsr_next(input logic [31:0] value);
    lfsr_next = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  task automatic check_case(
    input operation_e operation,
    input logic [31:0] numerator,
    input logic [31:0] denominator,
    input int unsigned stall_cycles
  );
    logic [31:0] expected;
    rob_tag_t expected_rob_tag;
    phy_tag_t expected_phy_tag;
    int unsigned wait_cycles;
    begin
      expected = reference_result(operation, numerator, denominator);
      expected_rob_tag = rob_tag_t'(case_id);
      expected_phy_tag = phy_tag_t'(case_id + 7);
      case_id = case_id + 1;

      while (!in_ready)
        @(negedge clk);
      op = operation;
      dividend = numerator;
      divisor = denominator;
      in_rob_tag = expected_rob_tag;
      in_phy_tag = expected_phy_tag;
      in_valid = 1'b1;
      @(negedge clk);
      in_valid = 1'b0;

      wait_cycles = 0;
      while (!out_valid) begin
        @(negedge clk);
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 40)
          $fatal(1, "divider timeout srt4=%0d op=%0d x=%08x d=%08x",
                 USE_SRT4, operation, numerator, denominator);
      end
      if ((result !== expected) || (out_rob_tag !== expected_rob_tag) ||
          (out_phy_tag !== expected_phy_tag)) begin
        $fatal(1, "divider mismatch srt4=%0d op=%0d x=%08x d=%08x got=%08x exp=%08x tag=%0d/%0d phy=%0d/%0d",
               USE_SRT4, operation, numerator, denominator, result, expected,
               out_rob_tag, expected_rob_tag, out_phy_tag, expected_phy_tag);
      end

      if (stall_cycles != 0) begin
        out_ready = 1'b0;
        repeat (stall_cycles) begin
          @(negedge clk);
          if (!out_valid || result !== expected || out_rob_tag !== expected_rob_tag ||
              out_phy_tag !== expected_phy_tag)
            $fatal(1, "divider output changed while stalled srt4=%0d", USE_SRT4);
        end
        out_ready = 1'b1;
      end
      @(negedge clk);
    end
  endtask

  task automatic check_flush;
    int unsigned wait_cycles;
    begin
      while (!in_ready)
        @(negedge clk);
      op = OP_DIVU;
      dividend = 32'hffff_ffff;
      divisor = 32'd3;
      in_rob_tag = 5'd17;
      in_phy_tag = 6'd11;
      in_valid = 1'b1;
      @(negedge clk);
      in_valid = 1'b0;
      repeat (2) @(negedge clk);
      flush_tag = 5'd16;
      flush = 1'b1;
      @(negedge clk);
      flush = 1'b0;

      for (wait_cycles = 0; wait_cycles < 40; wait_cycles = wait_cycles + 1) begin
        @(negedge clk);
        if (out_valid)
          $fatal(1, "flushed divider operation produced a result srt4=%0d", USE_SRT4);
      end
      if (!in_ready)
        $fatal(1, "divider did not become ready after flush srt4=%0d", USE_SRT4);
    end
  endtask

  initial begin : p_test
    logic [31:0] random_a, random_b;
    int unsigned index;

    clk = 1'b0;
    rst_n = 1'b0;
    flush = 1'b0;
    flush_tag = '0;
    in_valid = 1'b0;
    op = OP_INVALID;
    dividend = '0;
    divisor = '0;
    in_rob_tag = '0;
    in_phy_tag = '0;
    out_ready = 1'b1;
    case_id = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ISA boundary cases, including all immediate-result paths.
    check_case(OP_DIV,  32'd0,         32'd0,         2);
    check_case(OP_DIVU, 32'hffff_ffff, 32'd0,         0);
    check_case(OP_REM,  32'h8000_0000, 32'd0,         1);
    check_case(OP_REMU, 32'h8000_0000, 32'd0,         0);
    check_case(OP_DIV,  32'h8000_0000, 32'hffff_ffff, 2);
    check_case(OP_REM,  32'h8000_0000, 32'hffff_ffff, 0);
    check_case(OP_DIV,  32'hffff_ffff, 32'd1,         0);
    check_case(OP_DIV,  32'd1,         32'hffff_ffff, 1);
    check_case(OP_DIVU, 32'hffff_ffff, 32'h8000_0000, 0);
    check_case(OP_REMU, 32'hffff_ffff, 32'h8000_0000, 2);
    check_case(OP_DIV,  32'h7fff_ffff, 32'h8000_0000, 0);
    check_case(OP_REM,  32'h7fff_ffff, 32'h8000_0000, 0);

    check_flush();

    random_a = 32'hc001_c0de;
    random_b = 32'h1bad_b002;
    for (index = 0; index < 128; index = index + 1) begin
      random_a = lfsr_next(random_a);
      random_b = lfsr_next(random_b);
      check_case(OP_DIV, random_a, random_b, (index % 17 == 0) ? 2 : 0);
      random_a = lfsr_next(random_a);
      random_b = lfsr_next(random_b);
      check_case(OP_DIVU, random_a, random_b, (index % 19 == 0) ? 1 : 0);
      random_a = lfsr_next(random_a);
      random_b = lfsr_next(random_b);
      check_case(OP_REM, random_a, random_b, (index % 23 == 0) ? 2 : 0);
      random_a = lfsr_next(random_a);
      random_b = lfsr_next(random_b);
      check_case(OP_REMU, random_a, random_b, (index % 29 == 0) ? 1 : 0);
    end

    $display("DIV_UNIT_PASS srt4=%0d cases=%0d", USE_SRT4, case_id);
    $finish;
  end
endmodule
