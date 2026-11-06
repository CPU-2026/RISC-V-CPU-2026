// Public-port scoreboard. No DUT state is used to predict hits or replacements.
module icache_configuration_case #(
  parameter int FW=4, SETS=4, WAYS=4
)(output bit done);
  import rv32_pkg::*;
  logic clkInput=0,rstNInput=0,freezeInput=0,flushInput=0,secondInput=0;
  logic [31:0] predecodeAddressInput=0,secondInstructionOutput;
  icache_fetch_hint_t predecodeOutput;
  icache_cpu_request_input_t cpuRequestInput;
  logic cpuReqReadyOutput,cpuRspReadyInput=0;
  icache_cpu_response_output_t cpuResponseOutput;
  cache_line_request_output_t memRequestOutput;
  logic memReqReadyInput=1,memRspReadyOutput,memFlushOutput;
  icache_line_response_input_t memResponseInput;
  logic [127:0] packetInstructionsOutput;
  rv32_icache #(.SETS(SETS),.WAYS(WAYS),.FETCH_WIDTH(FW)) dut(.*);
  bit present[SETS][WAYS];
  int lines[SETS][WAYS], tree[SETS][3];
  int accesses=0,hits=0,misses=0,evictions=0,stalls=0,pipelines=0,forwards=0;
  logic [31:0] seed=32'h3891b2c7;
  function automatic logic [31:0] random_word;
    seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;
  endfunction
  function automatic logic [31:0] rom(input logic [31:0] address);
    if (((address>>2) ^ (address>>8)) % 7 == 3) return 32'h00000063;
    return (((address>>2) ^ (address>>11)) & 32'hfff)<<20 | 32'h00000093;
  endfunction
  task automatic tick;#2;clkInput=1;#2;clkInput=0;#2;endtask
  task automatic clear_inputs;
    cpuRequestInput='0;memResponseInput='0;cpuRspReadyInput=0;
    freezeInput=0;flushInput=0;secondInput=0;memReqReadyInput=1;
  endtask
  task automatic reset_model;
    for(int s=0;s<SETS;s++)begin
      for(int w=0;w<WAYS;w++)begin present[s][w]=0;lines[s][w]=0;end
      for(int b=0;b<3;b++)tree[s][b]=0;
    end
  endtask
  function automatic int lookup(input int lineNumber);
    lookup=-1;
    for(int w=0;w<WAYS;w++)if(present[lineNumber%SETS][w] && lines[lineNumber%SETS][w]==lineNumber)lookup=w;
  endfunction
  function automatic int victim(input int row);
    int choice;
    choice=0;
    if(WAYS==2)choice=1-tree[row][0];
    if(WAYS==4)begin
      if(tree[row][0]==1)choice=1-tree[row][1];
      else choice=2+1-tree[row][2];
    end
    for(int w=WAYS-1;w>=0;w--)if(!present[row][w])choice=w;
    return choice;
  endfunction
  task automatic touch(input int row,input int way);
    if(WAYS==2)tree[row][0]=way;
    if(WAYS==4)begin
      tree[row][0]=way/2;
      if(way<2)tree[row][1]=way%2;else tree[row][2]=way%2;
    end
  endtask
  task automatic check_packet(input logic [31:0] address,input logic [31:0] predicted,input bpu_ckpt_id_t cid);
    logic [127:0] expected;
    expected='0;
    for(int lane=0;lane<FW;lane++)if(int'(address[5:2])+lane<16)expected[32*lane+:32]=rom(address+32'(lane*4));
    #2;assert(cpuResponseOutput.valid && cpuResponseOutput.address==address &&
      cpuResponseOutput.predictedProgramCounter==predicted && cpuResponseOutput.predictorCheckpointId==cid &&
      cpuResponseOutput.instruction==rom(address) && packetInstructionsOutput===expected)
      else $fatal(1,"parameter ICache packet FW=%0d S=%0d W=%0d pc=%h got=%h expected=%h",FW,SETS,WAYS,address,packetInstructionsOutput,expected);
    if(secondInput)assert(secondInstructionOutput==expected[63:32])else $fatal(1,"parameter ICache second word");
  endtask
  task automatic access(input logic [31:0] address,input int holdCycles);
    int way,lineNumber,row;
    logic [3:0] expectedHints,actualHints;
    logic [31:0] predicted;
    bpu_ckpt_id_t cid;
    clear_inputs();lineNumber=int'(address>>6);row=lineNumber%SETS;way=lookup(lineNumber);
    predecodeAddressInput=address;#2;expectedHints='0;
    for(int lane=0;lane<FW;lane++)if(FW>=2 && way>=0 && int'(address[5:2])+lane<16)
      expectedHints[lane]=rom(address+32'(lane*4))==32'h63;
    actualHints={predecodeOutput.fourthControl,predecodeOutput.thirdControl,predecodeOutput.secondControl,predecodeOutput.firstControl};
    assert(predecodeOutput.hit==(FW>=2 && way>=0) && actualHints==expectedHints)
      else $fatal(1,"parameter ICache metadata FW=%0d S=%0d W=%0d pc=%h hit=%0d expectedWay=%0d hints=%h expected=%h",FW,SETS,WAYS,address,predecodeOutput.hit,way,actualHints,expectedHints);
    predicted=address^32'h92345000;cid=bpu_ckpt_id_t'(accesses);
    secondInput=FW>=2 && way>=0 && address[5:2]<15 && rom(address)!=32'h63;
    cpuRequestInput='{valid:1'b1,address:address,predictedProgramCounter:predicted,predictorCheckpointId:cid};#2;
    // Memory backpressure cannot accidentally accept either hits or misses.
    memReqReadyInput=0;#2;assert(!cpuReqReadyOutput && !memRequestOutput.valid)else $fatal(1,"parameter ICache admission backpressure");
    memReqReadyInput=1;#2;
    assert(cpuReqReadyOutput && memRequestOutput.valid==(way<0))else $fatal(1,"parameter ICache hit/miss request");
    if(way<0)assert(memRequestOutput.address==(address&32'hffffffc0))else $fatal(1,"parameter ICache line address");
    tick();cpuRequestInput.valid=0;
    if(way<0)begin
      misses++;#2;assert(!cpuResponseOutput.valid)else $fatal(1,"parameter ICache phantom response");
      // A wrong line must not steal a request or populate metadata.
      memResponseInput='{valid:1'b1,address:(address&32'hffffffc0)^32'h10000000,data:'0};#2;
      assert(!memRspReadyOutput)else $fatal(1,"parameter ICache wrong-line fill accepted");tick();
      memResponseInput.address=address&32'hffffffc0;
      for(int w=0;w<16;w++)memResponseInput.data[32*w+:32]=rom((address&32'hffffffc0)+32'(w*4));
      freezeInput=1;#2;assert(!memRspReadyOutput)else $fatal(1,"parameter ICache frozen fill accepted");tick();freezeInput=0;
      #2;assert(memRspReadyOutput)else $fatal(1,"parameter ICache fill blocked");tick();memResponseInput='0;
      way=victim(row);if(present[row][way])evictions++;
      present[row][way]=1;lines[row][way]=lineNumber;
    end else hits++;
    touch(row,way);
    for(int n=0;n<=holdCycles;n++)begin
      check_packet(address,predicted,cid);
      if(n<holdCycles)begin
        freezeInput=1;flushInput=1'(n&1);cpuRequestInput.address=address^32'h10000000;
        tick();freezeInput=0;flushInput=0;cpuRequestInput.address=address;stalls++;
      end
    end
    cpuRspReadyInput=1;tick();clear_inputs();#2;
    assert(!cpuResponseOutput.valid)else $fatal(1,"parameter ICache duplicate response");accesses++;
  endtask
  task automatic queued_hits_and_forward;
    logic [31:0] other;
    int row,way;
    // Consecutive synchronous reads must retain their own way even while the
    // old CPU response is held. For WAYS>1 these are different tags, same set.
    other=WAYS>1?32'(SETS*64):32'd64;
    access(0,0);access(other,0);clear_inputs();
    predecodeAddressInput=0;
    cpuRequestInput='{valid:1'b1,address:0,predictedProgramCounter:32'h10,predictorCheckpointId:bpu_ckpt_id_t'(1)};
    #2;assert(cpuReqReadyOutput && !memRequestOutput.valid)else $fatal(1,"parameter ICache pipeline first hit");
    touch(0,lookup(0));tick();check_packet(0,32'h10,bpu_ckpt_id_t'(1));
    predecodeAddressInput=other;
    cpuRequestInput='{valid:1'b1,address:other,predictedProgramCounter:other+16,predictorCheckpointId:bpu_ckpt_id_t'(2)};
    #2;assert(cpuReqReadyOutput && !memRequestOutput.valid)else $fatal(1,"parameter ICache pipeline second hit");
    touch(int'(other>>6)%SETS,lookup(int'(other>>6)));tick();cpuRequestInput='0;
    check_packet(0,32'h10,bpu_ckpt_id_t'(1));tick();check_packet(0,32'h10,bpu_ckpt_id_t'(1));
    cpuRspReadyInput=1;tick();cpuRspReadyInput=0;check_packet(other,other+16,bpu_ckpt_id_t'(2));
    cpuRspReadyInput=1;tick();clear_inputs();pipelines++;
    // A real accepted fill, not merely valid bus data, can forward to a new
    // request without a second port or another memory request.
    cpuRequestInput='{valid:1'b1,address:32'h60001000,predictedProgramCounter:32'h60001010,predictorCheckpointId:bpu_ckpt_id_t'(3)};
    #2;assert(cpuReqReadyOutput && memRequestOutput.valid)else $fatal(1,"parameter ICache forwarding miss");tick();cpuRequestInput='0;
    memResponseInput='{valid:1'b1,address:32'h60001000,data:'0};
    for(int w=0;w<16;w++)memResponseInput.data[32*w+:32]=rom(32'h60001000+32'(w*4));
    cpuRequestInput='{valid:1'b1,address:32'h6000100c,predictedProgramCounter:32'h6000101c,predictorCheckpointId:bpu_ckpt_id_t'(4)};
    #2;assert(memRspReadyOutput && cpuReqReadyOutput && !memRequestOutput.valid)
      else $fatal(1,"parameter ICache same-line refill forwarding");
    row=int'(32'h60001000>>6)%SETS;way=victim(row);present[row][way]=1;lines[row][way]=int'(32'h60001000>>6);touch(row,way);
    tick();cpuRequestInput='0;memResponseInput='0;
    check_packet(32'h60001000,32'h60001010,bpu_ckpt_id_t'(3));cpuRspReadyInput=1;tick();cpuRspReadyInput=0;
    check_packet(32'h6000100c,32'h6000101c,bpu_ckpt_id_t'(4));cpuRspReadyInput=1;tick();clear_inputs();forwards++;
    access(32'h6000100c,0);
  endtask
  task automatic duplicate_old_misses;
    clear_inputs();
    cpuRequestInput='{valid:1'b1,address:0,predictedProgramCounter:16,predictorCheckpointId:bpu_ckpt_id_t'(1)};
    #2;assert(cpuReqReadyOutput && memRequestOutput.valid)else $fatal(1,"parameter ICache first duplicate miss");tick();
    cpuRequestInput='{valid:1'b1,address:4,predictedProgramCounter:20,predictorCheckpointId:bpu_ckpt_id_t'(2)};
    #2;assert(cpuReqReadyOutput && memRequestOutput.valid)else $fatal(1,"parameter ICache second duplicate miss");tick();cpuRequestInput='0;
    memResponseInput='{valid:1'b1,address:0,data:'0};
    for(int w=0;w<16;w++)memResponseInput.data[32*w+:32]=rom(32'(w*4));
    #2;assert(memRspReadyOutput)else $fatal(1,"parameter ICache first duplicate fill");tick();memResponseInput.valid=0;
    check_packet(0,16,bpu_ckpt_id_t'(1));cpuRspReadyInput=1;tick();cpuRspReadyInput=0;
    memResponseInput.valid=1;#2;assert(memRspReadyOutput)else $fatal(1,"parameter ICache second duplicate fill");tick();memResponseInput='0;
    check_packet(4,20,bpu_ckpt_id_t'(2));cpuRspReadyInput=1;tick();clear_inputs();
    present[0][0]=1;lines[0][0]=0;touch(0,0);
    for(int w=1;w<WAYS;w++)access(32'(w*SETS*64),0);
    for(int w=0;w<WAYS;w++)access(32'(w*SETS*64),0);
  endtask
  initial begin
    int testSets,testWays,testWords,testRandom;
    // Runtime bounds prevent compiler expansion of timed task calls. All
    // bounds are checked against the original constants: no stimulus is lost.
    if(!$value$plusargs("ICACHE_TEST_SETS=%d",testSets))testSets=SETS;
    if(!$value$plusargs("ICACHE_TEST_WAYS=%d",testWays))testWays=WAYS;
    if(!$value$plusargs("ICACHE_TEST_WORDS=%d",testWords))testWords=16;
    if(!$value$plusargs("ICACHE_TEST_RANDOM=%d",testRandom))testRandom=240;
    assert(testSets==SETS && testWays==WAYS && testWords==16 && testRandom==240)
      else $fatal(1,"parameter ICache test bounds changed");
    done=0;clear_inputs();reset_model();tick();rstNInput=1;
    duplicate_old_misses();
    // Every row/way and every 64B-line word; includes cross-16B packets and
    // per-way CFI masks with different tags mapping to the same cache set.
    for(int w=0;w<testWays;w++)for(int s=0;s<testSets;s++)access(32'((s+w*SETS)*64),0);
    for(int w=0;w<testWays;w++)for(int s=0;s<testSets;s++)for(int word=0;word<testWords;word++)
      access(32'((s+w*SETS)*64+word*4),word%3);
    for(int n=0;n<testRandom;n++)access(32'((random_word()%(SETS*(WAYS+2)))*64+(random_word()%16)*4),n%3);
    queued_hits_and_forward();
    // Flush pending miss: a late physical response must not become a CPU reply.
    clear_inputs();cpuRequestInput='{valid:1'b1,address:32'h70000000,predictedProgramCounter:0,predictorCheckpointId:0};
    tick();cpuRequestInput='0;flushInput=1;#2;assert(memFlushOutput)else $fatal(1,"parameter ICache flush propagation");tick();clear_inputs();
    memResponseInput='{valid:1'b1,address:32'h70000000,data:'1};#2;
    assert(!memRspReadyOutput && !cpuResponseOutput.valid)else $fatal(1,"parameter ICache canceled fill");clear_inputs();
    // Cache metadata survives logical flush, but not reset.
    access(0,1);flushInput=1;tick();clear_inputs();access(0,1);
    rstNInput=0;tick();rstNInput=1;reset_model();access(0,1);
    assert(hits>0 && misses>0 && evictions>0 && stalls>0 && pipelines==1 && forwards==1)else $fatal(1,"parameter ICache missing coverage");
    $display("PASS parameter ICache FW=%0d SETS=%0d WAYS=%0d accesses=%0d hits=%0d misses=%0d evictions=%0d stalls=%0d",FW,SETS,WAYS,accesses,hits,misses,evictions,stalls);done=1;
  end
endmodule

module tb_parameterized_icache;
  wire [17:0] done;
  for(genvar fw=0;fw<3;fw++)begin : g_fw
    for(genvar ways=0;ways<3;ways++)begin : g_ways
      for(genvar size=0;size<2;size++)begin : g_size
        icache_configuration_case #(.FW(1<<fw),.WAYS(1<<ways),.SETS(size==0?4:16)) testCase(.done(done[fw*6+ways*2+size]));
      end
    end
  end
  initial begin wait(&done);$display("PASS parameter ICache all 18 configurations");$finish;end
  initial begin #1000000;$fatal(1,"parameter ICache timeout");end
endmodule
