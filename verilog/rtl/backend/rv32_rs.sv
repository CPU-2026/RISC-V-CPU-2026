module rv32_rs #(
  parameter int unsigned DEPTH = 4,
  parameter int unsigned AUX_W = 3
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   alloc_valid_i,
  output logic                   alloc_ready_o,
  input  rv32_pkg::operation_e   alloc_op_i,
  input  rv32_pkg::rob_tag_t     alloc_rob_tag_i,
  input  rv32_pkg::phy_tag_t     alloc_dest_phy_i,
  input  logic                   alloc_src1_ready_i,
  input  rv32_pkg::phy_tag_t     alloc_src1_tag_i,
  input  logic [31:0]            alloc_src1_value_i,
  input  logic                   alloc_src2_ready_i,
  input  rv32_pkg::phy_tag_t     alloc_src2_tag_i,
  input  logic [31:0]            alloc_src2_value_i,
  input  logic [31:0]            alloc_imm_i,
  input  logic [31:0]            alloc_pc_i,
  input  logic [31:0]            alloc_predicted_pc_i,
  input  logic                   alloc_use_imm_i,
  input  logic [AUX_W-1:0]       alloc_aux_i,

  input  logic                   wb0_valid_i,
  input  rv32_pkg::phy_tag_t     wb0_phy_i,
  input  logic [31:0]            wb0_value_i,
  input  logic                   wb1_valid_i,
  input  rv32_pkg::phy_tag_t     wb1_phy_i,
  input  logic [31:0]            wb1_value_i,
  input  logic                   wb2_valid_i,
  input  rv32_pkg::phy_tag_t     wb2_phy_i,
  input  logic [31:0]            wb2_value_i,
  input  logic                   wb3_valid_i,
  input  rv32_pkg::phy_tag_t     wb3_phy_i,
  input  logic [31:0]            wb3_value_i,

  output logic                   issue_valid_o,
  input  logic                   issue_ready_i,
  output rv32_pkg::operation_e   issue_op_o,
  output rv32_pkg::rob_tag_t     issue_rob_tag_o,
  output rv32_pkg::phy_tag_t     issue_dest_phy_o,
  output logic [31:0]            issue_src1_value_o,
  output logic [31:0]            issue_src2_value_o,
  output logic [31:0]            issue_imm_o,
  output logic [31:0]            issue_pc_o,
  output logic [31:0]            issue_predicted_pc_o,
  output logic                   issue_use_imm_o,
  output logic [AUX_W-1:0]       issue_aux_o,
  output logic [$clog2(DEPTH+1)-1:0] occupancy_o
);
  import rv32_pkg::*;

  localparam int unsigned INDEX_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

  logic busy_q [0:DEPTH-1];
  operation_e op_q [0:DEPTH-1];
  rob_tag_t rob_tag_q [0:DEPTH-1];
  phy_tag_t dest_phy_q [0:DEPTH-1];
  logic src1_ready_q [0:DEPTH-1];
  phy_tag_t src1_tag_q [0:DEPTH-1];
  logic [31:0] src1_value_q [0:DEPTH-1];
  logic src2_ready_q [0:DEPTH-1];
  phy_tag_t src2_tag_q [0:DEPTH-1];
  logic [31:0] src2_value_q [0:DEPTH-1];
  logic [31:0] imm_q [0:DEPTH-1];
  logic [31:0] pc_q [0:DEPTH-1];
  logic [31:0] predicted_pc_q [0:DEPTH-1];
  logic use_imm_q [0:DEPTH-1];
  logic [AUX_W-1:0] aux_q [0:DEPTH-1];

  logic issue_found;
  logic [INDEX_W-1:0] issue_index;
  logic alloc_found;
  logic [INDEX_W-1:0] alloc_index;
  logic alloc_src1_ready_resolved;
  logic [31:0] alloc_src1_value_resolved;
  logic alloc_src2_ready_resolved;
  logic [31:0] alloc_src2_value_resolved;
  integer comb_i;
  integer seq_i;

  function automatic logic rs_is_older(
    input rob_tag_t candidate,
    input rob_tag_t reference
  );
    rs_is_older = (candidate != reference) &&
                  ((reference - candidate) < ROB_TAG_W'(ROB_ENTRIES));
  endfunction

  always_comb begin
    issue_found = 1'b0;
    issue_index = '0;
    for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1) begin
      if (busy_q[comb_i] && src1_ready_q[comb_i] &&
          src2_ready_q[comb_i] &&
          (!issue_found || rs_is_older(rob_tag_q[comb_i],
                                       rob_tag_q[issue_index]))) begin
        issue_found = 1'b1;
        issue_index = comb_i[INDEX_W-1:0];
      end
    end

    issue_valid_o = issue_found && !flush_i;
    issue_op_o = operation_e'(op_q[issue_index]);
    issue_rob_tag_o = rob_tag_q[issue_index];
    issue_dest_phy_o = dest_phy_q[issue_index];
    issue_src1_value_o = src1_value_q[issue_index];
    issue_src2_value_o = src2_value_q[issue_index];
    issue_imm_o = imm_q[issue_index];
    issue_pc_o = pc_q[issue_index];
    issue_predicted_pc_o = predicted_pc_q[issue_index];
    issue_use_imm_o = use_imm_q[issue_index];
    issue_aux_o = aux_q[issue_index];

    alloc_found = 1'b0;
    alloc_index = '0;
    for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1) begin
      if (!alloc_found && !busy_q[comb_i]) begin
        alloc_found = 1'b1;
        alloc_index = comb_i[INDEX_W-1:0];
      end
    end
    alloc_ready_o = alloc_found && !flush_i;

    occupancy_o = '0;
    for (comb_i = 0; comb_i < DEPTH; comb_i = comb_i + 1)
      if (busy_q[comb_i])
        occupancy_o = occupancy_o + 1'b1;

    alloc_src1_ready_resolved = alloc_src1_ready_i;
    alloc_src1_value_resolved = alloc_src1_value_i;
    if (!alloc_src1_ready_resolved) begin
      if (wb0_valid_i && (wb0_phy_i == alloc_src1_tag_i)) begin
        alloc_src1_ready_resolved = 1'b1;
        alloc_src1_value_resolved = wb0_value_i;
      end else if (wb1_valid_i && (wb1_phy_i == alloc_src1_tag_i)) begin
        alloc_src1_ready_resolved = 1'b1;
        alloc_src1_value_resolved = wb1_value_i;
      end else if (wb2_valid_i && (wb2_phy_i == alloc_src1_tag_i)) begin
        alloc_src1_ready_resolved = 1'b1;
        alloc_src1_value_resolved = wb2_value_i;
      end else if (wb3_valid_i && (wb3_phy_i == alloc_src1_tag_i)) begin
        alloc_src1_ready_resolved = 1'b1;
        alloc_src1_value_resolved = wb3_value_i;
      end
    end

    alloc_src2_ready_resolved = alloc_src2_ready_i;
    alloc_src2_value_resolved = alloc_src2_value_i;
    if (!alloc_src2_ready_resolved) begin
      if (wb0_valid_i && (wb0_phy_i == alloc_src2_tag_i)) begin
        alloc_src2_ready_resolved = 1'b1;
        alloc_src2_value_resolved = wb0_value_i;
      end else if (wb1_valid_i && (wb1_phy_i == alloc_src2_tag_i)) begin
        alloc_src2_ready_resolved = 1'b1;
        alloc_src2_value_resolved = wb1_value_i;
      end else if (wb2_valid_i && (wb2_phy_i == alloc_src2_tag_i)) begin
        alloc_src2_ready_resolved = 1'b1;
        alloc_src2_value_resolved = wb2_value_i;
      end else if (wb3_valid_i && (wb3_phy_i == alloc_src2_tag_i)) begin
        alloc_src2_ready_resolved = 1'b1;
        alloc_src2_value_resolved = wb3_value_i;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (seq_i = 0; seq_i < DEPTH; seq_i = seq_i + 1) begin
        busy_q[seq_i] <= 1'b0;
        op_q[seq_i] <= OP_INVALID;
        rob_tag_q[seq_i] <= '0;
        dest_phy_q[seq_i] <= '0;
        src1_ready_q[seq_i] <= 1'b0;
        src1_tag_q[seq_i] <= '0;
        src1_value_q[seq_i] <= '0;
        src2_ready_q[seq_i] <= 1'b0;
        src2_tag_q[seq_i] <= '0;
        src2_value_q[seq_i] <= '0;
        imm_q[seq_i] <= '0;
        pc_q[seq_i] <= '0;
        predicted_pc_q[seq_i] <= '0;
        use_imm_q[seq_i] <= 1'b0;
        aux_q[seq_i] <= '0;
      end
    end else begin
      for (seq_i = 0; seq_i < DEPTH; seq_i = seq_i + 1) begin
        if (flush_i && busy_q[seq_i] &&
            rob_is_younger(rob_tag_q[seq_i], flush_tag_i)) begin
          busy_q[seq_i] <= 1'b0;
        end else if (busy_q[seq_i]) begin
          if (!src1_ready_q[seq_i]) begin
            if (wb0_valid_i && (wb0_phy_i == src1_tag_q[seq_i])) begin
              src1_ready_q[seq_i] <= 1'b1;
              src1_value_q[seq_i] <= wb0_value_i;
            end else if (wb1_valid_i && (wb1_phy_i == src1_tag_q[seq_i])) begin
              src1_ready_q[seq_i] <= 1'b1;
              src1_value_q[seq_i] <= wb1_value_i;
            end else if (wb2_valid_i && (wb2_phy_i == src1_tag_q[seq_i])) begin
              src1_ready_q[seq_i] <= 1'b1;
              src1_value_q[seq_i] <= wb2_value_i;
            end else if (wb3_valid_i && (wb3_phy_i == src1_tag_q[seq_i])) begin
              src1_ready_q[seq_i] <= 1'b1;
              src1_value_q[seq_i] <= wb3_value_i;
            end
          end
          if (!src2_ready_q[seq_i]) begin
            if (wb0_valid_i && (wb0_phy_i == src2_tag_q[seq_i])) begin
              src2_ready_q[seq_i] <= 1'b1;
              src2_value_q[seq_i] <= wb0_value_i;
            end else if (wb1_valid_i && (wb1_phy_i == src2_tag_q[seq_i])) begin
              src2_ready_q[seq_i] <= 1'b1;
              src2_value_q[seq_i] <= wb1_value_i;
            end else if (wb2_valid_i && (wb2_phy_i == src2_tag_q[seq_i])) begin
              src2_ready_q[seq_i] <= 1'b1;
              src2_value_q[seq_i] <= wb2_value_i;
            end else if (wb3_valid_i && (wb3_phy_i == src2_tag_q[seq_i])) begin
              src2_ready_q[seq_i] <= 1'b1;
              src2_value_q[seq_i] <= wb3_value_i;
            end
          end
        end
      end

      if (!flush_i) begin
        if (issue_valid_o && issue_ready_i)
          busy_q[issue_index] <= 1'b0;

        if (alloc_valid_i && alloc_ready_o) begin
          busy_q[alloc_index] <= 1'b1;
          op_q[alloc_index] <= alloc_op_i;
          rob_tag_q[alloc_index] <= alloc_rob_tag_i;
          dest_phy_q[alloc_index] <= alloc_dest_phy_i;
          src1_ready_q[alloc_index] <= alloc_src1_ready_resolved;
          src1_tag_q[alloc_index] <= alloc_src1_tag_i;
          src1_value_q[alloc_index] <= alloc_src1_value_resolved;
          src2_ready_q[alloc_index] <= alloc_src2_ready_resolved;
          src2_tag_q[alloc_index] <= alloc_src2_tag_i;
          src2_value_q[alloc_index] <= alloc_src2_value_resolved;
          imm_q[alloc_index] <= alloc_imm_i;
          pc_q[alloc_index] <= alloc_pc_i;
          predicted_pc_q[alloc_index] <= alloc_predicted_pc_i;
          use_imm_q[alloc_index] <= alloc_use_imm_i;
          aux_q[alloc_index] <= alloc_aux_i;
        end
      end
    end
  end
endmodule
