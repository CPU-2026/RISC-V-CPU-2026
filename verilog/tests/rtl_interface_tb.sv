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

  logic imemRspReadyOutput, imemFlushOutput;
  rv32_pkg::icache_cpu_request_input_t imemCacheRequestOutput;
  rv32_core #(.FETCH_WIDTH(1)) dut (.*);
  function automatic logic [31:0] instruction(input logic [31:0] pc);
    case (pc)
      0: return 32'h04000093;
      4: return 32'h02a00113;
      8: return 32'h0020a023;
      12: return 32'h0000a183;
      16: return 32'h00218463;
      20: return 32'h06300213;
      24: return 32'h0040a283;
      28: return 32'h0ff00513;
      default: return 32'h00000013;
    endcase
  endfunction
  logic [2:0] instructionSourceCount;
  rv32_epoch_fifo #(.DEPTH(4), .WIDTH(32)) instructionSource (
    .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(imemFlushOutput),
    .inValidInput(imemReqValidOutput), .inReadyOutput(imemReqReadyInput), .inDataInput(instruction(imemReqAddrOutput)),
    .outValidOutput(imemRspValidInput), .outReadyInput(imemRspReadyOutput), .outDataOutput(imemRspDataInput), .countOutput(instructionSourceCount)
  );

  always @(posedge clkInput) begin
    if (!rstNInput) begin
      dmemRspValidInput <= 1'b0;
      dmemRspRdataInput <= '0;
    end else begin
      dmemRspValidInput <= 1'b0;
      if (dmemReqValidOutput && dmemReqReadyInput) begin
        if (dmemReqWriteOutput) begin
          if (dmemReqAddrOutput != 32'h40 ||
              dmemReqWstrbOutput != 4'hf || dmemReqWdataOutput != 32'd42)
            $fatal(1, "incorrect store payload");
          storeCount <= storeCount + 1;
        end else begin
          if (dmemReqAddrOutput != 32'h44 && dmemReqAddrOutput != 32'h40)
            $fatal(1, "unexpected external load address %h", dmemReqAddrOutput);
          dmemRspRdataInput <= dmemReqAddrOutput == 32'h40 ? 32'd42 : 32'h11223344;
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
  rob_tag_t replayOffsetInput = rob_tag_t'(4);
  rob_replay_narrow_t [RECOVERY_WIDTH-1:0] replayNarrowOutput;
  rob_replay_ras_t [RECOVERY_WIDTH-1:0] replayRasOutput;

  rv32_rob #(.DEPTH(8)) dut (.storeReadyInput('0), .*);

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
        replayNarrowOutput[3].robTag != rob_tag_t'(7) ||
        replayRasOutput[3].programCounter != 32'd28)
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
  store_data_input_t storeDataInput [0:0] = '{default: '0};
  logic [3:0] storeDataIndexInput [0:0] = '{default: '0};
  logic storeAllocReadyOutput;
  logic [3:0] storeAllocIndexOutput;
  lsu_address_input_t addressInput = '0;
  logic [3:0] addressIndexInput = '0;
  cdb_result_t [3:0] writebackInput = '0;
  load_result_output_t loadResultOutput;
  logic loadResultReadyInput = 1'b1;
  rob_retirement_input_t robRetireInput = '0;
  store_completion_output_t storeCompleteOutput;
  store_commit_input_t storeCommitInput = '0;
  logic [3:0] storeCommitIndexInput = '0;
  logic storeCommitReadyOutput;
  data_memory_request_output_t storeRetirementOutput;
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
    // Retire/send in FIFO order; slot 12 is reached through real older pops.
    for (int slot = 0; slot <= 12; slot++) begin
      addressInput = '{valid: 1'b1, isStore: 1'b1, robTag: rob_tag_t'(slot), address: 32'h40+32'(slot<<2)};
      addressIndexInput = 4'(slot);
      @(negedge clkInput); addressInput.valid = 1'b0;
      storeCommitInput = '{valid: 1'b1, robTag: rob_tag_t'(slot)};
      storeCommitIndexInput = 4'(slot);
      robRetireInput = '{valid: 1'b1, robTag: rob_tag_t'(slot)};
      #1;
      if (!storeCommitReadyOutput || !dmemRequestOutput.valid ||
          !dmemRequestOutput.write || dmemRequestOutput.address != 32'h40+32'(slot<<2) ||
          dmemRequestOutput.writeData != 32'h12345678 || dmemRequestOutput.writeStrobe != 4'hf)
        $fatal(1, "store commit was misrouted at slot %0d", slot);
      @(negedge clkInput); storeCommitInput.valid = 1'b0; robRetireInput.valid = 1'b0; #1;
      if (sqCountOutput != 5'(12-slot))
        $fatal(1, "store queue count incorrect after committing slot %0d", slot);
    end
    $display("PASS lsu: parameterized high queue index");
    $finish;
  end
endmodule
