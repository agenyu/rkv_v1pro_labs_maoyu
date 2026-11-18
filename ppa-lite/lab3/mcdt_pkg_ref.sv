package mcdt_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // static variables shared by resources
  semaphore run_stop_flags = new();

  // channel sequence item
  class chnl_trans extends uvm_sequence_item;
    rand bit[31:0] data[];
    rand int ch_id;
    rand int pkt_id;
    rand int data_nidles;
    rand int pkt_nidles;
    bit rsp;

    constraint cstr{
      soft data.size inside {[4:32]};
      foreach(data[i]) data[i] == 'hC000_0000 + (this.ch_id<<24) + (this.pkt_id<<8) + i;
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
    mailbox #(chnl_trans) req_mb;
    mailbox #(chnl_trans) rsp_mb;

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
        this.req_mb.get(req);
        this.chnl_write(req);
        void'($cast(rsp, req.clone()));
        rsp.rsp = 1;
        this.rsp_mb.put(rsp);
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
  
  // channel generator and to be replaced by sequence + sequencer later
  class chnl_generator extends uvm_component;
    rand int pkt_id = 0;
    rand int ch_id = -1;
    rand int data_nidles = -1;
    rand int pkt_nidles = -1;
    rand int data_size = -1;
    rand int ntrans = 10;

    mailbox #(chnl_trans) req_mb;
    mailbox #(chnl_trans) rsp_mb;

    constraint cstr{
      soft ch_id == -1;
      soft pkt_id == 0;
      soft data_size == -1;
      soft data_nidles == -1;
      soft pkt_nidles == -1;
      soft ntrans == 10;
    }

    `uvm_component_utils_begin(chnl_generator)
      `uvm_field_int(pkt_id, UVM_ALL_ON)
      `uvm_field_int(ch_id, UVM_ALL_ON)
      `uvm_field_int(data_nidles, UVM_ALL_ON)
      `uvm_field_int(pkt_nidles, UVM_ALL_ON)
      `uvm_field_int(data_size, UVM_ALL_ON)
      `uvm_field_int(ntrans, UVM_ALL_ON)
    `uvm_component_utils_end

    function new (string name = "chnl_generator", uvm_component parent);
      super.new(name, parent);
      this.req_mb = new();
      this.rsp_mb = new();
    endfunction

    task start();
      repeat(ntrans) send_trans();
      run_stop_flags.put();
    endtask

    task send_trans();
      chnl_trans req, rsp;
      req = chnl_trans::type_id::create("req");;
      assert(req.randomize with {local::ch_id >= 0 -> ch_id == local::ch_id; 
                                 local::pkt_id >= 0 -> pkt_id == local::pkt_id;
                                 local::data_nidles >= 0 -> data_nidles == local::data_nidles;
                                 local::pkt_nidles >= 0 -> pkt_nidles == local::pkt_nidles;
                                 local::data_size >0 -> data.size() == local::data_size; 
                               })
        else `uvm_fatal("RNDFAIL", "channel packet randomization failure!")
      this.pkt_id++;
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      this.req_mb.put(req);
      this.rsp_mb.get(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else `uvm_error("RSPERR", "error response received!")
    endtask

    function void post_randomize();
      string s;
      s = {s, "AFTER RANDOMIZATION \n"};
      s = {s, "=======================================\n"};
      s = {s, "chnl_generator object content is as below: \n"};
      s = {s, super.sprint()};
      s = {s, "=======================================\n"};
      `uvm_info(get_type_name(), s, UVM_HIGH)
    endfunction
  endclass: chnl_generator

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
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
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

  //class mcdt_root_test;
  class mcdt_env extends uvm_env;
    chnl_agent agents[3];
    mcdt_monitor mcdt_mon;
    mcdt_checker chker;
    mcdt_coverage cvrg;

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
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      foreach(agents[i]) begin
        this.agents[i].monitor.mon_ana_port.connect(this.chker.in_tlm_fifos[i].analysis_export);
      end
      this.mcdt_mon.mon_ana_port.connect(this.chker.out_tlm_fifo.analysis_export);
    endfunction
  endclass

  class mcdt_root_test extends uvm_test;
    mcdt_env env;
    chnl_generator gens[3];
    event gen_stop_e;

    `uvm_component_utils(mcdt_root_test)

    function new(string name = "mcdt_root_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = mcdt_env::type_id::create("env", this);
      foreach(gens[i]) begin
        gens[i] = chnl_generator::type_id::create($sformatf("gens[%0d]", i),this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      foreach(gens[i]) begin
        env.agents[i].driver.req_mb = gens[i].req_mb;
        env.agents[i].driver.rsp_mb = gens[i].rsp_mb;
      end
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_root::get().set_report_verbosity_level_hier(UVM_HIGH);
      uvm_root::get().set_report_max_quit_count(1);
      uvm_root::get().set_timeout(10ms);
    endfunction

    virtual function void do_config();

    endfunction

    virtual task gen_stop_callback();
      // empty
    endtask

    virtual task run_stop_callback();
      `uvm_info(get_type_name(), "run_stop_callback enterred", UVM_HIGH)
      `uvm_info(get_type_name(), "wait for all generators have generated and tranferred transcations", UVM_HIGH)
      run_stop_flags.get(3);
    endtask

    task run_phase(uvm_phase phase);
      // NOTE:: raise objection to prevent simulation stopping
      phase.raise_objection(this);

      `uvm_info(get_type_name(), "=====================STARTED=====================", UVM_LOW)
      this.do_config();

      // run first the callback thread to conditionally disable gen_threads
      fork
        this.gen_stop_callback();
        @(this.gen_stop_e) disable gen_threads;
      join_none

      fork : gen_threads
        gens[0].start();
        gens[1].start();
        gens[2].start();
      join

      run_stop_callback(); // wait until run stop control task finished
      `uvm_info(get_type_name(), "=====================FINISHED=====================", UVM_LOW)
      // NOTE:: drop objection to request simulation stopping
      phase.drop_objection(this);
    endtask
  endclass

  class mcdt_basic_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_basic_test)

    function new(string name = "mcdt_basic_test", uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void do_config();
      super.do_config();
      assert(gens[0].randomize() with {ntrans==100; data_nidles==0; pkt_nidles==1; data_size==8;})
        else `uvm_fatal("RNDFAIL", "gen[0] randomization failure!") 
      assert(gens[1].randomize() with {ntrans==50; data_nidles inside {[1:2]}; pkt_nidles inside {[3:5]}; data_size==6;})
        else `uvm_fatal("RNDFAIL", "gen[1] randomization failure!") 
      assert(gens[2].randomize() with {ntrans==80; data_nidles inside {[0:1]}; pkt_nidles inside {[1:2]}; data_size==32;})
        else `uvm_fatal("RNDFAIL", "gen[2] randomization failure!") 
    endfunction
  endclass: mcdt_basic_test

  class mcdt_burst_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_burst_test)

    function new(string name = "mcdt_burst_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void do_config();
      super.do_config();
      assert(gens[0].randomize() with {ntrans inside {[80:100]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else `uvm_fatal("RNDFAIL", "gen[0] randomization failure!") 
      assert(gens[1].randomize() with {ntrans inside {[80:100]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else `uvm_fatal("RNDFAIL", "gen[1] randomization failure!") 
      assert(gens[2].randomize() with {ntrans inside {[80:100]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else `uvm_fatal("RNDFAIL", "gen[2] randomization failure!") 
    endfunction
  endclass: mcdt_burst_test

  class mcdt_fifo_full_test extends mcdt_root_test;
    `uvm_component_utils(mcdt_fifo_full_test)

    function new(string name = "mcdt_fifo_full_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void do_config();
      super.do_config();
      assert(gens[0].randomize() with {ntrans inside {[1000:2000]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else `uvm_fatal("RNDFAIL", "gen[0] randomization failure!") 
      assert(gens[1].randomize() with {ntrans inside {[1000:2000]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else `uvm_fatal("RNDFAIL", "gen[1] randomization failure!") 
      assert(gens[2].randomize() with {ntrans inside {[1000:2000]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else `uvm_fatal("RNDFAIL", "gen[2] randomization failure!") 
    endfunction

    // get all of 3 channles slave ready signals as a 3-bits vector
    function bit[2:0] get_chnl_ready_flags();
      return {env.agents[2].vif.ch_ready
             ,env.agents[1].vif.ch_ready
             ,env.agents[0].vif.ch_ready
             };
    endfunction

    virtual task gen_stop_callback();
      bit[2:0] chnl_ready_flags;
      `uvm_info(get_type_name(), "gen_stop_callback enterred", UVM_HIGH)
      @(posedge env.agents[0].vif.rstn);
      forever begin
        @(posedge env.agents[0].vif.clk);
        chnl_ready_flags = this.get_chnl_ready_flags();
        if($countones(chnl_ready_flags) <= 1) break;
      end
      `uvm_info(get_type_name(), "%s: stop 3 generators running", UVM_HIGH)
      -> this.gen_stop_e;
    endtask

    virtual task run_stop_callback();
      `uvm_info(get_type_name(), "run_stop_callback enterred", UVM_HIGH)
      `uvm_info(get_type_name(), "waiting DUT transfering all of data", UVM_HIGH)
      fork
        wait(env.agents[0].vif.ch_margin == 'h20);
        wait(env.agents[1].vif.ch_margin == 'h20);
        wait(env.agents[2].vif.ch_margin == 'h20);
      join
      `uvm_info(get_type_name(), "3 channel fifos have transferred all data", UVM_HIGH)
    endtask
  endclass: mcdt_fifo_full_test

endpackage

