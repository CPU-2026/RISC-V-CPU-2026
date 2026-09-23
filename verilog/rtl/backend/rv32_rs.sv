module rv32_rs #(
  parameter int unsigned DEPTH = 4,
  parameter int unsigned AUX_W = 3
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,

  input  rv32_pkg::rs_allocation_input_t allocInput,
  output logic                   allocReadyOutput,
  input  logic [AUX_W-1:0]       allocAuxInput,

  input  rv32_pkg::cdb_result_t [3:0] writebackInput,

  output rv32_pkg::rs_issue_output_t issueOutput,
  input  logic                   issueReadyInput,
  output logic [AUX_W-1:0]       issueAuxOutput,
  output logic [$clog2(DEPTH+1)-1:0] occupancyOutput
);
  import rv32_pkg::*;

  localparam int unsigned INDEX_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

  logic busyInner [DEPTH];
  operation_e opInner [DEPTH];
  rob_tag_t robTagInner [DEPTH];
  phy_tag_t destPhyInner [DEPTH];
  logic src1ReadyInner [DEPTH];
  phy_tag_t src1TagInner [DEPTH];
  logic [31:0] src1ValueInner [DEPTH];
  logic src2ReadyInner [DEPTH];
  phy_tag_t src2TagInner [DEPTH];
  logic [31:0] src2ValueInner [DEPTH];
  logic [31:0] immInner [DEPTH];
  logic [31:0] pcInner [DEPTH];
  logic [31:0] predictedPcInner [DEPTH];
  logic useImmInner [DEPTH];
  logic [AUX_W-1:0] auxInner [DEPTH];

  logic issueFoundInner;
  logic [INDEX_W-1:0] issueIndexInner;
  logic allocFoundInner;
  logic [INDEX_W-1:0] allocIndexInner;
  logic allocSrc1ReadyResolvedInner;
  logic [31:0] allocSrc1ValueResolvedInner;
  logic allocSrc2ReadyResolvedInner;
  logic [31:0] allocSrc2ValueResolvedInner;
  integer combIndexInner;
  integer seqIndexInner;

  function automatic logic rs_is_older(
    input rob_tag_t candidateInput,
    input rob_tag_t referenceInput
  );
    rs_is_older = (candidateInput != referenceInput) &&
                  ((referenceInput - candidateInput) < ROB_TAG_W'(ROB_ENTRIES));
  endfunction

  always_comb begin
    issueFoundInner = 1'b0;
    issueIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      if (busyInner[combIndexInner] && src1ReadyInner[combIndexInner] &&
          src2ReadyInner[combIndexInner] &&
          (!issueFoundInner || rs_is_older(robTagInner[combIndexInner],
                                       robTagInner[issueIndexInner]))) begin
        issueFoundInner = 1'b1;
        issueIndexInner = combIndexInner[INDEX_W-1:0];
      end
    end

    issueOutput.valid = issueFoundInner && !flushInfoInput.valid;
    issueOutput.operation = operation_e'(opInner[issueIndexInner]);
    issueOutput.robTag = robTagInner[issueIndexInner];
    issueOutput.destinationPhy = destPhyInner[issueIndexInner];
    issueOutput.source1Value = src1ValueInner[issueIndexInner];
    issueOutput.source2Value = src2ValueInner[issueIndexInner];
    issueOutput.immediate = immInner[issueIndexInner];
    issueOutput.programCounter = pcInner[issueIndexInner];
    issueOutput.predictedProgramCounter = predictedPcInner[issueIndexInner];
    issueOutput.useImmediate = useImmInner[issueIndexInner];
    issueAuxOutput = auxInner[issueIndexInner];

    allocFoundInner = 1'b0;
    allocIndexInner = '0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      if (!allocFoundInner && !busyInner[combIndexInner]) begin
        allocFoundInner = 1'b1;
        allocIndexInner = combIndexInner[INDEX_W-1:0];
      end
    end
    allocReadyOutput = allocFoundInner && !flushInfoInput.valid;

    occupancyOutput = '0;
    for (combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
      if (busyInner[combIndexInner])
        occupancyOutput = occupancyOutput + 1'b1;

    allocSrc1ReadyResolvedInner = allocInput.source1Ready;
    allocSrc1ValueResolvedInner = allocInput.source1Value;
    if (!allocSrc1ReadyResolvedInner) begin
      if (writebackInput[0].valid && (writebackInput[0].phyTag == allocInput.source1Tag)) begin
        allocSrc1ReadyResolvedInner = 1'b1;
        allocSrc1ValueResolvedInner = writebackInput[0].value;
      end else if (writebackInput[1].valid && (writebackInput[1].phyTag == allocInput.source1Tag)) begin
        allocSrc1ReadyResolvedInner = 1'b1;
        allocSrc1ValueResolvedInner = writebackInput[1].value;
      end else if (writebackInput[2].valid && (writebackInput[2].phyTag == allocInput.source1Tag)) begin
        allocSrc1ReadyResolvedInner = 1'b1;
        allocSrc1ValueResolvedInner = writebackInput[2].value;
      end else if (writebackInput[3].valid && (writebackInput[3].phyTag == allocInput.source1Tag)) begin
        allocSrc1ReadyResolvedInner = 1'b1;
        allocSrc1ValueResolvedInner = writebackInput[3].value;
      end
    end

    allocSrc2ReadyResolvedInner = allocInput.source2Ready;
    allocSrc2ValueResolvedInner = allocInput.source2Value;
    if (!allocSrc2ReadyResolvedInner) begin
      if (writebackInput[0].valid && (writebackInput[0].phyTag == allocInput.source2Tag)) begin
        allocSrc2ReadyResolvedInner = 1'b1;
        allocSrc2ValueResolvedInner = writebackInput[0].value;
      end else if (writebackInput[1].valid && (writebackInput[1].phyTag == allocInput.source2Tag)) begin
        allocSrc2ReadyResolvedInner = 1'b1;
        allocSrc2ValueResolvedInner = writebackInput[1].value;
      end else if (writebackInput[2].valid && (writebackInput[2].phyTag == allocInput.source2Tag)) begin
        allocSrc2ReadyResolvedInner = 1'b1;
        allocSrc2ValueResolvedInner = writebackInput[2].value;
      end else if (writebackInput[3].valid && (writebackInput[3].phyTag == allocInput.source2Tag)) begin
        allocSrc2ReadyResolvedInner = 1'b1;
        allocSrc2ValueResolvedInner = writebackInput[3].value;
      end
    end
  end

  always_ff @(posedge clkInput or negedge rstNInput) begin
    if (!rstNInput) begin
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        busyInner[seqIndexInner] <= 1'b0;
        opInner[seqIndexInner] <= OP_INVALID;
        robTagInner[seqIndexInner] <= '0;
        destPhyInner[seqIndexInner] <= '0;
        src1ReadyInner[seqIndexInner] <= 1'b0;
        src1TagInner[seqIndexInner] <= '0;
        src1ValueInner[seqIndexInner] <= '0;
        src2ReadyInner[seqIndexInner] <= 1'b0;
        src2TagInner[seqIndexInner] <= '0;
        src2ValueInner[seqIndexInner] <= '0;
        immInner[seqIndexInner] <= '0;
        pcInner[seqIndexInner] <= '0;
        predictedPcInner[seqIndexInner] <= '0;
        useImmInner[seqIndexInner] <= 1'b0;
        auxInner[seqIndexInner] <= '0;
      end
    end else begin
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (flushInfoInput.valid && busyInner[seqIndexInner] &&
            rob_is_younger(robTagInner[seqIndexInner], flushInfoInput.robTag)) begin
          busyInner[seqIndexInner] <= 1'b0;
        end else if (busyInner[seqIndexInner]) begin
          if (!src1ReadyInner[seqIndexInner]) begin
            if (writebackInput[0].valid && (writebackInput[0].phyTag == src1TagInner[seqIndexInner])) begin
              src1ReadyInner[seqIndexInner] <= 1'b1;
              src1ValueInner[seqIndexInner] <= writebackInput[0].value;
            end else if (writebackInput[1].valid && (writebackInput[1].phyTag == src1TagInner[seqIndexInner])) begin
              src1ReadyInner[seqIndexInner] <= 1'b1;
              src1ValueInner[seqIndexInner] <= writebackInput[1].value;
            end else if (writebackInput[2].valid && (writebackInput[2].phyTag == src1TagInner[seqIndexInner])) begin
              src1ReadyInner[seqIndexInner] <= 1'b1;
              src1ValueInner[seqIndexInner] <= writebackInput[2].value;
            end else if (writebackInput[3].valid && (writebackInput[3].phyTag == src1TagInner[seqIndexInner])) begin
              src1ReadyInner[seqIndexInner] <= 1'b1;
              src1ValueInner[seqIndexInner] <= writebackInput[3].value;
            end
          end
          if (!src2ReadyInner[seqIndexInner]) begin
            if (writebackInput[0].valid && (writebackInput[0].phyTag == src2TagInner[seqIndexInner])) begin
              src2ReadyInner[seqIndexInner] <= 1'b1;
              src2ValueInner[seqIndexInner] <= writebackInput[0].value;
            end else if (writebackInput[1].valid && (writebackInput[1].phyTag == src2TagInner[seqIndexInner])) begin
              src2ReadyInner[seqIndexInner] <= 1'b1;
              src2ValueInner[seqIndexInner] <= writebackInput[1].value;
            end else if (writebackInput[2].valid && (writebackInput[2].phyTag == src2TagInner[seqIndexInner])) begin
              src2ReadyInner[seqIndexInner] <= 1'b1;
              src2ValueInner[seqIndexInner] <= writebackInput[2].value;
            end else if (writebackInput[3].valid && (writebackInput[3].phyTag == src2TagInner[seqIndexInner])) begin
              src2ReadyInner[seqIndexInner] <= 1'b1;
              src2ValueInner[seqIndexInner] <= writebackInput[3].value;
            end
          end
        end
      end

      if (!flushInfoInput.valid) begin
        if (issueOutput.valid && issueReadyInput)
          busyInner[issueIndexInner] <= 1'b0;

        if (allocInput.valid && allocReadyOutput) begin
          busyInner[allocIndexInner] <= 1'b1;
          opInner[allocIndexInner] <= allocInput.operation;
          robTagInner[allocIndexInner] <= allocInput.robTag;
          destPhyInner[allocIndexInner] <= allocInput.destinationPhy;
          src1ReadyInner[allocIndexInner] <= allocSrc1ReadyResolvedInner;
          src1TagInner[allocIndexInner] <= allocInput.source1Tag;
          src1ValueInner[allocIndexInner] <= allocSrc1ValueResolvedInner;
          src2ReadyInner[allocIndexInner] <= allocSrc2ReadyResolvedInner;
          src2TagInner[allocIndexInner] <= allocInput.source2Tag;
          src2ValueInner[allocIndexInner] <= allocSrc2ValueResolvedInner;
          immInner[allocIndexInner] <= allocInput.immediate;
          pcInner[allocIndexInner] <= allocInput.programCounter;
          predictedPcInner[allocIndexInner] <= allocInput.predictedProgramCounter;
          useImmInner[allocIndexInner] <= allocInput.useImmediate;
          auxInner[allocIndexInner] <= allocAuxInput;
        end
      end
    end
  end
endmodule
