/*
 * Module: Standard Multiplication based SIMD
 *
 * */

`timescale 1ns/ 1ns

module mvu_pe_simd_std #(
    parameter int TSrcI = 4, // Input word length
    parameter int TW = 4, // Weight word length
    parameter int TDstI = 8, // Output word length
    parameter int OP_SGN = 0 // Enumerated values showing 
        //signedness/unsignedness of input activation/weights
) (
    input logic [TSrcI-1:0]     in_act,
    input logic [TW-1:0]        in_wgt,
    output logic [TDstI-1:0]    out
);

generate // If generate statement
    if (OP_SGN == 0) // Both operators unsigned
        always_comb
            out = in_act * in_wgt;
    else if (OP_SGN == 1) // in_act signed
        always_comb
            out = $signed(in_act) * $signed({1'b0, in_wgt});
    else if (OP_SGN == 2) // in_wgt sigbned
        always_comb
            out = $signed({1'b0, in_act}) * $signed(in_wgt);
    else if (OP_SGN == 3) // Both operator signed
        always_comb
            out = $signed(in_act) * $signed(in_wgt);
endgenerate

endmodule