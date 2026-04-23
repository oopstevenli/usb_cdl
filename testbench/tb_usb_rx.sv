`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_usb_rx ();

    localparam CLK_PERIOD = 10ns;
    localparam DATA_PERIOD = 83.3ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    logic dp_in, dm_in;
    logic [6:0] buffer_occupancy;
    logic [2:0] rx_packet;
    logic rx_data_ready, rx_transfer_active, rx_error, store_rx_packet_data;
    logic [7:0] rx_packet_data;
    logic flush;
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

    task wait_bit;
    begin
        @(negedge DUT.shift_strobe);
    end
    endtask

    task simplify_bit;
    input bit_val;
    begin
        if (bit_val) begin
            dp_in = 1;
            dm_in = 0;

        end else begin
            dp_in = 0;
            dm_in = 1;
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

    task decode_nrzi; //FOR JOEEEEEEEEE!!!!!
    input [7:0] encoded_dp_output;
    input [7:0] expected_decoded;

    integer i;
    static integer prev_dp = 1;
    logic [7:0] decoded;
    begin
        for (i = 0; i < 8; i++) begin
            if (encoded_dp_output[i] != prev_dp) begin
                prev_dp = encoded_dp_output[i];
                decoded[i] = 0;
            end else begin
                prev_dp = encoded_dp_output[i];
                decoded[i] = 1;
            end
        end

        if (expected_decoded == decoded) begin
            $display("Decoded matches!");
        end else begin
            $display("Decoded doesn't match!");
        end
    end
    endtask

    usb_rx #() DUT (.*);

    initial begin
        n_rst = 1;
        dp_in = 1;
        dm_in = 0;
        buffer_occupancy = '0;
        test_name = "RESET";

        reset_dut;
        @(negedge clk);
        @(negedge clk);
        test_name = "TOKEN OUT";
        //test_name = "SYNC BYTE";
        send_byte(8'b0010_1010, 4'd8);
        //#CLK_PERIOD;
        @(negedge clk);
        //test_name = "PID BYTE";
        send_byte(8'b0000_1010, 4'd8);
        #CLK_PERIOD;
        @(negedge clk);
        //test_name = "ADDR BYTE";
        send_byte(7'b010_1010, 4'd7);
        @(negedge clk);
        //test_name = "ENDP";
        send_byte(4'b1010, 4'd4);
        @(negedge clk);
        //test_name = "CRC5";
        send_byte(5'b01110, 4'd5);
        @(negedge clk);
        //test_name = "EOP";
        dp_in = 0;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        #(DATA_PERIOD);
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        test_name = "DATA0";
        //test_name = "SYNC BYTE";
        send_byte(8'b0010_1010, 4'd8);
        @(negedge clk);
        //test_name = "PID BYTE";
        
        send_byte(8'b0001_0100, 4'd8);
        #CLK_PERIOD;
        @(negedge clk);
        //4 byte data---------------------------------
        send_byte(8'b1010_1010, 4'd8);
        @(negedge clk);
        send_byte(8'b0101_0101, 4'd8);
        @(negedge clk);

        send_byte(8'b1010_1010, 4'd8);
        @(negedge clk);
        send_byte(8'b0101_0101, 4'd8);
        @(negedge clk);
        //CRC16 bits---------------------------------
        //test_name = "CRC16";
        send_byte(8'b1010_1110, 4'd8);
        @(negedge clk);
        //test_name = "CRC16-2";
        send_byte(8'b0010_1010, 4'd8);
        @(negedge clk);
        //test_name = "EOP";
        dp_in = 0;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        #(DATA_PERIOD);
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        #CLK_PERIOD;

        @(negedge clk);
        buffer_occupancy = 7'd64;
        @(negedge clk);
        test_name = "FILLED BUFFER";
        //test_name = "SYNC BYTE";
        send_byte(8'b0010_1010, 4'd8);
        @(negedge clk);
        //test_name = "PID BYTE";
        
        send_byte(8'b0001_0100, 4'd8);
        #CLK_PERIOD;
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);

        test_name = "0 byte DATA0";
        buffer_occupancy = '0;
        @(negedge clk);
        //test_name = "SYNC BYTE";
        send_byte(8'b0010_1010, 4'd8);
        @(negedge clk);
        //test_name = "PID BYTE";
        
        send_byte(8'b0001_0100, 4'd8);
        #CLK_PERIOD;
        @(negedge clk);
        //4 byte data---------------------------------
        //CRC16 bits---------------------------------
        //test_name = "CRC16";
        send_byte(8'b1010_1110, 4'd8);
        @(negedge clk);
        //test_name = "CRC16-2";
        send_byte(8'b0010_1010, 4'd8);
        @(negedge clk);
        //test_name = "EOP";
        dp_in = 0;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        #(DATA_PERIOD);
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        #CLK_PERIOD;
        @(negedge clk);
        test_name = "BIT UNSTUFF";
        //test_name = "SYNC BYTE";
        send_byte(8'b0010_1010, 4'd8);
        @(negedge clk);
        //test_name = "PID BYTE";
        
        send_byte(8'b0001_0100, 4'd8);
        #CLK_PERIOD;
        @(negedge clk);
        //test_name = "BIT STUFFED";
        //byte data---------------------------------
        send_byte(8'b1100_0000, 4'd8);
        @(negedge clk);
        send_byte(81'b1, 4'd1);
        @(negedge clk);
        //CRC16 bits---------------------------------
        test_name = "CRC16";
        send_byte(8'b0101_0001, 4'd8);
        @(negedge clk);
        test_name = "CRC16-2";
        send_byte(8'b1101_0101, 4'd8);
        @(negedge clk);
        //test_name = "EOP";
        dp_in = 0;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        #(DATA_PERIOD);
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        #CLK_PERIOD;
        //=============================================
        @(negedge clk);
        @(negedge clk);
        test_name = "IN TOKEN";
        //test_name = "SYNC BYTE";
        send_byte(8'b0010_1010, 4'd8);
        //#CLK_PERIOD;
        @(negedge clk);
        //test_name = "PID BYTE";
        send_byte(8'b0111_0010, 4'd8);
        #CLK_PERIOD;
        @(negedge clk);
        test_name = "ADDR BYTE";
        send_byte(7'b010_1010, 4'd7);
        @(negedge clk);
        //test_name = "ENDP";
        send_byte(4'b1010, 4'd4);
        @(negedge clk);
        //test_name = "CRC5";
        send_byte(5'b01110, 4'd5);
        @(negedge clk);
        //test_name = "EOP";
        dp_in = 0;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        #(DATA_PERIOD);
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(DATA_PERIOD);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);


        $finish;
        
        



    end
endmodule

/* verilator coverage_on */

