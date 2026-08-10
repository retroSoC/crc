// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module apb4_crc (
    apb4_if.slave apb4
);

  crc_reg u_crc_reg (
      .clk_i    (apb4.pclk),
      .rst_n_i  (apb4.presetn),
      .paddr_i  (apb4.paddr[11:0]),
      .psel_i   (apb4.psel),
      .penable_i(apb4.penable),
      .pwrite_i (apb4.pwrite),
      .pwdata_i (apb4.pwdata),
      .pstrb_i  (apb4.pstrb),
      .pready_o (apb4.pready),
      .prdata_o (apb4.prdata),
      .pslverr_o(apb4.pslverr)
  );

endmodule
