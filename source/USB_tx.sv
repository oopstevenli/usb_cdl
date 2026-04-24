`timescale 1ns / 10ps

module USB_tx (
    input logic clk, n_rst,
    input logic [6:0] buffer_occupancy,
    input logic [7:0] tx_packet_data,
    input logic [2:0] tx_packet,
    output logic get_tx_packet_data, tx_transfer_active, tx_error, DP_OUT, DM_OUT
);

enum logic [3:0] {IDLE, LOAD_SYNC, SEND_SYNC, LOAD_PID, SEND_PID, GET_DATA, LOAD_DATA, SEND_DATA, LOAD_CRC, SEND_CRC, SEND_EOP, ERROR} state, next_state;
typedef enum logic [2:0] {DATA0=1, DATA1=2, ACK=3, NAK=4, STALL=5} packet_type;
packet_type packet;
assign packet = packet_type'(tx_packet);
logic rollover_flag_t, rollover_flag_c;
logic [3:0] rollover_val_t;
logic shift_enable, load_enable, serial_out, shift_enable_crc, load_enable_crc, serial_out_crc;
logic [7:0] parallel_in;
logic [2:0] ones_ct, ones_ct_next;
logic [4:0] bit_num, bit_num_next;
logic DP_OUT_next, DM_OUT_next;
logic crc_enable, data_bit;
logic [7:0] pid_val;
logic [15:0] poly, crc_out, crc, crc_next;
logic [1:0] eop_ct_next, eop_ct;

//pidval logic
always_comb begin
    case(tx_packet)
        DATA0: pid_val=8'b11000011; //0011
        DATA1: pid_val=8'b01001011; //1011
        ACK: pid_val=8'b11010010; //0010
        NAK: pid_val=8'b01011010; //1010
        STALL: pid_val=8'b00011110; //1110
        default: pid_val='0;
    endcase
end

//set up timers and pts
assign rollover_val_t=4'b1000 + {3'b0, rollover_flag_c};
flex_counter #(.SIZE(2)) cycles (.clk(clk), .n_rst(n_rst), .clear(1'b0), .count_enable(rollover_flag_t), .rollover_val(2'b11), 
.rollover_flag(rollover_flag_c), .count_out());
flex_counter #(.SIZE(4)) timer (.clk(clk), .n_rst(n_rst), .clear(1'b0), .count_enable(1'b1), .rollover_val(rollover_val_t), 
.rollover_flag(rollover_flag_t), .count_out());

assign shift_enable=rollover_flag_t && (ones_ct<6);
assign shift_enable_crc=rollover_flag_t && (ones_ct<6);
flex_sr #(.SIZE(8), .MSB_FIRST(0)) pts_shift (.clk(clk), .n_rst(n_rst), .shift_enable(shift_enable), .load_enable(load_enable), 
.serial_in(1'b0), .parallel_in(parallel_in), .serial_out(serial_out), .parallel_out());
flex_sr #(.SIZE(16), .MSB_FIRST(0)) crc_shift (.clk(clk), .n_rst(n_rst), .shift_enable(shift_enable_crc), .load_enable(load_enable_crc), 
.serial_in(1'b0), .parallel_in(crc_out), .serial_out(serial_out_crc), .parallel_out());

//next state logic
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        state<=IDLE;
        DP_OUT<=1;
        DM_OUT<=0;
        ones_ct<=0;
        bit_num<=0;
        eop_ct<=0;
    end
    else begin
        state<=next_state;
        DP_OUT<=DP_OUT_next;
        DM_OUT<=DM_OUT_next;
        ones_ct<=ones_ct_next;
        bit_num<=bit_num_next;
        eop_ct<=eop_ct_next;
    end
end

//encoding logic
always_comb begin
    DP_OUT_next=DP_OUT;
    DM_OUT_next=DM_OUT;
    ones_ct_next=0;
    bit_num_next=0;
    eop_ct_next=0;

    if(state==SEND_EOP && rollover_flag_t) begin
        if(eop_ct<2) begin
            DP_OUT_next=0;
            DM_OUT_next=0;
            eop_ct_next=eop_ct+1;
        end
        else begin
            DP_OUT_next=1;
            DM_OUT_next=0;
            eop_ct_next=3;
        end
    end
    else if(rollover_flag_t && (state==SEND_PID || state==SEND_DATA ||state==SEND_CRC || state==SEND_SYNC)) begin
        if(ones_ct==6) begin
            ones_ct_next=0;
            DP_OUT_next=!DP_OUT;
            DM_OUT_next=!DM_OUT;
            bit_num_next=bit_num;
        end
        else begin
            if(!data_bit) begin
                DP_OUT_next=!DP_OUT;
                DM_OUT_next=!DM_OUT;
                ones_ct_next=0;
            end
            else begin
                DP_OUT_next=DP_OUT;
                DM_OUT_next=DM_OUT;
                ones_ct_next=ones_ct+1;
            end
            bit_num_next=bit_num+1;
        end
    end
    else if(state==SEND_PID || state==SEND_DATA ||state==SEND_CRC || state==SEND_EOP || state==SEND_SYNC) begin
        ones_ct_next=ones_ct;
        bit_num_next=bit_num;
        eop_ct_next=eop_ct;
    end
    else if(state==LOAD_DATA) begin
        ones_ct_next=ones_ct;
    end
end

//crc logic
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        crc<='0;
        crc_out<='0;
    end
    else if(state==SEND_DATA || state==LOAD_DATA || state==GET_DATA) begin
        crc<=crc_next;
        crc_out<=~(crc_next);
    end
    else begin

        crc<=16'hffff;
        crc_out<=~(16'hffff);
    end
end
always_comb begin//looped over send data
    poly=16'b1010000000000001;
    if(crc_enable && ones_ct!=6) begin
        if(data_bit ^ crc[0]) begin
            crc_next= {1'b0, crc[15:1]} ^ poly;
        end
        else begin
            crc_next= {1'b0, crc[15:1]};
        end
    end
    else if(state==SEND_DATA || state==LOAD_DATA || state==GET_DATA) begin
        crc_next=crc;
    end
    else begin
        crc_next=16'hffff;
    end
end

//next state logic
always_comb begin
    case(state)
        IDLE: begin
            tx_error=0;
            tx_transfer_active=0;
            load_enable=0;
            parallel_in='0;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit=0;
            if(tx_packet<6 && tx_packet>0) begin
                next_state=LOAD_SYNC;
            end
            else begin
                next_state=IDLE;
            end
        end

        LOAD_SYNC: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=1;
            parallel_in=8'b10000000;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit=serial_out;
            next_state=SEND_SYNC;
        end

        SEND_SYNC: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=0;
            parallel_in=8'b1000_0000;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit=serial_out;
            if(bit_num<8) begin
                next_state=SEND_SYNC;
            end
            else begin
                next_state=LOAD_PID;
            end
        end

        LOAD_PID: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=1;
            parallel_in=pid_val;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit=serial_out;
            next_state=SEND_PID;
        end

        SEND_PID: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=0;
            parallel_in=pid_val;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit=serial_out;
            if(bit_num<8) begin
                next_state=SEND_PID;
            end
            else begin
                if(packet==DATA0 || packet==DATA1) begin
                    next_state=GET_DATA;
                end
                else begin
                    next_state=SEND_EOP;
                end
            end
        end

        GET_DATA: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=0;
            parallel_in=tx_packet_data;
            crc_enable=0;
            get_tx_packet_data=1;
            load_enable_crc=0;
            data_bit=serial_out;
            if(buffer_occupancy==0) begin
                next_state=ERROR;
            end
            else begin
                next_state=LOAD_DATA;
            end
        end

        LOAD_DATA: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=1;
            parallel_in=tx_packet_data;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit=serial_out;
            next_state=SEND_DATA;
        end

        SEND_DATA: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=0;
            parallel_in=tx_packet_data;
            crc_enable=rollover_flag_t;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit= serial_out;
            if(bit_num<8) begin
                next_state=SEND_DATA;
            end
            else begin
                if(buffer_occupancy==0) begin
                    next_state=LOAD_CRC;
                end
                else begin
                    next_state=GET_DATA;
                end
            end
        end

        LOAD_CRC: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=0;
            parallel_in='0;
            crc_enable=0;
            load_enable_crc=1;
            get_tx_packet_data=0;
            data_bit= serial_out_crc;
            next_state=SEND_CRC;
        end

        SEND_CRC: begin
            tx_error=0;
            tx_transfer_active=1;
            load_enable=0;
            parallel_in='0;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit= serial_out_crc;
            if(bit_num<16) begin
                next_state=SEND_CRC;
            end
            else begin
                next_state=SEND_EOP;
            end
        end


        SEND_EOP: begin
            tx_error=0;
            tx_transfer_active=0;
            load_enable=0;
            parallel_in='0;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit= 0;
            if(eop_ct<3) begin
                next_state=SEND_EOP;
            end
            else begin
                next_state=IDLE;
            end
        end

        ERROR: begin
            tx_error=1;
            tx_transfer_active=0;
            load_enable=0;
            parallel_in='0;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit= 0;
            next_state=IDLE;
        end
        default: begin
            tx_error=0;
            tx_transfer_active=0;
            load_enable=0;
            parallel_in='0;
            crc_enable=0;
            get_tx_packet_data=0;
            load_enable_crc=0;
            data_bit= 0;
            next_state=IDLE;
        end
    endcase
end
            

endmodule

