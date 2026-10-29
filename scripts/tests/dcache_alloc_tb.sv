// The probe contains the exact production allocate_request block. Its grant is
// decoded from the selected index; Q2's speculative one-hot implementation was
// rejected. Released rows are deliberately NOT free until next cycle.
module tb_dcache_alloc;
  logic [2:0] cursor = 0;
  logic [7:0] active = 0, released = 0;
  logic accept = 0;
  integer allocation;
  logic [7:0] grant;
  int checks = 0;
  dcache_alloc_probe probe (
    .cursorInner(cursor), .activeInput(active), .releasedInner(released),
    .acceptInner(accept), .allocationInner(allocation),
    .allocationMaskInner(grant)
  );
  initial begin
    int expected, slot;
    logic [7:0] expectedFree, expectedGrant;
    for (int head = 0; head < 8; head++) begin
      for (int busy = 0; busy < 256; busy++) begin
        // Independent reverse priority fold, not the production found fold.
        expected = -1;
        for (int age = 7; age >= 0; age--) begin
          slot = (head+age) & 7;
          if (!(busy & (1 << slot))) expected = slot;
        end
        expectedFree = expected < 0 ? 8'b0 : 8'(1 << expected);
        for (int releaseMask = 0; releaseMask < 256; releaseMask++) begin
          for (int accepted = 0; accepted < 2; accepted++) begin
            cursor = 3'(head); active = 8'(busy); released = 8'(releaseMask);
            accept = 1'(accepted); expectedGrant = accepted != 0 ? expectedFree : 8'b0;
            #1;
            assert(allocation == (accepted != 0 ? expected : -1) &&
                   grant == expectedGrant)
              else $fatal(1, "allocation mismatch cursor=%0d active=%h release=%h accept=%0d index=%0d grant=%h",
                cursor, active, released, accept, allocation, grant);
            checks++;
          end
        end
      end
    end
    $display("PASS DCache allocation combinations=%0d", checks);
    $finish;
  end
endmodule
