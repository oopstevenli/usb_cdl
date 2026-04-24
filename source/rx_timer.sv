`timescale 1ns / 10ps

module rx_timer #(
    // parameters
) (
    input logic clk, n_rst,
    //input logic clear_cycle,
    input logic clear_timer,
    input logic count_enable_timer,
    input logic enable4, enable5, enable7, enable3, enable8,
    output logic shift_strobe,
    output logic eight_bit_done,
    output logic seven_bit_done,
    output logic four_bit_done,
    output logic five_bit_done,
    output logic three_bit_done
);  
    logic [3:0] rollover_val_t;
    logic rollover_flag_timer;
    //logic rollover_flag_cycle;

    //assign rollover_val_t = 4'd8 + {3'b0, rollover_flag_cycle};

    /*flex_counter #(.SIZE(2)) cycle (
        .clk(clk),
        .n_rst(n_rst),
        .clear(eight_bit_done),
        .count_enable(rollover_flag_timer),
        .rollover_val(2'd3),
        .count_out(),
        .rollover_flag(rollover_flag_cycle)
    );*/

    logic [1:0] phase, n_phase;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            phase <= '0;
        end else begin
            phase <= n_phase;
        end
    end

    always_comb begin
        n_phase = phase;
        if (rollover_flag_timer) begin
            if (phase >= 2'd2) begin
                n_phase = '0;
            end else begin
                n_phase = phase + 1;
            end
        end
    end

    always_comb begin 
        case(phase)
            2'd0: rollover_val_t = 4'd8;
            2'd1: rollover_val_t = 4'd8;
            2'd2: rollover_val_t = 4'd9;
            default: rollover_val_t = 4'd8;
        endcase
    end

    flex_counter #(.SIZE(4)) timer (
        .clk(clk),
        .n_rst(n_rst),
        .clear(clear_timer),
        .count_enable(count_enable_timer),
        .rollover_val(rollover_val_t),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .rollover_flag(rollover_flag_timer)

    );

    assign shift_strobe = rollover_flag_timer;

    flex_counter #(.SIZE(4)) bit_counter_8 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(eight_bit_done | !count_enable_timer),
        .count_enable(shift_strobe & enable8),
        .rollover_val(4'd8),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .rollover_flag(eight_bit_done)
    );

    flex_counter #(.SIZE(4)) bit_counter_7 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(seven_bit_done | !count_enable_timer),
        .count_enable(shift_strobe & enable7),
        .rollover_val(4'd7),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .rollover_flag(seven_bit_done)
    );

    flex_counter #(.SIZE(4)) bit_counter_4 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(four_bit_done | !count_enable_timer),
        .count_enable(shift_strobe & enable4),
        .rollover_val(4'd4),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .rollover_flag(four_bit_done)
    );

    flex_counter #(.SIZE(4)) bit_counter_5 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(five_bit_done | !count_enable_timer),
        .count_enable(shift_strobe & enable5),
        .rollover_val(4'd5),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .rollover_flag(five_bit_done)
    );

    flex_counter #(.SIZE(4)) bit_counter_3 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(three_bit_done | !count_enable_timer),
        .count_enable(shift_strobe & enable3),
        .rollover_val(4'd3),
        /* verilator lint_off PINCONNECTEMPTY */
        .count_out(),
        /* verilator lint_on PINCONNECTEMPTY */
        .rollover_flag(three_bit_done)
    );

    

endmodule
