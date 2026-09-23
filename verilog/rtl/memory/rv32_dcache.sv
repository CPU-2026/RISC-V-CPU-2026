module rv32_dcache #(
  parameter int unsigned SETS = 1024,
  parameter int unsigned WAYS = 4
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  input  logic             cpu_req_valid_i,
  output logic             cpu_req_ready_o,
  input  logic             cpu_req_write_i,
  input  logic [31:0]      cpu_req_addr_i,
  input  logic [31:0]      cpu_req_wdata_i,
  input  logic [3:0]       cpu_req_wstrb_i,
  input  logic [1:0]       cpu_req_size_i,
  output logic             cpu_rsp_valid_o,
  output logic [31:0]      cpu_rsp_data_o,

  output logic             mem_req_valid_o,
  input  logic             mem_req_ready_i,
  output logic             mem_req_write_o,
  output logic [31:0]      mem_req_addr_o,
  output logic [127:0]     mem_req_wdata_o,
  input  logic             mem_rsp_valid_i,
  input  logic [127:0]     mem_rsp_data_i,

  input  logic             flush_i,
  output logic             flush_done_o
);
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned WAY_W = $clog2(WAYS);
  localparam int unsigned TAG_W = 32 - INDEX_W - 4;

  typedef enum logic [2:0] {
    IDLE,
    TAG_READ,
    WRITEBACK_REQUEST,
    REFILL_REQUEST,
    REFILL_WAIT,
    FLUSH_SCAN,
    FLUSH_READ,
    FLUSH_WRITEBACK
  } state_e;
  state_e state_q;

  logic valid_q [0:WAYS-1][0:SETS-1];
  logic dirty_q [0:WAYS-1][0:SETS-1];
  logic [TAG_W-1:0] tag_q [0:WAYS-1][0:SETS-1];
  logic [2:0] plru_q [0:SETS-1];

  logic saved_write_q;
  logic [31:0] saved_addr_q;
  logic [31:0] saved_wdata_q;
  logic [3:0] saved_wstrb_q;
  logic [1:0] saved_size_q;
  logic [INDEX_W-1:0] saved_index_q;
  logic [3:0] saved_offset_q;
  logic req_hit_q;
  logic [WAY_W-1:0] req_hit_way_q, req_victim_q;
  logic [WAY_W-1:0] victim_way_q;
  logic [127:0] evict_data_q;
  logic [127:0] flush_data_q;
  logic [INDEX_W-1:0] flush_set_q;
  logic [WAY_W-1:0] flush_way_q;
  logic flush_done_q;
  logic [WAY_W-1:0] flush_way_next;
  logic [INDEX_W-1:0] flush_set_next;
  logic unused_cout_flush_way, unused_cout_flush_set;

  logic rsp_valid_q;
  logic [31:0] rsp_data_q;
  logic [INDEX_W-1:0] request_index;
  logic [TAG_W-1:0] request_tag;
  logic [3:0] request_offset;
  logic hit_found;
  logic [WAY_W-1:0] hit_way;
  logic victim_found;
  logic [WAY_W-1:0] selected_victim;
  logic [INDEX_W-1:0] saved_index;
  logic [TAG_W-1:0] saved_tag;
  logic [127:0] refill_merged;
  logic [127:0] sram_rdata [0:WAYS-1];
  logic [127:0] hit_line, victim_line, flush_line;
  logic [31:0] hit_word, refill_word;
  logic [15:0] store_wmask;
  logic [127:0] store_wdata;
  logic accept_q;
  integer comb_way;
  integer seq_way, seq_set;
  genvar g_way;

  rv32_add #(.WIDTH(WAY_W)) u_flush_way_next (
    .a_i(flush_way_q), .b_i(WAY_W'(1)), .cin_i(1'b0),
    .sum_o(flush_way_next), .cout_o(unused_cout_flush_way)
  );

  rv32_add #(.WIDTH(INDEX_W)) u_flush_set_next (
    .a_i(flush_set_q), .b_i(INDEX_W'(1)), .cin_i(1'b0),
    .sum_o(flush_set_next), .cout_o(unused_cout_flush_set)
  );

  function automatic logic [127:0] merge_store(
    input logic [127:0] line,
    input logic [3:0] offset,
    input logic [31:0] data,
    input logic [3:0] strobe
  );
    logic [127:0] result;
    integer byte_index;
    begin
      result = line;
      for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
        if (strobe[byte_index])
          result[((32'(offset) + byte_index) << 3) +: 8] =
            data[(byte_index << 3) +: 8];
      merge_store = result;
    end
  endfunction

  function automatic logic [31:0] extract_line_word(
    input logic [127:0] line,
    input logic [3:0] offset
  );
    logic [127:0] shifted;
    begin
      shifted = line >> ({4'b0, offset} << 3);
      extract_line_word = shifted[31:0];
    end
  endfunction

  function automatic logic [2:0] plru_after_access(
    input logic [2:0] old_plru,
    input logic [WAY_W-1:0] accessed_way
  );
    logic [2:0] next_plru;
    begin
      next_plru = old_plru;
      if (accessed_way < WAY_W'(2))
        next_plru[2] = 1'b1;
      else
        next_plru[2] = 1'b0;
      unique case (accessed_way)
        WAY_W'(0): next_plru[1] = 1'b1;
        WAY_W'(1): next_plru[1] = 1'b0;
        WAY_W'(2): next_plru[0] = 1'b1;
        default:   next_plru[0] = 1'b0;
      endcase
      plru_after_access = next_plru;
    end
  endfunction

  generate
    for (g_way = 0; g_way < WAYS; g_way = g_way + 1) begin : g_data
      rv32_sram_1rw #(
        .ADDR_W(INDEX_W),
        .DATA_W(128),
        .MASK_W(16)
      ) u_way (
        .clk_i(clk_i),
        .rd_en_i(accept_q ||
                 (state_q == FLUSH_SCAN && !flush_done_q &&
                  valid_q[flush_way_q][flush_set_q] &&
                  dirty_q[flush_way_q][flush_set_q])),
        .rd_addr_i((state_q == FLUSH_SCAN) ? flush_set_q : request_index),
        .rd_data_o(sram_rdata[g_way]),
        .wr_en_i((state_q == TAG_READ && req_hit_q && saved_write_q &&
                  (req_hit_way_q == WAY_W'(g_way))) ||
                 (state_q == REFILL_WAIT && mem_rsp_valid_i &&
                  (victim_way_q == WAY_W'(g_way)))),
        .wr_addr_i(saved_index),
        .wr_data_i((state_q == REFILL_WAIT) ?
                   (saved_write_q ? refill_merged : mem_rsp_data_i) :
                   store_wdata),
        .wr_mask_i((state_q == REFILL_WAIT) ? 16'hffff : store_wmask)
      );
    end
  endgenerate

  assign cpu_req_ready_o = (state_q == IDLE) && !flush_i;

  always_comb begin
    request_index = cpu_req_addr_i[INDEX_W+3:4];
    request_tag = cpu_req_addr_i[31:INDEX_W+4];
    request_offset = cpu_req_addr_i[3:0];
    hit_found = 1'b0;
    hit_way = '0;
    for (comb_way = 0; comb_way < WAYS; comb_way = comb_way + 1) begin
      if (!hit_found && valid_q[comb_way][request_index] &&
          (tag_q[comb_way][request_index] == request_tag)) begin
        hit_found = 1'b1;
        hit_way = comb_way[WAY_W-1:0];
      end
    end

    victim_found = 1'b0;
    selected_victim = plru_q[request_index][2] ?
      (plru_q[request_index][0] ? WAY_W'(3) : WAY_W'(2)) :
      (plru_q[request_index][1] ? WAY_W'(1) : WAY_W'(0));
    for (comb_way = 0; comb_way < WAYS; comb_way = comb_way + 1) begin
      if (!victim_found && !valid_q[comb_way][request_index]) begin
        victim_found = 1'b1;
        selected_victim = comb_way[WAY_W-1:0];
      end
    end

    accept_q = cpu_req_valid_i && cpu_req_ready_o;

    saved_index = saved_addr_q[INDEX_W+3:4];
    saved_tag = saved_addr_q[31:INDEX_W+4];
    refill_merged = merge_store(mem_rsp_data_i, saved_addr_q[3:0],
                                  saved_wdata_q, saved_wstrb_q);

    hit_line = sram_rdata[req_hit_way_q];
    victim_line = sram_rdata[req_victim_q];
    flush_line = sram_rdata[flush_way_q];
    hit_word = extract_line_word(hit_line, saved_offset_q);
    refill_word = extract_line_word(mem_rsp_data_i, saved_addr_q[3:0]);

    store_wmask = 16'b0;
    store_wdata = 128'b0;
    for (comb_way = 0; comb_way < 4; comb_way = comb_way + 1) begin
      if (saved_wstrb_q[comb_way]) begin
        store_wmask[saved_offset_q + comb_way[3:0]] = 1'b1;
        store_wdata[((32'(saved_offset_q) + comb_way) << 3) +: 8] =
          saved_wdata_q[(comb_way << 3) +: 8];
      end
    end

    cpu_rsp_valid_o = rsp_valid_q;
    cpu_rsp_data_o = rsp_data_q;
    flush_done_o = flush_done_q;

    mem_req_valid_o = (state_q == WRITEBACK_REQUEST) ||
                      (state_q == REFILL_REQUEST) ||
                      (state_q == FLUSH_WRITEBACK);
    mem_req_write_o = (state_q == WRITEBACK_REQUEST) ||
                      (state_q == FLUSH_WRITEBACK);
    mem_req_addr_o = 32'b0;
    mem_req_wdata_o = 128'b0;
    if (state_q == WRITEBACK_REQUEST) begin
      mem_req_addr_o = {tag_q[victim_way_q][saved_index], saved_index, 4'b0};
      mem_req_wdata_o = evict_data_q;
    end else if (state_q == REFILL_REQUEST) begin
      mem_req_addr_o = {saved_addr_q[31:4], 4'b0};
    end else if (state_q == FLUSH_WRITEBACK) begin
      mem_req_addr_o = {tag_q[flush_way_q][flush_set_q], flush_set_q, 4'b0};
      mem_req_wdata_o = flush_data_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      saved_write_q <= 1'b0;
      saved_addr_q <= '0;
      saved_wdata_q <= '0;
      saved_wstrb_q <= '0;
      saved_size_q <= '0;
      saved_index_q <= '0;
      saved_offset_q <= '0;
      req_hit_q <= 1'b0;
      req_hit_way_q <= '0;
      req_victim_q <= '0;
      victim_way_q <= '0;
      evict_data_q <= '0;
      flush_data_q <= '0;
      flush_set_q <= '0;
      flush_way_q <= '0;
      flush_done_q <= 1'b0;
      rsp_valid_q <= 1'b0;
      rsp_data_q <= '0;
      for (seq_set = 0; seq_set < SETS; seq_set = seq_set + 1) begin
        plru_q[seq_set] <= '0;
        for (seq_way = 0; seq_way < WAYS; seq_way = seq_way + 1) begin
          valid_q[seq_way][seq_set] <= 1'b0;
          dirty_q[seq_way][seq_set] <= 1'b0;
        end
      end
    end else begin
      rsp_valid_q <= 1'b0;
      unique case (state_q)
        IDLE: begin
          if (flush_i && !flush_done_q) begin
            flush_set_q <= '0;
            flush_way_q <= '0;
            state_q <= FLUSH_SCAN;
          end else if (!flush_i) begin
            flush_done_q <= 1'b0;
          end
          if (accept_q) begin
            saved_write_q <= cpu_req_write_i;
            saved_addr_q <= cpu_req_addr_i;
            saved_wdata_q <= cpu_req_wdata_i;
            saved_wstrb_q <= cpu_req_wstrb_i;
            saved_size_q <= cpu_req_size_i;
            saved_index_q <= request_index;
            saved_offset_q <= request_offset;
            req_hit_q <= hit_found;
            req_hit_way_q <= hit_way;
            req_victim_q <= selected_victim;
            victim_way_q <= selected_victim;
            state_q <= TAG_READ;
          end
        end
        TAG_READ: begin
          if (req_hit_q) begin
            plru_q[saved_index_q] <=
              plru_after_access(plru_q[saved_index_q], req_hit_way_q);
            if (saved_write_q) begin
              dirty_q[req_hit_way_q][saved_index_q] <= 1'b1;
            end else begin
              rsp_valid_q <= 1'b1;
              rsp_data_q <= hit_word;
            end
            state_q <= IDLE;
          end else begin
            if (valid_q[req_victim_q][saved_index_q] &&
                dirty_q[req_victim_q][saved_index_q]) begin
              evict_data_q <= victim_line;
              state_q <= WRITEBACK_REQUEST;
            end else begin
              state_q <= REFILL_REQUEST;
            end
          end
        end
        WRITEBACK_REQUEST: begin
          if (mem_req_valid_o && mem_req_ready_i)
            state_q <= REFILL_REQUEST;
        end
        REFILL_REQUEST: begin
          if (mem_req_valid_o && mem_req_ready_i)
            state_q <= REFILL_WAIT;
        end
        REFILL_WAIT: begin
          if (mem_rsp_valid_i) begin
            valid_q[victim_way_q][saved_index] <= 1'b1;
            dirty_q[victim_way_q][saved_index] <= saved_write_q;
            tag_q[victim_way_q][saved_index] <= saved_tag;
            plru_q[saved_index] <=
              plru_after_access(plru_q[saved_index], victim_way_q);
            if (!saved_write_q) begin
              rsp_valid_q <= 1'b1;
              rsp_data_q <= refill_word;
            end
            state_q <= IDLE;
          end
        end
        FLUSH_SCAN: begin
          if (valid_q[flush_way_q][flush_set_q] &&
              dirty_q[flush_way_q][flush_set_q]) begin
            state_q <= FLUSH_READ;
          end else if ((flush_way_q == WAY_W'(WAYS-1)) &&
                       (flush_set_q == INDEX_W'(SETS-1))) begin
            flush_done_q <= 1'b1;
            state_q <= IDLE;
          end else if (flush_way_q == WAY_W'(WAYS-1)) begin
            flush_way_q <= '0;
            flush_set_q <= flush_set_next;
          end else begin
            flush_way_q <= flush_way_next;
          end
        end
        FLUSH_READ: begin
          flush_data_q <= flush_line;
          state_q <= FLUSH_WRITEBACK;
        end
        FLUSH_WRITEBACK: begin
          if (mem_req_valid_o && mem_req_ready_i) begin
            dirty_q[flush_way_q][flush_set_q] <= 1'b0;
            if ((flush_way_q == WAY_W'(WAYS-1)) &&
                (flush_set_q == INDEX_W'(SETS-1))) begin
              flush_done_q <= 1'b1;
              state_q <= IDLE;
            end else if (flush_way_q == WAY_W'(WAYS-1)) begin
              flush_way_q <= '0;
              flush_set_q <= flush_set_next;
              state_q <= FLUSH_SCAN;
            end else begin
              flush_way_q <= flush_way_next;
              state_q <= FLUSH_SCAN;
            end
          end
        end
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
