// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

module crc_formal_props (
    // verilog_format: off
    input logic        clk_i,
    input logic        rst_n_i,
    input logic [ 4:0] config_i,
    input logic        config_lock_i,
    input logic        start_i,
    input logic        finish_i,
    input logic        abort_i,
    input logic        access_legal_i,
    input logic        transfer_i,
    input logic [31:0] raw_state_i,
    input logic [31:0] result_i,
    input logic [31:0] byte_count_i,
    input logic        active_i,
    input logic        result_valid_i,
    input logic        data_valid_i,
    input logic [ 3:0] data_strb_i,
    input logic        data_request_i,
    input logic        data_busy_i,
    input logic        data_ready_i,
    input logic        pready_i,
    input logic        pslverr_i
    // verilog_format: on
);

  logic f_past_valid;

  initial f_past_valid = 1'b0;

  always @(posedge clk_i) begin
    f_past_valid <= 1'b1;

    assert (!pslverr_i || transfer_i);
    assert (pready_i == (!data_request_i || (data_ready_i && !data_busy_i)));
    assert (!data_busy_i || data_request_i);
    if (config_i[1:0] == 2'b00) assert ((raw_state_i & ~32'h7F) == 0);
    if (config_i[1:0] == 2'b01) assert ((raw_state_i & ~32'hFF) == 0);
    if (config_i[1:0] == 2'b10) assert ((raw_state_i & ~32'hFFFF) == 0);

    if (f_past_valid && rst_n_i && $past(rst_n_i && config_lock_i)) begin
      assert (config_lock_i);
    end
    if (f_past_valid && rst_n_i && $past(rst_n_i && start_i)) begin
      assert (active_i);
      assert (byte_count_i == 0);
      assert (!result_valid_i);
    end
    if (f_past_valid && rst_n_i && $past(rst_n_i && finish_i)) begin
      assert (!active_i);
      assert (result_valid_i);
    end
    if (f_past_valid && rst_n_i && $past(rst_n_i && abort_i)) begin
      assert (!active_i);
      assert (!result_valid_i);
      assert (byte_count_i == 0);
    end
    if (f_past_valid && rst_n_i && $past(rst_n_i && transfer_i && !access_legal_i)) begin
      assert (raw_state_i == $past(raw_state_i));
      assert (byte_count_i == $past(byte_count_i));
    end
    if (f_past_valid && rst_n_i && $past(
            rst_n_i && result_valid_i && !start_i && !finish_i && !abort_i
        )) begin
      assert (result_i == $past(result_i));
    end

    cover (rst_n_i && active_i);
    cover (rst_n_i && result_valid_i);
    cover (rst_n_i && data_valid_i && (data_strb_i == 4'hF));
    cover (rst_n_i && data_request_i && !pready_i);
    cover (rst_n_i && config_lock_i);
    cover (rst_n_i && pslverr_i);
  end

endmodule

module crc_formal;

  (* gclk *)logic        clk;
  (* anyseq *)logic        rst_n;
  (* anyseq *)logic [11:0] paddr;
  (* anyseq *)logic        psel;
  (* anyseq *)logic        penable;
  (* anyseq *)logic        pwrite;
  (* anyseq *)logic [31:0] pwdata;
  (* anyseq *)logic [ 3:0] pstrb;

  logic        pready;
  logic [31:0] prdata;
  logic        pslverr;
  logic        f_past_valid;

  crc_reg u_dut (
      .clk_i    (clk),
      .rst_n_i  (rst_n),
      .paddr_i  (paddr),
      .psel_i   (psel),
      .penable_i(penable),
      .pwrite_i (pwrite),
      .pwdata_i (pwdata),
      .pstrb_i  (pstrb),
      .pready_o (pready),
      .prdata_o (prdata),
      .pslverr_o(pslverr)
  );

  initial assume (!rst_n);
  initial f_past_valid = 1'b0;

  always @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (f_past_valid && $past(psel && penable && !pready)) begin
      assume (psel && penable);
      assume ($stable(paddr));
      assume ($stable(pwrite));
      assume ($stable(pwdata));
      assume ($stable(pstrb));
    end
    cover (rst_n && pslverr);
  end

endmodule
