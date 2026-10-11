module rv32_frontend #(
  parameter int unsigned FQ_DEPTH = 4,
  parameter int unsigned IQ_DEPTH = 4,
  parameter int unsigned REQUEST_DEPTH = rv32_pkg::FETCH_REQUEST_ENTRIES,
  parameter logic [31:0] RESET_PC = 32'b0
) (
  input logic clkInput, rstNInput,
  output rv32_pkg::fetch_query_output_t predictorQueryOutput,
  output logic [31:0] fetchProgramCounterOutput,
  input rv32_pkg::prediction_output_t predictionInput,
  output rv32_pkg::instruction_memory_request_output_t imemRequestOutput,
  input logic imemReqReadyInput,
  input rv32_pkg::instruction_memory_response_input_t imemResponseInput,
  output logic imemRspReadyOutput,
  output logic imemFlushOutput,
  input rv32_pkg::redirect_input_t redirectInput,
  output rv32_pkg::fetch_queue_output_t instructionOutput,
  input logic iqReadyInput,
  output rv32_pkg::predictor_fetch_info_t fetchInfoOutput,
  output logic [$clog2(FQ_DEPTH+1)-1:0] fqCountOutput,
  output logic [$clog2(IQ_DEPTH+1)-1:0] iqCountOutput
);
  import rv32_pkg::*;
  localparam int unsigned REQ_SLOT_W = $clog2(REQUEST_DEPTH);
  localparam int unsigned REQ_SEQ_W = REQ_SLOT_W + 1;
  logic [31:0] pcInner;
  logic stopFetchInner;
  decode_context_t requestInner [REQUEST_DEPTH];
  logic [REQ_SEQ_W-1:0] reqHeadInner, reqTailInner, reqCountInner;
  logic [REQ_SLOT_W-1:0] reqHeadSlotInner, reqTailSlotInner;
  logic requestFireInner, responseAcceptInner, haltResponseInner;
  logic fetchAllowedInner;
  logic fqReadyInner, fqValidInner, iqReadyInner;
  logic fqPushInner, fqPopInner;
  decode_context_t fqInputInner, fqHeadInner, iqHeadInner;
  logic lastFqPushInner;
  logic [31:0] lastFqInstrInner, lastFqPcInner;
  integer iInner;

  assign reqCountInner = reqTailInner - reqHeadInner;
  assign reqHeadSlotInner = reqHeadInner[REQ_SLOT_W-1:0];
  assign reqTailSlotInner = reqTailInner[REQ_SLOT_W-1:0];
  // Return remains in I$ until FQ really accepts it. No advance/reservation
  // release merely because a response was offered to a full FQ.
  assign imemRspReadyOutput = rstNInput && !redirectInput.valid && !stopFetchInner &&
    reqCountInner != 0 && fqReadyInner;
  assign imemFlushOutput = redirectInput.valid;
  assign responseAcceptInner = imemResponseInput.valid && imemRspReadyOutput;
  assign haltResponseInner = fqPushInner && fqReadyInner &&
      imemResponseInput.instruction == HALT_INSN;
  // Keep acceptance independent of prediction payload and its accepted query;
  // no packed-output combinational feedback through the prediction bundle.
  assign fetchAllowedInner = rstNInput &&
        (reqCountInner < REQ_SEQ_W'(REQUEST_DEPTH) || responseAcceptInner) &&
        fqReadyInner && !haltResponseInner && !stopFetchInner && !redirectInput.valid;
  assign imemRequestOutput.valid = fetchAllowedInner;
  assign imemRequestOutput.address = pcInner;
  assign imemRequestOutput.predictedProgramCounter = predictionInput.nextProgramCounter;
  assign imemRequestOutput.predictorCheckpointId = predictionInput.checkpointId;
  assign predictorQueryOutput.programCounter = pcInner;
  assign fetchProgramCounterOutput = pcInner;
  assign predictorQueryOutput.accepted = requestFireInner;
  always_comb begin
    fqInputInner = requestInner[reqHeadSlotInner];
    fqInputInner.instruction = imemResponseInput.instruction;
  end
  assign requestFireInner = fetchAllowedInner && imemReqReadyInput;
  assign fqPushInner = responseAcceptInner;
  assign fqPopInner = fqValidInner && iqReadyInner;
  rv32_epoch_fifo #(.DEPTH(FQ_DEPTH), .WIDTH($bits(decode_context_t))) u_fq (
    .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(redirectInput.valid),
    .inValidInput(fqPushInner), .inReadyOutput(fqReadyInner), .inDataInput(fqInputInner),
    .outValidOutput(fqValidInner), .outReadyInput(iqReadyInner), .outDataOutput(fqHeadInner),
    .countOutput(fqCountOutput)
  );
  rv32_epoch_fifo #(.DEPTH(IQ_DEPTH), .WIDTH($bits(decode_context_t))) u_iq (
    .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(redirectInput.valid),
    .inValidInput(fqValidInner), .inReadyOutput(iqReadyInner), .inDataInput(fqHeadInner),
    .outValidOutput(instructionOutput.valid), .outReadyInput(iqReadyInput),
    .outDataOutput(iqHeadInner), .countOutput(iqCountOutput)
  );
  assign instructionOutput.payload = iqHeadInner;

  always_comb begin
    fetchInfoOutput = '0;
    fetchInfoOutput.valid = lastFqPushInner &&
      (lastFqInstrInner[6:0] == OPCODE_JAL ||
       (lastFqInstrInner[6:0] == OPCODE_JALR && lastFqInstrInner[14:12] == 0));
    fetchInfoOutput.isCall = fetchInfoOutput.valid &&
      (lastFqInstrInner[11:7] == 1 || lastFqInstrInner[11:7] == 5);
    fetchInfoOutput.isReturn = fetchInfoOutput.valid &&
      lastFqInstrInner[6:0] == OPCODE_JALR &&
      (lastFqInstrInner[19:15] == 1 || lastFqInstrInner[19:15] == 5);
    fetchInfoOutput.jalTargetValid = fetchInfoOutput.valid && lastFqInstrInner[6:0] == OPCODE_JAL;
    fetchInfoOutput.programCounter = lastFqPcInner;
    fetchInfoOutput.jalTarget = lastFqPcInner +
      {{11{lastFqInstrInner[31]}}, lastFqInstrInner[31], lastFqInstrInner[19:12],
       lastFqInstrInner[20], lastFqInstrInner[30:21], 1'b0};
  end
  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      pcInner <= RESET_PC;
      stopFetchInner <= 0;
      reqHeadInner <= 0;
      reqTailInner <= 0;
      lastFqPushInner <= 0;
      lastFqInstrInner <= 0;
      lastFqPcInner <= 0;
      for (iInner = 0; iInner < REQUEST_DEPTH; iInner++) begin
        requestInner[iInner] <= '0;
      end
    end else begin
      if (responseAcceptInner)
        reqHeadInner <= reqHeadInner + REQ_SEQ_W'(1);
      if (redirectInput.valid) begin
        pcInner <= redirectInput.programCounter;
        stopFetchInner <= 0;
        lastFqPushInner <= 0;
        reqHeadInner <= 0;
        reqTailInner <= 0;
      end else begin
        if (requestFireInner) begin
          requestInner[reqTailSlotInner] <= '{instruction: 32'b0, programCounter: pcInner,
            predictedNextProgramCounter: predictionInput.nextProgramCounter,
            predictorCheckpointId: predictionInput.checkpointId};
          reqTailInner <= reqTailInner + REQ_SEQ_W'(1);
          pcInner <= predictionInput.nextProgramCounter;
        end
        if (haltResponseInner) stopFetchInner <= 1;
        lastFqPushInner <= fqPushInner && fqReadyInner;
        if (fqPushInner && fqReadyInner) begin
          lastFqInstrInner <= imemResponseInput.instruction;
          lastFqPcInner <= requestInner[reqHeadSlotInner].programCounter;
        end
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    assert (reqCountInner <= REQ_SEQ_W'(REQUEST_DEPTH)) else $fatal(1, "fetch transaction overflow");
    assert (!fqPushInner || fqReadyInner) else $fatal(1, "unaccepted FQ response");
  end
`endif
endmodule
