// Standalone area/timing boundary. External memory is represented only by ports.
// This file is selected by scripts/assess.py, not by the course AXI file list.
module student_top (
  input logic clock,
  input logic reset,
  output logic imemReqValidOutput,
  output logic [31:0] imemReqAddrOutput,
  input logic imemReqReadyInput,
  input logic imemRspValidInput,
  input logic [31:0] imemRspAddrInput,
  input logic [rv32_pkg::CACHE_LINE_BITS-1:0] imemRspDataInput,
  output logic imemRspReadyOutput,
  output logic imemFlushOutput,
  output logic dmemReadValidOutput,
  output logic [31:0] dmemReadAddrOutput,
  output logic [1:0] dmemReadTransactionOutput,
  input logic dmemReadReadyInput,
  output logic dmemWriteValidOutput,
  output logic [31:0] dmemWriteAddrOutput,
  output logic [1:0] dmemWriteTransactionOutput,
  output logic [rv32_pkg::DCACHE_LINE_BITS-1:0] dmemWriteDataOutput,
  output logic [3:0] dmemWriteStrobeOutput,
  output logic [1:0] dmemSizeOutput,
  input logic dmemWriteReadyInput,
  input logic dmemRspValidInput,
  input logic [rv32_pkg::DCACHE_LINE_BITS-1:0] dmemRspDataInput,
  input logic [31:0] dmemRspAddrInput,
  input logic [1:0] dmemRspTransactionInput,
  output logic dmemRspReadyOutput,
  input logic dmemWriteDoneInput,
  input logic [31:0] dmemWriteDoneAddrInput,
  input logic [1:0] dmemWriteDoneTransactionInput,
  output logic dmemWriteDoneReadyOutput,
  output logic commitValidOutput,
  output logic [31:0] commitPcOutput,
  output logic [31:0] commitInstrOutput,
  output logic commitRdValidOutput,
  output logic [4:0] commitRdOutput,
  output logic [31:0] commitRdValueOutput,
  output logic commitMemValidOutput,
  output logic [31:0] commitMemAddrOutput,
  output logic [31:0] commitMemDataOutput,
  output logic [3:0] commitMemWstrbOutput,
  output logic haltedOutput,
  output logic trapOutput,
  output logic drainDoneOutput
);
  import rv32_pkg::*;
  logic coreImemReadyInner, coreImemRspValidInner, coreImemRspReadyInner;
  logic [31:0] coreImemRspDataInner;
  logic coreImemReqValidInner, coreImemFlushInner;
  logic [31:0] coreImemReqAddrInner;
  icache_cpu_request_input_t coreImemRequestInner;
  logic coreDmemReqValidInner, coreDmemReqReadyInner, coreDmemReqWriteInner;
  logic [31:0] coreDmemReqAddrInner, coreDmemReqDataInner;
  logic [3:0] coreDmemReqStrobeInner;
  logic [1:0] coreDmemReqSizeInner;
  logic coreDmemRspValidInner;
  logic [31:0] coreDmemRspDataInner;
  data_transaction_t coreDmemReqTransactionInner, coreDmemRspTransactionInner;
  logic coreResetNInner;
  assign coreResetNInner = !reset;

  rv32_core #(
    .FETCH_WIDTH(1),
    .LEGACY_HALT(1'b1),
`ifdef ASSESS_CORE_ONLY
    .TAGGED_DMEM(1'b0)
`else
    .TAGGED_DMEM(1'b1)
`endif
  ) u_core (
    .clkInput(clock), .rstNInput(coreResetNInner),
    .imemReqValidOutput(coreImemReqValidInner),
    .imemReqReadyInput(coreImemReadyInner),
    .imemReqAddrOutput(coreImemReqAddrInner),
    .imemRspValidInput(coreImemRspValidInner),
    .imemRspDataInput(coreImemRspDataInner),
    .imemRspReadyOutput(coreImemRspReadyInner),
    .imemFlushOutput(coreImemFlushInner),
    .imemCacheRequestOutput(coreImemRequestInner),
    .dmemReqValidOutput(coreDmemReqValidInner),
    .dmemReqReadyInput(coreDmemReqReadyInner),
    .dmemReqWriteOutput(coreDmemReqWriteInner),
    .dmemReqAddrOutput(coreDmemReqAddrInner),
    .dmemReqWdataOutput(coreDmemReqDataInner),
    .dmemReqWstrbOutput(coreDmemReqStrobeInner),
    .dmemReqSizeOutput(coreDmemReqSizeInner),
    .dmemRspValidInput(coreDmemRspValidInner),
    .dmemRspRdataInput(coreDmemRspDataInner),
    .dmemReqTransactionOutput(coreDmemReqTransactionInner),
    .dmemRspTransactionInput(coreDmemRspTransactionInner),
    .commitValidOutput(commitValidOutput), .commitPcOutput(commitPcOutput),
    .commitInstrOutput(commitInstrOutput), .commitRdValidOutput(commitRdValidOutput),
    .commitRdOutput(commitRdOutput), .commitRdValueOutput(commitRdValueOutput),
    .commitMemValidOutput(commitMemValidOutput), .commitMemAddrOutput(commitMemAddrOutput),
    .commitMemDataOutput(commitMemDataOutput), .commitMemWstrbOutput(commitMemWstrbOutput),
    .haltedOutput(haltedOutput), .trapOutput(trapOutput)
  );

`ifdef ASSESS_CORE_ONLY
  assign imemReqValidOutput = coreImemReqValidInner;
  assign imemReqAddrOutput = coreImemReqAddrInner;
  assign coreImemReadyInner = imemReqReadyInput;
  assign coreImemRspValidInner = imemRspValidInput;
  assign coreImemRspDataInner = imemRspDataInput[31:0];
  assign imemRspReadyOutput = coreImemRspReadyInner;
  assign imemFlushOutput = coreImemFlushInner;
  assign dmemReadValidOutput = coreDmemReqValidInner && !coreDmemReqWriteInner;
  assign dmemWriteValidOutput = coreDmemReqValidInner && coreDmemReqWriteInner;
  assign dmemReadAddrOutput = coreDmemReqAddrInner;
  assign dmemWriteAddrOutput = coreDmemReqAddrInner;
  assign dmemWriteDataOutput = {{(CACHE_LINE_BITS-32){1'b0}}, coreDmemReqDataInner};
  assign dmemWriteStrobeOutput = coreDmemReqStrobeInner;
  assign dmemSizeOutput = coreDmemReqSizeInner;
  assign coreDmemReqReadyInner = coreDmemReqWriteInner ? dmemWriteReadyInput : dmemReadReadyInput;
  assign coreDmemRspValidInner = dmemRspValidInput;
  assign coreDmemRspDataInner = dmemRspDataInput[31:0];
   assign coreDmemRspTransactionInner = data_transaction_t'(dmemRspTransactionInput);
  assign dmemReadTransactionOutput = coreDmemReqTransactionInner;
  assign dmemWriteTransactionOutput = 0;
  assign dmemRspReadyOutput = 1'b1;
  assign dmemWriteDoneReadyOutput = 1'b1;
  assign drainDoneOutput = haltedOutput;
`else
  // Compatibility observation only; HALT is no longer an instruction to drain.
  assign drainDoneOutput = haltedOutput;
  icache_cpu_response_output_t icacheResponseInner;
  cache_line_request_output_t icacheLineRequestInner;
  icache_line_response_input_t icacheLineResponseInner;
  dcache_cpu_request_input_t dcacheRequestInner;
  dcache_cpu_response_output_t dcacheResponseInner;
  dcache_line_request_output_t dcacheLineRequestInner;
  dcache_line_response_input_t dcacheLineResponseInner;
  dcache_write_response_input_t dcacheWriteResponseInner;

  assign icacheLineResponseInner.valid = imemRspValidInput;
  assign icacheLineResponseInner.address = imemRspAddrInput;
  assign icacheLineResponseInner.data = imemRspDataInput;
  assign imemReqValidOutput = icacheLineRequestInner.valid;
  assign imemReqAddrOutput = icacheLineRequestInner.address;
  assign coreImemRspValidInner = icacheResponseInner.valid;
  assign coreImemRspDataInner = icacheResponseInner.instruction;
  rv32_icache u_icache (
    .freezeInput(haltedOutput),
    .clkInput(clock), .rstNInput(coreResetNInner), .flushInput(coreImemFlushInner),
    .cpuRequestInput(coreImemRequestInner), .cpuReqReadyOutput(coreImemReadyInner),
    .cpuResponseOutput(icacheResponseInner), .cpuRspReadyInput(coreImemRspReadyInner),
    .memRequestOutput(icacheLineRequestInner), .memReqReadyInput(imemReqReadyInput),
    .memResponseInput(icacheLineResponseInner), .memRspReadyOutput(imemRspReadyOutput),
    .memFlushOutput(imemFlushOutput)
  );

  assign dcacheRequestInner.valid = coreDmemReqValidInner;
  assign dcacheRequestInner.write = coreDmemReqWriteInner;
  assign dcacheRequestInner.address = coreDmemReqAddrInner;
  assign dcacheRequestInner.writeData = coreDmemReqDataInner;
  assign dcacheRequestInner.writeStrobe = coreDmemReqStrobeInner;
  assign dcacheRequestInner.size = coreDmemReqSizeInner;
  assign dcacheRequestInner.transaction = coreDmemReqTransactionInner;
  assign coreDmemRspValidInner = dcacheResponseInner.valid;
  assign coreDmemRspDataInner = dcacheResponseInner.readData;
  assign coreDmemRspTransactionInner = dcacheResponseInner.transaction;
  assign dcacheLineResponseInner.valid = dmemRspValidInput;
  assign dcacheLineResponseInner.data = dmemRspDataInput;
  assign dcacheLineResponseInner.address = dmemRspAddrInput;
  assign dcacheLineResponseInner.transaction = dmemRspTransactionInput;
  assign dcacheWriteResponseInner = '{valid:dmemWriteDoneInput, address:dmemWriteDoneAddrInput,
    transaction:dmemWriteDoneTransactionInput};
  assign dmemReadValidOutput = dcacheLineRequestInner.readValid;
  assign dmemReadAddrOutput = dcacheLineRequestInner.readAddress;
  assign dmemReadTransactionOutput = dcacheLineRequestInner.readTransaction;
  assign dmemWriteValidOutput = dcacheLineRequestInner.writeValid;
  assign dmemWriteAddrOutput = dcacheLineRequestInner.writeAddress;
  assign dmemWriteTransactionOutput = dcacheLineRequestInner.writeTransaction;
  assign dmemWriteDataOutput = dcacheLineRequestInner.writeData;
  assign dmemWriteStrobeOutput = 4'b1111;
  assign dmemSizeOutput = 2'b10;
  rv32_dmem_backend u_dmem_backend (
    .exitReadyInput(1'b0), .exitValidOutput(), .exitValueOutput(),
    .clkInput(clock), .rstNInput(!reset),
    .cpuRequestInput(dcacheRequestInner), .cpuReqReadyOutput(coreDmemReqReadyInner),
    .cpuResponseOutput(dcacheResponseInner), .memRequestOutput(dcacheLineRequestInner),
    .memReadReadyInput(dmemReadReadyInput), .memWriteReadyInput(dmemWriteReadyInput),
    .memResponseInput(dcacheLineResponseInner), .memWriteResponseInput(dcacheWriteResponseInner),
    .memRspReadyOutput(dmemRspReadyOutput), .memWriteRspReadyOutput(dmemWriteDoneReadyOutput),
    .initializedOutput()
  );
`endif
endmodule
