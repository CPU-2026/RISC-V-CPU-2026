// The probe contains the exact production byte_overlap function. An independent
// 64-bit linear interval oracle preserves its no-wrap-at-zero interpretation.
module tb_lsu_word_neighbors;
  import rv32_pkg::*;
  lsu_word_overlap_probe probe();
  int checks = 0;
  int unsigned randomState = 32'h28c46e17;

  function automatic int span(input mem_size_e size);
    case (size)
      MEM_BYTE: return 1;
      MEM_HALF: return 2;
      default: return 4;
    endcase
  endfunction
  function automatic int unsigned random_word();
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
  endfunction
  task automatic check_overlap(input logic [31:0] la, input mem_size_e ls,
                                input logic [31:0] sa, input mem_size_e ss);
    logic [29:0] nextWord, prevWord;
    longint unsigned l, s;
    bit expected, actual;
    nextWord = sa[31:2] + 30'd1;
    prevWord = sa[31:2] - 30'd1;
    actual = probe.byte_overlap(la, ls, sa, ss, nextWord, prevWord);
    l = {32'b0, la}; s = {32'b0, sa};
    expected = l < s + 64'(span(ss)) && s < l + 64'(span(ls));
    assert(actual == expected) else $fatal(1,
      "word overlap mismatch L=%h/%0d S=%h/%0d next=%h prev=%h got=%0d expected=%0d",
      la, span(ls), sa, span(ss), nextWord, prevWord, actual, expected);
    checks++;
  endtask
  task automatic word_window(input logic [29:0] storeWord);
    logic [29:0] loadWord;
    for (int delta = -2; delta <= 2; delta++) begin
      loadWord = storeWord + 30'(delta);
      for (int so = 0; so < 4; so++)
        for (int lo = 0; lo < 4; lo++)
          for (int ss = 0; ss < 4; ss++)
            for (int ls = 0; ls < 4; ls++)
              check_overlap({loadWord, 2'(lo)}, mem_size_e'(ls),
                            {storeWord, 2'(so)}, mem_size_e'(ss));
    end
  endtask
  initial begin
    logic [31:0] s, l;
    word_window(30'd0); word_window(30'd1); word_window(30'h3ffffffe); word_window(30'h3fffffff);
    // Constant +/-1 carry/borrow chains of every possible word-address length.
    for (int bitIndex = 0; bitIndex < 30; bitIndex++) begin
      word_window((30'd1 << bitIndex)-30'd1);
      word_window(30'd1 << bitIndex);
    end
    for (int sample = 0; sample < 100000; sample++) begin
      s = random_word();
      case (sample % 4)
        0: l = s + 32'(random_word() % 9) - 32'd4;
        1: l = {s[31:2] + 30'd1, 2'(random_word())};
        2: l = {s[31:2] - 30'd1, 2'(random_word())};
        default: l = random_word();
      endcase
      check_overlap(l, mem_size_e'(random_word()), s, mem_size_e'(random_word()));
    end
    $display("PASS LSU word neighbors checks=%0d", checks);
    $finish;
  end
endmodule
