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
    logic clk, n_rst;
    logic hsel, hwrite, hready, hresp;
    logic [3:0] haddr;
    logic [1:0] htrans;
    logic [2:0] hsize;
    logic [31:0] hwdata, hrdata;

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

    // clock generation
    localparam CLK_PERIOD = 10ns; // 100MHz
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
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data_arr, 1'b0, 3'b010, 3'b0, 1'b0);
            BFM.run_transactions(1);
            BFM.wait_done();
        end
    endtask

    task ahb_read(input logic [3:0] addr, input logic [31:0] expected);
        logic [31:0] data_arr [];
        begin
            data_arr = new [1]; // same same
            data_arr[0] = expected;
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data_arr, 1'b0, 3'b010, 3'b0, 1'b1);
            BFM.run_transactions(1);
            BFM.wait_done();
        end
    endtask

    task send_usb_packet(input logic [7:0] data_bytes []);
        begin
            // im just sending in data here idk if thats how its supposed to go
            foreach (data_bytes[i]) begin
                for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
                    dp_in = data_bytes[i][bit_idx];
                    dm_in = ~data_bytes[i][bit_idx];
                    #(USB_BIT_PERIOD);
                end
            end
            // end of packet
            dp_in = 0; dm_in = 0; #(USB_BIT_PERIOD * 2);
            dp_in = 1; dm_in = 1;
        end
    endtask

    task check_multi_byte_usb(input logic [7:0] expected_payload []);
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

    initial begin
        n_rst = 1;

        reset_dut;


        // TEST 1 - write a byte and watch it come out
        testname = "end_to_host_verified";

        // clear buffer and write test data ('S' for Squish)
        ahb_write(4'hD, 32'h1); 
        ahb_write(4'h0, 32'h53); 

        fork
            // waits for bus to move
            begin
                check_usb_data(8'h53); 
            end

            // host asks for data
            begin
                #(USB_BIT_PERIOD * 10); // Small delay to let the monitor settle
                send_usb_packet('{8'h80, 8'h69, 8'h00, 8'h00}); // Host sends IN token
            end
        join

        $display("Test case %s completed verification.", testname);

        // TEST 2 - write multiple bytes and watch them all come out
        testname = "top_multi_byte_burst";

        // fill the FIFO via AHB with 3 bytes -- might change this to send 3 bytes in with 1 write
        ahb_write(4'h0, 8'h41); // 'A'
        ahb_write(4'h0, 8'h42); // 'B'
        ahb_write(4'h0, 8'h43); // 'C'

        fork
            // check all bytes
            check_multi_byte_usb('{8'h41, 8'h42, 8'h43});

            // host triggers the "dump" with an IN token
            begin
                #(USB_BIT_PERIOD * 5);
                send_usb_packet('{8'h80, 8'h69, 8'h00, 8'h00}); 
            end
        join

        $display("Test case %s completed verification.", testname);

        $finish;
    end
endmodule

/* verilator coverage_on */

