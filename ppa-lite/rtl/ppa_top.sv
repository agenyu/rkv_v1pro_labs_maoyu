module ppa_top (
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
  output logic        irq_o
);

  logic       enable;
  logic       start;
  logic       algo_mode;
  logic [3:0] type_mask;
  logic [5:0] exp_pkt_len;
  logic       done_irq_en;
  logic       err_irq_en;

  logic       pkt_mem_we;
  logic [2:0] pkt_mem_addr;
  logic [31:0] pkt_mem_wdata;
  logic       pkt_mem_re;
  logic [31:0] pkt_mem_rdata;

  logic       proc_rd_en;
  logic [2:0] proc_rd_addr;
  logic [31:0] proc_rd_data;

  logic       busy;
  logic       done;
  logic       format_ok;
  logic       length_error;
  logic       type_error;
  logic       chk_error;
  logic [5:0] res_pkt_len;
  logic [7:0] res_pkt_type;
  logic [7:0] res_payload_sum;
  logic [7:0] res_payload_xor;

  apb_slave_if u_m1 (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PWRITE(PWRITE),
    .PADDR(PADDR),
    .PWDATA(PWDATA),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR),
    .enable_o(enable),
    .start_o(start),
    .algo_mode_o(algo_mode),
    .type_mask_o(type_mask),
    .exp_pkt_len_o(exp_pkt_len),
    .done_irq_en_o(done_irq_en),
    .err_irq_en_o(err_irq_en),
    .pkt_mem_we_o(pkt_mem_we),
    .pkt_mem_addr_o(pkt_mem_addr),
    .pkt_mem_wdata_o(pkt_mem_wdata),
    .pkt_mem_re_o(pkt_mem_re),
    .pkt_mem_rdata_i(pkt_mem_rdata),
    .busy_i(busy),
    .done_i(done),
    .format_ok_i(format_ok),
    .length_error_i(length_error),
    .type_error_i(type_error),
    .chk_error_i(chk_error),
    .res_pkt_len_i(res_pkt_len),
    .res_pkt_type_i(res_pkt_type),
    .res_payload_sum_i(res_payload_sum),
    .res_payload_xor_i(res_payload_xor),
    .irq_o(irq_o)
  );

  packet_sram u_m2 (
    .clk(PCLK),
    .rst_n(PRESETn),
    .apb_wr_en(pkt_mem_we),
    .apb_addr(pkt_mem_addr),
    .apb_wr_data(pkt_mem_wdata),
    .proc_rd_en(proc_rd_en),
    .proc_rd_addr(proc_rd_addr),
    .proc_rd_data(proc_rd_data),
    .apb_rd_en(pkt_mem_re),
    .apb_rd_data(pkt_mem_rdata)
  );

  packet_proc_core u_m3 (
    .clk(PCLK),
    .rst_n(PRESETn),
    .start_i(start),
    .algo_mode_i(algo_mode),
    .type_mask_i(type_mask),
    .exp_pkt_len_i(exp_pkt_len),
    .mem_rd_en_o(proc_rd_en),
    .mem_rd_addr_o(proc_rd_addr),
    .mem_rd_data_i(proc_rd_data),
    .busy_o(busy),
    .done_o(done),
    .res_pkt_len_o(res_pkt_len),
    .res_pkt_type_o(res_pkt_type),
    .res_payload_sum_o(res_payload_sum),
    .res_payload_xor_o(res_payload_xor),
    .format_ok_o(format_ok),
    .length_error_o(length_error),
    .type_error_o(type_error),
    .chk_error_o(chk_error)
  );

endmodule
