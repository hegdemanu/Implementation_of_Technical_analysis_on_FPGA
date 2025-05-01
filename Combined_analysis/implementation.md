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
