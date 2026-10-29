module rv32_frontend #(
  parameter int unsigned FETCH_WIDTH = 1,
  parameter int unsigned DECODE_WIDTH = 1,
  parameter int unsigned RENAME_WIDTH = 1,
  parameter int unsigned FQ_DEPTH = rv32_pkg::default_fq_entries(DECODE_WIDTH),
  parameter int unsigned IQ_DEPTH = rv32_pkg::default_iq_entries(DECODE_WIDTH),
  parameter int unsigned REQUEST_DEPTH = (rv32_pkg::FETCH_REQUEST_ENTRIES/FETCH_WIDTH > 1) ? rv32_pkg::FETCH_REQUEST_ENTRIES/FETCH_WIDTH : 2,
  parameter logic [31:0] RESET_PC = 32'b0,
  parameter bit LEGACY_HALT = 1'b0
) (
  input logic clkInput, rstNInput,
  input logic freezeInput,
  output rv32_pkg::fetch_query_output_t predictorQueryOutput,
  output logic [31:0] fetchProgramCounterOutput,
  input rv32_pkg::prediction_output_t predictionInput,
  input rv32_pkg::icache_fetch_hint_t fetchHintInput,
  input logic [31:0] imemSecondInstructionInput,
  output logic secondRequestOutput,
  output logic predictEnableOutput,
  output rv32_pkg::instruction_memory_request_output_t imemRequestOutput,
  input logic imemReqReadyInput,
  input rv32_pkg::instruction_memory_response_input_t imemResponseInput,
  output logic imemRspReadyOutput,
  output logic imemFlushOutput,
  input rv32_pkg::redirect_input_t redirectInput,
  output rv32_pkg::fetch_queue_output_t instructionOutput,
  output rv32_pkg::decoded_uop_t decodedOutput,
  input logic iqReadyInput,
  output rv32_pkg::fetch_queue_output_t instructionSecondOutput,
  output rv32_pkg::decoded_uop_t decodedSecondOutput,
  input logic iqSecondReadyInput,
  output rv32_pkg::predictor_fetch_info_t fetchInfoOutput,
  output logic [$clog2(FQ_DEPTH+1)-1:0] fqCountOutput,
  output logic [$clog2(IQ_DEPTH+1)-1:0] iqCountOutput,
  // New four-lane interface; legacy scalar/Second ports retain their behavior.
  output rv32_pkg::decoded_uop_t [3:0] decodedLanesOutput,
  output logic [3:0] iqLaneValidOutput,
  input logic [2:0] iqReadyCountInput,
  input logic [127:0] imemPacketInstructionsInput,
  output logic [2:0] fetchCountOutput
);
  import rv32_pkg::*;
  if (FETCH_WIDTH != 1 && FETCH_WIDTH != 2 && FETCH_WIDTH != 4) begin : g_invalid_fetch_width
    initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
  end
  if (FETCH_WIDTH==4 && (DECODE_WIDTH!=4 || RENAME_WIDTH!=4)) begin : g_invalid_four_transport
    initial $fatal(1, "four-fetch requires four-decode/four-allocation transport");
  end
  if (DECODE_WIDTH != 1 && DECODE_WIDTH != 2 && DECODE_WIDTH != 4) begin : g_invalid_decode_width
    initial $fatal(1, "DECODE_WIDTH must be 1, 2 or 4");
  end
  if (RENAME_WIDTH != 1 && RENAME_WIDTH != 2 && RENAME_WIDTH != 4) begin : g_invalid_rename_width
    initial $fatal(1, "RENAME_WIDTH must be 1, 2 or 4");
  end
  if (rv32_pkg::ROB_ENTRIES + REQUEST_DEPTH * FETCH_WIDTH + FQ_DEPTH + IQ_DEPTH >
      rv32_pkg::BPU_CKPT_ENTRIES) begin : g_invalid_checkpoint_budget
    initial $fatal(1, "frontend capacity exceeds checkpoint live budget");
  end
  localparam int unsigned REQ_SLOT_W = $clog2(REQUEST_DEPTH);
  localparam int unsigned REQ_SEQ_W = REQ_SLOT_W + 1;
  logic [31:0] pcInner;
  logic stopFetchInner;
  fetch_packet_context_t requestInner [REQUEST_DEPTH];
  logic [2:0] requestWordsInner [REQUEST_DEPTH];
  logic [2:0] packetCountInner;
  logic [1:0] queryLaneInner;
  logic packetPredictInner;
  logic [3:0] controlLanesInner;
  logic [REQ_SEQ_W-1:0] reqHeadInner, reqTailInner, reqCountInner;
  logic [REQ_SLOT_W-1:0] reqHeadSlotInner, reqTailSlotInner;
  logic requestFireInner, responseAcceptInner, haltResponseInner;
  logic fetchAllowedInner;
  logic fqReadyInner, fqValidInner, iqReadyInner;
  logic fqPushInner, fqPopInner;
  decode_context_t fqInputInner, fqHeadInner, iqHeadInner;
  fetch_packet_t fqPacketInputInner;
  logic secondAllowedInner,querySecondInner;
  logic [31:0] packetNextPcInner;
  logic lastFqPushInner;
  logic [31:0] lastFqInstrInner, lastFqPcInner;
  integer iInner;

  function automatic logic is_control(input logic [31:0] instruction);
    return instruction[6:0]==OPCODE_BRANCH || instruction[6:0]==OPCODE_JAL ||
      (instruction[6:0]==OPCODE_JALR && instruction[14:12]==3'b000);
  endfunction
  // Cold misses use the existing single-PC predictor conservatively. Hit
  // metadata identifies the earliest CFI BEFORE data returns. A packet ends
  // at that CFI even when it is predicted not taken.
  assign controlLanesInner={fetchHintInput.fourthControl,fetchHintInput.thirdControl,
    fetchHintInput.secondControl,fetchHintInput.firstControl};
  always_comb begin
    bit open;
    open=1'b1;
    packetCountInner=3'd1;
    queryLaneInner='0;
    packetPredictInner=1'b1;
    if (FETCH_WIDTH==4 && !LEGACY_HALT && fetchHintInput.hit) begin
      packetCountInner='0;
      packetPredictInner=1'b0;
      for (int lane=0;lane<4;lane++) begin
        if (open && lane<4-int'(pcInner[3:2])) begin
          packetCountInner=3'(lane+1);
          queryLaneInner=2'(lane);
          packetPredictInner=controlLanesInner[lane];
          if (controlLanesInner[lane]) open=1'b0;
        end
      end
    end else if (FETCH_WIDTH==2 && !LEGACY_HALT && fetchHintInput.hit) begin
      if (!pcInner[2] && !fetchHintInput.firstControl) begin
        packetCountInner=3'd2;
        queryLaneInner=fetchHintInput.secondControl ? 2'd1 : 2'd0;
      end
      packetPredictInner=fetchHintInput.firstControl ||
        (packetCountInner==2 && fetchHintInput.secondControl);
    end
  end
  assign fetchCountOutput=packetCountInner;
  assign secondAllowedInner=packetCountInner>1;
  assign querySecondInner=queryLaneInner==1;
  assign secondRequestOutput=secondAllowedInner;
  assign predictEnableOutput=packetPredictInner;
  assign packetNextPcInner=predictEnableOutput?predictionInput.nextProgramCounter:
    pcInner+(32'(packetCountInner)<<2);

  assign reqCountInner = reqTailInner - reqHeadInner;
  assign reqHeadSlotInner = reqHeadInner[REQ_SLOT_W-1:0];
  assign reqTailSlotInner = reqTailInner[REQ_SLOT_W-1:0];
  // Prediction is combinational. I$ retains the instruction until the same
  // FQ acceptance edge; no SRAM-BTB join queue or prediction pipeline remains.
  assign imemRspReadyOutput = rstNInput && !freezeInput && !redirectInput.valid && !stopFetchInner &&
    reqCountInner != 0 && fqReadyInner;
  assign imemFlushOutput = redirectInput.valid;
  assign responseAcceptInner = imemResponseInput.valid && imemRspReadyOutput;
  assign haltResponseInner = LEGACY_HALT && responseAcceptInner &&
      imemResponseInput.instruction == HALT_INSN;
  assign fetchAllowedInner = rstNInput && !freezeInput &&
        (reqCountInner < REQ_SEQ_W'(REQUEST_DEPTH) || responseAcceptInner) &&
        fqReadyInner && !haltResponseInner && !stopFetchInner && !redirectInput.valid;
  assign imemRequestOutput.valid = fetchAllowedInner;
  assign imemRequestOutput.address = pcInner;
  assign imemRequestOutput.predictedProgramCounter = packetNextPcInner;
  assign imemRequestOutput.predictorCheckpointId = predictionInput.checkpointId;
  assign predictorQueryOutput.programCounter = pcInner + (32'(queryLaneInner)<<2);
  assign fetchProgramCounterOutput = pcInner;
  assign predictorQueryOutput.accepted = requestFireInner;
  always_comb begin
    fqInputInner = '{instruction:imemResponseInput.instruction,
      programCounter:requestInner[reqHeadSlotInner].programCounter,
      predictedNextProgramCounter:requestInner[reqHeadSlotInner].predictedNextProgramCounter,
      predictorCheckpointId:requestInner[reqHeadSlotInner].predictorCheckpointId};
    fqPacketInputInner = '{instructions:{imemSecondInstructionInput,imemResponseInput.instruction},
      metadata:requestInner[reqHeadSlotInner]};
  end
  assign requestFireInner = imemRequestOutput.valid && imemReqReadyInput;
  assign fqPushInner = responseAcceptInner;
  assign fqPopInner = fqValidInner && iqReadyInner;
  if (DECODE_WIDTH!=4 && RENAME_WIDTH!=4) begin : g_no_wide_interface
    assign decodedLanesOutput='0;
    assign iqLaneValidOutput='0;
  end
  generate if (DECODE_WIDTH == 1 && RENAME_WIDTH == 1) begin : g_single_decode
  assign decodedOutput = '0; // Scalar core retains its original IQ-head decoder.
  assign decodedSecondOutput = '0;
  assign instructionSecondOutput = '0;
  if(FETCH_WIDTH==2)begin : g_packet
    rv32_fetch_packet_fifo #(.DEPTH(FQ_DEPTH)) u_fq (
      .freezeInput(freezeInput), .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(redirectInput.valid),
      .inValidInput(fqPushInner), .inReadyOutput(fqReadyInner), .inDataInput(fqPacketInputInner),
      .outValidOutput(fqValidInner), .outReadyInput(iqReadyInner), .outDataOutput(fqHeadInner), .countOutput(fqCountOutput)
    );
  end else begin : g_scalar
  rv32_epoch_fifo #(.DEPTH(FQ_DEPTH), .WIDTH($bits(decode_context_t))) u_fq (
    .freezeInput(freezeInput),
    .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(redirectInput.valid),
    .inValidInput(fqPushInner), .inReadyOutput(fqReadyInner), .inDataInput(fqInputInner),
    .outValidOutput(fqValidInner), .outReadyInput(iqReadyInner), .outDataOutput(fqHeadInner),
    .countOutput(fqCountOutput)
  );
  end
  rv32_epoch_fifo #(.DEPTH(IQ_DEPTH), .WIDTH($bits(decode_context_t))) u_iq (
    .freezeInput(freezeInput),
    .clkInput(clkInput), .rstNInput(rstNInput), .flushInput(redirectInput.valid),
    .inValidInput(fqValidInner), .inReadyOutput(iqReadyInner), .inDataInput(fqHeadInner),
    .outValidOutput(instructionOutput.valid), .outReadyInput(iqReadyInput),
    .outDataOutput(iqHeadInner), .countOutput(iqCountOutput)
  );
  assign instructionOutput.payload = iqHeadInner;
  end else if (DECODE_WIDTH==4 || RENAME_WIDTH==4) begin : g_wide_decode
    localparam int PACKET_WIDTH=FETCH_WIDTH==4 ? 4 : 2;
    decode_context_t [PACKET_WIDTH-1:0] packetWords;
    decoded_uop_t [RENAME_WIDTH-1:0] queueDecoded;
    logic [RENAME_WIDTH-1:0] queueValid;
    logic [$clog2(PACKET_WIDTH+1)-1:0] inputCount;
    logic [$clog2(RENAME_WIDTH+1)-1:0] readyCount;
    assign inputCount=$bits(inputCount)'(requestWordsInner[reqHeadSlotInner]);
    always_comb begin
      packetWords='0;
      for (int lane=0;lane<PACKET_WIDTH;lane++) begin
        packetWords[lane]=fqInputInner;
        packetWords[lane].instruction=FETCH_WIDTH==4 ? imemPacketInstructionsInput[32*lane+:32] :
          (lane==0 ? imemResponseInput.instruction : imemSecondInstructionInput);
        packetWords[lane].programCounter=fqInputInner.programCounter+32'(lane*4);
        packetWords[lane].predictorCheckpointId=fqInputInner.predictorCheckpointId+bpu_ckpt_id_t'(lane);
        if (lane+1<int'(inputCount))
          packetWords[lane].predictedNextProgramCounter=fqInputInner.programCounter+32'((lane+1)*4);
      end
    end
    if (RENAME_WIDTH==4) begin : g_array_acceptance
      assign readyCount=iqReadyCountInput;
    end else begin : g_legacy_acceptance
      assign readyCount=$clog2(RENAME_WIDTH+1)'(iqReadyInput)+
        $clog2(RENAME_WIDTH+1)'(RENAME_WIDTH==2 && iqSecondReadyInput);
    end
    rv32_decode_issue_queue #(.DECODE_WIDTH(DECODE_WIDTH), .ISSUE_WIDTH(RENAME_WIDTH),
         .FQ_DEPTH(FQ_DEPTH), .IQ_DEPTH(IQ_DEPTH), .LEGACY_HALT(LEGACY_HALT), .FETCH_WIDTH(PACKET_WIDTH)) u_decode_issue (
      .clkInput, .rstNInput, .freezeInput, .flushInput(redirectInput.valid),
      .inValidInput(fqPushInner), .inCountInput(inputCount), .inDataInput(packetWords),
      .inReadyOutput(fqReadyInner), .decodedOutput(queueDecoded), .validOutput(queueValid),
      .readyCountInput(readyCount), .availableCountOutput(), .decodeFireCountOutput(),
      .fqCountOutput, .iqCountOutput
    );
    for (genvar lane=0; lane<4; lane++) begin : g_array_head
      if (lane<RENAME_WIDTH) begin
        assign decodedLanesOutput[lane]=queueDecoded[lane];
        assign iqLaneValidOutput[lane]=queueValid[lane];
      end else begin
        assign decodedLanesOutput[lane]='0;
        assign iqLaneValidOutput[lane]=1'b0;
      end
    end
    assign decodedOutput=queueDecoded[0];
    assign instructionOutput.valid=queueValid[0];
    assign instructionOutput.payload='{instruction:decodedOutput.instruction,
      programCounter:decodedOutput.programCounter, predictedNextProgramCounter:decodedOutput.predictedNextProgramCounter,
      predictorCheckpointId:decodedOutput.predictorCheckpointId};
    if (RENAME_WIDTH>=2) begin : g_second_head
      assign decodedSecondOutput=queueDecoded[1];
      assign instructionSecondOutput.valid=queueValid[1];
      assign instructionSecondOutput.payload='{instruction:decodedSecondOutput.instruction,
        programCounter:decodedSecondOutput.programCounter, predictedNextProgramCounter:decodedSecondOutput.predictedNextProgramCounter,
        predictorCheckpointId:decodedSecondOutput.predictorCheckpointId};
    end else begin
      assign decodedSecondOutput='0;
      assign instructionSecondOutput='0;
    end
    assign fqValidInner=1'b0;
    assign iqReadyInner=1'b0;
    assign fqHeadInner='0;
    assign iqHeadInner=instructionOutput.payload;
  end else begin : g_multi_decode
    // Expand packet transport into instruction credits. Unlike the old
    // experimental software grouping, each instruction keeps its own CID.
    localparam int unsigned FQ_COUNT_W = $clog2(FQ_DEPTH) + 1;
    localparam int unsigned IQ_COUNT_W = $clog2(IQ_DEPTH) + 1;
    decode_context_t [1:0] fqDataInner, fqWordsInner;
    decoded_uop_t [1:0] decodedWordsInner;
    logic [RENAME_WIDTH-1:0][$bits(decoded_uop_t)-1:0] iqWordsInner;
    logic [1:0] inputWordsInner, availableWordsInner, decodeCountInner;
    logic [$clog2(RENAME_WIDTH+1)-1:0] iqAvailableInner, issueCountInner;
    logic [FQ_COUNT_W-1:0] fqCapacityInner, fqOccupancyInner;
    logic [IQ_COUNT_W-1:0] iqCapacityInner, iqOccupancyInner;
    logic iqAcceptInner;
    assign inputWordsInner = FETCH_WIDTH == 2 &&
      requestInner[reqHeadSlotInner].secondValid ? 2'd2 : 2'd1;
    always_comb begin
      fqDataInner = '0;
      fqDataInner[0] = fqInputInner;
      if (inputWordsInner == 2) begin
        fqDataInner[0].predictedNextProgramCounter = fqInputInner.programCounter | 32'd4;
        fqDataInner[1] = '{instruction: imemSecondInstructionInput,
          programCounter: fqInputInner.programCounter | 32'd4,
          predictedNextProgramCounter: fqInputInner.predictedNextProgramCounter,
          predictorCheckpointId: fqInputInner.predictorCheckpointId + bpu_ckpt_id_t'(1)};
      end
    end
    always_comb begin
      decodeCountInner = int'(availableWordsInner) < int'(iqCapacityInner) ?
        availableWordsInner : 2'(iqCapacityInner);
      if (decodeCountInner > 2'(DECODE_WIDTH)) decodeCountInner = 2'(DECODE_WIDTH);
    end
    assign issueCountInner = $clog2(RENAME_WIDTH+1)'(iqReadyInput) +
      $clog2(RENAME_WIDTH+1)'(RENAME_WIDTH == 2 && iqSecondReadyInput);
    rv32_prefix_fifo #(.DEPTH(FQ_DEPTH), .WIDTH($bits(decode_context_t))) u_fq (
      .clkInput(clkInput), .rstNInput(rstNInput), .freezeInput(freezeInput), .flushInput(redirectInput.valid),
      .inValidInput(fqPushInner), .inCountInput(inputWordsInner), .inDataInput(fqDataInner),
      .inReadyOutput(fqReadyInner), .inCapacityOutput(fqCapacityInner),
      .outCountOutput(availableWordsInner), .outDataOutput(fqWordsInner),
      .outReadyCountInput(decodeCountInner), .countOutput(fqOccupancyInner)
    );
    for (genvar lane = 0; lane < 2; lane++) begin : g_decoder
      if (lane < DECODE_WIDTH) begin : g_enabled
      rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder (
        .decodeContextInput(fqWordsInner[lane]), .uopOutput(decodedWordsInner[lane])
      );
      end else assign decodedWordsInner[lane] = '0;
    end
    rv32_prefix_fifo #(.DEPTH(IQ_DEPTH), .WIDTH($bits(decoded_uop_t)), .POP_WIDTH(RENAME_WIDTH)) u_iq (
      .clkInput(clkInput), .rstNInput(rstNInput), .freezeInput(freezeInput), .flushInput(redirectInput.valid),
      .inValidInput(decodeCountInner != 0), .inCountInput(decodeCountInner), .inDataInput(decodedWordsInner),
      .inReadyOutput(iqAcceptInner), .inCapacityOutput(iqCapacityInner),
      .outCountOutput(iqAvailableInner), .outDataOutput(iqWordsInner),
      .outReadyCountInput(issueCountInner), .countOutput(iqOccupancyInner)
    );
    assign decodedOutput = decoded_uop_t'(iqWordsInner[0]);
    assign instructionOutput.valid = iqAvailableInner != 0;
    assign instructionOutput.payload = '{instruction: decodedOutput.instruction,
      programCounter: decodedOutput.programCounter,
      predictedNextProgramCounter: decodedOutput.predictedNextProgramCounter,
      predictorCheckpointId: decodedOutput.predictorCheckpointId};
    if (RENAME_WIDTH == 2) begin : g_second_head
      assign decodedSecondOutput = decoded_uop_t'(iqWordsInner[1]);
      assign instructionSecondOutput.valid = iqAvailableInner > 1;
      assign instructionSecondOutput.payload = '{instruction: decodedSecondOutput.instruction,
        programCounter: decodedSecondOutput.programCounter,
        predictedNextProgramCounter: decodedSecondOutput.predictedNextProgramCounter,
        predictorCheckpointId: decodedSecondOutput.predictorCheckpointId};
    end else begin : g_no_second_head
      assign decodedSecondOutput = '0;
      assign instructionSecondOutput = '0;
    end
    assign fqCountOutput = $clog2(FQ_DEPTH+1)'(fqOccupancyInner);
    assign iqCountOutput = $clog2(IQ_DEPTH+1)'(iqOccupancyInner);
    // The scalar-only signals are not used in this static configuration.
    assign fqValidInner = availableWordsInner != 0;
    assign iqReadyInner = decodeCountInner != 0;
    assign fqHeadInner = fqWordsInner[0];
    assign iqHeadInner = instructionOutput.payload;
`ifndef SYNTHESIS
    always @(posedge clkInput) if (rstNInput && !freezeInput && !redirectInput.valid) begin
      assert (decodeCountInner == 0 || iqAcceptInner) else $fatal(1, "decoded prefix not accepted atomically");
      assert (int'(decodeCountInner) <= int'(availableWordsInner));
      assert (!iqSecondReadyInput || RENAME_WIDTH == 1 || iqReadyInput)
        else $fatal(1, "IQ issue must consume an ordered prefix");
    end
`endif
  end endgenerate

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
        requestWordsInner[iInner] <= '0;
      end
    end else if (!freezeInput) begin
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
          requestInner[reqTailSlotInner] <= '{programCounter: pcInner,
            predictedNextProgramCounter: packetNextPcInner,
            predictorCheckpointId: predictionInput.checkpointId, secondValid:secondAllowedInner};
          requestWordsInner[reqTailSlotInner] <= packetCountInner;
          reqTailInner <= reqTailInner + REQ_SEQ_W'(1);
          pcInner <= packetNextPcInner;
        end
        if (haltResponseInner) begin
          stopFetchInner <= 1;
        end
        lastFqPushInner <= fqPushInner && fqReadyInner;
        if (fqPushInner && fqReadyInner) begin
          if (FETCH_WIDTH==4) begin
            lastFqInstrInner <= imemPacketInstructionsInput[(int'(requestWordsInner[reqHeadSlotInner])-1)*32+:32];
            lastFqPcInner <= requestInner[reqHeadSlotInner].programCounter+
              ((32'(requestWordsInner[reqHeadSlotInner])-32'd1)<<2);
          end else if(requestInner[reqHeadSlotInner].secondValid&&!is_control(imemResponseInput.instruction))begin
            lastFqInstrInner <= imemSecondInstructionInput;
            lastFqPcInner <= requestInner[reqHeadSlotInner].programCounter+32'd4;
          end else begin
            lastFqInstrInner <= imemResponseInput.instruction;
            lastFqPcInner <= requestInner[reqHeadSlotInner].programCounter;
          end
        end
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput) begin
    assert (reqCountInner <= REQ_SEQ_W'(REQUEST_DEPTH)) else $fatal(1, "fetch transaction overflow");
    assert (!fqPushInner || fqReadyInner) else $fatal(1, "unaccepted FQ response");
    if(FETCH_WIDTH==2&&secondAllowedInner)assert(!pcInner[2]&&fetchHintInput.hit&&!fetchHintInput.firstControl);
    if (FETCH_WIDTH==4 && requestFireInner) begin
      assert(packetCountInner>=1 && int'(packetCountInner)<=4-int'(pcInner[3:2]))
        else $fatal(1,"four-fetch packet crossed aligned boundary");
      for (int lane=0;lane<3;lane++) if (lane+1<int'(packetCountInner))
        assert(fetchHintInput.hit && !controlLanesInner[lane]) else $fatal(1,"four-fetch passed earliest CFI");
    end
    if (FETCH_WIDTH==4 && responseAcceptInner)
      for (int lane=0;lane<3;lane++) if (lane+1<int'(requestWordsInner[reqHeadSlotInner]))
        assert(!is_control(imemPacketInstructionsInput[lane*32+:32])) else $fatal(1,"four-fetch response crossed earliest CFI");
    if(FETCH_WIDTH==2&&responseAcceptInner&&requestInner[reqHeadSlotInner].secondValid)
      assert(!is_control(imemResponseInput.instruction)) else $fatal(1,"packet crossed its earliest CFI");
  end
`endif
endmodule
