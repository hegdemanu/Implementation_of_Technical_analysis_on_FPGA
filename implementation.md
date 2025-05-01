# FPGA-Based Technical Analysis Trading System

## Table of Contents

1. [Introduction](#introduction)
2. [Repository Structure](#repository-structure)
3. [System Architecture](#system-architecture)
4. [Technical Indicators Implementation](#technical-indicators-implementation)
    - [Moving Average Implementation](#moving-average-implementation)
    - [RSI Implementation](#rsi-implementation)
    - [Trading Decision Logic](#trading-decision-logic)
5. [Hardware Design Approach](#hardware-design-approach)
6. [Modules Documentation](#modules-documentation)
    - [Moving Average System](#moving-average-system)
    - [RSI Calculator](#rsi-calculator)
    - [Trading Decision System](#trading-decision-system)
    - [Price Memory (FIFO)](#price-memory-fifo)
7. [Implementation Optimizations](#implementation-optimizations)
8. [Performance Considerations](#performance-considerations)
9. [Verification and Testing](#verification-and-testing)
10. [Usage Guide](#usage-guide)
11. [Extension Possibilities](#extension-possibilities)
12. [Design Considerations and Tradeoffs](#design-considerations-and-tradeoffs)
13. [Future Work](#future-work)
14. [License](#license)

## Introduction

This repository contains a comprehensive Verilog implementation of technical analysis indicators for algorithmic trading systems on FPGAs. The design leverages hardware acceleration to achieve real-time processing of market data with minimal latency, making it suitable for high-frequency trading applications.

The implementation includes hardware modules for calculating:
- Simple Moving Average (SMA) with a configurable window size
- Relative Strength Index (RSI) for momentum analysis
- Trading decision logic based on technical indicators

All components are designed with resource efficiency, parameterization, and modularity in mind, allowing for straightforward integration into larger trading systems or modification for specific requirements.

Key features:
- Optimized for FPGA implementation with efficient resource utilization
- Low latency operation with deterministic timing
- Modular design with clean separation of data storage and calculation logic
- Finite State Machine (FSM) approach for control flow
- Sliding window algorithms to minimize computational complexity
- Parameterized design for flexibility and reusability
- Comprehensive testbenches for verification

## Repository Structure

The repository is organized into the following main sections:

```
Implementation_of_Technical_analysis_on_FPGA/
│
├── Combined_analysis/         # Integrated trading system implementation
│   ├── implementation.md      # Detailed implementation documentation
│   ├── moving_average_fsm.v   # Moving average FSM implementation
│   ├── price_memory.v         # Price memory (FIFO) implementation
│   ├── readme.md              # System documentation
│   ├── rsi_inc.v              # RSI implementation
│   ├── tb_trading_system_singlemem.v  # Testbench for trading system
│   ├── trading_decision.v     # Trading decision logic
│   └── trading_system_singlemem.v     # Top-level system integration
│
├── Moving_average/            # Moving average specific implementation
│   ├── Implementation Analysis.md      # In-depth analysis
│   ├── implementation_Summary.md       # Summary of implementation
│   ├── memory.v                        # Memory module for MA
│   ├── moving_average_fsm.v            # MA state machine
│   ├── readme.md                       # Documentation
│   └── trading_system_tb.v             # MA system testbench
│
├── rsi_verilog_project/                # RSI specific implementation
│   ├── implementation_summary.md       # RSI implementation summary
│   ├── price_fifo.v                    # Price FIFO for RSI
│   ├── readme.md                       # RSI documentation
│   ├── rsi_fsm.v                       # RSI state machine
│   └── rsi_testbench.v                 # RSI testbench
│
├── LICENSE                    # MIT License
└── README.md                  # This file
```

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

The data flow within the system follows these steps:

1. New price data enters the system through the top-level module
2. Price history is stored in a circular FIFO buffer
3. When sufficient data is available, technical indicators (Moving Average and RSI) are calculated in parallel
4. The Trading Decision module evaluates indicator values against predefined criteria
5. Buy/sell signals are generated based on the strategy implementation

## Technical Indicators Implementation

### Moving Average Implementation

The moving average is implemented using an efficient sliding window approach with O(1) complexity:

```verilog
sum <= sum + new_price - oldest_price;
moving_avg <= sum / WINDOW;
```

This algorithm maintains a running sum and updates it by adding the newest price and subtracting the oldest price, followed by division by the window size. This approach is significantly more efficient than recalculating the entire sum for each new price.

The implementation uses a parameterized window size (default: 20), making it adaptable to different trading strategies. A Finite State Machine controls the calculation process with three states:
- Idle: Waiting for the start signal
- Calculate: Updating the sum and computing the average
- Done: Signaling completion and returning to idle

### RSI Implementation

The Relative Strength Index (RSI) is implemented as a momentum oscillator that measures the speed and change of price movements. The RSI calculation follows these steps:

1. Store a defined number of consecutive price samples (default: 14)
2. Calculate price changes between consecutive periods
3. Accumulate gains (price increases) and losses (price decreases)
4. Calculate RSI using the formula: RSI = 100 * gain_sum / (gain_sum + loss_sum)

The implementation uses a 6-state Finite State Machine:
- IDLE: Waiting for start signal
- FILL_FIFO: Loading price data
- READ_INIT: Initializing the first price value
- COMPARE: Determining whether to continue processing
- READ_WAIT: Calculating gains and losses
- DONE: Computing final RSI value

### Trading Decision Logic

The trading decision module implements a momentum-based mean reversion strategy using both trend (price vs. MA) and momentum (RSI) indicators:

```verilog
// Buy condition: Price above MA (uptrend) and RSI below threshold (oversold)
buy <= (price_now > moving_avg[15:0]) && (rsi < BUY_RSI_THR);

// Sell condition: Price below MA (downtrend) and RSI above threshold (overbought)
sell <= (price_now < moving_avg[15:0]) && (rsi > SELL_RSI_THR);
```

The default thresholds are:
- Buy RSI threshold: 30 (traditional oversold level)
- Sell RSI threshold: 70 (traditional overbought level)

## Hardware Design Approach

The implementation follows hardware-specific optimization techniques to achieve efficient calculation of financial indicators in real-time:

1. **Memory Management**: 
   - Circular buffer implementation for price history
   - Efficient pointer management to avoid unnecessary data movement
   - Parameterized depth and width for adaptability

2. **Computational Efficiency**:
   - Sliding window algorithms for O(1) complexity
   - Register sizing optimized for precision and resource utilization
   - Strategic division implementation for FPGA platforms

3. **Control Logic**:
   - Finite State Machines for deterministic behavior
   - Clean separation of control and datapath elements
   - Clear state transitions with defined conditions

4. **System Integration**:
   - Single clock domain for timing simplification
   - Parallel indicator calculation
   - Synchronous design principles
   - Well-defined interfaces between modules

## Modules Documentation

### Moving Average System

The Moving Average system consists of two primary modules:

1. **Memory Module**:
   - Stores recent price history in a FIFO buffer
   - Provides oldest and newest prices for calculation
   - Signals when buffer is full (ready for calculation)
   - Configurable depth and data width parameters

2. **Moving Average FSM**:
   - Calculates the moving average using a sliding window
   - Maintains a running sum for efficiency
   - Uses extended precision to prevent overflow
   - Signals completion through a 'done' flag

Example instantiation:
```verilog
moving_average_fsm #(
    .WINDOW(20),
    .DW(16)
) ma_module (
    .clk(clk),
    .rst(rst),
    .start(start_signal),
    .new_price(price_input),
    .oldest_price(oldest_price),
    .moving_avg(ma_output),
    .done(ma_done)
);
```

### RSI Calculator

The RSI Calculator is composed of:

1. **Price FIFO Module**:
   - Customizable depth (default: 20 samples)
   - Parameterized data width (default: 16 bits)
   - Provides efficient storage and retrieval of price history

2. **RSI FSM Module**:
   - Controls the RSI calculation process through a 6-state machine
   - Tracks gain and loss accumulation
   - Handles proper sequencing of operations
   - Calculates final RSI value with overflow protection

Example instantiation:
```verilog
rsi_fsm rsi_module (
    .clk(clk),
    .rst(rst),
    .start(start_signal),
    .price_in(price_input),
    .new_price(price_valid),
    .done(rsi_done),
    .rsi(rsi_output)
);
```

### Trading Decision System

The Trading Decision module:
- Takes current price, moving average, and RSI as inputs
- Implements configurable threshold parameters
- Generates buy and sell signals based on predefined criteria
- Updates signals on each clock cycle

Example instantiation:
```verilog
trading_decision #(
    .BUY_RSI_THR(30),
    .SELL_RSI_THR(70)
) decision_module (
    .clk(clk),
    .rst(rst),
    .price_now(current_price),
    .moving_avg(ma_value),
    .rsi(rsi_value),
    .buy(buy_signal),
    .sell(sell_signal)
);
```

### Price Memory (FIFO)

The Price Memory module implements a circular buffer for storing price history:
- Reuses memory locations when full (circular wrapping)
- Provides the oldest price for sliding window calculation
- Signals when the buffer is full
- Configurable depth and data width

Implementation details:
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

## Implementation Optimizations

Several optimization techniques are employed to enhance performance and resource utilization:

### 1. Sliding Window for Moving Average

The moving average uses a sliding window approach for O(1) complexity instead of recalculating the entire sum for each new price, dramatically improving computational efficiency.

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

## Performance Considerations

### Clock Domain

All modules operate in a single clock domain, simplifying timing and synchronization. The reference implementation uses a 10ns clock period (100 MHz), appropriate for modern FPGA platforms.

### Calculation Latency

1. **Moving Average**:
   - 2 clock cycles from start to done
   - State 0 → 1: Calculation (1 cycle)
   - State 1 → 2: Done signaling (1 cycle)

2. **RSI**:
   - Variable latency based on data availability
   - Calculation occurs when new_price_strobe and mem_count >= 14
   - Done flag raised for one cycle after calculation

3. **End-to-End Latency**:
   - From new price input to signal generation: 3-4 clock cycles
   - Depends on the state of each module when the new price arrives

### Synchronization

- Moving Average and RSI are calculated in parallel
- Both triggered by the same compute_enable signal
- Trading decisions occur one cycle after indicator updates

## Verification and Testing

The repository includes comprehensive testbenches for each component:

### Moving Average Testbench

Tests the moving average calculation with a sequence of price inputs, verifying:
- Proper FIFO filling
- Moving average calculation correctness
- FSM state transitions

Example test data:
```
prices[ 0] = 16'd10234; prices[ 1] = 16'd10380; // Up
prices[ 2] = 16'd10125; prices[ 3] = 16'd10490; // Down then Up
prices[ 4] = 16'd10510; prices[ 5] = 16'd10420; // Up then Down
// ... and so on
```

### RSI Testbench

Verifies the RSI calculation using a specific test pattern:
- Initial price: 100
- Even indices: Price increases by 3
- Odd indices: Price decreases by 2

This pattern creates a deterministic outcome (RSI = 60) for verification. The testbench:
- Initializes the system with reset
- Feeds each price with proper timing
- Waits for calculation completion
- Verifies the final RSI value

### Trading System Testbench

Tests the complete integrated system, including:
- Price memory operation
- Indicator calculations
- Trading signal generation
- End-to-end functionality

The testbench outputs a timing table showing:
```
Time | Price | MA | RSI | BUY | SELL
```

## Usage Guide

### Integration with Larger Systems

To use this implementation in a complete trading system:

1. Include all Verilog files in your project
2. Instantiate the top-level module:
```verilog
trading_system_singlemem system (
    .clk(system_clock),
    .rst(system_reset),
    .price_in(market_price),
    .new_price(price_valid),
    .moving_avg(ma_output),
    .rsi(rsi_output),
    .buy(buy_signal),
    .sell(sell_signal),
    .mem_full(),
    .mem_cnt(),
    .oldest_price(),
    .ma_done(),
    .rsi_done()
);
```

3. Connect your price input to the `price_in` port
4. Use `new_price` to strobe in new price data
5. Monitor the `buy` and `sell` outputs for trading signals

### Parameter Configuration

The design is highly configurable through parameters:

1. **Moving Average Window**:
```verilog
moving_average_fsm #(
    .WINDOW(10)  // Change window size to 10
) ma_module (/* connections */);
```

2. **RSI Period**:
```verilog
price_fifo #(
    .DEPTH(14)  // Change RSI period to 14
) rsi_fifo (/* connections */);
```

3. **Trading Thresholds**:
```verilog
trading_decision #(
    .BUY_RSI_THR(25),    // More aggressive buy threshold
    .SELL_RSI_THR(75)    // More aggressive sell threshold
) decision_module (/* connections */);
```

## Extension Possibilities

The system can be extended in several ways:

### 1. Additional Technical Indicators

The modular design allows for the addition of other technical indicators:
- Exponential Moving Average (EMA)
- Bollinger Bands
- MACD (Moving Average Convergence Divergence)
- Stochastic Oscillator

### 2. Multiple Timeframes

Support for multiple timeframes can be implemented by:
- Instantiating indicator modules with different parameters
- Adding logic to combine signals from different timeframes
- Implementing downsampling for longer timeframes

### 3. Advanced Trading Strategies

The trading decision module can be enhanced to implement:
- Moving average crossover strategies
- Multi-indicator confirmation
- Volatility-based position sizing
- Custom strategies based on proprietary algorithms

### 4. Hardware Optimizations

Further optimizations could include:
- Pipelining for higher throughput
- Fixed-point arithmetic for better precision
- Custom division units for improved efficiency
- Multi-clock domain design for specialized timing requirements

## Design Considerations and Tradeoffs

Several design decisions influenced the implementation:

### 1. Integer vs. Fixed-Point Arithmetic

The current implementation uses integer division:
```verilog
moving_avg <= sum / WINDOW;
rsi <= (100 * gain) / total;
```

This approach prioritizes simplicity and resource efficiency but sacrifices some precision. A fixed-point implementation would offer better decimal precision but require additional resources.

### 2. FIFO Implementation Approach

The price memory uses a shift register approach for the FIFO. While efficient for small buffer sizes, this approach scales poorly for larger windows. For larger implementations, a circular buffer with pointers would be more efficient.

### 3. Calculation Timing

The design prioritizes deterministic timing and low latency, with indicator calculations completing in a fixed number of cycles. This predictability comes at the cost of potential resources that could be saved with a more variable-latency approach.

### 4. State Machine Complexity

The FSMs use minimal states to reduce complexity and resource usage. This simplicity enhances maintainability but limits the ability to handle complex error conditions or edge cases.

## Future Work

Potential areas for future enhancement include:

### 1. Advanced Implementation Features

- Fully parameterized design for all components
- Support for different moving average types (EMA, WMA)
- Implementation of more sophisticated trading strategies
- Integration with market data interfaces (FAST, FIX)

### 2. Performance Enhancements

- Pipelined implementation for higher throughput
- Clock domain crossing for interfacing with different system components
- Resource sharing between similar operations
- Fixed-point arithmetic for better precision

### 3. System Extensions

- Backtesting infrastructure for strategy validation
- Position management and risk control modules
- Multi-instrument support for portfolio trading
- Integration with order execution systems

### 4. Verification Improvements

- Automated test frameworks with reference models
- Formal verification of critical properties
- Statistical analysis of trading performance
- Coverage-driven verification

## License

This project is licensed under the MIT License - see the LICENSE file for details.

```
MIT License

Copyright (c) 2025 

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
