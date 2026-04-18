`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_USB_tx ();

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

    logic [6:0] buffer_occupancy;
    logic [7:0] tx_packet_data;
    logic [2:0] tx_packet;
    logic get_tx_packet_data, tx_transfer_active, tx_error, DP_OUT, DM_OUT;
    integer i;
    string taskname;

    task reset_dut;
    begin
        n_rst = 0;
        buffer_occupancy=0;
        tx_packet_data=0;
        tx_packet=0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        @(posedge clk);
        @(posedge clk);
    end
    endtask

    USB_tx #() DUT (.*);

    task send_ACK;
    begin
        @(negedge clk);
        taskname = "send ACK";
        tx_packet=3;
        for(i=0; i<100; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<80; i=i+1) begin
            tx_packet=0;
            @(posedge clk);
        end
    end
    endtask

    task send_NACK;
    begin
        @(negedge clk);
        taskname = "send NACK";
        tx_packet=4;
        for(i=0; i<100; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<80; i=i+1) begin
            tx_packet=0;
            @(posedge clk);
        end
    end
    endtask

    task send_STALL;
    begin
        @(negedge clk);
        taskname = "send STALL";
        tx_packet=5;
        for(i=0; i<100; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<80; i=i+1) begin
            tx_packet=0;
            @(posedge clk);
        end
    end
    endtask

    task send_DATA0_empty;
    begin
        @(negedge clk);
        taskname = "send empty DATA0";
        tx_packet=1;
        for(i=0; i<135; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<40; i=i+1) begin
            tx_packet=0;
            @(posedge clk);
        end
    end
    endtask

    task send_DATA1_1byte;
    begin
        @(negedge clk);
        tx_packet=2;
        buffer_occupancy=1;
        tx_packet_data=8'b10101010;
        taskname = "send 1 byte DATA1";
        for(i=0; i<167; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<220; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=0;
            tx_packet_data=8'b11001100;
            @(posedge clk);
        end
    end
    endtask

    task send_DATA0_bytes;
    begin
        @(negedge clk);
        tx_packet=1;
        buffer_occupancy=5;
        tx_packet_data=8'b11001100;
        taskname = "send data0bytes";
        for(i=0; i<135; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=4;
            tx_packet_data=8'b11110000;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=3;
            tx_packet_data=8'b10100110;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=2;
            tx_packet_data=8'b00010011;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=1;
            tx_packet_data=8'b10101010;
            @(posedge clk);
        end
        for(i=0; i<210; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=0;
            tx_packet_data=8'b00111001;
            @(posedge clk);
        end
    end
    endtask

    task send_DATA0_bitstuff;
    begin
        @(negedge clk);
        tx_packet=1;
        buffer_occupancy=2;
        tx_packet_data=8'b00000000;
        taskname = "send bitstuff one byte";
        for(i=0; i<135; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=1;
            tx_packet_data=8'b01111110;
            @(posedge clk);
        end
        for(i=0; i<210; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=0;
            tx_packet_data=8'b11100000;
            @(posedge clk);
        end
    end
    endtask

    task send_all1s;
    begin
        @(negedge clk);
        tx_packet=1;
        buffer_occupancy=11;
        tx_packet_data=8'b11111111;
        taskname = "send all 1s";
        for(i=0; i<135; i=i+1) begin
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=10;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=9;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=8;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=7;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=6;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=5;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=4;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=3;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=2;
            @(posedge clk);
        end
        for(i=0; i<75; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=1;
            @(posedge clk);
        end
        for(i=0; i<210; i=i+1) begin
            tx_packet=0;
            buffer_occupancy=0;
            @(posedge clk);
        end
    end
    endtask


    initial begin
        n_rst = 1;

        reset_dut;
        // send_ACK;
        // send_NACK;
        // send_STALL;
        // send_DATA0_empty;
        send_DATA1_1byte;
        send_DATA0_bytes;
        send_DATA0_bitstuff;
        send_all1s;

        $finish;
    end
endmodule

/* verilator coverage_on */

