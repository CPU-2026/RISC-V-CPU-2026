// Ordered allocation prefix. Credits and preview identities must be independent
// of this cycle's fire; all stateful consumers accept this same instruction mask.
module rv32_wide_rename_plan #(
  parameter int unsigned LANES=4,
  localparam int unsigned COUNT_W=$clog2(LANES+1)
) (
  input logic enableInput,
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
  always_comb begin : prefix_plan
    int usedPhysical,usedRob,usedLoad,usedStore,pool;
    int usedRs[7];
    logic open,canIssue,writes,isLink;
    phy_tag_t destination,previous,source1,source2;
    logic ready1,ready2;
    logic [31:0] value1,value2;
    rob_tag_t tag;
    fireOutput='0;renameOutput='0;physicalOutput='0;robOutput='0;
    rsOutput='0;loadOutput='0;storeOutput='0;loadIndexOutput='0;storeIndexOutput='0;
    usedPhysical=0;usedRob=0;usedLoad=0;usedStore=0;
    for(int p=0;p<7;p++)usedRs[p]=0;
    open=enableInput;pool=-1;canIssue=0;writes=0;isLink=0;
    destination='0;previous='0;source1='0;source2='0;
    ready1=0;ready2=0;value1='0;value2='0;tag='0;
    for(int lane=0;lane<LANES;lane++)begin
      writes=decodedInput[lane].writesRd && decodedInput[lane].rd!=0;
      isLink=decodedInput[lane].operation==OP_JAL || decodedInput[lane].operation==OP_JALR;
      pool=-1;
      case(decodedInput[lane].uopClass)
        UOP_ALU:pool=0;
        UOP_MUL:pool=1;
        UOP_DIV:pool=2;
        UOP_BRANCH:pool=3;
        UOP_LOAD:pool=4;
        UOP_STORE:pool=5;
        default:pool=-1;
      endcase
      canIssue=open && validInput[lane] && usedRob<int'(robCreditsInput) &&
        (!writes || usedPhysical<int'(physicalCreditsInput));
      if(pool>=0)canIssue=canIssue && usedRs[pool]<int'(rsCreditsInput[pool]);
      if(decodedInput[lane].uopClass==UOP_LOAD)
        canIssue=canIssue && usedLoad<int'(loadCreditsInput);
      if(decodedInput[lane].uopClass==UOP_STORE)
        canIssue=canIssue && usedStore<int'(storeCreditsInput) && usedRs[6]<int'(rsCreditsInput[6]);
      fireOutput[lane]=canIssue;
      open=fireOutput[lane] && !decodedInput[lane].halt;
      destination=(writes && usedPhysical<LANES)?freePhysicalInput[usedPhysical]:'0;
      previous=decodedInput[lane].rd==0?'0:oldDestinationInput[lane].previousPhysicalRegister;
      source1=decodedInput[lane].usesRs1 && decodedInput[lane].rs1!=0?mapReadInput[lane].source1Phy:'0;
      source2=decodedInput[lane].usesRs2 && decodedInput[lane].rs2!=0?mapReadInput[lane].source2Phy:'0;
      ready1=!decodedInput[lane].usesRs1 || decodedInput[lane].rs1==0 || sourceReadInput[lane][0].ready;
      ready2=!decodedInput[lane].usesRs2 || decodedInput[lane].rs2==0 || sourceReadInput[lane][1].ready;
      value1=!decodedInput[lane].usesRs1 || decodedInput[lane].rs1==0?'0:sourceReadInput[lane][0].value;
      value2=!decodedInput[lane].usesRs2 || decodedInput[lane].rs2==0?'0:sourceReadInput[lane][1].value;
      for(int older=0;older<LANES;older++)begin
        if(older<lane && renameOutput[older].valid)begin
          if(decodedInput[lane].usesRs1 && decodedInput[lane].rs1==decodedInput[older].rd)begin
            source1=renameOutput[older].physicalRegister;
            ready1=physicalOutput[older].valueValid;
            value1=ready1?physicalOutput[older].value:'0;
          end
          if(decodedInput[lane].usesRs2 && decodedInput[lane].rs2==decodedInput[older].rd)begin
            source2=renameOutput[older].physicalRegister;
            ready2=physicalOutput[older].valueValid;
            value2=ready2?physicalOutput[older].value:'0;
          end
          if(decodedInput[lane].rd==decodedInput[older].rd)
            previous=renameOutput[older].physicalRegister;
        end
      end
      tag=nextRobTagInput+rob_tag_t'(usedRob);
      if(canIssue)begin
        renameOutput[lane]='{valid:writes,architecturalRegister:decodedInput[lane].rd,physicalRegister:destination};
        physicalOutput[lane]='{valid:writes,valueValid:isLink,value:decodedInput[lane].programCounter+32'd4};
        robOutput[lane]='{valid:1'b1,programCounter:decodedInput[lane].programCounter,
          instruction:decodedInput[lane].instruction,writesArchitecturalRegister:writes,
          architecturalRegister:decodedInput[lane].rd,newPhysicalRegister:destination,
          oldPhysicalRegister:writes?previous:phy_tag_t'(0),ready:decodedInput[lane].halt,
          isStore:decodedInput[lane].uopClass==UOP_STORE,
          storeQueueIndex:usedStore<LANES?storeSlotInput[usedStore]:3'b0,
          isHalt:decodedInput[lane].halt,hasException:1'b0,
          predictedProgramCounter:decodedInput[lane].predictedNextProgramCounter,
          predictorCheckpointId:decodedInput[lane].predictorCheckpointId,
          isReturn:decodedInput[lane].operation==OP_JALR &&
            (decodedInput[lane].rs1==1 || decodedInput[lane].rs1==5)};
        rsOutput[lane]='{valid:1'b1,operation:decodedInput[lane].operation,robTag:tag,
          destinationPhy:destination,source1Ready:ready1,source1Tag:source1,source1Value:value1,
          source2Ready:ready2,source2Tag:source2,source2Value:value2,
          immediate:decodedInput[lane].immediate,programCounter:decodedInput[lane].programCounter,
          predictedProgramCounter:decodedInput[lane].predictedNextProgramCounter,
          useImmediate:decodedInput[lane].usesImmediate};
        if(decodedInput[lane].uopClass==UOP_LOAD)begin
          loadIndexOutput[lane]=loadSlotInput[usedLoad];
          loadOutput[lane]='{valid:1'b1,robTag:tag,destinationPhy:destination,
            size:decodedInput[lane].memorySize,isUnsigned:decodedInput[lane].memoryUnsigned};
        end
        if(decodedInput[lane].uopClass==UOP_STORE)begin
          storeIndexOutput[lane]=storeSlotInput[usedStore];
          storeOutput[lane]='{valid:1'b1,robTag:tag,size:decodedInput[lane].memorySize,
            dataReady:1'b0,dataTag:'0,dataValue:'0};
        end
        usedRob++;
        if(writes)usedPhysical++;
        if(pool>=0)usedRs[pool]++;
        if(decodedInput[lane].uopClass==UOP_LOAD)usedLoad++;
        if(decodedInput[lane].uopClass==UOP_STORE)begin usedStore++;usedRs[6]++;end
      end
    end
    issueCountOutput=COUNT_W'(usedRob);physicalCountOutput=COUNT_W'(usedPhysical);
    loadCountOutput=COUNT_W'(usedLoad);storeCountOutput=COUNT_W'(usedStore);
  end
`ifndef SYNTHESIS
  initial assert(LANES==1 || LANES==2 || LANES==4)else $fatal(1,"wide rename lane count");
`endif
endmodule
