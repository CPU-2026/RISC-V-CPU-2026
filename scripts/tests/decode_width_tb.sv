// Independent scalar queues model packet expansion, prefix decode and issue.
module tb_decode_width #(
  parameter int unsigned FETCH = 2,
  parameter int unsigned DECODE = 2,
  parameter int unsigned FQ = 2 * DECODE,
  parameter int unsigned IQ = 2 * DECODE
);
  import rv32_pkg::*;
  logic clk = 0, rstN = 0, freeze, issueReady, responseReady, flush;
  fetch_query_output_t query;
  prediction_output_t prediction;
  icache_fetch_hint_t hint;
  instruction_memory_request_output_t request;
  instruction_memory_response_input_t response;
  redirect_input_t redirect;
  fetch_queue_output_t instruction;
  decoded_uop_t decoded, referenceDecoded;
  predictor_fetch_info_t fetchInfo;
  logic second, predictEnable, requestReady;
  logic [31:0] fetchPc, responseSecond;
  logic [$clog2(FQ+1)-1:0] fqCount;
  logic [$clog2(IQ+1)-1:0] iqCount;
  decode_context_t referenceHead;
  decode_context_t fqModel[$], iqModel[$];
  fetch_packet_context_t requests[$];
  int unsigned rng = 32'h6712abe9;
  int unsigned issued = 0, doubleDecoded = 0, partialDecoded = 0;
  int unsigned dualPackets = 0, flushes = 0, freezes = 0, replacements = 0, cidWraps = 0;
  int unsigned nextCid = 31;

  rv32_frontend #(.FETCH_WIDTH(FETCH), .DECODE_WIDTH(DECODE), .FQ_DEPTH(FQ), .IQ_DEPTH(IQ)) dut (
    .clkInput(clk), .rstNInput(rstN), .freezeInput(freeze), .predictorQueryOutput(query),
    .fetchProgramCounterOutput(fetchPc), .predictionInput(prediction), .fetchHintInput(hint),
    .imemSecondInstructionInput(responseSecond), .secondRequestOutput(second), .predictEnableOutput(predictEnable),
    .imemRequestOutput(request), .imemReqReadyInput(requestReady), .imemResponseInput(response),
    .imemRspReadyOutput(responseReady), .imemFlushOutput(flush), .redirectInput(redirect),
    .instructionOutput(instruction), .decodedOutput(decoded), .iqReadyInput(issueReady),
    .fetchInfoOutput(fetchInfo), .fqCountOutput(fqCount), .iqCountOutput(iqCount)
  );
  rv32_decoder referenceDecoder (.decodeContextInput(referenceHead), .uopOutput(referenceDecoded));

  function automatic int unsigned random_word();
    rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5;
    return rng;
  endfunction
  function automatic logic [31:0] raw(input logic [31:0] pc);
    case (pc[5:2])
      2: return 32'h00000263; // BEQ +4: still terminates a packet.
      5: return 32'h004000ef; // JAL +4.
      9: return 32'h00008067; // JALR: per-instruction metadata must survive.
      11: return 32'h0220c1b3; // DIV.
      13: return 32'h022081b3; // MUL.
      14: return 32'h00310223; // SW.
      15: return 32'h00412283; // LW.
      default: return {pc[11:0], 5'd2, 3'b000, 5'd3, 7'h13};
    endcase
  endfunction
  function automatic bit control(input logic [31:0] insn);
    return insn[6:0] == OPCODE_BRANCH || insn[6:0] == OPCODE_JAL || insn[6:0] == OPCODE_JALR;
  endfunction

  initial begin
    freeze = 0; issueReady = 0; redirect = '0; prediction = '0; hint = '0;
    response = '0; responseSecond = 0; requestReady = 0; referenceHead = '0;
    #1; clk = 1; #1; clk = 0; rstN = 1;
    for (int cycle = 0; cycle < 12000; cycle++) begin
      int decodeCount, popCount;
      bit responseFire, requestFire;
      fetch_packet_context_t packet;
      decode_context_t word0, word1;
      freeze = random_word() % 7 == 0;
      issueReady = random_word() % 4 != 0;
      redirect.valid = random_word() % 47 == 0;
      redirect.programCounter = random_word() & 32'h7fc;
      requestReady = random_word() % 5 != 0;
      hint.hit = random_word() % 4 != 0;
      #1;
      hint.firstControl = control(raw(fetchPc));
      hint.secondControl = control(raw(fetchPc + 4));
      #1;
      prediction = '0;
      prediction.nextProgramCounter = query.programCounter + 4;
      prediction.checkpointId = bpu_ckpt_id_t'(nextCid);
      response = '0;
      responseSecond = 0;
      if (requests.size() != 0 && random_word() % 4 != 0) begin
        response.valid = 1;
        response.instruction = raw(requests[0].programCounter);
        responseSecond = raw(requests[0].programCounter + 4);
      end
      referenceHead = iqModel.size() ? iqModel[0] : decode_context_t'('0);
      #1;
      assert (int'(fqCount) == fqModel.size()) else $fatal(1, "FQ occupancy cycle=%0d", cycle);
      assert (int'(iqCount) == iqModel.size()) else $fatal(1, "IQ occupancy cycle=%0d", cycle);
      assert (instruction.valid == (iqModel.size() != 0 && !redirect.valid)) else $fatal(1, "IQ valid");
      if (instruction.valid) begin
        assert (instruction.payload == referenceHead) else $fatal(1, "IQ context cycle=%0d", cycle);
        if (DECODE == 2)
          assert (decoded == referenceDecoded) else $fatal(1, "decoded payload cycle=%0d", cycle);
      end
      assert (flush == redirect.valid);
      responseFire = response.valid && responseReady;
      requestFire = request.valid && requestReady;
      popCount = iqModel.size() != 0 && issueReady && !redirect.valid ? 1 : 0;
      decodeCount = fqModel.size();
      if (decodeCount > DECODE) decodeCount = DECODE;
      if (decodeCount > IQ - iqModel.size() + popCount) decodeCount = IQ - iqModel.size() + popCount;
      if (!freeze && redirect.valid) begin
        fqModel.delete(); iqModel.delete(); requests.delete(); flushes++;
      end else if (!freeze) begin
        if (popCount != 0) begin word0 = iqModel.pop_front(); issued++; end
        if (decodeCount == 2) doubleDecoded++;
        if (decodeCount == 1 && fqModel.size() >= 2) partialDecoded++;
        if (decodeCount != 0 && iqModel.size() + popCount == IQ) replacements++;
        for (int lane = 0; lane < decodeCount; lane++) begin
          word0 = fqModel.pop_front(); iqModel.push_back(word0);
        end
        if (responseFire) begin
          packet = requests.pop_front();
          word0 = '{instruction: response.instruction, programCounter: packet.programCounter,
            predictedNextProgramCounter: packet.secondValid ? packet.programCounter + 4 : packet.predictedNextProgramCounter,
            predictorCheckpointId: packet.predictorCheckpointId};
          fqModel.push_back(word0);
          if (packet.secondValid) begin
            word1 = '{instruction: responseSecond, programCounter: packet.programCounter + 4,
              predictedNextProgramCounter: packet.predictedNextProgramCounter,
              predictorCheckpointId: packet.predictorCheckpointId + bpu_ckpt_id_t'(1)};
            fqModel.push_back(word1); dualPackets++;
            if (packet.predictorCheckpointId == 31) cidWraps++;
          end
        end
        if (requestFire) begin
          packet = '{programCounter: request.address,
            predictedNextProgramCounter: request.predictedProgramCounter,
            predictorCheckpointId: request.predictorCheckpointId, secondValid: second};
          requests.push_back(packet);
          nextCid = (nextCid + (second ? 2 : 1)) & 31;
        end
      end else freezes++;
      #1; clk = 1; #1; clk = 0;
    end
    assert (issued > 100 && flushes > 0 && freezes > 0 && replacements > 0);
    // With one instruction arriving and one leaving per edge, greedy decode
    // never accumulates two FQ words while IQ has two free credits. That legal
    // mixed-width profile must not be failed for unreachable dual activity.
    if (DECODE == 2 && FETCH == 2)
      assert (doubleDecoded > 0 && partialDecoded > 0) else $fatal(1, "no real dual/partial decode");
    if (FETCH == 2) assert (dualPackets > 0 && cidWraps > 0) else $fatal(1, "no packet/CID wrap coverage");
    $display("PASS decode width fetch=%0d decode=%0d FQ=%0d IQ=%0d issued=%0d dual_decode=%0d partial=%0d packets=%0d wraps=%0d replacements=%0d", FETCH, DECODE, FQ, IQ, issued, doubleDecoded, partialDecoded, dualPackets, cidWraps, replacements);
    $finish;
  end
endmodule
