module cpu_top #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter bit DIV_USE_SRT4 = 1'b0
) (
  input  logic             clkInput,
  input  logic             rstNInput,
  output logic             imemReqValidOutput,
  input  logic             imemReqReadyInput,
  output logic [31:0]      imemReqAddrOutput,
  input  logic             imemRspValidInput,
  input  logic [31:0]      imemRspDataInput,
  output logic             dmemReqValidOutput,
  input  logic             dmemReqReadyInput,
  output logic             dmemReqWriteOutput,
  output logic [31:0]      dmemReqAddrOutput,
  output logic [31:0]      dmemReqWdataOutput,
  output logic [3:0]       dmemReqWstrbOutput,
  output logic [1:0]       dmemReqSizeOutput,
  input  logic             dmemRspValidInput,
  input  logic [31:0]      dmemRspRdataInput,
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
  rv32_core #(
    .RESET_PC(RESET_PC),
    .DIV_USE_SRT4(DIV_USE_SRT4)
  ) u_core (.*);
endmodule
