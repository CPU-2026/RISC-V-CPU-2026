// Software main-tree nonblocking SRAM D$: eight TOTAL request credits (including
// MSHR owners), four misses, pre-first-fill same-line Load merging. All decisions
// read old state. Fill > Store > lookup on real single-port SRAMs.
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
    logic [31:0] raw;
    logic [WAY_W-1:0] way;
    logic [1:0] miss;
    logic hasMiss, active, ready, deferred;
  } request_entry_t;
  typedef struct packed {
    logic [31:0] line;
    logic [TAG_W-1:0] victimTag;
    logic [DCACHE_LINE_BITS-1:0] victimLine;
    logic [REQUEST_W-1:0] owner;
    logic [WAY_W-1:0] way;
    logic [WORD_INDEX_W-1:0] fillWord;
    logic valid, dirty, readSent, writeSent, writeDone, responded;
  } miss_entry_t;
  request_entry_t requestInner [REQUEST_DEPTH];
  miss_entry_t missesInner [MSHR_DEPTH];
  logic [REQUEST_DEPTH-1:0] olderInner [REQUEST_DEPTH];
  logic [COUNT_W-1:0] countInner;
  logic [REQUEST_W-1:0] cursorInner, readIndexInner;
  logic readValidInner;
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
  logic [INDEX_W-1:0] sramAddressInner;
  logic [REQUEST_DEPTH-1:0] activeInner, releasedInner;
  integer firstInner, hitWayInner, freeMissInner, allocationInner;
  integer lookupInner, responseInner, storeInner, allocateMissInner;
  integer mergeSlotInner, mergeMissInner, fillMissInner, writeAckInner;
  integer readMissInner, writeMissInner;
  logic fillBeatInner, fillFireInner, firstFillInner, earlyInner, acceptInner;
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
    logic [DCACHE_LINE_BITS-1:0] shifted;
    shifted = lineData >> (32'(request.address[OFFSET_W-1:0]) << 3);
    case (request.size)
      MEM_BYTE: return {24'b0, shifted[7:0]};
      MEM_HALF: return {16'b0, shifted[15:0]};
      default: return shifted[31:0];
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
  function automatic logic store_hazard(input int slot, input logic allocatingMiss);
    logic overlap;
    logic [31:0] loadBytes, storeBytes;
    loadBytes = requestInner[slot].request.size == MEM_BYTE ? 32'd1 :
      requestInner[slot].request.size == MEM_HALF ? 32'd2 : 32'd4;
    store_hazard = 0;
    for (int s = 0; s < REQUEST_DEPTH; s++) begin
      storeBytes = requestInner[s].request.size == MEM_BYTE ? 32'd1 :
        requestInner[s].request.size == MEM_HALF ? 32'd2 : 32'd4;
      overlap = requestInner[slot].request.address >= requestInner[s].request.address ?
        requestInner[slot].request.address - requestInner[s].request.address <
          storeBytes :
        requestInner[s].request.address - requestInner[slot].request.address <
          loadBytes;
      if (requestInner[s].active && requestInner[s].request.write && olderInner[s][slot] &&
          (overlap || (allocatingMiss && requestInner[s].request.address[OFFSET_W+:INDEX_W] ==
                                             requestInner[slot].request.address[OFFSET_W+:INDEX_W])))
        store_hazard = 1;
    end
  endfunction
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

  assign initializedOutput = rstNInput;
  assign cpuReqReadyOutput = rstNInput && countInner < COUNT_W'(REQUEST_DEPTH);
  assign acceptInner = cpuRequestInput.valid && cpuReqReadyOutput;
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

  always_comb begin : plan
    logic [REQUEST_DEPTH-1:0] candidates;
    logic [3:0] readable, writable;
    logic anyMiss;
    int id, owner;
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
    earlyInner = fillBeatInner && !requestInner[owner].request.write && !missesInner[fillMissInner].responded;
    candidates = 0;
    for (int i = 0; i < REQUEST_DEPTH; i++)
      if (requestInner[i].active && !requestInner[i].request.write && !store_hazard(i, 0) &&
          (requestInner[i].ready || (readValidInner && int'(readIndexInner) == i && hitWayInner >= 0)))
        candidates[i] = 1;
    responseInner = earlyInner ? owner : oldest_request(candidates);
    cpuResponseOutput = '0;
    if (responseInner >= 0) begin
      cpuResponseOutput.valid = rstNInput;
      cpuResponseOutput.transaction = requestInner[responseInner].request.transaction;
      if (earlyInner) cpuResponseOutput.readData = extract_raw(memResponseInput.data, requestInner[responseInner].request);
      else if (readValidInner && int'(readIndexInner) == responseInner && hitWayInner >= 0)
        cpuResponseOutput.readData = extract_raw(sram_line(hitWayInner), requestInner[responseInner].request);
      else cpuResponseOutput.readData = requestInner[responseInner].raw;
    end
    storeInner = -1;
    if (!fillBeatInner && firstInner >= 0 && requestInner[firstInner].request.write &&
        !set_locked(requestInner[firstInner].request.address) &&
        (requestInner[firstInner].ready || (readValidInner && int'(readIndexInner) == firstInner && hitWayInner >= 0)))
      storeInner = firstInner;
    allocateMissInner = -1;
    if (readValidInner && hitWayInner < 0 && !store_hazard(int'(readIndexInner), 1) &&
        find_miss(line_of(requestInner[readIndexInner].request.address)) < 0 &&
        !set_locked(requestInner[readIndexInner].request.address)) allocateMissInner = freeMissInner;
    candidates = 0;
    for (int i = 0; i < REQUEST_DEPTH; i++) begin
      id = find_miss(line_of(requestInner[i].request.address));
      if (!readValidInner && requestInner[i].active && !requestInner[i].ready &&
          !requestInner[i].hasMiss && !requestInner[i].request.write && !store_hazard(i, 1) && id >= 0 &&
          !requestInner[missesInner[id].owner].request.write && missesInner[id].fillWord == 0 &&
          !missesInner[id].responded && fillMissInner != id) candidates[i] = 1;
    end
    mergeSlotInner = oldest_request(candidates);
    mergeMissInner = mergeSlotInner >= 0 ? find_miss(line_of(requestInner[mergeSlotInner].request.address)) : -1;
    candidates = 0;
    for (int i = 0; i < REQUEST_DEPTH; i++)
      if (!readValidInner && !fillBeatInner && storeInner < 0 && requestInner[i].active &&
           !requestInner[i].ready && !requestInner[i].hasMiss && i != mergeSlotInner &&
           requestInner[i].request.address != AXI_EXIT_ADDR &&
          !set_locked(requestInner[i].request.address) && !store_hazard(i, 0) &&
          find_miss(line_of(requestInner[i].request.address)) < 0 &&
          (!requestInner[i].request.write || i == firstInner) &&
          (!requestInner[i].deferred || (i == firstInner && freeMissInner >= 0)) &&
          (anyMiss || i == firstInner)) candidates[i] = 1;
    lookupInner = oldest_request(candidates);
    readable = 0;
    writable = 0;
    for (int m = 0; m < MSHR_DEPTH; m++)
      if (missesInner[m].valid) begin
        if (!missesInner[m].readSent && !victim_hazard(m) && !store_hazard(int'(missesInner[m].owner), 1)) readable[m] = 1;
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
      memRequestOutput.writeData = missesInner[writeMissInner].victimLine;
    end
    releasedInner = 0;
    if (responseInner >= 0 && (!fillBeatInner || responseInner != owner)) releasedInner[responseInner] = 1;
    if (storeInner >= 0) releasedInner[storeInner] = 1;
    if (fillFireInner) releasedInner[owner] = 1;
    if (exitValidOutput) releasedInner[firstInner] = 1;
  end

  always_comb begin : sram_ports
    int way, owner, globalByte;
    sramAddressInner = '0;
    metaWdataInner = '0;
    way = 0;
    owner = 0;
    globalByte = 0;
    for (int w = 0; w < WAYS; w++) begin
      metaEnableInner[w] = 0;
      metaWriteInner[w] = 0;
      for (int b = 0; b < WORDS_PER_LINE; b++) begin
        dataEnableBankInner[w][b] = 0;
        dataWriteBankInner[w][b] = 0;
        dataMaskBankInner[w][b] = 0;
        dataWdataBankInner[w][b] = 0;
      end
    end
    if (rstNInput && fillBeatInner) begin
      way = int'(missesInner[fillMissInner].way);
      owner = int'(missesInner[fillMissInner].owner);
      sramAddressInner = set_of(missesInner[fillMissInner].line);
      for (int b = 0; b < WORDS_PER_LINE; b++)
        if (b >= int'(missesInner[fillMissInner].fillWord) &&
            b < int'(missesInner[fillMissInner].fillWord) + FILL_WORDS_PER_BEAT) begin
          dataEnableBankInner[way][b] = 1;
          dataWriteBankInner[way][b] = 1;
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
        metaWdataInner = {requestInner[owner].request.write, missesInner[fillMissInner].line[31:OFFSET_W+INDEX_W]};
      end
    end else if (rstNInput && storeInner >= 0) begin
      way = readValidInner && int'(readIndexInner) == storeInner && hitWayInner >= 0 ?
        hitWayInner : int'(requestInner[storeInner].way);
      sramAddressInner = set_of(requestInner[storeInner].request.address);
      for (int i = 0; i < 4; i++) begin
        globalByte = int'(requestInner[storeInner].request.address[OFFSET_W-1:0]) + i;
        if (i < bytes_for_size(requestInner[storeInner].request.size) && requestInner[storeInner].request.writeStrobe[i]) begin
          dataEnableBankInner[way][globalByte >> 2] = 1;
          dataWriteBankInner[way][globalByte >> 2] = 1;
          dataMaskBankInner[way][globalByte >> 2][globalByte & 3] = 1;
          dataWdataBankInner[way][globalByte >> 2][(globalByte & 3)*8+:8] = requestInner[storeInner].request.writeData[i*8+:8];
        end
      end
      metaEnableInner[way] = 1;
      metaWriteInner[way] = 1;
      metaWdataInner = {1'b1, requestInner[storeInner].request.address[31:OFFSET_W+INDEX_W]};
    end else if (rstNInput && lookupInner >= 0) begin
      sramAddressInner = set_of(requestInner[lookupInner].request.address);
      for (int w = 0; w < WAYS; w++) begin
        metaEnableInner[w] = 1;
        for (int b = 0; b < WORDS_PER_LINE; b++) dataEnableBankInner[w][b] = 1;
      end
    end
  end
  for (genvar w = 0; w < WAYS; w++) begin : g_way
    for (genvar b = 0; b < WORDS_PER_LINE; b = b + 1) begin : g_data_bank
      sram_fakeram #(.DEPTH(SETS), .WIDTH(32), .WRITE_GRANULARITY(8)) u_data (
        .clk(clkInput), .en(dataEnableBankInner[w][b]), .we(dataWriteBankInner[w][b]), .addr(sramAddressInner),
        .wdata(dataWdataBankInner[w][b]), .wmask(dataMaskBankInner[w][b]), .rdata(dataRdataBankInner[w][b])
      );
    end
    sram_fakeram #(.DEPTH(SETS), .WIDTH(META_W), .WRITE_GRANULARITY(META_W)) u_metadata (
      .clk(clkInput), .en(metaEnableInner[w]), .we(metaWriteInner[w]), .addr(sramAddressInner),
      .wdata(metaWdataInner), .wmask(1'b1), .rdata(metaRdataInner[w])
    );
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      countInner <= 0;
      cursorInner <= 0;
      readIndexInner <= 0;
      readValidInner <= 0;
      readWayMaskInner <= 0;
      for (int i = 0; i < REQUEST_DEPTH; i++) begin requestInner[i] <= '0; olderInner[i] <= 0; end
      for (int m = 0; m < MSHR_DEPTH; m++) missesInner[m] <= '0;
      for (int s = 0; s < SETS; s++) begin
        plruInner[s] <= 0;
        for (int w = 0; w < WAYS; w++) validInner[s][w] <= 0;
      end
    end else begin
      countInner <= COUNT_W'(int'(countInner) + int'(acceptInner) - $countones(releasedInner));
      if (allocationInner >= 0) cursorInner <= REQUEST_W'(allocationInner + 1);
      readValidInner <= lookupInner >= 0;
      if (lookupInner >= 0) begin
        readIndexInner <= REQUEST_W'(lookupInner);
        for (int w = 0; w < WAYS; w++)
          readWayMaskInner[w] <= validInner[set_of(requestInner[lookupInner].request.address)][w];
      end
      for (int i = 0; i < REQUEST_DEPTH; i++) begin
        if (i == allocationInner) requestInner[i] <= '{request:cpuRequestInput, active:1'b1, default:'0};
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
              requestInner[i].raw <= extract_raw(memResponseInput.data, requestInner[i].request);
              requestInner[i].ready <= 1;
              requestInner[i].deferred <= 0;
              requestInner[i].hasMiss <= 0;
            end else if (readValidInner && readIndexInner == REQUEST_W'(i)) begin
              if (hitWayInner >= 0) begin
                requestInner[i].raw <= extract_raw(sram_line(hitWayInner), requestInner[i].request);
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
            victimLine:sram_line(int'(victimWayInner)), default:'0};
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
