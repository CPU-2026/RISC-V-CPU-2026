// One registered address result. An LSQ entry was reserved at instruction
// issue, so its address-update port has no capacity backpressure. Each old
// result is delivered or cancelled while the next dispatch refills the stage.
module rv32_agu_unit (
  input  logic clkInput,
  input  logic rstNInput,
  input logic freezeInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,
/* verilator lint_off UNUSEDSIGNAL */   input  rv32_pkg::rs_issue_output_t executeInput, /* verilator lint_on UNUSEDSIGNAL */
  input  logic [rv32_pkg::LSQ_SLOT_W:0] auxiliaryInput,
  output logic inReadyOutput,
  output rv32_pkg::lsu_address_input_t addressOutput,
  output logic [rv32_pkg::LSQ_SLOT_W:0] auxiliaryOutput,
  output rv32_pkg::rob_tag_t robTagOutput
);
  import rv32_pkg::*;
  address_generation_output_t sumInner;
  logic [15:0] lowSumInner, highZeroSumInner, highOneSumInner;
  logic lowCarryInner;
  /* verilator lint_off UNUSEDSIGNAL */
  logic highZeroCarryInner, highOneCarryInner;
  /* verilator lint_on UNUSEDSIGNAL */
  logic validInner;
  logic [31:0] addressInner;
  logic [LSQ_SLOT_W:0] auxiliaryInner;
  rob_tag_t robTagInner;

  // Carry-independent half sums; finish selection before the old edge.
  // No arithmetic or new selection logic is placed after addressInner.
  rv32_add #(.WIDTH(16)) u_add_low (
    .aInput(executeInput.source1Value[15:0]),
    .bInput(executeInput.immediate[15:0]), .cinInput(1'b0),
    .sumOutput(lowSumInner), .coutOutput(lowCarryInner)
  );
  rv32_add #(.WIDTH(16)) u_add_high_zero (
    .aInput(executeInput.source1Value[31:16]),
    .bInput(executeInput.immediate[31:16]), .cinInput(1'b0),
    .sumOutput(highZeroSumInner), .coutOutput(highZeroCarryInner)
  );
  rv32_add #(.WIDTH(16)) u_add_high_one (
    .aInput(executeInput.source1Value[31:16]),
    .bInput(executeInput.immediate[31:16]), .cinInput(1'b1),
    .sumOutput(highOneSumInner), .coutOutput(highOneCarryInner)
  );
  assign sumInner.address = {
    lowCarryInner ? highOneSumInner : highZeroSumInner, lowSumInner
  };

  assign inReadyOutput = 1'b1;
  assign robTagOutput = robTagInner;
  assign auxiliaryOutput = auxiliaryInner;
  assign addressOutput = '{
    valid: validInner && (!flushInfoInput.valid ||
                         rob_is_older(robTagInner, flushInfoInput.robTag)),
    isStore: auxiliaryInner[LSQ_SLOT_W],
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
