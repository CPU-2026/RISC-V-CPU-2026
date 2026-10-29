// Populate real SQ state through ports, then compare the production query with
// a FIFO-order, 64-bit interval oracle. Never force DUT arrays or probe ports.
module tb_lsu_forward_narrow;
  import rv32_pkg::*;
  logic clk = 0, rstN = 0;
  store_allocation_input_t storeAlloc;
  logic storeAllocReady;
  logic [2:0] storeAllocIndex;
  load_allocation_input_t loadAlloc;
  logic loadAllocReady;
  logic [2:0] loadAllocIndex;
  lsu_address_input_t addressPort;
  logic [2:0] addressIndex;
  store_data_input_t storeData [0:0];
  logic [2:0] storeDataIndex [0:0];
  store_commit_input_t [0:0] storeCommit;
  rob_retirement_input_t [0:0] retire;
  logic [0:0][2:0] commitIndex;
  logic [0:0] commitReady;
  data_memory_request_output_t request;
  load_result_output_t loadResult;
  logic memoryReady = 0;

  typedef struct packed {
    logic blocked, cacheBlocked;
    logic [3:0] mask;
    logic [31:0] data;
  } forward_result_t;
  typedef struct packed {
    bit valid, addressReady, dataReady, committed;
    rob_tag_t tag;
    mem_size_e size;
    logic [31:0] address, data;
  } store_model_t;
  store_model_t rows [8];
  int headModel = 0, tailModel = 0;
  int checks = 0, deliveries = 0;
  logic [31:0] digest = 32'h811c9dc5;
  int unsigned randomState = 32'h126fa937;

  rv32_lsu #(.TAGGED_DMEM(1'b1)) dut (
    .clkInput(clk), .rstNInput(rstN), .coreStoppedInput(1'b0), .flushInfoInput('0),
    .loadAllocationInput(loadAlloc), .loadAllocReadyOutput(loadAllocReady), .loadAllocIndexOutput(loadAllocIndex),
    .storeAllocationInput(storeAlloc), .storeAllocReadyOutput(storeAllocReady), .storeAllocIndexOutput(storeAllocIndex),
    .storeDataInput(storeData), .storeDataIndexInput(storeDataIndex),
    .addressInput(addressPort), .addressIndexInput(addressIndex), .writebackInput('0),
    .loadResultOutput(loadResult), .loadResultReadyInput(1'b0), .robRetireInput(retire),
    .storeCompleteOutput(), .storeCommitInput(storeCommit), .storeCommitIndexInput(commitIndex),
    .storeCommitReadyOutput(commitReady), .storeRetirementOutput(),
    .dmemRequestOutput(request), .dmemReqReadyInput(memoryReady), .dmemResponseInput('0),
    .dmemReqTransactionOutput(), .dmemRspTransactionInput(data_transaction_t'(0)),
    .lqCountOutput(), .sqCountOutput()
  );

  function automatic int unsigned random_word();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction

  function automatic int span(input mem_size_e size);
    case (size)
      MEM_BYTE: return 1;
      MEM_HALF: return 2;
      default: return 4;
    endcase
  endfunction

  function automatic forward_result_t reference_query(
    input rob_tag_t loadTag, input logic [31:0] loadAddress, input mem_size_e loadSize
  );
    forward_result_t expected;
    int winner, knownOrder, unknownOrder, slot, age;
    bit overlap;
    longint unsigned la, sa, loadEnd, storeEnd;
    expected = '0;
    winner = -1; knownOrder = -1; unknownOrder = -1;
    la = {32'b0, loadAddress};
    loadEnd = la + 64'(span(loadSize));
    for (int order = 0; order < 8; order++) begin
      slot = (headModel + order) & 7;
      age = (int'(loadTag) - int'(rows[slot].tag)) & 31;
      if (rows[slot].valid && (rows[slot].committed || (age > 0 && age < 16))) begin
        sa = {32'b0, rows[slot].address};
        storeEnd = sa + 64'(span(rows[slot].size));
        overlap = la < storeEnd && sa < loadEnd;
        if (!rows[slot].committed && (!rows[slot].addressReady || overlap))
          expected.cacheBlocked = 1;
        if (!rows[slot].addressReady) unknownOrder = order;
        else if (overlap) begin
          winner = slot;
          knownOrder = order;
        end
      end
    end
    expected.blocked = unknownOrder >= 0 && unknownOrder >= knownOrder;
    if (winner >= 0) begin
      sa = {32'b0, rows[winner].address};
      storeEnd = sa + 64'(span(rows[winner].size));
      if (rows[winner].dataReady && sa <= la && loadEnd <= storeEnd) begin
        expected.mask = loadSize == MEM_BYTE ? 4'b0001 : loadSize == MEM_HALF ? 4'b0011 : 4'b1111;
        expected.data = rows[winner].data >> (8 * int'(la-sa));
      end
    end
    return expected;
  endfunction

  task automatic tick;
    #1; clk = 1; #1; clk = 0; #1;
  endtask

  task automatic reset_lsu(input int head);
    rstN = 0; storeAlloc = '0; loadAlloc = '0; addressPort = '0; addressIndex = 0;
    storeData[0] = '0; storeDataIndex[0] = 0; storeCommit = '0; retire = '0;
    commitIndex = '0; memoryReady = 0;
    for (int i = 0; i < 8; i++) rows[i] = '0;
    headModel = 0; tailModel = 0;
    tick(); rstN = 1; tick();
    // Advance real epoch pointers by allocating, retiring and sending stores.
    for (int i = 0; i < head; i++) begin
      push_store(rob_tag_t'(i), MEM_WORD, 1, 1, 32'h800, 32'h12345678, 1);
      memoryReady = 1; #1;
      assert(request.valid && request.write) else $fatal(1, "head rotation request");
      tick(); memoryReady = 0;
      rows[headModel].valid = 0;
      headModel = (headModel+1) & 7;
    end
  endtask

  task automatic push_store(
    input rob_tag_t tag, input mem_size_e size, input bit addressReady,
    input bit dataReady, input logic [31:0] address, input logic [31:0] data,
    input bit committed
  );
    int slot;
    storeAlloc = '{valid:1'b1, robTag:tag, size:size, dataReady:dataReady,
      dataTag:phy_tag_t'(0), dataValue:data};
    #1;
    assert(storeAllocReady && storeAllocIndex == 3'(tailModel)) else $fatal(1, "SQ allocation");
    slot = int'(storeAllocIndex);
    tick(); storeAlloc = '0;
    rows[slot] = '{valid:1'b1, addressReady:1'b0, dataReady:dataReady, committed:1'b0,
      tag:tag, size:size, address:32'b0, data:dataReady ? data : 32'b0};
    tailModel = (tailModel+1) & 7;
    if (addressReady) begin
      addressIndex = 3'(slot);
      addressPort = '{valid:1'b1, isStore:1'b1, robTag:tag, address:address};
      tick(); addressPort = '0;
      rows[slot].addressReady = 1;
      rows[slot].address = address;
    end
    if (committed) begin
      assert(addressReady && dataReady) else $fatal(1, "invalid test committed Store");
      storeCommit[0] = '{valid:1'b1, robTag:tag};
      retire[0] = '{valid:1'b1, robTag:tag};
      commitIndex[0] = 3'(slot); #1;
      assert(commitReady[0]) else $fatal(1, "SQ commit");
      tick(); storeCommit = '0; retire = '0;
      rows[slot].committed = 1;
    end
    #1;
  endtask

  task automatic check_query(input logic [31:0] address, input mem_size_e size, input rob_tag_t tag);
    forward_result_t actual, expected;
    actual = dut.query_store_forward(tag, address, size);
    expected = reference_query(tag, address, size);
    assert(actual === expected) else $fatal(1,
      "forward mismatch check=%0d address=%h size=%0d tag=%0d actual=%h expected=%h",
      checks, address, size, tag, actual, expected);
    checks++;
    digest = {digest[26:0], digest[31:27]} ^ actual.data ^ {26'b0, actual[37:32]};
  endtask

  task automatic deliver_load(input logic [31:0] address, input mem_size_e size, input rob_tag_t tag);
    forward_result_t expected;
    int slot;
    loadAlloc = '{valid:1'b1, robTag:tag, destinationPhy:phy_tag_t'(40), size:size, isUnsigned:1'b1};
    #1; assert(loadAllocReady) else $fatal(1, "LQ allocation");
    slot = int'(loadAllocIndex);
    tick(); loadAlloc = '0;
    expected = reference_query(tag, address, size);
    addressIndex = 3'(slot);
    addressPort = '{valid:1'b1, isStore:1'b0, robTag:tag, address:address};
    #1; check_query(address, size, tag);
    tick(); addressPort = '0;
    assert(dut.lqResultReadyInner[slot] == (!expected.blocked && expected.mask != 0))
      else $fatal(1, "forward delivery ready slot=%0d", slot);
    if (!expected.blocked && expected.mask != 0)
      assert(dut.lqResultInner[slot] == expected.data) else $fatal(1, "forward delivery raw value");
    deliveries++;
  endtask

  initial begin
    logic [31:0] base, storeAddress, data;
    rob_tag_t queryTag;
    bit ready, committed, addressReady;
    reset_lsu(0);
    check_query(32'hffffffff, MEM_WORD, rob_tag_t'(0));
    // Exhaust all byte offsets, all enum encodings (default is word), both
    // readiness states, tag wrap, every head, and near-zero/high-bit boundaries.
    for (int head = 0; head < 8; head++) begin
      for (int region = 0; region < 5; region++) begin
        case (region)
          0: base = 32'h0;
          1: base = 32'h4;
          2: base = 32'h7ffffffc;
          3: base = 32'hfffffff8;
          default: base = 32'hfffffffc;
        endcase
        for (int offset = 0; offset < 4; offset++) begin
          for (int size = 0; size < 4; size++) begin
            for (int mode = 0; mode < 3; mode++) begin
              reset_lsu(head);
              storeAddress = base + 32'(offset);
              push_store(rob_tag_t'(30), mem_size_e'(size), 1, mode != 0,
                storeAddress, 32'hd380ff21, mode == 2);
              for (int delta = -8; delta <= 8; delta++) begin
                for (int loadSize = 0; loadSize < 4; loadSize++) begin
                  for (int age = 0; age < 4; age++) begin
                    case (age)
                      0: queryTag = rob_tag_t'(31);
                      1: queryTag = rob_tag_t'(0);
                      2: queryTag = rob_tag_t'(30);
                      default: queryTag = rob_tag_t'(14);
                    endcase
                    check_query(storeAddress + 32'(delta), mem_size_e'(loadSize), queryTag);
                  end
                end
              end
            end
          end
        end
      end
    end
    // Multi-source known/unknown/data-late cases, FIFO wrap and committed rows
    // with ROB tags that need not belong to the Load's current half-window.
    for (int round = 0; round < 256; round++) begin
      reset_lsu(round & 7);
      base = round[0] ? 32'hfffffff8 : 32'h7ffffff8;
      for (int s = 0; s < 8; s++) begin
        addressReady = (random_word() % 4 != 0);
        ready = (random_word() % 4 != 0);
        committed = addressReady && ready && (random_word() % 3 == 0);
        storeAddress = base + 32'(random_word() % 24);
        data = random_word();
        push_store(rob_tag_t'(30+s), mem_size_e'(random_word()), addressReady,
          ready, storeAddress, data, committed);
      end
      for (int q = 0; q < 128; q++)
        check_query(base + 32'(random_word() % 24), mem_size_e'(random_word()), rob_tag_t'(random_word()));
    end
    // Younger partial coverage and data-not-ready must not be filtered away.
    reset_lsu(6);
    push_store(rob_tag_t'(29), MEM_WORD, 1, 1, 32'h1000, 32'h11223344, 0);
    push_store(rob_tag_t'(30), MEM_HALF, 1, 1, 32'h1002, 32'h0000aabb, 0);
    check_query(32'h1000, MEM_WORD, rob_tag_t'(31));
    deliver_load(32'h1000, MEM_WORD, rob_tag_t'(31));
    reset_lsu(7);
    push_store(rob_tag_t'(29), MEM_WORD, 1, 1, 32'h1000, 32'h11223344, 0);
    push_store(rob_tag_t'(30), MEM_WORD, 1, 0, 32'h1000, 32'h55667788, 0);
    check_query(32'h1000, MEM_WORD, rob_tag_t'(31));
    deliver_load(32'h1000, MEM_WORD, rob_tag_t'(31));
    for (int youngerUnknown = 0; youngerUnknown < 2; youngerUnknown++) begin
      reset_lsu(6);
      push_store(rob_tag_t'(29), MEM_WORD, !youngerUnknown, 1, 32'h1000, 32'h11223344, 0);
      push_store(rob_tag_t'(30), MEM_WORD, youngerUnknown, 1, 32'h1000, 32'h55667788, 0);
      check_query(32'h1000, MEM_WORD, rob_tag_t'(31));
      deliver_load(32'h1000, MEM_WORD, rob_tag_t'(31));
    end
    // Cross-word, reverse partial overlap, default width and LQ slot 3 capture.
    reset_lsu(0);
    push_store(rob_tag_t'(30), MEM_WORD, 1, 1, 32'h1003, 32'hd380ff21, 0);
    deliver_load(32'h1004, MEM_HALF, rob_tag_t'(31));
    deliver_load(32'h1002, MEM_HALF, rob_tag_t'(0));
    deliver_load(32'h1003, mem_size_e'(3), rob_tag_t'(1));
    deliver_load(32'h1005, MEM_BYTE, rob_tag_t'(2));
    $display("PASS LSU narrow forward checks=%0d deliveries=%0d digest=%h", checks, deliveries, digest);
    $finish;
  end
endmodule
