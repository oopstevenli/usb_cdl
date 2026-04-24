`timescale 1ns / 10ps

module usb_rx #(
    // parameters
) (
    input logic clk, n_rst,
    input logic dp_in, dm_in,
    input logic [6:0] buffer_occupancy,
    output logic [2:0] rx_packet,
    output logic rx_data_ready,
    output logic rx_transfer_active,
    output logic rx_error,
    output logic store_rx_packet_data,
    output logic [7:0] rx_packet_data,
    output logic flush
);
    logic d_orig, edge_detected, eop_detected;
    logic count_enable_timer;
    logic shift_strobe, eight_bit_done, seven_bit_done, four_bit_done, five_bit_done;
    logic [7:0] out0, out1, out2, out3; //results from three registers
    logic valid1, valid2;
    logic enable4, enable5, enable7, enable8; //for bit counters
    logic data_eop, n_data_eop;
    logic clear_timer;
    logic [3:0] count6, n_count6;
    logic valid_bit;
    logic shift_enable;
    logic [2:0] hold_rx_pack, n_hold_rx_pack;
    logic stuff_error;
    

    nrzi_decoder nrzi (
        .clk(clk), .n_rst(n_rst),  .dp(dp_in), .dm(dm_in), .d_orig(d_orig), .shift_strobe(shift_strobe), .edge_detected(edge_detected), .eop_detected(eop_detected)
    );
    rx_timer time0 (
        .clk(clk), .n_rst(n_rst), .clear_timer(clear_timer), .enable8(valid_bit & enable8), .enable4(enable4), .enable5(enable5), .enable7(enable7), .count_enable_timer(count_enable_timer), .shift_strobe(shift_strobe), .eight_bit_done(eight_bit_done), .seven_bit_done(seven_bit_done), .four_bit_done(four_bit_done), .five_bit_done(five_bit_done)
    );
    flex_sr #(
        .SIZE(8),
        .MSB_FIRST(0)
    ) sr8bit (
        .clk(clk),
        .n_rst(n_rst),
        .shift_enable(shift_enable),
        .load_enable(1'b0),
        .serial_in(d_orig),
        .parallel_in('0),
        /* verilator lint_off PINCONNECTEMPTY */
        .serial_out(), 
        /* verilator lint_on PINCONNECTEMPTY */
        .parallel_out(out0)

    );

    assign shift_enable = shift_strobe & valid_bit;

    typedef enum logic [4:0] {
        IDLE = 5'd0,
        SYNC = 5'd1,
        PID = 5'd2,
        TOKEN = 5'd3,
        ENDP = 5'd4,
        LOAD_DATA = 5'd5,
        CHECK_DATA = 5'd6,
        CRC5 = 5'd7,
        CRC16 = 5'd8,
        EOP = 5'd9,
        ERR = 5'd10,
        STOP = 5'd11,
        DATA_ERR = 5'd12,
        CHECK_SYNC = 5'd13,
        CHECK_PID = 5'd14,
        CHECK_TOKEN = 5'd15,
        CHECK_ENDP = 5'd16
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk or negedge n_rst) begin : FSM
        if (!n_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk or negedge n_rst) begin : REGISTERS //out1 and out2 should hold the bits for crc16 because we don't want them to get into the data buffer
        if (!n_rst) begin
            out1 <= '0;
            out2 <= '0;
            out3  <= '0;
        end else if (eight_bit_done) begin
            out3 <= out2;
            out2 <= out1;
            out1 <= out0;
        end
    end

    always_ff @(posedge clk or negedge n_rst) begin : VALID_SR 
        if (!n_rst) begin
            valid1 <= '0;
            valid2 <= '0;
        end else if (eight_bit_done) begin
            valid2 <= valid1;
            valid1 <= (state == LOAD_DATA);
        end
    end

    always_ff @(posedge clk or negedge n_rst) begin : D_EOP 
        if (!n_rst) begin
            data_eop <= '0;
        end else begin
            data_eop <= n_data_eop;
        end
    end
    //=======================================================================
    always_ff @(posedge clk or negedge n_rst) begin : BIT_UNSTUFF 
        if (!n_rst) begin
            count6 <= '0; 
            
        end else begin
            count6 <= n_count6;
        end
    end  

    always_comb begin
        n_count6 = count6;

        if (shift_strobe) begin
            if (d_orig == 1'b1) begin
                n_count6 = count6 + 1;
            end else begin
                n_count6 = '0;
            end
        end
    end

    

    always_comb begin
        valid_bit = 1;
        stuff_error = '0;

        if (count6 == 4'd6 && d_orig == 1'b0) begin
            valid_bit = '0;
        end else if (count6 > 4'd6 && d_orig) begin
            stuff_error = 1;
        end
    end
    //==========================================================

    always_comb begin
        
        if (eop_detected)
            n_data_eop = 1;
        else if (state == IDLE) begin
            n_data_eop = 0;
        end
        else begin
            n_data_eop = data_eop;
        end
    end

    always_comb begin : NEXT_STATE_LOGIC
        next_state = state; //default

        case(state)
            IDLE: begin
                if (edge_detected)
                    next_state = SYNC;
                else    
                    next_state = IDLE;
            end
            SYNC: begin
                if (eight_bit_done) begin
                    next_state = CHECK_SYNC;
                end

            end

            CHECK_SYNC: begin
                if (out0 == 8'b1000_0000) begin
                    next_state = PID;
                end else begin
                    next_state = ERR;
            end
            end
            PID: begin
                if (eight_bit_done) begin
                    next_state = CHECK_PID;
                end
            end
            CHECK_PID: begin
                
                if ((out0 == 8'b1110_0001) || (out0 == 8'b0110_1001)) begin //TOKEN
                    next_state = TOKEN;
                end else if (((out0 == 8'b1100_0011) || (out0 == 8'b0100_1011)))begin //DATA
                    next_state = LOAD_DATA;
                end else if (((out0 == 8'b1101_0010)))begin //ACK
                    next_state = STOP;
                end else begin
                    next_state = ERR;
                end
                
            end

            TOKEN: begin
                if (seven_bit_done) begin
                    next_state = CHECK_TOKEN;
                end
            end
            CHECK_TOKEN: begin
            if (out0[7:1] == 7'b000_0001) //Assume address of endpoint is 000_0001 and multiple subordinates are connected
                    next_state = ENDP;
                else //wrong address
                    next_state = ERR;
            end
            ENDP: begin
                if (four_bit_done) begin
                    next_state = CHECK_ENDP;
                end
            end
            CHECK_ENDP: begin
                if (out0[7:4] == 4'b0001) //assum endpoint is 0001
                    next_state = CRC5;
                else
                    next_state = ERR;

            end
            LOAD_DATA: begin
                if ((buffer_occupancy == 7'd64) || stuff_error)
                    next_state = DATA_ERR;
                else if (eop_detected)
                    next_state = CRC16;
                else if (eight_bit_done && valid2) begin
                    next_state = CHECK_DATA;
                end

            end
            CHECK_DATA: begin
                next_state = LOAD_DATA;
            end
            CRC5: begin
                if (five_bit_done) begin //01100
                    if (out0[7:3] == 5'b01100)
                        next_state = EOP;
                    else    
                        next_state = ERR;
                end
            end
            CRC16: begin
                if ({out1, out2} == 16'b1000_0000_0000_1101) begin
                    next_state = STOP;
                end else begin
                    next_state = ERR;
                end
            end
            EOP: begin
                if (four_bit_done) begin
                    if (eop_detected)
                        next_state = STOP;
                    else
                        next_state = ERR;
                end else if (eop_detected) begin
                    next_state = STOP;
                end
            end
            ERR: begin
                next_state = IDLE;
            end
            DATA_ERR: begin
                next_state = EOP;
            end
            STOP: begin
                next_state = IDLE;
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        count_enable_timer = 0;
        rx_data_ready = '0;
        rx_transfer_active = '0;
        rx_error = '0;
        store_rx_packet_data = '0;
        rx_packet_data = '0;
        //enable3 = '0;
        enable5 = '0;
        enable4 = '0;
        enable7 = '0;
        enable8 = '0;
        clear_timer = '0;
        flush = '0;
        

        case(state)
            IDLE: begin
                count_enable_timer = 0;
                rx_data_ready = '0;
                rx_transfer_active = '0;
                rx_error = '0;
                store_rx_packet_data = '0;
                clear_timer = 0;

            end
            SYNC: begin
                enable8 = 1;
                count_enable_timer = 1;
                rx_transfer_active = 1;
            end
            CHECK_SYNC: begin
                enable8 = 0;
                count_enable_timer = 1;
                clear_timer = 1;

            end

            
            PID: begin
                count_enable_timer = 1;
                rx_transfer_active = 1;
                clear_timer = 0;
                enable8 = 1;
            end
            CHECK_PID: begin
                enable8 = 0;
                count_enable_timer = 1;
                clear_timer = 0;
                if (((out0 == 8'b1100_0011) || (out0 == 8'b0100_1011)))begin //DATA
                    flush = 1;
                end
            end
            TOKEN: begin
                count_enable_timer = 1;
                enable7 = 1;
                rx_transfer_active = 1;
            end
            CHECK_TOKEN: begin
                enable7 = 0;
                count_enable_timer = 1;
                clear_timer = 0;
            end
            ENDP: begin
                count_enable_timer = 1;
                rx_transfer_active = 1;
                enable4 = 1;
            end
            CHECK_ENDP: begin
                count_enable_timer = 1;
                clear_timer = 0;
                enable4 = 0;
            end
            LOAD_DATA: begin
                count_enable_timer = 1;
                rx_transfer_active = 1;
                enable8 = 1;
        
            end
            CHECK_DATA: begin
                count_enable_timer = 1;
                clear_timer = 0;
                store_rx_packet_data = 1;
                rx_packet_data = out3;
                rx_transfer_active = 1;
                enable8 = 0;
            end
            CRC5: begin
                count_enable_timer = 1;
                enable5 = 1;
                rx_transfer_active = 1;

            end
            CRC16: begin
                count_enable_timer = 0;
                rx_transfer_active = 1;
                enable8 = 1;
            end
            EOP: begin
                enable4 = 1;
                count_enable_timer = 1;
                rx_transfer_active = 1;
            end
            ERR: begin
                count_enable_timer = 1;
                rx_transfer_active = 0;
                rx_error = 1'b1;
                clear_timer = 1;
            end
            STOP: begin
                count_enable_timer = 1;
                rx_transfer_active = 0;
                rx_data_ready = 1;
                //clear_timer = 1;

            end

            DATA_ERR: begin
                count_enable_timer = 1;
                rx_transfer_active = 0;
                rx_error = 1'b1;
                //flush = 1;
            end
            default: begin
                count_enable_timer = '0;
                rx_data_ready = '0;
                rx_transfer_active = '0;
                rx_error = '0;
                store_rx_packet_data = '0;
                rx_packet_data = '0;
                enable5 = '0;
                enable4 = '0;
                enable7 = '0;
                flush = '0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge n_rst) begin : HOLD_RXXX 
        if (!n_rst) begin
            hold_rx_pack <= '0;
        end else begin
            hold_rx_pack <= n_hold_rx_pack;
        end
    end

    always_comb begin : RX_PACK
        n_hold_rx_pack = hold_rx_pack;
        //hold_rx_pack = hold_rx_pack;
        if (state == PID && eight_bit_done) begin
            if (out0 == 8'b1110_0001) //OUT
                n_hold_rx_pack = 3'b001;
            else if (out0 == 8'b0110_1001) //IN
                n_hold_rx_pack = 3'b010;
            else if (out0 == 8'b1100_0011) //DATA0
                n_hold_rx_pack = 3'b011;
            else if (out0 == 8'b0100_1011) //DATA1
                n_hold_rx_pack = 3'b100;
            else if (out0 == 8'b1101_0010) //ACK
                n_hold_rx_pack = 3'b101;
            else
                n_hold_rx_pack = 3'b000;
        end else if (state == PID) begin
            n_hold_rx_pack = '0;
        end
    end

    always_comb begin : SEND_RX_PACK
        //rx_packet = rx_packet;
        if (state == STOP || state == IDLE) begin
            rx_packet = hold_rx_pack;

        end else begin
            rx_packet = '0;
        end
    end






endmodule
