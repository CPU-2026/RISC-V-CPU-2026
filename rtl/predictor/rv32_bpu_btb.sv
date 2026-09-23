// Branch target buffer: a direct-mapped table of independently allocated
// branches. Each entry is one packed 56-bit word, indexed by PC[7:2]:
//
//   [55:32] tag     PC[31:BTB_INDEX_W+2]  (24 bit at the default geometry)
//   [31: 2] target  target[31:2]          (30 bit)
//   [ 1: 0] state   INVALID / CONDITIONAL / UNCONDITIONAL / RETURN
//
// The index covers PC[7:2] and the tag covers the remaining upper bits, so a
// tag hit together with the index is a full PC identity match for the 4-byte
// aligned addresses this core uses. `target[1:0]` is not stored: architectural
// jump targets are 4-byte aligned (JALR clears bit 0 in the ALU and a
// misaligned JAL/JALR traps in the BRU), so it is reconstructed as zero.
//
// Three training sources share the table and keep the fixed priority
// `fetch predecode > jump CDB > conditional BRU`. They train two field groups
// that used to be independent write ports:
//
//   tag + state : fetch line  > jump line    > branch line
//   target      : fetch static JAL > jump target > branch target
//
// A fetch JALR/RET line carries no static target, so it must not hide a
// resolved target from a lower-priority source landing on the same line; that
// case folds the lower-priority target into the fetch word. Because the entry
// is a single 56-bit register, the two groups are composed into one word
// before the flop, which keeps `fetch > jump > branch` per entry at one write
// per entry per cycle.
module rv32_bpu_btb #(
  parameter int unsigned BTB_ENTRIES = 64
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic [31:0]            query_pc_i,
  output logic                   query_btb_hit_o,
  output logic                   query_btb_uncond_o,
  output logic                   query_btb_ret_o,
  output logic [31:0]            query_btb_tgt_o,

  input  logic                   fetch_info_valid_i,
  input  logic                   fetch_info_return_i,
  input  logic                   fetch_info_jal_target_valid_i,
  input  logic [31:0]            fetch_info_pc_i,
  input  logic [31:0]            fetch_info_jal_target_i,

  input  logic                   branch_train_i,
  input  logic                   branch_taken_i,
  input  logic [31:0]            branch_pc_i,
  input  logic [31:0]            branch_next_pc_i,

  input  logic                   jump_train_i,
  input  logic [31:0]            jump_pc_i,
  input  logic [31:0]            jump_target_i,
  input  logic                   jump_is_return_i
);
  localparam int unsigned BTB_INDEX_W = $clog2(BTB_ENTRIES);

  // Packed entry layout. BTB_ENTRIES=64 gives the 56-bit word
  // {tag 24, target 30, state 2}; other geometries shift the tag width so the
  // index and tag fields still partition the PC exactly.
  localparam int unsigned BTB_STATE_LSB = 0;
  localparam int unsigned BTB_STATE_W   = 2;
  localparam int unsigned BTB_TGT_LSB   = BTB_STATE_LSB + BTB_STATE_W;
  localparam int unsigned BTB_TGT_W     = 30;
  localparam int unsigned BTB_TAG_LSB   = BTB_TGT_LSB + BTB_TGT_W;
  localparam int unsigned BTB_TAG_W     = 32 - (BTB_INDEX_W + 2);
  localparam int unsigned BTB_ENTRY_W   = BTB_TAG_LSB + BTB_TAG_W;

  localparam logic [BTB_STATE_W-1:0] BTB_STATE_INVALID = 2'b00;
  localparam logic [BTB_STATE_W-1:0] BTB_STATE_COND    = 2'b01;
  localparam logic [BTB_STATE_W-1:0] BTB_STATE_UNCOND  = 2'b10;
  localparam logic [BTB_STATE_W-1:0] BTB_STATE_RET     = 2'b11;

  logic [BTB_ENTRY_W-1:0] btb_entry_q [0:BTB_ENTRIES-1];

  logic [31:0] query_p2;
  logic [BTB_INDEX_W-1:0] query_btb_idx;
  logic [BTB_ENTRY_W-1:0] query_entry;
  logic [BTB_STATE_W-1:0] query_state;

  logic fetch_line_write, fetch_target_write;
  logic [BTB_INDEX_W-1:0] fetch_btb_idx;
  logic jump_line_write, jump_target_write;
  logic [BTB_INDEX_W-1:0] jump_btb_idx;
  logic branch_line_write, branch_target_write;
  logic [BTB_INDEX_W-1:0] branch_btb_idx;
  logic fetch_jump_same, fetch_branch_same, jump_branch_same;

  logic [BTB_TGT_W-1:0] fetch_tgt_next;
  logic [BTB_STATE_W-1:0] fetch_state_next;
  logic [BTB_ENTRY_W-1:0] fetch_entry_next, jump_entry_next, branch_entry_next;

  integer seq_i;

  always_comb begin
    query_p2 = query_pc_i >> 2;
    query_btb_idx = query_p2[BTB_INDEX_W-1:0];
    query_entry = btb_entry_q[query_btb_idx];
    query_state = query_entry[BTB_STATE_LSB+:BTB_STATE_W];

    query_btb_hit_o = (query_state != BTB_STATE_INVALID) &&
                      (query_entry[BTB_TAG_LSB+:BTB_TAG_W] == query_pc_i[31:BTB_INDEX_W+2]);
    // The state field carries both flags, and only a writer that also sets the
    // tag can leave a non-invalid state behind, so these stay ungated by the
    // hit - exactly the flag reads the separate-flag table used to expose.
    query_btb_uncond_o = (query_state == BTB_STATE_UNCOND) ||
                         (query_state == BTB_STATE_RET);
    query_btb_ret_o = (query_state == BTB_STATE_RET);
    // target[1:0] is not stored; architectural targets are 4-byte aligned.
    query_btb_tgt_o = {query_entry[BTB_TGT_LSB+:BTB_TGT_W], 2'b00};
  end

  always_comb begin
    fetch_line_write = fetch_info_valid_i;
    fetch_target_write = fetch_info_valid_i && !fetch_info_return_i &&
                         fetch_info_jal_target_valid_i;
    fetch_btb_idx = fetch_info_pc_i[BTB_INDEX_W+1:2];

    jump_line_write = jump_train_i;
    jump_target_write = jump_train_i;
    jump_btb_idx = jump_pc_i[BTB_INDEX_W+1:2];

    branch_line_write = branch_train_i && branch_taken_i;
    branch_target_write = branch_line_write;
    branch_btb_idx = branch_pc_i[BTB_INDEX_W+1:2];

    fetch_jump_same = fetch_line_write && jump_line_write &&
                      (fetch_btb_idx == jump_btb_idx);
    fetch_branch_same = fetch_line_write && branch_line_write &&
                        (fetch_btb_idx == branch_btb_idx);
    jump_branch_same = jump_line_write && branch_line_write &&
                       (jump_btb_idx == branch_btb_idx);

    // Composed target field for the fetch line: its own static JAL target when
    // it has one, otherwise the resolved target of the jump or branch source
    // that lands on the same index, otherwise the resident target.
    fetch_tgt_next = btb_entry_q[fetch_btb_idx][BTB_TGT_LSB+:BTB_TGT_W];
    if (fetch_target_write)
      fetch_tgt_next = fetch_info_jal_target_i[31:2];
    else if (jump_target_write && fetch_jump_same)
      fetch_tgt_next = jump_target_i[31:2];
    else if (branch_target_write && fetch_branch_same)
      fetch_tgt_next = branch_next_pc_i[31:2];
    fetch_state_next = fetch_info_return_i ? BTB_STATE_RET : BTB_STATE_UNCOND;
    fetch_entry_next = {fetch_info_pc_i[31:BTB_INDEX_W+2], fetch_tgt_next,
                        fetch_state_next};

    // A jump trains both groups: it is unconditional and always has a resolved
    // target on the CDB.
    jump_entry_next = {jump_pc_i[31:BTB_INDEX_W+2], jump_target_i[31:2],
                       jump_is_return_i ? BTB_STATE_RET : BTB_STATE_UNCOND};

    // Only a taken conditional allocates a line, and it is never a return.
    branch_entry_next = {branch_pc_i[31:BTB_INDEX_W+2], branch_next_pc_i[31:2],
                         BTB_STATE_COND};
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (seq_i = 0; seq_i < BTB_ENTRIES; seq_i = seq_i + 1)
        btb_entry_q[seq_i] <= '0; // state 0 = invalid, tag/target clear
    end else begin
      // One write per entry per cycle. The write qualifiers are the *line*
      // group's, because a source whose line loses arbitration either has its
      // target folded into the winning word (fetch against jump/branch) or
      // loses both groups outright (`jump_branch_same` blocks the branch line
      // and its target alike), so the target group needs no separate guard.
      if (fetch_line_write)
        btb_entry_q[fetch_btb_idx] <= fetch_entry_next;
      if (jump_line_write && !fetch_jump_same)
        btb_entry_q[jump_btb_idx] <= jump_entry_next;
      if (branch_line_write && !fetch_branch_same && !jump_branch_same)
        btb_entry_q[branch_btb_idx] <= branch_entry_next;
    end
  end
endmodule
