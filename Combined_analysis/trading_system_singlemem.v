`timescale 1ns / 1ps
module trading_system_singlemem (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] price_in,
    input  wire        new_price,
    output wire [31:0] moving_avg,
    output wire  [7:0] rsi,
    output wire        buy,
    output wire        sell,
    output wire        mem_full,
    output wire [4:0]  mem_cnt,
    output wire [15:0] oldest_price,
    output wire        ma_done,
    output wire        rsi_done
);

    wire [4:0] count;

    // Use the updated circular FIFO memory
    price_memory mem14 (
        .clk(clk),
        .rst(rst),
        .wr_en(new_price),
        .new_price(price_in),
        .oldest_price(oldest_price),
        .full(mem_full),
        .count(count)
    );

    assign mem_cnt = count;

    // Trigger MA and RSI only after memory is full (i.e., 14 prices stored)
    wire compute_enable = (mem_cnt == 14);

    // Moving Average FSM
    moving_average_fsm ma14 (
        .clk(clk),
        .rst(rst),
        .start(compute_enable),
        .new_price(price_in),
        .oldest_price(oldest_price),
        .moving_avg(moving_avg),
        .done(ma_done)
    );

    // RSI Incremental FSM
    rsi_inc rsi14 (
        .clk(clk),
        .rst(rst),
        .new_price_strobe(compute_enable),
        .new_price(price_in),
        .oldest_price(oldest_price),
        .mem_full(mem_full),
        .rsi(rsi),
        .done(rsi_done)
    );

    // Trading decision logic
    trading_decision dec (
        .clk(clk),
        .rst(rst),
        .price_now(price_in),
        .moving_avg(moving_avg),
        .rsi(rsi),
        .buy(buy),
        .sell(sell)
    );

endmodule
