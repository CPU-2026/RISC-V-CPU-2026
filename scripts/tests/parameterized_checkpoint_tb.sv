module tb_parameterized_checkpoint;
  import rv32_pkg::*;
  logic clkInput=0,rstNInput=0,freezeInput=0,secondAcceptedInput=0;
  logic [2:0] acceptedCountInput=0;
  checkpoint_input_t checkpointInput;
  direction_context_t queryContextInput,branchContextOutput;
  checkpoint_output_t checkpointOutput;
  bpu_ckpt_id_t nextCheckpointIdOutput;
  rv32_bpu_checkpoint #(.FETCH_WIDTH(FETCH_WIDTH)) dut(.*);
  logic [7:0] history[BPU_CKPT_ENTRIES];
  direction_context_t contextRows[BPU_CKPT_ENTRIES];
  int nextId=0,checks=0,wraps=0,freezes=0,squashes=0;
  task automatic check_all;
    for(int row=0;row<BPU_CKPT_ENTRIES;row++)begin
      checkpointInput.branchCheckpointId=bpu_ckpt_id_t'(row);
      checkpointInput.squash.checkpointId=bpu_ckpt_id_t'(BPU_CKPT_ENTRIES-1-row);#1;
      assert(nextCheckpointIdOutput==bpu_ckpt_id_t'(nextId) && checkpointOutput.nextCheckpointId==bpu_ckpt_id_t'(nextId) &&
        checkpointOutput.branchHistory==history[row] && branchContextOutput===contextRows[row] &&
        checkpointOutput.recoveryHistory==history[BPU_CKPT_ENTRIES-1-row])
        else $fatal(1,"parameter checkpoint oracle capacity=%0d row=%0d next=%0d expected=%0d",BPU_CKPT_ENTRIES,row,nextCheckpointIdOutput,nextId);
      checks++;
    end
  endtask
  task automatic step;
    int count;
    if(!freezeInput)begin
      if(checkpointInput.fetchAccepted && !checkpointInput.squash.valid)begin
        count=FETCH_WIDTH==4?int'(acceptedCountInput):(FETCH_WIDTH==2 && secondAcceptedInput?2:1);
        for(int lane=0;lane<count;lane++)begin
          history[(nextId+lane)%BPU_CKPT_ENTRIES]=checkpointInput.globalHistory;
          contextRows[(nextId+lane)%BPU_CKPT_ENTRIES]=queryContextInput;
        end
        if(nextId+count>=BPU_CKPT_ENTRIES)wraps++;
        nextId=(nextId+count)%BPU_CKPT_ENTRIES;
      end
      if(checkpointInput.squash.valid)begin nextId=(int'(checkpointInput.squash.checkpointId)+1)%BPU_CKPT_ENTRIES;squashes++;end
    end else freezes++;
    #2;clkInput=1;#2;clkInput=0;#2;
  endtask
  initial begin
    int rounds;
    if(!$value$plusargs("CHECKPOINT_TEST_ROUNDS=%d",rounds))rounds=3*BPU_CKPT_ENTRIES;
    assert(rounds==3*BPU_CKPT_ENTRIES)else $fatal(1,"parameter checkpoint stimulus changed");
    checkpointInput='0;queryContextInput='0;
    for(int row=0;row<BPU_CKPT_ENTRIES;row++)begin history[row]=0;contextRows[row]='0;end
    #2;clkInput=1;#2;clkInput=0;#2;rstNInput=1;check_all();
    for(int n=0;n<rounds;n++)begin
      checkpointInput.fetchAccepted=1;checkpointInput.globalHistory=8'(n*37+3);queryContextInput=direction_context_t'(n);
      acceptedCountInput=3'(1+n%4);secondAcceptedInput=1'(n&1);freezeInput=n%17==0;step();freezeInput=0;
      checkpointInput.fetchAccepted=0;check_all();
    end
    // Squash wins over a simultaneous fetch and may wrap back to CID zero.
    checkpointInput.fetchAccepted=1;checkpointInput.squash.valid=1;
    checkpointInput.squash.checkpointId=bpu_ckpt_id_t'(BPU_CKPT_ENTRIES-1);step();
    checkpointInput='0;check_all();
    assert(nextId==0 && wraps>0 && freezes>0 && squashes==1)else $fatal(1,"parameter checkpoint missing coverage");
    $display("PASS parameter checkpoint FW=%0d capacity=%0d checks=%0d wraps=%0d",FETCH_WIDTH,BPU_CKPT_ENTRIES,checks,wraps);$finish;
  end
endmodule
