package rv32_pkg;
  parameter int unsigned XLEN         = 32;
  parameter int unsigned ARCH_REGS    = 32;
  parameter int unsigned ROB_ENTRIES  = 16;
  parameter int unsigned PRF_ENTRIES  = 48;
  parameter int unsigned ROB_TAG_W    = 5;
  parameter int unsigned PHY_TAG_W    = 6;
  parameter int unsigned LQ_ENTRIES   = 8;
  parameter int unsigned SQ_ENTRIES   = 8;
  parameter int unsigned BPU_CKPT_ENTRIES = 32;
  parameter int unsigned BPU_CKPT_ID_W = $clog2(BPU_CKPT_ENTRIES);

  localparam logic [31:0] HALT_INSN = 32'h0ff0_0513;
  localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
  localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
  localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
  localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
  localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
  localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPCODE_OP     = 7'b0110011;

  typedef logic [ROB_TAG_W-1:0] rob_tag_t;
  typedef logic [PHY_TAG_W-1:0] phy_tag_t;
  typedef logic [BPU_CKPT_ID_W-1:0] bpu_ckpt_id_t;

  typedef enum logic [3:0] {
    UOP_NONE,
    UOP_ALU,
    UOP_MUL,
    UOP_DIV,
    UOP_BRANCH,
    UOP_LOAD,
    UOP_STORE,
    UOP_HALT,
    UOP_ILLEGAL
  } uop_class_e;

  typedef enum logic [5:0] {
    OP_INVALID,
    OP_ADD,
    OP_SUB,
    OP_SLL,
    OP_SLT,
    OP_SLTU,
    OP_XOR,
    OP_SRL,
    OP_SRA,
    OP_OR,
    OP_AND,
    OP_LUI,
    OP_AUIPC,
    OP_MUL,
    OP_MULH,
    OP_MULHSU,
    OP_MULHU,
    OP_DIV,
    OP_DIVU,
    OP_REM,
    OP_REMU,
    OP_BEQ,
    OP_BNE,
    OP_BLT,
    OP_BGE,
    OP_BLTU,
    OP_BGEU,
    OP_JAL,
    OP_JALR,
    OP_LOAD,
    OP_STORE
  } operation_e;

  typedef enum logic [1:0] {
    MEM_BYTE = 2'd0,
    MEM_HALF = 2'd1,
    MEM_WORD = 2'd2
  } mem_size_e;

  typedef struct packed {
    logic         valid;
    logic         illegal;
    logic         halt;
    uop_class_e   uop_class;
    operation_e   op;
    logic [4:0]   rd;
    logic [4:0]   rs1;
    logic [4:0]   rs2;
    logic         uses_rs1;
    logic         uses_rs2;
    logic         uses_imm;
    logic         writes_rd;
    logic [31:0]  imm;
    logic [31:0]  pc;
    logic [31:0]  instr;
    logic [31:0]  predicted_next_pc;
    bpu_ckpt_id_t predictor_ckpt_id;
    mem_size_e    mem_size;
    logic         mem_unsigned;
  } decoded_uop_t;

  typedef struct packed {
    logic       ready;
    phy_tag_t   tag;
    logic [31:0] value;
  } operand_t;

  function automatic logic rob_is_younger(
    input rob_tag_t candidate,
    input rob_tag_t boundary
  );
    logic [ROB_TAG_W-1:0] propagate;
    logic [ROB_TAG_W-1:0] gen_bit;
    logic [ROB_TAG_W-1:0] group_p;
    logic [ROB_TAG_W-1:0] group_g;
    begin
      propagate = candidate ^ ~boundary;
      gen_bit = candidate & ~boundary;
      group_p = propagate;
      group_g = gen_bit;
      for (int stage = 1; stage < ROB_TAG_W; stage = stage << 1) begin
        for (int bit_index = ROB_TAG_W-1; bit_index >= stage;
             bit_index = bit_index - 1) begin
          group_g[bit_index] = group_g[bit_index] |
                               (group_p[bit_index] &
                                group_g[bit_index-stage]);
          group_p[bit_index] = group_p[bit_index] &
                               group_p[bit_index-stage];
        end
      end
      rob_is_younger = (candidate != boundary) &&
                       !(propagate[ROB_TAG_W-1] ^
                         (group_g[ROB_TAG_W-2] |
                          (group_p[ROB_TAG_W-2] & 1'b1)));
    end
  endfunction

  function automatic logic rob_is_older(
    input rob_tag_t candidate,
    input rob_tag_t reference
  );
    begin
      rob_is_older = rob_is_younger(reference, candidate);
    end
  endfunction

  function automatic logic [2:0] mem_bytes(input mem_size_e size);
    begin
      unique case (size)
        MEM_BYTE: mem_bytes = 3'd1;
        MEM_HALF: mem_bytes = 3'd2;
        default:  mem_bytes = 3'd4;
      endcase
    end
  endfunction
endpackage
