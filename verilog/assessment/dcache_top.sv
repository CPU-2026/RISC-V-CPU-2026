// DCache-only area/timing boundary; external line memory remains ports only.
// Selected by scripts/assess.py --scope dcache, never by the course AXI list.
module student_top (
  input logic clock,
  input logic reset,
  input logic cpuValidInput,
  input logic cpuWriteInput,
  input logic [31:0] cpuAddressInput,
  input logic [31:0] cpuWriteDataInput,
  input logic [3:0] cpuWriteStrobeInput,
  input logic [1:0] cpuSizeInput,
  input logic [1:0] cpuTransactionInput,
  output logic cpuReadyOutput,
  output logic responseValidOutput,
  output logic [31:0] responseDataOutput,
  output logic [1:0] responseTransactionOutput,
  output logic readValidOutput,
  output logic [31:0] readAddressOutput,
  output logic [1:0] readTransactionOutput,
  output logic writeValidOutput,
  output logic [31:0] writeAddressOutput,
  output logic [1:0] writeTransactionOutput,
  output logic [rv32_pkg::DCACHE_LINE_BITS-1:0] writeDataOutput,
  input logic readReadyInput,
  input logic writeReadyInput,
  input logic lineResponseValidInput,
  input logic [rv32_pkg::DCACHE_LINE_BITS-1:0] lineResponseDataInput,
  input logic [31:0] lineResponseAddressInput,
  input logic [1:0] lineResponseTransactionInput,
  output logic lineResponseReadyOutput,
  input logic writeDoneInput,
  input logic [31:0] writeDoneAddressInput,
  input logic [1:0] writeDoneTransactionInput,
  output logic writeDoneReadyOutput,
  output logic initializedOutput,
  output logic idleOutput
);
  import rv32_pkg::*;
  dcache_cpu_request_input_t cpuRequestInner;
  dcache_cpu_response_output_t cpuResponseInner;
  dcache_line_request_output_t lineRequestInner;
  dcache_line_response_input_t lineResponseInner;

  assign cpuRequestInner = '{valid:cpuValidInput, write:cpuWriteInput,
    address:cpuAddressInput, writeData:cpuWriteDataInput,
    writeStrobe:cpuWriteStrobeInput, size:cpuSizeInput, transaction:cpuTransactionInput};
  assign lineResponseInner = '{valid:lineResponseValidInput, data:lineResponseDataInput,
    address:lineResponseAddressInput, transaction:lineResponseTransactionInput};
  assign responseValidOutput = cpuResponseInner.valid;
  assign responseDataOutput = cpuResponseInner.readData;
  assign responseTransactionOutput = cpuResponseInner.transaction;
  assign readValidOutput = lineRequestInner.readValid;
  assign readAddressOutput = lineRequestInner.readAddress;
  assign readTransactionOutput = lineRequestInner.readTransaction;
  assign writeValidOutput = lineRequestInner.writeValid;
  assign writeAddressOutput = lineRequestInner.writeAddress;
  assign writeTransactionOutput = lineRequestInner.writeTransaction;
  assign writeDataOutput = lineRequestInner.writeData;

  rv32_dcache cache (
    .clkInput(clock), .rstNInput(!reset), .cpuRequestInput(cpuRequestInner),
    .cpuReqReadyOutput(cpuReadyOutput), .cpuResponseOutput(cpuResponseInner),
    .memRequestOutput(lineRequestInner), .memReadReadyInput(readReadyInput),
    .memWriteReadyInput(writeReadyInput), .memResponseInput(lineResponseInner),
    .memWriteResponseInput('{valid:writeDoneInput, address:writeDoneAddressInput, transaction:writeDoneTransactionInput}),
    .memRspReadyOutput(lineResponseReadyOutput), .memWriteRspReadyOutput(writeDoneReadyOutput), .initializedOutput(initializedOutput),
    .idleOutput(idleOutput)
  );
endmodule
