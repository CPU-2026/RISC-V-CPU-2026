module rv32_flush_arbiter #(
  parameter int unsigned DEPTH = 4
) (
  input  logic                         clkInput,
  input  logic                         rstNInput,

  input  rv32_pkg::flush_candidate_input_t branchInput,
  input  rv32_pkg::flush_candidate_input_t jumpInput,
  output rv32_pkg::squash_input_t        squashOutput
);
  import rv32_pkg::*;

  logic validInner [DEPTH];
  rob_tag_t tagInner [DEPTH];
  logic [31:0] pcInner [DEPTH];
  bpu_ckpt_id_t ckptIdInner [DEPTH];

  logic validNext [DEPTH];
  rob_tag_t tagNext [DEPTH];
  logic [31:0] pcNext [DEPTH];
  bpu_ckpt_id_t ckptIdNext [DEPTH];

  integer selectIndexInner;
  integer combIndexInner, combJInner, countInner, writeIndexInner, insertPosInner;
  integer seqIndexInner;

  always @* begin
    squashOutput.valid = 1'b0;
    squashOutput.robTag = '0;
    squashOutput.programCounter = '0;
    squashOutput.checkpointId = '0;
    for (selectIndexInner = 0; selectIndexInner < DEPTH; selectIndexInner = selectIndexInner + 1) begin
      if (validInner[selectIndexInner] && (!squashOutput.valid ||
                         rob_is_older(tagInner[selectIndexInner], squashOutput.robTag))) begin
        squashOutput.valid = 1'b1;
        squashOutput.robTag = tagInner[selectIndexInner];
        squashOutput.programCounter = pcInner[selectIndexInner];
        squashOutput.checkpointId = ckptIdInner[selectIndexInner];
      end
    end
  end

  always @* begin
    countInner = 0;
    writeIndexInner = 0;
    insertPosInner = 0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      validNext[combIndexInner] = validInner[combIndexInner];
      tagNext[combIndexInner] = tagInner[combIndexInner];
      pcNext[combIndexInner] = pcInner[combIndexInner];
      ckptIdNext[combIndexInner] = ckptIdInner[combIndexInner];
    end

    // A broadcast squash has won arbitration. Keep only strictly older queued
    // requests before accepting this cycle's independently detected events.
    if (squashOutput.valid) begin
      for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
        if (validNext[combIndexInner] && !rob_is_older(tagNext[combIndexInner], squashOutput.robTag))
          validNext[combIndexInner] = 1'b0;
    end

    // Compact first so each insertion can use the same oldest-first layout.
    writeIndexInner = 0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      if (validNext[combIndexInner]) begin
        if (writeIndexInner != combIndexInner) begin
          validNext[writeIndexInner] = 1'b1;
          tagNext[writeIndexInner] = tagNext[combIndexInner];
          pcNext[writeIndexInner] = pcNext[combIndexInner];
          ckptIdNext[writeIndexInner] = ckptIdNext[combIndexInner];
          validNext[combIndexInner] = 1'b0;
        end
        writeIndexInner = writeIndexInner + 1;
      end
    end
    countInner = writeIndexInner;

    if (branchInput.valid &&
        (!squashOutput.valid || rob_is_older(branchInput.robTag, squashOutput.robTag)) &&
        (countInner < DEPTH)) begin
      insertPosInner = 0;
      for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
        if ((combIndexInner < countInner) && rob_is_younger(branchInput.robTag, tagNext[combIndexInner]))
          insertPosInner = insertPosInner + 1;
      for (combJInner = DEPTH-1; combJInner > 0; combJInner = combJInner - 1) begin
        if ((combJInner > insertPosInner) && (combJInner <= countInner)) begin
          validNext[combJInner] = validNext[combJInner-1];
          tagNext[combJInner] = tagNext[combJInner-1];
          pcNext[combJInner] = pcNext[combJInner-1];
          ckptIdNext[combJInner] = ckptIdNext[combJInner-1];
        end
      end
      validNext[insertPosInner] = 1'b1;
      tagNext[insertPosInner] = branchInput.robTag;
      pcNext[insertPosInner] = branchInput.programCounter;
      ckptIdNext[insertPosInner] = branchInput.checkpointId;
      countInner = countInner + 1;
    end

    if (jumpInput.valid &&
        (!squashOutput.valid || rob_is_older(jumpInput.robTag, squashOutput.robTag)) &&
        (countInner < DEPTH)) begin
      insertPosInner = 0;
      for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
        if ((combIndexInner < countInner) && rob_is_younger(jumpInput.robTag, tagNext[combIndexInner]))
          insertPosInner = insertPosInner + 1;
      for (combJInner = DEPTH-1; combJInner > 0; combJInner = combJInner - 1) begin
        if ((combJInner > insertPosInner) && (combJInner <= countInner)) begin
          validNext[combJInner] = validNext[combJInner-1];
          tagNext[combJInner] = tagNext[combJInner-1];
          pcNext[combJInner] = pcNext[combJInner-1];
          ckptIdNext[combJInner] = ckptIdNext[combJInner-1];
        end
      end
      validNext[insertPosInner] = 1'b1;
      tagNext[insertPosInner] = jumpInput.robTag;
      pcNext[insertPosInner] = jumpInput.programCounter;
      ckptIdNext[insertPosInner] = jumpInput.checkpointId;
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        validInner[seqIndexInner] <= 1'b0;
        tagInner[seqIndexInner] <= '0;
        pcInner[seqIndexInner] <= '0;
        ckptIdInner[seqIndexInner] <= '0;
      end
    end else begin
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        validInner[seqIndexInner] <= validNext[seqIndexInner];
        tagInner[seqIndexInner] <= tagNext[seqIndexInner];
        pcInner[seqIndexInner] <= pcNext[seqIndexInner];
        ckptIdInner[seqIndexInner] <= ckptIdNext[seqIndexInner];
      end
    end
  end
endmodule
