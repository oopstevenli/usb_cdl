`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_nrzi_decoder ();

    localparam CLK_PERIOD = 10ns;
    localparam DATA_PERIOD = 83.3ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    logic dp, dm;
    logic shift_strobe;
    logic d_orig, edge_detected, eop_detected;
    string test_name;

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

    task simplify_bit;
    input bit_val;
    begin
        if (bit_val) begin
            dp = 1;
            dm = 0;

        end else begin
            dp = 0;
            dm = 1;
        end
    end
    endtask

    task send_bit;
    input bit_val;
    begin
        simplify_bit(bit_val);
        //@(negedge DUT.shift_strobe);
        #DATA_PERIOD;

    end
    endtask;

    task send_byte;
    input [7:0] data;
    input [4:0] n;

    integer i;
    begin
        for (i = 0; i < n; i++) begin
            send_bit(data[i]);
            //#(DATA_PERIOD);
        end
    end
    endtask

    nrzi_decoder #() DUT (.*);

    initial begin
        n_rst = 1;
        dp = 1;
        dm = 0;
        shift_strobe = 0;
        test_name = "RESET";

        reset_dut;
        @(negedge clk);
        test_name = "IDLE";
        @(negedge clk);
        @(negedge clk);
        test_name = "SYNC BYTE";
        send_byte(8'b0101_0101, 4'd8);
        dp = 0;
        dm = 1;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 0;
        dm = 1;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 0;
        dm = 1;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 0;
        dm = 1;
        @(negedge clk);
        if (d_orig == 0) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        @(negedge clk);
        if (d_orig == 1) begin
            $display("Correct!");
        end else begin
            $display("Incorrect!");
        end
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        test_name = "PID BYTE";
        dp = 0;
        dm = 1;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 0;
        dm = 1;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 0;
        dm = 1;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 0;
        dm = 1;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        test_name = "EOP";
        dp = 0;
        dm = 0;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        dp = 1;
        dm = 0;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;
        @(negedge clk);
        shift_strobe = 0;
        #DATA_PERIOD;
        @(negedge clk);
        shift_strobe = 1;





        $finish;
    end
endmodule

/* verilator coverage_on */

