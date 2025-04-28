# RSI Hardware Implementation using Verilog

## 📌 Introduction
This project implements RSI (Relative Strength Index) calculation using Verilog for FPGA. It uses a FIFO for storing prices and an FSM for step-by-step RSI computation.

## 🎯 Objective
Calculate RSI for 20 prices using hardware logic, useful in trading systems for trend detection.

## 🧩 Modules

### `price_fifo.v`
- Stores 20 prices (FIFO buffer)
- Controls: `wr_en`, `rd_en`, `full`, `empty`, `dout`

### `rsi_fsm.v`
- FSM states: IDLE, FILL_FIFO, READ_INIT, COMPARE, DONE
- Computes gain/loss per step and final RSI

## 📊 Sample Prices (20)
100, 98, 101, 99, 102, 100, 103, 101, 104, 102, 105, 103, 106, 104, 107, 105, 108, 106, 109, 107

## 🧮 Manual RSI Calculation
- Gain = 27, Loss = 18
- RSI = 100 * 27 / (27 + 18) = 60

## ✅ Simulation Output
- `gain_sum = 27`, `loss_sum = 18`
- `rsi = 60`
