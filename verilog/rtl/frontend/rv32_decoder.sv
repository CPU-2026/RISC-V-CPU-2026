module rv32_decoder (
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
    uopOutput.illegal = 1'b1;
    uopOutput.uopClass = UOP_ILLEGAL;
    uopOutput.operation = OP_INVALID;
    uopOutput.rd = decodeContextInput.instruction[11:7];
    uopOutput.rs1 = decodeContextInput.instruction[19:15];
    uopOutput.rs2 = decodeContextInput.instruction[24:20];
    uopOutput.programCounter = decodeContextInput.programCounter;
    uopOutput.instruction = decodeContextInput.instruction;
    uopOutput.predictedNextProgramCounter = decodeContextInput.predictedNextProgramCounter;
    uopOutput.predictorCheckpointId = decodeContextInput.predictorCheckpointId;
    uopOutput.memorySize = MEM_WORD;

    if (decodeContextInput.instruction == HALT_INSN) begin
      uopOutput.illegal = 1'b0;
      uopOutput.halt = 1'b1;
      uopOutput.uopClass = UOP_HALT;
    end else begin
      unique case (opcodeInner)
        OPCODE_LUI: begin
          uopOutput.illegal = 1'b0;
          uopOutput.uopClass = UOP_ALU;
          uopOutput.operation = OP_LUI;
          uopOutput.immediate = {decodeContextInput.instruction[31:12], 12'b0};
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
        end

        OPCODE_AUIPC: begin
          uopOutput.illegal = 1'b0;
          uopOutput.uopClass = UOP_ALU;
          uopOutput.operation = OP_AUIPC;
          uopOutput.immediate = {decodeContextInput.instruction[31:12], 12'b0};
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
        end

        OPCODE_JAL: begin
          uopOutput.illegal = 1'b0;
          uopOutput.uopClass = UOP_ALU;
          uopOutput.operation = OP_JAL;
          uopOutput.immediate = {{11{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31], decodeContextInput.instruction[19:12],
                        decodeContextInput.instruction[20], decodeContextInput.instruction[30:21], 1'b0};
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
        end

        OPCODE_JALR: begin
          if (funct3Inner == 3'b000) begin
            uopOutput.illegal = 1'b0;
            uopOutput.uopClass = UOP_ALU;
            uopOutput.operation = OP_JALR;
            uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
            uopOutput.usesRs1 = 1'b1;
            uopOutput.usesImmediate = 1'b1;
            uopOutput.writesRd = (uopOutput.rd != 5'd0);
          end
        end

        OPCODE_BRANCH: begin
          uopOutput.uopClass = UOP_BRANCH;
          uopOutput.immediate = {{19{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31], decodeContextInput.instruction[7],
                        decodeContextInput.instruction[30:25], decodeContextInput.instruction[11:8], 1'b0};
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesRs2 = 1'b1;
          unique case (funct3Inner)
            3'b000: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_BEQ;  end
            3'b001: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_BNE;  end
            3'b100: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_BLT;  end
            3'b101: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_BGE;  end
            3'b110: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_BLTU; end
            3'b111: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_BGEU; end
            default: begin uopOutput.illegal = 1'b1; uopOutput.operation = OP_INVALID; end
          endcase
        end

        OPCODE_LOAD: begin
          uopOutput.uopClass = UOP_LOAD;
          uopOutput.operation = OP_LOAD;
          uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
          unique case (funct3Inner)
            3'b000: begin uopOutput.illegal = 1'b0; uopOutput.memorySize = MEM_BYTE; end
            3'b001: begin uopOutput.illegal = 1'b0; uopOutput.memorySize = MEM_HALF; end
            3'b010: begin uopOutput.illegal = 1'b0; uopOutput.memorySize = MEM_WORD; end
            3'b100: begin
              uopOutput.illegal = 1'b0;
              uopOutput.memorySize = MEM_BYTE;
              uopOutput.memoryUnsigned = 1'b1;
            end
            3'b101: begin
              uopOutput.illegal = 1'b0;
              uopOutput.memorySize = MEM_HALF;
              uopOutput.memoryUnsigned = 1'b1;
            end
            default: uopOutput.illegal = 1'b1;
          endcase
        end

        OPCODE_STORE: begin
          uopOutput.uopClass = UOP_STORE;
          uopOutput.operation = OP_STORE;
          uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:25], decodeContextInput.instruction[11:7]};
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesRs2 = 1'b1;
          uopOutput.usesImmediate = 1'b1;
          unique case (funct3Inner)
            3'b000: begin uopOutput.illegal = 1'b0; uopOutput.memorySize = MEM_BYTE; end
            3'b001: begin uopOutput.illegal = 1'b0; uopOutput.memorySize = MEM_HALF; end
            3'b010: begin uopOutput.illegal = 1'b0; uopOutput.memorySize = MEM_WORD; end
            default: uopOutput.illegal = 1'b1;
          endcase
        end

        OPCODE_OP_IMM: begin
          uopOutput.uopClass = UOP_ALU;
          uopOutput.immediate = {{20{decodeContextInput.instruction[31]}}, decodeContextInput.instruction[31:20]};
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesImmediate = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
          unique case (funct3Inner)
            3'b000: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_ADD;  end
            3'b010: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SLT;  end
            3'b011: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SLTU; end
            3'b100: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_XOR;  end
            3'b110: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_OR;   end
            3'b111: begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_AND;  end
            3'b001: begin
              if (funct7Inner == 7'b0000000) begin
                uopOutput.illegal = 1'b0;
                uopOutput.operation = OP_SLL;
              end
            end
            3'b101: begin
              if (funct7Inner == 7'b0000000) begin
                uopOutput.illegal = 1'b0;
                uopOutput.operation = OP_SRL;
              end else if (funct7Inner == 7'b0100000) begin
                uopOutput.illegal = 1'b0;
                uopOutput.operation = OP_SRA;
              end
            end
            default: uopOutput.illegal = 1'b1;
          endcase
        end

        OPCODE_OP: begin
          uopOutput.usesRs1 = 1'b1;
          uopOutput.usesRs2 = 1'b1;
          uopOutput.writesRd = (uopOutput.rd != 5'd0);
          if (funct7Inner == 7'b0000001) begin
            unique case (funct3Inner)
              3'b000: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_MUL; uopOutput.operation = OP_MUL;    end
              3'b001: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_MUL; uopOutput.operation = OP_MULH;   end
              3'b010: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_MUL; uopOutput.operation = OP_MULHSU; end
              3'b011: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_MUL; uopOutput.operation = OP_MULHU;  end
              3'b100: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_DIV; uopOutput.operation = OP_DIV;    end
              3'b101: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_DIV; uopOutput.operation = OP_DIVU;   end
              3'b110: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_DIV; uopOutput.operation = OP_REM;    end
              3'b111: begin uopOutput.illegal = 1'b0; uopOutput.uopClass = UOP_DIV; uopOutput.operation = OP_REMU;   end
              default: uopOutput.illegal = 1'b1;
            endcase
          end else if ((funct7Inner == 7'b0000000) ||
                       (funct7Inner == 7'b0100000)) begin
            uopOutput.uopClass = UOP_ALU;
            unique case (funct3Inner)
              3'b000: begin
                if (funct7Inner == 7'b0000000) begin
                  uopOutput.illegal = 1'b0;
                  uopOutput.operation = OP_ADD;
                end else begin
                  uopOutput.illegal = 1'b0;
                  uopOutput.operation = OP_SUB;
                end
              end
              3'b001: if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SLL;  end
              3'b010: if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SLT;  end
              3'b011: if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SLTU; end
              3'b100: if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_XOR;  end
              3'b101: begin
                if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SRL; end
                else begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_SRA; end
              end
              3'b110: if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_OR;  end
              3'b111: if (funct7Inner == 7'b0000000) begin uopOutput.illegal = 1'b0; uopOutput.operation = OP_AND; end
              default: uopOutput.illegal = 1'b1;
            endcase
          end
        end

        default: begin
          uopOutput.illegal = 1'b1;
          uopOutput.uopClass = UOP_ILLEGAL;
        end
      endcase
    end

    if (uopOutput.illegal) begin
      uopOutput.uopClass = UOP_ILLEGAL;
      uopOutput.operation = OP_INVALID;
      uopOutput.writesRd = 1'b0;
    end
  end
endmodule
