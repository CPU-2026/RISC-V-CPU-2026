// Call the production pure combinational helper directly, without depositing
// state into clocked arrays. Tags stay within one legal half-ring ROB window.
module tb_lsu_select_tree #(
  parameter int LQ_DEPTH = 8
);
  import rv32_pkg::*;
  localparam int INDEX_W = $clog2(LQ_DEPTH);
  localparam int HALF_RING = 1 << (ROB_TAG_W-1);
  logic clk = 0, resetN = 0;
  rob_flush_input_t flush;
  store_data_input_t storeData [0:0];
  logic [2:0] storeDataIndex [0:0];
  cdb_result_t [3:0] wb;
  data_memory_request_output_t request;
  int permutation [HALF_RING];
  int tests = 0;
  int unsigned randomState = 32'h71c50329;
  rob_tag_t [LQ_DEPTH-1:0] tags;
  logic [LQ_DEPTH-1:0] eligible, rowValid, addressReady, sent, resultReady;
  logic [ROB_TAG_W+INDEX_W:0] selected;

  rv32_lsu #(.LQ_DEPTH(LQ_DEPTH)) dut (
    .clkInput(clk), .rstNInput(resetN), .coreStoppedInput(1'b0), .flushInfoInput(flush),
    .loadAllocationInput('0), .loadAllocReadyOutput(), .loadAllocIndexOutput(),
    .storeAllocationInput('0), .storeAllocReadyOutput(), .storeAllocIndexOutput(),
    .storeDataInput(storeData), .storeDataIndexInput(storeDataIndex),
    .addressInput('0), .addressIndexInput('0), .writebackInput(wb),
    .loadResultOutput(), .loadResultReadyInput(1'b0), .robRetireInput('0),
    .storeCompleteOutput(), .storeCommitInput('0), .storeCommitIndexInput('0),
    .storeCommitReadyOutput(), .storeRetirementOutput(),
    .dmemRequestOutput(request), .dmemReqReadyInput(1'b0), .dmemResponseInput('0),
    .dmemReqTransactionOutput(), .dmemRspTransactionInput('0), .lqCountOutput(), .sqCountOutput()
  );

  function automatic int unsigned random_word();
    randomState = randomState ^ (randomState << 13);
    randomState = randomState ^ (randomState >> 17);
    randomState = randomState ^ (randomState << 5);
    return randomState;
  endfunction

  function automatic bit older_ref(input rob_tag_t a, input rob_tag_t b);
    int distance;
    distance = (int'(b) - int'(a)) & ((1 << ROB_TAG_W)-1);
    return distance > 0 && distance < HALF_RING;
  endfunction

  task automatic check_current;
    bit found, candidate, live;
    int winner;
    found = 0;
    winner = 0;
    for (int i = 0; i < LQ_DEPTH; i++) begin
      candidate = rowValid[i] && addressReady[i] && !sent[i] && !resultReady[i];
      if (candidate && (!found || older_ref(tags[i], tags[winner]))) begin
        found = 1;
        winner = i;
      end
    end
    eligible = rowValid & addressReady & ~sent & ~resultReady;
    selected = dut.select_oldest_load(eligible, tags);
    assert(selected[ROB_TAG_W+INDEX_W] == found && selected[INDEX_W-1:0] == INDEX_W'(winner))
      else $fatal(1, "selector mismatch depth=%0d test=%0d expected=%0d/%0d actual=%0d/%0d",
        LQ_DEPTH, tests, found, winner, selected[ROB_TAG_W+INDEX_W], selected[INDEX_W-1:0]);
    if (found)
      assert(selected[INDEX_W+:ROB_TAG_W] == tags[winner]) else $fatal(1, "winner tag lost");
    #1;
    tests++;
  endtask

  task automatic set_mask(input int mask, input int base, input bit reverse_order, input bit ties);
    for (int i = 0; i < LQ_DEPTH; i++) begin
      tags[i] = rob_tag_t'(base + (ties ? 0 : reverse_order ? LQ_DEPTH-1-i : i));
      rowValid[i] = 1;
      addressReady[i] = 1;
      sent[i] = 0;
      resultReady[i] = 0;
      if (!(mask & (1 << i))) begin
        // Exercise every term of the candidate predicate, not just valid.
        case ((i + base) & 3)
          0: rowValid[i] = 0;
          1: addressReady[i] = 0;
          2: sent[i] = 1;
          3: resultReady[i] = 1;
        endcase
      end
    end
    flush.valid = (base & 1) != 0;
    flush.robTag = rob_tag_t'(base + (LQ_DEPTH >> 1));
  endtask

  initial begin
    flush = '0; wb = '0; storeData[0] = '0; storeDataIndex[0] = 0;
    #1; resetN = 1; #1;
    for (int base = 0; base < (1 << ROB_TAG_W); base++) begin
      for (int mask = 0; mask < (1 << LQ_DEPTH); mask++) begin
        set_mask(mask, base, 0, 0); check_current();
        set_mask(mask, base, 1, 0); check_current();
        set_mask(mask, base, 0, 1); check_current();
      end
    end
    for (int trial = 0; trial < 2000; trial++) begin
      int base, mask, other, temp;
      base = int'(random_word() & ((1 << ROB_TAG_W)-1));
      mask = int'(random_word() & ((1 << LQ_DEPTH)-1));
      for (int i = 0; i < HALF_RING; i++) permutation[i] = i;
      for (int i = HALF_RING-1; i > 0; i--) begin
        other = int'(random_word() % (i+1));
        temp = permutation[i]; permutation[i] = permutation[other]; permutation[other] = temp;
      end
      set_mask(mask, base, 0, 0);
      for (int i = 0; i < LQ_DEPTH; i++) tags[i] = rob_tag_t'(base+permutation[i]);
      check_current();
    end
    $display("PASS LSU select tree depth=%0d cases=%0d: masks/status/epoch/order/ties/winner-tag", LQ_DEPTH, tests);
    $finish;
  end
endmodule
