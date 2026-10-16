// Transaction-level oracle: the original register BTB trains once per accepted
// batch. Queries wait for the SRAM batch to finish, then must match every bit.
module tb_btb_sram #(
  parameter int unsigned ENTRIES = 64
);
  import rv32_pkg::*;
  logic clock = 0;
  always #5 clock = ~clock;
  logic resetN = 0;
  logic queryValid = 0, queryReady, responseValid, responseReady = 0;
  logic trainingValid = 0, trainingReady, trainingDone, initialized;
  logic [31:0] queryPc = 0, responsePc;
  btb_lookup_output_t lookup, goldenLookup;
  btb_training_input_t training = '0, goldenTraining;

  logic convertedQueryReady, convertedResponseValid, convertedTrainingReady;
  logic convertedTrainingDone, convertedInitialized;
  logic [31:0] convertedResponsePc;
  btb_lookup_output_t convertedLookup;

  logic pendingQuery = 0, pendingTraining = 0;
  logic [31:0] expectedPc;
  btb_lookup_output_t expectedLookup;
  int queries = 0, responses = 0, batches = 0, completedBatches = 0;
  int cancelledQueries = 0, cancelledBatches = 0, resets = 0;
  int cycles = 0, stalledResponses = 0, readModifyWrites = 0;
  logic [31:0] randomState = 32'hb7b51234;

  rv32_bpu_btb_sram #(.BTB_ENTRIES(ENTRIES)) dut (
    .clkInput(clock), .rstNInput(resetN),
    .queryValidInput(queryValid), .queryReadyOutput(queryReady), .queryPcInput(queryPc),
    .responseValidOutput(responseValid), .responseReadyInput(responseReady),
    .responsePcOutput(responsePc), .lookupOutput(lookup),
    .trainingValidInput(trainingValid), .trainingReadyOutput(trainingReady),
    .trainingInput(training), .trainingDoneOutput(trainingDone), .initializedOutput(initialized)
  );
  rv32_bpu_btb_sram_converted #(.BTB_ENTRIES(ENTRIES)) converted (
    .clkInput(clock), .rstNInput(resetN),
    .queryValidInput(queryValid), .queryReadyOutput(convertedQueryReady), .queryPcInput(queryPc),
    .responseValidOutput(convertedResponseValid), .responseReadyInput(responseReady),
    .responsePcOutput(convertedResponsePc), .lookupOutput(convertedLookup),
    .trainingValidInput(trainingValid), .trainingReadyOutput(convertedTrainingReady),
    .trainingInput(training), .trainingDoneOutput(convertedTrainingDone),
    .initializedOutput(convertedInitialized)
  );
  always_comb begin
    goldenTraining = '0;
    if (resetN && trainingValid && trainingReady) goldenTraining = training;
  end
  rv32_bpu_btb #(.BTB_ENTRIES(ENTRIES)) golden (
    .freezeInput(1'b0),
    .clkInput(clock), .rstNInput(resetN), .queryPcInput(queryPc),
    .lookupOutput(goldenLookup), .trainingInput(goldenTraining)
  );

  always @(posedge clock) begin
    cycles++;
    if (!resetN) begin
      if (pendingQuery) cancelledQueries++;
      if (pendingTraining) cancelledBatches++;
      pendingQuery = 0;
      pendingTraining = 0;
    end else begin
      if (responseValid) begin
        assert (pendingQuery && responsePc === expectedPc && lookup === expectedLookup)
          else $fatal(1, "response mismatch cycle=%0d pc=%h expected_pc=%h got=%h expected=%h",
                      cycles, responsePc, expectedPc, lookup, expectedLookup);
        if (responseReady) begin
          pendingQuery = 0;
          responses++;
        end else stalledResponses++;
      end
      if (queryValid && queryReady) begin
        assert (!pendingQuery && !pendingTraining) else $fatal(1, "query overlapped an operation");
        pendingQuery = 1;
        expectedPc = queryPc;
        expectedLookup = goldenLookup;
        queries++;
      end
      if (trainingDone) begin
        assert (pendingTraining) else $fatal(1, "unexpected training completion");
        pendingTraining = 0;
        completedBatches++;
      end
      if (trainingValid && trainingReady) begin
        assert (!pendingTraining && !pendingQuery) else $fatal(1, "training overlapped an operation");
        pendingTraining = 1;
        batches++;
      end
      if (pendingTraining && dut.sramEnableInner && !dut.sramWriteInner) readModifyWrites++;
    end
  end

  always @(negedge clock) begin
    #1;
    assert ({queryReady, responseValid, responsePc, lookup, trainingReady, trainingDone, initialized} ===
            {convertedQueryReady, convertedResponseValid, convertedResponsePc, convertedLookup,
             convertedTrainingReady, convertedTrainingDone, convertedInitialized})
      else $fatal(1, "sv2v port equivalence failed cycle=%0d", cycles);
    if (!resetN || !initialized)
      assert (!queryReady && !trainingReady && !responseValid && !trainingDone)
        else $fatal(1, "operation visible during reset/initialization");
    if (resetN && trainingDone) begin
      // Compare every bit, including non-query fields and different-index
      // simultaneous producer writes. Neither DUT may keep a shadow flop table.
      for (int row = 0; row < ENTRIES; row++) begin
        assert (dut.u_btb.storage.words[row] === golden.btbEntryInner[row])
          else $fatal(1, "SRAM row mismatch row=%0d batch=%0d", row, batches);
        assert (converted.u_btb.storage.words[row] === golden.btbEntryInner[row])
          else $fatal(1, "converted SRAM row mismatch row=%0d batch=%0d", row, batches);
      end
    end
  end

  function automatic logic [31:0] next_random();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction

  // Called at a falling edge. Poison the real macro, not a fake register
  // mirror; the reset scanner must clear exactly ENTRIES rows on every reset.
  task automatic reset_btb;
    int ticks;
    resetN = 0;
    queryValid = 0;
    trainingValid = 0;
    responseReady = 0;
    resets++;
    for (int row = 0; row < ENTRIES; row++) begin
      dut.u_btb.storage.words[row] = '1;
      converted.u_btb.storage.words[row] = '1;
    end
    repeat (2) @(negedge clock);
    resetN = 1;
    ticks = 0;
    while (!initialized) begin
      @(posedge clock);
      #1;
      ticks++;
      assert (ticks <= ENTRIES) else $fatal(1, "initialization took too long");
    end
    assert (ticks == ENTRIES) else $fatal(1, "initialization skipped rows: %0d", ticks);
    for (int row = 0; row < ENTRIES; row++)
      assert (dut.u_btb.storage.words[row] === '0 && converted.u_btb.storage.words[row] === '0)
        else $fatal(1, "poison survived reset row=%0d", row);
    @(negedge clock);
  endtask

  task automatic train_batch(input btb_training_input_t batch, input bit contend = 0);
    int ticks;
    @(negedge clock);
    training = batch;
    trainingValid = 1;
    queryValid = contend;
    queryPc = 32'h1234;
    do @(posedge clock); while (!trainingReady);
    assert (!queryReady) else $fatal(1, "query defeated training priority");
    @(negedge clock);
    trainingValid = 0;
    queryValid = 0;
    training = '1; // Live producer changes must not corrupt the captured batch.
    ticks = 0;
    while (!trainingDone) begin
      assert (!queryReady && !trainingReady) else $fatal(1, "partial batch exposed to a query");
      @(negedge clock);
      ticks++;
      assert (ticks <= 4) else $fatal(1, "training batch did not finish");
    end
    assert (ticks == 3 || ticks == 4) else $fatal(1, "unexpected training latency %0d", ticks);
  endtask

  task automatic query(input logic [31:0] pc, input int holdCycles = 0, input bit contend = 0);
    @(negedge clock);
    queryPc = pc;
    queryValid = 1;
    responseReady = 0;
    do @(posedge clock); while (!queryReady);
    @(negedge clock);
    queryValid = 0;
    queryPc = ~pc; // The response must retain the accepted PC/tag.
    assert (responseValid) else $fatal(1, "synchronous lookup was not visible after its read edge");
    for (int i = 0; i < holdCycles; i++) begin
      trainingValid = contend;
      training = '1;
      queryValid = contend;
      #1;
      assert (!queryReady && !trainingReady && responseValid)
        else $fatal(1, "blocked response did not retain ownership");
      @(negedge clock);
    end
    responseReady = 1;
    @(posedge clock);
    @(negedge clock);
    responseReady = 0;
    trainingValid = 0;
    queryValid = 0;
    #1;
    assert (!responseValid) else $fatal(1, "response was repeated after acceptance");
  endtask

  initial begin
    btb_training_input_t batch;
    logic [31:0] fpc, jpc, bpc, bitsInner;
    int jumpSlot, branchSlot;
    @(negedge clock);
    reset_btb();
    for (int row = 0; row < ENTRIES; row++) query(32'h1000 + 32'(row * 4));

    // A first JALR/RET with no static or resolved target must retain the
    // reset zero target, not the macro's poisoned power-up contents.
    batch = '0;
    batch.fetchValid = 1;
    batch.isReturn = 1;
    batch.fetchProgramCounter = 32'h1000;
    train_batch(batch, 1);
    query(32'h1000, 7, 1);
    query(32'h1000 + 32'(ENTRIES * 4), 3); // tag miss with ungated return/target fields

    // All five index partitions of F/J/B, three fetch kinds, both jump kinds,
    // and taken/not-taken branch training. Distinct tags share physical slots.
    for (int partition = 0; partition < 5; partition++) begin
      jumpSlot = (partition == 2 || partition == 4) ? 1 : 0;
      branchSlot = (partition == 1 || partition == 4) ? (ENTRIES > 2 ? 2 : 1) :
                   (partition == 2 || partition == 3 ? 1 : 0);
      for (int kind = 0; kind < 3; kind++) begin
        for (int jumpReturn = 0; jumpReturn < 2; jumpReturn++) begin
          for (int taken = 0; taken < 2; taken++) begin
            fpc = 32'h1000;
            jpc = fpc + 32'(ENTRIES * 4 + jumpSlot * 4);
            bpc = fpc + 32'(ENTRIES * 8 + branchSlot * 4);
            batch = '0;
            batch.fetchValid = 1;
            batch.fetchProgramCounter = fpc;
            batch.isReturn = kind == 2;
            batch.jalTargetValid = kind == 0;
            batch.jalTarget = 32'h8003;
            batch.jumpValid = 1;
            batch.jumpProgramCounter = jpc;
            batch.jumpTarget = 32'h9001;
            batch.jumpIsReturn = 1'(jumpReturn);
            batch.branch.valid = 1;
            batch.branch.taken = 1'(taken);
            batch.branch.programCounter = bpc;
            batch.branch.nextProgramCounter = 32'ha002;
            train_batch(batch, 1);
            query(fpc);
            query(jpc);
            query(bpc);
          end
        end
      end
    end

    // Populate every row, then preserve its resident target while changing
    // the tag/type without a static target or another matching producer.
    for (int row = 0; row < ENTRIES; row++) begin
      batch = '0;
      batch.jumpValid = 1;
      batch.jumpProgramCounter = 32'h4000 + 32'(row * 4);
      batch.jumpTarget = 32'hc000 + 32'(row * 4);
      train_batch(batch);
      batch = '0;
      batch.fetchValid = 1;
      batch.fetchProgramCounter = 32'h4000 + 32'(ENTRIES * 4 + row * 4);
      train_batch(batch);
      query(batch.fetchProgramCounter, row % 3);
    end
    batch = '0;
    train_batch(batch); // empty outer-valid batch is acknowledged, not wedged
    batch.branch.valid = 1;
    batch.branch.taken = 0;
    train_batch(batch); // a not-taken conditional cannot allocate a BTB entry

    for (int trial = 0; trial < 300; trial++) begin
      batch = '0;
      bitsInner = next_random();
      batch.fetchValid = bitsInner[0];
      batch.isReturn = bitsInner[1];
      batch.jalTargetValid = bitsInner[2];
      batch.jumpValid = bitsInner[3];
      batch.jumpIsReturn = bitsInner[4];
      batch.branch.valid = bitsInner[5];
      batch.branch.taken = bitsInner[6];
      batch.fetchProgramCounter = 32'h1000 + ((next_random() & 32'(ENTRIES * 4 - 1)) << 2);
      batch.jumpProgramCounter = 32'h1000 + ((next_random() & 32'(ENTRIES * 4 - 1)) << 2);
      batch.branch.programCounter = 32'h1000 + ((next_random() & 32'(ENTRIES * 4 - 1)) << 2);
      batch.jalTarget = next_random();
      batch.jumpTarget = next_random();
      batch.branch.nextProgramCounter = next_random();
      train_batch(batch, 1'(trial % 2));
      query(batch.fetchProgramCounter, trial % 5, 1'(trial % 2));
      query(batch.jumpProgramCounter);
      query(batch.branch.programCounter);
    end

    // Reset kills an unconsumed response; no ghost completion may escape.
    @(negedge clock);
    queryPc = 32'h1000;
    queryValid = 1;
    do @(posedge clock); while (!queryReady);
    @(negedge clock);
    assert (responseValid) else $fatal(1, "missing response before reset");
    reset_btb();
    query(32'h1000);

    // Reset between a no-target fetch's read and write cancels the batch.
    @(negedge clock);
    training = '0;
    training.fetchValid = 1;
    training.fetchProgramCounter = 32'h5000;
    trainingValid = 1;
    do @(posedge clock); while (!trainingReady);
    @(negedge clock);
    trainingValid = 0;
    assert (dut.sramEnableInner && !dut.sramWriteInner) else $fatal(1, "RMW read was not issued");
    @(posedge clock);
    @(negedge clock);
    assert (dut.sramEnableInner && dut.sramWriteInner) else $fatal(1, "RMW write phase missing");
    reset_btb();
    query(32'h5000);

    // Another reset interrupts the scanner itself, which must restart at row 0.
    resetN = 0;
    repeat (2) @(negedge clock);
    resetN = 1;
    @(posedge clock);
    @(negedge clock);
    assert (!initialized) else $fatal(1, "scanner completed too early");
    reset_btb();
    query(32'h1000, 2);
    assert (queries == responses + cancelledQueries && batches == completedBatches + cancelledBatches)
      else $fatal(1, "lost/duplicate transaction: query=%0d response=%0d cancel=%0d batch=%0d done=%0d cancel=%0d",
                  queries, responses, cancelledQueries, batches, completedBatches, cancelledBatches);
    assert (cancelledQueries == 1 && cancelledBatches == 1 && stalledResponses > 100 && readModifyWrites > 0)
      else $fatal(1, "insufficient reset/backpressure/RMW coverage");
    $display("PASS naive SRAM BTB entries=%0d cycles=%0d queries=%0d batches=%0d stalls=%0d rmw=%0d resets=%0d",
             ENTRIES, cycles, queries, batches, stalledResponses, readModifyWrites, resets);
    $finish;
  end
  initial begin #2000000; $fatal(1, "SRAM BTB test timeout"); end
endmodule
