`timescale 1ns/1ps

module tb;
  import ppa_pkg::*;

  logic PCLK = 1'b0;

  always #5 PCLK = ~PCLK;

  apb_intf apb(PCLK);
  apb_intf m1_apb(PCLK);
  m3_intf m3(PCLK);

  ppa_top dut (
    .PCLK(PCLK),
    .PRESETn(apb.PRESETn),
    .PSEL(apb.PSEL),
    .PENABLE(apb.PENABLE),
    .PWRITE(apb.PWRITE),
    .PADDR(apb.PADDR),
    .PWDATA(apb.PWDATA),
    .PRDATA(apb.PRDATA),
    .PREADY(apb.PREADY),
    .PSLVERR(apb.PSLVERR),
    .irq_o(apb.irq_o)
  );

  assign apb.busy_o      = dut.busy;
  assign apb.done_o      = dut.done;
  assign apb.format_ok_o = dut.format_ok;
  assign apb.error_o     = dut.length_error | dut.type_error | dut.chk_error;

  apb_slave_if u_lab1_m1 (
    .PCLK(PCLK),
    .PRESETn(m1_apb.PRESETn),
    .PSEL(m1_apb.PSEL),
    .PENABLE(m1_apb.PENABLE),
    .PWRITE(m1_apb.PWRITE),
    .PADDR(m1_apb.PADDR),
    .PWDATA(m1_apb.PWDATA),
    .PRDATA(m1_apb.PRDATA),
    .PREADY(m1_apb.PREADY),
    .PSLVERR(m1_apb.PSLVERR),
    .enable_o(),
    .start_o(),
    .algo_mode_o(),
    .type_mask_o(),
    .exp_pkt_len_o(),
    .done_irq_en_o(),
    .err_irq_en_o(),
    .pkt_mem_we_o(),
    .pkt_mem_addr_o(),
    .pkt_mem_wdata_o(),
    .pkt_mem_re_o(),
    .pkt_mem_rdata_i(m1_apb.pkt_mem_rdata_stub),
    .busy_i(1'b0),
    .done_i(1'b0),
    .format_ok_i(1'b0),
    .length_error_i(1'b0),
    .type_error_i(1'b0),
    .chk_error_i(1'b0),
    .res_pkt_len_i(m1_apb.res_pkt_len_stub),
    .res_pkt_type_i(m1_apb.res_pkt_type_stub),
    .res_payload_sum_i(m1_apb.res_payload_sum_stub),
    .res_payload_xor_i(m1_apb.res_payload_xor_stub),
    .irq_o(m1_apb.irq_o)
  );

  packet_proc_core u_m3_standalone (
    .clk(PCLK),
    .rst_n(m3.rst_n),
    .start_i(m3.start_i),
    .algo_mode_i(m3.algo_mode_i),
    .type_mask_i(m3.type_mask_i),
    .exp_pkt_len_i(m3.exp_pkt_len_i),
    .mem_rd_en_o(m3.mem_rd_en_o),
    .mem_rd_addr_o(m3.mem_rd_addr_o),
    .mem_rd_data_i(m3.mem_rd_data_i),
    .busy_o(m3.busy_o),
    .done_o(m3.done_o),
    .res_pkt_len_o(m3.res_pkt_len_o),
    .res_pkt_type_o(m3.res_pkt_type_o),
    .res_payload_sum_o(m3.res_payload_sum_o),
    .res_payload_xor_o(m3.res_payload_xor_o),
    .format_ok_o(m3.format_ok_o),
    .length_error_o(m3.length_error_o),
    .type_error_o(m3.type_error_o),
    .chk_error_o(m3.chk_error_o)
  );

  always_ff @(posedge PCLK or negedge m3.rst_n) begin
    if (!m3.rst_n) begin
      m3.mem_rd_data_i <= 32'h0000_0000;
    end
    else if (m3.mem_rd_en_o) begin
      m3.mem_rd_data_i <= m3.mem_words[m3.mem_rd_addr_o];
    end
  end

  string test_name;
  base_test test;
  int unsigned test_seed;
  mailbox #(apb_transaction_t) apb_mb;
  apb_monitor apb_mon;
  apb_scoreboard apb_sb;

  initial begin
    apb.PRESETn = 1'b0;
    apb.PSEL    = 1'b0;
    apb.PENABLE = 1'b0;
    apb.PWRITE  = 1'b0;
    apb.PADDR   = 12'h000;
    apb.PWDATA  = 32'h0000_0000;

    m1_apb.PRESETn = 1'b0;
    m1_apb.PSEL    = 1'b0;
    m1_apb.PENABLE = 1'b0;
    m1_apb.PWRITE  = 1'b0;
    m1_apb.PADDR   = 12'h000;
    m1_apb.PWDATA  = 32'h0000_0000;
    m1_apb.res_pkt_len_stub     = 6'd0;
    m1_apb.res_pkt_type_stub    = 8'd0;
    m1_apb.res_payload_sum_stub = 8'd0;
    m1_apb.res_payload_xor_stub = 8'd0;
    m1_apb.pkt_mem_rdata_stub   = 32'h0000_0000;

    m3.rst_n        = 1'b0;
    m3.start_i      = 1'b0;
    m3.algo_mode_i  = 1'b1;
    m3.type_mask_i  = 4'hF;
    m3.exp_pkt_len_i = 6'd0;

    for (int i = 0; i < 8; i = i + 1) begin
      m3.mem_words[i] = 32'h0000_0000;
    end

    if (!$value$plusargs("TEST_SEED=%d", test_seed)) begin
      test_seed = 1;
    end
    if (!$value$plusargs("TESTNAME=%s", test_name)) begin
      test_name = "lab1_defaults_test";
    end

    $display("[TEST START] %s seed=%0d", test_name, test_seed);
    apb_mb = new();
    apb_mon = new(apb, apb_mb);
    apb_sb = new(apb_mb);
    fork
      apb_mon.run();
      apb_sb.run();
    join_none
    test = create_test(test_name, apb, m1_apb, m3);
    test.run();
  end

  initial begin
    #2ms;
    $fatal(1, "[TEST TIMEOUT] global simulation timeout");
  end

endmodule
