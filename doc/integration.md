# CRC V2 Integration Guide

Instantiate `apb4_crc` in one APB clock/reset domain and connect its single
named `apb4` port. The block has no external data, DMA, clock-domain-crossing,
or interrupt ports.

A DMA can feed full words by fixing its destination address at DATA and
incrementing the source address. It must honor APB PREADY backpressure. The DMA
completion event defines end of transfer; software then writes FINISH and reads
RESULT. Tail bytes can be sent by CPU byte or halfword stores.

The datapath processes one byte per clock between CRC state registers. DATA
writes insert bounded APB wait states while one to four selected byte lanes are
consumed. This keeps the combinational depth independent of store width and
makes full-word DMA writes suitable for the product clock target.

Access control belongs to the SoC fabric. If CRC results support boot or
integrity policy, untrusted masters must not be allowed to reconfigure, abort,
or overwrite the session.
