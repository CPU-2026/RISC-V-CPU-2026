module tb_predictor_register;
  import rv32_pkg::*;
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0, freeze = 0, accepted = 0;
  logic [31:0] pc = 32'h4000;
  prediction_output_t prediction;
  predictor_fetch_info_t fetchInfo = '0;
  branch_result_input_t branchInfo = '0;
  jump_result_input_t jumpInfo = '0;
  squash_input_t squash = '0;
  rob_predictor_input_t robInfo = '0;
  rv32_predictor dut (
    .clkInput(clock), .rstNInput(resetN), .freezeInput(freeze), .queryPcInput(pc),
    .predictionOutput(prediction), .fetchAcceptInput(accepted),
    .fetchInfoInput(fetchInfo), .branchInput(branchInfo), .jumpInput(jumpInfo),
    .squashInput(squash), .robInput(robInfo)
  );
  initial begin
    logic [7:0] history;
    repeat (2) @(negedge clock);
    resetN = 1;
    #1;
    assert (!prediction.taken && prediction.nextProgramCounter == pc+4 && prediction.checkpointId == 0);
    fetchInfo = '{valid:1'b1, isCall:1'b0, isReturn:1'b0, jalTargetValid:1'b1,
      programCounter:pc, jalTarget:32'h9000};
    // Training is next-edge visible, never queued and never same-edge bypassed.
    #1; assert (!prediction.taken);
    @(negedge clock);
    fetchInfo = '0;
    #1; assert (prediction.taken && prediction.nextProgramCounter == 32'h9000);
    history = dut.dirGhrInner;
    repeat (3) @(negedge clock);
    assert (prediction.checkpointId == 0 && dut.dirGhrInner == history);
    accepted = 1;
    @(negedge clock);
    accepted = 0;
    #1; assert (prediction.checkpointId == 1 && dut.dirGhrInner == {history[6:0],1'b1});
    history = dut.dirGhrInner;
    freeze = 1;
    accepted = 1;
    fetchInfo = '{valid:1'b1, isCall:1'b1, isReturn:1'b0, jalTargetValid:1'b1,
      programCounter:pc, jalTarget:32'hb000};
    repeat (3) @(negedge clock);
    assert (prediction.checkpointId == 1 && dut.dirGhrInner == history &&
      prediction.nextProgramCounter == 32'h9000 && dut.rasTopInner == 0);
    freeze = 0;
    accepted = 0;
    fetchInfo = '0;
    squash.valid = 1;
    squash.checkpointId = 0;
    @(negedge clock);
    squash = '0;
    #1; assert (dut.dirGhrInner == 0 && prediction.nextProgramCounter == 32'h9000);
    $display("PASS register predictor: combinational lookup, direct training, acceptance-only GHR/checkpoint, freeze, recovery");
    $finish;
  end
  initial begin #10000; $fatal(1,"register predictor timeout"); end
endmodule
