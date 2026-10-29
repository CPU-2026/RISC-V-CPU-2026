// CDB1 is shared by MUL, DIV and LQ. Candidates are already live/flush
// qualified. Arbitration is combinational: no extra result register stage.
module rv32_cdb_arbiter (
  input  rv32_pkg::cdb_result_t [2:0] candidateInput,
  input  rv32_pkg::rob_tag_t [2:0] candidateTagInput,
  output rv32_pkg::cdb_result_t resultOutput,
  output rv32_pkg::rob_tag_t robTagOutput,
  output logic [2:0] grantOutput
);
  import rv32_pkg::*;
  logic secondWinsInner, thirdWinsInner;
  // The MUL/DIV choice is old-state early. Compare the late Load tag with both
  // old tags in parallel; select one comparison bit, not a muxed ROB tag.
  assign secondWinsInner = candidateInput[1].valid &&
    (!candidateInput[0].valid || rob_is_older(candidateTagInput[1], candidateTagInput[0]));
  assign thirdWinsInner = candidateInput[2].valid &&
    (!(candidateInput[0].valid || candidateInput[1].valid) ||
      (secondWinsInner ? rob_is_older(candidateTagInput[2], candidateTagInput[1]) :
                        rob_is_older(candidateTagInput[2], candidateTagInput[0])));
  assign grantOutput[0] = candidateInput[0].valid && !secondWinsInner && !thirdWinsInner;
  assign grantOutput[1] = secondWinsInner && !thirdWinsInner;
  assign grantOutput[2] = thirdWinsInner;
  always_comb begin
    resultOutput = '0;
    robTagOutput = '0;
    for (int source = 0; source < 3; source++) begin
      resultOutput.valid |= grantOutput[source];
      resultOutput.phyTag |= candidateInput[source].phyTag & {PHY_TAG_W{grantOutput[source]}};
      resultOutput.value |= candidateInput[source].value & {32{grantOutput[source]}};
      robTagOutput |= candidateTagInput[source] & {ROB_TAG_W{grantOutput[source]}};
    end
  end
endmodule
