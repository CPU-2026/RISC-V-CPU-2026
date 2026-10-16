// Test-only observation boundary; the course DUT keeps exactly its AXI ports.
module course_sync_top (
  input logic clock, reset,
  output wire [31:0] araddr, awaddr, wdata,
  output wire arvalid, rready, awvalid, wvalid, bready,
  output wire [3:0] wstrb,
  input logic arready, rvalid, awready, wready, bvalid,
  input logic [31:0] rdata,
  input logic [1:0] rresp, bresp,
  output logic [31:0] observe [57]
);
  student_top dut (.*);
  always_comb begin
    observe[0] = 32'(dut.u_core.commitValidOutput);
    observe[1] = dut.u_core.commitPcOutput;
    observe[2] = 32'(dut.u_core.commitRdValidOutput);
    observe[3] = 32'(dut.u_core.commitRdOutput);
    observe[4] = dut.u_core.commitRdValueOutput;
    observe[5] = 32'(dut.u_core.commitMemValidOutput);
    observe[6] = dut.u_core.commitMemAddrOutput;
    observe[7] = dut.u_core.commitMemDataOutput;
    observe[8] = 32'(dut.u_core.commitMemWstrbOutput);
    observe[9] = 32'(dut.haltedInner);
    observe[10] = 32'(dut.trapInner);
    observe[11] = 32'(dut.u_core.predictorFetchAcceptInner);
    observe[12] = dut.u_core.predictorPcInner;
    observe[13] = dut.u_core.predictorOutputInner.nextProgramCounter;
    observe[14] = 32'(dut.u_core.predictorOutputInner.checkpointId);
    observe[15] = 32'(dut.u_core.issueFireInner);
    observe[16] = dut.u_core.iqPcInner;
    observe[17] = 32'(dut.u_core.robAllocTagInner);
    observe[18] = 32'(dut.u_core.globalFlushInner);
    observe[19] = 32'(dut.u_core.globalFlushTagInner);
    observe[20] = dut.u_core.globalRedirectPcInner;
    observe[21] = 32'(dut.u_core.robHeadTagInner);
    observe[22] = 32'(dut.u_core.robAllocTagInner);
    observe[23] = 32'(dut.u_core.u_frontend.fqCountOutput);
    observe[24] = 32'(dut.u_core.u_frontend.iqCountOutput);
    observe[25] = 32'(dut.u_core.u_predictor.dirGhrInner);
    observe[26] = 32'(dut.u_core.predictorOutputInner.checkpointId);
    observe[27] = 32'(dut.u_dmem_backend.cache.countInner);
    observe[28] = 32'(dut.u_dmem_backend.cache.lookupInner);
    observe[29] = 32'(dut.u_dmem_backend.cache.responseInner);
    observe[30] = 32'(dut.u_dmem_backend.cache.storeInner);
    observe[31] = 32'(dut.u_dmem_backend.cache.mergeSlotInner);
    observe[32] = 32'(dut.u_dmem_backend.cache.allocateMissInner);
    observe[33] = 32'(dut.u_dmem_backend.cache.fillMissInner);
    observe[34] = 32'(dut.u_dmem_backend.cache.fillFireInner);
    observe[35] = 32'(dut.u_dmem_backend.cache.writeAckInner);
    observe[36] = 32'(dut.exitValidInner);
    observe[37] = 32'(dut.u_core.aluResultLiveInner);
    observe[38] = 32'(dut.u_core.wbAluTagInner);
    observe[39] = dut.u_core.wbAluValueInner;
    observe[40] = 32'(dut.u_core.wbLoadValidInner);
    observe[41] = 32'(dut.u_core.wbLoadTagInner);
    observe[42] = dut.u_core.wbLoadValueInner;
    observe[43] = 32'(dut.u_core.wbMulValidInner);
    observe[44] = 32'(dut.u_core.wbMulTagInner);
    observe[45] = dut.u_core.wbMulValueInner;
    observe[46] = 32'(dut.u_core.wbDivValidInner);
    observe[47] = 32'(dut.u_core.wbDivTagInner);
    observe[48] = dut.u_core.wbDivValueInner;
    observe[49] = 32'(dut.dcacheRequestInner.valid && dut.dmemReadyInner);
    observe[50] = dut.dcacheRequestInner.address;
    observe[51] = 32'(dut.dcacheRequestInner.write);
    observe[52] = dut.dcacheRequestInner.writeData;
    observe[53] = 32'(dut.dcacheRequestInner.size);
    observe[54] = 32'(dut.dcacheResponseInner.valid);
    observe[55] = dut.dcacheResponseInner.readData;
    observe[56] = 32'(dut.dataResponseReadyInner);
  end
endmodule
