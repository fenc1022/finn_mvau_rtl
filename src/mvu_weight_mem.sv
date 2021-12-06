/*
// This is a single memory for weight storage.
// memory depth is (KDim^2 * IFMCh * OFMCh) / (SIMD*PE)
// memory width is (SIMD * TW)
*/

`timescale 1ns/1ns

module mvu_weight_mem #(
    parameter int PE_ID = 0,
    parameter int SIMD = 2,
    parameter int TW = 1,
    parameter int WMEM_DEPTH = 4,
    parameter int WMEM_ADDR_BW = $clog2(WMEM_DEPTH)>1 ? $clog2(WMEM_DEPTH) : 1
) (
    input logic                     clock;
    input logic [WMEM_ADDR_BW-1:0]  wmem_addr,
    output logic [SIMD*TW-1:0]      wmem_out
);

(* ram_style = "auto" *)
logic [SIMD*TW-1:0] weight_mem [0:WMEM_DEPTH-1];

string weight_mem_file = {"weight_mem", str.itoa(PE_ID), ".mem"};

initial
    $readmemh(weight_mem_file, weight_mem);

always_ff @(posedge clock)
    wmem_out <= weight_mem[wmem_addr];

endmodule