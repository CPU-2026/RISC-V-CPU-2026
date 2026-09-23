module rv32_bru (
  input  rv32_pkg::branch_operation_input_t branchInput,
  output rv32_pkg::branch_operation_output_t branchOutput
);
  import rv32_pkg::*;

  logic conditionInner;
  logic [31:0] pcPlus4Inner;
  logic [31:0] pcPlusImmInner;
  logic [31:0] src1PlusImmInner;
  logic unusedCoutPc4Inner, unusedCoutPcimmInner, unusedCoutSrc1immInner;

  rv32_add #(.WIDTH(32)) u_pc_plus_4 (
    .aInput(branchInput.programCounter), .bInput(32'd4), .cinInput(1'b0),
    .sumOutput(pcPlus4Inner), .coutOutput(unusedCoutPc4Inner)
  );

  rv32_add #(.WIDTH(32)) u_pc_plus_imm (
    .aInput(branchInput.programCounter), .bInput(branchInput.immediate), .cinInput(1'b0),
    .sumOutput(pcPlusImmInner), .coutOutput(unusedCoutPcimmInner)
  );

  rv32_add #(.WIDTH(32)) u_src1_plus_imm (
    .aInput(branchInput.source1), .bInput(branchInput.immediate), .cinInput(1'b0),
    .sumOutput(src1PlusImmInner), .coutOutput(unusedCoutSrc1immInner)
  );

  always_comb begin
    conditionInner = 1'b0;
    unique case (branchInput.operation)
      OP_BEQ:  conditionInner = (branchInput.source1 == branchInput.source2);
      OP_BNE:  conditionInner = (branchInput.source1 != branchInput.source2);
      OP_BLT:  conditionInner = ($signed(branchInput.source1) < $signed(branchInput.source2));
      OP_BGE:  conditionInner = ($signed(branchInput.source1) >= $signed(branchInput.source2));
      OP_BLTU: conditionInner = (branchInput.source1 < branchInput.source2);
      OP_BGEU: conditionInner = (branchInput.source1 >= branchInput.source2);
      OP_JAL, OP_JALR: begin
        conditionInner = 1'b1;
      end
      default: conditionInner = 1'b0;
    endcase

    branchOutput.taken = conditionInner;
    branchOutput.linkValue = pcPlus4Inner;
    if (branchInput.operation == OP_JALR) begin
      branchOutput.target = src1PlusImmInner & 32'hffff_fffe;
      branchOutput.nextProgramCounter = src1PlusImmInner & 32'hffff_fffe;
    end else begin
      branchOutput.target = pcPlusImmInner;
      if (conditionInner)
        branchOutput.nextProgramCounter = pcPlusImmInner;
      else
        branchOutput.nextProgramCounter = pcPlus4Inner;
    end

    branchOutput.targetMisaligned = conditionInner && (branchOutput.nextProgramCounter[1:0] != 2'b00);
    branchOutput.mispredict = (branchOutput.nextProgramCounter != branchInput.predictedNextProgramCounter);
  end
endmodule
