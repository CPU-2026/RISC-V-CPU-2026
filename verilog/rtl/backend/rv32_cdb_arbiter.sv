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
  always_comb begin
    resultOutput = '0;
    robTagOutput = '0;
    grantOutput = '0;
    for (int source = 0; source < 3; source++) begin
      if (candidateInput[source].valid &&
          (!resultOutput.valid || rob_is_older(candidateTagInput[source], robTagOutput))) begin
        resultOutput = candidateInput[source];
        robTagOutput = candidateTagInput[source];
        grantOutput = '0;
        grantOutput[source] = 1'b1;
      end
    end
  end
endmodule
