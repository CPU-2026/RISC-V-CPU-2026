module rv32_rat (
  input  logic                       clk_i,
  input  logic                       rst_ni,

  input  logic [4:0]                 rs1_arch_i,
  input  logic [4:0]                 rs2_arch_i,
  output rv32_pkg::phy_tag_t         rs1_phy_o,
  output rv32_pkg::phy_tag_t         rs2_phy_o,

  input  logic                       rename_valid_i,
  input  logic [4:0]                 rename_arch_i,
  input  rv32_pkg::phy_tag_t         rename_phy_i,
  output rv32_pkg::phy_tag_t         rename_old_phy_o,

  input  logic                       restore_valid_i,
  input  rv32_pkg::rob_tag_t          restore_tag_i,
  input  rv32_pkg::rob_tag_t          restore_head_tag_i,
  input  rv32_pkg::rob_tag_t          replay_tag_i [0:rv32_pkg::ROB_ENTRIES-1],
  input  logic [4:0]                 replay_arch_rd_i [0:rv32_pkg::ROB_ENTRIES-1],
  input  rv32_pkg::phy_tag_t         replay_new_phy_i [0:rv32_pkg::ROB_ENTRIES-1],

  input  logic                       commit_valid_i,
  input  logic [4:0]                 commit_arch_i,
  input  rv32_pkg::phy_tag_t         commit_phy_i,

  input  logic [4:0]                 debug_arch_i,
  output rv32_pkg::phy_tag_t         debug_phy_o
);
  import rv32_pkg::*;

  phy_tag_t map_q [0:ARCH_REGS-1];
  phy_tag_t arch_q [0:ARCH_REGS-1];
  phy_tag_t restore_map [0:ARCH_REGS-1];
  rob_tag_t replay_cursor [0:ROB_ENTRIES];
  logic replay_active [0:ROB_ENTRIES];
  logic replay_valid [0:ROB_ENTRIES-1];

  always_comb begin
    rs1_phy_o = (rs1_arch_i == 5'd0) ? '0 : map_q[rs1_arch_i];
    rs2_phy_o = (rs2_arch_i == 5'd0) ? '0 : map_q[rs2_arch_i];
    rename_old_phy_o = (rename_arch_i == 5'd0) ? '0 :
                       map_q[rename_arch_i];
    debug_phy_o = (debug_arch_i == 5'd0) ? '0 : map_q[debug_arch_i];
  end

  always_comb begin : build_restore_map
    integer replay_index, arch_index, window_index;

    replay_cursor[0] = restore_head_tag_i;
    replay_active[0] = restore_valid_i;
    for (replay_index = 0; replay_index < ROB_ENTRIES;
         replay_index = replay_index + 1) begin
      // A stale or malformed window must not replay entries beyond its gap.
      replay_valid[replay_index] = replay_active[replay_index] &&
                        (replay_tag_i[replay_index] == replay_cursor[replay_index]);
      replay_cursor[replay_index+1] = replay_cursor[replay_index];
      replay_active[replay_index+1] = 1'b0;
      if (replay_valid[replay_index] &&
          (replay_cursor[replay_index] != restore_tag_i)) begin
        replay_cursor[replay_index+1] =
          replay_cursor[replay_index] + rob_tag_t'(1);
        replay_active[replay_index+1] = 1'b1;
      end
    end

    for (arch_index = 0; arch_index < ARCH_REGS;
         arch_index = arch_index + 1) begin
      restore_map[arch_index] = arch_q[arch_index];
      for (window_index = 0; window_index < ROB_ENTRIES;
           window_index = window_index + 1) begin
        if (replay_valid[window_index] &&
            (replay_arch_rd_i[window_index] == arch_index[4:0]) &&
            (replay_arch_rd_i[window_index] != 5'd0) &&
            (replay_new_phy_i[window_index] != '0))
          restore_map[arch_index] = replay_new_phy_i[window_index];
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_mappings
    integer state_index;

    if (!rst_ni) begin
      for (state_index = 0; state_index < ARCH_REGS;
           state_index = state_index + 1) begin
        map_q[state_index] <= phy_tag_t'(state_index);
        arch_q[state_index] <= phy_tag_t'(state_index);
      end
    end else begin
      if (restore_valid_i) begin
        for (state_index = 0; state_index < ARCH_REGS;
             state_index = state_index + 1)
          map_q[state_index] <= restore_map[state_index];
      end else if (rename_valid_i && (rename_arch_i != 5'd0)) begin
        map_q[rename_arch_i] <= rename_phy_i;
      end

      if (commit_valid_i && (commit_arch_i != 5'd0) &&
          (commit_phy_i != '0))
        arch_q[commit_arch_i] <= commit_phy_i;
    end
  end
endmodule
