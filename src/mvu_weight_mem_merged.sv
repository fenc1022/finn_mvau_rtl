/*
// This is the top level weight memory file which instantiate all weights memories.
*/

`timescale 1ns/1ns

module mvu_weight_mem_merged #(
    parameter int SIMD = 2,
    parameter int PE = 2,
    parameter int TW = 1,
    parameter int WMEM_DEPTH = 4,
    parameter int WMEM_ADDR_BW = $clog2(WMEM_DEPTH)>1 ? $clog2(WMEM_DEPTH) : 1
) (
    input logic                     clock,
    input logic [WMEM_ADDR_BW-1:0]  wmem_addr,
    output logic [SIMD*TW-1:0]      wmem_out [0:PE-1]
);

generate
    for (genvar p = 0; p < PE; p++) begin
        mvu_weight_mem #(
            .PE_ID(p),
            .SIMD(SIMD),
            .TW(TW),
            .WMEM_DEPTH(WMEM_DEPTH))
        mvu_weight_mem (
            .clock,
            .wmem_addr,
            .wmem_out(wmem_out[p])
        );
    end
endgenerate

endmodule