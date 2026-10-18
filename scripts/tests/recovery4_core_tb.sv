// Real core: an older pending Load returns during recovery of a younger JALR.
// The wrong path contains an exit Store, which must never retire.
module tb_recovery4_core;
  import rv32_pkg::*;
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0;
  logic imemValid, imemReady, imemResponseValid = 0, imemResponseReady, imemFlush;
  logic [31:0] imemAddress, imemResponseData = 0;
  logic dmemValid, dmemWrite, dmemResponseValid, pendingRead = 0;
  logic [31:0] dmemAddress;
  logic halted, trapped, committed, rdValid, memValid;
  logic [31:0] committedPc, rdValue, memAddress, memData;
  logic [4:0] rd;
  int retired = 0, flushes = 0, walkCycles = 0;
  bit receivedDuringWalk = 0, sawResult = 0, sawExit = 0;

  function automatic logic [31:0] instruction(input logic [31:0] pc);
    case (pc)
      0: instruction = 32'h10000593;  // addi x11,x0,0x100
      4: instruction = 32'h0005a603;  // lw x12,0(x11)
      8: instruction = 32'h04000113;  // addi x2,x0,64
      12: instruction = 32'h000100e7; // jalr x1,0(x2)
      16: instruction = 32'h07b00513; // wrong: addi x10,x0,123
      20: instruction = 32'h800002b7; // wrong: lui x5,0x80000
      24: instruction = 32'h00a2a023; // wrong: sw x10,0(x5)
      64: instruction = 32'h00060533; // add x10,x12,x0
      68: instruction = 32'h800002b7; // lui x5,0x80000
      72: instruction = 32'h00a2a023; // sw x10,0(x5)
      default: instruction = 32'h00000013;
    endcase
  endfunction

  assign imemReady = !imemResponseValid || imemResponseReady;
  assign dmemResponseValid = pendingRead && dut.recoveryStepInner.active &&
    dut.recoveryStepInner.offset == 4;
  rv32_core dut (
    .clkInput(clock), .rstNInput(resetN),
    .imemReqValidOutput(imemValid), .imemReqReadyInput(imemReady), .imemReqAddrOutput(imemAddress),
    .imemRspValidInput(imemResponseValid), .imemRspDataInput(imemResponseData),
    .imemRspReadyOutput(imemResponseReady), .imemFlushOutput(imemFlush), .imemCacheRequestOutput(),
    .dmemReqValidOutput(dmemValid), .dmemReqReadyInput(1'b1), .dmemReqWriteOutput(dmemWrite),
    .dmemReqAddrOutput(dmemAddress), .dmemReqWdataOutput(), .dmemReqWstrbOutput(), .dmemReqSizeOutput(),
    .dmemRspValidInput(dmemResponseValid), .dmemRspRdataInput(32'd77),
    .dmemReqTransactionOutput(), .dmemRspTransactionInput('0),
    .commitValidOutput(committed), .commitPcOutput(committedPc), .commitInstrOutput(),
    .commitRdValidOutput(rdValid), .commitRdOutput(rd), .commitRdValueOutput(rdValue),
    .commitMemValidOutput(memValid), .commitMemAddrOutput(memAddress), .commitMemDataOutput(memData),
    .commitMemWstrbOutput(), .haltedOutput(halted), .trapOutput(trapped)
  );

  always @(posedge clock) if (resetN) begin
    if (imemFlush)
      imemResponseValid <= 0;
    else if (imemValid && imemReady) begin
      imemResponseValid <= 1;
      imemResponseData <= instruction(imemAddress);
    end else if (imemResponseReady)
      imemResponseValid <= 0;
    if (dmemValid && !dmemWrite) begin
      assert (!pendingRead && dmemAddress == 32'h100);
      pendingRead <= 1;
    end
    if (dmemResponseValid) begin
      pendingRead <= 0;
      receivedDuringWalk <= 1;
    end
    if (dut.globalFlushInner) flushes++;
    if (dut.recoveryBusyInner) walkCycles++;
    if (committed) begin
      assert (committedPc == (retired < 4 ? 32'(retired*4) : 32'(64+(retired-4)*4)))
        else $fatal(1, "unexpected retirement pc=%0d number=%0d", committedPc, retired);
      retired++;
    end
    if (rdValid && rd == 10) begin
      assert (rdValue == 77) else $fatal(1, "lost pending Load response");
      sawResult <= 1;
    end
    if (memValid) begin
      assert (committedPc == 72 && memAddress == AXI_EXIT_ADDR && memData == 77)
        else $fatal(1, "wrong-path Store retired");
      sawExit <= 1;
    end
  end

  initial begin
    repeat (2) @(negedge clock);
    resetN = 1;
    wait (halted);
    @(negedge clock);
    assert (!trapped && retired == 7 && flushes == 1 && walkCycles == 4 &&
      receivedDuringWalk && sawResult && sawExit && !pendingRead)
      else $fatal(1, "core summary trap=%0d retired=%0d flushes=%0d walk=%0d response=%0d result=%0d exit=%0d pending=%0d",
        trapped, retired, flushes, walkCycles, receivedDuringWalk, sawResult, sawExit, pendingRead);
    assert (dut.u_predictor.u_ras.specRasTopInner == 1 &&
            dut.u_predictor.u_ras.archRasTopInner == 1 &&
            dut.u_predictor.u_ras.specRasPcInner[0] == 16);
    $display("PASS recovery4 core: 7 retirements, 1 redirect, 4 walk cycles, pending Load response retained, wrong-path exit canceled");
    $finish;
  end
  initial begin #20000; $fatal(1, "recovery4 core timeout"); end
endmodule
