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
  parameter int unsigned FQ_ENTRIES   = 2;
  parameter int unsigned IQ_ENTRIES   = 2;
  parameter int unsigned FETCH_REQUEST_ENTRIES = 8;
  parameter int unsigned AXI_FETCH_LINE_ENTRIES = 8;
  parameter int unsigned DATA_REQUEST_ENTRIES = 8;
  localparam int DATA_TRANSACTION_W = $clog2(DATA_REQUEST_ENTRIES);
  typedef logic [DATA_TRANSACTION_W-1:0] data_transaction_t;
  localparam logic [31:0] AXI_EXIT_ADDR = 32'h8000_0000;

  typedef struct packed {
    logic arValid, rReady, awValid, wValid, bReady;
    logic [31:0] arAddr, awAddr, wData;
    logic [3:0] wStrb;
  } axi_master_t;
  typedef struct packed {
    logic arReady, rValid, awReady, wReady, bValid;
    logic [31:0] rData;
    logic [1:0] rResp, bResp;
  } axi_slave_t;
  parameter int unsigned INT_RS_ENTRIES = 2;
  parameter int unsigned MUL_RS_ENTRIES = 1;
  parameter int unsigned DIV_RS_ENTRIES = 1;
  parameter int unsigned BRANCH_RS_ENTRIES = 2;
  parameter int unsigned LOAD_RS_ENTRIES = 2;
  parameter int unsigned STORE_ADDR_RS_ENTRIES = 2;
  parameter int unsigned STORE_VALUE_RS_ENTRIES = 2;
  // ALU result buffer depth.  Mirrors the software reference ALU_CAP = 1: the
  // reference (since 2026-10-07) applies this cycle's grant/flush before the
  // push, so a single result slot is reusable in the cycle it is drained and
  // one op per cycle is sustained without extra capacity.
  parameter int unsigned ALU_RESULT_ENTRIES = 1;
  parameter int unsigned CACHE_LINE_BYTES = 64;
  parameter int unsigned CACHE_LINE_BITS = CACHE_LINE_BYTES << 3;
  parameter int unsigned ICACHE_SETS = 16;
  parameter int unsigned DCACHE_SETS = 64;
  parameter int unsigned DCACHE_WAYS = 2;
  // DCache line size is decoupled from the ICache line: refill beats, bank
  // count and the external line payload all follow DCACHE_LINE_BYTES while
  // the ICache keeps CACHE_LINE_BYTES.
  parameter int unsigned DCACHE_LINE_BYTES = 32;
  parameter int unsigned DCACHE_LINE_BITS = DCACHE_LINE_BYTES << 3;
  parameter int unsigned RAS_ENTRIES = 16;

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

  // One synchronous baseline read, followed by exactly four replay beats.
  localparam int unsigned RECOVERY_BEATS = 4;
  localparam int unsigned RECOVERY_WIDTH = (ROB_ENTRIES + RECOVERY_BEATS - 1) / RECOVERY_BEATS;
  typedef struct packed {
    logic active;
    logic first;
    logic last;
    rob_tag_t offset;       // Offset in the frozen, head-ordered replay window.
    rob_tag_t nextTag;      // Full identity of the next slot to recover.
    rob_tag_t squashTag;
    rob_tag_t liveCount;    // PRE-squash occupancy, including the canceled suffix.
  } recovery_step_t;

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
    uop_class_e   uopClass;
    operation_e   operation;
    logic [4:0]   rd;
    logic [4:0]   rs1;
    logic [4:0]   rs2;
    logic         usesRs1;
    logic         usesRs2;
    logic         usesImmediate;
    logic         writesRd;
    logic [31:0]  immediate;
    logic [31:0]  programCounter;
    logic [31:0]  instruction;
    logic [31:0]  predictedNextProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
    mem_size_e    memorySize;
    logic         memoryUnsigned;
  } decoded_uop_t;

  typedef struct packed {
    logic [31:0] instruction;
    logic [31:0] programCounter;
    logic [31:0] predictedNextProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
  } decode_context_t;

  typedef struct packed {
    logic valid;
    logic isCall;
    logic isReturn;
    logic jalTargetValid;
    logic [31:0] programCounter;
    logic [31:0] jalTarget;
  } predictor_fetch_info_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic robEntryLive;
    logic [31:0] programCounter;
    logic [31:0] nextProgramCounter;
    logic taken;
    bpu_ckpt_id_t checkpointId;
  } branch_result_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic robEntryLive;
    logic [31:0] programCounter;
    logic [31:0] target;
    logic isReturn;
  } jump_result_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic [31:0] programCounter;
    bpu_ckpt_id_t checkpointId;
  } squash_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic [31:0] programCounter;
    bpu_ckpt_id_t checkpointId;
  } flush_candidate_input_t;

  typedef struct packed {
    logic valid;
    phy_tag_t phyTag;
    logic [31:0] value;
  } cdb_result_t;

  typedef struct packed {
    logic valid;
    operation_e operation;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
    logic source1Ready;
    phy_tag_t source1Tag;
    logic [31:0] source1Value;
    logic source2Ready;
    phy_tag_t source2Tag;
    logic [31:0] source2Value;
    logic [31:0] immediate;
    logic [31:0] programCounter;
    logic [31:0] predictedProgramCounter;
    logic useImmediate;
  } rs_allocation_input_t;

  typedef struct packed {
    logic valid;
    operation_e operation;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
    logic [31:0] source1Value;
    logic [31:0] source2Value;
    logic [31:0] immediate;
    logic [31:0] programCounter;
    logic [31:0] predictedProgramCounter;
    logic useImmediate;
  } rs_issue_output_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
  } rob_flush_input_t;

  typedef struct packed {
    logic [4:0] source1Arch;
    logic [4:0] source2Arch;
  } rat_read_input_t;

  typedef struct packed {
    phy_tag_t source1Phy;
    phy_tag_t source2Phy;
  } rat_read_output_t;

  typedef struct packed {
    logic valid;
    logic [4:0] architecturalRegister;
    phy_tag_t physicalRegister;
  } rat_rename_input_t;

  typedef struct packed {
    phy_tag_t previousPhysicalRegister;
  } rat_rename_output_t;

  typedef struct packed {
    logic valid;
    rob_tag_t squashTag;
    rob_tag_t headTag;
  } rat_restore_input_t;

  typedef struct packed {
    logic valid;
    logic [4:0] architecturalRegister;
    phy_tag_t physicalRegister;
  } rat_commit_input_t;

  typedef struct packed {
    logic valid;
    logic valueValid;
    logic [31:0] value;
  } prf_allocation_input_t;

  typedef struct packed {
    logic valid;
    phy_tag_t physicalRegister;
  } prf_free_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t squashTag;
  } prf_restore_input_t;

  typedef struct packed {
    phy_tag_t physicalRegister;
  } prf_read_input_t;

  typedef struct packed {
    logic ready;
    logic [31:0] value;
  } prf_read_output_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
    mem_size_e size;
    logic isUnsigned;
  } load_allocation_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    mem_size_e size;
    logic dataReady;
    phy_tag_t dataTag;
    logic [31:0] dataValue;
  } store_allocation_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic [31:0] value;
  } store_data_input_t;

  typedef struct packed {
    logic valid;
    logic isStore;
    rob_tag_t robTag;
    logic [31:0] address;
  } lsu_address_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
  } store_commit_input_t;

  // Actual ROB retirement broadcast. LSU recycles a matching live LQ row;
  // non-load retirement tags have no matching row and leave the LQ alone.
  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
  } rob_retirement_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
    logic [31:0] value;
  } load_result_output_t;

  typedef struct packed {
    // Indexed by the package tag's slot bits, even in reduced-DEPTH ROB tests.
    // A bit is qualified only by an old, uncommitted, address/data-ready SQ row.
    logic [ROB_ENTRIES-1:0] readyMask;
    logic [ROB_ENTRIES-1:0] epochMask;
  } store_completion_output_t;

  typedef struct packed {
    logic valid;
    logic write;
    logic [31:0] address;
    logic [31:0] writeData;
    logic [3:0] writeStrobe;
    mem_size_e size;
  } data_memory_request_output_t;

  typedef struct packed {
    logic valid;
    logic [31:0] readData;
  } data_memory_response_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] address;
    logic [31:0] predictedProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
  } icache_cpu_request_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] instruction;
    logic [31:0] address;
    logic [31:0] predictedProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
  } icache_cpu_response_output_t;

  // I$ line returns carry their line identity, as software IMEM::LineReturn.
  // The instruction-line environment acknowledges logical cancellation with
  // memFlushOutput; a physical bus adapter owns any cancelled transport drain.
  typedef struct packed {
    logic valid;
    logic [31:0] address;
    logic [CACHE_LINE_BITS-1:0] data;
  } icache_line_response_input_t;

  typedef struct packed {
    logic [31:0] programCounter;
    logic accepted;
  } fetch_query_output_t;

  typedef struct packed {
    logic valid;
    decode_context_t payload;
  } fetch_queue_output_t;

  typedef struct packed {
    logic valid;
    logic [31:0] address;
    logic [31:0] predictedProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
  } instruction_memory_request_output_t;

  typedef struct packed {
    logic valid;
    logic [31:0] instruction;
  } instruction_memory_response_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] programCounter;
  } redirect_input_t;

  typedef struct packed {
    logic valid;
    logic write;
    logic [31:0] address;
    logic [31:0] writeData;
    logic [3:0] writeStrobe;
    logic [1:0] size;
    data_transaction_t transaction;
  } dcache_cpu_request_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] readData;
    data_transaction_t transaction;
  } dcache_cpu_response_output_t;

  typedef struct packed {
    logic valid;
    logic write;
    logic [31:0] address;
    logic [CACHE_LINE_BITS-1:0] writeData;
  } cache_line_request_output_t;

  typedef struct packed {
    logic valid;
    logic [CACHE_LINE_BITS-1:0] data;
  } cache_line_response_input_t;

  // D$ mirrors the software DMEM's independent read/write line channels.
  // A write handshake transfers the payload; write completion is separate.
  // The DCache line payload follows DCACHE_LINE_BITS, independent of the
  // ICache line width.
  typedef struct packed {
    logic readValid;
    logic [31:0] readAddress;
    logic [1:0] readTransaction;
    logic writeValid;
    logic [31:0] writeAddress;
    logic [1:0] writeTransaction;
    logic [DCACHE_LINE_BITS-1:0] writeData;
  } dcache_line_request_output_t;

  typedef struct packed {
    logic valid;
    logic [31:0] address;
    logic [1:0] transaction;
    logic [DCACHE_LINE_BITS-1:0] data;
  } dcache_line_response_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] address;
    logic [1:0] transaction;
  } dcache_write_response_input_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic exception;
  } rob_completion_t;

  typedef struct packed {
    logic valid;
    logic [31:0] programCounter;
    logic [31:0] instruction;
    logic writesArchitecturalRegister;
    logic [4:0] architecturalRegister;
    phy_tag_t newPhysicalRegister;
    phy_tag_t oldPhysicalRegister;
    logic ready;
    logic isStore;
    logic [2:0] storeQueueIndex;
    logic isHalt;
    logic hasException;
    logic [31:0] predictedProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
    logic isReturn;
  } rob_allocation_input_t;

  typedef struct packed {
    rob_tag_t robTag;
  } rob_lookup_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] programCounter;
    logic [31:0] predictedProgramCounter;
    bpu_ckpt_id_t predictorCheckpointId;
    logic isReturn;
  } rob_lookup_output_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic [31:0] programCounter;
    logic [31:0] instruction;
    logic writesArchitecturalRegister;
    logic [4:0] architecturalRegister;
    phy_tag_t newPhysicalRegister;
    phy_tag_t oldPhysicalRegister;
    logic [2:0] storeQueueIndex;
    logic isHalt;
    logic hasException;
  } rob_commit_output_t;

  typedef struct packed {
    logic empty;
    logic full;
    rob_tag_t headTag;
  } rob_status_output_t;

  // Replay window: RECOVERY_WIDTH consecutive entries starting at the absolute
  // slot head+offset, slot-selected inside the ROB so consumers need no second
  // index. Two shapes, one per consumer class, instead of the full 16-entry
  // rotated window (1280b) that every consumer then had to mux again.
  typedef struct packed {
    rob_tag_t robTag;
    logic [4:0] archRd;
    phy_tag_t newPhy;
  } rob_replay_narrow_t;

  typedef struct packed {
    rob_tag_t robTag;
    logic [31:0] programCounter;
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
  } rob_replay_ras_t;

  typedef struct packed {
    logic willCommit;
    rob_tag_t headTag;
    logic isHeadCall;
    logic isHeadReturn;
    logic [31:0] headProgramCounter;
    rob_replay_ras_t [RECOVERY_WIDTH-1:0] replayRasWindow;
  } rob_predictor_input_t;

  typedef struct packed {
    logic [31:0] nextProgramCounter;
    logic taken;
    bpu_ckpt_id_t checkpointId;
  } prediction_output_t;

  typedef struct packed {
    logic valid;
    logic [31:0] programCounter;
    logic [31:0] nextProgramCounter;
    logic taken;
    logic [7:0] globalHistory;
  } branch_training_input_t;

  typedef struct packed {
    logic fetchAccepted;
    logic squashValid;
    logic queryShift;
    logic queryShiftValue;
    logic [7:0] recoveryHistory;
  } direction_history_input_t;

  typedef struct packed {
    logic directionTaken;
    logic useGlobal;
    logic conditionalSeen;
    logic [7:0] globalHistory;
  } direction_prediction_output_t;

  typedef struct packed {
    logic hit;
    logic unconditional;
    logic isReturn;
    logic [31:0] target;
  } btb_lookup_output_t;

  typedef struct packed {
    logic fetchValid;
    logic isReturn;
    logic jalTargetValid;
    logic [31:0] fetchProgramCounter;
    logic [31:0] jalTarget;
    branch_training_input_t branch;
    logic jumpValid;
    logic [31:0] jumpProgramCounter;
    logic [31:0] jumpTarget;
    logic jumpIsReturn;
  } btb_training_input_t;

  typedef struct packed {
    logic fetchAccepted;
    squash_input_t squash;
    bpu_ckpt_id_t branchCheckpointId;
    logic [7:0] globalHistory;
  } checkpoint_input_t;

  typedef struct packed {
    logic [7:0] branchHistory;
    logic [7:0] recoveryHistory;
    bpu_ckpt_id_t nextCheckpointId;
  } checkpoint_output_t;

  typedef struct packed {
    operation_e operation;
    logic [31:0] leftOperand;
    logic [31:0] rightOperand;
    logic [31:0] immediate;
    logic [31:0] programCounter;
    logic useImmediate;
  } alu_operation_input_t;

  typedef struct packed {
    logic [31:0] value;
  } alu_operation_output_t;

  typedef struct packed {
    logic [31:0] baseAddress;
    logic [31:0] offset;
  } address_generation_input_t;

  typedef struct packed {
    logic [31:0] address;
  } address_generation_output_t;

  typedef struct packed {
    operation_e operation;
    logic [31:0] source1;
    logic [31:0] source2;
    logic [31:0] immediate;
    logic [31:0] programCounter;
    logic [31:0] predictedNextProgramCounter;
  } branch_operation_input_t;

  typedef struct packed {
    logic taken;
    logic [31:0] target;
    logic [31:0] nextProgramCounter;
    logic [31:0] linkValue;
    logic mispredict;
    logic targetMisaligned;
  } branch_operation_output_t;

  typedef struct packed {
    logic valid;
    operation_e operation;
    logic [31:0] source1;
    logic [31:0] source2;
    logic [31:0] immediate;
    logic [31:0] programCounter;
    logic [31:0] predictedNextProgramCounter;
    logic useImmediate;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
    logic isControl;
    logic isCall;
    logic isReturn;
  } execute_request_input_t;

  typedef struct packed {
    logic valid;
    logic [31:0] value;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
  } execute_value_output_t;

  typedef struct packed {
    logic valid;
    logic [31:0] value;
    rob_tag_t robTag;
    phy_tag_t destinationPhy;
    logic isControl;
    logic controlMisaligned;
  } alu_execute_output_t;

  typedef struct packed {
    logic valid;
    rob_tag_t robTag;
    logic [31:0] programCounter;
    logic [31:0] target;
    logic [31:0] nextProgramCounter;
    logic [31:0] returnAddress;
    logic taken;
    logic conditional;
    logic mispredict;
    logic misaligned;
    logic isCall;
    logic isReturn;
  } bru_execute_output_t;

  function automatic logic rob_is_younger(
    input rob_tag_t candidateInput,
    input rob_tag_t boundaryInput
  );
    logic [ROB_TAG_W-1:0] propagateInner;
    logic [ROB_TAG_W-1:0] genBitInner;
    logic [ROB_TAG_W-1:0] groupPInner;
    logic [ROB_TAG_W-1:0] groupGInner;
    begin
      propagateInner = candidateInput ^ ~boundaryInput;
      genBitInner = candidateInput & ~boundaryInput;
      groupPInner = propagateInner;
      groupGInner = genBitInner;
      for (int stageInner = 1; stageInner < ROB_TAG_W; stageInner = stageInner << 1) begin
        for (int bitIndexInner = ROB_TAG_W-1; bitIndexInner >= stageInner;
             bitIndexInner = bitIndexInner - 1) begin
          groupGInner[bitIndexInner] = groupGInner[bitIndexInner] |
                               (groupPInner[bitIndexInner] &
                                groupGInner[bitIndexInner-stageInner]);
          groupPInner[bitIndexInner] = groupPInner[bitIndexInner] &
                               groupPInner[bitIndexInner-stageInner];
        end
      end
      rob_is_younger = (candidateInput != boundaryInput) &&
                       !(propagateInner[ROB_TAG_W-1] ^
                         (groupGInner[ROB_TAG_W-2] |
                          (groupPInner[ROB_TAG_W-2] & 1'b1)));
    end
  endfunction

  function automatic logic rob_is_older(
    input rob_tag_t candidateInput,
    input rob_tag_t referenceInput
  );
    begin
      rob_is_older = rob_is_younger(referenceInput, candidateInput);
    end
  endfunction

  function automatic logic [2:0] mem_bytes(input mem_size_e sizeInput);
    begin
      unique case (sizeInput)
        MEM_BYTE: mem_bytes = 3'd1;
        MEM_HALF: mem_bytes = 3'd2;
        default:  mem_bytes = 3'd4;
      endcase
    end
  endfunction
endpackage
