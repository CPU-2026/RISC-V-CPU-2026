// Naive, standalone 1RW SRAM BTB. This is NOT a drop-in replacement for the
// combinational rv32_bpu_btb: both queries and training batches use handshakes.
// Only one operation is outstanding; training wins arbitration in IDLE.
// See docs/experiments.md for timing, reset and integration limitations.
module rv32_bpu_btb_sram #(
  parameter int unsigned BTB_ENTRIES = 64
) (
  input logic clkInput,
  input logic rstNInput,

  input logic queryValidInput,
  output logic queryReadyOutput,
  input logic [31:0] queryPcInput,
  output logic responseValidOutput,
  input logic responseReadyInput,
  output logic [31:0] responsePcOutput,
  output rv32_pkg::btb_lookup_output_t lookupOutput,

  input logic trainingValidInput,
  output logic trainingReadyOutput,
  input rv32_pkg::btb_training_input_t trainingInput,
  output logic trainingDoneOutput,
  output logic initializedOutput
);
  import rv32_pkg::*;

  localparam int unsigned INDEX_W = BTB_ENTRIES > 1 ? $clog2(BTB_ENTRIES) : 1;
  localparam int unsigned TAG_W = 32 - INDEX_W - 2;
  localparam int unsigned TAG_LSB = 32;
  localparam int unsigned TARGET_W = 30;
  localparam int unsigned ENTRY_W = TAG_LSB + TAG_W;
  localparam int unsigned STORAGE_ENTRIES = BTB_ENTRIES > 0 ? BTB_ENTRIES : 1;

  localparam logic [1:0] INVALID = 2'b00;
  localparam logic [1:0] CONDITIONAL = 2'b01;
  localparam logic [1:0] UNCONDITIONAL = 2'b10;
  localparam logic [1:0] RETURN = 2'b11;

  typedef enum logic [2:0] {
    INITIALIZE, IDLE, QUERY_RESPONSE, QUERY_HOLD,
    TRAIN_FETCH, TRAIN_FETCH_WRITE, TRAIN_JUMP, TRAIN_BRANCH
  } state_t;
  state_t stateInner;
  logic [INDEX_W-1:0] initIndexInner;
  logic [31:0] responsePcInner;
  logic [ENTRY_W-1:0] responseWordInner, queryWordInner;
  btb_training_input_t trainingInner;

  logic fetchWriteInner, fetchTargetKnownInner, jumpWriteInner, branchWriteInner;
  logic fetchJumpSameInner, fetchBranchSameInner, jumpBranchSameInner;
  logic [INDEX_W-1:0] fetchIndexInner, jumpIndexInner, branchIndexInner;
  logic [TARGET_W-1:0] fetchTargetInner;
  logic [1:0] fetchStateInner;

  logic queryFireInner, trainingFireInner;
  logic sramEnableInner, sramWriteInner;
  logic [INDEX_W-1:0] sramAddressInner;
  logic [ENTRY_W-1:0] sramWdataInner, sramRdataInner;

  assign initializedOutput = rstNInput && stateInner != INITIALIZE;
  assign trainingReadyOutput = rstNInput && stateInner == IDLE;
  assign queryReadyOutput = rstNInput && stateInner == IDLE && !trainingValidInput;
  assign queryFireInner = queryValidInput && queryReadyOutput;
  assign trainingFireInner = trainingValidInput && trainingReadyOutput;
  assign responseValidOutput = rstNInput &&
    (stateInner == QUERY_RESPONSE || stateInner == QUERY_HOLD);
  assign responsePcOutput = responseValidOutput ? responsePcInner : 32'b0;

  // The SRAM result is only used immediately after a read. If the consumer
  // stalls, capture it BEFORE the next disabled SRAM edge invalidates rdata.
  assign queryWordInner = stateInner == QUERY_RESPONSE ? sramRdataInner : responseWordInner;
  always_comb begin
    lookupOutput = '0;
    if (responseValidOutput) begin
      lookupOutput.hit = queryWordInner[1:0] != INVALID &&
        queryWordInner[TAG_LSB+:TAG_W] == responsePcInner[31:INDEX_W+2];
      // Match the register BTB: type/target are not gated by a tag hit.
      lookupOutput.unconditional = queryWordInner[1:0] == UNCONDITIONAL ||
        queryWordInner[1:0] == RETURN;
      lookupOutput.isReturn = queryWordInner[1:0] == RETURN;
      lookupOutput.target = {queryWordInner[2+:TARGET_W], 2'b00};
    end
  end

  // A handshake captures the WHOLE producer batch. Qualifiers below use only
  // this snapshot, never live inputs while the SRAM drains its writes.
  always_comb begin
    fetchWriteInner = trainingInner.fetchValid;
    jumpWriteInner = trainingInner.jumpValid;
    branchWriteInner = trainingInner.branch.valid && trainingInner.branch.taken;
    fetchIndexInner = trainingInner.fetchProgramCounter[INDEX_W+1:2];
    jumpIndexInner = trainingInner.jumpProgramCounter[INDEX_W+1:2];
    branchIndexInner = trainingInner.branch.programCounter[INDEX_W+1:2];
    fetchJumpSameInner = fetchWriteInner && jumpWriteInner && fetchIndexInner == jumpIndexInner;
    fetchBranchSameInner = fetchWriteInner && branchWriteInner && fetchIndexInner == branchIndexInner;
    jumpBranchSameInner = jumpWriteInner && branchWriteInner && jumpIndexInner == branchIndexInner;

    fetchStateInner = trainingInner.isReturn ? RETURN : UNCONDITIONAL;
    fetchTargetKnownInner = 1'b1;
    fetchTargetInner = '0;
    if (!trainingInner.isReturn && trainingInner.jalTargetValid)
      fetchTargetInner = trainingInner.jalTarget[31:2];
    else if (fetchJumpSameInner)
      fetchTargetInner = trainingInner.jumpTarget[31:2];
    else if (fetchBranchSameInner)
      fetchTargetInner = trainingInner.branch.nextProgramCounter[31:2];
    else
      fetchTargetKnownInner = 1'b0;
  end

  // Exactly one physical SRAM port. Even three different training indices
  // are serialized; no query is accepted until the entire batch completes.
  always_comb begin
    sramEnableInner = 1'b0;
    sramWriteInner = 1'b0;
    sramAddressInner = '0;
    sramWdataInner = '0;
    if (rstNInput) begin
      case (stateInner)
        INITIALIZE: begin
          sramEnableInner = 1'b1;
          sramWriteInner = 1'b1;
          sramAddressInner = initIndexInner;
        end
        IDLE: begin
          sramEnableInner = queryFireInner;
          sramAddressInner = queryPcInput[INDEX_W+1:2];
        end
        TRAIN_FETCH: begin
          sramEnableInner = fetchWriteInner;
          sramWriteInner = fetchTargetKnownInner;
          sramAddressInner = fetchIndexInner;
          sramWdataInner = {trainingInner.fetchProgramCounter[31:INDEX_W+2],
                            fetchTargetInner, fetchStateInner};
        end
        TRAIN_FETCH_WRITE: begin
          sramEnableInner = 1'b1;
          sramWriteInner = 1'b1;
          sramAddressInner = fetchIndexInner;
          sramWdataInner = {trainingInner.fetchProgramCounter[31:INDEX_W+2],
                            sramRdataInner[2+:TARGET_W], fetchStateInner};
        end
        TRAIN_JUMP: begin
          sramEnableInner = jumpWriteInner && !fetchJumpSameInner;
          sramWriteInner = 1'b1;
          sramAddressInner = jumpIndexInner;
          sramWdataInner = {trainingInner.jumpProgramCounter[31:INDEX_W+2],
                            trainingInner.jumpTarget[31:2],
                            trainingInner.jumpIsReturn ? RETURN : UNCONDITIONAL};
        end
        TRAIN_BRANCH: begin
          sramEnableInner = branchWriteInner && !fetchBranchSameInner && !jumpBranchSameInner;
          sramWriteInner = 1'b1;
          sramAddressInner = branchIndexInner;
          sramWdataInner = {trainingInner.branch.programCounter[31:INDEX_W+2],
                            trainingInner.branch.nextProgramCounter[31:2], CONDITIONAL};
        end
        default: begin end
      endcase
    end
  end

  sram_fakeram #(.DEPTH(STORAGE_ENTRIES), .WIDTH(ENTRY_W), .WRITE_GRANULARITY(ENTRY_W)) u_btb (
    .clk(clkInput), .en(sramEnableInner), .we(sramWriteInner), .wmask(1'b1),
    .addr(sramAddressInner), .wdata(sramWdataInner), .rdata(sramRdataInner)
  );

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      stateInner <= INITIALIZE;
      initIndexInner <= '0;
      responsePcInner <= '0;
      responseWordInner <= '0;
      trainingInner <= '0;
      trainingDoneOutput <= 1'b0;
    end else begin
      trainingDoneOutput <= 1'b0;
      case (stateInner)
        INITIALIZE: begin
          if (initIndexInner == INDEX_W'(STORAGE_ENTRIES - 1))
            stateInner <= IDLE;
          else
            initIndexInner <= initIndexInner + INDEX_W'(1);
        end
        IDLE: begin
          if (trainingFireInner) begin
            trainingInner <= trainingInput;
            stateInner <= TRAIN_FETCH;
          end else if (queryFireInner) begin
            responsePcInner <= queryPcInput;
            stateInner <= QUERY_RESPONSE;
          end
        end
        QUERY_RESPONSE: begin
          if (responseReadyInput)
            stateInner <= IDLE;
          else begin
            responseWordInner <= sramRdataInner;
            stateInner <= QUERY_HOLD;
          end
        end
        QUERY_HOLD: begin
          if (responseReadyInput) stateInner <= IDLE;
        end
        TRAIN_FETCH: stateInner <= fetchWriteInner && !fetchTargetKnownInner ?
                                    TRAIN_FETCH_WRITE : TRAIN_JUMP;
        TRAIN_FETCH_WRITE: stateInner <= TRAIN_JUMP;
        TRAIN_JUMP: stateInner <= TRAIN_BRANCH;
        TRAIN_BRANCH: begin
          trainingDoneOutput <= 1'b1;
          stateInner <= IDLE;
        end
        default: stateInner <= INITIALIZE;
      endcase
    end
  end

`ifndef SYNTHESIS
  initial begin
    assert (BTB_ENTRIES >= 2 && (BTB_ENTRIES & (BTB_ENTRIES - 1)) == 0 && TAG_W >= 1)
      else $fatal(1, "BPU SRAM BTB parameter must be power-of-two >=2 with a nonempty PC tag");
  end
  always @(posedge clkInput) if (rstNInput) begin
    assert (!(queryFireInner && trainingFireInner))
      else $fatal(1, "SRAM BTB accepted a query and training together");
    assert (!responseValidOutput || (!queryReadyOutput && !trainingReadyOutput && !sramEnableInner))
      else $fatal(1, "SRAM BTB failed to serialize a pending response");
  end
`endif
endmodule
