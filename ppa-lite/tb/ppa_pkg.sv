package ppa_pkg;

  typedef enum int {
    RESULT_OK    = 0,
    RESULT_LEN   = 1,
    RESULT_TYPE  = 2,
    RESULT_CHK   = 3,
    RESULT_MULTI = 4
  } result_kind_t;

  typedef struct {
    logic [11:0] addr;
    logic [31:0] data;
    bit          is_write;
    bit          error;
  } apb_transaction_t;

  class apb_monitor;
    virtual apb_intf vif;
    mailbox #(apb_transaction_t) mb;
    event observed_e;
    int unsigned observations;

    function new(input virtual apb_intf monitor_vif,
                 input mailbox #(apb_transaction_t) monitor_mb);
      vif         = monitor_vif;
      mb          = monitor_mb;
      observations = 0;
    endfunction

    task run();
      apb_transaction_t tr;
      forever begin
        @(posedge vif.PCLK);
        if (vif.PSEL && vif.PENABLE) begin
          tr.addr     = vif.PADDR;
          tr.data     = vif.PWRITE ? vif.PWDATA : vif.PRDATA;
          tr.is_write = vif.PWRITE;
          tr.error    = vif.PSLVERR;
          observations++;
          mb.put(tr);
          -> observed_e;
        end
      end
    endtask
  endclass

  class apb_scoreboard;
    mailbox #(apb_transaction_t) mb;
    int unsigned count;

    function new(input mailbox #(apb_transaction_t) scoreboard_mb);
      mb    = scoreboard_mb;
      count = 0;
    endfunction

    task run();
      apb_transaction_t tr;
      forever begin
        mb.get(tr);
        count++;
      end
    endtask
  endclass

  class packet_item;
    bit [5:0]  pkt_len;
    bit [7:0]  pkt_type;
    bit [7:0]  flags;
    bit [7:0]  hdr_chk;
    bit [7:0]  bytes [0:31];
    bit [31:0] words [0:7];
    bit [7:0]  payload_dyn [];
    bit [7:0]  bytes_q [$];

    rand int unsigned rand_len;
    rand int unsigned rand_type_idx;

    constraint c_rand_len {
      rand_len inside {[4:32]};
    }

    constraint c_rand_type_idx {
      rand_type_idx inside {[0:3]};
    }

    function new();
      clear();
    endfunction

    function void clear();
      int i;
      pkt_len   = 6'd0;
      pkt_type  = 8'h00;
      flags     = 8'h00;
      hdr_chk   = 8'h00;
      for (i = 0; i < 32; i = i + 1) begin
        bytes[i] = 8'h00;
      end
      for (i = 0; i < 8; i = i + 1) begin
        words[i] = 32'h0000_0000;
      end
      payload_dyn = new[0];
      bytes_q.delete();
    endfunction

    function bit [7:0] type_from_index(input int unsigned idx);
      case (idx)
        0: return 8'h01;
        1: return 8'h02;
        2: return 8'h04;
        3: return 8'h08;
        default: return 8'h03;
      endcase
    endfunction

    function void build(
      input int unsigned len,
      input bit [7:0] typ,
      input int unsigned pattern = 0
    );
      int i;
      int payload_limit;
      int payload_bytes;

      clear();
      pkt_len  = len[5:0];
      pkt_type = typ;
      flags    = 8'h00;
      bytes[0] = len[7:0];
      bytes[1] = typ;
      bytes[2] = flags;

      payload_limit = (len < 32) ? int'(len) : 32;
      payload_bytes = (payload_limit > 4) ? (payload_limit - 4) : 0;
      payload_dyn = new[payload_bytes];
      for (i = 4; i < payload_limit; i = i + 1) begin
        case (pattern)
          0:       bytes[i] = 8'h20 + i[7:0];
          1:       bytes[i] = (i % 2) ? 8'hA5 : 8'h5A;
          2:       bytes[i] = $urandom;
          default: bytes[i] = 8'h00;
        endcase
        payload_dyn[i - 4] = bytes[i];
      end

      bytes[3] = bytes[0] ^ bytes[1] ^ bytes[2];
      hdr_chk  = bytes[3];

      bytes_q.delete();
      bytes_q.push_back(bytes[0]);
      bytes_q.push_back(bytes[1]);
      bytes_q.push_back(bytes[2]);
      bytes_q.push_back(bytes[3]);
      foreach (payload_dyn[i]) begin
        bytes_q.push_back(payload_dyn[i]);
      end
      for (i = 0; i < bytes_q.size() && i < 32; i = i + 1) begin
        bytes[i] = bytes_q[i];
      end
      pack_words();
    endfunction

    function void build_random(input int unsigned pattern = 2);
      if (!randomize()) begin
        $fatal(1, "[RNDFAIL] packet_item randomize failed");
      end
      build(rand_len, type_from_index(rand_type_idx), pattern);
    endfunction

    function void force_bad_checksum();
      bytes[3] = bytes[3] ^ 8'h5A;
      hdr_chk  = bytes[3];
      pack_words();
    endfunction

    function void pack_words();
      int i;
      for (i = 0; i < 8; i = i + 1) begin
        words[i] = 32'h0000_0000;
      end
      for (i = 0; i < 32; i = i + 1) begin
        words[i / 4][((i % 4) * 8) +: 8] = bytes[i];
      end
    endfunction

    function int unsigned effective_len();
      return (pkt_len > 6'd32) ? 32 : int'(pkt_len);
    endfunction

    function bit [7:0] payload_sum();
      bit [7:0] value;
      int i;
      value = 8'h00;
      for (i = 4; i < effective_len(); i = i + 1) begin
        value = value + bytes[i];
      end
      return value;
    endfunction

    function bit [7:0] payload_xor();
      bit [7:0] value;
      int i;
      value = 8'h00;
      for (i = 4; i < effective_len(); i = i + 1) begin
        value = value ^ bytes[i];
      end
      return value;
    endfunction

    function bit length_error(input bit [5:0] exp_len);
      return (pkt_len < 6'd4) || (pkt_len > 6'd32) ||
             ((exp_len != 6'd0) && (pkt_len != exp_len));
    endfunction

    function bit type_error(input bit [3:0] mask);
      case (pkt_type)
        8'h01: return !mask[0];
        8'h02: return !mask[1];
        8'h04: return !mask[2];
        8'h08: return !mask[3];
        default: return 1'b1;
      endcase
    endfunction

    function bit chk_error(input bit algo_mode);
      bit [7:0] calc_chk;
      calc_chk = bytes[0] ^ bytes[1] ^ bytes[2];
      return algo_mode && (bytes[3] != calc_chk);
    endfunction

    function bit format_ok(
      input bit [3:0] mask,
      input bit [5:0] exp_len,
      input bit algo_mode
    );
      return !(length_error(exp_len) ||
               type_error(mask) ||
               chk_error(algo_mode));
    endfunction

    function result_kind_t result_kind(
      input bit [3:0] mask,
      input bit [5:0] exp_len,
      input bit algo_mode
    );
      bit le;
      bit te;
      bit ce;
      int unsigned count;

      le = length_error(exp_len);
      te = type_error(mask);
      ce = chk_error(algo_mode);
      count = le + te + ce;

      if (count == 0) return RESULT_OK;
      if (count > 1)  return RESULT_MULTI;
      if (le)         return RESULT_LEN;
      if (te)         return RESULT_TYPE;
      return RESULT_CHK;
    endfunction
  endclass

  class coverage_collector;
    int unsigned len_cat;
    int unsigned type_cat;
    int unsigned result_cat;
    int unsigned cfg_cat;
    int unsigned status_cat;

    covergroup cg_ppa;
      option.per_instance = 1;

      cp_len: coverpoint len_cat {
        bins min_len = {0};
        bins short_len = {1};
        bins mid_len   = {2};
        bins max_len = {3};
        bins under   = {4};
        bins over    = {5};
      }

      cp_type: coverpoint type_cat {
        bins type1 = {0};
        bins type2 = {1};
        bins type4 = {2};
        bins type8 = {3};
        bins bad   = {4};
      }

      cp_result: coverpoint result_cat {
        bins ok    = {0};
        bins len_e = {1};
        bins typ_e = {2};
        bins chk_e = {3};
        bins multi = {4};
      }

      cp_cfg: coverpoint cfg_cat {
        bins check  = {0};
        bins bypass = {1};
      }

      cp_status: coverpoint status_cat {
        bins ok  = {0};
        bins err = {1};
      }

      cross_status_cfg: cross cp_status, cp_cfg;
    endgroup

    function new();
      cg_ppa = new();
    endfunction

    function void sample(
      input packet_item pkt,
      input bit [3:0] mask,
      input bit [5:0] exp_len,
      input bit algo_mode
    );
      if (pkt.pkt_len == 6'd4) begin
        len_cat = 0;
      end
      else if ((pkt.pkt_len >= 6'd5) && (pkt.pkt_len <= 6'd8)) begin
        len_cat = 1;
      end
      else if ((pkt.pkt_len >= 6'd9) && (pkt.pkt_len <= 6'd24)) begin
        len_cat = 2;
      end
      else if (pkt.pkt_len == 6'd32) begin
        len_cat = 3;
      end
      else if (pkt.pkt_len < 6'd4) begin
        len_cat = 4;
      end
      else begin
        len_cat = 5;
      end

      case (pkt.pkt_type)
        8'h01: type_cat = 0;
        8'h02: type_cat = 1;
        8'h04: type_cat = 2;
        8'h08: type_cat = 3;
        default: type_cat = 4;
      endcase

      result_cat = pkt.result_kind(mask, exp_len, algo_mode);
      cfg_cat    = algo_mode ? 0 : 1;
      status_cat = (result_cat == RESULT_OK) ? 0 : 1;
      cg_ppa.sample();
    endfunction
  endclass

  class base_test;
    string name;
    virtual apb_intf vif;
    virtual apb_intf m1vif;
    virtual m3_intf m3vif;
    coverage_collector cov;
    semaphore apb_bus;
    apb_transaction_t apb_history [$];
    int errors;

    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      name   = test_name;
      vif    = main_vif;
      m1vif  = lab1_vif;
      m3vif  = standalone_vif;
      cov    = new();
      apb_bus = new(1);
      errors = 0;
    endfunction

    virtual task run();
      $fatal(1, "[TEST FAIL] base_test::run must be overridden");
    endtask

    function void check(input bit cond, input string msg);
      if (!cond) begin
        errors++;
        $error("[CHECK FAIL] %s: %s", name, msg);
      end
    endfunction

    function void record_apb(
      input logic [11:0] addr,
      input logic [31:0] data,
      input bit is_write,
      input bit error
    );
      apb_transaction_t tr;
      tr.addr     = addr;
      tr.data     = data;
      tr.is_write = is_write;
      tr.error    = error;
      apb_history.push_back(tr);
    endfunction

    task automatic idle_main_apb();
      vif.PSEL    = 1'b0;
      vif.PENABLE = 1'b0;
      vif.PWRITE  = 1'b0;
      vif.PADDR   = 12'h000;
      vif.PWDATA  = 32'h0000_0000;
    endtask

    task automatic idle_lab1_apb();
      m1vif.PSEL    = 1'b0;
      m1vif.PENABLE = 1'b0;
      m1vif.PWRITE  = 1'b0;
      m1vif.PADDR   = 12'h000;
      m1vif.PWDATA  = 32'h0000_0000;
    endtask

    task automatic reset_system();
      int i;
      @(negedge vif.PCLK);
      idle_main_apb();
      idle_lab1_apb();
      vif.PRESETn    = 1'b0;
      m1vif.PRESETn  = 1'b0;
      m3vif.rst_n    = 1'b0;
      m3vif.start_i  = 1'b0;
      m3vif.algo_mode_i = 1'b1;
      m3vif.type_mask_i = 4'hF;
      m3vif.exp_pkt_len_i = 6'd0;
      for (i = 0; i < 8; i = i + 1) begin
        m3vif.mem_words[i] = 32'h0000_0000;
      end
      m1vif.res_pkt_len_stub    = 6'd0;
      m1vif.res_pkt_type_stub   = 8'd0;
      m1vif.res_payload_sum_stub = 8'd0;
      m1vif.res_payload_xor_stub = 8'd0;
      m1vif.pkt_mem_rdata_stub   = 32'h0000_0000;
      repeat (4) @(negedge vif.PCLK);
      vif.PRESETn   = 1'b1;
      m1vif.PRESETn = 1'b1;
      m3vif.rst_n   = 1'b1;
      repeat (2) @(negedge vif.PCLK);
    endtask

    task automatic apb_write(
      input logic [11:0] addr,
      input logic [31:0] data,
      input bit exp_err = 1'b0
    );
      apb_bus.get(1);
      @(negedge vif.PCLK);
      vif.PSEL    = 1'b1;
      vif.PENABLE = 1'b0;
      vif.PWRITE  = 1'b1;
      vif.PADDR   = addr;
      vif.PWDATA  = data;
      @(negedge vif.PCLK);
      vif.PENABLE = 1'b1;
      @(posedge vif.PCLK);
      #1;
      check(vif.PREADY === 1'b1, $sformatf("PREADY low on write addr=0x%03h", addr));
      check(vif.PSLVERR === exp_err,
            $sformatf("write addr=0x%03h PSLVERR=%0b expected=%0b",
                      addr, vif.PSLVERR, exp_err));
      record_apb(addr, data, 1'b1, vif.PSLVERR);
      @(negedge vif.PCLK);
      vif.PSEL    = 1'b0;
      vif.PENABLE = 1'b0;
      vif.PWRITE  = 1'b0;
      apb_bus.put(1);
    endtask

    task automatic apb_read(
      input  logic [11:0] addr,
      output logic [31:0] data,
      input  bit exp_err = 1'b0
    );
      apb_bus.get(1);
      @(negedge vif.PCLK);
      vif.PSEL    = 1'b1;
      vif.PENABLE = 1'b0;
      vif.PWRITE  = 1'b0;
      vif.PADDR   = addr;
      @(negedge vif.PCLK);
      vif.PENABLE = 1'b1;
      @(posedge vif.PCLK);
      #1;
      data = vif.PRDATA;
      check(vif.PREADY === 1'b1, $sformatf("PREADY low on read addr=0x%03h", addr));
      check(vif.PSLVERR === exp_err,
            $sformatf("read addr=0x%03h PSLVERR=%0b expected=%0b",
                      addr, vif.PSLVERR, exp_err));
      record_apb(addr, data, 1'b0, vif.PSLVERR);
      @(negedge vif.PCLK);
      vif.PSEL    = 1'b0;
      vif.PENABLE = 1'b0;
      apb_bus.put(1);
    endtask

    task automatic lab1_apb_write(
      input logic [11:0] addr,
      input logic [31:0] data,
      input bit exp_err = 1'b0
    );
      @(negedge m1vif.PCLK);
      m1vif.PSEL    = 1'b1;
      m1vif.PENABLE = 1'b0;
      m1vif.PWRITE  = 1'b1;
      m1vif.PADDR   = addr;
      m1vif.PWDATA  = data;
      @(negedge m1vif.PCLK);
      m1vif.PENABLE = 1'b1;
      @(posedge m1vif.PCLK);
      #1;
      check(m1vif.PREADY === 1'b1, $sformatf("lab1 PREADY low on write addr=0x%03h", addr));
      check(m1vif.PSLVERR === exp_err,
            $sformatf("lab1 write addr=0x%03h PSLVERR=%0b expected=%0b",
                      addr, m1vif.PSLVERR, exp_err));
      @(negedge m1vif.PCLK);
      m1vif.PSEL    = 1'b0;
      m1vif.PENABLE = 1'b0;
      m1vif.PWRITE  = 1'b0;
    endtask

    task automatic lab1_apb_read(
      input  logic [11:0] addr,
      output logic [31:0] data,
      input  bit exp_err = 1'b0
    );
      @(negedge m1vif.PCLK);
      m1vif.PSEL    = 1'b1;
      m1vif.PENABLE = 1'b0;
      m1vif.PWRITE  = 1'b0;
      m1vif.PADDR   = addr;
      @(negedge m1vif.PCLK);
      m1vif.PENABLE = 1'b1;
      @(posedge m1vif.PCLK);
      #1;
      data = m1vif.PRDATA;
      check(m1vif.PREADY === 1'b1, $sformatf("lab1 PREADY low on read addr=0x%03h", addr));
      check(m1vif.PSLVERR === exp_err,
            $sformatf("lab1 read addr=0x%03h PSLVERR=%0b expected=%0b",
                      addr, m1vif.PSLVERR, exp_err));
      @(negedge m1vif.PCLK);
      m1vif.PSEL    = 1'b0;
      m1vif.PENABLE = 1'b0;
    endtask

    task automatic write_packet_to_apb(input packet_item pkt);
      int i;
      for (i = 0; i < 8; i = i + 1) begin
        apb_write(12'h040 + (i * 4), pkt.words[i], 1'b0);
      end
    endtask

    task automatic configure_top(
      input bit algo_mode,
      input bit [3:0] type_mask,
      input bit [5:0] exp_len
    );
      apb_write(12'h004, {24'b0, type_mask, 3'b0, algo_mode}, 1'b0);
      apb_write(12'h014, {26'b0, exp_len}, 1'b0);
      apb_write(12'h000, 32'h0000_0001, 1'b0);
    endtask

    task automatic start_top();
      apb_write(12'h000, 32'h0000_0003, 1'b0);
      @(negedge vif.PCLK);
      check(vif.busy_o === 1'b1, "busy_o did not assert after accepted start");
      check(vif.done_o === 1'b0, "done_o did not clear after accepted start");
    endtask

    task automatic wait_top_done(output bit ok);
      logic [31:0] status;
      int unsigned loops;
      ok = 1'b0;
      loops = 0;
      while (!ok && (loops < 300)) begin
        apb_read(12'h008, status, 1'b0);
        ok = status[1];
        loops++;
      end
      check(ok, "timed out waiting for STATUS.done");
    endtask

    task automatic read_top_results(
      output logic [31:0] status,
      output logic [31:0] res_len,
      output logic [31:0] res_type,
      output logic [31:0] res_sum,
      output logic [31:0] res_xor,
      output logic [31:0] err_flag
    );
      apb_read(12'h008, status, 1'b0);
      apb_read(12'h018, res_len, 1'b0);
      apb_read(12'h01C, res_type, 1'b0);
      apb_read(12'h020, res_sum, 1'b0);
      apb_read(12'h024, res_xor, 1'b0);
      apb_read(12'h028, err_flag, 1'b0);
    endtask

    task automatic run_packet_top(
      input packet_item pkt,
      input bit algo_mode,
      input bit [3:0] type_mask,
      input bit [5:0] exp_len,
      input bit sample_coverage = 1'b1
    );
      logic [31:0] status;
      logic [31:0] res_len;
      logic [31:0] res_type;
      logic [31:0] res_sum;
      logic [31:0] res_xor;
      logic [31:0] err_flag;
      bit done_ok;

      write_packet_to_apb(pkt);
      configure_top(algo_mode, type_mask, exp_len);
      start_top();
      wait_top_done(done_ok);
      read_top_results(status, res_len, res_type, res_sum, res_xor, err_flag);

      check(status[1] === 1'b1, "STATUS.done mismatch");
      check(status[2] === (err_flag[2:0] != 3'b000), "STATUS.error mismatch");
      check(status[3] === pkt.format_ok(type_mask, exp_len, algo_mode),
            "STATUS.format_ok mismatch");
      check(res_len[5:0] === pkt.pkt_len, "RES_PKT_LEN mismatch");
      check(res_type[7:0] === pkt.pkt_type, "RES_PKT_TYPE mismatch");
      check(res_sum[7:0] === pkt.payload_sum(), "RES_PAYLOAD_SUM mismatch");
      check(res_xor[7:0] === pkt.payload_xor(), "RES_PAYLOAD_XOR mismatch");
      check(err_flag[0] === pkt.length_error(exp_len), "ERR_FLAG.length mismatch");
      check(err_flag[1] === pkt.type_error(type_mask), "ERR_FLAG.type mismatch");
      check(err_flag[2] === pkt.chk_error(algo_mode), "ERR_FLAG.chk mismatch");

      if (sample_coverage) begin
        cov.sample(pkt, type_mask, exp_len, algo_mode);
      end
    endtask

    task automatic load_m3_packet(input packet_item pkt);
      int i;
      for (i = 0; i < 8; i = i + 1) begin
        m3vif.mem_words[i] = pkt.words[i];
      end
    endtask

    task automatic start_m3(
      input bit algo_mode,
      input bit [3:0] type_mask,
      input bit [5:0] exp_len
    );
      @(negedge m3vif.clk);
      m3vif.start_i      = 1'b1;
      m3vif.algo_mode_i  = algo_mode;
      m3vif.type_mask_i  = type_mask;
      m3vif.exp_pkt_len_i = exp_len;
      @(negedge m3vif.clk);
      m3vif.start_i = 1'b0;
    endtask

    task automatic run_packet_m3(
      input packet_item pkt,
      input bit algo_mode,
      input bit [3:0] type_mask,
      input bit [5:0] exp_len,
      input bit sample_coverage = 1'b1
    );
      int unsigned loops;
      bit done_ok;

      load_m3_packet(pkt);
      start_m3(algo_mode, type_mask, exp_len);
      @(negedge m3vif.clk);
      check(m3vif.busy_o === 1'b1, "M3 busy_o did not assert after start");
      check(m3vif.done_o === 1'b0, "M3 done_o did not clear after start");
      loops = 0;
      done_ok = 1'b0;
      while (!done_ok && (loops < 300)) begin
        @(posedge m3vif.clk);
        done_ok = m3vif.done_o;
        loops++;
      end
      #1;
      check(done_ok, "timed out waiting for standalone M3 done_o");
      check(m3vif.busy_o === 1'b0, "M3 busy_o stayed high in DONE");
      check(m3vif.res_pkt_len_o === pkt.pkt_len, "M3 RES_PKT_LEN mismatch");
      check(m3vif.res_pkt_type_o === pkt.pkt_type, "M3 RES_PKT_TYPE mismatch");
      check(m3vif.res_payload_sum_o === pkt.payload_sum(), "M3 payload sum mismatch");
      check(m3vif.res_payload_xor_o === pkt.payload_xor(), "M3 payload xor mismatch");
      check(m3vif.format_ok_o === pkt.format_ok(type_mask, exp_len, algo_mode),
            "M3 format_ok mismatch");
      check(m3vif.length_error_o === pkt.length_error(exp_len),
            "M3 length_error mismatch");
      check(m3vif.type_error_o === pkt.type_error(type_mask),
            "M3 type_error mismatch");
      check(m3vif.chk_error_o === pkt.chk_error(algo_mode),
            "M3 chk_error mismatch");

      if (sample_coverage) begin
        cov.sample(pkt, type_mask, exp_len, algo_mode);
      end
    endtask

    task automatic finish();
      if (errors != 0) begin
        $fatal(1, "[TEST FAIL] %s errors=%0d", name, errors);
      end
      else begin
        $display("[TEST PASS] %s", name);
        $finish;
      end
    endtask
  endclass

  class lab1_defaults_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      logic [31:0] data;
      reset_system();
      lab1_apb_read(12'h000, data, 0); check(data === 32'h0000_0000, "CTRL reset");
      lab1_apb_read(12'h004, data, 0); check(data === 32'h0000_00F1, "CFG reset");
      lab1_apb_read(12'h008, data, 0); check(data === 32'h0000_0000, "STATUS reset");
      lab1_apb_read(12'h00C, data, 0); check(data === 32'h0000_0000, "IRQ_EN reset");
      lab1_apb_read(12'h010, data, 0); check(data === 32'h0000_0000, "IRQ_STA reset");
      lab1_apb_read(12'h014, data, 0); check(data === 32'h0000_0000, "PKT_LEN_EXP reset");
      lab1_apb_read(12'h028, data, 0); check(data === 32'h0000_0000, "ERR_FLAG reset");
      m1vif.res_pkt_len_stub     = 6'h2A;
      m1vif.res_pkt_type_stub    = 8'hA5;
      m1vif.res_payload_sum_stub = 8'h3C;
      m1vif.res_payload_xor_stub = 8'h96;
      m1vif.pkt_mem_rdata_stub   = 32'hC001_2345;
      lab1_apb_read(12'h018, data, 0); check(data === 32'h0000_002A, "RES_PKT_LEN stub path");
      lab1_apb_read(12'h01C, data, 0); check(data === 32'h0000_00A5, "RES_PKT_TYPE stub path");
      lab1_apb_read(12'h020, data, 0); check(data === 32'h0000_003C, "RES_PAYLOAD_SUM stub path");
      lab1_apb_read(12'h024, data, 0); check(data === 32'h0000_0096, "RES_PAYLOAD_XOR stub path");
      lab1_apb_read(12'h040, data, 0); check(data === 32'hC001_2345, "PKT_MEM APB read path");
      lab1_apb_write(12'h000, 32'h0000_0001, 0);
      lab1_apb_write(12'h004, 32'h0000_0050, 0);
      lab1_apb_write(12'h00C, 32'h0000_0003, 0);
      lab1_apb_read(12'h000, data, 0); check(data === 32'h0000_0001, "CTRL write/read");
      lab1_apb_read(12'h004, data, 0); check(data === 32'h0000_0050, "CFG write/read");
      lab1_apb_read(12'h00C, data, 0); check(data === 32'h0000_0003, "IRQ_EN write/read");
      finish();
    endtask
  endclass

  class lab1_pkt_mem_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      logic [31:0] data;
      int i;
      reset_system();
      for (i = 0; i < 8; i = i + 1) begin
        apb_write(12'h040 + (i * 4), 32'hA500_0000 + i, 0);
      end
      for (i = 0; i < 8; i = i + 1) begin
        apb_read(12'h040 + (i * 4), data, 0);
        check(data === (32'hA500_0000 + i),
              $sformatf("PKT_MEM word %0d readback mismatch", i));
      end
      finish();
    endtask
  endclass

  class lab1_pslverr_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      logic [31:0] data;
      reset_system();
      lab1_apb_write(12'h008, 32'hFFFF_FFFF, 1);
      lab1_apb_write(12'h018, 32'hFFFF_FFFF, 1);
      lab1_apb_write(12'h02C, 32'hFFFF_FFFF, 1);
      lab1_apb_read(12'h02C, data, 1);
      lab1_apb_write(12'h000, 32'h0000_0002, 1);
      lab1_apb_write(12'h000, 32'h0000_0001, 0);
      lab1_apb_write(12'h000, 32'h0000_0003, 0);
      finish();
    endtask
  endclass

  class lab2_valid_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt;
      int unsigned lens[4] = '{4, 8, 16, 32};
      bit [7:0] types[4] = '{8'h01, 8'h02, 8'h04, 8'h08};
      int i;
      reset_system();
      for (i = 0; i < 4; i = i + 1) begin
        pkt = new();
        pkt.build(lens[i], types[i], 0);
        run_packet_m3(pkt, 1'b1, 4'hF, 6'd0);
      end
      finish();
    endtask
  endclass

  class lab2_errors_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt;
      reset_system();

      pkt = new(); pkt.build(3, 8'h01, 0);
      run_packet_m3(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(33, 8'h01, 0);
      run_packet_m3(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(12, 8'h03, 1);
      run_packet_m3(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(12, 8'h01, 1);
      run_packet_m3(pkt, 1'b1, 4'b1110, 6'd0);

      pkt = new(); pkt.build(16, 8'h04, 1); pkt.force_bad_checksum();
      run_packet_m3(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(16, 8'h04, 1); pkt.force_bad_checksum();
      run_packet_m3(pkt, 1'b0, 4'hF, 6'd0);

      pkt = new(); pkt.build(20, 8'h02, 0);
      run_packet_m3(pkt, 1'b1, 4'hF, 6'd24);

      pkt = new(); pkt.build(3, 8'h03, 0);
      run_packet_m3(pkt, 1'b1, 4'hF, 6'd0);

      finish();
    endtask
  endclass

  class lab3_e2e_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      logic [31:0] data;
      packet_item pkt;
      reset_system();
      pkt = new();
      pkt.build(8, 8'h02, 0);
      run_packet_top(pkt, 1'b1, 4'hF, 6'd8);
      apb_read(12'h00C, data, 0);
      check(data === 32'h0000_0000, "IRQ_EN unexpectedly nonzero");
      finish();
    endtask
  endclass

  class lab3_two_frames_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt0;
      packet_item pkt1;
      reset_system();
      pkt0 = new();
      pkt0.build(4, 8'h01, 0);
      pkt1 = new();
      pkt1.build(32, 8'h08, 1);
      run_packet_top(pkt0, 1'b1, 4'hF, 6'd4);
      run_packet_top(pkt1, 1'b1, 4'hF, 6'd32);
      finish();
    endtask
  endclass

  class lab3_busy_protect_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt;
      logic [31:0] word_before;
      logic [31:0] word_after;
      logic [31:0] status;
      bit done_ok;
      reset_system();
      pkt = new();
      pkt.build(32, 8'h08, 1);
      write_packet_to_apb(pkt);
      configure_top(1'b1, 4'hF, 6'd32);
      apb_write(12'h000, 32'h0000_0003, 0);
      apb_read(12'h008, status, 0);
      check(status[1:0] === 2'b01, "STATUS busy encoding mismatch");
      apb_read(12'h044, word_before, 0);
      apb_write(12'h044, 32'hDEAD_BEEF, 1);
      apb_read(12'h044, word_after, 0);
      check(word_before === word_after, "PKT_MEM changed during busy write-protect test");
      wait_top_done(done_ok);
      apb_read(12'h008, status, 0);
      check(status[1:0] === 2'b10, "STATUS done encoding mismatch");
      finish();
    endtask
  endclass

  class lab3_irq_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt;
      logic [31:0] data;
      reset_system();
      apb_write(12'h00C, 32'h0000_0003, 0);

      pkt = new();
      pkt.build(8, 8'h02, 0);
      write_packet_to_apb(pkt);
      configure_top(1'b1, 4'hF, 6'd8);
      apb_write(12'h000, 32'h0000_0003, 0);
      fork
        begin
          #200us;
          check(1'b0, "IRQ wait timeout");
        end
        begin
          while (vif.done_o !== 1'b1) @(posedge vif.PCLK);
        end
      join_any
      disable fork;
      #1;
      apb_read(12'h010, data, 0);
      check(data[0] === 1'b1, "done_irq did not set");
      check(vif.irq_o === 1'b1, "irq_o did not assert for done_irq");
      apb_write(12'h010, 32'h0000_0001, 0);
      apb_read(12'h010, data, 0);
      check(data[0] === 1'b0, "done_irq did not clear");
      apb_write(12'h00C, 32'h0000_0002, 0);

      pkt = new();
      pkt.build(12, 8'h04, 1);
      pkt.force_bad_checksum();
      write_packet_to_apb(pkt);
      configure_top(1'b1, 4'hF, 6'd12);
      apb_write(12'h000, 32'h0000_0003, 0);
      while (vif.done_o !== 1'b1) @(posedge vif.PCLK);
      #1;
      apb_read(12'h010, data, 0);
      check(data[1] === 1'b1, "err_irq did not set");
      check(vif.irq_o === 1'b1, "irq_o did not assert for err_irq");
      apb_write(12'h010, 32'h0000_0002, 0);
      apb_read(12'h010, data, 0);
      check(data[1] === 1'b0, "err_irq did not clear");
      finish();
    endtask
  endclass

  class lab3_reset_recovery_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt;
      logic [31:0] data;
      int i;
      reset_system();

      pkt = new();
      pkt.build(32, 8'h08, 1);
      write_packet_to_apb(pkt);
      configure_top(1'b1, 4'hF, 6'd32);
      apb_write(12'h000, 32'h0000_0003, 0);
      repeat (3) @(posedge vif.PCLK);
      @(negedge vif.PCLK);
      vif.PRESETn = 1'b0;
      m1vif.PRESETn = 1'b0;
      m3vif.rst_n = 1'b0;
      repeat (2) @(negedge vif.PCLK);
      vif.PRESETn = 1'b1;
      m1vif.PRESETn = 1'b1;
      m3vif.rst_n = 1'b1;
      repeat (2) @(negedge vif.PCLK);
      check(vif.busy_o === 1'b0, "busy_o after PROCESS reset");
      check(vif.done_o === 1'b0, "done_o after PROCESS reset");

      pkt = new();
      pkt.build(8, 8'h02, 0);
      run_packet_top(pkt, 1'b1, 4'hF, 6'd8);
      @(negedge vif.PCLK);
      vif.PRESETn = 1'b0;
      m3vif.rst_n = 1'b0;
      repeat (2) @(negedge vif.PCLK);
      vif.PRESETn = 1'b1;
      m3vif.rst_n = 1'b1;
      repeat (2) @(negedge vif.PCLK);
      apb_read(12'h018, data, 0);
      check(data === 32'h0000_0000, "RES_PKT_LEN after DONE reset");
      apb_read(12'h01C, data, 0);
      check(data === 32'h0000_0000, "RES_PKT_TYPE after DONE reset");
      finish();
    endtask
  endclass

  class lab4_random_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      mailbox #(packet_item) packet_mb;
      packet_item pkt;
      int unsigned i;
      reset_system();
      packet_mb = new();
      fork
        begin
          for (i = 0; i < 12; i = i + 1) begin
            pkt = new();
            if (!pkt.randomize()) begin
              $fatal(1, "[RNDFAIL] random packet generation failed");
            end
            pkt.build(pkt.rand_len, pkt.type_from_index(pkt.rand_type_idx), 2);
            packet_mb.put(pkt);
          end
        end
        begin
          for (i = 0; i < 12; i = i + 1) begin
            packet_mb.get(pkt);
            run_packet_top(pkt, 1'b1, 4'hF, 6'd0);
          end
        end
      join
      finish();
    endtask
  endclass

  class lab4_error_mix_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      packet_item pkt;
      result_kind_t expected_kind[string];
      reset_system();
      expected_kind["valid"]     = RESULT_OK;
      expected_kind["type_mask"] = RESULT_TYPE;
      expected_kind["checksum"]  = RESULT_CHK;
      expected_kind["bypass"]    = RESULT_OK;
      expected_kind["bad_type"]  = RESULT_TYPE;
      expected_kind["multi"]     = RESULT_MULTI;
      expected_kind["max"]       = RESULT_OK;
      expected_kind["bypass_len"] = RESULT_LEN;

      pkt = new(); pkt.build(5, 8'h01, 0);
      check(pkt.result_kind(4'hF, 6'd0, 1'b1) === expected_kind["valid"],
            "associative reference: valid");
      run_packet_top(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(24, 8'h04, 1);
      check(pkt.result_kind(4'h0, 6'd0, 1'b1) === expected_kind["type_mask"],
            "associative reference: type_mask");
      run_packet_top(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(16, 8'h04, 1); pkt.force_bad_checksum();
      check(pkt.result_kind(4'hF, 6'd0, 1'b1) === expected_kind["checksum"],
            "associative reference: checksum");
      run_packet_top(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(16, 8'h04, 1); pkt.force_bad_checksum();
      check(pkt.result_kind(4'hF, 6'd0, 1'b0) === expected_kind["bypass"],
            "associative reference: bypass");
      run_packet_top(pkt, 1'b0, 4'hF, 6'd0);

      pkt = new(); pkt.build(6, 8'h03, 0);
      check(pkt.result_kind(4'hF, 6'd0, 1'b1) === expected_kind["bad_type"],
            "associative reference: bad_type");
      run_packet_top(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(3, 8'h03, 0);
      check(pkt.result_kind(4'hF, 6'd0, 1'b1) === expected_kind["multi"],
            "associative reference: multi");
      run_packet_top(pkt, 1'b1, 4'hF, 6'd0);

      pkt = new(); pkt.build(32, 8'h08, 1);
      check(pkt.result_kind(4'hF, 6'd32, 1'b1) === expected_kind["max"],
            "associative reference: max");
      run_packet_top(pkt, 1'b1, 4'hF, 6'd32);

      pkt = new(); pkt.build(3, 8'h01, 0);
      check(pkt.result_kind(4'hF, 6'd0, 1'b0) === expected_kind["bypass_len"],
            "associative reference: bypass_len");
      run_packet_top(pkt, 1'b0, 4'hF, 6'd0);
      finish();
    endtask
  endclass

  class lab4_closure_test extends base_test;
    function new(
      input string test_name,
      input virtual apb_intf main_vif,
      input virtual apb_intf lab1_vif,
      input virtual m3_intf standalone_vif
    );
      super.new(test_name, main_vif, lab1_vif, standalone_vif);
    endfunction

    virtual task run();
      logic [31:0] data;
      logic [31:0] patterns[5];
      packet_item pkt;
      int i;
      bit done_ok;
      patterns[0] = 32'h0000_0000;
      patterns[1] = 32'hFFFF_FFFF;
      patterns[2] = 32'hAAAA_AAAA;
      patterns[3] = 32'h5555_5555;
      patterns[4] = 32'h8000_0001;

      reset_system();
      for (i = 0; i < 5; i = i + 1) begin
        for (int w = 0; w < 8; w = w + 1) begin
          apb_write(12'h040 + (w * 4), patterns[i], 0);
        end
        for (int w = 0; w < 8; w = w + 1) begin
          apb_read(12'h040 + (w * 4), data, 0);
          check(data === patterns[i], "PKT_MEM pattern readback");
        end
      end

      apb_read(12'h03C, data, 1);
      apb_read(12'h060, data, 1);
      apb_write(12'h03C, 32'hFFFF_FFFF, 1);
      apb_write(12'h060, 32'hFFFF_FFFF, 1);

      apb_write(12'h004, 32'h0000_0000, 0);
      apb_write(12'h004, 32'h0000_00FF, 0);
      apb_write(12'h00C, 32'h0000_0003, 0);
      apb_write(12'h014, 32'h0000_003F, 0);
      apb_write(12'h014, 32'h0000_0000, 0);

      apb_write(12'h000, 32'h0000_0000, 0);
      apb_write(12'h000, 32'h0000_0002, 1);
      apb_write(12'h000, 32'h0000_0001, 0);

      pkt = new();
      pkt.build(32, 8'h08, 2);
      write_packet_to_apb(pkt);
      configure_top(1'b1, 4'hF, 6'd32);
      apb_write(12'h000, 32'h0000_0003, 0);
      apb_write(12'h000, 32'h0000_0003, 1);
      wait_top_done(done_ok);

      pkt = new();
      pkt.build(33, 8'hA5, 1);
      run_packet_top(pkt, 1'b1, 4'h0, 6'd0);

      pkt = new();
      pkt.build(16, 8'h04, 1);
      pkt.force_bad_checksum();
      write_packet_to_apb(pkt);
      configure_top(1'b1, 4'hF, 6'd16);
      apb_write(12'h000, 32'h0000_0003, 0);
      wait_top_done(done_ok);
      apb_read(12'h010, data, 0);
      check(data[1] === 1'b1, "err_irq closure bit");
      apb_write(12'h010, 32'h0000_0002, 0);

      apb_write(12'h00C, 32'h0000_0000, 0);
      apb_write(12'h000, 32'h0000_0000, 0);
      apb_write(12'h004, 32'h0000_00F1, 0);
      finish();
    endtask
  endclass

  function automatic base_test create_test(
    input string test_name,
    input virtual apb_intf main_vif,
    input virtual apb_intf lab1_vif,
    input virtual m3_intf standalone_vif
  );
    lab1_defaults_test     t_defaults;
    lab1_pkt_mem_test      t_pkt_mem;
    lab1_pslverr_test      t_pslverr;
    lab2_valid_test        t_l2_valid;
    lab2_errors_test       t_l2_errors;
    lab3_e2e_test          t_e2e;
    lab3_two_frames_test   t_two_frames;
    lab3_busy_protect_test t_busy;
    lab3_irq_test          t_irq;
    lab3_reset_recovery_test t_reset;
    lab4_random_test       t_random;
    lab4_error_mix_test    t_error_mix;
    lab4_closure_test      t_closure;

    case (test_name)
      "lab1_defaults_test": begin
        t_defaults = new("lab1_defaults_test", main_vif, lab1_vif, standalone_vif);
        return t_defaults;
      end
      "lab1_pkt_mem_test": begin
        t_pkt_mem = new("lab1_pkt_mem_test", main_vif, lab1_vif, standalone_vif);
        return t_pkt_mem;
      end
      "lab1_pslverr_test": begin
        t_pslverr = new("lab1_pslverr_test", main_vif, lab1_vif, standalone_vif);
        return t_pslverr;
      end
      "lab2_valid_test": begin
        t_l2_valid = new("lab2_valid_test", main_vif, lab1_vif, standalone_vif);
        return t_l2_valid;
      end
      "lab2_errors_test": begin
        t_l2_errors = new("lab2_errors_test", main_vif, lab1_vif, standalone_vif);
        return t_l2_errors;
      end
      "lab3_e2e_test": begin
        t_e2e = new("lab3_e2e_test", main_vif, lab1_vif, standalone_vif);
        return t_e2e;
      end
      "lab3_two_frames_test": begin
        t_two_frames = new("lab3_two_frames_test", main_vif, lab1_vif, standalone_vif);
        return t_two_frames;
      end
      "lab3_busy_protect_test": begin
        t_busy = new("lab3_busy_protect_test", main_vif, lab1_vif, standalone_vif);
        return t_busy;
      end
      "lab3_irq_test": begin
        t_irq = new("lab3_irq_test", main_vif, lab1_vif, standalone_vif);
        return t_irq;
      end
      "lab3_reset_recovery_test": begin
        t_reset = new("lab3_reset_recovery_test", main_vif, lab1_vif, standalone_vif);
        return t_reset;
      end
      "lab4_random_test": begin
        t_random = new("lab4_random_test", main_vif, lab1_vif, standalone_vif);
        return t_random;
      end
      "lab4_error_mix_test": begin
        t_error_mix = new("lab4_error_mix_test", main_vif, lab1_vif, standalone_vif);
        return t_error_mix;
      end
      "lab4_closure_test": begin
        t_closure = new("lab4_closure_test", main_vif, lab1_vif, standalone_vif);
        return t_closure;
      end
      default: begin
        $fatal(1, "[TESTNAME] unknown test: %s", test_name);
        return null;
      end
    endcase
  endfunction

endpackage
