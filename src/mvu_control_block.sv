// This file lists an RTL implementation of the control block
// which generates address for weight memory

`timescale 1ns/1ns

module mvu_control_block #(
    parameter int SF = 8,
    parameter int NF = 8,
    parameter int WMEM_DEPTH = 4,
    localparam WMEM_ADDR_BW = $clog2(WMEM_DEPTH)>1 ? $clog2(WMEM_DEPTH) : 1
) (
    input logic                         resetn,
    input logic                         clock,
    input logic                         wmem_wready,
    output logic                        wmem_valid,
    output logic [WMEM_ADDR_BW-1 :0]    wmem_addr
);

assign wmem_valid = wmem_wready;

always_ff @(posedge clock)
    if (!resetn)
        wmem_addr <= 'd0;
    else if (wmem_wready)
        if (wmem_addr == WMEM_ADDR_BW'(WMEM_DEPTH-1))
            wmem_addr <= 'd0;
        else
            wmem_addr <= wmem_addr + 1;

endmodule