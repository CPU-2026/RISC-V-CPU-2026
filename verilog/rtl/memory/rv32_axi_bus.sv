// Shared AR channel, held grant under backpressure, ordered response owners.
// AW/W/B belong exclusively to AXIData. There are no AXI transaction IDs.
module rv32_axi_bus (
  input logic clkInput, rstNInput,
  input rv32_pkg::axi_master_t fetchInput, dataInput,
  input rv32_pkg::axi_slave_t slaveInput,
  output rv32_pkg::axi_master_t masterOutput,
  output rv32_pkg::axi_slave_t fetchOutput, dataOutput
);
  import rv32_pkg::*;
  logic ownerInner [64];
  logic [5:0] headInner;
  logic [6:0] countInner;
  logic preferDataInner, grantHeldInner, heldDataInner;
  logic creditInner, dataInner, pushInner, popInner;
  assign creditInner = countInner < 64;
  assign dataInner = grantHeldInner ? heldDataInner :
    dataInput.arValid && (!fetchInput.arValid || preferDataInner);
  always_comb begin
    masterOutput = dataInput;
    masterOutput.arValid = rstNInput && creditInner && (fetchInput.arValid || dataInput.arValid);
    masterOutput.arAddr = dataInner ? dataInput.arAddr : fetchInput.arAddr;
    masterOutput.rReady = rstNInput && countInner != 0 &&
      (ownerInner[headInner] ? dataInput.rReady : fetchInput.rReady);
    fetchOutput = slaveInput;
    dataOutput = slaveInput;
    fetchOutput.arReady = rstNInput && creditInner && !dataInner && slaveInput.arReady;
    dataOutput.arReady = rstNInput && creditInner && dataInner && slaveInput.arReady;
    fetchOutput.rValid = slaveInput.rValid && countInner != 0 && !ownerInner[headInner];
    dataOutput.rValid = slaveInput.rValid && countInner != 0 && ownerInner[headInner];
  end
  assign pushInner = masterOutput.arValid && slaveInput.arReady;
  assign popInner = masterOutput.rReady && slaveInput.rValid;
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      headInner <= 0;
      countInner <= 0;
      preferDataInner <= 0;
      grantHeldInner <= 0;
      heldDataInner <= 0;
      for (int i = 0; i < 64; i++) ownerInner[i] <= 0;
    end else begin
      if (masterOutput.arValid && !slaveInput.arReady && !grantHeldInner) begin
        grantHeldInner <= 1;
        heldDataInner <= dataInner;
      end else if (pushInner) grantHeldInner <= 0;
      if (pushInner) ownerInner[6'(headInner + 6'(countInner))] <= dataInner;
      if (popInner) headInner <= headInner + 1'b1;
      countInner <= countInner + 7'(pushInner) - 7'(popInner);
      if (pushInner && fetchInput.arValid && dataInput.arValid) preferDataInner <= !preferDataInner;
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    assert (countInner <= 64);
    if (slaveInput.rValid) assert (countInner != 0);
  end
`endif
endmodule
