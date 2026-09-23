module rv32_bpu_direction #(
  parameter int unsigned BHT_ENTRIES = 256,
  parameter int unsigned CONDSEEN_ENTRIES = 512
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic [31:0]            query_pc_i,
  output logic                   query_dir_taken_o,
  output logic                   query_use_global_o,
  output logic                   query_condseen_o,

  input  logic                   branch_train_i,
  input  logic [31:0]            branch_pc_i,
  input  logic                   branch_taken_i,
  input  logic [7:0]             branch_ghr_i,

  input  logic                   fetch_accept_i,
  input  logic                   squash_valid_i,
  input  logic                   query_shift_i,
  input  logic                   query_shift_value_i,
  input  logic [7:0]             squash_ghr_i,

  output logic [7:0]             ghr_o
);
  import rv32_pkg::*;

  localparam int unsigned BHT_INDEX_W = $clog2(BHT_ENTRIES);
  localparam int unsigned COND_INDEX_W = $clog2(CONDSEEN_ENTRIES);

  logic [1:0] local_pht_q [0:BHT_ENTRIES-1];
  logic [1:0] global_pht_q [0:BHT_ENTRIES-1];
  logic [1:0] selector_q [0:BHT_ENTRIES-1];
  logic [7:0] ghr_q;

  logic condseen_q [0:CONDSEEN_ENTRIES-1];

  logic [31:0] query_p2;
  logic [BHT_INDEX_W-1:0] query_local_idx, query_global_idx, query_sel_idx;
  logic [COND_INDEX_W-1:0] query_cond_idx;

  logic [31:0] branch_p2;
  logic [BHT_INDEX_W-1:0] branch_local_idx, branch_global_idx, branch_sel_idx;
  logic [COND_INDEX_W-1:0] branch_cond_idx;

  logic [7:0] ghr_next;
  integer comb_i;
  integer seq_i;

  always_comb begin
    query_p2 = query_pc_i >> 2;
    query_local_idx = query_p2[BHT_INDEX_W-1:0];
    query_global_idx = query_p2[BHT_INDEX_W-1:0] ^ ghr_q;
    query_sel_idx = query_p2[BHT_INDEX_W-1:0] ^ ghr_q;
    query_cond_idx = query_p2[COND_INDEX_W-1:0];
    query_use_global_o = selector_q[query_sel_idx] >= 2'b10;
    query_dir_taken_o = query_use_global_o ?
                        (global_pht_q[query_global_idx] >= 2'b10) :
                        (local_pht_q[query_local_idx] >= 2'b10);
    query_condseen_o = condseen_q[query_cond_idx];
  end

  always_comb begin
    branch_p2 = branch_pc_i >> 2;
    branch_local_idx = branch_p2[BHT_INDEX_W-1:0];
    branch_global_idx = branch_p2[BHT_INDEX_W-1:0] ^ branch_ghr_i;
    branch_sel_idx = branch_p2[BHT_INDEX_W-1:0] ^ branch_ghr_i;
    branch_cond_idx = branch_p2[COND_INDEX_W-1:0];
  end

  always_comb begin
    ghr_next = ghr_q;
    if (fetch_accept_i && !squash_valid_i) begin
      if (query_shift_i)
        ghr_next = {ghr_q[6:0], query_shift_value_i};
    end
    if (squash_valid_i)
      ghr_next = squash_ghr_i;
  end

  assign ghr_o = ghr_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ghr_q <= 8'd0;
      for (seq_i = 0; seq_i < BHT_ENTRIES; seq_i = seq_i + 1) begin
        local_pht_q[seq_i] <= 2'b01;
        global_pht_q[seq_i] <= 2'b01;
        selector_q[seq_i] <= 2'b01;
      end
      for (seq_i = 0; seq_i < CONDSEEN_ENTRIES; seq_i = seq_i + 1)
        condseen_q[seq_i] <= 1'b0;
    end else begin
      if (branch_train_i) begin
        if (branch_taken_i) begin
          if (local_pht_q[branch_local_idx] != 2'b11)
            local_pht_q[branch_local_idx] <= local_pht_q[branch_local_idx] + 2'b01;
          if (global_pht_q[branch_global_idx] != 2'b11)
            global_pht_q[branch_global_idx] <= global_pht_q[branch_global_idx] + 2'b01;
        end else begin
          if (local_pht_q[branch_local_idx] != 2'b00)
            local_pht_q[branch_local_idx] <= local_pht_q[branch_local_idx] - 2'b01;
          if (global_pht_q[branch_global_idx] != 2'b00)
            global_pht_q[branch_global_idx] <= global_pht_q[branch_global_idx] - 2'b01;
        end
        if ((global_pht_q[branch_global_idx] >= 2'b10) == branch_taken_i &&
            (local_pht_q[branch_local_idx] >= 2'b10) != branch_taken_i) begin
          if (selector_q[branch_sel_idx] != 2'b11)
            selector_q[branch_sel_idx] <= selector_q[branch_sel_idx] + 2'b01;
        end else if ((local_pht_q[branch_local_idx] >= 2'b10) == branch_taken_i &&
                     (global_pht_q[branch_global_idx] >= 2'b10) != branch_taken_i) begin
          if (selector_q[branch_sel_idx] != 2'b00)
            selector_q[branch_sel_idx] <= selector_q[branch_sel_idx] - 2'b01;
        end
        condseen_q[branch_cond_idx] <= 1'b1;
      end

      ghr_q <= ghr_next;
    end
  end
endmodule
