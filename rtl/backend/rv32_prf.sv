module rv32_prf #(
  parameter int unsigned PRF_DEPTH = rv32_pkg::PRF_ENTRIES,
  parameter int unsigned ROB_DEPTH = rv32_pkg::ROB_ENTRIES
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,

  input  logic                       alloc_valid_i,
  output logic                       alloc_ready_o,
  output rv32_pkg::phy_tag_t         alloc_phy_o,
  input  logic                       alloc_value_valid_i,
  input  logic [31:0]                alloc_value_i,

  input  logic                       free_valid_i,
  input  rv32_pkg::phy_tag_t         free_phy_i,

  // Recovery is ROB window replay -- the same window rv32_rat consumes. Only
  // the entries strictly younger than restore_tag_i are recycled; the boundary
  // itself and everything older keep their physical registers. restore_count_i
  // bounds the window to the live entries, so a stale tag left in a slot beyond
  // the ROB tail can never be replayed.
  input  logic                       restore_valid_i,
  input  rv32_pkg::rob_tag_t         restore_tag_i,
  input  logic [$clog2(ROB_DEPTH+1)-1:0] restore_count_i,
  input  rv32_pkg::rob_tag_t         replay_tag_i [0:ROB_DEPTH-1],
  input  rv32_pkg::phy_tag_t         replay_new_phy_i [0:ROB_DEPTH-1],

  input  rv32_pkg::phy_tag_t         read1_phy_i,
  output logic                       read1_ready_o,
  output logic [31:0]                read1_value_o,
  input  rv32_pkg::phy_tag_t         read2_phy_i,
  output logic                       read2_ready_o,
  output logic [31:0]                read2_value_o,
  input  rv32_pkg::phy_tag_t         read3_phy_i,
  output logic                       read3_ready_o,
  output logic [31:0]                read3_value_o,

  input  logic                       wb0_valid_i,
  input  rv32_pkg::phy_tag_t         wb0_phy_i,
  input  logic [31:0]                wb0_value_i,
  input  logic                       wb1_valid_i,
  input  rv32_pkg::phy_tag_t         wb1_phy_i,
  input  logic [31:0]                wb1_value_i,
  input  logic                       wb2_valid_i,
  input  rv32_pkg::phy_tag_t         wb2_phy_i,
  input  logic [31:0]                wb2_value_i,
  input  logic                       wb3_valid_i,
  input  rv32_pkg::phy_tag_t         wb3_phy_i,
  input  logic [31:0]                wb3_value_i,

  output logic [PRF_DEPTH-1:0]       ready_vector_o,
  output logic [$clog2(PRF_DEPTH+1)-1:0] free_count_o
);
  import rv32_pkg::*;

  localparam rob_tag_t ROB_AGE_MASK = '1;
  localparam rob_tag_t ROB_AGE_LIMIT = rob_tag_t'(1 << (ROB_TAG_W-1));

  logic [31:0] value_q [0:PRF_DEPTH-1];
  logic [PRF_DEPTH-1:0] ready_q;
  logic [PRF_DEPTH-1:0] free_q;
  logic [PRF_DEPTH-1:0] free_after_events;
  logic [PRF_DEPTH-1:0] restore_young_mask;
  phy_tag_t selected_phy;
  logic selected_valid;
  integer comb_i;
  integer comb_j;
  integer seq_i;

  always_comb begin
    selected_phy = '0;
    selected_valid = 1'b0;
    for (comb_i = 1; comb_i < PRF_DEPTH; comb_i = comb_i + 1) begin
      if (!selected_valid && free_q[comb_i]) begin
        selected_phy = phy_tag_t'(comb_i);
        selected_valid = 1'b1;
      end
    end
    // Squash owns recovery: only a non-squash cycle may pop. issue_fire already
    // excludes global_flush upstream, so this is a local invariant guard.
    alloc_ready_o = !restore_valid_i && selected_valid;
    alloc_phy_o = selected_phy;

    read1_ready_o = (read1_phy_i == '0) ? 1'b1 : ready_q[read1_phy_i];
    read1_value_o = (read1_phy_i == '0) ? 32'b0 : value_q[read1_phy_i];
    read2_ready_o = (read2_phy_i == '0) ? 1'b1 : ready_q[read2_phy_i];
    read2_value_o = (read2_phy_i == '0) ? 32'b0 : value_q[read2_phy_i];
    read3_ready_o = (read3_phy_i == '0) ? 1'b1 : ready_q[read3_phy_i];
    read3_value_o = (read3_phy_i == '0) ? 32'b0 : value_q[read3_phy_i];
    ready_vector_o = ready_q;

    free_count_o = '0;
    for (comb_i = 1; comb_i < PRF_DEPTH; comb_i = comb_i + 1)
      if (free_q[comb_i])
        free_count_o = free_count_o + 1'b1;
  end

  // A squashed instruction cannot have released a register yet: commits run in
  // order at the head and the head is strictly older than the boundary. So
  // free_q already covers every release that happened since the boundary was
  // renamed, and recovery is a plain set-union of the window's new physical
  // tags. That is exactly what the reference tree does by pushing each
  // robNewPhy of (SquashTag, next-free) back onto its free ring.
  //
  // The age test is written out instead of calling rv32_pkg::rob_is_younger:
  // iverilog stalls forever when that function (which contains variable-index
  // writes) is inlined into an always_comb that reads the replay window, while
  // the same predicate as arithmetic is fine. The two agree on all 1024 tag
  // pairs once the limit is exclusive -- rob_is_younger is false at age 16,
  // which no live lane can reach anyway (a window holds at most ROB_DEPTH
  // entries).
  always_comb begin
    restore_young_mask = '0;
    if (restore_valid_i) begin
      for (comb_j = 0; comb_j < ROB_DEPTH; comb_j = comb_j + 1) begin
        if ((comb_j < restore_count_i) &&
            (((replay_tag_i[comb_j] - restore_tag_i) & ROB_AGE_MASK) != '0) &&
            (((replay_tag_i[comb_j] - restore_tag_i) & ROB_AGE_MASK) <
             ROB_AGE_LIMIT) &&
            (replay_new_phy_i[comb_j] != '0))
          restore_young_mask[replay_new_phy_i[comb_j]] = 1'b1;
      end
    end
  end

  always_comb begin
    free_after_events = free_q;
    if (free_valid_i && (free_phy_i != '0))
      free_after_events[free_phy_i] = 1'b1;
    if (restore_valid_i)
      free_after_events = free_after_events | restore_young_mask;
    if (alloc_valid_i && selected_valid)
      free_after_events[selected_phy] = 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ready_q <= '0;
      free_q <= '0;
      for (seq_i = 0; seq_i < PRF_DEPTH; seq_i = seq_i + 1)
        value_q[seq_i] <= 32'b0;
      for (seq_i = 0; seq_i < ARCH_REGS; seq_i = seq_i + 1)
        ready_q[seq_i] <= 1'b1;
      for (seq_i = ARCH_REGS; seq_i < PRF_DEPTH; seq_i = seq_i + 1)
        free_q[seq_i] <= 1'b1;
    end else begin
      free_q <= free_after_events;

      if (alloc_valid_i && selected_valid) begin
        value_q[selected_phy] <= alloc_value_i;
        ready_q[selected_phy] <= alloc_value_valid_i;
      end

      if (wb0_valid_i && (wb0_phy_i != '0)) begin
        value_q[wb0_phy_i] <= wb0_value_i;
        ready_q[wb0_phy_i] <= 1'b1;
      end
      if (wb1_valid_i && (wb1_phy_i != '0)) begin
        value_q[wb1_phy_i] <= wb1_value_i;
        ready_q[wb1_phy_i] <= 1'b1;
      end
      if (wb2_valid_i && (wb2_phy_i != '0)) begin
        value_q[wb2_phy_i] <= wb2_value_i;
        ready_q[wb2_phy_i] <= 1'b1;
      end
      if (wb3_valid_i && (wb3_phy_i != '0)) begin
        value_q[wb3_phy_i] <= wb3_value_i;
        ready_q[wb3_phy_i] <= 1'b1;
      end

      value_q[0] <= 32'b0;
      ready_q[0] <= 1'b1;
      free_q[0] <= 1'b0;
    end
  end
endmodule
