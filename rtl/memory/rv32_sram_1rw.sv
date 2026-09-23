// Single-port synchronous SRAM with one read port and one byte-masked
// write port. Written in plain Verilog-2005 style so Yosys infers a $mem
// block instead of lowering the array into hundreds of thousands of FFs.
// A full-line write is expressed by tying wr_mask_i to all ones.
//
// Read latency is one cycle: rd_data_o reflects mem[rd_addr_i] sampled on
// the rising edge where rd_en_i was high. A simultaneous read and write to
// the same address returns the old contents (read-first); callers must not
// rely on write-through behaviour. Storage is intentionally not reset,
// matching real SRAM macros; only metadata (valid/dirty/replacement) is
// cleared on reset.
module rv32_sram_1rw #(
  parameter int unsigned ADDR_W = 10,
  parameter int unsigned DATA_W = 128,
  parameter int unsigned MASK_W = 16
) (
  input  logic                   clk_i,
  input  logic                   rd_en_i,
  input  logic [ADDR_W-1:0]      rd_addr_i,
  output logic [DATA_W-1:0]      rd_data_o,
  input  logic                   wr_en_i,
  input  logic [ADDR_W-1:0]      wr_addr_i,
  input  logic [DATA_W-1:0]      wr_data_i,
  input  logic [MASK_W-1:0]      wr_mask_i
);
  localparam int unsigned DEPTH = 1 << ADDR_W;
  localparam int unsigned BYTE_W = DATA_W / MASK_W;

  logic [DATA_W-1:0] mem [0:DEPTH-1];

  genvar b;
  generate
    for (b = 0; b < MASK_W; b = b + 1) begin : g_byte
      always @(posedge clk_i) begin
        if (wr_en_i && wr_mask_i[b])
          mem[wr_addr_i][(b * BYTE_W) +: BYTE_W] <=
            wr_data_i[(b * BYTE_W) +: BYTE_W];
      end
    end
  endgenerate

  always @(posedge clk_i) begin
    if (rd_en_i)
      rd_data_o <= mem[rd_addr_i];
  end
endmodule
