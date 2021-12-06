/*
 * Module: PE adder tree
 * which add the output of SIMD units
 *
 * */

`timescale 1ns/ 1ns

module mvu_pe_adders #(
    parameter int SIMD = 2,
    parameter int TDstI = 4
) (
    input                       clock,
    input                       resetn,
    input logic [TDstI-1:0]     in_simd [0:SIMD-1],
    output logic [TDstI-1:0]    out_add
);

//logic [TDstI-1:0] out_add_int;
// construct adder tree logarithmically
localparam Layer_num = $clog2(SIMD); // 0, 1, 2...L;
logic [TDstI-1:0] tree [0:2**(Layer_num+1) - 2];

always_comb begin
    // layer Layer_num, i.e. leaf layer, initialization
    for (int n = 0; n < 2**Layer_num; n++)
        if (n < SIMD) tree[2**Layer_num-1+n] = in_simd[n];
        else tree[2**Layer_num-1+n] = 'd0;
    
    for (int layer = Layer_num-1; layer >= 0; layer--)
        for (int n = 0; n < 2**layer; n++)
            tree[2**layer-1+n] = tree[2**(layer+1)-1+2*n] + tree[2**(layer+1)+2*n];
end

always_ff @( posedge clock )
    if (!resetn) out_add <= 'd0;
    else out_add <= tree[0];

endmodule