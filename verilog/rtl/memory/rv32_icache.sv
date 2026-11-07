// Width-selected ordered requests, synchronous SRAM hits, an old-head read
// bypass, and one old miss completed by each accepted refill.
module rv32_icache #(
  parameter int unsigned SETS = rv32_pkg::ICACHE_SETS,
  parameter int unsigned FETCH_WIDTH = 1,
  parameter int unsigned REQUEST_DEPTH = (rv32_pkg::FETCH_REQUEST_ENTRIES/FETCH_WIDTH > 1) ? rv32_pkg::FETCH_REQUEST_ENTRIES/FETCH_WIDTH : 2,
  parameter int unsigned WAYS = rv32_pkg::ICACHE_WAYS
) (
  input logic clkInput, rstNInput,
  input logic freezeInput,
  input logic flushInput,
  input logic secondInput,
  input logic [31:0] predecodeAddressInput,
  output logic [31:0] secondInstructionOutput,
  output rv32_pkg::icache_fetch_hint_t predecodeOutput,
  input rv32_pkg::icache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::icache_cpu_response_output_t cpuResponseOutput,
  input logic cpuRspReadyInput,
  output rv32_pkg::cache_line_request_output_t memRequestOutput,
  input logic memReqReadyInput,
  input rv32_pkg::icache_line_response_input_t memResponseInput,
  output logic memRspReadyOutput,
  output logic memFlushOutput,
  output logic [127:0] packetInstructionsOutput
);
  import rv32_pkg::*;
  if (FETCH_WIDTH != 1 && FETCH_WIDTH != 2 && FETCH_WIDTH != 4) begin : g_invalid_fetch_width
    initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
  end
  if (WAYS != 1 && WAYS != 2 && WAYS != 4) begin : g_invalid_ways
    initial $fatal(1, "ICache WAYS must be 1, 2 or 4");
  end
  localparam int unsigned FETCH_DATA_BITS = 32 * FETCH_WIDTH;
  localparam int unsigned OFFSET_W = $clog2(CACHE_LINE_BYTES);
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned TAG_W = 32 - INDEX_W - OFFSET_W;
  localparam int unsigned SLOT_W = $clog2(REQUEST_DEPTH);
  localparam int unsigned COUNT_W = $clog2(REQUEST_DEPTH + 1);
  localparam int unsigned WORD_W = OFFSET_W - 2;
  localparam int unsigned WAY_W = WAYS > 1 ? $clog2(WAYS) : 1;
  localparam int unsigned PLRU_W = WAYS == 4 ? 3 : 1;

  // Tags/valid bits are registers; instruction DATA exists only in u_data SRAM.
  logic validInner [SETS][WAYS];
  logic [TAG_W-1:0] tagInner [SETS][WAYS];
  logic [PLRU_W-1:0] plruInner [SETS];
/* verilator lint_off UNUSEDSIGNAL */   logic [WAY_W-1:0] hitWayInner, predecodeWayInner, fillWayInner, readWayInner; /* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_off UNUSEDSIGNAL */   logic predecodeHitInner; /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] requestAddressInner [REQUEST_DEPTH];
  logic [31:0] requestPredictedPcInner [REQUEST_DEPTH];
  bpu_ckpt_id_t requestCheckpointInner [REQUEST_DEPTH];
  logic requestReadyInner [REQUEST_DEPTH];
  logic [FETCH_DATA_BITS-1:0] requestInstructionInner [REQUEST_DEPTH];
/* verilator lint_off UNUSEDSIGNAL */   logic requestSecondInner [REQUEST_DEPTH]; /* verilator lint_on UNUSEDSIGNAL */
  logic [SLOT_W-1:0] headInner, tailSlotInner;
  logic [COUNT_W-1:0] countInner;
  logic readValidInner;
  logic [SLOT_W-1:0] readIndexInner;
  logic [WORD_W-1:0] readLaneInner;
  logic hitInner, refillHitInner, readBlockedInner;
  logic headReadReadyInner, responseFireInner, requestFireInner;
  logic refillFoundInner, fillFireInner;
  logic [SLOT_W-1:0] refillSlotInner;
  logic sramEnableInner;
  logic [INDEX_W-1:0] sramAddressInner;
  logic [CACHE_LINE_BITS-1:0] sramRdataInner;
  logic [CACHE_LINE_BITS-1:0] wayRdataInner [WAYS];
  logic [FETCH_DATA_BITS-1:0] readWordInner, fillWordInner, forwardWordInner;

/* verilator lint_off UNUSEDSIGNAL */   function automatic logic is_control(input logic [31:0] instruction); /* verilator lint_on UNUSEDSIGNAL */
    return instruction[6:0]==OPCODE_BRANCH || instruction[6:0]==OPCODE_JAL ||
      (instruction[6:0]==OPCODE_JALR && instruction[14:12]==3'b000);
  endfunction
  function automatic logic [63:0] packet_words(input logic [CACHE_LINE_BITS-1:0] lineData,
/* verilator lint_off UNUSEDSIGNAL */                                                input logic [31:0] address); /* verilator lint_on UNUSEDSIGNAL */
    return 64'(lineData>>(32'(address[OFFSET_W-1:2])<<5));
  endfunction
  function automatic logic [PLRU_W-1:0] touch_way(
    input logic [PLRU_W-1:0] bitsInput, input logic [WAY_W-1:0] wayInput
  );
    touch_way = bitsInput;
    if (WAYS == 2) touch_way = PLRU_W'(wayInput);
    if (WAYS == 4) begin
      if (int'(wayInput) >= 2)
        touch_way = PLRU_W'({1'b1, 1'(bitsInput >> 1), 1'(wayInput)});
      else
        touch_way = PLRU_W'({1'b0, 1'(wayInput), bitsInput[0]});
    end
  endfunction
  // Three independent old-state lookups. Refill chooses the lowest invalid
  // way, otherwise the opposite of the recorded MRU/tree-PLRU direction.
  always_comb begin
    hitInner = 1'b0;
    hitWayInner = '0;
    predecodeHitInner = 1'b0;
    predecodeWayInner = '0;
    for (int way = 0; way < WAYS; way++) begin
      if (validInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][way] &&
          tagInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][way] == cpuRequestInput.address[31:INDEX_W+OFFSET_W]) begin
        hitInner = 1'b1;
        hitWayInner = WAY_W'(way);
      end
      if (validInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][way] &&
          tagInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][way] == predecodeAddressInput[31:INDEX_W+OFFSET_W]) begin
        predecodeHitInner = 1'b1;
        predecodeWayInner = WAY_W'(way);
      end
    end
  end
  always_comb begin
    fillWayInner = '0;
    if (WAYS == 2)
      fillWayInner = WAY_W'(!plruInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][0]);
    if (WAYS == 4) begin
      if (plruInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][PLRU_W-1])
        fillWayInner = WAY_W'(((int'(plruInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]]) >> 1) & 1) != 0 ? 0 : 1);
      else
        fillWayInner = WAY_W'(plruInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][0] ? 2 : 3);
    end
    for (int way = WAYS-1; way >= 0; way--)
      if (!validInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][way]) fillWayInner = WAY_W'(way);
    // Two old misses may name the same line. Their separate physical replies
    // refresh the existing way, never install duplicate valid tags in a set.
    for (int way = 0; way < WAYS; way++)
      if (validInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][way] &&
          tagInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][way] == memResponseInput.address[31:INDEX_W+OFFSET_W])
        fillWayInner = WAY_W'(way);
  end
  assign sramRdataInner = wayRdataInner[readWayInner];
  generate if(FETCH_WIDTH>=2)begin : g_predecode
    // Metadata only: instruction DATA still lives exclusively in real SRAM.
    // The mask is published by the same fill that publishes its tag/valid.
    logic [CACHE_LINE_BYTES/4-1:0] controlMaskInner [SETS][WAYS];
    logic [CACHE_LINE_BYTES/4-1:0] fillMaskInner;
    always_comb begin
      for(int wordIndex=0;wordIndex<CACHE_LINE_BYTES/4;wordIndex++)
        fillMaskInner[wordIndex]=is_control(memResponseInput.data[wordIndex*32+:32]);
    end
    always_ff @(posedge clkInput)
      if(fillFireInner)controlMaskInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][fillWayInner]<=fillMaskInner;
    // The predecode PC comes straight from the old frontend PC register, not
    // the packed request which also carries this prediction's NEXT PC.
    assign predecodeOutput.hit=predecodeHitInner;
    assign predecodeOutput.firstControl=predecodeHitInner&&
      controlMaskInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][predecodeWayInner][predecodeAddressInput[OFFSET_W-1:2]];
    if (FETCH_WIDTH==4) begin : g_four_hints
      // Relative lanes may cross 16 bytes; clip only at the ICache line end.
/* verilator lint_off UNUSEDSIGNAL */       logic [3:0] controls; /* verilator lint_on UNUSEDSIGNAL */
      always_comb begin
        controls='0;
        for (int lane=0;lane<4;lane++)
          if (predecodeHitInner && lane < CACHE_LINE_BYTES/4-int'(predecodeAddressInput[OFFSET_W-1:2]))
            controls[lane]=controlMaskInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][predecodeWayInner]
              [int'(predecodeAddressInput[OFFSET_W-1:2])+lane];
      end
      assign predecodeOutput.secondControl=controls[1];
      assign predecodeOutput.thirdControl=controls[2];
      assign predecodeOutput.fourthControl=controls[3];
    end else begin : g_two_hints
      assign predecodeOutput.secondControl=predecodeHitInner&&predecodeAddressInput[OFFSET_W-1:2]!=WORD_W'(CACHE_LINE_BYTES/4-1)&&
        controlMaskInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][predecodeWayInner][predecodeAddressInput[OFFSET_W-1:2]+WORD_W'(1)];
      assign predecodeOutput.thirdControl=1'b0;
      assign predecodeOutput.fourthControl=1'b0;
    end
  end else begin : g_no_predecode
    assign predecodeOutput='0;
  end endgenerate

  assign tailSlotInner = headInner + SLOT_W'(countInner);
  assign headReadReadyInner = countInner != 0 && !requestReadyInner[headInner] &&
    readValidInner && readIndexInner == headInner;
  generate if (FETCH_WIDTH == 4) begin : g_four_packet_words
    assign readWordInner = 128'(sramRdataInner >> (32'(readLaneInner) << 5));
    assign fillWordInner = 128'(memResponseInput.data >> (32'(requestAddressInner[refillSlotInner][OFFSET_W-1:2]) << 5));
    assign forwardWordInner = 128'(memResponseInput.data >> (32'(cpuRequestInput.address[OFFSET_W-1:2]) << 5));
    assign secondInstructionOutput = requestSecondInner[headInner] ?
      (headReadReadyInner ? readWordInner[63:32] : requestInstructionInner[headInner][63:32]) : 32'b0;
  end else if (FETCH_WIDTH == 2) begin : g_packet_words
    assign readWordInner = packet_words(sramRdataInner,32'(readLaneInner)<<2);
    assign fillWordInner = packet_words(memResponseInput.data,requestAddressInner[refillSlotInner]);
    assign forwardWordInner = packet_words(memResponseInput.data,cpuRequestInput.address);
    assign secondInstructionOutput = requestSecondInner[headInner] ?
      (headReadReadyInner ? readWordInner[63:32] : requestInstructionInner[headInner][63:32]) : 32'b0;
  end else begin : g_scalar_word
    assign readWordInner = 32'(sramRdataInner >> (32'(readLaneInner) << 5));
    assign fillWordInner = 32'(memResponseInput.data >> (32'(requestAddressInner[refillSlotInner][OFFSET_W-1:2]) << 5));
    assign forwardWordInner = 32'(memResponseInput.data >> (32'(cpuRequestInput.address[OFFSET_W-1:2]) << 5));
    assign secondInstructionOutput = 32'b0;
  end endgenerate
  assign packetInstructionsOutput = 128'(headReadReadyInner ? readWordInner : requestInstructionInner[headInner]);
  assign cpuResponseOutput.valid = countInner != 0 &&
    (requestReadyInner[headInner] || headReadReadyInner);
  assign cpuResponseOutput.instruction = headReadReadyInner ? readWordInner[31:0] : requestInstructionInner[headInner][31:0];
  assign cpuResponseOutput.address = requestAddressInner[headInner];
  assign cpuResponseOutput.predictedProgramCounter = requestPredictedPcInner[headInner];
  assign cpuResponseOutput.predictorCheckpointId = requestCheckpointInner[headInner];
  assign responseFireInner = cpuResponseOutput.valid && cpuRspReadyInput && !flushInput;

  // Select in OLD queue age order. A pending SRAM hit is not a refill target.
  always_comb begin
    refillFoundInner = 1'b0;
    refillSlotInner = '0;
    for (int age = 0; age < REQUEST_DEPTH; age = age + 1) begin
      if (memResponseInput.valid && age < int'(countInner) && !refillFoundInner &&
          !requestReadyInner[SLOT_W'(headInner + SLOT_W'(age))] &&
          !(readValidInner && readIndexInner == SLOT_W'(headInner + SLOT_W'(age))) &&
          {requestAddressInner[SLOT_W'(headInner + SLOT_W'(age))][31:OFFSET_W], {OFFSET_W{1'b0}}} == memResponseInput.address) begin
        refillFoundInner = 1'b1;
        refillSlotInner = SLOT_W'(headInner + SLOT_W'(age));
      end
    end
  end
  assign memRspReadyOutput = !freezeInput && !flushInput && refillFoundInner;
  assign fillFireInner = memResponseInput.valid && memRspReadyOutput;
  assign refillHitInner = fillFireInner &&
    cpuRequestInput.address[31:OFFSET_W] == memResponseInput.address[31:OFFSET_W];
  assign readBlockedInner = fillFireInner && hitInner && !refillHitInner;
  // Matches CPU::comb(): even a hit observes old IMEM fullness. Only accepted
  // same-line refill forwarding bypasses that gate; no full IMEM pop bypass.
  assign cpuReqReadyOutput = !freezeInput && !flushInput &&
    (countInner < COUNT_W'(REQUEST_DEPTH) || responseFireInner) &&
    (memReqReadyInput || refillHitInner) && !readBlockedInner;
  assign requestFireInner = cpuRequestInput.valid && cpuReqReadyOutput;
  always_comb begin
    memRequestOutput = '0;
    memRequestOutput.valid = requestFireInner && !hitInner && !refillHitInner;
    memRequestOutput.address = {cpuRequestInput.address[31:OFFSET_W], {OFFSET_W{1'b0}}};
  end
  assign memFlushOutput = flushInput;

  // Actual framework macro interface from common/rv32_sram.sv, one 1RW port.
  // Refill owns the port; a new same-line request uses the accepted fill bus.
  // Read speculatively while active, independent of late backend/FQ ready.
  // Only requestFire/hit creates readValid; unused reads cannot create a CPU
  // response or a transport. A fill still owns the real synchronous 1RW port.
  // This trades extra idle SRAM reads for a shorter CE control path; logical
  // admission, fill writes, synchronous read capture and queue timing stay put.
  // The public SRAM makes rdata undefined on a disabled edge. A frozen,
  // not-yet-captured synchronous hit must therefore keep reading its ORIGINAL
  // row; retaining readValid alone does not retain SRAM data. No fill or CPU
  // acceptance is authorized by this refresh, including a held freeze+flush.
  assign sramEnableInner = rstNInput && ((!freezeInput && !flushInput) || (freezeInput && readValidInner));
  assign sramAddressInner = fillFireInner ? memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W] :
    (freezeInput && readValidInner) ? requestAddressInner[readIndexInner][INDEX_W+OFFSET_W-1:OFFSET_W] :
    cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W];
  for (genvar way = 0; way < WAYS; way++) begin : g_way
    sram_fakeram #(.DEPTH(SETS), .WIDTH(CACHE_LINE_BITS), .WRITE_GRANULARITY(32)) u_data (
      .clk(clkInput), .en(sramEnableInner), .we(fillFireInner && fillWayInner == WAY_W'(way)),
      .addr(sramAddressInner), .wdata(memResponseInput.data),
      .wmask({(CACHE_LINE_BYTES >> 2){1'b1}}), .rdata(wayRdataInner[way])
    );
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      countInner <= '0;
      readValidInner <= 1'b0;
      readIndexInner <= '0;
      readLaneInner <= '0;
      readWayInner <= '0;
      for (int s = 0; s < SETS; s = s + 1) begin
        plruInner[s] <= '0;
        for (int way = 0; way < WAYS; way++) begin
          validInner[s][way] <= 1'b0;
          tagInner[s][way] <= '0;
        end
      end
      for (int q = 0; q < REQUEST_DEPTH; q = q + 1) begin
        requestAddressInner[q] <= '0;
        requestPredictedPcInner[q] <= '0;
        requestCheckpointInner[q] <= '0;
        requestReadyInner[q] <= 1'b0;
        requestInstructionInner[q] <= '0;
        requestSecondInner[q] <= 1'b0;
      end
    end else if (!freezeInput && flushInput) begin
      // Logical requests and read identities die; non-speculative cache stays.
      headInner <= '0;
      countInner <= '0;
      readValidInner <= 1'b0;
      readIndexInner <= '0;
      readLaneInner <= '0;
      for (int q = 0; q < REQUEST_DEPTH; q = q + 1)
        requestReadyInner[q] <= 1'b0;
    end else if (!freezeInput) begin
      if (responseFireInner) headInner <= headInner + SLOT_W'(1);
      unique case ({requestFireInner, responseFireInner})
        2'b10: countInner <= countInner + COUNT_W'(1);
        2'b01: countInner <= countInner - COUNT_W'(1);
        default: ;
      endcase
      readValidInner <= requestFireInner && hitInner && !fillFireInner;
      if (requestFireInner && hitInner && !refillHitInner) begin
        readIndexInner <= tailSlotInner;
        readLaneInner <= cpuRequestInput.address[OFFSET_W-1:2];
        readWayInner <= hitWayInner;
      end
      if (fillFireInner) begin
        validInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][fillWayInner] <= 1'b1;
        tagInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]][fillWayInner] <= memResponseInput.address[31:INDEX_W+OFFSET_W];
        plruInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] <=
          touch_way(plruInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]], fillWayInner);
      end else if (requestFireInner && hitInner) begin
        plruInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] <=
          touch_way(plruInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]], hitWayInner);
      end
      for (int q = 0; q < REQUEST_DEPTH; q = q + 1) begin
        // Initialization wins the full pop/push same-slot case. The OLD head
        // bypass read is already consumed and must never resurrect this slot.
        if (requestFireInner && tailSlotInner == SLOT_W'(q)) begin
          requestAddressInner[q] <= cpuRequestInput.address;
          requestPredictedPcInner[q] <= cpuRequestInput.predictedProgramCounter;
          requestCheckpointInner[q] <= cpuRequestInput.predictorCheckpointId;
            requestSecondInner[q] <= FETCH_WIDTH>=2&&secondInput;
          requestReadyInner[q] <= refillHitInner;
           requestInstructionInner[q] <= refillHitInner ? forwardWordInner : '0;
        end else begin
          if (responseFireInner && headInner == SLOT_W'(q)) requestReadyInner[q] <= 1'b0;
          else if (fillFireInner && refillSlotInner == SLOT_W'(q)) requestReadyInner[q] <= 1'b1;
          else if (readValidInner && readIndexInner == SLOT_W'(q) &&
                   !(responseFireInner && headReadReadyInner)) requestReadyInner[q] <= 1'b1;
          if (fillFireInner && refillSlotInner == SLOT_W'(q)) requestInstructionInner[q] <= fillWordInner;
          else if (readValidInner && readIndexInner == SLOT_W'(q) &&
                   !(responseFireInner && headReadReadyInner)) requestInstructionInner[q] <= readWordInner;
        end
      end
    end
  end
`ifndef SYNTHESIS
  initial begin
    assert (SETS >= 2 && (SETS & (SETS-1)) == 0 && REQUEST_DEPTH >= 2 && (REQUEST_DEPTH & (REQUEST_DEPTH-1)) == 0)
      else $fatal(1, "ICache needs power-of-two SRAM rows and request slots");
  end
  always @(posedge clkInput) if (rstNInput) begin
    assert (countInner <= COUNT_W'(REQUEST_DEPTH)) else $fatal(1, "ICache request capacity exceeded");
    if(FETCH_WIDTH==2&&requestFireInner&&secondInput)
      assert(hitInner&&predecodeAddressInput==cpuRequestInput.address&&cpuRequestInput.address[OFFSET_W-1:2]!=WORD_W'(CACHE_LINE_BYTES/4-1)&&!predecodeOutput.firstControl)
        else $fatal(1,"dual request lacked valid earliest-CFI predecode");
    assert (!fillFireInner || !(readValidInner && refillSlotInner == readIndexInner))
      else $fatal(1, "ICache refill collided with old synchronous read");
  end
`endif
endmodule
