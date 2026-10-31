package mcdt_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // 全局停止标志：virtual sequence在满足停止条件后把它置1，
  // 挂在sequencer上的chnl_data_sequence会在当前包发完后自动退出，
  // 这样就不需要用disable fork去强杀sequence(强杀容易让sequencer状态不干净)
  bit chnl_seq_stop = 0;

  // channel sequence item
  class chnl_trans extends uvm_sequence_item;
    rand bit[31:0] data[];
    rand int ch_id;
    rand int pkt_id;
    rand int data_nidles;
    rand int pkt_nidles;
    bit rsp;
    // 数据内容"带通道标签"的编码开关(0=按 C000_0000+(ch<<24)+(pkt<<8)+i 生成，
    // 1=关闭编码约束用全随机数据，专门用于toggle覆盖率)
    static bit random_data_en = 0;

    constraint cstr{
      soft data.size inside {[4:32]};
      if(!random_data_en) foreach(data[i]) data[i] == 'hC000_0000 + (this.ch_id<<24) + (this.pkt_id<<8) + i;
      soft ch_id == 0;
      soft pkt_id == 0;
      soft data_nidles inside {[0:2]};
      soft pkt_nidles inside {[1:10]};
    };

    `uvm_object_utils_begin(chnl_trans)
      `uvm_field_array_int(data, UVM_ALL_ON)
      `uvm_field_int(ch_id, UVM_ALL_ON)
      `uvm_field_int(pkt_id, UVM_ALL_ON)
      `uvm_field_int(data_nidles, UVM_ALL_ON)
      `uvm_field_int(pkt_nidles, UVM_ALL_ON)
      `uvm_field_int(rsp, UVM_ALL_ON)
    `uvm_object_utils_end

    function new (string name = "chnl_trans");
      super.new(name);
    endfunction
  endclass: chnl_trans
  
  // channel driver
  class chnl_driver extends uvm_driver #(chnl_trans);
    virtual chnl_intf intf;

    `uvm_component_utils(chnl_driver)
  
    function new (string name = "chnl_driver", uvm_component parent);
      super.new(name, parent);
    endfunction
  
    function void set_interface(virtual chnl_intf intf);
      if(intf == null)
        `uvm_error("GETVIF","interface handle is NULL, please check if target interface has been intantiated")
      else
        this.intf = intf;
    endfunction

    task run_phase(uvm_phase phase);
      fork
       this.do_drive();
       this.do_reset();
      join
    endtask

    task do_reset();
      forever begin
        @(negedge intf.rstn);
        intf.ch_valid <= 0;
        intf.ch_data <= 0;
      end
    endtask

    task do_drive();
      chnl_trans req, rsp;
      @(posedge intf.rstn);
      forever begin
        seq_item_port.get_next_item(req);
        this.chnl_write(req);
        void'($cast(rsp, req.clone()));
        rsp.rsp = 1;
        rsp.set_sequence_id(req.get_sequence_id());
        seq_item_port.item_done(rsp);
      end
    endtask
  
    task chnl_write(input chnl_trans t);
      foreach(t.data[i]) begin
        @(posedge intf.clk);
        intf.drv_ck.ch_valid <= 1;
        intf.drv_ck.ch_data <= t.data[i];
        @(negedge intf.clk);
        wait(intf.ch_ready === 'b1);
        `uvm_info(get_type_name(), $sformatf("sent data 'h%8x", t.data[i]), UVM_HIGH)
        repeat(t.data_nidles) chnl_idle();
      end
      repeat(t.pkt_nidles) chnl_idle();
    endtask
    
    task chnl_idle();
      @(posedge intf.clk);
      intf.drv_ck.ch_valid <= 0;
      intf.drv_ck.ch_data <= 0;
    endtask
  endclass: chnl_driver
  
  class chnl_sequencer extends uvm_sequencer #(chnl_trans);
    `uvm_component_utils(chnl_sequencer)
    function new (string name = "chnl_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass: chnl_sequencer

  class chnl_data_sequence extends uvm_sequence #(chnl_trans);
    rand int pkt_id = 0;
    rand int ch_id = -1;
    rand int data_nidles = -1;
    rand int pkt_nidles = -1;
    rand int data_size = -1;
    rand int ntrans = 10;
    rand int data[];
    constraint cstr{
      soft pkt_id == 0;
      soft ch_id == -1;
      soft data_nidles == -1;
      soft pkt_nidles == -1;
      soft data_size == -1;
      soft ntrans == 10;
      soft data.size() == data_size;
      foreach(data[i]) soft data[i] == -1;
    };
    `uvm_object_utils_begin(chnl_data_sequence)
      `uvm_field_int(pkt_id, UVM_ALL_ON)
      `uvm_field_int(ch_id, UVM_ALL_ON)
      `uvm_field_int(data_nidles, UVM_ALL_ON)
      `uvm_field_int(pkt_nidles, UVM_ALL_ON)
      `uvm_field_int(data_size, UVM_ALL_ON)
      `uvm_field_int(ntrans, UVM_ALL_ON)
    `uvm_object_utils_end
    function new (string name = "chnl_data_sequence");
      super.new(name);
    endfunction

    task body();
      // 每发一个包之前检查一次全局停止标志，
      // 便于fifo_full这类"条件满足就收手"的用例优雅退出
      repeat(ntrans) begin
        if(chnl_seq_stop) break;
        send_trans();
      end
    endtask

    task send_trans();
      chnl_trans req, rsp;
      `uvm_do_with(req, {local::ch_id >= 0 -> ch_id == local::ch_id; 
                         local::pkt_id >= 0 -> pkt_id == local::pkt_id;
                         local::data_nidles >= 0 -> data_nidles == local::data_nidles;
                         local::pkt_nidles >= 0 -> pkt_nidles == local::pkt_nidles;
                         local::data_size >0 -> data.size() == local::data_size; 
                         foreach(local::data[i]) local::data[i] >= 0 -> data[i] == local::data[i];
                         })
      this.pkt_id++;
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      get_response(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
    endtask

    function void post_randomize();
      string s;
      s = {s, "AFTER RANDOMIZATION \n"};
      s = {s, "=======================================\n"};
      s = {s, "chnl_data_sequence object content is as below: \n"};
      s = {s, super.sprint()};
      s = {s, "=======================================\n"};
      `uvm_info(get_type_name(), s, UVM_HIGH)
    endfunction
  endclass: chnl_data_sequence

  typedef struct packed {
    bit[31:0] data;
    bit[1:0] id;
  } mon_data_t;

  // channel monitor
  class chnl_monitor extends uvm_monitor;
    virtual chnl_intf intf;
    uvm_analysis_port #(mon_data_t) mon_ana_port;

    `uvm_component_utils(chnl_monitor)

    function new(string name="chnl_monitor", uvm_component parent);
      super.new(name, parent);
      mon_ana_port = new("mon_ana_port", this);
    endfunction

    function void set_interface(virtual chnl_intf intf);
      if(intf == null)
        `uvm_error("GETVIF", "interface handle is NULL, please check if target interface has been intantiated")
      else
        this.intf = intf;
    endfunction

    task run_phase(uvm_phase phase);
      this.mon_trans();
    endtask

    task mon_trans();
      mon_data_t m;
      forever begin
        @(posedge intf.clk iff (intf.ch_valid==='b1 && intf.ch_ready==='b1));
        m.data = intf.ch_data;
        mon_ana_port.write(m);
        `uvm_info(get_type_name(), $sformatf("monitored channel data 'h%8x", m.data), UVM_HIGH)
      end
    endtask
  endclass: chnl_monitor
  
  // channel agent
  class chnl_agent extends uvm_agent;
    chnl_driver driver;
    chnl_monitor monitor;
    chnl_sequencer sequencer;
    virtual chnl_intf vif;

    `uvm_component_utils(chnl_agent)

    function new(string name = "chnl_agent", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // get virtual interface
      if(!uvm_config_db#(virtual chnl_intf)::get(this,"","vif", vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      driver = chnl_driver::type_id::create("driver", this);
      monitor = chnl_monitor::type_id::create("monitor", this);
      sequencer = chnl_sequencer::type_id::create("sequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.set_interface(vif);
      monitor.set_interface(vif);
    endfunction
  endclass: chnl_agent
  
  class mcdt_monitor extends uvm_monitor;
    virtual mcdt_intf intf;
    uvm_analysis_port #(mon_data_t) mon_ana_port;

    `uvm_component_utils(mcdt_monitor)

    function new(string name="mcdt_monitor", uvm_component parent);
      super.new(name, parent);
      mon_ana_port = new("mon_ana_port", this);
    endfunction

    task run_phase(uvm_phase phase);
      this.mon_trans();
    endtask

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // get virtual interface
      if(!uvm_config_db#(virtual mcdt_intf)::get(this,"","intf", intf)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
    endfunction

    task mon_trans();
      mon_data_t m;
      forever begin
        @(posedge intf.clk iff intf.mcdt_val==='b1);
        m.data = intf.mcdt_data;
        m.id = intf.mcdt_id;
        mon_ana_port.write(m);
        `uvm_info(get_type_name(), $sformatf("monitored channel data 'h%8x", m.data), UVM_HIGH)
      end
    endtask
  endclass

  class mcdt_checker extends uvm_scoreboard;
    int error_count;
    int cmp_count;
    uvm_tlm_analysis_fifo #(mon_data_t) in_tlm_fifos[3];
    uvm_tlm_analysis_fifo #(mon_data_t) out_tlm_fifo;

    `uvm_component_utils(mcdt_checker)

    function new (string name = "mcdt_checker", uvm_component parent);
      super.new(name, parent);
      foreach(in_tlm_fifos[i]) in_tlm_fifos[i] = new($sformatf("in_tlm_fifos[%0d]", i), this);
      out_tlm_fifo = new("out_tlm_fifo", this);
      this.error_count = 0;
      this.cmp_count = 0;
    endfunction

    task run_phase(uvm_phase phase);
      this.do_data_compare();
    endtask

    task do_data_compare();
      mon_data_t im, om;
      forever begin
        out_tlm_fifo.get(om);
        case(om.id)
          0: in_tlm_fifos[0].get(im);
          1: in_tlm_fifos[1].get(im);
          2: in_tlm_fifos[2].get(im);
          default: `uvm_fatal(get_type_name(), $sformatf("id %0d is not available", om.id))
        endcase
        if(om.data != im.data) begin
          this.error_count++;
          `uvm_error("CMPFAIL", $sformatf("Compared failed! mcdt out data %8x ch_id %0d is not equal with channel in data %8x", om.data, om.id, im.data))
        end
        else begin
          `uvm_info("CMPSUCD", $sformatf("Compared succeeded! mcdt out data %8x ch_id %0d is equal with channel in data %8x", om.data, om.id, im.data), UVM_HIGH)
        end
        this.cmp_count++;
      end
    endtask
  endclass

  class mcdt_coverage extends uvm_component;
    virtual chnl_intf chnl_vifs[3]; 
    virtual mcdt_intf mcdt_vif;

    `uvm_component_utils(mcdt_coverage)

    covergroup cg_fifo_state(int length = 32);
      fifo0: coverpoint chnl_vifs[0].ch_margin {
        option.weight = 0;
        bins empty = {length};
        bins full  = {0};
        bins others = {[1:length-1]};
      }
      fifo1: coverpoint chnl_vifs[1].ch_margin { 
        option.weight = 0;
        bins empty = {length};
        bins full  = {0};
        bins others = {[1:length-1]};
      }
      fifo2: coverpoint chnl_vifs[2].ch_margin {
        option.weight = 0;
        bins empty = {length};
        bins full  = {0};
        bins others = {[1:length-1]};
      }
      fifos: cross fifo0, fifo1, fifo2 {
        bins fifo0_empty = binsof(fifo0.empty );
        bins fifo0_full  = binsof(fifo0.full  );
        bins fifo0_others= binsof(fifo0.others);
        bins fifo1_empty = binsof(fifo1.empty );
        bins fifo1_full  = binsof(fifo1.full  );
        bins fifo1_others= binsof(fifo1.others);
        bins fifo2_empty = binsof(fifo2.empty );
        bins fifo2_full  = binsof(fifo2.full  );
        bins fifo2_others= binsof(fifo2.others);
        bins f0full_f1full = binsof(fifo0.full) && binsof(fifo1.full);
        bins f0full_f2full = binsof(fifo0.full) && binsof(fifo2.full);
        bins f1full_f2full = binsof(fifo1.full) && binsof(fifo2.full);
        bins all_fifo_full = binsof(fifo0.full) && binsof(fifo1.full) && binsof(fifo2.full);
      }
    endgroup: cg_fifo_state

    covergroup cg_channel_data;
      chnl0: coverpoint chnl_vifs[0].ch_valid {
        bins valid   = {1};
        bins burst[] = (1 [* 2]), (1 [* 4]), (1 [* 8]);
        bins single  = (0 => 1 => 0);
      }
      chnl1: coverpoint chnl_vifs[1].ch_valid {
        bins valid   = {1};
        bins burst[] = (1 [* 2]), (1 [* 4]), (1 [* 8]);
        bins single  = (0 => 1 => 0);
      }
      chnl2: coverpoint chnl_vifs[2].ch_valid {
        bins valid   = {1};
        bins burst[] = (1 [* 2]), (1 [* 4]), (1 [* 8]);
        bins single  = (0 => 1 => 0);
      }
      chnls: cross chnl0, chnl1, chnl2 {
        bins chnl0_valid   = binsof(chnl0.valid );
        bins chnl0_burst   = binsof(chnl0.burst );
        bins chnl0_single  = binsof(chnl0.single);
        bins chnl1_valid   = binsof(chnl1.valid );
        bins chnl1_burst   = binsof(chnl1.burst );
        bins chnl1_single  = binsof(chnl1.single);
        bins chnl2_valid   = binsof(chnl2.valid );
        bins chnl2_burst   = binsof(chnl2.burst );
        bins chnl2_single  = binsof(chnl2.single);
        bins c0vld_c1vld   = binsof(chnl0.valid) &&  binsof(chnl1.valid);
        bins c0vld_c2vld   = binsof(chnl0.valid) &&  binsof(chnl2.valid);
        bins c1vld_c2vld   = binsof(chnl1.valid) &&  binsof(chnl2.valid);
        bins all_chnl_vld  = binsof(chnl0.valid) &&  binsof(chnl1.valid) &&  binsof(chnl2.valid);
      }
    endgroup: cg_channel_data

    covergroup cg_arbitration;
      req: coverpoint mcdt_vif.arb_reqs iff(mcdt_vif.arb_reqs !== 0) {
        bins req1[] = {'b001, 'b010, 'b100};
        bins req2[] = {'b011, 'b101, 'b110};
        bins req3 = {'b111};
      }
    endgroup: cg_arbitration

    covergroup cg_arbiter_data;
      valid: coverpoint  mcdt_vif.mcdt_val{
        bins burst   = (1 => 1);
        bins single  = (0 => 1);
      }
      id: coverpoint  mcdt_vif.mcdt_id{
        bins same[] = (0 => 0), (1 => 1), (2 => 2);
        bins diff[] = (0 => 1,2), (1 => 0,2), (2 => 0,1);
      }
      validXid: cross valid, id {
        bins valid_burst    = binsof(valid.burst);
        bins valid_single   = binsof(valid.single);
        bins id_same        = binsof(id.same);
        bins id_diff        = binsof(id.diff);
        bins same_id_burst  = binsof(id.same) && binsof(valid.burst);
        bins same_id_single = binsof(id.same) && binsof(valid.single);
        bins diff_id_burst  = binsof(id.diff) && binsof(valid.burst);
        bins diff_id_single = binsof(id.diff) && binsof(valid.single);
      }
    endgroup: cg_arbiter_data

    function new (string name = "mcdf_coverage", uvm_component parent);
      super.new(name, parent);
      cg_fifo_state = new();
      cg_channel_data = new();
      cg_arbitration = new();
      cg_arbiter_data = new();
    endfunction

    task run_phase(uvm_phase phase);
      fork 
        this.do_sample();
      join_none
    endtask

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // get virtual interface
      foreach(chnl_vifs[i]) begin
        if(!uvm_config_db#(virtual chnl_intf)::get(this,"",$sformatf("chnl_vifs[%0d]",i), chnl_vifs[i])) begin
          `uvm_fatal("GETVIF","cannot get vif handle from config DB")
        end
      end
      if(!uvm_config_db#(virtual mcdt_intf)::get(this,"","mcdt_vif", mcdt_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
    endfunction

    task do_sample();
      forever begin
        @(posedge mcdt_vif.clk iff mcdt_vif.rstn);
        cg_fifo_state.sample();
        cg_channel_data.sample();
        cg_arbitration.sample();
        cg_arbiter_data.sample();
      end
    endtask
  endclass

  class mcdt_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
    chnl_sequencer chnl_sqrs[3];
    virtual mcdt_intf mcdt_vif;
    // 除了mcdt_vif，virtual sequencer还持有3个通道的虚接口，
    // 这样virtual sequence才能直接观察ready/margin这些"状态类"信号
    virtual chnl_intf chnl_vifs[3];
    `uvm_component_utils(mcdt_virtual_sequencer)
    function new (string name = "mcdt_virtual_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual mcdt_intf)::get(this,"","mcdt_vif", mcdt_vif)) begin
        `uvm_fatal("GETVIF","cannot get mcdt_vif handle from config DB")
      end
      foreach(chnl_vifs[i]) begin
        if(!uvm_config_db#(virtual chnl_intf)::get(this,"",$sformatf("chnl_vifs[%0d]",i), chnl_vifs[i])) begin
          `uvm_fatal("GETVIF","cannot get chnl_vif handle from config DB")
        end
      end
    endfunction
  endclass

  class mcdt_env extends uvm_env;
    chnl_agent agents[3];
    mcdt_monitor mcdt_mon;
    mcdt_checker chker;
    mcdt_coverage cvrg;
    mcdt_virtual_sequencer virt_sqr;

    `uvm_component_utils(mcdt_env)

    function new (string name = "mcdt_env", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      this.chker = mcdt_checker::type_id::create("chker", this);
      foreach(agents[i]) begin
        this.agents[i] = chnl_agent::type_id::create($sformatf("agents[%0d]",i), this);
      end
      this.mcdt_mon = mcdt_monitor::type_id::create("mcdt_mon", this);
      this.cvrg = mcdt_coverage::type_id::create("cvrg", this);
      this.virt_sqr = mcdt_virtual_sequencer::type_id::create("virt_sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      foreach(agents[i]) begin
        this.agents[i].monitor.mon_ana_port.connect(this.chker.in_tlm_fifos[i].analysis_export);
        this.virt_sqr.chnl_sqrs[i] = this.agents[i].sequencer;
      end
      this.mcdt_mon.mon_ana_port.connect(this.chker.out_tlm_fifo.analysis_export);
    endfunction
  endclass

  class mcdt_root_virtual_sequence extends uvm_sequence #(uvm_sequence_item);
    chnl_data_sequence chnl_data_seq;
    `uvm_object_utils(mcdt_root_virtual_sequence)
    `uvm_declare_p_sequencer(mcdt_virtual_sequencer)

    function new (string name = "mcdt_root_virtual_sequence");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), "=====================STARTED=====================", UVM_LOW)
      chnl_seq_stop = 0;              // 每个vseq开始前清掉全局停止标志
      this.do_data();
      `uvm_info(get_type_name(), "=====================FINISHED=====================", UVM_LOW)
    endtask

    // do data transition from 3 channel slaves
    virtual task do_data();
      //User to implment the task in the child virtual sequence
    endtask

    task wait_cycles(int n);
      repeat(n) @(posedge p_sequencer.mcdt_vif.clk);
    endtask

    // 等三个通道FIFO里的残留数据全部被arbiter搬空（margin回到32，即6'h20）
    task wait_all_fifo_drain();
      fork
        wait(p_sequencer.chnl_vifs[0].ch_margin == 'h20);
        wait(p_sequencer.chnl_vifs[1].ch_margin == 'h20);
        wait(p_sequencer.chnl_vifs[2].ch_margin == 'h20);
      join
      // arbiter的输出是打拍输出，FIFO空之后还会有最后一拍数据出现在mcdt接口上，
      // 再等几拍让monitor把它收走、checker把它比完
      this.wait_cycles(5);
      `uvm_info(get_type_name(), "3 channel fifos have transferred all data", UVM_LOW)
    endtask

    // 等至少两个通道的FIFO写满：ready为高的通道数<=1 等价于 至少2个通道ready为低
    task wait_two_chnl_fifo_full();
      bit[2:0] ready_flags;
      forever begin
        @(posedge p_sequencer.mcdt_vif.clk);
        ready_flags = {p_sequencer.chnl_vifs[2].ch_ready,
                       p_sequencer.chnl_vifs[1].ch_ready,
                       p_sequencer.chnl_vifs[0].ch_ready};
        if($countones(ready_flags) <= 1) begin
          `uvm_info(get_type_name(), $sformatf("fifo full detected, ready flags = 'b%03b", ready_flags), UVM_LOW)
          break;
        end
      end
    endtask

    // 手动创建并启动一条channel data sequence，包数可以按用例需要配置，
    // 不用为每种包数组合写一份`uvm_do_on_with约束
    task start_chnl_seq(int idx, int ntrans, int ch_id);
      chnl_data_sequence seq = chnl_data_sequence::type_id::create($sformatf("chnl_seq_%0d", idx));
      if(!seq.randomize() with {ntrans == local::ntrans;
                                ch_id == local::ch_id;
                                data_nidles == 0;
                                pkt_nidles == 1;
                                data_size inside {8, 16, 32};}) begin
        `uvm_fatal("RNDFAIL", $sformatf("channel %0d sequence randomization failure", idx))
      end
      seq.start(p_sequencer.chnl_sqrs[idx]);
    endtask
  endclass

  class mcdt_root_test extends uvm_test;
    mcdt_env env;

    `uvm_component_utils(mcdt_root_test)

    function new(string name = "mcdt_root_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = mcdt_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_root::get().set_report_verbosity_level_hier(UVM_HIGH);
      uvm_root::get().set_report_max_quit_count(1);
      // NOTE: UVM内部的timeout是按仿真精度(1ps)去和$time比较的，
      //       所以这里写10s实际等价于10ms的仿真时间，作为跑飞的兜底
      uvm_root::get().set_timeout(10s);
    endfunction

    task run_phase(uvm_phase phase);
      // NOTE:: raise objection to prevent simulation stopping
      phase.raise_objection(this);
      this.run_top_virtual_sequence();
      // NOTE:: drop objection to request simulation stopping
      phase.drop_objection(this);
    endtask

    virtual task run_top_virtual_sequence();
      // User
    endtask
  endclass: mcdt_root_test

  class mcdt_basic_virtual_sequence extends mcdt_root_virtual_sequence;
    `uvm_object_utils(mcdt_basic_virtual_sequence)
    function new (string name = "mcdt_basic_virtual_sequence");
      super.new(name);
    endfunction
    task do_data();
      // User
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0], 
                        {ntrans==100; ch_id==0; data_nidles ==0; pkt_nidles==1; data_size==8;}
                       )
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1], 
                        {ntrans== 50; ch_id==1; data_nidles inside {[1:2]}; pkt_nidles inside {[3:5]}; data_size==6;}
                       )
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2], 
                        {ntrans== 80; ch_id==2; data_nidles inside {[0:1]}; pkt_nidles inside {[1:2]}; data_size==32;})
      join
      // 等DUT把FIFO里剩下的数据搬完，保证checker把该比的数据都比完
      this.wait_all_fifo_drain();
    endtask
  endclass


  class mcdt_basic_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_basic_test)
    function new(string name = "mcdt_basic_test", uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_top_virtual_sequence();
      mcdt_basic_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_basic_test

  //------------------------------------------------------------------
  // burst测试的剥离：virtual sequence负责"发什么"，test只负责"跑哪个vseq"
  //------------------------------------------------------------------
  class mcdt_burst_virtual_sequence extends mcdt_root_virtual_sequence;
    `uvm_object_utils(mcdt_burst_virtual_sequence)
    function new (string name = "mcdt_burst_virtual_sequence");
      super.new(name);
    endfunction
    task do_data();
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      // 三个通道都背靠背发长包：data_nidles==0(包内无空拍)，pkt_nidles==1(包间1拍)
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0],
                        {ntrans inside {[80:100]}; ch_id==0; data_nidles==0; pkt_nidles==1; data_size inside {8,16,32};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1],
                        {ntrans inside {[80:100]}; ch_id==1; data_nidles==0; pkt_nidles==1; data_size inside {8,16,32};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2],
                        {ntrans inside {[80:100]}; ch_id==2; data_nidles==0; pkt_nidles==1; data_size inside {8,16,32};})
      join
      this.wait_all_fifo_drain();
    endtask
  endclass

  class mcdt_burst_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_burst_test)

    function new(string name = "mcdt_burst_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdt_burst_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_burst_test

  //------------------------------------------------------------------
  // fifo_full测试的剥离：
  //   停止条件写在virtual sequence里——两个通道的FIFO同时写满后，
  //   先把全局停止标志置1让三条data sequence收手，再等DUT把残留数据搬空
  //------------------------------------------------------------------
  class mcdt_fifo_full_virtual_sequence extends mcdt_root_virtual_sequence;
    `uvm_object_utils(mcdt_fifo_full_virtual_sequence)
    function new (string name = "mcdt_fifo_full_virtual_sequence");
      super.new(name);
    endfunction
    task do_data();
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0],
                        {ntrans inside {[1000:2000]}; ch_id==0; data_nidles==0; pkt_nidles==1; data_size inside {8,16,32};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1],
                        {ntrans inside {[1000:2000]}; ch_id==1; data_nidles==0; pkt_nidles==1; data_size inside {8,16,32};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2],
                        {ntrans inside {[1000:2000]}; ch_id==2; data_nidles==0; pkt_nidles==1; data_size inside {8,16,32};})
        begin
          this.wait_two_chnl_fifo_full();
          chnl_seq_stop = 1;    // 停止激励：让三条data sequence发完当前包后退出
        end
      join
      this.wait_all_fifo_drain();
    endtask
  endclass

  class mcdt_fifo_full_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_fifo_full_test)

    function new(string name = "mcdt_fifo_full_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdt_fifo_full_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_fifo_full_test

  //------------------------------------------------------------------
  // 覆盖率补充用例1(single beat)：包内只有1拍数据，用于命中
  //   cg_channel_data 的 single (0=>1=>0)、cg_arbiter_data.valid 的 single (0=>1)
  //------------------------------------------------------------------
  class mcdt_single_virtual_sequence extends mcdt_root_virtual_sequence;
    `uvm_object_utils(mcdt_single_virtual_sequence)
    function new (string name = "mcdt_single_virtual_sequence");
      super.new(name);
    endfunction
    task do_data();
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0],
                        {ntrans inside {[40:60]}; ch_id==0; data_nidles==0; pkt_nidles inside {[6:10]}; data_size==1;})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1],
                        {ntrans inside {[40:60]}; ch_id==1; data_nidles==0; pkt_nidles inside {[6:10]}; data_size==1;})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2],
                        {ntrans inside {[40:60]}; ch_id==2; data_nidles==0; pkt_nidles inside {[6:10]}; data_size==1;})
      join
      this.wait_all_fifo_drain();
    endtask
  endclass

  class mcdt_single_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_single_test)

    function new(string name = "mcdt_single_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdt_single_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_single_test

  //------------------------------------------------------------------
  // 覆盖率补充用例2(单一通道独占)：+CHID=<0|1|2> 指定主角通道，
  //   另外两个通道只发很少的包，之后arbiter只能授权主角通道，
  //   用于命中 cg_arbiter_data.id 的 same 转移 (0=>0)/(1=>1)/(2=>2)
  //------------------------------------------------------------------
  class mcdt_alone_virtual_sequence extends mcdt_root_virtual_sequence;
    int chid = 0;
    `uvm_object_utils(mcdt_alone_virtual_sequence)
    function new (string name = "mcdt_alone_virtual_sequence");
      super.new(name);
    endfunction

    // 主角/配角通道的包数不同，用start_chnl_seq按通道分别配置
    task do_data();
      void'($value$plusargs("CHID=%0d", chid));
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      `uvm_info(get_type_name(), $sformatf("channel %0d is the only active channel", chid), UVM_LOW)
      // 主角通道发很多包，另外两个通道只发3个包就退出发送，
      // 之后arbiter的请求只剩主角通道，于是轮询状态机每次都停在同一路
      fork
        start_chnl_seq(0, (chid==0) ? 200 : 3, 0);
        start_chnl_seq(1, (chid==1) ? 200 : 3, 1);
        start_chnl_seq(2, (chid==2) ? 200 : 3, 2);
      join
      this.wait_all_fifo_drain();
    endtask
  endclass

  class mcdt_alone_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_alone_test)

    function new(string name = "mcdt_alone_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdt_alone_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_alone_test

  //------------------------------------------------------------------
  // 覆盖率补充用例3(全随机数据)：把数据内容编码约束关掉，
  //   用32位随机数把数据总线每一位都翻转一遍，用于补toggle覆盖率
  //------------------------------------------------------------------
  class mcdt_random_virtual_sequence extends mcdt_root_virtual_sequence;
    `uvm_object_utils(mcdt_random_virtual_sequence)
    function new (string name = "mcdt_random_virtual_sequence");
      super.new(name);
    endfunction
    task do_data();
      chnl_trans::random_data_en = 1;
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0],
                        {ntrans inside {[40:60]}; ch_id==0; data_nidles inside {[0:1]}; pkt_nidles inside {[1:2]}; data_size inside {[4:32]};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1],
                        {ntrans inside {[40:60]}; ch_id==1; data_nidles inside {[0:1]}; pkt_nidles inside {[1:2]}; data_size inside {[4:32]};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2],
                        {ntrans inside {[40:60]}; ch_id==2; data_nidles inside {[0:1]}; pkt_nidles inside {[1:2]}; data_size inside {[4:32]};})
      join
      this.wait_all_fifo_drain();
    endtask
  endclass

  class mcdt_random_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_random_test)

    function new(string name = "mcdt_random_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdt_random_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_random_test

  //------------------------------------------------------------------
  // 覆盖率补充用例4(两通道配对)：+CHPAIR=0(ch0+ch1) / 1(ch1+ch2) / 2(ch0+ch2)
  //   只让两个通道同时活跃，用于命中 cg_arbitration.req2 的三组两路请求，
  //   以及 cg_arbiter_data.id 的对角转移(如 1=>0: GRANT1直接回到GRANT0)
  //------------------------------------------------------------------
  class mcdt_pair_virtual_sequence extends mcdt_root_virtual_sequence;
    int chpair = 0;
    `uvm_object_utils(mcdt_pair_virtual_sequence)
    function new (string name = "mcdt_pair_virtual_sequence");
      super.new(name);
    endfunction
    task do_data();
      void'($value$plusargs("CHPAIR=%0d", chpair));
      @(posedge p_sequencer.mcdt_vif.rstn);
      this.wait_cycles(10);
      `uvm_info(get_type_name(), $sformatf("channel pair = %0d", chpair), UVM_LOW)
      fork
        start_chnl_seq(0, ((chpair==0) || (chpair==2)) ? 120 : 0, 0);
        start_chnl_seq(1, ((chpair==0) || (chpair==1)) ? 120 : 0, 1);
        start_chnl_seq(2, ((chpair==1) || (chpair==2)) ? 120 : 0, 2);
      join
      this.wait_all_fifo_drain();
    endtask
  endclass

  class mcdt_pair_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_pair_test)

    function new(string name = "mcdt_pair_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdt_pair_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdt_pair_test

endpackage

