// Post-integration startup check, not a substitute for the full independent ISA.
module tb_four_issue_config;
  logic clock=0,reset=1;
  student_top dut(.clock(clock),.reset(reset),
    .arready(1'b0),.rdata(32'b0),.rresp(2'b0),.rvalid(1'b0),
    .awready(1'b0),.wready(1'b0),.bresp(2'b0),.bvalid(1'b0));
  initial begin
    repeat(5)begin #1;clock=1;#1;clock=0;end
    reset=0;
    repeat(4)begin #1;clock=1;#1;clock=0;end
    assert(dut.ISSUE_WIDTH==4 && dut.DECODE_WIDTH==4 && rv32_pkg::ROB_ENTRIES==32 &&
      rv32_pkg::PRF_ENTRIES==64 && $bits(dut.u_core.robCountInner)==6 &&
      dut.u_core.g_four_rename_state.u_rename.u_rob.LANES==4)
      else $fatal(1,"four-issue core did not select the real array backend");
    $display("PASS issue-width configuration integrated core issue4/decode4 ROB32 PRF64; fetch/commit unchanged");
    $finish;
  end
endmodule
