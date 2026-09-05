# ITCH FPGA Parser

A NASDAQ TotalView-ITCH 5.0 protocol parser written in SystemVerilog, targeting
the Xilinx Artix-7 (XC7A100T / Digilent Arty A7).

The design consumes a raw byte stream, frames it into ITCH messages, and decodes
message fields into parallel registers — the kind of line-rate packet processing
used in electronic trading systems.

**Status:** framer and Add Order decoder complete and verified in simulation
against a Python golden model. Synthesis results and additional message types
in progress.

## Architecture

```
byte stream ──▶ itch_framer ──▶ itch_decoder ──▶ decoded fields
                (FSM)            (field extract)
```

**`rtl/itch_framer.sv`** — a five-state FSM (`LEN_HI → LEN_LO → TYPE → PAYLOAD
→ DONE`) that reads the 2-byte big-endian length header, latches the message
type, and emits payload bytes with an index and end-of-packet flag. Uses a
`valid`/`ready` handshake on both interfaces, so the design tolerates stalls
from either the upstream source or the downstream consumer.

**`rtl/itch_decoder.sv`** — consumes the framer's indexed payload stream and
assembles the eight Add Order fields. Multi-byte fields are built by shift
assembly, which handles the protocol's big-endian wire order without explicit
byte swapping. Price is kept as a raw 32-bit integer with four implied decimal
places; no division is performed in hardware.

### Design notes

Two details worth calling out, both concerning cycle-accurate correctness:

- `s_ready` is deasserted in the `DONE` state. That cycle consumes no input, so
  holding ready high would complete a handshake for a byte that never gets
  stored — silently dropping the first length byte of the next message and
  desynchronising the stream permanently.
- `d_valid` is registered rather than combinational, so it pulses one cycle
  after the final payload byte. A combinational pulse would assert while the
  last byte was still in flight, and a downstream consumer would latch a stale
  price.

## Verification

A Python golden model (`tools/gen_vectors.py`) generates both the raw byte
stimulus and the expected decoded output, so the RTL is checked against an
independent implementation of the spec rather than against itself.

| Testbench | Checks |
|---|---|
| `tb/tb_itch_framer.sv` | payload index sequence, message type, `m_eop` placement, message count |
| `tb/tb_itch_top.sv` | all eight decoded fields per message, against `vectors/expected.txt` |

Both drive the input with randomised stall injection — `s_valid` is deasserted
on roughly 20% of cycles — so the backpressure path is exercised on every run
rather than only under ideal streaming.

Current result: **50 messages, 450 field comparisons, 0 errors.**

## Build and simulate

Framer only:

```
iverilog -g2012 -o /tmp/tb_framer tb/tb_itch_framer.sv rtl/itch_framer.sv
vvp /tmp/tb_framer
```

Full parser:

```
iverilog -g2012 -o /tmp/tb_top tb/tb_itch_top.sv rtl/itch_framer.sv rtl/itch_decoder.sv
vvp /tmp/tb_top
```

Regenerate vectors:

```
python3 tools/gen_vectors.py
```

Waveforms are dumped to `framer.vcd` / `top.vcd`.

## Repository layout

```
rtl/       synthesisable SystemVerilog
tb/        testbenches
tools/     Python golden model and vector generation
vectors/   generated stimulus and expected output
```

## Roadmap

- [x] Toolchain and simulation loop
- [x] ITCH message framing with valid/ready backpressure
- [x] Add Order field extraction
- [x] End-to-end verification against golden model
- [ ] Additional message types (E, X, D, U)
- [ ] Vivado synthesis and implementation on XC7A100T
- [ ] Timing closure; Fmax, WNS and utilisation figures
- [ ] Top-of-book order book state

## Limitations

- Verified in simulation only; no synthesis or on-hardware results yet.
- Only Add Order (`A`) messages are decoded. Other types are framed correctly
  but their payloads are ignored.
- The framer testbench hardcodes the payload length for a 36-byte Add Order and
  will need generalising when variable-length message types are added.