// Instruction-counted packet ingress, independent decode and ordered allocation.
module rv32_decode_issue_queue #(
  parameter int unsigned DECODE_WIDTH = 4,
  parameter int unsigned ISSUE_WIDTH = 4,
  parameter int unsigned FQ_DEPTH = 8,
  parameter int unsigned IQ_DEPTH = 8,
  parameter bit LEGACY_HALT = 1'b0,
  parameter int unsigned FETCH_WIDTH = 2
) (
  input logic clkInput, rstNInput, freezeInput, flushInput,
  input logic inValidInput,
  input logic [$clog2(FETCH_WIDTH+1)-1:0] inCountInput,
  input rv32_pkg::decode_context_t [FETCH_WIDTH-1:0] inDataInput,
  output logic inReadyOutput,
  output rv32_pkg::decoded_uop_t [ISSUE_WIDTH-1:0] decodedOutput,
  output logic [ISSUE_WIDTH-1:0] validOutput,
  input logic [$clog2(ISSUE_WIDTH+1)-1:0] readyCountInput,
  output logic [$clog2(ISSUE_WIDTH+1)-1:0] availableCountOutput,
  output logic [$clog2(DECODE_WIDTH+1)-1:0] decodeFireCountOutput,
  output logic [$clog2(FQ_DEPTH+1)-1:0] fqCountOutput,
  output logic [$clog2(IQ_DEPTH+1)-1:0] iqCountOutput
);
  import rv32_pkg::*;
  localparam int DCW=$clog2(DECODE_WIDTH+1);
  localparam int ICW=$clog2(ISSUE_WIDTH+1);
  decode_context_t [DECODE_WIDTH-1:0] fqWords;
  decoded_uop_t [DECODE_WIDTH-1:0] decodedWords;
  logic [ISSUE_WIDTH-1:0][$bits(decoded_uop_t)-1:0] iqWords;
  logic [DCW-1:0] availableDecode, decodeCount;
  logic [$clog2(FQ_DEPTH):0] fqCapacity, fqOccupancy;
  logic [$clog2(IQ_DEPTH):0] iqCapacity, iqOccupancy;
  logic fqReady, iqReady;

  if ((DECODE_WIDTH!=1 && DECODE_WIDTH!=2 && DECODE_WIDTH!=4) ||
      (ISSUE_WIDTH!=1 && ISSUE_WIDTH!=2 && ISSUE_WIDTH!=4)) begin : g_invalid_width
    initial $fatal(1,"decode/issue queue widths must be 1, 2 or 4");
  end
  always_comb begin
    decodeCount=availableDecode;
    if (int'(decodeCount)>int'(iqCapacity)) decodeCount=DCW'(iqCapacity);
  end
  rv32_prefix_fifo #(.DEPTH(FQ_DEPTH), .WIDTH($bits(decode_context_t)),
      .PUSH_WIDTH(FETCH_WIDTH), .POP_WIDTH(DECODE_WIDTH)) u_fq (
    .clkInput, .rstNInput, .freezeInput, .flushInput,
    .inValidInput(inValidInput), .inCountInput, .inDataInput,
    .inReadyOutput(fqReady), .inCapacityOutput(fqCapacity),
    .outCountOutput(availableDecode), .outDataOutput(fqWords),
    .outReadyCountInput(decodeCount), .countOutput(fqOccupancy)
  );
  for (genvar lane=0; lane<DECODE_WIDTH; lane++) begin : g_decoder
    rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder (
      .decodeContextInput(fqWords[lane]), .uopOutput(decodedWords[lane])
    );
  end
  rv32_prefix_fifo #(.DEPTH(IQ_DEPTH), .WIDTH($bits(decoded_uop_t)),
      .PUSH_WIDTH(DECODE_WIDTH), .POP_WIDTH(ISSUE_WIDTH)) u_iq (
    .clkInput, .rstNInput, .freezeInput, .flushInput,
    .inValidInput(decodeCount!=0), .inCountInput(decodeCount), .inDataInput(decodedWords),
    .inReadyOutput(iqReady), .inCapacityOutput(iqCapacity),
    .outCountOutput(availableCountOutput), .outDataOutput(iqWords),
    .outReadyCountInput(readyCountInput), .countOutput(iqOccupancy)
  );
  for (genvar lane=0; lane<ISSUE_WIDTH; lane++) begin : g_output
    assign validOutput[lane]=int'(availableCountOutput)>lane;
    assign decodedOutput[lane]=validOutput[lane] ? decoded_uop_t'(iqWords[lane]) : decoded_uop_t'('0);
  end
  assign inReadyOutput=fqReady && !freezeInput && !flushInput;
  assign decodeFireCountOutput=(!freezeInput && !flushInput) ? decodeCount : '0;
  assign fqCountOutput=$bits(fqCountOutput)'(fqOccupancy);
  assign iqCountOutput=$bits(iqCountOutput)'(iqOccupancy);
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !freezeInput && !flushInput) begin
    assert (decodeCount==0 || iqReady) else $fatal(1,"wide decode prefix not accepted atomically");
    assert (readyCountInput<=availableCountOutput) else $fatal(1,"wide IQ consumption exceeds available prefix");
    assert (int'(availableCountOutput)<=ISSUE_WIDTH && int'(decodeCount)<=DECODE_WIDTH)
      else $fatal(1,"wide decode/issue lane count truncated");
  end
`endif
endmodule
