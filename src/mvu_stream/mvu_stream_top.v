`timescale 1ns/1ns

module mvu_stream_top #(
    parameter KDim = 2, // kernel dimension
    parameter IFMCh = 2, // input channels
    parameter OFMCh = 2, // output channels
    parameter SIMD = 2, // input columns compute in parallel
    parameter PE = 2, // input row compute in parallel
    parameter TSrcI = 4, // bit width of input
    parameter TW = 1, // bit width of weights
    parameter TDstI = 8, // bit width of output
    parameter OP_SGN = 2'b00, // operand signed/unsigned
    parameter MatrixW = KDim*KDim*IFMCh, // input width
    parameter MatrixH = OFMCh // input height
) (
    input                   aresetn,
    input                   aclk,
    output [PE*TDstI-1:0]   m0_axis_tdata,
    output                  m0_axis_tvalid,
    input                   m0_axis_tready,

    input [SIMD*TSrcI-1:0]  s0_axis_tdata,
    input                   s0_axis_tvalid,
    output                  s0_axis_tready,

    input [0:PE*SIMD*TW-1]  s1_axis_tdata,
    input                   s1_axis_tvalid,
    output                  s1_axis_tready
);

mvu_stream #(
    .KDim   (KDim   ),
    .IFMCh  (IFMCh  ),
    .OFMCh  (OFMCh  ),
    .MatrixW(MatrixW),
    .MatrixH(MatrixH),
    .SIMD   (SIMD   ),
    .PE     (PE     ), // input row compute in parallel
    .TSrcI  (TSrcI  ), // bit width of input
    .TW     (TW     ), // bit width of weights
    .TDstI  (TDstI  ), // bit width of output
    .OP_SGN (OP_SGN ) // operand signed/unsigned
) mvu_stream (
    .resetn     (aresetn),
    .clock      (aclk),
    .in_wgt     (s1_axis_tdata),
    .in_wgt_v   (s1_axis_tvalid),
    .wmem_wready(s1_axis_tready),
    .in_act     (s0_axis_tdata),
    .in_v       (s0_axis_tvalid),
    .wready     (s0_axis_tready),
    .out        (m0_axis_tdata),
    .out_v      (m0_axis_tvalid),
    .rready     (m0_axis_tready)
);

endmodule