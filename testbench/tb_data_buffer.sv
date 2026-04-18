`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_data_buffer ();

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

    

    logic get_rx_data, store_tx_data, clear, flush, get_tx_packet_data, store_rx_packet_data;
    logic [7:0] tx_data, rx_packet_data;
    logic [6:0] buffer_occupancy;
    logic [7:0] rx_data, tx_packet_data;
    integer i;

    data_buffer DUT (.*);

    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        get_rx_data=0;
        store_tx_data=0;
        clear=0;
        flush=0;
        get_tx_packet_data=0;
        store_rx_packet_data=0;
        tx_data=0;
        rx_packet_data=0;
        @(posedge clk);
        @(posedge clk);
    end
    endtask

    task EndtoHostBuff;
    begin
        @(negedge clk);
        clear=1;
        @(negedge clk);
        clear=0;
        store_tx_data=1;
        tx_data=20;
        @(negedge clk);
        tx_data=13;
        @(negedge clk);
        tx_data=66;
        @(negedge clk);
        tx_data=100;
        @(negedge clk);
        store_tx_data=0;
        @(negedge clk);
        get_tx_packet_data=1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        get_tx_packet_data=0;
    end
    endtask;

    task HosttoEndBuff;
    begin
        @(negedge clk);
        flush=1;
        @(negedge clk);
        flush=0;
        store_rx_packet_data=1;
        rx_packet_data=100;
        @(negedge clk);
        rx_packet_data=10;
        @(negedge clk);
        rx_packet_data=1000;
        @(negedge clk);
        rx_packet_data=10000;
        @(negedge clk);
        rx_packet_data=1;
        @(negedge clk);
        rx_packet_data=900;
        @(negedge clk);
        rx_packet_data=18;
        @(negedge clk);
        rx_packet_data=4;
        @(negedge clk);
        store_rx_packet_data=0;
        get_rx_data=1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        get_rx_data=0;
        end
    endtask;

    task interchange;
    begin
        @(negedge clk);
        flush=1;
        @(negedge clk);
        flush=0;
        store_rx_packet_data=1;
        rx_packet_data=2;
        @(negedge clk);
        rx_packet_data=3;
        @(negedge clk);
        rx_packet_data=30;
        @(negedge clk);
        rx_packet_data=55;
        @(negedge clk);
        rx_packet_data=45;
        @(negedge clk);
        rx_packet_data=44;
        @(negedge clk);
        store_rx_packet_data=0;
        get_rx_data=1;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        get_rx_data=0;
        store_tx_data=1;
        tx_data=33;
        @(negedge clk);
        tx_data=44;
        @(negedge clk);
        tx_data=66;
        @(negedge clk);
        tx_data=10000;
        @(negedge clk);
        store_tx_data=0;
        get_tx_packet_data=1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        get_tx_packet_data=0;
        clear=0;
    end
    endtask;

    task storefull;
    begin
        @(negedge clk);
        flush=1;
        @(negedge clk);
        flush=0;
        @(posedge clk);
        for(i=0; i<70; i=i+1) begin
            @(negedge clk);
            store_rx_packet_data=1;
            rx_packet_data=i;
            @(posedge clk);
        end
        @(negedge clk);
        store_rx_packet_data=0;
        get_rx_data=1;
        for(i=0; i<70; i=i+1) begin
            @(posedge clk);
        end

        @(negedge clk);
        get_rx_data=0;
        clear=1;
        @(negedge clk);
        clear=0;
        @(negedge clk);
        for(i=0; i<70; i=i+1) begin
            @(negedge clk);
            store_tx_data=1;
            tx_data=i;
            @(posedge clk);
        end
        @(negedge clk);
        store_tx_data=0;
        get_tx_packet_data=1;
        for(i=0; i<70; i=i+1) begin
            @(posedge clk);
        end
        @(negedge clk);
        get_tx_packet_data=0;
        @(negedge clk);
    end
    endtask;

    task storeread;
    begin
        @(negedge clk);
        flush=1;
        @(negedge clk);
        flush=0;
        store_rx_packet_data=1;
        get_rx_data=1;
        rx_packet_data=5;
        @(negedge clk);
        rx_packet_data=10;
        @(negedge clk);
        rx_packet_data=15;
        @(negedge clk);
        store_rx_packet_data=0;
        get_rx_data=0;
        @(negedge clk);
        @(negedge clk);
        store_tx_data=1;
        get_tx_packet_data=1;
        tx_data=100;
        @(negedge clk);
        tx_data=1000;
        @(negedge clk);
        tx_data=999;
        @(negedge clk);
        store_tx_data=0;
        get_tx_packet_data=0;
        @(negedge clk);
        @(negedge clk);
    end
    endtask;

    initial begin
        n_rst = 1;

        reset_dut;
        @(posedge clk);
        @(posedge clk);
        EndtoHostBuff;
        @(posedge clk);
        @(posedge clk);
        HosttoEndBuff;
        @(posedge clk);
        @(posedge clk);
        interchange;
        @(posedge clk);
        @(posedge clk);
        storefull;
        @(posedge clk);
        @(posedge clk);
        storeread;
        @(posedge clk);
        @(posedge clk);

        $finish;
    end
endmodule

/* verilator coverage_on */

