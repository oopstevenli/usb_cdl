`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_rx_timer ();

    localparam CLK_PERIOD = 10ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    logic count_enable_timer;
    logic shift_strobe, eight_bit_done, seven_bit_done, four_bit_done, five_bit_done;
    logic enable4, enable5, enable7;
    string test_name;

    //DUT

    // clockgen
    always begin
        clk = 0;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        #(CLK_PERIOD / 2.0);
    end

    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        @(posedge clk);
        @(posedge clk);
    end
    endtask
    //DUT
    rx_timer #() DUT (.*);

    initial begin
        n_rst = 1;
        count_enable_timer = '0;
        enable4 = '0;
        enable5 = '0;
        enable7 = '0;
        test_name = "RESET";

        reset_dut;
        @(negedge clk);
        enable4 = 1;
        enable5 = 1;
        enable7 = 1;
        count_enable_timer = 1;
        test_name = "first 8";
        #(CLK_PERIOD * 8);
        @(negedge clk);
        test_name = "second 8";
        #(CLK_PERIOD * 8);
        @(negedge clk);
        test_name = "9";
        #(CLK_PERIOD * 9);
        @(negedge clk);
        test_name = "bit 4 checker";
        #(CLK_PERIOD * 75);


        $finish;
    end
endmodule

/* verilator coverage_on */

