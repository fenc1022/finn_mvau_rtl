/*
 * Module: PE adder tree based on popcount
 * which sum up SIMD outputs based on counting '1's
 *
 * */

`timescale 1ns/1ns

module mvu_pe_popcount #(
    parameter int SIMD = 2,
    parameter int TDstI = 4
) (
    input                       clock,
    input                       resetn,
    input logic [TDstI-1:0]     in_simd[0:SIMD-1] ,
    output logic [TDstI-1:0]    out_add
);

logic [TDstI-1:0] out_add_int;

always_comb begin
    out_add_int = in_simd[0];
    for (int i = 1; i < SIMD; i++)
        out_add_int = out_add_int + in_simd[i];
end

always_ff @( posedge clock ) begin
    if (!resetn) out_add <= '0;
    else out_add <= out_add_int;
end

endmodule