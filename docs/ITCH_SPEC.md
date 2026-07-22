# ITCH 5.0 Parser — Message Spec Reference

Byte-layout reference for the message types this parser targets.
Source: NASDAQ TotalView-ITCH 5.0 official specification.

## Global rules (apply to every message)

- **Integers:** unsigned, big-endian (network byte order).
- **Alpha:** ASCII, left-justified, right-padded with spaces.
- **Price:** integer with implied fixed-point precision. `Price(4)` = 4 implied
  decimal places (divide the integer by 10,000 to get dollars).
- **Timestamp:** 6 bytes, nanoseconds since midnight. (Note: 6 bytes in 5.0,
  not 4 — do not trust older examples.)
- **Stock symbol:** 8 bytes, ASCII, space-padded.

## Offset convention used here

Offsets below are **relative to the start of the message payload** (i.e. byte 0
is the Message Type character). In a live feed each message is preceded by a
2-byte big-endian length in the MoldUDP/framing layer — your framing FSM handles
that separately, then hands the payload to the field extractor using these
offsets.

Every message begins with the same 11-byte header:

| Offset | Bytes | Field                | Type    | Notes                          |
|--------|-------|----------------------|---------|--------------------------------|
| 0      | 1     | Message Type         | Alpha   | The type char ('A','E','X','D')|
| 1      | 2     | Stock Locate         | Integer | Locate code for the security   |
| 3      | 2     | Tracking Number      | Integer | Nasdaq internal tracking       |
| 5      | 6     | Timestamp            | Integer | Nanoseconds since midnight     |

Message-specific fields follow at offset 11.

---

## Add Order — No MPID Attribution ('A')

Total length: **36 bytes**

| Offset | Bytes | Field                | Type      | Notes                         |
|--------|-------|----------------------|-----------|-------------------------------|
| 0      | 1     | Message Type = 'A'   | Alpha     |                               |
| 1      | 2     | Stock Locate         | Integer   |                               |
| 3      | 2     | Tracking Number      | Integer   |                               |
| 5      | 6     | Timestamp            | Integer   | ns since midnight             |
| 11     | 8     | Order Reference No.  | Integer   | Unique order ID               |
| 19     | 1     | Buy/Sell Indicator   | Alpha     | 'B' = buy, 'S' = sell         |
| 20     | 4     | Shares               | Integer   | Order quantity                |
| 24     | 8     | Stock Symbol         | Alpha     | Space-padded                  |
| 32     | 4     | Price                | Price(4)  | Divide by 10,000 for dollars  |

This is the richest message and the one to implement first (M1.1).

---

## Order Executed ('E')

Total length: **31 bytes**

| Offset | Bytes | Field                | Type    | Notes                          |
|--------|-------|----------------------|---------|--------------------------------|
| 0      | 1     | Message Type = 'E'   | Alpha   |                                |
| 1      | 2     | Stock Locate         | Integer |                                |
| 3      | 2     | Tracking Number      | Integer |                                |
| 5      | 6     | Timestamp            | Integer | ns since midnight              |
| 11     | 8     | Order Reference No.  | Integer | Which resting order executed   |
| 19     | 4     | Executed Shares      | Integer | Quantity executed              |
| 23     | 8     | Match Number         | Integer | Unique execution ID            |

---

## Order Cancel ('X')

Total length: **23 bytes**

| Offset | Bytes | Field                | Type    | Notes                          |
|--------|-------|----------------------|---------|--------------------------------|
| 0      | 1     | Message Type = 'X'   | Alpha   |                                |
| 1      | 2     | Stock Locate         | Integer |                                |
| 3      | 2     | Tracking Number      | Integer |                                |
| 5      | 6     | Timestamp            | Integer | ns since midnight              |
| 11     | 8     | Order Reference No.  | Integer | Which resting order to reduce  |
| 19     | 4     | Cancelled Shares     | Integer | Quantity removed (partial)     |

---

## Order Delete ('D')

Total length: **19 bytes**

| Offset | Bytes | Field                | Type    | Notes                          |
|--------|-------|----------------------|---------|--------------------------------|
| 0      | 1     | Message Type = 'D'   | Alpha   |                                |
| 1      | 2     | Stock Locate         | Integer |                                |
| 3      | 2     | Tracking Number      | Integer |                                |
| 5      | 6     | Timestamp            | Integer | ns since midnight              |
| 11     | 8     | Order Reference No.  | Integer | Order removed in full          |

Shortest of the four — good sanity-check case for the framing FSM.

---

## Optional stretch: Order Replace ('U')

Total length: **35 bytes** — adds a new order ref, shares, and price to a
delete. Only add this if the core four are solid.

| Offset | Bytes | Field                    | Type      | Notes                    |
|--------|-------|--------------------------|-----------|--------------------------|
| 0      | 1     | Message Type = 'U'       | Alpha     |                          |
| 1      | 2     | Stock Locate             | Integer   |                          |
| 3      | 2     | Tracking Number          | Integer   |                          |
| 5      | 6     | Timestamp                | Integer   | ns since midnight        |
| 11     | 8     | Original Order Ref No.   | Integer   | Order being replaced     |
| 19     | 8     | New Order Reference No.  | Integer   | Replacement order ID     |
| 27     | 4     | Shares                   | Integer   | New quantity             |
| 31     | 4     | Price                    | Price(4)  | New price                |

---

## Verification note

Before writing RTL, confirm these lengths and offsets against the official PDF
yourself — download it from nasdaqtrader.com (search "NQTVITCH 5.0"). Section 4
lists every message format. The offsets here follow directly from the field
widths and the shared 11-byte header, but a single wrong width shifts every
field after it, so cross-check the total-length numbers against the spec's
stated message lengths as your checksum.
