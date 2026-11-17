// MUL and DIV share one CDB. Load broadcasts on its own independent port.
// Candidates are already live/flush qualified; no extra result register stage.
module rv32_cdb_arbiter (
  input  rv32_pkg::cdb_result_t [1:0] candidateInput,
  input  rv32_pkg::rob_tag_t [1:0] candidateTagInput,
  output rv32_pkg::cdb_result_t resultOutput,
  output rv32_pkg::rob_tag_t robTagOutput,
  output logic [1:0] grantOutput
);
  import rv32_pkg::*;
  logic secondWinsInner;
  assign secondWinsInner = candidateInput[1].valid &&
    (!candidateInput[0].valid || rob_is_older(candidateTagInput[1], candidateTagInput[0]));
  assign grantOutput[0] = candidateInput[0].valid && !secondWinsInner;
  assign grantOutput[1] = secondWinsInner;
  always_comb begin
    resultOutput = '0;
    robTagOutput = '0;
    for (int source = 0; source < 2; source++) begin
      resultOutput.valid |= grantOutput[source];
      resultOutput.phyTag |= candidateInput[source].phyTag & {PHY_TAG_W{grantOutput[source]}};
      resultOutput.value |= candidateInput[source].value & {32{grantOutput[source]}};
      robTagOutput |= candidateTagInput[source] & {ROB_TAG_W{grantOutput[source]}};
    end
  end
endmodule
