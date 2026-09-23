module rv32_icache #(
  parameter int unsigned SETS = 512
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  input  logic             cpu_req_valid_i,
  output logic             cpu_req_ready_o,
  input  logic [31:0]      cpu_req_addr_i,
  output logic             cpu_rsp_valid_o,
  output logic [31:0]      cpu_rsp_data_o,

  output logic             mem_req_valid_o,
  input  logic             mem_req_ready_i,
  output logic [31:0]      mem_req_addr_o,
  input  logic             mem_rsp_valid_i,
  input  logic [127:0]     mem_rsp_data_i
);
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned TAG_W = 32 - INDEX_W - 4;

  typedef enum logic [1:0] {IDLE, TAG_READ, MISS_REQUEST, MISS_WAIT} state_e;
  state_e state_q;
  logic valid_q [0:SETS-1];
  logic [TAG_W-1:0] tag_q [0:SETS-1];
  logic [31:0] miss_addr_q;
  logic [INDEX_W-1:0] miss_index_q;
  logic [TAG_W-1:0] miss_tag_q;
  logic [1:0] miss_word_q;
  logic rsp_valid_q;
  logic [31:0] rsp_data_q;
  logic [INDEX_W-1:0] request_index;
  logic [TAG_W-1:0] request_tag;
  logic [1:0] request_word;
  logic [127:0] sram_rdata;
  logic [31:0] hit_word, refill_word;
  integer i;

  rv32_sram_1rw #(
    .ADDR_W(INDEX_W),
    .DATA_W(128),
    .MASK_W(16)
  ) u_data (
    .clk_i(clk_i),
    .rd_en_i(state_q == IDLE && cpu_req_valid_i),
    .rd_addr_i(request_index),
    .rd_data_o(sram_rdata),
    .wr_en_i(state_q == MISS_WAIT && mem_rsp_valid_i),
    .wr_addr_i(miss_index_q),
    .wr_data_i(mem_rsp_data_i),
    .wr_mask_i(16'hffff)
  );

  always_comb begin
    request_index = cpu_req_addr_i[INDEX_W+3:4];
    request_tag = cpu_req_addr_i[31:INDEX_W+4];
    request_word = cpu_req_addr_i[3:2];
    unique case (miss_word_q)
      2'd0: hit_word = sram_rdata[31:0];
      2'd1: hit_word = sram_rdata[63:32];
      2'd2: hit_word = sram_rdata[95:64];
      default: hit_word = sram_rdata[127:96];
    endcase
    unique case (miss_word_q)
      2'd0: refill_word = mem_rsp_data_i[31:0];
      2'd1: refill_word = mem_rsp_data_i[63:32];
      2'd2: refill_word = mem_rsp_data_i[95:64];
      default: refill_word = mem_rsp_data_i[127:96];
    endcase
    cpu_req_ready_o = (state_q == IDLE);
    cpu_rsp_valid_o = rsp_valid_q;
    cpu_rsp_data_o = rsp_data_q;
    mem_req_valid_o = (state_q == MISS_REQUEST);
    mem_req_addr_o = {miss_addr_q[31:4], 4'b0};
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      miss_addr_q <= '0;
      miss_index_q <= '0;
      miss_tag_q <= '0;
      miss_word_q <= '0;
      rsp_valid_q <= 1'b0;
      rsp_data_q <= '0;
      for (i = 0; i < SETS; i = i + 1)
        valid_q[i] <= 1'b0;
    end else begin
      rsp_valid_q <= 1'b0;
      unique case (state_q)
        IDLE: begin
          if (cpu_req_valid_i && cpu_req_ready_o) begin
            miss_addr_q <= cpu_req_addr_i;
            miss_index_q <= request_index;
            miss_tag_q <= request_tag;
            miss_word_q <= request_word;
            state_q <= TAG_READ;
          end
        end
        TAG_READ: begin
          if (valid_q[miss_index_q] &&
              (tag_q[miss_index_q] == miss_tag_q)) begin
            rsp_valid_q <= 1'b1;
            rsp_data_q <= hit_word;
            state_q <= IDLE;
          end else begin
            state_q <= MISS_REQUEST;
          end
        end
        MISS_REQUEST: begin
          if (mem_req_valid_o && mem_req_ready_i)
            state_q <= MISS_WAIT;
        end
        MISS_WAIT: begin
          if (mem_rsp_valid_i) begin
            valid_q[miss_index_q] <= 1'b1;
            tag_q[miss_index_q] <= miss_tag_q;
            rsp_valid_q <= 1'b1;
            rsp_data_q <= refill_word;
            state_q <= IDLE;
          end
        end
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
