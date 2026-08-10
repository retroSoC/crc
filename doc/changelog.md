# Changelog

## CRC V2

- Replaced fixed-polynomial, per-write restart behavior with a programmable
  continuous streaming CRC engine.
- Added 7/8/16/32-bit width, polynomial, initial value, final XOR, reflection,
  byte order, explicit session control, byte count, configuration lock, strict
  APB errors, identification, and capability registers.
- Added portable software, register parity, Icarus/Verilator tests, synthesis,
  formal verification, locked CI dependencies, and delivery documentation.
- Added bounded APB backpressure and a one-byte-per-cycle datapath so DATA
  store width no longer increases the CRC state-register combinational depth.
- Removed the legacy five-register ABI and VCS class testbench.
