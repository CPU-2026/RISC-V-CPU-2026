module rv32_bru_unit (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  logic                   flushInput,

  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  output rv32_pkg::bru_execute_output_t executeOutput
);
  import rv32_pkg::*;

  logic bruTakenInner, bruMispredictInner, bruMisalignedInner;
  logic [31:0] bruTargetInner, bruNextPcInner, bruLinkInner;
  branch_operation_output_t bruOperationOutputInner;
  logic validInner;
  rob_tag_t tagInner;
  logic [31:0] pcInner, targetInner, nextPcInner, returnAddressInner;
  logic takenInner, conditionalInner, mispredictInner, misalignedInner;
  logic callInner, returnInner;

  rv32_bru u_bru (
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
  assign bruMisalignedInner = bruOperationOutputInner.targetMisaligned;

  always_comb begin
    inReadyOutput = !flushInput;
    executeOutput.valid = validInner;
    executeOutput.robTag = tagInner;
    executeOutput.programCounter = pcInner;
    executeOutput.target = targetInner;
    executeOutput.nextProgramCounter = nextPcInner;
    executeOutput.returnAddress = returnAddressInner;
    executeOutput.taken = takenInner;
    executeOutput.conditional = conditionalInner;
    executeOutput.mispredict = mispredictInner;
    executeOutput.misaligned = misalignedInner;
    executeOutput.isCall = callInner;
    executeOutput.isReturn = returnInner;
  end

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
      misalignedInner <= 1'b0;
      callInner <= 1'b0;
      returnInner <= 1'b0;
    end else if (flushInput) begin
      validInner <= 1'b0;
    end else begin
      validInner <= executeInput.valid;
      if (executeInput.valid) begin
        tagInner <= executeInput.robTag;
        pcInner <= executeInput.programCounter;
        targetInner <= bruTargetInner;
        nextPcInner <= bruNextPcInner;
        returnAddressInner <= bruLinkInner;
        takenInner <= bruTakenInner;
        conditionalInner <= !((executeInput.operation == OP_JAL) || (executeInput.operation == OP_JALR));
        mispredictInner <= bruMispredictInner;
        misalignedInner <= bruMisalignedInner;
        callInner <= executeInput.isCall;
        returnInner <= executeInput.isReturn;
      end
    end
  end
endmodule
