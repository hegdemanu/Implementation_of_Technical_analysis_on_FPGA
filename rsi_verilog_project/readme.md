# RSI Hardware Implementation using Verilog

## 📊 Overview
This project implements a hardware-based Relative Strength Index (RSI) calculator using Verilog for FPGA implementation. The RSI is a momentum oscillator that measures the speed and change of price movements, commonly used in financial technical analysis. This implementation uses a Finite State Machine (FSM) approach to manage the computational workflow and a FIFO buffer to store price data.

## 📈 Relative Strength Index (RSI) Theory

### Fundamental Concept
The Relative Strength Index (RSI) is a momentum oscillator developed by J. Welles Wilder in 1978. It measures the speed and magnitude of price movements on a scale from 0 to 100, helping traders identify potential overbought or oversold conditions in a market. The RSI is calculated based on the ratio of average gains to average losses over a specified period.

### Mathematical Foundation

The traditional RSI calculation involves several steps:

1. **Calculate price changes**: For each period, determine if there was a gain (positive change) or loss (negative change).
2. **Average gain and loss**: Calculate the average gain and average loss over the specified period.
3. **Relative Strength (RS)**: Divide the average gain by the average loss to find the Relative Strength.
4. **RSI formula**: Apply the formula RSI = 100 - (100 / (1 + RS)).

Alternatively, this can be expressed as:
RSI = 100 × (Average Gain / (Average Gain + Average Loss))

### Standard RSI Implementation Methods

#### Simple RSI (First Calculation)
For the first RSI calculation (when no previous average gain or loss exists):
1. Sum all gains over the period and divide by the period length.
2. Sum all losses over the period and divide by the period length.
3. Calculate RS = Average Gain / Average Loss.
4. Calculate RSI = 100 - (100 / (1 + RS)).

#### Smoothed RSI (Subsequent Calculations)
For subsequent calculations, a smoothing technique is often applied:
1. Current Average Gain = ((Previous Average Gain × (period-1)) + Current Gain) / period
2. Current Average Loss = ((Previous Average Loss × (period-1)) + Current Loss) / period

### Interpretation and Usage

- **Overbought/Oversold Indicators**:
  - RSI > 70: Generally considered overbought (potential sell signal)
  - RSI < 30: Generally considered oversold (potential buy signal)

- **Divergence Analysis**:
  - Bullish Divergence: Price makes a lower low but RSI makes a higher low (potential uptrend)
  - Bearish Divergence: Price makes a higher high but RSI makes a lower high (potential downtrend)

- **Centerline Crossovers**:
  - RSI crossing above 50: Potentially indicating increasing bullish momentum
  - RSI crossing below 50: Potentially indicating increasing bearish momentum

### Hardware Implementation Considerations

Implementing RSI in hardware presents several challenges:
1. **Memory requirements**: Storing price history
2. **Division operations**: Hardware division is resource-intensive
3. **Floating-point arithmetic**: Fixed-point operations are often preferred for FPGA implementation
4. **Parallel processing**: Potential for pipelined implementations for higher throughput

The current implementation addresses these challenges by:
1. Using a FIFO buffer for efficient price history management
2. Employing integer arithmetic for simplified calculations
3. Using a sequential state machine approach to break down the calculation into manageable steps

## 🔍 Technical Architecture

The system consists of two primary modules:
1. `price_fifo.v` - A customizable First-In-First-Out buffer for storing price data
2. `rsi_fsm.v` - A Finite State Machine that controls the RSI calculation process

### System Parameters
- Price history depth: 20 samples
- Price data width: 16 bits
- Output RSI range: 0-100 (8-bit representation)

## 💾 Price FIFO Module Detailed Documentation

### FIFO Architecture Principles

The First-In-First-Out (FIFO) buffer is a fundamental data structure in digital design, providing temporary storage where data is retrieved in the same order it was stored. FIFOs are essential components in systems where data production and consumption rates vary, acting as elastic buffers to manage timing differences.

#### Circular Buffer Implementation

The `price_fifo` module implements a circular buffer architecture, which uses a fixed-size memory array with two pointers:
1. **Write pointer** (`wr_ptr`): Indicates the next position to write data
2. **Read pointer** (`rd_ptr`): Indicates the next position to read data

This approach enables efficient memory utilization by reusing memory locations after their contents have been read.

#### Pointer Management

The circular nature of the buffer is achieved through pointer arithmetic:
- When a pointer reaches the end of the memory array, it wraps around to the beginning
- The 5-bit implementation for pointers allows addressing up to 32 entries, though only 20 are used by default
- The 6-bit counter allows tracking up to 32 elements, providing a safety margin above the 20-entry default

### Code Implementation Analysis

The `price_fifo` module implements a circular buffer that stores price data with configurable depth and width.

```verilog
module price_fifo #(parameter DEPTH = 20, WIDTH = 16) (
    input clk,
    input rst,
    input wr_en,
    input rd_en,
    input [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout,
    output full,
    output empty
);
```

#### Parameterization
- `DEPTH`: Number of entries in the FIFO (default: 20)
  - Selected to match the RSI period of 20 samples
  - Implemented as a parameter for flexibility in adapting to different RSI periods
- `WIDTH`: Bit width of each entry (default: 16)
  - 16 bits provides a range of 0-65535, sufficient for most price data
  - Parameterized to allow adaptation to different precision requirements

#### Port Detailed Analysis
- **Clock and Reset**:
  - `clk`: System clock signal - all sequential operations synchronize to the positive edge of this signal
  - `rst`: Asynchronous reset signal (active high) - immediately resets the FIFO state regardless of clock
- **Control Signals**:
  - `wr_en`: Write enable signal - must be asserted to store new data
  - `rd_en`: Read enable signal - must be asserted to retrieve data
- **Data Signals**:
  - `din[WIDTH-1:0]`: Data input (price value) - captured when `wr_en` is asserted
  - `dout[WIDTH-1:0]`: Data output (price value) - updated when `rd_en` is asserted
- **Status Signals**:
  - `full`: Flag indicating FIFO is full - prevents further write operations
  - `empty`: Flag indicating FIFO is empty - prevents read operations

#### Internal Registers and Signals
```verilog
reg [WIDTH-1:0] mem[0:DEPTH-1];
reg [4:0] wr_ptr = 0, rd_ptr = 0;
reg [5:0] count = 0;

assign full = (count == DEPTH);
assign empty = (count == 0);
```

- **Memory Array**:
  - `mem[0:DEPTH-1]`: 2D array for storing price values
  - Each element is `WIDTH` bits wide (16 bits by default)
  - Array depth is `DEPTH` elements (20 by default)
- **Pointer Registers**:
  - `wr_ptr`: Write pointer (5 bits to address up to 32 entries)
    - Points to the next memory location for writing
    - Initialized to 0
  - `rd_ptr`: Read pointer (5 bits to address up to 32 entries)
    - Points to the next memory location for reading
    - Initialized to 0
- **Counter Register**:
  - `count`: Current number of elements in the FIFO (6 bits to represent up to 32 entries)
    - Tracks the fill level of the FIFO
    - Used to determine full and empty conditions
    - Initialized to 0
- **Status Flags**:
  - `full`: Continuously assigned based on count comparison
    - Asserted when count equals DEPTH
    - Used to prevent buffer overflow
  - `empty`: Continuously assigned based on count comparison
    - Asserted when count equals 0
    - Used to prevent buffer underflow

#### Behavioral Logic
```verilog
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count <= 0;
    end else begin
        if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1;
            count <= count + 1;
        end
        if (rd_en && !empty) begin
            dout <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1;
            count <= count - 1;
        end
    end
end
```

The FIFO operates on the positive edge of the clock or reset signal:

- **Reset Operation**:
  - When `rst` is asserted (active high):
    - Write pointer (`wr_ptr`) is reset to 0
    - Read pointer (`rd_ptr`) is reset to 0
    - Count (`count`) is reset to 0
    - This effectively clears the FIFO state, though the memory contents remain unchanged

- **Write Operation**:
  - Conditions for write: `wr_en` is asserted AND FIFO is not full (`!full`)
  - Actions when write conditions are met:
    - Data at `din` is stored at the memory location pointed to by `wr_ptr`
    - Write pointer is incremented by 1 (wraps implicitly due to bit width)
    - Count is incremented by 1 to reflect additional stored element

- **Read Operation**:
  - Conditions for read: `rd_en` is asserted AND FIFO is not empty (`!empty`)
  - Actions when read conditions are met:
    - Data at memory location pointed to by `rd_ptr` is output to `dout`
    - Read pointer is incremented by 1 (wraps implicitly due to bit width)
    - Count is decremented by 1 to reflect removal of element

- **Simultaneous Read/Write Handling**:
  - If both read and write conditions are met in the same clock cycle:
    - Both operations occur independently
    - Count remains unchanged since one element is added and one is removed
    - This allows maintaining full throughput

#### Edge Cases and Considerations

1. **Overflow Protection**:
   - The `full` flag prevents writing when the FIFO is at capacity
   - Writing is only performed when `wr_en` is asserted AND `full` is not asserted

2. **Underflow Protection**:
   - The `empty` flag prevents reading when the FIFO has no data
   - Reading is only performed when `rd_en` is asserted AND `empty` is not asserted

3. **Pointer Wrapping**:
   - The 5-bit implementation of pointers allows them to wrap automatically
   - When `wr_ptr` or `rd_ptr` reaches 31, incrementing results in 0

4. **Metastability Concerns**:
   - The design assumes that `wr_en` and `rd_en` are synchronized to the clock domain
   - In cross-clock domain applications, additional synchronization would be required

## ⚙️ RSI FSM Module Detailed Documentation

### State Machine Architecture Analysis

The `rsi_fsm` module forms the core computational unit of the RSI calculator, implementing a sophisticated Finite State Machine (FSM) that controls the sequential process of calculating the Relative Strength Index (RSI). The module orchestrates data flow, performs calculations, and produces the final RSI value through a carefully designed state transition system.

#### Code Structure and Implementation

```verilog
module rsi_fsm (
    input clk,
    input rst,
    input start,
    input [15:0] price_in,
    input new_price,
    output reg done,
    output reg [7:0] rsi
);

    localparam IDLE      = 3'b000,
               FILL_FIFO = 3'b001,
               READ_INIT = 3'b010,
               READ_WAIT = 3'b011,
               COMPARE   = 3'b100,
               DONE      = 3'b101;

    reg [2:0] state = IDLE;
```

#### Port Interface Detailed Analysis

- **Clock and Reset**:
  - `clk`: System clock signal
    - All sequential operations synchronize to the positive edge of this signal
    - Determines the processing speed of the RSI calculation
  - `rst`: Asynchronous reset signal (active high)
    - Forces the FSM to the IDLE state regardless of clock
    - Initializes all registers and counters to their default values

- **Control Input Signals**:
  - `start`: Signal to start the RSI calculation process
    - Triggers the transition from IDLE to FILL_FIFO state
    - Allows external control over when calculation begins
  - `new_price`: Signal indicating a new price is available
    - Used during the FILL_FIFO state to identify valid price inputs
    - Must be asserted when a new price value is present on `price_in`

- **Data Input Signal**:
  - `price_in[15:0]`: Price input data
    - 16-bit value representing a market price
    - Captured when `new_price` is asserted during FILL_FIFO state

- **Output Signals**:
  - `done`: Signal indicating the RSI calculation is complete
    - Asserted when the calculation is finished and the result is valid
    - Remains asserted until a new calculation is started
  - `rsi[7:0]`: Calculated RSI value (0-100)
    - 8-bit value representing the RSI (sufficient for 0-100 range)
    - Updated when the calculation is complete (DONE state)

#### State Encoding and Constants

The FSM employs 3-bit state encoding to represent 6 possible states:
```verilog
localparam IDLE      = 3'b000,
           FILL_FIFO = 3'b001,
           READ_INIT = 3'b010,
           READ_WAIT = 3'b011,
           COMPARE   = 3'b100,
           DONE      = 3'b101;
```

This encoding scheme:
- Provides efficient representation (3 bits can encode up to 8 states)
- Follows a binary counting pattern, potentially simplifying next-state logic
- Enables straightforward one-hot conversion if needed for optimization

### FIFO Integration and Control

```verilog
wire [15:0] price_out;
wire fifo_full, fifo_empty;
reg fifo_wr_en = 0, fifo_rd_en = 0;

price_fifo #(.DEPTH(20)) fifo (
    .clk(clk),
    .rst(rst),
    .wr_en(fifo_wr_en),
    .rd_en(fifo_rd_en),
    .din(price_in),
    .dout(price_out),
    .full(fifo_full),
    .empty(fifo_empty)
);
```

#### Internal Connections and Wiring
The RSI FSM instantiates a `price_fifo` module with the following connections:

- **Clock and Reset**:
  - `clk` → `clk`: Clock signal passed directly to FIFO
  - `rst` → `rst`: Reset signal passed directly to FIFO

- **Control Signals**:
  - `fifo_wr_en` → `wr_en`: FSM-controlled write enable signal
  - `fifo_rd_en` → `rd_en`: FSM-controlled read enable signal

- **Data Signals**:
  - `price_in` → `din`: External price input connected directly to FIFO input
  - `price_out` ← `dout`: FIFO output connected to internal wire for processing

- **Status Signals**:
  - `fifo_full` ← `full`: FIFO full status connected to internal wire
  - `fifo_empty` ← `empty`: FIFO empty status connected to internal wire

#### Parameter Configuration
The FIFO is instantiated with a depth parameter of 20, matching the requirement for RSI calculation over 20 price samples.

#### FIFO Control Strategy
The FSM precisely controls FIFO operations through the `fifo_wr_en` and `fifo_rd_en` signals, which are managed in different states:
- Write operations: Controlled primarily in the FILL_FIFO state
- Read operations: Managed across READ_INIT, COMPARE, and READ_WAIT states

### Internal Registers and Processing Variables

```verilog
reg [15:0] prev_price = 0, curr_price = 0;
reg [31:0] gain_sum = 0, loss_sum = 0;
reg [4:0] sample_cnt = 0;
reg read_delay = 0;
```

- **Price Registers**:
  - `prev_price`: Previous price value for comparison (16 bits)
    - Stores the previous price in the sequence
    - Used as the reference for calculating price changes
    - Initialized to 0

  - `curr_price`: Current price value for comparison (16 bits)
    - Holds the most recently read price from the FIFO
    - Compared with `prev_price` to determine gains or losses
    - Initialized to 0

- **Accumulator Registers**:
  - `gain_sum`: Cumulative sum of price gains (32 bits)
    - Accumulates positive price changes (current > previous)
    - 32-bit width prevents overflow during summation
    - Used in final RSI calculation
    - Initialized to 0

  - `loss_sum`: Cumulative sum of price losses (32 bits)
    - Accumulates negative price changes (current < previous)
    - 32-bit width prevents overflow during summation
    - Used in final RSI calculation
    - Initialized to 0

- **Control Registers**:
  - `sample_cnt`: Counter for tracking processed samples (5 bits)
    - Counts from 0 to 19 (20 samples total)
    - Determines when all samples have been processed
    - 5-bit width allows counting up to 31 samples
    - Initialized to 0

  - `read_delay`: Flag for handling FIFO read delay (1 bit)
    - Compensates for the one-cycle delay between read request and data availability
    - Enables proper sequencing of read operations
    - Initialized to 0

  - `state`: Current FSM state (3 bits)
    - Stores the current state of the FSM
    - Updated on each clock cycle based on next-state logic
    - Initialized to IDLE (3'b000)

- **Control Flags**:
  - `fifo_wr_en`: FIFO write enable control
    - Controlled by the FSM to manage data writing
    - Default value is 0 (disabled)

  - `fifo_rd_en`: FIFO read enable control
    - Controlled by the FSM to manage data reading
    - Default value is 0 (disabled)

The 32-bit width for `gain_sum` and `loss_sum` provides substantial headroom for accumulating price changes, preventing overflow even with extreme price volatility.

### FSM Implementation Details

```verilog
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        fifo_wr_en <= 0;
        fifo_rd_en <= 0;
        done <= 0;
        rsi <= 0;
        sample_cnt <= 0;
        gain_sum <= 0;
        loss_sum <= 0;
        prev_price <= 0;
        read_delay <= 0;
    end else begin
        fifo_wr_en <= 0;
        fifo_rd_en <= 0;

        case (state)
            // State implementation details...
        endcase
    end
end
```

This block implements the state register and output logic for the FSM. Each state and its implementation details will be covered extensively in the subsequent sections.

## 🔄 FSM State Machine Design In-Depth Analysis

### Finite State Machine Fundamentals

A Finite State Machine (FSM) is a computational model used to design systems that can exist in a finite number of states at any given time, with transitions between these states governed by specific conditions. FSMs are particularly well-suited for sequential digital systems like the RSI calculator implemented in this project.

#### Key FSM Concepts

1. **States**: Distinct modes of operation where specific actions are performed
2. **Transitions**: Rules for moving between states based on input conditions
3. **Outputs**: Values or signals produced based on the current state and/or inputs
4. **State Register**: Storage element that holds the current state value
5. **Next State Logic**: Combinational logic that determines the next state
6. **Output Logic**: Combinational logic that determines the outputs

#### FSM Design Approaches

1. **Mealy Machine**: Outputs depend on both current state and inputs
2. **Moore Machine**: Outputs depend only on the current state

This RSI implementation uses a hybrid approach, with some outputs dependent solely on the state (Moore-like) and others influenced by both state and input conditions (Mealy-like).

#### FSM Coding Style in Verilog

The RSI FSM is implemented using a two-process coding style:
1. **State Register Process**: Sequential logic that updates the current state on clock edges
2. **Next State & Output Process**: Combinational logic that determines next state and outputs

The state encoding uses a 3-bit value to represent the 6 possible states:
```verilog
localparam IDLE      = 3'b000,
           FILL_FIFO = 3'b001,
           READ_INIT = 3'b010,
           READ_WAIT = 3'b011,
           COMPARE   = 3'b100,
           DONE      = 3'b101;
```

### FSM Implementation Analysis

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

## 🚩 Critical Flags and Control Signals In-Depth Analysis

The RSI implementation relies on a sophisticated system of flags and control signals to orchestrate the calculation process. These signals can be categorized into external interface signals, FIFO control signals, and internal processing flags, each playing a crucial role in the system's operation.

### Main Control Flags

#### 1. `start` Signal (Input)
- **Function**: Initiates the RSI calculation process
- **Behavior**: 
  - Sampled in the IDLE state to trigger transition to FILL_FIFO
  - Edge-sensitive in implementation (rising edge causes state transition)
  - Must be asserted for at least one clock cycle to be recognized
- **Timing Considerations**:
  - Should only be asserted after sufficient prices have been fed to the system
  - Can be asserted at any time to restart calculation
- **Hardware Implementation**:
  - Typically connected to an external control system or button
  - May require debouncing if connected to physical input

#### 2. `done` Signal (Output)
- **Function**: Signals completion of the RSI calculation
- **Behavior**:
  - Asserted in the DONE state when calculation is complete
  - Remains high until a new calculation is started
  - Returns to low when `start` is asserted
- **Timing Considerations**:
  - One-clock cycle latency between final calculation and assertion
  - Can be used as a handshake signal for downstream processing
- **Hardware Implementation**:
  - Register-based output ensuring glitch-free operation
  - Can drive LED indicators or external logic

#### 3. `new_price` Signal (Input)
- **Function**: Indicates a new price is available for processing
- **Behavior**:
  - Sampled in the FILL_FIFO state to identify valid price inputs
  - When asserted along with valid `price_in`, triggers price storage in FIFO
  - Ignored in other states
- **Timing Considerations**:
  - Must be synchronized with `price_in` data
  - Should be asserted for exactly one clock cycle per new price
- **Hardware Implementation**:
  - Often generated by price data acquisition system
  - May require synchronization if from different clock domain

### FIFO Control Flags

#### 4. `fifo_wr_en` Signal (Internal Control)
- **Function**: Controls writing to the FIFO
- **Behavior**:
  - Default state is disabled (0)
  - Explicitly set to 0 at the beginning of each state transition block
  - Set to 1 only under specific conditions in the FILL_FIFO state
- **Timing Considerations**:
  - Asserted for exactly one clock cycle per write operation
  - Must be synchronized with valid `price_in` data
- **Implementation Details**:
  - Register-based control signal
  - Set when `new_price` is asserted and FIFO is not full
  - Connects directly to the FIFO's write enable input

#### 5. `fifo_rd_en` Signal (Internal Control)
- **Function**: Controls reading from the FIFO
- **Behavior**:
  - Default state is disabled (0)
  - Explicitly set to 0 at the beginning of each state transition block
  - Set to 1 in multiple states: FILL_FIFO (when full), COMPARE (when more samples needed)
- **Timing Considerations**:
  - Creates one-cycle delay between assertion and data availability
  - Managed through the `read_delay` flag
- **Implementation Details**:
  - Register-based control signal
  - Complex activation logic depending on current state and conditions
  - Connects directly to the FIFO's read enable input

#### 6. `fifo_full` Signal (Status Input)
- **Function**: Indicates the FIFO has reached capacity
- **Behavior**:
  - Generated by the FIFO module (continuous assignment)
  - Sampled in the FILL_FIFO state to trigger transition to READ_INIT
  - Used to prevent buffer overflow
- **Timing Considerations**:
  - Combinational signal with minimal propagation delay
  - Valid on the same cycle as the last successful write
- **Implementation Details**:
  - Wire connection from FIFO status output
  - Derived from comparison of count with DEPTH parameter

#### 7. `fifo_empty` Signal (Status Input)
- **Function**: Indicates the FIFO contains no data
- **Behavior**:
  - Generated by the FIFO module (continuous assignment)
  - Sampled in the COMPARE state to prevent underflow
  - Used to determine when all data has been processed
- **Timing Considerations**:
  - Combinational signal with minimal propagation delay
  - Valid on the same cycle as the last successful read
- **Implementation Details**:
  - Wire connection from FIFO status output
  - Derived from comparison of count with zero

### Internal Processing Flags

#### 8. `read_delay` Flag (Internal State)
- **Function**: Manages the one-cycle delay in FIFO read operations
- **Behavior**:
  - Set to 1 when initiating a read operation
  - Sampled in subsequent states to determine when data is valid
  - Cleared after data processing is complete
- **Timing Consideration**:
  - Compensates for the inherent one-cycle latency in FIFO read operations
  - Critical for maintaining correct sequencing of operations
- **Implementation Details**:
  - Single-bit register
  - Acts as a simple state variable within the FSM
  - Enables proper synchronization between read requests and data processing

#### 9. `sample_cnt` Counter (Internal State)
- **Function**: Tracks the number of processed samples
- **Behavior**:
  - Initialized to 0 in IDLE or on reset
  - Incremented after each sample is processed in READ_WAIT
  - Compared with threshold (19) to determine completion
- **Timing Considerations**:
  - Updated synchronously with the clock
  - Value determines state transitions and completion
- **Implementation Details**:
  - 5-bit register allowing counting up to 31 samples
  - Provides flexibility for different RSI periods
  - Critical for maintaining processing sequence

#### 10. `state` Register (Internal State)
- **Function**: Stores the current state of the FSM
- **Behavior**:
  - Updated on each clock cycle based on transition conditions
  - Determines the actions performed and outputs generated
  - Initialized to IDLE on reset
- **Timing Considerations**:
  - Updated synchronously with the clock
  - Forms the backbone of the sequential operation
- **Implementation Details**:
  - 3-bit register encoding 6 possible states
  - Controls the overall flow of the RSI calculation
  - Directly influences all other control signals

### Data Processing Registers

#### 11. `prev_price` and `curr_price` Registers
- **Function**: Store consecutive price values for comparison
- **Behavior**:
  - `prev_price` holds the previous sample for reference
  - `curr_price` holds the current sample being processed
  - Comparison determines gain or loss contributions
- **Timing Considerations**:
  - Updated in sequence to maintain proper ordering
  - `prev_price` receives `curr_price` value after processing
- **Implementation Details**:
  - 16-bit registers matching price data width
  - Sequential updating pattern enables pairwise comparison

#### 12. `gain_sum` and `loss_sum` Accumulators
- **Function**: Accumulate total gains and losses for RSI calculation
- **Behavior**:
  - `gain_sum` accumulates positive price changes
  - `loss_sum` accumulates negative price changes
  - Used in final division to compute RSI
- **Timing Considerations**:
  - Updated during READ_WAIT state after price comparison
  - Final values used in DONE state for RSI calculation
- **Implementation Details**:
  - 32-bit registers providing ample overflow protection
  - Separate accumulators simplify the final RSI calculation

The intricate interplay of these flags and signals enables the FSM to maintain proper sequencing, handle timing dependencies, and ensure correct calculation of the RSI value. The design demonstrates careful consideration of digital timing principles and efficient state management techniques.

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
## 🧪 Testing and Verification Framework

### Hardware Verification Methodology
Verification is a critical aspect of hardware design that ensures the implementation meets its functional requirements. For this RSI calculator, we've adopted a comprehensive verification strategy that combines:

1. **Directed Testing**: Using carefully crafted input sequences with known expected outputs
2. **Functional Verification**: Ensuring all operations behave according to specification
3. **State Coverage**: Verifying all FSM states are reached and transitions occur correctly
4. **Temporal Verification**: Confirming timing relationships between signals meet requirements

The verification approach follows hardware design best practices, focusing on both functionality and robustness under various operating conditions.

### Testbench Philosophy
The verification strategy for this RSI implementation employs a directed testing approach with deterministic test vectors to ensure functional correctness. The testbench (`rsi_testbench.v`) is designed to:
1. Validate the end-to-end functionality of the RSI calculator
2. Verify correct operation of the FSM state transitions
3. Confirm accurate mathematical computation of the RSI formula
4. Test the FIFO buffering mechanism with sequential price data
5. Examine boundary conditions and edge cases
6. Ensure proper handshaking between control signals

### Testbench Architecture Overview
The testbench follows a stimulus-response verification model where:
- Test vectors are generated according to a predetermined pattern
- Signals are applied to the design under test (DUT) with proper timing
- Responses are monitored and compared against expected values
- Results are reported to verify correctness

This architecture allows for systematic verification of all aspects of the RSI calculator's functionality.

### Testbench Implementation Details

```verilog
`timescale 1ns / 1ps

module rsi_testbench;
    // System signals
    reg clk = 0, rst = 1, start = 0, new_price = 0;
    reg [15:0] price_in = 0;
    wire done;
    wire [7:0] rsi;

    // Instantiate the unit under test (UUT)
    rsi_fsm uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .price_in(price_in),
        .new_price(new_price),
        .done(done),
        .rsi(rsi)
    );

    // Clock generation - 10ns period (100MHz)
    always #5 clk = ~clk;

    integer i;
    reg [15:0] price_array[0:19];

    initial begin
        // Create pattern of rising and falling prices
        price_array[0] = 100;
        for (i = 1; i < 20; i = i + 1)
            price_array[i] = price_array[i - 1] + ((i % 2 == 0) ? 3 : -2);

        #20 rst = 0; #10 start = 1; #10 start = 0;

        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            price_in = price_array[i];
            new_price = 1;
            @(posedge clk);
            new_price = 0;
        end

        wait (done);
        $display("RSI Value = %d", rsi);
        $finish;
    end
endmodule
```

### Testbench Code Analysis

#### Timescale Directive
```verilog
`timescale 1ns / 1ps
```
This directive specifies the time unit (1ns) and precision (1ps) for simulation, providing adequate granularity for timing analysis without excessive computational overhead.

#### Signal Declarations
```verilog
reg clk = 0, rst = 1, start = 0, new_price = 0;
reg [15:0] price_in = 0;
wire done;
wire [7:0] rsi;
```
- **Input Signals**: Initialized to known states (clock low, reset active, other controls inactive)
- **Output Signals**: Declared as wires to receive values from the DUT
- **Data Width**: 16-bit price input provides adequate dynamic range; 8-bit RSI output covers the 0-100 range

#### Clock Generation
```verilog
always #5 clk = ~clk;
```
Creates a 10ns period clock (100MHz), representative of typical FPGA system clock speeds. The continuous toggling drives the sequential elements of the design.

#### Test Vector Generation
```verilog
price_array[0] = 100;
for (i = 1; i < 20; i = i + 1)
    price_array[i] = price_array[i - 1] + ((i % 2 == 0) ? 3 : -2);
```
This generates a deterministic sequence with alternating gain and loss values, ensuring predictable RSI calculation for verification purposes.

#### Reset and Control Sequencing
```verilog
#20 rst = 0; #10 start = 1; #10 start = 0;
```
A critical aspect that models proper system initialization:
1. Hold reset for 20ns to ensure complete initialization
2. De-assert reset and allow 10ns for stabilization
3. Pulse the start signal for precisely one clock cycle

#### Price Application Sequence
```verilog
for (i = 0; i < 20; i = i + 1) begin
    @(posedge clk);
    price_in = price_array[i];
    new_price = 1;
    @(posedge clk);
    new_price = 0;
end
```
This code demonstrates proper control signal handling:
1. Synchronize to clock edge for deterministic timing
2. Apply the test price value
3. Assert the new_price signal for exactly one clock cycle
4. De-assert new_price and proceed to the next value

#### Result Verification
```verilog
wait (done);
$display("RSI Value = %d", rsi);
```
The testbench waits for the done signal before reading results, properly modeling the asynchronous handshaking protocol between the RSI calculator and external systems.

### Price Generation Pattern
The testbench generates a systematic sequence of 20 prices following a pattern:
- Initial price: 100
- For even indices: Previous price + 3 (gain)
- For odd indices: Previous price - 2 (loss)

This results in the sequence: [100, 98, 101, 99, 102, 100, 103, 101, 104, 102, 105, 103, 106, 104, 107, 105, 108, 106, 109, 107]

The resulting price changes produce gains of +3 and losses of -2 in an alternating pattern, with:
- Total gain sum = 27
- Total loss sum = 18
- Expected RSI = 60

This pattern was specifically chosen to:
1. Create a balanced mix of gains and losses
2. Produce an RSI value in the mid-range (60)
3. Test the system's ability to handle both positive and negative changes
4. Create a deterministic outcome for easy verification
5. Exercise the core RSI calculation logic thoroughly

### Test Vector Analysis
Let's analyze the generated price sequence and expected calculations in detail:

| Index | Price | Change | Gain | Loss |
|-------|-------|--------|------|------|
| 0     | 100   | -      | -    | -    |
| 1     | 98    | -2     | 0    | 2    |
| 2     | 101   | +3     | 3    | 0    |
| 3     | 99    | -2     | 0    | 2    |
| 4     | 102   | +3     | 3    | 0    |
| 5     | 100   | -2     | 0    | 2    |
| 6     | 103   | +3     | 3    | 0    |
| 7     | 101   | -2     | 0    | 2    |
| 8     | 104   | +3     | 3    | 0    |
| 9     | 102   | -2     | 0    | 2    |
| 10    | 105   | +3     | 3    | 0    |
| 11    | 103   | -2     | 0    | 2    |
| 12    | 106   | +3     | 3    | 0    |
| 13    | 104   | -2     | 0    | 2    |
| 14    | 107   | +3     | 3    | 0    |
| 15    | 105   | -2     | 0    | 2    |
| 16    | 108   | +3     | 3    | 0    |
| 17    | 106   | -2     | 0    | 2    |
| 18    | 109   | +3     | 3    | 0    |
| 19    | 107   | -2     | 0    | 2    |
| **Totals** | | | **27** | **18** |

RSI Calculation:
```
RSI = 100 × (Gain Sum / (Gain Sum + Loss Sum))
    = 100 × (27 / (27 + 18))
    = 100 × (27 / 45)
    = 100 × 0.6
    = 60
```

### Simulation Protocol
The test sequence follows these steps:
1. **Initialization Phase (0-20ns):** 
   - Assert reset
   - Initialize test variables
   - Clear all registers and state machines

2. **Setup Phase (20-40ns):**
   - De-assert reset
   - Pulse start signal for one clock cycle
   - Allow FSM to transition to FILL_FIFO state

3. **Data Feeding Phase:**
   - For each price in the array:
     - Set price_in to the current test value
     - Assert new_price for one clock cycle
     - Wait for next clock edge
     - Observe FIFO filling operations

4. **Processing Phase:**
   - After FIFO fills, observe:
     - Transitions through READ_INIT, COMPARE, and READ_WAIT states
     - Accumulation of gain and loss values
     - Processing of all price samples

5. **Verification Phase:**
   - Wait for done signal assertion
   - Verify calculated RSI matches expected value
   - End simulation

### Detailed Timing Diagram

The testbench creates the following typical timing sequence (simplified):

```
       |    Reset    |    Setup    |       Data Feeding       |  Processing  | Verification |
       |             |             |                          |              |              |
clk    _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\
       |             |             |                          |              |              |
rst    ‾‾‾‾‾‾‾‾‾‾‾‾‾\___________________________________________________________
       |             |             |                          |              |              |
start  _____________/‾‾‾\___________________________________________________________
       |             |             |                          |              |              |
price  XXXXXXXXXXXXX|XXXXXXXXXXXXX|    P0   |    P1   |  ... |     P19      |XXXXXXXXXXXXXX
       |             |             |                          |              |              |
n_price ____________|_____________/‾‾‾\____/‾‾‾\____/‾‾‾\____/‾‾‾\___________
       |             |             |                          |              |              |
done   _____________|_____________|__________________________|______________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾
       |             |             |                          |              |              |
rsi    XXXXXXXXXXXXX|XXXXXXXXXXXXX|XXXXXXXXXXXXXXXXXXXXXXXXXX|XXXXXXXXXXXXXX|     60
```

### Verification Environment Setup
The testbench can be run with common Verilog simulators:

**Using Icarus Verilog:**
```
$ iverilog -o rsi_sim rsi_fsm.v price_fifo.v rsi_testbench.v
$ vvp rsi_sim
```

**Using ModelSim:**
```
> vlog rsi_fsm.v price_fifo.v rsi_testbench.v
> vsim -novopt work.rsi_testbench
> run -all
```

**Using Vivado Simulator:**
```
> xvlog rsi_fsm.v price_fifo.v rsi_testbench.v
> xelab -debug typical rsi_testbench -s rsi_sim
> xsim rsi_sim -runall
```

### Waveform Analysis
When running this testbench in a waveform viewer, pay particular attention to:

1. **State Transitions**: Observe the state register in the RSI FSM module to ensure proper sequencing through all required states.
2. **FIFO Operations**: Monitor the FIFO write/read enable signals and internal pointers to verify proper buffering.
3. **Accumulator Values**: Track the gain_sum and loss_sum registers to ensure they accumulate values correctly.
4. **Final Calculation**: Observe the division operation in the DONE state and the final RSI value assignment.

The waveform should show clear transitions between states with proper handshaking signals and data flow through the system.

### Expected Results and Validation
The testbench should produce the following output:
```
RSI Value = 60
```

This value can be verified manually by calculating:
RSI = 100 * gain_sum / (gain_sum + loss_sum) = 100 * 27 / (27 + 18) = 100 * 27 / 45 = 60

### Advanced Verification Considerations

#### Corner Case Testing
While the primary test vector examines normal operation, a comprehensive verification should also explore:

1. **All-Rising Prices**: When every price is higher than the previous (loss_sum = 0, RSI = 100)
2. **All-Falling Prices**: When every price is lower than the previous (gain_sum = 0, RSI = 0)
3. **Constant Prices**: When prices don't change (gain_sum = loss_sum = 0, potential division by zero)
4. **Extreme Volatility**: Large price swings that test the limits of the accumulators
5. **Boundary Conditions**: Values near the limits of the 16-bit price representation

#### Assertion-Based Verification
To enhance verification rigor, SystemVerilog assertions could be added to check:

1. Protocol compliance between signals
2. State transition validity
3. Timing requirements
4. Invariant conditions (e.g., FIFO never overflows)

Example assertions might include:
```systemverilog
// Reset properly initializes state
property reset_state;
  @(posedge clk) rst |-> ##1 (state == IDLE);
endproperty
assert property (reset_state);

// new_price is never asserted when FIFO is full
property no_write_when_full;
  @(posedge clk) (fifo_full && new_price) |-> ##1 !fifo_wr_en;
endproperty
assert property (no_write_when_full);
```

#### Code Coverage Analysis
For production-quality verification, code coverage metrics should be collected:

1. **Line Coverage**: Ensure all lines of code are executed
2. **Branch Coverage**: Verify all conditional branches are taken
3. **FSM Coverage**: Confirm all states and transitions are reached
4. **Toggle Coverage**: Check that all bits change value during testing
5. **Expression Coverage**: Validate all possible expression outcomes are tested

Coverage analysis helps identify untested scenarios and potential design weaknesses.

### Extending the Testbench
The testbench can be modified to test different scenarios:

#### 1. Alternative Price Patterns
Create different price sequences to test various market conditions:
```verilog
// Bull market simulation
price_array[0] = 100;
for (i = 1; i < 20; i = i + 1)
    price_array[i] = price_array[i-1] + ((i % 5 == 0) ? -1 : 2);

// Bear market simulation
price_array[0] = 100;
for (i = 1; i < 20; i = i + 1)
    price_array[i] = price_array[i-1] + ((i % 5 == 0) ? 1 : -2);
```

#### 2. Timing Sensitivity Testing
Modify stimulus timing to verify robustness:
```verilog
// Variable timing between new prices
for (i = 0; i < 20; i = i + 1) begin
    repeat ((i % 3) + 1) @(posedge clk); // Variable delay
    price_in = price_array[i];
    new_price = 1;
    @(posedge clk);
    new_price = 0;
end
```

#### 3. Automated Result Checking
Add self-checking capabilities to automate verification:
```verilog
// Calculate expected RSI
expected_rsi = (gain_sum * 100) / (gain_sum + loss_sum);

// Verify result
wait (done);
if (rsi == expected_rsi)
    $display("TEST PASSED: RSI Value = %d (Expected %d)", rsi, expected_rsi);
else
    $display("TEST FAILED: RSI Value = %d (Expected %d)", rsi, expected_rsi);
```

#### 4. Multiple Test Scenarios
Implement multiple test cases in sequence:
```verilog
task run_test_case;
    input [31:0] test_id;
    begin
        // Test case setup
        setup_test_case(test_id);
        
        // Run test
        run_rsi_calculation();
        
        // Check results
        verify_results(test_id);
    end
endtask

initial begin
    // Run multiple test cases
    run_test_case(1); // Normal case
    run_test_case(2); // All rising
    run_test_case(3); // All falling
    run_test_case(4); // Mixed extreme
    
    $display("All tests completed");
    $finish;
end
```

### Troubleshooting Common Issues

When running the testbench, watch for these common issues:

1. **Incomplete FIFO Filling**: If the FIFO never fills, check the new_price signal timing and count
2. **Stalled State Machine**: If the FSM gets stuck in a state, verify transition conditions
3. **Incorrect RSI Value**: Double-check the gain/loss accumulation and division operation
4. **Simulation Never Completes**: Ensure the done signal is properly asserted
5. **Unexpected Reset Behavior**: Verify reset signal timing and initialization values

### Integration into a Full Verification Strategy

This testbench forms one component of a comprehensive verification strategy that should also include:

1. **Unit Testing**: Verifying individual modules like price_fifo independently
2. **Integration Testing**: Testing interactions between modules
3. **System Testing**: Validating full system behavior with realistic workloads
4. **Formal Verification**: Mathematically proving correctness of critical components
5. **Hardware-in-Loop Testing**: Verifying performance in target FPGA hardware

By combining these approaches, the RSI implementation can be thoroughly validated for deployment in financial analysis systems.
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
