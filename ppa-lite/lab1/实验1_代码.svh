// ============================================================================
// 实验1 用例代码 —— 只读副本
//
//   来源    : tb/ppa_pkg.sv 第 771-914 行
//   用例    : lab1_defaults_test / lab1_pkt_mem_test / lab1_pslverr_test
//   基类    : base_test（tb/ppa_pkg.sv 第 380-769 行）
//   用到的方法（括号里是 tb/ppa_pkg.sv 的行号）：
//             reset_system(446)  apb_write(473)
//             apb_read(501)  lab1_apb_write(537)
//             lab1_apb_read(562)  finish(760)
//   运行    : make lab1    波形 make wave1 -> lab1/wave_ppa/*.wlf
//   对照    : lab1/实验1_验收对照.md
//
//   本文件是从 tb/ppa_pkg.sv 摘出来的副本，方便一个目录里看完整实验；
//   编译不读这里。改代码请改 tb/ppa_pkg.sv，改完按 README 的说法重新生成此副本。
// ============================================================================

  // ======================================================================
  // [评分 1] 实验1 —— 必做/选做各项位置（都在本文件）
  //   必做1 APB 读写时序  1-必做1.1~1.3
  //         1.1 寄存器默认值  lab1_defaults_test.run() 开头 7 行
  //         1.2 两段式时序    lab1_apb_write() / lab1_apb_read()
  //         1.3 PRDATA 存放在哪（口述）—— [评分 1-必做1.3]
  //             PRDATA 是组合输出：写进 always_ff 的 *_r，读走 always_comb 的 case
  //   必做2 PKT_MEM 映射  1-必做2.1~2.3   lab1_pkt_mem_test
  //   必做3 RES_* 读通路  1-必做3.1~3.3   lab1_defaults_test 中段 + lab4_code_cov_test
  //         3.1 四个 RES 寄存器  3.2 地址译码完整  3.3 [评分 1-必做3.3] 口述三区：
  //         CSR 区 0x000-0x028（11 个）/ PKT_MEM 区 0x040-0x05C（8 字）/ 其余非法
  //   选做4 PSLVERR       1-选做4.1~4.3   lab1_pslverr_test
  //         4.3 [评分 1-选做4.3] 口述四个来源：写不可写 / 读不可读 / busy 写 / 未使能 start
  //   选做5 IRQ           1-选做5.1~5.3   lab3_irq_test（在实验3 那一段里）
  //   运行 make lab1   波形 make wave1 -> lab1/wave_ppa/*.wlf
  //   对照文档 lab1/实验1_验收对照.md
  // ======================================================================
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
      // ---------------- [评分 1-必做1.1 | 10分] CTRL/CFG/STATUS 默认值 ----------------
      // 期望 CTRL=0x0000_0000、CFG=0x0000_00F1、STATUS=0x0000_0000，
      // IRQ_EN / IRQ_STA / PKT_LEN_EXP / ERR_FLAG 的复位值也都是 0。
      //   RTL : rtl/apb_slave_if.sv:156-167（复位分支）
      //   提示: CFG 的 0xF1 在 RTL 里没有字面量，是 141 行拼出来的
      //         {24'b0, cfg_type_mask_r(4'hF), 3'b0, cfg_algo_mode_r(1)} = 0xF1
      //   波形: lab1/wave_ppa/lab1_defaults_test.wlf 第 3 组（wave/ppa_wave_lab1.do）
      // -------------------------------------------------------------------------
      lab1_apb_read(12'h000, data, 0); check(data === 32'h0000_0000, "CTRL reset");
      lab1_apb_read(12'h004, data, 0); check(data === 32'h0000_00F1, "CFG reset");
      lab1_apb_read(12'h008, data, 0); check(data === 32'h0000_0000, "STATUS reset");
      lab1_apb_read(12'h00C, data, 0); check(data === 32'h0000_0000, "IRQ_EN reset");
      lab1_apb_read(12'h010, data, 0); check(data === 32'h0000_0000, "IRQ_STA reset");
      lab1_apb_read(12'h014, data, 0); check(data === 32'h0000_0000, "PKT_LEN_EXP reset");
      lab1_apb_read(12'h028, data, 0); check(data === 32'h0000_0000, "ERR_FLAG reset");
      // ---------------- [评分 1-必做3.1 | 10分] RES_* 读通路 --------------------
      // 桩值故意选 2A/A5/3C/96 四个互不相同、且和地址不对应的数，
      // 避免"读错地址也碰巧对"；PKT_MEM 窗口另给 0xC001_2345。
      //   RTL : rtl/apb_slave_if.sv:146-149（四个 RES 寄存器是组合直通输入口）
      //   连线: tb/tb.sv:62-65 把 m1_apb.*_stub 接到 M1 的输入端口
      //   波形: lab1_defaults_test.wlf 第 5 组
      // -------------------------------------------------------------------
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

  // [评分 1-必做2.1 | 10分] PKT_MEM 8 个 word 写入后逐个回读，全部正确
  // [评分 1-必做2.2 | 5分]  地址计算：0x040 -> addr[2:0]=0 ... 0x05C -> 7
  // [评分 1-必做2.3 | 5分]  口述：窗口 0x040~0x05C 共 8 字；we 的三个与项；wdata 直通不寄存
  //   RTL : rtl/apb_slave_if.sv:72(窗口判断) 79(addr=PADDR[5:2]) 80(wdata) 81(we)
  //   波形: lab1/wave_ppa/lab1_pkt_mem_test.wlf —— 注意这个用例走主通路 dut，
  //         必须用 wave/ppa_wave.do 打开（看 dut/u_m1 与 dut/u_m2/mem）
  //   模式 0xA500_0000+i：高 24 位不变、低字节递增，波形上 addr 与 data 一一对应
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

  // [评分 1-选做4.1 | 10分] 写 RO 寄存器 -> PSLVERR=1，且寄存器值保持不变
  // [评分 1-选做4.2 | 5分]  读写未定义地址 0x02C -> 同样返回 PSLVERR=1
  // [评分 1-选做4.3 | 5分]  口述：PSLVERR 四个来源 = 写不可写 / 读不可读 /
  //                     busy 时写 PKT_MEM / 未使能就写 start 位
  //   RTL : rtl/apb_slave_if.sv:101-108（可写表）118-121（写拒绝）127-129（读拒绝）
  //   波形: lab1/wave_ppa/lab1_pslverr_test.wlf（wave/ppa_wave_lab1.do）
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
      // ---------------- [评分 1-选做4.1/4.2 | 10+5分] ----------------------
      // 三个非法写：STATUS(0x008, RO)、RES_PKT_LEN(0x018, RO)、未映射(0x02C)，
      // 第三个参数 1 表示期望 PSLVERR=1；随后 0x02C 的读也期望报错。
      // 写被拒后必须没有任何寄存器更新 —— 下面的回读就是"值不变"的证据。
      // ---------------------------------------------------------------------
      lab1_apb_write(12'h008, 32'hFFFF_FFFF, 1);
      lab1_apb_write(12'h018, 32'hFFFF_FFFF, 1);
      lab1_apb_write(12'h02C, 32'hFFFF_FFFF, 1);
      lab1_apb_read(12'h02C, data, 1);
      // RO 写被拒绝后，寄存器内容必须保持原值（评分项：写 RO -> PSLVERR=1 且值不变）
      lab1_apb_read(12'h008, data, 0);
      check(data === 32'h0000_0000, "STATUS changed after illegal write");
      lab1_apb_read(12'h018, data, 0);
      check(data === 32'h0000_0000, "RES_PKT_LEN changed after illegal write");
      lab1_apb_write(12'h000, 32'h0000_0002, 1);
      lab1_apb_write(12'h000, 32'h0000_0001, 0);
      lab1_apb_write(12'h000, 32'h0000_0003, 0);
      finish();
    endtask
  endclass
