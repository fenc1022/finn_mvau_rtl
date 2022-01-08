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
    input logic                     clock,
    input logic [WMEM_ADDR_BW-1:0]  wmem_addr,
    output logic [SIMD*TW-1:0]      wmem_out
);

(* ram_style = "auto" *)
logic [SIMD*TW-1:0] weight_mem [0:WMEM_DEPTH-1];

localparam int PE_TENS = PE_ID / 10;
localparam int PE_ONES = PE_ID % 10;

bit [15:0] fn_pe;
bit [20*8-1:0] weight_mem_file ;

initial begin
    fn_pe[15:8] = PE_TENS + 48; // int to ascii
    fn_pe[7:0] = PE_ONES + 48; // int to ascii
    weight_mem_file[20*8-1:6*8] = "../sim/wgt_mem";
    weight_mem_file[6*8-1:4*8] = fn_pe;
    weight_mem_file[4*8-1:0] = ".mem";
    $readmemh(weight_mem_file, weight_mem);
end

always_comb
    wmem_out <= weight_mem[wmem_addr];

endmodule