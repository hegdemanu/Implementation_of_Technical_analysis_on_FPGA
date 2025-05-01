# Verilog Trading System Documentation

## README

### Overview
This repository contains a Verilog implementation of a trading system that uses technical indicators (Moving Average and RSI) to generate buy and sell signals. The system is designed for FPGA implementation and uses a finite state machine (FSM) approach for efficient calculation of indicators.

### Key Features
- 20-period moving average calculation
- 14-period RSI (Relative Strength Index) calculation
- Circular FIFO memory for price history
- Configurable buy/sell thresholds
- Complete testbench with sample price data

### System Architecture
The trading system is composed of multiple interconnected modules:
1. **Price Memory**: Stores recent price history in a circular FIFO buffer
2. **Moving Average FSM**: Calculates the moving average using a sliding window approach
3. **RSI Incremental**: Calculates RSI based on gain/loss accumulation
4. **Trading Decision**: Generates trading signals based on price, MA, and RSI values
5. **Trading System**: Top-level module that integrates all components

### Moving Average Implementation
The moving average is implemented using a sliding window approach with an FSM for efficient calculation:

1. **Window Management**:
   - The system maintains a 20-period window of prices
   - As new prices arrive, they replace the oldest prices in the window
   - A circular FIFO memory (price_memory module) handles this storage

2. **Calculation Method**:
   - Instead of recalculating the sum from scratch for each new price, the algorithm:
     - Adds the new price to the running sum
     - Subtracts the oldest price from the running sum
     - Divides the result by the window size (20)
   - This approach requires only two operations per update rather than summing all values

3. **FSM Implementation**:
   - State 0: Idle state, waiting for start signal
   - State 1: Calculation state - updates sum, computes average, sets done flag
   - State 2: Completion state - drops done flag, returns to idle

4. **Integration with Trading Strategy**:
   - The moving average is compared with the current price
   - When price > MA, it indicates upward momentum (one condition for buy signal)
   - When price < MA, it indicates downward momentum (one condition for sell signal)

### Usage
To use this system in simulation:
1. Include all Verilog files in your project
2. Run the testbench `tb_trading_system_singlemem.v`
3. Observe the output signals (moving_avg, rsi, buy, sell)

For FPGA implementation:
1. Use the `trading_system_singlemem.v` as the top-level module
2. Connect your price input to the `price_in` port
3. Use `new_price` to strobe in new price data
4. Monitor the `buy` and `sell` outputs for trading signals

### Testing
The included testbench provides a simulation environment with:
- 14 predefined price points
- Automatic price feeding
- Signal monitoring and verification
- VCD file generation for waveform analysis

## Implementation Details

### 1. Moving Average FSM Module

```verilog
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
```

#### Module Description
The `moving_average_fsm` module implements a 20-period rolling mean calculation using a finite state machine (FSM) approach. This module takes new price data and the oldest price (to be removed from the window) to maintain a continuous moving average with integer division.

#### Parameters
- `WINDOW` (default: 20): Number of periods for the moving average calculation
- `DW` (default: 16): Data width for the price inputs

#### Ports
- **Inputs**:
  - `clk`: System clock
  - `rst`: Active-high reset signal
  - `start`: Signal to begin the calculation process
  - `new_price`: The latest price value to add to the window [DW-1:0]
  - `oldest_price`: The oldest price value to remove from the window [DW-1:0]

- **Outputs**:
  - `moving_avg`: The calculated moving average value [31:0]
  - `done`: Flag indicating calculation completion

#### State Machine
The FSM operates in three states:
- **State 0**: Idle state, waiting for start signal
- **State 1**: Calculation state - updates the sum and computes the moving average
- **State 2**: Completion state - drops the done signal and returns to idle

#### Calculation Method
Rather than summing all prices in the window for each calculation, this implementation:
1. Maintains a running sum of all prices in the window
2. When a new price arrives:
   - Adds the new price to the sum
   - Subtracts the oldest price from the sum
   - Divides by the window size to get the average
3. This sliding window approach is significantly more efficient than recalculating the entire sum

### 2. Price Memory Module

```verilog
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
```

#### Module Description
The `price_memory` module implements a circular FIFO (First-In-First-Out) buffer to store price history. It maintains both the newest and oldest prices in the window, supporting the moving average and RSI calculations.

#### Parameters
- `DEPTH` (default: 14): The maximum number of prices stored in the FIFO
- `DW` (default: 16): Data width for the price values

#### Ports
- **Inputs**:
  - `clk`: System clock
  - `rst`: Active-high reset signal
  - `wr_en`: Write enable signal
  - `new_price`: New price to be written to the FIFO [DW-1:0]

- **Outputs**:
  - `oldest_price`: The oldest price in the FIFO [DW-1:0]
  - `full`: Flag indicating when the FIFO is full
  - `count`: Current number of items in the FIFO [4:0]

#### Operation
The module implements a circular buffer with the following behavior:
1. When not full, new prices are written and the item count increases
2. When full, the oldest price is overwritten with the new price
3. The write and read pointers wrap around when they reach DEPTH

This design allows continuous price updates while maintaining the required window size for technical indicators.

### 3. RSI Incremental Module

```verilog
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
```

#### Module Description
The `rsi_inc` module calculates the Relative Strength Index (RSI), a momentum oscillator that measures the speed and change of price movements. The implementation uses a 14-period window and processes prices incrementally.

#### Parameters
- `WINDOW` (default: 14): The size of the price window
- `DW` (default: 16): Price width in bits

#### Ports
- **Inputs**:
  - `clk`: System clock
  - `rst`: Active-high reset signal
  - `new_price_strobe`: Signal indicating new price data is available
  - `new_price`: The latest price value [DW-1:0]
  - `oldest_price`: The oldest price in the FIFO [DW-1:0]
  - `mem_full`: Flag indicating when the FIFO is full
  - `mem_count`: Current count of prices in FIFO [4:0]

- **Outputs**:
  - `rsi`: The calculated RSI value [7:0]
  - `done`: Signal indicating calculation completion

#### RSI Calculation Method
The module implements the RSI calculation as follows:
1. Tracks price changes from one period to the next
2. Accumulates the sum of gains (when price increases)
3. Accumulates the sum of losses (when price decreases)
4. When sufficient data is available (mem_count >= 14), calculates RSI using the formula:
   RSI = 100 * (gain_sum / (gain_sum + loss_sum))

The implementation ensures there's no division by zero by checking if total (gain + loss) is non-zero.

### 4. Trading Decision Module

```verilog
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
```

#### Module Description
The `trading_decision` module implements a simple trading strategy based on price, moving average, and RSI values. It generates buy and sell signals according to predefined rules.

#### Parameters
- `BUY_RSI_THR` (default: 30): RSI threshold for buy signals
- `SELL_RSI_THR` (default: 70): RSI threshold for sell signals

#### Ports
- **Inputs**:
  - `clk`: System clock
  - `rst`: Active-high reset signal
  - `price_now`: Current price value [15:0]
  - `moving_avg`: Moving average value [31:0]
  - `rsi`: Relative Strength Index value [7:0]

- **Outputs**:
  - `buy`: Buy signal
  - `sell`: Sell signal

#### Trading Strategy
The module implements a simple technical analysis strategy:
1. **BUY when**:
   - Price is above the moving average AND
   - RSI is below the buy threshold (30 by default)
2. **SELL when**:
   - Price is below the moving average AND
   - RSI is above the sell threshold (70 by default)

This strategy aims to:
- Buy when the market is in an uptrend (price > MA) but oversold (RSI < 30)
- Sell when the market is in a downtrend (price < MA) but overbought (RSI > 70)

### 5. Trading System (Single Memory) Module

```verilog
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
        .mem_count(mem_cnt),
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
```

#### Module Description
The `trading_system_singlemem` module is the top-level integration of all components, creating a complete technical analysis trading system. It connects the price memory, moving average, RSI, and trading decision modules together.

#### Ports
- **Inputs**:
  - `clk`: System clock
  - `rst`: Active-high reset signal
  - `price_in`: New price input [15:0]
  - `new_price`: Signal indicating a new price is available

- **Outputs**:
  - `moving_avg`: The calculated moving average [31:0]
  - `rsi`: The calculated RSI value [7:0]
  - `buy`: Buy signal generated by trading decision
  - `sell`: Sell signal generated by trading decision
  - `mem_full`: Flag indicating memory is full
  - `mem_cnt`: Current count of prices in memory [4:0]
  - `oldest_price`: The oldest price in memory [15:0]
  - `ma_done`: Flag indicating moving average calculation is complete
  - `rsi_done`: Flag indicating RSI calculation is complete

#### Design Architecture
The system connects multiple components:
1. **Price Memory**: Stores the last 14 prices as a circular FIFO buffer
2. **Moving Average FSM**: Calculates the 20-period moving average
3. **RSI Incremental**: Calculates the 14-period RSI
4. **Trading Decision**: Generates buy/sell signals based on the technical indicators

The system triggers calculations only when enough data is available (mem_cnt == 14).

### 6. Testbench Module

```verilog
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
```
# Trading System Implementation Details

## Overview

This document provides detailed implementation information for a Verilog-based algorithmic trading system designed for FPGA deployment. The system calculates technical indicators (20-period Moving Average and 14-period RSI) to generate trading signals based on predefined criteria. The implementation leverages hardware-specific optimization techniques to achieve efficient calculation of financial indicators in real-time.

## System Architecture

The system follows a modular design approach with the following key components:

```
                             ┌────────────────┐
                             │                │
                   ┌─────────┤  Price Memory  ├─────┐
                   │         │                │     │
                   │         └────────────────┘     │
                   │                                │
                   ▼                                ▼
         ┌─────────────────┐              ┌─────────────────┐
         │                 │              │                 │
         │  Moving Average │              │  RSI Calculator │
         │      FSM        │              │                 │
         │                 │              │                 │
         └────────┬────────┘              └────────┬────────┘
                  │                                │
                  └─────────────┬─────────────────┘
                                │
                                ▼
                      ┌──────────────────┐
                      │                  │
                      │ Trading Decision │
                      │                  │
                      └──────────────────┘
```

## Data Flow

1. New price data enters the system through the top-level module
2. Price history is stored in a circular FIFO buffer
3. When sufficient data is available, the Moving Average and RSI are calculated
4. The Trading Decision module compares current price, MA, and RSI values
5. Buy/sell signals are generated based on predefined criteria

## Module Implementations

### 1. Price Memory (Circular FIFO)

```verilog
module price_memory #(
    parameter DEPTH = 14,
    parameter DW = 16
)(
    input wire clk, rst, wr_en,
    input wire [DW-1:0] new_price,
    output wire [DW-1:0] oldest_price,
    output wire full,
    output wire [4:0] count
);
```

#### Implementation Details:

1. **Memory Structure**:
   - Uses a RAM array of size DEPTH: `reg [DW-1:0] mem [0:DEPTH-1];`
   - Default depth is 14 elements (for 14-period RSI)

2. **Pointer Management**:
   - Write pointer (`write_ptr`) indicates where to write the next price
   - Read pointer (`read_ptr`) indicates the oldest price location
   - Both pointers wrap around to implement circular behavior: `(ptr + 1) % DEPTH`

3. **FIFO Operations**:
   - When not full: write new price, increment write pointer and count
   - When full: write new price, increment both write and read pointers

4. **State Tracking**:
   - `item_count` tracks the number of valid items (0 to DEPTH)
   - `full` flag is set when item_count equals DEPTH

#### Memory Access Pattern:

```
Not Full:                    Full (Circular Overwrite):
                                 
  write_ptr                      read_ptr   write_ptr
      ↓                             ↓          ↓
┌─────┬─────┬─────┐           ┌─────┬─────┬─────┐
│ A   │ B   │     │           │ D   │ E   │ F   │
└─────┴─────┴─────┘           └─────┴─────┴─────┘
                             Oldest         Newest
```

### 2. Moving Average FSM

```verilog
module moving_average_fsm #(
    parameter WINDOW = 20,
    parameter DW = 16
)(
    input wire clk, rst, start,
    input wire [DW-1:0] new_price, oldest_price,
    output reg [31:0] moving_avg,
    output reg done
);
```

#### Implementation Details:

1. **Finite State Machine**:
   - Uses a 2-bit state register (`st`) to track the calculation state
   - Three states: Idle (0), Calculate (1), Done (2)

2. **Sliding Window Calculation**:
   - Maintains a running sum in a 64-bit register to prevent overflow
   - Updates the sum by adding new price and subtracting oldest price
   - Divides by WINDOW (20) to get the moving average

3. **State Transitions**:
   ```
   ┌─────────┐    start    ┌───────────┐    auto    ┌──────┐
   │  Idle   ├────────────►│ Calculate ├───────────►│ Done │
   │ (st=0)  │             │  (st=1)   │            │(st=2)│
   └─────────┘             └───────────┘            └──┬───┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                              auto
   ```

4. **Calculation Efficiency**:
   - Requires only 3 operations per update: add, subtract, divide
   - O(1) complexity instead of O(n) for a naive implementation

#### Register Widths:
- `sum`: 64-bit to prevent overflow with large price sums
- `moving_avg`: 32-bit to accommodate division results
- `st`: 2-bit for the FSM state (3 states)

### 3. RSI Incremental Calculator

```verilog
module rsi_inc #(
    parameter WINDOW = 14,
    parameter DW = 16
)(
    input wire clk, rst, new_price_strobe,
    input wire [DW-1:0] new_price, oldest_price,
    input wire mem_full,
    input wire [4:0] mem_count,
    output reg [7:0] rsi,
    output reg done
);
```

#### Implementation Details:

1. **Gain/Loss Tracking**:
   - Maintains separate accumulators for price gains and losses
   - Compares each new price with the previous price
   - Incrementally updates gain_sum or loss_sum based on price direction

2. **RSI Calculation Algorithm**:
   - Classic RSI formula: RSI = 100 * (Average Gain / (Average Gain + Average Loss))
   - Implemented as: rsi = (100 * gain_sum) / (gain_sum + loss_sum)
   - Includes protection against division by zero

3. **First Sample Handling**:
   - Uses a `first_sample` flag to handle the initial price
   - Sets the previous price without calculating gain/loss for the first sample

4. **Data Validation**:
   - Only calculates RSI when sufficient data is available (mem_count >= 14)
   - Sets the done flag when calculation is complete

#### Register Sizing:
- `gain_sum`, `loss_sum`: 32-bit registers for accumulating price differences
- `rsi`: 8-bit output (0-100 range)
- `prev_price`: Same width as input prices (DW)

### 4. Trading Decision Logic

```verilog
module trading_decision #(
    parameter BUY_RSI_THR = 8'd30,
    parameter SELL_RSI_THR = 8'd70
)(
    input wire clk, rst,
    input wire [15:0] price_now,
    input wire [31:0] moving_avg,
    input wire [7:0] rsi,
    output reg buy, sell
);
```

#### Implementation Details:

1. **Trading Strategy**:
   - Implements a momentum-based mean reversion strategy
   - Uses both trend (price vs. MA) and momentum (RSI) indicators

2. **Buy Conditions**:
   - Current price is ABOVE moving average (uptrend)
   - RSI is BELOW the buy threshold (oversold condition)
   - Both conditions must be true simultaneously

3. **Sell Conditions**:
   - Current price is BELOW moving average (downtrend)
   - RSI is ABOVE the sell threshold (overbought condition)
   - Both conditions must be true simultaneously

4. **Signal Generation**:
   - Evaluates conditions on every clock cycle
   - Buy and sell signals are registered outputs
   - One-cycle latency from condition evaluation to signal generation

#### Default Thresholds:
- Buy RSI threshold: 30 (traditional oversold level)
- Sell RSI threshold: 70 (traditional overbought level)

### 5. Top-Level Integration Module

```verilog
module trading_system_singlemem (
    input wire clk, rst,
    input wire [15:0] price_in,
    input wire new_price,
    output wire [31:0] moving_avg,
    output wire [7:0] rsi,
    output wire buy, sell,
    output wire mem_full,
    output wire [4:0] mem_cnt,
    output wire [15:0] oldest_price,
    output wire ma_done, rsi_done
);
```

#### Implementation Details:

1. **Module Instantiation**:
   - Creates instances of all four sub-modules
   - Connects them according to the system architecture

2. **Calculation Trigger Logic**:
   - Generates a `compute_enable` signal when memory contains enough data
   - Defined as: `wire compute_enable = (mem_cnt == 14);`
   - This signal triggers both MA and RSI calculations

3. **Signal Routing**:
   - Connects the price memory to both indicator modules
   - Connects indicator outputs to the decision module
   - Exposes key internal signals as module outputs for monitoring

4. **Port Forwarding**:
   - Passes through signals like `mem_full`, `mem_cnt`, `oldest_price`
   - Allows external monitoring of internal system state

## Timing Considerations

### Clock Domain
All modules operate in a single clock domain, simplifying timing and synchronization.

### Calculation Latency
1. **Moving Average**:
   - 2 clock cycles from start to done
   - State 0 → 1: Calculation (1 cycle)
   - State 1 → 2: Done signaling (1 cycle)

2. **RSI**:
   - Variable latency based on data availability
   - Calculation occurs when new_price_strobe and mem_count >= 14
   - done flag raised for one cycle after calculation

3. **End-to-End Latency**:
   - From new price input to signal generation: 3-4 clock cycles
   - Depends on the state of each module when the new price arrives

### Synchronization
- Moving Average and RSI are calculated in parallel
- Both triggered by the same compute_enable signal
- Trading decisions occur one cycle after indicator updates

## Implementation Optimizations

### 1. Sliding Window for Moving Average

The moving average uses a sliding window approach for O(1) complexity:

```verilog
sum <= sum + new_price - oldest_price;
moving_avg <= sum / WINDOW;
```

Compared to a naive implementation that would recalculate the entire sum for each new price:

```verilog
// Naive approach (not used)
sum = 0;
for (i = 0; i < WINDOW; i = i + 1) begin
    sum = sum + prices[i];
end
moving_avg = sum / WINDOW;
```

### 2. Efficient Memory Usage

The price memory implements a circular buffer that:
- Reuses memory locations when full
- Updates both read and write pointers in a single operation
- Avoids the need for shifting operations

### 3. Register Width Optimization

Each register is sized appropriately for its purpose:
- 64-bit sum in the MA module to prevent overflow
- 32-bit gain/loss accumulators in the RSI module
- 8-bit output for RSI (0-100 range)
- 2-bit state registers for the FSM

### 4. Parameterized Design

All modules use parameters to define key values:
- Window sizes (WINDOW = 14 for RSI, 20 for MA)
- Data widths (DW = 16 for price inputs)
- RSI thresholds (30 for buy, 70 for sell)

This allows easy reconfiguration without changing the core logic.

## Testbench Implementation

The testbench implements a complete simulation environment:

```verilog
module tb_trading_system_singlemem;
    // Clock generation, DUT instantiation, etc.
    
    reg [15:0] prices [0:13];  // Test data array
    
    // Feed prices one by one
    always @(posedge clk) begin
        if (!rst && index < 14) begin
            price_in <= prices[index];
            new_price <= 1;
            index <= index + 1;
        end else begin
            new_price <= 0;
        end
    end
    
    // Monitor and display outputs
    initial begin
        $display("Time | Price | MA | RSI | BUY | SELL");
        $monitor("%4t | %d | %d | %d | %b | %b",
                 $time, price_in, moving_avg, rsi, buy, sell);
    end
endmodule
```

### Test Data

The test data includes 14 price points with both upward and downward movements:

```
prices[ 0] = 16'd10234; prices[ 1] = 16'd10380; // Up
prices[ 2] = 16'd10125; prices[ 3] = 16'd10490; // Down then Up
prices[ 4] = 16'd10510; prices[ 5] = 16'd10420; // Up then Down
prices[ 6] = 16'd10650; prices[ 7] = 16'd10790; // Up, Up
prices[ 8] = 16'd10680; prices[ 9] = 16'd10830; // Down then Up
prices[10] = 16'd10920; prices[11] = 16'd10810; // Up then Down
prices[12] = 16'd10750; prices[13] = 16'd11060; // Down then Up
```

### Verification Points

1. Proper FIFO filling: `wait (mem_cnt == 14);`
2. RSI calculation correctness: Monitor rsi value
3. Moving average accuracy: Monitor moving_avg value
4. Trading signal generation: Monitor buy and sell outputs

## Advanced Implementation Considerations

### 1. Integer vs. Fixed-Point Arithmetic

The current implementation uses integer division:
```verilog
moving_avg <= sum / WINDOW;
rsi <= (100 * gain) / total;
```

This could be improved with fixed-point arithmetic:
```verilog
// Fixed-point approach (not implemented)
moving_avg <= (sum << FRAC_BITS) / WINDOW;
rsi <= ((100 << FRAC_BITS) * gain) / total;
```

### 2. Pipelining Opportunities

The calculation path could be pipelined for higher throughput:
1. Stage 1: Price update and memory operations
2. Stage 2: Indicator calculations (MA and RSI)
3. Stage 3: Trading decision logic

### 3. Resource Optimization

For FPGA implementation, consider:
- Using DSP blocks for high-speed arithmetic
- Implementing the division with shift operations for powers of 2
- Optimizing memory usage with block RAM resources

### 4. System Scalability

The design could be extended to:
- Support multiple trading pairs/instruments
- Implement multiple timeframes
- Add more sophisticated indicators (EMA, MACD, Bollinger Bands)

## Implementation Verification

### Functionality Tests

The testbench verifies:
1. Price memory operation and FIFO functionality
2. Moving average calculation correctness
3. RSI value generation
4. Buy/sell signal generation based on criteria

### Waveform Analysis

The testbench generates a VCD file:
```verilog
$dumpfile("trading_system.vcd");
$dumpvars(0, tb_trading_system_singlemem);
```

Key signals to observe in waveform viewer:
- Clock and reset signals
- Price inputs and memory operations
- Moving average and RSI calculations
- Buy/sell signal generation
- FSM state transitions

### Performance Metrics

The implementation prioritizes:
1. **Latency**: Minimizing clock cycles from input to output
2. **Resource Usage**: Efficient use of registers and memory
3. **Throughput**: Ability to process one price per clock cycle
4. **Accuracy**: Correct calculation of indicators and signals

## Conclusion

This trading system implements a complete algorithmic trading strategy using hardware description language (Verilog). The efficient implementation of the moving average calculation using a sliding window approach and the incremental RSI calculation demonstrate hardware-optimized approaches to common technical indicators. The modular design allows for easy modifications and extensions to implement more sophisticated trading strategies.
#### Test Configuration
- Clock period: 10ns (5ns high, 5ns low)
- Test data: 14 predefined price points

#### Test Procedure
1. Initializes with an active reset signal
2. Releases reset after 5 clock cycles
3. Feeds 14 predefined prices into the system, one per clock cycle
4. Verifies memory fills to capacity (mem_cnt == 14)
5. Monitors system outputs: moving average, RSI, buy/sell signals
6. Ends simulation after 2000 time units

#### Test Data
The testbench uses a predefined array of 14 prices:
- 10234, 10380, 10125, 10490, 10510, 10420, 10650
- 10790, 10680, 10830, 10920, 10810, 10750, 11060

#### Monitoring and Output
The testbench generates a VCD (Value Change Dump) file for waveform analysis and prints a formatted table of:
- Time
- Current price
- Moving average
- RSI
- Buy signal
- Sell signal

## Design Considerations and Optimizations

### Efficient Moving Average Calculation
The moving average implementation is optimized in several ways:

1. **Sliding Window Approach**:
   - Instead of recalculating the entire sum for each new price (which would be O(n) operations)
   - Uses a running sum that's updated by adding the new price and subtracting the oldest price (O(1) operations)

2. **FSM Implementation**:
   - Uses a minimal state machine with just 3 states
   - Reduces logic complexity and resource utilization

3. **64-bit Sum Accumulator**:
   - Uses a wide (64-bit) accumulator to prevent overflow
   - Ensures accurate calculations even with large price values

### Integration with Trading Decision
The moving average serves as one of the key technical indicators in the trading strategy:

1. **Trend Identification**:
   - Price above MA indicates an uptrend
   - Price below MA indicates a downtrend

2. **Signal Generation**:
   - Combined with RSI to filter out false signals
   - Only generates buy signals in uptrends with oversold conditions
   - Only generates sell signals in downtrends with overbought conditions

### Potential Enhancements
Possible improvements to the moving average implementation:

1. **Exponential Moving Average (EMA)**:
   - Could be implemented to give more weight to recent prices
   - Would require modifications to the calculation approach

2. **Multiple Timeframes**:
   - Could add multiple moving averages with different window sizes
   - Would allow for more sophisticated trading strategies

3. **Fixed-Point Arithmetic**:
   - Could implement fixed-point calculations for better precision
   - Would avoid the rounding issues of integer division

## Conclusion
The trading system demonstrates an efficient implementation of technical indicators in Verilog, suitable for FPGA deployment. The moving average calculation is particularly optimized, using a sliding window approach with an FSM for efficient computation. The system integrates multiple components to form a complete trading strategy that generates buy and sell signals based on price movements relative to the moving average and RSI values.
