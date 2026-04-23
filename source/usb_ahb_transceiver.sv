module usb_ahb_transceiver (
    input logic clk,
    input logic n_rst,
    input logic hsel,
    input logic [3:0] haddr,
    input logic [1:0] htrans,
    input logic [2:0] hsize,
    input logic hwrite,
    input logic [31:0] hwdata,
    output logic [31:0] hrdata,
    output logic hready,
    output logic hresp,
    input logic dp_in,
    input logic dm_in,
    output logic dp_out,
    output logic dm_out,
    output logic d_mode
);
    
    // ahb sub
    logic [7:0] tx_data;
    logic store_tx_data;
    logic get_rx_data;
    logic clear;
    logic [2:0] tx_packet;

    // rx
    logic [2:0] rx_packet;
    logic rx_data_ready;
    logic rx_transfer_active;
    logic rx_error;
    logic store_rx_packet_data;
    logic [7:0] rx_packet_data;
    logic rx_flush;

    // tx
    logic [7:0] tx_packet_data;
    logic get_tx_packet_data;
    logic tx_transfer_active;
    logic tx_error;

    // data buffer
    logic [6:0] buffer_occupancy;
    logic [7:0] rx_data;

    usb_ahb_subordinate AHB_SUB (
        // bus signals
        .HCLK(clk),
        .n_rst(n_rst),
        .HSEL(hsel),
        .HADDR(haddr),
        .HWRITE(hwrite),
        .HTRANS(htrans),
        .HSIZE(hsize),
        .HWDATA(hwdata),
        .HRDATA(hrdata),
        .HREADY(hready),
        .HRESP(hresp),
        
        // data buffer
        .buffer_occupancy(buffer_occupancy),
        .rx_data(rx_data),
        .tx_data(tx_data),
        .store_tx_data(store_tx_data),
        .get_rx_data(get_rx_data),
        .clear(clear),

        // rx
        .rx_packet(rx_packet),
        .rx_data_ready(rx_data_ready),
        .rx_transfer_active(rx_transfer_active),
        .rx_error(rx_error),

        // tx
        .tx_packet(tx_packet),
        .tx_transfer_active(tx_transfer_active),
        .tx_error(tx_error),

        .d_mode(d_mode)
    );

    data_buffer FIFO (
        .clk(clk),
        .n_rst(n_rst),
        .tx_data(tx_data),
        .store_tx_data(store_tx_data),
        .get_rx_data(get_rx_data),
        .rx_data(rx_data),
        .rx_packet_data(rx_packet_data),
        .store_rx_packet_data(store_rx_packet_data),
        .get_tx_packet_data(get_tx_packet_data),
        .tx_packet_data(tx_packet_data),
        .flush(rx_flush),
        .buffer_occupancy(buffer_occupancy),
        .clear(clear)
    );

    usb_rx RX_MODULE (
        .clk(clk),
        .n_rst(n_rst),
        .dp_in(dp_in),
        .dm_in(dm_in),
        .buffer_occupancy(buffer_occupancy),
        .rx_packet(rx_packet),
        .rx_data_ready(rx_data_ready),
        .rx_transfer_active(rx_transfer_active),
        .rx_error(rx_error),
        .store_rx_packet_data(store_rx_packet_data),
        .rx_packet_data(rx_packet_data),
        .flush(rx_flush)
    );

    USB_tx TX_MODULE (
        .clk(clk),
        .n_rst(n_rst),
        .DP_OUT(dp_out),
        .DM_OUT(dm_out),
        .buffer_occupancy(buffer_occupancy),
        .tx_packet_data(tx_packet_data),
        .tx_packet(tx_packet),
        .get_tx_packet_data(get_tx_packet_data),
        .tx_transfer_active(tx_transfer_active),
        .tx_error(tx_error)
    );



endmodule
