module cpu_top #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter bit DIV_USE_SRT4 = 1'b0
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  output logic             imem_req_valid_o,
  input  logic             imem_req_ready_i,
  output logic [31:0]      imem_req_addr_o,
  input  logic             imem_rsp_valid_i,
  input  logic [31:0]      imem_rsp_data_i,
  output logic             dmem_req_valid_o,
  input  logic             dmem_req_ready_i,
  output logic             dmem_req_write_o,
  output logic [31:0]      dmem_req_addr_o,
  output logic [31:0]      dmem_req_wdata_o,
  output logic [3:0]       dmem_req_wstrb_o,
  output logic [1:0]       dmem_req_size_o,
  input  logic             dmem_rsp_valid_i,
  input  logic [31:0]      dmem_rsp_rdata_i,
  output logic             commit_valid_o,
  output logic [31:0]      commit_pc_o,
  output logic [31:0]      commit_instr_o,
  output logic             commit_rd_valid_o,
  output logic [4:0]       commit_rd_o,
  output logic [31:0]      commit_rd_value_o,
  output logic             commit_mem_valid_o,
  output logic [31:0]      commit_mem_addr_o,
  output logic [31:0]      commit_mem_data_o,
  output logic [3:0]       commit_mem_wstrb_o,
  output logic             halted_o,
  output logic             trap_o
);
  rv32_core #(
    .RESET_PC(RESET_PC),
    .DIV_USE_SRT4(DIV_USE_SRT4)
  ) u_core (.*);
endmodule
