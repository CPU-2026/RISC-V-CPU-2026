module rv32_rs #(
  parameter int unsigned DEPTH = 4,
  parameter int unsigned AUX_W = 3,
  // Lanes exposed by the wide issue port.  ISSUE_WIDTH == 1 keeps the pool
  // single issue; a pool whose consumer accepts every valid lane in the same
  // cycle (storeValue) passes its DEPTH.
  parameter int unsigned ISSUE_WIDTH = 1,
  parameter int unsigned RENAME_WIDTH = 1,
  parameter int unsigned WRITEBACK_PORTS = 4,
  parameter bit REUSE_ON_ISSUE = 1'b0,
  parameter bit WB_ISSUE_BYPASS = 1'b0,
  parameter bit INDEPENDENT_ISSUE_READY = 1'b0
) (
  input  logic                   clkInput,
  input  logic                   rstNInput,
  input logic freezeInput,
  input  rv32_pkg::rob_flush_input_t flushInfoInput,

  input  rv32_pkg::rs_allocation_input_t allocInput,
  output logic                   allocReadyOutput,
  input  logic [AUX_W-1:0]       allocAuxInput,
  input  rv32_pkg::rs_allocation_input_t allocSecondInput,
  output logic allocSecondReadyOutput,
  input  logic [AUX_W-1:0] allocSecondAuxInput,

  input  rv32_pkg::cdb_result_t [WRITEBACK_PORTS-1:0] writebackInput,

  output rv32_pkg::rs_issue_output_t issueOutput,
  input  logic                   issueReadyInput,
  output logic [AUX_W-1:0]       issueAuxOutput,

  output logic [ISSUE_WIDTH-1:0] issueLaneValidOutput,
  output rv32_pkg::rs_issue_output_t issueLaneOutput [ISSUE_WIDTH],
  output logic [AUX_W-1:0]       issueLaneAuxOutput [ISSUE_WIDTH],

  output logic [$clog2(DEPTH+1)-1:0] occupancyOutput,
  // Used only by ordered rename4; ISSUE_WIDTH above remains execution dispatch.
  input rv32_pkg::rs_allocation_input_t [3:0] allocLanesInput,
  input logic [3:0][AUX_W-1:0] allocLanesAuxInput,
  output logic [3:0] allocLanesFireOutput,
  output logic [$clog2(DEPTH+1)-1:0] allocCreditsOutput,
  input logic [ISSUE_WIDTH-1:0] issueLaneReadyInput
);
  import rv32_pkg::*;
  if (RENAME_WIDTH != 1 && RENAME_WIDTH != 2 && RENAME_WIDTH != 4) begin : g_invalid_rename_width
    initial $fatal(1, "RENAME_WIDTH must be 1, 2 or 4");
  end

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
  logic [INDEX_W-1:0] allocSecondIndexInner;
  logic allocSecondFoundInner, allocFireInner, allocSecondFireInner;
  cdb_result_t allocSecondSrc1WbInner, allocSecondSrc2WbInner;
  logic allocSecondSrc1ReadyInner, allocSecondSrc2ReadyInner;
  logic [31:0] allocSecondSrc1ValueInner, allocSecondSrc2ValueInner;
  logic [INDEX_W-1:0] allocLanesIndexInner [4];
  logic [3:0] allocLanesS1ReadyInner, allocLanesS2ReadyInner;
  logic [3:0][31:0] allocLanesS1ValueInner, allocLanesS2ValueInner;
  assign allocFireInner = allocInput.valid && allocReadyOutput;
  assign allocSecondFireInner = RENAME_WIDTH == 2 && allocSecondInput.valid && allocSecondReadyOutput;
  logic allocSrc1ReadyResolvedInner;
  logic [31:0] allocSrc1ValueResolvedInner;
  logic allocSrc2ReadyResolvedInner;
  logic [31:0] allocSrc2ValueResolvedInner;
  integer seqIndexInner;
  integer laneInner;
  integer seqLaneInner;

  logic [DEPTH-1:0] laneTakenInner;
  logic laneFoundInner [ISSUE_WIDTH];
  logic [INDEX_W-1:0] laneIndexInner [ISSUE_WIDTH];
  logic [ISSUE_WIDTH-1:0] issueAcceptInner;
  for (genvar lane=0;lane<ISSUE_WIDTH;lane++) begin : g_dispatch_accept
    assign issueAcceptInner[lane]=!freezeInput && issueLaneValidOutput[lane] &&
      (INDEPENDENT_ISSUE_READY ? issueLaneReadyInput[lane] : issueReadyInput);
  end

  cdb_result_t allocSrc1WbInner, allocSrc2WbInner;
  cdb_result_t src1WbInner [DEPTH], src2WbInner [DEPTH];
  logic src1IssueReadyInner [DEPTH], src2IssueReadyInner [DEPTH];
  logic [31:0] src1IssueValueInner [DEPTH], src2IssueValueInner [DEPTH];
  function automatic cdb_result_t matching_writeback(input phy_tag_t tag);
    matching_writeback = '0;
    // Preserve the original lowest-port priority.
    for (int portIndex = WRITEBACK_PORTS-1; portIndex >= 0; portIndex--)
      if (writebackInput[portIndex].valid && writebackInput[portIndex].phyTag == tag)
        matching_writeback = writebackInput[portIndex];
  endfunction
  assign allocSrc1WbInner = matching_writeback(allocInput.source1Tag);
  assign allocSrc2WbInner = matching_writeback(allocInput.source2Tag);
  for (genvar row = 0; row < DEPTH; row++) begin : g_wakeup
    assign src1WbInner[row] = matching_writeback(src1TagInner[row]);
    assign src2WbInner[row] = matching_writeback(src2TagInner[row]);
    // Only OLD occupied entries may dispatch. An authenticated granted CDB
    // value can satisfy their operand now; ordinary register capture remains.
    assign src1IssueReadyInner[row] = src1ReadyInner[row] || (WB_ISSUE_BYPASS && src1WbInner[row].valid);
    assign src2IssueReadyInner[row] = src2ReadyInner[row] || (WB_ISSUE_BYPASS && src2WbInner[row].valid);
    assign src1IssueValueInner[row] = WB_ISSUE_BYPASS && !src1ReadyInner[row] && src1WbInner[row].valid ?
      src1WbInner[row].value : src1ValueInner[row];
    assign src2IssueValueInner[row] = WB_ISSUE_BYPASS && !src2ReadyInner[row] && src2WbInner[row].valid ?
      src2WbInner[row].value : src2ValueInner[row];
  end

  function automatic logic rs_is_older(
    input rob_tag_t candidateInput,
    input rob_tag_t referenceInput
  );
    rs_is_older = (candidateInput != referenceInput) &&
                  ((referenceInput - candidateInput) < ROB_TAG_W'(ROB_ENTRIES));
  endfunction

  // PARALLEL_SINGLE_ISSUE_SELECTOR
  generate if (ISSUE_WIDTH == 1 && WB_ISSUE_BYPASS && DEPTH >= 2) begin : g_parallel_select
    logic [DEPTH-1:0] readyMaskInner, winnerMaskInner;
    logic [DEPTH-1:0] outranksInner [DEPTH];
    for (genvar row = 0; row < DEPTH; row++) begin : g_row
      assign readyMaskInner[row] = busyInner[row] && src1IssueReadyInner[row] && src2IssueReadyInner[row];
      for (genvar peer = 0; peer < DEPTH; peer++) begin : g_peer
        if (peer == row) assign outranksInner[row][peer] = 1'b0;
        else if (peer < row)
          assign outranksInner[row][peer] = !rs_is_older(robTagInner[row], robTagInner[peer]);
        else assign outranksInner[row][peer] = rs_is_older(robTagInner[peer], robTagInner[row]);
      end
      // ROB tags inhabit one legal half-ring. Static age preference is early;
      // late granted-WB readiness only passes this short eligibility reduction.
      assign winnerMaskInner[row] = readyMaskInner[row] && !(|(readyMaskInner & outranksInner[row]));
    end
    always_comb begin
      logic [INDEX_W-1:0] encoded;
      logic [DEPTH-1:0] selected;
      logic [AUX_W-1:0] selectedAux;
      rs_issue_output_t selectedData, rowData;
      logic [WRITEBACK_PORTS-1:0] source1PortMaskInner, source2PortMaskInner;
      logic [31:0] source1StoredInner, source2StoredInner;
      logic source1PriorHitInner, source2PriorHitInner;
      logic source1PortHitInner, source2PortHitInner;
      encoded = '0;
      selected = winnerMaskInner;
      // Match the original invalid-cycle payload, whose index defaults to 0.
      if (!(|winnerMaskInner)) selected[0] = 1'b1;
      selectedData = '0;
      selectedAux = '0;
      rowData = '0;
      source1PortMaskInner = '0;
      source2PortMaskInner = '0;
      source1StoredInner = '0;
      source2StoredInner = '0;
      source1PriorHitInner = 1'b0;
      source2PriorHitInner = 1'b0;
      source1PortHitInner = 1'b0;
      source2PortHitInner = 1'b0;
      for (int row = 0; row < DEPTH; row++) begin
        encoded = encoded | (INDEX_W'(row) & {INDEX_W{winnerMaskInner[row]}});
        rowData = '{valid:1'b0, operation:opInner[row], robTag:robTagInner[row],
          destinationPhy:destPhyInner[row], source1Value:32'b0,
          source2Value:32'b0, immediate:immInner[row],
          programCounter:pcInner[row], predictedProgramCounter:predictedPcInner[row], useImmediate:useImmInner[row]};
        selectedData = selectedData | (rowData & {$bits(rs_issue_output_t){selected[row]}});
        selectedAux = selectedAux | (auxInner[row] & {AUX_W{selected[row]}});
        // Static row identities authenticate WB early. Only the selected row
        // contributes, including row 0 on an invalid issue cycle.
        source1StoredInner |= src1ValueInner[row] & {32{selected[row] &&
          (src1ReadyInner[row] || !src1WbInner[row].valid)}};
        source2StoredInner |= src2ValueInner[row] & {32{selected[row] &&
          (src2ReadyInner[row] || !src2WbInner[row].valid)}};
        source1PriorHitInner = 1'b0;
        source2PriorHitInner = 1'b0;
        for (int portIndex=0;portIndex<WRITEBACK_PORTS;portIndex++) begin
          source1PortHitInner = writebackInput[portIndex].valid &&
            writebackInput[portIndex].phyTag == src1TagInner[row];
          source2PortHitInner = writebackInput[portIndex].valid &&
            writebackInput[portIndex].phyTag == src2TagInner[row];
          source1PortMaskInner[portIndex] |= selected[row] && !src1ReadyInner[row] &&
            source1PortHitInner && !source1PriorHitInner;
          source2PortMaskInner[portIndex] |= selected[row] && !src2ReadyInner[row] &&
            source2PortHitInner && !source2PriorHitInner;
          source1PriorHitInner |= source1PortHitInner;
          source2PriorHitInner |= source2PortHitInner;
        end
      end
      // The wide granted-WB values are selected once per operand/port,
      // not muxed with a stored value separately in every reservation row.
      selectedData.source1Value = source1StoredInner;
      selectedData.source2Value = source2StoredInner;
      for (int portIndex=0;portIndex<WRITEBACK_PORTS;portIndex++) begin
        selectedData.source1Value |= writebackInput[portIndex].value & {32{source1PortMaskInner[portIndex]}};
        selectedData.source2Value |= writebackInput[portIndex].value & {32{source2PortMaskInner[portIndex]}};
      end
      selectedData.valid = (|winnerMaskInner) && (!flushInfoInput.valid ||
        rs_is_older(selectedData.robTag, flushInfoInput.robTag));
      laneFoundInner[0] = |winnerMaskInner;
      laneIndexInner[0] = encoded;
      laneTakenInner = winnerMaskInner;
      issueFoundInner = |winnerMaskInner;
      issueIndexInner = encoded;
      issueOutput = selectedData;
      issueAuxOutput = selectedAux;
      issueLaneValidOutput[0] = selectedData.valid;
      issueLaneOutput[0] = selectedData;
      issueLaneAuxOutput[0] = selectedAux;
    end
`ifndef SYNTHESIS
    always @(posedge clkInput) if (rstNInput) begin
      assert ($onehot0(winnerMaskInner)) else $fatal(1,"parallel RS winner not unique");
      assert (!(|readyMaskInner) || (|winnerMaskInner)) else $fatal(1,"parallel RS lost eligible winner");
    end
`endif
  end else begin : g_linear_select
  always_comb begin
    // Rank the eligible entries by ROB age.  Lane 0 repeats the original
    // single-issue selection, so ISSUE_WIDTH == 1 reproduces the previous
    // behaviour exactly; every later lane takes the oldest entry that no
    // earlier lane already took.
    for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1) begin
      laneFoundInner[laneInner] = 1'b0;
      laneIndexInner[laneInner] = '0;
    end
    laneTakenInner = '0;
    for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1) begin
      for (int combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
        if (busyInner[combIndexInner] && src1IssueReadyInner[combIndexInner] &&
            src2IssueReadyInner[combIndexInner] && !laneTakenInner[combIndexInner] &&
            (!laneFoundInner[laneInner] ||
             rs_is_older(robTagInner[combIndexInner],
                         robTagInner[laneIndexInner[laneInner]]))) begin
          laneFoundInner[laneInner] = 1'b1;
          laneIndexInner[laneInner] = combIndexInner[INDEX_W-1:0];
        end
      end
      if (laneFoundInner[laneInner])
        laneTakenInner[laneIndexInner[laneInner]] = 1'b1;
    end

    issueFoundInner = laneFoundInner[0];
    issueIndexInner = laneIndexInner[0];
    issueOutput.valid = issueFoundInner && (!flushInfoInput.valid ||
        rs_is_older(robTagInner[issueIndexInner], flushInfoInput.robTag));
    issueOutput.operation = operation_e'(opInner[issueIndexInner]);
    issueOutput.robTag = robTagInner[issueIndexInner];
    issueOutput.destinationPhy = destPhyInner[issueIndexInner];
    issueOutput.source1Value = src1IssueValueInner[issueIndexInner];
    issueOutput.source2Value = src2IssueValueInner[issueIndexInner];
    issueOutput.immediate = immInner[issueIndexInner];
    issueOutput.programCounter = pcInner[issueIndexInner];
    issueOutput.predictedProgramCounter = predictedPcInner[issueIndexInner];
    issueOutput.useImmediate = useImmInner[issueIndexInner];
    issueAuxOutput = auxInner[issueIndexInner];

    // Same candidates, same flush age gate: lane 0 is bit-identical to
    // issueOutput, and lane l is the (l+1)-th oldest eligible entry.
    for (laneInner = 0; laneInner < ISSUE_WIDTH; laneInner = laneInner + 1) begin
      issueLaneValidOutput[laneInner] = laneFoundInner[laneInner] &&
          (!flushInfoInput.valid ||
           rs_is_older(robTagInner[laneIndexInner[laneInner]], flushInfoInput.robTag));
      issueLaneOutput[laneInner].valid = issueLaneValidOutput[laneInner];
      issueLaneOutput[laneInner].operation = operation_e'(opInner[laneIndexInner[laneInner]]);
      issueLaneOutput[laneInner].robTag = robTagInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].destinationPhy = destPhyInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].source1Value = src1IssueValueInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].source2Value = src2IssueValueInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].immediate = immInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].programCounter = pcInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].predictedProgramCounter = predictedPcInner[laneIndexInner[laneInner]];
      issueLaneOutput[laneInner].useImmediate = useImmInner[laneIndexInner[laneInner]];
      issueLaneAuxOutput[laneInner] = auxInner[laneIndexInner[laneInner]];
    end

  end

  end endgenerate

  // Consumer acceptance only affects allocation, never OLD issue selection.
  always_comb begin
    allocFoundInner = 1'b0;
    allocIndexInner = '0;
    for (int combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1) begin
      if (!allocFoundInner && !busyInner[combIndexInner]) begin
        allocFoundInner = 1'b1;
        allocIndexInner = combIndexInner[INDEX_W-1:0];
      end
    end
    // Prefer old free slots. Only a full pool may reuse the slot whose OLD
    // instruction is actually accepted by its consumer on this same edge.
    // Sequential allocation already has final priority over release/wakeup.
    if (REUSE_ON_ISSUE && !allocFoundInner && !freezeInput &&
        issueOutput.valid && issueReadyInput) begin
      allocFoundInner = 1'b1;
      allocIndexInner = issueIndexInner;
    end
    allocReadyOutput = allocFoundInner && !flushInfoInput.valid;

    occupancyOutput = '0;
    for (int combIndexInner = 0; combIndexInner < DEPTH; combIndexInner = combIndexInner + 1)
      if (busyInner[combIndexInner])
        occupancyOutput = occupancyOutput + 1'b1;

    allocSrc1ReadyResolvedInner = allocInput.source1Ready;
    allocSrc1ValueResolvedInner = allocInput.source1Value;
    if (!allocSrc1ReadyResolvedInner) begin
      if (allocSrc1WbInner.valid) begin
        allocSrc1ReadyResolvedInner = 1'b1;
        allocSrc1ValueResolvedInner = allocSrc1WbInner.value;
      end
    end

    allocSrc2ReadyResolvedInner = allocInput.source2Ready;
    allocSrc2ValueResolvedInner = allocInput.source2Value;
    if (!allocSrc2ReadyResolvedInner) begin
      if (allocSrc2WbInner.valid) begin
        allocSrc2ReadyResolvedInner = 1'b1;
        allocSrc2ValueResolvedInner = allocSrc2WbInner.value;
      end
    end
  end

  // The younger port sees OLD free rows minus the first accepted allocation.
  // It may use a real departing row only when the pool supports that policy.
  generate if (RENAME_WIDTH == 2) begin : g_second_allocation
    assign allocSecondSrc1WbInner = matching_writeback(allocSecondInput.source1Tag);
    assign allocSecondSrc2WbInner = matching_writeback(allocSecondInput.source2Tag);
    always_comb begin
      allocSecondFoundInner = 1'b0;
      allocSecondIndexInner = '0;
      for (int row = 0; row < DEPTH; row++) begin
        if (!allocSecondFoundInner && !busyInner[row] &&
            (!allocFireInner || INDEX_W'(row) != allocIndexInner)) begin
          allocSecondFoundInner = 1'b1;
          allocSecondIndexInner = INDEX_W'(row);
        end
      end
      if (REUSE_ON_ISSUE && !allocSecondFoundInner && !freezeInput &&
          issueOutput.valid && issueReadyInput &&
          (!allocFireInner || issueIndexInner != allocIndexInner)) begin
        allocSecondFoundInner = 1'b1;
        allocSecondIndexInner = issueIndexInner;
      end
      allocSecondReadyOutput = allocSecondFoundInner && !flushInfoInput.valid;
    end
    assign allocSecondSrc1ReadyInner = allocSecondInput.source1Ready || allocSecondSrc1WbInner.valid;
    assign allocSecondSrc2ReadyInner = allocSecondInput.source2Ready || allocSecondSrc2WbInner.valid;
    assign allocSecondSrc1ValueInner = !allocSecondInput.source1Ready && allocSecondSrc1WbInner.valid ?
      allocSecondSrc1WbInner.value : allocSecondInput.source1Value;
    assign allocSecondSrc2ValueInner = !allocSecondInput.source2Ready && allocSecondSrc2WbInner.valid ?
      allocSecondSrc2WbInner.value : allocSecondInput.source2Value;
  end else begin : g_no_second_allocation
    assign allocSecondReadyOutput = 1'b0;
    assign allocSecondFoundInner = 1'b0;
    assign allocSecondIndexInner = '0;
    assign allocSecondSrc1WbInner = '0;
    assign allocSecondSrc2WbInner = '0;
    assign allocSecondSrc1ReadyInner = 1'b0;
    assign allocSecondSrc2ReadyInner = 1'b0;
    assign allocSecondSrc1ValueInner = '0;
    assign allocSecondSrc2ValueInner = '0;
  end endgenerate

  // Old free rows plus the independently accepted OLD scalar dispatch. There
  // is no allocation->credit path; a sparse instruction group consumes ranks
  // only for this pool, without enlarging its execution bandwidth.
  generate if (RENAME_WIDTH == 4) begin : g_four_allocation
    logic [DEPTH-1:0] available;
    always_comb begin : old_credits
      available='0;
      allocCreditsOutput='0;
      for (int row=0;row<DEPTH;row++) begin
        available[row]=!busyInner[row];
        for (int lane=0;lane<ISSUE_WIDTH;lane++)
          if (REUSE_ON_ISSUE && issueAcceptInner[lane] && INDEX_W'(row)==laneIndexInner[lane])
            available[row]=1'b1;
        if (available[row] && !freezeInput && !flushInfoInput.valid)
          allocCreditsOutput+=1'b1;
      end
    end
    always_comb begin : consume_sparse_pool
      logic [DEPTH-1:0] remaining;
      remaining=available;
      allocLanesFireOutput='0;
      for (int lane=0;lane<4;lane++) begin
        bit found;
        found=0;
        allocLanesIndexInner[lane]='0;
        for (int row=0;row<DEPTH;row++) begin
          if (!found && remaining[row]) begin
            found=1;
            allocLanesIndexInner[lane]=INDEX_W'(row);
          end
        end
        if (!freezeInput && !flushInfoInput.valid && allocLanesInput[lane].valid && found) begin
          allocLanesFireOutput[lane]=1;
          remaining[allocLanesIndexInner[lane]]=0;
        end
      end
    end
    for (genvar lane=0;lane<4;lane++) begin : g_operand
      cdb_result_t wb1,wb2;
      assign wb1=matching_writeback(allocLanesInput[lane].source1Tag);
      assign wb2=matching_writeback(allocLanesInput[lane].source2Tag);
      assign allocLanesS1ReadyInner[lane]=allocLanesInput[lane].source1Ready || wb1.valid;
      assign allocLanesS2ReadyInner[lane]=allocLanesInput[lane].source2Ready || wb2.valid;
      assign allocLanesS1ValueInner[lane]=!allocLanesInput[lane].source1Ready && wb1.valid ? wb1.value : allocLanesInput[lane].source1Value;
      assign allocLanesS2ValueInner[lane]=!allocLanesInput[lane].source2Ready && wb2.valid ? wb2.value : allocLanesInput[lane].source2Value;
    end
  end else begin : g_no_four_allocation
    assign allocLanesFireOutput='0;
    assign allocCreditsOutput='0;
    assign allocLanesS1ReadyInner='0;
    assign allocLanesS2ReadyInner='0;
    assign allocLanesS1ValueInner='0;
    assign allocLanesS2ValueInner='0;
    for (genvar lane=0;lane<4;lane++) assign allocLanesIndexInner[lane]='0;
  end endgenerate

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
    end else if (!freezeInput) begin
      for (seqIndexInner = 0; seqIndexInner < DEPTH; seqIndexInner = seqIndexInner + 1) begin
        if (flushInfoInput.valid && busyInner[seqIndexInner] &&
            rob_is_younger(robTagInner[seqIndexInner], flushInfoInput.robTag)) begin
          busyInner[seqIndexInner] <= 1'b0;
        end else if (busyInner[seqIndexInner]) begin
          if (!src1ReadyInner[seqIndexInner]) begin
            if (src1WbInner[seqIndexInner].valid) begin
              src1ReadyInner[seqIndexInner] <= 1'b1;
              src1ValueInner[seqIndexInner] <= src1WbInner[seqIndexInner].value;
            end
          end
          if (!src2ReadyInner[seqIndexInner]) begin
            if (src2WbInner[seqIndexInner].valid) begin
              src2ReadyInner[seqIndexInner] <= 1'b1;
              src2ValueInner[seqIndexInner] <= src2WbInner[seqIndexInner].value;
            end
          end
        end
      end

      // An accepted older instruction leaves even during flush. Boundary
      // entries are preserved, younger entries were cancelled above.
      if (issueAcceptInner[0])
        busyInner[issueIndexInner] <= 1'b0;

      // Independent consumers release only their actual accepted OLD row.
      // Existing shared-ready users (StoreValue) retain their original grant.
      for (seqLaneInner = 1; seqLaneInner < ISSUE_WIDTH; seqLaneInner = seqLaneInner + 1)
        if (issueAcceptInner[seqLaneInner])
          busyInner[laneIndexInner[seqLaneInner]] <= 1'b0;

      if (!flushInfoInput.valid) begin
        if (RENAME_WIDTH != 4 && allocInput.valid && allocReadyOutput) begin
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
        if (allocSecondFireInner) begin
          busyInner[allocSecondIndexInner] <= 1'b1;
          opInner[allocSecondIndexInner] <= allocSecondInput.operation;
          robTagInner[allocSecondIndexInner] <= allocSecondInput.robTag;
          destPhyInner[allocSecondIndexInner] <= allocSecondInput.destinationPhy;
          src1ReadyInner[allocSecondIndexInner] <= allocSecondSrc1ReadyInner;
          src1TagInner[allocSecondIndexInner] <= allocSecondInput.source1Tag;
          src1ValueInner[allocSecondIndexInner] <= allocSecondSrc1ValueInner;
          src2ReadyInner[allocSecondIndexInner] <= allocSecondSrc2ReadyInner;
          src2TagInner[allocSecondIndexInner] <= allocSecondInput.source2Tag;
          src2ValueInner[allocSecondIndexInner] <= allocSecondSrc2ValueInner;
          immInner[allocSecondIndexInner] <= allocSecondInput.immediate;
          pcInner[allocSecondIndexInner] <= allocSecondInput.programCounter;
          predictedPcInner[allocSecondIndexInner] <= allocSecondInput.predictedProgramCounter;
          useImmInner[allocSecondIndexInner] <= allocSecondInput.useImmediate;
          auxInner[allocSecondIndexInner] <= allocSecondAuxInput;
        end
        if (RENAME_WIDTH == 4) begin
          for (int lane=0;lane<4;lane++) if (allocLanesFireOutput[lane]) begin
            busyInner[allocLanesIndexInner[lane]]<=1;
            opInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].operation;
            robTagInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].robTag;
            destPhyInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].destinationPhy;
            src1ReadyInner[allocLanesIndexInner[lane]]<=allocLanesS1ReadyInner[lane];
            src1TagInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].source1Tag;
            src1ValueInner[allocLanesIndexInner[lane]]<=allocLanesS1ValueInner[lane];
            src2ReadyInner[allocLanesIndexInner[lane]]<=allocLanesS2ReadyInner[lane];
            src2TagInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].source2Tag;
            src2ValueInner[allocLanesIndexInner[lane]]<=allocLanesS2ValueInner[lane];
            immInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].immediate;
            pcInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].programCounter;
            predictedPcInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].predictedProgramCounter;
            useImmInner[allocLanesIndexInner[lane]]<=allocLanesInput[lane].useImmediate;
            auxInner[allocLanesIndexInner[lane]]<=allocLanesAuxInput[lane];
          end
        end
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clkInput) if (rstNInput && !freezeInput && INDEPENDENT_ISSUE_READY) begin
    for (int lane=0;lane<ISSUE_WIDTH;lane++) for (int peer=0;peer<lane;peer++)
      assert(!issueAcceptInner[lane] || !issueAcceptInner[peer] || laneIndexInner[lane]!=laneIndexInner[peer])
        else $fatal(1,"independent RS dispatch consumed one row twice");
  end
  always @(posedge clkInput) if (rstNInput && !freezeInput)
    assert (!allocFireInner || !allocSecondFireInner || allocIndexInner != allocSecondIndexInner)
      else $fatal(1, "RS allocation ports selected the same row");
  always @(posedge clkInput) if (rstNInput && !freezeInput && RENAME_WIDTH==4) begin
    assert ($countones(allocLanesFireOutput)<=int'(allocCreditsOutput)) else $fatal(1,"RS four-lane credit exceeded");
    for (int lane=0;lane<4;lane++) for (int older=0;older<lane;older++)
      assert (!allocLanesFireOutput[lane] || !allocLanesFireOutput[older] || allocLanesIndexInner[lane]!=allocLanesIndexInner[older])
        else $fatal(1,"RS four-lane allocation duplicated a row");
  end
`endif
endmodule
