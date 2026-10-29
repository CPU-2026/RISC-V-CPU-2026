// Software main-tree nonblocking SRAM D$: eight TOTAL request credits (including
// MSHR owners), four misses, pre-first-fill same-line Load merging. All decisions
// read old state, except an idle accepted Load may launch its SRAM read.
// Fill > Store > lookup on real single-port SRAMs.
// CPU transaction names an immutable LSU transport owner, NOT an MSHR or LQ row.
// Cancelled transports still complete once; the LSU suppresses their writeback.
module rv32_dcache #(
  parameter int unsigned SETS = rv32_pkg::DCACHE_SETS,
  parameter int unsigned WAYS = rv32_pkg::DCACHE_WAYS
) (
  input logic clkInput, rstNInput,
  input rv32_pkg::dcache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::dcache_cpu_response_output_t cpuResponseOutput,
  output rv32_pkg::dcache_line_request_output_t memRequestOutput,
  input logic memReadReadyInput, memWriteReadyInput,
  input rv32_pkg::dcache_line_response_input_t memResponseInput,
  input rv32_pkg::dcache_write_response_input_t memWriteResponseInput,
  output logic memRspReadyOutput, memWriteRspReadyOutput,
  output logic initializedOutput, idleOutput,
  input logic exitReadyInput,
  output logic exitValidOutput,
  output logic [31:0] exitValueOutput
);
  import rv32_pkg::*;
  localparam int INDEX_W = $clog2(SETS);
  localparam int OFFSET_W = $clog2(DCACHE_LINE_BYTES);
  localparam int TAG_W = 32 - INDEX_W - OFFSET_W;
  localparam int META_W = TAG_W + 1;
  localparam int WORDS_PER_LINE = DCACHE_LINE_BYTES / 4;
  localparam int FILL_WORDS_PER_BEAT = WORDS_PER_LINE > 1 ? 2 : 1;
  localparam int WORD_INDEX_W = $clog2(WORDS_PER_LINE) + 1;
  localparam int WAY_W = WAYS > 1 ? $clog2(WAYS) : 1;
  localparam int PLRU_W = WAYS > 2 ? 3 : 1;
  localparam int REQUEST_DEPTH = DATA_REQUEST_ENTRIES;
  localparam int REQUEST_W = $clog2(REQUEST_DEPTH);
  localparam int COUNT_W = $clog2(REQUEST_DEPTH+1);
  localparam int MSHR_DEPTH = 4;

  typedef struct packed {
    dcache_cpu_request_input_t request;
    logic [WAY_W-1:0] way;
    logic [1:0] miss;
    logic hasMiss, active, ready, deferred;
  } request_entry_t;
  typedef struct packed {
    logic [31:0] line;
    logic [TAG_W-1:0] victimTag;
    logic [REQUEST_W-1:0] owner;
    logic [WAY_W-1:0] way;
    logic [WORD_INDEX_W-1:0] fillWord;
    logic valid, dirty, readSent, writeSent, writeDone, responded;
  } miss_entry_t;
  request_entry_t requestInner [REQUEST_DEPTH];
  miss_entry_t missesInner [MSHR_DEPTH];
  logic [31:0] rawInner [REQUEST_DEPTH];
  logic [DCACHE_LINE_BITS-1:0] victimPayloadInner [MSHR_DEPTH];
  logic [OFFSET_W:0] byteEndInner [REQUEST_DEPTH];
  logic [REQUEST_DEPTH-1:0] storeHazardInner, storeAllocationHazardInner;
  logic [REQUEST_DEPTH-1:0] olderInner [REQUEST_DEPTH];
  logic [COUNT_W-1:0] countInner;
  logic [REQUEST_W-1:0] cursorInner, readIndexInner;
  logic readValidInner;
  logic acceptLookupInner;
  logic [OFFSET_W-1:0] readLookupAddressInner;
  logic [1:0] readLookupSizeInner;
  dcache_cpu_request_input_t readLookupRequestInner;
  logic [WAYS-1:0] readWayMaskInner;
  logic validInner [SETS][WAYS];
  logic [PLRU_W-1:0] plruInner [SETS];
  logic [31:0] dataRdataBankInner [WAYS][WORDS_PER_LINE];
  logic [31:0] dataWdataBankInner [WAYS][WORDS_PER_LINE];
  logic [3:0] dataMaskBankInner [WAYS][WORDS_PER_LINE];
  logic dataEnableBankInner [WAYS][WORDS_PER_LINE];
  logic dataWriteBankInner [WAYS][WORDS_PER_LINE];
  logic metaEnableInner [WAYS], metaWriteInner [WAYS];
  logic [META_W-1:0] metaRdataInner [WAYS], metaWdataInner;
  logic [INDEX_W-1:0] dataAddressBankInner [WAYS][WORDS_PER_LINE];
  logic [INDEX_W-1:0] metaAddressInner [WAYS];
  logic [INDEX_W-1:0] lookupAddressInner;
`ifndef SYNTHESIS
  // Logical grant address retained for existing read-only test probes. It is
  // not a hardware broadcast: every enabled physical port is checked below.
  logic [INDEX_W-1:0] sramAddressInner;
  always_comb begin
    sramAddressInner = '0;
    if (rstNInput && fillBeatInner)
      sramAddressInner = set_of(missesInner[fillMissInner].line);
    else if (rstNInput && storeInner >= 0)
      sramAddressInner = set_of(requestInner[storeInner].request.address);
    else if (rstNInput && lookupInner >= 0)
      sramAddressInner = set_of(requestInner[lookupInner].request.address);
    else if (rstNInput && acceptLookupInner)
      sramAddressInner = set_of(cpuRequestInput.address);
  end
`endif
  logic [REQUEST_DEPTH-1:0] activeInner, releasedInner;
  integer firstInner, hitWayInner, freeMissInner, allocationInner;
  integer lookupInner, lookupCandidateInner, responseInner, storeInner, allocateMissInner;
  integer normalResponseInner;
  integer mergeSlotInner, mergeMissInner, fillMissInner, writeAckInner;
  integer readMissInner, writeMissInner;
  logic fillBeatInner, fillFireInner, firstFillInner, earlyInner, acceptInner;
  logic [31:0] readHitRawInner;
  logic [MSHR_DEPTH-1:0] fillCanRespondInner;
  data_transaction_t fillTransactionInner [MSHR_DEPTH];
  data_transaction_t normalTransactionInner;
  data_transaction_t bufferedTransactionInner, hitTransactionInner;
  logic [REQUEST_DEPTH-1:0] normalWinnerInner;
  logic [REQUEST_DEPTH-1:0] normalBufferedMaskInner, normalBufferedWinnerInner;
  logic [REQUEST_DEPTH-1:0] normalHitEligibleInner;
  logic normalHitWinsInner;
  logic [31:0] normalReadDataInner;
  logic [WAY_W-1:0] victimWayInner;

  function automatic int bytes_for_size(input logic [1:0] sizeInput);
    case (sizeInput)
      MEM_BYTE: return 1;
      MEM_HALF: return 2;
      default: return 4;
    endcase
  endfunction
  function automatic logic [INDEX_W-1:0] set_of(input logic [31:0] address);
    return address[OFFSET_W+:INDEX_W];
  endfunction
  function automatic logic [31:0] line_of(input logic [31:0] address);
    return {address[31:OFFSET_W], {OFFSET_W{1'b0}}};
  endfunction
  function automatic logic [31:0] victim_address(input int m);
    return {missesInner[m].victimTag, missesInner[m].line[OFFSET_W+:INDEX_W], {OFFSET_W{1'b0}}};
  endfunction
  function automatic logic [31:0] extract_raw(
    input logic [DCACHE_LINE_BITS-1:0] lineData,
    input dcache_cpu_request_input_t request
  );
    // Byte-granular extract as word-select + 4-way byte rotate. Bit-identical to
    // lineData >> (offset*8): the 64-bit zero pad reproduces the shift's
    // fill-with-zero past the line end, and the size case truncates the window.
    logic [DCACHE_LINE_BITS+63:0] padded;
    logic [63:0] pair;
    logic [31:0] win;
    padded = {64'b0, lineData};
    pair = padded[{request.address[OFFSET_W-1:2], 2'b00} * 8 +: 64];
    unique case (request.address[1:0])
      2'd0: win = pair[31:0];
      2'd1: win = {pair[39:32], pair[31:8]};
      2'd2: win = {pair[47:32], pair[31:16]};
      default: win = {pair[55:32], pair[31:24]};
    endcase
    case (request.size)
      MEM_BYTE: return {24'b0, win[7:0]};
      MEM_HALF: return {16'b0, win[15:0]};
      default: return win;
    endcase
  endfunction
  function automatic logic [DCACHE_LINE_BITS-1:0] sram_line(input int way);
    for (int b = 0; b < WORDS_PER_LINE; b++)
      sram_line[b*32+:32] = dataRdataBankInner[way][b];
  endfunction
  function automatic int oldest_request(input logic [REQUEST_DEPTH-1:0] mask);
    logic prior;
    oldest_request = -1;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      prior = 0;
      for (int j = 0; j < REQUEST_DEPTH; j++)
        if (mask[j] && olderInner[j][i]) prior = 1;
      if (mask[i] && !prior) oldest_request = i;
    end
  endfunction
  function automatic int oldest_miss(input logic [3:0] mask);
    logic [REQUEST_DEPTH-1:0] owners;
    int owner;
    logic prior;
    owners = 0;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (mask[m]) owners[missesInner[m].owner] = 1;
    // Keep state-reading helpers leaf functions: Yosys cannot elaborate nested
    // function calls whose arguments reference module memories after sv2v.
    owner = -1;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      prior = 0;
      for (int j = 0; j < REQUEST_DEPTH; j++)
        if (owners[j] && olderInner[j][i]) prior = 1;
      if (owners[i] && !prior) owner = i;
    end
    oldest_miss = -1;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (mask[m] && int'(missesInner[m].owner) == owner) oldest_miss = m;
  endfunction
  function automatic int find_miss(input logic [31:0] lineAddress);
    find_miss = -1;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (missesInner[m].valid && missesInner[m].line == lineAddress) find_miss = m;
  endfunction
  function automatic logic set_locked(input logic [31:0] address);
    set_locked = 0;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (missesInner[m].valid && missesInner[m].line[OFFSET_W+:INDEX_W] == address[OFFSET_W+:INDEX_W]) set_locked = 1;
  endfunction
  // One shared hazard network. Legal requests stay within one cache line, so
  // overlap needs a line equality and small offset comparisons, not per-pair
  // full-width subtraction. Miss allocation additionally preserves set order.
  always_comb begin : store_hazards
    storeHazardInner = '0;
    storeAllocationHazardInner = '0;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      for (int s = 0; s < REQUEST_DEPTH; s++) begin
        if (requestInner[s].active && requestInner[s].request.write && olderInner[s][i]) begin
          if (requestInner[i].request.address[31:OFFSET_W] == requestInner[s].request.address[31:OFFSET_W] &&
              (OFFSET_W+1)'(requestInner[i].request.address[OFFSET_W-1:0]) <= byteEndInner[s] &&
              (OFFSET_W+1)'(requestInner[s].request.address[OFFSET_W-1:0]) <= byteEndInner[i])
            storeHazardInner[i] = 1;
          if (requestInner[s].request.address[OFFSET_W+:INDEX_W] == requestInner[i].request.address[OFFSET_W+:INDEX_W])
            storeAllocationHazardInner[i] = 1;
        end
      end
    end
    storeAllocationHazardInner |= storeHazardInner;
  end
  function automatic logic victim_hazard(input int miss);
    victim_hazard = 0;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (m != miss && missesInner[m].valid && missesInner[m].dirty &&
          !missesInner[m].writeDone &&
          {missesInner[m].victimTag, missesInner[m].line[OFFSET_W+:INDEX_W], {OFFSET_W{1'b0}}} == missesInner[miss].line)
        victim_hazard = 1;
  endfunction
  /* verilator lint_off SELRANGE */
  function automatic logic [WAY_W-1:0] select_victim(input logic [INDEX_W-1:0] setIndex);
    logic found;
    logic sub;
    select_victim = '0;
    sub = 0;
    if (WAYS == 2) select_victim = WAY_W'(!plruInner[setIndex][0]);
    if (WAYS == 4) begin
      sub = plruInner[setIndex][2] ? plruInner[setIndex][1] : plruInner[setIndex][0];
      select_victim = WAY_W'({!plruInner[setIndex][2], !sub});
    end
    found = 0;
    for (int w = 0; w < WAYS; w++)
      if (!found && !validInner[setIndex][w]) begin select_victim = WAY_W'(w); found = 1; end
  endfunction
  function automatic logic [PLRU_W-1:0] plru_touch(
    input logic [PLRU_W-1:0] bitsInput, input logic [WAY_W-1:0] wayInput
  );
    plru_touch = '0;
    if (WAYS == 2) plru_touch = PLRU_W'(wayInput[0]);
    if (WAYS == 4) begin
      if (wayInput[1]) plru_touch = PLRU_W'({wayInput[1], bitsInput[1], wayInput[0]});
      else plru_touch = PLRU_W'({wayInput[1], wayInput[0], bitsInput[0]});
    end
  endfunction
  /* verilator lint_on SELRANGE */

  // Metadata accompanies the existing synchronous SRAM read, not a new
  // pipeline stage. Only address/size are consumed by hit extraction.
  assign readLookupRequestInner = '{address:{{(32-OFFSET_W){1'b0}}, readLookupAddressInner}, size:readLookupSizeInner, default:'0};
  assign initializedOutput = rstNInput;
  assign cpuReqReadyOutput = rstNInput && countInner < COUNT_W'(REQUEST_DEPTH);
  assign acceptInner = cpuRequestInput.valid && cpuReqReadyOutput;
  // Empty means there is no older Store, request, or MSHR owner. This is
  // acceptance -> synchronous read only, never request -> response bypass.
  assign acceptLookupInner = acceptInner && countInner == 0 && !readValidInner &&
    !cpuRequestInput.write && cpuRequestInput.address != AXI_EXIT_ADDR;
  assign idleOutput = rstNInput && countInner == 0 && !readValidInner;

  // Allocation is not on the response/LSU-selection path. Keeping it separate
  // also makes the absence of a combinational request -> response bypass clear.
  always_comb begin : allocate_request
    int slot;
    allocationInner = -1;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      slot = (int'(cursorInner) + i) & (REQUEST_DEPTH-1);
      if (acceptInner && allocationInner < 0 && !requestInner[slot].active) allocationInner = slot;
    end
  end

  // These narrow identities/qualifiers depend only on OLD MSHR/request state.
  // Prepare each fill branch before the late line-response qualification, not
  // after fillMiss -> owner -> request selection. Payload extraction is shared.
  for (genvar miss = 0; miss < MSHR_DEPTH; miss++) begin : gen_fill_response
    assign fillCanRespondInner[miss] = !requestInner[missesInner[miss].owner].request.write &&
      !missesInner[miss].responded;
    assign fillTransactionInner[miss] = requestInner[missesInner[miss].owner].request.transaction;
  end

  always_comb begin : plan
    logic [REQUEST_DEPTH-1:0] candidates;
    logic [REQUEST_DEPTH-1:0] lookupActive;
    logic [3:0] readable, writable;
    logic anyMiss, continueHit, responsePrior;
    int id, owner, lookupFirst;
    activeInner = 0;
    freeMissInner = -1;
    hitWayInner = -1;
    anyMiss = 0;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      activeInner[i] = requestInner[i].active;
    end
    for (int m = 0; m < MSHR_DEPTH; m++) begin
      if (freeMissInner < 0 && !missesInner[m].valid) freeMissInner = m;
      anyMiss = anyMiss || missesInner[m].valid;
    end
    firstInner = oldest_request(activeInner);
    exitValidOutput = rstNInput && firstInner >= 0 &&
      requestInner[firstInner].request.write &&
      requestInner[firstInner].request.address == AXI_EXIT_ADDR && exitReadyInput;
    exitValueOutput = firstInner >= 0 ? requestInner[firstInner].request.writeData : 32'b0;
    for (int w = 0; w < WAYS; w++)
      if (readValidInner && hitWayInner < 0 && readWayMaskInner[w] &&
          metaRdataInner[w][TAG_W-1:0] == requestInner[readIndexInner].request.address[31:OFFSET_W+INDEX_W])
        hitWayInner = w;
    victimWayInner = select_victim(set_of(requestInner[readIndexInner].request.address));
    // One shared read-hit extractor. The eight request rows differ only in
    // offset/size and exactly one row owns the granted SRAM read, so the
    // per-row copies of this funnel carried seven redundant instances.
    readHitRawInner = extract_raw(sram_line(hitWayInner >= 0 ? hitWayInner : 0),
                                  readLookupRequestInner);
    writeAckInner = -1;
    id = int'(memWriteResponseInput.transaction);
    if (memWriteResponseInput.valid && missesInner[id].valid && missesInner[id].dirty &&
        missesInner[id].writeSent && !missesInner[id].writeDone &&
        victim_address(id) == memWriteResponseInput.address) writeAckInner = id;
    fillMissInner = -1;
    fillBeatInner = 0;
    fillFireInner = 0;
    id = int'(memResponseInput.transaction);
    if (memResponseInput.valid && missesInner[id].valid && missesInner[id].readSent &&
        missesInner[id].line == memResponseInput.address &&
        (!missesInner[id].dirty || missesInner[id].writeDone || writeAckInner == id)) begin
      fillMissInner = id;
      fillBeatInner = rstNInput;
      fillFireInner = rstNInput && missesInner[id].fillWord == WORD_INDEX_W'(WORDS_PER_LINE-FILL_WORDS_PER_BEAT);
    end
    memRspReadyOutput = fillFireInner;
    memWriteRspReadyOutput = rstNInput && writeAckInner >= 0;
    owner = fillMissInner >= 0 ? int'(missesInner[fillMissInner].owner) : 0;
    firstFillInner = fillBeatInner && missesInner[fillMissInner].fillWord == 0;
    earlyInner = fillBeatInner && fillCanRespondInner[memResponseInput.transaction];
    // Buffered eligibility uses only old request/hazard state. Do its
    // age arbitration before the late SRAM tag-hit qualification arrives.
    normalBufferedMaskInner = '0;
    for (int row = 0; row < REQUEST_DEPTH; row++)
      if (requestInner[row].active && !requestInner[row].request.write &&
          !storeHazardInner[row] && requestInner[row].ready)
        normalBufferedMaskInner[row] = 1'b1;
    normalBufferedWinnerInner = '0;
    normalHitEligibleInner = '0;
    responsePrior = 1'b0;
    for (int row = 0; row < REQUEST_DEPTH; row++) begin
      responsePrior = 1'b0;
      for (int peer = 0; peer < REQUEST_DEPTH; peer++)
        if (normalBufferedMaskInner[peer] && olderInner[peer][row]) responsePrior = 1'b1;
      normalBufferedWinnerInner[row] = normalBufferedMaskInner[row] && !responsePrior;
      // A late hit needs only the precomputed "no older buffered row" bit.
      // If its own row was already ready, both alternatives name that row.
      normalHitEligibleInner[row] = readValidInner && readIndexInner == REQUEST_W'(row) &&
        requestInner[row].active && !requestInner[row].request.write &&
        !storeHazardInner[row] && !responsePrior;
    end
    normalHitWinsInner = hitWayInner >= 0 && (|normalHitEligibleInner);
    normalWinnerInner = normalHitWinsInner ? normalHitEligibleInner : normalBufferedWinnerInner;
    normalResponseInner = -1;
    bufferedTransactionInner = '0;
    hitTransactionInner = '0;
    normalReadDataInner = '0;
    for (int row = 0; row < REQUEST_DEPTH; row++) begin
      if (normalWinnerInner[row]) normalResponseInner = row;
      bufferedTransactionInner |= requestInner[row].request.transaction &
        {$bits(data_transaction_t){normalBufferedWinnerInner[row]}};
      hitTransactionInner |= requestInner[row].request.transaction &
        {$bits(data_transaction_t){normalHitEligibleInner[row]}};
      normalReadDataInner |= rawInner[row] & {32{normalBufferedWinnerInner[row]}};
    end
    normalTransactionInner = normalHitWinsInner ? hitTransactionInner : bufferedTransactionInner;
    responseInner = earlyInner ? owner : normalResponseInner;
    cpuResponseOutput = '0;
    if (earlyInner || (|normalWinnerInner)) begin
      cpuResponseOutput.valid = rstNInput;
      cpuResponseOutput.transaction = earlyInner ? fillTransactionInner[memResponseInput.transaction] :
        normalTransactionInner;
      // earlyInner already authenticates this MSHR: avoid normal-response/validity muxes in the payload index.
      if (earlyInner) cpuResponseOutput.readData = extract_raw(memResponseInput.data, requestInner[missesInner[memResponseInput.transaction].owner].request);
      // An eligible hit wins iff the selected normal response is this read.
      // Avoid indexing the late winner vector through readIndex a second time.
      else if (normalHitWinsInner)
        cpuResponseOutput.readData = readHitRawInner;
      else cpuResponseOutput.readData = normalReadDataInner;
    end
    storeInner = -1;
    if (!fillBeatInner && firstInner >= 0 && requestInner[firstInner].request.write &&
        !set_locked(requestInner[firstInner].request.address) &&
        (requestInner[firstInner].ready || (readValidInner && int'(readIndexInner) == firstInner && hitWayInner >= 0)))
      storeInner = firstInner;
    allocateMissInner = -1;
    if (readValidInner && hitWayInner < 0 && !storeAllocationHazardInner[readIndexInner] &&
        find_miss(line_of(requestInner[readIndexInner].request.address)) < 0 &&
        !set_locked(requestInner[readIndexInner].request.address)) allocateMissInner = freeMissInner;
    candidates = 0;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      id = find_miss(line_of(requestInner[i].request.address));
      if (!readValidInner && requestInner[i].active && !requestInner[i].ready &&
          !requestInner[i].hasMiss && !requestInner[i].request.write && !storeAllocationHazardInner[i] && id >= 0 &&
          !requestInner[missesInner[id].owner].request.write && missesInner[id].fillWord == 0 &&
          !missesInner[id].responded && fillMissInner != id) candidates[i] = 1;
    end
    mergeSlotInner = oldest_request(candidates);
    mergeMissInner = mergeSlotInner >= 0 ? find_miss(line_of(requestInner[mergeSlotInner].request.address)) : -1;
    // A: start another synchronous read while consuming an actually delivered
    // old hit; misses, held results, fills and Store writes keep old priority.
    continueHit = readValidInner && hitWayInner >= 0 && !fillBeatInner &&
      !requestInner[readIndexInner].request.write && responseInner == int'(readIndexInner);
    lookupActive = activeInner;
    if (!fillBeatInner && responseInner >= 0) lookupActive[responseInner] = 1'b0;
    lookupFirst = oldest_request(lookupActive);
    candidates = 0;
    for (int i = 0; i < REQUEST_DEPTH; i++)
      if (requestInner[i].active &&
           !(readValidInner && int'(readIndexInner) == i) &&
           !requestInner[i].ready && !requestInner[i].hasMiss && i != mergeSlotInner &&
           requestInner[i].request.address != AXI_EXIT_ADDR &&
          !set_locked(requestInner[i].request.address) && !storeHazardInner[i] &&
          find_miss(line_of(requestInner[i].request.address)) < 0 &&
          (!requestInner[i].request.write || i == firstInner) &&
          (!requestInner[i].deferred || (i == firstInner && freeMissInner >= 0)) &&
           (anyMiss || i == firstInner || i == lookupFirst)) candidates[i] = 1;
    lookupCandidateInner = oldest_request(candidates);
    lookupInner = (!readValidInner || continueHit) && !fillBeatInner && storeInner < 0 ? lookupCandidateInner : -1;
    // Only lookupInner authorizes a read. With no candidate the truncated -1
    // selects a legal, inactive request row; its address is never consumed.
    lookupAddressInner = countInner == 0 ? set_of(cpuRequestInput.address) :
      set_of(requestInner[REQUEST_W'(lookupCandidateInner)].request.address);
    readable = 0;
    writable = 0;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (missesInner[m].valid) begin
        if (!missesInner[m].readSent && !victim_hazard(m) && !storeAllocationHazardInner[missesInner[m].owner]) readable[m] = 1;
        if (missesInner[m].dirty && !missesInner[m].writeSent) writable[m] = 1;
      end
    readMissInner = oldest_miss(readable);
    writeMissInner = oldest_miss(writable);
    memRequestOutput = '0;
    if (readMissInner >= 0) begin
      memRequestOutput.readValid = rstNInput;
      memRequestOutput.readAddress = missesInner[readMissInner].line;
      memRequestOutput.readTransaction = 2'(readMissInner);
    end
    if (writeMissInner >= 0) begin
      memRequestOutput.writeValid = rstNInput;
      memRequestOutput.writeAddress = victim_address(writeMissInner);
      memRequestOutput.writeTransaction = 2'(writeMissInner);
      memRequestOutput.writeData = victimPayloadInner[writeMissInner];
    end
    releasedInner = 0;
    if (responseInner >= 0 && (!fillBeatInner || responseInner != owner)) releasedInner[responseInner] = 1;
    if (storeInner >= 0) releasedInner[storeInner] = 1;
    if (fillFireInner) releasedInner[owner] = 1;
    if (exitValidOutput) releasedInner[firstInner] = 1;
  end

  always_comb begin : sram_ports
    int way, owner, globalByte;
    metaWdataInner = '0;
    way = 0;
    owner = 0;
    globalByte = 0;
    for (int w = 0; w < WAYS; w++) begin
      metaEnableInner[w] = 0;
      metaWriteInner[w] = 0;
      metaAddressInner[w] = lookupAddressInner;
      for (int b = 0; b < WORDS_PER_LINE; b++) begin
        dataEnableBankInner[w][b] = 0;
        dataWriteBankInner[w][b] = 0;
        // Inactive ports need not follow the globally granted operation.
        // Local overrides keep the late fill/store grant off other banks'
        // address muxes instead of broadcasting one net to every SRAM lane.
        dataAddressBankInner[w][b] = lookupAddressInner;
        dataMaskBankInner[w][b] = 0;
        dataWdataBankInner[w][b] = 0;
      end
    end
    if (rstNInput && fillBeatInner) begin
      way = int'(missesInner[fillMissInner].way);
      owner = int'(missesInner[fillMissInner].owner);
      for (int b = 0; b < WORDS_PER_LINE; b++)
        if (b >= int'(missesInner[fillMissInner].fillWord) &&
            b < int'(missesInner[fillMissInner].fillWord) + FILL_WORDS_PER_BEAT) begin
          dataEnableBankInner[way][b] = 1;
          dataWriteBankInner[way][b] = 1;
          dataAddressBankInner[way][b] = set_of(missesInner[fillMissInner].line);
          dataMaskBankInner[way][b] = '1;
          dataWdataBankInner[way][b] = memResponseInput.data[b*32+:32];
          for (int i = 0; i < 4; i++) begin
            globalByte = int'(requestInner[owner].request.address[OFFSET_W-1:0]) + i;
            if (requestInner[owner].request.write && i < bytes_for_size(requestInner[owner].request.size) &&
                requestInner[owner].request.writeStrobe[i] && (globalByte >> 2) == b)
              dataWdataBankInner[way][b][(globalByte & 3)*8+:8] = requestInner[owner].request.writeData[i*8+:8];
          end
        end
      if (fillFireInner) begin
        metaEnableInner[way] = 1;
        metaWriteInner[way] = 1;
        metaAddressInner[way] = set_of(missesInner[fillMissInner].line);
        metaWdataInner = {requestInner[owner].request.write, missesInner[fillMissInner].line[31:OFFSET_W+INDEX_W]};
      end
    end else if (rstNInput && storeInner >= 0) begin
      way = readValidInner && int'(readIndexInner) == storeInner && hitWayInner >= 0 ?
        hitWayInner : int'(requestInner[storeInner].way);
      for (int i = 0; i < 4; i++) begin
        globalByte = int'(requestInner[storeInner].request.address[OFFSET_W-1:0]) + i;
        if (i < bytes_for_size(requestInner[storeInner].request.size) && requestInner[storeInner].request.writeStrobe[i]) begin
          dataEnableBankInner[way][globalByte >> 2] = 1;
          dataWriteBankInner[way][globalByte >> 2] = 1;
          dataAddressBankInner[way][globalByte >> 2] = set_of(requestInner[storeInner].request.address);
          dataMaskBankInner[way][globalByte >> 2][globalByte & 3] = 1;
          dataWdataBankInner[way][globalByte >> 2][(globalByte & 3)*8+:8] = requestInner[storeInner].request.writeData[i*8+:8];
        end
      end
      metaEnableInner[way] = 1;
      metaWriteInner[way] = 1;
      metaAddressInner[way] = set_of(requestInner[storeInner].request.address);
      metaWdataInner = {1'b1, requestInner[storeInner].request.address[31:OFFSET_W+INDEX_W]};
    end else if (rstNInput && (lookupInner >= 0 || acceptLookupInner)) begin
      for (int w = 0; w < WAYS; w++) begin
        metaEnableInner[w] = 1;
        for (int b = 0; b < WORDS_PER_LINE; b++) dataEnableBankInner[w][b] = 1;
      end
    end
  end
  for (genvar w = 0; w < WAYS; w++) begin : g_way
    for (genvar b = 0; b < WORDS_PER_LINE; b = b + 1) begin : g_data_bank
      sram_fakeram #(.DEPTH(SETS), .WIDTH(32), .WRITE_GRANULARITY(8)) u_data (
        .clk(clkInput), .en(dataEnableBankInner[w][b]), .we(dataWriteBankInner[w][b]), .addr(dataAddressBankInner[w][b]),
        .wdata(dataWdataBankInner[w][b]), .wmask(dataMaskBankInner[w][b]), .rdata(dataRdataBankInner[w][b])
      );
`ifndef SYNTHESIS
      always @(posedge clkInput) if (rstNInput && dataEnableBankInner[w][b])
        assert (dataAddressBankInner[w][b] == sramAddressInner)
          else $fatal(1, "DCache local data address disagrees with grant");
`endif
    end
    sram_fakeram #(.DEPTH(SETS), .WIDTH(META_W), .WRITE_GRANULARITY(META_W)) u_metadata (
      .clk(clkInput), .en(metaEnableInner[w]), .we(metaWriteInner[w]), .addr(metaAddressInner[w]),
      .wdata(metaWdataInner), .wmask(1'b1), .rdata(metaRdataInner[w])
    );
`ifndef SYNTHESIS
    always @(posedge clkInput) if (rstNInput && metaEnableInner[w])
      assert (metaAddressInner[w] == sramAddressInner)
        else $fatal(1, "DCache local metadata address disagrees with grant");
`endif
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      countInner <= 0;
      cursorInner <= 0;
      readIndexInner <= 0;
      readValidInner <= 0;
      readLookupAddressInner <= '0;
      readLookupSizeInner <= '0;
      readWayMaskInner <= 0;
      for (int i = 0; i < REQUEST_DEPTH; i++) begin
        requestInner[i] <= '0;
        olderInner[i] <= 0;
        byteEndInner[i] <= '0;
      end
      for (int m = 0; m < MSHR_DEPTH; m++) missesInner[m] <= '0;
      for (int s = 0; s < SETS; s++) begin
        plruInner[s] <= 0;
        for (int w = 0; w < WAYS; w++) validInner[s][w] <= 0;
      end
    end else begin
      countInner <= COUNT_W'(int'(countInner) + int'(acceptInner) - $countones(releasedInner));
      if (allocationInner >= 0) cursorInner <= REQUEST_W'(allocationInner + 1);
      readValidInner <= lookupInner >= 0 || acceptLookupInner;
      if (acceptLookupInner) begin
        readIndexInner <= REQUEST_W'(allocationInner);
        readLookupAddressInner <= cpuRequestInput.address[OFFSET_W-1:0];
        readLookupSizeInner <= cpuRequestInput.size;
        for (int w = 0; w < WAYS; w++)
          readWayMaskInner[w] <= validInner[set_of(cpuRequestInput.address)][w];
      end else if (lookupInner >= 0) begin
        readIndexInner <= REQUEST_W'(lookupInner);
        // Candidate index is independent of the late grant qualification;
        // lookupInner>=0 guarantees it names this same old active request.
        readLookupAddressInner <= requestInner[REQUEST_W'(lookupCandidateInner)].request.address[OFFSET_W-1:0];
        readLookupSizeInner <= requestInner[REQUEST_W'(lookupCandidateInner)].request.size;
        for (int w = 0; w < WAYS; w++)
          readWayMaskInner[w] <= validInner[set_of(requestInner[lookupInner].request.address)][w];
      end
      for (int i = 0; i < REQUEST_DEPTH; i++) begin
        if (i == allocationInner) begin
          requestInner[i] <= '{request:cpuRequestInput, active:1'b1, default:'0};
          // Request address/size are immutable until this slot is reallocated.
          // Compute its inclusive byte end on the SAME allocation edge, not
          // on the critical response/Store-hazard qualification path.
          byteEndInner[i] <= (OFFSET_W+1)'(cpuRequestInput.address[OFFSET_W-1:0]) +
            (OFFSET_W+1)'(bytes_for_size(cpuRequestInput.size)-1);
        end
        else begin
          requestInner[i].active <= requestInner[i].active && !releasedInner[i];
          if (releasedInner[i]) begin
            requestInner[i].ready <= 0;
            requestInner[i].deferred <= 0;
            requestInner[i].hasMiss <= 0;
          end else if (requestInner[i].active) begin
            if (firstFillInner && !requestInner[missesInner[fillMissInner].owner].request.write &&
                requestInner[i].hasMiss && int'(requestInner[i].miss) == fillMissInner &&
                 REQUEST_W'(i) != missesInner[fillMissInner].owner) begin
              requestInner[i].ready <= 1;
              requestInner[i].deferred <= 0;
              requestInner[i].hasMiss <= 0;
            end else if (readValidInner && readIndexInner == REQUEST_W'(i)) begin
              if (hitWayInner >= 0) begin
                requestInner[i].ready <= 1;
                requestInner[i].way <= WAY_W'(hitWayInner);
              end else begin
                requestInner[i].miss <= 2'(allocateMissInner);
                requestInner[i].hasMiss <= allocateMissInner >= 0;
                requestInner[i].deferred <= allocateMissInner < 0;
              end
            end
            if (mergeSlotInner == i) begin
              requestInner[i].miss <= 2'(mergeMissInner);
              requestInner[i].hasMiss <= 1;
              requestInner[i].deferred <= 0;
            end
          end
        end
        olderInner[i] <= activeInner[i] && !releasedInner[i] ?
          (olderInner[i] & activeInner & ~releasedInner) |
             (allocationInner >= 0 ? (REQUEST_DEPTH'(1) << allocationInner) : REQUEST_DEPTH'(0)) : REQUEST_DEPTH'(0);
      end
      for (int m = 0; m < MSHR_DEPTH; m++) begin
        if (allocateMissInner == m) begin
          missesInner[m] <= '{line:line_of(requestInner[readIndexInner].request.address),
            owner:readIndexInner, way:victimWayInner, valid:1'b1,
            victimTag:readWayMaskInner[victimWayInner] ? metaRdataInner[victimWayInner][TAG_W-1:0] : TAG_W'(0),
            dirty:readWayMaskInner[victimWayInner] && metaRdataInner[victimWayInner][TAG_W],
            default:'0};
        end else if (fillFireInner && fillMissInner == m) missesInner[m].valid <= 0;
        else if (missesInner[m].valid) begin
          if (memRequestOutput.readValid && memReadReadyInput && readMissInner == m) missesInner[m].readSent <= 1;
          if (memRequestOutput.writeValid && memWriteReadyInput && writeMissInner == m) missesInner[m].writeSent <= 1;
          if (writeAckInner == m) missesInner[m].writeDone <= 1;
          if (fillBeatInner && fillMissInner == m)
            missesInner[m].fillWord <= missesInner[m].fillWord + WORD_INDEX_W'(FILL_WORDS_PER_BEAT);
          if (fillMissInner == m && responseInner == int'(missesInner[m].owner)) missesInner[m].responded <= 1;
        end
      end
      for (int s = 0; s < SETS; s++) begin
        if (fillFireInner && set_of(missesInner[fillMissInner].line) == INDEX_W'(s))
          plruInner[s] <= plru_touch(plruInner[s], missesInner[fillMissInner].way);
        else if (readValidInner && hitWayInner >= 0 && set_of(requestInner[readIndexInner].request.address) == INDEX_W'(s))
          plruInner[s] <= plru_touch(plruInner[s], WAY_W'(hitWayInner));
        for (int w = 0; w < WAYS; w++) begin
          if (allocateMissInner >= 0 && set_of(requestInner[readIndexInner].request.address) == INDEX_W'(s) && victimWayInner == WAY_W'(w))
            validInner[s][w] <= 0;
          else if (fillFireInner && set_of(missesInner[fillMissInner].line) == INDEX_W'(s) && missesInner[fillMissInner].way == WAY_W'(w))
            validInner[s][w] <= 1;
        end
      end
    end
  end
  // Wide payloads have no reset/allocation clear. Ready/dirty ownership gates
  // every use, and each payload is overwritten before that generation uses it.
  always_ff @(posedge clkInput) begin
    if (rstNInput) begin
      for (int m = 0; m < MSHR_DEPTH; m++)
        if (allocateMissInner == m) victimPayloadInner[m] <= sram_line(int'(victimWayInner));
      for (int i = 0; i < REQUEST_DEPTH; i++) begin
        if (requestInner[i].active && !releasedInner[i]) begin
          if (firstFillInner && !requestInner[missesInner[fillMissInner].owner].request.write &&
              requestInner[i].hasMiss && int'(requestInner[i].miss) == fillMissInner &&
              REQUEST_W'(i) != missesInner[fillMissInner].owner)
            rawInner[i] <= extract_raw(memResponseInput.data, requestInner[i].request);
          else if (readValidInner && readIndexInner == REQUEST_W'(i) && hitWayInner >= 0)
            rawInner[i] <= readHitRawInner;
        end
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    if (acceptLookupInner) begin
      assert (acceptInner && allocationInner >= 0 && activeInner == 0 &&
              !readValidInner && !fillBeatInner && storeInner < 0 && lookupInner < 0)
        else $fatal(1, "DCache accepted read conflicts with older work");
      for (int m = 0; m < MSHR_DEPTH; m++)
        assert (!missesInner[m].valid)
          else $fatal(1, "DCache empty request credits conceal an MSHR owner");
    end
    if (lookupInner >= 0) assert (lookupInner == lookupCandidateInner)
      else $fatal(1, "DCache lookup metadata grant mismatch");
    if (readValidInner)
      assert (readLookupAddressInner == requestInner[readIndexInner].request.address[OFFSET_W-1:0] &&
              readLookupSizeInner == requestInner[readIndexInner].request.size)
        else $fatal(1, "DCache read snapshot diverged");
  end
`endif
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    assert ($onehot0(normalWinnerInner)) else $fatal(1, "DCache response winner not unique");
    assert ((normalResponseInner < 0) == !(|normalWinnerInner))
      else $fatal(1, "DCache response winner lost");
    if (normalResponseInner >= 0)
      assert (normalWinnerInner[normalResponseInner])
        else $fatal(1, "DCache response age mismatch");
  end
`endif
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    logic [REQUEST_DEPTH-1:0] originalCandidates;
    originalCandidates = normalBufferedMaskInner;
    for (int row = 0; row < REQUEST_DEPTH; row++)
      if (requestInner[row].active && !requestInner[row].request.write && !storeHazardInner[row] &&
          readValidInner && readIndexInner == REQUEST_W'(row) && hitWayInner >= 0)
        originalCandidates[row] = 1'b1;
    assert (normalResponseInner == oldest_request(originalCandidates))
      else $fatal(1,"DCache factored late-hit age mismatch");
  end
`endif
`ifndef SYNTHESIS
  initial begin
    assert ((WAYS == 1 || WAYS == 2 || WAYS == 4) && SETS > 1 && (SETS & (SETS-1)) == 0 &&
      WORDS_PER_LINE >= 2 && (WORDS_PER_LINE & (WORDS_PER_LINE-1)) == 0)
      else $fatal(1, "nonblocking DCache requires power-of-two rows/lines and 1/2/4 ways");
  end
  always @(posedge clkInput) if (rstNInput) begin
    assert (countInner == $countones(activeInner) && countInner <= COUNT_W'(REQUEST_DEPTH));
    if (exitValidOutput) assert (requestInner[firstInner].request.size == MEM_WORD &&
      requestInner[firstInner].request.writeStrobe == 4'hf);
    if (memWriteResponseInput.valid) assert (writeAckInner >= 0)
      else $fatal(1, "DCache stale/mismatched write completion");
    if (memResponseInput.valid) begin
      assert (missesInner[memResponseInput.transaction].valid &&
        missesInner[memResponseInput.transaction].readSent &&
        missesInner[memResponseInput.transaction].line == memResponseInput.address)
        else $fatal(1, "DCache stale/mismatched read completion");
    end
    for (int m = 0; m < MSHR_DEPTH; m++) if (missesInner[m].valid) begin
      assert (requestInner[missesInner[m].owner].active && requestInner[missesInner[m].owner].hasMiss &&
        requestInner[missesInner[m].owner].miss == 2'(m));
      for (int n = m+1; n < MSHR_DEPTH; n++)
        assert (!missesInner[n].valid || set_of(missesInner[m].line) != set_of(missesInner[n].line));
    end
    if (readValidInner) assert (requestInner[readIndexInner].active);
    if (acceptInner) assert (int'(cpuRequestInput.address[OFFSET_W-1:0]) + bytes_for_size(cpuRequestInput.size) <= DCACHE_LINE_BYTES);
  end
`endif
endmodule
