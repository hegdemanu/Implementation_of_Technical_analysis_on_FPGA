`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.02.2025 00:32:00
// Design Name: 
// Module Name: trading_system_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////









module trading_system_tb;

    reg clk;
    reg rst;
    reg write_enable;
    reg [31:0] new_price;
    wire [31:0] moving_avg;
    wire memory_full;
    wire [31:0] oldest_price;
    wire [3:0] fifo_data_count;
    wire [319:0] prices_flat;
    wire done;

    // Instantiate FIFO Memory (Now for 10 Prices)
    memory memory_inst (
        .clk(clk),
        .rst(rst),
        .write_enable(write_enable),
        .new_price(new_price),
        .oldest_price(oldest_price),
        .memory_full(memory_full),
        .prices_flat(prices_flat),
        .fifo_data_count(fifo_data_count)
    );

    // Instantiate Moving Average FSM
    moving_average_fsm ma_fsm (
        .clk(clk),
        .rst(rst),
        .start(memory_full),  // ? Start when FIFO is full
        .new_price(new_price),
        .oldest_price(oldest_price),
        .moving_avg(moving_avg),
        .done(done)
    );

    // Clock Generation
    always #5 clk = ~clk; // 10ns clock period

    integer i;
    reg [31:0] price_data [0:9]; // Store 10 test prices

    initial begin
        clk = 0;
        rst = 1;
        write_enable = 0;
        new_price = 0;

        // Reset system and wait
        #50 rst = 0;

        // Generate test prices (Example: 1000 to 1045)
        for (i = 0; i < 10; i = i + 1) begin
            price_data[i] = 1000 + (i * 5);
        end

        // ? New price arrives every 20ns
        for (i = 0; i < 10; i = i + 1) begin
            #10;  // ? Small delay before setting `write_enable`
            new_price = price_data[i];
            write_enable = 1;
            #10;  // ? New price every 20ns
            write_enable = 0;
            #10;
        end

        // ? Keep simulation running until FIFO is full
        wait(fifo_data_count == 10);
        #200;  // ? Wait additional time for moving average computation

        // ? Stop simulation after confirming updates
        $display("Final Check -> Time: %0t | FIFO Count: %d | Memory Full: %b | Moving Avg: %d",
                 $time, fifo_data_count, memory_full, moving_avg);
        $finish;
    end

endmodule





