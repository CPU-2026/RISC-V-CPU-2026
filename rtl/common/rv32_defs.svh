`ifndef RV32_DEFS_SVH
`define RV32_DEFS_SVH

`define RV32_OP_INVALID  6'd0
`define RV32_OP_ADD      6'd1
`define RV32_OP_SUB      6'd2
`define RV32_OP_SLL      6'd3
`define RV32_OP_SLT      6'd4
`define RV32_OP_SLTU     6'd5
`define RV32_OP_XOR      6'd6
`define RV32_OP_SRL      6'd7
`define RV32_OP_SRA      6'd8
`define RV32_OP_OR       6'd9
`define RV32_OP_AND      6'd10
`define RV32_OP_LUI      6'd11
`define RV32_OP_AUIPC    6'd12
`define RV32_OP_MUL      6'd13
`define RV32_OP_MULH     6'd14
`define RV32_OP_MULHSU   6'd15
`define RV32_OP_MULHU    6'd16
`define RV32_OP_DIV      6'd17
`define RV32_OP_DIVU     6'd18
`define RV32_OP_REM      6'd19
`define RV32_OP_REMU     6'd20
`define RV32_OP_BEQ      6'd21
`define RV32_OP_BNE      6'd22
`define RV32_OP_BLT      6'd23
`define RV32_OP_BGE      6'd24
`define RV32_OP_BLTU     6'd25
`define RV32_OP_BGEU     6'd26
`define RV32_OP_JAL      6'd27
`define RV32_OP_JALR     6'd28
`define RV32_OP_LOAD     6'd29
`define RV32_OP_STORE    6'd30

`endif
