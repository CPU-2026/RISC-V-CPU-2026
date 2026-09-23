// Exercises the frontend, predictor, ROB, execution and LSU interfaces without
// depending on the course's as-yet-unimplemented student_top AXI wrapper.
// From the repository root, build with:
//   $ verilator --binary --timing --timescale 1ns/1ps -Wno-BLKLOOPINIT \
//     --top-module tb_cpu -F verilog/filelist.f verilog/tests/rtl_interface_tb.sv \
//     --Mdir /tmp/rtl_tb_cpu
// Run /tmp/rtl_tb_cpu/Vtb_cpu; use tb_lsu_capacity and a separate --Mdir
// for the parameterized queue test, or tb_rob_count for the ROB count test.
module tb_cpu;
  logic clkInput = 1'b0;
  always #5 clkInput = ~clkInput;
  logic rstNInput = 1'b0;
  logic imemReqValidOutput, imemReqReadyInput = 1'b1;
  logic [31:0] imemReqAddrOutput;
  logic imemRspValidInput = 1'b0;
  logic [31:0] imemRspDataInput = '0;
  logic dmemReqValidOutput, dmemReqWriteOutput;
  logic dmemReqReadyInput = 1'b1;
  logic [31:0] dmemReqAddrOutput, dmemReqWdataOutput;
  logic [3:0] dmemReqWstrbOutput;
  logic [1:0] dmemReqSizeOutput;
  logic dmemRspValidInput = 1'b0;
  logic [31:0] dmemRspRdataInput = '0;
  logic commitValidOutput, commitRdValidOutput, commitMemValidOutput;
  logic [31:0] commitPcOutput, commitInstrOutput, commitRdValueOutput;
  logic [4:0] commitRdOutput;
  logic [31:0] commitMemAddrOutput, commitMemDataOutput;
  logic [3:0] commitMemWstrbOutput;
  logic haltedOutput, trapOutput;
  int commitIndex = 0;
  int storeCount = 0;
  int loadCount = 0;

  cpu_top dut (.*);

  always @(posedge clkInput) begin
    if (!rstNInput) begin
      imemRspValidInput <= 1'b0;
      dmemRspValidInput <= 1'b0;
      dmemRspRdataInput <= '0;
    end else begin
      imemRspValidInput <= imemReqValidOutput && imemReqReadyInput;
      case (imemReqAddrOutput)
        32'd0:  imemRspDataInput <= 32'h04000093; // addi x1, x0, 64
        32'd4:  imemRspDataInput <= 32'h02a00113; // addi x2, x0, 42
        32'd8:  imemRspDataInput <= 32'h0020a023; // sw x2, 0(x1)
        32'd12: imemRspDataInput <= 32'h0000a183; // lw x3, 0(x1)
        32'd16: imemRspDataInput <= 32'h00218463; // beq x3, x2, +8
        32'd20: imemRspDataInput <= 32'h06300213; // must be squashed
        32'd24: imemRspDataInput <= 32'h0040a283; // lw x5, 4(x1), external response
        32'd28: imemRspDataInput <= 32'h0ff00513; // halt
        default: imemRspDataInput <= 32'h00000013; // nop
      endcase
      dmemRspValidInput <= 1'b0;
      if (dmemReqValidOutput && dmemReqReadyInput) begin
        if (dmemReqWriteOutput) begin
          if (dmemReqAddrOutput != 32'h40 ||
              dmemReqWstrbOutput != 4'hf || dmemReqWdataOutput != 32'd42)
            $fatal(1, "incorrect store payload");
          storeCount <= storeCount + 1;
        end else begin
          if (dmemReqAddrOutput != 32'h44)
            $fatal(1, "unexpected external load address %h", dmemReqAddrOutput);
          dmemRspRdataInput <= 32'h11223344;
          dmemRspValidInput <= 1'b1;
          loadCount <= loadCount + 1;
        end
      end
      if (trapOutput) $fatal(1, "unexpected trap");
      if (commitValidOutput) begin
        case (commitIndex)
          0: if (commitPcOutput != 0 || !commitRdValidOutput ||
                 commitRdOutput != 1 || commitRdValueOutput != 64)
               $fatal(1, "bad first commit");
          1: if (commitPcOutput != 4 || !commitRdValidOutput ||
                 commitRdOutput != 2 || commitRdValueOutput != 42)
               $fatal(1, "bad second commit");
          2: if (commitPcOutput != 8 || !commitMemValidOutput)
               $fatal(1, "store did not commit");
          3: if (commitPcOutput != 12 || !commitRdValidOutput ||
                 commitRdOutput != 3 || commitRdValueOutput != 42)
               $fatal(1, "load did not receive stored data");
          4: if (commitPcOutput != 16)
               $fatal(1, "branch did not commit");
          5: if (commitPcOutput != 24 || !commitRdValidOutput ||
                 commitRdOutput != 5 || commitRdValueOutput != 32'h11223344)
               $fatal(1, "external load did not receive response");
          6: if (commitPcOutput != 28)
               $fatal(1, "branch failed to squash fall-through");
          default: $fatal(1, "unexpected extra commit at %h", commitPcOutput);
        endcase
        commitIndex <= commitIndex + 1;
      end
    end
  end

  initial begin
    repeat (3) @(negedge clkInput);
    rstNInput = 1'b1;
    for (int cycle = 0; cycle < 500; cycle++) begin
      @(negedge clkInput);
      if (haltedOutput) begin
        // A redirected speculative load may issue a second external read;
        // only the committed register value and legal request addresses matter.
        if (commitIndex != 7 || storeCount != 1 || loadCount < 1)
          $fatal(1, "incomplete program: commits=%0d stores=%0d external loads=%0d",
                 commitIndex, storeCount, loadCount);
        $display("PASS cpu: commit/branch/store/load interfaces");
        $finish;
      end
    end
    $fatal(1, "cpu smoke program timed out");
  end
endmodule

module tb_rob_count;
  import rv32_pkg::*;
  logic clkInput = 1'b0;
  always #5 clkInput = ~clkInput;
  logic rstNInput = 1'b0;
  rob_allocation_input_t allocInput = '0;
  logic allocReadyOutput;
  rob_tag_t allocTagOutput;
  rob_completion_t [5:0] completionInput = '0;
  rob_flush_input_t flushInput = '0;
  rob_lookup_input_t [4:0] lookupInput = '0;
  rob_lookup_output_t [4:0] lookupOutput;
  rob_commit_output_t commitOutput;
  logic commitStoreOutput;
  logic commitReadyInput = 1'b0;
  logic commitFireOutput;
  rob_status_output_t statusOutput;
  logic [3:0] countOutput;
  rob_replay_entry_t [7:0] replayOutput;

  rv32_rob #(.DEPTH(8)) dut (.*);

  initial begin
    repeat (3) @(negedge clkInput);
    rstNInput = 1'b1;
    for (int slot = 0; slot < 8; slot++) begin
      allocInput = '0;
      allocInput.valid = 1'b1;
      allocInput.programCounter = 32'(slot * 4);
      allocInput.instruction = 32'h00000013;
      #1;
      if (!allocReadyOutput || allocTagOutput != rob_tag_t'(slot))
        $fatal(1, "ROB allocation failed at slot %0d", slot);
      @(negedge clkInput);
    end
    allocInput.valid = 1'b0;
    #1;
    if (!statusOutput.full || statusOutput.empty || countOutput != 4'd8 ||
        replayOutput[7].robTag != rob_tag_t'(7) ||
        replayOutput[7].programCounter != 32'd28)
      $fatal(1, "parameterized ROB count/replay truncated");
    $display("PASS rob: parameterized count and replay window");
    $finish;
  end
endmodule

// Checks a queue slot beyond the original three-bit index boundary.
module tb_lsu_capacity;
  import rv32_pkg::*;
  logic clkInput = 1'b0;
  always #5 clkInput = ~clkInput;
  logic rstNInput = 1'b0;
  rob_flush_input_t flushInfoInput = '0;
  load_allocation_input_t loadAllocationInput = '0;
  logic loadAllocReadyOutput;
  logic [3:0] loadAllocIndexOutput;
  store_allocation_input_t storeAllocationInput = '0;
  logic storeAllocReadyOutput;
  logic [3:0] storeAllocIndexOutput;
  lsu_address_input_t addressInput = '0;
  logic [3:0] addressIndexInput = '0;
  cdb_result_t [3:0] writebackInput = '0;
  load_result_output_t loadResultOutput;
  logic loadResultReadyInput = 1'b1;
  store_completion_output_t storeCompleteOutput;
  store_commit_input_t storeCommitInput = '0;
  logic [3:0] storeCommitIndexInput = '0;
  logic storeCommitReadyOutput;
  data_memory_request_output_t dmemRequestOutput;
  logic dmemReqReadyInput = 1'b1;
  data_memory_response_input_t dmemResponseInput = '0;
  logic [4:0] lqCountOutput, sqCountOutput;

  rv32_lsu #(.LQ_DEPTH(16), .SQ_DEPTH(16)) dut (.*);

  initial begin
    repeat (3) @(negedge clkInput);
    rstNInput = 1'b1;
    for (int slot = 0; slot <= 12; slot++) begin
      storeAllocationInput = '{valid: 1'b1, robTag: rob_tag_t'(slot),
                               size: MEM_WORD, dataReady: 1'b1,
                               dataTag: '0, dataValue: 32'h12345678};
      #1;
      if (!storeAllocReadyOutput || storeAllocIndexOutput != 4'(slot))
        $fatal(1, "failed to allocate slot %0d", slot);
      @(negedge clkInput);
    end
    storeAllocationInput.valid = 1'b0;
    addressInput = '{valid: 1'b1, isStore: 1'b1, address: 32'h00000040};
    addressIndexInput = 4'd12;
    @(negedge clkInput);
    addressInput.valid = 1'b0;
    storeCommitInput = '{valid: 1'b1, robTag: rob_tag_t'(12)};
    storeCommitIndexInput = 4'd12;
    #1;
    if (!storeCommitReadyOutput || !dmemRequestOutput.valid ||
        !dmemRequestOutput.write || dmemRequestOutput.address != 32'h40 ||
        dmemRequestOutput.writeData != 32'h12345678 ||
        dmemRequestOutput.writeStrobe != 4'hf)
      $fatal(1, "high-slot store commit was misrouted");
    @(negedge clkInput);
    storeCommitInput.valid = 1'b0;
    if (sqCountOutput != 5'd12)
      $fatal(1, "store queue count incorrect after committing high slot");
    $display("PASS lsu: parameterized high queue index");
    $finish;
  end
endmodule
