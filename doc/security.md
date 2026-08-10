# CRC V2 Security Guide

CRC detects accidental corruption under a selected error model. It is not a
cryptographic hash, message authentication code, digital signature, or source
of authenticity. An attacker able to alter both data and checksum can normally
construct a matching CRC.

Security-sensitive products must authenticate data with an approved
cryptographic mechanism. The SoC fabric must also restrict CRC configuration
and session control if the result contributes to boot, update, or diagnostic
policy.
