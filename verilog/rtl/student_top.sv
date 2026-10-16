module student_top (
    input  wire        clock,
    input  wire        reset,    // 高电平复位，初始化时保持 5 周期高电平

    // AXI4-Lite 读地址通道 (AR)
    output wire [31:0] araddr,
    output wire        arvalid,
    input  wire        arready,

    // AXI4-Lite 读数据通道 (R)
    input  wire [31:0] rdata,
    input  wire [1:0]  rresp,    // 2'b00 = OKAY, 2'b10 = SLVERR, 2'b11 = DECERR
    input  wire        rvalid,
    output wire        rready,

    // AXI4-Lite 写地址通道 (AW)
    output wire [31:0] awaddr,
    output wire        awvalid,
    input  wire        awready,

    // AXI4-Lite 写数据通道 (W)
    output wire [31:0] wdata,
    output wire [3:0]  wstrb,    // 字节写使能掩码
    output wire        wvalid,
    input  wire        wready,

    // AXI4-Lite 写响应通道 (B)
    input  wire [1:0]  bresp,
    input  wire        bvalid,
    output wire        bready
);
    import rv32_pkg::*;
    logic resetNInner;
    logic haltedInner, trapInner;
    logic imemReadyInner, imemResponseValidInner, imemResponseReadyInner, imemFlushInner;
    logic [31:0] imemInstructionInner;
    icache_cpu_request_input_t imemRequestInner;
    icache_cpu_response_output_t icacheResponseInner;
    cache_line_request_output_t fetchRequestInner;
    icache_line_response_input_t fetchResponseInner;
    logic fetchReadyInner, fetchResponseReadyInner, fetchFlushInner;
    logic dmemValidInner, dmemWriteInner, dmemReadyInner;
    logic [31:0] dmemAddressInner, dmemDataInner;
    logic [3:0] dmemStrobeInner;
    logic [1:0] dmemSizeInner;
    data_transaction_t dmemTransactionInner;
    dcache_cpu_request_input_t dcacheRequestInner;
    dcache_cpu_response_output_t dcacheResponseInner;
    dcache_line_request_output_t dataRequestInner;
    dcache_line_response_input_t dataResponseInner;
    dcache_write_response_input_t dataWriteResponseInner, cacheWriteResponseInner;
    logic dataReadReadyInner, dataWriteReadyInner, dataResponseReadyInner, dataWriteResponseReadyInner;
    logic exitReadyInner, exitValidInner;
    logic [31:0] exitValueInner;
    axi_master_t fetchMasterInner, dataMasterInner, masterInner;
    axi_slave_t slaveInner, fetchSlaveInner, dataSlaveInner;
    assign resetNInner = !reset;

    rv32_core #(.TAGGED_DMEM(1'b1), .LEGACY_HALT(1'b0)) u_core (
      .clkInput(clock), .rstNInput(resetNInner),
      .imemReqValidOutput(), .imemReqAddrOutput(), .imemCacheRequestOutput(imemRequestInner),
      .imemReqReadyInput(imemReadyInner), .imemRspValidInput(imemResponseValidInner),
      .imemRspDataInput(imemInstructionInner), .imemRspReadyOutput(imemResponseReadyInner),
      .imemFlushOutput(imemFlushInner),
      .dmemReqValidOutput(dmemValidInner), .dmemReqReadyInput(dmemReadyInner),
      .dmemReqWriteOutput(dmemWriteInner), .dmemReqAddrOutput(dmemAddressInner),
      .dmemReqWdataOutput(dmemDataInner), .dmemReqWstrbOutput(dmemStrobeInner),
      .dmemReqSizeOutput(dmemSizeInner), .dmemReqTransactionOutput(dmemTransactionInner),
      .dmemRspValidInput(dcacheResponseInner.valid), .dmemRspRdataInput(dcacheResponseInner.readData),
      .dmemRspTransactionInput(dcacheResponseInner.transaction),
      .commitValidOutput(), .commitPcOutput(), .commitInstrOutput(),
      .commitRdValidOutput(), .commitRdOutput(), .commitRdValueOutput(),
      .commitMemValidOutput(), .commitMemAddrOutput(), .commitMemDataOutput(), .commitMemWstrbOutput(),
      .haltedOutput(haltedInner), .trapOutput(trapInner)
    );
    assign imemResponseValidInner = icacheResponseInner.valid;
    assign imemInstructionInner = icacheResponseInner.instruction;
    rv32_icache u_icache (
      .clkInput(clock), .rstNInput(resetNInner), .freezeInput(haltedInner),
      .flushInput(imemFlushInner), .cpuRequestInput(imemRequestInner),
      .cpuReqReadyOutput(imemReadyInner), .cpuResponseOutput(icacheResponseInner),
      .cpuRspReadyInput(imemResponseReadyInner), .memRequestOutput(fetchRequestInner),
      .memReqReadyInput(fetchReadyInner), .memResponseInput(fetchResponseInner),
      .memRspReadyOutput(fetchResponseReadyInner), .memFlushOutput(fetchFlushInner)
    );
    rv32_axi_fetch u_axi_fetch (
      .clkInput(clock), .rstNInput(resetNInner), .squashInput(fetchFlushInner),
      .requestInput(fetchRequestInner), .requestReadyOutput(fetchReadyInner),
      .responseOutput(fetchResponseInner), .responseReadyInput(fetchResponseReadyInner),
      .masterOutput(fetchMasterInner), .slaveInput(fetchSlaveInner)
    );
    assign dcacheRequestInner = '{valid:dmemValidInner, write:dmemWriteInner,
      address:dmemAddressInner, writeData:dmemDataInner, writeStrobe:dmemStrobeInner,
      size:dmemSizeInner, transaction:dmemTransactionInner};
    assign cacheWriteResponseInner = '{valid:dataWriteResponseInner.valid &&
      dataWriteResponseInner.address != AXI_EXIT_ADDR, address:dataWriteResponseInner.address,
      transaction:dataWriteResponseInner.transaction};
    rv32_dmem_backend u_dmem_backend (
      .clkInput(clock), .rstNInput(resetNInner), .cpuRequestInput(dcacheRequestInner),
      .cpuReqReadyOutput(dmemReadyInner), .cpuResponseOutput(dcacheResponseInner),
      .memRequestOutput(dataRequestInner), .memReadReadyInput(dataReadReadyInner),
      .memWriteReadyInput(dataWriteReadyInner), .memResponseInput(dataResponseInner),
      .memWriteResponseInput(cacheWriteResponseInner), .memRspReadyOutput(dataResponseReadyInner),
      .memWriteRspReadyOutput(dataWriteResponseReadyInner), .initializedOutput(),
      .exitReadyInput(exitReadyInner), .exitValidOutput(exitValidInner), .exitValueOutput(exitValueInner)
    );
    rv32_axi_data u_axi_data (
      .clkInput(clock), .rstNInput(resetNInner), .requestInput(dataRequestInner),
      .readReadyOutput(dataReadReadyInner), .writeReadyOutput(dataWriteReadyInner),
      .responseOutput(dataResponseInner), .responseReadyInput(dataResponseReadyInner),
      .writeResponseOutput(dataWriteResponseInner),
      .writeResponseReadyInput(dataWriteResponseReadyInner || dataWriteResponseInner.address == AXI_EXIT_ADDR),
      .exitValidInput(exitValidInner), .exitValueInput(exitValueInner), .exitReadyOutput(exitReadyInner),
      .masterOutput(dataMasterInner), .slaveInput(dataSlaveInner)
    );
    assign slaveInner = '{arReady:arready, rValid:rvalid, awReady:awready, wReady:wready,
      bValid:bvalid, rData:rdata, rResp:rresp, bResp:bresp};
    rv32_axi_bus u_axi_bus (
      .clkInput(clock), .rstNInput(resetNInner), .fetchInput(fetchMasterInner), .dataInput(dataMasterInner),
      .slaveInput(slaveInner), .masterOutput(masterInner), .fetchOutput(fetchSlaveInner), .dataOutput(dataSlaveInner)
    );
    assign araddr = masterInner.arAddr;
    assign arvalid = masterInner.arValid;
    assign rready = masterInner.rReady;
    assign awaddr = masterInner.awAddr;
    assign awvalid = masterInner.awValid;
    assign wdata = masterInner.wData;
    assign wstrb = masterInner.wStrb;
    assign wvalid = masterInner.wValid;
    assign bready = masterInner.bReady;
`ifndef SYNTHESIS
    always @(posedge clock) if (!reset) assert (!trapInner)
      else $fatal(1, "CPU retired an illegal instruction");
`endif
endmodule
