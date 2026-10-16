// One registered address result. An LSQ entry was reserved at instruction
// issue, so its address-update port has no capacity backpressure. Each old
// result is delivered or cancelled while the next dispatch refills the stage.
module rv32_agu_unit (
  input  logic clkInput,
  input  logic rstNInput,
  input logic freezeInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,
  input  rv32_pkg::rs_issue_output_t executeInput,
  input  logic [3:0] auxiliaryInput,
  output logic inReadyOutput,
  output rv32_pkg::lsu_address_input_t addressOutput,
  output logic [3:0] auxiliaryOutput,
  output rv32_pkg::rob_tag_t robTagOutput
);
  import rv32_pkg::*;
  address_generation_output_t sumInner;
  logic validInner;
  logic [31:0] addressInner;
  logic [3:0] auxiliaryInner;
  rob_tag_t robTagInner;

  rv32_agu u_add_address (
    .addressInput('{baseAddress: executeInput.source1Value,
                   offset: executeInput.immediate}),
    .addressOutput(sumInner)
  );

  assign inReadyOutput = 1'b1;
  assign robTagOutput = robTagInner;
  assign auxiliaryOutput = auxiliaryInner;
  assign addressOutput = '{
    valid: validInner && (!flushInfoInput.valid ||
                         rob_is_older(robTagInner, flushInfoInput.robTag)),
    isStore: auxiliaryInner[3],
    robTag: robTagInner,
    address: addressInner
  };

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      validInner <= 1'b0;
      addressInner <= '0;
      auxiliaryInner <= '0;
      robTagInner <= '0;
    end else if (!freezeInput) begin
      // Old payload is consumed using Q[n]; all new fields are captured
      // together. Old cancellation never overrides the incoming tag's keep.
      validInner <= executeInput.valid && (!flushInfoInput.valid ||
          rob_is_older(executeInput.robTag, flushInfoInput.robTag));
      if (executeInput.valid) begin
        addressInner <= sumInner.address;
        auxiliaryInner <= auxiliaryInput;
        robTagInner <= executeInput.robTag;
      end
    end
  end
endmodule
