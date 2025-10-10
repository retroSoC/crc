// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// crc is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "crc_define.svh"

module apb4_crc (
    apb4_if.slave apb4
);

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`CRC_CTRL_WIDTH-1:0] s_crc_ctrl_d, s_crc_ctrl_q;
  logic s_crc_ctrl_en;
  logic [`CRC_INIT_WIDTH-1:0] s_crc_init_d, s_crc_init_q;
  logic s_crc_init_en;
  logic [`CRC_XORV_WIDTH-1:0] s_crc_xorv_d, s_crc_xorv_q;
  logic s_crc_xorv_en;
  logic [`CRC_DATA_WIDTH-1:0] s_crc_data_d, s_crc_data_q;
  logic s_crc_data_en;
  logic [`CRC_STAT_WIDTH-1:0] s_crc_stat_d, s_crc_stat_q;
  logic s_crc_stat_en;
  logic s_bit_en, s_bit_revin, s_bit_revout, s_bit_done;
  logic [1:0] s_bit_mode, s_bit_size;
  // calc cnt
  logic [2:0] s_calc_cnt_d, s_calc_cnt_q;
  logic s_calc_cnt_en;
  logic s_calc_start_d, s_calc_start_q, s_trans_done;
  logic [7:0] s_crc_data_in;
  // write origin data
  logic [7:0] s_crc_data8_wr, s_crc_data8_wr_rev;
  logic [15:0] s_crc_data16_wr, s_crc_data16_wr_rev;
  logic [23:0] s_crc_data24_wr, s_crc_data24_wr_rev;
  logic [31:0] s_crc_data32_wr, s_crc_data32_wr_rev;
  // crc result
  logic [7:0] s_crc8_d, s_crc8_q, s_crc8_qq, s_crc8_q_rev;
  logic [15:0] s_crc16_d, s_crc16_q, s_crc16_qq_1021, s_crc16_qq_8005, s_crc16_q_rev;
  logic [31:0] s_crc32_d, s_crc32_q, s_crc32_qq, s_crc32_q_rev;


  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  assign s_bit_en        = s_crc_ctrl_q[0];
  assign s_bit_revin     = s_crc_ctrl_q[1];
  assign s_bit_revout    = s_crc_ctrl_q[2];
  assign s_bit_mode      = s_crc_ctrl_q[4:3];
  assign s_bit_size      = s_crc_ctrl_q[6:5];
  assign s_bit_done      = s_crc_stat_q[0];

  assign s_crc_data8_wr  = apb4.pwdata[7:0];
  assign s_crc_data16_wr = apb4.pwdata[15:0];
  assign s_crc_data24_wr = apb4.pwdata[23:0];
  assign s_crc_data32_wr = apb4.pwdata[31:0];
  assign s_trans_done    = s_calc_cnt_q == s_bit_size + 1'd1;

  // data8
  for (genvar i = 0; i < 8; i++) begin : DATA8_REV_BLOCK
    assign s_crc_data8_wr_rev[i] = s_crc_data8_wr[7-i];
    assign s_crc8_q_rev[i]       = s_crc8_q[7-i];
  end

  // data16
  for (genvar i = 0; i < 16; i++) begin : DATA16_REV_BLOCK
    if (i < 8) begin
      assign s_crc_data16_wr_rev[i] = s_crc_data16_wr[7-i];
    end else begin
      assign s_crc_data16_wr_rev[i] = s_crc_data16_wr[15-(i-8)];
    end
    assign s_crc16_q_rev[i] = s_crc16_q[15-i];
  end

  // data24
  for (genvar i = 0; i < 24; i++) begin : DATA24_REV_BLOCK
    if (i < 8) begin
      assign s_crc_data24_wr_rev[i] = s_crc_data24_wr[7-i];
    end else if (i < 16) begin
      assign s_crc_data24_wr_rev[i] = s_crc_data24_wr[15-(i-8)];
    end else begin
      assign s_crc_data24_wr_rev[i] = s_crc_data24_wr[23-(i-16)];
    end
  end

  // data32
  for (genvar i = 0; i < 32; i++) begin : DATA32_REV_BLOCK
    if (i < 8) begin
      assign s_crc_data32_wr_rev[i] = s_crc_data32_wr[7-i];
    end else if (i < 16) begin
      assign s_crc_data32_wr_rev[i] = s_crc_data32_wr[15-(i-8)];
    end else if (i < 24) begin
      assign s_crc_data32_wr_rev[i] = s_crc_data32_wr[23-(i-16)];
    end else begin
      assign s_crc_data32_wr_rev[i] = s_crc_data32_wr[31-(i-24)];
    end
    assign s_crc32_q_rev[i] = s_crc32_q[31-i];
  end


  assign s_crc_ctrl_en = s_apb4_wr_hdshk && s_apb4_addr == `CRC_CTRL;
  assign s_crc_ctrl_d  = apb4.pwdata[`CRC_CTRL_WIDTH-1:0];
  dffer #(`CRC_CTRL_WIDTH) u_crc_ctrl_dffer (
      apb4.pclk,
      apb4.presetn,
      s_crc_ctrl_en,
      s_crc_ctrl_d,
      s_crc_ctrl_q
  );

  assign s_crc_init_en = s_apb4_wr_hdshk && s_apb4_addr == `CRC_INIT;
  assign s_crc_init_d  = apb4.pwdata[`CRC_INIT_WIDTH-1:0];
  dffer #(`CRC_INIT_WIDTH) u_crc_init_dffer (
      apb4.pclk,
      apb4.presetn,
      s_crc_init_en,
      s_crc_init_d,
      s_crc_init_q
  );

  assign s_crc_xorv_en = s_apb4_wr_hdshk && s_apb4_addr == `CRC_XORV;
  assign s_crc_xorv_d  = apb4.pwdata[`CRC_XORV_WIDTH-1:0];
  dffer #(`CRC_XORV_WIDTH) u_crc_xorv_dffer (
      apb4.pclk,
      apb4.presetn,
      s_crc_xorv_en,
      s_crc_xorv_d,
      s_crc_xorv_q
  );

  assign s_crc_data_en = s_bit_en && ((s_apb4_wr_hdshk && s_apb4_addr == `CRC_DATA) || s_trans_done);
  always_comb begin
    s_crc_data_d = s_crc_data_q;
    if (s_bit_en && s_apb4_wr_hdshk && s_apb4_addr == `CRC_DATA) begin  // write origin data
      if (s_bit_revin) begin
        unique case (s_bit_size)  // left align
          `CRC_8_SIZES:  s_crc_data_d[31:24] = s_crc_data8_wr_rev;
          `CRC_16_SIZES: s_crc_data_d[31:16] = s_crc_data16_wr_rev;
          `CRC_24_SIZES: s_crc_data_d[31:8] = s_crc_data24_wr_rev;
          `CRC_32_SIZES: s_crc_data_d[31:0] = s_crc_data32_wr_rev;
        endcase
      end else begin
        unique case (s_bit_size)
          `CRC_8_SIZES:  s_crc_data_d[31:24] = s_crc_data8_wr;
          `CRC_16_SIZES: s_crc_data_d[31:16] = s_crc_data16_wr;
          `CRC_24_SIZES: s_crc_data_d[31:8] = s_crc_data24_wr;
          `CRC_32_SIZES: s_crc_data_d[31:0] = s_crc_data32_wr;
        endcase
      end
    end else if (s_bit_en && s_trans_done) begin  // write result
      if (s_bit_revout) begin
        unique case (s_bit_mode)  // trick: right align
          `CRC8_MODE:       s_crc_data_d = s_crc8_q_rev ^ s_crc_xorv_q[7:0];
          `CRC16_1021_MODE: s_crc_data_d = s_crc16_q_rev ^ s_crc_xorv_q[15:0];
          `CRC16_8005_MODE: s_crc_data_d = s_crc16_q_rev ^ s_crc_xorv_q[15:0];
          `CRC32_MODE:      s_crc_data_d = s_crc32_q_rev ^ s_crc_xorv_q[31:0];
        endcase
      end else begin
        unique case (s_bit_mode)
          `CRC8_MODE:       s_crc_data_d = s_crc8_q ^ s_crc_xorv_q[7:0];
          `CRC16_1021_MODE: s_crc_data_d = s_crc16_q ^ s_crc_xorv_q[15:0];
          `CRC16_8005_MODE: s_crc_data_d = s_crc16_q ^ s_crc_xorv_q[15:0];
          `CRC32_MODE:      s_crc_data_d = s_crc32_q ^ s_crc_xorv_q[31:0];
        endcase
      end
    end
  end
  dffer #(`CRC_DATA_WIDTH) u_crc_data_dffer (
      apb4.pclk,
      apb4.presetn,
      s_crc_data_en,
      s_crc_data_d,
      s_crc_data_q
  );


  always_comb begin
    s_crc_stat_d = s_crc_stat_q;
    if (s_bit_en && s_crc_stat_q == 1'b1 && s_apb4_rd_hdshk && s_apb4_addr == `CRC_STAT) begin
      s_crc_stat_d = '0;
    end else if (s_bit_en && s_crc_stat_q == 1'b0 && s_trans_done) begin
      s_crc_stat_d = '1;
    end
  end
  dffr #(`CRC_STAT_WIDTH) u_crc_stat_dffr (
      apb4.pclk,
      apb4.presetn,
      s_crc_stat_d,
      s_crc_stat_q
  );

  always_comb begin
    apb4.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `CRC_CTRL: apb4.prdata[`CRC_CTRL_WIDTH-1:0] = s_crc_ctrl_q;
        `CRC_INIT: apb4.prdata[`CRC_INIT_WIDTH-1:0] = s_crc_init_q;
        `CRC_XORV: apb4.prdata[`CRC_XORV_WIDTH-1:0] = s_crc_xorv_q;
        `CRC_DATA: apb4.prdata[`CRC_DATA_WIDTH-1:0] = s_crc_data_q;
        `CRC_STAT: apb4.prdata[`CRC_STAT_WIDTH-1:0] = s_crc_stat_q;
        default:   apb4.prdata = '0;
      endcase
    end
  end

  always_comb begin
    s_calc_start_d = s_calc_start_q;
    if (s_bit_en && s_calc_start_q == 1'b1 && s_trans_done) begin
      s_calc_start_d = 1'b0;
    end else if(s_bit_en && s_calc_start_q == 1'b0 && (s_apb4_wr_hdshk && s_apb4_addr == `CRC_DATA)) begin
      s_calc_start_d = 1'b1;
    end
  end
  dffr #(1) u_calc_start_dffr (
      apb4.pclk,
      apb4.presetn,
      s_calc_start_d,
      s_calc_start_q
  );

  assign s_calc_cnt_en = s_bit_en & s_calc_start_q;
  assign s_calc_cnt_d  = s_trans_done ? '0 : s_calc_cnt_q + 1'b1;
  dffer #(3) u_calc_cnt_dffer (
      apb4.pclk,
      apb4.presetn,
      s_calc_cnt_en,
      s_calc_cnt_d,
      s_calc_cnt_q
  );


  always_comb begin
    unique case (s_calc_cnt_q)
      3'b000:  s_crc_data_in = s_crc_data_q[31:24];
      3'b001:  s_crc_data_in = s_crc_data_q[23:16];
      3'b010:  s_crc_data_in = s_crc_data_q[15:8];
      3'b011:  s_crc_data_in = s_crc_data_q[7:0];
      default: s_crc_data_in = s_crc_data_q[31:24];
    endcase
  end

  crc8_07 u_crc8_07 (
      .data_i(s_crc_data_in),
      .crc_i (s_crc8_q),
      .crc_o (s_crc8_qq)
  );

  always_comb begin
    s_crc8_d = s_crc8_q;
    if (s_bit_en && s_apb4_wr_hdshk && s_apb4_addr == `CRC_DATA) begin
      s_crc8_d = s_crc_init_q[7:0];
    end else if (~s_trans_done) begin
      s_crc8_d = s_crc8_qq;
    end
  end
  dffr #(8) u_crc8_dffr (
      apb4.pclk,
      apb4.presetn,
      s_crc8_d,
      s_crc8_q
  );

  crc16_1021 u_crc16_1021 (
      .data_i(s_crc_data_in),
      .crc_i (s_crc16_q),
      .crc_o (s_crc16_qq_1021)
  );

  crc16_8005 u_crc16_8005 (
      .data_i(s_crc_data_in),
      .crc_i (s_crc16_q),
      .crc_o (s_crc16_qq_8005)
  );

  always_comb begin
    s_crc16_d = s_crc16_q;
    if (s_bit_en && s_apb4_wr_hdshk && s_apb4_addr == `CRC_DATA) begin
      s_crc16_d = s_crc_init_q[15:0];
    end else if (~s_trans_done) begin
      s_crc16_d = s_bit_mode == `CRC16_1021_MODE ? s_crc16_qq_1021 : s_crc16_qq_8005;
    end
  end
  dffr #(16) u_crc16_dffr (
      apb4.pclk,
      apb4.presetn,
      s_crc16_d,
      s_crc16_q
  );

  crc32_04c11db7 u_crc32_04c11db7 (
      .data_i(s_crc_data_in),
      .crc_i (s_crc32_q),
      .crc_o (s_crc32_qq)
  );


  always_comb begin
    s_crc32_d = s_crc32_q;
    if (s_bit_en && s_apb4_wr_hdshk && s_apb4_addr == `CRC_DATA) begin
      s_crc32_d = s_crc_init_q[31:0];
    end else if (~s_trans_done) begin
      s_crc32_d = s_crc32_qq;
    end
  end
  dffr #(32) u_crc32_dffr (
      apb4.pclk,
      apb4.presetn,
      s_crc32_d,
      s_crc32_q
  );

endmodule
