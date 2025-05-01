`timescale 1ns / 1ps
module rsi_inc #(
    parameter WINDOW = 14,   // The size of the price window (FIFO size now 14)
    parameter DW = 16        // Price width (e.g., 16-bit price)
)(
    input wire             clk,
    input wire             rst,
    input wire             new_price_strobe, // New price strobe signal
    input wire [DW-1:0]    new_price,        // New price data
    input wire [DW-1:0]    oldest_price,     // Oldest price in FIFO
    input wire             mem_full,         // Flag when FIFO is full
    input wire [4:0]       mem_count,         // Current count of prices in FIFO
    output reg  [7:0]      rsi,              // RSI value
    output reg             done              // Done signal for FSM
);

    reg [31:0] gain_sum = 0; // Accumulator for gains
    reg [31:0] loss_sum = 0; // Accumulator for losses
    reg [DW-1:0] prev_price = 0; // Previous price for comparison
    reg first_sample = 1;  // Flag to indicate the first sample (first price)

    reg [31:0] gain, loss, total;  // Temporary registers for RSI calculation

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all registers on reset signal
            gain_sum     <= 0;
            loss_sum     <= 0;
            rsi          <= 0;
            prev_price   <= 0;
            done         <= 0;
            first_sample <= 1;
        end else begin
            done <= 0;  // Default to not done

            // Process only when new price strobe is active and we have enough data (mem_count >= 14)
            if (new_price_strobe && mem_count >= 14) begin
                if (first_sample) begin
                    // Initialize prev_price on the first sample
                    prev_price <= new_price;
                    first_sample <= 0;
                end else begin
                    // Calculate gain or loss based on price change
                    if (new_price > prev_price) begin
                        gain_sum <= gain_sum + (new_price - prev_price);
                    end else if (new_price < prev_price) begin
                        loss_sum <= loss_sum + (prev_price - new_price);
                    end
                    // If prices are equal, do nothing to gain/loss

                    prev_price <= new_price;  // Update prev_price

                    // Assign unsigned gain and loss to temporary variables
                    gain  = gain_sum;
                    loss  = loss_sum;
                    total = gain + loss;

                    // Only calculate RSI if total is non-zero
                    if (total != 0) begin
                        rsi <= (100 * gain) / total;  // RSI calculation: 100 * gain / total
                    end else begin
                        rsi <= 0;  // If total is 0, set RSI to 0 to avoid division by zero
                    end

                    done <= 1;  // Indicate completion of RSI calculation
                end
            end
        end
    end
endmodule
