
module usb_ahb_subordinate (
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
    input logic [6:0] buffer_occupancy,
    input logic [7:0] rx_data,
    output logic [7:0] tx_data,
    output logic store_tx_data,
    output logic get_rx_data,
    input logic [15:0] reg_status,
    input logic [15:0] reg_error,
    input logic [7:0] reg_buffer_occ,
    input logic [7:0] reg_tx_ctrl,
    input logic [7:0] reg_flush_ctrl
);

    // HEADER: Types and Declarations
    typedef enum logic [1:0] { IDLE_E, ERR1, ERR2 } err_state_t;
    typedef enum logic { IDLE_W, BUSY_W } write_state_t;
    
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
        end
    end

    //-------------------------------------------------------------------------
    // COMBINATIONAL LOGIC BLOCKS
    //-------------------------------------------------------------------------

    // HEADER: Address Phase Error Detection
    always_comb begin
        addr_phase_err = 1'b0;
        if (HSEL && HTRANS[1] && HREADY) begin
            if ((HADDR >= 4'h9 && HADDR <= 4'hB) || (HADDR >= 4'hE)) begin
                addr_phase_err = 1'b1;
            end else if (HWRITE && (HADDR >= 4'h4 && HADDR <= 4'h8)) begin
                addr_phase_err = 1'b1;
            end
        end
    end

    // HEADER: Error FSM Next State
    always_comb begin
        next_err_state = err_state;
        case (err_state)
            IDLE_E: if (addr_phase_err) next_err_state = ERR1;
            ERR1: next_err_state = ERR2;
            ERR2: next_err_state = IDLE_E;
            default: next_err_state = IDLE_E;
        endcase
    end

    // HEADER: Serialization Logic
    always_comb begin
        next_write_state = write_state;
        next_byte_cnt = byte_cnt;
        case (write_state)
            IDLE_W: begin
                if (reg_wen && (reg_haddr[3:2] == 2'b00) && (reg_hsize == 3'b010) && HREADY) begin
                    if (buffer_occupancy < 7'd64) begin
                        next_write_state = BUSY_W;
                        next_byte_cnt = 2'b01;
                    end
                end
            end
            BUSY_W: begin
                if (buffer_occupancy < 7'd64) begin
                    if (byte_cnt == 2'b11) begin
                        next_write_state = IDLE_W;
                        next_byte_cnt = 2'b00;
                    end else begin
                        next_byte_cnt = byte_cnt + 2'b01;
                    end
                end
            end
        endcase
    end

    // HEADER: Local HREADY and HRESP Logic
    always_comb begin
        hready_out_int = 1'b1; 
        HRESP = 1'b0;

        if (err_state == ERR1) begin
            hready_out_int = 1'b0;
            HRESP = 1'b1;
        end else if (err_state == ERR2) begin
            hready_out_int = 1'b1;
            HRESP = 1'b1;
        end else if (reg_hsel && reg_htrans[1]) begin
            if (write_state == BUSY_W) begin
                hready_out_int = 1'b0;
            end else if (reg_haddr[3:2] == 2'b00) begin
                if (reg_hwrite && buffer_occupancy >= 7'd64) begin
                    hready_out_int = 1'b0;
                end
                if (!reg_hwrite && buffer_occupancy == 7'd0) begin
                    hready_out_int = 1'b0;
                end
            end
        end
    end
    assign HREADY = hready_out_int;

    // HEADER: HRDATA Next State & RAW Hazard Bypass
    logic [3:0]  active_addr;
    logic [2:0]  active_size;
    logic        active_read;
    logic [31:0] read_mask;
    logic [31:0] read_reg_data;

    always_comb begin
        // Prevent latches
        read_mask = 32'h0;
        write_mask = 4'b0000; 

        if (HREADY) begin
            active_addr = HADDR;
            active_size = HSIZE;
            active_read = (HSEL && !HWRITE && HTRANS[1]);
        end else begin
            active_addr = reg_haddr;
            active_size = reg_hsize;
            active_read = (reg_hsel && !reg_hwrite && reg_htrans[1]);
        end

        case (active_size[1:0])
            2'b00: read_mask[(active_addr[1:0]*8) +: 8] = 8'hFF;
            2'b01: read_mask[{active_addr[1], 1'b0}*8 +: 16] = 16'hFFFF;
            2'b10: read_mask = 32'hFFFFFFFF;
            default: read_mask = 32'h0;
        endcase

        case (active_addr[3:2])
            2'b00: read_reg_data = {rx_data, rx_data, rx_data, rx_data}; 
            2'b01: read_reg_data = {reg_error, reg_status}; 
            2'b10: read_reg_data = {24'h0, reg_buffer_occ};
            2'b11: read_reg_data = {16'h0, reg_flush_ctrl, reg_tx_ctrl};
            default: read_reg_data = 32'h0;
        endcase

        // RAW HAZARD BYPASS
        if (reg_wen && (active_addr[3:2] == reg_haddr[3:2]) && (active_addr[3:2] != 2'b00)) begin
            case (reg_hsize[1:0])
                2'b00: write_mask[reg_haddr[1:0]] = 1'b1;
                2'b01: write_mask[{reg_haddr[1], 1'b0} +: 2] = 2'b11;
                2'b10: write_mask = 4'b1111;
                default: write_mask = 4'b0000;
            endcase
            
            for (int i = 0; i < 4; i = i + 1) begin
                if (write_mask[i]) read_reg_data[8*i +: 8] = HWDATA[8*i +: 8];
            end
        end

        next_hrdata = 32'h0;
        if (active_read) begin
            next_hrdata = read_reg_data & read_mask;
        end
    end

    // HEADER: Data Buffer Steering Logic
    always_comb begin
        store_tx_data = 1'b0;
        get_rx_data = 1'b0;
        tx_data = 8'h0;
        if (reg_hsel && (reg_haddr[3:2] == 2'b00)) begin
            if (reg_hwrite) begin
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
                get_rx_data = 1'b1;
            end
        end
    end

endmodule
