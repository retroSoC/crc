// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`timescale 1ns / 1ps
`include "crc_define.svh"

module apb4_crc_tb;

  logic   clk;
  logic   rst_n;
  integer last_wait_cycles;

  apb4_if u_apb4_if (
      .pclk   (clk),
      .presetn(rst_n)
  );

  apb4_crc u_dut (.apb4(u_apb4_if));

  always #5 clk = ~clk;

  task automatic idle;
    u_apb4_if.paddr   = '0;
    u_apb4_if.pprot   = '0;
    u_apb4_if.psel    = 1'b0;
    u_apb4_if.penable = 1'b0;
    u_apb4_if.pwrite  = 1'b0;
    u_apb4_if.pwdata  = '0;
    u_apb4_if.pstrb   = '0;
  endtask

  task automatic write_register(input logic [11:0] address, input logic [31:0] data,
                                input logic [3:0] strb);
    @(negedge clk);
    u_apb4_if.paddr   = {20'h0, address};
    u_apb4_if.psel    = 1'b1;
    u_apb4_if.penable = 1'b1;
    u_apb4_if.pwrite  = 1'b1;
    u_apb4_if.pwdata  = data;
    u_apb4_if.pstrb   = strb;
    #1;
    last_wait_cycles = 0;
    while (!u_apb4_if.pready) begin
      @(posedge clk);
      @(negedge clk);
      last_wait_cycles = last_wait_cycles + 1;
      if (last_wait_cycles > 8) $fatal(1, "APB4 write timeout");
      #1;
    end
    if (u_apb4_if.pslverr) $fatal(1, "APB4 write failed");
    @(posedge clk);
    @(negedge clk);
    idle();
  endtask

  task automatic read_register(input logic [11:0] address, input logic [31:0] expected);
    @(negedge clk);
    u_apb4_if.paddr   = {20'h0, address};
    u_apb4_if.psel    = 1'b1;
    u_apb4_if.penable = 1'b1;
    u_apb4_if.pwrite  = 1'b0;
    u_apb4_if.pstrb   = '0;
    #1;
    last_wait_cycles = 0;
    while (!u_apb4_if.pready) begin
      @(posedge clk);
      @(negedge clk);
      last_wait_cycles = last_wait_cycles + 1;
      if (last_wait_cycles > 8) $fatal(1, "APB4 read timeout");
      #1;
    end
    if (u_apb4_if.pslverr || (u_apb4_if.prdata !== expected)) begin
      $fatal(1, "APB4 read failed: got %h expected %h", u_apb4_if.prdata, expected);
    end
    @(posedge clk);
    @(negedge clk);
    idle();
  endtask

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
    idle();
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    read_register(`CRC_IP_ID_OFFSET, `CRC_IP_ID_VALUE);
    write_register(`CRC_CTRL_OFFSET, `CRC_CTRL_START_MASK, 4'hF);
    write_register(`CRC_DATA_OFFSET, 32'h3433_3231, 4'hF);
    if (last_wait_cycles == 0) $fatal(1, "Full-word DATA write did not insert wait states");
    write_register(`CRC_DATA_OFFSET, 32'h3837_3635, 4'hF);
    write_register(`CRC_DATA_OFFSET, 32'h0000_0039, 4'h1);
    write_register(`CRC_CTRL_OFFSET, `CRC_CTRL_FINISH_MASK, 4'hF);
    read_register(`CRC_RESULT_OFFSET, 32'hCBF4_3926);
    read_register(`CRC_BYTE_COUNT_OFFSET, 32'd9);

    $display("APB4_CRC_TEST_PASS");
    $finish;
  end

endmodule
