// Register-backed D$: combinational Q[n] reads, edge writes, one-cycle hits.
// Normal READY/WAIT behavior mirrors the two software DCache implementations.
module rv32_dcache #(
  parameter int unsigned SETS = rv32_pkg::DCACHE_SETS,
  parameter int unsigned WAYS = rv32_pkg::DCACHE_WAYS
) (
  input logic clkInput,
  input logic rstNInput,
  input rv32_pkg::dcache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::dcache_cpu_response_output_t cpuResponseOutput,
  output rv32_pkg::dcache_line_request_output_t memRequestOutput,
  input logic memReadReadyInput,
  input logic memWriteReadyInput,
  input rv32_pkg::cache_line_response_input_t memResponseInput,
  input logic memWriteDoneInput,
  input logic flushInput,
  output logic flushDoneOutput,
  output logic idleOutput
);
  import rv32_pkg::*;
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned WAY_W = WAYS <= 1 ? 1 : $clog2(WAYS);
  localparam int unsigned OFFSET_W = $clog2(CACHE_LINE_BYTES);
  localparam int unsigned TAG_W = 32 - INDEX_W - OFFSET_W;
  typedef enum logic [1:0] {READY, WAIT_FILL, FLUSH_SCAN, FLUSH_WAIT} state_e;
  state_e stateInner;
  logic validInner [WAYS][SETS], dirtyInner [WAYS][SETS];
  logic [TAG_W-1:0] tagInner [WAYS][SETS];
  logic [2:0] plruInner [SETS];
  wire [CACHE_LINE_BITS-1:0] dataInner [WAYS][SETS];
  dcache_cpu_request_input_t savedRequestInner;
  logic [WAY_W-1:0] victimWayInner;
  logic readValidInner, writeValidInner, readSentInner, writePendingInner;
  logic [31:0] readAddressInner, writeAddressInner;
  logic [CACHE_LINE_BITS-1:0] writeDataInner, replyDataInner;
  logic replyValidInner;
  logic rspValidInner;
  logic [31:0] rspDataInner;
  logic [INDEX_W-1:0] flushSetInner, flushSetNext;
  logic [WAY_W-1:0] flushWayInner, flushWayNext;
  logic flushDoneInner, unusedSetCarryInner, unusedWayCarryInner;
  logic [INDEX_W-1:0] requestIndexInner, savedIndexInner;
  logic [TAG_W-1:0] requestTagInner, savedTagInner;
  logic [OFFSET_W-1:0] requestOffsetInner;
  logic hitFoundInner, victimFoundInner;
  logic [WAY_W-1:0] hitWayInner, selectedVictimInner;
  logic acceptInner, storeHitInner, readFireInner, writeFireInner;
  logic writeCompleteInner, writeIdleInner, fillFireInner;
  logic [CACHE_LINE_BITS-1:0] fillDataInner, mergedFillInner;
  logic [CACHE_LINE_BYTES-1:0] hitByteEnableInner;
  logic [CACHE_LINE_BITS-1:0] hitByteDataInner;
  integer wayInner, setInner;

  rv32_add #(.WIDTH(INDEX_W)) u_flush_set_next (
    .aInput(flushSetInner), .bInput(INDEX_W'(1)), .cinInput(1'b0),
    .sumOutput(flushSetNext), .coutOutput(unusedSetCarryInner)
  );
  rv32_add #(.WIDTH(WAY_W)) u_flush_way_next (
    .aInput(flushWayInner), .bInput(WAY_W'(1)), .cinInput(1'b0),
    .sumOutput(flushWayNext), .coutOutput(unusedWayCarryInner)
  );

  function automatic logic [CACHE_LINE_BITS-1:0] merge_store(
    input logic [CACHE_LINE_BITS-1:0] lineInput,
    input logic [OFFSET_W-1:0] offsetInput,
    input logic [31:0] valueInput,
    input logic [3:0] maskInput
  );
    logic [CACHE_LINE_BITS-1:0] result;
    begin
      result = lineInput;
      for (int b = 0; b < 4; b = b + 1)
        if (maskInput[b]) result[((32'(offsetInput) + 32'(b)) << 3) +: 8] = valueInput[(b << 3) +: 8];
      return result;
    end
  endfunction
  function automatic logic [31:0] extract_word(
    input logic [CACHE_LINE_BITS-1:0] lineInput,
    input logic [OFFSET_W-1:0] offsetInput
  );
    logic [CACHE_LINE_BITS-1:0] shifted;
    begin
      shifted = lineInput >> (32'(offsetInput) << 3);
      return shifted[31:0];
    end
  endfunction
  function automatic logic [2:0] plru_after(input logic [2:0] oldInput, input logic [WAY_W-1:0] wayInput);
    logic [2:0] result;
    begin
      result = oldInput;
      result[2] = 2'(wayInput) < 2;
      case (2'(wayInput))
        0: result[1] = 1'b1;
        1: result[1] = 1'b0;
        2: result[0] = 1'b1;
        default: result[0] = 1'b0;
      endcase
      return WAYS == 1 ? 3'b0 : result;
    end
  endfunction

  // Each line is an explicit bank of flip-flops, not an inferred SRAM macro.
  // Invalid payload does not need reset: valid=0 hides it until a full fill.
  for (genvar w = 0; w < WAYS; w = w + 1) begin : g_way
    for (genvar s = 0; s < SETS; s = s + 1) begin : g_line
      logic [CACHE_LINE_BITS-1:0] lineRegisters;
      assign dataInner[w][s] = lineRegisters;
      always_ff @(posedge clkInput) begin
        if (rstNInput) begin
          for (int b = 0; b < CACHE_LINE_BYTES; b = b + 1) begin
            if (fillFireInner && victimWayInner == WAY_W'(w) && savedIndexInner == INDEX_W'(s))
              lineRegisters[(b << 3) +: 8] <= mergedFillInner[(b << 3) +: 8];
            else if (storeHitInner && hitWayInner == WAY_W'(w) && requestIndexInner == INDEX_W'(s) && hitByteEnableInner[b])
              lineRegisters[(b << 3) +: 8] <= hitByteDataInner[(b << 3) +: 8];
          end
        end
      end
    end
  end

  assign requestIndexInner = cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W];
  assign requestTagInner = cpuRequestInput.address[31:INDEX_W+OFFSET_W];
  assign requestOffsetInner = cpuRequestInput.address[OFFSET_W-1:0];
  assign savedIndexInner = savedRequestInner.address[INDEX_W+OFFSET_W-1:OFFSET_W];
  assign savedTagInner = savedRequestInner.address[31:INDEX_W+OFFSET_W];
  assign cpuReqReadyOutput = stateInner == READY && !flushInput;
  assign idleOutput = stateInner == READY && !readValidInner && !writeValidInner && !writePendingInner;
  assign acceptInner = cpuRequestInput.valid && cpuReqReadyOutput;
  assign storeHitInner = acceptInner && hitFoundInner && cpuRequestInput.write;
  assign readFireInner = readValidInner && memReadReadyInput;
  assign writeFireInner = writeValidInner && memWriteReadyInput;
  assign writeCompleteInner = memWriteDoneInput && (writePendingInner || writeFireInner);
  assign writeIdleInner = (!writeValidInner && !writePendingInner) || writeCompleteInner;
  assign fillFireInner = stateInner == WAIT_FILL &&
    (replyValidInner || (memResponseInput.valid && readSentInner)) &&
    !readValidInner && writeIdleInner;
  assign fillDataInner = replyValidInner ? replyDataInner : memResponseInput.data;
  assign mergedFillInner = savedRequestInner.write ?
    merge_store(fillDataInner, savedRequestInner.address[OFFSET_W-1:0],
      savedRequestInner.writeData, savedRequestInner.writeStrobe) : fillDataInner;
  assign cpuResponseOutput = '{valid:rspValidInner, readData:rspDataInner};
  assign memRequestOutput = '{readValid:readValidInner, readAddress:readAddressInner,
    writeValid:writeValidInner, writeAddress:writeAddressInner, writeData:writeDataInner};
  assign flushDoneOutput = flushDoneInner;

  always_comb begin
    hitByteEnableInner = '0; hitByteDataInner = '0;
    for (int b = 0; b < 4; b = b + 1) begin
      if (cpuRequestInput.writeStrobe[b] && 32'(requestOffsetInner) + 32'(b) < CACHE_LINE_BYTES) begin
        hitByteEnableInner[32'(requestOffsetInner) + 32'(b)] = 1'b1;
        hitByteDataInner[((32'(requestOffsetInner) + 32'(b)) << 3) +: 8] = cpuRequestInput.writeData[(b << 3) +: 8];
      end
    end
    hitFoundInner = 1'b0; hitWayInner = '0;
    victimFoundInner = 1'b0;
    selectedVictimInner = WAYS == 1 ? WAY_W'(0) : plruInner[requestIndexInner][2] ?
      (plruInner[requestIndexInner][0] ? WAY_W'(3) : WAY_W'(2)) :
      (plruInner[requestIndexInner][1] ? WAY_W'(1) : WAY_W'(0));
    for (int w = 0; w < WAYS; w = w + 1) begin
      if (validInner[w][requestIndexInner] && tagInner[w][requestIndexInner] == requestTagInner) begin
        hitFoundInner = 1'b1; hitWayInner = WAY_W'(w);
      end
      if (!victimFoundInner && !validInner[w][requestIndexInner]) begin
        victimFoundInner = 1'b1; selectedVictimInner = WAY_W'(w);
      end
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      stateInner <= READY; savedRequestInner <= '0; victimWayInner <= '0;
      readValidInner <= 1'b0; writeValidInner <= 1'b0; readSentInner <= 1'b0;
      writePendingInner <= 1'b0; readAddressInner <= '0; writeAddressInner <= '0;
      writeDataInner <= '0; replyValidInner <= 1'b0; replyDataInner <= '0;
      rspValidInner <= 1'b0; rspDataInner <= '0;
      flushSetInner <= '0; flushWayInner <= '0; flushDoneInner <= 1'b0;
      for (setInner = 0; setInner < SETS; setInner = setInner + 1) begin
        plruInner[setInner] <= '0;
        for (wayInner = 0; wayInner < WAYS; wayInner = wayInner + 1) begin
          validInner[wayInner][setInner] <= 1'b0;
          dirtyInner[wayInner][setInner] <= 1'b0;
          tagInner[wayInner][setInner] <= '0;
        end
      end
    end else begin
      rspValidInner <= 1'b0;
      if (readFireInner) begin readValidInner <= 1'b0; readSentInner <= 1'b1; end
      if (writeFireInner) begin writeValidInner <= 1'b0; writePendingInner <= !writeCompleteInner; end
      if (writeCompleteInner) writePendingInner <= 1'b0;
      if (memResponseInput.valid && readSentInner) begin
        replyValidInner <= 1'b1; replyDataInner <= memResponseInput.data;
      end
      case (stateInner)
        READY: begin
          if (!flushInput) flushDoneInner <= 1'b0;
          if (flushInput && !flushDoneInner) begin
            flushSetInner <= '0; flushWayInner <= '0; stateInner <= FLUSH_SCAN;
          end else if (acceptInner) begin
            if (hitFoundInner) begin
              plruInner[requestIndexInner] <= plru_after(plruInner[requestIndexInner], hitWayInner);
              if (cpuRequestInput.write) dirtyInner[hitWayInner][requestIndexInner] <= 1'b1;
              else begin
                rspValidInner <= 1'b1;
                rspDataInner <= extract_word(dataInner[hitWayInner][requestIndexInner], requestOffsetInner);
              end
            end else begin
              savedRequestInner <= cpuRequestInput; victimWayInner <= selectedVictimInner;
              readValidInner <= 1'b1;
              readAddressInner <= {cpuRequestInput.address[31:OFFSET_W], {OFFSET_W{1'b0}}};
              readSentInner <= 1'b0; replyValidInner <= 1'b0;
              writeValidInner <= dirtyInner[selectedVictimInner][requestIndexInner];
              if (dirtyInner[selectedVictimInner][requestIndexInner]) begin
                writeAddressInner <= {tagInner[selectedVictimInner][requestIndexInner], requestIndexInner, {OFFSET_W{1'b0}}};
                writeDataInner <= dataInner[selectedVictimInner][requestIndexInner];
              end
              stateInner <= WAIT_FILL;
            end
          end
        end
        WAIT_FILL: if (fillFireInner) begin
          validInner[victimWayInner][savedIndexInner] <= 1'b1;
          dirtyInner[victimWayInner][savedIndexInner] <= savedRequestInner.write;
          tagInner[victimWayInner][savedIndexInner] <= savedTagInner;
          plruInner[savedIndexInner] <= plru_after(plruInner[savedIndexInner], victimWayInner);
          if (!savedRequestInner.write) begin
            rspValidInner <= 1'b1;
            rspDataInner <= extract_word(fillDataInner, savedRequestInner.address[OFFSET_W-1:0]);
          end
          replyValidInner <= 1'b0; readSentInner <= 1'b0; stateInner <= READY;
        end
        FLUSH_SCAN: begin
          if (validInner[flushWayInner][flushSetInner] && dirtyInner[flushWayInner][flushSetInner]) begin
            writeValidInner <= 1'b1;
            writeAddressInner <= {tagInner[flushWayInner][flushSetInner], flushSetInner, {OFFSET_W{1'b0}}};
            writeDataInner <= dataInner[flushWayInner][flushSetInner];
            stateInner <= FLUSH_WAIT;
          end else if (flushWayInner == WAY_W'(WAYS-1) && flushSetInner == INDEX_W'(SETS-1)) begin
            flushDoneInner <= 1'b1; stateInner <= READY;
          end else if (flushWayInner == WAY_W'(WAYS-1)) begin
            flushWayInner <= '0; flushSetInner <= flushSetNext;
          end else flushWayInner <= flushWayNext;
        end
        FLUSH_WAIT: if (writeCompleteInner) begin
          dirtyInner[flushWayInner][flushSetInner] <= 1'b0;
          if (flushWayInner == WAY_W'(WAYS-1) && flushSetInner == INDEX_W'(SETS-1)) begin
            flushDoneInner <= 1'b1; stateInner <= READY;
          end else begin
            if (flushWayInner == WAY_W'(WAYS-1)) begin flushWayInner <= '0; flushSetInner <= flushSetNext; end
            else flushWayInner <= flushWayNext;
            stateInner <= FLUSH_SCAN;
          end
        end
        default: stateInner <= READY;
      endcase
    end
  end
endmodule
