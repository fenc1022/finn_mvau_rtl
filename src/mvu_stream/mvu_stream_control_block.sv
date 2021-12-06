`timescale 1ns/1ns

module mvu_stream_control_block #(
    parameter int SF = 8,
    parameter int NF = 1,
    parameter int SF_T = $clog2(SF)>=1 ? $clog2(SF) : 1,
    parameter int NF_T = $clog2(NF)>=1 ? $clog2(NF) : 1
) (
    input logic             resetn,
    input logic             clock,
    input logic             in_v, // input stream valid
    input logic             wait_rready, // whether rready asserted after valid
    output logic            ib_wen, // input buffer write enable
    output logic            wready, // output ready
    output logic            wmem_wready,
    output logic            sf_clr, // clear sf_cnt
    output logic [SF_T-1:0] sf_cnt // address for input buffer
);

logic inp_active; // input data is active
logic do_mvu_stream; // perform all compute
logic sf_full; // sf_cnt has gone full
logic ap_start; // start computation
logic halt_mvu_stream; // halt computation in case of missing input ready

generate
    // NF = 1 & input buffer will not be re-used
    if (NF==1) begin: ONE_FILTER_BANK
        logic wait_rready_dly;
        // wready generation
        always_ff @(posedge clock)
            if      (!resetn)           wready <= 1'b0;
            else if (halt_mvu_stream)   wready <= 1'b0;
            else                        wready <= 1'b1;	    
        // sf_cnt generation
        always_ff @(posedge clock)
            if      (!resetn)        sf_cnt <= 'd0;
            else if (sf_full)        sf_cnt <= 'd0;
            else if (do_mvu_stream)  sf_cnt <= sf_cnt + 1;
   
        // write to buffer & compute when input active
        assign ib_wen = inp_active;
        assign do_mvu_stream = inp_active;

        // If the wait_rready signal is asserted for two consecutive
        // clock cycles, need to halt computation
        always_ff @(posedge clock)
            if  (!resetn)   wait_rready_dly <= 1'b0;
            else            wait_rready_dly <= wait_rready;

        assign halt_mvu_stream = wait_rready & wait_rready_dly;
      
    end
    // NF > 1 & input buffer will be re-used
    else begin: N_FILTER_BANKS

        enum logic [1:0] {IDLE, WRITE, READ} pres_state, next_state;

        logic 		        nf_clr; // clear the nf_cnt
        logic 		        nf_zero; // indicate nf_cnt equals zero
        logic [NF_T-1:0]    nf_cnt; // NF counter
        logic               nf_full; // nf_cnt saturated

        assign nf_full = (nf_cnt == NF_T'(NF-1) & sf_full);//sf_cnt == SF_T'(SF-1));
        assign nf_zero = (nf_cnt=='d0);

        always_ff @(posedge clock)
            if (!resetn) pres_state <= IDLE;
            else         pres_state <= next_state;

        always_comb begin
            case(pres_state)
                IDLE: begin
                    casez({wait_rready, inp_active, nf_zero, sf_full})
                        4'b0000: next_state = READ;
                        4'b0001: next_state = IDLE;
                        4'b0010: next_state = IDLE;
                        4'b0011: next_state = READ;
                        4'b0100: next_state = WRITE;
                        4'b0101: next_state = WRITE;
                        4'b0110: next_state = WRITE;
                        4'b0111: next_state = READ;		   
                        4'b10??: next_state = IDLE;
                        4'b1100: next_state = WRITE;
                        4'b1101: next_state = IDLE;
                        4'b1110: next_state = WRITE;
                        4'b1111: next_state = IDLE;		   
                        default: next_state = IDLE;		   
                    endcase
                end
                WRITE: begin // accept input & weight
                    casez({halt_mvu_stream, inp_active, sf_full})
                        3'b000: next_state = IDLE;
                        3'b001: next_state = IDLE;
                        3'b010: next_state = WRITE;
                        3'b011: next_state = READ;
                        3'b1??: next_state = IDLE;		   
                    endcase	 
                end
                READ: begin // consume PEs output
                    casez({halt_mvu_stream, inp_active, nf_clr&sf_clr})
                        3'b000: next_state = READ;
                        3'b001: next_state = IDLE;
                        3'b010: next_state = WRITE;
                        3'b011: next_state = WRITE;
                        3'b1??: next_state = IDLE;		   
                    endcase // case ({inp_active, nf_clr&sf_clr})		 
                end
                default: next_state = IDLE;	      
            endcase
        end		

        // outputs of the state machine
        always_comb begin
            ib_wen = 1'b0;
            do_mvu_stream = 1'b0;	    
            case(pres_state)
                IDLE: begin
                    ib_wen = 1'b0;
                    do_mvu_stream = 1'b0;		 
                    case({inp_active})//,sf_full})
                        1'b0: begin
                            ib_wen = 1'b0;
                            do_mvu_stream = 1'b0;		      
                        end
                        1'b1: begin
                            ib_wen = 1'b1;
                            do_mvu_stream = 1'b1;
                        end
                    endcase // case ({inp_active})	
                end // case: IDLE	      
                WRITE: begin
                    ib_wen = 1'b0;
                    do_mvu_stream = 1'b0;		 
                    case({inp_active})//,sf_full})
                        1'b0: begin
                            ib_wen = 1'b0;
                            do_mvu_stream = 1'b0;		      
                        end
                        1'b1: begin
                            ib_wen = 1'b1;
                            do_mvu_stream = 1'b1;
                        end   
                    endcase // case ({inp_active})
                end // case: WRITE	      
                READ: begin
                    ib_wen = 1'b0;
                    do_mvu_stream = 1'b0;		 
                    case({inp_active})//, nf_clr&sf_clr})
                        1'b0: begin
                            do_mvu_stream = ~(nf_clr&sf_clr);//1'b1;
                        end
                        1'b1: begin
                            ib_wen = 1'b1;
                            do_mvu_stream = 1'b1;
                        end
                    endcase // case ({inp_active, nf_clr&sf_clr})
                end // case: READ	      
                default: begin
                    ib_wen = 1'b0;
                    do_mvu_stream = 1'b0;
                end	      
            endcase // case (pres_state)
        end // always_comb

        always_ff @(posedge clock)
            if (resetn)                     nf_clr <= 1'b0;
            else if (nf_cnt==NF_T'(NF-1))   nf_clr <= 1'b1;
            else                            nf_clr <= 1'b0;

        // Remains one when the input buffer is being filled
        // Resets to Zero the input buffer is filled and ready
        // to be reused
        always_ff @(posedge clock)
            if(!resetn)             wready <= 1'b0;
            else if (ap_start)      wready <= 1'b1;	  
            else if (nf_full)       wready <= 1'b1;	    
            else if (sf_full)       wready <= 1'b0;

        // A counter to keep track when we are done writing to the
        // input buffer so that it can be reused again
        // Similar to the variable nf in mvau.hpp
        // Only used when multiple output channels
        always_ff @(posedge clock)
            if (!resetn)                nf_cnt <= 'd0;//NF_T'(NF-1);
            else if (nf_clr & sf_clr)   nf_cnt <= 'd0;
            else if (sf_clr)            nf_cnt <= nf_cnt + 1;

        // which keeps track when the input buffer is full.
        // Only runs when do_mvau_stream is asserted
        // A counter similar to sf in mvau.hpp
        always_ff @(posedge clock)
            if(!resetn)             sf_cnt <= 'd0;//SF_T'(SF-1);
            else if (sf_full)       sf_cnt <= 'd0;
            else if (nf_full)       sf_cnt <= 'd0;      
            else if (do_mvu_stream) sf_cnt <= sf_cnt + 1;

        assign halt_mvu_stream = ((sf_cnt == SF_T'(SF-2)) & wait_rready);
    end // block: N_FILTER_BANKS
endgenerate

assign sf_full = ((sf_cnt == SF_T'(SF-1)) & do_mvu_stream);

// Always block for indicating when the system comes out of reset
always_ff @(posedge clock)
    if (!resetn)    ap_start <= 1'b1;
    else            ap_start <= 1'b0;
   
// A one bit control signal to indicate when sf_cnt == SF-1   
always_ff @(posedge clock)
    if (!resetn)        sf_clr <= 1'b0;
    else if(sf_full)    sf_clr <= 1'b1;
    else                sf_clr <= 1'b0;

assign inp_active = wready & in_v;

// Output ready for weight stream same as do_mvau_stream
assign wmem_wready = do_mvu_stream;

endmodule