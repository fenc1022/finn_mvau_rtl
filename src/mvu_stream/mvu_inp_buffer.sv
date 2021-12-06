`timescale 1ns/1ns

module mvu_inp_buffer #(
    parameter int SIMD = 2,
    parameter int TSrcI = 4,
    parameter int BUF_LEN = 16,
    parameter int BUF_ADDR=$clog2(BUF_LEN)>=1 ? $clog2(BUF_LEN) : 1
) (    
	input logic 		            clock,
	input logic 		            resetn,
	input logic [SIMD*TSrcI-1:0]    din,
	input logic 		            wr_en,
	input logic [BUF_ADDR-1:0]      addr,
	output logic [SIMD*TSrcI-1:0] 	dout
);

   logic [SIMD*TSrcI-1:0]   inp_buffer [0:BUF_LEN-1];
        
    always_ff @(posedge clock) begin
        if (wr_en) begin
	        inp_buffer[addr] <= din;
	        dout <= din;
        end
        else begin
	        dout <= inp_buffer[addr];
      end      
   end   

endmodule // mvau_inp_buffer
