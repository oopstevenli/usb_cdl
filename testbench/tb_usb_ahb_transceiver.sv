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
    logic [31:0] data_in;

    // clock generation
    localparam USB_BIT_PERIOD = 83.3ns; // 12MHz (approx 8 clock cycles)

    always begin
        clk = 0; #(CLK_PERIOD / 2.0);
        clk = 1; #(CLK_PERIOD / 2.0);
    end

    usb_ahb_transceiver #() DUT (.*);


    // tasks!!

    task ahb_write(input logic [3:0] addr, input logic [31:0] data, input logic [2:0] size);
        logic [31:0] data_arr []; // dynamic array to talk to BFM
        begin
            data_arr = new [1]; // dynamic sizing
            data_arr[0] = data; // put our data in the first (and only) box
            //              Fields: hsel,  R/W, addr, data, exp err,         size, burst, chk prdata or not
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data_arr, 1'b0, size, BYTE_SIZE, 1'b0);
            BFM.run_transactions(1);
            BFM.wait_done();
        end
    endtask

    task ahb_read(input logic [3:0] addr, input logic [31:0] expected, input logic [2:0] size);
        logic [31:0] data_arr [];
        begin
            data_arr = new [1]; // same same
            data_arr[0] = expected;
            //              Fields: hsel,  R/W, addr, data,     exp err,  size,   burst,  chk prdata or not
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data_arr, 1'b0,     size, 3'b0,   1'b1);
            BFM.run_transactions(1);
            BFM.wait_done();
        end
    endtask


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
        input [7:0] data;
        input [4:0] n;

        integer i;
        begin
            for (i = 0; i < n; i++) begin
                send_bit(data[i]);
                //#(USB_BIT_PERIOD);
            end
        end
    endtask

    task send_in_token();
        begin
            @(negedge clk);
            
            //test_name = "SYNC BYTE";
            send_byte(8'b0010_1010, 4'd8);
            #(CLK_PERIOD * 5);
            //#CLK_PERIOD;
            @(negedge clk);
            //test_name = "PID BYTE";
            send_byte(8'b0111_0010, 4'd8);
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
            #(USB_BIT_PERIOD);
            @(negedge clk);
            #(USB_BIT_PERIOD);
            @(negedge clk);
            dp_in = 1;
            dm_in = 0;
            #(USB_BIT_PERIOD);
            @(negedge clk);
        end
    endtask

    task send_data0(input logic [3:0] num_bytes, input logic [31:0] data_in);
        integer i;
        integer n;
        begin
             #(USB_BIT_PERIOD * 9);
            @(negedge clk);
            @(negedge clk);
            //test_name = "SYNC BYTE";
            send_byte(8'b0010_1010, 4'd8);
            //#CLK_PERIOD;
            #(CLK_PERIOD * 5);
            @(negedge clk);
            // PID BYTE      
            send_byte(8'b0001_0100, 4'd8);
            @(negedge clk);
            //n byte data---------------------------------
            if(num_bytes == 1) begin
                send_byte(data_in[7:0], 4'd8);
            end
            //ahb_read(4'h4, 32'h80);
            if(num_bytes == 2) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
            end
            if(num_bytes == 3) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
                @(negedge clk);
                send_byte(data_in[23:16], 4'd8);
            end
            if(num_bytes == 4) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
                @(negedge clk);
                send_byte(data_in[23:16], 4'd8);
                @(negedge clk);
                send_byte(data_in[31:24], 4'd8);
            end
            @(negedge clk);
            //CRC16 bits---------------------------------
            //testname = "CRC16";
            send_byte(8'b1010_1110, 4'd8);
            @(negedge clk);
            //testname = "CRC16-2";
            send_byte(8'b0010_1010, 4'd8);
            @(negedge clk);
            //testname = "EOP";
            dp_in = 0;
            dm_in = 0;
            #(USB_BIT_PERIOD);
            @(negedge clk);
            #(USB_BIT_PERIOD);
            @(negedge clk);
            dp_in = 1;
            dm_in = 0;
            #(USB_BIT_PERIOD);

        end
    endtask

    task send_data1(input logic [3:0] num_bytes, input logic [31:0] data_in);
        integer i;
        begin
            #(USB_BIT_PERIOD * 9);
            @(negedge clk);
            @(negedge clk);
            //test_name = "SYNC BYTE";
            send_byte(8'b0010_1010, 4'd8);
            //#CLK_PERIOD;
            #(CLK_PERIOD * 5);
            @(negedge clk);
            // PID BYTE      
            send_byte(8'b0110_1100, 4'd8);
            #CLK_PERIOD;
            @(negedge clk);
            //n byte data---------------------------------
            if(num_bytes == 1) begin
                send_byte(data_in[7:0], 4'd8);
            end
            //ahb_read(4'h4, 32'h80);
            if(num_bytes == 2) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
            end
            if(num_bytes == 3) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
                @(negedge clk);
                send_byte(data_in[23:16], 4'd8);
            end
            if(num_bytes == 4) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
                @(negedge clk);
                send_byte(data_in[23:16], 4'd8);
                @(negedge clk);
                send_byte(data_in[31:24], 4'd8);
            end
            @(negedge clk);
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
            #(USB_BIT_PERIOD);
            @(negedge clk);
            #(USB_BIT_PERIOD);
            @(negedge clk);
            dp_in = 1;
            dm_in = 0;
            #(USB_BIT_PERIOD);

        end
    endtask

    task send_data1_crc_err(input logic [3:0] num_bytes, input logic [31:0] data_in);
        integer i;
        begin
            #(USB_BIT_PERIOD * 9);
            @(negedge clk);
            @(negedge clk);
            //test_name = "SYNC BYTE";
            send_byte(8'b0010_1010, 4'd8);
            //#CLK_PERIOD;
            #(CLK_PERIOD * 5);
            @(negedge clk);
            // PID BYTE      
            send_byte(8'b0110_1100, 4'd8);
            #CLK_PERIOD;
            @(negedge clk);
            //n byte data---------------------------------
            if(num_bytes == 1) begin
                send_byte(data_in[7:0], 4'd8);
            end
            //ahb_read(4'h4, 32'h80);
            if(num_bytes == 2) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
            end
            if(num_bytes == 3) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
                @(negedge clk);
                send_byte(data_in[23:16], 4'd8);
            end
            if(num_bytes == 4) begin
                send_byte(data_in[7:0], 4'd8);
                @(negedge clk);
                send_byte(data_in[15:8], 4'd8);
                @(negedge clk);
                send_byte(data_in[23:16], 4'd8);
                @(negedge clk);
                send_byte(data_in[31:24], 4'd8);
            end
            @(negedge clk);
            //CRC16 bits---------------------------------
            // "CRC16";
            send_byte(8'b1110_1110, 4'd8);
            @(negedge clk);
            // "CRC16-2";
            send_byte(8'b0010_1010, 4'd8);
            @(negedge clk);
            // "EOP";
            dp_in = 0;
            dm_in = 0;
            #(USB_BIT_PERIOD);
            @(negedge clk);
            #(USB_BIT_PERIOD);
            @(negedge clk);
            dp_in = 1;
            dm_in = 0;
            #(USB_BIT_PERIOD);

        end
    endtask

    task send_out_token;
        begin
            #(USB_BIT_PERIOD * 9);
            @(negedge clk);
            @(negedge clk);
            //test_name = "SYNC BYTE";
            send_byte(8'b0010_1010, 4'd8);
            //#CLK_PERIOD;
            #(CLK_PERIOD * 5);
            @(negedge clk);
            //test_name = "PID BYTE";
            send_byte(8'b0000_1010, 4'd8);
            //#(CLK_PERIOD * 5);
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
            #(USB_BIT_PERIOD);
            @(negedge clk);
            #(USB_BIT_PERIOD);
            @(negedge clk);
            dp_in = 1;
            dm_in = 0;
            #(USB_BIT_PERIOD);
            @(negedge clk);

        end
    endtask

    task send_ack_token;
        begin
        //test_name = "SYNC BYTE";
        @(negedge clk);
        @(negedge clk);
        send_byte(8'b0010_1010, 4'd8);
        #(CLK_PERIOD * 5);
        //#CLK_PERIOD;
        @(negedge clk);
        //test_name = "PID BYTE";
        send_byte(8'b0001_1011, 4'd8);
        @(negedge clk);
        // "EOP";
        dp_in = 0;
        dm_in = 0;
        #(USB_BIT_PERIOD);
        @(negedge clk);
        #(USB_BIT_PERIOD);
        @(negedge clk);
        dp_in = 1;
        dm_in = 0;
        #(USB_BIT_PERIOD);

        end
    endtask


    task check_multi_byte_usb(input logic [7:0] expected_payload [], output logic decoded []);
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

    logic prev_dp = 1;

    task decode_nrzi; //FOR JOEEEEEEEEE!!!!!
        input [7:0] expected_decoded;
        input eop;
        output logic match;

        integer i;
        //static integer prev_dp = 1;
        logic [7:0] decoded;
        logic [7:0] encoded_dp_output;
        logic [7:0] pdp;
        begin
            if(eop) begin
                pdp[0]=1'b1;
                prev_dp=1;
            end
            else begin
                pdp[0]=prev_dp;
                for (i = 0; i < 8; i++) begin
                    if (dp_out != pdp[i]) begin
                        if(i!=7) begin
                            pdp[i+1]=dp_out;
                        end
                        else begin
                            pdp[0]=dp_out;
                        end
                        decoded[i] = 0;
                        if(decoded[i] != expected_decoded[i]) begin
                            $display("bit %d doesnt match", i);
                        end
                        #(USB_BIT_PERIOD);
                    end else begin
                        if(i!=7) begin
                            pdp[i+1]=dp_out;
                        end
                        else begin
                            pdp[0]=dp_out;
                        end
                        decoded[i] = 1;
                        if(decoded[i] != expected_decoded[i]) begin
                            $display("bit %d doesnt match", i);
                        end
                        #(USB_BIT_PERIOD);
                    end
                end

                prev_dp = pdp;
                if (expected_decoded == decoded) begin
                    $display("Decoded matches!");
                    match = 1;
                end else begin
                    $display("Decoded doesn't match!");
                    match = 0;
                end

            end
            

        end
    endtask

    logic decode_success = 0;

    initial begin
        n_rst = 1;

        reset_dut;
        dp_in=1;
        dm_in=0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        //TEST 1 - write a byte and watch it come out
        testname = "end_to_host_verified";
        send_in_token();
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_read(4'h8, 32'h0, 3'b0);
        ahb_write(4'h0, 32'h53, 3'b0);
        ahb_write(4'hc, 32'h1, 3'b0);
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success);
        decode_nrzi(8'b11000011, 1'b0,  decode_success); //0101_0011
        decode_nrzi(8'b0101_0011, 1'b0,  decode_success);
        decode_nrzi(8'b00000000, 1'b0,  decode_success);
        decode_nrzi(8'b1000_0010, 1'b0,  decode_success);
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hc, 32'h0, 3'b0);
        send_ack_token();
        ahb_read(4'h4, 32'h8, 3'h1);
        $display("Test case %s completed verification.", testname);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);


        testname = "end to host multiple bytes";
        send_in_token();
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_read(4'h8, 32'h0, 3'b0);
        ahb_write(4'h0, 32'h12345678, 3'b10);
        ahb_write(4'h0, 32'hab, 3'b0);
        ahb_write(4'hc, 32'h2, 3'b0);
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success);
        decode_nrzi(8'b01001011, 1'b0,  decode_success); 
        decode_nrzi(8'h78, 1'b0,  decode_success);
        decode_nrzi(8'h56, 1'b0,  decode_success);
        decode_nrzi(8'h34, 1'b0,  decode_success);
        decode_nrzi(8'h12, 1'b0,  decode_success);
        decode_nrzi(8'hab, 1'b0,  decode_success);
        decode_nrzi(8'h66, 1'b0,  decode_success);
        decode_nrzi(8'hac, 1'b0,  decode_success);
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_read(4'h4, 32'h2, 3'b0);
        ahb_write(4'hc, 32'h0, 3'b0);
        send_ack_token();
        ahb_read(4'h4, 32'h8, 3'b0);
        $display("Test case %s completed verification.", testname);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);


        testname = "end to host data error";
        send_in_token();
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_read(4'h8, 32'h0, 3'b0);
        ahb_write(4'hc, 32'h1, 3'b0);
        @(negedge dp_out);
        @(negedge clk);

        decode_nrzi(8'b1000_0000, 1'b0, decode_success);
        // decode_nrzi(8'b11000011, 1'b0,  decode_success); 
        wait(d_mode == 0);
        ahb_read(4'h6, 32'h100, 3'b1);
        ahb_write(4'hc, 32'h0, 3'b0);
        decode_nrzi(8'h0, 1'b1, decode_success);

    
        $display("Test case %s completed verification.", testname);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        testname = "end to host not ack error";
        send_in_token();
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_read(4'h8, 32'h0, 3'b0);
        ahb_write(4'h0, 32'h67, 3'b0);
        ahb_write(4'hc, 32'h1, 3'b0);
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success);
        decode_nrzi(8'b11000011, 1'b0,  decode_success); //0101_0011
        decode_nrzi(8'h67, 1'b0,  decode_success);
        decode_nrzi(8'h01, 1'b0,  decode_success);
        decode_nrzi(8'h55, 1'b0,  decode_success);
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hc, 32'h0, 3'b0);
        send_out_token();
        ahb_read(4'h6, 32'h100, 3'h1);
        $display("Test case %s completed verification.", testname);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);


        testname = "End to Host cannot send data";
        send_in_token();
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_read(4'h8, 32'h0, 3'b0);
        //no data to send so bus send nak packet
        ahb_write(4'hc, 32'h4, 3'b0);
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success);
        decode_nrzi(8'b01011010, 1'b0,  decode_success); 
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hc, 32'h0, 3'b0);
        $display("Test case %s completed verification.", testname);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        testname = "End to Host halted";
        send_in_token();
        ahb_read(4'h4, 32'h2, 3'b1);
        //rx error is read
        //stall packet
        ahb_write(4'hc, 32'h5, 3'b0);
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success);
        decode_nrzi(8'b00011110, 1'b0,  decode_success); 
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_read(4'h4, 32'h2, 3'b1);
        ahb_write(4'hc, 32'h0, 3'b0);
        $display("Test case %s completed verification.", testname);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);




        testname = "host to end";
        send_out_token();
        ahb_read(4'h4, 32'h4, 3'b1);
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_write(4'hd, 32'h0, 3'b0);
        ahb_read(4'h8, 32'h0, 3'b0);
        send_data0(4'd4, 32'b0101_0101_1010_1010_0101_0101_1010_1010);
        ahb_read(4'h4, 32'h10, 3'b1);
        ahb_write(4'hc, 32'h3, 3'b0); //ACK
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success); //sync byte
        decode_nrzi(8'b1101_0010, 1'b0,  decode_success); //ack pid
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_write(4'hc, 32'h0, 3'b0);
        ahb_read(4'h8, 32'h4, 3'b0);
        ahb_read(4'h0, 32'h01, 3'b0); //wrong order please fix
        ahb_read(4'h0, 32'h01, 3'b0);
        ahb_read(4'h0, 32'h01, 3'b0);
        ahb_read(4'h0, 32'h01, 3'b0);
        ahb_write(4'hd, 32'h0, 3'b0);
        
        $display("Test case %s completed verification.", testname);


        @(posedge clk);
        @(posedge clk);

        testname = "host to end crc error";
        send_out_token();
        ahb_read(4'h4, 32'h4, 3'b1); //see if out token received
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_write(4'hd, 32'h0, 3'b0); //clear data buffer
        ahb_read(4'h8, 32'h0, 3'b0);
        send_data1_crc_err(4'd1, 8'b0011_0101);
        //enqueue_error_test();
        ahb_write(4'hc, 32'd4, 3'b0); //NACK
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success); //sync byte
        decode_nrzi(8'b0101_1010, 1'b0,  decode_success); //nack pid
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_write(4'hc, 32'h0, 3'b0);

        
        $display("Test case %s completed verification.", testname);

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        testname = "stall: host to end crc error";
        send_out_token();
        ahb_read(4'h4, 32'h4, 3'b1); //see if out token received
        ahb_write(4'hd, 32'h1, 3'b0);
        ahb_write(4'hd, 32'h0, 3'b0); //clear data buffer
        ahb_read(4'h8, 32'h0, 3'b0);
        send_data1_crc_err(4'd1, 8'b0011_0101);
        //enqueue_error_test();
        ahb_write(4'hc, 32'd5, 3'b0); //STALL
        @(negedge dp_out);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        decode_nrzi(8'b1000_0000, 1'b0, decode_success); //sync byte
        decode_nrzi(8'b0001_1110, 1'b0,  decode_success); //STALL pid
        decode_nrzi(8'h0, 1'b1, decode_success);
        wait(d_mode == 0);
        ahb_write(4'hc, 32'h0, 3'b0);

        
        $display("Test case %s completed verification.", testname);


        $finish;
    end
endmodule

/* verilator coverage_on */
