// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// crc is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_CRC_DEF_SV
`define INC_CRC_DEF_SV

/* register mapping
 * CRC_CTRL:
 * BITS:   | 31:7 | 6:5  | 4:3  | 2      | 1     | 0  |
 * FIELDS: | RES  | SIZE | MODE | REVOUT | REVIN | EN |
 * PERMS:  | NONE | RW   | RW   | RW     | RW    | RW |
 * ----------------------------------------------------
 * CRC_INIT:
 * BITS:   | 31:0 |
 * FIELDS: | INIT |
 * PERMS:  | RW   |
 * ----------------------------------------------------
 * CRC_XORV:
 * BITS:   | 31:0 |
 * FIELDS: | XORV |
 * PERMS:  | RW   |
 * ----------------------------------------------------
 * CRC_DATA:
 * BITS:   | 31:0 |
 * FIELDS: | DATA |
 * PERMS:  | RW   |
 * ----------------------------------------------------
 * CRC_STAT:
 * BITS:   | 31:1 | 0     |
 * FIELDS: | RES  | DONE  |
 * PERMS:  | NONE | RC_W0 |
 * ----------------------------------------------------
*/

// verilog_format: off
`define CRC_CTRL 4'b0000 // BASEADDR + 0x00
`define CRC_INIT 4'b0001 // BASEADDR + 0x04
`define CRC_XORV 4'b0010 // BASEADDR + 0x08
`define CRC_DATA 4'b0011 // BASEADDR + 0x0C
`define CRC_STAT 4'b0100 // BASEADDR + 0x10

`define CRC_CTRL_ADDR {26'b0, `CRC_CTRL, 2'b00}
`define CRC_INIT_ADDR {26'b0, `CRC_INIT, 2'b00}
`define CRC_XORV_ADDR {26'b0, `CRC_XORV, 2'b00}
`define CRC_DATA_ADDR {26'b0, `CRC_DATA, 2'b00}
`define CRC_STAT_ADDR {26'b0, `CRC_STAT, 2'b00}

`define CRC_CTRL_WIDTH 7
`define CRC_INIT_WIDTH 32
`define CRC_XORV_WIDTH 32
`define CRC_DATA_WIDTH 32
`define CRC_STAT_WIDTH 1

`define CRC8_MODE       2'b00
`define CRC16_1021_MODE 2'b01
`define CRC16_8005_MODE 2'b10
`define CRC32_MODE      2'b11

`define CRC_8_SIZES  2'b00
`define CRC_16_SIZES 2'b01
`define CRC_24_SIZES 2'b10
`define CRC_32_SIZES 2'b11

`define FSM_IDLE   3'b000
`define FSM_SHIFT1 3'b001
`define FSM_SHIFT2 3'b010
`define FSM_SHIFT3 3'b011
`define FSM_SHIFT4 3'b100
`define FSM_DONE   3'b101
// verilog_format: on

`endif
