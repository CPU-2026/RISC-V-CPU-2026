module rv32_mul (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,
  input  rv32_pkg::execute_request_input_t executeInput,
  output logic                   inReadyOutput,

  input  logic                   outReadyInput,
  output rv32_pkg::execute_value_output_t executeOutput
);
  import rv32_pkg::*;

  localparam int unsigned PRODUCT_W = 64;

  logic [2:0] validInner;
  logic [2:0] keepValidInner;
  logic inputLiveInner;
  logic [PRODUCT_W-1:0] boothRowsRegisteredInner [6];
  logic [PRODUCT_W-1:0] csaSumInner, csaCarryInner;
  logic [31:0] resultInner;
  logic highInner [2];
  rob_tag_t tagInner [3];
  phy_tag_t phyInner [3];
  logic resultCanAcceptInner, CSACanAcceptInner, partialCanAcceptInner;

  logic lhsSignedInner, rhsSignedInner;
  logic [PRODUCT_W-1:0] boothMultiplicandInner;
  logic [34:0] boothMultiplierInner;
  logic [PRODUCT_W-1:0] boothRowsInner [18];
  logic [PRODUCT_W-1:0] boothCorrectionInner;
  logic [PRODUCT_W-1:0] compressL1Inner [12];
  logic [PRODUCT_W-1:0] compressL2Inner [8];
  logic [PRODUCT_W-1:0] compressL3Inner [6];

  logic [PRODUCT_W-1:0] csaL1Inner [4];
  logic [PRODUCT_W-1:0] csaL2Inner [3];
  logic [PRODUCT_W-1:0] csaSumDInner, csaCarryDInner;
  logic [PRODUCT_W-1:0] finalProductInner;
  logic finalCarryUnusedInner;

  integer boothIndexInner;
  integer compressIndexInner;
  integer csaIndexInner;
  integer seqIndexInner;

  for (genvar stage = 0; stage < 3; stage++) begin : gen_live_stages
    assign keepValidInner[stage] = validInner[stage] && (!flushInfoInput.valid ||
        rob_is_older(tagInner[stage], flushInfoInput.robTag));
  end
  assign inputLiveInner = !executeInput.valid || !flushInfoInput.valid ||
      rob_is_older(executeInput.robTag, flushInfoInput.robTag);

  // Stage 1: radix-4 Booth recoding followed by three CSA levels. Negative
  // digits use one's-complement rows plus a shared correction row, avoiding a
  // carry-propagate negation for every partial product.
  always_comb begin
    lhsSignedInner = (executeInput.operation == OP_MULH) || (executeInput.operation == OP_MULHSU);
    rhsSignedInner = (executeInput.operation == OP_MULH);
    boothMultiplicandInner = lhsSignedInner ? {{32{executeInput.source1[31]}}, executeInput.source1} :
                                        {32'b0, executeInput.source1};
    boothMultiplierInner = rhsSignedInner ? {{2{executeInput.source2[31]}}, executeInput.source2, 1'b0} :
                                      {2'b0, executeInput.source2, 1'b0};

    boothCorrectionInner = '0;
    for (boothIndexInner = 0; boothIndexInner < 17; boothIndexInner = boothIndexInner + 1) begin
      unique case (boothMultiplierInner[2*boothIndexInner +: 3])
        3'b001, 3'b010: begin
          boothRowsInner[boothIndexInner] = boothMultiplicandInner << (2*boothIndexInner);
        end
        3'b011: begin
          boothRowsInner[boothIndexInner] = boothMultiplicandInner << (2*boothIndexInner + 1);
        end
        3'b100: begin
          boothRowsInner[boothIndexInner] = (~boothMultiplicandInner) << (2*boothIndexInner + 1);
          boothCorrectionInner[2*boothIndexInner + 1] = 1'b1;
        end
        3'b101, 3'b110: begin
          boothRowsInner[boothIndexInner] = (~boothMultiplicandInner) << (2*boothIndexInner);
          boothCorrectionInner[2*boothIndexInner] = 1'b1;
        end
        default: begin
          boothRowsInner[boothIndexInner] = '0;
        end
      endcase
    end
    boothRowsInner[17] = boothCorrectionInner;

    for (compressIndexInner = 0; compressIndexInner < 6; compressIndexInner = compressIndexInner + 1) begin
      compressL1Inner[2*compressIndexInner] = boothRowsInner[3*compressIndexInner] ^
                                  boothRowsInner[3*compressIndexInner+1] ^
                                  boothRowsInner[3*compressIndexInner+2];
      compressL1Inner[2*compressIndexInner+1] =
          ((boothRowsInner[3*compressIndexInner] & boothRowsInner[3*compressIndexInner+1]) |
           (boothRowsInner[3*compressIndexInner] & boothRowsInner[3*compressIndexInner+2]) |
           (boothRowsInner[3*compressIndexInner+1] & boothRowsInner[3*compressIndexInner+2])) << 1;
    end
    for (compressIndexInner = 0; compressIndexInner < 4; compressIndexInner = compressIndexInner + 1) begin
      compressL2Inner[2*compressIndexInner] = compressL1Inner[3*compressIndexInner] ^
                                  compressL1Inner[3*compressIndexInner+1] ^
                                  compressL1Inner[3*compressIndexInner+2];
      compressL2Inner[2*compressIndexInner+1] =
          ((compressL1Inner[3*compressIndexInner] & compressL1Inner[3*compressIndexInner+1]) |
           (compressL1Inner[3*compressIndexInner] & compressL1Inner[3*compressIndexInner+2]) |
           (compressL1Inner[3*compressIndexInner+1] & compressL1Inner[3*compressIndexInner+2])) << 1;
    end
    for (compressIndexInner = 0; compressIndexInner < 2; compressIndexInner = compressIndexInner + 1) begin
      compressL3Inner[2*compressIndexInner] = compressL2Inner[3*compressIndexInner] ^
                                  compressL2Inner[3*compressIndexInner+1] ^
                                  compressL2Inner[3*compressIndexInner+2];
      compressL3Inner[2*compressIndexInner+1] =
          ((compressL2Inner[3*compressIndexInner] & compressL2Inner[3*compressIndexInner+1]) |
           (compressL2Inner[3*compressIndexInner] & compressL2Inner[3*compressIndexInner+2]) |
           (compressL2Inner[3*compressIndexInner+1] & compressL2Inner[3*compressIndexInner+2])) << 1;
    end
    compressL3Inner[4] = compressL2Inner[6];
    compressL3Inner[5] = compressL2Inner[7];
  end

  // Stage 2: finish the carry-save tree, leaving only two 64-bit rows.
  always_comb begin
    for (csaIndexInner = 0; csaIndexInner < 2; csaIndexInner = csaIndexInner + 1) begin
      csaL1Inner[2*csaIndexInner] = boothRowsRegisteredInner[3*csaIndexInner] ^
                         boothRowsRegisteredInner[3*csaIndexInner+1] ^
                         boothRowsRegisteredInner[3*csaIndexInner+2];
      csaL1Inner[2*csaIndexInner+1] =
          ((boothRowsRegisteredInner[3*csaIndexInner] & boothRowsRegisteredInner[3*csaIndexInner+1]) |
           (boothRowsRegisteredInner[3*csaIndexInner] & boothRowsRegisteredInner[3*csaIndexInner+2]) |
           (boothRowsRegisteredInner[3*csaIndexInner+1] & boothRowsRegisteredInner[3*csaIndexInner+2])) << 1;
    end
    csaL2Inner[0] = csaL1Inner[0] ^ csaL1Inner[1] ^ csaL1Inner[2];
    csaL2Inner[1] = ((csaL1Inner[0] & csaL1Inner[1]) |
                 (csaL1Inner[0] & csaL1Inner[2]) |
                 (csaL1Inner[1] & csaL1Inner[2])) << 1;
    csaL2Inner[2] = csaL1Inner[3];
    csaSumDInner = csaL2Inner[0] ^ csaL2Inner[1] ^ csaL2Inner[2];
    csaCarryDInner = ((csaL2Inner[0] & csaL2Inner[1]) |
                   (csaL2Inner[0] & csaL2Inner[2]) |
                   (csaL2Inner[1] & csaL2Inner[2])) << 1;
  end

  // Stage 3: the only carry-propagate addition in the multiplier.
  rv32_add #(.WIDTH(PRODUCT_W)) u_final_add (
    .aInput(csaSumInner),
    .bInput(csaCarryInner),
    .cinInput(1'b0),
    .sumOutput(finalProductInner),
    .coutOutput(finalCarryUnusedInner)
  );

  always_comb begin
    resultCanAcceptInner = !keepValidInner[2] || outReadyInput;
    CSACanAcceptInner = !keepValidInner[1] || resultCanAcceptInner;
    partialCanAcceptInner = !keepValidInner[0] || CSACanAcceptInner;
    inReadyOutput = partialCanAcceptInner && inputLiveInner;
    executeOutput.valid = keepValidInner[2];
    executeOutput.value = resultInner;
    executeOutput.robTag = tagInner[2];
    executeOutput.destinationPhy = phyInner[2];
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      validInner <= '0;
      for (seqIndexInner = 0; seqIndexInner < 6; seqIndexInner = seqIndexInner + 1)
        boothRowsRegisteredInner[seqIndexInner] <= '0;
      csaSumInner <= '0;
      csaCarryInner <= '0;
      resultInner <= '0;
      highInner[0] <= 1'b0;
      highInner[1] <= 1'b0;
      for (seqIndexInner = 0; seqIndexInner < 3; seqIndexInner = seqIndexInner + 1) begin
        tagInner[seqIndexInner] <= '0;
        phyInner[seqIndexInner] <= '0;
      end
    end else begin
      if (resultCanAcceptInner) begin
        validInner[2] <= keepValidInner[1];
        if (keepValidInner[1]) begin
          resultInner <= highInner[1] ? finalProductInner[63:32] : finalProductInner[31:0];
          tagInner[2] <= tagInner[1];
          phyInner[2] <= phyInner[1];
        end
      end
      if (CSACanAcceptInner) begin
        validInner[1] <= keepValidInner[0];
        if (keepValidInner[0]) begin
          csaSumInner <= csaSumDInner;
          csaCarryInner <= csaCarryDInner;
          highInner[1] <= highInner[0];
          tagInner[1] <= tagInner[0];
          phyInner[1] <= phyInner[0];
        end
      end
      if (partialCanAcceptInner) begin
        validInner[0] <= executeInput.valid && inputLiveInner;
        if (executeInput.valid && inputLiveInner) begin
          for (seqIndexInner = 0; seqIndexInner < 6; seqIndexInner = seqIndexInner + 1)
            boothRowsRegisteredInner[seqIndexInner] <= compressL3Inner[seqIndexInner];
          highInner[0] <= (executeInput.operation != OP_MUL);
          tagInner[0] <= executeInput.robTag;
          phyInner[0] <= executeInput.destinationPhy;
        end
      end
    end
  end
endmodule
