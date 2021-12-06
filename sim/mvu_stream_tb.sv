`timescale 1ns/1ns
`include "mvu_defn.sv"

module mvu_stream_tb;

parameter int CLK_PER = 10;
parameter int INIT_DLY = (CLK_PER*2)+1; // initial delay
parameter int RAND_DLY = 21; // random delay when needed
parameter int NO_IN_VEC = 100; // number of input vectors

// derived parameters
parameter int OFMDim=(IFMDim-KDim+2*PAD)/STRIDE+1; // Output feature map dimensions
parameter int MatrixW=KDim*KDim*IFMCh;   // Width of the WEIGHT matrix
parameter int MatrixH=OFMCh; // Heigth of the WEIGHT matrix
parameter int ACT_MatrixW = OFMDim*OFMDim; // input activation matrix height
parameter int ACT_MatrixH = (KDim*KDim*IFMCh); // input activation matrix weight
parameter int TOTAL_OUPUTS = OFMCh*ACT_MatrixW; // total number of outpput to be matched
parameter int TO=PE*TDstI; // PE times the word length of output stream
parameter int TI=SIMD*TSrcI; // SIMD times the word length of input stream

logic       clock;
logic       resetn;
logic       rready; // successor logic is ready
logic       wmem_wready; // weight memory ready
logic [0:SIMD-1][TW-1:0]      weights [0:MatrixH-1][0:MatrixW/SIMD-1];
logic [TSrcI-1:0]   in_mat [0:MMV-1][0:ACT_MatrixH-1][0:ACT_MatrixW-1];
// output interface
logic [TO-1:0]  out;
logic           out_v;
logic           wready;
logic [0:PE-1][TDstI-1:0]   out_packed;
// input interface
logic                       in_v;
logic [0:SIMD-1][TSrcI-1:0] in_act;
// weight interface
logic [0:PE*SIMD*TW-1]      in_wgt_packed;
logic [0:SIMD-1][TW-1:0]    in_wgt_um[0:PE-1];
logic                       in_wgt_v;

logic [TDstI-1:0]    mvu_beh [0:MMV-1][0:MatrixH-1][0:ACT_MatrixW-1];
integer test_count;
// logic   do_comp;
integer latency;
logic   sim_start;
// event for synchronzing the simulation
event   gen_inp; // generate input activation matrix
event   gen_weights; // generate weight matrix
event   do_mvu_beh; // start testing

initial begin
    $display($time, " << Starting Simulation >>");
    $display("Paramter settings:");
    $display("IFMDim:%2d    IFMCh:%2d    OFMCh:%2d", IFMDim, IFMCh, OFMCh);
    $display("KDim:%2d      PAD:%2d      STRIDE:%2d", KDim, PAD, STRIDE);
    $display("SIMD:%2d      PE:%2d       MMV:%2d", SIMD, PE, MMV);
    $display("TSrcI:%2d     TW:%2d       TDstI:%2d       OP_SGN:2'b%2b", TSrcI, TW, TDstI, OP_SGN);
    $display("Paramters derived:");
    $display("MatrixW:%2d   MatrixH:%2d  ACT_MatrixW:%2d ACT_MatrixH:%2d", MatrixW, MatrixH, ACT_MatrixW, ACT_MatrixH);
    $display("TI:%2d        TO:%2d", TI, TO);

    clock       = 0;
    resetn      = 0;
    sim_start   = 0;
    test_count  = 0;

    #1 -> gen_inp;
    #1 -> gen_weights;
    #1 -> do_mvu_beh;

    #(INIT_DLY);
    resetn      = 1;
    sim_start   = 1;

    // do_comp = 0;
    $display($time, " << Coming out of reset >>");
    $display($time, " << Starting simulation with System Verilog based data >>");

    // checking DUT output
    for (int m = 0; m < MMV; m++) begin
        for (int i = 0; i < ACT_MatrixW; i++) begin
            for (int j = 0; j < MatrixH/PE; j++) begin
                // #(CLK_PER*MatrixW/SIMD);
                // do_comp = 1;
                // #1;
                wait(out_v == 1'b1);
                @(posedge clock) begin
                    if (out_v) begin
                        out_packed = out;
                        for (int k = 0; k < PE; k++) begin
                            if (out_packed[k] == mvu_beh[m][j*PE+k][i]) begin
                                $display($time, "<< PE%0d : 0x%0h >> == << Model_%0d_%0d: 0x%0h",
                                    k, out_packed[k], j*PE+k, i, mvu_beh[m][j*PE+k][i]);
                                test_count++;
                            end
                            else begin
                                $display($time, "<< PE%0d : 0x%0h >> != << Model_%0d_%0d: 0x%0h",
                                    k, out_packed[k], j*PE+k, i, mvu_beh[m][j*PE+k][i]);
                                // assert (out_packed[k] == mvu_beh[m][j*PE+k][i]) 
                                // else   $fatal(1, "Data Mismatch");
                            end
                        end
                    end
                end
                // do_comp = 0;
                // wait(out_v == 1'b0); // || rready == 1'b1);
                #(CLK_PER/2);
            end
        end
    end

    sim_start = 0;

    #RAND_DLY;
    if (test_count == TOTAL_OUPUTS) begin
        integer f;
        $display($time, " << Simulation Complete. Total successul outputs: %d >>", test_count);
        $display($time, " << Latency: %d clock cycles >>", latency/MMV);
        f = $fopen("latency.txt","w");
        $fwrite(f,"%d",latency);
        $fclose(f);	   
        $stop;
    end
    else begin
        $display($time, " << Simulation complete, failed >>");
        $stop;
    end
end

always #(CLK_PER/2) clock = ~clock;

// generate weight matrix
always @(gen_weights)
    for (int row = 0; row < MatrixH; row++)
        for (int col = 0; col < MatrixW/SIMD; col++)
            for (int wgt = 0; wgt < SIMD; wgt++)
                weights[row][col][wgt] = TW'($random);

// generate input matrix
always @(gen_inp)
    for (int m = 0; m < MMV; m++)
        for (int row = 0; row < ACT_MatrixH; row++)
            for (int col = 0; col < ACT_MatrixW; col++)
                in_mat[m][row][col] = TSrcI'($random);

// perform behavioral mvu
if (TSrcI == 1)
    if (TW == 1) begin // 1-bit inputs & 1-bit weights
        always @(do_mvu_beh)
            for (int m = 0; m < MMV; m++)
                for (int i = 0; i < MatrixH; i++)
                    for (int j = 0; j < ACT_MatrixW; j++) begin
                        mvu_beh[m][i][j] = '0;
                        for (int k = 0; k < ACT_MatrixH/SIMD; k++)
                            for (int l = 0; l < SIMD; l++)
                                case (OP_SGN)
                                    2'b00: mvu_beh[m][i][j] +=
                                    in_mat[m][k*SIMD+l][j] & weights[i][k][l];
                                    2'b11: mvu_beh[m][i][j] +=
                                        in_mat[m][k*SIMD+l][j] ^~ weights[i][k][l];
                                    default:   // illegal operation
                                        $fatal(1, "Illegal TSrcI/TDstI/OP_SGN combination!");
                                endcase
                    end
    end
    else begin   // 1-bit inputs & multi-bit weights
        always @(do_mvu_beh)
            for (int m = 0; m < MMV; m++)
                for (int i = 0; i < MatrixH; i++)
                    for (int j = 0; j < ACT_MatrixW; j++) begin
                        mvu_beh[m][i][j] = '0;
                        for (int k = 0; k < ACT_MatrixH/SIMD; k++)
                            for (int l = 0; l < SIMD; l++)
                                case (OP_SGN)
                                    2'b00: mvu_beh[m][i][j] +=
                                        in_mat[m][k*SIMD+l][j] == '0 ? '0 : weights[i][k][l];
                                    2'b11: mvu_beh[m][i][j] +=
                                        in_mat[m][k*SIMD+l][j] == '0 ?
                                        ~weights[i][k][l] + 1'b1 : weights[i][k][l];
                                    default:   // illegal operation
                                        $fatal(1, "Illegal TSrcI/TDstI/OP_SGN combination!");
                                endcase
                    end
    end
else
    if (TW == 1) begin // multi-bit inputs & 1-bit weights
        always @(do_mvu_beh)
            for (int m = 0; m < MMV; m++)
                for (int i = 0; i < MatrixH; i++)
                    for (int j = 0; j < ACT_MatrixW; j++) begin
                        mvu_beh[m][i][j] = '0;
                        for (int k = 0; k < ACT_MatrixH/SIMD; k++)
                            for (int l = 0; l < SIMD; l++)
                                case (OP_SGN)
                                    2'b00: mvu_beh[m][i][j] +=
                                        weights[m][k*SIMD+l][j] == '0 ?
                                        '0 : in_mat[i][k][l];
                                    2'b11: mvu_beh[m][i][j] +=
                                        weights[m][k*SIMD+l][j] == '0 ?
                                        ~in_mat[i][k][l] + 1'b1 : in_mat[i][k][l];
                                    default:  // illegal operation
                                        $fatal(1, "Illegal TSrcI/TDstI/OP_SGN combinition!");
                                endcase
                    end
    end
    else begin   // multi-bit inputs & multi-bit weights
        always @(do_mvu_beh)
            for (int m = 0; m < MMV; m++)
                for (int i = 0; i < MatrixH; i++)
                    for (int j = 0; j < ACT_MatrixW; j++) begin
                        mvu_beh[m][i][j] = '0;
                        for (int k = 0; k < ACT_MatrixH/SIMD; k++)
                            for (int l = 0; l < SIMD; l++)
                                case (OP_SGN)
                                    2'b00: mvu_beh[m][i][j] += 
                                            in_mat[m][k*SIMD+l][j] * weights[i][k][l];
                                    2'b01: mvu_beh[m][i][j] = $signed(mvu_beh[m][i][j]) +
                                            $signed({1'b0, in_mat[m][k*SIMD+l][j]}) * 
                                            $signed(weights[i][k][l]);
                                    2'b10: mvu_beh[m][i][j] = $signed(mvu_beh[m][i][j]) +
                                            $signed(in_mat[m][k*SIMD+l][j]) * 
                                            $signed({1'b0, weights[i][k][l]});
                                    2'b11: mvu_beh[m][i][j] = $signed(mvu_beh[m][i][j]) +
                                            $signed(in_mat[m][k*SIMD+l][j]) * 
                                            $signed(weights[i][k][l]);
                                endcase
                    end
    end

// latency calculation
always_ff @(posedge clock)
    if (!resetn)                    latency <= '0;
    else if (sim_start == 1'b1)     latency <= latency + 1;

// assume next logic is always ready
assign  rready = out_v;

// DUT input generation
int m_inp, i_inp, j_inp;

always_ff @(posedge clock) begin // index generation
    if (!resetn) begin
        m_inp <= 0;
        i_inp <= 0;
        j_inp <= 0;
    end
    else if (wready) begin
        if (m_inp==MMV-1 & i_inp==ACT_MatrixW-1 & j_inp==ACT_MatrixH/SIMD-1) begin
            m_inp <= MMV - 1;
            i_inp <= ACT_MatrixW - 1;
            j_inp <= ACT_MatrixH/SIMD - 1;
        end
        else if (i_inp==ACT_MatrixW-1 & j_inp==ACT_MatrixH/SIMD-1) begin
            m_inp <= m_inp + 1;
            i_inp <= 0;
            j_inp <= 0;
        end
        else if (j_inp==ACT_MatrixH/SIMD-1) begin
            i_inp <= i_inp + 1;
            j_inp <= 0;
        end
        else
            j_inp <= j_inp + 1;
    end
end

generate  // input data generation
    for (genvar k = 0; k < SIMD; k++)
        assign in_act[k] = in_mat[m_inp][j_inp*SIMD+k][i_inp];
endgenerate

if (ACT_MatrixW == 1) // single colum
    if (ACT_MatrixH/SIMD == 1) // signle row
        always_ff @(posedge clock)
            if (!resetn)    in_v <= 1'b0;
            else            in_v <= ~in_v;
    else // multiple row
        always_ff @(posedge clock)
            if (!resetn)
                in_v <= 1'b0;
            else if (m_inp==MMV-1 & j_inp==ACT_MatrixH/SIMD-1)
                in_v <= 1'b0;
            else
                in_v <= 1'b1;
else  // multi-colum
    if (ACT_MatrixH/SIMD == 1)  // single row
        always_ff @(posedge clock)
            if (!resetn)
                in_v <= 1'b0;
            else if (m_inp==MMV-1 & i_inp==ACT_MatrixW-1)
                in_v <= 1'b0;
            else
                in_v <= 1'b1;
    else  // multi-row
        always_ff @(posedge clock)
            if (!resetn)
                in_v <= 1'b0;
            else if (m_inp==MMV-1 & i_inp==ACT_MatrixW-1 & j_inp==ACT_MatrixH/SIMD-1)
                in_v <= 1'b0;
            else
                in_v <= 1'b1;

// DUT weights generation
int x_wgt, r_wgt, s_wgt;

always_ff @(posedge clock) // index generation
    if (!resetn) begin
        x_wgt <= 0;
        r_wgt <= 0;
        s_wgt <= 0;
    end
    else if (wmem_wready) begin
        if (x_wgt==ACT_MatrixW-1 & r_wgt==MatrixH/PE-1 & s_wgt==MatrixW/SIMD-1) begin
            x_wgt <= ACT_MatrixW - 1;
            r_wgt <= MatrixH/PE - 1;
            s_wgt <= MatrixW/SIMD - 1;
        end
        else if (r_wgt==MatrixH/PE-1 & s_wgt==MatrixW/SIMD-1) begin
            x_wgt <= x_wgt + 1;
            r_wgt <= 0;
            s_wgt <= 0;
        end
        else if (s_wgt==MatrixW/SIMD-1) begin
            r_wgt <= r_wgt + 1;
            s_wgt <= 0;
        end
        else
            s_wgt <= s_wgt + 1;
    end

generate
    for (genvar k = PE-1; k >= 0; k--)
        assign in_wgt_um[k] = weights[r_wgt*PE+k][s_wgt];
endgenerate

generate // weight data generation
    for (genvar p=0; p<PE; p++)
        assign in_wgt_packed[SIMD*TW*p:SIMD*TW*p+(SIMD*TW-1)] = in_wgt_um[p];
endgenerate

always_ff @(posedge clock)
    if (!resetn)
        in_wgt_v <= 1'b0;
    else if (x_wgt==ACT_MatrixW-1 & r_wgt==MatrixH/PE-1 & s_wgt==MatrixW/SIMD-1)
        in_wgt_v <= 1'b0;
    else
        in_wgt_v <= 1'b1;

// DUT instantiation
mvu_stream_top #(
    .KDim       (KDim   ),
    .IFMCh      (IFMCh  ),
    .OFMCh      (OFMCh  ),
    .SIMD       (SIMD   ),
    .PE         (PE     ),
    .TSrcI      (TSrcI  ),
    .TW         (TW     ),
    .TDstI      (TDstI  ),
    .OP_SGN     (OP_SGN )
) mvu_stream_top (
    .aresetn    (resetn ),
    .aclk       (clock ),
    .m0_axis_tdata  (out    ),
    .m0_axis_tvalid (out_v  ),
    .m0_axis_tready (rready ),
    .s0_axis_tdata  (in_act ),
    .s0_axis_tvalid (in_v   ),
    .s0_axis_tready (wready ),
    .s1_axis_tdata  (in_wgt_packed),
    .s1_axis_tvalid (in_wgt_v),
    .s1_axis_tready (wmem_wready)
);

endmodule