// Isolated candidate for rtl/backend/rv32_rename_plan.sv. No new pipeline stage.
// Rank and dependency identities do not depend on admission: an accepted lane
// necessarily has every older lane accepted. Only final payloads use fire.
module rv32_wide_rename_plan #(
  parameter int unsigned LANES=4,
  localparam int unsigned COUNT_W=$clog2(LANES+1)
) (
  input logic enableInput, wholeGroupInput,
  input logic [LANES-1:0] validInput,
  input rv32_pkg::decoded_uop_t [LANES-1:0] decodedInput,
  input rv32_pkg::rat_read_output_t [LANES-1:0] mapReadInput,
  input rv32_pkg::rat_rename_output_t [LANES-1:0] oldDestinationInput,
  input rv32_pkg::prf_read_output_t [LANES-1:0][1:0] sourceReadInput,
  input rv32_pkg::phy_tag_t [LANES-1:0] freePhysicalInput,
  input logic [$clog2(rv32_pkg::PRF_ENTRIES+1)-1:0] physicalCreditsInput,
  input rv32_pkg::rob_tag_t nextRobTagInput,
  input logic [$clog2(rv32_pkg::ROB_ENTRIES+1)-1:0] robCreditsInput,
  input logic [6:0][$clog2(rv32_pkg::ROB_ENTRIES+1)-1:0] rsCreditsInput,
  input logic [$clog2(rv32_pkg::LQ_ENTRIES+1)-1:0] loadCreditsInput,
  input logic [$clog2(rv32_pkg::SQ_ENTRIES+1)-1:0] storeCreditsInput,
  input logic [LANES-1:0][$clog2(rv32_pkg::LQ_ENTRIES)-1:0] loadSlotInput,
  input logic [LANES-1:0][$clog2(rv32_pkg::SQ_ENTRIES)-1:0] storeSlotInput,
  output logic [LANES-1:0] fireOutput,
  output logic [COUNT_W-1:0] issueCountOutput,physicalCountOutput,loadCountOutput,storeCountOutput,
  output rv32_pkg::rat_rename_input_t [LANES-1:0] renameOutput,
  output rv32_pkg::prf_allocation_input_t [LANES-1:0] physicalOutput,
  output rv32_pkg::rob_allocation_input_t [LANES-1:0] robOutput,
  output rv32_pkg::rs_allocation_input_t [LANES-1:0] rsOutput,
  output rv32_pkg::load_allocation_input_t [LANES-1:0] loadOutput,
  output rv32_pkg::store_allocation_input_t [LANES-1:0] storeOutput,
  output logic [LANES-1:0][$clog2(rv32_pkg::LQ_ENTRIES)-1:0] loadIndexOutput,
  output logic [LANES-1:0][$clog2(rv32_pkg::SQ_ENTRIES)-1:0] storeIndexOutput
);
  import rv32_pkg::*;
  logic [LANES-1:0] writesInner,linkInner,loadInner,storeInner,haltInner;
  logic [LANES-1:0] prefixFireInner;
  logic [LANES-1:0] poolMemberInner[7];
  logic [COUNT_W-1:0] physicalRankInner[LANES],loadRankInner[LANES],storeRankInner[LANES];
  phy_tag_t destinationInner[LANES];

  // At most four bits. The explicit pair sums avoid an admission-dependent
  // accumulator and a serial four-input adder chain.
  function automatic logic [COUNT_W-1:0] population(input logic [LANES-1:0] mask);
    logic [3:0] padded;
    logic [2:0] lowPair,highPair;
    padded='0;padded[LANES-1:0]=mask;
    lowPair={2'b0,padded[0]}+{2'b0,padded[1]};
    highPair={2'b0,padded[2]}+{2'b0,padded[3]};
    return COUNT_W'(lowPair+highPair);
  endfunction

  for(genvar lane=0;lane<LANES;lane++)begin : g_classify
    assign writesInner[lane]=decodedInput[lane].writesRd && decodedInput[lane].rd!=0;
    assign linkInner[lane]=decodedInput[lane].operation==OP_JAL || decodedInput[lane].operation==OP_JALR;
    assign haltInner[lane]=decodedInput[lane].halt;
    assign loadInner[lane]=decodedInput[lane].uopClass==UOP_LOAD;
    assign storeInner[lane]=decodedInput[lane].uopClass==UOP_STORE;
    assign poolMemberInner[0][lane]=decodedInput[lane].uopClass==UOP_ALU;
    assign poolMemberInner[1][lane]=decodedInput[lane].uopClass==UOP_MUL;
    assign poolMemberInner[2][lane]=decodedInput[lane].uopClass==UOP_DIV;
    assign poolMemberInner[3][lane]=decodedInput[lane].uopClass==UOP_BRANCH;
    assign poolMemberInner[4][lane]=loadInner[lane];
    assign poolMemberInner[5][lane]=storeInner[lane];
    assign poolMemberInner[6][lane]=storeInner[lane];
  end
  for(genvar lane=0;lane<LANES;lane++)begin : g_prefix
    localparam logic [LANES-1:0] BEFORE=LANES'((1<<lane)-1);
    localparam logic [LANES-1:0] THROUGH=LANES'((1<<(lane+1))-1);
    logic [6:0] poolFits;
    assign physicalRankInner[lane]=population(writesInner & BEFORE);
    assign loadRankInner[lane]=population(loadInner & BEFORE);
    assign storeRankInner[lane]=population(storeInner & BEFORE);
    for(genvar pool=0;pool<7;pool++)begin : g_pool_credit
      assign poolFits[pool]=population(poolMemberInner[pool] & THROUGH)<=rsCreditsInput[pool];
    end
    assign prefixFireInner[lane]=enableInput && ((validInput & THROUGH)==THROUGH) &&
      !(|(haltInner & BEFORE)) && (lane+1<=int'(robCreditsInput)) &&
      population(writesInner & THROUGH)<=physicalCreditsInput && (&poolFits) &&
      population(loadInner & THROUGH)<=loadCreditsInput &&
      population(storeInner & THROUGH)<=storeCreditsInput;
    // Gate BEFORE every allocation payload is formed. Old-IQ operation
    // retains ordinary prefix allocation; only empty-IQ proposals are atomic.
    assign fireOutput[lane]=prefixFireInner[lane] &&
      (!wholeGroupInput || prefixFireInner == validInput);
    assign destinationInner[lane]=writesInner[lane] ? freePhysicalInput[physicalRankInner[lane]] : phy_tag_t'(0);
  end
  assign issueCountOutput=population(fireOutput);
  assign physicalCountOutput=population(fireOutput & writesInner);
  assign loadCountOutput=population(fireOutput & loadInner);
  assign storeCountOutput=population(fireOutput & storeInner);

  for(genvar lane=0;lane<LANES;lane++)begin : g_payload
    logic [LANES-1:0] raw1,raw2,waw,nearest1,nearest2,nearestWaw;
    for(genvar older=0;older<LANES;older++)begin : g_match
      if(older<lane)begin : g_older
        assign raw1[older]=writesInner[older] && decodedInput[lane].usesRs1 &&
          decodedInput[lane].rs1==decodedInput[older].rd;
        assign raw2[older]=writesInner[older] && decodedInput[lane].usesRs2 &&
          decodedInput[lane].rs2==decodedInput[older].rd;
        assign waw[older]=writesInner[older] && decodedInput[lane].rd==decodedInput[older].rd;
      end else begin : g_not_older
        assign raw1[older]=0;assign raw2[older]=0;assign waw[older]=0;
      end
      localparam logic [LANES-1:0] NEWER=~LANES'((1<<(older+1))-1);
      assign nearest1[older]=raw1[older] && !(|(raw1 & NEWER));
      assign nearest2[older]=raw2[older] && !(|(raw2 & NEWER));
      assign nearestWaw[older]=waw[older] && !(|(waw & NEWER));
    end
    always_comb begin : select_payload
      phy_tag_t previous,source1,source2;
      logic ready1,ready2;
      logic [31:0] value1,value2;
      rob_tag_t tag;
      previous=decodedInput[lane].rd==0?'0:oldDestinationInput[lane].previousPhysicalRegister;
      source1=decodedInput[lane].usesRs1 && decodedInput[lane].rs1!=0?mapReadInput[lane].source1Phy:'0;
      source2=decodedInput[lane].usesRs2 && decodedInput[lane].rs2!=0?mapReadInput[lane].source2Phy:'0;
      ready1=!decodedInput[lane].usesRs1 || decodedInput[lane].rs1==0 || sourceReadInput[lane][0].ready;
      ready2=!decodedInput[lane].usesRs2 || decodedInput[lane].rs2==0 || sourceReadInput[lane][1].ready;
      value1=!decodedInput[lane].usesRs1 || decodedInput[lane].rs1==0?'0:sourceReadInput[lane][0].value;
      value2=!decodedInput[lane].usesRs2 || decodedInput[lane].rs2==0?'0:sourceReadInput[lane][1].value;
      // One-hot nearest-writer masks select preview identities directly, never
      // an older lane's gated rename/physical output. The default PRF read is
      // preserved verbatim, including its value when ready is false.
      if(|nearest1)begin source1='0;ready1=0;value1='0;end
      if(|nearest2)begin source2='0;ready2=0;value2='0;end
      if(|nearestWaw)previous='0;
      for(int older=0;older<LANES;older++)begin
        source1|=destinationInner[older] & {$bits(phy_tag_t){nearest1[older]}};
        source2|=destinationInner[older] & {$bits(phy_tag_t){nearest2[older]}};
        previous|=destinationInner[older] & {$bits(phy_tag_t){nearestWaw[older]}};
        ready1|=nearest1[older] && linkInner[older];
        ready2|=nearest2[older] && linkInner[older];
        value1|=(decodedInput[older].programCounter+32'd4) & {32{nearest1[older] && linkInner[older]}};
        value2|=(decodedInput[older].programCounter+32'd4) & {32{nearest2[older] && linkInner[older]}};
      end
      tag=nextRobTagInput+rob_tag_t'(lane);
      renameOutput[lane]='0;physicalOutput[lane]='0;robOutput[lane]='0;rsOutput[lane]='0;
      loadOutput[lane]='0;storeOutput[lane]='0;loadIndexOutput[lane]='0;storeIndexOutput[lane]='0;
      if(fireOutput[lane])begin
        renameOutput[lane]='{valid:writesInner[lane],architecturalRegister:decodedInput[lane].rd,physicalRegister:destinationInner[lane]};
        physicalOutput[lane]='{valid:writesInner[lane],valueValid:linkInner[lane],value:decodedInput[lane].programCounter+32'd4};
        robOutput[lane]='{valid:1'b1,programCounter:decodedInput[lane].programCounter,
          instruction:decodedInput[lane].instruction,writesArchitecturalRegister:writesInner[lane],
          architecturalRegister:decodedInput[lane].rd,newPhysicalRegister:destinationInner[lane],
          oldPhysicalRegister:writesInner[lane]?previous:phy_tag_t'(0),ready:decodedInput[lane].halt,
          isStore:storeInner[lane],storeQueueIndex:storeSlotInput[storeRankInner[lane]],
          isHalt:decodedInput[lane].halt,hasException:1'b0,
          predictedProgramCounter:decodedInput[lane].predictedNextProgramCounter,
          predictorCheckpointId:decodedInput[lane].predictorCheckpointId,
          isReturn:decodedInput[lane].operation==OP_JALR && (decodedInput[lane].rs1==1 || decodedInput[lane].rs1==5)};
        rsOutput[lane]='{valid:1'b1,operation:decodedInput[lane].operation,robTag:tag,
          destinationPhy:destinationInner[lane],source1Ready:ready1,source1Tag:source1,source1Value:value1,
          source2Ready:ready2,source2Tag:source2,source2Value:value2,
          immediate:decodedInput[lane].immediate,programCounter:decodedInput[lane].programCounter,
          predictedProgramCounter:decodedInput[lane].predictedNextProgramCounter,useImmediate:decodedInput[lane].usesImmediate};
        if(loadInner[lane])begin
          loadIndexOutput[lane]=loadSlotInput[loadRankInner[lane]];
          loadOutput[lane]='{valid:1'b1,robTag:tag,destinationPhy:destinationInner[lane],
            size:decodedInput[lane].memorySize,isUnsigned:decodedInput[lane].memoryUnsigned};
        end
        if(storeInner[lane])begin
          storeIndexOutput[lane]=storeSlotInput[storeRankInner[lane]];
          storeOutput[lane]='{valid:1'b1,robTag:tag,size:decodedInput[lane].memorySize,dataReady:1'b0,dataTag:'0,dataValue:'0};
        end
      end
    end
  end
`ifndef SYNTHESIS
  initial assert(LANES==1 || LANES==2 || LANES==4)else $fatal(1,"wide rename lane count");
`endif
endmodule
