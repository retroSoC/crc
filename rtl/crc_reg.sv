// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

`include "crc_define.svh"

module crc_reg (
    // verilog_format: off
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [11:0] paddr_i,
    input  logic        psel_i,
    input  logic        penable_i,
    input  logic        pwrite_i,
    input  logic [31:0] pwdata_i,
    input  logic [ 3:0] pstrb_i,
    output logic        pready_o,
    output logic [31:0] prdata_o,
    output logic        pslverr_o
    // verilog_format: on
);

  localparam logic [4:0] CONFIG_RESET = 5'h0F;
  localparam logic [31:0] POLYNOMIAL_RESET = 32'h04C1_1DB7;
  localparam logic [31:0] INIT_RESET = 32'hFFFF_FFFF;
  localparam logic [31:0] XOR_OUT_RESET = 32'hFFFF_FFFF;

  logic        s_access_phase;
  logic        s_read_phase;
  logic        s_write_phase;
  logic        s_transfer;
  logic        s_write;
  logic        s_access_legal;
  logic        s_state_violation;
  logic        s_config_violation;
  logic [31:0] s_write_mask;
  logic [31:0] s_masked_wdata;
  logic [31:0] s_ctrl_value;
  logic [31:0] s_config_merged;
  logic [31:0] s_polynomial_merged;
  logic [31:0] s_init_merged;
  logic [31:0] s_xor_out_merged;
  logic        s_data_strb_valid;
  logic        s_config_valid;
  logic [31:0] s_width_mask;

  logic [4:0] s_config_d, s_config_q;
  logic [31:0] s_polynomial_d, s_polynomial_q;
  logic [31:0] s_init_d, s_init_q;
  logic [31:0] s_xor_out_d, s_xor_out_q;
  logic s_config_lock_d, s_config_lock_q;
  logic [3:0] s_error_status_d, s_error_status_q;

  logic        s_start_command;
  logic        s_finish_command;
  logic        s_abort_command;
  logic        s_data_request;
  logic        s_data_accept;
  logic        s_data_busy;
  logic        s_data_ready;
  logic        s_active;
  logic        s_result_valid;
  logic [31:0] s_raw_state;
  logic [31:0] s_result;
  logic [31:0] s_byte_count;
  logic        s_count_overflow_event;

  function automatic logic [31:0] width_mask(input logic [1:0] width);
    case (width)
      `CRC_WIDTH_7:  width_mask = 32'h0000_007F;
      `CRC_WIDTH_8:  width_mask = 32'h0000_00FF;
      `CRC_WIDTH_16: width_mask = 32'h0000_FFFF;
      default:       width_mask = 32'hFFFF_FFFF;
    endcase
  endfunction

  function automatic logic onehot_command(input logic [2:0] command);
    onehot_command = (command == 3'b001) || (command == 3'b010) || (command == 3'b100);
  endfunction

  function automatic logic legal_data_strb(input logic [3:0] strb);
    case (strb)
      4'b0001, 4'b0010, 4'b0100, 4'b1000, 4'b0011, 4'b0110, 4'b1100, 4'b1111:
      legal_data_strb = 1'b1;
      default: legal_data_strb = 1'b0;
    endcase
  endfunction

  assign s_access_phase      = psel_i && penable_i;
  assign s_read_phase        = s_access_phase && !pwrite_i;
  assign s_write_phase       = s_access_phase && pwrite_i;
  assign s_transfer          = s_access_phase && pready_o;
  assign s_write             = s_transfer && pwrite_i;
  assign s_write_mask        = {{8{pstrb_i[3]}}, {8{pstrb_i[2]}}, {8{pstrb_i[1]}}, {8{pstrb_i[0]}}};
  assign s_masked_wdata      = pwdata_i & s_write_mask;
  assign s_ctrl_value        = s_masked_wdata & `CRC_CTRL_VALID_MASK;
  assign s_config_merged     = ({27'h0, s_config_q} & ~s_write_mask) | s_masked_wdata;
  assign s_polynomial_merged = (s_polynomial_q & ~s_write_mask) | s_masked_wdata;
  assign s_init_merged       = (s_init_q & ~s_write_mask) | s_masked_wdata;
  assign s_xor_out_merged    = (s_xor_out_q & ~s_write_mask) | s_masked_wdata;
  assign s_data_strb_valid   = legal_data_strb(pstrb_i);
  assign s_width_mask        = width_mask(s_config_q[1:0]);
  assign s_config_valid      = s_polynomial_q[0] && ((s_polynomial_q & ~s_width_mask) == '0);

  always_comb begin
    prdata_o           = '0;
    s_access_legal     = (paddr_i[1:0] == 2'b00);
    s_state_violation  = 1'b0;
    s_config_violation = 1'b0;

    if (s_read_phase && s_access_legal) begin
      unique case (paddr_i)
        `CRC_STATUS_OFFSET: begin
          prdata_o = {28'h0, |s_error_status_q, s_config_lock_q, s_result_valid, s_active};
        end
        `CRC_CONFIG_OFFSET:       prdata_o = {27'h0, s_config_q};
        `CRC_POLYNOMIAL_OFFSET:   prdata_o = s_polynomial_q;
        `CRC_INIT_OFFSET:         prdata_o = s_init_q;
        `CRC_XOR_OUT_OFFSET:      prdata_o = s_xor_out_q;
        `CRC_RESULT_OFFSET: begin
          prdata_o          = s_result;
          s_access_legal    = s_result_valid;
          s_state_violation = !s_result_valid;
        end
        `CRC_RAW_STATE_OFFSET:    prdata_o = s_raw_state;
        `CRC_BYTE_COUNT_OFFSET:   prdata_o = s_byte_count;
        `CRC_ERROR_STATUS_OFFSET: prdata_o = {28'h0, s_error_status_q};
        `CRC_CONFIG_LOCK_OFFSET:  prdata_o = {31'h0, s_config_lock_q};
        `CRC_IP_ID_OFFSET:        prdata_o = `CRC_IP_ID_VALUE;
        `CRC_IP_VERSION_OFFSET:   prdata_o = `CRC_IP_VERSION_VALUE;
        `CRC_CAPABILITY_OFFSET:   prdata_o = `CRC_CAPABILITY_VALUE;
        default: begin
          prdata_o       = '0;
          s_access_legal = 1'b0;
        end
      endcase
    end else if (s_write_phase && s_access_legal) begin
      s_access_legal = |pstrb_i;
      unique case (paddr_i)
        `CRC_CTRL_OFFSET: begin
          s_access_legal = s_access_legal &&
                           ((s_masked_wdata & ~`CRC_CTRL_VALID_MASK) == '0) &&
                           onehot_command(s_ctrl_value[2:0]);
          if (s_access_legal && (s_ctrl_value == `CRC_CTRL_START_MASK)) begin
            s_config_violation = !s_config_valid;
            s_state_violation  = s_active;
            s_access_legal     = s_config_valid && !s_active;
          end else if (s_access_legal && (s_ctrl_value == `CRC_CTRL_FINISH_MASK)) begin
            s_state_violation = !s_active;
            s_access_legal    = s_active;
          end else if (s_access_legal && (s_ctrl_value == `CRC_CTRL_ABORT_MASK)) begin
            s_state_violation = !s_active;
            s_access_legal    = s_active;
          end
        end
        `CRC_CONFIG_OFFSET: begin
          s_state_violation = s_active || s_config_lock_q;
          s_access_legal = s_access_legal && !s_state_violation &&
                           ((s_config_merged & ~`CRC_CONFIG_VALID_MASK) == '0);
        end
        `CRC_POLYNOMIAL_OFFSET, `CRC_INIT_OFFSET, `CRC_XOR_OUT_OFFSET: begin
          s_state_violation = s_active || s_config_lock_q;
          s_access_legal    = s_access_legal && !s_state_violation;
        end
        `CRC_DATA_OFFSET: begin
          s_state_violation = !s_active;
          s_access_legal    = s_access_legal && s_active && s_data_strb_valid;
        end
        `CRC_ERROR_STATUS_OFFSET: begin
          s_access_legal = s_access_legal && ((s_masked_wdata & ~`CRC_ERROR_VALID_MASK) == '0);
        end
        `CRC_CONFIG_LOCK_OFFSET: begin
          s_state_violation = s_active || s_config_lock_q;
          s_config_violation = !s_config_valid;
          s_access_legal = s_access_legal && !s_state_violation && s_config_valid &&
                           ((s_masked_wdata & ~`CRC_CONFIG_LOCK_MASK) == '0);
        end
        default: s_access_legal = 1'b0;
      endcase
    end else if (s_access_phase) begin
      s_access_legal = 1'b0;
    end
  end

  assign s_data_request = s_write_phase && s_access_legal && (paddr_i == `CRC_DATA_OFFSET);
  assign pready_o = !s_data_request || (s_data_ready && !s_data_busy);
  assign pslverr_o = s_transfer && !s_access_legal;
  assign s_start_command = s_write && s_access_legal && (paddr_i == `CRC_CTRL_OFFSET) &&
                           (s_ctrl_value == `CRC_CTRL_START_MASK);
  assign s_finish_command = s_write && s_access_legal && (paddr_i == `CRC_CTRL_OFFSET) &&
                            (s_ctrl_value == `CRC_CTRL_FINISH_MASK);
  assign s_abort_command = s_write && s_access_legal && (paddr_i == `CRC_CTRL_OFFSET) &&
                           (s_ctrl_value == `CRC_CTRL_ABORT_MASK);
  assign s_data_accept = s_write && s_access_legal && (paddr_i == `CRC_DATA_OFFSET);

  always_comb begin
    s_config_d       = s_config_q;
    s_polynomial_d   = s_polynomial_q;
    s_init_d         = s_init_q;
    s_xor_out_d      = s_xor_out_q;
    s_config_lock_d  = s_config_lock_q;
    s_error_status_d = s_error_status_q;

    if (s_write && s_access_legal) begin
      unique case (paddr_i)
        `CRC_CONFIG_OFFSET:       s_config_d = s_config_merged[4:0];
        `CRC_POLYNOMIAL_OFFSET:   s_polynomial_d = s_polynomial_merged;
        `CRC_INIT_OFFSET:         s_init_d = s_init_merged;
        `CRC_XOR_OUT_OFFSET:      s_xor_out_d = s_xor_out_merged;
        `CRC_ERROR_STATUS_OFFSET: s_error_status_d = s_error_status_q & ~s_masked_wdata[3:0];
        `CRC_CONFIG_LOCK_OFFSET:  s_config_lock_d = s_config_lock_q | s_masked_wdata[0];
        default: begin
        end
      endcase
    end

    if (s_transfer && !s_access_legal) begin
      if (s_config_violation) begin
        s_error_status_d[2] = 1'b1;
      end else if (s_state_violation) begin
        s_error_status_d[1] = 1'b1;
      end else begin
        s_error_status_d[0] = 1'b1;
      end
    end
    if (s_count_overflow_event) begin
      s_error_status_d[3] = 1'b1;
    end
  end

  crc_core u_crc_core (
      .clk_i                 (clk_i),
      .rst_n_i               (rst_n_i),
      .start_i               (s_start_command),
      .finish_i              (s_finish_command),
      .abort_i               (s_abort_command),
      .data_request_i        (s_data_request),
      .data_accept_i         (s_data_accept),
      .data_i                (pwdata_i),
      .data_strb_i           (pstrb_i),
      .width_i               (s_config_q[1:0]),
      .reflect_in_i          (s_config_q[2]),
      .reflect_out_i         (s_config_q[3]),
      .byte_swap_i           (s_config_q[4]),
      .polynomial_i          (s_polynomial_q),
      .init_i                (s_init_q),
      .xor_out_i             (s_xor_out_q),
      .active_o              (s_active),
      .result_valid_o        (s_result_valid),
      .raw_state_o           (s_raw_state),
      .result_o              (s_result),
      .byte_count_o          (s_byte_count),
      .count_overflow_event_o(s_count_overflow_event),
      .data_busy_o           (s_data_busy),
      .data_ready_o          (s_data_ready)
  );

  dffrc #(
      .DATA_WIDTH(5),
      .RESET_VAL (CONFIG_RESET)
  ) u_config_dffrc (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_config_d),
      .dat_o  (s_config_q)
  );

  dffrc #(
      .DATA_WIDTH(32),
      .RESET_VAL (POLYNOMIAL_RESET)
  ) u_polynomial_dffrc (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_polynomial_d),
      .dat_o  (s_polynomial_q)
  );

  dffrc #(
      .DATA_WIDTH(32),
      .RESET_VAL (INIT_RESET)
  ) u_init_dffrc (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_init_d),
      .dat_o  (s_init_q)
  );

  dffrc #(
      .DATA_WIDTH(32),
      .RESET_VAL (XOR_OUT_RESET)
  ) u_xor_out_dffrc (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_xor_out_d),
      .dat_o  (s_xor_out_q)
  );

  dffr #(
      .DATA_WIDTH(1)
  ) u_config_lock_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_config_lock_d),
      .dat_o  (s_config_lock_q)
  );

  dffr #(
      .DATA_WIDTH(4)
  ) u_error_status_dffr (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (s_error_status_d),
      .dat_o  (s_error_status_q)
  );

`ifdef FORMAL
  crc_formal_props u_crc_formal_props (
      .clk_i         (clk_i),
      .rst_n_i       (rst_n_i),
      .config_i      (s_config_q),
      .config_lock_i (s_config_lock_q),
      .start_i       (s_start_command),
      .finish_i      (s_finish_command),
      .abort_i       (s_abort_command),
      .access_legal_i(s_access_legal),
      .transfer_i    (s_transfer),
      .raw_state_i   (s_raw_state),
      .result_i      (s_result),
      .byte_count_i  (s_byte_count),
      .active_i      (s_active),
      .result_valid_i(s_result_valid),
      .data_valid_i  (s_data_accept),
      .data_strb_i   (pstrb_i),
      .data_request_i(s_data_request),
      .data_busy_i   (s_data_busy),
      .data_ready_i  (s_data_ready),
      .pready_i      (pready_o),
      .pslverr_i     (pslverr_o)
  );
`endif

endmodule
