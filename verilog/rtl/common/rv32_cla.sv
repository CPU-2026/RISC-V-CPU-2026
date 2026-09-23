/* verilator lint_off DECLFILENAME */

module rv32_cla2 (
  input  logic [1:0] aInput,
  input  logic [1:0] bInput,
  input  logic       cinInput,
  output logic [1:0] sumOutput,
  output logic       coutOutput
);
  logic [1:0] pInner, gInner, cInner;

  assign pInner = aInput ^ bInput;
  assign gInner = aInput & bInput;
  assign cInner = {gInner[0] | (pInner[0] & cinInput), cinInput};
  assign sumOutput = pInner ^ cInner;
  assign coutOutput = gInner[1] | (pInner[1] & cInner[1]);
endmodule

module rv32_cla4 (
  input  logic [3:0] aInput,
  input  logic [3:0] bInput,
  input  logic       cinInput,
  output logic [3:0] sumOutput,
  output logic       coutOutput,
  output logic       pgOutput,
  output logic       ggOutput
);
  logic [3:0] pInner, gInner, cInner;

  assign pInner = aInput ^ bInput;
  assign gInner = aInput & bInput;
  assign cInner = {
    gInner[2] | (pInner[2] & gInner[1]) | (pInner[2] & pInner[1] & gInner[0]) |
      (pInner[2] & pInner[1] & pInner[0] & cinInput),
    gInner[1] | (pInner[1] & gInner[0]) | (pInner[1] & pInner[0] & cinInput),
    gInner[0] | (pInner[0] & cinInput),
    cinInput
  };
  assign pgOutput = pInner[3] & pInner[2] & pInner[1] & pInner[0];
  assign ggOutput = gInner[3] | (pInner[3] & gInner[2]) | (pInner[3] & pInner[2] & gInner[1]) |
                (pInner[3] & pInner[2] & pInner[1] & gInner[0]);
  assign sumOutput = pInner ^ cInner;
  assign coutOutput = ggOutput | (pgOutput & cinInput);
endmodule

module rv32_cla8 (
  input  logic [7:0] aInput,
  input  logic [7:0] bInput,
  input  logic       cinInput,
  output logic [7:0] sumOutput,
  output logic       coutOutput,
  output logic       pgOutput,
  output logic       ggOutput
);
  logic pgLoInner, pgHiInner, ggLoInner, ggHiInner;
  logic [3:0] sumLoInner, sumHiInner;
  logic coutLoInner, coutHiInner;
  logic carry4Inner;

  assign carry4Inner = ggLoInner | (pgLoInner & cinInput);

  rv32_cla4 u_low (
    .aInput(aInput[3:0]), .bInput(bInput[3:0]), .cinInput(cinInput),
    .sumOutput(sumLoInner), .coutOutput(coutLoInner), .pgOutput(pgLoInner), .ggOutput(ggLoInner)
  );
  rv32_cla4 u_high (
    .aInput(aInput[7:4]), .bInput(bInput[7:4]), .cinInput(carry4Inner),
    .sumOutput(sumHiInner), .coutOutput(coutHiInner), .pgOutput(pgHiInner), .ggOutput(ggHiInner)
  );

  assign sumOutput = {sumHiInner, sumLoInner};
  assign pgOutput = pgHiInner & pgLoInner;
  assign ggOutput = ggHiInner | (pgHiInner & ggLoInner);
  assign coutOutput = ggOutput | (pgOutput & cinInput);
endmodule

module rv32_cla16 (
  input  logic [15:0] aInput,
  input  logic [15:0] bInput,
  input  logic        cinInput,
  output logic [15:0] sumOutput,
  output logic        coutOutput,
  output logic        pgOutput,
  output logic        ggOutput
);
  logic [3:0] pgBlockInner, ggBlockInner;
  logic [3:0] coutBlockInner;
  logic [4:0] carryInner;

  assign carryInner = {
    ggBlockInner[3] | (pgBlockInner[3] & ggBlockInner[2]) |
      (pgBlockInner[3] & pgBlockInner[2] & ggBlockInner[1]) |
      (pgBlockInner[3] & pgBlockInner[2] & pgBlockInner[1] & ggBlockInner[0]) |
      (pgBlockInner[3] & pgBlockInner[2] & pgBlockInner[1] & pgBlockInner[0] & cinInput),
    ggBlockInner[2] | (pgBlockInner[2] & ggBlockInner[1]) |
      (pgBlockInner[2] & pgBlockInner[1] & ggBlockInner[0]) |
      (pgBlockInner[2] & pgBlockInner[1] & pgBlockInner[0] & cinInput),
    ggBlockInner[1] | (pgBlockInner[1] & ggBlockInner[0]) |
      (pgBlockInner[1] & pgBlockInner[0] & cinInput),
    ggBlockInner[0] | (pgBlockInner[0] & cinInput),
    cinInput
  };
  assign pgOutput = pgBlockInner[3] & pgBlockInner[2] & pgBlockInner[1] & pgBlockInner[0];
  assign ggOutput = ggBlockInner[3] | (pgBlockInner[3] & ggBlockInner[2]) |
                (pgBlockInner[3] & pgBlockInner[2] & ggBlockInner[1]) |
                (pgBlockInner[3] & pgBlockInner[2] & pgBlockInner[1] & ggBlockInner[0]);
  assign coutOutput = carryInner[4];

  genvar blockIndexInner;
  generate
    for (blockIndexInner = 0; blockIndexInner < 4; blockIndexInner = blockIndexInner + 1) begin : g_blocks
      rv32_cla4 u_block (
        .aInput(aInput[4*blockIndexInner +: 4]), .bInput(bInput[4*blockIndexInner +: 4]),
        .cinInput(carryInner[blockIndexInner]), .sumOutput(sumOutput[4*blockIndexInner +: 4]),
        .coutOutput(coutBlockInner[blockIndexInner]),
        .pgOutput(pgBlockInner[blockIndexInner]), .ggOutput(ggBlockInner[blockIndexInner])
      );
    end
  endgenerate
endmodule

module rv32_cla32 (
  input  logic [31:0] aInput,
  input  logic [31:0] bInput,
  input  logic        cinInput,
  output logic [31:0] sumOutput,
  output logic        coutOutput,
  output logic        pgOutput,
  output logic        ggOutput
);
  logic pgLoInner, pgHiInner, ggLoInner, ggHiInner;
  logic [15:0] sumLoInner, sumHiInner;
  logic coutLoInner, coutHiInner;
  logic carry16Inner;

  assign carry16Inner = ggLoInner | (pgLoInner & cinInput);

  rv32_cla16 u_low (
    .aInput(aInput[15:0]), .bInput(bInput[15:0]), .cinInput(cinInput),
    .sumOutput(sumLoInner), .coutOutput(coutLoInner), .pgOutput(pgLoInner), .ggOutput(ggLoInner)
  );
  rv32_cla16 u_high (
    .aInput(aInput[31:16]), .bInput(bInput[31:16]), .cinInput(carry16Inner),
    .sumOutput(sumHiInner), .coutOutput(coutHiInner), .pgOutput(pgHiInner), .ggOutput(ggHiInner)
  );

  assign sumOutput = {sumHiInner, sumLoInner};
  assign pgOutput = pgHiInner & pgLoInner;
  assign ggOutput = ggHiInner | (pgHiInner & ggLoInner);
  assign coutOutput = ggOutput | (pgOutput & cinInput);
endmodule

module rv32_cla64 (
  input  logic [63:0] aInput,
  input  logic [63:0] bInput,
  input  logic        cinInput,
  output logic [63:0] sumOutput,
  output logic        coutOutput
);
  logic pgLoInner, pgHiInner, ggLoInner, ggHiInner;
  logic [31:0] sumLoInner, sumHiInner;
  logic coutLoInner, coutHiInner;
  logic carry32Inner;

  assign carry32Inner = ggLoInner | (pgLoInner & cinInput);

  rv32_cla32 u_low (
    .aInput(aInput[31:0]), .bInput(bInput[31:0]), .cinInput(cinInput),
    .sumOutput(sumLoInner), .coutOutput(coutLoInner), .pgOutput(pgLoInner), .ggOutput(ggLoInner)
  );
  rv32_cla32 u_high (
    .aInput(aInput[63:32]), .bInput(bInput[63:32]), .cinInput(carry32Inner),
    .sumOutput(sumHiInner), .coutOutput(coutHiInner), .pgOutput(pgHiInner), .ggOutput(ggHiInner)
  );

  assign sumOutput = {sumHiInner, sumLoInner};
  assign coutOutput = ggHiInner | (pgHiInner & carry32Inner);
endmodule

module rv32_add #(
  parameter int unsigned WIDTH = 32
) (
  input  logic [WIDTH-1:0] aInput,
  input  logic [WIDTH-1:0] bInput,
  input  logic             cinInput,
  output logic [WIDTH-1:0] sumOutput,
  output logic             coutOutput
);
  localparam int unsigned CLA_WIDTH = (WIDTH <= 2) ? 2 :
                                      (WIDTH <= 4) ? 4 :
                                      (WIDTH <= 8) ? 8 :
                                      (WIDTH <= 16) ? 16 :
                                      (WIDTH <= 32) ? 32 : 64;

  logic [CLA_WIDTH-1:0] aExtInner, bExtInner, sumExtInner;
  logic coutExtInner;
  logic unusedPgInner, unusedGgInner;

  assign sumOutput = sumExtInner[WIDTH-1:0];

  generate
    if (CLA_WIDTH == WIDTH) begin : g_ext_native
      assign aExtInner = aInput;
      assign bExtInner = bInput;
    end else begin : g_ext_padded
      assign aExtInner = {{(CLA_WIDTH-WIDTH){1'b0}}, aInput};
      assign bExtInner = {{(CLA_WIDTH-WIDTH){1'b0}}, bInput};
    end
  endgenerate

  generate
    if (CLA_WIDTH == 2) begin : g_cla2
      rv32_cla2 u_cla (
        .aInput(aExtInner), .bInput(bExtInner), .cinInput(cinInput),
        .sumOutput(sumExtInner), .coutOutput(coutExtInner)
      );
    end else if (CLA_WIDTH == 4) begin : g_cla4
      rv32_cla4 u_cla (
        .aInput(aExtInner), .bInput(bExtInner), .cinInput(cinInput),
        .sumOutput(sumExtInner), .coutOutput(coutExtInner),
        .pgOutput(unusedPgInner), .ggOutput(unusedGgInner)
      );
    end else if (CLA_WIDTH == 8) begin : g_cla8
      rv32_cla8 u_cla (
        .aInput(aExtInner), .bInput(bExtInner), .cinInput(cinInput),
        .sumOutput(sumExtInner), .coutOutput(coutExtInner),
        .pgOutput(unusedPgInner), .ggOutput(unusedGgInner)
      );
    end else if (CLA_WIDTH == 16) begin : g_cla16
      rv32_cla16 u_cla (
        .aInput(aExtInner), .bInput(bExtInner), .cinInput(cinInput),
        .sumOutput(sumExtInner), .coutOutput(coutExtInner),
        .pgOutput(unusedPgInner), .ggOutput(unusedGgInner)
      );
    end else if (CLA_WIDTH == 32) begin : g_cla32
      rv32_cla32 u_cla (
        .aInput(aExtInner), .bInput(bExtInner), .cinInput(cinInput),
        .sumOutput(sumExtInner), .coutOutput(coutExtInner),
        .pgOutput(unusedPgInner), .ggOutput(unusedGgInner)
      );
    end else begin : g_cla64
      rv32_cla64 u_cla (
        .aInput(aExtInner), .bInput(bExtInner), .cinInput(cinInput),
        .sumOutput(sumExtInner), .coutOutput(coutExtInner)
      );
    end
  endgenerate

  generate
    if (CLA_WIDTH == WIDTH) begin : g_carry_native
      assign coutOutput = coutExtInner;
    end else begin : g_carry_extended
      assign coutOutput = sumExtInner[WIDTH];
    end
  endgenerate
endmodule

module rv32_sub #(
  parameter int unsigned WIDTH = 32
) (
  input  logic [WIDTH-1:0] aInput,
  input  logic [WIDTH-1:0] bInput,
  output logic [WIDTH-1:0] diffOutput,
  output logic             borrowOutput
);
  logic carryInner;

  rv32_add #(.WIDTH(WIDTH)) u_add (
    .aInput(aInput), .bInput(~bInput), .cinInput(1'b1),
    .sumOutput(diffOutput), .coutOutput(carryInner)
  );

  assign borrowOutput = ~carryInner;
endmodule

/* verilator lint_on DECLFILENAME */
