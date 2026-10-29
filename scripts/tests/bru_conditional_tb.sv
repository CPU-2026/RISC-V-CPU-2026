module tb_bru_conditional #(parameter bit NEGATIVE = 1'b0);
  import rv32_pkg::*;
  logic clock=0, resetN=0, freeze=0, flush=0;
  rob_tag_t boundary='0;
  branch_operation_input_t request;
  branch_operation_output_t genericResult, conditionalResult, expected;
  execute_request_input_t genericInput, conditionalInput;
  bru_execute_output_t genericOutput, conditionalOutput, genericModel, conditionalModel;
  logic genericReady, conditionalReady;
  logic [31:0] seed=32'h24b7e391;
  int accepted[6];
  int frozenCycles=0, flushCycles=0, warmResets=0;

  rv32_bru generic_bru (.branchInput(request),.branchOutput(genericResult));
  rv32_bru #(.CONDITIONAL_ONLY(1'b1)) conditional_bru (
    .branchInput(request),.branchOutput(conditionalResult));
  rv32_bru_unit generic_unit (
    .clkInput(clock),.rstNInput(resetN),.freezeInput(freeze),.flushInput(flush),
    .flushTagInput(boundary),.executeInput(genericInput),.inReadyOutput(genericReady),.executeOutput(genericOutput));
  rv32_bru_unit #(.CONDITIONAL_ONLY(1'b1)) conditional_unit (
    .clkInput(clock),.rstNInput(resetN),.freezeInput(freeze),.flushInput(flush),
    .flushTagInput(boundary),.executeInput(conditionalInput),.inReadyOutput(conditionalReady),.executeOutput(conditionalOutput));

  function automatic logic [31:0] random_word();
    seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;
  endfunction
  function automatic operation_e branch_op(input int index);
    case(index)
      0:return OP_BEQ;1:return OP_BNE;2:return OP_BLT;
      3:return OP_BGE;4:return OP_BLTU;default:return OP_BGEU;
    endcase
  endfunction
  function automatic logic older(input rob_tag_t a,b);
    int distance;
    distance=(int'(b)-int'(a)) & ((1<<ROB_TAG_W)-1);
    return distance>0 && distance<ROB_ENTRIES;
  endfunction
  function automatic branch_operation_output_t calculate(input branch_operation_input_t q);
    branch_operation_output_t value;
    logic taken;
    logic [31:0] fallthrough, target;
    taken=0;
    case(q.operation)
      OP_BEQ:taken=q.source1==q.source2;OP_BNE:taken=q.source1!=q.source2;
      OP_BLT:taken=$signed(q.source1)<$signed(q.source2);
      OP_BGE:taken=$signed(q.source1)>=$signed(q.source2);
      OP_BLTU:taken=q.source1<q.source2;OP_BGEU:taken=q.source1>=q.source2;
      OP_JAL,OP_JALR:taken=1;
      default:taken=0;
    endcase
    fallthrough=q.programCounter+32'd4;
    target=q.operation==OP_JALR ? ((q.source1+q.immediate)&32'hfffffffe) : q.programCounter+q.immediate;
    value='0;value.taken=taken;value.target=target;value.linkValue=fallthrough;
    value.nextProgramCounter=taken?target:fallthrough;
    value.mispredict=value.nextProgramCounter!=q.predictedNextProgramCounter;
    return value;
  endfunction
  function automatic bru_execute_output_t capture(input execute_request_input_t q);
    branch_operation_output_t value;
    bru_execute_output_t result;
    value=calculate('{operation:q.operation,source1:q.source1,source2:q.source2,
      immediate:q.immediate,programCounter:q.programCounter,predictedNextProgramCounter:q.predictedNextProgramCounter});
    result='0;result.valid=1;result.robTag=q.robTag;result.programCounter=q.programCounter;
    result.target=value.target;result.nextProgramCounter=value.nextProgramCounter;
    result.returnAddress=value.linkValue;result.taken=value.taken;
    result.conditional=q.operation!=OP_JAL && q.operation!=OP_JALR;
    result.mispredict=value.mispredict;result.isCall=q.isCall;result.isReturn=q.isReturn;
    return result;
  endfunction
  task automatic check_units;
    bru_execute_output_t a,b;
    a=genericModel;b=conditionalModel;
    a.valid=genericModel.valid && (!flush || older(genericModel.robTag,boundary));
    b.valid=conditionalModel.valid && (!flush || older(conditionalModel.robTag,boundary));
    assert(genericOutput===a)else $fatal(1,"generic BRU registered output mismatch");
    assert(conditionalOutput===b)else $fatal(1,"conditional BRU registered output mismatch");
    assert(genericReady==(!genericInput.valid || !flush || older(genericInput.robTag,boundary)))
      else $fatal(1,"generic BRU ready mismatch");
    assert(conditionalReady==(!conditionalInput.valid || !flush || older(conditionalInput.robTag,boundary)))
      else $fatal(1,"conditional BRU ready mismatch");
  endtask
  task automatic tick;
    #2;
    if(!resetN)begin genericModel='0;conditionalModel='0;end
    else if(!freeze)begin
      if(genericInput.valid && (!flush || older(genericInput.robTag,boundary)))genericModel=capture(genericInput);
      else genericModel.valid=0;
      if(conditionalInput.valid && (!flush || older(conditionalInput.robTag,boundary)))conditionalModel=capture(conditionalInput);
      else conditionalModel.valid=0;
    end
    clock=1;#2;
    if(!NEGATIVE)check_units();
    clock=0;#1;
  endtask

  initial begin
    request='0;genericInput='0;conditionalInput='0;genericModel='0;conditionalModel='0;
    for(int i=0;i<6;i++)accepted[i]=0;
    tick();resetN=1;
    if(NEGATIVE)begin
      conditionalInput.valid=1;conditionalInput.operation=OP_JALR;conditionalInput.robTag=rob_tag_t'(5);
      freeze=1;tick(); // Not accepted: must not trigger the domain assertion.
      freeze=0;flush=1;boundary=rob_tag_t'(4);tick(); // Blocked by flush: also not accepted.
      flush=0;tick();
      $fatal(1,"conditional-only dispatch contract failed to reject JALR");
    end
    for(int i=0;i<100000;i++)begin
      request.operation=i%9<6?branch_op(i%9):(i%9==6?OP_JAL:(i%9==7?OP_JALR:OP_INVALID));
      request.source1=random_word();request.source2=i%7==0?request.source1:random_word();
      request.programCounter=random_word();request.immediate=random_word();
      case(i%4)
        0:request.predictedNextProgramCounter=request.programCounter+4;
        1:request.predictedNextProgramCounter=request.programCounter+request.immediate;
        2:request.predictedNextProgramCounter=(request.source1+request.immediate)&32'hfffffffe;
        default:request.predictedNextProgramCounter=random_word();
      endcase
      if(i%17==0)begin request.source1=32'h80000000;request.source2=32'h7fffffff;end
      if(i%19==0)begin request.source1=32'hffffffff;request.source2=0;end
      if(i%23==0)request.programCounter=32'hffffffff-32'(i%4);
      #1;expected=calculate(request);
      assert(genericResult===expected)else $fatal(1,"generic BRU arithmetic mismatch");
      if(i%9<6)assert(conditionalResult===expected)else $fatal(1,"conditional BRU arithmetic mismatch");
    end
    for(int i=0;i<30000;i++)begin
      resetN=i%997!=0;warmResets+=int'(!resetN);
      freeze=random_word()%9==0;flush=random_word()%7==0;boundary=rob_tag_t'(random_word());
      frozenCycles+=int'(freeze);flushCycles+=int'(flush);
      genericInput='0;genericInput.valid=random_word()%4!=0;
      genericInput.operation=i%9<6?branch_op(i%9):(i%9==6?OP_JAL:(i%9==7?OP_JALR:OP_INVALID));
      genericInput.source1=random_word();genericInput.source2=random_word();
      genericInput.immediate=random_word();genericInput.programCounter=random_word();
      genericInput.predictedNextProgramCounter=i%2==0?genericInput.programCounter+4:random_word();
      genericInput.robTag=rob_tag_t'(random_word());genericInput.destinationPhy=phy_tag_t'(random_word());
      genericInput.isCall=1'(random_word());genericInput.isReturn=1'(random_word());
      conditionalInput=genericInput;conditionalInput.operation=branch_op(i%6);
      #1;
      if(resetN)begin
        check_units();
        if(!freeze && conditionalInput.valid && conditionalReady)accepted[i%6]++;
      end
      tick();
    end
    for(int i=0;i<6;i++)assert(accepted[i]>0)else $fatal(1,"missing branch opcode coverage");
    assert(frozenCycles>0 && flushCycles>0 && warmResets>0)else $fatal(1,"missing control coverage");
    $display("PASS conditional/default BRU: 100000 arithmetic vectors, 30000 registered cycles, flush/freeze/reset/tag-wrap");
    $finish;
  end
endmodule
