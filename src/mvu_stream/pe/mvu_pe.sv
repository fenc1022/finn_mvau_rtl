/*
 * Module: MVU Processing Element
 * which instantiates SIMDs, adders & Accumulators.
 *
 * */

`timescale 1ns/1ns

module mvu_pe #(
    parameter int SIMD   = 2,
    parameter int TSrcI  = 4,
    parameter int TW     = 4,
    parameter int TDstI  = 4,
    parameter bit[1:0] OP_SGN = 0 // signed or unsigned
) (
    input logic                     resetn,
    input logic                     clock,
    input logic                     sf_clr, // clear accmulator, from control unit
    input logic                     do_mvu_stream, // how long pe operates
    input logic [TSrcI*SIMD-1:0]    in_act,
    input logic [0:SIMD-1][TW-1:0]  in_wgt,
    output logic                    out_v,
    output logic [TDstI-1:0]        out
);

logic [TDstI-1:0]       out_simd[0:SIMD-1]; // SIMD output
logic [TDstI-1:0]       out_add; // adder-tree output
logic [0:TSrcI*SIMD-1]  in_act_rev; // index reversed copy of in_act
logic [TSrcI-1:0]       in_act_packed[0:SIMD-1]; // packed copy of in_act

assign in_act_rev = in_act;
generate
    for (genvar idx=0; idx<SIMD; idx=idx+1)
        assign in_act_packed[idx] = in_act_rev[idx*TSrcI:idx*TSrcI+TSrcI-1];
endgenerate

// SIMDs instantiation
genvar simd_idx;

for (simd_idx = 0; simd_idx < SIMD; simd_idx = simd_idx+1)
    mvu_pe_simd #(
        .TSrcI   (TSrcI),
        .TW      (TW),
        .TDstI   (TDstI),
        .OP_SGN  (OP_SGN)
    ) mvu_pe_simd(
        .in_act (in_act_packed[simd_idx]),
        .in_wgt (in_wgt[simd_idx]),
        .out    (out_simd[simd_idx])
    );

// Adder-Tree instantiation
// TODO: research how 1bit adder works
// Method 1: popcount
mvu_pe_popcount #(
    .SIMD   (SIMD),
    .TDstI  (TDstI)
) mvu_pe_addertree(
    .clock  (clock),
    .resetn (resetn),
    .in_simd(out_simd),
    .out_add(out_add)
);

// Method 2: binary tree
// mvu_pe_adders #(
//     .SIMD   (SIMD),
//     .TDstI  (TDst_I)
// ) mvu_pe_addertree(
//     .clock  (clock),
//     .resetn (resetn),
//     .in_simd(out_simd),
//     .out_add(out_add)
// );

// Accumulator instantiation
mvu_pe_acc #(
    .TDstI  (TDstI)
) mvu_pe_acc (
    .clock,
    .resetn,
    .do_mvu_stream,
    .sf_clr,
    .in_acc(out_add),
    .out_acc_v(out_v),
    .out_acc(out)
);

endmodule

