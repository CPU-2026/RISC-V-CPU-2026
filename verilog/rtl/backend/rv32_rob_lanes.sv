// Array allocation ROB for ordered rename1/2/4 and retirement1/2/4.
// Credits and nextTag are OLD-state only; execution bandwidth is independent.
module rv32_rob_lanes #(
  parameter int unsigned LANES=4,
  parameter int unsigned DEPTH=rv32_pkg::ROB_ENTRIES,
  parameter int unsigned COMMIT_WIDTH=2,
  parameter int unsigned LOOKUP_PORTS=5,
  parameter bit SPLIT_LOAD_LOOKUP=1'b0
) (
  input logic clkInput, rstNInput, freezeInput,
  input rv32_pkg::rob_allocation_input_t [LANES-1:0] allocationInput,
  output logic [LANES-1:0] allocationFireOutput,
  output rv32_pkg::rob_tag_t [LANES-1:0] allocationTagOutput,
  output logic [$clog2(DEPTH+1)-1:0] creditsOutput,
  output rv32_pkg::rob_tag_t nextTagOutput,
  input rv32_pkg::rob_completion_t [5:0] completionInput,
  input rv32_pkg::store_completion_output_t storeReadyInput,
  input rv32_pkg::rob_flush_input_t flushInput,
  input rv32_pkg::rob_lookup_input_t [LOOKUP_PORTS-1:0] lookupInput,
  input rv32_pkg::rob_lookup_input_t lookupLoadInput,
  output rv32_pkg::rob_lookup_output_t lookupLoadOutput,
  output rv32_pkg::rob_lookup_output_t [LOOKUP_PORTS-1:0] lookupOutput,
  output rv32_pkg::rob_commit_output_t [COMMIT_WIDTH-1:0] commitOutput,
  output logic [COMMIT_WIDTH-1:0] commitStoreOutput,
  input logic [COMMIT_WIDTH-1:0] commitReadyInput,
  output logic [COMMIT_WIDTH-1:0] commitFireOutput,
  output rv32_pkg::rob_status_output_t statusOutput,
  output logic [$clog2(DEPTH+1)-1:0] countOutput,
  input rv32_pkg::rob_tag_t replayOffsetInput,
  output rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayNarrowOutput,
  output rv32_pkg::rob_replay_ras_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayRasOutput
);
  import rv32_pkg::*;
  localparam int SLOT_W=$clog2(DEPTH);
  localparam int COUNT_W=$clog2(DEPTH+1);
  if ((LANES!=1 && LANES!=2 && LANES!=4) || (COMMIT_WIDTH!=1 && COMMIT_WIDTH!=2 && COMMIT_WIDTH!=4)) begin : g_invalid_width
    initial $fatal(1,"array ROB allocation/commit width unsupported");
  end
  if (DEPTH<LANES || DEPTH>ROB_ENTRIES || (DEPTH&(DEPTH-1))!=0) begin : g_invalid_depth
    initial $fatal(1,"array ROB depth must be a supported power of two");
  end
  rob_allocation_input_t payloadInner[DEPTH];
  rob_tag_t tagInner[DEPTH];
  logic [DEPTH-1:0] validInner, readyInner;
  rob_tag_t headInner, tailInner;
  logic [COUNT_W-1:0] countInner, allocatedCountInner, committedCountInner;

  // Shared decode stays INSIDE each port. Lookup results must not create a
  // coarse whole-array dependency into the independent retirement read path.
  localparam int SHARED_READ_PORTS=COMMIT_WIDTH+LOOKUP_PORTS;
  rob_allocation_input_t commitPayloadInner[COMMIT_WIDTH];
  rob_tag_t commitTagInner[COMMIT_WIDTH];
  logic [COMMIT_WIDTH-1:0] commitValidInner, commitReadyInner;
  // Consecutive retirement lanes use each low-bit bank once. Read a single
  // row from each bank, then rotate into program order. Invalid-row payloads
  // are preserved too; valid/ready/commit acceptance remain separate consumers.
  typedef struct packed {
    rob_allocation_input_t payload;
    rob_tag_t tag;
    logic valid;
    logic ready;
  } commit_read_t;
  commit_read_t commitReadInner[COMMIT_WIDTH];
  if (DEPTH>=COMMIT_WIDTH && COMMIT_WIDTH>1) begin : g_commit_banked
    localparam int BANK_W=$clog2(COMMIT_WIDTH);
    localparam int ROWS=DEPTH/COMMIT_WIDTH;
    localparam int ROW_W=(ROWS>1)?$clog2(ROWS):1;
    logic [SLOT_W-1:0] baseSlot;
    logic [BANK_W-1:0] firstBank;
    logic [ROW_W-1:0] baseRow;
    assign baseSlot=SLOT_W'(headInner);
    assign firstBank=BANK_W'(baseSlot);
    assign baseRow=ROW_W'(baseSlot>>BANK_W);
    for (genvar bank=0;bank<COMMIT_WIDTH;bank++) begin : g_bank
      logic [ROW_W-1:0] selectedCommitRow;
      logic [ROWS-1:0] selectRow;
      commit_read_t selected;
      assign selectedCommitRow=baseRow+ROW_W'(BANK_W'(bank)<firstBank);
      for (genvar row=0;row<ROWS;row++) begin : g_decode
        assign selectRow[row]=(selectedCommitRow & ROW_W'(ROWS-1))==ROW_W'(row);
      end
      always_comb begin
        selected='0;
        for (int row=0;row<ROWS;row++) begin
          selected|=commit_read_t'{payload:payloadInner[row*COMMIT_WIDTH+bank],
            tag:tagInner[row*COMMIT_WIDTH+bank],valid:validInner[row*COMMIT_WIDTH+bank],
            ready:readyInner[row*COMMIT_WIDTH+bank]} & {$bits(commit_read_t){selectRow[row]}};
        end
      end
    end
    for (genvar stage=0;stage<BANK_W;stage++) begin : g_rotate
      logic [COMMIT_WIDTH-1:0][$bits(commit_read_t)-1:0] value;
      for (genvar lane=0;lane<COMMIT_WIDTH;lane++) begin : g_lane
        if (stage==0) begin : g_first
          assign value[lane]=firstBank[stage] ?
            g_bank[(lane+(1<<stage))%COMMIT_WIDTH].selected : g_bank[lane].selected;
        end else begin : g_later
          assign value[lane]=firstBank[stage] ?
            g_rotate[stage-1].value[(lane+(1<<stage))%COMMIT_WIDTH] : g_rotate[stage-1].value[lane];
        end
      end
    end
    for (genvar lane=0;lane<COMMIT_WIDTH;lane++) begin : g_result
      assign commitReadInner[lane]=commit_read_t'(g_rotate[BANK_W-1].value[lane]);
    end
  end else begin : g_commit_small
    for (genvar lane=0;lane<COMMIT_WIDTH;lane++) begin : g_lane
      logic [SLOT_W-1:0] slot;
      logic [DEPTH-1:0] selectRow;
      commit_read_t selected;
      assign slot=SLOT_W'(headInner+rob_tag_t'(lane));
      for (genvar row=0;row<DEPTH;row++) begin : g_decode
        assign selectRow[row]=slot==SLOT_W'(row);
      end
      always_comb begin
        selected='0;
        for (int row=0;row<DEPTH;row++) begin
          selected|=commit_read_t'{payload:payloadInner[row],tag:tagInner[row],
            valid:validInner[row],ready:readyInner[row]} & {$bits(commit_read_t){selectRow[row]}};
        end
      end
      assign commitReadInner[lane]=selected;
    end
  end
  for (genvar lane=0;lane<COMMIT_WIDTH;lane++) begin : g_commit_read_outputs
    assign commitPayloadInner[lane]=commitReadInner[lane].payload;
    assign commitTagInner[lane]=commitReadInner[lane].tag;
    assign commitValidInner[lane]=commitReadInner[lane].valid;
    assign commitReadyInner[lane]=commitReadInner[lane].ready;
  end
  for (genvar portIndex=COMMIT_WIDTH;portIndex<SHARED_READ_PORTS;portIndex++) begin : g_shared_read
    logic [SLOT_W-1:0] slot;
    logic [DEPTH-1:0] selectRow;
    rob_allocation_input_t payload;
    rob_tag_t tag;
    logic valid,ready;
    if (portIndex<COMMIT_WIDTH) begin : g_commit_slot
      assign slot=SLOT_W'(headInner+rob_tag_t'(portIndex));
      assign commitPayloadInner[portIndex]=payload;
      assign commitTagInner[portIndex]=tag;
      assign commitValidInner[portIndex]=valid;
      assign commitReadyInner[portIndex]=ready;
    end else begin : g_lookup_slot
      if(SPLIT_LOAD_LOOKUP && portIndex==COMMIT_WIDTH+2)begin:g_load
        assign slot=lookupLoadInput.robTag[SLOT_W-1:0];
      end else begin:g_registered
        assign slot=lookupInput[portIndex-COMMIT_WIDTH].robTag[SLOT_W-1:0];
      end
    end
    for (genvar row=0;row<DEPTH;row++) begin : g_decode
      assign selectRow[row]=slot==SLOT_W'(row);
    end
    always_comb begin
      payload='0;
      tag='0;
      valid=1'b0;
      ready=1'b0;
      for (int row=0;row<DEPTH;row++) begin
        payload|=payloadInner[row]&{$bits(rob_allocation_input_t){selectRow[row]}};
        tag|=tagInner[row]&{ROB_TAG_W{selectRow[row]}};
        valid|=validInner[row] && selectRow[row];
        ready|=readyInner[row] && selectRow[row];
      end
    end
  end

  assign nextTagOutput=tailInner;
  assign creditsOutput=(!freezeInput && !flushInput.valid)?COUNT_W'(DEPTH)-countInner:'0;
  assign countOutput=countInner;
  assign statusOutput='{empty:countInner==0,full:countInner==COUNT_W'(DEPTH),headTag:headInner};
  always_comb begin : allocation_prefix
    bit open;
    open=!freezeInput && !flushInput.valid;
    allocatedCountInner='0;
    for (int lane=0;lane<LANES;lane++) begin
      allocationTagOutput[lane]=tailInner+rob_tag_t'(lane);
      allocationFireOutput[lane]=open && allocationInput[lane].valid && int'(countInner)+lane<DEPTH;
      open=allocationFireOutput[lane];
      allocatedCountInner+=COUNT_W'(allocationFireOutput[lane]);
    end
  end
  always_comb begin : commit_candidates
    bit open;
    open=!freezeInput;
    for (int lane=0;lane<COMMIT_WIDTH;lane++) begin
      commitOutput[lane]='0;
      commitOutput[lane].valid=open && int'(countInner)>lane && commitValidInner[lane] &&
        commitTagInner[lane]==headInner+rob_tag_t'(lane) && commitReadyInner[lane] &&
        (!flushInput.valid || rob_is_older(commitTagInner[lane],flushInput.robTag));
      commitOutput[lane].robTag=commitTagInner[lane];
      commitOutput[lane].programCounter=commitPayloadInner[lane].programCounter;
      commitOutput[lane].instruction=commitPayloadInner[lane].instruction;
      commitOutput[lane].writesArchitecturalRegister=commitPayloadInner[lane].writesArchitecturalRegister;
      commitOutput[lane].architecturalRegister=commitPayloadInner[lane].architecturalRegister;
      commitOutput[lane].newPhysicalRegister=commitPayloadInner[lane].newPhysicalRegister;
      commitOutput[lane].oldPhysicalRegister=commitPayloadInner[lane].oldPhysicalRegister;
      commitOutput[lane].storeQueueIndex=commitPayloadInner[lane].storeQueueIndex;
      commitOutput[lane].isHalt=commitPayloadInner[lane].isHalt;
      commitStoreOutput[lane]=commitPayloadInner[lane].isStore;
      open=commitOutput[lane].valid && !commitPayloadInner[lane].isHalt;
    end
  end
  always_comb begin : commit_acceptance
    bit open;
    open=1;
    committedCountInner='0;
    for (int lane=0;lane<COMMIT_WIDTH;lane++) begin
      commitFireOutput[lane]=open && commitOutput[lane].valid && commitReadyInput[lane];
      open=commitFireOutput[lane];
      committedCountInner+=COUNT_W'(commitFireOutput[lane]);
    end
  end
  for (genvar portIndex=0;portIndex<LOOKUP_PORTS;portIndex++) begin : g_lookup
    if(SPLIT_LOAD_LOOKUP && portIndex==2)begin:g_load
      assign lookupOutput[portIndex]='0;
    end else begin:g_registered
    always_comb begin
      lookupOutput[portIndex]='0;
      lookupOutput[portIndex].valid=g_shared_read[COMMIT_WIDTH+portIndex].valid && g_shared_read[COMMIT_WIDTH+portIndex].tag==lookupInput[portIndex].robTag;
      if (portIndex<2 || portIndex==5) begin
        lookupOutput[portIndex].programCounter=g_shared_read[COMMIT_WIDTH+portIndex].payload.programCounter;
        lookupOutput[portIndex].predictedProgramCounter=g_shared_read[COMMIT_WIDTH+portIndex].payload.predictedProgramCounter;
        lookupOutput[portIndex].predictorCheckpointId=g_shared_read[COMMIT_WIDTH+portIndex].payload.predictorCheckpointId;
        lookupOutput[portIndex].isReturn=g_shared_read[COMMIT_WIDTH+portIndex].payload.isReturn;
      end
    end
    end
  end
  if(SPLIT_LOAD_LOOKUP)begin:g_load_lookup_output
    // Check stored low bits against the constant row using OLD state. The
    // late query only supplies a row decode and the remaining identity bits;
    // no selected full-tag mux followed by an equality comparator is needed.
    // Keep the low-bit check: even arbitrary malformed stored tags must not hit.
    logic [DEPTH-1:0] rowMatch;
    for (genvar row=0;row<DEPTH;row++) begin : g_live_row
      assign rowMatch[row]=validInner[row] && tagInner[row][SLOT_W-1:0]==SLOT_W'(row) &&
        lookupLoadInput.robTag[SLOT_W-1:0] == SLOT_W'(row) &&
        tagInner[row][ROB_TAG_W-1:SLOT_W] == lookupLoadInput.robTag[ROB_TAG_W-1:SLOT_W];
    end
    assign lookupLoadOutput='{valid:|rowMatch,
      programCounter:'0,predictedProgramCounter:'0,predictorCheckpointId:'0,isReturn:1'b0};
  end else begin:g_no_load_lookup_output
    assign lookupLoadOutput='0;
  end
  // Consecutive recovery lanes visit each low-bit bank exactly once. Select
  // one row per bank, then rotate the bank order with log2(RECOVERY_WIDTH)
  // stages. Never gate on validInner: canceled payloads are still recycled.
  typedef struct packed {
    rob_tag_t robTag;
    logic [4:0] archRd;
    phy_tag_t newPhy;
    logic [31:0] programCounter;
    logic [19:0] instruction;
  } replay_read_t;
  replay_read_t replayReadInner[RECOVERY_WIDTH];
  if (DEPTH>=RECOVERY_WIDTH && RECOVERY_WIDTH>1 &&
      (RECOVERY_WIDTH&(RECOVERY_WIDTH-1))==0) begin : g_replay_banked
    localparam int BANK_W=$clog2(RECOVERY_WIDTH);
    localparam int ROWS=DEPTH/RECOVERY_WIDTH;
    localparam int ROW_W=(ROWS>1)?$clog2(ROWS):1;
    logic [SLOT_W-1:0] baseSlot;
    logic [BANK_W-1:0] firstBank;
    logic [ROW_W-1:0] baseRow;
    assign baseSlot=SLOT_W'(headInner+replayOffsetInput);
    assign firstBank=BANK_W'(baseSlot);
    assign baseRow=ROW_W'(baseSlot>>BANK_W);
    for (genvar bank=0;bank<RECOVERY_WIDTH;bank++) begin : g_bank
      logic [ROW_W-1:0] selectedRow;
      logic [ROWS-1:0] selectRow;
      replay_read_t selected;
      assign selectedRow=baseRow+ROW_W'(BANK_W'(bank)<firstBank);
      for (genvar row=0;row<ROWS;row++) begin : g_decode
        // For ROWS=1 the addition may be one; the physical slot still wraps.
        assign selectRow[row]=(selectedRow & ROW_W'(ROWS-1))==ROW_W'(row);
      end
      always_comb begin
        selected='0;
        for (int row=0;row<ROWS;row++) begin
          selected|=replay_read_t'{robTag:tagInner[row*RECOVERY_WIDTH+bank],
            archRd:payloadInner[row*RECOVERY_WIDTH+bank].architecturalRegister,
            newPhy:payloadInner[row*RECOVERY_WIDTH+bank].newPhysicalRegister,
            programCounter:payloadInner[row*RECOVERY_WIDTH+bank].programCounter,
            instruction:payloadInner[row*RECOVERY_WIDTH+bank].instruction[19:0]} &
            {$bits(replay_read_t){selectRow[row]}};
        end
      end
    end
    for (genvar stage=0;stage<BANK_W;stage++) begin : g_rotate
      // A separate net per generated stage avoids a coarse whole-array
      // dependency in native/converted frontends; this is still acyclic wiring.
      logic [RECOVERY_WIDTH-1:0][$bits(replay_read_t)-1:0] value;
      for (genvar lane=0;lane<RECOVERY_WIDTH;lane++) begin : g_lane
        if (stage==0) begin : g_first
          assign value[lane]=firstBank[stage] ?
            g_bank[(lane+(1<<stage))%RECOVERY_WIDTH].selected : g_bank[lane].selected;
        end else begin : g_later
          assign value[lane]=firstBank[stage] ?
            g_rotate[stage-1].value[(lane+(1<<stage))%RECOVERY_WIDTH] : g_rotate[stage-1].value[lane];
        end
      end
    end
    for (genvar lane=0;lane<RECOVERY_WIDTH;lane++) begin : g_result
      assign replayReadInner[lane]=replay_read_t'(g_rotate[BANK_W-1].value[lane]);
    end
  end else begin : g_replay_small
    // Preserve the parameterized interface when a beat revisits physical rows.
    for (genvar lane=0;lane<RECOVERY_WIDTH;lane++) begin : g_lane
      logic [SLOT_W-1:0] slot;
      logic [DEPTH-1:0] selectRow;
      replay_read_t selected;
      assign slot=SLOT_W'(headInner+replayOffsetInput+rob_tag_t'(lane));
      for (genvar row=0;row<DEPTH;row++) begin : g_decode
        assign selectRow[row]=slot==SLOT_W'(row);
      end
      always_comb begin
        selected='0;
        for (int row=0;row<DEPTH;row++) begin
          selected|=replay_read_t'{robTag:tagInner[row],
            archRd:payloadInner[row].architecturalRegister,
            newPhy:payloadInner[row].newPhysicalRegister,
            programCounter:payloadInner[row].programCounter,
            instruction:payloadInner[row].instruction[19:0]} &
            {$bits(replay_read_t){selectRow[row]}};
        end
      end
      assign replayReadInner[lane]=selected;
    end
  end
  for (genvar lane=0;lane<RECOVERY_WIDTH;lane++) begin : g_replay
    assign replayNarrowOutput[lane]='{robTag:replayReadInner[lane].robTag,
      archRd:replayReadInner[lane].archRd,newPhy:replayReadInner[lane].newPhy};
    assign replayRasOutput[lane]='{robTag:replayReadInner[lane].robTag,
      programCounter:replayReadInner[lane].programCounter,
      opcode:replayReadInner[lane].instruction[6:0],rd:replayReadInner[lane].instruction[11:7],
      funct3:replayReadInner[lane].instruction[14:12],rs1:replayReadInner[lane].instruction[19:15]};
  end
  // Wide write-data selection is grouped instead of replicated per row. Lane
  // `lane` can only ever target rows whose low log2(LANES) bits equal
  // (tailInner+lane)'s, so adding the low bits of tailInner to that lane index
  // maps each row group to exactly one candidate lane. One payload mux per group
  // then serves the DEPTH/LANES rows that group owns, while every row keeps its
  // own write enable. Selection count is DEPTH copies -> LANES copies; this is a
  // structural repetition count, not a measured area claim.
  localparam int GROUP_W=(LANES>1)?$clog2(LANES):1;
  logic [GROUP_W-1:0] tailGroup;
  logic [GROUP_W-1:0] laneGroup[LANES];
  rob_allocation_input_t writeGroupPayload[LANES];
  rob_tag_t writeGroupTag[LANES];
  logic [SLOT_W-1:0] writeGroupSlot[LANES];
  logic writeGroupFire[LANES];
  if (LANES>1) begin : g_tail_group
    assign tailGroup=tailInner[GROUP_W-1:0];
  end else begin : g_tail_group_single
    assign tailGroup='0;
  end
  for (genvar lane=0;lane<LANES;lane++) begin : g_lane_group
    assign laneGroup[lane]=tailGroup+GROUP_W'(lane);
  end
  for (genvar group=0;group<LANES;group++) begin : g_write_group
    always_comb begin
      writeGroupPayload[group]='0;
      writeGroupTag[group]='0;
      writeGroupSlot[group]='0;
      writeGroupFire[group]=1'b0;
      for (int lane=0;lane<LANES;lane++) begin
        if (laneGroup[lane]==GROUP_W'(group)) begin
          writeGroupPayload[group]=allocationInput[lane];
          writeGroupTag[group]=allocationTagOutput[lane];
          writeGroupSlot[group]=SLOT_W'(allocationTagOutput[lane]);
          writeGroupFire[group]=allocationFireOutput[lane];
        end
      end
    end
  end
  for (genvar row=0;row<DEPTH;row++) begin : g_row
    logic writeHit;
    logic completed, retired, storeReady;
    if (DEPTH==ROB_ENTRIES) begin
      assign storeReady=storeReadyInput.readyMask[row] && storeReadyInput.epochMask[row]==tagInner[row][ROB_TAG_W-1];
    end else begin
      assign storeReady=storeReadyInput.readyMask[tagInner[row][ROB_TAG_W-2:0]] &&
        storeReadyInput.epochMask[tagInner[row][ROB_TAG_W-2:0]]==tagInner[row][ROB_TAG_W-1];
    end
    // Rows in one group share the group payload; the compare only keeps the
    // single row that this allocation actually targets.
    assign writeHit=writeGroupFire[row&(LANES-1)] && writeGroupSlot[row&(LANES-1)]==SLOT_W'(row);
    always_comb begin
      completed=0;retired=0;
      if (validInner[row] && (!flushInput.valid || rob_is_older(tagInner[row],flushInput.robTag))) begin
        completed=payloadInner[row].isStore && storeReady;
        for (int portIndex=0;portIndex<6;portIndex++)
          completed|=completionInput[portIndex].valid && completionInput[portIndex].robTag==tagInner[row];
      end
      for (int lane=0;lane<COMMIT_WIDTH;lane++)
        retired|=commitFireOutput[lane] && SLOT_W'(headInner+rob_tag_t'(lane))==SLOT_W'(row);
    end
    always_ff @(posedge clkInput or negedge rstNInput) begin
      if (!rstNInput) begin
        validInner[row]<=0;readyInner[row]<=0;tagInner[row]<='0;payloadInner[row]<='0;
      end else if (!freezeInput) begin
        if (flushInput.valid && validInner[row] && rob_is_younger(tagInner[row],flushInput.robTag)) validInner[row]<=0;
        if (retired) validInner[row]<=0;
        if (writeHit) begin
          validInner[row]<=1;tagInner[row]<=writeGroupTag[row&(LANES-1)];payloadInner[row]<=writeGroupPayload[row&(LANES-1)];
          readyInner[row]<=writeGroupPayload[row&(LANES-1)].ready || writeGroupPayload[row&(LANES-1)].isHalt;
        end else if (completed) readyInner[row]<=1;
      end
    end
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin headInner<='0;tailInner<='0;countInner<='0;end
    else if (!freezeInput) begin
      headInner<=headInner+rob_tag_t'(committedCountInner);
      if (flushInput.valid) begin
        tailInner<=flushInput.robTag+rob_tag_t'(1);
        countInner<=COUNT_W'(flushInput.robTag+rob_tag_t'(1)-headInner)-committedCountInner;
      end else begin
        tailInner<=tailInner+rob_tag_t'(allocatedCountInner);
        countInner<=countInner-committedCountInner+allocatedCountInner;
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !freezeInput) begin
    assert (int'(countInner)<=DEPTH && int'(allocatedCountInner)<=int'(creditsOutput))
      else $fatal(1,"array ROB old-state credit overflow");
    if (!flushInput.valid)
      for (int lane=1;lane<LANES;lane++) assert (!allocationInput[lane].valid || allocationInput[lane-1].valid)
        else $fatal(1,"array ROB allocation must be a contiguous prefix");
    else assert (int'(rob_tag_t'(flushInput.robTag+rob_tag_t'(1)-headInner))<=int'(countInner))
      else $fatal(1,"array ROB squash outside live window");
  end
`endif
endmodule
