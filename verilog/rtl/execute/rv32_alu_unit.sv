module rv32_alu_unit (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,

  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  input  logic                   outReadyInput,
  output rv32_pkg::alu_execute_output_t executeOutput
);
  import rv32_pkg::*;

  logic [31:0] aluResultInner;
  alu_operation_output_t aluOutputInner;
  logic validInner;
  logic [31:0] resultInner;
  rob_tag_t tagInner;
  phy_tag_t phyInner;
  logic controlInner, controlMisalignedInner;

  rv32_alu u_alu (
    .aluInput('{operation: executeInput.operation,
               leftOperand: executeInput.source1,
               rightOperand: executeInput.source2,
               immediate: executeInput.immediate,
               programCounter: executeInput.programCounter,
               useImmediate: executeInput.useImmediate}),
    .aluOutput(aluOutputInner)
  );
  assign aluResultInner = aluOutputInner.value;

  always_comb begin
    inReadyOutput = !validInner || outReadyInput;
    executeOutput.valid = validInner;
    executeOutput.value = resultInner;
    executeOutput.robTag = tagInner;
    executeOutput.destinationPhy = phyInner;
    executeOutput.isControl = controlInner;
    executeOutput.controlMisaligned = controlMisalignedInner;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      validInner <= 1'b0;
      resultInner <= '0;
      tagInner <= '0;
      phyInner <= '0;
      controlInner <= 1'b0;
      controlMisalignedInner <= 1'b0;
    end else if (flushInfoInput.valid) begin
      // Strictly older results broadcast in this cycle; equal/younger results
      // are killed. Either way this single output slot is consumed once.
      validInner <= 1'b0;
    end else if (inReadyOutput) begin
      validInner <= executeInput.valid;
      if (executeInput.valid) begin
        resultInner <= aluResultInner;
        tagInner <= executeInput.robTag;
        phyInner <= executeInput.destinationPhy;
        controlInner <= executeInput.isControl;
        controlMisalignedInner <= executeInput.isControl && (aluResultInner[1:0] != 2'b00);
      end
    end
  end
endmodule
