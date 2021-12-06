/*
 * Module: PE accumulator
 * which accumulate as a row of weights
 * is multiplied by the input activation vector
 *
 * */

`timescale 1ns/1ns

module mvu_pe_acc #(
    parameter int TDstI = 4
) (
    input logic             resetn,
    input logic             clock,
    input logic             do_mvu_stream,
    input logic             sf_clr, // clear this accumulator, from control unit
    input logic [TDstI-1:0] in_acc, // from adders/popcount
    output logic             out_acc_v, // output valid
    output logic [TDstI-1:0] out_acc
);

logic   sf_clr_dly;
logic   do_mvu_stream_dly;

always_ff @( posedge clock ) begin
    if (!resetn) begin
        out_acc_v <= '0;
        do_mvu_stream_dly <= '0;
        sf_clr_dly <= '0;
    end else begin
        sf_clr_dly <= sf_clr;
        do_mvu_stream_dly <= do_mvu_stream;
        // Match the two cycles pipeline
        // One after SIMDs and one after adders
        // Thus reaches the last cycle of accumulation
        out_acc_v <= sf_clr_dly;
    end
end

always_ff @( posedge clock ) begin
    if (!resetn)        out_acc <= '0;
    else if (do_mvu_stream_dly)
        if (out_acc_v)  out_acc <= in_acc;
        else            out_acc <= out_acc + in_acc;
    else if (out_acc_v) out_acc <= '0;
end

endmodule