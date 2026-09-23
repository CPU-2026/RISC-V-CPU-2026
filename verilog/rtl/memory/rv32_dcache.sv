module rv32_dcache #(
  parameter int unsigned SETS = 1024,
  parameter int unsigned WAYS = 4
) (
  input  logic             clkInput,
  input  logic             rstNInput,

  input  rv32_pkg::dcache_cpu_request_input_t cpuRequestInput,
  output logic             cpuReqReadyOutput,
  output rv32_pkg::dcache_cpu_response_output_t cpuResponseOutput,

  output rv32_pkg::cache_line_request_output_t memRequestOutput,
  input  logic             memReqReadyInput,
  input  rv32_pkg::cache_line_response_input_t memResponseInput,

  input  logic             flushInput,
  output logic             flushDoneOutput
);
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned WAY_W = $clog2(WAYS);
  localparam int unsigned TAG_W = 32 - INDEX_W - 4;

  typedef enum logic [2:0] {
    IDLE,
    TAG_READ,
    WRITEBACK_REQUEST,
    REFILL_REQUEST,
    REFILL_WAIT,
    FLUSH_SCAN,
    FLUSH_READ,
    FLUSH_WRITEBACK
  } state_e;
  state_e stateInner;

  logic validInner [WAYS][SETS];
  logic dirtyInner [WAYS][SETS];
  logic [TAG_W-1:0] tagInner [WAYS][SETS];
  logic [2:0] plruInner [SETS];

  logic savedWriteInner;
  logic [31:0] savedAddrInner;
  logic [31:0] savedWdataInner;
  logic [3:0] savedWstrbInner;
  logic [1:0] savedSizeInner;
  logic [INDEX_W-1:0] savedIndexRegisteredInner;
  logic [3:0] savedOffsetInner;
  logic reqHitInner;
  logic [WAY_W-1:0] reqHitWayInner, reqVictimInner;
  logic [WAY_W-1:0] victimWayInner;
  logic [127:0] evictDataInner;
  logic [127:0] flushDataInner;
  logic [INDEX_W-1:0] flushSetInner;
  logic [WAY_W-1:0] flushWayInner;
  logic flushDoneInner;
  logic [WAY_W-1:0] flushWayNext;
  logic [INDEX_W-1:0] flushSetNext;
  logic unusedCoutFlushWayInner, unusedCoutFlushSetInner;

  logic rspValidInner;
  logic [31:0] rspDataInner;
  logic [INDEX_W-1:0] requestIndexInner;
  logic [TAG_W-1:0] requestTagInner;
  logic [3:0] requestOffsetInner;
  logic hitFoundInner;
  logic [WAY_W-1:0] hitWayInner;
  logic victimFoundInner;
  logic [WAY_W-1:0] selectedVictimInner;
  logic [INDEX_W-1:0] savedIndexInner;
  logic [TAG_W-1:0] savedTagInner;
  logic [127:0] refillMergedInner;
  logic [127:0] sramRdataInner [WAYS];
  logic [127:0] hitLineInner, victimLineInner, flushLineInner;
  logic [31:0] hitWordInner, refillWordInner;
  logic [15:0] storeWmaskInner;
  logic [127:0] storeWdataInner;
  logic acceptInner;
  integer combWayInner;
  integer seqWayInner, seqSetInner;
  genvar gWayInner;

  rv32_add #(.WIDTH(WAY_W)) u_flush_way_next (
    .aInput(flushWayInner), .bInput(WAY_W'(1)), .cinInput(1'b0),
    .sumOutput(flushWayNext), .coutOutput(unusedCoutFlushWayInner)
  );

  rv32_add #(.WIDTH(INDEX_W)) u_flush_set_next (
    .aInput(flushSetInner), .bInput(INDEX_W'(1)), .cinInput(1'b0),
    .sumOutput(flushSetNext), .coutOutput(unusedCoutFlushSetInner)
  );

  function automatic logic [127:0] merge_store(
    input logic [127:0] lineInput,
    input logic [3:0] offsetInput,
    input logic [31:0] dataInput,
    input logic [3:0] strobeInput
  );
    logic [127:0] resultInner;
    integer byteIndexInner;
    begin
      resultInner = lineInput;
      for (byteIndexInner = 0; byteIndexInner < 4; byteIndexInner = byteIndexInner + 1)
        if (strobeInput[byteIndexInner])
          resultInner[((32'(offsetInput) + byteIndexInner) << 3) +: 8] =
            dataInput[(byteIndexInner << 3) +: 8];
      merge_store = resultInner;
    end
  endfunction

  function automatic logic [31:0] extract_line_word(
    input logic [127:0] lineInput,
    input logic [3:0] offsetInput
  );
    logic [127:0] shiftedInner;
    begin
      shiftedInner = lineInput >> ({4'b0, offsetInput} << 3);
      extract_line_word = shiftedInner[31:0];
    end
  endfunction

  function automatic logic [2:0] plru_after_access(
    input logic [2:0] oldPlruInput,
    input logic [WAY_W-1:0] accessedWayInput
  );
    logic [2:0] nextPlruInner;
    begin
      nextPlruInner = oldPlruInput;
      if (accessedWayInput < WAY_W'(2))
        nextPlruInner[2] = 1'b1;
      else
        nextPlruInner[2] = 1'b0;
      unique case (accessedWayInput)
        WAY_W'(0): nextPlruInner[1] = 1'b1;
        WAY_W'(1): nextPlruInner[1] = 1'b0;
        WAY_W'(2): nextPlruInner[0] = 1'b1;
        default:   nextPlruInner[0] = 1'b0;
      endcase
      plru_after_access = nextPlruInner;
    end
  endfunction

  generate
    for (gWayInner = 0; gWayInner < WAYS; gWayInner = gWayInner + 1) begin : g_data
      rv32_sram_1rw #(
        .ADDR_W(INDEX_W),
        .DATA_W(128),
        .MASK_W(16)
      ) u_way (
        .clkInput(clkInput),
        .rdEnInput(acceptInner ||
                 (stateInner == FLUSH_SCAN && !flushDoneInner &&
                  validInner[flushWayInner][flushSetInner] &&
                  dirtyInner[flushWayInner][flushSetInner])),
        .rdAddrInput((stateInner == FLUSH_SCAN) ? flushSetInner : requestIndexInner),
        .rdDataOutput(sramRdataInner[gWayInner]),
        .wrEnInput((stateInner == TAG_READ && reqHitInner && savedWriteInner &&
                  (reqHitWayInner == WAY_W'(gWayInner))) ||
                 (stateInner == REFILL_WAIT && memResponseInput.valid &&
                  (victimWayInner == WAY_W'(gWayInner)))),
         .wrAddrInput(savedIndexRegisteredInner),
        .wrDataInput((stateInner == REFILL_WAIT) ?
                   (savedWriteInner ? refillMergedInner : memResponseInput.data) :
                   storeWdataInner),
        .wrMaskInput((stateInner == REFILL_WAIT) ? 16'hffff : storeWmaskInner)
      );
    end
  endgenerate

  assign cpuReqReadyOutput = (stateInner == IDLE) && !flushInput;

  always_comb begin
    requestIndexInner = cpuRequestInput.address[INDEX_W+3:4];
    requestTagInner = cpuRequestInput.address[31:INDEX_W+4];
    requestOffsetInner = cpuRequestInput.address[3:0];
    hitFoundInner = 1'b0;
    hitWayInner = '0;
    for (combWayInner = 0; combWayInner < WAYS; combWayInner = combWayInner + 1) begin
      if (!hitFoundInner && validInner[combWayInner][requestIndexInner] &&
          (tagInner[combWayInner][requestIndexInner] == requestTagInner)) begin
        hitFoundInner = 1'b1;
        hitWayInner = combWayInner[WAY_W-1:0];
      end
    end

    victimFoundInner = 1'b0;
    selectedVictimInner = plruInner[requestIndexInner][2] ?
      (plruInner[requestIndexInner][0] ? WAY_W'(3) : WAY_W'(2)) :
      (plruInner[requestIndexInner][1] ? WAY_W'(1) : WAY_W'(0));
    for (combWayInner = 0; combWayInner < WAYS; combWayInner = combWayInner + 1) begin
      if (!victimFoundInner && !validInner[combWayInner][requestIndexInner]) begin
        victimFoundInner = 1'b1;
        selectedVictimInner = combWayInner[WAY_W-1:0];
      end
    end

    acceptInner = cpuRequestInput.valid && cpuReqReadyOutput;

    savedIndexInner = savedAddrInner[INDEX_W+3:4];
    savedTagInner = savedAddrInner[31:INDEX_W+4];
    refillMergedInner = merge_store(memResponseInput.data, savedAddrInner[3:0],
                                  savedWdataInner, savedWstrbInner);

    hitLineInner = sramRdataInner[reqHitWayInner];
    victimLineInner = sramRdataInner[reqVictimInner];
    flushLineInner = sramRdataInner[flushWayInner];
    hitWordInner = extract_line_word(hitLineInner, savedOffsetInner);
    refillWordInner = extract_line_word(memResponseInput.data, savedAddrInner[3:0]);

    storeWmaskInner = 16'b0;
    storeWdataInner = 128'b0;
    for (combWayInner = 0; combWayInner < 4; combWayInner = combWayInner + 1) begin
      if (savedWstrbInner[combWayInner]) begin
        storeWmaskInner[savedOffsetInner + combWayInner[3:0]] = 1'b1;
        storeWdataInner[((32'(savedOffsetInner) + combWayInner) << 3) +: 8] =
          savedWdataInner[(combWayInner << 3) +: 8];
      end
    end

    cpuResponseOutput.valid = rspValidInner;
    cpuResponseOutput.readData = rspDataInner;
    flushDoneOutput = flushDoneInner;

    memRequestOutput.valid = (stateInner == WRITEBACK_REQUEST) ||
                      (stateInner == REFILL_REQUEST) ||
                      (stateInner == FLUSH_WRITEBACK);
    memRequestOutput.write = (stateInner == WRITEBACK_REQUEST) ||
                      (stateInner == FLUSH_WRITEBACK);
    memRequestOutput.address = 32'b0;
    memRequestOutput.writeData = 128'b0;
    if (stateInner == WRITEBACK_REQUEST) begin
      memRequestOutput.address = {tagInner[victimWayInner][savedIndexInner], savedIndexInner, 4'b0};
      memRequestOutput.writeData = evictDataInner;
    end else if (stateInner == REFILL_REQUEST) begin
      memRequestOutput.address = {savedAddrInner[31:4], 4'b0};
    end else if (stateInner == FLUSH_WRITEBACK) begin
      memRequestOutput.address = {tagInner[flushWayInner][flushSetInner], flushSetInner, 4'b0};
      memRequestOutput.writeData = flushDataInner;
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      stateInner <= IDLE;
      savedWriteInner <= 1'b0;
      savedAddrInner <= '0;
      savedWdataInner <= '0;
      savedWstrbInner <= '0;
      savedSizeInner <= '0;
      savedIndexRegisteredInner <= '0;
      savedOffsetInner <= '0;
      reqHitInner <= 1'b0;
      reqHitWayInner <= '0;
      reqVictimInner <= '0;
      victimWayInner <= '0;
      evictDataInner <= '0;
      flushDataInner <= '0;
      flushSetInner <= '0;
      flushWayInner <= '0;
      flushDoneInner <= 1'b0;
      rspValidInner <= 1'b0;
      rspDataInner <= '0;
      for (seqSetInner = 0; seqSetInner < SETS; seqSetInner = seqSetInner + 1) begin
        plruInner[seqSetInner] <= '0;
        for (seqWayInner = 0; seqWayInner < WAYS; seqWayInner = seqWayInner + 1) begin
          validInner[seqWayInner][seqSetInner] <= 1'b0;
          dirtyInner[seqWayInner][seqSetInner] <= 1'b0;
        end
      end
    end else begin
      rspValidInner <= 1'b0;
      unique case (stateInner)
        IDLE: begin
          if (flushInput && !flushDoneInner) begin
            flushSetInner <= '0;
            flushWayInner <= '0;
            stateInner <= FLUSH_SCAN;
          end else if (!flushInput) begin
            flushDoneInner <= 1'b0;
          end
          if (acceptInner) begin
            savedWriteInner <= cpuRequestInput.write;
            savedAddrInner <= cpuRequestInput.address;
            savedWdataInner <= cpuRequestInput.writeData;
            savedWstrbInner <= cpuRequestInput.writeStrobe;
            savedSizeInner <= cpuRequestInput.size;
            savedIndexRegisteredInner <= requestIndexInner;
            savedOffsetInner <= requestOffsetInner;
            reqHitInner <= hitFoundInner;
            reqHitWayInner <= hitWayInner;
            reqVictimInner <= selectedVictimInner;
            victimWayInner <= selectedVictimInner;
            stateInner <= TAG_READ;
          end
        end
        TAG_READ: begin
          if (reqHitInner) begin
            plruInner[savedIndexRegisteredInner] <=
              plru_after_access(plruInner[savedIndexRegisteredInner], reqHitWayInner);
            if (savedWriteInner) begin
              dirtyInner[reqHitWayInner][savedIndexRegisteredInner] <= 1'b1;
            end else begin
              rspValidInner <= 1'b1;
              rspDataInner <= hitWordInner;
            end
            stateInner <= IDLE;
          end else begin
            if (validInner[reqVictimInner][savedIndexRegisteredInner] &&
                dirtyInner[reqVictimInner][savedIndexRegisteredInner]) begin
              evictDataInner <= victimLineInner;
              stateInner <= WRITEBACK_REQUEST;
            end else begin
              stateInner <= REFILL_REQUEST;
            end
          end
        end
        WRITEBACK_REQUEST: begin
          if (memRequestOutput.valid && memReqReadyInput)
            stateInner <= REFILL_REQUEST;
        end
        REFILL_REQUEST: begin
          if (memRequestOutput.valid && memReqReadyInput)
            stateInner <= REFILL_WAIT;
        end
        REFILL_WAIT: begin
          if (memResponseInput.valid) begin
            validInner[victimWayInner][savedIndexRegisteredInner] <= 1'b1;
            dirtyInner[victimWayInner][savedIndexRegisteredInner] <= savedWriteInner;
            tagInner[victimWayInner][savedIndexRegisteredInner] <= savedTagInner;
            plruInner[savedIndexRegisteredInner] <=
              plru_after_access(plruInner[savedIndexRegisteredInner], victimWayInner);
            if (!savedWriteInner) begin
              rspValidInner <= 1'b1;
              rspDataInner <= refillWordInner;
            end
            stateInner <= IDLE;
          end
        end
        FLUSH_SCAN: begin
          if (validInner[flushWayInner][flushSetInner] &&
              dirtyInner[flushWayInner][flushSetInner]) begin
            stateInner <= FLUSH_READ;
          end else if ((flushWayInner == WAY_W'(WAYS-1)) &&
                       (flushSetInner == INDEX_W'(SETS-1))) begin
            flushDoneInner <= 1'b1;
            stateInner <= IDLE;
          end else if (flushWayInner == WAY_W'(WAYS-1)) begin
            flushWayInner <= '0;
            flushSetInner <= flushSetNext;
          end else begin
            flushWayInner <= flushWayNext;
          end
        end
        FLUSH_READ: begin
          flushDataInner <= flushLineInner;
          stateInner <= FLUSH_WRITEBACK;
        end
        FLUSH_WRITEBACK: begin
          if (memRequestOutput.valid && memReqReadyInput) begin
            dirtyInner[flushWayInner][flushSetInner] <= 1'b0;
            if ((flushWayInner == WAY_W'(WAYS-1)) &&
                (flushSetInner == INDEX_W'(SETS-1))) begin
              flushDoneInner <= 1'b1;
              stateInner <= IDLE;
            end else if (flushWayInner == WAY_W'(WAYS-1)) begin
              flushWayInner <= '0;
              flushSetInner <= flushSetNext;
              stateInner <= FLUSH_SCAN;
            end else begin
              flushWayInner <= flushWayNext;
              stateInner <= FLUSH_SCAN;
            end
          end
        end
        default: stateInner <= IDLE;
      endcase
    end
  end
endmodule
