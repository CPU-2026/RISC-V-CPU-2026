// The start edge reads the architectural SRAMs. Their synchronous outputs
// feed the first replay beat; the following four edges process the ROB window.
module rv32_recovery_cursor (
  input logic clkInput, rstNInput,
  input logic freezeInput,
  input logic startInput,
  input rv32_pkg::rob_tag_t headTagInput,
  input rv32_pkg::rob_tag_t squashTagInput,
  input logic [$clog2(rv32_pkg::ROB_ENTRIES+1)-1:0] countInput,
  output rv32_pkg::recovery_step_t stepOutput
);
  import rv32_pkg::*;
  logic activeInner;
  logic [1:0] beatInner;
  rob_tag_t offsetInner, nextTagInner, squashTagInner, countInner;

  assign stepOutput = '{active: activeInner, first: beatInner == 0,
    last: beatInner == 2'd3, offset: offsetInner, nextTag: nextTagInner,
    squashTag: squashTagInner, liveCount: countInner};

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      activeInner <= 1'b0;
      beatInner <= '0;
      offsetInner <= '0;
      nextTagInner <= '0;
      squashTagInner <= '0;
      countInner <= '0;
    end else if (!freezeInput) begin
      if (startInput && !activeInner) begin
        activeInner <= 1'b1;
        beatInner <= '0;
        offsetInner <= '0;
        nextTagInner <= headTagInput;
        squashTagInner <= squashTagInput;
        countInner <= rob_tag_t'(countInput);
      end else if (activeInner) begin
        nextTagInner <= nextTagInner + rob_tag_t'(RECOVERY_WIDTH);
        offsetInner <= offsetInner + rob_tag_t'(RECOVERY_WIDTH);
        if (beatInner == 2'd3)
          activeInner <= 1'b0;
        else
          beatInner <= beatInner + 2'd1;
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !freezeInput) begin
    assert (!(startInput && activeInner)) else $fatal(1, "nested recovery start");
    if (startInput) begin
      assert (countInput != 0 &&
              (squashTagInput - headTagInput) < rob_tag_t'(countInput))
        else $fatal(1, "recovery boundary outside live ROB window");
    end
  end
`endif
endmodule
