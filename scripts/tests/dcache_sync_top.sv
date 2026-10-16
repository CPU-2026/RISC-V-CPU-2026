// Read-only test instrumentation. Production modules have no probe ports.
module dcache_sync_top (
  input logic clock, reset,
  input logic cpuValid, cpuWrite,
  input logic [31:0] cpuAddress, cpuData,
  input logic [1:0] cpuSize, cpuTransaction,
  output logic cpuReady, responseValid,
  output logic [31:0] responseData,
  output logic [1:0] responseTransaction,
  input logic directMemory, directRead, directWrite, directReadConsume, directWriteConsume,
  input logic [31:0] directReadAddress, directWriteAddress,
  input logic [1:0] directReadTransaction, directWriteTransaction,
  input logic [rv32_pkg::DCACHE_LINE_BITS-1:0] directWriteData,
  output logic readReady, writeReady, readValid, writeValid, readConsume, writeConsume,
  output logic [31:0] readAddress, writeAddress,
  output logic [1:0] readTransaction, writeTransaction,
  output logic [rv32_pkg::DCACHE_LINE_BITS-1:0] readData,
  output logic [4:0] memoryCount,
  output logic backingRead, backingWrite,
  output logic [31:0] backingReadAddress, backingWriteAddress,
  input logic [rv32_pkg::DCACHE_LINE_BITS-1:0] backingReadData,
  output logic [rv32_pkg::DCACHE_LINE_BITS-1:0] backingWriteData,
  output logic [31:0] events [10],
  output logic [15:0] dataEnable, dataWrite,
  output logic [31:0] dataPort [16],
  output logic [3:0] dataMask [16],
  output logic [1:0] metaEnable, metaWrite,
  output logic [31:0] metaPort [2],
  output logic [31:0] sramAddress,
  output logic [31:0] missCount
);
  import rv32_pkg::*;
  dcache_cpu_request_input_t cpuRequest;
  dcache_cpu_response_output_t cpuResponse;
  dcache_line_request_output_t cacheRequest, request;
  dcache_line_response_input_t response;
  dcache_write_response_input_t writeResponse;
  logic cacheReadConsume, cacheWriteConsume;
  assign cpuRequest = '{valid:cpuValid, write:cpuWrite, address:cpuAddress, writeData:cpuData,
    writeStrobe:4'b1111, size:cpuSize, transaction:cpuTransaction};
  assign responseValid = cpuResponse.valid;
  assign responseData = cpuResponse.readData;
  assign responseTransaction = cpuResponse.transaction;
  assign request = directMemory ? '{readValid:directRead, readAddress:directReadAddress,
    readTransaction:directReadTransaction, writeValid:directWrite, writeAddress:directWriteAddress,
    writeTransaction:directWriteTransaction, writeData:directWriteData} : cacheRequest;
  assign readValid = response.valid;
  assign readAddress = response.address;
  assign readTransaction = response.transaction;
  assign readData = response.data;
  assign writeValid = writeResponse.valid;
  assign writeAddress = writeResponse.address;
  assign writeTransaction = writeResponse.transaction;
  assign readConsume = directMemory ? directReadConsume : cacheReadConsume;
  assign writeConsume = directMemory ? directWriteConsume : cacheWriteConsume;
  rv32_dcache cache (
    .clkInput(clock), .rstNInput(!reset), .cpuRequestInput(cpuRequest), .cpuReqReadyOutput(cpuReady),
    .cpuResponseOutput(cpuResponse), .memRequestOutput(cacheRequest), .memReadReadyInput(readReady),
    .memWriteReadyInput(writeReady), .memResponseInput(directMemory ? dcache_line_response_input_t'('0) : response),
    .memWriteResponseInput(directMemory ? dcache_write_response_input_t'('0) : writeResponse),
    .memRspReadyOutput(cacheReadConsume), .memWriteRspReadyOutput(cacheWriteConsume), .initializedOutput(), .idleOutput()
  );
  rv32_dmem memoryController (
    .clkInput(clock), .rstNInput(!reset), .requestInput(request), .readReadyOutput(readReady),
    .writeReadyOutput(writeReady), .responseOutput(response), .writeResponseOutput(writeResponse),
    .responseReadyInput(readConsume), .writeResponseReadyInput(writeConsume),
    .backingReadValidOutput(backingRead), .backingReadAddressOutput(backingReadAddress),
    .backingReadDataInput(backingReadData), .backingWriteValidOutput(backingWrite),
    .backingWriteAddressOutput(backingWriteAddress), .backingWriteDataOutput(backingWriteData), .countOutput(memoryCount)
  );
  assign events[0] = cache.lookupInner;
  assign events[1] = cache.responseInner;
  assign events[2] = cache.storeInner;
  assign events[3] = cache.allocateMissInner;
  assign events[4] = cache.mergeSlotInner;
  assign events[5] = cache.mergeMissInner;
  assign events[6] = cache.fillMissInner;
  assign events[7] = cache.writeAckInner;
  assign events[8] = 32'(cache.fillBeatInner);
  assign events[9] = 32'(cache.fillFireInner);
  assign sramAddress = 32'(cache.sramAddressInner);
  always_comb begin
    missCount = 0;
    for (int m = 0; m < 4; m++) if (cache.missesInner[m].valid) missCount++;
  end
  for (genvar w = 0; w < 2; w++) begin : g_way
    assign metaEnable[w] = cache.metaEnableInner[w];
    assign metaWrite[w] = cache.metaWriteInner[w];
    assign metaPort[w] = 32'(cache.metaWdataInner);
    for (genvar b = 0; b < 8; b++) begin : g_bank
      assign dataEnable[w*8+b] = cache.dataEnableBankInner[w][b];
      assign dataWrite[w*8+b] = cache.dataWriteBankInner[w][b];
      assign dataPort[w*8+b] = cache.dataWdataBankInner[w][b];
      assign dataMask[w*8+b] = cache.dataMaskBankInner[w][b];
    end
  end
endmodule
