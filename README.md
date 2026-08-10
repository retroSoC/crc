# CRC

CRC V2 is a programmable APB4 streaming checksum accelerator. It supports
7-, 8-, 16-, and 32-bit CRCs, programmable polynomial/initial/final-XOR
values, input and output reflection, byte-order selection, and continuous
1-, 2-, or 4-byte DATA writes.

The V2 ABI replaces the legacy fixed-polynomial block. A calculation is an
explicit START, zero or more DATA writes, and FINISH transaction, so successive
writes update one CRC state instead of restarting from INIT.
DATA writes use bounded APB wait states while the datapath consumes one byte
per clock.

See [the datasheet](doc/datasheet.md),
[integration guide](doc/integration.md), and
[verification guide](doc/verification.md).

## Build And Test

The default layout expects the Common repository at `../common`.

```bash
make doctor
make format-check register-check lint
make test synth formal
```

The register map is hand-written. `make register-check` compares the RTL and C
definitions; no register generator is used.
