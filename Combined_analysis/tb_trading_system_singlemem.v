module tb_trading_system_singlemem;

    reg clk = 0;
    reg rst = 1;
    reg [15:0] price_in = 0;
    reg new_price = 0;

    wire [31:0] moving_avg;
    wire [7:0] rsi;
    wire buy, sell;
    wire mem_full;
    wire [4:0] mem_cnt;
    wire [15:0] oldest_price;
    wire ma_done, rsi_done;

    // DUT (Device Under Test)
    trading_system_singlemem dut (
        .clk(clk), .rst(rst),
        .price_in(price_in), .new_price(new_price),
        .moving_avg(moving_avg), .rsi(rsi),
        .buy(buy), .sell(sell),
        .mem_full(mem_full),
        .mem_cnt(mem_cnt),
        .oldest_price(oldest_price),
        .ma_done(ma_done),
        .rsi_done(rsi_done)
    );

    always #5 clk = ~clk;  // Clock toggle every 5ns

    reg [15:0] prices [0:13];  // Array of 14 prices
    initial begin
        prices[ 0] = 16'd10234; prices[ 1] = 16'd10380;
        prices[ 2] = 16'd10125; prices[ 3] = 16'd10490;
        prices[ 4] = 16'd10510; prices[ 5] = 16'd10420;
        prices[ 6] = 16'd10650; prices[ 7] = 16'd10790;
        prices[ 8] = 16'd10680; prices[ 9] = 16'd10830;
        prices[10] = 16'd10920; prices[11] = 16'd10810;
        prices[12] = 16'd10750; prices[13] = 16'd11060;
    end

    integer index = 0;

    // Feed prices: one per clock, continuously
    always @(posedge clk) begin
        if (rst) begin
            index <= 0;
            new_price <= 0;
        end else begin
            if (index < 14) begin
                price_in <= prices[index];
                new_price <= 1;  // Feed new price into the system
                index <= index + 1;
            end else begin
                new_price <= 0;  // No more new prices
            end
        end
    end

    initial begin
        repeat (5) @(posedge clk);  // Wait for some time for the clock to stabilize
        rst = 0;  // Deassert reset

        // Check for mem_count update and confirm FIFO size
        wait (mem_cnt == 14);  // Wait until 14 prices are in memory
        $display("? SUCCESS: FIFO memory filled with 14 prices.");

        #2000 $finish;  // End simulation
    end

    initial begin
        $dumpfile("trading_system.vcd");
        $dumpvars(0, tb_trading_system_singlemem);
        $display("Time | Price | MA | RSI | BUY | SELL");
        $monitor("%4t | %d | %d | %d | %b | %b",
                 $time, price_in, moving_avg, rsi, buy, sell);
    end

endmodule
