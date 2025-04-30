`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.02.2025 00:24:10
// Design Name: 
// Module Name: moving_average_fsm
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


module moving_average_fsm (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] new_price,
    input wire [31:0] oldest_price, 
    output reg [31:0] moving_avg,
    output reg done
);

    reg [63:0] sum;  // 64-bit sum for precision
    reg [7:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum <= 0;
            moving_avg <= 0;
            done <= 0;
            state <= 0;
        end else begin
            case (state)
                0: begin
                    if (start) begin
                        state <= 1;
                    end
                end

                1: begin
                    sum <= sum + new_price - oldest_price;  // ? Rolling Sum Update
                    moving_avg <= sum / 10;  // ? Compute moving average
                    done <= 1;
                    state <= 2;
                end

                2: begin
                    done <= 0;
                    state <= 0;  // Reset FSM for next calculation
                end
            endcase
        end
    end
endmodule





