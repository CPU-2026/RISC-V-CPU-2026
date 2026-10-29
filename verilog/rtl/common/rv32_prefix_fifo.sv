// Equivalent prefix FIFO; adjacent two-lane writes share one data mux per parity bank.
module rv32_prefix_fifo #(
  parameter int unsigned DEPTH = 4,
  parameter int unsigned WIDTH = 32,
  parameter int unsigned PUSH_WIDTH = 2,
  parameter int unsigned POP_WIDTH = 2,
  localparam int unsigned SLOT_W = $clog2(DEPTH),
  localparam int unsigned SEQ_W = SLOT_W + 1,
  localparam int unsigned PUSH_W = $clog2(PUSH_WIDTH + 1),
  localparam int unsigned POP_W = $clog2(POP_WIDTH + 1)
) (
  input logic clkInput, rstNInput, freezeInput, flushInput,
  input logic inValidInput,
  input logic [PUSH_W-1:0] inCountInput,
  input logic [PUSH_WIDTH-1:0][WIDTH-1:0] inDataInput,
  output logic inReadyOutput,
  output logic [SEQ_W-1:0] inCapacityOutput,
  output logic [POP_W-1:0] outCountOutput,
  output logic [POP_WIDTH-1:0][WIDTH-1:0] outDataOutput,
  input logic [POP_W-1:0] outReadyCountInput,
  output logic [SEQ_W-1:0] countOutput
);
  logic [SEQ_W-1:0] headInner, tailInner;
  logic [WIDTH-1:0] entriesInner [DEPTH];
  logic [POP_W-1:0] popInner;
  logic [PUSH_W-1:0] pushInner;

  assign countOutput = tailInner - headInner;
  assign outCountOutput = flushInput ? '0 :
    (countOutput < SEQ_W'(POP_WIDTH) ? POP_W'(countOutput) : POP_W'(POP_WIDTH));
  assign popInner = outReadyCountInput < outCountOutput ? outReadyCountInput : outCountOutput;
  assign inCapacityOutput = SEQ_W'(DEPTH) - countOutput + SEQ_W'(popInner);
  generate if (PUSH_WIDTH == 2) begin : g_prefix_credit
    logic oneSpaceInner, twoSpaceInner, popOneInner, popTwoInner;
    // Occupancy thresholds are OLD-state work. A late consumer acceptance
    // only funds one/two additional credits, not an adder then a comparator.
    assign oneSpaceInner = countOutput < SEQ_W'(DEPTH);
    assign twoSpaceInner = countOutput <= SEQ_W'(DEPTH-2);
    assign popOneInner = |popInner;
    assign popTwoInner = popInner > POP_W'(1);
    always_comb begin
      case (inCountInput)
        PUSH_W'(0): inReadyOutput = !flushInput;
        PUSH_W'(1): inReadyOutput = !flushInput && (oneSpaceInner || popOneInner);
        PUSH_W'(2): inReadyOutput = !flushInput &&
          (twoSpaceInner || (oneSpaceInner && popOneInner) || popTwoInner);
        default: inReadyOutput = 1'b0;
      endcase
    end
  end else begin : g_generic_credit
    assign inReadyOutput = !flushInput && inCountInput <= PUSH_W'(PUSH_WIDTH) &&
      SEQ_W'(inCountInput) <= inCapacityOutput;
  end endgenerate
  assign pushInner = inValidInput && inReadyOutput ? inCountInput : '0;
  for (genvar lane = 0; lane < POP_WIDTH; lane++) begin : g_read
    assign outDataOutput[lane] = lane < int'(outCountOutput) ?
      entriesInner[SLOT_W'(headInner + SEQ_W'(lane))] : '0;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      tailInner <= '0;
    end else if (!freezeInput && flushInput) begin
      headInner <= '0;
      tailInner <= '0;
    end else if (!freezeInput) begin
      headInner <= headInner + SEQ_W'(popInner);
      tailInner <= tailInner + SEQ_W'(pushInner);
    end
  end

  generate if (PUSH_WIDTH == 2) begin : g_banked_write
    logic [1:0][WIDTH-1:0] bankDataInner;
    logic [SLOT_W-1:0] nextSlotInner;
    assign nextSlotInner = SLOT_W'(tailInner + SEQ_W'(1));
    assign bankDataInner[0] = tailInner[0] ? inDataInput[1] : inDataInput[0];
    assign bankDataInner[1] = tailInner[0] ? inDataInput[0] : inDataInput[1];
    for (genvar row = 0; row < DEPTH; row++) begin : g_row
      logic writeInner;
      assign writeInner = (pushInner != 0 && SLOT_W'(tailInner) == SLOT_W'(row)) ||
        (pushInner == PUSH_W'(2) && nextSlotInner == SLOT_W'(row));
      always_ff @(posedge clkInput)
        if (rstNInput && !freezeInput && !flushInput && writeInner)
          entriesInner[row] <= bankDataInner[row & 1];
    end
  end else begin : g_generic_write
    always_ff @(posedge clkInput)
      if (rstNInput && !freezeInput && !flushInput)
        for (int lane = 0; lane < PUSH_WIDTH; lane++)
          if (lane < int'(pushInner))
            entriesInner[SLOT_W'(tailInner + SEQ_W'(lane))] <= inDataInput[lane];
  end endgenerate
`ifndef SYNTHESIS
  initial begin
    assert (DEPTH >= 2 && (DEPTH & (DEPTH-1)) == 0)
      else $fatal(1, "prefix FIFO DEPTH must be a power of two >= 2");
    assert (PUSH_WIDTH >= 1 && PUSH_WIDTH <= DEPTH && POP_WIDTH >= 1 && POP_WIDTH <= DEPTH)
      else $fatal(1, "prefix FIFO lane count exceeds capacity");
  end
  always @(posedge clkInput) if (rstNInput) begin
    assert (countOutput <= SEQ_W'(DEPTH)) else $fatal(1, "prefix FIFO overflow");
    if (inValidInput && !flushInput && !freezeInput)
      assert (inCountInput != 0 && inCountInput <= PUSH_W'(PUSH_WIDTH))
        else $fatal(1, "invalid prefix FIFO input length");
  end
`endif
endmodule
