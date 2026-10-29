// Compile-time checks only: no runtime mode mux, registers, or datapath.
// ISSUE_WIDTH is ordered rename/allocation, NOT rv32_rs.ISSUE_WIDTH dispatch.
module rv32_issue_config #(
  parameter int unsigned ISSUE_WIDTH = rv32_pkg::ISSUE_WIDTH
) ();
  import rv32_pkg::*;
  if (ISSUE_WIDTH != 1 && ISSUE_WIDTH != 2 && ISSUE_WIDTH != 4) begin : g_invalid_width
    initial $fatal(1, "CPU_ISSUE_WIDTH must be 1, 2 or 4");
  end
  if (rv32_pkg::ISSUE_WIDTH != rv32_pkg::RENAME_WIDTH) begin : g_conflicting_macros
    initial $fatal(1, "CPU_ISSUE_WIDTH conflicts with legacy CPU_RENAME_WIDTH");
  end
  // A package defines transport types for one compilation. Local 1/2 width
  // overrides share ROB16; a local width4 override also needs a width4 package.
  if (ROB_ENTRIES != (ISSUE_WIDTH == 4 ? 32 : 16)) begin : g_mismatched_package
    initial $fatal(1, "ISSUE_WIDTH and package ROB capacity disagree; set CPU_ISSUE_WIDTH at compile time");
  end
  if (ROB_TAG_W != $clog2(ROB_ENTRIES)+1 || PHY_TAG_W != $clog2(PRF_ENTRIES)) begin : g_invalid_tags
    initial $fatal(1, "issue-width identity widths do not match configured capacities");
  end
  if (PRF_ENTRIES < ARCH_REGS+ROB_ENTRIES) begin : g_insufficient_physical_registers
    initial $fatal(1, "issue-width PRF does not cover architectural plus in-flight destinations");
  end
  if (BPU_CKPT_ENTRIES < ROB_ENTRIES+FETCH_REQUEST_ENTRIES+FQ_ENTRIES+IQ_ENTRIES) begin : g_checkpoint_budget
    initial $fatal(1, "issue-width configuration exceeds checkpoint live budget");
  end
endmodule
