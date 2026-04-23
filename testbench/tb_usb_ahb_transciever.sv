`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_usb_ahb_transceiver ();

    localparam CLK_PERIOD = 10ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;

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


    // AHB bus signals
    logic hsel, hwrite, hready, hresp;
    logic [3:0] haddr;
    logic [1:0] htrans;
    logic [2:0] hsize;
    logic [31:0] hwdata, hrdata;

    localparam BYTE_SIZE = 3'b000;
    localparam HALFWORD_SIZE = 3'b001;
    localparam FULLWORD_SIZE = 3'b010;


    ahb_model_updated #( .ADDR_WIDTH(4), .DATA_WIDTH(4) ) BFM (
        .clk(clk), .hsel(hsel), .haddr(haddr), .hsize(hsize), 
        .htrans(htrans), .hwrite(hwrite), .hwdata(hwdata),
        .hrdata(hrdata), .hresp(hresp), .hready(hready)
    );

    // usb signals
    logic dp_in, dm_in, dp_out, dm_out, d_mode;

    // tb signals
    string testname;
    integer i;
    input logic [31:0] data_in;

    // clock generation
    localparam USB_BIT_PERIOD = 83.3ns; // 12MHz (approx 8 clock cycles)

    always begin
        clk = 0; #(CLK_PERIOD / 2.0);
        clk = 1; #(CLK_PERIOD / 2.0);
    end

    usb_ahb_transceiver #() DUT (.*);


    // tasks!!

    task ahb_write(input logic [3:0] addr, input logic [31:0] data);
        logic [31:0] data_arr []; // dynamic array to talk to BFM
        begin
            data_arr = new [1]; // dynamic sizing
            data_arr[0] = data; // put our data in the first (and only) box
            //              Fields: hsel,  R/W, addr, data, exp err,         size, burst, chk prdata or not
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data_arr, 1'b0, 3'b010, BYTE_SIZE, 1'b0);
            BFM.run_transactions(1);
            BFM.wait_done();
        end
    endtask

    task ahb_read(input logic [3:0] addr, input logic [31:0] expected);
        logic [31:0] data_arr [];
        begin
            data_arr = new [1]; // same same
            data_arr[0] = expected;
            //              Fields: hsel,  R/W, addr, data,     exp err,  size,   burst,  chk prdata or not
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data_arr, 1'b0,     3'b010, 3'b0,   1'b1);
            BFM.run_transactions(1);
            BFM.wait_done();
        end
    endtask

    // task send_usb_packet(input logic [7:0] data_bytes []);
    //     begin
    //         // im just sending in data here idk if thats how its supposed to go
    //         foreach (data_bytes[i]) begin
    //             for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
    //                 dp_in = data_bytes[i][bit_idx];
    //                 dm_in = ~data_bytes[i][bit_idx];
    //                 #(USB_BIT_PERIOD);
    //             end
    //         end
    //         // end of packet
    //         dp_in = 0; dm_in = 0; #(USB_BIT_PERIOD * 2);
    //         dp_in = 1; dm_in = 1;
    //     end
    // endtask

    task send_usb_packet(input logic [7:0] data_bytes []);
        begin
            logic prev_dp_in, prev_dm_in;
            // dp_in=1;
            // dm_in=0;
            prev_dp_in=1;
            prev_dm_in=0;
    
            // encoder
            foreach (data_bytes[i]) begin
                for(int bit_idx=0; bit_idx<8; bit_idx++) begin
                    if(data_bytes[i][bit_idx]==0) begin
                        prev_dp_in = dp_in;
                        prev_dm_in = dm_in;
                        // @(posedge clk);
                        dp_in = ~dp_in;
                        dm_in = ~dm_in;
                        #(USB_BIT_PERIOD);
                    end
                    else begin
                        prev_dp_in = dp_in;
                        prev_dm_in = dm_in;
                        dp_in = prev_dp_in;
                        dm_in = prev_dm_in;
                        // @(posedge clk);
                        #(USB_BIT_PERIOD);
                    end
                end
            end
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
            #USB_BIT_PERIOD;

        end
    endtask;

    task send_byte;
        begin
            input [7:0] data;
            input [4:0] n;

            integer i;
        end
        begin
            for (i = 0; i < n; i++) begin
                send_bit(data[i]);
                //#(USB_BIT_PERIOD);
            end
        end
    endtask

    task send_in_token();
        begin
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
        end
    endtask

    task send_data0(input logic [3:0] num_bytes, input logic [31:0] data_in);
        begin
            buffer_occupancy = '0;
            @(negedge clk);
            // SYNC BYTE
            send_byte(8'b0010_1010, 4'd8);
            @(negedge clk);
            // PID BYTE      
            send_byte(8'b0001_0100, 4'd8);
            #CLK_PERIOD;
            @(negedge clk);
            //n byte data---------------------------------
            integer i;
            for(i = 0; i < num_bytes; i++) begin
                send_byte(data_in[(i * 8) - 1 : i], 4'd8);
                @(negedge clk);
            end
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
        end
    endtask

    task send_data1(input logic [3:0] num_bytes, input logic [31:0] data_in);
        begin
            buffer_occupancy = '0;
            @(negedge clk);
            // SYNC BYTE
            send_byte(8'b0010_1010, 4'd8);
            @(negedge clk);
            // PID BYTE      
            send_byte(8'b0110_1100, 4'd8);
            #CLK_PERIOD;
            @(negedge clk);
            //n byte data---------------------------------
            integer i;
            for(i = 0; i < num_bytes; i++) begin
                send_byte(data_in[(i * 8) - 1 : i], 4'd8);
                @(negedge clk);
            end
            //CRC16 bits---------------------------------
            // "CRC16";
            send_byte(8'b1010_1110, 4'd8);
            @(negedge clk);
            // "CRC16-2";
            send_byte(8'b0010_1010, 4'd8);
            @(negedge clk);
            // "EOP";
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
        end
    endtask

    task send_out_token;
        begin
            //test_name = "SYNC BYTE";
            send_byte(8'b0010_1010, 4'd8);
            //#CLK_PERIOD;
            @(negedge clk);
            //test_name = "PID BYTE";
            send_byte(8'b0000_1010, 4'd8);
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
        end
    endtask

    task send_ack_token;
        begin
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
        end
    endtask


    task check_multi_byte_usb(input logic [7:0] expected_payload [], output_logic decoded []);
        logic [7:0] captured_byte;
        begin
            // wait for d_mode and skip sync + PID (16 bits total)
            wait(d_mode == 1);
            #(USB_BIT_PERIOD * 16.5); // align to the middle of the first payload bit

            // loop through every byte
            foreach (expected_payload[j]) begin
                for (int i = 0; i < 8; i++) begin
                    captured_byte[i] = dp_out;
                    #(USB_BIT_PERIOD);
                end

                // verify this specific byte
                if (captured_byte === expected_payload[j]) begin
                    $display("SUCCESS: Captured Byte %0d: 0x%h", j, captured_byte);
                end else begin
                    $error("ERROR: Byte %0d Mismatch! Expected 0x%h, Got 0x%h", j, expected_payload[j], captured_byte);
                end
            end
            
            // skip the CRC16 (16 bits) and verify the EOP
            #(USB_BIT_PERIOD * 16);
            if (dp_out == 0 && dm_out == 0) 
                $display("SUCCESS: EOP detected at the end of the stream.");
        end
    endtask

    task decode_nrzi; //FOR JOEEEEEEEEE!!!!!
        begin
            input [7:0] expected_decoded;
            output logic match;

            integer i;
            static integer prev_dp = 1;
            logic [7:0] decoded;
            logic [7:0] encoded_dp_output;
        end
        begin
            // sample
            for (int i = 0; i < 8; i++) begin
                    encoded_dp_output[i] = dp_out;
                    #(USB_BIT_PERIOD);
            end

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
                match = 1;
            end else begin
                $display("Decoded doesn't match!");
                match = 0;
            end
        end
    endtask

    logic decode_success = 0;

    initial begin
        n_rst = 1;

        reset_dut;
        dp_in=1;
        dm_in=0;

        // TEST 1 - write a byte and watch it come out
        testname = "end_to_host_verified";
        ahb_write(4'hD, 32'h1); // clear
        testname= "wowie zowie ";
        data_in = 32'h53;
        ahb_write(4'h0, data_in); // write data

        send_out_token(); // send out
        send_data0(); // send data0
        send_in_token(); // send in

        decode_nrzi(data_in, decode_success);

        $display("Test case %s completed verification.", testname);

        // TEST 2 - write multiple bytes and watch them all come out
        testname = "top_multi_byte_burst";

        // fill the FIFO via AHB with 3 bytes -- might change this to send 3 bytes in with 1 write
        ahb_write(4'h0, 8'h41); // 'A'
        ahb_write(4'h0, 8'h42); // 'B'
        ahb_write(4'h0, 8'h43); // 'C'

        send_out_token(); // send out
        send_data0(); // send data0
        send_in_token(); // send in

        decode_nrzi(8'h41, decode_success);
        decode_nrzi(8'h42, decode_success);
        decode_nrzi(8'h43, decode_success);

        $display("Test case %s completed verification.", testname);

        $finish;
    end
endmodule

/* verilator coverage_on */
