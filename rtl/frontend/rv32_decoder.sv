module rv32_decoder (
  input  logic [31:0]              instr_i,
  input  logic [31:0]              pc_i,
  input  logic [31:0]              predicted_next_pc_i,
  input  rv32_pkg::bpu_ckpt_id_t   predictor_ckpt_id_i,
  output rv32_pkg::decoded_uop_t    uop_o
);
  import rv32_pkg::*;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  always_comb begin
    opcode = instr_i[6:0];
    funct3 = instr_i[14:12];
    funct7 = instr_i[31:25];

    uop_o = '0;
    uop_o.valid = 1'b1;
    uop_o.illegal = 1'b1;
    uop_o.uop_class = UOP_ILLEGAL;
    uop_o.op = OP_INVALID;
    uop_o.rd = instr_i[11:7];
    uop_o.rs1 = instr_i[19:15];
    uop_o.rs2 = instr_i[24:20];
    uop_o.pc = pc_i;
    uop_o.instr = instr_i;
    uop_o.predicted_next_pc = predicted_next_pc_i;
    uop_o.predictor_ckpt_id = predictor_ckpt_id_i;
    uop_o.mem_size = MEM_WORD;

    if (instr_i == HALT_INSN) begin
      uop_o.illegal = 1'b0;
      uop_o.halt = 1'b1;
      uop_o.uop_class = UOP_HALT;
    end else begin
      unique case (opcode)
        OPCODE_LUI: begin
          uop_o.illegal = 1'b0;
          uop_o.uop_class = UOP_ALU;
          uop_o.op = OP_LUI;
          uop_o.imm = {instr_i[31:12], 12'b0};
          uop_o.uses_imm = 1'b1;
          uop_o.writes_rd = (uop_o.rd != 5'd0);
        end

        OPCODE_AUIPC: begin
          uop_o.illegal = 1'b0;
          uop_o.uop_class = UOP_ALU;
          uop_o.op = OP_AUIPC;
          uop_o.imm = {instr_i[31:12], 12'b0};
          uop_o.uses_imm = 1'b1;
          uop_o.writes_rd = (uop_o.rd != 5'd0);
        end

        OPCODE_JAL: begin
          uop_o.illegal = 1'b0;
          uop_o.uop_class = UOP_ALU;
          uop_o.op = OP_JAL;
          uop_o.imm = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                       instr_i[20], instr_i[30:21], 1'b0};
          uop_o.uses_imm = 1'b1;
          uop_o.writes_rd = (uop_o.rd != 5'd0);
        end

        OPCODE_JALR: begin
          if (funct3 == 3'b000) begin
            uop_o.illegal = 1'b0;
            uop_o.uop_class = UOP_ALU;
            uop_o.op = OP_JALR;
            uop_o.imm = {{20{instr_i[31]}}, instr_i[31:20]};
            uop_o.uses_rs1 = 1'b1;
            uop_o.uses_imm = 1'b1;
            uop_o.writes_rd = (uop_o.rd != 5'd0);
          end
        end

        OPCODE_BRANCH: begin
          uop_o.uop_class = UOP_BRANCH;
          uop_o.imm = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                       instr_i[30:25], instr_i[11:8], 1'b0};
          uop_o.uses_rs1 = 1'b1;
          uop_o.uses_rs2 = 1'b1;
          unique case (funct3)
            3'b000: begin uop_o.illegal = 1'b0; uop_o.op = OP_BEQ;  end
            3'b001: begin uop_o.illegal = 1'b0; uop_o.op = OP_BNE;  end
            3'b100: begin uop_o.illegal = 1'b0; uop_o.op = OP_BLT;  end
            3'b101: begin uop_o.illegal = 1'b0; uop_o.op = OP_BGE;  end
            3'b110: begin uop_o.illegal = 1'b0; uop_o.op = OP_BLTU; end
            3'b111: begin uop_o.illegal = 1'b0; uop_o.op = OP_BGEU; end
            default: begin uop_o.illegal = 1'b1; uop_o.op = OP_INVALID; end
          endcase
        end

        OPCODE_LOAD: begin
          uop_o.uop_class = UOP_LOAD;
          uop_o.op = OP_LOAD;
          uop_o.imm = {{20{instr_i[31]}}, instr_i[31:20]};
          uop_o.uses_rs1 = 1'b1;
          uop_o.uses_imm = 1'b1;
          uop_o.writes_rd = (uop_o.rd != 5'd0);
          unique case (funct3)
            3'b000: begin uop_o.illegal = 1'b0; uop_o.mem_size = MEM_BYTE; end
            3'b001: begin uop_o.illegal = 1'b0; uop_o.mem_size = MEM_HALF; end
            3'b010: begin uop_o.illegal = 1'b0; uop_o.mem_size = MEM_WORD; end
            3'b100: begin
              uop_o.illegal = 1'b0;
              uop_o.mem_size = MEM_BYTE;
              uop_o.mem_unsigned = 1'b1;
            end
            3'b101: begin
              uop_o.illegal = 1'b0;
              uop_o.mem_size = MEM_HALF;
              uop_o.mem_unsigned = 1'b1;
            end
            default: uop_o.illegal = 1'b1;
          endcase
        end

        OPCODE_STORE: begin
          uop_o.uop_class = UOP_STORE;
          uop_o.op = OP_STORE;
          uop_o.imm = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
          uop_o.uses_rs1 = 1'b1;
          uop_o.uses_rs2 = 1'b1;
          uop_o.uses_imm = 1'b1;
          unique case (funct3)
            3'b000: begin uop_o.illegal = 1'b0; uop_o.mem_size = MEM_BYTE; end
            3'b001: begin uop_o.illegal = 1'b0; uop_o.mem_size = MEM_HALF; end
            3'b010: begin uop_o.illegal = 1'b0; uop_o.mem_size = MEM_WORD; end
            default: uop_o.illegal = 1'b1;
          endcase
        end

        OPCODE_OP_IMM: begin
          uop_o.uop_class = UOP_ALU;
          uop_o.imm = {{20{instr_i[31]}}, instr_i[31:20]};
          uop_o.uses_rs1 = 1'b1;
          uop_o.uses_imm = 1'b1;
          uop_o.writes_rd = (uop_o.rd != 5'd0);
          unique case (funct3)
            3'b000: begin uop_o.illegal = 1'b0; uop_o.op = OP_ADD;  end
            3'b010: begin uop_o.illegal = 1'b0; uop_o.op = OP_SLT;  end
            3'b011: begin uop_o.illegal = 1'b0; uop_o.op = OP_SLTU; end
            3'b100: begin uop_o.illegal = 1'b0; uop_o.op = OP_XOR;  end
            3'b110: begin uop_o.illegal = 1'b0; uop_o.op = OP_OR;   end
            3'b111: begin uop_o.illegal = 1'b0; uop_o.op = OP_AND;  end
            3'b001: begin
              if (funct7 == 7'b0000000) begin
                uop_o.illegal = 1'b0;
                uop_o.op = OP_SLL;
              end
            end
            3'b101: begin
              if (funct7 == 7'b0000000) begin
                uop_o.illegal = 1'b0;
                uop_o.op = OP_SRL;
              end else if (funct7 == 7'b0100000) begin
                uop_o.illegal = 1'b0;
                uop_o.op = OP_SRA;
              end
            end
            default: uop_o.illegal = 1'b1;
          endcase
        end

        OPCODE_OP: begin
          uop_o.uses_rs1 = 1'b1;
          uop_o.uses_rs2 = 1'b1;
          uop_o.writes_rd = (uop_o.rd != 5'd0);
          if (funct7 == 7'b0000001) begin
            unique case (funct3)
              3'b000: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_MUL; uop_o.op = OP_MUL;    end
              3'b001: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_MUL; uop_o.op = OP_MULH;   end
              3'b010: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_MUL; uop_o.op = OP_MULHSU; end
              3'b011: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_MUL; uop_o.op = OP_MULHU;  end
              3'b100: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_DIV; uop_o.op = OP_DIV;    end
              3'b101: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_DIV; uop_o.op = OP_DIVU;   end
              3'b110: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_DIV; uop_o.op = OP_REM;    end
              3'b111: begin uop_o.illegal = 1'b0; uop_o.uop_class = UOP_DIV; uop_o.op = OP_REMU;   end
              default: uop_o.illegal = 1'b1;
            endcase
          end else if ((funct7 == 7'b0000000) ||
                       (funct7 == 7'b0100000)) begin
            uop_o.uop_class = UOP_ALU;
            unique case (funct3)
              3'b000: begin
                if (funct7 == 7'b0000000) begin
                  uop_o.illegal = 1'b0;
                  uop_o.op = OP_ADD;
                end else begin
                  uop_o.illegal = 1'b0;
                  uop_o.op = OP_SUB;
                end
              end
              3'b001: if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_SLL;  end
              3'b010: if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_SLT;  end
              3'b011: if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_SLTU; end
              3'b100: if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_XOR;  end
              3'b101: begin
                if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_SRL; end
                else begin uop_o.illegal = 1'b0; uop_o.op = OP_SRA; end
              end
              3'b110: if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_OR;  end
              3'b111: if (funct7 == 7'b0000000) begin uop_o.illegal = 1'b0; uop_o.op = OP_AND; end
              default: uop_o.illegal = 1'b1;
            endcase
          end
        end

        default: begin
          uop_o.illegal = 1'b1;
          uop_o.uop_class = UOP_ILLEGAL;
        end
      endcase
    end

    if (uop_o.illegal) begin
      uop_o.uop_class = UOP_ILLEGAL;
      uop_o.op = OP_INVALID;
      uop_o.writes_rd = 1'b0;
    end
  end
endmodule
