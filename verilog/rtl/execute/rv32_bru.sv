module rv32_bru #(
  parameter bit CONDITIONAL_ONLY = 1'b0
) (
  input  rv32_pkg::branch_operation_input_t branchInput,
  output rv32_pkg::branch_operation_output_t branchOutput
);
  import rv32_pkg::*;

  logic conditionInner;
  logic [31:0] pcPlus4Inner;
  logic [31:0] pcPlusImmInner;
  logic [31:0] src1PlusImmInner;
  logic unusedCoutPcimmInner, unusedCoutSrc1immInner;

  // Adding 4 cannot change bits 1:0. Preserve them rather than assuming
  // alignment, and wrap the upper increment modulo 2^30 exactly as RV32.
  assign pcPlus4Inner = {branchInput.programCounter[31:2] + 30'd1,
                        branchInput.programCounter[1:0]};

  rv32_add #(.WIDTH(32)) u_pc_plus_imm (
    .aInput(branchInput.programCounter), .bInput(branchInput.immediate), .cinInput(1'b0),
    .sumOutput(pcPlusImmInner), .coutOutput(unusedCoutPcimmInner)
  );

  generate if (!CONDITIONAL_ONLY) begin : g_jump_target
    rv32_add #(.WIDTH(32)) u_src1_plus_imm (
      .aInput(branchInput.source1), .bInput(branchInput.immediate), .cinInput(1'b0),
      .sumOutput(src1PlusImmInner), .coutOutput(unusedCoutSrc1immInner)
    );
  end else begin : g_conditional_target
    // The core dispatches JAL/JALR to the integer ALU. No source-address
    // target adder or JALR target mux is needed by its conditional BRU.
    assign src1PlusImmInner = '0;
    assign unusedCoutSrc1immInner = 1'b0;
  end endgenerate

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
    if (!CONDITIONAL_ONLY && branchInput.operation == OP_JALR) begin
      branchOutput.target = src1PlusImmInner & 32'hffff_fffe;
      branchOutput.nextProgramCounter = src1PlusImmInner & 32'hffff_fffe;
    end else begin
      branchOutput.target = pcPlusImmInner;
      if (conditionInner)
        branchOutput.nextProgramCounter = pcPlusImmInner;
      else
        branchOutput.nextProgramCounter = pcPlus4Inner;
    end

    branchOutput.targetMisaligned = 1'b0; // Targets are aligned by contract.
    branchOutput.mispredict = (branchOutput.nextProgramCounter != branchInput.predictedNextProgramCounter);
  end
endmodule
