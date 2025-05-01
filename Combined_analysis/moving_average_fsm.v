`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.04.2025 17:46:23
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


// ==========================================================================
// moving_average_fsm.v
// 20-period rolling mean (integer division)
// ==========================================================================

`timescale 1ns/1ps
module moving_average_fsm #(
    parameter WINDOW = 20,
    parameter DW     = 16
)(
    input  wire           clk,
    input  wire           rst,
    input  wire           start,
    input  wire [DW-1:0]  new_price,
    input  wire [DW-1:0]  oldest_price,
    output reg  [31:0]    moving_avg,
    output reg            done
);
    reg [63:0] sum = 0;
    reg [1:0]  st = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum <= 0; moving_avg <= 0; done <= 0; st <= 0;
        end else begin
            case (st)
                0: if (start) st <= 1;
                1: begin
                    sum <= sum + new_price - oldest_price;
                    moving_avg <= sum / WINDOW;
                    done <= 1;
                    st <= 2;
                end
                2: begin
                    done <= 0;
                    st <= 0;
                end
            endcase
        end
    end
endmodule


