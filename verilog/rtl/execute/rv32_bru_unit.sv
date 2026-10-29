module rv32_bru_unit #(
  parameter bit CONDITIONAL_ONLY = 1'b0
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input logic freezeInput,
  input  logic                   flushInput,
  input  rv32_pkg::rob_tag_t      flushTagInput,

  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  output rv32_pkg::bru_execute_output_t executeOutput
);
  import rv32_pkg::*;

  logic bruTakenInner, bruMispredictInner;
  logic [31:0] bruTargetInner, bruNextPcInner, bruLinkInner;
  branch_operation_output_t bruOperationOutputInner;
  logic validInner;
  rob_tag_t tagInner;
  logic [31:0] pcInner, targetInner, nextPcInner, returnAddressInner;
  logic takenInner, conditionalInner, mispredictInner;
  logic callInner, returnInner;

  rv32_bru #(.CONDITIONAL_ONLY(CONDITIONAL_ONLY)) u_bru (
    .branchInput('{operation: executeInput.operation,
                  source1: executeInput.source1,
                  source2: executeInput.source2,
                  immediate: executeInput.immediate,
                  programCounter: executeInput.programCounter,
                  predictedNextProgramCounter: executeInput.predictedNextProgramCounter}),
    .branchOutput(bruOperationOutputInner)
  );
  assign bruTakenInner = bruOperationOutputInner.taken;
  assign bruTargetInner = bruOperationOutputInner.target;
  assign bruNextPcInner = bruOperationOutputInner.nextProgramCounter;
  assign bruLinkInner = bruOperationOutputInner.linkValue;
  assign bruMispredictInner = bruOperationOutputInner.mispredict;

  // New-input acceptance must not taint the OLD registered result outputs.
  assign inReadyOutput = !executeInput.valid || !flushInput || rob_is_older(executeInput.robTag, flushTagInput);
  always_comb begin
    executeOutput.valid = validInner && (!flushInput || rob_is_older(tagInner, flushTagInput));
    executeOutput.robTag = tagInner;
    executeOutput.programCounter = pcInner;
    executeOutput.target = targetInner;
    executeOutput.nextProgramCounter = nextPcInner;
    executeOutput.returnAddress = returnAddressInner;
    executeOutput.taken = takenInner;
    executeOutput.conditional = conditionalInner;
    executeOutput.mispredict = mispredictInner;
    executeOutput.misaligned = 1'b0; // Compatibility field, no exception state.
    executeOutput.isCall = callInner;
    executeOutput.isReturn = returnInner;
  end

`ifndef SYNTHESIS
  if (CONDITIONAL_ONLY) begin : g_conditional_contract
    always @(posedge clkInput) if (rstNInput && !freezeInput &&
        executeInput.valid && inReadyOutput)
      assert (executeInput.operation == OP_BEQ || executeInput.operation == OP_BNE ||
              executeInput.operation == OP_BLT || executeInput.operation == OP_BGE ||
              executeInput.operation == OP_BLTU || executeInput.operation == OP_BGEU)
        else $fatal(1, "conditional-only BRU accepted a non-conditional operation");
  end
`endif

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      validInner <= 1'b0;
      tagInner <= '0;
      pcInner <= '0;
      targetInner <= '0;
      nextPcInner <= '0;
      returnAddressInner <= '0;
      takenInner <= 1'b0;
      conditionalInner <= 1'b0;
      mispredictInner <= 1'b0;
      callInner <= 1'b0;
      returnInner <= 1'b0;
    end else if (!freezeInput) begin
      validInner <= executeInput.valid && inReadyOutput;
      if (executeInput.valid && inReadyOutput) begin
        tagInner <= executeInput.robTag;
        pcInner <= executeInput.programCounter;
        targetInner <= bruTargetInner;
        nextPcInner <= bruNextPcInner;
        returnAddressInner <= bruLinkInner;
        takenInner <= bruTakenInner;
        conditionalInner <= !((executeInput.operation == OP_JAL) || (executeInput.operation == OP_JALR));
        mispredictInner <= bruMispredictInner;
        callInner <= executeInput.isCall;
        returnInner <= executeInput.isReturn;
      end
    end
  end
endmodule
