module apb_slave_if (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [11:0] PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA,
  output logic        PREADY,
  output logic        PSLVERR,

  output logic        enable_o,
  output logic        start_o,
  output logic        algo_mode_o,
  output logic [3:0]  type_mask_o,
  output logic [5:0]  exp_pkt_len_o,
  output logic        done_irq_en_o,
  output logic        err_irq_en_o,
  output logic        pkt_mem_we_o,
  output logic [2:0]  pkt_mem_addr_o,
  output logic [31:0] pkt_mem_wdata_o,
  output logic        pkt_mem_re_o,
  input  logic [31:0] pkt_mem_rdata_i,

  input  logic        busy_i,
  input  logic        done_i,
  input  logic        format_ok_i,
  input  logic        length_error_i,
  input  logic        type_error_i,
  input  logic        chk_error_i,
  input  logic [5:0]  res_pkt_len_i,
  input  logic [7:0]  res_pkt_type_i,
  input  logic [7:0]  res_payload_sum_i,
  input  logic [7:0]  res_payload_xor_i,

  output logic        irq_o
);

  localparam logic [11:0] ADDR_CTRL        = 12'h000;
  localparam logic [11:0] ADDR_CFG         = 12'h004;
  localparam logic [11:0] ADDR_STATUS      = 12'h008;
  localparam logic [11:0] ADDR_IRQ_EN      = 12'h00C;
  localparam logic [11:0] ADDR_IRQ_STA     = 12'h010;
  localparam logic [11:0] ADDR_PKT_LEN_EXP = 12'h014;
  localparam logic [11:0] ADDR_RES_LEN     = 12'h018;
  localparam logic [11:0] ADDR_RES_TYPE    = 12'h01C;
  localparam logic [11:0] ADDR_RES_SUM     = 12'h020;
  localparam logic [11:0] ADDR_RES_XOR     = 12'h024;
  localparam logic [11:0] ADDR_ERR_FLAG    = 12'h028;

  logic       ctrl_enable_r;
  logic       cfg_algo_mode_r;
  logic [3:0] cfg_type_mask_r;
  logic [5:0] pkt_len_exp_r;
  logic       done_irq_en_r;
  logic       err_irq_en_r;
  logic       done_irq_sta_r;
  logic       err_irq_sta_r;
  logic       done_d;
  logic       start_accept_pulse_r;

  logic       access;
  logic       write_access;
  logic       pkt_mem_window;
  logic       error_all;
  logic       start_req;
  logic       start_enabled;

  assign access          = PSEL && PENABLE;
  assign write_access    = access && PWRITE;
  assign pkt_mem_window  = (PADDR >= 12'h040) && (PADDR <= 12'h05C);
  assign error_all       = length_error_i || type_error_i || chk_error_i;
  assign start_req       = write_access && (PADDR == ADDR_CTRL) && PWDATA[1];
  assign start_enabled   = PWDATA[0] || ctrl_enable_r;

  assign PREADY          = 1'b1;
  assign start_o         = start_req && start_enabled && !busy_i;
  assign pkt_mem_addr_o  = PADDR[5:2];
  assign pkt_mem_wdata_o = PWDATA;
  assign pkt_mem_we_o    = write_access && pkt_mem_window && !busy_i;
  assign pkt_mem_re_o    = PSEL && !PENABLE && !PWRITE && pkt_mem_window;

  assign enable_o        = ctrl_enable_r;
  assign algo_mode_o     = cfg_algo_mode_r;
  assign type_mask_o     = cfg_type_mask_r;
  assign exp_pkt_len_o   = pkt_len_exp_r;
  assign done_irq_en_o   = done_irq_en_r;
  assign err_irq_en_o    = err_irq_en_r;
  assign irq_o           = done_irq_sta_r || err_irq_sta_r;

  function automatic logic readable_csr(input logic [11:0] addr);
    case (addr)
      ADDR_CTRL, ADDR_CFG, ADDR_STATUS, ADDR_IRQ_EN, ADDR_IRQ_STA,
      ADDR_PKT_LEN_EXP, ADDR_RES_LEN, ADDR_RES_TYPE, ADDR_RES_SUM,
      ADDR_RES_XOR, ADDR_ERR_FLAG: return 1'b1;
      default: return 1'b0;
    endcase
  endfunction

  function automatic logic writable_csr(input logic [11:0] addr);
    case (addr)
      ADDR_CTRL, ADDR_CFG, ADDR_IRQ_EN, ADDR_IRQ_STA, ADDR_PKT_LEN_EXP:
        return 1'b1;
      default:
        return 1'b0;
    endcase
  endfunction

  always_comb begin
    PSLVERR = 1'b0;
    if (access) begin
      if (pkt_mem_window) begin
        if (write_access) begin
          PSLVERR = busy_i;
        end
      end
      else if (write_access) begin
        if (!writable_csr(PADDR)) begin
          PSLVERR = 1'b1;
        end
        else if ((PADDR == ADDR_CTRL) && PWDATA[1] &&
                 !start_o && !start_accept_pulse_r) begin
          PSLVERR = 1'b1;
        end
      end
      else if (!readable_csr(PADDR)) begin
        PSLVERR = 1'b1;
      end
    end
  end

  always_comb begin
    PRDATA = 32'h0000_0000;
    if (pkt_mem_window) begin
      PRDATA = pkt_mem_rdata_i;
    end
    else begin
      case (PADDR)
        ADDR_CTRL:        PRDATA = {31'b0, ctrl_enable_r};
        ADDR_CFG:         PRDATA = {24'b0, cfg_type_mask_r, 3'b0, cfg_algo_mode_r};
        ADDR_STATUS:      PRDATA = {28'b0, format_ok_i, error_all, done_i, busy_i};
        ADDR_IRQ_EN:      PRDATA = {30'b0, err_irq_en_r, done_irq_en_r};
        ADDR_IRQ_STA:     PRDATA = {30'b0, err_irq_sta_r, done_irq_sta_r};
        ADDR_PKT_LEN_EXP: PRDATA = {26'b0, pkt_len_exp_r};
        ADDR_RES_LEN:     PRDATA = {26'b0, res_pkt_len_i};
        ADDR_RES_TYPE:    PRDATA = {24'b0, res_pkt_type_i};
        ADDR_RES_SUM:     PRDATA = {24'b0, res_payload_sum_i};
        ADDR_RES_XOR:     PRDATA = {24'b0, res_payload_xor_i};
        ADDR_ERR_FLAG:    PRDATA = {29'b0, chk_error_i, type_error_i, length_error_i};
        default:          PRDATA = 32'h0000_0000;
      endcase
    end
  end

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      ctrl_enable_r  <= 1'b0;
      cfg_algo_mode_r <= 1'b1;
      cfg_type_mask_r <= 4'hF;
      pkt_len_exp_r  <= 6'd0;
      done_irq_en_r  <= 1'b0;
      err_irq_en_r   <= 1'b0;
      done_irq_sta_r <= 1'b0;
      err_irq_sta_r  <= 1'b0;
      done_d         <= 1'b0;
      start_accept_pulse_r <= 1'b0;
    end
    else begin
      done_d <= done_i;
      start_accept_pulse_r <= start_o;

      if (write_access && (PADDR == ADDR_CTRL)) begin
        ctrl_enable_r <= PWDATA[0];
      end
      if (write_access && (PADDR == ADDR_CFG)) begin
        cfg_algo_mode_r <= PWDATA[0];
        cfg_type_mask_r <= PWDATA[7:4];
      end
      if (write_access && (PADDR == ADDR_IRQ_EN)) begin
        done_irq_en_r <= PWDATA[0];
        err_irq_en_r  <= PWDATA[1];
      end
      if (write_access && (PADDR == ADDR_PKT_LEN_EXP)) begin
        pkt_len_exp_r <= PWDATA[5:0];
      end

      if (done_i && !done_d) begin
        if (done_irq_en_r) begin
          done_irq_sta_r <= 1'b1;
        end
        if (err_irq_en_r && error_all) begin
          err_irq_sta_r <= 1'b1;
        end
      end

      if (write_access && (PADDR == ADDR_IRQ_STA)) begin
        if (PWDATA[0]) begin
          done_irq_sta_r <= 1'b0;
        end
        if (PWDATA[1]) begin
          err_irq_sta_r <= 1'b0;
        end
      end
    end
  end

endmodule
