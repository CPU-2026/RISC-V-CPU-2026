// Width-selected ordered requests, synchronous SRAM hits, an old-head read
// bypass, and one old miss completed by each accepted refill.
module rv32_icache #(
  parameter int unsigned SETS = rv32_pkg::ICACHE_SETS,
  parameter int unsigned FETCH_WIDTH = 1,
  parameter int unsigned REQUEST_DEPTH = (rv32_pkg::FETCH_REQUEST_ENTRIES/FETCH_WIDTH > 1) ? rv32_pkg::FETCH_REQUEST_ENTRIES/FETCH_WIDTH : 2
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
  localparam int unsigned FETCH_DATA_BITS = 32 * FETCH_WIDTH;
  localparam int unsigned OFFSET_W = $clog2(CACHE_LINE_BYTES);
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned TAG_W = 32 - INDEX_W - OFFSET_W;
  localparam int unsigned SLOT_W = $clog2(REQUEST_DEPTH);
  localparam int unsigned COUNT_W = $clog2(REQUEST_DEPTH + 1);
  localparam int unsigned WORD_W = OFFSET_W - 2;

  // Tags/valid bits are registers; instruction DATA exists only in u_data SRAM.
  logic validInner [SETS];
  logic [TAG_W-1:0] tagInner [SETS];
  logic [31:0] requestAddressInner [REQUEST_DEPTH];
  logic [31:0] requestPredictedPcInner [REQUEST_DEPTH];
  bpu_ckpt_id_t requestCheckpointInner [REQUEST_DEPTH];
  logic requestReadyInner [REQUEST_DEPTH];
  logic [FETCH_DATA_BITS-1:0] requestInstructionInner [REQUEST_DEPTH];
  logic requestSecondInner [REQUEST_DEPTH];
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
  logic [FETCH_DATA_BITS-1:0] readWordInner, fillWordInner, forwardWordInner;

  function automatic logic is_control(input logic [31:0] instruction);
    return instruction[6:0]==OPCODE_BRANCH || instruction[6:0]==OPCODE_JAL ||
      (instruction[6:0]==OPCODE_JALR && instruction[14:12]==3'b000);
  endfunction
  function automatic logic [63:0] packet_words(input logic [CACHE_LINE_BITS-1:0] lineData,
                                               input logic [31:0] address);
    logic [63:0] blockData;
    blockData=64'(lineData>>(32'(address[OFFSET_W-1:3])<<6));
    return address[2]?{32'b0,blockData[63:32]}:blockData;
  endfunction
  generate if(FETCH_WIDTH>=2)begin : g_predecode
    // Metadata only: instruction DATA still lives exclusively in real SRAM.
    // The mask is published by the same fill that publishes its tag/valid.
    logic [CACHE_LINE_BYTES/4-1:0] controlMaskInner [SETS];
    logic [CACHE_LINE_BYTES/4-1:0] fillMaskInner;
    logic predecodeHitInner;
    always_comb begin
      for(int wordIndex=0;wordIndex<CACHE_LINE_BYTES/4;wordIndex++)
        fillMaskInner[wordIndex]=is_control(memResponseInput.data[wordIndex*32+:32]);
    end
    always_ff @(posedge clkInput)
      if(fillFireInner)controlMaskInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]]<=fillMaskInner;
    // The predecode PC comes straight from the old frontend PC register, not
    // the packed request which also carries this prediction's NEXT PC.
    assign predecodeHitInner=validInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]]&&
      tagInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]]==predecodeAddressInput[31:INDEX_W+OFFSET_W];
    assign predecodeOutput.hit=predecodeHitInner;
    assign predecodeOutput.firstControl=predecodeHitInner&&
      controlMaskInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][predecodeAddressInput[OFFSET_W-1:2]];
    if (FETCH_WIDTH==4) begin : g_four_hints
      // Relative lanes, clipped at the aligned 16-byte packet boundary.
      logic [3:0] controls;
      always_comb begin
        controls='0;
        for (int lane=0;lane<4;lane++)
          if (predecodeHitInner && lane < 4-int'(predecodeAddressInput[3:2]))
            controls[lane]=controlMaskInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]]
              [int'(predecodeAddressInput[OFFSET_W-1:2])+lane];
      end
      assign predecodeOutput.secondControl=controls[1];
      assign predecodeOutput.thirdControl=controls[2];
      assign predecodeOutput.fourthControl=controls[3];
    end else begin
      assign predecodeOutput.secondControl=predecodeHitInner&&!predecodeAddressInput[2]&&
        controlMaskInner[predecodeAddressInput[INDEX_W+OFFSET_W-1:OFFSET_W]][{predecodeAddressInput[OFFSET_W-1:3],1'b1}];
      assign predecodeOutput.thirdControl=1'b0;
      assign predecodeOutput.fourthControl=1'b0;
    end
  end else begin : g_no_predecode
    assign predecodeOutput='0;
  end endgenerate

  assign tailSlotInner = headInner + SLOT_W'(countInner);
  assign hitInner = validInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] &&
    tagInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] == cpuRequestInput.address[31:INDEX_W+OFFSET_W];
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
  assign sramEnableInner = rstNInput && !freezeInput && !flushInput;
  assign sramAddressInner = fillFireInner ? memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W] :
    cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W];
  sram_fakeram #(.DEPTH(SETS), .WIDTH(CACHE_LINE_BITS), .WRITE_GRANULARITY(32)) u_data (
    .clk(clkInput), .en(sramEnableInner), .we(fillFireInner),
    .addr(sramAddressInner), .wdata(memResponseInput.data),
    .wmask({(CACHE_LINE_BYTES >> 2){1'b1}}), .rdata(sramRdataInner)
  );

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      countInner <= '0;
      readValidInner <= 1'b0;
      readIndexInner <= '0;
      readLaneInner <= '0;
      for (int s = 0; s < SETS; s = s + 1) begin
        validInner[s] <= 1'b0;
        tagInner[s] <= '0;
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
      end
      if (fillFireInner) begin
        validInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] <= 1'b1;
        tagInner[memResponseInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] <= memResponseInput.address[31:INDEX_W+OFFSET_W];
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
      assert(hitInner&&predecodeAddressInput==cpuRequestInput.address&&!cpuRequestInput.address[2]&&!predecodeOutput.firstControl)
        else $fatal(1,"dual request lacked valid earliest-CFI predecode");
    assert (!fillFireInner || !(readValidInner && refillSlotInner == readIndexInner))
      else $fatal(1, "ICache refill collided with old synchronous read");
  end
`endif
endmodule
