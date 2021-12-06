/*
 * Test bench of mvu_pe_adders module
 *
 **/
`define CLK_PERIOD 10

module tb_mvu_pe_adders;
parameter int SIMD = 11;
parameter int TDst_I = 6;

logic               clk;
logic               rst_n;
logic [TDst_I-1:0]  in_simd [0:SIMD-1];
logic [TDst_I-1:0]  result;
logic [TDst_I-1:0]  sum;
logic               test_pass;

mvu_pe_adders #(SIMD, TDst_I) adder(
    .clock  (clk),
    .resetn (rst_n),
    .in_simd(in_simd),
    .out_add(result)
);

initial begin
    clk = '0;
    forever # (`CLK_PERIOD / 2) clk = ~clk;
end

initial begin
    rst_n = '1;
    test_pass = '1;
    # (`CLK_PERIOD*2) rst_n = '0;
    # (`CLK_PERIOD*2) rst_n = '1;
    repeat(10000) begin
        @(posedge clk) begin
            #1;
            if (sum != result) begin
                $display("mismatch at %t!", $time);
                test_pass = '0;
            end
            sum = '0;
            for (int i=0; i<SIMD; i++) begin
                in_simd[i] = $random;
                sum += in_simd[i];
            end
        end
                // $display("input %x", in_simd[i]);
    end
    if (test_pass) $display("Adder Tree test pass!");
    else $display("Adder Tree test failed!");
    $finish;
end

endmodule