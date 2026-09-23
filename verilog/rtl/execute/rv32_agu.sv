module rv32_agu (
  input  rv32_pkg::address_generation_input_t addressInput,
  output rv32_pkg::address_generation_output_t addressOutput
);
  logic unusedCoutInner;

  rv32_add #(.WIDTH(32)) u_add (
    .aInput(addressInput.baseAddress), .bInput(addressInput.offset), .cinInput(1'b0),
    .sumOutput(addressOutput.address), .coutOutput(unusedCoutInner)
  );
endmodule
