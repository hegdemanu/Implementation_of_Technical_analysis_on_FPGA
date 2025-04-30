# Moving Average Trading System Implementation Summary

## System Overview

This implementation consists of a 10-point moving average calculator for financial price data. The system is designed to calculate the moving average of the last 10 price points and could be used as part of a larger trading system. The implementation is written in Verilog HDL and consists of three main modules:

1. **Memory Module** (`memory.v`): A FIFO buffer that stores the last 10 price points
2. **Moving Average FSM** (`moving_average_fsm.v`): A finite state machine that calculates the moving average
3. **Testbench** (`trading_system_tb.v`): A simulation environment to verify the system's functionality

## Module Details

### Memory Module (`memory.v`)

The memory module implements a 10-element FIFO (First In, First Out) buffer for storing price data:

- **Inputs**:
  - `clk`: System clock
  - `rst`: Asynchronous reset
  - `new_price` (32-bit): New price data to be stored
  - `write_enable`: Control signal to enable writing to the FIFO

- **Outputs**:
  - `oldest_price` (32-bit): The oldest price in the FIFO (to be removed from the moving average)
  - `memory_full`: Flag indicating the FIFO contains 10 prices
  - `prices_flat` (320-bit): Flattened array of all 10 prices (for debugging)
  - `fifo_data_count` (4-bit): Number of prices currently stored in the FIFO

The FIFO operates as a shift register, where the oldest price is removed when a new price is added. The module keeps track of how many valid prices are in the buffer through the `fifo_data_count` signal.

### Moving Average FSM (`moving_average_fsm.v`)

This module implements a finite state machine to calculate the moving average:

- **Inputs**:
  - `clk`: System clock
  - `rst`: Asynchronous reset
  - `start`: Signal to begin calculation (connected to `memory_full` in the testbench)
  - `new_price` (32-bit): New price data
  - `oldest_price` (32-bit): Oldest price data from the FIFO

- **Outputs**:
  - `moving_avg` (32-bit): Calculated moving average
  - `done`: Flag indicating calculation is complete

The FSM has three states:
1. **Idle state (0)**: Waits for the start signal
2. **Calculate state (1)**: Updates the rolling sum and calculates the average
3. **Complete state (2)**: Sets the done flag and returns to idle

The module maintains a 64-bit `sum` variable to prevent overflow during calculations and divides by 10 to get the final average.

### Testbench (`trading_system_tb.v`)

The testbench connects the memory and moving average FSM modules and verifies their functionality:

- Generates a clock with a 10ns period
- Applies a reset at the beginning
- Feeds 10 test prices (starting at 1000 and incrementing by 5)
- Waits for the FIFO to be full and the moving average to be calculated
- Displays the final state and terminates the simulation

## Key Design Features

1. **Rolling Sum Approach**: Instead of recalculating the sum from scratch for each new price, the system maintains a running sum by adding new prices and subtracting oldest prices.

2. **FIFO Implementation**: The memory module implements a hardware-efficient FIFO using a shift register approach.

3. **Pipeline Structure**: The system uses a simple pipeline where the memory module feeds data to the moving average FSM.

4. **Data Width Management**: The sum is maintained as a 64-bit value to prevent overflow, while all I/O interfaces use 32-bit values.

## Potential Issues

1. There appears to be a timing issue in the FSM where the moving average is calculated using the sum before it's updated with the new price.

2. The FSM doesn't wait for memory operations to complete before starting the calculation.

3. The division operation (`sum / 10`) is implemented without handling potential rounding errors.

## Implementation Notes

- The design is synchronous with all operations triggered on the positive edge of the clock.
- Asynchronous reset is used throughout the design.
- The system is designed to work with 32-bit price values.
- The moving average calculation begins only when the FIFO is full (10 prices).
