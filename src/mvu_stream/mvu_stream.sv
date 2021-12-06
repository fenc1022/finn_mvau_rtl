`timescale 1ns/1ns

module mvu_stream #(
    parameter KDim = 2, // kernel dimension
    parameter IFMCh = 2, // input channels
    parameter OFMCh = 2, // output channels
    parameter MatrixW = 8, // input width
    parameter MatrixH = 2, // input height
    parameter SIMD = 2, // input columns compute in parallel
    parameter PE = 2, // input row compute in parallel
    parameter TSrcI = 4, // bit width of input
    parameter TW = 1, // bit width of weights
    parameter TDstI = 8, // bit width of output
    parameter OP_SGN = 0 // operand signed/unsigned
) (
    input logic                     resetn,
    input logic                     clock,
    // weight interface
    input logic                     in_wgt_v,
    output logic                    wmem_wready,
    input logic [0:PE*SIMD*TW-1]    in_wgt,
    // input interface
    output logic                    wready,
    input logic                     in_v,
    input logic [SIMD*TSrcI-1:0]    in_act,
    // output interface
    output logic                    out_v,
    input logic                     rready,
    output logic [PE*TDstI-1:0]     out
);

localparam SF = MatrixW / SIMD;
localparam NF = MatrixH / PE;
localparam SF_T = $clog2(SF)>=1 ? $clog2(SF) : 1;

logic [SIMD*TSrcI-1:0]      in_act_reg;
logic [0:SIMD-1][TW-1:0]    in_wgt_reg[0:PE-1];
logic                       ib_wen;
logic                       sf_clr; // accumulator clear
logic [SIMD*TSrcI-1:0]      out_act; // output of input buffer
logic [0:PE-1][TDstI-1:0]   out_pe; // all PEs outputs
logic [0:PE-1]              out_pe_v; // PEs outputs valid
logic                       do_mvu_stream; // active mvu operation
logic [0:SIMD*TW-1]         in_wgt2d[0:PE-1]; // unpack input weight
logic                       wait_rready; // waiting for rready after valid is assert

always_ff @( posedge clock )
    if (!resetn) do_mvu_stream <= 1'b0;
    else        do_mvu_stream <= (in_v & wready) | (in_wgt_v & wmem_wready);

generate
    for (genvar p = 0; p < PE; p++)
        assign in_wgt2d[p] = in_wgt[SIMD*TW*p:SIMD*TW*p+(SIMD*TW-1)];
endgenerate

// register input
always_ff @( posedge clock )
    if (!resetn)
        for (int i=0; i < PE; i++)
            in_wgt_reg[i] <= 'd0;
    else
        for (int i=0; i < PE; i++)
            in_wgt_reg[i] <= in_wgt2d[i];

assign in_act_reg = in_act;

// TODO: block every time out_v valid
// 50% efficiency at most?
always_ff @(posedge clock)
    if (!resetn)        wait_rready <= 1'b0;
    else if (rready)    wait_rready <= 1'b0;
    else if (out_v)     wait_rready <= 1'b1;

// Control logic for accessing input buffer
logic [SF_T-1:0] sf_cnt;

mvu_stream_control_block #(
    .SF(SF),
    .NF(NF)
)
mvu_stream_control_block(
    .resetn,
    .clock,
    .in_v,
    .wait_rready,
    .ib_wen,
    .wready,
    .wmem_wready,
    .sf_clr,
    .sf_cnt
);

mvu_inp_buffer #(
    .SIMD(SIMD),
    .TSrcI(TSrcI),
    .BUF_LEN(SF)
)
mvu_inp_buffer(
    .clock,
    .resetn,
    .din(in_act_reg),
    .wr_en(ib_wen),
    .addr(sf_cnt),
    .dout(out_act)
);

// PEs generation
// PEs read in different weights & same input
// PEs output TDstI btis each and packed together
generate
    for (genvar pe_idx=0; pe_idx < PE; pe_idx++)
        mvu_pe #(
            .SIMD(SIMD),
            .TSrcI(TSrcI),
            .TW(TW),
            .TDstI(TDstI),
            .OP_SGN(OP_SGN)
        )
        mvu_pe(
            .resetn,
            .clock,
            .sf_clr,
            .do_mvu_stream,
            .in_act(out_act),
            .in_wgt(in_wgt_reg[pe_idx]),
            .out_v(out_pe_v[pe_idx]), //(out_pe_v[PE-pe_idx-1]),
            .out(out_pe[pe_idx]) //(out_pe[PE-pe_idx-1])
        );
endgenerate

logic out_pe_v_one;
assign out_pe_v_one = |out_pe_v;

logic out_pe_v_hold;
logic [PE*TDstI-1:0] out_pe_hold;

// save the 2nd PE output in case previous output
// is not consumed in time
always_ff @( posedge clock )
    if (!resetn)                        out_pe_v_hold <= 1'b0;
    else if (~out_v & out_pe_v_hold)    out_pe_v_hold <= 1'b0;
    else if (out_pe_v_one & out_v)      out_pe_v_hold <= 1'b1;

always_ff @( posedge clock )
    if (!resetn)                    out_pe_hold <= 'd0;
    else if (out_pe_v_one & out_v)  out_pe_hold <= out_pe;
    else                            out_pe_hold <= out_pe_hold;
    
always_ff @( posedge clock )
    if (!resetn)                out <= 'd0;
    else if (out_v & ~rready)   out <= out;
    else if (out_pe_v_one)      out <= out_pe;
    else if (out_pe_v_hold)     out <= out_pe_hold;

always_ff @( posedge clock )
    if (!resetn)                out_v <= 1'b0;
    else if (out_pe_v_one)      out_v <= 1'b1;
    else if (out_v & rready)    out_v <= 1'b0;
    else if (out_pe_v_hold)     out_v <= 1'b1;

endmodule