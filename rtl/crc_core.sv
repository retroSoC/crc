// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`include "crc_define.svh"

module crc_core (
    // verilog_format: off
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        start_i,
    input  logic        finish_i,
    input  logic        abort_i,
    input  logic        data_request_i,
    input  logic        data_accept_i,
    input  logic [31:0] data_i,
    input  logic [ 3:0] data_strb_i,
    input  logic [ 1:0] width_i,
    input  logic        reflect_in_i,
    input  logic        reflect_out_i,
    input  logic        byte_swap_i,
    input  logic [31:0] polynomial_i,
    input  logic [31:0] init_i,
    input  logic [31:0] xor_out_i,
    output logic        active_o,
    output logic        result_valid_o,
    output logic [31:0] raw_state_o,
    output logic [31:0] result_o,
    output logic [31:0] byte_count_o,
    output logic        count_overflow_event_o,
    output logic        data_busy_o,
    output logic        data_ready_o
    // verilog_format: on
);

  logic s_active_d, s_active_q;
  logic s_result_valid_d, s_result_valid_q;
  logic [31:0] s_state_d, s_state_q;
  logic [31:0] s_result_d, s_result_q;
  logic [31:0] s_byte_count_d, s_byte_count_q;
  logic s_feed_active_d, s_feed_active_q;
  logic s_feed_done_d, s_feed_done_q;
  logic [1:0] s_lane_d, s_lane_q;
  logic [1:0] s_terminal_lane_d, s_terminal_lane_q;
  logic [31:0] s_pending_data_d, s_pending_data_q;
  logic [3:0] s_pending_strb_d, s_pending_strb_q;
  logic [31:0] s_width_mask;
  logic [31:0] s_write_bytes;
  logic [ 7:0] s_selected_byte;

  function automatic logic [31:0] crc_mask(input logic [1:0] width);
    case (width)
      `CRC_WIDTH_7:  crc_mask = 32'h0000_007F;
      `CRC_WIDTH_8:  crc_mask = 32'h0000_00FF;
      `CRC_WIDTH_16: crc_mask = 32'h0000_FFFF;
      default:       crc_mask = 32'hFFFF_FFFF;
    endcase
  endfunction

  function automatic logic [7:0] reflect_byte(input logic [7:0] value);
    reflect_byte = {value[0], value[1], value[2], value[3], value[4], value[5], value[6], value[7]};
  endfunction

  function automatic logic [31:0] reflect_value(input logic [31:0] value, input logic [1:0] width);
    case (width)
      `CRC_WIDTH_7: begin
        reflect_value = {
          25'h0, value[0], value[1], value[2], value[3], value[4], value[5], value[6]
        };
      end
      `CRC_WIDTH_8: begin
        reflect_value = {
          24'h0, value[0], value[1], value[2], value[3], value[4], value[5], value[6], value[7]
        };
      end
      `CRC_WIDTH_16: begin
        reflect_value = {
          16'h0,
          value[0],
          value[1],
          value[2],
          value[3],
          value[4],
          value[5],
          value[6],
          value[7],
          value[8],
          value[9],
          value[10],
          value[11],
          value[12],
          value[13],
          value[14],
          value[15]
        };
      end
      default: begin
        reflect_value = {
          value[0],
          value[1],
          value[2],
          value[3],
          value[4],
          value[5],
          value[6],
          value[7],
          value[8],
          value[9],
          value[10],
          value[11],
          value[12],
          value[13],
          value[14],
          value[15],
          value[16],
          value[17],
          value[18],
          value[19],
          value[20],
          value[21],
          value[22],
          value[23],
          value[24],
          value[25],
          value[26],
          value[27],
          value[28],
          value[29],
          value[30],
          value[31]
        };
      end
    endcase
  endfunction

  function automatic logic [6:0] step7(input logic [6:0] state, input logic data_bit,
                                       input logic [6:0] polynomial);
    step7 = {state[5:0], 1'b0} ^ ({7{state[6] ^ data_bit}} & polynomial);
  endfunction

  function automatic logic [7:0] step8(input logic [7:0] state, input logic data_bit,
                                       input logic [7:0] polynomial);
    step8 = {state[6:0], 1'b0} ^ ({8{state[7] ^ data_bit}} & polynomial);
  endfunction

  function automatic logic [15:0] step16(input logic [15:0] state, input logic data_bit,
                                         input logic [15:0] polynomial);
    step16 = {state[14:0], 1'b0} ^ ({16{state[15] ^ data_bit}} & polynomial);
  endfunction

  function automatic logic [31:0] step32(input logic [31:0] state, input logic data_bit,
                                         input logic [31:0] polynomial);
    step32 = {state[30:0], 1'b0} ^ ({32{state[31] ^ data_bit}} & polynomial);
  endfunction

  function automatic logic [6:0] update_byte7(input logic [6:0] state, input logic [7:0] data,
                                              input logic [6:0] polynomial);
    logic [6:0] current;
    current = step7(state, data[7], polynomial);
    current = step7(current, data[6], polynomial);
    current = step7(current, data[5], polynomial);
    current = step7(current, data[4], polynomial);
    current = step7(current, data[3], polynomial);
    current = step7(current, data[2], polynomial);
    current = step7(current, data[1], polynomial);
    current = step7(current, data[0], polynomial);
    return current;
  endfunction

  function automatic logic [7:0] update_byte8(input logic [7:0] state, input logic [7:0] data,
                                              input logic [7:0] polynomial);
    logic [7:0] current;
    current = step8(state, data[7], polynomial);
    current = step8(current, data[6], polynomial);
    current = step8(current, data[5], polynomial);
    current = step8(current, data[4], polynomial);
    current = step8(current, data[3], polynomial);
    current = step8(current, data[2], polynomial);
    current = step8(current, data[1], polynomial);
    current = step8(current, data[0], polynomial);
    return current;
  endfunction

  function automatic logic [15:0] update_byte16(input logic [15:0] state, input logic [7:0] data,
                                                input logic [15:0] polynomial);
    logic [15:0] current;
    current = step16(state, data[7], polynomial);
    current = step16(current, data[6], polynomial);
    current = step16(current, data[5], polynomial);
    current = step16(current, data[4], polynomial);
    current = step16(current, data[3], polynomial);
    current = step16(current, data[2], polynomial);
    current = step16(current, data[1], polynomial);
    current = step16(current, data[0], polynomial);
    return current;
  endfunction

  function automatic logic [31:0] update_byte32(input logic [31:0] state, input logic [7:0] data,
                                                input logic [31:0] polynomial);
    logic [31:0] current;
    current = step32(state, data[7], polynomial);
    current = step32(current, data[6], polynomial);
    current = step32(current, data[5], polynomial);
    current = step32(current, data[4], polynomial);
    current = step32(current, data[3], polynomial);
    current = step32(current, data[2], polynomial);
    current = step32(current, data[1], polynomial);
    current = step32(current, data[0], polynomial);
    return current;
  endfunction

  function automatic logic [31:0] update_byte(input logic [31:0] state, input logic [7:0] data,
                                              input logic [31:0] polynomial,
                                              input logic [1:0] width, input logic reflect_in);
    logic [7:0] ordered_data;
    ordered_data = reflect_in ? reflect_byte(data) : data;
    case (width)
      `CRC_WIDTH_7: begin
        update_byte = {25'h0, update_byte7(state[6:0], ordered_data, polynomial[6:0])};
      end
      `CRC_WIDTH_8: begin
        update_byte = {24'h0, update_byte8(state[7:0], ordered_data, polynomial[7:0])};
      end
      `CRC_WIDTH_16: begin
        update_byte = {16'h0, update_byte16(state[15:0], ordered_data, polynomial[15:0])};
      end
      default: update_byte = update_byte32(state, ordered_data, polynomial);
    endcase
  endfunction

  function automatic logic [1:0] lowest_lane(input logic [3:0] strb);
    if (strb[0]) begin
      lowest_lane = 2'd0;
    end else if (strb[1]) begin
      lowest_lane = 2'd1;
    end else if (strb[2]) begin
      lowest_lane = 2'd2;
    end else if (strb[3]) begin
      lowest_lane = 2'd3;
    end else begin
      lowest_lane = 2'd0;
    end
  endfunction

  function automatic logic [1:0] highest_lane(input logic [3:0] strb);
    if (strb[3]) begin
      highest_lane = 2'd3;
    end else if (strb[2]) begin
      highest_lane = 2'd2;
    end else if (strb[1]) begin
      highest_lane = 2'd1;
    end else if (strb[0]) begin
      highest_lane = 2'd0;
    end else begin
      highest_lane = 2'd3;
    end
  endfunction

  assign s_width_mask = crc_mask(width_i);
  assign s_write_bytes = {31'd0, s_pending_strb_q[0]} + {31'd0, s_pending_strb_q[1]} +
                         {31'd0, s_pending_strb_q[2]} + {31'd0, s_pending_strb_q[3]};

  always_comb begin
    unique case (s_lane_q)
      2'd0:    s_selected_byte = s_pending_data_q[7:0];
      2'd1:    s_selected_byte = s_pending_data_q[15:8];
      2'd2:    s_selected_byte = s_pending_data_q[23:16];
      default: s_selected_byte = s_pending_data_q[31:24];
    endcase
  end

  always_comb begin
    s_feed_active_d   = s_feed_active_q;
    s_feed_done_d     = s_feed_done_q;
    s_lane_d          = s_lane_q;
    s_terminal_lane_d = s_terminal_lane_q;
    s_pending_data_d  = s_pending_data_q;
    s_pending_strb_d  = s_pending_strb_q;

    if (start_i || abort_i) begin
      s_feed_active_d   = 1'b0;
      s_feed_done_d     = 1'b0;
      s_lane_d          = '0;
      s_terminal_lane_d = '0;
      s_pending_data_d  = '0;
      s_pending_strb_d  = '0;
    end else if (data_request_i && !s_feed_active_q && !s_feed_done_q) begin
      s_feed_active_d   = 1'b1;
      s_pending_data_d  = data_i;
      s_pending_strb_d  = data_strb_i;
      s_lane_d          = byte_swap_i ? highest_lane(data_strb_i) : lowest_lane(data_strb_i);
      s_terminal_lane_d = byte_swap_i ? lowest_lane(data_strb_i) : highest_lane(data_strb_i);
    end else if (s_feed_active_q) begin
      if (s_lane_q == s_terminal_lane_q) begin
        s_feed_active_d = 1'b0;
        s_feed_done_d   = 1'b1;
      end else if (byte_swap_i) begin
        s_lane_d = s_lane_q - 1'b1;
      end else begin
        s_lane_d = s_lane_q + 1'b1;
      end
    end else if (data_accept_i && s_feed_done_q) begin
      s_feed_done_d = 1'b0;
    end
  end

  always_comb begin
    s_active_d             = s_active_q;
    s_result_valid_d       = s_result_valid_q;
    s_state_d              = s_state_q;
    s_result_d             = s_result_q;
    s_byte_count_d         = s_byte_count_q;
    count_overflow_event_o = 1'b0;

    if (start_i) begin
      s_active_d       = 1'b1;
      s_result_valid_d = 1'b0;
      s_state_d        = init_i & s_width_mask;
      s_result_d       = '0;
      s_byte_count_d   = '0;
    end else if (abort_i) begin
      s_active_d       = 1'b0;
      s_result_valid_d = 1'b0;
      s_state_d        = init_i & s_width_mask;
      s_result_d       = '0;
      s_byte_count_d   = '0;
    end else if (s_feed_active_q) begin
      s_state_d = update_byte(s_state_q, s_selected_byte, polynomial_i, width_i, reflect_in_i);

      if (s_lane_q == s_terminal_lane_q) begin
        if (s_byte_count_q > (32'hFFFF_FFFF - s_write_bytes)) begin
          s_byte_count_d         = 32'hFFFF_FFFF;
          count_overflow_event_o = 1'b1;
        end else begin
          s_byte_count_d = s_byte_count_q + s_write_bytes;
        end
      end
    end else if (finish_i) begin
      s_active_d = 1'b0;
      s_result_valid_d = 1'b1;
      s_result_d = ((reflect_out_i ? reflect_value(s_state_q, width_i) : s_state_q) ^ xor_out_i) &
          s_width_mask;
    end
  end

  assign active_o       = s_active_q;
  assign result_valid_o = s_result_valid_q;
  assign raw_state_o    = s_state_q & s_width_mask;
  assign result_o       = s_result_q;
  assign byte_count_o   = s_byte_count_q;
  assign data_busy_o    = s_feed_active_q;
  assign data_ready_o   = s_feed_done_q;

  dffr #(
      .DATA_WIDTH(1)
  ) u_active_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_active_d),
      .dat_o  (s_active_q)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_result_valid_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_result_valid_d),
      .dat_o  (s_result_valid_q)
  );

  dffr #(
      .DATA_WIDTH(32)
  ) u_state_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_state_d),
      .dat_o  (s_state_q)
  );

  dffr #(
      .DATA_WIDTH(32)
  ) u_result_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_result_d),
      .dat_o  (s_result_q)
  );

  dffr #(
      .DATA_WIDTH(32)
  ) u_byte_count_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_byte_count_d),
      .dat_o  (s_byte_count_q)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_feed_active_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_feed_active_d),
      .dat_o  (s_feed_active_q)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_feed_done_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_feed_done_d),
      .dat_o  (s_feed_done_q)
  );

  dffr #(
      .DATA_WIDTH(2)
  ) u_lane_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_lane_d),
      .dat_o  (s_lane_q)
  );

  dffr #(
      .DATA_WIDTH(2)
  ) u_terminal_lane_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_terminal_lane_d),
      .dat_o  (s_terminal_lane_q)
  );

  dffr #(
      .DATA_WIDTH(32)
  ) u_pending_data_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_pending_data_d),
      .dat_o  (s_pending_data_q)
  );

  dffr #(
      .DATA_WIDTH(4)
  ) u_pending_strb_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_pending_strb_d),
      .dat_o  (s_pending_strb_q)
  );

endmodule
