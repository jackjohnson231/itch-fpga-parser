#!/usr/bin/env python3
"""
Golden-vector generator for NASDAQ ITCH 5.0 Add Order ('A') messages.

Emits:
  vectors/stimulus.hex  - byte stream for $readmemh, one byte per line
  vectors/expected.txt  - decoded field values for testbench comparison
"""

import random

# --- Reproducibility -------------------------------------------------
SEED = 42
random.seed(SEED)

# --- Message framing -------------------------------------------------
LEN_PREFIX_BYTES = 2      # big-endian length prefix precedes each message
MSG_TYPE         = b'A'   # Add Order
MSG_LEN          = 36     # bytes, excluding the length prefix

# --- Field layout: (name, offset, width) -----------------------------
# Offsets are relative to the start of the message; type byte is offset 0.
FIELDS = [
    ("msg_type",      0, 1),
    ("stock_locate",  1, 2),
    ("tracking_num",  3, 2),
    ("timestamp",     5, 6),
    ("order_ref",    11, 8),
    ("buy_sell",     19, 1),
    ("shares",       20, 4),
    ("stock",        24, 8),
    ("price",        32, 4),
]

# --- Run configuration -----------------------------------------------
NUM_MESSAGES  = 50
STIMULUS_PATH = "vectors/stimulus.hex"
EXPECTED_PATH = "vectors/expected.txt"

# --- Layout self-check -----------------------------------------------
_total = sum(w for _, _, w in FIELDS)
assert _total == MSG_LEN, f"Field widths sum to {_total}, expected {MSG_LEN}"

# --- Value generation ------------------------------------------------
SYMBOLS = ["AAPL", "MSFT", "SPY", "NVDA"]

# Market open: 9:30:00 AM in nanoseconds since midnight
MARKET_OPEN_NS = 34200 * 1_000_000_000


def make_message_values(index, timestamp):
    """Return a dict of field values for one Add Order message."""
    return {
        "msg_type":     ord('A'),
        "stock_locate": random.randint(1, 1000),
        "tracking_num": 0,
        "timestamp":    timestamp,
        "order_ref":    index + 1,
        "buy_sell":     ord(random.choice(['B', 'S'])),
        "shares":       random.randint(1, 10000),
        "stock":        random.choice(SYMBOLS),
        "price":        random.randint(1_0000, 500_0000),
    }


def make_all_messages(n):
    """Return a list of n message dicts with monotonic timestamps."""
    messages = []
    timestamp = MARKET_OPEN_NS
    for i in range(n):
        messages.append(make_message_values(i, timestamp))
        timestamp += random.randint(1000, 100000)
    return messages

# --- Encoding --------------------------------------------------------
def encode_message(values):
    """Pack a message dict into exactly MSG_LEN bytes, big-endian."""
    out = bytearray()
    for name, offset, width in FIELDS:
        assert len(out) == offset, \
            f"Field {name} should start at {offset}, but stream is at {len(out)}"
        if name == "stock":
            out += values[name].ljust(width).encode("ascii")
        else:
            out += values[name].to_bytes(width, "big")
    assert len(out) == MSG_LEN, f"Encoded {len(out)} bytes, expected {MSG_LEN}"
    return bytes(out)

# --- Stream assembly -------------------------------------------------
def build_stream(messages):
    """Concatenate length-prefixed messages into one byte stream."""
    stream = bytearray()
    for m in messages:
        body = encode_message(m)
        stream += len(body).to_bytes(LEN_PREFIX_BYTES, "big")
        stream += body
    return bytes(stream)


def write_stimulus(stream, path):
    """Write the stream one byte per line as two hex digits, for $readmemh."""
    with open(path, "w") as f:
        for b in stream:
            f.write(f"{b:02x}\n")

# --- Expected-value output -------------------------------------------
EXPECTED_ORDER = [name for name, _, _ in FIELDS]


def format_expected(values):
    """Render one message as a space-separated line for $fscanf."""
    parts = []
    for name, _, width in FIELDS:
        if name == "stock":
            sym_bytes = values[name].ljust(width).encode("ascii")
            parts.append(sym_bytes.hex())
        else:
            parts.append(str(values[name]))
    return " ".join(parts)


def write_expected(messages, path):
    """Write one line per message, fields in FIELDS order."""
    with open(path, "w") as f:
        for m in messages:
            f.write(format_expected(m) + "\n")

# --- Self-verification -----------------------------------------------
def read_stimulus(path):
    """Read the hex file back into a bytes object."""
    with open(path) as f:
        return bytes(int(line, 16) for line in f if line.strip())


def decode_stream(stream):
    """Walk the stream using length prefixes; return a list of field lines."""
    lines = []
    pos = 0
    while pos < len(stream):
        length = int.from_bytes(stream[pos:pos + LEN_PREFIX_BYTES], "big")
        pos += LEN_PREFIX_BYTES
        body = stream[pos:pos + length]
        assert len(body) == length, f"Truncated message at byte {pos}"
        pos += length

        parts = []
        for name, offset, width in FIELDS:
            raw = body[offset:offset + width]
            if name == "stock":
                parts.append(raw.hex())
            else:
                parts.append(str(int.from_bytes(raw, "big")))
        lines.append(" ".join(parts))
    return lines


def self_check(stimulus_path, expected_path):
    """Decode the stimulus independently and compare against expected.txt."""
    decoded = decode_stream(read_stimulus(stimulus_path))
    with open(expected_path) as f:
        expected = [line.strip() for line in f if line.strip()]

    assert len(decoded) == len(expected), \
        f"Decoded {len(decoded)} messages, expected file has {len(expected)}"

    for i, (d, e) in enumerate(zip(decoded, expected)):
        if d != e:
            print(f"MISMATCH on message {i}")
            print(f"  decoded:  {d}")
            print(f"  expected: {e}")
            for name, dv, ev in zip(EXPECTED_ORDER, d.split(), e.split()):
                if dv != ev:
                    print(f"  field '{name}': got {dv}, expected {ev}")
            return False
    print(f"SELF-CHECK PASSED: {len(decoded)} messages verified")
    return True



if __name__ == "__main__":
    print(f"Layout OK: {len(FIELDS)} fields, {_total} bytes")
    msgs = make_all_messages(NUM_MESSAGES)
    stream = build_stream(msgs)
    write_stimulus(stream, STIMULUS_PATH)
    expected_bytes = NUM_MESSAGES * (LEN_PREFIX_BYTES + MSG_LEN)
    assert len(stream) == expected_bytes, \
        f"Stream is {len(stream)} bytes, expected {expected_bytes}"
    write_expected(msgs, EXPECTED_PATH)
    print(f"Wrote {EXPECTED_PATH}: {NUM_MESSAGES} lines")
    print(f"Wrote {STIMULUS_PATH}: {NUM_MESSAGES} messages, {len(stream)} bytes")
    self_check(STIMULUS_PATH, EXPECTED_PATH)