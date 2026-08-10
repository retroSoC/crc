# CRC V2 Verification

The verification flow contains:

- Icarus simulation of the scalar register/controller implementation;
- Verilator simulation of the complete APB4 wrapper;
- standard check vectors for CRC-7/MMC, CRC-8/SMBUS,
  CRC-16/CCITT-FALSE, CRC-16/ARC, and CRC-32/ISO-HDLC;
- mixed byte, halfword, and word streaming checks, DATA wait-state checks, and
  APB negative tests;
- a freestanding-compatible host test for the portable C driver;
- RTL/C register parity, Verilator lint, and Yosys synthesis checks;
- SBY/Bitwuzla properties for APB response and backpressure, state transitions,
  lock behavior, width masking, invalid access stability, and command coverage.

Run `make format-check register-check lint test synth formal`. A release is not
ready if any command fails.
