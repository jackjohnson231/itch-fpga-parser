# FPGA Market-Data Parser (NASDAQ ITCH 5.0)

A low-latency, synthesizable SystemVerilog parser for NASDAQ TotalView-ITCH 5.0
market-data messages, targeting the Digilent Arty A7 (Xilinx Artix-7).

> **Status:** early development. Toolchain and simulation loop verified.
> Parser, order book, and on-hardware results to follow.

## Goal

Parse a stream of ITCH messages at line rate in hardware, extract order-book
events, and maintain top-of-book state — the kind of low-latency packet
processing used in electronic trading systems.

## Toolchain

- **Simulation:** Icarus Verilog (`iverilog`) + waveform viewer
- **Synthesis (planned):** Xilinx Vivado, targeting Arty A7

## Build & simulate

```
iverilog -g2012 -o blinky.vvp blinky.sv tb_blinky.sv
vvp blinky.vvp
```

## Roadmap

- [x] Toolchain + simulation loop verified
- [ ] ITCH message framing
- [ ] Single-message field extraction (Add Order)
- [ ] Pipelined multi-message parser
- [ ] Top-of-book order book (BRAM)
- [ ] Synthesis + on-board results (utilization, timing)
