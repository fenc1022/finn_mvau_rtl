/*
 * This file lists a test bench for the matrix-vector activation batch unit.
 * The input and weights are read from a file generated by HLS. The output from
 * DUT is matched against data generated from HLS. This
 * test bench is part of the regression test for MVAU batch unit.
 *
 * */

 `timescale 1ns/1ns

 `include "mvu_defn.sv" // compile the package file
 import mvu_defn::*; // import package into $unit compilation space

 module mvu_tb;

    // parameters for controlling the simulation and inserting some delays
    parameter int CLK_PER=20;
    parameter int INIT_DLY=(CLK_PER*2)+1;
    parameter int RAND_DLY=21;
    parameter int NO_IN_VEC = 100;
    parameter int TOTAL_OUTPUTS = MMV*MatrixH*ACT_MatrixW;

    logic 	 aclk;
    logic 	 aresetn;
    // result output interface
    logic [TO-1:0]  out;
    logic 	        out_v;
    logic 	        rready;
    // image input interface
    logic [0:SIMD-1][TSrcI-1:0] in;
    logic 		                in_v;
    logic 	                    wready;

    // Output signal from DUT where each element is divided into multiple elements
    logic [0:PE-1][TDstI-1:0] out_packed;

    // Input activation matrix
    logic [0:SIMD-1][TSrcI-1:0] in_mat [0:MMV-1][0:ACT_MatrixW-1][0:ACT_MatrixH/SIMD-1];

    // Output matrix holding output of behavioral simulation
    logic [TDstI-1:0] 	       mvau_beh [0:MMV-1][0:ACT_MatrixW-1][0:MatrixH-1];

    // An integer to count for successful output matching
    integer     test_count;

    // An integer to count the total number of cycles taken to get all outputs
    integer     latency;

    // A signal which indicates when simulation starts
    logic       sim_start;

    // A signal which indicates the comparison is done, helps in debugging
    logic       do_comp;

    // Events for synchronizing the simulation
    event   gen_inp;    // generate input activation matrix
    event   gen_weights;// generate weight matrix
    event   do_mvau_beh;// perform behavioral mvau

    initial begin
        $display($time, " << Starting Simulation >>");
        aclk = 0;
        aresetn = 0;
        sim_start = 0;
        test_count = 0;
        rready = 0;

        // Generating events to generate input vector and coefficients for test
        #1 -> gen_inp; // To populate the input data vector
        #1 -> gen_weights; // To generate coefficients
        #1 -> do_mvau_beh; // To perform behavioral matrix vector convolution

        #(INIT_DLY);

        aresetn = 1; // Coming out of reset
        sim_start = 1; // Simulation starts
        do_comp = 0;

        $display($time, " << Coming out of reset >>");
        $display($time, " << Starting simulation with System Verilog based data >>");

        // Checking DUT output with golden output generated in the test bench
        for(int m = 0; m < MMV; m++) begin
            for(int i = 0; i < ACT_MatrixW; i++) begin
                for(int j = 0; j < MatrixH/PE; j++) begin
                    do_comp = 1; // Indicating when actual comparison is done, helps in debugging
                    wait(out_v==1'b1);
                    @(posedge aclk) begin: DUT_BEH_MATCH
                        if(out_v) begin
                            out_packed = out;
                            for(int k = 0; k < PE; k++) begin
                                if(out_packed[k] == mvau_beh[m][i][j*PE+k]) begin
                                    $display($time, " PE%0d : 0x%0h == Model_%0d_%0d: 0x%0h",
                                        k,out_packed[k],i,j*PE+k,mvau_beh[m][i][j*PE+k]);
                                    test_count++;
                                end
                                else begin
                                    $display($time, " PE%0d : 0x%0h != Model_%0d_%0d: 0x%0h",
                                        k,out_packed[k],i,j*PE+k,mvau_beh[m][i][j*PE+k]);
                                    // assert (out_packed[PE-k-1] == mvau_beh[m][i][j*PE+k])
                                    // else $fatal(1,"Data MisMatch");
                                end
                            end // for (int k = 0; k < PE; k++)
                        end // if (out_v)
                    end // block: DUT_BEH_MATCH
                    do_comp = 0;
                    wait(out_v==1'b0);
                end // for (int j = 0; j < MatrixH/PE; j++)
            end // for (int i = 0; i < ACT_MatrixW; i++)
        end // for (int m = 0; m < MMV; m++)

        sim_start = 0;

        #RAND_DLY;
        if(test_count == TOTAL_OUTPUTS) begin
            integer f;
            $display($time, " << Simulation Complete. Total successul outputs: %d >>", test_count);
            $display($time, " << Latency: %d >>", latency/MMV);
            f = $fopen("latency.txt","w");
            $fwrite(f,"%d",latency);
            $fclose(f);
            $stop;
        end
        else begin
            $display($time, " << Simulation complete, failed >>");
            $stop;
        end
    end // initial begin

    always #(CLK_PER/2) aclk = ~aclk;

    // populating the input activation matrix from a memory file
    always @(gen_inp) $readmemh("inp.mem", in_mat);

    // populating the output activation matrix from a memory file
    always @(do_mvau_beh) $readmemh("out.mem",mvau_beh);

    // calculating the total run time of simulation in terms of clock cycles
    always_ff @(posedge aclk)
        if(!aresetn)                latency <= 'd0;
        else if(sim_start == 1'b1)  latency <= latency + 1'b1;

    always @(out_v) rready = 1'b1;

    int m_inp, i_inp, j_inp;

    // Three counters to control the generation of input
    always @(posedge aclk) begin
        if(!aresetn) begin
            m_inp <= 0;
            i_inp <= 0;
            j_inp <= 0;
        end
        else if(wready) begin
        if(m_inp == MMV-1 & i_inp == ACT_MatrixW-1 & j_inp == ACT_MatrixH/SIMD-1) begin
            m_inp <= MMV-1;
            i_inp <= ACT_MatrixW-1;
            j_inp <= ACT_MatrixH/SIMD-1;
        end
        else if(i_inp == ACT_MatrixW-1 & j_inp == ACT_MatrixH/SIMD-1) begin
            i_inp <= 0;
            j_inp <= 0;
            m_inp <= m_inp+1;
        end
        else if(j_inp == ACT_MatrixH/SIMD-1) begin
            j_inp <= 0;
            i_inp <= i_inp+1;
        end
        else
            j_inp <= j_inp +1;
        end
    end

    // Generating input for the DUT from the input tensor
    always @(aresetn, m_inp, i_inp, j_inp) begin
        for(int k = 0; k < SIMD; k++) begin
            in[k] = in_mat[m_inp][i_inp][j_inp][k];
        end
    end

    // Generating input valid for a variety of cases
    if (ACT_MatrixW==1) begin: COL_1
        if(ACT_MatrixH/SIMD==1) begin: ROW_1
            always_ff @(posedge aclk) begin
                if (!aresetn)   in_v <= 1'b0;
                else            in_v <= ~in_v;//1'b1;
            end
        end
        else begin: ROW_N
            always_ff @(posedge aclk) begin
                if (!aresetn)
                    in_v <= 1'b0;
                else if(m_inp == MMV-1 & j_inp == ACT_MatrixH/SIMD-1)
                    in_v <= 1'b0;
                else
                    in_v <= 1'b1;
            end
        end
    end // block: COL_1
    else begin: COL_N
        if(ACT_MatrixH/SIMD==1) begin: ROW_1
            always_ff @(posedge aclk) begin
                if(!aresetn)
                    in_v <= 1'b0;
                else if(m_inp == MMV-1 & i_inp == ACT_MatrixW-1)
                    in_v <= 1'b0;
                else
                    in_v <= 1'b1;
            end
        end
        else begin: ROW_N
            always_ff @(posedge aclk) begin
                if(!aresetn)
                    in_v <= 1'b0;
                else if(m_inp == MMV-1 & i_inp == ACT_MatrixW-1 & j_inp == ACT_MatrixH/SIMD-1)
                    in_v <= 1'b0;
                else
                    in_v <= 1'b1;
            end
        end
    end // block: COL_N

    // DUT Instantiation
    mvu_top #(
        .KDim   (KDim        ),
        .IFMCh  (IFMCh       ),
        .OFMCh  (OFMCh       ),
        .SIMD   (SIMD        ),
        .PE     (PE          ),
        .TSrcI  (TSrcI       ),
        .TW     (TW          ),
        .TDstI  (TDstI       ),
        .OP_SGN (OP_SGN      ))
    mvu_inst(
        .aresetn(aresetn),
        .aclk(aclk),
        .m0_axis_tready(rready),
        .s0_axis_tready(wready),
        .s0_axis_tvalid(in_v),
        .s0_axis_tdata(in),
        .m0_axis_tvalid(out_v),
        .m0_axis_tdata(out)
        );

endmodule // mvau_tb
