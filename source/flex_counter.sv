`timescale 1ns / 10ps
/*
module flex_counter #(
    parameter SIZE = 8
) (
    input logic clk,
    input logic n_rst,
    input logic clear,
    input logic count_enable,
    input logic [SIZE - 1:0] rollover_val,
    output logic [SIZE - 1:0] count_out,
    output logic rollover_flag
);

    logic [SIZE - 1:0] state, next_state;
    logic rollover_state, rollover_nstate;

    always_ff @(posedge clk or negedge n_rst) begin
        if (~n_rst) begin
            state <= '0;
            rollover_state <= 1'b0;
        end else begin
            state <= next_state;
            rollover_state <= rollover_nstate;
        end
    end

    always_comb begin
        next_state = state;
        //rollover_nstate = 1'b0;
        if (clear) begin
            next_state = '0;
            //rollover_nstate = 1'b0;
        end else if (count_enable) begin
            if (state >= (rollover_val)) begin
                next_state = {{(SIZE- 1){1'b0}},1'b1};
                //rollover_nstate = 1'b1;
            end else begin
                next_state = state + 1'b1;
                //rollover_nstate = 1'b0;
            end
        end 

        if (next_state >= rollover_val) begin //due to the delay of the FF the flag will have to be predicted one cycle early. Create a second next state logic block to generate this predictive flag, and update your RTL diagram to include the necessary components to optimize the counter.
            rollover_nstate = 1'b1;
        end else begin
            rollover_nstate = 1'b0;
        end
        //if ()
    end

    assign count_out = state;
    assign rollover_flag = rollover_state;

endmodule*/


module flex_counter #(
    parameter SIZE = 8 //Number of bits available to store the count
) (
    input logic clk, //sys clock
    input logic n_rst, //async active low sys reset, all registers/flipflops reset to initial val
    input logic clear, //active high signal that forces counter to synchronously clear its current count value to 0
    input logic count_enable, //active high enable signal that allows the counter to increment its internal value
    input logic [SIZE - 1:0] rollover_val, //value that is checked against for determining when to roll over, actual port declaration should use the SIZE value to determin val of #
    output logic [SIZE - 1:0] count_out, //current count value stored in the counter. The actual port declaration should use the SIZE parameter value to determine the value of #.
    output logic rollover_flag //active-high rollover flag and must be asserted when the counter is at the rollover value and cleared with the next increment
);

    logic [SIZE - 1:0] state, next_state;

    always_ff @(posedge clk or negedge n_rst) begin
        if (~n_rst) begin
            state <= '0;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        if (clear) begin //clear has higher priority
            next_state = '0;
        end else if (count_enable) begin
            next_state = state + 1'b1;
            if (state >= (rollover_val)) begin
                next_state = 'd1;
            end 
        end else begin
             next_state = state;
        end
    end

    always_comb begin
        if (state >= (rollover_val)) begin
            rollover_flag = 1'b1;
        end else begin
            rollover_flag = 0;
        end

    end

    assign count_out = state;
    //assign rollover_flag = (count_out >= rollover_flag);

endmodule

/*
counter is a more implicit type of state machine, keeping a count as its internal state. 
For a counter, we usually define the rules of its transitions rather than each state, 
as a state transition diagram would require a state for each number to be counted.
The most common use for a counter is as a timer. We count clock cycles and assert an output flag when the requisite number is reached. When this flag is used to enable a FF, that FF acts as if it is clocked by the flag, at a rate of 
f_clk/count
 This specific use case is called a clock divider. 
*/
