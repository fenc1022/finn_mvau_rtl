/*
 * Module: Binary Multiplication based SIMD
 *
 * */

`timescale 1ns/ 1ns

module mvu_pe_simd_binary #(
    parameter int TSrcI = 1, // Input word length
    parameter int TW = 1, // Weight word length
    parameter int TDstI = 1 // Output word length
) (
    input logic [TSrcI-1:0]     in_act,
    input logic [TW-1:0]        in_wgt,
    output logic [TDstI-1:0]    out
);


generate // If generate statement
    if (TW==1) //  If weight is 1-bit
        always_comb
            out = in_wgt==1'b1 ? in_act : ~in_act + 1'b1;
endgenerate

generate // If generate statement
    if (TSrcI==1) //  If activation is 1-bit
        always_comb
            out = in_act==1'b1 ? in_wgt : ~in_wgt + 1'b1;
endgenerate

endmodule