// Processor-side SRAM DCache boundary. Valid registers reset independently of
// SRAM; initializedOutput only observes reset release, with no startup scan.
// There is no HALT/drain state or dirty-line scan.
module rv32_dmem_backend (
  input logic clkInput,
  input logic rstNInput,
  input rv32_pkg::dcache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::dcache_cpu_response_output_t cpuResponseOutput,
  output rv32_pkg::dcache_line_request_output_t memRequestOutput,
  input logic memReadReadyInput,
  input logic memWriteReadyInput,
  input rv32_pkg::dcache_line_response_input_t memResponseInput,
  input rv32_pkg::dcache_write_response_input_t memWriteResponseInput,
  output logic memRspReadyOutput, memWriteRspReadyOutput,
  output logic initializedOutput,
  input logic exitReadyInput,
  output logic exitValidOutput,
  output logic [31:0] exitValueOutput
);
  rv32_dcache cache (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .cpuRequestInput(cpuRequestInput), .cpuReqReadyOutput(cpuReqReadyOutput),
    .cpuResponseOutput(cpuResponseOutput), .memRequestOutput(memRequestOutput),
    .memReadReadyInput(memReadReadyInput), .memWriteReadyInput(memWriteReadyInput),
    .memResponseInput(memResponseInput), .memWriteResponseInput(memWriteResponseInput),
    .memRspReadyOutput(memRspReadyOutput), .memWriteRspReadyOutput(memWriteRspReadyOutput),
    .initializedOutput(initializedOutput), .idleOutput(),
    .exitReadyInput(exitReadyInput), .exitValidOutput(exitValidOutput), .exitValueOutput(exitValueOutput)
  );
endmodule
