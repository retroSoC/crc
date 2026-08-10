// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`ifndef CRC_DEFINE_SVH
`define CRC_DEFINE_SVH

// verilog_format: off
`define CRC_CTRL_OFFSET                 12'h000
`define CRC_STATUS_OFFSET               12'h004
`define CRC_CONFIG_OFFSET               12'h008
`define CRC_POLYNOMIAL_OFFSET           12'h00C
`define CRC_INIT_OFFSET                 12'h010
`define CRC_XOR_OUT_OFFSET              12'h014
`define CRC_DATA_OFFSET                 12'h018
`define CRC_RESULT_OFFSET               12'h01C
`define CRC_RAW_STATE_OFFSET            12'h020
`define CRC_BYTE_COUNT_OFFSET           12'h024
`define CRC_ERROR_STATUS_OFFSET         12'h028
`define CRC_CONFIG_LOCK_OFFSET          12'h02C
`define CRC_IP_ID_OFFSET                12'h0F4
`define CRC_IP_VERSION_OFFSET           12'h0F8
`define CRC_CAPABILITY_OFFSET           12'h0FC

`define CRC_CTRL_START_MASK             32'h0000_0001
`define CRC_CTRL_FINISH_MASK            32'h0000_0002
`define CRC_CTRL_ABORT_MASK             32'h0000_0004
`define CRC_CTRL_VALID_MASK             32'h0000_0007

`define CRC_STATUS_ACTIVE_MASK          32'h0000_0001
`define CRC_STATUS_RESULT_VALID_MASK    32'h0000_0002
`define CRC_STATUS_CONFIG_LOCKED_MASK   32'h0000_0004
`define CRC_STATUS_ERROR_MASK           32'h0000_0008

`define CRC_CONFIG_WIDTH_MASK           32'h0000_0003
`define CRC_CONFIG_REFLECT_IN_MASK      32'h0000_0004
`define CRC_CONFIG_REFLECT_OUT_MASK     32'h0000_0008
`define CRC_CONFIG_BYTE_SWAP_MASK       32'h0000_0010
`define CRC_CONFIG_VALID_MASK           32'h0000_001F

`define CRC_WIDTH_7                     2'b00
`define CRC_WIDTH_8                     2'b01
`define CRC_WIDTH_16                    2'b10
`define CRC_WIDTH_32                    2'b11

`define CRC_ERROR_ACCESS_MASK           32'h0000_0001
`define CRC_ERROR_STATE_MASK            32'h0000_0002
`define CRC_ERROR_CONFIG_MASK           32'h0000_0004
`define CRC_ERROR_COUNT_OVERFLOW_MASK   32'h0000_0008
`define CRC_ERROR_VALID_MASK            32'h0000_000F

`define CRC_CONFIG_LOCK_MASK            32'h0000_0001

`define CRC_IP_ID_VALUE                 32'h4352_4332
`define CRC_IP_VERSION_VALUE            32'h0002_0000
`define CRC_CAPABILITY_FEATURES         8'hFF
`define CRC_ABI_VERSION                 8'h02
`define CRC_CAPABILITY_VALUE            32'h0200_00FF
// verilog_format: on

`endif
