// The probe extracts R2's actual old-state branch preparation and final narrow
// selection. fillBeat is the already-validated line response, not a new bypass.
module tb_dcache_response;
  logic rstN = 0, fillBeat = 0;
  logic [1:0] transaction = 0;
  logic [11:0] owners = 0;
  logic [3:0] responded = 0;
  logic [7:0] writes = 0;
  logic [23:0] ids = 0;
  integer normalResponse = -1, response;
  logic early, valid;
  logic [2:0] id;
  int checks = 0;
  dcache_response_probe probe (
    .rstNInput(rstN), .fillBeatInner(fillBeat), .transactionInput(transaction),
    .ownersInput(owners), .respondedInput(responded), .writesInput(writes), .idsInput(ids),
    .normalResponseInner(normalResponse), .responseInner(response),
    .earlyInner(early), .validOutput(valid), .transactionOutput(id)
  );
  initial begin
    int expected, seed;
    bit expectedEarly;
    logic [2:0] expectedId;
    for (int miss = 0; miss < 4; miss++) begin
      for (int source = 0; source < 8; source++) begin
        for (int m = 0; m < 4; m++) owners[m*3+:3] = 3'((source+miss+m+1)&7);
        owners[miss*3+:3] = 3'(source);
        transaction = 2'(miss);
        for (int normal = -1; normal < 8; normal++) begin
          normalResponse = normal;
          for (int done = 0; done < 16; done++) begin
            responded = 4'(done);
            for (int stores = 0; stores < 256; stores++) begin
              writes = 8'(stores);
              seed = ((stores >> 5)+normal+1+miss) & 7;
              // Distinct transport IDs expose mixing request/MSHR/owner domains.
              for (int row = 0; row < 8; row++) ids[row*3+:3] = 3'((row*3+seed)&7);
              for (int fill = 0; fill < 2; fill++) begin
                for (int reset = 0; reset < 2; reset++) begin
                  rstN = 1'(reset); fillBeat = 1'(fill);
                  expectedEarly = fill != 0 && (stores & (1 << source)) == 0 && (done & (1 << miss)) == 0;
                  expected = expectedEarly ? source : normal;
                  expectedId = expected < 0 ? 3'b0 : ids[expected*3+:3];
                  #1;
                  assert(early == expectedEarly && response == expected &&
                         valid == (reset != 0 && expected >= 0) && id == expectedId)
                    else $fatal(1, "response identity mismatch miss=%0d source=%0d normal=%0d done=%h stores=%h fill=%0d reset=%0d got=%0d expected=%0d ids=%h port=%h owner=%0d rowId=%0d fillId=%0d early=%0d index=%0d",
                      miss, source, normal, done, stores, fill, reset, id, expectedId,
                      ids, probe.idsInput, probe.missesInner[miss].owner,
                      probe.requestInner[source].request.transaction,
                      probe.fillTransactionInner[miss], early, response);
                  checks++;
                end
              end
            end
          end
        end
      end
    end
    $display("PASS DCache response identities combinations=%0d", checks);
    $finish;
  end
endmodule
