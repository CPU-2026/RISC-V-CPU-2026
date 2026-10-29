// Packet enqueue, scalar dequeue. DEPTH remains an INSTRUCTION credit limit,
// not DEPTH two-word packets. A partially consumed head retains its identity.
module rv32_fetch_packet_fifo #(
  parameter int unsigned DEPTH=rv32_pkg::FQ_ENTRIES,
  localparam int unsigned SLOT_W=$clog2(DEPTH),
  localparam int unsigned COUNT_W=$clog2(DEPTH+1)
) (
  input logic clkInput,rstNInput,freezeInput,flushInput,
  input logic inValidInput,
  output logic inReadyOutput,
  input rv32_pkg::fetch_packet_t inDataInput,
  output logic outValidOutput,
  input logic outReadyInput,
  output rv32_pkg::decode_context_t outDataOutput,
  output logic [COUNT_W-1:0] countOutput
);
  import rv32_pkg::*;
  fetch_packet_t entriesInner [DEPTH];
  fetch_packet_t headPacketInner;
  logic [SLOT_W-1:0] headInner,tailInner;
  logic [COUNT_W-1:0] packetsInner,wordsInner;
  logic cursorInner,popWordInner,popPacketInner,pushInner;
  logic [COUNT_W:0] wordsAfterPopInner,inWordsInner;
  logic [31:0] headSecondPcInner;
  assign headPacketInner=packetsInner=='0?'0:entriesInner[headInner];
  // Only dual packets consume this value. Their accepted base is 8B aligned,
  // so advancing to the second instruction sets bit 2 without a carry chain.
  assign headSecondPcInner=headPacketInner.metadata.programCounter | 32'd4;
  assign outValidOutput=packetsInner!='0&&!flushInput;
  assign popWordInner=outValidOutput&&outReadyInput;
  assign popPacketInner=popWordInner&&(!headPacketInner.metadata.secondValid||cursorInner);
  assign wordsAfterPopInner={1'b0,wordsInner}-(COUNT_W+1)'(popWordInner);
  assign inWordsInner=(COUNT_W+1)'(1)+(COUNT_W+1)'(inDataInput.metadata.secondValid);
  assign inReadyOutput=!flushInput&&(packetsInner<COUNT_W'(DEPTH)||popPacketInner)&&
    wordsAfterPopInner+inWordsInner<=(COUNT_W+1)'(DEPTH);
  assign pushInner=inValidInput&&inReadyOutput;
  assign countOutput=wordsInner;
  always_comb begin
    outDataOutput='0;
    if(packetsInner!='0)begin
      outDataOutput.instruction=cursorInner?headPacketInner.instructions[63:32]:headPacketInner.instructions[31:0];
      outDataOutput.programCounter=cursorInner?headSecondPcInner:headPacketInner.metadata.programCounter;
      outDataOutput.predictedNextProgramCounter=!cursorInner&&headPacketInner.metadata.secondValid?
        headSecondPcInner:headPacketInner.metadata.predictedNextProgramCounter;
      outDataOutput.predictorCheckpointId=headPacketInner.metadata.predictorCheckpointId+bpu_ckpt_id_t'(cursorInner);
    end
  end
  always_ff @(posedge clkInput or negedge rstNInput)begin
    if(!rstNInput)begin headInner<='0;tailInner<='0;packetsInner<='0;wordsInner<='0;cursorInner<=0;end
    else if(!freezeInput&&flushInput)begin headInner<='0;tailInner<='0;packetsInner<='0;wordsInner<='0;cursorInner<=0;end
    else if(!freezeInput)begin
      if(popPacketInner)begin headInner<=headInner+SLOT_W'(1);cursorInner<=0;end
      else if(popWordInner)cursorInner<=1;
      if(pushInner)begin entriesInner[tailInner]<=inDataInput;tailInner<=tailInner+SLOT_W'(1);end
      packetsInner<=packetsInner+COUNT_W'(pushInner)-COUNT_W'(popPacketInner);
      wordsInner<=wordsInner+COUNT_W'(pushInner?inWordsInner:'0)-COUNT_W'(popWordInner);
    end
  end
`ifndef SYNTHESIS
  initial assert(DEPTH>=2&&(DEPTH&(DEPTH-1))==0);
  always @(posedge clkInput)if(rstNInput)begin
    assert(wordsInner<=COUNT_W'(DEPTH)&&packetsInner<=wordsInner);
    assert(!cursorInner||headPacketInner.metadata.secondValid);
    if(packetsInner!='0 && headPacketInner.metadata.secondValid)
      assert(headPacketInner.metadata.programCounter[2:0]==0);
    if(pushInner)assert(!inDataInput.metadata.secondValid||inDataInput.metadata.programCounter[2:0]==0);
  end
`endif
endmodule
