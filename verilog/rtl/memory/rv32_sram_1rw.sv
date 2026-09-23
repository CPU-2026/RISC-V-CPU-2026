// Single-port synchronous SRAM with one read port and one byte-masked
// write port. Written in plain Verilog-2005 style so Yosys infers a $memInner
// blockIndexInner instead of lowering the array into hundreds of thousands of FFs.
// A full-lineInput write is expressed by tying wrMaskInput to all ones.
//
// Read latency is one cycle: rdDataOutput reflects memInner[rdAddrInput] sampled on
// the rising edge where rdEnInput was high. A simultaneous read and write to
// the same address returns the old contents (read-first); callers must not
// rely on write-through behaviour. Storage is intentionally not reset,
// matching real SRAM macros; only metadata (valid/dirty/replacement) is
// cleared on reset.
module rv32_sram_1rw #(
  parameter int unsigned ADDR_W = 10,
  parameter int unsigned DATA_W = 128,
  parameter int unsigned MASK_W = 16
) (
  input  logic                   clkInput,
  input  logic                   rdEnInput,
  input  logic [ADDR_W-1:0]      rdAddrInput,
  output logic [DATA_W-1:0]      rdDataOutput,
  input  logic                   wrEnInput,
  input  logic [ADDR_W-1:0]      wrAddrInput,
  input  logic [DATA_W-1:0]      wrDataInput,
  input  logic [MASK_W-1:0]      wrMaskInput
);
  localparam int unsigned DEPTH = 1 << ADDR_W;
  localparam int unsigned BYTE_W = DATA_W / MASK_W;

  logic [DATA_W-1:0] memInner [DEPTH];

  genvar byteLaneInner;
  generate
    for (byteLaneInner = 0; byteLaneInner < MASK_W; byteLaneInner = byteLaneInner + 1) begin : g_byte
      always @(posedge clkInput) begin
        if (wrEnInput && wrMaskInput[byteLaneInner])
          memInner[wrAddrInput][(byteLaneInner * BYTE_W) +: BYTE_W] <=
            wrDataInput[(byteLaneInner * BYTE_W) +: BYTE_W];
      end
    end
  endgenerate

  always @(posedge clkInput) begin
    if (rdEnInput)
      rdDataOutput <= memInner[rdAddrInput];
  end
endmodule
