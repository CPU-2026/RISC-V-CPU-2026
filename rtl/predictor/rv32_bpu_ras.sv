module rv32_bpu_ras #(
  parameter int unsigned RAS_ENTRIES = 8,
  parameter int unsigned ALIGNQ_ENTRIES = 16
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic                   fetch_info_valid_i,
  input  logic                   fetch_info_call_i,
  input  logic                   fetch_info_return_i,
  input  logic [31:0]            fetch_info_pc_i,

  input  logic                   squash_valid_i,
  input  logic [7:0]             squash_align_tail_i,
  input  logic [7:0]             squash_ras_top_i,

  output logic [7:0]             ras_top_o,
  output logic [7:0]             align_tail_o,
  output logic [31:0]            query_ret_target_o
);
  localparam int unsigned RAS_PTR_W = $clog2(RAS_ENTRIES);
  localparam int unsigned ALIGNQ_PTR_W = $clog2(ALIGNQ_ENTRIES);

  logic [31:0] ras_pc_q [0:RAS_ENTRIES-1];
  logic [7:0] ras_times_q [0:RAS_ENTRIES-1];
  // This is a logical ring pointer. Only the low bits index physical storage.
  logic [7:0] ras_top_q;
  logic [31:0] align_addr_q [0:ALIGNQ_ENTRIES-1];
  logic [RAS_PTR_W-1:0] align_index_q [0:ALIGNQ_ENTRIES-1];
  logic [7:0] align_times_q [0:ALIGNQ_ENTRIES-1];
  logic [7:0] align_tail_q;

  logic [7:0] ras_top_next, align_tail_next;
  logic [31:0] ras_pc_next [0:RAS_ENTRIES-1];
  logic [7:0] ras_times_next [0:RAS_ENTRIES-1];
  logic [31:0] align_addr_next [0:ALIGNQ_ENTRIES-1];
  logic [RAS_PTR_W-1:0] align_index_next [0:ALIGNQ_ENTRIES-1];
  logic [7:0] align_times_next [0:ALIGNQ_ENTRIES-1];
  logic [7:0] replay_distance;
  logic [RAS_PTR_W-1:0] ras_prev_index;
  logic [ALIGNQ_PTR_W-1:0] replay_index;
  integer comb_i;
  integer seq_i;

  always_comb begin
    if (ras_top_q == 8'd0)
      query_ret_target_o = 32'd0;
    else
      query_ret_target_o = ras_pc_q[ras_top_q[RAS_PTR_W-1:0] - 1'b1];
  end

  assign ras_top_o = ras_top_q;
  assign align_tail_o = align_tail_q;

  always_comb begin
    ras_top_next = ras_top_q;
    align_tail_next = align_tail_q;
    replay_distance = 8'd0;
    ras_prev_index = RAS_PTR_W'(ras_top_next - 8'd1);
    replay_index = '0;
    for (comb_i = 0; comb_i < RAS_ENTRIES; comb_i = comb_i + 1) begin
      ras_pc_next[comb_i] = ras_pc_q[comb_i];
      ras_times_next[comb_i] = ras_times_q[comb_i];
    end
    for (comb_i = 0; comb_i < ALIGNQ_ENTRIES; comb_i = comb_i + 1) begin
      align_addr_next[comb_i] = align_addr_q[comb_i];
      align_index_next[comb_i] = align_index_q[comb_i];
      align_times_next[comb_i] = align_times_q[comb_i];
    end

    if (fetch_info_valid_i) begin
      if (fetch_info_call_i) begin
        if ((ras_top_next != 8'd0) &&
            (ras_pc_next[ras_prev_index] ==
             (fetch_info_pc_i + 32'd4))) begin
          align_addr_next[align_tail_next[ALIGNQ_PTR_W-1:0]] =
            ras_pc_next[ras_prev_index];
          align_index_next[align_tail_next[ALIGNQ_PTR_W-1:0]] =
            ras_prev_index;
          align_times_next[align_tail_next[ALIGNQ_PTR_W-1:0]] =
            ras_times_next[ras_prev_index];
          align_tail_next = align_tail_next + 8'd1;
          ras_times_next[ras_prev_index] = ras_times_next[ras_prev_index] + 8'd1;
        end else begin
          ras_pc_next[ras_top_next[RAS_PTR_W-1:0]] = fetch_info_pc_i + 32'd4;
          ras_times_next[ras_top_next[RAS_PTR_W-1:0]] = 8'd1;
          ras_top_next = ras_top_next + 8'd1;
        end
      end else if (fetch_info_return_i && (ras_top_next != 8'd0)) begin
        align_addr_next[align_tail_next[ALIGNQ_PTR_W-1:0]] =
          ras_pc_next[ras_prev_index];
        align_index_next[align_tail_next[ALIGNQ_PTR_W-1:0]] =
          ras_prev_index;
        align_times_next[align_tail_next[ALIGNQ_PTR_W-1:0]] =
          ras_times_next[ras_prev_index];
        align_tail_next = align_tail_next + 8'd1;
        if (ras_times_next[ras_prev_index] > 8'd1)
          ras_times_next[ras_prev_index] = ras_times_next[ras_prev_index] - 8'd1;
        else
          ras_top_next = ras_top_next - 8'd1;
      end
    end

    if (squash_valid_i) begin
      replay_distance = align_tail_q - squash_align_tail_i;
      for (comb_i = 0; comb_i < ALIGNQ_ENTRIES; comb_i = comb_i + 1) begin
        if (comb_i < replay_distance) begin
          replay_index = align_tail_q[ALIGNQ_PTR_W-1:0] - ALIGNQ_PTR_W'(1) -
                         comb_i[ALIGNQ_PTR_W-1:0];
          ras_pc_next[align_index_q[replay_index]] = align_addr_q[replay_index];
          ras_times_next[align_index_q[replay_index]] = align_times_q[replay_index];
        end
      end
      align_tail_next = squash_align_tail_i;
      ras_top_next = squash_ras_top_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ras_top_q <= 8'd0;
      align_tail_q <= 8'd0;
      for (seq_i = 0; seq_i < RAS_ENTRIES; seq_i = seq_i + 1) begin
        ras_pc_q[seq_i] <= '0;
        ras_times_q[seq_i] <= 8'd0;
      end
      for (seq_i = 0; seq_i < ALIGNQ_ENTRIES; seq_i = seq_i + 1) begin
        align_addr_q[seq_i] <= '0;
        align_index_q[seq_i] <= '0;
        align_times_q[seq_i] <= 8'd0;
      end
    end else begin
      ras_top_q <= ras_top_next;
      align_tail_q <= align_tail_next;
      for (seq_i = 0; seq_i < RAS_ENTRIES; seq_i = seq_i + 1) begin
        ras_pc_q[seq_i] <= ras_pc_next[seq_i];
        ras_times_q[seq_i] <= ras_times_next[seq_i];
      end
      for (seq_i = 0; seq_i < ALIGNQ_ENTRIES; seq_i = seq_i + 1) begin
        align_addr_q[seq_i] <= align_addr_next[seq_i];
        align_index_q[seq_i] <= align_index_next[seq_i];
        align_times_q[seq_i] <= align_times_next[seq_i];
      end
    end
  end
endmodule
