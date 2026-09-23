module rv32_icache #(
  parameter int unsigned SETS = 512
) (
  input  logic             clkInput,
  input  logic             rstNInput,

  input  rv32_pkg::icache_cpu_request_input_t cpuRequestInput,
  output logic             cpuReqReadyOutput,
  output rv32_pkg::icache_cpu_response_output_t cpuResponseOutput,

  output rv32_pkg::cache_line_request_output_t memRequestOutput,
  input  logic             memReqReadyInput,
  input  rv32_pkg::cache_line_response_input_t memResponseInput
);
  localparam int unsigned INDEX_W = $clog2(SETS);
  localparam int unsigned TAG_W = 32 - INDEX_W - 4;

  typedef enum logic [1:0] {IDLE, TAG_READ, MISS_REQUEST, MISS_WAIT} state_e;
  state_e stateInner;
  logic validInner [SETS];
  logic [TAG_W-1:0] tagInner [SETS];
  logic [31:0] missAddrInner;
  logic [INDEX_W-1:0] missIndexInner;
  logic [TAG_W-1:0] missTagInner;
  logic [1:0] missWordInner;
  logic rspValidInner;
  logic [31:0] rspDataInner;
  logic [INDEX_W-1:0] requestIndexInner;
  logic [TAG_W-1:0] requestTagInner;
  logic [1:0] requestWordInner;
  logic [127:0] sramRdataInner;
  logic [31:0] hitWordInner, refillWordInner;
  integer iInner;

  rv32_sram_1rw #(
    .ADDR_W(INDEX_W),
    .DATA_W(128),
    .MASK_W(16)
  ) u_data (
    .clkInput(clkInput),
    .rdEnInput(stateInner == IDLE && cpuRequestInput.valid),
    .rdAddrInput(requestIndexInner),
    .rdDataOutput(sramRdataInner),
    .wrEnInput(stateInner == MISS_WAIT && memResponseInput.valid),
    .wrAddrInput(missIndexInner),
    .wrDataInput(memResponseInput.data),
    .wrMaskInput(16'hffff)
  );

  always_comb begin
    requestIndexInner = cpuRequestInput.address[INDEX_W+3:4];
    requestTagInner = cpuRequestInput.address[31:INDEX_W+4];
    requestWordInner = cpuRequestInput.address[3:2];
    unique case (missWordInner)
      2'd0: hitWordInner = sramRdataInner[31:0];
      2'd1: hitWordInner = sramRdataInner[63:32];
      2'd2: hitWordInner = sramRdataInner[95:64];
      default: hitWordInner = sramRdataInner[127:96];
    endcase
    unique case (missWordInner)
      2'd0: refillWordInner = memResponseInput.data[31:0];
      2'd1: refillWordInner = memResponseInput.data[63:32];
      2'd2: refillWordInner = memResponseInput.data[95:64];
      default: refillWordInner = memResponseInput.data[127:96];
    endcase
    cpuReqReadyOutput = (stateInner == IDLE);
    cpuResponseOutput.valid = rspValidInner;
    cpuResponseOutput.instruction = rspDataInner;
    memRequestOutput.valid = (stateInner == MISS_REQUEST);
    memRequestOutput.write = 1'b0;
    memRequestOutput.address = {missAddrInner[31:4], 4'b0};
    memRequestOutput.writeData = '0;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      stateInner <= IDLE;
      missAddrInner <= '0;
      missIndexInner <= '0;
      missTagInner <= '0;
      missWordInner <= '0;
      rspValidInner <= 1'b0;
      rspDataInner <= '0;
      for (iInner = 0; iInner < SETS; iInner = iInner + 1)
        validInner[iInner] <= 1'b0;
    end else begin
      rspValidInner <= 1'b0;
      unique case (stateInner)
        IDLE: begin
          if (cpuRequestInput.valid && cpuReqReadyOutput) begin
            missAddrInner <= cpuRequestInput.address;
            missIndexInner <= requestIndexInner;
            missTagInner <= requestTagInner;
            missWordInner <= requestWordInner;
            stateInner <= TAG_READ;
          end
        end
        TAG_READ: begin
          if (validInner[missIndexInner] &&
              (tagInner[missIndexInner] == missTagInner)) begin
            rspValidInner <= 1'b1;
            rspDataInner <= hitWordInner;
            stateInner <= IDLE;
          end else begin
            stateInner <= MISS_REQUEST;
          end
        end
        MISS_REQUEST: begin
          if (memRequestOutput.valid && memReqReadyInput)
            stateInner <= MISS_WAIT;
        end
        MISS_WAIT: begin
          if (memResponseInput.valid) begin
            validInner[missIndexInner] <= 1'b1;
            tagInner[missIndexInner] <= missTagInner;
            rspValidInner <= 1'b1;
            rspDataInner <= refillWordInner;
            stateInner <= IDLE;
          end
        end
        default: stateInner <= IDLE;
      endcase
    end
  end
endmodule
