`timescale 1ns / 1ps
module price_memory #(
    parameter DEPTH = 14,    // Depth of the FIFO (only 14 prices now)
    parameter DW = 16        // Data width (price width)
)(
    input wire clk,             // Clock signal
    input wire rst,             // Reset signal
    input wire wr_en,           // Write enable
    input wire [DW-1:0] new_price,  // New price input
    output wire [DW-1:0] oldest_price, // Oldest price
    output wire full,           // FIFO full flag
    output wire [4:0] count     // FIFO count
);

    reg [DW-1:0] mem [0:DEPTH-1];  // FIFO memory array
    reg [4:0] write_ptr = 0;        // Write pointer
    reg [4:0] read_ptr = 0;         // Read pointer
    reg [5:0] item_count = 0;       // Item count in FIFO (0 to DEPTH)

    assign full = (item_count == DEPTH);   // FIFO is full when item_count == DEPTH
    assign count = item_count;             // Output current item count
    assign oldest_price = mem[read_ptr];   // Oldest price is at read_ptr

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr <= 0;
            read_ptr <= 0;
            item_count <= 0;
        end else if (wr_en) begin
            if (item_count < DEPTH) begin
                // If FIFO is not full, write to memory and increment item_count
                mem[write_ptr] <= new_price;
                write_ptr <= (write_ptr + 1) % DEPTH;  // Circular write pointer
                item_count <= item_count + 1;          // Increment item count
            end else begin
                // FIFO is full, overwrite the oldest price
                mem[write_ptr] <= new_price;
                write_ptr <= (write_ptr + 1) % DEPTH;  // Circular write pointer
                read_ptr <= (read_ptr + 1) % DEPTH;   // Circular read pointer (overwrite oldest)
            end
        end
    end

endmodule
