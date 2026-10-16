module axi_sync_top (
  input logic clock, reset, squash,
  input logic fetchValid, fetchConsume,
  input logic [31:0] fetchAddress,
  output logic fetchReady, fetchReplyValid,
  output logic [31:0] fetchReplyAddress,
  output logic [511:0] fetchReplyData,
  input logic readValid, writeValid, readConsume, writeConsume,
  input logic [31:0] readAddress, writeAddress,
  input logic [1:0] readId, writeId,
  input logic [255:0] writeData,
  input logic exitValid,
  input logic [31:0] exitValue,
  output logic readReady, writeReady, exitReady, readReplyValid, writeReplyValid,
  output logic [31:0] readReplyAddress, writeReplyAddress,
  output logic [1:0] readReplyId, writeReplyId,
  output logic [255:0] readReplyData,
  input logic arready, awready, wready, rvalid, bvalid,
  input logic [31:0] rdata,
  output logic [31:0] pins [9]
);
  import rv32_pkg::*;
  axi_master_t fetchMaster, dataMaster, master;
  axi_slave_t fetchSlave, dataSlave;
  icache_line_response_input_t fetchReply;
  dcache_line_response_input_t readReply;
  dcache_write_response_input_t writeReply;
  rv32_axi_fetch fetch (
    .clkInput(clock), .rstNInput(!reset), .squashInput(squash),
    .requestInput('{valid:fetchValid, write:1'b0, address:fetchAddress, writeData:'0}),
    .requestReadyOutput(fetchReady), .responseOutput(fetchReply), .responseReadyInput(fetchConsume),
    .masterOutput(fetchMaster), .slaveInput(fetchSlave)
  );
  rv32_axi_data dataSide (
    .clkInput(clock), .rstNInput(!reset),
    .requestInput('{readValid:readValid, writeValid:writeValid, readAddress:readAddress,
      writeAddress:writeAddress, readTransaction:readId, writeTransaction:writeId, writeData:writeData}),
    .readReadyOutput(readReady), .writeReadyOutput(writeReady), .responseOutput(readReply),
    .responseReadyInput(readConsume), .writeResponseOutput(writeReply), .writeResponseReadyInput(writeConsume),
    .exitValidInput(exitValid), .exitValueInput(exitValue), .exitReadyOutput(exitReady),
    .masterOutput(dataMaster), .slaveInput(dataSlave)
  );
  rv32_axi_bus bus (
    .clkInput(clock), .rstNInput(!reset), .fetchInput(fetchMaster), .dataInput(dataMaster),
    .slaveInput('{arReady:arready, awReady:awready, wReady:wready, rValid:rvalid, bValid:bvalid,
      rData:rdata, rResp:2'b0, bResp:2'b0}), .masterOutput(master),
    .fetchOutput(fetchSlave), .dataOutput(dataSlave)
  );
  assign fetchReplyValid=fetchReply.valid;
  assign fetchReplyAddress=fetchReply.address;
  assign fetchReplyData=fetchReply.data;
  assign readReplyValid=readReply.valid;
  assign readReplyAddress=readReply.address;
  assign readReplyId=readReply.transaction;
  assign readReplyData=readReply.data;
  assign writeReplyValid=writeReply.valid;
  assign writeReplyAddress=writeReply.address;
  assign writeReplyId=writeReply.transaction;
  always_comb begin
    pins[0]=32'(master.arValid); pins[1]=master.arAddr; pins[2]=32'(master.rReady);
    pins[3]=32'(master.awValid); pins[4]=master.awAddr; pins[5]=32'(master.wValid);
    pins[6]=master.wData; pins[7]=32'(master.wStrb); pins[8]=32'(master.bReady);
  end
endmodule
