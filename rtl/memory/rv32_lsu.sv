module rv32_lsu #(
  parameter int unsigned LQ_DEPTH = rv32_pkg::LQ_ENTRIES,
  parameter int unsigned SQ_DEPTH = rv32_pkg::SQ_ENTRIES
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   flush_i,
  input  rv32_pkg::rob_tag_t     flush_tag_i,

  input  logic                   load_alloc_valid_i,
  output logic                   load_alloc_ready_o,
  output logic [$clog2(LQ_DEPTH)-1:0] load_alloc_index_o,
  input  rv32_pkg::rob_tag_t     load_alloc_rob_tag_i,
  input  rv32_pkg::phy_tag_t     load_alloc_dest_phy_i,
  input  rv32_pkg::mem_size_e    load_alloc_size_i,
  input  logic                   load_alloc_unsigned_i,

  input  logic                   store_alloc_valid_i,
  output logic                   store_alloc_ready_o,
  output logic [$clog2(SQ_DEPTH)-1:0] store_alloc_index_o,
  input  rv32_pkg::rob_tag_t     store_alloc_rob_tag_i,
  input  rv32_pkg::mem_size_e    store_alloc_size_i,
  input  logic                   store_alloc_data_ready_i,
  input  rv32_pkg::phy_tag_t     store_alloc_data_tag_i,
  input  logic [31:0]            store_alloc_data_value_i,

  input  logic                   address_valid_i,
  input  logic                   address_is_store_i,
  input  logic [2:0]             address_index_i,
  input  logic [31:0]            address_value_i,

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

  output logic                   load_result_valid_o,
  input  logic                   load_result_ready_i,
  output rv32_pkg::rob_tag_t     load_result_rob_tag_o,
  output rv32_pkg::phy_tag_t     load_result_dest_phy_o,
  output logic [31:0]            load_result_value_o,

  output logic                   store_complete_valid_o,
  output rv32_pkg::rob_tag_t     store_complete_rob_tag_o,

  input  logic                   store_commit_valid_i,
  input  rv32_pkg::rob_tag_t     store_commit_rob_tag_i,
  input  logic [$clog2(SQ_DEPTH)-1:0] store_commit_index_i,
  output logic                   store_commit_ready_o,

  output logic                   dmem_req_valid_o,
  input  logic                   dmem_req_ready_i,
  output logic                   dmem_req_write_o,
  output logic [31:0]            dmem_req_addr_o,
  output logic [31:0]            dmem_req_wdata_o,
  output logic [3:0]             dmem_req_wstrb_o,
  output rv32_pkg::mem_size_e    dmem_req_size_o,
  input  logic                   dmem_rsp_valid_i,
  input  logic [31:0]            dmem_rsp_rdata_i,

  output logic [$clog2(LQ_DEPTH+1)-1:0] lq_count_o,
  output logic [$clog2(SQ_DEPTH+1)-1:0] sq_count_o
);
  import rv32_pkg::*;

  localparam int unsigned LQ_INDEX_W = $clog2(LQ_DEPTH);
  localparam int unsigned SQ_INDEX_W = $clog2(SQ_DEPTH);

  logic lq_valid_q [0:LQ_DEPTH-1];
  rob_tag_t lq_tag_q [0:LQ_DEPTH-1];
  phy_tag_t lq_dest_q [0:LQ_DEPTH-1];
  mem_size_e lq_size_q [0:LQ_DEPTH-1];
  logic lq_unsigned_q [0:LQ_DEPTH-1];
  logic lq_address_ready_q [0:LQ_DEPTH-1];
  logic [31:0] lq_address_q [0:LQ_DEPTH-1];
  logic lq_sent_q [0:LQ_DEPTH-1];
  logic lq_result_ready_q [0:LQ_DEPTH-1];
  logic [31:0] lq_result_q [0:LQ_DEPTH-1];

  logic sq_valid_q [0:SQ_DEPTH-1];
  rob_tag_t sq_tag_q [0:SQ_DEPTH-1];
  mem_size_e sq_size_q [0:SQ_DEPTH-1];
  logic sq_address_ready_q [0:SQ_DEPTH-1];
  logic [31:0] sq_address_q [0:SQ_DEPTH-1];
  logic sq_data_ready_q [0:SQ_DEPTH-1];
  phy_tag_t sq_data_tag_q [0:SQ_DEPTH-1];
  logic [31:0] sq_data_q [0:SQ_DEPTH-1];
  logic sq_reported_q [0:SQ_DEPTH-1];

  logic pending_q;
  logic pending_drop_q;
  logic [LQ_INDEX_W-1:0] pending_index_q;
  logic [3:0] pending_forward_mask_q;
  logic [31:0] pending_forward_data_q;

  logic load_alloc_found;
  logic store_alloc_found;
  logic load_select_found;
  logic [LQ_INDEX_W-1:0] load_select_index;
  logic load_blocked;
  logic [3:0] load_forward_mask;
  logic [31:0] load_forward_data;
  logic [2:0] selected_load_bytes;
  logic [3:0] selected_load_byte_mask;
  logic load_fully_forwarded;
  logic load_needs_memory;
  logic selected_load_live;

  logic forward_byte_valid [0:3];
  rob_tag_t forward_byte_tag [0:3];
  logic [7:0] forward_byte_data [0:3];

  logic result_select_found;
  logic [LQ_INDEX_W-1:0] result_select_index;
  logic store_complete_found;
  logic [SQ_INDEX_W-1:0] store_complete_index;
  logic store_alloc_data_ready_resolved;
  logic [31:0] store_alloc_data_value_resolved;
  logic store_commit_match;
  logic load_request_selected;
  logic [31:0] merged_response;
  logic [31:0] extended_response;
  integer comb_i, comb_j;
  integer seq_i;

  function automatic logic [31:0] extend_load(
    input logic [31:0] value,
    input mem_size_e size,
    input logic is_unsigned
  );
    begin
      unique case (size)
        MEM_BYTE: extend_load = is_unsigned ? {24'b0, value[7:0]} :
                                             {{24{value[7]}}, value[7:0]};
        MEM_HALF: extend_load = is_unsigned ? {16'b0, value[15:0]} :
                                             {{16{value[15]}}, value[15:0]};
        default:  extend_load = value;
      endcase
    end
  endfunction

  function automatic logic [7:0] select_store_byte(
    input logic [31:0] data,
    input logic [31:0] byte_offset
  );
    begin
      unique case (byte_offset[1:0])
        2'd0: select_store_byte = data[7:0];
        2'd1: select_store_byte = data[15:8];
        2'd2: select_store_byte = data[23:16];
        default: select_store_byte = data[31:24];
      endcase
    end
  endfunction

  always_comb begin
    store_alloc_data_ready_resolved = store_alloc_data_ready_i;
    store_alloc_data_value_resolved = store_alloc_data_value_i;
    if (!store_alloc_data_ready_resolved) begin
      if (wb0_valid_i && (wb0_phy_i == store_alloc_data_tag_i)) begin
        store_alloc_data_ready_resolved = 1'b1;
        store_alloc_data_value_resolved = wb0_value_i;
      end else if (wb1_valid_i && (wb1_phy_i == store_alloc_data_tag_i)) begin
        store_alloc_data_ready_resolved = 1'b1;
        store_alloc_data_value_resolved = wb1_value_i;
      end else if (wb2_valid_i && (wb2_phy_i == store_alloc_data_tag_i)) begin
        store_alloc_data_ready_resolved = 1'b1;
        store_alloc_data_value_resolved = wb2_value_i;
      end else if (wb3_valid_i && (wb3_phy_i == store_alloc_data_tag_i)) begin
        store_alloc_data_ready_resolved = 1'b1;
        store_alloc_data_value_resolved = wb3_value_i;
      end
    end
  end

  always_comb begin
    load_alloc_found = 1'b0;
    load_alloc_index_o = '0;
    for (comb_i = 0; comb_i < LQ_DEPTH; comb_i = comb_i + 1) begin
      if (!load_alloc_found && !lq_valid_q[comb_i]) begin
        load_alloc_found = 1'b1;
        load_alloc_index_o = comb_i[LQ_INDEX_W-1:0];
      end
    end
    load_alloc_ready_o = load_alloc_found && !flush_i;

    store_alloc_found = 1'b0;
    store_alloc_index_o = '0;
    for (comb_i = 0; comb_i < SQ_DEPTH; comb_i = comb_i + 1) begin
      if (!store_alloc_found && !sq_valid_q[comb_i]) begin
        store_alloc_found = 1'b1;
        store_alloc_index_o = comb_i[SQ_INDEX_W-1:0];
      end
    end
    store_alloc_ready_o = store_alloc_found && !flush_i;

    result_select_found = 1'b0;
    result_select_index = '0;
    for (comb_i = 0; comb_i < LQ_DEPTH; comb_i = comb_i + 1) begin
      if (lq_valid_q[comb_i] && lq_result_ready_q[comb_i] &&
          (!result_select_found ||
           rob_is_older(lq_tag_q[comb_i], lq_tag_q[result_select_index]))) begin
        result_select_found = 1'b1;
        result_select_index = comb_i[LQ_INDEX_W-1:0];
      end
    end
    load_result_valid_o = result_select_found &&
      (!flush_i || rob_is_older(lq_tag_q[result_select_index], flush_tag_i));
    load_result_rob_tag_o = lq_tag_q[result_select_index];
    load_result_dest_phy_o = lq_dest_q[result_select_index];
    load_result_value_o = lq_result_q[result_select_index];

    store_complete_found = 1'b0;
    store_complete_index = '0;
    for (comb_i = 0; comb_i < SQ_DEPTH; comb_i = comb_i + 1) begin
      if (sq_valid_q[comb_i] && sq_address_ready_q[comb_i] &&
          sq_data_ready_q[comb_i] && !sq_reported_q[comb_i] &&
          (!store_complete_found ||
           rob_is_older(sq_tag_q[comb_i],
                        sq_tag_q[store_complete_index]))) begin
        store_complete_found = 1'b1;
        store_complete_index = comb_i[SQ_INDEX_W-1:0];
      end
    end
    store_complete_valid_o = store_complete_found &&
      (!flush_i || rob_is_older(sq_tag_q[store_complete_index], flush_tag_i));
    store_complete_rob_tag_o = sq_tag_q[store_complete_index];

    load_select_found = 1'b0;
    load_select_index = '0;
    for (comb_i = 0; comb_i < LQ_DEPTH; comb_i = comb_i + 1) begin
      if (lq_valid_q[comb_i] && lq_address_ready_q[comb_i] &&
          !lq_sent_q[comb_i] && !lq_result_ready_q[comb_i] &&
          (!load_select_found ||
           rob_is_older(lq_tag_q[comb_i], lq_tag_q[load_select_index]))) begin
        load_select_found = 1'b1;
        load_select_index = comb_i[LQ_INDEX_W-1:0];
      end
    end

    selected_load_bytes = mem_bytes(lq_size_q[load_select_index]);
    unique case (lq_size_q[load_select_index])
      MEM_BYTE: selected_load_byte_mask = 4'b0001;
      MEM_HALF: selected_load_byte_mask = 4'b0011;
      default:  selected_load_byte_mask = 4'b1111;
    endcase
    load_blocked = 1'b0;
    load_forward_mask = 4'b0000;
    load_forward_data = 32'b0;
    for (comb_j = 0; comb_j < 4; comb_j = comb_j + 1) begin
      forward_byte_valid[comb_j] = 1'b0;
      forward_byte_tag[comb_j] = '0;
      forward_byte_data[comb_j] = 8'b0;
    end

    if (load_select_found) begin
      for (comb_i = 0; comb_i < SQ_DEPTH; comb_i = comb_i + 1) begin
        if (sq_valid_q[comb_i] &&
            rob_is_older(sq_tag_q[comb_i],
                         lq_tag_q[load_select_index])) begin
          if (!sq_address_ready_q[comb_i]) begin
            load_blocked = 1'b1;
          end else begin
            for (comb_j = 0; comb_j < 4; comb_j = comb_j + 1) begin
              if ((comb_j < selected_load_bytes) &&
                  ((lq_address_q[load_select_index] + comb_j) >=
                   sq_address_q[comb_i]) &&
                  ((lq_address_q[load_select_index] + comb_j) <
                   (sq_address_q[comb_i] +
                    {29'b0, mem_bytes(sq_size_q[comb_i])}))) begin
                if (!sq_data_ready_q[comb_i]) begin
                  load_blocked = 1'b1;
                end else if (!forward_byte_valid[comb_j] ||
                             rob_is_younger(sq_tag_q[comb_i],
                                            forward_byte_tag[comb_j])) begin
                  forward_byte_valid[comb_j] = 1'b1;
                  forward_byte_tag[comb_j] = sq_tag_q[comb_i];
                  forward_byte_data[comb_j] = select_store_byte(
                    sq_data_q[comb_i],
                    lq_address_q[load_select_index] + comb_j -
                    sq_address_q[comb_i]);
                end
              end
            end
          end
        end
      end
    end

    for (comb_j = 0; comb_j < 4; comb_j = comb_j + 1) begin
      if (forward_byte_valid[comb_j]) begin
        load_forward_mask[comb_j] = 1'b1;
        load_forward_data = load_forward_data |
          ({24'b0, forward_byte_data[comb_j]} << (comb_j << 3));
      end
    end
    selected_load_live = load_select_found &&
      (!flush_i || rob_is_older(lq_tag_q[load_select_index], flush_tag_i));
    load_fully_forwarded = selected_load_live && !load_blocked &&
                            ((load_forward_mask & selected_load_byte_mask) ==
                             selected_load_byte_mask);
    load_needs_memory = selected_load_live && !load_blocked &&
                         !load_fully_forwarded && !pending_q;

    store_commit_match = store_commit_valid_i &&
      sq_valid_q[store_commit_index_i] &&
      (sq_tag_q[store_commit_index_i] == store_commit_rob_tag_i) &&
      sq_address_ready_q[store_commit_index_i] &&
      sq_data_ready_q[store_commit_index_i] &&
      (!flush_i || rob_is_older(store_commit_rob_tag_i, flush_tag_i));

    dmem_req_valid_o = 1'b0;
    dmem_req_write_o = 1'b0;
    dmem_req_addr_o = 32'b0;
    dmem_req_wdata_o = 32'b0;
    dmem_req_wstrb_o = 4'b0000;
    dmem_req_size_o = MEM_WORD;
    load_request_selected = 1'b0;
    if (store_commit_match) begin
      dmem_req_valid_o = 1'b1;
      dmem_req_write_o = 1'b1;
      dmem_req_addr_o = sq_address_q[store_commit_index_i];
      dmem_req_wdata_o = sq_data_q[store_commit_index_i];
      dmem_req_size_o = mem_size_e'(sq_size_q[store_commit_index_i]);
      unique case (sq_size_q[store_commit_index_i])
        MEM_BYTE: dmem_req_wstrb_o = 4'b0001;
        MEM_HALF: dmem_req_wstrb_o = 4'b0011;
        default:  dmem_req_wstrb_o = 4'b1111;
      endcase
    end else if (load_needs_memory) begin
      dmem_req_valid_o = 1'b1;
      dmem_req_write_o = 1'b0;
      dmem_req_addr_o = lq_address_q[load_select_index];
      dmem_req_size_o = mem_size_e'(lq_size_q[load_select_index]);
      load_request_selected = 1'b1;
    end
    store_commit_ready_o = store_commit_match && dmem_req_ready_i;

    merged_response = dmem_rsp_rdata_i;
    for (comb_j = 0; comb_j < 4; comb_j = comb_j + 1) begin
      if (pending_forward_mask_q[comb_j]) begin
        merged_response = (merged_response &
                           ~(32'h0000_00ff << (comb_j << 3))) |
                          (pending_forward_data_q &
                           (32'h0000_00ff << (comb_j << 3)));
      end
    end
    extended_response = extend_load(merged_response,
      lq_size_q[pending_index_q], lq_unsigned_q[pending_index_q]);

    lq_count_o = '0;
    for (comb_i = 0; comb_i < LQ_DEPTH; comb_i = comb_i + 1)
      if (lq_valid_q[comb_i]) lq_count_o = lq_count_o + 1'b1;
    sq_count_o = '0;
    for (comb_i = 0; comb_i < SQ_DEPTH; comb_i = comb_i + 1)
      if (sq_valid_q[comb_i]) sq_count_o = sq_count_o + 1'b1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pending_q <= 1'b0;
      pending_drop_q <= 1'b0;
      pending_index_q <= '0;
      pending_forward_mask_q <= '0;
      pending_forward_data_q <= '0;
      for (seq_i = 0; seq_i < LQ_DEPTH; seq_i = seq_i + 1) begin
        lq_valid_q[seq_i] <= 1'b0;
        lq_tag_q[seq_i] <= '0;
        lq_dest_q[seq_i] <= '0;
        lq_size_q[seq_i] <= MEM_WORD;
        lq_unsigned_q[seq_i] <= 1'b0;
        lq_address_ready_q[seq_i] <= 1'b0;
        lq_address_q[seq_i] <= '0;
        lq_sent_q[seq_i] <= 1'b0;
        lq_result_ready_q[seq_i] <= 1'b0;
        lq_result_q[seq_i] <= '0;
      end
      for (seq_i = 0; seq_i < SQ_DEPTH; seq_i = seq_i + 1) begin
        sq_valid_q[seq_i] <= 1'b0;
        sq_tag_q[seq_i] <= '0;
        sq_size_q[seq_i] <= MEM_WORD;
        sq_address_ready_q[seq_i] <= 1'b0;
        sq_address_q[seq_i] <= '0;
        sq_data_ready_q[seq_i] <= 1'b0;
        sq_data_tag_q[seq_i] <= '0;
        sq_data_q[seq_i] <= '0;
        sq_reported_q[seq_i] <= 1'b0;
      end
    end else begin
      for (seq_i = 0; seq_i < SQ_DEPTH; seq_i = seq_i + 1) begin
        if (sq_valid_q[seq_i] && !sq_data_ready_q[seq_i]) begin
          if (wb0_valid_i && (wb0_phy_i == sq_data_tag_q[seq_i])) begin
            sq_data_ready_q[seq_i] <= 1'b1;
            sq_data_q[seq_i] <= wb0_value_i;
          end else if (wb1_valid_i && (wb1_phy_i == sq_data_tag_q[seq_i])) begin
            sq_data_ready_q[seq_i] <= 1'b1;
            sq_data_q[seq_i] <= wb1_value_i;
          end else if (wb2_valid_i && (wb2_phy_i == sq_data_tag_q[seq_i])) begin
            sq_data_ready_q[seq_i] <= 1'b1;
            sq_data_q[seq_i] <= wb2_value_i;
          end else if (wb3_valid_i && (wb3_phy_i == sq_data_tag_q[seq_i])) begin
            sq_data_ready_q[seq_i] <= 1'b1;
            sq_data_q[seq_i] <= wb3_value_i;
          end
        end
      end

      if (flush_i) begin
        for (seq_i = 0; seq_i < LQ_DEPTH; seq_i = seq_i + 1)
          if (lq_valid_q[seq_i] &&
              rob_is_younger(lq_tag_q[seq_i], flush_tag_i))
            lq_valid_q[seq_i] <= 1'b0;
        for (seq_i = 0; seq_i < SQ_DEPTH; seq_i = seq_i + 1)
          if (sq_valid_q[seq_i] &&
              rob_is_younger(sq_tag_q[seq_i], flush_tag_i))
            sq_valid_q[seq_i] <= 1'b0;
        if (pending_q &&
            rob_is_younger(lq_tag_q[pending_index_q], flush_tag_i))
          pending_drop_q <= 1'b1;

        if (store_complete_valid_o)
          sq_reported_q[store_complete_index] <= 1'b1;

        if (load_fully_forwarded) begin
          lq_result_q[load_select_index] <= extend_load(
            load_forward_data, lq_size_q[load_select_index],
            lq_unsigned_q[load_select_index]);
          lq_result_ready_q[load_select_index] <= 1'b1;
          lq_sent_q[load_select_index] <= 1'b1;
        end else if (dmem_req_valid_o && dmem_req_ready_i &&
                     load_request_selected) begin
          pending_q <= 1'b1;
          pending_drop_q <= 1'b0;
          pending_index_q <= load_select_index;
          pending_forward_mask_q <= load_forward_mask;
          pending_forward_data_q <= load_forward_data;
          lq_sent_q[load_select_index] <= 1'b1;
        end

        if (load_result_valid_o && load_result_ready_i)
          lq_valid_q[result_select_index] <= 1'b0;

        if (store_commit_ready_o)
          sq_valid_q[store_commit_index_i] <= 1'b0;
      end else begin
        if (load_alloc_valid_i && load_alloc_ready_o) begin
          lq_valid_q[load_alloc_index_o] <= 1'b1;
          lq_tag_q[load_alloc_index_o] <= load_alloc_rob_tag_i;
          lq_dest_q[load_alloc_index_o] <= load_alloc_dest_phy_i;
          lq_size_q[load_alloc_index_o] <= load_alloc_size_i;
          lq_unsigned_q[load_alloc_index_o] <= load_alloc_unsigned_i;
          lq_address_ready_q[load_alloc_index_o] <= 1'b0;
          lq_sent_q[load_alloc_index_o] <= 1'b0;
          lq_result_ready_q[load_alloc_index_o] <= 1'b0;
        end
        if (store_alloc_valid_i && store_alloc_ready_o) begin
          sq_valid_q[store_alloc_index_o] <= 1'b1;
          sq_tag_q[store_alloc_index_o] <= store_alloc_rob_tag_i;
          sq_size_q[store_alloc_index_o] <= store_alloc_size_i;
          sq_address_ready_q[store_alloc_index_o] <= 1'b0;
          sq_data_ready_q[store_alloc_index_o] <=
            store_alloc_data_ready_resolved;
          sq_data_tag_q[store_alloc_index_o] <= store_alloc_data_tag_i;
          sq_data_q[store_alloc_index_o] <= store_alloc_data_value_resolved;
          sq_reported_q[store_alloc_index_o] <= 1'b0;
        end

        if (address_valid_i) begin
          if (address_is_store_i) begin
            sq_address_q[address_index_i] <= address_value_i;
            sq_address_ready_q[address_index_i] <= 1'b1;
          end else begin
            lq_address_q[address_index_i] <= address_value_i;
            lq_address_ready_q[address_index_i] <= 1'b1;
          end
        end

        if (store_complete_valid_o)
          sq_reported_q[store_complete_index] <= 1'b1;

        if (load_fully_forwarded) begin
          lq_result_q[load_select_index] <= extend_load(
            load_forward_data, lq_size_q[load_select_index],
            lq_unsigned_q[load_select_index]);
          lq_result_ready_q[load_select_index] <= 1'b1;
          lq_sent_q[load_select_index] <= 1'b1;
        end else if (dmem_req_valid_o && dmem_req_ready_i &&
                     load_request_selected) begin
          pending_q <= 1'b1;
          pending_drop_q <= 1'b0;
          pending_index_q <= load_select_index;
          pending_forward_mask_q <= load_forward_mask;
          pending_forward_data_q <= load_forward_data;
          lq_sent_q[load_select_index] <= 1'b1;
        end

        if (load_result_valid_o && load_result_ready_i)
          lq_valid_q[result_select_index] <= 1'b0;

        if (store_commit_ready_o)
          sq_valid_q[store_commit_index_i] <= 1'b0;
      end

      // A request the memory has already accepted may complete during a flush
      // cycle, when the else branch above is skipped in its entirety. That
      // response must still retire the pending marker: the flush squashes the
      // LQ entry, but dropping the handshake leaves pending_q set forever and
      // deadlocks every later load. The payload is delivered only when the
      // load itself survived the flush.
      if (dmem_rsp_valid_i && pending_q) begin
        pending_q <= 1'b0;
        if (!pending_drop_q &&
            !(flush_i &&
              rob_is_younger(lq_tag_q[pending_index_q], flush_tag_i)) &&
            lq_valid_q[pending_index_q]) begin
          lq_result_q[pending_index_q] <= extended_response;
          lq_result_ready_q[pending_index_q] <= 1'b1;
        end
        pending_drop_q <= 1'b0;
      end
    end
  end
endmodule
