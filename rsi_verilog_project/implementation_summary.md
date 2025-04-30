# RSI Hardware Implementation using Verilog

## 📊 Overview
This project implements a hardware-based Relative Strength Index (RSI) calculator using Verilog for FPGA implementation. The RSI is a momentum oscillator that measures the speed and change of price movements, commonly used in financial technical analysis. This implementation uses a Finite State Machine (FSM) approach to manage the computational workflow and a FIFO buffer to store price data.

## 🔍 Technical Architecture

The system consists of two primary modules:
1. `price_fifo.v` - A customizable First-In-First-Out buffer for storing price data
2. `rsi_fsm.v` - A Finite State Machine that controls the RSI calculation process

### System Parameters
- Price history depth: 20 samples
- Price data width: 16 bits
- Output RSI range: 0-100 (8-bit representation)

## 💾 Price FIFO Module Detailed Documentation

The `price_fifo` module implements a circular buffer that stores price data with configurable depth and width.

### Parameters
- `DEPTH`: Number of entries in the FIFO (default: 20)
- `WIDTH`: Bit width of each entry (default: 16)

### Ports
- **Inputs**:
  - `clk`: System clock signal
  - `rst`: Asynchronous reset signal (active high)
  - `wr_en`: Write enable signal
  - `rd_en`: Read enable signal
  - `din[WIDTH-1:0]`: Data input (price value)
- **Outputs**:
  - `dout[WIDTH-1:0]`: Data output (price value)
  - `full`: Flag indicating FIFO is full
  - `empty`: Flag indicating FIFO is empty

### Internal Registers
- `mem[0:DEPTH-1]`: Memory array for storing price values
- `wr_ptr`: Write pointer (5 bits to address up to 32 entries)
- `rd_ptr`: Read pointer (5 bits to address up to 32 entries)
- `count`: Current number of elements in the FIFO (6 bits to represent up to 32 entries)

### Behavior
The FIFO operates on the positive edge of the clock or reset signal:
- On reset: All pointers and counters are reset to zero
- Write operation: When `wr_en` is asserted and the FIFO is not full, the data at `din` is stored at the current write pointer position, the write pointer is incremented, and the count is increased
- Read operation: When `rd_en` is asserted and the FIFO is not empty, the data at the current read pointer position is output to `dout`, the read pointer is incremented, and the count is decreased

## ⚙️ RSI FSM Module Detailed Documentation

The `rsi_fsm` module implements a Finite State Machine (FSM) that controls the process of calculating the Relative Strength Index (RSI).

### Ports
- **Inputs**:
  - `clk`: System clock signal
  - `rst`: Asynchronous reset signal (active high)
  - `start`: Signal to start the RSI calculation process
  - `price_in[15:0]`: Price input data
  - `new_price`: Signal indicating a new price is available
- **Outputs**:
  - `done`: Signal indicating the RSI calculation is complete
  - `rsi[7:0]`: Calculated RSI value (0-100)

### Internal Connections
The RSI FSM instantiates a `price_fifo` module with the following connections:
- `clk` → `clk`
- `rst` → `rst`
- `fifo_wr_en` → `wr_en`
- `fifo_rd_en` → `rd_en`
- `price_in` → `din`
- `price_out` ← `dout`
- `fifo_full` ← `full`
- `fifo_empty` ← `empty`

### Internal Registers
- `state`: Current FSM state (3 bits)
- `fifo_wr_en`: FIFO write enable control
- `fifo_rd_en`: FIFO read enable control
- `prev_price`: Previous price value for comparison
- `curr_price`: Current price value for comparison
- `gain_sum`: Cumulative sum of price gains
- `loss_sum`: Cumulative sum of price losses
- `sample_cnt`: Counter for tracking processed samples
- `read_delay`: Flag for handling FIFO read delay

## 🔄 FSM State Machine Design In-Depth Analysis

The RSI calculation is managed through a 6-state Finite State Machine. The state transitions and operations are carefully designed to handle the sequential nature of RSI calculation. Let's examine each state in detail:

### 1. IDLE State (3'b000)
The IDLE state is the default starting state of the FSM and the state to which it returns after completing an RSI calculation.

**Behavior:**
- System waits for the `start` signal to begin a new RSI calculation
- When `start` is asserted:
  - Reset counters and accumulators: `gain_sum`, `loss_sum`, `sample_cnt`
  - Clear the `done` flag
  - Transition to the FILL_FIFO state

**Flag Operations:**
- No flags are modified unless transitioning to the next state

**Transition Conditions:**
- If `start` is asserted: → FILL_FIFO
- Otherwise: remain in IDLE

### 2. FILL_FIFO State (3'b001)
The FILL_FIFO state handles loading the price data into the FIFO buffer until it reaches capacity.

**Behavior:**
- If a new price is available (`new_price` is asserted) and the FIFO is not full:
  - Enable writing to the FIFO by asserting `fifo_wr_en`
- Once the FIFO is full:
  - Begin reading from the FIFO by asserting `fifo_rd_en`
  - Set the `read_delay` flag to handle the one-cycle delay in FIFO read operations
  - Transition to the READ_INIT state

**Flag Operations:**
- `fifo_wr_en`: Set when new price available and FIFO not full
- `fifo_rd_en`: Set when FIFO becomes full
- `read_delay`: Set when initiating first read operation

**Transition Conditions:**
- If FIFO becomes full: → READ_INIT
- Otherwise: remain in FILL_FIFO

### 3. READ_INIT State (3'b010)
The READ_INIT state initializes the first price value for subsequent comparisons.

**Behavior:**
- Clear the FIFO read enable signal (`fifo_rd_en`)
- If the `read_delay` flag is set:
  - Capture the first price as `prev_price`
  - Clear the `read_delay` flag
  - Transition to the COMPARE state

**Flag Operations:**
- `fifo_rd_en`: Cleared
- `read_delay`: Cleared when first price is captured
- `prev_price`: Updated with the first price value from the FIFO

**Transition Conditions:**
- When `read_delay` is set and the first price is captured: → COMPARE
- Otherwise: remain in READ_INIT

### 4. COMPARE State (3'b100)
The COMPARE state determines whether to continue processing price data or to complete the calculation.

**Behavior:**
- If not all samples have been processed (`sample_cnt < 19`) and the FIFO is not empty:
  - Enable reading from the FIFO by asserting `fifo_rd_en`
  - Set the `read_delay` flag to handle the one-cycle delay in FIFO read operations
  - Transition to the READ_WAIT state
- Otherwise:
  - Transition to the DONE state

**Flag Operations:**
- `fifo_rd_en`: Set when more samples need processing
- `read_delay`: Set when initiating a read operation

**Transition Conditions:**
- If `sample_cnt < 19` and FIFO not empty: → READ_WAIT
- Otherwise: → DONE

### 5. READ_WAIT State (3'b011)
The READ_WAIT state performs the core RSI calculation by comparing consecutive price values.

**Behavior:**
- Clear the FIFO read enable signal (`fifo_rd_en`)
- If the `read_delay` flag is set:
  - Capture the current price as `curr_price`
  - Compare `curr_price` with `prev_price`:
    - If `curr_price > prev_price`: Add the difference to `gain_sum`
    - If `curr_price < prev_price`: Add the difference to `loss_sum`
  - Update `prev_price` with the current price
  - Increment the sample counter
  - Clear the `read_delay` flag
  - Transition back to the COMPARE state

**Flag Operations:**
- `fifo_rd_en`: Cleared
- `curr_price`: Updated with the latest price from the FIFO
- `gain_sum`: Incremented if current price is higher than previous
- `loss_sum`: Incremented if current price is lower than previous
- `prev_price`: Updated with the current price for the next comparison
- `sample_cnt`: Incremented to track progress
- `read_delay`: Cleared after processing

**Transition Conditions:**
- When processing is complete: → COMPARE

### 6. DONE State (3'b101)
The DONE state calculates the final RSI value and signals completion.

**Behavior:**
- Calculate the RSI using the formula: RSI = 100 * gain_sum / (gain_sum + loss_sum)
  - If `gain_sum + loss_sum > 0`: Calculate RSI normally
  - Otherwise: Set RSI to 0 to avoid division by zero
- Assert the `done` flag to signal completion
- Transition back to the IDLE state

**Flag Operations:**
- `rsi`: Updated with the calculated RSI value
- `done`: Asserted to indicate calculation completion

**Transition Conditions:**
- Always: → IDLE

## 📈 RSI Calculation Method

The RSI is calculated using the following approach:
1. Store 20 consecutive price samples in the FIFO
2. For each pair of consecutive prices:
   - If current price > previous price: Add the difference to gain_sum
   - If current price < previous price: Add the difference to loss_sum
3. Calculate RSI using the formula: RSI = 100 * gain_sum / (gain_sum + loss_sum)

### Sample Calculation
For the sample prices: [100, 98, 101, 99, 102, 100, 103, 101, 104, 102, 105, 103, 106, 104, 107, 105, 108, 106, 109, 107]

The price changes are:
- 98-100 = -2 (loss: 2)
- 101-98 = 3 (gain: 3)
- 99-101 = -2 (loss: 2)
- 102-99 = 3 (gain: 3)
- 100-102 = -2 (loss: 2)
- 103-100 = 3 (gain: 3)
- 101-103 = -2 (loss: 2)
- 104-101 = 3 (gain: 3)
- 102-104 = -2 (loss: 2)
- 105-102 = 3 (gain: 3)
- 103-105 = -2 (loss: 2)
- 106-103 = 3 (gain: 3)
- 104-106 = -2 (loss: 2)
- 107-104 = 3 (gain: 3)
- 105-107 = -2 (loss: 2)
- 108-105 = 3 (gain: 3)
- 106-108 = -2 (loss: 2)
- 109-106 = 3 (gain: 3)
- 107-109 = -2 (loss: 2)

Total gain sum = 27
Total loss sum = 18

RSI = 100 * 27 / (27 + 18) = 100 * 27 / 45 = 60

## 🚩 Critical Flags and Control Signals

### Main Control Flags
- `start`: Initiates the RSI calculation process
- `done`: Signals completion of the RSI calculation
- `new_price`: Indicates a new price is available for processing

### FIFO Control Flags
- `fifo_wr_en`: Controls writing to the FIFO
- `fifo_rd_en`: Controls reading from the FIFO
- `fifo_full`: Indicates the FIFO has reached capacity
- `fifo_empty`: Indicates the FIFO contains no data

### Internal Processing Flags
- `read_delay`: Manages the one-cycle delay in FIFO read operations
- `sample_cnt`: Tracks the number of processed samples

## 🔧 Implementation Considerations

### Timing Considerations
- The FIFO read operation introduces a one-cycle delay, which is handled by the `read_delay` flag
- State transitions are synchronized to the positive edge of the clock

### Resource Utilization
- Memory usage: 20 price entries × 16 bits = 320 bits
- State encoding: 3 bits for 6 states
- Arithmetic operations: Addition and division for RSI calculation

### Potential Enhancements
1. Parameterized RSI period (currently fixed at 20)
2. Fixed-point arithmetic for more precise RSI calculation
3. Exponential moving average implementation for Exponential RSI
4. Pipelined architecture for higher throughput

## 📝 Usage and Integration
## 🧪 Testing and Verification

### Testbench Overview
The project includes a comprehensive testbench (`rsi_testbench.v`) that verifies the functionality of the RSI implementation.

### Testbench Architecture
```verilog
module rsi_testbench;
    reg clk = 0, rst = 1, start = 0, new_price = 0;
    reg [15:0] price_in = 0;
    wire done;
    wire [7:0] rsi;

    rsi_fsm uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .price_in(price_in),
        .new_price(new_price),
        .done(done),
        .rsi(rsi)
    );

    always #5 clk = ~clk;

    // Test implementation
    // ...
endmodule
```

### Test Sequence
1. Initialize system with reset asserted
2. Generate a test price sequence with alternating gains and losses
3. De-assert reset and pulse the start signal
4. Feed each price into the system with the new_price signal
5. Wait for the done signal to be asserted
6. Verify the calculated RSI value

### Test Data Pattern
The testbench uses a specially crafted price sequence where:
- Starting price: 100
- Even indices: Price increases by 3
- Odd indices: Price decreases by 2

This pattern creates a predictable RSI calculation with known gain and loss values.

### Running the Testbench
The testbench can be executed using standard Verilog simulation tools:
```
$ iverilog -o rsi_sim rsi_fsm.v price_fifo.v rsi_testbench.v
$ vvp rsi_sim
```

### Expected Results
With the provided test pattern, the expected RSI value is 60, matching our sample calculation example.
```
RSI Value = 60
```
### Module Instantiation
```verilog
rsi_fsm rsi_calculator (
    .clk(system_clock),
    .rst(system_reset),
    .start(begin_calculation),
    .price_in(current_price),
    .new_price(price_valid),
    .done(calculation_complete),
    .rsi(rsi_output)
);
```

### Operational Sequence
1. Assert `rst` to initialize the system
2. De-assert `rst` to begin operation
3. Feed prices by setting `price_in` and asserting `new_price`
4. Once 20 prices have been stored, assert `start`
5. Wait for `done` to be asserted
6. Read the calculated RSI value from the `rsi` output

## 📚 Conclusion

This RSI hardware implementation provides an efficient way to calculate the Relative Strength Index in real-time trading systems. The FSM-based approach offers a clear, maintainable design that can be easily adapted for various FPGA platforms. The modular structure with separated FIFO and calculation logic allows for independent optimization and reuse in larger systems.

The implementation demonstrates key digital design concepts including:
- Finite State Machine design
- FIFO buffer implementation
- Sequential numerical processing
- Hardware resource optimization
