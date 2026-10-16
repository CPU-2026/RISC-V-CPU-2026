// Standalone naive SRAM BTB boundary; not selected by the production CPU list.
module student_top (
  input logic clock,
  input logic reset,
  input logic queryValidInput,
  output logic queryReadyOutput,
  input logic [31:0] queryPcInput,
  output logic responseValidOutput,
  input logic responseReadyInput,
  output logic [31:0] responsePcOutput,
  output rv32_pkg::btb_lookup_output_t lookupOutput,
  input logic trainingValidInput,
  output logic trainingReadyOutput,
  input rv32_pkg::btb_training_input_t trainingInput,
  output logic trainingDoneOutput,
  output logic initializedOutput
);
  rv32_bpu_btb_sram btb (
    .clkInput(clock), .rstNInput(!reset),
    .queryValidInput(queryValidInput), .queryReadyOutput(queryReadyOutput),
    .queryPcInput(queryPcInput), .responseValidOutput(responseValidOutput),
    .responseReadyInput(responseReadyInput), .responsePcOutput(responsePcOutput),
    .lookupOutput(lookupOutput), .trainingValidInput(trainingValidInput),
    .trainingReadyOutput(trainingReadyOutput), .trainingInput(trainingInput),
    .trainingDoneOutput(trainingDoneOutput), .initializedOutput(initializedOutput)
  );
endmodule
