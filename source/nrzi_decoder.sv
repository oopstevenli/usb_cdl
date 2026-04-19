`timescale 1ns / 10ps

module nrzi_decoder (
   input logic clk, n_rst,
   input logic dp, dm,
   input logic shift_strobe,
   output logic d_orig,
   output logic edge_detected,
   output logic eop_detected
);

    typedef enum logic [1:0] {
        S0 = 2'b00,
        S1 = 2'b01,
        S2 = 2'b10,
        S3 = 2'b11
    } state_t;

    state_t state, next_state;
    logic dp_q, dm_q;
    logic next_dorig;
    logic edge_state, n_edge_state;

    logic eop1, eop2, eop3;
    logic n_eop1, n_eop2, n_eop3;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            dp_q <= 1'b1;
            dm_q <= 1'b0;
        end else begin
            dp_q <= dp;
            dm_q <= dm;
        end
    end

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            state <= S2;
        end else begin
            state <= next_state;
        end
    end



    always_comb begin
        next_state = state_t'({dp_q, dm_q});
    end

    assign edge_detected = ((dp != dp_q) || (dm != dm_q));

    always_comb begin
        //next_dorig = d_orig; //default
        
        //if (shift_strobe) begin
            /*if (shift_strobe) begin
                if (edge_state)
                    next_dorig = '0;
                else    
                    next_dorig = 1'b1;
            end else */if (edge_detected || edge_state) begin
                d_orig = '0;
            end else begin
                d_orig = 1'b1;
            end
        //end
        
    end

    always_ff @(posedge clk or negedge n_rst) begin : ED
        if (!n_rst) begin
            edge_state <= '0;
        end else begin
            edge_state <= n_edge_state;
        end
    end

    always_comb begin
        n_edge_state = edge_state;
        if (edge_detected)
            n_edge_state = 1;
        else if (shift_strobe)
            n_edge_state = 0;
    end

    /*always_ff @(posedge clk or negedge n_rst) begin : DORIG
        if (!n_rst) begin
            d_orig <= 1'b1;
        end else begin
            d_orig <= next_dorig;
        end
    end*/

    always_ff @(posedge clk or negedge n_rst) begin : EOP
        if (!n_rst) begin
            eop1 <= 1'b1;
            eop2 <= 1'b1;
            eop3 <= 1'b1;
        end else begin
            eop1 <= n_eop1;
            eop2 <= n_eop2;
            eop3 <= n_eop3;

        end
    end

    always_comb begin : HOLD_EOP
        n_eop1 = eop1;
        n_eop2 = eop2;
        n_eop3 = eop3;

        if (shift_strobe) begin
            n_eop1 = !(state == S0);
            n_eop2 = eop1;
            n_eop3 = eop2;
        end
    end

    assign eop_detected = (~(eop3 | eop2)) & (state == S2);


    


endmodule
