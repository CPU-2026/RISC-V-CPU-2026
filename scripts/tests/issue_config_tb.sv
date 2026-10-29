module tb_issue_config;
  import rv32_pkg::*;
  rv32_issue_config dut();
  initial begin
    #1;
    assert(ISSUE_WIDTH==`EXPECT_ISSUE_WIDTH && RENAME_WIDTH==ISSUE_WIDTH)
      else $fatal(1,"issue-width alias contract");
    assert(ROB_ENTRIES==(ISSUE_WIDTH==4?32:16) && ROB_TAG_W==$clog2(ROB_ENTRIES)+1)
      else $fatal(1,"issue-width ROB/tag contract");
    assert(PRF_ENTRIES==(ISSUE_WIDTH==4?64:48) && PHY_TAG_W==6 &&
      BPU_CKPT_ENTRIES==(ISSUE_WIDTH==4?64:32) && BPU_CKPT_ID_W==(ISSUE_WIDTH==4?6:5))
      else $fatal(1,"issue-width PRF/checkpoint contract");
    assert($bits(rob_tag_t)==ROB_TAG_W && $bits(bpu_ckpt_id_t)==BPU_CKPT_ID_W &&
      $bits(store_completion_output_t)==2*ROB_ENTRIES)
      else $fatal(1,"issue-width transported identity/bitmap contract");
    $display("PASS issue-width configuration issue=%0d ROB=%0d PRF=%0d CKPT=%0d tag=%0d",
      ISSUE_WIDTH,ROB_ENTRIES,PRF_ENTRIES,BPU_CKPT_ENTRIES,ROB_TAG_W);
    $finish;
  end
endmodule
