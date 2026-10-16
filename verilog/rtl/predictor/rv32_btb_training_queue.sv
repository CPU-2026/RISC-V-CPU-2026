// One accepted producer-cycle batch per entry. Capacity is reserved BEFORE
// predecode/BRU/ALU producers run; this queue never drops a training pulse.
module rv32_btb_training_queue #(
  parameter int unsigned DEPTH = 4
) (
  input logic clkInput, rstNInput,
  input logic trainingValidInput,
  input rv32_pkg::btb_training_input_t trainingInput,
  output logic trainingValidOutput,
  output rv32_pkg::btb_training_input_t trainingOutput,
  input logic trainingReadyInput,
  output logic [$clog2(DEPTH+1)-1:0] freeSlotsOutput
);
  import rv32_pkg::*;
  localparam int unsigned INDEX_W = $clog2(DEPTH);
  localparam int unsigned COUNT_W = $clog2(DEPTH+1);
  btb_training_input_t entriesInner [DEPTH];
  logic [INDEX_W-1:0] headInner, tailInner;
  logic [COUNT_W-1:0] countInner;
  logic popInner;
  assign trainingValidOutput = rstNInput && countInner != 0;
  assign trainingOutput = trainingValidOutput ? entriesInner[headInner] : '0;
  assign popInner = trainingValidOutput && trainingReadyInput;
  assign freeSlotsOutput = COUNT_W'(DEPTH) - countInner;
  always_ff @(posedge clkInput) begin
    if (rstNInput && trainingValidInput) entriesInner[tailInner] <= trainingInput;
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= '0;
      tailInner <= '0;
      countInner <= '0;
    end else begin
      if (trainingValidInput) tailInner <= tailInner + INDEX_W'(1);
      if (popInner) headInner <= headInner + INDEX_W'(1);
      case ({trainingValidInput, popInner})
        2'b10: countInner <= countInner + COUNT_W'(1);
        2'b01: countInner <= countInner - COUNT_W'(1);
        default: begin end
      endcase
    end
  end
`ifndef SYNTHESIS
  initial assert (DEPTH >= 2 && (DEPTH & (DEPTH - 1)) == 0)
    else $fatal(1, "BTB training queue depth must be power-of-two >=2");
  always @(posedge clkInput) if (rstNInput) begin
    assert (countInner <= COUNT_W'(DEPTH));
    assert (!trainingValidInput || countInner < COUNT_W'(DEPTH) || popInner)
      else $fatal(1, "BTB training queue overflow: producer credit was not reserved");
  end
`endif
endmodule
