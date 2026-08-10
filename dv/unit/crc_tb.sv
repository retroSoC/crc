// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`timescale 1ns / 1ps
`include "crc_define.svh"

module crc_tb;

  logic          clk;
  logic          rst_n;
  logic   [11:0] paddr;
  logic          psel;
  logic          penable;
  logic          pwrite;
  logic   [31:0] pwdata;
  logic   [ 3:0] pstrb;
  logic          pready;
  logic   [31:0] prdata;
  logic          pslverr;
  integer        last_wait_cycles;

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

  always #5 clk = ~clk;

  task automatic apb_idle;
    paddr   = '0;
    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    pwdata  = '0;
    pstrb   = '0;
  endtask

  task automatic apb_write(input logic [11:0] address, input logic [31:0] data,
                           input logic [3:0] strb, input logic expect_error);
    @(negedge clk);
    paddr   = address;
    psel    = 1'b1;
    penable = 1'b1;
    pwrite  = 1'b1;
    pwdata  = data;
    pstrb   = strb;
    #1;
    last_wait_cycles = 0;
    while (!pready) begin
      @(posedge clk);
      @(negedge clk);
      last_wait_cycles = last_wait_cycles + 1;
      if (last_wait_cycles > 8) $fatal(1, "APB write timeout");
      #1;
    end
    if (pslverr !== expect_error) $fatal(1, "APB write response mismatch");
    @(posedge clk);
    @(negedge clk);
    apb_idle();
  endtask

  task automatic apb_read(input logic [11:0] address, input logic [31:0] expected,
                          input logic expect_error);
    @(negedge clk);
    paddr   = address;
    psel    = 1'b1;
    penable = 1'b1;
    pwrite  = 1'b0;
    pwdata  = '0;
    pstrb   = '0;
    #1;
    last_wait_cycles = 0;
    while (!pready) begin
      @(posedge clk);
      @(negedge clk);
      last_wait_cycles = last_wait_cycles + 1;
      if (last_wait_cycles > 8) $fatal(1, "APB read timeout");
      #1;
    end
    if (pslverr !== expect_error) $fatal(1, "APB read response mismatch");
    if (!expect_error && (prdata !== expected)) begin
      $fatal(1, "APB read mismatch at %h: got %h expected %h", address, prdata, expected);
    end
    @(posedge clk);
    @(negedge clk);
    apb_idle();
  endtask

  task automatic configure(input logic [4:0] config_value, input logic [31:0] polynomial,
                           input logic [31:0] init, input logic [31:0] xor_out);
    apb_write(`CRC_CONFIG_OFFSET, {27'h0, config_value}, 4'hF, 1'b0);
    apb_write(`CRC_POLYNOMIAL_OFFSET, polynomial, 4'hF, 1'b0);
    apb_write(`CRC_INIT_OFFSET, init, 4'hF, 1'b0);
    apb_write(`CRC_XOR_OUT_OFFSET, xor_out, 4'hF, 1'b0);
  endtask

  task automatic feed_check_vector(input logic [31:0] expected);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h3433_3231, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h3837_3635, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_0039, 4'h1, 1'b0);
    apb_read(`CRC_BYTE_COUNT_OFFSET, 32'd9, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, '0, 1'b1);
    apb_write(`CRC_ERROR_STATUS_OFFSET, `CRC_ERROR_STATE_MASK, 4'hF, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_FINISH_MASK, 4'hF, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, expected, 1'b0);
  endtask

  task automatic feed_check_vector_halfwords(input logic [31:0] expected);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_3231, 4'h3, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_3433, 4'h3, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_3635, 4'h3, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_3837, 4'h3, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_0039, 4'h1, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_FINISH_MASK, 4'hF, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, expected, 1'b0);
  endtask

  task automatic feed_check_vector_swapped(input logic [31:0] expected);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h3132_3334, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h3536_3738, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_0039, 4'h1, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_FINISH_MASK, 4'hF, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, expected, 1'b0);
  endtask

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
    apb_idle();
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    apb_read(`CRC_IP_ID_OFFSET, `CRC_IP_ID_VALUE, 1'b0);
    apb_read(`CRC_IP_VERSION_OFFSET, `CRC_IP_VERSION_VALUE, 1'b0);
    apb_read(`CRC_CONFIG_OFFSET, 32'h0000_000F, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h3433_3231, 4'hF, 1'b0);
    if (last_wait_cycles == 0) $fatal(1, "Full-word DATA write did not insert wait states");
    apb_write(`CRC_DATA_OFFSET, 32'h3837_3635, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h0000_0039, 4'h1, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_FINISH_MASK, 4'hF, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, 32'hCBF4_3926, 1'b0);
    apb_write(`CRC_XOR_OUT_OFFSET, 32'h0000_0000, 4'hF, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, 32'hCBF4_3926, 1'b0);

    configure(5'h00, 32'h0000_0009, 32'h0000_0000, 32'h0000_0000);
    feed_check_vector(32'h0000_0075);
    configure(5'h01, 32'h0000_0007, 32'h0000_0000, 32'h0000_0000);
    feed_check_vector(32'h0000_00F4);
    configure(5'h02, 32'h0000_1021, 32'h0000_FFFF, 32'h0000_0000);
    feed_check_vector(32'h0000_29B1);
    configure(5'h0E, 32'h0000_8005, 32'h0000_0000, 32'h0000_0000);
    feed_check_vector(32'h0000_BB3D);

    configure(5'h0F, 32'h04C1_1DB7, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
    feed_check_vector_halfwords(32'hCBF4_3926);
    configure(5'h1F, 32'h04C1_1DB7, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
    feed_check_vector_swapped(32'hCBF4_3926);

    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_FINISH_MASK, 4'hF, 1'b0);
    apb_read(`CRC_RESULT_OFFSET, 32'h0000_0000, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b0);
    apb_write(`CRC_DATA_OFFSET, 32'h3433_3231, 4'hF, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_ABORT_MASK, 4'hF, 1'b0);
    apb_read(`CRC_STATUS_OFFSET, 32'h0000_0000, 1'b0);

    apb_write(`CRC_CONFIG_OFFSET, 32'h0000_0003, 4'hF, 1'b0);
    apb_write(`CRC_POLYNOMIAL_OFFSET, 32'h04C1_1DB6, 4'hF, 1'b0);
    apb_write(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF, 1'b1);
    apb_read(`CRC_ERROR_STATUS_OFFSET, `CRC_ERROR_CONFIG_MASK, 1'b0);
    apb_write(`CRC_ERROR_STATUS_OFFSET, `CRC_ERROR_CONFIG_MASK, 4'hF, 1'b0);

    configure(5'h0F, 32'h04C1_1DB7, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
    apb_write(`CRC_CONFIG_LOCK_OFFSET, 32'h1, 4'hF, 1'b0);
    apb_write(`CRC_INIT_OFFSET, 32'h0, 4'hF, 1'b1);
    apb_read(`CRC_CONFIG_LOCK_OFFSET, 32'h1, 1'b0);
    apb_write(`CRC_ERROR_STATUS_OFFSET, `CRC_ERROR_STATE_MASK, 4'hF, 1'b0);

    apb_read(12'h003, '0, 1'b1);
    apb_read(12'h080, '0, 1'b1);
    apb_write(`CRC_DATA_OFFSET, 32'h1234_5678, 4'b0101, 1'b1);

    $display("CRC_TEST_PASS");
    $finish;
  end

endmodule
