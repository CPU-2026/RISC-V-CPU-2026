// Software ICache contract: four ordered placeholders, synchronous SRAM hits,
// an old-head read bypass, and one old miss completed by each accepted refill.
module rv32_icache #(
  parameter int unsigned SETS = rv32_pkg::ICACHE_SETS,
  parameter int unsigned REQUEST_DEPTH = rv32_pkg::FETCH_REQUEST_ENTRIES
) (
  input logic clkInput, rstNInput,
  input logic flushInput,
  input rv32_pkg::icache_cpu_request_input_t cpuRequestInput,
  output logic cpuReqReadyOutput,
  output rv32_pkg::icache_cpu_response_output_t cpuResponseOutput,
  input logic cpuRspReadyInput,
  output rv32_pkg::cache_line_request_output_t memRequestOutput,
  input logic memReqReadyInput,
  input rv32_pkg::icache_line_response_input_t memResponseInput,
  output logic memRspReadyOutput,
  output logic memFlushOutput
);
  import rv32_pkg::*;
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
  logic [31:0] requestInstructionInner [REQUEST_DEPTH];
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
  logic [31:0] readWordInner, fillWordInner, forwardWordInner;

  assign tailSlotInner = headInner + SLOT_W'(countInner);
  assign hitInner = validInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] &&
    tagInner[cpuRequestInput.address[INDEX_W+OFFSET_W-1:OFFSET_W]] == cpuRequestInput.address[31:INDEX_W+OFFSET_W];
  assign headReadReadyInner = countInner != 0 && !requestReadyInner[headInner] &&
    readValidInner && readIndexInner == headInner;
  assign readWordInner = 32'(sramRdataInner >> (32'(readLaneInner) << 5));
  assign cpuResponseOutput.valid = countInner != 0 &&
    (requestReadyInner[headInner] || headReadReadyInner);
  assign cpuResponseOutput.instruction = headReadReadyInner ? readWordInner : requestInstructionInner[headInner];
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
  assign memRspReadyOutput = !flushInput && refillFoundInner;
  assign fillFireInner = memResponseInput.valid && memRspReadyOutput;
  assign refillHitInner = fillFireInner &&
    cpuRequestInput.address[31:OFFSET_W] == memResponseInput.address[31:OFFSET_W];
  assign readBlockedInner = fillFireInner && hitInner && !refillHitInner;
  // Matches CPU::comb(): even a hit observes old IMEM fullness. Only accepted
  // same-line refill forwarding bypasses that gate; no full IMEM pop bypass.
  assign cpuReqReadyOutput = !flushInput &&
    (countInner < COUNT_W'(REQUEST_DEPTH) || responseFireInner) &&
    (memReqReadyInput || refillHitInner) && !readBlockedInner;
  assign requestFireInner = cpuRequestInput.valid && cpuReqReadyOutput;
  always_comb begin
    memRequestOutput = '0;
    memRequestOutput.valid = requestFireInner && !hitInner && !refillHitInner;
    memRequestOutput.address = {cpuRequestInput.address[31:OFFSET_W], {OFFSET_W{1'b0}}};
  end
  assign memFlushOutput = flushInput;
  assign fillWordInner = 32'(memResponseInput.data >>
    (32'(requestAddressInner[refillSlotInner][OFFSET_W-1:2]) << 5));
  assign forwardWordInner = 32'(memResponseInput.data >>
    (32'(cpuRequestInput.address[OFFSET_W-1:2]) << 5));

  // Actual framework macro interface from common/rv32_sram.sv, one 1RW port.
  // Refill owns the port; a new same-line request uses the accepted fill bus.
  assign sramEnableInner = !flushInput && (fillFireInner || requestFireInner);
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
      end
    end else if (flushInput) begin
      // Logical requests and read identities die; non-speculative cache stays.
      headInner <= '0;
      countInner <= '0;
      readValidInner <= 1'b0;
      readIndexInner <= '0;
      readLaneInner <= '0;
      for (int q = 0; q < REQUEST_DEPTH; q = q + 1)
        requestReadyInner[q] <= 1'b0;
    end else begin
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
          requestReadyInner[q] <= refillHitInner;
          requestInstructionInner[q] <= refillHitInner ? forwardWordInner : 32'b0;
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
    assert (!fillFireInner || !(readValidInner && refillSlotInner == readIndexInner))
      else $fatal(1, "ICache refill collided with old synchronous read");
  end
`endif
endmodule
