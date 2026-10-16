// Line-memory execution controller matching software DMEM: ONE 16-entry mixed
// FIFO, independent fixed-latency execution, per-kind ordered completion, and
// consumed-prefix reclamation. The persistent byte array belongs to the external
// environment, not the CPU's synthesized SRAM budget. Backing read is sampled
// before the edge; backing write commits at the edge (read-old on collision).
module rv32_dmem #(
  parameter int unsigned DEPTH = 16,
  parameter int unsigned LATENCY = 20
) (
  input logic clkInput, rstNInput,
  input rv32_pkg::dcache_line_request_output_t requestInput,
  output logic readReadyOutput, writeReadyOutput,
  output rv32_pkg::dcache_line_response_input_t responseOutput,
  output rv32_pkg::dcache_write_response_input_t writeResponseOutput,
  input logic responseReadyInput, writeResponseReadyInput,
  output logic backingReadValidOutput,
  output logic [31:0] backingReadAddressOutput,
  input logic [rv32_pkg::DCACHE_LINE_BITS-1:0] backingReadDataInput,
  output logic backingWriteValidOutput,
  output logic [31:0] backingWriteAddressOutput,
  output logic [rv32_pkg::DCACHE_LINE_BITS-1:0] backingWriteDataOutput,
  output logic [$clog2(DEPTH):0] countOutput
);
  import rv32_pkg::*;
  localparam int PTR_W = $clog2(DEPTH);
  localparam int TIMER_W = $clog2(LATENCY+1);
  typedef struct packed {
    logic [DCACHE_LINE_BITS-1:0] payload;
    logic [31:0] address;
    logic [1:0] transaction;
    logic [TIMER_W-1:0] remainCycle;
    logic isWrite, consumed;
  } entry_t;
  entry_t requestsInner [DEPTH];
  logic [PTR_W-1:0] headInner;
  logic [PTR_W:0] countInner;
  integer readSlotInner, writeSlotInner, reclaimedInner;
  logic readPushInner, writePushInner, readPopInner, writePopInner;

  assign countOutput = countInner;
  assign writeReadyOutput = rstNInput && int'(countInner) < DEPTH;
  assign readReadyOutput = rstNInput && int'(countInner) + int'(requestInput.writeValid) < DEPTH;
  assign writePushInner = requestInput.writeValid && writeReadyOutput;
  assign readPushInner = requestInput.readValid && readReadyOutput;
  assign readPopInner = responseOutput.valid && responseReadyInput;
  assign writePopInner = writeResponseOutput.valid && writeResponseReadyInput;

  always_comb begin
    int slot;
    readSlotInner = -1;
    writeSlotInner = -1;
    backingReadValidOutput = 0;
    backingReadAddressOutput = 0;
    backingWriteValidOutput = 0;
    backingWriteAddressOutput = 0;
    backingWriteDataOutput = 0;
    for (int age = 0; age < DEPTH; age++) begin
      slot = (int'(headInner) + age) & (DEPTH-1);
      if (age < int'(countInner)) begin
        if (!requestsInner[slot].consumed) begin
          if (!requestsInner[slot].isWrite && readSlotInner < 0) readSlotInner = slot;
          if (requestsInner[slot].isWrite && writeSlotInner < 0) writeSlotInner = slot;
        end
        if (rstNInput && requestsInner[slot].remainCycle == 1) begin
          if (requestsInner[slot].isWrite) begin
            backingWriteValidOutput = 1;
            backingWriteAddressOutput = requestsInner[slot].address;
            backingWriteDataOutput = requestsInner[slot].payload;
          end else begin
            backingReadValidOutput = 1;
            backingReadAddressOutput = requestsInner[slot].address;
          end
        end
      end
    end
    responseOutput = '0;
    writeResponseOutput = '0;
    if (readSlotInner >= 0) begin
      responseOutput.valid = rstNInput && requestsInner[readSlotInner].remainCycle == 0;
      responseOutput.address = requestsInner[readSlotInner].address;
      responseOutput.transaction = requestsInner[readSlotInner].transaction;
      responseOutput.data = requestsInner[readSlotInner].payload;
    end
    if (writeSlotInner >= 0) begin
      writeResponseOutput.valid = rstNInput && requestsInner[writeSlotInner].remainCycle == 0;
      writeResponseOutput.address = requestsInner[writeSlotInner].address;
      writeResponseOutput.transaction = requestsInner[writeSlotInner].transaction;
    end
  end
  // Consumption cannot affect the current completion or admission outputs.
  // Reclaiming is next-state-only; old-full still rejects both input channels.
  always_comb begin
    int slot;
    logic blocked;
    reclaimedInner = 0;
    blocked = 0;
    for (int age = 0; age < DEPTH; age++) begin
      slot = (int'(headInner) + age) & (DEPTH-1);
      if (age < int'(countInner) && !blocked) begin
        if (requestsInner[slot].consumed || (readPopInner && slot == readSlotInner) ||
            (writePopInner && slot == writeSlotInner)) reclaimedInner++;
        else blocked = 1;
      end
    end
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= 0;
      countInner <= 0;
      for (int i = 0; i < DEPTH; i++) requestsInner[i] <= '0;
    end else begin
      headInner <= headInner + PTR_W'(reclaimedInner);
      countInner <= (PTR_W+1)'(int'(countInner) + int'(readPushInner) + int'(writePushInner) - reclaimedInner);
      for (int age = 0; age < DEPTH; age++) begin
        if (age < int'(countInner)) begin
          if (requestsInner[(int'(headInner)+age)&(DEPTH-1)].remainCycle != 0) begin
            requestsInner[(int'(headInner)+age)&(DEPTH-1)].remainCycle <=
              requestsInner[(int'(headInner)+age)&(DEPTH-1)].remainCycle - 1'b1;
            if (!requestsInner[(int'(headInner)+age)&(DEPTH-1)].isWrite &&
                requestsInner[(int'(headInner)+age)&(DEPTH-1)].remainCycle == 1)
              requestsInner[(int'(headInner)+age)&(DEPTH-1)].payload <= backingReadDataInput;
          end
          if ((readPopInner && ((int'(headInner)+age)&(DEPTH-1)) == readSlotInner) ||
              (writePopInner && ((int'(headInner)+age)&(DEPTH-1)) == writeSlotInner))
            requestsInner[(int'(headInner)+age)&(DEPTH-1)].consumed <= 1;
        end
      end
      if (writePushInner)
        requestsInner[(int'(headInner)+int'(countInner))&(DEPTH-1)] <=
          '{payload:requestInput.writeData, address:requestInput.writeAddress,
            transaction:requestInput.writeTransaction, remainCycle:TIMER_W'(LATENCY), isWrite:1'b1, consumed:1'b0};
      if (readPushInner)
        requestsInner[(int'(headInner)+int'(countInner)+int'(writePushInner))&(DEPTH-1)] <=
          '{payload:'0, address:requestInput.readAddress, transaction:requestInput.readTransaction,
            remainCycle:TIMER_W'(LATENCY), isWrite:1'b0, consumed:1'b0};
    end
  end
`ifndef SYNTHESIS
  initial assert (DEPTH > 1 && (DEPTH & (DEPTH-1)) == 0 && LATENCY > 0);
  always @(posedge clkInput) if (rstNInput) begin
    int reads, writes;
    reads = 0;
    writes = 0;
    assert (int'(countInner) <= DEPTH);
    for (int age = 0; age < DEPTH; age++)
      if (age < int'(countInner) && requestsInner[(int'(headInner)+age)&(DEPTH-1)].remainCycle == 1) begin
        if (requestsInner[(int'(headInner)+age)&(DEPTH-1)].isWrite) writes++;
        else reads++;
      end
    assert (reads <= 1 && writes <= 1);
    if (responseReadyInput) assert (responseOutput.valid);
    if (writeResponseReadyInput) assert (writeResponseOutput.valid);
  end
`endif
endmodule
