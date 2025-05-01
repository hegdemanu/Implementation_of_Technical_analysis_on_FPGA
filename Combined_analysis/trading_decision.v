// ==========================================================================
// trading_decision.v
// Simple rule: BUY when price>MA & RSI<30, SELL when price<MA & RSI>70
// ==========================================================================
`timescale 1ns/1ps
module trading_decision #(
    parameter BUY_RSI_THR  = 8'd30,
    parameter SELL_RSI_THR = 8'd70
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] price_now,
    input  wire [31:0] moving_avg,
    input  wire  [7:0] rsi,
    output reg         buy,
    output reg         sell
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buy  <= 0;
            sell <= 0;
        end else begin
            buy  <= (price_now > moving_avg[15:0]) && (rsi < BUY_RSI_THR);
            sell <= (price_now < moving_avg[15:0]) && (rsi > SELL_RSI_THR);
        end
    end
endmodule

