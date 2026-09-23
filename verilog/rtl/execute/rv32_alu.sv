module rv32_alu (
  input  rv32_pkg::alu_operation_input_t aluInput,
  output rv32_pkg::alu_operation_output_t aluOutput
);
  import rv32_pkg::*;

  logic [31:0] operandBInner;
  logic [31:0] sumAddInner;
  logic [31:0] sumSubInner;
  logic [31:0] sumAuipcInner;
  logic unusedCoutAddInner, unusedCoutAuipcInner, unusedBorrowInner;

  assign operandBInner = aluInput.useImmediate ? aluInput.immediate : aluInput.rightOperand;

  rv32_add #(.WIDTH(32)) u_add (
    .aInput(aluInput.leftOperand), .bInput(operandBInner), .cinInput(1'b0),
    .sumOutput(sumAddInner), .coutOutput(unusedCoutAddInner)
  );

  rv32_sub #(.WIDTH(32)) u_sub (
    .aInput(aluInput.leftOperand), .bInput(operandBInner),
    .diffOutput(sumSubInner), .borrowOutput(unusedBorrowInner)
  );

  rv32_add #(.WIDTH(32)) u_auipc (
    .aInput(aluInput.programCounter), .bInput(aluInput.immediate), .cinInput(1'b0),
    .sumOutput(sumAuipcInner), .coutOutput(unusedCoutAuipcInner)
  );

  always_comb begin
    unique case (aluInput.operation)
      OP_ADD:   aluOutput.value = sumAddInner;
      OP_SUB:   aluOutput.value = sumSubInner;
      OP_SLL:   aluOutput.value = aluInput.leftOperand << operandBInner[4:0];
      OP_SLT:   aluOutput.value = {31'b0, $signed(aluInput.leftOperand) < $signed(operandBInner)};
      OP_SLTU:  aluOutput.value = {31'b0, aluInput.leftOperand < operandBInner};
      OP_XOR:   aluOutput.value = aluInput.leftOperand ^ operandBInner;
      OP_SRL:   aluOutput.value = aluInput.leftOperand >> operandBInner[4:0];
      OP_SRA:   aluOutput.value = $unsigned($signed(aluInput.leftOperand) >>> operandBInner[4:0]);
      OP_OR:    aluOutput.value = aluInput.leftOperand | operandBInner;
      OP_AND:   aluOutput.value = aluInput.leftOperand & operandBInner;
      OP_LUI:   aluOutput.value = aluInput.immediate;
      OP_AUIPC: aluOutput.value = sumAuipcInner;
      OP_JAL:   aluOutput.value = sumAuipcInner;
      OP_JALR:  aluOutput.value = sumAddInner & 32'hffff_fffe;
      default:  aluOutput.value = 32'b0;
    endcase
  end
endmodule
