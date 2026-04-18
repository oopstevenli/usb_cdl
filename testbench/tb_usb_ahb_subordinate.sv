`timescale 1ns / 10ps

module tb_usb_ahb_subordinate ();

    localparam CLK_PERIOD = 10ns;
    localparam TIMEOUT = 1000;

    // AHB Sizes
    localparam SIZE_1B = 2'b00;
    localparam SIZE_2B = 2'b01;
    localparam SIZE_4B = 2'b10;

    // Transaction Types
    localparam BURST_SINGLE = 3'd0;
    localparam BURST_INCR4  = 3'd3;

    // Signals for DUT
    logic clk, n_rst;
    logic hsel, hwrite, hready, hresp;
    logic [3:0] haddr;
    logic [1:0] htrans;
    logic [2:0] hsize;
    logic [2:0] hburst;
    logic [31:0] hwdata, hrdata;

    // Internal Mock Signals
    logic [6:0]  mock_occ;
    logic [7:0]  mock_rx_data;
    logic [7:0]  dut_tx_data;
    logic        dut_store_tx, dut_get_rx;
    logic [15:0] mock_status, mock_error;
    logic [7:0]  mock_occ_reg, mock_tx_ctrl, mock_flush_ctrl;

    // WAVEFORM TEST NAME
    string testname; 

    // Clock Generation
    always begin
        clk = 0; #(CLK_PERIOD / 2.0);
        clk = 1; #(CLK_PERIOD / 2.0);
    end

    // DUT Instantiation
    usb_ahb_subordinate DUT (
        .HCLK(clk), .n_rst(n_rst),
        .HSEL(hsel), .HADDR(haddr), .HWRITE(hwrite), .HTRANS(htrans), .HSIZE(hsize),
        .HWDATA(hwdata), .HRDATA(hrdata), .HREADY(hready), .HRESP(hresp),
        .buffer_occupancy(mock_occ), .rx_data(mock_rx_data),
        .tx_data(dut_tx_data), .store_tx_data(dut_store_tx), .get_rx_data(dut_get_rx),
        .reg_status(mock_status), .reg_error(mock_error), .reg_buffer_occ(mock_occ_reg),
        .reg_tx_ctrl(mock_tx_ctrl), .reg_flush_ctrl(mock_flush_ctrl)
    );

    // BFM Instantiation
    ahb_model_updated #( .ADDR_WIDTH(4), .DATA_WIDTH(4) ) BFM (
        .clk(clk), .hsel(hsel), .haddr(haddr), .hsize(hsize), 
        .htrans(htrans), .hburst(hburst), .hwrite(hwrite), .hwdata(hwdata),
        .hrdata(hrdata), .hresp(hresp), .hready(hready)
    );

    // --- HELPER TASKS ---
    task enqueue_write ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = wdata;
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b0, {2'b0, size}, 3'b0, 1'b0);
        end
    endtask

    task enqueue_read ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] exp_read );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = exp_read;
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data, 1'b0, {1'b0, size}, 3'b0, 1'b1);
        end
    endtask

    task execute_transactions (input int num_transactions);
        BFM.run_transactions(num_transactions);
    endtask

    task finish_transactions();
        begin
            BFM.wait_done();
        end
    endtask

    task enqueue_burst_read ( input logic [3:0] base_addr, input logic [1:0] size, input logic [2:0] burst, input logic [31:0] data [] );
        BFM.enqueue_transaction(1'b1, 1'b0, base_addr, data, 1'b0, {1'b0, size}, burst, 1'b1);
    endtask

    task reset_dut;
        begin
            n_rst = 0; @(negedge clk); n_rst = 1; @(posedge clk);
        end
    endtask

    task enqueue_error_test (input logic [3:0] addr, input logic [31:0] wdata);
        logic [31:0] data [];
        begin
            data = new [1]; data[0] = wdata;
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b1, {1'b0, SIZE_1B}, 3'b0, 1'b0);
        end
    endtask

    // --- THE PURGE ---
    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, tb_usb_ahb_subordinate);
        
        // Initialize
        n_rst = 1; mock_occ = 0; mock_rx_data = 0; 
        mock_status = 0; mock_error = 0; mock_occ_reg = 0;
        mock_tx_ctrl = 0; mock_flush_ctrl = 0;
        testname = "IDLE";
        BFM.reset_model();
        reset_dut();

        // 1. 1-byte Write to 0x0
        testname = "T1: 1-byte Push 0x0";
        enqueue_write(4'h0, SIZE_1B, 32'hA5);
        execute_transactions(1);
        finish_transactions();

        // 2. 1-byte Read from 0x0
        testname = "T2: 1-byte Pop 0x0";
        mock_rx_data = 8'h5A; mock_occ = 1; 
        enqueue_read(4'h0, SIZE_1B, 32'h5A);
        execute_transactions(1);
        finish_transactions();

        // 3. Status Register Read
        testname = "T3: Status Reg Read";
        mock_status = 16'h0003; 
        enqueue_read(4'h4, SIZE_2B, 32'h0003);
        execute_transactions(1);
        finish_transactions();

        // 4. Buffer Flush
        testname = "T4: Buffer Flush 0xD";
        enqueue_write(4'hD, SIZE_1B, 32'h1);
        execute_transactions(1); 
        finish_transactions();

        // 5. Read-Only Violation
        testname = "T5: RO Violation Error";
        enqueue_error_test(4'h4, 32'hFFFF);
        execute_transactions(1);
        finish_transactions();

        // 6. Word Write Serialization
        testname = "T6: 32-bit Word Push";
        mock_occ = 0;
        enqueue_write(4'h0, SIZE_4B, 32'h04030201);
        execute_transactions(1);
        finish_transactions();

        // 7. Halfword Write
        testname = "T7: 16-bit Halfword Push";
        enqueue_write(4'h0, SIZE_2B, 32'h0000BEEF);
        execute_transactions(1);
        finish_transactions();

        // 8. Sequential Reads (Burst Mode) 
        /*
        testname = "T8: Burst Read Sequence";
        mock_rx_data = 8'h11;
        mock_occ = 2;
        enqueue_read(4'h0, SIZE_1B, 32'h11);
        enqueue_read(4'h1, SIZE_1B, 32'h11); 
        execute_transactions(2);
        finish_transactions();
        */

        // 10. RAW Hazard Bypass
        testname = "T10: RAW Hazard Bypass";
        enqueue_write(4'hC, SIZE_1B, 32'h02); 
        enqueue_read(4'hC, SIZE_1B, 32'h02);  
        execute_transactions(2);
        finish_transactions();

        // 11. Partial Word Bypass
        testname = "T11: Partial Byte Bypass";
        enqueue_write(4'hC, SIZE_4B, 32'h01020304); 
        enqueue_read(4'hD, SIZE_1B, 32'h03);
        execute_transactions(2);
        finish_transactions();

        // 12. FIFO Bypass Exclusion
        testname = "T12: FIFO Bypass Exclusion";
        mock_rx_data = 8'h99;
        mock_occ = 1;
        enqueue_write(4'h0, SIZE_1B, 32'h22); 
        enqueue_read(4'h0, SIZE_1B, 32'h99);  
        execute_transactions(2);
        finish_transactions();

        // 13. Address Hole Error
        testname = "T13: Address Hole Error";
        enqueue_error_test(4'h9, 32'h0);
        execute_transactions(1);
        finish_transactions();

        // 14. Full Buffer Stall
        testname = "T14: Full Buffer Stall";
        mock_occ = 64; 
        enqueue_write(4'h0, SIZE_1B, 32'hFF);
        fork
            execute_transactions(1);
            begin repeat(5) @(posedge clk); mock_occ = 60; end 
        join
        finish_transactions();

        // 15. Empty Buffer Stall
        testname = "T15: Empty Buffer Stall";
        mock_occ = 0;
        enqueue_read(4'h0, SIZE_1B, 32'h77);
        fork
            execute_transactions(1);
            begin 
                repeat(5) @(posedge clk); 
                mock_rx_data = 8'h77;
                @(posedge clk);
                mock_occ = 1;
            end
        join
        finish_transactions();

        // 16. Mid-Transaction Reset
        testname = "T16: Protocol Reset";
        enqueue_write(4'h0, SIZE_4B, 32'hFFFFFFFF);
        fork 
            execute_transactions(1);
            begin repeat(2) @(posedge clk); n_rst = 0; #1 n_rst = 1; end
        join
        finish_transactions();

        // 17. Little Endian Check
        testname = "T17: Little Endian Order";
        enqueue_write(4'h0, SIZE_4B, 32'h04030201);
        execute_transactions(1);
        finish_transactions();

        // 18. Burst Feature Check
        /*
        testname = "T18: INCR4 Burst Read";
        begin
            logic [31:0] burst_data [];
            burst_data = new[4];
            burst_data = {32'h77, 32'h77, 32'h77, 32'h77};
            enqueue_burst_read(4'h0, SIZE_1B, BURST_INCR4, burst_data);
            execute_transactions(4);
        end
        finish_transactions();
        */

        // 19. Back-to-Back Ready Check
        testname = "T19: Back-to-Back Fast Write";
        enqueue_write(4'hC, SIZE_1B, 32'hAA);
        enqueue_write(4'hD, SIZE_1B, 32'hBB);
        execute_transactions(2);
        finish_transactions();

        // 20. Throughput Torture
        testname = "T20: Max Throughput";
        mock_rx_data = 8'h99;
        mock_occ = 32;
        enqueue_write(4'h0, SIZE_1B, 32'h11);
        enqueue_read(4'h0, SIZE_1B, 32'h99);
        execute_transactions(2);
        finish_transactions();

        testname = "PURGE COMPLETE";
        $display("All tests finished. Check waveforms for %s", testname);
        $finish;
    end

endmodule
