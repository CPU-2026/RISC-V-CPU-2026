module cpu_cached_top #(
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter int unsigned ICACHE_SETS = 512,
  parameter int unsigned DCACHE_SETS = 1024,
  parameter int unsigned DCACHE_WAYS = 4,
  parameter bit DIV_USE_SRT4 = 1'b0
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  output logic             imem_line_req_valid_o,
  input  logic             imem_line_req_ready_i,
  output logic [31:0]      imem_line_req_addr_o,
  input  logic             imem_line_rsp_valid_i,
  input  logic [127:0]     imem_line_rsp_data_i,

  output logic             dmem_line_req_valid_o,
  input  logic             dmem_line_req_ready_i,
  output logic             dmem_line_req_write_o,
  output logic [31:0]      dmem_line_req_addr_o,
  output logic [127:0]     dmem_line_req_wdata_o,
  input  logic             dmem_line_rsp_valid_i,
  input  logic [127:0]     dmem_line_rsp_data_i,

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
  logic core_imem_req_valid, core_imem_req_ready;
  logic [31:0] core_imem_req_addr;
  logic core_imem_rsp_valid;
  logic [31:0] core_imem_rsp_data;
  logic core_dmem_req_valid, core_dmem_req_ready, core_dmem_req_write;
  logic [31:0] core_dmem_req_addr, core_dmem_req_wdata;
  logic [3:0] core_dmem_req_wstrb;
  logic [1:0] core_dmem_req_size;
  logic core_dmem_rsp_valid;
  logic [31:0] core_dmem_rsp_data;
  logic core_halted, dcache_flush_done;

  assign halted_o = core_halted && dcache_flush_done;

  rv32_core #(
    .RESET_PC(RESET_PC),
    .DIV_USE_SRT4(DIV_USE_SRT4)
  ) u_core (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .imem_req_valid_o(core_imem_req_valid),
    .imem_req_ready_i(core_imem_req_ready),
    .imem_req_addr_o(core_imem_req_addr),
    .imem_rsp_valid_i(core_imem_rsp_valid),
    .imem_rsp_data_i(core_imem_rsp_data),
    .dmem_req_valid_o(core_dmem_req_valid),
    .dmem_req_ready_i(core_dmem_req_ready),
    .dmem_req_write_o(core_dmem_req_write),
    .dmem_req_addr_o(core_dmem_req_addr),
    .dmem_req_wdata_o(core_dmem_req_wdata),
    .dmem_req_wstrb_o(core_dmem_req_wstrb),
    .dmem_req_size_o(core_dmem_req_size),
    .dmem_rsp_valid_i(core_dmem_rsp_valid),
    .dmem_rsp_rdata_i(core_dmem_rsp_data),
    .commit_valid_o(commit_valid_o), .commit_pc_o(commit_pc_o),
    .commit_instr_o(commit_instr_o),
    .commit_rd_valid_o(commit_rd_valid_o), .commit_rd_o(commit_rd_o),
    .commit_rd_value_o(commit_rd_value_o),
    .commit_mem_valid_o(commit_mem_valid_o),
    .commit_mem_addr_o(commit_mem_addr_o),
    .commit_mem_data_o(commit_mem_data_o),
    .commit_mem_wstrb_o(commit_mem_wstrb_o),
    .halted_o(core_halted), .trap_o(trap_o)
  );

  rv32_icache #(.SETS(ICACHE_SETS)) u_icache (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .cpu_req_valid_i(core_imem_req_valid),
    .cpu_req_ready_o(core_imem_req_ready),
    .cpu_req_addr_i(core_imem_req_addr),
    .cpu_rsp_valid_o(core_imem_rsp_valid),
    .cpu_rsp_data_o(core_imem_rsp_data),
    .mem_req_valid_o(imem_line_req_valid_o),
    .mem_req_ready_i(imem_line_req_ready_i),
    .mem_req_addr_o(imem_line_req_addr_o),
    .mem_rsp_valid_i(imem_line_rsp_valid_i),
    .mem_rsp_data_i(imem_line_rsp_data_i)
  );

  rv32_dcache #(.SETS(DCACHE_SETS), .WAYS(DCACHE_WAYS)) u_dcache (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .cpu_req_valid_i(core_dmem_req_valid),
    .cpu_req_ready_o(core_dmem_req_ready),
    .cpu_req_write_i(core_dmem_req_write),
    .cpu_req_addr_i(core_dmem_req_addr),
    .cpu_req_wdata_i(core_dmem_req_wdata),
    .cpu_req_wstrb_i(core_dmem_req_wstrb),
    .cpu_req_size_i(core_dmem_req_size),
    .cpu_rsp_valid_o(core_dmem_rsp_valid),
    .cpu_rsp_data_o(core_dmem_rsp_data),
    .mem_req_valid_o(dmem_line_req_valid_o),
    .mem_req_ready_i(dmem_line_req_ready_i),
    .mem_req_write_o(dmem_line_req_write_o),
    .mem_req_addr_o(dmem_line_req_addr_o),
    .mem_req_wdata_o(dmem_line_req_wdata_o),
    .mem_rsp_valid_i(dmem_line_rsp_valid_i),
    .mem_rsp_data_i(dmem_line_rsp_data_i),
    .flush_i(core_halted), .flush_done_o(dcache_flush_done)
  );
endmodule
