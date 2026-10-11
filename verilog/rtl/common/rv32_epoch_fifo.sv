// Full capacity, no empty bypass; a real dequeue permits same-cycle replacement.
module rv32_epoch_fifo #(
  parameter int unsigned DEPTH = 4,
  parameter int unsigned WIDTH = 32,
  localparam int unsigned SLOT_W = $clog2(DEPTH),
  localparam int unsigned SEQ_W = SLOT_W + 1
) (
  input logic clkInput, rstNInput, flushInput,
  input logic inValidInput,
  output logic inReadyOutput,
  input logic [WIDTH-1:0] inDataInput,
  output logic outValidOutput,
  input logic outReadyInput,
  output logic [WIDTH-1:0] outDataOutput,
  output logic [SEQ_W-1:0] countOutput
);
  logic [SEQ_W-1:0] headInner, tailInner;
  logic [WIDTH-1:0] entriesInner [DEPTH];
  logic emptyInner, fullInner;
  assign emptyInner = headInner == tailInner;
  assign fullInner = tailInner == (headInner ^ SEQ_W'(DEPTH));
  assign countOutput = tailInner - headInner;
  assign inReadyOutput = (!fullInner || (outValidOutput && outReadyInput)) && !flushInput;
  assign outValidOutput = !emptyInner && !flushInput;
  assign outDataOutput = emptyInner ? '0 : entriesInner[headInner[SLOT_W-1:0]];
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      tailInner <= '0;
    end else if (flushInput) begin
      headInner <= '0;
      tailInner <= '0;
    end else begin
      if (inValidInput && inReadyOutput) begin
        entriesInner[tailInner[SLOT_W-1:0]] <= inDataInput;
        tailInner <= tailInner + SEQ_W'(1);
      end
      if (outValidOutput && outReadyInput)
        headInner <= headInner + SEQ_W'(1);
    end
  end
`ifndef SYNTHESIS
  initial begin
    if (DEPTH < 2 || (DEPTH & (DEPTH-1)) != 0)
      $fatal(1, "epoch FIFO DEPTH must be a power of two >= 2");
  end
  always @(posedge clkInput)
    if (rstNInput) assert (countOutput <= SEQ_W'(DEPTH))
      else $fatal(1, "epoch FIFO occupancy outside capacity");
`endif
endmodule
