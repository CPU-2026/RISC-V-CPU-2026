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
  output logic wholeGroupOutput,
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
  logic [ICW-1:0] iqAvailableInner;
  logic wholeGroupFireInner;
  // Proposal is based solely on OLD queue state, never on backend ready.
  // The backend must either accept every proposed valid lane or none.
  assign wholeGroupOutput = rstNInput && !freezeInput && !flushInput &&
    DECODE_WIDTH==4 && ISSUE_WIDTH==4 && iqOccupancy==0 && availableDecode!=0;
  assign wholeGroupFireInner = wholeGroupOutput &&
    readyCountInput==ICW'(availableDecode);
  assign availableCountOutput = wholeGroupOutput ? ICW'(availableDecode) : iqAvailableInner;

  if ((DECODE_WIDTH!=1 && DECODE_WIDTH!=2 && DECODE_WIDTH!=4) ||
      (ISSUE_WIDTH!=1 && ISSUE_WIDTH!=2 && ISSUE_WIDTH!=4)) begin : g_invalid_width
    initial $fatal(1,"decode/issue queue widths must be 1, 2 or 4");
  end
  always_comb begin
    decodeCount=availableDecode;
    if (iqOccupancy!=0 && int'(decodeCount)>int'(iqCapacity)) decodeCount=DCW'(iqCapacity);
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
    .inValidInput(decodeCount!=0 && !wholeGroupFireInner), .inCountInput(decodeCount), .inDataInput(decodedWords),
    .inReadyOutput(iqReady), .inCapacityOutput(iqCapacity),
    .outCountOutput(iqAvailableInner), .outDataOutput(iqWords),
    .outReadyCountInput(wholeGroupOutput ? ICW'(0) : readyCountInput), .countOutput(iqOccupancy)
  );
  for (genvar lane=0; lane<ISSUE_WIDTH; lane++) begin : g_output
    assign validOutput[lane]=int'(availableCountOutput)>lane;
    if (lane<DECODE_WIDTH) begin : g_decode_bypass
      assign decodedOutput[lane]=validOutput[lane] ?
        (wholeGroupOutput ? decodedWords[lane] : decoded_uop_t'(iqWords[lane])) : decoded_uop_t'('0);
    end else begin : g_iq_only
      assign decodedOutput[lane]=validOutput[lane] ? decoded_uop_t'(iqWords[lane]) : decoded_uop_t'('0);
    end
  end
  assign inReadyOutput=fqReady && !freezeInput && !flushInput;
  assign decodeFireCountOutput=(!freezeInput && !flushInput) ? decodeCount : '0;
  assign fqCountOutput=$bits(fqCountOutput)'(fqOccupancy);
  assign iqCountOutput=$bits(iqCountOutput)'(iqOccupancy);
`ifndef SYNTHESIS
  initial assert(IQ_DEPTH>=DECODE_WIDTH) else $fatal(1,"decode group exceeds IQ capacity");
  always @(posedge clkInput) if (rstNInput && !freezeInput && !flushInput) begin
    assert (decodeCount==0 || iqReady) else $fatal(1,"wide decode prefix not accepted atomically");
    if (wholeGroupOutput)
      assert (readyCountInput==0 || readyCountInput==ICW'(availableDecode))
        else $fatal(1,"whole-group bypass partially accepted");
    assert (readyCountInput<=availableCountOutput) else $fatal(1,"wide IQ consumption exceeds available prefix");
    assert (int'(availableCountOutput)<=ISSUE_WIDTH && int'(decodeCount)<=DECODE_WIDTH)
      else $fatal(1,"wide decode/issue lane count truncated");
  end
`endif
endmodule
