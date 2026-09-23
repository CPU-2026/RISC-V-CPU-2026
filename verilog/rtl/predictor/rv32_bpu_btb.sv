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
//   tag + state : fetch lineInput  > jump lineInput    > branch lineInput
//   target      : fetch static JAL > jump target > branch target
//
// A fetch JALR/RET lineInput carries no static target, so it must not hide a
// resolved target from a lower-priority source landing on the same lineInput; that
// case folds the lower-priority target into the fetch word. Because the entry
// is a single 56-bit register, the two groups are composed into one word
// before the flop, which keeps `fetch > jump > branch` per entry at one write
// per entry per cycle.
module rv32_bpu_btb #(
  parameter int unsigned BTB_ENTRIES = 64
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,

  input  logic [31:0]            queryPcInput,
  output rv32_pkg::btb_lookup_output_t lookupOutput,
  input  rv32_pkg::btb_training_input_t trainingInput
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

  logic [BTB_ENTRY_W-1:0] btbEntryInner [BTB_ENTRIES];

  logic [31:0] queryP2Inner;
  logic [BTB_INDEX_W-1:0] queryBtbIdxInner;
  logic [BTB_ENTRY_W-1:0] queryEntryInner;
  logic [BTB_STATE_W-1:0] queryStateInner;

  logic fetchLineWriteInner, fetchTargetWriteInner;
  logic [BTB_INDEX_W-1:0] fetchBtbIdxInner;
  logic jumpLineWriteInner, jumpTargetWriteInner;
  logic [BTB_INDEX_W-1:0] jumpBtbIdxInner;
  logic branchLineWriteInner, branchTargetWriteInner;
  logic [BTB_INDEX_W-1:0] branchBtbIdxInner;
  logic fetchJumpSameInner, fetchBranchSameInner, jumpBranchSameInner;

  logic [BTB_TGT_W-1:0] fetchTgtNext;
  logic [BTB_STATE_W-1:0] fetchStateNext;
  logic [BTB_ENTRY_W-1:0] fetchEntryNext, jumpEntryNext, branchEntryNext;

  integer seqIndexInner;

  always_comb begin
    queryP2Inner = queryPcInput >> 2;
    queryBtbIdxInner = queryP2Inner[BTB_INDEX_W-1:0];
    queryEntryInner = btbEntryInner[queryBtbIdxInner];
    queryStateInner = queryEntryInner[BTB_STATE_LSB+:BTB_STATE_W];

    lookupOutput.hit = (queryStateInner != BTB_STATE_INVALID) &&
                      (queryEntryInner[BTB_TAG_LSB+:BTB_TAG_W] == queryPcInput[31:BTB_INDEX_W+2]);
    // The state field carries both flags, and only a writer that also sets the
    // tag can leave a non-invalid state behind, so these stay ungated by the
    // hit - exactly the flag reads the separate-flag table used to expose.
    lookupOutput.unconditional = (queryStateInner == BTB_STATE_UNCOND) ||
                         (queryStateInner == BTB_STATE_RET);
    lookupOutput.isReturn = (queryStateInner == BTB_STATE_RET);
    // target[1:0] is not stored; architectural targets are 4-byte aligned.
    lookupOutput.target = {queryEntryInner[BTB_TGT_LSB+:BTB_TGT_W], 2'b00};
  end

  always_comb begin
    fetchLineWriteInner = trainingInput.fetchValid;
    fetchTargetWriteInner = trainingInput.fetchValid && !trainingInput.isReturn &&
                         trainingInput.jalTargetValid;
    fetchBtbIdxInner = trainingInput.fetchProgramCounter[BTB_INDEX_W+1:2];

    jumpLineWriteInner = trainingInput.jumpValid;
    jumpTargetWriteInner = trainingInput.jumpValid;
    jumpBtbIdxInner = trainingInput.jumpProgramCounter[BTB_INDEX_W+1:2];

    branchLineWriteInner = trainingInput.branch.valid && trainingInput.branch.taken;
    branchTargetWriteInner = branchLineWriteInner;
    branchBtbIdxInner = trainingInput.branch.programCounter[BTB_INDEX_W+1:2];

    fetchJumpSameInner = fetchLineWriteInner && jumpLineWriteInner &&
                      (fetchBtbIdxInner == jumpBtbIdxInner);
    fetchBranchSameInner = fetchLineWriteInner && branchLineWriteInner &&
                        (fetchBtbIdxInner == branchBtbIdxInner);
    jumpBranchSameInner = jumpLineWriteInner && branchLineWriteInner &&
                       (jumpBtbIdxInner == branchBtbIdxInner);

    // Composed target field for the fetch lineInput: its own static JAL target when
    // it has one, otherwise the resolved target of the jump or branch source
    // that lands on the same index, otherwise the resident target.
    fetchTgtNext = btbEntryInner[fetchBtbIdxInner][BTB_TGT_LSB+:BTB_TGT_W];
    if (fetchTargetWriteInner)
      fetchTgtNext = trainingInput.jalTarget[31:2];
    else if (jumpTargetWriteInner && fetchJumpSameInner)
      fetchTgtNext = trainingInput.jumpTarget[31:2];
    else if (branchTargetWriteInner && fetchBranchSameInner)
      fetchTgtNext = trainingInput.branch.nextProgramCounter[31:2];
    fetchStateNext = trainingInput.isReturn ? BTB_STATE_RET : BTB_STATE_UNCOND;
    fetchEntryNext = {trainingInput.fetchProgramCounter[31:BTB_INDEX_W+2], fetchTgtNext,
                        fetchStateNext};

    // A jump trains both groups: it is unconditional and always has a resolved
    // target on the CDB.
    jumpEntryNext = {trainingInput.jumpProgramCounter[31:BTB_INDEX_W+2], trainingInput.jumpTarget[31:2],
                       trainingInput.jumpIsReturn ? BTB_STATE_RET : BTB_STATE_UNCOND};

    // Only a taken conditional allocates a lineInput, and it is never a return.
    branchEntryNext = {trainingInput.branch.programCounter[31:BTB_INDEX_W+2], trainingInput.branch.nextProgramCounter[31:2],
                         BTB_STATE_COND};
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (seqIndexInner = 0; seqIndexInner < BTB_ENTRIES; seqIndexInner = seqIndexInner + 1)
        btbEntryInner[seqIndexInner] <= '0; // state 0 = invalid, tag/target clear
    end else begin
      // One write per entry per cycle. The write qualifiers are the *lineInput*
      // group's, because a source whose lineInput loses arbitration either has its
      // target folded into the winning word (fetch against jump/branch) or
      // loses both groups outright (`jumpBranchSameInner` blocks the branch lineInput
      // and its target alike), so the target group needs no separate guard.
      if (fetchLineWriteInner)
        btbEntryInner[fetchBtbIdxInner] <= fetchEntryNext;
      if (jumpLineWriteInner && !fetchJumpSameInner)
        btbEntryInner[jumpBtbIdxInner] <= jumpEntryNext;
      if (branchLineWriteInner && !fetchBranchSameInner && !jumpBranchSameInner)
        btbEntryInner[branchBtbIdxInner] <= branchEntryNext;
    end
  end
endmodule
