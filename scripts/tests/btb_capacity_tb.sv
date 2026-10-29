// Behavioral full-PC/tag model, independent of the RTL's packed entry layout.
module tb_btb_capacity;
  import rv32_pkg::*;
  parameter int DEPTH = 32;
  logic clk = 0, rstN = 0, freeze = 0;
  logic [31:0] query;
  btb_training_input_t training;
  btb_lookup_output_t lookup;
  typedef struct packed {
    logic valid, unconditional, isReturn;
    logic [31:0] pc, target;
  } row_t;
  row_t model [DEPTH];
  int checks = 0, updates = 0, freezes = 0;
  int unsigned randomState = 32'hd174af39;

  rv32_bpu_btb #(.BTB_ENTRIES(DEPTH)) dut (
    .clkInput(clk), .rstNInput(rstN), .freezeInput(freeze),
    .queryPcInput(query), .lookupOutput(lookup), .trainingInput(training)
  );
  function automatic int unsigned random_word();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction
  task automatic check(input logic [31:0] pc);
    int row;
    query = pc; row = int'((pc >> 2) & 32'(DEPTH-1)); #1;
    assert(lookup.hit == (model[row].valid && model[row].pc == pc) &&
      lookup.unconditional == model[row].unconditional &&
      lookup.isReturn == model[row].isReturn && lookup.target == model[row].target)
      else $fatal(1, "BTB capacity/model mismatch depth=%0d pc=%h checks=%0d", DEPTH, pc, checks);
    checks++;
  endtask
  task automatic step;
    #1; clk = 1; #1; clk = 0; #1;
    if (!rstN) begin
      for (int row = 0; row < DEPTH; row++) model[row] = '0;
    end else if (!freeze) begin
      // Apply independent source intents from lowest to highest priority.
      // A metadata-only fetch preserves the resident or lower-writer target.
      if (training.branch.valid && training.branch.taken) begin
        int row;
        row = int'((training.branch.programCounter >> 2) & 32'(DEPTH-1));
        model[row] = '{valid:1'b1, unconditional:1'b0, isReturn:1'b0,
          pc:training.branch.programCounter, target:training.branch.nextProgramCounter};
      end
      if (training.jumpValid) begin
        int row;
        row = int'((training.jumpProgramCounter >> 2) & 32'(DEPTH-1));
        model[row] = '{valid:1'b1, unconditional:1'b1, isReturn:training.jumpIsReturn,
          pc:training.jumpProgramCounter, target:training.jumpTarget};
      end
      if (training.fetchValid) begin
        int row;
        row = int'((training.fetchProgramCounter >> 2) & 32'(DEPTH-1));
        model[row].valid = 1;
        model[row].pc = training.fetchProgramCounter;
        model[row].unconditional = 1;
        model[row].isReturn = training.isReturn;
        if (!training.isReturn && training.jalTargetValid) model[row].target = training.jalTarget;
      end
      updates++;
    end else freezes++;
  endtask
  initial begin
    logic [31:0] firstPc, aliasPc;
    assert($size(dut.btbEntryInner) == DEPTH) else $fatal(1, "BTB physical capacity mismatch");
    training = '0; query = 0; step(); rstN = 1;
    for (int row = 0; row < DEPTH; row++) check(32'(row*4));
    firstPc = 32'h1000; aliasPc = firstPc + 32'(DEPTH*4);
    training.jumpValid = 1; training.jumpProgramCounter = firstPc; training.jumpTarget = 32'h9000;
    check(firstPc); step(); check(firstPc);
    training.jumpProgramCounter = aliasPc; training.jumpTarget = 32'ha000;
    check(firstPc); step(); check(firstPc); check(aliasPc);
    assert(!lookup.isReturn);
    // Force same-index writers with different full tags, then random aliases.
    for (int sample = 0; sample < 1024; sample++) begin
      training = '0;
      training.fetchValid = 1'(random_word());
      training.jumpValid = 1'(random_word());
      training.branch.valid = 1'(random_word());
      training.branch.taken = 1'(random_word());
      training.isReturn = 1'(random_word());
      training.jumpIsReturn = 1'(random_word());
      training.jalTargetValid = 1'(random_word());
      firstPc = random_word() & 32'hfffffffc;
      training.fetchProgramCounter = firstPc;
      training.jumpProgramCounter = sample[0] ? firstPc ^ 32'(DEPTH*4) : random_word() & 32'hfffffffc;
      training.branch.programCounter = sample[1] ? firstPc ^ 32'h80000000 : random_word() & 32'hfffffffc;
      training.jalTarget = random_word() & 32'hfffffffc;
      training.jumpTarget = random_word() & 32'hfffffffc;
      training.branch.nextProgramCounter = random_word() & 32'hfffffffc;
      freeze = sample % 11 == 0;
      check(training.fetchProgramCounter); check(training.jumpProgramCounter); check(training.branch.programCounter);
      step();
      check(training.fetchProgramCounter); check(training.jumpProgramCounter); check(training.branch.programCounter);
      for (int row = 0; row < DEPTH; row++) begin
        check(model[row].pc);
        check(model[row].pc ^ 32'h80000000);
      end
    end
    training = '0; freeze = 0; rstN = 0; step(); rstN = 1;
    for (int row = 0; row < DEPTH; row++) check(32'(row*4));
    assert(checks > 70000 && updates > 900 && freezes > 0);
    $display("PASS BTB capacity depth=%0d checks=%0d updates=%0d freezes=%0d", DEPTH, checks, updates, freezes);
    $finish;
  end
endmodule
