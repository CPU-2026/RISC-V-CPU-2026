// Reuse the complete retirement/AXI observation boundary, not a software CPU.
module decode_course_top (
  input logic clock, reset,
  output wire [31:0] araddr, awaddr, wdata,
  output wire arvalid, rready, awvalid, wvalid, bready,
  output wire [3:0] wstrb,
  input logic arready, rvalid, awready, wready, bvalid,
  input logic [31:0] rdata,
  input logic [1:0] rresp, bresp,
  output wire [31:0] observe [57 + (9 * rv32_pkg::COMMIT_WIDTH)],
  output wire [1:0] decodeCountOutput,
  output wire [1:0] issueCountOutput, loadAllocCountOutput, storeAllocCountOutput,
  output wire [7:0] renameEventsOutput
);
  course_sync_top bench (.*);
  generate if (rv32_pkg::DECODE_WIDTH == 2 || rv32_pkg::RENAME_WIDTH == 2) begin : g_multi
    assign decodeCountOutput = !bench.dut.u_core.frontendFrozenInner &&
      !bench.dut.u_core.globalFlushInner ? bench.dut.u_core.u_frontend.g_multi_decode.decodeCountInner : 2'b0;
  end else begin : g_single
    assign decodeCountOutput = {1'b0, !bench.dut.u_core.frontendFrozenInner &&
      !bench.dut.u_core.globalFlushInner && bench.dut.u_core.u_frontend.fqPopInner};
  end endgenerate
  assign issueCountOutput = 2'(bench.dut.u_core.issueFireInner) + 2'(bench.dut.u_core.issueSecondFireInner);
  assign loadAllocCountOutput = 2'(bench.dut.u_core.lsuLoadAllocationInputInner.valid) +
    2'(bench.dut.u_core.lsuLoadAllocationSecondInputInner.valid);
  assign storeAllocCountOutput = 2'(bench.dut.u_core.lsuStoreAllocationInputInner.valid) +
    2'(bench.dut.u_core.lsuStoreAllocationSecondInputInner.valid);
  wire raw1 = bench.dut.u_core.issueSecondFireInner && bench.dut.u_core.ratRenameInputInner.valid &&
    bench.dut.u_core.decodedSecondInner.usesRs1 &&
    bench.dut.u_core.decodedSecondInner.rs1 == bench.dut.u_core.decodedInner.rd;
  wire raw2 = bench.dut.u_core.issueSecondFireInner && bench.dut.u_core.ratRenameInputInner.valid &&
    bench.dut.u_core.decodedSecondInner.usesRs2 &&
    bench.dut.u_core.decodedSecondInner.rs2 == bench.dut.u_core.decodedInner.rd;
  assign renameEventsOutput[0] = raw1;
  assign renameEventsOutput[1] = raw2;
  assign renameEventsOutput[2] = bench.dut.u_core.ratRenameInputInner.valid &&
    bench.dut.u_core.ratRenameSecondInputInner.valid &&
    bench.dut.u_core.decodedInner.rd == bench.dut.u_core.decodedSecondInner.rd;
  assign renameEventsOutput[3] = (raw1 || raw2) && bench.dut.u_core.issueIsJumpInner;
  assign renameEventsOutput[4] = bench.dut.u_core.issueFireInner &&
    bench.dut.u_core.frontendSecondInstructionInner.valid && !bench.dut.u_core.robAllocSecondReadyInner;
  assign renameEventsOutput[5] = bench.dut.u_core.issueFireInner &&
    bench.dut.u_core.frontendSecondInstructionInner.valid && bench.dut.u_core.decodedSecondInner.writesRd &&
    !bench.dut.u_core.prfAllocSecondReadyInner;
  assign renameEventsOutput[6] = bench.dut.u_core.issueFireInner &&
    bench.dut.u_core.frontendSecondInstructionInner.valid &&
    ((bench.dut.u_core.decodedSecondInner.uopClass == rv32_pkg::UOP_LOAD && !bench.dut.u_core.lqAllocSecondReadyInner) ||
     (bench.dut.u_core.decodedSecondInner.uopClass == rv32_pkg::UOP_STORE && !bench.dut.u_core.sqAllocSecondReadyInner));
  assign renameEventsOutput[7] = bench.dut.u_core.globalFlushInner;
endmodule
