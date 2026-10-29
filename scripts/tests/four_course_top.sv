// Same course Slave and retirement boundary; only additional wide RTL counters.
module four_course_top (
  input logic clock,reset,
  output wire [31:0] araddr,awaddr,wdata,
  output wire arvalid,rready,awvalid,wvalid,bready,
  output wire [3:0] wstrb,
  input logic arready,rvalid,awready,wready,bvalid,
  input logic [31:0] rdata,
  input logic [1:0] rresp,bresp,
  output wire [31:0] observe [57+(9*rv32_pkg::COMMIT_WIDTH)],
  output wire [2:0] decodeCountOutput,issueCountOutput,loadAllocCountOutput,storeAllocCountOutput,
  output wire [7:0] renameEventsOutput,
  output wire [5:0] robCountOutput
);
  import rv32_pkg::*;
  course_sync_top bench(.*);
  assign decodeCountOutput=bench.dut.u_core.u_frontend.g_wide_decode.u_decode_issue.decodeFireCountOutput;
  assign issueCountOutput=bench.dut.u_core.wideIssueCountInner;
  assign robCountOutput=bench.dut.u_core.robCountInner;
  logic [2:0] loads,stores;
  logic [7:0] events;
  always_comb begin
    loads='0;stores='0;events='0;
    for(int lane=0;lane<4;lane++)begin
      loads+=3'(bench.dut.u_core.wideLoadFireInner[lane]);
      stores+=3'(bench.dut.u_core.wideStoreFireInner[lane]);
      for(int older=0;older<lane;older++)begin
        if(bench.dut.u_core.wideFireInner[lane] && bench.dut.u_core.wideFireInner[older] &&
           bench.dut.u_core.wideDecodedInner[older].writesRd && bench.dut.u_core.wideDecodedInner[older].rd!=0)begin
          if(bench.dut.u_core.wideDecodedInner[lane].usesRs1 &&
             bench.dut.u_core.wideDecodedInner[lane].rs1==bench.dut.u_core.wideDecodedInner[older].rd)begin
            events[0]=1;
            if(bench.dut.u_core.wideDecodedInner[older].operation==OP_JAL ||
               bench.dut.u_core.wideDecodedInner[older].operation==OP_JALR)events[3]=1;
          end
          if(bench.dut.u_core.wideDecodedInner[lane].usesRs2 &&
             bench.dut.u_core.wideDecodedInner[lane].rs2==bench.dut.u_core.wideDecodedInner[older].rd)events[1]=1;
          if(bench.dut.u_core.wideDecodedInner[lane].writesRd &&
             bench.dut.u_core.wideDecodedInner[lane].rd==bench.dut.u_core.wideDecodedInner[older].rd)events[2]=1;
        end
      end
    end
    events[4]=bench.dut.u_core.robFullInner;
    events[5]=bench.dut.u_core.g_four_rename_state.u_rename.freeCount==0;
    events[6]=bench.dut.u_core.wideLoadCreditsInner==0 || bench.dut.u_core.wideStoreCreditsInner==0;
    events[7]=bench.dut.u_core.globalFlushInner;
  end
  assign loadAllocCountOutput=loads;
  assign storeAllocCountOutput=stores;
  assign renameEventsOutput=events;
endmodule
