// Exact production assignments are extracted into the probe by the driver.
module tb_icache_enable_bool;
  logic [8:0] flags = 0;
  logic [3:0] count = 0;
  logic actual, expected;
  int checks = 0;
  icache_enable_probe probe (.flagsInput(flags), .countInner(count),
    .enableOutput(actual), .legacyOutput(expected));
  initial begin
    for (int occupancy = 0; occupancy < 16; occupancy++) begin
      for (int pattern = 0; pattern < 512; pattern++) begin
        count = 4'(occupancy); flags = 9'(pattern); #1;
        assert(actual === expected)
          else $fatal(1, "enable mismatch count=%0d flags=%h actual=%b expected=%b", count, flags, actual, expected);
        checks++;
      end
    end
    $display("PASS ICache enable Boolean combinations=%0d", checks);
    $finish;
  end
endmodule
