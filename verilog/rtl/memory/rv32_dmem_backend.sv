// Processor-side DCache boundary and one-shot drain. Architectural Store
// retirement lives in core/LSU; acceptance transfers ownership into this Cache.
// A drain first finishes the accepted transaction, then writes back dirty lines.
module rv32_dmem_backend (
  input logic clkInput,
  input logic rstNInput,
  input rv32_pkg::dcache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::dcache_cpu_response_output_t cpuResponseOutput,
  output rv32_pkg::dcache_line_request_output_t memRequestOutput,
  input logic memReadReadyInput,
  input logic memWriteReadyInput,
  input rv32_pkg::cache_line_response_input_t memResponseInput,
  input logic memWriteDoneInput,
  input logic drainInput,
  output logic drainDoneOutput
);
  typedef enum logic [1:0] {RUN, WAIT_IDLE, WRITEBACK, DONE} drain_state_e;
  drain_state_e drainStateInner;
  rv32_pkg::dcache_cpu_request_input_t cacheRequestInner;
  logic cacheReadyInner, cacheIdleInner, flushDoneInner, flushInner;

  always_comb begin
    cacheRequestInner = cpuRequestInput;
    cacheRequestInner.valid = cpuRequestInput.valid && drainStateInner == RUN && !drainInput;
    cpuReqReadyOutput = cacheReadyInner && drainStateInner == RUN && !drainInput;
  end
  assign flushInner = drainStateInner == WRITEBACK;
  assign drainDoneOutput = drainStateInner == DONE;

  rv32_dcache cache (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .cpuRequestInput(cacheRequestInner), .cpuReqReadyOutput(cacheReadyInner),
    .cpuResponseOutput(cpuResponseOutput), .memRequestOutput(memRequestOutput),
    .memReadReadyInput(memReadReadyInput), .memWriteReadyInput(memWriteReadyInput),
    .memResponseInput(memResponseInput), .memWriteDoneInput(memWriteDoneInput),
    .flushInput(flushInner), .flushDoneOutput(flushDoneInner), .idleOutput(cacheIdleInner)
  );

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) drainStateInner <= RUN;
    else begin
      unique case (drainStateInner)
        RUN: if (drainInput) drainStateInner <= WAIT_IDLE;
        WAIT_IDLE: if (cacheIdleInner && !cpuResponseOutput.valid) drainStateInner <= WRITEBACK;
        WRITEBACK: if (flushDoneInner) drainStateInner <= DONE;
        DONE: drainStateInner <= DONE;
        default: drainStateInner <= RUN;
      endcase
    end
  end
endmodule
