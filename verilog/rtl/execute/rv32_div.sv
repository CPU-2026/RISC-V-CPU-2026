module rv32_div #(
  parameter bit USE_SRT4 = 1'b0
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,
  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  input  logic                   outReadyInput,
  output rv32_pkg::execute_value_output_t executeOutput
);
  generate
    if (USE_SRT4) begin : g_srt4
      rv32_div_srt4 u_impl (.*);
    end else begin : g_radix2
      rv32_div_radix2 u_impl (.*);
    end
  endgenerate
endmodule

/* verilator lint_off DECLFILENAME */
// Original 32-iteration restoring implementation, retained as the A/B
// baseline for the SRT radix-4 implementation below.
module rv32_div_radix2 (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,
  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  input  logic                   outReadyInput,
  output rv32_pkg::execute_value_output_t executeOutput
);
  import rv32_pkg::*;

  logic busyInner;
  logic [5:0] countInner;
  logic [31:0] dividendInner;
  logic [31:0] divisorInner;
  logic [32:0] remainderInner;
  logic [31:0] quotientInner;
  logic quotientNegativeInner;
  logic remainderNegativeInner;
  logic wantRemainderRegisteredInner;
  rob_tag_t activeTagInner;
  phy_tag_t activePhyInner;

  logic resultValidInner;
  logic [31:0] resultInner;
  rob_tag_t resultTagInner;
  phy_tag_t resultPhyInner;

  logic signedOpInner;
  logic wantRemainderInner;
  logic [31:0] dividendAbsInner;
  logic [31:0] divisorAbsInner;
  logic [32:0] shiftedRemainderInner;
  logic [32:0] divisorExtInner;
  logic [32:0] remainderDiffInner;
  logic [32:0] nextRemainderInner;
  logic [31:0] nextQuotientInner;
  logic [31:0] unsignedFinalInner;
  logic [31:0] signedFinalInner;
  logic remainderGeInner;
  logic [31:0] dividendNegInner, divisorNegInner, finalNegInner;
  logic [5:0] countNext;
  logic unusedBorrowRemainderInner, unusedBorrowDividendInner, unusedBorrowDivisorInner;
  logic unusedBorrowFinalInner, unusedCoutCountInner;

  assign signedOpInner = (executeInput.operation == OP_DIV) || (executeInput.operation == OP_REM);
  assign wantRemainderInner = (executeInput.operation == OP_REM) || (executeInput.operation == OP_REMU);

  rv32_sub #(.WIDTH(32)) u_dividend_neg (
    .aInput(32'b0), .bInput(executeInput.source1),
    .diffOutput(dividendNegInner), .borrowOutput(unusedBorrowDividendInner)
  );

  rv32_sub #(.WIDTH(32)) u_divisor_neg (
    .aInput(32'b0), .bInput(executeInput.source2),
    .diffOutput(divisorNegInner), .borrowOutput(unusedBorrowDivisorInner)
  );

  assign dividendAbsInner = (signedOpInner && executeInput.source1[31]) ?
                        dividendNegInner : executeInput.source1;
  assign divisorAbsInner = (signedOpInner && executeInput.source2[31]) ?
                       divisorNegInner : executeInput.source2;

  assign shiftedRemainderInner = {remainderInner[31:0], dividendInner[31]};
  assign divisorExtInner = {1'b0, divisorInner};
  assign remainderGeInner = (shiftedRemainderInner >= divisorExtInner);

  rv32_sub #(.WIDTH(33)) u_remainder_diff (
    .aInput(shiftedRemainderInner), .bInput(divisorExtInner),
    .diffOutput(remainderDiffInner), .borrowOutput(unusedBorrowRemainderInner)
  );

  assign nextRemainderInner = remainderGeInner ? remainderDiffInner : shiftedRemainderInner;
  assign nextQuotientInner = remainderGeInner ?
                         {quotientInner[30:0], 1'b1} :
                         {quotientInner[30:0], 1'b0};
  assign unsignedFinalInner = wantRemainderRegisteredInner ? nextRemainderInner[31:0] :
                                             nextQuotientInner;

  rv32_sub #(.WIDTH(32)) u_final_neg (
    .aInput(32'b0), .bInput(unsignedFinalInner),
    .diffOutput(finalNegInner), .borrowOutput(unusedBorrowFinalInner)
  );

  assign signedFinalInner =
    ((wantRemainderRegisteredInner && remainderNegativeInner) ||
     (!wantRemainderRegisteredInner && quotientNegativeInner)) ? finalNegInner : unsignedFinalInner;

  rv32_add #(.WIDTH(6)) u_count_next (
    .aInput(countInner), .bInput(6'd1), .cinInput(1'b0),
    .sumOutput(countNext), .coutOutput(unusedCoutCountInner)
  );

  always_comb begin
    inReadyOutput = !busyInner && (!resultValidInner || outReadyInput);
    executeOutput.valid = resultValidInner;
    executeOutput.value = resultInner;
    executeOutput.robTag = resultTagInner;
    executeOutput.destinationPhy = resultPhyInner;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      busyInner <= 1'b0;
      countInner <= '0;
      dividendInner <= '0;
      divisorInner <= '0;
      remainderInner <= '0;
      quotientInner <= '0;
      quotientNegativeInner <= 1'b0;
      remainderNegativeInner <= 1'b0;
      wantRemainderRegisteredInner <= 1'b0;
      activeTagInner <= '0;
      activePhyInner <= '0;
      resultValidInner <= 1'b0;
      resultInner <= '0;
      resultTagInner <= '0;
      resultPhyInner <= '0;
    end else begin
      if (flushInfoInput.valid && busyInner &&
          !rob_is_older(activeTagInner, flushInfoInput.robTag)) begin
        busyInner <= 1'b0;
      end else if (flushInfoInput.valid && resultValidInner) begin
        resultValidInner <= 1'b0;
      end else begin
        if (resultValidInner && outReadyInput)
          resultValidInner <= 1'b0;

        if (executeInput.valid && inReadyOutput) begin
          activeTagInner <= executeInput.robTag;
          activePhyInner <= executeInput.destinationPhy;
          wantRemainderRegisteredInner <= wantRemainderInner;
          quotientNegativeInner <= signedOpInner &&
                                 (executeInput.source1[31] ^ executeInput.source2[31]);
          remainderNegativeInner <= signedOpInner && executeInput.source1[31];

          if (executeInput.source2 == 32'b0) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? executeInput.source1 : 32'hffff_ffff;
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else if (signedOpInner && (executeInput.source1 == 32'h8000_0000) &&
                       (executeInput.source2 == 32'hffff_ffff)) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? 32'b0 : 32'h8000_0000;
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else if (dividendAbsInner < divisorAbsInner) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? executeInput.source1 : 32'b0;
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else if (dividendAbsInner == divisorAbsInner) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? 32'b0 :
                        ((signedOpInner && (executeInput.source1[31] ^ executeInput.source2[31])) ?
                         32'hffff_ffff : 32'd1);
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else begin
            busyInner <= 1'b1;
            countInner <= 6'd0;
            dividendInner <= dividendAbsInner;
            divisorInner <= divisorAbsInner;
            remainderInner <= 33'b0;
            quotientInner <= 32'b0;
          end
        end else if (busyInner) begin
          dividendInner <= {dividendInner[30:0], 1'b0};
          remainderInner <= nextRemainderInner;
          quotientInner <= nextQuotientInner;
          if (countInner == 6'd31) begin
            busyInner <= 1'b0;
            resultValidInner <= 1'b1;
            resultInner <= signedFinalInner;
            resultTagInner <= activeTagInner;
            resultPhyInner <= activePhyInner;
          end else begin
            countInner <= countNext;
          end
        end
      end
    end
  end
endmodule

// Radix-4 SRT divider translated from the C++ referenceInput DIV module. It uses
// carry-save partial remainders and redundant A/B quotient conversion, so each
// loop consumes two quotient bits without using a combinational divide.
module rv32_div_srt4 (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,
  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  input  logic                   outReadyInput,
  output rv32_pkg::execute_value_output_t executeOutput
);
  import rv32_pkg::*;

  typedef enum logic [1:0] {PH_PREP, PH_LOOP, PH_FINISH} phase_e;

  logic busyInner;
  phase_e phaseInner;
  logic [5:0] loopCountInner;
  logic [31:0] dividendMagInner, divisorMagInner;
  logic [35:0] divisorDpInner;
  logic [5:0] clzDInner;
  logic shiftDInner;
  logic [6:0] dSliceInner, dSlice3Inner;
  logic [35:0] regSInner, regCInner, maskInner;
  logic [31:0] regAInner, regBInner;
   logic quotientNegativeInner, remainderNegativeInner, wantRemainderRegisteredInner;
  rob_tag_t activeTagInner;
  phy_tag_t activePhyInner;

  logic resultValidInner;
  logic [31:0] resultInner;
  rob_tag_t resultTagInner;
  phy_tag_t resultPhyInner;

   logic signedOpInner, wantRemainderInner;
  logic [31:0] dividendNegInner, divisorNegInner;
  logic [31:0] dividendAbsInner, divisorAbsInner;
  logic unusedBorrowDividendInner, unusedBorrowDivisorInner;

  logic [5:0] prepClzXInner, prepClzDInner, prepAlignInner, prepLoopCountInner;
  logic prepShiftDInner;
  logic [35:0] prepMaskInner, prepDividendNormInner, prepDivisorNormInner, prepDivisorDpInner;
  logic [6:0] prepDSliceInner, prepDSlice3Inner, prepSliceInner;
  logic [35:0] prepSubtrahendInner, prepSInner, prepCInner;
  logic [31:0] prepAInner, prepBInner;

  logic [8:0] loopSum9Inner;
  logic signed [9:0] loopSliceInner, loopDSliceInner, loopDSlice3Inner;
  logic [35:0] loopS4Inner, loopC4Inner, loopSubtrahendInner, loopTInner, loopSInner, loopCInner;
  logic [31:0] loopAInner, loopBInner;

  logic [35:0] finishPkInner, finishCorrectedPkInner;
  logic finishNegativeInner;
  logic [31:0] finishQuotientInner, finishRemainderInner, finishUnsignedInner;
  logic [31:0] finishNegatedInner, finishSignedInner;

  function automatic logic [5:0] clz32(input logic [31:0] valueInput);
    integer indexInner;
    logic seenOneInner;
    begin
      clz32 = 6'd32;
      seenOneInner = 1'b0;
      for (indexInner = 31; indexInner >= 0; indexInner = indexInner - 1) begin
        if (!seenOneInner && valueInput[indexInner]) begin
          clz32 = 31 - indexInner;
          seenOneInner = 1'b1;
        end
      end
    end
  endfunction

  assign signedOpInner = (executeInput.operation == OP_DIV) || (executeInput.operation == OP_REM);
  assign wantRemainderInner = (executeInput.operation == OP_REM) || (executeInput.operation == OP_REMU);

  rv32_sub #(.WIDTH(32)) u_dividend_neg (
    .aInput(32'b0), .bInput(executeInput.source1),
    .diffOutput(dividendNegInner), .borrowOutput(unusedBorrowDividendInner)
  );
  rv32_sub #(.WIDTH(32)) u_divisor_neg (
    .aInput(32'b0), .bInput(executeInput.source2),
    .diffOutput(divisorNegInner), .borrowOutput(unusedBorrowDivisorInner)
  );
  assign dividendAbsInner = (signedOpInner && executeInput.source1[31]) ? dividendNegInner : executeInput.source1;
  assign divisorAbsInner = (signedOpInner && executeInput.source2[31]) ? divisorNegInner : executeInput.source2;

  always_comb begin
    prepClzXInner = clz32(dividendMagInner);
    prepClzDInner = clz32(divisorMagInner);
    prepAlignInner = prepClzDInner - prepClzXInner;
    prepLoopCountInner = (prepAlignInner + 6'd1) >> 1;
    prepShiftDInner = prepAlignInner[0];
    prepMaskInner = prepShiftDInner ? 36'hf_ffffffff : 36'h7_ffffffff;
    prepDividendNormInner = ({4'b0, dividendMagInner} << prepClzXInner) & prepMaskInner;
    prepDivisorNormInner = ({4'b0, divisorMagInner} << prepClzDInner) & prepMaskInner;
    prepDivisorDpInner = (prepDivisorNormInner << prepShiftDInner) & prepMaskInner;
    prepDSliceInner = prepShiftDInner ? {2'b0, prepDivisorDpInner[32:28]} :
                                 {2'b0, prepDivisorDpInner[31:27]};
    prepDSlice3Inner = prepDSliceInner + (prepDSliceInner << 1);
    prepSliceInner = prepShiftDInner ? (prepDividendNormInner >> 27) :
                                (prepDividendNormInner >> 26);

    prepSubtrahendInner = '0;
    prepSInner = '0;
    prepCInner = '0;
    prepAInner = '0;
    prepBInner = '0;
    if (prepSliceInner >= prepDSlice3Inner) begin
      prepSubtrahendInner = (prepDivisorDpInner << 1) & prepMaskInner;
      prepSInner = ((prepDividendNormInner ^ ~prepSubtrahendInner ^ 36'd1) << 2) & prepMaskInner;
      prepCInner = (((prepDividendNormInner & ~prepSubtrahendInner) |
                 (prepDividendNormInner & 36'd1) |
                 (~prepSubtrahendInner & 36'd1)) << 3) & prepMaskInner;
      prepAInner = 32'd2;
      prepBInner = 32'd1;
    end else if (prepSliceInner >= prepDSliceInner) begin
      prepSubtrahendInner = prepDivisorDpInner;
      prepSInner = ((prepDividendNormInner ^ ~prepSubtrahendInner ^ 36'd1) << 2) & prepMaskInner;
      prepCInner = (((prepDividendNormInner & ~prepSubtrahendInner) |
                 (prepDividendNormInner & 36'd1) |
                 (~prepSubtrahendInner & 36'd1)) << 3) & prepMaskInner;
      prepAInner = 32'd1;
      prepBInner = 32'd0;
    end else begin
      prepSInner = (prepDividendNormInner << 2) & prepMaskInner;
      prepCInner = '0;
      prepAInner = 32'd0;
      prepBInner = 32'd3;
    end
  end

  always_comb begin
    if (shiftDInner)
      loopSum9Inner = regSInner[35:27] + regCInner[35:27];
    else
      loopSum9Inner = regSInner[34:26] + regCInner[34:26];
    loopSliceInner = {loopSum9Inner[8], loopSum9Inner};
    loopSliceInner[0] = 1'b0;
    loopDSliceInner = $signed({3'b000, dSliceInner});
    loopDSlice3Inner = $signed({3'b000, dSlice3Inner});
    loopS4Inner = (regSInner << 2) & maskInner;
    loopC4Inner = (regCInner << 2) & maskInner;

    loopSubtrahendInner = '0;
    loopTInner = '0;
    loopSInner = '0;
    loopCInner = '0;
    loopAInner = '0;
    loopBInner = '0;
    if (loopSliceInner >= loopDSlice3Inner) begin
      loopSubtrahendInner = (divisorDpInner << 3) & maskInner;
      loopTInner = maskInner ^ loopSubtrahendInner;
      loopSInner = (loopS4Inner ^ loopC4Inner ^ loopTInner) & maskInner;
      loopCInner = ((((loopS4Inner & loopC4Inner) | (loopS4Inner & loopTInner) |
                  (loopC4Inner & loopTInner)) << 1) | 36'd1) & maskInner;
      loopAInner = (regAInner << 2) | 32'd2;
      loopBInner = (regAInner << 2) | 32'd1;
    end else if (loopSliceInner >= loopDSliceInner) begin
      loopSubtrahendInner = (divisorDpInner << 2) & maskInner;
      loopTInner = maskInner ^ loopSubtrahendInner;
      loopSInner = (loopS4Inner ^ loopC4Inner ^ loopTInner) & maskInner;
      loopCInner = ((((loopS4Inner & loopC4Inner) | (loopS4Inner & loopTInner) |
                  (loopC4Inner & loopTInner)) << 1) | 36'd1) & maskInner;
      loopAInner = (regAInner << 2) | 32'd1;
      loopBInner = regAInner << 2;
    end else if (loopSliceInner >= -loopDSliceInner) begin
      loopSInner = (loopS4Inner ^ loopC4Inner) & maskInner;
      loopCInner = ((loopS4Inner & loopC4Inner) << 1) & maskInner;
      loopAInner = regAInner << 2;
      loopBInner = (regBInner << 2) | 32'd3;
    end else if (loopSliceInner >= -loopDSlice3Inner) begin
      loopSubtrahendInner = (divisorDpInner << 2) & maskInner;
      loopSInner = (loopS4Inner ^ loopC4Inner ^ loopSubtrahendInner) & maskInner;
      loopCInner = (((loopS4Inner & loopC4Inner) | (loopS4Inner & loopSubtrahendInner) |
                 (loopC4Inner & loopSubtrahendInner)) << 1) & maskInner;
      loopAInner = (regBInner << 2) | 32'd3;
      loopBInner = (regBInner << 2) | 32'd2;
    end else begin
      loopSubtrahendInner = (divisorDpInner << 3) & maskInner;
      loopSInner = (loopS4Inner ^ loopC4Inner ^ loopSubtrahendInner) & maskInner;
      loopCInner = (((loopS4Inner & loopC4Inner) | (loopS4Inner & loopSubtrahendInner) |
                 (loopC4Inner & loopSubtrahendInner)) << 1) & maskInner;
      loopAInner = (regBInner << 2) | 32'd2;
      loopBInner = (regBInner << 2) | 32'd1;
    end
  end

  always_comb begin
    finishPkInner = (regSInner + regCInner) & maskInner;
    finishNegativeInner = shiftDInner ? finishPkInner[35] : finishPkInner[34];
    finishCorrectedPkInner = finishNegativeInner ?
                          ((finishPkInner + (divisorDpInner << 2)) & maskInner) : finishPkInner;
    finishQuotientInner = finishNegativeInner ? regBInner : regAInner;
    finishRemainderInner = (((finishCorrectedPkInner >> 2) >> shiftDInner) >> clzDInner);
     finishUnsignedInner = wantRemainderRegisteredInner ? finishRemainderInner : finishQuotientInner;
    finishNegatedInner = ~finishUnsignedInner + 32'd1;
    finishSignedInner =
       ((wantRemainderRegisteredInner && remainderNegativeInner) ||
        (!wantRemainderRegisteredInner && quotientNegativeInner)) ? finishNegatedInner : finishUnsignedInner;
  end

  always_comb begin
    inReadyOutput = !busyInner && (!resultValidInner || outReadyInput);
    executeOutput.valid = resultValidInner;
    executeOutput.value = resultInner;
    executeOutput.robTag = resultTagInner;
    executeOutput.destinationPhy = resultPhyInner;
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      busyInner <= 1'b0;
      phaseInner <= PH_PREP;
      loopCountInner <= '0;
      dividendMagInner <= '0;
      divisorMagInner <= '0;
      divisorDpInner <= '0;
      clzDInner <= '0;
      shiftDInner <= 1'b0;
      dSliceInner <= '0;
      dSlice3Inner <= '0;
      regSInner <= '0;
      regCInner <= '0;
      maskInner <= '0;
      regAInner <= '0;
      regBInner <= '0;
      quotientNegativeInner <= 1'b0;
      remainderNegativeInner <= 1'b0;
       wantRemainderRegisteredInner <= 1'b0;
      activeTagInner <= '0;
      activePhyInner <= '0;
      resultValidInner <= 1'b0;
      resultInner <= '0;
      resultTagInner <= '0;
      resultPhyInner <= '0;
    end else begin
      if (flushInfoInput.valid && busyInner && !rob_is_older(activeTagInner, flushInfoInput.robTag)) begin
        busyInner <= 1'b0;
      end else if (flushInfoInput.valid && resultValidInner) begin
        resultValidInner <= 1'b0;
      end else begin
        if (resultValidInner && outReadyInput)
          resultValidInner <= 1'b0;

        if (executeInput.valid && inReadyOutput) begin
          activeTagInner <= executeInput.robTag;
          activePhyInner <= executeInput.destinationPhy;
           wantRemainderRegisteredInner <= wantRemainderInner;
          quotientNegativeInner <= signedOpInner && (executeInput.source1[31] ^ executeInput.source2[31]);
          remainderNegativeInner <= signedOpInner && executeInput.source1[31];

          if (executeInput.source2 == 32'b0) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? executeInput.source1 : 32'hffff_ffff;
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else if (signedOpInner && (executeInput.source1 == 32'h8000_0000) &&
                       (executeInput.source2 == 32'hffff_ffff)) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? 32'b0 : 32'h8000_0000;
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else if (dividendAbsInner < divisorAbsInner) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? executeInput.source1 : 32'b0;
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else if (dividendAbsInner == divisorAbsInner) begin
            resultValidInner <= 1'b1;
            resultInner <= wantRemainderInner ? 32'b0 :
                        ((signedOpInner && (executeInput.source1[31] ^ executeInput.source2[31])) ?
                         32'hffff_ffff : 32'd1);
            resultTagInner <= executeInput.robTag;
            resultPhyInner <= executeInput.destinationPhy;
            busyInner <= 1'b0;
          end else begin
            busyInner <= 1'b1;
            phaseInner <= PH_PREP;
            dividendMagInner <= dividendAbsInner;
            divisorMagInner <= divisorAbsInner;
          end
        end else if (busyInner) begin
          unique case (phaseInner)
            PH_PREP: begin
              loopCountInner <= prepLoopCountInner;
              divisorDpInner <= prepDivisorDpInner;
              clzDInner <= prepClzDInner;
              shiftDInner <= prepShiftDInner;
              dSliceInner <= prepDSliceInner;
              dSlice3Inner <= prepDSlice3Inner;
              regSInner <= prepSInner;
              regCInner <= prepCInner;
              maskInner <= prepMaskInner;
              regAInner <= prepAInner;
              regBInner <= prepBInner;
              phaseInner <= (prepLoopCountInner == 6'd0) ? PH_FINISH : PH_LOOP;
            end
            PH_LOOP: begin
              regSInner <= loopSInner;
              regCInner <= loopCInner;
              regAInner <= loopAInner;
              regBInner <= loopBInner;
              if (loopCountInner == 6'd1) begin
                phaseInner <= PH_FINISH;
              end else begin
                loopCountInner <= loopCountInner - 6'd1;
              end
            end
            default: begin
              busyInner <= 1'b0;
              resultValidInner <= 1'b1;
              resultInner <= finishSignedInner;
              resultTagInner <= activeTagInner;
              resultPhyInner <= activePhyInner;
            end
          endcase
        end
      end
    end
  end
endmodule
/* verilator lint_on DECLFILENAME */
