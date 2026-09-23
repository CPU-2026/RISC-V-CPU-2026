module cpu_cached_top #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter int unsigned ICACHE_SETS = 512,
  parameter int unsigned DCACHE_SETS = 1024,
  parameter int unsigned DCACHE_WAYS = 4,
  parameter bit DIV_USE_SRT4 = 1'b0
) (
  input  logic             clkInput,
  input  logic             rstNInput,

  output logic             imemLineReqValidOutput,
  input  logic             imemLineReqReadyInput,
  output logic [31:0]      imemLineReqAddrOutput,
  input  logic             imemLineRspValidInput,
  input  logic [127:0]     imemLineRspDataInput,

  output logic             dmemLineReqValidOutput,
  input  logic             dmemLineReqReadyInput,
  output logic             dmemLineReqWriteOutput,
  output logic [31:0]      dmemLineReqAddrOutput,
  output logic [127:0]     dmemLineReqWdataOutput,
  input  logic             dmemLineRspValidInput,
  input  logic [127:0]     dmemLineRspDataInput,

  output logic             commitValidOutput,
  output logic [31:0]      commitPcOutput,
  output logic [31:0]      commitInstrOutput,
  output logic             commitRdValidOutput,
  output logic [4:0]       commitRdOutput,
  output logic [31:0]      commitRdValueOutput,
  output logic             commitMemValidOutput,
  output logic [31:0]      commitMemAddrOutput,
  output logic [31:0]      commitMemDataOutput,
  output logic [3:0]       commitMemWstrbOutput,
  output logic             haltedOutput,
  output logic             trapOutput
);
  logic coreImemReqValidInner, coreImemReqReadyInner;
  logic [31:0] coreImemReqAddrInner;
  logic coreImemRspValidInner;
  logic [31:0] coreImemRspDataInner;
  rv32_pkg::icache_cpu_request_input_t icacheCpuRequestInner;
  rv32_pkg::icache_cpu_response_output_t icacheCpuResponseInner;
  rv32_pkg::cache_line_request_output_t icacheMemoryRequestInner;
  rv32_pkg::cache_line_response_input_t icacheMemoryResponseInner;
  logic coreDmemReqValidInner, coreDmemReqReadyInner, coreDmemReqWriteInner;
  logic [31:0] coreDmemReqAddrInner, coreDmemReqWdataInner;
  logic [3:0] coreDmemReqWstrbInner;
  logic [1:0] coreDmemReqSizeInner;
  logic coreDmemRspValidInner;
  logic [31:0] coreDmemRspDataInner;
  rv32_pkg::dcache_cpu_request_input_t dcacheCpuRequestInner;
  rv32_pkg::dcache_cpu_response_output_t dcacheCpuResponseInner;
  rv32_pkg::cache_line_request_output_t dcacheMemoryRequestInner;
  rv32_pkg::cache_line_response_input_t dcacheMemoryResponseInner;
  logic coreHaltedInner, dcacheFlushDoneInner;

  assign haltedOutput = coreHaltedInner && dcacheFlushDoneInner;
  assign icacheCpuRequestInner = '{valid: coreImemReqValidInner,
                                   address: coreImemReqAddrInner};
  assign coreImemRspValidInner = icacheCpuResponseInner.valid;
  assign coreImemRspDataInner = icacheCpuResponseInner.instruction;
  assign icacheMemoryResponseInner = '{valid: imemLineRspValidInput,
                                       data: imemLineRspDataInput};
  assign imemLineReqValidOutput = icacheMemoryRequestInner.valid;
  assign imemLineReqAddrOutput = icacheMemoryRequestInner.address;
  assign dcacheCpuRequestInner = '{valid: coreDmemReqValidInner,
                                   write: coreDmemReqWriteInner,
                                   address: coreDmemReqAddrInner,
                                   writeData: coreDmemReqWdataInner,
                                   writeStrobe: coreDmemReqWstrbInner,
                                   size: coreDmemReqSizeInner};
  assign coreDmemRspValidInner = dcacheCpuResponseInner.valid;
  assign coreDmemRspDataInner = dcacheCpuResponseInner.readData;
  assign dcacheMemoryResponseInner = '{valid: dmemLineRspValidInput,
                                       data: dmemLineRspDataInput};
  assign dmemLineReqValidOutput = dcacheMemoryRequestInner.valid;
  assign dmemLineReqWriteOutput = dcacheMemoryRequestInner.write;
  assign dmemLineReqAddrOutput = dcacheMemoryRequestInner.address;
  assign dmemLineReqWdataOutput = dcacheMemoryRequestInner.writeData;

  rv32_core #(
    .RESET_PC(RESET_PC),
    .DIV_USE_SRT4(DIV_USE_SRT4)
  ) u_core (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .imemReqValidOutput(coreImemReqValidInner),
    .imemReqReadyInput(coreImemReqReadyInner),
    .imemReqAddrOutput(coreImemReqAddrInner),
    .imemRspValidInput(coreImemRspValidInner),
    .imemRspDataInput(coreImemRspDataInner),
    .dmemReqValidOutput(coreDmemReqValidInner),
    .dmemReqReadyInput(coreDmemReqReadyInner),
    .dmemReqWriteOutput(coreDmemReqWriteInner),
    .dmemReqAddrOutput(coreDmemReqAddrInner),
    .dmemReqWdataOutput(coreDmemReqWdataInner),
    .dmemReqWstrbOutput(coreDmemReqWstrbInner),
    .dmemReqSizeOutput(coreDmemReqSizeInner),
    .dmemRspValidInput(coreDmemRspValidInner),
    .dmemRspRdataInput(coreDmemRspDataInner),
    .commitValidOutput(commitValidOutput), .commitPcOutput(commitPcOutput),
    .commitInstrOutput(commitInstrOutput),
    .commitRdValidOutput(commitRdValidOutput), .commitRdOutput(commitRdOutput),
    .commitRdValueOutput(commitRdValueOutput),
    .commitMemValidOutput(commitMemValidOutput),
    .commitMemAddrOutput(commitMemAddrOutput),
    .commitMemDataOutput(commitMemDataOutput),
    .commitMemWstrbOutput(commitMemWstrbOutput),
    .haltedOutput(coreHaltedInner), .trapOutput(trapOutput)
  );

  rv32_icache #(.SETS(ICACHE_SETS)) u_icache (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .cpuRequestInput(icacheCpuRequestInner),
    .cpuReqReadyOutput(coreImemReqReadyInner),
    .cpuResponseOutput(icacheCpuResponseInner),
    .memRequestOutput(icacheMemoryRequestInner),
    .memReqReadyInput(imemLineReqReadyInput),
    .memResponseInput(icacheMemoryResponseInner)
  );

  rv32_dcache #(.SETS(DCACHE_SETS), .WAYS(DCACHE_WAYS)) u_dcache (
    .clkInput(clkInput), .rstNInput(rstNInput),
    .cpuRequestInput(dcacheCpuRequestInner),
    .cpuReqReadyOutput(coreDmemReqReadyInner),
    .cpuResponseOutput(dcacheCpuResponseInner),
    .memRequestOutput(dcacheMemoryRequestInner),
    .memReqReadyInput(dmemLineReqReadyInput),
    .memResponseInput(dcacheMemoryResponseInner),
    .flushInput(coreHaltedInner), .flushDoneOutput(dcacheFlushDoneInner)
  );
endmodule
