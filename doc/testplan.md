# CRC V2 Test Plan

Directed tests cover reset values, identification, all supported widths,
standard check values, empty messages, START/FINISH/ABORT, continuous state,
result validity and retention across reconfiguration, byte count, reflection,
and configuration lock.

APB tests cover byte/halfword/word PSTRB, mixed chunk boundaries, byte swap,
partial configuration writes, unmapped and unaligned accesses, wrong access
directions, reserved bits, invalid polynomial, illegal commands, bounded DATA
wait states, and writes in the wrong state.

Formal properties cover PREADY backpressure and PSLVERR phase, width masks,
command state transitions, invalid-access stability, byte-count updates,
result-valid state, and monotonic configuration lock. Covers require a
complete session, full-word feed, wait-state observation, lock, and error
response.
