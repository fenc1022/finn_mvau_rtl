/*
 * Module: XNOR Multiplication based SIMD
 * Both input activation anf weight are 1-bit
 * */

`timescale 1ns/ 1ns

module mvu_pe_simd_xnor #(
    parameter int TDstI = 4
) (
    input logic unsigned [0:0]          in_act,
    input logic unsigned [0:0]          in_wgt,
    output logic unsigned [TDstI-1:0]   out
);

// Performs multplication by XNOR
always_comb begin
    out[0] = in_act ^ ~in_wgt;
end

if (TDstI >= 2)
    always_comb
        out[TDstI-1:1] = 'd0;

endmodule