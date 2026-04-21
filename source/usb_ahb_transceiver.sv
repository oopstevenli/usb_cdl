module ahb_usb (
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
    logic [15:0] reg_status;
    logic [15:0] reg_error;
    logic [7:0]  reg_buffer_occ;
    logic [7:0]  reg_tx_ctrl;
    logic [7:0]  reg_flush_ctrl;
    logic [7:0]  tx_data;
    logic store_tx_data;
    logic get_rx_data;

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
    logic [7:0] buffer_rx_data;
    
    // packet decoder mapping
    // make sure these map how you guys did them
    localparam [2:0] RX_OUT_CODE = 3'd1; 
    localparam [2:0] RX_IN_CODE = 3'd2; 
    localparam [2:0] RX_DATA0_CODE = 3'd3;
    localparam [2:0] RX_DATA1_CODE = 3'd4;
    localparam [2:0] RX_ACK_CODE = 3'd5;

    logic rx_in_token, rx_out_token, rx_ack_received, rx_data0_received, rx_data1_received;

    assign rx_out_token = (rx_packet == RX_OUT_CODE);
    assign rx_in_token  = (rx_packet == RX_IN_CODE);
    assign rx_data0_received = (rx_packet == RX_DATA0_CODE);
    assign rx_data1_received = (rx_packet == RX_DATA1_CODE);
    assign rx_ack_received = (rx_packet == RX_ACK_CODE);


    assign reg_buffer_occ = {1'b0, buffer_occupancy};

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
        .tx_error(tx_error)
    );

    data_buffer FIFO (
        .clk(clk),
        .n_rst(n_rst),
        .tx_data(tx_data),
        .store_tx(store_tx_data),
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

    usb_tx TX_MODULE (
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
