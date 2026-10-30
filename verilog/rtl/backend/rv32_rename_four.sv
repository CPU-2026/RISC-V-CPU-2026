// Four ordered rename/allocation lanes, unchanged execute/writeback/commit ports.
// Pool and LSQ credits are upstream of the common planner, never fire-dependent.
module rv32_rename_four #(
  parameter int unsigned COMMIT_WIDTH=2,
  parameter int unsigned WRITEBACK_PORTS=2,
  parameter int unsigned LOOKUP_PORTS=5
) (
  input logic clkInput,rstNInput,freezeInput,enableInput,
  input rv32_pkg::decoded_uop_t [3:0] decodedInput,
  input logic [3:0] validInput,
  output logic [3:0] fireOutput,
  output logic [2:0] countOutput,
  input logic [6:0][$clog2(rv32_pkg::ROB_ENTRIES+1)-1:0] rsCreditsInput,
  input logic [$clog2(rv32_pkg::LQ_ENTRIES+1)-1:0] loadCreditsInput,
  input logic [$clog2(rv32_pkg::SQ_ENTRIES+1)-1:0] storeCreditsInput,
  input logic [3:0][$clog2(rv32_pkg::LQ_ENTRIES)-1:0] loadPreviewInput,
  input logic [3:0][$clog2(rv32_pkg::SQ_ENTRIES)-1:0] storePreviewInput,
  output rv32_pkg::rs_allocation_input_t [6:0][3:0] rsOutput,
  output logic [6:0][3:0][3:0] rsAuxOutput,
  output rv32_pkg::load_allocation_input_t [3:0] loadOutput,
  output rv32_pkg::store_allocation_input_t [3:0] storeOutput,
  input rv32_pkg::rat_commit_input_t [COMMIT_WIDTH-1:0] mapCommitInput,
  input rv32_pkg::prf_free_input_t [COMMIT_WIDTH-1:0] freeInput,
  input rv32_pkg::prf_read_input_t [COMMIT_WIDTH+3:0] scalarReadInput,
  output rv32_pkg::prf_read_output_t [COMMIT_WIDTH+3:0] scalarReadOutput,
  output rv32_pkg::rat_read_output_t firstMapOutput,
  output rv32_pkg::rat_rename_output_t firstPreviousOutput,
  output rv32_pkg::phy_tag_t firstFreePhysicalOutput,
  output logic [rv32_pkg::PRF_ENTRIES-1:0] readyVectorOutput,
  input rv32_pkg::cdb_result_t [WRITEBACK_PORTS-1:0] writebackInput,
  input rv32_pkg::rob_completion_t [5:0] completionInput,
  input rv32_pkg::store_completion_output_t storeReadyInput,
  input rv32_pkg::rob_flush_input_t flushInput,
  input rv32_pkg::recovery_step_t recoveryInput,
  input rv32_pkg::rob_lookup_input_t [LOOKUP_PORTS-1:0] lookupInput,
  output rv32_pkg::rob_lookup_output_t [LOOKUP_PORTS-1:0] lookupOutput,
  output rv32_pkg::rob_commit_output_t [COMMIT_WIDTH-1:0] commitOutput,
  output logic [COMMIT_WIDTH-1:0] commitStoreOutput,
  input logic [COMMIT_WIDTH-1:0] commitReadyInput,
  output logic [COMMIT_WIDTH-1:0] commitFireOutput,
  output rv32_pkg::rob_status_output_t statusOutput,
  output logic [$clog2(rv32_pkg::ROB_ENTRIES+1)-1:0] robCountOutput,
  output rv32_pkg::rob_tag_t nextTagOutput,
  output rv32_pkg::rob_replay_narrow_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayNarrowOutput,
  output rv32_pkg::rob_replay_ras_t [rv32_pkg::RECOVERY_WIDTH-1:0] replayRasOutput
);
  import rv32_pkg::*;
  rat_read_input_t [3:0] mapQuery;
  rat_read_output_t [3:0] mapRead;
  logic [3:0][4:0] destinationQuery;
  rat_rename_input_t [3:0] renames;
  rat_rename_output_t [3:0] previous;
  prf_allocation_input_t [3:0] physical;
  rob_allocation_input_t [3:0] allocations;
  rs_allocation_input_t [3:0] base;
  prf_read_input_t [8+COMMIT_WIDTH-1:0] reads;
  prf_read_output_t [8+COMMIT_WIDTH-1:0] values;
  prf_read_output_t [3:0][1:0] sourceValues;
  phy_tag_t [3:0] previewPhysical,allocatedPhysical;
  logic [3:0] previewReady,physicalFire,robFire;
  rob_tag_t [3:0] allocatedTags;
  logic [$clog2(PRF_ENTRIES+1)-1:0] freeCount;
  logic [$clog2(ROB_ENTRIES+1)-1:0] robCredits;
  logic [3:0][$clog2(LQ_ENTRIES)-1:0] loadIndices;
  logic [3:0][$clog2(SQ_ENTRIES)-1:0] storeIndices;
  for(genvar lane=0;lane<4;lane++)begin : g_queries
    assign mapQuery[lane]='{source1Arch:decodedInput[lane].rs1,source2Arch:decodedInput[lane].rs2};
    assign destinationQuery[lane]=decodedInput[lane].rd;
    assign reads[2*lane]='{physicalRegister:mapRead[lane].source1Phy};
    assign reads[2*lane+1]='{physicalRegister:mapRead[lane].source2Phy};
    assign sourceValues[lane][0]=values[2*lane];
    assign sourceValues[lane][1]=values[2*lane+1];
  end
  for(genvar lane=0;lane<COMMIT_WIDTH;lane++)begin : g_retire_reads
    assign reads[8+lane]=scalarReadInput[2+lane];
    assign scalarReadOutput[2+lane]=values[8+lane];
  end
  assign scalarReadOutput[0]=values[0];assign scalarReadOutput[1]=values[1];
  assign scalarReadOutput[COMMIT_WIDTH+2]=values[2];assign scalarReadOutput[COMMIT_WIDTH+3]=values[3];
  assign firstMapOutput=mapRead[0];assign firstPreviousOutput=previous[0];
  assign firstFreePhysicalOutput=previewPhysical[0];
  rv32_rat_lanes #(.LANES(4),.COMMIT_WIDTH(COMMIT_WIDTH)) u_rat (
    .clkInput,.rstNInput,.freezeInput,.readInput(mapQuery),.readOutput(mapRead),
    .destinationArchInput(destinationQuery),.renameInput(renames),.renameOutput(previous),
    .restoreInput('{valid:flushInput.valid,squashTag:flushInput.robTag,headTag:statusOutput.headTag}),
    .recoveryInput,.replayInput(replayNarrowOutput),.commitInput(mapCommitInput)
  );
  rv32_prf_lanes #(.LANES(4),.COMMIT_WIDTH(COMMIT_WIDTH),.READ_PORTS(8+COMMIT_WIDTH),.WRITEBACK_PORTS(WRITEBACK_PORTS)) u_prf (
    .clkInput,.rstNInput,.freezeInput,.allocationInput(physical),.previewReadyOutput(previewReady),
    .previewPhyOutput(previewPhysical),.allocationFireOutput(physicalFire),.allocationPhyOutput(allocatedPhysical),
    .freeInput,.restoreInput('{valid:flushInput.valid,squashTag:flushInput.robTag}),.recoveryInput,
    .restoreCountInput(robCountOutput),.replayInput(replayNarrowOutput),.readInput(reads),.readOutput(values),
    .writebackInput,.readyVectorOutput,.freeCountOutput(freeCount)
  );
  rv32_rob_lanes #(.LANES(4),.COMMIT_WIDTH(COMMIT_WIDTH),.LOOKUP_PORTS(LOOKUP_PORTS)) u_rob (
    .clkInput,.rstNInput,.freezeInput(freezeInput || recoveryInput.active),
    .allocationInput(allocations),.allocationFireOutput(robFire),
    .allocationTagOutput(allocatedTags),.creditsOutput(robCredits),.nextTagOutput,
    .completionInput,.storeReadyInput,.flushInput,.lookupInput,.lookupOutput,
    .commitOutput,.commitStoreOutput,.commitReadyInput,.commitFireOutput,.statusOutput,.countOutput(robCountOutput),
    .replayOffsetInput(recoveryInput.offset),.replayNarrowOutput,.replayRasOutput
  );
  rv32_wide_rename_plan u_plan (
    .enableInput(enableInput && !freezeInput && !flushInput.valid && !recoveryInput.active),
    .validInput,.decodedInput,.mapReadInput(mapRead),.oldDestinationInput(previous),.sourceReadInput(sourceValues),
    .freePhysicalInput(previewPhysical),.physicalCreditsInput(freeCount),.nextRobTagInput(nextTagOutput),
    .robCreditsInput(robCredits),.rsCreditsInput,.loadCreditsInput,.storeCreditsInput,
    .loadSlotInput(loadPreviewInput),.storeSlotInput(storePreviewInput),
    .fireOutput,.issueCountOutput(countOutput),.physicalCountOutput(),.loadCountOutput(),.storeCountOutput(),
    .renameOutput(renames),.physicalOutput(physical),.robOutput(allocations),.rsOutput(base),
    .loadOutput,.storeOutput,.loadIndexOutput(loadIndices),.storeIndexOutput(storeIndices)
  );
  // Local experiment only: every output target is constant after elaboration.
  for (genvar lane=0;lane<4;lane++) begin : g_static_route
    always_comb begin : route_lane
      rsOutput[0][lane]='0;rsOutput[1][lane]='0;rsOutput[2][lane]='0;
      rsOutput[3][lane]='0;rsOutput[4][lane]='0;rsOutput[5][lane]='0;
      rsOutput[6][lane]='0;
      rsAuxOutput[0][lane]='0;rsAuxOutput[1][lane]='0;rsAuxOutput[2][lane]='0;
      rsAuxOutput[3][lane]='0;rsAuxOutput[4][lane]='0;rsAuxOutput[5][lane]='0;
      rsAuxOutput[6][lane]='0;
      rsAuxOutput[0][lane][0]=decodedInput[lane].operation==OP_JAL || decodedInput[lane].operation==OP_JALR;
      case (decodedInput[lane].uopClass)
        UOP_ALU: rsOutput[0][lane]=base[lane];
        UOP_MUL: begin
          rsOutput[1][lane]=base[lane];
          rsOutput[1][lane].useImmediate=0;
        end
        UOP_DIV: begin
          rsOutput[2][lane]=base[lane];
          rsOutput[2][lane].useImmediate=0;
        end
        UOP_BRANCH: rsOutput[3][lane]=base[lane];
        UOP_LOAD: begin
          rsOutput[4][lane]=base[lane];
          rsOutput[4][lane].source2Ready=1;
          rsOutput[4][lane].source2Tag='0;
          rsOutput[4][lane].source2Value='0;
          rsOutput[4][lane].useImmediate=1;
          rsAuxOutput[4][lane]={1'b0,loadIndices[lane]};
        end
        UOP_STORE: begin
          rsOutput[5][lane]=base[lane];
          rsOutput[5][lane].source2Ready=1;
          rsOutput[5][lane].source2Tag='0;
          rsOutput[5][lane].source2Value='0;
          rsOutput[5][lane].useImmediate=1;
          rsAuxOutput[5][lane]={1'b1,storeIndices[lane]};
          rsOutput[6][lane]=base[lane];
          rsOutput[6][lane].source1Ready=base[lane].source2Ready;
          rsOutput[6][lane].source1Tag=base[lane].source2Tag;
          rsOutput[6][lane].source1Value=base[lane].source2Value;
          rsOutput[6][lane].source2Ready=1;
          rsOutput[6][lane].source2Tag='0;
          rsOutput[6][lane].source2Value='0;
          rsOutput[6][lane].useImmediate=0;
          rsAuxOutput[6][lane]={1'b0,storeIndices[lane]};
        end
        default: begin end
      endcase
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if(rstNInput && !freezeInput)begin
    assert(robFire==fireOutput)else $fatal(1,"four rename ROB did not accept common prefix");
    for(int lane=0;lane<4;lane++)begin
      assert(physicalFire[lane]==physical[lane].valid)else $fatal(1,"four rename PRF did not accept destination");
      if(physicalFire[lane])assert(allocatedPhysical[lane]==renames[lane].physicalRegister)
        else $fatal(1,"four rename physical preview rank disagrees");
    end
  end
`endif
endmodule
