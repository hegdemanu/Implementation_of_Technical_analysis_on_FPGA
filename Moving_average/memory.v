`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.02.2025 23:04:52
// Design Name: 
// Module Name: memory
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

module memory (
    input wire clk,
    input wire rst,
    input wire [31:0] new_price,  // Incoming new price
    input wire write_enable,      // Enables writing to memory
    output reg [31:0] oldest_price, // Provides the oldest price for rolling sum
    output wire memory_full,      // Becomes HIGH when FIFO is full
    output reg [319:0] prices_flat, // Flattened 10-price array
    output reg [3:0] fifo_data_count // Tracks number of stored prices
);

    reg [31:0] prices[9:0]; // FIFO Memory (only 10 prices)
    integer i;
    
    assign memory_full = (fifo_data_count >= 10);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 10; i = i + 1) begin
                prices[i] <= 0;
            end
            fifo_data_count <= 0;
            oldest_price <= 0;
        end else if (write_enable) begin
            // FIFO Shift: Remove oldest price, add new price
            oldest_price <= prices[0];  
            for (i = 0; i < 9; i = i + 1) begin
                prices[i] <= prices[i + 1];
            end
            prices[9] <= new_price;

            // Flattened Array for Debugging
            for (i = 0; i < 10; i = i + 1) begin
                prices_flat[i * 32 +: 32] <= prices[i];
            end

            // Update FIFO Count
            if (fifo_data_count < 10)
                fifo_data_count <= fifo_data_count + 1;
        end
    end

endmodule






