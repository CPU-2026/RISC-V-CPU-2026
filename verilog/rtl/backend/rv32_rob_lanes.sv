// Array allocation ROB for ordered rename1/2/4 and retirement1/2/4.
// Credits and nextTag are OLD-state only; execution bandwidth is independent.
module rv32_rob_lanes #(
  parameter int unsigned LANES=4,
  parameter int unsigned DEPTH=rv32_pkg::ROB_ENTRIES,
  parameter int unsigned COMMIT_WIDTH=2,
  parameter int unsigned LOOKUP_PORTS=5
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
      logic [SLOT_W-1:0] slot;
      slot=SLOT_W'(headInner+rob_tag_t'(lane));
      commitOutput[lane]='0;
      commitOutput[lane].valid=open && int'(countInner)>lane && validInner[slot] &&
        tagInner[slot]==headInner+rob_tag_t'(lane) && readyInner[slot] &&
        (!flushInput.valid || rob_is_older(tagInner[slot],flushInput.robTag));
      commitOutput[lane].robTag=tagInner[slot];
      commitOutput[lane].programCounter=payloadInner[slot].programCounter;
      commitOutput[lane].instruction=payloadInner[slot].instruction;
      commitOutput[lane].writesArchitecturalRegister=payloadInner[slot].writesArchitecturalRegister;
      commitOutput[lane].architecturalRegister=payloadInner[slot].architecturalRegister;
      commitOutput[lane].newPhysicalRegister=payloadInner[slot].newPhysicalRegister;
      commitOutput[lane].oldPhysicalRegister=payloadInner[slot].oldPhysicalRegister;
      commitOutput[lane].storeQueueIndex=payloadInner[slot].storeQueueIndex;
      commitOutput[lane].isHalt=payloadInner[slot].isHalt;
      commitStoreOutput[lane]=payloadInner[slot].isStore;
      open=commitOutput[lane].valid && !payloadInner[slot].isHalt;
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
    logic [SLOT_W-1:0] slot;
    assign slot=lookupInput[portIndex].robTag[SLOT_W-1:0];
    always_comb begin
      lookupOutput[portIndex]='0;
      lookupOutput[portIndex].valid=validInner[slot] && tagInner[slot]==lookupInput[portIndex].robTag;
      if (portIndex<2 || portIndex==5) begin
        lookupOutput[portIndex].programCounter=payloadInner[slot].programCounter;
        lookupOutput[portIndex].predictedProgramCounter=payloadInner[slot].predictedProgramCounter;
        lookupOutput[portIndex].predictorCheckpointId=payloadInner[slot].predictorCheckpointId;
        lookupOutput[portIndex].isReturn=payloadInner[slot].isReturn;
      end
    end
  end
  for (genvar lane=0;lane<RECOVERY_WIDTH;lane++) begin : g_replay
    logic [SLOT_W-1:0] slot;
    assign slot=SLOT_W'(headInner+replayOffsetInput+rob_tag_t'(lane));
    // Invalidated suffix payloads intentionally survive until recovery ends.
    assign replayNarrowOutput[lane]='{robTag:tagInner[slot],archRd:payloadInner[slot].architecturalRegister,
      newPhy:payloadInner[slot].newPhysicalRegister};
    assign replayRasOutput[lane]='{robTag:tagInner[slot],programCounter:payloadInner[slot].programCounter,
      opcode:payloadInner[slot].instruction[6:0],rd:payloadInner[slot].instruction[11:7],
      funct3:payloadInner[slot].instruction[14:12],rs1:payloadInner[slot].instruction[19:15]};
  end
  for (genvar row=0;row<DEPTH;row++) begin : g_row
    logic [LANES-1:0] writeHit;
    rob_allocation_input_t writePayload;
    rob_tag_t writeTag;
    logic completed, retired, storeReady;
    if (DEPTH==ROB_ENTRIES) begin
      assign storeReady=storeReadyInput.readyMask[row] && storeReadyInput.epochMask[row]==tagInner[row][ROB_TAG_W-1];
    end else begin
      assign storeReady=storeReadyInput.readyMask[tagInner[row][ROB_TAG_W-2:0]] &&
        storeReadyInput.epochMask[tagInner[row][ROB_TAG_W-2:0]]==tagInner[row][ROB_TAG_W-1];
    end
    for (genvar lane=0;lane<LANES;lane++) begin : g_write_hit
      assign writeHit[lane]=allocationFireOutput[lane] && SLOT_W'(allocationTagOutput[lane])==SLOT_W'(row);
    end
    always_comb begin
      writePayload='0;writeTag='0;
      for (int lane=0;lane<LANES;lane++) begin
        writePayload|=allocationInput[lane]&{$bits(rob_allocation_input_t){writeHit[lane]}};
        writeTag|=allocationTagOutput[lane]&{ROB_TAG_W{writeHit[lane]}};
      end
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
        if (|writeHit) begin
          validInner[row]<=1;tagInner[row]<=writeTag;payloadInner[row]<=writePayload;
          readyInner[row]<=writePayload.ready || writePayload.isHalt;
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
