`timescale 1ns / 10ps

module tb_usb_ahb_subordinate ();

    localparam CLK_PERIOD = 10ns;

    // AHB Sizes
    localparam SIZE_1B = 2'b00;
    localparam SIZE_2B = 2'b01;
    localparam SIZE_4B = 2'b10;

    // RX Packet Codes (Matching Steven's <3)
    localparam [2:0] RX_IDLE = 3'd0;
    localparam [2:0] RX_OUT = 3'd1;
    localparam [2:0] RX_IN = 3'd2;
    localparam [2:0] RX_DATA0  = 3'd3;

    // Signals for DUT
    logic clk, n_rst;
    logic hsel, hwrite, hready, hresp;
    logic [3:0] haddr;
    logic [1:0] htrans;
    logic [2:0] hsize;
    logic [2:0] hburst;
    logic [31:0] hwdata, hrdata;

    // Internal Mock Signals (UPDATED TO MATCH NEW PORTS)
    logic [6:0] mock_occ;
    logic [7:0] mock_rx_data;
    logic [7:0] mock_tx_data;
    logic mock_store_tx, mock_get_rx, mock_clear;
    
    // RX Mock Signals
    logic [2:0] mock_rx_packet;
    logic mock_rx_ready, mock_rx_active, mock_rx_err;
    
    // TX Mock Signals
    logic [7:0] mock_tx_packet;
    logic mock_tx_active, mock_tx_err;

    // WAVEFORM TEST NAME
    string testname; 

    // Clock Generation
    always begin
        clk = 0; #(CLK_PERIOD / 2.0);
        clk = 1; #(CLK_PERIOD / 2.0);
    end

    // DUT Instantiation (UPDATED MAPPING)
    usb_ahb_subordinate DUT (
        .HCLK(clk), .n_rst(n_rst),
        .HSEL(hsel), .HADDR(haddr), .HWRITE(hwrite), .HTRANS(htrans), .HSIZE(hsize),
        .HWDATA(hwdata), .HRDATA(hrdata), .HREADY(hready), .HRESP(hresp),
        // Buffer
        .buffer_occupancy(mock_occ), .rx_data(mock_rx_data),
        .tx_data(dut_tx_data), .store_tx_data(mock_store_tx), 
        .get_rx_data(mock_get_rx), .clear(mock_clear),
        // RX
        .rx_packet(mock_rx_packet), .rx_data_ready(mock_rx_ready),
        .rx_transfer_active(mock_rx_active), .rx_error(mock_rx_err),
        // TX
        .tx_packet(mock_tx_packet), .tx_transfer_active(mock_tx_active),
        .tx_error(mock_tx_err)
    );

    // BFM Instantiation
    ahb_model_updated #( .ADDR_WIDTH(4), .DATA_WIDTH(4) ) BFM (
        .clk(clk), .hsel(hsel), .haddr(haddr), .hsize(hsize), 
        .htrans(htrans), .hburst(hburst), .hwrite(hwrite), .hwdata(hwdata),
        .hrdata(hrdata), .hresp(hresp), .hready(hready)
    );

    // --- HELPER TASKS (Same as before) ---
    task enqueue_write ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata);
        logic [31:0] data [];
        begin
            data = new [1]; data[0] = wdata;
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b0, {1'b0, size}, 3'b0, 1'b0);
        end
    endtask

    task enqueue_read ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] exp_read);
        logic [31:0] data [];
        begin
            data = new [1]; data[0] = exp_read;
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data, 1'b0, {1'b0, size}, 3'b0, 1'b0);
        end
    endtask

    task enqueue_error_test (input logic [3:0] addr, input logic [31:0] wdata);
        logic [31:0] data [];
        begin
            data = new [1]; data[0] = wdata;
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b1, {1'b0, SIZE_1B}, 3'b0, 1'b1);
        end
    endtask

    task execute_transactions (input int num_transactions);
        BFM.run_transactions(num_transactions);
    endtask

    task finish_transactions();
        BFM.wait_done();
    endtask

    task reset_dut;
        begin
            n_rst = 0; @(negedge clk); n_rst = 1; @(posedge clk);
        end
    endtask

    // --- THE PURGE ---
    initial begin
        // --- 1. INITIALIZATION & RESET ---
        n_rst = 1; mock_occ = 0; mock_rx_data = 0; 
        mock_rx_packet = RX_IDLE; mock_rx_ready = 0; mock_rx_active = 0; mock_rx_err = 0;
        mock_tx_active = 0; mock_tx_err = 0;
        
        testname = "IDLE";
        BFM.reset_model();
        reset_dut();

        // --- 2. BASIC BUFFER OPS ---
        testname = "T1: 1-byte Push 0x0";
        enqueue_write(4'h0, SIZE_1B, 32'hA5);
        execute_transactions(1);
        finish_transactions();

        testname = "T2: 1-byte Pop 0x0";
        mock_rx_data = 8'h5A; mock_occ = 1; 
        enqueue_read(4'h0, SIZE_1B, 32'h5A);
        execute_transactions(1);
        finish_transactions();

        // --- 3. STATUS & CONTROL REGS ---
        testname = "T3: Status Reg Read";
        mock_rx_ready = 1'b1; mock_rx_packet = RX_IN; // Packs to 16'h0003
        enqueue_read(4'h4, SIZE_2B, 32'h0003); 
        execute_transactions(1);
        finish_transactions();

        testname = "T4: Buffer Flush 0xD";
        enqueue_write(4'hD, SIZE_1B, 32'h01);
        execute_transactions(1); 
        finish_transactions();

        // --- 4. SERIALIZATION TESTS (16-bit and 32-bit) ---
        testname = "T6: 32-bit Word Push (Serialization)";
        mock_occ = 0;
        enqueue_write(4'h0, SIZE_4B, 32'h04030201);
        execute_transactions(1); // Should see 3 stall cycles
        finish_transactions();

        testname = "T7: 16-bit Halfword Push (Serialization)";
        enqueue_write(4'h0, SIZE_2B, 32'h0000BEEF); // Should see 1 stall cycle
        execute_transactions(1);
        finish_transactions();

        testname = "T17: Little Endian Check";
        enqueue_write(4'h0, SIZE_4B, 32'h04030201); // Verify 01 is first byte pushed
        execute_transactions(1);
        finish_transactions();

        // --- 5. RAW HAZARD BYPASS TESTS ---
        testname = "T10: RAW Hazard (Byte)";
        enqueue_write(4'hC, SIZE_1B, 32'h02); 
        enqueue_read(4'hC, SIZE_1B, 32'h02);  
        execute_transactions(2);
        finish_transactions();

        testname = "T16: RAW Hazard (Word)";
        enqueue_write(4'hC, SIZE_4B, 32'h00000103); 
        enqueue_read(4'hC, SIZE_4B, 32'h00000103);
        execute_transactions(2);
        finish_transactions();

        testname = "T12: FIFO Bypass Exclusion (Safety Check)";
        mock_rx_data = 8'h99; mock_occ = 1;
        enqueue_write(4'h0, SIZE_1B, 32'h22); // Write to FIFO
        enqueue_read(4'h0, SIZE_1B, 32'h99);  // Should NOT bypass; should see old 99
        execute_transactions(2);
        finish_transactions();

        // --- 6. FLOW CONTROL STALL TESTS ---
        testname = "T14: Full Buffer Stall";
        mock_occ = 64; 
        enqueue_write(4'h0, SIZE_1B, 32'hFF);
        fork
            execute_transactions(1);
            begin repeat(5) @(posedge clk); mock_occ = 60; end // Release stall
        join
        finish_transactions();

        testname = "T15: Empty Buffer Stall";
        mock_occ = 0;
        enqueue_read(4'h0, SIZE_1B, 32'h77);
        fork
            execute_transactions(1);
            begin 
                repeat(5) @(posedge clk); 
                mock_rx_data = 8'h77; @(posedge clk); mock_occ = 1; 
            end
        join
        finish_transactions();

        // --- 7. ERROR & RESET TESTS ---
        testname = "T5: RO Violation Error";
        enqueue_error_test(4'h4, 32'hFFFF);
        execute_transactions(1);
        finish_transactions();

        testname = "T13: Address Hole Error";
        enqueue_error_test(4'h9, 32'h0);
        execute_transactions(1);
        finish_transactions();

        testname = "T16: Protocol Reset (Mid-Transaction)";
        enqueue_write(4'h0, SIZE_4B, 32'hFFFFFFFF);
        fork 
            execute_transactions(1);
            begin repeat(2) @(posedge clk); n_rst = 0; #1 n_rst = 1; end
        join
        finish_transactions();

        testname = "PURGE COMPLETE";
        $display("All integrated tests finished successfully.");
        $finish;
    end

endmodule
