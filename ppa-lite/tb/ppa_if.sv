interface apb_intf(input logic PCLK);
  logic        PRESETn;
  logic        PSEL;
  logic        PENABLE;
  logic        PWRITE;
  logic [11:0] PADDR;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;
  logic        PREADY;
  logic        PSLVERR;

  logic        busy_o;
  logic        done_o;
  logic        format_ok_o;
  logic        error_o;
  logic        irq_o;

  logic [5:0]  res_pkt_len_stub;
  logic [7:0]  res_pkt_type_stub;
  logic [7:0]  res_payload_sum_stub;
  logic [7:0]  res_payload_xor_stub;
  logic [31:0] pkt_mem_rdata_stub;
endinterface

interface m3_intf(input logic clk);
  logic        rst_n;
  logic        start_i;
  logic        algo_mode_i;
  logic [3:0]  type_mask_i;
  logic [5:0]  exp_pkt_len_i;

  logic        mem_rd_en_o;
  logic [2:0]  mem_rd_addr_o;
  logic [31:0] mem_rd_data_i;

  logic        busy_o;
  logic        done_o;
  logic [5:0]  res_pkt_len_o;
  logic [7:0]  res_pkt_type_o;
  logic [7:0]  res_payload_sum_o;
  logic [7:0]  res_payload_xor_o;
  logic        format_ok_o;
  logic        length_error_o;
  logic        type_error_o;
  logic        chk_error_o;

  logic [31:0] mem_words [0:7];
endinterface
