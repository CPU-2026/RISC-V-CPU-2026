// Contract: accepted instructions are legal RV32IM encodings. Reserved words
// are outside this core's supported input domain; no illegal-instruction trap.
module rv32_decoder #(
  parameter bit LEGACY_HALT = 1'b0
) (
  input  rv32_pkg::decode_context_t decodeContextInput,
  output rv32_pkg::decoded_uop_t    uopOutput
);
  import rv32_pkg::*;

  logic [6:0] opcodeInner;
  logic [2:0] funct3Inner;
  logic [6:0] funct7Inner;

  always_comb begin
    opcodeInner = decodeContextInput.instruction[6:0];
    funct3Inner = decodeContextInput.instruction[14:12];
    funct7Inner = decodeContextInput.instruction[31:25];
    uopOutput = '0;
    uopOutput.valid = 1'b1;
    uopOutput.uopClass = UOP_NONE;
    uopOutput.operation = OP_INVALID;
    uopOutput.rd = decodeContextInput.instruction[11:7];
    uopOutput.rs1 = decodeContextInput.instruction[19:15];
    uopOutput.rs2 = decodeContextInput.instruction[24:20];
    uopOutput.programCounter = decodeContextInput.programCounter;
    uopOutput.instruction = decodeContextInput.instruction;
    uopOutput.predictedNextProgramCounter = decodeContextInput.predictedNextProgramCounter;
    uopOutput.predictorCheckpointId = decodeContextInput.predictorCheckpointId;
    uopOutput.memorySize = MEM_WORD;

    if (LEGACY_HALT && decodeContextInput.instruction == HALT_INSN) begin
      uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
      uopOutput.halt = 1'b1;
      uopOutput.uopClass = UOP_HALT;
    end else begin
      unique case (opcodeInner)
        OPCODE_LUI, OPCODE_AUIPC: begin
          uopOutput.uopClass = UOP_ALU;
          uopOutput.operation = opcodeInner == OPCODE_LUI ? OP_LUI : OP_AUIPC;
          uopOutput.immediate = {decodeContextInput.instruction[31:12], 12'b0};
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
        end
        OPCODE_JAL: begin
          uopOutput.uopClass = UOP_ALU;
          uopOutput.operation = OP_JAL;
          uopOutput.immediate = {{11{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31],
            decodeContextInput.instruction[19:12], decodeContextInput.instruction[20],
            decodeContextInput.instruction[30:21], 1'b0};
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
        end
        OPCODE_JALR: begin
          uopOutput.uopClass = UOP_ALU;
          uopOutput.operation = OP_JALR;
          uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
        end
        OPCODE_BRANCH: begin
          uopOutput.uopClass = UOP_BRANCH;
          uopOutput.immediate = {{19{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31],
            decodeContextInput.instruction[7], decodeContextInput.instruction[30:25],
            decodeContextInput.instruction[11:8], 1'b0};
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesRs2 = 1'b1;
          unique case (funct3Inner)
            3'b000: uopOutput.operation = OP_BEQ;
            3'b001: uopOutput.operation = OP_BNE;
            3'b100: uopOutput.operation = OP_BLT;
            3'b101: uopOutput.operation = OP_BGE;
            3'b110: uopOutput.operation = OP_BLTU;
            3'b111: uopOutput.operation = OP_BGEU;
            default: uopOutput.operation = OP_INVALID;
          endcase
        end
        OPCODE_LOAD, OPCODE_STORE: begin
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesImmediate = 1'b1;
          uopOutput.memorySize = mem_size_e'(funct3Inner[1:0]);
          if (opcodeInner == OPCODE_LOAD) begin
            uopOutput.uopClass = UOP_LOAD;
            uopOutput.operation = OP_LOAD;
            uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
            uopOutput.writesRd = (uopOutput.rd != 5'd0);
            uopOutput.memoryUnsigned = funct3Inner[2];
          end else begin
            uopOutput.uopClass = UOP_STORE;
            uopOutput.operation = OP_STORE;
            uopOutput.immediate = {{20{decodeContextInput.instruction[31]}},
              decodeContextInput.instruction[31:25], decodeContextInput.instruction[11:7]};
            uopOutput.usesRs2 = 1'b1;
          end
        end
        OPCODE_OP_IMM, OPCODE_OP: begin
          uopOutput.uopClass = UOP_ALU;
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesRs2 = opcodeInner == OPCODE_OP;
          uopOutput.usesImmediate = opcodeInner == OPCODE_OP_IMM;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
          if (opcodeInner == OPCODE_OP_IMM)
            uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
          if (opcodeInner == OPCODE_OP && funct7Inner == 7'b0000001) begin
            uopOutput.uopClass = funct3Inner[2] ? UOP_DIV : UOP_MUL;
            unique case (funct3Inner)
              3'b000: uopOutput.operation = OP_MUL;
              3'b001: uopOutput.operation = OP_MULH;
              3'b010: uopOutput.operation = OP_MULHSU;
              3'b011: uopOutput.operation = OP_MULHU;
              3'b100: uopOutput.operation = OP_DIV;
              3'b101: uopOutput.operation = OP_DIVU;
              3'b110: uopOutput.operation = OP_REM;
              3'b111: uopOutput.operation = OP_REMU;
              default: uopOutput.operation = OP_INVALID;
            endcase
          end else begin
            unique case (funct3Inner)
              3'b000: uopOutput.operation = opcodeInner == OPCODE_OP && decodeContextInput.instruction[30] ? OP_SUB : OP_ADD;
              3'b001: uopOutput.operation = OP_SLL;
              3'b010: uopOutput.operation = OP_SLT;
              3'b011: uopOutput.operation = OP_SLTU;
              3'b100: uopOutput.operation = OP_XOR;
              3'b101: uopOutput.operation = decodeContextInput.instruction[30] ? OP_SRA : OP_SRL;
              3'b110: uopOutput.operation = OP_OR;
              3'b111: uopOutput.operation = OP_AND;
              default: uopOutput.operation = OP_INVALID;
            endcase
          end
        end
        default: begin end // Out of contract, not an architectural trap path.
      endcase
    end
  end
endmodule
