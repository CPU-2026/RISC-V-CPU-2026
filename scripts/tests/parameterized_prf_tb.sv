// Independent value/ready and abstract FIFO oracle, including non-power-of-two
// physical capacities. Exercise all public reads, not just ready destinations.
module tb_parameterized_prf;
  import rv32_pkg::*;
  localparam int LANES=ISSUE_WIDTH, PORTS=3, COMMIT=4;
  logic clkInput=0,rstNInput=0,freezeInput=0;
  prf_allocation_input_t [LANES-1:0] allocationInput;
  prf_free_input_t [COMMIT-1:0] freeInput;
  prf_restore_input_t restoreInput;
  recovery_step_t recoveryInput;
  logic [$clog2(ROB_ENTRIES+1)-1:0] restoreCountInput;
  rob_replay_narrow_t [RECOVERY_WIDTH-1:0] replayInput;
  prf_read_input_t [PRF_ENTRIES-1:0] readInput;
  cdb_result_t [PORTS-1:0] writebackInput;
  logic [LANES-1:0] previewReadyOutput,allocationFireOutput;
  phy_tag_t [LANES-1:0] previewPhyOutput,allocationPhyOutput;
  prf_read_output_t [PRF_ENTRIES-1:0] readOutput;
  logic [PRF_ENTRIES-1:0] readyVectorOutput;
  logic [$clog2(PRF_ENTRIES+1)-1:0] freeCountOutput;
  rv32_prf_lanes #(.LANES(LANES),.PRF_DEPTH(PRF_ENTRIES),.ROB_DEPTH(ROB_ENTRIES),
    .WRITEBACK_PORTS(PORTS),.COMMIT_WIDTH(COMMIT),.READ_PORTS(PRF_ENTRIES)) dut(.*);
  for(genvar p=0;p<PRF_ENTRIES;p++)assign readInput[p].physicalRegister=phy_tag_t'(p);
  int fifo[PRF_ENTRIES],freeCount,owned[PRF_ENTRIES],ownedCount,allocated[ROB_ENTRIES];
  logic [31:0] values[PRF_ENTRIES];
  bit ready[PRF_ENTRIES];
  int checks=0,allocations=0,releases=0,freezes=0,recoveries=0;
  logic [31:0] seed=32'h57bc1049;
  function automatic logic [31:0] random_word;
    seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;
  endfunction
  task automatic clear_inputs;
    allocationInput='0;freeInput='0;restoreInput='0;recoveryInput='0;
    restoreCountInput=0;replayInput='0;writebackInput='0;freezeInput=0;
  endtask
  task automatic check_values;
    #2;
    assert(int'(freeCountOutput)==freeCount)else $fatal(1,"parameter PRF free count got=%0d expected=%0d",freeCountOutput,freeCount);
    for(int p=0;p<PRF_ENTRIES;p++)
      assert(readOutput[p].value===values[p] && readOutput[p].ready==ready[p] && readyVectorOutput[p]==ready[p])
        else $fatal(1,"parameter PRF value/ready tag=%0d got=%h ready=%b expected=%h ready=%b",p,readOutput[p].value,readOutput[p].ready,values[p],ready[p]);
    checks++;
  endtask
  task automatic append_free(input int physical);
    for(int p=0;p<freeCount;p++)assert(fifo[p]!=physical)else $fatal(1,"parameter PRF oracle duplicate release");
    fifo[freeCount]=physical;freeCount++;releases++;
  endtask
  task automatic step;
    int used,physical;
    bit enabled,expected;
    check_values();used=0;enabled=!freezeInput && !restoreInput.valid && !recoveryInput.active;
    for(int lane=0;lane<LANES;lane++)begin
      expected=enabled && freeCount>lane;
      assert(previewReadyOutput[lane]==expected && previewPhyOutput[lane]==(expected?phy_tag_t'(fifo[lane]):phy_tag_t'(0)))
        else $fatal(1,"parameter PRF preview identity/rank");
      expected=enabled && allocationInput[lane].valid && used<freeCount;
      assert(allocationFireOutput[lane]==expected && allocationPhyOutput[lane]==(expected?phy_tag_t'(fifo[used]):phy_tag_t'(0)))
        else $fatal(1,"parameter PRF allocation identity/rank");
      if(expected)begin
        physical=fifo[used];values[physical]=allocationInput[lane].value;ready[physical]=allocationInput[lane].valueValid;
        owned[ownedCount]=physical;ownedCount++;used++;allocations++;
      end
    end
    if(!freezeInput)begin
      // Logical FIFO removal, unrelated to the implementation's padded pointer.
      for(int p=used;p<freeCount;p++)fifo[p-used]=fifo[p];freeCount-=used;
      for(int portIndex=0;portIndex<PORTS;portIndex++)if(writebackInput[portIndex].valid && writebackInput[portIndex].phyTag!=0)begin
        physical=int'(writebackInput[portIndex].phyTag);values[physical]=writebackInput[portIndex].value;ready[physical]=1;
      end
      if(recoveryInput.active)begin
        recoveries++;
        for(int k=0;k<RECOVERY_WIDTH;k++)begin
          int age;
          age=(int'(replayInput[k].robTag)-int'(recoveryInput.squashTag)+2*ROB_ENTRIES)%(2*ROB_ENTRIES);
          if(int'(recoveryInput.offset)+k<int'(recoveryInput.liveCount) &&
             int'(recoveryInput.offset)+k<ROB_ENTRIES &&
             replayInput[k].robTag==recoveryInput.nextTag+rob_tag_t'(k) &&
             age>0 && age<ROB_ENTRIES && replayInput[k].newPhy!=0)append_free(int'(replayInput[k].newPhy));
        end
      end else if(!restoreInput.valid)begin
        for(int lane=0;lane<COMMIT;lane++)if(freeInput[lane].valid && freeInput[lane].physicalRegister!=0)
          append_free(int'(freeInput[lane].physicalRegister));
      end
    end else freezes++;
    clkInput=1;#2;clkInput=0;#2;check_values();
  endtask
  task automatic reset_all;
    clear_inputs();rstNInput=0;#2;clkInput=1;#2;clkInput=0;#2;
    freeCount=PRF_ENTRIES-ARCH_REGS;ownedCount=0;
    for(int p=0;p<PRF_ENTRIES;p++)begin fifo[p]=p+ARCH_REGS;values[p]=0;ready[p]=p<ARCH_REGS;end
    rstNInput=1;check_values();
  endtask
  initial begin
    reset_all();
    // All rows, P0, duplicate WB priority, freeze immediately after a write.
    for(int p=0;p<PRF_ENTRIES;p++)begin
      clear_inputs();for(int portIndex=0;portIndex<PORTS;portIndex++)
        writebackInput[portIndex]='{valid:1'b1,phyTag:phy_tag_t'(p),value:32'(p*16+portIndex)};
      step();freezeInput=1;writebackInput[2].value=32'hbadbad;step();clear_inputs();step();
    end
    reset_all();
    for(int n=0;n<1500;n++)begin
      clear_inputs();
      for(int lane=0;lane<LANES;lane++)allocationInput[lane]='{valid:1'(random_word()),valueValid:1'(random_word()),value:random_word()};
      for(int portIndex=0;portIndex<PORTS;portIndex++)
        writebackInput[portIndex]='{valid:1'b1,phyTag:phy_tag_t'(random_word()%PRF_ENTRIES),value:random_word()};
      if(n%13==0)freezeInput=1;
      if(!freezeInput)begin
        int returning;
        returning=int'(random_word()%(COMMIT+1));if(returning>ownedCount)returning=ownedCount;
        for(int lane=0;lane<returning;lane++)freeInput[lane]='{valid:1'b1,physicalRegister:phy_tag_t'(owned[lane])};
        for(int p=returning;p<ownedCount;p++)owned[p-returning]=owned[p];ownedCount-=returning;
      end
      step();
    end
    reset_all();
    // Full ROB payload replay across the tag epoch boundary, then release the
    // retained squash destination. Extra PRF capacity remains in the free FIFO.
    for(int n=0;n<ROB_ENTRIES/LANES;n++)begin
      clear_inputs();#2;
      for(int lane=0;lane<LANES;lane++)begin
        allocated[n*LANES+lane]=int'(previewPhyOutput[lane]);
        allocationInput[lane]='{valid:1'b1,valueValid:1'b1,value:32'(n*LANES+lane)};
      end
      step();
    end
    clear_inputs();restoreInput='{valid:1'b1,squashTag:rob_tag_t'(2*ROB_ENTRIES-4)};restoreCountInput=ROB_ENTRIES;step();
    for(int beat=0;beat<RECOVERY_BEATS;beat++)begin
      clear_inputs();recoveryInput.active=1;recoveryInput.offset=rob_tag_t'(beat*RECOVERY_WIDTH);
      recoveryInput.liveCount=rob_tag_t'(ROB_ENTRIES);recoveryInput.squashTag=rob_tag_t'(2*ROB_ENTRIES-4);
      recoveryInput.nextTag=rob_tag_t'(2*ROB_ENTRIES-4+beat*RECOVERY_WIDTH);
      for(int k=0;k<RECOVERY_WIDTH;k++)begin
        replayInput[k].robTag=recoveryInput.nextTag+rob_tag_t'(k);
        replayInput[k].newPhy=phy_tag_t'(allocated[beat*RECOVERY_WIDTH+k]);
      end
      if(beat==1)begin freezeInput=1;step();freezeInput=0;end
      step();
    end
    clear_inputs();freeInput[0]='{valid:1'b1,physicalRegister:phy_tag_t'(allocated[0])};step();clear_inputs();step();
    assert(freeCount==PRF_ENTRIES-ARCH_REGS && allocations>ROB_ENTRIES && releases>0 && freezes>0 && recoveries==4)
      else $fatal(1,"parameter PRF missing coverage");
    reset_all();$display("PASS parameter PRF ISSUE=%0d ROB=%0d PRF=%0d checks=%0d allocated=%0d released=%0d freezes=%0d",LANES,ROB_ENTRIES,PRF_ENTRIES,checks,allocations,releases,freezes);$finish;
  end
endmodule
