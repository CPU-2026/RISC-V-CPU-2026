module rv32_frontend #(
  parameter int unsigned FQ_DEPTH = 4,
  parameter int unsigned IQ_DEPTH = 4,
  parameter logic [31:0] RESET_PC = 32'b0
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,

  output rv32_pkg::fetch_query_output_t predictorQueryOutput,
  input  rv32_pkg::prediction_output_t predictionInput,

  output rv32_pkg::instruction_memory_request_output_t imemRequestOutput,
  input  logic                   imemReqReadyInput,
  input  rv32_pkg::instruction_memory_response_input_t imemResponseInput,

  input  rv32_pkg::redirect_input_t redirectInput,

  output rv32_pkg::fetch_queue_output_t instructionOutput,
  input  logic                   iqReadyInput,

  output rv32_pkg::predictor_fetch_info_t fetchInfoOutput,

  output logic [$clog2(FQ_DEPTH+1)-1:0] fqCountOutput,
  output logic [$clog2(IQ_DEPTH+1)-1:0] iqCountOutput
);
  import rv32_pkg::*;

  localparam int unsigned FQ_PTR_W = $clog2(FQ_DEPTH);
  localparam int unsigned IQ_PTR_W = $clog2(IQ_DEPTH);
  localparam int unsigned FQ_COUNT_W = $clog2(FQ_DEPTH+1);
  localparam int unsigned IQ_COUNT_W = $clog2(IQ_DEPTH+1);

  logic [31:0] pcInner;
  logic requestPendingInner;
  logic requestDropInner;
  logic [31:0] requestPcInner;
  logic [31:0] requestPredictedPcInner;
  bpu_ckpt_id_t requestCkptIdInner;
  logic stopFetchInner;

  logic [31:0] fqPcInner [FQ_DEPTH];
  logic [31:0] fqInstrInner [FQ_DEPTH];
  logic [31:0] fqPredictedPcInner [FQ_DEPTH];
  bpu_ckpt_id_t fqCkptIdInner [FQ_DEPTH];
  logic [FQ_PTR_W-1:0] fqHeadInner, fqTailInner;
  logic [$clog2(FQ_DEPTH+1)-1:0] fqCountInner;

  logic [31:0] iqPcInner [IQ_DEPTH];
  logic [31:0] iqInstrInner [IQ_DEPTH];
  logic [31:0] iqPredictedPcInner [IQ_DEPTH];
  bpu_ckpt_id_t iqCkptIdInner [IQ_DEPTH];
  logic [IQ_PTR_W-1:0] iqHeadInner, iqTailInner;
  logic [$clog2(IQ_DEPTH+1)-1:0] iqCountInner;

  logic requestFireInner;
  logic responseAcceptInner;
  logic haltResponseInner;
  logic fireSpaceOkInner;
  logic fqPushInner;
  logic fqPopInner;
  logic iqPushInner;
  logic iqPopInner;
  integer iInner;

  logic [FQ_PTR_W-1:0] fqTailNext, fqHeadNext;
  logic [IQ_PTR_W-1:0] iqTailNext, iqHeadNext;
  logic [FQ_COUNT_W-1:0] fqCountUpInner, fqCountDownInner;
  logic [IQ_COUNT_W-1:0] iqCountUpInner, iqCountDownInner;
  logic unusedCoutFqTailInner, unusedCoutFqHeadInner;
  logic unusedCoutIqTailInner, unusedCoutIqHeadInner;
  logic unusedCoutFqUpInner, unusedBorrowFqDownInner;
  logic unusedCoutIqUpInner, unusedBorrowIqDownInner;

  logic lastFqPushInner;
  logic [31:0] lastFqInstrInner, lastFqPcInner;
  logic [6:0] fetchOpcodeInner;
  logic [2:0] fetchFunct3Inner;
  logic [4:0] fetchRdInner, fetchRs1Inner;
  logic fetchRdLinkInner, fetchRs1LinkInner;

  rv32_add #(.WIDTH(FQ_PTR_W)) u_fq_tail_next (
    .aInput(fqTailInner), .bInput(FQ_PTR_W'(1)), .cinInput(1'b0),
    .sumOutput(fqTailNext), .coutOutput(unusedCoutFqTailInner)
  );

  rv32_add #(.WIDTH(FQ_PTR_W)) u_fq_head_next (
    .aInput(fqHeadInner), .bInput(FQ_PTR_W'(1)), .cinInput(1'b0),
    .sumOutput(fqHeadNext), .coutOutput(unusedCoutFqHeadInner)
  );

  rv32_add #(.WIDTH(IQ_PTR_W)) u_iq_tail_next (
    .aInput(iqTailInner), .bInput(IQ_PTR_W'(1)), .cinInput(1'b0),
    .sumOutput(iqTailNext), .coutOutput(unusedCoutIqTailInner)
  );

  rv32_add #(.WIDTH(IQ_PTR_W)) u_iq_head_next (
    .aInput(iqHeadInner), .bInput(IQ_PTR_W'(1)), .cinInput(1'b0),
    .sumOutput(iqHeadNext), .coutOutput(unusedCoutIqHeadInner)
  );

  rv32_add #(.WIDTH(FQ_COUNT_W)) u_fq_count_up (
    .aInput(fqCountInner), .bInput(FQ_COUNT_W'(1)), .cinInput(1'b0),
    .sumOutput(fqCountUpInner), .coutOutput(unusedCoutFqUpInner)
  );

  rv32_sub #(.WIDTH(FQ_COUNT_W)) u_fq_count_down (
    .aInput(fqCountInner), .bInput(FQ_COUNT_W'(1)),
    .diffOutput(fqCountDownInner), .borrowOutput(unusedBorrowFqDownInner)
  );

  rv32_add #(.WIDTH(IQ_COUNT_W)) u_iq_count_up (
    .aInput(iqCountInner), .bInput(IQ_COUNT_W'(1)), .cinInput(1'b0),
    .sumOutput(iqCountUpInner), .coutOutput(unusedCoutIqUpInner)
  );

  rv32_sub #(.WIDTH(IQ_COUNT_W)) u_iq_count_down (
    .aInput(iqCountInner), .bInput(IQ_COUNT_W'(1)),
    .diffOutput(iqCountDownInner), .borrowOutput(unusedBorrowIqDownInner)
  );

  always_comb begin
    predictorQueryOutput.programCounter = pcInner;
    responseAcceptInner = imemResponseInput.valid && requestPendingInner;
    haltResponseInner = responseAcceptInner && (imemResponseInput.instruction == HALT_INSN);
    fireSpaceOkInner = responseAcceptInner
                    ? (fqCountInner <= $clog2(FQ_DEPTH+1)'(FQ_DEPTH - 2))
                    : (fqCountInner != $clog2(FQ_DEPTH+1)'(FQ_DEPTH));
    imemRequestOutput.valid = (responseAcceptInner || !requestPendingInner) &&
                       !haltResponseInner && fireSpaceOkInner &&
                       !stopFetchInner && !redirectInput.valid;
    imemRequestOutput.address = pcInner;
    requestFireInner = imemRequestOutput.valid && imemReqReadyInput;
    predictorQueryOutput.accepted = requestFireInner;
    fqPushInner = responseAcceptInner && !requestDropInner && !redirectInput.valid;
    fqPopInner = (fqCountInner != '0) &&
             (iqCountInner != $clog2(IQ_DEPTH+1)'(IQ_DEPTH)) &&
             !redirectInput.valid;
    iqPushInner = fqPopInner;
    fqCountOutput = fqCountInner;
    iqCountOutput = iqCountInner;
  end

  assign instructionOutput.valid = (iqCountInner != '0) && !redirectInput.valid;
  assign iqPopInner = instructionOutput.valid && iqReadyInput;
  assign instructionOutput.payload.programCounter = iqPcInner[iqHeadInner];
  assign instructionOutput.payload.instruction = iqInstrInner[iqHeadInner];
  assign instructionOutput.payload.predictedNextProgramCounter = iqPredictedPcInner[iqHeadInner];
  assign instructionOutput.payload.predictorCheckpointId = iqCkptIdInner[iqHeadInner];

  always_comb begin
    fetchOpcodeInner = lastFqInstrInner[6:0];
    fetchFunct3Inner = lastFqInstrInner[14:12];
    fetchRdInner = lastFqInstrInner[11:7];
    fetchRs1Inner = lastFqInstrInner[19:15];
    fetchRdLinkInner = (fetchRdInner == 5'd1) || (fetchRdInner == 5'd5);
    fetchRs1LinkInner = (fetchRs1Inner == 5'd1) || (fetchRs1Inner == 5'd5);

    fetchInfoOutput.valid = lastFqPushInner &&
                         ((fetchOpcodeInner == OPCODE_JAL) ||
                          ((fetchOpcodeInner == OPCODE_JALR) &&
                           (fetchFunct3Inner == 3'b000)));
    fetchInfoOutput.isCall = fetchInfoOutput.valid && fetchRdLinkInner;
    fetchInfoOutput.isReturn = fetchInfoOutput.valid &&
                           (fetchOpcodeInner == OPCODE_JALR) &&
                           fetchRs1LinkInner && !fetchRdLinkInner;
    fetchInfoOutput.jalTargetValid = fetchInfoOutput.valid &&
                                    (fetchOpcodeInner == OPCODE_JAL);
    fetchInfoOutput.programCounter = lastFqPcInner;
    fetchInfoOutput.jalTarget = lastFqPcInner +
                              {{11{lastFqInstrInner[31]}}, lastFqInstrInner[31],
                               lastFqInstrInner[19:12], lastFqInstrInner[20],
                               lastFqInstrInner[30:21], 1'b0};
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      pcInner <= RESET_PC;
      requestPendingInner <= 1'b0;
      requestDropInner <= 1'b0;
      requestPcInner <= '0;
      requestPredictedPcInner <= '0;
      requestCkptIdInner <= '0;
      stopFetchInner <= 1'b0;
      lastFqPushInner <= 1'b0;
      lastFqInstrInner <= '0;
      lastFqPcInner <= '0;
      fqHeadInner <= '0;
      fqTailInner <= '0;
      fqCountInner <= '0;
      iqHeadInner <= '0;
      iqTailInner <= '0;
      iqCountInner <= '0;
      for (iInner = 0; iInner < FQ_DEPTH; iInner = iInner + 1) begin
        fqPcInner[iInner] <= '0;
        fqInstrInner[iInner] <= '0;
        fqPredictedPcInner[iInner] <= '0;
        fqCkptIdInner[iInner] <= '0;
      end
      for (iInner = 0; iInner < IQ_DEPTH; iInner = iInner + 1) begin
        iqPcInner[iInner] <= '0;
        iqInstrInner[iInner] <= '0;
        iqPredictedPcInner[iInner] <= '0;
        iqCkptIdInner[iInner] <= '0;
      end
    end else if (redirectInput.valid) begin
      pcInner <= redirectInput.programCounter;
      fqHeadInner <= '0;
      fqTailInner <= '0;
      fqCountInner <= '0;
      iqHeadInner <= '0;
      iqTailInner <= '0;
      iqCountInner <= '0;
      stopFetchInner <= 1'b0;
      lastFqPushInner <= 1'b0;
      if (responseAcceptInner) begin
        requestPendingInner <= 1'b0;
        requestDropInner <= 1'b0;
      end else if (requestPendingInner) begin
        requestDropInner <= 1'b1;
      end
    end else begin
      if (requestFireInner) begin
        requestPendingInner <= 1'b1;
        requestDropInner <= 1'b0;
        requestPcInner <= pcInner;
        requestPredictedPcInner <= predictionInput.nextProgramCounter;
        requestCkptIdInner <= predictionInput.checkpointId;
        pcInner <= predictionInput.nextProgramCounter;
      end

      if (responseAcceptInner) begin
        if (!requestFireInner)
          requestPendingInner <= 1'b0;
        requestDropInner <= 1'b0;
        if (!requestDropInner) begin
          fqPcInner[fqTailInner] <= requestPcInner;
          fqInstrInner[fqTailInner] <= imemResponseInput.instruction;
          fqPredictedPcInner[fqTailInner] <= requestPredictedPcInner;
          fqCkptIdInner[fqTailInner] <= requestCkptIdInner;
          fqTailInner <= fqTailNext;
          if (imemResponseInput.instruction == HALT_INSN)
            stopFetchInner <= 1'b1;
        end
      end

      if (fqPopInner) begin
        iqPcInner[iqTailInner] <= fqPcInner[fqHeadInner];
        iqInstrInner[iqTailInner] <= fqInstrInner[fqHeadInner];
        iqPredictedPcInner[iqTailInner] <= fqPredictedPcInner[fqHeadInner];
        iqCkptIdInner[iqTailInner] <= fqCkptIdInner[fqHeadInner];
        fqHeadInner <= fqHeadNext;
        iqTailInner <= iqTailNext;
      end
      if (iqPopInner)
        iqHeadInner <= iqHeadNext;

      lastFqPushInner <= fqPushInner;
      if (fqPushInner) begin
        lastFqInstrInner <= imemResponseInput.instruction;
        lastFqPcInner <= requestPcInner;
      end

      unique case ({fqPushInner, fqPopInner})
        2'b10: fqCountInner <= fqCountUpInner;
        2'b01: fqCountInner <= fqCountDownInner;
        default: fqCountInner <= fqCountInner;
      endcase
      unique case ({iqPushInner, iqPopInner})
        2'b10: iqCountInner <= iqCountUpInner;
        2'b01: iqCountInner <= iqCountDownInner;
        default: iqCountInner <= iqCountInner;
      endcase
    end
  end
endmodule
