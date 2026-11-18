// ============================================================================
// 实验3 用例代码 —— 只读副本
//
//   来源    : tb/ppa_pkg.sv 第 1041-1278 行
//   用例    : lab3_e2e_test / lab3_two_frames_test / lab3_busy_protect_test / lab3_irq_test / lab3_reset_recovery_test
//   基类    : base_test（tb/ppa_pkg.sv 第 380-769 行）
//   用到的方法（括号里是 tb/ppa_pkg.sv 的行号）：
//             reset_system(446)  apb_write(473)
//             apb_read(501)  write_packet_to_apb(586)
//             configure_top(593)  wait_top_done(612)
//             run_packet_top(651)  finish(760)
//   运行    : make lab3    波形 make wave3 -> lab3/wave_ppa/*.wlf
//   对照    : lab3/实验3_验收对照.md
//
//   本文件是从 tb/ppa_pkg.sv 摘出来的副本，方便一个目录里看完整实验；
//   编译不读这里。改代码请改 tb/ppa_pkg.sv，改完按 README 的说法重新生成此副本。
// ============================================================================

  // ======================================================================
  // [评分 3] 实验3 —— 必做/选做各项位置（全部走主通路 dut/ppa_top）
  //   必做1 端到端链路   3-必做1.1~1.3   lab3_e2e_test + run_packet_top
  //   必做2 连续两帧     3-必做2.1~2.2   lab3_two_frames_test + start_top
  //   必做3 STATUS 通路  3-必做3.1~3.2   lab3_busy_protect_test
  //   选做4 busy 写保护  3-选做4.1~4.2   lab3_busy_protect_test 中段
  //   选做5 中断闭环     3-选做5.1~5.2   lab3_irq_test
  //   运行 make lab3   波形 make wave3 -> lab3/wave_ppa/*.wlf（wave/ppa_wave.do）
  //   对照文档 lab3/实验3_验收对照.md
  // ----------------------------------------------------------------------
  // [评分 3-必做1.1 | 10分] 端到端：写 8 字节包 -> 启动 -> 等 done -> 读回 RES_*
  // [评分 3-必做1.2 | 5分]  APB 组与 M3 的 busy/done 同屏可看（wave/ppa_wave.do）
  // [评分 3-必做1.3 | 5分]  口述：M1 -> M3 的信号连接，见 run_packet_top 头部注释
  //   RTL : rtl/ppa_top.sv:80-108（线网连接）apb_slave_if.sv:142,146-149
  //   波形: lab3/wave_ppa/lab3_e2e_test.wlf 第 2/6 组
  // ======================================================================
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

  // [评分 3-必做2.1 | 10分] 连续两帧：len 4 -> 32，两帧的 RES_PKT_LEN 各自正确
  // [评分 3-必做2.2 | 5分]  两帧之间 done_o 有可见的清零过程（第二帧 start 同拍落 0）
  //   RTL : rtl/packet_proc_core.sv:133(done_r 在启动分支清零) 166-168(结果刷新)
  //   波形: lab3/wave_ppa/lab3_two_frames_test.wlf，done_o 一屏可见掉 0
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

  // ======================================================================
  // [评分 3-必做3.1 | 10分] busy 期间读 STATUS，[1:0] = 2'b01（处理中）
  // [评分 3-必做3.2 | 5分]  done 期间读 STATUS，[1:0] = 2'b10（完成）
  // [评分 3-选做4.1 | 15分] busy 时写 PKT_MEM：PSLVERR=1 且 SRAM 原值不变
  // [评分 3-选做4.2 | 5分]  口述：写脉冲与 PSLVERR 由同一条件控制，不会"报了错还写进去"
  //   RTL : rtl/apb_slave_if.sv:142(STATUS 位定义) 113-116(busy 写报错)
  //         81(we = write_access && window && !busy)
  //   波形: lab3/wave_ppa/lab3_busy_protect_test.wlf 第 2/4 组
  // ======================================================================
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
      // [评分 3-选做4.1 | 15分] 三项合一：PSLVERR 拉高（第三个参数 1）+ 写入被丢弃
      //   + 原值不变（下面 word_before / word_after 比对）
      apb_write(12'h044, 32'hDEAD_BEEF, 1);
      apb_read(12'h044, word_after, 0);
      check(word_before === word_after, "PKT_MEM changed during busy write-protect test");
      wait_top_done(done_ok);
      apb_read(12'h008, status, 0);
      check(status[1:0] === 2'b10, "STATUS done encoding mismatch");
      finish();
    endtask
  endclass

  // ======================================================================
  // [评分 1-选做5.1 | 10分] IRQ_EN 读写 / IRQ_STA RW1C（实验1 选做5）
  // [评分 1-选做5.2 | 5分]  irq_o = done_irq_sta | err_irq_sta（电平，不是脉冲）
  // [评分 1-选做5.3 | 5分]  口述：写 1 清 0、写 0 保持；irq_o 或的是 STA 不是 EN，
  //                     EN 只门控 STA 能否被置位
  // [评分 3-选做5.1 | 10分] 实验3 选做5：done 触发 irq、W1C 后 irq_o 落回 0
  // [评分 3-选做5.2 | 5分]  写 IRQ_STA.done_irq=1 后下一拍 irq_o=0
  //   RTL : rtl/apb_slave_if.sv:90(irq_o) 180-183(EN) 188-195(STA 置位) 197-204(RW1C)
  //   波形: lab3/wave_ppa/lab3_irq_test.wlf 第 5 组（wave/ppa_wave.do）
  // ======================================================================
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
      // 评分项：写 IRQ_STA.done_irq=1 之后下一拍 irq_o 必须落回 0
      check(vif.irq_o === 1'b0, "irq_o did not deassert after done_irq W1C");
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
      check(vif.irq_o === 1'b0, "irq_o did not deassert after err_irq W1C");
      finish();
    endtask
  endclass

  // [附加证据 非单独计分] 复位安全：PROCESS 中途拉低 PRESETn，恢复后
  //   busy_o/done_o 必须归 0；DONE 之后复位，RES_PKT_LEN/TYPE 必须归 0。
  //   RTL: rtl/packet_proc_core.sv:32-38, apb_slave_if.sv:156-167
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
