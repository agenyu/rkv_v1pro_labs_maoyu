// ============================================================================
// 实验2 用例代码 —— 只读副本
//
//   来源    : tb/ppa_pkg.sv 第 916-1039 行
//   用例    : lab2_valid_test / lab2_errors_test
//   基类    : base_test（tb/ppa_pkg.sv 第 380-769 行）
//   用到的方法（括号里是 tb/ppa_pkg.sv 的行号）：
//             reset_system(446)  run_packet_m3(717)
//             finish(760)
//   运行    : make lab2    波形 make wave2 -> lab2/wave_ppa/*.wlf
//   对照    : lab2/实验2_验收对照.md
//
//   本文件是从 tb/ppa_pkg.sv 摘出来的副本，方便一个目录里看完整实验；
//   编译不读这里。改代码请改 tb/ppa_pkg.sv，改完按 README 的说法重新生成此副本。
// ============================================================================

  // ======================================================================
  // [评分 2] 实验2 —— 必做/选做各项位置（全部驱动 /tb/u_m3_standalone，不走 APB）
  //   必做1 合法包处理   2-必做1.1~1.3   lab2_valid_test + run_packet_m3
  //   必做2 长度越界     2-必做2.1~2.3   lab2_errors_test 第 1/2 包
  //   必做3 busy/done    2-必做3.1~3.2   lab2_valid_test 末尾 + run_packet_m3
  //   选做4 type/mask    2-选做4.1~4.2   lab2_errors_test 第 3/4 包
  //   选做5 hdr_chk      2-选做5.1~5.3   lab2_errors_test 第 5/6 包 + run_packet_m3
  //   运行 make lab2   波形 make wave2 -> lab2/wave_ppa/*.wlf（wave/ppa_wave_m3.do）
  //   对照文档 lab2/实验2_验收对照.md
  // ----------------------------------------------------------------------
  // [评分 2-必做1.1 | 10分] 合法包结果正确：4 种长度(4/8/16/32) x 4 种合法类型
  // [评分 2-必做1.2 | 5分]  FSM 波形 IDLE -> PROCESS -> DONE
  //                     （wave/ppa_wave_m3.do 第 3 组，state 按符号名显示）
  // [评分 2-必做1.3 | 5分]  口述：每读一个字在 PROCESS 停一拍，首字 4 字节是包头
  // [评分 2-必做3.1 | 10分] start_i 之后第 1 拍 busy_o 必须为 1（零延迟响应）
  // [评分 2-必做3.2 | 5分]  DONE 态 done_o 持续保持，再次 start 同拍清零
  //   RTL : rtl/packet_proc_core.sv:119-138（启动分支）132（busy_r 同拍置位）
  //         223-228（S_DONE 每拍保持 done_r=1）
  //   波形: lab2/wave_ppa/lab2_valid_test.wlf
  // ======================================================================
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

      // ---- [评分 2-必做3.2 | 5分] DONE 态 done_o 是电平保持（连续 3 拍仍为 1），
      //      再次 start 的同一拍 done_o 必须清 0，busy_o 同时抬起 ----
      // ---- 评分项：DONE 态 done_o 持续保持，再次 start 后清零 ----
      repeat (3) @(posedge m3vif.clk);
      #1;
      check(m3vif.done_o === 1'b1, "done_o did not hold while in DONE");
      check(m3vif.busy_o === 1'b0, "busy_o not low while in DONE");

      // 再次 start：busy_o 必须在采样 start 的那一拍就起来，done_o 同时清 0
      @(negedge m3vif.clk);
      m3vif.start_i       = 1'b1;
      m3vif.algo_mode_i   = 1'b1;
      m3vif.type_mask_i   = 4'hF;
      m3vif.exp_pkt_len_i = 6'd0;
      @(posedge m3vif.clk);
      #1;
      // [评分 2-必做3.1 | 10分] start_i 在 negedge 摆好，posedge 采样，再过 1ns 检查：
      //   期望 busy_o 在采样 start 的同一拍就为 1，中间没有额外延迟。
      //   RTL: rtl/packet_proc_core.sv:132 —— busy_r 与 start 判定在同一个 always_ff 里
      check(m3vif.busy_o === 1'b1, "busy_o not asserted on the first cycle after start_i");
      check(m3vif.done_o === 1'b0, "done_o not cleared by re-start");
      @(negedge m3vif.clk);
      m3vif.start_i = 1'b0;

      finish();
    endtask
  endclass

  // ======================================================================
  // [评分 2-必做2.1 | 5分]  len=3  下溢（<4）  -> length_error，仍正常 done
  // [评分 2-必做2.2 | 5分]  len=33 上溢（>32） -> length_error，仍正常 done
  // [评分 2-必做2.3 | 5分]  两种越界情形 done_o 都必须拉高（不挂死）
  // [评分 2-选做4.1 | 10分] type=0x03 不是 one-hot -> type_error（任何 mask 都非法）
  // [评分 2-选做4.2 | 5分]  type=0x01 合法，但 type_mask=4'b1110 关掉 bit0 -> type_error
  // [评分 2-选做5.1 | 8分]  hdr_chk 错误且 algo_mode=1 -> chk_error=1
  // [评分 2-选做5.2 | 7分]  同一个坏包、algo_mode=0 -> chk_error=0（旁路不校验）
  // [评分 2-选做5.3 | 5分]  payload sum/XOR 与参考模型一致（首字 4 字节是包头，不计入）
  //   RTL : rtl/packet_proc_core.sv:170-172(长度判定) 85-96(类型合法) 174-176(校验)
  //         183-193(payload 累加/异或)
  //   波形: lab2/wave_ppa/lab2_errors_test.wlf 第 6 组
  // ======================================================================
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
