// Generated from the supplied source list by verilog/export_rtl.py; edit the sources instead.
`line 3 "generated/student_top.sv" 0
module rv32_issue_config;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	parameter [31:0] ISSUE_WIDTH = rv32_pkg_ISSUE_WIDTH;
	generate
		if (((ISSUE_WIDTH != 1) && (ISSUE_WIDTH != 2)) && (ISSUE_WIDTH != 4)) begin : g_invalid_width
			initial $fatal(1, "CPU_ISSUE_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] rv32_pkg_RENAME_WIDTH = 4;
	localparam [31:0] rv32_pkg_COMMIT_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	generate
		if (!(!(rv32_pkg_ROB_ENTRIES < ISSUE_WIDTH)) || 1'd0) begin : g_invalid_rob_capacity
			initial $fatal(1, "CPU_ROB_ENTRIES must be a power of two >= 16 and cover allocation/commit width");
		end
	endgenerate
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	localparam [31:0] rv32_pkg_ARCH_REGS = 32;
	generate
		if (rv32_pkg_PRF_ENTRIES < (rv32_pkg_ARCH_REGS + rv32_pkg_ROB_ENTRIES)) begin : g_insufficient_physical_registers
			initial $fatal(1, "issue-width PRF does not cover architectural plus in-flight destinations");
		end
	endgenerate
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	generate
		if ((rv32_pkg_BPU_CKPT_ENTRIES < 2) || ((rv32_pkg_BPU_CKPT_ENTRIES & (rv32_pkg_BPU_CKPT_ENTRIES - 1)) != 0)) begin : g_invalid_checkpoint_capacity
			initial $fatal(1, "CPU_BPU_CKPT_ENTRIES must be a power of two >= 2");
		end
	endgenerate
	localparam [31:0] rv32_pkg_FETCH_REQUEST_ENTRIES = 8;
	localparam [31:0] rv32_pkg_FQ_ENTRIES = rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH);
	localparam [31:0] rv32_pkg_IQ_ENTRIES = rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH);
	generate
		if (rv32_pkg_BPU_CKPT_ENTRIES < (((rv32_pkg_ROB_ENTRIES + rv32_pkg_FETCH_REQUEST_ENTRIES) + rv32_pkg_FQ_ENTRIES) + rv32_pkg_IQ_ENTRIES)) begin : g_checkpoint_budget
			initial $fatal(1, "issue-width configuration exceeds checkpoint live budget");
		end
	endgenerate
endmodule
module rv32_cla2 (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput
);
	input wire [1:0] aInput;
	input wire [1:0] bInput;
	input wire cinInput;
	output wire [1:0] sumOutput;
	output wire coutOutput;
	wire [1:0] pInner;
	wire [1:0] gInner;
	wire [1:0] cInner;
	assign pInner = aInput ^ bInput;
	assign gInner = aInput & bInput;
	assign cInner = {gInner[0] | (pInner[0] & cinInput), cinInput};
	assign sumOutput = pInner ^ cInner;
	assign coutOutput = gInner[1] | (pInner[1] & cInner[1]);
endmodule
module rv32_cla4 (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput,
	pgOutput,
	ggOutput
);
	input wire [3:0] aInput;
	input wire [3:0] bInput;
	input wire cinInput;
	output wire [3:0] sumOutput;
	output wire coutOutput;
	output wire pgOutput;
	output wire ggOutput;
	wire [3:0] pInner;
	wire [3:0] gInner;
	wire [3:0] cInner;
	assign pInner = aInput ^ bInput;
	assign gInner = aInput & bInput;
	assign cInner = {((gInner[2] | (pInner[2] & gInner[1])) | ((pInner[2] & pInner[1]) & gInner[0])) | (((pInner[2] & pInner[1]) & pInner[0]) & cinInput), (gInner[1] | (pInner[1] & gInner[0])) | ((pInner[1] & pInner[0]) & cinInput), gInner[0] | (pInner[0] & cinInput), cinInput};
	assign pgOutput = ((pInner[3] & pInner[2]) & pInner[1]) & pInner[0];
	assign ggOutput = ((gInner[3] | (pInner[3] & gInner[2])) | ((pInner[3] & pInner[2]) & gInner[1])) | (((pInner[3] & pInner[2]) & pInner[1]) & gInner[0]);
	assign sumOutput = pInner ^ cInner;
	assign coutOutput = ggOutput | (pgOutput & cinInput);
endmodule
module rv32_cla8 (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput,
	pgOutput,
	ggOutput
);
	input wire [7:0] aInput;
	input wire [7:0] bInput;
	input wire cinInput;
	output wire [7:0] sumOutput;
	output wire coutOutput;
	output wire pgOutput;
	output wire ggOutput;
	wire pgLoInner;
	wire pgHiInner;
	wire ggLoInner;
	wire ggHiInner;
	wire [3:0] sumLoInner;
	wire [3:0] sumHiInner;
	wire coutLoInner;
	wire coutHiInner;
	wire carry4Inner;
	assign carry4Inner = ggLoInner | (pgLoInner & cinInput);
	rv32_cla4 u_low(
		.aInput(aInput[3:0]),
		.bInput(bInput[3:0]),
		.cinInput(cinInput),
		.sumOutput(sumLoInner),
		.coutOutput(coutLoInner),
		.pgOutput(pgLoInner),
		.ggOutput(ggLoInner)
	);
	rv32_cla4 u_high(
		.aInput(aInput[7:4]),
		.bInput(bInput[7:4]),
		.cinInput(carry4Inner),
		.sumOutput(sumHiInner),
		.coutOutput(coutHiInner),
		.pgOutput(pgHiInner),
		.ggOutput(ggHiInner)
	);
	assign sumOutput = {sumHiInner, sumLoInner};
	assign pgOutput = pgHiInner & pgLoInner;
	assign ggOutput = ggHiInner | (pgHiInner & ggLoInner);
	assign coutOutput = ggOutput | (pgOutput & cinInput);
endmodule
module rv32_cla16 (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput,
	pgOutput,
	ggOutput
);
	input wire [15:0] aInput;
	input wire [15:0] bInput;
	input wire cinInput;
	output wire [15:0] sumOutput;
	output wire coutOutput;
	output wire pgOutput;
	output wire ggOutput;
	wire [3:0] pgBlockInner;
	wire [3:0] ggBlockInner;
	wire [3:0] coutBlockInner;
	wire [4:0] carryInner;
	assign carryInner = {(((ggBlockInner[3] | (pgBlockInner[3] & ggBlockInner[2])) | ((pgBlockInner[3] & pgBlockInner[2]) & ggBlockInner[1])) | (((pgBlockInner[3] & pgBlockInner[2]) & pgBlockInner[1]) & ggBlockInner[0])) | ((((pgBlockInner[3] & pgBlockInner[2]) & pgBlockInner[1]) & pgBlockInner[0]) & cinInput), ((ggBlockInner[2] | (pgBlockInner[2] & ggBlockInner[1])) | ((pgBlockInner[2] & pgBlockInner[1]) & ggBlockInner[0])) | (((pgBlockInner[2] & pgBlockInner[1]) & pgBlockInner[0]) & cinInput), (ggBlockInner[1] | (pgBlockInner[1] & ggBlockInner[0])) | ((pgBlockInner[1] & pgBlockInner[0]) & cinInput), ggBlockInner[0] | (pgBlockInner[0] & cinInput), cinInput};
	assign pgOutput = ((pgBlockInner[3] & pgBlockInner[2]) & pgBlockInner[1]) & pgBlockInner[0];
	assign ggOutput = ((ggBlockInner[3] | (pgBlockInner[3] & ggBlockInner[2])) | ((pgBlockInner[3] & pgBlockInner[2]) & ggBlockInner[1])) | (((pgBlockInner[3] & pgBlockInner[2]) & pgBlockInner[1]) & ggBlockInner[0]);
	assign coutOutput = carryInner[4];
	genvar _gv_blockIndexInner_1;
	generate
		for (_gv_blockIndexInner_1 = 0; _gv_blockIndexInner_1 < 4; _gv_blockIndexInner_1 = _gv_blockIndexInner_1 + 1) begin : g_blocks
			localparam blockIndexInner = _gv_blockIndexInner_1;
			rv32_cla4 u_block(
				.aInput(aInput[4 * blockIndexInner+:4]),
				.bInput(bInput[4 * blockIndexInner+:4]),
				.cinInput(carryInner[blockIndexInner]),
				.sumOutput(sumOutput[4 * blockIndexInner+:4]),
				.coutOutput(coutBlockInner[blockIndexInner]),
				.pgOutput(pgBlockInner[blockIndexInner]),
				.ggOutput(ggBlockInner[blockIndexInner])
			);
		end
	endgenerate
endmodule
module rv32_cla32 (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput,
	pgOutput,
	ggOutput
);
	input wire [31:0] aInput;
	input wire [31:0] bInput;
	input wire cinInput;
	output wire [31:0] sumOutput;
	output wire coutOutput;
	output wire pgOutput;
	output wire ggOutput;
	wire pgLoInner;
	wire pgHiInner;
	wire ggLoInner;
	wire ggHiInner;
	wire [15:0] sumLoInner;
	wire [15:0] sumHiInner;
	wire coutLoInner;
	wire coutHiInner;
	wire carry16Inner;
	assign carry16Inner = ggLoInner | (pgLoInner & cinInput);
	rv32_cla16 u_low(
		.aInput(aInput[15:0]),
		.bInput(bInput[15:0]),
		.cinInput(cinInput),
		.sumOutput(sumLoInner),
		.coutOutput(coutLoInner),
		.pgOutput(pgLoInner),
		.ggOutput(ggLoInner)
	);
	rv32_cla16 u_high(
		.aInput(aInput[31:16]),
		.bInput(bInput[31:16]),
		.cinInput(carry16Inner),
		.sumOutput(sumHiInner),
		.coutOutput(coutHiInner),
		.pgOutput(pgHiInner),
		.ggOutput(ggHiInner)
	);
	assign sumOutput = {sumHiInner, sumLoInner};
	assign pgOutput = pgHiInner & pgLoInner;
	assign ggOutput = ggHiInner | (pgHiInner & ggLoInner);
	assign coutOutput = ggOutput | (pgOutput & cinInput);
endmodule
module rv32_cla64 (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput
);
	input wire [63:0] aInput;
	input wire [63:0] bInput;
	input wire cinInput;
	output wire [63:0] sumOutput;
	output wire coutOutput;
	wire pgLoInner;
	wire pgHiInner;
	wire ggLoInner;
	wire ggHiInner;
	wire [31:0] sumLoInner;
	wire [31:0] sumHiInner;
	wire coutLoInner;
	wire coutHiInner;
	wire carry32Inner;
	assign carry32Inner = ggLoInner | (pgLoInner & cinInput);
	rv32_cla32 u_low(
		.aInput(aInput[31:0]),
		.bInput(bInput[31:0]),
		.cinInput(cinInput),
		.sumOutput(sumLoInner),
		.coutOutput(coutLoInner),
		.pgOutput(pgLoInner),
		.ggOutput(ggLoInner)
	);
	rv32_cla32 u_high(
		.aInput(aInput[63:32]),
		.bInput(bInput[63:32]),
		.cinInput(carry32Inner),
		.sumOutput(sumHiInner),
		.coutOutput(coutHiInner),
		.pgOutput(pgHiInner),
		.ggOutput(ggHiInner)
	);
	assign sumOutput = {sumHiInner, sumLoInner};
	assign coutOutput = ggHiInner | (pgHiInner & carry32Inner);
endmodule
module rv32_add (
	aInput,
	bInput,
	cinInput,
	sumOutput,
	coutOutput
);
	parameter [31:0] WIDTH = 32;
	input wire [WIDTH - 1:0] aInput;
	input wire [WIDTH - 1:0] bInput;
	input wire cinInput;
	output wire [WIDTH - 1:0] sumOutput;
	output wire coutOutput;
	localparam [31:0] CLA_WIDTH = (WIDTH <= 2 ? 2 : (WIDTH <= 4 ? 4 : (WIDTH <= 8 ? 8 : (WIDTH <= 16 ? 16 : (WIDTH <= 32 ? 32 : 64)))));
	wire [CLA_WIDTH - 1:0] aExtInner;
	wire [CLA_WIDTH - 1:0] bExtInner;
	wire [CLA_WIDTH - 1:0] sumExtInner;
	wire coutExtInner;
	wire unusedPgInner;
	wire unusedGgInner;
	assign sumOutput = sumExtInner[WIDTH - 1:0];
	generate
		if (CLA_WIDTH == WIDTH) begin : g_ext_native
			assign aExtInner = aInput;
			assign bExtInner = bInput;
		end
		else begin : g_ext_padded
			assign aExtInner = {{CLA_WIDTH - WIDTH {1'b0}}, aInput};
			assign bExtInner = {{CLA_WIDTH - WIDTH {1'b0}}, bInput};
		end
		if (CLA_WIDTH == 2) begin : g_cla2
			rv32_cla2 u_cla(
				.aInput(aExtInner),
				.bInput(bExtInner),
				.cinInput(cinInput),
				.sumOutput(sumExtInner),
				.coutOutput(coutExtInner)
			);
		end
		else if (CLA_WIDTH == 4) begin : g_cla4
			rv32_cla4 u_cla(
				.aInput(aExtInner),
				.bInput(bExtInner),
				.cinInput(cinInput),
				.sumOutput(sumExtInner),
				.coutOutput(coutExtInner),
				.pgOutput(unusedPgInner),
				.ggOutput(unusedGgInner)
			);
		end
		else if (CLA_WIDTH == 8) begin : g_cla8
			rv32_cla8 u_cla(
				.aInput(aExtInner),
				.bInput(bExtInner),
				.cinInput(cinInput),
				.sumOutput(sumExtInner),
				.coutOutput(coutExtInner),
				.pgOutput(unusedPgInner),
				.ggOutput(unusedGgInner)
			);
		end
		else if (CLA_WIDTH == 16) begin : g_cla16
			rv32_cla16 u_cla(
				.aInput(aExtInner),
				.bInput(bExtInner),
				.cinInput(cinInput),
				.sumOutput(sumExtInner),
				.coutOutput(coutExtInner),
				.pgOutput(unusedPgInner),
				.ggOutput(unusedGgInner)
			);
		end
		else if (CLA_WIDTH == 32) begin : g_cla32
			rv32_cla32 u_cla(
				.aInput(aExtInner),
				.bInput(bExtInner),
				.cinInput(cinInput),
				.sumOutput(sumExtInner),
				.coutOutput(coutExtInner),
				.pgOutput(unusedPgInner),
				.ggOutput(unusedGgInner)
			);
		end
		else begin : g_cla64
			rv32_cla64 u_cla(
				.aInput(aExtInner),
				.bInput(bExtInner),
				.cinInput(cinInput),
				.sumOutput(sumExtInner),
				.coutOutput(coutExtInner)
			);
		end
		if (CLA_WIDTH == WIDTH) begin : g_carry_native
			assign coutOutput = coutExtInner;
		end
		else begin : g_carry_extended
			assign coutOutput = sumExtInner[WIDTH];
		end
	endgenerate
endmodule
module rv32_sub (
	aInput,
	bInput,
	diffOutput,
	borrowOutput
);
	parameter [31:0] WIDTH = 32;
	input wire [WIDTH - 1:0] aInput;
	input wire [WIDTH - 1:0] bInput;
	output wire [WIDTH - 1:0] diffOutput;
	output wire borrowOutput;
	wire carryInner;
	rv32_add #(.WIDTH(WIDTH)) u_add(
		.aInput(aInput),
		.bInput(~bInput),
		.cinInput(1'b1),
		.sumOutput(diffOutput),
		.coutOutput(carryInner)
	);
	assign borrowOutput = ~carryInner;
endmodule
module rv32_epoch_fifo (
	clkInput,
	rstNInput,
	flushInput,
	freezeInput,
	inValidInput,
	inReadyOutput,
	inDataInput,
	outValidOutput,
	outReadyInput,
	outDataOutput,
	countOutput
);
	parameter [31:0] DEPTH = 4;
	parameter [31:0] WIDTH = 32;
	localparam [31:0] SLOT_W = $clog2(DEPTH);
	localparam [31:0] SEQ_W = SLOT_W + 1;
	input wire clkInput;
	input wire rstNInput;
	input wire flushInput;
	input wire freezeInput;
	input wire inValidInput;
	output wire inReadyOutput;
	input wire [WIDTH - 1:0] inDataInput;
	output wire outValidOutput;
	input wire outReadyInput;
	output wire [WIDTH - 1:0] outDataOutput;
	output wire [SEQ_W - 1:0] countOutput;
	reg [SEQ_W - 1:0] headInner;
	reg [SEQ_W - 1:0] tailInner;
	reg [WIDTH - 1:0] entriesInner [0:DEPTH - 1];
	wire emptyInner;
	wire fullInner;
	assign emptyInner = headInner == tailInner;
	function automatic [SEQ_W - 1:0] sv2v_cast_A6A5F;
		input reg [SEQ_W - 1:0] inp;
		sv2v_cast_A6A5F = inp;
	endfunction
	assign fullInner = tailInner == (headInner ^ sv2v_cast_A6A5F(DEPTH));
	assign countOutput = tailInner - headInner;
	assign inReadyOutput = (!fullInner || (outValidOutput && outReadyInput)) && !flushInput;
	assign outValidOutput = !emptyInner && !flushInput;
	assign outDataOutput = (emptyInner ? {WIDTH {1'sb0}} : entriesInner[headInner[SLOT_W - 1:0]]);
	function automatic signed [SEQ_W - 1:0] sv2v_cast_A6A5F_signed;
		input reg signed [SEQ_W - 1:0] inp;
		sv2v_cast_A6A5F_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
		end
		else if (!freezeInput && flushInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
		end
		else if (!freezeInput) begin
			if (inValidInput && inReadyOutput) begin
				entriesInner[tailInner[SLOT_W - 1:0]] <= inDataInput;
				tailInner <= tailInner + sv2v_cast_A6A5F_signed(1);
			end
			if (outValidOutput && outReadyInput)
				headInner <= headInner + sv2v_cast_A6A5F_signed(1);
		end
`ifndef SYNTHESIS
	initial if ((DEPTH < 2) || ((DEPTH & (DEPTH - 1)) != 0))
		$fatal(1, "epoch FIFO DEPTH must be a power of two >= 2");
	always @(posedge clkInput)
		if (rstNInput)
			assert (countOutput <= sv2v_cast_A6A5F(DEPTH)) else $fatal(1, "epoch FIFO occupancy outside capacity");
`endif
endmodule
module rv32_prefix_fifo (
	clkInput,
	rstNInput,
	freezeInput,
	flushInput,
	inValidInput,
	inCreditInput,
	inCountInput,
	inDataInput,
	inReadyOutput,
	inCapacityOutput,
	outCountOutput,
	outDataOutput,
	outReadyCountInput,
	countOutput,
	emptyOutput
);
	parameter [31:0] DEPTH = 4;
	parameter [31:0] WIDTH = 32;
	parameter [31:0] PUSH_WIDTH = 2;
	parameter [31:0] POP_WIDTH = 2;
	parameter [0:0] EXTERNAL_CREDIT = 1'b0;
	localparam [31:0] SLOT_W = $clog2(DEPTH);
	localparam [31:0] SEQ_W = SLOT_W + 1;
	localparam [31:0] PUSH_W = $clog2(PUSH_WIDTH + 1);
	localparam [31:0] POP_W = $clog2(POP_WIDTH + 1);
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire flushInput;
	input wire inValidInput;
	input wire inCreditInput;
	input wire [PUSH_W - 1:0] inCountInput;
	input wire [(PUSH_WIDTH * WIDTH) - 1:0] inDataInput;
	output wire inReadyOutput;
	output wire [SEQ_W - 1:0] inCapacityOutput;
	output wire [POP_W - 1:0] outCountOutput;
	output wire [(POP_WIDTH * WIDTH) - 1:0] outDataOutput;
	input wire [POP_W - 1:0] outReadyCountInput;
	output wire [SEQ_W - 1:0] countOutput;
	output wire emptyOutput;
	reg [SEQ_W - 1:0] headInner;
	reg [SEQ_W - 1:0] tailInner;
	reg [WIDTH - 1:0] entriesInner [0:DEPTH - 1];
	wire [POP_W - 1:0] popInner;
	wire [PUSH_W - 1:0] pushInner;
	reg emptyInner;
	assign countOutput = tailInner - headInner;
	function automatic [SEQ_W - 1:0] sv2v_cast_A6A5F;
		input reg [SEQ_W - 1:0] inp;
		sv2v_cast_A6A5F = inp;
	endfunction
	function automatic [POP_W - 1:0] sv2v_cast_E3A37;
		input reg [POP_W - 1:0] inp;
		sv2v_cast_E3A37 = inp;
	endfunction
	assign outCountOutput = (flushInput ? {POP_W {1'sb0}} : (countOutput < sv2v_cast_A6A5F(POP_WIDTH) ? sv2v_cast_E3A37(countOutput) : sv2v_cast_E3A37(POP_WIDTH)));
	assign popInner = (outReadyCountInput < outCountOutput ? outReadyCountInput : outCountOutput);
	assign inCapacityOutput = (sv2v_cast_A6A5F(DEPTH) - countOutput) + sv2v_cast_A6A5F(popInner);
	reg countReadyInner;
	function automatic [PUSH_W - 1:0] sv2v_cast_B0505;
		input reg [PUSH_W - 1:0] inp;
		sv2v_cast_B0505 = inp;
	endfunction
	function automatic signed [POP_W - 1:0] sv2v_cast_E3A37_signed;
		input reg signed [POP_W - 1:0] inp;
		sv2v_cast_E3A37_signed = inp;
	endfunction
	function automatic signed [PUSH_W - 1:0] sv2v_cast_B0505_signed;
		input reg signed [PUSH_W - 1:0] inp;
		sv2v_cast_B0505_signed = inp;
	endfunction
	generate
		if (PUSH_WIDTH == 2) begin : g_prefix_credit
			wire oneSpaceInner;
			wire twoSpaceInner;
			wire popOneInner;
			wire popTwoInner;
			assign oneSpaceInner = countOutput < sv2v_cast_A6A5F(DEPTH);
			assign twoSpaceInner = countOutput <= sv2v_cast_A6A5F(DEPTH - 2);
			assign popOneInner = |popInner;
			assign popTwoInner = popInner > sv2v_cast_E3A37_signed(1);
			always @* case (inCountInput)
				sv2v_cast_B0505_signed(0): countReadyInner = !flushInput;
				sv2v_cast_B0505_signed(1): countReadyInner = !flushInput && (oneSpaceInner || popOneInner);
				sv2v_cast_B0505_signed(2): countReadyInner = !flushInput && ((twoSpaceInner || (oneSpaceInner && popOneInner)) || popTwoInner);
				default: countReadyInner = 1'b0;
			endcase
		end
		else begin : g_generic_credit
			wire [1:1] sv2v_tmp_01427;
			assign sv2v_tmp_01427 = (!flushInput && (inCountInput <= sv2v_cast_B0505(PUSH_WIDTH))) && (sv2v_cast_A6A5F(inCountInput) <= inCapacityOutput);
			always @(*) countReadyInner = sv2v_tmp_01427;
		end
	endgenerate
	assign inReadyOutput = (EXTERNAL_CREDIT ? inCreditInput : countReadyInner);
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin
			if (EXTERNAL_CREDIT)
				assert (inCreditInput == countReadyInner) else $fatal(1, "backward FIFO external credit identity");
			else
				assert (!inCreditInput) else $fatal(1, "backward FIFO default credit must be tied low");
		end
`endif
	assign pushInner = (inValidInput && inReadyOutput ? inCountInput : {PUSH_W {1'sb0}});
	genvar _gv_lane_1;
	function automatic signed [SEQ_W - 1:0] sv2v_cast_A6A5F_signed;
		input reg signed [SEQ_W - 1:0] inp;
		sv2v_cast_A6A5F_signed = inp;
	endfunction
	function automatic [SLOT_W - 1:0] sv2v_cast_7C1AF;
		input reg [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	generate
		for (_gv_lane_1 = 0; _gv_lane_1 < POP_WIDTH; _gv_lane_1 = _gv_lane_1 + 1) begin : g_read
			localparam lane = _gv_lane_1;
			assign outDataOutput[lane * WIDTH+:WIDTH] = (lane < sv2v_cast_32_signed(outCountOutput) ? entriesInner[sv2v_cast_7C1AF(headInner + sv2v_cast_A6A5F_signed(lane))] : {WIDTH * 1 {1'sb0}});
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
			emptyInner <= 1'b1;
		end
		else if (!freezeInput && flushInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
			emptyInner <= 1'b1;
		end
		else if (!freezeInput) begin
			headInner <= headInner + sv2v_cast_A6A5F(popInner);
			tailInner <= tailInner + sv2v_cast_A6A5F(pushInner);
			emptyInner <= (headInner + sv2v_cast_A6A5F(popInner)) == (tailInner + sv2v_cast_A6A5F(pushInner));
		end
	assign emptyOutput = emptyInner;
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	generate
		if (PUSH_WIDTH == 2) begin : g_banked_write
			wire [(2 * WIDTH) - 1:0] bankDataInner;
			wire [SLOT_W - 1:0] nextSlotInner;
			assign nextSlotInner = sv2v_cast_7C1AF(tailInner + sv2v_cast_A6A5F_signed(1));
			assign bankDataInner[0+:WIDTH] = (tailInner[0] ? inDataInput[WIDTH+:WIDTH] : inDataInput[0+:WIDTH]);
			assign bankDataInner[WIDTH+:WIDTH] = (tailInner[0] ? inDataInput[0+:WIDTH] : inDataInput[WIDTH+:WIDTH]);
			genvar _gv_row_1;
			for (_gv_row_1 = 0; _gv_row_1 < DEPTH; _gv_row_1 = _gv_row_1 + 1) begin : g_row
				localparam row = _gv_row_1;
				wire writeInner;
				assign writeInner = ((pushInner != 0) && (sv2v_cast_7C1AF(tailInner) == sv2v_cast_7C1AF_signed(row))) || ((pushInner == sv2v_cast_B0505_signed(2)) && (nextSlotInner == sv2v_cast_7C1AF_signed(row)));
				always_ff @(posedge clkInput)
					if (((rstNInput && !freezeInput) && !flushInput) && writeInner)
						entriesInner[row] <= bankDataInner[(row & 1) * WIDTH+:WIDTH];
			end
		end
		else if ((PUSH_WIDTH == 4) && (DEPTH >= 4)) begin : g_four_banked_write
			wire [7:0] bankLaneInner;
			wire [(4 * WIDTH) - 1:0] bankDataInner;
			wire [(4 * SLOT_W) - 1:0] bankSlotInner;
			wire [3:0] bankFireInner;
			genvar _gv_bank_1;
			for (_gv_bank_1 = 0; _gv_bank_1 < 4; _gv_bank_1 = _gv_bank_1 + 1) begin : g_bank
				localparam bank = _gv_bank_1;
				assign bankLaneInner[bank * 2+:2] = sv2v_cast_2_signed(bank) - tailInner[1:0];
				assign bankDataInner[bank * WIDTH+:WIDTH] = inDataInput[bankLaneInner[bank * 2+:2] * WIDTH+:WIDTH];
				assign bankSlotInner[bank * SLOT_W+:SLOT_W] = sv2v_cast_7C1AF(tailInner + sv2v_cast_A6A5F(bankLaneInner[bank * 2+:2]));
				assign bankFireInner[bank] = sv2v_cast_B0505(bankLaneInner[bank * 2+:2]) < pushInner;
			end
			genvar _gv_row_2;
			for (_gv_row_2 = 0; _gv_row_2 < DEPTH; _gv_row_2 = _gv_row_2 + 1) begin : g_row
				localparam row = _gv_row_2;
				wire writeInner;
				assign writeInner = bankFireInner[row & 3] && (bankSlotInner[(row & 3) * SLOT_W+:SLOT_W] == sv2v_cast_7C1AF_signed(row));
				always_ff @(posedge clkInput)
					if (((rstNInput && !freezeInput) && !flushInput) && writeInner)
						entriesInner[row] <= bankDataInner[(row & 3) * WIDTH+:WIDTH];
			end
		end
		else begin : g_generic_write
			always_ff @(posedge clkInput)
				if ((rstNInput && !freezeInput) && !flushInput) begin : sv2v_autoblock_1
					reg signed [31:0] lane;
					for (lane = 0; lane < PUSH_WIDTH; lane = lane + 1)
						if (lane < sv2v_cast_32_signed(pushInner))
							entriesInner[sv2v_cast_7C1AF(tailInner + sv2v_cast_A6A5F_signed(lane))] <= inDataInput[lane * WIDTH+:WIDTH];
				end
		end
	endgenerate
`ifndef SYNTHESIS
	initial begin
		assert ((DEPTH >= 2) && ((DEPTH & (DEPTH - 1)) == 0)) else $fatal(1, "prefix FIFO DEPTH must be a power of two >= 2");
		assert ((((PUSH_WIDTH >= 1) && (PUSH_WIDTH <= DEPTH)) && (POP_WIDTH >= 1)) && (POP_WIDTH <= DEPTH)) else $fatal(1, "prefix FIFO lane count exceeds capacity");
	end
	always @(posedge clkInput)
		if (rstNInput) begin
			assert (countOutput <= sv2v_cast_A6A5F(DEPTH)) else $fatal(1, "prefix FIFO overflow");
			if ((inValidInput && !flushInput) && !freezeInput)
				assert ((inCountInput != 0) && (inCountInput <= sv2v_cast_B0505(PUSH_WIDTH))) else $fatal(1, "invalid prefix FIFO input length");
		end
`endif
endmodule
module rv32_fetch_packet_fifo (
	clkInput,
	rstNInput,
	freezeInput,
	flushInput,
	inValidInput,
	inReadyOutput,
	inDataInput,
	outValidOutput,
	outReadyInput,
	outDataOutput,
	countOutput
);
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_FQ_ENTRIES = rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH);
	parameter [31:0] DEPTH = rv32_pkg_FQ_ENTRIES;
	localparam [31:0] SLOT_W = $clog2(DEPTH);
	localparam [31:0] COUNT_W = $clog2(DEPTH + 1);
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire flushInput;
	input wire inValidInput;
	output wire inReadyOutput;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(64 + (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0))) - 1:0] inDataInput;
	output wire outValidOutput;
	input wire outReadyInput;
	output reg [(96 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] outDataOutput;
	output wire [COUNT_W - 1:0] countOutput;
	reg [(64 + (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0))) - 1:0] entriesInner [0:DEPTH - 1];
	wire [(64 + (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0))) - 1:0] headPacketInner;
	reg [SLOT_W - 1:0] headInner;
	reg [SLOT_W - 1:0] tailInner;
	reg [COUNT_W - 1:0] packetsInner;
	reg [COUNT_W - 1:0] wordsInner;
	reg cursorInner;
	wire popWordInner;
	wire popPacketInner;
	wire pushInner;
	wire [COUNT_W:0] wordsAfterPopInner;
	wire [COUNT_W:0] inWordsInner;
	wire [31:0] headSecondPcInner;
	assign headPacketInner = (packetsInner == {COUNT_W {1'sb0}} ? {64 + (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) {1'sb0}} : entriesInner[headInner]);
	assign headSecondPcInner = headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] | 32'd4;
	assign outValidOutput = (packetsInner != {COUNT_W {1'sb0}}) && !flushInput;
	assign popWordInner = outValidOutput && outReadyInput;
	assign popPacketInner = popWordInner && (!headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) : 0)] || cursorInner);
	function automatic [((COUNT_W + 0) >= 0 ? COUNT_W + 1 : 1 - (COUNT_W + 0)) - 1:0] sv2v_cast_AE0F9;
		input reg [((COUNT_W + 0) >= 0 ? COUNT_W + 1 : 1 - (COUNT_W + 0)) - 1:0] inp;
		sv2v_cast_AE0F9 = inp;
	endfunction
	assign wordsAfterPopInner = {1'b0, wordsInner} - sv2v_cast_AE0F9(popWordInner);
	function automatic signed [((COUNT_W + 0) >= 0 ? COUNT_W + 1 : 1 - (COUNT_W + 0)) - 1:0] sv2v_cast_AE0F9_signed;
		input reg signed [((COUNT_W + 0) >= 0 ? COUNT_W + 1 : 1 - (COUNT_W + 0)) - 1:0] inp;
		sv2v_cast_AE0F9_signed = inp;
	endfunction
	assign inWordsInner = sv2v_cast_AE0F9_signed(1) + sv2v_cast_AE0F9(inDataInput[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) : 0)]);
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	assign inReadyOutput = (!flushInput && ((packetsInner < sv2v_cast_D4579(DEPTH)) || popPacketInner)) && ((wordsAfterPopInner + inWordsInner) <= sv2v_cast_AE0F9(DEPTH));
	assign pushInner = inValidInput && inReadyOutput;
	assign countOutput = wordsInner;
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
	always @* begin
		outDataOutput = 1'sb0;
		if (packetsInner != {COUNT_W {1'sb0}}) begin
			outDataOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] = (cursorInner ? headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 63:(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 32] : headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 31:(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 0]);
			outDataOutput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] = (cursorInner ? headSecondPcInner : headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)]);
			outDataOutput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = (!cursorInner && headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) : 0)] ? headSecondPcInner : headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)]);
			outDataOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0)) : (((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 0)) - 1)-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))] + sv2v_cast_C1E44(cursorInner);
		end
	end
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
			packetsInner <= 1'sb0;
			wordsInner <= 1'sb0;
			cursorInner <= 0;
		end
		else if (!freezeInput && flushInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
			packetsInner <= 1'sb0;
			wordsInner <= 1'sb0;
			cursorInner <= 0;
		end
		else if (!freezeInput) begin
			if (popPacketInner) begin
				headInner <= headInner + sv2v_cast_7C1AF_signed(1);
				cursorInner <= 0;
			end
			else if (popWordInner)
				cursorInner <= 1;
			if (pushInner) begin
				entriesInner[tailInner] <= inDataInput;
				tailInner <= tailInner + sv2v_cast_7C1AF_signed(1);
			end
			packetsInner <= (packetsInner + sv2v_cast_D4579(pushInner)) - sv2v_cast_D4579(popPacketInner);
			wordsInner <= (wordsInner + sv2v_cast_D4579((pushInner ? inWordsInner : {(COUNT_W >= 0 ? COUNT_W + 1 : 1 - COUNT_W) {1'sb0}}))) - sv2v_cast_D4579(popWordInner);
		end
`ifndef SYNTHESIS
	initial assert ((DEPTH >= 2) && ((DEPTH & (DEPTH - 1)) == 0)) ;
	always @(posedge clkInput)
		if (rstNInput) begin
			assert ((wordsInner <= sv2v_cast_D4579(DEPTH)) && (packetsInner <= wordsInner)) ;
			assert (!cursorInner || headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) : 0)]) ;
			if ((packetsInner != {COUNT_W {1'sb0}}) && headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) : 0)])
				assert (headPacketInner[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - 29)) : 0 + (29 - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)))):(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - 31)) : 0 + (31 - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))))] == 0) ;
			if (pushInner)
				assert (!inDataInput[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) : 0)] || (inDataInput[(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - 29)) : 0 + (29 - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)))):(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? ((((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1) - (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) - ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - 31)) : 0 + (31 - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))))] == 0)) ;
		end
`endif
endmodule
module rv32_core (
	clkInput,
	rstNInput,
	imemReqValidOutput,
	imemReqReadyInput,
	imemReqAddrOutput,
	imemRspValidInput,
	imemRspDataInput,
	imemRspSecondDataInput,
	imemFetchHintInput,
	imemSecondRequestOutput,
	imemRspReadyOutput,
	imemFlushOutput,
	imemCacheRequestOutput,
	dmemReqValidOutput,
	dmemReqReadyInput,
	dmemReqWriteOutput,
	dmemStoreSetPreviewOutput,
	dmemReqAddrOutput,
	dmemReqWdataOutput,
	dmemReqWstrbOutput,
	dmemReqSizeOutput,
	dmemRspValidInput,
	dmemRspRdataInput,
	dmemReqTransactionOutput,
	dmemRspTransactionInput,
	responsePreviewTransactionInput,
	responsePreviewSelectInput,
	commitValidOutput,
	commitPcOutput,
	commitInstrOutput,
	commitRdValidOutput,
	commitRdOutput,
	commitRdValueOutput,
	commitMemValidOutput,
	commitMemAddrOutput,
	commitMemDataOutput,
	commitMemWstrbOutput,
	retirementOutput,
	haltedOutput,
	trapOutput,
	imemRspPacketDataInput,
	imemFetchCountOutput
);
	parameter [31:0] RESET_PC = 32'b00000000000000000000000000000000;
	parameter [0:0] TAGGED_DMEM = 1'b0;
	parameter [0:0] LEGACY_HALT = 1'b0;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	parameter [31:0] FETCH_WIDTH = rv32_pkg_FETCH_WIDTH;
	localparam [31:0] rv32_pkg_COMMIT_WIDTH = 4;
	parameter [31:0] COMMIT_WIDTH = rv32_pkg_COMMIT_WIDTH;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	parameter [31:0] DECODE_WIDTH = rv32_pkg_DECODE_WIDTH;
	localparam [31:0] rv32_pkg_RENAME_WIDTH = 4;
	parameter [31:0] RENAME_WIDTH = rv32_pkg_RENAME_WIDTH;
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	parameter [31:0] FQ_DEPTH = rv32_pkg_default_fq_entries(DECODE_WIDTH);
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	parameter [31:0] IQ_DEPTH = rv32_pkg_default_iq_entries(DECODE_WIDTH);
	parameter [31:0] ISSUE_WIDTH = RENAME_WIDTH;
	input wire clkInput;
	input wire rstNInput;
	output wire imemReqValidOutput;
	input wire imemReqReadyInput;
	output wire [31:0] imemReqAddrOutput;
	input wire imemRspValidInput;
	input wire [31:0] imemRspDataInput;
	input wire [31:0] imemRspSecondDataInput;
	input wire [4:0] imemFetchHintInput;
	output wire imemSecondRequestOutput;
	output wire imemRspReadyOutput;
	output wire imemFlushOutput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	output wire [(65 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] imemCacheRequestOutput;
	output wire dmemReqValidOutput;
	input wire dmemReqReadyInput;
	output wire dmemReqWriteOutput;
	localparam [31:0] rv32_pkg_DCACHE_SETS = 128;
	output wire [6:0] dmemStoreSetPreviewOutput;
	output wire [31:0] dmemReqAddrOutput;
	output wire [31:0] dmemReqWdataOutput;
	output wire [3:0] dmemReqWstrbOutput;
	output wire [1:0] dmemReqSizeOutput;
	input wire dmemRspValidInput;
	input wire [31:0] dmemRspRdataInput;
	localparam [31:0] rv32_pkg_DATA_REQUEST_ENTRIES = 8;
	localparam signed [31:0] rv32_pkg_DATA_TRANSACTION_W = 3;
	output wire [2:0] dmemReqTransactionOutput;
	input wire [2:0] dmemRspTransactionInput;
	input wire [5:0] responsePreviewTransactionInput;
	input wire [1:0] responsePreviewSelectInput;
	output reg commitValidOutput;
	output reg [31:0] commitPcOutput;
	output reg [31:0] commitInstrOutput;
	output reg commitRdValidOutput;
	output reg [4:0] commitRdOutput;
	output reg [31:0] commitRdValueOutput;
	output reg commitMemValidOutput;
	output reg [31:0] commitMemAddrOutput;
	output reg [31:0] commitMemDataOutput;
	output reg [3:0] commitMemWstrbOutput;
	output wire [(COMMIT_WIDTH * 172) - 1:0] retirementOutput;
	output reg haltedOutput;
	output reg trapOutput;
	input wire [127:0] imemRspPacketDataInput;
	output wire [2:0] imemFetchCountOutput;
	localparam [31:0] rv32_pkg_ALU_UNITS = 2;
	localparam [31:0] ALU_LANES = rv32_pkg_ALU_UNITS;
	localparam [31:0] rv32_pkg_ALU_CDB_PORTS = 2;
	localparam [31:0] ROB_LOOKUP_PORTS = 6;
	wire [$clog2(FQ_DEPTH + 1) - 1:0] unusedFqCountInner;
	wire [$clog2(IQ_DEPTH + 1) - 1:0] unusedIqCountInner;
	localparam [31:0] rv32_pkg_INT_RS_ENTRIES = 4;
	wire [2:0] unusedIntOccupancyInner;
	localparam [31:0] rv32_pkg_MUL_RS_ENTRIES = 1;
	wire [0:0] unusedMulOccupancyInner;
	localparam [31:0] rv32_pkg_DIV_RS_ENTRIES = 1;
	wire [0:0] unusedDivOccupancyInner;
	localparam [31:0] rv32_pkg_BRANCH_RS_ENTRIES = 4;
	wire [2:0] unusedBranchOccupancyInner;
	localparam [31:0] rv32_pkg_LOAD_RS_ENTRIES = 2;
	wire [1:0] unusedLoadOccupancyInner;
	localparam [31:0] rv32_pkg_STORE_ADDR_RS_ENTRIES = 2;
	wire [1:0] unusedSaOccupancyInner;
	localparam [31:0] rv32_pkg_STORE_VALUE_RS_ENTRIES = 2;
	wire [1:0] unusedSvOccupancyInner;
	wire [0:0] unusedMulIssueLaneValidInner;
	wire [0:0] unusedDivIssueLaneValidInner;
	wire [0:0] unusedBranchIssueLaneValidInner;
	wire [0:0] unusedLoadIssueLaneValidInner;
	wire [0:0] unusedSaIssueLaneValidInner;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	wire [178:0] unusedMulIssueLaneInner;
	wire [178:0] unusedDivIssueLaneInner;
	wire [178:0] unusedBranchIssueLaneInner;
	wire [178:0] unusedLoadIssueLaneInner;
	wire [178:0] unusedSaIssueLaneInner;
	wire [0:0] unusedMulIssueLaneAuxInner;
	wire [0:0] unusedDivIssueLaneAuxInner;
	wire [2:0] unusedBranchIssueLaneAuxInner;
	localparam [31:0] rv32_pkg_LQ_ENTRIES = 4;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	localparam [31:0] rv32_pkg_SQ_SLOT_W = 2;
	localparam [31:0] rv32_pkg_LSQ_SLOT_W = rv32_pkg_SQ_SLOT_W;
	wire [2:0] unusedLoadIssueLaneAuxInner;
	wire [2:0] unusedSaIssueLaneAuxInner;
	wire [4:0] unusedAguRobTagInner;
	wire [2:0] unusedLqCountInner;
	generate
		if (ISSUE_WIDTH != 4) begin : g_invalid_alu_cdb_count
			initial $fatal(1, "two independent ALU CDBs require two ALUs and the array backend");
		end
	endgenerate
	rv32_issue_config #(.ISSUE_WIDTH(ISSUE_WIDTH)) u_issue_config();
	wire [31:0] predictorPcInner;
	wire [rv32_pkg_BPU_CKPT_ID_W - 1:0] iqPredictorCkptIdInner;
	wire predictorFetchAcceptInner;
	wire predictorFetchPredictInner;
	wire frontendSecondRequestInner;
	wire [2:0] frontendFetchCountInner;
	wire [32:0] predictorQueryOutputInner;
	wire [(65 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] frontendImemRequestOutputInner;
	wire [32:0] frontendImemResponseInputInner;
	wire [32:0] frontendRedirectInputInner;
	wire [(97 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] frontendInstructionOutputInner;
	wire [67:0] fetchInfoOutputInner;
	wire frontendIqValidInner;
	reg frontendIqReadyInner;
	wire [31:0] iqPcInner;
	wire [31:0] iqInstrInner;
	wire [31:0] iqPredictedPcInner;
	wire [(96 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] decodeContextInner;
	wire [67:0] predictorFetchInfoInner;
	wire [(72 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] predictorBranchInputInner;
	wire [71:0] predictorJumpInputInner;
	wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] branchFlushInputInner;
	wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] jumpFlushInputInner;
	wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] predictorSquashInputInner;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	reg [(COMMIT_WIDTH * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) - 1:0] predictorRobInputInner;
	wire [(33 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] predictorOutputInner;
	wire [(160 + rv32_pkg_BPU_CKPT_ID_W) + 2:0] decodedInner;
	wire [(160 + rv32_pkg_BPU_CKPT_ID_W) + 2:0] frontendDecodedInner;
	wire [(97 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] frontendSecondInstructionInner;
	wire [(160 + rv32_pkg_BPU_CKPT_ID_W) + 2:0] decodedSecondInner;
	wire issueSecondFireInner;
	wire issueSecondResourcesReadyInner;
	reg targetSecondRsReadyInner;
	wire issueSecondIsJumpInner;
	wire issueSecondIsReturnInner;
	wire issueSecondSrc1ReadyInner;
	wire issueSecondSrc2ReadyInner;
	wire [31:0] issueSecondSrc1ValueInner;
	wire [31:0] issueSecondSrc2ValueInner;
	wire [31:0] issueSecondLinkValueInner;
	wire [5:0] issueSecondSrc1PhyInner;
	wire [5:0] issueSecondSrc2PhyInner;
	wire [5:0] issueSecondDestPhyInner;
	wire [9:0] ratReadSecondInputInner;
	wire [(rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W) - 1:0] ratReadSecondOutputInner;
	wire [11:0] ratRenameSecondInputInner;
	wire [5:0] ratRenameSecondOutputInner;
	wire [33:0] prfAllocSecondInputInner;
	wire [5:0] prfAllocSecondPhyInner;
	wire [5:0] ratSecondOldPhyInner;
	wire prfAllocSecondReadyInner;
	wire robAllocSecondReadyInner;
	wire [4:0] robAllocSecondTagInner;
	wire [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] robAllocSecondInputInner;
	reg [192:0] rsAllocSecondBaseInner;
	reg [192:0] intRsAllocSecondInputInner;
	reg [192:0] mulRsAllocSecondInputInner;
	reg [192:0] divRsAllocSecondInputInner;
	reg [192:0] branchRsAllocSecondInputInner;
	reg [192:0] loadRsAllocSecondInputInner;
	reg [192:0] saRsAllocSecondInputInner;
	reg [192:0] svRsAllocSecondInputInner;
	wire intAllocSecondReadyInner;
	wire mulAllocSecondReadyInner;
	wire divAllocSecondReadyInner;
	wire branchAllocSecondReadyInner;
	wire loadRsAllocSecondReadyInner;
	wire saRsAllocSecondReadyInner;
	wire svRsAllocSecondReadyInner;
	wire [14:0] lsuLoadAllocationSecondInputInner;
	wire [46:0] lsuStoreAllocationSecondInputInner;
	wire lqAllocSecondReadyInner;
	wire sqAllocSecondReadyInner;
	wire [1:0] lqAllocSecondIndexInner;
	wire [1:0] sqAllocSecondIndexInner;
	wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (4 * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (4 * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] wideDecodedInner;
	wire [3:0] wideValidInner;
	wire [3:0] wideFireInner;
	wire [2:0] wideIssueCountInner;
	wire [5403:0] wideRsAllocInner;
	wire [83:0] wideRsAuxInner;
	wire [27:0] wideRsFireInner;
	wire [34:0] wideRsCreditsInner;
	wire [2:0] wideIntCreditsInner;
	wire [0:0] wideMulCreditsInner;
	wire [0:0] wideDivCreditsInner;
	wire [2:0] wideBranchCreditsInner;
	wire [34:0] unusedCreditFitsInner;
	wire [1:0] wideLoadRsCreditsInner;
	wire [1:0] wideSaCreditsInner;
	wire [1:0] wideSvCreditsInner;
	wire [3:0] wideIntAuxInner;
	wire [3:0] wideMulAuxInner;
	wire [3:0] wideDivAuxInner;
	wire [11:0] wideBranchAuxInner;
	wire [7:0] wideSvAuxInner;
	wire [11:0] wideLoadAuxInner;
	wire [11:0] wideSaAuxInner;
	wire [59:0] wideLoadAllocInner;
	wire [187:0] wideStoreAllocInner;
	wire [3:0] wideLoadFireInner;
	wire [3:0] wideStoreFireInner;
	wire [7:0] wideLoadPreviewInner;
	wire [7:0] wideStorePreviewInner;
	wire [2:0] wideLoadCreditsInner;
	wire [2:0] wideStoreCreditsInner;
	function automatic [4:0] sv2v_cast_71679;
		input reg [4:0] inp;
		sv2v_cast_71679 = inp;
	endfunction
	assign wideRsCreditsInner[0+:5] = sv2v_cast_71679(wideIntCreditsInner);
	assign wideRsCreditsInner[5+:5] = sv2v_cast_71679(wideMulCreditsInner);
	assign wideRsCreditsInner[10+:5] = sv2v_cast_71679(wideDivCreditsInner);
	assign wideRsCreditsInner[15+:5] = sv2v_cast_71679(wideBranchCreditsInner);
	assign wideRsCreditsInner[20+:5] = sv2v_cast_71679(wideLoadRsCreditsInner);
	assign wideRsCreditsInner[25+:5] = sv2v_cast_71679(wideSaCreditsInner);
	assign wideRsCreditsInner[30+:5] = sv2v_cast_71679(wideSvCreditsInner);
	genvar _gv_lane_2;
	generate
		for (_gv_lane_2 = 0; _gv_lane_2 < 4; _gv_lane_2 = _gv_lane_2 + 1) begin : g_wide_aux_wires
			localparam lane = _gv_lane_2;
			assign wideIntAuxInner[lane] = wideRsAuxInner[((0 + lane) * 3) + 0];
			assign wideMulAuxInner[lane] = wideRsAuxInner[((4 + lane) * 3) + 0];
			assign wideDivAuxInner[lane] = wideRsAuxInner[((8 + lane) * 3) + 0];
			assign wideBranchAuxInner[lane * 3+:3] = wideRsAuxInner[((12 + lane) * 3) + 2-:3];
			assign wideLoadAuxInner[0 + (lane * 3)+:3] = wideRsAuxInner[((16 + lane) * 3) + rv32_pkg_LSQ_SLOT_W-:3];
			assign wideSaAuxInner[0 + (lane * 3)+:3] = wideRsAuxInner[((20 + lane) * 3) + rv32_pkg_LSQ_SLOT_W-:3];
			assign wideSvAuxInner[lane * rv32_pkg_SQ_SLOT_W+:rv32_pkg_SQ_SLOT_W] = wideRsAuxInner[((24 + lane) * 3) + 1-:rv32_pkg_SQ_SLOT_W];
		end
	endgenerate
	wire [5:0] ratRs1PhyInner;
	wire [5:0] ratRs2PhyInner;
	wire [5:0] ratOldPhyInner;
	wire [9:0] ratReadInputInner;
	wire [(rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W) - 1:0] ratReadOutputInner;
	wire [11:0] ratRenameInputInner;
	wire [5:0] ratRenameOutputInner;
	wire [10:0] ratRestoreInputInner;
	wire [(COMMIT_WIDTH * 12) - 1:0] ratCommitInputInner;
	wire [(COMMIT_WIDTH * 7) - 1:0] retirementFreeInner;
	wire [(COMMIT_WIDTH * 6) - 1:0] retirementInputInner;
	wire [(COMMIT_WIDTH * 6) - 1:0] retirementStoreInputInner;
	wire [(COMMIT_WIDTH * 72) - 1:0] retirementMemoryInner;
	wire [COMMIT_WIDTH - 1:0] retirementExitInner;
	wire [(COMMIT_WIDTH * rv32_pkg_SQ_SLOT_W) - 1:0] retirementSqIndexInner;
	wire [COMMIT_WIDTH - 1:0] retirementReadyInner;
	wire [COMMIT_WIDTH - 1:0] retirementFireInner;
	wire [COMMIT_WIDTH - 1:0] retirementStoreInner;
	wire [COMMIT_WIDTH - 1:0] retirementStoreReadyInner;
	wire [5:0] prfAllocPhyInner;
	wire prfAllocReadyInner;
	wire prfSrc1ReadyInner;
	wire prfSrc2ReadyInner;
	wire prfCommitReadyInner;
	wire [31:0] prfSrc1ValueInner;
	wire [31:0] prfSrc2ValueInner;
	wire [31:0] prfCommitValueInner;
	wire [47:0] prfReadyVectorInner;
	localparam [31:0] rv32_pkg_WRITEBACK_PORTS = 4;
	wire [155:0] writebackInputInner;
	reg [155:0] branchIssueWritebackInner;
	localparam [31:0] rv32_pkg_LOAD_CDB_PORT = 3;
	always @* begin
		branchIssueWritebackInner = writebackInputInner;
		branchIssueWritebackInner[155] = 1'b0;
	end
	wire [3:0] writebackValidInner;
	genvar _gv_portIndex_1;
	generate
		for (_gv_portIndex_1 = 0; _gv_portIndex_1 < rv32_pkg_WRITEBACK_PORTS; _gv_portIndex_1 = _gv_portIndex_1 + 1) begin : g_wb_valid
			localparam portIndex = _gv_portIndex_1;
			assign writebackValidInner[portIndex] = writebackInputInner[(portIndex * 39) + 38];
		end
	endgenerate
	wire [77:0] sharedCdbCandidatesInner;
	wire [9:0] sharedCdbTagsInner;
	wire [4:0] sharedCdbTagInner;
	wire [1:0] sharedCdbGrantInner;
	wire loadResultEligibleInner;
	wire mulResultEligibleInner;
	wire divResultEligibleInner;
	wire [31:0] loadIdentityInner;
	wire loadWinnerIdentityInner;
	wire [((COMMIT_WIDTH + 3) >= 0 ? ((COMMIT_WIDTH + 4) * rv32_pkg_PHY_TAG_W) - 1 : ((1 - (COMMIT_WIDTH + 3)) * rv32_pkg_PHY_TAG_W) + (((COMMIT_WIDTH + 3) * rv32_pkg_PHY_TAG_W) - 1)):((COMMIT_WIDTH + 3) >= 0 ? 0 : (COMMIT_WIDTH + 3) * rv32_pkg_PHY_TAG_W)] prfReadInputInner;
	wire [((COMMIT_WIDTH + 3) >= 0 ? ((COMMIT_WIDTH + 4) * 33) - 1 : ((1 - (COMMIT_WIDTH + 3)) * 33) + (((COMMIT_WIDTH + 3) * 33) - 1)):((COMMIT_WIDTH + 3) >= 0 ? 0 : (COMMIT_WIDTH + 3) * 33)] prfReadOutputInner;
	wire [4:0] robAllocTagInner;
	wire [4:0] robHeadTagInner;
	wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] robReplayNarrowInner;
	wire [(rv32_pkg_RECOVERY_WIDTH * 39) - 1:0] robReplayRasInner;
	wire [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] robAllocInputInner;
	wire [41:0] robCompletionInputInner;
	wire [(ROB_LOOKUP_PORTS * rv32_pkg_ROB_TAG_W) - 1:0] robLookupInputInner;
	wire [(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (ROB_LOOKUP_PORTS * ((65 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (ROB_LOOKUP_PORTS * (1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((65 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] robLookupOutputInner;
	wire [(65 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] loadLookupSeparateInner;
	wire [(65 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] jumpLookupInner;
	wire [(COMMIT_WIDTH * 93) - 1:0] robCommitOutputInner;
	wire [6:0] robStatusOutputInner;
	wire robAllocReadyInner;
	wire robCommitValidInner;
	reg robCommitReadyInner;
	wire robCommitFireInner;
	wire robCommitFireOutputInner;
	wire [4:0] robCommitTagInner;
	wire [31:0] robCommitPcInner;
	wire [31:0] robCommitInstrInner;
	wire robCommitWritesInner;
	wire [4:0] robCommitRdInner;
	wire [5:0] robCommitNewPhyInner;
	wire [5:0] robCommitOldPhyInner;
	wire robCommitStoreInner;
	wire robCommitIsCallInner;
	wire robCommitIsRetInner;
	wire [1:0] robCommitSqIndexInner;
	wire robCommitHaltInner;
	wire robEmptyInner;
	wire robFullInner;
	wire [4:0] robCountInner;
	reg issueFireInner;
	reg issueResourcesReadyInner;
	reg targetRsReadyInner;
	reg issueIsJumpInner;
	reg issueIsCallInner;
	reg issueIsReturnInner;
	reg issueSrc1ReadyInner;
	reg issueSrc2ReadyInner;
	reg [31:0] issueSrc1ValueInner;
	reg [31:0] issueSrc2ValueInner;
	reg [5:0] issueDestPhyInner;
	wire globalFlushInner;
	wire [4:0] globalFlushTagInner;
	wire [31:0] globalRedirectPcInner;
	wire [rv32_pkg_BPU_CKPT_ID_W - 1:0] globalFlushCkptIdInner;
	wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] flushOutputInner;
	wire [22:0] recoveryStepInner;
	wire recoveryBusyInner;
	wire pipelineFrozenInner;
	wire frontendFrozenInner;
	wire frontendWholeGroupInner;
	wire branchFlushCandidateInner;
	wire jumpFlushCandidateInner;
	wire [31:0] branchFlushPcInner;
	wire [31:0] jumpFlushPcInner;
	wire predictorUpdateValidInner;
	wire predictorMispredictInner;
	wire wbAluValidInner;
	wire wbLoadValidInner;
	wire wbMulValidInner;
	wire wbDivValidInner;
	wire [45:0] aluExecuteOutputInner;
	wire [45:0] aluLaneResultInner [0:1];
	reg [181:0] aluLaneRequestInner [0:1];
	wire [357:0] intIssueLaneInner;
	wire [1:0] intIssueLaneAuxInner;
	wire [1:0] intIssueLaneValidInner;
	reg [1:0] intIssueLaneReadyInner;
	wire [1:0] aluInputReadyInner;
	wire [1:0] aluResultGrantInner;
	wire [1:0] aluPopReadyInner;
	wire [1:0] aluIssueFireInner;
	wire aluSecondWinsInner;
	wire [43:0] mulExecuteOutputInner;
	wire [139:0] bruExecuteOutputInner;
	wire [43:0] divExecuteOutputInner;
	wire loadCdbValidInner;
	wire mulCdbValidInner;
	wire divCdbValidInner;
	wire aluRobLiveInner;
	wire loadRobLiveInner;
	wire mulRobLiveInner;
	wire divRobLiveInner;
	wire aluResultLiveInner;
	wire branchResultLiveInner;
	wire [4:0] wbAluTagInner;
	wire [4:0] wbLoadTagInner;
	wire [4:0] wbMulTagInner;
	wire [4:0] wbDivTagInner;
	wire [5:0] wbAluPhyInner;
	wire [5:0] wbLoadPhyInner;
	wire [5:0] wbMulPhyInner;
	wire [5:0] wbDivPhyInner;
	wire [31:0] wbAluValueInner;
	wire [31:0] wbLoadValueInner;
	wire [31:0] wbMulValueInner;
	wire [31:0] wbDivValueInner;
	wire aluCdbValidInner;
	wire aluCdbIsControlInner;
	wire intAllocReadyInner;
	wire intIssueValidInner;
	wire intIssueReadyInner;
	wire [5:0] intIssueOpInner;
	wire [4:0] intIssueTagInner;
	wire [5:0] intIssuePhyInner;
	wire [31:0] intIssueS1Inner;
	wire [31:0] intIssueS2Inner;
	wire [31:0] intIssueImmInner;
	wire [31:0] intIssuePcInner;
	wire [31:0] intIssuePredInner;
	wire intIssueUseImmInner;
	wire [0:0] intIssueAuxInner;
	reg [192:0] rsAllocBaseInner;
	reg [192:0] intRsAllocInputInner;
	reg [192:0] mulRsAllocInputInner;
	reg [192:0] divRsAllocInputInner;
	reg [192:0] branchRsAllocInputInner;
	reg [192:0] memRsAllocInputInner;
	wire [178:0] intRsIssueOutputInner;
	wire [178:0] mulRsIssueOutputInner;
	wire [178:0] divRsIssueOutputInner;
	wire [178:0] branchRsIssueOutputInner;
	wire [178:0] memRsIssueOutputInner;
	wire mulAllocReadyInner;
	wire mulIssueValidInner;
	wire mulIssueReadyInner;
	wire [5:0] mulIssueOpInner;
	wire [4:0] mulIssueTagInner;
	wire [5:0] mulIssuePhyInner;
	wire [31:0] mulIssueS1Inner;
	wire [31:0] mulIssueS2Inner;
	wire [31:0] mulIssueImmInner;
	wire [31:0] mulIssuePcInner;
	wire [31:0] mulIssuePredInner;
	wire mulIssueUseImmInner;
	wire [0:0] mulIssueAuxInner;
	wire divAllocReadyInner;
	wire divIssueValidInner;
	wire divIssueReadyInner;
	wire [5:0] divIssueOpInner;
	wire [4:0] divIssueTagInner;
	wire [5:0] divIssuePhyInner;
	wire [31:0] divIssueS1Inner;
	wire [31:0] divIssueS2Inner;
	wire [31:0] divIssueImmInner;
	wire [31:0] divIssuePcInner;
	wire [31:0] divIssuePredInner;
	wire divIssueUseImmInner;
	wire [0:0] divIssueAuxInner;
	wire branchAllocReadyInner;
	wire branchIssueValidInner;
	wire branchIssueReadyInner;
	wire [5:0] branchIssueOpInner;
	wire [4:0] branchIssueTagInner;
	wire [5:0] branchIssuePhyInner;
	wire [31:0] branchIssueS1Inner;
	wire [31:0] branchIssueS2Inner;
	wire [31:0] branchIssueImmInner;
	wire [31:0] branchIssuePcInner;
	wire [31:0] branchIssuePredInner;
	wire branchIssueUseImmInner;
	wire [2:0] branchIssueAuxInner;
	wire memIssueReadyInner;
	wire [rv32_pkg_LSQ_SLOT_W:0] memIssueAuxInner;
	reg [192:0] loadRsAllocInputInner;
	reg [192:0] saRsAllocInputInner;
	reg [192:0] svRsAllocInputInner;
	wire [178:0] loadRsIssueOutputInner;
	wire [178:0] saRsIssueOutputInner;
	wire [178:0] svRsIssueOutputInner;
	wire loadRsAllocReadyInner;
	wire saRsAllocReadyInner;
	wire svRsAllocReadyInner;
	wire [1:0] svRsIssueLaneValidInner;
	wire [357:0] svRsIssueLaneInner;
	wire [(rv32_pkg_STORE_VALUE_RS_ENTRIES * rv32_pkg_SQ_SLOT_W) - 1:0] svRsIssueLaneAuxInner;
	reg [75:0] svRsStoreDataInner;
	reg [(rv32_pkg_STORE_VALUE_RS_ENTRIES * rv32_pkg_SQ_SLOT_W) - 1:0] svRsStoreDataIndexInner;
	wire chooseLoadInner;
	wire loadRsIssueReadyInner;
	wire saRsIssueReadyInner;
	wire [rv32_pkg_LSQ_SLOT_W:0] loadAuxInner;
	wire [rv32_pkg_LSQ_SLOT_W:0] saAuxInner;
	wire [1:0] svAuxInner;
	wire [rv32_pkg_LSQ_SLOT_W:0] aguResultAuxInner;
	wire bruValidInner;
	wire bruTakenInner;
	wire bruConditionalInner;
	wire bruMispredictInner;
	wire [4:0] bruTagInner;
	wire [31:0] bruPcInner;
	wire [31:0] bruNextPcInner;
	wire bruRobLiveInner;
	wire jumpRobLiveInner;
	wire [31:0] bruRobPcInner;
	wire [31:0] bruRobPredictedPcInner;
	wire [31:0] jumpRobPcInner;
	wire [31:0] jumpRobPredictedPcInner;
	wire [rv32_pkg_BPU_CKPT_ID_W - 1:0] bruRobCkptIdInner;
	wire [rv32_pkg_BPU_CKPT_ID_W - 1:0] jumpRobCkptIdInner;
	wire bruRobIsRetInner;
	wire jumpRobIsRetInner;
	wire lqAllocReadyInner;
	wire sqAllocReadyInner;
	wire [1:0] lqAllocIndexInner;
	wire [1:0] sqAllocIndexInner;
	wire lsuStoreCommitReadyInner;
	wire [14:0] lsuLoadAllocationInputInner;
	wire [46:0] lsuStoreAllocationInputInner;
	reg [38:0] lsuAddressInputInner;
	wire [38:0] aguAddressOutputInner;
	wire [5:0] lsuStoreCommitInputInner;
	wire [43:0] lsuLoadResultOutputInner;
	wire [(rv32_pkg_ROB_ENTRIES + rv32_pkg_ROB_ENTRIES) - 1:0] lsuStoreCompleteOutputInner;
	wire [71:0] lsuDmemRequestOutputInner;
	wire [71:0] lsuStoreRetirementOutputInner;
	wire [32:0] lsuDmemResponseInputInner;
	wire [2:0] sqCountInner;
	reg haltedInner;
	reg bootDoneInner;
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			bootDoneInner <= 1'b0;
		else
			bootDoneInner <= 1'b1;
	wire [31:0] issueLinkValueInner;
	wire unusedCoutLinkInner;
	integer robInputIndexInner;
	integer storeLaneInner;
	assign aluRobLiveInner = jumpRobLiveInner;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	assign aluResultLiveInner = ((!pipelineFrozenInner && aluCdbValidInner) && aluRobLiveInner) && (!globalFlushInner || rv32_pkg_rob_is_older(wbAluTagInner, globalFlushTagInner));
	assign wbAluValidInner = aluResultLiveInner && !aluCdbIsControlInner;
	generate
		if (1) begin : g_independent_alu_results
			wire [1:0] live;
			assign aluSecondWinsInner = (aluLaneResultInner[1][45] && aluLaneResultInner[1][1]) && (!(aluLaneResultInner[0][45] && aluLaneResultInner[0][1]) || rv32_pkg_rob_is_older(aluLaneResultInner[1][12-:5], aluLaneResultInner[0][12-:5]));
			assign aluExecuteOutputInner = (aluSecondWinsInner ? aluLaneResultInner[1] : aluLaneResultInner[0]);
			assign jumpLookupInner = (aluSecondWinsInner ? robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (5 * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))] : robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))]);
			assign live[0] = ((!pipelineFrozenInner && aluLaneResultInner[0][45]) && robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))]) && (!globalFlushInner || rv32_pkg_rob_is_older(aluLaneResultInner[0][12-:5], globalFlushTagInner));
			assign live[1] = ((!pipelineFrozenInner && aluLaneResultInner[1][45]) && robLookupOutputInner[(5 * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))]) && (!globalFlushInner || rv32_pkg_rob_is_older(aluLaneResultInner[1][12-:5], globalFlushTagInner));
			assign aluResultGrantInner[0] = live[0] && (!aluLaneResultInner[0][1] || !aluSecondWinsInner);
			assign aluResultGrantInner[1] = live[1] && (!aluLaneResultInner[1][1] || aluSecondWinsInner);
			assign aluPopReadyInner[0] = !pipelineFrozenInner && (aluResultGrantInner[0] || (aluLaneResultInner[0][45] && !robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))]));
			assign aluPopReadyInner[1] = !pipelineFrozenInner && (aluResultGrantInner[1] || (aluLaneResultInner[1][45] && !robLookupOutputInner[(5 * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))]));
		end
		if ((ISSUE_WIDTH == 4) && TAGGED_DMEM) begin : g_early_load_identity
`ifndef SYNTHESIS
			reg faultIdentity;
			initial faultIdentity = $test$plusargs("BAD_REGISTERED_IDENTITY");
			always @(posedge clkInput)
				if (rstNInput)
					assert (loadResultEligibleInner == (((!recoveryBusyInner && loadCdbValidInner) && loadRobLiveInner) && (!globalFlushInner || rv32_pkg_rob_is_older(wbLoadTagInner, globalFlushTagInner)))) else $fatal(1, "actual Load grant disagrees with exact late identity");
			assign loadResultEligibleInner = (!recoveryBusyInner && loadCdbValidInner) && (loadWinnerIdentityInner ^ faultIdentity);
`else
			assign loadResultEligibleInner = (!recoveryBusyInner && loadCdbValidInner) && loadWinnerIdentityInner;
`endif
		end
		else begin : g_late_load_identity
			assign loadResultEligibleInner = ((!recoveryBusyInner && loadCdbValidInner) && loadRobLiveInner) && (!globalFlushInner || rv32_pkg_rob_is_older(wbLoadTagInner, globalFlushTagInner));
		end
	endgenerate
	assign mulResultEligibleInner = ((!recoveryBusyInner && mulCdbValidInner) && mulRobLiveInner) && (!globalFlushInner || rv32_pkg_rob_is_older(wbMulTagInner, globalFlushTagInner));
	assign divResultEligibleInner = ((!recoveryBusyInner && divCdbValidInner) && divRobLiveInner) && (!globalFlushInner || rv32_pkg_rob_is_older(wbDivTagInner, globalFlushTagInner));
	assign branchResultLiveInner = (((!recoveryBusyInner && bruValidInner) && bruConditionalInner) && bruRobLiveInner) && (!globalFlushInner || rv32_pkg_rob_is_older(bruTagInner, globalFlushTagInner));
	assign branchFlushCandidateInner = branchResultLiveInner && bruMispredictInner;
	assign branchFlushPcInner = bruNextPcInner;
	assign jumpFlushCandidateInner = (aluResultLiveInner && aluCdbIsControlInner) && (wbAluValueInner != jumpRobPredictedPcInner);
	assign jumpFlushPcInner = wbAluValueInner;
	assign predictorUpdateValidInner = branchResultLiveInner || (aluResultLiveInner && aluCdbIsControlInner);
	assign predictorMispredictInner = branchFlushCandidateInner || jumpFlushCandidateInner;
	assign globalFlushInner = (flushOutputInner[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] && !recoveryBusyInner) && !haltedInner;
	assign recoveryBusyInner = recoveryStepInner[22];
	assign pipelineFrozenInner = haltedInner || recoveryBusyInner;
	assign frontendFrozenInner = haltedInner || (recoveryBusyInner && !(((((FETCH_WIDTH == 2) && !LEGACY_HALT) && imemFetchHintInput[4]) && !imemFetchHintInput[3]) && !imemFetchHintInput[2]));
	assign globalFlushTagInner = flushOutputInner[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)];
	assign globalRedirectPcInner = flushOutputInner[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)];
	assign globalFlushCkptIdInner = flushOutputInner[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W];
	rv32_recovery_cursor u_recovery_cursor(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.freezeInput(haltedInner),
		.startInput(globalFlushInner),
		.headTagInput(robHeadTagInner),
		.squashTagInput(globalFlushTagInner),
		.countInput(robCountInner),
		.stepOutput(recoveryStepInner)
	);
	localparam [6:0] rv32_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32_pkg_OPCODE_JALR = 7'b1100111;
	assign robCommitIsCallInner = ((robCommitInstrInner[6:0] == rv32_pkg_OPCODE_JAL) || ((robCommitInstrInner[6:0] == rv32_pkg_OPCODE_JALR) && (robCommitInstrInner[14:12] == 3'b000))) && ((robCommitInstrInner[11:7] == 5'd1) || (robCommitInstrInner[11:7] == 5'd5));
	assign robCommitIsRetInner = (((robCommitInstrInner[6:0] == rv32_pkg_OPCODE_JALR) && (robCommitInstrInner[14:12] == 3'b000)) && ((robCommitInstrInner[19:15] == 5'd1) || (robCommitInstrInner[19:15] == 5'd5))) && (robCommitInstrInner[11:7] != robCommitInstrInner[19:15]);
	always @* begin
		predictorRobInputInner = 1'sb0;
		begin : sv2v_autoblock_3
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				begin
					predictorRobInputInner[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (1 + (rv32_pkg_ROB_TAG_W + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31))))] = retirementFireInner[lane];
					predictorRobInputInner[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (rv32_pkg_ROB_TAG_W + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)))-:((7 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)) >= (34 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0)) ? ((rv32_pkg_ROB_TAG_W + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31))) - (34 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0))) + 1 : ((34 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0)) - (rv32_pkg_ROB_TAG_W + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)))) + 1)] = robCommitOutputInner[(lane * 93) + 91-:5];
					predictorRobInputInner[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31))] = ((robCommitOutputInner[(lane * 93) + 29-:7] == rv32_pkg_OPCODE_JAL) || ((robCommitOutputInner[(lane * 93) + 29-:7] == rv32_pkg_OPCODE_JALR) && (robCommitOutputInner[(lane * 93) + 37-:3] == 0))) && ((robCommitOutputInner[(lane * 93) + 34-:5] == 1) || (robCommitOutputInner[(lane * 93) + 34-:5] == 5));
					predictorRobInputInner[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 32)] = (((robCommitOutputInner[(lane * 93) + 29-:7] == rv32_pkg_OPCODE_JALR) && (robCommitOutputInner[(lane * 93) + 37-:3] == 0)) && ((robCommitOutputInner[(lane * 93) + 42-:5] == 1) || (robCommitOutputInner[(lane * 93) + 42-:5] == 5))) && (robCommitOutputInner[(lane * 93) + 34-:5] != robCommitOutputInner[(lane * 93) + 42-:5]);
					predictorRobInputInner[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)-:((((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31) >= (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0) ? ((((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31) - (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0)) + 1 : ((((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0) - (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)) + 1)] = robCommitOutputInner[(lane * 93) + 86-:32];
				end
		end
		for (robInputIndexInner = 0; robInputIndexInner < rv32_pkg_RECOVERY_WIDTH; robInputIndexInner = robInputIndexInner + 1)
			predictorRobInputInner[0 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) - 1) - (((rv32_pkg_RECOVERY_WIDTH * 39) - 1) - (0 + (robInputIndexInner * 39))) : -((0 + (robInputIndexInner * 39)) + 38))+:39] = robReplayRasInner[0 + (robInputIndexInner * 39)+:39];
	end
	assign predictorFetchInfoInner = fetchInfoOutputInner;
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
	assign predictorBranchInputInner = {branchResultLiveInner, sv2v_cast_60734(bruTagInner), bruRobLiveInner, bruPcInner, bruNextPcInner, bruTakenInner, sv2v_cast_C1E44(bruRobCkptIdInner)};
	assign predictorJumpInputInner = {aluResultLiveInner && aluCdbIsControlInner, sv2v_cast_60734(wbAluTagInner), jumpRobLiveInner, jumpRobPcInner, wbAluValueInner, jumpRobIsRetInner};
	assign branchFlushInputInner = {branchFlushCandidateInner, sv2v_cast_60734(bruTagInner), branchFlushPcInner, sv2v_cast_C1E44(bruRobCkptIdInner)};
	assign jumpFlushInputInner = {jumpFlushCandidateInner, sv2v_cast_60734(wbAluTagInner), jumpFlushPcInner, sv2v_cast_C1E44(jumpRobCkptIdInner)};
	assign predictorSquashInputInner = {globalFlushInner, sv2v_cast_60734(globalFlushTagInner), globalRedirectPcInner, sv2v_cast_C1E44(globalFlushCkptIdInner)};
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	generate
		if (1) begin : g_alu_writebacks
			genvar _gv_lane_3;
			for (_gv_lane_3 = 0; _gv_lane_3 < 2; _gv_lane_3 = _gv_lane_3 + 1) begin : g_port
				localparam lane = _gv_lane_3;
				assign writebackInputInner[0 + (lane * 39)+:39] = {aluResultGrantInner[lane] && !aluLaneResultInner[lane][1], sv2v_cast_A32BA(aluLaneResultInner[lane][7-:6]), sv2v_cast_32(aluLaneResultInner[lane][44-:32])};
			end
		end
	endgenerate
	wire [155:0] svEarlyWritebackInner;
	genvar _gv_earlyPort_1;
	generate
		for (_gv_earlyPort_1 = 0; _gv_earlyPort_1 < rv32_pkg_WRITEBACK_PORTS; _gv_earlyPort_1 = _gv_earlyPort_1 + 1) begin : g_sv_early_cdb
			localparam earlyPort = _gv_earlyPort_1;
			if (!(!(earlyPort < 2))) begin : g_dual
				assign svEarlyWritebackInner[0 + (earlyPort * 39)+:39] = {aluResultGrantInner[earlyPort] && !aluLaneResultInner[earlyPort][1], sv2v_cast_A32BA(aluLaneResultInner[earlyPort][7-:6]), sv2v_cast_32(aluLaneResultInner[earlyPort][44-:32])};
			end
			else begin : g_no_shared
				assign svEarlyWritebackInner[0 + (earlyPort * 39)+:39] = 1'sb0;
			end
		end
	endgenerate
	assign sharedCdbCandidatesInner[0+:39] = {mulResultEligibleInner, sv2v_cast_A32BA(wbMulPhyInner), wbMulValueInner};
	assign sharedCdbCandidatesInner[39+:39] = {divResultEligibleInner, sv2v_cast_A32BA(wbDivPhyInner), wbDivValueInner};
	assign sharedCdbTagsInner[0+:rv32_pkg_ROB_TAG_W] = wbMulTagInner;
	assign sharedCdbTagsInner[rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = wbDivTagInner;
	localparam [31:0] rv32_pkg_MULDIV_CDB_PORT = rv32_pkg_ALU_CDB_PORTS;
	rv32_cdb_arbiter u_shared_cdb(
		.candidateInput(sharedCdbCandidatesInner),
		.candidateTagInput(sharedCdbTagsInner),
		.resultOutput(writebackInputInner[78+:39]),
		.robTagOutput(sharedCdbTagInner),
		.grantOutput(sharedCdbGrantInner)
	);
	assign wbMulValidInner = sharedCdbGrantInner[0];
	assign wbDivValidInner = sharedCdbGrantInner[1];
	assign writebackInputInner[117+:39] = {loadResultEligibleInner, sv2v_cast_A32BA(wbLoadPhyInner), wbLoadValueInner};
	assign wbLoadValidInner = writebackInputInner[155];
	assign aluCdbValidInner = aluExecuteOutputInner[45];
	assign wbAluValueInner = aluExecuteOutputInner[44-:32];
	assign wbAluTagInner = aluExecuteOutputInner[12-:5];
	assign wbAluPhyInner = aluExecuteOutputInner[7-:6];
	assign aluCdbIsControlInner = aluExecuteOutputInner[1];
	assign mulCdbValidInner = mulExecuteOutputInner[43];
	assign wbMulValueInner = mulExecuteOutputInner[42-:32];
	assign wbMulTagInner = mulExecuteOutputInner[10-:5];
	assign wbMulPhyInner = mulExecuteOutputInner[5-:rv32_pkg_PHY_TAG_W];
	assign divCdbValidInner = divExecuteOutputInner[43];
	assign wbDivValueInner = divExecuteOutputInner[42-:32];
	assign wbDivTagInner = divExecuteOutputInner[10-:5];
	assign wbDivPhyInner = divExecuteOutputInner[5-:rv32_pkg_PHY_TAG_W];
	assign bruValidInner = bruExecuteOutputInner[139];
	assign bruTagInner = bruExecuteOutputInner[138-:5];
	assign bruPcInner = bruExecuteOutputInner[133-:32];
	assign bruNextPcInner = bruExecuteOutputInner[69-:32];
	assign bruTakenInner = bruExecuteOutputInner[5];
	assign bruConditionalInner = bruExecuteOutputInner[4];
	assign bruMispredictInner = bruExecuteOutputInner[3];
	assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? 0 : COMMIT_WIDTH + 3) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(ratRs1PhyInner)};
	assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? 1 : COMMIT_WIDTH + 2) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(ratRs2PhyInner)};
	assign prfSrc1ReadyInner = prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? 0 : COMMIT_WIDTH + 3) * 33) + 32];
	assign prfSrc1ValueInner = prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? 0 : COMMIT_WIDTH + 3) * 33) + 31-:32];
	assign prfSrc2ReadyInner = prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? 1 : COMMIT_WIDTH + 2) * 33) + 32];
	assign prfSrc2ValueInner = prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? 1 : COMMIT_WIDTH + 2) * 33) + 31-:32];
	assign prfCommitReadyInner = prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? 2 : COMMIT_WIDTH + 1) * 33) + 32];
	assign prfCommitValueInner = prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? 2 : COMMIT_WIDTH + 1) * 33) + 31-:32];
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	assign ratReadInputInner = {sv2v_cast_5(decodedInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_5(decodedInner[137 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])};
	assign ratRenameInputInner = {issueFireInner && decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)], sv2v_cast_5(decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_A32BA(prfAllocPhyInner)};
	assign ratRestoreInputInner = {globalFlushInner, sv2v_cast_60734(globalFlushTagInner), sv2v_cast_60734(robHeadTagInner)};
	assign ratRs1PhyInner = ratReadOutputInner[11-:6];
	assign ratRs2PhyInner = ratReadOutputInner[5-:rv32_pkg_PHY_TAG_W];
	assign ratOldPhyInner = ratRenameOutputInner[5-:rv32_pkg_PHY_TAG_W];
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	assign lsuLoadAllocationInputInner = {issueFireInner && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd5), sv2v_cast_60734(robAllocTagInner), sv2v_cast_A32BA(issueDestPhyInner), sv2v_cast_2(decodedInner[2-:2]), decodedInner[0]};
	assign lsuStoreAllocationInputInner = {issueFireInner && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6), sv2v_cast_60734(robAllocTagInner), sv2v_cast_2(decodedInner[2-:2]), 1'b0, sv2v_cast_A32BA(0), 32'b00000000000000000000000000000000};
	assign lsuStoreCommitInputInner = retirementStoreInputInner[0+:6];
	assign lsuStoreCommitReadyInner = retirementStoreReadyInner[0];
	assign lsuStoreRetirementOutputInner = retirementMemoryInner[0+:72];
	assign lsuDmemResponseInputInner = {dmemRspValidInput, dmemRspRdataInput};
	assign loadCdbValidInner = lsuLoadResultOutputInner[43];
	assign wbLoadTagInner = lsuLoadResultOutputInner[42-:5];
	assign wbLoadPhyInner = lsuLoadResultOutputInner[37-:6];
	assign wbLoadValueInner = lsuLoadResultOutputInner[31-:32];
	assign dmemReqValidOutput = lsuDmemRequestOutputInner[71];
	assign dmemReqWriteOutput = lsuDmemRequestOutputInner[70];
	assign dmemReqAddrOutput = lsuDmemRequestOutputInner[69-:32];
	assign dmemReqWdataOutput = lsuDmemRequestOutputInner[37-:32];
	assign dmemReqWstrbOutput = lsuDmemRequestOutputInner[5-:4];
	assign dmemReqSizeOutput = lsuDmemRequestOutputInner[1-:2];
	function automatic [1:0] sv2v_cast_FD44F;
		input reg [1:0] inp;
		sv2v_cast_FD44F = inp;
	endfunction
	assign robAllocInputInner = {issueFireInner, sv2v_cast_32(decodedInner[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedInner[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)], sv2v_cast_5(decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_A32BA(issueDestPhyInner), sv2v_cast_A32BA(ratOldPhyInner), decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] && (ratOldPhyInner != 1'b0), decodedInner[158 + (rv32_pkg_BPU_CKPT_ID_W + 2)], decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6, sv2v_cast_FD44F(sqAllocIndexInner), decodedInner[158 + (rv32_pkg_BPU_CKPT_ID_W + 2)], 1'b0, sv2v_cast_32(decodedInner[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedInner[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))]), issueIsReturnInner};
	generate
		if (1) begin : g_independent_alu_completions
			assign robCompletionInputInner[0+:7] = {aluResultGrantInner[0], sv2v_cast_60734(aluLaneResultInner[0][12-:5]), 1'b0};
			assign robCompletionInputInner[14+:7] = {aluResultGrantInner[1], sv2v_cast_60734(aluLaneResultInner[1][12-:5]), 1'b0};
			assign robLookupInputInner[rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = {sv2v_cast_60734(aluLaneResultInner[0][12-:5])};
			assign robLookupInputInner[25+:rv32_pkg_ROB_TAG_W] = {sv2v_cast_60734(aluLaneResultInner[1][12-:5])};
		end
	endgenerate
	assign robCompletionInputInner[7+:7] = {writebackInputInner[116], sv2v_cast_60734(sharedCdbTagInner), 1'b0};
	assign robCompletionInputInner[21+:7] = {writebackInputInner[155], sv2v_cast_60734(wbLoadTagInner), 1'b0};
	assign robCompletionInputInner[28+:7] = {branchResultLiveInner, sv2v_cast_60734(bruTagInner), 1'b0};
	assign robCompletionInputInner[35+:7] = 1'sb0;
	assign robLookupInputInner[0+:rv32_pkg_ROB_TAG_W] = {sv2v_cast_60734(bruTagInner)};
	assign robLookupInputInner[10+:rv32_pkg_ROB_TAG_W] = {sv2v_cast_60734((ISSUE_WIDTH == 4 ? sv2v_cast_60734(0) : wbLoadTagInner))};
	assign robLookupInputInner[15+:rv32_pkg_ROB_TAG_W] = {sv2v_cast_60734(wbMulTagInner)};
	assign robLookupInputInner[20+:rv32_pkg_ROB_TAG_W] = {sv2v_cast_60734(wbDivTagInner)};
	assign robCommitValidInner = robCommitOutputInner[92];
	assign robCommitFireInner = retirementFireInner[0];
	assign robCommitFireOutputInner = retirementFireInner[0];
	assign robCommitTagInner = robCommitOutputInner[91-:5];
	assign robCommitPcInner = robCommitOutputInner[86-:32];
	assign robCommitInstrInner = robCommitOutputInner[54-:32];
	assign robCommitWritesInner = robCommitOutputInner[22];
	assign robCommitRdInner = robCommitOutputInner[21-:5];
	assign robCommitNewPhyInner = robCommitOutputInner[16-:6];
	assign robCommitOldPhyInner = robCommitOutputInner[10-:6];
	assign robCommitSqIndexInner = robCommitOutputInner[3-:2];
	assign robCommitHaltInner = robCommitOutputInner[1];
	assign robCommitStoreInner = retirementStoreInner[0];
	genvar _gv_lane_4;
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	generate
		for (_gv_lane_4 = 0; _gv_lane_4 < COMMIT_WIDTH; _gv_lane_4 = _gv_lane_4 + 1) begin : g_retirement
			localparam lane = _gv_lane_4;
			wire prefix;
			if (lane == 0) begin : g_first
				assign prefix = 1'b1;
			end
			else begin : g_following
				assign prefix = !(retirementStoreInner[lane - 1] && retirementExitInner[lane - 1]);
			end
			assign retirementReadyInner[lane] = (((bootDoneInner && !pipelineFrozenInner) && !globalFlushInner) && prefix) && (retirementStoreInner[lane] ? retirementStoreReadyInner[lane] : 1'b1);
			assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? lane + 2 : (COMMIT_WIDTH + 3) - (lane + 2)) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(robCommitOutputInner[(lane * 93) + 16-:6])};
			assign ratCommitInputInner[lane * 12+:12] = {retirementFireInner[lane] && robCommitOutputInner[(lane * 93) + 22], sv2v_cast_5(robCommitOutputInner[(lane * 93) + 21-:5]), sv2v_cast_A32BA(robCommitOutputInner[(lane * 93) + 16-:6])};
			assign retirementFreeInner[lane * 7+:7] = {retirementFireInner[lane] && robCommitOutputInner[(lane * 93) + 4], sv2v_cast_A32BA(robCommitOutputInner[(lane * 93) + 10-:6])};
			assign retirementStoreInputInner[lane * 6+:6] = {((robCommitOutputInner[(lane * 93) + 92] && retirementStoreInner[lane]) && !globalFlushInner) && !pipelineFrozenInner, sv2v_cast_60734(robCommitOutputInner[(lane * 93) + 91-:5])};
			assign retirementInputInner[lane * 6+:6] = {retirementFireInner[lane], sv2v_cast_60734(robCommitOutputInner[(lane * 93) + 91-:5])};
			assign retirementSqIndexInner[lane * rv32_pkg_SQ_SLOT_W+:rv32_pkg_SQ_SLOT_W] = robCommitOutputInner[(lane * 93) + 3-:2];
			assign retirementOutput[lane * 172+:172] = {retirementFireInner[lane], sv2v_cast_32(robCommitOutputInner[(lane * 93) + 86-:32]), sv2v_cast_32(robCommitOutputInner[(lane * 93) + 54-:32]), (retirementFireInner[lane] && robCommitOutputInner[(lane * 93) + 22]) && (robCommitOutputInner[(lane * 93) + 21-:5] != 32'sd0), sv2v_cast_5(robCommitOutputInner[(lane * 93) + 21-:5]), sv2v_cast_32(prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? lane + 2 : (COMMIT_WIDTH + 3) - (lane + 2)) * 33) + 31-:32]), retirementFireInner[lane] && retirementStoreInner[lane], sv2v_cast_32(retirementMemoryInner[(lane * 72) + 69-:32]), sv2v_cast_32(retirementMemoryInner[(lane * 72) + 37-:32]), sv2v_cast_4(retirementMemoryInner[(lane * 72) + 5-:4])};
		end
	endgenerate
	assign robEmptyInner = robStatusOutputInner[6];
	assign robFullInner = robStatusOutputInner[5];
	assign robHeadTagInner = robStatusOutputInner[4-:rv32_pkg_ROB_TAG_W];
	assign bruRobLiveInner = robLookupOutputInner[0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))];
	assign bruRobPcInner = robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : ((0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
	assign bruRobPredictedPcInner = robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : ((0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
	assign bruRobCkptIdInner = robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0)) : ((0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0))) + ((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))];
	assign bruRobIsRetInner = robLookupOutputInner[0 + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)];
	assign jumpRobLiveInner = jumpLookupInner[65 + (rv32_pkg_BPU_CKPT_ID_W + 0)];
	assign jumpRobPcInner = jumpLookupInner[64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
	assign jumpRobPredictedPcInner = jumpLookupInner[32 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
	assign jumpRobCkptIdInner = jumpLookupInner[rv32_pkg_BPU_CKPT_ID_W + 0-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))];
	assign jumpRobIsRetInner = jumpLookupInner[0];
	assign loadRobLiveInner = (ISSUE_WIDTH == 4 ? loadLookupSeparateInner[65 + (rv32_pkg_BPU_CKPT_ID_W + 0)] : robLookupOutputInner[(2 * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))]);
	assign mulRobLiveInner = robLookupOutputInner[(3 * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))];
	assign divRobLiveInner = robLookupOutputInner[(4 * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))];
	assign predictorFetchAcceptInner = predictorQueryOutputInner[0];
	assign imemSecondRequestOutput = frontendSecondRequestInner;
	assign imemFetchCountOutput = frontendFetchCountInner;
	assign imemReqValidOutput = (frontendImemRequestOutputInner[33 + (rv32_pkg_BPU_CKPT_ID_W + 31)] && bootDoneInner) && !haltedInner;
	assign imemCacheRequestOutput = {imemReqValidOutput, predictorPcInner, sv2v_cast_32(frontendImemRequestOutputInner[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)]), sv2v_cast_C1E44(frontendImemRequestOutputInner[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W])};
	assign imemReqAddrOutput = predictorPcInner;
	assign frontendImemResponseInputInner = {imemRspValidInput, imemRspDataInput};
	assign frontendRedirectInputInner = {globalFlushInner, globalRedirectPcInner};
	assign frontendIqValidInner = frontendInstructionOutputInner[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0];
	assign iqPcInner = frontendInstructionOutputInner[((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (rv32_pkg_BPU_CKPT_ID_W + 63))-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)];
	assign iqInstrInner = frontendInstructionOutputInner[((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31)))-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)];
	assign iqPredictedPcInner = frontendInstructionOutputInner[((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (rv32_pkg_BPU_CKPT_ID_W + 31))-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)];
	assign iqPredictorCkptIdInner = frontendInstructionOutputInner[((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (((96 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (rv32_pkg_BPU_CKPT_ID_W - 1))-:rv32_pkg_BPU_CKPT_ID_W];
	assign decodeContextInner = {iqInstrInner, iqPcInner, iqPredictedPcInner, sv2v_cast_C1E44(iqPredictorCkptIdInner)};
	rv32_flush_arbiter #(.SORTED_HEAD_SELECT(1'b1)) u_flush_arbiter(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.branchInput(branchFlushInputInner),
		.jumpInput(jumpFlushInputInner),
		.squashOutput(flushOutputInner)
	);
	rv32_frontend #(
		.RESET_PC(RESET_PC),
		.LEGACY_HALT(LEGACY_HALT),
		.FETCH_WIDTH(FETCH_WIDTH),
		.DECODE_WIDTH(DECODE_WIDTH),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.FQ_DEPTH(FQ_DEPTH),
		.IQ_DEPTH(IQ_DEPTH)
	) u_frontend(
		.freezeInput(haltedInner),
		.fetchFreezeInput(frontendFrozenInner),
		.recoveryActiveInput(recoveryBusyInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.predictorQueryOutput(predictorQueryOutputInner),
		.fetchProgramCounterOutput(predictorPcInner),
		.predictionInput(predictorOutputInner),
		.fetchHintInput(imemFetchHintInput),
		.imemSecondInstructionInput(imemRspSecondDataInput),
		.secondRequestOutput(frontendSecondRequestInner),
		.predictEnableOutput(predictorFetchPredictInner),
		.imemPacketInstructionsInput(imemRspPacketDataInput),
		.fetchCountOutput(frontendFetchCountInner),
		.imemRequestOutput(frontendImemRequestOutputInner),
		.imemReqReadyInput((imemReqReadyInput && bootDoneInner) && !haltedInner),
		.imemResponseInput(frontendImemResponseInputInner),
		.imemRspReadyOutput(imemRspReadyOutput),
		.imemFlushOutput(imemFlushOutput),
		.redirectInput(frontendRedirectInputInner),
		.instructionOutput(frontendInstructionOutputInner),
		.decodedOutput(frontendDecodedInner),
		.iqReadyInput(frontendIqReadyInner),
		.instructionSecondOutput(frontendSecondInstructionInner),
		.decodedSecondOutput(decodedSecondInner),
		.iqSecondReadyInput(issueSecondFireInner),
		.decodedLanesOutput(wideDecodedInner),
		.iqLaneValidOutput(wideValidInner),
		.iqReadyCountInput(wideIssueCountInner),
		.wholeGroupOutput(frontendWholeGroupInner),
		.fetchInfoOutput(fetchInfoOutputInner),
		.fqCountOutput(unusedFqCountInner),
		.iqCountOutput(unusedIqCountInner)
	);
	rv32_predictor #(
		.COMMIT_WIDTH(COMMIT_WIDTH),
		.FETCH_WIDTH(FETCH_WIDTH)
	) u_predictor(
		.freezeInput(haltedInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.queryPcInput(predictorQueryOutputInner[32-:32]),
		.fetchAcceptInput(predictorFetchAcceptInner),
		.fetchPredictInput(predictorFetchPredictInner),
		.fetchSecondInput(frontendSecondRequestInner),
		.fetchCountInput(frontendFetchCountInner),
		.fetchInfoInput(predictorFetchInfoInner),
		.branchInput(predictorBranchInputInner),
		.jumpInput(predictorJumpInputInner),
		.squashInput(predictorSquashInputInner),
		.robInput(predictorRobInputInner),
		.recoveryInput(recoveryStepInner),
		.predictionOutput(predictorOutputInner)
	);
	generate
		if ((DECODE_WIDTH == 1) && (ISSUE_WIDTH == 1)) begin : g_single_decode
			rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder(
				.decodeContextInput(decodeContextInner),
				.uopOutput(decodedInner)
			);
		end
		else begin : g_multi_decode
			assign decodedInner = frontendDecodedInner;
		end
	endgenerate
	rv32_add #(.WIDTH(32)) u_link_add(
		.aInput(decodedInner[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]),
		.bInput(32'd4),
		.cinInput(1'b0),
		.sumOutput(issueLinkValueInner),
		.coutOutput(unusedCoutLinkInner)
	);
	function automatic [5:0] sv2v_cast_002AA;
		input reg [5:0] inp;
		sv2v_cast_002AA = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_96EA0_signed;
		input reg signed [31:0] inp;
		sv2v_cast_96EA0_signed = inp;
	endfunction
	function automatic [33:0] sv2v_cast_34;
		input reg [33:0] inp;
		sv2v_cast_34 = inp;
	endfunction
	generate
		if (ISSUE_WIDTH != 4) begin : g_legacy_rename_state
			assign loadLookupSeparateInner = 1'sb0;
			assign loadIdentityInner = sv2v_cast_96EA0_signed(0);
			wire [5:0] unusedPrfFreeCountInner;
			assign wideFireInner = 1'sb0;
			assign wideIssueCountInner = 1'sb0;
			assign wideRsAllocInner = 1'sb0;
			assign wideRsAuxInner = 1'sb0;
			assign wideLoadAllocInner = 1'sb0;
			assign wideStoreAllocInner = 1'sb0;
			rv32_rat #(
				.COMMIT_WIDTH(COMMIT_WIDTH),
				.RENAME_WIDTH(ISSUE_WIDTH)
			) u_rat(
				.freezeInput(haltedInner),
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.readInput(ratReadInputInner),
				.readOutput(ratReadOutputInner),
				.renameInput(ratRenameInputInner),
				.renameOutput(ratRenameOutputInner),
				.readSecondInput(ratReadSecondInputInner),
				.readSecondOutput(ratReadSecondOutputInner),
				.renameSecondInput(ratRenameSecondInputInner),
				.renameSecondOutput(ratRenameSecondOutputInner),
				.restoreInput(ratRestoreInputInner),
				.recoveryInput(recoveryStepInner),
				.replayInput(robReplayNarrowInner),
				.commitInput(ratCommitInputInner)
			);
			rv32_prf #(
				.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
				.COMMIT_WIDTH(COMMIT_WIDTH),
				.RENAME_WIDTH(ISSUE_WIDTH),
				.READ_PORTS(COMMIT_WIDTH + 4)
			) u_prf(
				.freezeInput(haltedInner),
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.allocationInput(sv2v_cast_34({issueFireInner && decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)], (issueFireInner && decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)]) && issueIsJumpInner, issueLinkValueInner})),
				.allocReadyOutput(prfAllocReadyInner),
				.allocPhyOutput(prfAllocPhyInner),
				.allocationSecondInput(prfAllocSecondInputInner),
				.allocSecondReadyOutput(prfAllocSecondReadyInner),
				.allocSecondPhyOutput(prfAllocSecondPhyInner),
				.freeInput(retirementFreeInner),
				.restoreInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
				.recoveryInput(recoveryStepInner),
				.restoreCountInput(robCountInner),
				.replayInput(robReplayNarrowInner),
				.readInput(prfReadInputInner),
				.readOutput(prfReadOutputInner),
				.writebackInput(writebackInputInner),
				.readyVectorOutput(prfReadyVectorInner),
				.freeCountOutput(unusedPrfFreeCountInner)
			);
			rv32_rob #(
				.COMMIT_WIDTH(COMMIT_WIDTH),
				.RENAME_WIDTH(ISSUE_WIDTH)
			) u_rob(
				.freezeInput(pipelineFrozenInner),
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.allocInput(robAllocInputInner),
				.allocReadyOutput(robAllocReadyInner),
				.allocTagOutput(robAllocTagInner),
				.allocSecondInput(robAllocSecondInputInner),
				.allocSecondReadyOutput(robAllocSecondReadyInner),
				.allocSecondTagOutput(robAllocSecondTagInner),
				.completionInput(robCompletionInputInner),
				.storeReadyInput(lsuStoreCompleteOutputInner),
				.flushInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
				.lookupInput(robLookupInputInner[0+:25]),
				.lookupOutput(robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + 0+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)) * 5]),
				.commitOutput(robCommitOutputInner),
				.commitStoreOutput(retirementStoreInner),
				.commitReadyInput(retirementReadyInner),
				.commitFireOutput(retirementFireInner),
				.statusOutput(robStatusOutputInner),
				.countOutput(robCountInner),
				.replayOffsetInput(recoveryStepInner[19-:5]),
				.replayNarrowOutput(robReplayNarrowInner),
				.replayRasOutput(robReplayRasInner)
			);
		end
		else begin : g_four_rename_state
			wire [(ROB_LOOKUP_PORTS * rv32_pkg_ROB_TAG_W) - 1:0] independentLookup;
			wire [(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (ROB_LOOKUP_PORTS * ((65 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (ROB_LOOKUP_PORTS * (1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((65 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] independentResult;
			genvar _gv_p_1;
			for (_gv_p_1 = 0; _gv_p_1 < ROB_LOOKUP_PORTS; _gv_p_1 = _gv_p_1 + 1) begin : g_lookup_route
				localparam p = _gv_p_1;
				if (p == 2) begin : g_load_hole
					assign independentLookup[p * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = 1'sb0;
					assign robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (p * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))] = 1'sb0;
				end
				else begin : g_registered
					assign independentLookup[p * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = robLookupInputInner[p * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W];
					assign robLookupOutputInner[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (p * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))] = independentResult[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (p * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))];
				end
			end
			assign prfAllocReadyInner = 1'b1;
			assign robAllocReadyInner = 1'b1;
			assign ratReadSecondOutputInner = 1'sb0;
			assign ratRenameSecondOutputInner = 1'sb0;
			assign prfAllocSecondPhyInner = 1'sb0;
			assign prfAllocSecondReadyInner = 1'b0;
			assign robAllocSecondTagInner = 1'sb0;
			assign robAllocSecondReadyInner = 1'b0;
			rv32_rename_four #(
				.COMMIT_WIDTH(COMMIT_WIDTH),
				.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
				.LOOKUP_PORTS(ROB_LOOKUP_PORTS)
			) u_rename(
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.freezeInput(haltedInner),
				.enableInput((bootDoneInner && !pipelineFrozenInner) && !globalFlushInner),
				.decodedInput(wideDecodedInner),
				.validInput(wideValidInner),
				.wholeGroupInput(frontendWholeGroupInner),
				.fireOutput(wideFireInner),
				.countOutput(wideIssueCountInner),
				.rsCreditsInput(wideRsCreditsInner),
				.branchCreditFitsInput(unusedCreditFitsInner[15+:5]),
				.loadCreditsInput(wideLoadCreditsInner),
				.storeCreditsInput(wideStoreCreditsInner),
				.loadPreviewInput(wideLoadPreviewInner),
				.storePreviewInput(wideStorePreviewInner),
				.rsOutput(wideRsAllocInner),
				.rsAuxOutput(wideRsAuxInner),
				.loadOutput(wideLoadAllocInner),
				.storeOutput(wideStoreAllocInner),
				.mapCommitInput(ratCommitInputInner),
				.freeInput(retirementFreeInner),
				.scalarReadInput(prfReadInputInner),
				.scalarReadOutput(prfReadOutputInner),
				.firstMapOutput(ratReadOutputInner),
				.firstPreviousOutput(ratRenameOutputInner),
				.firstFreePhysicalOutput(prfAllocPhyInner),
				.readyVectorOutput(prfReadyVectorInner),
				.writebackInput(writebackInputInner),
				.completionInput(robCompletionInputInner),
				.storeReadyInput(lsuStoreCompleteOutputInner),
				.flushInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
				.recoveryInput(recoveryStepInner),
				.lookupInput(independentLookup),
				.lookupOutput(independentResult),
				.lookupLoadInput(sv2v_cast_60734({sv2v_cast_60734(wbLoadTagInner)})),
				.lookupLoadOutput(loadLookupSeparateInner),
				.loadIdentityOutput(loadIdentityInner),
				.commitOutput(robCommitOutputInner),
				.commitStoreOutput(retirementStoreInner),
				.commitReadyInput(retirementReadyInner),
				.commitFireOutput(retirementFireInner),
				.statusOutput(robStatusOutputInner),
				.robCountOutput(robCountInner),
				.nextTagOutput(robAllocTagInner),
				.replayNarrowOutput(robReplayNarrowInner),
				.replayRasOutput(robReplayRasInner)
			);
		end
	endgenerate
	always @* begin
		issueIsJumpInner = (decodedInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd27) || (decodedInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28);
		issueIsCallInner = issueIsJumpInner && ((decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 5'd1) || (decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 5'd5));
		issueIsReturnInner = ((decodedInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28) && ((decodedInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 5'd1) || (decodedInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 5'd5))) && (decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != decodedInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
		issueDestPhyInner = (decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] ? prfAllocPhyInner : {rv32_pkg_PHY_TAG_W {1'sb0}});
		issueSrc1ReadyInner = !decodedInner[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] || prfSrc1ReadyInner;
		issueSrc1ValueInner = (decodedInner[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] ? prfSrc1ValueInner : 32'b00000000000000000000000000000000);
		issueSrc2ReadyInner = !decodedInner[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] || prfSrc2ReadyInner;
		issueSrc2ValueInner = (decodedInner[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] ? prfSrc2ValueInner : 32'b00000000000000000000000000000000);
		targetRsReadyInner = 1'b1;
		(* full_case, parallel_case *)
		case (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])
			4'd1: targetRsReadyInner = intAllocReadyInner;
			4'd2: targetRsReadyInner = mulAllocReadyInner;
			4'd3: targetRsReadyInner = divAllocReadyInner;
			4'd4: targetRsReadyInner = branchAllocReadyInner;
			4'd5: targetRsReadyInner = loadRsAllocReadyInner && lqAllocReadyInner;
			4'd6: targetRsReadyInner = (saRsAllocReadyInner && svRsAllocReadyInner) && sqAllocReadyInner;
			default: targetRsReadyInner = 1'b1;
		endcase
		issueResourcesReadyInner = (robAllocReadyInner && targetRsReadyInner) && (!decodedInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] || prfAllocReadyInner);
		issueFireInner = (ISSUE_WIDTH == 4 ? wideFireInner[0] : (((bootDoneInner && frontendIqValidInner) && issueResourcesReadyInner) && !globalFlushInner) && !pipelineFrozenInner);
		frontendIqReadyInner = issueFireInner;
		robCommitReadyInner = retirementReadyInner[0];
		commitValidOutput = robCommitFireInner;
		commitPcOutput = robCommitPcInner;
		commitInstrOutput = robCommitInstrInner;
		commitRdValidOutput = (robCommitFireInner && robCommitWritesInner) && (robCommitRdInner != 5'd0);
		commitRdOutput = robCommitRdInner;
		commitRdValueOutput = prfCommitValueInner;
		commitMemValidOutput = robCommitFireInner && robCommitStoreInner;
		commitMemAddrOutput = lsuStoreRetirementOutputInner[69-:32];
		commitMemDataOutput = lsuStoreRetirementOutputInner[37-:32];
		commitMemWstrbOutput = lsuStoreRetirementOutputInner[5-:4];
		haltedOutput = haltedInner;
		trapOutput = 1'b0;
	end
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	always @* begin
		rsAllocBaseInner = {issueFireInner, sv2v_cast_6(decodedInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_60734(robAllocTagInner), sv2v_cast_A32BA(issueDestPhyInner), issueSrc1ReadyInner, sv2v_cast_A32BA(ratRs1PhyInner), issueSrc1ValueInner, issueSrc2ReadyInner, sv2v_cast_A32BA(ratRs2PhyInner), issueSrc2ValueInner, sv2v_cast_32(decodedInner[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedInner[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedInner[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), decodedInner[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)]};
		intRsAllocInputInner = rsAllocBaseInner;
		intRsAllocInputInner[192] = rsAllocBaseInner[192] && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd1);
		mulRsAllocInputInner = rsAllocBaseInner;
		mulRsAllocInputInner[192] = rsAllocBaseInner[192] && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd2);
		mulRsAllocInputInner[0] = 1'b0;
		divRsAllocInputInner = rsAllocBaseInner;
		divRsAllocInputInner[192] = rsAllocBaseInner[192] && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd3);
		divRsAllocInputInner[0] = 1'b0;
		branchRsAllocInputInner = rsAllocBaseInner;
		branchRsAllocInputInner[192] = rsAllocBaseInner[192] && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd4);
		memRsAllocInputInner = rsAllocBaseInner;
		memRsAllocInputInner[192] = rsAllocBaseInner[192] && ((decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd5) || (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6));
		memRsAllocInputInner[135] = 1'b1;
		memRsAllocInputInner[134-:6] = 1'sb0;
		memRsAllocInputInner[128-:32] = 1'sb0;
		memRsAllocInputInner[0] = 1'b1;
		loadRsAllocInputInner = memRsAllocInputInner;
		loadRsAllocInputInner[192] = issueFireInner && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd5);
		saRsAllocInputInner = memRsAllocInputInner;
		saRsAllocInputInner[192] = issueFireInner && (decodedInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6);
		svRsAllocInputInner = rsAllocBaseInner;
		svRsAllocInputInner[192] = saRsAllocInputInner[192];
		svRsAllocInputInner[174] = issueSrc2ReadyInner;
		svRsAllocInputInner[173-:6] = ratRs2PhyInner;
		svRsAllocInputInner[167-:32] = issueSrc2ValueInner;
		svRsAllocInputInner[135] = 1'b1;
		svRsAllocInputInner[134-:6] = 1'sb0;
		svRsAllocInputInner[128-:32] = 1'sb0;
		svRsAllocInputInner[0] = 1'b0;
		for (storeLaneInner = 0; storeLaneInner < rv32_pkg_STORE_VALUE_RS_ENTRIES; storeLaneInner = storeLaneInner + 1)
			begin
				svRsStoreDataInner[((1 - storeLaneInner) * 38) + 37] = !recoveryBusyInner && svRsIssueLaneValidInner[storeLaneInner];
				svRsStoreDataInner[((1 - storeLaneInner) * 38) + 36-:5] = svRsIssueLaneInner[((1 - storeLaneInner) * 179) + 171-:5];
				svRsStoreDataInner[((1 - storeLaneInner) * 38) + 31-:32] = svRsIssueLaneInner[((1 - storeLaneInner) * 179) + 160-:32];
				svRsStoreDataIndexInner[(1 - storeLaneInner) * rv32_pkg_SQ_SLOT_W+:rv32_pkg_SQ_SLOT_W] = svRsIssueLaneAuxInner[(1 - storeLaneInner) * rv32_pkg_SQ_SLOT_W+:rv32_pkg_SQ_SLOT_W];
			end
	end
	rv32_rs #(
		.DEPTH(rv32_pkg_INT_RS_ENTRIES),
		.AUX_W(1),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.ISSUE_WIDTH(ALU_LANES),
		.INDEPENDENT_ISSUE_READY(1'd1),
		.REUSE_ON_ISSUE(1'b0),
		.WB_ISSUE_BYPASS(1'b1)
	) u_int_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(intRsAllocInputInner),
		.allocReadyOutput(intAllocReadyInner),
		.allocAuxInput(issueIsJumpInner),
		.allocSecondInput(intRsAllocSecondInputInner),
		.allocSecondReadyOutput(intAllocSecondReadyInner),
		.allocSecondAuxInput(issueSecondIsJumpInner),
		.allocLanesInput(wideRsAllocInner[0+:772]),
		.allocLanesAuxInput(wideIntAuxInner),
		.allocLanesFireOutput(wideRsFireInner[0+:4]),
		.allocCreditsOutput(wideIntCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[0+:5]),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(writebackInputInner),
		.issueOutput(intRsIssueOutputInner),
		.issueReadyInput(intIssueReadyInner),
		.issueAuxOutput(intIssueAuxInner),
		.occupancyOutput(unusedIntOccupancyInner),
		.issueLaneValidOutput(intIssueLaneValidInner),
		.issueLaneOutput(intIssueLaneInner),
		.issueLaneAuxOutput(intIssueLaneAuxInner),
		.issueLaneReadyInput(intIssueLaneReadyInner)
	);
	assign intIssueValidInner = intRsIssueOutputInner[178];
	assign intIssueOpInner = intRsIssueOutputInner[177-:6];
	assign intIssueTagInner = intRsIssueOutputInner[171-:5];
	assign intIssuePhyInner = intRsIssueOutputInner[166-:6];
	assign intIssueS1Inner = intRsIssueOutputInner[160-:32];
	assign intIssueS2Inner = intRsIssueOutputInner[128-:32];
	assign intIssueImmInner = intRsIssueOutputInner[96-:32];
	assign intIssuePcInner = intRsIssueOutputInner[64-:32];
	assign intIssuePredInner = intRsIssueOutputInner[32-:32];
	assign intIssueUseImmInner = intRsIssueOutputInner[0];
	localparam [31:0] sv2v_uu_u_mul_rs_ISSUE_WIDTH = 1;
	localparam [0:0] sv2v_uu_u_mul_rs_ext_issueLaneReadyInput_0 = 1'sb0;
	rv32_rs #(
		.DEPTH(rv32_pkg_MUL_RS_ENTRIES),
		.AUX_W(1),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH)
	) u_mul_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(mulRsAllocInputInner),
		.allocReadyOutput(mulAllocReadyInner),
		.allocAuxInput(1'b0),
		.allocSecondInput(mulRsAllocSecondInputInner),
		.allocSecondReadyOutput(mulAllocSecondReadyInner),
		.allocSecondAuxInput(1'b0),
		.allocLanesInput(wideRsAllocInner[772+:772]),
		.allocLanesAuxInput(wideMulAuxInner),
		.allocLanesFireOutput(wideRsFireInner[4+:4]),
		.allocCreditsOutput(wideMulCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[5+:5]),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(writebackInputInner),
		.issueOutput(mulRsIssueOutputInner),
		.issueReadyInput(mulIssueReadyInner),
		.issueAuxOutput(mulIssueAuxInner),
		.occupancyOutput(unusedMulOccupancyInner),
		.issueLaneValidOutput(unusedMulIssueLaneValidInner),
		.issueLaneOutput(unusedMulIssueLaneInner),
		.issueLaneAuxOutput(unusedMulIssueLaneAuxInner),
		.issueLaneReadyInput(sv2v_uu_u_mul_rs_ext_issueLaneReadyInput_0)
	);
	assign mulIssueValidInner = mulRsIssueOutputInner[178];
	assign mulIssueOpInner = mulRsIssueOutputInner[177-:6];
	assign mulIssueTagInner = mulRsIssueOutputInner[171-:5];
	assign mulIssuePhyInner = mulRsIssueOutputInner[166-:6];
	assign mulIssueS1Inner = mulRsIssueOutputInner[160-:32];
	assign mulIssueS2Inner = mulRsIssueOutputInner[128-:32];
	assign mulIssueImmInner = mulRsIssueOutputInner[96-:32];
	assign mulIssuePcInner = mulRsIssueOutputInner[64-:32];
	assign mulIssuePredInner = mulRsIssueOutputInner[32-:32];
	assign mulIssueUseImmInner = mulRsIssueOutputInner[0];
	localparam [31:0] sv2v_uu_u_div_rs_ISSUE_WIDTH = 1;
	localparam [0:0] sv2v_uu_u_div_rs_ext_issueLaneReadyInput_0 = 1'sb0;
	rv32_rs #(
		.DEPTH(rv32_pkg_DIV_RS_ENTRIES),
		.AUX_W(1),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH)
	) u_div_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(divRsAllocInputInner),
		.allocReadyOutput(divAllocReadyInner),
		.allocAuxInput(1'b0),
		.allocSecondInput(divRsAllocSecondInputInner),
		.allocSecondReadyOutput(divAllocSecondReadyInner),
		.allocSecondAuxInput(1'b0),
		.allocLanesInput(wideRsAllocInner[1544+:772]),
		.allocLanesAuxInput(wideDivAuxInner),
		.allocLanesFireOutput(wideRsFireInner[8+:4]),
		.allocCreditsOutput(wideDivCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[10+:5]),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(writebackInputInner),
		.issueOutput(divRsIssueOutputInner),
		.issueReadyInput(divIssueReadyInner),
		.issueAuxOutput(divIssueAuxInner),
		.occupancyOutput(unusedDivOccupancyInner),
		.issueLaneValidOutput(unusedDivIssueLaneValidInner),
		.issueLaneOutput(unusedDivIssueLaneInner),
		.issueLaneAuxOutput(unusedDivIssueLaneAuxInner),
		.issueLaneReadyInput(sv2v_uu_u_div_rs_ext_issueLaneReadyInput_0)
	);
	assign divIssueValidInner = divRsIssueOutputInner[178];
	assign divIssueOpInner = divRsIssueOutputInner[177-:6];
	assign divIssueTagInner = divRsIssueOutputInner[171-:5];
	assign divIssuePhyInner = divRsIssueOutputInner[166-:6];
	assign divIssueS1Inner = divRsIssueOutputInner[160-:32];
	assign divIssueS2Inner = divRsIssueOutputInner[128-:32];
	assign divIssueImmInner = divRsIssueOutputInner[96-:32];
	assign divIssuePcInner = divRsIssueOutputInner[64-:32];
	assign divIssuePredInner = divRsIssueOutputInner[32-:32];
	assign divIssueUseImmInner = divRsIssueOutputInner[0];
	localparam [31:0] sv2v_uu_u_branch_rs_ISSUE_WIDTH = 1;
	localparam [0:0] sv2v_uu_u_branch_rs_ext_issueLaneReadyInput_0 = 1'sb0;
	rv32_rs #(
		.DEPTH(rv32_pkg_BRANCH_RS_ENTRIES),
		.AUX_W(3),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.REUSE_ON_ISSUE(1'b0),
		.WB_ISSUE_BYPASS(1'b1),
		.CREDIT_FIT_SIDEBAND(1'b1),
		.SEPARATE_ISSUE_WB(1'b1)
	) u_branch_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(branchRsAllocInputInner),
		.allocReadyOutput(branchAllocReadyInner),
		.allocAuxInput({1'b0, issueIsReturnInner, issueIsCallInner}),
		.allocSecondInput(branchRsAllocSecondInputInner),
		.allocSecondReadyOutput(branchAllocSecondReadyInner),
		.allocSecondAuxInput(3'b000),
		.allocLanesInput(wideRsAllocInner[2316+:772]),
		.allocLanesAuxInput(wideBranchAuxInner),
		.allocLanesFireOutput(wideRsFireInner[12+:4]),
		.allocCreditsOutput(wideBranchCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[15+:5]),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(branchIssueWritebackInner),
		.issueOutput(branchRsIssueOutputInner),
		.issueReadyInput(branchIssueReadyInner),
		.issueAuxOutput(branchIssueAuxInner),
		.occupancyOutput(unusedBranchOccupancyInner),
		.issueLaneValidOutput(unusedBranchIssueLaneValidInner),
		.issueLaneOutput(unusedBranchIssueLaneInner),
		.issueLaneAuxOutput(unusedBranchIssueLaneAuxInner),
		.issueLaneReadyInput(sv2v_uu_u_branch_rs_ext_issueLaneReadyInput_0)
	);
	assign branchIssueValidInner = branchRsIssueOutputInner[178];
	assign branchIssueOpInner = branchRsIssueOutputInner[177-:6];
	assign branchIssueTagInner = branchRsIssueOutputInner[171-:5];
	assign branchIssuePhyInner = branchRsIssueOutputInner[166-:6];
	assign branchIssueS1Inner = branchRsIssueOutputInner[160-:32];
	assign branchIssueS2Inner = branchRsIssueOutputInner[128-:32];
	assign branchIssueImmInner = branchRsIssueOutputInner[96-:32];
	assign branchIssuePcInner = branchRsIssueOutputInner[64-:32];
	assign branchIssuePredInner = branchRsIssueOutputInner[32-:32];
	assign branchIssueUseImmInner = branchRsIssueOutputInner[0];
	function automatic [1:0] sv2v_cast_98BC2;
		input reg [1:0] inp;
		sv2v_cast_98BC2 = inp;
	endfunction
	localparam [31:0] sv2v_uu_u_load_rs_ISSUE_WIDTH = 1;
	localparam [0:0] sv2v_uu_u_load_rs_ext_issueLaneReadyInput_0 = 1'sb0;
	rv32_rs #(
		.DEPTH(rv32_pkg_LOAD_RS_ENTRIES),
		.AUX_W(3),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.REUSE_ON_ISSUE(1'b0),
		.WB_ISSUE_BYPASS(1'b1),
		.SELECTIVE_WAKE_PIPE(1'b1)
	) u_load_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(loadRsAllocInputInner),
		.allocReadyOutput(loadRsAllocReadyInner),
		.allocAuxInput({1'b0, sv2v_cast_98BC2(lqAllocIndexInner)}),
		.allocSecondInput(loadRsAllocSecondInputInner),
		.allocSecondReadyOutput(loadRsAllocSecondReadyInner),
		.allocSecondAuxInput({1'b0, sv2v_cast_98BC2(lqAllocSecondIndexInner)}),
		.allocLanesInput(wideRsAllocInner[3088+:772]),
		.allocLanesAuxInput(wideLoadAuxInner),
		.allocLanesFireOutput(wideRsFireInner[16+:4]),
		.allocCreditsOutput(wideLoadRsCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[20+:5]),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(writebackInputInner),
		.issueOutput(loadRsIssueOutputInner),
		.issueReadyInput(loadRsIssueReadyInner),
		.issueAuxOutput(loadAuxInner),
		.occupancyOutput(unusedLoadOccupancyInner),
		.issueLaneValidOutput(unusedLoadIssueLaneValidInner),
		.issueLaneOutput(unusedLoadIssueLaneInner),
		.issueLaneAuxOutput(unusedLoadIssueLaneAuxInner),
		.issueLaneReadyInput(sv2v_uu_u_load_rs_ext_issueLaneReadyInput_0)
	);
	localparam [31:0] sv2v_uu_u_store_addr_rs_ISSUE_WIDTH = 1;
	localparam [0:0] sv2v_uu_u_store_addr_rs_ext_issueLaneReadyInput_0 = 1'sb0;
	rv32_rs #(
		.DEPTH(rv32_pkg_STORE_ADDR_RS_ENTRIES),
		.AUX_W(3),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.REUSE_ON_ISSUE(1'b0),
		.WB_ISSUE_BYPASS(1'b1),
		.SELECTIVE_WAKE_PIPE(1'b1)
	) u_store_addr_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(saRsAllocInputInner),
		.allocReadyOutput(saRsAllocReadyInner),
		.allocAuxInput({1'b1, sv2v_cast_98BC2(sqAllocIndexInner)}),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(writebackInputInner),
		.allocSecondInput(saRsAllocSecondInputInner),
		.allocSecondReadyOutput(saRsAllocSecondReadyInner),
		.allocSecondAuxInput({1'b1, sv2v_cast_98BC2(sqAllocSecondIndexInner)}),
		.allocLanesInput(wideRsAllocInner[3860+:772]),
		.allocLanesAuxInput(wideSaAuxInner),
		.allocLanesFireOutput(wideRsFireInner[20+:4]),
		.allocCreditsOutput(wideSaCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[25+:5]),
		.issueOutput(saRsIssueOutputInner),
		.issueReadyInput(saRsIssueReadyInner),
		.issueAuxOutput(saAuxInner),
		.occupancyOutput(unusedSaOccupancyInner),
		.issueLaneValidOutput(unusedSaIssueLaneValidInner),
		.issueLaneOutput(unusedSaIssueLaneInner),
		.issueLaneAuxOutput(unusedSaIssueLaneAuxInner),
		.issueLaneReadyInput(sv2v_uu_u_store_addr_rs_ext_issueLaneReadyInput_0)
	);
	localparam [31:0] sv2v_uu_u_store_value_rs_ISSUE_WIDTH = rv32_pkg_STORE_VALUE_RS_ENTRIES;
	localparam [1:0] sv2v_uu_u_store_value_rs_ext_issueLaneReadyInput_0 = 1'sb0;
	rv32_rs #(
		.DEPTH(rv32_pkg_STORE_VALUE_RS_ENTRIES),
		.AUX_W(rv32_pkg_SQ_SLOT_W),
		.ISSUE_WIDTH(rv32_pkg_STORE_VALUE_RS_ENTRIES),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.REUSE_ON_ISSUE(1'b0),
		.WB_ISSUE_BYPASS(1'b1),
		.WB_ISSUE_PORTS(rv32_pkg_ALU_CDB_PORTS)
	) u_store_value_rs(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.allocInput(svRsAllocInputInner),
		.allocReadyOutput(svRsAllocReadyInner),
		.allocAuxInput(sqAllocIndexInner),
		.writebackInput(writebackInputInner),
		.issueWritebackInput(svEarlyWritebackInner),
		.allocSecondInput(svRsAllocSecondInputInner),
		.allocSecondReadyOutput(svRsAllocSecondReadyInner),
		.allocSecondAuxInput(sqAllocSecondIndexInner),
		.allocLanesInput(wideRsAllocInner[4632+:772]),
		.allocLanesAuxInput(wideSvAuxInner),
		.allocLanesFireOutput(wideRsFireInner[24+:4]),
		.allocCreditsOutput(wideSvCreditsInner),
		.allocCreditFitsOutput(unusedCreditFitsInner[30+:5]),
		.issueOutput(svRsIssueOutputInner),
		.issueReadyInput(!globalFlushInner || rv32_pkg_rob_is_older(svRsIssueOutputInner[171-:5], globalFlushTagInner)),
		.issueAuxOutput(svAuxInner),
		.occupancyOutput(unusedSvOccupancyInner),
		.issueLaneValidOutput(svRsIssueLaneValidInner),
		.issueLaneOutput(svRsIssueLaneInner),
		.issueLaneAuxOutput(svRsIssueLaneAuxInner),
		.issueLaneReadyInput(sv2v_uu_u_store_value_rs_ext_issueLaneReadyInput_0)
	);
	assign chooseLoadInner = loadRsIssueOutputInner[178] && (!saRsIssueOutputInner[178] || rv32_pkg_rob_is_older(loadRsIssueOutputInner[171-:5], saRsIssueOutputInner[171-:5]));
	assign memRsIssueOutputInner = (chooseLoadInner ? loadRsIssueOutputInner : saRsIssueOutputInner);
	assign memIssueAuxInner = (chooseLoadInner ? loadAuxInner : saAuxInner);
	assign loadRsIssueReadyInner = memIssueReadyInner && chooseLoadInner;
	assign saRsIssueReadyInner = memIssueReadyInner && !chooseLoadInner;
	always @* begin : route_integer_dispatch
		reg signed [31:0] candidate;
		candidate = 0;
		intIssueLaneReadyInner = 1'sb0;
		begin : sv2v_autoblock_4
			reg signed [31:0] unitIndex;
			for (unitIndex = 0; unitIndex < ALU_LANES; unitIndex = unitIndex + 1)
				begin
					aluLaneRequestInner[unitIndex] = 1'sb0;
					if ((!pipelineFrozenInner && aluInputReadyInner[unitIndex]) && (candidate < ALU_LANES)) begin
						aluLaneRequestInner[unitIndex] = {intIssueLaneValidInner[candidate], sv2v_cast_6(intIssueLaneInner[((1 - candidate) * 179) + 177-:6]), sv2v_cast_32(intIssueLaneInner[((1 - candidate) * 179) + 160-:32]), sv2v_cast_32(intIssueLaneInner[((1 - candidate) * 179) + 128-:32]), sv2v_cast_32(intIssueLaneInner[((1 - candidate) * 179) + 96-:32]), sv2v_cast_32(intIssueLaneInner[((1 - candidate) * 179) + 64-:32]), sv2v_cast_32(intIssueLaneInner[((1 - candidate) * 179) + 32-:32]), intIssueLaneInner[((1 - candidate) * 179) + 0], sv2v_cast_60734(intIssueLaneInner[((1 - candidate) * 179) + 171-:5]), sv2v_cast_A32BA(intIssueLaneInner[((1 - candidate) * 179) + 166-:6]), intIssueLaneAuxInner[1 - candidate], 2'b00};
						intIssueLaneReadyInner[candidate] = 1'b1;
						candidate = candidate + 1;
					end
				end
		end
	end
	assign intIssueReadyInner = intIssueLaneReadyInner[0];
	genvar _gv_unitIndex_1;
	localparam [31:0] rv32_pkg_ALU_RESULT_ENTRIES = 1;
	generate
		for (_gv_unitIndex_1 = 0; _gv_unitIndex_1 < ALU_LANES; _gv_unitIndex_1 = _gv_unitIndex_1 + 1) begin : g_alu_units
			localparam unitIndex = _gv_unitIndex_1;
			wire [0:0] unusedOccupancyInner;
			assign aluIssueFireInner[unitIndex] = aluLaneRequestInner[unitIndex][181] && aluInputReadyInner[unitIndex];
			rv32_alu_unit #(.DEPTH(rv32_pkg_ALU_RESULT_ENTRIES)) u_alu_unit(
				.freezeInput(pipelineFrozenInner),
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
				.executeInput(aluLaneRequestInner[unitIndex]),
				.inReadyOutput(aluInputReadyInner[unitIndex]),
				.outReadyInput(aluPopReadyInner[unitIndex]),
				.executeOutput(aluLaneResultInner[unitIndex]),
				.occupancyOutput(unusedOccupancyInner)
			);
		end
	endgenerate
	function automatic [181:0] sv2v_cast_36163;
		input reg [181:0] inp;
		sv2v_cast_36163 = inp;
	endfunction
	rv32_mul u_mul_unit(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.executeInput(sv2v_cast_36163({mulIssueValidInner, mulIssueOpInner, mulIssueS1Inner, mulIssueS2Inner, mulIssueImmInner, mulIssuePcInner, mulIssuePredInner, mulIssueUseImmInner, sv2v_cast_60734(mulIssueTagInner), sv2v_cast_A32BA(mulIssuePhyInner), 3'b000})),
		.inReadyOutput(mulIssueReadyInner),
		.outReadyInput(wbMulValidInner),
		.executeOutput(mulExecuteOutputInner)
	);
	rv32_div u_div_unit(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.executeInput(sv2v_cast_36163({divIssueValidInner, divIssueOpInner, divIssueS1Inner, divIssueS2Inner, divIssueImmInner, divIssuePcInner, divIssuePredInner, 1'b0, sv2v_cast_60734(divIssueTagInner), sv2v_cast_A32BA(divIssuePhyInner), 3'b000})),
		.inReadyOutput(divIssueReadyInner),
		.outReadyInput(wbDivValidInner),
		.executeOutput(divExecuteOutputInner)
	);
	rv32_bru_unit #(.CONDITIONAL_ONLY(1'b1)) u_bru_unit(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInput(globalFlushInner),
		.flushTagInput(globalFlushTagInner),
		.executeInput(sv2v_cast_36163({branchIssueValidInner, branchIssueOpInner, branchIssueS1Inner, branchIssueS2Inner, branchIssueImmInner, branchIssuePcInner, branchIssuePredInner, branchIssueUseImmInner, sv2v_cast_60734(branchIssueTagInner), sv2v_cast_A32BA(branchIssuePhyInner), 1'b0, branchIssueAuxInner[0], branchIssueAuxInner[1]})),
		.inReadyOutput(branchIssueReadyInner),
		.executeOutput(bruExecuteOutputInner)
	);
	rv32_agu_unit u_agu_unit(
		.freezeInput(pipelineFrozenInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.executeInput(memRsIssueOutputInner),
		.auxiliaryInput(memIssueAuxInner),
		.inReadyOutput(memIssueReadyInner),
		.addressOutput(aguAddressOutputInner),
		.auxiliaryOutput(aguResultAuxInner),
		.robTagOutput(unusedAguRobTagInner)
	);
	always @* begin
		lsuAddressInputInner = aguAddressOutputInner;
		lsuAddressInputInner[38] = aguAddressOutputInner[38] && !recoveryBusyInner;
	end
	rv32_lsu #(
		.STORE_DATA_LANES(rv32_pkg_STORE_VALUE_RS_ENTRIES),
		.TAGGED_DMEM(TAGGED_DMEM),
		.RESPONSE_PREVIEW(1'b1),
		.WRITEBACK_PORTS(rv32_pkg_WRITEBACK_PORTS),
		.COMMIT_WIDTH(COMMIT_WIDTH),
		.RENAME_WIDTH(ISSUE_WIDTH)
	) u_lsu(
		.coreStoppedInput(haltedInner),
		.loadYieldEnableInput((bootDoneInner && !pipelineFrozenInner) && !globalFlushInner),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.flushInfoInput(sv2v_cast_002AA({globalFlushInner, sv2v_cast_60734(globalFlushTagInner)})),
		.loadAllocationInput(lsuLoadAllocationInputInner),
		.loadAllocReadyOutput(lqAllocReadyInner),
		.loadAllocIndexOutput(lqAllocIndexInner),
		.loadAllocationSecondInput(lsuLoadAllocationSecondInputInner),
		.loadAllocSecondReadyOutput(lqAllocSecondReadyInner),
		.loadAllocSecondIndexOutput(lqAllocSecondIndexInner),
		.storeAllocationInput(lsuStoreAllocationInputInner),
		.storeAllocReadyOutput(sqAllocReadyInner),
		.storeAllocIndexOutput(sqAllocIndexInner),
		.storeAllocationSecondInput(lsuStoreAllocationSecondInputInner),
		.storeAllocSecondReadyOutput(sqAllocSecondReadyInner),
		.storeAllocSecondIndexOutput(sqAllocSecondIndexInner),
		.loadAllocationLanesInput(wideLoadAllocInner),
		.storeAllocationLanesInput(wideStoreAllocInner),
		.loadAllocationLanesFireOutput(wideLoadFireInner),
		.storeAllocationLanesFireOutput(wideStoreFireInner),
		.loadPreviewIndexOutput(wideLoadPreviewInner),
		.storePreviewIndexOutput(wideStorePreviewInner),
		.loadCreditsOutput(wideLoadCreditsInner),
		.storeCreditsOutput(wideStoreCreditsInner),
		.storeDataInput(svRsStoreDataInner),
		.storeDataIndexInput(svRsStoreDataIndexInner),
		.addressInput(lsuAddressInputInner),
		.addressIndexInput(aguResultAuxInner[1:0]),
		.writebackInput(writebackInputInner),
		.loadResultOutput(lsuLoadResultOutputInner),
		.loadResultReadyInput(wbLoadValidInner),
		.loadIdentityInput(loadIdentityInner),
		.loadWinnerIdentityOutput(loadWinnerIdentityInner),
		.robRetireInput(retirementInputInner),
		.storeCompleteOutput(lsuStoreCompleteOutputInner),
		.storeCommitInput(retirementStoreInputInner),
		.storeCommitIndexInput(retirementSqIndexInner),
		.storeCommitReadyOutput(retirementStoreReadyInner),
		.storeRetirementOutput(retirementMemoryInner),
		.storeRetirementExitOutput(retirementExitInner),
		.storeHeadSetPreviewOutput(dmemStoreSetPreviewOutput),
		.dmemRequestOutput(lsuDmemRequestOutputInner),
		.dmemReqReadyInput(dmemReqReadyInput),
		.dmemResponseInput(lsuDmemResponseInputInner),
		.dmemReqTransactionOutput(dmemReqTransactionOutput),
		.dmemRspTransactionInput(dmemRspTransactionInput),
		.responsePreviewTransactionInput(responsePreviewTransactionInput),
		.responsePreviewSelectInput(responsePreviewSelectInput),
		.lqCountOutput(unusedLqCountInner),
		.sqCountOutput(sqCountInner)
	);
	function automatic [5:0] sv2v_cast_3906B;
		input reg [5:0] inp;
		sv2v_cast_3906B = inp;
	endfunction
	generate
		if (ISSUE_WIDTH == 2) begin : g_dual_rename
			wire raw1;
			wire raw2;
			wire unusedLinkCarry;
			rv32_add #(.WIDTH(32)) u_second_link_add(
				.aInput(decodedSecondInner[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]),
				.bInput(32'd4),
				.cinInput(1'b0),
				.sumOutput(issueSecondLinkValueInner),
				.coutOutput(unusedLinkCarry)
			);
			assign ratReadSecondInputInner = {sv2v_cast_5(decodedSecondInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_5(decodedSecondInner[137 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])};
			assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 2 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 2)) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(ratReadSecondOutputInner[11-:6])};
			assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 3 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 3)) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(ratReadSecondOutputInner[5-:rv32_pkg_PHY_TAG_W])};
			assign issueSecondIsJumpInner = (decodedSecondInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd27) || (decodedSecondInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28);
			assign issueSecondIsReturnInner = ((decodedSecondInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28) && ((decodedSecondInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 1) || (decodedSecondInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 5))) && (decodedSecondInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != decodedSecondInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
			assign issueSecondDestPhyInner = (decodedSecondInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] ? prfAllocSecondPhyInner : {rv32_pkg_PHY_TAG_W {1'sb0}});
			assign raw1 = (ratRenameInputInner[11] && decodedSecondInner[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)]) && (decodedSecondInner[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
			assign raw2 = (ratRenameInputInner[11] && decodedSecondInner[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)]) && (decodedSecondInner[137 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
			assign issueSecondSrc1PhyInner = (raw1 ? issueDestPhyInner : ratReadSecondOutputInner[11-:6]);
			assign issueSecondSrc2PhyInner = (raw2 ? issueDestPhyInner : ratReadSecondOutputInner[5-:rv32_pkg_PHY_TAG_W]);
			assign issueSecondSrc1ReadyInner = !decodedSecondInner[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] || (raw1 ? issueIsJumpInner : prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 2 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 2)) * 33) + 32]);
			assign issueSecondSrc2ReadyInner = !decodedSecondInner[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] || (raw2 ? issueIsJumpInner : prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 3 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 3)) * 33) + 32]);
			assign issueSecondSrc1ValueInner = (!decodedSecondInner[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] ? 32'b00000000000000000000000000000000 : (raw1 ? (issueIsJumpInner ? issueLinkValueInner : 32'b00000000000000000000000000000000) : prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 2 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 2)) * 33) + 31-:32]));
			assign issueSecondSrc2ValueInner = (!decodedSecondInner[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] ? 32'b00000000000000000000000000000000 : (raw2 ? (issueIsJumpInner ? issueLinkValueInner : 32'b00000000000000000000000000000000) : prfReadOutputInner[(((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 3 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 3)) * 33) + 31-:32]));
			assign ratSecondOldPhyInner = (ratRenameInputInner[11] && (decodedSecondInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == decodedInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]) ? issueDestPhyInner : ratRenameSecondOutputInner[5-:rv32_pkg_PHY_TAG_W]);
			always @* begin
				targetSecondRsReadyInner = 1'b1;
				case (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])
					4'd1: targetSecondRsReadyInner = intAllocSecondReadyInner;
					4'd2: targetSecondRsReadyInner = mulAllocSecondReadyInner;
					4'd3: targetSecondRsReadyInner = divAllocSecondReadyInner;
					4'd4: targetSecondRsReadyInner = branchAllocSecondReadyInner;
					4'd5: targetSecondRsReadyInner = loadRsAllocSecondReadyInner && lqAllocSecondReadyInner;
					4'd6: targetSecondRsReadyInner = (saRsAllocSecondReadyInner && svRsAllocSecondReadyInner) && sqAllocSecondReadyInner;
					default: targetSecondRsReadyInner = 1'b1;
				endcase
			end
			assign issueSecondResourcesReadyInner = (robAllocSecondReadyInner && targetSecondRsReadyInner) && (!decodedSecondInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] || prfAllocSecondReadyInner);
			assign issueSecondFireInner = ((issueFireInner && !decodedInner[158 + (rv32_pkg_BPU_CKPT_ID_W + 2)]) && frontendSecondInstructionInner[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0]) && issueSecondResourcesReadyInner;
			assign ratRenameSecondInputInner = {issueSecondFireInner && decodedSecondInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)], sv2v_cast_5(decodedSecondInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_A32BA(prfAllocSecondPhyInner)};
			assign prfAllocSecondInputInner = {issueSecondFireInner && decodedSecondInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)], issueSecondIsJumpInner, issueSecondLinkValueInner};
			assign robAllocSecondInputInner = {issueSecondFireInner, sv2v_cast_32(decodedSecondInner[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondInner[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), decodedSecondInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)], sv2v_cast_5(decodedSecondInner[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_A32BA(issueSecondDestPhyInner), sv2v_cast_A32BA(ratSecondOldPhyInner), decodedSecondInner[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] && (ratSecondOldPhyInner != 1'b0), decodedSecondInner[158 + (rv32_pkg_BPU_CKPT_ID_W + 2)], decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6, sv2v_cast_FD44F(sqAllocSecondIndexInner), decodedSecondInner[158 + (rv32_pkg_BPU_CKPT_ID_W + 2)], 1'b0, sv2v_cast_32(decodedSecondInner[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedSecondInner[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))]), issueSecondIsReturnInner};
			assign lsuLoadAllocationSecondInputInner = {issueSecondFireInner && (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd5), sv2v_cast_60734(robAllocSecondTagInner), sv2v_cast_A32BA(issueSecondDestPhyInner), sv2v_cast_2(decodedSecondInner[2-:2]), decodedSecondInner[0]};
			assign lsuStoreAllocationSecondInputInner = {issueSecondFireInner && (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6), sv2v_cast_60734(robAllocSecondTagInner), sv2v_cast_2(decodedSecondInner[2-:2]), 1'b0, sv2v_cast_3906B(1'sb0), 32'b00000000000000000000000000000000};
			always @* begin
				rsAllocSecondBaseInner = {issueSecondFireInner, sv2v_cast_6(decodedSecondInner[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_60734(robAllocSecondTagInner), sv2v_cast_A32BA(issueSecondDestPhyInner), issueSecondSrc1ReadyInner, sv2v_cast_A32BA(issueSecondSrc1PhyInner), issueSecondSrc1ValueInner, issueSecondSrc2ReadyInner, sv2v_cast_A32BA(issueSecondSrc2PhyInner), issueSecondSrc2ValueInner, sv2v_cast_32(decodedSecondInner[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondInner[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondInner[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), decodedSecondInner[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)]};
				intRsAllocSecondInputInner = rsAllocSecondBaseInner;
				intRsAllocSecondInputInner[192] = issueSecondFireInner && (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd1);
				mulRsAllocSecondInputInner = rsAllocSecondBaseInner;
				mulRsAllocSecondInputInner[192] = issueSecondFireInner && (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd2);
				mulRsAllocSecondInputInner[0] = 1'b0;
				divRsAllocSecondInputInner = rsAllocSecondBaseInner;
				divRsAllocSecondInputInner[192] = issueSecondFireInner && (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd3);
				divRsAllocSecondInputInner[0] = 1'b0;
				branchRsAllocSecondInputInner = rsAllocSecondBaseInner;
				branchRsAllocSecondInputInner[192] = issueSecondFireInner && (decodedSecondInner[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd4);
				loadRsAllocSecondInputInner = rsAllocSecondBaseInner;
				loadRsAllocSecondInputInner[192] = lsuLoadAllocationSecondInputInner[14];
				loadRsAllocSecondInputInner[135] = 1'b1;
				loadRsAllocSecondInputInner[134-:6] = 1'sb0;
				loadRsAllocSecondInputInner[128-:32] = 1'sb0;
				loadRsAllocSecondInputInner[0] = 1'b1;
				saRsAllocSecondInputInner = loadRsAllocSecondInputInner;
				saRsAllocSecondInputInner[192] = lsuStoreAllocationSecondInputInner[46];
				svRsAllocSecondInputInner = rsAllocSecondBaseInner;
				svRsAllocSecondInputInner[192] = lsuStoreAllocationSecondInputInner[46];
				svRsAllocSecondInputInner[174] = issueSecondSrc2ReadyInner;
				svRsAllocSecondInputInner[173-:6] = issueSecondSrc2PhyInner;
				svRsAllocSecondInputInner[167-:32] = issueSecondSrc2ValueInner;
				svRsAllocSecondInputInner[135] = 1'b1;
				svRsAllocSecondInputInner[134-:6] = 1'sb0;
				svRsAllocSecondInputInner[128-:32] = 1'sb0;
				svRsAllocSecondInputInner[0] = 1'b0;
			end
		end
		else begin : g_single_rename
			assign issueSecondFireInner = (ISSUE_WIDTH == 4 ? wideFireInner[1] : 1'b0);
			assign issueSecondResourcesReadyInner = 1'b0;
			wire [1:1] sv2v_tmp_76896;
			assign sv2v_tmp_76896 = 1'b0;
			always @(*) targetSecondRsReadyInner = sv2v_tmp_76896;
			assign issueSecondIsJumpInner = 1'b0;
			assign issueSecondIsReturnInner = 1'b0;
			assign issueSecondLinkValueInner = 1'sb0;
			assign issueSecondSrc1PhyInner = 1'sb0;
			assign issueSecondSrc2PhyInner = 1'sb0;
			assign issueSecondDestPhyInner = 1'sb0;
			assign issueSecondSrc1ReadyInner = 1'b0;
			assign issueSecondSrc2ReadyInner = 1'b0;
			assign issueSecondSrc1ValueInner = 1'sb0;
			assign issueSecondSrc2ValueInner = 1'sb0;
			assign ratSecondOldPhyInner = 1'sb0;
			assign ratReadSecondInputInner = 1'sb0;
			assign ratRenameSecondInputInner = 1'sb0;
			assign prfAllocSecondInputInner = 1'sb0;
			assign robAllocSecondInputInner = 1'sb0;
			assign lsuLoadAllocationSecondInputInner = 1'sb0;
			assign lsuStoreAllocationSecondInputInner = 1'sb0;
			wire [193:1] sv2v_tmp_59036;
			assign sv2v_tmp_59036 = 1'sb0;
			always @(*) rsAllocSecondBaseInner = sv2v_tmp_59036;
			wire [193:1] sv2v_tmp_3643A;
			assign sv2v_tmp_3643A = 1'sb0;
			always @(*) intRsAllocSecondInputInner = sv2v_tmp_3643A;
			wire [193:1] sv2v_tmp_751BD;
			assign sv2v_tmp_751BD = 1'sb0;
			always @(*) mulRsAllocSecondInputInner = sv2v_tmp_751BD;
			wire [193:1] sv2v_tmp_1CD82;
			assign sv2v_tmp_1CD82 = 1'sb0;
			always @(*) divRsAllocSecondInputInner = sv2v_tmp_1CD82;
			wire [193:1] sv2v_tmp_4421A;
			assign sv2v_tmp_4421A = 1'sb0;
			always @(*) branchRsAllocSecondInputInner = sv2v_tmp_4421A;
			wire [193:1] sv2v_tmp_61B7E;
			assign sv2v_tmp_61B7E = 1'sb0;
			always @(*) loadRsAllocSecondInputInner = sv2v_tmp_61B7E;
			wire [193:1] sv2v_tmp_002C8;
			assign sv2v_tmp_002C8 = 1'sb0;
			always @(*) saRsAllocSecondInputInner = sv2v_tmp_002C8;
			wire [193:1] sv2v_tmp_CCF2F;
			assign sv2v_tmp_CCF2F = 1'sb0;
			always @(*) svRsAllocSecondInputInner = sv2v_tmp_CCF2F;
			assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 2 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 2)) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = 1'sb0;
			assign prfReadInputInner[((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 3 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 3)) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = 1'sb0;
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			haltedInner <= 1'b0;
		else begin : sv2v_autoblock_5
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (retirementFireInner[lane]) begin
					if (robCommitOutputInner[(lane * 93) + 1] || (retirementStoreInner[lane] && retirementExitInner[lane]))
						haltedInner <= 1'b1;
				end
		end
	generate
		if (((FETCH_WIDTH != 1) && (FETCH_WIDTH != 2)) && (FETCH_WIDTH != 4)) begin : g_invalid_fetch_width
			initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
		end
		if (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
		end
		if ((COMMIT_WIDTH == 4) && (ISSUE_WIDTH != 4)) begin : g_invalid_four_commit_backend
			initial $fatal(1, "four-commit requires the array four-allocation backend");
		end
		if (((ISSUE_WIDTH != 1) && (ISSUE_WIDTH != 2)) && (ISSUE_WIDTH != 4)) begin : g_invalid_issue_width
			initial $fatal(1, "ISSUE_WIDTH must be 1, 2 or 4");
		end
	endgenerate
`ifndef SYNTHESIS
	genvar _gv_unitIndex_2;
	generate
		for (_gv_unitIndex_2 = 0; _gv_unitIndex_2 < ALU_LANES; _gv_unitIndex_2 = _gv_unitIndex_2 + 1) begin : g_alu_hold_check
			localparam unitIndex = _gv_unitIndex_2;
			reg held;
			reg [45:0] previous;
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput) begin
					held <= 0;
					previous <= 1'sb0;
				end
				else begin
					if (held)
						assert (aluLaneResultInner[unitIndex] == previous) else $fatal(1, "ungranted ALU result was lost or changed");
					held <= (aluLaneResultInner[unitIndex][45] && (pipelineFrozenInner || !aluPopReadyInner[unitIndex])) && !(globalFlushInner && !rv32_pkg_rob_is_older(aluLaneResultInner[unitIndex][12-:5], globalFlushTagInner));
					previous <= aluLaneResultInner[unitIndex];
				end
		end
	endgenerate
	always @(posedge clkInput)
		if (rstNInput) begin
			assert ($countones(aluIssueFireInner) == $countones(u_int_rs.issueAcceptInner)) else $fatal(1, "ALU dispatch and real RS departures disagree");
			begin : sv2v_autoblock_6
				reg signed [31:0] lane;
				for (lane = 0; lane < ALU_LANES; lane = lane + 1)
					assert (writebackInputInner[(lane * 39) + 38] == (aluResultGrantInner[lane] && !aluLaneResultInner[lane][1])) else $fatal(1, "independent ALU grant did not reach its own CDB");
			end
			if (&aluResultGrantInner)
				assert (!(aluLaneResultInner[0][1] && aluLaneResultInner[1][1])) else $fatal(1, "two jump results consumed one predictor port");
			begin : sv2v_autoblock_7
				reg signed [31:0] portIndex;
				for (portIndex = 0; portIndex < rv32_pkg_WRITEBACK_PORTS; portIndex = portIndex + 1)
					begin : sv2v_autoblock_8
						reg signed [31:0] peer;
						for (peer = 0; peer < portIndex; peer = peer + 1)
							assert (((!writebackInputInner[(portIndex * 39) + 38] || !writebackInputInner[(peer * 39) + 38]) || (writebackInputInner[(portIndex * 39) + 37-:6] == 0)) || (writebackInputInner[(portIndex * 39) + 37-:6] != writebackInputInner[(peer * 39) + 37-:6])) else $fatal(1, "independent CDBs broadcast duplicate live physical identity");
					end
			end
		end
	always @(posedge clkInput)
		if (rstNInput && !haltedInner) begin
			if (ISSUE_WIDTH == 4) begin
				begin : sv2v_autoblock_9
					reg signed [31:0] pool;
					for (pool = 0; pool < 7; pool = pool + 1)
						begin : sv2v_autoblock_10
							reg signed [31:0] lane;
							for (lane = 0; lane < 4; lane = lane + 1)
								assert (wideRsFireInner[(pool * 4) + lane] == wideRsAllocInner[(((pool * 4) + lane) * 193) + 192]) else $fatal(1, "four rename RS pool did not accept common allocation");
						end
				end
				begin : sv2v_autoblock_11
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						begin
							assert ((wideLoadFireInner[lane] == wideLoadAllocInner[(lane * 15) + 14]) && (wideStoreFireInner[lane] == wideStoreAllocInner[(lane * 47) + 46])) else $fatal(1, "four rename LSQ did not accept common allocation");
							if (lane > 0)
								assert (!wideFireInner[lane] || wideFireInner[lane - 1]) else $fatal(1, "four rename did not form a contiguous prefix");
						end
				end
			end
			assert (!issueSecondFireInner || issueFireInner) else $fatal(1, "rename lanes did not form an ordered prefix");
			if (ratRenameInputInner[11] && ratRenameSecondInputInner[11])
				assert (issueDestPhyInner != issueSecondDestPhyInner) else $fatal(1, "rename lanes share one destination physical register");
			if (globalFlushInner)
				assert (retirementFireInner == {COMMIT_WIDTH {1'sb0}}) else $fatal(1, "architectural SRAM read competed with retirement");
			if (recoveryBusyInner) begin
				if (predictorFetchAcceptInner)
					assert (((((FETCH_WIDTH == 2) && !LEGACY_HALT) && imemFetchHintInput[4]) && !imemFetchHintInput[3]) && !imemFetchHintInput[2]) else $fatal(1, "recovery prefetch consumed unknown/control packet");
				assert (!predictorFetchInfoInner[67]) else $fatal(1, "RAS fetch update overlapped architectural replay");
				assert (((((!globalFlushInner && !issueFireInner) && !robCommitFireInner) && !(|writebackValidInner)) && !branchResultLiveInner) && !lsuAddressInputInner[38]) else $fatal(1, "pipeline consumed work during recovery");
				assert (robHeadTagInner == (recoveryStepInner[14-:5] - recoveryStepInner[19-:5])) else $fatal(1, "ROB head moved during recovery");
				assert (robCountInner == ((recoveryStepInner[9-:5] - robHeadTagInner) + sv2v_cast_60734(1))) else $fatal(1, "ROB recovery window changed during replay");
			end
		end
`endif
endmodule
module rv32_recovery_cursor (
	clkInput,
	rstNInput,
	freezeInput,
	startInput,
	headTagInput,
	squashTagInput,
	countInput,
	stepOutput
);
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire startInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [4:0] headTagInput;
	input wire [4:0] squashTagInput;
	input wire [4:0] countInput;
	output wire [22:0] stepOutput;
	reg activeInner;
	reg [1:0] beatInner;
	reg [4:0] offsetInner;
	reg [4:0] nextTagInner;
	reg [4:0] squashTagInner;
	reg [4:0] countInner;
	wire lastBeatInner;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	assign lastBeatInner = (offsetInner + sv2v_cast_60734(rv32_pkg_RECOVERY_WIDTH)) >= countInner;
	assign stepOutput = {activeInner, beatInner == 32'sd0, lastBeatInner, sv2v_cast_60734(offsetInner), sv2v_cast_60734(nextTagInner), sv2v_cast_60734(squashTagInner), sv2v_cast_60734(countInner)};
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			activeInner <= 1'b0;
			beatInner <= 1'sb0;
			offsetInner <= 1'sb0;
			nextTagInner <= 1'sb0;
			squashTagInner <= 1'sb0;
			countInner <= 1'sb0;
		end
		else if (!freezeInput) begin
			if (startInput && !activeInner) begin
				activeInner <= 1'b1;
				beatInner <= 1'sb0;
				offsetInner <= 1'sb0;
				nextTagInner <= headTagInput;
				squashTagInner <= squashTagInput;
				countInner <= sv2v_cast_60734(countInput);
			end
			else if (activeInner) begin
				nextTagInner <= nextTagInner + sv2v_cast_60734(rv32_pkg_RECOVERY_WIDTH);
				offsetInner <= offsetInner + sv2v_cast_60734(rv32_pkg_RECOVERY_WIDTH);
				if (lastBeatInner)
					activeInner <= 1'b0;
				else
					beatInner <= beatInner + 2'd1;
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput && !freezeInput) begin
			assert (!(startInput && activeInner)) else $fatal(1, "nested recovery start");
			if (startInput)
				assert ((countInput != 0) && ((squashTagInput - headTagInput) < sv2v_cast_60734(countInput))) else $fatal(1, "recovery boundary outside live ROB window");
		end
`endif
endmodule
module rv32_flush_arbiter (
	clkInput,
	rstNInput,
	freezeInput,
	branchInput,
	jumpInput,
	squashOutput
);
	parameter [31:0] DEPTH = 4;
	parameter [0:0] SORTED_HEAD_SELECT = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] branchInput;
	input wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] jumpInput;
	output reg [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] squashOutput;
	reg validInner [0:DEPTH - 1];
	reg [4:0] tagInner [0:DEPTH - 1];
	reg [31:0] pcInner [0:DEPTH - 1];
	reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] ckptIdInner [0:DEPTH - 1];
	reg validNext [0:DEPTH - 1];
	reg [4:0] tagNext [0:DEPTH - 1];
	reg [31:0] pcNext [0:DEPTH - 1];
	reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] ckptIdNext [0:DEPTH - 1];
	integer selectIndexInner;
	integer combIndexInner;
	integer combJInner;
	integer countInner;
	integer writeIndexInner;
	integer insertPosInner;
	integer seqIndexInner;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
`ifndef SYNTHESIS
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
`endif
	generate
		if (SORTED_HEAD_SELECT) begin : g_sorted_head
			always @(*) begin
				squashOutput = 1'sb0;
				if (validInner[0]) begin
					squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] = 1'b1;
					squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] = tagInner[0];
					squashOutput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = pcInner[0];
					squashOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = ckptIdInner[0];
				end
			end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput) begin : sv2v_autoblock_3
					reg [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] scanned;
					scanned = 1'sb0;
					begin : sv2v_autoblock_4
						reg signed [31:0] row;
						for (row = 0; row < DEPTH; row = row + 1)
							begin
								if ((row > 0) && validInner[row])
									assert (validInner[row - 1]) else $fatal(1, "flush valid-prefix invariant violated");
								begin : sv2v_autoblock_5
									reg signed [31:0] peer;
									for (peer = row + 1; peer < DEPTH; peer = peer + 1)
										if (validInner[row] && validInner[peer])
											assert (!rv32_pkg_rob_is_older(tagInner[peer], tagInner[row])) else $fatal(1, "flush age-order invariant violated");
								end
								if (validInner[row] && (!scanned[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || rv32_pkg_rob_is_older(tagInner[row], scanned[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)])))
									scanned = {1'b1, sv2v_cast_60734(tagInner[row]), pcInner[row], sv2v_cast_C1E44(ckptIdInner[row])};
							end
					end
					assert (squashOutput === scanned) else $fatal(1, "flush head/scan mismatch");
				end
`endif
		end
		else begin : g_scan_head
			always @(*) begin
				squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] = 1'b0;
				squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] = 1'sb0;
				squashOutput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = 1'sb0;
				squashOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = 1'sb0;
				for (selectIndexInner = 0; selectIndexInner < DEPTH; selectIndexInner = selectIndexInner + 1)
					if (validInner[selectIndexInner] && (!squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || rv32_pkg_rob_is_older(tagInner[selectIndexInner], squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)]))) begin
						squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] = 1'b1;
						squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] = tagInner[selectIndexInner];
						squashOutput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = pcInner[selectIndexInner];
						squashOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = ckptIdInner[selectIndexInner];
					end
			end
		end
	endgenerate
	always @(*) begin
		countInner = 0;
		writeIndexInner = 0;
		insertPosInner = 0;
		for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
			begin
				validNext[combIndexInner] = validInner[combIndexInner];
				tagNext[combIndexInner] = tagInner[combIndexInner];
				pcNext[combIndexInner] = pcInner[combIndexInner];
				ckptIdNext[combIndexInner] = ckptIdInner[combIndexInner];
			end
		if (squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))]) begin
			for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
				if (validNext[combIndexInner] && !rv32_pkg_rob_is_older(tagNext[combIndexInner], squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)]))
					validNext[combIndexInner] = 1'b0;
		end
		writeIndexInner = 0;
		for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
			if (validNext[combIndexInner]) begin
				if (writeIndexInner != combIndexInner) begin
					validNext[writeIndexInner] = 1'b1;
					tagNext[writeIndexInner] = tagNext[combIndexInner];
					pcNext[writeIndexInner] = pcNext[combIndexInner];
					ckptIdNext[writeIndexInner] = ckptIdNext[combIndexInner];
					validNext[combIndexInner] = 1'b0;
				end
				writeIndexInner = writeIndexInner + 1;
			end
		countInner = writeIndexInner;
		if ((branchInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] && (!squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || rv32_pkg_rob_is_older(branchInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)], squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)]))) && (countInner < DEPTH)) begin
			insertPosInner = 0;
			for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
				if ((combIndexInner < countInner) && rv32_pkg_rob_is_younger(branchInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)], tagNext[combIndexInner]))
					insertPosInner = insertPosInner + 1;
			for (combJInner = DEPTH - 1; combJInner > 0; combJInner = combJInner - 1)
				if ((combJInner > insertPosInner) && (combJInner <= countInner)) begin
					validNext[combJInner] = validNext[combJInner - 1];
					tagNext[combJInner] = tagNext[combJInner - 1];
					pcNext[combJInner] = pcNext[combJInner - 1];
					ckptIdNext[combJInner] = ckptIdNext[combJInner - 1];
				end
			validNext[insertPosInner] = 1'b1;
			tagNext[insertPosInner] = branchInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)];
			pcNext[insertPosInner] = branchInput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)];
			ckptIdNext[insertPosInner] = branchInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W];
			countInner = countInner + 1;
		end
		if ((jumpInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] && (!squashOutput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || rv32_pkg_rob_is_older(jumpInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)], squashOutput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)]))) && (countInner < DEPTH)) begin
			insertPosInner = 0;
			for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
				if ((combIndexInner < countInner) && rv32_pkg_rob_is_younger(jumpInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)], tagNext[combIndexInner]))
					insertPosInner = insertPosInner + 1;
			for (combJInner = DEPTH - 1; combJInner > 0; combJInner = combJInner - 1)
				if ((combJInner > insertPosInner) && (combJInner <= countInner)) begin
					validNext[combJInner] = validNext[combJInner - 1];
					tagNext[combJInner] = tagNext[combJInner - 1];
					pcNext[combJInner] = pcNext[combJInner - 1];
					ckptIdNext[combJInner] = ckptIdNext[combJInner - 1];
				end
			validNext[insertPosInner] = 1'b1;
			tagNext[insertPosInner] = jumpInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)];
			pcNext[insertPosInner] = jumpInput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)];
			ckptIdNext[insertPosInner] = jumpInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W];
		end
	end
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				begin
					validInner[seqIndexInner] <= 1'b0;
					tagInner[seqIndexInner] <= 1'sb0;
					pcInner[seqIndexInner] <= 1'sb0;
					ckptIdInner[seqIndexInner] <= 1'sb0;
				end
		else if (!freezeInput)
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				begin
					validInner[seqIndexInner] <= validNext[seqIndexInner];
					tagInner[seqIndexInner] <= tagNext[seqIndexInner];
					pcInner[seqIndexInner] <= pcNext[seqIndexInner];
					ckptIdInner[seqIndexInner] <= ckptIdNext[seqIndexInner];
				end
endmodule
module rv32_decoder (
	decodeContextInput,
	uopOutput
);
	parameter [0:0] LEGACY_HALT = 1'b0;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(96 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] decodeContextInput;
	output reg [(160 + rv32_pkg_BPU_CKPT_ID_W) + 2:0] uopOutput;
	reg [6:0] opcodeInner;
	reg [2:0] funct3Inner;
	reg [6:0] funct7Inner;
	localparam [31:0] rv32_pkg_HALT_INSN = 32'h0ff00513;
	localparam [6:0] rv32_pkg_OPCODE_AUIPC = 7'b0010111;
	localparam [6:0] rv32_pkg_OPCODE_BRANCH = 7'b1100011;
	localparam [6:0] rv32_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32_pkg_OPCODE_JALR = 7'b1100111;
	localparam [6:0] rv32_pkg_OPCODE_LOAD = 7'b0000011;
	localparam [6:0] rv32_pkg_OPCODE_LUI = 7'b0110111;
	localparam [6:0] rv32_pkg_OPCODE_OP = 7'b0110011;
	localparam [6:0] rv32_pkg_OPCODE_OP_IMM = 7'b0010011;
	localparam [6:0] rv32_pkg_OPCODE_STORE = 7'b0100011;
	always @* begin
		opcodeInner = decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 25:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 31];
		funct3Inner = decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 17:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 19];
		funct7Inner = decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 6];
		uopOutput = 1'sb0;
		uopOutput[160 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
		uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd0;
		uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd0;
		uopOutput[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 20:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 24];
		uopOutput[142 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 12:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 16];
		uopOutput[137 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 7:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 11];
		uopOutput[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = decodeContextInput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)];
		uopOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)];
		uopOutput[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = decodeContextInput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)];
		uopOutput[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))] = decodeContextInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W];
		uopOutput[2-:2] = 2'd2;
		if (LEGACY_HALT && (decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] == rv32_pkg_HALT_INSN)) begin
			uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{20 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 11]};
			uopOutput[158 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
			uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd7;
		end
		else
			(* full_case, parallel_case *)
			case (opcodeInner)
				rv32_pkg_OPCODE_LUI, rv32_pkg_OPCODE_AUIPC: begin
					uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd1;
					uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = (opcodeInner == rv32_pkg_OPCODE_LUI ? 6'd11 : 6'd12);
					uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 19], 12'b000000000000};
					uopOutput[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = uopOutput[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 5'd0;
				end
				rv32_pkg_OPCODE_JAL: begin
					uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd1;
					uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd27;
					uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{11 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 12:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 19], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 11], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 1:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 10], 1'b0};
					uopOutput[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = uopOutput[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 5'd0;
				end
				rv32_pkg_OPCODE_JALR: begin
					uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd1;
					uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd28;
					uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{20 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 11]};
					uopOutput[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = uopOutput[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 5'd0;
				end
				rv32_pkg_OPCODE_BRANCH: begin
					uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd4;
					uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{19 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 24], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 1:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 6], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 20:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 23], 1'b0};
					uopOutput[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					(* full_case, parallel_case *)
					case (funct3Inner)
						3'b000: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd21;
						3'b001: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd22;
						3'b100: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd23;
						3'b101: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd24;
						3'b110: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd25;
						3'b111: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd26;
						default: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd0;
					endcase
				end
				rv32_pkg_OPCODE_LOAD, rv32_pkg_OPCODE_STORE: begin
					uopOutput[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[2-:2] = funct3Inner[1:0];
					if (opcodeInner == rv32_pkg_OPCODE_LOAD) begin
						uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd5;
						uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd29;
						uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{20 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 11]};
						uopOutput[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = uopOutput[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 5'd0;
						uopOutput[0] = funct3Inner[2];
					end
					else begin
						uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd6;
						uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd30;
						uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{20 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 6], decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 20:(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 24]};
						uopOutput[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					end
				end
				rv32_pkg_OPCODE_OP_IMM, rv32_pkg_OPCODE_OP: begin
					uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 4'd1;
					uopOutput[132 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = 1'b1;
					uopOutput[131 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = opcodeInner == rv32_pkg_OPCODE_OP;
					uopOutput[130 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = opcodeInner == rv32_pkg_OPCODE_OP_IMM;
					uopOutput[129 + (rv32_pkg_BPU_CKPT_ID_W + 2)] = uopOutput[147 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 5'd0;
					if (opcodeInner == rv32_pkg_OPCODE_OP_IMM)
						uopOutput[128 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = {{20 {decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)]}}, decodeContextInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31):(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 11]};
					if ((opcodeInner == rv32_pkg_OPCODE_OP) && (funct7Inner == 7'b0000001)) begin
						uopOutput[157 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = (funct3Inner[2] ? 4'd3 : 4'd2);
						(* full_case, parallel_case *)
						case (funct3Inner)
							3'b000: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd13;
							3'b001: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd14;
							3'b010: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd15;
							3'b011: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd16;
							3'b100: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd17;
							3'b101: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd18;
							3'b110: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd19;
							3'b111: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd20;
							default: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd0;
						endcase
					end
					else
						(* full_case, parallel_case *)
						case (funct3Inner)
							3'b000: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = ((opcodeInner == rv32_pkg_OPCODE_OP) && decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 1] ? 6'd2 : 6'd1);
							3'b001: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd3;
							3'b010: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd4;
							3'b011: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd5;
							3'b100: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd6;
							3'b101: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = (decodeContextInput[(64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - 1] ? 6'd8 : 6'd7);
							3'b110: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd9;
							3'b111: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd10;
							default: uopOutput[153 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] = 6'd0;
						endcase
				end
				default:
					;
			endcase
	end
endmodule
module rv32_decode_issue_queue (
	clkInput,
	rstNInput,
	freezeInput,
	flushInput,
	inValidInput,
	inCountInput,
	inDataInput,
	inReadyOutput,
	decodedOutput,
	validOutput,
	wholeGroupOutput,
	readyCountInput,
	availableCountOutput,
	decodeFireCountOutput,
	fqCountOutput,
	iqCountOutput
);
	parameter [31:0] DECODE_WIDTH = 4;
	parameter [31:0] ISSUE_WIDTH = 4;
	parameter [31:0] FQ_DEPTH = 8;
	parameter [31:0] IQ_DEPTH = 8;
	parameter [0:0] LEGACY_HALT = 1'b0;
	parameter [31:0] FETCH_WIDTH = 2;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire flushInput;
	input wire inValidInput;
	input wire [$clog2(FETCH_WIDTH + 1) - 1:0] inCountInput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(FETCH_WIDTH * (96 + rv32_pkg_BPU_CKPT_ID_W)) - 1:0] inDataInput;
	output wire inReadyOutput;
	output wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (ISSUE_WIDTH * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (ISSUE_WIDTH * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] decodedOutput;
	output wire [ISSUE_WIDTH - 1:0] validOutput;
	output wire wholeGroupOutput;
	input wire [$clog2(ISSUE_WIDTH + 1) - 1:0] readyCountInput;
	output wire [$clog2(ISSUE_WIDTH + 1) - 1:0] availableCountOutput;
	output wire [$clog2(DECODE_WIDTH + 1) - 1:0] decodeFireCountOutput;
	output wire [$clog2(FQ_DEPTH + 1) - 1:0] fqCountOutput;
	output wire [$clog2(IQ_DEPTH + 1) - 1:0] iqCountOutput;
	localparam signed [31:0] DCW = $clog2(DECODE_WIDTH + 1);
	localparam signed [31:0] ICW = $clog2(ISSUE_WIDTH + 1);
	wire [(DECODE_WIDTH * (96 + rv32_pkg_BPU_CKPT_ID_W)) - 1:0] fqWords;
	wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (DECODE_WIDTH * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (DECODE_WIDTH * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] decodedWords;
	wire [(ISSUE_WIDTH * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) - 1:0] iqWords;
	wire [DCW - 1:0] availableDecode;
	reg [DCW - 1:0] decodeCount;
	wire [$clog2(FQ_DEPTH):0] fqCapacity;
	wire [$clog2(FQ_DEPTH):0] fqOccupancy;
	wire [$clog2(IQ_DEPTH):0] iqCapacity;
	wire [$clog2(IQ_DEPTH):0] iqOccupancy;
	wire fqReady;
	wire iqReady;
	wire [ICW - 1:0] iqAvailableInner;
	wire wholeGroupFireInner;
	wire emptyIngressInner;
	wire directIngressInner;
	wire [DCW - 1:0] storedDecodeInner;
	wire [(DECODE_WIDTH * (96 + rv32_pkg_BPU_CKPT_ID_W)) - 1:0] storedWordsInner;
	wire fqEmptyInner;
	wire iqEmptyInner;
	assign emptyIngressInner = ((((DECODE_WIDTH == 4) && (ISSUE_WIDTH == 4)) && (FETCH_WIDTH <= 4)) && fqEmptyInner) && iqEmptyInner;
	assign directIngressInner = (((emptyIngressInner && rstNInput) && !freezeInput) && !flushInput) && inValidInput;
	function automatic [DCW - 1:0] sv2v_cast_13A46;
		input reg [DCW - 1:0] inp;
		sv2v_cast_13A46 = inp;
	endfunction
	assign availableDecode = (directIngressInner ? sv2v_cast_13A46(inCountInput) : storedDecodeInner);
	genvar _gv_word_1;
	generate
		for (_gv_word_1 = 0; _gv_word_1 < DECODE_WIDTH; _gv_word_1 = _gv_word_1 + 1) begin : g_ingress_word
			localparam word = _gv_word_1;
			if (word < FETCH_WIDTH) begin : g_packet_word
				assign fqWords[word * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W] = (directIngressInner ? inDataInput[word * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W] : storedWordsInner[word * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W]);
			end
			else begin : g_stored_word
				assign fqWords[word * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W] = storedWordsInner[word * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W];
			end
		end
	endgenerate
	assign wholeGroupOutput = (((((rstNInput && !freezeInput) && !flushInput) && (DECODE_WIDTH == 4)) && (ISSUE_WIDTH == 4)) && iqEmptyInner) && (availableDecode != 0);
	function automatic [ICW - 1:0] sv2v_cast_2E07B;
		input reg [ICW - 1:0] inp;
		sv2v_cast_2E07B = inp;
	endfunction
	assign wholeGroupFireInner = wholeGroupOutput && (readyCountInput == sv2v_cast_2E07B(availableDecode));
	assign availableCountOutput = (wholeGroupOutput ? sv2v_cast_2E07B(availableDecode) : iqAvailableInner);
	generate
		if ((((DECODE_WIDTH != 1) && (DECODE_WIDTH != 2)) && (DECODE_WIDTH != 4)) || (((ISSUE_WIDTH != 1) && (ISSUE_WIDTH != 2)) && (ISSUE_WIDTH != 4))) begin : g_invalid_width
			initial $fatal(1, "decode/issue queue widths must be 1, 2 or 4");
		end
	endgenerate
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin
		decodeCount = availableDecode;
		if ((iqOccupancy != 0) && (sv2v_cast_32_signed(decodeCount) > sv2v_cast_32_signed(iqCapacity)))
			decodeCount = sv2v_cast_13A46(iqCapacity);
	end
	wire fqBackwardReadyInner;
	function automatic signed [DCW - 1:0] sv2v_cast_13A46_signed;
		input reg signed [DCW - 1:0] inp;
		sv2v_cast_13A46_signed = inp;
	endfunction
	function automatic signed [ICW - 1:0] sv2v_cast_2E07B_signed;
		input reg signed [ICW - 1:0] inp;
		sv2v_cast_2E07B_signed = inp;
	endfunction
	generate
		if (((FETCH_WIDTH == 4) && (DECODE_WIDTH == 4)) && (ISSUE_WIDTH == 4)) begin : g_backward_packet_credit
			localparam FCW = $clog2(FQ_DEPTH) + 1;
			localparam QCW = $clog2(IQ_DEPTH) + 1;
			function automatic [FCW - 1:0] sv2v_cast_77564;
				input reg [FCW - 1:0] inp;
				sv2v_cast_77564 = inp;
			endfunction
			wire [FCW - 1:0] oldFqFree = sv2v_cast_77564(FQ_DEPTH) - fqOccupancy;
			function automatic [QCW - 1:0] sv2v_cast_5FDC3;
				input reg [QCW - 1:0] inp;
				sv2v_cast_5FDC3 = inp;
			endfunction
			wire [QCW - 1:0] oldIqFree = sv2v_cast_5FDC3(IQ_DEPTH) - iqOccupancy;
			wire legalOldCounts = (fqOccupancy <= sv2v_cast_77564(FQ_DEPTH)) && (iqOccupancy <= sv2v_cast_5FDC3(IQ_DEPTH));
			wire [4:0] packetFits;
			assign packetFits[0] = 1'b1;
			genvar _gv_count_1;
			for (_gv_count_1 = 1; _gv_count_1 <= 4; _gv_count_1 = _gv_count_1 + 1) begin : g_packet_need
				localparam count = _gv_count_1;
				function automatic signed [FCW - 1:0] sv2v_cast_77564_signed;
					input reg signed [FCW - 1:0] inp;
					sv2v_cast_77564_signed = inp;
				endfunction
				wire [DCW - 1:0] needDecode = (oldFqFree >= sv2v_cast_77564_signed(count) ? sv2v_cast_13A46_signed(0) : sv2v_cast_13A46(sv2v_cast_77564_signed(count) - oldFqFree));
				function automatic [QCW - 1:0] sv2v_cast_5FDC3;
					input reg [QCW - 1:0] inp;
					sv2v_cast_5FDC3 = inp;
				endfunction
				wire [ICW - 1:0] needIssue = (oldIqFree >= sv2v_cast_5FDC3(needDecode) ? sv2v_cast_2E07B_signed(0) : sv2v_cast_2E07B(sv2v_cast_5FDC3(needDecode) - oldIqFree));
				assign packetFits[count] = (needDecode <= storedDecodeInner) && ((iqOccupancy == 0) || ((needIssue <= iqAvailableInner) && (readyCountInput >= needIssue)));
			end
			wire [7:0] arbitraryReady;
			genvar _gv_accepted_1;
			for (_gv_accepted_1 = 0; _gv_accepted_1 < 8; _gv_accepted_1 = _gv_accepted_1 + 1) begin : g_arbitrary_counts
				localparam accepted = _gv_accepted_1;
				wire [ICW - 1:0] fixedPop;
				if (accepted == 0) begin : g_no_fixed_pop
					assign fixedPop = 1'sb0;
				end
				else begin : g_some_fixed_pop
					wire [ICW - 1:0] availablePop = (wholeGroupOutput ? sv2v_cast_2E07B_signed(0) : iqAvailableInner);
					assign fixedPop = (availablePop < sv2v_cast_2E07B_signed(accepted) ? availablePop : sv2v_cast_2E07B_signed(accepted));
				end
				function automatic [QCW - 1:0] sv2v_cast_5FDC3;
					input reg [QCW - 1:0] inp;
					sv2v_cast_5FDC3 = inp;
				endfunction
				wire [QCW - 1:0] fixedIqCapacity = (sv2v_cast_5FDC3(IQ_DEPTH) - iqOccupancy) + sv2v_cast_5FDC3(fixedPop);
				wire [DCW - 1:0] fixedDecode = ((iqOccupancy != 0) && (sv2v_cast_32_signed(availableDecode) > sv2v_cast_32_signed(fixedIqCapacity)) ? sv2v_cast_13A46(fixedIqCapacity) : availableDecode);
				wire [DCW - 1:0] requestedPop = (emptyIngressInner ? sv2v_cast_13A46_signed(0) : fixedDecode);
				wire [DCW - 1:0] fixedFqPop = (requestedPop < storedDecodeInner ? requestedPop : storedDecodeInner);
				function automatic [FCW - 1:0] sv2v_cast_77564;
					input reg [FCW - 1:0] inp;
					sv2v_cast_77564 = inp;
				endfunction
				wire [FCW - 1:0] fixedFqCapacity = (sv2v_cast_77564(FQ_DEPTH) - fqOccupancy) + sv2v_cast_77564(fixedFqPop);
				assign arbitraryReady[accepted] = (!flushInput && (inCountInput <= 3'sd4)) && (sv2v_cast_77564(inCountInput) <= fixedFqCapacity);
			end
			wire legalReady = (inCountInput <= 3'sd4) && packetFits[inCountInput];
			assign fqBackwardReadyInner = (legalOldCounts ? !flushInput && legalReady : arbitraryReady[readyCountInput]);
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput) begin : sv2v_autoblock_1
					reg [FCW - 1:0] sv2v_tmp_cast;
					sv2v_tmp_cast = inCountInput;
					assert (fqBackwardReadyInner == ((!flushInput && (inCountInput <= 3'sd4)) && (sv2v_tmp_cast <= fqCapacity))) else $fatal(1, "backward queue exact FQ credit");
				end
`endif
		end
		else begin : g_original_packet_credit
			assign fqBackwardReadyInner = 1'b0;
		end
	endgenerate
	rv32_prefix_fifo #(
		.DEPTH(FQ_DEPTH),
		.WIDTH(96 + rv32_pkg_BPU_CKPT_ID_W),
		.PUSH_WIDTH(FETCH_WIDTH),
		.POP_WIDTH(DECODE_WIDTH),
		.EXTERNAL_CREDIT(((FETCH_WIDTH == 4) && (DECODE_WIDTH == 4)) && (ISSUE_WIDTH == 4))
	) u_fq(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.freezeInput(freezeInput),
		.flushInput(flushInput),
		.inCreditInput(fqBackwardReadyInner),
		.inValidInput(inValidInput && !emptyIngressInner),
		.inCountInput(inCountInput),
		.inDataInput(inDataInput),
		.inReadyOutput(fqReady),
		.inCapacityOutput(fqCapacity),
		.outCountOutput(storedDecodeInner),
		.outDataOutput(storedWordsInner),
		.outReadyCountInput((emptyIngressInner ? sv2v_cast_13A46_signed(0) : decodeCount)),
		.countOutput(fqOccupancy),
		.emptyOutput(fqEmptyInner)
	);
	genvar _gv_lane_5;
	generate
		for (_gv_lane_5 = 0; _gv_lane_5 < DECODE_WIDTH; _gv_lane_5 = _gv_lane_5 + 1) begin : g_decoder
			localparam lane = _gv_lane_5;
			rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder(
				.decodeContextInput(fqWords[lane * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W]),
				.uopOutput(decodedWords[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))])
			);
		end
	endgenerate
	rv32_prefix_fifo #(
		.DEPTH(IQ_DEPTH),
		.WIDTH((((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))),
		.PUSH_WIDTH(DECODE_WIDTH),
		.POP_WIDTH(ISSUE_WIDTH)
	) u_iq(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.freezeInput(freezeInput),
		.flushInput(flushInput),
		.inCreditInput(1'b0),
		.inValidInput((decodeCount != 0) && !wholeGroupFireInner),
		.inCountInput(decodeCount),
		.inDataInput(decodedWords),
		.inReadyOutput(iqReady),
		.inCapacityOutput(iqCapacity),
		.outCountOutput(iqAvailableInner),
		.outDataOutput(iqWords),
		.outReadyCountInput((wholeGroupOutput ? sv2v_cast_2E07B_signed(0) : readyCountInput)),
		.countOutput(iqOccupancy),
		.emptyOutput(iqEmptyInner)
	);
	genvar _gv_lane_6;
	function automatic [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)) - 1:0] sv2v_cast_6BEA7;
		input reg [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)) - 1:0] inp;
		sv2v_cast_6BEA7 = inp;
	endfunction
	function automatic [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)) - 1:0] sv2v_cast_7E1DF;
		input reg [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)) - 1:0] inp;
		sv2v_cast_7E1DF = inp;
	endfunction
	generate
		for (_gv_lane_6 = 0; _gv_lane_6 < ISSUE_WIDTH; _gv_lane_6 = _gv_lane_6 + 1) begin : g_output
			localparam lane = _gv_lane_6;
			assign validOutput[lane] = sv2v_cast_32_signed(availableCountOutput) > lane;
			if (lane < DECODE_WIDTH) begin : g_decode_bypass
				assign decodedOutput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))] = (validOutput[lane] ? (wholeGroupOutput ? decodedWords[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))] : sv2v_cast_6BEA7(iqWords[lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))])) : sv2v_cast_7E1DF(1'sb0));
			end
			else begin : g_iq_only
				assign decodedOutput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))] = (validOutput[lane] ? sv2v_cast_6BEA7(iqWords[lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))]) : sv2v_cast_7E1DF(1'sb0));
			end
		end
	endgenerate
	assign inReadyOutput = ((emptyIngressInner || fqReady) && !freezeInput) && !flushInput;
	assign decodeFireCountOutput = (!freezeInput && !flushInput ? decodeCount : {$clog2(DECODE_WIDTH + 1) {1'sb0}});
	function automatic [$clog2(FQ_DEPTH + 1) - 1:0] sv2v_cast_DB1E4;
		input reg [$clog2(FQ_DEPTH + 1) - 1:0] inp;
		sv2v_cast_DB1E4 = inp;
	endfunction
	assign fqCountOutput = sv2v_cast_DB1E4(fqOccupancy);
	function automatic [$clog2(IQ_DEPTH + 1) - 1:0] sv2v_cast_F8A1B;
		input reg [$clog2(IQ_DEPTH + 1) - 1:0] inp;
		sv2v_cast_F8A1B = inp;
	endfunction
	assign iqCountOutput = sv2v_cast_F8A1B(iqOccupancy);
`ifndef SYNTHESIS
	initial assert (IQ_DEPTH >= DECODE_WIDTH) else $fatal(1, "decode group exceeds IQ capacity");
	always @(posedge clkInput)
		if ((rstNInput && !freezeInput) && !flushInput) begin
			assert ((decodeCount == 0) || iqReady) else $fatal(1, "wide decode prefix not accepted atomically");
			if (wholeGroupOutput)
				assert ((readyCountInput == 0) || (readyCountInput == sv2v_cast_2E07B(availableDecode))) else $fatal(1, "whole-group bypass partially accepted");
			assert (readyCountInput <= availableCountOutput) else $fatal(1, "wide IQ consumption exceeds available prefix");
			assert ((sv2v_cast_32_signed(availableCountOutput) <= ISSUE_WIDTH) && (sv2v_cast_32_signed(decodeCount) <= DECODE_WIDTH)) else $fatal(1, "wide decode/issue lane count truncated");
		end
`endif
endmodule
module rv32_frontend (
	clkInput,
	rstNInput,
	freezeInput,
	fetchFreezeInput,
	recoveryActiveInput,
	predictorQueryOutput,
	fetchProgramCounterOutput,
	predictionInput,
	fetchHintInput,
	imemSecondInstructionInput,
	secondRequestOutput,
	predictEnableOutput,
	imemRequestOutput,
	imemReqReadyInput,
	imemResponseInput,
	imemRspReadyOutput,
	imemFlushOutput,
	redirectInput,
	instructionOutput,
	decodedOutput,
	iqReadyInput,
	instructionSecondOutput,
	decodedSecondOutput,
	iqSecondReadyInput,
	fetchInfoOutput,
	fqCountOutput,
	iqCountOutput,
	decodedLanesOutput,
	iqLaneValidOutput,
	iqReadyCountInput,
	wholeGroupOutput,
	imemPacketInstructionsInput,
	fetchCountOutput
);
	parameter [31:0] FETCH_WIDTH = 1;
	parameter [31:0] DECODE_WIDTH = 1;
	parameter [31:0] RENAME_WIDTH = 1;
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	parameter [31:0] FQ_DEPTH = rv32_pkg_default_fq_entries(DECODE_WIDTH);
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	parameter [31:0] IQ_DEPTH = rv32_pkg_default_iq_entries(DECODE_WIDTH);
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_REQUEST_ENTRIES = 8;
	parameter [31:0] REQUEST_DEPTH = ((rv32_pkg_FETCH_REQUEST_ENTRIES / FETCH_WIDTH) > 1 ? rv32_pkg_FETCH_REQUEST_ENTRIES / FETCH_WIDTH : 2);
	parameter [31:0] RESET_PC = 32'b00000000000000000000000000000000;
	parameter [0:0] LEGACY_HALT = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire fetchFreezeInput;
	input wire recoveryActiveInput;
	output wire [32:0] predictorQueryOutput;
	output wire [31:0] fetchProgramCounterOutput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(33 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] predictionInput;
	input wire [4:0] fetchHintInput;
	input wire [31:0] imemSecondInstructionInput;
	output wire secondRequestOutput;
	output wire predictEnableOutput;
	output wire [(65 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] imemRequestOutput;
	input wire imemReqReadyInput;
	input wire [32:0] imemResponseInput;
	output wire imemRspReadyOutput;
	output wire imemFlushOutput;
	input wire [32:0] redirectInput;
	output wire [(97 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] instructionOutput;
	output wire [(160 + rv32_pkg_BPU_CKPT_ID_W) + 2:0] decodedOutput;
	input wire iqReadyInput;
	output wire [(97 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] instructionSecondOutput;
	output wire [(160 + rv32_pkg_BPU_CKPT_ID_W) + 2:0] decodedSecondOutput;
	input wire iqSecondReadyInput;
	output reg [67:0] fetchInfoOutput;
	output wire [$clog2(FQ_DEPTH + 1) - 1:0] fqCountOutput;
	output wire [$clog2(IQ_DEPTH + 1) - 1:0] iqCountOutput;
	output wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (4 * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (4 * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] decodedLanesOutput;
	output wire [3:0] iqLaneValidOutput;
	input wire [2:0] iqReadyCountInput;
	output wire wholeGroupOutput;
	input wire [127:0] imemPacketInstructionsInput;
	output wire [2:0] fetchCountOutput;
	generate
		if (((FETCH_WIDTH != 1) && (FETCH_WIDTH != 2)) && (FETCH_WIDTH != 4)) begin : g_invalid_fetch_width
			initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
		end
		if ((FETCH_WIDTH == 4) && ((DECODE_WIDTH != 4) || (RENAME_WIDTH != 4))) begin : g_invalid_four_transport
			initial $fatal(1, "four-fetch requires four-decode/four-allocation transport");
		end
		if (((DECODE_WIDTH != 1) && (DECODE_WIDTH != 2)) && (DECODE_WIDTH != 4)) begin : g_invalid_decode_width
			initial $fatal(1, "DECODE_WIDTH must be 1, 2 or 4");
		end
		if (((RENAME_WIDTH != 1) && (RENAME_WIDTH != 2)) && (RENAME_WIDTH != 4)) begin : g_invalid_rename_width
			initial $fatal(1, "RENAME_WIDTH must be 1, 2 or 4");
		end
		if ((((rv32_pkg_ROB_ENTRIES + (REQUEST_DEPTH * FETCH_WIDTH)) + FQ_DEPTH) + IQ_DEPTH) > rv32_pkg_BPU_CKPT_ENTRIES) begin : g_invalid_checkpoint_budget
			initial $fatal(1, "frontend capacity exceeds checkpoint live budget");
		end
	endgenerate
	localparam [31:0] REQ_SLOT_W = $clog2(REQUEST_DEPTH);
	localparam [31:0] REQ_SEQ_W = REQ_SLOT_W + 1;
	reg [31:0] pcInner;
	reg stopFetchInner;
	reg [(64 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] requestInner [0:REQUEST_DEPTH - 1];
	reg [2:0] requestWordsInner [0:REQUEST_DEPTH - 1];
	reg [2:0] packetCountInner;
	reg [1:0] queryLaneInner;
	reg packetPredictInner;
	wire [3:0] controlLanesInner;
	reg [REQ_SEQ_W - 1:0] reqHeadInner;
	reg [REQ_SEQ_W - 1:0] reqTailInner;
	wire [REQ_SEQ_W - 1:0] reqCountInner;
	wire [REQ_SLOT_W - 1:0] reqHeadSlotInner;
	wire [REQ_SLOT_W - 1:0] reqTailSlotInner;
	wire requestFireInner;
	wire responseAcceptInner;
	wire haltResponseInner;
	wire fetchAllowedInner;
	wire recoveryResponseSafeInner;
	wire fqReadyInner;
	wire fqValidInner;
	wire iqReadyInner;
	wire fqPushInner;
	wire fqPopInner;
	reg [(96 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] fqInputInner;
	wire [(96 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] fqHeadInner;
	wire [(96 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] iqHeadInner;
	reg [(64 + (((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0))) - 1:0] fqPacketInputInner;
	wire secondAllowedInner;
	wire querySecondInner;
	wire [31:0] packetNextPcInner;
	reg lastFqPushInner;
	reg [31:0] lastFqInstrInner;
	reg [31:0] lastFqPcInner;
	integer iInner;
	localparam [6:0] rv32_pkg_OPCODE_BRANCH = 7'b1100011;
	localparam [6:0] rv32_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32_pkg_OPCODE_JALR = 7'b1100111;
	function automatic is_control;
		input reg [31:0] instruction;
		is_control = ((instruction[6:0] == rv32_pkg_OPCODE_BRANCH) || (instruction[6:0] == rv32_pkg_OPCODE_JAL)) || ((instruction[6:0] == rv32_pkg_OPCODE_JALR) && (instruction[14:12] == 3'b000));
	endfunction
	assign controlLanesInner = {fetchHintInput[0], fetchHintInput[1], fetchHintInput[2], fetchHintInput[3]};
	localparam [31:0] rv32_pkg_CACHE_LINE_BYTES = 64;
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	function automatic [3:0] sv2v_cast_58B43;
		input reg [3:0] inp;
		sv2v_cast_58B43 = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin : sv2v_autoblock_1
		reg open;
		open = 1'b1;
		packetCountInner = 3'd1;
		queryLaneInner = 1'sb0;
		packetPredictInner = 1'b1;
		if (((FETCH_WIDTH == 4) && !LEGACY_HALT) && fetchHintInput[4]) begin
			packetCountInner = 1'sb0;
			packetPredictInner = 1'b0;
			begin : sv2v_autoblock_2
				reg signed [31:0] lane;
				for (lane = 0; lane < 4; lane = lane + 1)
					if (open && (lane < (16 - sv2v_cast_32_signed(pcInner[5:2])))) begin
						packetCountInner = sv2v_cast_3_signed(lane + 1);
						queryLaneInner = sv2v_cast_2_signed(lane);
						packetPredictInner = controlLanesInner[lane];
						if (controlLanesInner[lane])
							open = 1'b0;
					end
			end
		end
		else if (((FETCH_WIDTH == 2) && !LEGACY_HALT) && fetchHintInput[4]) begin
			if ((pcInner[5:2] != sv2v_cast_58B43(15)) && !fetchHintInput[3]) begin
				packetCountInner = 3'd2;
				queryLaneInner = (fetchHintInput[2] ? 2'd1 : 2'd0);
			end
			packetPredictInner = fetchHintInput[3] || ((packetCountInner == 2) && fetchHintInput[2]);
		end
	end
	assign fetchCountOutput = packetCountInner;
	assign secondAllowedInner = packetCountInner > 1;
	assign querySecondInner = queryLaneInner == 1;
	assign secondRequestOutput = secondAllowedInner;
	assign predictEnableOutput = packetPredictInner;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	assign packetNextPcInner = (predictEnableOutput ? predictionInput[rv32_pkg_BPU_CKPT_ID_W + 32-:((rv32_pkg_BPU_CKPT_ID_W + 32) >= (1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 32) - (1 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 32)) + 1)] : pcInner + (sv2v_cast_32(packetCountInner) << 2));
	assign reqCountInner = reqTailInner - reqHeadInner;
	assign reqHeadSlotInner = reqHeadInner[REQ_SLOT_W - 1:0];
	assign reqTailSlotInner = reqTailInner[REQ_SLOT_W - 1:0];
	assign recoveryResponseSafeInner = !recoveryActiveInput || ((((FETCH_WIDTH == 2) && !LEGACY_HALT) && !is_control(imemResponseInput[31-:32])) && ((requestWordsInner[reqHeadSlotInner] < 2) || !is_control(imemSecondInstructionInput)));
	assign imemRspReadyOutput = (((((rstNInput && !freezeInput) && !redirectInput[32]) && !stopFetchInner) && (reqCountInner != 0)) && fqReadyInner) && recoveryResponseSafeInner;
	assign imemFlushOutput = redirectInput[32];
	assign responseAcceptInner = imemResponseInput[32] && imemRspReadyOutput;
	localparam [31:0] rv32_pkg_HALT_INSN = 32'h0ff00513;
	assign haltResponseInner = (LEGACY_HALT && responseAcceptInner) && (imemResponseInput[31-:32] == rv32_pkg_HALT_INSN);
	function automatic [REQ_SEQ_W - 1:0] sv2v_cast_77A5A;
		input reg [REQ_SEQ_W - 1:0] inp;
		sv2v_cast_77A5A = inp;
	endfunction
	assign fetchAllowedInner = ((((((rstNInput && !freezeInput) && !fetchFreezeInput) && ((reqCountInner < sv2v_cast_77A5A(REQUEST_DEPTH)) || responseAcceptInner)) && fqReadyInner) && !haltResponseInner) && !stopFetchInner) && !redirectInput[32];
	assign imemRequestOutput[33 + (rv32_pkg_BPU_CKPT_ID_W + 31)] = fetchAllowedInner;
	assign imemRequestOutput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] = pcInner;
	assign imemRequestOutput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = packetNextPcInner;
	assign imemRequestOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = predictionInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W];
	assign predictorQueryOutput[32-:32] = pcInner + (sv2v_cast_32(queryLaneInner) << 2);
	assign fetchProgramCounterOutput = pcInner;
	assign predictorQueryOutput[0] = requestFireInner;
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	function automatic [(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1:0] sv2v_cast_92213;
		input reg [(((64 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (64 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((64 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1:0] inp;
		sv2v_cast_92213 = inp;
	endfunction
	always @* begin
		fqInputInner = {sv2v_cast_32(imemResponseInput[31-:32]), sv2v_cast_32(requestInner[reqHeadSlotInner][64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)]), sv2v_cast_32(requestInner[reqHeadSlotInner][32 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)]), sv2v_cast_C1E44(requestInner[reqHeadSlotInner][rv32_pkg_BPU_CKPT_ID_W + 0-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))])};
		fqPacketInputInner = {sv2v_cast_64({imemSecondInstructionInput, imemResponseInput[31-:32]}), sv2v_cast_92213(requestInner[reqHeadSlotInner])};
	end
	assign requestFireInner = imemRequestOutput[33 + (rv32_pkg_BPU_CKPT_ID_W + 31)] && imemReqReadyInput;
	assign fqPushInner = responseAcceptInner;
	assign fqPopInner = fqValidInner && iqReadyInner;
	generate
		if ((DECODE_WIDTH != 4) && (RENAME_WIDTH != 4)) begin : g_no_wide_interface
			assign wholeGroupOutput = 1'b0;
			assign decodedLanesOutput = 1'sb0;
			assign iqLaneValidOutput = 1'sb0;
		end
	endgenerate
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	function automatic [$clog2(RENAME_WIDTH + 1) - 1:0] sv2v_cast_62C6E;
		input reg [$clog2(RENAME_WIDTH + 1) - 1:0] inp;
		sv2v_cast_62C6E = inp;
	endfunction
	function automatic [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)) - 1:0] sv2v_cast_6BEA7;
		input reg [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)) - 1:0] inp;
		sv2v_cast_6BEA7 = inp;
	endfunction
	function automatic [$clog2(FQ_DEPTH + 1) - 1:0] sv2v_cast_B05BE;
		input reg [$clog2(FQ_DEPTH + 1) - 1:0] inp;
		sv2v_cast_B05BE = inp;
	endfunction
	function automatic [$clog2(IQ_DEPTH + 1) - 1:0] sv2v_cast_D8EC1;
		input reg [$clog2(IQ_DEPTH + 1) - 1:0] inp;
		sv2v_cast_D8EC1 = inp;
	endfunction
	generate
		if ((DECODE_WIDTH == 1) && (RENAME_WIDTH == 1)) begin : g_single_decode
			assign decodedOutput = 1'sb0;
			assign decodedSecondOutput = 1'sb0;
			assign instructionSecondOutput = 1'sb0;
			if (FETCH_WIDTH == 2) begin : g_packet
				rv32_fetch_packet_fifo #(.DEPTH(FQ_DEPTH)) u_fq(
					.freezeInput(freezeInput),
					.clkInput(clkInput),
					.rstNInput(rstNInput),
					.flushInput(redirectInput[32]),
					.inValidInput(fqPushInner),
					.inReadyOutput(fqReadyInner),
					.inDataInput(fqPacketInputInner),
					.outValidOutput(fqValidInner),
					.outReadyInput(iqReadyInner),
					.outDataOutput(fqHeadInner),
					.countOutput(fqCountOutput)
				);
			end
			else begin : g_scalar
				rv32_epoch_fifo #(
					.DEPTH(FQ_DEPTH),
					.WIDTH(96 + rv32_pkg_BPU_CKPT_ID_W)
				) u_fq(
					.freezeInput(freezeInput),
					.clkInput(clkInput),
					.rstNInput(rstNInput),
					.flushInput(redirectInput[32]),
					.inValidInput(fqPushInner),
					.inReadyOutput(fqReadyInner),
					.inDataInput(fqInputInner),
					.outValidOutput(fqValidInner),
					.outReadyInput(iqReadyInner),
					.outDataOutput(fqHeadInner),
					.countOutput(fqCountOutput)
				);
			end
			rv32_epoch_fifo #(
				.DEPTH(IQ_DEPTH),
				.WIDTH(96 + rv32_pkg_BPU_CKPT_ID_W)
			) u_iq(
				.freezeInput(freezeInput),
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.flushInput(redirectInput[32]),
				.inValidInput(fqValidInner),
				.inReadyOutput(iqReadyInner),
				.inDataInput(fqHeadInner),
				.outValidOutput(instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0]),
				.outReadyInput(iqReadyInput),
				.outDataOutput(iqHeadInner),
				.countOutput(iqCountOutput)
			);
			assign instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W] = iqHeadInner;
		end
		else if ((DECODE_WIDTH == 4) || (RENAME_WIDTH == 4)) begin : g_wide_decode
			localparam signed [31:0] PACKET_WIDTH = (FETCH_WIDTH == 4 ? 4 : 2);
			reg [(PACKET_WIDTH * (96 + rv32_pkg_BPU_CKPT_ID_W)) - 1:0] packetWords;
			wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (RENAME_WIDTH * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (RENAME_WIDTH * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] queueDecoded;
			wire [RENAME_WIDTH - 1:0] queueValid;
			wire [$clog2(PACKET_WIDTH + 1) - 1:0] inputCount;
			wire [$clog2(RENAME_WIDTH + 1) - 1:0] readyCount;
			wire responseProposal;
			assign responseProposal = (((((imemResponseInput[32] && rstNInput) && !freezeInput) && !redirectInput[32]) && !stopFetchInner) && (reqCountInner != 0)) && recoveryResponseSafeInner;
			assign inputCount = requestWordsInner[reqHeadSlotInner][$clog2(PACKET_WIDTH + 1) - 1:0];
			always @* begin
				packetWords = 1'sb0;
				begin : sv2v_autoblock_3
					reg signed [31:0] lane;
					for (lane = 0; lane < PACKET_WIDTH; lane = lane + 1)
						begin
							packetWords[lane * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W] = fqInputInner;
							packetWords[(lane * (96 + rv32_pkg_BPU_CKPT_ID_W)) + (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] = (FETCH_WIDTH == 4 ? imemPacketInstructionsInput[32 * lane+:32] : (lane == 0 ? imemResponseInput[31-:32] : imemSecondInstructionInput));
							packetWords[(lane * (96 + rv32_pkg_BPU_CKPT_ID_W)) + (rv32_pkg_BPU_CKPT_ID_W + 63)-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] = fqInputInner[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] + sv2v_cast_32_signed(lane * 4);
							packetWords[(lane * (96 + rv32_pkg_BPU_CKPT_ID_W)) + (rv32_pkg_BPU_CKPT_ID_W - 1)-:rv32_pkg_BPU_CKPT_ID_W] = fqInputInner[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] + sv2v_cast_C1E44(lane);
							if ((lane + 1) < sv2v_cast_32_signed(inputCount))
								packetWords[(lane * (96 + rv32_pkg_BPU_CKPT_ID_W)) + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = fqInputInner[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] + sv2v_cast_32_signed((lane + 1) * 4);
						end
				end
			end
			if (RENAME_WIDTH == 4) begin : g_array_acceptance
				assign readyCount = iqReadyCountInput;
			end
			else begin : g_legacy_acceptance
				assign readyCount = sv2v_cast_62C6E(iqReadyInput) + sv2v_cast_62C6E((RENAME_WIDTH == 2) && iqSecondReadyInput);
			end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if ((rstNInput && recoveryActiveInput) && !redirectInput[32]) begin
					assert (readyCount == 0) else $fatal(1, "recovery transport allocated backend work");
					begin : sv2v_autoblock_4
						reg signed [31:0] lane;
						for (lane = 0; lane < RENAME_WIDTH; lane = lane + 1)
							if (queueValid[lane])
								assert (!is_control(queueDecoded[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])) else $fatal(1, "control entered recovery IQ");
					end
				end
`endif
			wire [$clog2(RENAME_WIDTH + 1) - 1:0] unusedAvailableCountInner;
			wire [$clog2(DECODE_WIDTH + 1) - 1:0] unusedDecodeFireCountInner;
			rv32_decode_issue_queue #(
				.DECODE_WIDTH(DECODE_WIDTH),
				.ISSUE_WIDTH(RENAME_WIDTH),
				.FQ_DEPTH(FQ_DEPTH),
				.IQ_DEPTH(IQ_DEPTH),
				.LEGACY_HALT(LEGACY_HALT),
				.FETCH_WIDTH(PACKET_WIDTH)
			) u_decode_issue(
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.freezeInput(freezeInput),
				.flushInput(redirectInput[32]),
				.inValidInput(responseProposal),
				.inCountInput(inputCount),
				.inDataInput(packetWords),
				.inReadyOutput(fqReadyInner),
				.decodedOutput(queueDecoded),
				.validOutput(queueValid),
				.wholeGroupOutput(wholeGroupOutput),
				.readyCountInput(readyCount),
				.availableCountOutput(unusedAvailableCountInner),
				.decodeFireCountOutput(unusedDecodeFireCountInner),
				.fqCountOutput(fqCountOutput),
				.iqCountOutput(iqCountOutput)
			);
			genvar _gv_lane_7;
			for (_gv_lane_7 = 0; _gv_lane_7 < 4; _gv_lane_7 = _gv_lane_7 + 1) begin : g_array_head
				localparam lane = _gv_lane_7;
				if (lane < RENAME_WIDTH) begin : g_enabled
					assign decodedLanesOutput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))] = queueDecoded[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))];
					assign iqLaneValidOutput[lane] = queueValid[lane];
				end
				else begin : g_disabled
					assign decodedLanesOutput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))] = 1'sb0;
					assign iqLaneValidOutput[lane] = 1'b0;
				end
			end
			assign decodedOutput = queueDecoded[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + 0+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))];
			assign instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0] = queueValid[0];
			assign instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W] = {sv2v_cast_32(decodedOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedOutput[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedOutput[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedOutput[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))])};
			if (RENAME_WIDTH >= 2) begin : g_second_head
				assign decodedSecondOutput = queueDecoded[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))];
				assign instructionSecondOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0] = queueValid[1];
				assign instructionSecondOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W] = {sv2v_cast_32(decodedSecondOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondOutput[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondOutput[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedSecondOutput[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))])};
			end
			else begin : g_no_second_head
				assign decodedSecondOutput = 1'sb0;
				assign instructionSecondOutput = 1'sb0;
			end
			assign fqValidInner = 1'b0;
			assign iqReadyInner = 1'b0;
			assign fqHeadInner = 1'sb0;
			assign iqHeadInner = instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W];
		end
		else begin : g_multi_decode
			localparam [31:0] FQ_COUNT_W = $clog2(FQ_DEPTH) + 1;
			localparam [31:0] IQ_COUNT_W = $clog2(IQ_DEPTH) + 1;
			reg [(2 * (96 + rv32_pkg_BPU_CKPT_ID_W)) - 1:0] fqDataInner;
			wire [(2 * (96 + rv32_pkg_BPU_CKPT_ID_W)) - 1:0] fqWordsInner;
			wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (2 * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (2 * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] decodedWordsInner;
			wire [(RENAME_WIDTH * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) - 1:0] iqWordsInner;
			wire [1:0] inputWordsInner;
			wire [1:0] availableWordsInner;
			reg [1:0] decodeCountInner;
			wire [$clog2(RENAME_WIDTH + 1) - 1:0] iqAvailableInner;
			wire [$clog2(RENAME_WIDTH + 1) - 1:0] issueCountInner;
			wire [FQ_COUNT_W - 1:0] fqCapacityInner;
			wire [FQ_COUNT_W - 1:0] fqOccupancyInner;
			wire [IQ_COUNT_W - 1:0] iqCapacityInner;
			wire [IQ_COUNT_W - 1:0] iqOccupancyInner;
			wire iqAcceptInner;
			assign inputWordsInner = ((FETCH_WIDTH == 2) && requestInner[reqHeadSlotInner][0] ? 2'd2 : 2'd1);
			always @* begin
				fqDataInner = 1'sb0;
				fqDataInner[0+:96 + rv32_pkg_BPU_CKPT_ID_W] = fqInputInner;
				if (inputWordsInner == 2) begin
					fqDataInner[0 + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = fqInputInner[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] + 32'd4;
					fqDataInner[96 + rv32_pkg_BPU_CKPT_ID_W+:96 + rv32_pkg_BPU_CKPT_ID_W] = {imemSecondInstructionInput, sv2v_cast_32(fqInputInner[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] + 32'd4), sv2v_cast_32(fqInputInner[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)]), sv2v_cast_C1E44(fqInputInner[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] + sv2v_cast_C1E44(1))};
				end
			end
			always @* begin
				decodeCountInner = (sv2v_cast_32_signed(availableWordsInner) < sv2v_cast_32_signed(iqCapacityInner) ? availableWordsInner : sv2v_cast_2(iqCapacityInner));
				if (decodeCountInner > sv2v_cast_2(DECODE_WIDTH))
					decodeCountInner = sv2v_cast_2(DECODE_WIDTH);
			end
			assign issueCountInner = sv2v_cast_62C6E(iqReadyInput) + sv2v_cast_62C6E((RENAME_WIDTH == 2) && iqSecondReadyInput);
			wire unusedFqEmptyInner;
			wire unusedIqEmptyInner;
			rv32_prefix_fifo #(
				.DEPTH(FQ_DEPTH),
				.WIDTH(96 + rv32_pkg_BPU_CKPT_ID_W)
			) u_fq(
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.freezeInput(freezeInput),
				.flushInput(redirectInput[32]),
				.inCreditInput(1'b0),
				.inValidInput(fqPushInner),
				.inCountInput(inputWordsInner),
				.inDataInput(fqDataInner),
				.inReadyOutput(fqReadyInner),
				.inCapacityOutput(fqCapacityInner),
				.outCountOutput(availableWordsInner),
				.outDataOutput(fqWordsInner),
				.outReadyCountInput(decodeCountInner),
				.countOutput(fqOccupancyInner),
				.emptyOutput(unusedFqEmptyInner)
			);
			genvar _gv_lane_8;
			for (_gv_lane_8 = 0; _gv_lane_8 < 2; _gv_lane_8 = _gv_lane_8 + 1) begin : g_decoder
				localparam lane = _gv_lane_8;
				if (lane < DECODE_WIDTH) begin : g_enabled
					rv32_decoder #(.LEGACY_HALT(LEGACY_HALT)) u_decoder(
						.decodeContextInput(fqWordsInner[lane * (96 + rv32_pkg_BPU_CKPT_ID_W)+:96 + rv32_pkg_BPU_CKPT_ID_W]),
						.uopOutput(decodedWordsInner[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))])
					);
				end
				else begin : g_disabled
					assign decodedWordsInner[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2) + (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2)))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))] = 1'sb0;
				end
			end
			rv32_prefix_fifo #(
				.DEPTH(IQ_DEPTH),
				.WIDTH((((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))),
				.POP_WIDTH(RENAME_WIDTH)
			) u_iq(
				.clkInput(clkInput),
				.rstNInput(rstNInput),
				.freezeInput(freezeInput),
				.flushInput(redirectInput[32]),
				.inCreditInput(1'b0),
				.inValidInput(decodeCountInner != 0),
				.inCountInput(decodeCountInner),
				.inDataInput(decodedWordsInner),
				.inReadyOutput(iqAcceptInner),
				.inCapacityOutput(iqCapacityInner),
				.outCountOutput(iqAvailableInner),
				.outDataOutput(iqWordsInner),
				.outReadyCountInput(issueCountInner),
				.countOutput(iqOccupancyInner),
				.emptyOutput(unusedIqEmptyInner)
			);
			assign decodedOutput = sv2v_cast_6BEA7(iqWordsInner[0+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))]);
			assign instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0] = iqAvailableInner != 0;
			assign instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W] = {sv2v_cast_32(decodedOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedOutput[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedOutput[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedOutput[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))])};
			if (RENAME_WIDTH == 2) begin : g_second_head
				assign decodedSecondOutput = sv2v_cast_6BEA7(iqWordsInner[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))+:(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))]);
				assign instructionSecondOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) + 0] = iqAvailableInner > 1;
				assign instructionSecondOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W] = {sv2v_cast_32(decodedSecondOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondOutput[96 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedSecondOutput[32 + (rv32_pkg_BPU_CKPT_ID_W + 2)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedSecondOutput[rv32_pkg_BPU_CKPT_ID_W + 2-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))])};
			end
			else begin : g_no_second_head
				assign decodedSecondOutput = 1'sb0;
				assign instructionSecondOutput = 1'sb0;
			end
			assign fqCountOutput = sv2v_cast_B05BE(fqOccupancyInner);
			assign iqCountOutput = sv2v_cast_D8EC1(iqOccupancyInner);
			assign fqValidInner = availableWordsInner != 0;
			assign iqReadyInner = decodeCountInner != 0;
			assign fqHeadInner = fqWordsInner[0+:96 + rv32_pkg_BPU_CKPT_ID_W];
			assign iqHeadInner = instructionOutput[(96 + rv32_pkg_BPU_CKPT_ID_W) - 1-:96 + rv32_pkg_BPU_CKPT_ID_W];
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if ((rstNInput && !freezeInput) && !redirectInput[32]) begin
					assert ((decodeCountInner == 0) || iqAcceptInner) else $fatal(1, "decoded prefix not accepted atomically");
					assert (sv2v_cast_32_signed(decodeCountInner) <= sv2v_cast_32_signed(availableWordsInner)) ;
					assert ((!iqSecondReadyInput || (RENAME_WIDTH == 1)) || iqReadyInput) else $fatal(1, "IQ issue must consume an ordered prefix");
				end
`endif
		end
	endgenerate
	always @* begin
		fetchInfoOutput = 1'sb0;
		fetchInfoOutput[67] = lastFqPushInner && ((lastFqInstrInner[6:0] == rv32_pkg_OPCODE_JAL) || ((lastFqInstrInner[6:0] == rv32_pkg_OPCODE_JALR) && (lastFqInstrInner[14:12] == 0)));
		fetchInfoOutput[66] = fetchInfoOutput[67] && ((lastFqInstrInner[11:7] == 1) || (lastFqInstrInner[11:7] == 5));
		fetchInfoOutput[65] = ((fetchInfoOutput[67] && (lastFqInstrInner[6:0] == rv32_pkg_OPCODE_JALR)) && ((lastFqInstrInner[19:15] == 1) || (lastFqInstrInner[19:15] == 5))) && (lastFqInstrInner[11:7] != lastFqInstrInner[19:15]);
		fetchInfoOutput[64] = fetchInfoOutput[67] && (lastFqInstrInner[6:0] == rv32_pkg_OPCODE_JAL);
		fetchInfoOutput[63-:32] = lastFqPcInner;
		fetchInfoOutput[31-:32] = lastFqPcInner + {{11 {lastFqInstrInner[31]}}, lastFqInstrInner[31], lastFqInstrInner[19:12], lastFqInstrInner[20], lastFqInstrInner[30:21], 1'b0};
	end
	function automatic signed [REQ_SEQ_W - 1:0] sv2v_cast_77A5A_signed;
		input reg signed [REQ_SEQ_W - 1:0] inp;
		sv2v_cast_77A5A_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			pcInner <= RESET_PC;
			stopFetchInner <= 0;
			reqHeadInner <= 0;
			reqTailInner <= 0;
			lastFqPushInner <= 0;
			lastFqInstrInner <= 0;
			lastFqPcInner <= 0;
			for (iInner = 0; iInner < REQUEST_DEPTH; iInner = iInner + 1)
				begin
					requestInner[iInner] <= 1'sb0;
					requestWordsInner[iInner] <= 1'sb0;
				end
		end
		else if (!freezeInput) begin
			if (responseAcceptInner)
				reqHeadInner <= reqHeadInner + sv2v_cast_77A5A_signed(1);
			if (redirectInput[32]) begin
				pcInner <= redirectInput[31-:32];
				stopFetchInner <= 0;
				lastFqPushInner <= 0;
				reqHeadInner <= 0;
				reqTailInner <= 0;
			end
			else begin
				if (requestFireInner) begin
					requestInner[reqTailSlotInner] <= {pcInner, packetNextPcInner, sv2v_cast_C1E44(predictionInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W]), secondAllowedInner};
					requestWordsInner[reqTailSlotInner] <= packetCountInner;
					reqTailInner <= reqTailInner + sv2v_cast_77A5A_signed(1);
					pcInner <= packetNextPcInner;
				end
				if (haltResponseInner)
					stopFetchInner <= 1;
				lastFqPushInner <= fqPushInner && fqReadyInner;
				if (fqPushInner && fqReadyInner) begin
					if (FETCH_WIDTH == 4) begin
						lastFqInstrInner <= imemPacketInstructionsInput[(sv2v_cast_32_signed(requestWordsInner[reqHeadSlotInner]) - 1) * 32+:32];
						lastFqPcInner <= requestInner[reqHeadSlotInner][64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] + ((sv2v_cast_32(requestWordsInner[reqHeadSlotInner]) - 32'd1) << 2);
					end
					else if (requestInner[reqHeadSlotInner][0] && !is_control(imemResponseInput[31-:32])) begin
						lastFqInstrInner <= imemSecondInstructionInput;
						lastFqPcInner <= requestInner[reqHeadSlotInner][64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] + 32'd4;
					end
					else begin
						lastFqInstrInner <= imemResponseInput[31-:32];
						lastFqPcInner <= requestInner[reqHeadSlotInner][64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
					end
				end
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin
			assert (reqCountInner <= sv2v_cast_77A5A(REQUEST_DEPTH)) else $fatal(1, "fetch transaction overflow");
			assert (!fqPushInner || fqReadyInner) else $fatal(1, "unaccepted FQ response");
			if ((FETCH_WIDTH == 2) && secondAllowedInner)
				assert (((pcInner[5:2] != sv2v_cast_58B43(15)) && fetchHintInput[4]) && !fetchHintInput[3]) ;
			if ((FETCH_WIDTH == 4) && requestFireInner) begin
				assert (((packetCountInner >= 1) && (packetCountInner <= 4)) && ((sv2v_cast_32_signed(packetCountInner) + sv2v_cast_32_signed(pcInner[5:2])) <= 16)) else $fatal(1, "four-fetch packet crossed cache-line boundary");
				begin : sv2v_autoblock_5
					reg signed [31:0] lane;
					for (lane = 0; lane < 3; lane = lane + 1)
						if ((lane + 1) < sv2v_cast_32_signed(packetCountInner))
							assert (fetchHintInput[4] && !controlLanesInner[lane]) else $fatal(1, "four-fetch passed earliest CFI");
				end
			end
			if ((FETCH_WIDTH == 4) && responseAcceptInner) begin : sv2v_autoblock_6
				reg signed [31:0] lane;
				for (lane = 0; lane < 3; lane = lane + 1)
					if ((lane + 1) < sv2v_cast_32_signed(requestWordsInner[reqHeadSlotInner]))
						assert (!is_control(imemPacketInstructionsInput[lane * 32+:32])) else $fatal(1, "four-fetch response crossed earliest CFI");
			end
			if (((FETCH_WIDTH == 2) && responseAcceptInner) && requestInner[reqHeadSlotInner][0])
				assert (!is_control(imemResponseInput[31-:32])) else $fatal(1, "packet crossed its earliest CFI");
		end
`endif
endmodule
module rv32_rat (
	clkInput,
	rstNInput,
	freezeInput,
	readInput,
	readOutput,
	renameInput,
	renameOutput,
	readSecondInput,
	readSecondOutput,
	renameSecondInput,
	renameSecondOutput,
	restoreInput,
	recoveryInput,
	replayInput,
	commitInput
);
	parameter [31:0] COMMIT_WIDTH = 1;
	parameter [31:0] RENAME_WIDTH = 1;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [9:0] readInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	output reg [(rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W) - 1:0] readOutput;
	input wire [11:0] renameInput;
	output reg [5:0] renameOutput;
	input wire [9:0] readSecondInput;
	output wire [(rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W) - 1:0] readSecondOutput;
	input wire [11:0] renameSecondInput;
	output wire [5:0] renameSecondOutput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [10:0] restoreInput;
	input wire [22:0] recoveryInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	input wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayInput;
	input wire [(COMMIT_WIDTH * 12) - 1:0] commitInput;
	generate
		if ((RENAME_WIDTH != 1) && (RENAME_WIDTH != 2)) begin : g_invalid_rename_width
			initial $fatal(1, "RENAME_WIDTH must be 1 or 2");
		end
		if ((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1 or 2");
		end
	endgenerate
	localparam [31:0] rv32_pkg_ARCH_REGS = 32;
	reg [5:0] mapInner [0:31];
	reg [5:0] restoreMapInner [0:31];
	reg [31:0] archValidInner;
	reg [31:0] archWriteMaskInner;
	wire [(rv32_pkg_ARCH_REGS * rv32_pkg_PHY_TAG_W) - 1:0] archReadDataInner;
	reg [(rv32_pkg_ARCH_REGS * rv32_pkg_PHY_TAG_W) - 1:0] archWriteDataInner;
	reg replayActiveInner;
	reg replayActiveNext;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin
		archWriteMaskInner = 1'sb0;
		archWriteDataInner = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (((((!freezeInput && !restoreInput[10]) && !recoveryInput[22]) && commitInput[(lane * 12) + 11]) && (commitInput[(lane * 12) + 10-:5] != 0)) && (commitInput[(lane * 12) + 5-:rv32_pkg_PHY_TAG_W] != 0)) begin
					archWriteMaskInner[commitInput[(lane * 12) + 10-:5]] = 1'b1;
					archWriteDataInner[sv2v_cast_32_signed(commitInput[(lane * 12) + 10-:5]) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = commitInput[(lane * 12) + 5-:rv32_pkg_PHY_TAG_W];
				end
		end
	end
	assign archReadDataInner[0+:rv32_pkg_PHY_TAG_W] = 1'sb0;
	genvar _gv_archIndex_1;
	generate
		for (_gv_archIndex_1 = 1; _gv_archIndex_1 < rv32_pkg_ARCH_REGS; _gv_archIndex_1 = _gv_archIndex_1 + 1) begin : gen_arch_sram
			localparam archIndex = _gv_archIndex_1;
			sram_fakeram #(
				.DEPTH(1),
				.WIDTH(rv32_pkg_PHY_TAG_W),
				.WRITE_GRANULARITY(rv32_pkg_PHY_TAG_W)
			) u_arch_sram(
				.clk(clkInput),
				.en((rstNInput && !freezeInput) && (restoreInput[10] || archWriteMaskInner[archIndex])),
				.we(archWriteMaskInner[archIndex]),
				.wmask(1'b1),
				.addr(1'b0),
				.wdata(archWriteDataInner[archIndex * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W]),
				.rdata(archReadDataInner[archIndex * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W])
			);
		end
	endgenerate
	always @* begin
		readOutput[11-:6] = (readInput[9-:5] == 5'd0 ? {6 {1'sb0}} : mapInner[readInput[9-:5]]);
		readOutput[5-:rv32_pkg_PHY_TAG_W] = (readInput[4-:5] == 5'd0 ? {6 {1'sb0}} : mapInner[readInput[4-:5]]);
		renameOutput[5-:rv32_pkg_PHY_TAG_W] = (renameInput[10-:5] == 5'd0 ? {6 {1'sb0}} : mapInner[renameInput[10-:5]]);
	end
	generate
		if (RENAME_WIDTH == 2) begin : g_second_read
			assign readSecondOutput[11-:6] = (readSecondInput[9-:5] == 0 ? {6 {1'sb0}} : mapInner[readSecondInput[9-:5]]);
			assign readSecondOutput[5-:rv32_pkg_PHY_TAG_W] = (readSecondInput[4-:5] == 0 ? {6 {1'sb0}} : mapInner[readSecondInput[4-:5]]);
			assign renameSecondOutput[5-:rv32_pkg_PHY_TAG_W] = (renameSecondInput[10-:5] == 0 ? {6 {1'sb0}} : mapInner[renameSecondInput[10-:5]]);
		end
		else begin : g_no_second_read
			assign readSecondOutput = 1'sb0;
			assign renameSecondOutput = 1'sb0;
		end
	endgenerate
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	always @* begin : build_restore_map
		integer archIndexInner;
		integer laneInner;
		integer windowIndexInner;
		reg [4:0] expectedTagInner;
		replayActiveNext = (recoveryInput[21] ? 1'b1 : replayActiveInner);
		windowIndexInner = 0;
		expectedTagInner = 1'sb0;
		for (archIndexInner = 0; archIndexInner < rv32_pkg_ARCH_REGS; archIndexInner = archIndexInner + 1)
			restoreMapInner[archIndexInner] = (recoveryInput[21] ? (archValidInner[archIndexInner] ? archReadDataInner[archIndexInner * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] : sv2v_cast_A32BA(archIndexInner)) : mapInner[archIndexInner]);
		for (laneInner = 0; laneInner < rv32_pkg_RECOVERY_WIDTH; laneInner = laneInner + 1)
			begin
				windowIndexInner = sv2v_cast_32_signed(recoveryInput[19-:5]) + laneInner;
				expectedTagInner = recoveryInput[14-:5] + sv2v_cast_60734(laneInner);
				if (((recoveryInput[22] && replayActiveNext) && (windowIndexInner < rv32_pkg_ROB_ENTRIES)) && (windowIndexInner < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]))) begin
					if (replayInput[(laneInner * 16) + 15-:5] == expectedTagInner) begin
						if ((replayInput[(laneInner * 16) + 10-:5] != 0) && (replayInput[(laneInner * 16) + 5-:rv32_pkg_PHY_TAG_W] != 0))
							restoreMapInner[replayInput[(laneInner * 16) + 10-:5]] = replayInput[(laneInner * 16) + 5-:rv32_pkg_PHY_TAG_W];
						if (expectedTagInner == recoveryInput[9-:5])
							replayActiveNext = 1'b0;
					end
					else
						replayActiveNext = 1'b0;
				end
			end
		restoreMapInner[0] = 1'sb0;
	end
	function automatic signed [4:0] sv2v_cast_5_signed;
		input reg signed [4:0] inp;
		sv2v_cast_5_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput) begin : update_mappings
		integer stateIndexInner;
		if (!rstNInput) begin
			archValidInner <= 1'sb0;
			replayActiveInner <= 1'b0;
			for (stateIndexInner = 0; stateIndexInner < rv32_pkg_ARCH_REGS; stateIndexInner = stateIndexInner + 1)
				mapInner[stateIndexInner] <= sv2v_cast_A32BA(stateIndexInner);
		end
		else if (!freezeInput) begin
			if (recoveryInput[22]) begin
				replayActiveInner <= replayActiveNext;
				for (stateIndexInner = 0; stateIndexInner < rv32_pkg_ARCH_REGS; stateIndexInner = stateIndexInner + 1)
					mapInner[stateIndexInner] <= restoreMapInner[stateIndexInner];
			end
			else if (!restoreInput[10]) begin
				for (stateIndexInner = 1; stateIndexInner < rv32_pkg_ARCH_REGS; stateIndexInner = stateIndexInner + 1)
					if (((RENAME_WIDTH == 2) && renameSecondInput[11]) && (renameSecondInput[10-:5] == sv2v_cast_5_signed(stateIndexInner)))
						mapInner[stateIndexInner] <= renameSecondInput[5-:rv32_pkg_PHY_TAG_W];
					else if (renameInput[11] && (renameInput[10-:5] == sv2v_cast_5_signed(stateIndexInner)))
						mapInner[stateIndexInner] <= renameInput[5-:rv32_pkg_PHY_TAG_W];
			end
			archValidInner <= archValidInner | archWriteMaskInner;
		end
	end
endmodule
module rv32_rat_lanes (
	clkInput,
	rstNInput,
	freezeInput,
	readInput,
	readOutput,
	destinationArchInput,
	renameInput,
	renameOutput,
	restoreInput,
	recoveryInput,
	replayInput,
	commitInput
);
	parameter [31:0] LANES = 4;
	parameter [31:0] COMMIT_WIDTH = 2;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [(LANES * 10) - 1:0] readInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	output wire [(LANES * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) - 1:0] readOutput;
	input wire [(LANES * 5) - 1:0] destinationArchInput;
	input wire [(LANES * 12) - 1:0] renameInput;
	output wire [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] renameOutput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [10:0] restoreInput;
	input wire [22:0] recoveryInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	input wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayInput;
	input wire [(COMMIT_WIDTH * 12) - 1:0] commitInput;
	generate
		if (((LANES != 1) && (LANES != 2)) && (LANES != 4)) begin : g_invalid_lanes
			initial $fatal(1, "RAT LANES must be 1, 2 or 4");
		end
		if (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4)) begin : g_invalid_commit
			initial $fatal(1, "RAT COMMIT_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] rv32_pkg_ARCH_REGS = 32;
	reg [5:0] mapInner [0:31];
	reg [5:0] restoreMapInner [0:31];
	reg [31:0] archValidInner;
	reg [31:0] archWriteMaskInner;
	wire [(rv32_pkg_ARCH_REGS * rv32_pkg_PHY_TAG_W) - 1:0] archReadDataInner;
	reg [(rv32_pkg_ARCH_REGS * rv32_pkg_PHY_TAG_W) - 1:0] archWriteDataInner;
	reg replayActiveInner;
	reg replayActiveNext;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin
		archWriteMaskInner = 1'sb0;
		archWriteDataInner = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (((((!freezeInput && !restoreInput[10]) && !recoveryInput[22]) && commitInput[(lane * 12) + 11]) && (commitInput[(lane * 12) + 10-:5] != 0)) && (commitInput[(lane * 12) + 5-:rv32_pkg_PHY_TAG_W] != 0)) begin
					archWriteMaskInner[commitInput[(lane * 12) + 10-:5]] = 1'b1;
					archWriteDataInner[sv2v_cast_32_signed(commitInput[(lane * 12) + 10-:5]) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = commitInput[(lane * 12) + 5-:rv32_pkg_PHY_TAG_W];
				end
		end
	end
	assign archReadDataInner[0+:rv32_pkg_PHY_TAG_W] = 1'sb0;
	genvar _gv_archIndex_2;
	generate
		for (_gv_archIndex_2 = 1; _gv_archIndex_2 < rv32_pkg_ARCH_REGS; _gv_archIndex_2 = _gv_archIndex_2 + 1) begin : g_arch_sram
			localparam archIndex = _gv_archIndex_2;
			sram_fakeram #(
				.DEPTH(1),
				.WIDTH(rv32_pkg_PHY_TAG_W),
				.WRITE_GRANULARITY(rv32_pkg_PHY_TAG_W)
			) u_arch_sram(
				.clk(clkInput),
				.en(rstNInput && ((restoreInput[10] || (recoveryInput[22] && recoveryInput[21])) || archWriteMaskInner[archIndex])),
				.we(archWriteMaskInner[archIndex]),
				.wmask(1'b1),
				.addr(1'b0),
				.wdata(archWriteDataInner[archIndex * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W]),
				.rdata(archReadDataInner[archIndex * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W])
			);
		end
	endgenerate
	genvar _gv_lane_9;
	generate
		for (_gv_lane_9 = 0; _gv_lane_9 < LANES; _gv_lane_9 = _gv_lane_9 + 1) begin : g_read
			localparam lane = _gv_lane_9;
			assign readOutput[(lane * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) + 11-:6] = (readInput[(lane * 10) + 9-:5] == 0 ? {6 {1'sb0}} : mapInner[readInput[(lane * 10) + 9-:5]]);
			assign readOutput[(lane * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) + 5-:rv32_pkg_PHY_TAG_W] = (readInput[(lane * 10) + 4-:5] == 0 ? {6 {1'sb0}} : mapInner[readInput[(lane * 10) + 4-:5]]);
			assign renameOutput[(lane * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W] = (destinationArchInput[lane * 5+:5] == 0 ? {6 {1'sb0}} : mapInner[destinationArchInput[lane * 5+:5]]);
		end
	endgenerate
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	always @* begin : build_restore_map
		reg signed [31:0] windowIndex;
		reg [4:0] expectedTag;
		replayActiveNext = (recoveryInput[21] ? 1'b1 : replayActiveInner);
		windowIndex = 0;
		expectedTag = 1'sb0;
		begin : sv2v_autoblock_2
			reg signed [31:0] arch;
			for (arch = 0; arch < rv32_pkg_ARCH_REGS; arch = arch + 1)
				restoreMapInner[arch] = (recoveryInput[21] ? (archValidInner[arch] ? archReadDataInner[arch * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] : sv2v_cast_A32BA(arch)) : mapInner[arch]);
		end
		begin : sv2v_autoblock_3
			reg signed [31:0] lane;
			for (lane = 0; lane < rv32_pkg_RECOVERY_WIDTH; lane = lane + 1)
				begin
					windowIndex = sv2v_cast_32_signed(recoveryInput[19-:5]) + lane;
					expectedTag = recoveryInput[14-:5] + sv2v_cast_60734(lane);
					if (((recoveryInput[22] && replayActiveNext) && (windowIndex < rv32_pkg_ROB_ENTRIES)) && (windowIndex < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]))) begin
						if (replayInput[(lane * 16) + 15-:5] == expectedTag) begin
							if ((replayInput[(lane * 16) + 10-:5] != 0) && (replayInput[(lane * 16) + 5-:rv32_pkg_PHY_TAG_W] != 0))
								restoreMapInner[replayInput[(lane * 16) + 10-:5]] = replayInput[(lane * 16) + 5-:rv32_pkg_PHY_TAG_W];
							if (expectedTag == recoveryInput[9-:5])
								replayActiveNext = 1'b0;
						end
						else
							replayActiveNext = 1'b0;
					end
				end
		end
		restoreMapInner[0] = 1'sb0;
	end
	function automatic signed [4:0] sv2v_cast_5_signed;
		input reg signed [4:0] inp;
		sv2v_cast_5_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			archValidInner <= 1'sb0;
			replayActiveInner <= 1'b0;
			begin : sv2v_autoblock_4
				reg signed [31:0] arch;
				for (arch = 0; arch < rv32_pkg_ARCH_REGS; arch = arch + 1)
					mapInner[arch] <= sv2v_cast_A32BA(arch);
			end
		end
		else if (!freezeInput) begin
			if (recoveryInput[22]) begin
				replayActiveInner <= replayActiveNext;
				begin : sv2v_autoblock_5
					reg signed [31:0] arch;
					for (arch = 0; arch < rv32_pkg_ARCH_REGS; arch = arch + 1)
						mapInner[arch] <= restoreMapInner[arch];
				end
			end
			else if (!restoreInput[10]) begin : sv2v_autoblock_6
				reg signed [31:0] arch;
				for (arch = 1; arch < rv32_pkg_ARCH_REGS; arch = arch + 1)
					begin : sv2v_autoblock_7
						reg [5:0] nextPhy;
						nextPhy = mapInner[arch];
						begin : sv2v_autoblock_8
							reg signed [31:0] lane;
							for (lane = 0; lane < LANES; lane = lane + 1)
								if (renameInput[(lane * 12) + 11] && (renameInput[(lane * 12) + 10-:5] == sv2v_cast_5_signed(arch)))
									nextPhy = renameInput[(lane * 12) + 5-:rv32_pkg_PHY_TAG_W];
						end
						mapInner[arch] <= nextPhy;
					end
			end
			archValidInner <= archValidInner | archWriteMaskInner;
		end
endmodule
module rv32_prf (
	clkInput,
	rstNInput,
	freezeInput,
	allocationInput,
	allocReadyOutput,
	allocPhyOutput,
	allocationSecondInput,
	allocSecondReadyOutput,
	allocSecondPhyOutput,
	freeInput,
	restoreInput,
	recoveryInput,
	restoreCountInput,
	replayInput,
	readInput,
	readOutput,
	writebackInput,
	readyVectorOutput,
	freeCountOutput
);
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	parameter [31:0] PRF_DEPTH = rv32_pkg_PRF_ENTRIES;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	parameter [31:0] ROB_DEPTH = rv32_pkg_ROB_ENTRIES;
	parameter [31:0] WRITEBACK_PORTS = 4;
	parameter [31:0] COMMIT_WIDTH = 1;
	parameter [31:0] RENAME_WIDTH = 1;
	parameter [31:0] READ_PORTS = 3;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [33:0] allocationInput;
	output reg allocReadyOutput;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	output reg [5:0] allocPhyOutput;
	input wire [33:0] allocationSecondInput;
	output wire allocSecondReadyOutput;
	output wire [5:0] allocSecondPhyOutput;
	input wire [(COMMIT_WIDTH * 7) - 1:0] freeInput;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] restoreInput;
	input wire [22:0] recoveryInput;
	input wire [$clog2(ROB_DEPTH + 1) - 1:0] restoreCountInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	input wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayInput;
	input wire [(READ_PORTS * rv32_pkg_PHY_TAG_W) - 1:0] readInput;
	output reg [(READ_PORTS * 33) - 1:0] readOutput;
	input wire [(WRITEBACK_PORTS * 39) - 1:0] writebackInput;
	output reg [PRF_DEPTH - 1:0] readyVectorOutput;
	output reg [$clog2(PRF_DEPTH + 1) - 1:0] freeCountOutput;
	generate
		if ((RENAME_WIDTH != 1) && (RENAME_WIDTH != 2)) begin : g_invalid_rename_width
			initial $fatal(1, "RENAME_WIDTH must be 1 or 2");
		end
		if ((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1 or 2");
		end
	endgenerate
	localparam [31:0] SLOT_W = $clog2(PRF_DEPTH);
	localparam [31:0] SEQ_W = SLOT_W + 1;
	localparam [31:0] COUNT_W = $clog2(PRF_DEPTH + 1);
	localparam [31:0] RECYCLE_W = $clog2(rv32_pkg_RECOVERY_WIDTH + 1);
	localparam [31:0] VALUE_WRITERS = WRITEBACK_PORTS + 2;
	reg [31:0] valueInner [0:PRF_DEPTH - 1];
	reg [PRF_DEPTH - 1:0] readyInner;
	reg [5:0] freeListInner [0:PRF_DEPTH - 1];
	reg [SEQ_W - 1:0] freeHeadInner;
	reg [SEQ_W - 1:0] freeTailInner;
	reg [SEQ_W - 1:0] recycleTailInner;
	wire [SLOT_W - 1:0] freeHeadSlotInner;
	wire [SLOT_W - 1:0] freeTailSlotInner;
	reg [5:0] recyclePhyInner [0:rv32_pkg_RECOVERY_WIDTH - 1];
	reg [SLOT_W - 1:0] recycleSlotInner [0:rv32_pkg_RECOVERY_WIDTH - 1];
	reg [RECYCLE_W - 1:0] recycleCountInner;
	reg [5:0] selectedPhyInner;
	reg selectedValidInner;
	wire allocationFireInner;
	wire allocationSecondFireInner;
	wire [SEQ_W - 1:0] secondHeadInner;
	wire [SEQ_W - 1:0] allocatedHeadInner;
	integer seqIndexInner;
	function automatic [SLOT_W - 1:0] sv2v_cast_7C1AF;
		input reg [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	function automatic [SEQ_W - 1:0] sv2v_cast_A6A5F;
		input reg [SEQ_W - 1:0] inp;
		sv2v_cast_A6A5F = inp;
	endfunction
	function automatic [SEQ_W - 1:0] free_seq_next;
		input reg [SEQ_W - 1:0] seq;
		if (seq[SLOT_W - 1:0] == sv2v_cast_7C1AF(PRF_DEPTH - 1))
			free_seq_next = {~seq[SEQ_W - 1], {SLOT_W {1'b0}}};
		else
			free_seq_next = seq + sv2v_cast_A6A5F(1);
	endfunction
	assign freeHeadSlotInner = freeHeadInner[SLOT_W - 1:0];
	assign freeTailSlotInner = freeTailInner[SLOT_W - 1:0];
	assign allocationFireInner = allocationInput[33] && allocReadyOutput;
	assign secondHeadInner = (allocationFireInner ? free_seq_next(freeHeadInner) : freeHeadInner);
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	assign allocSecondReadyOutput = (((RENAME_WIDTH == 2) && !restoreInput[5]) && !recoveryInput[22]) && (sv2v_cast_32_signed(freeCountOutput) > sv2v_cast_32_signed(allocationFireInner));
	assign allocSecondPhyOutput = (allocSecondReadyOutput ? freeListInner[secondHeadInner[SLOT_W - 1:0]] : {rv32_pkg_PHY_TAG_W {1'sb0}});
	assign allocationSecondFireInner = ((RENAME_WIDTH == 2) && allocationSecondInput[33]) && allocSecondReadyOutput;
	assign allocatedHeadInner = (allocationSecondFireInner ? free_seq_next(secondHeadInner) : secondHeadInner);
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	always @* begin
		freeCountOutput = sv2v_cast_D4579(freeTailSlotInner) - sv2v_cast_D4579(freeHeadSlotInner);
		if (freeHeadInner[SEQ_W - 1] != freeTailInner[SEQ_W - 1])
			freeCountOutput = freeCountOutput + sv2v_cast_D4579(PRF_DEPTH);
		selectedValidInner = freeHeadInner != freeTailInner;
		selectedPhyInner = (selectedValidInner ? freeListInner[freeHeadSlotInner] : {rv32_pkg_PHY_TAG_W {1'sb0}});
		allocReadyOutput = (!restoreInput[5] && !recoveryInput[22]) && selectedValidInner;
		allocPhyOutput = selectedPhyInner;
		begin : sv2v_autoblock_1
			reg signed [31:0] portIndex;
			for (portIndex = 0; portIndex < READ_PORTS; portIndex = portIndex + 1)
				begin
					readOutput[(portIndex * 33) + 32] = (readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W] == {6 {1'sb0}} ? 1'b1 : readyInner[readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]]);
					readOutput[(portIndex * 33) + 31-:32] = (readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W] == {6 {1'sb0}} ? 32'b00000000000000000000000000000000 : valueInner[readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]]);
				end
		end
		readyVectorOutput = readyInner;
	end
	reg [RECYCLE_W - 1:0] retireCountInner;
	reg [COMMIT_WIDTH - 1:0] retireValidInner;
	reg [SLOT_W - 1:0] retireSlotInner [0:COMMIT_WIDTH - 1];
	reg [5:0] retirePhyInner [0:COMMIT_WIDTH - 1];
	reg [SLOT_W - 1:0] retireTailSlotInner;
	reg retireTailWrapInner;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_2
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_3
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic [(rv32_pkg_RECOVERY_WIDTH > 1 ? $clog2(rv32_pkg_RECOVERY_WIDTH) : 1) - 1:0] sv2v_cast_85A8C;
		input reg [(rv32_pkg_RECOVERY_WIDTH > 1 ? $clog2(rv32_pkg_RECOVERY_WIDTH) : 1) - 1:0] inp;
		sv2v_cast_85A8C = inp;
	endfunction
	function automatic signed [RECYCLE_W - 1:0] sv2v_cast_C05E3_signed;
		input reg signed [RECYCLE_W - 1:0] inp;
		sv2v_cast_C05E3_signed = inp;
	endfunction
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	function automatic [RECYCLE_W - 1:0] sv2v_cast_C05E3;
		input reg [RECYCLE_W - 1:0] inp;
		sv2v_cast_C05E3 = inp;
	endfunction
	always @* begin
		recycleCountInner = 1'sb0;
		recycleTailInner = freeTailInner;
		begin : sv2v_autoblock_4
			reg signed [31:0] k;
			for (k = 0; k < rv32_pkg_RECOVERY_WIDTH; k = k + 1)
				begin
					recyclePhyInner[k] = 1'sb0;
					recycleSlotInner[k] = 1'sb0;
				end
		end
		if (recoveryInput[22]) begin : sv2v_autoblock_5
			reg signed [31:0] lane;
			for (lane = 0; lane < rv32_pkg_RECOVERY_WIDTH; lane = lane + 1)
				if (((sv2v_cast_32_signed(recoveryInput[19-:5]) + lane) < ROB_DEPTH) && ((sv2v_cast_32_signed(recoveryInput[19-:5]) + lane) < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]))) begin
					if (((replayInput[(lane * 16) + 15-:5] == (recoveryInput[14-:5] + sv2v_cast_60734(lane))) && rv32_pkg_rob_is_younger(replayInput[(lane * 16) + 15-:5], recoveryInput[9-:5])) && (replayInput[(lane * 16) + 5-:rv32_pkg_PHY_TAG_W] != {6 {1'sb0}})) begin
						recyclePhyInner[sv2v_cast_85A8C(recycleCountInner)] = replayInput[(lane * 16) + 5-:rv32_pkg_PHY_TAG_W];
						recycleSlotInner[sv2v_cast_85A8C(recycleCountInner)] = recycleTailInner[SLOT_W - 1:0];
						recycleTailInner = free_seq_next(recycleTailInner);
						recycleCountInner = recycleCountInner + sv2v_cast_C05E3_signed(1);
					end
				end
		end
		begin : sv2v_autoblock_6
			reg [RECYCLE_W - 1:0] prefix;
			reg [SLOT_W - 1:0] preWrapped [0:COMMIT_WIDTH + 0];
			reg preWrapFlag [0:COMMIT_WIDTH + 0];
			prefix = 1'sb0;
			begin : sv2v_autoblock_7
				reg signed [31:0] k;
				for (k = 0; k <= COMMIT_WIDTH; k = k + 1)
					begin
						preWrapped[k] = sv2v_cast_7C1AF(freeTailSlotInner) + sv2v_cast_7C1AF_signed(k);
						preWrapFlag[k] = preWrapped[k] >= sv2v_cast_7C1AF(PRF_DEPTH);
						if (preWrapFlag[k])
							preWrapped[k] = preWrapped[k] - sv2v_cast_7C1AF(PRF_DEPTH);
					end
			end
			begin : sv2v_autoblock_8
				reg signed [31:0] lane;
				for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
					begin
						retireValidInner[lane] = (!restoreInput[5] && !recoveryInput[22]) && freeInput[(lane * 7) + 6];
						retireSlotInner[lane] = preWrapped[prefix];
						retirePhyInner[lane] = freeInput[(lane * 7) + 5-:rv32_pkg_PHY_TAG_W];
						prefix = prefix + sv2v_cast_C05E3(retireValidInner[lane]);
					end
			end
			retireCountInner = prefix;
			retireTailSlotInner = preWrapped[retireCountInner];
			retireTailWrapInner = preWrapFlag[retireCountInner];
		end
	end
	genvar _gv_row_3;
	localparam [31:0] rv32_pkg_ARCH_REGS = 32;
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	generate
		for (_gv_row_3 = 0; _gv_row_3 < PRF_DEPTH; _gv_row_3 = _gv_row_3 + 1) begin : g_value_write
			localparam row = _gv_row_3;
			wire [VALUE_WRITERS - 1:0] hit;
			reg [VALUE_WRITERS - 1:0] winner;
			reg [31:0] data;
			reg isReady;
			assign hit[0] = ((row != 0) && allocationFireInner) && (selectedPhyInner == sv2v_cast_A32BA(row));
			assign hit[1] = ((row != 0) && allocationSecondFireInner) && (allocSecondPhyOutput == sv2v_cast_A32BA(row));
			genvar _gv_portIndex_2;
			for (_gv_portIndex_2 = 0; _gv_portIndex_2 < WRITEBACK_PORTS; _gv_portIndex_2 = _gv_portIndex_2 + 1) begin : g_wb_hit
				localparam portIndex = _gv_portIndex_2;
				assign hit[portIndex + 2] = ((row != 0) && writebackInput[(portIndex * 39) + 38]) && (writebackInput[(portIndex * 39) + 37-:6] == sv2v_cast_A32BA(row));
			end
			always @* begin
				winner = 1'sb0;
				begin : sv2v_autoblock_9
					reg signed [31:0] writer;
					for (writer = 0; writer < VALUE_WRITERS; writer = writer + 1)
						begin : sv2v_autoblock_10
							reg later;
							later = 1'b0;
							begin : sv2v_autoblock_11
								reg signed [31:0] peer;
								for (peer = writer + 1; peer < VALUE_WRITERS; peer = peer + 1)
									later = later | hit[peer];
							end
							winner[writer] = hit[writer] && !later;
						end
				end
				data = (allocationInput[31-:32] & {32 {winner[0]}}) | (allocationSecondInput[31-:32] & {32 {winner[1]}});
				isReady = (allocationInput[32] && winner[0]) || (allocationSecondInput[32] && winner[1]);
				begin : sv2v_autoblock_12
					reg signed [31:0] portIndex;
					for (portIndex = 0; portIndex < WRITEBACK_PORTS; portIndex = portIndex + 1)
						begin
							data = data | (writebackInput[(portIndex * 39) + 31-:32] & {32 {winner[portIndex + 2]}});
							isReady = isReady | winner[portIndex + 2];
						end
				end
			end
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput) begin
					valueInner[row] <= 1'sb0;
					readyInner[row] <= row < rv32_pkg_ARCH_REGS;
				end
				else if (!freezeInput) begin
					if (row == 0) begin
						valueInner[row] <= 1'sb0;
						readyInner[row] <= 1'b1;
					end
					else if (|hit) begin
						valueInner[row] <= data;
						readyInner[row] <= isReady;
					end
				end
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			freeHeadInner <= 1'sb0;
			freeTailInner <= sv2v_cast_A6A5F(PRF_DEPTH - rv32_pkg_ARCH_REGS);
			for (seqIndexInner = 0; seqIndexInner < PRF_DEPTH; seqIndexInner = seqIndexInner + 1)
				freeListInner[seqIndexInner] <= (seqIndexInner < (PRF_DEPTH - rv32_pkg_ARCH_REGS) ? sv2v_cast_A32BA(rv32_pkg_ARCH_REGS + seqIndexInner) : sv2v_cast_A32BA(0));
		end
		else if (!freezeInput) begin
			if (allocationFireInner || allocationSecondFireInner)
				freeHeadInner <= allocatedHeadInner;
			if (recoveryInput[22] && (recycleCountInner != 0))
				freeTailInner <= recycleTailInner;
			else if (!recoveryInput[22] && (retireCountInner != 0))
				freeTailInner <= {freeTailInner[SEQ_W - 1] ^ retireTailWrapInner, retireTailSlotInner};
			begin : sv2v_autoblock_13
				reg signed [31:0] k;
				for (k = 0; k < rv32_pkg_RECOVERY_WIDTH; k = k + 1)
					if (recoveryInput[22] && (k < sv2v_cast_32_signed(recycleCountInner)))
						freeListInner[recycleSlotInner[k]] <= recyclePhyInner[k];
			end
			begin : sv2v_autoblock_14
				reg signed [31:0] lane;
				for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
					if (retireValidInner[lane])
						freeListInner[retireSlotInner[lane]] <= retirePhyInner[lane];
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin : sv2v_autoblock_15
			reg [PRF_DEPTH - 1:0] freeMembership;
			reg [SEQ_W - 1:0] scanSeq;
			freeMembership = 1'sb0;
			scanSeq = freeHeadInner;
			if (restoreInput[5])
				assert (sv2v_cast_32_signed(restoreCountInput) <= ROB_DEPTH) else $fatal(1, "invalid pre-squash ROB count");
			begin : sv2v_autoblock_16
				reg signed [31:0] age;
				for (age = 0; age < PRF_DEPTH; age = age + 1)
					if (age < sv2v_cast_32_signed(freeCountOutput)) begin
						freeMembership[freeListInner[scanSeq[SLOT_W - 1:0]]] = 1'b1;
						scanSeq = free_seq_next(scanSeq);
					end
			end
			assert ((sv2v_cast_32_signed(freeHeadSlotInner) < PRF_DEPTH) && (sv2v_cast_32_signed(freeTailSlotInner) < PRF_DEPTH)) else $fatal(1, "PRF FIFO entered a padded slot");
			assert (!freeMembership[0] && ($countones(freeMembership) == sv2v_cast_32_signed(freeCountOutput))) else $fatal(1, "PRF FIFO contains P0 or duplicate registers");
			assert (sv2v_cast_32_signed(freeCountOutput) >= (sv2v_cast_32_signed(allocationFireInner) + sv2v_cast_32_signed(allocationSecondFireInner))) else $fatal(1, "PRF allocation exceeds old free capacity");
			assert ((!allocationSecondFireInner || !allocationFireInner) || (allocSecondPhyOutput != selectedPhyInner)) else $fatal(1, "PRF allocated one physical register twice");
			assert (((((sv2v_cast_32_signed(freeCountOutput) - sv2v_cast_32_signed(allocationFireInner)) - sv2v_cast_32_signed(allocationSecondFireInner)) + sv2v_cast_32_signed(recycleCountInner)) + sv2v_cast_32_signed(retireCountInner)) <= PRF_DEPTH) else $fatal(1, "PRF FIFO overflow");
			begin : sv2v_autoblock_17
				reg signed [31:0] k;
				for (k = 0; k < rv32_pkg_RECOVERY_WIDTH; k = k + 1)
					if (k < sv2v_cast_32_signed(recycleCountInner)) begin
						assert (((recyclePhyInner[k] != 0) && (sv2v_cast_32_signed(recyclePhyInner[k]) < PRF_DEPTH)) && !freeMembership[recyclePhyInner[k]]) else $fatal(1, "PRF duplicate/invalid release");
						begin : sv2v_autoblock_18
							reg signed [31:0] j;
							for (j = 0; j < k; j = j + 1)
								assert (recyclePhyInner[k] != recyclePhyInner[j]) else $fatal(1, "PRF duplicate batch release");
						end
					end
			end
			begin : sv2v_autoblock_19
				reg signed [31:0] lane;
				for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
					if (retireValidInner[lane]) begin
						assert (((retirePhyInner[lane] != 0) && (sv2v_cast_32_signed(retirePhyInner[lane]) < PRF_DEPTH)) && !freeMembership[retirePhyInner[lane]]) else $fatal(1, "PRF duplicate/invalid retire release");
						begin : sv2v_autoblock_20
							reg signed [31:0] j;
							for (j = 0; j < lane; j = j + 1)
								assert (!retireValidInner[j] || (retirePhyInner[lane] != retirePhyInner[j])) else $fatal(1, "PRF duplicate retire batch release");
						end
					end
			end
		end
`endif
endmodule
module rv32_prf_lanes (
	clkInput,
	rstNInput,
	freezeInput,
	allocationInput,
	allocationCandidateInput,
	previewReadyOutput,
	previewPhyOutput,
	allocationFireOutput,
	allocationPhyOutput,
	freeInput,
	restoreInput,
	recoveryInput,
	restoreCountInput,
	replayInput,
	readInput,
	readOutput,
	writebackInput,
	readyVectorOutput,
	freeCountOutput,
	recycleWindowInput,
	recycleTagsInput
);
	parameter [31:0] LANES = 4;
	parameter [0:0] ALLOCATION_TAG_SIDEBAND = 1'b0;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	parameter [31:0] PRF_DEPTH = rv32_pkg_PRF_ENTRIES;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	parameter [31:0] ROB_DEPTH = rv32_pkg_ROB_ENTRIES;
	parameter [31:0] WRITEBACK_PORTS = 2;
	parameter [31:0] COMMIT_WIDTH = 2;
	parameter [31:0] READ_PORTS = 2 * LANES;
	parameter [0:0] RECYCLE_TICKET_SIDEBAND = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [(LANES * 34) - 1:0] allocationInput;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] allocationCandidateInput;
	output reg [LANES - 1:0] previewReadyOutput;
	output reg [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] previewPhyOutput;
	output reg [LANES - 1:0] allocationFireOutput;
	output reg [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] allocationPhyOutput;
	input wire [(COMMIT_WIDTH * 7) - 1:0] freeInput;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] restoreInput;
	input wire [22:0] recoveryInput;
	input wire [$clog2(ROB_DEPTH + 1) - 1:0] restoreCountInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	input wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayInput;
	input wire [(READ_PORTS * rv32_pkg_PHY_TAG_W) - 1:0] readInput;
	output reg [(READ_PORTS * 33) - 1:0] readOutput;
	input wire [(WRITEBACK_PORTS * 39) - 1:0] writebackInput;
	output wire [PRF_DEPTH - 1:0] readyVectorOutput;
	output reg [$clog2(PRF_DEPTH + 1) - 1:0] freeCountOutput;
	input wire [rv32_pkg_RECOVERY_WIDTH - 1:0] recycleWindowInput;
	input wire [(rv32_pkg_RECOVERY_WIDTH * rv32_pkg_ROB_TAG_W) - 1:0] recycleTagsInput;
	localparam signed [31:0] SLOT_W = $clog2(PRF_DEPTH);
	localparam signed [31:0] SEQ_W = SLOT_W + 1;
	localparam signed [31:0] COUNT_W = $clog2(PRF_DEPTH + 1);
	localparam signed [31:0] RECYCLE_W = $clog2(rv32_pkg_RECOVERY_WIDTH + 1);
	localparam signed [31:0] VALUE_WRITERS = LANES + WRITEBACK_PORTS;
	generate
		if (((LANES != 1) && (LANES != 2)) && (LANES != 4)) begin : g_invalid_lanes
			initial $fatal(1, "PRF LANES must be 1, 2 or 4");
		end
		if (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4)) begin : g_invalid_commit
			initial $fatal(1, "PRF COMMIT_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] rv32_pkg_ARCH_REGS = 32;
	generate
		if ((PRF_DEPTH <= rv32_pkg_ARCH_REGS) || (PRF_DEPTH > 64)) begin : g_invalid_depth
			initial $fatal(1, "PRF lane capacity outside physical identity range");
		end
	endgenerate
	wire [31:0] bankReadInner [0:PRF_DEPTH - 1];
	reg [PRF_DEPTH - 1:0] everWrittenInner;
	reg [VALUE_WRITERS - 1:0] priorWriteValidInner;
	reg [(VALUE_WRITERS * rv32_pkg_PHY_TAG_W) - 1:0] priorWritePhyInner;
	reg [(VALUE_WRITERS * 32) - 1:0] priorWriteDataInner;
	reg [PRF_DEPTH - 1:0] readyInner;
	reg [5:0] freeListInner [0:PRF_DEPTH - 1];
	reg [SEQ_W - 1:0] freeHeadInner;
	reg [SEQ_W - 1:0] freeTailInner;
	reg [SEQ_W - 1:0] allocatedHeadInner;
	reg [SEQ_W - 1:0] recycleTailInner;
	reg [5:0] recyclePhyInner [0:rv32_pkg_RECOVERY_WIDTH - 1];
	reg [SLOT_W - 1:0] recycleSlotInner [0:rv32_pkg_RECOVERY_WIDTH - 1];
	reg [RECYCLE_W - 1:0] recycleCountInner;
	reg [$clog2(LANES + 1) - 1:0] allocatedCountInner;
	wire [rv32_pkg_RECOVERY_WIDTH - 1:0] replayEligibleInner;
	function automatic [SLOT_W - 1:0] sv2v_cast_7C1AF;
		input reg [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	function automatic [SEQ_W - 1:0] sv2v_cast_A6A5F;
		input reg [SEQ_W - 1:0] inp;
		sv2v_cast_A6A5F = inp;
	endfunction
	function automatic [SEQ_W - 1:0] free_seq_next;
		input reg [SEQ_W - 1:0] seq;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if (seq[SLOT_W - 1:0] == sv2v_cast_7C1AF(PRF_DEPTH - 1)) begin
				free_seq_next = {~seq[SEQ_W - 1], {SLOT_W {1'b0}}};
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				free_seq_next = seq + sv2v_cast_A6A5F(1);
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin : old_credit_preview
		reg [SEQ_W - 1:0] cursor;
		cursor = freeHeadInner;
		freeCountOutput = sv2v_cast_D4579(freeTailInner[SLOT_W - 1:0]) - sv2v_cast_D4579(freeHeadInner[SLOT_W - 1:0]);
		if (freeHeadInner[SEQ_W - 1] != freeTailInner[SEQ_W - 1])
			freeCountOutput = freeCountOutput + sv2v_cast_D4579(PRF_DEPTH);
		begin : sv2v_autoblock_1
			reg signed [31:0] rank;
			for (rank = 0; rank < LANES; rank = rank + 1)
				begin
					previewReadyOutput[rank] = ((!freezeInput && !restoreInput[5]) && !recoveryInput[22]) && (sv2v_cast_32_signed(freeCountOutput) > rank);
					previewPhyOutput[rank * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = (previewReadyOutput[rank] ? freeListInner[cursor[SLOT_W - 1:0]] : {6 {1'sb0}});
					cursor = free_seq_next(cursor);
				end
		end
	end
	function automatic signed [$clog2(LANES + 1) - 1:0] sv2v_cast_95EEB_signed;
		input reg signed [$clog2(LANES + 1) - 1:0] inp;
		sv2v_cast_95EEB_signed = inp;
	endfunction
	always @* begin : consume_by_destination_rank
		reg signed [31:0] used;
		used = 0;
		allocatedHeadInner = freeHeadInner;
		allocationFireOutput = 1'sb0;
		allocationPhyOutput = 1'sb0;
		begin : sv2v_autoblock_2
			reg signed [31:0] lane;
			for (lane = 0; lane < LANES; lane = lane + 1)
				if ((((!freezeInput && !restoreInput[5]) && !recoveryInput[22]) && allocationInput[(lane * 34) + 33]) && (used < sv2v_cast_32_signed(freeCountOutput))) begin
					allocationFireOutput[lane] = 1'b1;
					allocationPhyOutput[lane * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = previewPhyOutput[used * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W];
					allocatedHeadInner = free_seq_next(allocatedHeadInner);
					used = used + 1;
				end
		end
		allocatedCountInner = sv2v_cast_95EEB_signed(used);
	end
	genvar _gv_portIndex_3;
	generate
		for (_gv_portIndex_3 = 0; _gv_portIndex_3 < READ_PORTS; _gv_portIndex_3 = _gv_portIndex_3 + 1) begin : g_read
			localparam portIndex = _gv_portIndex_3;
			wire [1:1] sv2v_tmp_772F4;
			assign sv2v_tmp_772F4 = (readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W] == 0 ? 1'b1 : readyInner[readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]]);
			always @(*) readOutput[(portIndex * 33) + 32] = sv2v_tmp_772F4;
			always @* begin : read_with_last_edge_forwarding
				readOutput[(portIndex * 33) + 31-:32] = 1'sb0;
				if (readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W] != 0) begin
					if (everWrittenInner[readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]])
						readOutput[(portIndex * 33) + 31-:32] = bankReadInner[readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]];
					begin : sv2v_autoblock_3
						reg signed [31:0] writer;
						for (writer = 0; writer < VALUE_WRITERS; writer = writer + 1)
							if (priorWriteValidInner[writer] && (priorWritePhyInner[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] == readInput[(portIndex * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]))
								readOutput[(portIndex * 33) + 31-:32] = priorWriteDataInner[writer * 32+:32];
					end
				end
			end
		end
	endgenerate
	assign readyVectorOutput = readyInner;
	genvar _gv_writer_1;
	generate
		for (_gv_writer_1 = 0; _gv_writer_1 < VALUE_WRITERS; _gv_writer_1 = _gv_writer_1 + 1) begin : g_write_history
			localparam writer = _gv_writer_1;
			wire valid;
			wire [5:0] tag;
			wire [31:0] value;
			if (writer < LANES) begin : g_allocation
				assign valid = allocationFireOutput[writer] && (allocationPhyOutput[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] != 0);
				assign tag = allocationPhyOutput[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W];
				assign value = allocationInput[(writer * 34) + 31-:32];
			end
			else begin : g_writeback
				assign valid = writebackInput[((writer - LANES) * 39) + 38] && (writebackInput[((writer - LANES) * 39) + 37-:6] != 0);
				assign tag = writebackInput[((writer - LANES) * 39) + 37-:6];
				assign value = writebackInput[((writer - LANES) * 39) + 31-:32];
			end
			always_ff @(posedge clkInput) begin
				priorWritePhyInner[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] <= tag;
				priorWriteDataInner[writer * 32+:32] <= value;
			end
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					priorWriteValidInner[writer] <= 1'b0;
				else
					priorWriteValidInner[writer] <= !freezeInput && valid;
		end
	endgenerate
	genvar _gv_lane_10;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_4
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_5
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	generate
		for (_gv_lane_10 = 0; _gv_lane_10 < rv32_pkg_RECOVERY_WIDTH; _gv_lane_10 = _gv_lane_10 + 1) begin : g_recycle_identity
			localparam lane = _gv_lane_10;
			if (RECYCLE_TICKET_SIDEBAND) begin : g_early
				assign replayEligibleInner[lane] = recycleWindowInput[lane] && (replayInput[(lane * 16) + 15-:5] == recycleTagsInput[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W]);
			end
			else begin : g_local
				assign replayEligibleInner[lane] = ((((sv2v_cast_32_signed(recoveryInput[19-:5]) + lane) < ROB_DEPTH) && ((sv2v_cast_32_signed(recoveryInput[19-:5]) + lane) < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]))) && (replayInput[(lane * 16) + 15-:5] == (recoveryInput[14-:5] + sv2v_cast_60734(lane)))) && rv32_pkg_rob_is_younger(replayInput[(lane * 16) + 15-:5], recoveryInput[9-:5]);
			end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (((rstNInput && !freezeInput) && recoveryInput[22]) && RECYCLE_TICKET_SIDEBAND) begin
					assert (recycleTagsInput[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] == (recoveryInput[14-:5] + sv2v_cast_60734(lane))) else $fatal(1, "PRF replay ticket tag differs from replay cursor");
					assert (replayEligibleInner[lane] == (((((sv2v_cast_32_signed(recoveryInput[19-:5]) + lane) < ROB_DEPTH) && ((sv2v_cast_32_signed(recoveryInput[19-:5]) + lane) < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]))) && (replayInput[(lane * 16) + 15-:5] == (recoveryInput[14-:5] + sv2v_cast_60734(lane)))) && rv32_pkg_rob_is_younger(replayInput[(lane * 16) + 15-:5], recoveryInput[9-:5]))) else $fatal(1, "PRF replay ticket changes a release");
				end
`endif
		end
	endgenerate
	function automatic [(rv32_pkg_RECOVERY_WIDTH > 1 ? $clog2(rv32_pkg_RECOVERY_WIDTH) : 1) - 1:0] sv2v_cast_85A8C;
		input reg [(rv32_pkg_RECOVERY_WIDTH > 1 ? $clog2(rv32_pkg_RECOVERY_WIDTH) : 1) - 1:0] inp;
		sv2v_cast_85A8C = inp;
	endfunction
	always @* begin : release_old_physical
		recycleCountInner = 1'sb0;
		recycleTailInner = freeTailInner;
		begin : sv2v_autoblock_6
			reg signed [31:0] k;
			for (k = 0; k < rv32_pkg_RECOVERY_WIDTH; k = k + 1)
				begin
					recyclePhyInner[k] = 1'sb0;
					recycleSlotInner[k] = 1'sb0;
				end
		end
		if (recoveryInput[22]) begin : sv2v_autoblock_7
			reg signed [31:0] lane;
			for (lane = 0; lane < rv32_pkg_RECOVERY_WIDTH; lane = lane + 1)
				if (replayEligibleInner[lane] && (replayInput[(lane * 16) + 5-:rv32_pkg_PHY_TAG_W] != 0)) begin
					recyclePhyInner[sv2v_cast_85A8C(recycleCountInner)] = replayInput[(lane * 16) + 5-:rv32_pkg_PHY_TAG_W];
					recycleSlotInner[sv2v_cast_85A8C(recycleCountInner)] = recycleTailInner[SLOT_W - 1:0];
					recycleTailInner = free_seq_next(recycleTailInner);
					recycleCountInner = recycleCountInner + 1;
				end
		end
		begin : sv2v_autoblock_8
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (((!restoreInput[5] && !recoveryInput[22]) && freeInput[(lane * 7) + 6]) && (freeInput[(lane * 7) + 5-:rv32_pkg_PHY_TAG_W] != 0)) begin
					recyclePhyInner[sv2v_cast_85A8C(recycleCountInner)] = freeInput[(lane * 7) + 5-:rv32_pkg_PHY_TAG_W];
					recycleSlotInner[sv2v_cast_85A8C(recycleCountInner)] = recycleTailInner[SLOT_W - 1:0];
					recycleTailInner = free_seq_next(recycleTailInner);
					recycleCountInner = recycleCountInner + 1;
				end
		end
	end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput && ALLOCATION_TAG_SIDEBAND) begin : sv2v_autoblock_9
			reg signed [31:0] lane;
			for (lane = 0; lane < LANES; lane = lane + 1)
				if (allocationFireOutput[lane])
					assert (allocationCandidateInput[lane * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] == allocationPhyOutput[lane * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W]) else $fatal(1, "PRF early destination disagrees with actual allocation");
		end
`endif
	wire [VALUE_WRITERS - 1:0] writeValidInner;
	wire [VALUE_WRITERS - 1:0] writeReadyInner;
	reg [VALUE_WRITERS - 1:0] writeWinnerInner;
	wire [(VALUE_WRITERS * rv32_pkg_PHY_TAG_W) - 1:0] writeTagInner;
	wire [(VALUE_WRITERS * 32) - 1:0] writeDataInner;
	genvar _gv_writer_2;
	generate
		for (_gv_writer_2 = 0; _gv_writer_2 < VALUE_WRITERS; _gv_writer_2 = _gv_writer_2 + 1) begin : g_global_writer
			localparam writer = _gv_writer_2;
			if (writer < LANES) begin : g_alloc
				assign writeValidInner[writer] = allocationFireOutput[writer];
				assign writeTagInner[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = (ALLOCATION_TAG_SIDEBAND ? allocationCandidateInput[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] : allocationPhyOutput[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W]);
				assign writeDataInner[writer * 32+:32] = allocationInput[(writer * 34) + 31-:32];
				assign writeReadyInner[writer] = allocationInput[(writer * 34) + 32];
			end
			else begin : g_wb
				assign writeValidInner[writer] = writebackInput[((writer - LANES) * 39) + 38];
				assign writeTagInner[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = writebackInput[((writer - LANES) * 39) + 37-:6];
				assign writeDataInner[writer * 32+:32] = writebackInput[((writer - LANES) * 39) + 31-:32];
				assign writeReadyInner[writer] = 1'b1;
			end
			always @* begin : resolve_same_tag
				reg later;
				later = 1'b0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_10
`else
				begin : sv2v_autoblock_9
`endif
					reg signed [31:0] peer;
					for (peer = writer + 1; peer < VALUE_WRITERS; peer = peer + 1)
						later = later | (writeValidInner[peer] && (writeTagInner[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] == writeTagInner[peer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W]));
				end
				writeWinnerInner[writer] = writeValidInner[writer] && !later;
			end
		end
	endgenerate
	genvar _gv_row_4;
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	generate
		for (_gv_row_4 = 0; _gv_row_4 < PRF_DEPTH; _gv_row_4 = _gv_row_4 + 1) begin : g_value_write
			localparam row = _gv_row_4;
			wire [VALUE_WRITERS - 1:0] hit;
			reg [31:0] data;
			reg isReady;
			genvar _gv_writer_3;
			for (_gv_writer_3 = 0; _gv_writer_3 < VALUE_WRITERS; _gv_writer_3 = _gv_writer_3 + 1) begin : g_hit
				localparam writer = _gv_writer_3;
				assign hit[writer] = ((row != 0) && writeWinnerInner[writer]) && (writeTagInner[writer * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] == sv2v_cast_A32BA(row));
			end
			always @* begin
				data = 1'sb0;
				isReady = 1'b0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_11
`else
				begin : sv2v_autoblock_10
`endif
					reg signed [31:0] writer;
					for (writer = 0; writer < VALUE_WRITERS; writer = writer + 1)
						begin
							data = data | (writeDataInner[writer * 32+:32] & {32 {hit[writer]}});
							isReady = isReady | (writeReadyInner[writer] && hit[writer]);
						end
				end
			end
			if (row == 0) begin : g_zero
				assign bankReadInner[row] = 1'sb0;
			end
			else begin : g_payload_sram
				sram_fakeram #(
					.DEPTH(1),
					.WIDTH(32),
					.WRITE_GRANULARITY(32)
				) u_payload(
					.clk(clkInput),
					.en(rstNInput),
					.we(!freezeInput && |hit),
					.wmask(1'b1),
					.addr(1'b0),
					.wdata(data),
					.rdata(bankReadInner[row])
				);
			end
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput) begin
					readyInner[row] <= row < rv32_pkg_ARCH_REGS;
					everWrittenInner[row] <= 1'b0;
				end
				else if (!freezeInput) begin
					if (row == 0)
						readyInner[row] <= 1'b1;
					else if (|hit) begin
						readyInner[row] <= isReady;
						everWrittenInner[row] <= 1'b1;
					end
				end
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			freeHeadInner <= 1'sb0;
			freeTailInner <= sv2v_cast_A6A5F(PRF_DEPTH - rv32_pkg_ARCH_REGS);
`ifndef SYNTHESIS
			begin : sv2v_autoblock_12
`else
			begin : sv2v_autoblock_11
`endif
				reg signed [31:0] k;
				for (k = 0; k < PRF_DEPTH; k = k + 1)
					freeListInner[k] <= (k < (PRF_DEPTH - rv32_pkg_ARCH_REGS) ? sv2v_cast_A32BA(rv32_pkg_ARCH_REGS + k) : {rv32_pkg_PHY_TAG_W {1'sb0}});
			end
		end
		else if (!freezeInput) begin
			if (allocatedCountInner != 0)
				freeHeadInner <= allocatedHeadInner;
			if (recycleCountInner != 0)
				freeTailInner <= recycleTailInner;
`ifndef SYNTHESIS
			begin : sv2v_autoblock_13
`else
			begin : sv2v_autoblock_12
`endif
				reg signed [31:0] k;
				for (k = 0; k < rv32_pkg_RECOVERY_WIDTH; k = k + 1)
					if (k < sv2v_cast_32_signed(recycleCountInner))
						freeListInner[recycleSlotInner[k]] <= recyclePhyInner[k];
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin : sv2v_autoblock_14
			reg [PRF_DEPTH - 1:0] membership;
			reg [SEQ_W - 1:0] cursor;
			membership = 1'sb0;
			cursor = freeHeadInner;
			begin : sv2v_autoblock_15
				reg signed [31:0] age;
				for (age = 0; age < PRF_DEPTH; age = age + 1)
					if (age < sv2v_cast_32_signed(freeCountOutput)) begin
						membership[freeListInner[cursor[SLOT_W - 1:0]]] = 1'b1;
						cursor = free_seq_next(cursor);
					end
			end
			assert (!membership[0] && ($countones(membership) == sv2v_cast_32_signed(freeCountOutput))) else $fatal(1, "lane PRF free FIFO duplicate/P0");
			assert ((sv2v_cast_32_signed(freeHeadInner[SLOT_W - 1:0]) < PRF_DEPTH) && (sv2v_cast_32_signed(freeTailInner[SLOT_W - 1:0]) < PRF_DEPTH)) else $fatal(1, "lane PRF FIFO padded slot");
			assert ((sv2v_cast_32_signed(freeCountOutput) >= sv2v_cast_32_signed(allocatedCountInner)) && (((sv2v_cast_32_signed(freeCountOutput) - sv2v_cast_32_signed(allocatedCountInner)) + sv2v_cast_32_signed(recycleCountInner)) <= PRF_DEPTH)) else $fatal(1, "lane PRF credit overflow");
			if (restoreInput[5])
				assert (sv2v_cast_32_signed(restoreCountInput) <= ROB_DEPTH) else $fatal(1, "lane PRF invalid pre-squash count");
			begin : sv2v_autoblock_16
				reg signed [31:0] k;
				for (k = 0; k < rv32_pkg_RECOVERY_WIDTH; k = k + 1)
					if (k < sv2v_cast_32_signed(recycleCountInner)) begin
						assert (((recyclePhyInner[k] != 0) && (sv2v_cast_32_signed(recyclePhyInner[k]) < PRF_DEPTH)) && !membership[recyclePhyInner[k]]) else $fatal(1, "lane PRF duplicate/invalid release");
						begin : sv2v_autoblock_17
							reg signed [31:0] j;
							for (j = 0; j < k; j = j + 1)
								assert (recyclePhyInner[k] != recyclePhyInner[j]) else $fatal(1, "lane PRF duplicate batch release");
						end
					end
			end
			begin : sv2v_autoblock_18
				reg signed [31:0] lane;
				for (lane = 0; lane < LANES; lane = lane + 1)
					begin : sv2v_autoblock_19
						reg signed [31:0] older;
						for (older = 0; older < lane; older = older + 1)
							assert ((!allocationFireOutput[lane] || !allocationFireOutput[older]) || (allocationPhyOutput[lane * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] != allocationPhyOutput[older * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W])) else $fatal(1, "lane PRF duplicate allocation");
					end
			end
		end
`endif
endmodule
module rv32_rob (
	clkInput,
	rstNInput,
	freezeInput,
	allocInput,
	allocReadyOutput,
	allocTagOutput,
	allocSecondInput,
	allocSecondReadyOutput,
	allocSecondTagOutput,
	completionInput,
	storeReadyInput,
	flushInput,
	lookupInput,
	lookupOutput,
	commitOutput,
	commitStoreOutput,
	commitReadyInput,
	commitFireOutput,
	statusOutput,
	countOutput,
	replayOffsetInput,
	replayNarrowOutput,
	replayRasOutput
);
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	parameter [31:0] DEPTH = rv32_pkg_ROB_ENTRIES;
	parameter [31:0] COMMIT_WIDTH = 1;
	parameter [31:0] RENAME_WIDTH = 1;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	localparam [31:0] rv32_pkg_SQ_SLOT_W = 2;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] allocInput;
	output reg allocReadyOutput;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	output reg [4:0] allocTagOutput;
	input wire [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] allocSecondInput;
	output wire allocSecondReadyOutput;
	output wire [4:0] allocSecondTagOutput;
	input wire [41:0] completionInput;
	input wire [(rv32_pkg_ROB_ENTRIES + rv32_pkg_ROB_ENTRIES) - 1:0] storeReadyInput;
	input wire [5:0] flushInput;
	input wire [24:0] lookupInput;
	output wire [(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (5 * ((65 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (5 * (1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((65 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] lookupOutput;
	output reg [(COMMIT_WIDTH * 93) - 1:0] commitOutput;
	output reg [COMMIT_WIDTH - 1:0] commitStoreOutput;
	input wire [COMMIT_WIDTH - 1:0] commitReadyInput;
	output reg [COMMIT_WIDTH - 1:0] commitFireOutput;
	output reg [6:0] statusOutput;
	output reg [$clog2(DEPTH + 1) - 1:0] countOutput;
	input wire [4:0] replayOffsetInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	output wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayNarrowOutput;
	output wire [(rv32_pkg_RECOVERY_WIDTH * 39) - 1:0] replayRasOutput;
	generate
		if ((RENAME_WIDTH != 1) && (RENAME_WIDTH != 2)) begin : g_invalid_rename_width
			initial $fatal(1, "RENAME_WIDTH must be 1 or 2");
		end
		if ((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1 or 2");
		end
	endgenerate
	localparam [31:0] SLOT_W = $clog2(DEPTH);
	localparam [31:0] COUNT_W = $clog2(DEPTH + 1);
	reg validInner [0:DEPTH - 1];
	reg [4:0] tagInner [0:DEPTH - 1];
	reg readyInner [0:DEPTH - 1];
	reg [31:0] pcInner [0:DEPTH - 1];
	reg [31:0] instrInner [0:DEPTH - 1];
	reg writesRdInner [0:DEPTH - 1];
	reg [4:0] archRdInner [0:DEPTH - 1];
	reg [5:0] newPhyInner [0:DEPTH - 1];
	reg [5:0] oldPhyInner [0:DEPTH - 1];
	reg storeInner [0:DEPTH - 1];
	reg [1:0] sqIndexInner [0:DEPTH - 1];
	reg haltInner [0:DEPTH - 1];
	reg [31:0] predictedPcInner [0:DEPTH - 1];
	reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] predictorCkptIdInner [0:DEPTH - 1];
	reg isRetInner [0:DEPTH - 1];
	reg [4:0] headInner;
	reg [4:0] tailInner;
	reg [$clog2(DEPTH + 1) - 1:0] countInner;
	reg [SLOT_W - 1:0] headSlotInner;
	reg [SLOT_W - 1:0] tailSlotInner;
	wire [4:0] flushCountInner;
	wire [COUNT_W - 1:0] flushCountAfterCommitInner;
	integer iInner;
	wire [4:0] flushTagNext;
	wire [4:0] headNext;
	wire [4:0] tailNext;
	wire [COUNT_W - 1:0] countUpInner;
	wire [COUNT_W - 1:0] countDownInner;
	wire unusedCoutFlushTagInner;
	wire unusedBorrowFlushInner;
	wire unusedCoutHeadInner;
	wire unusedCoutTailInner;
	wire unusedCoutCountUpInner;
	wire unusedBorrowCountDownInner;
	wire unusedBorrowFlushCommitInner;
	reg [DEPTH - 1:0] readySetInner;
	wire [DEPTH - 1:0] storeBitmapReadyInner;
	reg [COUNT_W - 1:0] commitCountInner;
	wire allocFireInner;
	wire allocSecondFireInner;
	wire [COUNT_W - 1:0] allocCountInner;
	wire [SLOT_W - 1:0] secondSlotInner;
	assign allocFireInner = allocInput[71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))] && allocReadyOutput;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	assign allocSecondReadyOutput = ((RENAME_WIDTH == 2) && !flushInput[5]) && (sv2v_cast_32_signed(countInner) <= (DEPTH - 2));
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	assign allocSecondTagOutput = tailInner + sv2v_cast_60734(1);
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	assign secondSlotInner = tailSlotInner + sv2v_cast_7C1AF_signed(1);
	assign allocSecondFireInner = (((RENAME_WIDTH == 2) && allocFireInner) && allocSecondInput[71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))]) && allocSecondReadyOutput;
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	assign allocCountInner = sv2v_cast_D4579(allocFireInner) + sv2v_cast_D4579(allocSecondFireInner);
	generate
		if (COMMIT_WIDTH == 1) begin : g_single_commit
			wire [COUNT_W:1] sv2v_tmp_3212D;
			assign sv2v_tmp_3212D = sv2v_cast_D4579(commitFireOutput[0]);
			always @(*) commitCountInner = sv2v_tmp_3212D;
			wire [1:1] sv2v_tmp_FE65F;
			assign sv2v_tmp_FE65F = commitOutput[92] && commitReadyInput[0];
			always @(*) commitFireOutput[0] = sv2v_tmp_FE65F;
		end
		else begin : g_dual_commit
			always @* begin
				commitCountInner = 1'sb0;
				begin : sv2v_autoblock_1
					reg signed [31:0] lane;
					for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
						commitCountInner = commitCountInner + sv2v_cast_D4579(commitFireOutput[lane]);
				end
			end
			always @* begin : commit_prefix
				reg open;
				open = 1'b1;
				begin : sv2v_autoblock_2
					reg signed [31:0] lane;
					for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
						begin
							commitFireOutput[lane] = (open && commitOutput[(lane * 93) + 92]) && commitReadyInput[lane];
							open = commitFireOutput[lane];
						end
				end
			end
		end
	endgenerate
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_3
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_4
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	always @* begin
		readySetInner = 1'sb0;
		begin : sv2v_autoblock_5
			reg signed [31:0] row;
			for (row = 0; row < DEPTH; row = row + 1)
				if (validInner[row] && (!flushInput[5] || rv32_pkg_rob_is_older(tagInner[row], flushInput[4-:rv32_pkg_ROB_TAG_W]))) begin
					if (storeInner[row] && storeBitmapReadyInner[row])
						readySetInner[row] = 1'b1;
					begin : sv2v_autoblock_6
						reg signed [31:0] portIndex;
						for (portIndex = 0; portIndex < 6; portIndex = portIndex + 1)
							if (completionInput[(portIndex * 7) + 6] && (completionInput[(portIndex * 7) + 5-:5] == tagInner[row]))
								readySetInner[row] = 1'b1;
					end
				end
		end
	end
	genvar _gv_row_5;
	generate
		for (_gv_row_5 = 0; _gv_row_5 < DEPTH; _gv_row_5 = _gv_row_5 + 1) begin : gen_ready_write
			localparam row = _gv_row_5;
			if (DEPTH == rv32_pkg_ROB_ENTRIES) begin : gen_constant_bitmap_slot
				assign storeBitmapReadyInner[row] = storeReadyInput[16 + row] && (storeReadyInput[0 + row] == tagInner[row][4]);
			end
			else begin : gen_full_tag_bitmap_slot
				assign storeBitmapReadyInner[row] = storeReadyInput[16 + tagInner[row][3:0]] && (storeReadyInput[0 + tagInner[row][3:0]] == tagInner[row][4]);
			end
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					readyInner[row] <= 1'b0;
				else if (((!freezeInput && allocInput[71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))]) && allocReadyOutput) && (tailSlotInner == sv2v_cast_7C1AF_signed(row)))
					readyInner[row] <= allocInput[2 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))] || allocInput[34 + (rv32_pkg_BPU_CKPT_ID_W + 0)];
				else if ((!freezeInput && allocSecondFireInner) && (secondSlotInner == sv2v_cast_7C1AF_signed(row)))
					readyInner[row] <= allocSecondInput[2 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))] || allocSecondInput[34 + (rv32_pkg_BPU_CKPT_ID_W + 0)];
				else if (!freezeInput && readySetInner[row])
					readyInner[row] <= 1'b1;
		end
	endgenerate
	genvar _gv_replayIndexInner_1;
	localparam [6:0] rv32_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32_pkg_OPCODE_JALR = 7'b1100111;
	function automatic [1:0] rv32_pkg_ras_replay_actions;
		input reg [19:0] insn;
		reg ind;
		reg linkRd;
		reg linkRs;
		begin
			ind = (insn[6:0] == rv32_pkg_OPCODE_JALR) && (insn[14:12] == 3'b000);
			linkRd = {insn[11:10], insn[8:7]} == 4'b0001;
			linkRs = {insn[19:18], insn[16:15]} == 4'b0001;
			rv32_pkg_ras_replay_actions = {(ind && linkRs) && (insn[11:7] != insn[19:15]), linkRd && ((insn[6:0] == rv32_pkg_OPCODE_JAL) || ind)};
		end
	endfunction
	function automatic [SLOT_W - 1:0] sv2v_cast_7C1AF;
		input reg [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	generate
		for (_gv_replayIndexInner_1 = 0; _gv_replayIndexInner_1 < rv32_pkg_RECOVERY_WIDTH; _gv_replayIndexInner_1 = _gv_replayIndexInner_1 + 1) begin : gen_replay_window
			localparam replayIndexInner = _gv_replayIndexInner_1;
			wire [SLOT_W - 1:0] replaySlotInner;
			assign replaySlotInner = (headInner[SLOT_W - 1:0] + sv2v_cast_7C1AF(replayOffsetInput)) + sv2v_cast_7C1AF_signed(replayIndexInner);
			assign replayNarrowOutput[replayIndexInner * 16+:16] = {sv2v_cast_60734(tagInner[replaySlotInner]), archRdInner[replaySlotInner], sv2v_cast_A32BA(newPhyInner[replaySlotInner])};
			assign replayRasOutput[0 + (replayIndexInner * 39)+:39] = {sv2v_cast_60734(tagInner[replaySlotInner]), pcInner[replaySlotInner], rv32_pkg_ras_replay_actions(instrInner[replaySlotInner][19:0])};
		end
	endgenerate
	function automatic signed [4:0] sv2v_cast_60734_signed;
		input reg signed [4:0] inp;
		sv2v_cast_60734_signed = inp;
	endfunction
	rv32_add #(.WIDTH(rv32_pkg_ROB_TAG_W)) u_flush_tag_next(
		.aInput(flushInput[4-:rv32_pkg_ROB_TAG_W]),
		.bInput(sv2v_cast_60734_signed(1)),
		.cinInput(1'b0),
		.sumOutput(flushTagNext),
		.coutOutput(unusedCoutFlushTagInner)
	);
	rv32_sub #(.WIDTH(rv32_pkg_ROB_TAG_W)) u_flush_count(
		.aInput(flushTagNext),
		.bInput(headInner),
		.diffOutput(flushCountInner),
		.borrowOutput(unusedBorrowFlushInner)
	);
	rv32_add #(.WIDTH(rv32_pkg_ROB_TAG_W)) u_head_next(
		.aInput(headInner),
		.bInput(sv2v_cast_60734(commitCountInner)),
		.cinInput(1'b0),
		.sumOutput(headNext),
		.coutOutput(unusedCoutHeadInner)
	);
	rv32_add #(.WIDTH(rv32_pkg_ROB_TAG_W)) u_tail_next(
		.aInput(tailInner),
		.bInput(sv2v_cast_60734(allocCountInner)),
		.cinInput(1'b0),
		.sumOutput(tailNext),
		.coutOutput(unusedCoutTailInner)
	);
	function automatic signed [COUNT_W - 1:0] sv2v_cast_D4579_signed;
		input reg signed [COUNT_W - 1:0] inp;
		sv2v_cast_D4579_signed = inp;
	endfunction
	rv32_add #(.WIDTH(COUNT_W)) u_count_up(
		.aInput(countInner),
		.bInput(sv2v_cast_D4579_signed(1)),
		.cinInput(1'b0),
		.sumOutput(countUpInner),
		.coutOutput(unusedCoutCountUpInner)
	);
	rv32_sub #(.WIDTH(COUNT_W)) u_count_down(
		.aInput(countInner),
		.bInput(commitCountInner),
		.diffOutput(countDownInner),
		.borrowOutput(unusedBorrowCountDownInner)
	);
	rv32_sub #(.WIDTH(COUNT_W)) u_flush_count_after_commit(
		.aInput(flushCountInner[COUNT_W - 1:0]),
		.bInput(commitCountInner),
		.diffOutput(flushCountAfterCommitInner),
		.borrowOutput(unusedBorrowFlushCommitInner)
	);
	always @* begin
		headSlotInner = headInner[SLOT_W - 1:0];
		tailSlotInner = tailInner[SLOT_W - 1:0];
		statusOutput[6] = countInner == {$clog2(DEPTH + 1) {1'sb0}};
		statusOutput[5] = countInner == sv2v_cast_D4579(DEPTH);
		countOutput = countInner;
		statusOutput[4-:rv32_pkg_ROB_TAG_W] = headInner;
		allocTagOutput = tailInner;
		allocReadyOutput = !flushInput[5] && !statusOutput[5];
	end
	genvar _gv_portIndex_4;
	generate
		for (_gv_portIndex_4 = 0; _gv_portIndex_4 < 5; _gv_portIndex_4 = _gv_portIndex_4 + 1) begin : g_lookup
			localparam portIndex = _gv_portIndex_4;
			assign lookupOutput[(portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))] = validInner[lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)]] && (tagInner[lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)]] == lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + 4-:rv32_pkg_ROB_TAG_W]);
			if (portIndex < 2) begin : g_metadata
				assign lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] = pcInner[lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)]];
				assign lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] = predictedPcInner[lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)]];
				assign lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0)) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0))) + ((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))] = predictorCkptIdInner[lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)]];
				assign lookupOutput[(portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] = isRetInner[lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)]];
			end
			else begin : g_no_metadata
				assign lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] = 1'sb0;
				assign lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] = 1'sb0;
				assign lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0)) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0))) + ((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))] = 1'sb0;
				assign lookupOutput[(portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] = 1'b0;
			end
		end
	endgenerate
	always @* begin : commit_candidates
		reg prefix;
		reg [SLOT_W - 1:0] slot;
		reg eligible;
		prefix = !freezeInput;
		slot = 1'sb0;
		eligible = 1'b0;
		begin : sv2v_autoblock_7
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				begin
					slot = headInner[SLOT_W - 1:0] + sv2v_cast_7C1AF_signed(lane);
					eligible = ((((prefix && (sv2v_cast_32_signed(countInner) > lane)) && validInner[slot]) && (tagInner[slot] == (headInner + sv2v_cast_60734(lane)))) && readyInner[slot]) && (!flushInput[5] || rv32_pkg_rob_is_older(tagInner[slot], flushInput[4-:rv32_pkg_ROB_TAG_W]));
					commitOutput[(lane * 93) + 92] = eligible;
					commitOutput[(lane * 93) + 91-:5] = tagInner[slot];
					commitOutput[(lane * 93) + 86-:32] = pcInner[slot];
					commitOutput[(lane * 93) + 54-:32] = instrInner[slot];
					commitOutput[(lane * 93) + 22] = writesRdInner[slot];
					commitOutput[(lane * 93) + 21-:5] = archRdInner[slot];
					commitOutput[(lane * 93) + 16-:6] = newPhyInner[slot];
					commitOutput[(lane * 93) + 10-:6] = oldPhyInner[slot];
					commitOutput[(lane * 93) + 4] = writesRdInner[slot] && (oldPhyInner[slot] != sv2v_cast_A32BA(0));
					commitStoreOutput[lane] = storeInner[slot];
					commitOutput[(lane * 93) + 3-:2] = sqIndexInner[slot];
					commitOutput[(lane * 93) + 1] = haltInner[slot];
					commitOutput[(lane * 93) + 0] = 1'b0;
					prefix = eligible && !haltInner[slot];
				end
		end
	end
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
			countInner <= 1'sb0;
			for (iInner = 0; iInner < DEPTH; iInner = iInner + 1)
				begin
					validInner[iInner] <= 1'b0;
					tagInner[iInner] <= 1'sb0;
					pcInner[iInner] <= 1'sb0;
					instrInner[iInner] <= 1'sb0;
					writesRdInner[iInner] <= 1'b0;
					archRdInner[iInner] <= 1'sb0;
					newPhyInner[iInner] <= 1'sb0;
					oldPhyInner[iInner] <= 1'sb0;
					storeInner[iInner] <= 1'b0;
					sqIndexInner[iInner] <= 1'sb0;
					haltInner[iInner] <= 1'b0;
					predictedPcInner[iInner] <= 1'sb0;
					predictorCkptIdInner[iInner] <= 1'sb0;
					isRetInner[iInner] <= 1'b0;
				end
		end
		else if (!freezeInput && flushInput[5]) begin
			tailInner <= flushTagNext;
			countInner <= (|commitFireOutput ? flushCountAfterCommitInner : flushCountInner[COUNT_W - 1:0]);
			for (iInner = 0; iInner < DEPTH; iInner = iInner + 1)
				if (validInner[iInner] && rv32_pkg_rob_is_younger(tagInner[iInner], flushInput[4-:rv32_pkg_ROB_TAG_W]))
					validInner[iInner] <= 1'b0;
			if (commitCountInner != 0) begin
				begin : sv2v_autoblock_8
					reg signed [31:0] lane;
					for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
						if (commitFireOutput[lane])
							validInner[sv2v_cast_7C1AF(headInner + sv2v_cast_60734(lane))] <= 1'b0;
				end
				headInner <= headNext;
			end
		end
		else if (!freezeInput) begin
			if (commitCountInner != 0) begin
				begin : sv2v_autoblock_9
					reg signed [31:0] lane;
					for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
						if (commitFireOutput[lane])
							validInner[sv2v_cast_7C1AF(headInner + sv2v_cast_60734(lane))] <= 1'b0;
				end
				headInner <= headNext;
			end
			if (allocInput[71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))] && allocReadyOutput) begin
				validInner[tailSlotInner] <= 1'b1;
				tagInner[tailSlotInner] <= tailInner;
				pcInner[tailSlotInner] <= allocInput[70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((121 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (89 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
				instrInner[tailSlotInner] <= allocInput[38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((89 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (57 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
				writesRdInner[tailSlotInner] <= allocInput[6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))];
				archRdInner[tailSlotInner] <= allocInput[5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((56 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (51 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) + 1 : ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) - (5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
				newPhyInner[tailSlotInner] <= allocInput[rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))-:((51 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (45 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) + 1 : ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) + 1)];
				oldPhyInner[tailSlotInner] <= allocInput[rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))-:((45 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (39 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))) - (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) + 1 : ((3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) + 1)];
				storeInner[tailSlotInner] <= allocInput[1 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))];
				sqIndexInner[tailSlotInner] <= allocInput[rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))-:((36 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + 1)];
				haltInner[tailSlotInner] <= allocInput[34 + (rv32_pkg_BPU_CKPT_ID_W + 0)];
				predictedPcInner[tailSlotInner] <= allocInput[32 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
				predictorCkptIdInner[tailSlotInner] <= allocInput[rv32_pkg_BPU_CKPT_ID_W + 0-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))];
				isRetInner[tailSlotInner] <= allocInput[0];
				tailInner <= tailNext;
			end
			if (allocSecondFireInner) begin
				validInner[secondSlotInner] <= 1'b1;
				tagInner[secondSlotInner] <= allocSecondTagOutput;
				pcInner[secondSlotInner] <= allocSecondInput[70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((121 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (89 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
				instrInner[secondSlotInner] <= allocSecondInput[38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((89 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (57 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
				writesRdInner[secondSlotInner] <= allocSecondInput[6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))];
				archRdInner[secondSlotInner] <= allocSecondInput[5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((56 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (51 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) + 1 : ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) - (5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
				newPhyInner[secondSlotInner] <= allocSecondInput[rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))-:((51 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (45 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) + 1 : ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) + 1)];
				oldPhyInner[secondSlotInner] <= allocSecondInput[rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))-:((45 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (39 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))) - (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) + 1 : ((3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) + 1)];
				storeInner[secondSlotInner] <= allocSecondInput[1 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))];
				sqIndexInner[secondSlotInner] <= allocSecondInput[rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))-:((36 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + 1)];
				haltInner[secondSlotInner] <= allocSecondInput[34 + (rv32_pkg_BPU_CKPT_ID_W + 0)];
				predictedPcInner[secondSlotInner] <= allocSecondInput[32 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
				predictorCkptIdInner[secondSlotInner] <= allocSecondInput[rv32_pkg_BPU_CKPT_ID_W + 0-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))];
				isRetInner[secondSlotInner] <= allocSecondInput[0];
			end
			countInner <= countDownInner + allocCountInner;
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput && !freezeInput) begin
			assert ((!allocSecondInput[71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))] || (RENAME_WIDTH == 1)) || allocFireInner) else $fatal(1, "ROB second allocation must follow the first");
			assert ((sv2v_cast_32_signed(countInner) + sv2v_cast_32_signed(allocCountInner)) <= DEPTH) else $fatal(1, "ROB allocation exceeds old free capacity");
		end
`endif
endmodule
module rv32_rob_lanes (
	clkInput,
	rstNInput,
	freezeInput,
	allocationInput,
	allocationFireOutput,
	allocationTagOutput,
	creditsOutput,
	nextTagOutput,
	completionInput,
	storeReadyInput,
	flushInput,
	lookupInput,
	lookupLoadInput,
	lookupLoadOutput,
	loadIdentityOutput,
	lookupOutput,
	commitOutput,
	commitStoreOutput,
	commitReadyInput,
	commitFireOutput,
	statusOutput,
	countOutput,
	replayOffsetInput,
	replayNarrowOutput,
	replayRasOutput
);
	parameter [31:0] LANES = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	parameter [31:0] DEPTH = rv32_pkg_ROB_ENTRIES;
	parameter [31:0] COMMIT_WIDTH = 2;
	parameter [31:0] LOOKUP_PORTS = 5;
	parameter [0:0] SPLIT_LOAD_LOOKUP = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	localparam [31:0] rv32_pkg_SQ_SLOT_W = 2;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (LANES * ((122 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (LANES * (1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((122 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (122 + rv32_pkg_BPU_CKPT_ID_W) + 0)] allocationInput;
	output reg [LANES - 1:0] allocationFireOutput;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	output reg [(LANES * rv32_pkg_ROB_TAG_W) - 1:0] allocationTagOutput;
	output wire [$clog2(DEPTH + 1) - 1:0] creditsOutput;
	output wire [4:0] nextTagOutput;
	input wire [41:0] completionInput;
	input wire [(rv32_pkg_ROB_ENTRIES + rv32_pkg_ROB_ENTRIES) - 1:0] storeReadyInput;
	input wire [5:0] flushInput;
	input wire [(LOOKUP_PORTS * rv32_pkg_ROB_TAG_W) - 1:0] lookupInput;
	input wire [4:0] lookupLoadInput;
	output wire [(65 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] lookupLoadOutput;
	output reg [31:0] loadIdentityOutput;
	output reg [(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (LOOKUP_PORTS * ((65 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (LOOKUP_PORTS * (1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((65 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] lookupOutput;
	output reg [(COMMIT_WIDTH * 93) - 1:0] commitOutput;
	output reg [COMMIT_WIDTH - 1:0] commitStoreOutput;
	input wire [COMMIT_WIDTH - 1:0] commitReadyInput;
	output reg [COMMIT_WIDTH - 1:0] commitFireOutput;
	output wire [6:0] statusOutput;
	output wire [$clog2(DEPTH + 1) - 1:0] countOutput;
	input wire [4:0] replayOffsetInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	output wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayNarrowOutput;
	output wire [(rv32_pkg_RECOVERY_WIDTH * 39) - 1:0] replayRasOutput;
	localparam signed [31:0] SLOT_W = $clog2(DEPTH);
	localparam signed [31:0] COUNT_W = $clog2(DEPTH + 1);
	wire [4:0] commitFlushDistanceInner;
	reg [4:0] headInner;
	assign commitFlushDistanceInner = flushInput[4-:rv32_pkg_ROB_TAG_W] - headInner;
	generate
		if ((((LANES != 1) && (LANES != 2)) && (LANES != 4)) || (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4))) begin : g_invalid_width
			initial $fatal(1, "array ROB allocation/commit width unsupported");
		end
		if (((DEPTH < LANES) || (DEPTH > rv32_pkg_ROB_ENTRIES)) || ((DEPTH & (DEPTH - 1)) != 0)) begin : g_invalid_depth
			initial $fatal(1, "array ROB depth must be a supported power of two");
		end
	endgenerate
	wire [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] payloadInner [0:DEPTH - 1];
	reg [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] payloadRawInner [0:DEPTH - 1];
	reg [DEPTH - 1:0] payloadInitializedInner;
	reg [4:0] tagInner [0:DEPTH - 1];
	reg [DEPTH - 1:0] validInner;
	reg [DEPTH - 1:0] readyInner;
	reg [4:0] tailInner;
	reg [COUNT_W - 1:0] countInner;
	reg [COUNT_W - 1:0] allocatedCountInner;
	reg [COUNT_W - 1:0] committedCountInner;
	localparam signed [31:0] SHARED_READ_PORTS = COMMIT_WIDTH + LOOKUP_PORTS;
	wire [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] commitPayloadInner [0:COMMIT_WIDTH - 1];
	wire [4:0] commitTagInner [0:COMMIT_WIDTH - 1];
	wire [COMMIT_WIDTH - 1:0] commitValidInner;
	wire [COMMIT_WIDTH - 1:0] commitReadyInner;
	wire [((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1:0] commitReadInner [0:COMMIT_WIDTH - 1];
	wire [29:0] commitReadNarrowInner [0:COMMIT_WIDTH - 1];
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic [SLOT_W - 1:0] sv2v_cast_7C1AF;
		input reg [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	function automatic [(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1:0] sv2v_cast_6A5C7;
		input reg [(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) - 1:0] inp;
		sv2v_cast_6A5C7 = inp;
	endfunction
	function automatic [(((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6) >= 0 ? ((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 2 : 1 - (((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1)) - 1:0] sv2v_cast_4AE62;
		input reg [(((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6) >= 0 ? ((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 2 : 1 - (((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1)) - 1:0] inp;
		sv2v_cast_4AE62 = inp;
	endfunction
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic [1:0] sv2v_cast_FD44F;
		input reg [1:0] inp;
		sv2v_cast_FD44F = inp;
	endfunction
	function automatic [29:0] sv2v_cast_5B945;
		input reg [29:0] inp;
		sv2v_cast_5B945 = inp;
	endfunction
	generate
		if ((DEPTH >= COMMIT_WIDTH) && (COMMIT_WIDTH > 1)) begin : g_commit_banked
			localparam signed [31:0] BANK_W = $clog2(COMMIT_WIDTH);
			localparam signed [31:0] ROWS = DEPTH / COMMIT_WIDTH;
			localparam signed [31:0] ROW_W = (ROWS > 1 ? $clog2(ROWS) : 1);
			wire [SLOT_W - 1:0] baseSlot;
			wire [BANK_W - 1:0] firstBank;
			wire [ROW_W - 1:0] baseRow;
			assign baseSlot = sv2v_cast_7C1AF(headInner);
			function automatic [BANK_W - 1:0] sv2v_cast_503ED;
				input reg [BANK_W - 1:0] inp;
				sv2v_cast_503ED = inp;
			endfunction
			assign firstBank = sv2v_cast_503ED(baseSlot);
			function automatic [ROW_W - 1:0] sv2v_cast_8E462;
				input reg [ROW_W - 1:0] inp;
				sv2v_cast_8E462 = inp;
			endfunction
			assign baseRow = sv2v_cast_8E462(baseSlot >> BANK_W);
			genvar _gv_bank_2;
			for (_gv_bank_2 = 0; _gv_bank_2 < COMMIT_WIDTH; _gv_bank_2 = _gv_bank_2 + 1) begin : g_bank
				localparam bank = _gv_bank_2;
				wire [ROWS - 1:0] selectRow;
				reg [((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1:0] selected;
				reg [29:0] narrowSelected;
				genvar _gv_row_6;
				for (_gv_row_6 = 0; _gv_row_6 < ROWS; _gv_row_6 = _gv_row_6 + 1) begin : g_decode
					localparam row = _gv_row_6;
					if (ROWS == 1) begin : g_only
						assign selectRow[row] = 1'b1;
					end
					else if (bank == (COMMIT_WIDTH - 1)) begin : g_last
						function automatic signed [ROW_W - 1:0] sv2v_cast_8E462_signed;
							input reg signed [ROW_W - 1:0] inp;
							sv2v_cast_8E462_signed = inp;
						endfunction
						assign selectRow[row] = baseRow == sv2v_cast_8E462_signed(row);
					end
					else begin : g_wrapped
						function automatic signed [BANK_W - 1:0] sv2v_cast_503ED_signed;
							input reg signed [BANK_W - 1:0] inp;
							sv2v_cast_503ED_signed = inp;
						endfunction
						function automatic signed [ROW_W - 1:0] sv2v_cast_8E462_signed;
							input reg signed [ROW_W - 1:0] inp;
							sv2v_cast_8E462_signed = inp;
						endfunction
						assign selectRow[row] = (firstBank > sv2v_cast_503ED_signed(bank) ? baseRow == sv2v_cast_8E462_signed(((row + ROWS) - 1) % ROWS) : baseRow == sv2v_cast_8E462_signed(row));
					end
				end
				always @* begin
					selected = 1'sb0;
					narrowSelected = 1'sb0;
					begin : sv2v_autoblock_1
						reg signed [31:0] row;
						for (row = 0; row < ROWS; row = row + 1)
							begin
								selected = selected | (sv2v_cast_4AE62({sv2v_cast_6A5C7(payloadInner[(row * COMMIT_WIDTH) + bank]), sv2v_cast_60734(tagInner[(row * COMMIT_WIDTH) + bank]), validInner[(row * COMMIT_WIDTH) + bank], readyInner[(row * COMMIT_WIDTH) + bank]}) & {(((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6) >= 0 ? ((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 2 : 1 - (((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1)) {selectRow[row]}});
								narrowSelected = narrowSelected | (sv2v_cast_5B945({sv2v_cast_60734(tagInner[(row * COMMIT_WIDTH) + bank]), validInner[(row * COMMIT_WIDTH) + bank], readyInner[(row * COMMIT_WIDTH) + bank], payloadInner[(row * COMMIT_WIDTH) + bank][6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))], sv2v_cast_5(payloadInner[(row * COMMIT_WIDTH) + bank][5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((56 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (51 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) + 1 : ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) - (5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)]), sv2v_cast_A32BA(payloadInner[(row * COMMIT_WIDTH) + bank][rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))-:((51 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (45 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) + 1 : ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) + 1)]), sv2v_cast_A32BA(payloadInner[(row * COMMIT_WIDTH) + bank][rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))-:((45 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (39 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))) - (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) + 1 : ((3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) + 1)]), payloadInner[(row * COMMIT_WIDTH) + bank][3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))], payloadInner[(row * COMMIT_WIDTH) + bank][1 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))], sv2v_cast_FD44F(payloadInner[(row * COMMIT_WIDTH) + bank][rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))-:((36 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + 1)]), payloadInner[(row * COMMIT_WIDTH) + bank][34 + (rv32_pkg_BPU_CKPT_ID_W + 0)]}) & {30 {selectRow[row]}});
							end
					end
				end
			end
			genvar _gv_stage_1;
			for (_gv_stage_1 = 0; _gv_stage_1 < BANK_W; _gv_stage_1 = _gv_stage_1 + 1) begin : g_rotate
				localparam stage = _gv_stage_1;
				wire [(COMMIT_WIDTH * (1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2))) - 1:0] value;
				wire [(COMMIT_WIDTH * 30) - 1:0] narrowValue;
				genvar _gv_lane_11;
				for (_gv_lane_11 = 0; _gv_lane_11 < COMMIT_WIDTH; _gv_lane_11 = _gv_lane_11 + 1) begin : g_lane
					localparam lane = _gv_lane_11;
					if (stage == 0) begin : g_first
						assign value[lane * (1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2))+:1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2)] = (firstBank[stage] ? g_bank[(lane + (1 << stage)) % COMMIT_WIDTH].selected : g_bank[lane].selected);
						assign narrowValue[lane * 30+:30] = (firstBank[stage] ? g_bank[(lane + (1 << stage)) % COMMIT_WIDTH].narrowSelected : g_bank[lane].narrowSelected);
					end
					else begin : g_later
						assign value[lane * (1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2))+:1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2)] = (firstBank[stage] ? g_rotate[stage - 1].value[((lane + (1 << stage)) % COMMIT_WIDTH) * (1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2))+:1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2)] : g_rotate[stage - 1].value[lane * (1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2))+:1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2)]);
						assign narrowValue[lane * 30+:30] = (firstBank[stage] ? g_rotate[stage - 1].narrowValue[((lane + (1 << stage)) % COMMIT_WIDTH) * 30+:30] : g_rotate[stage - 1].narrowValue[lane * 30+:30]);
					end
				end
			end
			genvar _gv_lane_12;
			for (_gv_lane_12 = 0; _gv_lane_12 < COMMIT_WIDTH; _gv_lane_12 = _gv_lane_12 + 1) begin : g_result
				localparam lane = _gv_lane_12;
				assign commitReadInner[lane] = sv2v_cast_4AE62(g_rotate[BANK_W - 1].value[lane * (1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2))+:1 * (((0 + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + rv32_pkg_ROB_TAG_W) + 2)]);
				assign commitReadNarrowInner[lane] = sv2v_cast_5B945(g_rotate[BANK_W - 1].narrowValue[lane * 30+:30]);
			end
		end
		else begin : g_commit_small
			genvar _gv_lane_13;
			for (_gv_lane_13 = 0; _gv_lane_13 < COMMIT_WIDTH; _gv_lane_13 = _gv_lane_13 + 1) begin : g_lane
				localparam lane = _gv_lane_13;
				wire [SLOT_W - 1:0] slot;
				wire [DEPTH - 1:0] selectRow;
				reg [((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1:0] selected;
				reg [29:0] narrowSelected;
				assign slot = sv2v_cast_7C1AF(headInner + sv2v_cast_60734(lane));
				genvar _gv_row_7;
				for (_gv_row_7 = 0; _gv_row_7 < DEPTH; _gv_row_7 = _gv_row_7 + 1) begin : g_decode
					localparam row = _gv_row_7;
					assign selectRow[row] = slot == sv2v_cast_7C1AF_signed(row);
				end
				always @* begin
					selected = 1'sb0;
					narrowSelected = 1'sb0;
					begin : sv2v_autoblock_2
						reg signed [31:0] row;
						for (row = 0; row < DEPTH; row = row + 1)
							begin
								selected = selected | (sv2v_cast_4AE62({sv2v_cast_6A5C7(payloadInner[row]), sv2v_cast_60734(tagInner[row]), validInner[row], readyInner[row]}) & {(((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6) >= 0 ? ((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 2 : 1 - (((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + rv32_pkg_ROB_TAG_W) + 1)) {selectRow[row]}});
								narrowSelected = narrowSelected | (sv2v_cast_5B945({sv2v_cast_60734(tagInner[row]), validInner[row], readyInner[row], payloadInner[row][6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))], sv2v_cast_5(payloadInner[row][5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((56 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (51 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) + 1 : ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) - (5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)]), sv2v_cast_A32BA(payloadInner[row][rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))-:((51 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (45 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) + 1 : ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) + 1)]), sv2v_cast_A32BA(payloadInner[row][rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))-:((45 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (39 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))) - (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) + 1 : ((3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) + 1)]), payloadInner[row][3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))], payloadInner[row][1 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))], sv2v_cast_FD44F(payloadInner[row][rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))-:((36 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))) - (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((34 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + 1)]), payloadInner[row][34 + (rv32_pkg_BPU_CKPT_ID_W + 0)]}) & {30 {selectRow[row]}});
							end
					end
				end
				assign commitReadInner[lane] = selected;
				assign commitReadNarrowInner[lane] = narrowSelected;
			end
		end
	endgenerate
	genvar _gv_lane_14;
	generate
		for (_gv_lane_14 = 0; _gv_lane_14 < COMMIT_WIDTH; _gv_lane_14 = _gv_lane_14 + 1) begin : g_commit_read_outputs
			localparam lane = _gv_lane_14;
			assign commitPayloadInner[lane] = commitReadInner[lane][(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6-:(((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6) >= 7 ? (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) : 8 - ((((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 6))];
			assign commitTagInner[lane] = commitReadNarrowInner[lane][29-:5];
			assign commitValidInner[lane] = commitReadNarrowInner[lane][24];
			assign commitReadyInner[lane] = commitReadNarrowInner[lane][23];
		end
	endgenerate
	genvar _gv_portIndex_5;
	generate
		for (_gv_portIndex_5 = COMMIT_WIDTH; _gv_portIndex_5 < SHARED_READ_PORTS; _gv_portIndex_5 = _gv_portIndex_5 + 1) begin : g_shared_read
			localparam portIndex = _gv_portIndex_5;
			wire [SLOT_W - 1:0] slot;
			wire [DEPTH - 1:0] selectRow;
			reg [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] payload;
			reg [4:0] tag;
			reg valid;
			reg ready;
			if (portIndex < COMMIT_WIDTH) begin : g_commit_slot
				assign slot = sv2v_cast_7C1AF(headInner + sv2v_cast_60734(portIndex));
				assign commitPayloadInner[portIndex] = payload;
				assign commitTagInner[portIndex] = tag;
				assign commitValidInner[portIndex] = valid;
				assign commitReadyInner[portIndex] = ready;
			end
			else begin : g_lookup_slot
				if (SPLIT_LOAD_LOOKUP && (portIndex == (COMMIT_WIDTH + 2))) begin : g_load
					assign slot = lookupLoadInput[SLOT_W - 1:0];
				end
				else begin : g_registered
					assign slot = lookupInput[((portIndex - COMMIT_WIDTH) * rv32_pkg_ROB_TAG_W) + (SLOT_W >= 1 ? SLOT_W - 1 : ((SLOT_W - 1) + (SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)) - 1)-:(SLOT_W >= 1 ? 0 + SLOT_W : 2 - SLOT_W)];
				end
			end
			genvar _gv_row_8;
			for (_gv_row_8 = 0; _gv_row_8 < DEPTH; _gv_row_8 = _gv_row_8 + 1) begin : g_decode
				localparam row = _gv_row_8;
				assign selectRow[row] = slot == sv2v_cast_7C1AF_signed(row);
			end
			always @* begin
				payload = 1'sb0;
				tag = 1'sb0;
				valid = 1'b0;
				ready = 1'b0;
				begin : sv2v_autoblock_3
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						begin
							payload = payload | (payloadInner[row] & {(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)) {selectRow[row]}});
							tag = tag | (tagInner[row] & {rv32_pkg_ROB_TAG_W {selectRow[row]}});
							valid = valid | (validInner[row] && selectRow[row]);
							ready = ready | (readyInner[row] && selectRow[row]);
						end
				end
			end
		end
	endgenerate
	assign nextTagOutput = tailInner;
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	assign creditsOutput = (!freezeInput && !flushInput[5] ? sv2v_cast_D4579(DEPTH) - countInner : {$clog2(DEPTH + 1) {1'sb0}});
	assign countOutput = countInner;
	assign statusOutput = {countInner == 32'sd0, countInner == sv2v_cast_D4579(DEPTH), sv2v_cast_60734(headInner)};
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin : allocation_prefix
		reg open;
		open = !freezeInput && !flushInput[5];
		allocatedCountInner = 1'sb0;
		begin : sv2v_autoblock_4
			reg signed [31:0] lane;
			for (lane = 0; lane < LANES; lane = lane + 1)
				begin
					allocationTagOutput[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = tailInner + sv2v_cast_60734(lane);
					allocationFireOutput[lane] = (open && allocationInput[(lane * (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) : ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))))]) && ((sv2v_cast_32_signed(countInner) + lane) < DEPTH);
					open = allocationFireOutput[lane];
					allocatedCountInner = allocatedCountInner + sv2v_cast_D4579(allocationFireOutput[lane]);
				end
		end
	end
	always @* begin : commit_candidates
		reg open;
		open = !freezeInput;
		begin : sv2v_autoblock_5
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				begin
					commitOutput[0 + (lane * 93)+:93] = 1'sb0;
					commitOutput[(lane * 93) + 92] = ((((open && (sv2v_cast_32_signed(countInner) > lane)) && commitValidInner[lane]) && (commitTagInner[lane] == (headInner + sv2v_cast_60734(lane)))) && commitReadyInner[lane]) && (!flushInput[5] || (commitFlushDistanceInner > sv2v_cast_60734(lane)));
					commitOutput[(lane * 93) + 91-:5] = commitTagInner[lane];
					commitOutput[(lane * 93) + 86-:32] = commitPayloadInner[lane][70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((121 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (89 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
					commitOutput[(lane * 93) + 54-:32] = commitPayloadInner[lane][38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((89 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (57 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((6 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
					commitOutput[(lane * 93) + 22] = commitReadNarrowInner[lane][22];
					commitOutput[(lane * 93) + 21-:5] = commitReadNarrowInner[lane][21-:5];
					commitOutput[(lane * 93) + 16-:6] = commitReadNarrowInner[lane][16-:6];
					commitOutput[(lane * 93) + 10-:6] = commitReadNarrowInner[lane][10-:6];
					commitOutput[(lane * 93) + 4] = commitReadNarrowInner[lane][4];
					commitOutput[(lane * 93) + 3-:2] = commitReadNarrowInner[lane][2-:2];
					commitOutput[(lane * 93) + 1] = commitReadNarrowInner[lane][0];
					commitStoreOutput[lane] = commitReadNarrowInner[lane][3];
					open = commitOutput[(lane * 93) + 92] && !commitReadNarrowInner[lane][0];
				end
		end
	end
`ifndef SYNTHESIS
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_6
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_7
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	always @(posedge clkInput)
		if (rstNInput) begin : sv2v_autoblock_8
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (commitTagInner[lane] == (headInner + sv2v_cast_60734(lane)))
					assert ((!flushInput[5] || (commitFlushDistanceInner > sv2v_cast_60734(lane))) == (!flushInput[5] || rv32_pkg_rob_is_older(commitTagInner[lane], flushInput[4-:rv32_pkg_ROB_TAG_W]))) else $fatal(1, "commit flush distance reformulation mismatch");
		end
`endif
	always @* begin : commit_acceptance
		reg open;
		open = 1;
		committedCountInner = 1'sb0;
`ifndef SYNTHESIS
		begin : sv2v_autoblock_9
`else
		begin : sv2v_autoblock_6
`endif
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				begin
					commitFireOutput[lane] = (open && commitOutput[(lane * 93) + 92]) && commitReadyInput[lane];
					open = commitFireOutput[lane];
					committedCountInner = committedCountInner + sv2v_cast_D4579(commitFireOutput[lane]);
				end
		end
	end
	genvar _gv_portIndex_6;
	generate
		for (_gv_portIndex_6 = 0; _gv_portIndex_6 < LOOKUP_PORTS; _gv_portIndex_6 = _gv_portIndex_6 + 1) begin : g_lookup
			localparam portIndex = _gv_portIndex_6;
			if (SPLIT_LOAD_LOOKUP && (portIndex == 2)) begin : g_load
				wire [(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)) * 1:1] sv2v_tmp_41157;
				assign sv2v_tmp_41157 = 1'sb0;
				always @(*) lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))] = sv2v_tmp_41157;
			end
			else begin : g_registered
				always @* begin
					lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))] = 1'sb0;
					lookupOutput[(portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 65 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (65 + (rv32_pkg_BPU_CKPT_ID_W + 0)))] = g_shared_read[COMMIT_WIDTH + portIndex].valid && (g_shared_read[COMMIT_WIDTH + portIndex].tag == lookupInput[(portIndex * rv32_pkg_ROB_TAG_W) + 4-:rv32_pkg_ROB_TAG_W]);
					if ((portIndex < 2) || (portIndex == 5)) begin
						lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 1))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 1)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] = g_shared_read[COMMIT_WIDTH + portIndex].payload[70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((121 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (89 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)];
						lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 0) : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)))) + ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)] = g_shared_read[COMMIT_WIDTH + portIndex].payload[32 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (rv32_pkg_BPU_CKPT_ID_W + 1) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 1)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 1) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)];
						lookupOutput[(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0)) : (((portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 0 : ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (rv32_pkg_BPU_CKPT_ID_W + 0))) + ((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))) - 1)-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))] = g_shared_read[COMMIT_WIDTH + portIndex].payload[rv32_pkg_BPU_CKPT_ID_W + 0-:((rv32_pkg_BPU_CKPT_ID_W + 0) >= 1 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 2 - (rv32_pkg_BPU_CKPT_ID_W + 0))];
						lookupOutput[(portIndex * (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (65 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] = g_shared_read[COMMIT_WIDTH + portIndex].payload[0];
					end
				end
			end
		end
	endgenerate
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_F4BE6;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_F4BE6 = inp;
	endfunction
	generate
		if (SPLIT_LOAD_LOOKUP) begin : g_load_lookup_output
			wire [DEPTH - 1:0] rowMatch;
			genvar _gv_row_9;
			for (_gv_row_9 = 0; _gv_row_9 < DEPTH; _gv_row_9 = _gv_row_9 + 1) begin : g_live_row
				localparam row = _gv_row_9;
				assign rowMatch[row] = ((validInner[row] && (tagInner[row][SLOT_W - 1:0] == sv2v_cast_7C1AF_signed(row))) && (lookupLoadInput[SLOT_W - 1:0] == sv2v_cast_7C1AF_signed(row))) && (tagInner[row][4:SLOT_W] == lookupLoadInput[4:0 + SLOT_W]);
			end
			assign lookupLoadOutput = {|rowMatch, 64'b0000000000000000000000000000000000000000000000000000000000000000, sv2v_cast_F4BE6(1'sb0), 1'b0};
		end
		else begin : g_no_load_lookup_output
			assign lookupLoadOutput = 1'sb0;
		end
	endgenerate
	wire [49:0] replayReadInner [0:rv32_pkg_RECOVERY_WIDTH - 1];
	reg [1:0] replayActionRawInner [0:DEPTH - 1];
	wire [1:0] replayActionRow [0:DEPTH - 1];
	genvar _gv_row_10;
	generate
		for (_gv_row_10 = 0; _gv_row_10 < DEPTH; _gv_row_10 = _gv_row_10 + 1) begin : g_replay_predecode
			localparam row = _gv_row_10;
			assign replayActionRow[row] = (payloadInitializedInner[row] ? replayActionRawInner[row] : 2'b00);
		end
	endgenerate
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [49:0] sv2v_cast_A5588;
		input reg [49:0] inp;
		sv2v_cast_A5588 = inp;
	endfunction
	generate
		if (((DEPTH >= rv32_pkg_RECOVERY_WIDTH) && (rv32_pkg_RECOVERY_WIDTH > 1)) && ((rv32_pkg_RECOVERY_WIDTH & (rv32_pkg_RECOVERY_WIDTH - 1)) == 0)) begin : g_replay_banked
			localparam signed [31:0] BANK_W = $clog2(rv32_pkg_RECOVERY_WIDTH);
			localparam signed [31:0] ROWS = DEPTH / rv32_pkg_RECOVERY_WIDTH;
			localparam signed [31:0] ROW_W = (ROWS > 1 ? $clog2(ROWS) : 1);
			wire [SLOT_W - 1:0] baseSlot;
			wire [BANK_W - 1:0] firstBank;
			wire [ROW_W - 1:0] baseRow;
			assign baseSlot = sv2v_cast_7C1AF(headInner + replayOffsetInput);
			function automatic [BANK_W - 1:0] sv2v_cast_503ED;
				input reg [BANK_W - 1:0] inp;
				sv2v_cast_503ED = inp;
			endfunction
			assign firstBank = sv2v_cast_503ED(baseSlot);
			function automatic [ROW_W - 1:0] sv2v_cast_8E462;
				input reg [ROW_W - 1:0] inp;
				sv2v_cast_8E462 = inp;
			endfunction
			assign baseRow = sv2v_cast_8E462(baseSlot >> BANK_W);
			genvar _gv_bank_3;
			for (_gv_bank_3 = 0; _gv_bank_3 < rv32_pkg_RECOVERY_WIDTH; _gv_bank_3 = _gv_bank_3 + 1) begin : g_bank
				localparam bank = _gv_bank_3;
				wire [ROW_W - 1:0] selectedRow;
				wire [ROWS - 1:0] selectRow;
				reg [49:0] selected;
				if (bank == (rv32_pkg_RECOVERY_WIDTH - 1)) begin : g_last_bank
					assign selectedRow = baseRow;
				end
				else begin : g_rotated_bank
					function automatic signed [BANK_W - 1:0] sv2v_cast_503ED_signed;
						input reg signed [BANK_W - 1:0] inp;
						sv2v_cast_503ED_signed = inp;
					endfunction
					function automatic [ROW_W - 1:0] sv2v_cast_8E462;
						input reg [ROW_W - 1:0] inp;
						sv2v_cast_8E462 = inp;
					endfunction
					assign selectedRow = baseRow + sv2v_cast_8E462(sv2v_cast_503ED_signed(bank) < firstBank);
				end
				genvar _gv_row_11;
				for (_gv_row_11 = 0; _gv_row_11 < ROWS; _gv_row_11 = _gv_row_11 + 1) begin : g_decode
					localparam row = _gv_row_11;
					function automatic signed [ROW_W - 1:0] sv2v_cast_8E462_signed;
						input reg signed [ROW_W - 1:0] inp;
						sv2v_cast_8E462_signed = inp;
					endfunction
					assign selectRow[row] = (selectedRow & sv2v_cast_8E462_signed(ROWS - 1)) == sv2v_cast_8E462_signed(row);
				end
				always @* begin
					selected = 1'sb0;
`ifndef SYNTHESIS
					begin : sv2v_autoblock_10
`else
					begin : sv2v_autoblock_7
`endif
						reg signed [31:0] row;
						for (row = 0; row < ROWS; row = row + 1)
							selected = selected | (sv2v_cast_A5588({sv2v_cast_60734(tagInner[(row * rv32_pkg_RECOVERY_WIDTH) + bank]), sv2v_cast_5(payloadInner[(row * rv32_pkg_RECOVERY_WIDTH) + bank][5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((56 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (51 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) + 1 : ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) - (5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)]), sv2v_cast_A32BA(payloadInner[(row * rv32_pkg_RECOVERY_WIDTH) + bank][rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))-:((51 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (45 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) + 1 : ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) + 1)]), sv2v_cast_32(payloadInner[(row * rv32_pkg_RECOVERY_WIDTH) + bank][70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((121 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (89 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)]), replayActionRow[(row * rv32_pkg_RECOVERY_WIDTH) + bank]}) & {50 {selectRow[row]}});
					end
				end
			end
			genvar _gv_stage_2;
			for (_gv_stage_2 = 0; _gv_stage_2 < BANK_W; _gv_stage_2 = _gv_stage_2 + 1) begin : g_rotate
				localparam stage = _gv_stage_2;
				wire [(rv32_pkg_RECOVERY_WIDTH * 50) - 1:0] value;
				genvar _gv_lane_15;
				for (_gv_lane_15 = 0; _gv_lane_15 < rv32_pkg_RECOVERY_WIDTH; _gv_lane_15 = _gv_lane_15 + 1) begin : g_lane
					localparam lane = _gv_lane_15;
					if (stage == 0) begin : g_first
						assign value[lane * 50+:50] = (firstBank[stage] ? g_bank[(lane + (1 << stage)) % rv32_pkg_RECOVERY_WIDTH].selected : g_bank[lane].selected);
					end
					else begin : g_later
						assign value[lane * 50+:50] = (firstBank[stage] ? g_rotate[stage - 1].value[((lane + (1 << stage)) % rv32_pkg_RECOVERY_WIDTH) * 50+:50] : g_rotate[stage - 1].value[lane * 50+:50]);
					end
				end
			end
			genvar _gv_lane_16;
			for (_gv_lane_16 = 0; _gv_lane_16 < rv32_pkg_RECOVERY_WIDTH; _gv_lane_16 = _gv_lane_16 + 1) begin : g_result
				localparam lane = _gv_lane_16;
				assign replayReadInner[lane] = sv2v_cast_A5588(g_rotate[BANK_W - 1].value[lane * 50+:50]);
			end
		end
		else begin : g_replay_small
			genvar _gv_lane_17;
			for (_gv_lane_17 = 0; _gv_lane_17 < rv32_pkg_RECOVERY_WIDTH; _gv_lane_17 = _gv_lane_17 + 1) begin : g_lane
				localparam lane = _gv_lane_17;
				wire [SLOT_W - 1:0] slot;
				wire [DEPTH - 1:0] selectRow;
				reg [49:0] selected;
				assign slot = sv2v_cast_7C1AF((headInner + replayOffsetInput) + sv2v_cast_60734(lane));
				genvar _gv_row_12;
				for (_gv_row_12 = 0; _gv_row_12 < DEPTH; _gv_row_12 = _gv_row_12 + 1) begin : g_decode
					localparam row = _gv_row_12;
					assign selectRow[row] = slot == sv2v_cast_7C1AF_signed(row);
				end
				always @* begin
					selected = 1'sb0;
`ifndef SYNTHESIS
					begin : sv2v_autoblock_11
`else
					begin : sv2v_autoblock_8
`endif
						reg signed [31:0] row;
						for (row = 0; row < DEPTH; row = row + 1)
							selected = selected | (sv2v_cast_A5588({sv2v_cast_60734(tagInner[row]), sv2v_cast_5(payloadInner[row][5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((56 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (51 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) + 1 : ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) - (5 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)]), sv2v_cast_A32BA(payloadInner[row][rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))-:((51 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (45 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) - (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))) + 1 : ((rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))) - (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) + 1)]), sv2v_cast_32(payloadInner[row][70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))-:((121 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (89 + (rv32_pkg_BPU_CKPT_ID_W + 1)) ? ((70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - (38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1)))))))) + 1 : ((38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 1))))))) - (70 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))))) + 1)]), replayActionRow[row]}) & {50 {selectRow[row]}});
					end
				end
				assign replayReadInner[lane] = selected;
			end
		end
	endgenerate
	genvar _gv_lane_18;
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	generate
		for (_gv_lane_18 = 0; _gv_lane_18 < rv32_pkg_RECOVERY_WIDTH; _gv_lane_18 = _gv_lane_18 + 1) begin : g_replay
			localparam lane = _gv_lane_18;
			assign replayNarrowOutput[lane * 16+:16] = {sv2v_cast_60734(replayReadInner[lane][49-:5]), sv2v_cast_5(replayReadInner[lane][44-:5]), sv2v_cast_A32BA(replayReadInner[lane][39-:6])};
			assign replayRasOutput[0 + (lane * 39)+:39] = {sv2v_cast_60734(replayReadInner[lane][49-:5]), sv2v_cast_32(replayReadInner[lane][33-:32]), sv2v_cast_2(replayReadInner[lane][1-:2])};
		end
	endgenerate
	localparam signed [31:0] GROUP_W = (LANES > 1 ? $clog2(LANES) : 1);
	wire [GROUP_W - 1:0] tailGroup;
	wire [GROUP_W - 1:0] laneGroup [0:LANES - 1];
	reg [(122 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] writeGroupPayload [0:LANES - 1];
	reg [4:0] writeGroupTag [0:LANES - 1];
	reg [SLOT_W - 1:0] writeGroupSlot [0:LANES - 1];
	reg writeGroupFire [0:LANES - 1];
	generate
		if (LANES > 1) begin : g_tail_group
			assign tailGroup = tailInner[GROUP_W - 1:0];
		end
		else begin : g_tail_group_single
			assign tailGroup = 1'sb0;
		end
	endgenerate
	genvar _gv_lane_19;
	function automatic signed [GROUP_W - 1:0] sv2v_cast_40245_signed;
		input reg signed [GROUP_W - 1:0] inp;
		sv2v_cast_40245_signed = inp;
	endfunction
	generate
		for (_gv_lane_19 = 0; _gv_lane_19 < LANES; _gv_lane_19 = _gv_lane_19 + 1) begin : g_lane_group
			localparam lane = _gv_lane_19;
			assign laneGroup[lane] = tailGroup + sv2v_cast_40245_signed(lane);
		end
	endgenerate
	genvar _gv_group_1;
	generate
		for (_gv_group_1 = 0; _gv_group_1 < LANES; _gv_group_1 = _gv_group_1 + 1) begin : g_write_group
			localparam group = _gv_group_1;
			always @* begin
				writeGroupPayload[group] = 1'sb0;
				writeGroupTag[group] = 1'sb0;
				writeGroupSlot[group] = 1'sb0;
				writeGroupFire[group] = 1'b0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_12
`else
				begin : sv2v_autoblock_9
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < LANES; lane = lane + 1)
						if (laneGroup[lane] == sv2v_cast_40245_signed(group)) begin
							writeGroupPayload[group] = allocationInput[(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (122 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (lane * (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))];
							writeGroupTag[group] = allocationTagOutput[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W];
							writeGroupSlot[group] = sv2v_cast_7C1AF(allocationTagOutput[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W]);
							writeGroupFire[group] = allocationFireOutput[lane];
						end
				end
			end
		end
	endgenerate
	genvar _gv_row_13;
	localparam [6:0] rv32_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32_pkg_OPCODE_JALR = 7'b1100111;
	function automatic [1:0] rv32_pkg_ras_replay_actions;
		input reg [19:0] insn;
		reg ind;
		reg linkRd;
		reg linkRs;
		begin
			ind = (insn[6:0] == rv32_pkg_OPCODE_JALR) && (insn[14:12] == 3'b000);
			linkRd = {insn[11:10], insn[8:7]} == 4'b0001;
			linkRs = {insn[19:18], insn[16:15]} == 4'b0001;
			rv32_pkg_ras_replay_actions = {(ind && linkRs) && (insn[11:7] != insn[19:15]), linkRd && ((insn[6:0] == rv32_pkg_OPCODE_JAL) || ind)};
		end
	endfunction
`ifdef SYNTHESIS
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_10
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_11
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
`endif
	generate
		for (_gv_row_13 = 0; _gv_row_13 < DEPTH; _gv_row_13 = _gv_row_13 + 1) begin : g_row
			localparam row = _gv_row_13;
			wire writeHit;
			reg completed;
			reg retired;
			wire storeReady;
			if (DEPTH == rv32_pkg_ROB_ENTRIES) begin : g_package_depth
				assign storeReady = storeReadyInput[16 + row] && (storeReadyInput[0 + row] == tagInner[row][4]);
			end
			else begin : g_local_depth
				assign storeReady = storeReadyInput[16 + tagInner[row][3:0]] && (storeReadyInput[0 + tagInner[row][3:0]] == tagInner[row][4]);
			end
			assign writeHit = writeGroupFire[row & (LANES - 1)] && (writeGroupSlot[row & (LANES - 1)] == sv2v_cast_7C1AF_signed(row));
			always @* begin
				completed = 0;
				retired = 0;
				if (validInner[row] && (!flushInput[5] || rv32_pkg_rob_is_older(tagInner[row], flushInput[4-:rv32_pkg_ROB_TAG_W]))) begin
					completed = payloadInner[row][1 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))] && storeReady;
`ifndef SYNTHESIS
					begin : sv2v_autoblock_13
`else
					begin : sv2v_autoblock_12
`endif
						reg signed [31:0] portIndex;
						for (portIndex = 0; portIndex < 6; portIndex = portIndex + 1)
							completed = completed | (completionInput[(portIndex * 7) + 6] && (completionInput[(portIndex * 7) + 5-:5] == tagInner[row]));
					end
				end
`ifndef SYNTHESIS
				begin : sv2v_autoblock_14
`else
				begin : sv2v_autoblock_13
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
						retired = retired | (commitFireOutput[lane] && (sv2v_cast_7C1AF(headInner + sv2v_cast_60734(lane)) == sv2v_cast_7C1AF_signed(row)));
				end
			end
			genvar _gv_epoch_1;
			for (_gv_epoch_1 = 0; _gv_epoch_1 < (1 << (rv32_pkg_ROB_TAG_W - SLOT_W)); _gv_epoch_1 = _gv_epoch_1 + 1) begin : g_load_identity
				localparam epoch = _gv_epoch_1;
				localparam [4:0] FULL_TAG = sv2v_cast_60734((epoch << SLOT_W) | row);
				always_ff @(posedge clkInput or negedge rstNInput)
					if (!rstNInput)
						loadIdentityOutput[FULL_TAG] <= 1'b0;
					else if (!freezeInput) begin
						if (writeHit)
							loadIdentityOutput[FULL_TAG] <= writeGroupTag[row & (LANES - 1)] == FULL_TAG;
						else if (retired || ((flushInput[5] && validInner[row]) && rv32_pkg_rob_is_younger(tagInner[row], flushInput[4-:rv32_pkg_ROB_TAG_W])))
							loadIdentityOutput[FULL_TAG] <= 1'b0;
					end
`ifndef SYNTHESIS
				always @(posedge clkInput)
					if (rstNInput)
						assert (loadIdentityOutput[FULL_TAG] == (validInner[row] && (tagInner[row] == FULL_TAG))) else $fatal(1, "ROB registered identity mirror disagrees with old row");
`endif
			end
			assign payloadInner[row] = (payloadInitializedInner[row] ? payloadRawInner[row] : sv2v_cast_6A5C7(0));
			always_ff @(posedge clkInput)
				if ((rstNInput && !freezeInput) && writeHit) begin
					payloadRawInner[row] <= writeGroupPayload[row & (LANES - 1)];
					replayActionRawInner[row] <= rv32_pkg_ras_replay_actions(writeGroupPayload[row & (LANES - 1)][(38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - 12:(38 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))) - 31]);
				end
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					payloadInitializedInner[row] <= 1'b0;
				else if (!freezeInput && writeHit)
					payloadInitializedInner[row] <= 1'b1;
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput) begin
					validInner[row] <= 0;
					readyInner[row] <= 0;
					tagInner[row] <= 1'sb0;
				end
				else if (!freezeInput) begin
					if ((flushInput[5] && validInner[row]) && rv32_pkg_rob_is_younger(tagInner[row], flushInput[4-:rv32_pkg_ROB_TAG_W]))
						validInner[row] <= 0;
					if (retired)
						validInner[row] <= 0;
					if (writeHit) begin
						validInner[row] <= 1;
						tagInner[row] <= writeGroupTag[row & (LANES - 1)];
						readyInner[row] <= writeGroupPayload[row & (LANES - 1)][2 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))] || writeGroupPayload[row & (LANES - 1)][34 + (rv32_pkg_BPU_CKPT_ID_W + 0)];
					end
					else if (completed)
						readyInner[row] <= 1;
				end
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 1'sb0;
			tailInner <= 1'sb0;
			countInner <= 1'sb0;
		end
		else if (!freezeInput) begin
			headInner <= headInner + sv2v_cast_60734(committedCountInner);
			if (flushInput[5]) begin
				tailInner <= flushInput[4-:rv32_pkg_ROB_TAG_W] + sv2v_cast_60734(1);
				countInner <= sv2v_cast_D4579((flushInput[4-:rv32_pkg_ROB_TAG_W] + sv2v_cast_60734(1)) - headInner) - committedCountInner;
			end
			else begin
				tailInner <= tailInner + sv2v_cast_60734(allocatedCountInner);
				countInner <= (countInner - committedCountInner) + allocatedCountInner;
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput && !freezeInput) begin
			assert ((sv2v_cast_32_signed(countInner) <= DEPTH) && (sv2v_cast_32_signed(allocatedCountInner) <= sv2v_cast_32_signed(creditsOutput))) else $fatal(1, "array ROB old-state credit overflow");
			if (!flushInput[5]) begin : sv2v_autoblock_15
				reg signed [31:0] lane;
				for (lane = 1; lane < LANES; lane = lane + 1)
					assert (!allocationInput[(lane * (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) : ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))))] || allocationInput[((lane - 1) * (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0)))))) : ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) - (71 + (rv32_pkg_PHY_TAG_W + (rv32_pkg_PHY_TAG_W + (3 + (rv32_pkg_SQ_SLOT_W + (34 + (rv32_pkg_BPU_CKPT_ID_W + 0))))))))]) else $fatal(1, "array ROB allocation must be a contiguous prefix");
			end
			else
				assert (sv2v_cast_32_signed(sv2v_cast_60734((flushInput[4-:rv32_pkg_ROB_TAG_W] + sv2v_cast_60734(1)) - headInner)) <= sv2v_cast_32_signed(countInner)) else $fatal(1, "array ROB squash outside live window");
		end
`endif
endmodule
module rv32_wide_rename_plan (
	enableInput,
	wholeGroupInput,
	validInput,
	decodedInput,
	mapReadInput,
	oldDestinationInput,
	sourceReadInput,
	freePhysicalInput,
	physicalCreditsInput,
	nextRobTagInput,
	robCreditsInput,
	rsCreditsInput,
	branchCreditFitsInput,
	loadCreditsInput,
	storeCreditsInput,
	loadSlotInput,
	storeSlotInput,
	fireOutput,
	issueCountOutput,
	physicalCountOutput,
	loadCountOutput,
	storeCountOutput,
	renameOutput,
	physicalOutput,
	destinationPreviewOutput,
	robOutput,
	rsOutput,
	loadOutput,
	storeOutput,
	loadIndexOutput,
	storeIndexOutput
);
	parameter [31:0] LANES = 4;
	parameter [0:0] BRANCH_CREDIT_FITS = 1'b0;
	localparam [31:0] COUNT_W = $clog2(LANES + 1);
	input wire enableInput;
	input wire wholeGroupInput;
	input wire [LANES - 1:0] validInput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (LANES * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (LANES * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] decodedInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [(LANES * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) - 1:0] mapReadInput;
	input wire [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] oldDestinationInput;
	input wire [((LANES * 2) * 33) - 1:0] sourceReadInput;
	input wire [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] freePhysicalInput;
	input wire [5:0] physicalCreditsInput;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [4:0] nextRobTagInput;
	input wire [4:0] robCreditsInput;
	input wire [34:0] rsCreditsInput;
	input wire [4:0] branchCreditFitsInput;
	localparam [31:0] rv32_pkg_LQ_ENTRIES = 4;
	input wire [2:0] loadCreditsInput;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	input wire [2:0] storeCreditsInput;
	input wire [(LANES * 2) - 1:0] loadSlotInput;
	input wire [(LANES * 2) - 1:0] storeSlotInput;
	output wire [LANES - 1:0] fireOutput;
	output wire [COUNT_W - 1:0] issueCountOutput;
	output wire [COUNT_W - 1:0] physicalCountOutput;
	output wire [COUNT_W - 1:0] loadCountOutput;
	output wire [COUNT_W - 1:0] storeCountOutput;
	output reg [(LANES * 12) - 1:0] renameOutput;
	output reg [(LANES * 34) - 1:0] physicalOutput;
	output wire [(LANES * rv32_pkg_PHY_TAG_W) - 1:0] destinationPreviewOutput;
	localparam [31:0] rv32_pkg_SQ_SLOT_W = 2;
	output reg [(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (LANES * ((122 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (LANES * (1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((122 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (122 + rv32_pkg_BPU_CKPT_ID_W) + 0)] robOutput;
	output reg [(LANES * 193) - 1:0] rsOutput;
	output reg [(LANES * 15) - 1:0] loadOutput;
	output reg [(LANES * 47) - 1:0] storeOutput;
	output reg [(LANES * 2) - 1:0] loadIndexOutput;
	output reg [(LANES * 2) - 1:0] storeIndexOutput;
	wire [LANES - 1:0] writesInner;
	wire [LANES - 1:0] linkInner;
	wire [LANES - 1:0] loadInner;
	wire [LANES - 1:0] storeInner;
	wire [LANES - 1:0] haltInner;
	wire [LANES - 1:0] prefixFireInner;
	wire [LANES - 1:0] poolMemberInner [0:6];
	wire [COUNT_W - 1:0] physicalRankInner [0:LANES - 1];
	wire [COUNT_W - 1:0] loadRankInner [0:LANES - 1];
	wire [COUNT_W - 1:0] storeRankInner [0:LANES - 1];
	wire [5:0] destinationInner [0:LANES - 1];
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	function automatic [COUNT_W - 1:0] population;
		input reg [LANES - 1:0] mask;
		reg [3:0] padded;
		reg [2:0] lowPair;
		reg [2:0] highPair;
		begin
			padded = 1'sb0;
			padded[LANES - 1:0] = mask;
			lowPair = {2'b00, padded[0]} + {2'b00, padded[1]};
			highPair = {2'b00, padded[2]} + {2'b00, padded[3]};
			population = sv2v_cast_D4579(lowPair + highPair);
		end
	endfunction
	genvar _gv_lane_20;
	generate
		for (_gv_lane_20 = 0; _gv_lane_20 < LANES; _gv_lane_20 = _gv_lane_20 + 1) begin : g_classify
			localparam lane = _gv_lane_20;
			assign writesInner[lane] = decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 129 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (129 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 0);
			assign linkInner[lane] = (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd27) || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28);
			assign haltInner[lane] = decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 158 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (158 + (rv32_pkg_BPU_CKPT_ID_W + 2)))];
			assign loadInner[lane] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd5;
			assign storeInner[lane] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd6;
			assign poolMemberInner[0][lane] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd1;
			assign poolMemberInner[1][lane] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd2;
			assign poolMemberInner[2][lane] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd3;
			assign poolMemberInner[3][lane] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 4'd4;
			assign poolMemberInner[4][lane] = loadInner[lane];
			assign poolMemberInner[5][lane] = storeInner[lane];
			assign poolMemberInner[6][lane] = storeInner[lane];
		end
	endgenerate
	genvar _gv_lane_21;
	function automatic signed [LANES - 1:0] sv2v_cast_933C5_signed;
		input reg signed [LANES - 1:0] inp;
		sv2v_cast_933C5_signed = inp;
	endfunction
	function automatic [4:0] sv2v_cast_71679;
		input reg [4:0] inp;
		sv2v_cast_71679 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_102D2;
		input reg [5:0] inp;
		sv2v_cast_102D2 = inp;
	endfunction
	function automatic [2:0] sv2v_cast_6B8DB;
		input reg [2:0] inp;
		sv2v_cast_6B8DB = inp;
	endfunction
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	generate
		for (_gv_lane_21 = 0; _gv_lane_21 < LANES; _gv_lane_21 = _gv_lane_21 + 1) begin : g_prefix
			localparam lane = _gv_lane_21;
			localparam [LANES - 1:0] BEFORE = sv2v_cast_933C5_signed((1 << lane) - 1);
			localparam [LANES - 1:0] THROUGH = sv2v_cast_933C5_signed((1 << (lane + 1)) - 1);
			wire [6:0] poolFits;
			assign physicalRankInner[lane] = population(writesInner & BEFORE);
			assign loadRankInner[lane] = population(loadInner & BEFORE);
			assign storeRankInner[lane] = population(storeInner & BEFORE);
			genvar _gv_pool_1;
			for (_gv_pool_1 = 0; _gv_pool_1 < 7; _gv_pool_1 = _gv_pool_1 + 1) begin : g_pool_credit
				localparam pool = _gv_pool_1;
				if (BRANCH_CREDIT_FITS && (pool == 3)) begin : g_branch_fit
					assign poolFits[pool] = branchCreditFitsInput[population(poolMemberInner[pool] & THROUGH)];
				end
				else begin : g_numeric_fit
					assign poolFits[pool] = sv2v_cast_71679(population(poolMemberInner[pool] & THROUGH)) <= rsCreditsInput[pool * 5+:5];
				end
			end
			assign prefixFireInner[lane] = ((((((enableInput && ((validInput & THROUGH) == THROUGH)) && !(|(haltInner & BEFORE))) && ((lane + 1) <= sv2v_cast_32_signed(robCreditsInput))) && (sv2v_cast_102D2(population(writesInner & THROUGH)) <= physicalCreditsInput)) && &poolFits) && (sv2v_cast_6B8DB(population(loadInner & THROUGH)) <= loadCreditsInput)) && (sv2v_cast_6B8DB(population(storeInner & THROUGH)) <= storeCreditsInput);
			assign fireOutput[lane] = prefixFireInner[lane] && (!wholeGroupInput || (prefixFireInner == validInput));
			assign destinationInner[lane] = (writesInner[lane] ? freePhysicalInput[physicalRankInner[lane] * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] : sv2v_cast_A32BA(0));
			assign destinationPreviewOutput[lane * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = destinationInner[lane];
		end
	endgenerate
	assign issueCountOutput = population(fireOutput);
	assign physicalCountOutput = population(fireOutput & writesInner);
	assign loadCountOutput = population(fireOutput & loadInner);
	assign storeCountOutput = population(fireOutput & storeInner);
	genvar _gv_lane_22;
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [1:0] sv2v_cast_FD44F;
		input reg [1:0] inp;
		sv2v_cast_FD44F = inp;
	endfunction
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_13AA8;
		input reg [5:0] inp;
		sv2v_cast_13AA8 = inp;
	endfunction
	generate
		for (_gv_lane_22 = 0; _gv_lane_22 < LANES; _gv_lane_22 = _gv_lane_22 + 1) begin : g_payload
			localparam lane = _gv_lane_22;
			wire [LANES - 1:0] raw1;
			wire [LANES - 1:0] raw2;
			wire [LANES - 1:0] waw;
			wire [LANES - 1:0] nearest1;
			wire [LANES - 1:0] nearest2;
			wire [LANES - 1:0] nearestWaw;
			genvar _gv_older_1;
			for (_gv_older_1 = 0; _gv_older_1 < LANES; _gv_older_1 = _gv_older_1 + 1) begin : g_match
				localparam older = _gv_older_1;
				if (older < lane) begin : g_older
					assign raw1[older] = (writesInner[older] && decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 132 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 2)))]) && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
					assign raw2[older] = (writesInner[older] && decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 131 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (131 + (rv32_pkg_BPU_CKPT_ID_W + 2)))]) && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
					assign waw[older] = writesInner[older] && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]);
				end
				else begin : g_not_older
					assign raw1[older] = 0;
					assign raw2[older] = 0;
					assign waw[older] = 0;
				end
				localparam [LANES - 1:0] NEWER = ~sv2v_cast_933C5_signed((1 << (older + 1)) - 1);
				assign nearest1[older] = raw1[older] && !(|(raw1 & NEWER));
				assign nearest2[older] = raw2[older] && !(|(raw2 & NEWER));
				assign nearestWaw[older] = waw[older] && !(|(waw & NEWER));
			end
			always @* begin : select_payload
				reg [5:0] previous;
				reg [5:0] source1;
				reg [5:0] source2;
				reg ready1;
				reg ready2;
				reg [31:0] value1;
				reg [31:0] value2;
				reg [4:0] tag;
				previous = (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 0 ? {rv32_pkg_PHY_TAG_W {1'sb0}} : oldDestinationInput[(lane * rv32_pkg_PHY_TAG_W) + 5-:rv32_pkg_PHY_TAG_W]);
				source1 = (decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 132 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 0) ? mapReadInput[(lane * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) + 11-:6] : {rv32_pkg_PHY_TAG_W {1'sb0}});
				source2 = (decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 131 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (131 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != 0) ? mapReadInput[(lane * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) + 5-:rv32_pkg_PHY_TAG_W] : {rv32_pkg_PHY_TAG_W {1'sb0}});
				ready1 = (!decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 132 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 0)) || sourceReadInput[((lane * 2) * 33) + 32];
				ready2 = (!decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 131 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (131 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 0)) || sourceReadInput[(((lane * 2) + 1) * 33) + 32];
				value1 = (!decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 132 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 0) ? {32 {1'sb0}} : sourceReadInput[((lane * 2) * 33) + 31-:32]);
				value2 = (!decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 131 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (131 + (rv32_pkg_BPU_CKPT_ID_W + 2)))] || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 0) ? {32 {1'sb0}} : sourceReadInput[(((lane * 2) + 1) * 33) + 31-:32]);
				if (|nearest1) begin
					source1 = 1'sb0;
					ready1 = 0;
					value1 = 1'sb0;
				end
				if (|nearest2) begin
					source2 = 1'sb0;
					ready2 = 0;
					value2 = 1'sb0;
				end
				if (|nearestWaw)
					previous = 1'sb0;
				begin : sv2v_autoblock_1
					reg signed [31:0] older;
					for (older = 0; older < LANES; older = older + 1)
						begin
							source1 = source1 | (destinationInner[older] & {rv32_pkg_PHY_TAG_W {nearest1[older]}});
							source2 = source2 | (destinationInner[older] & {rv32_pkg_PHY_TAG_W {nearest2[older]}});
							previous = previous | (destinationInner[older] & {rv32_pkg_PHY_TAG_W {nearestWaw[older]}});
							ready1 = ready1 | (nearest1[older] && linkInner[older]);
							ready2 = ready2 | (nearest2[older] && linkInner[older]);
							value1 = value1 | ((decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] + 32'd4) & {32 {nearest1[older] && linkInner[older]}});
							value2 = value2 | ((decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((older * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] + 32'd4) & {32 {nearest2[older] && linkInner[older]}});
						end
				end
				tag = nextRobTagInput + sv2v_cast_60734(lane);
				renameOutput[lane * 12+:12] = 1'sb0;
				physicalOutput[lane * 34+:34] = 1'sb0;
				robOutput[(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (122 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (lane * (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))] = 1'sb0;
				rsOutput[0 + (lane * 193)+:193] = 1'sb0;
				loadOutput[0 + (lane * 15)+:15] = 1'sb0;
				storeOutput[0 + (lane * 47)+:47] = 1'sb0;
				loadIndexOutput[lane * 2+:2] = 1'sb0;
				storeIndexOutput[lane * 2+:2] = 1'sb0;
				if (fireOutput[lane]) begin
					renameOutput[lane * 12+:12] = {writesInner[lane], sv2v_cast_5(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_A32BA(destinationInner[lane])};
					physicalOutput[lane * 34+:34] = {writesInner[lane], linkInner[lane], sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] + 32'd4)};
					robOutput[(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (122 + rv32_pkg_BPU_CKPT_ID_W) + 0) + (lane * (((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0)))+:(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (122 + rv32_pkg_BPU_CKPT_ID_W) + 1 : 1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))] = {1'b1, sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 64 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), writesInner[lane], sv2v_cast_5(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_A32BA(destinationInner[lane]), sv2v_cast_A32BA((writesInner[lane] ? previous : sv2v_cast_A32BA(0))), writesInner[lane] && (previous != sv2v_cast_A32BA(0)), decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 158 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (158 + (rv32_pkg_BPU_CKPT_ID_W + 2)))], storeInner[lane], sv2v_cast_FD44F(storeSlotInput[storeRankInner[lane] * 2+:2]), decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 158 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (158 + (rv32_pkg_BPU_CKPT_ID_W + 2)))], 1'b0, sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_C1E44(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 2 : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (rv32_pkg_BPU_CKPT_ID_W + 2)) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? rv32_pkg_BPU_CKPT_ID_W + 2 : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (rv32_pkg_BPU_CKPT_ID_W + 2))) + ((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))) - 1)-:((rv32_pkg_BPU_CKPT_ID_W + 2) >= 3 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 4 - (rv32_pkg_BPU_CKPT_ID_W + 2))]), ((decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28) && ((decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 32'sd1) || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 32'sd5))) && (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] != decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])};
					rsOutput[0 + (lane * 193)+:193] = {1'b1, sv2v_cast_6(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_60734(tag), sv2v_cast_A32BA(destinationInner[lane]), ready1, sv2v_cast_A32BA(source1), value1, ready2, sv2v_cast_A32BA(source2), value2, sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 128 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 128 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((128 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((96 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (128 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 96 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((96 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (96 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_32(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 32 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (rv32_pkg_BPU_CKPT_ID_W + 3) ? ((32 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (rv32_pkg_BPU_CKPT_ID_W + 3)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 3) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 130 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (130 + (rv32_pkg_BPU_CKPT_ID_W + 2)))]};
					if (loadInner[lane]) begin
						loadIndexOutput[lane * 2+:2] = loadSlotInput[loadRankInner[lane] * 2+:2];
						loadOutput[0 + (lane * 15)+:15] = {1'b1, sv2v_cast_60734(tag), sv2v_cast_A32BA(destinationInner[lane]), sv2v_cast_2(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 2 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 0) : ((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 2 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 1)-:2]), decodedInput[(lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)]};
					end
					if (storeInner[lane]) begin
						storeIndexOutput[lane * 2+:2] = storeSlotInput[storeRankInner[lane] * 2+:2];
						storeOutput[0 + (lane * 47)+:47] = {1'b1, sv2v_cast_60734(tag), sv2v_cast_2(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 2 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 0) : ((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 2 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 0)) + 1)-:2]), 1'b0, sv2v_cast_13AA8(1'sb0), 32'b00000000000000000000000000000000};
					end
				end
			end
		end
	endgenerate
`ifndef SYNTHESIS
	always @* begin : check_branch_credit_fit
		if (BRANCH_CREDIT_FITS && enableInput) begin : sv2v_autoblock_2
			reg signed [31:0] lane;
			for (lane = 0; lane < LANES; lane = lane + 1)
				assert (branchCreditFitsInput[population(poolMemberInner[3] & sv2v_cast_933C5_signed((1 << (lane + 1)) - 1))] == (sv2v_cast_71679(population(poolMemberInner[3] & sv2v_cast_933C5_signed((1 << (lane + 1)) - 1))) <= rsCreditsInput[15+:5])) else $fatal(1, "Branch planner credit fit qualification");
		end
	end
	initial assert (((LANES == 1) || (LANES == 2)) || (LANES == 4)) else $fatal(1, "wide rename lane count");
`endif
endmodule
module rv32_rename_four (
	clkInput,
	rstNInput,
	freezeInput,
	enableInput,
	wholeGroupInput,
	decodedInput,
	validInput,
	fireOutput,
	countOutput,
	rsCreditsInput,
	branchCreditFitsInput,
	loadCreditsInput,
	storeCreditsInput,
	loadPreviewInput,
	storePreviewInput,
	rsOutput,
	rsAuxOutput,
	loadOutput,
	storeOutput,
	mapCommitInput,
	freeInput,
	scalarReadInput,
	scalarReadOutput,
	firstMapOutput,
	firstPreviousOutput,
	firstFreePhysicalOutput,
	readyVectorOutput,
	writebackInput,
	completionInput,
	storeReadyInput,
	flushInput,
	recoveryInput,
	lookupInput,
	lookupLoadInput,
	lookupLoadOutput,
	loadIdentityOutput,
	lookupOutput,
	commitOutput,
	commitStoreOutput,
	commitReadyInput,
	commitFireOutput,
	statusOutput,
	robCountOutput,
	nextTagOutput,
	replayNarrowOutput,
	replayRasOutput
);
	parameter [31:0] COMMIT_WIDTH = 2;
	parameter [31:0] WRITEBACK_PORTS = 2;
	parameter [31:0] LOOKUP_PORTS = 5;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire enableInput;
	input wire wholeGroupInput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (4 * ((160 + rv32_pkg_BPU_CKPT_ID_W) + 3)) - 1 : (4 * (1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + ((160 + rv32_pkg_BPU_CKPT_ID_W) + 1)):(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 0 : (160 + rv32_pkg_BPU_CKPT_ID_W) + 2)] decodedInput;
	input wire [3:0] validInput;
	output wire [3:0] fireOutput;
	output wire [2:0] countOutput;
	input wire [34:0] rsCreditsInput;
	input wire [4:0] branchCreditFitsInput;
	localparam [31:0] rv32_pkg_LQ_ENTRIES = 4;
	input wire [2:0] loadCreditsInput;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	input wire [2:0] storeCreditsInput;
	input wire [7:0] loadPreviewInput;
	input wire [7:0] storePreviewInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	output reg [5403:0] rsOutput;
	localparam [31:0] rv32_pkg_SQ_SLOT_W = 2;
	localparam [31:0] rv32_pkg_LSQ_SLOT_W = rv32_pkg_SQ_SLOT_W;
	output reg [83:0] rsAuxOutput;
	output wire [59:0] loadOutput;
	output wire [187:0] storeOutput;
	input wire [(COMMIT_WIDTH * 12) - 1:0] mapCommitInput;
	input wire [(COMMIT_WIDTH * 7) - 1:0] freeInput;
	input wire [((COMMIT_WIDTH + 3) >= 0 ? ((COMMIT_WIDTH + 4) * rv32_pkg_PHY_TAG_W) - 1 : ((1 - (COMMIT_WIDTH + 3)) * rv32_pkg_PHY_TAG_W) + (((COMMIT_WIDTH + 3) * rv32_pkg_PHY_TAG_W) - 1)):((COMMIT_WIDTH + 3) >= 0 ? 0 : (COMMIT_WIDTH + 3) * rv32_pkg_PHY_TAG_W)] scalarReadInput;
	output wire [((COMMIT_WIDTH + 3) >= 0 ? ((COMMIT_WIDTH + 4) * 33) - 1 : ((1 - (COMMIT_WIDTH + 3)) * 33) + (((COMMIT_WIDTH + 3) * 33) - 1)):((COMMIT_WIDTH + 3) >= 0 ? 0 : (COMMIT_WIDTH + 3) * 33)] scalarReadOutput;
	output wire [(rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W) - 1:0] firstMapOutput;
	output wire [5:0] firstPreviousOutput;
	output wire [5:0] firstFreePhysicalOutput;
	output wire [47:0] readyVectorOutput;
	input wire [(WRITEBACK_PORTS * 39) - 1:0] writebackInput;
	input wire [41:0] completionInput;
	input wire [(rv32_pkg_ROB_ENTRIES + rv32_pkg_ROB_ENTRIES) - 1:0] storeReadyInput;
	input wire [5:0] flushInput;
	input wire [22:0] recoveryInput;
	input wire [(LOOKUP_PORTS * rv32_pkg_ROB_TAG_W) - 1:0] lookupInput;
	input wire [4:0] lookupLoadInput;
	output wire [(65 + rv32_pkg_BPU_CKPT_ID_W) + 0:0] lookupLoadOutput;
	output wire [31:0] loadIdentityOutput;
	output wire [(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (LOOKUP_PORTS * ((65 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (LOOKUP_PORTS * (1 - ((65 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((65 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((65 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (65 + rv32_pkg_BPU_CKPT_ID_W) + 0)] lookupOutput;
	output wire [(COMMIT_WIDTH * 93) - 1:0] commitOutput;
	output wire [COMMIT_WIDTH - 1:0] commitStoreOutput;
	input wire [COMMIT_WIDTH - 1:0] commitReadyInput;
	output wire [COMMIT_WIDTH - 1:0] commitFireOutput;
	output wire [6:0] statusOutput;
	output wire [4:0] robCountOutput;
	output wire [4:0] nextTagOutput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	output wire [(rv32_pkg_RECOVERY_WIDTH * 16) - 1:0] replayNarrowOutput;
	output wire [(rv32_pkg_RECOVERY_WIDTH * 39) - 1:0] replayRasOutput;
	wire [39:0] mapQuery;
	wire [(4 * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) - 1:0] mapRead;
	wire [19:0] destinationQuery;
	wire [47:0] renames;
	wire [23:0] previous;
	wire [135:0] physical;
	wire [(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? (4 * ((122 + rv32_pkg_BPU_CKPT_ID_W) + 1)) - 1 : (4 * (1 - ((122 + rv32_pkg_BPU_CKPT_ID_W) + 0))) + ((122 + rv32_pkg_BPU_CKPT_ID_W) - 1)):(((122 + rv32_pkg_BPU_CKPT_ID_W) + 0) >= 0 ? 0 : (122 + rv32_pkg_BPU_CKPT_ID_W) + 0)] allocations;
	wire [771:0] base;
	wire [((8 + COMMIT_WIDTH) * rv32_pkg_PHY_TAG_W) - 1:0] reads;
	wire [((8 + COMMIT_WIDTH) * 33) - 1:0] values;
	wire [263:0] sourceValues;
	wire [23:0] previewPhysical;
	wire [23:0] allocatedPhysical;
	wire [23:0] destinationPreview;
	wire [3:0] previewReady;
	wire [3:0] physicalFire;
	wire [3:0] robFire;
	wire [19:0] allocatedTags;
	wire [5:0] freeCount;
	wire [4:0] robCredits;
	wire [7:0] loadIndices;
	wire [7:0] storeIndices;
	wire [2:0] unusedPhysicalCount;
	wire [2:0] unusedLoadCount;
	wire [2:0] unusedStoreCount;
	reg [15:0] recycleWindowInner;
	wire [4:0] recycleBoundaryAgeInner;
	reg [(rv32_pkg_RECOVERY_WIDTH * rv32_pkg_ROB_TAG_W) - 1:0] recycleTagsInner;
	assign recycleBoundaryAgeInner = flushInput[4-:rv32_pkg_ROB_TAG_W] - statusOutput[4-:rv32_pkg_ROB_TAG_W];
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			recycleWindowInner <= 1'sb0;
		else if (!freezeInput) begin
			if (flushInput[5]) begin : sv2v_autoblock_1
				reg signed [31:0] row;
				for (row = 0; row < rv32_pkg_ROB_ENTRIES; row = row + 1)
					recycleWindowInner[row] <= (sv2v_cast_60734(row) > recycleBoundaryAgeInner) && (sv2v_cast_60734(row) < sv2v_cast_60734(robCountOutput));
			end
			else if (recoveryInput[22])
				recycleWindowInner <= recycleWindowInner >> rv32_pkg_RECOVERY_WIDTH;
		end
	genvar _gv_lane_23;
	generate
		for (_gv_lane_23 = 0; _gv_lane_23 < rv32_pkg_RECOVERY_WIDTH; _gv_lane_23 = _gv_lane_23 + 1) begin : g_recycle_tag
			localparam lane = _gv_lane_23;
			always_ff @(posedge clkInput)
				if (!freezeInput) begin
					if (flushInput[5])
						recycleTagsInner[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] <= statusOutput[4-:rv32_pkg_ROB_TAG_W] + sv2v_cast_60734(lane);
					else if (recoveryInput[22])
						recycleTagsInner[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] <= recycleTagsInner[lane * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] + sv2v_cast_60734(rv32_pkg_RECOVERY_WIDTH);
				end
		end
	endgenerate
	genvar _gv_lane_24;
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	generate
		for (_gv_lane_24 = 0; _gv_lane_24 < 4; _gv_lane_24 = _gv_lane_24 + 1) begin : g_queries
			localparam lane = _gv_lane_24;
			assign mapQuery[lane * 10+:10] = {sv2v_cast_5(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 142 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((142 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((137 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)]), sv2v_cast_5(decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 137 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((137 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (132 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((132 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (137 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])};
			assign destinationQuery[lane * 5+:5] = decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 147 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((147 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (142 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((142 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)];
			assign reads[(2 * lane) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(mapRead[(lane * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) + 11-:6])};
			assign reads[((2 * lane) + 1) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = {sv2v_cast_A32BA(mapRead[(lane * (rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W)) + 5-:rv32_pkg_PHY_TAG_W])};
			assign sourceValues[(lane * 2) * 33+:33] = values[(2 * lane) * 33+:33];
			assign sourceValues[((lane * 2) + 1) * 33+:33] = values[((2 * lane) + 1) * 33+:33];
		end
	endgenerate
	genvar _gv_lane_25;
	generate
		for (_gv_lane_25 = 0; _gv_lane_25 < COMMIT_WIDTH; _gv_lane_25 = _gv_lane_25 + 1) begin : g_retire_reads
			localparam lane = _gv_lane_25;
			assign reads[(8 + lane) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] = scalarReadInput[((COMMIT_WIDTH + 3) >= 0 ? 2 + lane : (COMMIT_WIDTH + 3) - (2 + lane)) * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W];
			assign scalarReadOutput[((COMMIT_WIDTH + 3) >= 0 ? 2 + lane : (COMMIT_WIDTH + 3) - (2 + lane)) * 33+:33] = values[(8 + lane) * 33+:33];
		end
	endgenerate
	assign scalarReadOutput[((COMMIT_WIDTH + 3) >= 0 ? 0 : COMMIT_WIDTH + 3) * 33+:33] = values[0+:33];
	assign scalarReadOutput[((COMMIT_WIDTH + 3) >= 0 ? 1 : COMMIT_WIDTH + 2) * 33+:33] = values[33+:33];
	assign scalarReadOutput[((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 2 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 2)) * 33+:33] = values[66+:33];
	assign scalarReadOutput[((COMMIT_WIDTH + 3) >= 0 ? COMMIT_WIDTH + 3 : (COMMIT_WIDTH + 3) - (COMMIT_WIDTH + 3)) * 33+:33] = values[99+:33];
	assign firstMapOutput = mapRead[0+:rv32_pkg_PHY_TAG_W + rv32_pkg_PHY_TAG_W];
	assign firstPreviousOutput = previous[0+:rv32_pkg_PHY_TAG_W];
	assign firstFreePhysicalOutput = previewPhysical[0+:rv32_pkg_PHY_TAG_W];
	function automatic [10:0] sv2v_cast_EFBF8;
		input reg [10:0] inp;
		sv2v_cast_EFBF8 = inp;
	endfunction
	rv32_rat_lanes #(
		.LANES(4),
		.COMMIT_WIDTH(COMMIT_WIDTH)
	) u_rat(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.freezeInput(freezeInput),
		.readInput(mapQuery),
		.readOutput(mapRead),
		.destinationArchInput(destinationQuery),
		.renameInput(renames),
		.renameOutput(previous),
		.restoreInput(sv2v_cast_EFBF8({flushInput[5], sv2v_cast_60734(flushInput[4-:rv32_pkg_ROB_TAG_W]), sv2v_cast_60734(statusOutput[4-:rv32_pkg_ROB_TAG_W])})),
		.recoveryInput(recoveryInput),
		.replayInput(replayNarrowOutput),
		.commitInput(mapCommitInput)
	);
	function automatic [5:0] sv2v_cast_002AA;
		input reg [5:0] inp;
		sv2v_cast_002AA = inp;
	endfunction
	rv32_prf_lanes #(
		.LANES(4),
		.ALLOCATION_TAG_SIDEBAND(1'b1),
		.COMMIT_WIDTH(COMMIT_WIDTH),
		.READ_PORTS(8 + COMMIT_WIDTH),
		.WRITEBACK_PORTS(WRITEBACK_PORTS),
		.RECYCLE_TICKET_SIDEBAND(1'b1)
	) u_prf(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.freezeInput(freezeInput),
		.allocationInput(physical),
		.allocationCandidateInput(destinationPreview),
		.previewReadyOutput(previewReady),
		.previewPhyOutput(previewPhysical),
		.allocationFireOutput(physicalFire),
		.allocationPhyOutput(allocatedPhysical),
		.freeInput(freeInput),
		.restoreInput(sv2v_cast_002AA({flushInput[5], sv2v_cast_60734(flushInput[4-:rv32_pkg_ROB_TAG_W])})),
		.recoveryInput(recoveryInput),
		.restoreCountInput(robCountOutput),
		.replayInput(replayNarrowOutput),
		.readInput(reads),
		.readOutput(values),
		.writebackInput(writebackInput),
		.readyVectorOutput(readyVectorOutput),
		.freeCountOutput(freeCount),
		.recycleWindowInput(recycleWindowInner[rv32_pkg_RECOVERY_WIDTH - 1:0]),
		.recycleTagsInput(recycleTagsInner)
	);
	rv32_rob_lanes #(
		.LANES(4),
		.COMMIT_WIDTH(COMMIT_WIDTH),
		.LOOKUP_PORTS(LOOKUP_PORTS),
		.SPLIT_LOAD_LOOKUP(1'b1)
	) u_rob(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.freezeInput(freezeInput || recoveryInput[22]),
		.allocationInput(allocations),
		.allocationFireOutput(robFire),
		.allocationTagOutput(allocatedTags),
		.creditsOutput(robCredits),
		.nextTagOutput(nextTagOutput),
		.completionInput(completionInput),
		.storeReadyInput(storeReadyInput),
		.flushInput(flushInput),
		.lookupInput(lookupInput),
		.lookupOutput(lookupOutput),
		.lookupLoadInput(lookupLoadInput),
		.lookupLoadOutput(lookupLoadOutput),
		.loadIdentityOutput(loadIdentityOutput),
		.commitOutput(commitOutput),
		.commitStoreOutput(commitStoreOutput),
		.commitReadyInput(commitReadyInput),
		.commitFireOutput(commitFireOutput),
		.statusOutput(statusOutput),
		.countOutput(robCountOutput),
		.replayOffsetInput(recoveryInput[19-:5]),
		.replayNarrowOutput(replayNarrowOutput),
		.replayRasOutput(replayRasOutput)
	);
	rv32_wide_rename_plan #(.BRANCH_CREDIT_FITS(1'b1)) u_plan(
		.enableInput(((enableInput && !freezeInput) && !flushInput[5]) && !recoveryInput[22]),
		.validInput(validInput),
		.wholeGroupInput(wholeGroupInput),
		.decodedInput(decodedInput),
		.mapReadInput(mapRead),
		.oldDestinationInput(previous),
		.sourceReadInput(sourceValues),
		.freePhysicalInput(previewPhysical),
		.physicalCreditsInput(freeCount),
		.nextRobTagInput(nextTagOutput),
		.robCreditsInput(robCredits),
		.rsCreditsInput(rsCreditsInput),
		.branchCreditFitsInput(branchCreditFitsInput),
		.loadCreditsInput(loadCreditsInput),
		.storeCreditsInput(storeCreditsInput),
		.loadSlotInput(loadPreviewInput),
		.storeSlotInput(storePreviewInput),
		.fireOutput(fireOutput),
		.issueCountOutput(countOutput),
		.physicalCountOutput(unusedPhysicalCount),
		.loadCountOutput(unusedLoadCount),
		.storeCountOutput(unusedStoreCount),
		.renameOutput(renames),
		.physicalOutput(physical),
		.destinationPreviewOutput(destinationPreview),
		.robOutput(allocations),
		.rsOutput(base),
		.loadOutput(loadOutput),
		.storeOutput(storeOutput),
		.loadIndexOutput(loadIndices),
		.storeIndexOutput(storeIndices)
	);
	genvar _gv_lane_26;
	function automatic [1:0] sv2v_cast_98BC2;
		input reg [1:0] inp;
		sv2v_cast_98BC2 = inp;
	endfunction
	generate
		for (_gv_lane_26 = 0; _gv_lane_26 < 4; _gv_lane_26 = _gv_lane_26 + 1) begin : g_static_route
			localparam lane = _gv_lane_26;
			always @* begin : route_lane
				rsOutput[0 + ((0 + lane) * 193)+:193] = 1'sb0;
				rsOutput[0 + ((4 + lane) * 193)+:193] = 1'sb0;
				rsOutput[0 + ((8 + lane) * 193)+:193] = 1'sb0;
				rsOutput[0 + ((12 + lane) * 193)+:193] = 1'sb0;
				rsOutput[0 + ((16 + lane) * 193)+:193] = 1'sb0;
				rsOutput[0 + ((20 + lane) * 193)+:193] = 1'sb0;
				rsOutput[0 + ((24 + lane) * 193)+:193] = 1'sb0;
				rsAuxOutput[0 + ((0 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[0 + ((4 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[0 + ((8 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[0 + ((12 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[0 + ((16 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[0 + ((20 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[0 + ((24 + lane) * 3)+:3] = 1'sb0;
				rsAuxOutput[((0 + lane) * 3) + 0] = (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd27) || (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 153 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((153 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (147 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((147 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)] == 6'd28);
				case (decodedInput[(((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) : (((lane * (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? (160 + rv32_pkg_BPU_CKPT_ID_W) + 3 : 1 - ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2))) + (((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) >= 0 ? 157 + (rv32_pkg_BPU_CKPT_ID_W + 2) : ((160 + rv32_pkg_BPU_CKPT_ID_W) + 2) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2)))) + ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)) - 1)-:((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) >= (153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) ? ((157 + (rv32_pkg_BPU_CKPT_ID_W + 2)) - (153 + (rv32_pkg_BPU_CKPT_ID_W + 3))) + 1 : ((153 + (rv32_pkg_BPU_CKPT_ID_W + 3)) - (157 + (rv32_pkg_BPU_CKPT_ID_W + 2))) + 1)])
					4'd1: rsOutput[0 + ((0 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
					4'd2: begin
						rsOutput[0 + ((4 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
						rsOutput[((4 + lane) * 193) + 0] = 0;
					end
					4'd3: begin
						rsOutput[0 + ((8 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
						rsOutput[((8 + lane) * 193) + 0] = 0;
					end
					4'd4: rsOutput[0 + ((12 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
					4'd5: begin
						rsOutput[0 + ((16 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
						rsOutput[((16 + lane) * 193) + 135] = 1;
						rsOutput[((16 + lane) * 193) + 134-:6] = 1'sb0;
						rsOutput[((16 + lane) * 193) + 128-:32] = 1'sb0;
						rsOutput[((16 + lane) * 193) + 0] = 1;
						rsAuxOutput[((16 + lane) * 3) + rv32_pkg_LSQ_SLOT_W-:3] = {1'b0, sv2v_cast_98BC2(loadIndices[lane * 2+:2])};
					end
					4'd6: begin
						rsOutput[0 + ((20 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
						rsOutput[((20 + lane) * 193) + 135] = 1;
						rsOutput[((20 + lane) * 193) + 134-:6] = 1'sb0;
						rsOutput[((20 + lane) * 193) + 128-:32] = 1'sb0;
						rsOutput[((20 + lane) * 193) + 0] = 1;
						rsAuxOutput[((20 + lane) * 3) + rv32_pkg_LSQ_SLOT_W-:3] = {1'b1, sv2v_cast_98BC2(storeIndices[lane * 2+:2])};
						rsOutput[0 + ((24 + lane) * 193)+:193] = base[0 + (lane * 193)+:193];
						rsOutput[((24 + lane) * 193) + 174] = base[(lane * 193) + 135];
						rsOutput[((24 + lane) * 193) + 173-:6] = base[(lane * 193) + 134-:6];
						rsOutput[((24 + lane) * 193) + 167-:32] = base[(lane * 193) + 128-:32];
						rsOutput[((24 + lane) * 193) + 135] = 1;
						rsOutput[((24 + lane) * 193) + 134-:6] = 1'sb0;
						rsOutput[((24 + lane) * 193) + 128-:32] = 1'sb0;
						rsOutput[((24 + lane) * 193) + 0] = 0;
						rsAuxOutput[((24 + lane) * 3) + 1-:rv32_pkg_SQ_SLOT_W] = storeIndices[lane * 2+:2];
					end
					default:
						;
				endcase
			end
		end
	endgenerate
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput && !freezeInput) begin
			assert (robFire == fireOutput) else $fatal(1, "four rename ROB did not accept common prefix");
			begin : sv2v_autoblock_2
				reg signed [31:0] lane;
				for (lane = 0; lane < 4; lane = lane + 1)
					begin
						assert (physicalFire[lane] == physical[(lane * 34) + 33]) else $fatal(1, "four rename PRF did not accept destination");
						if (physicalFire[lane])
							assert (allocatedPhysical[lane * rv32_pkg_PHY_TAG_W+:rv32_pkg_PHY_TAG_W] == renames[(lane * 12) + 5-:rv32_pkg_PHY_TAG_W]) else $fatal(1, "four rename physical preview rank disagrees");
					end
			end
		end
`endif
endmodule
module rv32_rs (
	clkInput,
	rstNInput,
	freezeInput,
	flushInfoInput,
	allocInput,
	allocReadyOutput,
	allocAuxInput,
	allocSecondInput,
	allocSecondReadyOutput,
	allocSecondAuxInput,
	writebackInput,
	issueOutput,
	issueReadyInput,
	issueAuxOutput,
	issueLaneValidOutput,
	issueLaneOutput,
	issueLaneAuxOutput,
	occupancyOutput,
	allocLanesInput,
	allocLanesAuxInput,
	allocLanesFireOutput,
	allocCreditsOutput,
	allocCreditFitsOutput,
	issueLaneReadyInput,
	issueWritebackInput
);
	parameter [31:0] DEPTH = 4;
	parameter [31:0] AUX_W = 3;
	parameter [31:0] ISSUE_WIDTH = 1;
	parameter [31:0] RENAME_WIDTH = 1;
	parameter [31:0] WRITEBACK_PORTS = 4;
	parameter [0:0] REUSE_ON_ISSUE = 1'b0;
	parameter [0:0] WB_ISSUE_BYPASS = 1'b0;
	parameter [31:0] WB_ISSUE_PORTS = WRITEBACK_PORTS;
	parameter [0:0] CREDIT_FIT_SIDEBAND = 1'b0;
	parameter [0:0] INDEPENDENT_ISSUE_READY = 1'b0;
	parameter [0:0] SELECTIVE_WAKE_PIPE = 1'b0;
	parameter [0:0] SEPARATE_ISSUE_WB = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] flushInfoInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [192:0] allocInput;
	output reg allocReadyOutput;
	input wire [AUX_W - 1:0] allocAuxInput;
	input wire [192:0] allocSecondInput;
	output reg allocSecondReadyOutput;
	input wire [AUX_W - 1:0] allocSecondAuxInput;
	input wire [(WRITEBACK_PORTS * 39) - 1:0] writebackInput;
	output reg [178:0] issueOutput;
	input wire issueReadyInput;
	output reg [AUX_W - 1:0] issueAuxOutput;
	output reg [ISSUE_WIDTH - 1:0] issueLaneValidOutput;
	output reg [(ISSUE_WIDTH * 179) - 1:0] issueLaneOutput;
	output reg [(ISSUE_WIDTH * AUX_W) - 1:0] issueLaneAuxOutput;
	output reg [$clog2(DEPTH + 1) - 1:0] occupancyOutput;
	input wire [771:0] allocLanesInput;
	input wire [(4 * AUX_W) - 1:0] allocLanesAuxInput;
	output reg [3:0] allocLanesFireOutput;
	output reg [$clog2(DEPTH + 1) - 1:0] allocCreditsOutput;
	output wire [4:0] allocCreditFitsOutput;
	input wire [ISSUE_WIDTH - 1:0] issueLaneReadyInput;
	input wire [(WRITEBACK_PORTS * 39) - 1:0] issueWritebackInput;
	generate
		if (((RENAME_WIDTH != 1) && (RENAME_WIDTH != 2)) && (RENAME_WIDTH != 4)) begin : g_invalid_rename_width
			initial $fatal(1, "RENAME_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] INDEX_W = (DEPTH <= 1 ? 1 : $clog2(DEPTH));
	reg busyInner [0:DEPTH - 1];
	reg [5:0] opInner [0:DEPTH - 1];
	reg [4:0] robTagInner [0:DEPTH - 1];
	reg [5:0] destPhyInner [0:DEPTH - 1];
	reg src1ReadyInner [0:DEPTH - 1];
	reg [5:0] src1TagInner [0:DEPTH - 1];
	reg [31:0] src1ValueInner [0:DEPTH - 1];
	reg src2ReadyInner [0:DEPTH - 1];
	reg [5:0] src2TagInner [0:DEPTH - 1];
	reg [31:0] src2ValueInner [0:DEPTH - 1];
	reg [31:0] immInner [0:DEPTH - 1];
	reg [31:0] pcInner [0:DEPTH - 1];
	reg [31:0] predictedPcInner [0:DEPTH - 1];
	reg useImmInner [0:DEPTH - 1];
	reg [AUX_W - 1:0] auxInner [0:DEPTH - 1];
	reg issueFoundInner;
	reg [INDEX_W - 1:0] issueIndexInner;
	reg allocFoundInner;
	reg [INDEX_W - 1:0] allocIndexInner;
	reg [INDEX_W - 1:0] allocSecondIndexInner;
	reg allocSecondFoundInner;
	wire allocFireInner;
	wire allocSecondFireInner;
	wire [38:0] allocSecondSrc1WbInner;
	wire [38:0] allocSecondSrc2WbInner;
	wire allocSecondSrc1ReadyInner;
	wire allocSecondSrc2ReadyInner;
	wire [31:0] allocSecondSrc1ValueInner;
	wire [31:0] allocSecondSrc2ValueInner;
	reg [INDEX_W - 1:0] allocLanesIndexInner [0:3];
	wire [3:0] allocLanesS1ReadyInner;
	wire [3:0] allocLanesS2ReadyInner;
	wire [127:0] allocLanesS1ValueInner;
	wire [127:0] allocLanesS2ValueInner;
	assign allocFireInner = allocInput[192] && allocReadyOutput;
	assign allocSecondFireInner = ((RENAME_WIDTH == 2) && allocSecondInput[192]) && allocSecondReadyOutput;
	reg allocSrc1ReadyResolvedInner;
	reg [31:0] allocSrc1ValueResolvedInner;
	reg allocSrc2ReadyResolvedInner;
	reg [31:0] allocSrc2ValueResolvedInner;
	integer seqIndexInner;
	integer laneInner;
	integer seqLaneInner;
	reg [DEPTH - 1:0] laneTakenInner;
	reg laneFoundInner [0:ISSUE_WIDTH - 1];
	reg [INDEX_W - 1:0] laneIndexInner [0:ISSUE_WIDTH - 1];
	wire [ISSUE_WIDTH - 1:0] issueAcceptInner;
	genvar _gv_lane_27;
	generate
		for (_gv_lane_27 = 0; _gv_lane_27 < ISSUE_WIDTH; _gv_lane_27 = _gv_lane_27 + 1) begin : g_dispatch_accept
			localparam lane = _gv_lane_27;
			assign issueAcceptInner[lane] = (!freezeInput && issueLaneValidOutput[lane]) && (INDEPENDENT_ISSUE_READY ? issueLaneReadyInput[lane] : issueReadyInput);
		end
	endgenerate
	wire [38:0] allocSrc1WbInner;
	wire [38:0] allocSrc2WbInner;
	wire [38:0] src1WbInner [0:DEPTH - 1];
	wire [38:0] src2WbInner [0:DEPTH - 1];
	wire [38:0] src1IssueWbInner [0:DEPTH - 1];
	wire [38:0] src2IssueWbInner [0:DEPTH - 1];
	wire src1IssueReadyInner [0:DEPTH - 1];
	wire src2IssueReadyInner [0:DEPTH - 1];
	wire [31:0] src1IssueValueInner [0:DEPTH - 1];
	wire [31:0] src2IssueValueInner [0:DEPTH - 1];
	function automatic [38:0] matching_writeback;
		input reg [5:0] tag;
		begin
			matching_writeback = 1'sb0;
			begin : sv2v_autoblock_1
				reg signed [31:0] portIndex;
				for (portIndex = WRITEBACK_PORTS - 1; portIndex >= 0; portIndex = portIndex - 1)
					if (writebackInput[(portIndex * 39) + 38] && (writebackInput[(portIndex * 39) + 37-:6] == tag))
						matching_writeback = writebackInput[0 + (portIndex * 39)+:39];
			end
		end
	endfunction
	function automatic [38:0] matching_issue_writeback;
		input reg [5:0] tag;
		begin
			matching_issue_writeback = 1'sb0;
			begin : sv2v_autoblock_2
				reg signed [31:0] portIndex;
				for (portIndex = WB_ISSUE_PORTS - 1; portIndex >= 0; portIndex = portIndex - 1)
					if (issueWritebackInput[(portIndex * 39) + 38] && (issueWritebackInput[(portIndex * 39) + 37-:6] == tag))
						matching_issue_writeback = issueWritebackInput[0 + (portIndex * 39)+:39];
			end
		end
	endfunction
	assign allocSrc1WbInner = matching_writeback(allocInput[173-:6]);
	assign allocSrc2WbInner = matching_writeback(allocInput[134-:6]);
	genvar _gv_row_14;
	generate
		for (_gv_row_14 = 0; _gv_row_14 < DEPTH; _gv_row_14 = _gv_row_14 + 1) begin : g_wakeup
			localparam row = _gv_row_14;
			assign src1WbInner[row] = matching_writeback(src1TagInner[row]);
			assign src2WbInner[row] = matching_writeback(src2TagInner[row]);
			if ((WB_ISSUE_PORTS == WRITEBACK_PORTS) && !SEPARATE_ISSUE_WB) begin : g_all_issue_ports
				assign src1IssueWbInner[row] = src1WbInner[row];
				assign src2IssueWbInner[row] = src2WbInner[row];
			end
			else begin : g_prefix_issue_ports
				assign src1IssueWbInner[row] = matching_issue_writeback(src1TagInner[row]);
				assign src2IssueWbInner[row] = matching_issue_writeback(src2TagInner[row]);
			end
			assign src1IssueReadyInner[row] = src1ReadyInner[row] || (WB_ISSUE_BYPASS && src1IssueWbInner[row][38]);
			assign src2IssueReadyInner[row] = src2ReadyInner[row] || (WB_ISSUE_BYPASS && src2IssueWbInner[row][38]);
			assign src1IssueValueInner[row] = ((WB_ISSUE_BYPASS && !src1ReadyInner[row]) && src1IssueWbInner[row][38] ? src1IssueWbInner[row][31-:32] : src1ValueInner[row]);
			assign src2IssueValueInner[row] = ((WB_ISSUE_BYPASS && !src2ReadyInner[row]) && src2IssueWbInner[row][38] ? src2IssueWbInner[row][31-:32] : src2ValueInner[row]);
		end
	endgenerate
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic rs_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rs_is_older = (candidateInput != referenceInput) && ((referenceInput - candidateInput) < sv2v_cast_60734(rv32_pkg_ROB_ENTRIES));
	endfunction
	wire [DEPTH - 1:0] selectiveDualRowsInner [0:ISSUE_WIDTH - 1];
	generate
		if (SELECTIVE_WAKE_PIPE || !((((DEPTH == 4) && (ISSUE_WIDTH == 2)) && WB_ISSUE_BYPASS) && INDEPENDENT_ISSUE_READY)) begin : g_unused_dual_alias
			genvar _gv_lane_28;
			for (_gv_lane_28 = 0; _gv_lane_28 < ISSUE_WIDTH; _gv_lane_28 = _gv_lane_28 + 1) begin : g_lane
				localparam lane = _gv_lane_28;
				assign selectiveDualRowsInner[lane] = 1'sb0;
			end
		end
	endgenerate
	function automatic signed [INDEX_W - 1:0] sv2v_cast_3C754_signed;
		input reg signed [INDEX_W - 1:0] inp;
		sv2v_cast_3C754_signed = inp;
	endfunction
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
`ifndef SYNTHESIS
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
`endif
	generate
		if (SELECTIVE_WAKE_PIPE) begin : g_selective_wake
			reg [DEPTH - 1:0] selectedRowsInner;
			reg [DEPTH - 1:0] choiceRowsInner;
			reg [DEPTH - 1:0] payloadRowsInner;
			reg earlyFoundInner;
			reg choiceFoundInner;
			reg [INDEX_W - 1:0] earlyIndexInner;
			reg [INDEX_W - 1:0] choiceIndexInner;
`ifndef SYNTHESIS
			initial assert ((((ISSUE_WIDTH == 1) && WB_ISSUE_BYPASS) && (WB_ISSUE_PORTS == WRITEBACK_PORTS)) && ((DEPTH == 2) || (DEPTH == 4))) else $fatal(1, "selective onehot wake configuration");
`endif
			always @* begin
				earlyFoundInner = 1'b0;
				earlyIndexInner = 1'sb0;
				choiceFoundInner = 1'b0;
				choiceIndexInner = 1'sb0;
				begin : sv2v_autoblock_3
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						begin
							if (((busyInner[row] && src1ReadyInner[row]) && src2ReadyInner[row]) && (!earlyFoundInner || rs_is_older(robTagInner[row], robTagInner[earlyIndexInner]))) begin
								earlyFoundInner = 1'b1;
								earlyIndexInner = sv2v_cast_3C754_signed(row);
							end
							if (((((busyInner[row] && !(src1ReadyInner[row] && src2ReadyInner[row])) && src1IssueReadyInner[row]) && src2IssueReadyInner[row]) && !selectedRowsInner[row]) && (!choiceFoundInner || rs_is_older(robTagInner[row], robTagInner[choiceIndexInner]))) begin
								choiceFoundInner = 1'b1;
								choiceIndexInner = sv2v_cast_3C754_signed(row);
							end
						end
				end
				choiceRowsInner = 1'sb0;
				if (choiceFoundInner)
					choiceRowsInner[choiceIndexInner] = 1'b1;
				issueFoundInner = |selectedRowsInner || earlyFoundInner;
				payloadRowsInner = 1'sb0;
				if (|selectedRowsInner)
					payloadRowsInner = selectedRowsInner;
				else
					payloadRowsInner[earlyIndexInner] = 1'b1;
				issueIndexInner = 1'sb0;
				issueOutput = 1'sb0;
				issueAuxOutput = 1'sb0;
				begin : sv2v_autoblock_4
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						begin
							issueIndexInner = issueIndexInner | (sv2v_cast_3C754_signed(row) & {INDEX_W {payloadRowsInner[row]}});
							issueOutput[177-:6] = sv2v_cast_6(issueOutput[177-:6] | (opInner[row] & {6 {payloadRowsInner[row]}}));
							issueOutput[171-:5] = issueOutput[171-:5] | (robTagInner[row] & {rv32_pkg_ROB_TAG_W {payloadRowsInner[row]}});
							issueOutput[166-:6] = issueOutput[166-:6] | (destPhyInner[row] & {rv32_pkg_PHY_TAG_W {payloadRowsInner[row]}});
							issueOutput[160-:32] = issueOutput[160-:32] | (src1ValueInner[row] & {32 {payloadRowsInner[row]}});
							issueOutput[128-:32] = issueOutput[128-:32] | (src2ValueInner[row] & {32 {payloadRowsInner[row]}});
							issueOutput[96-:32] = issueOutput[96-:32] | (immInner[row] & {32 {payloadRowsInner[row]}});
							issueOutput[64-:32] = issueOutput[64-:32] | (pcInner[row] & {32 {payloadRowsInner[row]}});
							issueOutput[32-:32] = issueOutput[32-:32] | (predictedPcInner[row] & {32 {payloadRowsInner[row]}});
							issueOutput[0] = issueOutput[0] | (useImmInner[row] && payloadRowsInner[row]);
							issueAuxOutput = issueAuxOutput | (auxInner[row] & {AUX_W {payloadRowsInner[row]}});
						end
				end
				issueOutput[178] = issueFoundInner && (!flushInfoInput[5] || rs_is_older(issueOutput[171-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
				laneFoundInner[0] = issueFoundInner;
				laneIndexInner[0] = issueIndexInner;
				laneTakenInner = (issueFoundInner ? payloadRowsInner : {DEPTH {1'sb0}});
				issueLaneValidOutput[0] = issueOutput[178];
				issueLaneOutput[0 + ((ISSUE_WIDTH - 1) * 179)+:179] = issueOutput;
				issueLaneAuxOutput[(ISSUE_WIDTH - 1) * AUX_W+:AUX_W] = issueAuxOutput;
			end
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					selectedRowsInner <= 1'sb0;
				else if (!freezeInput) begin
					if (flushInfoInput[5])
						selectedRowsInner <= 1'sb0;
					else if (!(|selectedRowsInner) || issueAcceptInner[0])
						selectedRowsInner <= choiceRowsInner;
				end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput) begin
					assert ($onehot0(selectedRowsInner)) else $fatal(1, "onehot selector encoding");
					begin : sv2v_autoblock_5
						reg signed [31:0] row;
						for (row = 0; row < DEPTH; row = row + 1)
							if (selectedRowsInner[row])
								assert ((busyInner[row] && src1ReadyInner[row]) && src2ReadyInner[row]) else $fatal(1, "held selector lost its resident OLD ready row");
					end
				end
`endif
		end
		else if ((((DEPTH == 4) && (ISSUE_WIDTH == 2)) && WB_ISSUE_BYPASS) && INDEPENDENT_ISSUE_READY) begin : g_parallel_n_of_m
			wire [DEPTH - 1:0] readyMaskInner;
			wire [DEPTH - 1:0] beforeInner [0:DEPTH - 1];
			wire [DEPTH - 1:0] olderReadyInner [0:DEPTH - 1];
			wire [2:0] rankLoInner [0:DEPTH - 1];
			wire [2:0] rankHiInner [0:DEPTH - 1];
			wire [2:0] rankInner [0:DEPTH - 1];
			wire [DEPTH - 1:0] winnerMaskInner [0:ISSUE_WIDTH - 1];
			wire [DEPTH - 1:0] selectedRowMaskInner [0:ISSUE_WIDTH - 1];
			wire [DEPTH - 1:0] flushAllowedRowsInner;
			genvar _gv_row_15;
			for (_gv_row_15 = 0; _gv_row_15 < DEPTH; _gv_row_15 = _gv_row_15 + 1) begin : g_early_flush
				localparam row = _gv_row_15;
				assign flushAllowedRowsInner[row] = !flushInfoInput[5] || rs_is_older(robTagInner[row], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]);
			end
			genvar _gv_lane_29;
			for (_gv_lane_29 = 0; _gv_lane_29 < ISSUE_WIDTH; _gv_lane_29 = _gv_lane_29 + 1) begin : g_selected_row
				localparam lane = _gv_lane_29;
				assign selectiveDualRowsInner[lane] = selectedRowMaskInner[lane];
				assign selectedRowMaskInner[lane][0] = !(|winnerMaskInner[lane][3:1]);
				assign selectedRowMaskInner[lane][1] = (winnerMaskInner[lane][1] && !winnerMaskInner[lane][2]) && !winnerMaskInner[lane][3];
				assign selectedRowMaskInner[lane][2] = (winnerMaskInner[lane][2] && !winnerMaskInner[lane][1]) && !winnerMaskInner[lane][3];
				assign selectedRowMaskInner[lane][3] = winnerMaskInner[lane][3] || (winnerMaskInner[lane][1] && winnerMaskInner[lane][2]);
			end
			genvar _gv_row_16;
			for (_gv_row_16 = 0; _gv_row_16 < DEPTH; _gv_row_16 = _gv_row_16 + 1) begin : g_rank
				localparam row = _gv_row_16;
				assign readyMaskInner[row] = (busyInner[row] && src1IssueReadyInner[row]) && src2IssueReadyInner[row];
				genvar _gv_peer_1;
				for (_gv_peer_1 = 0; _gv_peer_1 < DEPTH; _gv_peer_1 = _gv_peer_1 + 1) begin : g_precedence
					localparam peer = _gv_peer_1;
					if (peer == row) begin : g_self
						assign beforeInner[row][peer] = 1'b0;
					end
					else if (peer < row) begin : g_lower
						assign beforeInner[row][peer] = !rs_is_older(robTagInner[row], robTagInner[peer]);
					end
					else begin : g_higher
						assign beforeInner[row][peer] = rs_is_older(robTagInner[peer], robTagInner[row]);
					end
				end
				assign olderReadyInner[row] = readyMaskInner & beforeInner[row];
				assign rankLoInner[row] = {2'b00, olderReadyInner[row][0]} + {2'b00, olderReadyInner[row][1]};
				assign rankHiInner[row] = {2'b00, olderReadyInner[row][2]} + {2'b00, olderReadyInner[row][3]};
				assign rankInner[row] = rankLoInner[row] + rankHiInner[row];
				genvar _gv_lane_30;
				for (_gv_lane_30 = 0; _gv_lane_30 < ISSUE_WIDTH; _gv_lane_30 = _gv_lane_30 + 1) begin : g_grant
					localparam lane = _gv_lane_30;
					assign winnerMaskInner[lane][row] = readyMaskInner[row] && (rankInner[row] == sv2v_cast_3_signed(lane));
				end
			end
			always @* begin
				laneTakenInner = winnerMaskInner[0] | winnerMaskInner[1];
`ifndef SYNTHESIS
				begin : sv2v_autoblock_6
`else
				begin : sv2v_autoblock_5
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < ISSUE_WIDTH; lane = lane + 1)
						begin
							laneFoundInner[lane] = |winnerMaskInner[lane];
							laneIndexInner[lane] = 1'sb0;
`ifndef SYNTHESIS
							begin : sv2v_autoblock_7
`else
							begin : sv2v_autoblock_6
`endif
								reg signed [31:0] row;
								for (row = 0; row < DEPTH; row = row + 1)
									laneIndexInner[lane] = laneIndexInner[lane] | (sv2v_cast_3C754_signed(row) & {INDEX_W {winnerMaskInner[lane][row]}});
							end
						end
				end
				issueFoundInner = laneFoundInner[0];
				issueIndexInner = laneIndexInner[0];
				issueOutput[178] = issueFoundInner && |(selectedRowMaskInner[0] & flushAllowedRowsInner);
				issueOutput[177-:6] = opInner[issueIndexInner];
				issueOutput[171-:5] = robTagInner[issueIndexInner];
				issueOutput[166-:6] = destPhyInner[issueIndexInner];
				issueOutput[160-:32] = src1IssueValueInner[issueIndexInner];
				issueOutput[128-:32] = src2IssueValueInner[issueIndexInner];
				issueOutput[96-:32] = immInner[issueIndexInner];
				issueOutput[64-:32] = pcInner[issueIndexInner];
				issueOutput[32-:32] = predictedPcInner[issueIndexInner];
				issueOutput[0] = useImmInner[issueIndexInner];
				issueAuxOutput = auxInner[issueIndexInner];
`ifndef SYNTHESIS
				begin : sv2v_autoblock_8
`else
				begin : sv2v_autoblock_7
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < ISSUE_WIDTH; lane = lane + 1)
						begin
							issueLaneValidOutput[lane] = laneFoundInner[lane] && |(selectedRowMaskInner[lane] & flushAllowedRowsInner);
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 178] = issueLaneValidOutput[lane];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 177-:6] = opInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 171-:5] = robTagInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 166-:6] = destPhyInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 160-:32] = src1IssueValueInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 128-:32] = src2IssueValueInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 96-:32] = immInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 64-:32] = pcInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 32-:32] = predictedPcInner[laneIndexInner[lane]];
							issueLaneOutput[(((ISSUE_WIDTH - 1) - lane) * 179) + 0] = useImmInner[laneIndexInner[lane]];
							issueLaneAuxOutput[((ISSUE_WIDTH - 1) - lane) * AUX_W+:AUX_W] = auxInner[laneIndexInner[lane]];
						end
				end
			end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput) begin
					assert ($onehot0(winnerMaskInner[0]) && $onehot0(winnerMaskInner[1])) else $fatal(1, "N-of-M RS grant not onehot");
					assert (!(|(winnerMaskInner[0] & winnerMaskInner[1]))) else $fatal(1, "N-of-M RS grants overlap");
					assert ((sv2v_cast_32_signed(laneFoundInner[0]) + sv2v_cast_32_signed(laneFoundInner[1])) == ($countones(readyMaskInner) > 1 ? 2 : $countones(readyMaskInner))) else $fatal(1, "N-of-M RS lost eligible instruction (illegal age window?)");
				end
`endif
		end
		else if ((((ISSUE_WIDTH == 1) && WB_ISSUE_BYPASS) && (WB_ISSUE_PORTS == WRITEBACK_PORTS)) && (DEPTH >= 2)) begin : g_parallel_select
			wire [(WRITEBACK_PORTS * 39) - 1:0] operandWritebackInner;
			assign operandWritebackInner = (SEPARATE_ISSUE_WB ? issueWritebackInput : writebackInput);
			wire [DEPTH - 1:0] readyMaskInner;
			wire [DEPTH - 1:0] winnerMaskInner;
			wire [DEPTH - 1:0] outranksInner [0:DEPTH - 1];
			genvar _gv_row_17;
			for (_gv_row_17 = 0; _gv_row_17 < DEPTH; _gv_row_17 = _gv_row_17 + 1) begin : g_row
				localparam row = _gv_row_17;
				assign readyMaskInner[row] = (busyInner[row] && src1IssueReadyInner[row]) && src2IssueReadyInner[row];
				genvar _gv_peer_2;
				for (_gv_peer_2 = 0; _gv_peer_2 < DEPTH; _gv_peer_2 = _gv_peer_2 + 1) begin : g_peer
					localparam peer = _gv_peer_2;
					if (peer == row) begin : g_self
						assign outranksInner[row][peer] = 1'b0;
					end
					else if (peer < row) begin : g_lower
						assign outranksInner[row][peer] = !rs_is_older(robTagInner[row], robTagInner[peer]);
					end
					else begin : g_higher
						assign outranksInner[row][peer] = rs_is_older(robTagInner[peer], robTagInner[row]);
					end
				end
				assign winnerMaskInner[row] = readyMaskInner[row] && !(|(readyMaskInner & outranksInner[row]));
			end
`ifndef SYNTHESIS
			always @* begin : sv2v_autoblock_9
`else
			always @* begin : sv2v_autoblock_8
`endif
				reg [INDEX_W - 1:0] encoded;
				reg [DEPTH - 1:0] selected;
				reg [AUX_W - 1:0] selectedAux;
				reg [178:0] selectedData;
				reg [178:0] rowData;
				reg [WRITEBACK_PORTS - 1:0] source1PortMaskInner;
				reg [WRITEBACK_PORTS - 1:0] source2PortMaskInner;
				reg [31:0] source1StoredInner;
				reg [31:0] source2StoredInner;
				reg source1PriorHitInner;
				reg source2PriorHitInner;
				reg source1PortHitInner;
				reg source2PortHitInner;
				encoded = 1'sb0;
				selected = winnerMaskInner;
				if (!(|winnerMaskInner))
					selected[0] = 1'b1;
				selectedData = 1'sb0;
				selectedAux = 1'sb0;
				rowData = 1'sb0;
				source1PortMaskInner = 1'sb0;
				source2PortMaskInner = 1'sb0;
				source1StoredInner = 1'sb0;
				source2StoredInner = 1'sb0;
				source1PriorHitInner = 1'b0;
				source2PriorHitInner = 1'b0;
				source1PortHitInner = 1'b0;
				source2PortHitInner = 1'b0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_10
`else
				begin : sv2v_autoblock_9
`endif
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						begin
							encoded = encoded | (sv2v_cast_3C754_signed(row) & {INDEX_W {winnerMaskInner[row]}});
							rowData = {1'b0, opInner[row], sv2v_cast_60734(robTagInner[row]), sv2v_cast_A32BA(destPhyInner[row]), 64'b0000000000000000000000000000000000000000000000000000000000000000, immInner[row], pcInner[row], predictedPcInner[row], useImmInner[row]};
							selectedData = selectedData | (rowData & {179 {selected[row]}});
							selectedAux = selectedAux | (auxInner[row] & {AUX_W {selected[row]}});
							source1StoredInner = source1StoredInner | (src1ValueInner[row] & {32 {selected[row] && (src1ReadyInner[row] || !src1IssueWbInner[row][38])}});
							source2StoredInner = source2StoredInner | (src2ValueInner[row] & {32 {selected[row] && (src2ReadyInner[row] || !src2IssueWbInner[row][38])}});
							source1PriorHitInner = 1'b0;
							source2PriorHitInner = 1'b0;
`ifndef SYNTHESIS
							begin : sv2v_autoblock_11
`else
							begin : sv2v_autoblock_10
`endif
								reg signed [31:0] portIndex;
								for (portIndex = 0; portIndex < WRITEBACK_PORTS; portIndex = portIndex + 1)
									begin
										source1PortHitInner = operandWritebackInner[(portIndex * 39) + 38] && (operandWritebackInner[(portIndex * 39) + 37-:6] == src1TagInner[row]);
										source2PortHitInner = operandWritebackInner[(portIndex * 39) + 38] && (operandWritebackInner[(portIndex * 39) + 37-:6] == src2TagInner[row]);
										source1PortMaskInner[portIndex] = source1PortMaskInner[portIndex] | (((selected[row] && !src1ReadyInner[row]) && source1PortHitInner) && !source1PriorHitInner);
										source2PortMaskInner[portIndex] = source2PortMaskInner[portIndex] | (((selected[row] && !src2ReadyInner[row]) && source2PortHitInner) && !source2PriorHitInner);
										source1PriorHitInner = source1PriorHitInner | source1PortHitInner;
										source2PriorHitInner = source2PriorHitInner | source2PortHitInner;
									end
							end
						end
				end
				selectedData[160-:32] = source1StoredInner;
				selectedData[128-:32] = source2StoredInner;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_12
`else
				begin : sv2v_autoblock_11
`endif
					reg signed [31:0] portIndex;
					for (portIndex = 0; portIndex < WRITEBACK_PORTS; portIndex = portIndex + 1)
						begin
							selectedData[160-:32] = selectedData[160-:32] | (operandWritebackInner[(portIndex * 39) + 31-:32] & {32 {source1PortMaskInner[portIndex]}});
							selectedData[128-:32] = selectedData[128-:32] | (operandWritebackInner[(portIndex * 39) + 31-:32] & {32 {source2PortMaskInner[portIndex]}});
						end
				end
				selectedData[178] = |winnerMaskInner && (!flushInfoInput[5] || rs_is_older(selectedData[171-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
				laneFoundInner[0] = |winnerMaskInner;
				laneIndexInner[0] = encoded;
				laneTakenInner = winnerMaskInner;
				issueFoundInner = |winnerMaskInner;
				issueIndexInner = encoded;
				issueOutput = selectedData;
				issueAuxOutput = selectedAux;
				issueLaneValidOutput[0] = selectedData[178];
				issueLaneOutput[0 + ((ISSUE_WIDTH - 1) * 179)+:179] = selectedData;
				issueLaneAuxOutput[(ISSUE_WIDTH - 1) * AUX_W+:AUX_W] = selectedAux;
			end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput) begin
					assert ($onehot0(winnerMaskInner)) else $fatal(1, "parallel RS winner not unique");
					assert (!(|readyMaskInner) || |winnerMaskInner) else $fatal(1, "parallel RS lost eligible winner");
				end
`endif
		end
		else if ((DEPTH == 2) && (ISSUE_WIDTH == 2)) begin : g_two_slot_select
			wire [1:0] readyRowsInner;
			wire [1:0] flushAllowedRowsInner;
			wire [1:0] authenticatedValidInner;
			wire row1OlderInner;
			wire firstIndexInner;
			wire secondIndexInner;
			genvar _gv_row_18;
			for (_gv_row_18 = 0; _gv_row_18 < 2; _gv_row_18 = _gv_row_18 + 1) begin : g_row
				localparam row = _gv_row_18;
				assign readyRowsInner[row] = (busyInner[row] && src1IssueReadyInner[row]) && src2IssueReadyInner[row];
				assign flushAllowedRowsInner[row] = !flushInfoInput[5] || rs_is_older(robTagInner[row], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]);
			end
			assign row1OlderInner = rs_is_older(robTagInner[1], robTagInner[0]);
			assign firstIndexInner = readyRowsInner[1] && (!readyRowsInner[0] || row1OlderInner);
			assign secondIndexInner = &readyRowsInner && !row1OlderInner;
			assign authenticatedValidInner[0] = ((readyRowsInner[0] && (!readyRowsInner[1] || !row1OlderInner)) && flushAllowedRowsInner[0]) || ((readyRowsInner[1] && (!readyRowsInner[0] || row1OlderInner)) && flushAllowedRowsInner[1]);
			assign authenticatedValidInner[1] = &readyRowsInner && ((row1OlderInner && flushAllowedRowsInner[0]) || (!row1OlderInner && flushAllowedRowsInner[1]));
			always @* begin
				laneFoundInner[0] = |readyRowsInner;
				laneFoundInner[1] = &readyRowsInner;
				laneIndexInner[0] = firstIndexInner;
				laneIndexInner[1] = secondIndexInner;
				laneTakenInner = readyRowsInner;
				issueFoundInner = laneFoundInner[0];
				issueIndexInner = laneIndexInner[0];
				issueOutput[178] = authenticatedValidInner[0];
				issueOutput[177-:6] = opInner[issueIndexInner];
				issueOutput[171-:5] = robTagInner[issueIndexInner];
				issueOutput[166-:6] = destPhyInner[issueIndexInner];
				issueOutput[160-:32] = src1IssueValueInner[issueIndexInner];
				issueOutput[128-:32] = src2IssueValueInner[issueIndexInner];
				issueOutput[96-:32] = immInner[issueIndexInner];
				issueOutput[64-:32] = pcInner[issueIndexInner];
				issueOutput[32-:32] = predictedPcInner[issueIndexInner];
				issueOutput[0] = useImmInner[issueIndexInner];
				issueAuxOutput = auxInner[issueIndexInner];
				for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1)
					begin
						issueLaneValidOutput[laneInner] = authenticatedValidInner[laneInner];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 178] = issueLaneValidOutput[laneInner];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 177-:6] = opInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 171-:5] = robTagInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 166-:6] = destPhyInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 160-:32] = src1IssueValueInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 128-:32] = src2IssueValueInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 96-:32] = immInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 64-:32] = pcInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 32-:32] = predictedPcInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 0] = useImmInner[laneIndexInner[laneInner]];
						issueLaneAuxOutput[((ISSUE_WIDTH - 1) - laneInner) * AUX_W+:AUX_W] = auxInner[laneIndexInner[laneInner]];
					end
			end
		end
		else begin : g_linear_select
			always @* begin
				for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1)
					begin
						laneFoundInner[laneInner] = 1'b0;
						laneIndexInner[laneInner] = 1'sb0;
					end
				laneTakenInner = 1'sb0;
				for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1)
					begin
`ifndef SYNTHESIS
						begin : sv2v_autoblock_13
`else
						begin : sv2v_autoblock_12
`endif
							reg signed [31:0] combIndexInner;
							for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
								if ((((busyInner[combIndexInner] && src1IssueReadyInner[combIndexInner]) && src2IssueReadyInner[combIndexInner]) && !laneTakenInner[combIndexInner]) && (!laneFoundInner[laneInner] || rs_is_older(robTagInner[combIndexInner], robTagInner[laneIndexInner[laneInner]]))) begin
									laneFoundInner[laneInner] = 1'b1;
									laneIndexInner[laneInner] = combIndexInner[INDEX_W - 1:0];
								end
						end
						if (laneFoundInner[laneInner])
							laneTakenInner[laneIndexInner[laneInner]] = 1'b1;
					end
				issueFoundInner = laneFoundInner[0];
				issueIndexInner = laneIndexInner[0];
				issueOutput[178] = issueFoundInner && (!flushInfoInput[5] || rs_is_older(robTagInner[issueIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
				issueOutput[177-:6] = opInner[issueIndexInner];
				issueOutput[171-:5] = robTagInner[issueIndexInner];
				issueOutput[166-:6] = destPhyInner[issueIndexInner];
				issueOutput[160-:32] = src1IssueValueInner[issueIndexInner];
				issueOutput[128-:32] = src2IssueValueInner[issueIndexInner];
				issueOutput[96-:32] = immInner[issueIndexInner];
				issueOutput[64-:32] = pcInner[issueIndexInner];
				issueOutput[32-:32] = predictedPcInner[issueIndexInner];
				issueOutput[0] = useImmInner[issueIndexInner];
				issueAuxOutput = auxInner[issueIndexInner];
				for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1)
					begin
						issueLaneValidOutput[laneInner] = laneFoundInner[laneInner] && (!flushInfoInput[5] || rs_is_older(robTagInner[laneIndexInner[laneInner]], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 178] = issueLaneValidOutput[laneInner];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 177-:6] = opInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 171-:5] = robTagInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 166-:6] = destPhyInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 160-:32] = src1IssueValueInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 128-:32] = src2IssueValueInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 96-:32] = immInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 64-:32] = pcInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 32-:32] = predictedPcInner[laneIndexInner[laneInner]];
						issueLaneOutput[(((ISSUE_WIDTH - 1) - laneInner) * 179) + 0] = useImmInner[laneIndexInner[laneInner]];
						issueLaneAuxOutput[((ISSUE_WIDTH - 1) - laneInner) * AUX_W+:AUX_W] = auxInner[laneIndexInner[laneInner]];
					end
			end
		end
	endgenerate
	always @* begin
		allocFoundInner = 1'b0;
		allocIndexInner = 1'sb0;
`ifndef SYNTHESIS
		begin : sv2v_autoblock_14
`else
		begin : sv2v_autoblock_13
`endif
			reg signed [31:0] combIndexInner;
			for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
				if (!allocFoundInner && !busyInner[combIndexInner]) begin
					allocFoundInner = 1'b1;
					allocIndexInner = combIndexInner[INDEX_W - 1:0];
				end
		end
		if ((((REUSE_ON_ISSUE && !allocFoundInner) && !freezeInput) && issueOutput[178]) && issueReadyInput) begin
			allocFoundInner = 1'b1;
			allocIndexInner = issueIndexInner;
		end
		allocReadyOutput = allocFoundInner && !flushInfoInput[5];
		occupancyOutput = 1'sb0;
`ifndef SYNTHESIS
		begin : sv2v_autoblock_15
`else
		begin : sv2v_autoblock_14
`endif
			reg signed [31:0] combIndexInner;
			for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
				if (busyInner[combIndexInner])
					occupancyOutput = occupancyOutput + 1'b1;
		end
		allocSrc1ReadyResolvedInner = allocInput[174];
		allocSrc1ValueResolvedInner = allocInput[167-:32];
		if (!allocSrc1ReadyResolvedInner) begin
			if (allocSrc1WbInner[38]) begin
				allocSrc1ReadyResolvedInner = 1'b1;
				allocSrc1ValueResolvedInner = allocSrc1WbInner[31-:32];
			end
		end
		allocSrc2ReadyResolvedInner = allocInput[135];
		allocSrc2ValueResolvedInner = allocInput[128-:32];
		if (!allocSrc2ReadyResolvedInner) begin
			if (allocSrc2WbInner[38]) begin
				allocSrc2ReadyResolvedInner = 1'b1;
				allocSrc2ValueResolvedInner = allocSrc2WbInner[31-:32];
			end
		end
	end
	generate
		if (RENAME_WIDTH == 2) begin : g_second_allocation
			assign allocSecondSrc1WbInner = matching_writeback(allocSecondInput[173-:6]);
			assign allocSecondSrc2WbInner = matching_writeback(allocSecondInput[134-:6]);
			always @* begin
				allocSecondFoundInner = 1'b0;
				allocSecondIndexInner = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_16
`else
				begin : sv2v_autoblock_15
`endif
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						if ((!allocSecondFoundInner && !busyInner[row]) && (!allocFireInner || (sv2v_cast_3C754_signed(row) != allocIndexInner))) begin
							allocSecondFoundInner = 1'b1;
							allocSecondIndexInner = sv2v_cast_3C754_signed(row);
						end
				end
				if (((((REUSE_ON_ISSUE && !allocSecondFoundInner) && !freezeInput) && issueOutput[178]) && issueReadyInput) && (!allocFireInner || (issueIndexInner != allocIndexInner))) begin
					allocSecondFoundInner = 1'b1;
					allocSecondIndexInner = issueIndexInner;
				end
				allocSecondReadyOutput = allocSecondFoundInner && !flushInfoInput[5];
			end
			assign allocSecondSrc1ReadyInner = allocSecondInput[174] || allocSecondSrc1WbInner[38];
			assign allocSecondSrc2ReadyInner = allocSecondInput[135] || allocSecondSrc2WbInner[38];
			assign allocSecondSrc1ValueInner = (!allocSecondInput[174] && allocSecondSrc1WbInner[38] ? allocSecondSrc1WbInner[31-:32] : allocSecondInput[167-:32]);
			assign allocSecondSrc2ValueInner = (!allocSecondInput[135] && allocSecondSrc2WbInner[38] ? allocSecondSrc2WbInner[31-:32] : allocSecondInput[128-:32]);
		end
		else begin : g_no_second_allocation
			wire [1:1] sv2v_tmp_13418;
			assign sv2v_tmp_13418 = 1'b0;
			always @(*) allocSecondReadyOutput = sv2v_tmp_13418;
			wire [1:1] sv2v_tmp_8C715;
			assign sv2v_tmp_8C715 = 1'b0;
			always @(*) allocSecondFoundInner = sv2v_tmp_8C715;
			wire [INDEX_W:1] sv2v_tmp_5814F;
			assign sv2v_tmp_5814F = 1'sb0;
			always @(*) allocSecondIndexInner = sv2v_tmp_5814F;
			assign allocSecondSrc1WbInner = 1'sb0;
			assign allocSecondSrc2WbInner = 1'sb0;
			assign allocSecondSrc1ReadyInner = 1'b0;
			assign allocSecondSrc2ReadyInner = 1'b0;
			assign allocSecondSrc1ValueInner = 1'sb0;
			assign allocSecondSrc2ValueInner = 1'sb0;
		end
`ifdef SYNTHESIS
	endgenerate
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	generate
`endif
		if (RENAME_WIDTH == 4) begin : g_four_allocation
			reg [DEPTH - 1:0] available;
			wire [DEPTH - 1:0] creditRowMaskInner [0:ISSUE_WIDTH - 1];
			genvar _gv_lane_31;
			for (_gv_lane_31 = 0; _gv_lane_31 < ISSUE_WIDTH; _gv_lane_31 = _gv_lane_31 + 1) begin : g_credit_row
				localparam lane = _gv_lane_31;
				if ((((DEPTH == 4) && (ISSUE_WIDTH == 2)) && WB_ISSUE_BYPASS) && INDEPENDENT_ISSUE_READY) begin : g_direct
					assign creditRowMaskInner[lane] = selectiveDualRowsInner[lane];
				end
				else begin : g_legacy
					genvar _gv_row_19;
					for (_gv_row_19 = 0; _gv_row_19 < DEPTH; _gv_row_19 = _gv_row_19 + 1) begin : g_decode
						localparam row = _gv_row_19;
						assign creditRowMaskInner[lane][row] = sv2v_cast_3C754_signed(row) == laneIndexInner[lane];
					end
				end
			end
			if (CREDIT_FIT_SIDEBAND && (ISSUE_WIDTH == 1)) begin : g_credit_fit
				reg [$clog2(DEPTH + 1) - 1:0] oldFreeCount;
				wire [DEPTH - 1:0] selectedBusyMask;
				wire selectedOccupied;
				always @* begin : count_old_free
					oldFreeCount = 1'sb0;
`ifndef SYNTHESIS
					begin : sv2v_autoblock_17
`else
					begin : sv2v_autoblock_16
`endif
						reg signed [31:0] row;
						for (row = 0; row < DEPTH; row = row + 1)
							if (!busyInner[row])
								oldFreeCount = oldFreeCount + 1'b1;
					end
				end
				genvar _gv_row_20;
				for (_gv_row_20 = 0; _gv_row_20 < DEPTH; _gv_row_20 = _gv_row_20 + 1) begin : g_selected_busy
					localparam row = _gv_row_20;
					assign selectedBusyMask[row] = busyInner[row] && creditRowMaskInner[0][row];
				end
				assign selectedOccupied = |selectedBusyMask;
				genvar _gv_demand_1;
				for (_gv_demand_1 = 0; _gv_demand_1 < 5; _gv_demand_1 = _gv_demand_1 + 1) begin : g_fit
					localparam demand = _gv_demand_1;
					if (demand == 0) begin : g_zero
						assign allocCreditFitsOutput[demand] = 1'b1;
					end
					else begin : g_nonzero
						wire enoughOld;
						wire enoughWithRelease;
						assign enoughOld = demand <= sv2v_cast_32_signed(oldFreeCount);
						assign enoughWithRelease = demand <= (sv2v_cast_32_signed(oldFreeCount) + 1);
						assign allocCreditFitsOutput[demand] = (!freezeInput && !flushInfoInput[5]) && (enoughOld || (((REUSE_ON_ISSUE && issueAcceptInner[0]) && selectedOccupied) && enoughWithRelease));
					end
				end
			end
			else begin : g_no_credit_fit
				assign allocCreditFitsOutput = 1'sb0;
			end
			always @* begin : old_credits
				available = 1'sb0;
				allocCreditsOutput = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_18
`else
				begin : sv2v_autoblock_17
`endif
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						begin
							available[row] = !busyInner[row];
`ifndef SYNTHESIS
							begin : sv2v_autoblock_19
`else
							begin : sv2v_autoblock_18
`endif
								reg signed [31:0] lane;
								for (lane = 0; lane < ISSUE_WIDTH; lane = lane + 1)
									if ((REUSE_ON_ISSUE && issueAcceptInner[lane]) && creditRowMaskInner[lane][row])
										available[row] = 1'b1;
							end
							if ((available[row] && !freezeInput) && !flushInfoInput[5])
								allocCreditsOutput = allocCreditsOutput + 1'b1;
						end
				end
			end
			always @* begin : consume_sparse_pool
				reg [DEPTH - 1:0] remaining;
				remaining = available;
				allocLanesFireOutput = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_20
`else
				begin : sv2v_autoblock_19
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
`ifndef SYNTHESIS
						begin : sv2v_autoblock_21
`else
						begin : sv2v_autoblock_20
`endif
							reg found;
							found = 0;
							allocLanesIndexInner[lane] = 1'sb0;
`ifndef SYNTHESIS
							begin : sv2v_autoblock_22
`else
							begin : sv2v_autoblock_21
`endif
								reg signed [31:0] row;
								for (row = 0; row < DEPTH; row = row + 1)
									if (!found && remaining[row]) begin
										found = 1;
										allocLanesIndexInner[lane] = sv2v_cast_3C754_signed(row);
									end
							end
							if (((!freezeInput && !flushInfoInput[5]) && allocLanesInput[(lane * 193) + 192]) && found) begin
								allocLanesFireOutput[lane] = 1;
								remaining[allocLanesIndexInner[lane]] = 0;
							end
						end
				end
			end
			genvar _gv_lane_32;
			for (_gv_lane_32 = 0; _gv_lane_32 < 4; _gv_lane_32 = _gv_lane_32 + 1) begin : g_operand
				localparam lane = _gv_lane_32;
				wire [38:0] wb1;
				wire [38:0] wb2;
				assign wb1 = matching_writeback(allocLanesInput[(lane * 193) + 173-:6]);
				assign wb2 = matching_writeback(allocLanesInput[(lane * 193) + 134-:6]);
				assign allocLanesS1ReadyInner[lane] = allocLanesInput[(lane * 193) + 174] || wb1[38];
				assign allocLanesS2ReadyInner[lane] = allocLanesInput[(lane * 193) + 135] || wb2[38];
				assign allocLanesS1ValueInner[lane * 32+:32] = (!allocLanesInput[(lane * 193) + 174] && wb1[38] ? wb1[31-:32] : allocLanesInput[(lane * 193) + 167-:32]);
				assign allocLanesS2ValueInner[lane * 32+:32] = (!allocLanesInput[(lane * 193) + 135] && wb2[38] ? wb2[31-:32] : allocLanesInput[(lane * 193) + 128-:32]);
			end
		end
		else begin : g_no_four_allocation
			assign allocCreditFitsOutput = 1'sb0;
			wire [4:1] sv2v_tmp_3B6AC;
			assign sv2v_tmp_3B6AC = 1'sb0;
			always @(*) allocLanesFireOutput = sv2v_tmp_3B6AC;
			wire [$clog2(DEPTH + 1):1] sv2v_tmp_46159;
			assign sv2v_tmp_46159 = 1'sb0;
			always @(*) allocCreditsOutput = sv2v_tmp_46159;
			assign allocLanesS1ReadyInner = 1'sb0;
			assign allocLanesS2ReadyInner = 1'sb0;
			assign allocLanesS1ValueInner = 1'sb0;
			assign allocLanesS2ValueInner = 1'sb0;
			genvar _gv_lane_33;
			for (_gv_lane_33 = 0; _gv_lane_33 < 4; _gv_lane_33 = _gv_lane_33 + 1) begin : g_lane
				localparam lane = _gv_lane_33;
				wire [INDEX_W:1] sv2v_tmp_D5CE5;
				assign sv2v_tmp_D5CE5 = 1'sb0;
				always @(*) allocLanesIndexInner[lane] = sv2v_tmp_D5CE5;
			end
		end
	endgenerate
	reg [192:0] rowAllocationInner [0:DEPTH - 1];
	reg [AUX_W - 1:0] rowAllocationAuxInner [0:DEPTH - 1];
	wire [DEPTH - 1:0] rowAllocationFireInner;
	generate
		if ((RENAME_WIDTH == 4) && (DEPTH > 1)) begin : g_static_allocation_write
			genvar _gv_row_21;
			for (_gv_row_21 = 0; _gv_row_21 < DEPTH; _gv_row_21 = _gv_row_21 + 1) begin : g_row
				localparam row = _gv_row_21;
				wire [3:0] hit;
				genvar _gv_lane_34;
				for (_gv_lane_34 = 0; _gv_lane_34 < 4; _gv_lane_34 = _gv_lane_34 + 1) begin : g_hit
					localparam lane = _gv_lane_34;
					assign hit[lane] = allocLanesFireOutput[lane] && (allocLanesIndexInner[lane] == sv2v_cast_3C754_signed(row));
				end
				assign rowAllocationFireInner[row] = |hit;
`ifndef SYNTHESIS
				always @* begin : sv2v_autoblock_23
`else
				always @* begin : sv2v_autoblock_22
`endif
					reg [192:0] resolved;
					rowAllocationInner[row] = 1'sb0;
					rowAllocationAuxInner[row] = 1'sb0;
					resolved = 1'sb0;
`ifndef SYNTHESIS
					begin : sv2v_autoblock_24
`else
					begin : sv2v_autoblock_23
`endif
						reg signed [31:0] lane;
						for (lane = 0; lane < 4; lane = lane + 1)
							begin
								resolved = allocLanesInput[0 + (lane * 193)+:193];
								resolved[174] = allocLanesS1ReadyInner[lane];
								resolved[135] = allocLanesS2ReadyInner[lane];
								resolved[167-:32] = allocLanesS1ValueInner[lane * 32+:32];
								resolved[128-:32] = allocLanesS2ValueInner[lane * 32+:32];
								rowAllocationInner[row] = rowAllocationInner[row] | (resolved & {193 {hit[lane]}});
								rowAllocationAuxInner[row] = rowAllocationAuxInner[row] | (allocLanesAuxInput[lane * AUX_W+:AUX_W] & {AUX_W {hit[lane]}});
							end
					end
				end
			end
		end
		else begin : g_no_static_allocation_write
			assign rowAllocationFireInner = 1'sb0;
			genvar _gv_row_22;
			for (_gv_row_22 = 0; _gv_row_22 < DEPTH; _gv_row_22 = _gv_row_22 + 1) begin : g_row
				localparam row = _gv_row_22;
				wire [193:1] sv2v_tmp_9E408;
				assign sv2v_tmp_9E408 = 1'sb0;
				always @(*) rowAllocationInner[row] = sv2v_tmp_9E408;
				wire [AUX_W:1] sv2v_tmp_173D9;
				assign sv2v_tmp_173D9 = 1'sb0;
				always @(*) rowAllocationAuxInner[row] = sv2v_tmp_173D9;
			end
		end
	endgenerate
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
`ifndef SYNTHESIS
			begin : sv2v_autoblock_25
`else
			begin : sv2v_autoblock_24
`endif
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
`ifndef SYNTHESIS
					begin : sv2v_autoblock_26
`else
					begin : sv2v_autoblock_25
`endif
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				begin
					busyInner[seqIndexInner] <= 1'b0;
					opInner[seqIndexInner] <= 6'd0;
					robTagInner[seqIndexInner] <= 1'sb0;
					destPhyInner[seqIndexInner] <= 1'sb0;
					src1ReadyInner[seqIndexInner] <= 1'b0;
					src1TagInner[seqIndexInner] <= 1'sb0;
					src2ReadyInner[seqIndexInner] <= 1'b0;
					src2TagInner[seqIndexInner] <= 1'sb0;
					useImmInner[seqIndexInner] <= 1'b0;
					auxInner[seqIndexInner] <= 1'sb0;
				end
		else if (!freezeInput) begin
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				if ((flushInfoInput[5] && busyInner[seqIndexInner]) && rv32_pkg_rob_is_younger(robTagInner[seqIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))
					busyInner[seqIndexInner] <= 1'b0;
				else if (busyInner[seqIndexInner]) begin
					if (!src1ReadyInner[seqIndexInner]) begin
						if (src1WbInner[seqIndexInner][38])
							src1ReadyInner[seqIndexInner] <= 1'b1;
					end
					if (!src2ReadyInner[seqIndexInner]) begin
						if (src2WbInner[seqIndexInner][38])
							src2ReadyInner[seqIndexInner] <= 1'b1;
					end
				end
			if (issueAcceptInner[0])
				busyInner[issueIndexInner] <= 1'b0;
			for (seqLaneInner = 1; seqLaneInner < ISSUE_WIDTH; seqLaneInner = seqLaneInner + 1)
				if (issueAcceptInner[seqLaneInner])
					busyInner[laneIndexInner[seqLaneInner]] <= 1'b0;
			if (!flushInfoInput[5]) begin
				if (((RENAME_WIDTH != 4) && allocInput[192]) && allocReadyOutput) begin
					busyInner[allocIndexInner] <= 1'b1;
					opInner[allocIndexInner] <= allocInput[191-:6];
					robTagInner[allocIndexInner] <= allocInput[185-:5];
					destPhyInner[allocIndexInner] <= allocInput[180-:6];
					src1ReadyInner[allocIndexInner] <= allocSrc1ReadyResolvedInner;
					src1TagInner[allocIndexInner] <= allocInput[173-:6];
					src2ReadyInner[allocIndexInner] <= allocSrc2ReadyResolvedInner;
					src2TagInner[allocIndexInner] <= allocInput[134-:6];
					useImmInner[allocIndexInner] <= allocInput[0];
					auxInner[allocIndexInner] <= allocAuxInput;
				end
				if (allocSecondFireInner) begin
					busyInner[allocSecondIndexInner] <= 1'b1;
					opInner[allocSecondIndexInner] <= allocSecondInput[191-:6];
					robTagInner[allocSecondIndexInner] <= allocSecondInput[185-:5];
					destPhyInner[allocSecondIndexInner] <= allocSecondInput[180-:6];
					src1ReadyInner[allocSecondIndexInner] <= allocSecondSrc1ReadyInner;
					src1TagInner[allocSecondIndexInner] <= allocSecondInput[173-:6];
					src2ReadyInner[allocSecondIndexInner] <= allocSecondSrc2ReadyInner;
					src2TagInner[allocSecondIndexInner] <= allocSecondInput[134-:6];
					useImmInner[allocSecondIndexInner] <= allocSecondInput[0];
					auxInner[allocSecondIndexInner] <= allocSecondAuxInput;
				end
`ifndef SYNTHESIS
				if ((RENAME_WIDTH == 4) && (DEPTH > 1)) begin : sv2v_autoblock_27
`else
				if ((RENAME_WIDTH == 4) && (DEPTH > 1)) begin : sv2v_autoblock_26
`endif
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						if (rowAllocationFireInner[row]) begin
							busyInner[row] <= 1'b1;
							opInner[row] <= rowAllocationInner[row][191-:6];
							robTagInner[row] <= rowAllocationInner[row][185-:5];
							destPhyInner[row] <= rowAllocationInner[row][180-:6];
							src1ReadyInner[row] <= rowAllocationInner[row][174];
							src1TagInner[row] <= rowAllocationInner[row][173-:6];
							src2ReadyInner[row] <= rowAllocationInner[row][135];
							src2TagInner[row] <= rowAllocationInner[row][134-:6];
							useImmInner[row] <= rowAllocationInner[row][0];
							auxInner[row] <= rowAllocationAuxInner[row];
						end
				end
`ifndef SYNTHESIS
				else if (RENAME_WIDTH == 4) begin : sv2v_autoblock_28
`else
				else if (RENAME_WIDTH == 4) begin : sv2v_autoblock_27
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						if (allocLanesFireOutput[lane]) begin
							busyInner[allocLanesIndexInner[lane]] <= 1;
							opInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 191-:6];
							robTagInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 185-:5];
							destPhyInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 180-:6];
							src1ReadyInner[allocLanesIndexInner[lane]] <= allocLanesS1ReadyInner[lane];
							src1TagInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 173-:6];
							src2ReadyInner[allocLanesIndexInner[lane]] <= allocLanesS2ReadyInner[lane];
							src2TagInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 134-:6];
							useImmInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 0];
							auxInner[allocLanesIndexInner[lane]] <= allocLanesAuxInput[lane * AUX_W+:AUX_W];
						end
				end
			end
		end
	always_ff @(posedge clkInput)
		if (!freezeInput) begin
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				if (busyInner[seqIndexInner]) begin
					if (!src1ReadyInner[seqIndexInner] && src1WbInner[seqIndexInner][38])
						src1ValueInner[seqIndexInner] <= src1WbInner[seqIndexInner][31-:32];
					if (!src2ReadyInner[seqIndexInner] && src2WbInner[seqIndexInner][38])
						src2ValueInner[seqIndexInner] <= src2WbInner[seqIndexInner][31-:32];
				end
			if (!flushInfoInput[5]) begin
				if (((RENAME_WIDTH != 4) && allocInput[192]) && allocReadyOutput) begin
					src1ValueInner[allocIndexInner] <= allocSrc1ValueResolvedInner;
					src2ValueInner[allocIndexInner] <= allocSrc2ValueResolvedInner;
					immInner[allocIndexInner] <= allocInput[96-:32];
					pcInner[allocIndexInner] <= allocInput[64-:32];
					predictedPcInner[allocIndexInner] <= allocInput[32-:32];
				end
				if (allocSecondFireInner) begin
					src1ValueInner[allocSecondIndexInner] <= allocSecondSrc1ValueInner;
					src2ValueInner[allocSecondIndexInner] <= allocSecondSrc2ValueInner;
					immInner[allocSecondIndexInner] <= allocSecondInput[96-:32];
					pcInner[allocSecondIndexInner] <= allocSecondInput[64-:32];
					predictedPcInner[allocSecondIndexInner] <= allocSecondInput[32-:32];
				end
`ifndef SYNTHESIS
				if ((RENAME_WIDTH == 4) && (DEPTH > 1)) begin : sv2v_autoblock_29
`else
				if ((RENAME_WIDTH == 4) && (DEPTH > 1)) begin : sv2v_autoblock_28
`endif
					reg signed [31:0] row;
					for (row = 0; row < DEPTH; row = row + 1)
						if (rowAllocationFireInner[row]) begin
							src1ValueInner[row] <= rowAllocationInner[row][167-:32];
							src2ValueInner[row] <= rowAllocationInner[row][128-:32];
							immInner[row] <= rowAllocationInner[row][96-:32];
							pcInner[row] <= rowAllocationInner[row][64-:32];
							predictedPcInner[row] <= rowAllocationInner[row][32-:32];
						end
				end
`ifndef SYNTHESIS
				else if (RENAME_WIDTH == 4) begin : sv2v_autoblock_30
`else
				else if (RENAME_WIDTH == 4) begin : sv2v_autoblock_29
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						if (allocLanesFireOutput[lane]) begin
							src1ValueInner[allocLanesIndexInner[lane]] <= allocLanesS1ValueInner[lane * 32+:32];
							src2ValueInner[allocLanesIndexInner[lane]] <= allocLanesS2ValueInner[lane * 32+:32];
							immInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 96-:32];
							pcInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 64-:32];
							predictedPcInner[allocLanesIndexInner[lane]] <= allocLanesInput[(lane * 193) + 32-:32];
						end
				end
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if ((rstNInput && !freezeInput) && INDEPENDENT_ISSUE_READY) begin : sv2v_autoblock_31
			reg signed [31:0] lane;
			for (lane = 0; lane < ISSUE_WIDTH; lane = lane + 1)
				begin : sv2v_autoblock_32
					reg signed [31:0] peer;
					for (peer = 0; peer < lane; peer = peer + 1)
						assert ((!issueAcceptInner[lane] || !issueAcceptInner[peer]) || (laneIndexInner[lane] != laneIndexInner[peer])) else $fatal(1, "independent RS dispatch consumed one row twice");
				end
		end
	always @(posedge clkInput)
		if (rstNInput && !freezeInput)
			assert ((!allocFireInner || !allocSecondFireInner) || (allocIndexInner != allocSecondIndexInner)) else $fatal(1, "RS allocation ports selected the same row");
	always @(posedge clkInput)
		if ((rstNInput && !freezeInput) && (RENAME_WIDTH == 4)) begin
			assert ($countones(allocLanesFireOutput) <= sv2v_cast_32_signed(allocCreditsOutput)) else $fatal(1, "RS four-lane credit exceeded");
			begin : sv2v_autoblock_33
				reg signed [31:0] lane;
				for (lane = 0; lane < 4; lane = lane + 1)
					begin : sv2v_autoblock_34
						reg signed [31:0] older;
						for (older = 0; older < lane; older = older + 1)
							assert ((!allocLanesFireOutput[lane] || !allocLanesFireOutput[older]) || (allocLanesIndexInner[lane] != allocLanesIndexInner[older])) else $fatal(1, "RS four-lane allocation duplicated a row");
					end
			end
		end
`endif
endmodule
module rv32_cdb_arbiter (
	candidateInput,
	candidateTagInput,
	resultOutput,
	robTagOutput,
	grantOutput
);
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [77:0] candidateInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [9:0] candidateTagInput;
	output reg [38:0] resultOutput;
	output reg [4:0] robTagOutput;
	output wire [1:0] grantOutput;
	wire secondWinsInner;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	assign secondWinsInner = candidateInput[77] && (!candidateInput[38] || rv32_pkg_rob_is_older(candidateTagInput[rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W], candidateTagInput[0+:rv32_pkg_ROB_TAG_W]));
	assign grantOutput[0] = candidateInput[38] && !secondWinsInner;
	assign grantOutput[1] = secondWinsInner;
	always @* begin
		resultOutput = 1'sb0;
		robTagOutput = 1'sb0;
		begin : sv2v_autoblock_3
			reg signed [31:0] source;
			for (source = 0; source < 2; source = source + 1)
				begin
					resultOutput[38] = resultOutput[38] | grantOutput[source];
					resultOutput[37-:6] = resultOutput[37-:6] | (candidateInput[(source * 39) + 37-:6] & {rv32_pkg_PHY_TAG_W {grantOutput[source]}});
					resultOutput[31-:32] = resultOutput[31-:32] | (candidateInput[(source * 39) + 31-:32] & {32 {grantOutput[source]}});
					robTagOutput = robTagOutput | (candidateTagInput[source * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] & {rv32_pkg_ROB_TAG_W {grantOutput[source]}});
				end
		end
	end
endmodule
module rv32_lsu (
	clkInput,
	rstNInput,
	coreStoppedInput,
	flushInfoInput,
	loadAllocationInput,
	loadAllocReadyOutput,
	loadAllocIndexOutput,
	loadAllocationSecondInput,
	loadAllocSecondReadyOutput,
	loadAllocSecondIndexOutput,
	storeAllocationInput,
	storeAllocReadyOutput,
	storeAllocIndexOutput,
	storeAllocationSecondInput,
	storeAllocSecondReadyOutput,
	storeAllocSecondIndexOutput,
	storeDataInput,
	storeDataIndexInput,
	addressInput,
	addressIndexInput,
	writebackInput,
	loadResultOutput,
	loadResultReadyInput,
	loadIdentityInput,
	loadWinnerIdentityOutput,
	robRetireInput,
	storeCompleteOutput,
	storeCommitInput,
	storeCommitIndexInput,
	storeCommitReadyOutput,
	storeRetirementOutput,
	storeRetirementExitOutput,
	storeHeadSetPreviewOutput,
	dmemRequestOutput,
	dmemReqReadyInput,
	dmemResponseInput,
	dmemReqTransactionOutput,
	dmemRspTransactionInput,
	responsePreviewTransactionInput,
	responsePreviewSelectInput,
	lqCountOutput,
	sqCountOutput,
	loadAllocationLanesInput,
	storeAllocationLanesInput,
	loadAllocationLanesFireOutput,
	storeAllocationLanesFireOutput,
	loadPreviewIndexOutput,
	storePreviewIndexOutput,
	loadCreditsOutput,
	storeCreditsOutput,
	loadYieldEnableInput
);
	localparam [31:0] rv32_pkg_LQ_ENTRIES = 4;
	parameter [31:0] LQ_DEPTH = rv32_pkg_LQ_ENTRIES;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	parameter [31:0] SQ_DEPTH = rv32_pkg_SQ_ENTRIES;
	parameter [31:0] STORE_DATA_LANES = 1;
	parameter [0:0] TAGGED_DMEM = 1'b0;
	parameter [0:0] RESPONSE_PREVIEW = 1'b0;
	parameter [31:0] WRITEBACK_PORTS = 4;
	parameter [31:0] COMMIT_WIDTH = 1;
	parameter [31:0] RENAME_WIDTH = 1;
	input wire clkInput;
	input wire rstNInput;
	input wire coreStoppedInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] flushInfoInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [14:0] loadAllocationInput;
	output reg loadAllocReadyOutput;
	output reg [$clog2(LQ_DEPTH) - 1:0] loadAllocIndexOutput;
	input wire [14:0] loadAllocationSecondInput;
	output reg loadAllocSecondReadyOutput;
	output reg [$clog2(LQ_DEPTH) - 1:0] loadAllocSecondIndexOutput;
	input wire [46:0] storeAllocationInput;
	output reg storeAllocReadyOutput;
	output reg [$clog2(SQ_DEPTH) - 1:0] storeAllocIndexOutput;
	input wire [46:0] storeAllocationSecondInput;
	output wire storeAllocSecondReadyOutput;
	output wire [$clog2(SQ_DEPTH) - 1:0] storeAllocSecondIndexOutput;
	input wire [(STORE_DATA_LANES * 38) - 1:0] storeDataInput;
	input wire [(STORE_DATA_LANES * $clog2(SQ_DEPTH)) - 1:0] storeDataIndexInput;
	input wire [38:0] addressInput;
	input wire [($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH) ? $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH)) - 1:0] addressIndexInput;
	input wire [(WRITEBACK_PORTS * 39) - 1:0] writebackInput;
	output reg [43:0] loadResultOutput;
	input wire loadResultReadyInput;
	input wire [31:0] loadIdentityInput;
	output wire loadWinnerIdentityOutput;
	input wire [(COMMIT_WIDTH * 6) - 1:0] robRetireInput;
	output reg [(rv32_pkg_ROB_ENTRIES + rv32_pkg_ROB_ENTRIES) - 1:0] storeCompleteOutput;
	input wire [(COMMIT_WIDTH * 6) - 1:0] storeCommitInput;
	input wire [(COMMIT_WIDTH * $clog2(SQ_DEPTH)) - 1:0] storeCommitIndexInput;
	output wire [COMMIT_WIDTH - 1:0] storeCommitReadyOutput;
	output reg [(COMMIT_WIDTH * 72) - 1:0] storeRetirementOutput;
	output wire [COMMIT_WIDTH - 1:0] storeRetirementExitOutput;
	localparam [31:0] rv32_pkg_DCACHE_SETS = 128;
	output wire [6:0] storeHeadSetPreviewOutput;
	output reg [71:0] dmemRequestOutput;
	input wire dmemReqReadyInput;
	input wire [32:0] dmemResponseInput;
	localparam [31:0] rv32_pkg_DATA_REQUEST_ENTRIES = 8;
	localparam signed [31:0] rv32_pkg_DATA_TRANSACTION_W = 3;
	output wire [2:0] dmemReqTransactionOutput;
	input wire [2:0] dmemRspTransactionInput;
	input wire [5:0] responsePreviewTransactionInput;
	input wire [1:0] responsePreviewSelectInput;
	output reg [$clog2(LQ_DEPTH + 1) - 1:0] lqCountOutput;
	output reg [$clog2(SQ_DEPTH + 1) - 1:0] sqCountOutput;
	input wire [59:0] loadAllocationLanesInput;
	input wire [187:0] storeAllocationLanesInput;
	output reg [3:0] loadAllocationLanesFireOutput;
	output reg [3:0] storeAllocationLanesFireOutput;
	output reg [(4 * $clog2(LQ_DEPTH)) - 1:0] loadPreviewIndexOutput;
	output reg [(4 * $clog2(SQ_DEPTH)) - 1:0] storePreviewIndexOutput;
	output reg [$clog2(LQ_DEPTH + 1) - 1:0] loadCreditsOutput;
	output reg [$clog2(SQ_DEPTH + 1) - 1:0] storeCreditsOutput;
	input wire loadYieldEnableInput;
	generate
		if (((RENAME_WIDTH != 1) && (RENAME_WIDTH != 2)) && (RENAME_WIDTH != 4)) begin : g_invalid_rename_width
			initial $fatal(1, "RENAME_WIDTH must be 1, 2 or 4");
		end
		if (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] LQ_INDEX_W = $clog2(LQ_DEPTH);
	localparam [31:0] SQ_INDEX_W = $clog2(SQ_DEPTH);
	function automatic [LQ_INDEX_W - 1:0] sv2v_cast_2B0BB;
		input reg [LQ_INDEX_W - 1:0] inp;
		sv2v_cast_2B0BB = inp;
	endfunction
	wire [LQ_INDEX_W - 1:0] loadAddressIndexInner = sv2v_cast_2B0BB(addressIndexInput);
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	wire loadAddressInRangeInner = sv2v_cast_32_signed(addressIndexInput) < LQ_DEPTH;
	reg [LQ_DEPTH - 1:0] loadRequestBaseInner;
	reg [LQ_DEPTH - 1:0] loadInsertableInner;
	reg [LQ_DEPTH - 1:0] loadPendingAddressInner;
	reg [LQ_DEPTH - 1:0] loadRequestBaseNextInner;
	reg [LQ_DEPTH - 1:0] loadInsertableNextInner;
	reg [LQ_DEPTH - 1:0] loadPendingAddressNextInner;
	reg [(LQ_DEPTH * rv32_pkg_ROB_TAG_W) - 1:0] summaryTagNextInner;
	wire [(LQ_DEPTH * LQ_DEPTH) - 1:0] loadPairOlderCachedInner;
	reg [4:0] lqTagInner [0:LQ_DEPTH - 1];
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	wire loadSummaryTagEventInner = (((addressInput[38] && !addressInput[37]) && loadAddressInRangeInner) && (lqTagInner[loadAddressIndexInner] == addressInput[36-:5])) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(addressInput[36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
	reg lqValidInner [0:LQ_DEPTH - 1];
	reg [5:0] lqDestInner [0:LQ_DEPTH - 1];
	reg [1:0] lqSizeInner [0:LQ_DEPTH - 1];
	reg lqUnsignedInner [0:LQ_DEPTH - 1];
	reg lqAddressReadyInner [0:LQ_DEPTH - 1];
	reg [31:0] lqAddressInner [0:LQ_DEPTH - 1];
	reg lqSentInner [0:LQ_DEPTH - 1];
	reg lqResultReadyInner [0:LQ_DEPTH - 1];
	reg lqBroadcastedInner [0:LQ_DEPTH - 1];
	reg [31:0] lqResultInner [0:LQ_DEPTH - 1];
	reg sqValidInner [0:SQ_DEPTH - 1];
	reg [4:0] sqTagInner [0:SQ_DEPTH - 1];
	reg [1:0] sqSizeInner [0:SQ_DEPTH - 1];
	reg sqAddressReadyInner [0:SQ_DEPTH - 1];
	reg [31:0] sqAddressInner [0:SQ_DEPTH - 1];
	reg sqDataReadyInner [0:SQ_DEPTH - 1];
	reg [5:0] sqDataTagInner [0:SQ_DEPTH - 1];
	reg [31:0] sqDataInner [0:SQ_DEPTH - 1];
	reg sqCommittedInner [0:SQ_DEPTH - 1];
	reg sqIsExitInner [0:SQ_DEPTH - 1];
	reg [SQ_INDEX_W:0] sqHeadSeqInner;
	reg [SQ_INDEX_W:0] sqTailSeqInner;
	wire [SQ_INDEX_W - 1:0] sqHeadIndexInner;
	reg [SQ_INDEX_W:0] sqRetainedCountInner;
	reg [2:0] fifoHeadInner;
	reg [2:0] fifoTailInner;
	reg [rv32_pkg_DATA_TRANSACTION_W:0] fifoCountInner;
	reg [LQ_INDEX_W - 1:0] fifoIndexInner [0:7];
	reg [4:0] fifoTagInner [0:7];
	reg fifoDropInner [0:7];
	reg fifoValidInner [0:7];
	wire [2:0] responseOwnerInner;
	reg [2:0] allocationOwnerInner;
	function automatic [2:0] sv2v_cast_70E94;
		input reg [2:0] inp;
		sv2v_cast_70E94 = inp;
	endfunction
	always @* begin : sv2v_autoblock_3
		reg found;
		reg signed [31:0] slot;
		found = 0;
		allocationOwnerInner = fifoTailInner;
		begin : sv2v_autoblock_4
			reg signed [31:0] i;
			for (i = 0; i < rv32_pkg_DATA_REQUEST_ENTRIES; i = i + 1)
				begin
					slot = (sv2v_cast_32_signed(fifoTailInner) + i) & 7;
					if ((TAGGED_DMEM && !found) && !fifoValidInner[slot]) begin
						allocationOwnerInner = sv2v_cast_70E94(slot);
						found = 1;
					end
				end
		end
	end
	assign responseOwnerInner = (TAGGED_DMEM ? dmemRspTransactionInput : fifoHeadInner);
	assign dmemReqTransactionOutput = allocationOwnerInner;
	reg loadAllocFoundInner;
	reg storeAllocFoundInner;
	wire loadAllocFireInner;
	wire loadAllocSecondFireInner;
	wire storeAllocFireInner;
	wire storeAllocSecondFireInner;
	wire [SQ_INDEX_W:0] storeAllocCountInner;
	reg [SQ_INDEX_W:0] storeAllocLanesCountInner;
	reg [(4 * LQ_INDEX_W) - 1:0] loadLanesIndexInner;
	reg [(4 * SQ_INDEX_W) - 1:0] storeLanesIndexInner;
	wire [3:0] storeLanesDataReadyInner;
	wire [127:0] storeLanesDataValueInner;
	wire [SQ_INDEX_W:0] sqUsedInner;
	assign sqUsedInner = sqTailSeqInner - sqHeadSeqInner;
	wire storeAllocSecondDataReadyInner;
	wire [31:0] storeAllocSecondDataValueInner;
	assign loadAllocFireInner = loadAllocationInput[14] && loadAllocReadyOutput;
	assign loadAllocSecondFireInner = ((RENAME_WIDTH == 2) && loadAllocationSecondInput[14]) && loadAllocSecondReadyOutput;
	assign storeAllocFireInner = storeAllocationInput[46] && storeAllocReadyOutput;
	assign storeAllocSecondFireInner = ((RENAME_WIDTH == 2) && storeAllocationSecondInput[46]) && storeAllocSecondReadyOutput;
	function automatic [((SQ_INDEX_W + 0) >= 0 ? SQ_INDEX_W + 1 : 1 - (SQ_INDEX_W + 0)) - 1:0] sv2v_cast_84930;
		input reg [((SQ_INDEX_W + 0) >= 0 ? SQ_INDEX_W + 1 : 1 - (SQ_INDEX_W + 0)) - 1:0] inp;
		sv2v_cast_84930 = inp;
	endfunction
	assign storeAllocCountInner = (RENAME_WIDTH == 4 ? storeAllocLanesCountInner : sv2v_cast_84930(storeAllocFireInner) + sv2v_cast_84930(storeAllocSecondFireInner));
	wire loadSelectFoundInner;
	wire [LQ_INDEX_W - 1:0] loadSelectIndexInner;
	wire [4:0] loadSelectTagInner;
	wire [31:0] loadSelectAddressInner;
	localparam [31:0] LOAD_SELECT_LEAVES = 1 << LQ_INDEX_W;
	wire [LQ_DEPTH - 1:0] loadSelectCandidatesInner;
	wire [(LQ_DEPTH * rv32_pkg_ROB_TAG_W) - 1:0] loadSelectTagsInner;
	wire [(6 + LQ_INDEX_W) - 1:0] loadSelectWinnerInner;
	reg loadBlockedInner;
	wire loadRequestUsesAddressInner;
	wire [LQ_DEPTH - 1:0] oldRequestCacheBlockedInner;
	wire [LQ_DEPTH - 1:0] oldRequestYieldsInner;
	wire [LQ_DEPTH - 1:0] oldPostedStoreBlocksInner;
	wire [SQ_DEPTH - 1:0] postedStoreUnsafeInner;
	wire [SQ_DEPTH - 1:0] incomingPostedBlockInner;
	wire incomingRequestYieldsInner;
	wire selectedRequestYieldsInner;
	reg loadNeedsMemoryInner;
	reg selectedLoadLiveInner;
	wire storeDataEventInner [0:STORE_DATA_LANES - 1];
	wire storeAddressEventInner;
	wire loadAddressEventInner;
	reg lqEarlyForwardInner [0:LQ_DEPTH - 1];
	reg [31:0] lqEarlyValueInner [0:LQ_DEPTH - 1];
	reg [37:0] selectedForwardInner;
	reg [37:0] addressedForwardInner;
	wire addressedForwardValidInner;
	integer forwardIndexInner;
	wire resultSelectFoundInner;
	wire [LQ_INDEX_W - 1:0] resultSelectIndexInner;
	wire [4:0] resultSelectTagInner;
	wire [LQ_DEPTH - 1:0] resultSelectCandidatesInner;
	wire [(6 + LQ_INDEX_W) - 1:0] resultSelectWinnerInner;
	reg [(6 + LQ_INDEX_W) - 1:0] bufferedResultWinnerInner;
	wire chooseResponseResultInner;
	wire responseResultLiveInner;
	wire responseResultIdentityLiveInner;
	reg responseForwardPriorityInner;
	wire [LQ_INDEX_W - 1:0] responseResultIndexInner;
	assign responseResultIndexInner = fifoIndexInner[responseOwnerInner];
	reg storeAllocDataReadyResolvedInner;
	reg [31:0] storeAllocDataValueResolvedInner;
	wire [COMMIT_WIDTH - 1:0] storeCommitMatchInner;
	wire [COMMIT_WIDTH - 1:0] storeRetireFireInner;
	reg storeAvailableInner;
	reg storeSendSelectedInner;
	reg storeYieldDebtInner;
	reg loadBypassStoreInner;
	reg postedStoreBlocksLoadInner;
	reg [SQ_DEPTH - 1:0] postedStoreMaskInner;
	wire [SQ_DEPTH - 1:0] pressureSqValidInner;
	wire pressureLowInner;
	genvar _gv_row_23;
	generate
		for (_gv_row_23 = 0; _gv_row_23 < SQ_DEPTH; _gv_row_23 = _gv_row_23 + 1) begin : g_pressure_sq
			localparam row = _gv_row_23;
			assign pressureSqValidInner[row] = sqValidInner[row];
		end
	endgenerate
	assign pressureLowInner = ($countones(pressureSqValidInner) <= 4) && (sv2v_cast_32_signed(fifoCountInner) <= 0);
	reg loadAddressMatchInner;
	reg storeAddressMatchInner;
	reg loadRequestSelectedInner;
	integer combIndexInner;
	integer seqIndexInner;
	integer storeLaneInner;
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic signed [LQ_INDEX_W - 1:0] sv2v_cast_2B0BB_signed;
		input reg signed [LQ_INDEX_W - 1:0] inp;
		sv2v_cast_2B0BB_signed = inp;
	endfunction
	function automatic [(6 + LQ_INDEX_W) - 1:0] select_oldest_load;
		input reg [LQ_DEPTH - 1:0] validInput;
		input reg [(LQ_DEPTH * rv32_pkg_ROB_TAG_W) - 1:0] tagsInput;
		reg [(6 + LQ_INDEX_W) - 1:0] tree [0:(2 * LOAD_SELECT_LEAVES) - 1];
		begin
			tree[0] = 1'sb0;
			begin : sv2v_autoblock_5
				reg signed [31:0] leaf;
				for (leaf = 0; leaf < LOAD_SELECT_LEAVES; leaf = leaf + 1)
					begin
						tree[LOAD_SELECT_LEAVES + leaf] = 1'sb0;
						if (leaf < LQ_DEPTH)
							tree[LOAD_SELECT_LEAVES + leaf] = {validInput[leaf], sv2v_cast_60734(tagsInput[leaf * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W]), sv2v_cast_2B0BB(sv2v_cast_2B0BB_signed(leaf))};
					end
			end
			begin : sv2v_autoblock_6
				reg signed [31:0] node;
				for (node = LOAD_SELECT_LEAVES - 1; node > 0; node = node - 1)
					begin
						tree[node] = tree[2 * node];
						if (tree[(2 * node) + 1][1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] && (!tree[2 * node][1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] || rv32_pkg_rob_is_older(tree[(2 * node) + 1][rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)], tree[2 * node][rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)])))
							tree[node] = tree[(2 * node) + 1];
					end
			end
			if (!tree[1][1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))])
				tree[1][LQ_INDEX_W - 1-:LQ_INDEX_W] = 1'sb0;
			select_oldest_load = tree[1];
		end
	endfunction
	wire [(LQ_DEPTH * LQ_DEPTH) - 1:0] loadTreePairOlderInner;
	genvar _gv_right_1;
	generate
		for (_gv_right_1 = 0; _gv_right_1 < LQ_DEPTH; _gv_right_1 = _gv_right_1 + 1) begin : g_load_tree_pair_right
			localparam right = _gv_right_1;
			genvar _gv_left_1;
			for (_gv_left_1 = 0; _gv_left_1 < LQ_DEPTH; _gv_left_1 = _gv_left_1 + 1) begin : g_left
				localparam left = _gv_left_1;
				if (right > left) begin : g_pair
					assign loadTreePairOlderInner[(right * LQ_DEPTH) + left] = loadPairOlderCachedInner[(right * LQ_DEPTH) + left];
				end
				else begin : g_unused_pair
					assign loadTreePairOlderInner[(right * LQ_DEPTH) + left] = 1'b0;
					assign loadPairOlderCachedInner[(right * LQ_DEPTH) + left] = 1'b0;
				end
			end
		end
	endgenerate
	function automatic signed [LQ_DEPTH - 1:0] sv2v_cast_24422_signed;
		input reg signed [LQ_DEPTH - 1:0] inp;
		sv2v_cast_24422_signed = inp;
	endfunction
	function automatic [(6 + LQ_INDEX_W) - 1:0] select_load_pair_flags;
		input reg [LQ_DEPTH - 1:0] validInput;
		input reg [(LQ_DEPTH * rv32_pkg_ROB_TAG_W) - 1:0] tagsInput;
		input reg [(LQ_DEPTH * LQ_DEPTH) - 1:0] olderInput;
		reg [LQ_DEPTH - 1:0] pathTree [0:(2 * LOAD_SELECT_LEAVES) - 1];
		reg validTree [0:(2 * LOAD_SELECT_LEAVES) - 1];
		reg rightOlder;
		reg [(6 + LQ_INDEX_W) - 1:0] answer;
		begin
			pathTree[0] = 1'sb0;
			validTree[0] = 1'b0;
			begin : sv2v_autoblock_7
				reg signed [31:0] leaf;
				for (leaf = 0; leaf < LOAD_SELECT_LEAVES; leaf = leaf + 1)
					begin
						pathTree[LOAD_SELECT_LEAVES + leaf] = 1'sb0;
						validTree[LOAD_SELECT_LEAVES + leaf] = 1'b0;
						if (leaf < LQ_DEPTH) begin
							pathTree[LOAD_SELECT_LEAVES + leaf] = sv2v_cast_24422_signed(1) << leaf;
							validTree[LOAD_SELECT_LEAVES + leaf] = validInput[leaf];
						end
					end
			end
			begin : sv2v_autoblock_8
				reg signed [31:0] node;
				for (node = LOAD_SELECT_LEAVES - 1; node > 0; node = node - 1)
					begin
						rightOlder = 1'b0;
						begin : sv2v_autoblock_9
							reg signed [31:0] right;
							for (right = 1; right < LQ_DEPTH; right = right + 1)
								begin : sv2v_autoblock_10
									reg signed [31:0] left;
									for (left = 0; left < right; left = left + 1)
										rightOlder = rightOlder | ((pathTree[(2 * node) + 1][right] && pathTree[2 * node][left]) && olderInput[(right * LQ_DEPTH) + left]);
								end
						end
						pathTree[node] = pathTree[2 * node];
						validTree[node] = validTree[2 * node];
						if (validTree[(2 * node) + 1] && (!validTree[2 * node] || rightOlder)) begin
							pathTree[node] = pathTree[(2 * node) + 1];
							validTree[node] = validTree[(2 * node) + 1];
						end
					end
			end
			answer = 1'sb0;
			answer[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] = validTree[1];
			begin : sv2v_autoblock_11
				reg signed [31:0] row;
				for (row = 0; row < LQ_DEPTH; row = row + 1)
					begin
						answer[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)] = answer[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)] | (tagsInput[row * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] & {rv32_pkg_ROB_TAG_W {pathTree[1][row]}});
						answer[LQ_INDEX_W - 1-:LQ_INDEX_W] = answer[LQ_INDEX_W - 1-:LQ_INDEX_W] | (sv2v_cast_2B0BB_signed(row) & {LQ_INDEX_W {pathTree[1][row]}});
					end
			end
			if (!answer[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))])
				answer[LQ_INDEX_W - 1-:LQ_INDEX_W] = 1'sb0;
			select_load_pair_flags = answer;
		end
	endfunction
	genvar _gv_row_24;
	function automatic signed [($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH) ? $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH)) - 1:0] sv2v_cast_EE378_signed;
		input reg signed [($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH) ? $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH)) - 1:0] inp;
		sv2v_cast_EE378_signed = inp;
	endfunction
	generate
		for (_gv_row_24 = 0; _gv_row_24 < LQ_DEPTH; _gv_row_24 = _gv_row_24 + 1) begin : g_load_select_candidate
			localparam row = _gv_row_24;
			assign loadSelectCandidatesInner[row] = ((lqValidInner[row] && (lqAddressReadyInner[row] || ((loadAddressEventInner && (addressIndexInput == sv2v_cast_EE378_signed(row))) && !(!lqBroadcastedInner[row] && addressedForwardValidInner)))) && !lqSentInner[row]) && !lqResultReadyInner[row];
			assign loadSelectTagsInner[row * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = lqTagInner[row];
			assign resultSelectCandidatesInner[row] = (lqValidInner[row] && lqResultReadyInner[row]) && !lqBroadcastedInner[row];
		end
	endgenerate
	wire [LQ_DEPTH - 1:0] loadInsertBaseMaskInner;
	wire [LQ_DEPTH - 1:0] loadInsertEligibleInner;
	wire [(6 + LQ_INDEX_W) - 1:0] loadInsertBaseWinnerInner;
	wire [(6 + LQ_INDEX_W) - 1:0] loadInsertWinnerInner [0:LQ_DEPTH - 1];
	genvar _gv_row_25;
	generate
		for (_gv_row_25 = 0; _gv_row_25 < LQ_DEPTH; _gv_row_25 = _gv_row_25 + 1) begin : g_load_address_insertion
			localparam row = _gv_row_25;
			wire [LQ_DEPTH - 1:0] insertedMask;
			assign loadInsertBaseMaskInner[row] = loadRequestBaseInner[row];
			assign loadInsertEligibleInner[row] = loadInsertableInner[row];
			assign insertedMask = loadInsertBaseMaskInner | ((sv2v_cast_24422_signed(1) << row) & {LQ_DEPTH {loadInsertEligibleInner[row]}});
			assign loadInsertWinnerInner[row] = select_load_pair_flags(insertedMask, loadSelectTagsInner, loadTreePairOlderInner);
		end
	endgenerate
	assign loadInsertBaseWinnerInner = select_load_pair_flags(loadInsertBaseMaskInner, loadSelectTagsInner, loadTreePairOlderInner);
	assign loadSelectWinnerInner = ((loadSummaryTagEventInner && loadInsertableInner[loadAddressIndexInner]) && (lqBroadcastedInner[loadAddressIndexInner] || !addressedForwardValidInner) ? loadInsertWinnerInner[loadAddressIndexInner] : loadInsertBaseWinnerInner);
`ifndef SYNTHESIS
	always @* assert (loadSelectWinnerInner == select_oldest_load(loadSelectCandidatesInner, loadSelectTagsInner)) else $fatal(1, "LQ insertion exact original tree oracle");
`endif
	assign loadSelectFoundInner = loadSelectWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))];
	assign loadSelectIndexInner = loadSelectWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W];
	assign loadSelectTagInner = loadSelectWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)];
	function automatic [($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH) ? $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH)) - 1:0] sv2v_cast_EE378;
		input reg [($clog2(LQ_DEPTH) > $clog2(SQ_DEPTH) ? $clog2(LQ_DEPTH) : $clog2(SQ_DEPTH)) - 1:0] inp;
		sv2v_cast_EE378 = inp;
	endfunction
	assign loadRequestUsesAddressInner = (loadSummaryTagEventInner && loadPendingAddressInner[loadAddressIndexInner]) && (addressIndexInput == sv2v_cast_EE378(loadSelectIndexInner));
	assign loadSelectAddressInner = (loadRequestUsesAddressInner ? addressInput[31-:32] : lqAddressInner[loadSelectIndexInner]);
	always @* bufferedResultWinnerInner = select_oldest_load(resultSelectCandidatesInner, loadSelectTagsInner);
	reg [LQ_INDEX_W - 1:0] previewResultIndexInner;
	reg [4:0] previewResultTagInner;
	assign resultSelectWinnerInner = (chooseResponseResultInner ? {1'b1, sv2v_cast_60734(previewResultTagInner), sv2v_cast_2B0BB(previewResultIndexInner)} : bufferedResultWinnerInner);
	assign resultSelectFoundInner = resultSelectWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))];
	assign resultSelectIndexInner = resultSelectWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W];
	assign resultSelectTagInner = resultSelectWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)];
	wire [LQ_DEPTH - 1:0] resultRowIdentity;
	genvar _gv_row_26;
	generate
		for (_gv_row_26 = 0; _gv_row_26 < LQ_DEPTH; _gv_row_26 = _gv_row_26 + 1) begin : g_result_row_identity
			localparam row = _gv_row_26;
			assign resultRowIdentity[row] = loadIdentityInput[lqTagInner[row]];
		end
	endgenerate
	assign loadWinnerIdentityOutput = resultRowIdentity[resultSelectIndexInner];
	generate
		if (RENAME_WIDTH != 4) begin : g_legacy_address_match
			wire [1:1] sv2v_tmp_F5199;
			assign sv2v_tmp_F5199 = (((loadAddressInRangeInner && lqValidInner[loadAddressIndexInner]) && (lqTagInner[loadAddressIndexInner] == addressInput[36-:5])) || (((loadAllocationInput[14] && loadAllocReadyOutput) && (addressIndexInput == sv2v_cast_EE378(loadAllocIndexOutput))) && (loadAllocationInput[13-:5] == addressInput[36-:5]))) || ((loadAllocSecondFireInner && (addressIndexInput == sv2v_cast_EE378(loadAllocSecondIndexOutput))) && (loadAllocationSecondInput[13-:5] == addressInput[36-:5]));
			always @(*) loadAddressMatchInner = sv2v_tmp_F5199;
			wire [1:1] sv2v_tmp_DFF79;
			assign sv2v_tmp_DFF79 = (((sqValidInner[addressIndexInput] && !sqCommittedInner[addressIndexInput]) && (sqTagInner[addressIndexInput] == addressInput[36-:5])) || (((storeAllocationInput[46] && storeAllocReadyOutput) && (addressIndexInput == sv2v_cast_EE378(storeAllocIndexOutput))) && (storeAllocationInput[45-:5] == addressInput[36-:5]))) || ((storeAllocSecondFireInner && (addressIndexInput == sv2v_cast_EE378(storeAllocSecondIndexOutput))) && (storeAllocationSecondInput[45-:5] == addressInput[36-:5]));
			always @(*) storeAddressMatchInner = sv2v_tmp_DFF79;
		end
		else begin : g_four_address_match
			always @* begin
				loadAddressMatchInner = (loadAddressInRangeInner && lqValidInner[loadAddressIndexInner]) && (lqTagInner[loadAddressIndexInner] == addressInput[36-:5]);
				storeAddressMatchInner = (sqValidInner[addressIndexInput] && !sqCommittedInner[addressIndexInput]) && (sqTagInner[addressIndexInput] == addressInput[36-:5]);
				begin : sv2v_autoblock_12
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						begin
							loadAddressMatchInner = loadAddressMatchInner | ((loadAllocationLanesFireOutput[lane] && (addressIndexInput == sv2v_cast_EE378(loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]))) && (loadAllocationLanesInput[(lane * 15) + 13-:5] == addressInput[36-:5]));
							storeAddressMatchInner = storeAddressMatchInner | ((storeAllocationLanesFireOutput[lane] && (addressIndexInput == sv2v_cast_EE378(storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]))) && (storeAllocationLanesInput[(lane * 47) + 45-:5] == addressInput[36-:5]));
						end
				end
			end
		end
	endgenerate
	genvar _gv_exitLane_1;
	generate
		for (_gv_exitLane_1 = 0; _gv_exitLane_1 < COMMIT_WIDTH; _gv_exitLane_1 = _gv_exitLane_1 + 1) begin : g_exit_output
			localparam exitLane = _gv_exitLane_1;
			assign storeRetirementExitOutput[exitLane] = sqIsExitInner[storeCommitIndexInput[exitLane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]];
		end
	endgenerate
	assign sqHeadIndexInner = sqHeadSeqInner[SQ_INDEX_W - 1:0];
	localparam [31:0] rv32_pkg_DCACHE_LINE_BYTES = 32;
	assign storeHeadSetPreviewOutput = sqAddressInner[sqHeadIndexInner][5+:7];
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if ((rstNInput && dmemRequestOutput[71]) && dmemRequestOutput[70])
			assert (storeHeadSetPreviewOutput == dmemRequestOutput[43+:7]) else $fatal(1, "LSU Store preview boundary mismatch");
`endif
	genvar _gv_lane_35;
	generate
		for (_gv_lane_35 = 0; _gv_lane_35 < COMMIT_WIDTH; _gv_lane_35 = _gv_lane_35 + 1) begin : g_store_commit
			localparam lane = _gv_lane_35;
			assign storeCommitMatchInner[lane] = (((((storeCommitInput[(lane * 6) + 5] && sqValidInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && !sqCommittedInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && (sqTagInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]] == storeCommitInput[(lane * 6) + 4-:rv32_pkg_ROB_TAG_W])) && sqAddressReadyInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && sqDataReadyInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(storeCommitInput[(lane * 6) + 4-:rv32_pkg_ROB_TAG_W], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
			assign storeCommitReadyOutput[lane] = storeCommitMatchInner[lane];
			assign storeRetireFireInner[lane] = (storeCommitMatchInner[lane] && robRetireInput[(lane * 6) + 5]) && (robRetireInput[(lane * 6) + 4-:rv32_pkg_ROB_TAG_W] == storeCommitInput[(lane * 6) + 4-:rv32_pkg_ROB_TAG_W]);
			always @* begin
				storeRetirementOutput[lane * 72+:72] = 1'sb0;
				storeRetirementOutput[(lane * 72) + 71] = storeCommitMatchInner[lane];
				storeRetirementOutput[(lane * 72) + 70] = 1'b1;
				storeRetirementOutput[(lane * 72) + 69-:32] = sqAddressInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]];
				storeRetirementOutput[(lane * 72) + 37-:32] = sqDataInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]];
				storeRetirementOutput[(lane * 72) + 1-:2] = sqSizeInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]];
				(* full_case, parallel_case *)
				case (sqSizeInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]])
					2'd0: storeRetirementOutput[(lane * 72) + 5-:4] = 4'b0001;
					2'd1: storeRetirementOutput[(lane * 72) + 5-:4] = 4'b0011;
					default: storeRetirementOutput[(lane * 72) + 5-:4] = 4'b1111;
				endcase
			end
		end
	endgenerate
	wire [SQ_INDEX_W - 1:0] sqOrderInner [0:SQ_DEPTH - 1];
	genvar _gv_orderRow_1;
	function automatic signed [SQ_INDEX_W - 1:0] sv2v_cast_41EA4_signed;
		input reg signed [SQ_INDEX_W - 1:0] inp;
		sv2v_cast_41EA4_signed = inp;
	endfunction
	generate
		for (_gv_orderRow_1 = 0; _gv_orderRow_1 < SQ_DEPTH; _gv_orderRow_1 = _gv_orderRow_1 + 1) begin : g_sq_order
			localparam orderRow = _gv_orderRow_1;
			assign sqOrderInner[orderRow] = sv2v_cast_41EA4_signed(orderRow) - sqHeadIndexInner;
		end
	endgenerate
	function automatic [31:0] extend_load;
		input reg [31:0] valueInput;
		input reg [1:0] sizeInput;
		input reg isUnsignedInput;
		(* full_case, parallel_case *)
		case (sizeInput)
			2'd0: extend_load = (isUnsignedInput ? {24'b000000000000000000000000, valueInput[7:0]} : {{24 {valueInput[7]}}, valueInput[7:0]});
			2'd1: extend_load = (isUnsignedInput ? {16'b0000000000000000, valueInput[15:0]} : {{16 {valueInput[15]}}, valueInput[15:0]});
			default: extend_load = valueInput;
		endcase
	endfunction
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [1:0] word_neighbors;
		input reg [29:0] loadWordInput;
		input reg [29:0] storeWordInput;
		reg [5:0] sameChunk;
		reg [5:0] upChunk;
		reg [5:0] downChunk;
		reg [5:0] upWrap;
		reg [5:0] downWrap;
		reg [5:0] nextTerms;
		reg [5:0] prevTerms;
		begin
			begin : sv2v_autoblock_13
				reg signed [31:0] chunk;
				for (chunk = 0; chunk < 6; chunk = chunk + 1)
					begin
						sameChunk[chunk] = loadWordInput[5 * chunk+:5] == storeWordInput[5 * chunk+:5];
						upChunk[chunk] = (storeWordInput[5 * chunk+:5] != 5'd31) && (loadWordInput[5 * chunk+:5] == (storeWordInput[5 * chunk+:5] + 5'd1));
						downChunk[chunk] = (storeWordInput[5 * chunk+:5] != 5'd0) && (loadWordInput[5 * chunk+:5] == (storeWordInput[5 * chunk+:5] - 5'd1));
						upWrap[chunk] = (storeWordInput[5 * chunk+:5] == 5'd31) && (loadWordInput[5 * chunk+:5] == 5'd0);
						downWrap[chunk] = (storeWordInput[5 * chunk+:5] == 5'd0) && (loadWordInput[5 * chunk+:5] == 5'd31);
					end
			end
			begin : sv2v_autoblock_14
				reg signed [31:0] chunk;
				for (chunk = 0; chunk < 6; chunk = chunk + 1)
					begin
						nextTerms[chunk] = (upChunk[chunk] && &(sameChunk | sv2v_cast_6_signed((2 << chunk) - 1))) && &(upWrap | ~sv2v_cast_6_signed((1 << chunk) - 1));
						prevTerms[chunk] = (downChunk[chunk] && &(sameChunk | sv2v_cast_6_signed((2 << chunk) - 1))) && &(downWrap | ~sv2v_cast_6_signed((1 << chunk) - 1));
					end
			end
			word_neighbors = {|prevTerms, |nextTerms};
		end
	endfunction
	function automatic [2:0] rv32_pkg_mem_bytes;
		input reg [1:0] sizeInput;
		(* full_case, parallel_case *)
		case (sizeInput)
			2'd0: rv32_pkg_mem_bytes = 3'd1;
			2'd1: rv32_pkg_mem_bytes = 3'd2;
			default: rv32_pkg_mem_bytes = 3'd4;
		endcase
	endfunction
	function automatic byte_overlap;
		input reg [31:0] loadAddressInput;
		input reg [1:0] loadSizeInput;
		input reg [31:0] storeAddressInput;
		input reg [1:0] storeSizeInput;
		reg [2:0] loadOffset;
		reg [2:0] storeOffset;
		reg [2:0] loadSpan;
		reg [2:0] storeSpan;
		reg [2:0] loadEnd;
		reg [2:0] storeEnd;
		reg [1:0] neighbors;
		begin
			loadOffset = {1'b0, loadAddressInput[1:0]};
			storeOffset = {1'b0, storeAddressInput[1:0]};
			loadSpan = rv32_pkg_mem_bytes(loadSizeInput);
			storeSpan = rv32_pkg_mem_bytes(storeSizeInput);
			loadEnd = loadOffset + loadSpan;
			storeEnd = storeOffset + storeSpan;
			neighbors = word_neighbors(loadAddressInput[31:2], storeAddressInput[31:2]);
			byte_overlap = ((((loadAddressInput[31:2] == storeAddressInput[31:2]) && (loadOffset < storeEnd)) && (storeOffset < loadEnd)) || (neighbors[0] && ((loadOffset + 3'sd4) < storeEnd))) || (neighbors[1] && ((storeOffset + 3'sd4) < loadEnd));
		end
	endfunction
	function automatic [32:0] sv2v_cast_33;
		input reg [32:0] inp;
		sv2v_cast_33 = inp;
	endfunction
	function automatic yield_ram_access;
		input reg [31:0] address;
		input reg [1:0] size;
		reg [32:0] last;
		begin
			last = ({1'b0, address} + sv2v_cast_33(rv32_pkg_mem_bytes(size))) - 33'sd1;
			yield_ram_access = (((((size == 2'd0) || (size == 2'd1)) || (size == 2'd2)) && (address < 32'h10000000)) && (last < 33'h010000000)) && (address[31:5] == last[31:5]);
		end
	endfunction
	assign storeAddressEventInner = ((((addressInput[38] && addressInput[37]) && sqValidInner[addressIndexInput]) && !sqCommittedInner[addressIndexInput]) && (sqTagInner[addressIndexInput] == addressInput[36-:5])) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(addressInput[36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
	assign loadAddressEventInner = ((((addressInput[38] && !addressInput[37]) && loadAddressInRangeInner) && lqValidInner[loadAddressIndexInner]) && (lqTagInner[loadAddressIndexInner] == addressInput[36-:5])) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(addressInput[36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
	genvar _gv_lane_36;
	generate
		for (_gv_lane_36 = 0; _gv_lane_36 < STORE_DATA_LANES; _gv_lane_36 = _gv_lane_36 + 1) begin : g_store_event
			localparam lane = _gv_lane_36;
			assign storeDataEventInner[lane] = (((storeDataInput[(lane * 38) + 37] && sqValidInner[storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && !sqCommittedInner[storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && (sqTagInner[storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]] == storeDataInput[(lane * 38) + 36-:5])) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(storeDataInput[(lane * 38) + 36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
		end
	endgenerate
	function automatic [37:0] query_store_forward;
		input reg [4:0] loadTagInput;
		input reg [31:0] loadAddressInput;
		input reg [1:0] loadSizeInput;
		reg [37:0] result;
		reg found;
		reg addressReady;
		reg dataReady;
		reg unknownFound;
		reg [SQ_INDEX_W - 1:0] youngestIndex;
		reg [SQ_INDEX_W - 1:0] youngestUnknownIndex;
		reg [31:0] youngestAddress;
		reg [31:0] youngestData;
		reg [1:0] youngestSize;
		reg youngestReady;
		reg [31:0] address;
		reg [31:0] data;
		reg [1:0] byteOffset;
		reg [2:0] coverEnd;
		begin
			result = 1'sb0;
			found = 1'b0;
			youngestIndex = 1'sb0;
			youngestAddress = 1'sb0;
			youngestData = 1'sb0;
			youngestSize = 2'd2;
			youngestReady = 1'b0;
			unknownFound = 1'b0;
			youngestUnknownIndex = 1'sb0;
			begin : sv2v_autoblock_15
				reg signed [31:0] s;
				for (s = 0; s < SQ_DEPTH; s = s + 1)
					if (sqValidInner[s] && (sqCommittedInner[s] || rv32_pkg_rob_is_older(sqTagInner[s], loadTagInput))) begin
						addressReady = sqAddressReadyInner[s];
						address = sqAddressInner[s];
						dataReady = sqDataReadyInner[s];
						data = sqDataInner[s];
						if (!sqCommittedInner[s] && (!sqAddressReadyInner[s] || byte_overlap(loadAddressInput, loadSizeInput, sqAddressInner[s], sqSizeInner[s])))
							result[36] = 1'b1;
						if (!addressReady) begin
							if (!unknownFound || (sqOrderInner[s] > sqOrderInner[youngestUnknownIndex]))
								youngestUnknownIndex = sv2v_cast_41EA4_signed(s);
							unknownFound = 1'b1;
						end
						else if (byte_overlap(loadAddressInput, loadSizeInput, address, sqSizeInner[s]) && (!found || (sqOrderInner[s] > sqOrderInner[youngestIndex]))) begin
							found = 1'b1;
							youngestIndex = sv2v_cast_41EA4_signed(s);
							youngestAddress = address;
							youngestData = data;
							youngestSize = sqSizeInner[s];
							youngestReady = dataReady;
						end
					end
			end
			result[37] = unknownFound && (!found || (sqOrderInner[youngestUnknownIndex] >= sqOrderInner[youngestIndex]));
			byteOffset = loadAddressInput[1:0] - youngestAddress[1:0];
			coverEnd = {1'b0, byteOffset} + rv32_pkg_mem_bytes(loadSizeInput);
			if ((found && youngestReady) && (coverEnd <= rv32_pkg_mem_bytes(youngestSize))) begin
				result[35-:4] = (loadSizeInput == 2'd0 ? 4'b0001 : (loadSizeInput == 2'd1 ? 4'b0011 : 4'b1111));
				result[31-:32] = youngestData >> {byteOffset, 3'b000};
			end
			query_store_forward = result;
		end
	endfunction
	function automatic query_request_cache_block;
		input reg [4:0] loadTagInput;
		input reg [31:0] loadAddressInput;
		input reg [1:0] loadSizeInput;
		reg blocked;
		begin
			blocked = 1'b0;
			begin : sv2v_autoblock_16
				reg signed [31:0] s;
				for (s = 0; s < SQ_DEPTH; s = s + 1)
					if (((sqValidInner[s] && !sqCommittedInner[s]) && rv32_pkg_rob_is_older(sqTagInner[s], loadTagInput)) && (!sqAddressReadyInner[s] || byte_overlap(loadAddressInput, loadSizeInput, sqAddressInner[s], sqSizeInner[s])))
						blocked = 1'b1;
			end
			query_request_cache_block = blocked;
		end
	endfunction
	function automatic notify_matches;
		input reg [SQ_INDEX_W - 1:0] sourceInput;
		input reg [31:0] sourceAddressInput;
		input reg [4:0] loadTagInput;
		input reg [31:0] loadAddressInput;
		input reg [1:0] loadSizeInput;
		reg matched;
		begin
			matched = ((sourceAddressInput == loadAddressInput) && (sqSizeInner[sourceInput] == loadSizeInput)) && rv32_pkg_rob_is_older(sqTagInner[sourceInput], loadTagInput);
			begin : sv2v_autoblock_17
				reg signed [31:0] s;
				for (s = 0; s < SQ_DEPTH; s = s + 1)
					if (((sqValidInner[s] && (sqOrderInner[s] > sqOrderInner[sourceInput])) && rv32_pkg_rob_is_older(sqTagInner[s], loadTagInput)) && (!sqAddressReadyInner[s] || (sqAddressInner[s][31:2] == sourceAddressInput[31:2])))
						matched = 1'b0;
			end
			notify_matches = matched;
		end
	endfunction
	function automatic query_store_forward_valid;
		input reg [4:0] loadTagInput;
		input reg [31:0] loadAddressInput;
		input reg [1:0] loadSizeInput;
		reg [SQ_DEPTH - 1:0] relevant;
		reg [SQ_DEPTH - 1:0] covering;
		reg [SQ_DEPTH - 1:0] winners;
		reg [SQ_DEPTH - 1:0] younger;
		reg eligible;
		reg overlaps;
		reg [1:0] byteOffset;
		reg [2:0] coverEnd;
		begin
			relevant = 1'sb0;
			covering = 1'sb0;
			winners = 1'sb0;
			younger = 1'sb0;
			eligible = 1'b0;
			overlaps = 1'b0;
			byteOffset = 1'sb0;
			coverEnd = 1'sb0;
			begin : sv2v_autoblock_18
				reg signed [31:0] s;
				for (s = 0; s < SQ_DEPTH; s = s + 1)
					begin
						eligible = sqValidInner[s] && (sqCommittedInner[s] || rv32_pkg_rob_is_older(sqTagInner[s], loadTagInput));
						overlaps = byte_overlap(loadAddressInput, loadSizeInput, sqAddressInner[s], sqSizeInner[s]);
						relevant[s] = eligible && (!sqAddressReadyInner[s] || overlaps);
						byteOffset = loadAddressInput[1:0] - sqAddressInner[s][1:0];
						coverEnd = {1'b0, byteOffset} + rv32_pkg_mem_bytes(loadSizeInput);
						covering[s] = (((eligible && sqAddressReadyInner[s]) && overlaps) && sqDataReadyInner[s]) && (coverEnd <= rv32_pkg_mem_bytes(sqSizeInner[s]));
					end
			end
			begin : sv2v_autoblock_19
				reg signed [31:0] s;
				for (s = 0; s < SQ_DEPTH; s = s + 1)
					begin
						younger = 1'sb0;
						begin : sv2v_autoblock_20
							reg signed [31:0] t;
							for (t = 0; t < SQ_DEPTH; t = t + 1)
								younger[t] = relevant[t] && (sqOrderInner[t] > sqOrderInner[s]);
						end
						winners[s] = covering[s] && !(|younger);
					end
			end
			query_store_forward_valid = |winners;
		end
	endfunction
	wire [SQ_DEPTH - 1:0] oldNotifyMatchInner [0:LQ_DEPTH - 1];
	genvar _gv_notifyLoad_1;
	generate
		for (_gv_notifyLoad_1 = 0; _gv_notifyLoad_1 < LQ_DEPTH; _gv_notifyLoad_1 = _gv_notifyLoad_1 + 1) begin : g_notify_load
			localparam notifyLoad = _gv_notifyLoad_1;
			genvar _gv_notifyStore_1;
			for (_gv_notifyStore_1 = 0; _gv_notifyStore_1 < SQ_DEPTH; _gv_notifyStore_1 = _gv_notifyStore_1 + 1) begin : g_notify_store
				localparam notifyStore = _gv_notifyStore_1;
				assign oldNotifyMatchInner[notifyLoad][notifyStore] = (lqAddressReadyInner[notifyLoad] && sqAddressReadyInner[notifyStore]) && notify_matches(sv2v_cast_41EA4_signed(notifyStore), sqAddressInner[notifyStore], lqTagInner[notifyLoad], lqAddressInner[notifyLoad], lqSizeInner[notifyLoad]);
			end
		end
	endgenerate
	reg [5:0] previewResultDestinationInner;
	reg [1:0] previewResultSizeInner;
	reg previewResultUnsignedInner;
	reg [43:0] previewCdbPacketInner;
	wire directStorePacketInner;
	function automatic [5:0] sv2v_cast_A32BA;
		input reg [5:0] inp;
		sv2v_cast_A32BA = inp;
	endfunction
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	generate
		if (RESPONSE_PREVIEW && TAGGED_DMEM) begin : g_response_preview
			wire [LQ_DEPTH - 1:0] rowLive;
			wire [LQ_DEPTH - 1:0] rowBeatsBuffered;
			wire [LQ_DEPTH - 1:0] rowAddressForward;
			wire [LQ_DEPTH - 1:0] rowStoreValue;
			wire [((LQ_INDEX_W + rv32_pkg_ROB_TAG_W) + rv32_pkg_PHY_TAG_W) + 6:0] ownerCandidate [0:7];
			reg [((LQ_INDEX_W + rv32_pkg_ROB_TAG_W) + rv32_pkg_PHY_TAG_W) + 6:0] selectedCandidate [0:2];
			wire [2:0] identityRows;
			wire [2:0] forwardRows;
			wire [2:0] winnerRows;
			wire [2:0] selectedRows;
			wire [2:0] storeValueRows;
			wire [2:0] addressForwardRows;
			wire [8:0] owners;
			wire [LQ_INDEX_W - 1:0] indices [0:2];
			wire bufferedWritebackValid;
			assign bufferedWritebackValid = bufferedResultWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] && (!flushInfoInput[5] || rv32_pkg_rob_is_older(bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
			assign owners[0+:rv32_pkg_DATA_TRANSACTION_W] = responseOwnerInner;
			assign owners[rv32_pkg_DATA_TRANSACTION_W+:rv32_pkg_DATA_TRANSACTION_W] = responsePreviewTransactionInput[0+:rv32_pkg_DATA_TRANSACTION_W];
			assign owners[6+:rv32_pkg_DATA_TRANSACTION_W] = responsePreviewTransactionInput[rv32_pkg_DATA_TRANSACTION_W+:rv32_pkg_DATA_TRANSACTION_W];
			assign selectedRows = {responsePreviewSelectInput, !(|responsePreviewSelectInput)};
			genvar _gv_row_27;
			for (_gv_row_27 = 0; _gv_row_27 < LQ_DEPTH; _gv_row_27 = _gv_row_27 + 1) begin : g_row_candidate
				localparam row = _gv_row_27;
				wire [STORE_DATA_LANES - 1:0] notifications;
				wire addressOverride = loadAddressEventInner && (addressIndexInput == sv2v_cast_EE378_signed(row));
				genvar _gv_lane_37;
				for (_gv_lane_37 = 0; _gv_lane_37 < STORE_DATA_LANES; _gv_lane_37 = _gv_lane_37 + 1) begin : g_notify
					localparam lane = _gv_lane_37;
					assign notifications[lane] = storeDataEventInner[lane] && oldNotifyMatchInner[row][storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]];
				end
				assign rowAddressForward[row] = addressOverride && addressedForwardValidInner;
				assign rowStoreValue[row] = !addressOverride && |notifications;
				assign rowLive[row] = (((lqValidInner[row] && lqSentInner[row]) && !lqResultReadyInner[row]) && !lqBroadcastedInner[row]) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(lqTagInner[row], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
				wire smallerOnTie;
				if (sv2v_cast_2B0BB_signed(row) == {LQ_INDEX_W {1'b1}}) begin : g_max_index
					assign smallerOnTie = 1'b0;
				end
				else begin : g_compare_indices
					assign smallerOnTie = sv2v_cast_2B0BB_signed(row) < bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W];
				end
				assign rowBeatsBuffered[row] = (!bufferedResultWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] || rv32_pkg_rob_is_older(lqTagInner[row], bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)])) || ((lqTagInner[row] == bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)]) && smallerOnTie);
			end
			genvar _gv_owner_1;
			for (_gv_owner_1 = 0; _gv_owner_1 < rv32_pkg_DATA_REQUEST_ENTRIES; _gv_owner_1 = _gv_owner_1 + 1) begin : g_owner_candidate
				localparam owner = _gv_owner_1;
				wire [LQ_INDEX_W - 1:0] index = fifoIndexInner[owner];
				wire identity = ((fifoValidInner[owner] && !fifoDropInner[owner]) && rowLive[index]) && (lqTagInner[index] == fifoTagInner[owner]);
				assign ownerCandidate[owner] = {sv2v_cast_2B0BB(index), sv2v_cast_60734(lqTagInner[index]), sv2v_cast_A32BA(lqDestInner[index]), lqSizeInner[index], lqUnsignedInner[index], identity, rowAddressForward[index], rowStoreValue[index], (identity && !rowAddressForward[index]) && rowBeatsBuffered[index]};
			end
			genvar _gv_option_1;
			for (_gv_option_1 = 0; _gv_option_1 < 3; _gv_option_1 = _gv_option_1 + 1) begin : g_option
				localparam option = _gv_option_1;
				always @* begin : select_candidate
					selectedCandidate[option] = 1'sb0;
					begin : sv2v_autoblock_21
						reg signed [31:0] owner;
						for (owner = 0; owner < rv32_pkg_DATA_REQUEST_ENTRIES; owner = owner + 1)
							selectedCandidate[option] = selectedCandidate[option] | (ownerCandidate[owner] & {(((LQ_INDEX_W + (32'd5 + 32'd6)) + 6) >= 0 ? ((LQ_INDEX_W + rv32_pkg_ROB_TAG_W) + rv32_pkg_PHY_TAG_W) + 7 : 1 - (((LQ_INDEX_W + rv32_pkg_ROB_TAG_W) + rv32_pkg_PHY_TAG_W) + 6)) {owners[option * rv32_pkg_DATA_TRANSACTION_W+:rv32_pkg_DATA_TRANSACTION_W] == sv2v_cast_70E94(owner)}});
					end
				end
				assign indices[option] = selectedCandidate[option][LQ_INDEX_W + 17-:((LQ_INDEX_W + 17) >= 18 ? LQ_INDEX_W : 19 - (LQ_INDEX_W + 17))];
				assign identityRows[option] = selectedCandidate[option][3];
				assign addressForwardRows[option] = selectedCandidate[option][2];
				assign storeValueRows[option] = selectedCandidate[option][1];
				assign forwardRows[option] = addressForwardRows[option] || storeValueRows[option];
				assign winnerRows[option] = selectedCandidate[option][0];
			end
			assign responseResultIdentityLiveInner = dmemResponseInput[32] && |(identityRows & selectedRows);
			wire [1:1] sv2v_tmp_303B9;
			assign sv2v_tmp_303B9 = |(forwardRows & selectedRows);
			always @(*) responseForwardPriorityInner = sv2v_tmp_303B9;
			assign responseResultLiveInner = responseResultIdentityLiveInner && !(|(addressForwardRows & selectedRows));
			assign chooseResponseResultInner = dmemResponseInput[32] && |(winnerRows & selectedRows);
			assign directStorePacketInner = chooseResponseResultInner && |(storeValueRows & selectedRows);
			always @* begin : preview_metadata
				previewResultIndexInner = 1'sb0;
				previewResultTagInner = 1'sb0;
				previewResultDestinationInner = 1'sb0;
				previewResultSizeInner = 2'd0;
				previewResultUnsignedInner = 1'b0;
				begin : sv2v_autoblock_22
					reg signed [31:0] option;
					for (option = 0; option < 3; option = option + 1)
						begin
							previewResultIndexInner = previewResultIndexInner | (indices[option] & {LQ_INDEX_W {selectedRows[option]}});
							previewResultTagInner = previewResultTagInner | (selectedCandidate[option][17-:5] & {rv32_pkg_ROB_TAG_W {selectedRows[option]}});
							previewResultDestinationInner = previewResultDestinationInner | (selectedCandidate[option][12-:6] & {rv32_pkg_PHY_TAG_W {selectedRows[option]}});
							previewResultSizeInner = sv2v_cast_2(previewResultSizeInner | (selectedCandidate[option][6-:2] & {2 {selectedRows[option]}}));
							previewResultUnsignedInner = previewResultUnsignedInner | (selectedCandidate[option][4] && selectedRows[option]);
						end
				end
			end
			always @* begin : preview_cdb_packet_cofactors
				reg [43:0] packet;
				reg useResponse;
				previewCdbPacketInner = 1'sb0;
				packet = 1'sb0;
				useResponse = 1'b0;
				begin : sv2v_autoblock_23
					reg signed [31:0] option;
					for (option = 0; option < 3; option = option + 1)
						begin
							useResponse = dmemResponseInput[32] && winnerRows[option];
							packet[42-:5] = (useResponse ? selectedCandidate[option][17-:5] : bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)]);
							packet[37-:6] = (useResponse ? selectedCandidate[option][12-:6] : lqDestInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]);
							packet[31-:32] = (useResponse ? extend_load((storeValueRows[option] ? lqEarlyValueInner[indices[option]] : dmemResponseInput[31-:32]), selectedCandidate[option][6-:2], selectedCandidate[option][4]) : extend_load(lqResultInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqSizeInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqUnsignedInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]));
							packet[43] = useResponse || bufferedWritebackValid;
							previewCdbPacketInner = previewCdbPacketInner | (packet & {44 {selectedRows[option]}});
						end
				end
			end
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput) begin : selected_owner_oracle
					reg live;
					reg advance;
					reg addressOverride;
					reg addressForward;
					reg storeValue;
					reg [LQ_INDEX_W - 1:0] index;
					reg [43:0] packet;
					reg [4:0] tag;
					index = fifoIndexInner[responseOwnerInner];
					tag = lqTagInner[index];
					live = (((((((dmemResponseInput[32] && fifoValidInner[responseOwnerInner]) && !fifoDropInner[responseOwnerInner]) && lqValidInner[index]) && (tag == fifoTagInner[responseOwnerInner])) && lqSentInner[index]) && !lqResultReadyInner[index]) && !lqBroadcastedInner[index]) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
					addressOverride = loadAddressEventInner && (addressIndexInput == sv2v_cast_EE378(index));
					addressForward = addressOverride && addressedForwardValidInner;
					storeValue = 1'b0;
					begin : sv2v_autoblock_24
						reg signed [31:0] lane;
						for (lane = 0; lane < STORE_DATA_LANES; lane = lane + 1)
							if ((!addressOverride && storeDataEventInner[lane]) && oldNotifyMatchInner[index][storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]])
								storeValue = 1'b1;
					end
					advance = (live && !addressForward) && ((!bufferedResultWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] || rv32_pkg_rob_is_older(tag, bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)])) || ((tag == bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)]) && (index < bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W])));
					packet[42-:5] = (advance ? tag : bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)]);
					packet[37-:6] = (advance ? lqDestInner[index] : lqDestInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]);
					packet[31-:32] = (advance ? extend_load((storeValue ? lqEarlyValueInner[index] : dmemResponseInput[31-:32]), lqSizeInner[index], lqUnsignedInner[index]) : extend_load(lqResultInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqSizeInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqUnsignedInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]));
					packet[43] = (advance || bufferedResultWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))]) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(packet[42-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
					assert (((((packet == loadResultOutput) && (live == responseResultIdentityLiveInner)) && ((live && !addressForward) == responseResultLiveInner)) && (advance == chooseResponseResultInner)) && ((advance && storeValue) == directStorePacketInner)) else $fatal(1, "LSU actual-owner candidate differs from post-route oracle");
				end
			always @* begin
				assert (!chooseResponseResultInner || responseResultLiveInner) else $fatal(1, "Response preview live qualification consistency");
				assert ($onehot0(responsePreviewSelectInput)) else $fatal(1, "Response preview grants not onehot0");
				if (dmemResponseInput[32])
					assert ((!responsePreviewSelectInput[0] || (responsePreviewTransactionInput[0+:rv32_pkg_DATA_TRANSACTION_W] == responseOwnerInner)) && (!responsePreviewSelectInput[1] || (responsePreviewTransactionInput[rv32_pkg_DATA_TRANSACTION_W+:rv32_pkg_DATA_TRANSACTION_W] == responseOwnerInner))) else $fatal(1, "Response preview transaction contract");
			end
`endif
		end
		else begin : g_original_response
			assign directStorePacketInner = 1'b0;
			assign responseResultIdentityLiveInner = (((((((dmemResponseInput[32] && fifoValidInner[responseOwnerInner]) && !fifoDropInner[responseOwnerInner]) && lqValidInner[responseResultIndexInner]) && (lqTagInner[responseResultIndexInner] == fifoTagInner[responseOwnerInner])) && lqSentInner[responseResultIndexInner]) && !lqResultReadyInner[responseResultIndexInner]) && !lqBroadcastedInner[responseResultIndexInner]) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
			assign responseResultLiveInner = responseResultIdentityLiveInner && !responseForwardPriorityInner;
			always @* begin : response_forward_priority
				reg [STORE_DATA_LANES - 1:0] notifications;
				notifications = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_25
`else
				begin : sv2v_autoblock_24
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < STORE_DATA_LANES; lane = lane + 1)
						notifications[lane] = storeDataEventInner[lane] && oldNotifyMatchInner[responseResultIndexInner][storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]];
				end
				responseForwardPriorityInner = |notifications;
				if (loadAddressEventInner && (addressIndexInput == sv2v_cast_EE378(responseResultIndexInner)))
					responseForwardPriorityInner = addressedForwardValidInner;
			end
			assign chooseResponseResultInner = responseResultLiveInner && ((!bufferedResultWinnerInner[1 + (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))] || rv32_pkg_rob_is_older(lqTagInner[responseResultIndexInner], bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)])) || ((lqTagInner[responseResultIndexInner] == bufferedResultWinnerInner[rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)-:((LQ_INDEX_W + 4) >= (LQ_INDEX_W + 0) ? ((rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1)) - (LQ_INDEX_W + 0)) + 1 : ((LQ_INDEX_W + 0) - (rv32_pkg_ROB_TAG_W + (LQ_INDEX_W - 1))) + 1)]) && (responseResultIndexInner < bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W])));
			wire [LQ_INDEX_W:1] sv2v_tmp_CAC23;
			assign sv2v_tmp_CAC23 = responseResultIndexInner;
			always @(*) previewResultIndexInner = sv2v_tmp_CAC23;
			wire [rv32_pkg_ROB_TAG_W:1] sv2v_tmp_D1946;
			assign sv2v_tmp_D1946 = lqTagInner[responseResultIndexInner];
			always @(*) previewResultTagInner = sv2v_tmp_D1946;
			wire [rv32_pkg_PHY_TAG_W:1] sv2v_tmp_A0385;
			assign sv2v_tmp_A0385 = lqDestInner[responseResultIndexInner];
			always @(*) previewResultDestinationInner = sv2v_tmp_A0385;
			wire [2:1] sv2v_tmp_17954;
			assign sv2v_tmp_17954 = lqSizeInner[responseResultIndexInner];
			always @(*) previewResultSizeInner = sv2v_tmp_17954;
			wire [1:1] sv2v_tmp_B230C;
			assign sv2v_tmp_B230C = lqUnsignedInner[responseResultIndexInner];
			always @(*) previewResultUnsignedInner = sv2v_tmp_B230C;
			wire [44:1] sv2v_tmp_A6D4B;
			assign sv2v_tmp_A6D4B = 1'sb0;
			always @(*) previewCdbPacketInner = sv2v_tmp_A6D4B;
		end
	endgenerate
	assign addressedForwardValidInner = query_store_forward_valid(addressInput[36-:5], addressInput[31-:32], lqSizeInner[loadAddressIndexInner]);
	always @* addressedForwardInner = query_store_forward(lqTagInner[loadAddressIndexInner], addressInput[31-:32], lqSizeInner[loadAddressIndexInner]);
	always @* begin : prepare_posted_store_mask
		postedStoreMaskInner = 1'sb0;
`ifndef SYNTHESIS
		begin : sv2v_autoblock_26
`else
		begin : sv2v_autoblock_25
`endif
			reg signed [31:0] s;
			for (s = 0; s < SQ_DEPTH; s = s + 1)
				postedStoreMaskInner[s] = sqValidInner[s] && sqCommittedInner[s];
		end
`ifndef SYNTHESIS
		begin : sv2v_autoblock_27
`else
		begin : sv2v_autoblock_26
`endif
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (storeRetireFireInner[lane])
					postedStoreMaskInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]] = 1'b1;
		end
	end
	genvar _gv_scanStore_1;
	generate
		for (_gv_scanStore_1 = 0; _gv_scanStore_1 < SQ_DEPTH; _gv_scanStore_1 = _gv_scanStore_1 + 1) begin : g_scan_store
			localparam scanStore = _gv_scanStore_1;
			assign postedStoreUnsafeInner[scanStore] = (!sqAddressReadyInner[scanStore] || !sqDataReadyInner[scanStore]) || !yield_ram_access(sqAddressInner[scanStore], sqSizeInner[scanStore]);
			assign incomingPostedBlockInner[scanStore] = postedStoreMaskInner[scanStore] && (postedStoreUnsafeInner[scanStore] || byte_overlap(addressInput[31-:32], lqSizeInner[loadAddressIndexInner], sqAddressInner[scanStore], sqSizeInner[scanStore]));
		end
	endgenerate
	genvar _gv_scanLoad_1;
	generate
		for (_gv_scanLoad_1 = 0; _gv_scanLoad_1 < LQ_DEPTH; _gv_scanLoad_1 = _gv_scanLoad_1 + 1) begin : g_old_request_scan
			localparam scanLoad = _gv_scanLoad_1;
			wire [SQ_DEPTH - 1:0] postedBlocks;
			assign oldRequestCacheBlockedInner[scanLoad] = query_request_cache_block(lqTagInner[scanLoad], lqAddressInner[scanLoad], lqSizeInner[scanLoad]);
			assign oldRequestYieldsInner[scanLoad] = yield_ram_access(lqAddressInner[scanLoad], lqSizeInner[scanLoad]);
			genvar _gv_scanStore_2;
			for (_gv_scanStore_2 = 0; _gv_scanStore_2 < SQ_DEPTH; _gv_scanStore_2 = _gv_scanStore_2 + 1) begin : g_store
				localparam scanStore = _gv_scanStore_2;
				assign postedBlocks[scanStore] = postedStoreMaskInner[scanStore] && (postedStoreUnsafeInner[scanStore] || byte_overlap(lqAddressInner[scanLoad], lqSizeInner[scanLoad], sqAddressInner[scanStore], sqSizeInner[scanStore]));
			end
			assign oldPostedStoreBlocksInner[scanLoad] = |postedBlocks;
		end
	endgenerate
	assign incomingRequestYieldsInner = yield_ram_access(addressInput[31-:32], lqSizeInner[loadAddressIndexInner]);
	assign selectedRequestYieldsInner = (loadRequestUsesAddressInner ? incomingRequestYieldsInner : oldRequestYieldsInner[loadSelectIndexInner]);
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin : moved_SQ_scan_oracle
			reg originalPostedBlock;
			originalPostedBlock = 1'b0;
			begin : sv2v_autoblock_28
				reg signed [31:0] s;
				for (s = 0; s < SQ_DEPTH; s = s + 1)
					if (postedStoreMaskInner[s] && (((!sqAddressReadyInner[s] || !sqDataReadyInner[s]) || !yield_ram_access(sqAddressInner[s], sqSizeInner[s])) || byte_overlap(loadSelectAddressInner, lqSizeInner[loadSelectIndexInner], sqAddressInner[s], sqSizeInner[s])))
						originalPostedBlock = 1'b1;
			end
			assert (loadBlockedInner == selectedForwardInner[36]) else $fatal(1, "SQ moved cache-block exact original post-mux oracle");
			assert (postedStoreBlocksLoadInner == originalPostedBlock) else $fatal(1, "SQ moved posted-Store exact original post-mux oracle");
			assert (selectedRequestYieldsInner == yield_ram_access(loadSelectAddressInner, lqSizeInner[loadSelectIndexInner])) else $fatal(1, "SQ moved yield exact original post-mux oracle");
		end
`endif
	always @* for (forwardIndexInner = 0; forwardIndexInner < LQ_DEPTH; forwardIndexInner = forwardIndexInner + 1)
`ifndef SYNTHESIS
		begin : sv2v_autoblock_29
`else
		begin : sv2v_autoblock_27
`endif
			reg [37:0] forwardResult;
			reg [3:0] needed;
			forwardResult = 1'sb0;
			needed = (lqSizeInner[forwardIndexInner] == 2'd0 ? 4'b0001 : (lqSizeInner[forwardIndexInner] == 2'd1 ? 4'b0011 : 4'b1111));
			lqEarlyForwardInner[forwardIndexInner] = 1'b0;
			lqEarlyValueInner[forwardIndexInner] = 1'sb0;
			if (((lqValidInner[forwardIndexInner] && !lqResultReadyInner[forwardIndexInner]) && !lqBroadcastedInner[forwardIndexInner]) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(lqTagInner[forwardIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))) begin
`ifndef SYNTHESIS
				if (lqAddressReadyInner[forwardIndexInner]) begin : sv2v_autoblock_30
`else
				if (lqAddressReadyInner[forwardIndexInner]) begin : sv2v_autoblock_28
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < STORE_DATA_LANES; lane = lane + 1)
						if ((storeDataEventInner[lane] && sqAddressReadyInner[storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]]) && notify_matches(storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)], sqAddressInner[storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]], lqTagInner[forwardIndexInner], lqAddressInner[forwardIndexInner], lqSizeInner[forwardIndexInner])) begin
							lqEarlyForwardInner[forwardIndexInner] = 1'b1;
							lqEarlyValueInner[forwardIndexInner] = storeDataInput[(lane * 38) + 31-:32];
						end
				end
				if (loadAddressEventInner && (addressIndexInput == sv2v_cast_EE378_signed(forwardIndexInner))) begin
					forwardResult = addressedForwardInner;
					lqEarlyForwardInner[forwardIndexInner] = !forwardResult[37] && ((forwardResult[35-:4] & needed) == needed);
					lqEarlyValueInner[forwardIndexInner] = forwardResult[31-:32];
				end
			end
		end
	wire [SQ_DEPTH - 1:0] completionAddressReadyInner;
	wire [SQ_DEPTH - 1:0] completionDataReadyInner;
	genvar _gv_row_28;
	wire [38:0] sqWbInner [0:SQ_DEPTH - 1];
	generate
		for (_gv_row_28 = 0; _gv_row_28 < SQ_DEPTH; _gv_row_28 = _gv_row_28 + 1) begin : g_completion_events
			localparam row = _gv_row_28;
			wire completionLive;
			wire [STORE_DATA_LANES - 1:0] dataEvents;
			assign completionLive = !coreStoppedInput && (!flushInfoInput[5] || rv32_pkg_rob_is_older(sqTagInner[row], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
			genvar _gv_lane_38;
			for (_gv_lane_38 = 0; _gv_lane_38 < STORE_DATA_LANES; _gv_lane_38 = _gv_lane_38 + 1) begin : g_lane
				localparam lane = _gv_lane_38;
				assign dataEvents[lane] = storeDataEventInner[lane] && (storeDataIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)] == sv2v_cast_41EA4_signed(row));
			end
			assign completionAddressReadyInner[row] = sqAddressReadyInner[row] || ((completionLive && storeAddressEventInner) && (addressIndexInput == sv2v_cast_EE378_signed(row)));
			assign completionDataReadyInner[row] = sqDataReadyInner[row] || (completionLive && (|dataEvents || ((sqDataTagInner[row] != {rv32_pkg_PHY_TAG_W {1'sb0}}) && sqWbInner[row][38])));
		end
	endgenerate
	function automatic signed [15:0] sv2v_cast_9432F_signed;
		input reg signed [15:0] inp;
		sv2v_cast_9432F_signed = inp;
	endfunction
	always @* begin : completion_bitmap
		reg signed [31:0] completionRow;
		storeCompleteOutput = 1'sb0;
		for (completionRow = 0; completionRow < SQ_DEPTH; completionRow = completionRow + 1)
			if (((sqValidInner[completionRow] && completionAddressReadyInner[completionRow]) && completionDataReadyInner[completionRow]) && !sqCommittedInner[completionRow]) begin
				storeCompleteOutput[31-:16] = storeCompleteOutput[31-:16] | (sv2v_cast_9432F_signed(1) << sqTagInner[completionRow][3:0]);
				if (sqTagInner[completionRow][4])
					storeCompleteOutput[15-:rv32_pkg_ROB_ENTRIES] = storeCompleteOutput[15-:rv32_pkg_ROB_ENTRIES] | (sv2v_cast_9432F_signed(1) << sqTagInner[completionRow][3:0]);
			end
	end
	wire [38:0] storeAllocWbInner;
	function automatic [38:0] matching_writeback;
		input reg [5:0] tag;
		begin
			matching_writeback = 1'sb0;
`ifndef SYNTHESIS
			begin : sv2v_autoblock_31
`else
			begin : sv2v_autoblock_29
`endif
				reg signed [31:0] portIndex;
				for (portIndex = WRITEBACK_PORTS - 1; portIndex >= 0; portIndex = portIndex - 1)
					if (writebackInput[(portIndex * 39) + 38] && (writebackInput[(portIndex * 39) + 37-:6] == tag))
						matching_writeback = writebackInput[0 + (portIndex * 39)+:39];
			end
		end
	endfunction
	assign storeAllocWbInner = matching_writeback(storeAllocationInput[37-:6]);
	genvar _gv_row_29;
	generate
		for (_gv_row_29 = 0; _gv_row_29 < SQ_DEPTH; _gv_row_29 = _gv_row_29 + 1) begin : g_sq_wakeup
			localparam row = _gv_row_29;
			assign sqWbInner[row] = matching_writeback(sqDataTagInner[row]);
		end
	endgenerate
	always @* begin
		storeAllocDataReadyResolvedInner = storeAllocationInput[38];
		storeAllocDataValueResolvedInner = storeAllocationInput[31-:32];
		if (!storeAllocDataReadyResolvedInner && (storeAllocationInput[37-:6] != {6 {1'sb0}})) begin
			if (storeAllocWbInner[38]) begin
				storeAllocDataReadyResolvedInner = 1'b1;
				storeAllocDataValueResolvedInner = storeAllocWbInner[31-:32];
			end
		end
	end
	function automatic signed [$clog2(LQ_DEPTH + 1) - 1:0] sv2v_cast_2E28E_signed;
		input reg signed [$clog2(LQ_DEPTH + 1) - 1:0] inp;
		sv2v_cast_2E28E_signed = inp;
	endfunction
	function automatic [$clog2(SQ_DEPTH + 1) - 1:0] sv2v_cast_D7121;
		input reg [$clog2(SQ_DEPTH + 1) - 1:0] inp;
		sv2v_cast_D7121 = inp;
	endfunction
	function automatic [SQ_INDEX_W - 1:0] sv2v_cast_41EA4;
		input reg [SQ_INDEX_W - 1:0] inp;
		sv2v_cast_41EA4 = inp;
	endfunction
	function automatic signed [((SQ_INDEX_W + 0) >= 0 ? SQ_INDEX_W + 1 : 1 - (SQ_INDEX_W + 0)) - 1:0] sv2v_cast_84930_signed;
		input reg signed [((SQ_INDEX_W + 0) >= 0 ? SQ_INDEX_W + 1 : 1 - (SQ_INDEX_W + 0)) - 1:0] inp;
		sv2v_cast_84930_signed = inp;
	endfunction
	generate
		if (RENAME_WIDTH == 4) begin : g_four_allocation
			always @* begin : preview_old_rows
				reg signed [31:0] rank;
				rank = 0;
				loadPreviewIndexOutput = 1'sb0;
				storePreviewIndexOutput = 1'sb0;
				loadCreditsOutput = 1'sb0;
				storeCreditsOutput = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_32
`else
				begin : sv2v_autoblock_30
`endif
					reg signed [31:0] row;
					for (row = 0; row < LQ_DEPTH; row = row + 1)
						if (!lqValidInner[row]) begin
							if (rank < 4)
								loadPreviewIndexOutput[rank * $clog2(LQ_DEPTH)+:$clog2(LQ_DEPTH)] = sv2v_cast_2B0BB_signed(row);
							rank = rank + 1;
						end
				end
				if (!coreStoppedInput && !flushInfoInput[5]) begin
					loadCreditsOutput = sv2v_cast_2E28E_signed(rank);
					storeCreditsOutput = sv2v_cast_D7121(SQ_DEPTH) - sv2v_cast_D7121(sqUsedInner);
				end
`ifndef SYNTHESIS
				begin : sv2v_autoblock_33
`else
				begin : sv2v_autoblock_31
`endif
					reg signed [31:0] r;
					for (r = 0; r < 4; r = r + 1)
						storePreviewIndexOutput[r * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)] = sv2v_cast_41EA4(sqTailSeqInner) + sv2v_cast_41EA4_signed(r);
				end
			end
			always @* begin : consume_sparse_memory_ranks
				reg signed [31:0] loads;
				reg signed [31:0] stores;
				loads = 0;
				stores = 0;
				loadAllocationLanesFireOutput = 1'sb0;
				storeAllocationLanesFireOutput = 1'sb0;
				loadLanesIndexInner = 1'sb0;
				storeLanesIndexInner = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_34
`else
				begin : sv2v_autoblock_32
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						begin
							if (loadAllocationLanesInput[(lane * 15) + 14] && (loads < sv2v_cast_32_signed(loadCreditsOutput))) begin
								loadAllocationLanesFireOutput[lane] = 1;
								loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W] = loadPreviewIndexOutput[loads * $clog2(LQ_DEPTH)+:$clog2(LQ_DEPTH)];
								loads = loads + 1;
							end
							if (storeAllocationLanesInput[(lane * 47) + 46] && (stores < sv2v_cast_32_signed(storeCreditsOutput))) begin
								storeAllocationLanesFireOutput[lane] = 1;
								storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W] = storePreviewIndexOutput[stores * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)];
								stores = stores + 1;
							end
						end
				end
				storeAllocLanesCountInner = sv2v_cast_84930_signed(stores);
			end
			genvar _gv_lane_39;
			for (_gv_lane_39 = 0; _gv_lane_39 < 4; _gv_lane_39 = _gv_lane_39 + 1) begin : g_data
				localparam lane = _gv_lane_39;
				wire [38:0] wb;
				assign wb = matching_writeback(storeAllocationLanesInput[(lane * 47) + 37-:6]);
				assign storeLanesDataReadyInner[lane] = storeAllocationLanesInput[(lane * 47) + 38] || ((storeAllocationLanesInput[(lane * 47) + 37-:6] != 0) && wb[38]);
				assign storeLanesDataValueInner[lane * 32+:32] = ((!storeAllocationLanesInput[(lane * 47) + 38] && (storeAllocationLanesInput[(lane * 47) + 37-:6] != 0)) && wb[38] ? wb[31-:32] : storeAllocationLanesInput[(lane * 47) + 31-:32]);
			end
		end
		else begin : g_no_four_allocation
			wire [4:1] sv2v_tmp_37EFE;
			assign sv2v_tmp_37EFE = 1'sb0;
			always @(*) loadAllocationLanesFireOutput = sv2v_tmp_37EFE;
			wire [4:1] sv2v_tmp_3D3D4;
			assign sv2v_tmp_3D3D4 = 1'sb0;
			always @(*) storeAllocationLanesFireOutput = sv2v_tmp_3D3D4;
			wire [4 * $clog2(LQ_DEPTH):1] sv2v_tmp_5EECC;
			assign sv2v_tmp_5EECC = 1'sb0;
			always @(*) loadPreviewIndexOutput = sv2v_tmp_5EECC;
			wire [4 * $clog2(SQ_DEPTH):1] sv2v_tmp_12494;
			assign sv2v_tmp_12494 = 1'sb0;
			always @(*) storePreviewIndexOutput = sv2v_tmp_12494;
			wire [$clog2(LQ_DEPTH + 1):1] sv2v_tmp_757D1;
			assign sv2v_tmp_757D1 = 1'sb0;
			always @(*) loadCreditsOutput = sv2v_tmp_757D1;
			wire [$clog2(SQ_DEPTH + 1):1] sv2v_tmp_EE17B;
			assign sv2v_tmp_EE17B = 1'sb0;
			always @(*) storeCreditsOutput = sv2v_tmp_EE17B;
			wire [4 * LQ_INDEX_W:1] sv2v_tmp_DF147;
			assign sv2v_tmp_DF147 = 1'sb0;
			always @(*) loadLanesIndexInner = sv2v_tmp_DF147;
			wire [4 * SQ_INDEX_W:1] sv2v_tmp_8BDE9;
			assign sv2v_tmp_8BDE9 = 1'sb0;
			always @(*) storeLanesIndexInner = sv2v_tmp_8BDE9;
			wire [(SQ_INDEX_W >= 0 ? SQ_INDEX_W + 1 : 1 - SQ_INDEX_W):1] sv2v_tmp_205B4;
			assign sv2v_tmp_205B4 = 1'sb0;
			always @(*) storeAllocLanesCountInner = sv2v_tmp_205B4;
			assign storeLanesDataReadyInner = 1'sb0;
			assign storeLanesDataValueInner = 1'sb0;
		end
		if (RENAME_WIDTH == 2) begin : g_second_allocation
			wire [38:0] dataWb;
			assign dataWb = matching_writeback(storeAllocationSecondInput[37-:6]);
`ifndef SYNTHESIS
			always @* begin : sv2v_autoblock_35
`else
			always @* begin : sv2v_autoblock_33
`endif
				reg found;
				found = 1'b0;
				loadAllocSecondIndexOutput = 1'sb0;
`ifndef SYNTHESIS
				begin : sv2v_autoblock_36
`else
				begin : sv2v_autoblock_34
`endif
					reg signed [31:0] row;
					for (row = 0; row < LQ_DEPTH; row = row + 1)
						if ((!found && !lqValidInner[row]) && (!loadAllocFireInner || (sv2v_cast_2B0BB_signed(row) != loadAllocIndexOutput))) begin
							found = 1'b1;
							loadAllocSecondIndexOutput = sv2v_cast_2B0BB_signed(row);
						end
				end
				loadAllocSecondReadyOutput = found && !flushInfoInput[5];
			end
			assign storeAllocSecondReadyOutput = !flushInfoInput[5] && ((sv2v_cast_32_signed(sqUsedInner) + sv2v_cast_32_signed(storeAllocFireInner)) < SQ_DEPTH);
			assign storeAllocSecondIndexOutput = sv2v_cast_41EA4(sqTailSeqInner) + sv2v_cast_41EA4(storeAllocFireInner);
			assign storeAllocSecondDataReadyInner = storeAllocationSecondInput[38] || ((storeAllocationSecondInput[37-:6] != {6 {1'sb0}}) && dataWb[38]);
			assign storeAllocSecondDataValueInner = ((!storeAllocationSecondInput[38] && (storeAllocationSecondInput[37-:6] != {6 {1'sb0}})) && dataWb[38] ? dataWb[31-:32] : storeAllocationSecondInput[31-:32]);
		end
		else begin : g_no_second_allocation
			wire [1:1] sv2v_tmp_54592;
			assign sv2v_tmp_54592 = 1'b0;
			always @(*) loadAllocSecondReadyOutput = sv2v_tmp_54592;
			wire [$clog2(LQ_DEPTH):1] sv2v_tmp_4D8B7;
			assign sv2v_tmp_4D8B7 = 1'sb0;
			always @(*) loadAllocSecondIndexOutput = sv2v_tmp_4D8B7;
			assign storeAllocSecondReadyOutput = 1'b0;
			assign storeAllocSecondIndexOutput = 1'sb0;
			assign storeAllocSecondDataReadyInner = 1'b0;
			assign storeAllocSecondDataValueInner = 1'sb0;
		end
		if (RESPONSE_PREVIEW && TAGGED_DMEM) begin : g_preview_cdb_output
			wire [44:1] sv2v_tmp_D1759;
			assign sv2v_tmp_D1759 = previewCdbPacketInner;
			always @(*) loadResultOutput = sv2v_tmp_D1759;
`ifndef SYNTHESIS
			always @* begin : packet_reference_assertion
				reg [43:0] originalPacket;
				originalPacket[43] = resultSelectFoundInner && (!flushInfoInput[5] || rv32_pkg_rob_is_older(resultSelectTagInner, flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
				originalPacket[42-:5] = resultSelectTagInner;
				originalPacket[37-:6] = (chooseResponseResultInner ? previewResultDestinationInner : lqDestInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]);
				originalPacket[31-:32] = (chooseResponseResultInner ? extend_load((lqEarlyForwardInner[responseResultIndexInner] ? lqEarlyValueInner[responseResultIndexInner] : dmemResponseInput[31-:32]), previewResultSizeInner, previewResultUnsignedInner) : extend_load(lqResultInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqSizeInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqUnsignedInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]));
				assert (loadResultOutput == originalPacket) else $fatal(1, "Response payload cofactor oracle");
			end
`endif
		end
		else begin : g_original_cdb_output
			always @* begin : result_output
				loadResultOutput[43] = resultSelectFoundInner && (!flushInfoInput[5] || rv32_pkg_rob_is_older(resultSelectTagInner, flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
				loadResultOutput[42-:5] = resultSelectTagInner;
				loadResultOutput[37-:6] = (chooseResponseResultInner ? previewResultDestinationInner : lqDestInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]);
				loadResultOutput[31-:32] = (chooseResponseResultInner ? extend_load(dmemResponseInput[31-:32], previewResultSizeInner, previewResultUnsignedInner) : extend_load(lqResultInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqSizeInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]], lqUnsignedInner[bufferedResultWinnerInner[LQ_INDEX_W - 1-:LQ_INDEX_W]]));
			end
		end
	endgenerate
	always @* begin
		loadAllocFoundInner = 1'b0;
		loadAllocIndexOutput = 1'sb0;
		for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1)
			if (!loadAllocFoundInner && !lqValidInner[combIndexInner]) begin
				loadAllocFoundInner = 1'b1;
				loadAllocIndexOutput = combIndexInner[LQ_INDEX_W - 1:0];
			end
		loadAllocReadyOutput = loadAllocFoundInner && !flushInfoInput[5];
		storeAllocFoundInner = sqTailSeqInner != (sqHeadSeqInner ^ sv2v_cast_84930(SQ_DEPTH));
		storeAllocIndexOutput = sqTailSeqInner[SQ_INDEX_W - 1:0];
		storeAllocReadyOutput = storeAllocFoundInner && !flushInfoInput[5];
		selectedForwardInner = 1'sb0;
		if (loadSelectFoundInner)
			selectedForwardInner = query_store_forward(loadSelectTagInner, loadSelectAddressInner, lqSizeInner[loadSelectIndexInner]);
		loadBlockedInner = loadSelectFoundInner && (loadRequestUsesAddressInner ? addressedForwardInner[36] : oldRequestCacheBlockedInner[loadSelectIndexInner]);
		selectedLoadLiveInner = loadSelectFoundInner && (!flushInfoInput[5] || rv32_pkg_rob_is_older(loadSelectTagInner, flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
		loadNeedsMemoryInner = ((!coreStoppedInput && selectedLoadLiveInner) && !loadBlockedInner) && (sv2v_cast_32_signed(fifoCountInner) < rv32_pkg_DATA_REQUEST_ENTRIES);
		storeAvailableInner = sqValidInner[sqHeadIndexInner] && sqCommittedInner[sqHeadIndexInner];
`ifndef SYNTHESIS
		begin : sv2v_autoblock_37
`else
		begin : sv2v_autoblock_35
`endif
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if ((sqValidInner[sqHeadIndexInner] && storeRetireFireInner[lane]) && (storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)] == sqHeadIndexInner))
					storeAvailableInner = 1'b1;
		end
		postedStoreBlocksLoadInner = (loadRequestUsesAddressInner ? |incomingPostedBlockInner : oldPostedStoreBlocksInner[loadSelectIndexInner]);
		loadBypassStoreInner = (((((((loadYieldEnableInput && !coreStoppedInput) && !flushInfoInput[5]) && storeAvailableInner) && !storeYieldDebtInner) && loadNeedsMemoryInner) && selectedRequestYieldsInner) && !postedStoreBlocksLoadInner) && pressureLowInner;
		storeSendSelectedInner = storeAvailableInner && !loadBypassStoreInner;
		dmemRequestOutput[71] = 1'b0;
		dmemRequestOutput[70] = 1'b0;
		dmemRequestOutput[69-:32] = (storeSendSelectedInner ? sqAddressInner[sqHeadIndexInner] : loadSelectAddressInner);
		dmemRequestOutput[37-:32] = 32'b00000000000000000000000000000000;
		dmemRequestOutput[5-:4] = 4'b0000;
		dmemRequestOutput[1-:2] = (storeSendSelectedInner ? sqSizeInner[sqHeadIndexInner] : lqSizeInner[loadSelectIndexInner]);
		loadRequestSelectedInner = 1'b0;
		if (storeSendSelectedInner) begin
			dmemRequestOutput[71] = 1'b1;
			dmemRequestOutput[70] = 1'b1;
			dmemRequestOutput[37-:32] = sqDataInner[sqHeadIndexInner];
			(* full_case, parallel_case *)
			case (sqSizeInner[sqHeadIndexInner])
				2'd0: dmemRequestOutput[5-:4] = 4'b0001;
				2'd1: dmemRequestOutput[5-:4] = 4'b0011;
				default: dmemRequestOutput[5-:4] = 4'b1111;
			endcase
		end
		else if (loadNeedsMemoryInner) begin
			dmemRequestOutput[71] = 1'b1;
			dmemRequestOutput[70] = 1'b0;
			loadRequestSelectedInner = 1'b1;
		end
		lqCountOutput = 1'sb0;
		for (combIndexInner = 0; combIndexInner < LQ_DEPTH; combIndexInner = combIndexInner + 1)
			if (lqValidInner[combIndexInner])
				lqCountOutput = lqCountOutput + 1'b1;
		sqCountOutput = 1'sb0;
		sqRetainedCountInner = 1'sb0;
		for (combIndexInner = 0; combIndexInner < SQ_DEPTH; combIndexInner = combIndexInner + 1)
			begin
				if (sqValidInner[combIndexInner])
					sqCountOutput = sqCountOutput + 1'b1;
				if (sqValidInner[combIndexInner] && (sqCommittedInner[combIndexInner] || !rv32_pkg_rob_is_younger(sqTagInner[combIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W])))
					sqRetainedCountInner = sqRetainedCountInner + 1'b1;
			end
	end
	genvar _gv_summaryRow_1;
	generate
		for (_gv_summaryRow_1 = 0; _gv_summaryRow_1 < LQ_DEPTH; _gv_summaryRow_1 = _gv_summaryRow_1 + 1) begin : g_scheduler_summary
			localparam summaryRow = _gv_summaryRow_1;
			always @* begin : next_tag
				summaryTagNextInner[summaryRow * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = lqTagInner[summaryRow];
				if (!coreStoppedInput && !flushInfoInput[5]) begin
					if ((((RENAME_WIDTH != 4) && loadAllocationInput[14]) && loadAllocReadyOutput) && (loadAllocIndexOutput == sv2v_cast_2B0BB_signed(summaryRow)))
						summaryTagNextInner[summaryRow * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = loadAllocationInput[13-:5];
					if (loadAllocSecondFireInner && (loadAllocSecondIndexOutput == sv2v_cast_2B0BB_signed(summaryRow)))
						summaryTagNextInner[summaryRow * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = loadAllocationSecondInput[13-:5];
`ifndef SYNTHESIS
					if (RENAME_WIDTH == 4) begin : sv2v_autoblock_38
`else
					if (RENAME_WIDTH == 4) begin : sv2v_autoblock_36
`endif
						reg signed [31:0] lane;
						for (lane = 0; lane < 4; lane = lane + 1)
							if (loadAllocationLanesFireOutput[lane] && (loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W] == sv2v_cast_2B0BB_signed(summaryRow)))
								summaryTagNextInner[summaryRow * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W] = loadAllocationLanesInput[(lane * 15) + 13-:5];
					end
				end
			end
			always @* begin : next_flags
				reg v;
				reg a;
				reg s;
				reg r;
				reg allocated;
				reg doPop;
				reg doPush;
				v = lqValidInner[summaryRow];
				a = lqAddressReadyInner[summaryRow];
				s = lqSentInner[summaryRow];
				r = lqResultReadyInner[summaryRow];
				allocated = 1'b0;
				doPop = dmemResponseInput[32] && fifoValidInner[responseOwnerInner];
				doPush = ((dmemRequestOutput[71] && dmemReqReadyInput) && loadRequestSelectedInner) && ((sv2v_cast_32_signed(fifoCountInner) < rv32_pkg_DATA_REQUEST_ENTRIES) || doPop);
				if (!coreStoppedInput) begin
					if (flushInfoInput[5]) begin
						if (lqValidInner[summaryRow] && rv32_pkg_rob_is_younger(lqTagInner[summaryRow], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))
							v = 1'b0;
					end
					else begin
						allocated = ((((RENAME_WIDTH != 4) && loadAllocationInput[14]) && loadAllocReadyOutput) && (loadAllocIndexOutput == sv2v_cast_2B0BB_signed(summaryRow))) || (loadAllocSecondFireInner && (loadAllocSecondIndexOutput == sv2v_cast_2B0BB_signed(summaryRow)));
`ifndef SYNTHESIS
						if (RENAME_WIDTH == 4) begin : sv2v_autoblock_39
`else
						if (RENAME_WIDTH == 4) begin : sv2v_autoblock_37
`endif
							reg signed [31:0] lane;
							for (lane = 0; lane < 4; lane = lane + 1)
								allocated = allocated | (loadAllocationLanesFireOutput[lane] && (loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W] == sv2v_cast_2B0BB_signed(summaryRow)));
						end
						if (allocated) begin
							v = 1'b1;
							a = 1'b0;
							s = 1'b0;
							r = 1'b0;
						end
					end
`ifndef SYNTHESIS
					begin : sv2v_autoblock_40
`else
					begin : sv2v_autoblock_38
`endif
						reg signed [31:0] lane;
						for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
							if ((robRetireInput[(lane * 6) + 5] && lqValidInner[summaryRow]) && (lqTagInner[summaryRow] == robRetireInput[(lane * 6) + 4-:rv32_pkg_ROB_TAG_W]))
								v = 1'b0;
					end
					if ((((addressInput[38] && !addressInput[37]) && loadAddressMatchInner) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(addressInput[36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))) && (addressIndexInput == sv2v_cast_EE378_signed(summaryRow)))
						a = 1'b1;
					if (((((((doPop && !fifoDropInner[responseOwnerInner]) && !(flushInfoInput[5] && !rv32_pkg_rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))) && (fifoIndexInner[responseOwnerInner] == sv2v_cast_2B0BB_signed(summaryRow))) && lqValidInner[summaryRow]) && (lqTagInner[summaryRow] == fifoTagInner[responseOwnerInner])) && lqSentInner[summaryRow]) && !lqResultReadyInner[summaryRow])
						r = 1'b1;
					if (doPush && (loadSelectIndexInner == sv2v_cast_2B0BB_signed(summaryRow)))
						s = 1'b1;
					if (lqEarlyForwardInner[summaryRow] && !(((dmemRequestOutput[71] && dmemReqReadyInput) && loadRequestSelectedInner) && (loadSelectIndexInner == sv2v_cast_2B0BB_signed(summaryRow)))) begin
						r = 1'b1;
						s = 1'b1;
					end
				end
				loadRequestBaseNextInner[summaryRow] = ((v && a) && !s) && !r;
				loadInsertableNextInner[summaryRow] = (v && !s) && !r;
				loadPendingAddressNextInner[summaryRow] = v && !a;
			end
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			loadRequestBaseInner <= 1'sb0;
			loadInsertableInner <= 1'sb0;
			loadPendingAddressInner <= 1'sb0;
		end
		else if (!coreStoppedInput) begin
			loadRequestBaseInner <= loadRequestBaseNextInner;
			loadInsertableInner <= loadInsertableNextInner;
			loadPendingAddressInner <= loadPendingAddressNextInner;
		end
	genvar _gv_summaryRight_1;
	generate
		for (_gv_summaryRight_1 = 1; _gv_summaryRight_1 < LQ_DEPTH; _gv_summaryRight_1 = _gv_summaryRight_1 + 1) begin : g_summary_age_right
			localparam summaryRight = _gv_summaryRight_1;
			genvar _gv_summaryLeft_1;
			for (_gv_summaryLeft_1 = 0; _gv_summaryLeft_1 < summaryRight; _gv_summaryLeft_1 = _gv_summaryLeft_1 + 1) begin : g_left
				localparam summaryLeft = _gv_summaryLeft_1;
				reg pairOlderInner;
				assign loadPairOlderCachedInner[(summaryRight * LQ_DEPTH) + summaryLeft] = pairOlderInner;
				always_ff @(posedge clkInput or negedge rstNInput)
					if (!rstNInput)
						pairOlderInner <= 1'b0;
					else if (!coreStoppedInput)
						pairOlderInner <= rv32_pkg_rob_is_older(summaryTagNextInner[summaryRight * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W], summaryTagNextInner[summaryLeft * rv32_pkg_ROB_TAG_W+:rv32_pkg_ROB_TAG_W]);
			end
		end
	endgenerate
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin : summary_original_state_oracle
			begin : sv2v_autoblock_41
				reg signed [31:0] row;
				for (row = 0; row < LQ_DEPTH; row = row + 1)
					begin
						assert (loadRequestBaseInner[row] == (((lqValidInner[row] && lqAddressReadyInner[row]) && !lqSentInner[row]) && !lqResultReadyInner[row])) else $fatal(1, "LQ summary base does not describe current original state");
						assert (loadInsertableInner[row] == ((lqValidInner[row] && !lqSentInner[row]) && !lqResultReadyInner[row])) else $fatal(1, "LQ summary insertion does not describe current original state");
						assert (loadPendingAddressInner[row] == (lqValidInner[row] && !lqAddressReadyInner[row])) else $fatal(1, "LQ summary pending-address does not describe current original state");
						begin : sv2v_autoblock_42
							reg signed [31:0] left;
							for (left = 0; left < row; left = left + 1)
								assert (loadPairOlderCachedInner[(row * LQ_DEPTH) + left] == rv32_pkg_rob_is_older(lqTagInner[row], lqTagInner[left])) else $fatal(1, "LQ summary pair age does not describe current original tags");
						end
					end
			end
		end
`endif
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			storeYieldDebtInner <= 1'b0;
		else if ((storeSendSelectedInner && dmemRequestOutput[71]) && dmemReqReadyInput)
			storeYieldDebtInner <= 1'b0;
		else if ((((loadBypassStoreInner && loadRequestSelectedInner) && dmemRequestOutput[71]) && !dmemRequestOutput[70]) && dmemReqReadyInput)
			storeYieldDebtInner <= 1'b1;
	localparam [31:0] rv32_pkg_AXI_EXIT_ADDR = 32'h80000000;
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			fifoHeadInner <= 1'sb0;
			fifoTailInner <= 1'sb0;
			fifoCountInner <= 1'sb0;
			for (seqIndexInner = 0; seqIndexInner < rv32_pkg_DATA_REQUEST_ENTRIES; seqIndexInner = seqIndexInner + 1)
				begin
					fifoValidInner[seqIndexInner] <= 1'b0;
					fifoIndexInner[seqIndexInner] <= 1'sb0;
					fifoTagInner[seqIndexInner] <= 1'sb0;
					fifoDropInner[seqIndexInner] <= 1'b0;
				end
			sqHeadSeqInner <= 1'sb0;
			sqTailSeqInner <= 1'sb0;
			for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
				begin
					lqValidInner[seqIndexInner] <= 1'b0;
					lqTagInner[seqIndexInner] <= 1'sb0;
					lqDestInner[seqIndexInner] <= 1'sb0;
					lqSizeInner[seqIndexInner] <= 2'd2;
					lqUnsignedInner[seqIndexInner] <= 1'b0;
					lqAddressReadyInner[seqIndexInner] <= 1'b0;
					lqSentInner[seqIndexInner] <= 1'b0;
					lqResultReadyInner[seqIndexInner] <= 1'b0;
					lqBroadcastedInner[seqIndexInner] <= 1'b0;
				end
			for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1)
				begin
					sqValidInner[seqIndexInner] <= 1'b0;
					sqTagInner[seqIndexInner] <= 1'sb0;
					sqSizeInner[seqIndexInner] <= 2'd2;
					sqAddressReadyInner[seqIndexInner] <= 1'b0;
					sqAddressInner[seqIndexInner] <= 1'sb0;
					sqDataReadyInner[seqIndexInner] <= 1'b0;
					sqDataTagInner[seqIndexInner] <= 1'sb0;
					sqDataInner[seqIndexInner] <= 1'sb0;
					sqCommittedInner[seqIndexInner] <= 1'b0;
					sqIsExitInner[seqIndexInner] <= 1'b0;
				end
		end
		else if (coreStoppedInput) begin
			if (storeSendSelectedInner && dmemReqReadyInput) begin
				sqValidInner[sqHeadIndexInner] <= 1'b0;
				sqHeadSeqInner <= sqHeadSeqInner + 1'b1;
			end
		end
		else begin
			for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1)
				if ((sqValidInner[seqIndexInner] && !sqDataReadyInner[seqIndexInner]) && (sqDataTagInner[seqIndexInner] != {rv32_pkg_PHY_TAG_W {1'sb0}})) begin
					if (sqWbInner[seqIndexInner][38]) begin
						sqDataReadyInner[seqIndexInner] <= 1'b1;
						sqDataInner[seqIndexInner] <= sqWbInner[seqIndexInner][31-:32];
					end
				end
			for (storeLaneInner = 0; storeLaneInner < STORE_DATA_LANES; storeLaneInner = storeLaneInner + 1)
				if (storeDataEventInner[storeLaneInner]) begin
					sqDataInner[storeDataIndexInput[storeLaneInner * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]] <= storeDataInput[(storeLaneInner * 38) + 31-:32];
					sqDataReadyInner[storeDataIndexInput[storeLaneInner * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]] <= 1'b1;
				end
			if (flushInfoInput[5]) begin
				sqTailSeqInner <= sqHeadSeqInner + sqRetainedCountInner;
				for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
					if (lqValidInner[seqIndexInner] && rv32_pkg_rob_is_younger(lqTagInner[seqIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))
						lqValidInner[seqIndexInner] <= 1'b0;
				for (seqIndexInner = 0; seqIndexInner < SQ_DEPTH; seqIndexInner = seqIndexInner + 1)
					if ((sqValidInner[seqIndexInner] && !sqCommittedInner[seqIndexInner]) && rv32_pkg_rob_is_younger(sqTagInner[seqIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))
						sqValidInner[seqIndexInner] <= 1'b0;
				for (seqIndexInner = 0; seqIndexInner < rv32_pkg_DATA_REQUEST_ENTRIES; seqIndexInner = seqIndexInner + 1)
					if (fifoValidInner[seqIndexInner] && !rv32_pkg_rob_is_older(fifoTagInner[seqIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))
						fifoDropInner[seqIndexInner] <= 1'b1;
				if (loadResultOutput[43] && loadResultReadyInput)
					lqBroadcastedInner[resultSelectIndexInner] <= 1'b1;
			end
			else begin
				if (((RENAME_WIDTH != 4) && loadAllocationInput[14]) && loadAllocReadyOutput) begin
					lqValidInner[loadAllocIndexOutput] <= 1'b1;
					lqTagInner[loadAllocIndexOutput] <= loadAllocationInput[13-:5];
					lqDestInner[loadAllocIndexOutput] <= loadAllocationInput[8-:6];
					lqSizeInner[loadAllocIndexOutput] <= loadAllocationInput[2-:2];
					lqUnsignedInner[loadAllocIndexOutput] <= loadAllocationInput[0];
					lqAddressReadyInner[loadAllocIndexOutput] <= 1'b0;
					lqSentInner[loadAllocIndexOutput] <= 1'b0;
					lqResultReadyInner[loadAllocIndexOutput] <= 1'b0;
					lqBroadcastedInner[loadAllocIndexOutput] <= 1'b0;
				end
				if (loadAllocSecondFireInner) begin
					lqValidInner[loadAllocSecondIndexOutput] <= 1'b1;
					lqTagInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput[13-:5];
					lqDestInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput[8-:6];
					lqSizeInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput[2-:2];
					lqUnsignedInner[loadAllocSecondIndexOutput] <= loadAllocationSecondInput[0];
					lqAddressReadyInner[loadAllocSecondIndexOutput] <= 1'b0;
					lqSentInner[loadAllocSecondIndexOutput] <= 1'b0;
					lqResultReadyInner[loadAllocSecondIndexOutput] <= 1'b0;
					lqBroadcastedInner[loadAllocSecondIndexOutput] <= 1'b0;
				end
				if (storeAllocCountInner != 0)
					sqTailSeqInner <= sqTailSeqInner + storeAllocCountInner;
				if (((RENAME_WIDTH != 4) && storeAllocationInput[46]) && storeAllocReadyOutput) begin
					sqValidInner[storeAllocIndexOutput] <= 1'b1;
					sqTagInner[storeAllocIndexOutput] <= storeAllocationInput[45-:5];
					sqSizeInner[storeAllocIndexOutput] <= storeAllocationInput[40-:2];
					sqAddressReadyInner[storeAllocIndexOutput] <= 1'b0;
					sqDataReadyInner[storeAllocIndexOutput] <= storeAllocDataReadyResolvedInner;
					sqDataTagInner[storeAllocIndexOutput] <= storeAllocationInput[37-:6];
					sqDataInner[storeAllocIndexOutput] <= storeAllocDataValueResolvedInner;
					sqCommittedInner[storeAllocIndexOutput] <= 1'b0;
				end
				if (storeAllocSecondFireInner) begin
					sqValidInner[storeAllocSecondIndexOutput] <= 1'b1;
					sqTagInner[storeAllocSecondIndexOutput] <= storeAllocationSecondInput[45-:5];
					sqSizeInner[storeAllocSecondIndexOutput] <= storeAllocationSecondInput[40-:2];
					sqAddressReadyInner[storeAllocSecondIndexOutput] <= 1'b0;
					sqDataReadyInner[storeAllocSecondIndexOutput] <= storeAllocSecondDataReadyInner;
					sqDataTagInner[storeAllocSecondIndexOutput] <= storeAllocationSecondInput[37-:6];
					sqDataInner[storeAllocSecondIndexOutput] <= storeAllocSecondDataValueInner;
					sqCommittedInner[storeAllocSecondIndexOutput] <= 1'b0;
				end
`ifndef SYNTHESIS
				if (RENAME_WIDTH == 4) begin : sv2v_autoblock_43
`else
				if (RENAME_WIDTH == 4) begin : sv2v_autoblock_39
`endif
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						begin
							if (loadAllocationLanesFireOutput[lane]) begin
								lqValidInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= 1;
								lqTagInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= loadAllocationLanesInput[(lane * 15) + 13-:5];
								lqDestInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= loadAllocationLanesInput[(lane * 15) + 8-:6];
								lqSizeInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= loadAllocationLanesInput[(lane * 15) + 2-:2];
								lqUnsignedInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= loadAllocationLanesInput[(lane * 15) + 0];
								lqAddressReadyInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= 0;
								lqSentInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= 0;
								lqResultReadyInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= 0;
								lqBroadcastedInner[loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W]] <= 0;
							end
							if (storeAllocationLanesFireOutput[lane]) begin
								sqValidInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= 1;
								sqTagInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= storeAllocationLanesInput[(lane * 47) + 45-:5];
								sqSizeInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= storeAllocationLanesInput[(lane * 47) + 40-:2];
								sqAddressReadyInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= 0;
								sqDataReadyInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= storeLanesDataReadyInner[lane];
								sqDataTagInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= storeAllocationLanesInput[(lane * 47) + 37-:6];
								sqDataInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= storeLanesDataValueInner[lane * 32+:32];
								sqCommittedInner[storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W]] <= 0;
							end
						end
				end
				if (loadResultOutput[43] && loadResultReadyInput)
					lqBroadcastedInner[resultSelectIndexInner] <= 1'b1;
			end
`ifndef SYNTHESIS
			begin : sv2v_autoblock_44
`else
			begin : sv2v_autoblock_40
`endif
				reg signed [31:0] lane;
				for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
					if (storeRetireFireInner[lane])
						sqCommittedInner[storeCommitIndexInput[lane * $clog2(SQ_DEPTH)+:$clog2(SQ_DEPTH)]] <= 1'b1;
			end
			if (storeSendSelectedInner && dmemReqReadyInput) begin
				sqValidInner[sqHeadIndexInner] <= 1'b0;
				sqHeadSeqInner <= sqHeadSeqInner + 1'b1;
			end
`ifndef SYNTHESIS
			begin : sv2v_autoblock_45
`else
			begin : sv2v_autoblock_41
`endif
				reg signed [31:0] lane;
				for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
					if (robRetireInput[(lane * 6) + 5]) begin
						for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
							if (lqValidInner[seqIndexInner] && (lqTagInner[seqIndexInner] == robRetireInput[(lane * 6) + 4-:rv32_pkg_ROB_TAG_W]))
								lqValidInner[seqIndexInner] <= 1'b0;
					end
			end
			if ((addressInput[38] && (addressInput[37] ? storeAddressMatchInner : loadAddressMatchInner)) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(addressInput[36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))) begin
				if (addressInput[37]) begin
					sqAddressInner[addressIndexInput] <= addressInput[31-:32];
					sqAddressReadyInner[addressIndexInput] <= 1'b1;
					sqIsExitInner[addressIndexInput] <= addressInput[31-:32] == rv32_pkg_AXI_EXIT_ADDR;
				end
				else
					lqAddressReadyInner[loadAddressIndexInner] <= 1'b1;
			end
`ifndef SYNTHESIS
			begin : sv2v_autoblock_46
`else
			begin : sv2v_autoblock_42
`endif
				reg doPop;
				reg doPush;
				doPop = dmemResponseInput[32] && fifoValidInner[responseOwnerInner];
				doPush = ((dmemRequestOutput[71] && dmemReqReadyInput) && loadRequestSelectedInner) && ((sv2v_cast_32_signed(fifoCountInner) < rv32_pkg_DATA_REQUEST_ENTRIES) || doPop);
				if (doPop) begin
					if (((((!fifoDropInner[responseOwnerInner] && !(flushInfoInput[5] && !rv32_pkg_rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))) && lqValidInner[fifoIndexInner[responseOwnerInner]]) && (lqTagInner[fifoIndexInner[responseOwnerInner]] == fifoTagInner[responseOwnerInner])) && lqSentInner[fifoIndexInner[responseOwnerInner]]) && !lqResultReadyInner[fifoIndexInner[responseOwnerInner]])
						lqResultReadyInner[fifoIndexInner[responseOwnerInner]] <= 1'b1;
					fifoValidInner[responseOwnerInner] <= 1'b0;
					if (!TAGGED_DMEM)
						fifoHeadInner <= fifoHeadInner + sv2v_cast_70E94(1);
				end
				if (doPush) begin
					fifoIndexInner[allocationOwnerInner] <= loadSelectIndexInner;
					fifoTagInner[allocationOwnerInner] <= lqTagInner[loadSelectIndexInner];
					fifoDropInner[allocationOwnerInner] <= 1'b0;
					fifoValidInner[allocationOwnerInner] <= 1'b1;
					fifoTailInner <= allocationOwnerInner + sv2v_cast_70E94(1);
					lqSentInner[loadSelectIndexInner] <= 1'b1;
				end
				if (doPop && !doPush)
					fifoCountInner <= fifoCountInner - 1'b1;
				else if (doPush && !doPop)
					fifoCountInner <= fifoCountInner + 1'b1;
			end
			for (seqIndexInner = 0; seqIndexInner < LQ_DEPTH; seqIndexInner = seqIndexInner + 1)
				if (lqEarlyForwardInner[seqIndexInner] && !(((dmemRequestOutput[71] && dmemReqReadyInput) && loadRequestSelectedInner) && (loadSelectIndexInner == sv2v_cast_2B0BB_signed(seqIndexInner)))) begin
					lqResultReadyInner[seqIndexInner] <= 1'b1;
					lqSentInner[seqIndexInner] <= 1'b1;
					lqBroadcastedInner[seqIndexInner] <= ((directStorePacketInner && loadResultOutput[43]) && loadResultReadyInput) && (resultSelectIndexInner == sv2v_cast_2B0BB_signed(seqIndexInner));
				end
		end
	always_ff @(posedge clkInput)
		if (rstNInput && !coreStoppedInput) begin
			if (((((((dmemResponseInput[32] && fifoValidInner[responseOwnerInner]) && !fifoDropInner[responseOwnerInner]) && !(flushInfoInput[5] && !rv32_pkg_rob_is_older(fifoTagInner[responseOwnerInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]))) && lqValidInner[fifoIndexInner[responseOwnerInner]]) && (lqTagInner[fifoIndexInner[responseOwnerInner]] == fifoTagInner[responseOwnerInner])) && lqSentInner[fifoIndexInner[responseOwnerInner]]) && !lqResultReadyInner[fifoIndexInner[responseOwnerInner]])
				lqResultInner[fifoIndexInner[responseOwnerInner]] <= dmemResponseInput[31-:32];
`ifndef SYNTHESIS
			begin : sv2v_autoblock_47
`else
			begin : sv2v_autoblock_43
`endif
				reg signed [31:0] row;
				for (row = 0; row < LQ_DEPTH; row = row + 1)
					if (lqEarlyForwardInner[row] && !(((dmemRequestOutput[71] && dmemReqReadyInput) && loadRequestSelectedInner) && (loadSelectIndexInner == sv2v_cast_2B0BB_signed(row))))
						lqResultInner[row] <= lqEarlyValueInner[row];
			end
		end
	always_ff @(posedge clkInput)
		if (((((rstNInput && !coreStoppedInput) && addressInput[38]) && !addressInput[37]) && loadAddressMatchInner) && (!flushInfoInput[5] || rv32_pkg_rob_is_older(addressInput[36-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W])))
			lqAddressInner[loadAddressIndexInner] <= addressInput[31-:32];
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin
			assert (!(storeSendSelectedInner && loadRequestSelectedInner)) else $fatal(1, "single yield double memory grant");
			if (storeYieldDebtInner) begin
				assert (sqValidInner[sqHeadIndexInner] && sqCommittedInner[sqHeadIndexInner]) else $fatal(1, "single yield lost posted Store debt owner");
				if (storeAvailableInner)
					assert (storeSendSelectedInner && !loadBypassStoreInner) else $fatal(1, "single yield Store starvation");
			end
			if (loadBypassStoreInner)
				assert ((((((loadYieldEnableInput && !coreStoppedInput) && !flushInfoInput[5]) && !storeYieldDebtInner) && storeAvailableInner) && !postedStoreBlocksLoadInner) && pressureLowInner) else $fatal(1, "single yield unsafe permission");
		end
	always @(posedge clkInput)
		if (rstNInput) begin
			if (RENAME_WIDTH == 4) begin
				assert (($countones(loadAllocationLanesFireOutput) <= sv2v_cast_32_signed(loadCreditsOutput)) && ($countones(storeAllocationLanesFireOutput) <= sv2v_cast_32_signed(storeCreditsOutput))) else $fatal(1, "LSQ four-lane credit exceeded");
				begin : sv2v_autoblock_48
					reg signed [31:0] lane;
					for (lane = 0; lane < 4; lane = lane + 1)
						begin : sv2v_autoblock_49
							reg signed [31:0] older;
							for (older = 0; older < lane; older = older + 1)
								begin
									assert ((!loadAllocationLanesFireOutput[lane] || !loadAllocationLanesFireOutput[older]) || (loadLanesIndexInner[lane * LQ_INDEX_W+:LQ_INDEX_W] != loadLanesIndexInner[older * LQ_INDEX_W+:LQ_INDEX_W])) else $fatal(1, "four Load allocations share a row");
									assert ((!storeAllocationLanesFireOutput[lane] || !storeAllocationLanesFireOutput[older]) || (storeLanesIndexInner[lane * SQ_INDEX_W+:SQ_INDEX_W] != storeLanesIndexInner[older * SQ_INDEX_W+:SQ_INDEX_W])) else $fatal(1, "four Store allocations share a row");
								end
						end
				end
			end
			assert ((!loadAllocFireInner || !loadAllocSecondFireInner) || (loadAllocIndexOutput != loadAllocSecondIndexOutput)) else $fatal(1, "dual Load allocations share a row");
			assert ((!storeAllocFireInner || !storeAllocSecondFireInner) || (storeAllocIndexOutput != storeAllocSecondIndexOutput)) else $fatal(1, "dual Store allocations share a row");
			assert ((sv2v_cast_32_signed(sqUsedInner) + sv2v_cast_32_signed(storeAllocCountInner)) <= SQ_DEPTH) else $fatal(1, "Store allocation exceeds old SQ capacity");
			if ((loadAddressEventInner && !lqResultReadyInner[loadAddressIndexInner]) && !lqBroadcastedInner[loadAddressIndexInner])
				assert (addressedForwardValidInner == lqEarlyForwardInner[loadAddressIndexInner]) else $fatal(1, "early address-forward eligibility differs from original intent");
			if (responseResultIdentityLiveInner)
				assert (responseForwardPriorityInner == lqEarlyForwardInner[responseResultIndexInner]) else $fatal(1, "narrow response-forward priority differs from full original intent");
			assert (sv2v_cast_32_signed(fifoCountInner) <= rv32_pkg_DATA_REQUEST_ENTRIES) ;
			if (dmemResponseInput[32])
				assert (fifoValidInner[responseOwnerInner]) else $fatal(1, "LSU received a response without an outstanding owner");
			if ((dmemRequestOutput[71] && dmemReqReadyInput) && loadRequestSelectedInner)
				assert (sv2v_cast_32_signed(fifoCountInner) < rv32_pkg_DATA_REQUEST_ENTRIES) ;
		end
`endif
endmodule
module rv32_icache (
	clkInput,
	rstNInput,
	freezeInput,
	flushInput,
	secondInput,
	predecodeAddressInput,
	secondInstructionOutput,
	predecodeOutput,
	cpuRequestInput,
	cpuReqReadyOutput,
	cpuResponseOutput,
	cpuRspReadyInput,
	memRequestOutput,
	memReqReadyInput,
	memResponseInput,
	memRspReadyOutput,
	memFlushOutput,
	packetInstructionsOutput
);
	localparam [31:0] rv32_pkg_ICACHE_SETS = 16;
	parameter [31:0] SETS = rv32_pkg_ICACHE_SETS;
	parameter [31:0] FETCH_WIDTH = 1;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_REQUEST_ENTRIES = 8;
	parameter [31:0] REQUEST_DEPTH = ((rv32_pkg_FETCH_REQUEST_ENTRIES / FETCH_WIDTH) > 1 ? rv32_pkg_FETCH_REQUEST_ENTRIES / FETCH_WIDTH : 2);
	localparam [31:0] rv32_pkg_ICACHE_WAYS = 1;
	parameter [31:0] WAYS = rv32_pkg_ICACHE_WAYS;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire flushInput;
	input wire secondInput;
	input wire [31:0] predecodeAddressInput;
	output wire [31:0] secondInstructionOutput;
	output wire [4:0] predecodeOutput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	input wire [(65 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] cpuRequestInput;
	output wire cpuReqReadyOutput;
	output wire [(97 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] cpuResponseOutput;
	input wire cpuRspReadyInput;
	localparam [31:0] rv32_pkg_CACHE_LINE_BYTES = 64;
	localparam [31:0] rv32_pkg_CACHE_LINE_BITS = rv32_pkg_CACHE_LINE_BYTES << 3;
	output reg [(34 + rv32_pkg_CACHE_LINE_BITS) - 1:0] memRequestOutput;
	input wire memReqReadyInput;
	input wire [(33 + rv32_pkg_CACHE_LINE_BITS) - 1:0] memResponseInput;
	output wire memRspReadyOutput;
	output wire memFlushOutput;
	output wire [127:0] packetInstructionsOutput;
	generate
		if (((FETCH_WIDTH != 1) && (FETCH_WIDTH != 2)) && (FETCH_WIDTH != 4)) begin : g_invalid_fetch_width
			initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
		end
		if (((WAYS != 1) && (WAYS != 2)) && (WAYS != 4)) begin : g_invalid_ways
			initial $fatal(1, "ICache WAYS must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] FETCH_DATA_BITS = 32 * FETCH_WIDTH;
	localparam [31:0] OFFSET_W = 6;
	localparam [31:0] INDEX_W = $clog2(SETS);
	localparam [31:0] TAG_W = (32 - INDEX_W) - OFFSET_W;
	localparam [31:0] SLOT_W = $clog2(REQUEST_DEPTH);
	localparam [31:0] COUNT_W = $clog2(REQUEST_DEPTH + 1);
	localparam [31:0] WORD_W = 4;
	localparam [31:0] WAY_W = (WAYS > 1 ? $clog2(WAYS) : 1);
	localparam [31:0] PLRU_W = (WAYS == 4 ? 3 : 1);
	reg validInner [0:SETS - 1][0:WAYS - 1];
	reg [TAG_W - 1:0] tagInner [0:SETS - 1][0:WAYS - 1];
	reg [PLRU_W - 1:0] plruInner [0:SETS - 1];
	reg [WAY_W - 1:0] hitWayInner;
	reg [WAY_W - 1:0] predecodeWayInner;
	reg [WAY_W - 1:0] fillWayInner;
	reg [WAY_W - 1:0] readWayInner;
	reg predecodeHitInner;
	reg [31:0] requestAddressInner [0:REQUEST_DEPTH - 1];
	reg [31:0] requestPredictedPcInner [0:REQUEST_DEPTH - 1];
	reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] requestCheckpointInner [0:REQUEST_DEPTH - 1];
	reg requestReadyInner [0:REQUEST_DEPTH - 1];
	reg [FETCH_DATA_BITS - 1:0] requestInstructionInner [0:REQUEST_DEPTH - 1];
	reg requestSecondInner [0:REQUEST_DEPTH - 1];
	reg [SLOT_W - 1:0] headInner;
	wire [SLOT_W - 1:0] tailSlotInner;
	reg [COUNT_W - 1:0] countInner;
	reg readValidInner;
	reg [SLOT_W - 1:0] readIndexInner;
	reg [3:0] readLaneInner;
	reg hitInner;
	wire refillHitInner;
	wire readBlockedInner;
	wire headReadReadyInner;
	wire responseFireInner;
	wire requestFireInner;
	reg refillFoundInner;
	wire fillFireInner;
	reg [SLOT_W - 1:0] refillSlotInner;
	wire sramEnableInner;
	wire sramWriteModeInner;
	wire [INDEX_W - 1:0] sramAddressInner;
	wire [rv32_pkg_CACHE_LINE_BITS - 1:0] sramRdataInner;
	wire [rv32_pkg_CACHE_LINE_BITS - 1:0] wayRdataInner [0:WAYS - 1];
	wire [FETCH_DATA_BITS - 1:0] readWordInner;
	wire [FETCH_DATA_BITS - 1:0] fillWordInner;
	wire [FETCH_DATA_BITS - 1:0] forwardWordInner;
	localparam [6:0] rv32_pkg_OPCODE_BRANCH = 7'b1100011;
	localparam [6:0] rv32_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32_pkg_OPCODE_JALR = 7'b1100111;
	function automatic is_control;
		input reg [31:0] instruction;
		is_control = ((instruction[6:0] == rv32_pkg_OPCODE_BRANCH) || (instruction[6:0] == rv32_pkg_OPCODE_JAL)) || ((instruction[6:0] == rv32_pkg_OPCODE_JALR) && (instruction[14:12] == 3'b000));
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	function automatic [63:0] packet_words;
		input reg [rv32_pkg_CACHE_LINE_BITS - 1:0] lineData;
		input reg [31:0] address;
		packet_words = sv2v_cast_64(lineData >> (sv2v_cast_32(address[5:2]) << 5));
	endfunction
	function automatic [PLRU_W - 1:0] sv2v_cast_EBBC0;
		input reg [PLRU_W - 1:0] inp;
		sv2v_cast_EBBC0 = inp;
	endfunction
	function automatic [0:0] sv2v_cast_1;
		input reg [0:0] inp;
		sv2v_cast_1 = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [PLRU_W - 1:0] touch_way;
		input reg [PLRU_W - 1:0] bitsInput;
		input reg [WAY_W - 1:0] wayInput;
		begin
			touch_way = bitsInput;
			if (WAYS == 2)
				touch_way = sv2v_cast_EBBC0(wayInput);
			if (WAYS == 4) begin
				if (sv2v_cast_32_signed(wayInput) >= 2)
					touch_way = sv2v_cast_EBBC0({1'b1, sv2v_cast_1(bitsInput >> 1), sv2v_cast_1(wayInput)});
				else
					touch_way = sv2v_cast_EBBC0({1'b0, sv2v_cast_1(wayInput), bitsInput[0]});
			end
		end
	endfunction
	function automatic signed [WAY_W - 1:0] sv2v_cast_19C97_signed;
		input reg signed [WAY_W - 1:0] inp;
		sv2v_cast_19C97_signed = inp;
	endfunction
	always @* begin
		hitInner = 1'b0;
		hitWayInner = 1'sb0;
		predecodeHitInner = 1'b0;
		predecodeWayInner = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] way;
			for (way = 0; way < WAYS; way = way + 1)
				begin
					if (validInner[cpuRequestInput[(rv32_pkg_BPU_CKPT_ID_W + 63) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_BPU_CKPT_ID_W + 38]][way] && (tagInner[cpuRequestInput[(rv32_pkg_BPU_CKPT_ID_W + 63) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_BPU_CKPT_ID_W + 38]][way] == cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 63:(rv32_pkg_BPU_CKPT_ID_W + 63) - (31 - (INDEX_W + OFFSET_W))])) begin
						hitInner = 1'b1;
						hitWayInner = sv2v_cast_19C97_signed(way);
					end
					if (validInner[predecodeAddressInput[(INDEX_W + OFFSET_W) - 1:OFFSET_W]][way] && (tagInner[predecodeAddressInput[(INDEX_W + OFFSET_W) - 1:OFFSET_W]][way] == predecodeAddressInput[31:INDEX_W + OFFSET_W])) begin
						predecodeHitInner = 1'b1;
						predecodeWayInner = sv2v_cast_19C97_signed(way);
					end
				end
		end
	end
	function automatic [WAY_W - 1:0] sv2v_cast_19C97;
		input reg [WAY_W - 1:0] inp;
		sv2v_cast_19C97 = inp;
	endfunction
	always @* begin
		fillWayInner = 1'sb0;
		if (WAYS == 2)
			fillWayInner = sv2v_cast_19C97(!plruInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][0]);
		if (WAYS == 4) begin
			if (plruInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][PLRU_W - 1])
				fillWayInner = sv2v_cast_19C97_signed((((sv2v_cast_32_signed(plruInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + 32'd6)):rv32_pkg_CACHE_LINE_BITS + 6]]) >> 1) & 1) != 0 ? 0 : 1));
			else
				fillWayInner = sv2v_cast_19C97_signed((plruInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + 32'd6)):rv32_pkg_CACHE_LINE_BITS + 6]][0] ? 2 : 3));
		end
		begin : sv2v_autoblock_2
			reg signed [31:0] way;
			for (way = WAYS - 1; way >= 0; way = way - 1)
				if (!validInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][way])
					fillWayInner = sv2v_cast_19C97_signed(way);
		end
		begin : sv2v_autoblock_3
			reg signed [31:0] way;
			for (way = 0; way < WAYS; way = way + 1)
				if (validInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][way] && (tagInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][way] == memResponseInput[rv32_pkg_CACHE_LINE_BITS + 31:(rv32_pkg_CACHE_LINE_BITS + 31) - (31 - (INDEX_W + OFFSET_W))]))
					fillWayInner = sv2v_cast_19C97_signed(way);
		end
	end
	assign sramRdataInner = wayRdataInner[readWayInner];
	function automatic [3:0] sv2v_cast_F7755;
		input reg [3:0] inp;
		sv2v_cast_F7755 = inp;
	endfunction
	function automatic signed [3:0] sv2v_cast_F7755_signed;
		input reg signed [3:0] inp;
		sv2v_cast_F7755_signed = inp;
	endfunction
	generate
		if (FETCH_WIDTH >= 2) begin : g_predecode
			reg [15:0] controlMaskInner [0:SETS - 1][0:WAYS - 1];
			reg [15:0] fillMaskInner;
			always @* begin : sv2v_autoblock_4
				reg signed [31:0] wordIndex;
				for (wordIndex = 0; wordIndex < 16; wordIndex = wordIndex + 1)
					fillMaskInner[wordIndex] = is_control(memResponseInput[(rv32_pkg_CACHE_LINE_BITS - 1) - ((rv32_pkg_CACHE_LINE_BITS - 1) - (wordIndex * 32))+:32]);
			end
			always_ff @(posedge clkInput)
				if (fillFireInner)
					controlMaskInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][fillWayInner] <= fillMaskInner;
			assign predecodeOutput[4] = predecodeHitInner;
			assign predecodeOutput[3] = predecodeHitInner && controlMaskInner[predecodeAddressInput[(INDEX_W + OFFSET_W) - 1:OFFSET_W]][predecodeWayInner][predecodeAddressInput[5:2]];
			if (FETCH_WIDTH == 4) begin : g_four_hints
				reg [3:0] controls;
				always @* begin
					controls = 1'sb0;
					begin : sv2v_autoblock_5
						reg signed [31:0] lane;
						for (lane = 0; lane < 4; lane = lane + 1)
							if (predecodeHitInner && (lane < (16 - sv2v_cast_32_signed(predecodeAddressInput[5:2]))))
								controls[lane] = controlMaskInner[predecodeAddressInput[(INDEX_W + OFFSET_W) - 1:OFFSET_W]][predecodeWayInner][sv2v_cast_32_signed(predecodeAddressInput[5:2]) + lane];
					end
				end
				assign predecodeOutput[2] = controls[1];
				assign predecodeOutput[1] = controls[2];
				assign predecodeOutput[0] = controls[3];
			end
			else begin : g_two_hints
				assign predecodeOutput[2] = (predecodeHitInner && (predecodeAddressInput[5:2] != sv2v_cast_F7755(15))) && controlMaskInner[predecodeAddressInput[(INDEX_W + OFFSET_W) - 1:OFFSET_W]][predecodeWayInner][predecodeAddressInput[5:2] + sv2v_cast_F7755_signed(1)];
				assign predecodeOutput[1] = 1'b0;
				assign predecodeOutput[0] = 1'b0;
			end
		end
		else begin : g_no_predecode
			assign predecodeOutput = 1'sb0;
		end
	endgenerate
	function automatic [SLOT_W - 1:0] sv2v_cast_7C1AF;
		input reg [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	assign tailSlotInner = headInner + sv2v_cast_7C1AF(countInner);
	assign headReadReadyInner = (((countInner != 0) && !requestReadyInner[headInner]) && readValidInner) && (readIndexInner == headInner);
	function automatic [127:0] sv2v_cast_128;
		input reg [127:0] inp;
		sv2v_cast_128 = inp;
	endfunction
	generate
		if (FETCH_WIDTH == 4) begin : g_four_packet_words
			assign readWordInner = sv2v_cast_128(sramRdataInner >> (sv2v_cast_32(readLaneInner) << 5));
			assign fillWordInner = sv2v_cast_128(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS] >> (sv2v_cast_32(requestAddressInner[refillSlotInner][5:2]) << 5));
			assign forwardWordInner = sv2v_cast_128(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS] >> (sv2v_cast_32(cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 37:rv32_pkg_BPU_CKPT_ID_W + 34]) << 5));
			assign secondInstructionOutput = (requestSecondInner[headInner] ? (headReadReadyInner ? readWordInner[63:32] : requestInstructionInner[headInner][63:32]) : 32'b00000000000000000000000000000000);
		end
		else if (FETCH_WIDTH == 2) begin : g_packet_words
			assign readWordInner = packet_words(sramRdataInner, sv2v_cast_32(readLaneInner) << 2);
			assign fillWordInner = packet_words(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS], requestAddressInner[refillSlotInner]);
			assign forwardWordInner = packet_words(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS], cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)]);
			assign secondInstructionOutput = (requestSecondInner[headInner] ? (headReadReadyInner ? readWordInner[63:32] : requestInstructionInner[headInner][63:32]) : 32'b00000000000000000000000000000000);
		end
		else begin : g_scalar_word
			assign readWordInner = sv2v_cast_32(sramRdataInner >> (sv2v_cast_32(readLaneInner) << 5));
			assign fillWordInner = sv2v_cast_32(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS] >> (sv2v_cast_32(requestAddressInner[refillSlotInner][5:2]) << 5));
			assign forwardWordInner = sv2v_cast_32(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS] >> (sv2v_cast_32(cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 37:rv32_pkg_BPU_CKPT_ID_W + 34]) << 5));
			assign secondInstructionOutput = 32'b00000000000000000000000000000000;
		end
	endgenerate
	assign packetInstructionsOutput = sv2v_cast_128((headReadReadyInner ? readWordInner : requestInstructionInner[headInner]));
	assign cpuResponseOutput[33 + (rv32_pkg_BPU_CKPT_ID_W + 63)] = (countInner != 0) && (requestReadyInner[headInner] || headReadReadyInner);
	assign cpuResponseOutput[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)] = (headReadReadyInner ? readWordInner[31:0] : requestInstructionInner[headInner][31:0]);
	assign cpuResponseOutput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)] = requestAddressInner[headInner];
	assign cpuResponseOutput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)] = requestPredictedPcInner[headInner];
	assign cpuResponseOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = requestCheckpointInner[headInner];
	assign responseFireInner = (cpuResponseOutput[33 + (rv32_pkg_BPU_CKPT_ID_W + 63)] && cpuRspReadyInput) && !flushInput;
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	always @* begin
		refillFoundInner = 1'b0;
		refillSlotInner = 1'sb0;
		begin : sv2v_autoblock_6
			reg signed [31:0] age;
			for (age = 0; age < REQUEST_DEPTH; age = age + 1)
				if (((((memResponseInput[rv32_pkg_CACHE_LINE_BITS + 32] && (age < sv2v_cast_32_signed(countInner))) && !refillFoundInner) && !requestReadyInner[sv2v_cast_7C1AF(headInner + sv2v_cast_7C1AF_signed(age))]) && !(readValidInner && (readIndexInner == sv2v_cast_7C1AF(headInner + sv2v_cast_7C1AF_signed(age))))) && ({requestAddressInner[sv2v_cast_7C1AF(headInner + sv2v_cast_7C1AF_signed(age))][31:OFFSET_W], {OFFSET_W {1'b0}}} == memResponseInput[rv32_pkg_CACHE_LINE_BITS + 31-:((rv32_pkg_CACHE_LINE_BITS + 31) >= (rv32_pkg_CACHE_LINE_BITS + 0) ? ((rv32_pkg_CACHE_LINE_BITS + 31) - (rv32_pkg_CACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_CACHE_LINE_BITS + 0) - (rv32_pkg_CACHE_LINE_BITS + 31)) + 1)])) begin
					refillFoundInner = 1'b1;
					refillSlotInner = sv2v_cast_7C1AF(headInner + sv2v_cast_7C1AF_signed(age));
				end
		end
	end
	assign memRspReadyOutput = (!freezeInput && !flushInput) && refillFoundInner;
	assign fillFireInner = memResponseInput[rv32_pkg_CACHE_LINE_BITS + 32] && memRspReadyOutput;
	assign refillHitInner = fillFireInner && (cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 63:rv32_pkg_BPU_CKPT_ID_W + 38] == memResponseInput[rv32_pkg_CACHE_LINE_BITS + 31:rv32_pkg_CACHE_LINE_BITS + 6]);
	assign readBlockedInner = (fillFireInner && hitInner) && !refillHitInner;
	function automatic [COUNT_W - 1:0] sv2v_cast_D4579;
		input reg [COUNT_W - 1:0] inp;
		sv2v_cast_D4579 = inp;
	endfunction
	assign cpuReqReadyOutput = (((!freezeInput && !flushInput) && ((countInner < sv2v_cast_D4579(REQUEST_DEPTH)) || responseFireInner)) && (memReqReadyInput || refillHitInner)) && !readBlockedInner;
	assign requestFireInner = cpuRequestInput[33 + (rv32_pkg_BPU_CKPT_ID_W + 31)] && cpuReqReadyOutput;
	always @* begin
		memRequestOutput = 1'sb0;
		memRequestOutput[2 + (rv32_pkg_CACHE_LINE_BITS + 31)] = (requestFireInner && !hitInner) && !refillHitInner;
		memRequestOutput[rv32_pkg_CACHE_LINE_BITS + 31-:((rv32_pkg_CACHE_LINE_BITS + 31) >= (rv32_pkg_CACHE_LINE_BITS + 0) ? ((rv32_pkg_CACHE_LINE_BITS + 31) - (rv32_pkg_CACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_CACHE_LINE_BITS + 0) - (rv32_pkg_CACHE_LINE_BITS + 31)) + 1)] = {cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 63:rv32_pkg_BPU_CKPT_ID_W + 38], {OFFSET_W {1'b0}}};
	end
	assign memFlushOutput = flushInput;
	assign sramEnableInner = rstNInput && ((!freezeInput && !flushInput) || (freezeInput && readValidInner));
	assign sramAddressInner = (fillFireInner ? memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6] : (freezeInput && readValidInner ? requestAddressInner[readIndexInner][(INDEX_W + OFFSET_W) - 1:OFFSET_W] : cpuRequestInput[(rv32_pkg_BPU_CKPT_ID_W + 63) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_BPU_CKPT_ID_W + 38]));
	assign sramWriteModeInner = refillFoundInner && !(freezeInput && readValidInner);
	genvar _gv_way_1;
	generate
		for (_gv_way_1 = 0; _gv_way_1 < WAYS; _gv_way_1 = _gv_way_1 + 1) begin : g_way
			localparam way = _gv_way_1;
			sram_fakeram #(
				.DEPTH(SETS),
				.WIDTH(rv32_pkg_CACHE_LINE_BITS),
				.WRITE_GRANULARITY(32)
			) u_data(
				.clk(clkInput),
				.en(sramEnableInner),
				.we(sramWriteModeInner && (fillWayInner == sv2v_cast_19C97_signed(way))),
				.addr(sramAddressInner),
				.wdata(memResponseInput[rv32_pkg_CACHE_LINE_BITS - 1-:rv32_pkg_CACHE_LINE_BITS]),
				.wmask({rv32_pkg_CACHE_LINE_BYTES >> 2 {1'b1}}),
				.rdata(wayRdataInner[way])
			);
		end
	endgenerate
	function automatic signed [COUNT_W - 1:0] sv2v_cast_D4579_signed;
		input reg signed [COUNT_W - 1:0] inp;
		sv2v_cast_D4579_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 1'sb0;
			countInner <= 1'sb0;
			readValidInner <= 1'b0;
			readIndexInner <= 1'sb0;
			readLaneInner <= 1'sb0;
			readWayInner <= 1'sb0;
			begin : sv2v_autoblock_7
				reg signed [31:0] s;
				for (s = 0; s < SETS; s = s + 1)
					begin
						plruInner[s] <= 1'sb0;
						begin : sv2v_autoblock_8
							reg signed [31:0] way;
							for (way = 0; way < WAYS; way = way + 1)
								begin
									validInner[s][way] <= 1'b0;
									tagInner[s][way] <= 1'sb0;
								end
						end
					end
			end
			begin : sv2v_autoblock_9
				reg signed [31:0] q;
				for (q = 0; q < REQUEST_DEPTH; q = q + 1)
					begin
						requestAddressInner[q] <= 1'sb0;
						requestPredictedPcInner[q] <= 1'sb0;
						requestCheckpointInner[q] <= 1'sb0;
						requestReadyInner[q] <= 1'b0;
						requestInstructionInner[q] <= 1'sb0;
						requestSecondInner[q] <= 1'b0;
					end
			end
		end
		else if (!freezeInput && flushInput) begin
			headInner <= 1'sb0;
			countInner <= 1'sb0;
			readValidInner <= 1'b0;
			readIndexInner <= 1'sb0;
			readLaneInner <= 1'sb0;
			begin : sv2v_autoblock_10
				reg signed [31:0] q;
				for (q = 0; q < REQUEST_DEPTH; q = q + 1)
					requestReadyInner[q] <= 1'b0;
			end
		end
		else if (!freezeInput) begin
			if (responseFireInner)
				headInner <= headInner + sv2v_cast_7C1AF_signed(1);
			(* full_case, parallel_case *)
			case ({requestFireInner, responseFireInner})
				2'b10: countInner <= countInner + sv2v_cast_D4579_signed(1);
				2'b01: countInner <= countInner - sv2v_cast_D4579_signed(1);
				default:
					;
			endcase
			readValidInner <= (requestFireInner && hitInner) && !fillFireInner;
			if ((requestFireInner && hitInner) && !refillHitInner) begin
				readIndexInner <= tailSlotInner;
				readLaneInner <= cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 37:rv32_pkg_BPU_CKPT_ID_W + 34];
				readWayInner <= hitWayInner;
			end
			if (fillFireInner) begin
				validInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][fillWayInner] <= 1'b1;
				tagInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]][fillWayInner] <= memResponseInput[rv32_pkg_CACHE_LINE_BITS + 31:(rv32_pkg_CACHE_LINE_BITS + 31) - (31 - (INDEX_W + OFFSET_W))];
				plruInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]] <= touch_way(plruInner[memResponseInput[(rv32_pkg_CACHE_LINE_BITS + 31) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_CACHE_LINE_BITS + 6]], fillWayInner);
			end
			else if (requestFireInner && hitInner)
				plruInner[cpuRequestInput[(rv32_pkg_BPU_CKPT_ID_W + 63) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_BPU_CKPT_ID_W + 38]] <= touch_way(plruInner[cpuRequestInput[(rv32_pkg_BPU_CKPT_ID_W + 63) - (32 - (INDEX_W + OFFSET_W)):rv32_pkg_BPU_CKPT_ID_W + 38]], hitWayInner);
			begin : sv2v_autoblock_11
				reg signed [31:0] q;
				for (q = 0; q < REQUEST_DEPTH; q = q + 1)
					if (requestFireInner && (tailSlotInner == sv2v_cast_7C1AF_signed(q))) begin
						requestAddressInner[q] <= cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)];
						requestPredictedPcInner[q] <= cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 31-:((rv32_pkg_BPU_CKPT_ID_W + 31) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 31) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 31)) + 1)];
						requestCheckpointInner[q] <= cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W];
						requestSecondInner[q] <= (FETCH_WIDTH >= 2) && secondInput;
						requestReadyInner[q] <= refillHitInner;
						requestInstructionInner[q] <= (refillHitInner ? forwardWordInner : {FETCH_DATA_BITS {1'sb0}});
					end
					else begin
						if (responseFireInner && (headInner == sv2v_cast_7C1AF_signed(q)))
							requestReadyInner[q] <= 1'b0;
						else if (fillFireInner && (refillSlotInner == sv2v_cast_7C1AF_signed(q)))
							requestReadyInner[q] <= 1'b1;
						else if ((readValidInner && (readIndexInner == sv2v_cast_7C1AF_signed(q))) && !(responseFireInner && headReadReadyInner))
							requestReadyInner[q] <= 1'b1;
						if (fillFireInner && (refillSlotInner == sv2v_cast_7C1AF_signed(q)))
							requestInstructionInner[q] <= fillWordInner;
						else if ((readValidInner && (readIndexInner == sv2v_cast_7C1AF_signed(q))) && !(responseFireInner && headReadReadyInner))
							requestInstructionInner[q] <= readWordInner;
					end
			end
		end
`ifndef SYNTHESIS
	initial assert ((((SETS >= 2) && ((SETS & (SETS - 1)) == 0)) && (REQUEST_DEPTH >= 2)) && ((REQUEST_DEPTH & (REQUEST_DEPTH - 1)) == 0)) else $fatal(1, "ICache needs power-of-two SRAM rows and request slots");
	always @(posedge clkInput)
		if (rstNInput) begin
			assert (countInner <= sv2v_cast_D4579(REQUEST_DEPTH)) else $fatal(1, "ICache request capacity exceeded");
			if (((FETCH_WIDTH == 2) && requestFireInner) && secondInput)
				assert (((hitInner && (predecodeAddressInput == cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 63-:((rv32_pkg_BPU_CKPT_ID_W + 63) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 63) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 63)) + 1)])) && (cpuRequestInput[rv32_pkg_BPU_CKPT_ID_W + 37:rv32_pkg_BPU_CKPT_ID_W + 34] != sv2v_cast_F7755(15))) && !predecodeOutput[3]) else $fatal(1, "dual request lacked valid earliest-CFI predecode");
			assert (!fillFireInner || !(readValidInner && (refillSlotInner == readIndexInner))) else $fatal(1, "ICache refill collided with old synchronous read");
		end
`endif
endmodule
module rv32_dcache (
	clkInput,
	rstNInput,
	cpuRequestInput,
	storeSetPreviewInput,
	cpuReqReadyOutput,
	cpuResponseOutput,
	responsePreviewTransactionOutput,
	responsePreviewSelectOutput,
	memRequestOutput,
	memReadReadyInput,
	memWriteReadyInput,
	memResponseInput,
	memWordResponseInput,
	memWriteResponseInput,
	memRspReadyOutput,
	memWriteRspReadyOutput,
	initializedOutput,
	idleOutput,
	exitReadyInput,
	exitValidOutput,
	exitValueOutput
);
	localparam [31:0] rv32_pkg_DCACHE_SETS = 128;
	parameter [31:0] SETS = rv32_pkg_DCACHE_SETS;
	localparam [31:0] rv32_pkg_DCACHE_WAYS = 2;
	parameter [31:0] WAYS = rv32_pkg_DCACHE_WAYS;
	parameter [0:0] EARLY_WORD_RETURN = 1'b0;
	parameter [31:0] STORE_LOCATION_ENTRIES = 4;
	parameter [0:0] LOAD_PREFETCH = 1'b0;
	parameter [0:0] STORE_SET_PREVIEW = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	localparam [31:0] rv32_pkg_DATA_REQUEST_ENTRIES = 8;
	localparam signed [31:0] rv32_pkg_DATA_TRANSACTION_W = 3;
	input wire [74:0] cpuRequestInput;
	input wire [6:0] storeSetPreviewInput;
	output wire cpuReqReadyOutput;
	output reg [35:0] cpuResponseOutput;
	output wire [5:0] responsePreviewTransactionOutput;
	output wire [1:0] responsePreviewSelectOutput;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BYTES = 32;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BITS = rv32_pkg_DCACHE_LINE_BYTES << 3;
	output reg [(73 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] memRequestOutput;
	input wire memReadReadyInput;
	input wire memWriteReadyInput;
	input wire [(35 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] memResponseInput;
	input wire [66:0] memWordResponseInput;
	input wire [34:0] memWriteResponseInput;
	output reg memRspReadyOutput;
	output reg memWriteRspReadyOutput;
	output wire initializedOutput;
	output wire idleOutput;
	input wire exitReadyInput;
	output reg exitValidOutput;
	output reg [31:0] exitValueOutput;
	localparam signed [31:0] INDEX_W = $clog2(SETS);
	localparam signed [31:0] OFFSET_W = 5;
	localparam signed [31:0] TAG_W = (32 - INDEX_W) - OFFSET_W;
	localparam signed [31:0] META_W = TAG_W + 1;
	localparam signed [31:0] WORDS_PER_LINE = 8;
	localparam signed [31:0] FILL_WORDS_PER_BEAT = WORDS_PER_LINE;
	localparam signed [31:0] WORD_INDEX_W = 4;
	localparam signed [31:0] WAY_W = (WAYS > 1 ? $clog2(WAYS) : 1);
	localparam signed [31:0] PLRU_W = (WAYS > 2 ? 3 : 1);
	localparam signed [31:0] REQUEST_DEPTH = rv32_pkg_DATA_REQUEST_ENTRIES;
	localparam signed [31:0] REQUEST_W = 3;
	localparam signed [31:0] COUNT_W = 4;
	localparam signed [31:0] MSHR_DEPTH = 4;
	reg [(75 + WAY_W) + 6:0] requestInner [0:7];
	reg [7:0] exitInner;
	reg [((((32 + TAG_W) + REQUEST_W) + WAY_W) + WORD_INDEX_W) + 5:0] missesInner [0:3];
	reg [31:0] rawInner [0:7];
	reg [rv32_pkg_DCACHE_LINE_BITS - 1:0] victimPayloadInner [0:3];
	reg [OFFSET_W:0] byteEndInner [0:7];
	reg [7:0] storeHazardInner;
	reg [7:0] storeAllocationHazardInner;
	reg [7:0] olderInner [0:7];
	reg [3:0] countInner;
	reg [2:0] cursorInner;
	reg [2:0] readIndexInner;
	reg readValidInner;
	wire acceptLookupInner;
	reg [4:0] readLookupAddressInner;
	reg [1:0] readLookupSizeInner;
	wire [74:0] readLookupRequestInner;
	reg [WAYS - 1:0] readWayMaskInner;
	reg validInner [0:SETS - 1][0:WAYS - 1];
	reg [PLRU_W - 1:0] plruInner [0:SETS - 1];
	wire [31:0] dataRdataBankInner [0:WAYS - 1][0:7];
	reg [31:0] dataWdataBankInner [0:WAYS - 1][0:7];
	reg [3:0] dataMaskBankInner [0:WAYS - 1][0:7];
	reg dataEnableBankInner [0:WAYS - 1][0:7];
	reg dataWriteBankInner [0:WAYS - 1][0:7];
	reg metaEnableInner [0:WAYS - 1];
	reg metaWriteInner [0:WAYS - 1];
	wire [META_W - 1:0] metaRdataInner [0:WAYS - 1];
	reg [META_W - 1:0] metaWdataInner;
	wire [INDEX_W - 1:0] dataAddressBankInner [0:WAYS - 1][0:7];
	reg [INDEX_W - 1:0] metaAddressInner [0:WAYS - 1];
	reg [INDEX_W - 1:0] lookupAddressInner;
	reg [7:0] lookupWinnerInner;
`ifndef SYNTHESIS
	reg [INDEX_W - 1:0] sramAddressInner;
	reg fillBeatInner;
	integer fillMissInner;
	integer lookupInner;
	function automatic [INDEX_W - 1:0] set_of;
		input reg [31:0] address;
		set_of = address[OFFSET_W+:INDEX_W];
	endfunction
	integer storeInner;
	always @* begin
		sramAddressInner = 1'sb0;
		if (rstNInput && fillBeatInner)
			sramAddressInner = set_of(missesInner[fillMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]);
		else if (rstNInput && (storeInner >= 0))
			sramAddressInner = set_of(requestInner[storeInner][(75 + (WAY_W + 6)) - 2-:32]);
		else if (rstNInput && (lookupInner >= 0))
			sramAddressInner = set_of(requestInner[lookupInner][(75 + (WAY_W + 6)) - 2-:32]);
		else if (rstNInput && acceptLookupInner)
			sramAddressInner = set_of(cpuRequestInput[72-:32]);
	end
`endif
	reg prefetchPendingInner;
	wire prefetchEnqueueInner;
	reg prefetchDuplicateInner;
	reg prefetchStoppedInner;
	reg [31:0] prefetchTargetInner;
	reg [31:0] prefetchNextLineInner;
	reg [3:0] prefetchSeenValidInner;
	reg [31:0] prefetchSeenLineInner [0:3];
	reg [1:0] prefetchSeenVictimInner;
	reg prefetchSeenInner;
	reg prefetchTriggerInner;
	wire [7:0] prefetchMaskInner;
	reg [7:0] prefetchAbortInner;
	reg [7:0] demandLookupMaskInner;
	reg [2:0] prefetchMissCountInner;
	reg prefetchStoreConflictInner;
	wire [INDEX_W - 1:0] storeCancelSetInner;
`ifdef SYNTHESIS
	function automatic [INDEX_W - 1:0] set_of;
		input reg [31:0] address;
		set_of = address[OFFSET_W+:INDEX_W];
	endfunction
`endif
	function automatic [INDEX_W - 1:0] sv2v_cast_3C754;
		input reg [INDEX_W - 1:0] inp;
		sv2v_cast_3C754 = inp;
	endfunction
	generate
		if (STORE_SET_PREVIEW && (SETS == rv32_pkg_DCACHE_SETS)) begin : g_store_set_preview
			assign storeCancelSetInner = sv2v_cast_3C754(storeSetPreviewInput);
		end
		else begin : g_store_set_original
			assign storeCancelSetInner = set_of(cpuRequestInput[72-:32]);
		end
	endgenerate
`ifndef SYNTHESIS
	wire acceptInner;
	always @(posedge clkInput)
		if ((rstNInput && acceptInner) && cpuRequestInput[73])
			assert (storeCancelSetInner == set_of(cpuRequestInput[72-:32])) else $fatal(1, "DCache Store preview boundary mismatch");
`endif
	genvar _gv_p_2;
	generate
		for (_gv_p_2 = 0; _gv_p_2 < REQUEST_DEPTH; _gv_p_2 = _gv_p_2 + 1) begin : g_prefetch_type
			localparam p = _gv_p_2;
			assign prefetchMaskInner[p] = requestInner[p][3] && requestInner[p][0];
		end
	endgenerate
`ifdef SYNTHESIS
	wire acceptInner;
`endif
	function automatic signed [31:0] find_miss;
		input reg [31:0] lineAddress;
		begin
			find_miss = -1;
			begin : sv2v_autoblock_1
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (missesInner[m][5] && (missesInner[m][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)] == lineAddress))
						find_miss = m;
			end
		end
	endfunction
	function automatic [31:0] line_of;
		input reg [31:0] address;
		line_of = {address[31:OFFSET_W], {OFFSET_W {1'b0}}};
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	always @* begin : prefetch_old_state
		prefetchMissCountInner = 1'sb0;
		begin : sv2v_autoblock_2
			reg signed [31:0] m;
			for (m = 0; m < MSHR_DEPTH; m = m + 1)
				prefetchMissCountInner = prefetchMissCountInner + sv2v_cast_3(missesInner[m][5]);
		end
		prefetchSeenInner = 1'b0;
		begin : sv2v_autoblock_3
			reg signed [31:0] h;
			for (h = 0; h < 4; h = h + 1)
				if (prefetchSeenValidInner[h] && (prefetchSeenLineInner[h] == line_of(cpuRequestInput[72-:32])))
					prefetchSeenInner = 1'b1;
		end
		prefetchNextLineInner = line_of(cpuRequestInput[72-:32]) + rv32_pkg_DCACHE_LINE_BYTES;
		prefetchTriggerInner = (((((LOAD_PREFETCH && !prefetchStoppedInner) && acceptInner) && !cpuRequestInput[73]) && (cpuRequestInput[72:69] == 0)) && (prefetchNextLineInner[31:28] == 0)) && !prefetchSeenInner;
		prefetchDuplicateInner = 1'b0;
		prefetchStoreConflictInner = 1'b0;
		prefetchAbortInner = 1'sb0;
		begin : sv2v_autoblock_4
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				begin
					if (requestInner[row][3] && (line_of(requestInner[row][(75 + (WAY_W + 6)) - 2-:32]) == prefetchTargetInner))
						prefetchDuplicateInner = 1'b1;
					if ((requestInner[row][3] && requestInner[row][(75 + (WAY_W + 6)) - 1]) && (set_of(requestInner[row][(75 + (WAY_W + 6)) - 2-:32]) == set_of(prefetchTargetInner)))
						prefetchStoreConflictInner = 1'b1;
					if (prefetchMaskInner[row] && !requestInner[row][4]) begin
						if ((prefetchStoppedInner || (prefetchMissCountInner >= 3)) || (find_miss(line_of(requestInner[row][(75 + (WAY_W + 6)) - 2-:32])) >= 0))
							prefetchAbortInner[row] = 1'b1;
						begin : sv2v_autoblock_5
							reg signed [31:0] st;
							for (st = 0; st < REQUEST_DEPTH; st = st + 1)
								if ((requestInner[st][3] && requestInner[st][(75 + (WAY_W + 6)) - 1]) && (set_of(requestInner[st][(75 + (WAY_W + 6)) - 2-:32]) == set_of(requestInner[row][(75 + (WAY_W + 6)) - 2-:32])))
									prefetchAbortInner[row] = 1'b1;
						end
						if ((acceptInner && cpuRequestInput[73]) && (storeCancelSetInner == set_of(requestInner[row][(75 + (WAY_W + 6)) - 2-:32])))
							prefetchAbortInner[row] = 1'b1;
					end
				end
		end
	end
	function automatic signed [3:0] sv2v_cast_D4579_signed;
		input reg signed [3:0] inp;
		sv2v_cast_D4579_signed = inp;
	endfunction
	assign prefetchEnqueueInner = (((((((((LOAD_PREFETCH && rstNInput) && !prefetchStoppedInner) && prefetchPendingInner) && !cpuRequestInput[74]) && !(|prefetchMaskInner)) && (countInner <= sv2v_cast_D4579_signed(6))) && (prefetchMissCountInner <= 2)) && !prefetchDuplicateInner) && !prefetchStoreConflictInner) && (find_miss(prefetchTargetInner) < 0);
	localparam [31:0] rv32_pkg_AXI_EXIT_ADDR = 32'h80000000;
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			prefetchPendingInner <= 0;
			prefetchTargetInner <= 0;
			prefetchSeenValidInner <= 0;
			prefetchSeenVictimInner <= 0;
			prefetchStoppedInner <= 0;
		end
		else begin
			if ((((prefetchEnqueueInner || prefetchDuplicateInner) || prefetchStoreConflictInner) || (prefetchMissCountInner >= 3)) || (countInner > sv2v_cast_D4579_signed(6)))
				prefetchPendingInner <= 0;
			if (prefetchTriggerInner) begin
				prefetchPendingInner <= 1;
				prefetchTargetInner <= prefetchNextLineInner;
				prefetchSeenValidInner[prefetchSeenVictimInner] <= 1;
				prefetchSeenVictimInner <= prefetchSeenVictimInner + 2'd1;
			end
			if ((acceptInner && cpuRequestInput[73]) && (cpuRequestInput[72-:32] == rv32_pkg_AXI_EXIT_ADDR)) begin
				prefetchStoppedInner <= 1;
				prefetchPendingInner <= 0;
			end
		end
	always_ff @(posedge clkInput)
		if (rstNInput && prefetchTriggerInner)
			prefetchSeenLineInner[prefetchSeenVictimInner] <= line_of(cpuRequestInput[72-:32]);
	reg [7:0] activeInner;
	reg [7:0] releasedInner;
	integer firstInner;
	integer hitWayInner;
	integer freeMissInner;
	integer allocationInner;
`ifdef SYNTHESIS
	integer lookupInner;
`endif
	integer lookupCandidateInner;
	integer responseInner;
`ifdef SYNTHESIS
	integer storeInner;
`endif
	integer allocateMissInner;
	integer normalResponseInner;
	integer mergeSlotInner;
	integer mergeMissInner;
`ifdef SYNTHESIS
	integer fillMissInner;
`endif
	integer writeAckInner;
	integer readMissInner;
	integer writeMissInner;
`ifdef SYNTHESIS
	reg fillBeatInner;
`endif
	reg fillFireInner;
	reg firstFillInner;
	reg earlyInner;
	reg [31:0] readHitRawInner;
	wire [3:0] fillCanRespondInner;
	wire [2:0] fillTransactionInner [0:3];
	reg [2:0] normalTransactionInner;
	reg [2:0] bufferedTransactionInner;
	reg [2:0] hitTransactionInner;
	reg [7:0] normalWinnerInner;
	reg [7:0] normalBufferedMaskInner;
	reg [7:0] normalBufferedWinnerInner;
	reg [7:0] normalHitEligibleInner;
	reg normalHitWinsInner;
	reg [31:0] normalReadDataInner;
	reg [WAY_W - 1:0] victimWayInner;
	reg wordReturnInner;
	reg wordCaptureValidInner;
	reg [7:0] wordCaptureInner;
	wire [1:0] wordMissInner;
	wire [2:0] wordOwnerInner;
	reg [31:0] wordRawInner;
	assign wordMissInner = memWordResponseInput[33-:2];
	assign wordOwnerInner = missesInner[wordMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)];
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @* begin
		wordRawInner = memWordResponseInput[31-:32] >> (sv2v_cast_32(requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 32:(75 + (WAY_W + 6)) - 33]) << 3);
		case (requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 70-:2])
			2'd0: wordRawInner = {24'b000000000000000000000000, wordRawInner[7:0]};
			2'd1: wordRawInner = {16'b0000000000000000, wordRawInner[15:0]};
			default:
				;
		endcase
	end
	localparam signed [31:0] LOCATION_INDEX_W = (STORE_LOCATION_ENTRIES > 1 ? $clog2(STORE_LOCATION_ENTRIES) : 1);
	reg [STORE_LOCATION_ENTRIES - 1:0] hitLocationValidInner;
	reg [31:OFFSET_W] hitLocationLineInner [0:STORE_LOCATION_ENTRIES - 1];
	reg [WAY_W - 1:0] hitLocationWayInner [0:STORE_LOCATION_ENTRIES - 1];
	reg [LOCATION_INDEX_W - 1:0] hitLocationVictimInner;
	reg [LOCATION_INDEX_W - 1:0] hitLocationTrainIndexInner;
	reg hitLocationTrainInner;
	reg storeHintMatchInner;
	reg storeHintFireInner;
	reg [WAY_W - 1:0] storeHintWayInner;
	function automatic signed [LOCATION_INDEX_W - 1:0] sv2v_cast_DBCE1_signed;
		input reg signed [LOCATION_INDEX_W - 1:0] inp;
		sv2v_cast_DBCE1_signed = inp;
	endfunction
	always @* begin : hit_location_query
		hitLocationTrainInner = ((readValidInner && !requestInner[readIndexInner][0]) && (hitWayInner >= 0)) && !requestInner[readIndexInner][(75 + (WAY_W + 6)) - 1];
		hitLocationTrainIndexInner = hitLocationVictimInner;
		begin : sv2v_autoblock_6
			reg signed [31:0] h;
			for (h = STORE_LOCATION_ENTRIES - 1; h >= 0; h = h - 1)
				if (!hitLocationValidInner[h])
					hitLocationTrainIndexInner = sv2v_cast_DBCE1_signed(h);
		end
		begin : sv2v_autoblock_7
			reg signed [31:0] h;
			for (h = 0; h < STORE_LOCATION_ENTRIES; h = h + 1)
				if (hitLocationValidInner[h] && (hitLocationLineInner[h] == requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 28]))
					hitLocationTrainIndexInner = sv2v_cast_DBCE1_signed(h);
		end
	end
	function automatic [LOCATION_INDEX_W - 1:0] sv2v_cast_DBCE1;
		input reg [LOCATION_INDEX_W - 1:0] inp;
		sv2v_cast_DBCE1 = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			hitLocationValidInner <= 1'sb0;
			hitLocationVictimInner <= 1'sb0;
		end
		else begin
			begin : sv2v_autoblock_8
				reg signed [31:0] h;
				for (h = 0; h < STORE_LOCATION_ENTRIES; h = h + 1)
					if ((allocateMissInner >= 0) && (hitLocationLineInner[h][OFFSET_W+:INDEX_W] == requestInner[readIndexInner][(75 + (WAY_W + 6)) - 28+:INDEX_W]))
						hitLocationValidInner[h] <= 1'b0;
			end
			if (hitLocationTrainInner) begin
				hitLocationValidInner[hitLocationTrainIndexInner] <= 1'b1;
				hitLocationVictimInner <= (hitLocationTrainIndexInner == sv2v_cast_DBCE1(STORE_LOCATION_ENTRIES - 1) ? sv2v_cast_DBCE1_signed(0) : hitLocationTrainIndexInner + sv2v_cast_DBCE1_signed(1));
			end
		end
	function automatic signed [WAY_W - 1:0] sv2v_cast_19C97_signed;
		input reg signed [WAY_W - 1:0] inp;
		sv2v_cast_19C97_signed = inp;
	endfunction
	always_ff @(posedge clkInput)
		if (rstNInput && hitLocationTrainInner) begin
			hitLocationLineInner[hitLocationTrainIndexInner] <= requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 28];
			hitLocationWayInner[hitLocationTrainIndexInner] <= sv2v_cast_19C97_signed(hitWayInner);
		end
	function automatic [31:0] extract_returned_word;
		input reg [31:0] data;
		input reg [74:0] request;
		reg [31:0] shifted;
		begin
			shifted = data >> (sv2v_cast_32(request[42:41]) << 3);
			case (request[4-:2])
				2'd0: extract_returned_word = {24'b000000000000000000000000, shifted[7:0]};
				2'd1: extract_returned_word = {16'b0000000000000000, shifted[15:0]};
				default: extract_returned_word = shifted;
			endcase
		end
	endfunction
	function automatic signed [31:0] bytes_for_size;
		input reg [1:0] sizeInput;
		case (sizeInput)
			2'd0: bytes_for_size = 1;
			2'd1: bytes_for_size = 2;
			default: bytes_for_size = 4;
		endcase
	endfunction
	function automatic [31:0] victim_address;
		input reg signed [31:0] m;
		victim_address = {missesInner[m][TAG_W + (REQUEST_W + (WAY_W + 9))-:((TAG_W + (REQUEST_W + (WAY_W + 9))) >= (REQUEST_W + (WAY_W + 10)) ? ((TAG_W + (REQUEST_W + (WAY_W + 9))) - (REQUEST_W + (WAY_W + 10))) + 1 : ((REQUEST_W + (WAY_W + 10)) - (TAG_W + (REQUEST_W + (WAY_W + 9)))) + 1)], missesInner[m][(32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - 26+:INDEX_W], {OFFSET_W {1'b0}}};
	endfunction
	function automatic [31:0] extract_raw;
		input reg [rv32_pkg_DCACHE_LINE_BITS - 1:0] lineData;
		input reg [74:0] request;
		reg [rv32_pkg_DCACHE_LINE_BITS + 63:0] padded;
		reg [63:0] pair;
		reg [31:0] win;
		begin
			padded = {64'b0000000000000000000000000000000000000000000000000000000000000000, lineData};
			pair = padded[{request[45:43], 2'b00} * 8+:64];
			(* full_case, parallel_case *)
			case (request[42:41])
				2'd0: win = pair[31:0];
				2'd1: win = {pair[39:32], pair[31:8]};
				2'd2: win = {pair[47:32], pair[31:16]};
				default: win = {pair[55:32], pair[31:24]};
			endcase
			case (request[4-:2])
				2'd0: extract_raw = {24'b000000000000000000000000, win[7:0]};
				2'd1: extract_raw = {16'b0000000000000000, win[15:0]};
				default: extract_raw = win;
			endcase
		end
	endfunction
	function automatic [rv32_pkg_DCACHE_LINE_BITS - 1:0] sram_line;
		input reg signed [31:0] way;
		reg signed [31:0] b;
		for (b = 0; b < WORDS_PER_LINE; b = b + 1)
			sram_line[b * 32+:32] = dataRdataBankInner[way][b];
	endfunction
	function automatic signed [31:0] oldest_request;
		input reg [7:0] mask;
		reg prior;
		begin
			oldest_request = -1;
			begin : sv2v_autoblock_9
				reg signed [31:0] i;
				for (i = 0; i < REQUEST_DEPTH; i = i + 1)
					begin
						prior = 0;
						begin : sv2v_autoblock_10
							reg signed [31:0] j;
							for (j = 0; j < REQUEST_DEPTH; j = j + 1)
								if (mask[j] && olderInner[j][i])
									prior = 1;
						end
						if (mask[i] && !prior)
							oldest_request = i;
					end
			end
		end
	endfunction
	function automatic signed [7:0] sv2v_cast_D7F72_signed;
		input reg signed [7:0] inp;
		sv2v_cast_D7F72_signed = inp;
	endfunction
	function automatic [7:0] lookup_winner;
		input reg [7:0] mask;
		reg [7:0] eligible;
		reg prior;
		begin
			eligible = sv2v_cast_D7F72_signed(0);
			begin : sv2v_autoblock_11
				reg signed [31:0] row;
				for (row = 0; row < REQUEST_DEPTH; row = row + 1)
					begin
						prior = 1'b0;
						begin : sv2v_autoblock_12
							reg signed [31:0] peer;
							for (peer = 0; peer < REQUEST_DEPTH; peer = peer + 1)
								if (mask[peer] && olderInner[peer][row])
									prior = 1'b1;
						end
						if (mask[row] && !prior)
							eligible[row] = 1'b1;
					end
			end
			begin : sv2v_autoblock_13
				reg signed [31:0] row;
				for (row = 0; row < REQUEST_DEPTH; row = row + 1)
					lookup_winner[row] = eligible[row] && !(|(eligible >> (row + 1)));
			end
		end
	endfunction
	function automatic signed [2:0] sv2v_cast_87BE5_signed;
		input reg signed [2:0] inp;
		sv2v_cast_87BE5_signed = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic signed [31:0] lookup_index;
		input reg [7:0] winner;
		reg [2:0] indexBits;
		begin
			indexBits = sv2v_cast_87BE5_signed(0);
			begin : sv2v_autoblock_14
				reg signed [31:0] row;
				for (row = 0; row < REQUEST_DEPTH; row = row + 1)
					indexBits = indexBits | (sv2v_cast_87BE5_signed(row) & {REQUEST_W {winner[row]}});
			end
			lookup_index = (|winner ? sv2v_cast_32_signed(indexBits) : -1);
		end
	endfunction
	function automatic signed [31:0] oldest_miss;
		input reg [3:0] mask;
		reg [7:0] owners;
		reg signed [31:0] owner;
		reg prior;
		begin
			owners = 0;
			begin : sv2v_autoblock_15
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (mask[m])
						owners[missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]] = 1;
			end
			owner = -1;
			begin : sv2v_autoblock_16
				reg signed [31:0] i;
				for (i = 0; i < REQUEST_DEPTH; i = i + 1)
					begin
						prior = 0;
						begin : sv2v_autoblock_17
							reg signed [31:0] j;
							for (j = 0; j < REQUEST_DEPTH; j = j + 1)
								if (owners[j] && olderInner[j][i])
									prior = 1;
						end
						if (owners[i] && !prior)
							owner = i;
					end
			end
			oldest_miss = -1;
			begin : sv2v_autoblock_18
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (mask[m] && (sv2v_cast_32_signed(missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]) == owner))
						oldest_miss = m;
			end
		end
	endfunction
	function automatic set_locked;
		input reg [31:0] address;
		begin
			set_locked = 0;
			begin : sv2v_autoblock_19
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (missesInner[m][5] && (missesInner[m][(32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - 26+:INDEX_W] == address[OFFSET_W+:INDEX_W]))
						set_locked = 1;
			end
		end
	endfunction
	function automatic [5:0] sv2v_cast_71568;
		input reg [5:0] inp;
		sv2v_cast_71568 = inp;
	endfunction
	always @* begin : store_hazards
		storeHazardInner = 1'sb0;
		storeAllocationHazardInner = 1'sb0;
		begin : sv2v_autoblock_20
			reg signed [31:0] i;
			for (i = 0; i < REQUEST_DEPTH; i = i + 1)
				begin : sv2v_autoblock_21
					reg signed [31:0] s;
					for (s = 0; s < REQUEST_DEPTH; s = s + 1)
						if ((requestInner[s][3] && requestInner[s][(75 + (WAY_W + 6)) - 1]) && olderInner[s][i]) begin
							if (((requestInner[i][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 28] == requestInner[s][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 28]) && (sv2v_cast_71568(requestInner[i][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 33]) <= byteEndInner[s])) && (sv2v_cast_71568(requestInner[s][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 33]) <= byteEndInner[i]))
								storeHazardInner[i] = 1;
							if (requestInner[s][(75 + (WAY_W + 6)) - 28+:INDEX_W] == requestInner[i][(75 + (WAY_W + 6)) - 28+:INDEX_W])
								storeAllocationHazardInner[i] = 1;
						end
				end
		end
		storeAllocationHazardInner = storeAllocationHazardInner | storeHazardInner;
	end
	function automatic victim_hazard;
		input reg signed [31:0] miss;
		begin
			victim_hazard = 0;
			begin : sv2v_autoblock_22
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (((((m != miss) && missesInner[m][5]) && missesInner[m][4]) && !missesInner[m][1]) && ({missesInner[m][TAG_W + (REQUEST_W + (WAY_W + 9))-:((TAG_W + (REQUEST_W + (WAY_W + 9))) >= (REQUEST_W + (WAY_W + 10)) ? ((TAG_W + (REQUEST_W + (WAY_W + 9))) - (REQUEST_W + (WAY_W + 10))) + 1 : ((REQUEST_W + (WAY_W + 10)) - (TAG_W + (REQUEST_W + (WAY_W + 9)))) + 1)], missesInner[m][(32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - 26+:INDEX_W], {OFFSET_W {1'b0}}} == missesInner[miss][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]))
						victim_hazard = 1;
			end
		end
	endfunction
	function automatic [WAY_W - 1:0] sv2v_cast_19C97;
		input reg [WAY_W - 1:0] inp;
		sv2v_cast_19C97 = inp;
	endfunction
	function automatic [WAY_W - 1:0] select_victim;
		input reg [INDEX_W - 1:0] setIndex;
		reg found;
		reg sub;
		begin
			select_victim = 1'sb0;
			sub = 0;
			if (WAYS == 2)
				select_victim = sv2v_cast_19C97(!plruInner[setIndex][0]);
			if (WAYS == 4) begin
				sub = (plruInner[setIndex][2] ? plruInner[setIndex][1] : plruInner[setIndex][0]);
				select_victim = sv2v_cast_19C97({!plruInner[setIndex][2], !sub});
			end
			found = 0;
			begin : sv2v_autoblock_23
				reg signed [31:0] w;
				for (w = 0; w < WAYS; w = w + 1)
					if (!found && !validInner[setIndex][w]) begin
						select_victim = sv2v_cast_19C97_signed(w);
						found = 1;
					end
			end
		end
	endfunction
	function automatic [PLRU_W - 1:0] sv2v_cast_EBBC0;
		input reg [PLRU_W - 1:0] inp;
		sv2v_cast_EBBC0 = inp;
	endfunction
	function automatic [PLRU_W - 1:0] plru_touch;
		input reg [PLRU_W - 1:0] bitsInput;
		input reg [WAY_W - 1:0] wayInput;
		begin
			plru_touch = 1'sb0;
			if (WAYS == 2)
				plru_touch = sv2v_cast_EBBC0(wayInput[0]);
			if (WAYS == 4) begin
				if (wayInput[1])
					plru_touch = sv2v_cast_EBBC0({wayInput[1], bitsInput[1], wayInput[0]});
				else
					plru_touch = sv2v_cast_EBBC0({wayInput[1], wayInput[0], bitsInput[0]});
			end
		end
	endfunction
	function automatic [2:0] sv2v_cast_54DE4;
		input reg [2:0] inp;
		sv2v_cast_54DE4 = inp;
	endfunction
	assign readLookupRequestInner = {2'b00, sv2v_cast_32({{27 {1'b0}}, readLookupAddressInner}), 36'b000000000000000000000000000000000000, readLookupSizeInner, sv2v_cast_54DE4(1'sb0)};
	assign initializedOutput = rstNInput;
	assign cpuReqReadyOutput = rstNInput && (countInner < sv2v_cast_D4579_signed(REQUEST_DEPTH));
	assign acceptInner = cpuRequestInput[74] && cpuReqReadyOutput;
	reg queuedStoreInner;
	wire readEdgeAvailableInner;
	always @* begin
		queuedStoreInner = 1'b0;
		begin : sv2v_autoblock_24
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				queuedStoreInner = queuedStoreInner | ((requestInner[row][3] && requestInner[row][(75 + (WAY_W + 6)) - 1]) && ((requestInner[row][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 28] == cpuRequestInput[72:46]) || exitInner[row]));
		end
	end
	assign readEdgeAvailableInner = !readValidInner || (((hitWayInner >= 0) && !requestInner[readIndexInner][(75 + (WAY_W + 6)) - 1]) && (responseInner == sv2v_cast_32_signed(readIndexInner)));
	assign acceptLookupInner = (((((((acceptInner && !queuedStoreInner) && readEdgeAvailableInner) && (lookupInner < 0)) && !fillBeatInner) && (storeInner < 0)) && !cpuRequestInput[73]) && (cpuRequestInput[72-:32] != rv32_pkg_AXI_EXIT_ADDR)) && !set_locked(cpuRequestInput[72-:32]);
	function automatic signed [INDEX_W - 1:0] sv2v_cast_3C754_signed;
		input reg signed [INDEX_W - 1:0] inp;
		sv2v_cast_3C754_signed = inp;
	endfunction
	always @* begin : lookup_set
		reg [INDEX_W - 1:0] selectedSet;
		selectedSet = sv2v_cast_3C754_signed(0);
		begin : sv2v_autoblock_25
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				selectedSet = selectedSet | (set_of(requestInner[row][(75 + (WAY_W + 6)) - 2-:32]) & {INDEX_W {lookupWinnerInner[row]}});
		end
		lookupAddressInner = (|lookupWinnerInner ? selectedSet : set_of(cpuRequestInput[72-:32]));
	end
	assign idleOutput = ((rstNInput && (countInner == 0)) && !readValidInner) && !prefetchPendingInner;
	wire [WAYS - 1:0] readHitWayInner;
	genvar _gv_hw_1;
	generate
		for (_gv_hw_1 = 0; _gv_hw_1 < WAYS; _gv_hw_1 = _gv_hw_1 + 1) begin : g_read_compare_way
			localparam hw = _gv_hw_1;
			wire [7:0] rowMatches;
			genvar _gv_hr_1;
			for (_gv_hr_1 = 0; _gv_hr_1 < REQUEST_DEPTH; _gv_hr_1 = _gv_hr_1 + 1) begin : g_read_compare_row
				localparam hr = _gv_hr_1;
				assign rowMatches[hr] = (readIndexInner == sv2v_cast_87BE5_signed(hr)) && (metaRdataInner[hw][TAG_W - 1:0] == requestInner[hr][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - (74 - (41 + (OFFSET_W + INDEX_W)))]);
			end
			assign readHitWayInner[hw] = (readValidInner && readWayMaskInner[hw]) && |rowMatches;
		end
	endgenerate
	always @* begin : allocate_request
		reg signed [31:0] slot;
		allocationInner = -1;
		begin : sv2v_autoblock_26
			reg signed [31:0] i;
			for (i = 0; i < REQUEST_DEPTH; i = i + 1)
				begin
					slot = (sv2v_cast_32_signed(cursorInner) + i) & 7;
					if (((acceptInner || prefetchEnqueueInner) && (allocationInner < 0)) && !requestInner[slot][3])
						allocationInner = slot;
				end
		end
	end
	genvar _gv_miss_1;
	generate
		for (_gv_miss_1 = 0; _gv_miss_1 < MSHR_DEPTH; _gv_miss_1 = _gv_miss_1 + 1) begin : gen_fill_response
			localparam miss = _gv_miss_1;
			assign fillCanRespondInner[miss] = (!requestInner[missesInner[miss][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][(75 + (WAY_W + 6)) - 1] && !missesInner[miss][0]) && !requestInner[missesInner[miss][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][0];
			assign fillTransactionInner[miss] = requestInner[missesInner[miss][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][(75 + (WAY_W + 6)) - 72-:rv32_pkg_DATA_TRANSACTION_W];
		end
	endgenerate
	function automatic signed [3:0] sv2v_cast_4384E_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4384E_signed = inp;
	endfunction
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	always @* begin : plan
		reg [7:0] candidates;
		reg [7:0] lookupActive;
		reg [3:0] readable;
		reg [3:0] writable;
		reg anyMiss;
		reg continueHit;
		reg responsePrior;
		reg signed [31:0] id;
		reg signed [31:0] owner;
		reg signed [31:0] lookupFirst;
		activeInner = 0;
		freeMissInner = -1;
		hitWayInner = -1;
		anyMiss = 0;
		begin : sv2v_autoblock_27
			reg signed [31:0] i;
			for (i = 0; i < REQUEST_DEPTH; i = i + 1)
				activeInner[i] = requestInner[i][3];
		end
		begin : sv2v_autoblock_28
			reg signed [31:0] m;
			for (m = 0; m < MSHR_DEPTH; m = m + 1)
				begin
					if ((freeMissInner < 0) && !missesInner[m][5])
						freeMissInner = m;
					anyMiss = anyMiss || missesInner[m][5];
				end
		end
		firstInner = oldest_request(activeInner & ~prefetchMaskInner);
		storeHintMatchInner = 1'b0;
		storeHintWayInner = 1'sb0;
		begin : sv2v_autoblock_29
			reg signed [31:0] h;
			for (h = 0; h < STORE_LOCATION_ENTRIES; h = h + 1)
				if (((firstInner >= 0) && hitLocationValidInner[h]) && (hitLocationLineInner[h] == requestInner[firstInner][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 28])) begin
					storeHintMatchInner = 1'b1;
					storeHintWayInner = hitLocationWayInner[h];
				end
		end
		exitValidOutput = (((rstNInput && (firstInner >= 0)) && requestInner[firstInner][(75 + (WAY_W + 6)) - 1]) && exitInner[firstInner]) && exitReadyInput;
		exitValueOutput = (firstInner >= 0 ? requestInner[firstInner][(75 + (WAY_W + 6)) - 34-:32] : 32'b00000000000000000000000000000000);
		begin : sv2v_autoblock_30
			reg signed [31:0] w;
			for (w = 0; w < WAYS; w = w + 1)
				if ((hitWayInner < 0) && readHitWayInner[w])
					hitWayInner = w;
		end
		victimWayInner = select_victim(set_of(requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2-:32]));
		readHitRawInner = extract_raw(sram_line((hitWayInner >= 0 ? hitWayInner : 0)), readLookupRequestInner);
		writeAckInner = -1;
		id = sv2v_cast_32_signed(memWriteResponseInput[1-:2]);
		if (((((memWriteResponseInput[34] && missesInner[id][5]) && missesInner[id][4]) && missesInner[id][2]) && !missesInner[id][1]) && (victim_address(id) == memWriteResponseInput[33-:32]))
			writeAckInner = id;
		fillMissInner = -1;
		fillBeatInner = 0;
		fillFireInner = 0;
		id = sv2v_cast_32_signed(memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]);
		if ((((memResponseInput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)] && missesInner[id][5]) && missesInner[id][3]) && (missesInner[id][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)] == memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 33-:((rv32_pkg_DCACHE_LINE_BITS + 33) >= (2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((rv32_pkg_DCACHE_LINE_BITS + 33) - (2 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (rv32_pkg_DCACHE_LINE_BITS + 33)) + 1)])) && ((!missesInner[id][4] || missesInner[id][1]) || (writeAckInner == id))) begin
			fillMissInner = id;
			fillBeatInner = rstNInput;
			fillFireInner = rstNInput && (missesInner[id][9-:4] == sv2v_cast_4384E_signed(WORDS_PER_LINE - FILL_WORDS_PER_BEAT));
		end
		memRspReadyOutput = fillFireInner;
		memWriteRspReadyOutput = rstNInput && (writeAckInner >= 0);
		owner = (fillMissInner >= 0 ? sv2v_cast_32_signed(missesInner[fillMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]) : 0);
		firstFillInner = fillBeatInner && (missesInner[fillMissInner][9-:4] == 0);
		earlyInner = fillBeatInner && fillCanRespondInner[memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]];
		wordReturnInner = ((((((((((((EARLY_WORD_RETURN && rstNInput) && memWordResponseInput[66]) && !earlyInner) && missesInner[wordMissInner][5]) && missesInner[wordMissInner][3]) && !missesInner[wordMissInner][0]) && requestInner[wordOwnerInner][3]) && !requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 1]) && !requestInner[wordOwnerInner][0]) && !storeHazardInner[wordOwnerInner]) && (memWordResponseInput[65:39] == missesInner[wordMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9))):(32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - 26])) && (memWordResponseInput[38:36] == requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 31])) && ((sv2v_cast_32_signed(requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 32:(75 + (WAY_W + 6)) - 33]) + bytes_for_size(requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 70-:2])) <= 4);
		wordCaptureValidInner = (((((EARLY_WORD_RETURN && rstNInput) && memWordResponseInput[66]) && missesInner[wordMissInner][5]) && missesInner[wordMissInner][3]) && !requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 1]) && (memWordResponseInput[65:39] == missesInner[wordMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9))):(32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - 26]);
		wordCaptureInner = 1'sb0;
		begin : sv2v_autoblock_31
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				wordCaptureInner[row] = (((((((wordCaptureValidInner && (sv2v_cast_87BE5_signed(row) != wordOwnerInner)) && requestInner[row][3]) && !requestInner[row][0]) && !requestInner[row][2]) && !requestInner[row][(75 + (WAY_W + 6)) - 1]) && !storeAllocationHazardInner[row]) && (requestInner[row][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - 31] == memWordResponseInput[65:36])) && ((sv2v_cast_32_signed(requestInner[row][(75 + (WAY_W + 6)) - 32:(75 + (WAY_W + 6)) - 33]) + bytes_for_size(requestInner[row][(75 + (WAY_W + 6)) - 70-:2])) <= 4);
		end
		normalBufferedMaskInner = 1'sb0;
		begin : sv2v_autoblock_32
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				if ((((requestInner[row][3] && !requestInner[row][0]) && !requestInner[row][(75 + (WAY_W + 6)) - 1]) && !storeHazardInner[row]) && requestInner[row][2])
					normalBufferedMaskInner[row] = 1'b1;
		end
		normalBufferedWinnerInner = 1'sb0;
		normalHitEligibleInner = 1'sb0;
		responsePrior = 1'b0;
		begin : sv2v_autoblock_33
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				begin
					responsePrior = 1'b0;
					begin : sv2v_autoblock_34
						reg signed [31:0] peer;
						for (peer = 0; peer < REQUEST_DEPTH; peer = peer + 1)
							if (normalBufferedMaskInner[peer] && olderInner[peer][row])
								responsePrior = 1'b1;
					end
					normalBufferedWinnerInner[row] = normalBufferedMaskInner[row] && !responsePrior;
					normalHitEligibleInner[row] = (((((readValidInner && (readIndexInner == sv2v_cast_87BE5_signed(row))) && requestInner[row][3]) && !requestInner[row][0]) && !requestInner[row][(75 + (WAY_W + 6)) - 1]) && !storeHazardInner[row]) && !responsePrior;
				end
		end
		normalHitWinsInner = (hitWayInner >= 0) && |normalHitEligibleInner;
		normalWinnerInner = (normalHitWinsInner ? normalHitEligibleInner : normalBufferedWinnerInner);
		normalResponseInner = -1;
		bufferedTransactionInner = 1'sb0;
		hitTransactionInner = 1'sb0;
		normalReadDataInner = 1'sb0;
		begin : sv2v_autoblock_35
			reg signed [31:0] row;
			for (row = 0; row < REQUEST_DEPTH; row = row + 1)
				begin
					if (normalWinnerInner[row])
						normalResponseInner = row;
					bufferedTransactionInner = bufferedTransactionInner | (requestInner[row][(75 + (WAY_W + 6)) - 72-:rv32_pkg_DATA_TRANSACTION_W] & {rv32_pkg_DATA_TRANSACTION_W {normalBufferedWinnerInner[row]}});
					hitTransactionInner = hitTransactionInner | (requestInner[row][(75 + (WAY_W + 6)) - 72-:rv32_pkg_DATA_TRANSACTION_W] & {rv32_pkg_DATA_TRANSACTION_W {normalHitEligibleInner[row]}});
					normalReadDataInner = normalReadDataInner | (rawInner[row] & {32 {normalBufferedWinnerInner[row]}});
				end
		end
		normalTransactionInner = (normalHitWinsInner ? hitTransactionInner : bufferedTransactionInner);
		responseInner = (earlyInner ? owner : (wordReturnInner ? sv2v_cast_32_signed(wordOwnerInner) : normalResponseInner));
		cpuResponseOutput = 1'sb0;
		if ((earlyInner || wordReturnInner) || |normalWinnerInner) begin
			cpuResponseOutput[35] = rstNInput;
			cpuResponseOutput[2-:rv32_pkg_DATA_TRANSACTION_W] = (earlyInner ? fillTransactionInner[memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]] : (wordReturnInner ? requestInner[wordOwnerInner][(75 + (WAY_W + 6)) - 72-:rv32_pkg_DATA_TRANSACTION_W] : normalTransactionInner));
			if (earlyInner)
				cpuResponseOutput[34-:32] = extract_raw(memResponseInput[rv32_pkg_DCACHE_LINE_BITS - 1-:rv32_pkg_DCACHE_LINE_BITS], requestInner[missesInner[memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][75 + (WAY_W + 6)-:((75 + (WAY_W + 6)) >= (WAY_W + 7) ? ((75 + (WAY_W + 6)) - (WAY_W + 7)) + 1 : ((WAY_W + 7) - (75 + (WAY_W + 6))) + 1)]);
			else if (wordReturnInner)
				cpuResponseOutput[34-:32] = wordRawInner;
			else if (normalHitWinsInner)
				cpuResponseOutput[34-:32] = readHitRawInner;
			else
				cpuResponseOutput[34-:32] = normalReadDataInner;
		end
		storeHintFireInner = (((((((((rstNInput && !fillBeatInner) && (firstInner >= 0)) && requestInner[firstInner][(75 + (WAY_W + 6)) - 1]) && !exitInner[firstInner]) && !requestInner[firstInner][2]) && !requestInner[firstInner][4]) && !requestInner[firstInner][1]) && storeHintMatchInner) && !set_locked(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32])) && (!readValidInner || (((hitWayInner >= 0) && !requestInner[readIndexInner][(75 + (WAY_W + 6)) - 1]) && (responseInner == sv2v_cast_32_signed(readIndexInner))));
		storeInner = -1;
		if ((((!fillBeatInner && (firstInner >= 0)) && requestInner[firstInner][(75 + (WAY_W + 6)) - 1]) && !set_locked(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32])) && ((storeHintFireInner || requestInner[firstInner][2]) || ((readValidInner && (sv2v_cast_32_signed(readIndexInner) == firstInner)) && (hitWayInner >= 0))))
			storeInner = firstInner;
		allocateMissInner = -1;
		if (((((readValidInner && (hitWayInner < 0)) && !prefetchAbortInner[readIndexInner]) && !storeAllocationHazardInner[readIndexInner]) && (find_miss(line_of(requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2-:32])) < 0)) && !set_locked(requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2-:32]))
			allocateMissInner = freeMissInner;
		candidates = 0;
		begin : sv2v_autoblock_36
			reg signed [31:0] i;
			for (i = 0; i < REQUEST_DEPTH; i = i + 1)
				begin
					id = find_miss(line_of(requestInner[i][(75 + (WAY_W + 6)) - 2-:32]));
					if (((((((((((!readValidInner && requestInner[i][3]) && !requestInner[i][2]) && !requestInner[i][4]) && !requestInner[i][0]) && !requestInner[i][(75 + (WAY_W + 6)) - 1]) && !storeAllocationHazardInner[i]) && (id >= 0)) && !requestInner[missesInner[id][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][(75 + (WAY_W + 6)) - 1]) && (missesInner[id][9-:4] == 0)) && !missesInner[id][0]) && (fillMissInner != id))
						candidates[i] = 1;
				end
		end
		mergeSlotInner = oldest_request(candidates);
		mergeMissInner = (mergeSlotInner >= 0 ? find_miss(line_of(requestInner[mergeSlotInner][(75 + (WAY_W + 6)) - 2-:32])) : -1);
		continueHit = (((readValidInner && (hitWayInner >= 0)) && !fillBeatInner) && !requestInner[readIndexInner][(75 + (WAY_W + 6)) - 1]) && (responseInner == sv2v_cast_32_signed(readIndexInner));
		lookupActive = activeInner;
		if (normalResponseInner >= 0)
			lookupActive[normalResponseInner] = 1'b0;
		lookupFirst = oldest_request(lookupActive & ~prefetchMaskInner);
		candidates = 0;
		begin : sv2v_autoblock_37
			reg signed [31:0] i;
			for (i = 0; i < REQUEST_DEPTH; i = i + 1)
				if (((((((((((requestInner[i][3] && !(readValidInner && (sv2v_cast_32_signed(readIndexInner) == i))) && !requestInner[i][2]) && !requestInner[i][4]) && (i != mergeSlotInner)) && !exitInner[i]) && (!requestInner[i][(75 + (WAY_W + 6)) - 1] || !set_locked(requestInner[i][(75 + (WAY_W + 6)) - 2-:32]))) && !storeHazardInner[i]) && (find_miss(line_of(requestInner[i][(75 + (WAY_W + 6)) - 2-:32])) < 0)) && (!requestInner[i][(75 + (WAY_W + 6)) - 1] || (i == firstInner))) && (!requestInner[i][1] || (((i == firstInner) && (freeMissInner >= 0)) && !set_locked(requestInner[i][(75 + (WAY_W + 6)) - 2-:32])))) && (((anyMiss || (i == firstInner)) || (i == lookupFirst)) || requestInner[i][0]))
					candidates[i] = 1;
		end
		demandLookupMaskInner = candidates & ~prefetchMaskInner;
		if (|demandLookupMaskInner)
			lookupWinnerInner = lookup_winner(demandLookupMaskInner);
		else begin
			lookupWinnerInner = 1'sb0;
			if (!cpuRequestInput[74])
				lookupWinnerInner = (candidates & prefetchMaskInner) & ~prefetchAbortInner;
		end
		lookupCandidateInner = lookup_index(lookupWinnerInner);
		lookupInner = (((!readValidInner || continueHit) && !fillBeatInner) && (storeInner < 0) ? lookupCandidateInner : -1);
		readable = 0;
		writable = 0;
		begin : sv2v_autoblock_38
			reg signed [31:0] m;
			for (m = 0; m < MSHR_DEPTH; m = m + 1)
				if (missesInner[m][5]) begin
					if ((!missesInner[m][3] && !victim_hazard(m)) && !storeAllocationHazardInner[missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]])
						readable[m] = 1;
					if (missesInner[m][4] && !missesInner[m][2])
						writable[m] = 1;
				end
		end
		begin : sv2v_autoblock_39
			reg [3:0] demandReadable;
			demandReadable = 1'sb0;
			begin : sv2v_autoblock_40
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					demandReadable[m] = readable[m] && !requestInner[missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][0];
			end
			if (|demandReadable)
				readable = demandReadable;
		end
		readMissInner = oldest_miss(readable);
		writeMissInner = oldest_miss(writable);
		memRequestOutput = 1'sb0;
		if (readMissInner >= 0) begin
			memRequestOutput[71 + (rv32_pkg_DCACHE_LINE_BITS + 1)] = rstNInput;
			memRequestOutput[70 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((70 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (40 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((70 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (40 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((40 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (70 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)] = missesInner[readMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)];
			memRequestOutput[38 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)] = sv2v_cast_2_signed(readMissInner);
			memRequestOutput[36 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((36 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (35 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((36 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (35 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((35 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (36 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)] = (EARLY_WORD_RETURN ? requestInner[missesInner[readMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 31] : {((36 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (35 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((36 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (35 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((35 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (36 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1) * 1 {1'sb0}});
		end
		if (writeMissInner >= 0) begin
			memRequestOutput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)] = rstNInput;
			memRequestOutput[rv32_pkg_DCACHE_LINE_BITS + 33-:((rv32_pkg_DCACHE_LINE_BITS + 33) >= (2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((rv32_pkg_DCACHE_LINE_BITS + 33) - (2 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (rv32_pkg_DCACHE_LINE_BITS + 33)) + 1)] = victim_address(writeMissInner);
			memRequestOutput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)] = sv2v_cast_2_signed(writeMissInner);
			memRequestOutput[rv32_pkg_DCACHE_LINE_BITS - 1-:rv32_pkg_DCACHE_LINE_BITS] = victimPayloadInner[writeMissInner];
		end
		releasedInner = prefetchAbortInner;
		if ((readValidInner && requestInner[readIndexInner][0]) && (hitWayInner >= 0))
			releasedInner[readIndexInner] = 1'b1;
		if (((responseInner >= 0) && !wordReturnInner) && (!fillBeatInner || (responseInner != owner)))
			releasedInner[responseInner] = 1;
		if (storeInner >= 0)
			releasedInner[storeInner] = 1;
		if (fillFireInner)
			releasedInner[owner] = 1;
		if (exitValidOutput)
			releasedInner[firstInner] = 1;
	end
	assign responsePreviewTransactionOutput = {bufferedTransactionInner, hitTransactionInner};
	assign responsePreviewSelectOutput = {(((rstNInput && !earlyInner) && !wordReturnInner) && !normalHitWinsInner) && |normalBufferedWinnerInner, ((rstNInput && !earlyInner) && !wordReturnInner) && normalHitWinsInner};
`ifndef SYNTHESIS
	always @* begin
		assert ($onehot0(responsePreviewSelectOutput)) else $fatal(1, "DCache response previews not onehot0");
		if (cpuResponseOutput[35])
			assert ((!responsePreviewSelectOutput[0] || (responsePreviewTransactionOutput[0+:rv32_pkg_DATA_TRANSACTION_W] == cpuResponseOutput[2-:rv32_pkg_DATA_TRANSACTION_W])) && (!responsePreviewSelectOutput[1] || (responsePreviewTransactionOutput[rv32_pkg_DATA_TRANSACTION_W+:rv32_pkg_DATA_TRANSACTION_W] == cpuResponseOutput[2-:rv32_pkg_DATA_TRANSACTION_W]))) else $fatal(1, "DCache response preview actual grant contract");
	end
`endif
	reg [INDEX_W - 1:0] fillWriteAddressInner;
	reg [INDEX_W - 1:0] storeWriteAddressInner;
	always @* begin : prepare_bank_parallel_addresses
		fillWriteAddressInner = {INDEX_W {1'b0}};
		storeWriteAddressInner = {INDEX_W {1'b0}};
		if (rstNInput && fillBeatInner)
			fillWriteAddressInner = set_of(missesInner[fillMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]);
		if ((rstNInput && !fillBeatInner) && (storeInner >= 0))
			storeWriteAddressInner = set_of(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32]);
	end
	genvar _gv_addressWay_1;
	generate
		for (_gv_addressWay_1 = 0; _gv_addressWay_1 < WAYS; _gv_addressWay_1 = _gv_addressWay_1 + 1) begin : g_mask_address_way
			localparam addressWay = _gv_addressWay_1;
			genvar _gv_addressBank_1;
			for (_gv_addressBank_1 = 0; _gv_addressBank_1 < WORDS_PER_LINE; _gv_addressBank_1 = _gv_addressBank_1 + 1) begin : g_mask_address_bank
				localparam addressBank = _gv_addressBank_1;
				assign dataAddressBankInner[addressWay][addressBank] = ((lookupAddressInner & {INDEX_W {!dataWriteBankInner[addressWay][addressBank]}}) | (fillWriteAddressInner & {INDEX_W {dataWriteBankInner[addressWay][addressBank]}})) | (storeWriteAddressInner & {INDEX_W {dataWriteBankInner[addressWay][addressBank]}});
			end
		end
	endgenerate
	always @* begin : sram_ports
		reg signed [31:0] way;
		reg signed [31:0] owner;
		reg signed [31:0] globalByte;
		metaWdataInner = 1'sb0;
		way = 0;
		owner = 0;
		globalByte = 0;
		begin : sv2v_autoblock_41
			reg signed [31:0] w;
			for (w = 0; w < WAYS; w = w + 1)
				begin
					metaEnableInner[w] = 0;
					metaWriteInner[w] = 0;
					metaAddressInner[w] = lookupAddressInner;
					begin : sv2v_autoblock_42
						reg signed [31:0] b;
						for (b = 0; b < WORDS_PER_LINE; b = b + 1)
							begin
								dataEnableBankInner[w][b] = 0;
								dataWriteBankInner[w][b] = 0;
								dataMaskBankInner[w][b] = 0;
								dataWdataBankInner[w][b] = 0;
							end
					end
				end
		end
		if (rstNInput && fillBeatInner) begin
			way = sv2v_cast_32_signed(missesInner[fillMissInner][WAY_W + 9-:((WAY_W + 9) >= 10 ? WAY_W : 11 - (WAY_W + 9))]);
			owner = sv2v_cast_32_signed(missesInner[fillMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]);
			begin : sv2v_autoblock_43
				reg signed [31:0] b;
				for (b = 0; b < WORDS_PER_LINE; b = b + 1)
					if ((b >= sv2v_cast_32_signed(missesInner[fillMissInner][9-:4])) && (b < (sv2v_cast_32_signed(missesInner[fillMissInner][9-:4]) + FILL_WORDS_PER_BEAT))) begin
						dataEnableBankInner[way][b] = 1;
						dataWriteBankInner[way][b] = 1;
						dataMaskBankInner[way][b] = 1'sb1;
						dataWdataBankInner[way][b] = memResponseInput[(rv32_pkg_DCACHE_LINE_BITS - 1) - ((rv32_pkg_DCACHE_LINE_BITS - 1) - (b * 32))+:32];
						begin : sv2v_autoblock_44
							reg signed [31:0] i;
							for (i = 0; i < 4; i = i + 1)
								begin
									globalByte = sv2v_cast_32_signed(requestInner[owner][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 33]) + i;
									if (((requestInner[owner][(75 + (WAY_W + 6)) - 1] && (i < bytes_for_size(requestInner[owner][(75 + (WAY_W + 6)) - 70-:2]))) && requestInner[owner][(75 + (WAY_W + 6)) - (74 - (5 + i))]) && ((globalByte >> 2) == b))
										dataWdataBankInner[way][b][(globalByte & 3) * 8+:8] = requestInner[owner][(75 + (WAY_W + 6)) - (74 - (9 + (i * 8)))+:8];
								end
						end
					end
			end
			if (fillFireInner) begin
				metaEnableInner[way] = 1;
				metaWriteInner[way] = 1;
				metaAddressInner[way] = set_of(missesInner[fillMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]);
				metaWdataInner = {requestInner[owner][(75 + (WAY_W + 6)) - 1], missesInner[fillMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9))):(32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (31 - (OFFSET_W + INDEX_W))]};
			end
		end
		else if (rstNInput && (storeInner >= 0)) begin
			way = (storeHintFireInner ? sv2v_cast_32_signed(storeHintWayInner) : ((readValidInner && (sv2v_cast_32_signed(readIndexInner) == firstInner)) && (hitWayInner >= 0) ? hitWayInner : sv2v_cast_32_signed(requestInner[firstInner][WAY_W + 6-:((WAY_W + 6) >= 7 ? WAY_W + 0 : 8 - (WAY_W + 6))])));
			begin : sv2v_autoblock_45
				reg signed [31:0] i;
				for (i = 0; i < 4; i = i + 1)
					begin
						globalByte = sv2v_cast_32_signed(requestInner[firstInner][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 33]) + i;
						if ((i < bytes_for_size(requestInner[firstInner][(75 + (WAY_W + 6)) - 70-:2])) && requestInner[firstInner][(75 + (WAY_W + 6)) - (74 - (5 + i))]) begin
							dataEnableBankInner[way][globalByte >> 2] = 1;
							dataWriteBankInner[way][globalByte >> 2] = 1;
							dataMaskBankInner[way][globalByte >> 2][globalByte & 3] = 1;
							dataWdataBankInner[way][globalByte >> 2][(globalByte & 3) * 8+:8] = requestInner[firstInner][(75 + (WAY_W + 6)) - (74 - (9 + (i * 8)))+:8];
						end
					end
			end
			metaEnableInner[way] = 1;
			metaWriteInner[way] = 1;
			metaAddressInner[way] = set_of(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32]);
			metaWdataInner = {1'b1, requestInner[firstInner][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - (74 - (41 + (OFFSET_W + INDEX_W)))]};
		end
		else if (rstNInput && ((lookupInner >= 0) || acceptLookupInner)) begin : sv2v_autoblock_46
			reg signed [31:0] w;
			for (w = 0; w < WAYS; w = w + 1)
				begin
					metaEnableInner[w] = 1;
					begin : sv2v_autoblock_47
						reg signed [31:0] b;
						for (b = 0; b < WORDS_PER_LINE; b = b + 1)
							dataEnableBankInner[w][b] = 1;
					end
				end
		end
	end
	genvar _gv_w_1;
	generate
		for (_gv_w_1 = 0; _gv_w_1 < WAYS; _gv_w_1 = _gv_w_1 + 1) begin : g_way
			localparam w = _gv_w_1;
			genvar _gv_b_1;
			for (_gv_b_1 = 0; _gv_b_1 < WORDS_PER_LINE; _gv_b_1 = _gv_b_1 + 1) begin : g_data_bank
				localparam b = _gv_b_1;
				sram_fakeram #(
					.DEPTH(SETS),
					.WIDTH(32),
					.WRITE_GRANULARITY(8)
				) u_data(
					.clk(clkInput),
					.en(dataEnableBankInner[w][b]),
					.we(dataWriteBankInner[w][b]),
					.addr(dataAddressBankInner[w][b]),
					.wdata(dataWdataBankInner[w][b]),
					.wmask(dataMaskBankInner[w][b]),
					.rdata(dataRdataBankInner[w][b])
				);
`ifndef SYNTHESIS
				always @(posedge clkInput)
					if (rstNInput && dataEnableBankInner[w][b])
						assert (dataAddressBankInner[w][b] == sramAddressInner) else $fatal(1, "DCache local data address disagrees with grant");
`endif
			end
			sram_fakeram #(
				.DEPTH(SETS),
				.WIDTH(META_W),
				.WRITE_GRANULARITY(META_W)
			) u_metadata(
				.clk(clkInput),
				.en(metaEnableInner[w]),
				.we(metaWriteInner[w]),
				.addr(metaAddressInner[w]),
				.wdata(metaWdataInner),
				.wmask(1'b1),
				.rdata(metaRdataInner[w])
			);
`ifndef SYNTHESIS
			always @(posedge clkInput)
				if (rstNInput && metaEnableInner[w])
					assert (metaAddressInner[w] == sramAddressInner) else $fatal(1, "DCache local metadata address disagrees with grant");
`endif
		end
	endgenerate
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	generate
		if (SETS == 128) begin : g_read_mask_banks
			reg [WAYS - 1:0] readWayMaskLowInner;
			reg [WAYS - 1:0] readWayMaskHighInner;
			reg readWayMaskSetHiInner;
			wire [WAYS:1] sv2v_tmp_34EE2;
			assign sv2v_tmp_34EE2 = (readWayMaskSetHiInner ? readWayMaskHighInner : readWayMaskLowInner);
			always @(*) readWayMaskInner = sv2v_tmp_34EE2;
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput) begin
					readWayMaskLowInner <= {WAYS {1'b0}};
					readWayMaskHighInner <= {WAYS {1'b0}};
					readWayMaskSetHiInner <= 1'b0;
				end
				else if (acceptLookupInner) begin
					begin : sv2v_autoblock_48
						reg signed [31:0] w;
						for (w = 0; w < WAYS; w = w + 1)
							begin
								readWayMaskLowInner[w] <= validInner[{1'b0, sv2v_cast_6(set_of(cpuRequestInput[72-:32]))}][w];
								readWayMaskHighInner[w] <= validInner[{1'b1, sv2v_cast_6(set_of(cpuRequestInput[72-:32]))}][w];
							end
					end
					readWayMaskSetHiInner <= cpuRequestInput[52];
				end
				else if (lookupCandidateInner >= 0) begin
					begin : sv2v_autoblock_49
						reg signed [31:0] w;
						for (w = 0; w < WAYS; w = w + 1)
							begin
								readWayMaskLowInner[w] <= validInner[{1'b0, sv2v_cast_6(set_of(requestInner[lookupCandidateInner][(75 + (WAY_W + 6)) - 2-:32]))}][w];
								readWayMaskHighInner[w] <= validInner[{1'b1, sv2v_cast_6(set_of(requestInner[lookupCandidateInner][(75 + (WAY_W + 6)) - 2-:32]))}][w];
							end
					end
					readWayMaskSetHiInner <= requestInner[lookupCandidateInner][(75 + (WAY_W + 6)) - 22];
				end
		end
		else begin : g_read_mask_original
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					readWayMaskInner <= 0;
				else if (acceptLookupInner) begin : sv2v_autoblock_50
					reg signed [31:0] w;
					for (w = 0; w < WAYS; w = w + 1)
						readWayMaskInner[w] <= validInner[set_of(cpuRequestInput[72-:32])][w];
				end
				else if (lookupInner >= 0) begin : sv2v_autoblock_51
					reg signed [31:0] w;
					for (w = 0; w < WAYS; w = w + 1)
						readWayMaskInner[w] <= validInner[set_of(requestInner[lookupInner][(75 + (WAY_W + 6)) - 2-:32])][w];
				end
		end
	endgenerate
	function automatic [74:0] sv2v_cast_9E2A1;
		input reg [74:0] inp;
		sv2v_cast_9E2A1 = inp;
	endfunction
	function automatic signed [5:0] sv2v_cast_71568_signed;
		input reg signed [5:0] inp;
		sv2v_cast_71568_signed = inp;
	endfunction
	function automatic signed [TAG_W - 1:0] sv2v_cast_2861A_signed;
		input reg signed [TAG_W - 1:0] inp;
		sv2v_cast_2861A_signed = inp;
	endfunction
	function automatic [TAG_W - 1:0] sv2v_cast_2861A;
		input reg [TAG_W - 1:0] inp;
		sv2v_cast_2861A = inp;
	endfunction
	function automatic [2:0] sv2v_cast_87BE5;
		input reg [2:0] inp;
		sv2v_cast_87BE5 = inp;
	endfunction
	function automatic [3:0] sv2v_cast_F2D56;
		input reg [3:0] inp;
		sv2v_cast_F2D56 = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			countInner <= 0;
			cursorInner <= 0;
			readIndexInner <= 0;
			readValidInner <= 0;
			readLookupAddressInner <= 1'sb0;
			readLookupSizeInner <= 1'sb0;
			begin : sv2v_autoblock_52
				reg signed [31:0] i;
				for (i = 0; i < REQUEST_DEPTH; i = i + 1)
					begin
						requestInner[i] <= 1'sb0;
						olderInner[i] <= 0;
						byteEndInner[i] <= 1'sb0;
						exitInner[i] <= 1'b0;
					end
			end
			begin : sv2v_autoblock_53
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					missesInner[m] <= 1'sb0;
			end
			begin : sv2v_autoblock_54
				reg signed [31:0] s;
				for (s = 0; s < SETS; s = s + 1)
					begin
						plruInner[s] <= 0;
						begin : sv2v_autoblock_55
							reg signed [31:0] w;
							for (w = 0; w < WAYS; w = w + 1)
								validInner[s][w] <= 0;
						end
					end
			end
		end
		else begin
			countInner <= 32'sd4'(((sv2v_cast_32_signed(countInner) + sv2v_cast_32_signed(acceptInner)) + sv2v_cast_32_signed(prefetchEnqueueInner)) - $countones(releasedInner));
			if (allocationInner >= 0)
				cursorInner <= sv2v_cast_87BE5_signed(allocationInner + 1);
			readValidInner <= (lookupInner >= 0) || acceptLookupInner;
			if (acceptLookupInner) begin
				readIndexInner <= sv2v_cast_87BE5_signed(allocationInner);
				readLookupAddressInner <= cpuRequestInput[45:41];
				readLookupSizeInner <= cpuRequestInput[4-:2];
			end
			else if (lookupInner >= 0) begin
				readIndexInner <= sv2v_cast_87BE5_signed(lookupInner);
				readLookupAddressInner <= requestInner[sv2v_cast_87BE5_signed(lookupCandidateInner)][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 33];
				readLookupSizeInner <= requestInner[sv2v_cast_87BE5_signed(lookupCandidateInner)][(75 + (WAY_W + 6)) - 70-:2];
			end
			begin : sv2v_autoblock_56
				reg signed [31:0] i;
				for (i = 0; i < REQUEST_DEPTH; i = i + 1)
					begin
						if (i == allocationInner) begin
							requestInner[i] <= {sv2v_cast_9E2A1((prefetchEnqueueInner ? sv2v_cast_9E2A1({2'b10, prefetchTargetInner, 38'h0000000002, sv2v_cast_54DE4(1'sb0)}) : cpuRequestInput)), sv2v_cast_19C97(1'sb0), 6'b000100, prefetchEnqueueInner};
							byteEndInner[i] <= sv2v_cast_71568(cpuRequestInput[45:41]) + sv2v_cast_71568_signed(bytes_for_size(cpuRequestInput[4-:2]) - 1);
							exitInner[i] <= !prefetchEnqueueInner && (cpuRequestInput[72-:32] == rv32_pkg_AXI_EXIT_ADDR);
						end
						else begin
							requestInner[i][3] <= requestInner[i][3] && !releasedInner[i];
							if (releasedInner[i]) begin
								requestInner[i][2] <= 0;
								requestInner[i][1] <= 0;
								requestInner[i][4] <= 0;
							end
							else if (requestInner[i][3]) begin
								if (wordCaptureInner[i]) begin
									requestInner[i][2] <= 1;
									requestInner[i][1] <= 0;
									requestInner[i][4] <= 0;
								end
								else if ((((firstFillInner && !requestInner[missesInner[fillMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][(75 + (WAY_W + 6)) - 1]) && requestInner[i][4]) && (sv2v_cast_32_signed(requestInner[i][6-:2]) == fillMissInner)) && (sv2v_cast_87BE5_signed(i) != missesInner[fillMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)])) begin
									requestInner[i][2] <= 1;
									requestInner[i][1] <= 0;
									requestInner[i][4] <= 0;
								end
								else if (readValidInner && (readIndexInner == sv2v_cast_87BE5_signed(i))) begin
									if (hitWayInner >= 0) begin
										requestInner[i][2] <= 1;
										requestInner[i][WAY_W + 6-:((WAY_W + 6) >= 7 ? WAY_W + 0 : 8 - (WAY_W + 6))] <= sv2v_cast_19C97_signed(hitWayInner);
									end
									else begin
										requestInner[i][6-:2] <= sv2v_cast_2_signed(allocateMissInner);
										requestInner[i][4] <= allocateMissInner >= 0;
										requestInner[i][1] <= allocateMissInner < 0;
									end
								end
								if ((mergeSlotInner == i) && !wordCaptureInner[i]) begin
									requestInner[i][6-:2] <= sv2v_cast_2_signed(mergeMissInner);
									requestInner[i][4] <= 1;
									requestInner[i][1] <= 0;
								end
							end
						end
						olderInner[i] <= (activeInner[i] && !releasedInner[i] ? ((olderInner[i] & activeInner) & ~releasedInner) | (allocationInner >= 0 ? sv2v_cast_D7F72_signed(1) << allocationInner : sv2v_cast_D7F72_signed(0)) : sv2v_cast_D7F72_signed(0));
					end
			end
			begin : sv2v_autoblock_57
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (allocateMissInner == m)
						missesInner[m] <= {line_of(requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2-:32]), sv2v_cast_2861A((readWayMaskInner[victimWayInner] ? metaRdataInner[victimWayInner][TAG_W - 1:0] : sv2v_cast_2861A_signed(0))), sv2v_cast_87BE5(readIndexInner), sv2v_cast_19C97(victimWayInner), sv2v_cast_F2D56(1'sb0), 1'b1, readWayMaskInner[victimWayInner] && metaRdataInner[victimWayInner][TAG_W], 4'b0000};
					else if (fillFireInner && (fillMissInner == m))
						missesInner[m][5] <= 0;
					else if (missesInner[m][5]) begin
						if ((memRequestOutput[71 + (rv32_pkg_DCACHE_LINE_BITS + 1)] && memReadReadyInput) && (readMissInner == m))
							missesInner[m][3] <= 1;
						if ((memRequestOutput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)] && memWriteReadyInput) && (writeMissInner == m))
							missesInner[m][2] <= 1;
						if (writeAckInner == m)
							missesInner[m][1] <= 1;
						if (fillBeatInner && (fillMissInner == m))
							missesInner[m][9-:4] <= missesInner[m][9-:4] + sv2v_cast_4384E_signed(FILL_WORDS_PER_BEAT);
						if ((fillMissInner == m) && (responseInner == sv2v_cast_32_signed(missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)])))
							missesInner[m][0] <= 1;
						if (wordReturnInner && (wordMissInner == sv2v_cast_2_signed(m)))
							missesInner[m][0] <= 1;
					end
			end
			begin : sv2v_autoblock_58
				reg signed [31:0] s;
				for (s = 0; s < SETS; s = s + 1)
					begin
						if (fillFireInner && (set_of(missesInner[fillMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]) == sv2v_cast_3C754_signed(s)))
							plruInner[s] <= plru_touch(plruInner[s], missesInner[fillMissInner][WAY_W + 9-:((WAY_W + 9) >= 10 ? WAY_W : 11 - (WAY_W + 9))]);
						else if (storeHintFireInner && (set_of(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32]) == sv2v_cast_3C754_signed(s)))
							plruInner[s] <= plru_touch(plruInner[s], storeHintWayInner);
						else if ((readValidInner && (hitWayInner >= 0)) && (set_of(requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2-:32]) == sv2v_cast_3C754_signed(s)))
							plruInner[s] <= plru_touch(plruInner[s], sv2v_cast_19C97_signed(hitWayInner));
						begin : sv2v_autoblock_59
							reg signed [31:0] w;
							for (w = 0; w < WAYS; w = w + 1)
								if (((allocateMissInner >= 0) && (set_of(requestInner[readIndexInner][(75 + (WAY_W + 6)) - 2-:32]) == sv2v_cast_3C754_signed(s))) && (victimWayInner == sv2v_cast_19C97_signed(w)))
									validInner[s][w] <= 0;
								else if ((fillFireInner && (set_of(missesInner[fillMissInner][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]) == sv2v_cast_3C754_signed(s))) && (missesInner[fillMissInner][WAY_W + 9-:((WAY_W + 9) >= 10 ? WAY_W : 11 - (WAY_W + 9))] == sv2v_cast_19C97_signed(w)))
									validInner[s][w] <= 1;
						end
					end
			end
		end
	always_ff @(posedge clkInput)
		if (rstNInput) begin
			begin : sv2v_autoblock_60
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (allocateMissInner == m)
						victimPayloadInner[m] <= sram_line(sv2v_cast_32_signed(victimWayInner));
			end
			begin : sv2v_autoblock_61
				reg signed [31:0] i;
				for (i = 0; i < REQUEST_DEPTH; i = i + 1)
					if (requestInner[i][3] && !releasedInner[i]) begin
						if (wordCaptureInner[i])
							rawInner[i] <= extract_returned_word(memWordResponseInput[31-:32], requestInner[i][75 + (WAY_W + 6)-:((75 + (WAY_W + 6)) >= (WAY_W + 7) ? ((75 + (WAY_W + 6)) - (WAY_W + 7)) + 1 : ((WAY_W + 7) - (75 + (WAY_W + 6))) + 1)]);
						else if ((((firstFillInner && !requestInner[missesInner[fillMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][(75 + (WAY_W + 6)) - 1]) && requestInner[i][4]) && (sv2v_cast_32_signed(requestInner[i][6-:2]) == fillMissInner)) && (sv2v_cast_87BE5_signed(i) != missesInner[fillMissInner][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]))
							rawInner[i] <= extract_raw(memResponseInput[rv32_pkg_DCACHE_LINE_BITS - 1-:rv32_pkg_DCACHE_LINE_BITS], requestInner[i][75 + (WAY_W + 6)-:((75 + (WAY_W + 6)) >= (WAY_W + 7) ? ((75 + (WAY_W + 6)) - (WAY_W + 7)) + 1 : ((WAY_W + 7) - (75 + (WAY_W + 6))) + 1)]);
						else if ((readValidInner && (readIndexInner == sv2v_cast_87BE5_signed(i))) && (hitWayInner >= 0))
							rawInner[i] <= readHitRawInner;
					end
			end
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin
			if (acceptLookupInner)
				assert (((((((acceptInner && (allocationInner >= 0)) && !queuedStoreInner) && readEdgeAvailableInner) && !fillBeatInner) && (storeInner < 0)) && (lookupInner < 0)) && !set_locked(cpuRequestInput[72-:32])) else $fatal(1, "DCache accepted read conflicts with older work");
			if (lookupInner >= 0)
				assert (lookupInner == lookupCandidateInner) else $fatal(1, "DCache lookup metadata grant mismatch");
			if (readValidInner)
				assert ((readLookupAddressInner == requestInner[readIndexInner][(75 + (WAY_W + 6)) - 29:(75 + (WAY_W + 6)) - 33]) && (readLookupSizeInner == requestInner[readIndexInner][(75 + (WAY_W + 6)) - 70-:2])) else $fatal(1, "DCache read snapshot diverged");
		end
	always @(posedge clkInput)
		if (rstNInput) begin
			assert ($onehot0(normalWinnerInner)) else $fatal(1, "DCache response winner not unique");
			assert ((normalResponseInner < 0) == !(|normalWinnerInner)) else $fatal(1, "DCache response winner lost");
			if (normalResponseInner >= 0)
				assert (normalWinnerInner[normalResponseInner]) else $fatal(1, "DCache response age mismatch");
		end
	always @(posedge clkInput)
		if (rstNInput) begin : sv2v_autoblock_62
			reg [7:0] originalCandidates;
			originalCandidates = normalBufferedMaskInner;
			begin : sv2v_autoblock_63
				reg signed [31:0] row;
				for (row = 0; row < REQUEST_DEPTH; row = row + 1)
					if ((((((requestInner[row][3] && !requestInner[row][0]) && !requestInner[row][(75 + (WAY_W + 6)) - 1]) && !storeHazardInner[row]) && readValidInner) && (readIndexInner == sv2v_cast_87BE5_signed(row))) && (hitWayInner >= 0))
						originalCandidates[row] = 1'b1;
			end
			assert (normalResponseInner == oldest_request(originalCandidates)) else $fatal(1, "DCache factored late-hit age mismatch");
		end
	initial assert (((((((WAYS == 1) || (WAYS == 2)) || (WAYS == 4)) && (SETS > 1)) && ((SETS & (SETS - 1)) == 0)) && 1'd1) && 1'd1) else $fatal(1, "nonblocking DCache requires power-of-two rows/lines and 1/2/4 ways");
	always @(posedge clkInput)
		if (rstNInput) begin
			assert ((countInner == $countones(activeInner)) && (countInner <= sv2v_cast_D4579_signed(REQUEST_DEPTH))) ;
			assert ($countones(prefetchMaskInner) <= 1) else $fatal(1, "prefetch multiple owners");
			assert (!(acceptInner && prefetchEnqueueInner)) else $fatal(1, "prefetch stole CPU allocation");
			if (prefetchEnqueueInner)
				assert ((countInner <= sv2v_cast_D4579_signed(6)) && (prefetchMissCountInner <= 2)) else $fatal(1, "prefetch demand-credit reservation");
			if (responseInner >= 0)
				assert (!requestInner[responseInner][0]) else $fatal(1, "prefetch produced architectural response");
			if (exitValidOutput)
				assert ((requestInner[firstInner][(75 + (WAY_W + 6)) - 70-:2] == 2'd2) && (requestInner[firstInner][(75 + (WAY_W + 6)) - 66-:4] == 4'hf)) ;
			if (memWriteResponseInput[34])
				assert (writeAckInner >= 0) else $fatal(1, "DCache stale/mismatched write completion");
			if (memResponseInput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)])
				assert ((missesInner[memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]][5] && missesInner[memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]][3]) && (missesInner[memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)] == memResponseInput[rv32_pkg_DCACHE_LINE_BITS + 33-:((rv32_pkg_DCACHE_LINE_BITS + 33) >= (2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((rv32_pkg_DCACHE_LINE_BITS + 33) - (2 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (rv32_pkg_DCACHE_LINE_BITS + 33)) + 1)])) else $fatal(1, "DCache stale/mismatched read completion");
			begin : sv2v_autoblock_64
				reg signed [31:0] m;
				for (m = 0; m < MSHR_DEPTH; m = m + 1)
					if (missesInner[m][5]) begin
						assert ((requestInner[missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][3] && requestInner[missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][4]) && (requestInner[missesInner[m][REQUEST_W + (WAY_W + 9)-:((REQUEST_W + (WAY_W + 9)) >= (WAY_W + 10) ? ((REQUEST_W + (WAY_W + 9)) - (WAY_W + 10)) + 1 : ((WAY_W + 10) - (REQUEST_W + (WAY_W + 9))) + 1)]][6-:2] == sv2v_cast_2_signed(m))) ;
						begin : sv2v_autoblock_65
							reg signed [31:0] n;
							for (n = m + 1; n < MSHR_DEPTH; n = n + 1)
								assert (!missesInner[n][5] || (set_of(missesInner[m][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]) != set_of(missesInner[n][32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))-:((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) >= (TAG_W + (REQUEST_W + (WAY_W + 10))) ? ((32 + (TAG_W + (REQUEST_W + (WAY_W + 9)))) - (TAG_W + (REQUEST_W + (WAY_W + 10)))) + 1 : ((TAG_W + (REQUEST_W + (WAY_W + 10))) - (32 + (TAG_W + (REQUEST_W + (WAY_W + 9))))) + 1)]))) ;
						end
					end
			end
			if (readValidInner)
				assert (requestInner[readIndexInner][3]) ;
			if (acceptInner)
				assert ((sv2v_cast_32_signed(cpuRequestInput[45:41]) + bytes_for_size(cpuRequestInput[4-:2])) <= rv32_pkg_DCACHE_LINE_BYTES) ;
		end
	reg [TAG_W - 1:0] hintWitnessTag [0:SETS - 1][0:WAYS - 1];
	always @(posedge clkInput)
		if (rstNInput) begin
			if (storeHintFireInner)
				assert (((((storeInner == firstInner) && (lookupInner < 0)) && !fillBeatInner) && validInner[set_of(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32])][storeHintWayInner]) && (hintWitnessTag[set_of(requestInner[firstInner][(75 + (WAY_W + 6)) - 2-:32])][storeHintWayInner] == requestInner[firstInner][(75 + (WAY_W + 6)) - 2:(75 + (WAY_W + 6)) - (74 - (41 + (OFFSET_W + INDEX_W)))])) else $fatal(1, "Store location stale or conflicting physical write");
			begin : sv2v_autoblock_66
				reg signed [31:0] w;
				for (w = 0; w < WAYS; w = w + 1)
					if (metaEnableInner[w] && metaWriteInner[w])
						hintWitnessTag[metaAddressInner[w]][w] <= metaWdataInner[TAG_W - 1:0];
			end
		end
`endif
endmodule
module rv32_dmem_backend (
	clkInput,
	rstNInput,
	cpuRequestInput,
	storeSetPreviewInput,
	cpuReqReadyOutput,
	cpuResponseOutput,
	responsePreviewTransactionOutput,
	responsePreviewSelectOutput,
	memRequestOutput,
	memReadReadyInput,
	memWriteReadyInput,
	memResponseInput,
	memWordResponseInput,
	memWriteResponseInput,
	memRspReadyOutput,
	memWriteRspReadyOutput,
	initializedOutput,
	exitReadyInput,
	exitValidOutput,
	exitValueOutput
);
	input wire clkInput;
	input wire rstNInput;
	localparam [31:0] rv32_pkg_DATA_REQUEST_ENTRIES = 8;
	localparam signed [31:0] rv32_pkg_DATA_TRANSACTION_W = 3;
	input wire [74:0] cpuRequestInput;
	localparam [31:0] rv32_pkg_DCACHE_SETS = 128;
	input wire [6:0] storeSetPreviewInput;
	output wire cpuReqReadyOutput;
	output wire [35:0] cpuResponseOutput;
	output wire [5:0] responsePreviewTransactionOutput;
	output wire [1:0] responsePreviewSelectOutput;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BYTES = 32;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BITS = rv32_pkg_DCACHE_LINE_BYTES << 3;
	output wire [(73 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] memRequestOutput;
	input wire memReadReadyInput;
	input wire memWriteReadyInput;
	input wire [(35 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] memResponseInput;
	input wire [66:0] memWordResponseInput;
	input wire [34:0] memWriteResponseInput;
	output wire memRspReadyOutput;
	output wire memWriteRspReadyOutput;
	output wire initializedOutput;
	input wire exitReadyInput;
	output wire exitValidOutput;
	output wire [31:0] exitValueOutput;
	wire unusedIdleInner;
	rv32_dcache #(
		.SETS(128),
		.EARLY_WORD_RETURN(1'b1),
		.LOAD_PREFETCH(1'b1),
		.STORE_SET_PREVIEW(1'b1)
	) cache(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.cpuRequestInput(cpuRequestInput),
		.cpuReqReadyOutput(cpuReqReadyOutput),
		.storeSetPreviewInput(storeSetPreviewInput),
		.cpuResponseOutput(cpuResponseOutput),
		.memRequestOutput(memRequestOutput),
		.responsePreviewTransactionOutput(responsePreviewTransactionOutput),
		.responsePreviewSelectOutput(responsePreviewSelectOutput),
		.memReadReadyInput(memReadReadyInput),
		.memWriteReadyInput(memWriteReadyInput),
		.memResponseInput(memResponseInput),
		.memWordResponseInput(memWordResponseInput),
		.memWriteResponseInput(memWriteResponseInput),
		.memRspReadyOutput(memRspReadyOutput),
		.memWriteRspReadyOutput(memWriteRspReadyOutput),
		.initializedOutput(initializedOutput),
		.idleOutput(unusedIdleInner),
		.exitReadyInput(exitReadyInput),
		.exitValidOutput(exitValidOutput),
		.exitValueOutput(exitValueOutput)
	);
endmodule
module rv32_axi_fetch (
	clkInput,
	rstNInput,
	squashInput,
	requestInput,
	requestReadyOutput,
	responseOutput,
	responseReadyInput,
	masterOutput,
	slaveInput
);
	input wire clkInput;
	input wire rstNInput;
	input wire squashInput;
	localparam [31:0] rv32_pkg_CACHE_LINE_BYTES = 64;
	localparam [31:0] rv32_pkg_CACHE_LINE_BITS = rv32_pkg_CACHE_LINE_BYTES << 3;
	input wire [(34 + rv32_pkg_CACHE_LINE_BITS) - 1:0] requestInput;
	output reg requestReadyOutput;
	output reg [(33 + rv32_pkg_CACHE_LINE_BITS) - 1:0] responseOutput;
	input wire responseReadyInput;
	output reg [104:0] masterOutput;
	input wire [40:0] slaveInput;
	localparam [31:0] rv32_pkg_AXI_FETCH_LINE_ENTRIES = 4;
	localparam signed [31:0] DEPTH = rv32_pkg_AXI_FETCH_LINE_ENTRIES;
	localparam signed [31:0] SLOT_W = 2;
	localparam signed [31:0] WORDS = rv32_pkg_CACHE_LINE_BYTES >> 2;
	localparam signed [31:0] WORD_W = $clog2(WORDS) + 1;
	reg [((33 + WORD_W) + WORD_W) - 1:0] linesInner [0:3];
	reg [31:0] payloadInner [0:3][0:WORDS - 1];
	reg [1:0] headInner;
	reg [SLOT_W:0] countInner;
	reg [SLOT_W:0] tailSeqInner;
	reg [SLOT_W:0] issueSeqInner;
	reg [SLOT_W:0] collectSeqInner;
	reg [8:0] inflightInner;
	reg [8:0] discardInner;
	reg pendingInner;
	reg [31:0] pendingAddressInner;
	reg signed [31:0] occupancyInner;
	reg signed [31:0] issueInner;
	reg signed [31:0] collectInner;
	reg signed [31:0] tailInner;
	wire arInner;
	wire rInner;
	wire consumeInner;
	wire pushInner;
	function automatic signed [WORD_W - 1:0] sv2v_cast_F7755_signed;
		input reg signed [WORD_W - 1:0] inp;
		sv2v_cast_F7755_signed = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [rv32_pkg_CACHE_LINE_BITS - 1:0] sv2v_cast_9A3B2;
		input reg [rv32_pkg_CACHE_LINE_BITS - 1:0] inp;
		sv2v_cast_9A3B2 = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin
		occupancyInner = sv2v_cast_32_signed(countInner);
		issueInner = (issueSeqInner != tailSeqInner ? sv2v_cast_32_signed(issueSeqInner[1:0]) : -1);
		collectInner = ((collectSeqInner != tailSeqInner) && (linesInner[collectSeqInner[1:0]][WORD_W - 1-:WORD_W] < linesInner[collectSeqInner[1:0]][WORD_W + (WORD_W - 1)-:((WORD_W + (WORD_W - 1)) >= (WORD_W + 0) ? ((WORD_W + (WORD_W - 1)) - (WORD_W + 0)) + 1 : ((WORD_W + 0) - (WORD_W + (WORD_W - 1))) + 1)]) ? sv2v_cast_32_signed(collectSeqInner[1:0]) : -1);
		tailInner = (sv2v_cast_32_signed(headInner) + occupancyInner) & 3;
		requestReadyOutput = rstNInput && (occupancyInner < DEPTH);
		responseOutput = {(rstNInput && linesInner[headInner][33 + (WORD_W + (WORD_W - 1))]) && (linesInner[headInner][WORD_W - 1-:WORD_W] == sv2v_cast_F7755_signed(WORDS)), sv2v_cast_32(linesInner[headInner][32 + (WORD_W + (WORD_W - 1))-:((32 + (WORD_W + (WORD_W - 1))) >= (WORD_W + (WORD_W + 0)) ? ((32 + (WORD_W + (WORD_W - 1))) - (WORD_W + (WORD_W + 0))) + 1 : ((WORD_W + (WORD_W + 0)) - (32 + (WORD_W + (WORD_W - 1)))) + 1)]), sv2v_cast_9A3B2(1'sb0)};
		begin : sv2v_autoblock_1
			reg signed [31:0] wordIndex;
			for (wordIndex = 0; wordIndex < WORDS; wordIndex = wordIndex + 1)
				if (responseOutput[rv32_pkg_CACHE_LINE_BITS + 32])
					responseOutput[(rv32_pkg_CACHE_LINE_BITS - 1) - ((rv32_pkg_CACHE_LINE_BITS - 1) - (wordIndex * 32))+:32] = payloadInner[headInner][wordIndex];
		end
		masterOutput = 1'sb0;
		masterOutput[104] = rstNInput && (pendingInner || (issueInner >= 0));
		masterOutput[99-:32] = (pendingInner ? pendingAddressInner : (issueInner >= 0 ? linesInner[issueInner][32 + (WORD_W + (WORD_W - 1))-:((32 + (WORD_W + (WORD_W - 1))) >= (WORD_W + (WORD_W + 0)) ? ((32 + (WORD_W + (WORD_W - 1))) - (WORD_W + (WORD_W + 0))) + 1 : ((WORD_W + (WORD_W + 0)) - (32 + (WORD_W + (WORD_W - 1)))) + 1)] + (sv2v_cast_32(linesInner[issueInner][WORD_W + (WORD_W - 1)-:((WORD_W + (WORD_W - 1)) >= (WORD_W + 0) ? ((WORD_W + (WORD_W - 1)) - (WORD_W + 0)) + 1 : ((WORD_W + 0) - (WORD_W + (WORD_W - 1))) + 1)]) << 2) : 32'b00000000000000000000000000000000));
		masterOutput[103] = rstNInput;
	end
	assign arInner = masterOutput[104] && slaveInput[40];
	assign rInner = slaveInput[39] && masterOutput[103];
	assign consumeInner = responseOutput[rv32_pkg_CACHE_LINE_BITS + 32] && responseReadyInput;
	assign pushInner = requestInput[2 + (rv32_pkg_CACHE_LINE_BITS + 31)] && ((occupancyInner < DEPTH) || consumeInner);
	function automatic [8:0] sv2v_cast_9;
		input reg [8:0] inp;
		sv2v_cast_9 = inp;
	endfunction
	function automatic [WORD_W - 1:0] sv2v_cast_BE961;
		input reg [WORD_W - 1:0] inp;
		sv2v_cast_BE961 = inp;
	endfunction
	function automatic signed [2:0] sv2v_cast_A518B_signed;
		input reg signed [2:0] inp;
		sv2v_cast_A518B_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 0;
			countInner <= 0;
			tailSeqInner <= 0;
			issueSeqInner <= 0;
			collectSeqInner <= 0;
			inflightInner <= 0;
			discardInner <= 0;
			pendingInner <= 0;
			pendingAddressInner <= 0;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < DEPTH; i = i + 1)
					linesInner[i] <= 1'sb0;
			end
		end
		else begin
			inflightInner <= (inflightInner + sv2v_cast_9(arInner)) - sv2v_cast_9(rInner);
			if (squashInput) begin
				begin : sv2v_autoblock_3
					reg signed [31:0] i;
					for (i = 0; i < DEPTH; i = i + 1)
						linesInner[i][33 + (WORD_W + (WORD_W - 1))] <= 0;
				end
				headInner <= 0;
				countInner <= 0;
				tailSeqInner <= 0;
				issueSeqInner <= 0;
				collectSeqInner <= 0;
				discardInner <= (inflightInner + sv2v_cast_9(arInner)) - sv2v_cast_9(rInner);
				if (pendingInner && arInner)
					pendingInner <= 0;
				else if ((!pendingInner && !arInner) && masterOutput[104]) begin
					pendingInner <= 1;
					pendingAddressInner <= masterOutput[99-:32];
				end
			end
			else begin
				discardInner <= (discardInner - sv2v_cast_9(rInner && (discardInner != 0))) + sv2v_cast_9(arInner && pendingInner);
				if ((rInner && (discardInner == 0)) && (collectInner >= 0)) begin
					linesInner[collectInner][WORD_W - 1-:WORD_W] <= linesInner[collectInner][WORD_W - 1-:WORD_W] + 1'b1;
					if ((linesInner[collectInner][WORD_W - 1-:WORD_W] + 1'b1) == sv2v_cast_F7755_signed(WORDS))
						collectSeqInner <= collectSeqInner + 1'b1;
				end
				if (arInner && pendingInner)
					pendingInner <= 0;
				else if (arInner && (issueInner >= 0)) begin
					linesInner[issueInner][WORD_W + (WORD_W - 1)-:((WORD_W + (WORD_W - 1)) >= (WORD_W + 0) ? ((WORD_W + (WORD_W - 1)) - (WORD_W + 0)) + 1 : ((WORD_W + 0) - (WORD_W + (WORD_W - 1))) + 1)] <= linesInner[issueInner][WORD_W + (WORD_W - 1)-:((WORD_W + (WORD_W - 1)) >= (WORD_W + 0) ? ((WORD_W + (WORD_W - 1)) - (WORD_W + 0)) + 1 : ((WORD_W + 0) - (WORD_W + (WORD_W - 1))) + 1)] + 1'b1;
					if ((linesInner[issueInner][WORD_W + (WORD_W - 1)-:((WORD_W + (WORD_W - 1)) >= (WORD_W + 0) ? ((WORD_W + (WORD_W - 1)) - (WORD_W + 0)) + 1 : ((WORD_W + 0) - (WORD_W + (WORD_W - 1))) + 1)] + 1'b1) == sv2v_cast_F7755_signed(WORDS))
						issueSeqInner <= issueSeqInner + 1'b1;
				end
				if (consumeInner && !(pushInner && (tailInner == sv2v_cast_32_signed(headInner))))
					linesInner[headInner][33 + (WORD_W + (WORD_W - 1))] <= 0;
				if (pushInner)
					linesInner[tailInner] <= {1'b1, sv2v_cast_32(requestInput[rv32_pkg_CACHE_LINE_BITS + 31-:((rv32_pkg_CACHE_LINE_BITS + 31) >= (rv32_pkg_CACHE_LINE_BITS + 0) ? ((rv32_pkg_CACHE_LINE_BITS + 31) - (rv32_pkg_CACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_CACHE_LINE_BITS + 0) - (rv32_pkg_CACHE_LINE_BITS + 31)) + 1)]), sv2v_cast_BE961(1'sb0), sv2v_cast_BE961(1'sb0)};
				if (pushInner)
					tailSeqInner <= tailSeqInner + 1'b1;
				if (consumeInner)
					headInner <= headInner + 1'b1;
				countInner <= (pushInner ? (consumeInner ? countInner : countInner + sv2v_cast_A518B_signed(1)) : (consumeInner ? countInner - sv2v_cast_A518B_signed(1) : countInner));
			end
		end
	always_ff @(posedge clkInput)
		if ((((rstNInput && !squashInput) && rInner) && (discardInner == 0)) && (collectInner >= 0))
			payloadInner[collectInner][linesInner[collectInner][(WORD_W - 1) - ((WORD_W - 1) - ($clog2(WORDS) - 1)):(WORD_W - 1) - (WORD_W - 1)]] <= slaveInput[35-:32];
`ifndef SYNTHESIS
	function automatic [1:0] sv2v_cast_7C1AF;
		input reg [1:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	function automatic [2:0] sv2v_cast_A518B;
		input reg [2:0] inp;
		sv2v_cast_A518B = inp;
	endfunction
	always @(posedge clkInput)
		if (rstNInput) begin : sv2v_autoblock_4
			reg signed [31:0] active;
			active = 0;
			begin : sv2v_autoblock_5
				reg signed [31:0] row;
				for (row = 0; row < DEPTH; row = row + 1)
					active = active + sv2v_cast_32_signed(linesInner[row][33 + (WORD_W + (WORD_W - 1))]);
			end
			assert ((sv2v_cast_32_signed(countInner) == active) && (sv2v_cast_32_signed(countInner) <= DEPTH)) ;
			assert (tailSeqInner[1:0] == sv2v_cast_7C1AF(headInner + sv2v_cast_7C1AF(countInner))) ;
			assert (sv2v_cast_A518B(tailSeqInner - issueSeqInner) <= countInner) ;
			assert (sv2v_cast_A518B(tailSeqInner - collectSeqInner) <= countInner) ;
			assert (!requestInput[2 + (rv32_pkg_CACHE_LINE_BITS + 31)] || requestReadyOutput) ;
			if (rInner) begin
				assert ((inflightInner != 0) && (slaveInput[3-:2] == 0)) ;
				assert ((squashInput || (discardInner != 0)) || (collectInner >= 0)) ;
			end
		end
`endif
endmodule
module rv32_axi_data (
	clkInput,
	rstNInput,
	requestInput,
	readReadyOutput,
	writeReadyOutput,
	responseOutput,
	wordResponseOutput,
	responseReadyInput,
	writeResponseOutput,
	writeResponseReadyInput,
	exitValidInput,
	exitValueInput,
	exitReadyOutput,
	masterOutput,
	slaveInput,
	readHeadTransactionOutput,
	writeHeadTransactionOutput,
	writeHeadAddressOutput
);
	input wire clkInput;
	input wire rstNInput;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BYTES = 32;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BITS = rv32_pkg_DCACHE_LINE_BYTES << 3;
	input wire [(73 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] requestInput;
	output wire readReadyOutput;
	output wire writeReadyOutput;
	output reg [(35 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] responseOutput;
	output reg [66:0] wordResponseOutput;
	input wire responseReadyInput;
	output reg [34:0] writeResponseOutput;
	input wire writeResponseReadyInput;
	input wire exitValidInput;
	input wire [31:0] exitValueInput;
	output wire exitReadyOutput;
	output reg [104:0] masterOutput;
	input wire [40:0] slaveInput;
	output wire [1:0] readHeadTransactionOutput;
	output wire [1:0] writeHeadTransactionOutput;
	output wire [31:0] writeHeadAddressOutput;
	localparam signed [31:0] DEPTH = 8;
	localparam signed [31:0] ORDER_ROWS = 16;
	localparam signed [31:0] WORDS = rv32_pkg_DCACHE_LINE_BYTES >> 2;
	localparam signed [31:0] WORD_W = $clog2(WORDS) + 1;
	localparam signed [31:0] WORD_INDEX_W = $clog2(WORDS);
	reg [((((34 + WORD_INDEX_W) + WORD_W) + WORD_W) + WORD_W) + 0:0] entriesInner [0:7];
	wire [7:0] lineCompleteInner;
	wire [7:0] writeCompleteInner;
	genvar _gv_slot_1;
	function automatic signed [WORD_W - 1:0] sv2v_cast_F7755_signed;
		input reg signed [WORD_W - 1:0] inp;
		sv2v_cast_F7755_signed = inp;
	endfunction
	generate
		for (_gv_slot_1 = 0; _gv_slot_1 < DEPTH; _gv_slot_1 = _gv_slot_1 + 1) begin : g_completion
			localparam slot = _gv_slot_1;
			assign lineCompleteInner[slot] = entriesInner[slot][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] == sv2v_cast_F7755_signed(WORDS);
			assign writeCompleteInner[slot] = (entriesInner[slot][0] ? entriesInner[slot][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] == sv2v_cast_F7755_signed(1) : lineCompleteInner[slot]);
		end
	endgenerate
	reg [3:0] readOrderInner [0:15];
	reg [3:0] writeOrderInner [0:15];
	localparam signed [31:0] SLOT_W = 3;
	reg [4:0] readIssueSeqInner;
	function automatic [2:0] sv2v_cast_7C1AF;
		input reg [2:0] inp;
		sv2v_cast_7C1AF = inp;
	endfunction
	wire [2:0] readIssueSlotInner = sv2v_cast_7C1AF(readOrderInner[readIssueSeqInner[3:0]]);
	reg [4:0] readCollectSeqInner;
	wire [2:0] readCollectSlotInner = sv2v_cast_7C1AF(readOrderInner[readCollectSeqInner[3:0]]);
	reg [4:0] awIssueSeqInner;
	wire [2:0] awIssueSlotInner = sv2v_cast_7C1AF(writeOrderInner[awIssueSeqInner[3:0]]);
	reg [4:0] wIssueSeqInner;
	wire [2:0] wIssueSlotInner = sv2v_cast_7C1AF(writeOrderInner[wIssueSeqInner[3:0]]);
	reg [4:0] writeCollectSeqInner;
	wire [2:0] writeCollectSlotInner = sv2v_cast_7C1AF(writeOrderInner[writeCollectSeqInner[3:0]]);
	reg [2:0] readHeadOwnerInner;
	reg [2:0] writeHeadOwnerInner;
	reg [1:0] readHeadTxnInner;
	reg [1:0] writeHeadTxnInner;
	reg [31:0] writeHeadAddressInner;
	assign readHeadTransactionOutput = readHeadTxnInner;
	assign writeHeadTransactionOutput = writeHeadTxnInner;
	assign writeHeadAddressOutput = writeHeadAddressInner;
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	wire [2:0] readHeadSlotInner = sv2v_cast_7C1AF(sv2v_cast_4(readHeadOwnerInner));
	wire [2:0] writeHeadSlotInner = sv2v_cast_7C1AF(sv2v_cast_4(writeHeadOwnerInner));
	wire [rv32_pkg_DCACHE_LINE_BITS - 1:0] payloadReadLineInner;
	wire [31:0] payloadWriteWordInner;
	wire [WORD_INDEX_W - 1:0] collectReadWordInner;
	wire pushWriteInner;
	reg signed [31:0] readCollectInner;
	reg [3:0] writeSlotInner;
	axi_payload_micro_sram #(
		.DEPTH(DEPTH),
		.WORDS(WORDS)
	) u_payload_sram(
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.lineWriteInput(pushWriteInner),
		.lineMmioInput(exitValidInput),
		.lineSlotInput(sv2v_cast_7C1AF(writeSlotInner)),
		.lineDataInput(requestInput[rv32_pkg_DCACHE_LINE_BITS - 1-:rv32_pkg_DCACHE_LINE_BITS]),
		.exitDataInput(exitValueInput),
		.beatWriteInput(slaveInput[39] && (readCollectInner >= 0)),
		.beatSlotInput(sv2v_cast_7C1AF(readCollectSlotInner)),
		.beatWordInput(collectReadWordInner),
		.beatDataInput(slaveInput[35-:32]),
		.readLineSlotInput(sv2v_cast_7C1AF(readHeadSlotInner)),
		.readWordSlotInput(sv2v_cast_7C1AF(wIssueSlotInner)),
		.readWordInput(entriesInner[wIssueSlotInner][(WORD_W + 0) - ((WORD_W - 1) - (WORD_INDEX_W - 1)):(WORD_W + 0) - (WORD_W - 1)]),
		.readLineDataOutput(payloadReadLineInner),
		.readWordDataOutput(payloadWriteWordInner)
	);
	wire [WORD_INDEX_W - 1:0] issueReadWordInner;
	assign issueReadWordInner = entriesInner[readIssueSlotInner][WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))-:((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))) >= (WORD_W + (WORD_W + (WORD_W + 1))) ? ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))) - (WORD_W + (WORD_W + (WORD_W + 1)))) + 1 : ((WORD_W + (WORD_W + (WORD_W + 1))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) + 1)] + entriesInner[readIssueSlotInner][(WORD_W + (WORD_W + (WORD_W + 0))) - ((WORD_W - 1) - (WORD_INDEX_W - 1)):(WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W - 1)];
	assign collectReadWordInner = entriesInner[readCollectSlotInner][WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))-:((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))) >= (WORD_W + (WORD_W + (WORD_W + 1))) ? ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))) - (WORD_W + (WORD_W + (WORD_W + 1)))) + 1 : ((WORD_W + (WORD_W + (WORD_W + 1))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) + 1)] + entriesInner[readCollectSlotInner][(WORD_W + (WORD_W + 0)) - ((WORD_W - 1) - (WORD_INDEX_W - 1)):(WORD_W + (WORD_W + 0)) - (WORD_W - 1)];
	function automatic [31:0] beat_address_prefix;
		input reg [31:0] baseAddress;
		input reg [3:0] beat;
		reg [4:0] lowSum;
		reg [31:0] result;
		begin
			lowSum = {1'b0, baseAddress[5:2]} + {1'b0, beat};
			result[1:0] = baseAddress[1:0];
			result[5:2] = lowSum[3:0];
			result[6] = baseAddress[6] ^ lowSum[4];
			result[7] = baseAddress[7] ^ (lowSum[4] & (&baseAddress[6:6]));
			result[8] = baseAddress[8] ^ (lowSum[4] & (&baseAddress[7:6]));
			result[9] = baseAddress[9] ^ (lowSum[4] & (&baseAddress[8:6]));
			result[10] = baseAddress[10] ^ (lowSum[4] & (&baseAddress[9:6]));
			result[11] = baseAddress[11] ^ (lowSum[4] & (&baseAddress[10:6]));
			result[12] = baseAddress[12] ^ (lowSum[4] & (&baseAddress[11:6]));
			result[13] = baseAddress[13] ^ (lowSum[4] & (&baseAddress[12:6]));
			result[14] = baseAddress[14] ^ (lowSum[4] & (&baseAddress[13:6]));
			result[15] = baseAddress[15] ^ (lowSum[4] & (&baseAddress[14:6]));
			result[16] = baseAddress[16] ^ (lowSum[4] & (&baseAddress[15:6]));
			result[17] = baseAddress[17] ^ (lowSum[4] & (&baseAddress[16:6]));
			result[18] = baseAddress[18] ^ (lowSum[4] & (&baseAddress[17:6]));
			result[19] = baseAddress[19] ^ (lowSum[4] & (&baseAddress[18:6]));
			result[20] = baseAddress[20] ^ (lowSum[4] & (&baseAddress[19:6]));
			result[21] = baseAddress[21] ^ (lowSum[4] & (&baseAddress[20:6]));
			result[22] = baseAddress[22] ^ (lowSum[4] & (&baseAddress[21:6]));
			result[23] = baseAddress[23] ^ (lowSum[4] & (&baseAddress[22:6]));
			result[24] = baseAddress[24] ^ (lowSum[4] & (&baseAddress[23:6]));
			result[25] = baseAddress[25] ^ (lowSum[4] & (&baseAddress[24:6]));
			result[26] = baseAddress[26] ^ (lowSum[4] & (&baseAddress[25:6]));
			result[27] = baseAddress[27] ^ (lowSum[4] & (&baseAddress[26:6]));
			result[28] = baseAddress[28] ^ (lowSum[4] & (&baseAddress[27:6]));
			result[29] = baseAddress[29] ^ (lowSum[4] & (&baseAddress[28:6]));
			result[30] = baseAddress[30] ^ (lowSum[4] & (&baseAddress[29:6]));
			result[31] = baseAddress[31] ^ (lowSum[4] & (&baseAddress[30:6]));
			beat_address_prefix = result;
		end
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			wordResponseOutput <= 1'sb0;
		else begin
			wordResponseOutput[66] <= slaveInput[39] && (readCollectInner >= 0);
			if (slaveInput[39] && (readCollectInner >= 0)) begin
				wordResponseOutput[65-:32] <= beat_address_prefix(entriesInner[readCollectSlotInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)], sv2v_cast_4(collectReadWordInner));
				wordResponseOutput[33-:2] <= entriesInner[readCollectSlotInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)];
				wordResponseOutput[31-:32] <= slaveInput[35-:32];
			end
		end
	reg [7:0] dataBusyInner;
	reg [7:0] allocatedInner;
	reg [7:0] releasedInner;
	reg [3:0] firstFreeInner;
	reg [3:0] secondFreeInner;
	reg [3:0] readSlotInner;
	reg firstFreeFoundInner;
	reg secondFreeFoundInner;
	reg [3:0] readHeadInner;
	reg [3:0] writeHeadInner;
	reg [4:0] readCountInner;
	reg [4:0] writeCountInner;
	reg [4:0] readTailSeqInner;
	reg [4:0] writeTailSeqInner;
	reg signed [31:0] readIssueInner;
	reg signed [31:0] awIssueInner;
	reg signed [31:0] wIssueInner;
	reg signed [31:0] writeCollectInner;
	wire pushReadInner;
	wire popReadInner;
	wire popWriteInner;
	function automatic signed [3:0] sv2v_cast_4_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4_signed = inp;
	endfunction
	always @* begin
		firstFreeInner = 1'sb0;
		secondFreeInner = 1'sb0;
		firstFreeFoundInner = 1'b0;
		secondFreeFoundInner = 1'b0;
		begin : sv2v_autoblock_1
			reg signed [31:0] slot;
			for (slot = 0; slot < DEPTH; slot = slot + 1)
				if (!dataBusyInner[slot]) begin
					if (!firstFreeFoundInner) begin
						firstFreeFoundInner = 1'b1;
						firstFreeInner = sv2v_cast_4_signed(slot);
					end
					else if (!secondFreeFoundInner) begin
						secondFreeFoundInner = 1'b1;
						secondFreeInner = sv2v_cast_4_signed(slot);
					end
				end
		end
		writeSlotInner = firstFreeInner;
		readSlotInner = (pushWriteInner ? secondFreeInner : firstFreeInner);
		allocatedInner = 1'sb0;
		releasedInner = 1'sb0;
		if (pushWriteInner)
			allocatedInner[sv2v_cast_7C1AF(writeSlotInner)] = 1'b1;
		if (pushReadInner)
			allocatedInner[sv2v_cast_7C1AF(readSlotInner)] = 1'b1;
		if (popReadInner)
			releasedInner[readHeadSlotInner] = 1'b1;
		if (popWriteInner)
			releasedInner[writeHeadSlotInner] = 1'b1;
	end
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @* begin
		readIssueInner = (readIssueSeqInner != readTailSeqInner ? sv2v_cast_32_signed(readIssueSeqInner[3:0]) : -1);
		awIssueInner = (awIssueSeqInner != writeTailSeqInner ? sv2v_cast_32_signed(awIssueSeqInner[3:0]) : -1);
		wIssueInner = (wIssueSeqInner != writeTailSeqInner ? sv2v_cast_32_signed(wIssueSeqInner[3:0]) : -1);
		readCollectInner = ((readCollectSeqInner != readTailSeqInner) && (entriesInner[readCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] < entriesInner[readCollectSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)]) ? sv2v_cast_32_signed(readCollectSeqInner[3:0]) : -1);
		writeCollectInner = (((writeCollectSeqInner != writeTailSeqInner) && (entriesInner[writeCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] < entriesInner[writeCollectSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)])) && (entriesInner[writeCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] < entriesInner[writeCollectSlotInner][WORD_W + 0-:((WORD_W + 0) >= 1 ? WORD_W + 0 : 2 - (WORD_W + 0))]) ? sv2v_cast_32_signed(writeCollectSeqInner[3:0]) : -1);
		masterOutput = 1'sb0;
		masterOutput[104] = rstNInput && (readIssueInner >= 0);
		masterOutput[99-:32] = (readIssueInner >= 0 ? beat_address_prefix(entriesInner[readIssueSlotInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)], sv2v_cast_4(issueReadWordInner)) : 0);
		masterOutput[102] = rstNInput && (awIssueInner >= 0);
		masterOutput[67-:32] = (awIssueInner >= 0 ? beat_address_prefix(entriesInner[awIssueSlotInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)], entriesInner[awIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)]) : 0);
		masterOutput[101] = rstNInput && (wIssueInner >= 0);
		if (wIssueInner >= 0) begin
			masterOutput[3-:4] = 4'hf;
			masterOutput[35-:32] = payloadWriteWordInner;
		end
		masterOutput[103] = rstNInput;
		masterOutput[100] = rstNInput;
	end
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	function automatic [rv32_pkg_DCACHE_LINE_BITS - 1:0] sv2v_cast_077AA;
		input reg [rv32_pkg_DCACHE_LINE_BITS - 1:0] inp;
		sv2v_cast_077AA = inp;
	endfunction
	always @* begin : registered_axi_responses
		responseOutput = {(rstNInput && (readCountInner != 32'sd0)) && lineCompleteInner[readHeadSlotInner], sv2v_cast_32(entriesInner[readHeadSlotInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)]), sv2v_cast_2(entriesInner[readHeadSlotInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)]), sv2v_cast_077AA(1'sb0)};
		begin : sv2v_autoblock_2
			reg signed [31:0] wordIndex;
			for (wordIndex = 0; wordIndex < WORDS; wordIndex = wordIndex + 1)
				if (responseOutput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)])
					responseOutput[(rv32_pkg_DCACHE_LINE_BITS - 1) - ((rv32_pkg_DCACHE_LINE_BITS - 1) - (wordIndex * 32))+:32] = payloadReadLineInner[wordIndex * 32+:32];
		end
		writeResponseOutput = {(rstNInput && (writeCountInner != 32'sd0)) && writeCompleteInner[writeHeadSlotInner], sv2v_cast_32(entriesInner[writeHeadSlotInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)]), sv2v_cast_2(entriesInner[writeHeadSlotInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)])};
	end
	assign writeReadyOutput = rstNInput && ((sv2v_cast_32_signed(readCountInner) + sv2v_cast_32_signed(writeCountInner)) < DEPTH);
	assign readReadyOutput = rstNInput && (((sv2v_cast_32_signed(readCountInner) + sv2v_cast_32_signed(writeCountInner)) + sv2v_cast_32_signed(requestInput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)] || exitValidInput)) < DEPTH);
	assign exitReadyOutput = (rstNInput && (readCountInner == 0)) && (writeCountInner == 0);
	assign pushWriteInner = (requestInput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)] || exitValidInput) && writeReadyOutput;
	assign pushReadInner = requestInput[71 + (rv32_pkg_DCACHE_LINE_BITS + 1)] && readReadyOutput;
	assign popReadInner = responseOutput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)] && responseReadyInput;
	assign popWriteInner = writeResponseOutput[34] && writeResponseReadyInput;
	localparam [31:0] rv32_pkg_AXI_EXIT_ADDR = 32'h80000000;
	function automatic [WORD_INDEX_W - 1:0] sv2v_cast_4384E;
		input reg [WORD_INDEX_W - 1:0] inp;
		sv2v_cast_4384E = inp;
	endfunction
	function automatic [WORD_W - 1:0] sv2v_cast_39B2C;
		input reg [WORD_W - 1:0] inp;
		sv2v_cast_39B2C = inp;
	endfunction
	function automatic [WORD_INDEX_W - 1:0] sv2v_cast_46553;
		input reg [WORD_INDEX_W - 1:0] inp;
		sv2v_cast_46553 = inp;
	endfunction
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			readHeadInner <= 0;
			writeHeadInner <= 0;
			readCountInner <= 0;
			writeCountInner <= 0;
			readTailSeqInner <= 0;
			writeTailSeqInner <= 0;
			readIssueSeqInner <= 0;
			readCollectSeqInner <= 0;
			awIssueSeqInner <= 0;
			wIssueSeqInner <= 0;
			writeCollectSeqInner <= 0;
			dataBusyInner <= 1'sb0;
			begin : sv2v_autoblock_3
				reg signed [31:0] i;
				for (i = 0; i < DEPTH; i = i + 1)
					begin
						entriesInner[i] <= 1'sb0;
						readOrderInner[i] <= 1'sb0;
						writeOrderInner[i] <= 1'sb0;
					end
			end
		end
		else begin
			if (masterOutput[104] && slaveInput[40]) begin
				entriesInner[readIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)] <= entriesInner[readIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)] + 1'b1;
				if ((entriesInner[readIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)] + 1'b1) == sv2v_cast_F7755_signed(WORDS))
					readIssueSeqInner <= readIssueSeqInner + 1'b1;
			end
			if (masterOutput[102] && slaveInput[38]) begin
				entriesInner[awIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)] <= entriesInner[awIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)] + 1'b1;
				if ((entriesInner[awIssueSlotInner][WORD_W + (WORD_W + (WORD_W + 0))-:((WORD_W + (WORD_W + (WORD_W + 0))) >= (WORD_W + (WORD_W + 1)) ? ((WORD_W + (WORD_W + (WORD_W + 0))) - (WORD_W + (WORD_W + 1))) + 1 : ((WORD_W + (WORD_W + 1)) - (WORD_W + (WORD_W + (WORD_W + 0)))) + 1)] + 1'b1) == (entriesInner[awIssueSlotInner][0] ? sv2v_cast_F7755_signed(1) : sv2v_cast_F7755_signed(WORDS)))
					awIssueSeqInner <= awIssueSeqInner + 1'b1;
			end
			if (masterOutput[101] && slaveInput[37]) begin
				entriesInner[wIssueSlotInner][WORD_W + 0-:((WORD_W + 0) >= 1 ? WORD_W + 0 : 2 - (WORD_W + 0))] <= entriesInner[wIssueSlotInner][WORD_W + 0-:((WORD_W + 0) >= 1 ? WORD_W + 0 : 2 - (WORD_W + 0))] + 1'b1;
				if ((entriesInner[wIssueSlotInner][WORD_W + 0-:((WORD_W + 0) >= 1 ? WORD_W + 0 : 2 - (WORD_W + 0))] + 1'b1) == (entriesInner[wIssueSlotInner][0] ? sv2v_cast_F7755_signed(1) : sv2v_cast_F7755_signed(WORDS)))
					wIssueSeqInner <= wIssueSeqInner + 1'b1;
			end
			if (slaveInput[39] && (readCollectInner >= 0)) begin
				entriesInner[readCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] <= entriesInner[readCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] + 1'b1;
				if ((entriesInner[readCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] + 1'b1) == sv2v_cast_F7755_signed(WORDS))
					readCollectSeqInner <= readCollectSeqInner + 1'b1;
			end
			if (slaveInput[36] && (writeCollectInner >= 0)) begin
				entriesInner[writeCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] <= entriesInner[writeCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] + 1'b1;
				if ((entriesInner[writeCollectSlotInner][WORD_W + (WORD_W + 0)-:((WORD_W + (WORD_W + 0)) >= (WORD_W + 1) ? ((WORD_W + (WORD_W + 0)) - (WORD_W + 1)) + 1 : ((WORD_W + 1) - (WORD_W + (WORD_W + 0))) + 1)] + 1'b1) == (entriesInner[writeCollectSlotInner][0] ? sv2v_cast_F7755_signed(1) : sv2v_cast_F7755_signed(WORDS)))
					writeCollectSeqInner <= writeCollectSeqInner + 1'b1;
			end
			if (pushReadInner) begin
				readOrderInner[readTailSeqInner[3:0]] <= readSlotInner;
				entriesInner[sv2v_cast_7C1AF(readSlotInner)] <= {sv2v_cast_32(requestInput[70 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((70 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (40 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((70 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (40 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((40 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (70 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)]), sv2v_cast_2(requestInput[38 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)]), sv2v_cast_4384E(requestInput[36 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((36 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (35 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((36 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (35 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((35 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (36 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)]), sv2v_cast_39B2C(1'sb0), sv2v_cast_39B2C(1'sb0), sv2v_cast_39B2C(1'sb0), 1'b0};
				readTailSeqInner <= readTailSeqInner + 1'b1;
			end
			if (pushWriteInner) begin
				writeOrderInner[writeTailSeqInner[3:0]] <= writeSlotInner;
				entriesInner[sv2v_cast_7C1AF(writeSlotInner)] <= {sv2v_cast_32((exitValidInput ? rv32_pkg_AXI_EXIT_ADDR : requestInput[rv32_pkg_DCACHE_LINE_BITS + 33-:((rv32_pkg_DCACHE_LINE_BITS + 33) >= (2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((rv32_pkg_DCACHE_LINE_BITS + 33) - (2 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (rv32_pkg_DCACHE_LINE_BITS + 33)) + 1)])), sv2v_cast_2(requestInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)]), sv2v_cast_46553(1'sb0), sv2v_cast_39B2C(1'sb0), sv2v_cast_39B2C(1'sb0), sv2v_cast_39B2C(1'sb0), exitValidInput};
				writeTailSeqInner <= writeTailSeqInner + 1'b1;
			end
			if (popReadInner)
				readHeadInner <= readHeadInner + 1'b1;
			if (popWriteInner)
				writeHeadInner <= writeHeadInner + 1'b1;
			readCountInner <= (readCountInner + sv2v_cast_5(pushReadInner)) - sv2v_cast_5(popReadInner);
			writeCountInner <= (writeCountInner + sv2v_cast_5(pushWriteInner)) - sv2v_cast_5(popWriteInner);
			dataBusyInner <= (dataBusyInner & ~releasedInner) | allocatedInner;
		end
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			readHeadOwnerInner <= 1'sb0;
			writeHeadOwnerInner <= 1'sb0;
		end
		else begin
			if (pushReadInner && ((readCountInner == 0) || (popReadInner && (readCountInner == 1))))
				readHeadOwnerInner <= sv2v_cast_7C1AF(readSlotInner);
			else if (popReadInner)
				readHeadOwnerInner <= sv2v_cast_7C1AF(readOrderInner[readHeadInner + 4'd1]);
			if (pushWriteInner && ((writeCountInner == 0) || (popWriteInner && (writeCountInner == 1))))
				writeHeadOwnerInner <= sv2v_cast_7C1AF(writeSlotInner);
			else if (popWriteInner)
				writeHeadOwnerInner <= sv2v_cast_7C1AF(writeOrderInner[writeHeadInner + 4'd1]);
		end
	wire [2:0] followingReadOwnerInner = sv2v_cast_7C1AF(readOrderInner[readHeadInner + 4'd1]);
	wire readBecomesHeadInner = pushReadInner && ((readCountInner == 0) || (popReadInner && (readCountInner == 1)));
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			readHeadTxnInner <= 1'sb0;
		else if (readBecomesHeadInner)
			readHeadTxnInner <= (pushWriteInner && (sv2v_cast_7C1AF(writeSlotInner) == sv2v_cast_7C1AF(readSlotInner)) ? requestInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)] : requestInput[38 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)]);
		else if (popReadInner) begin
			if (pushWriteInner && (sv2v_cast_7C1AF(writeSlotInner) == followingReadOwnerInner))
				readHeadTxnInner <= requestInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)];
			else if (pushReadInner && (sv2v_cast_7C1AF(readSlotInner) == followingReadOwnerInner))
				readHeadTxnInner <= requestInput[38 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)];
			else
				readHeadTxnInner <= entriesInner[followingReadOwnerInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)];
		end
		else if (pushWriteInner && (sv2v_cast_7C1AF(writeSlotInner) == readHeadSlotInner))
			readHeadTxnInner <= requestInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)];
		else if (pushReadInner && (sv2v_cast_7C1AF(readSlotInner) == readHeadSlotInner))
			readHeadTxnInner <= requestInput[38 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)];
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput)
			assert (readHeadTxnInner == entriesInner[readHeadSlotInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)]) else $fatal(1, "AXI read-head transaction differs from original descriptor");
`endif
	wire [2:0] followingWriteOwnerInner = sv2v_cast_7C1AF(writeOrderInner[writeHeadInner + 4'd1]);
	wire writeBecomesHeadInner = pushWriteInner && ((writeCountInner == 0) || (popWriteInner && (writeCountInner == 1)));
	wire [2:0] writeHeadTxnNextOwnerInner = (popWriteInner ? followingWriteOwnerInner : writeHeadSlotInner);
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			writeHeadTxnInner <= 1'sb0;
		else if (writeBecomesHeadInner || (pushWriteInner && (sv2v_cast_7C1AF(writeSlotInner) == writeHeadTxnNextOwnerInner)))
			writeHeadTxnInner <= requestInput[rv32_pkg_DCACHE_LINE_BITS + 1-:((rv32_pkg_DCACHE_LINE_BITS + 1) >= (rv32_pkg_DCACHE_LINE_BITS + 0) ? ((rv32_pkg_DCACHE_LINE_BITS + 1) - (rv32_pkg_DCACHE_LINE_BITS + 0)) + 1 : ((rv32_pkg_DCACHE_LINE_BITS + 0) - (rv32_pkg_DCACHE_LINE_BITS + 1)) + 1)];
		else if (pushReadInner && (sv2v_cast_7C1AF(readSlotInner) == writeHeadTxnNextOwnerInner))
			writeHeadTxnInner <= requestInput[38 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((38 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((38 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (38 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)];
		else if (popWriteInner)
			writeHeadTxnInner <= entriesInner[followingWriteOwnerInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)];
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			writeHeadAddressInner <= 1'sb0;
		else if (writeBecomesHeadInner || (pushWriteInner && (sv2v_cast_7C1AF(writeSlotInner) == writeHeadTxnNextOwnerInner)))
			writeHeadAddressInner <= (exitValidInput ? rv32_pkg_AXI_EXIT_ADDR : requestInput[rv32_pkg_DCACHE_LINE_BITS + 33-:((rv32_pkg_DCACHE_LINE_BITS + 33) >= (2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((rv32_pkg_DCACHE_LINE_BITS + 33) - (2 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (rv32_pkg_DCACHE_LINE_BITS + 33)) + 1)]);
		else if (pushReadInner && (sv2v_cast_7C1AF(readSlotInner) == writeHeadTxnNextOwnerInner))
			writeHeadAddressInner <= requestInput[70 + (rv32_pkg_DCACHE_LINE_BITS + 1)-:((70 + (rv32_pkg_DCACHE_LINE_BITS + 1)) >= (40 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((70 + (rv32_pkg_DCACHE_LINE_BITS + 1)) - (40 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((40 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (70 + (rv32_pkg_DCACHE_LINE_BITS + 1))) + 1)];
		else if (popWriteInner)
			writeHeadAddressInner <= entriesInner[followingWriteOwnerInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)];
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin
			assert (writeHeadTxnInner == entriesInner[writeHeadSlotInner][2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) ? ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) + 1 : ((WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)]) else $fatal(1, "AXI write-head transaction differs from original descriptor");
			assert (writeHeadAddressInner == entriesInner[writeHeadSlotInner][34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))-:((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) >= (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) ? ((34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0))))) - (2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1)))))) + 1 : ((2 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 1))))) - (34 + (WORD_INDEX_W + (WORD_W + (WORD_W + (WORD_W + 0)))))) + 1)]) else $fatal(1, "AXI write-head address differs from original descriptor");
		end
	always @(posedge clkInput)
		if (rstNInput) begin : sv2v_autoblock_4
			reg [7:0] owners;
			owners = 1'sb0;
			assert (sv2v_cast_4(readHeadOwnerInner) == readOrderInner[readHeadInner]) else $fatal(1, "AXI read head owner cache diverged");
			assert (sv2v_cast_4(writeHeadOwnerInner) == writeOrderInner[writeHeadInner]) else $fatal(1, "AXI write head owner cache diverged");
			assert ((sv2v_cast_32_signed(readCountInner) + sv2v_cast_32_signed(writeCountInner)) <= DEPTH) ;
			assert ($countones(dataBusyInner) == (sv2v_cast_32_signed(readCountInner) + sv2v_cast_32_signed(writeCountInner))) ;
			assert (readTailSeqInner[3:0] == sv2v_cast_4(readHeadInner + sv2v_cast_4(readCountInner))) ;
			assert (writeTailSeqInner[3:0] == sv2v_cast_4(writeHeadInner + sv2v_cast_4(writeCountInner))) ;
			assert ((readTailSeqInner - readIssueSeqInner) <= readCountInner) ;
			assert ((readTailSeqInner - readCollectSeqInner) <= readCountInner) ;
			assert ((writeTailSeqInner - awIssueSeqInner) <= writeCountInner) ;
			assert ((writeTailSeqInner - wIssueSeqInner) <= writeCountInner) ;
			assert ((writeTailSeqInner - writeCollectSeqInner) <= writeCountInner) ;
			assert (!pushWriteInner || firstFreeFoundInner) ;
			assert (!pushReadInner || (pushWriteInner ? secondFreeFoundInner : firstFreeFoundInner)) ;
			begin : sv2v_autoblock_5
				reg signed [31:0] age;
				for (age = 0; age < DEPTH; age = age + 1)
					begin
						if (age < sv2v_cast_32_signed(readCountInner)) begin
							assert (!owners[sv2v_cast_7C1AF(readOrderInner[sv2v_cast_4(readHeadInner + sv2v_cast_4_signed(age))])]) ;
							owners[sv2v_cast_7C1AF(readOrderInner[sv2v_cast_4(readHeadInner + sv2v_cast_4_signed(age))])] = 1'b1;
						end
						if (age < sv2v_cast_32_signed(writeCountInner)) begin
							assert (!owners[sv2v_cast_7C1AF(writeOrderInner[sv2v_cast_4(writeHeadInner + sv2v_cast_4_signed(age))])]) ;
							owners[sv2v_cast_7C1AF(writeOrderInner[sv2v_cast_4(writeHeadInner + sv2v_cast_4_signed(age))])] = 1'b1;
						end
					end
			end
			assert (owners == dataBusyInner) ;
			assert (!exitValidInput || (exitReadyOutput && !requestInput[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)])) ;
			if (slaveInput[39])
				assert ((readCollectInner >= 0) && (slaveInput[3-:2] == 0)) ;
			if (slaveInput[36])
				assert ((writeCollectInner >= 0) && (slaveInput[1-:2] == 0)) ;
		end
`endif
endmodule
module axi_payload_micro_sram (
	clkInput,
	rstNInput,
	lineWriteInput,
	lineMmioInput,
	lineSlotInput,
	lineDataInput,
	exitDataInput,
	beatWriteInput,
	beatSlotInput,
	beatWordInput,
	beatDataInput,
	readLineSlotInput,
	readWordSlotInput,
	readWordInput,
	readLineDataOutput,
	readWordDataOutput
);
	parameter signed [31:0] DEPTH = 8;
	parameter signed [31:0] WORDS = 8;
	localparam signed [31:0] SLOT_W = $clog2(DEPTH);
	localparam signed [31:0] WORD_INDEX_W = $clog2(WORDS);
	input wire clkInput;
	input wire rstNInput;
	input wire lineWriteInput;
	input wire lineMmioInput;
	input wire [SLOT_W - 1:0] lineSlotInput;
	input wire [(WORDS * 32) - 1:0] lineDataInput;
	input wire [31:0] exitDataInput;
	input wire beatWriteInput;
	input wire [SLOT_W - 1:0] beatSlotInput;
	input wire [WORD_INDEX_W - 1:0] beatWordInput;
	input wire [31:0] beatDataInput;
	input wire [SLOT_W - 1:0] readLineSlotInput;
	input wire [SLOT_W - 1:0] readWordSlotInput;
	input wire [WORD_INDEX_W - 1:0] readWordInput;
	output reg [(WORDS * 32) - 1:0] readLineDataOutput;
	output reg [31:0] readWordDataOutput;
	wire [((DEPTH * WORDS) * 32) - 1:0] bankDataInner;
	reg lastLineValidInner;
	reg lastBeatValidInner;
	reg lastLineMmioInner;
	reg [SLOT_W - 1:0] lastLineSlotInner;
	reg [SLOT_W - 1:0] lastBeatSlotInner;
	reg [WORD_INDEX_W - 1:0] lastBeatWordInner;
	reg [(WORDS * 32) - 1:0] lastLineDataInner;
	reg [31:0] lastBeatDataInner;
	genvar _gv_slot_2;
	function automatic signed [SLOT_W - 1:0] sv2v_cast_7C1AF_signed;
		input reg signed [SLOT_W - 1:0] inp;
		sv2v_cast_7C1AF_signed = inp;
	endfunction
	function automatic signed [WORD_INDEX_W - 1:0] sv2v_cast_4384E_signed;
		input reg signed [WORD_INDEX_W - 1:0] inp;
		sv2v_cast_4384E_signed = inp;
	endfunction
	generate
		for (_gv_slot_2 = 0; _gv_slot_2 < DEPTH; _gv_slot_2 = _gv_slot_2 + 1) begin : g_line
			localparam slot = _gv_slot_2;
			genvar _gv_wordIndex_1;
			for (_gv_wordIndex_1 = 0; _gv_wordIndex_1 < WORDS; _gv_wordIndex_1 = _gv_wordIndex_1 + 1) begin : g_word
				localparam wordIndex = _gv_wordIndex_1;
				wire lineHit;
				wire beatHit;
				assign lineHit = ((rstNInput && lineWriteInput) && (lineSlotInput == sv2v_cast_7C1AF_signed(slot))) && (!lineMmioInput || (wordIndex == 0));
				assign beatHit = ((rstNInput && beatWriteInput) && (beatSlotInput == sv2v_cast_7C1AF_signed(slot))) && (beatWordInput == sv2v_cast_4384E_signed(wordIndex));
				sram_fakeram #(
					.DEPTH(1),
					.WIDTH(32),
					.WRITE_GRANULARITY(32)
				) u_bank(
					.clk(clkInput),
					.en(1'b1),
					.we(lineHit || beatHit),
					.wmask(1'b1),
					.addr(1'b0),
					.wdata((lineHit ? (lineMmioInput ? exitDataInput : lineDataInput[wordIndex * 32+:32]) : beatDataInput)),
					.rdata(bankDataInner[((slot * WORDS) + wordIndex) * 32+:32])
				);
			end
		end
	endgenerate
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			lastLineValidInner <= 0;
			lastBeatValidInner <= 0;
		end
		else begin
			lastLineValidInner <= lineWriteInput;
			lastBeatValidInner <= beatWriteInput;
		end
	always_ff @(posedge clkInput)
		if (rstNInput) begin
			if (lineWriteInput) begin
				lastLineSlotInner <= lineSlotInput;
				lastLineMmioInner <= lineMmioInput;
				lastLineDataInner <= lineDataInput;
				if (lineMmioInput)
					lastLineDataInner[31:0] <= exitDataInput;
			end
			if (beatWriteInput) begin
				lastBeatSlotInner <= beatSlotInput;
				lastBeatWordInner <= beatWordInput;
				lastBeatDataInner <= beatDataInput;
			end
		end
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [31:0] payload_word;
		input reg [SLOT_W - 1:0] slot;
		input reg [WORD_INDEX_W - 1:0] wordIndex;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if ((lastLineValidInner && (lastLineSlotInner == slot)) && (!lastLineMmioInner || (wordIndex == 0))) begin
				payload_word = lastLineDataInner[wordIndex * 32+:32];
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				if ((lastBeatValidInner && (lastBeatSlotInner == slot)) && (lastBeatWordInner == wordIndex)) begin
					payload_word = lastBeatDataInner;
					_sv2v_jump = 2'b11;
				end
				if (_sv2v_jump == 2'b00) begin
					payload_word = bankDataInner[((sv2v_cast_32_signed(slot) * WORDS) + sv2v_cast_32_signed(wordIndex)) * 32+:32];
					_sv2v_jump = 2'b11;
				end
			end
		end
	endfunction
	genvar _gv_wordIndex_2;
	generate
		for (_gv_wordIndex_2 = 0; _gv_wordIndex_2 < WORDS; _gv_wordIndex_2 = _gv_wordIndex_2 + 1) begin : g_response_word
			localparam wordIndex = _gv_wordIndex_2;
			always @* readLineDataOutput[wordIndex * 32+:32] = payload_word(readLineSlotInput, sv2v_cast_4384E_signed(wordIndex));
		end
	endgenerate
	always @* readWordDataOutput = payload_word(readWordSlotInput, readWordInput);
endmodule
module rv32_axi_bus (
	clkInput,
	rstNInput,
	fetchInput,
	dataInput,
	slaveInput,
	masterOutput,
	fetchOutput,
	dataOutput
);
	input wire clkInput;
	input wire rstNInput;
	input wire [104:0] fetchInput;
	input wire [104:0] dataInput;
	input wire [40:0] slaveInput;
	output reg [104:0] masterOutput;
	output reg [40:0] fetchOutput;
	output reg [40:0] dataOutput;
	reg ownerInner [0:63];
	reg [5:0] headInner;
	reg [6:0] countInner;
	reg preferDataInner;
	reg grantHeldInner;
	reg heldDataInner;
	wire creditInner;
	wire dataInner;
	wire pushInner;
	wire popInner;
	assign creditInner = countInner < 64;
	assign dataInner = (grantHeldInner ? heldDataInner : dataInput[104] && (!fetchInput[104] || preferDataInner));
	always @* begin
		masterOutput = dataInput;
		masterOutput[104] = (rstNInput && creditInner) && (fetchInput[104] || dataInput[104]);
		masterOutput[99-:32] = (dataInner ? dataInput[99-:32] : fetchInput[99-:32]);
		masterOutput[103] = (rstNInput && (countInner != 0)) && (ownerInner[headInner] ? dataInput[103] : fetchInput[103]);
		fetchOutput = slaveInput;
		dataOutput = slaveInput;
		fetchOutput[40] = ((rstNInput && creditInner) && !dataInner) && slaveInput[40];
		dataOutput[40] = ((rstNInput && creditInner) && dataInner) && slaveInput[40];
		fetchOutput[39] = (slaveInput[39] && (countInner != 0)) && !ownerInner[headInner];
		dataOutput[39] = (slaveInput[39] && (countInner != 0)) && ownerInner[headInner];
	end
	assign pushInner = masterOutput[104] && slaveInput[40];
	assign popInner = masterOutput[103] && slaveInput[39];
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			headInner <= 0;
			countInner <= 0;
			preferDataInner <= 0;
			grantHeldInner <= 0;
			heldDataInner <= 0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 64; i = i + 1)
					ownerInner[i] <= 0;
			end
		end
		else begin
			if ((masterOutput[104] && !slaveInput[40]) && !grantHeldInner) begin
				grantHeldInner <= 1;
				heldDataInner <= dataInner;
			end
			else if (pushInner)
				grantHeldInner <= 0;
			if (pushInner)
				ownerInner[sv2v_cast_6(headInner + sv2v_cast_6(countInner))] <= dataInner;
			if (popInner)
				headInner <= headInner + 1'b1;
			countInner <= (countInner + sv2v_cast_7(pushInner)) - sv2v_cast_7(popInner);
			if ((pushInner && fetchInput[104]) && dataInput[104])
				preferDataInner <= !preferDataInner;
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (rstNInput) begin
			assert (countInner <= 64) ;
			if (slaveInput[39])
				assert (countInner != 0) ;
		end
`endif
endmodule
module rv32_bpu_direction (
	clkInput,
	rstNInput,
	freezeInput,
	queryPcInput,
	branchInput,
	branchContextInput,
	historyInput,
	predictionOutput,
	queryContextOutput
);
	parameter [31:0] BHT_ENTRIES = 256;
	parameter [31:0] CONDSEEN_ENTRIES = 512;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [31:0] queryPcInput;
	input wire [73:0] branchInput;
	input wire [2:0] branchContextInput;
	input wire [11:0] historyInput;
	output reg [10:0] predictionOutput;
	output reg [2:0] queryContextOutput;
	localparam [31:0] BHT_INDEX_W = $clog2(BHT_ENTRIES);
	localparam [31:0] COND_INDEX_W = $clog2(CONDSEEN_ENTRIES);
	reg [2:0] localPhtInner [0:BHT_ENTRIES - 1];
	reg localHistoryInner [0:BHT_ENTRIES - 1];
	reg [1:0] globalPhtInner [0:BHT_ENTRIES - 1];
	reg [1:0] selectorInner [0:BHT_ENTRIES - 1];
	reg [7:0] ghrInner;
	reg condseenInner [0:CONDSEEN_ENTRIES - 1];
	reg [31:0] queryP2Inner;
	reg [BHT_INDEX_W - 1:0] queryLocalIdxInner;
	reg [BHT_INDEX_W - 1:0] queryGlobalIdxInner;
	reg [BHT_INDEX_W - 1:0] querySelIdxInner;
	reg [COND_INDEX_W - 1:0] queryCondIdxInner;
	reg [31:0] branchP2Inner;
	reg [BHT_INDEX_W - 1:0] branchLocalIdxInner;
	reg [BHT_INDEX_W - 1:0] branchGlobalIdxInner;
	reg [BHT_INDEX_W - 1:0] branchSelIdxInner;
	reg [COND_INDEX_W - 1:0] branchCondIdxInner;
	reg [7:0] ghrNext;
	integer combIndexInner;
	integer seqIndexInner;
	function automatic [BHT_INDEX_W - 1:0] sv2v_cast_14A99;
		input reg [BHT_INDEX_W - 1:0] inp;
		sv2v_cast_14A99 = inp;
	endfunction
	always @* begin
		queryP2Inner = queryPcInput >> 2;
		queryLocalIdxInner = sv2v_cast_14A99({queryP2Inner, localHistoryInner[queryP2Inner[BHT_INDEX_W - 1:0]]});
		queryGlobalIdxInner = queryP2Inner[BHT_INDEX_W - 1:0] ^ ghrInner;
		querySelIdxInner = queryP2Inner[BHT_INDEX_W - 1:0];
		queryCondIdxInner = queryP2Inner[COND_INDEX_W - 1:0];
		predictionOutput[9] = (selectorInner[querySelIdxInner] == 2'b11) && (((globalPhtInner[queryGlobalIdxInner] == 2'b00) || (globalPhtInner[queryGlobalIdxInner] == 2'b11)) || ((localPhtInner[queryLocalIdxInner] == 3'b011) || (localPhtInner[queryLocalIdxInner] == 3'b100)));
		queryContextOutput = {localHistoryInner[queryP2Inner[BHT_INDEX_W - 1:0]], localPhtInner[queryLocalIdxInner] >= 3'b100, globalPhtInner[queryGlobalIdxInner] >= 2'b10};
		predictionOutput[10] = (predictionOutput[9] ? globalPhtInner[queryGlobalIdxInner] >= 2'b10 : localPhtInner[queryLocalIdxInner] >= 3'b100);
		predictionOutput[8] = condseenInner[queryCondIdxInner];
	end
	always @* begin
		branchP2Inner = branchInput[72-:32] >> 2;
		branchLocalIdxInner = sv2v_cast_14A99({branchP2Inner, branchContextInput[2]});
		branchGlobalIdxInner = branchP2Inner[BHT_INDEX_W - 1:0] ^ branchInput[7-:8];
		branchSelIdxInner = branchP2Inner[BHT_INDEX_W - 1:0];
		branchCondIdxInner = branchP2Inner[COND_INDEX_W - 1:0];
	end
	always @* begin
		ghrNext = ghrInner;
		if (historyInput[11] && !historyInput[10]) begin
			if (historyInput[9])
				ghrNext = {ghrInner[6:0], historyInput[8]};
		end
		if (historyInput[10])
			ghrNext = historyInput[7-:8];
	end
	wire [8:1] sv2v_tmp_B181E;
	assign sv2v_tmp_B181E = ghrInner;
	always @(*) predictionOutput[7-:8] = sv2v_tmp_B181E;
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			ghrInner <= 8'd0;
			for (seqIndexInner = 0; seqIndexInner < BHT_ENTRIES; seqIndexInner = seqIndexInner + 1)
				localHistoryInner[seqIndexInner] <= 1'b0;
			for (seqIndexInner = 0; seqIndexInner < BHT_ENTRIES; seqIndexInner = seqIndexInner + 1)
				begin
					globalPhtInner[seqIndexInner] <= 2'b01;
					selectorInner[seqIndexInner] <= 2'b01;
				end
			for (seqIndexInner = 0; seqIndexInner < CONDSEEN_ENTRIES; seqIndexInner = seqIndexInner + 1)
				condseenInner[seqIndexInner] <= 1'b0;
		end
		else if (!freezeInput) begin
			if (branchInput[73]) begin
				localHistoryInner[branchP2Inner[BHT_INDEX_W - 1:0]] <= branchInput[8];
				if (branchInput[8]) begin
					if (globalPhtInner[branchGlobalIdxInner] != 2'b11)
						globalPhtInner[branchGlobalIdxInner] <= globalPhtInner[branchGlobalIdxInner] + 2'b01;
				end
				else if (globalPhtInner[branchGlobalIdxInner] != 2'b00)
					globalPhtInner[branchGlobalIdxInner] <= globalPhtInner[branchGlobalIdxInner] - 2'b01;
				if ((branchContextInput[0] == branchInput[8]) && (branchContextInput[1] != branchInput[8])) begin
					if (selectorInner[branchSelIdxInner] != 2'b11)
						selectorInner[branchSelIdxInner] <= selectorInner[branchSelIdxInner] + 2'b01;
				end
				else if ((branchContextInput[1] == branchInput[8]) && (branchContextInput[0] != branchInput[8])) begin
					if (selectorInner[branchSelIdxInner] != 2'b00)
						selectorInner[branchSelIdxInner] <= selectorInner[branchSelIdxInner] - 2'b01;
				end
				condseenInner[branchCondIdxInner] <= 1'b1;
			end
			ghrInner <= ghrNext;
		end
	genvar _gv_counterRow_1;
	function automatic signed [BHT_INDEX_W - 1:0] sv2v_cast_14A99_signed;
		input reg signed [BHT_INDEX_W - 1:0] inp;
		sv2v_cast_14A99_signed = inp;
	endfunction
	generate
		for (_gv_counterRow_1 = 0; _gv_counterRow_1 < BHT_ENTRIES; _gv_counterRow_1 = _gv_counterRow_1 + 1) begin : g_local_counter
			localparam counterRow = _gv_counterRow_1;
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					localPhtInner[counterRow] <= 3'b011;
				else if ((!freezeInput && branchInput[73]) && (branchLocalIdxInner == sv2v_cast_14A99_signed(counterRow))) begin
					if (localPhtInner[counterRow] != {3 {branchInput[8]}})
						localPhtInner[counterRow] <= {localPhtInner[counterRow][2] ^ ((localPhtInner[counterRow][1] ^ !branchInput[8]) & (localPhtInner[counterRow][0] ^ !branchInput[8])), localPhtInner[counterRow][1] ^ (localPhtInner[counterRow][0] ^ !branchInput[8]), ~localPhtInner[counterRow][0]};
				end
		end
	endgenerate
endmodule
module rv32_bpu_btb (
	clkInput,
	rstNInput,
	freezeInput,
	queryPcInput,
	lookupOutput,
	trainingInput
);
	parameter [31:0] BTB_ENTRIES = 64;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [31:0] queryPcInput;
	output reg [34:0] lookupOutput;
	input wire [206:0] trainingInput;
	localparam [31:0] BTB_INDEX_W = (BTB_ENTRIES > 1 ? $clog2(BTB_ENTRIES) : 1);
	localparam [31:0] BTB_STORAGE_ENTRIES = (BTB_ENTRIES > 0 ? BTB_ENTRIES : 1);
	localparam [31:0] BTB_STATE_LSB = 0;
	localparam [31:0] BTB_STATE_W = 2;
	localparam [31:0] BTB_TGT_LSB = BTB_STATE_LSB + BTB_STATE_W;
	localparam [31:0] BTB_TGT_W = 30;
	localparam [31:0] BTB_TAG_LSB = BTB_TGT_LSB + BTB_TGT_W;
	localparam [31:0] BTB_TAG_W = 32 - (BTB_INDEX_W + 2);
	localparam [31:0] BTB_ENTRY_W = BTB_TAG_LSB + BTB_TAG_W;
	localparam [1:0] BTB_STATE_INVALID = 2'b00;
	localparam [1:0] BTB_STATE_COND = 2'b01;
	localparam [1:0] BTB_STATE_UNCOND = 2'b10;
	localparam [1:0] BTB_STATE_RET = 2'b11;
	reg [BTB_ENTRY_W - 1:0] btbEntryInner [0:BTB_STORAGE_ENTRIES - 1];
	reg [31:0] queryP2Inner;
	reg [BTB_INDEX_W - 1:0] queryBtbIdxInner;
	reg [BTB_ENTRY_W - 1:0] queryEntryInner;
	reg [1:0] queryStateInner;
	reg fetchLineWriteInner;
	reg fetchTargetWriteInner;
	reg [BTB_INDEX_W - 1:0] fetchBtbIdxInner;
	reg jumpLineWriteInner;
	reg jumpTargetWriteInner;
	reg [BTB_INDEX_W - 1:0] jumpBtbIdxInner;
	reg branchLineWriteInner;
	reg branchTargetWriteInner;
	reg [BTB_INDEX_W - 1:0] branchBtbIdxInner;
	reg [1:0] fetchStateNext;
	always @* begin
		queryP2Inner = queryPcInput >> 2;
		queryBtbIdxInner = queryP2Inner[BTB_INDEX_W - 1:0];
		queryEntryInner = btbEntryInner[queryBtbIdxInner];
		queryStateInner = queryEntryInner[BTB_STATE_LSB+:BTB_STATE_W];
		lookupOutput[34] = (queryStateInner != BTB_STATE_INVALID) && (queryEntryInner[BTB_TAG_LSB+:BTB_TAG_W] == queryPcInput[31:BTB_INDEX_W + 2]);
		lookupOutput[33] = (queryStateInner == BTB_STATE_UNCOND) || (queryStateInner == BTB_STATE_RET);
		lookupOutput[32] = queryStateInner == BTB_STATE_RET;
		lookupOutput[31-:32] = {queryEntryInner[BTB_TGT_LSB+:BTB_TGT_W], 2'b00};
	end
	always @* begin
		fetchLineWriteInner = trainingInput[206];
		fetchTargetWriteInner = (trainingInput[206] && !trainingInput[205]) && trainingInput[204];
		fetchBtbIdxInner = trainingInput[172 + (BTB_INDEX_W + 1):174];
		jumpLineWriteInner = trainingInput[65];
		jumpTargetWriteInner = trainingInput[65];
		jumpBtbIdxInner = trainingInput[33 + (BTB_INDEX_W + 1):35];
		branchLineWriteInner = trainingInput[139] && trainingInput[74];
		branchTargetWriteInner = branchLineWriteInner;
		branchBtbIdxInner = trainingInput[107 + (BTB_INDEX_W + 1):109];
		fetchStateNext = (trainingInput[205] ? BTB_STATE_RET : BTB_STATE_UNCOND);
	end
	genvar _gv_row_30;
	function automatic signed [BTB_INDEX_W - 1:0] sv2v_cast_BDC93_signed;
		input reg signed [BTB_INDEX_W - 1:0] inp;
		sv2v_cast_BDC93_signed = inp;
	endfunction
	generate
		for (_gv_row_30 = 0; _gv_row_30 < BTB_STORAGE_ENTRIES; _gv_row_30 = _gv_row_30 + 1) begin : g_entry_write
			localparam row = _gv_row_30;
			always_ff @(posedge clkInput or negedge rstNInput)
				if (!rstNInput)
					btbEntryInner[row] <= 1'sb0;
				else if (!freezeInput) begin
					if (fetchLineWriteInner && (fetchBtbIdxInner == sv2v_cast_BDC93_signed(row))) begin
						btbEntryInner[row][BTB_TAG_LSB+:BTB_TAG_W] <= trainingInput[203:172 + (BTB_INDEX_W + 2)];
						btbEntryInner[row][BTB_STATE_LSB+:BTB_STATE_W] <= fetchStateNext;
					end
					else if (jumpLineWriteInner && (jumpBtbIdxInner == sv2v_cast_BDC93_signed(row))) begin
						btbEntryInner[row][BTB_TAG_LSB+:BTB_TAG_W] <= trainingInput[64:33 + (BTB_INDEX_W + 2)];
						btbEntryInner[row][BTB_STATE_LSB+:BTB_STATE_W] <= (trainingInput[0] ? BTB_STATE_RET : BTB_STATE_UNCOND);
					end
					else if (branchLineWriteInner && (branchBtbIdxInner == sv2v_cast_BDC93_signed(row))) begin
						btbEntryInner[row][BTB_TAG_LSB+:BTB_TAG_W] <= trainingInput[138:107 + (BTB_INDEX_W + 2)];
						btbEntryInner[row][BTB_STATE_LSB+:BTB_STATE_W] <= BTB_STATE_COND;
					end
					if (fetchTargetWriteInner && (fetchBtbIdxInner == sv2v_cast_BDC93_signed(row)))
						btbEntryInner[row][BTB_TGT_LSB+:BTB_TGT_W] <= trainingInput[171:142];
					else if (jumpTargetWriteInner && (jumpBtbIdxInner == sv2v_cast_BDC93_signed(row)))
						btbEntryInner[row][BTB_TGT_LSB+:BTB_TGT_W] <= trainingInput[32:3];
					else if (branchTargetWriteInner && (branchBtbIdxInner == sv2v_cast_BDC93_signed(row)))
						btbEntryInner[row][BTB_TGT_LSB+:BTB_TGT_W] <= trainingInput[106:77];
				end
		end
	endgenerate
`ifndef SYNTHESIS
	initial assert (((BTB_ENTRIES >= 2) && ((BTB_ENTRIES & (BTB_ENTRIES - 1)) == 0)) && (BTB_TAG_W >= 1)) else $fatal(1, "BPU BTB parameter must be power-of-two >=2 with a nonempty PC tag");
`endif
endmodule
module rv32_bpu_ras (
	clkInput,
	rstNInput,
	freezeInput,
	fetchInfoInput,
	squashInput,
	robInput,
	recoveryInput,
	rasTopOutput,
	queryRetTargetOutput
);
	localparam [31:0] rv32_pkg_RAS_ENTRIES = 3;
	parameter [31:0] RAS_ENTRIES = rv32_pkg_RAS_ENTRIES;
	parameter [31:0] COMMIT_WIDTH = 1;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [67:0] fetchInfoInput;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] squashInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	input wire [(COMMIT_WIDTH * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) - 1:0] robInput;
	input wire [22:0] recoveryInput;
	output wire [15:0] rasTopOutput;
	output reg [31:0] queryRetTargetOutput;
	generate
		if (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	localparam [31:0] RAS_PTR_W = (RAS_ENTRIES > 1 ? $clog2(RAS_ENTRIES) : 1);
	localparam [31:0] RAS_STORAGE_ENTRIES = (RAS_ENTRIES > 0 ? RAS_ENTRIES : 1);
	localparam [31:0] RAS_TOP_W = $clog2(RAS_STORAGE_ENTRIES + 1);
	reg [31:0] specRasPcInner [0:RAS_STORAGE_ENTRIES - 1];
	reg [RAS_TOP_W - 1:0] specRasTopInner;
	reg [RAS_TOP_W - 1:0] archRasTopInner;
	reg [RAS_TOP_W - 1:0] specRasTopNext;
	reg [RAS_TOP_W - 1:0] archRasTopNext;
	reg [31:0] specRasPcNext [0:RAS_STORAGE_ENTRIES - 1];
	reg [RAS_TOP_W - 1:0] baselineTopInner;
	reg [RAS_STORAGE_ENTRIES - 1:0] archValidInner;
	reg [RAS_STORAGE_ENTRIES - 1:0] archWriteMaskInner;
	wire [(RAS_STORAGE_ENTRIES * 32) - 1:0] archReadDataInner;
	reg [(RAS_STORAGE_ENTRIES * 32) - 1:0] archWriteDataInner;
	reg archWriteInner;
	reg replayActiveInner;
	reg replayActiveNext;
	reg replayCallInner;
	reg replayRetInner;
	integer normalIndexInner;
	integer recoveryIndexInner;
	integer laneInner;
	integer windowIndexInner;
	reg [4:0] replayTagInner;
	integer seqIndexInner;
	localparam [0:0] RAIL_REPLAY = (rv32_pkg_RECOVERY_WIDTH == 8) && (RAS_STORAGE_ENTRIES == 8);
	wire [RAS_TOP_W - 1:0] replayTop;
	wire replayStillOpen;
	wire [RAS_STORAGE_ENTRIES - 1:0] replayWrite;
	wire [31:0] replayData [0:RAS_STORAGE_ENTRIES - 1];
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	generate
		if (RAIL_REPLAY) begin : g_replay_rails
			function automatic [15:0] advance_depth;
				input reg [15:0] d;
				input reg push;
				input reg pop;
				advance_depth = ((({16 {!push && !pop}} & d) | ({16 {push && !pop}} & ((d & 16'hff00) | ((d & 16'h00ff) << 1)))) | ({16 {!push && pop}} & ((d >> 1) | (d & 16'h0001)))) | ({16 {push && pop}} & (((d & 16'h01fe) | ((d & 16'h0001) << 1)) | ((d & 16'hfe00) >> 1)));
			endfunction
			wire [3:0] initialDepth = (recoveryInput[21] ? baselineTopInner : specRasTopInner);
			wire initialOpen = recoveryInput[21] || replayActiveInner;
			wire [7:0] stop;
			wire [7:0] push;
			wire [7:0] pop;
			wire [255:0] linkPc;
			genvar _gv_i_1;
			for (_gv_i_1 = 0; _gv_i_1 < 8; _gv_i_1 = _gv_i_1 + 1) begin : g_decode
				localparam i = _gv_i_1;
				wire [38:0] item = robInput[0 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) - 1) - (((rv32_pkg_RECOVERY_WIDTH * 39) - 1) - (0 + (i * 39))) : -((0 + (i * 39)) + 38))+:39];
				wire [4:0] expected = recoveryInput[14-:5] + sv2v_cast_60734(i);
				wire inWindow = ((sv2v_cast_32_signed(recoveryInput[19-:5]) + i) < rv32_pkg_ROB_ENTRIES) && ((sv2v_cast_32_signed(recoveryInput[19-:5]) + i) < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]));
				wire tagEqual = item[38-:5] == expected;
				wire eligible = ((initialOpen && !(|(stop & sv2v_cast_8_signed((1 << i) - 1)))) && inWindow) && tagEqual;
				assign stop[i] = inWindow && (!tagEqual || (expected == recoveryInput[9-:5]));
				assign push[i] = eligible && item[0];
				assign pop[i] = eligible && item[1];
				assign linkPc[i * 32+:32] = item[33-:32] + 32'd4;
			end
			assign replayStillOpen = initialOpen && !(|stop);
			wire [15:0] d0 = 16'h0001 << initialDepth;
			wire [15:0] d1 = advance_depth(d0, push[0], pop[0]);
			wire [15:0] d2 = advance_depth(d1, push[1], pop[1]);
			wire [15:0] d3 = advance_depth(d2, push[2], pop[2]);
			wire [15:0] d4 = advance_depth(d3, push[3], pop[3]);
			wire [15:0] d5 = advance_depth(d4, push[4], pop[4]);
			wire [15:0] d6 = advance_depth(d5, push[5], pop[5]);
			wire [15:0] d7 = advance_depth(d6, push[6], pop[6]);
			wire [15:0] d8 = advance_depth(d7, push[7], pop[7]);
			assign replayTop = {|(d8 & 16'hff00), |(d8 & 16'hf0f0), |(d8 & 16'hcccc), |(d8 & 16'haaaa)};
			genvar _gv_slot_3;
			for (_gv_slot_3 = 0; _gv_slot_3 < 8; _gv_slot_3 = _gv_slot_3 + 1) begin : g_slot
				localparam slot = _gv_slot_3;
				wire [7:0] hits;
				assign hits[0] = push[0] && ((d0[slot] && ((slot == 0) || !pop[0])) || (d0[slot + 1] && pop[0]));
				assign hits[1] = push[1] && ((d1[slot] && ((slot == 0) || !pop[1])) || (d1[slot + 1] && pop[1]));
				assign hits[2] = push[2] && ((d2[slot] && ((slot == 0) || !pop[2])) || (d2[slot + 1] && pop[2]));
				assign hits[3] = push[3] && ((d3[slot] && ((slot == 0) || !pop[3])) || (d3[slot + 1] && pop[3]));
				assign hits[4] = push[4] && ((d4[slot] && ((slot == 0) || !pop[4])) || (d4[slot + 1] && pop[4]));
				assign hits[5] = push[5] && ((d5[slot] && ((slot == 0) || !pop[5])) || (d5[slot + 1] && pop[5]));
				assign hits[6] = push[6] && ((d6[slot] && ((slot == 0) || !pop[6])) || (d6[slot + 1] && pop[6]));
				assign hits[7] = push[7] && ((d7[slot] && ((slot == 0) || !pop[7])) || (d7[slot + 1] && pop[7]));
				wire [255:0] data;
				genvar _gv_lane_40;
				for (_gv_lane_40 = 0; _gv_lane_40 < 8; _gv_lane_40 = _gv_lane_40 + 1) begin : g_select
					localparam lane = _gv_lane_40;
					localparam [7:0] YOUNGER = sv2v_cast_8_signed(~((1 << (lane + 1)) - 1));
					wire selected = hits[lane] && !(|(hits & YOUNGER));
					assign data[lane * 32+:32] = linkPc[lane * 32+:32] & {32 {selected}};
				end
				assign replayWrite[slot] = |hits;
				assign replayData[slot] = ((data[0+:32] | data[32+:32]) | (data[64+:32] | data[96+:32])) | ((data[128+:32] | data[160+:32]) | (data[192+:32] | data[224+:32]));
			end
		end
		else begin : g_scalar_restore
			assign replayTop = 1'sb0;
			assign replayStillOpen = 1'b0;
			assign replayWrite = 1'sb0;
			genvar _gv_i_2;
			for (_gv_i_2 = 0; _gv_i_2 < RAS_STORAGE_ENTRIES; _gv_i_2 = _gv_i_2 + 1) begin : genblk1
				localparam i = _gv_i_2;
				assign replayData[i] = 1'sb0;
			end
		end
	endgenerate
	function automatic signed [RAS_TOP_W - 1:0] sv2v_cast_AE1D0_signed;
		input reg signed [RAS_TOP_W - 1:0] inp;
		sv2v_cast_AE1D0_signed = inp;
	endfunction
	function automatic [RAS_PTR_W - 1:0] sv2v_cast_9156D;
		input reg [RAS_PTR_W - 1:0] inp;
		sv2v_cast_9156D = inp;
	endfunction
	always @* if (specRasTopInner == {RAS_TOP_W {1'sb0}})
		queryRetTargetOutput = 32'd0;
	else
		queryRetTargetOutput = specRasPcInner[sv2v_cast_9156D(specRasTopInner - sv2v_cast_AE1D0_signed(1))];
	function automatic [15:0] sv2v_cast_16;
		input reg [15:0] inp;
		sv2v_cast_16 = inp;
	endfunction
	assign rasTopOutput = sv2v_cast_16(specRasTopInner);
	function automatic [RAS_TOP_W - 1:0] sv2v_cast_AE1D0;
		input reg [RAS_TOP_W - 1:0] inp;
		sv2v_cast_AE1D0 = inp;
	endfunction
	always @* begin
		archRasTopNext = archRasTopInner;
		archWriteInner = 1'b0;
		archWriteMaskInner = 1'sb0;
		archWriteDataInner = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] lane;
			for (lane = 0; lane < COMMIT_WIDTH; lane = lane + 1)
				if (((!freezeInput && !squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))]) && !recoveryInput[22]) && robInput[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (1 + (rv32_pkg_ROB_TAG_W + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31))))]) begin
					if (robInput[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 32)] && (archRasTopNext != {RAS_TOP_W {1'sb0}}))
						archRasTopNext = archRasTopNext - sv2v_cast_AE1D0_signed(1);
					if (robInput[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (2 + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31))] && (archRasTopNext < sv2v_cast_AE1D0(RAS_STORAGE_ENTRIES))) begin
						archWriteInner = 1'b1;
						archWriteMaskInner[archRasTopNext[RAS_PTR_W - 1:0]] = 1'b1;
						archWriteDataInner[sv2v_cast_32_signed(archRasTopNext) * 32+:32] = robInput[(lane * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) + (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)-:((((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31) >= (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0) ? ((((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31) - (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0)) + 1 : ((((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 0) - (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) + 31)) + 1)] + 32'd4;
						archRasTopNext = archRasTopNext + sv2v_cast_AE1D0_signed(1);
					end
				end
		end
	end
	sram_fakeram #(
		.DEPTH(1),
		.WIDTH(RAS_STORAGE_ENTRIES * 32),
		.WRITE_GRANULARITY(32)
	) u_arch_sram(
		.clk(clkInput),
		.en((rstNInput && !freezeInput) && (squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || archWriteInner)),
		.we(archWriteInner),
		.wmask(archWriteMaskInner),
		.addr(1'b0),
		.wdata(archWriteDataInner),
		.rdata(archReadDataInner)
	);
	always @* begin
		specRasTopNext = specRasTopInner;
		for (normalIndexInner = 0; normalIndexInner < RAS_STORAGE_ENTRIES; normalIndexInner = normalIndexInner + 1)
			specRasPcNext[normalIndexInner] = specRasPcInner[normalIndexInner];
		if ((!squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] && !recoveryInput[22]) && fetchInfoInput[67]) begin
			if (fetchInfoInput[65] && (specRasTopNext != {RAS_TOP_W {1'sb0}}))
				specRasTopNext = specRasTopNext - sv2v_cast_AE1D0_signed(1);
			if (fetchInfoInput[66] && (specRasTopNext < sv2v_cast_AE1D0(RAS_STORAGE_ENTRIES))) begin
				specRasPcNext[specRasTopNext[RAS_PTR_W - 1:0]] = fetchInfoInput[63-:32] + 32'd4;
				specRasTopNext = specRasTopNext + sv2v_cast_AE1D0_signed(1);
			end
		end
		replayActiveNext = (recoveryInput[21] ? 1'b1 : replayActiveInner);
		replayTagInner = 1'sb0;
		replayCallInner = 1'b0;
		replayRetInner = 1'b0;
		windowIndexInner = 0;
		if (recoveryInput[22]) begin
			if (recoveryInput[21]) begin
				specRasTopNext = baselineTopInner;
				for (recoveryIndexInner = 0; recoveryIndexInner < RAS_STORAGE_ENTRIES; recoveryIndexInner = recoveryIndexInner + 1)
					specRasPcNext[recoveryIndexInner] = (archValidInner[recoveryIndexInner] ? archReadDataInner[recoveryIndexInner * 32+:32] : 32'b00000000000000000000000000000000);
			end
			if (RAIL_REPLAY) begin
				replayActiveNext = replayStillOpen;
				specRasTopNext = replayTop;
				begin : sv2v_autoblock_2
					reg signed [31:0] slot;
					for (slot = 0; slot < RAS_STORAGE_ENTRIES; slot = slot + 1)
						if (replayWrite[slot])
							specRasPcNext[slot] = replayData[slot];
				end
			end
			else
				for (laneInner = 0; laneInner < rv32_pkg_RECOVERY_WIDTH; laneInner = laneInner + 1)
					begin
						windowIndexInner = sv2v_cast_32_signed(recoveryInput[19-:5]) + laneInner;
						replayTagInner = recoveryInput[14-:5] + sv2v_cast_60734(laneInner);
						if ((replayActiveNext && (windowIndexInner < rv32_pkg_ROB_ENTRIES)) && (windowIndexInner < sv2v_cast_32_signed(recoveryInput[4-:rv32_pkg_ROB_TAG_W]))) begin
							if (robInput[0 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) - 1) - (((rv32_pkg_RECOVERY_WIDTH * 39) - 1) - ((laneInner * 39) + 38)) : (5 - ((laneInner * 39) + 38)) - 1)-:5] == replayTagInner) begin
								replayCallInner = robInput[0 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) - 1) - (((rv32_pkg_RECOVERY_WIDTH * 39) - 1) - ((laneInner * 39) + 0)) : -((laneInner * 39) + 0))];
								replayRetInner = robInput[0 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) - 1) - (((rv32_pkg_RECOVERY_WIDTH * 39) - 1) - ((laneInner * 39) + 1)) : -((laneInner * 39) + 1))];
								if (replayRetInner && (specRasTopNext != {RAS_TOP_W {1'sb0}}))
									specRasTopNext = specRasTopNext - sv2v_cast_AE1D0_signed(1);
								if (replayCallInner && (specRasTopNext < sv2v_cast_AE1D0(RAS_STORAGE_ENTRIES))) begin
									specRasPcNext[specRasTopNext[RAS_PTR_W - 1:0]] = robInput[0 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? (((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)) - 1) - (((rv32_pkg_RECOVERY_WIDTH * 39) - 1) - ((laneInner * 39) + 33)) : 31 - ((laneInner * 39) + 33))-:32] + 32'd4;
									specRasTopNext = specRasTopNext + sv2v_cast_AE1D0_signed(1);
								end
								if (replayTagInner == recoveryInput[9-:5])
									replayActiveNext = 1'b0;
							end
							else
								replayActiveNext = 1'b0;
						end
					end
		end
	end
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			specRasTopInner <= 1'sb0;
			archRasTopInner <= 1'sb0;
			baselineTopInner <= 1'sb0;
			archValidInner <= 1'sb0;
			replayActiveInner <= 1'b0;
			for (seqIndexInner = 0; seqIndexInner < RAS_STORAGE_ENTRIES; seqIndexInner = seqIndexInner + 1)
				specRasPcInner[seqIndexInner] <= 1'sb0;
		end
		else if (!freezeInput) begin
			specRasTopInner <= specRasTopNext;
			archRasTopInner <= archRasTopNext;
			if (squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))])
				baselineTopInner <= archRasTopInner;
			if (archWriteInner)
				archValidInner <= archValidInner | archWriteMaskInner;
			if (recoveryInput[22])
				replayActiveInner <= replayActiveNext;
			for (seqIndexInner = 0; seqIndexInner < RAS_STORAGE_ENTRIES; seqIndexInner = seqIndexInner + 1)
				specRasPcInner[seqIndexInner] <= specRasPcNext[seqIndexInner];
		end
`ifndef SYNTHESIS
	initial assert ((RAS_ENTRIES >= 1) && (RAS_ENTRIES <= 255)) else $fatal(1, "BPU RAS parameter must be 1..255 (shared software depth carrier)");
`endif
endmodule
module rv32_bpu_checkpoint (
	clkInput,
	rstNInput,
	freezeInput,
	secondAcceptedInput,
	checkpointInput,
	queryContextInput,
	checkpointOutput,
	branchContextOutput,
	nextCheckpointIdOutput,
	acceptedCountInput
);
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	parameter [31:0] CKPT_ENTRIES = rv32_pkg_BPU_CKPT_ENTRIES;
	parameter [31:0] FETCH_WIDTH = 1;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire secondAcceptedInput;
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 7:0] checkpointInput;
	input wire [2:0] queryContextInput;
	output wire [(16 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] checkpointOutput;
	output wire [2:0] branchContextOutput;
	output wire [rv32_pkg_BPU_CKPT_ID_W - 1:0] nextCheckpointIdOutput;
	input wire [2:0] acceptedCountInput;
	generate
		if (((FETCH_WIDTH != 1) && (FETCH_WIDTH != 2)) && (FETCH_WIDTH != 4)) begin : g_invalid_fetch_width
			initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
		end
	endgenerate
`ifndef SYNTHESIS
	localparam [31:0] rv32_pkg_FETCH_REQUEST_ENTRIES = 8;
	localparam [31:0] rv32_pkg_FQ_ENTRIES = rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH);
	localparam [31:0] rv32_pkg_IQ_ENTRIES = rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH);
	initial assert ((((CKPT_ENTRIES >= 2) && (CKPT_ENTRIES == rv32_pkg_BPU_CKPT_ENTRIES)) && (CKPT_ENTRIES == (1 << rv32_pkg_BPU_CKPT_ID_W))) && (CKPT_ENTRIES >= (((rv32_pkg_ROB_ENTRIES + rv32_pkg_FETCH_REQUEST_ENTRIES) + rv32_pkg_FQ_ENTRIES) + rv32_pkg_IQ_ENTRIES))) else $fatal(1, "BPU checkpoint parameter must match package/CID width and cover configured live budget");
`endif
	localparam [31:0] CKPT_ADDR_W = (CKPT_ENTRIES > 1 ? $clog2(CKPT_ENTRIES) : 1);
	reg [7:0] ckptGhrInner [0:CKPT_ENTRIES - 1];
	reg [2:0] ckptDirectionInner [0:CKPT_ENTRIES - 1];
	reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] nextCkptIdInner;
	reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] nextCkptIdNext;
	integer seqIndexInner;
	function automatic [CKPT_ADDR_W - 1:0] sv2v_cast_A2536;
		input reg [CKPT_ADDR_W - 1:0] inp;
		sv2v_cast_A2536 = inp;
	endfunction
	assign checkpointOutput[rv32_pkg_BPU_CKPT_ID_W + 15-:((rv32_pkg_BPU_CKPT_ID_W + 15) >= (8 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 15) - (8 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((8 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 15)) + 1)] = ckptGhrInner[sv2v_cast_A2536(checkpointInput[rv32_pkg_BPU_CKPT_ID_W + 7-:((rv32_pkg_BPU_CKPT_ID_W + 7) >= 8 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 9 - (rv32_pkg_BPU_CKPT_ID_W + 7))])];
	assign branchContextOutput = ckptDirectionInner[sv2v_cast_A2536(checkpointInput[rv32_pkg_BPU_CKPT_ID_W + 7-:((rv32_pkg_BPU_CKPT_ID_W + 7) >= 8 ? rv32_pkg_BPU_CKPT_ID_W + 0 : 9 - (rv32_pkg_BPU_CKPT_ID_W + 7))])];
	assign checkpointOutput[rv32_pkg_BPU_CKPT_ID_W + 7-:((rv32_pkg_BPU_CKPT_ID_W + 7) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 7) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 7)) + 1)] = ckptGhrInner[sv2v_cast_A2536(checkpointInput[((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7)) - (((38 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (rv32_pkg_BPU_CKPT_ID_W - 1))-:rv32_pkg_BPU_CKPT_ID_W])];
	assign checkpointOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = nextCkptIdInner;
	assign nextCheckpointIdOutput = nextCkptIdInner;
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
	always @* begin
		nextCkptIdNext = nextCkptIdInner;
		if (checkpointInput[1 + ((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7))] && !checkpointInput[((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7)) - (((38 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))))])
			nextCkptIdNext = nextCkptIdInner + (FETCH_WIDTH == 4 ? sv2v_cast_C1E44(acceptedCountInput) : sv2v_cast_C1E44(1) + sv2v_cast_C1E44((FETCH_WIDTH == 2) && secondAcceptedInput));
		if (checkpointInput[((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7)) - (((38 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))))])
			nextCkptIdNext = checkpointInput[((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7)) - (((38 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (rv32_pkg_BPU_CKPT_ID_W - 1))-:rv32_pkg_BPU_CKPT_ID_W] + sv2v_cast_C1E44(1);
	end
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			nextCkptIdInner <= 1'sb0;
			for (seqIndexInner = 0; seqIndexInner < CKPT_ENTRIES; seqIndexInner = seqIndexInner + 1)
				begin
					ckptGhrInner[seqIndexInner] <= 8'd0;
					ckptDirectionInner[seqIndexInner] <= 1'sb0;
				end
		end
		else if (!freezeInput) begin
			if (checkpointInput[1 + ((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7))] && !checkpointInput[((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7)) - (((38 + rv32_pkg_BPU_CKPT_ID_W) - 1) - (1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))))]) begin
				ckptGhrInner[sv2v_cast_A2536(nextCkptIdInner)] <= checkpointInput[7-:8];
				ckptDirectionInner[sv2v_cast_A2536(nextCkptIdInner)] <= queryContextInput;
				if ((FETCH_WIDTH == 2) && secondAcceptedInput) begin
					ckptGhrInner[sv2v_cast_A2536(nextCkptIdInner + sv2v_cast_C1E44(1))] <= checkpointInput[7-:8];
					ckptDirectionInner[sv2v_cast_A2536(nextCkptIdInner + sv2v_cast_C1E44(1))] <= queryContextInput;
				end
				if (FETCH_WIDTH == 4) begin : sv2v_autoblock_1
					reg signed [31:0] lane;
					for (lane = 1; lane < 4; lane = lane + 1)
						if (lane < sv2v_cast_32_signed(acceptedCountInput)) begin
							ckptGhrInner[sv2v_cast_A2536(nextCkptIdInner + sv2v_cast_C1E44(lane))] <= checkpointInput[7-:8];
							ckptDirectionInner[sv2v_cast_A2536(nextCkptIdInner + sv2v_cast_C1E44(lane))] <= queryContextInput;
						end
				end
			end
			nextCkptIdInner <= nextCkptIdNext;
		end
`ifndef SYNTHESIS
	always @(posedge clkInput)
		if (((rstNInput && !freezeInput) && checkpointInput[1 + ((38 + rv32_pkg_BPU_CKPT_ID_W) + (rv32_pkg_BPU_CKPT_ID_W + 7))]) && (FETCH_WIDTH == 4))
			assert ((acceptedCountInput >= 1) && (acceptedCountInput <= 4)) else $fatal(1, "invalid four-fetch checkpoint prefix");
`endif
endmodule
module rv32_predictor (
	clkInput,
	rstNInput,
	freezeInput,
	queryPcInput,
	predictionOutput,
	fetchAcceptInput,
	fetchPredictInput,
	fetchSecondInput,
	fetchInfoInput,
	branchInput,
	jumpInput,
	squashInput,
	robInput,
	recoveryInput,
	fetchCountInput
);
	parameter [31:0] BHT_ENTRIES = 256;
	parameter [31:0] BTB_ENTRIES = 32;
	localparam [31:0] rv32_pkg_RAS_ENTRIES = 3;
	parameter [31:0] RAS_ENTRIES = rv32_pkg_RAS_ENTRIES;
	parameter [31:0] CONDSEEN_ENTRIES = 512;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	parameter [31:0] CKPT_ENTRIES = rv32_pkg_BPU_CKPT_ENTRIES;
	parameter [31:0] COMMIT_WIDTH = 1;
	parameter [31:0] FETCH_WIDTH = 1;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire [31:0] queryPcInput;
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	output reg [(33 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] predictionOutput;
	input wire fetchAcceptInput;
	input wire fetchPredictInput;
	input wire fetchSecondInput;
	input wire [67:0] fetchInfoInput;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [(72 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] branchInput;
	input wire [71:0] jumpInput;
	input wire [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] squashInput;
	localparam [31:0] rv32_pkg_ISSUE_WIDTH = 4;
	localparam [31:0] rv32_pkg_RECOVERY_BEATS = 2;
	localparam [31:0] rv32_pkg_RECOVERY_WIDTH = ((rv32_pkg_ROB_ENTRIES + rv32_pkg_RECOVERY_BEATS) - 1) / rv32_pkg_RECOVERY_BEATS;
	input wire [(COMMIT_WIDTH * (40 + ((rv32_pkg_RECOVERY_WIDTH * 39) >= 1 ? rv32_pkg_RECOVERY_WIDTH * 39 : 2 - (rv32_pkg_RECOVERY_WIDTH * 39)))) - 1:0] robInput;
	input wire [22:0] recoveryInput;
	input wire [2:0] fetchCountInput;
	generate
		if (((FETCH_WIDTH != 1) && (FETCH_WIDTH != 2)) && (FETCH_WIDTH != 4)) begin : g_invalid_fetch_width
			initial $fatal(1, "FETCH_WIDTH must be 1, 2 or 4");
		end
		if (((COMMIT_WIDTH != 1) && (COMMIT_WIDTH != 2)) && (COMMIT_WIDTH != 4)) begin : g_invalid_commit_width
			initial $fatal(1, "COMMIT_WIDTH must be 1, 2 or 4");
		end
	endgenerate
	wire dirTakenInner;
	wire dirUseGlobalInner;
	wire dirCondseenInner;
	wire [7:0] dirGhrInner;
	wire [7:0] branchGhrInner;
	wire [10:0] directionOutputInner;
	wire [2:0] queryDirectionContextInner;
	wire [2:0] branchDirectionContextInner;
	wire btbHitInner;
	wire btbUncondInner;
	wire btbRetInner;
	wire [31:0] btbTgtInner;
	wire [34:0] btbLookupOutputInner;
	wire [15:0] rasTopInner;
	wire [31:0] rasRetTargetInner;
	wire [7:0] ckptSquashGhrInner;
	wire [(16 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] checkpointOutputInner;
	reg branchTrainInner;
	reg jumpTrainInner;
	reg queryBtbHitInner;
	reg queryDirTakenInner;
	reg queryIsRetInner;
	reg queryTakenInner;
	reg queryShiftInner;
	reg queryShiftValueInner;
	reg [31:0] queryTargetInner;
	wire [206:0] trainingBatchInner;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [73:0] sv2v_cast_74;
		input reg [73:0] inp;
		sv2v_cast_74 = inp;
	endfunction
	function automatic [11:0] sv2v_cast_12;
		input reg [11:0] inp;
		sv2v_cast_12 = inp;
	endfunction
	rv32_bpu_direction #(
		.BHT_ENTRIES(BHT_ENTRIES),
		.CONDSEEN_ENTRIES(CONDSEEN_ENTRIES)
	) u_direction(
		.freezeInput(freezeInput),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.queryPcInput(queryPcInput),
		.branchInput(sv2v_cast_74({branchTrainInner, sv2v_cast_32(branchInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (33 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (33 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((33 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)]), sv2v_cast_32(branchInput[rv32_pkg_BPU_CKPT_ID_W + 32-:((rv32_pkg_BPU_CKPT_ID_W + 32) >= (1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 32) - (1 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 32)) + 1)]), branchInput[rv32_pkg_BPU_CKPT_ID_W + 0], branchGhrInner})),
		.branchContextInput(branchDirectionContextInner),
		.historyInput(sv2v_cast_12({fetchAcceptInput && ((FETCH_WIDTH == 32'sd1) || fetchPredictInput), squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))], queryShiftInner, queryShiftValueInner, ckptSquashGhrInner})),
		.predictionOutput(directionOutputInner),
		.queryContextOutput(queryDirectionContextInner)
	);
	assign dirTakenInner = directionOutputInner[10];
	assign dirUseGlobalInner = directionOutputInner[9];
	assign dirCondseenInner = directionOutputInner[8];
	assign dirGhrInner = directionOutputInner[7-:8];
	assign trainingBatchInner = {fetchInfoInput[67], fetchInfoInput[65], fetchInfoInput[64], sv2v_cast_32(fetchInfoInput[63-:32]), sv2v_cast_32(fetchInfoInput[31-:32]), sv2v_cast_74({branchTrainInner, sv2v_cast_32(branchInput[64 + (rv32_pkg_BPU_CKPT_ID_W + 0)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) >= (33 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (33 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((33 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1)]), sv2v_cast_32(branchInput[rv32_pkg_BPU_CKPT_ID_W + 32-:((rv32_pkg_BPU_CKPT_ID_W + 32) >= (1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 32) - (1 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 32)) + 1)]), branchInput[rv32_pkg_BPU_CKPT_ID_W + 0], branchGhrInner}), jumpTrainInner, sv2v_cast_32(jumpInput[64-:32]), sv2v_cast_32(jumpInput[32-:32]), jumpInput[0]};
	rv32_bpu_btb #(.BTB_ENTRIES(BTB_ENTRIES)) u_btb(
		.freezeInput(freezeInput),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.queryPcInput(queryPcInput),
		.lookupOutput(btbLookupOutputInner),
		.trainingInput(trainingBatchInner)
	);
	assign btbHitInner = btbLookupOutputInner[34];
	assign btbUncondInner = btbLookupOutputInner[33];
	assign btbRetInner = btbLookupOutputInner[32];
	assign btbTgtInner = btbLookupOutputInner[31-:32];
	rv32_bpu_ras #(
		.RAS_ENTRIES(RAS_ENTRIES),
		.COMMIT_WIDTH(COMMIT_WIDTH)
	) u_ras(
		.freezeInput(freezeInput),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.fetchInfoInput(fetchInfoInput),
		.squashInput(squashInput),
		.robInput(robInput),
		.recoveryInput(recoveryInput),
		.rasTopOutput(rasTopInner),
		.queryRetTargetOutput(rasRetTargetInner)
	);
	wire [rv32_pkg_BPU_CKPT_ID_W * 1:1] sv2v_tmp_u_checkpoint_nextCheckpointIdOutput;
	always @(*) predictionOutput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W] = sv2v_tmp_u_checkpoint_nextCheckpointIdOutput;
	function automatic [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] sv2v_cast_A9A22;
		input reg [(38 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] inp;
		sv2v_cast_A9A22 = inp;
	endfunction
	function automatic [rv32_pkg_BPU_CKPT_ID_W - 1:0] sv2v_cast_C1E44;
		input reg [rv32_pkg_BPU_CKPT_ID_W - 1:0] inp;
		sv2v_cast_C1E44 = inp;
	endfunction
	function automatic [((((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 7) >= 0 ? ((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 8 : 1 - (((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 7)) - 1:0] sv2v_cast_465C7;
		input reg [((((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 7) >= 0 ? ((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 8 : 1 - (((39 + rv32_pkg_BPU_CKPT_ID_W) + rv32_pkg_BPU_CKPT_ID_W) + 7)) - 1:0] inp;
		sv2v_cast_465C7 = inp;
	endfunction
	rv32_bpu_checkpoint #(
		.CKPT_ENTRIES(CKPT_ENTRIES),
		.FETCH_WIDTH(FETCH_WIDTH)
	) u_checkpoint(
		.freezeInput(freezeInput),
		.clkInput(clkInput),
		.rstNInput(rstNInput),
		.secondAcceptedInput(fetchSecondInput),
		.acceptedCountInput(fetchCountInput),
		.checkpointInput(sv2v_cast_465C7({fetchAcceptInput, sv2v_cast_A9A22(squashInput), sv2v_cast_C1E44(branchInput[rv32_pkg_BPU_CKPT_ID_W - 1-:rv32_pkg_BPU_CKPT_ID_W]), dirGhrInner})),
		.checkpointOutput(checkpointOutputInner),
		.queryContextInput(queryDirectionContextInner),
		.branchContextOutput(branchDirectionContextInner),
		.nextCheckpointIdOutput(sv2v_tmp_u_checkpoint_nextCheckpointIdOutput)
	);
	assign branchGhrInner = checkpointOutputInner[rv32_pkg_BPU_CKPT_ID_W + 15-:((rv32_pkg_BPU_CKPT_ID_W + 15) >= (8 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 15) - (8 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((8 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 15)) + 1)];
	assign ckptSquashGhrInner = checkpointOutputInner[rv32_pkg_BPU_CKPT_ID_W + 7-:((rv32_pkg_BPU_CKPT_ID_W + 7) >= (rv32_pkg_BPU_CKPT_ID_W + 0) ? ((rv32_pkg_BPU_CKPT_ID_W + 7) - (rv32_pkg_BPU_CKPT_ID_W + 0)) + 1 : ((rv32_pkg_BPU_CKPT_ID_W + 0) - (rv32_pkg_BPU_CKPT_ID_W + 7)) + 1)];
	wire unusedDirUseGlobalInner;
	assign unusedDirUseGlobalInner = dirUseGlobalInner;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	always @* begin
		branchTrainInner = (branchInput[1 + (rv32_pkg_ROB_TAG_W + (33 + (rv32_pkg_BPU_CKPT_ID_W + 32)))] && branchInput[33 + (rv32_pkg_BPU_CKPT_ID_W + 32)]) && (!squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || rv32_pkg_rob_is_older(branchInput[rv32_pkg_ROB_TAG_W + (33 + (rv32_pkg_BPU_CKPT_ID_W + 32))-:((38 + (rv32_pkg_BPU_CKPT_ID_W + 32)) >= (66 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (33 + (rv32_pkg_BPU_CKPT_ID_W + 32))) - (66 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((66 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (33 + (rv32_pkg_BPU_CKPT_ID_W + 32)))) + 1)], squashInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)]));
		jumpTrainInner = (jumpInput[71] && jumpInput[65]) && (!squashInput[1 + (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))] || rv32_pkg_rob_is_older(jumpInput[70-:5], squashInput[rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (32 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((32 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_ROB_TAG_W + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)]));
	end
	always @* begin
		queryDirTakenInner = dirTakenInner;
		queryBtbHitInner = btbHitInner;
		queryTakenInner = queryBtbHitInner && queryDirTakenInner;
		if (queryBtbHitInner && btbUncondInner)
			queryTakenInner = 1'b1;
		queryIsRetInner = btbRetInner;
		if (queryIsRetInner && (rasTopInner == 0)) begin
			queryBtbHitInner = 1'b0;
			queryTakenInner = 1'b0;
		end
		queryTargetInner = btbTgtInner;
		if (queryIsRetInner && (rasTopInner != 0))
			queryTargetInner = rasRetTargetInner;
		queryShiftInner = queryBtbHitInner || dirCondseenInner;
		queryShiftValueInner = (queryBtbHitInner ? (btbUncondInner ? 1'b1 : queryTakenInner) : (dirCondseenInner ? queryTakenInner : 1'b0));
		predictionOutput[rv32_pkg_BPU_CKPT_ID_W + 0] = queryTakenInner;
		predictionOutput[rv32_pkg_BPU_CKPT_ID_W + 32-:((rv32_pkg_BPU_CKPT_ID_W + 32) >= (1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((rv32_pkg_BPU_CKPT_ID_W + 32) - (1 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((1 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (rv32_pkg_BPU_CKPT_ID_W + 32)) + 1)] = (queryTakenInner ? queryTargetInner : queryPcInput + 32'd4);
	end
endmodule
module rv32_alu (
	aluInput,
	aluOutput
);
	input wire [134:0] aluInput;
	output reg [31:0] aluOutput;
	wire [31:0] operandBInner;
	wire [31:0] sumAddInner;
	wire subtractInner;
	wire [31:0] arithmeticOperandBInner;
	wire [31:0] sumAuipcInner;
	wire unusedCoutAddInner;
	wire unusedCoutAuipcInner;
	assign operandBInner = (aluInput[0] ? aluInput[64-:32] : aluInput[96-:32]);
	assign subtractInner = aluInput[134-:6] == 6'd2;
	assign arithmeticOperandBInner = operandBInner ^ {32 {subtractInner}};
	rv32_add #(.WIDTH(32)) u_add(
		.aInput(aluInput[128-:32]),
		.bInput(arithmeticOperandBInner),
		.cinInput(subtractInner),
		.sumOutput(sumAddInner),
		.coutOutput(unusedCoutAddInner)
	);
	rv32_add #(.WIDTH(32)) u_auipc(
		.aInput(aluInput[32-:32]),
		.bInput(aluInput[64-:32]),
		.cinInput(1'b0),
		.sumOutput(sumAuipcInner),
		.coutOutput(unusedCoutAuipcInner)
	);
	always @* (* full_case, parallel_case *)
	case (aluInput[134-:6])
		6'd1: aluOutput[31-:32] = sumAddInner;
		6'd2: aluOutput[31-:32] = sumAddInner;
		6'd3: aluOutput[31-:32] = aluInput[128-:32] << operandBInner[4:0];
		6'd4: aluOutput[31-:32] = {31'b0000000000000000000000000000000, $signed(aluInput[128-:32]) < $signed(operandBInner)};
		6'd5: aluOutput[31-:32] = {31'b0000000000000000000000000000000, aluInput[128-:32] < operandBInner};
		6'd6: aluOutput[31-:32] = aluInput[128-:32] ^ operandBInner;
		6'd7: aluOutput[31-:32] = aluInput[128-:32] >> operandBInner[4:0];
		6'd8: aluOutput[31-:32] = $unsigned($signed(aluInput[128-:32]) >>> operandBInner[4:0]);
		6'd9: aluOutput[31-:32] = aluInput[128-:32] | operandBInner;
		6'd10: aluOutput[31-:32] = aluInput[128-:32] & operandBInner;
		6'd11: aluOutput[31-:32] = aluInput[64-:32];
		6'd12: aluOutput[31-:32] = sumAuipcInner;
		6'd27: aluOutput[31-:32] = sumAuipcInner;
		6'd28: aluOutput[31-:32] = sumAddInner & 32'hfffffffe;
		default: aluOutput[31-:32] = 32'b00000000000000000000000000000000;
	endcase
endmodule
module rv32_alu_unit (
	clkInput,
	rstNInput,
	freezeInput,
	flushInfoInput,
	executeInput,
	inReadyOutput,
	outReadyInput,
	executeOutput,
	occupancyOutput
);
	localparam [31:0] rv32_pkg_ALU_RESULT_ENTRIES = 1;
	parameter [31:0] DEPTH = rv32_pkg_ALU_RESULT_ENTRIES;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] flushInfoInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [181:0] executeInput;
	output reg inReadyOutput;
	input wire outReadyInput;
	output wire [45:0] executeOutput;
	output reg [$clog2(DEPTH + 1) - 1:0] occupancyOutput;
	localparam [31:0] INDEX_W = (DEPTH <= 1 ? 1 : $clog2(DEPTH));
	reg [134:0] operandsInner [0:DEPTH - 1];
	wire [31:0] aluOutputInner [0:DEPTH - 1];
	wire [31:0] valueInner [0:DEPTH - 1];
	reg [4:0] tagInner [0:DEPTH - 1];
	reg [5:0] phyInner [0:DEPTH - 1];
	reg controlInner [0:DEPTH - 1];
	reg validInner [0:DEPTH - 1];
	reg headFoundInner;
	reg [INDEX_W - 1:0] headIndexInner;
	reg allocFoundInner;
	reg [INDEX_W - 1:0] allocIndexInner;
	wire pushHereInner;
	wire pushFlushedInner;
	reg removedInner [0:DEPTH - 1];
	reg flushedInner [0:DEPTH - 1];
	integer combIndexInner;
	integer seqIndexInner;
	genvar _gv_slot_4;
	generate
		for (_gv_slot_4 = 0; _gv_slot_4 < DEPTH; _gv_slot_4 = _gv_slot_4 + 1) begin : g_registered_operands
			localparam slot = _gv_slot_4;
			rv32_alu u_alu(
				.aluInput(operandsInner[slot]),
				.aluOutput(aluOutputInner[slot])
			);
			assign valueInner[slot] = aluOutputInner[slot][31-:32];
		end
	endgenerate
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	function automatic signed [INDEX_W - 1:0] sv2v_cast_3C754_signed;
		input reg signed [INDEX_W - 1:0] inp;
		sv2v_cast_3C754_signed = inp;
	endfunction
	always @* begin
		headFoundInner = 1'b0;
		headIndexInner = 1'sb0;
		begin : sv2v_autoblock_3
			reg signed [31:0] headRow;
			for (headRow = 0; headRow < DEPTH; headRow = headRow + 1)
				if (validInner[headRow] && (!headFoundInner || rv32_pkg_rob_is_older(tagInner[headRow], tagInner[headIndexInner]))) begin
					headFoundInner = 1'b1;
					headIndexInner = sv2v_cast_3C754_signed(headRow);
				end
		end
	end
	assign executeOutput[45] = headFoundInner;
	assign executeOutput[44-:32] = valueInner[headIndexInner];
	assign executeOutput[12-:5] = tagInner[headIndexInner];
	assign executeOutput[7-:6] = phyInner[headIndexInner];
	assign executeOutput[1] = controlInner[headIndexInner];
	assign executeOutput[0] = 1'b0;
	always @* begin
		for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
			begin
				removedInner[combIndexInner] = ((outReadyInput && headFoundInner) && validInner[combIndexInner]) && (tagInner[combIndexInner] == tagInner[headIndexInner]);
				flushedInner[combIndexInner] = (flushInfoInput[5] && validInner[combIndexInner]) && !rv32_pkg_rob_is_older(tagInner[combIndexInner], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]);
			end
		allocFoundInner = 1'b0;
		allocIndexInner = 1'sb0;
		for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
			if (!allocFoundInner && ((!validInner[combIndexInner] || removedInner[combIndexInner]) || flushedInner[combIndexInner])) begin
				allocFoundInner = 1'b1;
				allocIndexInner = combIndexInner[INDEX_W - 1:0];
			end
		inReadyOutput = allocFoundInner;
		occupancyOutput = 1'sb0;
		for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
			if (validInner[combIndexInner])
				occupancyOutput = occupancyOutput + 1'b1;
	end
	assign pushHereInner = executeInput[181] && allocFoundInner;
	assign pushFlushedInner = flushInfoInput[5] && !rv32_pkg_rob_is_older(executeInput[13-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]);
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput)
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				begin
					validInner[seqIndexInner] <= 1'b0;
					operandsInner[seqIndexInner] <= 1'sb0;
					tagInner[seqIndexInner] <= 1'sb0;
					phyInner[seqIndexInner] <= 1'sb0;
					controlInner[seqIndexInner] <= 1'b0;
				end
		else if (!freezeInput) begin
			for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1)
				if (pushHereInner && (seqIndexInner[INDEX_W - 1:0] == allocIndexInner)) begin
					operandsInner[seqIndexInner] <= {sv2v_cast_6(executeInput[180-:6]), sv2v_cast_32(executeInput[174-:32]), sv2v_cast_32(executeInput[142-:32]), sv2v_cast_32(executeInput[110-:32]), sv2v_cast_32(executeInput[78-:32]), executeInput[14]};
					tagInner[seqIndexInner] <= executeInput[13-:5];
					phyInner[seqIndexInner] <= executeInput[8-:6];
					controlInner[seqIndexInner] <= executeInput[2];
					validInner[seqIndexInner] <= !pushFlushedInner;
				end
				else if (flushedInner[seqIndexInner])
					validInner[seqIndexInner] <= 1'b0;
				else if (removedInner[seqIndexInner])
					validInner[seqIndexInner] <= 1'b0;
		end
endmodule
module rv32_agu_unit (
	clkInput,
	rstNInput,
	freezeInput,
	flushInfoInput,
	executeInput,
	auxiliaryInput,
	inReadyOutput,
	addressOutput,
	auxiliaryOutput,
	robTagOutput
);
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] flushInfoInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [178:0] executeInput;
	localparam [31:0] rv32_pkg_LQ_ENTRIES = 4;
	localparam [31:0] rv32_pkg_SQ_ENTRIES = 4;
	localparam [31:0] rv32_pkg_SQ_SLOT_W = 2;
	localparam [31:0] rv32_pkg_LSQ_SLOT_W = rv32_pkg_SQ_SLOT_W;
	input wire [rv32_pkg_LSQ_SLOT_W:0] auxiliaryInput;
	output wire inReadyOutput;
	output wire [38:0] addressOutput;
	output wire [rv32_pkg_LSQ_SLOT_W:0] auxiliaryOutput;
	output wire [4:0] robTagOutput;
	wire [31:0] sumInner;
	wire [15:0] lowSumInner;
	wire [15:0] highZeroSumInner;
	wire [15:0] highOneSumInner;
	wire lowCarryInner;
	wire highZeroCarryInner;
	wire highOneCarryInner;
	reg validInner;
	reg [31:0] addressInner;
	reg [rv32_pkg_LSQ_SLOT_W:0] auxiliaryInner;
	reg [4:0] robTagInner;
	rv32_add #(.WIDTH(16)) u_add_low(
		.aInput(executeInput[144:129]),
		.bInput(executeInput[80:65]),
		.cinInput(1'b0),
		.sumOutput(lowSumInner),
		.coutOutput(lowCarryInner)
	);
	rv32_add #(.WIDTH(16)) u_add_high_zero(
		.aInput(executeInput[160:145]),
		.bInput(executeInput[96:81]),
		.cinInput(1'b0),
		.sumOutput(highZeroSumInner),
		.coutOutput(highZeroCarryInner)
	);
	rv32_add #(.WIDTH(16)) u_add_high_one(
		.aInput(executeInput[160:145]),
		.bInput(executeInput[96:81]),
		.cinInput(1'b1),
		.sumOutput(highOneSumInner),
		.coutOutput(highOneCarryInner)
	);
	assign sumInner[31-:32] = {(lowCarryInner ? highOneSumInner : highZeroSumInner), lowSumInner};
	assign inReadyOutput = 1'b1;
	assign robTagOutput = robTagInner;
	assign auxiliaryOutput = auxiliaryInner;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	function automatic [4:0] sv2v_cast_60734;
		input reg [4:0] inp;
		sv2v_cast_60734 = inp;
	endfunction
	assign addressOutput = {validInner && (!flushInfoInput[5] || rv32_pkg_rob_is_older(robTagInner, flushInfoInput[4-:rv32_pkg_ROB_TAG_W])), auxiliaryInner[rv32_pkg_LSQ_SLOT_W], sv2v_cast_60734(robTagInner), addressInner};
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			validInner <= 1'b0;
			addressInner <= 1'sb0;
			auxiliaryInner <= 1'sb0;
			robTagInner <= 1'sb0;
		end
		else if (!freezeInput) begin
			validInner <= executeInput[178] && (!flushInfoInput[5] || rv32_pkg_rob_is_older(executeInput[171-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
			if (executeInput[178]) begin
				addressInner <= sumInner[31-:32];
				auxiliaryInner <= auxiliaryInput;
				robTagInner <= executeInput[171-:5];
			end
		end
endmodule
module rv32_bru (
	branchInput,
	branchOutput
);
	parameter [0:0] CONDITIONAL_ONLY = 1'b0;
	input wire [165:0] branchInput;
	output reg [98:0] branchOutput;
	reg conditionInner;
	wire [31:0] pcPlus4Inner;
	wire [31:0] pcPlusImmInner;
	wire [31:0] src1PlusImmInner;
	wire unusedCoutPcimmInner;
	wire unusedCoutSrc1immInner;
	assign pcPlus4Inner = {branchInput[63:34] + 30'd1, branchInput[33:32]};
	rv32_add #(.WIDTH(32)) u_pc_plus_imm(
		.aInput(branchInput[63-:32]),
		.bInput(branchInput[95-:32]),
		.cinInput(1'b0),
		.sumOutput(pcPlusImmInner),
		.coutOutput(unusedCoutPcimmInner)
	);
	generate
		if (!CONDITIONAL_ONLY) begin : g_jump_target
			rv32_add #(.WIDTH(32)) u_src1_plus_imm(
				.aInput(branchInput[159-:32]),
				.bInput(branchInput[95-:32]),
				.cinInput(1'b0),
				.sumOutput(src1PlusImmInner),
				.coutOutput(unusedCoutSrc1immInner)
			);
		end
		else begin : g_conditional_target
			assign src1PlusImmInner = 1'sb0;
			assign unusedCoutSrc1immInner = 1'b0;
		end
	endgenerate
	always @* begin
		conditionInner = 1'b0;
		(* full_case, parallel_case *)
		case (branchInput[165-:6])
			6'd21: conditionInner = branchInput[159-:32] == branchInput[127-:32];
			6'd22: conditionInner = branchInput[159-:32] != branchInput[127-:32];
			6'd23: conditionInner = $signed(branchInput[159-:32]) < $signed(branchInput[127-:32]);
			6'd24: conditionInner = $signed(branchInput[159-:32]) >= $signed(branchInput[127-:32]);
			6'd25: conditionInner = branchInput[159-:32] < branchInput[127-:32];
			6'd26: conditionInner = branchInput[159-:32] >= branchInput[127-:32];
			6'd27, 6'd28: conditionInner = 1'b1;
			default: conditionInner = 1'b0;
		endcase
		branchOutput[98] = conditionInner;
		branchOutput[33-:32] = pcPlus4Inner;
		if (!CONDITIONAL_ONLY && (branchInput[165-:6] == 6'd28)) begin
			branchOutput[97-:32] = src1PlusImmInner & 32'hfffffffe;
			branchOutput[65-:32] = src1PlusImmInner & 32'hfffffffe;
		end
		else begin
			branchOutput[97-:32] = pcPlusImmInner;
			if (conditionInner)
				branchOutput[65-:32] = pcPlusImmInner;
			else
				branchOutput[65-:32] = pcPlus4Inner;
		end
		branchOutput[0] = 1'b0;
		branchOutput[1] = branchOutput[65-:32] != branchInput[31-:32];
	end
endmodule
module rv32_bru_unit (
	clkInput,
	rstNInput,
	freezeInput,
	flushInput,
	flushTagInput,
	executeInput,
	inReadyOutput,
	executeOutput
);
	parameter [0:0] CONDITIONAL_ONLY = 1'b0;
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	input wire flushInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [4:0] flushTagInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [181:0] executeInput;
	output wire inReadyOutput;
	output reg [139:0] executeOutput;
	wire bruTakenInner;
	wire bruMispredictInner;
	wire [31:0] bruTargetInner;
	wire [31:0] bruNextPcInner;
	wire [31:0] bruLinkInner;
	wire [98:0] bruOperationOutputInner;
	reg validInner;
	reg [4:0] tagInner;
	reg [31:0] pcInner;
	reg [31:0] targetInner;
	reg [31:0] nextPcInner;
	reg [31:0] returnAddressInner;
	reg takenInner;
	reg conditionalInner;
	reg mispredictInner;
	reg callInner;
	reg returnInner;
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [165:0] sv2v_cast_166;
		input reg [165:0] inp;
		sv2v_cast_166 = inp;
	endfunction
	rv32_bru #(.CONDITIONAL_ONLY(CONDITIONAL_ONLY)) u_bru(
		.branchInput(sv2v_cast_166({sv2v_cast_6(executeInput[180-:6]), sv2v_cast_32(executeInput[174-:32]), sv2v_cast_32(executeInput[142-:32]), sv2v_cast_32(executeInput[110-:32]), sv2v_cast_32(executeInput[78-:32]), sv2v_cast_32(executeInput[46-:32])})),
		.branchOutput(bruOperationOutputInner)
	);
	assign bruTakenInner = bruOperationOutputInner[98];
	assign bruTargetInner = bruOperationOutputInner[97-:32];
	assign bruNextPcInner = bruOperationOutputInner[65-:32];
	assign bruLinkInner = bruOperationOutputInner[33-:32];
	assign bruMispredictInner = bruOperationOutputInner[1];
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	assign inReadyOutput = (!executeInput[181] || !flushInput) || rv32_pkg_rob_is_older(executeInput[13-:5], flushTagInput);
	always @* begin
		executeOutput[139] = validInner && (!flushInput || rv32_pkg_rob_is_older(tagInner, flushTagInput));
		executeOutput[138-:5] = tagInner;
		executeOutput[133-:32] = pcInner;
		executeOutput[101-:32] = targetInner;
		executeOutput[69-:32] = nextPcInner;
		executeOutput[37-:32] = returnAddressInner;
		executeOutput[5] = takenInner;
		executeOutput[4] = conditionalInner;
		executeOutput[3] = mispredictInner;
		executeOutput[2] = 1'b0;
		executeOutput[1] = callInner;
		executeOutput[0] = returnInner;
	end
`ifndef SYNTHESIS
	generate
		if (CONDITIONAL_ONLY) begin : g_conditional_contract
			always @(posedge clkInput)
				if (((rstNInput && !freezeInput) && executeInput[181]) && inReadyOutput)
					assert ((((((executeInput[180-:6] == 6'd21) || (executeInput[180-:6] == 6'd22)) || (executeInput[180-:6] == 6'd23)) || (executeInput[180-:6] == 6'd24)) || (executeInput[180-:6] == 6'd25)) || (executeInput[180-:6] == 6'd26)) else $fatal(1, "conditional-only BRU accepted a non-conditional operation");
		end
	endgenerate
`endif
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			validInner <= 1'b0;
			tagInner <= 1'sb0;
			pcInner <= 1'sb0;
			targetInner <= 1'sb0;
			nextPcInner <= 1'sb0;
			returnAddressInner <= 1'sb0;
			takenInner <= 1'b0;
			conditionalInner <= 1'b0;
			mispredictInner <= 1'b0;
			callInner <= 1'b0;
			returnInner <= 1'b0;
		end
		else if (!freezeInput) begin
			validInner <= executeInput[181] && inReadyOutput;
			if (executeInput[181] && inReadyOutput) begin
				tagInner <= executeInput[13-:5];
				pcInner <= executeInput[78-:32];
				targetInner <= bruTargetInner;
				nextPcInner <= bruNextPcInner;
				returnAddressInner <= bruLinkInner;
				takenInner <= bruTakenInner;
				conditionalInner <= !((executeInput[180-:6] == 6'd27) || (executeInput[180-:6] == 6'd28));
				mispredictInner <= bruMispredictInner;
				callInner <= executeInput[1];
				returnInner <= executeInput[0];
			end
		end
endmodule
module rv32_mul (
	clkInput,
	rstNInput,
	freezeInput,
	flushInfoInput,
	executeInput,
	inReadyOutput,
	outReadyInput,
	executeOutput
);
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] flushInfoInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [181:0] executeInput;
	output reg inReadyOutput;
	input wire outReadyInput;
	output reg [43:0] executeOutput;
	localparam [31:0] PRODUCT_W = 64;
	reg [2:0] validInner;
	wire [2:0] keepValidInner;
	wire inputLiveInner;
	reg [63:0] boothRowsRegisteredInner [0:5];
	reg [63:0] csaSumInner;
	reg [63:0] csaCarryInner;
	reg [31:0] resultInner;
	reg highInner [0:1];
	reg [4:0] tagInner [0:2];
	reg [5:0] phyInner [0:2];
	reg resultCanAcceptInner;
	reg CSACanAcceptInner;
	reg partialCanAcceptInner;
	reg lhsSignedInner;
	reg rhsSignedInner;
	reg [63:0] boothMultiplicandInner;
	reg [34:0] boothMultiplierInner;
	reg [63:0] boothRowsInner [0:17];
	reg [63:0] boothCorrectionInner;
	reg [63:0] compressL1Inner [0:11];
	reg [63:0] compressL2Inner [0:7];
	reg [63:0] compressL3Inner [0:5];
	reg [63:0] csaL1Inner [0:3];
	reg [63:0] csaL2Inner [0:2];
	reg [63:0] csaSumDInner;
	reg [63:0] csaCarryDInner;
	wire [63:0] finalProductInner;
	wire finalCarryUnusedInner;
	integer boothIndexInner;
	integer compressIndexInner;
	integer csaIndexInner;
	integer seqIndexInner;
	genvar _gv_stage_3;
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	generate
		for (_gv_stage_3 = 0; _gv_stage_3 < 3; _gv_stage_3 = _gv_stage_3 + 1) begin : gen_live_stages
			localparam stage = _gv_stage_3;
			assign keepValidInner[stage] = validInner[stage] && (!flushInfoInput[5] || rv32_pkg_rob_is_older(tagInner[stage], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
		end
	endgenerate
	assign inputLiveInner = (!executeInput[181] || !flushInfoInput[5]) || rv32_pkg_rob_is_older(executeInput[13-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]);
	always @* begin
		lhsSignedInner = (executeInput[180-:6] == 6'd14) || (executeInput[180-:6] == 6'd15);
		rhsSignedInner = executeInput[180-:6] == 6'd14;
		boothMultiplicandInner = (lhsSignedInner ? {{32 {executeInput[174]}}, executeInput[174-:32]} : {32'b00000000000000000000000000000000, executeInput[174-:32]});
		boothMultiplierInner = (rhsSignedInner ? {{2 {executeInput[142]}}, executeInput[142-:32], 1'b0} : {2'b00, executeInput[142-:32], 1'b0});
		boothCorrectionInner = 1'sb0;
		for (boothIndexInner = 0; boothIndexInner < 17; boothIndexInner = boothIndexInner + 1)
			(* full_case, parallel_case *)
			case (boothMultiplierInner[2 * boothIndexInner+:3])
				3'b001, 3'b010: boothRowsInner[boothIndexInner] = boothMultiplicandInner << (2 * boothIndexInner);
				3'b011: boothRowsInner[boothIndexInner] = boothMultiplicandInner << ((2 * boothIndexInner) + 1);
				3'b100: begin
					boothRowsInner[boothIndexInner] = ~boothMultiplicandInner << ((2 * boothIndexInner) + 1);
					boothCorrectionInner[(2 * boothIndexInner) + 1] = 1'b1;
				end
				3'b101, 3'b110: begin
					boothRowsInner[boothIndexInner] = ~boothMultiplicandInner << (2 * boothIndexInner);
					boothCorrectionInner[2 * boothIndexInner] = 1'b1;
				end
				default: boothRowsInner[boothIndexInner] = 1'sb0;
			endcase
		boothRowsInner[17] = boothCorrectionInner;
		for (compressIndexInner = 0; compressIndexInner < 6; compressIndexInner = compressIndexInner + 1)
			begin
				compressL1Inner[2 * compressIndexInner] = (boothRowsInner[3 * compressIndexInner] ^ boothRowsInner[(3 * compressIndexInner) + 1]) ^ boothRowsInner[(3 * compressIndexInner) + 2];
				compressL1Inner[(2 * compressIndexInner) + 1] = (((boothRowsInner[3 * compressIndexInner] & boothRowsInner[(3 * compressIndexInner) + 1]) | (boothRowsInner[3 * compressIndexInner] & boothRowsInner[(3 * compressIndexInner) + 2])) | (boothRowsInner[(3 * compressIndexInner) + 1] & boothRowsInner[(3 * compressIndexInner) + 2])) << 1;
			end
		for (compressIndexInner = 0; compressIndexInner < 4; compressIndexInner = compressIndexInner + 1)
			begin
				compressL2Inner[2 * compressIndexInner] = (compressL1Inner[3 * compressIndexInner] ^ compressL1Inner[(3 * compressIndexInner) + 1]) ^ compressL1Inner[(3 * compressIndexInner) + 2];
				compressL2Inner[(2 * compressIndexInner) + 1] = (((compressL1Inner[3 * compressIndexInner] & compressL1Inner[(3 * compressIndexInner) + 1]) | (compressL1Inner[3 * compressIndexInner] & compressL1Inner[(3 * compressIndexInner) + 2])) | (compressL1Inner[(3 * compressIndexInner) + 1] & compressL1Inner[(3 * compressIndexInner) + 2])) << 1;
			end
		for (compressIndexInner = 0; compressIndexInner < 2; compressIndexInner = compressIndexInner + 1)
			begin
				compressL3Inner[2 * compressIndexInner] = (compressL2Inner[3 * compressIndexInner] ^ compressL2Inner[(3 * compressIndexInner) + 1]) ^ compressL2Inner[(3 * compressIndexInner) + 2];
				compressL3Inner[(2 * compressIndexInner) + 1] = (((compressL2Inner[3 * compressIndexInner] & compressL2Inner[(3 * compressIndexInner) + 1]) | (compressL2Inner[3 * compressIndexInner] & compressL2Inner[(3 * compressIndexInner) + 2])) | (compressL2Inner[(3 * compressIndexInner) + 1] & compressL2Inner[(3 * compressIndexInner) + 2])) << 1;
			end
		compressL3Inner[4] = compressL2Inner[6];
		compressL3Inner[5] = compressL2Inner[7];
	end
	always @* begin
		for (csaIndexInner = 0; csaIndexInner < 2; csaIndexInner = csaIndexInner + 1)
			begin
				csaL1Inner[2 * csaIndexInner] = (boothRowsRegisteredInner[3 * csaIndexInner] ^ boothRowsRegisteredInner[(3 * csaIndexInner) + 1]) ^ boothRowsRegisteredInner[(3 * csaIndexInner) + 2];
				csaL1Inner[(2 * csaIndexInner) + 1] = (((boothRowsRegisteredInner[3 * csaIndexInner] & boothRowsRegisteredInner[(3 * csaIndexInner) + 1]) | (boothRowsRegisteredInner[3 * csaIndexInner] & boothRowsRegisteredInner[(3 * csaIndexInner) + 2])) | (boothRowsRegisteredInner[(3 * csaIndexInner) + 1] & boothRowsRegisteredInner[(3 * csaIndexInner) + 2])) << 1;
			end
		csaL2Inner[0] = (csaL1Inner[0] ^ csaL1Inner[1]) ^ csaL1Inner[2];
		csaL2Inner[1] = (((csaL1Inner[0] & csaL1Inner[1]) | (csaL1Inner[0] & csaL1Inner[2])) | (csaL1Inner[1] & csaL1Inner[2])) << 1;
		csaL2Inner[2] = csaL1Inner[3];
		csaSumDInner = (csaL2Inner[0] ^ csaL2Inner[1]) ^ csaL2Inner[2];
		csaCarryDInner = (((csaL2Inner[0] & csaL2Inner[1]) | (csaL2Inner[0] & csaL2Inner[2])) | (csaL2Inner[1] & csaL2Inner[2])) << 1;
	end
	rv32_add #(.WIDTH(PRODUCT_W)) u_final_add(
		.aInput(csaSumInner),
		.bInput(csaCarryInner),
		.cinInput(1'b0),
		.sumOutput(finalProductInner),
		.coutOutput(finalCarryUnusedInner)
	);
	always @* begin
		resultCanAcceptInner = !keepValidInner[2] || outReadyInput;
		CSACanAcceptInner = !keepValidInner[1] || resultCanAcceptInner;
		partialCanAcceptInner = !keepValidInner[0] || CSACanAcceptInner;
		inReadyOutput = partialCanAcceptInner && inputLiveInner;
		executeOutput[43] = keepValidInner[2];
		executeOutput[42-:32] = resultInner;
		executeOutput[10-:5] = tagInner[2];
		executeOutput[5-:rv32_pkg_PHY_TAG_W] = phyInner[2];
	end
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			validInner <= 1'sb0;
			for (seqIndexInner = 0; seqIndexInner < 6; seqIndexInner = seqIndexInner + 1)
				boothRowsRegisteredInner[seqIndexInner] <= 1'sb0;
			csaSumInner <= 1'sb0;
			csaCarryInner <= 1'sb0;
			resultInner <= 1'sb0;
			highInner[0] <= 1'b0;
			highInner[1] <= 1'b0;
			for (seqIndexInner = 0; seqIndexInner < 3; seqIndexInner = seqIndexInner + 1)
				begin
					tagInner[seqIndexInner] <= 1'sb0;
					phyInner[seqIndexInner] <= 1'sb0;
				end
		end
		else if (!freezeInput) begin
			if (resultCanAcceptInner) begin
				validInner[2] <= keepValidInner[1];
				if (keepValidInner[1]) begin
					resultInner <= (highInner[1] ? finalProductInner[63:32] : finalProductInner[31:0]);
					tagInner[2] <= tagInner[1];
					phyInner[2] <= phyInner[1];
				end
			end
			if (CSACanAcceptInner) begin
				validInner[1] <= keepValidInner[0];
				if (keepValidInner[0]) begin
					csaSumInner <= csaSumDInner;
					csaCarryInner <= csaCarryDInner;
					highInner[1] <= highInner[0];
					tagInner[1] <= tagInner[0];
					phyInner[1] <= phyInner[0];
				end
			end
			if (partialCanAcceptInner) begin
				validInner[0] <= executeInput[181] && inputLiveInner;
				if (executeInput[181] && inputLiveInner) begin
					for (seqIndexInner = 0; seqIndexInner < 6; seqIndexInner = seqIndexInner + 1)
						boothRowsRegisteredInner[seqIndexInner] <= compressL3Inner[seqIndexInner];
					highInner[0] <= executeInput[180-:6] != 6'd13;
					tagInner[0] <= executeInput[13-:5];
					phyInner[0] <= executeInput[8-:6];
				end
			end
		end
endmodule
module rv32_div (
	clkInput,
	rstNInput,
	freezeInput,
	flushInfoInput,
	executeInput,
	inReadyOutput,
	outReadyInput,
	executeOutput
);
	input wire clkInput;
	input wire rstNInput;
	input wire freezeInput;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	localparam [31:0] rv32_pkg_ROB_TAG_W = 5;
	input wire [5:0] flushInfoInput;
	localparam [31:0] rv32_pkg_PRF_ENTRIES = 48;
	localparam [31:0] rv32_pkg_PHY_TAG_W = 6;
	input wire [181:0] executeInput;
	output wire inReadyOutput;
	input wire outReadyInput;
	output wire [43:0] executeOutput;
	reg busyInner;
	reg [1:0] phaseInner;
	reg [5:0] loopCountInner;
	reg [31:0] dividendMagInner;
	reg [31:0] divisorMagInner;
	reg [35:0] divisorDpInner;
	reg [5:0] clzDInner;
	reg shiftDInner;
	reg [6:0] dSliceInner;
	reg [6:0] dSlice3Inner;
	reg [35:0] regSInner;
	reg [35:0] regCInner;
	reg [35:0] maskInner;
	reg [31:0] regAInner;
	reg [31:0] regBInner;
	reg quotientNegativeInner;
	reg remainderNegativeInner;
	reg wantRemainderRegisteredInner;
	reg [4:0] activeTagInner;
	reg [5:0] activePhyInner;
	reg resultValidInner;
	reg [31:0] resultInner;
	reg [4:0] resultTagInner;
	reg [5:0] resultPhyInner;
	wire signedOpInner;
	wire wantRemainderInner;
	wire [31:0] dividendNegInner;
	wire [31:0] divisorNegInner;
	wire [31:0] dividendAbsInner;
	wire [31:0] divisorAbsInner;
	wire unusedBorrowDividendInner;
	wire unusedBorrowDivisorInner;
	reg [5:0] prepClzXInner;
	reg [5:0] prepClzDInner;
	reg [5:0] prepAlignInner;
	reg [5:0] prepLoopCountInner;
	reg prepShiftDInner;
	reg [35:0] prepMaskInner;
	reg [35:0] prepDividendNormInner;
	reg [35:0] prepDivisorNormInner;
	reg [35:0] prepDivisorDpInner;
	reg [6:0] prepDSliceInner;
	reg [6:0] prepDSlice3Inner;
	reg [6:0] prepSliceInner;
	reg [35:0] prepSubtrahendInner;
	reg [35:0] prepSInner;
	reg [35:0] prepCInner;
	reg [31:0] prepAInner;
	reg [31:0] prepBInner;
	reg [8:0] loopSum9Inner;
	reg signed [9:0] loopSliceInner;
	reg signed [9:0] loopDSliceInner;
	reg signed [9:0] loopDSlice3Inner;
	reg [35:0] loopS4Inner;
	reg [35:0] loopC4Inner;
	reg [35:0] loopSubtrahendInner;
	reg [35:0] loopTInner;
	reg [35:0] loopSInner;
	reg [35:0] loopCInner;
	reg [31:0] loopAInner;
	reg [31:0] loopBInner;
	reg [35:0] finishPkInner;
	reg [35:0] finishCorrectedPkInner;
	reg finishNegativeInner;
	reg [31:0] finishQuotientInner;
	reg [31:0] finishRemainderInner;
	reg [31:0] finishUnsignedInner;
	reg [31:0] finishNegatedInner;
	reg [31:0] finishSignedInner;
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [5:0] clz32;
		input reg [31:0] valueInput;
		integer indexInner;
		reg seenOneInner;
		begin
			clz32 = 6'd32;
			seenOneInner = 1'b0;
			for (indexInner = 31; indexInner >= 0; indexInner = indexInner - 1)
				if (!seenOneInner && valueInput[indexInner]) begin
					clz32 = sv2v_cast_6_signed(31 - indexInner);
					seenOneInner = 1'b1;
				end
		end
	endfunction
	assign signedOpInner = (executeInput[180-:6] == 6'd17) || (executeInput[180-:6] == 6'd19);
	assign wantRemainderInner = (executeInput[180-:6] == 6'd19) || (executeInput[180-:6] == 6'd20);
	rv32_sub #(.WIDTH(32)) u_dividend_neg(
		.aInput(32'b00000000000000000000000000000000),
		.bInput(executeInput[174-:32]),
		.diffOutput(dividendNegInner),
		.borrowOutput(unusedBorrowDividendInner)
	);
	rv32_sub #(.WIDTH(32)) u_divisor_neg(
		.aInput(32'b00000000000000000000000000000000),
		.bInput(executeInput[142-:32]),
		.diffOutput(divisorNegInner),
		.borrowOutput(unusedBorrowDivisorInner)
	);
	assign dividendAbsInner = (signedOpInner && executeInput[174] ? dividendNegInner : executeInput[174-:32]);
	assign divisorAbsInner = (signedOpInner && executeInput[142] ? divisorNegInner : executeInput[142-:32]);
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	always @* begin
		prepClzXInner = clz32(dividendMagInner);
		prepClzDInner = clz32(divisorMagInner);
		prepAlignInner = prepClzDInner - prepClzXInner;
		prepLoopCountInner = (prepAlignInner + 6'd1) >> 1;
		prepShiftDInner = prepAlignInner[0];
		prepMaskInner = (prepShiftDInner ? 36'hfffffffff : 36'h7ffffffff);
		prepDividendNormInner = ({4'b0000, dividendMagInner} << prepClzXInner) & prepMaskInner;
		prepDivisorNormInner = ({4'b0000, divisorMagInner} << prepClzDInner) & prepMaskInner;
		prepDivisorDpInner = (prepDivisorNormInner << prepShiftDInner) & prepMaskInner;
		prepDSliceInner = (prepShiftDInner ? {2'b00, prepDivisorDpInner[32:28]} : {2'b00, prepDivisorDpInner[31:27]});
		prepDSlice3Inner = prepDSliceInner + (prepDSliceInner << 1);
		prepSliceInner = (prepShiftDInner ? sv2v_cast_7(prepDividendNormInner >> 27) : sv2v_cast_7(prepDividendNormInner >> 26));
		prepSubtrahendInner = 1'sb0;
		prepSInner = 1'sb0;
		prepCInner = 1'sb0;
		prepAInner = 1'sb0;
		prepBInner = 1'sb0;
		if (prepSliceInner >= prepDSlice3Inner) begin
			prepSubtrahendInner = (prepDivisorDpInner << 1) & prepMaskInner;
			prepSInner = (((prepDividendNormInner ^ ~prepSubtrahendInner) ^ 36'd1) << 2) & prepMaskInner;
			prepCInner = ((((prepDividendNormInner & ~prepSubtrahendInner) | (prepDividendNormInner & 36'd1)) | (~prepSubtrahendInner & 36'd1)) << 3) & prepMaskInner;
			prepAInner = 32'd2;
			prepBInner = 32'd1;
		end
		else if (prepSliceInner >= prepDSliceInner) begin
			prepSubtrahendInner = prepDivisorDpInner;
			prepSInner = (((prepDividendNormInner ^ ~prepSubtrahendInner) ^ 36'd1) << 2) & prepMaskInner;
			prepCInner = ((((prepDividendNormInner & ~prepSubtrahendInner) | (prepDividendNormInner & 36'd1)) | (~prepSubtrahendInner & 36'd1)) << 3) & prepMaskInner;
			prepAInner = 32'd1;
			prepBInner = 32'd0;
		end
		else begin
			prepSInner = (prepDividendNormInner << 2) & prepMaskInner;
			prepCInner = 1'sb0;
			prepAInner = 32'd0;
			prepBInner = 32'd3;
		end
	end
	always @* begin
		if (shiftDInner)
			loopSum9Inner = regSInner[35:27] + regCInner[35:27];
		else
			loopSum9Inner = regSInner[34:26] + regCInner[34:26];
		loopSliceInner = {loopSum9Inner[8], loopSum9Inner};
		loopSliceInner[0] = 1'b0;
		loopDSliceInner = $signed({3'b000, dSliceInner});
		loopDSlice3Inner = $signed({3'b000, dSlice3Inner});
		loopS4Inner = (regSInner << 2) & maskInner;
		loopC4Inner = (regCInner << 2) & maskInner;
		loopSubtrahendInner = 1'sb0;
		loopTInner = 1'sb0;
		loopSInner = 1'sb0;
		loopCInner = 1'sb0;
		loopAInner = 1'sb0;
		loopBInner = 1'sb0;
		if (loopSliceInner >= loopDSlice3Inner) begin
			loopSubtrahendInner = (divisorDpInner << 3) & maskInner;
			loopTInner = maskInner ^ loopSubtrahendInner;
			loopSInner = ((loopS4Inner ^ loopC4Inner) ^ loopTInner) & maskInner;
			loopCInner = (((((loopS4Inner & loopC4Inner) | (loopS4Inner & loopTInner)) | (loopC4Inner & loopTInner)) << 1) | 36'd1) & maskInner;
			loopAInner = (regAInner << 2) | 32'd2;
			loopBInner = (regAInner << 2) | 32'd1;
		end
		else if (loopSliceInner >= loopDSliceInner) begin
			loopSubtrahendInner = (divisorDpInner << 2) & maskInner;
			loopTInner = maskInner ^ loopSubtrahendInner;
			loopSInner = ((loopS4Inner ^ loopC4Inner) ^ loopTInner) & maskInner;
			loopCInner = (((((loopS4Inner & loopC4Inner) | (loopS4Inner & loopTInner)) | (loopC4Inner & loopTInner)) << 1) | 36'd1) & maskInner;
			loopAInner = (regAInner << 2) | 32'd1;
			loopBInner = regAInner << 2;
		end
		else if (loopSliceInner >= -loopDSliceInner) begin
			loopSInner = (loopS4Inner ^ loopC4Inner) & maskInner;
			loopCInner = ((loopS4Inner & loopC4Inner) << 1) & maskInner;
			loopAInner = regAInner << 2;
			loopBInner = (regBInner << 2) | 32'd3;
		end
		else if (loopSliceInner >= -loopDSlice3Inner) begin
			loopSubtrahendInner = (divisorDpInner << 2) & maskInner;
			loopSInner = ((loopS4Inner ^ loopC4Inner) ^ loopSubtrahendInner) & maskInner;
			loopCInner = ((((loopS4Inner & loopC4Inner) | (loopS4Inner & loopSubtrahendInner)) | (loopC4Inner & loopSubtrahendInner)) << 1) & maskInner;
			loopAInner = (regBInner << 2) | 32'd3;
			loopBInner = (regBInner << 2) | 32'd2;
		end
		else begin
			loopSubtrahendInner = (divisorDpInner << 3) & maskInner;
			loopSInner = ((loopS4Inner ^ loopC4Inner) ^ loopSubtrahendInner) & maskInner;
			loopCInner = ((((loopS4Inner & loopC4Inner) | (loopS4Inner & loopSubtrahendInner)) | (loopC4Inner & loopSubtrahendInner)) << 1) & maskInner;
			loopAInner = (regBInner << 2) | 32'd2;
			loopBInner = (regBInner << 2) | 32'd1;
		end
	end
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @* begin
		finishPkInner = (regSInner + regCInner) & maskInner;
		finishNegativeInner = (shiftDInner ? finishPkInner[35] : finishPkInner[34]);
		finishCorrectedPkInner = (finishNegativeInner ? (finishPkInner + (divisorDpInner << 2)) & maskInner : finishPkInner);
		finishQuotientInner = (finishNegativeInner ? regBInner : regAInner);
		finishRemainderInner = sv2v_cast_32(((finishCorrectedPkInner >> 2) >> shiftDInner) >> clzDInner);
		finishUnsignedInner = (wantRemainderRegisteredInner ? finishRemainderInner : finishQuotientInner);
		finishNegatedInner = ~finishUnsignedInner + 32'd1;
		finishSignedInner = ((wantRemainderRegisteredInner && remainderNegativeInner) || (!wantRemainderRegisteredInner && quotientNegativeInner) ? finishNegatedInner : finishUnsignedInner);
	end
	function automatic rv32_pkg_rob_is_younger;
		input reg [4:0] candidateInput;
		input reg [4:0] boundaryInput;
		reg [4:0] propagateInner;
		reg [4:0] genBitInner;
		reg [4:0] groupPInner;
		reg [4:0] groupGInner;
		begin
			propagateInner = candidateInput ^ ~boundaryInput;
			genBitInner = candidateInput & ~boundaryInput;
			groupPInner = propagateInner;
			groupGInner = genBitInner;
			begin : sv2v_autoblock_1
				reg signed [31:0] stageInner;
				for (stageInner = 1; stageInner < rv32_pkg_ROB_TAG_W; stageInner = stageInner << 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] bitIndexInner;
						for (bitIndexInner = 4; bitIndexInner >= stageInner; bitIndexInner = bitIndexInner - 1)
							begin
								groupGInner[bitIndexInner] = groupGInner[bitIndexInner] | (groupPInner[bitIndexInner] & groupGInner[bitIndexInner - stageInner]);
								groupPInner[bitIndexInner] = groupPInner[bitIndexInner] & groupPInner[bitIndexInner - stageInner];
							end
					end
			end
			rv32_pkg_rob_is_younger = (candidateInput != boundaryInput) && !(propagateInner[4] ^ (groupGInner[3] | (groupPInner[3] & 1'b1)));
		end
	endfunction
	function automatic rv32_pkg_rob_is_older;
		input reg [4:0] candidateInput;
		input reg [4:0] referenceInput;
		rv32_pkg_rob_is_older = rv32_pkg_rob_is_younger(referenceInput, candidateInput);
	endfunction
	assign executeOutput[43] = resultValidInner && (!flushInfoInput[5] || rv32_pkg_rob_is_older(resultTagInner, flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
	assign executeOutput[42-:32] = resultInner;
	assign executeOutput[10-:5] = resultTagInner;
	assign executeOutput[5-:rv32_pkg_PHY_TAG_W] = resultPhyInner;
	assign inReadyOutput = (!busyInner && ((!resultValidInner || (executeOutput[43] && outReadyInput)) || ((outReadyInput && flushInfoInput[5]) && rv32_pkg_rob_is_older(flushInfoInput[4-:rv32_pkg_ROB_TAG_W], resultTagInner)))) && ((!executeInput[181] || !flushInfoInput[5]) || rv32_pkg_rob_is_older(executeInput[13-:5], flushInfoInput[4-:rv32_pkg_ROB_TAG_W]));
	always_ff @(posedge clkInput or negedge rstNInput)
		if (!rstNInput) begin
			busyInner <= 1'b0;
			phaseInner <= 2'd0;
			loopCountInner <= 1'sb0;
			dividendMagInner <= 1'sb0;
			divisorMagInner <= 1'sb0;
			divisorDpInner <= 1'sb0;
			clzDInner <= 1'sb0;
			shiftDInner <= 1'b0;
			dSliceInner <= 1'sb0;
			dSlice3Inner <= 1'sb0;
			regSInner <= 1'sb0;
			regCInner <= 1'sb0;
			maskInner <= 1'sb0;
			regAInner <= 1'sb0;
			regBInner <= 1'sb0;
			quotientNegativeInner <= 1'b0;
			remainderNegativeInner <= 1'b0;
			wantRemainderRegisteredInner <= 1'b0;
			activeTagInner <= 1'sb0;
			activePhyInner <= 1'sb0;
			resultValidInner <= 1'b0;
			resultInner <= 1'sb0;
			resultTagInner <= 1'sb0;
			resultPhyInner <= 1'sb0;
		end
		else if (!freezeInput) begin
			if (resultValidInner && ((executeOutput[43] && outReadyInput) || (flushInfoInput[5] && rv32_pkg_rob_is_older(flushInfoInput[4-:rv32_pkg_ROB_TAG_W], resultTagInner))))
				resultValidInner <= 1'b0;
			if ((flushInfoInput[5] && busyInner) && rv32_pkg_rob_is_older(flushInfoInput[4-:rv32_pkg_ROB_TAG_W], activeTagInner))
				busyInner <= 1'b0;
			else if (executeInput[181] && inReadyOutput) begin
				activeTagInner <= executeInput[13-:5];
				activePhyInner <= executeInput[8-:6];
				wantRemainderRegisteredInner <= wantRemainderInner;
				quotientNegativeInner <= signedOpInner && (executeInput[174] ^ executeInput[142]);
				remainderNegativeInner <= signedOpInner && executeInput[174];
				if (executeInput[142-:32] == 32'b00000000000000000000000000000000) begin
					resultValidInner <= 1'b1;
					resultInner <= (wantRemainderInner ? executeInput[174-:32] : 32'hffffffff);
					resultTagInner <= executeInput[13-:5];
					resultPhyInner <= executeInput[8-:6];
					busyInner <= 1'b0;
				end
				else if ((signedOpInner && (executeInput[174-:32] == 32'h80000000)) && (executeInput[142-:32] == 32'hffffffff)) begin
					resultValidInner <= 1'b1;
					resultInner <= (wantRemainderInner ? 32'b00000000000000000000000000000000 : 32'h80000000);
					resultTagInner <= executeInput[13-:5];
					resultPhyInner <= executeInput[8-:6];
					busyInner <= 1'b0;
				end
				else if (dividendAbsInner < divisorAbsInner) begin
					resultValidInner <= 1'b1;
					resultInner <= (wantRemainderInner ? executeInput[174-:32] : 32'b00000000000000000000000000000000);
					resultTagInner <= executeInput[13-:5];
					resultPhyInner <= executeInput[8-:6];
					busyInner <= 1'b0;
				end
				else if (dividendAbsInner == divisorAbsInner) begin
					resultValidInner <= 1'b1;
					resultInner <= (wantRemainderInner ? 32'b00000000000000000000000000000000 : (signedOpInner && (executeInput[174] ^ executeInput[142]) ? 32'hffffffff : 32'd1));
					resultTagInner <= executeInput[13-:5];
					resultPhyInner <= executeInput[8-:6];
					busyInner <= 1'b0;
				end
				else begin
					busyInner <= 1'b1;
					phaseInner <= 2'd0;
					dividendMagInner <= dividendAbsInner;
					divisorMagInner <= divisorAbsInner;
				end
			end
			else if (busyInner)
				(* full_case, parallel_case *)
				case (phaseInner)
					2'd0: begin
						loopCountInner <= prepLoopCountInner;
						divisorDpInner <= prepDivisorDpInner;
						clzDInner <= prepClzDInner;
						shiftDInner <= prepShiftDInner;
						dSliceInner <= prepDSliceInner;
						dSlice3Inner <= prepDSlice3Inner;
						regSInner <= prepSInner;
						regCInner <= prepCInner;
						maskInner <= prepMaskInner;
						regAInner <= prepAInner;
						regBInner <= prepBInner;
						phaseInner <= (prepLoopCountInner == 6'd0 ? 2'd2 : 2'd1);
					end
					2'd1: begin
						regSInner <= loopSInner;
						regCInner <= loopCInner;
						regAInner <= loopAInner;
						regBInner <= loopBInner;
						if (loopCountInner == 6'd1)
							phaseInner <= 2'd2;
						else
							loopCountInner <= loopCountInner - 6'd1;
					end
					default: begin
						busyInner <= 1'b0;
						resultValidInner <= 1'b1;
						resultInner <= finishSignedInner;
						resultTagInner <= activeTagInner;
						resultPhyInner <= activePhyInner;
					end
				endcase
		end
endmodule
module student_top (
	clock,
	reset,
	araddr,
	arvalid,
	arready,
	rdata,
	rresp,
	rvalid,
	rready,
	awaddr,
	awvalid,
	awready,
	wdata,
	wstrb,
	wvalid,
	wready,
	bresp,
	bvalid,
	bready
);
	localparam [31:0] rv32_pkg_FETCH_WIDTH = 4;
	parameter [31:0] FETCH_WIDTH = rv32_pkg_FETCH_WIDTH;
	localparam [31:0] rv32_pkg_COMMIT_WIDTH = 4;
	parameter [31:0] COMMIT_WIDTH = rv32_pkg_COMMIT_WIDTH;
	localparam [31:0] rv32_pkg_DECODE_WIDTH = 4;
	parameter [31:0] DECODE_WIDTH = rv32_pkg_DECODE_WIDTH;
	localparam [31:0] rv32_pkg_RENAME_WIDTH = 4;
	parameter [31:0] RENAME_WIDTH = rv32_pkg_RENAME_WIDTH;
	function automatic [31:0] rv32_pkg_default_fq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_fq_entries = 2 * decodeWidth;
	endfunction
	parameter [31:0] FQ_DEPTH = rv32_pkg_default_fq_entries(DECODE_WIDTH);
	function automatic [31:0] rv32_pkg_default_iq_entries;
		input reg [31:0] decodeWidth;
		rv32_pkg_default_iq_entries = 2 * decodeWidth;
	endfunction
	parameter [31:0] IQ_DEPTH = rv32_pkg_default_iq_entries(DECODE_WIDTH);
	parameter [31:0] ISSUE_WIDTH = RENAME_WIDTH;
	localparam [31:0] rv32_pkg_ICACHE_SETS = 16;
	parameter [31:0] ICACHE_SETS = rv32_pkg_ICACHE_SETS;
	localparam [31:0] rv32_pkg_ICACHE_WAYS = 1;
	parameter [31:0] ICACHE_WAYS = rv32_pkg_ICACHE_WAYS;
	input wire clock;
	input wire reset;
	output wire [31:0] araddr;
	output wire arvalid;
	input wire arready;
	input wire [31:0] rdata;
	input wire [1:0] rresp;
	input wire rvalid;
	output wire rready;
	output wire [31:0] awaddr;
	output wire awvalid;
	input wire awready;
	output wire [31:0] wdata;
	output wire [3:0] wstrb;
	output wire wvalid;
	input wire wready;
	input wire [1:0] bresp;
	input wire bvalid;
	output wire bready;
	wire resetNInner;
	wire haltedInner;
	wire trapInner;
	wire imemReadyInner;
	wire imemResponseValidInner;
	wire imemResponseReadyInner;
	wire imemFlushInner;
	wire [31:0] imemInstructionInner;
	wire [31:0] imemSecondInstructionInner;
	wire [127:0] imemPacketInstructionsInner;
	wire [2:0] imemFetchCountInner;
	wire [31:0] imemFetchPcInner;
	wire imemSecondRequestInner;
	wire [4:0] imemFetchHintInner;
	localparam [31:0] rv32_pkg_ROB_ENTRIES = 16;
	function automatic [31:0] rv32_pkg_checkpoint_capacity;
		input reg [31:0] requiredEntries;
		reg [31:0] capacity;
		begin
			capacity = 1;
			while (capacity < requiredEntries) capacity = capacity * 2;
			rv32_pkg_checkpoint_capacity = capacity;
		end
	endfunction
	localparam [31:0] rv32_pkg_BPU_CKPT_ENTRIES = rv32_pkg_checkpoint_capacity((24 + rv32_pkg_default_fq_entries(rv32_pkg_DECODE_WIDTH)) + rv32_pkg_default_iq_entries(rv32_pkg_DECODE_WIDTH));
	localparam [31:0] rv32_pkg_BPU_CKPT_ID_W = $clog2(rv32_pkg_BPU_CKPT_ENTRIES);
	wire [(65 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] imemRequestInner;
	wire [(97 + rv32_pkg_BPU_CKPT_ID_W) - 1:0] icacheResponseInner;
	localparam [31:0] rv32_pkg_CACHE_LINE_BYTES = 64;
	localparam [31:0] rv32_pkg_CACHE_LINE_BITS = rv32_pkg_CACHE_LINE_BYTES << 3;
	wire [(34 + rv32_pkg_CACHE_LINE_BITS) - 1:0] fetchRequestInner;
	wire [(33 + rv32_pkg_CACHE_LINE_BITS) - 1:0] fetchResponseInner;
	wire fetchReadyInner;
	wire fetchResponseReadyInner;
	wire fetchFlushInner;
	wire dmemValidInner;
	wire dmemWriteInner;
	wire dmemReadyInner;
	localparam [31:0] rv32_pkg_DCACHE_SETS = 128;
	wire [6:0] dmemStoreSetPreviewInner;
	wire [31:0] dmemAddressInner;
	wire [31:0] dmemDataInner;
	wire [3:0] dmemStrobeInner;
	wire [1:0] dmemSizeInner;
	localparam [31:0] rv32_pkg_DATA_REQUEST_ENTRIES = 8;
	localparam signed [31:0] rv32_pkg_DATA_TRANSACTION_W = 3;
	wire [2:0] dmemTransactionInner;
	wire [74:0] dcacheRequestInner;
	wire [35:0] dcacheResponseInner;
	wire [5:0] responsePreviewTransaction;
	wire [1:0] responsePreviewSelect;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BYTES = 32;
	localparam [31:0] rv32_pkg_DCACHE_LINE_BITS = rv32_pkg_DCACHE_LINE_BYTES << 3;
	wire [(73 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] dataRequestInner;
	wire [(35 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] dataResponseInner;
	wire [(35 + rv32_pkg_DCACHE_LINE_BITS) - 1:0] dataResponseToCacheInner;
	wire [1:0] dataHeadTransactionInner;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [rv32_pkg_DCACHE_LINE_BITS - 1:0] sv2v_cast_9476F;
		input reg [rv32_pkg_DCACHE_LINE_BITS - 1:0] inp;
		sv2v_cast_9476F = inp;
	endfunction
	assign dataResponseToCacheInner = {dataResponseInner[33 + (rv32_pkg_DCACHE_LINE_BITS + 1)], sv2v_cast_32(dataResponseInner[rv32_pkg_DCACHE_LINE_BITS + 33-:((rv32_pkg_DCACHE_LINE_BITS + 33) >= (2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) ? ((rv32_pkg_DCACHE_LINE_BITS + 33) - (2 + (rv32_pkg_DCACHE_LINE_BITS + 0))) + 1 : ((2 + (rv32_pkg_DCACHE_LINE_BITS + 0)) - (rv32_pkg_DCACHE_LINE_BITS + 33)) + 1)]), dataHeadTransactionInner, sv2v_cast_9476F(dataResponseInner[rv32_pkg_DCACHE_LINE_BITS - 1-:rv32_pkg_DCACHE_LINE_BITS])};
`ifndef SYNTHESIS
	always @(posedge clock)
		if (!reset)
			assert (dataResponseToCacheInner == dataResponseInner) else $fatal(1, "AXI read reply bundle changed");
`endif
	wire [66:0] dataWordResponseInner;
	wire [34:0] dataWriteResponseInner;
	wire [34:0] cacheWriteResponseInner;
	wire [1:0] dataWriteHeadTransactionInner;
	wire [31:0] dataWriteHeadAddressInner;
	wire dataReadReadyInner;
	wire dataWriteReadyInner;
	wire dataResponseReadyInner;
	wire dataWriteResponseReadyInner;
	wire exitReadyInner;
	wire exitValidInner;
	wire [31:0] exitValueInner;
	wire [104:0] fetchMasterInner;
	wire [104:0] dataMasterInner;
	wire [104:0] masterInner;
	wire [40:0] slaveInner;
	wire [40:0] fetchSlaveInner;
	wire [40:0] dataSlaveInner;
	wire unusedImemReqValidInner;
	wire unusedCommitValidInner;
	wire unusedCommitRdValidInner;
	wire unusedCommitMemValidInner;
	localparam [31:0] rv32_pkg_XLEN = 32;
	wire [31:0] unusedCommitPcInner;
	wire [31:0] unusedCommitInstrInner;
	wire [31:0] unusedCommitRdValueInner;
	wire [4:0] unusedCommitRdInner;
	wire [31:0] unusedCommitMemAddrInner;
	wire [31:0] unusedCommitMemDataInner;
	wire [3:0] unusedCommitMemWstrbInner;
	wire [(COMMIT_WIDTH * 172) - 1:0] unusedRetirementInner;
	wire unusedDmemInitializedInner;
	assign resetNInner = !reset;
	rv32_core #(
		.TAGGED_DMEM(1'b1),
		.LEGACY_HALT(1'b0),
		.FETCH_WIDTH(FETCH_WIDTH),
		.COMMIT_WIDTH(COMMIT_WIDTH),
		.DECODE_WIDTH(DECODE_WIDTH),
		.RENAME_WIDTH(ISSUE_WIDTH),
		.ISSUE_WIDTH(ISSUE_WIDTH),
		.FQ_DEPTH(FQ_DEPTH),
		.IQ_DEPTH(IQ_DEPTH)
	) u_core(
		.clkInput(clock),
		.rstNInput(resetNInner),
		.imemReqValidOutput(unusedImemReqValidInner),
		.imemReqAddrOutput(imemFetchPcInner),
		.imemCacheRequestOutput(imemRequestInner),
		.imemReqReadyInput(imemReadyInner),
		.imemRspValidInput(imemResponseValidInner),
		.imemRspDataInput(imemInstructionInner),
		.imemRspReadyOutput(imemResponseReadyInner),
		.imemRspSecondDataInput(imemSecondInstructionInner),
		.imemFetchHintInput(imemFetchHintInner),
		.imemSecondRequestOutput(imemSecondRequestInner),
		.imemRspPacketDataInput(imemPacketInstructionsInner),
		.imemFetchCountOutput(imemFetchCountInner),
		.imemFlushOutput(imemFlushInner),
		.dmemReqValidOutput(dmemValidInner),
		.dmemReqReadyInput(dmemReadyInner),
		.dmemReqWriteOutput(dmemWriteInner),
		.dmemReqAddrOutput(dmemAddressInner),
		.dmemStoreSetPreviewOutput(dmemStoreSetPreviewInner),
		.dmemReqWdataOutput(dmemDataInner),
		.dmemReqWstrbOutput(dmemStrobeInner),
		.dmemReqSizeOutput(dmemSizeInner),
		.dmemReqTransactionOutput(dmemTransactionInner),
		.dmemRspValidInput(dcacheResponseInner[35]),
		.dmemRspRdataInput(dcacheResponseInner[34-:32]),
		.dmemRspTransactionInput(dcacheResponseInner[2-:rv32_pkg_DATA_TRANSACTION_W]),
		.responsePreviewTransactionInput(responsePreviewTransaction),
		.responsePreviewSelectInput(responsePreviewSelect),
		.commitValidOutput(unusedCommitValidInner),
		.commitPcOutput(unusedCommitPcInner),
		.commitInstrOutput(unusedCommitInstrInner),
		.commitRdValidOutput(unusedCommitRdValidInner),
		.commitRdOutput(unusedCommitRdInner),
		.commitRdValueOutput(unusedCommitRdValueInner),
		.commitMemValidOutput(unusedCommitMemValidInner),
		.commitMemAddrOutput(unusedCommitMemAddrInner),
		.commitMemDataOutput(unusedCommitMemDataInner),
		.commitMemWstrbOutput(unusedCommitMemWstrbInner),
		.retirementOutput(unusedRetirementInner),
		.haltedOutput(haltedInner),
		.trapOutput(trapInner)
	);
	assign imemResponseValidInner = icacheResponseInner[33 + (rv32_pkg_BPU_CKPT_ID_W + 63)];
	assign imemInstructionInner = icacheResponseInner[64 + (rv32_pkg_BPU_CKPT_ID_W + 31)-:((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) >= (64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) ? ((64 + (rv32_pkg_BPU_CKPT_ID_W + 31)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 0))) + 1 : ((64 + (rv32_pkg_BPU_CKPT_ID_W + 0)) - (64 + (rv32_pkg_BPU_CKPT_ID_W + 31))) + 1)];
	rv32_icache #(
		.FETCH_WIDTH(FETCH_WIDTH),
		.SETS(ICACHE_SETS),
		.WAYS(ICACHE_WAYS)
	) u_icache(
		.clkInput(clock),
		.rstNInput(resetNInner),
		.freezeInput(haltedInner),
		.secondInput(imemSecondRequestInner),
		.secondInstructionOutput(imemSecondInstructionInner),
		.packetInstructionsOutput(imemPacketInstructionsInner),
		.predecodeAddressInput(imemFetchPcInner),
		.predecodeOutput(imemFetchHintInner),
		.flushInput(imemFlushInner),
		.cpuRequestInput(imemRequestInner),
		.cpuReqReadyOutput(imemReadyInner),
		.cpuResponseOutput(icacheResponseInner),
		.cpuRspReadyInput(imemResponseReadyInner),
		.memRequestOutput(fetchRequestInner),
		.memReqReadyInput(fetchReadyInner),
		.memResponseInput(fetchResponseInner),
		.memRspReadyOutput(fetchResponseReadyInner),
		.memFlushOutput(fetchFlushInner)
	);
	rv32_axi_fetch u_axi_fetch(
		.clkInput(clock),
		.rstNInput(resetNInner),
		.squashInput(fetchFlushInner),
		.requestInput(fetchRequestInner),
		.requestReadyOutput(fetchReadyInner),
		.responseOutput(fetchResponseInner),
		.responseReadyInput(fetchResponseReadyInner),
		.masterOutput(fetchMasterInner),
		.slaveInput(fetchSlaveInner)
	);
	function automatic [2:0] sv2v_cast_70E94;
		input reg [2:0] inp;
		sv2v_cast_70E94 = inp;
	endfunction
	assign dcacheRequestInner = {dmemValidInner, dmemWriteInner, dmemAddressInner, dmemDataInner, dmemStrobeInner, dmemSizeInner, sv2v_cast_70E94(dmemTransactionInner)};
	localparam [31:0] rv32_pkg_AXI_EXIT_ADDR = 32'h80000000;
	assign cacheWriteResponseInner = {dataWriteResponseInner[34] && (dataWriteHeadAddressInner != rv32_pkg_AXI_EXIT_ADDR), dataWriteHeadAddressInner, dataWriteHeadTransactionInner};
`ifndef SYNTHESIS
	always @(posedge clock)
		if (!reset) begin
			assert (cacheWriteResponseInner[1-:2] == dataWriteResponseInner[1-:2]) else $fatal(1, "AXI write reply transaction changed");
			assert (dataWriteHeadAddressInner == dataWriteResponseInner[33-:32]) else $fatal(1, "AXI write reply address sideband changed");
		end
`endif
	rv32_dmem_backend u_dmem_backend(
		.clkInput(clock),
		.rstNInput(resetNInner),
		.cpuRequestInput(dcacheRequestInner),
		.storeSetPreviewInput(dmemStoreSetPreviewInner),
		.cpuReqReadyOutput(dmemReadyInner),
		.cpuResponseOutput(dcacheResponseInner),
		.responsePreviewTransactionOutput(responsePreviewTransaction),
		.responsePreviewSelectOutput(responsePreviewSelect),
		.memRequestOutput(dataRequestInner),
		.memReadReadyInput(dataReadReadyInner),
		.memWriteReadyInput(dataWriteReadyInner),
		.memResponseInput(dataResponseToCacheInner),
		.memWordResponseInput(dataWordResponseInner),
		.memWriteResponseInput(cacheWriteResponseInner),
		.memRspReadyOutput(dataResponseReadyInner),
		.memWriteRspReadyOutput(dataWriteResponseReadyInner),
		.initializedOutput(unusedDmemInitializedInner),
		.exitReadyInput(exitReadyInner),
		.exitValidOutput(exitValidInner),
		.exitValueOutput(exitValueInner)
	);
	rv32_axi_data u_axi_data(
		.clkInput(clock),
		.rstNInput(resetNInner),
		.requestInput(dataRequestInner),
		.readReadyOutput(dataReadReadyInner),
		.writeReadyOutput(dataWriteReadyInner),
		.responseOutput(dataResponseInner),
		.readHeadTransactionOutput(dataHeadTransactionInner),
		.wordResponseOutput(dataWordResponseInner),
		.responseReadyInput(dataResponseReadyInner),
		.writeResponseOutput(dataWriteResponseInner),
		.writeHeadTransactionOutput(dataWriteHeadTransactionInner),
		.writeHeadAddressOutput(dataWriteHeadAddressInner),
		.writeResponseReadyInput(dataWriteResponseReadyInner || (dataWriteHeadAddressInner == rv32_pkg_AXI_EXIT_ADDR)),
		.exitValidInput(exitValidInner),
		.exitValueInput(exitValueInner),
		.exitReadyOutput(exitReadyInner),
		.masterOutput(dataMasterInner),
		.slaveInput(dataSlaveInner)
	);
	assign slaveInner = {arready, rvalid, awready, wready, bvalid, rdata, rresp, bresp};
	rv32_axi_bus u_axi_bus(
		.clkInput(clock),
		.rstNInput(resetNInner),
		.fetchInput(fetchMasterInner),
		.dataInput(dataMasterInner),
		.slaveInput(slaveInner),
		.masterOutput(masterInner),
		.fetchOutput(fetchSlaveInner),
		.dataOutput(dataSlaveInner)
	);
	assign araddr = masterInner[99-:32];
	assign arvalid = masterInner[104];
	assign rready = masterInner[103];
	assign awaddr = masterInner[67-:32];
	assign awvalid = masterInner[102];
	assign wdata = masterInner[35-:32];
	assign wstrb = masterInner[3-:4];
	assign wvalid = masterInner[101];
	assign bready = masterInner[100];
`ifndef SYNTHESIS
	always @(posedge clock)
		if (!reset)
			assert (!trapInner) else $fatal(1, "CPU retired an illegal instruction");
`endif
endmodule
