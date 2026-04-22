module usb_ahb_subordinate (
    // bus
    input logic HCLK,
    input logic n_rst,
    input logic HSEL,
    input logic [3:0] HADDR,
    input logic HWRITE,
    input logic [1:0] HTRANS,
    input logic [2:0] HSIZE,
    input logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic HREADY,
    output logic HRESP,

    // data buffer
    input logic [6:0] buffer_occupancy,
    input logic [7:0] rx_data,
    output logic [7:0] tx_data,
    output logic store_tx_data,
    output logic get_rx_data,
    output logic clear,

    // rx
    input logic [2:0] rx_packet,
    input logic rx_data_ready,
    input logic rx_transfer_active,
    input logic rx_error,

    // tx
    output logic [2:0] tx_packet,
    input logic tx_transfer_active,
    input logic tx_error,

    output logic d_mode

);

    // READABILITY 
    typedef enum logic [1:0] { IDLE_E, ERR1, ERR2 } err_state_t;
    typedef enum logic { IDLE_W, BUSY_W } write_state_t;
    
    // size defs
    localparam [2:0] HSIZE_1B = 3'b000;
    localparam [2:0] HSIZE_2B = 3'b001;
    localparam [2:0] HSIZE_4B = 3'b010;
    
    // address - bits [3:2] of address
    localparam [1:0] REG_DATA_BUFF = 2'b00;
    localparam [1:0] REG_STAT_ERR = 2'b01;
    localparam [1:0] REG_OCCUPANCY = 2'b10;
    localparam [1:0] REG_CONTROL = 2'b11;

    // offsets to choose between 0xC and 0xD
    localparam [1:0] OFF_TX_PKT = 2'b00; // 0xC
    localparam [1:0] OFF_FLUSH = 2'b01; // 0xD
    

    //-------------------------------------------------------------------------
    // ADAPTER FOR RX AND TX
    //-------------------------------------------------------------------------

    // old signals
    logic [15:0] reg_status;
    logic [15:0] reg_error;
    logic [7:0] reg_buffer_occ;
    logic [7:0] reg_tx_ctrl;
    logic [7:0] reg_flush_ctrl;
    logic [7:0] next_status;

    // rx packet decoding to match stevens <3
    localparam [2:0] RX_OUT_CODE = 3'd1;
    localparam [2:0] RX_IN_CODE = 3'd2;
    localparam [2:0] RX_DATA0_CODE = 3'd3;
    localparam [2:0] RX_DATA1_CODE = 3'd4;
    localparam [2:0] RX_ACK_CODE = 3'd5;

    // tx packet decoding to match amys <3
    localparam [2:0] TX_DATA0_CODE = 3'd1;
    localparam [2:0] TX_DATA1_CODE = 3'd2;
    localparam [2:0] TX_ACK_CODE = 3'd3;
    localparam [2:0] TX_NAK_CODE = 3'd4;
    localparam [2:0] TX_STALL_CODE = 3'd5;

    assign tx_data0_send = (HREADY == 1 && HRESP == 0) && ~data_type && next_status[1];
    assign tx_data1_send = (HREADY == 1 && HRESP == 0) && data_type && next_status[1] ;    
    assign tx_send_ack = (HREADY == 1 && HRESP == 0);
    assign tx_send_nak = (HREADY == 0);
    assign tx_send_stall = (HRESP == 1);


    // logic signals for packet type (more readable)
    assign rx_out_token = (rx_packet == RX_OUT_CODE);
    assign rx_in_token = (rx_packet == RX_IN_CODE);
    assign rx_data0_received = (rx_packet == RX_DATA0_CODE);
    assign rx_data1_received = (rx_packet == RX_DATA1_CODE);
    assign rx_ack_received = (rx_packet == RX_ACK_CODE);

    logic data_type = 1'b0;
    logic next_data_type = 1'b0;

    // signal definitions moved from top level to here
    assign next_status = {
        6'b000000, // bits 15:10
        tx_transfer_active, // bit 9
        rx_transfer_active, // bit 8
        2'b00, // bits 7:6
        rx_data1_received, // bit 5
        rx_data0_received, // bit 4
        rx_ack_received, // bit 3
        rx_out_token, // bit 2
        rx_in_token, // bit 1
        rx_data_ready // bit 0
    };

    assign reg_error = {
        7'b0000000, // bits 15:9
        tx_error, // bit 8
        7'b0000000, // bits 7:1
        rx_error // bit 0
    };

    // output commands
    assign tx_packet = reg_tx_ctrl[2:0];
    assign clear = reg_flush_ctrl[0];
    assign d_mode = tx_transfer_active;
    
    //-------------------------------------------------------------------------
    // ORIGINAL LOGIC
    //-------------------------------------------------------------------------
    
    logic [3:0] reg_haddr;
    logic reg_hwrite;
    logic [2:0] reg_hsize;
    logic reg_hsel;
    logic reg_wen;
    logic [1:0] reg_htrans;
    logic [1:0] byte_cnt;
    err_state_t err_state;
    write_state_t write_state;

    logic addr_phase_err;
    logic [1:0] next_byte_cnt;
    err_state_t next_err_state;
    write_state_t next_write_state;
    logic [3:0] write_mask;
    logic [31:0] bypassed_reg_data;
    logic [31:0] next_hrdata;
    logic hready_out_int;
    logic [7:0] next_tx_ctrl;
    logic [7:0] next_flush_ctrl;
    


    //-------------------------------------------------------------------------
    // REGISTERED SIGNALS
    //-------------------------------------------------------------------------

    always_ff @(posedge HCLK or negedge n_rst) begin
        if (!n_rst) begin
            reg_haddr <= 4'h0;
            reg_hwrite <= 1'b0;
            reg_hsize <= 3'b0;
            reg_hsel <= 1'b0;
            reg_htrans <= 2'b00;
            reg_wen <= 1'b0;
            err_state <= IDLE_E;
            write_state <= IDLE_W;
            byte_cnt <= 2'b00;
            HRDATA <= 32'h0;
            reg_tx_ctrl <= 8'h00;
            reg_flush_ctrl <= 8'h00;
            reg_status <= 8'h00;
            data_type <= 1'b0;
        end else begin
            if (HREADY) begin
                reg_haddr <= HADDR;
                reg_hwrite <= HWRITE;
                reg_hsize <= HSIZE;
                reg_hsel <= HSEL;
                reg_htrans <= HTRANS;
                reg_wen <= HSEL && HTRANS[1] && HWRITE && !addr_phase_err;
            end

            err_state <= next_err_state;
            write_state <= next_write_state;
            byte_cnt <= next_byte_cnt;
            HRDATA <= next_hrdata;
            data_type <= next_data_type;

            reg_flush_ctrl <= next_flush_ctrl;
            reg_tx_ctrl <= next_tx_ctrl;
            reg_status <= next_status;
        end
    end

    //-------------------------------------------------------------------------
    // COMBINATIONAL LOGIC BLOCKS
    //-------------------------------------------------------------------------

    // Address Phase Error Detection
    // checks if there is a meaningful register at that address
    // checks if write attempt is valid
    always_comb begin
        addr_phase_err = 1'b0;
        if (HSEL && HTRANS[1] && HREADY) begin
            if ((HADDR >= 4'h9 && HADDR <= 4'hB) || (HADDR >= 4'hE)) begin // out of range addresses shouldnt be accessed
                addr_phase_err = 1'b1;
            end else if (HWRITE && (HADDR >= 4'h4 && HADDR <= 4'h8)) begin // read only addresses shouldnt be written to
                addr_phase_err = 1'b1;
            end
        end
    end

    // next_tx_ctrl and next_flush_ctrl logic
    always_comb begin
        next_tx_ctrl = reg_tx_ctrl;
        next_flush_ctrl = reg_flush_ctrl;
        if(reg_wen && (reg_haddr[3:2] == REG_CONTROL)) begin
            
            // assign tx_data0_send = reg_status[4];
            // assign tx_data1_send = reg_status[5];    
            // assign tx_send_ack = (HREADY == 1 && HRESP == 0);
            // assign tx_send_nak = (HREADY == 0);
            // assign tx_send_stall = (HRESP == 1);
            if(reg_haddr[1:0] == OFF_TX_PKT) begin
                if(tx_data0_send) next_tx_ctrl = {4'b0, TX_DATA0_CODE}; // write to 0xC
                if(tx_data1_send) next_tx_ctrl = {4'b0, TX_DATA1_CODE};
                if(tx_send_ack) next_tx_ctrl = {4'b0, TX_ACK_CODE};
                if(tx_send_nak) next_tx_ctrl = {4'b0, TX_NAK_CODE};
                if(tx_send_stall) next_tx_ctrl = {4'b0, TX_STALL_CODE};
            end
            
            if(reg_haddr[1:0] == OFF_FLUSH) begin
                next_flush_ctrl = HWDATA[15:8]; // write to 0xD
            end else begin
                next_flush_ctrl = 8'b0;
            end

        end
    end

    // Error FSM Next State
    // controls error states (2 cycles long)
    always_comb begin
        next_err_state = err_state;
        case (err_state)
            IDLE_E: if (addr_phase_err || rx_error) next_err_state = ERR1;
            ERR1: next_err_state = ERR2;
            ERR2: next_err_state = IDLE_E;
            default: next_err_state = IDLE_E;
        endcase
    end

    // Serialization Logic
    always_comb begin
        // defaults
        next_write_state = write_state;
        next_byte_cnt = byte_cnt;

        case (write_state)
            IDLE_W: begin
                if (reg_wen && (reg_haddr[3:2] == REG_DATA_BUFF) && (reg_hsize == HSIZE_4B || reg_hsize == HSIZE_2B) && HREADY) begin
                    if (buffer_occupancy < 7'd64) begin
                        next_write_state = BUSY_W; // will still be dealing with bytes next cycle
                        next_byte_cnt = 2'b01;
                    end
                end
            end
            BUSY_W: begin
                if (buffer_occupancy < 7'd64) begin
                    if ((reg_hsize == HSIZE_2B && byte_cnt == 2'b01) || (byte_cnt == 2'b11)) begin // stop after 1 byte for half word or 3 bytes for full word
                        next_write_state = IDLE_W;
                        next_byte_cnt = 2'b00;
                    end else begin
                        next_byte_cnt = byte_cnt + 2'b01;
                    end
                end
            end
        endcase
    end

    // Local HREADY and HRESP Logic
    // HREADY stops bus for errors and for flow controls
    // HRESP only goes high if theres an error
    always_comb begin
        hready_out_int = 1'b1; 
        HRESP = 1'b0;
        
        // error must last 2 cycles
        if (err_state == ERR1) begin // cycle 1
            hready_out_int = 1'b0;
            HRESP = 1'b1;
        end else if (err_state == ERR2) begin // cycle 2
            hready_out_int = 1'b1;
            HRESP = 1'b1;
        end else if (reg_hsel && reg_htrans[1]) begin
            if (write_state == BUSY_W) begin
                hready_out_int = 1'b0; // hold up the bus when busy
            end else if (reg_haddr[3:2] == REG_DATA_BUFF) begin
                if (reg_hwrite && buffer_occupancy >= 7'd64) begin // hold up bus from reading when fifo is full
                    hready_out_int = 1'b0;
                end
                if (!reg_hwrite && buffer_occupancy == 7'd0) begin // hold up bus from reading when fifo is empty
                    hready_out_int = 1'b0;
                end
            end
        end
    end
    assign HREADY = hready_out_int;

    // HEADER: HRDATA Next State & RAW Hazard Bypass
    logic [3:0] active_addr;
    logic [2:0] active_size;
    logic active_read;
    logic [31:0] read_mask;
    logic [31:0] read_reg_data;

    always_comb begin
        // default
        read_mask = 32'h0;
        write_mask = 4'b0000; 

        if (HREADY) begin // bus is moving, signals are new
            active_addr = HADDR;
            active_size = HSIZE;
            active_read = (HSEL && !HWRITE && HTRANS[1]);
        end else begin // bus is not moving, use registered signals
            active_addr = reg_haddr;
            active_size = reg_hsize;
            active_read = (reg_hsel && !reg_hwrite && reg_htrans[1]);
        end

        // decide how many bits to send based on current size request
        case (active_size[1:0])
            HSIZE_1B[1:0]: read_mask[(active_addr[1:0]*8) +: 8] = 8'hFF; // last 8 bits
            HSIZE_2B[1:0]: read_mask[{active_addr[1], 1'b0}*8 +: 16] = 16'hFFFF; // last 16 bits
            HSIZE_4B[1:0]: read_mask = 32'hFFFFFFFF; // full 32 bits
            default: read_mask = 32'h0;
        endcase

        case (active_addr[3:2]) // select where data is coming from
            REG_DATA_BUFF: read_reg_data = {rx_data, rx_data, rx_data, rx_data}; 
            REG_STAT_ERR: read_reg_data = {reg_error, reg_status}; 
            REG_OCCUPANCY: read_reg_data = {24'h0, reg_buffer_occ};
            REG_CONTROL: read_reg_data = {16'h0, reg_flush_ctrl, reg_tx_ctrl};
            default: read_reg_data = 32'h0;
        endcase

        // RAW HAZARD BYPASS
        if (reg_wen && (active_addr[3:2] == reg_haddr[3:2]) && (active_addr[3:2] != 2'b00)) begin
            case (reg_hsize[1:0]) // find which bytes were just written to
                2'b00: write_mask[reg_haddr[1:0]] = 1'b1; // last byte
                2'b01: write_mask[{reg_haddr[1], 1'b0} +: 2] = 2'b11; // last 2 bytes
                2'b10: write_mask = 4'b1111; // all bytes
                default: write_mask = 4'b0000;
            endcase
            
            for (int i = 0; i < 4; i = i + 1) begin
                if (write_mask[i]) read_reg_data[8*i +: 8] = HWDATA[8*i +: 8]; // put bypassed data into the live signal
            end
        end

        next_hrdata = 32'h0;
        if (active_read) begin
            next_hrdata = read_reg_data & read_mask; // update next output with the right size request
        end
    end

    // Data Buffer Steering Logic
    always_comb begin
        store_tx_data = 1'b0;
        get_rx_data = 1'b0;
        tx_data = 8'h0;
        if (reg_hsel && (reg_haddr[3:2] == REG_DATA_BUFF)) begin
            if (reg_hwrite) begin
                // write to data buffer
                if (write_state == BUSY_W) begin
                    if (buffer_occupancy < 7'd64) begin
                        store_tx_data = 1'b1;
                        tx_data = HWDATA[(8 * byte_cnt) +: 8];
                    end
                end else if (HREADY) begin
                    store_tx_data = 1'b1;
                    tx_data = HWDATA[(8 * reg_haddr[1:0]) +: 8];
                end
            end else if (HREADY) begin
                // read from data buffer
                get_rx_data = 1'b1; // pop from FIFO
            end
        end
    end

    always_comb begin
        next_data_type = data_type;
        if(reg_status[5] == 1) begin
            next_data_type = 1;
        end else if (reg_status[4] == 1) begin
            next_data_type = 0;
        end
    end

endmodule
