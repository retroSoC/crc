# CRC V2 Datasheet

## Purpose

CRC V2 accelerates general-purpose cyclic redundancy checks over byte streams.
It is a synchronous APB4 target and does not fetch memory, arbitrate a bus, or
generate an interrupt. A CPU or system DMA writes the DATA register and uses
its own completion mechanism.

## Operation

Software configures CRC width, polynomial, initial value, final XOR, input and
output reflection, and byte order while inactive. START validates the complete
configuration, loads INIT into the raw state, clears BYTE_COUNT, and enters the
active state. Each legal DATA write updates the existing raw state. FINISH
leaves active state, latches the final value into RESULT, and makes RESULT
valid. Later configuration writes do not reinterpret the latched result. ABORT
discards the partial message.

The polynomial is stored without its highest-order coefficient. It must be odd
and fit the selected 7-, 8-, 16-, or 32-bit width. INIT, XOR_OUT, RAW_STATE, and
RESULT ignore bits above that width.

DATA accepts one, two, or four contiguous APB byte lanes. With BYTE_SWAP clear,
asserted lanes are processed from low to high; with BYTE_SWAP set, they are
processed from high to low. REFLECT_IN reverses bits independently in each
byte. REFLECT_OUT reverses the selected raw CRC width before XOR_OUT is applied.

The reset configuration is CRC-32/ISO-HDLC: width 32, polynomial `0x04C11DB7`,
INIT and XOR_OUT `0xFFFFFFFF`, input/output reflection enabled, and low-byte
first ordering.

## APB Behavior

Register accesses complete without wait states. A legal DATA write holds
PREADY low while the block captures the write and processes one selected byte
per clock; a 1-, 2-, or 4-byte write therefore has bounded latency. The APB
initiator must hold address and write controls stable until PREADY is high, as
required by APB4.

Unaligned or unmapped accesses, incorrect access direction, zero or unsupported
PSTRB, reserved-bit writes, illegal state transitions, and invalid
configuration assert PSLVERR in the completing APB access phase. Rejected
accesses do not change configuration or CRC state, but record a sticky
ERROR_STATUS cause. Writable configuration registers honor PSTRB.

## Register Map

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | WO | START, FINISH, and ABORT command pulses |
| `0x004` | `STATUS` | RO | Active, result-valid, lock, and error status |
| `0x008` | `CONFIG` | RW | Width, reflection, and byte-order controls |
| `0x00C` | `POLYNOMIAL` | RW | Generator polynomial without the leading term |
| `0x010` | `INIT` | RW | Initial CRC state |
| `0x014` | `XOR_OUT` | RW | Final result XOR value |
| `0x018` | `DATA` | WO | Streaming 1-, 2-, or 4-byte input |
| `0x01C` | `RESULT` | RO | Reflected/XORed result; valid after FINISH |
| `0x020` | `RAW_STATE` | RO | Current unmodified LFSR state |
| `0x024` | `BYTE_COUNT` | RO | Saturating bytes accepted in this session |
| `0x028` | `ERROR_STATUS` | RW1C | Access, state, config, and count errors |
| `0x02C` | `CONFIG_LOCK` | RW1S | Lock configuration until hardware reset |
| `0x0F4` | `IP_ID` | RO | ASCII `CRC2`, `0x43524332` |
| `0x0F8` | `IP_VERSION` | RO | ABI version, `0x00020000` |
| `0x0FC` | `CAPABILITY` | RO | ABI and feature bitmap |

CTRL bits 0 through 2 are START, FINISH, and ABORT. Exactly one command must be
written. STATUS bits 0 through 3 are ACTIVE, RESULT_VALID, CONFIG_LOCKED, and
ERROR. CONFIG bits 1:0 encode widths 7, 8, 16, and 32; bits 2 through 4 are
REFLECT_IN, REFLECT_OUT, and BYTE_SWAP.

ERROR_STATUS bits 0 through 3 report access, state, configuration, and byte
count overflow. CONFIG_LOCK bit 0 is monotonic until reset. BYTE_COUNT saturates
at `0xFFFFFFFF`; calculation continues and sets the overflow error.
