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
// aligned instruction targets are guaranteed by the input contract), so it is reconstructed as zero.
//
// Three training sources share the table and keep the fixed priority
// `fetch predecode > jump CDB > conditional BRU`. They train two field groups
// that used to be independent write ports:
//
//   tag + state : fetch lineInput  > jump lineInput    > branch lineInput
//   target      : fetch static JAL > jump target > branch target
//
// A fetch JALR/RET carries no static target. Tag/state and target therefore
// arbitrate independently PER ENTRY. A missing target write holds the resident
// field directly, without an extra indexed target read/merge/writeback port.
module rv32_bpu_btb #(
  parameter int unsigned BTB_ENTRIES = 64
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input logic freezeInput,

  input  logic [31:0]            queryPcInput,
  output rv32_pkg::btb_lookup_output_t lookupOutput,
  input  rv32_pkg::btb_training_input_t trainingInput
);
  localparam int unsigned BTB_INDEX_W = BTB_ENTRIES > 1 ? $clog2(BTB_ENTRIES) : 1;
  localparam int unsigned BTB_STORAGE_ENTRIES = BTB_ENTRIES > 0 ? BTB_ENTRIES : 1;

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

  logic [BTB_ENTRY_W-1:0] btbEntryInner [BTB_STORAGE_ENTRIES];

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
  logic [BTB_STATE_W-1:0] fetchStateNext;

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

    fetchStateNext = trainingInput.isReturn ? BTB_STATE_RET : BTB_STATE_UNCOND;
  end

  for (genvar row = 0; row < BTB_STORAGE_ENTRIES; row++) begin : g_entry_write
    always_ff @(posedge clkInput or negedge rstNInput) begin
      if (!rstNInput) btbEntryInner[row] <= '0;
      else if (!freezeInput) begin
        if (fetchLineWriteInner && fetchBtbIdxInner == BTB_INDEX_W'(row)) begin
          btbEntryInner[row][BTB_TAG_LSB+:BTB_TAG_W] <= trainingInput.fetchProgramCounter[31:BTB_INDEX_W+2];
          btbEntryInner[row][BTB_STATE_LSB+:BTB_STATE_W] <= fetchStateNext;
        end else if (jumpLineWriteInner && jumpBtbIdxInner == BTB_INDEX_W'(row)) begin
          btbEntryInner[row][BTB_TAG_LSB+:BTB_TAG_W] <= trainingInput.jumpProgramCounter[31:BTB_INDEX_W+2];
          btbEntryInner[row][BTB_STATE_LSB+:BTB_STATE_W] <= trainingInput.jumpIsReturn ? BTB_STATE_RET : BTB_STATE_UNCOND;
        end else if (branchLineWriteInner && branchBtbIdxInner == BTB_INDEX_W'(row)) begin
          btbEntryInner[row][BTB_TAG_LSB+:BTB_TAG_W] <= trainingInput.branch.programCounter[31:BTB_INDEX_W+2];
          btbEntryInner[row][BTB_STATE_LSB+:BTB_STATE_W] <= BTB_STATE_COND;
        end
        // A target-less fetch must not suppress a lower-priority resolved
        // target at this index. Different indices still update in parallel.
        if (fetchTargetWriteInner && fetchBtbIdxInner == BTB_INDEX_W'(row))
          btbEntryInner[row][BTB_TGT_LSB+:BTB_TGT_W] <= trainingInput.jalTarget[31:2];
        else if (jumpTargetWriteInner && jumpBtbIdxInner == BTB_INDEX_W'(row))
          btbEntryInner[row][BTB_TGT_LSB+:BTB_TGT_W] <= trainingInput.jumpTarget[31:2];
        else if (branchTargetWriteInner && branchBtbIdxInner == BTB_INDEX_W'(row))
          btbEntryInner[row][BTB_TGT_LSB+:BTB_TGT_W] <= trainingInput.branch.nextProgramCounter[31:2];
      end
    end
  end
`ifndef SYNTHESIS
  initial begin
    assert (BTB_ENTRIES >= 2 && (BTB_ENTRIES & (BTB_ENTRIES - 1)) == 0 && BTB_TAG_W >= 1)
      else $fatal(1, "BPU BTB parameter must be power-of-two >=2 with a nonempty PC tag");
  end
`endif
endmodule
