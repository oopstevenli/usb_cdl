`timescale 1ns / 10ps

module flex_sr #(
    parameter SIZE = 8, //Number of bits stored by shift register
    parameter MSB_FIRST = 0 //logic switch for whether data si shifted out MSB direction (left), default is 0 (right)
) (
    input logic clk, //system clock
    input logic n_rst, //async active low system reset, FFs/registers reset to logic 1
    input logic shift_enable, //active high enable signal that allows shift register to shift in the value of the serial_in signal
    input logic load_enable, //Active-high enable signal that allows the shift register to load the value of the parallel_in bus to all SR bits simultaneously.
    input logic serial_in, //	Serial input signal to be shifted into the register. Default/idle value is logic 1, as used in serial communications.
    input logic [SIZE - 1: 0] parallel_in, //Data to be loaded into the shift register. Width depends on the SIZE parameter.
    output logic serial_out, //Serial output signal representing the value being transmitted from the shift register.
    output logic [SIZE - 1:0] parallel_out //Data currently held in the shift register. Width depends on the SIZE parameter.
);
    logic [SIZE -1:0] state, next_state;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            state <= '1;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state; //default case

        if (load_enable) begin //Load enable has higher priority
            next_state = parallel_in;
        end 
        else if (shift_enable) begin
            if (MSB_FIRST) begin
                next_state = {state[SIZE - 2:0], serial_in};
                
            end else begin
                next_state = {serial_in, state[SIZE - 1:1]};
            end
        end
    end

    assign parallel_out = state;
    assign serial_out = MSB_FIRST ? state[SIZE - 1] : state[0];


endmodule

