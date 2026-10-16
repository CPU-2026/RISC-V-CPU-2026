// All queries are checked against the register BTB at their acceptance edge.
// Older same-bank intents stall that query; independent-bank writes cannot
// change its row. A simultaneous new training batch is read-before-write.
module tb_btb_sram4 #(parameter int unsigned ENTRIES = 64);
  import rv32_pkg::*;
  localparam int unsigned ROWS = ENTRIES / 4;
  localparam int unsigned TAG_W = 30 - $clog2(ENTRIES);
  localparam int unsigned META_W = TAG_W + 2;
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
  int cycles = 0, queries = 0, responses = 0, batches = 0, completedBatches = 0;
  int cancelledQueries = 0, cancelledBatches = 0, overlaps = 0, tripleWrites = 0;
  int bankConflicts = 0, heldResponses = 0, metadataOnlyWrites = 0, targetWrites = 0;
  logic [31:0] randomState = 32'h4b7b1234;

  rv32_bpu_btb_sram4 #(.BTB_ENTRIES(ENTRIES)) dut (
    .clkInput(clock), .rstNInput(resetN), .queryValidInput(queryValid),
    .queryReadyOutput(queryReady), .queryPcInput(queryPc),
    .responseValidOutput(responseValid), .responseReadyInput(responseReady),
    .responsePcOutput(responsePc), .lookupOutput(lookup),
    .trainingValidInput(trainingValid), .trainingReadyOutput(trainingReady),
    .trainingInput(training), .trainingDoneOutput(trainingDone), .initializedOutput(initialized)
  );
  rv32_bpu_btb_sram4_converted #(.BTB_ENTRIES(ENTRIES)) converted (
    .clkInput(clock), .rstNInput(resetN), .queryValidInput(queryValid),
    .queryReadyOutput(convertedQueryReady), .queryPcInput(queryPc),
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

  for (genvar bank = 0; bank < 4; bank++) begin : g_check
    task automatic poison;
      for (int row = 0; row < ROWS; row++) begin
        dut.g_bank[bank].u_metadata.storage.words[row] = '1;
        dut.g_bank[bank].u_target.storage.words[row] = '1;
        converted.g_bank[bank].u_metadata.storage.words[row] = '1;
        converted.g_bank[bank].u_target.storage.words[row] = '1;
      end
    endtask
    always @(negedge clock) begin
      #1;
      if (resetN && trainingDone) begin
        for (int row = 0; row < ROWS; row++) begin
          logic [TAG_W+31:0] actual, lowered;
          actual = '0;
          lowered = '0;
          if (dut.validInner[row*4+bank])
            actual = {dut.g_bank[bank].u_metadata.storage.words[row][2+:TAG_W],
              dut.targetValidInner[row*4+bank] ? dut.g_bank[bank].u_target.storage.words[row] : 30'b0,
              dut.g_bank[bank].u_metadata.storage.words[row][1:0]};
          if (converted.validInner[row*4+bank])
            lowered = {converted.g_bank[bank].u_metadata.storage.words[row][2+:TAG_W],
              converted.targetValidInner[row*4+bank] ? converted.g_bank[bank].u_target.storage.words[row] : 30'b0,
              converted.g_bank[bank].u_metadata.storage.words[row][1:0]};
          assert (actual === golden.btbEntryInner[row*4+bank] && lowered === actual)
            else $fatal(1, "logical SRAM mismatch bank=%0d row=%0d got=%h expected=%h",
                        bank, row, actual, golden.btbEntryInner[row*4+bank]);
        end
      end
    end
  end

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
          else $fatal(1, "query snapshot mismatch cycle=%0d pc=%h got=%h expected=%h",
                      cycles, responsePc, lookup, expectedLookup);
        if (responseReady) begin pendingQuery = 0; responses++; end
        else heldResponses++;
      end
      if (queryValid && queryReady) begin
        assert (!pendingQuery) else $fatal(1, "query overwrote a blocked response");
        pendingQuery = 1;
        expectedPc = queryPc;
        expectedLookup = goldenLookup;
        queries++;
      end
      if (trainingDone) begin
        assert (pendingTraining) else $fatal(1, "duplicate training completion");
        pendingTraining = 0;
        completedBatches++;
      end
      if (trainingValid && trainingReady) begin
        assert (!pendingTraining) else $fatal(1, "training batch overwritten");
        pendingTraining = 1;
        batches++;
      end
      if ($countones(dut.metaWriteInner) == 3) tripleWrites++;
      if (queryValid && queryReady && |dut.metaWriteInner) overlaps++;
      if (queryValid && !queryReady && dut.trainingActiveInner) bankConflicts++;
      for (int b = 0; b < 4; b++) begin
        if (dut.targetEnableInner[b] && dut.targetWriteInner[b]) targetWrites++;
        if (dut.metaWriteInner[b] && !dut.targetWriteInner[b]) begin
          metadataOnlyWrites++;
          assert (!dut.targetEnableInner[b]) else $fatal(1, "metadata-only update read/rewrote target");
        end
        assert (!(dut.queryGrantInner[b] && dut.metaWriteInner[b]));
      end
    end
  end
  always @(negedge clock) begin
    #1;
    assert ({queryReady,responseValid,responsePc,lookup,trainingReady,trainingDone,initialized} ===
            {convertedQueryReady,convertedResponseValid,convertedResponsePc,convertedLookup,
             convertedTrainingReady,convertedTrainingDone,convertedInitialized})
      else $fatal(1, "four-bank sv2v port equivalence failed cycle=%0d", cycles);
    if (!resetN)
      assert (!initialized && !queryReady && !trainingReady && !responseValid &&
              !(|dut.metaEnableInner) && !(|dut.targetEnableInner))
        else $fatal(1, "SRAM accessed during reset");
  end

  function automatic logic [31:0] random_word();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction
  task automatic reset_btb;
    resetN = 0;
    queryValid = 0;
    trainingValid = 0;
    responseReady = 0;
    g_check[0].poison(); g_check[1].poison(); g_check[2].poison(); g_check[3].poison();
    repeat (2) @(negedge clock);
    resetN = 1;
    #1;
    assert (initialized && queryReady && trainingReady && !(|dut.metaEnableInner) && !(|dut.targetEnableInner))
      else $fatal(1, "valid-bit reset introduced a scan/startup cycle");
    for (int row = 0; row < ENTRIES; row++)
      assert (!dut.validInner[row] && !dut.targetValidInner[row]);
  endtask
  task automatic train_batch(input btb_training_input_t batch);
    int ticks;
    @(negedge clock);
    training = batch; trainingValid = 1;
    do @(posedge clock); while (!trainingReady);
    @(negedge clock);
    trainingValid = 0; training = '1;
    ticks = 0;
    while (!trainingDone) begin
      @(negedge clock); ticks++;
      assert (ticks <= 3) else $fatal(1, "banked batch exceeded three writes");
    end
  endtask
  task automatic finish_query(input int holdCycles = 0);
    queryValid = 0;
    queryPc = ~queryPc;
    assert (responseValid) else $fatal(1, "missing one-cycle SRAM response");
    repeat (holdCycles) @(negedge clock);
    responseReady = 1;
    @(posedge clock);
    @(negedge clock);
    responseReady = 0;
  endtask
  task automatic query(input logic [31:0] pc, input int holdCycles = 0);
    @(negedge clock);
    queryPc = pc; queryValid = 1; responseReady = 0;
    do @(posedge clock); while (!queryReady);
    @(negedge clock);
    finish_query(holdCycles);
  endtask
  task automatic overlap(input btb_training_input_t batch, input logic [31:0] pc);
    @(negedge clock);
    training = batch; trainingValid = 1;
    do @(posedge clock); while (!trainingReady);
    @(negedge clock);
    trainingValid = 0; training = '1;
    queryPc = pc; queryValid = 1; responseReady = 0;
    do @(posedge clock); while (!queryReady);
    @(negedge clock);
    finish_query(2);
    while (!trainingReady) @(negedge clock);
  endtask

  initial begin
    btb_training_input_t batch;
    logic [31:0] fpc, jpc, bpc, bitsInner;
    int beforeTargets;
    @(negedge clock);
    reset_btb();
    for (int row = 0; row < ENTRIES; row++) query(32'h4000 + 32'(row*4));

    batch = '0;
    batch.fetchValid = 1; batch.isReturn = 1; batch.fetchProgramCounter = 32'h4000;
    train_batch(batch);
    query(32'h4000, 4);
    assert (!dut.targetValidInner[0]) else $fatal(1, "first RET fabricated a target");

    // One prediction read and three training writes on DIFFERENT banks.
    batch = '0;
    batch.fetchValid = 1; batch.jalTargetValid = 1;
    batch.fetchProgramCounter = 32'h4000; batch.jalTarget = 32'h8000;
    batch.jumpValid = 1; batch.jumpProgramCounter = 32'h4004; batch.jumpTarget = 32'h9000;
    batch.branch.valid = 1; batch.branch.taken = 1;
    batch.branch.programCounter = 32'h4008; batch.branch.nextProgramCounter = 32'ha000;
    overlap(batch,32'h400c);
    query(32'h4008); // CONDITIONAL must not decode as unconditional.
    if (ROWS >= 3) begin
      batch.jumpProgramCounter = 32'h4010;
      batch.branch.programCounter = 32'h4020;
      overlap(batch,32'h4000); // Three SAME-bank rows: query must wait.
    end

    // Query and a new same-index batch accept together: query sees OLD state.
    @(negedge clock);
    queryPc = 32'h4000; queryValid = 1; responseReady = 0;
    training = '0; training.jumpValid = 1;
    training.jumpProgramCounter = 32'h4000; training.jumpTarget = 32'hb000;
    trainingValid = 1;
    do @(posedge clock); while (!(queryReady && trainingReady));
    @(negedge clock);
    queryValid = 0; trainingValid = 0;
    finish_query(5); // Remains stable while training overwrites the same row.
    query(32'h4000 + 32'(ENTRIES*4)); // tag miss still exposes type/target

    // Every row and target-retaining tag replacement, including upper indices.
    for (int row = 0; row < ENTRIES; row++) begin
      batch = '0; batch.jumpValid = 1;
      batch.jumpProgramCounter = 32'h4000 + 32'(row*4);
      batch.jumpTarget = 32'hc000 + 32'(row*4);
      train_batch(batch);
      beforeTargets = targetWrites;
      batch = '0; batch.fetchValid = 1;
      batch.fetchProgramCounter = 32'h4000 + 32'(ENTRIES*4 + row*4);
      train_batch(batch);
      assert (targetWrites == beforeTargets) else $fatal(1, "metadata update touched target SRAM");
      query(batch.fetchProgramCounter,row%4);
    end

    for (int trial = 0; trial < 300; trial++) begin
      bitsInner = random_word();
      batch = '0;
      batch.fetchValid = bitsInner[0]; batch.isReturn = bitsInner[1]; batch.jalTargetValid = bitsInner[2];
      batch.jumpValid = bitsInner[3]; batch.jumpIsReturn = bitsInner[4];
      batch.branch.valid = bitsInner[5]; batch.branch.taken = bitsInner[6];
      fpc = 32'h4000 + ((random_word() & 32'(ENTRIES*4-1)) << 2);
      jpc = trial%3 == 0 ? fpc + 32'(ENTRIES*4) :
        32'h4000 + ((random_word() & 32'(ENTRIES*4-1)) << 2);
      bpc = trial%5 == 0 ? jpc + 32'(ENTRIES*4) :
        32'h4000 + ((random_word() & 32'(ENTRIES*4-1)) << 2);
      batch.fetchProgramCounter = fpc; batch.jumpProgramCounter = jpc;
      batch.branch.programCounter = bpc;
      batch.jalTarget = random_word(); batch.jumpTarget = random_word();
      batch.branch.nextProgramCounter = random_word();
      overlap(batch,trial%2 == 0 ? fpc : 32'h700c);
      query(fpc); query(jpc); query(bpc,trial%3);
    end
    batch = '0;
    train_batch(batch);
    batch.branch.valid = 1; // not taken: no allocation
    train_batch(batch);

    // Reset cancels BOTH a held response and an accepted, unwritten batch.
    @(negedge clock);
    queryPc = 32'h4000; queryValid = 1; responseReady = 0;
    do @(posedge clock); while (!queryReady);
    @(negedge clock);
    queryValid = 0;
    training = '0; training.jumpValid = 1;
    training.jumpProgramCounter = 32'h4000; training.jumpTarget = 32'hf000;
    trainingValid = 1;
    @(posedge clock);
    @(negedge clock);
    reset_btb();
    query(32'h4000,4);
    batch = '0; batch.fetchValid = 1; batch.fetchProgramCounter = 32'h4000;
    train_batch(batch);
    query(32'h4000,2); // stale pre-reset target must stay masked to zero

    assert (queries == responses + cancelledQueries && batches == completedBatches + cancelledBatches);
    assert (cancelledQueries == 1 && cancelledBatches == 1 && overlaps > 0 && tripleWrites > 0 &&
            heldResponses > 100 && metadataOnlyWrites > 0);
    if (ROWS >= 3) assert (bankConflicts > 0);
    $display("PASS four-bank SRAM BTB entries=%0d cycles=%0d queries=%0d batches=%0d overlap=%0d triple=%0d conflicts=%0d metadata_only=%0d",
             ENTRIES,cycles,queries,batches,overlaps,tripleWrites,bankConflicts,metadataOnlyWrites);
    $finish;
  end
  initial begin #2000000; $fatal(1,"four-bank BTB timeout"); end
endmodule
