/*
 * Module: Standard Multiplication based SIMD
 *
 * */

`timescale 1ns/ 1ns

module mvu_pe_simd #(
    parameter int TSrcI = 4, // Input word length
    parameter int TW = 4, // Weight word length
    parameter int TDstI = 8, // Output word length
    parameter bit [1:0] OP_SGN = 0
    // OP_SGN[1]: if inputs are signed
    // OP_SGN[0]: if weights are signed
    // when operand bit width is greater than 1,
    // 0: unsigned; 1: signed
    // when operand bit width is 1,
    // 0: 0/1 1: +1/-1
) (
    input logic [TSrcI-1:0]     in_act,
    input logic [TW-1:0]        in_wgt,
    output logic [TDstI-1:0]    out
);

bit Inp1Bit = (TSrcI == 1) ? 1 : 0;
bit Wgt1Bit = (TW == 1) ? 1 : 0;

    // inputs * weights
always_comb
    case ({Inp1Bit, Wgt1Bit, OP_SGN})
        4'b0_0_00: // N-bit unsigned * N-bit unsigned
            out = in_act * in_wgt;
        4'b0_0_01: // N-bit unsigned * N-bit signed
            out = $signed({1'b0, in_act}) * $signed(in_wgt);
        4'b0_0_10: // N-bit signed * N-bit unsigned
            out = $signed(in_act) * $signed({1'b0, in_wgt});
        4'b0_0_11:  // N-bit signed * N-bit signed
            out = $signed(in_act) * $signed(in_wgt);

        4'b1_0_00: // 1-bit 0/1 * N-bit unsigned
            out = in_act==1'b1 ? in_wgt : '0;
        4'b1_0_01: // 1-bit 0/1 * N-bit signed
            out = in_act==1'b1 ? in_wgt : '0;
        4'b1_0_10: // 1-bit +1/-1 * N-bit unsigned
            out = in_act==1'b1 ?
                $signed({1'b0, in_wgt}) :
                ~$signed({1'b0, in_wgt}) + 1'b1;
        4'b1_0_11: // 1-bit +1/-1 * N-bit signed
            out = in_act==1'b1 ? in_wgt : ~in_wgt + 1'b1;

        4'b0_1_00: // N-bit unsigned * 1-bit 0/1
            out = in_wgt==1'b1 ? in_act : '0;
        4'b0_1_01: // N-bit unsigned * 1-bit +1/-1
            out = in_wgt==1'b1 ?
                $signed({1'b0, in_act}) :
                ~$signed({1'b0, in_act}) + 1'b1;
        4'b0_1_10: // N-bit signed * 1-bit 0/1
            out = in_wgt==1'b1 ? in_act : '0;
        4'b0_1_11: // N-bit signed * 1-bit +1/-1
            out = in_wgt==1'b1 ? in_act : ~in_act + 1'b1;

        4'b1_1_00: // 1-bit 0/1 * 1-bit 0/1
            out = in_act & in_wgt;
        4'b1_1_01: // 1-bit 0/1 * 1-bit +1/-1
            out = in_act==1'b1 ? in_wgt : '0;
        4'b1_1_10: // 1-bit +1/-1 * 1-bit 0/1
            out = in_wgt==1'b1 ? in_act : '0;
        4'b1_1_11: // 1-bit +1/-1 * 1-bit +1/-1
            out = ~(in_act ^ in_wgt);
        default:
            out = '0;
    endcase


endmodule