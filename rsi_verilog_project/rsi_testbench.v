`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.04.2025 18:04:27
// Design Name: 
// Module Name: rsi_testbench
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


module rsi_testbench;

    reg clk = 0, rst = 1, start = 0, new_price = 0;
    reg [15:0] price_in = 0;
    wire done;
    wire [7:0] rsi;

    rsi_fsm uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .price_in(price_in),
        .new_price(new_price),
        .done(done),
        .rsi(rsi)
    );

    always #5 clk = ~clk;

    integer i;
    reg [15:0] price_array[0:19];

    initial begin
        // Create pattern of rising and falling prices
        price_array[0] = 100;
        for (i = 1; i < 20; i = i + 1)
            price_array[i] = price_array[i - 1] + ((i % 2 == 0) ? 3 : -2);

        #20 rst = 0; #10 start = 1; #10 start = 0;

        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            price_in = price_array[i];
            new_price = 1;
            @(posedge clk);
            new_price = 0;
        end

        wait (done);
        $display("RSI Value = %d", rsi);
        $finish;
    end

endmodule


